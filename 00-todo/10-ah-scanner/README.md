# 10 — AH Scanner

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données du jeu                                    |
| Duration      | 1h                                                          |
| Difficulty    | ●●●●● (5/5)                                                |
| Prerequisites | Capsule 09 — Item Info                                      |
| Type          | Semi-autonomous                                              |
| Concepts      | `QueryAuctionItems`, `GetAuctionItemInfo`, `AUCTION_ITEM_LIST_UPDATE`, pagination, throttling, buyout per stack vs unit |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Scan** AH for targeted items from the recipe DB
2. **Extract** minimum buyout price per unit for each item
3. **Store** prices with timestamp in SavedVariables
4. **Handle** pagination and throttling

## Key Concepts

*(To be expanded during Phase C)*

## Execution

1. Open AH in-game
2. `/cg scan` — start targeted scan
3. Wait for completion
4. `/cg prices` — show scanned prices

## Expected Output

*(To be written during Phase A)*

## Common Pitfalls

*(To be populated during Phase B)*

## Going Further

- → Next capsule: **11 — Profit Window**
