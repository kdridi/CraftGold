# Recherche — Architecture testable pour add-ons WoW Classic Era en Lua

## Verdict court

Votre architecture est **saine, réaliste et plutôt meilleure que la moyenne des add-ons WoW** pour un projet pédagogique de taille moyenne. Le pattern **Functional Core / Imperative Shell** est exactement ce qu’il faut si l’objectif est de tester hors de WoW : garder `Core.lua` et `Style.lua` purs, concentrer les appels WoW dans une couche mince, puis tester avec `loadfile()` et un `ns` simulé.

Le point important : votre pattern `WoW.lua` comme **seam unique injectable** n’est pas forcément le pattern le plus courant dans les gros add-ons historiques ; beaucoup de projets préfèrent soit mocker `_G` dans les tests, soit utiliser Ace3/LibStub, soit accumuler des abstractions maison. Mais comme pattern pédagogique et testable, il est **plus propre** que la plupart des approches observées.

---

## 1. Frameworks et outils de test pour add-ons WoW

### Ce qui existe réellement

| Outil                   |                Type | Utilité                                                                                                                                                                                                                                     | Verdict                                                                                                            |
| ----------------------- | ------------------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **WoWUnit**             |       tests in-game | Framework dédié aux tests unitaires d’add-ons WoW, avec interface de suivi ; la page CurseForge indique qu’il peut lancer des tests “once” ou sur événements, et qu’il fournit des méthodes pour mocker temporairement variables/fonctions. | Intéressant historiquement, mais impose de lancer WoW. ([GitHub][1])                                               |
| **wowUnit**             |       tests in-game | Ancien add-on de tests unitaires exécutés via slash command, sans “intrusion” dans le code de l’add-on selon sa page WoWInterface.                                                                                                          | Utile comme référence, mais ancien. ([WoWInterface][2])                                                            |
| **QhunUnitTest**        |       tests in-game | Suite de test unitaire pour add-ons WoW listée sur WoWInterface.                                                                                                                                                                            | Même famille : tests dans le client. ([WoWInterface][3])                                                           |
| **busted**              |      tests hors-jeu | Framework Lua populaire, compatible Lua 5.1/LuaJIT, avec `describe`, `it`, assertions, spies.                                                                                                                                               | Le plus pertinent pour des tests hors WoW. ([GitHub][4])                                                           |
| **luaunit**             |      tests hors-jeu | Framework Lua minimaliste.                                                                                                                                                                                                                  | Possible si vous voulez éviter `busted`, mais moins “BDD”.                                                         |
| **wow-addon-container** |         CI / Docker | Image Docker pensée pour exécuter des tests Lua et outils de couverture pour add-ons WoW.                                                                                                                                                   | Bon pour CI/CD, mais plus lourd que votre besoin “Lua brut”. ([GitHub][5])                                         |
| **Mechanic**            |       sandbox/mocks | Sandbox offline qui génère beaucoup de stubs d’API Blizzard depuis APIDefs.                                                                                                                                                                 | Très intéressant pour tester du code proche de l’API WoW, probablement trop lourd pour vos capsules. ([GitHub][6]) |
| **DBM-Offline**         | simulation hors-jeu | Permet de charger des mods DBM et rejouer des logs de combat dans Lua 5.1 hors WoW.                                                                                                                                                         | Excellent exemple de tests offline spécialisés. ([GitHub][7])                                                      |

### Conclusion sur les tests

Il y a deux mondes :

1. **Tests in-game** : WoWUnit, wowUnit, DBM-Test. Plus fidèles, mais moins automatisables.
2. **Tests offline** : `busted`, `loadfile`, mocks `_G`, stubs WoW. Moins fidèles, mais excellents pour logique pure, parsing, formatting, slash commands, SavedVariables migrations.

Votre choix `loadfile()` + `ns` simulé est donc **aligné avec les vrais exemples modernes**, notamment DisenchantBuddy, qui charge un fichier avec `loadfile("SlashCommands.lua")("DisenchantBuddy", DisenchantBuddy)` dans un test `busted`. ([GitHub][8])

---

## 2. Architecture de gros add-ons WoW

## Questie

### Structure

Questie est un gros add-on WoW Classic en Lua 5.1 ; son guide développeur demande Lua 5.1, `busted`, `bit32`, `luacheck`, et exécute les tests via :

```bash
busted -p ".test.lua" .
```

Il précise aussi que les fichiers de test sont nommés `<module>.test.lua` à côté du module testé. ([GitHub][9])

Son `.toc` Classic Era cible `Interface: 11508`, déclare des dépendances optionnelles comme Ace3, LibStub, CallbackHandler, HereBeDragons, et des SavedVariables comme `QuestieConfig` et `QuestieConfigCharacter`. ([GitHub][10])

### Pattern d’initialisation

