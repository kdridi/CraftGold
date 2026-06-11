# 08 — Analyze & Report

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 3 — Cœur métier                                       |
| Prerequisites | Capsule 07 — Price & Calculator                             |
| Type          | Autonomous                                                  |
| Concepts      | `/cg analyze`, Top N crafts rentables, affichage chat, détail recette avec arbre de décision buy vs craft |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Afficher** le top N des crafts rentables dans le chat
2. **Détailler** chaque craft : coût, prix de vente, profit, marge
3. **Montrer** les conseils buy vs craft pour les composants intermédiaires

## Execution

1. Copy to `Interface/AddOns/`
2. `/reload` in-game
3. Set prices with `/cg price`
4. `/cg analyze` — see profitable crafts

## Expected Output

```
/cg analyze
CraftGold — Top 3 profitable crafts:
  1. Copper Modulator — Cost: 43s40c — Sell: 72s — Profit: 28s60c — Margin: 66%
    → Craft Handful of Copper Bolts (12s40c) instead of buying (18s)
```

## Going Further

- → Capsule 09 : Item Info (noms lisibles au lieu de `item:XXXX`)
