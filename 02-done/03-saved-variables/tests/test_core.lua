-- tests/test_core.lua
-- Run: busted tests/test_core.lua (or just: busted)

local helpers = require("tests/helpers")

describe("Core", function()
    local Core

    before_each(function()
        local ns = helpers.loadModules(helpers.DEFAULT_ORDER)
        Core = ns.Core
    end)

    -------------------------------------------------
    -- applyDefaults
    -------------------------------------------------

    describe("applyDefaults", function()
        it("creates table from nil", function()
            local db = Core.applyDefaults(nil, Core.DEFAULTS)
            assert.are.equal(0, db.counter)
            assert.are.equal("unknown", db.name)
        end)

        it("preserves existing value", function()
            local db = Core.applyDefaults({ counter = 7 }, Core.DEFAULTS)
            assert.are.equal(7, db.counter)
            assert.are.equal("unknown", db.name)
        end)

        it("does not overwrite when all keys set", function()
            local db = Core.applyDefaults({ counter = 3, name = "test" }, Core.DEFAULTS)
            assert.are.equal(3, db.counter)
            assert.are.equal("test", db.name)
        end)
    end)

    -------------------------------------------------
    -- reset
    -------------------------------------------------

    describe("reset", function()
        it("clears old values and reapplies defaults", function()
            local db = { counter = 42, name = "old", extra = "gone" }
            Core.reset(db, Core.DEFAULTS)
            assert.are.equal(nil, db.extra)
            assert.are.equal(0, db.counter)
        end)

        it("preserves table reference", function()
            local db = { counter = 5 }
            Core.reset(db, Core.DEFAULTS)
            assert.are.equal("table", type(db))
        end)
    end)

    -------------------------------------------------
    -- increment
    -------------------------------------------------

    describe("increment", function()
        it("increments by 1 (default)", function()
            local db = { counter = 0 }
            assert.are.equal(1, Core.increment(db))
        end)

        it("increments by custom step", function()
            local db = { counter = 1 }
            assert.are.equal(6, Core.increment(db, 5))
        end)

        it("handles nil counter", function()
            local db = {}
            assert.are.equal(1, Core.increment(db))
        end)
    end)

    -------------------------------------------------
    -- parseCommand
    -------------------------------------------------

    describe("parseCommand", function()
        it("empty string returns help", function()
            assert.are.equal("help", Core.parseCommand("").kind)
        end)

        it("nil returns help", function()
            assert.are.equal("help", Core.parseCommand(nil).kind)
        end)

        it("whitespace returns help", function()
            assert.are.equal("help", Core.parseCommand("   ").kind)
        end)

        it("help returns help", function()
            assert.are.equal("help", Core.parseCommand("help").kind)
        end)

        it("HELP (uppercase) returns help", function()
            assert.are.equal("help", Core.parseCommand("HELP").kind)
        end)

        it("parses count", function()
            assert.are.equal("count", Core.parseCommand("count").kind)
        end)

        it("parses increment", function()
            assert.are.equal("increment", Core.parseCommand("increment").kind)
        end)

        it("parses reset", function()
            assert.are.equal("reset", Core.parseCommand("reset").kind)
        end)

        it("parses info", function()
            assert.are.equal("info", Core.parseCommand("info").kind)
        end)

        it("parses test", function()
            assert.are.equal("test", Core.parseCommand("test").kind)
        end)

        it("trims and lowercases", function()
            assert.are.equal("increment", Core.parseCommand("  Increment  ").kind)
        end)

        it("returns unknown with value for unrecognized input", function()
            local cmd = Core.parseCommand("banana")
            assert.are.equal("unknown", cmd.kind)
            assert.are.equal("banana", cmd.value)
        end)
    end)
end)