Questie ne se contente pas de `local _, ns = ...`. Il utilise un loader maison : `QuestieLoader:CreateModule(name)` et `QuestieLoader:ImportModule(name)`. Le fichier `QuestieLoader.lua` maintient une table interne `modules`, expose `QuestieLoader._modules`, et crée des modules sous forme de tables. ([GitHub][11])

Le fichier principal importe ensuite les modules avec `QuestieLoader:ImportModule(...)`. L’initialisation utilise AceDB via `LibStub("AceDB-3.0"):New("QuestieConfig", ...)`, enregistre des callbacks AceDB, puis appelle l’initialisation de Questie. ([GitHub][12])

### Tests

Questie a de vrais tests `busted`. Exemple : `Modules/QuestiePlayer.test.lua` fait `dofile("setupTests.lua")`, puis `require("Modules.QuestiePlayer")`, et mocke `_G.UnitInParty`, `_G.UnitInRaid`, `_G.UnitName`, `_G.UnitClass`, `_G.GetClassColor`. ([GitHub][13])

Le `setupTests.lua` est massif : il initialise `Questie`, charge plusieurs fichiers via `dofile`, définit `bit32`, mocke des fonctions globales (`tContains`, `strsplit`, `GetTime`, `GetRealmName`, `UnitName`, etc.), mocke `C_Item`, `CreateFrame`, `LibStub`, et fournit des helpers comme `TestUtils:triggerMockEvent`. ([GitHub][14])

### Leçon pour vous

Questie valide votre approche générale : **tests offline + mocks + Lua 5.1 + `busted`**. Mais Questie mocke `_G` massivement, alors que votre `WoW.lua` seam réduit le besoin de polluer `_G`. C’est une amélioration pédagogique nette.

---

## DBM — Deadly Boss Mods

### Structure

DBM est très modulaire : le dépôt contient `DBM-Core`, `DBM-GUI`, `DBM-Test`, plusieurs packs de raids/donjons, et des fichiers `.toc` par version. ([GitHub][15])

Le dossier `DBM-Core` contient des modules, sons, textures, `DBM-Core.lua`, et des `.toc` spécifiques comme `DBM-Core_Vanilla.toc`. ([GitHub][16])

Le `.toc` Vanilla déclare `Interface: 11508`, dépend de `DBM-StatusBarTimers`, liste plusieurs `OptionalDeps`, puis charge de nombreux modules internes comme `PrototypeRegistry.lua`, `Testing.lua`, `GameVersion.lua`, `StringUtils.lua`, `TableUtils.lua`, `Modules.lua`, avant `DBM-Core.lua`. ([GitHub][17])

### Pattern d’initialisation

DBM utilise un namespace privé via le second vararg : `local private = select(2, ...)`, puis récupère des prototypes via `private:GetPrototype("DBM")`. Il expose aussi `_G.DBM = DBM`. ([GitHub][18])

C’est donc un pattern plus sophistiqué que `ns.Core = {}` : un **registre de prototypes** et une architecture orientée modules.

### Tests

DBM a un add-on séparé `DBM-Test`, avec ses propres `.toc`, `Mocks.lua`, `Runner.lua`, `Registry.lua`, `Report.lua`, `TimeWarper.lua`, etc. ([GitHub][19])

Le README de DBM-Test précise que les tests sont des **characterization tests** : ils rejouent des logs Transcriptor, observent la réponse de DBM, puis comparent à un rapport “golden”. La commande in-game est du type `/dbm test <test name>`. ([GitHub][20])

DBM a aussi un dépôt/projet DBM-Offline capable de charger des mods DBM et rejouer des logs dans Lua 5.1 hors WoW, avec l’objectif explicite de réduire les tests manuels et de pouvoir les lancer automatiquement sur commit/PR. ([GitHub][7])

### Leçon pour vous

DBM montre que, pour un add-on très événementiel, les tests unitaires purs ne suffisent pas : il faut parfois des tests de scénario. Pour votre capsule pédagogique SavedVariables, slash commands et crafting costs, vous n’avez pas besoin d’aller aussi loin.

---

## WeakAuras

### Structure

WeakAuras est un framework très complexe. Le dépôt est séparé en plusieurs add-ons/packages : `WeakAuras`, `WeakAurasOptions`, `WeakAurasTemplates`, `WeakAurasModelPaths`, etc. ([GitHub][21])

Le `.toc` Vanilla cible `Interface: 11508`, déclare `SavedVariables: WeakAurasSaved`, liste beaucoup d’`OptionalDeps`, puis charge `embeds.xml`, `Init.lua`, `Compatibility.lua`, `DefaultOptions.lua`, `WeakAuras.lua`, les systèmes de triggers, helpers, types de régions et sous-régions. ([GitHub][22])

### Pattern d’initialisation

