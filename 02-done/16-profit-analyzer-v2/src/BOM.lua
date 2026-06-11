-- src/BOM.lua
-- Bill of Materials: recursive expansion of a craft into raw materials.
-- Pure Lua logic — testable with busted.
--
-- CAPSULE 12 FOCUS:
--   - expand(itemID, qty) → flat list of raw materials (non-craftable)
--   - Aggregation by itemID (e.g. 8x Copper Bar, not 2+3+3)
--   - shoplist(itemID, qty) → expanded materials + quote per item + total cost
--   - Cycle detection (same mechanism as Calculator)
--
-- KEY CONCEPTS:
--   - "Raw material" = an item that is NOT the output of any recipe in DB
--   - The BOM always expands ALL craftable components (no buy vs craft decision)
--   - The buy vs craft decision is deferred to capsule 13 (Buy vs Craft v2)
--
-- ARCHITECTURE:
--   BOM.expand  → pure data: { itemID → qty } mapping
--   BOM.shoplist → data + quoting via Quote.quote()
--   BOM.formatShoplist → WoW-specific display (ItemInfo, Money formatting)

local _, ns = ...

local BOM = {}
ns.BOM = BOM

-------------------------------------------------
-- Internal: recursive expansion
-------------------------------------------------
-- Recursively walks the recipe tree, accumulating quantities of raw materials.
--
-- state = { materials = {}, visiting = {}, errors = {} }
--   materials[itemID] = total quantity needed (aggregated across all paths)
--   visiting[itemID]  = true when currently recursing (cycle detection)
--   errors            = list of cycle warnings
--
-- The "visiting" set works like a call stack marker:
--   - Set to true before descending into an item
--   - Cleared after all its children are processed
--   - If we see an item already in "visiting", we have a cycle

function BOM._expand(itemID, qty, state)
    if not qty or qty <= 0 then return end

    -- Cycle detection: if this item is already on the call stack,
    -- we have a circular dependency. Treat it as a raw material
    -- to break the recursion, and log a warning.
    if state.visiting[itemID] then
        state.errors[#state.errors + 1] = {
            itemID = itemID,
            msg = string.format("Cycle detected for item %d — treating as raw material", itemID),
        }
        state.materials[itemID] = (state.materials[itemID] or 0) + qty
        return
    end

    -- Check if this item is craftable (is it the output of a recipe?)
    local recipe = ns.Core.getByOutput(itemID)

    if not recipe then
        -- Not craftable → this is a raw material (leaf in the recipe tree).
        -- Aggregate: if Copper Bar appears in 3 different sub-crafts,
        -- we sum all quantities into one entry.
        state.materials[itemID] = (state.materials[itemID] or 0) + qty
        return
    end

    -- Craftable → descend into each reagent.
    -- The key insight: multiply reagent count by the parent quantity.
    -- If a recipe needs 2 Copper Bar per craft, and we're crafting 3,
    -- we need 2 × 3 = 6 Copper Bar total.
    state.visiting[itemID] = true

    for _, reagent in ipairs(recipe.reagents) do
        local reagentID    = reagent[1]
        local reagentCount = reagent[2]
        BOM._expand(reagentID, reagentCount * qty, state)
    end

    state.visiting[itemID] = nil
end

-------------------------------------------------
-- Public API: expand a craft into raw materials
-------------------------------------------------
-- Returns: { materials = { [itemID] = qty, ... }, errors = {} }
function BOM.expand(itemID, qty)
    local state = {
        materials = {},
        visiting  = {},
        errors    = {},
    }
    BOM._expand(itemID, qty or 1, state)
    return state
end

-------------------------------------------------
-- Public API: full shoplist with quote per material
-------------------------------------------------
-- Expands the craft, then quotes each raw material via Quote.quote().
-- Quote.quote() uses DP knapsack to find the cheapest way to buy
-- the exact quantity needed from available AH listings.
--
-- Returns: {
--   itemID    = number,          -- the crafted item
--   qty       = number,          -- how many to craft
--   materials = { [itemID] = qty },  -- expanded raw materials
--   quotes    = { { itemID, qty, result }, ... },  -- sorted by itemID
--   totalCost = number,          -- sum of all quote costs (copper)
--   errors    = {},              -- cycle warnings
-- }
function BOM.shoplist(itemID, qty)
    qty = qty or 1

    local expanded = BOM.expand(itemID, qty)

    -- Quote each raw material using DP knapsack
    local quotes = {}
    local totalCost = 0

    for matID, matQty in pairs(expanded.materials) do
        local q = ns.Quote.quote(matID, matQty)
        quotes[#quotes + 1] = {
            itemID = matID,
            qty    = matQty,
            result = q,  -- nil if no listings available
        }

        if q then
            totalCost = totalCost + q.cost
        end
    end

    -- Sort by itemID for deterministic output order
    table.sort(quotes, function(a, b) return a.itemID < b.itemID end)

    return {
        itemID    = itemID,
        qty       = qty,
        materials = expanded.materials,
        quotes    = quotes,
        totalCost = totalCost,
        errors    = expanded.errors,
    }
end

-------------------------------------------------
-- Format shoplist result for chat display
-------------------------------------------------
-- Returns a multi-line string with color codes, ready for line-by-line printing.
function BOM.formatShoplist(result)
    local lines = {}

    local name = ns.ItemInfo.formatName(result.itemID)
    lines[#lines + 1] = string.format(
        "|cFF4FC3F7[Shoplist]|r %s (%d) × %d",
        name, result.itemID, result.qty)

    -- Materials breakdown with costs
    lines[#lines + 1] = "  |cFFFFFFFFRaw materials:|r"
    for _, q in ipairs(result.quotes) do
        local matName = ns.ItemInfo.formatName(q.itemID)
        if q.result then
            lines[#lines + 1] = string.format(
                "    %s (%d) × %d — %s",
                matName, q.itemID, q.qty,
                ns.Money.formatColored(q.result.cost))
            if q.result.surplus > 0 then
                lines[#lines + 1] = string.format(
                    "      |cFF808080(surplus: %d extra)|r",
                    q.result.surplus)
            end
        else
            lines[#lines + 1] = string.format(
                "    |cFFFF8800%s (%d) × %d — no listings|r",
                matName, q.itemID, q.qty)
        end
    end

    -- Total cost with warning for unquoted items
    local unquoted = 0
    for _, q in ipairs(result.quotes) do
        if not q.result then unquoted = unquoted + 1 end
    end

    if unquoted > 0 then
        lines[#lines + 1] = string.format(
            "  |cFFFFFFFFTotal: %s (|cFFFF8800%d item(s) not quoted|r)",
            ns.Money.formatColored(result.totalCost), unquoted)
    else
        lines[#lines + 1] = string.format(
            "  |cFFFFFFFFTotal: %s|r",
            ns.Money.formatColored(result.totalCost))
    end

    -- Cycle warnings (should not happen with valid recipe data)
    for _, err in ipairs(result.errors) do
        lines[#lines + 1] = string.format(
            "  |cFFFF0000⚠ %s|r", err.msg)
    end

    return table.concat(lines, "\n")
end
