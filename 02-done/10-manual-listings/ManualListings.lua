-- ManualListings.lua
-- Shell: WoW integration (slash commands, events, SavedVariables init).
-- This is the only file that talks to WoW directly.
--
-- CAPSULE 10 FOCUS:
--   - New /cg listing commands for managing AH listings
--   - Listings model: each item has multiple stacks {count, buyout}
--   - Coexists with existing /cg price commands (Calculator untouched)
--   - /cg run for batch commands (semicolon-separated)
--   - /cg log for capturing output to file (via SavedVariables)

local _, ns = ...
_G.cgNS = ns  -- Expose namespace for /run debugging

local addonName = "ManualListings"

-------------------------------------------------
-- Log system
-------------------------------------------------
-- Captures all CraftGold output to ManualListingsDB.log
-- After /reload, the log is flushed to disk and can be read externally.

local _logBuffer = nil       -- nil = not logging, {} = active
local _origPrint = nil       -- saved original ns.WoW.print

-- Strip WoW color codes for clean text log
local function stripColors(str)
    return (str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function logPrint(msg)
    -- Always call original print (chat output)
    if _origPrint then _origPrint(msg) end
    -- Also append to log buffer if active
    if _logBuffer then
        _logBuffer[#_logBuffer + 1] = stripColors(msg)
    end
end

-------------------------------------------------
-- Slash commands
-------------------------------------------------

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
    elseif args[1]:lower() == "listing" then
        cmdListing(args)
    elseif args[1]:lower() == "run" then
        cmdRun(input)
    elseif args[1]:lower() == "log" then
        cmdLog(args)
    elseif args[1]:lower() == "cost" then
        cmdCost(args)
    elseif args[1]:lower() == "analyze" then
        cmdAnalyze(args)
    elseif args[1]:lower() == "detail" then
        cmdDetail(args)
    elseif args[1]:lower() == "reset" then
        cmdReset()
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
    ns.WoW.print("  |cFFFFFF00/cg listing add <itemID> <count> <buyout>|r — Add a listing (stack)")
    ns.WoW.print("  |cFFFFFF00/cg listing list [itemID]|r — Show listings")
    ns.WoW.print("  |cFFFFFF00/cg listing remove <itemID> <index>|r — Remove listing #index")
    ns.WoW.print("  |cFFFFFF00/cg listing clear <itemID>|r — Remove all listings for an item")
    ns.WoW.print("  |cFFFFFF00/cg cost <itemID>|r — Show recursive cost breakdown")
    ns.WoW.print("  |cFFFFFF00/cg analyze [N]|r — Show top N profitable crafts (default: all)")
    ns.WoW.print("  |cFFFFFF00/cg detail <itemID>|r — Detailed profit report with reagent tree")
    ns.WoW.print("  |cFFFFFF00/cg run <cmd1; cmd2; ...>|r — Run multiple commands (semicolon-separated)")
    ns.WoW.print("  |cFFFFFF00/cg log on|off|clear|show|r — Capture output to file (survives /reload)")
    ns.WoW.print("  |cFFFFFF00/cg reset|r — Clear all prices and listings")
    ns.WoW.print("  |cFFFFFF00/cg test|r — Run in-game tests")
    ns.WoW.print("  |cFFFFFF00/cg help|r — Show this help")
end

-------------------------------------------------
-- /cg run — batch commands
-------------------------------------------------

function cmdRun(input)
    -- Extract everything after "run "
    local rest = input:match("^%S+%s+(.*)$")
    if not rest or rest == "" then
        ns.WoW.print("|cFFFF0000[CraftGold]|r Usage: /cg run <cmd1; cmd2; ...>")
        ns.WoW.print("  Example: /cg run price 2840 12s40c; listing add 2840 20 10g; listing list")
        return
    end

    local count = 0
    for cmd in rest:gmatch("([^;]+)") do
        cmd = cmd:match("^%s*(.-)%s*$")  -- trim whitespace
        if cmd ~= "" then
            count = count + 1
            SlashCmdList["CRAFTGOLD"](cmd)
        end
    end

    ns.WoW.print(string.format("|cFF808080[run]|r Executed %d command(s)", count))
end

-------------------------------------------------
-- /cg log — output capture
-------------------------------------------------

function cmdLog(args)
    local sub = (args[2] or ""):lower()

    if sub == "on" then
        if _logBuffer then
            ns.WoW.print("|cFF4FC3F7[Log]|r Already logging (" .. #_logBuffer .. " lines)")
            return
        end
        _logBuffer = ManualListingsDB.log or {}
        ManualListingsDB.log = _logBuffer
        -- Hook print
        _origPrint = ns.WoW.print
        ns.WoW.print = logPrint
        ManualListingsDB._logActive = true
        ns.WoW.print("|cFF4FC3F7[Log]|r Logging started. Output will be saved after /reload.")

    elseif sub == "off" then
        if not _logBuffer then
            ns.WoW.print("|cFF4FC3F7[Log]|r Not currently logging")
            return
        end
        ManualListingsDB._logActive = false
        ns.WoW.print("|cFF4FC3F7[Log]|r Logging stopped. " .. #_logBuffer .. " lines captured.")
        -- Restore original print
        if _origPrint then
            ns.WoW.print = _origPrint
            _origPrint = nil
        end
        _logBuffer = nil

    elseif sub == "clear" then
        ManualListingsDB.log = {}
        if _logBuffer then
            _logBuffer = ManualListingsDB.log
        end
        ns.WoW.print("|cFF4FC3F7[Log]|r Log cleared.")

    elseif sub == "show" then
        local log = ManualListingsDB.log or {}
        if #log == 0 then
            ns.WoW.print("|cFF4FC3F7[Log]|r Log is empty.")
            return
        end
        ns.WoW.print(string.format("|cFF4FC3F7[Log]|r %d line(s):", #log))
        for i, line in ipairs(log) do
            ns.WoW.print(string.format("  |cFF808080%03d|r %s", i, line))
        end

    else
        ns.WoW.print("|cFF4FC3F7[Log]|r Commands:")
        ns.WoW.print("  |cFFFFFF00/cg log on|r — Start capturing output")
        ns.WoW.print("  |cFFFFFF00/cg log off|r — Stop capturing")
        ns.WoW.print("  |cFFFFFF00/cg log clear|r — Clear the log")
        ns.WoW.print("  |cFFFFFF00/cg log show|r — Show the log in chat")
        ns.WoW.print("  Log is saved to disk on /reload. " ..
            string.format("(%d line(s) currently)", #(ManualListingsDB.log or {})))
    end
end

-------------------------------------------------
-- /cg price (preserved from capsule 07)
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

    elseif sub == "remove" or sub == "delete" then
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
-- /cg listing (NEW — Capsule 10)
-------------------------------------------------

function cmdListing(args)
    local sub = (args[2] or ""):lower()

    if sub == "add" then
        cmdListingAdd(args)
    elseif sub == "list" then
        cmdListingList(args)
    elseif sub == "remove" then
        cmdListingRemove(args)
    elseif sub == "clear" then
        cmdListingClear(args)
    else
        ns.WoW.print("|cFF4FC3F7[Listings]|r Commands:")
        ns.WoW.print("  |cFFFFFF00/cg listing add <itemID> <count> <buyout>|r — Add a stack listing")
        ns.WoW.print("  |cFFFFFF00/cg listing list [itemID]|r — Show all listings or for one item")
        ns.WoW.print("  |cFFFFFF00/cg listing remove <itemID> <index>|r — Remove listing #index")
        ns.WoW.print("  |cFFFFFF00/cg listing clear <itemID>|r — Remove all listings for an item")
        ns.WoW.print("  Examples:")
        ns.WoW.print("    /cg listing add 2840 20 10g      — 20x Copper Bars at 10g/stack")
        ns.WoW.print("    /cg listing add 2840 5 2s50c     — 5x Copper Bars at 2s50c/stack")
    end
end

function cmdListingAdd(args)
    local itemID   = tonumber(args[3])
    local count    = tonumber(args[4])
    local buyoutStr = args[5]

    if not itemID or not count or not buyoutStr then
        ns.WoW.print("|cFFFF0000[CraftGold]|r Usage: /cg listing add <itemID> <count> <buyout>")
        ns.WoW.print("  Example: /cg listing add 2840 20 10g")
        return
    end

    if count <= 0 then
        ns.WoW.print("|cFFFF0000[CraftGold]|r Count must be > 0")
        return
    end

    local buyout, err = ns.Money.parse(buyoutStr)
    if not buyout then
        ns.WoW.print("|cFFFF0000[CraftGold]|r " .. err)
        return
    end

    local idx = ns.Listings.add(itemID, count, buyout)
    if not idx then
        ns.WoW.print("|cFFFF0000[CraftGold]|r Failed to add listing")
        return
    end

    local name = ns.ItemInfo.formatName(itemID)
    local unitPrice = math.floor(buyout / count)
    ns.WoW.print(string.format("|cFF4FC3F7[Listings]|r Added #%d for %s (%d): |cFFFFFF00%d|r stack at %s (≈ %s/unit)",
        idx, name, itemID, count,
        ns.Money.formatColored(buyout),
        ns.Money.formatColored(unitPrice)))
end

function cmdListingList(args)
    local filterID = tonumber(args[3])

    if filterID then
        -- Show listings for one item
        local listings = ns.Listings.getListings(filterID)
        local name = ns.ItemInfo.formatName(filterID)
        local count = #listings

        if count == 0 then
            ns.WoW.print(string.format("|cFF4FC3F7[Listings]|r No listings for %s (%d)", name, filterID))
            return
        end

        ns.WoW.print(string.format("|cFF4FC3F7[Listings]|r %s (%d) — %d listing(s):", name, filterID, count))
        for i, listing in ipairs(listings) do
            local unitPrice = math.floor(listing.buyout / listing.count)
            ns.WoW.print(string.format("  |cFFFFFF00#%d|r  |cFFFFFFFF%d|r stack at %s (≈ %s/unit)",
                i, listing.count,
                ns.Money.formatColored(listing.buyout),
                ns.Money.formatColored(unitPrice)))
        end
    else
        -- Show all listings grouped by item
        local all = ns.Listings.getAll()
        local itemCount = ns.Listings.count()

        if itemCount == 0 then
            ns.WoW.print("|cFF4FC3F7[Listings]|r No listings. Use /cg listing add <itemID> <count> <buyout>")
            return
        end

        ns.WoW.print(string.format("|cFF4FC3F7[Listings]|r %d item(s) with listings:", itemCount))
        for itemID, listings in pairs(all) do
            local name = ns.ItemInfo.formatName(itemID)
            local totalQty = 0
            local totalCost = 0
            for _, l in ipairs(listings) do
                totalQty = totalQty + l.count
                totalCost = totalCost + l.buyout
            end
            ns.WoW.print(string.format("  %s (%d) — |cFFFFFFFF%d|r stack(s), %d total items, total value %s",
                name, itemID, #listings, totalQty, ns.Money.formatColored(totalCost)))

            for i, listing in ipairs(listings) do
                local unitPrice = math.floor(listing.buyout / listing.count)
                ns.WoW.print(string.format("    |cFFFFFF00#%d|r  %d stack at %s (≈ %s/unit)",
                    i, listing.count,
                    ns.Money.formatColored(listing.buyout),
                    ns.Money.formatColored(unitPrice)))
            end
        end
    end
end

function cmdListingRemove(args)
    local itemID = tonumber(args[3])
    local index  = tonumber(args[4])

    if not itemID or not index then
        ns.WoW.print("|cFFFF0000[CraftGold]|r Usage: /cg listing remove <itemID> <index>")
        ns.WoW.print("  Use /cg listing list <itemID> to see indexes")
        return
    end

    local name = ns.ItemInfo.formatName(itemID)
    local ok = ns.Listings.remove(itemID, index)
    if ok then
        ns.WoW.print(string.format("|cFF4FC3F7[Listings]|r Removed listing #%d for %s (%d)", index, name, itemID))
    else
        ns.WoW.print(string.format("|cFFFF0000[CraftGold]|r No listing #%d for %s (%d)", index, name, itemID))
    end
end

function cmdListingClear(args)
    local itemID = tonumber(args[3])

    if not itemID then
        ns.WoW.print("|cFFFF0000[CraftGold]|r Usage: /cg listing clear <itemID>")
        return
    end

    local name = ns.ItemInfo.formatName(itemID)
    local count = ns.Listings.countListings(itemID)
    ns.Listings.clear(itemID)
    ns.WoW.print(string.format("|cFF4FC3F7[Listings]|r Cleared %d listing(s) for %s (%d)", count, name, itemID))
end

-------------------------------------------------
-- /cg reset — Clear everything
-------------------------------------------------

function cmdReset()
    local priceCount = ns.Prices.count()
    local listingCount = ns.Listings.count()

    -- Clear all prices
    local prices = ns.Prices.getAll()
    for itemID in pairs(prices) do
        ns.Prices.remove(itemID)
    end

    -- Clear all listings
    ns.Listings.clear()  -- no itemID = clear all

    ns.WoW.print(string.format("|cFF4FC3F7[Reset]|r Cleared %d price(s) and %d item(s) with listings.",
        priceCount, listingCount))
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
-- In-game tests
-------------------------------------------------

function RunInGameTests()
    local Money      = ns.Money
    local Prices     = ns.Prices
    local Listings   = ns.Listings
    local Calculator = ns.Calculator

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

    -- ====== Save pre-existing state (will be restored after tests) ======
    local savedPrices = {}
    local savedListings = {}
    local testItemIDs = {2840, 2589, 4359, 4363, 90001, 90002, 90003}
    for _, id in ipairs(testItemIDs) do
        savedPrices[id] = Prices.get(id)
        local lst = Listings.getListings(id)
        if #lst > 0 then
            savedListings[id] = {}
            for i, l in ipairs(lst) do
                savedListings[id][i] = { count = l.count, buyout = l.buyout }
            end
        end
    end

    -- ====== Cleanup for test isolation ======
    for _, id in ipairs(testItemIDs) do
        Listings.clear(id)
        Prices.remove(id)
    end

    -- ====== Listings — basic CRUD ======
    ns.WoW.print("|cFF4FC3F7--- Listings: basic CRUD ---|r")

    -- Add listings
    local idx1 = Listings.add(90001, 20, 10000)
    assert2(idx1 == 1, "First listing should be index 1")
    local idx2 = Listings.add(90001, 5, 2500)
    assert2(idx2 == 2, "Second listing should be index 2")
    local idx3 = Listings.add(90001, 10, 3000)
    assert2(idx3 == 3, "Third listing should be index 3")

    -- Count
    assert2(Listings.countListings(90001) == 3, "Should have 3 listings for item 90001")
    assert2(Listings.count() >= 1, "At least 1 item with listings")

    -- Get listings
    local l = Listings.getListings(90001)
    assert2(#l == 3, "Should get 3 listings back")
    assert2(l[1].count == 20, "Listing 1 count should be 20")
    assert2(l[1].buyout == 10000, "Listing 1 buyout should be 10000")
    assert2(l[2].count == 5, "Listing 2 count should be 5")
    assert2(l[2].buyout == 2500, "Listing 2 buyout should be 2500")

    -- Empty item
    assert2(#Listings.getListings(90002) == 0, "Item with no listings should return empty table")
    assert2(Listings.countListings(90002) == 0, "countListings for empty item should be 0")

    -- ====== Listings — remove by index ======
    ns.WoW.print("|cFF4FC3F7--- Listings: remove by index ---|r")

    local ok = Listings.remove(90001, 2)
    assert2(ok == true, "Remove should succeed for valid index")
    assert2(Listings.countListings(90001) == 2, "Should have 2 listings after remove")
    l = Listings.getListings(90001)
    assert2(l[1].count == 20, "After remove, listing 1 unchanged (20)")
    assert2(l[2].count == 10, "After remove, listing 2 is now the old #3 (10)")

    -- Remove invalid index
    ok = Listings.remove(90001, 99)
    assert2(ok == false, "Remove should fail for invalid index")
    assert2(Listings.countListings(90001) == 2, "Count unchanged after failed remove")

    -- ====== Listings — clear ======
    ns.WoW.print("|cFF4FC3F7--- Listings: clear ---|r")

    Listings.clear(90001)
    assert2(Listings.countListings(90001) == 0, "Should have 0 listings after clear")
    assert2(#Listings.getListings(90001) == 0, "getListings should return empty after clear")

    -- ====== Listings — auto-cleanup of empty item ======
    ns.WoW.print("|cFF4FC3F7--- Listings: auto-cleanup ---|r")

    Listings.add(90003, 1, 100)
    assert2(Listings.countListings(90003) == 1, "Should have 1 listing")
    Listings.remove(90003, 1)
    -- getListings returns {} for items with no data (public API returns empty, not nil)
    local remaining = Listings.getListings(90003)
    assert2(#remaining == 0, "getListings should return empty table for cleaned item")

    -- But internally, the key is truly gone
    local all = Listings.getAll()
    assert2(all[90003] == nil, "Internal data for 90003 should be nil after removing last listing")

    -- ====== Listings — validation ======
    ns.WoW.print("|cFF4FC3F7--- Listings: validation ---|r")

    assert2(Listings.add(nil, 5, 100) == nil, "add with nil itemID should fail")
    assert2(Listings.add(90001, 0, 100) == nil, "add with count=0 should fail")
    assert2(Listings.add(90001, -1, 100) == nil, "add with negative count should fail")
    assert2(Listings.add(90001, 5, -1) == nil, "add with negative buyout should fail")
    assert2(Listings.add("abc", 5, 100) == nil, "add with string itemID should fail")

    -- ====== Coexistence with Prices ======
    ns.WoW.print("|cFF4FC3F7--- Coexistence: Prices + Listings ---|r")

    Prices.set(2840, 1240)
    Listings.add(2840, 20, 10000)
    Listings.add(2840, 5, 2500)

    -- Prices still works independently
    assert2(Prices.get(2840) == 1240, "Prices.get should still work (coexistence)")
    -- Listings also works
    assert2(Listings.countListings(2840) == 2, "Listings for 2840 should have 2 entries")

    -- Calculator still works (uses Prices, not Listings)
    local r = Calculator.calculate(2840)
    assert2(r ~= nil, "Calculator should still work")
    assert2(r.cost == 1240, "Calculator cost should come from Prices (1240)")
    assert2(r.method == "buy", "Calculator method should be buy")

    -- ====== Money.parse (preserved from capsule 07) ======
    ns.WoW.print("|cFF00FF00--- Money.parse ---|r")

    assert2(Money.parse("1g") == 10000, "1g should be 10000 copper")
    assert2(Money.parse("50s") == 5000, "50s should be 5000 copper")
    assert2(Money.parse("100c") == 100, "100c should be 100 copper")
    assert2(Money.parse("12s40c") == 1240, "12s40c should be 1240 copper")
    assert2(Money.parse("1g50s30c") == 15030, "1g50s30c should be 15030 copper")
    assert2(Money.parse("3g2s") == 30200, "3g2s should be 30200 copper")

    -- ====== Calculator (preserved) ======
    ns.WoW.print("|cFF00FF00--- Calculator ---|r")

    Prices.set(2589, 310)
    local bolts = Calculator.calculate(4359)
    assert2(bolts ~= nil, "Copper Bolts should have a cost")
    assert2(bolts.cost == 1240, "Copper Bolts cost should be 1240")
    assert2(bolts.method == "craft", "Copper Bolts should use craft method")

    -- ====== Restore pre-existing state ======
    for _, id in ipairs(testItemIDs) do
        -- Remove everything first (tests may have set prices that didn't exist before)
        Prices.remove(id)
        Listings.clear(id)
        -- Restore what was there before
        if savedPrices[id] then
            Prices.set(id, savedPrices[id])
        end
        if savedListings[id] then
            for _, l in ipairs(savedListings[id]) do
                Listings.add(id, l.count, l.buyout)
            end
        end
    end

    -- ====== Summary ======
    ns.WoW.print(string.format(
        "|cFF00FF00[CraftGold]|r Tests: |cFF00FF00%d passed|r, |cFFFF0000%d failed|r",
        passed, failed))
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
    ManualListingsDB = ManualListingsDB or {}
    ns.Prices.init(ManualListingsDB)
    ns.Listings.init(ManualListingsDB)

    -- Restore log if it was active before reload
    if ManualListingsDB._logActive then
        _logBuffer = ManualListingsDB.log or {}
        ManualListingsDB.log = _logBuffer
        _origPrint = ns.WoW.print
        ns.WoW.print = logPrint
        ns.WoW.print("|cFF4FC3F7[Log]|r Logging resumed (" .. #_logBuffer .. " existing lines).")
    end

    ns.WoW.print("|cFF4FC3F7[ManualListings]|r Loaded! "
        .. ns.Core.count() .. " recipes, "
        .. ns.Prices.count() .. " price(s), "
        .. ns.Listings.count() .. " item(s) with listings.")
    ns.WoW.print("|cFF4FC3F7[ManualListings]|r |cFFFFFF00/cg help|r for commands.")

    self:UnregisterEvent("ADDON_LOADED")
end)
