# Recherche — API Explorer WoW : projets existants et dump de l’API Lua

## Résumé opérationnel

Oui, il existe plusieurs briques sérieuses, mais aucune ne donne à elle seule “la vérité complète” pour un client Classic Era précis. La meilleure approche est hybride :

1. **Runtime in-game** : dumper `_G`, les métatables de widgets, les événements observés, les frames chargées, via un add-on de dump.
2. **Export statique** : exporter ou récupérer le `FrameXML` / les Blizzard AddOns via `ExportInterfaceFiles code` ou via des miroirs Git.
3. **Données communautaires** : utiliser les dumps de Ketho / BlizzardInterfaceResources, les miroirs `wow-ui-source`, les outils d’IDE LuaLS, et comparer par build.
4. **Validation Classic Era** : toujours exécuter le dump sur le client cible, parce que Retail, Classic, Classic Era, PTR et Beta divergent.

Le projet le plus proche de ton besoin est **KethoDoc** : il dump explicitement l’API globale, les méthodes de widgets, les événements, les CVars, les enums Lua, les frames top-level et des fonctions FrameXML, dans le but d’alimenter **BlizzardInterfaceResources**. ([GitHub][1])

---

## 1. Projets existants d’exploration / dump de l’API WoW

### 1.1 Tableau des projets les plus pertinents

| Projet                                                      | Ce que ça dump / expose                                                                                                                                                                                                                                                | Fonctionnement                                                                                                                                 | Dernière mise à jour connue                                                                                                                               | Distinction Retail / Classic / Classic Era                                                                                                                                                     |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **KethoDoc**                                                | API globale, API widgets, événements, CVars, commandes console, enums Lua, frames top-level, fonctions FrameXML. Le README expose notamment `DumpGlobalAPI()`, `DumpWidgetAPI()`, `DumpEvents()`, `DumpCVars()`, `DumpLuaEnums()`, `DumpFrames()` et `DumpFrameXML()`. | Add-on / outil in-game qui introspecte le client en cours d’exécution et organise les données pour `BlizzardInterfaceResources`.               | Le dépôt montre des commits en 2026, dont un historique récent jusqu’au 25 mars 2026 ; il contient aussi des commits liés à `1.15.8 ptr` en octobre 2025. | Le dump dépend du client sur lequel il est lancé ; l’historique montre des travaux sur Classic Era / PTR 1.15.x. ([GitHub][1])                                                                 |
| **Ketho / BlizzardInterfaceResources**                      | Ressources de développement pour l’API WoW : listes d’API, widgets, événements, etc. KethoDoc est explicitement conçu pour dumper les données destinées à ce dépôt.                                                                                                    | Dépôt de données générées / maintenues à partir de dumps et de sources d’interface.                                                            | Dépôt actif avec releases / tags selon la page GitHub indexée.                                                                                            | Le dépôt est organisé autour des ressources de l’API WoW et peut être alimenté par des dumps de clients différents ; à vérifier par branche/tag/fichier pour chaque version. ([GitHub][2])     |
| **Resike / BlizzardInterfaceResources**                     | Ressources globales extraites de World of Warcraft ; contient par exemple un gros `API.lua` listant des noms d’API globales.                                                                                                                                           | Dépôt statique de ressources extraites.                                                                                                        | Pas de release visible dans la page consultée ; dépôt plus ancien.                                                                                        | Ne semble pas être le meilleur choix pour distinguer finement Classic Era moderne ; utile comme référence historique / comparative. ([GitHub][3])                                              |
| **Gethe / wow-ui-source**                                   | Miroir Git du code UI Blizzard exporté : `FrameXML`, Blizzard AddOns, XML/Lua, par branche client.                                                                                                                                                                     | Miroir de l’UI source exportée ; ce n’est pas un dump runtime de `_G`, mais une source statique très utile pour templates, mixins et FrameXML. | La branche `classic_era` montre des commits récents, par exemple `1.15.8 (67156)` le 27 avril 2026.                                                       | Oui : branches séparées, dont `classic_era`, avec builds Classic Era traçables. ([GitHub][4])                                                                                                  |
| **Gethe / InterfaceExport**                                 | Extrait les fichiers d’interface depuis une installation locale ou le CDN : code, art, PNG, ou tout.                                                                                                                                                                   | Outil offline basé sur Casc / CDN ; usage documenté sous la forme `lua export.lua [project] [branch] [filter]`.                                | Derniers commits visibles en septembre 2024 dans la page consultée.                                                                                       | Oui : le README liste les projets `retail`, `classic`, `wrath`, `classic_era`, `vanilla`, et les branches `live`, `ptr`, `ptr2`, `beta`. ([GitHub][5])                                         |
| **tomrus88 / BlizzardInterfaceCode**                        | Code Blizzard exporté, dont `Blizzard_APIDocumentation.lua`.                                                                                                                                                                                                           | Dépôt miroir de code UI exporté ; permet d’inspecter le système `/api` de Blizzard.                                                            | Dépend du miroir / branche consultée.                                                                                                                     | Utile pour comprendre l’API documentation intégrée, mais pas suffisant comme dump complet. ([GitHub][6])                                                                                       |
| **`/api` / Blizzard_APIDocumentation**                      | Tables, fonctions, événements, systèmes et callbacks documentés par Blizzard dans l’add-on d’API documentation.                                                                                                                                                        | Add-on Blizzard in-game ; le code contient des fonctions de recherche et d’affichage des API documentées.                                      | Inclus dans les exports FrameXML / Blizzard AddOns.                                                                                                       | Très dépendant du client ; surtout utile quand le client fournit des tables APIDocumentation. Attention : la communauté signale que `/api` ne contient pas toutes les fonctions. ([GitHub][6]) |
| **Event Trace / `/eventtrace` / `/etrace`**                 | Événements réellement déclenchés pendant une session, avec filtrage possible.                                                                                                                                                                                          | Outil Blizzard in-game de debug événementiel ; historiquement basé sur une frame enregistrée sur tous les événements.                          | Intégré au client ; disponibilité exacte à tester sur Classic Era.                                                                                        | Montre les événements observés à l’exécution, pas nécessairement la liste complète théorique. ([Blizzard Forums][7])                                                                           |
| **EventTracker**                                            | Suivi détaillé des événements déclenchés, arguments et frames qui les surveillent ; peut aussi suivre certains appels de fonctions selon la description.                                                                                                               | Add-on de debug.                                                                                                                               | CurseForge indique une mise à jour le 7 août 2024.                                                                                                        | Le projet GitHub cité historiquement visait surtout d’anciens clients 2.4.3 / 3.3.5 / 4.3.4 / 5.4.8 ; la version CurseForge moderne est à vérifier par flavor. ([curseforge.com][8])           |
| **shagu / wow-vanilla-api**                                 | Documentation API Vanilla 1.12.1, incluant notamment une liste d’événements.                                                                                                                                                                                           | Dump / documentation communautaire statique.                                                                                                   | Le contenu cible Vanilla 1.12.1, pas Classic Era moderne.                                                                                                 | Non : utile comme comparaison historique, pas comme vérité Classic Era 1.15.x. ([GitHub][9])                                                                                                   |
| **Ketho / vscode-wow-api**                                  | Annotations LuaLS / IntelliSense pour l’API WoW.                                                                                                                                                                                                                       | Extension VS Code / LuaLS consommant des définitions générées ou maintenues ; utile comme sortie finale de ton propre dumper.                  | Marketplace : mise à jour indiquée le 24 février 2026.                                                                                                    | Projet orienté IDE ; la distinction exacte des flavors dépend des définitions incluses. ([Visual Studio Marketplace][10])                                                                      |
| **wow-classic-declarations / wow-ts-decl / autres typings** | Déclarations TypeScript ou Lua pour API WoW / Classic.                                                                                                                                                                                                                 | Génération ou maintenance de typings pour TypeScriptToLua / LuaLS.                                                                             | Variable selon dépôt.                                                                                                                                     | Utile comme inspiration de format, mais pas comme source primaire fiable pour Classic Era 1.15.x sans vérification runtime. ([GitHub][11])                                                     |