Dans `Init.lua`, WeakAuras utilise :

```lua
local AddonName = ...
local Private = select(2, ...)
WeakAuras = {}
```

Donc : namespace privé via `select(2, ...)`, mais aussi une globale publique `WeakAuras`. ([GitHub][23])

WeakAuras centralise ensuite beaucoup de fonctions dans `Private` et `WeakAuras`, vérifie les bibliothèques via `LibStub:GetLibrary(...)`, et expose des helpers comme `WeakAuras.IsClassicEra()`. ([GitHub][23])

### Tests

Je n’ai pas trouvé, dans la racine publique du dépôt, de répertoire `tests/` ou `spec/` comparable à Questie. La racine montre surtout les packages d’add-on, `.luacheckrc`, `.luarc.json`, `.pkgmeta`, etc. ([GitHub][21])

### Leçon pour vous

WeakAuras confirme que `local _, Private = ...` est idiomatique, mais son architecture est trop lourde pour votre besoin. Pour un add-on pédagogique de 500–2000 lignes, imiter WeakAuras serait over-engineered.

---

## Auctionator

### Structure

Auctionator est structuré par couches et par variantes client : `Source`, `Source_Classic`, `Source_Mainline`, `Source_ModernAH`, `Source_Vanilla`, `Source_LegacyAH`, `Data_Vanilla`, `Imports_*`, etc. ([GitHub][24])

Son `.toc` cible plusieurs clients dans une seule ligne `Interface: 120005, 50504, 38000, 20505, 11508`, déclare plusieurs SavedVariables, puis charge des manifests XML conditionnés par `AllowLoadGameType`, par exemple `Source_Classic\Manifest.xml [AllowLoadGameType classic]` et `Source_Vanilla\Manifest.xml [AllowLoadGameType vanilla, tbc, wrath]`. ([GitHub][25])

`Source/Manifest.xml` inclut ensuite des sous-systèmes : `Objects.lua`, `Locales`, `Constants`, `AH`, `Components`, `Search`, `Utilities`, `Tooltips`, `Variables`, `Database`, `SlashCmd`, `Shopping`, `Config`, `Selling`, `PostingHistory`, `Groups`, `Cancelling`, `CraftingInfo`, `Tabs`, `API`, `Initialize`. ([GitHub][26])

`Source_Classic/Manifest.xml` et `Source_Vanilla/Manifest.xml` ajoutent seulement les parties spécifiques à ces clients. ([GitHub][27])

### Tests

Je n’ai pas trouvé dans la page racine publique de procédure `busted` ni de répertoire `tests/spec` visible ; en revanche, le dépôt contient `test-data/shopping-lists`, ce qui suggère au moins des données de test ou de validation, mais pas forcément un runner de tests unitaires publié. Le README recommande surtout BugGrabber/BugSack pour les rapports de bugs. ([GitHub][24])

### Leçon pour vous

Auctionator est un bon exemple de **séparation par domaines** : `Search`, `Database`, `Shopping`, `Selling`, `Tooltips`, `Config`, etc. Votre futur `CraftGold` gagnerait à avoir ce type de découpage métier, mais sans l’infrastructure multi-client lourde.

---

## Leatrix Plus

### Structure

Leatrix Plus est présenté sur CurseForge comme un add-on modulaire de qualité de vie, avec “small resource footprint”, supportant plusieurs versions de WoW, et dont rien n’est activé par défaut. ([CurseForge][28])

Un miroir Classic montre une structure très compacte : `Leatrix_Plus_Library.lua`, `Leatrix_Plus_Locale.lua`, `Leatrix_Plus.lua`, avec `SavedVariables: LeaPlusDB`. ([GitHub][29])

### Pattern d’initialisation

Le code Classic crée une table globale SavedVariables `_G.LeaPlusDB = _G.LeaPlusDB or {}`, utilise des tables locales comme `LeaPlusLC`, `LeaPlusCB`, `LeaDropList`, récupère `local void, Leatrix_Plus = ...`, puis crée un frame d’événements qui enregistre `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`. ([GitHub][30])

### Tests

Je n’ai pas trouvé de tests publiés dans ce miroir Classic. Leatrix Plus semble plutôt suivre un style “add-on compact et pragmatique”, avec beaucoup de fonctionnalités dans un gros fichier, ce qui marche pour un auteur expert mais est moins pédagogique.

### Leçon pour vous

Leatrix montre le style historique : efficace, direct, très dépendant de l’environnement WoW. Pour apprendre une architecture testable, ce n’est pas le meilleur modèle.

---

## 3. Dependency injection en Lua WoW

Votre pattern :

```lua
local WoW = {}
ns.WoW = WoW

function WoW.wipe(t)
    for k in pairs(t) do t[k] = nil end
end

function WoW.init(env)
    WoW.print = env.print or WoW.print
    WoW.wipe = env.wipe or WoW.wipe
end
```

