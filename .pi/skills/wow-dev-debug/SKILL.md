---
name: wow-dev-debug
description: WoW Classic Era debugging tools and patterns. Activate when the user encounters an error, needs to inspect game state, debug an event, profile performance, or wants to explore WoW internals. Covers native commands (/dump, /etrace, /fstack, /tinspect, /console scriptErrors), third-party add-ons (BugSack, DevTool), logging patterns, and Lua debugging techniques specific to WoW add-on development.
---

# WoW Dev Debug — Outils et patterns de debugging

## Quand activer ce skill

L'utilisateur rencontre l'une de ces situations :
- **Erreur Lua** → erreur en jeu, crash d'add-on, comportement inattendu
- **Inspection** → veut voir le contenu d'une table, l'état d'une variable, d'une frame
- **Événements** → veut savoir quel événement se déclenche, quand, avec quels args
- **Performance** → quelque chose est lent, veut profiler
- **Exploration** → veut comprendre comment fonctionne l'API, une frame, un widget
- **State dump** → veut capturer l'état pour l'agent IA

## Outils natifs WoW (rien à installer)

### Commandes chat natives

| Commande | Usage | Exemple |
|----------|-------|---------|
| `/dump <expr>` | Évalue une expression Lua et l'affiche | `/dump ns.DB.recipes` |
| `/run <code>` ou `/script <code>` | Exécute du Lua arbitraire | `/run print(GetTime())` |
| `/reload` | Recharge l'UI et les add-ons | — |
| `/etrace` | Ouvre le traceur d'événements en temps réel | — |
| `/fstack` | Frame Stack : survol visuel des frames under cursor | `/fstack` puis déplacer la souris |
| `/tinspect` | Table Inspector : inspecte une table ou le widget sous la souris | `/tinspect ns.DB` |
| `/console scriptErrors 1` | Active la popup d'erreurs Lua | À activer en permanence en dev |
| `/console scriptErrors 0` | Désactive la popup | — |

### /etrace — Event Tracer

**Quand l'utiliser** : "Quel événement se déclenmente quand je fais X ?"

1. `/etrace` → ouvre la fenêtre
2. Faire l'action en jeu
3. Lire les événements dans la fenêtre
4. `/etrace mark TEST` → pose un marqueur texte dans le log
5. Fermer la fenêtre pour arrêter

**Variante** : filtrer en tapant dans la zone de texte (ex: `ITEM` pour ne voir que les événements `ITEM_*`)

### /fstack — Frame Stack

**Quand l'utiliser** : "Quelle frame est sous ma souris ? Comment est-elle construite ?"

1. `/fstack` → active le survol
2. Déplacer la souris sur l'élément à inspecter
3. `ALT gauche/droite` → navigue entre les frames highlightées
4. `CTRL` → ouvre le Table Inspector sur la frame sélectionnée
5. `SHIFT` → toggle texture information
6. `CTRL+C` → copie des infos texture
7. La variable globale `fsobj` contient la dernière frame sélectionnée

### /tinspect — Table Inspector

**Quand l'utiliser** : "Je veux explorer une table Lua en profondeur"

1. `/tinspect ns.DB` → inspecte la table `ns.DB`
2. `/tinspect` (sans args) → inspecte le widget UI sous la souris
3. Naviguer dans l'arbre, cliquer pour expandre

### /dump — Quick inspect

**Quand l'utiliser** : "Quick check d'une valeur dans le chat"

- `/dump ns.Prices.getAll()` → affiche la table des prix
- `/dump GetMouseFocus():GetName()` → nom de la frame sous la souris
- `/dump select(4, GetBuildInfo())` → version de l'interface

### Fonctions Lua de debug

| Fonction | Usage |
|----------|-------|
| `debugstack(level)` | Stack trace à partir du niveau donné |
| `debuglocals(level)` | Variables locales au niveau donné |
| `debugprofilestart()` | Démarre un timer (ms) |
| `debugprofilestop()` | Retourne le temps écoulé depuis le dernier start |
| `pcall(fn, ...)` | Appel protégé, retourne ok, result |
| `xpcall(fn, errorHandler)` | pcall avec handler custom |

## Add-ons tiers à installer

### Obligatoires (dev)

| Add-on | Pourquoi | Source |
|--------|----------|--------|
| **BugSack** + **BugGrabber** | Capture et affiche les erreurs Lua avec stack complète | CurseForge |
| **DevTool** | Inspection visuelle de tables, events, appels de fonction | CurseForge |

### Recommandés

| Add-on | Pourquoi | Source |
|--------|----------|--------|
| **WowLua** | Éditeur/REPL Lua in-game pour prototyper des snippets | CurseForge / WoWInterface |

## Patterns de debugging CraftGold

### Pattern 1 — Logger structuré dans SavedVariables

Notre add-on a déjà `/cg log on/off/clear/show` qui capture l'output dans les SavedVariables.
Après `/reload`, l'agent peut lire le fichier `WTF/Account/.../SavedVariables/ManualListings.lua`.

**Amélioration à venir** : niveaux DEBUG/INFO/WARN/ERROR.

### Pattern 2 — Batch commands

`/cg run cmd1; cmd2; cmd3` pour enchaîner plusieurs commandes en une seule saisie.

### Pattern 3 — Breakpoint manuel

```lua
-- Dans le code, quand on veut debugger :
ns.WoW.print("BP: " .. debugstack(2))
ns.WoW.print("LOCALS: " .. debuglocals(2))
```

### Pattern 4 — Profiling ad hoc

```lua
debugprofilestart()
-- ... code à mesurer ...
ns.WoW.print(string.format("Elapsed: %.3f ms", debugprofilestop()))
```

### Pattern 5 — Event Spy (à implémenter)

```lua
local f = CreateFrame("Frame")
f:RegisterAllEvents()
f:SetScript("OnEvent", function(_, event, ...)
    ns.WoW.print("EVT: " .. event)
end)
```

## Réaction de l'agent face à un problème

Quand l'utilisateur rapporte un bug ou un comportement inattendu :

1. **D'abord** : demander s'il a `/console scriptErrors 1` activé → erreurs visibles ?
2. **Ensuite** : proposer `/dump` pour inspecter l'état en question
3. **Si événement suspect** : proposer `/etrace` pour capturer ce qui se passe
4. **Si frame/UI** : proposer `/fstack` pour identifier la frame
5. **Si table profonde** : proposer `/tinspect` ou DevTool
6. **Si besoin de capturer pour l'agent** : proposer `/cg log on` + actions + `/reload`

## Références

- Code source Blizzard exporté : `/Applications/World of Warcraft/_classic_era_/BlizzardInterfaceCode/Interface/AddOns/`
- `Blizzard_DebugTools/` — Frame Stack, Table Inspector
- `Blizzard_SharedXML/Dump.lua` — implémentation de `/dump`
- `Blizzard_ScriptErrors/` — handler d'erreurs Lua
- `Blizzard_Console/` — Developer Console intégrée
- API docs : `Blizzard_APIDocumentationGenerated/`
