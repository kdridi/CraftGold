-- tests/test_calculator.lua
-- Tests for Prices and Calculator modules (pure Lua, no WoW API).

local helpers = require("tests/helpers")
local ns = helpers.loadModules(helpers.DEFAULT_ORDER)
local Prices    = ns.Prices
local Calculator = ns.Calculator
local Core      = ns.Core
local DB        = ns.DB

-------------------------------------------------
-- Setup: initialize Prices with a fresh store before each test
-------------------------------------------------

local function resetPrices()
    local freshDB = {}
    Prices.init(freshDB)
end

describe("Prices", function()
    before_each(resetPrices)

    it("stores and retrieves a price", function()
        Prices.set(2840, 1240)
        assert.equals(1240, Prices.get(2840))
    end)

    it("returns nil for unset price", function()
        assert.is_nil(Prices.get(99999))
    end)

    it("removes a price", function()
        Prices.set(2840, 1240)
        Prices.remove(2840)
        assert.is_nil(Prices.get(2840))
    end)

    it("counts prices correctly", function()
        assert.equals(0, Prices.count())
        Prices.set(2840, 1240)
        assert.equals(1, Prices.count())
        Prices.set(2589, 310)
        assert.equals(2, Prices.count())
        Prices.remove(2840)
        assert.equals(1, Prices.count())
    end)

    it("survives init with empty table", function()
        Prices.init({})
        assert.equals(0, Prices.count())
        Prices.set(123, 456)
        assert.equals(456, Prices.get(123))
    end)

    it("survives init with nil", function()
        Prices.init(nil)
        assert.equals(0, Prices.count())
    end)
end)

describe("Calculator — raw materials", function()
    before_each(resetPrices)

    it("returns cost for priced raw material", function()
        Prices.set(2840, 1240) -- Copper Bar = 12s40c
        local r = Calculator.calculate(2840)
        assert.is_not_nil(r)
        assert.equals(1240, r.cost)
        assert.equals("buy", r.method)
    end)

    it("returns nil for unpriced raw material", function()
        assert.is_nil(Calculator.calculate(2840))
    end)

    it("returns nil for unknown item", function()
        assert.is_nil(Calculator.calculate(99999))
    end)
end)

describe("Calculator — simple craft (one reagent)", function()
    before_each(resetPrices)

    it("crafts when no buy price set", function()
        -- Copper Bolts (4359) = 1x Copper Bar (2840)
        Prices.set(2840, 1240)
        local r = Calculator.calculate(4359)
        assert.is_not_nil(r)
        assert.equals(1240, r.cost)
        assert.equals("craft", r.method)
    end)

    it("buys when buy price is cheaper", function()
        Prices.set(2840, 1240)
        Prices.set(4359, 1000) -- buy at 10s < craft at 12s40c
        local r = Calculator.calculate(4359)
        assert.equals(1000, r.cost)
        assert.equals("buy", r.method)
    end)

    it("crafts when craft is cheaper", function()
        Prices.set(2840, 1240)
        Prices.set(4359, 1800) -- buy at 18s > craft at 12s40c
        local r = Calculator.calculate(4359)
        assert.equals(1240, r.cost)
        assert.equals("craft", r.method)
        assert.equals(1800, r.buyPrice) -- stores the buy price for comparison
    end)

    it("returns nil when reagent has no price", function()
        -- Copper Bolts needs Copper Bar, but we don't price it
        local r = Calculator.calculate(4359)
        assert.is_nil(r)
    end)
end)

