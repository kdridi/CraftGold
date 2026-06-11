# Le pattern Mixin dans WoW Classic Era

## Définition simple

Un **mixin** est une table Lua contenant des méthodes qu'on « copie » (à plat) dans un objet cible.
C'est le mécanisme principal utilisé par Blizzard pour organiser le code de l'interface : au lieu
d'un héritage classique, on compose des objets en leur injectant des méthodes depuis plusieurs tables.

**Analogie** : c'est exactement `Object.assign(target, ...sources)` en JavaScript — une copie plate
de propriétés, pas de chaîne de prototypes.

---

## Fonctions natives (implémentées en C)

`Mixin()` et `CreateFromMixins()` sont des fonctions **natives C** exposées au Lua par le client WoW.
On ne trouve pas leur code source Lua dans l'export FrameXML — leur implémentation est dans le moteur.

### Signatures (source : `Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua`)

```lua
-- Copie toutes les clés/valeurs de chaque mixin dans object, retourne object
Mixin(object, ...) --> outObject
-- object : table cible (modifiée en place)
-- ...    : une ou plusieurs tables mixin (variadique)

-- Crée une nouvelle table vide, y copie toutes les clés/valeurs de chaque mixin, la retourne
CreateFromMixins(...) --> object
-- ... : une ou plusieurs tables mixin (variadique)
```

### Comportement exact (inféré depuis `SecureMixin` dans `Blizzard_SharedXMLBase/Mixin.lua`)

```lua
-- SecureMixin est la version Lua de Mixin, avec un check issecure() en plus
function SecureMixin(object, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...);
        for k, v in pairs(mixin) do
            object[k] = v;  -- copie plate clé par clé
        end
    end
    return object;
end
```

**Donc `Mixin()` fait exactement la même chose, sans le `issecure()`.**

Règles :
- **Ordre matters** : les mixins sont appliqués de gauche à droite. Si deux mixins définissent la même clé, le dernier gagne.
- **Copie plate** : seules les clés directes sont copiées (`pairs`), pas de récursion dans les sous-tables.
- **Mutation en place** : `Mixin()` modifie `object` et le retourne.
- **Retourne toujours l'objet** : `Mixin({}, MyMixin)` et `CreateFromMixins(MyMixin)` font la même chose.

---

## Fonctions associées (source : `Blizzard_SharedXMLBase/Mixin.lua`)

### `CreateAndInitFromMixin(mixin, ...)`

Crée un objet depuis un mixin, puis appelle `object:Init(...)` dessus.

```lua
function CreateAndInitFromMixin(mixin, ...)
    local object = CreateFromMixins(mixin);
    object:Init(...);  -- appelle la méthode Init du mixin avec les args
    return object;
end
```

### `SecureMixin(object, ...)`

Version sécurisée de `Mixin()` — ne fonctionne que dans un contexte secure (pendant le load initial).
Utilisée pour les templates secure.

```lua
function SecureMixin(object, ...)
    if not issecure() then return; end
    for i = 1, select("#", ...) do
        local mixin = select(i, ...);
        for k, v in pairs(mixin) do
            object[k] = v;
        end
    end
    return object;
end
```

### `CreateFromSecureMixins(...)`

Version sécurisée de `CreateFromMixins()`.

```lua
function CreateFromSecureMixins(...)
    if not issecure() then return; end
    return SecureMixin({}, ...)
end
```

### `CreateSecureMixinCopy(mixin)`

Crée une copie indépendante d'un mixin (table vierge + copie + métatable marquée).
Usage interne pour la sécurité.

```lua
function CreateSecureMixinCopy(mixin)
    local mixinCopy = Mixin({}, mixin);
    setmetatable(mixinCopy, { __metatable = false });
    return mixinCopy;
end
```

### `FrameUtil.SpecializeFrameWithMixins(frame, ...)`

Injecte des mixins dans une frame existante, puis connecte les scripts handlers standards
et appelle `OnLoad` si présent.

```lua
function FrameUtil.SpecializeFrameWithMixins(frame, ...)
    Mixin(frame, ...);
    FrameUtil.ReflectStandardScriptHandlers(frame);
    -- Appelle frame:OnLoad() si défini
    -- Appelle frame:OnShow() si défini et frame visible
end
```

### `MixinUtil` (source : `Blizzard_SharedXML/MixinUtil.lua`)

Utilitaires pour appeler des méthodes sur des instances de mixins :

