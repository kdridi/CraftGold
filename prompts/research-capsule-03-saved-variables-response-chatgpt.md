# Recherche — Capsule 03 : Saved Variables — WoW Classic Era 1.15.x / Interface 11508

## Synthèse fiable

Pour un add-on WoW Classic Era, les `SavedVariables` sont des **variables globales déclarées dans le `.toc`**, sauvegardées automatiquement par le client **à la déconnexion, au `/reload`, au quit ou au disconnect**, puis rechargées au prochain chargement de l’add-on. Le bon événement pour les initialiser est **`ADDON_LOADED` filtré sur le nom de ton add-on**, car à ce moment-là les fichiers `.lua` de l’add-on ont déjà été exécutés **et ses SavedVariables ont déjà été chargées**. ([Warcraft Wiki][1])

---

## 1. Cycle de vie des SavedVariables

### Ordre de chargement

Le cycle pertinent est :

1. WoW charge/exécute le code FrameXML.
2. WoW charge/exécute les fichiers `.lua` listés dans le `.toc` de l’add-on.
3. WoW charge les SavedVariables de cet add-on.
4. WoW déclenche `ADDON_LOADED` pour cet add-on.
5. Une fois les add-ons non-load-on-demand chargés et le personnage connecté, WoW déclenche `PLAYER_LOGIN`. ([Warcraft Wiki][1])

### `ADDON_LOADED`

`ADDON_LOADED` est déclenché **pour chaque add-on chargé**. Il faut donc tester l’argument `addonName`/`arg1` et ne lancer l’initialisation que si c’est ton add-on. À ce moment-là, les SavedVariables de cet add-on sont déjà chargées ; c’est le premier moment fiable où ton add-on peut les lire. ([Warcraft Wiki][2])

Pattern attendu :

```lua
local ADDON_NAME = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    -- Ici, MyAddonDB est déjà chargée si elle existe.
    MyAddonDB = MyAddonDB or {}

    self:UnregisterEvent("ADDON_LOADED")
end)
```

Le filtrage est important parce que `ADDON_LOADED` peut aussi être déclenché pour d’autres add-ons, notamment lors de chargements dynamiques avec `LoadAddOn()`. ([WoWInterface][3])

### `VARIABLES_LOADED`

`VARIABLES_LOADED` est **à éviter pour initialiser les SavedVariables de ton add-on**. Les docs communautaires modernes indiquent explicitement que les add-ons ne devraient pas utiliser cet événement pour vérifier que leurs propres SavedVariables sont chargées ; il faut utiliser `ADDON_LOADED` et tester le nom de l’add-on. ([Warcraft Wiki][4])

Historiquement, `VARIABLES_LOADED` a été décrit comme un événement global lié au chargement des variables, mais depuis les changements introduits autour de WoW 3.0.2 il n’est plus un point fiable du cycle de chargement des add-ons : il est plutôt lié à des choses comme les CVars et keybindings, et peut même arriver après `PLAYER_ENTERING_WORLD`. ([Wowpedia][5])

### `PLAYER_LOGIN`

`PLAYER_LOGIN` se déclenche une fois que les add-ons non-load-on-demand sont chargés et que le joueur est réellement connecté au monde. Il est pertinent si ton initialisation dépend de l’état joueur, de l’UI plus complète, ou d’autres add-ons déjà chargés. Pour les SavedVariables de **ton propre add-on**, `ADDON_LOADED` reste le point le plus précoce et le plus précis. ([Warcraft Wiki][1])

### `PLAYER_LOGOUT`

`PLAYER_LOGOUT` est déclenché quand le joueur se déconnecte ou fait un `/reload`, juste avant la sauvegarde des SavedVariables. C’est le bon endroit pour écrire des valeurs finales simples : date de dernière session, état courant, statistiques accumulées, nettoyage de cache, etc. ([Warcraft Wiki][6])

Exemple :

```lua
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        MyAddonDB = MyAddonDB or {}
    elseif event == "PLAYER_LOGOUT" then
        MyAddonDB.lastLogout = time()
    end
end)
```

