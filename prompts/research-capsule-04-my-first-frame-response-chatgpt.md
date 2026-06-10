# Capsule 04 — My First Frame — WoW Classic Era 1.15.x / Interface 11508

> Hypothèse de cible : **Classic Era / Season of Discovery 1.15.8, Interface `11508`**. Cette valeur est cohérente avec les add-ons Classic Era récents qui indiquent `Interface version updated to 11508`, et tu peux toujours vérifier côté client avec `/dump select(4, GetBuildInfo())`. ([curseforge.com][1])
> Point important : **Classic Era n’est pas Vanilla 1.12 pur**. Blizzard a backporté beaucoup de mécanique UI moderne dans les branches Classic ; les sources exactes d’un build se vérifient via `ExportInterfaceFiles code` ou via des miroirs comme `Gethe/wow-ui-source` sur la branche `classic`. ([Blizzard Forums][2])

---

## 1. `CreateFrame` — types et paramètres

### Signature

La signature moderne est :

```lua
local frame = CreateFrame(frameType, name, parent, template)
```

Les anciennes docs documentent aussi la forme :

```lua
local frame = CreateFrame("frameType"[, "frameName"[, parentFrame[, "inheritsFrame"]]])
```

`frameType` est une string comme `"Frame"`, `"Button"`, `"CheckButton"`, etc. `name` peut être `nil`. `parent` doit être un objet frame, pas une string. `template` est optionnel. ([WoWWiki Archive][3])

### Types de frames disponibles

Warcraft Wiki indique que les types possibles viennent du **XML schema `UI.xsd`**. Pour les branches modernes de WoW / Classic modernisé, la liste visible dans les docs API / schema comprend notamment :

```text
Frame
ArchaeologyDigSiteFrame
Browser
Button
CheckButton
Checkout
CinematicModel
ColorSelect
Cooldown
DressUpModel
EditBox
FogOfWarFrame
GameTooltip
MessageFrame
Minimap
Model
ModelScene
MovieFrame
OffScreenFrame
PlayerModel
QuestPOIFrame
ScenarioPOIFrame
ScrollFrame
ScrollingMessageFrame
SimpleHTML
Slider
StatusBar
TabardModel
UnitPositionFrame
```

Pour une capsule débutant, les types réellement utiles sont surtout `"Frame"`, `"Button"`, `"CheckButton"`, `"Slider"`, `"EditBox"`, `"ScrollFrame"`, `"StatusBar"` et parfois `"GameTooltip"`. Les types comme `Checkout`, `Minimap`, `QuestPOIFrame`, `ScenarioPOIFrame` ou `UnitPositionFrame` sont des widgets internes/spécialisés, pas des bases normales pour un add-on pédagogique. ([Warcraft Wiki][4])

Attention : `FontString` et `Texture` ne se créent pas avec `CreateFrame()`. On les crée depuis une frame via `frame:CreateFontString()` et `frame:CreateTexture()`. Les docs Widget API distinguent les widgets créés par `CreateFrame()` des régions comme textures et font strings. ([Warcraft Wiki][5])

### `template` : string unique ou héritage multiple ?

Le 4e paramètre est une **string**. Cette string peut contenir **un seul template** :

```lua
CreateFrame("Frame", "MyFrame", UIParent, "BackdropTemplate")
```

ou **plusieurs templates séparés par des virgules** :

```lua
CreateFrame("GameTooltip", "MyTooltip", UIParent, "BackdropTemplate,GameTooltipTemplate")
```

Ce n’est donc pas plusieurs paramètres Lua séparés : c’est une seule string comma-separated. Les anciennes docs appellent ce paramètre `inheritsFrame` et précisent qu’il peut être une liste de noms de frames virtuelles à hériter, comme en XML. Des exemples Blizzard/forum utilisent bien `"BackdropTemplate,GameTooltipTemplate"`. ([WoWWiki Archive][3])

### Frame nommée vs anonyme

Avec un nom :

```lua
local f = CreateFrame("Frame", "MyFrame", UIParent)
```

WoW crée aussi une variable globale :

```lua
_G["MyFrame"] == f
```

Les anciennes docs précisent que `CreateFrame` définit une variable globale portant ce nom. C’est pratique pour `/fstack`, le debug, certains layouts, et les templates XML, mais cela pollue l’espace global et peut créer des collisions. ([WoWWiki Archive][3])

Avec `nil` :

```lua
local f = CreateFrame("Frame", nil, UIParent)
```

la frame est anonyme : pas de variable globale `_G["..."]`. C’est généralement préférable pour du code propre, sauf si tu veux explicitement un nom global pour debug ou compatibilité. Si `frameName` est `nil`, aucun nom de frame n’est assigné. ([WoWWiki Archive][3])