### 1.2 Ce qu’il faut retenir

**KethoDoc** est le point de départ le plus direct pour ton besoin : il vise précisément le dump de l’API globale, des widgets, des événements, des CVars, des enums, des frames et de FrameXML. ([GitHub][1])

**Gethe / wow-ui-source** est probablement la meilleure source statique pour Classic Era moderne, car la branche `classic_era` suit des builds récents, dont `1.15.8`. Ce dépôt ne remplace pas l’introspection runtime, mais il est excellent pour analyser les fichiers `.lua`, `.xml`, les templates, les mixins et les changements par build. ([GitHub][12])

**`/api` / Blizzard_APIDocumentation** est utile, mais incomplet : un fil WoWInterface rappelle que la commande `/api` ne contient que ce que Blizzard a explicitement ajouté à son add-on de documentation et qu’elle ne contiendra probablement jamais toutes les fonctions. ([WoWInterface][13])

---

## 2. La commande `ExportInterfaceFiles`

### 2.1 Syntaxe correcte

La documentation historique indique d’utiliser les commandes console :

```text
ExportInterfaceFiles code
ExportInterfaceFiles art
```

Le point important : ce sont des **commandes de console client**, à exécuter depuis la console ouverte au login screen ou à l’écran de sélection de personnage, pas une commande slash Lua en jeu. Les sources indiquent explicitement que ça ne fonctionne pas via `/console` pendant que le personnage est connecté ; il faut lancer le client avec `-console`, ouvrir la console, puis taper la commande. ([Wowpedia][14])

