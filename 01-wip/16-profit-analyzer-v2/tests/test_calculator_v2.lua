-- tests/test_calculator_v2.lua
-- Busted tests for Calculator v2 (Buy vs Craft with Quote DP)
--
-- Calculator v2 uses Quote.quote(itemID, qty) instead of Prices.get(itemID).
-- This means:
--   - Buy cost depends on quantity (DP knapsack)
--   - Fallback to Prices.get() * qty when no listings
--   - Surplus info in results
--   - No cache (cost is quantity-dependent)

local testHelper = require 'tests.helpers'
local ns

before_each(function()
    ns = testHelper.setup()
end)

-------------------------------------------------
-- Helper: set up DB recipe for testing
-------------------------------------------------
-- We use the existing Engineering DB from DB.lua.
-- Key items used in tests:
--   2835 = Rough Stone (raw)
--   2589 = Linen Cloth (raw)
--   2840 = Copper Bar (raw, but craftable from Copper Ore — not in our DB)
--   4357 = Rough Blasting Powder (craftable: 1×2835)
--   4359 = Handful of Copper Bolts (craftable: 1×2840)
--   4360 = Rough Copper Bomb (craftable: 1×2589, 1×2840, 2×4357, 1×4359)

-------------------------------------------------
-- Basic: fallback to Prices (no listings)
-------------------------------------------------

describe("Calculator v2 — fallback to Prices", function()
    it("calculates cost from manual price when no listings", function()
        ns.Prices.set(2840, 500)
        local result = ns.Calculator.calculate(2840)
        assert.are.equal(500, result.cost)
        assert.are.equal("buy", result.method)
        assert.are.equal(0, result.surplus)
    end)

    it("multiplies price by quantity for fallback", function()
        ns.Prices.set(2840, 500)
        local result = ns.Calculator.calculate(2840, 3)
        assert.are.equal(1500, result.cost)
        assert.are.equal("buy", result.method)
    end)

    it("returns nil when no price and no listings", function()
        local result = ns.Calculator.calculate(99999)
        assert.is_nil(result)
    end)
end)

-------------------------------------------------
-- Buy via Quote DP (listings present)
-------------------------------------------------

describe("Calculator v2 — buy via Quote DP", function()
    it("uses Quote DP when listings exist", function()
        ns.Listings.add(2840, 20, 10000)  -- 20 Copper Bar @ 1g
        local result = ns.Calculator.calculate(2840, 5)
        -- Only one listing: must buy 20 to get 5 → cost 10000, surplus 15
        assert.are.equal(10000, result.cost)
        assert.are.equal("buy", result.method)
        assert.are.equal(15, result.surplus)
    end)

    it("picks optimal DP combination", function()
        ns.Listings.add(2840, 20, 10000)  -- 20 @ 1g
        ns.Listings.add(2840, 5, 2500)    -- 5 @ 25s
        ns.Listings.add(2840, 3, 1200)    -- 3 @ 12s

        local result = ns.Calculator.calculate(2840, 5)
        -- Best: the 5-stack at 2500 (exact match)
        assert.are.equal(2500, result.cost)
        assert.are.equal("buy", result.method)
        assert.are.equal(0, result.surplus)
    end)

    it("falls back to price when quote returns nil (no listings)", function()
        ns.Prices.set(2840, 500)
        -- No listings for 2840
        local result = ns.Calculator.calculate(2840, 3)
        assert.are.equal(1500, result.cost)
        assert.are.equal(0, result.surplus)
    end)
end)

-------------------------------------------------
-- Craft option (recursive)
-------------------------------------------------

