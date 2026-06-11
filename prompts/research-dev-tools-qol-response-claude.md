Voici le résultat de mes recherches, organisé par situation. J'indique pour chaque solution si elle **existe déjà** (natif ou add-on) ou s'il faut la **coder**, avec une évaluation effort/bénéfice.

---

# Outils de dev pour add-ons WoW Classic Era — synthèse de recherche

## Avant tout : les 3 add-ons à installer immédiatement

Avant de détailler par situation, trois installations couvrent à elles seules ~70% des besoins, pour zéro effort de code :

1. **BugSack + BugGrabber** (Curseforge) — capture d'erreurs Lua. BugSack affiche les erreurs Lua survenues pendant la session, avec la stack de debug complète, et se veut un outil indispensable aux développeurs. BugGrabber est le moteur de capture ; sans add-on d'affichage comme BugSack, il imprime simplement les erreurs dans le chat. Maintenu activement, versions Classic Era disponibles. Source : https://www.curseforge.com/wow/addons/bugsack et https://www.curseforge.com/wow/addons/bug-grabber
2. **DevTool** (successeur de ViragDevTool) — outil multi-usage proche d'un debugger, capable de visualiser et inspecter tables, événements et appels de fonctions au runtime. Source : https://www.curseforge.com/wow/addons/devtool
3. **WowLua** — éditeur/REPL Lua in-game (voir S6). WowLua est annoncé comme compatible Classic. Source : https://www.wowinterface.com/downloads/info7366-WowLua.html

---

## S1 — Logging et output

### 1. Logger dans un fichier lisible hors-jeu

**Verdict ferme : votre pattern SavedVariables est LE pattern.** Il n'existe aucune API permettant à un add-on d'écrire un fichier arbitraire sur disque — c'est un choix de sécurité délibéré de Blizzard. Les SavedVariables ne sont écrites qu'au `/reload`, au logout ou à la fermeture du client. Vous ne trouverez pas mieux côté add-on.

Précisions sur vos pistes :
- **Developer Console / `ConsoleExec()`** : la console écrit dans le chat/console, pas dans un fichier accessible. Pas de redirection possible vers le disque. Effort/bénéfice : nul, abandonnez cette piste.
- **`C_Log.LogMessage()`** : écrit dans les logs internes du client (destinés à Blizzard), pas dans un fichier que vous pouvez parser proprement. Inutile pour votre agent.
- **La seule écriture disque temps réel qui existe** : `/combatlog`, qui écrit `Logs/WoWCombatLog.txt` en continu — mais seuls les événements de combat y vont, un add-on ne peut pas y injecter de données arbitraires. Sans intérêt pour du logging général, mais à connaître si un jour vous debuggez du combat log.

**Amélioration concrète de votre pattern existant (effort : 30 min, bénéfice : élevé)** : ajoutez un *flush automatique* — votre agent ne peut lire qu'après `/reload`, donc faites en sorte que `/cg log flush` fasse le reload lui-même :

```lua
SLASH_CGFLUSH1 = "/cgflush"
SlashCmdList.CGFLUSH = function()
    CGDB.log._flushedAt = date("%Y-%m-%d %H:%M:%S")
    ReloadUI()  -- force l'écriture des SavedVariables
end
```

Et côté agent, un script qui attend la modification du fichier `WTF/Account/<ACCOUNT>/SavedVariables/<Addon>.lua` (mtime) avant de le parser. C'est le pont fichier le plus court entre le jeu et l'agent.

### 2. Logger avec des niveaux

**À coder vous-mêmes (B)** — `C_Log` n'est pas fait pour ça, roulez le vôtre. Pattern standard de la communauté, ~40 lignes :

```lua
ns.Log = { level = 2 } -- 1=DEBUG 2=INFO 3=WARN 4=ERROR
local LEVELS = { [1]="DEBUG", [2]="INFO", [3]="WARN", [4]="ERROR" }
local COLORS = { [1]="|cFF888888", [2]="|cFFFFFFFF", [3]="|cFFFFAA00", [4]="|cFFFF4444" }

local function emit(lvl, fmt, ...)
    if lvl < ns.Log.level then return end
    local msg = string.format("[%s][%s] %s", date("%H:%M:%S"), LEVELS[lvl],
                              select("#", ...) > 0 and fmt:format(...) or fmt)
    if ns.Log.toChat then print(COLORS[lvl] .. msg .. "|r") end
    if CGDB and CGDB.logBuffer then table.insert(CGDB.logBuffer, msg) end
end

function ns.Log.Debug(...) emit(1, ...) end
function ns.Log.Info(...)  emit(2, ...) end
function ns.Log.Warn(...)  emit(3, ...) end
function ns.Log.Error(...) emit(4, ...) end
```

