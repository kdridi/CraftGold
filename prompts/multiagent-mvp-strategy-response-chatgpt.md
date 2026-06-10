# Consultation multi-agents — Stratégie MVP CraftGold

## Verdict direct

Ta roadmap actuelle est **pédagogiquement cohérente**, mais **produit/MVP trop orientée widgets**. La prochaine capsule ne devrait pas être “Scroll Frame” en tant que widget isolé. La prochaine étape devrait être : **faire apparaître une première décision économique utile**, même moche, même en chat, même avec 10 recettes statiques.

Les add-ons existants confirment que le vrai cœur de valeur est : **prix AH → coût des réactifs → valeur du craft → profit**. Auctionator met en avant les prix AH, le scan, les coûts de réactifs et les profits dans les vues de craft ; TSM définit explicitement le profit comme `valeur de l’objet crafté - coût des matériaux` ; LilSparky’s Workshop faisait déjà exactement l’idée “cost/value/profit dans la fenêtre métier”. ([GitHub][1]) ([TradeSkillMaster Support][2]) ([wowace.com][3])

---

## 0. Les trois angles de décision

### Expert joueur / gold maker

Le joueur ne veut pas “ouvrir une belle UI”. Il veut répondre à deux questions :

```text
1. Avec les prix actuels de mon serveur, qu’est-ce que je peux crafter avec profit ?
2. Pour une recette donnée, dois-je acheter les composants ou fabriquer les sous-composants ?
```

Donc le premier workflow doit partir de l’**HdV**, car sans prix récents, CraftGold ne peut pas produire de décision fiable. TSM indique d’ailleurs que la cause la plus fréquente des coûts/profits manquants est l’absence de données de prix. ([TradeSkillMaster Support][4])

### Expert API WoW Classic

En Classic Era, le MVP doit être bâti sur le flux legacy AH : `AUCTION_HOUSE_SHOW`, `CanSendAuctionQuery()`, `QueryAuctionItems()`, `AUCTION_ITEM_LIST_UPDATE`, `GetNumAuctionItems()`, `GetAuctionItemInfo()`. `QueryAuctionItems()` est listé comme API legacy ajoutée en Classic, `AUCTION_ITEM_LIST_UPDATE` existe en Classic Era, et `GetAuctionItemInfo()` retourne notamment `count`, `buyoutPrice`, `itemId` et `hasAllInfo`. ([warcraft.wiki.gg][5]) ([warcraft.wiki.gg][6]) ([warcraft.wiki.gg][7]) ([warcraft.wiki.gg][8])

### Expert pédagogie / architecture

Tu as déjà assez de widgets pour prouver la valeur. Tu peux afficher un **Top 10** avec `FontString` fixes, boutons, slash commands et SavedVariables. Une vraie scroll frame deviendra utile dès que tu veux afficher 30, 100 ou 300 lignes, mais ce n’est pas le prochain risque technique. Le prochain risque technique, c’est : **prix incomplets, item cache asynchrone, recettes incomplètes, calcul récursif faux**. `GetItemInfo()` / `C_Item.GetItemInfo()` peuvent retourner `nil` si l’item n’est pas encore en cache, et `GET_ITEM_INFO_RECEIVED` existe précisément pour le retour d’information d’un item non caché. ([warcraft.wiki.gg][9]) ([warcraft.wiki.gg][10]) ([warcraft.wiki.gg][11])

---

# Q1 — Workflow joueur minimal

## Workflow MVP recommandé : “Je suis à l’HdV → je vois quoi crafter”

Le workflow le plus court vers la valeur est :

```text
1. Le joueur ouvre l’Hôtel des ventes.
2. CraftGold affiche un petit panneau : [Scan prices] [Analyze].
3. CraftGold scanne uniquement les items utiles à sa DB de recettes.
4. CraftGold stocke les prix unitaires en SavedVariables.
5. CraftGold calcule les coûts récursifs.
6. CraftGold affiche les crafts les plus rentables.
7. Le joueur clique une recette pour voir le détail : acheter ou fabriquer chaque composant.
```

Pourquoi commencer par l’HdV ? Parce que l’HdV est le point où tu peux récupérer la donnée qui manque le plus : le prix courant des matériaux et des outputs. Auctionator met justement en avant le scan AH pour mettre à jour les prix, les prix dans les tooltips et les profits/coûts de recettes dans les vues de craft. ([GitHub][1])