Donc, pour éviter la confusion :

```text
-- Mauvais en jeu :
/console ExportInterfaceFiles code

-- À faire dans la console client ouverte avec -console :
ExportInterfaceFiles code
```

### 2.2 Où les fichiers sont dumpés ?

La documentation indique que les fichiers sont créés dans des dossiers nommés :

```text
BlizzardInterfaceCode
BlizzardInterfaceArt
```

dans le répertoire de World of Warcraft. ([Wowpedia][14])

Sur une installation moderne multi-flavors, pour Classic Era, le chemin pratique attendu est généralement dans le répertoire du client lancé, par exemple autour de :

```text
World of Warcraft/_classic_era_/BlizzardInterfaceCode/
World of Warcraft/_classic_era_/BlizzardInterfaceArt/
```

Mais la source consultée formule le chemin de façon générique comme “dans le répertoire World of Warcraft” ; pour ton client 1.15.x exact, il faut vérifier le dossier produit après exécution. ([Wowpedia][14])

### 2.3 Contenu de `ExportInterfaceFiles code`

`ExportInterfaceFiles code` extrait le code de l’interface Blizzard : `FrameXML`, Blizzard AddOns, fichiers `.lua` et `.xml`, et plus généralement le code UI que Blizzard charge côté interface. Les sources parlent explicitement de `FrameXML` / `AddOns` Blizzard et du code de l’interface utilisateur. ([Wowpedia][14])

Le miroir `wow-ui-source` de Gethe montre concrètement cette structure sous forme de dépôt Git, avec un dossier `Interface` et des branches par client, dont `classic_era`. ([GitHub][12])

### 2.4 Est-ce que ça contient toutes les fonctions API Lua ?

Non. `ExportInterfaceFiles code` donne le **code UI Blizzard exportable**, pas l’implémentation native C/C++ du client. Une partie de l’API est visible parce que le FrameXML l’appelle, ou parce que Blizzard fournit `Blizzard_APIDocumentation`, mais les fonctions natives elles-mêmes restent dans le client fermé. Des discussions d’addon authors distinguent justement le code FrameXML/AddOns visible et les API exposées directement par le jeu, qui restent côté moteur fermé. ([WoWInterface][15])

Conséquence pratique : pour connaître toutes les fonctions accessibles en Lua, il faut combiner :

```text
ExportInterfaceFiles code
+ dump runtime de _G
+ dump des métatables de widgets
+ Blizzard_APIDocumentation quand disponible
+ diff entre clients / builds
```

### 2.5 Est-ce que ça fonctionne en Classic Era 1.15.x ?

Je n’ai pas trouvé de source officielle Blizzard disant explicitement “Classic Era 1.15.x / interface 11508 supporte `ExportInterfaceFiles code`”. En revanche, les sources documentent `ExportInterfaceFiles` comme commande client WoW, et les outils modernes comme Gethe / InterfaceExport listent explicitement `classic_era` comme projet exportable depuis installation locale ou CDN. De plus, `wow-ui-source` possède une branche `classic_era` mise à jour jusqu’à des builds 1.15.8 en 2026. ([Wowpedia][14])

Conclusion prudente : **oui, c’est la voie attendue pour Classic Era, mais valide toujours sur ton client précis**. Pour une pipeline robuste, garde aussi une voie CDN/offline via `InterfaceExport`, parce qu’elle distingue explicitement `classic_era`, `live`, `ptr`, `ptr2`, `beta`, et les filtres `code`, `art`, `png`, `all`. ([GitHub][5])

### 2.6 Combien de fichiers environ ?

Le nombre exact dépend du build, du flavor, du filtre et de la langue. Les sources consultées ne donnent pas un chiffre fiable pour Classic Era 1.15.x / interface 11508. Historiquement, l’export `art` pouvait générer énormément de fichiers : une source ancienne donne un exemple de 19 122 fichiers art sur un PTR, et une autre note que l’export art pouvait atteindre au moins 2,8 Go à l’époque de 8.2. ([WoWInterface][16])

Pour `code`, attends plutôt un volume raisonnable de fichiers `.lua` / `.xml`; pour `art`, attends un export beaucoup plus gros, souvent inutile pour un API Explorer sauf si tu veux indexer textures, atlas et assets UI. ([Wowpedia][14])

### 2.7 `ExportInterfaceFiles art`

`ExportInterfaceFiles art` extrait les assets graphiques de l’interface dans `BlizzardInterfaceArt`. La documentation liste bien les deux commandes `code` et `art`, et indique que les fichiers extraits sont destinés aux développeurs d’add-ons, sans support officiel Blizzard. ([Wowpedia][14])

---

## 3. Méthodologie pour construire ton propre API Explorer in-game

## 3a. Dump des globales

### Principe

