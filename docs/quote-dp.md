# Quote DP — Covering Knapsack 0/1

> Concept introduit en capsule 11, validé par consultation multi-agents (Session 9).

## Problème

À l'HdV de WoW Classic Era, les stacks sont **indivisibles** — un buyout achète le listing entier. Étant donné :

- `listings[item] = { {count=20, buyout=10g}, {count=5, buyout=2s50c}, ... }`
- Un besoin de Q unités

Trouver le **coût minimum** pour obtenir au moins Q unités, en choisissant quels stacks acheter.

## Pourquoi pas glouton ?

Le glouton (trier par coût unitaire croissant, prendre tant que Q pas atteint) est **souvent bon mais parfois mauvais** :

| Listing | Coût | Par unité |
|---------|------|-----------|
| 100 items | 1000c | 10c/unité ← glouton prend celui-là |
| 3 items | 200c | 66.7c/unité |
| 3 items | 200c | 66.7c/unité |

Besoin : 6. Glouton = 1000c (94 surplus). DP = 400c (0 surplus).

## Algorithme DP

```
dp[q] = coût minimum pour obtenir AU MOINS q unités
dp[0] = 0, dp[1..need] = ∞

Pour chaque listing i (0/1) :
  Pour q de need à 0 (décroissant) :
    Si dp[q] < ∞ :
      newQ = min(need, q + count[i])
      dp[newQ] = min(dp[newQ], dp[q] + buyout[i])

Résultat : dp[need]
```

- **0/1** : itération décroissante sur q → chaque listing utilisé au plus une fois
- **Covering** : `min(need, q+count)` → on cappe à `need`, le surplus est implicite
- **Complexité** : O(need × nbListings) en temps, O(need) en espace

### Reconstruction du panier

On maintient `choice[q] = { listingIndex, prevQ }` quand on améliore `dp[q]`. Après la DP, on remonte depuis `need` :

```lua
local basket = {}
local q = need
while choice[q] do
    basket[#basket+1] = listings[choice[q].listingIndex]
    q = choice[q].prevQ
end
```

### Surplus

```
surplus = (somme des count des stacks achetés) - need
```

## API

```lua
ns.Quote.dpCover(listings, need)  -- → {cost, basket, surplus} | nil
ns.Quote.greedy(listings, need)   -- → {cost, basket, surplus} | nil (témoin)
ns.Quote.quote(itemID, quantity)  -- → {cost, basket, surplus} | nil (API publique)
```

## Utilisation en jeu

```
/cg quote <itemID> <qty>
```

Affiche : coût optimal, panier (stacks à acheter), surplus, et comparaison avec le glouton si différent.