est une forme de **manual dependency injection** ou de **seam object**. Je n’ai pas trouvé ce pattern exact comme convention standard WoW, mais il est cohérent avec les pratiques Lua : on passe explicitement une table de capacités plutôt que d’accéder directement aux globals.

### Ce que font les add-ons réels

Questie mocke beaucoup `_G` dans `setupTests.lua` : `UnitName`, `UnitClass`, `CreateFrame`, `LibStub`, `C_Item`, etc. ([GitHub][14])

DisenchantBuddy fait un compromis très proche de votre approche : le test prépare `_G.SlashCmdList`, `_G.print`, `_G.IsShiftKeyDown`, crée une table `DisenchantBuddy`, puis charge le fichier testé avec `loadfile("SlashCommands.lua")("DisenchantBuddy", DisenchantBuddy)`. ([GitHub][8])

WeakAuras et DBM utilisent plutôt un namespace privé `select(2, ...)` et des registres internes, mais ne cherchent pas à rendre chaque module pur au sens “Functional Core”. ([GitHub][23])

### Ace3 et LibStub ne sont pas des containers DI

AceAddon-3.0 fournit un template d’objet add-on, des callbacks de lifecycle (`OnInitialize`, `OnEnable`, `OnDisable`) et un système de modules (`NewModule`, `GetModule`, `IterateModules`). Ce n’est pas un container d’injection de dépendances ; c’est plutôt un framework de lifecycle + modules + mixins. ([WowAce][31])

LibStub est une bibliothèque de versioning/registry pour bibliothèques partagées : `NewLibrary`, `GetLibrary`, `IterateLibraries`. Ce n’est pas non plus de la DI ; c’est plutôt un service locator minimaliste pour libs versionnées. ([WowAce][32])

### Pattern plus idiomatique conseillé

Je garderais votre `WoW.lua`, mais je le rendrais plus explicite :

```lua
-- src/WoW.lua
local _, ns = ...

local fallback = {}

function fallback.print(...)
    io.write(table.concat({...}, " "), "\n")
end

function fallback.wipe(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local WoW = ns.WoW or {}
ns.WoW = WoW

function WoW.init(env)
    env = env or _G or {}

    WoW.print = env.print or fallback.print
    WoW.wipe = env.wipe or fallback.wipe
    WoW.time = env.time or os.time
end
```

Puis, au lieu que `Logger.lua` lise directement `ns.WoW` partout, vous pouvez faire une petite injection au moment de construire le logger :

```lua
-- src/Logger.lua
local _, ns = ...

local Logger = {}
ns.Logger = Logger

function Logger.new(wow, prefix)
    return {
        info = function(_, msg)
            wow.print(prefix .. " " .. msg)
        end,
    }
end
```

Et dans le shell WoW :

```lua
-- SavedVarsDemo.lua
local addonName, ns = ...

ns.WoW.init(_G)

local logger = ns.Logger.new(ns.WoW, "|cff00ff00SavedVarsDemo:|r")
logger:info("loaded")
```

En test :

```lua
local ns = {}
local output = {}

local function load(path)
    assert(loadfile(path))("SavedVarsDemo", ns)
end

load("src/WoW.lua")
load("src/Logger.lua")

ns.WoW.init({
    print = function(...)
        table.insert(output, table.concat({...}, " "))
    end,
})

local logger = ns.Logger.new(ns.WoW, "[TEST]")
logger:info("hello")

assert(output[1] == "[TEST] hello")
```

---

## 4. Le namespace `ns` comme module system

Oui, `local addonName, ns = ...` est un pattern communautaire standard, pas une invention.

Warcraft fournit aux fichiers Lua d’un add-on deux valeurs dans `...` : le nom de l’add-on et une table namespace partagée entre les fichiers. Cette table permet de partager du code entre fichiers sans polluer l’environnement global. ([Warcraft Wiki][33])

Un article de design WoW/Lua recommande explicitement d’éviter trois problèmes classiques : pollution globale, tout mettre dans un seul fichier, absence de séparation des responsabilités. Il montre précisément `local addon, ns = ...`, puis l’usage de `ns.register(...)` pour partager un système d’événements entre fichiers sans globale. ([andydote.co.uk][34])

### Conventions de nommage

Il n’y a pas une convention unique. On trouve :

```lua
local addonName, ns = ...
local _, ns = ...
local _, Private = ...
local private = select(2, ...)
local _, addon = ...
```

WeakAuras utilise `local AddonName = ...` et `local Private = select(2, ...)`. DBM utilise `local private = select(2, ...)`. Questie utilise plutôt son loader global `QuestieLoader` et ses modules importés. ([GitHub][23])

### Avec Ace3

