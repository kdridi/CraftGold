# 16 — Profit Analyzer v2

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 5 — Produit MVP                                       |
| Prerequisites | Capsule 13 — Buy vs Craft v2, Capsule 15 — AH Scanner v2   |
| Type          | Semi-autonomous                                             |
| Concepts      | Prix marché, commission HdV 5%, full scan getAll, DB complète |

## Why This Capsule?

Jusqu'ici, on avait construit toutes les briques séparément : DB recettes, DP knapsack (Quote), scanner AH (Scanner), calculateur récursif (Calculator). Chaque pièce fonctionnait parfaitement de son côté.

Mais la question centrale restait sans réponse : **« Est-ce que je gagne de l'or en craftant ça ? »**

Le vieux `/cg analyze` utilisait `Prices.get()` — des prix manuels unitaires — pour le prix de vente ET comme fallback pour les coûts. C'était un prototype. La réalité, c'est :

- **Coût des mats** → exact via DP knapsack sur les listings réels (déjà en place depuis la capsule 13)
- **Prix de vente** → le marché, estimé depuis les listings HdV du craft lui-même

Cette capsule connecte les tuyaux. Et elle ajoute une pièce manquante cruciale : le **full scan** de l'HdV, qui télécharge toutes les enchères d'un coup — fini le scan item par item avec ses 84 items failed.

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

### Full scan AH via `getAll = true`

L'ancienne API `QueryAuctionItems` a un 7e paramètre `getAll` qui télécharge **tout** l'HdV en une seule query asynchrone. Résultat validé en jeu : **60 549 enchères, 4 759 items distincts** en ~10 secondes.

**Fonctionnement** (consensus 4/4 LLM + code Auctionator) :
- `CanSendAuctionQuery()` retourne `(canQuery, canQueryAll)` — `canQueryAll` doit être `true`
- `QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)` — text vide + getAll = true
- Un seul `AUCTION_ITEM_LIST_UPDATE` avec toutes les données
- `GetNumAuctionItems("list")` retourne `(numBatch, total)` où `numBatch == total`
- Cooldown **15 minutes** par compte/royaume

**Pièges critiques** (validés par Auctionator en production) :
- **Anti-freeze** : traiter par batches de 250 via `C_Timer.After(0.01)` — sinon le client gèle
- **Anti-corruption** : désenregistrer les autres listeners de `AUCTION_ITEM_LIST_UPDATE` pendant le scan — sinon l'UI Blizzard essaye de render 60k items
- **`ITEM_QUALITY_COLORS[-1]`** : certaines enchères getAll ont `quality = -1`, ce qui crashe l'UI Blizzard. Patch défensif : `ITEM_QUALITY_COLORS[-1] = { r=0, g=0, b=0 }`
- `itemID`, `count`, `buyoutPrice` sont disponibles **immédiatement** dans `GetAuctionItemInfo` — pas besoin du cache item

### DB complète : 1 383 recettes

