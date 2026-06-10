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

-- These are immutable — WoW.init always rebuilds from these.
local FALLBACKS = {
    print = function() end,
    wipe = function(t)
        for k in pairs(t) do t[k] = nil end
    end,
}

-------------------------------------------------
-- Apply fallbacks immediately (safe defaults)
-------------------------------------------------

WoW.print = FALLBACKS.print
WoW.wipe = FALLBACKS.wipe

-------------------------------------------------
-- Initialization
-------------------------------------------------

-- Called by the shell at startup with _G.
-- Injects real WoW functions when available, keeps fallbacks otherwise.
-- Always rebuilds from FALLBACKS — safe to call multiple times.
function WoW.init(env)
    WoW.print = env.print or FALLBACKS.print
    WoW.wipe = env.wipe or FALLBACKS.wipe
end
