# Réponse ChatGPT — Capsule 02 : Slash Commands

*Coller la réponse de ChatGPT ci-dessous*

---

# Recherche — Capsule 02 : Slash Commands WoW Classic Era

## 0. Résultat court

Oui : le modèle de base est bien :

```lua
SLASH_HELLOAZEROTH1 = "/helloazeroth"
SLASH_HELLOAZEROTH2 = "/ha"

SlashCmdList["HELLOAZEROTH"] = function(msg, editBox)
  -- ...
end
```

Le moteur associe la clé `HELLOAZEROTH` de `SlashCmdList` aux globals consécutifs `SLASH_HELLOAZEROTH1`, `SLASH_HELLOAZEROTH2`, etc. Le nom doit donc correspondre exactement entre `SlashCmdList["..."]` et la partie centrale de `SLASH_<TOKEN><N>`. Les indices doivent être consécutifs, sans trou. ([addonstudio.org][1])

---

## 1. Enregistrement d’une slash command

### Aliases : `SLASH_<NAME>1 = "/monalias"` ?

Oui. Pour déclarer les alias, on crée des variables globales nommées `SLASH_<TOKEN>1`, `SLASH_<TOKEN>2`, etc. Exemple documenté : `SLASH_TEST1 = "/test1"`, `SLASH_TEST2 = "/addontest1"`, puis `SlashCmdList["TEST"] = function(msg) ... end`. ([addonstudio.org][1])

Le `<TOKEN>` est la clé commune qui relie les alias au handler : avec `SlashCmdList["TEST"]`, WoW cherche `SLASH_TEST1`, puis `SLASH_TEST2`, etc. ([addonstudio.org][1])

### Handler : `SlashCmdList["MONNAME"] = handler` ?

Oui. L’add-on doit placer une fonction dans la table globale `SlashCmdList`, sous la même clé que celle utilisée dans les globals `SLASH_<TOKEN>N`. La doc donne explicitement le pattern `SlashCmdList["MYADDON"] = handler` ou `function SlashCmdList.HELLOWORLD(msg, editbox) ... end`. ([addonstudio.org][1])

### Majuscules obligatoires ou conventionnelles ?

Les majuscules sont **conventionnelles**, pas strictement obligatoires. La doc dit que les identifiants de commande sont “generally all caps” mais peuvent aussi contenir des minuscules. En pratique, garde les majuscules : c’est plus lisible, plus standard, et ça évite les erreurs entre `SlashCmdList["HELLO"]` et `SLASH_HELLO1`. ([addonstudio.org][1])

Attention : ce qui est obligatoire, c’est la correspondance exacte entre la clé et le nom global : `SlashCmdList["HELLOAZEROTH"]` va avec `SLASH_HELLOAZEROTH1`, pas avec `SLASH_HelloAzeroth1`. ([addonstudio.org][1])

### Peut-on définir autant d’aliases qu’on veut ?

Oui, le mécanisme itère `SLASH_<TOKEN>1`, `SLASH_<TOKEN>2`, `SLASH_<TOKEN>3`, etc. jusqu’au premier index manquant. Les numéros doivent donc être consécutifs : si tu définis `SLASH_FOO1` et `SLASH_FOO3` mais pas `SLASH_FOO2`, `SLASH_FOO3` ne sera pas pris dans cette itération. ([addonstudio.org][1])

Aucun plafond pratique n’est documenté dans ces sources, mais la recommandation explicite est d’être prudent sur le nombre d’aliases et de choisir des commandes peu susceptibles de collisionner avec Blizzard ou d’autres add-ons. ([addonstudio.org][1])

### Conflit avec une commande native WoW

À éviter absolument. La doc indique que les commandes de l’UI par défaut ont souvent priorité sur les slash commands d’add-ons, et qu’il n’y a pas d’ordre de priorité défini entre add-ons en conflit. ([addonstudio.org][1])

Le code FrameXML cité sur WoWInterface montre aussi que les commandes sécurisées (`SecureCmdList`) sont vérifiées avant les commandes d’add-ons dans `SlashCmdList`, puis que `SlashCmdList` est consulté ensuite. ([WoWInterface][2])

