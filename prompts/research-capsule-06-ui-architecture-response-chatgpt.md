````markdown
# Architecture UI orientée données pour add-on WoW Lua — cas `GetItemInfo()` async

## Verdict

Pour **CraftGold**, le meilleur compromis est :

1. **Component-oriented + Mixin Lua + `ItemResolver` central**  
   Chaque ligne est autonome (`RecipeLine:Render`, `RecipeLine:OnItemReady`, `RecipeLine:Destroy`), mais les événements WoW restent centralisés dans un petit service. C’est le meilleur pattern pour votre problème exact.

2. **Observer/Event-driven ciblé par `itemID`**  
   Nécessaire en dessous, car `GetItemInfo()` peut retourner `nil` et `GET_ITEM_INFO_RECEIVED` arrive plus tard.

3. **MVU/MVP-lite pour la logique métier testable**  
   Très bon pour tester les décisions, mais moins “component-oriented” si toute la logique de rendu remonte dans un parent.

4. **Signal-based explicite**  
   Très élégant, mais en Lua 5.1 il faut écrire soi-même les signaux ; pas de proxy comme Vue, pas de compilateur comme Svelte.

5. **Declarative/reconciler-lite**  
   Intéressant pédagogiquement, mais facilement surdimensionné pour une simple liste de recettes.

Je déconseille **ECS** et **immediate mode pur** pour cette UI précise. L’ECS est excellent pour des mondes dynamiques ou beaucoup de systèmes, mais une liste de recettes avec async item-cache n’a pas besoin d’une architecture jeu complète. L’immediate mode pur est mal adapté à WoW parce que l’UI WoW est un système retained-mode : on crée des Frames/FontStrings, on les conserve, on les modifie via `SetText`, `Hide`, etc. `CreateFrame()` crée des widgets WoW, les événements passent par des Frames enregistrées, et l’`OnEvent` reçoit `self`, `event`, puis les arguments de l’événement. :contentReference[oaicite:0]{index=0}

---

## Contraintes vérifiées

`GetItemInfo(itemID)` peut retourner `nil` si l’objet n’est pas encore chargé/caché. L’événement `GET_ITEM_INFO_RECEIVED` est déclenché quand une requête `GetItemInfo` pour un item non caché reçoit une réponse, avec `itemID` et `success` en payload. Des discussions d’auteurs d’add-ons confirment aussi le flux pratique : appeler `GetItemInfo`, afficher un placeholder si `nil`, attendre `GET_ITEM_INFO_RECEIVED`, puis rappeler `GetItemInfo`. :contentReference[oaicite:1]{index=1}

Lua 5.1 n’a pas de classes natives, mais les tables sont des tableaux associatifs indexables par presque n’importe quelle valeur, et les metatables permettent d’implémenter des objets/prototypes via `__index`. C’est suffisant pour faire des composants UI propres en style `Component:new(...):Render()`. :contentReference[oaicite:2]{index=2}

WoW lui-même expose des helpers de type mixin (`Mixin`, `CreateFromMixins`) et les décrit comme un mécanisme proche de l’héritage multiple par copie de méthodes. :contentReference[oaicite:3]{index=3}

---

# Top 1 — Component-oriented + `ItemResolver` central

## Description

Chaque ligne de recette est un objet Lua autonome. Elle possède sa frame, sa FontString, ses données, son `Render()`, et son handler `OnItemReady()`. Le seul index `itemID -> composants` existe encore, mais il est encapsulé dans un service d’infrastructure (`ItemResolver`), pas dans le code de création visuelle.

C’est le pattern le plus proche de React/Vue/Svelte dans l’esprit : composant = données + rendu + réaction locale. React encourage à découper l’UI en pièces indépendantes et réutilisables ; Vue/Svelte propagent les changements de données vers l’UI via réactivité, mais en Lua 5.1 il faut rendre cette réactivité explicite. :contentReference[oaicite:4]{index=4}

## Avantages dans votre contexte

- La logique d’une ligne est rassemblée dans `RecipeLine`.
- L’async `GetItemInfo` ne pollue pas le parent.
- Le parent ne connaît pas les `FontString`.
- Très testable : on injecte `env.GetItemInfo`, `env.CreateFrame`, et on simule `GET_ITEM_INFO_RECEIVED`.
- Idiomatique WoW : proche des mixins, widgets AceGUI, WeakAuras regions, etc. AceGUI fournit des widgets créés puis manipulés via méthodes, et WeakAuras a des prototypes de régions et un système interne de callbacks. :contentReference[oaicite:5]{index=5}

## Inconvénients

- Il y a toujours un registre central, mais il est caché dans le resolver.
- Il faut gérer la destruction/désinscription si la liste est reconstruite.
- Si chaque composant enregistre directement `GET_ITEM_INFO_RECEIVED`, vous multipliez les handlers ; il vaut mieux un dispatcher central.

## Code complet

