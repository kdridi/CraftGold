# 03 — Saved Variables

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 1                                                     |
| Duration      | ~2h                                                         |
| Difficulty    | ●●●●○ (4/5)                                                |
| Prerequisites | Capsule 02 — Slash Commands                                 |
| Type          | Autonomous                                                  |
| Concepts      | `SavedVariables`, `ADDON_LOADED`, `PLAYER_LOGOUT`, Functional Core / Imperative Shell, injection de dépendances, tests unitaires (busted + in-game) |

## Why This Capsule?

Jusqu'ici, nos add-ons ont la mémoire d'un poisson rouge. Un compteur dans la capsule 02 ? Au `/reload`, tout disparaît.

Le problème : **aucune donnée ne survit entre les sessions**. Or CraftGold DOIT se souvenir des crafts, prix, préférences.

Cette capsule introduit les **SavedVariables** — le mécanisme officiel de WoW pour persister des données. Mais elle introduit surtout un **changement architectural majeur** : la séparation entre logique pure (testable hors WoW) et shell impur (appels API WoW). C'est le pattern *Functional Core / Imperative Shell*, validé par consultation multi-agents (3 LLM). Il sera le fil conducteur de toutes les capsules suivantes.

## Concepts

### SavedVariables — Cycle de vie

1. Déclarer une variable globale dans le `.toc` : `## SavedVariables: SavedVarsDemoDB`
2. Au chargement, WoW exécute le fichier sauvegardé sur disque → la variable est peuplée
3. `ADDON_LOADED` se déclenche → initialiser les defaults
4. Au logout/reload, WoW sérialise et écrit sur disque
5. `PLAYER_LOGOUT` se déclenche juste avant — dernière chance de modifier

**Écriture avant le reload** — crash = perte des données.

**Premier lancement** — la variable vaut `nil` → `_G.SavedVarsDemoDB = Core.applyDefaults(...)`.

### `ADDON_LOADED` se déclenche pour TOUS les add-ons

Pas privé à notre add-on. Il se déclenche pour chaque add-on chargé. D'où le filtre obligatoire :

```lua
if addonName ~= ADDON_NAME then return end
```

### `_G` — L'espace global

`_G` est la table qui contient toutes les globales Lua. On utilise `_G.SavedVarsDemoDB` pour :
- Rendre explicite que c'est une SavedVar (donc une globale)
- La distinguer des variables locales

### Architecture — Functional Core / Imperative Shell

Décision validée via consultation multi-agents (voir `prompts/multiagent-architecture.md`).

Le principe : séparer ce qui est **testable** de ce qui ne l'est pas.

| Couche | Responsabilité | WoW API ? | Testable hors WoW ? |
|--------|---------------|-----------|---------------------|
| `src/WoW.lua` | Seam : fonctions WoW injectables | Injecté | ✅ (mock) |
| `src/Core.lua` | Logique métier pure | ❌ Jamais | ✅ Oui |
| `src/Style.lua` | Formatage visuel | ❌ Jamais | ✅ Oui |
| `src/Logger.lua` | Logging via `WoW.print` | ❌ Injecté | ✅ Oui (mock) |
| `src/Test.lua` | Tests in-game | ✅ | ❌ |
| `SavedVarsDemo.lua` | Shell WoW | ✅ Oui | ❌ Non |

**Règle d'or** : si `Core.lua` ne charge pas en Lua pur, tu as cassé le contrat.

### Seam `WoW.lua` — Injection de dépendances

Un seul module expose les fonctions WoW. Initialisé avec `_G` en jeu, `{}` en test :

```lua
-- En jeu :
WoW.init(_G)         → WoW.wipe = vrai wipe C (rapide)

-- En test :
WoW.init({})         → WoW.wipe = fallback Lua pur
```

Les fallbacks sont immuables — `WoW.init` reconstruit toujours depuis les defaults.

### Tests unitaires — Deux environnements

| Environnement | Commande | Framework |
|---|---|---|
| Terminal (hors WoW) | `busted` | busted 2.3 (describe/it/assert) |
| En jeu (WoW) | `/svars test` | Runner maison (mêmes assertions sur Core) |

C'est la **démonstration vivante** : le même `Core.lua` tourne dans deux environnements et produit les mêmes résultats.

## Structure de fichiers

```
SavedVarsDemo/
├── .busted                  -- config busted (juste: busted)
├── SavedVarsDemo.toc        -- manifest
├── SavedVarsDemo.lua        -- shell WoW (events, slash, SavedVars)
├── src/                     -- testable, réutilisable
│   ├── WoW.lua              -- seam API WoW (print, wipe)
│   ├── Core.lua             -- logique métier pure
│   ├── Style.lua            -- formatage visuel pur
│   ├── Logger.lua           -- logging via WoW.print
│   └── Test.lua             -- runner de tests in-game
└── tests/                   -- busted, zéro WoW
    ├── helpers.lua          -- chargement des modules (loadfile + vararg simulé)
    ├── test_core.lua        -- 24 tests
    ├── test_style.lua       -- 4 tests
    ├── test_logger.lua      -- 3 tests
    └── test_wow.lua         -- 5 tests
```

## Le `.toc`

```
## Interface: 11508
## Title: SavedVars Demo
## Notes: Learn to persist data across sessions
## SavedVariables: SavedVarsDemoDB

src\WoW.lua
src\Core.lua
src\Style.lua
src\Logger.lua
src\Test.lua
SavedVarsDemo.lua
```

**L'ordre compte** : `WoW` en premier (seam sans dépendance), puis les modules purs, puis le shell.