---

## 2. Frame methods — taille et position

## Taille

`SetSize(width, height)` existe dans l’API moderne et permet de régler largeur + hauteur en une seule fois :

```lua
frame:SetSize(400, 300)
```

Il existe aussi :

```lua
frame:SetWidth(400)
frame:SetHeight(300)
```

Les docs `ScriptRegionResizing:SetSize` décrivent `SetSize(width, height)` comme l’équivalent pratique de `SetWidth` + `SetHeight`. ([Warcraft Wiki][6])

L’unité est une **unité UI WoW**, souvent appelée “pixel” dans les anciennes docs, mais elle dépend de l’échelle UI. Les docs de coordonnées anciennes précisent que les offsets sont dans l’espace effectif de l’UI, avec une hauteur virtuelle historique de 768 unités et une largeur dépendante du ratio d’écran. Pour enseigner proprement : dis “unités UI”, pas “pixels physiques écran”. ([WoWWiki Archive][7])

Gotcha : si la taille est déjà déduite de deux ancres opposées, `SetSize`, `SetWidth` ou `SetHeight` peut ne pas avoir l’effet attendu, car la géométrie est contrainte par les anchors. ([Wowpedia][8])

## Position — système d’anchors

Syntaxe générale :

```lua
frame:SetPoint(point, relativeFrame, relativePoint, offsetX, offsetY)
```

Exemple :

```lua
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
```

Formes raccourcies courantes :

```lua
frame:SetPoint("CENTER")
frame:SetPoint("CENTER", 0, 0)
```

Si `relativeTo` est omis, WoW ancre par défaut relativement au parent quand c’est applicable, sinon relativement à l’écran. Si `relativeTo` est explicitement `nil`, l’ancre est relative à l’écran. ([Warcraft Wiki][9])

### Points d’ancrage complets

Les points standards sont :

```text
TOPLEFT
TOP
TOPRIGHT
LEFT
CENTER
RIGHT
BOTTOMLEFT
BOTTOM
BOTTOMRIGHT
```

Ce sont les points qu’il faut enseigner pour `SetPoint`. Il n’y a pas d’autre point utile pour une frame standard. Les docs `SetPoint` et les exemples FrameXML utilisent ces ancres. ([Warcraft Wiki][9])

### Peut-on appeler `SetPoint()` plusieurs fois ?

Oui. C’est même un usage normal :

```lua
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -20)
frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 20)
```

Dans cet exemple, la frame est étirée entre deux coins : sa taille vient des anchors, pas de `SetSize`. Les docs notent que plusieurs points peuvent interagir et qu’avant de repositionner une frame il faut souvent nettoyer les ancres existantes. ([WoWWiki Archive][7])

### `ClearAllPoints()`

`ClearAllPoints()` supprime toutes les ancres :

```lua
frame:ClearAllPoints()
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
```

On l’utilise avant de repositionner une frame pour éviter qu’un ancien anchor continue de contraindre la géométrie. Les docs précisent que cela sert à éviter des rectangles invalides ou des déformations. ([Warcraft Wiki][10])

Attention : une frame sans anchor exploitable peut ne plus être affichable correctement. Les anciennes docs indiquent qu’après `ClearAllPoints`, une frame peut disparaître tant qu’un nouveau point n’est pas posé. ([WoWWiki Archive][11])

### Que se passe-t-il sans parent et sans point ?

Une frame créée par `CreateFrame` est initialement “shown”, mais sans parent clair, sans taille et sans point d’ancrage, elle n’a pas de géométrie utile à afficher. Pour une capsule débutant, utilise toujours :

```lua
local frame = CreateFrame("Frame", nil, UIParent)
frame:SetSize(400, 300)
frame:SetPoint("CENTER")
```

Les docs `CreateFrame` précisent que le parent ne devient pas automatiquement `UIParent` si tu passes `nil`, et les docs `SetPoint` expliquent le comportement parent/écran quand `relativeTo` est omis. ([WoWWiki Archive][3])

---

## 3. Backdrop — fond et bordure

C’est le point critique.

## `SetBackdrop` en Classic Era

En Retail moderne, `Frame:SetBackdrop` **n’est plus directement disponible sur toutes les frames** : l’API backdrop a été déplacée vers `BackdropTemplate` / `BackdropTemplateMixin` à partir de la refonte 9.0.1. ([Warcraft Wiki][12])