### `/reload` : sauvegarde avant ou après ?

Au `/reload`, le client déclenche le chemin de sortie UI : `PLAYER_LOGOUT` est déclenché, puis les SavedVariables sont sauvegardées automatiquement, puis la nouvelle instance de l’UI recharge les fichiers. Donc, fonctionnellement, les SavedVariables sont écrites **avant que la nouvelle UI issue du reload ne les relise**, pas après le chargement suivant. Les sources communautaires listent explicitement `/reload` / `ReloadUI()` parmi les moments où le client sauvegarde automatiquement les variables. ([WoWWiki Archive][7])

### Premier chargement : la globale est-elle `nil` ?

Oui. Au premier chargement après installation, si aucun fichier SavedVariables n’existe encore ou si la variable n’a jamais été sauvegardée, la globale déclarée dans le `.toc` vaut `nil` jusqu’à ce que ton code l’initialise. Les guides communautaires montrent explicitement ce cas : au premier run, les variables sauvegardées absentes sont `nil`, d’où le pattern `MyAddonDB = MyAddonDB or {}`. ([WoWWiki Archive][7])

---

## 2. Déclaration dans le `.toc`

### Syntaxe exacte

Oui, la syntaxe correcte est :

```toc
## SavedVariables: MyVarName
## SavedVariablesPerCharacter: MyPerCharVar
```

Les directives acceptent une liste de noms globaux séparés par des virgules :

```toc
## SavedVariables: Var1, Var2, Var3
## SavedVariablesPerCharacter: CharVar1, CharVar2
```

Les docs du format `.toc` décrivent `SavedVariables` et `SavedVariablesPerCharacter` comme des listes séparées par des virgules de **noms de variables globales** à sauvegarder et recharger. ([AddOn Studio][8])

### Différence entre `SavedVariables` et `SavedVariablesPerCharacter`

`SavedVariables` est sauvegardé au niveau du compte : la même base est partagée entre les personnages du même compte WoW, dans le dossier SavedVariables du compte. `SavedVariablesPerCharacter` est sauvegardé au niveau personnage : chaque personnage a son propre fichier SavedVariables dans son dossier realm/personnage. ([AddOn Studio][8])

### Les deux existent-ils en Classic Era ?

Oui. Des add-ons Classic Era actuels avec `## Interface: 11508` utilisent les deux. Par exemple, Questie déclare `## Interface: 11508`, puis `## SavedVariables: QuestieConfig` et `## SavedVariablesPerCharacter: QuestieConfigCharacter`. ([GitHub][9])

Deathlog déclare aussi `## Interface: 20505, 11508`, puis plusieurs `SavedVariables` et une `SavedVariablesPerCharacter: deathlog_char_data`. ([GitHub][10])

RaidLogAuto déclare une interface Vanilla/Classic Era incluant `11508` et utilise `## SavedVariables: RaidLogAutoDB`. ([GitHub][11])

### Peut-on déclarer plusieurs variables ?

Oui :

```toc
## SavedVariables: Var1, Var2
```

C’est explicitement supporté par la syntaxe `.toc`, et Deathlog montre un exemple réel avec plusieurs variables globales déclarées sur la ligne `## SavedVariables`. ([AddOn Studio][8])

### La variable doit-elle être globale ?

Oui. Le `.toc` ne connaît que des noms dans l’environnement global. Une variable `local` n’est pas sauvegardée directement. Si tu veux travailler avec un `local db`, il doit référencer la table globale après chargement :

```lua
MyAddonDB = MyAddonDB or {}
local db = MyAddonDB
```

Les guides SavedVariables indiquent que les variables sauvegardées sont chargées dans l’environnement global, et que si tu utilises une variable locale, tu dois la lire depuis la globale au chargement puis la remettre dans la globale avant la sauvegarde si tu l’as remplacée. ([WoWWiki Archive][7])

À éviter :

```toc
## SavedVariables: MyAddon.DB
```

