-- tests/test_scanner.lua
-- Unit tests for the Scanner module (AH Scanner v1).
-- All WoW API calls are mocked via the WoW seam.

local assert = require("luassert")
local busted = require("busted")
local describe, it, before_each, after_each =
    busted.describe, busted.it, busted.before_each, busted.after_each

local helpers = require("tests.helpers")

describe("Scanner", function()
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
                    [4357] = "Rough Blasting Powder",
                }
                return items[itemID]
            end,
            CanSendAuctionQuery = function() return true end,
            QueryAuctionItems = function() end,
            GetNumAuctionItems = function() return 0, 0 end,
            GetAuctionItemInfo = function() return nil end,
        }
        ns.WoW.init(mockEnv)
    end)

    after_each(function()
        -- Reset scanner state between tests
        ns.Scanner._active = false
        ns.Scanner._targetItemID = nil
        ns.Scanner._callback = nil
    end)

    -------------------------------------------------
    -- scan() — start a scan
    -------------------------------------------------
    describe("scan()", function()

        it("returns true when scan starts successfully", function()
            local ok, err = ns.Scanner.scan(2840, function() end)
            assert.is_true(ok)
            assert.is_nil(err)
            assert.is_true(ns.Scanner.isActive())
        end)

        it("returns false if item not in cache", function()
            -- Remove GetItemInfo to simulate cache miss
            ns.WoW.GetItemInfo = function() return nil end

            local ok, err = ns.Scanner.scan(99999, function() end)
            assert.is_false(ok)
            assert.truthy(err:match("not in cache"))
            assert.is_false(ns.Scanner.isActive())
        end)

        it("returns false if AH query throttled", function()
            ns.WoW.CanSendAuctionQuery = function() return false end

            local ok, err = ns.Scanner.scan(2840, function() end)
            assert.is_false(ok)
            assert.truthy(err:match("not ready"))
        end)

        it("returns false if already scanning", function()
            ns.Scanner.scan(2840, function() end)

            local ok, err = ns.Scanner.scan(2589, function() end)
            assert.is_false(ok)
            assert.truthy(err:match("already in progress"))
        end)

        it("calls QueryAuctionItems with exact name and exactMatch=true", function()
            local captured = {}
            ns.WoW.QueryAuctionItems = function(text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)
                captured = { text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData }
            end

            ns.Scanner.scan(2840, function() end)

            assert.equal("Copper Bar", captured[1])     -- text = item name
            assert.is_nil(captured[2])                   -- minLevel = nil
            assert.is_nil(captured[3])                   -- maxLevel = nil
            assert.equal(0, captured[4])                 -- page = 0
            assert.is_nil(captured[5])                   -- usable = nil
            assert.is_nil(captured[6])                   -- rarity = nil
            assert.is_false(captured[7])                 -- getAll = false
            assert.is_true(captured[8])                  -- exactMatch = true
            assert.is_nil(captured[9])                   -- filterData = nil
        end)

        it("stores targetItemID for status queries", function()
            ns.Scanner.scan(2840, function() end)
            assert.equal(2840, ns.Scanner.getTargetItemID())
        end)

    end)

    -------------------------------------------------
    -- onItemListUpdate() — process results
    -------------------------------------------------
    describe("onItemListUpdate()", function()

        it("does nothing when no scan is active", function()
            -- Should not error
            ns.Scanner.onItemListUpdate()
        end)

        it("collects listings with buyoutPrice > 0 matching target itemID", function()
            local received = nil
            local callback = function(results, skipped)
                received = { results = results, skipped = skipped }
            end

            -- Mock AH results
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

            -- Start scan, then simulate event
            ns.Scanner.scan(2840, callback)
            ns.Scanner.onItemListUpdate()

            -- Should have 2 valid listings
            assert.is_not_nil(received)
            assert.equal(2, #received.results)
            assert.equal(20, received.results[1].count)
            assert.equal(50000, received.results[1].buyout)
            assert.equal(1, received.results[2].count)
            assert.equal(300, received.results[2].buyout)

            -- Should have skipped 1 wrong item + 1 no buyout
            assert.equal(1, received.skipped.wrongItem)
            assert.equal(1, received.skipped.noBuyout)

            -- Scanner should be inactive after callback
            assert.is_false(ns.Scanner.isActive())
        end)

        it("handles empty results", function()
            local received = nil
            ns.WoW.GetNumAuctionItems = function() return 0, 0 end

            ns.Scanner.scan(2840, function(results, skipped)
                received = { results = results, skipped = skipped }
            end)
            ns.Scanner.onItemListUpdate()

            assert.is_not_nil(received)
            assert.equal(0, #received.results)
            assert.equal(0, received.skipped.wrongItem)
            assert.equal(0, received.skipped.noBuyout)
        end)

        it("resets state after callback even if callback is nil", function()
            ns.WoW.GetNumAuctionItems = function() return 0, 0 end

            ns.Scanner.scan(2840, nil)  -- nil callback
            ns.Scanner.onItemListUpdate()

            assert.is_false(ns.Scanner.isActive())
        end)

        it("skips entries with hasAllInfo=false", function()
            local received = nil
            ns.WoW.GetNumAuctionItems = function() return 2, 2 end
            ns.WoW.GetAuctionItemInfo = function(list, index)
                if index == 1 then
                    -- Complete entry, valid
                    return "Copper Bar", nil, 5, 1, true, 0, "", 0, 0, 1000, 0, false, nil, "Seller", nil, 0, 2840, true
                else
                    -- Incomplete entry — should be skipped
                    return "Copper Bar", nil, 10, 1, true, 0, "", 0, 0, 2000, 0, false, nil, "Seller", nil, 0, 2840, false
                end
            end

            ns.Scanner.scan(2840, function(results, skipped)
                received = { results = results, skipped = skipped }
            end)
            ns.Scanner.onItemListUpdate()

            assert.is_not_nil(received)
            assert.equal(1, #received.results)  -- only the complete entry
            assert.equal(5, received.results[1].count)
        end)

    end)

    -------------------------------------------------
    -- cancel() — cancel a stuck scan
    -------------------------------------------------
    describe("cancel()", function()

        it("returns false when nothing is active", function()
            local cancelled = ns.Scanner.cancel()
            assert.is_false(cancelled)
        end)

        it("returns true and resets state when scan is active", function()
            ns.Scanner.scan(2840, function() end)
            assert.is_true(ns.Scanner.isActive())

            local cancelled = ns.Scanner.cancel()
            assert.is_true(cancelled)
            assert.is_false(ns.Scanner.isActive())
            assert.is_nil(ns.Scanner.getTargetItemID())
        end)

        it("calls callback with cancelled flag", function()
            local received = nil
            ns.Scanner.scan(2840, function(results, skipped)
                received = { results = results, skipped = skipped }
            end)

            ns.Scanner.cancel()

            assert.is_not_nil(received)
            assert.equal(0, #received.results)
            assert.is_true(received.skipped.cancelled)
            assert.equal(2840, received.skipped.itemID)
        end)

        it("does not call callback if callback is nil", function()
            ns.Scanner.scan(2840, nil)
            -- Should not error
            ns.Scanner.cancel()
            assert.is_false(ns.Scanner.isActive())
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

        it("auto-cancels active scan when AH closes", function()
            ns.Scanner.setAHOpen(true)
            ns.Scanner.scan(2840, function() end)
            assert.is_true(ns.Scanner.isActive())

            ns.Scanner.setAHOpen(false)
            assert.is_false(ns.Scanner.isActive())
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
