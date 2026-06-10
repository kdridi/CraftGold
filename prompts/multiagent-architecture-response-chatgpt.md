# Consultation multi-agents — Architecture d’un add-on WoW Classic Era en Lua

## Position de départ

Le bon compromis n’est **ni** “tout en single-file parce que les add-ons WoW font souvent comme ça”, **ni** “architecture hexagonale complète pour 120 lignes”.

Pour un projet pédagogique progressif, l’objectif est plutôt :

> Introduire très tôt une séparation simple entre **domaine pur**, **adaptateurs WoW**, **contrôleur d’add-on**, puis faire grandir cette structure sans changer de paradigme à chaque capsule.

L’architecture cible doit rester compatible avec WoW :

* pas de `require()`,
* pas de build,
* fichiers chargés par ordre dans le `.toc`,
* partage via `local addonName, ns = ...`,
* logique métier testable hors WoW,
* API WoW confinée dans quelques fichiers.

---

# Tour 1 — Propositions idéales

## Expert 1 — Le Puriste Testabilité

### Vision

> “Chaque fonction qui ne dépend pas de WoW doit être testable avec `lua tests.lua`. L’API WoW doit être vue comme une dépendance externe, donc injectée.”

Il propose une architecture en couches :

```text
CraftGold/
  CraftGold.toc
  Core/
    Domain.lua
    Defaults.lua
    Commands.lua
  Adapters/
    WowApi.lua
    SavedVars.lua
    Chat.lua
  App/
    App.lua
    Events.lua
```

### Principe

* `Domain.lua` contient uniquement des fonctions pures.
* `Commands.lua` transforme une commande texte en intention métier.
* `SavedVars.lua` lit/écrit les SavedVariables.
* `Chat.lua` encapsule `print`, `DEFAULT_CHAT_FRAME:AddMessage`, couleurs, etc.
* `Events.lua` branche `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_LOGOUT`.
* `App.lua` orchestre tout.

### Exemple mental

```lua
local result = ns.Domain.incrementCounter(state)
```

La fonction ne connaît ni WoW, ni `print`, ni SavedVariables.

```lua
function Domain.incrementCounter(state)
  return {
    count = (state.count or 0) + 1
  }
end
```

### Avantage

Très testable, très propre, très maintenable.

### Risque

Pour une capsule 03 de 120 lignes, c’est trop lourd. Le débutant risque de retenir “architecture compliquée” au lieu de comprendre SavedVariables et slash commands.

---

## Expert 2 — Le Pragmatiste WoW

### Vision

> “Un add-on WoW vit dans un environnement événementiel. Le code doit rester court, lisible, idiomatique. Trop d’abstraction rend le debug plus pénible.”

Il propose :

```text
CraftGold/
  CraftGold.toc
  CraftGold.lua
```

Ou, à partir d’une certaine taille :

```text
CraftGold/
  CraftGold.toc
  Core.lua
  UI.lua
```

### Pattern recommandé

Une seule table d’add-on :

```lua
local addonName, ns = ...
local Addon = {}
ns.Addon = Addon
```

Puis des méthodes :

```lua
function Addon:OnLoad()
end

function Addon:OnEvent(event, ...)
end

function Addon:Print(message)
  print("|cff00ff00CraftGold:|r " .. message)
end
```

### Avantage

C’est proche de ce que font beaucoup d’add-ons WoW : simple, direct, facile à lire, pas de “fausse architecture d’entreprise”.

### Risque

La logique métier finit vite mélangée avec :

* `CreateFrame`,
* `RegisterEvent`,
* slash commands,
* formatage,
* SavedVariables,
* UI.

À la capsule 10 ou 13, on se retrouve avec un fichier géant impossible à tester proprement.

---

## Expert 3 — Le Pédagogue Architecte

### Vision

> “L’architecture doit enseigner une idée par étape. La capsule 03 ne doit pas être parfaite, mais elle doit contenir les graines de la structure finale.”

Il propose une progression en trois phases.

### Phase A — Capsules 01-03

Single-file ou quasi single-file, mais déjà structuré par sections :

