````markdown
# Outils de développement et QoL pour add-ons WoW Classic Era — recommandations pratiques

## Position courte

Pour ton workflow **agent IA → jeu → SavedVariables → agent IA**, le meilleur canal reste :

1. **Entrée agent → WoW** : un fichier Lua fixe, déjà listé dans le `.toc`, par exemple `DevInput.lua`, que l’agent réécrit avant `/reload`.
2. **Exécution en jeu** : `/cg run ...`, `/cg scenario ...`, boutons de dev, macros.
3. **Sortie WoW → agent** : SavedVariables écrites au `/reload` ou logout.

C’est cohérent avec les contraintes connues : les SavedVariables sont chargées au chargement de l’UI et sauvées à la sortie/reload, et les add-ons n’ont pas de vrai I/O fichier temps réel contrôlable depuis Lua. :contentReference[oaicite:0]{index=0}  
La cible **Classic Era 1.15.8 / Interface 11508** est bien cohérente avec les métadonnées d’add-ons Classic Era récentes. :contentReference[oaicite:1]{index=1}

---

# S1 — Logging et output

## S1.1 — Logger dans un fichier lisible hors-jeu

### Solution recommandée : garder SavedVariables, mais les structurer

**Effort : faible. Bénéfice : très élevé.**  
Je ne vois pas mieux que SavedVariables pour une sortie lisible par ton agent, parce que WoW ne fournit pas d’écriture arbitraire temps réel vers un fichier depuis les add-ons ; les variables déclarées dans le `.toc` sont précisément le mécanisme prévu pour persister des données sur disque. :contentReference[oaicite:2]{index=2}

La Developer Console et `ConsoleExec()` sont utiles pour exécuter des commandes console, mais pas comme pipe de logs vers un fichier agent. `ConsoleExec("command")` est documenté comme équivalent à `/console command`, et `ConsoleGetAllCommands()` / `C_Console.GetAllCommands()` servent à lister les commandes/CVars, pas à exporter un flux de logs. :contentReference[oaicite:3]{index=3}

Pattern conseillé :

```lua
-- CraftGold.toc
-- ## SavedVariables: CraftGoldDB
````

```lua
-- Logger.lua
local ADDON, ns = ...
CraftGoldDB = CraftGoldDB or {}

local LEVELS = {
  DEBUG = 10,
  INFO  = 20,
  WARN  = 30,
  ERROR = 40,
}

local DEFAULTS = {
  enabled = true,
  chatLevel = "INFO",
  saveLevel = "DEBUG",
  max = 500,
  entries = {},
  seq = 0,
}

local function ensure()
  CraftGoldDB.devlog = CraftGoldDB.devlog or {}
  for k, v in pairs(DEFAULTS) do
    if CraftGoldDB.devlog[k] == nil then
      if type(v) == "table" then
        CraftGoldDB.devlog[k] = {}
      else
        CraftGoldDB.devlog[k] = v
      end
    end
  end
  return CraftGoldDB.devlog
end