Avec Ace3, le pattern courant est plutôt :

```lua
local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon")
```

puis :

```lua
function MyAddon:OnInitialize()
end

function MyAddon:OnEnable()
end
```

AceAddon sait aussi créer des modules via `NewModule`. ([WowAce][31])

Mais Ace3 n’empêche pas d’utiliser `ns` en plus pour stocker du privé. Pour vos capsules pédagogiques, je recommande **pas Ace3 au début** : trop de magie, trop de dépendances, et moins bon pour apprendre les contraintes natives du chargement `.toc`.

---

## 5. Bonnes pratiques communauté

### Structurer un add-on moyen

Pour un add-on de 500–2000 lignes, je recommande :

```text
MyAddon/
├── MyAddon.toc
├── MyAddon.lua          -- shell : events, slash commands, SavedVariables
├── src/
│   ├── WoW.lua          -- seam API WoW
│   ├── Defaults.lua     -- defaults SavedVariables
│   ├── Store.lua        -- init/migration SavedVariables
│   ├── Core.lua         -- logique métier pure
│   ├── Format.lua       -- formatage pur
│   ├── UI.lua           -- frames/widgets WoW
│   └── Logger.lua
└── tests/
    ├── run.lua
    ├── helpers.lua
    ├── test_core.lua
    ├── test_store.lua
    └── test_logger.lua
```

Le `.toc` charge les fichiers dans l’ordre ; le format TOC est une suite de lignes, où les lignes `##` sont des tags metadata et les autres lignes sont les fichiers chargés par le client dans l’ordre. ([addonstudio.org][35])

### Séparer logique et UI

Le principe communautaire général est : éviter les globals, éviter les fichiers énormes, séparer les responsabilités. L’article “Good Design in Warcraft Addons/Lua” identifie précisément ces trois problèmes et montre un pattern où un système d’événements est séparé d’un module métier. ([andydote.co.uk][34])

Donc votre séparation :

```text
Core.lua   -- pur
Style.lua  -- pur
WoW.lua    -- seam
Shell.lua  -- events/slash/SavedVariables
```

est très bonne.

### SavedVariables

Les SavedVariables sont déclarées dans le `.toc`, chargées après l’exécution du code de l’add-on, puis `ADDON_LOADED` est fired pour cet add-on. Le client sauvegarde les variables automatiquement à la déconnexion, à la fermeture du jeu ou au `/reload`, et `PLAYER_LOGOUT` permet de faire des modifications de dernière minute avant sérialisation. ([WoWWiki Archive][36])

Une discussion WoWInterface recommande d’utiliser `ADDON_LOADED` pour savoir quand les fichiers et SavedVariables d’un add-on sont chargés, et `PLAYER_LOGIN` quand on veut attendre que tous les add-ons non-LoD et leurs SavedVariables soient chargés ; elle déconseille `VARIABLES_LOADED` pour les add-ons modernes. ([WoWInterface][37])

Donc, pour votre shell :

```lua
local addonName, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        ns.WoW.init(_G)
        ns.Store.init(_G.SavedVarsDemoDB)
    elseif event == "PLAYER_LOGOUT" then
        ns.Store.flush()
    end
end)
```

### Maintenabilité

La page AddOn Studio “UI best practices” rappelle que les variables Lua sont globales par défaut, que les globals ont un coût en performance et en conflits de noms, et recommande l’usage de variables locales. ([addonstudio.org][38])

Votre approche `ns` + modules purs + seam est donc alignée avec ces bonnes pratiques.

---

## 6. Exemples concrets de code testé

## Exemple 1 — Questie

Runner/commande :

```bash
busted -p ".test.lua" .
```

Questie documente cette commande dans son guide développeur, avec Lua 5.1, `busted`, `bit32`, `luacheck`, et des tests nommés `<module>.test.lua`. ([GitHub][9])

Extrait de pattern de test :

```lua
dofile("setupTests.lua")

describe("QuestiePlayer", function()
    before_each(function()
        QuestiePlayer = require("Modules.QuestiePlayer")

        _G.UnitInParty = function() return false end
        _G.UnitInRaid = function() return false end
        _G.UnitName = function() return "Player" end
    end)
end)
```

Le vrai fichier mocke beaucoup plus de fonctions WoW, mais l’idée est celle-ci : charger un environnement test, puis mocker `_G`. ([GitHub][13])

## Exemple 2 — DisenchantBuddy

DisenchantBuddy utilise `busted` et documente :

```bash
busted -p ".test.lua" .
```

dans son README. ([GitHub][39])

Son test `SlashCommands.test.lua` fait exactement ce que vous proposez : il prépare `_G`, crée une table add-on, puis charge le fichier avec un vararg simulé :

