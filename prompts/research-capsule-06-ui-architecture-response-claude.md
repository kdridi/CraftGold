# Architecture UI orientée composants en Lua — Add-ons WoW Classic Era

Réponse à la recherche : patterns UI applicables en Lua 5.1 pur, sans build step, dans le contexte de l'API WoW (frames retenus, événements globaux, `GetItemInfo` asynchrone).

---

## 0. TL;DR — Classement recommandé

| Rang | Pattern | Verdict pour votre cas |
|---|---|---|
| **1** | **Composant Mixin auto-suffisant** + résolveur d'items centralisé | Idiomatique WoW, encapsulation réelle, ~40 lignes. C'est ce que fait Blizzard elle-même. |
| **2** | **Signal/Reactive** (mini-store réactif) | Meilleure séparation données/vue, excellent pour les tests, ~60 lignes de plomberie. |
| **3** | **Observer ciblé** (event-bus + `ItemResolver`) | Le plus petit refactor depuis votre code actuel ; supprime l'index externe sans tout réécrire. |
| **4** | **Data-driven / DataProvider** (déclaratif + frame pool) | Le bon choix si la liste devient grande/scrollable/filtrée. C'est le modèle du `ScrollBox` Blizzard moderne. |
| **5** | **MVVM** | Testabilité maximale, mais boilerplate disproportionné pour une liste de recettes. |
| ✗ | Immediate mode (ImGui-like) | Anti-pattern dans WoW : les frames sont des objets retenus, pas un canvas. |
| ✗ | ECS complet | Overkill : ECS résout des problèmes de composition combinatoire que vous n'avez pas. |
| ✗ | Virtual DOM (clone React complet) | Faisable (Roact le prouve en Lua), mais le diffing coûte plus qu'il ne rapporte sans JSX ni build step. |

**Recommandation concrète** : pattern 1 pour les lignes, avec en interne le mécanisme `Item:CreateFromItemID():ContinueOnItemLoad()` fourni par le client (disponible en Classic Era 1.14+), qui règle à lui seul 80 % de votre problème d'asynchronicité. Si vous voulez aller plus loin (filtres, tri dynamique, état partagé), ajoutez le pattern 2 par-dessus.

---

## 1. Préliminaire : trois contraintes WoW qui dictent tout

Avant les patterns, trois faits techniques qui invalident ou favorisent certaines approches :

**1.1 — Les frames sont des objets retenus et indestructibles.**
`CreateFrame()` alloue un objet C++ côté client qui ne sera **jamais** libéré (pas de `DeleteFrame`). On ne peut que `Hide()` et recycler. Conséquence : tout pattern qui recrée l'UI à chaque changement (immediate mode, virtual DOM naïf) doit obligatoirement passer par un **frame pool**. C'est la raison d'être de `CreateFramePool()` dans le code Blizzard.

**1.2 — Chaque frame est nativement un récepteur d'événements.**
N'importe quel frame peut faire `frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")` et recevoir l'événement dans son propre `OnEvent`. Le moteur dispatche l'événement à *tous* les frames enregistrés. C'est un support natif du pattern Observer au niveau de chaque composant — chose que React doit émuler. Trade-off : si 200 lignes s'enregistrent sur le même événement, chaque `GET_ITEM_INFO_RECEIVED` déclenche 200 handlers (dont 199 filtreront par `itemID` et ne feront rien). Acceptable jusqu'à quelques centaines de lignes ; au-delà, centralisez (voir pattern 3).

**1.3 — Le client fournit déjà une abstraction promise-like pour les items.**
Depuis le moteur moderne (que Classic Era 1.14+ utilise), `Item.lua` du FrameXML expose :

```lua
local item = Item:CreateFromItemID(itemID)
item:ContinueOnItemLoad(function()
    -- garanti : les données item sont en cache ici
    local name = item:GetItemName()
end)
```

