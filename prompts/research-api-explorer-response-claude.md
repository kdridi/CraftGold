Voici la recherche complète, en un seul bloc markdown.

---

# WoW Classic Era — Explorer & Dumper l'API Lua : recherche complète

## 1. Projets existants d'exploration/dump de l'API WoW

### 🔧 KethoDoc (addon in-game)
- **URL** : [https://github.com/ketho-wow/KethoDoc](https://github.com/ketho-wow/KethoDoc)
- **Ce qu'il dump** : Widget API, Events par système d'API, CVars et commandes console, Lua Enums, frames de top-level, et fonctions FrameXML.
- **Comment ça fonctionne** : Addon in-game. Nécessite de désactiver l'addon `Blizzard_Deprecated` (sans quoi les APIs dépréciées sont omises). Il n'est plus nécessaire de dumper les globales FrameXML séparément avec FindGlobals.
- **Distinction versions** : Oui. Un diff Classic API vs Retail est disponible sur le repo `BlizzardInterfaceResources` avec widgets, events, CVars et enums, branche `classic`. KethoDoc lui-même est plutôt orienté Retail récent ; pour Classic/Classic Era, c'est le repo de resources associé qui est la cible principale.
- **Mise à jour** : Active (commit récent sur le repo principal en 2025–2026).

### 📦 BlizzardInterfaceResources (dumps statiques versionnés)
- **URL** : [https://github.com/Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources)
- **Ce qu'il contient** : Dump depuis l'addon KethoDoc. GlobalStrings et AtlasInfo téléchargés depuis wago.tools. Templates et mixins parsés depuis FrameXML. Le repo couvre le build le plus récent de Retail.
- **Branch Classic** : [https://github.com/Ketho/BlizzardInterfaceResources/blob/classic/Resources/GlobalAPI.lua](https://github.com/Ketho/BlizzardInterfaceResources/blob/classic/Resources/GlobalAPI.lua) — contient la GlobalAPI, widgets, events, CVars et enums pour Classic.
- **Distinction versions** : Oui, branche dédiée `classic` (et historiquement `classic_era`).

### 🪞 Gethe/wow-ui-source (miroir FrameXML)
- **URL** : [https://github.com/Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source)
- **Ce qu'il contient** : Miroir git du code source de l'interface utilisateur de World of Warcraft.
- **Branches** : `classic_era` pour Classic Era, `classic` pour TBC/Wrath/Cata Classic, `live` pour Retail. [Comparaison directe classic\_era vs classic disponible.](https://github.com/Gethe/wow-ui-source/compare/classic_era...classic)
- **Comment ça marche** : Export `ExportInterfaceFiles code` suivi d'un push Git, mis à jour à chaque patch.
- **Mise à jour** : Active. Référence communautaire principale pour parcourir le FrameXML d'une version spécifique.

### 🔎 DevTool (addon d'exploration in-game)
- **URL** : [https://github.com/brittyazel/DevTool](https://github.com/brittyazel/DevTool)
- **Ce qu'il fait** : Outil multifonction pour le développement d'addons. Visualise et inspecte des tables, des events, et des appels de fonctions en runtime. Peut monitorer les events WoW de façon similaire à `/etrace`, et logger les appels de fonctions avec leurs args et valeurs de retour.
- **Limitation** : Outil visuel/interactif in-game, pas un dump exportable automatiquement.

### 🗂️ Lua Browser (backport 1.12)
- **URL** : [https://github.com/Allerias-Forge/Lua-Browser](https://github.com/Allerias-Forge/Lua-Browser)
- **Ce qu'il fait** : Backport WoW Classic (1.12) du Lua Browser addon de 3.3.5a. Permet de naviguer dans l'environnement Lua, les tables, widgets et autres valeurs. Permet de browser la metatable d'un widget sous la souris.
- **Limitation** : Orienté 1.12 (vanilla privé) ; compatibilité à vérifier sur 1.15.x Classic Era officiel.

### 📊 warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic
- **URL** : [https://warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic)
- **Ce qu'il contient** : Comparaison des fonctions globales entre Classic Era et Mists of Pandaria Classic. Mis à jour pour le patch 1.15.8 (63829). C'est actuellement la référence wiki la plus à jour pour Classic Era.

### 🛠️ wago.tools
- **URL** : [https://wago.tools](https://wago.tools)
- **Ce qu'il fait** : Collection à jour de données de jeu WoW, y compris les fichiers d'interface UI. Fichiers cherchables par build WoW, téléchargeables, comparables en ligne. Successeur de wow.tools (fermé).
- **Usage** : Télécharger le FrameXML d'un build Classic Era précis sans faire l'export soi-même.

### 🪞 tomrus88/BlizzardInterfaceCode
- **URL** : [https://github.com/tomrus88/BlizzardInterfaceCode](https://github.com/tomrus88/BlizzardInterfaceCode)
- Export brut du code produit par `ExportInterfaceFiles code`, versionné par build.

---

## 2. La commande `ExportInterfaceFiles`

### Syntaxe
```
ExportInterfaceFiles code
ExportInterfaceFiles art
```

### Accès
La commande ne fonctionne que depuis la console réelle sur l'écran de connexion ou de sélection de personnage. Elle ne peut pas être lancée via la commande slash `/console`, ni depuis la vraie console en jeu sur un personnage : la réponse sera juste "Unknown Command".

Pour accéder à la console : ajouter `-console` aux arguments de lancement (via le client Battle.net), puis appuyer sur la touche `` ` `` à l'écran de login.

### Destination des fichiers
Une fois extraits, les fichiers se trouvent dans les dossiers `BlizzardInterfaceCode` et `BlizzardInterfaceArt` dans le répertoire World of Warcraft.

Pour Classic Era spécifiquement, le chemin sera : `World of Warcraft/_classic_era_/BlizzardInterfaceCode/`

### Contenu
Le dump `code` contient les fichiers `.lua` et `.xml` qui composent l'UI Blizzard (FrameXML, AddOns Blizzard intégrés). C'est le **code de l'UI par défaut**, pas une liste exhaustive de toutes les fonctions C natives exposées. Les fonctions natives (celles enregistrées côté C++ du moteur) n'apparaissent pas dans ce dump — elles sont simplement *appelées* par le code FrameXML.

### `ExportInterfaceFiles art`
La commande `exportInterfaceFiles art` existe également. L'export art peut prendre un temps considérable, et requiert au minimum (depuis 8.2) 2,8 Go d'espace disque. Elle exporte les textures et assets graphiques (.blp, etc.) — pas utile pour l'exploration API.

### Fonctionnement sur Classic Era 1.15.x
Oui, la commande fonctionne sur Classic Era. Le miroir de référence [Gethe/wow-ui-source branche `classic_era`](https://github.com/Gethe/wow-ui-source/tree/classic_era) est entretenu précisément à partir de cet export sur le client Classic Era.

---

## 3. Méthodologie : dumper l'API depuis Lua in-game

### 3a. Dump des globales `_G`

```lua
for k, v in pairs(_G) do print(k, type(v)) end
```

Cela liste l'ensemble des variables globales Lua visibles depuis l'environnement addon. **Mais attention** : les fonctions C natives enregistrées par le moteur WoW sont bien dans `_G` et apparaîtront. En revanche :

- Les fonctions qui existent côté C mais ne sont pas exportées dans l'env Lua (très rare mais possible pour des fonctions internes) ne seront pas visibles.
- Les fonctions ajoutées dynamiquement après le chargement (ex. : lazy-loaded) peuvent être manquantes si le dump tourne trop tôt.
- Pour distinguer les fonctions WoW des fonctions Lua standard (`pairs`, `ipairs`, `type`…), comparer avec la liste des globales Lua 5.1 standard (WoW utilise une VM Lua 5.1 modifiée).

Le projet KethoDoc utilise précisément cette approche complétée par l'API interne `GetAPIDocumentation()` disponible en Retail (moins accessible en Classic Era), et l'exploration des metatables de widgets.

### 3b. Exploration des méthodes de widget

Les widgets WoW (Frame, Button, Texture…) sont des userdata C++ dont les méthodes sont exposées via metatable. Pour inspecter :

```lua
local f = CreateFrame("Frame")
local mt = getmetatable(f)
-- mt.__index contient la table des méthodes
for k, v in pairs(mt.__index) do print(k, type(v)) end
```

La liste des fonctions de Widget API a été obtenue en scannant l'environnement in-game. C'est exactement cette technique (`getmetatable(frame).__index`) que les projets comme KethoDoc utilisent pour lister les méthodes par type de widget.

Note importante : en Classic Era, `getmetatable()` sur un widget peut retourner `nil` selon la version, car Blizzard protège parfois ces accès. Sur les builds récents de Classic Era (1.15.x), l'accès est généralement possible hors combat.

### 3c. Événements

Il n'existe pas de fonction Lua native pour lister tous les events disponibles côté moteur. Les approches possibles :

1. **`BlizzardInterfaceResources`** : le fichier `Resources/Events.lua` du repo Ketho (branche `classic`) contient la liste complète des events dumpés pour Classic.
   → [https://github.com/Resike/BlizzardInterfaceResources/blob/master/Resources/Events.lua](https://github.com/Resike/BlizzardInterfaceResources/blob/master/Resources/Events.lua)

2. **`/etrace`** : commande in-game qui monitore les events en temps réel. DevTool intègre une fonctionnalité similaire.

3. **Parsing du FrameXML** : les fichiers `Blizzard_APIDocumentation/*.lua` dans le dump ExportInterfaceFiles contiennent des déclarations structurées d'events avec leurs arguments (disponibles en Retail depuis 8.x, partiellement en Classic Era moderne).

### 3d. Templates et Mixins

Les templates et mixins sont parsés depuis FrameXML dans le repo BlizzardInterfaceResources.

Pour les lister manuellement :
- **Templates XML** : définis dans les fichiers `.xml` du FrameXML, avec l'attribut `name` sur un élément `<Frame>` sans parent. Grep `virtual="true"` dans le dump ExportInterfaceFiles.
- **Mixins** : fonctions Lua de la forme `MonNomMixin = {}` définies dans les fichiers `.lua` du FrameXML. Grep `Mixin = {}` dans le dump.

---

## 4. Projets similaires dans d'autres écosystèmes

- **Lua introspection générique** : les techniques `pairs(_G)`, `getmetatable`, `debug.getinfo` sont standard en Lua 5.1+. La bibliothèque `debug` est **partiellement désactivée** dans le sandbox WoW (pas de `debug.sethook`, `debug.getlocal`, etc.).
- **Other MMO modding** : ESO (Elder Scrolls Online) expose une API Lua documentée officiellement et dispose d'outils similaires. FFXIV utilise un modèle différent (Dalamud/.NET). WoW reste parmi les plus ouverts à l'introspection in-game via Lua.
- **TypeScript declarations** : le projet [wartoshika/wow-declarations](https://github.com/wartoshika/wow-declarations) fournit des types TypeScript pour l'API WoW, généré depuis ces mêmes dumps.

---

## 5. Limites et précautions

### APIs cachées / non découvrables

Certaines fonctions C internes du moteur ne sont délibérément pas enregistrées dans l'environnement Lua addon. En pratique, tout ce qui est accessible à un addon est dans `_G` ou accessible via les metatables de widgets. Il n'existe pas de "couche cachée" accessible à FrameXML mais pas aux addons, sauf via les addons signés Blizzard (qui peuvent appeler des fonctions PROTECTED).

### Taint et fonctions PROTECTED

Quand WoW commence l'exécution du code Lua, l'exécution démarre en mode "secure". Elle reste sécurisée jusqu'à ce qu'elle rencontre du "taint" — un indicateur qu'une fonction ou un objet provient d'une source non fiable (AddOn ou /script). L'exécution devient "taintée" dès qu'elle lit des données ou du code introduit par un tiers, et toute nouvelle donnée écrite par une exécution taintée devient elle-même taintée. Les fonctions protégées refusent d'opérer si le chemin d'exécution n'est pas sécurisé.

Les APIs qui ne peuvent pas être appelées par du code insécure déclenchent `ADDON_ACTION_FORBIDDEN`. Celles qui nécessitent un event hardware (clic utilisateur) déclenchent `ADDON_ACTION_BLOCKED`. Les APIs qui ne peuvent pas être appelées en combat déclenchent également `ADDON_ACTION_BLOCKED`.

En Classic Era (pre-2.0 gameplay), le système de taint existe dans le client 1.15.x mais est moins élaboré que Retail — certaines restrictions NOCOMBAT ne s'appliquent pas. L'introspection `_G` et des metatables est safe tant qu'on ne *modifie* pas de variables sécurisées.

### Risques ToS / ban

`ExportInterfaceFiles` est une **commande officielle** fournie par Blizzard pour les développeurs d'addons. Son usage est explicitement autorisé. Explorer l'API via `pairs(_G)` ou `getmetatable` est de l'introspection Lua standard, parfaitement légal au regard des ToS. Il n'y a pas d'antécédents de ban pour cette pratique. La limite ToS concerne l'automation et le botting, pas l'exploration de l'API.

### Historique de la commande ExportInterfaceFiles

Blizzard n'a jamais supprimé ni restreint `ExportInterfaceFiles`. Elle a été ajoutée progressivement et reste disponible sur tous les clients actifs (Retail, Classic Era, Cata Classic…). La seule restriction documentée est qu'elle ne fonctionne qu'à l'écran de login/sélection de personnage, pas en jeu.

---

## Récapitulatif des URLs clés

| Ressource | URL |
|-----------|-----|
| KethoDoc (addon dump) | https://github.com/ketho-wow/KethoDoc |
| BlizzardInterfaceResources (dumps branche classic) | https://github.com/Ketho/BlizzardInterfaceResources/tree/classic |
| GlobalAPI.lua Classic | https://github.com/Ketho/BlizzardInterfaceResources/blob/classic/Resources/GlobalAPI.lua |
| Gethe wow-ui-source (classic_era branch) | https://github.com/Gethe/wow-ui-source/tree/classic_era |
| DevTool (explorateur in-game) | https://github.com/brittyazel/DevTool |
| Lua Browser (backport 1.12) | https://github.com/Allerias-Forge/Lua-Browser |
| warcraft.wiki.gg API/Classic | https://warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic |
| wago.tools | https://wago.tools |
| ExportInterfaceFiles (doc wiki) | https://warcraft.wiki.gg/wiki/Viewing_Blizzard's_interface_code |
| Secure Execution & Tainting | https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting |