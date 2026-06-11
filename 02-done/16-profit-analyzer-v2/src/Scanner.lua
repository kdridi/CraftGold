-- src/Scanner.lua
-- AH Scanner v2: pagination, throttling, queue.
--
-- State machine:
--   IDLE → (scan called) → SCANNING page 0
--     → AUCTION_ITEM_LIST_UPDATE → accumulate results
--       → more pages? → wait for CanSendAuctionQuery → SCANNING page N
--       → no more pages? → deliver results → dequeue next item or IDLE
--
-- Throttling:
--   OnUpdate ticker checks CanSendAuctionQuery() before requesting next page.
--   The Blizzard UI does the same (BrowseSearchButton_OnUpdate).
--
-- Queue:
--   Multiple items can be queued. They are scanned sequentially.
--   /cg scan 2840; scan 2589; scan 2835 → all three in sequence.

local _, ns = ...

local Scanner = {}
ns.Scanner = Scanner

-------------------------------------------------
-- Constants
-------------------------------------------------
local ITEMS_PER_PAGE = 50

-------------------------------------------------
-- State
-------------------------------------------------
Scanner._ahOpen = false

-- Current scan state
Scanner._active = false       -- are we mid-scan?
Scanner._targetItemID = nil   -- itemID we're scanning
Scanner._scanName = nil       -- resolved item name (for queries)
Scanner._callback = nil       -- function(results, skipped, meta)
Scanner._currentPage = 0      -- current page being fetched
Scanner._totalAuctions = 0    -- total auctions reported by server
Scanner._accumulated = nil    -- accumulated results across pages
Scanner._skipped = nil        -- accumulated skip stats

-- Queue: array of { itemID = N, callback = fn }
Scanner._queue = {}

-- Throttle: OnUpdate frame
Scanner._frame = nil

-------------------------------------------------
-- Public queries
-------------------------------------------------
function Scanner.isAHOpen()
    return Scanner._ahOpen
end

function Scanner.setAHOpen(open)
    Scanner._ahOpen = open
    if not open then
        Scanner.cancel()
    end
end

function Scanner.isActive()
    return Scanner._active
end

function Scanner.getTargetItemID()
    return Scanner._targetItemID
end

function Scanner.getQueueSize()
    return #Scanner._queue
end

-- Return progress info for the current scan
function Scanner.getProgress()
    if not Scanner._active then
        return nil
    end
    local totalPages = math.ceil(Scanner._totalAuctions / ITEMS_PER_PAGE)
    if totalPages < 1 then totalPages = 1 end
    return {
        itemID = Scanner._targetItemID,
        currentPage = Scanner._currentPage,
        totalPages = totalPages,
        totalAuctions = Scanner._totalAuctions,
        listingsFound = #Scanner._accumulated,
        queueRemaining = #Scanner._queue,
    }
end

-------------------------------------------------
-- Throttle frame (OnUpdate)
-------------------------------------------------
-- We create a hidden frame that ticks OnUpdate.
-- When we need to request the next page, we wait
-- until CanSendAuctionQuery() returns true.
-- This mirrors the Blizzard UI approach.

local function ensureFrame()
    if Scanner._frame then return end
    -- Frame creation happens in WoW env; in tests CreateFrame may return nil
    if not ns.WoW.CreateFrame then return end
    local f = ns.WoW.CreateFrame("Frame")
    if not f then return end  -- test env: no frame available
    Scanner._frame = f
    Scanner._frame:Hide()
    Scanner._frame:SetScript("OnUpdate", function(self, elapsed)
        if not Scanner._active then
            self:Hide()
            return
        end
        -- Check if we're waiting to send next page
        if Scanner._waitingForThrottle then
            if ns.WoW.CanSendAuctionQuery() then
                Scanner._waitingForThrottle = false
                Scanner._requestNextPage()
            end
        end
    end)
end

Scanner._waitingForThrottle = false

