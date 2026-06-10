Voici une analyse détaillée et experte concernant la gestion des `SavedVariables` dans World of Warcraft Classic Era (1.15.x), basée sur la documentation officielle de l'API et les pratiques de la communauté.

### 1. Cycle de vie des SavedVariables

Le cycle de vie et l'ordre de déclenchement des événements au chargement de l'interface sont cruciaux pour éviter les erreurs d'initialisation.

* **Ordre des événements :** `ADDON_LOADED` -> `VARIABLES_LOADED` -> `PLAYER_LOGIN` -> `PLAYER_ENTERING_WORLD`.
* **`ADDON_LOADED`** : Cet événement se déclenche individuellement pour *chaque* add-on. Lorsque `ADDON_LOADED` se déclenche et que le premier argument (`arg1`) correspond au nom de votre add-on, **la SavedVariable globale est déjà peuplée** (le moteur du jeu a lu le fichier `.lua` dans le dossier WTF et l'a injecté dans l'environnement global). C'est le moment idéal pour initialiser vos variables.
* **`VARIABLES_LOADED`** : Cet événement se déclenche une fois que *tous* les add-ons et leurs SavedVariables respectives ont été chargés. Il est moins utilisé aujourd'hui pour l'initialisation interne d'un add-on, mais utile si vous devez interagir avec la SavedVariable d'un *autre* add-on.
* **`PLAYER_LOGIN`** : L'environnement de jeu complet est prêt. Les SavedVariables sont disponibles depuis longtemps. C'est ici que l'on construit généralement l'interface utilisateur (UI) basée sur les données sauvegardées.
* **`PLAYER_LOGOUT`** : Se déclenche quand le joueur se déconnecte. C'est votre dernière chance pour nettoyer vos tables (supprimer le cache, purger les données inutiles) *avant* que le jeu ne les écrive sur le disque.
* **Au moment du `/reload` (ou déconnexion)** : Le moteur du jeu sérialise et écrit les fichiers `SavedVariables/*.lua` **AVANT** de recharger l'interface ou de fermer le client.
* **Premier chargement** : Oui, au tout premier chargement d'un add-on (ou si le fichier WTF est effacé), la variable globale déclarée n'existe pas encore dans le fichier de sauvegarde. Elle vaudra donc `nil` dans l'environnement Lua jusqu'à ce que votre code l'initialise.

