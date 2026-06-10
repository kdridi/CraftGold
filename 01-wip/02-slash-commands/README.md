# 02 — Slash Commands

| Metadata      | Value                                                    |
|---------------|----------------------------------------------------------|
| Phase         | Phase 1                                                  |
| Duration      | 30 min                                                   |
| Difficulty    | ●●○○○ (2/5)                                             |
| Prerequisites | Capsule 01 — Hello Azeroth                               |
| Type          | Autonomous                                               |
| Concepts      | `SLASH_*`, `SlashCmdList`, argument parsing, chat colors |

## Why This Capsule?

La capsule 01 nous a appris à créer un add-on minimal : un `.toc`, un `.lua`, un événement `PLAYER_LOGIN`, et un `print("Hello Azeroth!")`. Notre add-on parle… mais il ne nous **écoute** pas. Il dit bonjour au chargement et c'est tout.

Pour CraftGold, on aura besoin d'interagir avec l'add-on : `/cg scan` pour lancer un scan AH, `/cg status` pour voir l'état, `/cg help` pour l'aide. Sans slash command, l'add-on est un monologue.

Les slash commands sont aussi le premier outil de **debug** : taper une commande pour inspecter l'état interne, c'est indispensable pendant le développement.

Cette capsule nous fait passer du « add-on passif » au « add-on interactif ». Toutes les capsules suivantes utiliseront des slash commands.

## Objectifs

1. **REGISTER** une slash command avec 2 aliases (`/helloazeroth` et `/ha`)
2. **PARSE** les arguments (sous-commande + reste du message)
3. **DISPLAY** des messages avec un préfixe coloré `[HelloAzeroth]`

## Concepts clés

### SlashCmdList et SLASH_*

Le mécanisme WoW pour les slash commands personnalisées repose sur deux éléments :

1. Des **globals `SLASH_<TOKEN>N`** pour déclarer les aliases. Les numéros doivent être consécutifs (1, 2, 3...). Le token doit correspondre exactement à la clé dans `SlashCmdList`.

2. **`SlashCmdList["TOKEN"] = handler`** pour enregistrer la fonction qui traite la commande.

```lua
local addonName, ns = ...
local TOKEN = string.upper(addonName)  -- "HELLOAZEROTH"

_G["SLASH_" .. TOKEN .. "1"] = "/helloazeroth"
_G["SLASH_" .. TOKEN .. "2"] = "/ha"
SlashCmdList[TOKEN] = HandleSlash
```

Rien n'est codé en dur — si on renomme le dossier en `CraftGold`, tout s'adapte automatiquement.

### Signature du handler

```lua
local function HandleSlash(msg, editBox)
end
```

- `msg` = texte **après** la commande (`/ha toto titi` → `msg = "toto titi"`)
- `msg` est **trimé** par le moteur (vérifié en jeu) — `""` si pas d'argument, jamais `nil` via le chat
- Les espaces **internes** sont conservés (`/ha a   b` → `msg = "a   b"`)
- `editBox` = widget du chat (rarement utilisé)

### Parsing d'arguments

Le pattern canonique pour séparer sous-commande et reste :

```lua
local command, rest = msg:match("^(%S*)%s*(.-)$")
```

| Symbole | Signification |
|---------|---------------|
| `^` | Début de chaîne |
| `(%S*)` | Capture les non-espaces → sous-commande |
| `%s*` | Avale les espaces entre |
| `(.-)$` | Capture le reste (non-gourmand) jusqu'à la fin |

⚠️ **`.-` n'est PAS « un point suivi d'un tiret ».** C'est le quantificateur **non-gourmand** de Lua (équivalent regex `.*?`). `.` = n'importe quel caractère, `-` = « le moins possible ».

### Couleurs dans le chat

Le format WoW : `|cFFRRGGBBtexte|r` (alpha ignoré, toujours `FF`).

Plutôt que forger ces chaînes à la main, on utilise une fonction utilitaire :

```lua
local function RGB(text, r, g, b)
    return string.format("|cFF%02X%02X%02X%s|r", r, g, b, text)
end
```

Exemple : `RGB("Bonjour", 0xFF, 0x00, 0x00)` → texte rouge.

## Fonctions API utilisées

| Fonction | Rôle | Source |
|----------|------|--------|
| `SlashCmdList[token]` | Table globale pour enregistrer les handlers | [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Creating_a_slash_command) |
| `SLASH_<TOKEN>N` | Globals déclarant les aliases (numéros consécutifs) | idem |
| `strtrim(str)` | Retire les espaces en début/fin de chaîne | [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Global_functions) |
| `string.match(str, pattern)` | Extrait des sous-chaînes via un pattern Lua | Lua standard |
| `string.lower(str)` | Convertit en minuscules (insensibilité casse) | Lua standard |
| `string.format(fmt, ...)` | Formate une chaîne (comme printf en C) | Lua standard |
| `print(...)` | Affiche dans le chat (supporte les codes couleur) | [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_print) |

## Déroulement réel

### Ce qui a marché du premier coup
- L'enregistrement `SLASH_*` + `SlashCmdList` — exactement comme documenté
- Le parsing avec `"^(%S*)%s*(.-)$"` — fonctionne parfaitement
- Les couleurs avec `print()` — les escape sequences sont interprétées

### Ce qu'on a amélioré en Phase B
- **Fonction `RGB()`** — au lieu de forger `|cFFRRGGBB...|r` à la main (illisible), on a créé un utilitaire propre avec `string.format`
- **Bug de la reconstruction du message** — le code initial reconstruisait `full = command .. " " .. rest` pour le cas echo, ce qui avalait les espaces internes. Solution : utiliser directement `msg` original. Le parsing ne sert qu'à identifier les sous-commandes connues (`help`), pas à transformer le message libre.
- **`addonName` au lieu du dur** — on a repris le vararg `local addonName, ns = ...` de la capsule 01 pour déduire dynamiquement le token, le préfixe et les aliases `SLASH_*` via `_G[]`

### Vérification Phase 0 confirmée en jeu
- ✅ `msg` est **trimé** par le moteur (ChatGPT avait la bonne source FrameXML)
- ✅ Les espaces **internes** sont conservés

## Test

1. Copier le dossier dans `Interface/AddOns/`
2. `/reload` en jeu
3. Tester :

| Commande | Résultat attendu |
|----------|-----------------|
| `/ha` | Message d'accueil coloré |
| `/ha help` | Liste des commandes |
| `/ha coucou le monde` | `[HelloAzeroth] Tu as dit : coucou le monde` |
| `/ha a      b      c` | `[HelloAzeroth] Tu as dit : a      b      c` (espaces conservés) |
| `/helloazeroth bonjour` | `[HelloAzeroth] Tu as dit : bonjour` |

## Pièges rencontrés

| Piège | Solution |
|-------|----------|
| Codes couleur `|cFF...|r` illisibles | Fonction utilitaire `RGB()` + `string.format` |
| Reconstruction du message qui perd les espaces | Utiliser `msg` directement, pas `command .. " " .. rest` |
| `.-` confondu avec « point puis tiret » | C'est le quantificateur non-gourmand de Lua (`.*?` en regex) |
| Numéros d'alias non consécutifs | WoW s'arrête au premier manquant — toujours 1, 2, 3... |

## Going Further

- → Prochaine capsule : **03 — Saved Variables** (persistance de données entre les sessions)