```lua
_G.SlashCmdList = {}
_G.SLASH_DisenchantBuddy1 = nil

describe("SlashCommands", function()
    local DisenchantBuddy

    before_each(function()
        _G.IsShiftKeyDown = spy.new(function() return false end)
        _G.IsAltKeyDown = spy.new(function() return false end)
        _G.IsControlKeyDown = spy.new(function() return false end)
        _G.print = spy.new(function() end)
        _G.DisenchantBuddy_Profile = {}

        DisenchantBuddy = {
            L = {
                ["Modifier is now: %s"] = "Modifier is now: %s",
                ["Syntax:"] = "Syntax:",
            }
        }

        loadfile("SlashCommands.lua")("DisenchantBuddy", DisenchantBuddy)
    end)
end)
```

C’est une validation directe de votre idée `loadfile()` + `ns` simulé. ([GitHub][8])

## Exemple 3 — ExtendedCharacterStats

ExtendedCharacterStats, un add-on WoW Classic, documente aussi Lua 5.1, `busted`, `luacheck`, puis :

```bash
busted -p ".test.lua" .
```

pour les tests unitaires. ([GitHub][40])

C’est moins riche comme exemple que Questie, mais ça montre que `busted` est une pratique réelle dans l’écosystème WoW Classic.

## Exemple 4 — DBM-Test / DBM-Offline

DBM-Test n’est pas du test unitaire pur : c’est du test de caractérisation à partir de logs Transcriptor, lancé via `/dbm test <test name>`, avec rapports “golden”. ([GitHub][20])

DBM-Offline va plus loin : charger DBM dans Lua 5.1 hors WoW et rejouer des logs, dans l’idée d’automatiser les tests sur commits/PRs. ([GitHub][7])

---

# Évaluation honnête de votre architecture

## Ce qui est très bien

Votre découpage :

```text
SavedVarsDemo.lua       -- shell WoW
src/WoW.lua             -- seam API WoW
src/Core.lua            -- logique pure
src/Style.lua           -- formatage pur
src/Logger.lua          -- logging via seam
tests/run.lua
tests/test_*.lua
```

est excellent pour un projet pédagogique.

Les points forts :

* **Un seul namespace `ns`** : standard WoW, évite la pollution globale.
* **Modules purs** : `Core` et `Style` testables sans WoW.
* **Seam `WoW.lua`** : évite de mocker `_G` partout comme Questie.
* **Tests `loadfile()` + vararg simulé** : validé par des projets réels comme DisenchantBuddy.
* **Pas d’Ace3 au départ** : bon choix pédagogique ; Ace3 est utile, mais masque le lifecycle natif.

## Ce qui pourrait être amélioré

### 1. Ne laissez pas `WoW.init()` devenir un service locator géant

Risque :

```lua
ns.WoW.CreateFrame
ns.WoW.RegisterEvent
ns.WoW.print
ns.WoW.UnitName
ns.WoW.GetItemInfo
ns.WoW.C_Timer
ns.WoW.C_AuctionHouse
...
```

À ce moment-là, vous recréez `_G` en moins bien.

Recommandation : exposez uniquement ce dont chaque capsule a besoin.

```lua
WoW.print
WoW.wipe
WoW.time
WoW.createFrame
```

Puis ajoutez progressivement.

### 2. Injecter les dépendances au bord des modules

Préférez :

```lua
local logger = ns.Logger.new(ns.WoW)
```

à :

```lua
function Logger.info(msg)
    ns.WoW.print(msg)
end
```

La première forme rend le module plus testable, car le test peut construire un logger avec un fake `wow`.

### 3. Ajouter un helper de chargement commun aux tests

```lua
-- tests/helpers.lua
local M = {}

function M.loadAddon(files)
    local ns = {}

    for _, file in ipairs(files) do
        assert(loadfile(file))("SavedVarsDemo", ns)
    end

    return ns
end

return M
```

Usage :

```lua
local helpers = dofile("tests/helpers.lua")

local ns = helpers.loadAddon({
    "src/WoW.lua",
    "src/Core.lua",
    "src/Style.lua",
    "src/Logger.lua",
})
```

Cela évite de dupliquer l’ordre de chargement dans chaque test.

### 4. Tester les migrations SavedVariables

Pour un add-on comme CraftGold, les bugs les plus pénibles viendront souvent des données persistées. Ajoutez un module pur :

```lua
-- src/Store.lua
local _, ns = ...

local Store = {}
ns.Store = Store

local DEFAULTS = {
    version = 1,
    crafts = {},
}

function Store.withDefaults(db)
    db = db or {}

    if db.version == nil then
        db.version = DEFAULTS.version
    end

    if db.crafts == nil then
        db.crafts = {}
    end

    return db
end
```

Test :

```lua
local db = ns.Store.withDefaults(nil)
assert(db.version == 1)
assert(type(db.crafts) == "table")
```