Si deux add-ons utilisent le même **token** `SlashCmdList["FOO"]`, celui qui fait l’assignation en dernier possède la clé. Si deux add-ons utilisent le même **alias** `/foo`, le comportement n’est pas à considérer fiable : choisis toujours un alias long et namespacé, puis éventuellement un alias court. ([addonstudio.org][1])

---

## 2. Signature du handler

### Paramètres exacts : `(msg, editBox)` ?

Oui. La signature documentée est :

```lua
local function Handler(msg, editBox)
end
```

La doc AddOn Studio parle explicitement d’un handler prenant `(msg, editbox)`, et le code FrameXML cité appelle le handler avec `hash_SlashCmdList[command](strtrim(msg), editBox)`. ([addonstudio.org][1])

### `msg` est-il trimé ? Peut-il être `""` ? `nil` ?

Pour une commande tapée normalement dans le chat, `msg` est trimé par `strtrim(msg)` avant d’être passé au handler. `strtrim` enlève par défaut les espaces, tabs, retours chariot et newlines au début et à la fin. ([WoWInterface][2])

Donc :

```text
/ha              -> msg == ""
/ha    test      -> msg == "test"
/ha test arg     -> msg == "test arg"
```

Dans l’usage normal via le chat, `msg` doit être une string, et sans argument il faut le traiter comme `""`. Par contre, si un autre code appelle directement `SlashCmdList["HELLOAZEROTH"]()` sans argument, `msg` peut être `nil`; c’est pour cela qu’un handler robuste commence souvent par `msg = strtrim(msg or "")`. Le fait que les fonctions puissent être appelées directement via `SlashCmdList["TOKEN"]()` est documenté dans la discussion WoWInterface. ([WoWInterface][2])

### `editBox` est-il toujours présent ? Quel type ?

Quand la commande vient du chat, le second argument est l’edit box du chat d’où provient la commande. La doc le décrit comme “the chat frame edit box frame”, et montre qu’on peut appeler `editBox:Show()` et `editBox:SetText(...)` dessus. ([addonstudio.org][1])

Donc en invocation normale, c’est un widget/frame de type edit box de chat. En revanche, si quelqu’un appelle ton handler directement en Lua, `editBox` peut être absent ; évite donc de l’utiliser sans test. ([WoWInterface][2])

### Distinguer `/ha` de `/ha test argument`

Tu regardes simplement `msg` :

```lua
local function Handler(msg, editBox)
  msg = strtrim(msg or "")

  if msg == "" then
    -- /ha sans argument
  else
    -- /ha quelque chose
  end
end
```

Le handler reçoit la partie après la commande, sans `/ha` lui-même ; la doc donne explicitement l’exemple où `/yourcmd someargs` passe `someargs` comme premier argument `msg`. ([addonstudio.org][1])

---

## 3. Parsing d’arguments

### Fonctions disponibles : `strsplit` existe-t-il ?

`strsplit(delimiter, subject[, pieces])` existe dans l’API WoW Lua documentée : elle renvoie plusieurs valeurs, pas une table. Exemple : `local a, b, c = strsplit(" ", "a b c d", 3)`. ([WoWWiki Archive][3])

Mais `strsplit` n’est pas idéal pour parser des commandes utilisateur, parce qu’il utilise un délimiteur brut et non un pattern Lua ; la doc recommande plutôt `string.gmatch(..., "[^ ]+")` pour des arguments séparés par espaces variables. ([WoWWiki Archive][3])

Tu as aussi les fonctions Lua standard de pattern matching, comme `string.find`, `string.match`, `string.gmatch`, utilisées dans les exemples de slash commands. ([addonstudio.org][1])

### Pattern simple pour sous-commandes

Pour `/ha help`, `/ha status`, `/ha do something here`, un pattern robuste minimal est :

```lua
msg = strtrim(msg or "")

local cmd, rest = msg:match("^(%S+)%s*(.-)$")
cmd = cmd and cmd:lower() or ""
rest = strtrim(rest or "")
```