```lua
-- Namespace
-- Defaults
-- Pure logic
-- WoW adapters
-- Events
-- Slash commands
```

### Phase B — Capsules 04-06

Split léger :

```text
CraftGold.toc
Core.lua
UI.lua
Main.lua
```

### Phase C — Capsules 07-13

Architecture claire :

```text
CraftGold.toc
Core/State.lua
Core/Crafting.lua
Core/Money.lua
Adapters/Wow.lua
Adapters/Chat.lua
Adapters/SavedVars.lua
UI/MainWindow.lua
UI/ScrollList.lua
Main.lua
```

### Avantage

L’élève comprend pourquoi on extrait les fichiers au moment où la complexité apparaît.

### Risque

Si la progression est mal expliquée, les refactors successifs peuvent donner l’impression que l’architecture précédente était “fausse”.

---

# Tour 2 — Critiques croisées

## Le Puriste critique le Pragmatiste

> “Ton approche marche pour 80 lignes. Mais dès qu’on ajoute SavedVariables, calcul de coûts, scan de recettes, affichage, filtres et slash commands, le fichier devient un sac de nœuds.”

Il pointe trois dangers :

1. Les fonctions métier appellent directement `print`.
2. Les handlers d’événements modifient directement les données.
3. Les tests deviennent impossibles sans lancer WoW.

Exemple de mauvais mélange :

```lua
function Addon:Increment()
  CraftGoldDB.count = CraftGoldDB.count + 1
  print("Count: " .. CraftGoldDB.count)
end
```

Ici, une seule fonction fait trois choses :

* logique métier,
* persistance,
* affichage.

---

## Le Puriste critique le Pédagogue

> “Ta progression est bonne, mais il faut introduire l’idée de fonction pure très tôt. Sinon les élèves vont prendre de mauvaises habitudes dès la capsule 03.”

Il propose que même en single-file, on écrive déjà :

```lua
local function incrementCounter(state)
  return {
    count = state.count + 1
  }
end
```

plutôt que :

```lua
CraftGoldDB.count = CraftGoldDB.count + 1
```

---

## Le Pragmatiste critique le Puriste

> “Tu construis une cathédrale pour une cabane. En Lua/WoW, chaque indirection coûte de la lisibilité. Les débutants vont se perdre.”

Il critique notamment :

```lua
ns.adapters.chat.send(ns.ports.formatter.format(...))
```

Pour lui, cela devient ridicule dans un add-on pédagogique.

Il rappelle que dans WoW :

* le chargement est séquentiel,
* les erreurs de nommage sont fréquentes,
* plus il y a de fichiers, plus le `.toc` devient une source d’erreurs,
* il faut pouvoir taper `/reload` et comprendre vite ce qui casse.

---

## Le Pragmatiste critique le Pédagogue

> “OK pour progresser, mais ne faisons pas semblant qu’un add-on WoW est une application serveur. Il faut garder l’architecture plate le plus longtemps possible.”

Il préfère :

```text
Core.lua
UI.lua
Main.lua
```

à :

```text
Domain/
Application/
Infrastructure/
Presentation/
```

---

## Le Pédagogue critique le Puriste

> “Tu as raison techniquement, mais pédagogiquement tu vas trop vite. Avant d’enseigner l’injection de dépendances, il faut que l’élève ressente la douleur du couplage.”

Il propose de ne pas parler de “ports/adapters” au début, mais plutôt de mots simples :

* `Core` : ce qui calcule,
* `Wow` : ce qui parle au jeu,
* `UI` : ce qui affiche,
* `Main` : ce qui branche tout.

---

## Le Pédagogue critique le Pragmatiste

> “Ton approche est réaliste, mais elle reproduit exactement le problème qu’on veut éviter : les tutos WoW finissent souvent en gros fichier impératif.”

Il insiste sur un point :

> Le projet final s’appelle CraftGold. Il fera du calcul. Donc le cœur du projet doit être une logique de calcul testable hors WoW.

---

# Tour 3 — Compromis des experts

## Compromis du Puriste

