# 10 — Manual Listings

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données réelles                                   |
| Prerequisites | Capsule 07 — Price & Calculator                             |
| Type          | Autonomous                                                  |
| Concepts      | Remplacer `price[item]` par `listings[item] = {{count, buyout}, …}`, saisie manuelle via slash command, prix par stack vs unité |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Changer** le modèle de données : un item n'a plus un prix, il a des listings
2. **Saisir** des listings manuellement : `/cg listing add 2840 5 25s` (5 Copper Bars à 25s le stack)
3. **Préparer** le terrain pour la DP de la capsule 11

## Key Insight

Un listing HdV est un **stack indivisible** : on achète tout ou rien. Le prix est par stack, pas par unité.

## Going Further

- → Capsule 11 : Quote DP (algorithme optimal pour choisir les stacks)
