Je vais faire une recherche approfondie sur les outils de développement WoW Classic Era et vous proposer des solutions concrètes et sourcées.Je vois que les résultats de support ne sont pas pertinents (ils parlent de GitHub Copilot SDK, pas de WoW). Laissez-moi faire une recherche plus ciblée sur les patterns de développement WoW Classic.Voici une recherche exhaustive sur les outils de développement et QoL pour WoW Classic Era, avec des solutions concrètes pour chaque situation :

---

# 🎮 Outils de développement et QoL pour add-ons WoW Classic Era

## Vue d'ensemble du contexte

Vous avez déjà un workflow puissant avec logging SavedVariables et `/cg run`. Je vais couvrir ce qui existe nativement, ce que les add-ons font, et ce qu'il vaut la peine d'ajouter.

**Note importante sur Classic Era** : Les outils Retail comme `C_Profiler`, la Table Inspector avancée, ou certains CVars n'existent pas en Classic Era. Je vais spécifier les limitations.

---

## S1 — Logging et output

### 1. Logger dans un fichier lisible hors-jeu

**Votre approach SavedVariables est déjà optimale.** Voici pourquoi et comment l'améliorer :

**✅ Ce qui existe** (source: [WoW API Console.lua](https://github.com/Ellypse/IntelliJ-IDEA-Lua-IDE-WoW-API/blob/52f9dac3b701ac653ee2d2c1b500c2e5b1e506fe/APIs/Console.lua)):
- `ConsoleExec(command, addToHistory)` — Exécute une commande et stocke dans l'historique de la console
- `ConsoleAddMessage(message)` — Ajoute un message à la console
- `/dump` — Affiche dans le chat (limité : max 255 chars par ligne)

**⚠️ Limitation critique** : La console client de WoW **n'écrit pas sur disque automatiquement**. Vous devez passer par SavedVariables pour que l'agent IA puisse lire.

**Pattern amélioré** (effort: 5 lignes) :

```lua
-- Complément de votre système actuel
local function LogWithMetadata(message, category, level)
    -- Enrichir avec timestamp + contexte
    local entry = string.format(
        "[%s] %s [%s]: %s",
        date("%H:%M:%S"),
        level or "INFO",
        category or "APP",
        message
    )
    
    -- Appender à votre buffer SavedVariables existant
    table.insert(ns.WoW.logBuffer, entry)
end

-- Alias pour facilité
ns.log = function(msg, cat) LogWithMetadata(msg, cat, "INFO") end
ns.warn = function(msg, cat) LogWithMetadata(msg, cat, "WARN") end
ns.err = function(msg, cat) LogWithMetadata(msg, cat, "ERROR") end
```

**Source et référence** : [DandersFrames Debug Console](https://github.com/qyh214/wow_addons_private_use/blob/d947450afd9e241307f2daa3b7d955354e53b447/AddOns/DandersFrames/Debug/DebugConsole.lua#L95-L190) implémente exactement ce pattern avec `debugLog` stocké dans SavedVariables.

### 2. Logger avec des niveaux (DEBUG, INFO, WARN, ERROR)

**✅ Pattern existant avancé** :

```lua
-- Dans votre ns.WoW ou un nouveau module Debug
local DEBUG_LEVELS = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
}

local logBuffer = {}
local maxLines = 1000  -- Changer selon vos besoins
local minLogLevel = DEBUG_LEVELS.DEBUG  -- Dynamique via /cg log level

function ns.WoW.logEntry(level, category, message)
    if (DEBUG_LEVELS[level] or 0) < minLogLevel then
        return  -- Niveau filtré
    end
    
    local timestamp = date("%H:%M:%S")
    local entry = string.format(
        "[%s] %s %-8s %s",
        timestamp,
        category or "---",
        level,
        message
    )
    
    table.insert(logBuffer, entry)
    
    -- Circular buffer : limite max lines
    if #logBuffer > maxLines then
        table.remove(logBuffer, 1)
    end
    
    -- Persist to SavedVariables
    ns.WoW.savedVars.log = logBuffer
end
```

**Slash command** pour contrôler le niveau :

```lua
SlashCmdList["CGLOG"] = function(msg)
    local cmd, arg = msg:match("^([^ ]+)%s*(.*)$")
    if cmd == "level" then
        local level = arg:upper()
        if DEBUG_LEVELS[level] then
            minLogLevel = DEBUG_LEVELS[level]
            print("Log level: " .. level)
        end
    elseif cmd == "show" then
        for i, line in ipairs(logBuffer) do
            print(line)
        end
    end
end
SLASH_CGLOG1 = "/cg"
```

### 3. Activer/désactiver le logging à chaud

**Votre `/cg log on/off` fonctionne déjà.** Astuce supplémentaire pour garder l'état entre les reloads :

```lua
-- Dans votre module de slash commands
SlashCmdList["CGLOGCTRL"] = function(msg)
    local cmd = msg:lower():match("^(%w+)")
    
    if cmd == "on" then
        ns.WoW.loggingEnabled = true
        ns.WoW.savedVars.loggingEnabled = true
        print("Logging enabled")
    elseif cmd == "off" then
        ns.WoW.loggingEnabled = false
        ns.WoW.savedVars.loggingEnabled = false
        print("Logging disabled")
    elseif cmd == "clear" then
        wipe(logBuffer)
        ns.WoW.savedVars.log = {}
        print("Log buffer cleared")
    end
end
```

**Avantage** : SavedVariables persiste entre reloads, donc l'agent IA peut relire un même log après `/reload`.

---

## S2 — Debugging

### 4. Inspecter une table Lua en jeu

**Native (source: [Blizzard Dump.lua](https://github.com/fiskee/DoMeWhen-Classic/blob/5b556139e916ce5558804419ec2f82a7e374355d/Helpers/Dump.lua#L291-L395))** :
- `/dump MyTable` — Affiche la table dans le chat (format lisible, mais limité en profondeur)

**Limitation** : `/dump` coupe à une certaine profondeur et a une limite de 255 chars par ligne chat.

**Pattern Table Inspector en jeu** (effort: ~50 lignes) :

```lua
local function DumpTableRecursive(tbl, depth, maxDepth, seenTables, prefix)
    maxDepth = maxDepth or 5
    seenTables = seenTables or {}
    prefix = prefix or ""
    
    if depth > maxDepth then
        print(prefix .. "{...}")
        return
    end
    
    if seenTables[tbl] then
        print(prefix .. "{CIRCULAR}")
        return
    end
    seenTables[tbl] = true
    
    print(prefix .. "{")
    for k, v in pairs(tbl) do
        local key = type(k) == "string" and k or "["..tostring(k).."]"
        if type(v) == "table" then
            print(prefix .. "  " .. key .. " = ")
            DumpTableRecursive(v, depth+1, maxDepth, seenTables, prefix .. "    ")
        else
            print(prefix .. "  " .. key .. " = " .. tostring(v))
        end
    end
    print(prefix .. "}")
end

SlashCmdList["CGINSPECT"] = function(msg)
    local var = _G[msg]
    if var then
        print("Inspecting: " .. msg)
        DumpTableRecursive(var, 0, 3)
    else
        print("Variable not found: " .. msg)
    end
end
SLASH_CGINSPECT1 = "/inspect"
```

**Alternative** : Utiliser `/dump variable` natif pour la plupart des cas. Pour plus de contrôle, ajouter votre fonction ci-dessus.

### 5. Debugger pas-à-pas

⚠️ **WoW Classic Era n'a PAS de debugger Lua interactif** comme pdb en Python. Les options :

**A) Stack trace sur erreur** (natif) :

```lua
-- Activer via slash command
SlashCmdList["CGSTACKTRACE"] = function(msg)
    if msg == "on" then
        -- Wrapper autour de pcall pour capturer stack
        local originalPcall = pcall
        function _G.pcall(func, ...)
            local ok, result = originalPcall(func, ...)
            if not ok then
                print("ERROR: " .. tostring(result))
                print("STACK:\n" .. debugstack())
            end
            return ok, result
        end
        print("Stack tracing enabled")
    end
end
SLASH_CGSTACKTRACE1 = "/cg"
```

**B) Breakpoint manuel** (votre approche) :

```lua
function ns.debug.breakpoint(label)
    print("|cffff0000BREAKPOINT: " .. label .. "|r")
    print("STACK: " .. debugstack(2))
    -- Vous pouvez aussi logguer dans SavedVariables
    ns.WoW.logEntry("ERROR", "DEBUG", "BREAKPOINT: " .. label)
end

-- Utilisation
if some_condition then
    ns.debug.breakpoint("Before critical operation")
end
```

### 6. Profiler les performances

**✅ Native** (source: [Debugging.d.lua](https://github.com/SabineWren/wow-api-type-definitions/blob/79911d1f8411892dde07f862f089f62434db92cf/Client/Function/Debugging.d.lua#L1-L33)) :
- `debugprofilestart()` — Démarre un timer global
- `debugprofilestop()` — Retourne le temps en millisecondes

**Pattern de profiling** (effort: ~20 lignes) :

```lua
local benchmarks = {}

function ns.bench(label, func, ...)
    debugprofilestart()
    local result = func(...)
    local elapsed = debugprofilestop()
    
    table.insert(benchmarks, {
        label = label,
        ms = elapsed,
        timestamp = date("%H:%M:%S"),
    })
    
    print(string.format("[BENCH] %s: %.2fms", label, elapsed))
    return result
end

-- Afficher les résultats (pour l'agent IA)
function ns.bench.report()
    for _, entry in ipairs(benchmarks) do
        ns.log(string.format(
            "BENCH %s: %.2fms",
            entry.label,
            entry.ms
        ), "PERF")
    end
    return benchmarks
end
```

**⚠️ Important** : Il y a un bug connu où plusieurs appels à `debugprofilestart/stop` peuvent interférer. Solution : [wrapper de TellMeWhen](https://github.com/Naurplay/NaurClassicAddons/blob/eae5631e0ed41d0bd75c5496f48f62d1a2e3cb93/TellMeWhen/TellMeWhen.lua#L567-L682) pour compenser :

```lua
local startOld = debugprofilestart
local lastReset = 0

function _G.debugprofilestart()
    lastReset = lastReset + debugprofilestop()
    return startOld()
end

function _G.debugprofilestop_SAFE()
    return debugprofilestop() + lastReset
end
```

### 7. Surveiller les événements

**Pattern écoute universelle** (effort: ~30 lignes) :

```lua
local eventLog = {}
local eventFilters = {}  -- whitelist/blacklist

function ns.debug.SetEventFilter(eventName, enabled)
    eventFilters[eventName] = enabled ~= false
end

function ns.debug.ListenAllEvents()
    local frame = CreateFrame("Frame")
    
    -- Écouter TOUS les événements possibles
    local allEvents = {
        "ADDON_LOADED",
        "PLAYER_LOGIN",
        "PLAYER_ENTERING_WORLD",
        "QUEST_ACCEPTED",
        "QUEST_TURNED_IN",
        "COMBAT_LOG_EVENT",
        "CHAT_MSG_CHANNEL",
        -- ... ajouter selon vos besoins
    }
    
    for _, event in ipairs(allEvents) do
        frame:RegisterEvent(event)
    end
    
    frame:SetScript("OnEvent", function(self, event, ...)
        if eventFilters[event] == false then return end
        
        local timestamp = date("%H:%M:%S")
        local args = {...}
        
        table.insert(eventLog, {
            timestamp = timestamp,
            event = event,
            args = args,
        })
        
        -- Log pour agent
        ns.log(event .. " (" .. #args .. " args)", "EVENTS")
    end)
end

-- Slice des derniers N événements
function ns.debug.GetEventLog(count)
    count = count or 50
    local start = math.max(1, #eventLog - count + 1)
    return {table.unpack(eventLog, start)}
end
```

**Alternative simplifée** : Crochet directement dans votre event handler existant :

```lua
-- Si vous avez déjà un frame principal
localFrame = CreateFrame("Frame")
Frame:RegisterEvent("ADDON_LOADED")

Frame:SetScript("OnEvent", function(self, event, ...)
    -- Log systématique
    if not event:find("UPDATE") then  -- Ignorer les updates fréquents
        ns.debug.LogEvent(event)
    end
    
    -- Dispatch normal
    if event == "ADDON_LOADED" then
        -- ...
    end
end)
```

---

## S3 — Tests

### 8. Framework de tests in-game

**Vous avez déjà `/cg test`.** Voici comment l'étendre :

**Pattern assert/test structuré** (effort: ~40 lignes) :

```lua
ns.test = {}
ns.test.results = {}
ns.test.suites = {}

function ns.test.Assert(condition, message)
    table.insert(ns.test.results, {
        success = condition,
        message = message or "Assertion failed",
        timestamp = date("%H:%M:%S"),
    })
    
    if not condition then
        ns.log("ASSERT FAILED: " .. message, "TEST")
    end
end

function ns.test.AssertEqual(a, b, label)
    ns.test.Assert(a == b, 
        string.format("%s: expected %s, got %s",
            label or "equality check",
            tostring(b),
            tostring(a)
        )
    )
end

function ns.test.Suite(name)
    ns.test.results = {}
    return {
        name = name,
        test = function(label, fn)
            local ok, err = pcall(fn)
            if not ok then
                ns.test.Assert(false, label .. ": " .. err)
            end
        end,
        report = function()
            local passed = 0
            for _, r in ipairs(ns.test.results) do
                if r.success then passed = passed + 1 end
            end
            ns.log(
                string.format("%s: %d/%d passed",
                    ns.test.suites[name],
                    passed,
                    #ns.test.results
                ),
                "TEST"
            )
            return passed, #ns.test.results
        end
    }
end

-- Utilisation
local myTest = ns.test.Suite("core_logic")
myTest.test("should parse quest name", function()
    local result = ns.ParseQuestName("Quest: Goblin Camp")
    ns.test.AssertEqual(result, "Goblin Camp", "quest parse")
end)
myTest.report()
```

### 9. Tests automatisés

**Slash command** pour chaîner les tests :

```lua
SlashCmdList["CGTEST"] = function(msg)
    if msg == "run" then
        print("Running test suite...")
        
        -- Exécuter tous les tests
        ns.test.RunSuite("core_logic")
        ns.test.RunSuite("inventory")
        ns.test.RunSuite("combat")
        
        -- Sauvegarder résultats dans SavedVariables
        ns.WoW.savedVars.lastTestRun = {
            timestamp = date("%Y-%m-%d %H:%M:%S"),
            results = ns.test.GetAllResults(),
        }
        
        print("Test suite complete. Check logs with /cg log show")
    end
end
SLASH_CGTEST1 = "/cg"
```

**Macro pour auto-reload + test** :

```
/reload
/run local t = 0; local f = CreateFrame("Frame"); f:SetScript("OnUpdate", function() t = t + GetFrameTime(); if t > 1 then SlashCmdList["CGTEST"]("run") end end)
```

---

## S4 — Interaction agent IA ↔ jeu

### 10. Communication bidirectionnelle améliorée

Vous avez : agent → fichier → SavedVariables → agent

**Améliorations suggérées** (effort: ~20 lignes) :

```lua
-- A) Métadonnées enrichies dans SavedVariables
ns.WoW.savedVars.lastCommand = {
    command = "quest_accept",
    args = { questId = 12345 },
    startTime = GetTime(),
    status = "pending",  -- ou "success", "error"
    errorMessage = nil,
}

-- B) Pattern State Snapshot pour agent
function ns.GetStateSnapshot()
    return {
        player = {
            name = UnitName("player"),
            level = UnitLevel("player"),
            zone = GetZoneText(),
            subzone = GetSubZoneText(),
        },
        quest = {
            active = GetNumQuestLogEntries(),
            completed = C_QuestLog.GetNumCompletedQuests and C_QuestLog.GetNumCompletedQuests() or 0,
        },
        inventory = {
            usedSlots = GetContainerNumSlots(0),
            totalSlots = GetContainerNumSlots(0) + GetContainerNumSlots(1) + -- etc
        },
        timestamp = date("%Y-%m-%d %H:%M:%S"),
        gameTime = GetTime(),
    }
end

-- C) Persister dans SavedVariables
function ns.SnapshotState()
    ns.WoW.savedVars.stateSnapshot = ns.GetStateSnapshot()
end

-- Macro pour agent
SlashCmdList["CGSNAPSHOT"] = function()
    ns.SnapshotState()
    print("State snapshot saved to SavedVariables")
end
SLASH_CGSNAPSHOT1 = "/cg"
```

### 11. Exécuter des scénarios complexes

**Votre `/cg run cmd1; cmd2; ...` fonctionne. Amélioration : support script multi-ligne** :

```lua
function ns.ExecuteScenario(scenarioName)
    local scenario = ns.scenarios[scenarioName]
    if not scenario then
        print("Scenario not found: " .. scenarioName)
        return
    end
    
    -- Exécuter séquentiellement avec délai
    local stepIndex = 1
    local frame = CreateFrame("Frame")
    
    frame:SetScript("OnUpdate", function(self, elapsed)
        if stepIndex > #scenario then
            self:Hide()
            return
        end
        
        local step = scenario[stepIndex]
        
        if step.delay then
            step.delay = step.delay - elapsed
            if step.delay > 0 then return end
        end
        
        if type(step.action) == "function" then
            step.action()
        elseif type(step.action) == "string" then
            SlashCmdList["CGRUN"](step.action)  -- Re-use /cg run
        end
        
        stepIndex = stepIndex + 1
    end)
    frame:Show()
end

-- Définir scénarios dans SavedVariables ou un fichier
ns.scenarios = {
    test_quest_flow = {
        { action = "quest_accept 12345" },
        { action = "quest_progress", delay = 2 },
        { action = "quest_turn_in", delay = 1 },
    }
}
```

### 12. Capturer l'état complet du jeu

```lua
function ns.DumpFullState()
    local state = {
        -- SavedVariables
        savedVars = ns.WoW.savedVars,
        
        -- Runtime state
        addon = ns,
        
        -- UI state
        ui = {
            frames = {},  -- À completer selon vos besoins
        },
        
        -- Game state
        game = ns.GetStateSnapshot(),
        
        -- Logs
        logs = ns.WoW.logBuffer,
        
        timestamp = date("%Y-%m-%d %H:%M:%S"),
    }
    
    -- Sauvegarder en SavedVariables
    ns.WoW.savedVars.fullStateDump = state
    
    -- Optional : sérialiser en JSON pour agent (si vous avez une lib JSON)
    if ns.json then
        return ns.json.encode(state)
    end
    
    return state
end

SlashCmdList["CGDUMP"] = function()
    ns.DumpFullState()
    print("Full state dump saved to SavedVariables")
end
SLASH_CGDUMP1 = "/cg"
```

---

## S5 — Macros WoW et automatisation

### 13. Macros pour le dev

**Macro reload rapide** :
```
/reload
```

**Macro pour dump + log** :
```
/dump MyVariable
/cg log show
```

**Macro pour reset + test** :
```
/cg reset
/run local f = CreateFrame("Frame"); f:SetScript("OnUpdate", function(self, elapsed) self.t = self.t + elapsed; if self.t > 0.5 then SlashCmdList["CGTEST"]("run") end end); f.t = 0; f:Show()
```

**Macro pour toggle logging** :
```
/cg log on
```

### 14. Macros conditionnelles

**Exemple : log seulement en combat** :
```lua
local inCombat = false
local combatFrame = CreateFrame("Frame")

combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

combatFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        ns.loggingEnabled = true
    else
        inCombat = false
        ns.loggingEnabled = false
    end
end)
```

### 15. Boutons d'action pour le dev

```lua
-- Créer un panel de boutons pour dev
local devPanel = CreateFrame("Frame", "CGDevPanel", UIParent)
devPanel:SetSize(200, 150)
devPanel:SetPoint("TOPRIGHT", -10, -10)
devPanel:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
devPanel:SetBackdropColor(0, 0, 0, 0.8)

local buttons = {
    { name = "Reload", cmd = "/reload" },
    { name = "Run Tests", cmd = "/cg test run" },
    { name = "Toggle Log", cmd = "/cg log on" },
    { name = "Dump State", cmd = "/cg dump" },
    { name = "Clear", cmd = "/cg reset" },
}

local yOffset = -10
for i, btn in ipairs(buttons) do
    local button = CreateFrame("Button", "CGDevBtn"..i, devPanel, "UIPanelButtonTemplate")
    button:SetSize(180, 25)
    button:SetPoint("TOP", devPanel, "TOP", 0, yOffset)
    button:SetText(btn.name)
    button:SetScript("OnClick", function()
        SlashCmdList["CGRUN"](btn.cmd)
    end)
    yOffset = yOffset - 30
end

-- Toggle avec /cg panel
SlashCmdList["CGPANEL"] = function(msg)
    if devPanel:IsShown() then
        devPanel:Hide()
    else
        devPanel:Show()
    end
end
```

---

## S6 — Comfort et productivité

### 16. Auto-reload (impossible nativement)

⚠️ **WoW n'a pas de système natif de file watching**. Alternatives :

**A) Macro périodique** (à cliquer manuellement) :
```
/reload
```

**B) Script externe** (Python/Node.js sur votre machine) :
```python
#!/usr/bin/env python3
import os
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class AddonChangeHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.src_path.endswith('.lua'):
            os.system('open wow://console/reload')  # sur Mac

observer = Observer()
observer.schedule(AddonChangeHandler(), path='/path/to/addon', recursive=True)
observer.start()
```

**C) Pattern le plus simple : wrapper de /reload**

Vous relancez manuellement, mais rapidement via macro ou bouton.

### 17. Éditeur de code in-game

⚠️ **Pas faisable nativement en Classic Era.** Les options :

**A) VS Code + Live Reload** (externe) :
- Éditeur VS Code
- Script qui watch les changements
- Macro `/reload` automatique

**B) Éditeur Lua basique en UI** (effort: ~100 lignes, complexe) :

```lua
-- Frame d'édition avec ScrollingEditBox
local editorFrame = CreateFrame("Frame", "CGLuaEditor", UIParent)
editorFrame:SetSize(600, 400)
editorFrame:SetPoint("CENTER")
editorFrame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})

local editBox = CreateFrame("EditBox", nil, editorFrame)
editBox:SetMultiLine(true)
editBox:SetMaxLetters(50000)
editBox:SetWidth(580)
editBox:SetHeight(350)
editBox:SetPoint("TOPLEFT", 10, -30)

-- Save button
local saveBtn = CreateFrame("Button", nil, editorFrame, "UIPanelButtonTemplate")
saveBtn:SetSize(100, 25)
saveBtn:SetPoint("BOTTOMLEFT", 10, 5)
saveBtn:SetText("Save & Run")
saveBtn:SetScript("OnClick", function()
    local code = editBox:GetText()
    -- Sauvegarder dans SavedVariables
    ns.WoW.savedVars.customScript = code
    -- Exécuter
    local fn, err = loadstring(code)
    if fn then
        fn()
    else
        print("Error: " .. err)
    end
end)
```

### 18. Snippets et templates

**Pattern : Command templates pour tâches courantes** :

```lua
ns.templates = {
    quest_flow = [[
        local questId = %quest_id%
        AcceptQuest(questId)
        C_QuestLog.SetSelectedQuest(questId)
        -- TODO: progress logic
        TurnInQuest(questId)
    ]],
    
    inventory_check = [[
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local item = GetContainerItemLink(bag, slot)
                if item then
                    print(item)
                end
            end
        end
    ]],
    
    benchmark_fn = [[
        debugprofilestart()
        -- TODO: function to benchmark
        print(string.format("Time: %.2fms", debugprofilestop()))
    ]],
}

-- Slash command pour appliquer un template
SlashCmdList["CGTEMPLATE"] = function(msg)
    local template = ns.templates[msg]
    if template then
        editBox:SetText(template)
        editorFrame:Show()
    else
        print("Template not found: " .. msg)
    end
end
SLASH_CGTEMPLATE1 = "/cg"
```

---

## Tableau récapitulatif d'effort/bénéfice

| Situation | Solution | Effort | Bénéfice | Priorité |
|-----------|----------|--------|----------|----------|
| S1.1 | SavedVariables (existant) | 0 | ⭐⭐⭐⭐⭐ | ✅ |
| S1.2 | Logging par niveaux | 5 lignes | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| S1.3 | Toggle logging | 10 lignes | ⭐⭐⭐ | ✅ |
| S2.4 | Table dump avancée | 30 lignes | ⭐⭐⭐ | ⭐⭐ |
| S2.5 | Debugger (impossible) | N/A | ⭐ | ✖️ |
| S2.6 | Profiling | 20 lignes | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| S2.7 | Event monitoring | 30 lignes | ⭐⭐⭐⭐ | ⭐⭐ |
| S3.8 | Test framework | 40 lignes | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| S3.9 | Auto test suite | 20 lignes | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| S4.10 | State snapshot | 20 lignes | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| S4.11 | Scenario runner | 30 lignes | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| S4.12 | Full state dump | 20 lignes | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| S5.13-15 | Macros + buttons | 50 lignes | ⭐⭐⭐⭐ | ⭐⭐ |
| S6.16 | Auto reload | ⭐ (script externe) | ⭐⭐⭐ | ⭐⭐ |
| S6.17 | Editor in-game | 100+ lignes | ⭐⭐ | ✖️ (trop complexe) |
| S6.18 | Snippets | 30 lignes | ⭐⭐⭐ | ⭐⭐ |

---

## Sources citées

- [WoW API Console.lua](https://github.com/Ellypse/IntelliJ-IDEA-Lua-IDE-WoW-API/blob/52f9dac3b701ac653ee2d2c1b500c2e5b1e506fe/APIs/Console.lua)
- [Blizzard Dump.lua](https://github.com/fiskee/DoMeWhen-Classic/blob/5b556139e916ce5558804419ec2f82a7e374355d/Helpers/Dump.lua#L291-L395)
- [DandersFrames Debug Console](https://github.com/qyh214/wow_addons_private_use/blob/d947450afd9e241307f2daa3b7d955354e53b447/AddOns/DandersFrames/Debug/DebugConsole.lua#L95-L190)
- [Debugging API](https://github.com/SabineWren/wow-api-type-definitions/blob/79911d1f8411892dde07f862f089f62434db92cf/Client/Function/Debugging.d.lua)
- [TellMeWhen profiling wrapper](https://github.com/Naurplay/NaurClassicAddons/blob/eae5631e0ed41d0bd75c5496f48f62d1a2e3cb93/TellMeWhen/TellMeWhen.lua#L567-L682)

---

**Recommandation pour votre workflow agent** :

1. **Core** (déjà fait) : SavedVariables logging ✅
2. **Ajouter** : State snapshot (S4.10, 20 lignes) → agent analyse après chaque commande
3. **Ajouter** : Test framework (S3.8, 40 lignes) → validation automatique
4. **Optionnel** : Scenario runner (S4.11) → tests complexes multi-étapes

Cela vous donne une feedback loop complète : agent → code → test → log → agent lia