Dans l’environnement Lua WoW, les objets globaux visibles — fonctions, tables, strings, numbers, booleans — sont accessibles via `_G`. Une discussion WoWInterface décrit même les dumps de Ketho comme une organisation plus avancée de ce qu’on obtient en parcourant `_G` dans le client. ([WoWInterface][13])

Base minimale :

```lua
local rows = {}

for k, v in pairs(_G) do
  rows[#rows + 1] = {
    name = tostring(k),
    kind = type(v),
  }
end

table.sort(rows, function(a, b)
  return a.name < b.name
end)

for _, row in ipairs(rows) do
  print(row.name, row.kind)
end
```

### Est-ce que ça liste vraiment tout ?

Ça liste ce qui est **globalement visible dans l’environnement Lua courant**. Ça ne garantit pas :

* les fonctions natives non exposées comme globales ;
* les méthodes accessibles seulement via métatables de widgets ;
* les API chargées plus tard par des Blizzard AddOns load-on-demand ;
* les tables créées après certains événements ;
* les fonctions protégées ou secure qui existent mais ne sont pas appelables dans tous les contextes.

Cette distinction est importante parce que le code UI exporté n’est pas l’implémentation native complète du client, et parce que `/api` ne documente pas tout. ([WoWInterface][15])

### Comment distinguer Lua standard / WoW / add-ons ?

Méthode recommandée :

1. construire une allowlist des symboles Lua standards ;
2. lancer ton add-on seul sur une installation propre ;
3. dumper `_G` à plusieurs moments : `ADDON_LOADED`, `PLAYER_LOGIN`, après chargement des Blizzard AddOns, après ouverture de panneaux UI ;
4. comparer avec une session “sans ton add-on” ;
5. stocker le résultat dans une SavedVariable pour analyse hors jeu.

Exemple de classification simple :

```lua
local luaStd = {
  assert = true,
  collectgarbage = true,
  coroutine = true,
  debug = true,
  error = true,
  getfenv = true,
  getmetatable = true,
  ipairs = true,
  loadstring = true,
  math = true,
  next = true,
  pairs = true,
  pcall = true,
  print = true,
  rawequal = true,
  rawget = true,
  rawset = true,
  select = true,
  setfenv = true,
  setmetatable = true,
  string = true,
  table = true,
  tonumber = true,
  tostring = true,
  type = true,
  unpack = true,
  xpcall = true,
}

local dump = {}

for k, v in pairs(_G) do
  dump[#dump + 1] = {
    name = tostring(k),
    kind = type(v),
    category = luaStd[k] and "lua-std" or "wow-or-addon",
  }
end
```

La classification “wow-or-addon” n’est pas suffisante seule : il faut ensuite croiser avec le `FrameXML`, les Blizzard AddOns exportés, et un profil de session avec seulement Blizzard UI. ([Wowpedia][14])

---

## 3b. Exploration des méthodes de widgets

### Métatables de widgets

Les widgets WoW sont des objets userdata/table spéciaux, et leurs méthodes sont accessibles via leur métatable, en particulier `getmetatable(widget).__index`. Des discussions WoWInterface montrent explicitement des exemples du type :

```lua
for k, v in pairs(getmetatable(frame).__index) do
  ...
end
```

et des usages comme récupérer `getmetatable(BuffFrame).__index.SetPoint`. ([WoWInterface][17])

Le Wiki historique “Widget API” indique aussi que les listes de fonctions UIObject/widget ont été trouvées en scannant l’environnement in-game. ([WoWWiki Archive][18])

### Exemple de dumper de méthodes

```lua
local function collectMethods(obj)
  local methods = {}
  local mt = getmetatable(obj)

  if mt and type(mt.__index) == "table" then
    for name, value in pairs(mt.__index) do
      if type(value) == "function" then
        methods[#methods + 1] = tostring(name)
      end
    end
  end

  table.sort(methods)
  return methods
end

local samples = {
  Frame = function()
    return CreateFrame("Frame")
  end,

  Button = function()
    return CreateFrame("Button")
  end,

  CheckButton = function()
    return CreateFrame("CheckButton")
  end,

  EditBox = function()
    return CreateFrame("EditBox")
  end,

  Slider = function()
    return CreateFrame("Slider")
  end,

  StatusBar = function()
    return CreateFrame("StatusBar")
  end,

  FontString = function()
    return UIParent:CreateFontString(nil, "OVERLAY")
  end,

  Texture = function()
    return UIParent:CreateTexture(nil, "ARTWORK")
  end,

  AnimationGroup = function()
    return UIParent:CreateAnimationGroup()
  end,
}

for widgetType, make in pairs(samples) do
  local ok, obj = pcall(make)

  if ok and obj then
    local methods = collectMethods(obj)
    print(widgetType, #methods)
  else
    print("FAILED", widgetType, obj)
  end
end
```