```lua
-- Appelle methodName sur chaque instance qui la définit
MixinUtil.CallMethodOnAllSafe(instances, methodName, ...)

-- Appelle element[methodName](element, ...) si element existe
MixinUtil.CallMethodSafe(element, methodName, ...)
```

---

## Comparaison avec JavaScript

| Concept | WoW Lua | JavaScript | Mécanisme |
|---------|---------|------------|-----------|
| **Copie plate** | `Mixin(obj, src)` | `Object.assign(obj, src)` | Copie chaque propriété directement sur l'objet |
| **Mixin + création** | `CreateFromMixins(src)` | `Object.assign({}, src)` | Nouvel objet + copie plate |
| **Délégation prototype** | `setmetatable(obj, {__index = proto})` | `Object.create(proto)` | Lookup chain, pas de copie |

### `Mixin()` ≈ `Object.assign()` — subtilités

**Oui, `Mixin()` est strictement équivalent à `Object.assign()`** pour la copie de propriétés :

```javascript
// JavaScript
Object.assign(target, source1, source2);
```

```lua
-- WoW Lua
Mixin(target, source1, source2);
```

Les deux :
- Copient les propriétés énumérables propres (JS) / clés accessibles via `pairs` (Lua)
- Écrasent les clés existantes (dernier source gagne)
- Modifient et retournent `target`
- Font une copie **plate** (shallow) — les sous-tables sont partagées par référence

**Différences mineures :**
- En Lua, `pairs()` itère sur les clés numériques et string (toutes les clés de la table)
- En JS, `Object.assign()` ne copie que les propriétés énumérables propres (pas celles héritées via prototype)
- En Lua WoW, il n'y a pas de prototype chain au sens JS — la distinction n'existe pas

### `Mixin()` ≠ délégation (`__index` / `Object.create`)

```lua
-- DÉLÉGATION : obj n'a PAS les méthodes, elles sont trouvées via __index
setmetatable(obj, { __index = MyMixin })
-- Si on modifie MyMixin après, obj "voit" le changement
-- obj n'a pas de copie des méthodes
```

```lua
-- MIXIN : obj A les méthodes, copiées directement
Mixin(obj, MyMixin)
-- Si on modifie MyMixin après, obj ne change PAS
-- obj possède ses propres copies des méthodes
```

```javascript
// JS — délégation prototype
const obj = Object.create(proto);
// obj.n'a PAS les propriétés, elles sont trouvées via la chaîne de prototypes
```

**En résumé** : Mixin = copie physique des méthodes. `__index` = lookup dynamique.

---

## Réimplémentation Lua 5.1 pur (sans client WoW)

```lua
--- Copie plate de toutes les clés de chaque mixin dans object.
--- @param object table La table cible (modifiée en place)
--- @param ... table Un ou plusieurs mixins à copier
--- @return table L'objet modifié
function Mixin(object, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...);
        if mixin then
            for k, v in pairs(mixin) do
                object[k] = v;
            end
        end
    end
    return object;
end

--- Crée un nouvel objet en copiant tous les mixins dedans.
--- @param ... table Un ou plusieurs mixins
--- @return table Le nouvel objet
function CreateFromMixins(...)
    return Mixin({}, ...);
end

--- Crée un objet depuis un mixin et appelle Init().
--- @param mixin table Le mixin source
--- @param ... any Arguments passés à Init
--- @return table Le nouvel objet initialisé
function CreateAndInitFromMixin(mixin, ...)
    local object = CreateFromMixins(mixin);
    object:Init(...);
    return object;
end
```

---

## Exemples concrets

### Exemple 1 : Mixin basique (injecter dans un objet existant)

```lua
-- Définition du mixin (table de méthodes)
local GreetMixin = {
    name = "Unknown",

    Greet = function(self)
        print("Hello, I'm " .. self.name)
    end,

    SetName = function(self, name)
        self.name = name
    end,
}

-- Utilisation avec Mixin (copie dans un objet existant)
local player = { level = 42 }
Mixin(player, GreetMixin)

player:SetName("Thrall")
player:Greet()  -- "Hello, I'm Thrall"
print(player.level)  -- 42 (propriété originale conservée)
```

### Exemple 2 : CreateFromMixins (créer un nouvel objet)

```lua
local CounterMixin = {
    count = 0,

    Increment = function(self)
        self.count = self.count + 1
    end,

    GetCount = function(self)
        return self.count
    end,
}

-- Crée un nouvel objet avec les méthodes du mixin
local myCounter = CreateFromMixins(CounterMixin)
myCounter:Increment()
myCounter:Increment()
print(myCounter:GetCount())  -- 2
```

