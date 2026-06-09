# 03 — Saved Variables

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 1                                                     |
| Duration      | 30 min                                                      |
| Difficulty    | ●●○○○ (2/5)                                                |
| Prerequisites | Capsule 02 — Slash Commands                                 |
| Type          | Autonomous                                                  |
| Concepts      | `SavedVariables` in `.toc`, `ADDON_LOADED` event, persistence |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Declare** SavedVariables in the `.toc` file
2. **Handle** the `ADDON_LOADED` event to initialize data
3. **Persist** data across sessions (reload, logout, restart)

## Key Concepts

*(To be expanded during Phase C)*

## Execution

1. Copy to `Interface/AddOns/`
2. `/reload` in-game
3. Set a value via slash command
4. `/reload` again → value should persist

## Expected Output

```
[SavedVars] Counter: 5 (saved across sessions!)
```

## Common Pitfalls

*(To be populated during Phase B)*

## Going Further

- → Next capsule: **04 — My First Frame**
