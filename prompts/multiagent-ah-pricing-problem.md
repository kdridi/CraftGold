# Consultation — Problème du prix réel à l'Hôtel des Ventes et impact sur la roadmap

## Contexte

Je développe **CraftGold**, un add-on World of Warcraft Classic Era (Lua, pas de build). Le but : aider les joueurs à identifier les crafts rentables (achat de composants → fabrication → revente à l'Hôtel des Ventes).

L'add-on est construit de manière **pédagogique**, en **capsules progressives** (mini-add-ons autonomes). J'en suis à la capsule 7.

## Ce qui existe aujourd'hui

### Modèle actuel des prix (simpliste)

Actuellement, chaque item a **un seul prix** :

```
/cg price 2840 12s40c     -- Copper Bar = 12s40c
/cg analyze
→ Copper Modulator — Coût: 43s40c — Profit: 28s60c
```

Le calculateur récursif fait `min(prixAchat, coûtCraft)` pour chaque composant. Ça marche pour un prototype, mais **ce modèle est faux** par rapport à la réalité de l'Hôtel des Ventes.

### Architecture existante

- **DB statique** de 26 recettes Engineering (skill 1-150), composants en itemID
- **Prix manuels** via `/cg price <itemID> <price>` (stockés en SavedVariables)
- **Calculateur récursif** : `min(buy, craft)` avec détection de cycles et mémoïsation
- **`/cg analyze`** : classe les crafts par profit

### API HdV disponible en Classic Era

- `QueryAuctionItems(text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)` — recherche par **nom uniquement**, pas par itemID
- `GetAuctionItemInfo("list", index)` → `buyoutPrice` (prix du stack), `count` (taille du stack), `itemId`, etc.
- Résultats paginés par 50, asynchrones via événement `AUCTION_ITEM_LIST_UPDATE`
- `buyoutPrice` est **par stack**, pas par unité

## Le problème

À l'Hôtel des Ventes, un même item peut avoir **plusieurs listings** à des prix et quantités différents :

```
Listing 1 : Copper Bar x1  — buyout: 1s       (1s/unité)
Listing 2 : Copper Bar x5  — buyout: 25s      (5s/unité)
Listing 3 : Copper Bar x20 — buyout: 2g       (10s/unité)
Listing 4 : Copper Bar x1  — buyout: 15s      (15s/unité)
```

Si j'ai besoin de **7 Copper Bars** :
- J'achète le listing 1 (1 bar à 1s) + le listing 2 (5 bars à 25s) + le listing 4 (1 bar à 15s) = **41s**
- OU j'achète le listing 3 (20 bars à 2g) = **2g** (mais j'ai 13 bars en trop)

Le prix « unitaire moyen » ou « prix le plus bas » ne reflète **jamais** le coût réel. Le coût réel dépend de **la quantité dont j'ai besoin**.

Ce problème se **propage** dans le calcul récursif : pour crafter un Copper Modulator, j'ai besoin de 2 Copper Bolts, qui nécessitent chacun 1 Copper Bar. Si j'ai aussi besoin de Copper Bars pour d'autres crafts, les achats se regroupent — c'est un problème d'**optimisation combinatoire**.

## Ma question

1. **Quel algorithme résout ce problème ?** J'ai l'impression que c'est proche du problème du sac à dos (knapsack) ou du bin packing, mais je n'en suis pas sûr. Quelles sont les approches possibles ?
   - Le problème est-il NP-difficile dans le cas général ?
   - Existe-t-il des heuristiques simples qui donnent de bons résultats en pratique ?
   - Comment les add-ons WoW existants (Auctionator, TSM, etc.) gèrent-ils ça ?

2. **Comment structurer ça en capsules pédagogiques ?** Chaque capsule doit être :
   - **Atomique** : un seul concept, testable indépendamment
   - **Progressive** : chaque capsule s'appuie sur la précédente
   - **Orientée données d'abord** : on apprend les widgets quand les données les rendent nécessaires

   Les capsules doivent amener progressivement vers la solution finale, en partant du modèle simpliste actuel (1 prix/item) vers le modèle réel (listings HdV, quantités, optimisation).

## Roadmap actuelle (ce qui reste à faire)

| # | Capsule | Concepts |
|---|---------|----------|
| 08 | Analyze & Report | `/cg analyze`, Top N crafts, affichage chat |
| 09 | Item Info | `GetItemInfo()`, cache asynchrone, noms lisibles |
| 10 | AH Scanner | `QueryAuctionItems`, pagination, throttling, prix par stack vs unité |
| 11 | Profit Window | Fenêtre CraftGold, Top 10 crafts, sélection |
| 12 | Scroll Frame | ScrollFrame, Slider — si la liste déborde |
| 13 | Leveling Planner | Plan 1→300 optimal, seuils, coût total |
| 14 | CraftGold v1 | DB complète, intégration Trade Skill UI, polish |

## Ce que j'attends

1. **Analyse du problème** : nature algorithmique, complexité, approches possibles
2. **Étude de ce que font les add-ons existants** (Auctionator, TSM, etc.) — avec sources
3. **Proposition de roadmap révisée** : nouvelles capsules à insérer, capsules existantes à modifier, ordre optimal
4. **Chaque nouvelle capsule doit être atomique et progressive** — pas de saut géant

## Format de réponse

Réponse en **markdown dans un seul bloc texte**. Pas de fichiers séparés, pas d'artifacts. Tout inline — code, exemples, liens.
