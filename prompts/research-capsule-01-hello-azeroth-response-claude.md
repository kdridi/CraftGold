I'll research this thoroughly. The most volatile fact here is the exact interface version number for Classic Era, which changes with each patch, so let me verify that and several other current details before writing anything up.11508 confirms as the current version (patch 1.15.8). Let me verify there isn't a newer patch since October 2025, and dig into the TOC format details.Confirmed: 11508 (patch 1.15.8) is still current as of 2026. Let me get authoritative detail on the TOC format and loading lifecycle.I have authoritative TOC detail. Now let me verify the Lua version, `print()` behavior, and the addon loading lifecycle.I have enough confirmed on the TOC and chat output. Let me verify the loading lifecycle and the `scriptErrors` console variable, then I'll write everything up.I've verified the volatile facts against authoritative sources (primarily Warcraft Wiki, which tracks current patch data). Here's the full verification, question by question. The single most important correction is in Question 5 about `/reload`.

---

## Question 1 — The `.toc` file format

**Confirmed, with important nuances.**

Your minimal `.toc` is valid and sufficient. WoW will recognize and load it.

**Interface version:** `11508` is correct *as of right now* — but be precise in your teaching material: 11508 is specifically **patch 1.15.8** (released 21 October 2025), not "1.15.x" generically. The number is `major*10000 + minor*100 + patch` with periods removed, so 1.15.8 → 11508. Earlier 1.15.x patches had different numbers (1.15.4 was 11504, etc.). Since Classic Era patches bump this, you may want to phrase the capsule as "the current Classic Era version — check it yourself with `/dump (select(4, GetBuildInfo()))`" rather than hard-coding a number that will eventually go stale.

**Filename must match the folder name.** This is mandatory and a top beginner trap. Folder `HelloAzeroth/` must contain `HelloAzeroth.toc`. If they differ, the `.toc` is silently ignored and the add-on never appears.

**Required fields:** Strictly speaking, only the *file list* is required for the add-on to do anything. However:
- If you omit `## Interface:`, WoW always treats the add-on as out of date.
- `## Title:` is what shows in the add-on list (defaults to the folder name if absent).
- `## Notes:` is optional (tooltip text).

**Out-of-date behavior — correcting a likely assumption:** If the `Interface` number is *older* than the client's, WoW flags the add-on "out of date." It does **not** silently refuse to load it forever — there's a **"Load out of date AddOns"** checkbox on the add-on list that lets it load anyway. So a wrong/old number isn't fatal; it just trips the warning. (A number that is newer than the client, or malformed, behaves less predictably — keep it accurate.)

**Folder placement:** `Interface/AddOns/` relative to the WoW install — but for Classic Era specifically it's inside the version subfolder, typically:
```
World of Warcraft/_classic_era_/Interface/AddOns/HelloAzeroth/
```
Not the retail `_retail_` folder. This is a very common beginner mistake — putting the add-on in the wrong client's folder so it never appears.

**Useful additional fields** (all confirmed against current docs):
```
## Interface: 11508
## Title: Hello Azeroth
## Notes: My first WoW add-on
## Author: YourName
## Version: 1.0.0
## SavedVariables: HelloAzerothDB
## SavedVariablesPerCharacter: HelloAzerothCharDB
## Dependencies: SomeOtherAddon
## OptionalDeps: AnotherAddon
## DefaultState: enabled

HelloAzeroth.lua
```
`Author`, `Version`, and any `X-*` custom field are retrievable via `C_AddOns.GetAddOnMetadata()`. `Dependencies` (aliases: `RequiredDeps`, or anything starting with `Dep`) forces load order; missing required deps prevent loading.

**Gotcha:** WoW reads only the first 1024 characters of each line. And whitespace *before* a `#` makes WoW treat the line as a filename, not a comment — so don't indent comments.

---

## Question 2 — Lua in WoW

**Confirmed (with one refinement).**

