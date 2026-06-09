# 09 — Item Info

| Metadata      | Value                                                              |
|---------------|--------------------------------------------------------------------|
| Phase         | Phase 4                                                            |
| Duration      | 30 min                                                             |
| Difficulty    | ●●●○○ (3/5)                                                       |
| Prerequisites | Capsule 03 — Saved Variables                                       |
| Type          | Semi-autonomous                                                    |
| Concepts      | `GetItemInfo()`, `GetItemInfoInstant()`, cache, item loading       |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Retrieve** item information (name, icon, rarity) using WoW's API
2. **Handle** the item cache (items may not be loaded immediately)
3. **Display** item details in the chat or a frame

## Key Concepts

*(To be expanded during Phase C)*

## Execution

1. Copy to `Interface/AddOns/`
2. `/reload` in-game (must be logged in with a character)
3. Type `/iteminfo 2589` (Linen Cloth) or any item ID

## Expected Output

```
[ItemInfo] Linen Cloth
  ID: 2589
  Rarity: Common (white)
  Stack size: 20
  Icon: Interface\Icons\INV_Fabric_Linen_01
```

## Common Pitfalls

*(To be populated during Phase B)*

## Going Further

- → Next capsule: **10 — Trade Skill API**