```lua
-- CraftGold_Component.lua
-- Lua 5.1 / WoW Classic Era compatible

local CraftGold = {}

------------------------------------------------------------
-- ItemResolver
-- Service central : cache, GetItemInfo, subscriptions par itemID.
-- Il ne connaît PAS les FontString. Il connaît seulement des callbacks.
------------------------------------------------------------

local ItemResolver = {}
ItemResolver.__index = ItemResolver

function ItemResolver:New(env)
    local o = {
        env = env,
        listenersByItemID = {},
        frame = env.CreateFrame("Frame"),
    }
    setmetatable(o, self)

    o.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    o.frame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "GET_ITEM_INFO_RECEIVED" then
            o:OnItemInfoReceived(itemID, success)
        end
    end)

    return o
end

function ItemResolver:GetName(itemID)
    local name = self.env.GetItemInfo(itemID)
    if name then
        return name, true
    end

    -- Appeler GetItemInfo suffit à déclencher la requête async côté client
    -- si l'item n'est pas chargé.
    return ("Item #%d (chargement...)"):format(itemID), false
end

function ItemResolver:Subscribe(itemID, owner, callback)
    local list = self.listenersByItemID[itemID]
    if not list then
        list = {}
        self.listenersByItemID[itemID] = list
    end

    local entry = { owner = owner, callback = callback }
    list[#list + 1] = entry

    return function()
        local current = self.listenersByItemID[itemID]
        if not current then return end

        for i = #current, 1, -1 do
            if current[i] == entry then
                table.remove(current, i)
                break
            end
        end

        if #current == 0 then
            self.listenersByItemID[itemID] = nil
        end
    end
end

function ItemResolver:OnItemInfoReceived(itemID, success)
    if not success then return end

    local list = self.listenersByItemID[itemID]
    if not list then return end

    -- Copie défensive : un callback peut se désinscrire.
    local copy = {}
    for i = 1, #list do
        copy[i] = list[i]
    end

    for i = 1, #copy do
        local entry = copy[i]
        entry.callback(entry.owner, itemID)
    end
end

------------------------------------------------------------
-- RecipeLine component
------------------------------------------------------------

local RecipeLine = {}
RecipeLine.__index = RecipeLine

function RecipeLine:New(parent, recipe, y, resolver, env)
    local row = env.CreateFrame("Frame", nil, parent)
    row:SetSize(360, 20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", row, "LEFT", 0, 0)

    local o = {
        frame = row,
        text = text,
        recipe = recipe,
        resolver = resolver,
        env = env,
        unsubscribe = nil,
    }

    setmetatable(o, self)

    o.unsubscribe = resolver:Subscribe(recipe.itemID, o, o.OnItemReady)
    o:Render()

    return o
end

function RecipeLine:FormatLine()
    local itemName, loaded = self.resolver:GetName(self.recipe.itemID)

    local prefix = loaded and "" or "|cff888888"
    local suffix = loaded and "" or "|r"

    return ("%s%s  |cffaaaaaaskill:%d|r%s"):format(
        prefix,
        itemName,
        self.recipe.skill or 0,
        suffix
    )
end

function RecipeLine:Render()
    self.text:SetText(self:FormatLine())
end

function RecipeLine:OnItemReady(itemID)
    if itemID == self.recipe.itemID then
        self:Render()
    end
end

function RecipeLine:Destroy()
    if self.unsubscribe then
        self.unsubscribe()
        self.unsubscribe = nil
    end
    self.frame:Hide()
end

------------------------------------------------------------
-- RecipeList component
------------------------------------------------------------

local RecipeList = {}
RecipeList.__index = RecipeList

function RecipeList:New(parent, recipes, resolver, env)
    local o = {
        parent = parent,
        recipes = recipes,
        resolver = resolver,
        env = env,
        lines = {},
    }
    setmetatable(o, self)
    o:Render()
    return o
end

function RecipeList:Render()
    for i = 1, #self.recipes do
        local recipe = self.recipes[i]
        self.lines[i] = RecipeLine:New(
            self.parent,
            recipe,
            -10 - (i - 1) * 22,
            self.resolver,
            self.env
        )
    end
end

function RecipeList:Destroy()
    for i = 1, #self.lines do
        self.lines[i]:Destroy()
    end
    self.lines = {}
end

------------------------------------------------------------
-- Public entry point
------------------------------------------------------------

function CraftGold.Create(parent)
    local env = {
        CreateFrame = CreateFrame,
        GetItemInfo = GetItemInfo,
    }

    local recipes = {
        { itemID = 4360, skill = 1   }, -- Rough Copper Bomb
        { itemID = 4362, skill = 30  }, -- Rough Boomstick
        { itemID = 4371, skill = 75  }, -- Bronze Tube
        { itemID = 4384, skill = 120 }, -- Explosive Sheep
    }

    local resolver = ItemResolver:New(env)
    local list = RecipeList:New(parent, recipes, resolver, env)

    return {
        resolver = resolver,
        list = list,
    }
end

_G.CraftGold = CraftGold
````

## Testabilité

Très bonne. Vous pouvez tester `RecipeLine:Render()` sans WoW en injectant un faux `env` :

```lua
local fakeText = { value = nil }
function fakeText:SetPoint() end
function fakeText:SetText(v) self.value = v end

local fakeFrame = {}
function fakeFrame:SetSize() end
function fakeFrame:SetPoint() end
function fakeFrame:CreateFontString() return fakeText end
function fakeFrame:RegisterEvent() end
function fakeFrame:SetScript(_, fn) self.onEvent = fn end
function fakeFrame:Hide() self.hidden = true end

local fakeEnv = {
    CreateFrame = function() return fakeFrame end,
    GetItemInfo = function(itemID)
        if itemID == 4360 then return "Rough Copper Bomb" end
        return nil
    end
}
```

---

# Top 2 — Observer / Event-driven ciblé

## Description

Le pattern Observer sépare l’émetteur d’événements des abonnés. Ici, `ItemBus` publie `ITEM_READY:itemID`, et chaque ligne s’abonne seulement à son item. C’est proche d’AceEvent/CallbackHandler : AceEvent centralise l’enregistrement aux événements Blizzard puis redistribue vers des callbacks, et CallbackHandler fournit une mécanique de callbacks réutilisable. ([WowAce][1])

## Avantages

* Très naturel pour `GET_ITEM_INFO_RECEIVED`.
* Simple à tester : on appelle `bus:Emit("ITEM_READY", itemID)`.
* Permet plusieurs vues pour le même item sans couplage.

## Inconvénients

* Moins encapsulé qu’un composant pur si le bus devient global.
* Risque de fuite si on oublie de `Unsubscribe`.
* Les chaînes d’événements peuvent devenir difficiles à suivre.

## Projets proches

* **AceEvent-3.0 / CallbackHandler-1.0** : dispatch d’événements et callbacks dans l’écosystème WoW. ([WowAce][1])
* **WeakAuras** : système interne simple `RegisterCallback` / `Fire`. ([GitHub][2])
* **GetItemInfoAsync** : transforme précisément `GetItemInfo` + `GET_ITEM_INFO_RECEIVED` en callback sync/async. ([CurseForge][3])

## Code complet

```lua
-- CraftGold_Observer.lua

