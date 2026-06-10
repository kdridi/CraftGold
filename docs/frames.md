# Frames et Interface Graphique — Classic Era 1.15.x

> Source : code source Blizzard exporté via `ExportInterfaceFiles code` (client Classic Era 1.15.x, interface 11508).
> Fichiers de référence : `BlizzardInterfaceCode/Interface/AddOns/Blizzard_SharedXML/Backdrop.lua`, `Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua`, `Blizzard_UIPanelTemplates/Classic/UIPanelTemplates.xml`.

---

## Créer une Frame — `CreateFrame()`

```lua
local frame = CreateFrame(frameType, name, parent, template)
```

### Types de frames courants

| Type | Rôle |
|------|------|
| `"Frame"` | Conteneur de base, invisible par défaut |
| `"Button"` | Cliquable, a des états (normal, survolé, pressé) |
| `"CheckButton"` | Bouton à cocher (checked/unchecked) |
| `"EditBox"` | Zone de saisie de texte |
| `"Slider"` | Barre de défilement ou slider de valeur |
| `"ScrollFrame"` | Zone avec défilement |
| `"StatusBar"` | Barre de progression |
| `"GameTooltip"` | Infobulle |
| `"MessageFrame"` | Zone de messages |
| `"Cooldown"` | Affichage de cooldown (horloge) |
| `"Model"` / `"PlayerModel"` | Modèle 3D |

⚠️ `FontString` et `Texture` ne se créent **pas** via `CreateFrame` — utiliser `frame:CreateFontString()` et `frame:CreateTexture()`.

### Paramètres

- `name` (string ou nil) — Si fourni, crée une variable globale `_G[name]`. Utile pour debug (`/fstack`). `nil` = anonyme (recommandé si pas besoin de debug).
- `parent` (frame ou nil) — Frame parente. Les enfants héritent de la visibilité et de l'échelle. `nil` = pas de parent. ⚠️ **UIParent n'est pas ajouté automatiquement si parent = nil**.
- `template` (string) — Templates hérités, séparés par des virgules. Ex : `"BackdropTemplate, BasicFrameTemplate"`.

---

## Taille et Position

### Taille

```lua
frame:SetSize(width, height)   -- racourci pour SetWidth + SetHeight
frame:SetWidth(width)
frame:SetHeight(height)
```

- Unité : **unités UI** (pas des pixels physiques — affectées par le UI Scale)
- ⚠️ Si la taille est déduite de 2 ancres opposées, `SetSize` est **ignoré**

### Position — système d'ancres

```lua
frame:SetPoint(point, relativeFrame, relativePoint, offsetX, offsetY)
frame:SetPoint(point, offsetX, offsetY)    -- raccourci, relativeFrame = parent
frame:SetPoint("CENTER")                   -- centre sur le parent
```

**9 points d'ancrage** :

```
TOPLEFT    TOP    TOPRIGHT
LEFT       CENTER RIGHT
BOTTOMLEFT BOTTOM BOTTOMRIGHT
```