## Workflow secondaire : “J’ouvre mon métier → je vois les coûts par recette”

Ce workflow est excellent, mais je le mettrais **en deuxième** :

```text
1. Le joueur ouvre sa fenêtre de métier.
2. CraftGold détecte les recettes apprises.
3. CraftGold affiche à côté de chaque recette :
   coût mats, prix revente, profit, marge, données manquantes.
```

C’est validé par les add-ons existants : LilSparky’s Workshop ajoutait des informations de coût et valeur directement dans la fenêtre métier, et Auctionator annonce aussi les coûts de réactifs/profits dans les vues de craft. ([wowace.com][3]) ([GitHub][1])

Mais attention : les API métier ne suffisent pas pour planifier tout le leveling. `C_TradeSkillUI.GetAllRecipeIDs()` retourne les recettes du métier courant, et plusieurs add-ons de suivi de recettes expliquent qu’il faut ouvrir la fenêtre de métier pour construire/rafraîchir leur base interne. ([warcraft.wiki.gg][12]) ([curseforge.com][13])

## Workflow leveling : à repousser après le MVP gold

Le leveling 1–300 est plus ambitieux que le profit immédiat, parce qu’il nécessite les seuils orange/jaune/vert/gris, le nombre attendu de crafts, les recettes apprises/non apprises, les sources trainer/vendor/drop, et les coûts de toutes les alternatives. Les recettes orange donnent un skill-up garanti, les jaunes environ 60%, les vertes rarement, les grises jamais ; c’est un vrai problème d’optimisation probabiliste, pas juste un affichage. ([Wowpedia][14]) ([warcraft.wiki.gg][15])

---

# Q2 — Données à afficher concrètement

## Écran 1 — Panneau HdV / scan des prix

Objectif : rendre visible l’état de la donnée.

```text
+------------------------------------------------------------+
| CraftGold — Auction Prices                                 |
| [Scan relevant items] [Analyze crafts] [Clear old prices]  |
|                                                            |
| Last scan: 2026-06-10 17:42     Items: 48/73 priced        |
|                                                            |
| Item                    Source   Unit price   Seen   Age   |
| Copper Bar              AH       12s 40c      532    2m    |
| Linen Cloth             AH       03s 10c      884    2m    |
| Handful of Copper Bolts  AH       18s 00c      27     3m    |
| Rough Stone             AH       01s 20c      210    3m    |
| Weak Flux               Vendor   01s 00c      -      static|
| Silver Bar              Missing  -            0      -     |
+------------------------------------------------------------+
```

Colonnes minimales :

| Colonne         | Pourquoi                                             |
| --------------- | ---------------------------------------------------- |
| `item`          | Nom lisible, mais stockage interne en `itemID`.      |
| `source`        | `AH`, `vendor`, `manual`, `craft`, `missing`.        |
| `unit price`    | Prix normalisé par unité, car les stacks AH varient. |
| `seen quantity` | Donne une idée de liquidité brute.                   |
| `age`           | Un prix AH périmé doit être visible.                 |

La collecte AH doit normaliser `buyoutPrice / count`, car `GetAuctionItemInfo()` retourne à la fois le nombre d’items dans le lot et le prix buyout total de l’enchère. ([warcraft.wiki.gg][7])

## Écran 2 — Liste des crafts rentables

Objectif : donner une décision immédiate.

```text
+--------------------------------------------------------------------------+
| CraftGold — Profitable Crafts                                            |
| Filter: Engineering  Sort: Profit desc        Missing prices hidden [x]   |
|                                                                          |
| Craft                  Cost       Sell net   Profit    Margin   Status   |
| Copper Modulator        41s 20c    72s 00c    30s 80c   74%      OK       |
| Rough Copper Bomb x2     18s 40c    24s 70c    06s 30c   34%      OK       |
| Coarse Blasting Powder   01s 10c    01s 80c    00s 70c   63%      Thin     |
| Silver Contact           ?          09s 00c    ?         ?        Missing  |
+--------------------------------------------------------------------------+
```

Colonnes minimales :

| Colonne    | Définition                                           |
| ---------- | ---------------------------------------------------- |
| `Craft`    | Output + quantité produite.                          |
| `Cost`     | Coût récursif minimal des matériaux.                 |
| `Sell net` | Prix revente après cut AH, pas le prix brut.         |
| `Profit`   | `sell net - cost`.                                   |
| `Margin`   | `profit / cost`.                                     |
| `Status`   | `OK`, `Missing price`, `Low quantity`, `Stale data`. |

