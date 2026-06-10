-- tests/helpers.lua
-- Shared test utilities: load src/ modules in .toc order with simulated vararg.

local helpers = {}

-- Load a list of src/ files into a fresh namespace, simulating WoW's vararg.
-- Returns the populated ns table.
function helpers.loadModules(files)
    local ns = {}
    for _, file in ipairs(files) do
        assert(loadfile(file))("SavedVarsDemo", ns)
    end
    return ns
end

-- Default module loading order (mirrors the .toc)
helpers.DEFAULT_ORDER = {
    "src/WoW.lua",
    "src/Core.lua",
    "src/Style.lua",
    "src/Logger.lua",
    "src/Test.lua",
}

return helpers
