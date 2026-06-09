# 01 — Hello Azeroth

| Metadata      | Value                                              |
|---------------|----------------------------------------------------|
| Phase         | Phase 1                                            |
| Duration      | 20 min                                             |
| Difficulty    | ●○○○○ (1/5)                                       |
| Prerequisites | None                                               |
| Type          | Autonomous                                         |
| Concepts      | `.toc` file, `.lua` file, `print()`, `/reload`    |

## Why This Capsule?

*(To be written during Phase A — storytelling)*

## Objectives

By the end of this capsule, you will be able to:

1. **Create** a valid `.toc` file that WoW recognizes as an add-on
2. **Write** a basic Lua script that runs when the add-on loads
3. **See** your add-on's output in the WoW chat window
4. **Reload** the UI to test changes without restarting the game

## Key Concepts

*(To be expanded during Phase C)*

### The `.toc` File — Your Add-on's ID Card

```
## Interface: 11508
## Title: Hello Azeroth
## Notes: My first WoW add-on
## Author: YourName

HelloAzeroth.lua
```

- `## Interface: 11508` — the version of WoW Classic Era's UI API (1.15.8, verify in-game with `/dump select(4, GetBuildInfo())`)
- `## Title` — the name shown in the Add-ons list
- Files listed at the bottom are loaded **in order**

### The `.lua` File — Your Add-on's Brain

```lua
print("Hello Azeroth!")
```

- `print()` outputs a message to the default chat window
- Code outside of functions runs **immediately** when the file is loaded

### `/reload` — The Developer's Best Friend

- Type `/reload` in chat to reload the entire UI
- All add-ons are reloaded from disk
- Equivalent to restarting the game's UI layer (much faster than restarting WoW)

## Execution

1. Copy the `01-hello-azeroth/` folder into `Interface/AddOns/`
2. Launch WoW (or type `/reload` if already in-game)
3. Check the chat window for the message
4. Verify in Escape → System → Add-ons that "Hello Azeroth" appears

## Expected Output

```
[HelloAzeroth] Hello Azeroth! The add-on has loaded successfully.
```

## Common Pitfalls

*(To be populated during Phase B based on real experience)*

## Going Further

- → Next capsule: **02 — Slash Commands**