Attention : tous les types ne se créent pas forcément via `CreateFrame("Type")`. Certains objets se créent via des méthodes de frames (`CreateTexture`, `CreateFontString`, `CreateAnimationGroup`, etc.), ce qui correspond à la hiérarchie de widgets UIObject / Region / Frame / LayeredRegion / Animation décrite dans les docs Widget API. ([WoWWiki Archive][18])

### Comment obtenir l’héritage réel ?

Une bonne méthode est de dumper les méthodes par type, puis de faire des diffs :

```text
ButtonMethods - FrameMethods = méthodes spécifiques Button
StatusBarMethods - FrameMethods = méthodes spécifiques StatusBar
TextureMethods - RegionMethods = méthodes spécifiques Texture
```

C’est exactement le genre de données que KethoDoc vise déjà via `DumpWidgetAPI()`. ([GitHub][1])

---

## 3c. Événements

### Sources possibles

Il y a trois familles de sources pour les événements :

1. **APIDocumentation / `/api`** : événements documentés par Blizzard quand présents dans le système `Blizzard_APIDocumentation`. ([GitHub][6])
2. **Dumps communautaires** : KethoDoc expose `DumpEvents()`, et des projets historiques comme `wow-vanilla-api` listent les événements pour Vanilla 1.12.1. ([GitHub][1])
3. **Observation runtime** : `RegisterAllEvents()`, `/eventtrace`, ou un add-on comme EventTracker. ([Warcraft Wiki][19])

### Observation runtime

Exemple minimal :

```lua
local f = CreateFrame("Frame")
local seen = {}

f:RegisterAllEvents()

f:SetScript("OnEvent", function(_, event, ...)
  local row = seen[event]

  if not row then
    row = {
      count = 0,
      samples = {},
    }
    seen[event] = row
  end

  row.count = row.count + 1

  if #row.samples < 3 then
    row.samples[#row.samples + 1] = { ... }
  end
end)
```

Cette méthode ne découvre que les événements qui se déclenchent pendant ta session. Elle ne prouve pas qu’un événement absent n’existe pas. Les sources communautaires préviennent aussi que `RegisterAllEvents()` est surtout un outil de debug, pas une pratique normale en production. ([WoWWiki Archive][20])

### Stratégie robuste

Pour un vrai explorer Classic Era :

```text
events =
  événements APIDocumentation
  ∪ événements KethoDoc / BlizzardInterfaceResources
  ∪ événements observés via RegisterAllEvents
  ∪ événements repérés dans FrameXML par recherche de RegisterEvent(...)
```

Puis tu attaches pour chaque événement :

```text
nom
source
présent dans build
observé oui/non
payload observé
fichiers FrameXML qui l’utilisent
```

Cette approche évite de confondre “pas observé” avec “n’existe pas”. Elle est cohérente avec le fait que `/api` est incomplet et que le code FrameXML ne couvre pas forcément toute l’API native. ([WoWInterface][13])

---

## 3d. Templates XML et Mixins

### Templates XML

Les templates XML ne sont pas correctement découvrables uniquement via `_G`. La bonne source est le code exporté : `ExportInterfaceFiles code`, `Gethe / wow-ui-source`, ou `Gethe / InterfaceExport`. Ces sources donnent accès aux fichiers `.xml` et `.lua` de l’interface Blizzard. ([Wowpedia][14])

Méthode recommandée hors jeu :

```text
1. parser tous les fichiers .xml ;
2. extraire les balises avec name="..." ;
3. marquer les templates virtual="true" ;
4. indexer inherits="..." ;
5. indexer mixin="..." ;
6. enregistrer fichier + ligne + type de widget.
```

Exemples de motifs utiles :

```text
<Frame name="..." virtual="true">
<Button name="..." inherits="...">
<Frame mixin="...">
```

Ensuite, en jeu, tu peux tester certains templates :

```lua
local ok, frameOrError = pcall(CreateFrame, "Frame", nil, UIParent, "SomeTemplateName")

if ok then
  print("template ok")
else
  print("template failed", frameOrError)
end
```

Le paramètre `template` de `CreateFrame` est précisément le mécanisme par lequel on applique des templates XML existants à une frame créée en Lua ; les widgets WoW peuvent être créés en Lua ou via XML et étendus avec templates, mixins et mécanismes internes. ([Warcraft Wiki][21])

### Mixins

Pour les mixins, fais une analyse statique du code exporté :

```text
1. chercher les tables dont le nom finit par Mixin ;
2. chercher les appels Mixin(target, ...);
3. chercher CreateFromMixins(...);
4. chercher les attributs XML mixin="...";
5. relier chaque mixin aux fichiers et templates qui l’utilisent.
```

Le code exporté via `ExportInterfaceFiles code` ou les miroirs `wow-ui-source` est la bonne base, parce que les mixins sont définis dans le Lua / XML de l’interface Blizzard plutôt que dans une liste runtime unique. ([Wowpedia][14])

---

