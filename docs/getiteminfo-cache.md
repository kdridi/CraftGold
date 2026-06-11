# GetItemInfo — Cache et async en Classic Era

> Base de connaissances validée — Session 8, Capsule 06

## Pourquoi GetItemInfo() retourne toujours les données immédiatement

Le client Classic Era (1.15.x) charge **toutes les données d'items** depuis les fichiers DB2/CASC locaux au démarrage du client. Ce ne sont pas des données réseau — elles sont dans les archives du jeu installé.

Le dossier `Cache/WDB/` n'est qu'une couche de cache complémentaire (hotfixes serveur, données détaillées de certains items). Le supprimer ne change rien pour les items de base.

### Couches de données (de la plus proche à la plus distante)

| Couche | Emplacement | Rôle |
|--------|-------------|------|
| DB2/CASC | `Data/` (archives du jeu) | Données statiques de TOUS les items — chargées en RAM au démarrage |
| DBCache.bin | `Cache/ADB/` | Hotfixes serveur appliqués aux DB2 |
| WDB | `Cache/WDB/` | Cache réseau (items détaillés vus en jeu) |
| Session | Mémoire | Items chargés par l'UI, les sacs, l'AH, les add-ons |

## GetItemInfo() vs GetItemInfoInstant()

| Fonction | Source | Retourne nil ? | Contenu |
|----------|--------|----------------|---------|
| `GetItemInfo(itemID)` | DB2 + WDB + serveur | Oui si pas en cache | Nom, lien, qualité, level, type, icône, prix... |
| `GetItemInfoInstant(itemID)` | DB2 local uniquement | **Jamais pour un item valide** | itemID, type, sous-type, equipLoc, icône, classID |

`GetItemInfoInstant()` ne fait **jamais** de requête serveur. Elle retourne toujours les données DB2 pour un item valide. En revanche, elle ne donne pas le nom localisé ni le lien complet.

## GET_ITEM_INFO_RECEIVED — Quand se déclenche-t-il ?

**Uniquement quand le client a dû faire une vraie requête réseau** vers le serveur. En Classic Era 1.15.x, cela n'arrive quasiment jamais car les données sont dans les DB2 locales.

Payload : `itemID` (number), `success` (bool)

### Cas où l'événement peut se déclencher

1. Item ajouté par hotfix très récent, pas encore dans DBCache.bin
2. Item avec stats dynamiques (suffixes aléatoires type "...of the Bear")
3. Item Retail interrogé depuis Classic Era (success=false probable)

## Comment tester l'async en développement

### Méthode 1 — IDs Retail (test partiel)

Les IDs Retail (200000+) n'existent pas dans les DB2 Classic Era. `GetItemInfo()` retourne `nil`, mais l'événement peut ne jamais se déclencher (success=false) ou se déclencher avec success=false.

```lua
/script local n = GetItemInfo(210502); print("210502:", n or "NIL")
```

### Méthode 2 — IDs d'items rares Classic (test réel)

Ces items existent en Classic Era mais sont rarement préchargés :
- 16054 — Schematic: Arcanite Dragonling
- 18650 — Schematic: EZ-Thro Dynamite II
- 19999 — Bloodvine Goggles
- 22729 — Schematic: Steam Tonk Controller
- 21524 — Red Winter Hat (saisonnier)

⚠️ Résultat non garanti — dépend du client et du cache.

### Méthode 3 — Mocking (la vraie solution)

Simuler le comportement async en Lua pour les tests :

```lua
local isDevMode = true
local mockCache = {}

local function SafeGetItemInfo(itemID)
    if not isDevMode then return GetItemInfo(itemID) end

    if mockCache[itemID] then
        return GetItemInfo(itemID)
    else
        C_Timer.After(2.0, function()
            mockCache[itemID] = true
            -- Déclencher manuellement le handler
        end)
        return nil
    end
end
```

## Fréquence en production (CraftGold)

| Type d'item | Risque de nil |
|-------------|---------------|
| Matériaux communs (Cloth, Bar, Herb) | Quasi-nul |
| Items de craft Engineering | Très faible |
| Schematics rares, réputation | Faible |
| Items saisonniers / event | Faible à moyen |
| Items Retail (IDs > 200000) | Toujours nil |

**Conclusion** : le handler `GET_ITEM_INFO_RECEIVED` est un filet de sécurité nécessaire, mais en Classic Era il se déclenchera presque jamais pour les items de CraftGold. Notre pattern (fallback "item:ID" + écoute de l'événement) est correct.
