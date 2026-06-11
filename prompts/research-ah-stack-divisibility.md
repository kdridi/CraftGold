# Consultation — Achat de stacks indivisibles vs fractionnaires à l'Hôtel des Ventes WoW Classic Era

## Contexte

Je développe **CraftGold**, un add-on World of Warcraft Classic Era (Lua). L'un des objectifs est de calculer le **coût réel exact** de l'achat de composants à l'Hôtel des Ventes, en tenant compte du fait que l'HdV présente des listings de tailles et prix différents.

## La question factuelle

**En WoW Classic Era, quand on achète un listing à l'Hôtel des Ventes (clic droit → Buyout), achète-t-on le stack entier ou peut-on en acheter une fraction ?**

Par exemple, si un listing propose Copper Bar x20 à 2g buyout :
- **Option A** : on peut acheter seulement 7 Copper Bars pour un prix proportionnel
- **Option B** : on doit obligatoirement acheter les 20 pour 2g entier

## Pourquoi c'est fondamental

Si **achat fractionnaire** (A) → un simple tri par prix unitaire suffit (glouton optimal). On trie par prix unitaire croissant, on "achète" virtuellement jusqu'à couvrir la quantité voulue, chaque unité coûtant son prix unitaire.

Si **stacks indivisibles** (B) → c'est un covering knapsack 0/1. On doit choisir quels stacks entiers acheter pour couvrir la quantité souhaitée au coût minimal. Le glouton peut se tromper :

```
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