describe("Calculator — complex craft (multiple reagents)", function()
    before_each(resetPrices)

    it("calculates Copper Modulator cost correctly", function()
        -- Copper Modulator (4363): Linen Cloth x2, Copper Bar x1, Copper Bolts x2
        Prices.set(2589, 310)  -- Linen Cloth = 3s10c
        Prices.set(2840, 1240) -- Copper Bar = 12s40c
        -- Copper Bolts: craft from 1x Copper Bar = 1240c (no buy price)
        local r = Calculator.calculate(4363)
        assert.is_not_nil(r)
        -- 2*310 + 1*1240 + 2*1240 = 620 + 1240 + 2480 = 4340
        assert.equals(4340, r.cost)
        assert.equals("craft", r.method)
        assert.equals(3, #r.breakdown)
    end)

    it("uses buy price for intermediate when cheaper", function()
        Prices.set(2589, 310)
        Prices.set(2840, 1240)
        Prices.set(4359, 500) -- Copper Bolts buy at 5s < craft at 12s40c
        local r = Calculator.calculate(4363)
        assert.is_not_nil(r)
        -- 2*310 + 1*1240 + 2*500 = 620 + 1240 + 1000 = 2860
        assert.equals(2860, r.cost)
    end)
end)

describe("Calculator — cycle detection", function()
    before_each(resetPrices)

    it("detects direct cycle", function()
        -- A → B → A
        DB.recipes[88888] = {
            spellID = 88888, output = 99998,
            reagents = {{99997, 1}}, skillRequired = 1, source = "test"
        }
        DB.recipes[88889] = {
            spellID = 88889, output = 99997,
            reagents = {{99998, 1}}, skillRequired = 1, source = "test"
        }
        -- No prices → cycle can't be resolved
        local r = Calculator.calculate(99998)
        assert.is_nil(r)

        DB.recipes[88888] = nil
        DB.recipes[88889] = nil
    end)

    it("resolves cycle when one item has buy price", function()
        DB.recipes[88888] = {
            spellID = 88888, output = 99998,
            reagents = {{99997, 1}}, skillRequired = 1, source = "test"
        }
        DB.recipes[88889] = {
            spellID = 88889, output = 99997,
            reagents = {{99998, 1}}, skillRequired = 1, source = "test"
        }
        -- Provide a buy price for one of them to break the cycle
        Prices.set(99997, 500)
        local r = Calculator.calculate(99998)
        assert.is_not_nil(r)
        assert.equals(500, r.cost)
        assert.equals("craft", r.method)

        DB.recipes[88888] = nil
        DB.recipes[88889] = nil
    end)

    it("handles self-referencing recipe", function()
        DB.recipes[88890] = {
            spellID = 88890, output = 99999,
            reagents = {{99999, 1}}, skillRequired = 1, source = "test"
        }
        local r = Calculator.calculate(99999)
        assert.is_nil(r)

        DB.recipes[88890] = nil
    end)
end)

describe("Calculator — memoization", function()
    before_each(resetPrices)

    it("returns consistent results for same item", function()
        Prices.set(2840, 1240)
        local r1 = Calculator.calculate(2840)
        local r2 = Calculator.calculate(2840)
        assert.equals(r1.cost, r2.cost)
        assert.equals(r1.method, r2.method)
    end)
end)

describe("Calculator.analyze", function()
    before_each(resetPrices)

    it("finds profitable crafts", function()
        -- Set prices for Copper Modulator recipe
        Prices.set(2589, 310)  -- Linen Cloth
        Prices.set(2840, 1240) -- Copper Bar
        -- Copper Bolts: crafted from Copper Bar (no buy price)
        -- Sell price for Copper Modulator
        Prices.set(4363, 7200) -- 72s

        local results = Calculator.analyze()
        assert.is_true(#results > 0)

        -- Find Copper Modulator
        local found = false
        for _, entry in ipairs(results) do
            if entry.itemID == 4363 then
                found = true
                assert.equals(7200, entry.sellPrice)
                assert.equals(4340, entry.craftCost)
                assert.equals(2860, entry.profit)
                assert.is_true(entry.margin > 0)
                break
            end
        end
        assert.is_true(found)
    end)

    it("returns empty when no sell prices set", function()
        Prices.set(2840, 1240)
        local results = Calculator.analyze()
        assert.equals(0, #results)
    end)

    it("sorts by profit descending", function()
        -- Set up two profitable recipes
        Prices.set(2835, 100)   -- Rough Stone (for Rough Blasting Powder)
        Prices.set(2840, 1240)  -- Copper Bar
        Prices.set(2589, 310)   -- Linen Cloth
        Prices.set(4359, 1800)  -- Copper Bolts buy price

        -- Rough Dynamite (4358) = Linen Cloth + 2x Rough Blasting Powder
        -- Rough Blasting Powder (4357) = 1x Rough Stone → cost = 100
        -- Rough Dynamite cost = 310 + 2*100 = 510
        Prices.set(4358, 2000)  -- sell at 20s, profit = 1490

        -- Copper Modulator cost = 4340
        Prices.set(4363, 7200)  -- sell at 72s, profit = 2860

        local results = Calculator.analyze()
        if #results >= 2 then
            assert.is_true(results[1].profit >= results[2].profit)
        end
    end)
end)

describe("Breakdown structure", function()
    before_each(resetPrices)

    it("contains reagent details", function()
        Prices.set(2840, 1240)
        local r = Calculator.calculate(4359) -- Copper Bolts = 1x Copper Bar
        assert.is_not_nil(r.breakdown)
        assert.equals(1, #r.breakdown)
        assert.equals(2840, r.breakdown[1].itemID)
        assert.equals(1, r.breakdown[1].count)
        assert.equals(1240, r.breakdown[1].unitCost)
        assert.equals(1240, r.breakdown[1].totalCost)
        assert.equals("buy", r.breakdown[1].method)
    end)

    it("has correct multi-reagent breakdown", function()
        Prices.set(2589, 310)
        Prices.set(2840, 1240)
        local r = Calculator.calculate(4363) -- Copper Modulator
        assert.is_not_nil(r.breakdown)
        assert.equals(3, #r.breakdown)

        -- Check Linen Cloth entry
        local linen = r.breakdown[1]
        assert.equals(2589, linen.itemID)
        assert.equals(2, linen.count)
        assert.equals(310, linen.unitCost)
        assert.equals(620, linen.totalCost)
    end)
end)
