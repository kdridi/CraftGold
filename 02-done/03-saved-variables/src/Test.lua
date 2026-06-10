-- src/Test.lua
-- In-game test runner: verifies Core logic inside WoW.
-- Same assertions as busted tests, but running live in the client.

local _, ns = ...

local Test = {}
ns.Test = Test

-------------------------------------------------
-- Test harness (lightweight, no framework)
-------------------------------------------------

local pass, fail = 0, 0

local function check(label, condition)
    if condition then
        pass = pass + 1
        return "  " .. ns.Style.colorize("OK", 0x33, 0xFF, 0x99) .. " " .. label
    else
        fail = fail + 1
        return "  " .. ns.Style.colorize("FAIL", 0xFF, 0x33, 0x33) .. " " .. label
    end
end

-------------------------------------------------
-- Test suites
-------------------------------------------------

local function testApplyDefaults(Core)
    local results = {}

    do
        local db = Core.applyDefaults(nil, Core.DEFAULTS)
        table.insert(results, check("creates table from nil", db.counter == 0))
    end

    do
        local db = Core.applyDefaults({ counter = 7 }, Core.DEFAULTS)
        table.insert(results, check("preserves existing value", db.counter == 7))
        table.insert(results, check("fills missing key", db.name == "unknown"))
    end

    do
        local db = Core.applyDefaults({ counter = 3, name = "test" }, Core.DEFAULTS)
        table.insert(results, check("no overwrite when all keys set", db.counter == 3 and db.name == "test"))
    end

    return results
end

local function testIncrement(Core)
    local results = {}

    do
        local db = { counter = 0 }
        table.insert(results, check("increments by 1", Core.increment(db) == 1))
    end

    do
        local db = { counter = 1 }
        table.insert(results, check("increments by custom step", Core.increment(db, 5) == 6))
    end

    do
        local db = {}
        table.insert(results, check("handles nil counter", Core.increment(db) == 1))
    end

    return results
end

local function testReset(Core)
    local results = {}

    do
        local db = { counter = 42, name = "old", extra = "gone" }
        Core.reset(db, Core.DEFAULTS)
        table.insert(results, check("clears old values", db.extra == nil))
        table.insert(results, check("reapplies defaults", db.counter == 0))
    end

    return results
end

local function testParseCommand(Core)
    local results = {}

    table.insert(results, check("empty = help", Core.parseCommand("").kind == "help"))
    table.insert(results, check("nil = help", Core.parseCommand(nil).kind == "help"))
    table.insert(results, check("HELP = help", Core.parseCommand("HELP").kind == "help"))
    table.insert(results, check("count", Core.parseCommand("count").kind == "count"))
    table.insert(results, check("increment", Core.parseCommand("increment").kind == "increment"))
    table.insert(results, check("reset", Core.parseCommand("reset").kind == "reset"))
    table.insert(results, check("info", Core.parseCommand("info").kind == "info"))

    do
        local cmd = Core.parseCommand("  Increment  ")
        table.insert(results, check("trims and lowercases", cmd.kind == "increment"))
    end

    do
        local cmd = Core.parseCommand("banana")
        table.insert(results, check("unknown kind", cmd.kind == "unknown"))
        table.insert(results, check("unknown value", cmd.value == "banana"))
    end

    return results
end

-------------------------------------------------
-- Run all tests
-------------------------------------------------

function Test.run()
    local Core = ns.Core

    pass = 0
    fail = 0

    local allResults = {}
    local suites = {
        { name = "Core.applyDefaults", fn = testApplyDefaults },
        { name = "Core.increment",     fn = testIncrement },
        { name = "Core.reset",         fn = testReset },
        { name = "Core.parseCommand",  fn = testParseCommand },
    }

    for _, suite in ipairs(suites) do
        table.insert(allResults, ns.Style.highlight(suite.name .. ":"))
        local results = suite.fn(Core)
        for _, r in ipairs(results) do
            table.insert(allResults, r)
        end
    end

    -- Summary
    local summary
    if fail == 0 then
        summary = ns.Style.colorize(
            string.format("%d passed, %d failed", pass, fail),
            0x33, 0xFF, 0x99
        )
    else
        summary = ns.Style.colorize(
            string.format("%d passed, %d failed", pass, fail),
            0xFF, 0x33, 0x33
        )
    end
    table.insert(allResults, "")
    table.insert(allResults, summary)

    return allResults
end
