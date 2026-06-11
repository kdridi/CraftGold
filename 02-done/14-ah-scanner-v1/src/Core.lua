-- src/Core.lua
-- Pure business logic for querying the recipe database.
-- Zero WoW API calls, zero side effects — testable in plain Lua.

local _, ns = ...

local Core = {}
ns.Core = Core

local DB = ns.DB

-------------------------------------------------
-- Query: get a recipe by its output itemID
-------------------------------------------------
-- Returns the recipe table, or nil if not found.
-- If multiple recipes produce the same item, returns the first one found.
function Core.getByOutput(itemID)
    for _, recipe in pairs(DB.recipes) do
        if recipe.output == itemID then
            return recipe
        end
    end
    return nil
end

-------------------------------------------------
-- Query: get all recipes that use a given reagent itemID
-------------------------------------------------
-- Returns a list of recipe tables.
function Core.getByReagent(itemID)
    local results = {}
    for _, recipe in pairs(DB.recipes) do
        for _, reagent in ipairs(recipe.reagents) do
            if reagent[1] == itemID then
                results[#results + 1] = recipe
                break
            end
        end
    end
    return results
end

-------------------------------------------------
-- Query: get all recipes learnable at a given skill level
-------------------------------------------------
-- Returns a list of recipe tables where skillRequired <= skillLevel.
function Core.getBySkill(skillLevel)
    local results = {}
    for _, recipe in pairs(DB.recipes) do
        if recipe.skillRequired <= skillLevel then
            results[#results + 1] = recipe
        end
    end
    return results
end

-------------------------------------------------
-- Query: get a recipe by its spellID
-------------------------------------------------
-- Returns the recipe table, or nil if not found.
function Core.getBySpellID(spellID)
    return DB.recipes[spellID]
end

-------------------------------------------------
-- Query: get all recipes from a given source
-------------------------------------------------
-- Returns a list of recipe tables.
function Core.getBySource(source)
    local results = {}
    for _, recipe in pairs(DB.recipes) do
        if recipe.source == source then
            results[#results + 1] = recipe
        end
    end
    return results
end

-------------------------------------------------
-- Utility: count total recipes in the database
-------------------------------------------------
function Core.count()
    local n = 0
    for _ in pairs(DB.recipes) do
        n = n + 1
    end
    return n
end

-------------------------------------------------
-- Utility: check if an item is craftable (exists as output)
-------------------------------------------------
function Core.isCraftable(itemID)
    return Core.getByOutput(itemID) ~= nil
end

-------------------------------------------------
-- Utility: get all intermediate items (used as reagent AND produced by a recipe)
-------------------------------------------------
-- These are items we can either buy OR craft — the heart of the recursive cost calculator.
function Core.getIntermediates()
    local craftable = {}
    for _, recipe in pairs(DB.recipes) do
        craftable[recipe.output] = true
    end

    local intermediates = {}
    for itemID in pairs(craftable) do
        local usedAsReagent = #Core.getByReagent(itemID) > 0
        if usedAsReagent then
            intermediates[#intermediates + 1] = itemID
        end
    end
    return intermediates
end
