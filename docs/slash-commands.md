# Slash Commands — WoW Classic Era

> Source : recherche multi-LLM (Claude, Gemini, ChatGPT), Capsule 02.
> Toutes les sources pointent vers les mêmes faits. Les désaccords sont signalés.

---

## Mécanisme d'enregistrement

### 1. Définir les aliases (globals)

```lua
SLASH_HELLOAZEROTH1 = "/helloazeroth"
SLASH_HELLOAZEROTH2 = "/ha"
SLASH_HELLOAZEROTH3 = "/helloaz"
```

- Les globals doivent suivre le pattern `SLASH_<TOKEN><N>` où `<TOKEN>` correspond **exactement** à la clé dans `SlashCmdList`
- Les numéros doivent être **consécutifs** (1, 2, 3...) — s'il manque `SLASH_FOO2`, `SLASH_FOO3` sera ignoré
- Pas de limite pratique connue au nombre d'aliases
- Les MAJUSCULES pour le token sont **conventionnelles**, pas obligatoires

### 2. Enregistrer le handler

```lua
SlashCmdList["HELLOAZEROTH"] = MyHandler
-- ou :
function SlashCmdList.HELLOAZEROTH(msg, editBox)
    -- ...
end
```

Les deux écritures sont équivalentes.

### 3. Conflits

- Les commandes natives WoW (`SecureCmdList`) sont vérifiées **avant** `SlashCmdList` → elles ont priorité
- Entre add-ons : pas d'ordre défini. Si deux add-ons utilisent le même token, le dernier à assigner gagne
- **Recommandation** : utiliser des tokens longs et uniques, un alias court pratique mais risqué