Il accepte une architecture plus plate :

```text
Core.lua
Wow.lua
Main.lua
```

Mais impose une règle :

> Toute logique testable doit être dans `Core.lua`, sans appel WoW.

Exemple :

```lua
function Core.applyDefaults(db)
  db.count = db.count or 0
  db.version = db.version or 1
  return db
end
```

---

## Compromis du Pragmatiste

Il accepte de séparer les fonctions pures, mais refuse l’excès d’abstraction.

Il propose :

```text
CraftGold.toc
CraftGold_Core.lua
CraftGold_Wow.lua
CraftGold.lua
```

Avec convention simple :

* `Core` ne connaît pas WoW.
* `Wow` contient les fonctions pratiques autour de WoW.
* `CraftGold.lua` branche événements et commandes.

---

## Compromis du Pédagogue

Il propose une règle progressive :

* Capsule 01-03 : architecture en sections, puis extraction légère.
* Capsule 04-06 : `Core.lua`, `Ui.lua`, `Main.lua`.
* Capsule 07-13 : sous-dossiers seulement quand la taille le justifie.

Il recommande de présenter l’architecture comme une réponse à une douleur réelle :

> “On extrait `Core.lua` parce qu’on veut tester `applyDefaults` et `incrementCounter` sans lancer WoW.”

---

# Synthèse finale — Architecture recommandée

## Principe général

L’architecture recommandée est une architecture **Lua/WoW plate, modulaire, progressive** :

```text
CraftGold/
  CraftGold.toc
  CraftGold_Core.lua
  CraftGold_Wow.lua
  CraftGold.lua
```

Pour la capsule 03, c’est largement suffisant.

À ce stade, éviter :

```text
Domain/
Application/
Infrastructure/
Presentation/
```

C’est propre sur le papier, mais trop abstrait pour un add-on WoW débutant.

---

# Architecture capsule 03 recommandée

## Structure

```text
CraftGold/
  CraftGold.toc
  CraftGold_Core.lua
  CraftGold_Wow.lua
  CraftGold.lua
```

## Fichier `.toc`

```toc
## Interface: 11508
## Title: CraftGold
## Notes: Capsule 03 - SavedVariables, events and slash commands
## SavedVariables: CraftGoldDB

CraftGold_Core.lua
CraftGold_Wow.lua
CraftGold.lua
```

L’ordre est important :

1. `CraftGold_Core.lua` définit la logique pure.
2. `CraftGold_Wow.lua` définit les adaptateurs WoW.
3. `CraftGold.lua` branche le tout.

---

# Pattern central : `ns` comme namespace privé

Chaque fichier commence par :

```lua
local addonName, ns = ...
```

Puis il ajoute ses fonctions dans `ns`.

Exemple :

```lua
local addonName, ns = ...

ns.Core = ns.Core or {}
```

On évite de polluer `_G`.

La seule globale assumée ici est la SavedVariable :

```lua
CraftGoldDB
```

parce que WoW a besoin de ce nom global pour sauvegarder les données.

---

# Fichier `CraftGold_Core.lua`

Objectif : aucune dépendance à WoW.

```lua
local addonName, ns = ...

local Core = {}
ns.Core = Core

Core.DEFAULT_DB = {
  version = 1,
  count = 0,
}

local function copyDefaults(defaults, target)
  target = target or {}

  for key, value in pairs(defaults) do
    if target[key] == nil then
      if type(value) == "table" then
        target[key] = copyDefaults(value, {})
      else
        target[key] = value
      end
    elseif type(value) == "table" and type(target[key]) == "table" then
      copyDefaults(value, target[key])
    end
  end

  return target
end

function Core.applyDefaults(db)
  return copyDefaults(Core.DEFAULT_DB, db)
end

function Core.incrementCounter(db)
  db.count = (db.count or 0) + 1
  return db.count
end

function Core.resetCounter(db)
  db.count = 0
  return db.count
end

function Core.getCounter(db)
  return db.count or 0
end

function Core.parseCommand(input)
  input = input or ""
  input = input:lower():match("^%s*(.-)%s*$")

  if input == "" or input == "help" then
    return {
      kind = "help",
    }
  end

  if input == "inc" then
    return {
      kind = "increment",
    }
  end

  if input == "reset" then
    return {
      kind = "reset",
    }
  end

  if input == "count" then
    return {
      kind = "count",
    }
  end

  return {
    kind = "unknown",
    value = input,
  }
end
```