local function NewBus()
    local bus = { listeners = {} }

    function bus:On(eventName, owner, fn)
        local list = self.listeners[eventName]
        if not list then
            list = {}
            self.listeners[eventName] = list
        end

        local entry = { owner = owner, fn = fn }
        list[#list + 1] = entry

        return function()
            local current = self.listeners[eventName]
            if not current then return end
            for i = #current, 1, -1 do
                if current[i] == entry then
                    table.remove(current, i)
                    break
                end
            end
        end
    end

    function bus:Emit(eventName, ...)
        local list = self.listeners[eventName]
        if not list then return end

        local copy = {}
        for i = 1, #list do copy[i] = list[i] end

        for i = 1, #copy do
            copy[i].fn(copy[i].owner, ...)
        end
    end

    return bus
end

local function NewItemLoader(bus, env)
    local loader = {
        bus = bus,
        env = env,
        frame = env.CreateFrame("Frame"),
    }

    loader.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    loader.frame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "GET_ITEM_INFO_RECEIVED" and success then
            bus:Emit("ITEM_READY:" .. tostring(itemID), itemID)
        end
    end)

    function loader:GetNameOrPlaceholder(itemID)
        local name = env.GetItemInfo(itemID)
        if name then return name, true end
        return ("Item #%d (chargement...)"):format(itemID), false
    end

    return loader
end

local RecipeLine = {}
RecipeLine.__index = RecipeLine

function RecipeLine:New(parent, recipe, y, itemLoader, bus, env)
    local frame = env.CreateFrame("Frame", nil, parent)
    frame:SetSize(360, 20)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT")

    local o = {
        frame = frame,
        text = text,
        recipe = recipe,
        itemLoader = itemLoader,
        bus = bus,
    }

    setmetatable(o, self)

    o.off = bus:On("ITEM_READY:" .. tostring(recipe.itemID), o, o.OnItemReady)
    o:Render()

    return o
end

function RecipeLine:Render()
    local name, loaded = self.itemLoader:GetNameOrPlaceholder(self.recipe.itemID)
    if loaded then
        self.text:SetText(name)
    else
        self.text:SetText("|cff888888" .. name .. "|r")
    end
end

function RecipeLine:OnItemReady()
    self:Render()
end

function RecipeLine:Destroy()
    if self.off then self.off() end
    self.frame:Hide()
end

function CraftGoldObserver_Create(parent)
    local env = { CreateFrame = CreateFrame, GetItemInfo = GetItemInfo }
    local bus = NewBus()
    local loader = NewItemLoader(bus, env)

    local recipes = {
        { itemID = 4360 },
        { itemID = 4362 },
        { itemID = 4371 },
        { itemID = 4384 },
    }

    local lines = {}
    for i = 1, #recipes do
        lines[i] = RecipeLine:New(parent, recipes[i], -10 - (i - 1) * 22, loader, bus, env)
    end

    return { bus = bus, loader = loader, lines = lines }
end
```

## Testabilité

Très bonne pour les événements. Il suffit de tester :

```lua
bus:Emit("ITEM_READY:4360", 4360)
assert(fakeText.value == "Rough Copper Bomb")
```

Le danger est architectural : si tout le système devient un gros bus global avec des noms d’événements stringly-typed, les tests restent faciles mais le design devient fragile.

---

# Top 3 — MVU / MVP-lite

## Description

MVU vient de l’architecture Elm : `Model` = état, `View` = transformation de l’état en UI, `Update` = transformation de l’état en réponse à des messages. Elm décrit explicitement ce triptyque `Model / View / Update`. ([guide.elm-lang.org][4])

En WoW Lua, on peut faire une version “lite” : les lignes deviennent des vues stupides, le modèle sait quels items sont chargés, et `Update({ type = "ITEM_READY", itemID = ... })` déclenche un rendu.

## Avantages

* Excellent pour tests unitaires.
* Flux très prévisible.
* Les événements async deviennent de simples messages.
* Très adapté si CraftGold va évoluer vers calculs, filtres, tri, prix AH, simulation de coûts.

## Inconvénients

* Moins “ligne autonome”.
* Peut devenir centralisé si tout passe par un gros `Update`.
* Le rendu WoW reste impératif, donc on ne gagne pas toute la pureté d’Elm.

## Projet proche

* **Core Loot Manager** indique utiliser Event Sourcing et MVC pour gérer synchronisation, stockage et robustesse. ([CurseForge][5])

## Code complet

```lua
-- CraftGold_MVU.lua

local function initModel(recipes)
    local rows = {}
    for i = 1, #recipes do
        rows[i] = {
            itemID = recipes[i].itemID,
            skill = recipes[i].skill or 0,
            itemName = nil,
            loaded = false,
        }
    end
    return { rows = rows }
end

local function loadItemInfoIntoModel(model, env)
    for i = 1, #model.rows do
        local row = model.rows[i]
        local name = env.GetItemInfo(row.itemID)
        row.itemName = name
        row.loaded = name ~= nil
    end
end