local function stripColors(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|r", "")
  return s
end

local function should(level, threshold)
  return LEVELS[level] >= LEVELS[threshold]
end

function ns.Log(level, fmt, ...)
  local db = ensure()
  level = level or "INFO"

  local ok, msg = pcall(string.format, tostring(fmt), ...)
  if not ok then
    msg = tostring(fmt)
  end

  msg = stripColors(msg)

  if db.enabled and should(level, db.saveLevel) then
    db.seq = (db.seq or 0) + 1
    table.insert(db.entries, {
      seq = db.seq,
      t = date("%Y-%m-%d %H:%M:%S"),
      level = level,
      msg = msg,
    })

    while #db.entries > db.max do
      table.remove(db.entries, 1)
    end
  end

  if db.enabled and should(level, db.chatLevel) then
    print("|cff88ccffCraftGold|r [" .. level .. "] " .. msg)
  end
end

function ns.LogClear()
  local db = ensure()
  db.entries = {}
  db.seq = 0
end

function ns.LogSetEnabled(enabled)
  ensure().enabled = enabled and true or false
end

function ns.LogSetLevel(kind, level)
  local db = ensure()
  level = string.upper(level or "")
  if not LEVELS[level] then
    ns.Log("ERROR", "Unknown log level: %s", tostring(level))
    return
  end
  if kind == "chat" then
    db.chatLevel = level
  else
    db.saveLevel = level
  end
end
```

Commandes :

```lua
-- /cg log on
-- /cg log off
-- /cg log clear
-- /cg log chat debug
-- /cg log save warn
-- /cg log show

function ns.HandleLogCommand(args)
  local sub, a, b = args[1], args[2], args[3]

  if sub == "on" then
    ns.LogSetEnabled(true)
    ns.Log("INFO", "Logging enabled")
  elseif sub == "off" then
    ns.Log("INFO", "Logging disabled")
    ns.LogSetEnabled(false)
  elseif sub == "clear" then
    ns.LogClear()
    ns.Log("INFO", "Log cleared")
  elseif sub == "chat" then
    ns.LogSetLevel("chat", a)
  elseif sub == "save" then
    ns.LogSetLevel("save", a)
  elseif sub == "show" then
    for _, e in ipairs((CraftGoldDB.devlog and CraftGoldDB.devlog.entries) or {}) do
      print(("[%04d] %s [%s] %s"):format(e.seq, e.t, e.level, e.msg))
    end
  else
    print("/cg log on|off|clear|show|chat <level>|save <level>")
  end
end
```

## S1.2 — `C_Log` ou logger maison ?

**Recommandation : logger maison.**
`C_Log.LogMessage()` et `C_Log.LogErrorMessage()` existent dans le système API “Log”, mais je ne trouve pas de preuve fiable que ce soit un sink stable, documenté, exportable et lisible par ton agent. ([Warcraft Wiki][1])

Pour CraftGold, le logger maison gagne parce qu’il contrôle :

* niveaux ;
* format stable ;
* ring buffer ;
* nettoyage des codes couleur ;
* export SavedVariables ;
* compatibilité avec tests in-game.

## S1.3 — Activer/désactiver à chaud

Ton `/cg log on/off` est déjà le bon pattern. L’amélioration simple est d’ajouter des seuils :

```text
/cg log on
/cg log off
/cg log clear
/cg log chat warn
/cg log save debug
```

Et un mode temporaire :

```lua
function ns.WithDebugLogging(fn)
  local db = CraftGoldDB.devlog
  local old = db.chatLevel
  db.chatLevel = "DEBUG"

  local ok, err = xpcall(fn, debugstack)

  db.chatLevel = old

  if not ok then
    ns.Log("ERROR", "WithDebugLogging failed: %s", err)
  end

  return ok, err
end
```

---

# S2 — Debugging

## S2.4 — Inspecter une table Lua en jeu

### Niveau 1 : `/dump`

`/dump` pretty-print une valeur et est équivalent à `DevTools_Dump(value)` ; c’est utile pour une table peu profonde, un retour API, ou une variable globale. ([Warcraft Wiki][2])

Exemples :

```text
/dump CraftGoldDB
/dump CraftGoldDB.devlog.entries[1]
/run DevTools_Dump(CraftGoldDB)
```

Si `Blizzard_DebugTools` n’est pas chargé :

```text
/run UIParentLoadAddOn("Blizzard_DebugTools"); DevTools_Dump(CraftGoldDB)
```

Le package Blizzard DebugTools est load-on-demand et contient les outils de debug, dont TableInspector dans les sources UI exportées. ([GitHub][3])

### Niveau 2 : `/tableinspect` ou DevTool

Le DebugTools Blizzard fournit aussi un Table Inspector sur certains builds via `/tableinspect`, mais l’option la plus pratique en dev add-on reste **DevTool** : il est conçu pour visualiser tables, événements et appels de fonctions à runtime, et CurseForge liste une saveur **Classic**. ([WoWInterface][4])

Alternative historique : **ViragDevTool**, qui sert à examiner l’API WoW et les variables d’un add-on dans une UI tabulaire, mais le dépôt GitHub indique que le projet original n’est plus vraiment maintenu et recommande DevTool comme fork/réécriture maintenu. ([CurseForge][5])

Usage DevTool/ViragDevTool typique :

```lua
if DevTool then
  DevTool:AddData(CraftGoldDB, "CraftGoldDB")
end

if ViragDevTool_AddData then
  ViragDevTool_AddData(CraftGoldDB, "CraftGoldDB")
end
```

### Niveau 3 : serializer maison pour SavedVariables

Pour l’agent IA, une inspection visuelle ne suffit pas. Il faut un dump borné, stable, sans cycles :

```lua
local function dumpValue(v, depth, maxDepth, seen)
  local tv = type(v)

  if tv ~= "table" then
    if tv == "string" then
      return string.format("%q", v)
    end
    return tostring(v)
  end

  if seen[v] then
    return '"<cycle>"'
  end

  if depth >= maxDepth then
    return '"<max-depth>"'
  end

  seen[v] = true

  local out = {}
  local count = 0

  for k, val in pairs(v) do
    count = count + 1
    if count > 100 then
      table.insert(out, '["<truncated>"]="too many keys"')
      break
    end

    local key
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
      key = k
    else
      key = "[" .. dumpValue(k, depth + 1, maxDepth, seen) .. "]"
    end

    table.insert(out, key .. "=" .. dumpValue(val, depth + 1, maxDepth, seen))
  end

  seen[v] = nil
  return "{" .. table.concat(out, ",") .. "}"
end

function ns.DumpToLog(name, value, maxDepth)
  ns.Log("DEBUG", "%s = %s", name, dumpValue(value, 0, maxDepth or 4, {}))
end
```

## S2.5 — Debugger pas-à-pas

Il n’y a pas de vrai `gdb`/`pdb` fiable dans le client WoW pour faire du pas-à-pas sur un add-on. Les pratiques réalistes restent : logs, `/dump`, `/script`, `debugstack()`, `xpcall`, DevTool, WowLua, et tests hors-jeu. Un fil ancien mais encore réaliste côté pratique résume que les devs utilisent surtout `/fstack`, `/etrace`, `/dump`, `/script` et des outils comme DevPad/WowLua plutôt qu’un debugger attaché au process. ([Reddit][6])

Pour les erreurs Lua, active :

```text
/console scriptErrors 1
```

Puis désactive hors session de dev :

```text
/console scriptErrors 0
```

Cette commande est couramment recommandée pour faire apparaître la fenêtre d’erreurs Lua. ([WowAce][7])

Wrapper d’erreur recommandé :

```lua
local function safeCall(label, fn, ...)
  local args = { ... }

  local function runner()
    return fn(unpack(args))
  end

  local function onError(err)
    return tostring(err) .. "\n" .. debugstack(3)
  end

  local ok, result = xpcall(runner, onError)

  if not ok then
    ns.Log("ERROR", "%s failed:\n%s", label, result)
  end

  return ok, result
end
```

Pour un vrai pas-à-pas hors client, **WoWBench** existe historiquement comme environnement qui remplace WoW et permet de rejouer des événements / utiliser un debugger Lua, mais il est ancien et son API simulée sera forcément incomplète pour Classic Era moderne. ([AddOn Studio][8])

## S2.6 — Profiler les performances

### Micro-benchmark ponctuel

`debugprofilestop()` fournit un timer haute précision en millisecondes ; malgré son nom, il ne “stoppe” pas le profiling. ([Warcraft Wiki][9])

```lua
function ns.Profile(label, fn, iterations)
  iterations = iterations or 1

  collectgarbage("collect")

  local t0 = debugprofilestop()
  for i = 1, iterations do
    fn()
  end
  local dt = debugprofilestop() - t0

  ns.Log("INFO", "PROFILE %s: %.3f ms total, %.3f ms/call",
    label,
    dt,
    dt / iterations
  )
end
```

Exemple :

```lua
ns.Profile("ResolveRecipeCost", function()
  ns.Cost.ResolveRecipeCost(4364)
end, 1000)
```

### Profiling add-on complet

Pour les métriques CPU par add-on, active le CVar `scriptProfile`, reload, puis utilise `UpdateAddOnCPUUsage()` / `GetAddOnCPUUsage()`. Le CVar `scriptProfile` active le profiling Lua et nécessite un reload ; `GetAddOnCPUUsage()` renvoie une valeur cachée calculée par `UpdateAddOnCPUUsage()`. ([Warcraft Wiki][10])

```text
/console scriptProfile 1
/reload
```

Puis :

```lua
UpdateAddOnCPUUsage()
local ms = GetAddOnCPUUsage("CraftGold")
print("CraftGold CPU:", ms, "ms")
```

À désactiver après diagnostic :

```text
/console scriptProfile 0
/reload
```

Pour une UI prête à l’emploi, **Addon Usage** supporte Retail, Classic et Classic TBC, et affiche mémoire + CPU si le profiling est activé. ([CurseForge][11])

### Profiling d’événements et frames

WoW expose aussi des métriques de CPU de frame/event/fonction dans l’ancienne famille de fonctions de profiling (`GetFrameCPUUsage`, `GetFunctionCPUUsage`, etc.), mais ces mesures peuvent attribuer le temps de manière contre-intuitive si plusieurs frames partagent le même handler. ([WoWWiki Archive][12])

## S2.7 — Surveiller les événements

### Solution native : `/etrace`

`/etrace` / `/eventtrace` ouvre EventTraceFrame et sert précisément à voir quels événements se déclenchent et dans quel ordre ; l’outil fait partie de Blizzard_DebugTools. ([Wowpedia][13])

```text
/etrace
```

### Solution à coder : event spy filtré

`Frame:RegisterAllEvents()` existe et force une frame à recevoir tous les événements, mais il est déconseillé hors debug à cause du coût potentiel. ([Warcraft Wiki][14])

```lua
function ns.EventSpyStart(pattern)
  if ns.eventSpy then
    ns.eventSpy:UnregisterAllEvents()
  end

  local f = CreateFrame("Frame")
  f:RegisterAllEvents()

  CraftGoldDB.eventspy = CraftGoldDB.eventspy or {
    enabled = true,
    max = 300,
    entries = {},
  }

  f:SetScript("OnEvent", function(_, event, ...)
    if pattern and not event:match(pattern) then
      return
    end

    local db = CraftGoldDB.eventspy
    local entry = {
      t = debugprofilestop(),
      event = event,
      args = { ... },
    }

    table.insert(db.entries, entry)

    while #db.entries > db.max do
      table.remove(db.entries, 1)
    end
  end)

  ns.eventSpy = f
  ns.Log("INFO", "EventSpy started: %s", pattern or "<all>")
end

function ns.EventSpyStop()
  if ns.eventSpy then
    ns.eventSpy:UnregisterAllEvents()
    ns.eventSpy:SetScript("OnEvent", nil)
    ns.eventSpy = nil
  end
  ns.Log("INFO", "EventSpy stopped")
end
```

Commandes :

```text
/cg events on GET_ITEM
/cg events off
/cg events dump
```

Pour ton cas `GetItemInfo`, tu peux filtrer :

```text
/cg events on ITEM|GET_ITEM
```

---

# S3 — Tests

## S3.8 — Framework de tests in-game

### Recommandation : garder ton runner maison

**Effort : déjà fait. Bénéfice : très élevé.**
Le marché n’a pas de framework in-game moderne dominant pour Classic Era. **WoWUnit** existe et son GitHub décrit un framework de tests unitaires avec UI, exécution sur événements, et mocking temporaire de variables ; mais une page CurseForge historique est très ancienne et marquée Retail, donc je ne l’utiliserais pas comme dépendance centrale sans vérification manuelle sur Classic Era 1.15.8. ([GitHub][15])

Le meilleur pattern pour CraftGold :

* logique pure testée hors-jeu avec `busted` ;
* intégration WoW testée en jeu avec `/cg test` ;
* résultats exportés dans SavedVariables.

`busted` supporte Lua 5.1 / LuaJIT et reste adapté aux modules purs hors WoW ; des gros add-ons Classic comme Questie documentent des prérequis de tests avec Lua 5.1, luarocks, luacheck, busted, etc. ([GitHub][16])

Runner in-game minimal :

```lua
ns.Tests = ns.Tests or {}

function ns.Test(name, fn)
  table.insert(ns.Tests, { name = name, fn = fn })
end

local function assertEq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertEq failed")
      .. ": expected=" .. tostring(expected)
      .. " actual=" .. tostring(actual), 2)
  end
