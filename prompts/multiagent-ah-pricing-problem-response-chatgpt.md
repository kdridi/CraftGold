# Synthèse : le vrai sujet n’est pas “un prix par item”, c’est un **moteur de cotation par quantité**

Ton intuition est correcte : le modèle actuel `itemID -> prix` est utile pour apprendre, mais il devient faux dès qu’on veut répondre sérieusement aux deux objectifs de CraftGold.

Le bon pivot architectural est celui-ci :

```lua
-- Ancien monde
getPrice(itemID) -> copper

-- Nouveau monde
quote(itemID, quantity) -> {
  cost = copper,
  bought = quantityActuallyBought,
  surplus = bought - quantity,
  lots = { ...listingsChoisis... },
  source = "manual" | "auction_scan" | "fallback"
}
```

À partir de là, tout devient plus propre :

* **craft rentable** : “combien coûte vraiment la fabrication de 1 / 5 / 20 exemplaires ?”
* **leveling planner** : “combien coûte vraiment le panier complet de composants nécessaires ?”
* **AH scanner** : ne produit pas un prix, il produit des **listings**
* **analyse** : ne consomme pas un prix, elle consomme une **cotation pour une quantité**

Les API Classic Era imposent bien ce modèle : `QueryAuctionItems(...)` interroge l’Hôtel des Ventes quand `CanSendAuctionQuery()` l’autorise, `GetAuctionItemInfo("list", index)` donne notamment `count`, `buyoutPrice` et `itemId`, et `AUCTION_ITEM_LIST_UPDATE` signale la mise à jour de la liste. `buyoutPrice` est donc exploitable avec `count` pour reconstruire un prix par lot, puis filtrer par `itemId` après une recherche textuelle. ([Warcraft Wiki][1])

---

# 1. Problème des listings HdV : nature algorithmique

## 1.1 Le problème exact

Pour un item donné, tu as :

```text
Besoin : q unités

Listings disponibles :
L1 = count 1,  price 1s
L2 = count 5,  price 25s
L3 = count 20, price 2g
L4 = count 1,  price 15s
```

Tu veux choisir un sous-ensemble de listings tel que :

```text
somme(count_i) >= q
```

et minimiser :

```text
somme(price_i)
```

C’est un **minimum-cost knapsack cover** : chaque auction est un lot indivisible, avec une taille `count`, un coût `buyoutPrice`, et une demande minimale `q`. La littérature décrit ce type de problème comme une variante de knapsack où l’objectif est de sélectionner un sous-ensemble d’items dont la taille cumulée couvre au moins une demande donnée, au coût minimal. ([DROPS][2])

Dans le cas général, c’est apparenté aux problèmes de sac à dos, qui sont NP-complets / NP-difficiles en formulation générale, mais qui admettent des algorithmes pseudo-polynomiaux par programmation dynamique quand les poids sont des entiers raisonnables. ([Wikipedia][3])

## 1.2 La bonne nouvelle : dans WoW, c’est petit

En théorie, c’est dur.

En pratique, pour CraftGold, c’est très faisable parce que :

* les quantités sont des entiers ;
* les stacks ont une taille bornée ;
* tu ne vas pas optimiser des millions de listings ;
* pour une cotation de matériau, `q` est souvent entre 1 et quelques milliers ;
* les résultats AH sont paginés par pages de 50 via l’ancienne API, ce qui force déjà une collecte bornée. ([Warcraft Wiki][4])

Donc pour **un item**, tu peux résoudre exactement avec une DP très simple.

---

# 2. Algorithme exact recommandé pour un item : DP “min-cost cover”

## 2.1 Idée

On calcule le coût minimal pour obtenir exactement `x` unités, puis on prend le meilleur `x >= need`.

Mais on n’a pas besoin d’aller jusqu’à une quantité énorme. Si `maxStack` est la plus grande taille de listing disponible, alors il existe toujours une solution optimale avec :

```text
need <= totalBought <= need + maxStack - 1
```

Intuition : si une solution achète au moins `need + maxStack`, on peut retirer un listing sélectionné, de taille au plus `maxStack`, et rester au-dessus de `need`, avec un coût inférieur ou égal.

Donc la DP peut s’arrêter à :

```lua
cap = need + maxStack - 1
```

## 2.2 Pseudo-code Lua

