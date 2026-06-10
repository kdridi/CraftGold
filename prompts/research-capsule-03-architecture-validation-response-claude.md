Voici la synthèse de mes recherches. J'ai pu vérifier la plupart de vos questions sur des sources primaires (dépôts GitHub des add-ons, wikis communautaires, docs d'outillage).

---

## 1. Frameworks et outils de test pour add-ons WoW

Il existe deux familles d'outils : les tests **in-game** et les tests **hors du jeu** (votre approche).

**In-game :**
- **WoWUnit** (Feithar) : framework de tests exécutés dans le client via `/wowunit <suite>`. Les suites contiennent des tests, des fonctions setUp/tearDown optionnelles, et une table `mocks` qui définit les fonctions et variables globales à remplacer pendant les tests — ce qui permet de simuler les appels à l'API WoW. Source : https://www.wowace.com/projects/wowunit et https://www.curseforge.com/wow/addons/wowunit. Notez que le projet date de ~2014.
- **wowUnit** (Mirroar) : conçu pour être facile à mettre en place sans intrusion dans le code de l'add-on — on déclare une table de tests et on lance une commande slash. Source : https://github.com/Mirroar/wowUnit
- **QhunUnitTest** : framework orienté objet qui reprend les patterns de tests unitaires de langages comme Java ou TypeScript, avec enregistrement de suites et commande `/test`. Source : https://github.com/wartoshika/wow-QhunUnitTest

**Hors du jeu (votre famille) :**
- **busted** : le framework de test Lua standard, compatible Lua 5.1 (la version du client WoW), avec describe/it, une lib d'assertions extensible, des sorties TAP/JSON pour la CI, et une GitHub Action officielle. Sources : https://github.com/lunarmodules/busted, https://github.com/marketplace/actions/lua-busted
- **wowmock** (Adirelle) : c'est *littéralement votre pattern*, packagé. wowmock charge un fichier Lua dans un environnement contrôlé via `setfenv`, avec un mock des globales et un sous-ensemble de fonctions WoW ; on lui passe le nom de l'addon et une table « privée » (le ns), qui peut elle-même être un mock. Source : https://github.com/Adirelle/wowmock
- **wowless** : projet plus ambitieux — un interpréteur headless du Lua et du FrameXML du client WoW, destiné au test d'add-ons, encore en pré-alpha mais en développement actif. Sources : https://github.com/wowless/wowless, https://wowless.dev/
- **wow-ui-sim** (Osso) : un simulateur d'UI WoW qui charge et rend les add-ons hors du jeu, supporte des workflows de test headless avec sortie d'arbre de frames et de captures d'écran, fournit une GitHub Action versionnée par version d'interface, et attend les tests dans `Interface/AddOns/MyAddon/tests/*.lua` avec une fonction `test(...)` et `assertEquals`. Source : https://github.com/Osso/wow-ui-sim (exemple minimal : Osso/test-wow-addon).

**CI/CD :** le standard communautaire est **luacheck** (lint) + **busted** (tests) + **BigWigs packager** (release). release.sh du packager BigWigs construit le zip depuis un checkout Git, embarque les bibliothèques externes, et peut publier sur CurseForge, WoWInterface, Wago et GitHub Releases ; il existe une GitHub Action `BigWigsMods/packager@v2` qui peut même générer automatiquement les .toc par version du jeu (Vanilla, Wrath, retail). Sources : https://github.com/BigWigsMods/packager, https://wowpedia.fandom.com/wiki/Using_the_BigWigs_Packager_with_GitHub_Actions

En pratique, la majorité des devs d'add-ons testent encore à la main en jeu (`/reload` + `/console scriptErrors 1`), mais les gros projets sérieux ont convergé vers busted + luacheck + GitHub Actions.

## 2. Architecture des add-ons populaires

**Questie** — la référence en matière de tests. Le projet utilise luacheck pour le lint (`luacheck -q Database Localization Modules Questie.lua`), busted pour les tests (`busted -p ".test.lua" .` à la racine), avec la convention de nommer les tests `<module>.test.lua` et de les placer à côté du module testé ; il y a en plus des scripts de validation de la base de données par extension (`lua cli/validate-<expansion>.lua`). Le cœur du dispositif est un fichier `setupTests.lua` qui mocke l'environnement global : il installe un faux `LibStub` (avec metatable `__call`), un faux objet global `Questie` (avec `db.char/profile/global`, `Print`/`Debug` en no-op, `RegisterEvent`/`UnregisterEvent` qui stockent les callbacks dans une table `registeredEvents`), et des mocks de frames. Sources : https://github.com/Questie/Questie et https://github.com/Questie/Questie/blob/master/setupTests.lua. C'est exactement la philosophie de votre `WoW.init({})`, mais en mockant `_G` directement plutôt qu'à travers un seam.