## Remarques

`Core` contient :

* les valeurs par défaut,
* la logique SavedVariables,
* le parsing de commande,
* les opérations métier.

Il ne contient pas :

* `print`,
* `CreateFrame`,
* `SLASH_...`,
* `RegisterEvent`,
* couleurs de chat,
* appels à l’API WoW.

C’est le cœur testable.

---

# Fichier `CraftGold_Wow.lua`

Objectif : regrouper les petites fonctions dépendantes de WoW.

```lua
local addonName, ns = ...

local Wow = {}
ns.Wow = Wow

function Wow.print(message)
  print("|cff00ff00CraftGold:|r " .. tostring(message))
end

function Wow.createEventFrame(onEvent)
  local frame = CreateFrame("Frame")

  frame:SetScript("OnEvent", function(_, event, ...)
    onEvent(event, ...)
  end)

  return frame
end

function Wow.registerSlashCommand(commandName, slash, handler)
  _G["SLASH_" .. commandName .. "1"] = slash
  SlashCmdList[commandName] = handler
end
```

## Remarques

Ce fichier reste volontairement simple.

On ne fait pas une abstraction énorme de toute l’API WoW. On encapsule seulement ce qui aide vraiment :

* afficher un message,
* créer une frame événementielle,
* enregistrer une slash command.

---

# Fichier `CraftGold.lua`

Objectif : orchestrer l’add-on.

```lua
local addonName, ns = ...

local Core = ns.Core
local Wow = ns.Wow

local Addon = {}
ns.Addon = Addon

Addon.name = addonName
Addon.db = nil
Addon.frame = nil

function Addon:InitDatabase()
  CraftGoldDB = Core.applyDefaults(CraftGoldDB)
  self.db = CraftGoldDB
end

function Addon:PrintHelp()
  Wow.print("Commands:")
  Wow.print("/cg help  - show help")
  Wow.print("/cg inc   - increment counter")
  Wow.print("/cg count - show counter")
  Wow.print("/cg reset - reset counter")
end

function Addon:HandleCommand(input)
  local command = Core.parseCommand(input)

  if command.kind == "help" then
    self:PrintHelp()
    return
  end

  if command.kind == "increment" then
    local count = Core.incrementCounter(self.db)
    Wow.print("Counter incremented: " .. count)
    return
  end

  if command.kind == "count" then
    Wow.print("Counter: " .. Core.getCounter(self.db))
    return
  end

  if command.kind == "reset" then
    Core.resetCounter(self.db)
    Wow.print("Counter reset.")
    return
  end

  Wow.print("Unknown command: " .. tostring(command.value))
  Wow.print("Type /cg help")
end

function Addon:OnAddonLoaded(loadedAddonName)
  if loadedAddonName ~= addonName then
    return
  end

  self:InitDatabase()
  Wow.print("Loaded. Type /cg help.")
end

function Addon:OnPlayerLogout()
  -- Optional hook.
  -- WoW saves SavedVariables automatically on logout/reload.
  -- This is a good place to finalize transient values if needed.
end

function Addon:OnEvent(event, ...)
  if event == "ADDON_LOADED" then
    self:OnAddonLoaded(...)
    return
  end

  if event == "PLAYER_LOGOUT" then
    self:OnPlayerLogout()
    return
  end
end

function Addon:Start()
  self.frame = Wow.createEventFrame(function(event, ...)
    self:OnEvent(event, ...)
  end)

  self.frame:RegisterEvent("ADDON_LOADED")
  self.frame:RegisterEvent("PLAYER_LOGOUT")

  Wow.registerSlashCommand("CRAFTGOLD", "/cg", function(input)
    self:HandleCommand(input)
  end)
end

Addon:Start()
```