## Code pas-à-pas

### `src/WoW.lua` — Le seam

Expose les fonctions WoW avec fallbacks Lua pur. Au chargement, les fallbacks sont appliqués immédiatement (pas besoin d'attendre `init`). `WoW.init(_G)` les remplace par les vraies en jeu.

### `src/Core.lua` — Le noyau pur

Zéro référence à WoW. Pas de `print`, pas de `CreateFrame`, pas de `_G`.

- `Core.DEFAULTS` — constantes par défaut
- `Core.applyDefaults(db, defaults)` — remplit les clés manquantes (test `== nil` pour préserver `false`)
- `Core.reset(db, defaults)` — vide via `WoW.wipe` puis reapplique les defaults
- `Core.increment(db, step)` — incrémente le compteur
- `Core.parseCommand(input)` — string → `{ kind, value }`

### `src/Style.lua` — Le formatage visuel

Fonctions pures retournant des strings avec codes couleur (`|cFFRRGGBB...|r`).

- `Style.colorize(text, r, g, b)` — bas niveau
- `Style.prefix(name)` — `[SavedVarsDemo]` en vert
- `Style.highlight(text)` — valeur en doré
- `Style.command(text)` — slash command en jaune

Les couleurs sont des constantes internes — le code appelant ne connaît que l'intention.

### `src/Logger.lua` — Le logging

Utilise `WoW.print` (pas `print` directement). Initialise avec un prefix :

```lua
Logger.init(Style.prefix(addonName) .. " ")
```

### `src/Test.lua` — Les tests in-game

Mêmes assertions que les tests busted, mais affichées dans le chat avec couleurs (vert OK, rouge FAIL).

### `SavedVarsDemo.lua` — Le shell

1. **Bootstrap** : `WoW.init(_G)`, `Logger.init(...)` — un seul endroit câble le vrai WoW
2. **Events** : `ADDON_LOADED` (init SavedVars), `PLAYER_LOGOUT` (timestamp)
3. **Slash commands** : parsing via Core, rendu via Style, affichage via Logger
4. **Tests** : `/svars test` lance `Test.run()` et affiche les résultats

## Test en jeu

```
/reload
→ [SavedVarsDemo] Loaded! Counter: 0

/svars increment
→ [SavedVarsDemo] Counter incremented to: 1

/svars info
→ [SavedVarsDemo] Counter: 1
→ [SavedVarsDemo] Name: unknown
→ [SavedVarsDemo] Last logout: never

/reload
→ [SavedVarsDemo] Loaded! Counter: 1    ← persistance !

/svars test
→ [SavedVarsDemo] Core.applyDefaults:
→ [SavedVarsDemo]   OK creates table from nil
→ [SavedVarsDemo]   OK preserves existing value
→ ...
→ [SavedVarsDemo] 19 passed, 0 failed
```

## Le fichier SavedVariables sur disque

Après un `/reload`, WoW écrit dans :
```
_classic_era_/WTF/Account/<account>/SavedVariables/SavedVarsDemo.lua
```

```lua
SavedVarsDemoDB = {
["lastLogout"] = 1781100188,
["name"] = "unknown",
["counter"] = 1,
}
```

Un fichier `.lua.bak` (backup) est créé à côté.

## Tests busted (terminal)

```bash
cd SavedVarsDemo
busted
→ 32 successes / 0 failures / 0 errors
```

## Pitfalls rencontrés

1. **`wipe()` est WoW-only** — `Core.reset()` l'appelait → crash en Lua pur. Résolu : `WoW.wipe` avec fallback, fallbacks appliqués au chargement (pas juste dans `init`).

2. **Proxy local assigné trop tôt** — `local db = _G.SavedVarsDemoDB` au top-level = `nil`. Il faut assigner dans le handler `ADDON_LOADED`.

3. **`ADDON_LOADED` pour tous les add-ons** — Sans le filtre `addonName ~= ADDON_NAME`, le handler s'exécute pour chaque add-on chargé.

4. **`WoW.init` ne restaure pas les fallbacks** — Bug identifié par consultation multi-agents : `WoW.wipe = env.wipe or WoW.wipe` ne peut jamais restaurer le fallback après injection. Résolu : fallbacks immuables dans `FALLBACKS`, `init` reconstruit toujours depuis eux.

5. **Test `== nil` vs `or`** — `if db[k] == nil then db[k] = v end` préserve un `false` sauvegardé. `db[k] = db[k] or v` écraserait `false`.

6. **`.busted` doit avoir une clé `default`** — busted ignore silencieusement une config sans clé `default`.

## Recherche et validation

- **Phase 0** : recherche SavedVariables (3 LLM, consensus total) → `docs/saved-variables.md`
- **Architecture** : consultation multi-agents (3 LLM, consensus) → `prompts/multiagent-architecture.md`
- **Validation architecture** : recherche auprès de 3 LLM sur les pratiques réelles (Questie, DBM, WeakAuras, Auctionator) → `prompts/research-capsule-03-architecture-validation-response-*.md`
- **Busted config** : `prompts/research-busted-config.md` + doc officielle

## Going Further

- **`SavedVariablesPerCharacter`** — même principe, fichier par personnage
- **Defaults imbriqués récursifs** — voir `docs/saved-variables.md`
- **`luacheck` + `.luacheckrc`** — linter Lua avec connaissance de l'API WoW
- **AceDB-3.0** — librairie communauté pour profils, defaults, migration (mentionné en capsule tardive)
- **wowmock / wow-ui-sim** — pour les tests d'intégration avancés

→ Prochaine capsule : **04 — My First Frame**