Files listed in the `.toc` are executed in order, top to bottom — but "at UI load time" needs a precise definition (see Q3).

**Lua version: 5.1.** All WoW flavors, including Classic Era, run **Lua 5.1** — *not* 5.4. This matters for teaching: no integer division `//`, no `goto`, no bitwise operators (use the `bit` library WoW provides), `#` length operator exists, but teach 5.1 idioms throughout.

**WoW-specific library changes:** Yes, several. Some standard libraries are removed or sandboxed for security — there's no `io`, no `os.execute`, no `require`/`dofile`/`loadfile` (no filesystem access). `os.time`, `os.date`, `os.clock` exist. WoW adds its own functions to `string`, `math`, and `table`, plus globals like `strsplit`, `strjoin`, `tinsert`, `wipe`, etc. So it's "Lua 5.1 minus the OS/filesystem layer, plus a large WoW API."

**`print()`:** Use it directly — confirmed. In modern WoW (including current Classic Era), `print()` is a real, safe global that routes to the current print handler, which by default writes to the default chat frame. It's the cleaner, recommended choice over `DEFAULT_CHAT_FRAME:AddMessage()` because it handles `nil` and multiple arguments of any type gracefully.

```lua
print("Hello, Azeroth!")          -- appears in the default chat window
print("Value:", 42, nil, true)    -- handles mixed types and nil
```

**Difference between the two methods:**
- `print(...)` — accepts any number of arguments of any type, comma-separated, auto-converts and space-joins them. Cannot set color directly.
- `DEFAULT_CHAT_FRAME:AddMessage(text, r, g, b)` — takes a single string but lets you set RGB color. You must build the string yourself and it errors on `nil`.

```lua
DEFAULT_CHAT_FRAME:AddMessage("Hello in green!", 0, 1, 0)
```

For a beginner capsule, `print()` is the right default; introduce `AddMessage` only when you want colored output.

**Globals across files:** Confirmed — yes. Any global variable or function defined in one file is visible to other files in the same add-on. **But** the global namespace is shared across the *entire* UI (all add-ons + Blizzard code), which is the big gotcha — see Q7. The clean pattern, even for beginners, is the private add-on namespace passed as the second vararg to every file:

```lua
local addonName, ns = ...   -- ns is a private table shared only within this add-on
ns.greeting = "Hello, Azeroth!"
```

---

## Question 3 — Loading and lifecycle

**Mostly confirmed; one detail to sharpen.**

**When files load:** Not at the login screen and not at character selection. Per Blizzard's documented loading process, the client *scans* `Interface/AddOns` at startup (building the list of valid TOCs), but **add-on Lua code is actually executed after the player picks a character and clicks Enter World.** After all files run, SavedVariables are loaded, then the `ADDON_LOADED` event fires (once per add-on). So your capsule should say loading happens "as you enter the world," not "at the login screen."

**Top-level code:** Runs immediately when that file is executed during the load step above. So a bare `print("Hello")` at file scope fires once, as you enter the world.

**Entry point:** There is **no** `main()` or special function WoW calls. The model is event-driven. The idiomatic entry point is to create a frame and register for an event:

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, ...)
    print("Hello, Azeroth! Loaded and ready.")
