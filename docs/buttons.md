# Boutons et Texte — Classic Era 1.15.x

> Source : code source Blizzard exporté via `ExportInterfaceFiles code` (client Classic Era 1.15.x).
> Fichiers de référence : `Blizzard_SharedXML/SecureUIPanelTemplates.xml`, `Blizzard_SharedXML/SecureUIPanelTemplates.lua`, `Blizzard_SharedXML/Classic/SharedUIPanelTemplates.xml`, `Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua`.

---

## Créer un bouton — `CreateFrame("Button", ...)`

```lua
local btn = CreateFrame("Button", "MyBtn", parent, "UIPanelButtonTemplate")
btn:SetSize(120, 22)
btn:SetText("Cliquez ici")
btn:SetPoint("CENTER")
```

### Types de frames cliquables

| Type | Rôle |
|------|------|
| `"Button"` | Cliquable, a des états (normal, survolé, pressé, désactivé) |
| `"CheckButton"` | Bouton à cocher (checked/unchecked) — voir `UICheckButtonTemplate` |

⚠️ `Button` est un type de frame à part entière, pas un widget séparé. Il hérite de toutes les méthodes de Frame (SetPoint, SetSize, SetScript, etc.).

---

## Templates de boutons

### Hiérarchie des templates

```
UIPanelButtonNoTooltipTemplate          (base : 40×22, 3 textures Left/Middle/Right, fonts, highlight)
  └─ UIPanelButtonTemplate              (+ tooltip OnEnter/OnLeave)
       ├─ UIPanelButtonGrayTemplate     (look grisé permanent)
       ├─ MagicButtonTemplate           (80×22, auto-positionné dans ButtonFrameTemplate)
       ├─ UIPanelDynamicResizeButtonTemplate  (s'élargit automatiquement au texte)
       └─ UIPanelButtonUserScaledTemplate     (avec police mise à l'échelle)

UIPanelCloseButtonNoScripts             (32×32, bouton X sans handler)
  └─ UIPanelCloseButton                 (+ handler OnClick qui cache le parent)
       └─ UIPanelCloseButtonDefaultAnchors  (+ ancrage TOPRIGHT automatique)

UIPanelGoldButtonTemplate               (bouton doré pour dialogues)
UIMenuButtonStretchTemplate             (bouton silver extensible)
UIRadioButtonTemplate                   (16×16, radio button)
UICheckButtonTemplate                   (32×32, checkbox avec texte)
```

### `UIPanelButtonTemplate` — anatomie

Défini dans `Blizzard_SharedXML/Classic/SharedUIPanelTemplates.xml` et `Blizzard_SharedXML/SecureUIPanelTemplates.xml`.

**Hérite de** : `UIPanelButtonNoTooltipTemplate`

**Mixin** : `UIButtonFitToTextBehaviorMixin` (méthodes `SetTextToFit(text)`, `FitToText()`)

**Taille par défaut** : 40×22

**Textures d'état** (3 morceaux : Left, Middle, Right) :
| État | Texture |
|------|---------|
| Normal | `Interface\Buttons\UI-Panel-Button-Up` |
| Pressé | `Interface\Buttons\UI-Panel-Button-Down` |
| Désactivé | `Interface\Buttons\UI-Panel-Button-Disabled` |
| Désactivé+pressé | `Interface\Buttons\UI-Panel-Button-Disabled-Down` |

Ces textures sont changées par les handlers Lua `UIPanelButton_OnLoad`, `UIPanelButton_OnMouseDown`, `UIPanelButton_OnMouseUp`, etc.

**Highlight** : `UIPanelButtonHighlightTexture` (`Interface\Buttons\UI-Panel-Button-Highlight`, mode ADD)

**Fonts** :
| État | Font |
|------|------|
| Normal | `GameFontNormal` |
| Highlight (survol) | `GameFontHighlight` |
| Disabled | `GameFontDisable` |

**Tooltip** : géré par `self.tooltipText` et `self.newbieText` via `OnEnter`/`OnLeave`.

### `UIPanelCloseButton` — bouton fermer

```lua
local closeBtn = CreateFrame("Button", nil, myFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", myFrame, "TOPRIGHT", 4, 4)
```

- 32×32, icône X standard
- Le handler `UIPanelCloseButton_OnClick(self)` appelle `self:GetParent():Hide()` par défaut
- Si le parent a un `onCloseCallback`, il est appelé en premier

