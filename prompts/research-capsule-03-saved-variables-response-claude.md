# Recherche — Capsule 03 : SavedVariables (WoW Classic Era 1.15.x)

Voici la synthèse complète, basée principalement sur Warcraft Wiki (warcraft.wiki.gg, la référence actuelle), Wowpedia et des dépôts d'add-ons réels.

---

## 1. Cycle de vie des SavedVariables

### Ordre de chargement

Le processus documenté est le suivant : le code FrameXML de WoW est chargé et exécuté, puis le code de l'add-on est chargé et exécuté, puis les saved variables sont chargées et exécutées add-on par add-on, et l'événement `ADDON_LOADED` est déclenché pour cet add-on ; enfin `PLAYER_LOGIN` se déclenche une fois que tous les add-ons non-LoadOnDemand sont chargés et que le joueur est complètement connecté.

**`ADDON_LOADED`** : par défaut, les saved variables sont chargées après le dernier fichier listé dans le .toc (modifiable via la directive `LoadSavedVariablesFirst`), puis `ADDON_LOADED` se déclenche — c'est le moment le plus précoce où un add-on peut lire ses saved variables. Donc **oui, la SavedVariable est déjà peuplée** quand `ADDON_LOADED` se déclenche (avec `arg1` = nom de l'add-on). Point important : les saved variables se chargent après le dernier fichier et **écrasent toute valeur par défaut** définie plus tôt dans le code — c'est pourquoi on n'initialise jamais ses defaults au chargement du fichier Lua, mais dans le handler.

**`VARIABLES_LOADED`** : à éviter. Avant le patch 3.0.1, cet événement faisait partie de la séquence de chargement, mais il n'a plus d'ordre garanti ; il se déclenche en réponse au chargement des CVars, keybindings et autres variables "Blizzard", et peut survenir après `PLAYER_ENTERING_WORLD`. Les add-ons ne doivent pas l'utiliser pour vérifier que leurs saved variables sont chargées — utiliser `ADDON_LOADED` à la place. Cela vaut aussi pour le client Classic Era (1.15.x), qui utilise le moteur moderne. De plus, `VARIABLES_LOADED` ne se déclenche pas pour les add-ons load-on-demand.

**`PLAYER_LOGIN`** : peu pertinent pour les SavedVars elles-mêmes — elles sont disponibles bien avant. Il sert plutôt pour l'initialisation qui dépend des données du personnage.

**`PLAYER_LOGOUT`** : il se déclenche juste avant la déconnexion du personnage et c'est le dernier événement avant que vos saved variables soient écrites sur disque — utilisez-le pour faire des modifications de dernière minute avant la sauvegarde.

### Quand le fichier est-il écrit ?

Le client écrit automatiquement les valeurs sur disque quand vous vous déconnectez, êtes déconnecté, quittez le jeu, ou rechargez l'interface (`/reload`). Pour le `/reload` précisément : tous les add-ons "committent" leurs SavedVariables **avant** le reload, le quit ou le logoff — mais cela ne se produit pas lors d'un crash ou d'un Alt-F4. Donc : écriture **AVANT** le reload, puis relecture pendant le rechargement. Conséquence pratique : un crash = perte des données de la session.

### Premier chargement = `nil` ? Confirmé.

Quand l'add-on est chargé pour la première fois, la variable sera `nil` après `ADDON_LOADED` (en supposant qu'aucun autre add-on n'écrase la globale). D'où l'idiome `MyAddonDB = MyAddonDB or {}`.

**Sources** :
- https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions
- https://warcraft.wiki.gg/wiki/AddOn_loading_process
- https://wowpedia.fandom.com/wiki/VARIABLES_LOADED

---

## 2. Déclaration dans le .toc