**DBM** — architecture par plugins. Le design est modulaire : chaque boss mod est un plugin échangeable et mis à jour séparément, et les mods sont des AddOns distincts chargés à la demande (load on demand) — ils ne consomment ni mémoire ni CPU tant qu'on n'entre pas dans l'instance correspondante. Pas de tests unitaires ; la nature du code (réaction à des événements de combat en temps réel) rend le test hors-jeu peu rentable, et le projet s'appuie sur des testeurs alpha. Source : https://www.curseforge.com/wow/addons/deadly-boss-mods

**WeakAuras** — le plus proche de vos conventions. Chaque fichier commence par le même prélude : `local AddonName = ...` puis `local Private = select(2, ...)` avec une annotation `---@class Private`, suivi d'un bloc « Lua APIs » et d'un bloc « WoW APIs » où les fonctions globales sont mises en cache dans des locales (`local UnitClass = UnitClass`, etc.). Donc : le vararg `ns` (renommé `Private`), des annotations LuaLS pour l'outillage, et une *séparation visuelle explicite* entre Lua pur et API WoW en tête de fichier — un seam léger par convention plutôt que par injection. L'addon est aussi scindé en deux : le runtime (`WeakAuras`) et les options (`WeakAurasOptions`, chargé à la demande). Les gros fichiers documentent leur API publique en commentaire d'en-tête (ex. Transmission.lua liste DisplayToString, Import, etc.). Leur CI GitHub Actions fait du lint/packaging, pas de tests unitaires systématiques. Sources : https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/WeakAuras.lua, https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Prototypes.lua

**Auctionator** (TheMouseNest) — code organisé en dossiers `Source/` par feature, avec variantes par flavor. Le `.pkgmeta` exclut du package final `test-data`, `scripts`, `DB2_Scripts` et `annotations.lua`, et copie les dossiers `Source`, `*Mainline`, `*Classic`, `*Vanilla` — donc des données de test et des annotations LuaLS existent dans le repo mais ne sont jamais livrées au joueur. Source : https://github.com/TheMouseNest/Auctionator/blob/master/.pkgmeta

**Leatrix Plus** — le contre-exemple assumé : un fichier monolithique. Le fichier s'ouvre sur un sommaire en commentaires (01:Functions, 20:Live, 50:RunOnce, 60:Events, 80:Commands, 90:Panel...), crée la table globale `LeaPlusDB` pour les SavedVariables, des tables locales (`LeaPlusLC`, `LeaPlusCB`...), récupère la locale via le vararg (`local void, Leatrix_Plus = ...`), puis crée une frame d'événements enregistrée sur ADDON_LOADED, PLAYER_LOGIN et PLAYER_ENTERING_WORLD. Zéro test, zéro module — et pourtant des dizaines de millions de téléchargements. Source : https://github.com/Naurplay/NaurClassicAddons/blob/master/Leatrix_Plus/Leatrix_Plus.lua

## 3. Dependency injection en Lua WoW

Votre pattern de seam **existe bien dans la nature**, sous plusieurs formes :

- **wowmock** en est la version la plus formelle : injection de l'environnement global complet via `setfenv` au chargement du fichier (DI « par environnement » plutôt que « par module »). C'est plus radical que votre `WoW.init(env)` mais le même principe.
- **WeakAuras** pratique une version implicite : le cache de globales en tête de fichier (`local UnitClass = UnitClass`) crée un point unique par fichier où l'API WoW entre — motivé par la performance, mais qui sert aussi de seam documentaire.
- Le blog *Good Design in Warcraft Addons* d'Andy Dote décrit exactement votre idée : un fichier d'initialisation copie les dépendances externes dans `ns.lib`, ce qui économise des lookups globaux mais crée surtout un point d'abstraction — pour remplacer le système d'événements, il suffit d'assigner le remplaçant à `ns.lib.events` tant qu'il a les bonnes fonctions. Source : https://andydote.co.uk/2014/11/23/good-design-in-warcraft-addons/