### Exemple 3 : Composition de plusieurs mixins

```lua
local SerializableMixin = {
    Serialize = function(self)
        local parts = {}
        for k, v in pairs(self) do
            if type(k) == "string" and type(v) ~= "function" then
                parts[#parts + 1] = k .. "=" .. tostring(v)
            end
        end
        return table.concat(parts, ", ")
    end,
}

local PrintableMixin = {
    Print = function(self)
        print(self:Serialize())
    end,
}

-- Compose les deux mixins — le dernier peut écraser le premier en cas de conflit
local ConfigMixin = {
    setting = "default",

    Init = function(self, setting)
        self.setting = setting
    end,
}

-- Usage avec CreateAndInitFromMixin
local config = CreateAndInitFromMixin(
    Mixin({}, ConfigMixin, SerializableMixin, PrintableMixin),
    "debug"
)
-- ou plus lisible avec CreateFromMixins sur plusieurs mixins :
-- local config = CreateAndInitFromMixin(
--     CreateFromMixins(ConfigMixin, SerializableMixin, PrintableMixin),
--     "debug"
-- )

config:Print()  -- "setting=debug"
```

### Exemple 4 : Pattern Blizzard — Mixin sur une Frame

C'est le pattern le plus courant dans le code Blizzard :

```lua
-- Définir un mixin pour des frames
local MyPanelMixin = {
    OnLoad = function(self)
        self.title = self:GetName() .. " Panel"
        print(self.title .. " loaded!")
    end,

    OnShow = function(self)
        print(self.title .. " shown!")
    end,

    SetTitle = function(self, title)
        self.title = title
    end,
}

-- XML : <Frame name="MyPanel" mixin="MyPanelMixin">
-- Ou en Lua :
local frame = CreateFrame("Frame", "MyPanel", UIParent)
Mixin(frame, MyPanelMixin)
frame:OnLoad()  -- "MyPanel Panel loaded!"
```

### Exemple 5 : Usage réel Blizzard (source code)

```lua
-- Depuis Blizzard_MapCanvas/MapCanvas.lua
MapCanvasMixin = CreateFromMixins(CallbackRegistryMixin);
-- MapCanvasMixin est une NOUVELLE table qui contient toutes les méthodes de CallbackRegistryMixin

-- Depuis Blizzard_MapCanvas/MapCanvas_DataProviderBase.lua
CVarMapCanvasDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin);
-- Héritage de mixin : le provider spécialisé "hérite" du provider de base

-- Depuis Blizzard_CustomizationUI/Blizzard_CustomizationOptionTemplates.lua
CustomizationOptionSliderMixin = CreateFromMixins(
    CustomizationOptionFrameBaseMixin,
    SliderWithButtonsAndLabelMixin,
    CustomizationFrameWithTooltipMixin
);
-- Composition multiple : 3 mixins fusionnés, le dernier gagne en cas de conflit
```

---

## Quand utiliser Mixin vs `__index` ?

| Situation | Choix | Pourquoi |
|-----------|-------|----------|
| Ajouter des méthodes à une frame | **Mixin** | Pattern standard Blizzard, les frames sont des userdata |
| Partager du code entre plusieurs objets | **Mixin** | Chaque objet a sa propre copie, pas d'interférence |
| Héritage simple, un seul parent | `__index` OK | Plus léger, lookup dynamique |
| Runtime memory concern | `__index` | Pas de copie des méthodes dans chaque instance |
| Compatibilité code Blizzard | **Mixin** | Convention universelle dans le FrameXML |

**Règle pratique** : dans un add-on WoW, suivre la convention Blizzard → utiliser `Mixin`/`CreateFromMixins`.

---

## Références dans le code source Blizzard exporté

| Fichier | Contenu |
|---------|---------|
| `Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua` | Signatures officielles de `Mixin()` et `CreateFromMixins()` |
| `Blizzard_SharedXMLBase/Mixin.lua` | `SecureMixin`, `CreateAndInitFromMixin`, `CreateFromSecureMixins` |
| `Blizzard_SharedXML/MixinUtil.lua` | `MixinUtil.CallMethodOnAllSafe`, `MixinUtil.CallMethodSafe` |
| `Blizzard_SharedXMLBase/FrameUtil.lua` | `FrameUtil.SpecializeFrameWithMixins` |
| `Blizzard_SharedXMLBase/SecureTypes.lua` | Usage de `local Mixin = Mixin;` (localisation pour perf) |
