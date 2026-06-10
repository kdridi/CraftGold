-- HelloAzeroth.lua — My first WoW add-on

-- --------------------------------------------------------------------------
-- Utility: pretty-print a table (recursive, with indentation)
-- Lua has no built-in table serialization — this will be useful throughout
-- the entire project whenever we need to inspect a table.
-- --------------------------------------------------------------------------
local function DumpTable(t, indent)
    indent = indent or ""
    if type(t) ~= "table" then
        print(indent .. tostring(t))
        return
    end
    -- Check if table is empty
    local isEmpty = true
    for _ in pairs(t) do
        isEmpty = false
        break
    end
    if isEmpty then
        print(indent .. "{}")
        return
    end
    for k, v in pairs(t) do
        local key = type(k) == "string" and k or "[" .. tostring(k) .. "]"
        if type(v) == "table" then
            print(indent .. key .. " = {")
            DumpTable(v, indent .. "  ")
            print(indent .. "}")
        else
            print(indent .. key .. " = " .. tostring(v))
        end
    end
end

-- --------------------------------------------------------------------------
-- The vararg trick: every .lua file receives the addon name and a private
-- namespace. WoW passes these automatically when loading the file.
-- addonName = "HelloAzeroth" (string)
-- ns        = {} (empty table, shared only between files of this add-on)
-- --------------------------------------------------------------------------
local addonName, ns = ...

-- STEP 1: Top-level print — runs during loading screen
print("[" .. addonName .. "] addonName = " .. tostring(addonName))
print("[" .. addonName .. "] ns =")
DumpTable(ns)

-- STEP 2: The proper way — wait for PLAYER_LOGIN event
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    print("|cFF00FF00[" .. addonName .. "]|r Event received: " .. tostring(event))
    print("|cFF00FF00[" .. addonName .. "]|r Hello Azeroth! The add-on has loaded successfully.")
end)
