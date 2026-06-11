-- tests/test_core.lua
-- Tests for Core query functions (pure Lua, no WoW API).

local helpers = require("tests/helpers")
local ns = helpers.loadModules(helpers.DEFAULT_ORDER)
local Core = ns.Core
local DB = ns.DB

describe("Core.getByOutput", function()
    it("finds recipe by output itemID", function()
        local r = Core.getByOutput(4363) -- Copper Modulator
        assert.is_not_nil(r)
        assert.equals(3926, r.spellID)
        assert.equals(65, r.skillRequired)
    end)

    it("returns nil for unknown itemID", function()
        assert.is_nil(Core.getByOutput(99999))
    end)
end)

describe("Core.getByReagent", function()
    it("finds all recipes using Copper Bar (2840)", function()
        local results = Core.getByReagent(2840)
        assert.equals(8, #results)
    end)

    it("finds recipes using Copper Bolts (4359)", function()
        local results = Core.getByReagent(4359)
        -- Used in: Rough Copper Bomb, Rough Boomstick, Copper Modulator, Target Dummy, Crude Scope = 5
        assert.equals(5, #results)
    end)

    it("returns empty list for unused itemID", function()
        local results = Core.getByReagent(99999)
        assert.equals(0, #results)
    end)
end)

describe("Core.getBySkill", function()
    it("finds recipes learnable at skill 1", function()
        local results = Core.getBySkill(1)
        -- 3 recipes with skillRequired = 1: Rough Blasting Powder, Rough Dynamite, Crafted Light Shot
        assert.equals(3, #results)
    end)

    it("finds recipes learnable at skill 50", function()
        local results = Core.getBySkill(50)
        assert.equals(8, #results)
    end)

    it("finds all recipes at skill 300", function()
        local results = Core.getBySkill(300)
        assert.equals(Core.count(), #results)
    end)
end)

describe("Core.getBySpellID", function()
    it("finds recipe by spellID", function()
        local r = Core.getBySpellID(3922)
        assert.is_not_nil(r)
        assert.equals(4359, r.output) -- Handful of Copper Bolts
        assert.equals(1, #r.reagents)
        assert.equals(2840, r.reagents[1][1])
        assert.equals(1, r.reagents[1][2])
    end)

    it("returns nil for unknown spellID", function()
        assert.is_nil(Core.getBySpellID(99999))
    end)
end)

describe("Core.getBySource", function()
    it("finds trainer recipes", function()
        local results = Core.getBySource("trainer")
        assert.is_true(#results > 0)
    end)

    it("finds auto-learned recipes", function()
        local results = Core.getBySource("auto")
        assert.equals(3, #results) -- Rough Blasting Powder, Rough Dynamite, Crafted Light Shot
    end)
end)

describe("Core.count", function()
    it("returns total number of recipes", function()
        local c = Core.count()
        assert.is_true(c >= 25) -- we have at least 25 recipes
    end)
end)

describe("Core.isCraftable", function()
    it("returns true for craftable items", function()
        assert.is_true(Core.isCraftable(4363))  -- Copper Modulator
        assert.is_true(Core.isCraftable(4357))  -- Rough Blasting Powder
    end)

    it("returns false for non-craftable items", function()
        assert.is_false(Core.isCraftable(2840)) -- Copper Bar (raw material)
        assert.is_false(Core.isCraftable(99999))
    end)
end)

describe("Core.getIntermediates", function()
    it("finds items that are both craftable and used as reagent", function()
        local intermediates = Core.getIntermediates()
        assert.is_true(#intermediates > 0)

        -- Check some known intermediates
        local found = {}
        for _, id in ipairs(intermediates) do
            found[id] = true
        end
        assert.is_true(found[4359])  -- Copper Bolts
        assert.is_true(found[4357])  -- Rough Blasting Powder
        assert.is_true(found[4363])  -- Copper Modulator
        assert.is_true(found[4361])  -- Copper Tube
    end)

    it("has exactly 11 intermediate items", function()
        local intermediates = Core.getIntermediates()
        assert.equals(11, #intermediates)
    end)
end)

describe("DB consistency", function()
    it("all recipes have required fields", function()
        for spellID, recipe in pairs(DB.recipes) do
            assert.equals(spellID, recipe.spellID)
            assert.is_number(recipe.output)
            assert.is_table(recipe.reagents)
            assert.is_number(recipe.skillRequired)
            assert.is_string(recipe.source)
        end
    end)

    it("all reagent counts are positive", function()
        for spellID, recipe in pairs(DB.recipes) do
            for i, reagent in ipairs(recipe.reagents) do
                assert.is_number(reagent[1])  -- itemID
                assert.is_number(reagent[2])  -- count
                assert.is_true(reagent[2] > 0, "Recipe " .. spellID .. " reagent " .. i .. " count should be > 0")
            end
        end
    end)
end)
