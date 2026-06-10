# Lua dans WoW Classic Era

> Consolidé à partir des recherches ChatGPT, Claude et Gemini (Session 1).

---

## Version de Lua

**Lua 5.1** — toutes les versions de WoW y compris Classic Era.

Ce que ça signifie pour les débutants :
- ✅ `local`, tables, metatables, opérateur de longueur `#`, `string.format()`, `pairs()`, `ipairs()`
- ❌ Pas de `//` (division entière), pas de `goto`, pas d'opérateurs bit à bit dans la syntaxe (utiliser la lib `bit`)
- ❌ Pas de `require()`, `dofile()`, `loadfile()` — WoW bloque l'accès au système de fichiers

## Modifications de WoW par rapport au Lua standard

### Supprimé (sécurité)
- Bibliothèque `io` (système de fichiers)
- `os.execute()` (commandes shell)
- `require()`, `dofile()`, `loadfile()` (chargement de fichiers externes)

### Conservé
- `os.time()`, `os.date()`, `os.clock()`
- `math.*`, `string.*`, `table.*`

### Ajouté par WoW
- `strsplit(sep, str)`, `strjoin(sep, ...)` — découpage/jonction de chaînes
- `tinsert(table, value)`, `tremove(table, pos)` — manipulation de tables
- `wipe(table)` — vider une table
- `GetCoinTextureString(copper)` — formater or/argent/cuivre
- Toute l'API WoW (`CreateFrame`, `GetItemInfo`, événements, etc.)

## Affichage dans le chat

### `print()` — recommandé pour les débutants
```lua
print("Hello Azeroth!")           -- message simple
print("Value:", 42, nil, true)    -- gère plusieurs args, nil, tout type
```
- Affiche dans la fenêtre de chat par défaut
- Gère `nil` et les arguments multiples gracieusement
- Ne permet pas de colorer directement via des paramètres, **mais** les codes couleur `|cFFRRGGBBtexte|r` sont interprétés

### `DEFAULT_CHAT_FRAME:AddMessage()` — pour la couleur
```lua
DEFAULT_CHAT_FRAME:AddMessage("Hello en vert !", 0, 1, 0)  -- RGB : plage 0-1
```
- Prend une seule chaîne en argument (il faut la construire soi-même)
- Permet le contrôle de la couleur en RGB (valeurs de 0.0 à 1.0)
- Erreur sur `nil` — il faut convertir en chaîne d'abord

**Règle : utiliser `print()` par défaut, `AddMessage` seulement quand on a besoin de couleurs par paramètre RGB.**

### Codes couleur (UI Escape Sequences)

Toutes les méthodes d'affichage (`print`, `AddMessage`, `SetFontString`, etc.) interprètent les séquences de couleur :

```
|cAARRGGBBtexte|r
```

- `|c` = début, `|r` = fin (restaure la couleur précédente)
- `AA` = alpha (ignoré pour le texte, toujours `FF`)
- `RRGGBB` = couleur hexadécimale

```lua
print("|cFFFF0000Rouge|r et |cFF00FF00Vert|r")
DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99[MonAddon]|r Message")
```

