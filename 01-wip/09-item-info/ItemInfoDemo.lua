-- ItemInfoDemo.lua
-- Shell: WoW integration (slash commands, events, SavedVariables init).
-- This is the only file that talks to WoW directly.
--
-- CAPSULE 09 FOCUS:
--   - New /iteminfo command for exploring C_Item.* APIs
--   - Preserved /cg commands from capsule 08 (now using ItemInfo module)
--   - In-game tests for ItemInfo module

local _, ns = ...

local addonName = "ItemInfoDemo"

-------------------------------------------------
-- Slash commands
-------------------------------------------------

SLASH_ITEMINFODEMO1 = "/iteminfo"
SLASH_ITEMINFODEMO2 = "/ii"

SlashCmdList["ITEMINFODEMO"] = function(input)
    local args = {}
    for word in (input or ""):gmatch("%S+") do
        args[#args + 1] = word
    end

    if #args == 0 or args[1]:lower() == "help" then
        cmdItemInfoHelp()
    elseif args[1]:lower() == "scan" then
        cmdItemInfoScan()
    elseif args[1]:lower() == "test" then
        cmdItemInfoTest()
    else
        -- /iteminfo <itemID> — show item details
        cmdItemInfoShow(args)
    end
end

-- Preserve /cg commands from capsule 08
SLASH_CRAFTGOLD1 = "/cg"
SLASH_CRAFTGOLD2 = "/craftgold"

SlashCmdList["CRAFTGOLD"] = function(input)
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
        cmdAnalyze(args)
    elseif args[1]:lower() == "detail" then
        cmdDetail(args)
    elseif args[1]:lower() == "test" then
        RunInGameTests()
    else
        ns.WoW.print("|cFF00FF00[CraftGold]|r Unknown command: " .. args[1])
        cmdHelp()
    end
end

-------------------------------------------------
-- /iteminfo help
-------------------------------------------------

function cmdItemInfoHelp()
    ns.WoW.print("|cFF4FC3F7[ItemInfo]|r Commands:")
    ns.WoW.print("  |cFFFFFF00/iteminfo <itemID>|r — Show item details (name, quality, icon, sell price)")
    ns.WoW.print("  |cFFFFFF00/iteminfo scan|r — Scan all DB items and show cache status")
    ns.WoW.print("  |cFFFFFF00/iteminfo test|r — Run ItemInfo module tests")
    ns.WoW.print("  |cFFFFFF00/iteminfo help|r — Show this help")
end

-------------------------------------------------
-- /iteminfo <itemID> — Explore C_Item.* APIs
-------------------------------------------------

function cmdItemInfoShow(args)
    local id = tonumber(args[1])
    if not id then
        ns.WoW.print("|cFFFF0000[ItemInfo]|r Usage: /iteminfo <itemID>")
        ns.WoW.print("  Example: /iteminfo 2840")
        return
    end

    local ItemInfo = ns.ItemInfo
    local PREFIX = "|cFF4FC3F7[ItemInfo]|r "

    -- 1. Instant info (always available for valid items)
    local instant = ItemInfo.getInstantInfo(id)
    if instant then
        ns.WoW.print(PREFIX .. string.format(
            "|cFFFFFF00Instant data (DB2 local):|r  type=%s  subType=%s  equipLoc=%s  icon=%s  classID=%s  subClassID=%s",
            tostring(instant.itemType),
            tostring(instant.itemSubType),
            tostring(instant.equipLoc),
            tostring(instant.icon),
            tostring(instant.classID),
            tostring(instant.subClassID)
        ))
    else
        ns.WoW.print(PREFIX .. "|cFFFF0000GetItemInfoInstant returned nil — item " .. id .. " does not exist|r")
        return
    end

    -- 2. Cache status
    local cached = ItemInfo.isCached(id)
    local cacheTag = cached and "|cFF00FF00YES|r" or "|cFFFF0000NO|r"
    ns.WoW.print(PREFIX .. "Cached: " .. cacheTag)

    -- 3. Full info (may be nil if not cached)
    local name = ItemInfo.getName(id)
    local quality = ItemInfo.getQuality(id)
    local icon = ItemInfo.getIcon(id)
    local sellPrice = ItemInfo.getSellPrice(id)
    local maxStack = ItemInfo.getMaxStack(id)

    ns.WoW.print(PREFIX .. string.format("Name: %s", name and name or "|cff808080(nil)|r"))
    ns.WoW.print(PREFIX .. string.format("Quality: %s  Icon: %s  MaxStack: %s  SellPrice: %s",
        quality ~= nil and tostring(quality) or "|cff808080nil|r",
        icon and tostring(icon) or "|cff808080nil|r",
        maxStack and tostring(maxStack) or "|cff808080nil|r",
        sellPrice and ns.Money.formatColored(sellPrice) or "|cff808080nil|r"
    ))

    -- 4. Full GetItemInfo dump (all 17 returns)
    local name2, link, quality2, itemLevel, reqLevel, class, subclass,
          maxStack2, equipLoc, texture, sellPrice2, classID, subclassID,
          bindType, expansionID, setID, isCraftingReagent = GetItemInfo(id)

    if name2 then
        ns.WoW.print(PREFIX .. "|cFFFFFF00Full GetItemInfo:|r")
        ns.WoW.print(PREFIX .. string.format("  itemLevel=%s  reqLevel=%s  bindType=%s  expansionID=%s",
            tostring(itemLevel), tostring(reqLevel), tostring(bindType), tostring(expansionID)))
        ns.WoW.print(PREFIX .. string.format("  class=%s  subclass=%s  classID=%s  subclassID=%s",
            tostring(class), tostring(subclass), tostring(classID), tostring(subclassID)))
        ns.WoW.print(PREFIX .. string.format("  isCraftingReagent=%s  setID=%s",
            tostring(isCraftingReagent), tostring(setID)))
        ns.WoW.print(PREFIX .. string.format("  link=%s", tostring(link)))
    else
        ns.WoW.print(PREFIX .. "|cff808080GetItemInfo returned nil — data not cached yet|r")

        -- Trigger async load and show what happens
        ns.WoW.print(PREFIX .. "Requesting load... (watch for callback)")
        ItemInfo.onLoad(id, function(loadedID)
            local loadedName = ItemInfo.getName(loadedID)
            ns.WoW.print(PREFIX .. string.format("|cFF00FF00Async callback!|r Item %d loaded: %s",
                loadedID, loadedName or "(still nil??)"))
        end)
    end
end

-------------------------------------------------
-- /iteminfo scan — Scan all DB items
-------------------------------------------------

function cmdItemInfoScan()
    local scan = ns.ItemInfo.scanDB()
    local PREFIX = "|cFF4FC3F7[ItemInfo]|r "

    ns.WoW.print(PREFIX .. string.format("DB Scan: |cFFFFFF00%d|r items total — |cFF00FF00%d cached|r — |cFFFF0000%d uncached|r",
        scan.total, scan.cached, scan.uncached))

    -- Show first 20 uncached items
    if scan.uncached > 0 then
        local shown = 0
        for _, item in ipairs(scan.items) do
            if not item.cached then
                shown = shown + 1
                if shown <= 20 then
                    ns.WoW.print(PREFIX .. string.format("  |cFFFF0000?|r item:%d — %s", item.id,
                        item.name or "not loaded"))
                end
            end
        end
        if scan.uncached > 20 then
            ns.WoW.print(PREFIX .. string.format("  |cFF808080... and %d more uncached|r", scan.uncached - 20))
        end
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
    ns.WoW.print("  |cFFFFFF00/cg analyze [N]|r — Show top N profitable crafts (default: all)")
    ns.WoW.print("  |cFFFFFF00/cg detail <itemID>|r — Detailed profit report with reagent tree")
    ns.WoW.print("  |cFFFFFF00/cg test|r — Run in-game tests")
    ns.WoW.print("  |cFFFFFF00/cg help|r — Show this help")
end

-------------------------------------------------
-- /cg price
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
            local name = ns.ItemInfo.formatName(itemID)
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
            local name = ns.ItemInfo.formatName(itemID)
            ns.WoW.print(string.format("|cFF00FF00[CraftGold]|r Removed price for %s (%d)", name, itemID))
        else
            ns.WoW.print(string.format("|cFF00FF00[CraftGold]|r No price set for item %d", itemID))
        end

    else
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
        local name = ns.ItemInfo.formatName(itemID)
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
    ns.Report.detail(itemID)
end

-------------------------------------------------
-- /cg analyze [N]
-------------------------------------------------

function cmdAnalyze(args)
    local n = tonumber(args[2])
    ns.Report.topCrafts(n)
end

-------------------------------------------------
-- /cg detail <itemID>
-------------------------------------------------

function cmdDetail(args)
    local itemID = tonumber(args[2])
    if not itemID then
        ns.WoW.print("|cFFFF0000[CraftGold]|r Usage: /cg detail <itemID>")
        return
    end
    ns.Report.detail(itemID)
end

-------------------------------------------------
-- /iteminfo test — ItemInfo module tests
-------------------------------------------------

function cmdItemInfoTest()
    local ItemInfo = ns.ItemInfo
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

    ns.WoW.print("|cFF4FC3F7--- ItemInfo module tests ---|r")

    -- Test with a well-known item: Copper Bar (2840)
    local copperBar = 2840

    -- Get the expected name from the client (locale-dependent)
    local expectedName = GetItemInfo(copperBar)

    -- getName should return a string for a cached item
    local name = ItemInfo.getName(copperBar)
    assert2(type(name) == "string", "getName(2840) should return string, got: " .. type(name))
    assert2(name == expectedName, "getName(2840) should be '" .. tostring(expectedName) .. "', got: " .. tostring(name))

    -- isCached should return true for common items
    local cached = ItemInfo.isCached(copperBar)
    assert2(cached == true, "isCached(2840) should be true, got: " .. tostring(cached))

    -- getInfo should return a table with expected fields
    local info = ItemInfo.getInfo(copperBar)
    assert2(info ~= nil, "getInfo(2840) should not be nil")
    if info then
        assert2(type(info.name) == "string", "info.name should be string")
        assert2(type(info.quality) == "number", "info.quality should be number")
        assert2(type(info.maxStack) == "number", "info.maxStack should be number")
        assert2(type(info.sellPrice) == "number", "info.sellPrice should be number")
        assert2(info.quality == 1, "Copper Bar quality should be 1 (Common), got: " .. tostring(info.quality))
    end

    -- getQuality
    local quality = ItemInfo.getQuality(copperBar)
    assert2(quality == 1, "getQuality(2840) should be 1, got: " .. tostring(quality))

    -- getIcon
    local icon = ItemInfo.getIcon(copperBar)
    assert2(icon ~= nil, "getIcon(2840) should not be nil")
    assert2(type(icon) == "number", "getIcon(2840) should be a number (fileID), got: " .. type(icon))

    -- getSellPrice
    local sellPrice = ItemInfo.getSellPrice(copperBar)
    assert2(sellPrice ~= nil, "getSellPrice(2840) should not be nil")
    assert2(type(sellPrice) == "number", "getSellPrice(2840) should be number")

    -- getMaxStack
    local maxStack = ItemInfo.getMaxStack(copperBar)
    assert2(maxStack ~= nil, "getMaxStack(2840) should not be nil")
    assert2(type(maxStack) == "number", "getMaxStack(2840) should be number")

    -- getInstantInfo (should always work for valid items)
    local instant = ItemInfo.getInstantInfo(copperBar)
    assert2(instant ~= nil, "getInstantInfo(2840) should not be nil")
    if instant then
        assert2(instant.itemID == copperBar, "instant.itemID should be 2840")
        assert2(type(instant.icon) == "number", "instant.icon should be number")
        assert2(type(instant.classID) == "number", "instant.classID should be number")
    end

    -- formatName — cached item
    local formatted = ItemInfo.formatName(copperBar)
    assert2(formatted == expectedName, "formatName(2840) should be '" .. tostring(expectedName) .. "', got: " .. tostring(formatted))

    -- formatName — unknown item (should show fallback)
    local unknownFormatted = ItemInfo.formatName(99999)
    assert2(unknownFormatted:find("item:99999") ~= nil, "formatName(99999) should contain 'item:99999'")

    -- formatColoredName — should have color codes for known items
    local colored = ItemInfo.formatColoredName(copperBar)
    assert2(colored:find(expectedName) ~= nil, "formatColoredName(2840) should contain '" .. tostring(expectedName) .. "'")
    assert2(colored:find("|cff") ~= nil or colored:find("|cFF") ~= nil,
        "formatColoredName(2840) should contain color codes")

    -- scanDB
    local scan = ItemInfo.scanDB()
    assert2(scan.total > 0, "scanDB should find items from the recipe DB")
    assert2(scan.cached + scan.uncached == scan.total, "cached + uncached should equal total")
    assert2(type(scan.items) == "table", "scanDB should return items table")

    -- Test with an invalid item
    assert2(ItemInfo.getName(0) == nil, "getName(0) should be nil")
    assert2(ItemInfo.getInstantInfo(0) == nil, "getInstantInfo(0) should be nil")

    -- Summary
    ns.WoW.print(string.format(
        "|cFF4FC3F7[ItemInfo]|r Tests: |cFF00FF00%d passed|r, |cFFFF0000%d failed|r",
        passed, failed))
end

-------------------------------------------------
-- In-game tests (preserved from capsule 08)
-------------------------------------------------

function RunInGameTests()
    local Money      = ns.Money
    local Prices     = ns.Prices
    local Calculator = ns.Calculator
    local Core       = ns.Core

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
    assert2(Money.format(1240) == "12s 40c", "1240 should format as 12s 40c")
    assert2(Money.format(15030) == "1g 50s 30c", "15030 should format as 1g 50s 30c")
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

    Prices.set(2840, 1240)
    local r = Calculator.calculate(2840)
    assert2(r ~= nil, "Copper Bar should have a cost")
    assert2(r.cost == 1240, "Copper Bar cost should be 1240")
    assert2(r.method == "buy", "Copper Bar should use buy method")

    -- ====== Calculator — simple craft (Copper Bolts) ======
    ns.WoW.print("|cFF00FF00--- Calculator (simple craft) ---|r")

    local bolts = Calculator.calculate(4359)
    assert2(bolts ~= nil, "Copper Bolts should have a cost")
    assert2(bolts.cost == 1240, "Copper Bolts cost should be 1240 (1x Copper Bar)")
    assert2(bolts.method == "craft", "Copper Bolts should use craft method")
    assert2(bolts.breakdown ~= nil, "Copper Bolts should have breakdown")

    Prices.set(4359, 1800)
    local bolts2 = Calculator.calculate(4359)
    assert2(bolts2.method == "craft", "Copper Bolts should still craft (cheaper)")
    assert2(bolts2.cost == 1240, "Copper Bolts craft cost unchanged")

    Prices.set(4359, 1000)
    local bolts3 = Calculator.calculate(4359)
    assert2(bolts3.method == "buy", "Copper Bolts should buy (cheaper)")
    assert2(bolts3.cost == 1000, "Copper Bolts buy cost = 1000")

    Prices.set(4359, 1800)

    -- ====== Calculator — complex craft (Copper Modulator) ======
    ns.WoW.print("|cFF00FF00--- Calculator (complex craft) ---|r")

    Prices.set(2589, 310)

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
    ns.DB.recipes[88888] = nil
    ns.DB.recipes[88889] = nil

    -- ====== Analyze ======
    ns.WoW.print("|cFF00FF00--- Analyze ---|r")

    Prices.set(4363, 7200)

    local profitList = Calculator.analyze()
    assert2(#profitList > 0, "Should find profitable crafts")

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

    -- ====== Summary ======
    ns.WoW.print(string.format(
        "|cFF00FF00[CraftGold]|r Tests: |cFF00FF00%d passed|r, |cFFFF0000%d failed|r",
        passed, failed))

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
    ItemInfoDemoDB = ItemInfoDemoDB or {}
    ns.Prices.init(ItemInfoDemoDB)

    ns.WoW.print("|cFF4FC3F7[ItemInfo]|r Loaded! " .. ns.Core.count() .. " recipes, " .. ns.Prices.count() .. " price(s).")
    ns.WoW.print("|cFF4FC3F7[ItemInfo]|r |cFFFFFF00/iteminfo <id>|r to explore C_Item.* APIs, |cFFFFFF00/cg help|r for CraftGold commands.")

    self:UnregisterEvent("ADDON_LOADED")
end)
