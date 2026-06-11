-- src/ItemInfo.lua
-- Centralized module for all item data access.
-- Every other module (Report, Shell, future UI) goes through here.
-- No direct GetItemInfo() calls outside this file.
--
-- This module wraps two API families:
--   1. Classic: GetItemInfo(id) → 17 returns (async, may be nil)
--   2. C_Item.*: GetItemNameByID, IsItemDataCachedByID, etc.
--
-- DESIGN LESSON: Centralizing item access means:
--   - One place to change if the API behaves differently than expected
--   - One place to add caching, logging, or fallback logic
--   - Tests can mock item data by replacing just this module

local _, ns = ...

local ItemInfo = {}
ns.ItemInfo = ItemInfo

-------------------------------------------------
-- Synchronous getters — return nil if not cached
-------------------------------------------------
-- These wrap GetItemInfo() and C_Item.* functions.
-- The caller is responsible for handling nil (or using formatName for fallback).

-- Get the display name for an item. Returns nil if not cached.
function ItemInfo.getName(id)
    return C_Item.GetItemNameByID(id)
end

-- Get all info for an item as a table (mirrors GetItemInfo returns).
-- Returns nil if not cached.
function ItemInfo.getInfo(id)
    local name, link, quality, itemLevel, reqLevel, class, subclass,
          maxStack, equipLoc, texture, sellPrice, classID, subclassID,
          bindType, expansionID, setID, isCraftingReagent = GetItemInfo(id)

    if not name then return nil end

    return {
        name = name,
        link = link,
        quality = quality,
        itemLevel = itemLevel,
        reqLevel = reqLevel,
        class = class,
        subclass = subclass,
        maxStack = maxStack,
        equipLoc = equipLoc,
        texture = texture,
        sellPrice = sellPrice,
        classID = classID,
        subclassID = subclassID,
        bindType = bindType,
        expansionID = expansionID,
        setID = setID,
        isCraftingReagent = isCraftingReagent,
    }
end

-- Get just the icon fileID. Returns nil if not cached.
function ItemInfo.getIcon(id)
    return C_Item.GetItemIconByID(id)
end

-- Get just the quality (0-7). Returns nil if not cached.
function ItemInfo.getQuality(id)
    return C_Item.GetItemQualityByID(id)
end

-- Get the vendor sell price in copper. Returns nil if not cached.
function ItemInfo.getSellPrice(id)
    local info = ItemInfo.getInfo(id)
    return info and info.sellPrice or nil
end

-- Get the max stack size. Returns nil if not cached.
function ItemInfo.getMaxStack(id)
    local info = ItemInfo.getInfo(id)
    return info and info.maxStack or nil
end

-------------------------------------------------
-- Instant getters — always available for valid items
-------------------------------------------------
-- These use GetItemInfoInstant() which reads from local DB2 only.
-- They never trigger server requests and never return nil for valid items.
-- But they don't include the localized name.

function ItemInfo.getInstantInfo(id)
    local itemID, itemType, itemSubType, equipLoc, icon, classID, subclassID =
        GetItemInfoInstant(id)
    if not itemID then return nil end
    return {
        itemID = itemID,
        itemType = itemType,
        itemSubType = itemSubType,
        equipLoc = equipLoc,
        icon = icon,
        classID = classID,
        subclassID = subclassID,
    }
end

-------------------------------------------------
-- Cache status
-------------------------------------------------

-- Check if full item data is cached (name, quality, sellPrice, etc.)
function ItemInfo.isCached(id)
    return C_Item.IsItemDataCachedByID(id)
end

-- Request the server to load item data. Triggers ITEM_DATA_LOAD_RESULT
-- when complete. Usually called internally by ContinueOnItemLoad.
function ItemInfo.requestLoad(id)
    C_Item.RequestLoadItemDataByID(id)
end

-------------------------------------------------
-- Async resolution — callback when item data is loaded
-------------------------------------------------
-- Uses Blizzard's ContinueOnItemLoad (the recommended API).
-- If the item is already cached, the callback fires immediately.
-- If not, it fires when the data arrives.

function ItemInfo.onLoad(id, callback)
    local item = Item:CreateFromItemID(id)
    item:ContinueOnItemLoad(function()
        callback(id)
    end)
end

-------------------------------------------------
-- Display helpers
-------------------------------------------------

-- Get a display-ready name with fallback for uncached items.
-- Returns the item name if cached, otherwise "item:XXXXX" in gray.
function ItemInfo.formatName(id)
    local name = ItemInfo.getName(id)
    if name then
        return name
    end
    return "|cff808080item:" .. id .. "|r"
end

-- Get a colored name based on item quality.
-- Falls back to white if quality is unknown, gray if not cached at all.
function ItemInfo.formatColoredName(id)
    local name = ItemInfo.getName(id)
    if not name then
        return "|cff808080item:" .. id .. "|r"
    end

    local quality = ItemInfo.getQuality(id)
    if quality then
        local color = ITEM_QUALITY_COLORS[quality]
        if color and color.color then
            local c = color.color
            return string.format("|cff%02x%02x%02x%s|r",
                math.floor(c.r * 255),
                math.floor(c.g * 255),
                math.floor(c.b * 255),
                name)
        end
    end
    return name
end

-------------------------------------------------
-- Batch operations — scan DB items
-------------------------------------------------

-- Scan all output items in the recipe DB and return their cache status.
-- Returns: { total, cached, uncached, items = {{id, name, cached}, ...} }
function ItemInfo.scanDB()
    local DB = ns.DB
    local seen = {}
    local items = {}

    -- Collect unique item IDs from outputs and reagents
    for _, recipe in pairs(DB.recipes) do
        if not seen[recipe.output] then
            seen[recipe.output] = true
            items[#items + 1] = recipe.output
        end
        for _, reagent in ipairs(recipe.reagents) do
            if not seen[reagent[1]] then
                seen[reagent[1]] = true
                items[#items + 1] = reagent[1]
            end
        end
    end

    table.sort(items)

    local cached = 0
    local uncached = 0
    local result = {}

    for _, id in ipairs(items) do
        local isCached = ItemInfo.isCached(id)
        if isCached then
            cached = cached + 1
        else
            uncached = uncached + 1
        end
        result[#result + 1] = {
            id = id,
            name = ItemInfo.getName(id),
            cached = isCached,
        }
    end

    return {
        total = #items,
        cached = cached,
        uncached = uncached,
        items = result,
    }
end

return ItemInfo
