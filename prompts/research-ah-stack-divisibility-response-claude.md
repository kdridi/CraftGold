# Stacks indivisibles vs fractionnaires — réponse factuelle et algorithme

## 1. Réponse factuelle : **Option B — le stack est indivisible**

En Classic Era, un buyout achète **obligatoirement le listing entier**. Si le listing est Copper Bar x20 à 2g, tu paies 2g et tu reçois 20 barres — il n'existe aucun mécanisme d'achat partiel.

Sources :

- **Wowpedia (Auction House)**, décrivant le système d'enchères classique : les acheteurs ne peuvent pas fractionner un stack lors de l'achat, raison pour laquelle il est conseillé aux vendeurs de découper leurs gros stacks à la mise en vente ; le wiki met aussi en garde contre le fait de payer le prix d'un stack plein pour un stack incomplet, et recommande de trier par prix unitaire. Toute cette section (choix de la taille de stack par le vendeur, prix « per item » vs « per stack ») n'a de sens que parce que l'unité d'achat est le listing.
- **Preuve par contraste — le patch 8.3 de Retail** : l'achat fractionnaire de « commodities » est précisément la grande nouveauté de la refonte de l'HdV de Retail fin 2019. Blizzard (via le community manager Kaivax) annonçait que les objets empilables ne seraient plus achetés ni vendus par stacks : l'acheteur saisit une quantité et l'HdV sélectionne automatiquement les enchères les moins chères — c'est le comportement de ton Option A, introduit comme une *nouveauté* de Retail. Classic Era utilise l'ancien système, antérieur à cette refonte : c'est même un de ses marqueurs « vanilla ».
- **Côté API** : ça se voit dans les fonctions que tu utilises déjà. `GetAuctionItemInfo("list", index)` retourne un `buyoutPrice` et un `count` par *listing*, et `PlaceAuctionBid("list", index, buyoutPrice)` opère sur un index de listing entier — il n'y a aucun paramètre de quantité. Les add-ons d'achat de masse comme AuctionLite confirment ce modèle : l'achat se fait listing par listing (sélection de listings puis buyout, avec une validation par listing).

Ton problème est donc bien le **covering knapsack 0/1**, et ton contre-exemple (besoin de 2 unités, glouton qui paie 40s au lieu de 10s) est exactement le mode d'échec du tri par prix unitaire.

## 2. Algorithme recommandé : programmation dynamique exacte

Bonne nouvelle qui rend ta précision sur la performance presque superflue : **il existe un algorithme exact** (pas une heuristique, pas une approximation) **et il est de surcroît rapide**. Tu n'as pas à choisir entre optimalité et vitesse.

C'est la programmation dynamique du covering knapsack :

- État : `dp[k]` = coût minimal pour obtenir **au moins** `k` unités, pour `k` de 0 à `Q`.
- Transition : pour chaque listing `(count, buyout)`, traité une seule fois (0/1), `dp[min(Q, k + count)] = min(dp[…], dp[k] + buyout)`.
- Le plafonnement à `Q` (`min(Q, k + count)`) encode « le surplus est gratuit mais inutile » : tout état au-delà de `Q` unités est équivalent à l'état `Q`. C'est ce qui permet de découvrir qu'un gros stack excédentaire peut être optimal — ou pas.

**Garantie d'optimalité** : la DP énumère implicitement *tous* les sous-ensembles de listings (chaque sous-ensemble correspond à un chemin dans la table) et n'en fusionne que ceux qui sont strictement équivalents pour la suite (même quantité couverte, plafonnée à `Q`). Le résultat `dp[Q]` est donc le minimum global exact — identique à ce que donnerait une énumération brute des `2ⁿ` sous-ensembles, mais en `O(n × Q)`. Pour `n = 200` listings et `Q = 1000` unités, c'est 200 000 opérations : de l'ordre de la milliseconde en Lua, très loin de tes 2 minutes de budget.

Deux raffinements que je recommande, puisque ton seul critère est la qualité du résultat :

1. **Critère secondaire de départage** : plusieurs solutions peuvent avoir le même coût minimal (ex. deux façons de payer 41s). Il est naturel de préférer celle qui achète le moins d'unités excédentaires (moins d'encombrement de sacs, surplus revendable mais à frais). On départage lexicographiquement : minimiser le coût, puis le nombre total d'unités achetées.
2. **Reconstruction du panier** : `dp[Q]` te donne le coût, mais l'add-on doit dire *quels listings acheter*. On garde une table de décisions et on remonte.

