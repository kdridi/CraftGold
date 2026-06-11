## Verdict

Pour **CraftGold**, ne fais pas :

```lua
RequestLoadItemDataByID(id)
GetItemInfo(id) -- retry immédiat
```

Le bon pattern est : **request → attendre `ITEM_DATA_LOAD_RESULT` / `GET_ITEM_INFO_RECEIVED` → seulement ensuite appeler `GetItemInfo(id)`**.

Même en Classic Era, où le chargement est souvent très rapide, l’API est bien conçue comme **asynchrone**. Blizzard a un système interne d’async callbacks : pour les items, il associe `ITEM_DATA_LOAD_RESULT` à `C_Item.RequestLoadItemDataByID`, puis appelle les callbacks seulement à la réception de l’événement.  

---

## Ce que font les add-ons existants

### Auctionator

Auctionator utilise le pattern moderne :

```lua
local item = Item:CreateFromItemID(itemID)
item:ContinueOnItemLoad(function()
  -- GetItemInfo / traitement AH ici
end)
```

Dans son provider Legacy AH, Auctionator crée un `Item` à partir d’un itemID, appelle `ContinueOnItemLoad`, puis seulement dans le callback appelle `C_Item.GetItemInfo(...)` pour remplir les données de ligne. 

Dans son provider Modern AH, il crée aussi un `Item:CreateFromItemID(itemKey.itemID)` et traite les résultats d’enchère dans `ContinueOnItemLoad(...)`. 

Même pour les prix vendeurs, Auctionator ne lit pas les données immédiatement : il crée l’objet item et attend `ContinueOnItemLoad` avant de lire le lien/prix. 

### Baganator

Baganator a un loader maison très intéressant pour ton cas : il maintient une table `pendingItems`, écoute `ITEM_DATA_LOAD_RESULT`, appelle tous les callbacks associés à l’itemID, et relance périodiquement `C_Item.RequestLoadItemDataByID(itemID)` toutes les `0.4s` tant que l’item est pending. 

Dans sa préparation d’items, Baganator vérifie `C_Item.IsItemDataCachedByID`, puis si l’item existe via `C_Item.GetItemInfoInstant`, il appelle son `LoadItemData` et attend le callback avant de recalculer les champs dépendants. 

### Syndicator

Syndicator utilise quasiment le même pattern que Baganator : table `pendingItems`, frame qui écoute `ITEM_DATA_LOAD_RESULT`, callbacks par itemID, et retry périodique via `OnUpdate` toutes les `0.4s`.  

Il a aussi un pattern défensif : si le nom n’est pas encore disponible, il appelle `C_Item.RequestLoadItemDataByID(details.itemID)` au lieu de supposer que `GetItemInfo` va marcher tout de suite. 

### ItemCache

ItemCache est encore plus robuste : il écoute **les deux événements** `GET_ITEM_INFO_RECEIVED` et `ITEM_DATA_LOAD_RESULT`, ce qui est utile si certains chemins passent par `GetItemInfo` et d’autres par `RequestLoadItemDataByID`. 

Il traite aussi les échecs (`success == false`) avec une logique de retry et de limite de tentatives. 

Enfin, ItemCache montre bien le pattern “pas encore chargé = request puis return nil” : `Item:GetInfo()` appelle `self:Load()` quand l’item n’est pas chargé, puis retourne sans info jusqu’au chargement effectif.  

---

## `RequestLoadItemDataByID` vs `ContinueOnItemLoad`

`ContinueOnItemLoad` est pratique, mais pour CraftGold je recommande plutôt **ton propre batch loader événementiel**.

Pourquoi ? Parce que le système Blizzard `ContinueOnItemLoad` repose sur `ItemEventListener:AddCallback`, qui appelle `C_Item.RequestLoadItemDataByID(id)` puis attend `ITEM_DATA_LOAD_RESULT`.  Or, si `ITEM_DATA_LOAD_RESULT` revient avec `success == false`, le système interne **clear les callbacks sans les appeler**. 

Donc :

| Besoin                                | Pattern                                                                              |
| ------------------------------------- | ------------------------------------------------------------------------------------ |
| UI simple, tooltip, ligne d’item      | `Item:CreateFromItemID(id):ContinueOnItemLoad(cb)`                                   |
| Batch scanner AH robuste              | loader maison avec `ITEM_DATA_LOAD_RESULT`, `GET_ITEM_INFO_RECEIVED`, timeout, retry |
| Besoin de savoir quels IDs ont échoué | loader maison obligatoire                                                            |
| Liste de 130 items avant scan         | loader maison recommandé                                                             |

La doc Warcraft Wiki indique aussi que `C_Item.RequestLoadItemDataByID` demande les données item et déclenche `ITEM_DATA_LOAD_RESULT`; elle indique l’API comme disponible depuis `8.0.1 / 1.13.2`, donc dans la famille Classic. ([Warcraft Wiki][1])

---

## Méthode synchrone ?

Je n’ai trouvé aucune méthode fiable pour forcer un chargement **synchrone** du nom localisé.

