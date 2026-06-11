-- tests/test_scanner.lua
-- Unit tests for the Scanner module (AH Scanner v2).
-- Pagination, throttling, queue.
-- All WoW API calls are mocked via the WoW seam.

local assert = require("luassert")
local busted = require("busted")
local describe, it, before_each, after_each =
    busted.describe, busted.it, busted.before_each, busted.after_each

local helpers = require("tests.helpers")

describe("Scanner v2", function()
    local ns, mockEnv

    before_each(function()
        -- Reset WoW seam + all modules
        ns = helpers.setup()

        -- Mock WoW AH functions
        mockEnv = {
            print = function() end,
            wipe = wipe,
            GetItemInfo = function(itemID)
                local items = {
                    [2840] = "Copper Bar",
                    [2589] = "Linen Cloth",
                    [2835] = "Rough Stone",
                    [4357] = "Rough Blasting Powder",
                }
                return items[itemID]
            end,
            CanSendAuctionQuery = function() return true end,
            QueryAuctionItems = function() end,
            GetNumAuctionItems = function() return 0, 0 end,
            GetAuctionItemInfo = function() return nil end,
            CreateFrame = function() return nil end,
        }
        ns.WoW.init(mockEnv)

        -- Reset scanner state
        ns.Scanner._active = false
        ns.Scanner._ahOpen = false
        ns.Scanner._targetItemID = nil
        ns.Scanner._callback = nil
        ns.Scanner._queue = {}
        ns.Scanner._currentPage = 0
        ns.Scanner._totalAuctions = 0
        ns.Scanner._accumulated = {}
        ns.Scanner._waitingForThrottle = false
    end)

    after_each(function()
        ns.Scanner._active = false
        ns.Scanner._ahOpen = false
        ns.Scanner._targetItemID = nil
        ns.Scanner._callback = nil
        ns.Scanner._queue = {}
    end)

    -------------------------------------------------
    -- scan() — start a scan
    -------------------------------------------------
    describe("scan()", function()

        it("returns true when scan starts successfully (AH open)", function()
            ns.Scanner.setAHOpen(true)
            local ok, err = ns.Scanner.scan(2840, function() end)
            assert.is_true(ok)
            assert.is_nil(err)
            assert.is_true(ns.Scanner.isActive())
        end)

        it("returns false if item not in cache", function()
            ns.Scanner.setAHOpen(true)
            ns.WoW.GetItemInfo = function() return nil end

            local ok, err = ns.Scanner.scan(99999, function() end)
            assert.is_false(ok)
            assert.truthy(err:match("not in cache"))
            assert.is_false(ns.Scanner.isActive())
        end)

        it("returns false if AH not open", function()
            ns.Scanner.setAHOpen(false)
            local ok, err = ns.Scanner.scan(2840, function() end)
            assert.is_false(ok)
            assert.truthy(err:match("not open"))
        end)

        it("queues when scan is already active (returns true)", function()
            ns.Scanner.setAHOpen(true)
            ns.Scanner.scan(2840, function() end)

            assert.is_true(ns.Scanner.isActive())
            local ok = ns.Scanner.scan(2589, function() end)
            assert.is_true(ok)  -- queued, not rejected
            assert.equal(1, ns.Scanner.getQueueSize())
        end)

        it("calls QueryAuctionItems with exact name, exactMatch=true, page 0", function()
            ns.Scanner.setAHOpen(true)
            local captured = {}
            ns.WoW.QueryAuctionItems = function(text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)
                captured = { text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData }
            end

            ns.Scanner.scan(2840, function() end)

            assert.equal("Copper Bar", captured[1])
            assert.equal(0, captured[4])                 -- page = 0
            assert.is_true(captured[8])                  -- exactMatch = true
        end)

        it("stores targetItemID for status queries", function()
            ns.Scanner.setAHOpen(true)
            ns.Scanner.scan(2840, function() end)
            assert.equal(2840, ns.Scanner.getTargetItemID())
        end)

    end)

    -------------------------------------------------
    -- onItemListUpdate() — single page results
    -------------------------------------------------
    describe("onItemListUpdate()", function()

        it("does nothing when no scan is active", function()
            ns.Scanner.onItemListUpdate()
        end)

        it("collects listings with buyoutPrice > 0 matching target itemID", function()
            ns.Scanner.setAHOpen(true)
            local received = nil
            local callback = function(results, skipped, meta)
                received = { results = results, skipped = skipped, meta = meta }
            end

            -- Mock AH results (1 page, 4 items)
            ns.WoW.GetNumAuctionItems = function() return 4, 4 end
            ns.WoW.GetAuctionItemInfo = function(list, index)
                local items = {
                    -- Good: Copper Bar, stack of 20, buyout 5g
                    { "Copper Bar", nil, 20, 1, true, 0, "", 0, 0, 50000, 0, false, nil, "Seller", nil, 0, 2840, true },
                    -- Good: Copper Bar, stack of 1, buyout 3s
                    { "Copper Bar", nil, 1, 1, true, 0, "", 0, 0, 300, 0, false, nil, "Seller", nil, 0, 2840, true },
                    -- Bad: recipe "Copper Bar" (wrong itemID)
                    { "Copper Bar", nil, 1, 1, true, 0, "", 0, 0, 100, 0, false, nil, "Seller", nil, 0, 2589, true },
                    -- Bad: no buyout (bid only)
                    { "Copper Bar", nil, 5, 1, true, 0, "", 200, 50, 0, 200, false, nil, "Seller", nil, 0, 2840, true },
                }
                local item = items[index]
                if not item then return nil end
                return item[1], item[2], item[3], item[4], item[5], item[6],
                       item[7], item[8], item[9], item[10], item[11], item[12],
                       item[13], item[14], item[15], item[16], item[17], item[18]
            end

            ns.Scanner.scan(2840, callback)
            ns.Scanner.onItemListUpdate()

            assert.is_not_nil(received)
            assert.equal(2, #received.results)
            assert.equal(20, received.results[1].count)
            assert.equal(50000, received.results[1].buyout)
            assert.equal(1, received.results[2].count)
            assert.equal(300, received.results[2].buyout)

            assert.equal(1, received.skipped.wrongItem)
            assert.equal(1, received.skipped.noBuyout)

            -- Meta should report pages
            assert.equal(2840, received.meta.itemID)
            assert.equal(1, received.meta.pages)
            assert.equal(4, received.meta.totalAuctions)

            assert.is_false(ns.Scanner.isActive())
        end)

        it("handles empty results", function()
            ns.Scanner.setAHOpen(true)
            local received = nil
            ns.WoW.GetNumAuctionItems = function() return 0, 0 end

            ns.Scanner.scan(2840, function(results, skipped, meta)
                received = { results = results, skipped = skipped, meta = meta }
            end)
            ns.Scanner.onItemListUpdate()

            assert.is_not_nil(received)
            assert.equal(0, #received.results)
            assert.equal(1, received.meta.pages)  -- ceil(0/50) = 0 → min 1
        end)

        it("resets state after callback even if callback is nil", function()
            ns.Scanner.setAHOpen(true)
            ns.WoW.GetNumAuctionItems = function() return 0, 0 end

            ns.Scanner.scan(2840, nil)
            ns.Scanner.onItemListUpdate()

            assert.is_false(ns.Scanner.isActive())
        end)

        it("skips entries with hasAllInfo=false", function()
            ns.Scanner.setAHOpen(true)
            local received = nil
            ns.WoW.GetNumAuctionItems = function() return 2, 2 end
            ns.WoW.GetAuctionItemInfo = function(list, index)
                if index == 1 then
                    return "Copper Bar", nil, 5, 1, true, 0, "", 0, 0, 1000, 0, false, nil, "Seller", nil, 0, 2840, true
                else
                    return "Copper Bar", nil, 10, 1, true, 0, "", 0, 0, 2000, 0, false, nil, "Seller", nil, 0, 2840, false
                end
            end

            ns.Scanner.scan(2840, function(results, skipped, meta)
                received = { results = results, skipped = skipped, meta = meta }
            end)
            ns.Scanner.onItemListUpdate()

            assert.is_not_nil(received)
            assert.equal(1, #received.results)
            assert.equal(5, received.results[1].count)
        end)

    end)

    -------------------------------------------------
    -- Pagination
    -------------------------------------------------
    describe("pagination", function()

        it("requests next page when totalAuctions > 50", function()
            ns.Scanner.setAHOpen(true)
            local queryCalls = {}
            ns.WoW.QueryAuctionItems = function(text, minL, maxL, page, ...)
                queryCalls[#queryCalls + 1] = page
            end

            -- Page 0: 50 results, totalAuctions = 120
            ns.WoW.GetNumAuctionItems = function() return 50, 120 end
            ns.WoW.GetAuctionItemInfo = function(list, index)
                return "Copper Bar", nil, 1, 1, true, 0, "", 0, 0, 100, 0, false, nil, "Seller", nil, 0, 2840, true
            end

            local received = nil
            ns.Scanner.scan(2840, function(results, skipped, meta)
                received = { results = results, skipped = skipped, meta = meta }
            end)

            -- After page 0 arrives
            ns.Scanner.onItemListUpdate()

            -- After page 0 arrives, since CanSendAuctionQuery returns true,
            -- page 1 is requested immediately via _requestNextPage
            assert.equal(2, #queryCalls)  -- page 0 (initial) + page 1 (auto)
            -- Scanner should still be active (more pages)
            assert.is_true(ns.Scanner.isActive())
            assert.equal(1, ns.Scanner._currentPage)

            -- Simulate page 1 arrival: 50 results, totalAuctions still 120
            ns.WoW.GetNumAuctionItems = function() return 50, 120 end
            ns.Scanner.onItemListUpdate()

            -- Should be on page 2 now
            assert.equal(2, ns.Scanner._currentPage)

            -- Simulate page 2: 20 results (last page)
            ns.WoW.GetNumAuctionItems = function() return 20, 120 end
            ns.Scanner.onItemListUpdate()

            -- Now should be done
            assert.is_false(ns.Scanner.isActive())
            assert.is_not_nil(received)
            -- Total results: 50 + 50 + 20 = 120
            assert.equal(120, #received.results)
            assert.equal(3, received.meta.pages)
        end)

        it("does not paginate when totalAuctions <= 50", function()
            ns.Scanner.setAHOpen(true)
            local queryCalls = {}
            ns.WoW.QueryAuctionItems = function(text, minL, maxL, page, ...)
                queryCalls[#queryCalls + 1] = page
            end

            ns.WoW.GetNumAuctionItems = function() return 30, 30 end
            ns.WoW.GetAuctionItemInfo = function(list, index)
                return "Copper Bar", nil, 1, 1, true, 0, "", 0, 0, 100, 0, false, nil, "Seller", nil, 0, 2840, true
            end

            local received = nil
            ns.Scanner.scan(2840, function(results, skipped, meta)
                received = { results = results, skipped = skipped, meta = meta }
            end)

            ns.Scanner.onItemListUpdate()

            assert.is_false(ns.Scanner.isActive())
            assert.equal(30, #received.results)
            assert.equal(1, received.meta.pages)
        end)

        it("caps last page to actual remaining items (stale buffer fix)", function()
            -- Bug: GetNumAuctionItems returns 50 even on the last page,
            -- but stale data from previous pages fills the extra slots.
            -- With 75 total items: page 0 has 50, page 1 should read 25.
            ns.Scanner.setAHOpen(true)

            ns.WoW.GetAuctionItemInfo = function(list, index)
                -- All entries look valid (stale ones too)
                return "Copper Bar", nil, 1, 1, true, 0, "", 0, 0, 100, 0, false, nil, "Seller", nil, 0, 2840, true
            end

            local received = nil
            ns.Scanner.scan(2840, function(results, skipped, meta)
                received = { results = results, skipped = skipped, meta = meta }
            end)

            -- Page 0: 50 results, total = 75
            ns.WoW.GetNumAuctionItems = function() return 50, 75 end
            ns.Scanner.onItemListUpdate()

            assert.is_true(ns.Scanner.isActive())

            -- Page 1: buffer says 50, but only 25 are real
            -- Without the fix, we'd read 50 → total 100
            -- With the fix, we cap to 75 - 1*50 = 25 → total 75
            ns.WoW.GetNumAuctionItems = function() return 50, 75 end
            ns.Scanner.onItemListUpdate()

            assert.is_false(ns.Scanner.isActive())
            assert.is_not_nil(received)
            assert.equal(75, #received.results)  -- NOT 100!
            assert.equal(2, received.meta.pages)
            assert.equal(75, received.meta.totalAuctions)
        end)

        it("caps last page for 134 items (3 pages)", function()
            ns.Scanner.setAHOpen(true)

            ns.WoW.GetAuctionItemInfo = function(list, index)
                return "Linen Cloth", nil, 1, 1, true, 0, "", 0, 0, 50, 0, false, nil, "Seller", nil, 0, 2589, true
            end

            local received = nil
            ns.Scanner.scan(2589, function(results, skipped, meta)
                received = { results = results, skipped = skipped, meta = meta }
            end)

            -- Page 0: 50 items, total = 134
            ns.WoW.GetNumAuctionItems = function() return 50, 134 end
            ns.Scanner.onItemListUpdate()
            assert.is_true(ns.Scanner.isActive())

            -- Page 1: 50 items, total = 134
            ns.WoW.GetNumAuctionItems = function() return 50, 134 end
            ns.Scanner.onItemListUpdate()
            assert.is_true(ns.Scanner.isActive())

            -- Page 2: buffer says 50, but only 34 are real
            ns.WoW.GetNumAuctionItems = function() return 50, 134 end
            ns.Scanner.onItemListUpdate()

            assert.is_false(ns.Scanner.isActive())
            assert.is_not_nil(received)
            assert.equal(134, #received.results)  -- NOT 150!
            assert.equal(3, received.meta.pages)
        end)

    end)

    -------------------------------------------------
    -- Throttling
    -------------------------------------------------
    describe("throttling", function()

        it("waits when CanSendAuctionQuery returns false during pagination", function()
            ns.Scanner.setAHOpen(true)

            local queryCalls = {}
            ns.WoW.QueryAuctionItems = function(text, minL, maxL, page, ...)
                queryCalls[#queryCalls + 1] = page
            end

            -- Page 0: succeeds (CanSendAuctionQuery = true)
            ns.WoW.GetNumAuctionItems = function() return 50, 120 end
            ns.WoW.GetAuctionItemInfo = function(list, index)
                return "Copper Bar", nil, 1, 1, true, 0, "", 0, 0, 100, 0, false, nil, "Seller", nil, 0, 2840, true
            end

            ns.Scanner.scan(2840, function() end)
            assert.equal(0, queryCalls[#queryCalls])  -- page 0 sent

            -- Now throttle: CanSendAuctionQuery = false
            ns.WoW.CanSendAuctionQuery = function() return false end

            ns.Scanner.onItemListUpdate()

            -- Scanner should be waiting for throttle
            assert.is_true(ns.Scanner._waitingForThrottle)
            assert.is_true(ns.Scanner.isActive())
            assert.equal(1, ns.Scanner._currentPage)

            -- Now throttle clears
            ns.WoW.CanSendAuctionQuery = function() return true end
            -- Simulate OnUpdate tick (call the internal logic)
            -- We can't easily call the OnUpdate, but we can call _requestNextPage
            ns.Scanner._waitingForThrottle = false  -- simulate throttle cleared
            ns.Scanner._requestNextPage()

            -- Page 1 should now be sent
            assert.equal(1, queryCalls[#queryCalls])
        end)

    end)

    -------------------------------------------------
    -- Queue
    -------------------------------------------------
    describe("queue", function()

        it("queues multiple items and scans them sequentially", function()
            ns.Scanner.setAHOpen(true)

            local results2840 = nil
            local results2589 = nil
            local results2835 = nil

            -- Start first scan
            ns.Scanner.scan(2840, function(r, s, m) results2840 = r end)
            assert.is_true(ns.Scanner.isActive())
            assert.equal(2840, ns.Scanner.getTargetItemID())

            -- Queue second
            local ok2 = ns.Scanner.scan(2589, function(r, s, m) results2589 = r end)
            assert.is_true(ok2)
            assert.equal(1, ns.Scanner.getQueueSize())

            -- Queue third
            local ok3 = ns.Scanner.scan(2835, function(r, s, m) results2835 = r end)
            assert.is_true(ok3)
            assert.equal(2, ns.Scanner.getQueueSize())

            -- Mock results for page 0 of item 2840 (single page)
            ns.WoW.GetNumAuctionItems = function() return 1, 1 end
            ns.WoW.GetAuctionItemInfo = function()
                return "Copper Bar", nil, 20, 1, true, 0, "", 0, 0, 5000, 0, false, nil, "Seller", nil, 0, 2840, true
            end

            -- Finish first scan
            ns.Scanner.onItemListUpdate()

            -- First item done, second should have started automatically
            assert.is_true(ns.Scanner.isActive())
            assert.equal(2589, ns.Scanner.getTargetItemID())
            assert.equal(1, ns.Scanner.getQueueSize())
            assert.is_not_nil(results2840)
            assert.equal(1, #results2840)

            -- Mock results for item 2589 (single page)
            ns.WoW.GetAuctionItemInfo = function()
                return "Linen Cloth", nil, 5, 1, true, 0, "", 0, 0, 200, 0, false, nil, "Seller", nil, 0, 2589, true
            end

            ns.Scanner.onItemListUpdate()

            -- Second item done, third should have started
            assert.is_true(ns.Scanner.isActive())
            assert.equal(2835, ns.Scanner.getTargetItemID())
            assert.equal(0, ns.Scanner.getQueueSize())
            assert.is_not_nil(results2589)

            -- Mock results for item 2835 (single page)
            ns.WoW.GetAuctionItemInfo = function()
                return "Rough Stone", nil, 10, 1, true, 0, "", 0, 0, 1000, 0, false, nil, "Seller", nil, 0, 2835, true
            end

            ns.Scanner.onItemListUpdate()

            -- All done
            assert.is_false(ns.Scanner.isActive())
            assert.is_not_nil(results2835)
            assert.equal(1, #results2835)
        end)

    end)

    -------------------------------------------------
    -- cancel()
    -------------------------------------------------
    describe("cancel()", function()

        it("returns false when nothing is active", function()
            local cancelled = ns.Scanner.cancel()
            assert.is_false(cancelled)
        end)

        it("returns true and resets state when scan is active", function()
            ns.Scanner.setAHOpen(true)
            ns.Scanner.scan(2840, function() end)
            assert.is_true(ns.Scanner.isActive())

            local cancelled = ns.Scanner.cancel()
            assert.is_true(cancelled)
            assert.is_false(ns.Scanner.isActive())
            assert.is_nil(ns.Scanner.getTargetItemID())
        end)

        it("calls callback with cancelled flag", function()
            ns.Scanner.setAHOpen(true)
            local received = nil
            ns.Scanner.scan(2840, function(results, skipped, meta)
                received = { results = results, skipped = skipped, meta = meta }
            end)

            ns.Scanner.cancel()

            assert.is_not_nil(received)
            assert.equal(0, #received.results)
            assert.is_true(received.skipped.cancelled)
            assert.equal(2840, received.skipped.itemID)
        end)

        it("clears the queue when cancelled", function()
            ns.Scanner.setAHOpen(true)
            ns.Scanner.scan(2840, function() end)
            ns.Scanner.scan(2589, function() end)
            ns.Scanner.scan(2835, function() end)

            assert.equal(2, ns.Scanner.getQueueSize())

            local cancelled, queueSize = ns.Scanner.cancel()
            assert.is_true(cancelled)
            assert.equal(2, queueSize)
            assert.equal(0, ns.Scanner.getQueueSize())
        end)

    end)

    -------------------------------------------------
    -- isAHOpen() / setAHOpen()
    -------------------------------------------------
    describe("isAHOpen()", function()

        it("returns false by default", function()
            assert.is_false(ns.Scanner.isAHOpen())
        end)

        it("returns true after setAHOpen(true)", function()
            ns.Scanner.setAHOpen(true)
            assert.is_true(ns.Scanner.isAHOpen())
        end)

        it("returns false after setAHOpen(false)", function()
            ns.Scanner.setAHOpen(true)
            ns.Scanner.setAHOpen(false)
            assert.is_false(ns.Scanner.isAHOpen())
        end)

        it("auto-cancels active scan + queue when AH closes", function()
            ns.Scanner.setAHOpen(true)
            ns.Scanner.scan(2840, function() end)
            ns.Scanner.scan(2589, function() end)

            assert.is_true(ns.Scanner.isActive())
            assert.equal(1, ns.Scanner.getQueueSize())

            ns.Scanner.setAHOpen(false)
            assert.is_false(ns.Scanner.isActive())
            assert.equal(0, ns.Scanner.getQueueSize())
        end)

    end)

    -------------------------------------------------
    -- getProgress()
    -------------------------------------------------
    describe("getProgress()", function()

        it("returns nil when no scan is active", function()
            assert.is_nil(ns.Scanner.getProgress())
        end)

        it("returns progress info during scan", function()
            ns.Scanner.setAHOpen(true)

            -- Mock: 50 results on page, 120 total
            ns.WoW.GetNumAuctionItems = function() return 50, 120 end
            ns.WoW.GetAuctionItemInfo = function()
                return "Copper Bar", nil, 1, 1, true, 0, "", 0, 0, 100, 0, false, nil, "Seller", nil, 0, 2840, true
            end

            ns.Scanner.scan(2840, function() end)

            -- After page 0 arrives
            ns.Scanner.onItemListUpdate()

            -- Should be waiting for page 1
            local progress = ns.Scanner.getProgress()
            assert.is_not_nil(progress)
            assert.equal(2840, progress.itemID)
            assert.equal(1, progress.currentPage)
            assert.equal(3, progress.totalPages)
            assert.equal(50, progress.listingsFound)
            assert.equal(120, progress.totalAuctions)
        end)

    end)

    -------------------------------------------------
    -- isActive() / getTargetItemID()
    -------------------------------------------------
    describe("isActive()", function()

        it("returns false by default", function()
            assert.is_false(ns.Scanner.isActive())
        end)

        it("returns true during scan, false after results", function()
            ns.Scanner.setAHOpen(true)
            ns.WoW.GetNumAuctionItems = function() return 0, 0 end

            ns.Scanner.scan(2840, function() end)
            assert.is_true(ns.Scanner.isActive())
            assert.equal(2840, ns.Scanner.getTargetItemID())

            ns.Scanner.onItemListUpdate()
            assert.is_false(ns.Scanner.isActive())
            assert.is_nil(ns.Scanner.getTargetItemID())
        end)

    end)

end)
