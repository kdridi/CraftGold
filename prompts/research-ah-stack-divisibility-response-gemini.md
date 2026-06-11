C'est un excellent problème d'ingénierie. Tu as tout à fait raison de te méfier de l'algorithme glouton ici, car la réalité du jeu rend ton modèle mathématique initial caduc.

Voici les faits, l'analyse algorithmique et la solution pour ton add-on.

## 1. Réponse factuelle : Stacks indivisibles (Option B)

Dans **World of Warcraft Classic Era**, l'Hôtel des Ventes fonctionne selon le modèle historique du jeu : **les stacks sont strictement indivisibles (Option B).**

Si un joueur met en vente 20 *Copper Bars* pour 2g, tu ne peux pas en acheter 7. Le clic droit (Buyout) achète l'intégralité du lot ou rien du tout.

**Sources et historique :**

* Le système d'achat fractionné (où les composants d'artisanat sont regroupés et où l'on peut acheter une quantité spécifique) n'a été introduit dans WoW que lors du **Patch 8.3 (Visions of N'Zoth)** sur la version Retail en janvier 2020.
* Toutes les versions Classic (Era, Hardcore, SoD, et les extensions progressives jusqu'à l'implémentation de ce patch spécifique) utilisent l'architecture d'origine de l'HdV basée sur des lots (`listings`) non fractionnables.

## 2. Le problème algorithmique et la contrainte de réalité

Ton instinct est le bon : puisqu'on ne peut pas fractionner, le glouton (trier par prix unitaire) échoue face aux grandes piles. Nous sommes face à une variante du **Problème du sac à dos 0/1 (0-1 Knapsack Problem)**, plus spécifiquement le **Set Cover Problem** (ou problème de couverture au coût minimum).

Tu as précisé que le temps d'exécution n'était pas un critère pour toi, car tu cherches l'optimalité pure. Je valide cette approche axée sur la qualité des données, mais **je dois apporter une correction factuelle liée au moteur de WoW** : le temps d'exécution *est* un critère, même si tu ne le souhaites pas.

Le client WoW impose une limite stricte de temps d'exécution ininterrompu pour le code Lua. Si ton calcul prend 2 minutes pour résoudre un arbre d'artisanat complexe, le client WoW va geler, puis crasher ton add-on avec une erreur fatale `Script ran too long`.

**La solution recommandée : La Programmation Dynamique (DP)**
Heureusement, nous pouvons avoir le beurre et l'argent du beurre. L'algorithme de programmation dynamique pour le sac à dos 0/1 garantit **100% d'optimalité** (il ne se trompe jamais), tout en ayant une complexité de temps de `O(M * N)` (où `M` est le nombre de listings et `N` la quantité requise). Pour les échelles de l'HdV (ex: 200 listings pour trouver 15 barres), Lua l'exécutera en une fraction de milliseconde, évitant tout crash.

## 3. Implémentation de la solution (Lua)

L'idée de l'algorithme est de construire un tableau `dp` où `dp[j]` représente le coût minimum garanti pour obtenir **exactement ou au moins** `j` composants.

On parcourt chaque listing de l'HdV un par un. Pour chaque listing, on regarde si l'ajouter à une de nos combinaisons précédentes permet d'atteindre une quantité `j` à un prix inférieur à ce qu'on connaissait jusqu'alors.

Voici le code Lua, prêt à être intégré dans ta capsule :

```lua
--[[
  Calcule la combinaison optimale de listings pour atteindre une quantité cible au moindre coût.
  
  @param listings: table - Un tableau de tables représentant les enchères { count = X, buyout = Y, id = Z }
  @param targetQty: number - La quantité exacte dont on a besoin
  @return number, table - Le coût total minimum, et le tableau des enchères sélectionnées
]]
function CraftGold_GetOptimalBuyout(listings, targetQty)
    -- Initialisation du tableau de programmation dynamique
    -- dp[i] contient { cost = minimum_cost, selection = { list_of_listings } }
    local dp = {}
    
    -- On doit aller de 0 jusqu'à la quantité cible
    for i = 0, targetQty do
        dp[i] = { cost = math.huge, selection = {} }
    end
    
    -- Le coût pour 0 composant est de 0
    dp[0].cost = 0

    -- On évalue chaque listing de l'HdV
    for _, listing in ipairs(listings) do
        local count = listing.count
        local price = listing.buyout

        -- On parcourt à l'envers pour s'assurer qu'on utilise chaque listing au maximum UNE fois (Sac à dos 0/1)
        for j = targetQty, 0, -1 do
            -- Si on a un chemin valide pour atteindre la quantité 'j'
            if dp[j].cost ~= math.huge then
                
                -- Si on achète ce listing en plus, combien en aura-t-on ?
                -- On cap à targetQty, car tout ce qui dépasse nous intéresse uniquement 
                -- si ça valide notre objectif final moins cher.
                local newQty = math.min(targetQty, j + count)
                local newCost = dp[j].cost + price

                -- Si ce nouveau coût est plus intéressant que le précédent pour cette quantité
                if newCost < dp[newQty].cost then
                    dp[newQty].cost = newCost
                    
                    -- On copie la sélection d'objets précédente et on y ajoute le listing actuel
                    local newSelection = {}
                    for _, selectedListing in ipairs(dp[j].selection) do
                        table.insert(newSelection, selectedListing)
                    end
                    table.insert(newSelection, listing)
                    
                    dp[newQty].selection = newSelection
                end
            end
        end
    end

    -- Retourne le coût minimal pour la cible, et la liste exacte des achats à effectuer
    return dp[targetQty].cost, dp[targetQty].selection
end

-- ==========================================
-- EXEMPLE D'UTILISATION (Ton cas d'école)
-- ==========================================
local ahListings = {
    { id = 1, count = 20, buyout = 4000 }, -- 20 unités pour 40s (2s/u) -> Listing A
    { id = 2, count = 2,  buyout = 1000 }, -- 2 unités pour 10s (5s/u) -> Listing B
    { id = 3, count = 1,  buyout = 800  }  -- Bruit de fond
}

local cost, toBuy = CraftGold_GetOptimalBuyout(ahListings, 2)

print("Coût optimal : " .. cost .. " cuivres")
-- Affichera : Coût optimal : 1000 cuivres
-- toBuy contiendra uniquement le { id = 2, count = 2, buyout = 1000 }

```

### Pourquoi cet algorithme est parfait pour toi :

1. **Zéro heuristique, 100% mathématique** : Il n'essaie pas de deviner. Il prouve la combinaison la moins chère, y compris s'il faut acheter un stack de 20 et un stack de 1 pour atteindre 21.
2. **Cap sur l'objectif (`math.min`)** : C'est la clé de la solution. En plafonnant l'index à `targetQty`, l'algorithme comprend automatiquement qu'acheter 20 unités pour satisfaire un besoin de 2 unités mettra à jour la case "Objectif de 2 atteint".
3. **Traçabilité** : Le tableau `selection` te permet de dire exactement à l'utilisateur : *"Achète le lot de 2 à 10s de xXxArthasxXx"*.