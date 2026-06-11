# 16 — Profit Analyzer v2

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 5 — Produit MVP                                       |
| Prerequisites | Capsule 13 — Buy vs Craft v2, Capsule 15 — AH Scanner v2   |
| Type          | Semi-autonomous                                             |
| Concepts      | Prix marché (cheapest unit listing), commission HdV 5%, profit net, source tracking |

## Why This Capsule?

Jusqu'ici, on avait construit toutes les briques séparément : DB recettes, DP knapsack (Quote), scanner AH (Scanner), calculateur récursif (Calculator). Chaque pièce fonctionnait parfaitement de son côté.

Mais la question centrale restait sans réponse : **« Est-ce que je gagne de l'or en craftant ça ? »**

Le vieux `/cg analyze` utilisait `Prices.get()` — des prix manuels unitaires — pour le prix de vente ET comme fallback pour les coûts. C'était un prototype. La réalité, c'est :

- **Coût des mats** → exact via DP knapsack sur les listings réels (déjà en place depuis la capsule 13)
- **Prix de vente** → le marché, estimé depuis les listings HdV du craft lui-même

Cette capsule connecte les tuyaux. On scanne les composants ET les crafts, et `/cg analyze` dit quel craft est rentable — avec un profit calculé sur des données réelles, commission HdV incluse.

## Ce qu'on a appris

### Prix marché = cheapest unit listing

Pour estimer le prix de vente d'un craft, on ne peut pas utiliser `Quote.quote()` (qui optimise l'achat d'une quantité précise). On veut juste savoir : « si je pose un buyout à l'HdV, à quel prix puis-je espérer vendre ? »

La réponse : le **prix unitaire le plus bas** parmi les listings existants. C'est le prix marché — en dessous, on est le moins cher (vente rapide), au-dessus, on attend.

`Quote.marketPrice(itemID)` fait exactement ça :
1. Prend les listings de l'item
2. Calcule le prix unitaire de chaque listing (`buyout / count`)
3. Retourne le minimum
4. Fallback sur `Prices.get(itemID)` si pas de listings

Retourne aussi la source (`"ah"` ou `"manual"`) pour la transparence.

### Commission HdV = 5% côté serveur

L'HdV prélève 5% du prix de vente. Cette commission est calculée côté serveur — elle n'apparaît pas dans le code client Lua. C'est un fait bien connu et documenté.

Conséquence pour notre calcul :
```
netSell  = floor(sellPrice × 0.95)
ahCut    = sellPrice - netSell
profit   = netSell - craftCost
```

### Montants négatifs dans Money.format

Le bug rencontré en jeu : `Money.format(-7)` retournait `"—"` (em dash) au lieu de `"-7c"`. Les fonctions `format` et `formatColored` rejetaient les montants négatifs avec `copper < 0 → "—"`. 

Fix : prendre la valeur absolue, construire la chaîne normalement, et préfixer avec `"-"`.

### Les crafts bas niveau ne sont pas rentables

Résultat concret sur le serveur : Bombe grossière en cuivre (skill ~10) se vend exactement au prix des mats (1s30). Après la commission de 5%, c'est une **perte nette de 7c**. L'outil fait son job : il révèle que ce craft n'est pas rentable.

## Objectifs

1. **Estimer** le prix de vente d'un craft depuis ses listings (prix unitaire le plus bas) ✅
2. **Calculer** le profit réel = (prix de vente × 0.95) − coût exact DP ✅
3. **Afficher** le rapport de profit avec distinction coût (exact) vs prix de vente (estimé) ✅

## Changements par module

| Module | Changement |
|--------|-----------|
| **`Quote.lua`** | +`marketPrice(itemID)` → prix unitaire le plus bas (listings → fallback manual) |
| **`Calculator.lua`** | `analyze()` utilise `marketPrice()` au lieu de `Prices.get()`, applique 5% commission, expose `priceSource`/`netSell`/`ahCut` |
| **`Report.lua`** | `topCrafts()` affiche source `[AH]`/`[Manual]`, commission, profit net. `detail()` utilise `marketPrice()` |
| **`Money.lua`** | `format()` et `formatColored()` supportent les montants négatifs (`-7c` au lieu de `—`) |

## Commandes

| Commande | Description |
|----------|-------------|
| `/cg scan 2840; scan 2589; scan 2835; scan 4360` | Scanner composants + craft |
| `/cg analyze` | Top crafts rentables (profit net après commission) |
| `/cg analyze 5` | Top 5 seulement |
| `/cg detail 4360` | Rapport complet avec arbre buy vs craft + profit |

## Exemple de sortie

```
Top 1 craft(s) — profit after 5% AH commission:
  1. Bombe grossière en cuivre [AH] — Cost: 1s 30c — Sell: 1s 30c — Cut: 7c — Profit: -7c — Margin: -5%
```

→ L'outil dit « ne craft pas ça, tu perds 7c par craft ».

## Pitfalls rencontrés

### 1. Montants négatifs dans Money.format
`Money.format(-7)` retournait `"—"` au lieu de `"-7c"`. Les deux fonctions de formatage rejetaient les négatifs. **Solution** : valeur absolue + préfixe `"-"`.

### 2. Test busted existant qui échouait
Le test `Calculator.analyze()` vérifiait `profit = sellPrice - craftCost`. Après la refactorisation avec commission, c'est devenu `profit = netSell - craftCost`. **Solution** : mettre à jour le test pour vérifier `netSell`, `priceSource`, et la formule corrigée.

## Tests

- **166 tests busted** (0 failures)
  - +12 tests spécifiques Profit Analyzer v2 (marketPrice, analyze avec commission, source tracking)
- **46 tests in-game** (0 failures)
  - +11 tests in-game (marketPrice, analyze v2, commission, ahCut)

## Going Further

- → Capsule 17 : Profit Window (fenêtre UI pour afficher les résultats)
