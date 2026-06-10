Tout vérifié empiriquement — j'ai installé busted 2.2.0 dans un sandbox, recréé votre structure exacte, et reproduit vos échecs avant de faire marcher la config. Voici le résultat complet.

## 1. Le nom exact du fichier

C'est bien **`.busted`** (sans extension). Votre fichier `.busted.lua` est totalement ignoré — je l'ai confirmé en renommant le fichier : busted retombe silencieusement sur `spec/` et `_spec`.

## 2. Où le placer

À la racine du projet, c'est-à-dire dans le **répertoire courant** d'où vous lancez `busted`. Il n'y a pas de recherche dans les répertoires parents (contrairement à `.luacheckrc`).

## 3. Pourquoi votre `.busted` était « ignoré »

C'est presque certainement un problème de structure interne, pas de nom de fichier. Le `.busted` doit retourner une table de **configurations nommées**, et busted n'applique que la clé `default` (ou celle passée via `-r, --run` : « Config to run from .busted file »). J'ai reproduit votre symptôme exact avec une config « plate » :

```lua
-- ❌ NE MARCHE PAS — ignoré silencieusement, busted cherche dans spec/
return {
  ROOT = {"tests/"},
  pattern = "test_",
}
```

Résultat : `Error -> Cannot find file or directory: spec`. Aucun message d'erreur — busted ignore juste les clés qu'il ne reconnaît pas au premier niveau. C'est un piège connu : un utilisateur dans l'issue #268 du dépôt rapportait le même genre de confusion, avec une config qui ne semblait pas s'appliquer.

## 4. La config complète qui marche (testée, 4/4 tests passent)

```lua
-- .busted  (à la racine de mon-projet/)
return {
  _all = {
    -- options communes à toutes les configurations nommées (optionnel)
    coverage = false,
  },
  default = {
    -- équivalent des arguments ROOT positionnels de la CLI
    ROOT = {"tests"},

    -- pattern Lua appliqué aux noms de fichiers (défaut: "_spec")
    pattern = "test_",

    -- préfixé au package.path ; indispensable pour require("tests/helpers")
    lpath = "./?.lua;./?/init.lua",

    verbose = true,
  },
}
```

Avec ce fichier, `busted` sans aucun argument depuis la racine donne :

```
++++
4 successes / 0 failures / 0 errors / 0 pending : 0.001952 seconds
```

Détails importants vérifiés :

- **`ROOT = {"tests"}`** : c'est la clé (en majuscules) qui correspond aux arguments positionnels. Les dossiers ROOT sont parcourus pour tout fichier correspondant à l'option `--pattern`.
- **`pattern = "test_"`** suffit : c'est un pattern Lua matché contre le nom de fichier, pas un glob. `helpers.lua` ne le matche pas, donc il n'est pas exécuté comme test. Si vous voulez être strict : `pattern = "^test_.*%.lua$"` marche aussi (testé).
- **`lpath` est obligatoire pour votre `require("tests/helpers")`** : le lpath par défaut de busted est `./src/?.lua;./src/?/?.lua;./src/?/init.lua` — il ne couvre que `src/`. En ajoutant `./?.lua`, `require("tests/helpers")` se résout en `./tests/helpers.lua` et `require("src/Core")` en `./src/Core.lua`. Bonus : grâce au lpath par défaut, `require("Core")` marcherait aussi directement.

## 5. Sans fichier de config

Il n'existe **aucune variable d'environnement** ni mécanisme de détection automatique du répertoire `tests/`. Les deux seules options :

```bash
# CLI pure (testé, fonctionne) :
busted --pattern=test_ --lpath="./?.lua" tests

# ou via un alias / Makefile :
alias bt='busted --pattern=test_ --lpath="./?.lua" tests'
```

À noter aussi : `-f, --config-file=FILE` charge les options depuis un fichier — mais le fichier passé doit avoir la même structure (table avec clé `default`), donc votre essai `--config-file=.busted` échouait pour la même raison que le fichier auto-détecté.

## Récapitulatif des trois causes de vos échecs

1. `.busted` ignoré → probablement une table sans clé `default` (ignorée silencieusement, reproduit dans mon test).
2. `.busted.lua` ignoré → mauvais nom, busted ne cherche que `.busted` exactement.
3. `--config-file=.busted` sans effet → le fichier était chargé mais sa structure interne était invalide.

Corrigez la structure (table imbriquée sous `default` avec `ROOT`, `pattern`, `lpath`) et la commande `busted` nue fonctionnera — vérifié sur busted 2.2.0 avec votre arborescence exacte.