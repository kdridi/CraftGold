# Réponse courte

En **WoW Classic Era**, pour l’Hôtel des Ventes classique, l’achat est **par auction/listing entier**. Tu ne peux pas acheter 7 Copper Bars à l’intérieur d’un listing `Copper Bar x20`. Si tu buyout ce listing, tu achètes les **20** pour le prix total du listing.

Donc c’est bien ton **Option B** :

```text
Listing : Copper Bar x20 — buyout 2g
Achat   : Copper Bar x20 — coût 2g
```

Conséquence directe pour CraftGold : le modèle exact est bien un **covering knapsack 0/1**, pas un simple tri glouton par prix unitaire.

---

# 1. Réponse factuelle : stacks indivisibles ou fractionnaires ?

## En Classic Era : stacks indivisibles

Les sources communautaires décrivent explicitement l’ancienne logique AH : les acheteurs ne peuvent pas “casser” un stack lors de l’achat. Warcraft Wiki indique que les acheteurs ne peuvent pas diviser les stacks, et Wowpedia formule la même règle : puisque les acheteurs ne peuvent pas casser un stack à l’achat, il est conseillé aux vendeurs de poster des tailles pratiques. ([Warcraft Wiki][1])

C’est cohérent avec l’API ancienne utilisée par Classic Era : `GetAuctionItemInfo("list", index)` retourne une auction à un index donné avec un `count` et un `buyoutPrice`; `buyoutPrice` est le prix de l’auction item, pas un prix partiel demandé pour une quantité arbitraire. ([WoWWiki Archive][2])

C’est aussi cohérent avec `PlaceAuctionBid("list", index, bid)`, dont la signature cible un **type de liste**, un **index d’auction**, et un montant en cuivre. Il n’y a aucun paramètre `quantity` dans cette API d’achat ancienne. ([AddOn Studio][3])

Auctionator ClassicFix va dans le même sens pratique : il annonce trier les **itemstacks** par prix par item, afficher les stack prices, et permettre d’acheter des stacks rapidement. Autrement dit : le prix unitaire est une information de comparaison, mais l’objet acheté reste le stack/listing. ([CurseForge][4])

Donc pour CraftGold :

```text
Un listing AH Classic = un lot indivisible.
```

Ton exemple est donc exact :

```text
Besoin : 2 unités

Listing A : x20 à 40s total, soit 2s/unité
Listing B : x2  à 10s total, soit 5s/unité

Glouton par prix unitaire -> choisit A -> paie 40s
Optimal exact             -> choisit B -> paie 10s
```

---

# 2. Algorithme recommandé si l’optimalité est le seul critère

## Problème formel

Pour un item donné :

```text
Besoin : Q unités

Listings :
L1 = count c1, buyout p1
L2 = count c2, buyout p2
...
Ln = count cn, buyout pn
```

On cherche un sous-ensemble de listings tel que :

```text
sum(count_i) >= Q
```

et qui minimise :

```text
sum(buyout_i)
```

Chaque listing peut être choisi au plus une fois :

```text
acheter le listing
ou
ne pas acheter le listing
```

C’est donc un :

```text
0/1 minimum cost covering knapsack
```

ou, plus simplement pour CraftGold :

```text
choix optimal de lots indivisibles pour couvrir une quantité demandée
```

## Recommandation

Utilise une **programmation dynamique exacte par quantité**.

Elle est exacte, déterministe, testable hors WoW, facile à expliquer pédagogiquement, et parfaitement adaptée à Lua.

L’idée :

```text
dp[q] = coût minimal pour obtenir exactement q unités
```

Puis on prend le meilleur `q >= need`.

On ne doit pas aller jusqu’à la somme totale de tous les listings. Il suffit d’aller jusqu’à :

```lua
cap = need + maxListingCount - 1
```

Pourquoi ? Si une solution optimale achetait au moins `need + maxListingCount` unités, on pourrait retirer un des listings achetés. Comme chaque listing contient au plus `maxListingCount` unités, on resterait encore à `>= need`, avec un coût inférieur. Donc cette solution ne pouvait pas être optimale.

---

# 3. Code Lua exact

Voici une version pure Lua, indépendante de WoW, adaptée à ton architecture CraftGold.

