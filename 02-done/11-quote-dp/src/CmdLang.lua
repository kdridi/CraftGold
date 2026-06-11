-- CmdLang.lua
-- Declarative mini-command language for Lua 5.1
-- Pure Lua, zero dependencies, testable with busted
--
-- Design principles:
--   1. Declaration = data (tables)
--   2. Parser = generic interpreter of data
--   3. Types = pluggable functions
--   4. Help = auto-generated from declarations
--   5. Parse and dispatch are separated
--
-- Usage:
--   local CmdLang = require("CmdLang")
--   local cmd = CmdLang.new()
--
--   cmd:register {
--       name = "listing",
--       help = "Manage AH listings",
--       subs = {
--           add = {
--               help = "Add a listing to the database",
--               args = {
--                   { "itemID:int",    "Item ID" },
--                   { "count:int",     "Stack size" },
--                   { "buyout:money",  "Buyout price (e.g. 2g50s30c)" },
--               },
--               handler = function(args, ctx)
--                   ctx.db:add(args.itemID, args.count, args.buyout)
--               end,
--           },
--           list = {
--               help = "Show listings",
--               args = {
--                   { "itemID:int?", "Filter by item (optional)" },
--               },
--               handler = function(args, ctx) ... end,
--           },
--       },
--   }
--
--   cmd:execute("listing add 2840 3 2s50c", { db = MyDB })

local CmdLang = {}
CmdLang.__index = CmdLang

-------------------------------------------------------------------
-- Type system
-------------------------------------------------------------------
-- A type is a function(token) -> value | nil, errorMessage

local function builtinTypes()
    return {
        ["int"] = function(s)
            local n = tonumber(s)
            if n and n == math.floor(n) then return n end
            return nil, ("integer expected, got '%s'"):format(s)
        end,

        ["number"] = function(s)
            local n = tonumber(s)
            if n then return n end
            return nil, ("number expected, got '%s'"):format(s)
        end,

        ["string"] = function(s) return s end,

        ["bool"] = function(s)
            local v = s:lower()
            if v == "true"  or v == "on"  or v == "1" or v == "yes" then return true  end
            if v == "false" or v == "off" or v == "0" or v == "no"  then return false end
            return nil, ("boolean expected (on/off, yes/no, 1/0), got '%s'"):format(s)
        end,

        ["money"] = function(s)
            local v = s:lower()
            if v:match("^%d+$") then return tonumber(v) end
            if not v:match("^%d+[gsc]") or v:gsub("%d+[gsc]", "") ~= "" then
                return nil, ("invalid money format (e.g. 2g50s30c), got '%s'"):format(s)
            end
            local total = 0
            local mult = { g = 10000, s = 100, c = 1 }
            for num, unit in v:gmatch("(%d+)([gsc])") do
                total = total + tonumber(num) * mult[unit]
            end
            return total
        end,

        ["rest"] = function(s) return s end,
    }
end

-------------------------------------------------------------------
-- Arg spec: parse and validate declarations
-------------------------------------------------------------------
-- Formats:
--   "name:type"                  → required arg
--   "name:type?"                 → optional arg
--   "name:enum(a|b|c)"           → enum arg (required)
--   "name:enum(a|b|c)?"          → enum arg (optional)
--   { "name:type", "help text" } → with help

local function parseArgSpec(raw, path)
    local spec, help
    if type(raw) == "table" then
        spec, help = raw[1], raw[2]
    else
        spec = raw
    end

    local name, rest = spec:match("^([%w_]+):(.+)$")
    if not name then
        error(("invalid arg spec '%s' in %s — format: 'name:type'"):format(spec, path))
    end

    local optional = false
    if rest:sub(-1) == "?" then
        optional = true
        rest = rest:sub(1, -2)
    end

    local result = {
        name     = name,
        typeName = rest,
        optional = optional,
        help     = help,
    }

    local enums = rest:match("^enum%((.+)%)$")
    if enums then
        result.enumValues = {}
        for v in enums:gmatch("[^|]+") do
            result.enumValues[v] = true
        end
    end

    return result
end

local function compileArgs(args, types, path)
    if not args then return nil end

    local compiled = {}
    local seenOptional = false

    for i, raw in ipairs(args) do
        local a = parseArgSpec(raw, path)

        if compiled[i - 1] and compiled[i - 1].typeName == "rest" then
            error(("no argument allowed after 'rest' in %s"):format(path))
        end
        if seenOptional and not a.optional then
            error(("required arg '%s' after optional arg in %s"):format(a.name, path))
        end
        if not a.enumValues and a.typeName ~= "rest" then
            if not types[a.typeName] then
                error(("unknown type '%s' for arg '%s' in %s"):format(a.typeName, a.name, path))
            end
        end

        seenOptional = seenOptional or a.optional
        compiled[i] = a
    end

    return compiled
end

-------------------------------------------------------------------
-- Command tree: compile declaration into internal tree
-------------------------------------------------------------------

-- Default condition: always available
local ALWAYS_AVAILABLE = function() return true, "" end

