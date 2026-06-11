# 09 — Item Info

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données réelles                                   |
| Prerequisites | Capsule 08 — Analyze & Report                               |
| Type          | Semi-autonomous                                             |
| Concepts      | `C_Item.*`, `GetItemInfo()`, `GetItemInfoInstant()`, cache asynchrone, `ContinueOnItemLoad`, module centralisé |

## Why This Capsule?

Jusqu'ici, chaque module appelait `GetItemInfo()` directement, avec son propre fallback `"item:" .. id` éparpillé partout. Ça marchait, mais :
- Pas de cohérence entre modules
- Impossible de changer le comportement centralisé
- On n'explorait qu'une seule fonction (`GetItemInfo`) alors que le code source Blizzard révèle tout un écosystème `C_Item.*`

Avant d'attaquer les listings réels (capsule 10), on a besoin d'un **module ItemInfo centralisé** qui :
- Abstrait tout accès aux données d'items derrière une API propre
- Explore les fonctions `C_Item.*` ciblées (`GetItemNameByID`, `IsItemDataCachedByID`, etc.)
- Gère l'async une bonne fois pour toutes

C'est le fondement de la Phase 4 — les capsules suivantes (listings, DP knapsack, AH scanner) s'appuieront toutes sur ce module.

## Ce qu'on a appris

### `GetItemInfo()` vs `C_Item.*` — deux familles d'API

| Fonction | Retour | Async ? | Usage |
|----------|--------|---------|-------|
| `GetItemInfo(id)` | 17 valeurs (nom, lien, qualité, level, type, icône, prix...) | Oui, peut retourner `nil` | Tout-en-un, mais lourd si on ne veut qu'un champ |
| `C_Item.GetItemNameByID(id)` | Juste le nom | Oui, peut retourner `nil` | Léger quand on ne veut que le nom |
| `C_Item.GetItemQualityByID(id)` | Juste la qualité | Oui | Léger |
| `C_Item.GetItemIconByID(id)` | Juste l'icône (fileID) | Oui | Léger |
| `C_Item.IsItemDataCachedByID(id)` | `bool` | Non, synchrone | Savoir si les données sont dispo |
| `C_Item.RequestLoadItemDataByID(id)` | Rien | Déclenche le chargement | Utilisé en interne par `ContinueOnItemLoad` |
| `GetItemInfoInstant(id)` | itemID, type, subType, equipLoc, icon, classID, subClassID | Non, **toujours synchrone** | Pas de nom localisé, mais jamais nil pour un item valide |

**Découverte** : `C_Item.GetItemNameByID()` partage le même cache que `GetItemInfo()`. Si l'un retourne une valeur, l'autre aussi.

### Cache en Classic Era — Comportement observé

| Observation | Détail |
|-------------|--------|
| Items communs (Copper Bar, Linen Cloth) | **Toujours en cache** dès le login — données DB2 locales |
| Items craftés Engineering | **La plupart en cache** — mais pas tous au premier scan |
| Chargement entre deux commandes | Les items uncached au 1er scan étaient cached au 2e — le chargement est quasi-instantané |
| Callback `onLoad` | Très difficile à observer en Classic Era — les données arrivent trop vite |
| ItemID invalide (99999) | `GetItemInfoInstant` retourne `nil` — on peut détecter les items inexistants |

**Conclusion** : en Classic Era, `GET_ITEM_INFO_RECEIVED` et le callback async se déclenchent rarement pour les items de CraftGold. Le handler `onLoad` est un filet de sécurité nécessaire mais presque jamais sollicité.

### ItemID invalide = `GetItemInfoInstant` retourne nil

`/iteminfo 99999` confirme : `GetItemInfoInstant` retourne `nil` pour un itemID qui n'existe pas. C'est le premier check à faire — si `getInstantInfo()` retourne nil, l'item n'existe pas, pas besoin d'aller plus loin.

## Module ItemInfo — API

```
ItemInfo.getName(id)          → string|nil     (nom localisé)
ItemInfo.getInfo(id)          → table|nil      (tous les champs GetItemInfo en table)
ItemInfo.getIcon(id)          → fileID|nil
ItemInfo.getQuality(id)       → number|nil     (0=Poor, 1=Common, 2=Uncommon, ...)
ItemInfo.getSellPrice(id)     → number|nil     (en copper)
ItemInfo.getMaxStack(id)      → number|nil
ItemInfo.getInstantInfo(id)   → table|nil      (sync, jamais nil pour un item valide)
ItemInfo.isCached(id)         → bool
ItemInfo.requestLoad(id)      → void
ItemInfo.onLoad(id, callback) → void           (callback(id) quand chargé)
ItemInfo.formatName(id)       → string         (nom ou "item:XXXX" fallback gris)
ItemInfo.formatColoredName(id)→ string         (nom coloré par qualité)
ItemInfo.scanDB()             → {total, cached, uncached, items}
```

## Architecture

```
Avant (capsule 08) :              Après (capsule 09) :
┌──────────────┐                  ┌──────────────┐
│  Shell.lua   │── GetItemInfo()  │  Shell.lua   │── ItemInfo.formatName()
│  Report.lua  │── GetItemInfo()  │  Report.lua  │── ItemInfo.formatName()
│  UI.lua (06) │── GetItemInfo()  │  ItemInfo.lua│── C_Item.* + GetItemInfo()
└──────────────┘                  └──────────────┘
  Appels dispersés                  Point unique d'accès
```

**Règle** : plus aucun appel direct à `GetItemInfo()` hors de `ItemInfo.lua`.

## Refactoring réalisé

- `Report.lua` : tous les `ns.WoW.GetItemInfo()` remplacés par `ns.ItemInfo.formatName()`
- `ItemInfoDemo.lua` (shell) : tous les `ns.WoW.GetItemInfo()` remplacés par `ns.ItemInfo.formatName()`
- Tests in-game : assertions localisation-indépendantes (comparent avec `GetItemInfo()` directement)

## Pitfalls rencontrés

### 1. Tests localisation-dépendants
Les tests initiaux comparaient le nom avec `"Copper Bar"` (hardcodé anglais). Sur un client français, l'item s'appelle "Barre de cuivre" → 3 tests en échec.

**Fix** : récupérer le nom attendu via `GetItemInfo(2840)` au début du test, au lieu de le coder en dur.

**Leçon** : en WoW, toujours supposer que le client peut être dans n'importe quelle langue. Ne jamais hardcoder un nom d'item.

### 2. Les C_Item.* partagent le même cache que GetItemInfo
Pas une erreur, mais une découverte : `C_Item.GetItemNameByID()` et `GetItemInfo()` retournent nil ou une valeur en même temps. Pas besoin de gérer deux caches séparés.

## Going Further

- → Capsule 10 : Manual Listings (remplacer `price[item]` par `listings[item] = {{count, buyout}, …}`)
