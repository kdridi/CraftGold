-- src/Report.lua
-- Display module: formats and prints analysis results to the chat.
-- All visual output lives here — the shell only parses commands.
--
-- DESIGN LESSON: Separating display from command parsing keeps the shell thin.
-- As we add more features (listings, AH scanner), the shell stays manageable.
-- This is the "Imperative Shell / Functional Core" pattern from capsule 03.
--
-- Key concepts in this file:
--   - Module pattern: local Report = {} assigned to ns.Report
--   - Delegation: shell calls Report.topCrafts(n), Report.detail(itemID)
--   - Recursive tree display: _printTree walks the Calculator result recursively
--   - WoW color codes: |cAARRGGBBtext|r for colored chat output

local _, ns = ...

local Report = {}
ns.Report = Report

-------------------------------------------------
-- Private helpers for chat output
-------------------------------------------------
-- WoW chat supports inline color codes: |cAARRGGBB...|r
-- We use a consistent [CraftGold] prefix in green for all output.

local PREFIX = "|cFF00FF00[CraftGold]|r "

local function log(msg)
    ns.WoW.print(PREFIX .. msg)
end

-- logIndent: used by _printTree to show hierarchical structure.
-- string.rep("  ", indent) creates the visual indentation.
local function logIndent(indent, msg)
    local prefix = string.rep("  ", indent)
    ns.WoW.print(prefix .. msg)
end

-------------------------------------------------
-- Report: Top N profitable crafts
-------------------------------------------------
-- Calls Calculator.analyze() and displays the top N results.
-- If n is nil or 0, shows all results.
function Report.topCrafts(n)
    -- Calculator.analyze() returns ALL crafts sorted by profit (descending).
    -- We just slice the list to show top N.
    local results = ns.Calculator.analyze()

    if #results == 0 then
        log("No profitable crafts found.")
        log("  Set prices with |cFFFFFF00/cg price <itemID> <price>|r first.")
        return
    end

    -- n can be nil (no argument) or a number.
    -- math.min clamps to the actual result count.
    local show = (n and n > 0) and math.min(n, #results) or #results

    log(string.format("Top %d profitable craft(s):", show))

    for i = 1, show do
        local entry = results[i]
        local name = ns.WoW.GetItemInfo(entry.itemID) or ("item:" .. entry.itemID)
        local profitColor = entry.profit > 0 and "|cFF00FF00" or "|cFFFF0000"

        ns.WoW.print(string.format(
            "  |cFFFFFF00%d.|r %s — Cost: %s — Sell: %s — Profit: %s%s|r — Margin: %.0f%%",
            i, name,
            ns.Money.formatColored(entry.craftCost),
            ns.Money.formatColored(entry.sellPrice),
            profitColor, ns.Money.format(entry.profit),
            entry.margin))
    end

    if show < #results then
        log(string.format("  |cFF808080... and %d more (use /cg analyze %d to see all)|r",
            #results - show, #results))
    end
end

-------------------------------------------------
-- Report: Detailed breakdown for one item
-------------------------------------------------
-- Shows cost, sell price, profit, margin, and the full recursive buy/craft tree.
function Report.detail(itemID)
    local result = ns.Calculator.calculate(itemID)
    if not result then
        local name = ns.WoW.GetItemInfo(itemID) or ("item:" .. itemID)
        log(string.format("%s (%d) — cannot calculate cost (missing prices)", name, itemID))
        return
    end

    local name = ns.WoW.GetItemInfo(itemID) or ("item:" .. itemID)
    local methodColor = result.method == "craft" and "|cFF00FF00" or "|cFF4FC3F7"

    log(string.format("%s (%d)", name, itemID))
    log(string.format("  Cost: %s (%s%s|r)",
        ns.Money.formatColored(result.cost),
        methodColor, result.method))

    -- Buy vs craft comparison: only shown when both options are available.
    -- result.buyPrice = cost if buying from AH (stored alongside craft data)
    -- result.craftCost = total cost if crafting from reagents
    -- These fields only exist when Calculator found BOTH options.
    if result.buyPrice and result.craftCost then
        if result.method == "craft" then
            log(string.format("  |cFF4FC3F7Buy: %s|r |cFF00FF00Craft: %s|r — craft is cheaper!",
                ns.Money.formatColored(result.buyPrice),
                ns.Money.formatColored(result.craftCost)))
        else
            log(string.format("  |cFF4FC3F7Buy: %s|r |cFF00FF00Craft: %s|r — buy is cheaper!",
                ns.Money.formatColored(result.buyPrice),
                ns.Money.formatColored(result.craftCost)))
        end
    end

    -- Profit section: only shown if the item has a sell price set.
    -- We check sellPrice ~= result.cost to avoid showing 0 profit for items
    -- that only have a buy price (no separate sell price).
    local sellPrice = ns.Prices.get(itemID)
    if sellPrice and sellPrice ~= result.cost then
        local profit = sellPrice - result.cost
        local margin = profit / result.cost * 100
        local profitColor = profit > 0 and "|cFF00FF00" or "|cFFFF0000"
        log(string.format("  Sell: %s — Profit: %s%s|r — Margin: %.0f%%",
            ns.Money.formatColored(sellPrice),
            profitColor, ns.Money.format(profit),
            margin))
    end

    -- Recursive tree
    if result.breakdown then
        log("  |cFFFFFF00Reagent tree:|r")
        Report._printTree(result, 2)
    end
end

-------------------------------------------------
-- Private: print a recursive buy/craft tree node
-------------------------------------------------
-- Each node shows: item name, method (buy/craft), cost
-- If crafted, recurse into its reagents.
function Report._printTree(result, indent)
    -- Recursively prints the buy/craft decision tree.
    --
    -- Structure: result.breakdown is a flat list of reagent lines.
    -- Each line has: itemID, count, unitCost, totalCost, method ("buy"|"craft").
    -- If method == "craft", we call Calculator.calculate() again to get
    -- that item's own breakdown, and recurse.
    --
    -- Note: this creates a NEW Calculator call per sub-component.
    -- The cache from the parent call is not reused here. This is fine
    -- for our small DB, but could be optimized later by passing the
    -- state/cache down if needed.

    if not result.breakdown then return end

    for _, line in ipairs(result.breakdown) do
        local rName = ns.WoW.GetItemInfo(line.itemID) or ("item:" .. line.itemID)
        local methodTag = line.method == "craft" and "|cFF00FF00craft|r" or "|cFF4FC3F7buy|r"

        logIndent(indent, string.format("|cFFFFFFFF%s|r x%d — %s each = %s (%s)",
            rName, line.count,
            ns.Money.formatColored(line.unitCost),
            ns.Money.formatColored(line.totalCost),
            methodTag))

        -- Only recurse into crafted items (buy items are leaf nodes)
        if line.method == "craft" then
            local subResult = ns.Calculator.calculate(line.itemID)
            if subResult and subResult.breakdown then
                Report._printTree(subResult, indent + 1)
            end
        end
    end
end