```lua
local INF = 10 ^ 18

-- listing = {
--   itemID = 2840,
--   count = 5,
--   buyout = 2500, -- copper total du stack
--   owner = "...", -- optionnel
-- }

local function quoteListings(listings, need)
  if need <= 0 then
    return {
      cost = 0,
      bought = 0,
      surplus = 0,
      listings = {},
    }
  end

  local usable = {}
  local maxCount = 0

  for _, a in ipairs(listings) do
    if a.count and a.count > 0 and a.buyout and a.buyout > 0 then
      table.insert(usable, a)
      if a.count > maxCount then
        maxCount = a.count
      end
    end
  end

  if #usable == 0 then
    return nil -- pas de cotation possible
  end

  local cap = need + maxCount - 1

  local dp = {}
  local prev = {}

  for q = 0, cap do
    dp[q] = INF
  end

  dp[0] = 0

  -- 0/1 : chaque listing ne peut être acheté qu'une fois
  for i, a in ipairs(usable) do
    for q = cap, 0, -1 do
      if dp[q] < INF then
        local nq = q + a.count
        if nq > cap then
          nq = cap
        end

        local nc = dp[q] + a.buyout

        if nc < dp[nq] then
          dp[nq] = nc
          prev[nq] = {
            previousQuantity = q,
            listingIndex = i,
          }
        end
      end
    end
  end

  local bestQ = nil
  local bestCost = INF

  for q = need, cap do
    if dp[q] < bestCost then
      bestCost = dp[q]
      bestQ = q
    end
  end

  if not bestQ then
    return nil
  end

  local chosen = {}
  local q = bestQ

  while q > 0 and prev[q] do
    local p = prev[q]
    local listing = usable[p.listingIndex]
    table.insert(chosen, listing)
    q = p.previousQuantity
  end

  return {
    cost = bestCost,
    bought = bestQ,
    surplus = bestQ - need,
    listings = chosen,
  }
end
```

## 2.3 Complexité

Pour un item :

```text
O(nombreListings × (need + maxStack))
```

Dans un contexte Classic, c’est parfaitement acceptable pour une cotation locale.

Exemple réaliste :

```text
500 listings × (847 + 20) ≈ 433 500 états
```

C’est trivial.

## 2.4 Pourquoi pas seulement “prix unitaire le plus bas” ?

Le tri par prix unitaire est une excellente **heuristique d’achat rapide**, mais pas une vérité mathématique.

Exemple :

```text
Besoin : 7

A: x20 pour 2g  => 10s / unité
B: x5  pour 60s => 12s / unité
C: x2  pour 30s => 15s / unité
```

Le plus bas prix unitaire est `A`, mais acheter `A` coûte 2g. Acheter `B + C` coûte 90s. Le greedy par prix unitaire échoue.

Donc :

```text
UI d’achat rapide          -> tri par prix unitaire OK
cotation exacte CraftGold  -> DP par quantité
```

---

# 3. Extension au batch : le vrai coût d’un panier de composants

Pour un craft isolé, tu peux faire :

```lua
quote(2840, 2) -- Copper Bar x2
quote(2880, 1) -- Weak Flux x1
```

Mais pour un leveling planner, il faut agréger avant de coter :

```text
Mauvais :
- craft 1 demande Copper Bar x2 -> quote(2840, 2)
- craft 2 demande Copper Bar x3 -> quote(2840, 3)
- craft 3 demande Copper Bar x4 -> quote(2840, 4)

Bon :
- total Copper Bar x9 -> quote(2840, 9)
```

Donc tu veux introduire une structure intermédiaire :

```lua
local demand = {
  [2840] = 847, -- Copper Bar
  [2880] = 120, -- Weak Flux
  [2835] = 310, -- Rough Stone
}
```

Puis :

```lua
local total = 0

for itemID, quantity in pairs(demand) do
  local quote = PriceOracle:Quote(itemID, quantity)
  total = total + quote.cost
end
```

Ça résout déjà le gros problème pratique : **les achats se regroupent par item**.

---

# 4. Le cas plus dur : acheter ou crafter les composants

Ton calcul actuel fait :

```text
min(prixAchat(item), coûtCraft(item))
```

C’est bien pour un prototype.

Mais avec des quantités, la bonne version devient :

```text
min(
  quoteBuy(itemID, quantity),
  quoteCraft(itemID, quantity)
)
```

Or `quoteCraft(itemID, quantity)` peut produire du surplus, consommer des composants, lesquels peuvent être achetés ou craftés à leur tour.

Le modèle exact devient un problème de **production planning entier** :

