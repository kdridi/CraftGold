# The `.toc` File — WoW Add-on Manifest

> Consolidated from ChatGPT, Claude, and Gemini research (Session 1).
> See `prompts/research-capsule-01-hello-azeroth-response-*.md` for raw responses.

---

## What is it?

The `.toc` (Table of Contents) file is the **manifest** that tells WoW how to recognize and load your add-on. Without it, your folder is invisible.

## Mandatory rules

1. **Filename must match folder name** — `HelloAzeroth/HelloAzeroth.toc`. If they differ, WoW silently ignores the entire folder. This is the #1 "my add-on doesn't show up" cause.
2. **File placement** — Must be in `_classic_era_/Interface/AddOns/YourFolder/` (NOT `_retail_` or `_classic_`)
3. **UTF-8 without BOM** — A BOM can corrupt the first directive (especially `## Interface:`)

## Minimal valid `.toc`

```
## Interface: 11508
## Title: Hello Azeroth
## Notes: My first WoW add-on

HelloAzeroth.lua
```

## All available fields

```toc
## Interface: 11508
## Title: Hello Azeroth
## Notes: My first WoW add-on
## Author: YourName
## Version: 1.0.0
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB
## Dependencies: SomeOtherAddon
## OptionalDeps: AnotherAddon
## DefaultState: enabled
## LoadOnDemand: 1

HelloAzeroth.lua
src\Utils.lua
```

### Field details

| Field | Purpose | Required? |
|-------|---------|-----------|
| `## Interface:` | Game version number. If mismatched, add-on marked "out of date" | Practically yes |
| `## Title:` | Name shown in add-on list. Defaults to folder name if absent | No |
| `## Notes:` | Tooltip text on hover in add-on list | No |
| `## Author:` | Creator name (informational, shown in add-on list) | No |
| `## Version:` | Your version string (informational) | No |
| `## SavedVariables:` | Global variables persisted to disk (all characters) | No |
| `## SavedVariablesPerCharacter:` | Variables persisted per character | No |
| `## Dependencies:` | Add-ons that MUST load before this one | No |
| `## OptionalDeps:` | Add-ons that should load before this one if present | No |
| `## DefaultState:` | `enabled` or `disabled` on first install | No |
| `## LoadOnDemand:` | `1` = don't load at startup, load via `LoadAddOn()` | No |

## Interface version

The interface number follows the pattern `major * 10000 + minor * 100 + patch`:
- 1.15.4 → 11504
- 1.15.7 → 11507
- 1.15.8 → 11508

**Always verify in-game**: `/dump select(4, GetBuildInfo())`

If the number is older than the client, the add-on is flagged "out of date" but can still load if the user checks **"Load out of date AddOns"**.

## File list

- Files listed after the `##` headers are loaded **in order**, top to bottom
- Subdirectories are allowed: `src\Core.lua` or `modules\Utils.lua`
- If a listed file doesn't exist, that line is silently skipped
- Only the first 1024 characters of each line are read

## Gotchas

1. **Don't forget `##`** before metadata lines. `Interface: 11508` without `##` is treated as a filename
2. **Don't indent** comment lines — whitespace before `#` makes WoW treat it as a filename
3. **Hidden extensions on Windows** — File might actually be `HelloAzeroth.toc.txt`
4. **Double nesting** — Extracting a ZIP creates `AddOns/HelloAzeroth/HelloAzeroth/HelloAzeroth.toc` (one folder too deep)
5. **Case sensitivity** — Keep folder name, `.toc` name, and file references consistent (especially cross-platform)

## Accessing metadata from code

```lua
-- Get any ## field from your own add-on
local version = C_AddOns.GetAddOnMetadata("HelloAzeroth", "Version")
local notes = C_AddOns.GetAddOnMetadata("HelloAzeroth", "Notes")
```