local function update(model, msg, env)
    if msg.type == "INIT" then
        loadItemInfoIntoModel(model, env)
    elseif msg.type == "ITEM_READY" then
        for i = 1, #model.rows do
            local row = model.rows[i]
            if row.itemID == msg.itemID then
                local name = env.GetItemInfo(row.itemID)
                row.itemName = name
                row.loaded = name ~= nil
            end
        end
    end
end

local function formatRow(row)
    local name = row.itemName or ("Item #" .. row.itemID .. " (chargement...)")
    if row.loaded then
        return ("%s  |cffaaaaaaskill:%d|r"):format(name, row.skill)
    else
        return ("|cff888888%s  skill:%d|r"):format(name, row.skill)
    end
end

local function createView(parent, model, env)
    local view = { texts = {} }

    for i = 1, #model.rows do
        local frame = env.CreateFrame("Frame", nil, parent)
        frame:SetSize(360, 20)
        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10 - (i - 1) * 22)

        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT")
        view.texts[i] = text
    end

    return view
end

local function render(model, view)
    for i = 1, #model.rows do
        view.texts[i]:SetText(formatRow(model.rows[i]))
    end
end

function CraftGoldMVU_Create(parent)
    local env = { CreateFrame = CreateFrame, GetItemInfo = GetItemInfo }

    local recipes = {
        { itemID = 4360, skill = 1 },
        { itemID = 4362, skill = 30 },
        { itemID = 4371, skill = 75 },
        { itemID = 4384, skill = 120 },
    }

    local model = initModel(recipes)
    local view = createView(parent, model, env)

    local eventFrame = env.CreateFrame("Frame")
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    eventFrame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "GET_ITEM_INFO_RECEIVED" and success then
            update(model, { type = "ITEM_READY", itemID = itemID }, env)
            render(model, view)
        end
    end)

    update(model, { type = "INIT" }, env)
    render(model, view)

    return { model = model, view = view, eventFrame = eventFrame }
end
```

## Testabilité

Excellente. `update(model, msg, fakeEnv)` et `formatRow(row)` sont testables sans WoW. C’est probablement le meilleur pattern pour tester les calculs de coût récursifs de CraftGold. Pour l’UI pure, il est un peu moins encapsulé que le pattern composant.

---

# Top 4 — Signal-based / Reactive explicite

## Description

Un signal est une valeur observable : quand la valeur change, les abonnés sont notifiés. Vue parle de données réactives qui déclenchent des mises à jour ; Svelte expose aussi des primitives de state réactif. Côté Lua/Luau, Roblox a des projets de signaux et de réactivité fine-grained ; par exemple `Roblox/signals` décrit des primitives qui suivent les dépendances et relancent seulement les calculs nécessaires. ([Vue.js][6])

En Lua 5.1, sans proxy ni compilateur, la version réaliste est explicite : `signal:Set(value)` puis les callbacks se déclenchent.

## Avantages

* Très élégant pour `itemNameSignal`.
* La ligne ne connaît pas `GET_ITEM_INFO_RECEIVED`.
* Une même donnée peut alimenter plusieurs composants.
* Facile à tester.

## Inconvénients

* Il faut écrire et maintenir la mini-lib Signal.
* Débogage plus indirect.
* En Lua 5.1, pas de tracking automatique des dépendances : tout est manuel.

## Projets proches

* **Vue / Svelte** pour l’idée générale de réactivité. ([Vue.js][6])
* **Roblox/signals**, **Fusion**, **GoodSignal** côté Lua/Luau. ([GitHub][7])

## Code complet

```lua
-- CraftGold_Signals.lua

local Signal = {}
Signal.__index = Signal

function Signal:New(value)
    return setmetatable({
        value = value,
        listeners = {},
    }, self)
end

function Signal:Get()
    return self.value
end

function Signal:Set(value)
    if self.value == value then return end
    self.value = value

    local copy = {}
    for i = 1, #self.listeners do copy[i] = self.listeners[i] end

    for i = 1, #copy do
        copy[i](value)
    end
end

function Signal:Subscribe(fn)
    self.listeners[#self.listeners + 1] = fn

    return function()
        for i = #self.listeners, 1, -1 do
            if self.listeners[i] == fn then
                table.remove(self.listeners, i)
                break
            end
        end
    end
end

local ItemStore = {}
ItemStore.__index = ItemStore

function ItemStore:New(env)
    local o = {
        env = env,
        nameSignals = {},
        frame = env.CreateFrame("Frame"),
    }
    setmetatable(o, self)

    o.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    o.frame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "GET_ITEM_INFO_RECEIVED" and success then
            o:RefreshItem(itemID)
        end
    end)

    return o
end

function ItemStore:GetNameSignal(itemID)
    local sig = self.nameSignals[itemID]
    if sig then return sig end

    local name = self.env.GetItemInfo(itemID)
    sig = Signal:New(name)
    self.nameSignals[itemID] = sig

    return sig
end

function ItemStore:RefreshItem(itemID)
    local sig = self.nameSignals[itemID]
    if not sig then return end

    local name = self.env.GetItemInfo(itemID)
    if name then
        sig:Set(name)
    end
end

local RecipeLine = {}
RecipeLine.__index = RecipeLine

function RecipeLine:New(parent, recipe, y, store, env)
    local frame = env.CreateFrame("Frame", nil, parent)
    frame:SetSize(360, 20)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT")

    local o = {
        frame = frame,
        text = text,
        recipe = recipe,
        store = store,
    }
    setmetatable(o, self)

    local sig = store:GetNameSignal(recipe.itemID)
    o.unsubscribe = sig:Subscribe(function()
        o:Render()
    end)

    o:Render()
    return o
end

function RecipeLine:Render()
    local sig = self.store:GetNameSignal(self.recipe.itemID)
    local name = sig:Get()

    if name then
        self.text:SetText(name)
    else
        self.text:SetText("|cff888888Item #" .. self.recipe.itemID .. " (chargement...)|r")
    end
