# Réponse Claude — Capsule 02 : Slash Commands

*Coller la réponse de Claude ci-dessous*

---

# Recherche — Slash Commands pour Add-on WoW Classic Era (1.15.x)

J'ai vérifié chaque point sur warcraft.wiki.gg, Wowpedia et le GitHub d'Ace3. Voici les résultats.

---

## 1. Enregistrement d'une slash command

**Oui, le mécanisme est bien celui que tu décris.** Le principe résumé par Warcraft Wiki : assigner une fonction handler à `SlashCmdList[key]`, et créer des constantes globales `SLASH_key1`, ..., `SLASH_keyn` contenant les noms de commandes souhaités, où *key* est une chaîne unique propre à la commande.

Source : https://warcraft.wiki.gg/wiki/Creating_a_slash_command

```lua
SLASH_HELLOWORLD1, SLASH_HELLOWORLD2 = '/hiw', '/hellow'
function SlashCmdList.HELLOWORLD(msg, editBox)
    print("Hello, World!")
end
```

**Détails par sous-question :**

- **Aliases via globals** : oui, `SLASH_<KEY>1 = "/monalias"`, `SLASH_<KEY>2 = "/autre"`, etc. WoW utilise la clé de `SlashCmdList` (ex. "TEST") pour trouver la globale `SLASH_TEST1`, puis itère `SLASH_TEST2`, `SLASH_TEST3`, etc. jusqu'à ce que la prochaine globale numérotée n'existe pas — les numéros doivent donc être consécutifs, sans trou. (https://addonstudio.org/wiki/WoW:Creating_a_slash_command)

- **Handler via `SlashCmdList["MONNAME"] = handler`** : oui, ou de façon équivalente `function SlashCmdList.MONNAME(msg, editBox) ... end`. Les deux écritures sont montrées dans le tutoriel officiel du wiki.

- **MAJUSCULES obligatoires ?** Conventionnelles, pas obligatoires. Les identifiants de commande sont généralement tout en majuscules, avec des underscores si nécessaire, mais ils peuvent aussi contenir des minuscules. L'essentiel est que la clé de `SlashCmdList` corresponde exactement au nom utilisé dans les globales `SLASH_<KEY>n`.

- **Nombre d'aliases** : illimité en pratique (tant que la numérotation est consécutive : 1, 2, 3...). Le wiki recommande toutefois d'être prudent sur le nombre d'aliases et de choisir des noms peu susceptibles d'entrer en collision avec ceux d'autres add-ons — y compris ceux de Blizzard.

- **Conflits avec une commande native** : les commandes de l'interface par défaut ont généralement la priorité sur les slash commands créées par les add-ons. Entre add-ons, il n'y a pas d'ordre de précédence défini : les conflits se résolvent de manière non déterministe, et si deux add-ons utilisent la même clé dans `SlashCmdList`, c'est le dernier à faire l'assignation qui possède la commande. Concrètement : `/hi` et `/hello` sont des emotes natives, donc le tutoriel du wiki choisit `/hiw` et `/hellow` à la place.

---

## 2. Signature du handler

- **Paramètres** : `(msg, editBox)`. Le wiki indique d'écrire une fonction handler prenant `(msg, editBox)` comme arguments et de l'assigner à `SlashCmdList["MYFANCYADDON"]`.

- **Contenu de `msg`** : quand l'utilisateur tape une commande commençant par "/test1", WoW exécute la fonction assignée à `SlashCmdList["TEST"]` en lui passant la chaîne de commande sans le préfixe "/test1 " comme `msg`. Donc :
  - `/ha` seul → `msg == ""` (chaîne vide, **jamais `nil`**) ;
  - `/ha test argument` → `msg == "test argument"`.
  - `msg` n'est **pas trimé** au-delà de l'espace séparateur : si l'utilisateur tape `/ha   foo  `, tu peux recevoir des espaces superflus. D'où l'usage quasi systématique de `strtrim()` ou d'un pattern `%s*` dans le parsing (`strtrim(string[, chars])` retire les espaces en début et fin de chaîne, https://warcraft.wiki.gg/wiki/Lua_functions).

- **`editBox`** : c'est un second paramètre rarement utilisé : il s'agit du frame edit box du chat depuis lequel la slash command a été tapée. C'est donc un widget `EditBox` (celui de la ChatFrame, ou celui d'un macro/autre source). Le wiki montre qu'on peut faire `editBox:Show()` et `editBox:SetText(...)` dessus. Il est présent lors d'une saisie normale dans le chat ; par prudence, les add-ons ne supposent généralement rien dessus.

- **Distinguer `/ha` de `/ha test argument`** : tester `msg == ""` (ou `strtrim(msg) == ""`) pour le cas sans argument, sinon parser `msg`.

---

## 3. Parsing d'arguments

**`strsplit` existe-t-il ?** Oui. `strsplit(delimiter, str [, pieces])` découpe une chaîne selon un délimiteur et retourne plusieurs valeurs ; il existe aussi `string.split` (alias) et `strsplittable` qui retourne un tableau (https://warcraft.wiki.gg/wiki/API_strsplit). Ces fonctions font partie des extensions Blizzard de la librairie string, présentes dans le client Classic Era 1.15 (qui utilise le moteur moderne). La liste des fonctions globales du wiki confirme la présence de `strsplit`, `strsplittable`, `strtrim`, `strmatch`, `strfind`, etc. (https://warcraft.wiki.gg/wiki/Global_functions)

⚠️ Limite importante : `strsplit` utilise une chaîne brute comme délimiteur, pas un pattern Lua — il est donc mal adapté aux arguments de ligne de commande où plusieurs espaces consécutifs devraient être tolérés. Pour extraire des arguments séparés par des espaces, le wiki recommande plutôt `string.gmatch(str, "[^ ]+")`.

**Pattern recommandé par Warcraft Wiki** (sous-commande + reste) — c'est LE pattern canonique pour `/ha help`, `/ha status`, `/ha do something here` :

```lua
local function handler(msg, editBox)
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    -- command = premier mot (non-espace), rest = tout le reste sans espace de tête
    if command == "add" and rest ~= "" then
        -- ...
    elseif command == "remove" and rest ~= "" then
        -- ...
    else
        print("Syntax: /yourcmd (add|remove) someIdentifier")
    end
end
```

(Code adapté de https://warcraft.wiki.gg/wiki/Creating_a_slash_command, section "Parsing Arguments".)

**Pattern utilisé par des add-ons connus** : la librairie **AceConsole-3.0** (embarquée par d'innombrables add-ons : ElvUI, Details, WeakAuras...) fournit un parseur robuste. AceConsole-3.0 fournit l'enregistrement de slash commands via `RegisterChatCommand("command", func)` et une fonction `GetArgs(str, numargs, startpos)` pour parser les arguments selon les besoins de l'add-on ; les arguments manquants sont retournés comme `nil`, et `nextposition` vaut 1e9 en fin de chaîne. `GetArgs` gère même les arguments entre guillemets et les hyperliens d'objets (`|Hitem:...|h`) comme un seul argument.

Source : https://github.com/WoWUIDev/Ace3/blob/master/AceConsole-3.0/AceConsole-3.0.lua et https://www.wowace.com/projects/ace3/pages/api/ace-console-3-0

---

## 4. Chat coloré

- **Format de couleur** : `|cAARRGGBBtexte|r`. Beaucoup d'éléments d'UI affichant du texte supportent des séquences d'échappement commençant par le caractère pipe (`|`) ; `|cAARRGGBB` définit la couleur du texte qui suit, et `|r` restaure la couleur précédente. Note : le composant **AA (alpha) est ignoré** pour la couleur du texte mais doit être présent — par convention on met `FF`. Donc oui, en pratique : `|cFFRRGGBBtexte|r`. Source : https://warcraft.wiki.gg/wiki/UI_escape_sequences

- **`print()` supporte-t-il les codes couleur ?** Oui, car `print()` finit dans la chat frame qui interprète les séquences d'échappement. `print(...)` passe ses arguments au print handler courant, qui par défaut les affiche tous dans la chat frame par défaut.

- **`DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)` en Classic Era ?** Oui. C'est une méthode du widget ScrollingMessageFrame, présente depuis toujours. Exemple du wiki : `DEFAULT_CHAT_FRAME:AddMessage("Testing", 1.0, 0.0, 0.0)` affiche "Testing" en rouge dans la fenêtre de chat par défaut ; les séquences d'échappement UI peuvent aussi être utilisées dans le texte, par ex. `AddMessage("messages can be |cffff0000red|r and |cff00ff00green|r!")`. Les paramètres r/g/b sont des nombres entre 0 et 1. Source : https://warcraft.wiki.gg/wiki/API_ScrollingMessageFrame_AddMessage

- **Différence `print()` vs `AddMessage()`** :
  - `print()` est un wrapper (ajouté au patch 3.0.2) autour du print handler courant — remplaçable via `setprinthandler(func)` — et sert de remplacement plus propre à `DEFAULT_CHAT_FRAME:AddMessage()` ; contrairement à ce dernier, il peut afficher des valeurs `nil` sans erreur. Il accepte un nombre quelconque d'arguments de n'importe quel type, les `tostring()` et les sépare par des espaces. (https://warcraft.wiki.gg/wiki/API_print)
  - `AddMessage()` n'écrit que dans **un frame précis**, prend une seule chaîne, mais permet de passer la couleur directement en paramètres `r, g, b` sans codes d'échappement. Détail historique : `print()` n'existait pas dans le Vanilla original de 2006 (ajout 3.0.2), mais **le client Classic Era 1.15 est moderne et l'inclut** — tu peux l'utiliser sans souci.

- **Préfixe coloré typique** : la quasi-totalité des add-ons concatènent un préfixe avec code couleur et le message :

```lua
print("|cFF33FF99[MonAddon]|r " .. message)
```

C'est exactement ce que fait `AceConsole:Print()` en interne (préfixe coloré `|cff33ff99NomAddon|r:` puis le message) — voir https://github.com/WoWUIDev/Ace3/blob/master/AceConsole-3.0/AceConsole-3.0.lua.

---

## 5. Exemple complet

**`HelloAzeroth/HelloAzeroth.toc`** (format basé sur https://warcraft.wiki.gg/wiki/Create_a_WoW_AddOn_in_15_Minutes ; pour Classic Era 1.15.8 l'interface est 11508) :

```toc
## Interface: 11508
## Title: HelloAzeroth
## Notes: Exemple minimal de slash command pour Classic Era
## Author: Toi
## Version: 1.0.0

HelloAzeroth.lua
```

**`HelloAzeroth/HelloAzeroth.lua`** :

```lua
-- HelloAzeroth.lua
local ADDON_PREFIX = "|cFF33FF99[HelloAzeroth]|r "

local function HA_Print(text)
    -- print() existe en Classic Era 1.15 (client moderne) et
    -- interprète les codes couleur |cAARRGGBB...|r
    print(ADDON_PREFIX .. text)
end

local function HA_Handler(msg, editBox)
    -- msg est la chaîne après la commande, "" si rien ; jamais nil.
    -- On normalise : trim + on extrait sous-commande et reste.
    msg = strtrim(msg or "")
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = string.lower(command)

    if command == "" then
        -- /ha sans argument
        HA_Print("Salut, Azeroth ! Tape |cFFFFFF00/ha help|r pour l'aide.")
    elseif command == "help" then
        HA_Print("Commandes disponibles :")
        HA_Print("  |cFFFFFF00/ha|r — message de bienvenue")
        HA_Print("  |cFFFFFF00/ha help|r — cette aide")
        HA_Print("  |cFFFFFF00/ha <message>|r — répète ton message")
    else
        -- Message libre : on répète tout ce qui a été tapé
        -- (command .. rest reconstitue le message complet)
        local fullMessage = rest ~= "" and (command .. " " .. rest) or command
        HA_Print("Tu as dit : |cFFFFD100" .. fullMessage .. "|r")
    end
end

-- Enregistrement : deux aliases, numérotation consécutive obligatoire
SLASH_HELLOAZEROTH1 = "/helloazeroth"
SLASH_HELLOAZEROTH2 = "/ha"
SlashCmdList["HELLOAZEROTH"] = HA_Handler
```

Points de robustesse appliqués (tous sourcés plus haut) : pattern `"^(%S*)%s*(.-)$"` du wiki officiel, `strtrim` pour les espaces parasites, gestion du cas `msg == ""`, clé `SlashCmdList` identique au nom des globales `SLASH_*`, aliases consécutifs, et préfixe coloré `|cFF...|r` fermé par `|r`.

---

## 6. Différences Classic Era vs Retail

**Pour le système de slash commands lui-même : aucune différence.** Le mécanisme `SLASH_*` + `SlashCmdList` est identique sur toutes les saveurs du jeu (Classic Era, Cataclysm/MoP Classic, Retail) — la page du wiki n'est d'ailleurs pas marquée comme spécifique à une version, et les exemples du tutoriel "Create a WoW AddOn in 15 Minutes" utilisent le même code avec un `## Interface:` Retail (le wiki montre le même pattern `SLASH_NEWRELOAD1 = "/rl"` / `SlashCmdList.NEWRELOAD = ReloadUI` avec un TOC d'interface 120005).

Nuances utiles à connaître :

1. **Le client Classic Era 1.15 ≠ Vanilla 2006.** C'est un client moderne, donc toutes les commodités post-vanilla sont disponibles : `print()` (ajouté en 3.0.2), `strsplit`/`strtrim`/`strmatch`, etc. Si tu lis de vieux guides Vanilla (vanilla-wow-archive), ignore leurs avertissements sur l'absence de ces fonctions.
2. **Différences périphériques, pas structurelles** : Retail a ajouté autour du chat des choses absentes ou différentes en Classic (par ex. le type de lien `addon:` pour les liens cliquables créés par add-on, et le système Addon Compartment, ajoutés en 10.1), mais rien de tout cela ne touche l'enregistrement ou le dispatch des slash commands.
3. **Le TOC diffère** : seule la valeur `## Interface:` change (11508 pour Classic Era 1.15.8 vs 12xxxx pour Retail). Tu peux aussi fournir des fichiers TOC à suffixe par saveur (`MonAddon_Vanilla.toc`, etc.) si tu cibles plusieurs versions — mécanisme de suffixes client introduit côté Blizzard avec les clients Classic (https://warcraft.wiki.gg/wiki/TOC_format).
4. **Conflits avec les commandes natives** : la liste des commandes/emotes natives diffère légèrement entre Classic et Retail, donc un alias libre sur l'un peut être pris sur l'autre — mais la règle de précédence (l'UI par défaut a priorité sur les commandes d'add-ons) est la même partout.

**Sources principales :**
- https://warcraft.wiki.gg/wiki/Creating_a_slash_command
- https://warcraft.wiki.gg/wiki/Create_a_WoW_AddOn_in_15_Minutes
- https://warcraft.wiki.gg/wiki/API_strsplit · https://warcraft.wiki.gg/wiki/Global_functions
- https://warcraft.wiki.gg/wiki/UI_escape_sequences
- https://warcraft.wiki.gg/wiki/API_ScrollingMessageFrame_AddMessage · https://warcraft.wiki.gg/wiki/API_print
- https://github.com/WoWUIDev/Ace3/blob/master/AceConsole-3.0/AceConsole-3.0.lua · https://www.wowace.com/projects/ace3/pages/api/ace-console-3-0