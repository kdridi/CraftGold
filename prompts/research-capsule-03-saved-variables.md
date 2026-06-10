# Recherche — Capsule 03 : Saved Variables

Tu es un expert des add-ons World of Warcraft Classic Era (version 1.15.x, interface 11508). Fais une **recherche web approfondie** et réponds en **français**. Fournis des **liens sources** (URLs) pour chaque affirmation.

**Consigne : ta réponse doit être un seul bloc markdown, sans fichiers séparés, sans artifacts.**

## Questions

### 1. Cycle de vie des SavedVariables

Explique le cycle de vie complet des SavedVariables dans un add-on WoW Classic Era :

- Dans quel ordre se déclenchent les événements liés au chargement ?
  - `ADDON_LOADED` — quand exactement ? La variable SavedVariable est-elle déjà peuplée à ce moment ?
  - `VARIABLES_LOADED` — quand ? Différence avec `ADDON_LOADED` ?
  - `PLAYER_LOGIN` — pertinent pour les SavedVars ?
  - `PLAYER_LOGOUT` — que peut-on y faire ?
- Au moment du `/reload`, le fichier `SavedVariables/*.lua` est-il écrit AVANT le reload ou APRÈS ? Autrement dit : quand le jeu sauvegarde-t-il les SavedVars ?
- La variable globale est-elle `nil` au premier chargement (premier /reload après installation de l'add-on) ? Confirmé.

### 2. Déclaration dans le .toc

Syntaxe exacte dans le `.toc` :
```
## SavedVariables: MyVarName
## SavedVariablesPerCharacter: MyPerCharVar
```

- Quelle est la différence entre `SavedVariables` et `SavedVariablesPerCharacter` ?
- Est-ce que les deux existent en Classic Era ?
- Peut-on déclarer plusieurs variables ? `## SavedVariables: Var1, Var2` ?
- La variable DOIT-ELLE être globale (pas `local`) ? Confirmé.

### 3. Sérialisation — Limitations

WoW sérialise les SavedVariables en Lua. Quels types sont supportés et lesquels ne le sont PAS ?

- Numbers, strings, booleans — OK ?
- Tables imbriquées — OK ? Profondeur limite ?
- Functions — NON sérialisables ? Confirmé.
- Que se passe-t-il si une table contient une fonction ? Elle est ignorée ? Erreur ?
- Mixed tables (clés numériques + string) — supporté ?

### 4. Pattern d'initialisation recommandé

Montre le pattern canonique pour initialiser des SavedVars avec valeurs par défaut :

```lua
local defaults = {
    counter = 0,
    name = "unknown",
}

-- Dans le handler ADDON_LOADED :
MyAddonDB = MyAddonDB or {}
for k, v in pairs(defaults) do
    if MyAddonDB[k] == nil then
        MyAddonDB[k] = v
    end
end
```

Ce pattern est-il correct ? Y a-t-il un pattern plus idiomatique en WoW ? Comment gérer les defaults imbriqués ?

### 5. Où sont stockés les fichiers ?

Chemin exact du fichier de sauvegarde :
- `SavedVariables` : `_classic_era_/WTF/Account/<account>/SavedVariables/<AddonName>.lua` ?
- `SavedVariablesPerCharacter` : `_classic_era_/WTF/Account/<account>/<server>/<character>/SavedVariables/<AddonName>.lua` ?

Confirme les chemins pour Classic Era.

### 6. Exemples d'add-ons existants

Cite 2-3 add-ons Classic Era populés qui utilisent les SavedVars de façon simple et propre. Montre un extrait de leur code d'initialisation si possible.

### 7. Points subtils / gotchas

- Que se passe-t-il si le .toc déclare `SavedVariables: MyVar` mais le .lua ne définit jamais `MyVar` ?
- Que se passe-t-il si le .lua définit `MyVar` mais le .toc ne le déclare pas ?
- Peut-on utiliser une table locale comme proxy (ex: `local db` qui référence la globale) ?
- Est-ce que le `wipe()` fonction est utilisable sur les SavedVars ?
- Y a-t-il des limites de taille pour les SavedVariables ?