-------------------------------------------------
-- Internal: start scanning the next page
-------------------------------------------------
function Scanner._requestNextPage()
    if not Scanner._active then return end

    local page = Scanner._currentPage

    -- Check throttle before sending
    if not ns.WoW.CanSendAuctionQuery() then
        -- Not ready yet — enable OnUpdate ticker to retry
        Scanner._waitingForThrottle = true
        ensureFrame()
        if Scanner._frame then
            Scanner._frame:Show()
        end
        return
    end

    -- Send the query for this page
    ns.WoW.QueryAuctionItems(Scanner._scanName, nil, nil, page, nil, nil, false, true, nil)
    -- After sending, update currentPage to reflect what was just sent
    Scanner._currentPage = page
end

-------------------------------------------------
-- Start scanning an item
-------------------------------------------------
-- itemID: the item to search for on the AH
-- callback: function(results, skipped, meta)
--   results = { { count = N, buyout = C }, ... }
--   skipped = { wrongItem = N, noBuyout = N }
--   meta = { itemID = N, pages = N, totalAuctions = N }
-- Returns: true if scan started/queued, false + error message
function Scanner.scan(itemID, callback)
    -- Resolve itemID → name
    -- First try the cache, then force-load if not cached
    local name = ns.WoW.GetItemInfo(itemID)
    if not name then
        -- Force the client to load item data from local DB2 files
        if ns.WoW.RequestLoadItemDataByID then
            ns.WoW.RequestLoadItemDataByID(itemID)
        end
        -- Retry after force-load (in Classic Era, data is local and loads near-instantly)
        name = ns.WoW.GetItemInfo(itemID)
    end
    if not name then
        return false, "item not in cache (try viewing it first, then retry)"
    end

    -- If AH not open, fail immediately
    if not Scanner._ahOpen then
        return false, "AH not open"
    end

    -- If a scan is active, queue this one
    if Scanner._active then
        Scanner._queue[#Scanner._queue + 1] = {
            itemID = itemID,
            callback = callback,
        }
        return true  -- queued
    end

    -- Start scan immediately
    Scanner._startScan(itemID, name, callback)
    return true
end

-------------------------------------------------
-- Internal: actually start a scan
-------------------------------------------------
function Scanner._startScan(itemID, name, callback)
    Scanner._active = true
    Scanner._targetItemID = itemID
    Scanner._scanName = name
    Scanner._callback = callback
    Scanner._currentPage = 0
    Scanner._totalAuctions = 0
    Scanner._accumulated = {}
    Scanner._skipped = { wrongItem = 0, noBuyout = 0 }
    Scanner._waitingForThrottle = false

    -- Request page 0
    Scanner._requestNextPage()
end