## 3. Code Lua complet

```lua
-- listings : tableau de { count = <int>, buyout = <int en cuivre>, index = <index HdV> }
-- need     : quantité requise (>= 1)
-- Retourne : coûtTotal, unitésAchetées, { listings retenus } 
--            ou nil si le stock total est insuffisant.
function CG.OptimalPurchase(listings, need)
    local n   = #listings
    local INF = math.huge

    -- dp[i][k] = { cost, units } : meilleur (coût, puis unités) pour couvrir
    -- au moins k unités en n'utilisant que les listings 1..i.
    -- take[i][k] = true si le listing i est pris dans cette solution optimale.
    local dp, take = {}, {}

    -- Ligne 0 : aucun listing disponible.
    dp[0] = {}
    dp[0][0] = { cost = 0, units = 0 }
    for k = 1, need do dp[0][k] = { cost = INF, units = INF } end

    -- better(a, b) : a strictement meilleur que b ?
    -- Critère lexicographique : coût minimal, puis surplus minimal.
    local function better(a, b)
        if a.cost ~= b.cost then return a.cost < b.cost end
        return a.units < b.units
    end

    for i = 1, n do
        local L = listings[i]
        dp[i], take[i] = {}, {}
        for k = 0, need do
            -- Option 1 : ne pas prendre le listing i.
            local best, taken = dp[i-1][k], false
            -- Option 2 : prendre le listing i. Il couvre L.count unités ;
            -- l'état d'origine est la quantité restante AVANT cet achat.
            local from = math.max(0, k - L.count)
            local prev = dp[i-1][from]
            if prev.cost < INF then
                local cand = { cost = prev.cost + L.buyout,
                               units = prev.units + L.count }
                if better(cand, best) then best, taken = cand, true end
            end
            dp[i][k]   = best
            take[i][k] = taken
        end
    end

    local final = dp[n][need]
    if final.cost == INF then return nil end   -- stock insuffisant à l'HdV

    -- Reconstruction du panier : on remonte la table de décisions.
    local basket, k = {}, need
    for i = n, 1, -1 do
        if take[i][k] then
            table.insert(basket, listings[i])
            k = math.max(0, k - listings[i].count)
        end
    end

    return final.cost, final.units, basket
end
```

Exemple d'utilisation sur ton cas Copper Bar :

```lua
local listings = {
    { count = 1,  buyout = 100,   index = 1 },  -- 1s
    { count = 5,  buyout = 2500,  index = 2 },  -- 25s
    { count = 20, buyout = 20000, index = 3 },  -- 2g
    { count = 1,  buyout = 1500,  index = 4 },  -- 15s
}
local cost, units, basket = CG.OptimalPurchase(listings, 7)
-- cost = 4100 (41s), units = 7, basket = listings 1, 2 et 4
-- Avec need = 16, l'algorithme basculerait de lui-même sur le stack x20 (2g)
-- dès que la somme des petits listings dépasse 2g : aucun cas particulier à coder.
```

Notes d'implémentation :

- **Mémoire** : la table 2D `take` coûte `n × (Q+1)` booléens — pour 200 listings × 1000 unités, c'est négligeable. Si un jour tu agrèges des quantités énormes, tu peux passer à une DP 1D + reconstruction par re-calcul, mais inutile d'optimiser prématurément vu ton cahier des charges.
- **`buyoutPrice = 0`** : à l'HdV Classic, un listing peut être *sans buyout* (enchère pure). Filtre `buyout > 0` avant d'appeler la fonction — on ne peut pas « acheter » une enchère, et l'inclure fausserait le résultat.
- **Stock insuffisant** : le retour `nil` est une information précieuse en soi pour CraftGold (« il n'y a pas 847 Copper Bars à vendre aujourd'hui ») — affiche-la plutôt que de la masquer.
- **Doublons de scan** : `GetAuctionItemInfo` paginé peut renvoyer des listings identiques sur des pages successives si l'HdV bouge pendant le scan ; déduplique par index/signature avant l'optimisation, sinon la DP croira pouvoir acheter deux fois le même stack.

En résumé : Classic Era = stacks indivisibles (Option B), donc covering knapsack ; et la DP ci-dessus en donne la solution **exactement optimale**, avec reconstruction du panier, pour un coût de calcul dérisoire.