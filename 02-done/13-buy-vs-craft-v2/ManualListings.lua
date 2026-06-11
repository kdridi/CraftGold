-- ManualListings.lua
-- Shell: WoW integration (slash commands, events, SavedVariables init).
-- This is the only file that talks to WoW directly.
--
-- CAPSULE 11 FOCUS:
--   - CmdLang: declarative command language (parse, dispatch, help, errors)
--   - /cg quote <itemID> <qty> — DP covering knapsack
--   - All capsule 10 features preserved (listings, prices, batch, log)
--   - /cg run is gone — batch is now native via semicolons

local _, ns = ...
_G.cgNS = ns  -- Expose namespace for /run debugging

local CmdLang = ns.CmdLang
local cmd = CmdLang.new()
ns.cmd = cmd  -- Expose for external access

local addonName = "ManualListings"

-------------------------------------------------
-- Log system
-------------------------------------------------

local _logBuffer = nil
local _origPrint = nil

local function stripColors(str)
    return (str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function logPrint(msg)
    if _origPrint then _origPrint(msg) end
    if _logBuffer then
        _logBuffer[#_logBuffer + 1] = stripColors(msg)
    end
end

local function printMsg(msg)
    ns.WoW.print(msg)
end

-------------------------------------------------
-- Register commands with CmdLang
-------------------------------------------------

-- /cg price <itemID> <buyout>
cmd:register {
    name = "price",
    help = "Set or manage item prices",
    args = {
        { "itemID:int",   "Item ID" },
        { "buyout:money", "Price (e.g. 12s40c, 1g50s)" },
    },
    handler = function(a)
        ns.Prices.set(a.itemID, a.buyout)
        local name = ns.ItemInfo.formatName(a.itemID)
        printMsg(string.format("|cFF00FF00[CraftGold]|r %s (%d) = %s",
            name, a.itemID, ns.Money.formatColored(a.buyout)))
    end,
}

-- /cg price list
cmd:register {
    name = "price",
    subs = {
        list = {
            help = "Show all prices",
            handler = function()
                local prices = ns.Prices.getAll()
                local count = ns.Prices.count()
                if count == 0 then
                    printMsg("|cFF00FF00[CraftGold]|r No prices set. Use /cg price <itemID> <price>")
                    return
                end
                printMsg(string.format("|cFF00FF00[CraftGold]|r %d price(s) set:", count))
                for itemID, copper in pairs(prices) do
                    local name = ns.ItemInfo.formatName(itemID)
                    printMsg(string.format("  %s (%d) = %s", name, itemID, ns.Money.formatColored(copper)))
                end
            end,
        },
        remove = {
            help = "Remove a price",
            args = { { "itemID:int", "Item ID" } },
            handler = function(a)
                local old = ns.Prices.get(a.itemID)
                ns.Prices.remove(a.itemID)
                if old then
                    local name = ns.ItemInfo.formatName(a.itemID)
                    printMsg(string.format("|cFF00FF00[CraftGold]|r Removed price for %s (%d)", name, a.itemID))
                else
                    printMsg(string.format("|cFF00FF00[CraftGold]|r No price set for item %d", a.itemID))
                end
            end,
        },
    },
}

-- /cg listing add/list/remove/clear
cmd:register {
    name = "listing",
    help = "Manage AH listings (indivisible stacks)",
    subs = {
        add = {
            help = "Add a listing",
            args = {
                { "itemID:int",   "Item ID" },
                { "count:int",    "Stack size" },
                { "buyout:money", "Buyout price" },
            },
            handler = function(a)
                local idx = ns.Listings.add(a.itemID, a.count, a.buyout)
                if not idx then
                    printMsg("|cFFFF0000[CraftGold]|r Failed to add listing")
                    return
                end
                local name = ns.ItemInfo.formatName(a.itemID)
                local unitPrice = math.floor(a.buyout / a.count)
                printMsg(string.format(
                    "|cFF4FC3F7[Listings]|r Added #%d for %s (%d): |cFFFFFF00%d|r stack at %s (≈ %s/unit)",
                    idx, name, a.itemID, a.count,
                    ns.Money.formatColored(a.buyout),
                    ns.Money.formatColored(unitPrice)))
            end,
        },
        list = {
            help = "Show listings",
            args = { { "itemID:int?", "Filter by item" } },
            handler = function(a)
                if a.itemID then
                    local listings = ns.Listings.getListings(a.itemID)
                    local name = ns.ItemInfo.formatName(a.itemID)
                    if #listings == 0 then
                        printMsg(string.format("|cFF4FC3F7[Listings]|r No listings for %s (%d)", name, a.itemID))
                        return
                    end
                    printMsg(string.format("|cFF4FC3F7[Listings]|r %s (%d) — %d listing(s):", name, a.itemID, #listings))
                    for i, l in ipairs(listings) do
                        local unitPrice = math.floor(l.buyout / l.count)
                        printMsg(string.format("  |cFFFFFF00#%d|r  |cFFFFFFFF%d|r stack at %s (≈ %s/unit)",
                            i, l.count,
                            ns.Money.formatColored(l.buyout),
                            ns.Money.formatColored(unitPrice)))
                    end
                else
                    local all = ns.Listings.getAll()
                    local itemCount = ns.Listings.count()
                    if itemCount == 0 then
                        printMsg("|cFF4FC3F7[Listings]|r No listings. Use /cg listing add <itemID> <count> <buyout>")
                        return
                    end
                    printMsg(string.format("|cFF4FC3F7[Listings]|r %d item(s) with listings:", itemCount))
                    for itemID, listings in pairs(all) do
                        local name = ns.ItemInfo.formatName(itemID)
                        local totalQty, totalCost = 0, 0
                        for _, l in ipairs(listings) do
                            totalQty = totalQty + l.count
                            totalCost = totalCost + l.buyout
                        end
                        printMsg(string.format("  %s (%d) — |cFFFFFFFF%d|r stack(s), %d total, %s",
                            name, itemID, #listings, totalQty, ns.Money.formatColored(totalCost)))
                        for i, l in ipairs(listings) do
                            local unitPrice = math.floor(l.buyout / l.count)
                            printMsg(string.format("    |cFFFFFF00#%d|r  %d at %s (≈ %s/unit)",
                                i, l.count,
                                ns.Money.formatColored(l.buyout),
                                ns.Money.formatColored(unitPrice)))
                        end
                    end
                end
            end,
        },
        remove = {
            help = "Remove a listing by index",
            args = {
                { "itemID:int", "Item ID" },
                { "index:int",  "Listing index" },
            },
            handler = function(a)
                local name = ns.ItemInfo.formatName(a.itemID)
                local ok = ns.Listings.remove(a.itemID, a.index)
                if ok then
                    printMsg(string.format("|cFF4FC3F7[Listings]|r Removed #%d for %s (%d)", a.index, name, a.itemID))
                else
                    printMsg(string.format("|cFFFF0000[CraftGold]|r No listing #%d for %s (%d)", a.index, name, a.itemID))
                end
            end,
        },
        clear = {
            help = "Clear all listings for an item",
            args = { { "itemID:int", "Item ID" } },
            handler = function(a)
                local name = ns.ItemInfo.formatName(a.itemID)
                local count = ns.Listings.countListings(a.itemID)
                ns.Listings.clear(a.itemID)
                printMsg(string.format("|cFF4FC3F7[Listings]|r Cleared %d listing(s) for %s (%d)", count, name, a.itemID))
            end,
        },
    },
}

-- /cg quote <itemID> <qty>
cmd:register {
    name = "quote",
    help = "Optimal cost to buy qty from AH listings (DP knapsack)",
    args = {
        { "itemID:int", "Item ID" },
        { "qty:int",    "Quantity needed" },
    },
    handler = function(a)
        local name = ns.ItemInfo.formatName(a.itemID)
        local result = ns.Quote.quote(a.itemID, a.qty)

        if not result then
            printMsg(string.format("|cFF4FC3F7[Quote]|r %s (%d) × %d — no listings available",
                name, a.itemID, a.qty))
            return
        end

        printMsg(string.format("|cFF4FC3F7[Quote]|r %s (%d) × %d — optimal cost: %s",
            name, a.itemID, a.qty, ns.Money.formatColored(result.cost)))

        if result.surplus > 0 then
            printMsg(string.format("  Surplus: |cFFFFFF00%d|r extra item(s)", result.surplus))
        else
            printMsg("  Surplus: |cFF00FF00none|r (exact match)")
        end

        printMsg("  Basket:")
        for _, b in ipairs(result.basket) do
            local unitPrice = math.floor(b.buyout / b.count)
            printMsg(string.format("    Listing #%d: |cFFFFFFFF%d|r stack at %s (≈ %s/unit)",
                b.index, b.count,
                ns.Money.formatColored(b.buyout),
                ns.Money.formatColored(unitPrice)))
        end

        -- Greedy comparison
        local listings = ns.Listings.getListings(a.itemID)
        if #listings > 1 then
            local greedyResult = ns.Quote.greedy(listings, a.qty)
            if greedyResult and greedyResult.cost ~= result.cost then
                printMsg(string.format("  |cFF808080Greedy would cost: %s (DP saves %s)|r",
                    ns.Money.formatColored(greedyResult.cost),
                    ns.Money.formatColored(greedyResult.cost - result.cost)))
            end
        end
    end,
}

-- /cg cost <itemID>
cmd:register {
    name = "cost",
    help = "Show recursive cost breakdown",
    args = { { "itemID:int", "Item ID" } },
    handler = function(a)
        ns.Report.detail(a.itemID)
    end,
}

-- /cg detail <itemID>
cmd:register {
    name = "detail",
    help = "Detailed profit report with reagent tree",
    args = { { "itemID:int", "Item ID" } },
    handler = function(a)
        ns.Report.detail(a.itemID)
    end,
}

-- /cg analyze [N]
cmd:register {
    name = "analyze",
    help = "Show top N profitable crafts",
    args = { { "N:int?", "Number of crafts (default: all)" } },
    handler = function(a)
        ns.Report.topCrafts(a.N)
    end,
}

-- /cg log on/off/clear/show
cmd:register {
    name = "log",
    help = "Capture output to file (survives /reload)",
    subs = {
        on = {
            help = "Start capturing",
            handler = function()
                if _logBuffer then
                    printMsg("|cFF4FC3F7[Log]|r Already logging (" .. #_logBuffer .. " lines)")
                    return
                end
                _logBuffer = ManualListingsDB.log or {}
                ManualListingsDB.log = _logBuffer
                _origPrint = ns.WoW.print
                ns.WoW.print = logPrint
                ManualListingsDB._logActive = true
                printMsg("|cFF4FC3F7[Log]|r Logging started. Output saved after /reload.")
            end,
        },
        off = {
            help = "Stop capturing",
            handler = function()
                if not _logBuffer then
                    printMsg("|cFF4FC3F7[Log]|r Not currently logging")
                    return
                end
                ManualListingsDB._logActive = false
                printMsg("|cFF4FC3F7[Log]|r Logging stopped. " .. #_logBuffer .. " lines captured.")
                if _origPrint then
                    ns.WoW.print = _origPrint
                    _origPrint = nil
                end
                _logBuffer = nil
            end,
        },
        clear = {
            help = "Clear the log",
            handler = function()
                ManualListingsDB.log = {}
                if _logBuffer then _logBuffer = ManualListingsDB.log end
                printMsg("|cFF4FC3F7[Log]|r Log cleared.")
            end,
        },
        show = {
            help = "Show the log in chat",
            handler = function()
                local log = ManualListingsDB.log or {}
                if #log == 0 then
                    printMsg("|cFF4FC3F7[Log]|r Log is empty.")
                    return
                end
                printMsg(string.format("|cFF4FC3F7[Log]|r %d line(s):", #log))
                for i, line in ipairs(log) do
                    printMsg(string.format("  |cFF808080%03d|r %s", i, line))
                end
            end,
        },
    },
}

-- /cg reset
cmd:register {
    name = "reset",
    help = "Clear all prices and listings",
    handler = function()
        local priceCount = ns.Prices.count()
        local listingCount = ns.Listings.count()
        local prices = ns.Prices.getAll()
        for itemID in pairs(prices) do ns.Prices.remove(itemID) end
        ns.Listings.clear()
        printMsg(string.format("|cFF4FC3F7[Reset]|r Cleared %d price(s) and %d item(s) with listings.",
            priceCount, listingCount))
    end,
}

-- /cg help
local helpHandler = function()
    local lines = cmd:help()
    for line in lines:gmatch("[^\n]+") do
        printMsg("|cFF00FF00[CraftGold]|r " .. line)
    end
end

cmd:register {
    name = "help",
    help = "Show available commands",
    handler = helpHandler,
}

-- /cg helpall
cmd:register {
    name = "helpall",
    help = "Show all commands (including unavailable, with reasons)",
    handler = function()
        local lines = cmd:helpAll()
        for line in lines:gmatch("[^\n]+") do
            printMsg("|cFF00FF00[CraftGold]|r " .. line)
        end
    end,
}

-- /cg shoplist <itemID> [qty]
-- /cg shoplist expand <itemID> [qty]
cmd:register {
    name = "shoplist",
    help = "Expand a craft into raw materials with costs",
    args = {
        { "itemID:int", "Item to craft" },
        { "qty:int?",   "Quantity (default: 1)" },
    },
    handler = function(a)
        local result = ns.BOM.shoplist(a.itemID, a.qty or 1)
        local output = ns.BOM.formatShoplist(result)
        for line in output:gmatch("[^\n]+") do
            printMsg(line)
        end
    end,
    subs = {
        expand = {
            help = "Show raw materials without prices",
            args = {
                { "itemID:int", "Item to craft" },
                { "qty:int?",   "Quantity (default: 1)" },
            },
            handler = function(a)
                local expanded = ns.BOM.expand(a.itemID, a.qty or 1)
                local name = ns.ItemInfo.formatName(a.itemID)
                printMsg(string.format(
                    "|cFF4FC3F7[Shoplist]|r %s (%d) × %d — raw materials:",
                    name, a.itemID, a.qty or 1))

                -- Sort by itemID for consistent display
                local sorted = {}
                for matID, matQty in pairs(expanded.materials) do
                    sorted[#sorted + 1] = { id = matID, qty = matQty }
                end
                table.sort(sorted, function(a, b) return a.id < b.id end)

                for _, mat in ipairs(sorted) do
                    local matName = ns.ItemInfo.formatName(mat.id)
                    printMsg(string.format("  %s (%d) × %d",
                        matName, mat.id, mat.qty))
                end

                for _, err in ipairs(expanded.errors) do
                    printMsg(string.format("  |cFFFF0000⚠ %s|r", err.msg))
                end
            end,
        },
    },
}

-- /cg test
cmd:register {
    name = "test",
    help = "Run in-game tests",
    handler = function()
        RunInGameTests()
    end,
}

-------------------------------------------------
-- Slash command handler
-------------------------------------------------

SLASH_CRAFTGOLD1 = "/cg"
SLASH_CRAFTGOLD2 = "/craftgold"

SlashCmdList["CRAFTGOLD"] = function(input)
    -- Empty input = help
    if not input or input:match("^%s*$") then
        local lines = cmd:help()
        for line in lines:gmatch("[^\n]+") do
            printMsg("|cFF00FF00[CraftGold]|r " .. line)
        end
        return
    end

    local results, err = cmd:execute(input)
    if not results then
        printMsg("|cFFFF0000[CraftGold]|r " .. err)
    end
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

    -- ====== Save pre-existing state ======
    local savedPrices = {}
    local savedListings = {}
    local testItemIDs = {2840, 2589, 2835, 4357, 4359, 4363, 90001, 90002, 90003}
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

    -- ====== CmdLang parsing ======
    ns.WoW.print("|cFF4FC3F7--- CmdLang ---|r")

    local parsed, err = cmd:parse("listing add 2840 3 2s50c")
    assert2(parsed ~= nil, "CmdLang should parse 'listing add 2840 3 2s50c'")
    if parsed then
        assert2(parsed[1].args.itemID == 2840, "CmdLang itemID should be 2840")
        assert2(parsed[1].args.count == 3, "CmdLang count should be 3")
        assert2(parsed[1].args.buyout == 250, "CmdLang buyout should be 250 copper")
    end

    parsed, err = cmd:parse("quote 2840 5")
    assert2(parsed ~= nil, "CmdLang should parse 'quote 2840 5'")

    parsed, err = cmd:parse("unknown")
    assert2(parsed == nil, "CmdLang should fail on 'unknown'")
    assert2(err ~= nil and err:match("unknown command"), "Error should say 'unknown command'")

    parsed, err = cmd:parse("listing add abc 3 1g")
    assert2(parsed == nil, "CmdLang should fail on non-int itemID")
    assert2(err ~= nil and err:match("itemID"), "Error should mention 'itemID'")

    parsed, err = cmd:parse("listing add 2840 3 1g; listing list")
    assert2(parsed ~= nil, "CmdLang should parse batch")
    if parsed then
        assert2(#parsed == 2, "Batch should produce 2 commands")
    end

    -- ====== Listings CRUD ======
    ns.WoW.print("|cFF4FC3F7--- Listings: CRUD ---|r")

    local idx1 = Listings.add(90001, 20, 10000)
    assert2(idx1 == 1, "First listing index 1")
    local idx2 = Listings.add(90001, 5, 2500)
    assert2(idx2 == 2, "Second listing index 2")

    assert2(Listings.countListings(90001) == 2, "2 listings")
    local l = Listings.getListings(90001)
    assert2(l[1].count == 20, "Listing 1 count 20")
    assert2(l[2].buyout == 2500, "Listing 2 buyout 2500")

    Listings.remove(90001, 1)
    assert2(Listings.countListings(90001) == 1, "1 after remove")

    Listings.clear(90001)
    assert2(Listings.countListings(90001) == 0, "0 after clear")

    -- ====== Quote DP ======
    ns.WoW.print("|cFF4FC3F7--- Quote DP ---|r")

    local Quote = ns.Quote

    Listings.add(90001, 20, 10000)
    Listings.add(90001, 5, 2500)
    Listings.add(90001, 3, 1200)

    local q = Quote.quote(90001, 5)
    assert2(q and q.cost == 2500, "quote ×5 = 2500")
    assert2(q.surplus == 0, "no surplus")

    q = Quote.quote(90001, 8)
    assert2(q and q.cost == 3700, "quote ×8 = 3700 (5+3)")
    assert2(q.surplus == 0, "no surplus")

    q = Quote.quote(90001, 100)
    assert2(q == nil, "impossible quote = nil")

    -- DP vs Greedy
    Listings.clear(90002)
    Listings.add(90002, 100, 1000)
    Listings.add(90002, 3, 200)
    Listings.add(90002, 3, 200)

    local dpR = Quote.dpCover(Listings.getListings(90002), 6)
    local greedyR = Quote.greedy(Listings.getListings(90002), 6)
    assert2(dpR.cost == 400, "DP = 400")
    assert2(dpR.cost < greedyR.cost, "DP beats greedy")

    -- ====== Money.parse ======
    ns.WoW.print("|cFF00FF00--- Money ---|r")
    assert2(Money.parse("1g") == 10000, "1g = 10000")
    assert2(Money.parse("12s40c") == 1240, "12s40c = 1240")

    -- ====== Calculator v2 (fallback: Prices) ======
    ns.WoW.print("|cFF00FF00--- Calculator v2 (Prices fallback) ---|r")
    Prices.set(2840, 1240)
    Prices.set(2589, 310)
    local bolts = Calculator.calculate(4359)
    assert2(bolts and bolts.cost == 1240, "Copper Bolts = 1240")
    assert2(bolts.method == "craft", "method = craft")

    -- ====== Calculator v2 (DP Quote) ======
    ns.WoW.print("|cFF4FC3F7--- Calculator v2 (DP Quote) ---|r")

    -- Test: buy cheaper via DP quote
    Listings.add(4359, 5, 2000)       -- 5 Copper Bolts @ 20s
    local boltsBuy = Calculator.calculate(4359, 1)
    -- Buy: quote(4359, 1) → 5@2000 → cost 2000, surplus 4
    -- Craft: quote(2840, 1) → no listings → fallback 1240 → craft cost 1240
    -- Craft wins (1240 < 2000)
    assert2(boltsBuy and boltsBuy.cost == 1240, "Copper Bolts v2 = 1240 (craft cheaper)")
    assert2(boltsBuy.method == "craft", "method = craft (cheaper than buy@2000)")

    -- Test: buy cheaper than craft
    Listings.add(4359, 1, 500)        -- 1 Copper Bolts @ 5s
    local boltsBuy2 = Calculator.calculate(4359, 1)
    -- Buy: quote(4359, 1) → 1@500 → cost 500 (cheapest listing)
    -- Craft: quote(2840, 1) → no listings → fallback 1240 → craft cost 1240
    -- Buy wins (500 < 1240)
    assert2(boltsBuy2 and boltsBuy2.cost == 500, "Copper Bolts buy = 500")
    assert2(boltsBuy2.method == "buy", "method = buy (cheaper than craft@1240)")
    assert2(boltsBuy2.surplus == 0, "surplus = 0 (exact match)")
    assert2(boltsBuy2.craftCost == 1240, "craftCost = 1240 (what craft would have cost)")

    -- ====== BOM (Bill of Materials) ======\n    ns.WoW.print("|cFF4FC3F7--- BOM ---|r")\n\n    local BOM = ns.BOM\n\n    -- Test 1: non-craftable item → itself as raw material\n    local exp1 = BOM.expand(2840, 3)\n    assert2(exp1.materials[2840] == 3, "Non-craftable ×3 → materials[2840] = 3")\n    assert2(#exp1.errors == 0, "No errors for non-craftable")\n\n    -- Test 2: Copper Bolts (1 Copper Bar → 1 Copper Bolts)\n    -- 4359 = Handful of Copper Bolts, reagent: {2840, 1}\n    local exp2 = BOM.expand(4359, 2)\n    assert2(exp2.materials[2840] == 2, "Copper Bolts ×2 → 2 Copper Bar")\n    assert2(exp2.materials[4359] == nil, "Copper Bolts should not appear (it's craftable)")\n\n    -- Test 3: Rough Copper Bomb (multi-reagent)\n    -- 4360 = Rough Copper Bomb\n    -- reagents: {2589, 1}, {2840, 1}, {4357, 2}, {4359, 1}\n    -- 4357 = Rough Blasting Powder, reagent: {2835, 1}\n    -- 4359 = Handful of Copper Bolts, reagent: {2840, 1}\n    -- So: Linen Cloth ×1 + Copper Bar ×1 + Rough Stone ×2 + Copper Bar ×1\n    -- Aggregated: Copper Bar ×2, Linen Cloth ×1, Rough Stone ×2\n    local exp3 = BOM.expand(4360, 1)\n    assert2(exp3.materials[2589] == 1, "Rough Copper Bomb ×1 → 1 Linen Cloth")\n    assert2(exp3.materials[2840] == 2, "Rough Copper Bomb ×1 → 2 Copper Bar (1 direct + 1 via Bolts)")\n    assert2(exp3.materials[2835] == 2, "Rough Copper Bomb ×1 → 2 Rough Stone (via Blasting Powder)")\n    assert2(exp3.materials[4357] == nil, "Blasting Powder should not appear (craftable)")\n    assert2(exp3.materials[4359] == nil, "Copper Bolts should not appear (craftable)")\n\n    -- Test 4: quantity multiplication\n    -- Rough Copper Bomb ×3\n    local exp4 = BOM.expand(4360, 3)\n    assert2(exp4.materials[2840] == 6, "Rough Copper Bomb ×3 → 6 Copper Bar")\n    assert2(exp4.materials[2835] == 6, "Rough Copper Bomb ×3 → 6 Rough Stone")\n    assert2(exp4.materials[2589] == 3, "Rough Copper Bomb ×3 → 3 Linen Cloth")\n\n    -- Test 5: shoplist with quoting\n    -- Set up listings for raw materials\n    Listings.clear(2840)\n    Listings.clear(2835)\n    Listings.clear(2589)\n    Listings.add(2840, 20, 5000)   -- 20 Copper Bar @ 50s\n    Listings.add(2835, 10, 1000)   -- 10 Rough Stone @ 10s\n    Listings.add(2589, 5, 200)     -- 5 Linen Cloth @ 2s\n\n    local sl = BOM.shoplist(4360, 3)\n    assert2(sl.totalCost > 0, "shoplist has a total cost")\n    assert2(#sl.quotes == 3, "shoplist has 3 materials")\n    assert2(sl.errors ~= nil, "shoplist has errors field")\n\n    -- Verify quote amounts\n    -- Copper Bar ×6: need 6, listing is 20@5000 → cost 5000, surplus 14\n    -- Rough Stone ×6: need 6, listing is 10@1000 → cost 1000, surplus 4\n    -- Linen Cloth ×3: need 3, listing is 5@200 → cost 200, surplus 2\n    -- Total = 5000 + 1000 + 200 = 6200\n    assert2(sl.totalCost == 6200, "shoplist total cost = 6200")\n\n    -- Test 6: shoplist with missing listings\n    Listings.clear(2835)\n    local sl2 = BOM.shoplist(4360, 1)\n    local unquoted = 0\n    for _, q in ipairs(sl2.quotes) do\n        if not q.result then unquoted = unquoted + 1 end\n    end\n    assert2(unquoted == 1, "1 material without listings")\n\n    -- ====== Restore ======
    for _, id in ipairs(testItemIDs) do
        Prices.remove(id)
        Listings.clear(id)
        if savedPrices[id] then Prices.set(id, savedPrices[id]) end
        if savedListings[id] then
            for _, l in ipairs(savedListings[id]) do
                Listings.add(id, l.count, l.buyout)
            end
        end
    end

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