Résultat :

```text
/ha                  -> msg = "", cmd = "", rest = ""
/ha help             -> cmd = "help", rest = ""
/ha status           -> cmd = "status", rest = ""
/ha do something     -> cmd = "do", rest = "something"
```

Ce pattern suit l’approche documentée : parser `msg` avec des patterns Lua, extraire une sous-commande puis le reste de la ligne. L’exemple AddOn Studio utilise `string.find(msg, "%s?(%w+)%s?(.*)")` pour distinguer `add`, `remove` et les arguments restants. ([addonstudio.org][1])

### Pattern plus robuste utilisé par des add-ons connus : AceConsole-3.0

Beaucoup d’add-ons utilisent Ace3/AceConsole plutôt que de manipuler directement `SLASH_*`. AceConsole documente `RegisterChatCommand(command, func, persist)` pour enregistrer une commande sans le `/`, et `GetArgs(str, numargs, startpos)` pour récupérer des arguments séparés par espaces. ([wowace.com][4])

Le code source d’AceConsole montre qu’il crée lui-même une clé `ACECONSOLE_<COMMAND>`, assigne `SlashCmdList[name]`, puis crée `_G["SLASH_"..name.."1"] = "/"..command:lower()`. ([GitHub][5])

AceConsole va plus loin que `strsplit` : son `GetArgs` traite les chaînes citées et les liens WoW comme des arguments non séparés par espaces, ce qui est utile pour les commandes qui acceptent des noms, item links ou fragments avec espaces. ([wowace.com][4])

Exemple de style “AceConsole-like” sans dépendre d’Ace3 :

```lua
local function ParseCommandLine(msg)
  msg = strtrim(msg or "")

  if msg == "" then
    return "", ""
  end

  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  return (cmd or ""):lower(), strtrim(rest or "")
end
```

Pour un add-on débutant, c’est suffisant. Si tu veux gérer correctement les quotes, les item links, ou des syntaxes plus complexes, AceConsole est un bon modèle. ([wowace.com][4])

---

## 4. Chat coloré

### Format exact : `|cFFRRGGBBtexte|r` ?

Oui. Le format général est :

```text
|cAARRGGBBtexte|r
```

Dans WoW, l’alpha `AA` est documenté comme ignoré et devrait être `FF`, donc en pratique on écrit presque toujours :

```text
|cFFRRGGBBtexte|r
```

`|r` termine la couleur et restaure la couleur précédente. ([addonstudio.org][6])

Exemples :

```lua
"|cFFFF0000Rouge|r"
"|cFF00FF00Vert|r"
"|cFF33FF99[HelloAzeroth]|r Message normal"
```

Les séquences de couleur sont des “UI escape sequences” supportées par les éléments texte de l’UI. ([addonstudio.org][6])

### `print()` supporte-t-il les codes couleur ?

Oui, indirectement : `print(...)` envoie par défaut sa sortie vers la frame de chat par défaut, et les chaînes affichées dans l’UI supportent les escape sequences de couleur. ([addonstudio.org][7])

Exemple :

```lua
print("|cFF33FF99[HelloAzeroth]|r Bonjour")
```

`print()` accepte plusieurs arguments et les affiche via le print handler courant ; par défaut, c’est la chat frame par défaut. ([addonstudio.org][7])

### `DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)` existe-t-il ?

Oui. `AddMessage` est une méthode de `MessageFrame` qui affiche du texte avec des paramètres optionnels `red`, `green`, `blue`, `messageId`, `holdTime`. Les composantes RGB sont des floats entre `0.0` et `1.0`. ([addonstudio.org][8])

Exemple :

```lua
DEFAULT_CHAT_FRAME:AddMessage("Message vert", 0.2, 1.0, 0.4)
```

Tous les paramètres après `text` sont optionnels, donc tu peux aussi faire :

```lua
DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99[HelloAzeroth]|r Message normal")
```

([addonstudio.org][8])

