# 07 — Price & Calculator

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 3 — Cœur métier                                       |
| Duration      | 1h                                                          |
| Difficulty    | ●●●●○ (4/5)                                                |
| Prerequisites | Capsule 06 — Recipe DB                                      |
| Type          | Autonomous                                                  |
| Concepts      | Money formatting, manual prices via slash, recursive cost calculator, min(buy, craft), cycle detection, memoization |

## Why This Capsule?

On a une DB de 26 recettes Engineering (capsule 06). Mais ces recettes sont juste des données statiques — elles ne nous disent pas si crafter est rentable. Pour ça, il nous faut deux choses :

1. **Des prix** — combien ça coûte d'acheter un composant à l'Hôtel des Ventes
2. **Un calculateur** — qui descend récursivement dans l'arbre des recettes pour trouver le coût minimum

Le cœur du calcul est simple mais subtil : pour chaque composant, on choisit le chemin le moins cher entre **acheter** directement et **crafter** à partir de sous-composants. Et comme certains items sont à la fois craftables ET utilisés comme composants (Copper Bolts, Rough Blasting Powder, Copper Modulator…), il faut gérer les arbres profonds et les cycles potentiels.

Cette capsule pose les fondations économiques de CraftGold — tout le reste (scan AH, fenêtre de profits) viendra se brancher dessus.

## Objectives

1. **Parse & format** des montants en or/argent/cuivre (`"12s40c"` → `1240` → `"12s 40c"`)
2. **Saisir des prix manuellement** via `/cg price <itemID> <price>`
3. **Stocker les prix** en SavedVariables (persistés entre les sessions)
4. **Calculer récursivement** le coût optimal : `min(prixAchat, coûtCraft)`
5. **Détecter les cycles** dans le graphe des recettes
6. **Mémoïser** les résultats pour les performances

## Architecture

### Fichiers

| Fichier | Rôle | WoW API ? |
|---------|------|-----------|
| `PriceCalc.toc` | Descriptor + `SavedVariables: PriceCalcDB` | — |
| `src/WoW.lua` | Seam WoW (print, wipe, GetItemInfo) | Init uniquement |
| `src/DB.lua` | DB statique Engineering (copie capsule 06) | Non |
| `src/Core.lua` | Fonctions de requête recettes (copie capsule 06) | Non |
| `src/Money.lua` | Parse/format argent (or/argent/cuivre ↔ copper) | Non |
| `src/Prices.lua` | Stockage prix itemID → copper, backed by SavedVars | Non |
| `src/Calculator.lua` | Calculateur récursif `min(buy, craft)` | Non |
| `PriceCalc.lua` | Shell : slash commands, événements, init | Oui |

### Algorithme du calculateur

```
calculate(itemID):
  si en cache → retourner le résultat
  si en cours de visite → cycle → nil
  marquer comme "visiting"

  buyPrice = Prices.get(itemID)
  craftCost = nil
  
  si itemID est craftable:
    pour chaque réactif:
      reagentCost = calculate(reagentID)  // récursion
      si un réactif est impossible → craftCost = nil
      sinon → somme
    fin pour
  fin si

  résultat = min(buy, craft) ou celui qui existe
  mettre en cache
  retirer de "visiting"
  retourner résultat
```

### État partagé pour analyze()

`Calculator.analyze()` crée un seul `{ cache, visiting }` partagé entre toutes les recettes. Ainsi, le calcul des Copper Bolts est mémoïsé et réutilisé quand on calcule Copper Modulator, Rough Copper Bomb, etc.

## Execution

1. Symlink dans `Interface/AddOns/` :
   ```bash
   ln -sf /Users/kdridi/git/github.com/kdridi/CraftGold/01-wip/07-price-calculator "/Applications/World of Warcraft/_classic_era_/Interface/AddOns/PriceCalc"
   ```
2. `/reload` en jeu
3. Vérifier : `/cg help`
4. Entrer des prix :
   ```
   /cg price 2840 12s40c     -- Copper Bar
   /cg price 2589 3s10c      -- Linen Cloth
   /cg price 4359 18s        -- Handful of Copper Bolts
   ```
5. Tester le calculateur :
   ```
   /cg cost 4363              -- Copper Modulator: breakdown complet
   /cg analyze                -- Top crafts rentables
   /cg analyze                -- Top crafts rentables
   /cg price list             -- Tous les prix
   ```
6. Tester : `/cg test`

## Expected Output

```
/cg price 2840 12s40c
[CraftGold] Copper Bar (2840) = 12s 40c

/cg price 2589 3s10c
[CraftGold] Linen Cloth (2589) = 3s 10c

/cg price 4359 18s
[CraftGold] Handful of Copper Bolts (4359) = 18s

/cg cost 4363
[CraftGold] Copper Modulator (4363) — Cost: 43s 40c (craft)
  Buy: 72s Craft: 43s 40c — craft is cheaper!
  Reagents:
    Linen Cloth x2 — 3s 10c each = 6s 20c (buy)
    Copper Bar x1 — 12s 40c each = 12s 40c (buy)
    Handful of Copper Bolts x2 — 12s 40c each = 24s 80c (craft)

/cg analyze
[CraftGold] Top 1 profitable craft(s):
  1. Copper Modulator — Cost: 43s 40c — Sell: 72s — Profit: 28s 60c — Margin: 66%
    → Craft Handful of Copper Bolts (12s 40c) instead of buying (18s)
```

## Key Concepts

### Money parsing
- Format d'entrée flexible : `1g50s30c`, `12s40c`, `3g`, `500c`
- Case-insensitive : `1G50S` fonctionne aussi
- Stockage interne en **cuivre** (entier)
- Affichage avec couleurs WoW (or=jaune, argent=gris, cuivre=brun)

### SavedVariables
- `PriceCalcDB` déclaré dans le `.toc`
- Initialisé dans `ADDON_LOADED` (filtrage par nom d'add-on)
- Les prix survivent aux `/reload` et déconnexions

### Calculateur récursif
- **Méthode buy** : prix direct depuis `Prices.get(itemID)`
- **Méthode craft** : somme des coûts récursifs des réactifs × quantités
- **Décision** : `min(buy, craft)` quand les deux existent
- **Détection de cycles** : ensemble `visiting` (items sur la pile d'appel)
- **Mémoïsation** : cache partagé pour éviter les recalculs
- **Items non priceables** : sentinel `false` dans le cache (distinguer "pas calculé" de "impossible")

## Tests

### busted (41 tests, 0 failure)
- `test_money.lua` — Money.parse, Money.format, round-trip
- `test_calculator.lua` — Prices, Calculator (raw, simple, complex, cycles, analyze, breakdown)

### In-game (`/cg test`)
- ~30 assertions couvrant tout le pipeline : parse, format, prix, calcul, cycles, analyze

## Common Pitfalls

- **Lua 5.4 const loop variables** : les variables de `for` sont const → utiliser une variable intermédiaire (`raw_amount` → `amount`)
- **Money.format avec espaces** : `table.concat(parts, " ")` produit `"12s 40c"`, pas `"12s40c"` — les deux sont parsables
- **SavedVariables nil** : `PriceCalcDB` peut être nil au premier chargement → `PriceCalcDB = PriceCalcDB or {}`
- **Cycle + buy price** : un cycle n'est pas bloquant si un item du cycle a un buy price (ça casse la boucle)

## Going Further

- → Capsule 08 : `/cg analyze` enrichi (affichage chat avancé, arbre de décision détaillé)
- → Capsule 09 : ItemInfo cache (noms lisibles au lieu de `item:XXXX`)
- → Capsule 10 : Scan AH automatique (remplace les prix manuels)