Pour Classic, point important : `BackdropTemplate` a été **backporté dans les clients Classic**. Warcraft Wiki indique que `BackdropTemplate` a été backporté dans les flavours Classic à partir de Classic Patch 1.14.0. Donc en Classic Era 1.15.x, la bonne pratique est de créer ta frame avec `"BackdropTemplate"` si tu veux utiliser `SetBackdrop`. ([Warcraft Wiki][13])

Donc, pour Classic Era 1.15.x :

```lua
local frame = CreateFrame("Frame", "MyFrame", UIParent, "BackdropTemplate")
frame:SetBackdrop({...})
```

est la forme recommandée. Ne pars pas du principe qu’une frame nue possède toujours `SetBackdrop`. Les forums Blizzard montrent des erreurs typiques quand des templates comme `GameTooltipTemplate` ou `SharedTooltipTemplate` n’héritent plus implicitement de `BackdropTemplate`, et la correction consiste à ajouter explicitement `BackdropTemplate`. ([Blizzard Forums][14])

Pour du code multi-version ultra défensif :

```lua
local template = BackdropTemplateMixin and "BackdropTemplate" or nil
local frame = CreateFrame("Frame", "MyFrame", UIParent, template)
```

Mais pour une capsule ciblée **Classic Era 1.15.8**, tu peux enseigner simplement `"BackdropTemplate"`.

## Structure de table backdrop

Ta table est correcte :

```lua
local backdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
}
```

Les champs documentés sont notamment `bgFile`, `edgeFile`, `tile`, `tileSize`, `edgeSize`, `insets`; les docs anciennes et XML montrent exactement ce type de structure. ([AddOn Studio][15])

Textures utiles :

```lua
-- Fond tooltip sombre, très courant
bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"

-- Bordure tooltip
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border"

-- Fond boîte de dialogue
bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"

-- Bordure boîte de dialogue
edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border"

-- Fond tutorial
bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground"

-- Fond “roche” moderne
bgFile = "Interface\\FrameGeneral\\UI-Background-Rock"

-- Texture blanche/solide utile pour bordures custom
edgeFile = "Interface\\Buttons\\WHITE8x8"
```

Les chemins tooltip/dialog/tutorial sont documentés dans les exemples XML Backdrop ; `WHITE8x8` est utilisé classiquement comme texture solide pour border/backdrop custom dans des exemples WoWInterface. ([AddOn Studio][16])

Tu peux omettre `bgFile` ou `edgeFile` :

```lua
-- Fond seulement
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
})

-- Bordure seulement
frame:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
})
```

En Lua, `bgFile = nil` revient à ne pas mettre le champ. Les attributs `bgFile` et `edgeFile` sont optionnels côté XML/schema, et `SetBackdrop(nil)` signifie autre chose : retirer tout le backdrop. ([AddOn Studio][16])

## `SetBackdropColor` et `SetBackdropBorderColor`

Syntaxe :

```lua
frame:SetBackdropColor(r, g, b, a)
frame:SetBackdropBorderColor(r, g, b, a)
```

Les valeurs sont en **0.0 à 1.0**, pas en 0 à 255 :

```lua
frame:SetBackdropColor(0, 0, 0, 0.85)      -- noir semi-opaque
frame:SetBackdropBorderColor(1, 1, 1, 1)  -- blanc opaque
```

Les docs `SetBackdropBorderColor` indiquent une plage de 0 à 1, et les docs `SetBackdropColor` décrivent bien une couleur + alpha appliqués au backdrop. ([WoWWiki Archive][17])

`SetBackdropColor` teinte le `bgFile`. Si le `bgFile` est absent, il n’y a pas de fond à teinter. `SetBackdropBorderColor` teinte le `edgeFile`. Si le `edgeFile` est absent, il n’y a pas de bordure à teinter. Les docs XML expliquent que `Color` colorise la texture de fond et `BorderColor` colorise la texture de bordure. ([Wowpedia][18])

---

## 4. Dragging — rendre une frame déplaçable

La séquence habituelle est correcte :

```lua
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)
```

Les docs “Making draggable frames” utilisent précisément `SetMovable(true)`, `EnableMouse(true)`, `RegisterForDrag("LeftButton")`, `StartMoving` et `StopMovingOrSizing`. ([AddOn Studio][19])

Version robuste recommandée :

```lua
frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
    self.isMoving = true
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.isMoving = false
end)

frame:SetScript("OnHide", function(self)
    if self.isMoving then
        self:StopMovingOrSizing()
        self.isMoving = false
    end
end)
```

Le handler `OnHide` évite de laisser la frame dans un état bizarre si elle est cachée pendant un drag ; les guides de frames déplaçables recommandent de gérer ce cas. ([AddOn Studio][19])

