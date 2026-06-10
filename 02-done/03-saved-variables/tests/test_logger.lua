-- tests/test_logger.lua
-- Run: busted tests/test_logger.lua (or just: busted)

local helpers = require("tests/helpers")

describe("Logger", function()
    local Logger, WoW

    before_each(function()
        local ns = helpers.loadModules(helpers.DEFAULT_ORDER)
        WoW = ns.WoW
        Logger = ns.Logger
    end)

    -------------------------------------------------
    -- info sends via WoW.print
    -------------------------------------------------

    describe("info", function()
        it("sends prefixed message via WoW.print", function()
            local messages = {}
            WoW.print = function(msg)
                table.insert(messages, msg)
            end

            Logger.init("[Test] ")
            Logger.info("hello")
            Logger.info("counter: 42")

            assert.are.equal(2, #messages)
            assert.are.equal("[Test] hello", messages[1])
            assert.are.equal("[Test] counter: 42", messages[2])
        end)

        it("works with empty prefix", function()
            local messages = {}
            WoW.print = function(msg)
                table.insert(messages, msg)
            end

            Logger.init("")
            Logger.info("no prefix")

            assert.are.equal("no prefix", messages[1])
        end)

        it("defaults to empty prefix when nil", function()
            local messages = {}
            WoW.print = function(msg)
                table.insert(messages, msg)
            end

            Logger.init(nil)
            Logger.info("default prefix")

            assert.are.equal("default prefix", messages[1])
        end)
    end)
end)