*[Source : Warcraft Wiki - Saving variables between game sessions](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions)*
*[Source : Warcraft Wiki - Event ADDON_LOADED](https://warcraft.wiki.gg/wiki/ADDON_LOADED)*

---

### 2. Déclaration dans le .toc

La syntaxe dans le fichier `.toc` est stricte :

```toc
## SavedVariables: MyGlobalAddonDB, MySecondGlobalVar
## SavedVariablesPerCharacter: MyCharSpecificDB

```

* **Différence** : `SavedVariables` sauvegarde les données au niveau du compte (partagé entre tous les personnages, utile pour les configurations générales). `SavedVariablesPerCharacter` sauvegarde les données spécifiquement pour le personnage actuellement connecté (utile pour les barres d'actions, l'or du personnage, etc.).
* **Classic Era** : Oui, les deux directives existent et fonctionnent parfaitement sur le client 1.15.x.
* **Variables multiples** : Oui, il est tout à fait possible de déclarer plusieurs variables en les séparant par des virgules.
* **Obligation d'être globale** : **Confirmé.** Le moteur C++ de WoW lit les noms dans le `.toc` et va chercher ces clés *uniquement* dans la table globale de Lua (`_G`). Si votre variable est `local`, le client ne la verra pas au moment de la sauvegarde et vos données seront perdues.

*[Source : Warcraft Wiki - TOC format](https://warcraft.wiki.gg/wiki/TOC_format)*

---

### 3. Sérialisation — Limitations

WoW utilise son propre sérialiseur C++ pour transformer vos tables Lua en fichiers texte.

* **Types supportés** : Les `numbers`, `strings`, `booleans` et `tables` sont parfaitement supportés.
* **Tables imbriquées** : Totalement supportées. La profondeur théorique est la limite de la pile C/Lua, mais en pratique, vous pouvez imbriquer des dizaines de niveaux sans problème.
* **Functions, Userdata (Frames, Textures)** : **NON sérialisables.**
* **Que se passe-t-il avec une fonction ?** Si une table contient une fonction, le sérialiseur de WoW va tout simplement l'ignorer. La paire clé-valeur contenant la fonction ne sera pas écrite dans le fichier `.lua`, sans générer d'erreur bloquante (elle sera "droppée" silencieusement).
* **Mixed tables** : Les tables mixtes (contenant à la fois des clés numériques séquentielles `[1]` et des clés chaînes de caractères `["key"]`) sont parfaitement supportées, car c'est le comportement natif des tables en Lua.

*[Source : Warcraft Wiki - SavedVariables Serialization](https://www.google.com/search?q=https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions%23Variable_types_and_limits)*

---

### 4. Pattern d'initialisation recommandé

Le pattern que vous avez fourni est fonctionnel pour une table "plate" (sans imbrication). Cependant, dans les add-ons WoW, il y a deux patterns plus idiomatiques.

**Pattern 1 : Copie récursive (Vanilla Lua)**
Si vos valeurs par défaut contiennent des sous-tables, la boucle `for` simple ne suffit pas (elle écraserait les références ou ne remplirait pas les sous-clés manquantes). Il faut utiliser une fonction de fusion.

```lua
local defaults = {
    counter = 0,
    settings = { showMinimap = true, scale = 1.0 }
}

-- Fonction récursive pour appliquer les défauts sans écraser les choix de l'utilisateur
local function CopyDefaults(src, dest)
    if type(dest) ~= "table" then dest = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = CopyDefaults(v, dest[k])
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
    return dest
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "MyAddon" then
        MyAddonDB = MyAddonDB or {}
        MyAddonDB = CopyDefaults(defaults, MyAddonDB)
    end
end)

```

**Pattern 2 : Utilisation d'AceDB-3.0 (Le standard de l'industrie)**
La grande majorité des add-ons utilisent la librairie `AceDB-3.0` pour gérer ça automatiquement, y compris la notion de profils.

```lua
-- Automatiquement géré par AceDB :
self.db = LibStub("AceDB-3.0"):New("MyAddonDB", defaults, true)

```

*[Source : WoWInterface Forums - Best practices for SavedVariables](https://www.wowinterface.com/forums/showthread.php?t=48405)*
*[Source : Ace3 Documentation - AceDB-3.0](https://www.wowace.com/projects/ace3/pages/api/ace-db-3-0)*

---

### 5. Où sont stockés les fichiers ?

Les chemins pour Classic Era (Version 1.15.x) sont les suivants. Notez le dossier `_classic_era_` qui est propre à cette version.

* **Compte (`SavedVariables`)** :
`World of Warcraft\_classic_era_\WTF\Account\<NOM_COMPTE>\SavedVariables\<NomAddon>.lua`
* **Personnage (`SavedVariablesPerCharacter`)** :
`World of Warcraft\_classic_era_\WTF\Account\<NOM_COMPTE>\<NomServeur>\<NomPersonnage>\SavedVariables\<NomAddon>.lua`

*(Note : Ne modifiez jamais ces fichiers pendant que le jeu est lancé, car le client WoW les écrasera lors du `/reload` ou de la déconnexion).*

*[Source : Warcraft Wiki - WTF folder](https://www.google.com/search?q=https://warcraft.wiki.gg/wiki/WTF_folder)*

---

### 6. Exemples d'add-ons existants

* **DBM (Deadly Boss Mods)** : Utilise massivement les SavedVariables globales pour les timers et alertes, stockées dans `DBM_AllSavedOptions`. Ils utilisent des tables d'initialisation récursives similaires au "Pattern 1" pour gérer les innombrables options de boss.
* **WeakAuras** : Stocke toutes vos auras dans une énorme variable de compte `WeakAurasSaved`. Le code charge les auras dans `ADDON_LOADED` et nettoie les tables temporaires lors de `PLAYER_LOGOUT`.
* **TomTom** : (Très bon exemple simple) Utilise `TomTomGlobal_Inner` et `TomTomWaypoints` gérés via le pattern `AceDB-3.0` mentionné plus haut pour séparer les points de passage spécifiques au personnage des réglages de la flèche globaux.

*[Source : DBM GitHub Repository](https://www.google.com/search?q=https://github.com/DeadlyBossMods/DBM-Classic)*
*[Source : WeakAuras GitHub Repository](https://github.com/WeakAuras/WeakAuras2)*

---

### 7. Points subtils / gotchas

* **Le `.toc` déclare `MyVar` mais le `.lua` ne la définit jamais** : Si le fichier de sauvegarde existait (d'une session précédente), ses données sont chargées en mémoire. Si l'add-on ne fait rien, la variable reste en mémoire. À la déconnexion, elle est re-sauvegardée telle quelle. Si c'est une nouvelle installation, elle reste à `nil` et le fichier créé contiendra juste un retour chariot ou rien du tout.
* **Le `.lua` définit `MyVar` mais le `.toc` ne la déclare pas** : `MyVar` existera en tant que variable globale normale pendant la session de jeu. Cependant, à la déconnexion ou au `/reload`, **elle ne sera pas sauvegardée** sur le disque.
* **Le piège du Proxy Local (`local db`)** :
C'est un bug très courant. Si vous écrivez ceci en haut de votre fichier :
```lua
local db = MyAddonDB -- ERREUR !

```


Au moment où ce code est lu, `ADDON_LOADED` n'a pas encore eu lieu, donc `MyAddonDB` est `nil`. `db` vaudra `nil`. Vous DEVEZ assigner le proxy à l'intérieur de la fonction `ADDON_LOADED`, une fois que la globale est chargée.
```lua
local db
-- ... plus tard dans ADDON_LOADED :
db = MyAddonDB -- CORRECT

```


* **La fonction `wipe()**` : Oui, `wipe(MyAddonDB)` est une fonction API de WoW extrêmement utile (écrite en C pour être ultra-rapide). Elle vide le contenu de la table sans détruire la référence mémoire de la table elle-même. C'est parfait pour réinitialiser les réglages sans casser vos proxys locaux.
* **Limites de taille** : Il n'y a pas de limite stricte codée en dur. Cependant, des tables gigantesques (comme TradeSkillMaster - TSM ou les compteurs de dégâts comme Details!) créent d'énormes fichiers texte (parfois > 50 Mo). Cela provoque de graves freezes (micro-blocages) du client lors des écrans de chargement, des `/reload` et des déconnexions à cause de l'I/O disque et du travail acharné du Garbage Collector de Lua pour parser des millions de lignes de texte.

*[Source : Warcraft Wiki - API wipe](https://www.google.com/search?q=https://warcraft.wiki.gg/wiki/API_wipe)*
*[Source : Lua 5.1 Reference Manual - Garbage Collection](https://www.google.com/search?q=https://www.lua.org/manual/5.1/manual.html%232.10)*