end

ns.Assert = {
  eq = assertEq,
  truthy = function(v, message)
    if not v then error(message or "expected truthy value", 2) end
  end,
}

function ns.RunTests()
  local results = {
    startedAt = date("%Y-%m-%d %H:%M:%S"),
    passed = 0,
    failed = 0,
    cases = {},
  }

  for _, test in ipairs(ns.Tests) do
    local ok, err = xpcall(test.fn, debugstack)

    if ok then
      results.passed = results.passed + 1
      ns.Log("INFO", "PASS %s", test.name)
    else
      results.failed = results.failed + 1
      ns.Log("ERROR", "FAIL %s\n%s", test.name, err)
    end

    table.insert(results.cases, {
      name = test.name,
      ok = ok,
      error = ok and nil or err,
    })
  end

  CraftGoldDB.lastTestRun = results

  ns.Log("INFO", "Tests done: %d passed, %d failed",
    results.passed,
    results.failed
  )

  return results.failed == 0
end
```

Test :

```lua
ns.Test("money parser parses copper", function()
  ns.Assert.eq(ns.Money.Parse("12c"), 12)
end)
```

## S3.9 — Tests automatisés

Dans le client WoW, l’automatisation totale est limitée : les macros et add-ons peuvent lancer du Lua, mais pas se transformer en boucle CI autonome lisant/écrivant des fichiers en direct. Les macros sont utiles pour enchaîner des commandes, mais restent dans le modèle d’action utilisateur du client. ([Wowhead][17])

Macro de dev utile :

```text
/cg run log clear; test; log show
/reload
```

Ou, si tu veux forcer l’écriture disque après test :

```text
/cg run log clear; test
/reload
```

Le fichier SavedVariables sera alors lisible par l’agent après reload/logout, ce qui correspond au mécanisme normal de sauvegarde des SavedVariables. ([Warcraft Wiki][18])

---

# S4 — Interaction agent IA ↔ jeu

## S4.10 — Communication bidirectionnelle

### Meilleur pattern : fichier d’entrée fixe + SavedVariables de sortie

**Effort : faible à moyen. Bénéfice : énorme.**

`CraftGold.toc` :

```toc
## Interface: 11508
## Title: CraftGold
## SavedVariables: CraftGoldDB

