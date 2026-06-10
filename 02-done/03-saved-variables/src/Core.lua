-- src/Core.lua
-- Pure business logic — zero WoW API calls, zero side effects.
-- This file must load in plain Lua without crashing.

local _, ns = ...

local Core = {}
ns.Core = Core

-------------------------------------------------
-- Constants
-------------------------------------------------

Core.DEFAULTS = {
    counter = 0,
    name = "unknown",
}

-------------------------------------------------
-- Database
-------------------------------------------------

-- Fill missing keys from defaults without overwriting existing values.
-- Uses == nil (not "or") to preserve saved false values.
function Core.applyDefaults(db, defaults)
    db = db or {}
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v
        end
    end
    return db
end

-- Reset a table in-place: clear all keys, then reapply defaults.
-- Preserves the table reference so local proxies stay valid.
-- Uses WoW.wipe (optimized C) when available, pure Lua fallback otherwise.
function Core.reset(db, defaults)
    ns.WoW.wipe(db)
    for k, v in pairs(defaults) do
        db[k] = v
    end
    return db
end

-------------------------------------------------
-- Counter operations
-------------------------------------------------

function Core.increment(db, step)
    db.counter = (db.counter or 0) + (step or 1)
    return db.counter
end

-------------------------------------------------
-- Command parsing
-------------------------------------------------

-- Parse a slash command string into a structured action.
-- Returns: { kind = "help"|"count"|"increment"|"reset"|"info"|"unknown", value = string }
function Core.parseCommand(input)
    input = input or ""
    local cmd = input:match("^%s*(.-)%s*$") -- trim whitespace
    cmd = cmd:lower()

    if cmd == "" or cmd == "help" then
        return { kind = "help" }
    elseif cmd == "count" then
        return { kind = "count" }
    elseif cmd == "increment" then
        return { kind = "increment" }
    elseif cmd == "reset" then
        return { kind = "reset" }
    elseif cmd == "info" then
        return { kind = "info" }
    elseif cmd == "test" then
        return { kind = "test" }
    else
        return { kind = "unknown", value = cmd }
    end
end