TSM formalise exactement cette logique : le coût de craft est la somme des coûts des matériaux, et le profit est la valeur de l’objet crafté moins le coût de craft. ([TradeSkillMaster Support][2]) ([TradeSkillMaster Support][16])

Pour le prix net, il faut intégrer au moins le cut AH. Les maisons de faction prennent 5% du prix de vente ; les AH neutres prennent 15%. Le dépôt est remboursé si l’objet se vend, mais perdu si l’enchère expire ou est annulée, donc pour le MVP tu peux l’ignorer ou l’afficher comme “risk”. ([Wowhead][17]) ([warcraft.wiki.gg][18])

## Écran 3 — Détail d’une recette

Objectif : montrer la valeur unique de CraftGold : **acheter vs fabriquer les sous-composants**.

Exemple avec Engineering :

```text
+------------------------------------------------------------+
| Copper Modulator                                           |
| Output: 1x Copper Modulator                                |
| Sell gross: 75s 79c       Sell net: 72s 00c                |
| Craft cost: 41s 20c       Profit: 30s 80c                  |
|                                                            |
| Cost path                                                  |
| - 2x Handful of Copper Bolts                               |
|     AH:    18s 00c each = 36s 00c                          |
|     Craft: 1x Copper Bar each = 24s 80c total   <- chosen  |
| - 1x Copper Bar                                            |
|     AH: 12s 40c                                  <- chosen |
| - 2x Linen Cloth                                           |
|     AH: 03s 10c each = 06s 20c                  <- chosen  |
|                                                            |
| Missing: none                                              |
+------------------------------------------------------------+
```

Ce type de détail est exactement ce que ton calcul récursif doit prouver. Exemple concret vérifié : `Copper Modulator` utilise `2x Handful of Copper Bolts`, `1x Copper Bar`, `2x Linen Cloth`, et `Handful of Copper Bolts` se craft avec `1x Copper Bar`, ce qui donne un très bon fixture pour tester la récursion. ([Wowhead][19]) ([Wowhead][20])

## Écran 4 — Plan de leveling, mais pas MVP initial

Quand tu l’ajoutes, le wireframe utile est :

```text
+--------------------------------------------------------------------------------+
| CraftGold — Leveling Plan: Engineering 1 -> 150                                 |
|                                                                                |
| Skill     Recipe                     Expected crafts   Cost       Notes         |
| 1-30      Rough Blasting Powder       30                36s        Trainer       |
| 30-45     Handful of Copper Bolts     20                2g48s      Save for later|
| 45-75     Rough Copper Bomb           30                5g52s      Uses bolts    |
| 75-90     Coarse Blasting Powder      60                1g20s      Save for later|
+--------------------------------------------------------------------------------+
```

Mais ce module doit attendre. Les guides de professions Classic existent déjà parce que le problème dépend des seuils de couleur et des choix économiques de matériaux ; les pages Wowhead indiquent les niveaux où les recettes changent de couleur, et quand une recette n’est plus orange il faut comparer économiquement les recettes jaunes. ([Wowhead][21])

---

# Q3 — Widgets vraiment nécessaires

## Pour le MVP : ce que tu sais déjà faire suffit presque

Tu peux faire un MVP utile avec :

```text
- une Frame principale
- des FontString fixes
- 2 ou 3 Buttons
- slash commands
- SavedVariables
- une petite table de lignes réutilisables
```

Tu n’as pas besoin de minimap button, options panel, onglets, dropdowns, templates complexes, ni d’une scroll frame pour prouver la valeur.

## Mais une liste scrollable deviendra vite nécessaire

Dès que tu affiches plus de 10–15 crafts, une scroll frame devient justifiée. Les widgets WoW sont créés via `CreateFrame()` ou XML, et les scroll frames servent à faire défiler des widgets/contenus ; les `FauxScrollFrame` / `HybridScrollFrame` sont historiquement utilisés pour donner l’impression d’une longue liste sans créer tous les widgets hors écran. ([warcraft.wiki.gg][22]) ([warcraft.wiki.gg][23]) ([warcraft.wiki.gg][24]) ([Wowpedia][25])

Donc je changerais la capsule 06 :

