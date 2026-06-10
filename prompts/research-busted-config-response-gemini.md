C'est une frustration classique avec Busted ! La raison pour laquelle l'outil semblait ignorer ton fichier `.busted` est très probablement due à sa syntaxe interne : Busted s'attend à une structure de données précise (des "profils d'exécution") et non à une simple liste d'options à la racine du fichier. Si tes options ne sont pas enveloppées dans un profil comme `default`, Busted les ignore de manière totalement silencieuse.

Voici les réponses directes et factuelles à tes questions pour remettre ta configuration sur pied.

### 1. Nom exact du fichier

Le nom exact et attendu par défaut est **`.busted`** (sans aucune extension `.lua`, bien qu'il contienne du code Lua valide).

### 2. Emplacement du fichier

Il doit être placé strictement à la **racine de ton projet**, exactement au même niveau que ton dossier `src/` et ton dossier `tests/`.

### 3. Syntaxe complète du fichier

Le fichier `.busted` est lu via un `loadfile` en Lua. Il **doit retourner une table** contenant des sous-tables qui représentent des profils. Quand tu lances la commande `busted` sans argument, c'est le profil nommé `default` qui est lu.

Voici la structure squelette obligatoire :

```lua
return {
  _all = {
    -- Options partagées par tous les profils (optionnel)
  },
  default = {
    -- Options appliquées quand tu lances juste `busted`
  }
}

```

### 4. Spécifier le répertoire `tests/` et le pattern

* **Le répertoire :** Tu dois utiliser la clé **`ROOT`** (en majuscules, sous forme de tableau de chaînes) pour dire à Busted d'ignorer le `spec/` par défaut et de chercher dans ton dossier.
* **Le pattern :** Tu dois utiliser la clé **`pattern`**. **Attention :** Busted n'utilise pas des globs Bash (comme `*.lua`), il s'attend à un **pattern Lua**. Pour matcher tes fichiers, tu dois utiliser `"test_.*%.lua$"` (où `.*` correspond à n'importe quel nombre de caractères, et `%.` échappe le point de l'extension).

### 5. Alternative sans fichier de config ?

Il n'existe pas de variable d'environnement native (`BUSTED_PATTERN` ou autre) pour surcharger ce comportement de base. Sans le fichier `.busted`, la seule façon de le faire sans arguments manuels est de l'automatiser via les outils de ton projet :

* **Alias shell ou Makefile :** En créant une commande `make test` qui exécute sous le capot `busted -p "test_.*%.lua" tests/`.
* **Luarocks :** Si tu utilises un fichier `.rockspec`, tu peux configurer la section `test` pour passer ces arguments fixes.

---

### 6. Configuration complète et fonctionnelle

Voici le fichier `.busted` exact dont tu as besoin pour ton architecture. Copie-colle ce bloc à la racine de ton projet :

```lua
return {
  default = {
    ROOT = { "tests" },
    pattern = "test_.*%.lua$",
    -- Assure que les dépendances (src/ et tests/) soient bien trouvées lors des tests
    lpath = "?.lua;?/init.lua;src/?.lua;;",
  }
}

```

> **Note technique sur `require("tests/helpers")` :** > Puisque la commande `busted` sera lancée depuis la racine, ce `require` fonctionnera car Lua remplacera le point d'interrogation du chemin par défaut (`?.lua`) par ta chaîne exacte, trouvant ainsi `tests/helpers.lua`. Cependant, pour être puriste et garantir une compatibilité totale quel que soit le système d'exploitation, la convention standard en Lua est de remplacer les slashs par des points : **`require("tests.helpers")`**. Lua se chargera de traduire ce point en séparateur de dossier natif.