```text
Variables :
- x_l ∈ {0,1} : acheter ou non le listing HdV l
- y_r ∈ N     : nombre de fois où l’on craft la recette r

Contraintes :
Pour chaque item :
  stock initial
+ achats HdV
+ outputs de crafts
- composants consommés
>= demande finale

Objectif :
  minimiser coût des achats HdV + coûts vendeurs éventuels
```

C’est très propre conceptuellement, mais trop lourd pour une capsule pédagogique WoW Lua : c’est essentiellement un petit problème d’optimisation entière. C’est possible à expliquer, mais pas souhaitable à implémenter en v1 dans un add-on sans build ni solveur.

Recommandation pragmatique :

```text
v1 pédagogique :
1. quote exacte par item acheté
2. agrégation des besoins
3. récursion buy-vs-craft avec mémoïsation
4. surplus géré localement, pas globalement optimal

v2 avancée :
5. solveur global sur panier complet
6. éventuellement branch-and-bound ou ILP hors jeu
```

---

# 5. Ce que font les add-ons existants

## 5.1 Auctionator

Auctionator se présente comme un add-on orienté usage quotidien de l’Hôtel des Ventes, avec prix en tooltips, scan complet de l’AH, coûts de réactifs et profits dans les vues de crafting, recherches filtrées et shopping lists. ([GitHub][5])

La version / fork Classic met explicitement en avant l’affichage de listings triés avec **prix individuel** et **taille de stack**, la comparaison des listings existants au moment de vendre, le scan complet de l’AH et l’historique des prix. ([GitHub][6])

Conclusion pour CraftGold : Auctionator est très proche de ton besoin côté **collecte / UI / prix unitaire / historique**, mais les sources publiques ne montrent pas un solveur global “j’ai besoin de 847 unités, choisis les lots indivisibles optimaux”. Sa logique documentée est plutôt : scanner, afficher, trier, historiser, aider à acheter/vendre.

## 5.2 TradeSkillMaster

TSM expose des **price sources** : `DBMinBuyout`, `DBMarket`, `DBRecent`, `DBHistorical`, `crafting`, `matPrice`, etc. Sa documentation précise que `Crafting` est la somme des prix de matériaux (`matPrice`) de chaque réactif d’une recette, et que `matPrice` est configurable. ([support.tradeskillmaster.com][7])

TSM documente aussi que `DBMinBuyout` est le plus bas prix listé sur le royaume lors de la dernière mise à jour de pricing, et que cette donnée n’est pas temps réel ; `DBMarket` est une moyenne pondérée sur 14 jours favorisant les 3 jours les plus récents. ([support.tradeskillmaster.com][7])

Le calcul `AuctionDB Market Value` de TSM est plus subtil qu’une moyenne simple : il cherche à corriger les outliers, considère une partie basse des auctions, limite l’influence de hausses brutales, puis jette les données individuelles de scan pour conserver une valeur de marché agrégée dans le temps. ([support.tradeskillmaster.com][8])

Conclusion pour CraftGold : TSM ne cherche pas principalement à répondre à “combien me coûtent exactement 847 Copper Bars si j’achète les lots disponibles maintenant ?”. Il produit des **sources de prix robustes** pour automatiser des décisions. C’est excellent pour du goldmaking à grande échelle, mais différent d’une cotation exacte par quantité.

## 5.3 TSM Crafting / Shopping

TSM Crafting Operations permettent de restocker un nombre donné d’items à utiliser ou vendre, avec seuil de profit minimal ; la documentation définit le profit comme `Crafted Item Value - Crafting Cost`. ([support.tradeskillmaster.com][9])

TSM Shopping Operations permettent de chercher des items avec un prix d’action maximal configurable, et incluent une quantité de restock maximale. ([support.tradeskillmaster.com][10])

Conclusion : TSM sépare bien les concepts que tu veux enseigner :

```text
prix source     -> estimation
crafting cost   -> somme des matériaux
shopping        -> achat sous condition de prix
restock         -> objectif de quantité
profit          -> valeur craftée - coût craft
```

CraftGold peut reprendre cette séparation, mais en gardant une pédagogie plus simple et en ajoutant une vraie notion de `quote(itemID, quantity)`.

## 5.4 Auctioneer

Auctioneer est historiquement centré sur le scan et le suivi de données AH, incluant prix d’enchère, buyout et quantités listées. ([WoWWiki Archive][11])

Sa page CurseForge mentionne plusieurs modules statistiques, dont `Auc-Stat-Sales` basé sur des données historiques d’achats/ventes, et `Auc-Stat-Simple`, qui utilise des moyennes converties en moyennes mobiles exponentielles. ([CurseForge][12])