end

function RecipeLine:Destroy()
    if self.unsubscribe then self.unsubscribe() end
    self.frame:Hide()
end

function CraftGoldSignals_Create(parent)
    local env = { CreateFrame = CreateFrame, GetItemInfo = GetItemInfo }
    local store = ItemStore:New(env)

    local recipes = {
        { itemID = 4360 },
        { itemID = 4362 },
        { itemID = 4371 },
        { itemID = 4384 },
    }

    local lines = {}
    for i = 1, #recipes do
        lines[i] = RecipeLine:New(parent, recipes[i], -10 - (i - 1) * 22, store, env)
    end

    return { store = store, lines = lines }
end
```

## Testabilité

Très bonne. Test unitaire minimal :

```lua
local s = Signal:New(nil)
local seen = nil
s:Subscribe(function(v) seen = v end)
s:Set("Bronze Tube")
assert(seen == "Bronze Tube")
```

Ce pattern devient excellent si CraftGold a plusieurs panneaux qui affichent les mêmes items, prix, coûts et marges.

---

# Top 5 — Data-driven / Declarative + reconciler-lite

## Description

On décrit l’UI souhaitée comme une table de données, puis un petit moteur met à jour les Frames existantes. C’est l’idée générale de React/Roact : l’UI est décrite déclarativement, puis un runtime crée/met à jour la vue. Roact est une bibliothèque Lua/Luau inspirée de React, et React Luau est une traduction de ReactJS en Luau. ([Roblox][8])

WoW a aussi une forme déclarative historique avec XML/FrameXML et templates héritables, mais dans un add-on Lua pédagogique sans build step, une table Lua déclarative est plus simple. Les templates XML WoW permettent de partager propriétés/enfants/attributs entre widgets héritant d’un template. ([Warcraft Wiki][9])

## Avantages

* Très lisible pour décrire des listes.
* Permet de séparer `describe(model)` et `reconcile(parent, description)`.
* Prépare une future UI plus riche.

## Inconvénients

* Il faut écrire un mini-reconciler.
* On réinvente une petite partie de React.
* Risque d’over-engineering pour 20 lignes.

## Code complet

```lua
-- CraftGold_Declarative.lua

local function describeRecipeLine(recipe, name)
    return {
        type = "RecipeLine",
        key = recipe.itemID,
        itemID = recipe.itemID,
        text = name or ("Item #" .. recipe.itemID .. " (chargement...)"),
        loaded = name ~= nil,
    }
end

local function describeList(recipes, env)
    local children = {}

    for i = 1, #recipes do
        local recipe = recipes[i]
        local name = env.GetItemInfo(recipe.itemID)
        children[#children + 1] = describeRecipeLine(recipe, name)
    end

    return {
        type = "RecipeList",
        children = children,
    }
end

local Renderer = {}
Renderer.__index = Renderer

function Renderer:New(parent, env)
    return setmetatable({
        parent = parent,
        env = env,
        rowsByKey = {},
    }, self)
end

function Renderer:Render(tree)
    local used = {}

    for i = 1, #tree.children do
        local node = tree.children[i]
        local row = self.rowsByKey[node.key]

        if not row then
            row = self:CreateRow(i)
            self.rowsByKey[node.key] = row
        end

        used[node.key] = true
        row.frame:Show()
        row.frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 10, -10 - (i - 1) * 22)

        if node.loaded then
            row.text:SetText(node.text)
        else
            row.text:SetText("|cff888888" .. node.text .. "|r")
        end
    end

    for key, row in pairs(self.rowsByKey) do
        if not used[key] then
            row.frame:Hide()
        end
    end
end

function Renderer:CreateRow()
    local frame = self.env.CreateFrame("Frame", nil, self.parent)
    frame:SetSize(360, 20)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT")

    return { frame = frame, text = text }
end

function CraftGoldDeclarative_Create(parent)
    local env = { CreateFrame = CreateFrame, GetItemInfo = GetItemInfo }

    local recipes = {
        { itemID = 4360 },
        { itemID = 4362 },
        { itemID = 4371 },
        { itemID = 4384 },
    }

    local renderer = Renderer:New(parent, env)

    local function rerender()
        renderer:Render(describeList(recipes, env))
    end

    local eventFrame = env.CreateFrame("Frame")
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    eventFrame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "GET_ITEM_INFO_RECEIVED" and success then
            rerender()
        end
    end)

    rerender()

    return { renderer = renderer, eventFrame = eventFrame }
end
```

## Testabilité

Bonne pour `describeList()` : c’est une pure transformation données → arbre descriptif. Moyenne pour `Renderer`, car il touche les Frames WoW. Ce pattern devient intéressant quand vous voulez tester la forme de l’UI sans créer de Frames.

---

# Pattern 6 — Mixin / Module pattern idiomatique WoW

## Description

Un mixin est une table de méthodes copiée dans un objet ou une Frame. C’est très idiomatique côté WoW moderne : `Mixin(object, SomeMixin)` ou `CreateFromMixins(...)`. Warcraft Wiki décrit `Mixin` et `CreateFromMixins` comme des mécanismes proches de classes/mixins. ([Warcraft Wiki][10])

En Lua 5.1 Classic, vous pouvez faire la même chose sans dépendre de `Mixin()` si besoin : copier les méthodes manuellement dans la frame.

## Avantages

* Très proche de l’écosystème WoW.
* Permet d’avoir `frame:Init(recipe)` puis `frame:Render()`.
* Moins d’objets séparés : la Frame est le composant.

## Inconvénients

* Mélange objet métier et widget WoW.
* Plus difficile à tester si vos méthodes appellent directement `self:CreateFontString`.
* Peut devenir confus si vous mixez trop de comportements.

## Projets proches

* Blizzard FrameXML mixins. ([Warcraft Wiki][10])
* WeakAuras utilise des prototypes/régions ; AceGUI définit des widgets Lua autour de Frames. ([GitHub][11])

## Code complet

```lua
-- CraftGold_Mixin.lua