La DB est passée de 61 recettes (Engineering + quelques-unes d'autres professions) à **1 383 recettes** couvrant toutes les professions Vanilla :

| Profession | Recettes |
|-----------|----------|
| Blacksmithing | 331 |
| Leatherworking | 290 |
| Tailoring | 277 |
| Engineering | 181 |
| Alchemy | 136 |
| Cooking | 93 |
| Enchanting | 22 |
| Poisons | 26 |
| FirstAid | 14 |
| Mining | 13 |

Conversion automatisée depuis LibCrafts-1.0 (MIT) via un script Lua de parsing.

**Impact** : avec Mining dans la DB, les barres (Copper Bar, Bronze Bar, etc.) sont maintenant craftables. Le BOM descend plus profond (Copper Bar → Copper Ore). Les tests busted ont été adaptés.

## Changements par module

| Module | Changement |
|--------|-----------|
| **`FullScan.lua`** | **NOUVEAU** — Full scan via `getAll=true`, batches de 250, silencing listeners, cooldown 15min, injection dans Listings |
| **`Quote.lua`** | +`marketPrice(itemID)` → prix unitaire le plus bas (listings → fallback manual) |
| **`Calculator.lua`** | `analyze()` utilise `marketPrice()` au lieu de `Prices.get()`, applique 5% commission, expose `priceSource`/`netSell`/`ahCut` |
| **`Report.lua`** | `topCrafts()` affiche source `[AH]`/`[Manual]`, commission, profit net. `detail()` utilise `marketPrice()` |
| **`Money.lua`** | `format()` et `formatColored()` supportent les montants négatifs (`-7c` au lieu de `—`) |
| **`DB.lua`** | 61 → 1 383 recettes (toutes professions Vanilla, LibCrafts-1.0) |
| **`WoW.lua`** | +`GetFramesRegisteredForEvent`, +`C_Timer_After` dans la seam |

## Commandes

| Commande | Description |
|----------|-------------|
| `/cg fullscan` | Lancer un full scan de l'HdV (getAll, 15min cooldown) |
| `/cg fullscan status` | Âge du dernier scan, fraîcheur, nombre d'items en cache |
| `/cg analyze` | Top crafts rentables (profit net après commission) |
| `/cg analyze 5` | Top 5 seulement |
| `/cg detail 4360` | Rapport complet avec arbre buy vs craft + profit |

## Exemple de sortie (données réelles)

```
/cg fullscan
→ [FullScan] Starting full scan... (may take 10-30s)
→ [FullScan] Complete: 4759 items, 60549 auctions from 60674 total

/cg analyze
→ Top 20 craft(s) — profit after 5% AH commission:
→   1. Gilet en vignesang [AH] — Cost: 157g — Sell: 326g — Profit: +152g 48s — Margin: 97%
→   2. Sac sans fond [AH] — Cost: 89g — Sell: 236g — Profit: +134g 89s — Margin: 151%
→   3. Heaume Coeur-de-lion [AH] — Cost: 379g — Sell: 531g — Profit: +124g 89s — Margin: 33%
→   5. Sac en étoffe lunaire [AH] — Cost: 6g 58s — Sell: 16g 45s — Profit: +9g 4s — Margin: 137%
→   6. Étoffe lunaire [AH] — Cost: 4g — Sell: 13g — Profit: +8g 32s — Margin: 208%
```

## Pitfalls rencontrés

### 1. Montants négatifs dans Money.format
`Money.format(-7)` retournait `"—"` au lieu de `"-7c"`. Les deux fonctions de formatage rejetaient les négatifs. **Solution** : valeur absolue + préfixe `"-"`.

### 2. Scan item par item : 84/130 items failed
L'approche `analyze scan` (scan AH item par item après preload) échouait sur 84 items car `GetItemInfo` retournait nil. Le preload via `Item:ContinueOnItemLoad` ne marchait pas non plus. **Solution** : abandon de l'approche item par item, passage au full scan `getAll=true` qui récupère tout d'un coup.

### 3. Anti-freeze indispensable
Traiter 60 000 `GetAuctionItemInfo` dans une seule frame gèle le client plusieurs secondes. **Solution** : batches de 250 avec `C_Timer.After(0.01)` entre chaque (pattern Auctionator).

### 4. Silencing des listeners Blizzard
L'UI Blizzard écoute `AUCTION_ITEM_LIST_UPDATE` et essaye de render la liste. Avec 60k résultats → crash. **Solution** : `GetFramesRegisteredForEvent` → `UnregisterEvent` → traiter → `RegisterEvent` (pattern Auctionator).

### 5. `ITEM_QUALITY_COLORS[-1]`
Certaines enchères getAll ont `quality = -1` qui crashe `Blizzard_AuctionUI`. **Solution** : patch défensif `ITEM_QUALITY_COLORS[-1] = { r=0, g=0, b=0 }` avant le scan.

### 6. DB complète → barres craftables
Avec Mining dans la DB, Copper Bar (2840) est maintenant craftable depuis Copper Ore (2770). Le BOM descend plus profond. Les tests busted référençant 2840 comme "non-craftable" ont dû être adaptés.

## Tests

- **166 tests busted** (0 failures)
- **46 tests in-game** (0 failures)
- Tests BOM adaptés pour la DB complète (Copper Ore au lieu de Copper Bar)

## Going Further

- → Capsule 17 : Profit Window (fenêtre UI pour afficher les résultats)
