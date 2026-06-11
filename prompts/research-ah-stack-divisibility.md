# Consultation — Achat de stacks indivisibles vs fractionnaires à l'Hôtel des Ventes

## Contexte

Suite à notre consultation précédente sur CraftGold (add-on WoW Classic Era), les 4 LLM consultés ont proposé des algorithmes différents pour résoudre le problème du coût réel d'achat à l'Hôtel des Ventes. Le désaccord porte sur un point factuel qui conditionne tout l'algorithme.

## La question factuelle

**En WoW Classic Era, quand on achète un listing à l'Hôtel des Ventes (clic droit → Buyout), achète-t-on le stack entier ou peut-on en acheter une fraction ?**

Par exemple, si un listing propose Copper Bar x20 à 2g buyout :
- **Option A** : on peut acheter seulement 7 Copper Bars pour un prix proportionnel
- **Option B** : on doit obligatoirement acheter les 20 pour 2g entier

## Pourquoi c'est fondamental

Si **achat fractionnaire** (A) → un simple tri par prix unitaire suffit (glouton optimal). On trie par prix unitaire croissant, on "achète" virtuellement jusqu'à couvrir la quantité voulue, chaque unité coûtant son prix unitaire.

Si **stacks indivisibles** (B) → c'est un covering knapsack 0/1. On doit choisir quels stacks entiers acheter pour couvrir la quantité souhaitée au coût minimal. Le glouton peut se tromper :

```
Besoin : 7 Copper Bars

Listing 1 : x1 à 1s
Listing 2 : x5 à 25s
Listing 3 : x20 à 2g
Listing 4 : x1 à 15s

Glouton (tri prix unitaire) : L1(1s) + L2(25s) + L4(15s) = 41s → 7 bars ✅
DP exact : même résultat ici, mais il existe des contre-exemples
```

```
Contre-exemple :
Besoin : 2 unités

Listing A : x20 à 2s/unité → 40s total
Listing B : x2 à 5s/unité → 10s total

Glouton choisit A (prix unitaire plus bas) → paie 40s pour 20 unités
Optimal est B → paie 10s pour exactement 2 unités
```

## Précision importante : performance n'est PAS un critère

Parmi les algorithmes candidats, **le temps d'exécution n'est pas un critère de choix**. Même si le calcul prend 2 minutes en Lua, ce n'est pas un problème. L'objectif est le **résultat le plus optimal possible**. Ne privilégiez pas un algorithme plus rapide s'il donne un résultat moins précis.

## Ce que j'attends

1. **Réponse factuelle** : stacks indivisibles ou fractionnaires en Classic Era ? Citez vos sources (wowpedia, warcraft.wiki.gg, expérience en jeu, code source d'add-ons, forums).
2. **Quel algorithme recommandez-vous** sachant que l'optimalité du résultat est le seul critère ?
3. **Code Lua** de l'algorithme recommandé (ou pseudo-code si vous préférez).

## Format de réponse

Réponse en **markdown dans un seul bloc texte**. Pas de fichiers séparés, pas d'artifacts. Tout inline.