### Différence entre `print()` et `DEFAULT_CHAT_FRAME:AddMessage()`

`print(...)` est le plus simple : il convertit plusieurs valeurs en texte, supporte mieux les `nil`, et envoie par défaut vers la chat frame par défaut. La doc le décrit même comme un remplacement plus propre de `DEFAULT_CHAT_FRAME:AddMessage()` pour les sorties simples. ([addonstudio.org][7])

`DEFAULT_CHAT_FRAME:AddMessage(...)` est plus explicite : tu choisis la frame cible, tu peux passer une couleur RGB pour tout le message, et tu contrôles les paramètres optionnels comme `messageId` et `holdTime`. ([addonstudio.org][8])

Pour un add-on pédagogique, je recommande `DEFAULT_CHAT_FRAME:AddMessage()` dans une petite fonction `Print`, car tu contrôles clairement le préfixe, la cible et le rendu. Cette approche ressemble aussi à celle d’AceConsole, dont `Print` ajoute un préfixe coloré puis appelle `frame:AddMessage(...)`. ([GitHub][5])

### Préfixe coloré typique

Pattern typique :

```lua
local PREFIX = "|cFF33FF99[MonAddon]|r "

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end
```

TomTom, par exemple, utilise un préfixe coloré du style `|cffffff78TomTom:|r` puis affiche le message via `ChatFrame1:AddMessage(msg)`. ([GitHub][9])

AceConsole utilise aussi un préfixe coloré en `|cff33ff99...|r:` avant d’appeler `frame:AddMessage(...)`. ([GitHub][5])

---

## 5. Exemple complet minimal

Structure attendue :

```text
Interface/AddOns/HelloAzeroth/
  HelloAzeroth.toc
  HelloAzeroth.lua
```

Le format `.toc` charge les fichiers listés ligne par ligne, et les lignes commençant par `##` sont des tags de métadonnées. Le nom du `.toc` par défaut doit correspondre au nom du dossier de l’add-on. ([addonstudio.org][10])

### `HelloAzeroth.toc`

```toc
## Interface: 11508
## Title: Hello Azeroth
## Notes: Minimal slash command example for WoW Classic Era
## Author: Karim
## Version: 0.1.0

HelloAzeroth.lua
```

`11508` correspond à Classic Era 1.15.8 dans des sources communautaires récentes ; le champ `## Interface` sert à indiquer au client la version d’interface visée par l’add-on. ([Blizzard Forums][11])

### `HelloAzeroth.lua`

```lua
-- HelloAzeroth.lua

local TOKEN = "HELLOAZEROTH"

local PREFIX = "|cFF33FF99[HelloAzeroth]|r "

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg or ""))
end

local function ShowHelp()
  Print("Commandes disponibles :")
  Print("|cFFFFFFFF/helloazeroth|r ou |cFFFFFFFF/ha|r : affiche l'aide si aucun argument.")
  Print("|cFFFFFFFF/ha help|r : affiche cette aide.")
  Print("|cFFFFFFFF/ha <message>|r : affiche le message après le préfixe.")
end

local function ParseArgs(msg)
  msg = strtrim(msg or "")

  if msg == "" then
    return "", "", ""
  end

  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = (cmd or ""):lower()
  rest = strtrim(rest or "")

  return cmd, rest, msg
end

local function HandleSlash(msg, editBox)
  local cmd, rest, fullMessage = ParseArgs(msg)

  if cmd == "" then
    Print("Aucun argument fourni. Tape |cFFFFFFFF/ha help|r pour voir l'aide.")
    return
  end

  if cmd == "help" or cmd == "?" then
    ShowHelp()
    return
  end

  -- Ici, tout ce qui n'est pas une sous-commande connue est traité
  -- comme un message libre. On garde fullMessage pour ne pas perdre
  -- le premier mot.
  Print(fullMessage)
end

SLASH_HELLOAZEROTH1 = "/helloazeroth"
SLASH_HELLOAZEROTH2 = "/ha"

SlashCmdList[TOKEN] = HandleSlash
```