```text
Ancien :
06 — Scroll Frame

Nouveau :
06 — Results List MVP
- affiche Top 10 crafts rentables avec FontString fixes
- pas de scroll au début
- structure déjà compatible avec row recycling
- scroll frame seulement quand la donnée dépasse l’écran
```

Autrement dit : **n’apprends pas ScrollFrame pour apprendre ScrollFrame**. Construis d’abord une liste de résultats. Quand elle déborde, tu as une raison réelle d’introduire une scroll frame.

---

# Q4 — Ordre de développement optimal

## Roadmap réordonnée

### Phase A — Noyau économique hors WoW

```text
06 — Recipe DB Mini + Cost Model
```

Contenu :

```lua
CraftGoldDB = {
  recipes = {
    [4363] = { -- Copper Modulator, exemple
      outputItemID = 4363,
      outputQty = 1,
      profession = "Engineering",
      skill = 65,
      reagents = {
        { itemID = 4359, qty = 2 }, -- Handful of Copper Bolts
        { itemID = 2840, qty = 1 }, -- Copper Bar
        { itemID = 2589, qty = 2 }, -- Linen Cloth
      },
    },
    [4359] = {
      outputItemID = 4359,
      outputQty = 1,
      profession = "Engineering",
      skill = 30,
      reagents = {
        { itemID = 2840, qty = 1 },
      },
    },
  }
}
```

Pourquoi d’abord ? Parce que ton avantage produit est le calcul récursif. Les bibliothèques/add-ons de données métiers existants confirment qu’une DB ID-based de recettes, reagents, outputs et sources est une approche réaliste pour WoW Classic/Vanilla. ([GitHub][26]) ([GitHub][27]) ([curseforge.com][28])

### Phase B — PriceStore manuel

```text
07 — Manual Prices + Recursive Cost Calculator
```

Avant même de scanner l’HdV, ajoute :

```text
/cg price 2840 12s40c
/cg price 2589 3s10c
/cg analyze
/cg detail 4363
```

Ça te permet de tester :

```text
- prix par itemID
- conversion copper/silver/gold
- coût récursif
- choix min(acheter, fabriquer)
- memoization
- cycle detection
- données manquantes
```

C’est le chemin le plus court vers une preuve métier.

### Phase C — ItemInfo cache

```text
08 — ItemInfo Cache
```

Tu ajoutes la résolution `itemID -> name/link/icon/vendorSell`. Ne bloque jamais le calcul sur le nom : si `GetItemInfo()` retourne `nil`, affiche `item:2840` puis rafraîchis quand `GET_ITEM_INFO_RECEIVED` arrive. `C_Item.GetItemInfo()` peut retourner `nil` si l’item n’est pas caché, et l’événement `GET_ITEM_INFO_RECEIVED` signale le retour d’une requête item non cachée. ([warcraft.wiki.gg][10]) ([warcraft.wiki.gg][11])

### Phase D — Scan AH ciblé

```text
09 — Targeted AH Scanner
```

Ne commence pas par un full scan. Fais d’abord un scan ciblé des itemIDs présents dans ta DB :

```text
for each itemID in neededItems:
  name = GetItemInfo(itemID)
  QueryAuctionItems(name, nil, nil, page, nil, nil, false, true)
  wait AUCTION_ITEM_LIST_UPDATE
  for each auction row:
    read GetAuctionItemInfo("list", i)
    if returned itemId == wantedItemID:
       unit = buyoutPrice / count
       keep min unit buyout + quantity seen
```

`QueryAuctionItems()` prend un nom/texte, une page qui commence à 0 et un booléen `exactMatch`; `CanSendAuctionQuery()` doit être utilisé pour savoir si une requête peut être envoyée. Le mode `getAll` télécharge l’HdV entier, mais il est fortement throttlé, historiquement autour de 15 minutes, donc il est plus risqué comme première implémentation. ([AddOn Studio][29])

### Phase E — Petit panneau de résultats

```text
10 — Profit Panel
```

Affiche :

```text
- Top 10 crafts
- bouton Scan
- bouton Analyze
- détail recette sélectionnée
```

Là seulement, si tu as trop de résultats, tu transformes la liste en scroll frame.

### Phase F — Intégration métier

```text
11 — Profession Window Integration
```

Tu peux ensuite lire les recettes apprises / disponibles quand la fenêtre métier est ouverte, et enrichir l’affichage. Les add-ons de recettes confirment que l’ouverture de la fenêtre de métier est souvent nécessaire pour construire la base côté personnage. ([curseforge.com][13])