En interne, ça fait exactement ce que votre Phase 2 fait à la main (registre `GET_ITEM_INFO_RECEIVED`, filtre par ID, callback, désenregistrement) — via `ItemEventListener`, déduplication incluse. **Vous pouvez supprimer `itemToTexts` aujourd'hui sans changer d'architecture.** Source : `wow-ui-source`, `Interface/SharedXML/ObjectAPI/Item.lua` (https://github.com/Gethe/wow-ui-source).

---

## 2. Pattern 1 — Composant Mixin auto-suffisant (recommandé)

### Description
Le mixin est *le* pattern objet idiomatique de WoW : une table de méthodes copiée dans un frame via `Mixin(frame, MyMixin)` (fonction globale fournie par le client). Chaque ligne de recette devient un composant qui possède son état (`self.recipe`), sait se rendre (`:Render()`), et gère lui-même son cycle asynchrone. Plus d'index externe, plus de Phase 2 détachée.

### Avantages (votre contexte)
- **Encapsulation réelle** : toute la logique d'une ligne vit dans un seul fichier/mixin. C'est exactement le « component-oriented » demandé.
- **Zéro dépendance** : `Mixin()` et `CreateFramePool()` sont fournis par le client. En Lua 5.1 pur, `Mixin` se réécrit en 4 lignes.
- **Idiomatique** : tout le FrameXML moderne de Blizzard est écrit comme ça (`*Mixin` partout). Un contributeur WoW comprendra immédiatement.
- **Réutilisable** : le même mixin sert pour une tooltip, une liste, un panneau de détail.

### Inconvénients
- Pas de réactivité automatique : si la recette change, il faut appeler `:SetRecipe()` à la main (pas de binding).
- L'état vit dans le frame → tester sans WoW demande d'extraire la logique pure (voir testabilité).
- Si N lignes s'enregistrent chacune sur `GET_ITEM_INFO_RECEIVED`, dispatch en O(N) par événement (voir §1.2). Mitigé ici en utilisant `ContinueOnItemLoad` qui centralise via `ItemEventListener`.

### Code complet — votre cas réel

```lua
-- =====================================================================
-- RecipeLine.lua — composant ligne de recette, auto-suffisant
-- =====================================================================

-- Fallback Lua 5.1 pur si on veut tester hors WoW (Mixin existe in-game)
local Mixin = Mixin or function(obj, ...)
    for i = 1, select("#", ...) do
        for k, v in pairs((select(i, ...))) do obj[k] = v end
    end
    return obj
end

RecipeLineMixin = {}

-- ---- logique pure (testable hors WoW, voir §Testabilité) ----
function RecipeLineMixin.FormatLine(itemName, recipe)
    if not itemName then
        return ("|cff808080Chargement... (item %d)|r"):format(recipe.itemID)
    end
    local color = recipe.known and "|cff00ff00" or "|cffff8000"
    return ("%s%s|r  —  skill %d"):format(color, itemName, recipe.skill)
end

-- ---- cycle de vie ----
function RecipeLineMixin:OnLoad()
    self.text = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.text:SetAllPoints(self)
    self.text:SetJustifyH("LEFT")
end

function RecipeLineMixin:SetRecipe(recipe)
    self.recipe = recipe
    self:Render()

    local name = GetItemInfo(recipe.itemID)
    if not name then
        -- L'abstraction promise-like du client : déduplication,
        -- filtrage par itemID et désabonnement sont gérés pour nous.
        local item = Item:CreateFromItemID(recipe.itemID)
        item:ContinueOnItemLoad(function()
            -- garde : la ligne a pu être recyclée pour une autre recette
            if self.recipe == recipe then
                self:Render()
            end
        end)
    end
end

function RecipeLineMixin:Render()
    local name = GetItemInfo(self.recipe.itemID)
    self.text:SetText(self.FormatLine(name, self.recipe))
end

-- =====================================================================
-- RecipeListFrame.lua — la liste, avec frame pool (recyclage)
-- =====================================================================
RecipeListMixin = {}

function RecipeListMixin:OnLoad()
    self.linePool = CreateFramePool("Frame", self, nil, nil, false,
        function(line)                     -- init une seule fois par frame
            Mixin(line, RecipeLineMixin)
            line:OnLoad()
        end)
end

function RecipeListMixin:SetRecipes(recipes)
    self.linePool:ReleaseAll()
    local prev
    for _, recipe in ipairs(recipes) do
        local line = self.linePool:Acquire()
        line:SetSize(320, 16)
        if prev then
            line:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
        else
            line:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -8)
        end
        line:SetRecipe(recipe)
        line:Show()
        prev = line
    end
end

-- =====================================================================
-- Usage
-- =====================================================================
local list = CreateFrame("Frame", "MyEngineeringList", UIParent)
Mixin(list, RecipeListMixin)
list:OnLoad()
list:SetSize(340, 400)
list:SetPoint("CENTER")

list:SetRecipes({
    { itemID = 10518, skill = 215, known = true  },  -- Parachute Cloak
    { itemID = 10720, skill = 230, known = false },  -- Gnomish Net-o-Matic
    { itemID = 16022, skill = 285, known = false },  -- Arcanite Dragonling
})
```

Variante sans `ContinueOnItemLoad` (si vous voulez voir la mécanique) : la ligne s'enregistre elle-même —

```lua
function RecipeLineMixin:SetRecipe(recipe)
    self.recipe = recipe
    self:Render()
    if not GetItemInfo(recipe.itemID) then
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        self:SetScript("OnEvent", self.OnEvent)
    end
end

function RecipeLineMixin:OnEvent(event, itemID, success)
    if itemID ~= self.recipe.itemID then return end
    self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    self:Render()
end
```

C'est l'expression la plus pure du « composant qui réagit aux événements qui le concernent » — au prix du dispatch O(N) décrit en §1.2.

### Testabilité
- `FormatLine` est une fonction pure : testable en busted sans aucun stub.
- `Render`/`SetRecipe` nécessitent des stubs (`GetItemInfo`, `CreateFontString`). Règle d'or : **pousser le maximum de logique dans des fonctions pures du mixin** (formatage, tri, décision d'état), garder les méthodes WoW comme de la « colle » triviale qu'on ne teste pas unitairement.
- Verdict : **bon**, à condition de discipliner la frontière pur/impur.

