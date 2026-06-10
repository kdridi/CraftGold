# 09 — Item Info

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données du jeu                                    |
| Duration      | 45 min                                                      |
| Difficulty    | ●●●○○ (3/5)                                                |
| Prerequisites | Capsule 08 — Analyze & Report                               |
| Type          | Semi-autonomous                                              |
| Concepts      | `GetItemInfo()`, `GetItemInfoInstant()`, cache asynchrone, `GET_ITEM_INFO_RECEIVED` |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Resolve** itemID → name, icon, sellPrice
2. **Handle** the nil case (item not in cache yet)
3. **Retry** on `GET_ITEM_INFO_RECEIVED` event
4. **Display** readable item names instead of raw itemIDs

## Key Concepts

*(To be expanded during Phase C)*

## Execution

1. Copy to `Interface/AddOns/`
2. `/reload` in-game
3. `/cg item 2840` — show item info

## Expected Output

*(To be written during Phase A)*

## Common Pitfalls

*(To be populated during Phase B)*

## Going Further

- → Next capsule: **10 — AH Scanner**