local function compileNode(def, types, path)
    local node = {
        name      = def.name,
        help      = def.help,
        handler   = def.handler,
        args      = compileArgs(def.args, types, path),
        subs      = nil,
        path      = path,
        condition = def.condition or ALWAYS_AVAILABLE,
    }

    if def.subs then
        node.subs = {}
        for subName, subDef in pairs(def.subs) do
            node.subs[subName] = compileNode(subDef, types, path .. " " .. subName)
        end
    end

    return node
end

-------------------------------------------------------------------
-- Tokenizer
-------------------------------------------------------------------
-- Produces a flat list of tokens from a raw input string.
-- Handles: whitespace delimiters, quoted strings ("..." / '...'),
-- and semicolons as batch separators (protected inside quotes).

local function tokenize(input)
    local tokens = {}
    local i, n = 1, #input

    while i <= n do
        local c = input:sub(i, i)

        if c:match("%s") then
            i = i + 1

        elseif c == ";" then
            tokens[#tokens + 1] = { sep = true }
            i = i + 1

        elseif c == '"' or c == "'" then
            local close = input:find(c, i + 1, true)
            if not close then
                return nil, "unterminated quote at position " .. i
            end
            tokens[#tokens + 1] = { text = input:sub(i + 1, close - 1) }
            i = close + 1

        else
            local j = input:find("[%s%;\"']", i)
            local stop = j and (j - 1) or n
            tokens[#tokens + 1] = { text = input:sub(i, stop) }
            i = stop + 1
        end
    end

    return tokens
end

-- Split token list into batches at semicolons
local function splitBatches(tokens)
    local batches, cur = {}, {}
    for _, tok in ipairs(tokens) do
        if tok.sep then
            if #cur > 0 then batches[#batches + 1] = cur; cur = {} end
        else
            cur[#cur + 1] = tok
        end
    end
    if #cur > 0 then batches[#batches + 1] = cur end
    return batches
end

-------------------------------------------------------------------
-- Resolver: match token batch against command tree
-------------------------------------------------------------------

local function resolve(commands, tokens)
    if #tokens == 0 then
        return nil, "empty command"
    end

    local first = tokens[1].text
    local node = commands[first]
    if not node then
        -- Build suggestion list
        local names = {}
        for k in pairs(commands) do names[#names + 1] = k end
        table.sort(names)
        return nil, ("unknown command '%s' (available: %s)")
            :format(first, table.concat(names, ", "))
    end

    -- Check condition on root command
    local available, reason = node.condition()
    if not available then
        return nil, ("%s: unavailable — %s"):format(node.path, reason)
    end

    local idx = 2

    -- Walk subcommands
    while node.subs do
        local tok = tokens[idx]
        if not tok then
            local names = {}
            for k in pairs(node.subs) do names[#names + 1] = k end
            table.sort(names)
            return nil, ("%s: expected subcommand (%s)")
                :format(node.path, table.concat(names, ", "))
        end
        if not node.subs[tok.text] then
            local names = {}
            for k in pairs(node.subs) do names[#names + 1] = k end
            table.sort(names)
            return nil, ("%s: unknown subcommand '%s' (expected: %s)")
                :format(node.path, tok.text, table.concat(names, ", "))
        end
        node = node.subs[tok.text]
        idx = idx + 1

        -- Check condition on this subcommand
        available, reason = node.condition()
        if not available then
            return nil, ("%s: unavailable — %s"):format(node.path, reason)
        end
    end

    return { node = node, startIndex = idx }
end

-------------------------------------------------------------------
-- Binder: match remaining tokens against typed arg specs
-------------------------------------------------------------------

local function bindArgs(node, tokens, startIdx, types)
    local args = {}
    local idx = startIdx

    for _, spec in ipairs(node.args or {}) do
        local tok = tokens[idx]

        if spec.typeName == "rest" then
            local parts = {}
            while tokens[idx] do
                parts[#parts + 1] = tokens[idx].text
                idx = idx + 1
            end
            if #parts > 0 then
                args[spec.name] = table.concat(parts, " ")
            elseif not spec.optional then
                return nil, ("%s: missing argument '%s' (expected %s)")
                    :format(node.path, spec.name, spec.typeName)
            end

        elseif spec.enumValues then
            if not tok then
                if spec.optional then break end
                return nil, ("%s: missing argument '%s' (expected %s)")
                    :format(node.path, spec.name, spec.typeName)
            end
            if not spec.enumValues[tok.text] then
                local valid = {}
                for v in pairs(spec.enumValues) do valid[#valid + 1] = v end
                table.sort(valid)
                return nil, ("%s: '%s' is not valid for '%s' (expected: %s)")
                    :format(node.path, tok.text, spec.name, table.concat(valid, "|"))
            end
            args[spec.name] = tok.text
            idx = idx + 1

        else
            if not tok then
                if spec.optional then break end
                return nil, ("%s: missing argument '%s' (expected %s)")
                    :format(node.path, spec.name, spec.typeName)
            end
            local value, err = types[spec.typeName](tok.text)
            if value == nil then
                return nil, ("%s: argument '%s': %s")
                    :format(node.path, spec.name, err)
            end
            args[spec.name] = value
            idx = idx + 1
        end
    end

    if tokens[idx] then
        return nil, ("%s: unexpected argument '%s'")
            :format(node.path, tokens[idx].text)
    end

    return args
end

-------------------------------------------------------------------
-- Help generator
-------------------------------------------------------------------

-------------------------------------------------------------------
-- Help generators (shared logic)
-------------------------------------------------------------------

local function generateHelp(self, showAll)
    local lines = { "|cFFFFFF00/cg|r command reference:", "" }

    local function walkTree(node, depth)
        local available, reason = node.condition()

        if not showAll and not available then return end  -- skip disabled

        local indent = string.rep("  ", depth)

        if node.subs then
            -- Branch node
            local header = indent .. "|cFF4FC3F7" .. node.path .. "|r"
            if node.help then header = header .. " — " .. node.help end
            if not available then
                header = header .. "  |cFFFF0000[unavailable: " .. reason .. "]|r"
            end
            lines[#lines + 1] = header

            local subNames = {}
            for k in pairs(node.subs) do subNames[#subNames + 1] = k end
            table.sort(subNames)

            for _, name in ipairs(subNames) do
                walkTree(node.subs[name], depth + 1)
            end
        else
            -- Leaf node
            local usage = indent .. "|cFFFFFF00/cg " .. node.path
            if node.args then
                for _, a in ipairs(node.args) do
                    if a.optional then
                        usage = usage .. " [" .. a.name .. "]"
                    else
                        usage = usage .. " <" .. a.name .. ">"
                    end
                end
            end
            if not available then
                usage = usage .. "  |cFFFF0000[unavailable: " .. reason .. "]|r"
            else
                usage = usage .. "|r"
            end
            if available and node.help then usage = usage .. "  — " .. node.help end
            lines[#lines + 1] = usage

            -- Show arg details if any have help text
            if node.args then
                for _, a in ipairs(node.args) do
                    if a.help then
                        local tag = a.optional and "optional" or "required"
                        lines[#lines + 1] = indent .. "    |cFF808080" .. a.name
                            .. " (" .. a.typeName .. ", " .. tag .. "): "
                            .. a.help .. "|r"
                    end
                end
            end
        end
    end

    local names = {}
    for k in pairs(self.commands) do names[#names + 1] = k end
    table.sort(names)

    for _, name in ipairs(names) do
        walkTree(self.commands[name], 0)
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cFF808080Batch: separate commands with ; (e.g. /cg listing clear 2840; listing add 2840 3 2s50c)|r"

    return table.concat(lines, "\n")
end

-------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------

function CmdLang.new()
    local self = setmetatable({}, CmdLang)
    self.types = builtinTypes()
    self.commands = {}
    return self
end

--- Register a custom type.
-- @param name  type name (e.g. "itemlink")
-- @param fn    function(token) -> value | nil, errorMessage
function CmdLang:registerType(name, fn)
    self.types[name] = fn
end

--- Register a command.
-- @param def  table with name, help, args, subs, handler
function CmdLang:register(def)
    assert(type(def) == "table" and type(def.name) == "string",
        "CmdLang.register: expected table with 'name' field")
    self.commands[def.name] = compileNode(def, self.types, def.name)
end

--- Parse input string into a list of parsed commands.
-- Returns: list of { node, args } or nil, errorMessage
function CmdLang:parse(input)
    local tokens, err = tokenize(input or "")
    if not tokens then return nil, err end

    local batches = splitBatches(tokens)
    if #batches == 0 then return nil, "empty command" end

    local parsed = {}
    for i, batch in ipairs(batches) do
        local resolved, err = resolve(self.commands, batch)
        if not resolved then return nil, err end

        local args, err = bindArgs(resolved.node, batch, resolved.startIndex, self.types)
        if not args then return nil, err end

        parsed[i] = { node = resolved.node, args = args }
    end

    return parsed
end

--- Parse and execute all commands.
-- Returns: list of handler results or nil, errorMessage
function CmdLang:execute(input, ctx)
    local parsed, err = self:parse(input)
    if not parsed then return nil, err end

    local results = {}
    for i, cmd in ipairs(parsed) do
        if not cmd.node.handler then
            return nil, ("%s: no handler registered"):format(cmd.node.path)
        end
        results[i] = cmd.node.handler(cmd.args, ctx)
    end

    return results
end

--- Generate help text (only enabled commands).
function CmdLang:help()
    return generateHelp(self, false)
end

--- Generate full help text (all commands, including disabled with reasons).
function CmdLang:helpAll()
    return generateHelp(self, true)
end

--- Expose internal functions for testing.
CmdLang._tokenize = tokenize
CmdLang._splitBatches = splitBatches

-- Register in namespace (WoW .toc loading ignores 'return')
local _, ns = ...
if ns and type(ns) == "table" then ns.CmdLang = CmdLang end

return CmdLang