Astuce qui change tout pour votre agent : loggez **toujours** au format `[timestamp][LEVEL][module] message`. Un format stable = parsing trivial côté agent, filtrage par grep. Effort : 1h, bénéfice : énorme.

### 3. Toggle à chaud

Votre `/cg log on/off` est déjà le bon pattern. Deux raffinements peu coûteux :
- **Niveau par module** : `ns.Log.levels = { Core = 2, UI = 4 }` — réduire le bruit sans tout couper.
- **Le pattern le plus élégant observé chez les gros add-ons** (Ace3 et consorts) : un flag dans les SavedVariables + une fonction debug qui est une no-op quand désactivée (`ns.Debug = isEnabled and emit or function() end`), réassignée au toggle. Coût runtime nul quand off — important si vous loggez dans des hot paths (OnUpdate, événements fréquents).

---

## S2 — Debugging

### 4. Inspecter des tables profondes

**Du plus pratique au plus avancé :**

1. **`/tinspect` (natif, C)** — ouvre le Table Inspector sur une table globale nommée ; sans argument, il inspecte le widget UI sous le curseur de la souris. Le `Blizzard_TableInspector` que vous avez vu dans le code exporté est bien fonctionnel en Classic Era 1.15. Combo puissant avec fstack : dans /fstack, ALT gauche/droite navigue entre les éléments surlignés et CTRL inspecte la table sélectionnée (équivalent /tinspect). Effort : zéro, c'est déjà dans le client.
2. **DevTool (add-on, C)** — l'outil de référence pour l'inspection. Examiner l'API WoW ou les variables de votre add-on dans une interface en colonnes est bien plus facile qu'avec print(), /dump ou d'autres méthodes de debug par chat. Il expose une API à intégrer dans votre code : la fonction publique principale est AddData(data, nom), qui ajoute la donnée à la liste pour exploration dans l'interface. Pattern d'intégration recommandé par la doc :

```lua
function ns:Inspect(data, name)
    if DevTool and ns.DEBUG then DevTool:AddData(data, name) end
end
```

3. **Sérialiseur de table dans vos SavedVariables (B)** — pour que *l'agent* (pas vous) inspecte une table, dumpez-la récursivement dans le log buffer (voir S4-12 pour le code). C'est le seul moyen pour que l'IA "voie" une table.

### 5. Debugger pas-à-pas

