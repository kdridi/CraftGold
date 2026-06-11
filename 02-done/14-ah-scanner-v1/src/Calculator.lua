-- src/Calculator.lua
-- Recursive cost calculator: min(buyCost, craftCost) for any item × quantity.
-- Pure Lua logic — testable with busted.
--
-- CAPSULE 13 REFACTOR (Buy vs Craft v2):
--   - Uses Quote.quote(itemID, qty) for exact DP-based purchase cost
--   - Falls back to Prices.get(itemID) * qty when no listings exist
--   - No cache (cost depends on quantity, per-itemID cache would be incorrect)
--   - Cycle detection via "visiting" set (same mechanism as before)
--   - Result includes surplus info when buy is chosen via DP quote
--
-- Algorithm:
--   1. Buy option: Quote.quote(itemID, qty) → exact cost from AH listings
--      If no listings: Prices.get(itemID) * qty as fallback estimate
--   2. Craft option: sum of reagent costs (recursive, qty propagated)
--   3. Result = min(buy, craft) when both exist, otherwise whichever is available
--   4. Cycle detection via "visiting" set (items currently on the call stack)

local _, ns = ...

local Calculator = {}
ns.Calculator = Calculator

-------------------------------------------------
-- Internal recursive calculation
-------------------------------------------------
-- state = { visiting = {} }
-- visiting[itemID] = true when currently recursing into it (cycle detection)
--
-- NOTE: No cache. Previous capsule used cache[itemID] because cost was
-- unit-price-based (same for any qty). Now cost depends on quantity,
-- so a per-itemID cache would give wrong results for different quantities.
-- Profiling showed Calculator takes ~15 µs/call — acceptable without cache.

function Calculator._calculate(itemID, qty, state)
    qty = qty or 1

    -- Cycle detection
    if state.visiting[itemID] then return nil end

    state.visiting[itemID] = true

    -- === BUY OPTION ===
    -- Try Quote.quote first (DP knapsack on real listings)
    -- If no listings, fall back to manual price * quantity
    local buyCost, buySurplus, buyResult = nil, 0, nil

    local quoteResult = ns.Quote.quote(itemID, qty)
    if quoteResult then
        buyCost = quoteResult.cost
        buySurplus = quoteResult.surplus
        buyResult = quoteResult
    else
        local unitPrice = ns.Prices.get(itemID)
        if unitPrice then
            buyCost = unitPrice * qty
            buySurplus = 0
        end
    end

    -- === CRAFT OPTION ===
    local craftCost, craftBreakdown = nil, nil
    local recipe = ns.Core.getByOutput(itemID)

    if recipe then
        craftBreakdown = {}
        local total = 0
        local allPriced = true

        for _, reagent in ipairs(recipe.reagents) do
            local reagentID    = reagent[1]
            local reagentCount = reagent[2]
            local needed       = reagentCount * qty

            local reagentResult = Calculator._calculate(reagentID, needed, state)

            if reagentResult == nil then
                allPriced = false
            else
                local lineCost = reagentResult.cost
                total = total + lineCost
                craftBreakdown[#craftBreakdown + 1] = {
                    itemID    = reagentID,
                    count     = needed,
                    unitCost  = lineCost / needed,  -- average unit cost
                    totalCost = lineCost,
                    method    = reagentResult.method,
                    surplus   = reagentResult.surplus or 0,
                }
            end
        end

        if allPriced then
            craftCost = total
        end
    end

    state.visiting[itemID] = nil  -- done processing this item

    -- === DECISION: min(buy, craft) ===
    local result
    if buyCost and craftCost then
        if buyCost <= craftCost then
            result = {
                cost = buyCost, method = "buy",
                breakdown = craftBreakdown, craftCost = craftCost,
                surplus = buySurplus, quoteResult = buyResult,
            }
        else
            result = {
                cost = craftCost, method = "craft",
                breakdown = craftBreakdown, buyPrice = buyCost,
                surplus = 0,
            }
        end
    elseif buyCost then
        result = {
            cost = buyCost, method = "buy",
            breakdown = nil,
            surplus = buySurplus, quoteResult = buyResult,
        }
    elseif craftCost then
        result = {
            cost = craftCost, method = "craft",
            breakdown = craftBreakdown,
            surplus = 0,
        }
    else
        result = nil  -- unpriceable
    end

    return result
end

-------------------------------------------------
-- Public API: calculate cost for qty of an item
-------------------------------------------------
-- Returns a result table or nil
function Calculator.calculate(itemID, qty)
    local state = { visiting = {} }
    return Calculator._calculate(itemID, qty or 1, state)
end

-------------------------------------------------
-- Public API: analyze all craftable items for profit
-------------------------------------------------
-- For each craftable item that has a sell price (manual price set):
--   cost = recursive craft cost (min(buy, craft) for each reagent × qty)
--   profit = sellPrice - cost
--   margin = profit / cost * 100
--
-- Returns list sorted by profit descending
function Calculator.analyze()
    local state = { visiting = {} }
    local results = {}

    for _, recipe in pairs(ns.DB.recipes) do
        local outputID  = recipe.output
        local sellPrice = ns.Prices.get(outputID)

        if sellPrice then
            local costResult = Calculator._calculate(outputID, 1, state)
            if costResult and costResult.cost > 0 then
                local profit = sellPrice - costResult.cost
                local margin = profit / costResult.cost * 100

                results[#results + 1] = {
                    itemID     = outputID,
                    spellID    = recipe.spellID,
                    sellPrice  = sellPrice,
                    craftCost  = costResult.cost,
                    method     = costResult.method,
                    profit     = profit,
                    margin     = margin,
                    breakdown  = costResult.breakdown,
                    surplus    = costResult.surplus or 0,
                }
            end
        end
    end

    table.sort(results, function(a, b) return a.profit > b.profit end)
    return results
end
