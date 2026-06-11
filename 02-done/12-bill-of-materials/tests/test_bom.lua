-- tests/test_bom.lua
-- Busted tests for BOM module + CmdLang hybrid node fix

local helpers = require("tests/helpers")

-------------------------------------------------------------------
-- BOM module tests
-------------------------------------------------------------------

describe("BOM expand", function()
    local ns

    before_each(function()
        ns = helpers.setup()
    end)

    it("non-craftable item → itself as raw material", function()
        local exp = ns.BOM.expand(2840, 3)
        assert.are.equal(3, exp.materials[2840])
        assert.are.equal(0, #exp.errors)
    end)

    it("non-craftable ×1 → qty 1", function()
        local exp = ns.BOM.expand(2835, 1)
        assert.are.equal(1, exp.materials[2835])
    end)

    it("Copper Bolts (1 Copper Bar) → expands to Copper Bar", function()
        local exp = ns.BOM.expand(4359, 2)
        assert.are.equal(2, exp.materials[2840])
        assert.is_nil(exp.materials[4359])  -- craftable, should not appear
    end)

    it("Rough Blasting Powder (1 Rough Stone) → expands to Rough Stone", function()
        local exp = ns.BOM.expand(4357, 3)
        assert.are.equal(3, exp.materials[2835])
        assert.is_nil(exp.materials[4357])
    end)

    it("multi-reagent craft aggregates correctly", function()
        -- Rough Copper Bomb (4360):
        --   {2589, 1}, {2840, 1}, {4357, 2}, {4359, 1}
        -- 4357 = Rough Blasting Powder → {2835, 1}
        -- 4359 = Copper Bolts → {2840, 1}
        -- Expected: Linen Cloth ×1, Copper Bar ×2, Rough Stone ×2
        local exp = ns.BOM.expand(4360, 1)
        assert.are.equal(1, exp.materials[2589])  -- Linen Cloth
        assert.are.equal(2, exp.materials[2840])  -- Copper Bar (1 direct + 1 via Bolts)
        assert.are.equal(2, exp.materials[2835])  -- Rough Stone (via Blasting Powder ×2)
        assert.is_nil(exp.materials[4357])        -- Blasting Powder is craftable
        assert.is_nil(exp.materials[4359])        -- Copper Bolts is craftable
    end)

    it("quantity multiplication works", function()
        -- Rough Copper Bomb ×3
        local exp = ns.BOM.expand(4360, 3)
        assert.are.equal(3, exp.materials[2589])  -- 1 × 3
        assert.are.equal(6, exp.materials[2840])  -- 2 × 3
        assert.are.equal(6, exp.materials[2835])  -- 2 × 3
    end)

    it("qty defaults to 1", function()
        local exp = ns.BOM.expand(4359)
        assert.are.equal(1, exp.materials[2840])
    end)

    it("qty 0 produces empty materials", function()
        local exp = ns.BOM.expand(4359, 0)
        local count = 0
        for _ in pairs(exp.materials) do count = count + 1 end
        assert.are.equal(0, count)
    end)

    it("deep tree expands fully", function()
        -- Ornate Spyglass (5507):
        --   {1206, 1}, {4363, 1}, {4371, 2}, {4375, 2}
        -- 4363 = Copper Modulator → {2589, 2}, {2840, 1}, {4359, 2}
        --   4359 = Copper Bolts → {2840, 1}
        -- 4371 = Bronze Tube → {2841, 2}, {2880, 1}
        -- 4375 = Whirring Bronze Gizmo → {2592, 1}, {2841, 2}
        -- So for ×1:
        --   1206 (Moss Agate) ×1
        --   2589 (Linen Cloth) ×2 (from Copper Modulator)
        --   2840 (Copper Bar) ×3 (1 from Modulator + 2×1 from Bolts in Modulator)
        --   2841 (Bronze Bar) ×6 (2×2 from Bronze Tube + 2×2 from Gizmo... wait)
        -- Actually: 4371 ×2 → Bronze Bar ×4, Flux ×2
        --           4375 ×2 → Wool Cloth ×2, Bronze Bar ×4
        --   2880 (Weak Flux) ×2 (from Bronze Tube ×2)
        --   2592 (Wool Cloth) ×2 (from Gizmo ×2)
        --   2841 (Bronze Bar) ×8 (4 from Tube ×2 + 4 from Gizmo ×2)
        local exp = ns.BOM.expand(5507, 1)
        assert.are.equal(1, exp.materials[1206])  -- Moss Agate
        assert.are.equal(2, exp.materials[2589])  -- Linen Cloth
        assert.are.equal(3, exp.materials[2840])  -- Copper Bar
        assert.are.equal(8, exp.materials[2841])  -- Bronze Bar
        assert.are.equal(2, exp.materials[2880])  -- Weak Flux
        assert.are.equal(2, exp.materials[2592])  -- Wool Cloth
    end)
end)

describe("BOM shoplist", function()
    local ns

    before_each(function()
        ns = helpers.setup()
        -- Add some listings for quoting
        ns.Listings.add(2840, 20, 5000)   -- 20 Copper Bar @ 50s
        ns.Listings.add(2835, 10, 1000)   -- 10 Rough Stone @ 10s
        ns.Listings.add(2589, 5, 200)      -- 5 Linen Cloth @ 2s
    end)

    it("quotes each raw material", function()
        local sl = ns.BOM.shoplist(4360, 3)
        -- Copper Bar ×6: 20@5000 → cost 5000, surplus 14
        -- Rough Stone ×6: 10@1000 → cost 1000, surplus 4
        -- Linen Cloth ×3: 5@200 → cost 200, surplus 2
        -- Total = 6200
        assert.are.equal(3, #sl.quotes)
        assert.are.equal(6200, sl.totalCost)
    end)

    it("returns itemID and qty", function()
        local sl = ns.BOM.shoplist(4360, 2)
        assert.are.equal(4360, sl.itemID)
        assert.are.equal(2, sl.qty)
    end)

    it("reports unquoted materials when no listings", function()
        ns.Listings.clear(2835)  -- Remove Rough Stone listings
        local sl = ns.BOM.shoplist(4360, 1)
        local unquoted = 0
        for _, q in ipairs(sl.quotes) do
            if not q.result then unquoted = unquoted + 1 end
        end
        assert.are.equal(1, unquoted)
    end)

    it("qty defaults to 1", function()
        local sl = ns.BOM.shoplist(4359)
        assert.are.equal(1, sl.qty)
    end)

    it("quotes are sorted by itemID", function()
        local sl = ns.BOM.shoplist(4360, 1)
        for i = 2, #sl.quotes do
            assert.is_true(sl.quotes[i - 1].itemID < sl.quotes[i].itemID)
        end
    end)
end)

-------------------------------------------------------------------
-- CmdLang hybrid node tests (bug fix: handler + subs on same node)
-------------------------------------------------------------------

describe("CmdLang hybrid node (handler + subs)", function()
    local CmdLang = require("src.CmdLang")
    local cmd, calls

    before_each(function()
        cmd = CmdLang.new()
        calls = {}

        -- Hybrid node: "shoplist" has its own handler AND a sub "expand"
        cmd:register {
            name = "shoplist",
            help = "Expand a craft into raw materials",
            args = {
                { "itemID:int", "Item to craft" },
                { "qty:int?", "Quantity (default: 1)" },
            },
            handler = function(args)
                calls[#calls + 1] = { cmd = "shoplist", args = args }
            end,
            subs = {
                expand = {
                    help = "Show raw materials without prices",
                    args = {
                        { "itemID:int", "Item to craft" },
                        { "qty:int?", "Quantity (default: 1)" },
                    },
                    handler = function(args)
                        calls[#calls + 1] = { cmd = "shoplist expand", args = args }
                    end,
                },
            },
        }
    end)

    it("routes to handler when no subcommand matches (leaf path)", function()
        local parsed, err = cmd:parse("shoplist 4360 3")
        assert.is_nil(err)
        assert.is_not_nil(parsed)
        assert.are.equal(4360, parsed[1].args.itemID)
        assert.are.equal(3, parsed[1].args.qty)
    end)

    it("routes to subcommand when token matches a sub", function()
        local parsed, err = cmd:parse("shoplist expand 4360 3")
        assert.is_nil(err)
        assert.is_not_nil(parsed)
        assert.are.equal(4360, parsed[1].args.itemID)
        assert.are.equal(3, parsed[1].args.qty)
    end)

    it("handler works with no optional args", function()
        local parsed, err = cmd:parse("shoplist 4360")
        assert.is_nil(err)
        assert.are.equal(4360, parsed[1].args.itemID)
        assert.is_nil(parsed[1].args.qty)
    end)

    it("sub works with no optional args", function()
        local parsed, err = cmd:parse("shoplist expand 4360")
        assert.is_nil(err)
        assert.are.equal(4360, parsed[1].args.itemID)
    end)

    it("executes handler path correctly", function()
        cmd:execute("shoplist 4360 2")
        assert.are.equal(1, #calls)
        assert.are.equal("shoplist", calls[1].cmd)
        assert.are.equal(4360, calls[1].args.itemID)
        assert.are.equal(2, calls[1].args.qty)
    end)

    it("executes sub path correctly", function()
        cmd:execute("shoplist expand 4360 2")
        assert.are.equal(1, #calls)
        assert.are.equal("shoplist expand", calls[1].cmd)
        assert.are.equal(4360, calls[1].args.itemID)
        assert.are.equal(2, calls[1].args.qty)
    end)

    it("batch: handler then sub in same line", function()
        cmd:execute("shoplist 4360 1; shoplist expand 4360 3")
        assert.are.equal(2, #calls)
        assert.are.equal("shoplist", calls[1].cmd)
        assert.are.equal("shoplist expand", calls[2].cmd)
    end)

    it("batch: sub then handler in same line", function()
        cmd:execute("shoplist expand 4360 3; shoplist 4360 1")
        assert.are.equal(2, #calls)
        assert.are.equal("shoplist expand", calls[1].cmd)
        assert.are.equal("shoplist", calls[2].cmd)
    end)

    it("unknown subcommand on non-hybrid node still errors", function()
        -- Pure branch node (no handler) should still error
        local cmd2 = CmdLang.new()
        cmd2:register {
            name = "log",
            subs = {
                on = { handler = function() end },
                off = { handler = function() end },
            },
        }
        local _, err = cmd2:parse("log unknown")
        assert.matches("unknown subcommand", err)
    end)

    it("no tokens on non-hybrid branch still errors", function()
        local cmd2 = CmdLang.new()
        cmd2:register {
            name = "log",
            subs = {
                on = { handler = function() end },
            },
        }
        local _, err = cmd2:parse("log")
        assert.matches("expected subcommand", err)
    end)

    it("hybrid node with token that is not a sub and not a valid arg", function()
        -- "shoplist foo" — "foo" is not a sub (expand is), and hybrid → try as leaf
        -- but "foo" is not a valid int → type error on itemID
        local _, err = cmd:parse("shoplist foo")
        assert.is_not_nil(err)
        assert.matches("itemID", err)
    end)
end)