### `RegisterForDrag()`

Arguments documentés :

```lua
frame:RegisterForDrag("LeftButton")
frame:RegisterForDrag("RightButton")
frame:RegisterForDrag("LeftButton", "RightButton")
```

Les boutons documentés sont notamment `"LeftButton"`, `"RightButton"`, `"MiddleButton"`, `"Button4"`, `"Button5"`. `RegisterForDrag()` sans argument retire les boutons précédemment enregistrés, et un nouvel appel remplace les anciens boutons. Les docs ne listent pas `"AnyButton"` pour `RegisterForDrag`; `"AnyButton"` est plutôt rencontré côté clics, pas comme valeur standard ici. ([Warcraft Wiki][20])

### `StartMoving()` et sauvegarde de position

`StartMoving()` ne garde pas “magiquement” ton anchor original. Les anciennes docs indiquent qu’il désancre la frame de son ancien référentiel et la repositionne relativement à l’écran ; `StopMovingOrSizing()` choisit ensuite un anchor écran proche. ([WoWWiki Archive][21])

`StopMovingOrSizing()` arrête le déplacement. Il ne sauvegarde pas dans tes `SavedVariables`. Le client peut sauvegarder certaines positions de frames nommées via le layout cache / mécanisme user-placed, mais ce n’est pas une sauvegarde applicative fiable pour ton add-on. Pour une capsule sérieuse, dis : **si tu veux restaurer proprement la position, sauvegarde-la toi-même dans SavedVariables**. Les docs `StartMoving` / `SetUserPlaced` expliquent le comportement user-placed, notamment que les frames anonymes ne sont pas restaurées comme les frames nommées. ([WoWWiki Archive][21])

### `SetClampedToScreen(true)`

Oui, c’est standard :

```lua
frame:SetClampedToScreen(true)
```

Cela empêche la frame de partir hors écran pendant les déplacements, redimensionnements ou repositionnements. ([WoWWiki Archive][22])

---

## 5. Show / Hide

Syntaxe :

```lua
frame:Show()
frame:Hide()
```

`Show()` rend la frame “shown”, `Hide()` la rend “not shown”. Les objets créés via `CreateFrame`, `CreateFontString` ou `CreateTexture` sont initialement shown. ([AddOn Studio][23])

Différence importante :

```lua
frame:IsShown()
frame:IsVisible()
```

`IsShown()` répond : “cette frame veut-elle être montrée ?”
`IsVisible()` répond : “est-elle réellement visible à l’écran, en tenant compte aussi des parents ?”

Donc si un parent est caché, un enfant peut avoir :

```lua
child:IsShown()   -- true
child:IsVisible() -- false
```

Les docs `IsShown` et `IsVisible` décrivent exactement cette différence. ([Warcraft Wiki][24])

Pour une frame sans parent créée par `CreateFrame("Frame")`, `print(frame:IsShown())` retourne normalement `true`, car les frames créées par `CreateFrame` sont initialement shown. Cela ne veut pas dire qu’elle est utilement visible : sans taille, contenu et anchor, tu ne verras rien. ([AddOn Studio][23])

---

## 6. Frame Strata et Frame Level

Les stratas disponibles sont :

```text
PARENT
BACKGROUND
LOW
MEDIUM
HIGH
DIALOG
FULLSCREEN
FULLSCREEN_DIALOG
TOOLTIP
```

L’ordre visuel principal, du plus bas au plus haut, est :

```text
BACKGROUND
LOW
MEDIUM
HIGH
DIALOG
FULLSCREEN
FULLSCREEN_DIALOG
TOOLTIP
```

`PARENT` signifie : même strata que le parent. Les docs `FrameStrata` listent ces valeurs et expliquent leur ordre. ([WoWWiki Archive][25])

`SetFrameStrata(strata)` choisit la grande couche :

```lua
frame:SetFrameStrata("DIALOG")
```

`SetFrameLevel(level)` choisit l’ordre relatif **à l’intérieur d’une même strata** :

```lua
frame:SetFrameLevel(10)
```

En résumé : `FrameStrata` décide de la couche globale ; `FrameLevel` décide qui passe devant qui dans cette couche. Les docs `SetFrameLevel` indiquent qu’un niveau plus élevé apparaît au-dessus d’un niveau plus bas dans la même strata. ([Warcraft Wiki][26])

