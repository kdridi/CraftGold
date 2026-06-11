-- src/Calculator.lua
-- Recursive cost calculator: min(buyPrice, craftCost) for any item.
-- Pure Lua logic — testable with busted.
--
-- Algorithm:
--   1. If item has a buy price (Prices.get) → that's the buy option
--   2. If item is craftable (Core.getByOutput) → sum of reagent costs (recursive)
--   3. Result = min(buy, craft) when both exist, otherwise whichever is available
--   4. Cycle detection via "visiting" set (items currently on the call stack)
--   5. Memoization via "cache" (shared across a single analyze run)

local _, ns = ...

local Calculator = {}
ns.Calculator = Calculator

-------------------------------------------------
-- Internal recursive calculation
-------------------------------------------------
-- state = { cache = {}, visiting = {} }
-- cache[itemID] = result table | false (computed, unpriceable) | nil (not computed)
-- visiting[itemID] = true when currently recursing into it (cycle detection)

function Calculator._calculate(itemID, state)
    -- Memoization: return cached result
    if state.cache[itemID] ~= nil then
        if state.cache[itemID] == false then return nil end
        return state.cache[itemID]
    end

    -- Cycle detection
    if state.visiting[itemID] then return nil end

    state.visiting[itemID] = true

    local buyPrice = ns.Prices.get(itemID)
    local craftCost, craftBreakdown = nil, nil
    local recipe = ns.Core.getByOutput(itemID)

    if recipe then
        craftBreakdown = {}
        local total = 0
        local allPriced = true

        for _, reagent in ipairs(recipe.reagents) do
            local reagentID    = reagent[1]
            local reagentCount = reagent[2]

            local reagentResult = Calculator._calculate(reagentID, state)

            if reagentResult == nil then
                allPriced = false
            else
                local lineCost = reagentResult.cost * reagentCount
                total = total + lineCost
                craftBreakdown[#craftBreakdown + 1] = {
                    itemID    = reagentID,
                    count     = reagentCount,
                    unitCost  = reagentResult.cost,
                    totalCost = lineCost,
                    method    = reagentResult.method,
                }
            end
        end

        if allPriced then
            craftCost = total
        end
    end

    state.visiting[itemID] = nil  -- done processing this item

    -- Decision: min(buy, craft)
    local result
    if buyPrice and craftCost then
        if buyPrice <= craftCost then
            result = { cost = buyPrice, method = "buy", breakdown = craftBreakdown, craftCost = craftCost }
        else
            result = { cost = craftCost, method = "craft", breakdown = craftBreakdown, buyPrice = buyPrice }
        end
    elseif buyPrice then
        result = { cost = buyPrice, method = "buy", breakdown = nil }
    elseif craftCost then
        result = { cost = craftCost, method = "craft", breakdown = craftBreakdown }
    else
        result = nil  -- unpriceable
    end

    state.cache[itemID] = result or false
    return result
end

-------------------------------------------------
-- Public API: calculate cost for a single item
-------------------------------------------------
-- Returns a result table or nil
function Calculator.calculate(itemID)
    local state = { cache = {}, visiting = {} }
    return Calculator._calculate(itemID, state)
end

-------------------------------------------------
-- Public API: analyze all craftable items for profit
-------------------------------------------------
-- For each craftable item that has a sell price (AH price set):
--   cost = recursive craft cost (min(buy, craft) for each reagent)
--   profit = sellPrice - cost
--   margin = profit / cost * 100
--
-- Returns list sorted by profit descending
function Calculator.analyze()
    local state = { cache = {}, visiting = {} }
    local results = {}

    for _, recipe in pairs(ns.DB.recipes) do
        local outputID  = recipe.output
        local sellPrice = ns.Prices.get(outputID)

        if sellPrice then
            local costResult = Calculator._calculate(outputID, state)
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
                }
            end
        end
    end

    table.sort(results, function(a, b) return a.profit > b.profit end)
    return results
end

-------------------------------------------------
-- Public API: list items where crafting is cheaper than buying
-------------------------------------------------
-- Finds intermediate items where craft < buy
function Calculator.savings()
    local state = { cache = {}, visiting = {} }
    local results = {}

    for _, recipe in pairs(ns.DB.recipes) do
        local outputID = recipe.output
        local buyPrice = ns.Prices.get(outputID)

        if buyPrice then
            local costResult = Calculator._calculate(outputID, state)
            if costResult and costResult.method == "craft" and costResult.buyPrice then
                local saving = costResult.buyPrice - costResult.cost
                results[#results + 1] = {
                    itemID    = outputID,
                    buyPrice  = costResult.buyPrice,
                    craftCost = costResult.cost,
                    saving    = saving,
                }
            end
        end
    end

    table.sort(results, function(a, b) return a.saving > b.saving end)
    return results
end