end)
```
Common events to teach, in order: `ADDON_LOADED` (your SavedVariables are now available — fires per add-on, check `... == addonName`), then `PLAYER_LOGIN` (all add-ons loaded, UI ready — good general entry point), then `PLAYER_ENTERING_WORLD` (fires on login *and* every zone/instance change). For a "print on load" capsule, `PLAYER_LOGIN` is the cleanest, or just top-level code.

**Syntax errors:** A syntax/parse error in a `.lua` file causes *that file* to fail to load; subsequent files in the same TOC may still run, but the add-on is usually broken. A runtime error during top-level execution behaves similarly. With error display on, you get a popup; with it off, the failure is silent (a classic "why is nothing happening" beginner moment).

**Seeing which add-ons loaded:** The add-on list shows enabled/disabled state. In code, `C_AddOns.IsAddOnLoaded("HelloAzeroth")` (or legacy `IsAddOnLoaded`) returns load status. `/dump C_AddOns.GetAddOnInfo("HelloAzeroth")` is handy for debugging.

**`scriptErrors` — confirmed.** `/console scriptErrors 1` enables the built-in Lua error display so beginners actually see their mistakes. This is essential to include early in the capsule — by default many error popups are suppressed. (Note: many developers use the **BugSack + BugGrabber** add-ons for a better error log; worth a mention.)

**`taintLog` — confirmed but not useful here.** `/console taintLog 2` logs "taint" (the security system that blocks insecure code from touching protected/secure actions like casting spells or moving action buttons in combat). It's an advanced debugging tool for protected-function problems. For a hello-world capsule it's irrelevant and would just confuse beginners — skip it.

**`/reload`:** See Q5 — it re-executes everything from scratch.

---

## Question 4 — The Add-on list in-game

**Corrected on the menu path.**

In Classic Era, it's **not** "Escape → System → Add-ons." The game menu (Escape) has a dedicated **"AddOns"** button directly in it. There's also an **"AddOns"** button on the **character selection screen** (bottom-left), which is the most common way to manage them before entering the world. (The "System" submenu in the Esc menu holds graphics/sound/etc. options, not the add-on list.) Menu wording shifts slightly between patches, so it's worth a quick in-client check before you finalize screenshots.

The list shows, per add-on: the **Title**, an enable/disable checkbox, the **Notes** tooltip on hover, and out-of-date/missing-dependency flags. Add-ons **can** be enabled/disabled individually from this screen.

**"Load out of date AddOns":** A checkbox that, when enabled, loads add-ons whose `Interface` number doesn't match the current client (otherwise they're greyed out and skipped). Toggling it requires a `/reload` or relog to take effect.

**Character-specific vs account-wide:** Yes — there's a dropdown at the top of the list to set the enabled/disabled selection **per character** or apply it to **all characters** on the account.

---

## Question 5 — The `/reload` command

**This is your most important correction.**

Your assumption (that you might need to restart WoW after editing the `.toc`) reflects *old* behavior. On current Classic Era (since patch 1.14.0), **`/reload` does recognize changes to TOC metadata and entirely new files** added to `Interface/AddOns/` while the game is running. So:
- Edited the `.lua`? `/reload` picks it up. ✅
- Edited the `.toc` (metadata, file list)? `/reload` picks it up. ✅
- Added a brand-new add-on folder while WoW is running? `/reload` detects it. ✅

This is a big quality-of-life point for a beginner capsule: **you almost never need to fully restart WoW during development** on Classic Era — the edit → `/reload` → test loop is the whole workflow. (The legacy "must restart to add a new TOC" rule still appears in old wiki pages, which is why I'm flagging it; it's outdated for 1.15.x.)

**What `/reload` does:** It reloads the entire UI — re-reads files and **re-executes all add-on code from scratch.** All Lua state (globals, locals, frames, your variables) is wiped and rebuilt. It is essentially a UI-only restart without dropping your connection to the server.

**SavedVariables:** They **persist** across `/reload`. SavedVariables are written to disk on logout *and* on `/reload`, then read back in when the UI comes up again. So `/reload` is also how you test that your save/load logic works.

**Per-add-on reload:** No — there's **no built-in way to reload a single add-on.** `/reload` always reloads the whole UI. (`LoadOnDemand` add-ons can be loaded on the fly via `C_AddOns.LoadAddOn()`, but that's a one-way load, not a reload, and is beyond a beginner capsule.)

```
/reload          -- full alias
/reloadui        -- same thing
/console reloadui -- also works
```

---

## Question 6 — Folder structure and naming conventions

**Confirmed.**

**Folder name must match the `.toc` filename** (case-sensitive on some filesystems — keep them identical). Mismatch → the add-on is invisible to WoW. This is the #1 "it's not showing up" cause.

**Subdirectories:** Yes, a `.toc` can reference files in subfolders. Use **backslashes** (Blizzard's convention; recommended over forward slashes to avoid issues with XML `<Include>`):
```
## Interface: 11508
## Title: Hello Azeroth

