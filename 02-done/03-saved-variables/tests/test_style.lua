-- tests/test_style.lua
-- Run: busted tests/test_style.lua (or just: busted)

local helpers = require("tests/helpers")

describe("Style", function()
    local Style

    before_each(function()
        local ns = helpers.loadModules(helpers.DEFAULT_ORDER)
        Style = ns.Style
    end)

    -------------------------------------------------
    -- colorize
    -------------------------------------------------

    describe("colorize", function()
        it("wraps text with color escape sequence", function()
            local result = Style.colorize("hello", 0xFF, 0x00, 0x00)
            assert.are.equal("|cFFFF0000hello|r", result)
        end)

        it("converts number to string", function()
            local result = Style.colorize(42, 0x33, 0xFF, 0x99)
            assert.truthy(result:find("42"))
        end)
    end)

    -------------------------------------------------
    -- prefix
    -------------------------------------------------

    describe("prefix", function()
        it("contains addon name in brackets", function()
            local result = Style.prefix("SavedVarsDemo")
            assert.truthy(result:find("%[SavedVarsDemo%]"))
        end)
    end)

    -------------------------------------------------
    -- highlight
    -------------------------------------------------

    describe("highlight", function()
        it("contains text with color escape", function()
            local result = Style.highlight("test")
            assert.truthy(result:find("test"))
            assert.truthy(result:find("|cFF"))
        end)
    end)

    -------------------------------------------------
    -- command
    -------------------------------------------------

    describe("command", function()
        it("contains text with color escape", function()
            local result = Style.command("/svars help")
            assert.truthy(result:find("/svars help"))
            assert.truthy(result:find("|cFF"))
        end)
    end)
end)