Valeur par défaut : une frame enfant apparaît normalement légèrement au-dessus de son parent ; les docs XML/Frame indiquent par exemple que `UIParent` est niveau 1, une frame enfant de `UIParent` niveau 2, puis un bouton enfant niveau 3. Pour une frame parentée à `UIParent`, tu peux retenir : elle hérite globalement du contexte UI normal et apparaît au-dessus de son parent. Pour une capsule débutant, évite de toucher à `SetFrameLevel` tant que ce n’est pas nécessaire. ([AddOn Studio][27])

---

## 7. Templates XML utiles

## `BackdropTemplate`

`BackdropTemplate` est le template à connaître pour cette capsule. Il ajoute l’infrastructure backdrop à une frame, ce qui permet `SetBackdrop`, `SetBackdropColor` et `SetBackdropBorderColor`. Ce n’est pas seulement Retail : Warcraft Wiki indique qu’il a été backporté dans les flavours Classic. ([Warcraft Wiki][13])

Recommandation pédagogique :

```lua
CreateFrame("Frame", "MyFrame", UIParent, "BackdropTemplate")
```

C’est le meilleur choix pour apprendre explicitement fond + bordure.

## `BasicFrameTemplate` / `BasicFrameTemplateWithInset`

`BasicFrameTemplate` et surtout `BasicFrameTemplateWithInset` sont des templates souvent utilisés pour obtenir une fenêtre Blizzard simple avec bordure, fond et bouton de fermeture. Des tutoriels récents utilisent `BasicFrameTemplateWithInset` pour créer rapidement une fenêtre standard. ([Reddit][28])

Exemple :

```lua
local frame = CreateFrame("Frame", "MyFrame", UIParent, "BasicFrameTemplateWithInset")
```

Mais pour une capsule “My First Frame”, je recommande plutôt `BackdropTemplate` + backdrop manuel, parce que l’élève voit exactement ce qui rend la frame visible.

## `UIPanelDialogTemplate`

`UIPanelDialogTemplate` existe dans beaucoup de branches FrameXML historiques, mais les templates internes Blizzard peuvent changer selon les clients. Les auteurs d’add-ons recommandent de vérifier les templates dans les sources correspondant exactement au client ciblé, via `ExportInterfaceFiles code` ou un miroir de sources UI. ([WoWInterface][29])

Recommandation pour débutant :

1. **Pour apprendre** : `BackdropTemplate` + `SetBackdrop`.
2. **Pour aller vite** : `BasicFrameTemplateWithInset`, si confirmé dans ton client.
3. **À éviter au début** : templates Blizzard complexes (`UIPanelDialogTemplate`, templates de panneaux, templates tooltip avancés), parce qu’ils embarquent des comportements et dépendances non évidents.

---

## 8. Exemple complet — add-on minimal Classic Era

Structure :

```text
MyFirstFrame/
├── MyFirstFrame.toc
└── MyFirstFrame.lua
```

### `MyFirstFrame.toc`

```toc
## Interface: 11508
## Title: My First Frame
## Notes: Capsule 04 - première frame visible et déplaçable
## Author: Karim
## Version: 0.1.0

MyFirstFrame.lua
```

### `MyFirstFrame.lua`

```lua
-- MyFirstFrame.lua
-- Capsule 04 : première frame visible, avec fond, bordure, drag souris et slash command.

-- Backdrop classique de type tooltip : fond sombre + bordure standard.
-- En Classic Era 1.15.x, on crée la frame avec "BackdropTemplate"
-- pour garantir que SetBackdrop / SetBackdropColor existent.
local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {
        left = 5,
        right = 5,
        top = 5,
        bottom = 5,
    },
}

-- Crée une frame nommée, parentée à UIParent.
-- Le nom "MyFirstFrame" crée aussi _G["MyFirstFrame"], utile pour debug /fstack.
local frame = CreateFrame("Frame", "MyFirstFrame", UIParent, "BackdropTemplate")

-- Taille en unités UI.
frame:SetSize(400, 300)

-- Position au centre de l'écran, relativement à UIParent.
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- Strata assez haute pour une petite fenêtre de démonstration.
frame:SetFrameStrata("DIALOG")

-- Empêche de perdre la frame hors écran pendant le déplacement.
frame:SetClampedToScreen(true)

-- Applique le fond + bordure.
frame:SetBackdrop(BACKDROP)

-- Teinte le fond en noir semi-opaque.
frame:SetBackdropColor(0, 0, 0, 0.85)

-- Teinte la bordure en blanc opaque.
frame:SetBackdropBorderColor(1, 1, 1, 1)

-- Permet à la frame de recevoir la souris.
frame:EnableMouse(true)

-- Autorise le déplacement.
frame:SetMovable(true)

-- Déclenche le drag avec le bouton gauche.
frame:RegisterForDrag("LeftButton")

-- Quand le drag commence, WoW déplace la frame avec la souris.
frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
    self.isMoving = true
end)

-- Quand le drag s'arrête, WoW fixe la nouvelle position.
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.isMoving = false
end)

-- Sécurité : si la frame est cachée pendant un drag, on arrête proprement le mouvement.
frame:SetScript("OnHide", function(self)
    if self.isMoving then
        self:StopMovingOrSizing()
        self.isMoving = false
    end
end)

-- Petit titre visible dans la frame.
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -18)
title:SetText("My First Frame")

-- Petit texte d'aide.
local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
hint:SetPoint("CENTER", frame, "CENTER", 0, 0)
hint:SetText("Drag avec le bouton gauche\\n/myframe pour afficher/cacher")

-- Slash command : /myframe alterne Show / Hide.
SLASH_MYFIRSTFRAME1 = "/myframe"

SlashCmdList["MYFIRSTFRAME"] = function()
    if frame:IsShown() then
        frame:Hide()
        print("MyFirstFrame: cachée")
    else
        frame:Show()
        print("MyFirstFrame: affichée")
    end
end

print("MyFirstFrame chargé. Tape /myframe pour afficher/cacher la frame.")
```