### Phase G — Leveling optimizer

```text
12 — Leveling Plan 1-300
```

À faire après le profit MVP, car c’est un problème plus vaste.

---

# Q5 — MVP scope

## Le plus petit MVP qui démontre vraiment CraftGold

Je ferais ce MVP :

```text
CraftGold MVP v0.1 — “Top profitable crafts from current AH prices”
```

### Inclus

```text
1. Une DB statique limitée à 1 profession
2. 20 à 50 recettes max
3. Stockage itemID
4. Prix manuels via slash command
5. Scan AH ciblé des items nécessaires
6. PriceStore SavedVariables avec timestamp
7. Calcul récursif min(acheter, fabriquer)
8. Top 10 crafts rentables
9. Détail d’une recette
10. Gestion claire des prix manquants
```

### Non inclus

```text
- Pas de leveling 1-300 complet
- Pas de toutes les professions
- Pas de scan complet de l’HdV
- Pas de statistiques historiques avancées
- Pas de prédiction de vitesse de vente
- Pas de minimap button
- Pas d’options panel complet
- Pas de tabs
- Pas de craft queue
- Pas d’achat automatique
- Pas de posting/undercut/cancel automatique
- Pas d’intégration TSM/Auctionator au début
```

Le stockage compact est important : aux, un addon AH Vanilla, explique qu’il condense les prix scannés par jour et prend ensuite une médiane sur plusieurs jours pour limiter l’usage mémoire, plutôt que de stocker chaque scan brut indéfiniment. ([GitHub][30])

---

# Roadmap corrigée proposée

```text
Phase 1 — Bases WoW                         ✅ fait
01 Hello Azeroth
02 Slash Commands
03 Saved Variables

Phase 2 — UI minimale                       ✅ partiel
04 Frame
05 Buttons & Text

Phase 3 — MVP économique visible             ⬅️ maintenant
06 Recipe DB Mini
07 Manual PriceStore
08 Recursive CostCalculator
09 ItemInfo Cache
10 Profit Report UI

Phase 4 — Données réelles WoW
11 Targeted AH Scanner
12 Profession Window Reader

Phase 5 — UI de liste réelle
13 Results List / ScrollFrame
14 Recipe Detail Panel

Phase 6 — Produit CraftGold v1
15 Leveling Planner 1-150
16 Leveling Planner 1-300
17 Options / Minimap / polish
```

Je déplacerais donc :

```text
Minimap      -> très tard
Options      -> tard, slash commands suffisent
ScrollFrame  -> après vraie liste de résultats
TradeSkill   -> après CostCalculator
AuctionHouse -> après PriceStore manuel + ItemInfo cache
Leveling     -> après profit MVP
```

---

# Exemple de découpage pédagogique des prochaines capsules

## Capsule 06 — Static Recipe DB

Objectif : représenter les recettes en Lua pur.

```text
Livrable :
- CraftGoldDB.lua
- 10 recettes Engineering
- itemID partout
- tests busted : lookup recipe by outputItemID
```

## Capsule 07 — Money & PriceStore

Objectif : manipuler les prix.

```text
Livrable :
- parseMoney("1g 20s 5c")
- formatMoney(12005)
- /cg price <itemID> <price>
- SavedVariables prices[itemID]
```

## Capsule 08 — Recursive Cost Calculator

Objectif : cœur métier.

```text
Livrable :
- cost(itemID)
- buy vs craft
- memoization
- missing prices
- cycle detection
- detail tree
```

## Capsule 09 — Profit Analyzer

Objectif : première valeur visible.

```text
Livrable :
- /cg analyze
- Top 10 en chat ou petite frame
- coût, prix net, profit, marge
```

## Capsule 10 — ItemInfo Cache

Objectif : noms lisibles.

```text
Livrable :
- itemID -> name/link/icon
- fallback si cache absent
- refresh sur GET_ITEM_INFO_RECEIVED
```

## Capsule 11 — Targeted AH Scan

Objectif : prix réels.

```text
Livrable :
- scan des items présents dans la DB
- QueryAuctionItems par nom exact
- parse GetAuctionItemInfo
- prix unitaire min buyout
- timestamp
```

## Capsule 12 — Results List

Objectif : UI utile.

```text
Livrable :
- fenêtre CraftGold
- bouton Scan
- bouton Analyze
- Top 10
- détail recette
```