**Réponse courte : non, ça n'existe pas in-game.** L'environnement Lua de WoW est sandboxé, sans `debug.sethook` complet ni socket — donc pas de pdb/gdb possible, ni de remote debugger type MobDebug (qui exige LuaSocket, absent du client ; la page Wowpedia des éditeurs Lua note d'ailleurs que le debugger d'Eclipse LDT n'est pas utilisable avec WoW car il nécessite LuaSocket).

Les substituts réels utilisés par les devs :
- **`debugstack()` + `debuglocals()`** au point d'intérêt — un "breakpoint manuel" qui dumpe la stack et les locales dans votre log :

```lua
function ns.Breakpoint(label)
    ns.Log.Debug("BP[%s]\n%s\nLOCALS:\n%s", label, debugstack(2), debuglocals(2))
end
```

- **Tests hors-jeu** avec busted/luaunit + mocks (voir S3-8) — c'est *là* que vous pouvez utiliser un vrai debugger Lua, puisque le code tourne dans un interpréteur standard sur votre machine.

Effort/bénéfice : la fonction `Breakpoint` ci-dessus, c'est 5 lignes pour 80% de la valeur d'un debugger dans votre contexte agent.

### 6. Profiling

Trois étages, du plus simple au plus complet :

1. **`debugprofilestart()/stop()` (natif, A)** — micro-benchmarks ad hoc. Pattern utile :

```lua
function ns.Bench(label, fn, n)
    n = n or 1000
    debugprofilestart()
    for i = 1, n do fn() end
    local ms = debugprofilestop()
    ns.Log.Info("BENCH %s: %.3f ms total, %.5f ms/op", label, ms, ms/n)
end
```

2. **CVar `scriptProfile` + API CPU (natif, A)** — le client a un profiler intégré par add-on et par fonction : `SetCVar("scriptProfile", "1")` puis `/reload`, ensuite `UpdateAddOnCPUUsage()` et `GetAddOnCPUUsage("MonAddon")`. GetAddOnCPUUsage retourne le temps total utilisé par l'add-on en millisecondes, valeur en cache recalculée par UpdateAddOnCPUUsage(), sommant le temps de toutes les fonctions créées pour le compte de l'add-on. Attention : le temps mesuré n'inclut PAS les appels à l'API WoW elle-même — un add-on qui passe son temps dans des appels C apparaîtra faussement léger. Pensez à remettre le CVar à 0 ensuite (le profiling coûte cher en perfs).
3. **Add-on "Addon Profiler" de Numy (C)** — se présente comme un gestionnaire de tâches pour add-ons, et publie des builds pour 1.15.x (Classic Era). Source : https://www.curseforge.com/wow/addons/numy-addon-profiler

Effort/bénéfice : `ns.Bench` (5 min) couvre vos besoins de dev quotidiens ; `scriptProfile` quand vous suspectez un problème global ; l'add-on si vous voulez une UI.

### 7. Surveiller les événements

1. **`/etrace` (natif, A)** — la commande eventtrace trace les événements via l'EventTraceFrame de Blizzard_DebugTools, et aide les développeurs à comprendre quels événements se déclenchent et dans quel ordre. Disponible en Classic Era. /etrace mark [texte] ajoute un marqueur personnalisé dans la fenêtre de trace pour aider au debug — très utile pour borner "avant/après mon action".
2. **DevTool (C)** fait aussi du monitoring d'événements : DevTool peut surveiller les événements de l'API WoW à la manière de /etrace, et logger les appels de fonctions avec leurs arguments et valeurs de retour.
3. **Pattern "écouter TOUT" pour votre log agent (B)** — `RegisterAllEvents()` existe et c'est 10 lignes :

```lua
local f = CreateFrame("Frame")
local IGNORE = { COMBAT_LOG_EVENT_UNFILTERED = true, OnUpdate = true }
function ns.EventSpy(filterPattern)
    f:RegisterAllEvents()
    f:SetScript("OnEvent", function(_, event, ...)
        if IGNORE[event] then return end
        if filterPattern and not event:find(filterPattern) then return end
        ns.Log.Debug("EVT %s | %s", event, table.concat({tostringall(...)}, ", "))
    end)
end
-- /cg run spy UNIT  → ne logge que les événements UNIT_*
```

C'est *la* brique qui rend votre agent autonome sur les questions "quel événement se déclenche quand X ?" : il lance le spy, vous faites l'action, `/reload`, il lit le fichier. Effort : 30 min, bénéfice : majeur pour votre workflow.

---

## S3 — Tests

### 8. Framework de tests in-game

Deux familles, complémentaires :

**In-game (C, existant)** :
- **WoWUnit (Jaliborc)** — le plus moderne. Permet d'écrire des tests unitaires avec interface de suivi, de lancer les tests sur des événements de jeu, et fournit des méthodes de mock temporaire de variables ; l'intégration recommandée passe par ## OptionalDeps: WoWUnit. Son API (`AreEqual`, `Exists`, `Replace` pour mocker) est exactement ce que vous avez probablement réinventé. Source : https://github.com/Jaliborc/WoWUnit
- **wowUnit (Mirroar)** — alternative, corrigée en 2019 pour fonctionner avec WoW Classic, avec des assertions récursives sur tables et un lancement par slash command "/test addAddOn". Source : https://github.com/Mirroar/wowUnit
- L'ancien **WoWUnit (Feithar)** sur Curseforge montre le pattern historique : suites de tests avec setUp/tearDown, mocks d'appels API WoW, exécution via /wowunit et résultats dans le chat — mais il date de 2014, préférez les deux ci-dessus.

Mon conseil : ne migrez pas votre système maison qui marche ; **pillez** plutôt deux idées de WoWUnit : (a) le mock/restore systématique de globales (`Replace`), (b) le déclenchement de tests sur événement (tester ce qui se passe à `PLAYER_ENTERING_WORLD` sans intervention manuelle).

**Hors-jeu (E, le vrai game-changer pour un agent IA)** : faire tourner la logique pure (parsing, calculs, structures de données) dans un Lua standard avec **busted** + mocks de l'API WoW. Il existe des environnements prêts : une image Docker (wow-addon-container) permet de lancer busted sur un dossier spec/ de votre add-on, avec couverture de code via luacov et rapports HTML (https://github.com/runeberry/wow-addon-container), et wowmock charge un fichier Lua d'add-on dans un environnement contrôlé via setfenv, conçu pour luaunit et mockagne, où les fonctions de l'API WoW sont mockées (https://github.com/Adirelle/wowmock).

**C'est la solution n°1 pour votre situation** : l'agent peut exécuter `busted` lui-même, sans vous, sans `/reload`, en boucle. Architecture cible : séparez votre add-on en couche "logique pure" (testable hors-jeu par l'agent en autonomie totale) et couche "intégration WoW" (testée in-game via votre `/cg test`). Effort : 1-2 jours de refactoring ; bénéfice : l'agent itère 50× plus vite sur toute la logique métier.

### 9. Tests automatisés

- **In-game** : votre `/cg run` + une commande `/cg test all` qui écrit les résultats dans le SavedVariables est déjà l'état de l'art (les macros ne savent rien faire de plus qu'enchaîner des slash commands). Ajoutez un **résumé machine-readable** en fin de buffer : `TESTS: 47 passed, 2 failed, 0 errors` + liste des échecs avec stack — l'agent n'a plus qu'à grep.
- **Auto-run au login** : un flag `CGDB.autoTestOnLogin = true` que l'agent peut activer en éditant le fichier SavedVariables *avant* que vous lanciez le jeu (le fichier est du Lua, l'agent peut le modifier !), et qui déclenche la suite à `PLAYER_ENTERING_WORLD`. La boucle devient : agent écrit code + flag → vous faites `/reload` → tests tournent seuls → second `/reload` (automatisable par un `C_Timer.After(5, ReloadUI)` post-tests, hors combat) → l'agent lit les résultats. Vous êtes réduit au rôle de presse-bouton, c'est le but.
- **Hors-jeu** : busted en CI/local, voir point 8 — automatisation totale sans vous.

---

## S4 — Interaction agent IA ↔ jeu

### 10. Communication bidirectionnelle

État des lieux honnête : votre pattern (fichiers Lua → test humain → lecture SavedVariables) est le **seul canal sanctionné**. Ce qui peut l'améliorer :

- **Sens agent → jeu, l'astuce sous-exploitée** : les SavedVariables sont du Lua exécutable que l'agent peut **écrire**. Créez une convention `CGDB.inbox = { commands = {...} }` : l'agent dépose des commandes à exécuter dans le fichier (jeu fermé ou avant reload), votre add-on les lit et les exécute à `ADDON_LOADED`, logge les résultats, et l'agent les récupère au reload suivant. Un seul `/reload` humain fait alors un aller-retour complet question→réponse. Effort : 2-3h, bénéfice : c'est probablement la plus grosse amélioration de débit possible de votre workflow.
- **Réduire la friction du `/reload`** : voir S6-16 (watcher externe + keystroke). En combinant les deux, l'agent peut quasiment piloter seul : il écrit l'inbox, déclenche le reload via l'outil externe, attend le mtime du fichier, lit la réponse.
- Les **macros WoW n'apportent rien ici** : elles sont statiques, limitées à 255 caractères, et ne peuvent pas être créées/modifiées depuis l'extérieur de façon fiable (elles vivent dans le cache serveur/compte, pas dans un fichier éditable proprement).

### 11. Scénarios complexes

- **WowLua comme moteur de scénarios (C, existant)** : c'est la réponse directe à "scripts multi-lignes". WowLua permet d'exécuter ses pages de script depuis la ligne de commande via /wowluarun ou /luarun, chaque commande prenant le nom d'une page, et ces commandes sont utilisables depuis des macros. Vos scénarios deviennent des pages nommées, lancées par `/luarun ScenarioRaid`. Bonus : les pages WowLua sont stockées… dans ses SavedVariables, donc **l'agent peut écrire des pages WowLua directement dans le fichier** et vous n'avez plus qu'à `/luarun NomDeLaPage`. Attention au point habituel : il faut un restart (pas juste reload) si l'agent modifie le fichier pendant que le jeu tourne, sinon le jeu écrasera ses modifications au prochain flush.
- **Alternative maison (B)** : `/cg scenario <nom>` qui exécute une table de steps définie dans un fichier `scenarios.lua` de votre add-on (l'agent écrit le fichier, `/reload`, vous lancez). Avantage sur `/cg run` : vrai Lua multi-lignes, boucles, asserts intermédiaires, `C_Timer` pour les étapes asynchrones :

```lua
ns.Scenarios["loot_test"] = {
    { desc = "ouvrir le sac",  fn = function() OpenAllBags() end, wait = 0.5 },
    { desc = "vérifier slots", fn = function() ns.Assert(C_Container.GetContainerNumSlots(0) > 0) end },
}
```

### 12. Capturer l'état complet

À coder (B) : un sérialiseur récursif → SavedVariables. Les pièges à gérer : cycles, frames (non sérialisables), fonctions, profondeur.

```lua
local function serialize(v, depth, seen)
    depth = depth or 0
    if depth > 6 then return "<max-depth>" end
    local t = type(v)
    if t ~= "table" then return tostring(v) end
    if seen[v] then return "<cycle>" end
    seen[v] = true
    if v.GetObjectType then return "<frame:" .. v:GetObjectType() .. ">" end
    local out = {}
    for k, val in pairs(v) do
        out[#out+1] = string.rep(" ", depth*2) .. tostring(k) .. " = " .. serialize(val, depth+1, seen)
    end
    return "{\n" .. table.concat(out, "\n") .. "\n" .. string.rep(" ", depth*2) .. "}"
end
function ns.Snapshot(label)
    CGDB.snapshots = CGDB.snapshots or {}
    CGDB.snapshots[label] = { time = date(), state = serialize(ns.State, 0, {}) }
end
```

`/cg snapshot before_fix` → action → `/cg snapshot after_fix` → `/reload` → l'agent diffe les deux. Effort : 2h, bénéfice : élevé (debug de régressions, "pourquoi l'état diverge").

---

## S5 — Macros et automatisation

### 13. Macros utiles pour le dev (D)

Le strict utile (les macros ne sont que des raccourcis de slash commands) :

- `/reload` — LA macro à mettre sur une touche (bind clavier via le système de raccourcis, ex. F12). C'est l'optimisation #1 de tout dev d'add-on.
- `/run DevTool:AddData(MonAddonNS, "ns")` — inspection en un clic.
- `/dump GetMouseFocus():GetName()` — identifier la frame sous la souris.
- `/console scriptErrors 1` — devrait être permanent chez vous (ou remplacé par BugSack).
- `/etrace mark TEST` — borner une zone d'investigation dans l'event trace.
- `/cg test; /cg log show` — vos propres commandes chaînées (votre `/cg run` rend ça encore plus flexible que la macro native, qui exécute aussi les lignes séquentiellement mais sans logique).

### 14. Macros conditionnelles

Les conditionnelles de macro natives (`[combat]`, `[mod:shift]`, `[group]`…) ne s'appliquent qu'aux commandes sécurisées (sorts, cibles). Pour de la logique de dev, la "macro conditionnelle" c'est simplement `/run` :

```
/run if InCombatLockdown() then print("en combat, reload refusé") else ReloadUI() end
```

Limite dure : 255 caractères par macro. Au-delà → page WowLua ou commande dans votre add-on. La vraie réponse à ce besoin : mettez la logique dans `/cg` et gardez les macros comme simples déclencheurs.

### 15. Boutons d'action pour le dev (B)

Pattern simple et rentable (effort : 1-2h) — une barre de boutons cliquables :

```lua
local function MakeDevButton(label, onClick, index)
    local b = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    b:SetSize(80, 22)
    b:SetPoint("TOPLEFT", 10, -100 - index * 24)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end
MakeDevButton("Reload", ReloadUI, 0)
MakeDevButton("Tests",  function() ns.RunTests() end, 1)
MakeDevButton("Log",    function() ns.Log.Toggle() end, 2)
MakeDevButton("Flush",  function() ReloadUI() end, 3)
```

Note : `ReloadUI()` appelé depuis un OnClick d'add-on fonctionne hors combat. Conditionnez l'affichage de la barre à un flag dev pour ne pas polluer l'UI normale.

---

## S6 — Confort et productivité

### 16. Auto-reload

**Impossible de l'intérieur** : le client ne détecte pas les changements de fichiers et aucun add-on ne peut déclencher un reload sur événement externe. À noter aussi : le /reload suffit pour les modifications de fichiers .lua existants, mais l'ajout de nouveaux fichiers (ou .toc) exige un redémarrage du client.

**Solution externe (E)**, le standard officieux des devs : un watcher de fichiers qui envoie une frappe clavier à la fenêtre WoW, frappe bindée sur une macro `/reload`.
- Windows : AutoHotkey (`ControlSend` vers la fenêtre WoW) déclenché par `watchexec` ou un `FileSystemWatcher` PowerShell.
- macOS/Linux : `entr`/`watchexec` + `osascript`/`xdotool`.

Squelette PowerShell+AHK (Windows) : watchexec surveille votre dossier AddOns et lance un script AHK d'une ligne qui envoie F12 (votre bind /reload) à la fenêtre "World of Warcraft". Effort : 1h ; bénéfice : élimine le geste le plus répété de votre journée, et donne à votre agent la capacité de déclencher des reloads lui-même (cf. S4-10). Restez sur "1 frappe = 1 reload" — pas d'automatisation d'actions de jeu, pour rester dans les clous des ToS.

### 17. Édition de code in-game

**WowLua (C, existant)** — environnement de scripting Lua in-game avec interpréteur interactif et éditeur multi-pages, coloration syntaxique incluse, ouvert via /wowlua ou /lua, ces commandes pouvant aussi exécuter directement une expression (/lua print(14)). Parfait pour prototyper un snippet avant de le donner à l'agent. La version Curseforge est maintenue ; il existe même un backport pour les clients Vanilla 1.12 si vous touchez aux serveurs privés. Alternative légère : le **Table Inspector + /dump** pour l'exploration, WowLua pour l'écriture.

### 18. Snippets et templates récurrents

Les patterns qui reviennent dans tout add-on Classic Era — à mettre dans la bibliothèque de snippets de votre agent :

```lua
-- 1. Boilerplate événements (le pattern dispatch)
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, ...)
    if ns[event] then ns[event](ns, ...) end
end)

-- 2. Défaut de SavedVariables avec migration
function ns:ADDON_LOADED(name)
    if name ~= "MonAddon" then return end
    CGDB = CGDB or {}
    for k, v in pairs(ns.defaults) do
        if CGDB[k] == nil then CGDB[k] = v end
    end
end

-- 3. Throttle d'OnUpdate (jamais de travail à chaque frame)
local acc = 0
f:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc < 0.2 then return end
    acc = 0
    -- travail ici, 5×/s max
end)

-- 4. Différer hors combat
function ns.SafeCall(fn)
    if InCombatLockdown() then
        ns.pending = ns.pending or {}
        table.insert(ns.pending, fn)  -- vidé à PLAYER_REGEN_ENABLED
    else fn() end
end

-- 5. pcall systématique autour des handlers (avec report vers le log agent)
local function safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Log.Error("HANDLER FAIL: %s\n%s", err, debugstack(2)) end
end
```

Côté éditeur externe, équipez l'agent/VS Code de l'extension **WoW API** + **Ketho's wow-api annotations** pour le Lua Language Server (autocomplétion de l'API, détection d'API Retail-only — précieux pour éviter que l'agent génère du code 11.x invalide en 1.15).

---

## Récapitulatif effort/bénéfice (le top 6 dans l'ordre où je le ferais)

1. **Installer BugSack+BugGrabber et DevTool** — 5 min, transforme le debugging quotidien. *(existant)*
2. **EventSpy avec filtre → log SavedVariables** — 30 min, rend l'agent autonome sur les questions d'événements. *(à coder, S2-7)*
3. **Format de log machine-readable + résumé de tests greppable** — 1h. *(à coder, S1-2/S3-9)*
4. **Inbox de commandes dans les SavedVariables** (l'agent écrit, le jeu exécute au load) — 2-3h, double le débit de votre boucle. *(à coder, S4-10)*
5. **Watcher externe + keystroke /reload** — 1h, supprime la friction n°1. *(workflow, S6-16)*
6. **Extraction de la logique pure + busted hors-jeu** — 1-2 jours, mais c'est le seul changement qui permet à l'agent d'itérer *sans vous* ; le plus gros ROI à moyen terme. *(refactoring, S3-8)*

Deux pistes de votre document à classer sans suite, pour que vous ne perdiez pas de temps dessus : la redirection d'output via `ConsoleExec()`/Developer Console (pas de sortie fichier) et `C_Log` (logs internes client, inaccessibles proprement). Et une limite à garder en tête sur tout ce qui précède : aucun débit fichier en temps réel n'existera jamais côté add-on — toute votre architecture agent doit assumer le cycle « écriture → reload → lecture », et les gains se font en maximisant ce qu'on fait passer dans chaque cycle.