## 4. Projets similaires dans d’autres écosystèmes

## 4.1 Roblox API Dump

Roblox a une culture d’API dump beaucoup plus structurée : le projet **Roblox API Dump Tool** permet de parcourir un dump lisible de l’API Lua Roblox et de voir les changements à venir, développé en lien avec la fonctionnalité JSON API Dump de Roblox. ([GitHub][22])

Le site **ROBLOX API Reference** indique que ses pages sont générées automatiquement à partir des “API dumps” Roblox, avec classes, membres, enums, types, etc. C’est un bon modèle d’architecture cible pour ton API Explorer WoW : dump machine-readable → normalisation → site/doc humaine → diff par version. ([anaminus.github.io][23])

## 4.2 LuaLS Addons / annotations

LuaLS supporte des “addons” qui ajoutent des définitions pour un framework, une bibliothèque ou une API, avec éventuellement un plugin et des réglages. C’est un excellent format de sortie pour ton dump WoW : ton pipeline peut générer à la fois JSON brut, Markdown, et annotations LuaLS. ([luals.github.io][24])

Les annotations EmmyLua / LuaLS servent à améliorer l’autocomplétion, les signatures et la documentation dans l’éditeur, ce qui correspond exactement au besoin final d’un développeur d’add-ons WoW. ([GitHub][25])

## 4.3 LDoc / génération de documentation Lua

LDoc est un générateur de documentation Lua compatible LuaDoc, capable aussi de traiter du code source d’extensions C, avec Markdown optionnel. Ce n’est pas un dumper runtime, mais c’est une inspiration utile pour transformer des données extraites en documentation lisible. ([GitHub][26])

---

## 5. Limites et précautions

## 5.1 Fonctions cachées ou non découvrables

Un dump `_G` ne peut pas révéler les fonctions natives non exposées en Lua, ni les implémentations C/C++ du client. Il peut aussi manquer des API accessibles seulement par métatable de widget, par objets retournés, ou par modules Blizzard chargés plus tard. Les discussions d’addon authors distinguent clairement le code UI visible et les API exposées par le moteur fermé. ([WoWInterface][15])

`/api` n’est pas une garantie de complétude : il expose ce que Blizzard a documenté dans son add-on APIDocumentation, et des auteurs d’add-ons notent qu’il ne contiendra probablement jamais toutes les fonctions. ([WoWInterface][13])

## 5.2 Fonctions protected / secure / taint

Certaines fonctions ou actions existent mais ne sont pas appelables librement par un add-on standard, surtout en combat. Warcraft Wiki décrit le système de secure execution / taint comme un mécanisme destiné à imposer la décision humaine, notamment en combat, en protégeant de nombreuses fonctions contre l’usage insecure ou tainted. ([Warcraft Wiki][27])

`InCombatLockdown()` indique que les restrictions d’add-ons en combat sont actives, et la documentation mentionne que certaines modifications de macros, bindings, frames protégées, parents ou frames liées ne sont pas autorisées dans ce contexte. ([Warcraft Wiki][28])

L’événement `ADDON_ACTION_BLOCKED` se déclenche lorsqu’une fonction protégée est appelée depuis du code tainted, par exemple du code d’add-on. ([Warcraft Wiki][29])

Conclusion : ton API Explorer doit distinguer au minimum :

```text
présent dans _G
présent comme méthode de widget
documenté par APIDocumentation
appelable hors combat
appelable en combat
protected / secure / susceptible de taint
```

## 5.3 Risque de ban / ToS

Je n’ai pas trouvé d’élément indiquant qu’utiliser `ExportInterfaceFiles` ou faire de l’introspection Lua depuis un add-on normal serait interdit : `ExportInterfaceFiles` est une commande client documentée comme un moyen pratique d’extraire les fichiers d’interface pour les développeurs d’add-ons, même si Blizzard ne fournit pas de support officiel pour ces fichiers. ([Wowpedia][14])

En revanche, ne confonds pas ces pratiques avec du reverse engineering mémoire, de l’injection, du scraping de process live ou de l’automatisation externe : ton besoin peut être couvert par des mécanismes normaux d’add-on, de console client et d’extraction CDN/local sans attacher d’outil au process du jeu. Cette prudence découle du fait que le code moteur natif reste fermé et que l’API d’add-ons est volontairement sandboxée / sécurisée. ([WoWInterface][15])

## 5.4 Changements historiques de `ExportInterfaceFiles`

La documentation indique que l’ancien toolkit MPQ n’est plus supporté depuis les patches 4.0.x, et que la méthode recommandée est devenue l’usage des commandes console `ExportInterfaceFiles code` et `ExportInterfaceFiles art`. ([Wowpedia][14])

Les sources indiquent aussi une restriction pratique importante : la commande doit être lancée depuis la console au login screen ou à la sélection de personnage, pas via `/console` en jeu. ([Wowpedia][14])

