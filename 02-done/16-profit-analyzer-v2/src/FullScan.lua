-- src/FullScan.lua
-- Full AH scan: download all auctions in one query via getAll=true.
-- Uses the old AH API (QueryAuctionItems), not C_AuctionHouse (Retail only).
--
-- Flow:
--   1. Check CanSendAuctionQuery() → canQueryAll must be true
--   2. Silence other AUCTION_ITEM_LIST_UPDATE listeners (anti-corruption)
--   3. QueryAuctionItems("", ..., true, ...) → single getAll query
--   4. Wait for AUCTION_ITEM_LIST_UPDATE (one event, all data at once)
--   5. Process results in batches of 250 (anti-freeze)
--   6. Inject into Listings, store timestamp, restore listeners
--
-- Cooldown: 15 minutes (900s) per account/realm, server-enforced.
-- We also track locally for UX (countdown message).

local _, ns = ...

local FullScan = {}
ns.FullScan = FullScan

-------------------------------------------------
-- Constants
-------------------------------------------------
local BATCH_SIZE = 250
local COOLDOWN_SECONDS = 900  -- 15 minutes

-------------------------------------------------
-- State
-------------------------------------------------
FullScan._active = false
FullScan._results = nil        -- { [itemID] = { {count=N, buyout=N}, ... } }
FullScan._suspendedFrames = nil
FullScan._frame = nil          -- event frame
FullScan._processIndex = 0     -- current batch position
FullScan._processTotal = 0     -- total auctions to process
FullScan._totalAuctions = 0    -- for final summary

-------------------------------------------------
-- Timestamp (stored in SavedVariables)
-------------------------------------------------
FullScan._db = nil             -- ref to ManualListingsDB

function FullScan.init(db)
    if type(db) ~= "table" then db = {} end
    FullScan._db = db
    if type(db.fullScanTime) ~= "number" then
        db.fullScanTime = 0
    end
end

-------------------------------------------------
-- Public queries
-------------------------------------------------

function FullScan.isActive()
    return FullScan._active
end

function FullScan.getLastScanTime()
    return FullScan._db and FullScan._db.fullScanTime or 0
end

function FullScan.isStale()
    local last = FullScan.getLastScanTime()
    if last == 0 then return true end
    return (time() - last) > COOLDOWN_SECONDS
end

function FullScan.getRemainingCooldown()
    local last = FullScan.getLastScanTime()
    if last == 0 then return 0 end
    local remaining = COOLDOWN_SECONDS - (time() - last)
    if remaining < 0 then remaining = 0 end
    return remaining
end

-------------------------------------------------
-- Can we start a full scan?
-------------------------------------------------
function FullScan.canStart()
    if FullScan._active then
        return false, "scan in progress"
    end
    if not ns.Scanner.isAHOpen() then
        return false, "AH is not open"
    end
    local _, canQueryAll = ns.WoW.CanSendAuctionQuery()
    if not canQueryAll then
        local remaining = FullScan.getRemainingCooldown()
        local min = math.floor(remaining / 60)
        local sec = remaining % 60
        return false, string.format("cooldown (~%dm %ds remaining)", min, sec)
    end
    return true
end

-------------------------------------------------
-- Silence other listeners (pattern from Auctionator)
-------------------------------------------------
local function silenceListeners()
    local frames
    if ns.WoW.GetFramesRegisteredForEvent then
        frames = ns.WoW.GetFramesRegisteredForEvent("AUCTION_ITEM_LIST_UPDATE")
    end
    FullScan._suspendedFrames = frames or {}
    for _, f in ipairs(FullScan._suspendedFrames) do
        if f ~= FullScan._frame then
            f:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
        end
    end
end

local function restoreListeners()
    if not FullScan._suspendedFrames then return end
    for _, f in ipairs(FullScan._suspendedFrames) do
        if f ~= FullScan._frame then
            f:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
        end
    end
    FullScan._suspendedFrames = nil
end

-------------------------------------------------
-- Ensure event frame exists
-------------------------------------------------
local function ensureFrame()
    if FullScan._frame then return end
    if not ns.WoW.CreateFrame then return end
    local f = ns.WoW.CreateFrame("Frame")
    if not f then return end
    FullScan._frame = f
    f:SetScript("OnEvent", function(_, event)
        if event == "AUCTION_ITEM_LIST_UPDATE" and FullScan._active then
            -- Unregister immediately: getAll sends one event with all data
            FullScan._frame:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
            FullScan._onDataReady()
        elseif event == "AUCTION_HOUSE_CLOSED" and FullScan._active then
            FullScan._finish(false, "AH closed during scan")
        end
    end)