---

## API complète des boutons

Source : `SimpleButtonAPIDocumentation.lua`

### Texte

| Méthode | Description |
|---------|-------------|
| `SetText(text)` | Définit le texte du bouton |
| `GetText()` | Retourne le texte du bouton |
| `SetFormattedText(fmt, ...)` | Comme `string.format` — définit le texte formaté |
| `GetFontString()` | Retourne la FontString interne du bouton |
| `SetFontString(fontString)` | Associe une FontString existante au bouton |
| `GetTextWidth()` | Largeur du texte |
| `GetTextHeight()` | Hauteur du texte |

### Textures d'état

| Méthode | Description |
|---------|-------------|
| `SetNormalTexture(asset)` | Texture état normal |
| `GetNormalTexture()` | Retourne la texture |
| `ClearNormalTexture()` | Supprime la texture |
| `SetPushedTexture(asset)` | Texture état pressé |
| `GetPushedTexture()` | Retourne la texture |
| `ClearPushedTexture()` | Supprime la texture |
| `SetHighlightTexture(asset [, blendMode])` | Texture état survolé |
| `GetHighlightTexture()` | Retourne la texture |
| `ClearHighlightTexture()` | Supprime la texture |
| `SetDisabledTexture(asset)` | Texture état désactivé |
| `GetDisabledTexture()` | Retourne la texture |
| `ClearDisabledTexture()` | Supprime la texture |

**`asset`** peut être :
- Un chemin de fichier : `"Interface\\Buttons\\UI-Panel-Button-Up"`
- Un atlas : utilisé avec `SetNormalAtlas(atlas)`, `SetPushedAtlas(atlas)`, etc.

**`blendMode`** : `"ADD"`, `"BLEND"`, `"MOD"`, `"DISABLE"`, `"ALPHAKEY"` (optionnel, défaut dépend du contexte)

### Atlas (textures modernes)

| Méthode | Description |
|---------|-------------|
| `SetNormalAtlas(atlas)` | Atlas état normal |
| `SetPushedAtlas(atlas)` | Atlas état pressé |
| `SetHighlightAtlas(atlas [, blendMode])` | Atlas état survolé |
| `SetDisabledAtlas(atlas)` | Atlas état désactivé |

### Font objects (police par état)

| Méthode | Description |
|---------|-------------|
| `SetNormalFontObject(font)` | Police état normal |
| `GetNormalFontObject()` | Retourne la font |
| `SetHighlightFontObject(font)` | Police état survolé |
| `GetHighlightFontObject()` | Retourne la font |
| `SetDisabledFontObject(font)` | Police état désactivé |
| `GetDisabledFontObject()` | Retourne la font |

**`font`** est un font object comme `GameFontNormal`, `GameFontHighlight`, `GameFontRed`, etc.

### État et activation

| Méthode | Description |
|---------|-------------|
| `Enable()` | Active le bouton |
| `Disable()` | Désactive le bouton (grisé) |
| `SetEnabled(bool)` | Active ou désactive |
| `IsEnabled()` | Retourne `true`/`false` |
| `SetButtonState(state [, lock])` | Force un état (`"NORMAL"`, `"PUSHED"`) |
| `GetButtonState()` | Retourne l'état actuel |

### Décalage du texte pressé

| Méthode | Description |
|---------|-------------|
| `SetPushedTextOffset(offsetX, offsetY)` | Décale le texte quand le bouton est pressé |
| `GetPushedTextOffset()` | Retourne `offsetX, offsetY` |

Par défaut, le texte se décale légèrement vers le bas à droite quand on presse.

### Divers

| Méthode | Description |
|---------|-------------|
| `Click([button, isDown])` | Simule un clic par programme |
| `SetMotionScriptsWhileDisabled(bool)` | Autorise OnEnter/OnLeave même si désactivé |
| `GetMotionScriptsWhileDisabled()` | Retourne le booléen |

---

## RegisterForClicks — Contrôle des clics

```lua
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
```

### Options disponibles