---

# Pourquoi cette architecture est propre

## 1. La logique métier est isolée

Tout ceci est testable hors WoW :

```lua
Core.applyDefaults(db)
Core.incrementCounter(db)
Core.resetCounter(db)
Core.getCounter(db)
Core.parseCommand(input)
```

## 2. WoW est confiné

Les appels WoW sont ici :

```lua
CreateFrame
RegisterEvent
SetScript
SlashCmdList
SLASH_...
print
```

Ils sont regroupés dans `CraftGold_Wow.lua` ou dans l’orchestration finale.

## 3. L’architecture reste idiomatique Lua

On utilise :

* des tables,
* des fonctions,
* `ns`,
* `local`,
* chargement séquentiel,
* pas de classes artificielles,
* pas de `require`,
* pas de simulation de framework.

## 4. Elle reste pédagogique

La capsule 03 peut expliquer :

> “On extrait `Core` parce qu’on veut tester les règles sans WoW.”

C’est beaucoup plus concret que :

> “Voici une architecture hexagonale.”

---

# Conventions de nommage recommandées

## Tables principales

```lua
ns.Core
ns.Wow
ns.UI
ns.Addon
```

## Fichiers

Pour les capsules simples :

```text
CraftGold_Core.lua
CraftGold_Wow.lua
CraftGold.lua
```

Puis plus tard :

```text
CraftGold_UI.lua
CraftGold_Crafting.lua
CraftGold_Money.lua
CraftGold_Recipes.lua
```

Pour le projet final, quand le nombre de fichiers augmente :

```text
Core/State.lua
Core/Money.lua
Core/Crafting.lua
Data/Recipes.lua
UI/MainWindow.lua
UI/RecipeList.lua
Adapters/Wow.lua
Main.lua
```

Mais seulement quand cela devient nécessaire.

## Fonctions

Pour les fonctions pures :

```lua
Core.applyDefaults
Core.parseCommand
Core.computeCraftCost
Core.formatMoney
Core.normalizeItem
```

Pour les fonctions dépendantes de WoW :

```lua
Wow.print
Wow.createEventFrame
Wow.registerSlashCommand
Wow.getItemInfo
Wow.getAuctionPrice
```

Pour l’orchestration :

```lua
Addon:Start()
Addon:OnEvent()
Addon:HandleCommand()
Addon:InitDatabase()
```

## Style recommandé

Préférer :

```lua
function Core.incrementCounter(db)
  db.count = (db.count or 0) + 1
  return db.count
end
```

Éviter :

```lua
function IncrementCounter()
  CraftGoldDB.count = CraftGoldDB.count + 1
  print(CraftGoldDB.count)
end
```

La première version est testable. La seconde est couplée à `_G`, aux SavedVariables et au chat.

---

# Faut-il utiliser des metatables ?

## Capsule 03

Non.

Pour 120 lignes, les metatables n’apportent rien.

Éviter :

```lua
Addon.__index = Addon

function Addon:new()
  return setmetatable({}, self)
end
```

C’est inutilement complexe pour ce stade.

## Capsules 04-06

Toujours pas nécessaire, sauf pour des composants UI répétables.

## Capsules 07-13

Possible, mais avec parcimonie.

Cas légitime :

```lua
local RecipeList = {}
RecipeList.__index = RecipeList

function RecipeList.new(parent)
  local self = setmetatable({}, RecipeList)
  self.parent = parent
  self.rows = {}
  return self
end
```

Les metatables deviennent utiles quand on crée plusieurs instances d’un même composant :

* lignes de tableau,
* widgets UI,
* objets de vue,
* cache spécialisé.

Mais pour `Addon`, une simple table suffit.

---

# Pattern recommandé pour les SavedVariables

## À éviter

```lua
CraftGoldDB = CraftGoldDB or {}
CraftGoldDB.count = CraftGoldDB.count or 0
```

répété partout.

## À préférer

Centraliser dans `Core.applyDefaults` :

```lua
function Addon:InitDatabase()
  CraftGoldDB = Core.applyDefaults(CraftGoldDB)
  self.db = CraftGoldDB
end
```

