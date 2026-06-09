# 11 — Auction House Scan

| Metadata      | Value                                                             |
|---------------|-------------------------------------------------------------------|
| Phase         | Phase 4                                                           |
| Duration      | 45 min                                                            |
| Difficulty    | ●●●●● (5/5)                                                      |
| Prerequisites | Capsule 10 — Trade Skill API                                      |
| Type          | Semi-autonomous                                                   |
| Concepts      | `C_AuctionHouse`, scan, callbacks, price table, throttling        |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Query** the Auction House for item prices using the WoW API
2. **Build** a price table: `{ itemID → minBuyout }`
3. **Handle** async callbacks and throttling limits
4. **Cache** prices for reuse between scans

## Key Concepts

*(To be expanded during Phase C)*

## Execution

1. Copy to `Interface/AddOns/`
2. `/reload` in-game
3. Go to the Auction House NPC, interact to open the AH window
4. Type `/ahscan item 2589` (Linen Cloth)

## Expected Output

```
[AHScan] Scanning for item: Linen Cloth (2589)...
[AHScan] Found 47 auctions
[AHScan] Min buyout: 2s 50c
[AHScan] Market average: 3s 12c
```

## Common Pitfalls

*(To be populated during Phase B)*

## Going Further

- → Next capsule: **12 — Cost Calculator**
