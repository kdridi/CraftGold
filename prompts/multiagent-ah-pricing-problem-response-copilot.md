Je vais analyser vos deux problèmes et proposer une roadmap révisée. C'est une excellente question d'algorithmique appliquée à un domaine contraint (Lua + API WoW Limited).

---

## 1. Analyse du Problème 1 : Prix réel à l'Hôtel des Ventes

### Nature algorithmique

Votre intuition est bonne, mais ce n'est **pas exactement** du knapsack classique. C'est plutôt un problème de **sélection de listings avec contrainte de quantité**, que je classifie ainsi :

**Problème formel :**
```
Entrée : 
  - listings = [(price_per_unit_1, quantity_1), ..., (price_per_unit_n, quantity_n)]
  - need = quantité totale dont on a besoin
Sortie :
  - ensemble minimal de listings à acheter pour atteindre au moins `need`
  - coût total minimisé
```

**Exemple concret (vos données) :**
```
listings = [(1s, 1), (5s, 5), (10s, 20), (15s, 1)]
need = 7

Tri par prix unitaire : [(1s, 1), (5s, 5), (10s, 20), (15s, 1)]
Greedy : achète (1s, 1) → 1 unité, coût 1s
         achète (5s, 5) → 5 unités, coût 25s
         achète (10s, 20) → 1 unité (sur 20), coût 10s
Total : 7 unités, coût 36s
```

### Complexité

**Réponse courte** : c'est **O(n log n)** si on utilise une **greedy heuristique**.

**Réponse longue** : le problème est **NP-difficile au sens fort** si on l'étend à :
- Multiobjectif (minimiser coût ET minimiser quantité achetée)
- Avec dépendances entre items (acheter 7 Copper Bars qui proviennent de 3 recettes différentes dont chacune a ses propres listings)

Mais dans la pratique, **le greedy marche parfaitement** pour un seul item :

```lua
-- Pseudo-code optimal O(n log n)
function getMinCostForQuantity(listings, need)
  -- listings = [{price, qty}, ...]
  table.sort(listings, function(a, b) return a.price < b.price end)
  
  local cost, bought = 0, 0
  for _, listing in ipairs(listings) do
    if bought >= need then break end
    local toBuy = math.min(need - bought, listing.qty)
    cost = cost + (toBuy * listing.price)
    bought = bought + toBuy
  end
  
  return cost, bought >= need  -- (coût, possible?)
end
```

**Pourquoi greedy marche ici :**
- On n'a pas de contrainte de capacité (pas de limite d'inventaire simulée)
- On veut juste atteindre la quantité minimum au coût minimum
- Le tri par prix unitaire croissant est optimal

---

## 2. Analyse du Problème 2 : Leveling Planner avec probabilités

### Nature algorithmique

C'est un **problème de programmation dynamique** ou **shortest path** avec états stochastiques.

**Problème formel :**
```
État : skill_level (0 à 300)
Actions : chaque recette i a un {coût, probabilité_gainup}
Objectif : atteindre skill 300 en minimisant E[coût total]

E[coût | recette i au level L] = coût_composants(i, L) / prob_skillup(i, L)
```

**Exemple concret :**
```
Recette A (orange, skill 0-60) :
  - coût composants : 5s
  - prob skillup : 100%
  → coût moyen par point : 5s

Recette B (jaune, skill 60-90) :
  - coût composants : 2s
  - prob skillup : 75%
  → coût moyen par point : 2s / 0.75 = 2s67c

Au skill 60, on a le choix :
  - continuer avec A (devient jaune, prob 75%) : 5s / 0.75 = 6s67c par point
  - switcher vers B : 2s67c par point
→ B est meilleur au-delà de skill 60
```

### Complexité

**O(300 × R)** où R = nombre de recettes (~50 pour Engineering).

On peut résoudre ça avec **dynamic programming** :