Core.lua
Logger.lua
Tests.lua
DevInput.lua
CraftGold.lua
```

`DevInput.lua`, réécrit par l’agent :

```lua
local ADDON, ns = ...

ns.DevInput = {
  commands = {
    "log clear",
    "test",
    "dump db",
  },

  scenarios = {
    smoke = {
      "log clear",
      "test",
      "log show",
    },

    iteminfo = {
      "log clear",
      "events on GET_ITEM",
      "show engineering",
    },
  },
}
```

Puis en jeu :

```text
/cg devinput
/cg scenario smoke
/reload
```

C’est plus robuste qu’un collage chat, parce que tu peux faire écrire à l’agent des structures Lua longues, multi-lignes, versionnées, et testables. Attention : `/reload` recharge les fichiers déjà chargés, mais l’ajout de nouveaux fichiers ou d’un nouvel add-on peut nécessiter un redémarrage complet selon le comportement documenté de `ReloadUI`. ([AddOn Studio][19])

## S4.11 — Scénarios complexes

Tu as déjà `/cg run cmd1; cmd2; ...`. L’étape suivante est `/cg scenario <name>` :

```lua
function ns.RunScenario(name)
  local input = ns.DevInput or {}
  local scenarios = input.scenarios or {}
  local scenario = scenarios[name]

  if not scenario then
    ns.Log("ERROR", "Unknown scenario: %s", tostring(name))
    return
  end

  ns.Log("INFO", "Running scenario: %s", name)

  for _, command in ipairs(scenario) do
    ns.Log("DEBUG", "Scenario command: %s", command)
    ns.HandleSlash(command)
  end