Sources : [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Creating_a_slash_command), [addonstudio.org](https://addonstudio.org/wiki/WoW%3ACreating_a_slash_command), code FrameXML cité sur [WoWInterface](https://www.wowinterface.com/forums/showthread.php?t=41942)

---

## Signature du handler

```lua
local function MyHandler(msg, editBox)
    -- msg     = texte après la commande, "" si pas d'argument
    -- editBox = widget EditBox du chat (rarement utilisé)
end
```

### `msg`

- **Jamais `nil`** via le chat normal — toujours une string
- `""` si l'utilisateur tape juste `/ha`
- `"test argument"` si l'utilisateur tape `/ha test argument`
- **Trimé par le moteur** — le code FrameXML appelle `hash_SlashCmdList[command](strtrim(msg), editBox)`

> ⚠️ **Désaccord entre sources** : Claude dit que `msg` n'est pas trimé et peut contenir des espaces superflus. ChatGPT cite le code FrameXML qui montre `strtrim(msg)` appliqué avant l'appel. **ChatGPT a la source primaire** → `msg` est trimé. Mais `strtrim(msg or "")` reste une bonne pratique défensive (au cas où le handler serait appelé directement en Lua).

**→ À vérifier en jeu (Phase B)** : tester `/ha   foo  ` et afficher `("[%s]")` pour confirmer.

### `editBox`

- Widget `EditBox` du chat depuis lequel la commande a été tapée
- Toujours présent via le chat normal
- Rarement utilisé — les add-ons ne supposent généralement rien dessus

---

## Parsing d'arguments

### Pattern canonique (recommandé par warcraft.wiki.gg)

```lua
local function handler(msg, editBox)
    msg = strtrim(msg or "")
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    -- command = premier mot (non-espace), minuscules recommandées
    -- rest    = tout le reste, sans espace de tête

    command = command:lower()

    if command == "" then
        -- aucun argument
    elseif command == "help" then
        -- /ha help
    elseif command == "status" then
        -- /ha status
    else
        -- message libre : command .. " " .. rest reconstitue le tout
    end
end
```

Explication du pattern `"^(%S*)%s*(.-)$"` :
- `^(%S*)` — capture les caractères non-espaces du début → sous-commande
- `%s*` — ignore les espaces entre
- `(.-)$` — capture le reste (non gourmand) jusqu'à la fin → arguments

### Fonctions disponibles

| Fonction | Disponible | Notes |
|----------|------------|-------|
| `strsplit(sep, str [, pieces])` | ✅ Oui | Délimiteur brut, pas un pattern. Mal adapté aux espaces multiples |
| `strsplittable(sep, str [, pieces])` | ✅ Oui | Même chose mais retourne un tableau |
| `string.match(str, pattern)` | ✅ Oui | Recommandé pour le parsing |
| `string.gmatch(str, pattern)` | ✅ Oui | Itérateur, utile pour extraire tous les mots |

Source : [warcraft.wiki.gg — Global functions](https://warcraft.wiki.gg/wiki/Global_functions)

### Référence avancée : AceConsole-3.0

Les add-ons sérieux (ElvUI, Details, WeakAuras) utilisent AceConsole-3.0 qui fournit :
- `RegisterChatCommand("command", func)` — enregistrement sans manipuler `SLASH_*` directement
- `GetArgs(str, numargs, startpos)` — parsing robuste (supporte les guillemets et les item links `|Hitem:...|h`)

Source : [GitHub Ace3](https://github.com/WoWUIDev/Ace3/blob/master/AceConsole-3.0/AceConsole-3.0.lua), [wowace.com](https://www.wowace.com/projects/ace3/pages/api/ace-console-3-0)

---

## Chat coloré

### Format de couleur (UI Escape Sequences)

```
|cAARRGGBBtexte|r
```

- `|c` — début de la séquence couleur
- `AA` — alpha (ignoré pour le texte, toujours mettre `FF`)
- `RRGGBB` — composantes hexadécimales
- `|r` — restaure la couleur précédente

**En pratique** : `|cFFRRGGBBtexte|r`

```lua
"|cFFFF0000Rouge|r"        -- Rouge
"|cFF00FF00Vert|r"          -- Vert
"|cFF33FF99[MonAddon]|r"    -- Préfixe vert clair (comme AceConsole)
```

Source : [warcraft.wiki.gg — UI escape sequences](https://warcraft.wiki.gg/wiki/UI_escape_sequences)

### Méthodes d'affichage

#### `print(...)` — Simple et recommandé

```lua
print("|cFF33FF99[HelloAzeroth]|r " .. message)
```

- Supporte les codes couleur (le chat les interprète)
- Accepte plusieurs arguments de tout type, les `tostring()` et les sépare par des espaces
- Gère `nil` sans erreur
- Wrapper autour du print handler (remplaçable via `setprinthandler`)

Source : [warcraft.wiki.gg — API print](https://warcraft.wiki.gg/wiki/API_print)

#### `DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)` — Contrôle précis

```lua
DEFAULT_CHAT_FRAME:AddMessage("Message rouge", 1.0, 0.0, 0.0)
DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99[HelloAzeroth]|r Message")  -- OK aussi
```

- Cible une frame spécifique
- Couleur RGB en paramètres (0.0 à 1.0) sans codes d'échappement
- Prend une seule chaîne — `nil` provoque une erreur
- Paramètres optionnels : `messageId`, `holdTime`

Source : [warcraft.wiki.gg — ScrollingMessageFrame:AddMessage](https://warcraft.wiki.gg/wiki/API_ScrollingMessageFrame_AddMessage)

### Pattern typique de préfixe coloré

```lua
local PREFIX = "|cFF33FF99[HelloAzeroth]|r "

local function Print(msg)
    print(PREFIX .. msg)
end
```

C'est exactement ce que fait AceConsole en interne. La couleur `33FF99` (vert clair) est un standard communautaire.

---

## Classic Era vs Retail

**Aucune différence** sur le système de slash commands :
- `SLASH_*` + `SlashCmdList` identique partout
- `print()`, `strsplit`, `strtrim` disponibles (client Classic Era = moteur moderne)
- Les différences sont dans les API **périphériques** (gameplay), pas dans le mécanisme de commands

Sources : consensus 3/3 LLMs
