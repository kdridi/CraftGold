-- src/Quote.lua
-- Optimal cost calculator for buying items from AH listings.
-- Uses DP covering knapsack 0/1 to find the cheapest combination
-- of indivisible stacks that covers a required quantity.
--
-- CAPSULE 11 FOCUS:
--   - quote(itemID, quantity) → {cost, basket, surplus}
--   - DP algorithm: exact optimal, not greedy
--   - Greedy implementation for comparison/testing

local _, ns = ...

local Quote = {}
ns.Quote = Quote

-------------------------------------------------
-- Greedy algorithm (for comparison/testing only)
-------------------------------------------------
-- Sorts listings by unit price (cheapest first),
-- then takes stacks until quantity is met.
-- This is WRONG in general — DP is needed.

function Quote.greedy(listings, need)
    if need <= 0 then
        return { cost = 0, basket = {}, surplus = 0 }
    end
    if not listings or #listings == 0 then
        return nil  -- impossible to fulfill
    end

    -- Sort by unit price ascending (cheapest per unit first)
    local sorted = {}
    for i, l in ipairs(listings) do
        sorted[i] = { count = l.count, buyout = l.buyout, origIndex = i }
    end
    table.sort(sorted, function(a, b)
        return (a.buyout / a.count) < (b.buyout / b.count)
    end)

    local totalCost = 0
    local totalQty = 0
    local basket = {}  -- list of { index, count, buyout }

    for _, l in ipairs(sorted) do
        if totalQty >= need then break end
        totalCost = totalCost + l.buyout
        totalQty = totalQty + l.count
        basket[#basket + 1] = { index = l.origIndex, count = l.count, buyout = l.buyout }
    end

    if totalQty < need then
        return nil  -- not enough total items in all listings
    end

    return {
        cost = totalCost,
        basket = basket,
        surplus = totalQty - need,
    }
end

-------------------------------------------------
-- DP covering knapsack 0/1
-------------------------------------------------
-- listings: array of {count=N, buyout=C}
-- need:     how many units we need
-- Returns:  { cost, basket, surplus } or nil (impossible)
--
-- dp[q] = minimum cost to obtain AT LEAST q units
-- We use "at least" semantics: when a stack of count S is added,
-- the effective coverage jumps from q to min(need, q+S).
-- This caps the DP table size at `need` entries.

function Quote.dpCover(listings, need)
    if need <= 0 then
        return { cost = 0, basket = {}, surplus = 0 }
    end
    if not listings or #listings == 0 then
        return nil  -- impossible to fulfill
    end

    local INF = math.huge

    -- dp[q] = minimum cost to cover at least q units
    local dp = {}
    -- choice[q] = { listingIndex, prevQ } for reconstruction
    local choice = {}

    for q = 0, need do
        dp[q] = INF
        choice[q] = nil
    end
    dp[0] = 0

    -- For each listing (0/1: take it or not)
    for i, listing in ipairs(listings) do
        local S = listing.count    -- stack size
        local C = listing.buyout   -- stack cost

        -- Iterate backwards to avoid using the same listing twice
        for q = need, 0, -1 do
            if dp[q] ~= INF then
                -- If we take this listing, we cover min(need, q + S) units
                local newQ = math.min(need, q + S)
                local newCost = dp[q] + C

                if newCost < dp[newQ] then
                    dp[newQ] = newCost
                    choice[newQ] = { listingIndex = i, prevQ = q }
                end
            end
        end
    end

    -- Find the minimum cost among all states that cover at least `need`
    if dp[need] == INF then
        return nil  -- impossible to cover `need` with available listings
    end

    -- Reconstruct basket
    local basket = {}
    local q = need
    while choice[q] do
        local c = choice[q]
        local l = listings[c.listingIndex]
        basket[#basket + 1] = {
            index = c.listingIndex,
            count = l.count,
            buyout = l.buyout,
        }
        q = c.prevQ
    end

    -- Calculate surplus: total items bought - need
    local totalQty = 0
    for _, b in ipairs(basket) do
        totalQty = totalQty + b.count
    end

    return {
        cost = dp[need],
        basket = basket,
        surplus = totalQty - need,
    }
end

-------------------------------------------------
-- Public API: quote(itemID, quantity)
-------------------------------------------------
-- Combines getListings + DP to find optimal purchase plan.
-- Returns: { cost, basket, surplus } or nil

function Quote.quote(itemID, quantity)
    if not itemID or not quantity or quantity <= 0 then
        return { cost = 0, basket = {}, surplus = 0 }
    end

    local listings = ns.Listings.getListings(itemID)
    if not listings or #listings == 0 then
        return nil  -- no listings available
    end

    return Quote.dpCover(listings, quantity)
end