end
```

Commande :

```text
/cg scenario smoke
/cg scenario iteminfo
```

Pour un script multi-ligne généré par l’agent, ne fais pas un `loadstring()` libre par défaut. Préfère une table déclarative `ns.DevInput.scenarios`, car c’est relisible dans Git, diffable, et beaucoup moins dangereux que l’exécution arbitraire.

Si tu veux quand même un mode `eval` réservé au dev :

```lua
function ns.DevEval(code)
  if not CraftGoldDB.dev or not CraftGoldDB.dev.allowEval then
    ns.Log("ERROR", "DevEval disabled")
    return
  end

  local fn, err = loadstring(code)
  if not fn then
    ns.Log("ERROR", "Compile error: %s", err)
    return
  end

  local ok, result = xpcall(fn, debugstack)
  if not ok then
    ns.Log("ERROR", "Runtime error: %s", result)
  else
    ns.Log("INFO", "Eval result: %s", tostring(result))
  end
end
```

## S4.12 — Capturer l’état complet du jeu/add-on

Ne tente pas de dumper `_G` complet : trop gros, cycles, objets userdata/frames, et pollution énorme. Capture plutôt :

```lua
function ns.CaptureState(label)
  CraftGoldDB.captures = CraftGoldDB.captures or {}

  local capture = {
    label = label or "manual",
    t = date("%Y-%m-%d %H:%M:%S"),
    version = GetAddOnMetadata and GetAddOnMetadata("CraftGold", "Version") or nil,
    db = CopyTable and CopyTable(CraftGoldDB) or CraftGoldDB,
    runtime = {
      cache = ns.cache,
      lastErrors = CraftGoldDB.devlog and CraftGoldDB.devlog.entries,
      itemInfoPending = ns.itemInfoPending,
    },
  }

  table.insert(CraftGoldDB.captures, capture)

  while #CraftGoldDB.captures > 10 do
    table.remove(CraftGoldDB.captures, 1)
  end

  ns.Log("INFO", "State captured: %s", capture.label)
end
```

Version plus sûre : ne copie pas tout `CraftGoldDB` dans lui-même, mais capture des sous-sections :

```lua
function ns.CaptureState(label)
  CraftGoldDB.captures = CraftGoldDB.captures or {}

  table.insert(CraftGoldDB.captures, {
    label = label or "manual",
    t = date("%Y-%m-%d %H:%M:%S"),
    saved = {
      settings = CraftGoldDB.settings,
      recipes = CraftGoldDB.recipes,
      lastTestRun = CraftGoldDB.lastTestRun,
    },
    runtime = {
      visible = ns.MainFrame and ns.MainFrame:IsShown() or false,
      pendingItems = ns.PendingItems,
    },
  })
end
```

---

# S5 — Macros WoW et automatisation

## S5.13 — Macros utiles pour le dev

Macros recommandées :

```text
# Reload
/reload
```

```text
# Active erreurs Lua
/console scriptErrors 1
/reload
```

```text
# Désactive erreurs Lua
/console scriptErrors 0
/reload
```

```text
# Test CraftGold
/cg run log clear; test; log show
```

```text
# Test + flush disque
/cg run log clear; test
/reload
```

```text
# Inspect DB
/dump CraftGoldDB
```

```text
# Event trace
/etrace
```

```text
# Frame stack
/fstack
```

`/fstack` sert à voir les frames sous le curseur et fait partie de Blizzard_DebugTools ; `GameTooltip:SetFrameStack()` et `C_System.GetFrameStack()` exposent aussi des informations de frame stack côté API selon build. ([Wowpedia][20])

## S5.14 — Macros conditionnelles

Les macros WoW acceptent des conditionnels pour les commandes qui supportent les secure command options, mais pas une logique arbitraire générale sur toutes les slash commands. Les pages “Macro conditionals” et “Secure command options” documentent ce système limité. ([Warcraft Wiki][21])

Donc ceci est naturel :

```text
/cast [mod:shift] Frostbolt; Fireball
```

Mais ceci n’est pas un vrai `if/then` universel pour tes commandes de dev :

```text
/cg [mod:shift] test; log show
```

Pour tes propres commandes, le meilleur pattern est de parser toi-même les modificateurs côté Lua :

```lua
function ns.DevSmartCommand()
  if IsShiftKeyDown() then
    ns.RunTests()
  elseif IsControlKeyDown() then
    ns.LogClear()
  else
    ns.ToggleMainWindow()
  end
