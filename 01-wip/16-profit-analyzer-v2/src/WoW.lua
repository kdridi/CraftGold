-- src/WoW.lua
-- WoW API seam: single entry point for all WoW functions.
-- In WoW: initialized with _G (real C implementations, fast).
-- In tests: initialized with {} (pure Lua fallbacks or mocks).

local _, ns = ...

local WoW = {}
ns.WoW = WoW

-------------------------------------------------
-- Fallbacks (pure Lua, no WoW)
-------------------------------------------------

local FALLBACKS = {
    print = function() end,
    wipe = function(t)
        for k in pairs(t) do t[k] = nil end
    end,
    GetItemInfo = function() return nil end,
    RequestLoadItemDataByID = function() end,
    CanSendAuctionQuery = function() return false end,
    QueryAuctionItems = function() end,
    GetNumAuctionItems = function() return 0, 0 end,
    GetAuctionItemInfo = function() return nil end,
    CreateFrame = function() return nil end,
}

-------------------------------------------------
-- Apply fallbacks immediately (safe defaults)
-------------------------------------------------

WoW.print = FALLBACKS.print
WoW.wipe = FALLBACKS.wipe
WoW.GetItemInfo = FALLBACKS.GetItemInfo
WoW.CanSendAuctionQuery = FALLBACKS.CanSendAuctionQuery
WoW.QueryAuctionItems = FALLBACKS.QueryAuctionItems
WoW.GetNumAuctionItems = FALLBACKS.GetNumAuctionItems
WoW.GetAuctionItemInfo = FALLBACKS.GetAuctionItemInfo
WoW.CreateFrame = FALLBACKS.CreateFrame

-------------------------------------------------
-- Initialization
-------------------------------------------------

function WoW.init(env)
    WoW.print = env.print or FALLBACKS.print
    WoW.wipe = env.wipe or FALLBACKS.wipe
    WoW.GetItemInfo = env.GetItemInfo or FALLBACKS.GetItemInfo
    WoW.CanSendAuctionQuery = env.CanSendAuctionQuery or FALLBACKS.CanSendAuctionQuery
    WoW.QueryAuctionItems = env.QueryAuctionItems or FALLBACKS.QueryAuctionItems
    WoW.GetNumAuctionItems = env.GetNumAuctionItems or FALLBACKS.GetNumAuctionItems
    WoW.GetAuctionItemInfo = env.GetAuctionItemInfo or FALLBACKS.GetAuctionItemInfo
    WoW.CreateFrame = env.CreateFrame or FALLBACKS.CreateFrame
end