### 5. Ajouter `luacheck` plus tard

`luacheck` est utilisé par Questie, ExtendedCharacterStats et DisenchantBuddy. ([GitHub][9])

Pour une capsule débutant, ce n’est pas obligatoire dès le départ. Pour une capsule “qualité”, oui.

---

# Ce qui serait over-engineered

Pour un add-on de 500–2000 lignes, je déconseille :

* un container DI complet ;
* Ace3 dès la capsule 1 ;
* un clone de QuestieLoader ;
* une simulation complète de `CreateFrame`;
* un framework de build ;
* une architecture DBM-like avec replay de logs ;
* une arborescence trop profonde du type `Domain/Application/Infrastructure`.

Votre seam `WoW.lua` n’est **pas** over-engineered. Ce qui deviendrait over-engineered, ce serait de transformer `WoW.lua` en mock complet de l’API Blizzard.

---

# Recommandation finale

Je garderais votre architecture, avec ces 5 changements concrets :

1. **Renommer mentalement `WoW.lua` en “ports WoW”** : il doit rester petit, explicite, et limité aux fonctions réellement utilisées.
2. **Injecter `WoW` dans les modules impurs** (`Logger.new(WoW)`, `Shell.new(WoW, Store, Core)`) au lieu de lire `ns.WoW` partout.
3. **Créer `tests/helpers.lua`** pour charger les fichiers dans l’ordre `.toc` avec `loadfile(path)(addonName, ns)`.
4. **Ajouter un module `Store.lua` pur** pour defaults/migrations SavedVariables, testé hors WoW.
5. **Garder `busted` optionnel** : votre runner Lua brut est parfait pédagogiquement ; une capsule avancée pourra montrer `busted -p ".test.lua" .`.

Architecture recommandée :

```text
SavedVarsDemo/
├── SavedVarsDemo.toc
├── SavedVarsDemo.lua
├── src/
│   ├── WoW.lua          -- petite façade injectable
│   ├── Store.lua        -- SavedVariables defaults/migrations, pur
│   ├── Core.lua         -- métier pur
│   ├── Style.lua        -- formatage pur
│   └── Logger.lua       -- dépend de WoW.print injecté
└── tests/
    ├── run.lua
    ├── helpers.lua
    ├── test_core.lua
    ├── test_style.lua
    ├── test_store.lua
    ├── test_logger.lua
    └── test_wow.lua
```

Verdict final : **oui, votre pattern est une bonne idée**. Il est même plus propre que beaucoup d’add-ons réels, tout en restant compatible avec les contraintes Lua/WoW : pas de `require()` en jeu, chargement séquentiel `.toc`, namespace `ns`, globals minimisés, et tests offline simples.