Conclusion : Auctioneer est encore une approche “statistique de marché”, pas un modèle exact de panier par lots indivisibles.

---

# 6. Problème du leveling planner

## 6.1 Nature du problème

Le leveling planner est un problème d’optimisation séquentielle :

```text
État :
  skill actuel

Actions :
  crafter une recette disponible

Coût :
  coût attendu des composants

Transition :
  skill + 1 avec probabilité p
  skill inchangé avec probabilité 1 - p

Objectif :
  minimiser le coût attendu pour atteindre skill cible
```

C’est un petit **Markov Decision Process** / problème de programmation dynamique stochastique.

Mais dans ta version pédagogique, on peut le ramener à quelque chose de très simple :

```text
coût moyen par point = coût du craft / probabilité de skill-up
```

La documentation communautaire WoW indique qu’une recette orange donne normalement un skill-up garanti, qu’une jaune donne un skill-up fréquemment, qu’une verte rarement, et qu’une grise jamais. Wowpedia / Vanilla Wiki donnent aussi la formule empirique :

```text
chance = (greySkill - currentSkill) / (greySkill - yellowSkill)
```

avec une espérance de crafts égale à `1 / chance`. ([Wowpedia][13])

Wowhead Classic résume aussi la logique pédagogique classique : orange = 100 %, jaune = fréquent, vert = peu fréquent, gris = jamais, et recommande d’analyser les recettes jaunes quand elles ne garantissent plus le skill-up. ([Wowhead][14])

## 6.2 Formule utile pour CraftGold

Pour une recette `r` au skill `s` :

```lua
local function skillupChance(recipe, skill)
  if skill < recipe.yellow then
    return 1.0
  end

  if skill >= recipe.gray then
    return 0.0
  end

  return (recipe.gray - skill) / (recipe.gray - recipe.yellow)
end
```

Puis :

```lua
expectedCostPerPoint = craftCost(recipe) / skillupChance(recipe, skill)
```

Exemple :

```text
Recette A :
  coût craft = 5s
  chance = 1.0
  coût moyen par point = 5s

Recette B :
  coût craft = 2s
  chance = 0.75
  coût moyen par point = 2s / 0.75 = 2s66c

Recette C :
  coût craft = 1s
  chance = 0.20
  coût moyen par point = 5s
```

Donc une recette moins chère par craft peut être plus chère par point.

## 6.3 DP simplifiée pour le leveling

Si on accepte l’espérance mathématique comme critère, alors :

```lua
bestCost[targetSkill] = 0

for skill = targetSkill - 1, startSkill, -1 do
  bestCost[skill] = INF

  for _, recipe in ipairs(recipes) do
    local p = skillupChance(recipe, skill)

    if p > 0 then
      local craftCost = RecipeCost(recipe)
      local expected = craftCost / p + bestCost[skill + 1]

      if expected < bestCost[skill] then
        bestCost[skill] = expected
        bestRecipe[skill] = recipe
      end
    end
  end
end
```

Cette version donne un plan du type :

```text
1-30   Rough Blasting Powder
30-50  Handful of Copper Bolts
50-65  Arclight Spanner
...
```

Mais attention : elle suppose un coût de craft stable. Avec les listings réels, le coût du 1er craft et du 100e craft ne sont pas forcément identiques.

---

# 7. Lien entre leveling planner et listings HdV

Il y a trois niveaux possibles.

## Niveau 1 — Simple et pédagogique

Pour chaque recette :

```text
coût craft = somme des composants × prix unitaire estimé
```

Puis :

```text
coût par point = coût craft / probabilité
```

C’est la bonne première capsule de leveling.

## Niveau 2 — Correct pour le panier global

Le planner choisit d’abord un chemin attendu :

```text
1-30 recette A
30-50 recette B
50-75 recette C
```

Ensuite il agrège les composants :

```text
Copper Bar x847
Rough Stone x310
Weak Flux x120
```

Puis il appelle :

```lua
quote(CopperBar, 847)
quote(RoughStone, 310)
quote(WeakFlux, 120)
```

C’est le meilleur compromis pour CraftGold v1.

## Niveau 3 — Optimisation globale exacte

Le choix du chemin dépend directement des lots disponibles.

Exemple :

```text
Recette A utilise Copper Bar
Recette B utilise Rough Stone

À prix unitaire moyen, A semble meilleure.
Mais l’AH a un gros lot de Rough Stone très bon marché.
Donc B devient meilleure pour ce serveur, à cet instant.
```

