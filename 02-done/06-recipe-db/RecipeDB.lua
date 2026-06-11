-- RecipeDB.lua
-- Shell: WoW integration (slash commands, events, init).
-- This is the only file that talks to WoW directly.

local _, ns = ...

local addonName = "RecipeDB"
local browserFrame = nil  -- created on first use

-------------------------------------------------
-- Slash commands
-------------------------------------------------

SLASH_RECIPEDB1 = "/cgdb"
SLASH_RECIPEDB2 = "/recipeDB"

SlashCmdList["RECIPEDB"] = function(input)
    local cmd = (input or ""):match("^%s*(.-)%s*$"):lower()

    if cmd == "" or cmd == "help" then
        ns.WoW.print("|cFF00FF00[RecipeDB]|r Commands:")
        ns.WoW.print("  /cgdb test   — Run in-game tests")
        ns.WoW.print("  /cgdb count  — Show recipe count")
        ns.WoW.print("  /cgdb show   — Show recipe browser")
        ns.WoW.print("  /cgdb hide   — Hide recipe browser")
        ns.WoW.print("  /cgdb help   — Show this help")
    elseif cmd == "count" then
        ns.WoW.print("|cFF00FF00[RecipeDB]|r " .. ns.Core.count() .. " recipes loaded.")
    elseif cmd == "show" then
        if not browserFrame then browserFrame = ns.UI.Create() end
        browserFrame:Show()
    elseif cmd == "hide" then
        if browserFrame then browserFrame:Hide() end
    elseif cmd == "test" then
        RunInGameTests()
    else
        ns.WoW.print("|cFF00FF00[RecipeDB]|r Unknown command: " .. cmd)
    end
end

-------------------------------------------------
-- In-game test runner
-------------------------------------------------

function RunInGameTests()
    local Core = ns.Core
    local DB = ns.DB
    local passed = 0
    local failed = 0

    local function assert(condition, msg)
        if condition then
            passed = passed + 1
        else
            failed = failed + 1
            ns.WoW.print("|cFFFF0000[FAIL]|r " .. msg)
        end
    end

    -- Test 1: Database loaded
    assert(DB.recipes ~= nil, "DB.recipes should exist")
    assert(Core.count() > 0, "DB should contain recipes")

    -- Test 2: getByOutput — find recipe producing Copper Modulator (4363)
    local modulator = Core.getByOutput(4363)
    assert(modulator ~= nil, "Should find recipe for Copper Modulator (4363)")
    assert(modulator.spellID == 3926, "Copper Modulator spellID should be 3926")
    assert(modulator.skillRequired == 65, "Copper Modulator skillRequired should be 65")
    assert(#modulator.reagents == 3, "Copper Modulator should have 3 reagents")

    -- Test 3: getByReagent — find recipes using Copper Bar (2840)
    local copperBarRecipes = Core.getByReagent(2840)
    assert(#copperBarRecipes > 0, "Should find recipes using Copper Bar (2840)")
    -- Copper Bar is used by: Copper Bolts, Copper Tube, Rough Copper Bomb, Crafted Light Shot,
    -- Copper Modulator, Large Copper Bomb, Arclight Spanner, Crafted Heavy Shot = 8 recipes
    assert(#copperBarRecipes == 8, "Should find 8 recipes using Copper Bar (2840), got " .. #copperBarRecipes)

    -- Test 4: getBySkill — recipes learnable at skill 50
    local learnable50 = Core.getBySkill(50)
    assert(#learnable50 > 0, "Should find recipes learnable at skill 50")
    -- All recipes with skillRequired <= 50: 3918, 3919, 3920, 3922, 3923, 3924, 3925, 7430 = 8
    assert(#learnable50 == 8, "Should find 8 recipes learnable at skill 50, got " .. #learnable50)

    -- Test 5: getBySpellID — direct lookup
    local bolts = Core.getBySpellID(3922)
    assert(bolts ~= nil, "Should find recipe with spellID 3922")
    assert(bolts.output == 4359, "Copper Bolts should output item 4359")
    assert(#bolts.reagents == 1, "Copper Bolts should have 1 reagent")
    assert(bolts.reagents[1][1] == 2840, "Copper Bolts reagent should be Copper Bar (2840)")
    assert(bolts.reagents[1][2] == 1, "Copper Bolts needs 1 Copper Bar")

    -- Test 6: getBySource — trainer recipes
    local trainerRecipes = Core.getBySource("trainer")
    assert(#trainerRecipes > 0, "Should find trainer recipes")

    -- Test 7: isCraftable
    assert(Core.isCraftable(4363) == true, "Copper Modulator (4363) should be craftable")
    assert(Core.isCraftable(99999) == false, "Item 99999 should not be craftable")

    -- Test 8: getIntermediates — items that are both craftable and used as reagent
    local intermediates = Core.getIntermediates()
    assert(#intermediates > 0, "Should find intermediate items")
    -- Copper Bolts (4359), Rough Blasting Powder (4357), Coarse Blasting Powder (4364),
    -- Copper Modulator (4363), Copper Tube (4361), Silver Contact (4404),
    -- Bronze Tube (4371), Whirring Bronze Gizmo (4375), Heavy Blasting Powder (4377),
    -- Bronze Framework (4382), Flying Tiger Goggles (4368) = 11
    assert(#intermediates == 11, "Should find 11 intermediate items, got " .. #intermediates)

    -- Test 9: Reagent counts are positive
    for spellID, recipe in pairs(DB.recipes) do
        for i, reagent in ipairs(recipe.reagents) do
            assert(reagent[2] > 0, "Recipe " .. spellID .. " reagent " .. i .. " count should be > 0")
        end
    end

    -- Summary
    ns.WoW.print(string.format("|cFF00FF00[RecipeDB]|r Tests: |cFF00FF00%d passed|r, |cFFFF0000%d failed|r", passed, failed))
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

    ns.WoW.print("|cFF00FF00[RecipeDB]|r Loaded! " .. ns.Core.count() .. " Engineering recipes.")
    ns.WoW.print("|cFF00FF00[RecipeDB]|r Type /cgdb help for commands.")

    self:UnregisterEvent("ADDON_LOADED")
end)