Cet exemple utilise `BackdropTemplate` pour le backdrop, `SetSize` + `SetPoint` pour la géométrie, `SetMovable` + `EnableMouse` + `RegisterForDrag` + `StartMoving` / `StopMovingOrSizing` pour le drag, et `SLASH_*` + `SlashCmdList` pour la commande slash. Ces usages correspondent aux docs `CreateFrame`, `BackdropTemplate`, `SetPoint`, draggable frames et slash commands. ([WoWWiki Archive][3])

---

## 9. Pièges courants / gotchas

### 1. Frame créée mais invisible

Une `Frame` nue n’a aucun rendu visuel. Il faut au moins une texture, un font string, ou un backdrop visible. `CreateFrame("Frame")` crée un conteneur logique, pas une fenêtre dessinée automatiquement. Les exemples de backdrop montrent qu’il faut fournir `bgFile` / `edgeFile` ou créer des textures. ([AddOn Studio][16])

### 2. Oublier `BackdropTemplate`

En Classic Era moderne, enseigne directement :

```lua
CreateFrame("Frame", "MyFrame", UIParent, "BackdropTemplate")
```

Sinon `frame:SetBackdrop(...)` peut être `nil` selon le type de frame ou template. Le changement vient de la migration de l’API backdrop vers `BackdropTemplate`, et cette mécanique est backportée dans Classic. ([Warcraft Wiki][12])

### 3. `SetBackdropColor(255, 255, 255, 255)`

Erreur classique : les couleurs sont en 0–1, pas en 0–255. Utilise :

```lua
frame:SetBackdropColor(1, 1, 1, 1)
```

pas :

```lua
frame:SetBackdropColor(255, 255, 255, 255)
```

Les docs de couleur backdrop/border utilisent une plage 0 à 1. ([WoWWiki Archive][17])

### 4. Alpha à zéro

Si tu fais :

```lua
frame:SetBackdropColor(0, 0, 0, 0)
```

le fond est transparent. La frame existe, mais tu ne vois pas le fond. Les exemples de transparence utilisent justement le 4e paramètre alpha. ([MMO-Champion][30])

### 5. Pas de taille

Si tu oublies :

```lua
frame:SetSize(400, 300)
```

et que ta frame n’est pas dimensionnée par plusieurs anchors, elle peut avoir une taille nulle ou non utile. `SetSize` règle explicitement largeur + hauteur. ([Warcraft Wiki][6])

### 6. Pas d’anchor

Si tu oublies :

```lua
frame:SetPoint("CENTER")
```

la frame peut être “shown” sans position utile. `ClearAllPoints()` sans nouveau `SetPoint()` peut aussi faire disparaître la frame. ([WoWWiki Archive][11])

### 7. Mauvais parent

`CreateFrame("Frame", nil, nil)` ne parent pas automatiquement à `UIParent`. Pour une frame d’interface normale, utilise :

```lua
CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
```

Les anciennes docs `CreateFrame` précisent que le parent ne devient pas `UIParent` par défaut si tu passes `nil`. ([WoWWiki Archive][3])

### 8. Oublier `EnableMouse(true)` pour le drag

Une frame normale ne reçoit pas forcément la souris. Pour drag :

```lua
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
```

Les guides de draggable frames listent explicitement ces appels. ([AddOn Studio][19])

### 9. Croire que `RegisterForDrag("LeftButton")` puis `RegisterForDrag("RightButton")` ajoute les deux