Source : [warcraft.wiki.gg — UI escape sequences](https://warcraft.wiki.gg/wiki/UI_escape_sequences)

## Portée globale et espace de noms

Tous les fichiers d'un add-on partagent le **même environnement Lua** — et cet environnement est partagé avec TOUS les autres add-ons et le code UI de Blizzard.

### L'astuce du vararg — espace de noms privé
```lua
-- Chaque fichier .lua reçoit ceci en varargs :
local addonName, ns = ...
-- addonName = "HelloAzeroth" (chaîne)
-- ns = une table partagée UNIQUEMENT entre les fichiers de cet add-on
```

### Mauvais vs Bon
```lua
-- ❌ MAUVAIS : pollue l'espace global, peut écraser d'autres add-ons
message = "Hello"
function update() end

-- ✅ BON : utiliser local ou l'espace de noms privé
local message = "Hello"
ns.message = "Hello"
ns.update = function() end
```

### Ne jamais utiliser ces noms comme variables (ce sont des globales WoW)
`CreateFrame`, `print`, `select`, `format`, `time`, `wipe`, `pairs`, `ipairs`, `tinsert`, `strsplit`, `DEFAULT_CHAT_FRAME`, `UIParent`, `GameTooltip`... en gros, tout ce que WoW définit, ne pas l'écraser.

**Règle : `local` pour tout par défaut.**

## Cycle de chargement

### Quand le code s'exécute-t-il ?

1. **Écran de chargement** (après la sélection du personnage, avant d'entrer dans le monde)
   - WoW scanne `Interface/AddOns/` pour trouver les fichiers `.toc`
   - Pour chaque add-on activé, charge les fichiers `.lua` dans l'ordre du `.toc`
   - **Le code au top-level s'exécute immédiatement** pendant cette phase
   - ⚠️ La fenêtre de chat peut ne pas être encore initialisée — `print()` au top-level peut ne pas être visible

2. **Après le chargement de tous les fichiers** — l'événement `ADDON_LOADED` se déclenche (une fois par add-on)
   - Les SavedVariables sont maintenant disponibles
   - Bon endroit pour initialiser les données

3. **Après le chargement de tous les add-ons** — l'événement `PLAYER_LOGIN` se déclenche
   - Tout le code des add-ons a été exécuté
   - L'UI est prête
   - **Meilleur événement pour un message « hello world »**

4. **Entrée dans le monde** — l'événement `PLAYER_ENTERING_WORLD` se déclenche
   - Se déclenche au login ET à chaque changement de zone/instance
   - Bon pour l'initialisation qui nécessite que le monde soit chargé

### Le piège de l'écran de chargement

```lua
-- Ça s'exécute pendant le loading screen — le joueur ne le verra probablement pas !
print("Hello from top-level code")

-- Ça s'exécute après le chargement du monde — le joueur le verra ✅
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    print("Hello Azeroth! Add-on loaded.")
end)
```

## Gestion des erreurs

### Activer l'affichage des erreurs (indispensable pour le dev)
```
/console scriptErrors 1
```
Sans ça, les erreurs Lua sont **silencieusement avalées**. L'add-on arrête juste de fonctionner sans aucun retour.

### Messages d'erreur courants

| Erreur | Signification |
|--------|---------------|
| `attempt to call a nil value` | Appel d'une fonction qui n'existe pas (faute de frappe, ou API Retail-only) |
| `attempt to index a nil value` | Accès à `.champ` sur quelque chose qui est nil (courant avec des SavedVariables non initialisées) |
| `unexpected symbol near 'x'` | Erreur de syntaxe — vérifier le numéro de ligne |

### Outils de debug avancés (pas pour les débutants)
- `/console taintLog 2` — journalise les problèmes de taint (conflits secure/protected). Trop bruyant pour les débutants.
- **BugSack + BugGrabber** — add-ons tiers qui fournissent un meilleur journal d'erreurs. À mentionner comme optionnels.

## `/reload` — le meilleur ami du développeur

### Ce qu'il fait
- Relit tous les fichiers depuis le disque
- Réexécute tout le code Lua des add-ons from scratch
- Efface tout l'état Lua (globales, locales, frames)
- Écrit les SavedVariables sur disque, puis les relit
- Équivalent à un redémarrage complet de l'UI sans déconnexion

### ✅ Vérifié en jeu (Session 2) : `/reload` détecte les nouveaux dossiers d'add-ons

La question est résolue : `/reload` détecte bien les nouveaux dossiers et les changements de TOC. Voir `open-questions.md` Q1 pour les détails.

### Ce qu'on sait avec certitude
- Modifier un fichier `.lua` existant → `/reload` le prend en compte ✅
- Les SavedVariables persistent à travers `/reload` ✅
- Impossible de recharger un seul add-on ✅

## Encodage des fichiers

- **UTF-8 sans BOM** — pour les fichiers `.lua` comme `.toc`
- Fins de ligne : WoW tolère LF et CRLF
- BOM (Byte Order Mark) peut corrompre les en-têtes `.toc` → l'add-on apparaît « out of date » ou ne se charge pas