- Si `relativeFrame` est omis → ancrage sur le parent (ou l'écran si pas de parent)
- Si `relativePoint` est omis → même valeur que `point`
- **Multi-ancrage possible** : appeler `SetPoint` plusieurs fois (ex: ancrer 2 coins)
- ⚠️ Un 2e `SetPoint` **ajoute** une ancre, ne remplace pas → `ClearAllPoints()` avant de repositionner
- **Sans parent ni point** : la frame n'a pas de géométrie valide → **invisible**, même si `IsShown()` = true

### `ClearAllPoints()`

Supprime toutes les ancres. À appeler avant un nouveau `SetPoint` si on change de point d'ancrage.

---

## Backdrop — Fond et bordure

### ⚠️ Point critique : `BackdropTemplate` est OBLIGATOIRE

Depuis le patch 9.0 (rétroporté à Classic Era 1.14.0), `SetBackdrop()` n'existe **plus** directement sur les frames. Il faut hériter du template :

```lua
-- ✅ CORRECT
local frame = CreateFrame("Frame", "MyFrame", UIParent, "BackdropTemplate")

-- ❌ ERREUR : attempt to call method 'SetBackdrop' (a nil value)
local frame = CreateFrame("Frame", "MyFrame", UIParent)
```

**Source vérifiée** : `Blizzard_SharedXML/Backdrop.xml` définit :
```xml
<Frame name="BackdropTemplate" mixin="BackdropTemplateMixin" virtual="true">
    <Scripts>
        <OnLoad method="OnBackdropLoaded"/>
        <OnSizeChanged method="OnBackdropSizeChanged"/>
    </Scripts>
</Frame>
```

### Backdrops prédéfinis (globales dans Backdrop.lua)

| Constante | Style |
|-----------|-------|
| `BACKDROP_DIALOG_32_32` | Boîte de dialogue standard (fond clair + bordure grise) |
| `BACKDROP_DARK_DIALOG_32_32` | Boîte de dialogue sombre |
| `BACKDROP_GOLD_DIALOG_32_32` | Boîte de dialogue avec bordure dorée |
| `BACKDROP_DIALOG_EDGE_32` | Bordure seule (pas de fond) |
| `BACKDROP_TUTORIAL_16_16` | Style tooltip (fond sombre + bordure tooltip) |
| `BACKDROP_TOAST_12_12` | Style notification toast |
| `BACKDROP_SLIDER_8_8` | Fond de slider |
| `BACKDROP_PARTY_32_32` | Cadre de groupe |
| `BACKDROP_ARENA_32_32` | Cadre d'arène |
| `BACKDROP_ACHIEVEMENTS_0_64` | Bordure de hauts faits |
| `BACKDROP_CALLOUT_GLOW_0_16` | Bordure de callout lumineux |
| `BACKDROP_CALLOUT_GLOW_0_20` | Idem, taille 20 |
| `BACKDROP_TEXT_PANEL_0_16` | Panneau de texte |
| `BACKDROP_CHARACTER_CREATE_TOOLTIP_32_32` | Tooltip de création de personnage |
| `BACKDROP_WATERMARK_DIALOG_0_16` | Dialogue avec watermark |
| `BACKDROP_WRATH_CHARACTER_CREATE_TOOLTIP_32_32` | Tooltip WotLK |
| `BACKDROP_MISTS_CHARACTER_CREATE_TOOLTIP_32_32` | Tooltip Mists |

### Exemple d'utilisation d'un backdrop prédéfini

```lua
frame:SetBackdrop(BACKDROP_DIALOG_32_32)
frame:SetBackdropColor(1, 1, 1, 1)        -- teinte le fond (valeurs 0-1)
frame:SetBackdropBorderColor(1, 1, 1, 1)  -- teinte la bordure
```

### Backdrop personnalisé

```lua
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
```

Champs :
- `bgFile` — texture du fond (`nil` = pas de fond)
- `edgeFile` — texture de la bordure (`nil` = pas de bordure)
- `tile` — répéter le fond (défaut : false)
- `tileEdge` — répéter la bordure (défaut : true)
- `tileSize` — taille de tuile (défaut : 0)
- `edgeSize` — taille de la bordure (défaut : 39)
- `insets` — marges intérieures `{ left, right, top, bottom }` (défaut : tous à 0)

### Textures courantes

| Chemin | Usage |
|--------|-------|
| `"Interface\\DialogFrame\\UI-DialogBox-Background"` | Fond boîte de dialogue (clair) |
| `"Interface\\DialogFrame\\UI-DialogBox-Background-Dark"` | Fond boîte de dialogue (sombre) |
| `"Interface\\DialogFrame\\UI-DialogBox-Border"` | Bordure standard |
| `"Interface\\DialogFrame\\UI-DialogBox-Gold-Border"` | Bordure dorée |
| `"Interface\\Tooltips\\UI-Tooltip-Background"` | Fond tooltip (noir) |
| `"Interface\\Tooltips\\UI-Tooltip-Border"` | Bordure tooltip |
| `"Interface\\ChatFrame\\ChatFrameBackground"` | Texture blanche uni (idéal pour colorier) |
| `"Interface\\Buttons\\WHITE8x8"` | Petite texture blanche (8×8) |
| `"Interface\\TutorialFrame\\TutorialFrameBackground"` | Fond tutorial |
| `"Interface\\FrameGeneral\\UI-Background-Rock"` | Fond rocheux (utilisé dans BasicFrameTemplate) |

### SetBackdropColor / SetBackdropBorderColor

```lua
frame:SetBackdropColor(r, g, b, a)        -- r,g,b,a = 0.0 à 1.0
frame:SetBackdropBorderColor(r, g, b, a)  -- idem
```

- ⚠️ **Plage 0–1**, pas 0–255 !
- ⚠️ **Toujours appeler `SetBackdrop()` AVANT** `SetBackdropColor()` — sinon erreur silencieuse ou crash (régression 1.15.x)
- Le alpha est optionnel (défaut : 1)
- `SetBackdropColor` teinte le `bgFile`, `SetBackdropBorderColor` teinte le `edgeFile`
- Utiliser une texture blanche (`ChatFrameBackground`) pour que la couleur s'affiche correctement

---

## Drag — Rendre une frame déplaçable

### Séquence complète (vérifiée dans `SharedUIPanelTemplates.lua`)

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

Les 3 appels sont **obligatoires** : `SetMovable` + `EnableMouse` + `RegisterForDrag`. Il n'y a **aucun message d'erreur** si l'un manque — la frame ne bouge juste pas.

### Version raccourcie (méthode comme handler)

```lua
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
```

### Boutons acceptés par `RegisterForDrag`

`"LeftButton"`, `"RightButton"`, `"MiddleButton"`, `"Button4"`, `"Button5"`.
⚠️ Pas de `"AnyButton"`. Un nouvel appel **remplace** les précédents. Pour plusieurs : `frame:RegisterForDrag("LeftButton", "RightButton")`.

### Sécurité OnHide

Si la frame est masquée pendant un drag, elle reste dans un état bizarre. Bonne pratique :

```lua
frame:SetScript("OnHide", function(self)
    if self.isMoving then
        self:StopMovingOrSizing()
        self.isMoving = false
    end
end)
```

### Clamp à l'écran

```lua
frame:SetClampedToScreen(true)  -- empêche la frame de sortir de l'écran
```

### Persistance de position

`StartMoving` active le flag "user placed" sur les frames nommées → le client sauvegarde/restaure la position automatiquement au reload. Pour éviter ce comportement :

```lua
frame:SetUserPlaced(false)
```

Ou gérer manuellement via SavedVariables avec `frame:GetPoint()`.

---

## Show / Hide

```lua
frame:Show()
frame:Hide()
frame:SetShown(bool)  -- raccourci conditionnel
```

- Les frames sont **shown par défaut** après `CreateFrame`
- `IsShown()` → la frame *veut* être visible (ne dépend pas des parents)
- `IsVisible()` → la frame est *réellement* visible à l'écran (prend en compte tous les parents)
- Une frame shown mais sans taille/ancrage/contenu est "logiquement visible" mais invisible à l'écran

---

## Frame Strata et Level

### Stratas (de l'arrière vers l'avant)

```
BACKGROUND → LOW → MEDIUM → HIGH → DIALOG → FULLSCREEN → FULLSCREEN_DIALOG → TOOLTIP
```

- **MEDIUM** = strata par défaut de `UIParent` (et donc de ses enfants)
- **DIALOG** = recommandé pour les fenêtres de dialogue
- La strata gagne **toujours** sur le level (un level 10000 en BACKGROUND reste derrière un level 0 en DIALOG)

### Level

```lua
frame:SetFrameLevel(number)  -- ordre dans la même strata (0-10000)
```

- Par défaut : légèrement au-dessus du parent
- `frame:Raise()` / `frame:Lower()` pour réordonner

---

## Templates XML utiles

| Template | Fichier source | Description |
|----------|---------------|-------------|
| `"BackdropTemplate"` | `Blizzard_SharedXML/Backdrop.xml` | Ajoute `SetBackdrop`, `SetBackdropColor`, `SetBackdropBorderColor`. **Obligatoire** pour les backdrops en 1.15.x. |
| `"BaseBasicFrameTemplate"` | `Blizzard_UIPanelTemplates/Classic/UIPanelTemplates.xml` | Fenêtre basique : coins, bordures, titre (`TitleText`), bouton fermer (`CloseButton`). |
| `"BasicFrameTemplate"` | idem | Hérite de `BaseBasicFrameTemplate` + fond rocheux + barre de titre. |
| `"BasicFrameTemplateWithInset"` | idem | Hérite de `BasicFrameTemplate` + zone intérieure marble. |
| `"UIPanelDialogTemplate"` | `Blizzard_SharedXML/SharedBasicControls.xml` | Dialogue style Blizzard avec bordure dorée et bouton fermer. |
| `"UIPanelCloseButton"` | `Blizzard_SharedXML/Classic/SharedUIPanelTemplates.xml` | Bouton de fermeture (X). |

### Recommandation pédagogique

- **Capsule 04** : utiliser `"BackdropTemplate"` seul → l'élève voit chaque pièce
- **Plus tard** : `"BasicFrameTemplate"` ou `"BasicFrameTemplateWithInset"` pour une fenêtre complète avec titre et bouton fermer

---

## FontStrings — Texte dans une frame

```lua
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("Mon titre")
```

### Polices (fonts) disponibles

| Font | Style |
|------|-------|
| `"GameFontNormal"` | Texte normal (hérite de `SystemFont_Shadow_Med1`) |
| `"GameFontNormalLarge"` | Texte grand (hérite de `SystemFont_Shadow_Large`) |
| `"GameFontHighlight"` | Texte highlight (hérite de `GameFontNormal`) |
| `"GameFontGreen"` | Texte vert |
| `"GameFontRed"` | Texte rouge |
| `"GameFontDisable"` | Texte désactivé (gris) |
| `"GameFontWhite"` | Texte blanc |

**Source** : `Blizzard_Fonts_Shared/Shared/FontStyles.xml` et `Blizzard_Fonts_Shared/Classic/FontStyles.xml`.

---

## Pièges courants (gotchas)

1. **`SetBackdrop` = nil** → Oublier `"BackdropTemplate"` dans `CreateFrame`. Erreur n°1.
2. **`SetBackdropColor` avant `SetBackdrop`** → Erreur silencieuse ou crash. Toujours `SetBackdrop` d'abord.
3. **Drag qui ne marche pas** → Oublier un des 3 : `SetMovable(true)`, `EnableMouse(true)`, `RegisterForDrag(...)`. Aucune erreur, juste rien ne se passe.
4. **Frame invisible** → Pas de taille ET/OU pas de point d'ancrage. `IsShown()` peut être `true` mais rien ne s'affiche.
5. **`SetSize` ignoré** → Si 2 ancres opposées définissent déjà la taille.
6. **Frame qui s'étire** → Ajouter un 2e `SetPoint` sans `ClearAllPoints()` avant.
7. **Couleurs 0-255 au lieu de 0-1** → Tout > 1 est clampé à 1 = blanc opaque.
8. **Frame derrière tout le reste** → Strata trop basse. Utiliser `"DIALOG"`.
9. **Frames non garbage-collectables** → Les frames créées par `CreateFrame` ne sont jamais détruites. Les réutiliser ou les cacher.
10. **`parent = nil` ne donne pas UIParent** → Toujours passer `UIParent` explicitement si on veut que la frame fasse partie de l'UI.