| Option | Se déclenche quand... |
|--------|----------------------|
| `"LeftButtonUp"` | Relâchement du bouton gauche |
| `"LeftButtonDown"` | Enfoncement du bouton gauche |
| `"RightButtonUp"` | Relâchement du bouton droit |
| `"RightButtonDown"` | Enfoncement du bouton droit |
| `"MiddleButtonUp"` | Relâchement du bouton central |
| `"MiddleButtonDown"` | Enfoncement du bouton central |
| `"Button4Up"` / `"Button4Down"` | Bouton supplémentaire 4 |
| `"Button5Up"` / `"Button5Down"` | Bouton supplémentaire 5 |
| `"AnyUp"` | N'importe quel bouton, au relâchement |
| `"AnyDown"` | N'importe quel bouton, à l'enfoncement |

⚠️ Un nouvel appel à `RegisterForClicks` **remplace** les précédents.
⚠️ Par défaut (sans `RegisterForClicks`), le comportement dépend du type de bouton.

---

## OnClick — Handler de clic

```lua
btn:SetScript("OnClick", function(self, button, down)
    -- self    = le bouton cliqué
    -- button  = "LeftButton", "RightButton", "MiddleButton", "Button4", "Button5"
    -- down    = true si le bouton vient d'être enfoncé, false si relâché
    --         (uniquement pertinent si RegisterForClicks inclut des options "Down")
    print("Clic sur", self:GetName(), "avec", button)
end)
```

### Signature

`function(self, button, down)`

- `self` — le bouton
- `button` — nom du bouton de souris (`"LeftButton"`, `"RightButton"`, etc.)
- `down` — booléen (true = enfoncement, false = relâchement)

⚠️ Si le handler est défini en XML via `<OnClick function="..."/>`, la signature peut être juste `function(self)` si la fonction n'utilise pas les autres args.

---

## Exemples pratiques

### Bouton standard avec UIPanelButtonTemplate

```lua
local btn = CreateFrame("Button", "MyBtn", UIParent, "UIPanelButtonTemplate")
btn:SetSize(120, 22)
btn:SetText("Cliquez-moi")
btn:SetPoint("CENTER")
btn:SetScript("OnClick", function(self, button)
    print("Clic avec " .. button)
end)
```

### Bouton fermer

```lua
local closeBtn = CreateFrame("Button", nil, myFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", myFrame, "TOPRIGHT", 4, 4)
-- Le handler par défaut cache le parent
```

### Bouton personnalisé (sans template)

```lua
local btn = CreateFrame("Button", nil, UIParent)
btn:SetSize(64, 64)
btn:SetPoint("CENTER")

-- Texture normale
btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
-- Texture quand pressé
btn:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
-- Texture au survol (mode ADD pour éclaircir)
btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")

btn:SetScript("OnClick", function(self, button)
    print("Clic !")
end)
```

### Bouton avec compteur de clics

```lua
local count = 0
local btn = CreateFrame("Button", "CounterBtn", UIParent, "UIPanelButtonTemplate")
btn:SetSize(140, 22)
btn:SetPoint("CENTER")
btn:SetText("Clics : 0")

btn:SetScript("OnClick", function(self, button)
    count = count + 1
    self:SetText("Clics : " .. count)
end)
```

---

## Pièges courants (gotchas)

1. **Bouton invisible** — Comme toute frame, un bouton sans taille ET/OU sans point d'ancrage est invisible même si `IsShown()` = true.
2. **OnClick ne se déclenche pas** — Vérifier `RegisterForClicks`. Par défaut les templates standard l'appellent, mais un bouton nu ne l'a pas.
3. **SetText pas visible** — Le texte peut être trop grand pour le bouton. Les templates standard utilisent `ButtonText` avec un ancrage interne. Si vous créez un bouton nu, vous devez gérer vous-même la FontString.
4. **Highlight invisible** — `SetHighlightTexture` avec un mauvais blend mode peut rendre la texture invisible. `"ADD"` est généralement le bon choix.
5. **Disable ne change pas le look** — Si le bouton n'a pas de `DisabledTexture` ni de `DisabledFontObject`, le désactiver ne change rien visuellement.
6. **Font objects vs font strings** — `SetFontObject` change la police selon l'état (normal/highlight/disabled). C'est différent de `SetFontString` qui associe une FontString existante.
7. **Protected functions** — `Click()`, `Enable()`, `Disable()`, `SetEnabled()`, `RegisterForClicks()` sont des fonctions protégées — elles ne peuvent pas être appelées en combat si le bouton est sécurisé.
