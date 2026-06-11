# 11 — Quote DP (Covering Knapsack)

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données réelles                                   |
| Prerequisites | Capsule 10 — Manual Listings                                |
| Type          | Autonomous                                                  |
| Concepts      | DP covering knapsack 0/1, `quote(itemID, quantity)`, reconstruction du panier, surplus |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Implémenter** la DP covering knapsack 0/1 exacte
2. **Retourner** le coût optimal + les stacks à acheter + le surplus
3. **Tester** avec des contre-exemples où le glouton se trompe

## Key Algorithm

```
dp[k] = coût minimum pour obtenir AU MOINS k unités
dp[0] = 0
Pour chaque listing (0/1) : dp[min(Q, k+count)] = min(dp[…], dp[k] + buyout)
Résultat : dp[need]
```

## Going Further

- → Capsule 12 : Bill of Materials (agrégation des besoins)
