# Recherche — Architecture testable pour add-ons WoW Classic Era (Lua)

Tu es un expert des add-ons World of Warcraft Classic Era et de l'architecture logicielle en Lua. Fais une **recherche web approfondie** et réponds en **français**. Fournis des **liens sources** (URLs) pour chaque affirmation.

**Consigne : ta réponse doit être un seul bloc markdown, sans fichiers séparés, sans artifacts.**

---

## Contexte

Nous développons un add-on WoW Classic Era en Lua. Nous voulons une architecture propre, testable hors de WoW, avec séparation des responsabilités. Pas de framework de test lourd, pas de build, du Lua brut.

### Notre architecture actuelle (en cours de validation)

```text
SavedVarsDemo/
├── SavedVarsDemo.toc
├── SavedVarsDemo.lua       -- shell WoW (events, slash, SavedVars)
├── src/
│   ├── WoW.lua             -- seam: expose les fonctions WoW, injectable/mockable
│   ├── Core.lua            -- logique métier pure (zéro WoW)
│   ├── Style.lua           -- formatage visuel pur
│   └── Logger.lua          -- logging via WoW.print
└── tests/
    ├── run.lua             -- runner qui découvre les test_*.lua
    ├── test_core.lua
    ├── test_style.lua
    ├── test_logger.lua
    └── test_wow.lua
```

Principes :
- **Functional Core / Imperative Shell**
- `WoW.lua` = seam unique : `WoW.init(_G)` en jeu, `WoW.init({})` en test (fallbacks Lua pur)
- Les modules purs (`Core`, `Style`) ne référencent jamais l'API WoW directement
- Les tests utilisent `loadfile()` + vararg simulé pour charger les modules hors de WoW
- Un seul namespace `ns` (table du vararg) partagé entre fichiers

### Ce qu'on veut valider / améliorer

- Notre pattern de seam (`WoW.lua`) est-il une bonne idée ? Existe-t-il un pattern plus idiomatique ?
- Notre approche de test (`loadfile` + vararg simulé) est-elle la bonne ?
- Y a-t-il des frameworks ou libs existants pour tester les add-ons WoW hors du jeu ?
- Comment les gros add-ons (Questie, DBM, WeakAuras, Auctionator) gèrent-ils l'architecture et les tests ?

---

## Questions de recherche

### 1. Frameworks et outils de test pour add-ons WoW

Existe-t-il des frameworks ou outils pour écrire et exécuter des tests unitaires sur du code d'add-on WoW Lua ? Cherche notamment :

- **WoWUnit** ou similaires
- ** busted** utilisé avec des mocks WoW
- Des CI/CD pipelines pour add-ons WoW
- Des dépôts GitHub d'add-ons qui ont des répertoires `tests/` ou `spec/`
- Comment les devs d'add-ons testent-ils leur code en pratique ?

### 2. Architecture et patterns dans les add-ons WoW populaires

Analyse l'architecture de 3-5 add-ons WoW Classic Era populaires et open source :

- **Questie** — comment est structuré le code ? Tests ?
- **DBM (Deadly Boss Mods)** — architecture modulaire ?
- **WeakAuras** — comment gèrent-ils la complexité ?
- **Auctionator** — connu pour son code propre, comment est-il structuré ?
- **Leatrix Plus** — pattern d'initialisation ?

Pour chaque add-on, montre :
- Structure de fichiers (extraits du `.toc`)
- Pattern d'initialisation (comment les modules sont chargés)
- S'il y a des tests, comment ils fonctionnent
- S'il n'y a pas de tests, comment justifient-ils l'absence ?

### 3. Dependency injection en Lua WoW

Notre pattern actuel :

```lua
-- WoW.lua (seam)
local WoW = {}
ns.WoW = WoW

function WoW.wipe(t)
    for k in pairs(t) do t[k] = nil end
end

function WoW.init(env)
    WoW.print = env.print or WoW.print
    WoW.wipe = env.wipe or WoW.wipe
end
```

- Ce pattern est-il utilisé dans d'autres add-ons ?
- Existe-t-il un pattern plus idiomatique en Lua pour l'injection de dépendances ?
- **LibStub** et **Ace3** ont-ils un mécanisme d'injection ou de remplacement ?
- Y a-t-il un équivalent de `DI container` dans l'écosystème WoW ?

### 4. Le namespace `ns` comme module system

Nous utilisons `local addonName, ns = ...` comme système de modules :

```lua
-- Core.lua
local _, ns = ...
ns.Core = {}

-- Shell.lua
local addonName, ns = ...
local Core = ns.Core
```

- Est-ce un pattern communautaire standard ou une invention ?
- Comment les add-ons qui utilisent Ace3 gèrent-ils le namespace ?
- Y a-t-il des conventions de nommage pour `ns` ?

### 5. Bonnes pratiques de la communauté

Quelles sont les bonnes pratiques reconnues par la communauté des devs d'add-ons WoW pour :

- Structurer un add-on de taille moyenne (500-2000 lignes)
- Séparer la logique de l'UI
- Gérer les SavedVariables proprement
- Écrire du code maintenable et testable
- Documenter le code

Sources à consulter : wowinterface.com forums, wowace.com forums, warcraft.wiki.gg, r/wowaddons, GitHub.

### 6. Exemples de code testé

Montre 2-3 exemples concrets d'add-ons WoW (ou de libs) qui ont des tests unitaires réels. Extrais le code du test runner, des mocks, et de la structure de fichiers. Si tu ne trouves pas d'exemples en Lua WoW, montre des exemples dans des contextes Lua similaires (LÖVE2D, neovim plugins, etc.).

---

## Synthèse attendue

À la fin, donne une **évaluation honnête** de notre architecture actuelle :
- Ce qui est bien (par rapport aux pratiques de la communauté)
- Ce qui pourrait être amélioré (avec des exemples concrets de code alternatif)
- Ce qui est over-engineered pour un add-on WoW
- Les 3-5 changements concrets que tu recommanderais