Un nouvel appel remplace les boutons précédents. Pour enregistrer plusieurs boutons :

```lua
frame:RegisterForDrag("LeftButton", "RightButton")
```

Les docs `RegisterForDrag` précisent que les appels suivants remplacent les précédents. ([Warcraft Wiki][20])

### 10. Utiliser `"AnyButton"` avec `RegisterForDrag`

Les docs listent `"LeftButton"`, `"RightButton"`, `"MiddleButton"`, `"Button4"`, `"Button5"`. Elles ne listent pas `"AnyButton"` comme argument standard pour `RegisterForDrag`. ([Wowpedia][31])

### 11. Misspell d’anchor

Une faute comme :

```lua
frame:SetPoint("CETNER")
```

au lieu de :

```lua
frame:SetPoint("CENTER")
```

peut provoquer une erreur ou empêcher la frame d’être correctement positionnée. Les threads de support sur `BackdropTemplate` montrent ce genre de faute dans les exemples de frames invisibles ou mal placées. ([WoWInterface][32])

### 12. Plusieurs anchors qui écrasent `SetSize`

Si tu poses deux coins opposés, la frame est dimensionnée par anchors. Ensuite, `SetSize` peut sembler ignoré. C’est normal : les contraintes d’ancrage définissent déjà la taille. ([Wowpedia][8])

### 13. Confondre `IsShown()` et `IsVisible()`

Un enfant peut être `IsShown() == true` mais `IsVisible() == false` si son parent est caché. Pour diagnostiquer une frame invisible, vérifie les deux. ([Warcraft Wiki][24])

### 14. Sauvegarde de position mal comprise

Le drag peut marquer une frame comme user-placed et le client peut restaurer certaines frames nommées via son layout cache, mais ce n’est pas une vraie sauvegarde add-on. Pour un comportement fiable, utilise tes propres SavedVariables. ([WoWWiki Archive][21])

### 15. Frame perdue hors écran

Ajoute :

```lua
frame:SetClampedToScreen(true)
```

Cela évite qu’un utilisateur déplace la frame hors de l’écran. ([WoWWiki Archive][22])

### 16. Trop jouer avec `FrameStrata` / `FrameLevel`

Pour une première capsule, `SetFrameStrata("DIALOG")` suffit. Évite de multiplier les `SetFrameLevel(999)` : les niveaux ne règlent que l’ordre à l’intérieur d’une strata, et une hiérarchie parent/enfant propre est souvent meilleure. ([WoWWiki Archive][33])

### 17. Croire qu’on peut détruire une frame

Les frames créées par `CreateFrame` ne sont pas vraiment supprimées comme des objets C++/JS ordinaires. On les cache, on les réutilise, ou on évite d’en créer en boucle. Les anciennes docs `CreateFrame` rappellent que les frames ne peuvent pas être supprimées explicitement une fois créées. ([WoWWiki Archive][3])

---

## Conclusion pédagogique recommandée

Pour la capsule 04, je recommande d’enseigner cette règle simple :

```lua
local frame = CreateFrame("Frame", "MyFirstFrame", UIParent, "BackdropTemplate")
frame:SetSize(400, 300)
frame:SetPoint("CENTER")
frame:SetBackdrop({...})
frame:SetBackdropColor(0, 0, 0, 0.85)
frame:SetBackdropBorderColor(1, 1, 1, 1)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
```

C’est le chemin le plus clair pour un débutant : une frame parentée à `UIParent`, dimensionnée, ancrée, rendue visible par un backdrop, puis rendue déplaçable.