local function ApplyMixin(object, mixin)
    for k, v in pairs(mixin) do
        object[k] = v
    end
    return object
end

local RecipeLineMixin = {}

function RecipeLineMixin:Init(recipe, itemResolver)
    self.recipe = recipe
    self.itemResolver = itemResolver

    self:SetSize(360, 20)

    self.text = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.text:SetPoint("LEFT")

    self.unsubscribe = itemResolver:Subscribe(recipe.itemID, self, self.OnItemReady)
    self:Render()
end

function RecipeLineMixin:Render()
    local name, loaded = self.itemResolver:GetName(self.recipe.itemID)
    if loaded then
        self.text:SetText(name)
    else
        self.text:SetText("|cff888888" .. name .. "|r")
    end
end

function RecipeLineMixin:OnItemReady(itemID)
    if itemID == self.recipe.itemID then
        self:Render()
    end
end

function RecipeLineMixin:Destroy()
    if self.unsubscribe then self.unsubscribe() end
    self:Hide()
end

local ItemResolver = {}
ItemResolver.__index = ItemResolver

function ItemResolver:New(env)
    local o = {
        env = env,
        listeners = {},
        frame = env.CreateFrame("Frame"),
    }
    setmetatable(o, self)

    o.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    o.frame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "GET_ITEM_INFO_RECEIVED" and success then
            o:Notify(itemID)
        end
    end)

    return o
end

function ItemResolver:GetName(itemID)
    local name = self.env.GetItemInfo(itemID)
    if name then return name, true end
    return ("Item #%d (chargement...)"):format(itemID), false
end

function ItemResolver:Subscribe(itemID, owner, fn)
    self.listeners[itemID] = self.listeners[itemID] or {}
    local list = self.listeners[itemID]
    local entry = { owner = owner, fn = fn }
    list[#list + 1] = entry

    return function()
        for i = #list, 1, -1 do
            if list[i] == entry then
                table.remove(list, i)
                break
            end
        end
    end
end

function ItemResolver:Notify(itemID)
    local list = self.listeners[itemID]
    if not list then return end

    for i = 1, #list do
        list[i].fn(list[i].owner, itemID)
    end
end

function CraftGoldMixin_Create(parent)
    local env = { CreateFrame = CreateFrame, GetItemInfo = GetItemInfo }
    local resolver = ItemResolver:New(env)

    local recipes = {
        { itemID = 4360 },
        { itemID = 4362 },
        { itemID = 4371 },
        { itemID = 4384 },
    }

    local lines = {}
    for i = 1, #recipes do
        local line = ApplyMixin(env.CreateFrame("Frame", nil, parent), RecipeLineMixin)
        line:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10 - (i - 1) * 22)
        line:Init(recipes[i], resolver)
        lines[i] = line
    end

    return { resolver = resolver, lines = lines }
end
```

## Testabilité

Moyenne. Le mixin est testable si vous lui donnez une fausse frame avec `CreateFontString`, `SetSize`, `SetPoint`, `Hide`. C’est acceptable pour un add-on WoW, mais moins pur que `RecipeLine` objet séparé.

---

# Pattern 7 — ECS

## Description

ECS sépare `Entity` = identité, `Component` = données, `System` = logique. En Lua, des projets comme `tiny-ecs`, `lovetoys` et `Concord` montrent que le pattern existe bien dans l’écosystème Lua/LÖVE. `tiny-ecs` décrit les entités comme de simples tables de données traitées par des systèmes, ce qui colle bien à la nature tabulaire de Lua. ([GitHub][12])

## Avantages

* Très structuré pour beaucoup d’entités.
* Très bon si CraftGold devient une simulation visuelle complexe.
* Les systèmes sont testables séparément.

## Inconvénients dans votre cas

* Surdimensionné pour une liste UI.
* L’encapsulation “une ligne sait se mettre à jour” disparaît : la logique est dans les systèmes.
* Moins idiomatique WoW UI.
* Plus difficile à expliquer à des débutants add-on WoW.

## Code complet

```lua
-- CraftGold_ECS.lua

local World = {}
World.__index = World

function World:New()
    return setmetatable({
        entities = {},
        nextID = 0,
    }, self)
end

function World:CreateEntity(components)
    self.nextID = self.nextID + 1
    components.id = self.nextID
    self.entities[self.nextID] = components
    return components
end

local function ItemLoadingSystem(world, env)
    for _, e in pairs(world.entities) do
        if e.recipe and e.item then
            local name = env.GetItemInfo(e.recipe.itemID)
            if name then
                e.item.name = name
                e.item.loaded = true
            else
                e.item.name = nil
                e.item.loaded = false
            end
        end
    end
end

local function RenderSystem(world)
    for _, e in pairs(world.entities) do
        if e.recipe and e.item and e.ui then
            local text
            if e.item.loaded then
                text = e.item.name
            else
                text = "|cff888888Item #" .. e.recipe.itemID .. " (chargement...)|r"
            end
            e.ui.text:SetText(text)
        end
    end
end

local function RefreshOneItemSystem(world, env, itemID)
    for _, e in pairs(world.entities) do
        if e.recipe and e.recipe.itemID == itemID and e.item then
            local name = env.GetItemInfo(itemID)
            if name then
                e.item.name = name
                e.item.loaded = true
            end
        end
    end
end