```lua
--[[
  Résout exactement :
    choisir des listings AH indivisibles
    pour obtenir au moins `need` unités
    au coût buyout total minimal.

  Chaque listing attendu :
    {
      itemID = 2840,          -- optionnel ici
      count = 20,             -- nombre d'items dans le stack
      buyout = 20000,         -- prix total du stack en copper
      index = 17,             -- optionnel : index AH
      page = 0,               -- optionnel : page AH
      owner = "SellerName",   -- optionnel
    }

  Retour :
    {
      cost = 4100,
      bought = 7,
      surplus = 0,
      listings = { ... },
    }

  Ou nil si aucune combinaison ne peut couvrir le besoin.
]]

local function QuoteIndivisibleStacks(listings, need)
  assert(type(listings) == "table", "listings must be a table")
  assert(type(need) == "number", "need must be a number")
  assert(need >= 0, "need must be >= 0")

  if need == 0 then
    return {
      cost = 0,
      bought = 0,
      surplus = 0,
      listings = {},
    }
  end

  local usable = {}
  local maxCount = 0

  -- On ne garde que les listings immédiatement achetables en buyout.
  -- buyout == 0 signifie généralement "pas de buyout", donc pas utilisable
  -- pour un coût d'achat immédiat exact.
  for _, a in ipairs(listings) do
    local count = a.count
    local buyout = a.buyout or a.buyoutPrice

    if type(count) == "number"
      and type(buyout) == "number"
      and count > 0
      and buyout > 0
    then
      local copy = {}

      for k, v in pairs(a) do
        copy[k] = v
      end

      copy.buyout = buyout
      copy.count = count

      table.insert(usable, copy)

      if count > maxCount then
        maxCount = count
      end
    end
  end

  if #usable == 0 then
    return nil
  end

  local cap = need + maxCount - 1
  local INF = 10 ^ 18

  local dpCost = {}
  local dpNumListings = {}
  local prevQty = {}
  local prevListingIndex = {}

  for q = 0, cap do
    dpCost[q] = INF
    dpNumListings[q] = INF
  end

  dpCost[0] = 0
  dpNumListings[0] = 0

  -- 0/1 knapsack :
  -- boucle descendante pour éviter de réutiliser le même listing plusieurs fois.
  for i, listing in ipairs(usable) do
    local c = listing.count
    local p = listing.buyout

    for q = cap - c, 0, -1 do
      if dpCost[q] < INF then
        local nq = q + c
        local nc = dpCost[q] + p
        local nn = dpNumListings[q] + 1

        -- Critère principal : coût minimal.
        -- Critère secondaire : moins de listings, donc moins de clics.
        if nc < dpCost[nq]
          or (nc == dpCost[nq] and nn < dpNumListings[nq])
        then
          dpCost[nq] = nc
          dpNumListings[nq] = nn
          prevQty[nq] = q
          prevListingIndex[nq] = i
        end
      end
    end
  end

  local bestQty = nil
  local bestCost = INF
  local bestNumListings = INF

  for q = need, cap do
    local cost = dpCost[q]
    local n = dpNumListings[q]

    -- Critère principal : coût minimal.
    -- Critère secondaire : moins de surplus.
    -- Critère tertiaire : moins de listings.
    if cost < bestCost
      or (cost == bestCost and bestQty ~= nil and q < bestQty)
      or (cost == bestCost and q == bestQty and n < bestNumListings)
    then
      bestQty = q
      bestCost = cost
      bestNumListings = n
    end
  end

  if not bestQty then
    return nil
  end

  local chosen = {}
  local q = bestQty

  while q > 0 do
    local i = prevListingIndex[q]

    if not i then
      break
    end

    table.insert(chosen, usable[i])
    q = prevQty[q]
  end

  -- Optionnel : ordre lisible par prix unitaire puis taille
  table.sort(chosen, function(a, b)
    local ua = a.buyout / a.count
    local ub = b.buyout / b.count

    if ua ~= ub then
      return ua < ub
    end

    if a.buyout ~= b.buyout then
      return a.buyout < b.buyout
    end

    return a.count < b.count
  end)

  return {
    cost = bestCost,
    bought = bestQty,
    surplus = bestQty - need,
    listings = chosen,
  }
end
```