end
```

Macro :

```text
/run CraftGold.DevSmartCommand()
```

Ou via ton namespace global contrôlé :

```lua
_G.CraftGold = _G.CraftGold or {}
_G.CraftGold.DevSmartCommand = function()
  ns.DevSmartCommand()
end
```

## S5.15 — Boutons d’action pour le dev

Très bon ROI : crée une petite toolbar flottante “dev”. Les boutons normaux `CreateFrame("Button", ..., "UIPanelButtonTemplate")` + `SetScript("OnClick")` suffisent pour tes commandes non protégées ; les exemples `CreateFrame` et `OnClick` sont standards dans l’API UI. ([Wowpedia][22])

```lua
function ns.CreateDevToolbar()
  if ns.DevToolbar then
    ns.DevToolbar:Show()
    return
  end

  local f = CreateFrame("Frame", "CraftGoldDevToolbar", UIParent, "BackdropTemplate")
  f:SetSize(360, 42)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 260)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  local buttons = {
    { text = "Test",  fn = function() ns.RunTests() end },
    { text = "Log",   fn = function() ns.HandleLogCommand({ "show" }) end },
    { text = "Clear", fn = function() ns.LogClear() end },
    { text = "Cap",   fn = function() ns.CaptureState("button") end },
    { text = "Reload", fn = function() ReloadUI() end },
  }

  local x = 8

  for _, spec in ipairs(buttons) do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(64, 24)
    b:SetPoint("LEFT", f, "LEFT", x, 0)
    b:SetText(spec.text)
    b:SetScript("OnClick", spec.fn)
    x = x + 68
  end

  ns.DevToolbar = f
end
```

Attention aux actions protégées et au combat lockdown : l’API WoW protège certaines actions pour imposer une décision humaine, surtout en combat ; `InCombatLockdown()` permet de détecter l’état de verrouillage. ([Warcraft Wiki][23])

---

# S6 — Comfort et productivité

## S6.16 — Auto-reload

### Dans WoW : non, pas de vrai auto-reload sur changement fichier

WoW ne surveille pas tes fichiers Lua pour recharger automatiquement l’UI. Le workflow normal reste : éditer → sauver → `/reload`. `ReloadUI` recharge l’interface, sauvegarde les réglages, et reprend les fichiers d’add-on déjà chargés ; les nouveaux fichiers ou nouveaux add-ons peuvent demander un redémarrage complet. ([AddOn Studio][19])

### Hors WoW : watcher utile, mais pas pour piloter le client

Ce qui a du sens :

* watcher externe qui lance `luacheck` / `busted` ;
* watcher qui met à jour `DevInput.lua` ;
* watcher qui lit `SavedVariables/CraftGold.lua` après `/reload`.

Exemple shell :

```bash
#!/usr/bin/env bash
set -euo pipefail

ADDON="$HOME/Games/World of Warcraft/_classic_era_/Interface/AddOns/CraftGold"
SV="$HOME/Games/World of Warcraft/_classic_era_/WTF/Account/<ACCOUNT>/SavedVariables/CraftGold.lua"

fswatch -o "$ADDON" | while read _; do
  echo "[watch] files changed"
  lua5.1 -e 'assert(loadfile("Core.lua"))' || true
  echo "[watch] run /reload in-game when ready"
done
```

Je déconseille l’envoi automatique de touches au client pour déclencher `/reload` : c’est fragile, dépend de l’OS/focus fenêtre, et ça mélange dev tooling avec automatisation du client.

## S6.17 — Éditeur Lua in-game

### WowLua

**WowLua** est un environnement Lua in-game avec interpréteur interactif et éditeur multi-pages ; CurseForge liste des saveurs Retail, MoP Classic, Classic et Classic TBC, avec mise à jour récente. ([CurseForge][24])

Usage : très bon pour prototyper une expression, tester une API, ou écrire un petit script exploratoire. Pas recommandé comme source principale du projet.

### TinyPad

**TinyPad** est un notepad in-game qui indique explicitement fonctionner en Retail, Classic Era et WotLK Classic ; il est utile pour stocker des snippets, commandes de test, notes d’événements, etc. ([CurseForge][25])

### _DevPad

**_DevPad** est un ancien outil d’édition/prototypage Lua in-game, mais WowAce le marque abandonné/non maintenu ; à éviter comme dépendance principale. ([WowAce][26])

## S6.18 — Snippets et templates utiles

### Template `ns` propre

Chaque fichier Lua d’un add-on reçoit `addonName, ns = ...`, et utiliser `ns` comme namespace partagé est un pattern reconnu pour éviter la pollution globale. ([Andy Dote][27])

```lua
local ADDON, ns = ...

