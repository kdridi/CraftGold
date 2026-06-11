-- src/Prices.lua
-- Price storage: maps itemID → copper price.
-- Backed by SavedVariables (PriceCalcDB.prices).
-- Pure data access — no WoW API calls.

local _, ns = ...

local Prices = {}
ns.Prices = Prices

-------------------------------------------------
-- Internal data store (set during ADDON_LOADED)
-------------------------------------------------
Prices._data = nil

-------------------------------------------------
-- Initialize from SavedVariables
-------------------------------------------------
function Prices.init(db)
    if type(db) ~= "table" then db = {} end
    if type(db.prices) ~= "table" then db.prices = {} end
    Prices._data = db.prices
end

-------------------------------------------------
-- Get / Set / Remove
-------------------------------------------------
function Prices.get(itemID)
    if not Prices._data then return nil end
    return Prices._data[itemID]
end

function Prices.set(itemID, copper)
    if Prices._data and type(copper) == "number" then
        Prices._data[itemID] = copper
    end
end

function Prices.remove(itemID)
    if Prices._data then
        Prices._data[itemID] = nil
    end
end

-------------------------------------------------
-- Utilities
-------------------------------------------------
function Prices.count()
    local n = 0
    for _ in pairs(Prices._data or {}) do
        n = n + 1
    end
    return n
end

function Prices.getAll()
    return Prices._data or {}
end