Puis partout ailleurs :

```lua
Core.incrementCounter(self.db)
```

Ainsi, le reste du code ne dépend pas directement du nom global `CraftGoldDB`.

---

# Pattern recommandé pour les slash commands

## À éviter

```lua
SLASH_CRAFTGOLD1 = "/cg"
SlashCmdList["CRAFTGOLD"] = function(msg)
  if msg == "inc" then
    CraftGoldDB.count = CraftGoldDB.count + 1
    print(CraftGoldDB.count)
  end
end
```

## À préférer

Séparer parsing, décision et effet :

```lua
function Core.parseCommand(input)
  -- pur, testable
end

function Addon:HandleCommand(input)
  -- orchestration
end

Wow.registerSlashCommand("CRAFTGOLD", "/cg", function(input)
  Addon:HandleCommand(input)
end)
```

Cela permet de tester :

```lua
local command = Core.parseCommand("inc")
assert(command.kind == "increment")
```

sans lancer WoW.

---

# Pattern recommandé pour les événements

## Simple et lisible

```lua
function Addon:OnEvent(event, ...)
  if event == "ADDON_LOADED" then
    self:OnAddonLoaded(...)
    return
  end

  if event == "PLAYER_LOGOUT" then
    self:OnPlayerLogout()
    return
  end
end
```

Pour la capsule 03, éviter une table de dispatch trop abstraite.

## Plus tard, si les événements se multiplient

À partir de 8-10 événements :

```lua
Addon.eventHandlers = {}

Addon.eventHandlers.ADDON_LOADED = function(self, loadedAddonName)
  self:OnAddonLoaded(loadedAddonName)
end

Addon.eventHandlers.PLAYER_LOGOUT = function(self)
  self:OnPlayerLogout()
end

function Addon:OnEvent(event, ...)
  local handler = self.eventHandlers[event]

  if handler then
    handler(self, ...)
  end
end
```

Mais ce n’est pas nécessaire au début.

---

# Tests unitaires pratiques

## Objectif

Ne pas tester WoW.

On teste seulement :

* defaults,
* parsing de commande,
* calculs,
* transformation de données,
* formatage pur,
* algorithmes de coût de craft.

## Structure de test simple

```text
CraftGold/
  CraftGold_Core.lua
  tests/
    test_core.lua
```

Mais attention : `CraftGold_Core.lua` attend normalement :

```lua
local addonName, ns = ...
```

Dans WoW, `...` est fourni automatiquement.

Hors WoW, on peut charger le fichier avec `loadfile` et passer nous-mêmes les arguments.

## Exemple `tests/test_core.lua`

```lua
local ns = {}

local chunk = assert(loadfile("../CraftGold_Core.lua"))
chunk("CraftGold", ns)

local Core = ns.Core

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error((message or "assertEqual failed")
      .. "\nexpected: " .. tostring(expected)
      .. "\nactual:   " .. tostring(actual))
  end
end

local function test_apply_defaults()
  local db = Core.applyDefaults(nil)

  assertEqual(db.version, 1, "default version")
  assertEqual(db.count, 0, "default count")
end

local function test_increment_counter()
  local db = Core.applyDefaults(nil)

  local count = Core.incrementCounter(db)

  assertEqual(count, 1, "returned count")
  assertEqual(db.count, 1, "stored count")
end

local function test_parse_command_inc()
  local command = Core.parseCommand("inc")

  assertEqual(command.kind, "increment", "parse inc")
end

local function test_parse_command_trim_and_lower()
  local command = Core.parseCommand("  InC  ")

  assertEqual(command.kind, "increment", "parse inc with spaces and uppercase")
end

local function test_parse_unknown_command()
  local command = Core.parseCommand("banana")

  assertEqual(command.kind, "unknown", "unknown command kind")
  assertEqual(command.value, "banana", "unknown command value")
end

test_apply_defaults()
test_increment_counter()
test_parse_command_inc()
test_parse_command_trim_and_lower()
test_parse_unknown_command()

print("All tests passed.")
```