end

-------------------------------------------------
-- Start the full scan
-------------------------------------------------
function FullScan.start()
    local ok, err = FullScan.canStart()
    if not ok then
        return false, err
    end

    ensureFrame()
    if not FullScan._frame then
        return false, "could not create frame"
    end

    FullScan._active = true
    FullScan._results = {}
    FullScan._processIndex = 0
    FullScan._processTotal = 0
    FullScan._totalAuctions = 0

    -- Defensive patch: some getAll results have quality = -1
    -- which causes errors in Blizzard_AuctionUI
    if _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[-1] == nil then
        _G.ITEM_QUALITY_COLORS[-1] = { r = 0, g = 0, b = 0 }
    end

    -- Silence Blizzard + other addon listeners
    silenceListeners()

    -- Register for events
    FullScan._frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    FullScan._frame:RegisterEvent("AUCTION_HOUSE_CLOSED")

    -- Store timestamp immediately (cooldown starts now)
    if FullScan._db then
        FullScan._db.fullScanTime = time()
    end

    -- Fire the getAll query
    ns.WoW.QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)

    return true
end

-------------------------------------------------
-- Data ready — start batch processing
-------------------------------------------------
function FullScan._onDataReady()
    local numBatch, totalAuctions = ns.WoW.GetNumAuctionItems("list")

    -- In getAll mode, numBatch should equal totalAuctions
    FullScan._totalAuctions = numBatch or 0
    FullScan._processIndex = 1
    FullScan._processTotal = numBatch or 0

    if FullScan._processTotal == 0 then
        FullScan._finish(false, "no auctions returned")
        return
    end

    -- Start processing first batch
    FullScan._processBatch()
end

-------------------------------------------------
-- Process a batch of results
-------------------------------------------------
function FullScan._processBatch()
    if not FullScan._active then return end

    local stopIdx = math.min(FullScan._processIndex + BATCH_SIZE - 1, FullScan._processTotal)

    for i = FullScan._processIndex, stopIdx do
        -- count(3), buyoutPrice(10), itemId(17) are available immediately
        -- even if the item name is not cached
        local _, _, count, _, _, _, _, _, _, buyoutPrice,
              _, _, _, _, _, _, itemID = ns.WoW.GetAuctionItemInfo("list", i)

        if itemID and itemID ~= 0 and buyoutPrice and buyoutPrice > 0 and count and count > 0 then
            if not FullScan._results[itemID] then
                FullScan._results[itemID] = {}
            end
            local bucket = FullScan._results[itemID]
            bucket[#bucket + 1] = {
                count = count,
                buyout = buyoutPrice,
            }
        end
    end

    FullScan._processIndex = stopIdx + 1

    if FullScan._processIndex <= FullScan._processTotal then
        -- More batches to process — yield to next frame
        ns.WoW.C_Timer_After(0.01, FullScan._processBatch)
    else
        -- All done
        FullScan._finish(true)
    end
end

-------------------------------------------------
-- Finish the scan
-------------------------------------------------
function FullScan._finish(success, errMsg)
    -- Unregister events
    if FullScan._frame then
        FullScan._frame:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
        FullScan._frame:UnregisterEvent("AUCTION_HOUSE_CLOSED")
    end

    -- Restore silenced listeners
    restoreListeners()

    FullScan._active = false

    if success then
        -- Clear all existing listings and inject full scan results
        ns.Listings.clear()
        local itemCount = 0
        local auctionCount = 0
        for itemID, auctions in pairs(FullScan._results) do
            itemCount = itemCount + 1
            for _, a in ipairs(auctions) do
                ns.Listings.add(itemID, a.count, a.buyout)
                auctionCount = auctionCount + 1
            end
        end

        -- Update timestamp
        if FullScan._db then
            FullScan._db.fullScanTime = time()
        end

        ns.WoW.print(string.format(
            "|cFF4FC3F7[FullScan]|r Complete: |cFF00FF00%d|r items, |cFF00FF00%d|r auctions from %d total",
            itemCount, auctionCount, FullScan._totalAuctions))
    else
        ns.WoW.print(string.format(
            "|cFFFF0000[FullScan]|r Failed: %s", errMsg or "unknown error"))
    end

    FullScan._results = nil
end

return FullScan