Là, il faudrait intégrer le coût de panier directement dans la DP de leveling. C’est faisable, mais beaucoup plus lourd, parce que le coût marginal d’une recette dépend de tous les achats déjà prévus.

Recommandation :

```text
CraftGold v1 :
  planner par coût estimé + cotation finale du panier

CraftGold v2 :
  planner itératif :
    1. estimer les prix unitaires
    2. choisir un chemin
    3. agréger le panier
    4. recalculer les coûts effectifs
    5. éventuellement réoptimiser
```

---

# 8. Architecture recommandée

## 8.1 Séparer trois notions

Ne mélange pas :

```text
PriceSource
  Donne une estimation simple.
  Exemple : manualPrice[itemID] = 1240 copper

ListingSource
  Donne les lots disponibles.
  Exemple : Copper Bar x5 à 25s

QuoteEngine
  Transforme des listings + une quantité en coût réel.
```

Interface mentale :

```lua
PriceSource:GetUnitPrice(itemID)
ListingSource:GetListings(itemID)
QuoteEngine:Quote(itemID, quantity)
```

## 8.2 Garder une façade unique

Le reste de l’add-on ne devrait pas savoir si le prix vient de :

* prix manuel ;
* scan AH ;
* Auctionator ;
* TSM ;
* fallback vendor ;
* estimation historique.

Il devrait seulement appeler :

```lua
CraftGold.PriceOracle:Quote(itemID, quantity)
```

Exemple :

```lua
local quote = PriceOracle:Quote(2840, 7)

if quote then
  print("Coût:", FormatMoney(quote.cost))
  print("Acheté:", quote.bought)
  print("Surplus:", quote.surplus)
else
  print("Prix inconnu")
end
```

## 8.3 Fallbacks progressifs

Ordre recommandé :

```text
1. Listings AH frais
2. Prix manuel
3. Prix historique local
4. Prix vendor, si item vendor
5. inconnu
```

Ne fais pas :

```lua
if scanAH then price = minUnitPrice end
```

Fais plutôt :

```lua
if scanAH then quote = exactListingQuote(itemID, quantity) end
```

---

# 9. Roadmap actuelle : où sont les gros sauts

Ta roadmap actuelle :

| #  | Capsule          | Problème                                                               |
| -- | ---------------- | ---------------------------------------------------------------------- |
| 08 | Analyze & Report | OK, mais encore scalaire                                               |
| 09 | Item Info        | OK                                                                     |
| 10 | AH Scanner       | Trop grosse : API, async, pagination, throttling, listings, stack/unit |
| 11 | Profit Window    | Arrive trop tôt si le modèle de prix est encore faux                   |
| 12 | Scroll Frame     | OK, mais doit venir quand la liste déborde vraiment                    |
| 13 | Leveling Planner | Beaucoup trop grosse : skill probability + DP + panier + AH real cost  |
| 14 | CraftGold v1     | OK, mais seulement si les concepts précédents sont séparés             |

Le problème principal est que la capsule 10 et la capsule 13 contiennent chacune 4 ou 5 concepts.

---

# 10. Roadmap révisée proposée

Je proposerais de passer de 14 capsules à environ 18 ou 19. Ça paraît plus long, mais chaque capsule devient beaucoup plus claire.

## Vue globale

| #  | Capsule                | Objectif       | Concept principal                                     |
| -- | ---------------------- | -------------- | ----------------------------------------------------- |
| 08 | Analyze & Report v1    | Rentabilité    | Rapport avec prix scalaire                            |
| 09 | Item Info              | Infrastructure | `GetItemInfo()` async, noms lisibles                  |
| 10 | Price Oracle           | Les deux       | Remplacer `getPrice(itemID)` par `quote(itemID, qty)` |
| 11 | Manual Listings        | Les deux       | Simuler des lots AH à la main                         |
| 12 | Quantity Quote DP      | Les deux       | Résoudre le choix optimal de listings                 |
| 13 | Batch Demand           | Les deux       | Agréger les composants avant cotation                 |
| 14 | AH Scanner v1          | Les deux       | Requête AH pour un item, page unique                  |
| 15 | AH Scanner v2          | Les deux       | Pagination, throttling, fraîcheur                     |
| 16 | Profit Analyzer v2     | Rentabilité    | Profits basés sur `quote(reagent, qty)`               |
| 17 | Profit Window          | Rentabilité    | Fenêtre Top crafts                                    |
| 18 | Scroll Frame           | UI             | Scroll quand la liste déborde                         |
| 19 | Skill Difficulty       | Leveling       | Orange/jaune/vert/gris + probabilité                  |
| 20 | Leveling DP v1         | Leveling       | Coût attendu par point                                |
| 21 | Leveling Shopping List | Leveling       | Panier global + cotation AH exacte                    |
| 22 | CraftGold v1           | Intégration    | DB complète, polish, TradeSkill UI                    |

