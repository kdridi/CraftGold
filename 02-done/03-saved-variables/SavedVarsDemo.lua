-- SavedVarsDemo.lua
-- Imperative shell — the only file that touches WoW directly.
-- Wires everything together: events, slash commands, SavedVars.

local addonName, ns = ...
local Core = ns.Core
local Style = ns.Style
local Logger = ns.Logger
local WoW = ns.WoW
local Test = ns.Test

-------------------------------------------------
-- 1. Bootstrap
-------------------------------------------------

-- Inject WoW's real functions (print, wipe, etc.)
WoW.init(_G)

-- Configure Logger prefix
Logger.init(Style.prefix(addonName) .. " ")

-------------------------------------------------
-- 2. Constants
-------------------------------------------------

local TOKEN = string.upper(addonName) -- "SAVEDVARSDEMO"

-------------------------------------------------
-- 3. State
-------------------------------------------------

-- Local proxy — assigned in ADDON_LOADED, not before!
local db

-------------------------------------------------
-- 4. Event frame
-------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName ~= addonName then return end

        _G.SavedVarsDemoDB = Core.applyDefaults(_G.SavedVarsDemoDB, Core.DEFAULTS)
        db = _G.SavedVarsDemoDB

        self:UnregisterEvent("ADDON_LOADED")

        Logger.info("Loaded! Counter: " .. Style.highlight(db.counter))

    elseif event == "PLAYER_LOGOUT" then
        -- Last chance to modify SavedVars before they are written to disk
        db.lastLogout = time()
    end
end)

-------------------------------------------------
-- 5. Slash command handler
-------------------------------------------------

local function HandleSlash(msg, editBox)
    local command = Core.parseCommand(msg)

    if command.kind == "help" then
        Logger.info("Commands:")
        Logger.info("  " .. Style.command("/svars count") .. "     — Show counter")
        Logger.info("  " .. Style.command("/svars increment") .. " — Increment counter")
        Logger.info("  " .. Style.command("/svars reset") .. "    — Reset to defaults")
        Logger.info("  " .. Style.command("/svars info") .. "     — Show all saved data")
        Logger.info("  " .. Style.command("/svars test") .. "     — Run in-game tests")

    elseif command.kind == "count" then
        Logger.info("Counter: " .. Style.highlight(db.counter))

    elseif command.kind == "increment" then
        local count = Core.increment(db)
        Logger.info("Counter incremented to: " .. Style.highlight(count))

    elseif command.kind == "reset" then
        Core.reset(db, Core.DEFAULTS)
        Logger.info("Reset to defaults!")

    elseif command.kind == "info" then
        Logger.info("Counter: " .. Style.highlight(db.counter))
        Logger.info("Name: " .. Style.highlight(db.name))
        if db.lastLogout then
            Logger.info("Last logout: " .. Style.highlight(date("%Y-%m-%d %H:%M:%S", db.lastLogout)))
        else
            Logger.info("Last logout: " .. Style.highlight("never"))
        end

    elseif command.kind == "test" then
        local results = Test.run()
        for _, line in ipairs(results) do
            Logger.info(line)
        end

    else
        Logger.info("Unknown command: " .. Style.highlight(command.value) .. ". Type " .. Style.command("/svars help") .. " for help.")
    end
end

-------------------------------------------------
-- 6. Registration
-------------------------------------------------

_G["SLASH_" .. TOKEN .. "1"] = "/svars"
_G["SLASH_" .. TOKEN .. "2"] = "/savedvars"
SlashCmdList[TOKEN] = HandleSlash
