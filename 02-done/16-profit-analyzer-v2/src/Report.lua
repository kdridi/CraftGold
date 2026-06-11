-- src/Report.lua
-- Display module: formats and prints analysis results to the chat.
-- All visual output lives here — the shell only parses commands.
--
-- CAPSULE 13 UPDATE:
--   - Calculator now returns surplus info (from DP quote)
--   - Report shows surplus when buy is chosen via DP
--   - _printTree shows surplus per reagent when applicable
--
-- CAPSULE 16 UPDATE:
--   - topCrafts() shows net profit (after AH commission)
--   - Displays price source: [AH] or [Manual]
--   - Shows AH cut amount
--   - detail() uses Quote.marketPrice() for sell price estimation

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
-- CAPSULE 16 UPDATE:
--   - Shows net profit (after AH commission)
--   - Displays price source: [AH] or [Manual]
--   - Shows AH cut amount

function Report.topCrafts(n)
    local results = ns.Calculator.analyze()

    if #results == 0 then
        log("No craftable items found with sell price data.")
        log("  Use |cFFFFFF00/cg analyze scan|r at the AH to scan everything automatically.")
        return
    end

    -- Check if any are profitable
    local profitable = {}
    for _, r in ipairs(results) do
        if r.profit > 0 then
            profitable[#profitable + 1] = r
        end
    end

    if #profitable == 0 then
        log(string.format("%d craft(s) analyzed — |cFFFF0000none profitable|r after %.0f%% AH commission.",
            #results, ns.Calculator._getAhCutPercent()))
        log("  Closest to profit:")
        local show = math.min(5, #results)
        for i = 1, show do
            local entry = results[i]
            local name = ns.ItemInfo.formatName(entry.itemID)
            local srcTag = entry.priceSource == "ah" and "|cFF4FC3F7[AH]|r" or "|cFF808080[Manual]|r"
            ns.WoW.print(string.format(
                "  |cFFFFFF00%d.|r %s %s — Cost: %s — Sell: %s — Cut: %s — Profit: |cFFFF0000%s|r — Margin: %.0f%%",
                i, name, srcTag,
                ns.Money.formatColored(entry.craftCost),
                ns.Money.formatColored(entry.sellPrice),
                ns.Money.formatColored(entry.ahCut),
                ns.Money.format(entry.profit),
                entry.margin))
        end
        return
    end

    local showList = n and n > 0 and math.min(n, #profitable) or #profitable

    log(string.format("Top %d craft(s) — profit after %.0f%% AH commission:",
        showList, ns.Calculator._getAhCutPercent()))

    for i = 1, showList do
        local entry = profitable[i]
        local name = ns.ItemInfo.formatName(entry.itemID)
        local profitColor = entry.profit > 0 and "|cFF00FF00" or "|cFFFF0000"
        local surplusTag = ""
        if entry.surplus and entry.surplus > 0 then
            surplusTag = string.format(" |cFF808080(+%d surplus)|r", entry.surplus)
        end

        -- Price source tag
        local srcTag = entry.priceSource == "ah" and "|cFF4FC3F7[AH]|r" or "|cFF808080[Manual]|r"

        ns.WoW.print(string.format(
            "  |cFFFFFF00%d.|r %s %s — Cost: %s — Sell: %s — Cut: %s — |cFFFFFF00Profit: %s%s|r — Margin: %.0f%%%s",
            i, name, srcTag,
            ns.Money.formatColored(entry.craftCost),
            ns.Money.formatColored(entry.sellPrice),
            ns.Money.formatColored(entry.ahCut),
            profitColor, ns.Money.format(entry.profit),
            entry.margin, surplusTag))
    end

    if showList < #profitable then
        log(string.format("  |cFF808080... and %d more (use /cg analyze %d to see all)|r",
            #profitable - showList, #profitable))
    end
end

-------------------------------------------------
-- Report: Detailed breakdown for one item
-------------------------------------------------

function Report.detail(itemID)
    local result = ns.Calculator.calculate(itemID)
    if not result then
        local name = ns.ItemInfo.formatName(itemID)
        log(string.format("%s — cannot calculate cost (missing prices/listings)", name))
        return
    end

    local name = ns.ItemInfo.formatName(itemID)
    local methodColor = result.method == "craft" and "|cFF00FF00" or "|cFF4FC3F7"

    log(string.format("%s (%d)", name, itemID))
    log(string.format("  Cost: %s (%s%s|r)",
        ns.Money.formatColored(result.cost),
        methodColor, result.method))

    -- Show surplus when buy was chosen via DP quote
    if result.surplus and result.surplus > 0 then
        log(string.format("  |cFF808080Surplus: +%d extra item(s) from AH stack(s)|r", result.surplus))
    end

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

    -- Estimate sell price via marketPrice (listings or manual)
    local sellPrice, priceSource = ns.Quote.marketPrice(itemID)
    if sellPrice then
        local AH_CUT_PCT = ns.Calculator._getAhCutPercent()
        local netSell = math.floor(sellPrice * (1 - AH_CUT_PCT / 100))
        local ahCut = sellPrice - netSell
        local srcLabel = priceSource == "ah" and "|cFF4FC3F7AH listing|r" or "|cFF808080Manual price|r"
        log(string.format("  Sell: %s (after %.0f%% cut: %s) — Source: %s",
            ns.Money.formatColored(sellPrice),
            AH_CUT_PCT,
            ns.Money.formatColored(netSell),
            srcLabel))
        local profit = netSell - result.cost
        local margin = profit / result.cost * 100
        local profitColor = profit > 0 and "|cFF00FF00" or "|cFFFF0000"
        log(string.format("  Profit: %s%s|r — Margin: %.0f%%",
            profitColor, ns.Money.format(profit), margin))
    end

    if result.breakdown then
        log("  |cFFFFFF00Reagent tree:|r")
        Report._printTree(result, 2)
    end
end

-------------------------------------------------
-- Private: print a recursive buy/craft tree node
-------------------------------------------------
-- CAPSULE 13: line.count is now the total qty needed (not per-craft qty)
-- line.unitCost is average unit cost (totalCost / count)
-- line.surplus shows AH overbuy when buy was chosen

function Report._printTree(result, indent)
    if not result.breakdown then return end

    for _, line in ipairs(result.breakdown) do
        local rName = ns.ItemInfo.formatName(line.itemID)
        local methodTag = line.method == "craft" and "|cFF00FF00craft|r" or "|cFF4FC3F7buy|r"
        local surplusTag = ""
        if line.surplus and line.surplus > 0 then
            surplusTag = string.format(" |cFF808080(+%d surplus)|r", line.surplus)
        end

        logIndent(indent, string.format("|cFFFFFFFF%s|r x%d — %s each = %s (%s)%s",
            rName, line.count,
            ns.Money.formatColored(line.unitCost),
            ns.Money.formatColored(line.totalCost),
            methodTag, surplusTag))

        if line.method == "craft" then
            local subResult = ns.Calculator.calculate(line.itemID, line.count)
            if subResult and subResult.breakdown then
                Report._printTree(subResult, indent + 1)
            end
        end
    end
end