function CraftGoldECS_Create(parent)
    local env = { CreateFrame = CreateFrame, GetItemInfo = GetItemInfo }
    local world = World:New()

    local recipes = {
        { itemID = 4360 },
        { itemID = 4362 },
        { itemID = 4371 },
        { itemID = 4384 },
    }

    for i = 1, #recipes do
        local frame = env.CreateFrame("Frame", nil, parent)
        frame:SetSize(360, 20)
        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10 - (i - 1) * 22)

        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT")

        world:CreateEntity({
            recipe = recipes[i],
            item = { name = nil, loaded = false },
            ui = { frame = frame, text = text },
        })
    end

    local eventFrame = env.CreateFrame("Frame")
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    eventFrame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "GET_ITEM_INFO_RECEIVED" and success then
            RefreshOneItemSystem(world, env, itemID)
            RenderSystem(world)
        end
    end)

    ItemLoadingSystem(world, env)
    RenderSystem(world)

    return { world = world, eventFrame = eventFrame }
end
```

## Testabilité

Bonne pour les systèmes purs (`ItemLoadingSystem`, `RefreshOneItemSystem`) si `env.GetItemInfo` est mocké. Mauvaise pour l’encapsulation composant : une ligne ne possède pas vraiment son comportement.

---

# Pattern 8 — Immediate mode UI, version compatible WoW

## Description

L’immediate mode consiste à décrire/redessiner l’UI depuis la boucle de rendu ou un appel de fonction, plutôt que de conserver un arbre de widgets riche. Dear ImGui est l’exemple classique : il permet d’écrire directement `Text`, `Button`, etc. dans le flux du programme, et il est pensé pour des outils/debug UIs en contexte moteur/temps réel. ([GitHub][13])

En WoW, il faut éviter le “pur” immediate mode qui recrée les Frames sans arrêt. La version raisonnable est un **immediate-like retained pool** : vous rappelez `Render(recipes)` quand les données changent, mais vous réutilisez les lignes existantes.

## Avantages

* Très simple.
* Excellent pour debug panels.
* Peu d’architecture.

## Inconvénients

* Moins encapsulé.
* Peut faire trop de `SetText`.
* Pas idéal pour une UI utilisateur riche.
* Il faut éviter la création massive répétée de Frames ; dans l’écosystème WoW, on préfère créer puis cacher/réutiliser. Une discussion WoWInterface rappelle qu’on ne “supprime” pas vraiment une frame créée, on la cache/réutilise. ([WoWInterface][14])

## Code complet

```lua
-- CraftGold_ImmediateLike.lua

local function createRow(parent, env)
    local frame = env.CreateFrame("Frame", nil, parent)
    frame:SetSize(360, 20)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT")

    return { frame = frame, text = text }
end

local function renderList(state)
    local env = state.env
    local parent = state.parent
    local recipes = state.recipes

    for i = 1, #recipes do
        local row = state.pool[i]
        if not row then
            row = createRow(parent, env)
            state.pool[i] = row
        end

        row.frame:Show()
        row.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10 - (i - 1) * 22)

        local itemID = recipes[i].itemID
        local name = env.GetItemInfo(itemID)

        if name then
            row.text:SetText(name)
        else
            row.text:SetText("|cff888888Item #" .. itemID .. " (chargement...)|r")
        end
    end

    for i = #recipes + 1, #state.pool do
        state.pool[i].frame:Hide()
    end
end

function CraftGoldImmediateLike_Create(parent)
    local state = {
        env = { CreateFrame = CreateFrame, GetItemInfo = GetItemInfo },
        parent = parent,
        pool = {},
        recipes = {
            { itemID = 4360 },
            { itemID = 4362 },
            { itemID = 4371 },
            { itemID = 4384 },
        },
    }

    local eventFrame = state.env.CreateFrame("Frame")
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    eventFrame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "GET_ITEM_INFO_RECEIVED" and success then
            renderList(state)
        end
    end)

    renderList(state)

    return state
end
```

## Testabilité

Correcte mais moins fine. On teste surtout `renderList(state)` avec un faux pool. C’est simple, mais vous retombez vite dans une fonction centrale qui connaît toutes les lignes.

---

# Comparaison synthétique

| Pattern                      | Recommandation | Pourquoi                                                                |
| ---------------------------- | -------------: | ----------------------------------------------------------------------- |
| Component + ItemResolver     |          ⭐⭐⭐⭐⭐ | Meilleur alignement avec votre besoin : lignes autonomes + async propre |
| Observer ciblé               |           ⭐⭐⭐⭐ | Indispensable en infrastructure, mais à encapsuler                      |
| MVU/MVP-lite                 |           ⭐⭐⭐⭐ | Excellent pour calculs et tests, moins “composant autonome”             |
| Signal-based                 |           ⭐⭐⭐⭐ | Élégant pour données partagées, mais mini-framework à maintenir         |
| Mixin WoW                    |           ⭐⭐⭐⭐ | Très idiomatique WoW, testabilité moyenne                               |
| Declarative/reconciler-lite  |            ⭐⭐⭐ | Puissant mais overkill au début                                         |
| ECS                          |             ⭐⭐ | Bon pattern Lua/game, mauvais rapport complexité/bénéfice ici           |
| Immediate-like retained pool |             ⭐⭐ | Simple pour debug, faible encapsulation                                 |

---

# Architecture finale recommandée pour CraftGold

Je recommande une architecture hybride :

```text
CraftGold/
├── Core.lua                  -- logique pure : tri, coût, recettes
├── ItemResolver.lua          -- GetItemInfo + GET_ITEM_INFO_RECEIVED + subscriptions
├── UI/
│   ├── RecipeList.lua        -- composant parent
│   ├── RecipeLine.lua        -- composant autonome
│   └── FrameFactory.lua      -- wrappers CreateFrame si besoin
└── CraftGold.lua             -- shell WoW : ADDON_LOADED, slash, fenêtre principale
```

Règle importante :

```text
RecipeLine connaît :
- sa recipe
- son FontString
- son Render()
- son callback OnItemReady()