Le `.toc` attend des noms de variables globales, pas des chemins de sous-table. Des discussions Blizzard anciennes signalent que déclarer une sous-table de ce type peut provoquer des problèmes parce que la table racine n’est pas automatiquement créée. ([bluetracker.gg][12])

---

## 3. Sérialisation — limitations

WoW sauvegarde les SavedVariables sous forme de fichier Lua lisible, typiquement avec des affectations globales comme :

```lua
MyAddonDB = {
    counter = 12,
    name = "Karim",
}
```

Les sources communautaires décrivent les fichiers SavedVariables comme des fichiers Lua réexécutés au chargement pour restaurer les valeurs. ([WoWInterface][13])

### Types supportés

Les types supportés de manière fiable sont :

```lua
number
string
boolean
table
```

Les guides SavedVariables listent explicitement les chaînes, booléens, nombres et tables comme types sauvegardables. ([WoWWiki Archive][7])

Exemple valide :

```lua
MyAddonDB = {
    counter = 42,
    enabled = true,
    name = "unknown",
    options = {
        scale = 1.0,
        locked = false,
    },
}
```

### Tables imbriquées

Oui, les tables imbriquées sont supportées, puisque les tables sont le format normal pour organiser des SavedVariables. C’est d’ailleurs le pattern recommandé pour éviter de polluer l’espace global avec beaucoup de variables. ([WoWWiki Archive][7])

Je n’ai pas trouvé de limite publique fiable du type “profondeur maximale = N”. En pratique, il faut éviter les structures extrêmement profondes ou énormes : les SavedVariables restent des fichiers Lua à écrire, lire et compiler, et des limites pratiques existent sur les très gros fichiers. Un bug WoWUIBugs documente par exemple un échec `constant table overflow` au-delà de 262 144 valeurs littérales uniques dans certains cas. ([GitHub][14])

### Fonctions

Les fonctions ne sont pas sérialisables comme SavedVariables. Les guides listent explicitement `functions`, `userdata` et `coroutines` parmi les types qui ne seront pas sauvegardés. ([WoWWiki Archive][7])

À éviter :

```lua
MyAddonDB = {
    counter = 0,

    -- Mauvais : ne doit pas être dans une SavedVariable.
    callback = function()
        print("hello")
    end,
}
```

Si une table contient une fonction, il ne faut pas compter sur sa restauration. Les sources disent que les fonctions “ne seront pas sauvegardées”, mais je n’ai pas trouvé de documentation Blizzard moderne précisant formellement si le champ est silencieusement ignoré, supprimé du dump, ou traité différemment selon le sérialiseur interne. Le comportement sûr est donc : **ne mets jamais de fonction, frame, texture, userdata, coroutine ou objet runtime dans une SavedVariable**. ([WoWWiki Archive][7])

### Tables mixtes : clés numériques + clés string

Oui, les tables Lua peuvent contenir des clés numériques et des clés chaînes, et les SavedVariables utilisent justement des tables Lua. C’est donc un cas normal tant que les clés et valeurs sont elles-mêmes sérialisables. ([WoWInterface][13])

Exemple valide :

```lua
MyAddonDB = {
    [1] = "first",
    [2] = "second",

    counter = 2,
    enabled = true,
}
```

### Références circulaires

Les références circulaires sont à éviter. Les guides communautaires signalent que les références circulaires ne seront pas préservées correctement. ([WoWWiki Archive][7])

Mauvais :

```lua
MyAddonDB = {}
MyAddonDB.self = MyAddonDB -- à éviter
```

---

## 4. Pattern d’initialisation recommandé

Ton pattern est correct :

```lua
local defaults = {
    counter = 0,
    name = "unknown",
}

-- Dans ADDON_LOADED :
MyAddonDB = MyAddonDB or {}

for k, v in pairs(defaults) do
    if MyAddonDB[k] == nil then
        MyAddonDB[k] = v
    end
end
```

Le point important est le test `== nil`, pas un simple `or`, parce que `false` est une valeur utilisateur valide. Par exemple, si l’utilisateur a sauvegardé `enabled = false`, ce code respecte son choix :

