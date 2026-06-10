# Saved Variables — Persistance des données entre les sessions

> Consolidé à partir des recherches Claude, Gemini et ChatGPT (Phase 0, Capsule 03).
> Sources principales : [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions), [AddOn loading process](https://warcraft.wiki.gg/wiki/AddOn_loading_process)

---

## Vue d'ensemble

Les **SavedVariables** permettent à un add-on de sauvegarder des données entre les sessions. Le mécanisme est simple :

1. Déclarer une variable globale dans le `.toc` avec `## SavedVariables: MyVarName`
2. WoW la sérialise dans un fichier `.lua` au logout/reload
3. Au prochain chargement, WoW relit le fichier et peuple la variable globale

---

## Cycle de vie

### Ordre de chargement (par add-on)

```
1. Code FrameXML chargé
2. Fichiers .lua de l'add-on chargés et exécutés (dans l'ordre du .toc)
3. SavedVariables de l'add-on chargées (écrasent les valeurs par défaut)
4. ADDON_LOADED déclenché pour cet add-on
5. ... (autres add-ons) ...
6. PLAYER_LOGIN déclenché (tous les add-ons chargés, joueur connecté)
```

### Événements pertinents

| Événement | Quand | SavedVars disponibles ? | Usage |
|-----------|-------|------------------------|-------|
| `ADDON_LOADED` | Après le chargement de chaque add-on | ✅ Oui, déjà peuplées | **Initialisation des SavedVars** (filtrer sur le nom de l'add-on) |
| `VARIABLES_LOADED` | Chargement des CVars/keybindings Blizzard | ⚠️ Pas fiable | **À éviter** — peut survenir après `PLAYER_ENTERING_WORLD` |
| `PLAYER_LOGIN` | Joueur complètement connecté | ✅ Oui | Initialisation UI qui dépend du personnage |
| `PLAYER_LOGOUT` | Avant sauvegarde finale | ✅ Oui | **Dernière chance** de modifier les SavedVars |

### Quand le fichier est-il écrit ?

Le fichier SavedVariables est écrit **AVANT** le reload/logout/quit :
- `/reload` → sauvegarde → recharge
- Logout/Quit → sauvegarde → ferme
- **Crash/Alt-F4** → ❌ **perte des données de la session**

Un fichier `.lua.bak` (backup de la version précédente) est créé à côté à chaque sauvegarde.

---

## Déclaration dans le `.toc`

```toc
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyCharDB
```

### Différences

| Directive | Portée | Chemin du fichier |
|-----------|--------|-------------------|
| `SavedVariables` | Compte (partagé entre tous les personnages) | `WTF/Account/<account>/SavedVariables/<Addon>.lua` |
| `SavedVariablesPerCharacter` | Personnage (indépendant par personnage) | `WTF/Account/<account>/<realm>/<char>/SavedVariables/<Addon>.lua` |

Pour Classic Era, tout est sous le préfixe `_classic_era_/`.

### Règles

- **La variable DOIT être globale** — `local` n'est pas vu par le sérialiseur
- **Plusieurs variables** : `## SavedVariables: Var1, Var2` (virgules)
- **Pas de sous-table** : `## SavedVariables: MyAddon.DB` peut causer des problèmes
- Les deux directives existent en Classic Era (depuis WoW vanilla)

---

## Sérialisation — Types supportés

| Type | Sérialisable ? | Notes |
|------|----------------|-------|
| `number` | ✅ | |
| `string` | ✅ | |
| `boolean` | ✅ | `false` est une valeur valide — utiliser `== nil` pour les defaults |
| `table` | ✅ | Imbriquées OK, récursif, pas de limite documentée |
| `function` | ❌ | **Silencieusement ignorée** — pas d'erreur, clé simplement absente au prochain chargement |
| `userdata` | ❌ | Frames, textures — ignorés |
| `coroutine` | ❌ | Ignoré |

### Tables mixtes

Les tables avec clés numériques ET string sont supportées :

```lua
MyDB = {
    [1] = "first",
    name = "Karim",  -- OK
}
```

### Références

- Les **références circulaires** ne sont pas préservées
- Les **références partagées** entre deux SavedVariables créent des copies séparées au rechargement

---

## Pattern d'initialisation canonique

### Pattern simple (table plate)

```lua
local ADDON_NAME = ...

local defaults = {
    counter = 0,
    name = "unknown",
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= ADDON_NAME then return end

    MyAddonDB = MyAddonDB or {}

    -- Appliquer les defaults sans écraser les valeurs existantes
    for k, v in pairs(defaults) do
        if MyAddonDB[k] == nil then
            MyAddonDB[k] = v
        end
    end

    self:UnregisterEvent("ADDON_LOADED")
end)
```

⚠️ **Test `== nil` (pas `or`)** : `if MyAddonDB[k] == nil` préserve la valeur `false`, alors que `MyAddonDB[k] = MyAddonDB[k] or default` écraserait un `false` sauvegardé.

### Pattern récursif (defaults imbriqués)

```lua
local function ApplyDefaults(db, defaults)
    if type(db) ~= "table" then db = {} end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            db[k] = ApplyDefaults(db[k], v)
        elseif db[k] == nil then
            db[k] = v
        end
    end
    return db
end
```

### Proxy local

```lua
local db  -- déclaré mais pas assigné

-- Dans ADDON_LOADED :
MyAddonDB = MyAddonDB or {}
db = MyAddonDB  -- maintenant db pointe vers la table globale
```

⚠️ **Piège** : `local db = MyAddonDB` au top-level = `nil` car `ADDON_LOADED` n'a pas encore eu lieu.

### Reset propre

```lua
-- Utiliser wipe() plutôt que = {}
wipe(MyAddonDB)
-- Les proxys locaux (db) restent valides car la référence est conservée
```

---

## PLAYER_LOGOUT — Dernière chance

```lua
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        -- init...
    elseif event == "PLAYER_LOGOUT" then
        -- Sauvegarder des données de dernière minute
        MyAddonDB.lastLogout = time()
    end
end)
```

---

## Gotchas courants

1. **Oublier `## SavedVariables:` dans le .toc** → la variable existe en session mais n'est jamais sauvegardée. Bug #1 des débutants.
2. **Proxy local assigné trop tôt** → `local db = MyAddonDB` au top-level = `nil`
3. **Fonctions dans les SavedVars** → disparaissent silencieusement au reload
4. **Crash = perte de données** → pas de sauvegarde
5. **`VARIABLES_LOADED`** → ne pas utiliser, pas fiable pour les SavedVars
6. **Collision de noms** → préfixer les globales (`MyAddonDB` pas `DB`)
7. **Fichier parasitaire** → une copie de `SavedVariables.lua` à la racine de WoW peut être chargée à la place

## Taille

- Pas de limite documentée en octets
- Événement `SAVED_VARIABLES_TOO_LARGE` si le client manque de mémoire
- En pratique : quelques Mo sans problème, au-delà de ~50 Mo → freezes lors du chargement/sauvegarde

---

## Exemples d'add-ons Classic Era

| Add-on | SavedVars | Notes |
|--------|-----------|-------|
| **Questie** | `QuestieConfig` (compte), `QuestieConfigCharacter` (perso) | Sépare init SavedVars (ADDON_LOADED) et init UI (PLAYER_LOGIN) |
| **Deathlog** | 7 globales + 1 per-character | Utilise `wipe()` pour purger des caches |
| **RaidLogAuto** | `RaidLogAutoDB` | Pattern simple avec defaults flat |
| **Leatrix Plus** | `LeaPlusDB` | Validation défensive des types chargés |
