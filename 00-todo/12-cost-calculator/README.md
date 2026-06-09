# 12 — Cost Calculator

| Metadata      | Value                                                                         |
|---------------|-------------------------------------------------------------------------------|
| Phase         | Phase 5                                                                       |
| Duration      | 60 min                                                                        |
| Difficulty    | ●●●●● (5/5)                                                                  |
| Prerequisites | Capsule 10 — Trade Skill API, Capsule 11 — Auction House Scan                 |
| Type          | Sequential                                                                    |
| Concepts      | Recipe graph, recursive cost, `min(buy, craft)`, cycle detection, memoization |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Model** the crafting tree as a directed graph
2. **Implement** the recursive cost function: `cost(item) = min(AH price, sum(cost(reagents)))`
3. **Detect** cycles to prevent infinite recursion
4. **Cache** results for performance (memoization)
5. **Calculate** profit = sell price − real cost

## Key Concepts

*(To be expanded during Phase C)*

## Execution

1. Copy to `Interface/AddOns/`
2. `/reload` in-game
3. Type `/craftcalc 4364` (compare buying vs crafting a specific item)

## Expected Output

```
[CraftCalc] Bright Baubles
  Direct AH buy: 12s 50c
  Craft cost breakdown:
    Handful of Copper Bolts: 3s (cheaper to BUY on AH)
    Copper Bar × 3: 1s 80c each (total: 5s 40c)
    ...
  Real craft cost: 9s 30c
  → CRAFT is cheaper! Save 3s 20c per unit
  → Profit at current AH sell price: 8s 70c
```

## Common Pitfalls

*(To be populated during Phase B)*

## Going Further

- → Next capsule: **13 — CraftGold Final**