Même si les données DB2 sont locales, le contrat API reste async. Les add-ons sérieux ne font pas “request puis retry immédiat” : Auctionator attend `ContinueOnItemLoad`, Baganator/Syndicator attendent `ITEM_DATA_LOAD_RESULT`, et ItemCache écoute les événements + retry.   

Donc :

```lua
C_Item.RequestLoadItemDataByID(itemID)
local name = GetItemInfo(itemID)
```

peut marcher parfois, mais ce n’est pas garanti dans le même tick/frame.

Attendre “1 frame” est mieux que rien, mais reste moins correct qu’attendre l’événement. Le bon contrat est : **événement ou callback**.

---

## Liens d’items : est-ce que créer un link force le cache ?

Créer une string du genre :

```lua
"|Hitem:6533::::::::|h[Aquadynamic Fish Attractor]|h"
```

ne suffit pas à garantir que `GetItemInfo(6533)` retournera un nom. Une string Lua n’est qu’une string.

Ce qui peut déclencher/renseigner le cache, c’est quand le client **résout réellement l’item** : tooltip, chat link reçu, `GetItemInfo`, `RequestLoadItemDataByID`, etc. ItemCache illustre ça : il scanne les messages chat pour extraire les `item:...`, puis tente de cacher l’item ; il hook aussi `GameTooltip:OnTooltipSetItem` pour cacher les items vus au mouseover.  

Donc pour CraftGold : **ne génère pas de faux item links pour précharger**. Utilise `RequestLoadItemDataByID` + événement.

---

# Pattern recommandé pour CraftGold

Architecture :

```text
CraftGold
├── ItemPreloader.lua   -- preload batch itemID -> GetItemInfo name ready
├── Scanner.lua         -- suppose que le nom est déjà dispo
└── Orchestrator.lua    -- preload puis scan AH
```

Le scanner ne doit plus essayer de “forcer” le cache lui-même. Il doit soit :

1. recevoir un `itemName` déjà résolu ;
2. soit échouer proprement si le preloader n’a pas réussi.

---

# Code complet : `preloadItems(ids, callback)`

Version robuste Classic Era : écoute `ITEM_DATA_LOAD_RESULT` **et** `GET_ITEM_INFO_RECEIVED`, retry périodique, timeout, déduplication des IDs.

```lua
-- ItemPreloader.lua
local _, ns = ...

ns.ItemPreloader = ns.ItemPreloader or {}
local ItemPreloader = ns.ItemPreloader

local frame = CreateFrame("Frame")
local pending = {}

local DEFAULT_TIMEOUT = 5.0
local DEFAULT_RETRY_EVERY = 0.40

local function GetItemNameCached(itemID)
    local name = GetItemInfo(itemID)
    if type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

local function RequestItem(itemID)
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    else
        -- Old fallback: calling GetItemInfo on an uncached item can trigger
        -- GET_ITEM_INFO_RECEIVED later.
        GetItemInfo(itemID)
    end
end

local function HasAnyPending()
    return next(pending) ~= nil
end

local function StopIfIdle()
    if HasAnyPending() then
        return
    end

    frame:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
    frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnUpdate", nil)
end

local function FinishItem(itemID, ok, reason)
    local entry = pending[itemID]
    if not entry then
        return
    end

    pending[itemID] = nil

    local name = ok and GetItemNameCached(itemID) or nil
    if ok and not name then
        ok = false
        reason = reason or "loaded but GetItemInfo still returned nil"
    end

    for _, callback in ipairs(entry.callbacks) do
        callback(itemID, ok, name, reason)
    end

    StopIfIdle()
end

local function EnsureRunning()
    frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    frame:SetScript("OnUpdate", function(_, elapsed)
        local now = GetTime()
        local completed = {}

        for itemID, entry in pairs(pending) do
            local name = GetItemNameCached(itemID)
            if name then
                table.insert(completed, { itemID = itemID, ok = true })
            elseif now >= entry.deadline then
                table.insert(completed, {
                    itemID = itemID,
                    ok = false,
                    reason = "timeout waiting for item data",
                })
            elseif now >= entry.nextRetry then
                entry.nextRetry = now + entry.retryEvery
                entry.attempts = entry.attempts + 1
                RequestItem(itemID)
            end
        end

        for _, result in ipairs(completed) do
            FinishItem(result.itemID, result.ok, result.reason)
        end
    end)
end

frame:SetScript("OnEvent", function(_, event, itemID, success)
    if not itemID or not pending[itemID] then
        return
    end

    -- ITEM_DATA_LOAD_RESULT passes success.
    -- GET_ITEM_INFO_RECEIVED also commonly passes itemID, success.
    if success == false then
        FinishItem(itemID, false, event .. " success=false")
        return
    end

    -- Event arrived. In most cases GetItemInfo is now ready.
    -- If not, OnUpdate will retry/check again.
    local name = GetItemNameCached(itemID)
    if name then
        FinishItem(itemID, true)
    else
        pending[itemID].nextRetry = 0
    end
end)

local function WaitForItem(itemID, callback, opts)
    local name = GetItemNameCached(itemID)
    if name then
        callback(itemID, true, name, nil)
        return
    end

    local now = GetTime()
    local entry = pending[itemID]

    if not entry then
        entry = {
            callbacks = {},
            attempts = 0,
            retryEvery = opts.retryEvery or DEFAULT_RETRY_EVERY,
            deadline = now + (opts.timeout or DEFAULT_TIMEOUT),
            nextRetry = 0,
        }
        pending[itemID] = entry
    end

    table.insert(entry.callbacks, callback)

    EnsureRunning()
    RequestItem(itemID)
end

function ItemPreloader.preloadItems(itemIDs, callback, opts)
    opts = opts or {}

    local seen = {}
    local result = {
        total = 0,
        loaded = 0,
        failedCount = 0,
        names = {},
        failed = {},
    }

    local remaining = 0
    local loopComplete = false

    local function MaybeDone()
        if loopComplete and remaining == 0 then
            callback(result.failedCount == 0, result)
        end
    end

    local function OnOneItem(itemID, ok, name, reason)
        remaining = remaining - 1

        if ok then
            result.loaded = result.loaded + 1
            result.names[itemID] = name
        else
            result.failedCount = result.failedCount + 1
            result.failed[itemID] = reason or "unknown error"
        end

        if opts.onProgress then
            opts.onProgress(result.loaded + result.failedCount, result.total, itemID, ok, reason)
        end

        MaybeDone()
    end

    for _, rawID in ipairs(itemIDs) do
        local itemID = tonumber(rawID)

        if itemID and not seen[itemID] then
            seen[itemID] = true
            result.total = result.total + 1

            local name = GetItemNameCached(itemID)
            if name then
                result.loaded = result.loaded + 1
                result.names[itemID] = name
            else
                remaining = remaining + 1
                WaitForItem(itemID, OnOneItem, opts)
            end
        end
    end

    loopComplete = true
    MaybeDone()
end
```