### Projets open source utilisant ce pattern
- **FrameXML Blizzard** lui-même — des centaines de `*Mixin` : https://github.com/Gethe/wow-ui-source (miroir non officiel du code UI extrait du client)
- **DetailsFramework** (la lib UI derrière Details! et Plater) : https://github.com/Tercioo/Details-Damage-Meter (dossier `Libs/DF`) — templates + injection de méthodes dans les frames
- **Plater Nameplates** : https://github.com/Tercioo/Plater-Nameplates — chaque nameplate est un frame enrichi de méthodes qui gère son propre cycle de vie

---

## 3. Pattern 2 — Signal-based / Reactive (mini-store réactif)

### Description
Une valeur réactive (« signal ») encapsule une donnée + une liste d'abonnés ; tout `set()` notifie automatiquement. La vue s'abonne et se redessine quand la donnée change. C'est le cœur de SolidJS, Vue (`ref`), Svelte 5 (runes), et de **Fusion** côté Lua/Roblox. En Lua 5.1, un signal s'écrit en 20 lignes.

### Avantages
- **L'asynchronicité disparaît de la vue** : la ligne s'abonne à `recipe.itemName` et ne sait même pas que `GetItemInfo` est async. Le résolveur pousse la valeur quand elle arrive — la propagation est automatique.
- Frontière données/affichage nette → la couche données se teste **sans aucun stub WoW**.
- Pas de diffing, pas de virtual DOM : mise à jour chirurgicale, O(1) par changement.
- Trivial en Lua 5.1 : closures + tables suffisent, aucune metatable requise.

