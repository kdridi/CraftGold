Je vais rechercher des réponses à tes questions en consultant les sources disponibles et les add-ons existants.Je vais maintenant chercher des informations plus précises sur les patterns utilisés dans les add-ons pour le preload d'items et rechercher Auctionator sur un fork ou une source alternative.Parfait ! J'ai maintenant des infos concrètes. Laisse-moi te synthesiser ce que j'ai trouvé, en mettant en évidence **les patterns réels** utilisés par des add-ons en production.

## 📋 PATTERN RECOMMANDÉ POUR PRELOAD EN CLASSIC ERA 1.15.x

D'après plusieurs add-ons que j'ai trouvés sur GitHub, il y a **deux approches** qui fonctionnent :

### **Approche 1 : Événement `ITEM_DATA_LOAD_RESULT` (Asynchrone — RECOMMANDÉ)**

C'est la **méthode la plus robuste** pour Classic Era. Voici le pattern extrait de **prio3** et **hekili** :

```lua
local itemCallbacks = {}

local function RegisterItemLoadCallback(itemID, callback)
    if not itemCallbacks[itemID] then
        itemCallbacks[itemID] = {}
    end
    table.insert(itemCallbacks[itemID], callback)
    
    -- Déclencher le chargement
    C_Item.RequestLoadItemDataByID(itemID)
end

-- Hook l'événement
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function(_, event, itemID, success)
    if event == "GET_ITEM_INFO_RECEIVED" then
        local callbacks = itemCallbacks[itemID]
        if callbacks then
            for _, func in ipairs(callbacks) do
                func(success)
            end
            itemCallbacks[itemID] = nil
        end
    end
end)
```

**Pour preloader une liste entière** :

```lua
function PreloadItems(itemIDs, onComplete)
    local pending = #itemIDs
    local failed = {}
    
    -- Enregistrer une callback pour chaque item
    for _, itemID in ipairs(itemIDs) do
        RegisterItemLoadCallback(itemID, function(success)
            if not success then
                table.insert(failed, itemID)
            end
            pending = pending - 1
            
            -- Quand tous les items sont chargés
            if pending == 0 then
                onComplete(failed)
            end
        end)
    end
end
```

**Utilisation** :

```lua
PreloadItems({itemID1, itemID2, itemID3, ...}, function(failedItems)
    if #failedItems == 0 then
        print("✓ Tous les items sont en cache, on peut scanner")
        Scanner.scan(itemID, callback)
    else
        print("⚠ Items échoués :", table.concat(failedItems, ", "))
    end
end)
```

---

### **Approche 2 : GameTooltip Synchrone (Pour Classic 3.3.5 pré-Retail)**

Trouvée dans **Xurkon/X-Libs** (compatibilité 3.3.5) :

```lua
C_Item.RequestLoadItemDataByID = function(itemID)
    -- En 3.3.5, les items se chargent synchronement via tooltip
    GameTooltip:SetHyperlink("item:" .. itemID)
    GameTooltip:Hide()
end
```

**MAIS** : Tu dis que tu es en **Classic Era 1.15.x** — c'est closest de la vanilla originale, donc **l'approche 1 (événement) est préférable**.

---

## 🔍 CE QUE J'AI TROUVÉ DANS LES ADD-ONS RÉELS

### **Hekili (Events.lua)** — https://github.com/Bloodmallet/hekili/blob/fedd51c9597ab3538c6c6619489829ecc51c722e/Events.lua#L123-L251

```lua
function Hekili:ContinueOnItemLoad( itemID, func )
    local callbacks = itemCallbacks[ itemID ] or {}
    insert( callbacks, func )
    itemCallbacks[ itemID ] = callbacks

    C_Item.RequestLoadItemDataByID( itemID )
end

RegisterEvent( "GET_ITEM_INFO_RECEIVED", function( event, itemID, success )
    local callbacks = itemCallbacks[ itemID ]
    if callbacks then
        for i, func in ipairs( callbacks ) do
            func( success )
            callbacks[ i ] = nil
        end
        itemCallbacks[ itemID ] = nil
    end
end )
```

