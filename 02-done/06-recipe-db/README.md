# 06 — Recipe DB

| Metadata      | Value                                                        |
|---------------|--------------------------------------------------------------|
| Phase         | Phase 3 — Cœur métier                                        |
| Duration      | ~2h                                                          |
| Difficulty    | ●●●○○ (3/5)                                                 |
| Prerequisites | Capsule 03 — Saved Variables (architecture Functional Core) |
| Type          | Autonomous                                                   |
| Concepts      | DB statique, itemID, structures Lua, tests busted, Component Mixin, GetItemInfo async |

## Why This Capsule?

On a passé 5 capsules à apprendre les bases : structure d'add-on, slash commands, SavedVariables, frames, boutons. On sait créer des trucs qui s'affichent et qui persistent. Mais CraftGold reste vide — il n'a pas encore de données, pas de moteur.

Cette capsule marque le **pivot** : on entre dans le cœur métier de CraftGold. Le problème : pour calculer si un craft est rentable, il faut savoir **ce qui existe**. Quelles recettes Engineering sont disponibles ? Quels composants faut-il ? L'API WoW ne donne que les recettes apprises par le personnage — impossible de planifier sans ouvrir un guide externe.

La solution : construire notre **propre base de données statique**. 26 recettes Engineering niveau 1-150, en pur Lua, testable avec busted, sans dépendance à l'API WoW. C'est le Functional Core de CraftGold.

## Ce qu'on a appris

### 1. Données statiques en Lua pur

- **DB par itemID** (jamais par nom) : les noms changent selon la langue du client, les itemIDs sont universels
- **Structure plate** : `recipes[spellID] = { output, reagents, skillRequired, source }` — simple à parser, facile à requêter
- **Source de données** : LibCrafts-1.0 (MIT) — DB Vanilla complète, itemIDs identiques en Classic Era
- **Tests busted** : 19 tests en pur Lua, sans WoW — le Core ne dépend de rien

### 2. Fonctions de requête (Core.lua)

```lua
Core.getByOutput(itemID)     -- Trouver la recette qui produit un item
Core.getByReagent(itemID)    -- Trouver toutes les recettes utilisant un composant
Core.getBySkill(level)       -- Recettes apprenables à un niveau donné
Core.getBySpellID(spellID)   -- Lookup direct
Core.getBySource(source)     -- Filtrer par source (trainer, auto, vendor, drop)
Core.isCraftable(itemID)     -- Cet item est-il craftable ?
Core.getIntermediates()      -- Items à la fois craftables ET utilisés comme composant
```

La dernière fonction est la clé du calculateur récursif : les **intermediates** sont les items pour lesquels on choisira entre acheter et crafter (prochaine capsule).

### 3. GetItemInfo et le cache d'items

- **`GetItemInfo(itemID)`** retourne le nom, la qualité, l'icône, etc. — mais peut retourner `nil` si l'item n'est pas en cache
- **En Classic Era** : les items de base sont quasi-toujours en cache immédiatement (données DB2 locales chargées au démarrage)
- **`GET_ITEM_INFO_RECEIVED`** se déclenche quand le client reçoit les données du serveur — quasi-jamais en Classic Era pour les items communs
- Voir `docs/getiteminfo-cache.md` pour les détails

### 4. Architecture UI — Component Mixin

Le problème initial : notre code UI avait deux phases séparées (création + mise à jour asynchrone) reliées par un index externe `itemToTexts`. Pas encapsulé.

**Solution** : le pattern **Mixin + ContinueOnItemLoad** :

```lua
-- Chaque ligne est un composant autonome
RecipeLineMixin = {}

function RecipeLineMixin:SetRecipe(recipe)
    self.recipe = recipe
    self:Render()

    local name = GetItemInfo(recipe.output)
    if not name then
        local item = Item:CreateFromItemID(recipe.output)
        item:ContinueOnItemLoad(function()
            if self.recipe == recipe then  -- garde anti-recyclage
                self:Render()
            end
        end)
    end
end

-- Injection dans une frame WoW
Mixin(line, RecipeLineMixin)
line:Init(recipe)
```

**Pourquoi ce pattern** :
- **Idiomatique WoW** : Blizzard utilise des `*Mixin` partout dans le FrameXML
- **`ContinueOnItemLoad`** est fourni par le client — déduplication, filtrage, désabonnement automatiques
- **Encapsulation** : chaque composant gère son propre cycle async
- **Plus d'index externe** : la création et la mise à jour sont au même endroit

Voir `docs/ui-architecture.md` pour les autres patterns évalués et les recommandations futures.

## Structure du code

```
06-recipe-db/
├── RecipeDB.toc
├── RecipeDB.lua          -- Shell : slash commands, ADDON_LOADED, tests in-game
├── src/
│   ├── WoW.lua           -- Seam (fallbacks pur Lua pour les tests)
│   ├── DB.lua            -- 26 recettes Engineering (skill 1-150)
│   ├── Core.lua          -- 7 fonctions de requête (pur Lua, testable busted)
│   └── UI.lua            -- Fenêtre navigateur, pattern Component Mixin
├── tests/
│   ├── helpers.lua       -- Chargement des modules en pur Lua
│   └── test_core.lua     -- 19 tests busted
├── .busted               -- Config busted
└── README.md
```

## Tests

### busted (pur Lua)
```
19 successes / 0 failures
```

### In-game (`/cgdb test`)
```
82 assertions passed
```

## Commands

| Command | Description |
|---------|-------------|
| `/cgdb help` | Affiche l'aide |
| `/cgdb count` | Nombre de recettes chargées |
| `/cgdb test` | Lance les tests in-game |
| `/cgdb show` | Ouvre la fenêtre navigateur |
| `/cgdb hide` | Ferme la fenêtre |

## Difficultés rencontrées

### Comptage des recettes utilisant Copper Bar (2840)

Erreur initiale : on pensait 7 recettes, mais il y en a 8 (on avait oublié Crafted Heavy Shot). Le test busted et le test in-game étaient initialement incohérents. **Le test busted avait raison** — corrigé dans les deux.

### `GetItemInfo` est (quasi) toujours synchrone en Classic Era

Même après suppression du cache WDB, `GetItemInfo()` retourne immédiatement les noms car les données sont dans les DB2/CASC locaux (chargées au démarrage du client). L'événement `GET_ITEM_INFO_RECEIVED` ne se déclenche quasiment jamais pour les items communs.

Testé avec des IDs Retail (210502) : `GetItemInfo` retourne `nil`, puis `GET_ITEM_INFO_RECEIVED` se déclenche avec `success=false` (l'item n'existe pas en Classic Era).

### Architecture UI — deux phases détachées

Le code initial mélangeait création visuelle et mise à jour async dans deux blocs séparés, reliés par un index externe. Résolu via le pattern Component Mixin + `ContinueOnItemLoad`.

## Going Further

→ **Prochaine capsule** : **07 — Price & Calculator** — Prix manuels (`/cg price`), formatage money, calculateur récursif `min(buy, craft)`, détection de cycles, mémoïsation. Le cœur du produit.