Lancement :

```bash
cd CraftGold/tests
lua test_core.lua
```

## Pourquoi cette méthode est bonne

Elle respecte les contraintes :

* pas de `require`,
* pas de framework,
* pas de WoW,
* pas de build,
* pas de dépendance externe.

Et elle enseigne une idée très importante :

> Un fichier Lua WoW peut aussi être exécuté hors de WoW si ses dépendances sont contrôlées.

---

# Variante : rendre `Core.lua` encore plus testable

Si on veut rendre le fichier compatible WoW et Lua standard encore plus proprement, on peut faire :

```lua
local addonName, ns = ...

ns = ns or {}

local Core = {}
ns.Core = Core
```

Mais dans WoW, `ns` existera toujours.

Pour les tests, il vaut mieux passer explicitement `ns` :

```lua
chunk("CraftGold", ns)
```

plutôt que rendre le code trop défensif.

---

# Progression recommandée des capsules 03 à 13

## Capsule 03 — SavedVariables + slash commands

Structure :

```text
CraftGold_Core.lua
CraftGold_Wow.lua
CraftGold.lua
```

Concepts enseignés :

* namespace `ns`,
* SavedVariables globales,
* defaults,
* slash commands,
* événement `ADDON_LOADED`,
* séparation minimale entre logique et WoW,
* premier test hors WoW.

---

## Capsule 04 — Première frame UI

Ajouter :

```text
CraftGold_UI.lua
```

Structure :

```text
CraftGold_Core.lua
CraftGold_Wow.lua
CraftGold_UI.lua
CraftGold.lua
```

`UI` peut dépendre de WoW. Ce n’est pas du domaine pur.

Exemple :

```lua
function ns.UI.createMainFrame(parent)
  local frame = CreateFrame("Frame", "CraftGoldFrame", parent, "BasicFrameTemplateWithInset")
  return frame
end
```

Règle pédagogique :

> L’UI peut appeler WoW. Le Core ne doit toujours pas appeler WoW.

---

## Capsule 05 — Boutons et interactions

Ajouter des callbacks UI, mais garder les actions dans `Addon`.

Mauvais :

```lua
button:SetScript("OnClick", function()
  CraftGoldDB.count = CraftGoldDB.count + 1
end)
```

Meilleur :

```lua
button:SetScript("OnClick", function()
  Addon:IncrementCounter()
end)
```

Puis :

```lua
function Addon:IncrementCounter()
  local count = Core.incrementCounter(self.db)
  self.ui:SetCounter(count)
end
```

---

## Capsule 06 — Scroll / liste

On introduit des composants UI plus propres :

```text
CraftGold_UI.lua
CraftGold_ListView.lua
```

Ou :

```text
UI/MainFrame.lua
UI/ListView.lua
```

Seulement si le nombre de fichiers devient justifié.

Concept enseigné :

> Un composant UI peut être une table Lua avec des fonctions.

---

## Capsule 07 — Données de jeu

Ajouter :

```text
CraftGold_Data.lua
```

ou :

```text
Data/Recipes.lua
```

Règle :

* les données statiques peuvent vivre dans `ns.Data`,
* les fonctions de calcul restent dans `ns.Core` ou `ns.Crafting`.

---

## Capsule 08 — Modèle économique / argent

Ajouter :

```text
CraftGold_Money.lua
```

Exemples de fonctions pures :

```lua
Money.fromCopper(copper)
Money.toText(copper)
Money.add(a, b)
Money.subtract(a, b)
```

Très bon candidat pour tests unitaires.

---

## Capsule 09 — Calcul de coût de craft

Ajouter :

```text
CraftGold_Crafting.lua
```

Exemple :

```lua
function Crafting.computeCost(recipe, prices)
  local total = 0

  for _, reagent in ipairs(recipe.reagents) do
    local unitPrice = prices[reagent.itemId] or 0
    total = total + unitPrice * reagent.count
  end

  return total
end
```

C’est le cœur de CraftGold. Il doit être 100 % testable hors WoW.

---

## Capsule 10 — Intégration API WoW

