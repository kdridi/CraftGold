-- src/Style.lua
-- Visual styling: colors, formatting.
-- Pure functions — no side effects, no WoW API.
-- This file must load in plain Lua without crashing.

local _, ns = ...

local Style = {}
ns.Style = Style

-------------------------------------------------
-- 1. Color constants
-------------------------------------------------

-- Internal hex values — code never touches these directly
local COLORS = {
    prefix    = { 0x33, 0xFF, 0x99 }, -- green — addon tag
    highlight = { 0xFF, 0xD1, 0x00 }, -- gold — values in context
    command   = { 0xFF, 0xFF, 0x00 }, -- yellow — slash commands
}

-------------------------------------------------
-- 2. Low-level helper
-------------------------------------------------

-- Wraps text in UI color escape sequence: |cFFRRGGBBtext|r
function Style.colorize(text, r, g, b)
    return string.format("|cFF%02X%02X%02X%s|r", r, g, b, tostring(text))
end

-------------------------------------------------
-- 3. Semantic styling functions
-------------------------------------------------

-- Addon tag: [SavedVarsDemo]
function Style.prefix(addonName)
    local c = COLORS.prefix
    return Style.colorize("[" .. addonName .. "]", c[1], c[2], c[3])
end

-- Highlight a value in context (counter, date, etc.)
function Style.highlight(text)
    local c = COLORS.highlight
    return Style.colorize(text, c[1], c[2], c[3])
end

-- Style a slash command or keyword
function Style.command(text)
    local c = COLORS.command
    return Style.colorize(text, c[1], c[2], c[3])
end