---

## Usage dans CraftGold

```lua
local itemIDs = {
    6533, -- Aquadynamic Fish Attractor
    10505,
    10560,
    -- ...
}

ns.ItemPreloader.preloadItems(itemIDs, function(ok, result)
    if not ok then
        print("CraftGold: certains items n'ont pas pu être préchargés")

        for itemID, reason in pairs(result.failed) do
            print("  itemID " .. itemID .. ": " .. reason)
        end

        -- Tu peux choisir :
        -- 1. abort complet
        -- 2. scan seulement les items chargés
    end

    for _, itemID in ipairs(itemIDs) do
        local name = result.names[itemID]
        if name then
            Scanner.scanByName(itemID, name, function(scanResult)
                -- traitement AH
            end)
        end
    end
end, {
    timeout = 5.0,
    retryEvery = 0.40,
    onProgress = function(done, total, itemID, ok, reason)
        print(("CraftGold preload: %d/%d itemID=%d %s"):format(
            done,
            total,
            itemID,
            ok and "OK" or ("FAILED: " .. tostring(reason))
        ))
    end,
})
```

---

## Changement recommandé dans `Scanner.scan`

Au lieu de résoudre `itemID → name` dans `Scanner.scan`, sépare les responsabilités :

```lua
function Scanner.scanByName(itemID, itemName, callback)
    if not itemName then
        return false, "missing item name"
    end

    -- QueryAuctionItems recherche par nom.
    QueryAuctionItems(itemName)

    -- suite de ton scanner AH...
    return true
end
```

Et garde éventuellement une fonction de confort :

```lua
function Scanner.scan(itemID, callback)
    local name = GetItemInfo(itemID)
    if not name then
        return false, "item not preloaded"
    end

    return Scanner.scanByName(itemID, name, callback)
end
```

---

## Réponse directe à tes questions

1. **Pattern recommandé** : batch loader maison, event-driven, avec `RequestLoadItemDataByID`, écoute de `ITEM_DATA_LOAD_RESULT` + `GET_ITEM_INFO_RECEIVED`, retry toutes les `0.4s`, timeout autour de `5s`.

2. **`ContinueOnItemLoad` disponible ?** Oui, c’est le pattern utilisé par Auctionator, et son implémentation passe par l’async item listener Blizzard.  

3. **Synchrone ?** Non fiable. Le retry immédiat peut marcher parfois, mais il n’est pas contractuel. Les add-ons robustes attendent l’événement/callback.

4. **Item links ?** Ne compte pas dessus. Un vrai lien affiché/tooltip/chat peut amener le client à résoudre l’item, mais construire une string Lua ne force pas proprement `GetItemInfo`. Pour un scanner AH, `RequestLoadItemDataByID` est plus propre.

5. **Pour 130 items Classic Era** : aucun problème à les précharger en batch, mais fais-le avant de scanner l’AH et loggue les IDs qui échouent. Le scanner AH doit ensuite travailler uniquement avec des noms déjà résolus.

[1]: https://warcraft.wiki.gg/wiki/API_C_Item.RequestLoadItemData?utm_source=chatgpt.com "C_Item.RequestLoadItemData - Warcraft Wiki"