```lua
if MyAddonDB.enabled == nil then
    MyAddonDB.enabled = true
end
```

Alors que celui-ci écraserait `false` :

```lua
MyAddonDB.enabled = MyAddonDB.enabled or true -- mauvais pour les booléens
```

L’usage de `ADDON_LOADED` filtré sur ton add-on est conforme aux recommandations : les SavedVariables sont disponibles à cet événement, et les guides comme les add-ons réels font cette initialisation à ce moment-là. ([Warcraft Wiki][2])

### Pattern plus propre avec defaults imbriqués

Pour des defaults imbriqués, utilise une copie récursive qui matérialise les tables manquantes :

```lua
local ADDON_NAME = ...

local defaults = {
    counter = 0,
    name = "unknown",

    minimap = {
        hide = false,
        angle = 180,
    },

    window = {
        x = 0,
        y = 0,
        width = 400,
        height = 300,
    },
}

local function ApplyDefaults(db, defaultsTable)
    if type(db) ~= "table" then
        db = {}
    end

    for k, defaultValue in pairs(defaultsTable) do
        if type(defaultValue) == "table" then
            db[k] = ApplyDefaults(db[k], defaultValue)
        elseif db[k] == nil then
            db[k] = defaultValue
        end
    end

    return db
end

local db

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    MyAddonDB = ApplyDefaults(MyAddonDB, defaults)
    db = MyAddonDB

    self:UnregisterEvent("ADDON_LOADED")
end)
```

Ce pattern est idiomatique parce qu’il garde une seule globale sauvegardée, évite la pollution de `_G`, respecte les valeurs utilisateur existantes, et fonctionne naturellement avec la sérialisation en table Lua. Les guides recommandent justement d’utiliser une table unique pour organiser les SavedVariables plutôt que multiplier les globales. ([WoWWiki Archive][7])

---

## 5. Où sont stockés les fichiers ?

Pour Classic Era, le chemin est sous le dossier du jeu `_classic_era_`.

### `SavedVariables` compte

Chemin attendu :

```text
World of Warcraft/_classic_era_/WTF/Account/<account>/SavedVariables/<AddonName>.lua
```

Les docs Warcraft Wiki indiquent que les SavedVariables sont stockées sous `WTF/Account/...`, et les guides anciens détaillent le chemin `WTF\Account\ACCOUNTNAME\SavedVariables\AddOnName.lua` pour les variables par compte. ([Warcraft Wiki][15])

Deathlog, un add-on Classic Era, affiche directement dans son code un chemin utilisateur de type :

```text
_classic_era_/WTF/Account/<your_account_name>/SavedVariables/Deathlog.lua
```

ce qui confirme la forme pratique du chemin pour Classic Era. ([GitHub][16])

### `SavedVariablesPerCharacter`

Chemin attendu :

```text
World of Warcraft/_classic_era_/WTF/Account/<account>/<server>/<character>/SavedVariables/<AddonName>.lua
```

Les guides détaillent le chemin per-character sous `WTF\Account\ACCOUNTNAME\RealmName\CharacterName\SavedVariables\AddOnName.lua`. ([WoWWiki Archive][7])

---

## 6. Exemples d’add-ons Classic Era existants

### Exemple 1 — RaidLogAuto

RaidLogAuto supporte Classic Era avec interface `11508` et stocke sa configuration dans une SavedVariable globale `RaidLogAutoDB`. Son `.toc` Vanilla déclare `## SavedVariables: RaidLogAutoDB`. ([GitHub][17])

Extrait `.toc` :

```toc
## Interface-Vanilla: 11508, 11507
## SavedVariables: RaidLogAutoDB
```

Extrait d’initialisation :

```lua
RaidLogAutoDB = RaidLogAutoDB or {}

local defaults = {
    enabled = true,
    onlyInRaid = true,
    autoStartOnBoss = true,
    autoStopAfterCombat = true,
    minimap = { hide = false },
}

-- Dans ADDON_LOADED :
for key, value in pairs(defaults) do
    if RaidLogAutoDB[key] == nil then
        RaidLogAutoDB[key] = value
    end
end
```

