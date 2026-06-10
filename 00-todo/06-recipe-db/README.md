# 06 — Recipe DB

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 3 — Cœur métier                                       |
| Duration      | 45 min                                                      |
| Difficulty    | ●●●○○ (3/5)                                                |
| Prerequisites | Capsule 03 — Saved Variables (architecture Functional Core) |
| Type          | Autonomous                                                  |
| Concepts      | DB statique, itemID, structures Lua, tests busted           |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Define** a static recipe database for Engineering (10-20 recipes)
2. **Store** everything by itemID (not by name)
3. **Query** recipes by output itemID
4. **Test** the DB in pure Lua with busted (no WoW API needed)

## Key Concepts

*(To be expanded during Phase C)*

## Execution

1. Copy to `Interface/AddOns/`
2. `/reload` in-game
3. Type `/cgdb test` to run in-game tests
4. Run `busted` outside WoW for pure Lua tests

## Expected Output

A working recipe database that can answer:
- "What recipe produces item X?"
- "What reagents does recipe Y need?"
- "What items can I craft with item Z?"

## Common Pitfalls

*(To be populated during Phase B)*

## Going Further

- → Next capsule: **07 — Price & Calculator**
