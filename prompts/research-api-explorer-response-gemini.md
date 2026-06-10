Voici une synthèse complète et technique pour vous permettre de cartographier, explorer et dumper systématiquement l'API Lua de World of Warcraft Classic Era (1.15.x / Interface 11508).

---

## 1. Projets existants d'exploration/dump de l'API WoW

Il existe plusieurs projets communautaires de référence pour suivre les modifications de l'API, visualiser les arborescences de tables ou consulter des dumps statiques.

### Wago.tools & Townlong Yak

* **URL du projet** : [wago.tools](https://wago.tools) et [Townlong Yak](https://www.google.com/search?q=https://www.townlong-yak.com/framexml)
* **Ce qu'il dump** : L'intégralité du code de l'interface utilisateur de Blizzard (`FrameXML`), les bases de données clients (`DB2`), l'art (`Textures`), et l'historique complet des fonctions globales (`GlobalAPI`).
* **Comment il fonctionne** : Extraction directe des données à partir des serveurs CDN de Blizzard et parsing des fichiers binaires du jeu.
* **Dernière mise à jour connue** : Continu, mis à jour à chaque déploiement de patch par Blizzard (incluant Classic Era 1.15.x).
* **Distinction des versions** : Oui, un menu déroulant permet de filtrer strictement par version de build (`Retail`, `Classic Whitehead`, `Classic Era`).

### Ketho's WoW-API (GitHub)

* **URL du projet** : [GitHub - Ketho/wow-api](https://www.google.com/search?q=https://github.com/Ketho/wow-api)
* **Ce qu'il dump** : Listes exhaustives des fonctions globales, constantes du jeu, énumérations de l'API et événements de manière brute (`JSON` / `Lua`).
* **Comment il fonctionne** : À l'aide d'addons in-game automatisés couplés à des scripts d'intégration continue qui extraient et structurent les données générées.
* **Dernière mise à jour connue** : Régulièrement mis à jour au fil des patchs majeurs.
* **Distinction des versions** : Oui, le projet sépare explicitement ses branches et dossiers par types de clients (`live`, `classic`, `classic_era`).

### DevTool (Addon In-game)

* **URL du projet** : [GitHub - brittyazel/DevTool](https://github.com/brittyazel/DevTool)
* **Ce qu'il dump** : Variables globales, tables d'addons, événements levés à l'écran en temps réel.
* **Comment il fonctionne** : Un explorateur graphique in-game écrit entièrement en Lua. Il permet de naviguer dans l'environnement d'exécution de `_G`.
* **Dernière mise à jour connue** : Compatible avec les versions contemporaines de l'API.
* **Distinction des versions** : Il s'adapte dynamiquement au client sur lequel il est lancé en introspectant l'environnement Lua vivant.

### Gethe's wow-ui-source

* **URL du projet** : [GitHub - Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source)
* **Ce qu'il dump** : L'arborescence complète du code source Lua/XML officiel de l'UI Blizzard.
* **Comment il fonctionne** : Extraction automatisée des builds et push automatique sur GitHub avec diffs lisibles.
* **Distinction des versions** : Gère des branches distinctes pour `live`, `classic` et `classic_era`.

---

## 2. La commande `/console ExportInterfaceFiles`

La commande d'exportation native de Blizzard reste la méthode la plus propre pour récupérer le code source brut de l'UI.

```text
exportInterfaceFiles code
exportInterfaceFiles art

```

* **Où les fichiers sont-ils dumpés ?** Les fichiers sont générés à la racine de votre installation de jeu, dans un sous-dossier dédié. Pour Classic Era, le chemin exact est :
`World of Warcraft/_classic_era_/BlizzardInterfaceCode/` (pour le code)
`World of Warcraft/_classic_era_/BlizzardInterfaceArt/` (pour l'art)
* **Contenu exact généré** :
La commande `code` extrait l'arborescence complète de l'UI Blizzard : fichiers `.lua` (logique), `.xml` (dispositions graphiques et templates) et fichiers `.toc` (tables des matières des modules de l'interface).
* **Fonctionnement en Classic Era 1.15.x** :
**Oui**, cette commande fonctionne parfaitement sur le client Classic Era. Cependant, il y a une contrainte majeure : elle **ne fonctionne pas** via le chat en jeu (elle renverra une erreur de commande inconnue). Vous devez impérativement l'exécuter depuis la console de développement (déclenchable via la touche `²` ou `~` après avoir ajouté l'argument de lancement `-console` sur l'application Battle.net), et ce, uniquement sur **l'écran de sélection des personnages** ou sur l'écran de connexion ([Source : Wowpedia](https://wowpedia.fandom.com/wiki/Viewing_Blizzard%27s_interface_code)).
* **Volume de fichiers générés** :
Pour la commande `code`, cela génère environ **1 500 à 2 500 fichiers** organisés en sous-dossiers thématiques (`Interface/FrameXML`, `Interface/AddOns/Blizzard_SharedXML`, etc.).
* **Étendue des fonctions incluses** :
**Non**, vous n'y trouverez pas la définition de *toutes* les fonctions de l'API. Cette commande n'extrait que le code écrit en Lua/XML par Blizzard pour concevoir l'interface utilisateur. Les fonctions fondamentales du moteur (ex: `UnitHealth()`, `CastSpellByName()`) sont implémentées en C++ à l'intérieur du binaire du client de jeu et ne possèdent pas de code source Lua visible. Elles y sont simplement consommées.
* **La commande `exportInterfaceFiles art**` :
Elle extrait l'intégralité des textures, icônes et composants visuels natifs du jeu au format propriétaire `.blp` (Blizzard Texture). Pour les manipuler ou les lire en dehors du jeu, un convertisseur tiers (comme BLPNG Converter) est requis ([Source : Reddit WowUI](https://www.reddit.com/r/WowUI/comments/1ohjjcl/other_are_there_any_sourcesdocumentation_for_how/)).

---

## 3. Méthodologie : comment dumper l'API depuis Lua in-game

### 3a. Dump des globales

Le parcours de `_G` est le point de départ classique, mais il possède des spécificités dans WoW :

* **Est-ce que cela liste TOUTES les fonctions ?** Oui et non. Cela listera toutes les fonctions enregistrées dans l'environnement global au moment de l'exécution. Cependant, beaucoup d'API modernes de WoW sont encapsulées dans des namespaces (tables de sous-systèmes comme `C_Timer`, `C_Item`, `C_Container`). Un scan plat ratera le contenu interne de ces tables.
* **Y a-t-il des globales absentes de `_G` ?** Dans les versions récentes du moteur de WoW (dont la base 1.15.x hérite), l'environnement global d'un addon utilise un mécanisme de méta-table pour la sécurité. Certaines fonctions injectées par le moteur C++ peuvent ne pas apparaître immédiatement lors d'un `pairs(_G)` tant qu'elles n'ont pas été lues ou initialisées par le code de l'UI.
* **Distinguer l'API WoW de l'API Lua standard** :
Vous pouvez exclure explicitement les tables natives de la spécification Lua 5.1/5.2 (`math`, `string`, `table`, `coroutine`, `pairs`, `ipairs`, etc.). Tout le reste appartient soit à l'environnement d'addons tiers chargés, soit au framework C++/Lua de Blizzard.

### 3b. Exploration des méthodes de widget

Les éléments d'interface (Frames, Buttons) créés par le moteur C++ n'exposent pas leurs méthodes via une méta-table Lua traditionnelle accessible par `getmetatable(frame).__index`. Le moteur WoW utilise des structures internes (Userdata enveloppés).

Pour inspecter les méthodes valides d'un type de widget, les outils de dump procèdent par **introspection dynamique forcée** :

1. Ils créent un widget vierge de chaque type via l'API d'usine :
```lua
local frame = CreateFrame("Frame")
local button = CreateFrame("Button")

```


2. Bien que `getmetatable(frame)` soit protégé ou opaque, les clés de méthodes sont accessibles en itérant directement sur l'objet ou en exploitant les prototypes du système d'UI si exposés.
3. Pour lister exhaustivement ce qui est disponible, la technique communautaire consiste à utiliser un script d'introspection qui teste la présence de fonctions courantes ou qui extrait l'index de l'objet via les wrappers de l'UIObject globale du client ([Source : WoWWiki Widget API](https://wowwiki-archive.fandom.com/wiki/Widget_API)).

### 3c. Événements

Il n'existe aucune table Lua in-game regroupant nativement la liste de tous les chaînages de caractères valides pour les événements (ex: `"PLAYER_ENTERING_WORLD"`).

* **Découverte dynamique** : La méthode absolue consiste à créer une frame de monitoring globale qui s'enregistre à tous les événements possibles en interceptant les appels via le système `/etrace` (Event Trace) intégré par Blizzard, ou en parsant le binaire du jeu hors-ligne pour en extraire les chaînes de caractères brutes.

### 3d. Templates et Mixins

* **Templates XML** : Ils sont stockés au niveau de la couche C++ lors du chargement de l'UI. Il est impossible de lister les templates XML existants via une boucle purement Lua in-game. La seule méthode viable est d'analyser le dump de fichiers généré par `exportInterfaceFiles code` à l'aide d'un script externe (Python/Grep) à la recherche de l'attribut `virtual="true"`.
* **Mixins** : Contrairement aux templates XML, les Mixins sont de pures structures de POO implémentées en Lua par Blizzard (ex: `BackpackTokenMixin`). Comme ce sont des tables globales, elles peuvent être identifiées dans `_G` en appliquant un filtre par expression régulière sur leur nom (recherche du suffixe `Mixin`).

---

## 4. Projets similaires dans d'autres écosystèmes

L'ingénierie inverse et la documentation d'API Lua non documentées se retrouvent dans d'autres jeux :

* **Elder Scrolls Online (ESO)** : Utilise un système d'extraction d'API complet très proche de WoW via des commandes internes comme `/script d(GetAPI())` et maintient un dépôt public de son code d'interface complet (ESOUIDocumentation).
* **Roblox** : L'écosystème Roblox maintient des outils de dump automatique de l'API (comme le projet *Roblox API Dump*) mis à jour à chaque version du client pour générer des fichiers de typage auto-complétés pour les éditeurs de code externes.
* **Luvit / Neovim** : Les développeurs utilisent intensément l'introspection via des bibliothèques comme `inspect.lua` pour cartographier les tables de fonctions C bindées en Lua à la volée.

---

## 5. Limites et précautions

* **Fonctions cachées / C++ pures** : De nombreuses API privées de Blizzard (notamment celles liées aux fonctionnalités de la boutique, à la modération ou aux interactions de bas niveau avec le système d'exploitation) sont volontairement protégées contre toute tentative d'itération et d'appel via le code d'un addon tiers.
* **Risques de suspension/Ban** : L'utilisation de la commande `/console exportInterfaceFiles` est une fonctionnalité **officiellement intégrée par Blizzard** pour les développeurs d'addons. Son utilisation est 100% légale et ne viole pas les Conditions d'Utilisation (ToS). En revanche, l'utilisation de logiciels tiers (comme des injecteurs DLL ou des décompilateurs de mémoire vive) sur le binaire actif `Wow.exe` pour dumper l'API C++ déclenchera instantanément une détection par l'anti-triche *Warden* et provoquera un bannissement permanent de votre compte.
* **Modifications de la commande** : Blizzard n'a pas restreint l'usage de la commande mais l'a déplacée au niveau de la console de démarrage pour éviter les freezes complets du client de jeu que provoquait l'écriture synchrone de milliers de fichiers depuis une session de jeu active.
* **Mécanisme de "Taint" (Sécurisation des fonctions)** : WoW sépare strictement l'environnement en fonctions dites **"Secure"** (gérées par Blizzard, ex: le ciblage de sorts, les actions de mouvement) et **"Unsecure"** (le code de votre addon). Si votre addon tente de modifier une variable globale ou d'intercepter une fonction utilisée par le framework de combat natif (ex: modifier le comportement des boutons de barre d'action), la fonction devient *tainted* (contaminée). Dès lors que le joueur entrera en combat, le moteur de WoW bloquera instantanément l'exécution de l'addon en levant une erreur d'action interdite (`Action Forbidden`).