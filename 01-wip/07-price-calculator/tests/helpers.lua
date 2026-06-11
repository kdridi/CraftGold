-- tests/helpers.lua
-- Shared test utilities: load src/ modules in .toc order with simulated vararg.

local helpers = {}

function helpers.loadModules(files)
    local ns = {}
    for _, file in ipairs(files) do
        assert(loadfile(file))("PriceCalc", ns)
    end
    return ns
end

helpers.DEFAULT_ORDER = {
    "src/WoW.lua",
    "src/DB.lua",
    "src/Core.lua",
    "src/Money.lua",
    "src/Prices.lua",
    "src/Calculator.lua",
}

return helpers
