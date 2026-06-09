# Lua in WoW Classic Era

> Consolidated from ChatGPT, Claude, and Gemini research (Session 1).

---

## Lua version

**Lua 5.1** — all WoW flavors including Classic Era.

What this means for beginners:
- ✅ `local`, tables, metatables, `#` length operator, `string.format()`, `pairs()`, `ipairs()`
- ❌ No `//` (integer division), no `goto`, no bitwise operators in syntax (use `bit` library)
- ❌ No `require()`, `dofile()`, `loadfile()` — WoW blocks filesystem access

## WoW modifications to standard Lua

### Removed (security)
- `io` library (filesystem)
- `os.execute()` (shell commands)
- `require()`, `dofile()`, `loadfile()` (loading external files)

### Kept
- `os.time()`, `os.date()`, `os.clock()`
- `math.*`, `string.*`, `table.*`

### Added by WoW
- `strsplit(sep, str)`, `strjoin(sep, ...)` — string splitting/joining
- `tinsert(table, value)`, `tremove(table, pos)` — table manipulation
- `wipe(table)` — clear a table
- `GetCoinTextureString(copper)` — format gold/silver/copper
- The entire WoW API (`CreateFrame`, `GetItemInfo`, events, etc.)

## Output to chat

### `print()` — recommended for beginners
```lua
print("Hello Azeroth!")           -- simple message
print("Value:", 42, nil, true)    -- handles multiple args, nil, any type
```
- Routes to the default chat frame
- Handles `nil` and multiple arguments gracefully
- Cannot set text color directly

### `DEFAULT_CHAT_FRAME:AddMessage()` — for colored output
```lua
DEFAULT_CHAT_FRAME:AddMessage("Hello in green!", 0, 1, 0)  -- RGB: 0-1 range
```
- Single string argument (must build it yourself)
- Allows RGB color control (values 0.0 to 1.0)
- Errors on `nil` — must convert to string first

**Rule: use `print()` by default, `AddMessage` only when you need colors.**

## Global scope and namespacing

All files in an add-on share the **same Lua environment** — and that environment is shared with ALL other add-ons and Blizzard's own UI code.

### The vararg trick — private namespace
```lua
-- Every .lua file receives these as varargs:
local addonName, ns = ...
-- addonName = "HelloAzeroth" (string)
-- ns = a table shared ONLY between files of this add-on
```

### Bad vs Good
```lua
-- ❌ BAD: pollutes global namespace, can overwrite other add-ons
message = "Hello"
function update() end

-- ✅ GOOD: use local or private namespace
local message = "Hello"
ns.message = "Hello"
ns.update = function() end
```

### Never use these as variable names (they're WoW globals)
`CreateFrame`, `print`, `select`, `format`, `time`, `wipe`, `pairs`, `ipairs`, `tinsert`, `strsplit`, `DEFAULT_CHAT_FRAME`, `UIParent`, `GameTooltip`... basically, if WoW defines it, don't overwrite it.

**Rule: `local` everything by default.**

## Loading lifecycle

### When does code run?

1. **Loading screen** (after character selection, before entering world)
   - WoW scans `Interface/AddOns/` for `.toc` files
   - For each enabled add-on, loads `.lua` files in `.toc` order
   - **Top-level code runs immediately** during this phase
   - ⚠️ The chat frame may not be fully initialized yet — `print()` at top level may not be visible

2. **After all files loaded** — `ADDON_LOADED` event fires (once per add-on)
   - SavedVariables are now available
   - Good place to initialize data

3. **After all add-ons loaded** — `PLAYER_LOGIN` event fires
   - All add-on code has executed
   - UI is ready
   - **Best event for a "hello world" message**

4. **Entering world** — `PLAYER_ENTERING_WORLD` event fires
   - Fires on login AND every zone/instance change
   - Good for initial setup that needs the world to be loaded

### The loading screen trap

```lua
-- This runs during loading screen — player probably won't see it!
print("Hello from top-level code")

-- This runs after the world loads — player will see it ✅
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    print("Hello Azeroth! Add-on loaded.")
end)
```

## Error handling

### Enable error display (essential for development)
```
/console scriptErrors 1
```
Without this, Lua errors are **silently swallowed**. The add-on just stops working with no feedback.

### Common error messages

| Error | Meaning |
|-------|---------|
| `attempt to call a nil value` | Calling a function that doesn't exist (typo, or Retail-only API) |
| `attempt to index a nil value` | Accessing `.field` on something that's nil (common with uninitialized SavedVariables) |
| `unexpected symbol near 'x'` | Syntax error — check the line number |

### Advanced debugging tools (not for beginners)
- `/console taintLog 2` — logs taint issues (secure/protected action conflicts). Too noisy for beginners.
- **BugSack + BugGrabber** — third-party add-ons that provide a better error log. Worth mentioning as optional.

## `/reload` — the developer's best friend

### What it does
- Re-reads all files from disk
- Re-executes all add-on Lua code from scratch
- Wipes all Lua state (globals, locals, frames)
- Writes SavedVariables to disk, then reads them back
- Equivalent to a full UI restart without disconnecting

### ⚠️ Unresolved: does `/reload` detect new add-on folders?

| Source | Says |
|--------|------|
| Claude | **Yes** — since Classic Era 1.14.0, `/reload` detects new folders and TOC changes |
| Gemini | **No** — new add-on folders require a full client restart |
| ChatGPT | **Maybe** — "generally yes but some cases may need restart" |

**→ Must be verified in-game during Phase B of Capsule 01.**

### What we know for sure
- Editing an existing `.lua` file → `/reload` picks it up ✅ (all 3 agree)
- SavedVariables persist across `/reload` ✅ (all 3 agree)
- No way to reload a single add-on ✅ (all 3 agree)

## File encoding

- **UTF-8 without BOM** — both `.lua` and `.toc` files
- Line endings: WoW tolerates both LF and CRLF
- BOM (Byte Order Mark) can corrupt `.toc` headers → add-on appears "out of date" or fails to load
