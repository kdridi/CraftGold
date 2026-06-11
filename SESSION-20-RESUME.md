# Session 20 — Reprise

## État du projet

CraftGold = add-on WoW Classic Era (1.15.x) qui calcule les profits des crafts.

- **17 capsules terminées** (00-16), **5 restantes** (17-21)
- **61 recettes** en DB (Engineering 1-300, Alchemy, Blacksmithing, Leatherworking, Tailoring, Enchanting, Cooking)
- **166 tests busted, 0 failures**
- Code dans `01-wip/16-profit-analyzer-v2/`

## Ce qu'on a fait cette session

### Capsule 16 — Profit Analyzer v2 (complétée)
- `Quote.marketPrice(itemID)` : prix unitaire le plus bas depuis les listings
- Commission HdV 5% appliquée au profit
- Source tracking `[AH]`/`[Manual]` dans le rapport
- Bug `Money.format` montants négatifs corrigé
- Bug listings non injectés dans `analyze scan` corrigé
- Bug vieux listings polluants → `Listings.clear()` avant chaque `analyze scan`
- Commit : `beaa6c0`

### Extension — `/cg analyze scan` (batch scan automatique)
- Collecte tous les itemIDs (crafts + mats via BOM.expand)
- Queue les scans AH en séquence, analyse à la fin
- **Bug découvert** : le callback `analyze scan` n'injectait pas les résultats dans Listings → fix
- **Résultat** : trouvé Espingole grossière (+1s87, marge 33%) et Tube en bronze (+1s20, marge 14%)

### Extension — DB multi-professions (61 recettes)
- Prompt de recherche des crafts les plus rentables → 4 LLM consultés, top croisé
- **Sources** : `prompts/research-capsule-16-top-profitable-engineering-response-*.md`
- Ajouté 35 recettes (Alchemy, Blacksmithing, Leatherworking, Tailoring, Enchanting) via LibCrafts-1.0 (MIT, cloné dans `/tmp/LibCrafts-1.0/`)
- Résultat : **130 items à scanner, 84 failed** (items pas dans le cache client)

### Problème actuel — Preload items
- `GetItemInfo(itemID)` retourne `nil` pour les items jamais rencontrés en jeu → le scanner AH ne peut pas obtenir le nom pour lancer `QueryAuctionItems`
- **Recherche** : `prompts/research-capsule-16-item-preload.md` + 4 réponses dans `prompts/research-capsule-16-item-preload-response-*.md`
- **Consensus 4/4** : `Item:CreateFromItemID(id):ContinueOnItemLoad(cb)` + timeout
- **Implémenté** : `src/ItemPreloader.lua` intégré dans `analyze scan`
- **Mais** : après `/reload`, les logs montrent l'ancien code (pas de message "Preloading") → le `.toc` est à jour mais le reload n'a pas chargé le nouveau fichier → **à investiguer**

## Fichiers modifiés cette session

| Fichier | Changement |
|---------|-----------|
| `src/Quote.lua` | +`marketPrice(itemID)` |
| `src/Calculator.lua` | `analyze()` avec commission 5% + source tracking |
| `src/Report.lua` | Affichage net profit, source, top 5 des moins pires |
| `src/Money.lua` | `format()`/`formatColored()` supportent les négatifs |
| `src/DB.lua` | 61 recettes (6 professions) |
| `src/ItemPreloader.lua` | **NOUVEAU** — batch preload via ContinueOnItemLoad |
| `src/Scanner.lua` | Tentative RequestLoadItemDataByID avant scan |
| `src/WoW.lua` | +`RequestLoadItemDataByID` dans la seam |
| `ManualListings.lua` | `/cg analyze scan` avec preload + clear + injection |
| `ManualListings.toc` | +`ItemPreloader.lua` |
| `tests/test_profit_analyzer.lua` | +12 tests marketPrice + analyze v2 |

## À faire immédiatement

1. **Debugger le preload** : pourquoi ItemPreloader n'est pas chargé après `/reload` ? Vérifier que le fichier est accessible via le symlink
2. **Tester `analyze scan`** avec le preload fonctionnel → vérifier que les 130 items se chargent
3. **Commit** la capsule 16 une fois le preload fonctionnel
