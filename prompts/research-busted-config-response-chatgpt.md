## Conclusion

Pour ton cas, le fichier doit s’appeler **exactement `.busted`**, sans extension `.lua`, placé à la racine du projet, et il doit retourner une table Lua. Busted sait charger automatiquement ce fichier si tu lances `busted` depuis ce répertoire. La doc officielle indique que Busted 1.6 a introduit ces “tasks” via un fichier `.busted` autochargé, avec une table `default`, `_all`, et des tâches nommées ; le code actuel cherche explicitement un fichier nommé `.busted`, pas `.busted.lua`. ([Lunar Modules][1]) ([GitHub][2])

La config complète que je mettrais dans ton projet est celle-ci :

```lua
-- .busted
return {
  default = {
    -- Répertoire où Busted cherche les tests.
    -- Attention : la clé officielle est ROOT en majuscules.
    ROOT = { "tests" },

    -- Busted attend un "Lua pattern", pas un glob shell.
    -- Donc pas "test_*.lua", mais "test_.*%.lua$".
    pattern = "test_.*%.lua$",

    -- Chemins de require.
    -- ./?.lua permet require("tests/helpers") -> ./tests/helpers.lua
    -- ./src/?.lua permet require("Core") -> ./src/Core.lua
    lpath = table.concat({
      "./?.lua",
      "./?/init.lua",
      "./src/?.lua",
      "./src/?/init.lua",
    }, ";"),

    -- Optionnel, mais pratique.
    verbose = true,
  },
}
```

Avec cette structure :