### **prio3 (core.lua)** — https://github.com/dieck/prio3/blob/7a26663f0ae287621dc4bd2529e3e4399d3180a5/core.lua#L51-L140

```lua
-- Trigger GetItemInfo for all items in database
local tblrequest = {}
for user, prios in pairs(self.db.profile.priorities) do
    for prio, itemid in pairs(prios) do
        tblrequest[itemid] = itemid;
    end
end
for itemid,id2 in pairs(tblrequest) do
    GetItemInfo(itemid)  -- Juste appeler GetItemInfo pour déclencher le cache
end

self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
```

### **AuctionExport** — https://github.com/lbogerd/AuctionExport/blob/8c4191e79b97e9a62d387dc05b8bc17670dc3dc8/AuctionExport.lua#L1084-L1165

Gère les chargements d'items en mass batch pour l'AH :

```lua
f:RegisterEvent("ITEM_DATA_LOAD_RESULT")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED" then
        local itemId, success = ...
        if job.pending[itemId] then
            job.loadedQueue[#job.loadedQueue + 1] = itemId
            job.loadedSuccess[itemId] = (success == true)
        end
    end
end)
```

---

## ❓ RÉPONSES À TES QUESTIONS SPÉCIFIQUES

### **1. Est-ce que `RequestLoadItemDataByID` + `GetItemInfo` immédiat fonctionne ?**

**Non, pas fiable.** Même en Classic Era, le cache n'est pas mis à jour **dans le même frame/tick**.  
Tu dois attendre l'événement `GET_ITEM_INFO_RECEIVED`.

### **2. `RequestLoadItemDataByID` vs `ContinueOnItemLoad` ?**

- **`ContinueOnItemLoad`** — API Blizzard moderne (Retail) — probablement **pas disponible en Classic Era 1.15.x**
- **`RequestLoadItemDataByID`** + **`GET_ITEM_INFO_RECEIVED`** — **c'est le pattern de base** que tu dois utiliser

### **3. Y a-t-il une méthode synchrone en Classic Era ?**

Non, pas vraiment. Même en Classic Era, le chargement est asynchrone.

**MAIS** : En Classic Era, les données **sont locales** (fichiers DB2), donc le chargement est **quasi-instantané** (~10-50ms), pas comme sur le serveur.

### **4. Créer un item link force le chargement ?**

Oui, mais **c'est un hack**. Techniquement `GameTooltip:SetHyperlink("item:" .. itemID)` charge l'item, mais c'est un side-effect non documenté. Ne pas l'utiliser en prod.

---

## 📝 FONCTION COMPLÈTE POUR TON CAS D'USAGE

```lua
-- Scanner.lua
local ns = ns or {}
ns.ItemPreloadModule = {}

local preloadModule = ns.ItemPreloadModule
preloadModule.pending = {}
preloadModule.registered = false

-- Register event handler once at addon startup
function preloadModule:Init()
    if self.registered then return end
    
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "GET_ITEM_INFO_RECEIVED" then
            self:OnItemLoaded(itemID, success)
        end
    end)
    
    self.registered = true
end

function preloadModule:OnItemLoaded(itemID, success)
    local callbacks = self.pending[itemID]
    if not callbacks then return end
    
    for _, callback in ipairs(callbacks) do
        xpcall(callback, function(err)
            print("Item load callback error: " .. tostring(err))
        end, success)
    end
    
    self.pending[itemID] = nil
end

function preloadModule:PreloadItemAsync(itemID, callback)
    if not self.registered then
        self:Init()
    end
    
    -- Check if already cached
    local name = GetItemInfo(itemID)
    if name then
        -- Already in cache, call immediately
        if callback then
            callback(true)
        end
        return
    end
    
    -- Register callback before requesting load (avoid race)
    if callback then
        self.pending[itemID] = self.pending[itemID] or {}
        table.insert(self.pending[itemID], callback)
    end
    
    -- Request load
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    else
        -- Fallback for older API
        RequestLoadItemDataByID(itemID)
    end
end

function preloadModule:PreloadItemsBatch(itemIDs, onComplete)
    if not self.registered then
        self:Init()
    end
    
    local pending = #itemIDs
    local failed = {}
    
    if pending == 0 then
        if onComplete then
            onComplete({})
        end
        return
    end
    
    for _, itemID in ipairs(itemIDs) do
        self:PreloadItemAsync(itemID, function(success)
            if not success then
                table.insert(failed, itemID)
            end
            pending = pending - 1
            
            if pending == 0 and onComplete then
                onComplete(failed)
            end
        end)
    end
end

-- ============================================
-- UTILISATION DANS Scanner.lua
-- ============================================

function Scanner.scanBatch(itemIDs, callback)
    -- Preload all items first
    ns.ItemPreloadModule:PreloadItemsBatch(itemIDs, function(failed)
        if #failed > 0 then
            print("⚠ " .. #failed .. " items failed to load:")
            for _, id in ipairs(failed) do
                print("  - itemID: " .. id)
            end
        end
        
        -- Now all items are in cache (or marked as failed)
        local results = {}
        for _, itemID in ipairs(itemIDs) do
            local success, result = Scanner.scan(itemID, callback)
            if not success then
                table.insert(results, result)
            end
        end
        
        if callback then
            callback(results)
        end
    end)
end
```

