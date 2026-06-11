-- tests/test_quote.lua
-- Busted tests for Quote DP (covering knapsack 0/1)

local testHelper = require 'tests.helpers'
local ns

before_each(function()
    ns = testHelper.setup()
end)

describe("Quote.dpCover", function()
    it("returns zero cost for need <= 0", function()
        local result = ns.Quote.dpCover({}, 0)
        assert.are.equal(0, result.cost)
        assert.are.equal(0, #result.basket)
        assert.are.equal(0, result.surplus)

        result = ns.Quote.dpCover({}, -5)
        assert.are.equal(0, result.cost)
    end)

    it("returns nil when no listings and need > 0", function()
        assert.is_nil(ns.Quote.dpCover({}, 5))
        assert.is_nil(ns.Quote.dpCover(nil, 5))
    end)

    it("buys a single exact stack", function()
        local listings = {
            { count = 5, buyout = 1000 },
        }
        local result = ns.Quote.dpCover(listings, 5)
        assert.are.equal(1000, result.cost)
        assert.are.equal(0, result.surplus)
        assert.are.equal(1, #result.basket)
    end)

    it("picks the cheapest exact stack when multiple options exist", function()
        local listings = {
            { count = 5, buyout = 1000 },
            { count = 10, buyout = 1500 },
            { count = 3, buyout = 200 },
        }
        local result = ns.Quote.dpCover(listings, 5)
        -- Stack of 5 at 1000 is exact, cheaper than stack of 10 at 1500
        assert.are.equal(1000, result.cost)
        assert.are.equal(0, result.surplus)
    end)

    it("combines multiple stacks optimally", function()
        local listings = {
            { count = 3, buyout = 300 },
            { count = 4, buyout = 350 },
            { count = 2, buyout = 250 },
        }
        local result = ns.Quote.dpCover(listings, 5)
        -- Best: 3+2=5 at 300+250=550 (exact, no surplus)
        -- vs 3+4=7 at 650, vs 4+2=6 at 600
        assert.are.equal(550, result.cost)
        assert.are.equal(0, result.surplus)
        assert.are.equal(2, #result.basket)
    end)

    it("handles surplus when no exact combination exists", function()
        local listings = {
            { count = 20, buyout = 5000 },
        }
        local result = ns.Quote.dpCover(listings, 5)
        -- Only option: buy 20 at 5000, surplus 15
        assert.are.equal(5000, result.cost)
        assert.are.equal(15, result.surplus)
    end)

    it("returns nil when total available is less than need", function()
        local listings = {
            { count = 2, buyout = 100 },
            { count = 3, buyout = 200 },
        }
        assert.is_nil(ns.Quote.dpCover(listings, 10))
    end)

    it("respects 0/1 constraint (no duplicate from same listing)", function()
        local listings = {
            { count = 2, buyout = 100 },
        }
        -- Only 2 available, can't cover 5
        assert.is_nil(ns.Quote.dpCover(listings, 5))
    end)

    it("chooses cheaper big stack over multiple small stacks", function()
        local listings = {
            { count = 20, buyout = 2000 },  -- 100/unit
            { count = 5, buyout = 600 },     -- 120/unit
            { count = 5, buyout = 600 },     -- 120/unit
            { count = 5, buyout = 600 },     -- 120/unit
            { count = 5, buyout = 600 },     -- 120/unit
        }
        local result = ns.Quote.dpCover(listings, 20)
        -- Big stack: 2000 (exact)
        -- 4 small stacks: 2400 (exact)
        assert.are.equal(2000, result.cost)
        assert.are.equal(0, result.surplus)
    end)

    it("prefers combination over big stack when cheaper", function()
        local listings = {
            { count = 20, buyout = 3000 },  -- 150/unit
            { count = 10, buyout = 1000 },   -- 100/unit
            { count = 10, buyout = 1000 },   -- 100/unit
        }
        local result = ns.Quote.dpCover(listings, 20)
        -- 10+10 at 2000 < big stack at 3000
        assert.are.equal(2000, result.cost)
        assert.are.equal(0, result.surplus)
        assert.are.equal(2, #result.basket)
    end)
end)

describe("Quote.greedy vs DP", function()
    it("DP beats greedy: small stacks cheaper than one big stack", function()
        local listings = {
            { count = 100, buyout = 1000 },  -- 10/unit — cheapest per unit
            { count = 3, buyout = 200 },      -- 66.7/unit
            { count = 3, buyout = 200 },      -- 66.7/unit
        }

        local greedyResult = ns.Quote.greedy(listings, 6)
        local dpResult = ns.Quote.dpCover(listings, 6)

        -- Greedy picks the 100-stack (cheapest per unit): 1000, surplus 94
        assert.are.equal(1000, greedyResult.cost)
        assert.are.equal(94, greedyResult.surplus)

        -- DP picks two 3-stacks: 400, surplus 0
        assert.are.equal(400, dpResult.cost)
        assert.are.equal(0, dpResult.surplus)

        assert.is_true(dpResult.cost < greedyResult.cost)
    end)

    it("DP beats greedy: multiple small stacks beat big stack despite higher unit price", function()
        -- Need: 6
        -- Stack A: 8 at 120    (15/unit) — cheapest per unit
        -- Stack B: 3 at 50     (16.7/unit)
        -- Stack C: 3 at 50     (16.7/unit)
        -- Greedy: takes A at 120 → cost 120, surplus 2
        -- DP: takes B+C at 100 → cost 100, surplus 0
        local listings = {
            { count = 8, buyout = 120 },     -- 15/unit
            { count = 3, buyout = 50 },      -- 16.7/unit
            { count = 3, buyout = 50 },      -- 16.7/unit
        }

        local greedyResult = ns.Quote.greedy(listings, 6)
        local dpResult = ns.Quote.dpCover(listings, 6)

        assert.are.equal(120, greedyResult.cost)
        assert.are.equal(2, greedyResult.surplus)

        assert.are.equal(100, dpResult.cost)
        assert.are.equal(0, dpResult.surplus)

        assert.is_true(dpResult.cost < greedyResult.cost)
    end)

    it("DP matches greedy when greedy is optimal", function()
        local listings = {
            { count = 5, buyout = 500 },   -- 100/unit
            { count = 3, buyout = 600 },    -- 200/unit
        }

        local greedyResult = ns.Quote.greedy(listings, 5)
        local dpResult = ns.Quote.dpCover(listings, 5)

        assert.are.equal(dpResult.cost, greedyResult.cost)
    end)

    it("DP matches greedy when only one way to fulfill", function()
        local listings = {
            { count = 3, buyout = 300 },
            { count = 4, buyout = 400 },
        }

        local greedyResult = ns.Quote.greedy(listings, 7)
        local dpResult = ns.Quote.dpCover(listings, 7)

        -- Must take both stacks
        assert.are.equal(700, dpResult.cost)
        assert.are.equal(700, greedyResult.cost)
    end)
end)

describe("Quote.quote (public API)", function()
    it("returns nil for item with no listings", function()
        assert.is_nil(ns.Quote.quote(99999, 5))
    end)

    it("returns zero for quantity <= 0", function()
        local result = ns.Quote.quote(2840, 0)
        assert.are.equal(0, result.cost)
    end)

    it("uses Listings from namespace", function()
        ns.Listings.add(2840, 20, 10000)
        ns.Listings.add(2840, 5, 2500)

        local result = ns.Quote.quote(2840, 5)
        assert.are.equal(2500, result.cost)
        assert.are.equal(0, result.surplus)
    end)

    it("finds optimal combination across multiple listings", function()
        ns.Listings.add(2840, 20, 10000)   -- 500/unit
        ns.Listings.add(2840, 5, 2500)     -- 500/unit
        ns.Listings.add(2840, 3, 1200)     -- 400/unit

        local result = ns.Quote.quote(2840, 8)
        -- Best: 5+3 at 3700 (exact)
        assert.are.equal(3700, result.cost)
        assert.are.equal(0, result.surplus)
        assert.are.equal(2, #result.basket)
    end)

    it("returns nil when item exists but quantity cannot be fulfilled", function()
        ns.Listings.add(2840, 2, 100)

        assert.is_nil(ns.Quote.quote(2840, 10))
    end)
end)
