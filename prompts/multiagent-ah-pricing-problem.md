# Consultation — Problème du prix réel à l'Hôtel des Ventes et impact sur la roadmap

## Contexte

Je développe **CraftGold**, un add-on World of Warcraft Classic Era (Lua, pas de build). L'add-on poursuit **deux objectifs** :

1. **Monter un métier au moindre coût** — Calculer combien ça coûte de monter un métier (ex: Ingénierie) de 0 à 300 en achetant tous les composants à l'Hôtel des Ventes. Quel est le chemin optimal (quelles recettes crafter, dans quel ordre, pour dépenser le moins possible) ?

2. **Identifier les crafts rentables** — Une fois le métier monté, quels crafts sont rentables ? Achat de composants → fabrication → revente à l'Hôtel des Ventes.

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

## Problème 1 — Prix réel à l'Hôtel des Ventes

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

Ce problème impacte **les deux objectifs** de CraftGold :
- Pour le leveling planner : combien ça coûte *vraiment* d'acheter les 847 Copper Bars nécessaires pour monter Engineering de 0 à 150 ?
- Pour les crafts rentables : combien ça coûte *vraiment* de fabriquer ce Copper Modulator ?

## Problème 2 — Mécanique de montée de compétence

Pour le leveling planner (objectif 1), il faut aussi prendre en compte la **mécanique de gain de compétence** de WoW :

- **Orange** : 100% de chance de gagner un point de compétence
- **Jaune** : forte chance (≈75%) mais pas garantie
- **Vert** : faible chance (≈25%)
- **Gris** : 0% — aucun gain

Les seuils de couleur dépendent de la recette et du niveau de compétence actuel. Par exemple, une recette peut être orange de skill 30 à 60, jaune de 60 à 80, verte de 80 à 100, grise au-delà.

Ça signifie que le « chemin optimal » pour monter un métier n'est pas juste une question de prix des composants — c'est aussi une question de **probabilité de gain de compétence**. Il faut estimer combien de crafts d'une recette donnée seront nécessaires en moyenne pour passer d'un palier à l'autre, en fonction de la couleur.

Exemple concret :
- Recette A : composants coûtent 5s, orange → exactement 1 craft = 1 point
- Recette B : composants coûtent 2s, jaune → en moyenne 1.3 crafts pour 1 point → coût moyen par point = 2s × 1.3 = 2s60c

Recette B est moins chère par craft, mais pas forcément par point de compétence gagné.

## Mes questions

### Algorithmie

1. **Quel algorithme résout le problème des listings HdV ?** J'ai l'impression que c'est proche du problème du sac à dos (knapsack) ou du bin packing, mais je n'en suis pas sûr. Quelles sont les approches possibles ?
   - Le problème est-il NP-difficile dans le cas général ?
   - Existe-t-il des heuristiques simples qui donnent de bons résultats en pratique ?
   - Comment les add-ons WoW existants (Auctionator, TSM, etc.) gèrent-ils ça ?

2. **Quel algorithme pour le leveling planner ?** C'est un problème d'optimisation où :
   - On doit passer de skill 0 à skill N
   - Chaque recette a un coût en composants et une probabilité de gain (selon sa couleur à un skill donné)
   - L'objectif est de minimiser le coût total
   - Les deux problèmes sont liés : le coût des composants dépend des listings HdV (problème 1)

### Pédagogie

3. **Comment structurer ça en capsules pédagogiques ?** Chaque capsule doit être :
   - **Atomique** : un seul concept, testable indépendamment
   - **Progressive** : chaque capsule s'appuie sur la précédente
   - **Orientée données d'abord** : on apprend les widgets quand les données les rendent nécessaires

   Les capsules doivent amener progressivement vers la solution finale, en partant du modèle simpliste actuel (1 prix/item) vers le modèle réel (listings HdV, quantités, probabilités de skill-up, optimisation).

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

1. **Analyse des deux problèmes** : nature algorithmique, complexité, approches possibles, lien entre les deux
2. **Étude de ce que font les add-ons existants** (Auctionator, TSM, etc.) — avec sources
3. **Proposition de roadmap révisée** : nouvelles capsules à insérer, capsules existantes à modifier, ordre optimal. Les capsules liées aux deux objectifs (leveling planner + crafts rentables) doivent être clairement identifiées.
4. **Chaque nouvelle capsule doit être atomique et progressive** — pas de saut géant

## Format de réponse

Réponse en **markdown dans un seul bloc texte**. Pas de fichiers séparés, pas d'artifacts. Tout inline — code, exemples, liens.
