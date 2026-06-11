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
    GetFramesRegisteredForEvent = function() return {} end,
    C_Timer_After = function() end,
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
WoW.GetFramesRegisteredForEvent = FALLBACKS.GetFramesRegisteredForEvent
WoW.C_Timer_After = FALLBACKS.C_Timer_After

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
    WoW.GetFramesRegisteredForEvent = env.GetFramesRegisteredForEvent or FALLBACKS.GetFramesRegisteredForEvent
    -- C_Timer.After is a global: C_Timer.After(delay, callback)
    if env.C_Timer and env.C_Timer.After then
        WoW.C_Timer_After = env.C_Timer.After
    elseif _G.C_Timer and _G.C_Timer.After then
        WoW.C_Timer_After = _G.C_Timer.After
    else
        WoW.C_Timer_After = FALLBACKS.C_Timer_After
    end
end