---

## 🔗 SOURCES RÉELLES AVEC LIENS

| Add-on | Pattern | Lien |
|--------|---------|------|
| **Hekili** | `RequestLoadItemDataByID` + `GET_ITEM_INFO_RECEIVED` | https://github.com/Bloodmallet/hekili/blob/fedd51c9597ab3538c6c6619489829ecc51c722e/Events.lua#L123-L251 |
| **prio3** | Batch preload via `GetItemInfo()` en boucle | https://github.com/dieck/prio3/blob/7a26663f0ae287621dc4bd2529e3e4399d3180a5/core.lua#L51-L140 |
| **AuctionExport** | Batch AH scanning avec `ITEM_DATA_LOAD_RESULT` | https://github.com/lbogerd/AuctionExport/blob/8c4191e79b97e9a62d387dc05b8bc17670dc3dc8/AuctionExport.lua#L1084-L1165 |
| **Carbonite** | Item caching wrapper avec retry logic | https://github.com/IrcDirk/Carbonite-All-in-One-Retail-Classic/blob/f32b56fd27b7e08ff7b30a4bf0a2372f0185c567/Carbonite/Modules/ItemRegistry/ItemRegistry.lua#L1-L94 |
| **Caerdon** | `ContinueOnItemLoad` (Retail, mais doc complète) | https://github.com/Caerdon/CaerdonWardrobe/blob/90c05b538c97234a0d7a9ec19a07b06504682e39/CaerdonItem.lua#L186-L271 |
| **X-Libs** | Compat 3.3.5 avec `GameTooltip:SetHyperlink` | https://github.com/Xurkon/X-Libs/blob/52a175d260ff4079beeef8e34bffb9b9596a428f/Compat-335.lua#L891-L1000 |

---

## ⚠️ POINTS CRITIQUES POUR TON CAS

1. **Timing** : En Classic Era, quasi-instantané (~10-50ms) car données locales. Toujours attendre l'événement.

2. **Événement** : `GET_ITEM_INFO_RECEIVED` (ou `ITEM_DATA_LOAD_RESULT` en Retail/Dragonflight, mais `GET_ITEM_INFO_RECEIVED` en Classic).

3. **Fallback** : Si `C_Item.RequestLoadItemDataByID` n'existe pas, utilise `RequestLoadItemDataByID(itemID)`.

4. **Race condition** : Enregistre le callback **avant** d'appeler `RequestLoadItemDataByID()`, sinon tu risques de rater l'événement.

5. **Déjà en cache** : Toujours checker `GetItemInfo()` d'abord — si c'est déjà là, pas besoin de demander.

---

Ça te convient ? Tu veux que je creuse un point en particulier (ex. les étapes du Compat 335 vs Classic Era, ou comment gérer les retry si un item refuse de charger) ?