Ensuite seulement :

```text
13 — ScrollFrame
14 — Profession Integration
15 — Leveling Planner
```

---

# Architecture de données MVP

## Recipe DB

```lua
---@class CraftGoldRecipe
---@field outputItemID number
---@field outputQty number
---@field profession string
---@field skill number
---@field reagents { itemID:number, qty:number }[]
---@field source "trainer"|"vendor"|"drop"|"quest"|"unknown"

CraftGoldDB = {
  recipesByOutput = {
    [4363] = {
      outputItemID = 4363,
      outputQty = 1,
      profession = "Engineering",
      skill = 65,
      source = "trainer",
      reagents = {
        { itemID = 4359, qty = 2 },
        { itemID = 2840, qty = 1 },
        { itemID = 2589, qty = 2 },
      },
    },
  }
}
```

## PriceStore

```lua
CraftGoldDB_Char = {
  prices = {
    [2840] = {
      source = "AH",
      unitBuyout = 1240, -- copper
      quantitySeen = 532,
      scannedAt = 1781106120,
    },
  }
}
```

## Cost result

```lua
{
  itemID = 4363,
  unitCost = 4120,
  method = "craft",
  missing = false,
  children = {
    {
      itemID = 4359,
      qty = 2,
      chosen = "craft",
      unitCost = 1240,
    },
    {
      itemID = 2840,
      qty = 1,
      chosen = "buy",
      unitCost = 1240,
    },
  }
}
```

---

# Algorithme cœur

```lua
function Cost(itemID, stack)
  if stack[itemID] then
    return Missing("cycle")
  end

  local buy = PriceStore:GetUnitPrice(itemID)
  local recipe = RecipeDB:GetRecipeProducing(itemID)

  if not recipe then
    return buy or Missing("no price and no recipe")
  end

  stack[itemID] = true

  local craftTotal = 0
  local children = {}

  for _, reagent in ipairs(recipe.reagents) do
    local child = Cost(reagent.itemID, stack)
    if child.missing then
      stack[itemID] = nil
      return Missing("missing reagent", child)
    end

    craftTotal = craftTotal + child.unitCost * reagent.qty
    table.insert(children, child)
  end

  stack[itemID] = nil

  local craftUnit = craftTotal / recipe.outputQty

  if buy and buy.unitBuyout < craftUnit then
    return BuyResult(itemID, buy.unitBuyout)
  else
    return CraftResult(itemID, craftUnit, children)
  end
end
```

Ce cœur est ton “moteur CraftGold”. Tout le reste est périphérique.

---

# Décision finale

## Ce que tu dois faire maintenant

Ne fais pas “Capsule 06 — Scroll Frame”.

Fais :

```text
Capsule 06 — Recipe DB Mini + Recursive Cost Calculator
```

Puis :

```text
Capsule 07 — Manual prices + /cg analyze
```

Ton premier vrai moment magique doit être :

```text
/cg price 2840 12s40c
/cg price 2589 3s10c
/cg price 4359 18s
/cg analyze

CraftGold:
Copper Modulator
Cost: 41s20c
Sell net: 72s00c
Profit: 30s80c
Decision: craft Handful of Copper Bolts instead of buying them.
```

À ce moment-là, CraftGold existe déjà comme produit. L’UI scrollable, les onglets, la minimap et les options ne sont que de l’emballage.

