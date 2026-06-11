-- src/Money.lua
-- Parse and format money strings (gold/silver/copper).
-- Pure Lua, zero WoW API — testable with busted.

local _, ns = ...

local Money = {}
ns.Money = Money

-------------------------------------------------
-- Parse a money string into copper
-------------------------------------------------
-- Accepts: "12s40c", "1g50s", "3g", "500c", "1g2s3c", "12G40C"
-- Returns: number (copper) or nil, error message
function Money.parse(str)
    if type(str) ~= "string" then
        return nil, "expected money string (e.g. 12s40c, 1g50s)"
    end

    local copper = 0
    local found = false

    for raw_amount, denom in str:gmatch("(%d+)([gGcCsS])") do
        local amount = tonumber(raw_amount)
        local d = denom:lower()
        if d == "g" then
            copper = copper + amount * 10000
        elseif d == "s" then
            copper = copper + amount * 100
        elseif d == "c" then
            copper = copper + amount
        end
        found = true
    end

    if not found then
        return nil, "invalid money format (use e.g. 12s40c, 1g50s)"
    end
    return copper
end

-------------------------------------------------
-- Format copper to plain string
-------------------------------------------------
-- 4340 → "43s40c", 1240 → "12s40c", 10000 → "1g"
function Money.format(copper)
    if copper == nil then return "—" end
    if type(copper) ~= "number" or copper < 0 then return "—" end

    local gold   = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop    = copper % 100

    local parts = {}
    if gold > 0   then parts[#parts + 1] = gold .. "g" end
    if silver > 0 then parts[#parts + 1] = silver .. "s" end
    if cop > 0    then parts[#parts + 1] = cop .. "c" end

    if #parts == 0 then return "0c" end
    return table.concat(parts, " ")
end

-------------------------------------------------
-- Format copper with WoW color codes
-------------------------------------------------
-- Gold = yellow, Silver = gray, Copper = brown
function Money.formatColored(copper)
    if copper == nil then return "|cff808080—|r" end
    if type(copper) ~= "number" or copper < 0 then return "|cff808080—|r" end

    local gold   = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop    = copper % 100

    local parts = {}
    if gold > 0   then parts[#parts + 1] = "|cFFFFD700" .. gold .. "g|r" end
    if silver > 0 then parts[#parts + 1] = "|cFFC0C0C0" .. silver .. "s|r" end
    if cop > 0    then parts[#parts + 1] = "|cFFCD853F" .. cop .. "c|r" end

    if #parts == 0 then return "|cFFCD853F0c|r" end
    return table.concat(parts, " ")
end