ns.Core = ns.Core or {}
ns.UI = ns.UI or {}
ns.Tests = ns.Tests or {}
```

### Slash command dispatcher

```lua
SLASH_CRAFTGOLD1 = "/cg"

SlashCmdList.CRAFTGOLD = function(msg)
  ns.HandleSlash(msg or "")
end

function ns.HandleSlash(msg)
  local args = {}
  for token in msg:gmatch("%S+") do
    table.insert(args, token)
  end

  local cmd = table.remove(args, 1)

  if cmd == "log" then
    ns.HandleLogCommand(args)
  elseif cmd == "test" then
    ns.RunTests()
  elseif cmd == "scenario" then
    ns.RunScenario(args[1])
  elseif cmd == "devbar" then
    ns.CreateDevToolbar()
  else
    print("/cg log|test|scenario|devbar")
  end
end
```

### Multi-command runner

```lua
function ns.RunCommands(line)
  for command in tostring(line or ""):gmatch("[^;]+") do
    command = command:gsub("^%s+", ""):gsub("%s+$", "")
    if command ~= "" then
      ns.Log("DEBUG", "RUN: %s", command)
      ns.HandleSlash(command)
    end
  end
end
```

### Guard combat lockdown

```lua
function ns.RunOutOfCombat(label, fn)
  if InCombatLockdown and InCombatLockdown() then
    ns.Log("WARN", "%s skipped: in combat lockdown", label)
    return false
  end

  return safeCall(label, fn)