[1]: https://github.com/Jaliborc/WoWUnit?utm_source=chatgpt.com "Jaliborc/WoWUnit: A unit testing framework ... - GitHub"
[2]: https://www.wowinterface.com/downloads/info19958-wowUnit.html?utm_source=chatgpt.com "wowUnit : Developer Utilities : World of Warcraft AddOns"
[3]: https://www.wowinterface.com/downloads/info24659-QhunUnitTest.html?utm_source=chatgpt.com "QhunUnitTest : Developer Utilities : World of Warcraft AddOns"
[4]: https://github.com/lunarmodules/busted?utm_source=chatgpt.com "lunarmodules/busted: Elegant Lua unit testing."
[5]: https://github.com/runeberry/wow-addon-container?utm_source=chatgpt.com "runeberry/wow-addon-container: Docker image ..."
[6]: https://github.com/Falkicon/mechanic?utm_source=chatgpt.com "Falkicon/Mechanic: In-game development hub ..."
[7]: https://raw.githubusercontent.com/DeadlyBossMods/DBM-Offline/main/README.md "raw.githubusercontent.com"
[8]: https://github.com/BreakBB/DisenchantBuddy/blob/main/SlashCommands.test.lua?utm_source=chatgpt.com "SlashCommands.test.lua - BreakBB/DisenchantBuddy"
[9]: https://github.com/Questie/Questie "GitHub - Questie/Questie: Questie: The WoW Classic quest helper · GitHub"
[10]: https://github.com/Questie/Questie/blob/master/Questie-Classic.toc "Questie/Questie-Classic.toc at master · Questie/Questie · GitHub"
[11]: https://raw.githubusercontent.com/Questie/Questie/master/Modules/Libs/QuestieLoader.lua "raw.githubusercontent.com"
[12]: https://raw.githubusercontent.com/Questie/Questie/master/Questie.lua "raw.githubusercontent.com"
[13]: https://raw.githubusercontent.com/Questie/Questie/master/Modules/QuestiePlayer.test.lua "raw.githubusercontent.com"
[14]: https://github.com/Questie/Questie/blob/master/setupTests.lua "Questie/setupTests.lua at master · Questie/Questie · GitHub"
[15]: https://github.com/DeadlyBossMods/DeadlyBossMods "GitHub - DeadlyBossMods/DeadlyBossMods: The ultimate encounter helper to give you fight info that's easy to process at a glance. DBM aims to focus on what's happening to you, and what YOU need to do about it. · GitHub"
[16]: https://github.com/DeadlyBossMods/DeadlyBossMods/tree/master/DBM-Core "DeadlyBossMods/DBM-Core at master · DeadlyBossMods/DeadlyBossMods · GitHub"
[17]: https://raw.githubusercontent.com/DeadlyBossMods/DeadlyBossMods/master/DBM-Core/DBM-Core_Vanilla.toc "raw.githubusercontent.com"
[18]: https://raw.githubusercontent.com/DeadlyBossMods/DeadlyBossMods/master/DBM-Core/DBM-Core.lua "raw.githubusercontent.com"
[19]: https://github.com/DeadlyBossMods/DeadlyBossMods/tree/master/DBM-Test "DeadlyBossMods/DBM-Test at master · DeadlyBossMods/DeadlyBossMods · GitHub"
[20]: https://github.com/DeadlyBossMods/DeadlyBossMods/blob/master/DBM-Test/README.md "DeadlyBossMods/DBM-Test/README.md at master · DeadlyBossMods/DeadlyBossMods · GitHub"
[21]: https://github.com/weakauras/weakauras2 "GitHub - WeakAuras/WeakAuras2: World of Warcraft addon that provides a powerful framework to display customizable graphics on your screen. · GitHub"
[22]: https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/WeakAuras_Vanilla.toc "WeakAuras2/WeakAuras/WeakAuras_Vanilla.toc at main · WeakAuras/WeakAuras2 · GitHub"
[23]: https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Init.lua "WeakAuras2/WeakAuras/Init.lua at main · WeakAuras/WeakAuras2 · GitHub"
[24]: https://github.com/TheMouseNest/Auctionator "GitHub - TheMouseNest/Auctionator: The Auctionator addon for World of Warcraft. · GitHub"
[25]: https://github.com/TheMouseNest/Auctionator/blob/master/Auctionator.toc "Auctionator/Auctionator.toc at master · TheMouseNest/Auctionator · GitHub"
[26]: https://github.com/TheMouseNest/Auctionator/blob/master/Source/Manifest.xml "Auctionator/Source/Manifest.xml at master · TheMouseNest/Auctionator · GitHub"
[27]: https://github.com/TheMouseNest/Auctionator/blob/master/Source_Classic/Manifest.xml "Auctionator/Source_Classic/Manifest.xml at master · TheMouseNest/Auctionator · GitHub"
[28]: https://www.curseforge.com/wow/addons/leatrix-plus "Leatrix Plus - World of Warcraft Addons - CurseForge"
[29]: https://github.com/jpaolin/leatrix-plus-classic "GitHub - jpaolin/leatrix-plus-classic: Leatrix Plus (World of Warcraft Classic) · GitHub"
[30]: https://raw.githubusercontent.com/jpaolin/leatrix-plus-classic/main/Leatrix_Plus.lua "raw.githubusercontent.com"
[31]: https://www.wowace.com/projects/ace3/pages/api/ace-addon-3-0 "api/AceAddon-3.0 - api - Pages - Ace3 - Addons - Projects - WowAce "
[32]: https://www.wowace.com/projects/libstub "Overview - LibStub - Addons - Projects - WowAce "
[33]: https://warcraft.wiki.gg/wiki/Using_the_AddOn_namespace?utm_source=chatgpt.com "Using the AddOn namespace - Warcraft Wiki"
[34]: https://andydote.co.uk/2014/11/23/good-design-in-warcraft-addons/ "Good Design in Warcraft Addons/Lua | Andy Dote"
[35]: https://addonstudio.org/wiki/WoW%3ATOC_format "WoW:TOC format - AddOn Studio"
[36]: https://wowwiki-archive.fandom.com/wiki/Saving_variables_between_game_sessions "Saving variables between game sessions | WoWWiki | Fandom"
[37]: https://www.wowinterface.com/forums/showthread.php?t=34497 "how can i get addon to save a variable? - WoWInterface"
[38]: https://addonstudio.org/wiki/WoW%3AUI_best_practices "WoW:UI best practices - AddOn Studio"
[39]: https://github.com/BreakBB/DisenchantBuddy/blob/main/README.md "DisenchantBuddy/README.md at main · BreakBB/DisenchantBuddy · GitHub"
[40]: https://github.com/BreakBB/ExtendedCharacterStats "GitHub - BreakBB/ExtendedCharacterStats: Extended Character Stats: A WoW Classic addon · GitHub"