-------------------------------------------------
-- Handle AUCTION_ITEM_LIST_UPDATE event
-------------------------------------------------
function Scanner.onItemListUpdate()
    if not Scanner._active then return end

    local numBatchAuctions, totalAuctions = ns.WoW.GetNumAuctionItems("list")

    -- Update total (server may refine it across pages)
    if totalAuctions > 0 then
        Scanner._totalAuctions = totalAuctions
    end

    -- Cap to expected items on this page.
    -- The AH buffer always returns ITEMS_PER_PAGE (50) entries,
    -- even on the last page where stale data from previous pages
    -- lingers in the extra slots.  We compute the expected count
    -- based on totalAuctions and the current page index.
    local totalPages = math.ceil(Scanner._totalAuctions / ITEMS_PER_PAGE)
    if totalPages < 1 then totalPages = 1 end
    local isLastPage = (Scanner._currentPage >= totalPages - 1)
    local maxItems = numBatchAuctions
    if isLastPage and Scanner._totalAuctions > 0 then
        local expected = Scanner._totalAuctions - Scanner._currentPage * ITEMS_PER_PAGE
        if expected < 0 then expected = 0 end
        maxItems = math.min(numBatchAuctions, expected)
    end

    -- Parse this page's results
    for i = 1, maxItems do
        local name, texture, count, quality, canUse, level, levelColHeader,
              minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
              bidderFullName, owner, ownerFullName, saleStatus, itemId,
              hasAllInfo = ns.WoW.GetAuctionItemInfo("list", i)

        if hasAllInfo == false then
            -- skip incomplete entries
        elseif itemId ~= Scanner._targetItemID then
            Scanner._skipped.wrongItem = Scanner._skipped.wrongItem + 1
        elseif buyoutPrice == 0 then
            Scanner._skipped.noBuyout = Scanner._skipped.noBuyout + 1
        else
            Scanner._accumulated[#Scanner._accumulated + 1] = {
                count = count,
                buyout = buyoutPrice,
            }
        end
    end

    -- Check if more pages remain
    local totalPages = math.ceil(Scanner._totalAuctions / ITEMS_PER_PAGE)
    if totalPages < 1 then totalPages = 1 end
    local nextPage = Scanner._currentPage + 1

    if nextPage < totalPages then
        -- More pages to fetch
        Scanner._currentPage = nextPage
        Scanner._requestNextPage()
    else
        -- All pages fetched — deliver results
        Scanner._finishItem()
    end
end

-------------------------------------------------
-- Internal: deliver results and dequeue next
-------------------------------------------------
function Scanner._finishItem()
    local itemID = Scanner._targetItemID
    local callback = Scanner._callback
    local results = Scanner._accumulated
    local skipped = Scanner._skipped
    local totalPages = math.ceil(Scanner._totalAuctions / ITEMS_PER_PAGE)
    if totalPages < 1 then totalPages = 1 end

    local meta = {
        itemID = itemID,
        pages = totalPages,
        totalAuctions = Scanner._totalAuctions,
    }

    -- Reset state
    Scanner._active = false
    Scanner._targetItemID = nil
    Scanner._scanName = nil
    Scanner._callback = nil
    Scanner._currentPage = 0
    Scanner._totalAuctions = 0
    Scanner._accumulated = {}
    Scanner._skipped = nil
    Scanner._waitingForThrottle = false

    if Scanner._frame then
        Scanner._frame:Hide()
    end

    -- Deliver callback
    if callback then
        callback(results, skipped, meta)
    end

    -- Dequeue next item if any
    if #Scanner._queue > 0 and Scanner._ahOpen then
        local next = table.remove(Scanner._queue, 1)
        local name = ns.WoW.GetItemInfo(next.itemID)
        if name then
            Scanner._startScan(next.itemID, name, next.callback)
        else
            -- Item not in cache — skip and try next
            if next.callback then
                next.callback({}, { wrongItem = 0, noBuyout = 0, error = "not in cache" }, { itemID = next.itemID, pages = 0, totalAuctions = 0 })
            end
            -- Recurse to try next in queue
            Scanner._finishItem()  -- will dequeue again
        end
    end
end

-------------------------------------------------
-- Cancel current scan + clear queue
-------------------------------------------------
function Scanner.cancel()
    if not Scanner._active and #Scanner._queue == 0 then
        return false
    end

    local itemID = Scanner._targetItemID
    local callback = Scanner._callback

    -- Clear queue
    local queueSize = #Scanner._queue
    Scanner._queue = {}

    -- Reset scan state
    Scanner._active = false
    Scanner._targetItemID = nil
    Scanner._scanName = nil
    Scanner._callback = nil
    Scanner._currentPage = 0
    Scanner._totalAuctions = 0
    Scanner._accumulated = {}
    Scanner._skipped = nil
    Scanner._waitingForThrottle = false

    if Scanner._frame then
        Scanner._frame:Hide()
    end

    -- Notify current scan callback
    if callback then
        callback({}, { wrongItem = 0, noBuyout = 0, cancelled = true, itemID = itemID })
    end

    return true, queueSize
end

return Scanner