---

# 11. Détail des nouvelles capsules

## Capsule 08 — Analyze & Report v1

Objectif : garder ton modèle actuel.

Concept unique :

```text
Avec un prix scalaire par item, calculer coût/profit et afficher un classement.
```

Commande :

```text
/cg analyze
```

Résultat :

```text
Top crafts:
1. Copper Modulator — coût 43s40c — vente 72s — profit 28s60c
```

Pourquoi la garder : elle donne une récompense immédiate et prépare le besoin d’un meilleur modèle.

Statut : **rentabilité uniquement**.

---

## Capsule 09 — Item Info

Objectif : rendre l’add-on lisible.

Concept unique :

```text
itemID -> nom affichable, avec cache asynchrone.
```

Tu gardes `GetItemInfo()` et `GET_ITEM_INFO_RECEIVED`.

Statut : **infrastructure pour les deux objectifs**.

---

## Capsule 10 — Price Oracle

Objectif : introduire l’abstraction qui sauvera l’architecture.

Avant :

```lua
GetPrice(itemID)
```

Après :

```lua
Quote(itemID, quantity)
```

Mais au début, l’implémentation reste triviale :

```lua
function ManualPriceOracle:Quote(itemID, quantity)
  local unit = self.prices[itemID]

  if not unit then
    return nil
  end

  return {
    cost = unit * quantity,
    bought = quantity,
    surplus = 0,
    source = "manual-unit-price",
  }
end
```

Statut : **les deux objectifs**.

---

## Capsule 11 — Manual Listings

Objectif : introduire les listings sans encore toucher à l’AH.

Commande possible :

```text
/cg listing 2840 1 1s
/cg listing 2840 5 25s
/cg listing 2840 20 2g
```

Données :

```lua
CraftGoldDB.listings = {
  [2840] = {
    { count = 1,  buyout = 100 },
    { count = 5,  buyout = 2500 },
    { count = 20, buyout = 20000 },
  }
}
```

Concept unique :

```text
Un prix AH est un lot, pas un prix unitaire.
```

Statut : **les deux objectifs**.

---

## Capsule 12 — Quantity Quote DP

Objectif : résoudre exactement :

```text
J’ai besoin de q unités, quels listings acheter ?
```

Commande :

```text
/cg quote 2840 7
```

Résultat :

```text
Copper Bar x7
Achat optimal:
- x1 à 1s
- x5 à 25s
- x1 à 15s
Total: 41s
Surplus: 0
```

Concept unique :

```text
programmation dynamique sur quantité
```

Statut : **les deux objectifs**.

C’est une capsule algorithmique très forte pédagogiquement.

---

## Capsule 13 — Batch Demand

Objectif : ne plus coter craft par craft, mais panier par panier.

Entrée :

```lua
{
  { itemID = 2840, quantity = 2 },
  { itemID = 2840, quantity = 3 },
  { itemID = 2880, quantity = 1 },
}
```

Sortie :

```lua
{
  [2840] = 5,
  [2880] = 1,
}
```

Concept unique :

```text
agrégation de demande
```

Statut : **les deux objectifs**.

---

## Capsule 14 — AH Scanner v1

Objectif : scanner un item, une page.

Concept unique :

```text
QueryAuctionItems par nom, puis filtrage par itemID.
```

Important : comme l’API prend un texte de recherche, ton flow doit être :

```text
itemID -> GetItemInfo(itemID) -> nom
nom -> QueryAuctionItems(nom, ...)
résultats -> GetAuctionItemInfo("list", i)
filtrer result.itemId == itemID
```

`QueryAuctionItems` interroge l’AH par texte et `GetAuctionItemInfo` permet ensuite de lire `count`, `buyoutPrice` et `itemId` pour les résultats courants. ([Warcraft Wiki][1])

Statut : **les deux objectifs**.

---

## Capsule 15 — AH Scanner v2

Objectif : rendre le scanner fiable.

Concept unique :

```text
file de requêtes + pagination + throttling + fraîcheur des données
```

Tu introduis :

```lua
ScanQueue
ScanState
lastScanTime
isFresh(maxAgeSeconds)
```