Core.lua
modules\Greeter.lua
lib\Helpers.lua
```

**Naming conventions/restrictions:** The add-on folder should be a single folder sitting **directly** inside `Interface/AddOns/` (not nested). Stick to plain ASCII names without spaces — spaces and odd characters cause loading and SavedVariables headaches. SavedVariables global names you declare must be valid Lua identifiers.

**Two add-ons with the same folder name:** Not possible within one client — they'd occupy the same path and collide; one overwrites the other on disk. Across different clients (Era vs retail) they're separate.

**Path/filename length:** Governed by the OS filesystem limits (e.g., Windows path limits), not a specific WoW cap you'd realistically hit. Keep names short and sane and it's a non-issue.

---

## Question 7 — Common pitfalls for beginners

**Confirmed list, expanded.**

The most common first-timer mistakes:
1. **Folder name ≠ `.toc` name** — add-on doesn't appear at all.
2. **Wrong client folder** — dropping it in `_retail_` (or the base install) instead of `_classic_era_/Interface/AddOns/`.
3. **Forgetting "Load out of date AddOns"** or having a stale `Interface` number — add-on greyed out.
4. **Editing files while the WoW window is *closed* mid-session vs expecting hot reload** — the fix is `/reload`, not a restart (see Q5), but they need to know `/reload` exists.
5. **Errors silently swallowed** — not enabling `/console scriptErrors 1` (or BugSack), so a typo just produces "nothing happens" with no feedback.
6. **Listing a file in the `.toc` that doesn't exist / misspelled filename** — that line is skipped.

**Common error messages:**
- *"...attempt to call a nil value..."* — calling a function that doesn't exist (typo, or an API not present in Classic Era — many retail APIs are missing or namespaced differently).
- *"...attempt to index a nil value..."* — using `something.field` where `something` is nil (very common with un-initialized SavedVariables before `ADDON_LOADED`).
- *"...unexpected symbol near..."* — a Lua syntax error; the line number points at (or just after) the problem.

**Encoding / line endings — confirmed this matters:**
- Save `.lua` and `.toc` files as **UTF-8 *without* BOM**. A UTF-8 BOM at the start of a `.toc` can break the first directive (so `## Interface:` is mis-read and the add-on looks out of date or invalid). This is a genuinely sneaky beginner bug worth calling out.
- Line endings: WoW is tolerant of LF or CRLF, so that's rarely fatal, but BOM is the real trap. Tell learners to set their editor (VS Code, etc.) to "UTF-8" not "UTF-8 with BOM."

**Reserved/conflicting names — confirmed and important:** Because the global namespace is shared across all add-ons and Blizzard's own UI, defining a global like `frame`, `button`, `print`, `time`, `select`, `format`, or any common word can **overwrite a Blizzard global and break the UI** (or your add-on breaks when another add-on does the same). Two defenses to teach from day one:
- Use `local` for everything by default.
- Use the private namespace: `local addonName, ns = ...`

```lua
-- Bad: pollutes/overwrites globals
greeting = "Hi"               -- collides with anything else named "greeting"
function update() end         -- may clobber a Blizzard or addon global

-- Good
local addonName, ns = ...
local greeting = "Hi"
ns.update = function() end
```

---

If it's useful for the capsule, I can write out a complete, copy-pasteable `HelloAzeroth` add-on (the `.toc` plus a `.lua` that prints on `PLAYER_LOGIN`) with inline teaching comments, and a short "first 10 minutes" setup checklist (folder location, enable error display, the edit→`/reload`→test loop). Just say the word.