```lua
-- Pseudo-code
function optimalLevelingPath(startSkill, endSkill, recipes)
  local dp = {}  -- dp[skill] = coût minimum pour atteindre ce skill
  dp[startSkill] = 0
  
  for skill = startSkill, endSkill - 1 do
    for _, recipe in ipairs(recipes) do
      local color = getRecipeColor(recipe, skill)
      if color ~= "grey" then
        local prob = colorToProbability(color)  -- 1.0, 0.75, 0.25
        local cost = getCraftCost(recipe)
        local pointCost = cost / prob
        
        local nextSkill = skill + 1
        if not dp[nextSkill] or dp[nextSkill] > dp[skill] + pointCost then
          dp[nextSkill] = dp[skill] + pointCost
          parent[nextSkill] = {recipe, skill}  -- tracer le chemin
        end
      end
    end
  end
  
  return dp[endSkill], reconstructPath(parent, endSkill)
end
```

---

## 3. Lien entre Problème 1 et Problème 2

**C'est critique et c'est là que ça devient intéressant :**

Pour le leveling planner, on ne peut pas calculer `getCraftCost(recipe)` de manière isolée. Exemple :

```
Recettes à comparer au skill 30 :
  - Copper Modulator : besoin 2× Copper Bolt, 1× Power Core
  - Mossy Sensor : besoin 3× Copper Bar, 1× Power Core

Si je dois monter de skill 30→150, j'aurai peut-être 50 Copper Modulators + 
30 Mossy Sensors = 100 Copper Bars + 80 Power Cores à acheter.

Le "coût réel" dépend de COMMENT ces 100 Copper Bars arrivent à l'HdV :
  - Listing 1 : 1 Copper Bar @ 1s
  - Listing 2 : 10 Copper Bars @ 5s (50s total)
  - Listing 3 : 100 Copper Bars @ 3s (300s total)

Pour 100 Copper Bars, j'achète listings 1+2 (51s) + partie de listing 3 (210s) 
= 261s, pas 100 × 3s = 300s.
```

**Cela signifie :** le leveling planner est un problème d'**optimisation combinatoire global**, pas juste un graphe de coûts constants.

### Approche pragmatique pour CraftGold

Vu les contraintes (Lua, pas de build, exécution real-time), je propose une **heuristique en deux phases** :

**Phase 1 (greedy local)** : Pour chaque recette, estimer `getCraftCost()` en supposant qu'on va crafter ~50 fois (moyenne leveling). Scanner l'HdV, appliquer le greedy pour chaque composant aggégé.

**Phase 2 (DP global)** : Construire le graphe de leveling avec ces coûts estimés, résoudre le DP.

```lua
function estimateLevelingCost(recipe, estimatedCrafts)
  local components = {}  -- agrégation
  for _, comp in ipairs(recipe.components) do
    components[comp.itemId] = (components[comp.itemId] or 0) + (comp.qty * estimatedCrafts)
  end
  
  local totalCost = 0
  for itemId, needQty in pairs(components) do
    local listings = scanAHFor(itemId)  -- greedy problem 1
    local cost, ok = getMinCostForQuantity(listings, needQty)
    if not ok then return nil end  -- pas assez de stock
    totalCost = totalCost + cost
  end
  
  return totalCost / estimatedCrafts  -- coût moyen par craft
end
```

---

## 4. Ce que font les add-ons existants