La syntaxe que tu donnes est correcte. Il existe deux directives à ajouter au .toc, toutes deux suivies de deux-points et d'une **liste de noms de variables séparés par des virgules**, ces variables devant être dans l'environnement global (c'est-à-dire non déclarées avec `local`).

- **`## SavedVariables`** : variables sauvegardées **par compte** : quel que soit le personnage du compte qui se connecte, ces variables sont restaurées. Utile pour les réglages globaux ou les systèmes de profils.
- **`## SavedVariablesPerCharacter`** : une copie séparée de la variable est stockée et restaurée **pour chaque personnage** — utile pour des options ou un historique propres au personnage.

Réponses point par point :
- **Les deux existent en Classic Era ?** Oui. Ces directives existent depuis WoW vanilla (1.x) et sont identiques sur tous les clients (Era, Wrath/Cata Classic, Retail). Les .toc d'add-ons Classic réels le confirment, par ex. Leatrix Plus déclare `## SavedVariables: LeaPlusDB` dans son .toc.
- **Plusieurs variables ?** Oui : `## SavedVariables: Var1, Var2` (liste séparée par virgules, voir ci-dessus).
- **Globale obligatoire ?** Confirmé. Si vous voulez sauvegarder une valeur locale, vous devez d'abord la lire depuis l'environnement global (table `_G`) lors de `ADDON_LOADED`, puis la remettre dans l'environnement global avant la déconnexion. Le client ne sait sérialiser que ce qu'il trouve dans `_G` sous le nom déclaré.

**Sources** :
- https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions
- https://github.com/anzz1/leatrix-plus-wrath/blob/main/Leatrix_Plus_Wrath.toc

---

## 3. Sérialisation — Limitations

Le wiki est explicite : seuls certains types sont sauvegardés : **strings, booleans, numbers et tables** ; les **functions, userdata et coroutines ne le sont pas**. Les références circulaires dans les tables peuvent ne pas être préservées.

Détails :
- **Numbers, strings, booleans** : OK, sérialisés tels quels en Lua.
- **Tables imbriquées** : OK, sérialisées récursivement. Aucune limite de profondeur officiellement documentée ; en pratique la limite est la mémoire au rechargement (voir question 7). Les fichiers SavedVariables d'add-ons de données (Questie, AtlasLoot…) contiennent des tables très profondément imbriquées sans problème.
- **Functions** : NON sérialisables — confirmé (cf. citation ci-dessus). **Comportement** : la clé contenant une fonction est **silencieusement ignorée** lors de l'écriture du fichier ; il n'y a pas d'erreur Lua, la valeur disparaît simplement au prochain chargement. C'est pour cela que les frameworks comme AceDB séparent données (sauvegardées) et méthodes (recréées au chargement).
- **Mixed tables** (clés numériques + string) : supporté. Le format de sortie est du Lua pur avec clés entre crochets (`["clé"] = ...`, `[1] = ...`), exactement le mécanisme classique de sérialisation Lua décrit dans *Programming in Lua* (https://www.lua.org/pil/12.1.1.html). Le format de ces fichiers est du pur script Lua — en théorie on pourrait y mettre du code et il serait chargé, mais il serait écrasé à la prochaine sauvegarde.
- **Piège supplémentaire** : plusieurs saved variables qui référencent la même table créeront chacune une instance séparée (mais identique) de la table, et ne pointeront donc plus vers la même table après rechargement. L'identité de référence n'est pas préservée entre variables.

**Sources** :
- https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions (section « Common pitfalls »)
- https://www.lua.org/pil/12.1.1.html

---

## 4. Pattern d'initialisation recommandé

**Oui, ton pattern est correct** — et c'est même quasi mot pour mot le pattern canonique du tutoriel officiel du Warcraft Wiki. Le tutoriel « Create a WoW AddOn in 15 Minutes » utilise exactement : une table `local defaults`, puis dans le handler `if addOnName == "HelloWorld" then HelloWorldDB = HelloWorldDB or {}; self.db = HelloWorldDB -- plus lisible et bonne pratique; for k, v in pairs(defaults) do if self.db[k] == nil then self.db[k] = v end end`, et pour un reset : `HelloWorldDB = CopyTable(defaults)`.

Points clés du pattern :
- Le test `== nil` (et non `if not db[k]`) est essentiel pour ne pas écraser un `false` sauvegardé.
- Le `MyAddonDB = MyAddonDB or {}` gère le tout premier chargement (variable `nil`).
- Cette boucle gère aussi la **migration** : si une mise à jour de l'add-on ajoute une clé aux defaults, elle sera injectée chez les utilisateurs existants. Le wiki note que les tables peuvent être plus difficiles à initialiser aux valeurs par défaut quand l'add-on est mis à jour et qu'on ajoute ou retire une clé — d'où ce pattern.

**Defaults imbriqués** : la version récursive idiomatique :

```lua
local function ApplyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(db[k]) ~= "table" then db[k] = {} end
            ApplyDefaults(db[k], v)
        elseif db[k] == nil then
            db[k] = v
        end
    end
end
```

**Alternative plus industrielle** : la bibliothèque **AceDB-3.0** (utilisée par la majorité des gros add-ons, dont Questie) gère defaults imbriqués, profils, et la magie `['*']` pour les defaults par clé dynamique — mais pour un add-on pédagogique simple, ton pattern manuel est exactement ce qu'il faut. Doc : https://www.wowace.com/projects/ace3/pages/api/ace-db-3-0

**Sources** :
- https://warcraft.wiki.gg/wiki/Create_a_WoW_AddOn_in_15_Minutes
- https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions

---

## 5. Où sont stockés les fichiers ?

Chemins confirmés. La structure documentée est : `WTF\Account\ACCOUNTNAME\SavedVariables.lua` pour les saved variables de Blizzard ; `WTF\Account\ACCOUNTNAME\SavedVariables\AddOnName.lua` pour les réglages **par compte** de chaque add-on ; `WTF\Account\ACCOUNTNAME\RealmName\CharacterName\SavedVariables\AddOnName.lua` pour les réglages **par personnage**. Supprimer ou renommer le dossier WTF réinitialise les réglages de tous les add-ons.

Pour Classic Era, tout cela est sous le préfixe `_classic_era_` du dossier d'installation — confirmé par des outils réels qui parsent ces fichiers : l'outil AHDBapp lit `c:\Program Files (x86)\World of Warcraft\_classic_era_\WTF\Account\YOURACCOUNT\SavedVariables\AuctionDB.lua`.

Donc :
- **SavedVariables** : `_classic_era_/WTF/Account/<ACCOUNT>/SavedVariables/<AddonName>.lua` ✅
- **SavedVariablesPerCharacter** : `_classic_era_/WTF/Account/<ACCOUNT>/<Royaume>/<Personnage>/SavedVariables/<AddonName>.lua` ✅

Note : un fichier `.lua.bak` (backup de la version précédente) est créé à côté à chaque sauvegarde.

**Sources** :
- https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions
- https://github.com/mooreatv/AHDBapp
- https://vanilla-wow-archive.fandom.com/wiki/SavedVariables

---

## 6. Exemples d'add-ons existants

**1. HaveWeMet (l'exemple de référence du wiki)** — le plus simple et pédagogique : son .toc déclare `## SavedVariables: HaveWeMetCount` et `## SavedVariablesPerCharacter: HaveWeMetLastSeen` ; le code crée une frame, enregistre `ADDON_LOADED` et `PLAYER_LOGOUT`, et dans le handler : `if event == "ADDON_LOADED" and arg1 == "HaveWeMet" then if HaveWeMetCount == nil then HaveWeMetCount = 0 end ...` puis sur `PLAYER_LOGOUT` : `HaveWeMetLastSeen = time()`.
→ https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions

**2. Leatrix Plus (très populaire en Classic)** — une seule SavedVariable globale `LeaPlusDB` servant de table de configuration. Le .toc contient `## SavedVariables: LeaPlusDB`, et le code valide chaque entrée chargée avant usage, par exemple : `if LeaPlusDB[var] and type(LeaPlusDB[var]) == "number" and LeaPlusDB[var] >= valmin and LeaPlusDB[var] <= valmax then ...` — un bon exemple de validation défensive des données chargées (l'utilisateur peut avoir édité le fichier à la main).
→ https://github.com/anzz1/leatrix-plus-wrath/blob/main/Leatrix_Plus_Wrath.toc

**3. HelloWorld (tutoriel officiel)** — montre le pattern defaults + proxy `self.db` + compteur de sessions + reset via `CopyTable(defaults)` (code complet cité en question 4).
→ https://warcraft.wiki.gg/wiki/Create_a_WoW_AddOn_in_15_Minutes

(Pour aller plus loin : Questie, le plus gros add-on Era, utilise AceDB-3.0 par-dessus une SavedVariable `QuestieConfig` — intéressant comme contre-exemple « industriel » : https://github.com/Questie/Questie)

---

## 7. Points subtils / gotchas

**`.toc` déclare `MyVar` mais le .lua ne la définit jamais** : aucun problème. Au premier lancement, rien n'est sauvegardé (la globale vaut `nil` au logout, et `nil` n'est pas sérialisé) ; aux lancements suivants, la variable reste `nil` après `ADDON_LOADED`. C'est exactement l'état « premier chargement » du flux normal — le wiki confirme que la variable est simplement `nil` après `ADDON_LOADED` tant qu'elle n'a jamais existé.

**Le .lua définit `MyVar` mais le .toc ne la déclare pas** : la variable fonctionne normalement pendant la session (c'est juste une globale Lua), mais **n'est jamais écrite sur disque** — tout est perdu au logout/reload. C'est la conséquence directe du mécanisme : c'est l'ajout au .toc qui dit au client WoW que vous voulez qu'une variable persiste à travers la déconnexion. C'est le bug n°1 des débutants (« mes settings ne se sauvegardent pas »).

**Table locale comme proxy** : oui, c'est même la bonne pratique recommandée. Le tutoriel du wiki fait `self.db = HelloWorldDB -- makes it more readable and generally a good practice`. Comme les tables Lua sont passées par référence, écrire dans `db` écrit dans la globale. **Attention au piège** : si tu *réassignes* la globale (`MyAddonDB = CopyTable(defaults)`), le proxy local pointe encore vers l'ancienne table — il faut réassigner le proxy aussi (le tutoriel le fait : `HelloWorldDB = CopyTable(defaults)` suivi de la réassignation de `f.db`).

**`wipe()` sur les SavedVars** : oui, parfaitement utilisable. `wipe(MyAddonDB)` (alias de `table.wipe`) vide la table **en conservant la référence** — c'est même préférable à `MyAddonDB = {}` justement parce que les proxys locaux restent valides. C'est l'idiome standard pour un « reset » propre. Doc API : https://warcraft.wiki.gg/wiki/API_table.wipe

**Limites de taille** : pas de limite documentée en octets, mais une limite pratique : la mémoire au chargement. L'événement `SAVED_VARIABLES_TOO_LARGE` se déclenche quand le client manque de mémoire en tentant de charger les saved variables, après `ADDON_LOADED` ; le client affiche alors un popup informant l'utilisateur de l'erreur. Cas réel sur les forums : « Your Computer does not have enough memory to load settings from the following AddOn » avec Skada, où un fichier SavedVariables énorme (souvent causé par une référence cyclique générant un dump géant) empêchait le chargement. En pratique : des fichiers de plusieurs Mo sont courants et sans problème ; au-delà de quelques dizaines/centaines de Mo, risques d'écran de chargement très long, de freeze à l'écriture, voire de cette erreur. Gros volumes de données ⇒ compresser/sérialiser (LibDeflate, AceSerializer) ou élaguer.

**Bonus gotcha (vanilla mais toujours vrai)** : si une copie parasite de `SavedVariables.lua` existe à un autre emplacement (notamment à la racine du dossier World of Warcraft), elle peut être chargée à la place de la bonne, donnant l'impression que tous les add-ons oublient leur configuration.

**Sources** :
- https://warcraft.wiki.gg/wiki/AddOn_loading_process (événement `SAVED_VARIABLES_TOO_LARGE`)
- https://wowinterface.com/forums/archive/index.php/t-52375.html (cas mémoire Skada)
- https://warcraft.wiki.gg/wiki/Create_a_WoW_AddOn_in_15_Minutes (proxy `self.db`, reset)
- https://vanilla-wow-archive.fandom.com/wiki/SavedVariables

---

### Résumé pour ta capsule

1. **Tout se joue dans `ADDON_LOADED`** (filtré sur `arg1 == "TonAddon"`) — la SavedVar y est déjà chargée ; ignore `VARIABLES_LOADED`.
2. **Écriture sur disque avant** le reload/logout/quit ; `PLAYER_LOGOUT` = dernière chance de modifier ; crash = perte.
3. **`nil` au premier lancement** → idiome `Db = Db or {}` + boucle de defaults avec test `== nil`.
4. Seuls **number/string/boolean/table** sont sérialisés ; les fonctions disparaissent silencieusement ; les références partagées/cycliques ne sont pas préservées.