[1]: https://github.com/TheMouseNest/Auctionator "GitHub - TheMouseNest/Auctionator: The Auctionator addon for World of Warcraft. · GitHub"
[2]: https://support.tradeskillmaster.com/en_US/tsm-addon-documentation/1236068-tsm-addon-crafting-operations "TSM Addon: Crafting Operations - TradeSkillMaster"
[3]: https://www.wowace.com/projects/lil-sparkys-workshop?page=35 "Overview - LilSparky's Workshop - Addons - Projects - WowAce "
[4]: https://support.tradeskillmaster.com/en_US/addon/why-am-i-missing-crafting-costs-or-profits-in-my-profession-window "Why am I missing crafting costs or profits in my profession window? - TradeSkillMaster"
[5]: https://warcraft.wiki.gg/wiki/API_QueryAuctionItems?utm_source=chatgpt.com "QueryAuctionItems - Warcraft Wiki"
[6]: https://warcraft.wiki.gg/wiki/AUCTION_ITEM_LIST_UPDATE?utm_source=chatgpt.com "AUCTION_ITEM_LIST_UPDATE - Warcraft Wiki"
[7]: https://warcraft.wiki.gg/wiki/API_GetAuctionItemInfo?utm_source=chatgpt.com "GetAuctionItemInfo - Warcraft Wiki"
[8]: https://warcraft.wiki.gg/wiki/API_GetNumAuctionItems?utm_source=chatgpt.com "GetNumAuctionItems - Warcraft Wiki"
[9]: https://warcraft.wiki.gg/wiki/API_GetItemInfo?utm_source=chatgpt.com "GetItemInfo - Warcraft Wiki"
[10]: https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfo?utm_source=chatgpt.com "C_Item.GetItemInfo - Warcraft Wiki"
[11]: https://warcraft.wiki.gg/wiki/GET_ITEM_INFO_RECEIVED?utm_source=chatgpt.com "GET_ITEM_INFO_RECEIVED - Warcraft Wiki"
[12]: https://warcraft.wiki.gg/wiki/API_C_TradeSkillUI.GetAllRecipeIDs?utm_source=chatgpt.com "C_TradeSkillUI.GetAllRecipeIDs - Warcraft Wiki"
[13]: https://www.curseforge.com/wow/addons/recipescollector "RecipesCollector - World of Warcraft Addons - CurseForge"
[14]: https://wowpedia.fandom.com/wiki/Recipe?utm_source=chatgpt.com "Recipe - Wowpedia - Your wiki guide to the World of Warcraft"
[15]: https://warcraft.wiki.gg/wiki/Profession?utm_source=chatgpt.com "Profession - Warcraft Wiki"
[16]: https://support.tradeskillmaster.com/en_US/custom-strings/which-price-sources-can-i-use-and-what-do-they-mean "Which Price Sources can I use and what do they mean? - TradeSkillMaster"
[17]: https://www.wowhead.com/classic/guide/classic-auction-house-economy?utm_source=chatgpt.com "Introduction to the Auction House and the Classic Economy"
[18]: https://warcraft.wiki.gg/wiki/Auction_House?utm_source=chatgpt.com "Auction House - Warcraft Wiki"
[19]: https://www.wowhead.com/classic/spell%3D3926/copper-modulator?utm_source=chatgpt.com "Copper Modulator - Spell - Classic World of Warcraft"
[20]: https://www.wowhead.com/classic/spell%3D3922/handful-of-copper-bolts?utm_source=chatgpt.com "Handful of Copper Bolts - Spell - Classic World of Warcraft"
[21]: https://www.wowhead.com/classic/guide/professions-overview-wow-classic?utm_source=chatgpt.com "Professions Guide And Best Professions For Each Class/ ..."
[22]: https://warcraft.wiki.gg/wiki/Widget_API?utm_source=chatgpt.com "Widget API - Warcraft Wiki"
[23]: https://warcraft.wiki.gg/wiki/UIOBJECT_ScrollFrame/Archive?utm_source=chatgpt.com "ScrollFrame/Archive - Warcraft Wiki"
[24]: https://warcraft.wiki.gg/wiki/HybridScrollFrame?utm_source=chatgpt.com "HybridScrollFrame - Warcraft Wiki"
[25]: https://wowpedia.fandom.com/wiki/UIOBJECT_ScrollFrame?utm_source=chatgpt.com "ScrollFrame - Your wiki guide to the World of Warcraft"
[26]: https://github.com/refaim/LibCrafts-1.0 "GitHub - refaim/LibCrafts-1.0: Vanilla WoW 1.12.1 addon library designed to provide an embeddable database of crafting spells, recipes, reagents, results, sources etc · GitHub"
[27]: https://github.com/refaim/TradeSkillsData "GitHub - refaim/TradeSkillsData: Vanilla WoW 1.12.1 addon. Provides database of trade skill recipes, vendors and sources. · GitHub"
[28]: https://www.curseforge.com/wow/addons/craftlib "CraftLib - World of Warcraft Addons - CurseForge"
[29]: https://addonstudio.org/wiki/WoW%3AAPI_QueryAuctionItems "WoW API: QueryAuctionItems - AddOn Studio"
[30]: https://github.com/OldManAlpha/aux-addon "GitHub - OldManAlpha/aux-addon: Auction House addOn for Vanilla (1.12) IMPORTANT: The folder name must be \"aux-addon\" · GitHub"
