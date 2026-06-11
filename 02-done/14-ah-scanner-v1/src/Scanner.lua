-- src/Scanner.lua
-- AH Scanner v1: scan one item from the Auction House.
-- Queries the AH by item name (exact match), filters by itemID,
-- extracts buyout listings, and feeds them into the Listings module.
--
-- WoW AH API is async:
--   1. scan(itemID, callback) → calls QueryAuctionItems
--   2. AUCTION_ITEM_LIST_UPDATE fires → onItemListUpdate()
--   3. Results filtered by itemID + buyoutPrice > 0
--   4. Callback called with the filtered results
--
-- Safety:
--   - cancel() resets stuck state (e.g. AH closed mid-scan)
--   - AUCTION_HOUSE_CLOSED event triggers automatic cancel
--   - Target itemID stored for status reporting

local _, ns = ...

local Scanner = {}
ns.Scanner = Scanner

-------------------------------------------------
-- State
-------------------------------------------------
Scanner._active = false       -- are we mid-scan?
Scanner._targetItemID = nil   -- itemID we're scanning for
Scanner._callback = nil       -- function(results, skipped) to call when done
Scanner._ahOpen = false       -- is the Auction House open?

-------------------------------------------------
-- Check if the Auction House is open
-------------------------------------------------
function Scanner.isAHOpen()
    return Scanner._ahOpen
end

-------------------------------------------------
-- Set AH open state (called by shell on events)
-------------------------------------------------
function Scanner.setAHOpen(open)
    Scanner._ahOpen = open
    if not open and Scanner._active then
        Scanner.cancel()
    end
end

-------------------------------------------------
-- Check if a scan is in progress
-------------------------------------------------
function Scanner.isActive()
    return Scanner._active
end

-------------------------------------------------
-- Get the itemID being scanned (for status messages)
-------------------------------------------------
function Scanner.getTargetItemID()
    return Scanner._targetItemID
end

-------------------------------------------------
-- Start scanning an item
-------------------------------------------------
-- itemID: the item to search for on the AH
-- callback: function(results, skipped) called when results are ready
--   results = { { count = N, buyout = C }, ... } (only buyout listings)
--   skipped = { wrongItem = N, noBuyout = N }
-- Returns: true if scan started, false + error message if not
function Scanner.scan(itemID, callback)
    if Scanner._active then
        return false, "scan already in progress"
    end

    -- Resolve itemID → name (needed for QueryAuctionItems)
    local name = ns.WoW.GetItemInfo(itemID)
    if not name then
        return false, "item not in cache (try viewing it first, then retry)"
    end

    -- Check if we can send a query
    if not ns.WoW.CanSendAuctionQuery() then
        return false, "AH query not ready (is the AH open?)"
    end

    -- Store state
    Scanner._active = true
    Scanner._targetItemID = itemID
    Scanner._callback = callback

    -- Fire the query (exact match on name)
    ns.WoW.QueryAuctionItems(name, nil, nil, 0, nil, nil, false, true, nil)

    return true
end

-------------------------------------------------
-- Cancel an in-progress scan
-------------------------------------------------
-- Called when AH closes mid-scan or user cancels manually.
-- Returns true if a scan was cancelled, false if nothing active.
function Scanner.cancel()
    if not Scanner._active then
        return false
    end

    local itemID = Scanner._targetItemID
    local callback = Scanner._callback

    -- Reset state
    Scanner._active = false
    Scanner._targetItemID = nil
    Scanner._callback = nil

    -- Notify callback that scan was cancelled (empty results + cancelled flag)
    if callback then
        callback({}, { wrongItem = 0, noBuyout = 0, cancelled = true, itemID = itemID })
    end

    return true
end

-------------------------------------------------
-- Handle AUCTION_ITEM_LIST_UPDATE event
-------------------------------------------------
-- Called by the shell when the event fires.
-- Filters results by targetItemID and buyoutPrice > 0.
function Scanner.onItemListUpdate()
    if not Scanner._active then return end

    local targetItemID = Scanner._targetItemID
    local callback = Scanner._callback

    -- Read results
    local numBatchAuctions = ns.WoW.GetNumAuctionItems("list")

    local results = {}
    local skipped = {
        wrongItem = 0,
        noBuyout = 0,
    }

    for i = 1, numBatchAuctions do
        local name, texture, count, quality, canUse, level, levelColHeader,
              minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
              bidderFullName, owner, ownerFullName, saleStatus, itemId,
              hasAllInfo = ns.WoW.GetAuctionItemInfo("list", i)

        -- Skip incomplete data
        if hasAllInfo == false then
            -- skip entries without full info
        elseif itemId ~= targetItemID then
            -- Wrong item (recipe, homonym, etc.)
            skipped.wrongItem = skipped.wrongItem + 1
        elseif buyoutPrice == 0 then
            -- No buyout — we only want direct buy price
            skipped.noBuyout = skipped.noBuyout + 1
        else
            results[#results + 1] = {
                count = count,
                buyout = buyoutPrice,
            }
        end
    end

    -- Reset state before callback
    Scanner._active = false
    Scanner._targetItemID = nil
    Scanner._callback = nil

    -- Deliver results
    if callback then
        callback(results, skipped)
    end
end

return Scanner
