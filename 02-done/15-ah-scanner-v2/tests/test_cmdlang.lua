-- tests/test_cmdlang.lua
-- Busted tests for CmdLang — declarative mini-command language

local CmdLang = require("src.CmdLang")

-------------------------------------------------------------------
-- Helper: create a fresh instance with sample commands
-------------------------------------------------------------------

local function makeSampleCmd()
    local cmd = CmdLang.new()
    local calls = {}

    cmd:register {
        name = "listing",
        help = "Manage AH listings",
        subs = {
            add = {
                help = "Add a listing",
                args = {
                    { "itemID:int",   "Item ID" },
                    { "count:int",    "Stack size" },
                    { "buyout:money", "Price" },
                },
                handler = function(args)
                    calls[#calls + 1] = { cmd = "listing add", args = args }
                end,
            },
            list = {
                help = "Show listings",
                args = {
                    { "itemID:int?", "Filter by item" },
                },
                handler = function(args)
                    calls[#calls + 1] = { cmd = "listing list", args = args }
                end,
            },
            remove = {
                help = "Remove a listing",
                args = {
                    { "itemID:int", "Item ID" },
                    { "index:int",  "Listing index" },
                },
                handler = function(args)
                    calls[#calls + 1] = { cmd = "listing remove", args = args }
                end,
            },
            clear = {
                help = "Clear all listings for an item",
                args = {
                    { "itemID:int", "Item ID" },
                },
                handler = function(args)
                    calls[#calls + 1] = { cmd = "listing clear", args = args }
                end,
            },
        },
    }

    cmd:register {
        name = "ping",
        help = "Test command",
        args = {
            { "msg:rest?", "Message to echo" },
        },
        handler = function(args)
            calls[#calls + 1] = { cmd = "ping", args = args }
        end,
    }

    cmd:register {
        name = "log",
        help = "Log control",
        subs = {
            on  = { help = "Enable logging", handler = function() calls[#calls+1] = {cmd="log on"} end },
            off = { help = "Disable logging", handler = function() calls[#calls+1] = {cmd="log off"} end },
            clear = { help = "Clear log", handler = function() calls[#calls+1] = {cmd="log clear"} end },
            show = { help = "Show log", handler = function() calls[#calls+1] = {cmd="log show"} end },
        },
    }

    cmd:register {
        name = "analyze",
        help = "Analyze profitable crafts",
        args = {
            { "N:int?", "Top N crafts" },
        },
        handler = function(args)
            calls[#calls + 1] = { cmd = "analyze", args = args }
        end,
    }

    return cmd, calls
end

-------------------------------------------------------------------
-- Tokenizer
-------------------------------------------------------------------

describe("CmdLang tokenizer", function()
    it("splits on whitespace", function()
        local tokens = CmdLang._tokenize("listing add 2840 3 2s50c")
        assert.are.equal(5, #tokens)
        assert.are.equal("listing", tokens[1].text)
        assert.are.equal("2s50c", tokens[5].text)
    end)

    it("handles quoted strings", function()
        local tokens = CmdLang._tokenize('say "hello world" bye')
        assert.are.equal(3, #tokens)
        assert.are.equal("hello world", tokens[2].text)
    end)

    it("handles single quotes", function()
        local tokens = CmdLang._tokenize("say 'hello world' bye")
        assert.are.equal(3, #tokens)
        assert.are.equal("hello world", tokens[2].text)
    end)

    it("produces sep tokens for semicolons", function()
        local tokens = CmdLang._tokenize("a 1; b 2")
        assert.are.equal(5, #tokens)
        assert.are.equal("a", tokens[1].text)
        assert.are.equal("1", tokens[2].text)
        assert.is_true(tokens[3].sep)
        assert.are.equal("b", tokens[4].text)
    end)

    it("protects semicolons inside quotes", function()
        local tokens = CmdLang._tokenize('say "a;b" c')
        assert.are.equal(3, #tokens)
        assert.are.equal("a;b", tokens[2].text)
    end)

    it("returns error for unterminated quote", function()
        local tokens, err = CmdLang._tokenize('say "hello')
        assert.is_nil(tokens)
        assert.matches("unterminated", err)
    end)

    it("handles empty input", function()
        local tokens = CmdLang._tokenize("")
        assert.are.equal(0, #tokens)
    end)

    it("handles extra whitespace", function()
        local tokens = CmdLang._tokenize("  a   b   c  ")
        assert.are.equal(3, #tokens)
    end)
end)

-------------------------------------------------------------------
-- Batch splitter
-------------------------------------------------------------------

describe("CmdLang batch splitter", function()
    it("splits on semicolons", function()
        local tokens = CmdLang._tokenize("a 1; b 2; c 3")
        local batches = CmdLang._splitBatches(tokens)
        assert.are.equal(3, #batches)
        assert.are.equal("a", batches[1][1].text)
        assert.are.equal("b", batches[2][1].text)
        assert.are.equal("c", batches[3][1].text)
    end)

    it("does not split inside quotes", function()
        local tokens = CmdLang._tokenize('say "a;b"')
        local batches = CmdLang._splitBatches(tokens)
        assert.are.equal(1, #batches)
        assert.are.equal(2, #batches[1])
    end)
end)

-------------------------------------------------------------------
-- Type system
-------------------------------------------------------------------

describe("CmdLang types", function()
    local cmd

    before_each(function()
        cmd = CmdLang.new()
        -- Register a test command for type testing
        cmd:register {
            name = "listing",
            subs = {
                add = {
                    args = { { "itemID:int", "" }, { "count:int", "" }, { "buyout:money", "" } },
                    handler = function() end,
                },
            },
        }
    end)

    it("int: accepts integers", function()
        local parsed, err = cmd:parse("listing add 42 3 1g")
        assert.is_nil(err)
        assert.are.equal(42, parsed[1].args.itemID)
    end)

    it("int: rejects non-integers", function()
        local parsed, err = cmd:parse("listing add abc 3 1g")
        assert.is_nil(parsed)
        assert.matches("itemID", err)
        assert.matches("integer expected", err)
    end)

    it("money: accepts gold/silver/copper format", function()
        cmd:register {
            name = "test",
            args = { "price:money" },
            handler = function() end,
        }
        local parsed = cmd:parse("test 2g50s30c")
        assert.are.equal(25030, parsed[1].args.price)
    end)

    it("money: accepts pure copper", function()
        cmd:register {
            name = "test",
            args = { "price:money" },
            handler = function() end,
        }
        local parsed = cmd:parse("test 250")
        assert.are.equal(250, parsed[1].args.price)
    end)

    it("money: rejects invalid format", function()
        cmd:register {
            name = "test",
            args = { "price:money" },
            handler = function() end,
        }
        local parsed, err = cmd:parse("test abc")
        assert.is_nil(parsed)
        assert.matches("money", err)
    end)

    it("bool: accepts on/off variants", function()
        cmd:register {
            name = "test",
            args = { "flag:bool" },
            handler = function() end,
        }
        assert.are.equal(true, cmd:parse("test on")[1].args.flag)
        assert.are.equal(true, cmd:parse("test yes")[1].args.flag)
        assert.are.equal(true, cmd:parse("test 1")[1].args.flag)
        assert.are.equal(false, cmd:parse("test off")[1].args.flag)
        assert.are.equal(false, cmd:parse("test no")[1].args.flag)
        assert.are.equal(false, cmd:parse("test 0")[1].args.flag)
    end)

    it("allows custom types", function()
        cmd:registerType("itemlink", function(s)
            local id = s:match("item:(%d+)")
            if id then return tonumber(id) end
            return nil, "item link expected"
        end)
        cmd:register {
            name = "inspect",
            args = { "item:itemlink" },
            handler = function() end,
        }
        local parsed = cmd:parse("inspect item:2840")
        assert.are.equal(2840, parsed[1].args.item)
    end)
end)

-------------------------------------------------------------------
-- Parsing — subcommands
-------------------------------------------------------------------

describe("CmdLang parsing", function()
    local cmd, calls

    before_each(function()
        cmd, calls = makeSampleCmd()
    end)

    it("parses a simple command with typed args", function()
        local parsed, err = cmd:parse("listing add 2840 3 2s50c")
        assert.is_nil(err)
        assert.are.equal(1, #parsed)
        assert.are.equal(2840, parsed[1].args.itemID)
        assert.are.equal(3, parsed[1].args.count)
        assert.are.equal(250, parsed[1].args.buyout)
    end)

    it("parses optional arg when provided", function()
        local parsed = cmd:parse("listing list 2840")
        assert.are.equal(2840, parsed[1].args.itemID)
    end)

    it("parses optional arg when missing", function()
        local parsed = cmd:parse("listing list")
        assert.is_nil(parsed[1].args.itemID)
    end)

    it("parses command with no args", function()
        local parsed = cmd:parse("log on")
        assert.are.equal("log on", parsed[1].node.path)
    end)

    it("parses rest type (greedy string)", function()
        local parsed = cmd:parse("ping hello world foo")
        assert.are.equal("hello world foo", parsed[1].args.msg)
    end)

    it("parses rest type when empty", function()
        local parsed = cmd:parse("ping")
        assert.is_nil(parsed[1].args.msg)
    end)

    it("parses batch with semicolons", function()
        local parsed = cmd:parse("log on; log off; log show")
        assert.are.equal(3, #parsed)
        assert.are.equal("log on", parsed[1].node.path)
        assert.are.equal("log off", parsed[2].node.path)
        assert.are.equal("log show", parsed[3].node.path)
    end)

    it("protects semicolons inside quotes in batch", function()
        local parsed = cmd:parse('ping "a;b;c"')
        assert.are.equal("a;b;c", parsed[1].args.msg)
    end)
end)

-------------------------------------------------------------------
-- Error messages
-------------------------------------------------------------------

describe("CmdLang error messages", function()
    local cmd

    before_each(function()
        cmd = makeSampleCmd()
    end)

    it("unknown command → lists available commands", function()
        local _, err = cmd:parse("unknown")
        assert.matches("unknown command 'unknown'", err)
        assert.matches("listing", err)
        assert.matches("ping", err)
    end)

    it("missing subcommand → lists expected subcommands", function()
        local _, err = cmd:parse("listing")
        assert.matches("expected subcommand", err)
        assert.matches("add", err)
        assert.matches("list", err)
    end)

    it("unknown subcommand → shows what was expected", function()
        local _, err = cmd:parse("listing explode")
        assert.matches("unknown subcommand 'explode'", err)
        assert.matches("add", err)
    end)

    it("missing required arg → names the arg and its type", function()
        local _, err = cmd:parse("listing add 2840")
        assert.matches("missing argument 'count'", err)
        assert.matches("int", err)
    end)

    it("wrong type → describes what was expected", function()
        local _, err = cmd:parse("listing add abc 3 1g")
        assert.matches("itemID", err)
        assert.matches("integer expected", err)
    end)

    it("unexpected trailing arg → shows the offending token", function()
        local _, err = cmd:parse("log on extra")
        assert.matches("unexpected argument 'extra'", err)
    end)

    it("empty input → clear error", function()
        local _, err = cmd:parse("")
        assert.matches("empty", err)
    end)

    it("enum: invalid value → lists valid options", function()
        local cmd2 = CmdLang.new()
        cmd2:register {
            name = "log",
            args = { { "state:enum(on|off|clear|show)", "Log state" } },
            handler = function() end,
        }
        local _, err = cmd2:parse("log maybe")
        assert.matches("not valid", err)
        assert.matches("on", err)
        assert.matches("off", err)
    end)
end)

-------------------------------------------------------------------
-- Execution (dispatch)
-------------------------------------------------------------------

describe("CmdLang execute", function()
    local cmd, calls

    before_each(function()
        cmd, calls = makeSampleCmd()
    end)

    it("executes a single command", function()
        cmd:execute("listing add 2840 3 2s50c")
        assert.are.equal(1, #calls)
        assert.are.equal(2840, calls[1].args.itemID)
        assert.are.equal(250, calls[1].args.buyout)
    end)

    it("executes a batch", function()
        cmd:execute("log on; log off; log show")
        assert.are.equal(3, #calls)
    end)

    it("executes quoted args in batch", function()
        cmd:execute('ping "hello world"; log on')
        assert.are.equal(2, #calls)
        assert.are.equal("hello world", calls[1].args.msg)
    end)

    it("returns nil + error on parse failure", function()
        local results, err = cmd:execute("listing add abc 3 1g")
        assert.is_nil(results)
        assert.matches("itemID", err)
    end)

    it("returns handler results", function()
        local cmd2 = CmdLang.new()
        cmd2:register {
            name = "double",
            args = { "n:int" },
            handler = function(args) return args.n * 2 end,
        }
        local results = cmd2:execute("double 21")
        assert.are.equal(42, results[1])
    end)

    it("passes context to handlers", function()
        local cmd2 = CmdLang.new()
        local received = nil
        cmd2:register {
            name = "test",
            handler = function(args, ctx)
                received = ctx.value
            end,
        }
        cmd2:execute("test", { value = "hello" })
        assert.are.equal("hello", received)
    end)
end)

-------------------------------------------------------------------
-- Help generation
-------------------------------------------------------------------

describe("CmdLang help", function()
    local cmd

    before_each(function()
        cmd = makeSampleCmd()
    end)

    it("shows the entire command tree flattened", function()
        local help = cmd:help()
        -- All leaves appear
        assert.matches("listing add", help)
        assert.matches("listing list", help)
        assert.matches("listing remove", help)
        assert.matches("listing clear", help)
        assert.matches("ping", help)
        assert.matches("log on", help)
        assert.matches("log off", help)
        assert.matches("analyze", help)
    end)

    it("shows <required> and [optional] args", function()
        local help = cmd:help()
        assert.matches("<itemID>", help)
        assert.matches("<count>", help)
        assert.matches("%[itemID%]", help)  -- optional in listing list
    end)

    it("shows help text for commands and args", function()
        local help = cmd:help()
        assert.matches("Manage AH listings", help)
        assert.matches("Add a listing", help)
        assert.matches("Item ID", help)  -- arg help
        assert.matches("Stack size", help)
    end)

    it("shows batch hint", function()
        local help = cmd:help()
        assert.matches("Batch", help)
        assert.matches(";", help)
    end)

    it("shows branch nodes as section headers", function()
        local help = cmd:help()
        assert.matches("listing", help)  -- branch header
        assert.matches("log", help)      -- branch header
    end)
end)

-------------------------------------------------------------------
-- Hybrid nodes (handler + subs on same command)
-------------------------------------------------------------------
-- Bug: registering the same command name twice overwrites the first.
-- Fix: merge handler + subs into a single hybrid registration.

describe("CmdLang hybrid nodes", function()
    it("allows handler + subs on same command via single registration", function()
        local cmd = CmdLang.new()
        local calls = {}

        cmd:register {
            name = "price",
            help = "Manage prices",
            args = {
                { "itemID:int",   "Item ID" },
                { "buyout:money", "Price" },
            },
            handler = function(args)
                calls[#calls + 1] = { cmd = "price set", args = args }
            end,
            subs = {
                list = {
                    help = "List all prices",
                    handler = function()
                        calls[#calls + 1] = { cmd = "price list" }
                    end,
                },
                remove = {
                    help = "Remove a price",
                    args = { { "itemID:int", "Item ID" } },
                    handler = function(args)
                        calls[#calls + 1] = { cmd = "price remove", args = args }
                    end,
                },
            },
        }

        -- /cg price 2589 100 → handler (set price)
        local parsed, err = cmd:parse("price 2589 100")
        assert.is_nil(err, "price 2589 100 should parse, got error: " .. tostring(err))
        assert.are.equal(2589, parsed[1].args.itemID)
        assert.are.equal(100, parsed[1].args.buyout)

        -- /cg price list → sub command
        parsed, err = cmd:parse("price list")
        assert.is_nil(err, "price list should parse, got error: " .. tostring(err))

        -- /cg price remove 2589 → sub command with args
        parsed, err = cmd:parse("price remove 2589")
        assert.is_nil(err, "price remove 2589 should parse, got error: " .. tostring(err))
        assert.are.equal(2589, parsed[1].args.itemID)
    end)

    it("executes both handler and subs correctly", function()
        local cmd = CmdLang.new()
        local calls = {}

        cmd:register {
            name = "price",
            help = "Manage prices",
            args = {
                { "itemID:int",   "Item ID" },
                { "buyout:money", "Price" },
            },
            handler = function(args)
                calls[#calls + 1] = { cmd = "price set", itemID = args.itemID }
            end,
            subs = {
                list = {
                    handler = function()
                        calls[#calls + 1] = { cmd = "price list" }
                    end,
                },
            },
        }

        cmd:execute("price 2589 100")
        cmd:execute("price list")

        assert.are.equal(2, #calls)
        assert.are.equal("price set", calls[1].cmd)
        assert.are.equal(2589, calls[1].itemID)
        assert.are.equal("price list", calls[2].cmd)
    end)

    it("batch: handler + sub in same batch", function()
        local cmd = CmdLang.new()
        local calls = {}

        cmd:register {
            name = "price",
            args = {
                { "itemID:int", "" },
                { "buyout:money", "" },
            },
            handler = function(args)
                calls[#calls + 1] = { cmd = "price set", itemID = args.itemID }
            end,
            subs = {
                list = {
                    handler = function()
                        calls[#calls + 1] = { cmd = "price list" }
                    end,
                },
            },
        }

        cmd:execute("price 2589 100; price list")
        assert.are.equal(2, #calls)
        assert.are.equal("price set", calls[1].cmd)
        assert.are.equal("price list", calls[2].cmd)
    end)

    it("BUG: registering same name twice overwrites the first", function()
        -- This is the actual bug in ManualListings.lua:
        --   cmd:register { name = "price", handler = ... }   -- first
        --   cmd:register { name = "price", subs = { ... } }  -- overwrites!
        -- After the second register, "price 2589 100" fails because
        -- the handler was replaced by the subs-only node.

        local cmd = CmdLang.new()
        local calls = {}

        -- First registration (handler only)
        cmd:register {
            name = "price",
            args = {
                { "itemID:int", "" },
                { "buyout:money", "" },
            },
            handler = function(args)
                calls[#calls + 1] = { cmd = "price set", itemID = args.itemID }
            end,
        }

        -- Second registration (subs only) — overwrites the first!
        cmd:register {
            name = "price",
            subs = {
                list = {
                    handler = function()
                        calls[#calls + 1] = { cmd = "price list" }
                    end,
                },
                remove = {
                    args = { { "itemID:int", "" } },
                    handler = function(args)
                        calls[#calls + 1] = { cmd = "price remove", itemID = args.itemID }
                    end,
                },
            },
        }

        -- This should work: /cg price 2589 100
        local parsed, err = cmd:parse("price 2589 100")
        assert.is_nil(err, "price 2589 100 should still work after second register: " .. tostring(err))
        assert.is_not_nil(parsed)

        -- This should also work: /cg price list
        parsed, err = cmd:parse("price list")
        assert.is_nil(err, "price list should work: " .. tostring(err))

        -- This should also work: /cg price remove 2589
        parsed, err = cmd:parse("price remove 2589")
        assert.is_nil(err, "price remove 2589 should work: " .. tostring(err))
    end)
end)

-------------------------------------------------------------------
-- Validation at registration time
-------------------------------------------------------------------

describe("CmdLang registration validation", function()
    it("rejects invalid arg spec format", function()
        local cmd = CmdLang.new()
        assert.has_error(function()
            cmd:register {
                name = "bad",
                args = { "no_colon_here" },
                handler = function() end,
            }
        end)
    end)

    it("rejects unknown type", function()
        local cmd = CmdLang.new()
        assert.has_error(function()
            cmd:register {
                name = "bad",
                args = { "n:foobar" },
                handler = function() end,
            }
        end)
    end)

    it("rejects required arg after optional", function()
        local cmd = CmdLang.new()
        assert.has_error(function()
            cmd:register {
                name = "bad",
                args = { "a:int?", "b:int" },
                handler = function() end,
            }
        end)
    end)

    it("rejects args after rest", function()
        local cmd = CmdLang.new()
        assert.has_error(function()
            cmd:register {
                name = "bad",
                args = { "msg:rest", "extra:int" },
                handler = function() end,
            }
        end)
    end)
end)

-------------------------------------------------------------------
-- Condition system (enabled/disabled commands)
-------------------------------------------------------------------

describe("CmdLang condition", function()
    local state

    before_each(function()
        state = { ahOpen = false }
    end)

    it("condition=false rejects command with reason", function()
        local cmd = CmdLang.new()
        cmd:register {
            name = "scan",
            help = "Scan the auction house",
            condition = function()
                return state.ahOpen, "auction house must be open"
            end,
            handler = function() end,
        }

        state.ahOpen = false
        local parsed, err = cmd:parse("scan")
        assert.is_nil(parsed)
        assert.matches("unavailable", err)
        assert.matches("auction house must be open", err)
    end)

    it("condition=true allows command", function()
        local cmd = CmdLang.new()
        cmd:register {
            name = "scan",
            help = "Scan the auction house",
            condition = function()
                return state.ahOpen, "auction house must be open"
            end,
            handler = function() end,
        }

        state.ahOpen = true
        local parsed = cmd:parse("scan")
        assert.is_not_nil(parsed)
    end)

    it("condition can flip dynamically", function()
        local cmd = CmdLang.new()
        cmd:register {
            name = "scan",
            condition = function()
                return state.ahOpen, "auction house must be open"
            end,
            handler = function() end,
        }

        state.ahOpen = false
        assert.is_nil(cmd:parse("scan"))

        state.ahOpen = true
        assert.is_not_nil(cmd:parse("scan"))

        state.ahOpen = false
        assert.is_nil(cmd:parse("scan"))
    end)

    it("condition on branch disables entire subtree", function()
        local cmd = CmdLang.new()
        cmd:register {
            name = "scan",
            condition = function()
                return state.ahOpen, "auction house must be open"
            end,
            subs = {
                start = { handler = function() end },
                stop  = { handler = function() end },
            },
        }

        state.ahOpen = false
        local _, err = cmd:parse("scan start")
        assert.matches("unavailable", err)
    end)

    it("condition on subcommand only disables that sub", function()
        local cmd = CmdLang.new()
        cmd:register {
            name = "scan",
            subs = {
                start = {
                    condition = function()
                        return state.ahOpen, "auction house must be open"
                    end,
                    handler = function() end,
                },
                status = { handler = function() end },
            },
        }

        state.ahOpen = false
        local _, err = cmd:parse("scan start")
        assert.matches("unavailable", err)

        -- status still works
        local parsed = cmd:parse("scan status")
        assert.is_not_nil(parsed)
    end)

    it("help() hides disabled commands", function()
        local cmd = CmdLang.new()
        cmd:register {
            name = "always",
            help = "Always available",
            handler = function() end,
        }
        cmd:register {
            name = "scan",
            help = "Scan AH",
            condition = function()
                return state.ahOpen, "AH must be open"
            end,
            handler = function() end,
        }

        state.ahOpen = false
        local help = cmd:help()
        assert.matches("always", help)
        assert.not_matches("scan", help)
    end)

    it("helpAll() shows disabled commands with reason", function()
        local cmd = CmdLang.new()
        cmd:register {
            name = "always",
            help = "Always available",
            handler = function() end,
        }
        cmd:register {
            name = "scan",
            help = "Scan AH",
            condition = function()
                return state.ahOpen, "AH must be open"
            end,
            handler = function() end,
        }

        state.ahOpen = false
        local help = cmd:helpAll()
        assert.matches("always", help)
        assert.matches("scan", help)
        assert.matches("unavailable", help)
        assert.matches("AH must be open", help)
    end)

    it("help() shows command again when re-enabled", function()
        local cmd = CmdLang.new()
        cmd:register {
            name = "scan",
            help = "Scan AH",
            condition = function()
                return state.ahOpen, "AH must be open"
            end,
            handler = function() end,
        }

        state.ahOpen = false
        assert.not_matches("scan", cmd:help())

        state.ahOpen = true
        assert.matches("scan", cmd:help())
    end)

    it("help() shows both handler usage AND subs for hybrid nodes", function()
        local cmd = CmdLang.new()

        cmd:register {
            name = "scan",
            help = "Scan AH for an item",
            args = {
                { "itemID:int", "Item to scan" },
            },
            handler = function() end,
            subs = {
                cancel = {
                    help = "Cancel scan",
                    handler = function() end,
                },
            },
        }

        local help = cmd:help()

        -- Should show the handler usage line with <itemID>
        assert.matches("scan <itemID>", help, 1, true,
            "help should show '/cg scan <itemID>' usage for the handler")

        -- Should also show the sub command 'cancel'
        assert.matches("scan cancel", help, 1, true,
            "help should show '/cg scan cancel' sub command")
    end)

    it("no condition = always available", function()
        local cmd = CmdLang.new()
        cmd:register {
            name = "ping",
            handler = function() end,
        }
        local parsed = cmd:parse("ping")
        assert.is_not_nil(parsed)
    end)
end)
