-- PriceCalc.lua
-- Shell: WoW integration (slash commands, events, SavedVariables init).
-- This is the only file that talks to WoW directly.

local _, ns = ...

local addonName = "PriceCalc"

-------------------------------------------------
-- Slash commands
-------------------------------------------------

SLASH_PRICECALC1 = "/cg"
SLASH_PRICECALC2 = "/craftgold"

SlashCmdList["PRICECALC"] = function(input)
    local args = {}
    for word in (input or ""):gmatch("%S+") do
        args[#args + 1] = word
    end

    if #args == 0 or args[1]:lower() == "help" then
        cmdHelp()
    elseif args[1]:lower() == "price" then
        cmdPrice(args)
    elseif args[1]:lower() == "cost" then
        cmdCost(args)
    elseif args[1]:lower() == "analyze" then
        cmdAnalyze()
    elseif args[1]:lower() == "savings" then
        cmdSavings()
    elseif args[1]:lower() == "test" then
        RunInGameTests()
    else
        ns.WoW.print("|cFF00FF00[CraftGold]|r Unknown command: " .. args[1])
        cmdHelp()
    end
end

-------------------------------------------------
-- /cg help
-------------------------------------------------

function cmdHelp()
    ns.WoW.print("|cFF00FF00[CraftGold]|r Commands:")
    ns.WoW.print("  |cFFFFFF00/cg price <itemID> <price>|r — Set AH price (e.g. 12s40c, 1g50s)")
    ns.WoW.print("  |cFFFFFF00/cg price list|r — Show all prices")
    ns.WoW.print("  |cFFFFFF00/cg price remove <itemID>|r — Remove a price")
    ns.WoW.print("  |cFFFFFF00/cg cost <itemID>|r — Show recursive cost breakdown")
    ns.WoW.print("  |cFFFFFF00/cg analyze|r — Show profitable crafts")
    ns.WoW.print("  |cFFFFFF00/cg savings|r — Show items cheaper to craft than buy")
    ns.WoW.print("  |cFFFFFF00/cg test|r — Run in-game tests")
    ns.WoW.print("  |cFFFFFF00/cg help|r — Show this help")
end

-------------------------------------------------
-- /cg price [<itemID> <price> | list | remove <itemID>]
-------------------------------------------------

function cmdPrice(args)
    local sub = (args[2] or ""):lower()

    if sub == "list" then
        local prices = ns.Prices.getAll()
        local count = ns.Prices.count()
        if count == 0 then
            ns.WoW.print("|cFF00FF00[CraftGold]|r No prices set. Use /cg price <itemID> <price>")
            return
        end
        ns.WoW.print(string.format("|cFF00FF00[CraftGold]|r %d price(s) set:", count))
        for itemID, copper in pairs(prices) do
            local name = ns.WoW.GetItemInfo(itemID) or ("item:" .. itemID)
            ns.WoW.print(string.format("  %s (%d) = %s", name, itemID, ns.Money.formatColored(copper)))
        end

    elseif sub == "remove" or sub == "delete" or sub == "clear" then
        local itemID = tonumber(args[3])
        if not itemID then
            ns.WoW.print("|cFFFF0000[CraftGold]|r Usage: /cg price remove <itemID>")
            return
        end
        local old = ns.Prices.get(itemID)
        ns.Prices.remove(itemID)
        if old then
            local name = ns.WoW.GetItemInfo(itemID) or ("item:" .. itemID)
            ns.WoW.print(string.format("|cFF00FF00[CraftGold]|r Removed price for %s (%d)", name, itemID))
        else
            ns.WoW.print(string.format("|cFF00FF00[CraftGold]|r No price set for item %d", itemID))
        end

    else
        -- /cg price <itemID> <price>
        local itemID = tonumber(args[2])
        local priceStr = args[3]

        if not itemID or not priceStr then
            ns.WoW.print("|cFFFF0000[CraftGold]|r Usage: /cg price <itemID> <price>")
            ns.WoW.print("  Example: /cg price 2840 12s40c")
            return
        end

        local copper, err = ns.Money.parse(priceStr)
        if not copper then
            ns.WoW.print("|cFFFF0000[CraftGold]|r " .. err)
            return
        end

        ns.Prices.set(itemID, copper)
        local name = ns.WoW.GetItemInfo(itemID) or ("item:" .. itemID)
        ns.WoW.print(string.format("|cFF00FF00[CraftGold]|r %s (%d) = %s",
            name, itemID, ns.Money.formatColored(copper)))
    end
end

-------------------------------------------------
-- /cg cost <itemID>
-------------------------------------------------

function cmdCost(args)
    local itemID = tonumber(args[2])
    if not itemID then
        ns.WoW.print("|cFFFF0000[CraftGold]|r Usage: /cg cost <itemID>")
        return
    end

    local result = ns.Calculator.calculate(itemID)
    if not result then
        local name = ns.WoW.GetItemInfo(itemID) or ("item:" .. itemID)
        ns.WoW.print(string.format("|cFF00FF00[CraftGold]|r %s (%d) — cannot calculate cost (missing prices)",
            name, itemID))
        return
    end

    local name = ns.WoW.GetItemInfo(itemID) or ("item:" .. itemID)
    local methodColor = result.method == "craft" and "|cFF00FF00" or "|cFF4FC3F7"
    ns.WoW.print(string.format("|cFF00FF00[CraftGold]|r %s (%d) — Cost: %s (%s%s|r)",
        name, itemID,
        ns.Money.formatColored(result.cost),
        methodColor, result.method))

    -- Show buy vs craft comparison
    if result.buyPrice and result.craftCost then
        if result.method == "craft" then
            ns.WoW.print(string.format("  |cFF4FC3F7Buy: %s|r |cFF00FF00Craft: %s|r — craft is cheaper!",
                ns.Money.formatColored(result.buyPrice),
                ns.Money.formatColored(result.craftCost)))
        else
            ns.WoW.print(string.format("  |cFF4FC3F7Buy: %s|r |cFF00FF00Craft: %s|r — buy is cheaper!",
                ns.Money.formatColored(result.buyPrice),
                ns.Money.formatColored(result.craftCost)))
        end
    end

    -- Show breakdown for crafted items
    if result.breakdown then
        ns.WoW.print("  |cFFFFFF00Reagents:|r")
        for _, line in ipairs(result.breakdown) do
            local rName = ns.WoW.GetItemInfo(line.itemID) or ("item:" .. line.itemID)
            local methodTag = line.method == "craft" and "|cFF00FF00craft|r" or "|cFF4FC3F7buy|r"
            ns.WoW.print(string.format("    %s x%d — %s each = %s (%s)",
                rName, line.count,
                ns.Money.formatColored(line.unitCost),
                ns.Money.formatColored(line.totalCost),
                methodTag))
        end
    end
end

-------------------------------------------------
-- /cg analyze
-------------------------------------------------

function cmdAnalyze()
    local results = ns.Calculator.analyze()

    if #results == 0 then
        ns.WoW.print("|cFF00FF00[CraftGold]|r No profitable crafts found.")
        ns.WoW.print("  Set prices with |cFFFFFF00/cg price <itemID> <price>|r first.")
        return
    end

    ns.WoW.print(string.format("|cFF00FF00[CraftGold]|r Top %d profitable craft(s):", #results))

    for i, entry in ipairs(results) do
        local name = ns.WoW.GetItemInfo(entry.itemID) or ("item:" .. entry.itemID)
        local profitColor = entry.profit > 0 and "|cFF00FF00" or "|cFFFF0000"

        ns.WoW.print(string.format(
            "  |cFFFFFF00%d.|r %s — Cost: %s — Sell: %s — Profit: %s%s|r — Margin: %.0f%%",
            i, name,
            ns.Money.formatColored(entry.craftCost),
            ns.Money.formatColored(entry.sellPrice),
            profitColor, ns.Money.format(entry.profit),
            entry.margin))

        -- Show craft-vs-buy tips for intermediates
        if entry.breakdown then
            for _, line in ipairs(entry.breakdown) do
                if line.method == "craft" then
                    local rName = ns.WoW.GetItemInfo(line.itemID) or ("item:" .. line.itemID)
                    local buyPrice = ns.Prices.get(line.itemID)
                    if buyPrice then
                        ns.WoW.print(string.format(
                            "    |cFF808080→ Craft %s (%s) instead of buying (%s)|r",
                            rName,
                            ns.Money.format(line.unitCost),
                            ns.Money.format(buyPrice)))
                    end
                end
            end
        end
    end
end

-------------------------------------------------
-- /cg savings
-------------------------------------------------

function cmdSavings()
    local results = ns.Calculator.savings()

    if #results == 0 then
        ns.WoW.print("|cFF00FF00[CraftGold]|r No savings found.")
        ns.WoW.print("  Set buy prices for intermediate items to compare craft vs buy.")
        return
    end

    ns.WoW.print(string.format("|cFF00FF00[CraftGold]|r Craft vs Buy savings:", #results))
    for i, entry in ipairs(results) do
        local name = ns.WoW.GetItemInfo(entry.itemID) or ("item:" .. entry.itemID)
        ns.WoW.print(string.format(
            "  %s — Buy: %s — Craft: %s — Save: |cFF00FF00%s|r",
            name,
            ns.Money.formatColored(entry.buyPrice),
            ns.Money.formatColored(entry.craftCost),
            ns.Money.format(entry.saving)))
    end
end

-------------------------------------------------
-- In-game test runner
-------------------------------------------------

function RunInGameTests()
    local Money     = ns.Money
    local Prices    = ns.Prices
    local Calculator = ns.Calculator
    local Core      = ns.Core

    local passed = 0
    local failed = 0

    local function assert2(condition, msg)
        if condition then
            passed = passed + 1
        else
            failed = failed + 1
            ns.WoW.print("|cFFFF0000[FAIL]|r " .. msg)
        end
    end

    -- ====== Money.parse ======
    ns.WoW.print("|cFF00FF00--- Money.parse ---|r")

    assert2(Money.parse("1g") == 10000, "1g should be 10000 copper")
    assert2(Money.parse("50s") == 5000, "50s should be 5000 copper")
    assert2(Money.parse("100c") == 100, "100c should be 100 copper")
    assert2(Money.parse("12s40c") == 1240, "12s40c should be 1240 copper")
    assert2(Money.parse("1g50s30c") == 15030, "1g50s30c should be 15030 copper")
    assert2(Money.parse("3g2s") == 30200, "3g2s should be 30200 copper")
    assert2(Money.parse("1G50S") == 15000, "1G50S should be 15000 copper (case insensitive)")
    assert2(Money.parse("invalid") == nil, "invalid should return nil")
    assert2(Money.parse("") == nil, "empty string should return nil")

    -- ====== Money.format ======
    ns.WoW.print("|cFF00FF00--- Money.format ---|r")

    assert2(Money.format(10000) == "1g", "10000 should format as 1g")
    assert2(Money.format(1240) == "12s40c", "1240 should format as 12s40c")
    assert2(Money.format(15030) == "1g50s30c", "15030 should format as 1g50s30c")
    assert2(Money.format(0) == "0c", "0 should format as 0c")
    assert2(Money.format(nil) == "—", "nil should format as —")
    assert2(Money.format(100) == "1s", "100 should format as 1s")
    assert2(Money.format(50) == "50c", "50 should format as 50c")

    -- ====== Prices ======
    ns.WoW.print("|cFF00FF00--- Prices ---|r")

    assert2(Prices.count() >= 0, "Prices.count() should return a number")
    local oldCount = Prices.count()

    Prices.set(99999, 1234)
    assert2(Prices.get(99999) == 1234, "Should get price we just set")
    assert2(Prices.count() == oldCount + 1, "Count should increase by 1")

    Prices.remove(99999)
    assert2(Prices.get(99999) == nil, "Price should be gone after remove")
    assert2(Prices.count() == oldCount, "Count should be back to original")

    -- ====== Calculator — raw material ======
    ns.WoW.print("|cFF00FF00--- Calculator (raw material) ---|r")

    -- Set a price for Copper Bar (2840) — raw material, not craftable in our DB
    Prices.set(2840, 1240) -- 12s40c
    local r = Calculator.calculate(2840)
    assert2(r ~= nil, "Copper Bar should have a cost")
    assert2(r.cost == 1240, "Copper Bar cost should be 1240")
    assert2(r.method == "buy", "Copper Bar should use buy method")

    -- ====== Calculator — simple craft (Copper Bolts) ======
    ns.WoW.print("|cFF00FF00--- Calculator (simple craft) ---|r")

    -- Copper Bolts (4359): 1x Copper Bar (2840)
    -- craft cost = 1240, no buy price set → method = craft
    local bolts = Calculator.calculate(4359)
    assert2(bolts ~= nil, "Copper Bolts should have a cost")
    assert2(bolts.cost == 1240, "Copper Bolts cost should be 1240 (1x Copper Bar)")
    assert2(bolts.method == "craft", "Copper Bolts should use craft method")
    assert2(bolts.breakdown ~= nil, "Copper Bolts should have breakdown")

    -- Set a buy price for Copper Bolts that's higher → should still craft
    Prices.set(4359, 1800) -- 18s (more expensive than crafting)
    local bolts2 = Calculator.calculate(4359)
    assert2(bolts2.method == "craft", "Copper Bolts should still craft (cheaper)")
    assert2(bolts2.cost == 1240, "Copper Bolts craft cost unchanged")

    -- Set a buy price for Copper Bolts that's lower → should buy
    Prices.set(4359, 1000) -- 10s (cheaper than crafting)
    local bolts3 = Calculator.calculate(4359)
    assert2(bolts3.method == "buy", "Copper Bolts should buy (cheaper)")
    assert2(bolts3.cost == 1000, "Copper Bolts buy cost = 1000")

    -- Reset to original test price
    Prices.set(4359, 1800)

    -- ====== Calculator — complex craft (Copper Modulator) ======
    ns.WoW.print("|cFF00FF00--- Calculator (complex craft) ---|r")

    -- Set price for Linen Cloth (2589)
    Prices.set(2589, 310) -- 3s10c

    -- Copper Modulator (4363): Linen Cloth x2, Copper Bar x1, Copper Bolts x2
    -- craft cost = 310*2 + 1240*1 + min(1800, 1240)*2 = 620 + 1240 + 2480 = 4340
    local modulator = Calculator.calculate(4363)
    assert2(modulator ~= nil, "Copper Modulator should have a cost")
    assert2(modulator.cost == 4340, "Copper Modulator cost should be 4340 (43s40c)")
    assert2(modulator.method == "craft", "Copper Modulator should use craft method")
    assert2(#modulator.breakdown == 3, "Copper Modulator should have 3 reagent lines")

    -- ====== Calculator — unpriceable ======
    ns.WoW.print("|cFF00FF00--- Calculator (unpriceable) ---|r")

    local unknown = Calculator.calculate(99999)
    assert2(unknown == nil, "Unknown item should be nil")

    -- ====== Calculator — cycle detection ======
    ns.WoW.print("|cFF00FF00--- Calculator (cycle detection) ---|r")

    -- Inject a fake cycle: make item 99998 craft from 99997, and 99997 craft from 99998
    ns.DB.recipes[88888] = {
        spellID = 88888, output = 99998,
        reagents = {{99997, 1}}, skillRequired = 1, source = "test"
    }
    ns.DB.recipes[88889] = {
        spellID = 88889, output = 99997,
        reagents = {{99998, 1}}, skillRequired = 1, source = "test"
    }
    local cycled = Calculator.calculate(99998)
    assert2(cycled == nil, "Cycle should be detected and return nil")
    -- Clean up
    ns.DB.recipes[88888] = nil
    ns.DB.recipes[88889] = nil

    -- ====== Analyze ======
    ns.WoW.print("|cFF00FF00--- Analyze ---|r")

    -- Set a sell price for Copper Modulator
    Prices.set(4363, 7200) -- 72s

    local profitList = Calculator.analyze()
    assert2(#profitList > 0, "Should find profitable crafts")

    -- Find Copper Modulator in results
    local found = false
    for _, entry in ipairs(profitList) do
        if entry.itemID == 4363 then
            found = true
            assert2(entry.sellPrice == 7200, "Sell price should be 7200")
            assert2(entry.craftCost == 4340, "Craft cost should be 4340")
            assert2(entry.profit == 2860, "Profit should be 2860 (28s60c)")
            assert2(entry.margin > 0, "Margin should be positive")
            break
        end
    end
    assert2(found, "Copper Modulator should appear in analyze results")

    -- ====== Savings ======
    ns.WoW.print("|cFF00FF00--- Savings ---|r")

    local savings = Calculator.savings()
    assert2(#savings > 0, "Should find savings (Copper Bolts)")

    -- ====== Summary ======
    ns.WoW.print(string.format(
        "|cFF00FF00[CraftGold]|r Tests: |cFF00FF00%d passed|r, |cFFFF0000%d failed|r",
        passed, failed))

    -- Clean up test prices
    Prices.remove(2840)
    Prices.remove(2589)
    Prices.remove(4359)
    Prices.remove(4363)
end

-------------------------------------------------
-- Event handling
-------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end

    -- Initialize WoW seam
    ns.WoW.init(_G)

    -- Initialize SavedVariables
    PriceCalcDB = PriceCalcDB or {}
    ns.Prices.init(PriceCalcDB)

    ns.WoW.print("|cFF00FF00[CraftGold]|r Loaded! " .. ns.Core.count() .. " Engineering recipes, " .. ns.Prices.count() .. " price(s) set.")
    ns.WoW.print("|cFF00FF00[CraftGold]|r Type |cFFFFFF00/cg help|r for commands.")

    self:UnregisterEvent("ADDON_LOADED")
end)