---

## 6. Architecture recommandée pour ton “API Explorer Classic Era”

## 6.1 Pipeline idéal

```text
                 ┌─────────────────────────────┐
                 │ Client Classic Era 1.15.x   │
                 └──────────────┬──────────────┘
                                │
              ┌─────────────────┴─────────────────┐
              │                                   │
      runtime add-on dump                 static code export
              │                                   │
      _G / widgets / events              FrameXML / XML / mixins
              │                                   │
              └─────────────────┬─────────────────┘
                                │
                         normalisation JSON
                                │
          ┌─────────────────────┼─────────────────────┐
          │                     │                     │
      Markdown docs          LuaLS defs            version diff
          │                     │                     │
      site local          VS Code / IDE        1.15.7 vs 1.15.8
```

## 6.2 Données à produire

```text
api/
  globals.json
  widgets.json
  widget-methods.json
  events.json
  event-payload-samples.json
  templates.json
  mixins.json
  cvars.json
  frames.json
  framxml-functions.json
  build.json
  diffs/
    1.15.7-to-1.15.8.json
```

## 6.3 Format JSON minimal

```json
{
  "build": {
    "flavor": "classic_era",
    "interface": 11508,
    "clientBuild": "unknown-until-runtime-dump"
  },
  "globals": [
    {
      "name": "CreateFrame",
      "type": "function",
      "source": ["runtime:_G", "FrameXML usage"],
      "documentedByApi": false
    }
  ],
  "widgets": [
    {
      "type": "Frame",
      "creation": "CreateFrame(\"Frame\")",
      "methods": ["SetPoint", "Show", "Hide"],
      "source": ["runtime:metatable"]
    }
  ],
  "events": [
    {
      "name": "PLAYER_LOGIN",
      "source": ["runtime:RegisterAllEvents", "FrameXML:RegisterEvent"],
      "observed": true,
      "samples": []
    }
  ],
  "templates": [
    {
      "name": "SomeTemplate",
      "virtual": true,
      "inherits": [],
      "mixins": [],
      "file": "Interface/FrameXML/SomeFile.xml"
    }
  ]
}
```

## 6.4 Priorité de fiabilité des sources

Pour Classic Era 1.15.x, je classerais les sources ainsi :

1. **Dump runtime sur ton client exact** : vérité la plus forte pour `_G`, widgets, événements observés.
2. **Export `code` du client exact** : vérité forte pour FrameXML, Blizzard AddOns, XML, templates, mixins.
3. **Gethe / wow-ui-source branche `classic_era` build correspondant** : excellente source statique si tu n’as pas l’export local.
4. **KethoDoc / BlizzardInterfaceResources** : excellente base communautaire pour API/widgets/events.
5. **`/api` / Blizzard_APIDocumentation** : utile, mais incomplet.
6. **Wikis** : utiles pour explications humaines, mais pas comme source d’exhaustivité Classic Era.
7. **Anciens dumps Vanilla / Wrath / Retail** : utiles pour comparaison, mais jamais comme vérité pour Classic Era 1.15.x.

Cette hiérarchie est justifiée par le fait que KethoDoc dump explicitement les API/widgets/events depuis le client, que `wow-ui-source` suit des branches par flavor dont `classic_era`, et que `/api` est reconnu comme incomplet par des auteurs d’add-ons. ([GitHub][1])

---

## 7. Réponse courte à tes questions clés

* **Existe-t-il un projet qui fait presque exactement ça ?** Oui : **KethoDoc**, surtout pour `_G`, widgets, events, CVars, enums, frames et FrameXML. ([GitHub][1])
* **Existe-t-il des dumps Classic Era publiés ?** Oui, au moins sous forme de code UI exporté dans `Gethe/wow-ui-source` branche `classic_era`, avec des builds récents 1.15.8. Pour les dumps API runtime, il faut vérifier les branches/tags/fichiers de BlizzardInterfaceResources ou exécuter KethoDoc toi-même. ([GitHub][12])
* **`ExportInterfaceFiles code` donne-t-il toute l’API ?** Non : il donne le code UI Blizzard exportable, pas l’implémentation native complète ni toutes les fonctions globales. ([Wowpedia][14])
* **Peut-on lister les méthodes de widgets ?** Oui, via les métatables des objets widgets, typiquement `getmetatable(frame).__index`, technique confirmée par des exemples d’addon authors. ([WoWInterface][17])
* **Peut-on lister tous les événements uniquement runtime ?** Non : `RegisterAllEvents()` observe ce qui se déclenche, mais ne prouve pas la complétude ; il faut croiser APIDocumentation, FrameXML et dumps communautaires. ([Warcraft Wiki][19])
* **Risque de ban avec `ExportInterfaceFiles` ?** Je n’ai trouvé aucune source indiquant un risque pour cette commande documentée ; elle est décrite comme une commodité pour développeurs d’add-ons. Reste dans les mécanismes normaux : add-on Lua, console client, export local/CDN, pas d’injection ou de scan mémoire. ([Wowpedia][14])

