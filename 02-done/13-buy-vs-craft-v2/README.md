# 13 — Buy vs Craft v2

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données réelles                                   |
| Prerequisites | Capsule 12 — Bill of Materials                              |
| Type          | Autonomous                                                  |
| Concepts      | Calculateur récursif avec `quote(itemID, qty)`, surplus DP, CmdLang register merge |

## Why This Capsule?

Jusqu'ici, notre `Calculator` vivait dans un monde fictif : il suppose qu'on peut acheter n'importe quelle quantité d'un item à un prix unitaire fixé manuellement via `/cg price`. Ça marche pour explorer l'algorithme, mais c'est un mensonge économique.

Dans la vraie HdV, les stacks sont **indivisibles**. Si tu as besoin de 5 Copper Bar et que le seul stack dispo est 20 @ 10g, ça te coûte 10g, pas 5 × 2g. Depuis la capsule 11, `Quote.quote(itemID, qty)` sait calculer ce coût exact via DP knapsack.

Le problème : le `Calculator` et `Quote` vivaient côte à côte mais ne se parlaient pas. Le Calculator décidait "buy ou craft ?" avec des prix bidon, tandis que Quote calculait le vrai coût dans son coin.

**Cette capsule connecte les deux.** Le Calculator passe de "prix unitaire" à "coût réel via DP". C'est le moment où notre moteur économique passe de **simulation** à **réalité**.

## Objectives

1. **Refondre** le calculateur pour utiliser `quote(itemID, qty)` au lieu de `Prices.get(itemID)`
2. **Mettre à jour** `/cg analyze` et `/cg detail` avec les coûts exacts via DP
3. **Écrire** des tests busted couvrant le Calculator v2
4. **Corriger** le bug CmdLang : deux `register` du même nom s'écrasaient mutuellement

## Ce qu'on a fait

### Calculator v2

**Avant (capsule 07)** :
```
_calculate(itemID, state)
  buy = Prices.get(itemID)          -- prix unitaire fixe
  craft = sum(_calculate(reagentID, state) × count)
```

**Après (capsule 13)** :
```
_calculate(itemID, qty, state)
  buy = Quote.quote(itemID, qty)    -- DP knapsack exact
  fallback = Prices.get(itemID) × qty  -- si pas de listings
  craft = sum(_calculate(reagentID, reagentCount × qty, state))
```

Changements clés :
- `qty` propagé à travers la récursion (le coût dépend de la quantité)
- **Pas de cache** : le coût dépend de qty, un cache par itemID serait incorrect
- Résultat enrichi avec `surplus` quand buy via DP quote
- Fallback sur `Prices.get() × qty` quand aucun listing n'existe

### Bug CmdLang : register merge

**Bug découvert en jeu** : `/cg price 2589 100` → "price: unknown subcommand '2589'".

**Cause** : deux `cmd:register { name = "price", ... }` dans le shell — le deuxième écrase le premier. Le handler (set price) était perdu, seul le sous-arbre (list, remove) survivait.

**Fix** : `CmdLang:register()` merge maintenant les inscriptions successives du même nom (handler + args de l'une, subs de l'autre, fusionnés).

**Test** : 4 tests busted ajoutés pour les nœuds hybrides et le cas de double register.

### Report adapté

- `detail()` affiche le surplus quand buy via DP
- `_printTree()` montre le surplus par réagent
- `topCrafts()` affiche le surplus dans le classement

## Exemple en jeu

```
/cg reset
/cg listing add 2840 20 10000   -- 20 Copper Bar @ 1g
/cg listing add 2840 5 2500     -- 5 Copper Bar @ 25s
/cg listing add 2840 3 1200     -- 3 Copper Bar @ 12s
/cg price 2589 100              -- Linen Cloth @ 1s
/cg price 2835 50               -- Rough Stone @ 50c
/cg price 4360 5000             -- Rough Copper Bomb (sell price) @ 50s
/cg detail 4360
```

Résultat :
- Craft coûte **26s** (DP quote pour Copper Bar, fallback prices pour les autres)
- Sell price 50s → Profit **24s**, marge **92%**
- Surplus de 2 Copper Bar (stack de 3 acheté pour 1 nécessaire)

## Tests

- **124 tests busted** (0 failures) : 101 anciens + 19 Calculator v2 + 4 CmdLang hybrid
- **35 tests in-game** : Money, CmdLang, Listings, Quote DP, Calculator v2 (Prices + DP), BOM

## Fichiers modifiés

| Fichier | Changement |
|---------|-----------|
| `src/Calculator.lua` | Refonte complète : qty-aware, Quote DP, fallback Prices, surplus |
| `src/Report.lua` | Affichage surplus dans detail() et _printTree() |
| `src/CmdLang.lua` | register() merge les inscriptions du même nom |
| `ManualListings.lua` | Tests in-game Calculator v2, TOC mis à jour |
| `ManualListings.toc` | Title/Notes/Version capsule 13 |
| `tests/test_calculator_v2.lua` | 19 tests busted Calculator v2 |
| `tests/test_cmdlang.lua` | 4 tests nœuds hybrides + bug register |
| `tests/helpers.lua` | Calculator + Report ajoutés au DEFAULT_ORDER |

## Going Further

- → Capsule 14 : AH Scanner v1 — remplacer les listings manuels par des données réelles de l'HdV