L’API expose `CanSendAuctionQuery()` pour savoir quand une nouvelle requête AH peut être envoyée, et `AUCTION_ITEM_LIST_UPDATE` signale la mise à jour de la liste. ([Warcraft Wiki][15])

Statut : **les deux objectifs**.

---

## Capsule 16 — Profit Analyzer v2

Objectif : refaire `/cg analyze` avec le modèle réel.

Avant :

```text
profit = sellPrice - sum(unitPrice * qty)
```

Après :

```text
profit = sellQuote - sum(quote(componentID, qty).cost)
```

Mais attention : pour le prix de vente du produit fini, tu n’as pas exactement le même problème. Tu ne peux pas garantir que l’item va se vendre au lowest buyout. Les add-ons comme TSM distinguent justement différentes sources (`DBMinBuyout`, `DBMarket`, `DBRecent`, `DBHistorical`) pour éviter de réduire la valeur de vente à un seul listing fragile. ([support.tradeskillmaster.com][7])

Donc je recommande :

```text
coût matériaux = quote exacte par quantité
valeur de vente = estimation configurable
profit = estimatedSellValue - exactMaterialCost
```

Statut : **rentabilité**.

---

## Capsule 17 — Profit Window

Objectif : fenêtre Top crafts.

Concept unique :

```text
afficher une liste structurée issue de l’analyse.
```

Tu peux maintenant justifier les widgets :

* nom du craft ;
* coût ;
* valeur estimée ;
* profit ;
* source du prix ;
* fraîcheur du scan.

Statut : **rentabilité**.

---

## Capsule 18 — Scroll Frame

Objectif : gérer une liste qui déborde.

Concept unique :

```text
ScrollFrame / Slider sur une liste déjà utile.
```

Statut : **UI, surtout rentabilité mais réutilisable leveling**.

---

## Capsule 19 — Skill Difficulty

Objectif : introduire la mécanique orange/jaune/vert/gris sans planner complet.

Données recette :

```lua
{
  itemID = 4357,
  orange = 1,
  yellow = 30,
  green = 45,
  gray = 60,
}
```

Fonction :

```lua
skillupChance(recipe, currentSkill)
```

Affichage :

```text
Rough Blasting Powder at skill 35:
chance skill-up: 83%
expected crafts per point: 1.20
```

La formule empirique communément citée est `chance = (graySkill - currentSkill) / (graySkill - yellowSkill)`, avec `1 / chance` comme nombre moyen de crafts par skill-up. ([Wowpedia][13])

Statut : **leveling**.

---

## Capsule 20 — Leveling DP v1

Objectif : produire un chemin optimal en coût attendu.

Concept unique :

```text
programmation dynamique par skill
```

Sortie :

```text
Engineering 1 -> 150

1-30   Rough Blasting Powder   expected cost: 1g20s
30-50  Handful of Copper Bolts expected cost: 2g10s
50-65  Arclight Spanner        expected cost: 90s
...
Total expected: 14g35s
```

Statut : **leveling**.

---

## Capsule 21 — Leveling Shopping List

Objectif : transformer le plan en panier réel.

Concept unique :

```text
plan -> expected crafts -> aggregated demand -> AH quote
```

Exemple :

```text
Plan attendu :
- Rough Blasting Powder x35
- Handful of Copper Bolts x70
- Copper Modulator x15

Panier :
- Copper Bar x155
- Rough Stone x70
- Linen Cloth x30
- Weak Flux x15

Cotation AH :
- Copper Bar x155 -> 7g42s, surplus 5
- Rough Stone x70 -> 1g20s, surplus 10
...
```

Statut : **leveling + AH réel**.

---

## Capsule 22 — CraftGold v1

Objectif : intégration finale.

Concepts :

```text
DB complète
Trade Skill UI integration
fenêtre principale
polish
fallbacks
messages d’erreur propres
```

Statut : **les deux objectifs**.

---

# 12. Ce qu’il faut éviter

## 12.1 Ne pas mettre l’AH scanner avant le modèle de listings

Si tu fais :

```text
AH Scanner -> minUnitPrice
```

tu vas enseigner une mauvaise abstraction.

Mieux :

```text
Manual Listings -> Quote DP -> AH Scanner
```

Comme ça, quand l’AH arrive, il ne fait que remplir une structure déjà comprise.

## 12.2 Ne pas faire le leveling planner en une seule capsule

Une capsule “Leveling Planner” qui inclut :

