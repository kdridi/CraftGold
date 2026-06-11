# Fonctions API WoW — Dictionnaire progressif

> Ce fichier enrichit au fil des capsules. Chaque fonction est documentée quand elle est rencontrée pour la première fois.
> Références : [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API), [wowprogramming.com](https://wowprogramming.com/)

---

## Généralités

### `print(...)`

**Rôle** : Affiche un message dans la fenêtre de chat par défaut.

```lua
print("Hello")              -- "Hello"
print("Value:", 42, nil)    -- "Value:  42  nil"
```

- Accepte plusieurs arguments de n'importe quel type
- Gère `nil` gracieusement
- Supporte les codes couleur `|cFFRRGGBB...|r` (le chat les interprète)
- **Visible même au top-level** après `/reload` (vérifié Session 2)

---

## Frames

### `CreateFrame(frameType [, name] [, parent] [, template])`

**Rôle** : Crée un élément d'interface (frame). Les frames sont des conteneurs invisibles qui peuvent afficher du texte, recevoir des clics, écouter des événements, etc.

**Paramètres** :
- `frameType` (string, requis) — Type de frame : `"Frame"`, `"Button"`, `"Slider"`, `"EditBox"`, `"ScrollFrame"`, etc.
- `name` (string, optionnel) — Nom global de la frame (utile pour le debug). `nil` = anonyme. Si fourni, crée `_G[name]`.
- `parent` (frame, optionnel) — Frame parente. Les enfants héritent de la visibilité et de l'échelle du parent. `nil` = pas de parent. ⚠️ **UIParent n'est PAS ajouté automatiquement si nil**.
- `template` (string, optionnel) — Template(s) XML hérité(s). Plusieurs templates séparés par des virgules : `"BackdropTemplate, BasicFrameTemplate"`.

```lua
local frame = CreateFrame("Frame")                      -- frame anonyme, sans parent
local frame = CreateFrame("Frame", "MyFrame")           -- frame nommée (_G["MyFrame"] existe)
local frame = CreateFrame("Frame", "MyFrame", UIParent) -- frame attachée à l'UI
local frame = CreateFrame("Frame", "MyFrame", UIParent, "BackdropTemplate") -- avec backdrop
local btn = CreateFrame("Button", "MyBtn", UIParent, "UIPanelButtonTemplate")
```

**Types de frames courants** :
| Type | Rôle |
|------|------|
| `"Frame"` | Conteneur de base, invisible — utilisé pour écouter des événements |
| `"Button"` | Cliquable, a des états (normal, survolé, pressé) |
| `"CheckButton"` | Bouton à cocher |
| `"Slider"` | Barre de défilement ou slider de valeur |
| `"EditBox"` | Zone de saisie de texte |
| `"ScrollFrame"` | Zone avec défilement |
| `"StatusBar"` | Barre de progression |
| `"GameTooltip"` | Infobulle |
| `"Cooldown"` | Affichage de cooldown |
| `"MessageFrame"` | Zone de messages |

⚠️ `FontString` et `Texture` ne se créent **pas** via `CreateFrame` — utiliser `frame:CreateFontString()` et `frame:CreateTexture()`.

---

## Événements

### `frame:RegisterEvent(eventName)`

**Rôle** : Abonne la frame à un événement WoW. Sans ça, la frame ignore l'événement.

```lua
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
```

- On peut enregistrer **plusieurs événements** sur la même frame
- Le handler `OnEvent` reçoit le nom de l'événement pour savoir lequel s'est déclenché
- Pour se désabonner : `frame:UnregisterEvent(eventName)`

### `frame:SetScript(scriptType, handler)`

**Rôle** : Définit la fonction à appeler quand un script type se déclenche.

```lua
frame:SetScript("OnEvent", function(self, event, ...)
    -- self  = la frame
    -- event = nom de l'événement (ex: "PLAYER_LOGIN")
    -- ...   = arguments supplémentaires selon l'événement
end)
```

**Script types courants** :
| Script Type | Se déclenche quand... |
|-------------|----------------------|
| `"OnEvent"` | Un événement enregistré se produit |
| `"OnClick"` | La frame reçoit un clic |
| `"OnEnter"` | La souris entre sur la frame |
| `"OnLeave"` | La souris quitte la frame |
| `"OnUpdate"` | À chaque frame (~60 fois/sec) — Attention performance |
| `"OnShow"` | La frame devient visible |
| `"OnHide"` | La frame est masquée |
| `"OnDragStart"` | Un drag commence (bouton enregistré via `RegisterForDrag`) |
| `"OnDragStop"` | Le drag s'arrête (relâchement du bouton) |
| `"OnMouseDown"` | Bouton de souris pressé sur la frame |
| `"OnMouseUp"` | Bouton de souris relâché sur la frame |
| `"OnMouseWheel"` | Molette de souris sur la frame |
| `"OnKeyDown"` | Touche clavier pressée (si `EnableKeyboard(true)`) |
| `"OnKeyUp"` | Touche clavier relâchée |

---

## Événements WoW rencontrés

| Événement | Se déclenche quand... | Capsule |
|-----------|----------------------|---------|
| `PLAYER_LOGIN` | Le personnage se connecte (une seule fois par session) | 01 |
| `PLAYER_ENTERING_WORLD` | Entrée dans le monde (login + chaque changement de zone/instance) | 01 |
| `ADDON_LOADED` | Un add-on a fini de charger (une fois par add-on). Les SavedVars sont déjà peuplées. | 03 |
| `PLAYER_LOGOUT` | Le joueur se déconnecte/reload — dernière chance avant sauvegarde des SavedVars | 03 |
| `SAVED_VARIABLES_TOO_LARGE` | Les SavedVars d'un add-on sont trop volumineuses pour être chargées | 03 |
| `GET_ITEM_INFO_RECEIVED` | Données d'un item reçues du serveur — payload : `itemID` (number), `success` (bool) | 06 |
| `ITEM_DATA_LOAD_RESULT` | Données d'un item chargées en cache — payload : `itemID` (number), `success` (bool). Utilisé en interne par `ContinueOnItemLoad` | 09 |

---

## Add-ons

### `C_AddOns.GetAddOnMetadata(addonName, field)`

**Rôle** : Récupère un champ `##` du fichier `.toc` d'un add-on.

```lua
local version = C_AddOns.GetAddOnMetadata("HelloAzeroth", "Version")
local notes = C_AddOns.GetAddOnMetadata("HelloAzeroth", "Notes")
```

---

## Taille et position des frames

### `frame:SetSize(width, height)`

**Rôle** : Définit la largeur et la hauteur en une fois. Équivalent à `SetWidth(width) + SetHeight(height)`.

```lua
frame:SetSize(400, 300)
```

- Unité : unités UI (affectées par le UI Scale)
- ⚠️ Ignoré si la taille est déjà déduite de 2 ancres opposées

### `frame:SetPoint(point [, relativeTo [, relativePoint]] [, offsetX, offsetY])`

**Rôle** : Positionne la frame par rapport à un point d'ancrage.

```lua
frame:SetPoint("CENTER")                            -- centre sur le parent
frame:SetPoint("TOPLEFT", 10, -10)                  -- décalé depuis le parent
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- forme complète
```

- 9 points : `TOPLEFT`, `TOP`, `TOPRIGHT`, `LEFT`, `CENTER`, `RIGHT`, `BOTTOMLEFT`, `BOTTOM`, `BOTTOMRIGHT`
- Multi-ancrage possible (appeler plusieurs fois) → ⚠️ appeler `ClearAllPoints()` avant de changer

### `frame:ClearAllPoints()`

**Rôle** : Supprime toutes les ancres. À appeler avant un nouveau `SetPoint` si on change de position.

## Backdrop (fond et bordure)

### ⚠️ `BackdropTemplate` obligatoire en Classic Era 1.15.x

Depuis le patch 9.0 (rétroporté à Classic 1.14.0), `SetBackdrop` n'existe que sur les frames héritant de `BackdropTemplate` :

```lua
local frame = CreateFrame("Frame", "MyFrame", UIParent, "BackdropTemplate")
```

### `frame:SetBackdrop(backdropTable)`

**Rôle** : Applique un fond et/ou une bordure à la frame.

```lua
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
```

- Peut utiliser un backdrop prédéfini : `frame:SetBackdrop(BACKDROP_DIALOG_32_32)`
- `SetBackdrop(nil)` retire le backdrop
- ⚠️ **Toujours appeler avant** `SetBackdropColor` / `SetBackdropBorderColor`

### `frame:SetBackdropColor(r, g, b [, a])`

**Rôle** : Teinte le fond. Valeurs 0.0–1.0 (pas 0–255).

### `frame:SetBackdropBorderColor(r, g, b [, a])`

**Rôle** : Teinte la bordure. Valeurs 0.0–1.0.

## Drag (déplacement)

### `frame:SetMovable(movable)`

**Rôle** : Autorise la frame à être déplacée. `true`/`false`.

### `frame:EnableMouse(enable)`

**Rôle** : Permet à la frame de recevoir les événements de souris. **Obligatoire** pour le drag.

### `frame:RegisterForDrag(button, ...)`

**Rôle** : Enregistre quels boutons de souris déclenchent `OnDragStart`.

```lua
frame:RegisterForDrag("LeftButton")
frame:RegisterForDrag("LeftButton", "RightButton")
```

- Boutons : `"LeftButton"`, `"RightButton"`, `"MiddleButton"`, `"Button4"`, `"Button5"`
- Un nouvel appel **remplace** les précédents

### `frame:StartMoving()`

**Rôle** : Commence le déplacement de la frame (appelé dans `OnDragStart`).

- Peut être utilisé directement comme handler : `frame:SetScript("OnDragStart", frame.StartMoving)`

### `frame:StopMovingOrSizing()`

**Rôle** : Arrête le déplacement et fixe la nouvelle position (appelé dans `OnDragStop`).

- Active le flag "user placed" sur les frames nommées

### `frame:SetClampedToScreen(clamped)`

**Rôle** : Si `true`, empêche la frame de sortir des limites de l'écran.

### `frame:SetUserPlaced(userPlaced)`

**Rôle** : Si `false`, désactive la sauvegarde automatique de la position par le client.

## Visibilité

### `frame:Show()` / `frame:Hide()` / `frame:SetShown(bool)`

**Rôle** : Affiche, masque, ou bascule la visibilité de la frame.

### `frame:IsShown()` vs `frame:IsVisible()`

- `IsShown()` : la frame *veut* être visible (ne dépend pas des parents)
- `IsVisible()` : la frame est *réellement* à l'écran (prend en compte les parents)

## Strata et Level

### `frame:SetFrameStrata(strata)`

**Rôle** : Définit la couche d'affichage. Les stratas (de l'arrière vers l'avant) :

```
BACKGROUND → LOW → MEDIUM → HIGH → DIALOG → FULLSCREEN → FULLSCREEN_DIALOG → TOOLTIP
```

- Défaut pour les enfants de `UIParent` : `MEDIUM`

### `frame:SetFrameLevel(level)`

**Rôle** : Définit l'ordre dans la même strata (0–10000). La strata gagne toujours sur le level.

## Texte dans une frame

### `frame:CreateFontString(name, drawLayer, template)`

**Rôle** : Crée un texte (FontString) attaché à la frame.

```lua
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("Mon titre")
```

Fonts courantes : `"GameFontNormal"`, `"GameFontNormalLarge"`, `"GameFontHighlight"`, `"GameFontWhite"`.

---

## Utilitaires

### `select(index, ...)`

**Rôle** : Retourne les arguments à partir de l'index donné.

```lua
select(4, GetBuildInfo())  -- retourne seulement le 4e argument (interface version)
```

### `GetBuildInfo()`

**Rôle** : Retourne des infos sur la version du client.

```lua
local version, build, date, tocVersion = GetBuildInfo()
-- version    = "1.15.8"
-- build      = numéro de build
-- date       = date du build
-- tocVersion = 11508
```

---

## Saved Variables

### `wipe(table)`

**Rôle** : Vide une table **en place** (conserve la référence). ⚠️ Fonction WoW, pas Lua standard.

```lua
wipe(MyAddonDB)
-- MyAddonDB est toujours la même table, mais vide
```

- Alias de `table.wipe`
- Écrit en C, ultra-rapide
- Préférer à `MyAddonDB = {}` quand des références locales pointent vers la table
- ⚠️ **Pas disponible en Lua standard** — ne pas utiliser dans `src/Core.lua`

### `time()`

**Rôle** : Retourne le timestamp Unix actuel (nombre de secondes depuis le 01/01/1970).

```lua
local ts = time()  -- ex: 1781100188
```

### `date(format, timestamp)`

**Rôle** : Formate un timestamp en chaîne de caractères (similaire à la fonction C `strftime`).

```lua
date("%Y-%m-%d %H:%M:%S", time())  -- "2026-06-10 15:43:08"
```

---

## Slash Commands

### `SlashCmdList`

**Rôle** : Table globale où les add-ons enregistrent leurs handlers de slash commands.

```lua
SlashCmdList["HELLOAZEROTH"] = function(msg, editBox)
    -- handler
end
```

- La clé doit correspondre exactement au token dans `SLASH_<TOKEN>N`
- Écraser une clé existante = remplacer le handler

### `SLASH_<TOKEN>N` (globals)

**Rôle** : Déclarent les aliases d'une slash command.

```lua
SLASH_HELLOAZEROTH1 = "/helloazeroth"
SLASH_HELLOAZEROTH2 = "/ha"
```

- Numéros consécutifs obligatoires (1, 2, 3...)
- Convention : token en MAJUSCULES

---

## Chat

### `DEFAULT_CHAT_FRAME:AddMessage(msg [, r, g, b])`

**Rôle** : Affiche un message dans une frame de chat spécifique.

```lua
DEFAULT_CHAT_FRAME:AddMessage("Message rouge", 1.0, 0.0, 0.0)
DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99[Addon]|r Message")  -- codes couleur OK
```

- `r, g, b` : valeurs 0.0–1.0, optionnelles
- Paramètres supplémentaires optionnels : `messageId`, `holdTime`
- Ne gère pas `nil` — utiliser `tostring()` si nécessaire

---

## Strings (extensions WoW)

### `strtrim(str [, chars])`

**Rôle** : Retire les espaces (ou les caractères spécifiés) en début et fin de chaîne.

```lua
strtrim("  hello  ")      -- "hello"
strtrim("  hello  ", " h") -- "ello"
```

### `strsplit(sep, str [, pieces])`

**Rôle** : Découpe une chaîne selon un délimiteur brut. Retourne plusieurs valeurs.

```lua
local a, b, c = strsplit(" ", "un deux trois quatre", 3)
-- a = "un", b = "deux", c = "trois quatre"
```

- ⚠️ Délimiteur brut, pas un pattern Lua
- Mal adapté aux espaces multiples consécutifs

### `strsplittable(sep, str [, pieces])`

**Rôle** : Identique à `strsplit` mais retourne un tableau.

```lua
local parts = strsplittable(" ", "a b c")
-- parts = {"a", "b", "c"}
```

---

## Items

### `GetItemInfo(itemID)`

**Rôle** : Retourne les informations complètes d'un item. Peut retourner `nil` si l'item n'est pas encore en cache client (asynchrone).

```lua
local name, link, quality, itemLevel, reqLevel, class, subclass, maxStack, equipLoc, texture, sellPrice = GetItemInfo(2840)
-- name = "Copper Bar", link = "|cffffffff|Hitem:2840...", quality = 1, ...
```

- ⚠️ Peut retourner `nil` si l'item n'est pas en cache → écouter `GET_ITEM_INFO_RECEIVED`
- En Classic Era 1.15.x, les items de base sont quasi-toujours en cache immédiatement (données DB2 locales)
- Voir `docs/getiteminfo-cache.md` pour les détails du cache

### `GetItemInfoInstant(itemID)`

**Rôle** : Retourne seulement les infos disponibles localement (pas de requête serveur). Jamais `nil` pour un item valide.

```lua
local itemID, itemType, itemSubType, equipLoc, icon, classID, subclassID = GetItemInfoInstant(2840)
```

- Ne retourne **pas** le nom localisé ni le lien complet
- Utile pour icône, type, classe — sans risque d'async

### `Item:CreateFromItemID(itemID)`

**Rôle** : Crée un objet `Item` (Blizzard ObjectAPI) pour un itemID donné.

```lua
local item = Item:CreateFromItemID(2840)
```

- Disponible en Classic Era 1.15.x (vérifié dans `Blizzard_ObjectAPI/Classic/Item.lua`)
- Prérequis pour `ContinueOnItemLoad`

### `item:ContinueOnItemLoad(callback)`

**Rôle** : Exécute le callback quand les données de l'item sont disponibles en cache. Si déjà en cache, exécute immédiatement.

```lua
local item = Item:CreateFromItemID(recipe.output)
item:ContinueOnItemLoad(function()
    local name = item:GetItemName()
    -- name est garanti dispo ici
end)
```

- Gère la déduplication, le filtrage par itemID et le désabonnement automatiquement
- Utilise `ItemEventListener` en interne (événement `ITEM_DATA_LOAD_RESULT`)
- C'est l'API Blizzard recommandée pour la résolution async d'items
- **Garde anti-recyclage** : toujours vérifier `if self.recipe == recipe then` dans le callback

### `C_Item.GetItemNameByID(itemID)` — Capsule 09

**Rôle** : Retourne juste le nom localisé d'un item. Plus léger que `GetItemInfo()` quand on ne veut que le nom.

```lua
local name = C_Item.GetItemNameByID(2840)  -- "Copper Bar" / "Barre de cuivre" / etc.
```

- Retourne `nil` si l'item n'est pas en cache (même cache que `GetItemInfo`)
- Partage le même cache que `GetItemInfo()` — si l'un retourne une valeur, l'autre aussi
- Source : `Blizzard_APIDocumentationGenerated/ItemDocumentation.lua`

### `C_Item.IsItemDataCachedByID(itemID)` — Capsule 09

**Rôle** : Retourne `true` si les données complètes de l'item sont en cache local. **Synchrone**, jamais async.

```lua
if C_Item.IsItemDataCachedByID(2840) then
    -- GetItemInfo garant de retourner les données
end
```

- Utile pour décider si on peut appeler `GetItemInfo()` ou si on doit utiliser `ContinueOnItemLoad`
- Retourne `false` pour un itemID invalide

### `C_Item.GetItemIconByID(itemID)` — Capsule 09

**Rôle** : Retourne juste l'icône (fileID) d'un item.

```lua
local icon = C_Item.GetItemIconByID(2840)  -- ex: 135020
```

- Retourne `nil` si pas en cache

### `C_Item.GetItemQualityByID(itemID)` — Capsule 09

**Rôle** : Retourne juste la qualité (0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic...).

```lua
local quality = C_Item.GetItemQualityByID(2840)  -- 1 (Common)
```

- Retourne `nil` si pas en cache

### `C_Item.RequestLoadItemDataByID(itemID)` — Capsule 09

**Rôle** : Demande explicitement au client de charger les données d'un item. Déclenche `ITEM_DATA_LOAD_RESULT` quand c'est prêt.

```lua
C_Item.RequestLoadItemDataByID(2840)
```

- Utilisé en interne par `ContinueOnItemLoad`
- Rarement nécessaire d'appeler directement — `ContinueOnItemLoad` le fait pour vous

### `Mixin(object, mixinTable)`

**Rôle** : Copie toutes les méthodes d'une table mixin dans un objet. Pattern idiomatique WoW pour la composition.

```lua
Mixin(myFrame, RecipeLineMixin)
-- myFrame hérite maintenant de RecipeLineMixin.Render, SetRecipe, etc.
```

- Fourni par le client WoW (`FrameXML`)
- Equivalent à copier les clés d'une table dans une autre
- Alternative Lua 5.1 pur : `for k, v in pairs(mixin) do obj[k] = v end`

---

## Boutons

> Source : `Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua`, `Blizzard_SharedXML/SecureUIPanelTemplates.xml`.
> Voir aussi : `docs/buttons.md` pour la documentation complète.

### `button:SetText(text)` / `button:GetText()`

**Rôle** : Définit ou lit le texte affiché sur le bouton.

```lua
btn:SetText("Click Me")
local txt = btn:GetText()  -- "Click Me"
```

### `button:SetFormattedText(fmt, ...)`

**Rôle** : Définit le texte du bouton avec un format (comme `string.format`).

```lua
btn:SetFormattedText("Clics : %d", count)
```

### `button:SetScript("OnClick", function(self, button, down) ... end)`

**Rôle** : Définit le handler appelé quand le bouton est cliqué.

```lua
btn:SetScript("OnClick", function(self, button, down)
    -- self    = le bouton
    -- button  = "LeftButton", "RightButton", "MiddleButton", etc.
    -- down    = true (enfoncé) ou false (relâché)
end)
```

### `button:Enable()` / `button:Disable()` / `button:SetEnabled(bool)`

**Rôle** : Active ou désactive le bouton. Un bouton désactivé est grisé et OnClick ne se déclenche pas.

```lua
btn:Disable()
btn:Enable()
btn:SetEnabled(false)  -- équivalent à Disable()
```

### `button:IsEnabled()`

**Rôle** : Retourne `true` si le bouton est actif.

### `button:RegisterForClicks(...)`

**Rôle** : Définit quels clics déclenchent OnClick.

```lua
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
```

Options : `"LeftButtonUp"`, `"LeftButtonDown"`, `"RightButtonUp"`, `"RightButtonDown"`, `"AnyUp"`, `"AnyDown"`.

### `button:SetNormalTexture(asset)` / `SetPushedTexture` / `SetHighlightTexture` / `SetDisabledTexture`

**Rôle** : Définit la texture pour chaque état du bouton. `asset` = chemin de fichier ou atlas.

```lua
btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
```

### `button:SetNormalFontObject(font)` / `SetHighlightFontObject` / `SetDisabledFontObject`

**Rôle** : Définit la police pour chaque état du bouton.

```lua
btn:SetNormalFontObject(GameFontNormal)
btn:SetDisabledFontObject(GameFontDisable)
```

### `button:SetPushedTextOffset(offsetX, offsetY)`

**Rôle** : Décale le texte du bouton quand il est pressé (effet visuel de profondeur).

---

## Templates de boutons

### `UIPanelButtonTemplate`

Template standard de bouton Blizzard. Taille par défaut 40×22. Fournit :
- 3 textures (Left/Middle/Right) qui changent selon l'état
- Fonts par état : `GameFontNormal`, `GameFontHighlight`, `GameFontDisable`
- Highlight en mode ADD
- Support tooltip via `self.tooltipText`

```lua
local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
btn:SetSize(120, 24)
btn:SetText("OK")
```

### `UIPanelCloseButton`

Bouton X de 32×32. Handler par défaut : cache le parent.

```lua
local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4)
```