end
```

### Bug collector recommandé

Installe **BugGrabber + BugSack** pendant le dev : BugGrabber capture les erreurs Lua et les expose via `/buggrabber`, tandis que BugSack affiche les erreurs de session avec stack complète et permet de les copier/coller. ([CurseForge][28])

### Suite dev optionnelle

Si tu veux un bundle plus intégré, **DevSuite** est listé comme outil développeur WoW avec saveurs Retail, MoP Classic, Classic et Classic TBC, mis à jour en juin 2026 ; je le classerais “à essayer”, pas “à intégrer comme dépendance CraftGold”. ([CurseForge][29])

---

# Synthèse effort / bénéfice

| Priorité | Action                                                | Type                 | Effort |   Bénéfice |
| -------: | ----------------------------------------------------- | -------------------- | -----: | ---------: |
|        1 | Garder SavedVariables comme sortie agent              | À coder / workflow   | faible |     énorme |
|        2 | Ajouter niveaux `DEBUG/INFO/WARN/ERROR` + ring buffer | À coder              | faible |     énorme |
|        3 | Ajouter `DevInput.lua` fixe dans le `.toc`            | Workflow             | faible |     énorme |
|        4 | Ajouter `/cg scenario <name>`                         | À coder              | faible |     énorme |
|        5 | Installer BugGrabber + BugSack                        | Add-ons existants    | faible | très élevé |
|        6 | Installer DevTool                                     | Add-on existant      | faible | très élevé |
|        7 | Ajouter toolbar dev                                   | À coder              |  moyen |      élevé |
|        8 | Ajouter event spy filtré                              | À coder              |  moyen |      élevé |
|        9 | Utiliser `scriptProfile` + Addon Usage ponctuellement | Natif + add-on       | faible |      élevé |
|       10 | Tester WowLua/TinyPad pour snippets                   | Add-ons existants    | faible |      moyen |
|       11 | WoWBench / debugger hors-jeu complet                  | Outil externe ancien |  élevé |  incertain |

---

# Recommandation finale pour CraftGold

Ton architecture actuelle est déjà très bonne. Je ferais seulement ces ajouts :

```text
/cg log save debug
/cg log chat warn
/cg scenario <name>
/cg capture <label>
/cg events on <pattern>
/cg events off
/cg devbar
```

Et côté fichiers :

```text
CraftGold/
├── CraftGold.toc
├── Core.lua
├── Logger.lua
├── Tests.lua
├── EventSpy.lua
├── Capture.lua
├── DevInput.lua      # réécrit par l’agent IA
└── CraftGold.lua
```

Le duo gagnant pour ton agent IA est :

```text
Agent écrit DevInput.lua
→ joueur fait /reload
→ joueur lance /cg scenario smoke
→ joueur fait /reload
→ agent lit WTF/.../SavedVariables/CraftGold.lua
```

C’est simple, compatible Classic Era, robuste, et aligné avec les limites réelles du client WoW.

```
```

[1]: https://warcraft.wiki.gg/wiki/Category%3AAPI_systems/Log?utm_source=chatgpt.com "System: Log - Warcraft Wiki"
[2]: https://warcraft.wiki.gg/wiki/API_DevTools_Dump?utm_source=chatgpt.com "API DevTools Dump - Warcraft Wiki"
[3]: https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/AddOns/Blizzard_DebugTools/Blizzard_DebugTools.toc?utm_source=chatgpt.com "Blizzard_DebugTools.toc - AddOns"
[4]: https://www.wowinterface.com/forums/showthread.php?t=59599&utm_source=chatgpt.com "How to dump a table to the screen"
[5]: https://www.curseforge.com/wow/addons/varrendevtool?utm_source=chatgpt.com "ViragDevTool - World of Warcraft Addons"
[6]: https://www.reddit.com/r/WowUI/comments/2lpmff/help_what_debugging_tools_are_available_to/?utm_source=chatgpt.com "[Help] What debugging tools are available to developers?"
[7]: https://www.wowace.com/projects/rarity/pages/faq/how-to-enable-and-disable-script-errors-lua-errors?utm_source=chatgpt.com "FAQ/How to enable and disable script errors (\"Lua errors\")"
[8]: https://addonstudio.org/wiki/WoWBench?utm_source=chatgpt.com "WoWBench"
[9]: https://warcraft.wiki.gg/wiki/API_debugprofilestop?utm_source=chatgpt.com "debugprofilestop - Warcraft Wiki"
[10]: https://warcraft.wiki.gg/wiki/CVar_scriptProfile?utm_source=chatgpt.com "CVar scriptProfile - Warcraft Wiki"
[11]: https://www.curseforge.com/wow/addons/addon-usage?utm_source=chatgpt.com "Addon Usage - World of Warcraft Addons"
[12]: https://wowwiki-archive.fandom.com/wiki/World_of_Warcraft_API?utm_source=chatgpt.com "World of Warcraft API | WoWWiki"
[13]: https://wowpedia.fandom.com/wiki/MACRO_eventtrace?utm_source=chatgpt.com "MACRO eventtrace - Wowpedia - Fandom"
[14]: https://warcraft.wiki.gg/wiki/API_Frame_RegisterAllEvents?utm_source=chatgpt.com "Frame:RegisterAllEvents - Warcraft Wiki"
[15]: https://github.com/Jaliborc/WoWUnit?utm_source=chatgpt.com "Jaliborc/WoWUnit: A unit testing framework ..."
[16]: https://github.com/lunarmodules/busted?utm_source=chatgpt.com "lunarmodules/busted: Elegant Lua unit testing."
[17]: https://www.wowhead.com/guide/macro-writing-creating?utm_source=chatgpt.com "Macro Guide for World of Warcraft"
[18]: https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions?utm_source=chatgpt.com "Saving variables between game sessions - Warcraft Wiki"
[19]: https://addonstudio.org/wiki/WoW%3AAPI_ReloadUI?utm_source=chatgpt.com "WoW API: ReloadUI"
[20]: https://wowpedia.fandom.com/wiki/MACRO_framestack?utm_source=chatgpt.com "MACRO framestack - Wowpedia - Fandom"
[21]: https://warcraft.wiki.gg/wiki/Macro_conditionals?utm_source=chatgpt.com "Macro conditionals - Warcraft Wiki"
[22]: https://wowpedia.fandom.com/wiki/API_CreateFrame?utm_source=chatgpt.com "CreateFrame - Wowpedia - Your wiki guide to the World of ..."
[23]: https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting?utm_source=chatgpt.com "Secure Execution and Tainting - Warcraft Wiki"
[24]: https://www.curseforge.com/wow/addons/wowlua?utm_source=chatgpt.com "WowLua - Lua in Wow - World of Warcraft Addons"
[25]: https://www.curseforge.com/wow/addons/tinypad?utm_source=chatgpt.com "TinyPad - World of Warcraft Addons"
[26]: https://www.wowace.com/projects/devpad?utm_source=chatgpt.com "Overview - _DevPad - Addons - Projects"
[27]: https://andydote.co.uk/2014/11/23/good-design-in-warcraft-addons/?utm_source=chatgpt.com "Good Design in Warcraft Addons/Lua - Andy Dote"
[28]: https://www.curseforge.com/wow/addons/bug-grabber?utm_source=chatgpt.com "BugGrabber - World of Warcraft Addons"
[29]: https://www.curseforge.com/wow/addons/devsuite?utm_source=chatgpt.com "DevSuite Development Tool - World of Warcraft Addons"
