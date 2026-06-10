# Recherche — Configuration busted pour un projet Lua avec tests dans tests/

Je veux configurer busted (framework de test Lua) pour qu'il trouve mes tests avec juste la commande `busted` sans aucun argument.

**Consigne : ta réponse doit être un seul bloc markdown, sans fichiers séparés, sans artifacts.**

## Ma structure de projet

```
mon-projet/
├── src/
│   ├── WoW.lua
│   ├── Core.lua
│   ├── Style.lua
│   └── Logger.lua
├── tests/
│   ├── helpers.lua
│   ├── test_core.lua
│   ├── test_style.lua
│   ├── test_logger.lua
│   └── test_wow.lua
├── SavedVarsDemo.lua
└── SavedVarsDemo.toc
```

## Ce que je veux

En tapant juste `busted` depuis la racine du projet, je veux que busted :
1. Cherche les tests dans le répertoire `tests/`
2. Utilise le pattern `test_*.lua` (pas `_spec.lua`)
3. Charge `tests/helpers.lua` correctement via `require("tests/helpers")`

## Ce que j'ai essayé

- `.busted` à la racine — busted l'ignore
- `.busted.lua` à la racine — busted l'ignore
- `busted --config-file=.busted` — ne change rien, cherche quand même dans `spec/`

## Questions

1. Quel est le nom exact du fichier de configuration busted ?
2. Où doit-il être placé ?
3. Quelle est sa syntaxe complète (pas un extrait, le fichier entier) ?
4. Comment spécifier le répertoire `tests/` et le pattern `test_*.lua` ?
5. Y a-t-il un moyen de le faire sans fichier de config (option dans le répertoire ou environnement) ?
6. Montre la config complète qui fait marcher `busted` tout seul pour ma structure.

Cherche dans la documentation officielle de busted (GitHub lunarmodules/busted), les issues GitHub, et les exemples réels de projets qui utilisent busted avec un répertoire `tests/` personnalisé.