```text
mon-projet/
├── .busted
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

tu devrais pouvoir lancer simplement :

```bash
busted
```

et Busted cherchera dans `tests/`, ne prendra que les fichiers qui matchent `test_.*%.lua$`, donc `test_core.lua`, `test_style.lua`, etc., mais pas `helpers.lua`.

## Réponses précises à tes questions

### 1. Nom exact du fichier de configuration

Le nom exact est :

```text
.busted
```

Pas `.busted.lua`. La documentation officielle parle d’un fichier `.busted` autochargé, et le code CLI courant construit explicitement le chemin `path.join(cliArgs.directory, '.busted')`. ([Lunar Modules][1]) ([GitHub][2])

### 2. Où doit-il être placé ?

Place-le dans le répertoire depuis lequel tu veux lancer `busted`, donc ici :

```text
mon-projet/.busted
```

Techniquement, Busted cherche `.busted` dans le répertoire courant par défaut, ou dans le répertoire donné par `-C, --directory=DIR`. Le code montre que le fichier par défaut est cherché via `path.join(cliArgs.directory, '.busted')`. ([Lunar Modules][1]) ([GitHub][2])

Donc :

```bash
cd mon-projet
busted
```

doit fonctionner.

### 3. Syntaxe complète

Le fichier `.busted` est un fichier Lua qui doit faire `return { ... }`. La doc officielle donne exactement ce modèle avec `_all`, `default`, et des tâches nommées ; elle précise aussi que les options sont celles de la CLI avec leur nom long, et que les options contenant des tirets doivent être écrites entre crochets, par exemple `["suppress-pending"]`. ([Lunar Modules][1])

Syntaxe générale :

```lua
return {
  _all = {
    -- Options communes à toutes les tâches.
  },

  default = {
    -- Options utilisées quand on tape juste : busted
  },

  uneTacheNommee = {
    -- Options utilisées avec : busted --run=uneTacheNommee
  },
}
```

Pour ton cas, tu n’as besoin que de `default`.

### 4. Spécifier `tests/` et `test_*.lua`

La clé à utiliser pour le répertoire est :

```lua
ROOT = { "tests" }
```

La doc officielle utilise `ROOT = {"spec/unit"}` dans son exemple de task, et plusieurs projets réels utilisent aussi `ROOT` pour rediriger Busted vers un dossier de tests spécifique. ([Lunar Modules][1]) ([GitHub][3]) ([GitHub][4])

La clé à utiliser pour le pattern est :

```lua
pattern = "test_.*%.lua$"
```

Point important : Busted parle de **Lua pattern**, pas de glob shell. Donc `test_*.lua` n’est pas le bon équivalent Lua de `test_*.lua`. En Lua pattern, `.` veut dire “n’importe quel caractère”, `*` veut dire “répéter le motif précédent”, et `%.` veut dire “un vrai point littéral”. La CLI officielle documente `-p, --pattern=PATTERN` comme un “Lua pattern”, avec `_spec` comme valeur par défaut. ([Lunar Modules][1])

### 5. Sans fichier de config ?

Oui, mais pas avec la commande nue `busted`.

Équivalent sans fichier `.busted` :

```bash
busted tests --pattern='test_.*%.lua$' --lpath='./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua'
```

Ou plus court si ton `package.path` standard contient déjà `./?.lua` :

```bash
busted tests --pattern='test_.*%.lua$'
```

La CLI officielle accepte un ou plusieurs arguments `ROOT`, accepte `--pattern`, et accepte `--lpath` pour préfixer le chemin de recherche Lua. ([Lunar Modules][1])

En revanche, je n’ai pas trouvé dans la documentation officielle de variable d’environnement Busted du type `BUSTED_ROOT` ou `BUSTED_PATTERN` permettant de faire ça automatiquement avec `busted` seul. Pour `require`, tu peux utiliser l’environnement Lua standard `LUA_PATH`, mais ça ne règle que le chargement des modules, pas la découverte des fichiers de test. Le manuel Lua explique que `require` cherche via `package.path` et `package.searchers`, et que `package.searchpath` remplace `?` par le nom du module. ([lua.org][5])

### 6. Config complète pour ton projet

À mettre dans :

```text
mon-projet/.busted
```

Contenu complet :

```lua
return {
  default = {
    ROOT = { "tests" },
    pattern = "test_.*%.lua$",

    lpath = table.concat({
      "./?.lua",
      "./?/init.lua",
      "./src/?.lua",
      "./src/?/init.lua",
    }, ";"),

    verbose = true,
  },
}
```

Ensuite :

```bash
cd mon-projet
busted
```

Dans tes tests :

```lua
local helpers = require("tests/helpers")
local Core = require("Core")
```

`require("tests/helpers")` fonctionne avec `./?.lua`, car le template `./?.lua` devient `./tests/helpers.lua`. `require("Core")` fonctionne avec `./src/?.lua`, car le template devient `./src/Core.lua`. Le comportement de recherche de `require` via `package.path` est celui documenté par le manuel Lua. ([lua.org][5])

## Pourquoi tes essais ont pu échouer

Si `.busted` “semble ignoré”, les causes les plus probables sont :

1. La clé utilisée était `root` au lieu de `ROOT`. La doc officielle et les exemples fiables utilisent `ROOT` en majuscules pour les racines de test. ([Lunar Modules][1]) ([GitHub][3])

2. Le pattern était écrit comme un glob shell (`test_*.lua`) au lieu d’un Lua pattern (`test_.*%.lua$`). La CLI documente bien `--pattern` comme un Lua pattern. ([Lunar Modules][1])

3. Le fichier était nommé `.busted.lua`. Le nom autochargé est `.busted`. Le code CLI courant ne cherche pas `.busted.lua`. ([GitHub][2])

4. Tu utilises une vieille version ou un wrapper Docker/alias. Il y a eu d’anciens problèmes GitHub où certaines options, dont `ROOT`, n’étaient pas correctement prises en compte depuis `.busted`, et d’autres cas où `busted` sans argument ne trouvait rien alors que `busted .` marchait. Ces issues sont anciennes, mais elles expliquent très bien le symptôme “il cherche encore dans `spec/`”. ([GitHub][6]) ([GitHub][7])

Vérifie ta version :

```bash
busted --version
```

Sur LuaRocks, la version récente listée est `2.3.0-1`; si tu es sur une vieille `1.x` ou `2.0.rc*`, je mettrais à jour avant de perdre du temps sur la config. ([luarocks.org][8])

[1]: https://lunarmodules.github.io/busted/ "busted : Elegant Lua unit testing, by Olivine-Labs"
[2]: https://github.com/Olivine-Labs/busted/blob/master/busted/modules/cli.lua "busted/busted/modules/cli.lua at master · lunarmodules/busted · GitHub"
[3]: https://github.com/wrxck/telegram-bot-lua/blob/main/.busted?utm_source=chatgpt.com "telegram-bot-lua/.busted at main"
[4]: https://github.com/bngarren/checkmate.nvim/blob/main/.busted?utm_source=chatgpt.com "checkmate.nvim/.busted at main · bngarren ..."
[5]: https://www.lua.org/manual/5.4/manual.html?utm_source=chatgpt.com "Lua 5.4 Reference Manual"
[6]: https://github.com/lunarmodules/busted/issues/265 "Various options are not loaded from .busted files · Issue #265 · lunarmodules/busted · GitHub"
[7]: https://github.com/Olivine-Labs/busted/issues/552?utm_source=chatgpt.com "Calling busted with no arguments fails to find spec file · Issue #552"
[8]: https://luarocks.org/modules/lunarmodules/busted "busted - LuaRocks"
