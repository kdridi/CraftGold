# 07 — Price & Calculator

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 3 — Cœur métier                                       |
| Duration      | 1h                                                          |
| Difficulty    | ●●●●○ (4/5)                                                |
| Prerequisites | Capsule 06 — Recipe DB                                      |
| Type          | Autonomous                                                  |
| Concepts      | Money formatting, manual prices via slash, recursive cost calculator, min(buy, craft), cycle detection, memoization |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Parse & format** money amounts (gold/silver/copper)
2. **Enter prices manually** via `/cg price <itemID> <price>`
3. **Store prices** in SavedVariables
4. **Implement** recursive cost calculator: `min(buyPrice, craftCost)`
5. **Detect cycles** in the recipe graph
6. **Memoize** results for performance

## Key Concepts

*(To be expanded during Phase C)*

## Execution

1. Copy to `Interface/AddOns/`
2. `/reload` in-game
3. `/cg price 2840 12s40c` — set a price
4. `/cg analyze` — see profitable crafts

## Expected Output

```
/cg analyze
CraftGold — Top 3 profitable crafts:
  Copper Modulator — Cost: 41s20c — Sell: 72s — Profit: 30s80c — Margin: 74%
    → Craft Handful of Copper Bolts (12s40c) instead of buying (18s)
  Rough Copper Bomb — Cost: 18s40c — Sell: 24s70c — Profit: 6s30c — Margin: 34%
```

## Common Pitfalls

*(To be populated during Phase B)*

## Going Further

- → Next capsule: **08 — Analyze & Report**