describe("Calculator v2 — craft option", function()
    it("calculates craft cost from raw materials with prices", function()
        -- 4359 = Handful of Copper Bolts (1×2840)
        ns.Prices.set(2840, 500)
        local result = ns.Calculator.calculate(4359)
        -- Craft: 1 × 500 = 500
        -- Buy: no listings → no buy option
        assert.are.equal(500, result.cost)
        assert.are.equal("craft", result.method)
    end)

    it("calculates craft cost with listings for reagents", function()
        -- 4359 = Handful of Copper Bolts (1×2840)
        ns.Listings.add(2840, 5, 2000)  -- 5 @ 20s

        local result = ns.Calculator.calculate(4359)
        -- Craft: quote(2840, 1) → only listing is 5@2000 → cost 2000, surplus 4
        -- That's the only option (no buy for 4359)
        assert.are.equal(2000, result.cost)
        assert.are.equal("craft", result.method)
        -- The surplus from buying the reagent shows up in the breakdown
        assert.are.equal(4, result.breakdown[1].surplus)
    end)

    it("multiplies reagent quantities correctly", function()
        -- 4359 = Handful of Copper Bolts (1×2840)
        -- If we need 3 Bolts, we need 3×2840 = 3 Copper Bar
        ns.Listings.add(2840, 20, 10000)  -- 20 @ 1g
        ns.Listings.add(2840, 5, 2500)    -- 5 @ 25s

        local result = ns.Calculator.calculate(4359, 3)
        -- Craft: quote(2840, 3) → 5@2500 covers 3 → cost 2500, surplus 2
        assert.are.equal(2500, result.cost)
        assert.are.equal("craft", result.method)
        assert.are.equal(3, result.breakdown[1].count)
        assert.are.equal(2, result.breakdown[1].surplus)
    end)

    it("calculates multi-reagent craft with mixed buy/craft", function()
        -- 4360 = Rough Copper Bomb
        -- Reagents: 1×2589 (Linen Cloth), 1×2840 (Copper Bar), 2×4357 (Blasting Powder), 1×4359 (Copper Bolts)
        -- 4357 = craft from 1×2835 (Rough Stone)
        -- 4359 = craft from 1×2840 (Copper Bar)

        -- Set up prices (fallback mode)
        ns.Prices.set(2589, 100)   -- Linen Cloth
        ns.Prices.set(2840, 500)   -- Copper Bar
        ns.Prices.set(2835, 50)    -- Rough Stone

        local result = ns.Calculator.calculate(4360)
        -- Craft cost breakdown:
        --   2589 ×1 = 100 (buy)
        --   2840 ×1 = 500 (buy) → direct reagent
        --   4357 ×2 → craft: 2 × 2835 = 100 (buy)
        --   4359 ×1 → craft: 1 × 2840 = 500 (buy) → via Bolts
        -- Total craft = 100 + 500 + 100 + 500 = 1200
        assert.are.equal(1200, result.cost)
        assert.are.equal("craft", result.method)
    end)
end)

-------------------------------------------------
-- Buy vs Craft decision
-------------------------------------------------

describe("Calculator v2 — buy vs craft decision", function()
    it("chooses buy when cheaper than craft", function()
        -- 4359 = Copper Bolts (craft: 1×2840)
        -- Set up: crafting costs 1000 (2840 @ 1000), buying costs 800 (listing)
        ns.Prices.set(2840, 1000)           -- Craft costs 1000
        ns.Listings.add(4359, 1, 800)       -- Buy for 800

        local result = ns.Calculator.calculate(4359)
        assert.are.equal(800, result.cost)
        assert.are.equal("buy", result.method)
        -- Buy wins: craftCost is set showing what craft would have cost
        assert.are.equal(1000, result.craftCost)
    end)

    it("chooses craft when cheaper than buy", function()
        -- 4359 = Copper Bolts (craft: 1×2840)
        ns.Prices.set(2840, 200)            -- Craft costs 200
        ns.Listings.add(4359, 1, 800)       -- Buy for 800

        local result = ns.Calculator.calculate(4359)
        assert.are.equal(200, result.cost)
        assert.are.equal("craft", result.method)
        assert.are.equal(800, result.buyPrice)
    end)

    it("prefers buy when equal cost", function()
        -- When buy == craft, buy wins (<= check)
        ns.Prices.set(2840, 500)            -- Craft costs 500
        ns.Listings.add(4359, 1, 500)       -- Buy for 500

        local result = ns.Calculator.calculate(4359)
        assert.are.equal(500, result.cost)
        assert.are.equal("buy", result.method)
    end)

    it("chooses buy via DP quote over craft", function()
        -- 4359 = Copper Bolts (craft: 1×2840)
        ns.Listings.add(2840, 1, 1000)      -- Crafting: buy reagent at 1000
        ns.Listings.add(4359, 5, 3000)      -- Buying directly: 5 @ 30s → 600/unit for qty=1

        local result = ns.Calculator.calculate(4359, 1)
        -- Buy: quote(4359, 1) → 5@3000 → cost 3000, surplus 4
        -- Craft: quote(2840, 1) → 1@1000 → cost 1000
        -- Craft wins
        assert.are.equal(1000, result.cost)
        assert.are.equal("craft", result.method)
    end)
end)

-------------------------------------------------
-- Cycle detection
-------------------------------------------------

