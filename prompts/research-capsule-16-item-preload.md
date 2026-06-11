# Recherche — Preload item cache pour scanner AH

## Contexte

On développe un add-on WoW Classic Era (1.15.x) appelé **CraftGold**. L'add-on scanne les listings de l'Hôtel des Ventes (AH) pour calculer les profits des crafts.

## Le problème

Notre scanner AH utilise `QueryAuctionItems(name)` qui recherche par **nom**. Pour obtenir le nom d'un item à partir de son itemID, on utilise `GetItemInfo(itemID)`. 

Le problème : `GetItemInfo()` retourne `nil` si l'item n'est pas dans le cache local du client. En Classic Era, la plupart des items sont dans les fichiers DB2 locaux, mais le client ne les charge en cache que quand on les rencontre en jeu (loot, HdV, chat link, etc.).

Conséquence : sur 130 items à scanner, 84 ont échoué parce que `GetItemInfo()` retournait `nil` — le scanner ne pouvait pas obtenir le nom pour lancer la recherche AH.

## Ce qu'on sait déjà

- `GetItemInfo(itemID)` retourne les infos d'un item **si en cache**, `nil` sinon
- `GetItemInfoInstant(itemID)` retourne des infos partielles même sans cache complet, mais **pas le nom localisé**
- `C_Item.RequestLoadItemDataByID(itemID)` demande au client de charger les données d'un item — déclenche `ITEM_DATA_LOAD_RESULT` quand c'est prêt
- `ContinueOnItemLoad(callback)` — API Blizzard qui exécute un callback quand l'item est chargé
- En Classic Era, les données sont **locales** (fichiers DB2) — le chargement est quasi-instantané
- L'événement `GET_ITEM_INFO_RECEIVED` se déclenche quand un item est chargé

## Notre code actuel

### Scanner.lua — la fonction qui échoue

```lua
function Scanner.scan(itemID, callback)
    -- Resolve itemID → name
    -- First try the cache, then force-load if not cached
    local name = ns.WoW.GetItemInfo(itemID)
    if not name then
        -- Force the client to load item data from local DB2 files
        if ns.WoW.RequestLoadItemDataByID then
            ns.WoW.RequestLoadItemDataByID(itemID)
        end
        -- Retry after force-load (in Classic Era, data is local and loads near-instantly)
        name = ns.WoW.GetItemInfo(itemID)
    end
    if not name then
        return false, "item not in cache (try viewing it first, then retry)"
    end
    -- ... lance le scan AH
end
```

Le problème : `RequestLoadItemDataByID()` est **asynchrone** — même si en Classic Era c'est quasi-instantané, le retry juste après ne fonctionne pas toujours car le cache n'est pas encore mis à jour dans le même tick.

### Ce qu'on veut

On a une liste de ~130 itemIDs. On veut les **précharger tous** dans le cache avant de lancer les scans AH. Quelque chose comme :

```lua
-- Pseudocode
preloadItems(itemIDs, function()
    -- Tous les items sont en cache, on peut scanner
    for _, itemID in ipairs(itemIDs) do
        Scanner.scan(itemID, callback)
    end
end)
```

## Questions de recherche

### 1. Comment les add-ons existants gèrent-ils le preload d'items ?

Chercher des exemples concrets dans des add-ons open source :
- **Auctionator** — comment gère-t-il les items pas en cache ?
- **TradeSkillMaster (TSM)** — a-t-il un système de preload ?
- **Attic** / **Baganator** / **AdiBags** — gèrent-ils le cache d'items ?
- **CraftSim** / **RecipeRadar** — comment chargent-ils les données d'items en masse ?
- Tout autre add-on qui charge des items par itemID

### 2. `RequestLoadItemDataByID` vs `ContinueOnItemLoad` — quel pattern utiliser ?

- Est-ce que `RequestLoadItemDataByID(itemID)` suivi immédiatement de `GetItemInfo(itemID)` fonctionne en Classic Era ?
- Ou faut-il absolument attendre l'événement `GET_ITEM_INFO_RECEIVED` / `ITEM_DATA_LOAD_RESULT` ?
- `ContinueOnItemLoad` est-il disponible en Classic Era 1.15.x ? Si oui, comment l'utiliser pour charger une liste d'items en batch ?

### 3. Existe-t-il une méthode synchrone ?

En Classic Era, les données sont locales (DB2). Y a-t-il un moyen de forcer le chargement synchrone ? Par exemple :
- `select(1, GetItemInfo(itemID))` après un `RequestLoadItemDataByID` — ça marche dans le même frame ?
- Faut-il attendre 1 frame (OnUpdate) ?
- Ou un événement ?

### 4. Comment fonctionnent les liens d'items ?

Le joueur peut copier-coller un lien d'item dans le chat (ex: `[Aquadynamic Fish Attractor]`) et l'item se charge instantanément dans le cache. Comment ça marche en interne ? Est-ce que créer un item link en Lua force le chargement ?

## Ce qu'on veut comme réponse

1. **Le pattern recommandé** pour précharger une liste d'itemIDs dans le cache en Classic Era 1.15.x
2. **Du vrai code** tiré d'add-ons existants (avec liens GitHub)
3. **Le timing** : synchrone ? 1 frame ? événement ?
4. **Un exemple complet** de fonction `preloadItems(ids, callback)` qui fonctionne en Classic Era

## Sources à consulter

- https://warcraft.wiki.gg/wiki/GetItemInfo
- https://warcraft.wiki.gg/wiki/API_C_Item.RequestLoadItemDataByID
- https://github.com/Beast-Mage/Auctionator (si le code est accessible)
- https://github.com/TrinityCore/TrinityCore (pour comprendre le cache serveur)
- Tout repo GitHub d'add-on Classic Era qui gère le preload d'items
