-- src/Listings.lua
-- Listing storage: maps itemID → { {count=N, buyout=C}, ... }
-- Each listing represents an indivisible AH stack you can buy.
-- Backed by SavedVariables (ManualListingsDB.listings).
-- Pure data access — no WoW API calls.

local _, ns = ...

local Listings = {}
ns.Listings = Listings

-------------------------------------------------
-- Internal data store (set during ADDON_LOADED)
-------------------------------------------------
Listings._data = nil

-------------------------------------------------
-- Initialize from SavedVariables
-------------------------------------------------
function Listings.init(db)
    if type(db) ~= "table" then db = {} end
    if type(db.listings) ~= "table" then db.listings = {} end
    Listings._data = db.listings
end

-------------------------------------------------
-- Add a listing for an item
-------------------------------------------------
-- count = number of items in the stack
-- buyout = total buyout price for the stack (in copper)
function Listings.add(itemID, count, buyout)
    if not Listings._data then return end
    if type(itemID) ~= "number" or type(count) ~= "number" or type(buyout) ~= "number" then
        return
    end
    if count <= 0 or buyout < 0 then return end

    if not Listings._data[itemID] then
        Listings._data[itemID] = {}
    end

    local listing = { count = count, buyout = buyout }
    local item_listings = Listings._data[itemID]
    item_listings[#item_listings + 1] = listing

    return #item_listings  -- return the index of the new listing
end

-------------------------------------------------
-- Remove a specific listing by index
-------------------------------------------------
function Listings.remove(itemID, index)
    if not Listings._data then return false end
    local item_listings = Listings._data[itemID]
    if not item_listings then return false end
    if type(index) ~= "number" or index < 1 or index > #item_listings then
        return false
    end

    table.remove(item_listings, index)

    -- Clean up empty entries
    if #item_listings == 0 then
        Listings._data[itemID] = nil
    end

    return true
end

-------------------------------------------------
-- Remove all listings for an item
-------------------------------------------------
function Listings.clear(itemID)
    if not Listings._data then return end
    if itemID then
        Listings._data[itemID] = nil
    else
        -- Clear all
        for k in pairs(Listings._data) do
            Listings._data[k] = nil
        end
    end
end

-------------------------------------------------
-- Get all listings for one item
-------------------------------------------------
function Listings.getListings(itemID)
    if not Listings._data then return {} end
    return Listings._data[itemID] or {}
end

-------------------------------------------------
-- Get all listings (full table)
-------------------------------------------------
function Listings.getAll()
    return Listings._data or {}
end

-------------------------------------------------
-- Count items that have listings
-------------------------------------------------
function Listings.count()
    local n = 0
    for _ in pairs(Listings._data or {}) do
        n = n + 1
    end
    return n
end

-------------------------------------------------
-- Count total listings for one item
-------------------------------------------------
function Listings.countListings(itemID)
    local item_listings = Listings.getListings(itemID)
    return #item_listings
end