[1]: https://github.com/ketho-wow/KethoDoc "GitHub - ketho-wow/KethoDoc: Dumps the WoW API · GitHub"
[2]: https://github.com/Ketho/BlizzardInterfaceResources?utm_source=chatgpt.com "Ketho/BlizzardInterfaceResources: Development resources ..."
[3]: https://github.com/Resike/BlizzardInterfaceResources "GitHub - Resike/BlizzardInterfaceResources: Global resources from World of Warcraft · GitHub"
[4]: https://github.com/Gethe/wow-ui-source "GitHub - Gethe/wow-ui-source: git mirror of the user interface source code for World of Warcraft · GitHub"
[5]: https://github.com/Gethe/InterfaceExport "GitHub - Gethe/InterfaceExport: Interface extraction tool for World of Warcraft · GitHub"
[6]: https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/AddOns/Blizzard_APIDocumentation/Blizzard_APIDocumentation.lua "BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentation/Blizzard_APIDocumentation.lua at master · tomrus88/BlizzardInterfaceCode · GitHub"
[7]: https://us.forums.blizzard.com/en/wow/t/track-all-events/294792?utm_source=chatgpt.com "Track All Events? - UI and Macro - World of Warcraft Forums"
[8]: https://www.curseforge.com/wow/addons/eventtracker?utm_source=chatgpt.com "EventTracker - World of Warcraft Addons"
[9]: https://github.com/shagu/wow-vanilla-api/blob/master/events.md "wow-vanilla-api/events.md at master · shagu/wow-vanilla-api · GitHub"
[10]: https://marketplace.visualstudio.com/items?itemName=ketho.wow-api&utm_source=chatgpt.com "WoW API"
[11]: https://github.com/wartoshika/wow-classic-declarations?utm_source=chatgpt.com "wartoshika/wow-classic-declarations: Typescript ..."
[12]: https://github.com/Gethe/wow-ui-source/tree/classic_era "GitHub - Gethe/wow-ui-source at classic_era · GitHub"
[13]: https://wowinterface.com/forums/archive/index.php/t-57551.html "How are API's discovered? [Archive]  - WoWInterface"
[14]: https://wowpedia.fandom.com/wiki/Viewing_Blizzard%27s_interface_code "Viewing Blizzard's interface code - Wowpedia - Your wiki guide to the World of Warcraft"
[15]: https://wowinterface.com/forums/showthread.php?t=55762&utm_source=chatgpt.com "viewing wow code"
[16]: https://www.wowinterface.com/forums/showthread.php?p=226783&utm_source=chatgpt.com "WoW code/artwork exporter built-in?"
[17]: https://www.wowinterface.com/forums/showthread.php?t=53928&utm_source=chatgpt.com "Frames and metatables"
[18]: https://wowwiki-archive.fandom.com/wiki/Widget_API "Widget API | WoWWiki | Fandom"
[19]: https://warcraft.wiki.gg/wiki/API_Frame_RegisterAllEvents?utm_source=chatgpt.com "Frame:RegisterAllEvents - Warcraft Wiki"
[20]: https://wowwiki-archive.fandom.com/wiki/API_Frame_RegisterAllEvents?utm_source=chatgpt.com "API Frame RegisterAllEvents | WoWWiki"
[21]: https://warcraft.wiki.gg/wiki/Widget_API?utm_source=chatgpt.com "Widget API - Warcraft Wiki"
[22]: https://github.com/MaximumADHD/Roblox-API-Dump-Tool?utm_source=chatgpt.com "MaximumADHD/Roblox-API-Dump-Tool: A tool that lets ..."
[23]: https://anaminus.github.io/api/about.html?utm_source=chatgpt.com "ROBLOX API Reference"
[24]: https://luals.github.io/wiki/addons/?utm_source=chatgpt.com "Addons"
[25]: https://github.com/LuaLS/lua-language-server/wiki/EmmyLua-Annotations/bd7c39d63156abd70cbfba54d236c861436500c5?utm_source=chatgpt.com "EmmyLua Annotations · LuaLS/lua-language-server Wiki"
[26]: https://github.com/lunarmodules/ldoc?utm_source=chatgpt.com "lunarmodules/ldoc - A Lua Documentation Tool"
[27]: https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting?utm_source=chatgpt.com "Secure Execution and Tainting - Warcraft Wiki"
[28]: https://warcraft.wiki.gg/wiki/API_InCombatLockdown?utm_source=chatgpt.com "InCombatLockdown - Warcraft Wiki"
[29]: https://warcraft.wiki.gg/wiki/ADDON_ACTION_BLOCKED?utm_source=chatgpt.com "ADDON_ACTION_BLOCKED - Warcraft Wiki"