**LibStub et Ace3** ne font pas de DI au sens strict. LibStub est un registre versionné de bibliothèques (`LibStub:NewLibrary(MAJOR, MINOR)`) — un *service locator*, pas un conteneur d'injection. Ace3 fonctionne par mixins : `NewAddon("MyAddon", "AceConsole-3.0")` copie les méthodes de la bibliothèque dans votre objet addon, et AceAddon fournit un système de modules (`MyAddon:NewModule`, `SetDefaultModuleLibraries`, `SetDefaultModulePrototype`, `IterateModules`) avec cycle de vie OnInitialize/OnEnable/OnDisable. On peut remplacer une lib dans LibStub en enregistrant une version « plus récente » (c'est ainsi que certains mocks s'injectent), mais ce n'est pas son but. Il n'existe **aucun conteneur DI** établi dans l'écosystème — et personne n'en réclame : la communauté préfère les seams ad hoc (table `ns`, cache de locales, mock de `_G` en test). Sources : https://www.wowace.com/projects/ace3/pages/api/ace-addon-3-0, https://warcraft.wiki.gg/wiki/WelcomeHome:_Your_first_Ace3_Addon

## 4. Le namespace `ns`

C'est un mécanisme **officiel du jeu**, pas une invention. Le namespace d'addon est une table privée partagée entre les fichiers Lua d'un même addon, qui permet d'échanger des données entre fichiers sans polluer l'environnement global ; il a été ajouté au patch 3.3.0 (2009). Le tutoriel officiel du wiki (« Create a WoW AddOn in 15 Minutes ») l'enseigne comme pratique de base, avec la convention du `_` pour ignorer le nom de l'addon. Sources : https://wowpedia.fandom.com/wiki/Using_the_AddOn_namespace, https://warcraft.wiki.gg/wiki/Create_a_WoW_AddOn_in_15_Minutes

Conventions de nommage observées : `ns` (le plus courant), `addonTable`, `Private` (WeakAuras, avec `select(2, ...)`), ou le nom de l'addon lui-même (Leatrix utilise `local void, Leatrix_Plus = ...`). Les addons Ace3 utilisent souvent les **deux** : l'objet AceAddon comme API publique/cycle de vie, et `ns` pour les données partagées entre fichiers. Important pour Classic Era : le vararg fonctionne identiquement sur tous les flavors, donc votre choix est portable.

## 5. Bonnes pratiques communautaires

Synthèse de ce qui fait consensus (wiki, blogs de devs, pratiques des gros repos) :