ItemResolver connaît :
- GetItemInfo
- GET_ITEM_INFO_RECEIVED
- itemID -> callbacks

RecipeList connaît :
- la liste des recipes
- les lignes enfants

Personne hors RecipeLine ne touche RecipeLine.text.
```

Autrement dit : oui, il y a toujours un index `itemID -> abonnés`, mais il devient un détail d’implémentation du resolver. Ce n’est plus un pont sale entre création et update ; c’est un service de données asynchrones.

---

# Version courte de l’API interne idéale

```lua
local resolver = ItemResolver:New({
    CreateFrame = CreateFrame,
    GetItemInfo = GetItemInfo,
})

local line = RecipeLine:New(parent, {
    itemID = 4360,
    skill = 1,
}, resolver)

-- Dans RecipeLine:
function RecipeLine:Render()
    local item = self.resolver:Get(self.recipe.itemID)
    self.text:SetText(item.name or "chargement...")
end

function RecipeLine:OnItemReady(itemID)
    if itemID == self.recipe.itemID then
        self:Render()
    end
end
```

---

# Tests unitaires recommandés

Utilisez un seam `env` partout où du WoW API est nécessaire. `busted` supporte Lua >= 5.1, et LuaUnit est une alternative xUnit en un seul fichier sans dépendance externe ; les deux sont adaptés à vos tests hors WoW. ([Lunarmodules][15])

## Test 1 — placeholder si item absent

```lua
it("affiche un placeholder quand GetItemInfo retourne nil", function()
    local env = FakeWoW({
        itemNames = {}
    })

    local resolver = ItemResolver:New(env)
    local line = RecipeLine:New(env.parent, { itemID = 4360 }, -10, resolver, env)

    assert.matches("chargement", env.lastText)
end)
```

## Test 2 — update après événement async

```lua
it("met à jour la ligne quand GET_ITEM_INFO_RECEIVED arrive", function()
    local env = FakeWoW({
        itemNames = {}
    })

    local resolver = ItemResolver:New(env)
    local line = RecipeLine:New(env.parent, { itemID = 4360 }, -10, resolver, env)

    env.itemNames[4360] = "Rough Copper Bomb"
    resolver:OnItemInfoReceived(4360, true)

    assert.equals("Rough Copper Bomb", env.lastText)
end)
```

## Test 3 — pas d’update pour un autre item

```lua
it("ignore les événements d'autres itemIDs", function()
    local env = FakeWoW({
        itemNames = {}
    })

    local resolver = ItemResolver:New(env)
    local line = RecipeLine:New(env.parent, { itemID = 4360 }, -10, resolver, env)

    local before = env.lastText
    env.itemNames[4371] = "Bronze Tube"
    resolver:OnItemInfoReceived(4371, true)

    assert.equals(before, env.lastText)
end)
```

---

# Conclusion

Le pattern à adopter n’est pas “full React en Lua”. Le bon design est :

```text
Component-oriented retained UI
+ ItemResolver observer centralisé
+ injection env pour tests
+ Core pur séparé
```

C’est simple, idiomatique WoW, compatible Lua 5.1, testable hors client, et ça résout précisément le problème initial : **la ligne de recette redevient l’unité de comportement**, tandis que l’async `GetItemInfo` devient un service propre au lieu d’un index externe qui manipule directement des `FontString`.

```
```

[1]: https://www.wowace.com/projects/ace3/pages/api/ace-event-3-0?utm_source=chatgpt.com "api/AceEvent-3.0 - api - Pages - Ace3 - Addons - Projects"
[2]: https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/WeakAuras.lua "WeakAuras2/WeakAuras/WeakAuras.lua at main · WeakAuras/WeakAuras2 · GitHub"
[3]: https://www.curseforge.com/wow/addons/getiteminfoasync "GetItemInfoAsync - World of Warcraft Addons - CurseForge"
[4]: https://guide.elm-lang.org/architecture/?utm_source=chatgpt.com "The Elm Architecture · An Introduction to Elm"
[5]: https://www.curseforge.com/wow/addons/classic-loot-manager "Core Loot Manager DKP & EPGP & SK - World of Warcraft Addons - CurseForge"
[6]: https://vuejs.org/guide/essentials/reactivity-fundamentals.html?utm_source=chatgpt.com "Reactivity Fundamentals"
[7]: https://github.com/Roblox/signals?utm_source=chatgpt.com "Roblox/signals: A declarative state management library ..."
[8]: https://roblox.github.io/roact/?utm_source=chatgpt.com "Roact Documentation"
[9]: https://warcraft.wiki.gg/wiki/XML_user_interface?utm_source=chatgpt.com "XML user interface - Warcraft Wiki"
[10]: https://warcraft.wiki.gg/wiki/FrameXML_functions?utm_source=chatgpt.com "FrameXML functions - Warcraft Wiki"
[11]: https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/RegionTypes/RegionPrototype.lua "WeakAuras2/WeakAuras/RegionTypes/RegionPrototype.lua at main · WeakAuras/WeakAuras2 · GitHub"
[12]: https://github.com/bakpakin/tiny-ecs?utm_source=chatgpt.com "bakpakin/tiny-ecs: ECS for Lua"
[13]: https://github.com/ocornut/imgui?utm_source=chatgpt.com "Dear ImGui: Bloat-free Graphical User interface for C++ ..."
[14]: https://www.wowinterface.com/forums/showthread.php?t=49772&utm_source=chatgpt.com "LUA CreateFrame, then RemoveFrame??"
[15]: https://lunarmodules.github.io/busted/?utm_source=chatgpt.com "busted : Elegant Lua unit testing, by Olivine-Labs"
