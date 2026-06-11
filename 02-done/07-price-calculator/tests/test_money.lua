-- tests/test_money.lua
-- Tests for Money.parse and Money.format (pure Lua).

local helpers = require("tests/helpers")
local ns = helpers.loadModules(helpers.DEFAULT_ORDER)
local Money = ns.Money

describe("Money.parse", function()
    it("parses gold only", function()
        assert.equals(10000, Money.parse("1g"))
        assert.equals(50000, Money.parse("5g"))
    end)

    it("parses silver only", function()
        assert.equals(5000, Money.parse("50s"))
        assert.equals(100, Money.parse("1s"))
    end)

    it("parses copper only", function()
        assert.equals(100, Money.parse("100c"))
        assert.equals(1, Money.parse("1c"))
    end)

    it("parses mixed denominations", function()
        assert.equals(1240, Money.parse("12s40c"))
        assert.equals(15030, Money.parse("1g50s30c"))
        assert.equals(30200, Money.parse("3g2s"))
        assert.equals(15000, Money.parse("1g50s"))
    end)

    it("is case-insensitive", function()
        assert.equals(15000, Money.parse("1G50S"))
        assert.equals(1240, Money.parse("12S40C"))
    end)

    it("returns nil for invalid input", function()
        assert.is_nil(Money.parse("invalid"))
        assert.is_nil(Money.parse(""))
        assert.is_nil(Money.parse("abc"))
    end)

    it("returns nil for non-string input", function()
        assert.is_nil(Money.parse(nil))
        assert.is_nil(Money.parse(123))
    end)

    it("returns error message as second value", function()
        local _, err = Money.parse("bad")
        assert.is_string(err)
    end)
end)

describe("Money.format", function()
    it("formats gold only", function()
        assert.equals("1g", Money.format(10000))
        assert.equals("5g", Money.format(50000))
    end)

    it("formats silver only", function()
        assert.equals("1s", Money.format(100))
        assert.equals("50s", Money.format(5000))
    end)

    it("formats copper only", function()
        assert.equals("1c", Money.format(1))
        assert.equals("50c", Money.format(50))
    end)

    it("formats mixed denominations", function()
        assert.equals("12s 40c", Money.format(1240))
        assert.equals("1g 50s 30c", Money.format(15030))
    end)

    it("formats zero", function()
        assert.equals("0c", Money.format(0))
    end)

    it("handles nil and negative", function()
        assert.equals("—", Money.format(nil))
        assert.equals("—", Money.format(-1))
    end)
end)

describe("Money round-trip", function()
    it("parse → format preserves values", function()
        local values = { "1g", "50s", "100c", "12s40c", "1g50s30c", "3g2s" }
        for _, v in ipairs(values) do
            local copper = Money.parse(v)
            assert.is_number(copper)
            local formatted = Money.format(copper)
            local reparsed = Money.parse(formatted)
            assert.equals(copper, reparsed, "round-trip failed for " .. v)
        end
    end)

    it("format output is parseable", function()
        local copper = 1240
        local formatted = Money.format(copper)
        local reparsed = Money.parse(formatted)
        assert.equals(copper, reparsed)
    end)
end)
