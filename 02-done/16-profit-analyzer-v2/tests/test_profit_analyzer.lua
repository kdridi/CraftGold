-- tests/test_profit_analyzer.lua
-- Tests for Capsule 16: Profit Analyzer v2
-- marketPrice, AH commission, price source tracking

local helpers = require 'tests.helpers'

describe("Profit Analyzer v2 — marketPrice", function()
    local ns

    before_each(function()
        ns = helpers.setup()
    end)

    it("returns cheapest unit price from listings", function()
        ns.Listings.add(90001, 20, 10000)  -- 20 @ 1g = 50s/unit
        ns.Listings.add(90001, 5, 2000)    -- 5 @ 20s = 4s/unit
        ns.Listings.add(90001, 1, 300)     -- 1 @ 3s = 3s/unit

        local price, source = ns.Quote.marketPrice(90001)
        assert.are.equal(300, price)
        assert.are.equal("ah", source)
    end)

    it("returns floor of unit price (integer copper)", function()
        ns.Listings.add(90001, 3, 100)     -- 3 @ 1s = 33.33.../unit → floor = 33

        local price, source = ns.Quote.marketPrice(90001)
        assert.are.equal(33, price)
        assert.are.equal("ah", source)
    end)

    it("falls back to manual price when no listings", function()
        ns.Prices.set(90001, 500)

        local price, source = ns.Quote.marketPrice(90001)
        assert.are.equal(500, price)
        assert.are.equal("manual", source)
    end)

    it("prefers listings over manual price", function()
        ns.Listings.add(90001, 10, 1000)   -- 10 @ 10s = 1s/unit
        ns.Prices.set(90001, 500)           -- manual: 5s

        local price, source = ns.Quote.marketPrice(90001)
        assert.are.equal(100, price)        -- AH listing is cheaper
        assert.are.equal("ah", source)
    end)

    it("returns nil when no data available", function()
        local price, source = ns.Quote.marketPrice(99999)
        assert.is_nil(price)
        assert.is_nil(source)
    end)

    it("ignores listings with zero count", function()
        ns.Listings.add(90001, 0, 100)
        ns.Prices.set(90001, 500)

        local price, source = ns.Quote.marketPrice(90001)
        assert.are.equal(500, price)
        assert.are.equal("manual", source)
    end)
end)

describe("Profit Analyzer v2 — analyze with commission", function()
    local ns

    before_each(function()
        ns = helpers.setup()
    end)

    it("applies 5% AH commission to profit", function()
        -- Set up material cost
        ns.Listings.add(2840, 20, 5000)    -- Copper Bar: 20 @ 50s
        ns.Listings.add(2835, 10, 500)     -- Rough Stone: 10 @ 5s
        ns.Listings.add(2589, 5, 200)      -- Linen Cloth: 5 @ 2s

        -- Sell price via AH listing for the craft output
        ns.Listings.add(4360, 1, 10000)    -- Rough Copper Bomb: 1 @ 10g

        local results = ns.Calculator.analyze()

        local entry4360 = nil
        for _, entry in ipairs(results) do
            if entry.itemID == 4360 then
                entry4360 = entry
            end
        end

        assert.is_not_nil(entry4360)
        -- Sell price = 10000 (cheapest unit from listings)
        assert.are.equal(10000, entry4360.sellPrice)
        assert.are.equal("ah", entry4360.priceSource)
        -- Net sell = floor(10000 * 0.95) = 9500
        assert.are.equal(9500, entry4360.netSell)
        -- AH cut = 10000 - 9500 = 500
        assert.are.equal(500, entry4360.ahCut)
        -- Profit = 9500 - craftCost
        assert.are.equal(9500 - entry4360.craftCost, entry4360.profit)
    end)

    it("marks manual price source correctly", function()
        ns.Listings.add(2840, 20, 5000)
        ns.Listings.add(2835, 10, 500)
        ns.Listings.add(2589, 5, 200)

        -- Manual price for the craft output (no listing)
        ns.Prices.set(4360, 10000)

        local results = ns.Calculator.analyze()

        local entry4360 = nil
        for _, entry in ipairs(results) do
            if entry.itemID == 4360 then
                entry4360 = entry
            end
        end

        assert.is_not_nil(entry4360)
        assert.are.equal("manual", entry4360.priceSource)
        -- Still applies commission
        assert.are.equal(9500, entry4360.netSell)
    end)

    it("excludes items with no sell price data", function()
        -- Only set material costs, no sell price for any output
        ns.Listings.add(2840, 20, 5000)

        local results = ns.Calculator.analyze()
        -- Should be empty (no craft output has a sell price)
        for _, entry in ipairs(results) do
            assert.is_not_nil(entry.sellPrice)
            assert.is_true(entry.sellPrice > 0)
        end
    end)

    it("calculates margin correctly after commission", function()
        -- Simple setup: craft costs 1000c, sells for 2000c
        ns.Prices.set(2840, 100)    -- Copper Bar = 1s
        ns.Prices.set(2589, 50)     -- Linen Cloth = 50c
        ns.Prices.set(2835, 10)     -- Rough Stone = 10c

        -- Sell at 2000c via listing
        ns.Listings.add(4360, 1, 2000)

        local results = ns.Calculator.analyze()

        local entry4360 = nil
        for _, entry in ipairs(results) do
            if entry.itemID == 4360 then
                entry4360 = entry
            end
        end

        assert.is_not_nil(entry4360)
        -- Net sell = floor(2000 * 0.95) = 1900
        -- Margin = profit / craftCost * 100
        local expectedMargin = entry4360.profit / entry4360.craftCost * 100
        assert.are.equal(expectedMargin, entry4360.margin)
    end)

    it("shows negative profit when craft costs more than sell price", function()
        -- Expensive materials
        ns.Prices.set(2840, 50000)  -- Copper Bar = 5g
        ns.Prices.set(2589, 10000)  -- Linen Cloth = 1g
        ns.Prices.set(2835, 5000)   -- Rough Stone = 50s

        -- Cheap sell price
        ns.Listings.add(4360, 1, 100)    -- sells for 1s

        local results = ns.Calculator.analyze()

        local entry4360 = nil
        for _, entry in ipairs(results) do
            if entry.itemID == 4360 then
                entry4360 = entry
            end
        end

        assert.is_not_nil(entry4360)
        assert.is_true(entry4360.profit < 0)
    end)

    it("AH cut percent helper returns 5", function()
        assert.are.equal(5, ns.Calculator._getAhCutPercent())
    end)
end)
