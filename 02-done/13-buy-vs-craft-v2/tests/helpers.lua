-- tests/helpers.lua
-- Shared test utilities: load src/ modules in .toc order with simulated vararg.

local helpers = {}

function helpers.loadModules(files)
    local ns = {}
    for _, file in ipairs(files) do
        assert(loadfile(file))("QuoteDP", ns)
    end
    return ns
end

helpers.DEFAULT_ORDER = {
    "src/WoW.lua",
    "src/DB.lua",
    "src/Core.lua",
    "src/Money.lua",
    "src/Prices.lua",
    "src/Listings.lua",
    "src/Quote.lua",
    "src/Calculator.lua",
    "src/Report.lua",
    "src/BOM.lua",
}

-- Expose ns globally for tests that need it
helpers.ns = nil

function helpers.setup()
    local ns = helpers.loadModules(helpers.DEFAULT_ORDER)
    -- Initialize Listings with a fresh mock DB
    ns.Listings.init({ listings = {} })
    -- Initialize Prices with a fresh mock DB
    ns.Prices.init({ prices = {} })
    -- Expose globally
    _G.ns = ns
    helpers.ns = ns
    return ns
end

return helpers