[1]: https://www.curseforge.com/wow/addons/recount-revived/files/8103955?utm_source=chatgpt.com "Revived - Recount-v1.18.2 - World of Warcraft Addons"
[2]: https://us.forums.blizzard.com/en/wow/t/will-classic-era-update-to-the-dragonflight-interface-client-with-the-patch-on-822/1650328?utm_source=chatgpt.com "Will Classic Era update to the Dragonflight Interface client ..."
[3]: https://wowwiki-archive.fandom.com/wiki/API_CreateFrame?utm_source=chatgpt.com "API CreateFrame | WoWWiki"
[4]: https://warcraft.wiki.gg/wiki/API_CreateFrame?utm_source=chatgpt.com "CreateFrame - Warcraft Wiki"
[5]: https://warcraft.wiki.gg/wiki/Widget_API?utm_source=chatgpt.com "Widget API - Warcraft Wiki"
[6]: https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_SetSize?utm_source=chatgpt.com "ScriptRegionResizing:SetSize - Warcraft Wiki"
[7]: https://wowwiki-archive.fandom.com/wiki/API_Region_SetPoint?utm_source=chatgpt.com "API Region SetPoint | WoWWiki"
[8]: https://wowpedia.fandom.com/wiki/API_ScriptRegionResizing_SetSize?utm_source=chatgpt.com "ScriptRegionResizing:SetSize - Wowpedia - Fandom"
[9]: https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_SetPoint?utm_source=chatgpt.com "ScriptRegionResizing:SetPoint - Warcraft Wiki"
[10]: https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_ClearAllPoints?utm_source=chatgpt.com "ScriptRegionResizing:ClearAllPoints - Warcraft Wiki"
[11]: https://wowwiki-archive.fandom.com/wiki/API_Region_ClearAllPoints?utm_source=chatgpt.com "API Region ClearAllPoints | WoWWiki"
[12]: https://warcraft.wiki.gg/wiki/API_Frame_SetBackdrop?utm_source=chatgpt.com "Frame:SetBackdrop - Warcraft Wiki"
[13]: https://warcraft.wiki.gg/wiki/BackdropTemplate?utm_source=chatgpt.com "BackdropTemplate - Warcraft Wiki"
[14]: https://us.forums.blizzard.com/en/wow/t/backdroptemplate-issues/1125674?utm_source=chatgpt.com "BackdropTemplate issues - UI and Macro"
[15]: https://addonstudio.org/wiki/WoW%3AAPI_Frame_SetBackdrop?utm_source=chatgpt.com "Widget API: Frame:SetBackdrop"
[16]: https://addonstudio.org/wiki/WoW%3AXML/Backdrop?utm_source=chatgpt.com "WoW:XML/Backdrop"
[17]: https://wowwiki-archive.fandom.com/wiki/API_Frame_SetBackdropBorderColor?utm_source=chatgpt.com "API Frame SetBackdropBorderColor"
[18]: https://wowpedia.fandom.com/wiki/XML/Backdrop?utm_source=chatgpt.com "XML/Backdrop - Your wiki guide to the World of Warcraft"
[19]: https://addonstudio.org/wiki/WoW%3AMaking_Draggable_Frames?utm_source=chatgpt.com "WoW:Making Draggable Frames"
[20]: https://warcraft.wiki.gg/wiki/API_Frame_RegisterForDrag?utm_source=chatgpt.com "Frame:RegisterForDrag - Warcraft Wiki"
[21]: https://wowwiki-archive.fandom.com/wiki/API_Frame_StartMoving?utm_source=chatgpt.com "API Frame StartMoving | WoWWiki"
[22]: https://wowwiki-archive.fandom.com/wiki/API_Frame_SetClampedToScreen?utm_source=chatgpt.com "API Frame SetClampedToScreen"
[23]: https://addonstudio.org/wiki/WoW%3AAPI_Region_IsShown?utm_source=chatgpt.com "Widget API: Region:IsShown"
[24]: https://warcraft.wiki.gg/wiki/API_ScriptRegion_IsShown?utm_source=chatgpt.com "ScriptRegion:IsShown - Warcraft Wiki"
[25]: https://wowwiki-archive.fandom.com/wiki/UITYPE_FrameStrata?utm_source=chatgpt.com "UITYPE FrameStrata | WoWWiki"
[26]: https://warcraft.wiki.gg/wiki/API_Frame_SetFrameStrata?utm_source=chatgpt.com "Frame:SetFrameStrata - Warcraft Wiki"
[27]: https://addonstudio.org/wiki/WoW%3AXML/Frame?utm_source=chatgpt.com "WoW:XML/Frame"
[28]: https://www.reddit.com/r/wowaddondev/comments/1cc2qgj/creating_a_wow_addon_part_2_creating_a_frame/?utm_source=chatgpt.com "Creating a WoW Addon - Part 2: Creating a Frame"
[29]: https://www.wowinterface.com/forums/showthread.php?t=59835&utm_source=chatgpt.com "Where do I find information on Templates?"
[30]: https://www.mmo-champion.com/threads/1351096-BasicFrame-template-transparent-background-using-SetBackdrop?utm_source=chatgpt.com "transparent background using SetBackdrop"
[31]: https://wowpedia.fandom.com/wiki/API_Frame_RegisterForDrag?utm_source=chatgpt.com "Frame:RegisterForDrag - Wowpedia - Fandom"
[32]: https://www.wowinterface.com/forums/showthread.php?t=59730&utm_source=chatgpt.com "BackdropTemplate issue"
[33]: https://wowwiki-archive.fandom.com/wiki/API_Frame_SetFrameLevel?utm_source=chatgpt.com "API Frame SetFrameLevel"