Ce code applique le mécanisme documenté : alias globaux `SLASH_HELLOAZEROTH1/2`, handler dans `SlashCmdList["HELLOAZEROTH"]`, signature `(msg, editBox)`, parsing de `msg`, et affichage via `DEFAULT_CHAT_FRAME:AddMessage`. ([addonstudio.org][1])

Comportement attendu :

```text
/ha
=> [HelloAzeroth] Aucun argument fourni. Tape /ha help pour voir l'aide.

/ha help
=> [HelloAzeroth] Commandes disponibles :
=> [HelloAzeroth] /helloazeroth ou /ha : affiche l'aide si aucun argument.
=> [HelloAzeroth] /ha help : affiche cette aide.
=> [HelloAzeroth] /ha <message> : affiche le message après le préfixe.

/ha coucou Azeroth
=> [HelloAzeroth] coucou Azeroth
```

Le cas sans argument fonctionne parce que le handler reçoit la partie après la commande, trimée ; pour `/ha`, cette partie est vide. ([WoWInterface][2])

---

## 6. Différences Classic Era vs Retail

Je n’ai pas trouvé de différence de principe dans le système brut des slash commands personnalisées : le modèle `SLASH_<TOKEN>N` + `SlashCmdList["TOKEN"]` + handler `(msg, editBox)` est le modèle documenté côté add-ons WoW, et il est également reproduit par AceConsole, une bibliothèque utilisée largement par des add-ons. ([addonstudio.org][1])

Les différences Classic Era vs Retail se situent surtout dans les API que tu appelles **à l’intérieur** du handler, pas dans l’enregistrement de la slash command elle-même. Pour cette capsule précise, `SlashCmdList`, `SLASH_*`, `strtrim`, `strsplit`, `print`, les escape sequences couleur, et `MessageFrame:AddMessage` sont des API/mécanismes anciens et stables dans l’écosystème add-on. ([WoWInterface][2])

La prudence principale est la même dans Classic et Retail : éviter les collisions avec les commandes Blizzard et les autres add-ons, utiliser un token unique, préférer un alias long namespacé comme `/helloazeroth`, et considérer l’alias court `/ha` comme un confort potentiellement conflictuel. ([addonstudio.org][1])

[1]: https://addonstudio.org/wiki/WoW%3ACreating_a_slash_command "WoW:Creating a slash command - AddOn Studio"
[2]: https://www.wowinterface.com/forums/showthread.php?t=41942 "Blizz LOD interface changes - WoWInterface"
[3]: https://wowwiki-archive.fandom.com/wiki/API_strsplit "API strsplit | WoWWiki | Fandom"
[4]: https://www.wowace.com/projects/ace3/pages/api/ace-console-3-0 "api/AceConsole-3.0 - api - Pages - Ace3 - Addons - Projects - WowAce "
[5]: https://github.com/mikeboers/GoldFarmer/blob/master/Libs/AceConsole-3.0/AceConsole-3.0.lua "GoldFarmer/Libs/AceConsole-3.0/AceConsole-3.0.lua at master · mikeboers/GoldFarmer · GitHub"
[6]: https://addonstudio.org/wiki/WoW%3AUI_escape_sequences "WoW:UI escape sequences - AddOn Studio"
[7]: https://addonstudio.org/wiki/WoW%3AAPI_print "WoW API: print - AddOn Studio"
[8]: https://addonstudio.org/wiki/WoW%3AAPI_MessageFrame_AddMessage "Widget API: MessageFrame:AddMessage - AddOn Studio"
[9]: https://github.com/nanenj/wow-addons/blob/master/TomTom/TomTom.lua "wow-addons/TomTom/TomTom.lua at master · nanenj/wow-addons · GitHub"
[10]: https://addonstudio.org/wiki/WoW%3ATOC_format "WoW:TOC format - AddOn Studio"
[11]: https://eu.forums.blizzard.com/en/wow/t/latest-patches-killed-half-my-addons/593846?utm_source=chatgpt.com "Latest patches killed half my addons - WoW Classic ..."