- **Structure** : pour 500-2000 lignes, un fichier par responsabilité listé en ordre de dépendance dans le `.toc` + namespace `ns` est la norme. Andy Dote recommande de faire correspondre les sous-namespaces aux dossiers, à la manière des développeurs C#.
- **Séparation logique/UI** : le pattern dominant est celui de WeakAuras et Auctionator — logique dans des modules sans référence aux frames, UI dans des fichiers dédiés (voire un addon Options séparé en load-on-demand).
- **SavedVariables** : soit `AceDB-3.0` (`self.db = LibStub("AceDB-3.0"):New("MyDB")` dans OnInitialize, avec les types profile/char/global — source : https://www.wowace.com/projects/ace3/pages/ace-db-3-0-tutorial), soit à la main : initialiser `MyDB = MyDB or {}` sur ADDON_LOADED et fusionner avec une table de defaults. Votre shell qui isole les SavedVars est conforme.
- **Qualité** : luacheck avec un `.luacheckrc` déclarant les globales WoW est quasi universel chez les projets GitHub sérieux ; les annotations LuaLS (`---@class`, `---@type`) se généralisent (WeakAuras, Questie, Auctionator les utilisent).
- **Release** : tags Git annotés + BigWigs packager en GitHub Actions.

## 6. Exemples de code testé

**Questie** (le meilleur exemple WoW) — l'amorçage des tests reconstitué d'après `setupTests.lua` :

```lua
-- setupTests.lua (schéma, simplifié)
_G.LibStub = { GetLibrary = function() return {} end }
setmetatable(_G.LibStub, { __call = function() return { Fetch = function() return "Font" end } end })

local registeredEvents = {}
_G["Questie"] = {
  db = { char = {}, profile = {}, global = {} },
  Print = function() end,
  Debug = function() end,
  RegisterEvent = function(_, name, cb) registeredEvents[name] = cb end,
  UnregisterEvent = function(_, name) registeredEvents[name] = nil end,
}
```
Puis chaque module a son `Module.test.lua` voisin, lancé par `busted -p ".test.lua" .`. Sources : https://github.com/Questie/Questie/blob/master/setupTests.lua, https://github.com/Questie/Questie

**wowmock** — chargement d'un fichier d'addon avec environnement et ns injectés :

```lua
-- schéma d'après le README de wowmock
local globals = mockagne:getMock()
local addon = mockagne:getMock()
wowmock("FileToTest.lua", globals, "MyAddon", addon)  -- env, addonName, ns
when(globals.UnitSpeed("player")).thenAnswer(7)
```
Source : https://github.com/Adirelle/wowmock

**wow-ui-sim** — tests d'intégration headless avec vraies frames :

```lua
-- Interface/AddOns/MyAddon/tests/frame.lua
test("frame name matches", function()
  local f = CreateFrame("Frame", "MyFrame")
  assertEquals("MyFrame", f:GetName())
end)
```
Exécutable via Docker (`ghcr.io/osso/wow-ui-sim run-tests MyAddon`) ou en GitHub Action. Source : https://github.com/Osso/wow-ui-sim

---

## Synthèse : évaluation de votre architecture

**Ce qui est bien.** Votre socle est validé par les meilleures pratiques observées. Le namespace `ns` via vararg est le mécanisme officiel et standard depuis 2009. Le chargement par `loadfile()` + vararg simulé est exactement ce que fait wowmock (qui y ajoute `setfenv`), et le mock d'environnement est ce que fait Questie dans `setupTests.lua`. Le Functional Core / Imperative Shell correspond à ce que WeakAuras et Auctionator font implicitement (logique pure d'un côté, frames de l'autre). Un runner maison sans dépendance est un choix défendable pour du « Lua brut » — c'est le seul point où vous divergez du standard de facto (busted).

**Ce qui pourrait être amélioré.**

1. *Le pattern `WoW.init` a un défaut subtil.* Avec `WoW.print = env.print or WoW.print`, un second `init` ne peut jamais *restaurer* le fallback, et l'état est mutable globalement entre tests. Préférez reconstruire la table à chaque init, en partant des fallbacks purs :

```lua
local defaults = {
  wipe = function(t) for k in pairs(t) do t[k] = nil end end,
  print = print,
}
function WoW.init(env)
  for k, v in pairs(defaults) do WoW[k] = env[k] or v end
end
```

2. *N'injectez que l'impur.* `wipe` est implémentable en Lua pur — il n'a pas besoin d'être dans le seam au même titre que `print`, `GetTime`, `CreateFrame` ou les SavedVars. Réservez `WoW.lua` aux effets de bord réels ; mettre des utilitaires purs dedans dilue le concept et grossit les mocks pour rien. C'est le piège que Questie évite en ne mockant que ce qui touche `_G`.

3. *Adoptez la convention Questie pour les tests* : `Core.test.lua` à côté de `Core.lua` (ou gardez `tests/`, les deux existent), et envisagez busted si un jour vous voulez `describe/it`, les spies et la sortie TAP gratuite — votre code de test resterait du Lua brut, seul le runner change.

4. *Ajoutez luacheck + CI.* C'est le quasi-consensus : un `.luacheckrc` avec les globales WoW, et un workflow GitHub Actions qui enchaîne luacheck → tests → (au tag) BigWigs packager. Coût : ~30 lignes de YAML.

5. *Pour les tests d'intégration* (frames, events, slash), regardez wow-ui-sim ou wowless plutôt que d'étendre vos mocks à la main — mocker fidèlement `CreateFrame` est un puits sans fond, et ces projets existent précisément pour ça.

**Ce qui est over-engineered.** Pour 500-2000 lignes : rien de rédhibitoire, mais soyez vigilants sur deux points. D'abord, ne cherchez pas de conteneur DI ni de mécanisme de remplacement via LibStub — l'écosystème n'en a pas et votre seam unique suffit largement. Ensuite, ne laissez pas `WoW.lua` devenir un wrapper exhaustif de l'API : Leatrix Plus prouve qu'un addon massivement populaire peut vivre sans aucune abstraction ; la valeur de votre seam est sa *petitesse*. Si une fonction WoW n'est appelée que par le shell (jamais par le core), elle n'a pas besoin de passer par le seam. Enfin, un détail de perf idiomatique : en jeu, les gros addons cachent les fonctions dans des locales en tête de fichier (style WeakAuras) ; un appel `WoW.print(...)` (lookup de table) est négligeable pour votre taille, mais si un module pur devient chaud, `local print_ = ns.WoW.print` en tête de fichier est la forme communautaire.

**Mes 5 recommandations concrètes**, par ordre de rendement : (1) corriger `WoW.init` pour reconstruire depuis des defaults immuables, (2) sortir les utilitaires purs du seam, (3) ajouter luacheck avec un `.luacheckrc` WoW, (4) monter une CI GitHub Actions (lint + tests, packager au tag), (5) garder votre runner maison tant qu'il fait moins de ~100 lignes, et basculer sur busted le jour où vous voulez des mocks/spies sérieux — la migration sera triviale puisque vos modules se chargent déjà hors du jeu.