Le code réel initialise `RaidLogAutoDB = RaidLogAutoDB or {}`, définit une table `defaults`, puis applique les valeurs manquantes dans le handler `ADDON_LOADED` filtré sur le nom de l’add-on. ([GitHub][18])

### Exemple 2 — Deathlog

Deathlog est un add-on populaire pour WoW Hardcore / Classic Era, avec support Classic Era et une base de données de morts collectées. ([GitHub][19])

Son `.toc` déclare plusieurs SavedVariables compte et une SavedVariable par personnage :

```toc
## Interface: 20505, 11508
## SavedVariables: deathlog_settings, deathlog_data, deathlog_data_map, deathlog_data_map_by_loc, deathlog_data_map_by_id, deathlog_last_server_reset, deathlog_cache, deathlog_last_cache_update, deathlog_precomputed
## SavedVariablesPerCharacter: deathlog_char_data
```

Ces lignes sont présentes dans son `.toc`. ([GitHub][10])

Extrait d’initialisation :

```lua
deathlog_settings = deathlog_settings or {}
deathlog_data = deathlog_data or {}
deathlog_data_map = deathlog_data_map or {}
deathlog_char_data = deathlog_char_data or {}
```

Le code réel appelle une fonction `initVariables()` qui initialise ces globales, puis l’appelle aussi dans le handler `ADDON_LOADED` quand `loaded_addon == addonName`. ([GitHub][16])

Deathlog montre aussi un usage réel de `wipe()` sur des SavedVariables pour vider un cache :

```lua
wipe(deathlog_data)
wipe(deathlog_data_map)
```

Son UI précise ensuite que les données sont stockées dans `_classic_era_/WTF/Account/<your_account_name>/SavedVariables/Deathlog.lua`. ([GitHub][16])

### Exemple 3 — Questie

Questie est un add-on de quête très populaire pour WoW Classic ; sa page CurseForge indique un très grand volume de téléchargements et une mise à jour récente, et son dépôt GitHub montre une release récente. ([curseforge.com][20])

Son `.toc` Classic Era déclare :

```toc
## Interface: 11508
## SavedVariables: QuestieConfig
## SavedVariablesPerCharacter: QuestieConfigCharacter
```

Ces lignes confirment l’usage simultané des SavedVariables compte et personnage en Classic Era 11508. ([GitHub][9])

Questie sépare aussi des phases d’initialisation : une fonction `OnAddonLoaded()` est appelée côté chargement add-on, tandis qu’une autre phase `Init()` est lancée via `PLAYER_LOGIN`, ce qui illustre bien la distinction entre “SavedVariables prêtes” et “initialisation complète de l’UI / du joueur”. ([GitHub][21])

---

## 7. Points subtils / gotchas

### `.toc` déclare `SavedVariables: MyVar`, mais le `.lua` ne définit jamais `MyVar`

Au premier chargement, `MyVar` sera `nil` si aucun fichier SavedVariables existant ne la définit. Si ton add-on ne l’initialise jamais, il n’y aura rien d’utile à sauvegarder. Les guides montrent explicitement que les variables absentes sont `nil` au premier run, puis doivent être initialisées par l’add-on. ([WoWWiki Archive][7])

Correct :

```lua
MyVar = MyVar or {}
```

### Le `.lua` définit `MyVar`, mais le `.toc` ne la déclare pas

La variable existera pendant la session courante, mais elle ne sera pas sauvegardée/restaurée automatiquement. Les sources communautaires rappellent que le seul mécanisme de sauvegarde persistante passe par les directives `## SavedVariables:` et `## SavedVariablesPerCharacter:` du `.toc`. ([Blizzard Forums][22])

### Peut-on utiliser une table locale comme proxy ?

Oui, si elle référence la globale sauvegardée après `ADDON_LOADED` :

```lua
MyAddonDB = MyAddonDB or {}
local db = MyAddonDB

db.counter = (db.counter or 0) + 1
```

Ici, `db` et `MyAddonDB` pointent vers la même table, donc les mutations sont sauvegardées via la globale `MyAddonDB`.