* couleurs ;
* probabilités ;
* espérance ;
* DP ;
* coûts AH ;
* batch demand ;
* shopping list ;

sera trop massive.

Il faut séparer :

```text
Skill Difficulty
Leveling DP
Leveling Shopping List
```

## 12.3 Ne pas promettre une exactitude économique parfaite

Même avec un coût d’achat exact, le profit reste une estimation :

```text
coût matériaux : observable et exact au moment du scan
prix de vente : incertain
temps de vente : incertain
concurrence : changeante
```

TSM reflète cette réalité en proposant plusieurs price sources et des valeurs de marché lissées plutôt qu’un seul “vrai prix”. ([support.tradeskillmaster.com][7])

---

# 13. Recommandation finale

Pour CraftGold, je prendrais cette ligne directrice :

```text
Ne cherche pas d’abord “le meilleur prix”.
Construis d’abord “une cotation pour une quantité”.
```

Architecture cible :

```lua
PriceOracle:Quote(itemID, quantity)
RecipeCost:QuoteCraft(recipeID, craftCount)
DemandBuilder:AddRecipe(recipeID, craftCount)
ProfitAnalyzer:AnalyzeCraft(recipeID, craftCount)
LevelingPlanner:Plan(startSkill, targetSkill)
ShoppingList:QuoteDemand(demand)
```

Ordre pédagogique optimal :

```text
1. prix scalaire
2. abstraction Quote(item, qty)
3. listings manuels
4. DP exacte de lots
5. agrégation de panier
6. scan AH
7. analyse profit réelle
8. UI profit
9. probabilité skill-up
10. DP leveling
11. shopping list leveling
```

C’est progressif, atomique, testable hors WoW, et surtout ça évite de bâtir l’add-on final sur une abstraction fausse.

[1]: https://warcraft.wiki.gg/wiki/API_QueryAuctionItems?utm_source=chatgpt.com "QueryAuctionItems - Warcraft Wiki"
[2]: https://drops.dagstuhl.de/storage/00lipics/lipics-vol024-fsttcs2013/LIPIcs.FSTTCS.2013.275/LIPIcs.FSTTCS.2013.275.pdf?utm_source=chatgpt.com "Knapsack Cover Subject to a Matroid Constraint - DROPS"
[3]: https://en.wikipedia.org/wiki/Knapsack_problem?utm_source=chatgpt.com "Knapsack problem"
[4]: https://warcraft.wiki.gg/wiki/API_GetAuctionItemInfo?utm_source=chatgpt.com "GetAuctionItemInfo - Warcraft Wiki"
[5]: https://github.com/TheMouseNest/Auctionator "GitHub - TheMouseNest/Auctionator: The Auctionator addon for World of Warcraft. · GitHub"
[6]: https://github.com/manzarek123/Auctionator-Classic "GitHub - manzarek123/Auctionator-Classic: The auctionator add on for World of Warcraft · GitHub"
[7]: https://support.tradeskillmaster.com/en_US/custom-strings/which-price-sources-can-i-use-and-what-do-they-mean "Which Price Sources can I use and what do they mean? - TradeSkillMaster"
[8]: https://support.tradeskillmaster.com/en_US/tsm-addon-documentation/auctiondb-market-value "AuctionDB Market Value - TradeSkillMaster"
[9]: https://support.tradeskillmaster.com/en_US/tsm-addon-documentation/1236068-tsm-addon-crafting-operations "TSM Addon: Crafting Operations - TradeSkillMaster"
[10]: https://support.tradeskillmaster.com/en_US/tsm-addon-documentation/tsm-addon-shopping-operations "TSM Addon: Shopping Operations - TradeSkillMaster"
[11]: https://wowwiki-archive.fandom.com/wiki/Auctioneer_%28AddOn%29?utm_source=chatgpt.com "Auctioneer (AddOn)"
[12]: https://www.curseforge.com/wow/addons/auctioneer?utm_source=chatgpt.com "Auctioneer - World of Warcraft Addons"
[13]: https://wowpedia.fandom.com/wiki/Profession?utm_source=chatgpt.com "Profession - Wowpedia - Your wiki guide to the World of Warcraft"
[14]: https://www.wowhead.com/classic/guide/professions-overview-wow-classic?utm_source=chatgpt.com "Professions Guide And Best Professions For Each Class/ ..."
[15]: https://warcraft.wiki.gg/wiki/API_CanSendAuctionQuery?utm_source=chatgpt.com "CanSendAuctionQuery - Warcraft Wiki"
