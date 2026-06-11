-- src/Report.lua
-- Display module: formats and prints analysis results to the chat.
-- All visual output lives here — the shell only parses commands.
--
-- REFACTOR (Capsule 09): All GetItemInfo() calls replaced by ns.ItemInfo.
-- ItemInfo is the single source of truth for item name resolution.
-- This means:
--   - No more "item:" .. id fallback scattered everywhere
--   - Consistent quality-colored names via ItemInfo.formatColoredName
--   - Async handled by ItemInfo.onLoad (not used in Report since it's fire-and-forget chat output)

local _, ns = ...

local Report = {}
ns.Report = Report

-------------------------------------------------
-- Private helpers for chat output
-------------------------------------------------

local PREFIX = "|cFF00FF00[CraftGold]|r "

local function log(msg)
    ns.WoW.print(PREFIX .. msg)
end

local function logIndent(indent, msg)
    local prefix = string.rep("  ", indent)
    ns.WoW.print(prefix .. msg)
end

-------------------------------------------------
-- Report: Top N profitable crafts
-------------------------------------------------

function Report.topCrafts(n)
    local results = ns.Calculator.analyze()

    if #results == 0 then
        log("No profitable crafts found.")
        log("  Set prices with |cFFFFFF00/cg price <itemID> <price>|r first.")
        return
    end

    local show = (n and n > 0) and math.min(n, #results) or #results

    log(string.format("Top %d profitable craft(s):", show))

    for i = 1, show do
        local entry = results[i]
        local name = ns.ItemInfo.formatName(entry.itemID)
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

function Report.detail(itemID)
    local result = ns.Calculator.calculate(itemID)
    if not result then
        local name = ns.ItemInfo.formatName(itemID)
        log(string.format("%s — cannot calculate cost (missing prices)", name))
        return
    end

    local name = ns.ItemInfo.formatName(itemID)
    local methodColor = result.method == "craft" and "|cFF00FF00" or "|cFF4FC3F7"

    log(string.format("%s (%d)", name, itemID))
    log(string.format("  Cost: %s (%s%s|r)",
        ns.Money.formatColored(result.cost),
        methodColor, result.method))

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

    if result.breakdown then
        log("  |cFFFFFF00Reagent tree:|r")
        Report._printTree(result, 2)
    end
end

-------------------------------------------------
-- Private: print a recursive buy/craft tree node
-------------------------------------------------

function Report._printTree(result, indent)
    if not result.breakdown then return end

    for _, line in ipairs(result.breakdown) do
        local rName = ns.ItemInfo.formatName(line.itemID)
        local methodTag = line.method == "craft" and "|cFF00FF00craft|r" or "|cFF4FC3F7buy|r"

        logIndent(indent, string.format("|cFFFFFFFF%s|r x%d — %s each = %s (%s)",
            rName, line.count,
            ns.Money.formatColored(line.unitCost),
            ns.Money.formatColored(line.totalCost),
            methodTag))

        if line.method == "craft" then
            local subResult = ns.Calculator.calculate(line.itemID)
            if subResult and subResult.breakdown then
                Report._printTree(subResult, indent + 1)
            end
        end
    end
end