Attention en revanche à ceci :

```lua
local db = {}
db.counter = 1
```

Cette table locale ne sera pas sauvegardée si elle n’est jamais assignée à la globale déclarée dans le `.toc`. Les guides indiquent que les SavedVariables sont chargées/sauvegardées dans l’environnement global ; les locals doivent donc être synchronisées avec la globale. ([WoWWiki Archive][7])

### `wipe()` est-il utilisable sur les SavedVariables ?

Oui. `wipe(MyAddonDB)` vide la table en place. Comme la table globale reste la même table mais vidée, cet état sera sauvegardé au logout ou au `/reload`.

Deathlog utilise concrètement `wipe(deathlog_data)` et `wipe(deathlog_data_map)` pour vider des données sauvegardées/cache. ([GitHub][16])

Exemple :

```lua
SLASH_MYADDON1 = "/myaddon"
SlashCmdList["MYADDON"] = function(msg)
    if msg == "reset" then
        wipe(MyAddonDB)
        MyAddonDB.counter = 0
        print("MyAddonDB reset.")
    end
end
```

### Limites de taille

Je n’ai pas trouvé de limite officielle simple du type “maximum X Mo par fichier SavedVariables”. Il existe cependant des limites pratiques : les fichiers SavedVariables sont du Lua lisible, peuvent devenir très gros, et de très grosses tables peuvent déclencher des erreurs de chargement/compilation comme `constant table overflow`. Un rapport WoWUIBugs documente un cas autour de plus de 262 144 valeurs littérales uniques. ([Blizzard Forums][23])

Il existe aussi un cas d’erreur `SAVED_VARIABLES_TOO_LARGE` mentionné dans la documentation de `ADDON_LOADED`, ce qui confirme qu’un add-on peut échouer à charger ses SavedVariables si elles sont trop volumineuses. ([Warcraft Wiki][2])

Conclusion pratique : ne stocke pas de logs infinis, ne stocke pas de frames/textures/functions/userdata, nettoie les caches, et préfère une structure compacte :

```lua
MyAddonDB = {
    version = 1,
    settings = {},
    cache = {}, -- purgeable
}
```

### Collision de noms globaux

Tous les add-ons partagent l’espace global `_G`. Il faut donc préfixer fortement ses SavedVariables, par exemple `MyAddonDB` plutôt que `DB`, `Config` ou `Settings`. Des discussions communautaires rappellent que l’environnement global est partagé entre Blizzard UI et tous les add-ons, donc les noms trop génériques peuvent entrer en collision. ([WoWInterface][24])

---

## Pattern final recommandé pour ta capsule

```toc
## Interface: 11508
## Title: MyAddon
## Notes: SavedVariables example
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB

MyAddon.lua
```

```lua
local ADDON_NAME = ...

local defaults = {
    counter = 0,
    name = "unknown",
    options = {
        enabled = true,
        scale = 1.0,
    },
}

local charDefaults = {
    seenTutorial = false,
}

local db
local charDB

local function ApplyDefaults(target, source)
    if type(target) ~= "table" then
        target = {}
    end

    for key, defaultValue in pairs(source) do
        if type(defaultValue) == "table" then
            target[key] = ApplyDefaults(target[key], defaultValue)
        elseif target[key] == nil then
            target[key] = defaultValue
        end
    end

    return target
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName ~= ADDON_NAME then
            return
        end

        MyAddonDB = ApplyDefaults(MyAddonDB, defaults)
        MyAddonCharDB = ApplyDefaults(MyAddonCharDB, charDefaults)

        db = MyAddonDB
        charDB = MyAddonCharDB

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGOUT" then
        if db then
            db.lastLogout = time()
        end
    end
end)
```

Ce pattern est le plus sûr pour Classic Era : déclaration `.toc`, globale sauvegardée, initialisation dans `ADDON_LOADED`, defaults récursifs, proxy local après chargement, et mise à jour finale éventuelle dans `PLAYER_LOGOUT`.