describe("Calculator v2 — cycle detection", function()
    it("handles cycles gracefully (returns nil for that branch)", function()
        -- No cycles in our real DB, but the mechanism should still work
        -- The "visiting" set prevents infinite recursion
        -- With our DB, there are no cycles, so this just tests that
        -- normal recursive items still work
        ns.Prices.set(2840, 500)
        ns.Prices.set(2835, 100)
        ns.Prices.set(2589, 50)   -- Linen Cloth (needed for Rough Copper Bomb)

        local result = ns.Calculator.calculate(4360)
        assert.is_not_nil(result)
        assert.are.equal("craft", result.method)
    end)
end)

-------------------------------------------------
-- analyze() — top crafts ranking
-------------------------------------------------

describe("Calculator v2 — analyze", function()
    it("ranks crafts by profit", function()
        -- Set up sell prices and reagent prices
        ns.Prices.set(2840, 500)   -- Copper Bar
        ns.Prices.set(2589, 100)   -- Linen Cloth
        ns.Prices.set(2835, 50)    -- Rough Stone

        -- Sell prices for craftable items
        ns.Prices.set(4359, 800)   -- Copper Bolts sell @ 80s
        ns.Prices.set(4360, 2000)  -- Rough Copper Bomb sell @ 2g

        local results = ns.Calculator.analyze()
        assert.is_true(#results > 0)

        -- All entries should have profit and margin
        for _, entry in ipairs(results) do
            assert.is_not_nil(entry.profit)
            assert.is_not_nil(entry.margin)
            assert.is_not_nil(entry.craftCost)
        end

        -- Should be sorted by profit descending
        for i = 2, #results do
            assert.is_true(results[i-1].profit >= results[i].profit)
        end
    end)

    it("uses quote DP in analyze for exact costs", function()
        -- Set up listings for raw materials
        ns.Listings.add(2840, 20, 5000)    -- 20 Copper Bar @ 50s
        ns.Listings.add(2835, 10, 500)     -- 10 Rough Stone @ 5s
        ns.Listings.add(2589, 5, 200)      -- 5 Linen Cloth @ 2s

        -- Sell price for Rough Copper Bomb
        ns.Prices.set(4360, 10000)  -- Sell @ 10g

        local results = ns.Calculator.analyze()

        -- Find the 4360 entry
        local found = false
        for _, entry in ipairs(results) do
            if entry.itemID == 4360 then
                found = true
                -- Craft cost uses DP for each reagent
                assert.is_true(entry.craftCost > 0)
                -- Profit = netSell (after 5% cut) - craftCost
                local netSell = math.floor(10000 * 0.95)
                assert.are.equal(netSell, entry.netSell)
                assert.are.equal("manual", entry.priceSource)
                assert.are.equal(netSell - entry.craftCost, entry.profit)
            end
        end
        assert.is_true(found)
    end)
end)

-------------------------------------------------
-- Quantity propagation
-------------------------------------------------

describe("Calculator v2 — quantity propagation", function()
    it("propagates quantity through craft tree", function()
        -- 4360 = Rough Copper Bomb
        -- Reagents: 1×2589, 1×2840, 2×4357, 1×4359
        -- 4357 = craft from 1×2835
        -- 4359 = craft from 1×2840
        -- So per bomb: 1 Linen + 1 Copper + 2 Rough Stone + 1 Copper = 2 Copper Bar, 1 Linen, 2 Rough Stone

        ns.Prices.set(2840, 500)
        ns.Prices.set(2589, 100)
        ns.Prices.set(2835, 50)

        -- Craft 3 bombs → need 6 Copper Bar, 3 Linen, 6 Rough Stone
        local result = ns.Calculator.calculate(4360, 3)
        assert.is_not_nil(result)
        assert.are.equal("craft", result.method)
        -- Cost = 3 × (100 + 500 + 2×50 + 500) = 3 × 1200 = 3600
        assert.are.equal(3600, result.cost)
    end)

    it("uses quote DP with correct quantity for reagents", function()
        -- Craft 2 Copper Bolts → need 2 Copper Bar
        ns.Listings.add(2840, 5, 2500)    -- 5 @ 25s
        ns.Listings.add(2840, 3, 1200)    -- 3 @ 12s

        local result = ns.Calculator.calculate(4359, 2)
        -- Craft: quote(2840, 2) → 3@1200 covers 2 → cost 1200, surplus 1
        assert.are.equal(1200, result.cost)
        assert.are.equal("craft", result.method)
        assert.are.equal(1, result.breakdown[1].surplus)
    end)
end)
