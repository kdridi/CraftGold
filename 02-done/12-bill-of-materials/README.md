# 12 — Bill of Materials

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données réelles                                   |
| Prerequisites | Capsule 11 — Quote DP                                       |
| Type          | Autonomous                                                  |
| Concepts      | Expansion récursive, agrégation, cotation de panier         |

## Why This Capsule?

La capsule 11 nous a donné `quote(itemID, qty)` — le coût exact pour acheter une quantité d'un item à l'HdV via DP knapsack. Mais en pratique, on veut crafter un objet complexe qui nécessite des composants, eux-mêmes potentiellement craftables. On a besoin de répondre à la question : **« Qu'est-ce que je dois acheter exactement, et combien ça coûte ? »**

C'est le rôle du **Bill of Materials (BOM)** : descendre récursivement dans l'arbre de craft, développer chaque composant craftable en ses sous-composants, jusqu'à n'obtenir plus que des matières premières. Puis agréger les quantités et coter le tout via `quote()`.

C'est aussi la fondation du **leveling planner** (capsules 18-21) : pour monter Engineering de 0 à 300, on aura besoin d'agréger les matériaux de dizaines de crafts.

## Ce qu'on a appris

### 1. Expansion récursive + agrégation

Le cœur du BOM est une fonction récursive `_expand(itemID, qty, state)` :

- Si l'item n'est **pas craftable** → matière première, on ajoute `qty` à `state.materials[itemID]`
- Si l'item est **craftable** → on descend dans chaque reagent × qty
- L'agrégation est naturelle : si Copper Bar apparaît via 2 chemins différents (direct + via Copper Bolts), on somme les quantités

Exemple concret — Rough Copper Bomb (4360) :
```
4360 → {2589×1, 2840×1, 4357×2, 4359×1}
  4357 → {2835×1}        (Rough Blasting Powder)
  4359 → {2840×1}        (Copper Bolts)

Résultat agrégé : 2589×1, 2840×2, 2835×2
```

### 2. Détection de cycles

Même mécanisme que le Calculator (capsule 07) : un set `visiting` marque les items en cours de traitement sur la call stack. Si on revoit le même item → cycle. On le traite comme matière première et on log un warning.

### 3. Cotation du panier via Quote.quote()

Pour chaque matière première agrégée, on appelle `Quote.quote(matID, matQty)` qui lance le DP knapsack. Le surplus (stacks indivisibles) est affiché par matière.

### 4. Bug CmdLang : nœuds hybrides (handler + subs)

**Pitfall rencontré** : on a enregistré `shoplist` avec un handler (`/cg shoplist 4360 1`) ET un sub (`/cg shoplist expand 4360 1`). CmdLang ne supportait pas ça — un nœud était soit une branche (subs) soit une feuille (handler), jamais les deux.

**Correction** : dans `resolve()`, quand un nœud a `subs` ET `handler`, si le token suivant ne correspond à aucun sub → on le traite comme une feuille (bind args sur le handler). 5 lignes de fix, 100% rétrocompatible.

**Règle apprise** : un bug = un trou dans les tests unitaires. On a écrit 8 tests busted spécifiques au cas hybride avant de demander le test en jeu.

## Commandes

| Commande | Description |
|----------|-------------|
| `/cg shoplist <itemID> [qty]` | Expansion + cotation DP du panier complet |
| `/cg shoplist expand <itemID> [qty]` | Expansion brute (sans prix) |

## Exemples

### Expansion brute
```
/cg shoplist expand 4360 3
→ [Shoplist] Rough Copper Bomb (4360) × 3 — raw materials:
    Linen Cloth (2589) × 3
    Copper Bar (2840) × 6
    Rough Stone (2835) × 6
```

### Avec cotation (après avoir ajouté des listings)
```
/cg listing add 2840 20 50s; listing add 2835 10 10s; listing add 2589 5 2s
/cg shoplist 4360 3
→ [Shoplist] Rough Copper Bomb (4360) × 3
    Raw materials:
      Copper Bar (2840) × 6 — 50s (surplus: 14 extra)
      Linen Cloth (2589) × 3 — 2s (surplus: 2 extra)
      Rough Stone (2835) × 6 — 10s (surplus: 4 extra)
    Total: 62s
```

### Arbre profond (Explosive Sheep)
```
/cg shoplist expand 4384
→ [Shoplist] Explosive Sheep (4384) × 1 — raw materials:
    Heavy Stone (2838) × 2
    Medium Leather (2319) × 1
    Wool Cloth (2592) × 4
    Bronze Bar (2841) × 4
```

## Fichiers

| Fichier | Rôle |
|---------|------|
| `src/BOM.lua` | Module BOM — expansion, agrégation, shoplist, formatage |
| `src/CmdLang.lua` | **Modifié** — support des nœuds hybrides (handler + subs) |
| `ManualListings.lua` | **Modifié** — ajout commande `/cg shoplist` |

## Tests

- **101 tests busted** (76 existants + 12 BOM + 8 CmdLang hybride + 5 CmdLang existants)
- **Tests BOM** : expansion simple, multi-reagent, agrégation, quantité ×N, arbre profond, cotation, items sans listings
- **Tests CmdLang hybride** : handler vs sub routing, batch, edge cases, non-régression sur nœuds purs

## Limites connues

- Le BOM développe **toujours** les composants craftables — pas de décision buy vs craft (c'est la capsule 13)
- Les items sans listings sont affichés « no listings » avec un compteur dans le total
- La DB contient uniquement les recettes Engineering 1-150

## Going Further

- → Capsule 13 : Buy vs Craft v2 — le calculateur utilise `quote()` au lieu des prix unitaires, et choisit buy vs craft par quantité