[1]: https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions?utm_source=chatgpt.com "Saving variables between game sessions - Warcraft Wiki"
[2]: https://warcraft.wiki.gg/wiki/ADDON_LOADED?utm_source=chatgpt.com "ADDON_LOADED - Warcraft Wiki"
[3]: https://www.wowinterface.com/forums/showthread.php?t=39536 "About ADDON_LOADED and VARIABLES_LOADED events - WoWInterface"
[4]: https://warcraft.wiki.gg/wiki/VARIABLES_LOADED?utm_source=chatgpt.com "VARIABLES_LOADED - Warcraft Wiki - Your wiki guide to the World ..."
[5]: https://wowpedia.fandom.com/wiki/AddOn_loading_process?utm_source=chatgpt.com "AddOn loading process - Wowpedia - Fandom"
[6]: https://warcraft.wiki.gg/wiki/PLAYER_LOGOUT?utm_source=chatgpt.com "PLAYER_LOGOUT - Warcraft Wiki"
[7]: https://wowwiki-archive.fandom.com/wiki/Saving_variables_between_game_sessions "Saving variables between game sessions | WoWWiki | Fandom"
[8]: https://addonstudio.org/wiki/WoW%3ATOC_format?utm_source=chatgpt.com "WoW:TOC format"
[9]: https://github.com/Questie/Questie/blob/master/Questie-Classic.toc "Questie/Questie-Classic.toc at master · Questie/Questie · GitHub"
[10]: https://github.com/aaronma37/Deathlog/blob/master/Deathlog.toc "Deathlog/Deathlog.toc at master · aaronma37/Deathlog · GitHub"
[11]: https://github.com/Xerrion/RaidLogAuto/blob/master/RaidLogAuto.toc "RaidLogAuto/RaidLogAuto.toc at master · Xerrion/RaidLogAuto · GitHub"
[12]: https://www.bluetracker.gg/wow/topic/us-en/94202708-addon-bug-sub-table-in-saved-variables/?utm_source=chatgpt.com "[ADDON BUG] Sub-table in Saved Variables"
[13]: https://www.wowinterface.com/forums/showthread.php?t=7389&utm_source=chatgpt.com "Heh, saved variables?"
[14]: https://github.com/Stanzilla/WoWUIBugs/issues/241?utm_source=chatgpt.com "Suggestion to improve SavedVariables writing process #241"
[15]: https://warcraft.wiki.gg/wiki/SavedVariables?utm_source=chatgpt.com "SavedVariables - Warcraft Wiki"
[16]: https://github.com/aaronma37/Deathlog/blob/master/deathlog.lua "Deathlog/deathlog.lua at master · aaronma37/Deathlog · GitHub"
[17]: https://github.com/Xerrion/RaidLogAuto "GitHub - Xerrion/RaidLogAuto: Automatically enables combat logging when entering a raid and disables it when leaving · GitHub"
[18]: https://github.com/Xerrion/RaidLogAuto/blob/master/RaidLogAuto_Vanilla.lua "RaidLogAuto/RaidLogAuto_Vanilla.lua at master · Xerrion/RaidLogAuto · GitHub"
[19]: https://github.com/aaronma37/Deathlog?utm_source=chatgpt.com "aaronma37/Deathlog"
[20]: https://www.curseforge.com/wow/addons/questie?utm_source=chatgpt.com "Questie - World of Warcraft Addons"
[21]: https://github.com/Questie/Questie/blob/master/Modules/QuestieInit.lua "Questie/Modules/QuestieInit.lua at master · Questie/Questie · GitHub"
[22]: https://us.forums.blizzard.com/en/wow/t/saving-local-variables-between-sessions/380081?utm_source=chatgpt.com "Saving Local Variables Between Sessions - UI and Macro"
[23]: https://us.forums.blizzard.com/en/wow/t/option-to-compress-savedvariables/1752911?utm_source=chatgpt.com "Option to Compress SavedVariables - General Discussion"
[24]: https://www.wowinterface.com/forums/showthread.php?t=59831&utm_source=chatgpt.com "Saved variables not working"