### Inconvénients
- Plomberie maison (~60 lignes) à maintenir : signals, désabonnement, éviter les fuites (un frame recyclé doit se désabonner de son ancien signal — c'est *le* bug classique du pattern).
- Risque de sur-ingénierie : pour une liste statique, c'est plus de code que le pattern 1.
- Les chaînes de signaux dérivés (computed) peuvent devenir difficiles à suivre si on en abuse.

### Code complet

```lua
-- =====================================================================
-- signal.lua — valeur réactive minimale (Lua 5.1 pur, zéro dépendance)
-- =====================================================================
local function CreateSignal(initial)
    local value, listeners = initial, {}
    local signal = {}

    function signal:Get() return value end

    function signal:Set(v)
        if v == value then return end
        value = v
        for cb in pairs(listeners) do cb(v) end
    end

    -- Retourne une fonction de désabonnement (crucial pour le recyclage)
    function signal:Subscribe(cb)
        listeners[cb] = true
        cb(value)                          -- appel immédiat avec l'état courant
        return function() listeners[cb] = nil end
    end

    return signal
end

-- =====================================================================
-- RecipeStore.lua — couche données, 100 % testable hors WoW
-- (GetItemInfo et le listener d'événement sont INJECTÉS)
-- =====================================================================
local function CreateRecipeStore(getItemInfo, onItemInfoReceived)
    local store = { entries = {} }

    function store:Load(recipes)
        for _, recipe in ipairs(recipes) do
            local entry = {
                recipe   = recipe,
                itemName = CreateSignal(getItemInfo(recipe.itemID)), -- nil si pas en cache
            }
            self.entries[#self.entries + 1] = entry
        end
        -- L'événement alimente les signaux ; la vue n'en saura jamais rien.
        onItemInfoReceived(function(itemID)
            for _, entry in ipairs(self.entries) do
                if entry.recipe.itemID == itemID then
                    entry.itemName:Set(getItemInfo(itemID))
                end
            end
        end)
    end

    return store
end

-- =====================================================================
-- Côté WoW : on injecte les vraies dépendances
-- =====================================================================
local eventFrame = CreateFrame("Frame")
local function WowItemInfoListener(callback)
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    eventFrame:SetScript("OnEvent", function(_, _, itemID, success)
        if success then callback(itemID) end
    end)
end

local store = CreateRecipeStore(
    function(id) return (GetItemInfo(id)) end,  -- parenthèses : 1er retour seul
    WowItemInfoListener
)

-- =====================================================================
-- Vue : la ligne s'abonne, point final.
-- =====================================================================
local function CreateRecipeLine(parent, entry, index)
    local line = CreateFrame("Frame", nil, parent)
    line:SetSize(320, 16)
    line:SetPoint("TOPLEFT", 8, -8 - (index - 1) * 18)
    local text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetAllPoints()

    line.unsubscribe = entry.itemName:Subscribe(function(name)
        text:SetText(name
            and ("%s — skill %d"):format(name, entry.recipe.skill)
            or  ("|cff808080Chargement...|r (item %d)"):format(entry.recipe.itemID))
    end)
    -- Au recyclage de la ligne : line.unsubscribe() AVANT de réutiliser.
    return line
end

store:Load({
    { itemID = 10518, skill = 215 },
    { itemID = 10720, skill = 230 },
})
for i, entry in ipairs(store.entries) do
    CreateRecipeLine(MyListFrame, entry, i)
end
```

### Testabilité
La meilleure de tous les patterns. Le store ne touche aucune API WoW :

```lua
-- spec/store_spec.lua (busted : https://github.com/lunarmodules/busted)
describe("RecipeStore", function()
    it("résout un item async et notifie la vue", function()
        local cache, fireEvent = {}, nil
        local store = CreateRecipeStore(
            function(id) return cache[id] end,
            function(cb) fireEvent = cb end)

        store:Load({ { itemID = 10518, skill = 215 } })
        local seen
        store.entries[1].itemName:Subscribe(function(v) seen = v end)
        assert.is_nil(seen)                      -- placeholder

        cache[10518] = "Parachute Cloak"         -- la "réponse serveur" arrive
        fireEvent(10518)
        assert.equals("Parachute Cloak", seen)   -- propagation automatique
    end)
end)
```

### Projets open source
- **Fusion** (Roblox/Luau, mais le cœur — `Value`/`Computed`/`Observer` — est transposable en Lua 5.1) : https://github.com/dphfox/Fusion
- **Vide** (réactivité fine-grained en Luau, inspiré SolidJS) : https://github.com/centau/vide
- Dans WoW, **WeakAuras** utilise une forme de ce pattern : les « states » des triggers sont des données qui, en changeant, déclenchent la mise à jour des régions d'affichage : https://github.com/WeakAuras/WeakAuras2

---

## 4. Pattern 3 — Observer ciblé / Event-bus (`ItemResolver` central)

### Description
On garde votre structure actuelle mais on remplace l'index externe `itemToTexts` par un **résolveur centralisé** : un service qui prend `(itemID, callback)`, répond immédiatement si l'item est en cache, sinon mémorise le callback et le déclenche à la réception de l'événement. La « ligne » fournit son callback à la création : la logique de mise à jour revient *dans* le composant, seul le transport est centralisé.

### Avantages
- **Refactor minimal** depuis votre code : ~30 lignes, votre Phase 1 et Phase 2 fusionnent.
- Un seul frame enregistré sur `GET_ITEM_INFO_RECEIVED` (pas de dispatch O(N) du §1.2).
- Déduplication naturelle : 10 recettes du même itemID = 1 seule attente.
- C'est exactement ce que fait `ItemEventListener` de Blizzard — vous pouvez donc aussi *ne pas l'écrire* et utiliser `ContinueOnItemLoad` (§1.3).

### Inconvénients
- Moins « composant » que les patterns 1-2 : le composant délègue au lieu d'écouter lui-même.
- Les callbacks retiennent des références aux frames : au recyclage d'une ligne, un callback en attente peut écrire sur une ligne réaffectée → toujours garder une **garde de validité** (vérifier `line.recipe == recipe` dans le callback).
- Si les callbacks prolifèrent (items, sorts, guildes...), on glisse vers un event-bus global, avec son défaut connu : le flux de contrôle devient difficile à tracer.

### Code complet

```lua
-- =====================================================================
-- ItemResolver.lua — service central, écrit une fois, utilisé partout
-- =====================================================================
local ItemResolver = { pending = {} }   -- itemID -> { callback, ... }

local frame = CreateFrame("Frame")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function(_, _, itemID, success)
    local callbacks = ItemResolver.pending[itemID]
    if not callbacks then return end
    ItemResolver.pending[itemID] = nil
    local name = success and GetItemInfo(itemID) or nil
    for _, cb in ipairs(callbacks) do cb(name) end
end)

-- Appelle callback(name) immédiatement si possible, sinon plus tard.
function ItemResolver.Resolve(itemID, callback)
    local name = GetItemInfo(itemID)
    if name then return callback(name) end
    local list = ItemResolver.pending[itemID]
    if not list then
        list = {}
        ItemResolver.pending[itemID] = list
    end
    list[#list + 1] = callback
end

-- =====================================================================
-- La ligne : création ET mise à jour au même endroit. Plus d'index.
-- =====================================================================
local function CreateRecipeLine(parent, recipe, index)
    local line = CreateFrame("Frame", nil, parent)
    line:SetSize(320, 16)
    line:SetPoint("TOPLEFT", 8, -8 - (index - 1) * 18)
    local text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetAllPoints()
    line.recipe = recipe

    text:SetText(("|cff808080Chargement...|r (item %d)"):format(recipe.itemID))
    ItemResolver.Resolve(recipe.itemID, function(name)
        if line.recipe ~= recipe then return end   -- garde anti-recyclage
        text:SetText(name
            and ("%s — skill %d"):format(name, recipe.skill)
            or  "|cffff0000Item invalide|r")
    end)
    return line
end
```

### Testabilité
- `ItemResolver` se teste en stubant `GetItemInfo` + en appelant le handler manuellement (extraire le corps du `OnEvent` dans une fonction nommée `ItemResolver._OnItemReceived(itemID, success)` pour pouvoir l'invoquer en test).
- La ligne reste peu testable (mélange création de frame + logique) — c'est la limite du pattern : il résout le *transport*, pas la *structure*.

### Projets open source
- **CallbackHandler-1.0 / AceEvent-3.0** (Ace3) — l'event-bus standard de facto de l'écosystème, utilisé par des milliers d'add-ons : https://www.wowace.com/projects/ace3
- **LibItemCache / Bagnon** (Jaliborc) — résolution d'items en cache avec callbacks : https://github.com/Jaliborc/Bagnon
- **ItemEventListener** de Blizzard (la version officielle de ce résolveur) : `Interface/SharedXML/ObjectAPI/Item.lua` dans https://github.com/Gethe/wow-ui-source

---

## 5. Pattern 4 — Data-driven / Déclaratif (DataProvider + frame pool)

### Description
On décrit *ce que* la liste doit afficher (une table de données + une fonction d'initialisation d'élément), et un moteur générique s'occupe du *comment* (acquisition de frames dans un pool, positionnement, recyclage). C'est le modèle du `ScrollBox`/`DataProvider` du FrameXML moderne (présent dans les clients Classic Era récents, 1.15+) et, conceptuellement, celui des listes virtualisées React.

### Avantages
- **Sépare radicalement données et présentation** : changer la liste = remplacer la table et appeler `:Refresh()`. Tri, filtre, recherche deviennent de simples transformations de données.
- Recyclage systématique des frames (contrainte §1.1 respectée par construction).
- Évolue naturellement vers une liste scrollable virtualisée (n'instancier que les lignes visibles) — indispensable si vos recettes Engineering dépassent ~50 lignes dans un scroll frame.
- Le moteur s'écrit une fois et sert pour toutes les listes de l'add-on.

### Inconvénients
- Plus de code initial que les patterns 1-3 (le moteur).
- Le re-render est par *liste*, pas par *ligne* : sans précaution, un item résolu redessine tout. La solution propre : combiner avec le pattern 1 ou 3 au niveau de l'élément (le moteur place les lignes, chaque ligne gère son async). C'est exactement ce que fait Blizzard : `ScrollBox` + element initializer qui utilise `ContinueOnItemLoad`.
- « Déclaratif » en Lua sans build step = tables imbriquées ; lisible mais sans la vérification statique d'un JSX.

### Code complet

```lua
-- =====================================================================
-- ListView.lua — moteur générique data-driven avec pool de frames
-- =====================================================================
local function CreateListView(parent, config)
    -- config = { lineHeight, lineInit(line), lineUpdate(line, datum) }
    local view = { frames = {}, numActive = 0 }

    function view:SetData(data)
        self.data = data
        self:Refresh()
    end

    function view:Refresh()
        local n = #self.data
        for i = 1, n do
            local line = self.frames[i]
            if not line then                              -- pool : créer 1 fois
                line = CreateFrame("Frame", nil, parent)
                line:SetSize(320, config.lineHeight)
                line:SetPoint("TOPLEFT", 8, -8 - (i - 1) * (config.lineHeight + 2))
                config.lineInit(line)
                self.frames[i] = line
            end
            config.lineUpdate(line, self.data[i])         -- (re)binder la donnée
            line:Show()
        end
        for i = n + 1, self.numActive do                  -- recycler le surplus
            self.frames[i]:Hide()
        end
        self.numActive = n
    end

    return view
end

-- =====================================================================
-- Déclaration : on DÉCRIT une ligne de recette, le moteur fait le reste
-- =====================================================================
local recipeList = CreateListView(MyListFrame, {
    lineHeight = 16,

    lineInit = function(line)
        line.text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line.text:SetAllPoints()
    end,

    -- Appelé à chaque (re)bind ; gère l'async localement (pattern 1 imbriqué)
    lineUpdate = function(line, recipe)
        line.recipe = recipe
        local name = GetItemInfo(recipe.itemID)
        if name then
            line.text:SetText(("%s — skill %d"):format(name, recipe.skill))
        else
            line.text:SetText(("|cff808080Chargement...|r (%d)"):format(recipe.itemID))
            Item:CreateFromItemID(recipe.itemID):ContinueOnItemLoad(function()
                if line.recipe == recipe then             -- garde anti-recyclage
                    line.text:SetText(("%s — skill %d"):format(
                        GetItemInfo(recipe.itemID), recipe.skill))
                end
            end)
        end
    end,
})

-- L'UI devient une conséquence des données :
recipeList:SetData(SortRecipesBySkill(myRecipes))   -- tri = transformation pure
-- Filtre ? recipeList:SetData(Filter(myRecipes, predicate)) — rien d'autre.
```

### Testabilité
- Toutes les transformations de données (tri, filtre, groupage) sont des fonctions pures, testables directement.
- Le moteur `ListView` se teste avec un stub `CreateFrame` minimal (une table avec `SetSize`/`SetPoint`/`Show`/`Hide` no-op) — faisable car le moteur ne dépend que de 5 méthodes.
- Verdict : **très bon** pour la couche données, **moyen** pour le moteur.

### Projets open source
- **oUF** — *l'*exemple canonique de framework data-driven dans WoW : on déclare les éléments d'un unitframe, le moteur les construit et les met à jour sur événements : https://github.com/oUF-wow/oUF (utilisé par ElvUI et des dizaines de layouts)
- **WeakAuras** — des affichages entiers décrits comme tables de données sérialisables, rendues par des « regions » génériques : https://github.com/WeakAuras/WeakAuras2
- **ScrollBox/DataProvider Blizzard** : `Interface/SharedXML/Scroll/` dans https://github.com/Gethe/wow-ui-source

---

## 6. Pattern 5 — MVC / MVVM

### Description
Séparation en trois couches : le **Model** détient les recettes et l'état de résolution ; le **ViewModel** (MVVM) expose des propriétés observables prêtes à afficher (chaînes formatées, visibilité) ; la **View** ne fait que binder ces propriétés à des FontStrings. La direction Model→View passe par des notifications ; View→Model par des commandes.

### Avantages
- Testabilité maximale : le ViewModel contient *toute* la logique d'affichage (formatage, placeholder, couleurs) et se teste sans un seul frame.
- Échelle bien si la fenêtre grossit (onglets, filtres, détail de recette, état partagé entre panneaux).
- Frontières explicites = onboarding facile pour les contributeurs venant du monde .NET/mobile.

### Inconvénients
- **Boilerplate disproportionné** pour une liste : trois couches + un mécanisme d'observation maison là où le pattern 1 fait le travail en un mixin. En pratique, MVVM en Lua = pattern Signal (§3) + une couche de nommage par-dessus.
- Lua 5.1 n'a ni propriétés ni binding déclaratif : chaque binding s'écrit à la main (ou via metatables `__newindex`, au prix de la lisibilité).
- Peu idiomatique dans l'écosystème WoW : vous ne trouverez quasiment aucun add-on MVVM strict, donc pas de référence commune.

### Code (condensé — le binding réutilise `CreateSignal` du §3)

```lua
-- ViewModel : zéro API WoW, 100 % testable
local function CreateRecipeLineVM(recipe, resolveItem)
    local vm = {
        displayText = CreateSignal(("Chargement... (%d)"):format(recipe.itemID)),
        skillText   = CreateSignal(("skill %d"):format(recipe.skill)),
    }
    resolveItem(recipe.itemID, function(name)
        vm.displayText:Set(name or "Item invalide")
    end)
    return vm
end

-- View : du binding pur, aucune logique
local function BindRecipeLine(line, vm)
    line.unbinds = {
        vm.displayText:Subscribe(function(v) line.nameText:SetText(v) end),
        vm.skillText:Subscribe(function(v) line.skillText:SetText(v) end),
    }
end
```

`resolveItem` est injecté : en jeu c'est `ItemResolver.Resolve` (§4), en test c'est un fake. Le test du VM ressemble trait pour trait au test du store §3.

### Testabilité
**Excellente** (c'est sa raison d'être) — mais le pattern Signal seul atteint le même résultat avec moins de cérémonie.

### Projets open source
- MVVM strict est rare en Lua. Les approches proches : **Roact + Rodux** (Roblox ; Rodux est un portage de Redux en Lua — modèle + actions + vues abonnées) : https://github.com/Roblox/roact et https://github.com/Roblox/rodux
- Dans WoW, **AdiBags** sépare nettement modules de données et widgets d'affichage (architecture AceAddon modulaire, esprit MVC) : https://github.com/AdiAddons/AdiBags

---

## 7. Anti-patterns dans ce contexte (et pourquoi)

### 7.1 Immediate mode UI (Dear ImGui, SUIT)

**Idée** : pas d'état UI retenu — chaque frame de rendu, le code redéclare toute l'UI (`if Button("OK") then ... end`).

**Pourquoi ça ne marche pas dans WoW** : l'immediate mode suppose un canvas qu'on repeint. Or WoW n'expose **que** des objets retenus (§1.1) — frames indestructibles, FontStrings persistants. Émuler l'immediate mode signifie réconcilier un pool de frames retenus à chaque `OnUpdate` (~60+ fois/seconde), c'est-à-dire réimplémenter un retained mode déguisé, en payant le coût CPU à chaque frame *même quand rien ne change*. Dans un jeu où les add-ons partagent le budget CPU du client, c'est rédhibitoire. De plus, `SetText` sur un FontString n'est pas gratuit (layout de texte côté C).

**Où ce pattern brille, pour référence** : **SUIT** pour LÖVE2D (https://github.com/vrld/suit), où l'on possède réellement la boucle de rendu. C'est le contre-exemple instructif : même langage, modèle de rendu opposé.

### 7.2 ECS (Entity Component System)

**Idée** : entités = IDs, composants = données pures, systèmes = boucles de logique sur les composants.

**Pourquoi c'est overkill ici** : l'ECS résout l'explosion combinatoire de *types* d'entités (un jeu avec 50 mélanges de comportements) et la localité mémoire — deux problèmes inexistants pour une liste homogène de lignes de recettes. Vous paieriez l'indirection (registres de composants, scheduling de systèmes) sans en récolter les bénéfices. Par ailleurs, l'argument cache-friendly de l'ECS s'évapore en Lua : tout est table hachée, il n'y a pas de layout mémoire contigu à exploiter.

**Référence Lua propre si un jour le besoin émerge** (simulation, beaucoup d'objets dynamiques) : **tiny-ecs** : https://github.com/bakpakin/tiny-ecs

### 7.3 Virtual DOM complet (clone de React)

**Roact** (https://github.com/Roblox/roact) prouve qu'un React en Lua est faisable : composants, `setState`, reconciliation. Mais le bilan dans WoW est défavorable : (a) sans JSX ni build step, déclarer l'arbre = tables verbeuses (`createElement("Frame", {props}, {children})`) ; (b) le diffing alloue massivement des tables temporaires à chaque render — exactement ce que votre contrainte « éviter les créations massives par frame » interdit ; (c) la reconciliation doit de toute façon recycler des frames indestructibles. Le pattern 4 (data-driven + pool) capture 90 % du bénéfice (UI = f(data)) pour 10 % du coût.

---

## 8. Testabilité — synthèse transversale

Le facteur déterminant n'est pas le pattern, c'est **où passe la frontière entre logique pure et API WoW**. Trois techniques, cumulables :

**8.1 — Extraction de fonctions pures.** Formatage, tri, filtrage, décisions d'état : aucune raison qu'ils touchent un frame. Testables directement avec busted (https://github.com/lunarmodules/busted) + luassert, exécutés par LuaJIT ou Lua 5.1 en CI.

**8.2 — Injection de dépendances.** `GetItemInfo`, l'abonnement aux événements, voire `CreateFrame`, passés en paramètres de vos constructeurs (comme `CreateRecipeStore(getItemInfo, onItemInfoReceived)` au §3). En jeu : les vraies fonctions. En test : des fakes de 3 lignes. C'est ce qui rend les patterns Signal et MVVM si testables — la frontière est *forcée* par construction.

**8.3 — Stubs d'API WoW.** Pour tester la colle elle-même (le moteur de liste, un mixin), un stub minimal suffit :

```lua
-- spec/wow_stub.lua — le strict nécessaire, ~20 lignes
local function FakeRegion()
    local r = { shown = true, text = "" }
    function r:SetText(t) self.text = t end
    function r:SetAllPoints() end
    function r:SetJustifyH() end
    return r
end
function _G.CreateFrame()
    local f = FakeRegion()
    f.events = {}
    function f:CreateFontString() return FakeRegion() end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self[k] = fn end
    function f:SetSize() end
    function f:SetPoint() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    return f
end
function _G.GetItemInfo(id) return MockItemCache and MockItemCache[id] end
```

On simule alors l'asynchronicité en test : créer la ligne (cache vide → placeholder), remplir `MockItemCache`, appeler `line:OnEvent("GET_ITEM_INFO_RECEIVED", id, true)` à la main, vérifier `line.text.text`.

Pour des tests *in-game* (intégration), **WoWUnit** : https://github.com/Jaliborc/WoWUnit

**Classement testabilité** : Signal ≈ MVVM > Data-driven > Mixin > Observer central > code actuel (deux phases + index global, quasi intestable).

---

## 9. Recommandation finale

**Étape 1 (gain immédiat, aujourd'hui)** — Remplacez `itemToTexts` + le handler `GET_ITEM_INFO_RECEIVED` par `Item:CreateFromItemID(itemID):ContinueOnItemLoad(callback)`. Le client fait déjà la déduplication et le ciblage par itemID. Vos deux phases fusionnent en une, sans nouvelle architecture.

**Étape 2 (structure)** — Adoptez le **pattern Mixin** (§2) : `RecipeLineMixin` avec `SetRecipe`/`Render` + `RecipeListMixin` avec frame pool. C'est le « component-oriented » que vous cherchez, dans le dialecte natif de WoW, avec ~80 lignes au total.

**Étape 3 (si l'add-on grandit)** — Quand apparaîtront filtres, recherche, tri dynamique ou état partagé entre panneaux, introduisez un **store réactif à signaux** (§3) sous les mixins : les données deviennent la source de vérité, les composants des abonnés, et toute la logique se teste en CI sans client WoW. La paire mixin (vue) + signaux (données) est l'équivalent Lua honnête de ce que React/Vue vous offrent — sans virtual DOM, dont le coût n'est pas justifiable dans un client de jeu.

À éviter : immediate mode (incompatible avec le modèle retenu de WoW), ECS (résout un problème que vous n'avez pas), clone React complet (le diffing alloue trop pour le bénéfice apporté sans build step).

---

## 10. Récapitulatif des sources

| Référence | Pattern illustré | Lien |
|---|---|---|
| wow-ui-source (FrameXML Blizzard, miroir) | Mixin, ItemMixin/ContinueOnItemLoad, ScrollBox/DataProvider, FramePool | https://github.com/Gethe/wow-ui-source |
| oUF | Data-driven / déclaratif (unitframes) | https://github.com/oUF-wow/oUF |
| WeakAuras 2 | Data-driven + états réactifs | https://github.com/WeakAuras/WeakAuras2 |
| Details! / DetailsFramework | Mixin / injection de méthodes | https://github.com/Tercioo/Details-Damage-Meter |
| Plater | Composants frames autonomes | https://github.com/Tercioo/Plater-Nameplates |
| Ace3 (AceEvent, CallbackHandler, AceGUI) | Observer / event-bus, widgets pooled | https://www.wowace.com/projects/ace3 |
| AdiBags | Modularité esprit MVC | https://github.com/AdiAddons/AdiBags |
| Bagnon (Jaliborc) | Résolution d'items avec cache/callbacks | https://github.com/Jaliborc/Bagnon |
| Roact (Roblox) | Virtual DOM React en Lua | https://github.com/Roblox/roact |
| Rodux (Roblox) | Store Redux en Lua | https://github.com/Roblox/rodux |
| Fusion (Roblox) | Signals / réactivité fine | https://github.com/dphfox/Fusion |
| Vide (Roblox) | Réactivité type SolidJS | https://github.com/centau/vide |
| SUIT (LÖVE2D) | Immediate mode (contre-exemple instructif) | https://github.com/vrld/suit |
| tiny-ecs | ECS en Lua | https://github.com/bakpakin/tiny-ecs |
| middleclass | OOP classique en Lua (alternative aux mixins) | https://github.com/kikito/middleclass |
| busted | Tests unitaires Lua | https://github.com/lunarmodules/busted |
| WoWUnit | Tests in-game | https://github.com/Jaliborc/WoWUnit |

*Note d'honnêteté : les API du client évoluent (notamment `ScrollBox` côté Classic Era) — vérifiez la présence d'une API dans votre version via `/dump Item` ou le code de `wow-ui-source` correspondant à votre build avant de vous y appuyer. Les URLs de projets sont stables mais leur contenu bouge ; les patterns, eux, ne bougent pas.*