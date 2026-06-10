-- HelloAzeroth.lua
-- Capsule 02: Slash Commands
-- Learn to register custom commands, parse arguments, and display colored messages.

-------------------------------------------------
-- 1. Constants
-------------------------------------------------

-- Token used to match SLASH_HELLOAZEROTH* globals with SlashCmdList["HELLOAZEROTH"]
local TOKEN = "HELLOAZEROTH"

-- Color helper: wraps text in UI escape sequence
-- |cFFRRGGBBtext|r  (FF = alpha, ignored but required)
local function RGB(text, r, g, b)
    return string.format("|cFF%02X%02X%02X%s|r", r, g, b, text)
end

local PREFIX = RGB("[HelloAzeroth]", 0x33, 0xFF, 0x99) .. " "

-------------------------------------------------
-- 2. Utility: colored print
-------------------------------------------------

local function Print(msg)
    print(PREFIX .. tostring(msg))
end

-------------------------------------------------
-- 3. Handler
-------------------------------------------------

local function HandleSlash(msg, editBox)
    -- Defensive: msg is "" when no args, never nil via chat,
    -- but someone could call our handler directly in Lua
    msg = strtrim(msg or "")

    -- Extract: first word = subcommand, rest = arguments
    -- Pattern: ^(start of string)
    --          (%S*) capture non-space characters (subcommand)
    --          %s* skip spaces
    --          (.-)$ capture the rest, non-greedy, until end of string
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = string.lower(command)

    if command == "" then
        -- No argument: greet the user
        Print("Salut, Azeroth ! Tape " .. RGB("/ha help", 0xFF, 0xFF, 0x00) .. " pour l'aide.")

    elseif command == "help" then
        Print("Commandes disponibles :")
        Print("  " .. RGB("/ha", 0xFF, 0xFF, 0x00) .. "         - message de bienvenue")
        Print("  " .. RGB("/ha help", 0xFF, 0xFF, 0x00) .. "    - cette aide")
        Print("  " .. RGB("/ha <msg>", 0xFF, 0xFF, 0x00) .. "   - repete ton message")

    else
        -- Anything else: echo the original message as-is
        Print("Tu as dit : " .. RGB(msg, 0xFF, 0xD1, 0x00))
    end
end

-------------------------------------------------
-- 4. Registration
-------------------------------------------------

-- Declare aliases: numbers MUST be consecutive (1, 2, 3...)
SLASH_HELLOAZEROTH1 = "/helloazeroth"
SLASH_HELLOAZEROTH2 = "/ha"

-- Register the handler under the same token
SlashCmdList[TOKEN] = HandleSlash
