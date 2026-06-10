-- src/Logger.lua
-- Chat logging via WoW.print.
-- All output goes through ns.WoW.print — mockable from tests.

local _, ns = ...

local Logger = {}
ns.Logger = Logger

-------------------------------------------------
-- State
-------------------------------------------------

Logger._prefix = ""

-------------------------------------------------
-- Initialization
-------------------------------------------------

-- Configure the prefix (e.g. "[SavedVarsDemo] ")
function Logger.init(prefix)
    Logger._prefix = prefix or ""
end

-------------------------------------------------
-- Log levels
-------------------------------------------------

function Logger.info(msg)
    ns.WoW.print(Logger._prefix .. tostring(msg))
end