Ajouter dans `Wow.lua` des wrappers spécifiques :

```lua
function Wow.getItemInfo(itemId)
  return GetItemInfo(itemId)
end
```

Mais éviter de wrapper tout WoW par principe.

Règle :

> On wrappe quand ça aide à tester ou à centraliser une différence WoW/API. On ne wrappe pas pour faire joli.

---

## Capsule 11 — Cache et état applicatif

Ajouter :

```text
CraftGold_State.lua
```

ou intégrer dans `Core`.

Exemple :

```lua
State.create()
State.setPrice(state, itemId, copper)
State.getPrice(state, itemId)
```

---

## Capsule 12 — Assemblage final

Structure possible :

```text
CraftGold.toc
Core/Defaults.lua
Core/Money.lua
Core/Crafting.lua
Core/Commands.lua
Data/Recipes.lua
Adapters/Wow.lua
Adapters/Chat.lua
UI/MainFrame.lua
UI/RecipeList.lua
Main.lua
```

À ce stade, les sous-dossiers deviennent légitimes.

---

## Capsule 13 — Projet final CraftGold

Architecture finale recommandée :

```text
CraftGold/
  CraftGold.toc

  Core/
    Defaults.lua
    Money.lua
    Commands.lua
    Crafting.lua
    State.lua

  Data/
    Recipes.lua

  Adapters/
    Wow.lua
    Chat.lua
    SavedVars.lua

  UI/
    MainFrame.lua
    RecipeList.lua
    PriceEditor.lua

  Main.lua

  tests/
    test_money.lua
    test_crafting.lua
    test_commands.lua
```

Mais cette structure ne doit apparaître qu’une fois que l’élève comprend pourquoi elle existe.

---

# Règles d’or finales

## Règle 1

`Core` ne connaît pas WoW.

Interdit dans `Core` :

```lua
CreateFrame
print
DEFAULT_CHAT_FRAME
SlashCmdList
C_Timer
GetItemInfo
```

---

## Règle 2

Les SavedVariables sont initialisées une seule fois.

```lua
function Addon:InitDatabase()
  CraftGoldDB = Core.applyDefaults(CraftGoldDB)
  self.db = CraftGoldDB
end
```

Ensuite, le reste du code utilise :

```lua
self.db
```

pas directement :

```lua
CraftGoldDB
```

---

## Règle 3

Les slash commands ne contiennent pas de logique métier.

Elles appellent seulement :

```lua
Addon:HandleCommand(input)
```

---

## Règle 4

L’UI ne calcule pas.

Mauvais :

```lua
button:SetScript("OnClick", function()
  local total = price * count
  text:SetText(total)
end)
```

Meilleur :

```lua
button:SetScript("OnClick", function()
  Addon:RefreshCraftCost()
end)
```

---

## Règle 5

Les tests ciblent le domaine, pas WoW.

Tester :

```lua
Core.parseCommand
Money.toText
Crafting.computeCost
Core.applyDefaults
```

Ne pas tester directement :

```lua
CreateFrame
RegisterEvent
SlashCmdList
```

---

# Décision finale

L’architecture recommandée est :

```text
CraftGold_Core.lua
CraftGold_Wow.lua
CraftGold.lua
```

pour la capsule 03.

Puis :

```text
CraftGold_Core.lua
CraftGold_Wow.lua
CraftGold_UI.lua
CraftGold.lua
```

pour les capsules UI.

Puis, seulement vers les capsules 09-13 :

```text
Core/
Adapters/
UI/
Data/
Main.lua
```

Cette architecture est le meilleur compromis parce qu’elle est :

* compatible WoW,
* idiomatique Lua,
* testable hors WoW,
* lisible pour un développeur expérimenté,
* progressive pour un débutant,
* assez simple pour une capsule 03,
* assez solide pour grandir jusqu’à CraftGold.

La phrase pédagogique à marteler est :

> “On ne sépare pas les fichiers pour faire joli. On les sépare quand cela permet de tester, comprendre, remplacer ou faire évoluer une responsabilité précise.”
