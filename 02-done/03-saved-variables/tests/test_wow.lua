-- tests/test_wow.lua
-- Run: busted tests/test_wow.lua (or just: busted)

local helpers = require("tests/helpers")

describe("WoW", function()
    local WoW

    before_each(function()
        local ns = helpers.loadModules(helpers.DEFAULT_ORDER)
        WoW = ns.WoW
    end)

    -------------------------------------------------
    -- wipe (fallback)
    -------------------------------------------------

    describe("wipe", function()
        it("empties a table", function()
            local t = { a = 1, b = 2, c = 3 }
            WoW.wipe(t)
            assert.are.equal(nil, next(t))
        end)

        it("preserves table reference", function()
            local t = {}
            local ref = t
            WoW.wipe(t)
            t.x = 42
            assert.are.equal(42, ref.x)
        end)
    end)

    -------------------------------------------------
    -- init (injection)
    -------------------------------------------------

    describe("init", function()
        it("injects custom wipe", function()
            local calls = 0
            WoW.init({ wipe = function(t)
                calls = calls + 1
                for k in pairs(t) do t[k] = nil end
            end })

            local t = { a = 1 }
            WoW.wipe(t)
            assert.are.equal(1, calls)
            assert.are.equal(nil, next(t))
        end)

        it("restores fallbacks when called with empty table", function()
            -- First inject a custom wipe
            WoW.init({ wipe = function() end })

            -- Then reset to fallbacks
            WoW.init({})

            local t = { a = 1, b = 2 }
            WoW.wipe(t)
            assert.are.equal(nil, next(t))
        end)
    end)
end)