---

# 4. Test avec ton exemple

```lua
local listings = {
  { count = 20, buyout = 4000, label = "A: x20 à 40s" },
  { count = 2,  buyout = 1000, label = "B: x2 à 10s" },
}

local quote = QuoteIndivisibleStacks(listings, 2)

print(quote.cost)    -- 1000
print(quote.bought)  -- 2
print(quote.surplus) -- 0

for _, a in ipairs(quote.listings) do
  print(a.label)
end
```

Résultat attendu :

```text
1000
2
0
B: x2 à 10s
```

Donc l’algorithme ne se fait pas piéger par le prix unitaire.

---

# 5. Test avec ton exemple Copper Bar x7

```lua
local listings = {
  { count = 1,  buyout = 100,   label = "x1 à 1s"  },
  { count = 5,  buyout = 2500,  label = "x5 à 25s" },
  { count = 20, buyout = 20000, label = "x20 à 2g" },
  { count = 1,  buyout = 1500,  label = "x1 à 15s" },
}

local quote = QuoteIndivisibleStacks(listings, 7)

print(quote.cost)    -- 4100 = 41s
print(quote.bought)  -- 7
print(quote.surplus) -- 0

for _, a in ipairs(quote.listings) do
  print(a.label)
end
```

Résultat attendu :

```text
4100
7
0
x1 à 1s
x5 à 25s
x1 à 15s
```

---

# 6. À intégrer dans CraftGold

Je recommande cette séparation :

```lua
AuctionScanner
  -> collecte les listings bruts depuis l'AH

ListingStore
  -> stocke les listings par itemID

QuoteEngine
  -> résout QuoteIndivisibleStacks(listings, need)

PriceOracle
  -> façade utilisée par le reste de CraftGold
```

Interface cible :

```lua
local quote = CraftGold.PriceOracle:Quote(2840, 7)
```

Retour :

```lua
{
  itemID = 2840,
  requested = 7,
  bought = 7,
  surplus = 0,
  cost = 4100,
  source = "auction-listings",
  listings = {
    { count = 1, buyout = 100, index = 3, page = 0 },
    { count = 5, buyout = 2500, index = 8, page = 0 },
    { count = 1, buyout = 1500, index = 12, page = 0 },
  },
}
```

Important : pour un coût “exact”, il faut exclure les auctions sans buyout :

```lua
if buyoutPrice == 0 then
  -- pas d'achat immédiat garanti
  -- donc pas utilisable pour le coût exact d'achat maintenant
end
```

Et il faut considérer le résultat comme exact **pour le snapshot scanné**, pas pour le marché futur. Une auction peut être achetée par quelqu’un d’autre entre le scan et l’achat.

---

# 7. Conclusion pour la roadmap

Ta capsule “prix réel AH” doit partir du principe suivant :

```text
Les stacks AH Classic Era sont indivisibles.
```

Donc :

```text
prix unitaire minimal     -> information utile pour affichage
tri par prix unitaire     -> heuristique d’interface
coût exact pour quantité  -> DP 0/1 minimum cover
```

Pour CraftGold, l’algorithme recommandé est donc :

```text
Exact 0/1 covering knapsack par programmation dynamique sur la quantité
```

C’est le bon choix parce que :

* il respecte la mécanique réelle de Classic Era ;
* il donne l’optimum exact ;
* il est testable hors WoW ;
* il se code simplement en Lua ;
* il prépare proprement le leveling planner et le calcul de profit réel.

[1]: https://warcraft.wiki.gg/wiki/Auction_House?utm_source=chatgpt.com "Auction House - Warcraft Wiki"
[2]: https://wowwiki-archive.fandom.com/wiki/API_GetAuctionItemInfo?utm_source=chatgpt.com "API GetAuctionItemInfo"
[3]: https://addonstudio.org/wiki/WoW%3AAPI_PlaceAuctionBid "WoW API: PlaceAuctionBid - AddOn Studio"
[4]: https://www.curseforge.com/wow/addons/auctionator-classicfix "Auctionator ClassicFix - World of Warcraft Addons - CurseForge"