### Auctionator
- **Stratégie de prix** : sauvegarde **tous les listings** pour chaque item (pas juste le meilleur prix)
- **Scan complet** : scan l'HdV entièrement au login, pré-calcule les coûts
- **Pas de DP complexe** : affiche juste "cheapest way to flip" item par item
- **Source** : [Auctionator GitHub](https://github.com/Warcraft-Auctioneer/Auctionator) — voir `data/prices.lua`

### TSM (TradeSkillMaster)
- **Stratégie** : **database communautaire** (crowdsourced), pas de scan real-time
- **Optimization** : résout du knapsack multi-étapes pour l'artisanat optimal (craft A → vendre → acheter matériaux B → craft B)
- **DP sophistiquée** : optimise sur l'ensemble de la chaine de production
- **Source** : code fermé, mais documenté ici : [TSM Wiki](https://www.tradeskillmaster.com/site/guides/how-to-use-tsm-crafting)

### Verdict
- **Auctionator** : greedy simple, pas d'optimisation globale
- **TSM** : DP globale mais sur database fixe (pas real-time HdV)
- **CraftGold** : opportunité de faire mieux avec une approche hybride

---

## 5. Roadmap révisée

Je réorganise vos capsules pour attaquer les deux problèmes en parallèle, progressivement.

### Phase A : Fondations (Capsules 8-10) — *Prix réal*

| # | Capsule | Concepts clés | Livrables |
|---|---------|---------------|-----------|
| 8 | **AH Listings Model** (NOUVEAU) | Stocker listings comme `[(price, qty), ...]` au lieu d'un seul prix | `/cg listings 2840` → affiche tous les listings de Copper Bar |
| 9 | **Item Info (révisée)** | `GetItemInfo()`, cache asynchrone, resolve itemID → name | `/cg info 2840` → "Copper Bar" |
| 10 | **AH Scanner (révisée)** | `QueryAuctionItems`, pagination, throttling, **populate listings model** | `/cg scan` → met à jour le modèle listings en arrière-plan |
| 11 | **Min Cost Calculator (NOUVEAU)** | Implémenter greedy O(n log n) pour le problème 1 | `/cg cost 2840 7` → "7x Copper Bar = 36s (via listings 1,2,3)" |

**Fin de Phase A :** le calculateur de coût est **réaliste** pour un seul item. Les prix ne sont plus "fixes", mais recalculés dynamiquement à chaque scan HdV.

### Phase B : Single-Item Profitability (Capsules 12-13)

| # | Capsule | Concepts clés | Livrables |
|---|---------|---------------|-----------|
| 12 | **Recipe Cost (NOUVEAU)** | Aggréger composants d'une recette, appliquer min-cost-calculator | `/cg recipe 10644` → "Copper Modulator = 36s (2×Copper Bolt @18s each)" |
| 13 | **Profit Analysis (révisée)** | Profit = `sell_price - recipe_cost`, rank par profit | `/cg analyze` → classe par profit réel |
| 14 | **Profit Window** | UI pour filtrer, trier, afficher top 10 crafts | fenêtre CraftGold, scrollable |

**Fin de Phase B :** objectif 2 (crafts rentables) **résolu** avec des prix réalistes.

### Phase C : Leveling Planner (Capsules 15-17) — *Probabilités*

| # | Capsule | Concepts clés | Livrables |
|---|---------|---------------|-----------|
| 15 | **Recipe Color & Skillup (NOUVEAU)** | Seuils orange/jaune/vert/gris, proba(color) | `/cg color 10644 skill:50` → "orange (100%)" |
| 16 | **Estimated Leveling Cost (NOUVEAU)** | Estimer coût moyen/point en agrégant composants, ~50 crafts | `/cg level-cost 10644 skill:50` → "3s20c/point" |
| 17 | **DP Leveling Planner (NOUVEAU)** | Construire graphe recette→coût/point, résoudre DP, tracer chemin optimal | `/cg plan 0 300` → "recettes optimales: [10644×40, 10645×60, ...]" |

**Fin de Phase C :** objectif 1 (leveling planner) **résolu**.

### Phase D : Intégration & Polish (Capsules 18-19)

| # | Capsule | Concepts clés | Livrables |
|---|---------|---------------|-----------|
| 18 | **Full DB & Persistence** | DB complète Engineering 1-300, cache listings, SavedVariables | `/cg dump` → dump JSON pour vérif |
| 19 | **CraftGold v1** | Intégration Trade Skill UI, polish, tester bouts à bouts | addon "prêt production" |

---

## 6. Architecture des capsules (détail pédagogique)

### Capsule 8 : AH Listings Model

**Objectif** : changer le modèle de données de "1 prix" à "liste de listings".

```lua
-- AVANT (capsule 7)
CraftGoldDB.prices[2840] = {gold=0, silver=12, copper=40}

-- APRÈS (capsule 8)
CraftGoldDB.listings[2840] = {
  {price=100, qty=1},    -- 1s
  {price=500, qty=5},    -- 5s
  {price=1000, qty=20},  -- 10s
  {price=1500, qty=1},   -- 15s
}
```

**Tests** :
```lua
assert(#CraftGoldDB.listings[2840] == 4)
assert(CraftGoldDB.listings[2840][1].price == 100)
```

**Pas d'UI** (données seulement).

### Capsule 9 : Item Info

**Objectif** : resolver itemID → nom via `GetItemInfo()`, avec cache asynchrone.

```lua
function CraftGold_GetItemName(itemId, callback)
  if CraftGold.itemCache[itemId] then
    return callback(CraftGold.itemCache[itemId])
  end
  
  -- Hook async GetItemInfo
  local name = GetItemInfo(itemId)
  if name then
    CraftGold.itemCache[itemId] = name
    callback(name)
  else
    -- itemId introuvable, cache "nil"
    CraftGold.itemCache[itemId] = nil
    callback(nil)
  end
end

-- Usage
CraftGold_GetItemName(2840, function(name)
  print(name)  -- "Copper Bar"
end)
```

**Tests** :
```lua
CraftGold_GetItemName(2840, function(name)
  assert(name == "Copper Bar")
end)
```

### Capsule 10 : AH Scanner (révisée)

**Objectif** : scanner l'HdV, repeupler le modèle listings avec données réelles.

```lua
function CraftGold_ScanItem(itemName, callback)
  QueryAuctionItems(itemName, 0, 0, 1, false, 0, false, false)
  
  local hooked = false
  local listener = function()
    if hooked then return end
    hooked = true
    
    CraftGold.listings[itemId] = {}
    for i = 1, GetNumAuctionItems("list") do
      local name, texture, count, quality, canUse, level, dealer, duration, 
            buyoutPrice, bidAmount, highBidder, owner = GetAuctionItemInfo("list", i)
      
      if buyoutPrice then
        local pricePerUnit = buyoutPrice / count
        table.insert(CraftGold.listings[itemId], {
          price = pricePerUnit,
          qty = count,
          raw_buyout = buyoutPrice,
        })
      end
    end
    
    table.sort(CraftGold.listings[itemId], function(a,b) 
      return a.price < b.price 
    end)
    
    callback(CraftGold.listings[itemId])
  end
  
  CraftGold.frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
  CraftGold.frame:SetScript("OnEvent", listener)
end
```

**Tests** :
```lua
CraftGold_ScanItem("Copper Bar", function(listings)
  assert(#listings > 0)
  assert(listings[1].price < listings[2].price)  -- trié
end)
```

### Capsule 11 : Min Cost Calculator

**Objectif** : implémenter l'algorithme greedy pour le problème 1.

```lua
function CraftGold_GetMinCostForQuantity(itemId, need)
  local listings = CraftGold.listings[itemId]
  if not listings or #listings == 0 then
    return nil, "no listings"
  end
  
  -- déjà trié par price croissant (depuis capsule 10)
  local cost, bought = 0, 0
  local path = {}
  
  for _, listing in ipairs(listings) do
    if bought >= need then break end
    local toBuy = math.min(need - bought, listing.qty)
    cost = cost + (toBuy * listing.price)
    bought = bought + toBuy
    table.insert(path, {listing, toBuy})
  end
  
  if bought < need then
    return nil, "insufficient stock"
  end
  
  return cost, path
end
```

**Tests** :
```lua
CraftGold.listings[2840] = {
  {price=100, qty=1},
  {price=500, qty=5},
  {price=1000, qty=20},
}

local cost, path = CraftGold_GetMinCostForQuantity(2840, 7)
assert(cost == 100 + 500 + 100)  -- 1×1 + 5×5 + 1×20 = 601 copper
assert(#path == 3)
```

**Fin de Phase A :** `/cg cost 2840 7` → "36s 1c" (affiché via une première UI basique, chat ou popup).

---

### Capsule 12 : Recipe Cost

**Objectif** : aggréger composants d'une recette, appliquer `GetMinCostForQuantity` à chaque.

```lua
function CraftGold_GetRecipeCost(recipeId)
  local recipe = CraftGold.recipes[recipeId]
  if not recipe then return nil end
  
  local totalCost = 0
  local components = {}
  
  for _, comp in ipairs(recipe.components) do
    local itemId, qty = comp[1], comp[2]
    local cost, path = CraftGold_GetMinCostForQuantity(itemId, qty)
    
    if not cost then
      return nil, "can't buy " .. itemId
    end
    
    totalCost = totalCost + cost
    table.insert(components, {itemId, qty, cost})
  end
  
  return totalCost, components
end
```

**Tests** :
```lua
-- Recipe: Copper Modulator (10644)
--   - 2× Copper Bolt
--   - 1× Power Core

local cost, comps = CraftGold_GetRecipeCost(10644)
assert(cost > 0)
assert(#comps == 2)  -- 2 composants
```

### Capsule 13 : Profit Analysis (révisée)

**Objectif** : calculer profit = sellPrice - recipeCost (avec prix réalistes).

```lua
function CraftGold_AnalyzeProfits()
  local profitList = {}
  
  for recipeId, recipe in ipairs(CraftGold.recipes) do
    local craftCost, _ = CraftGold_GetRecipeCost(recipeId)
    if craftCost then
      local sellPrice = CraftGold_GetItemSellPrice(recipe.output_itemId)
      if sellPrice then
        local profit = sellPrice - craftCost
        table.insert(profitList, {
          recipeId = recipeId,
          profit = profit,
          craftCost = craftCost,
          sellPrice = sellPrice,
        })
      end
    end
  end
  
  table.sort(profitList, function(a,b) return a.profit > b.profit end)
  return profitList
end

function CraftGold_GetItemSellPrice(itemId)
  -- Scanner l'HdV, trouver le prix de VENTE (min listing)
  -- ... implémentation similar à GetMinCostForQuantity
end
```

**Tests** :
```lua
local profits = CraftGold_AnalyzeProfits()
assert(profits[1].profit >= profits[2].profit)  -- trié décroissant
```

### Capsule 14 : Profit Window

**Objectif** : UI pour afficher top 10 crafts profitables (scroll, sélection, détails).

```lua
function CraftGold_CreateProfitWindow()
  local frame = CreateFrame("Frame", "CraftGoldProfitWindow", UIParent, "BackdropTemplate")
  frame:SetSize(400, 300)
  frame:SetPoint("CENTER")
  frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background"})
  frame:SetTitle("CraftGold — Profits")
  
  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", frame, 10, -30)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, -10, 10)
  
  local listFrame = CreateFrame("Frame", nil, scrollFrame)
  listFrame:SetSize(400-20, 1)  -- height auto
  scrollFrame:SetScrollChild(listFrame)
  
  local profits = CraftGold_AnalyzeProfits()
  local y = 0
  
  for i = 1, math.min(10, #profits) do
    local p = profits[i]
    local itemText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemText:SetPoint("TOPLEFT", listFrame, 10, y)
    itemText:SetText(string.format("%s: +%s", GetItemInfo(p.output_itemId), FormatCurrency(p.profit)))
    y = y - 20
  end
  
  listFrame:SetHeight(-y)
  return frame
end
```

**Fin Phase B :** objectif 2 résolu, UI fonctionnelle.

---

### Capsule 15 : Recipe Color & Skillup

**Objectif** : mapper recette + skill → couleur + probabilité de skillup.

```lua
-- Données : seuils pour Engineering (exemple, à compléter)
CraftGold.recipeColors = {
  [10644] = {  -- Copper Modulator
    {skillFrom=0, skillTo=50, color="orange", prob=1.0},
    {skillFrom=50, skillTo=90, color="yellow", prob=0.75},
    {skillFrom=90, skillTo=120, color="green", prob=0.25},
    {skillFrom=120, color="grey", prob=0.0},
  },
  -- ... 25 autres recettes
}

function CraftGold_GetRecipeColor(recipeId, currentSkill)
  local colors = CraftGold.recipeColors[recipeId]
  if not colors then return nil end
  
  for _, entry in ipairs(colors) do
    if currentSkill >= entry.skillFrom and 
       (not entry.skillTo or currentSkill < entry.skillTo) then
      return entry.color, entry.prob
    end
  end
  
  return "grey", 0.0
end
```

**Tests** :
```lua
local color, prob = CraftGold_GetRecipeColor(10644, 40)
assert(color == "orange" and prob == 1.0)

local color, prob = CraftGold_GetRecipeColor(10644, 70)
assert(color == "yellow" and prob == 0.75)
```

### Capsule 16 : Estimated Leveling Cost

**Objectif** : coût moyen par point = crafts necessaire pour monter de 1 point × coût par craft.

```lua
function CraftGold_EstimateLevelingCost(recipeId, currentSkill)
  -- 1. Obtenir la couleur et la probabilité
  local color, prob = CraftGold_GetRecipeColor(recipeId, currentSkill)
  if prob == 0 then return nil end
  
  -- 2. Obtenir le coût du craft
  local craftCost, _ = CraftGold_GetRecipeCost(recipeId)
  if not craftCost then return nil end
  
  -- 3. Coût moyen par point = coût craft / prob
  local costPerPoint = craftCost / prob
  
  return {
    craftCost = craftCost,
    prob = prob,
    costPerPoint = costPerPoint,
    color = color,
  }
end
```

**Tests** :
```lua
local est = CraftGold_EstimateLevelingCost(10644, 40)
assert(est.craftCost > 0)
assert(est.costPerPoint == est.craftCost / 1.0)  -- orange → prob 1.0

local est2 = CraftGold_EstimateLevelingCost(10644, 70)
assert(est2.costPerPoint == est2.craftCost / 0.75)  -- yellow
```

### Capsule 17 : DP Leveling Planner

**Objectif** : résoudre le DP pour trouver le chemin de skill 0→300 au coût minimum.

```lua
function CraftGold_OptimalLevelingPath(startSkill, endSkill)
  local numSkills = endSkill - startSkill + 1
  local dp = {}
  local parent = {}
  
  -- Initialisation
  for i = startSkill, endSkill do
    dp[i] = math.huge
  end
  dp[startSkill] = 0
  
  -- DP
  for skill = startSkill, endSkill - 1 do
    if dp[skill] == math.huge then goto continue end
    
    for _, recipe in ipairs(CraftGold.recipes) do
      local est = CraftGold_EstimateLevelingCost(recipe.id, skill)
      if est then
        local nextSkill = skill + 1
        local newCost = dp[skill] + est.costPerPoint
        
        if newCost < dp[nextSkill] then
          dp[nextSkill] = newCost
          parent[nextSkill] = {recipe = recipe.id, fromSkill = skill}
        end
      end
    end
    
    ::continue::
  end
  
  -- Reconstruction du chemin
  local path = {}
  local skill = endSkill
  while skill > startSkill do
    local p = parent[skill]
    if not p then break end
    table.insert(path, 1, {recipe = p.recipe, toSkill = skill})
    skill = p.fromSkill
  end
  
  return {
    totalCost = dp[endSkill],
    path = path,
  }
end
```

**Tests** :
```lua
local plan = CraftGold_OptimalLevelingPath(0, 300)
assert(plan.totalCost > 0)
assert(#plan.path > 0)
assert(plan.path[1].toSkill > 0)
```

**Fin Phase C :** `/cg plan 0 300` → affiche le chemin optimal avec coût total.

---

## 7. Implémentation : ordre exact de travail

```
Semaine 1:
  Capsule 8 : AH Listings Model (data, pas UI)
  Capsule 9 : Item Info (cache async)
  Capsule 10 : AH Scanner (test avec `/cg scan Copper Bar`)

Semaine 2:
  Capsule 11 : Min Cost Calculator (test avec `/cg cost 2840 7`)
  Capsule 12 : Recipe Cost (test `/cg recipe 10644`)
  Capsule 13 : Profit Analysis (test `/cg analyze`)

Semaine 3:
  Capsule 14 : Profit Window (UI)
  Capsule 15 : Recipe Color (data + test)
  Capsule 16 : Leveling Cost (test `/cg level-cost 10644 skill:40`)

Semaine 4:
  Capsule 17 : DP Leveling Planner (test `/cg plan 0 300`)
  Capsule 18 : Full DB + Persistence
  Capsule 19 : CraftGold v1, polish, intégration Trade Skill UI
```

---

## 8. Réponses directes à vos questions

### Question 1 : Quel algorithme pour l'HdV ?

**Réponse** : Greedy O(n log n). Pas NP-difficile pour un seul item. C'est essentiellement le **change-making problem** (rendre la monnaie) en sens inverse.

### Question 2 : Quel algorithme pour le leveling planner ?

**Réponse** : **Dynamic Programming O(300 × R)** où R ≈ 50. État = skill_level, transitions = recettes disponibles. Résout en <100ms en Lua.

### Question 3 : Comment structurer en capsules ?

**Réponse** : voir roadmap ci-dessus. **Phase A (listings réalistes)** → **Phase B (profits)** → **Phase C (leveling DP)** → **Phase D (polish)**. Chaque capsule = 1 concept atomic, testable indépendamment, puis intégré.

---

## 9. Notes implémentation Lua

### Async pattern pour GetItemInfo

```lua
-- GetItemInfo ne retourne quelque chose que si l'item a été vu en jeu
-- Il faut hooker les événements ou utiliser une queue

CraftGold.itemQueue = {}

function CraftGold_QueueItemInfo(itemId, callback)
  table.insert(CraftGold.itemQueue, {itemId, callback})
  CraftGold_ProcessItemQueue()
end

function CraftGold_ProcessItemQueue()
  if not CraftGold.frame:IsEventRegistered("BAG_UPDATE") then
    CraftGold.frame:RegisterEvent("BAG_UPDATE")
  end
end

CraftGold.frame:SetScript("OnEvent", function(self, event)
  if event == "BAG_UPDATE" then
    local item = table.remove(CraftGold.itemQueue, 1)
    if item then
      local itemId, callback = item[1], item[2]
      local name = GetItemInfo(itemId)
      if name then
        callback(name)
      else
        table.insert(CraftGold.itemQueue, item)  -- retry
      end
    end
  end
end)
```

### SavedVariables structure

```lua
CraftGoldDB = {
  recipes = {...},  -- statique, hardcodé
  listings = {      -- dynamique, scanné
    [2840] = {{price=100, qty=1}, ...},
    [2841] = {...},
  },
  itemCache = {     -- async resolver
    [2840] = "Copper Bar",
  },
  profitCache = {   -- TTL = 1 heure
    timestamp = now(),
    profits = {...},
  },
}
```

---

## Conclusion

**Vos deux problèmes ne sont pas indépendants.** Le leveling planner est un super-ensemble du problème des listings réalistes. Mais la roadmap que je propose les démêle progressivement :

1. **Résoudre d'abord le problème 1** (listings) en isolation → profite imédiatement au profitability analyzer (objectif 2).
2. **Ajouter les probabilités** (capsule 15-16) sans changer les capsules précédentes.
3. **Connecter le tout** (capsule 17) avec un DP global.

Chaque capsule reste **atomic**, **progressive**, et **testable indépendamment**. Vous pouvez faire une démo fonctionnelle à chaque étape.