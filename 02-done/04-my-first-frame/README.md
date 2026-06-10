# 04 — My First Frame

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 2 — Interface graphique                               |
| Duration      | ~30 min                                                     |
| Difficulty    | ●●●○○ (3/5)                                                |
| Prerequisites | Capsule 03 — Saved Variables                                |
| Type          | Autonomous                                                  |
| Concepts      | `CreateFrame()`, Backdrop, ancres, FontString, drag         |

---

## Why This Capsule?

Jusqu'ici, nos 3 capsules n'ont produit que du **texte dans le chat** — `print()`, des slash commands, des SavedVariables. L'add-on existe, il tourne, mais il est **invisible**. Le joueur qui installe CraftGold ne verra jamais une fenêtre, un bouton, une liste de crafts.

Le problème, c'est qu'en WoW, **tout** élément visuel est une Frame. Un bouton est une Frame. Un texte est attaché à une Frame. Une liste scrollable est composée de Frames. On ne peut rien construire de visible sans maîtriser ce concept fondamental.

Dans cette capsule, on a ouvert les yeux de notre add-on. On a créé une **fenêtre visible à l'écran** — un rectangle avec un fond, une bordure, un titre — qu'on peut déplacer à la souris et afficher/masquer via une commande.

**Pourquoi maintenant ?** On avait les bases (structure .toc, slash commands, événements). Les frames sont le prérequis de TOUTE la Phase 2 : boutons (05), listes scrollables (06), bouton minimap (07), panneau d'options (08).

**Où ça mène ?** Chaque capsule suivante ajoute des briques sur cette fondation — tout est une Frame.

---

## Ce qu'on a appris

### 1. `CreateFrame()` — Créer un widget UI

```lua
local frame = CreateFrame("Frame", "MyFrame", UIParent, "BackdropTemplate")
```

| Paramètre  | Rôle |
|-----------|------|
| `"Frame"` | Type de widget (Frame, Button, Slider, EditBox, etc.) |
| `"MyFrame"` | Nom global (accessible via `_G["MyFrame"]`). `nil` = anonyme. |
| `UIParent` | Frame parente. Hérite visibilité et échelle. |
| `"BackdropTemplate"` | Template hérité — **obligatoire** pour `SetBackdrop()` en 1.15.x |

### 2. Taille et position — le système d'ancres

```lua
frame:SetSize(400, 300)        -- largeur × hauteur en unités UI
frame:SetPoint("CENTER")        -- centre sur le parent (UIParent = écran)
```

9 points d'ancrage disponibles : TOPLEFT, TOP, TOPRIGHT, LEFT, CENTER, RIGHT, BOTTOMLEFT, BOTTOM, BOTTOMRIGHT.

⚠️ **Sans `SetPoint` ni `SetSize`, la frame est logiquement "shown" mais invisible à l'écran.**

### 3. Backdrop — Fond et bordure

`BackdropTemplate` est **obligatoire** depuis le patch 9.0 (rétroporté à Classic Era). Sans lui, `SetBackdrop` n'existe pas → erreur.

```lua
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:SetBackdropColor(0, 0, 0, 0.8)        -- RGBA, plage 0.0–1.0
frame:SetBackdropBorderColor(1, 1, 1, 1)    -- blanc = couleurs originales
```

⚠️ **`SetBackdrop()` AVANT `SetBackdropColor()`** — sinon erreur silencieuse ou crash.
⚠️ **Plage 0–1**, pas 0–255.

### 4. FontString — Texte dans une frame

```lua
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("My First Frame")
```

Les FontStrings ne se créent **pas** via `CreateFrame` — mais via `frame:CreateFontString()`.

Fonts disponibles : `GameFontNormal`, `GameFontNormalLarge`, `GameFontHighlight`, `GameFontGreen`, `GameFontRed`, etc.

### 5. Drag — Déplacer la frame

**3 appels obligatoires** (si un seul manque, rien ne se passe, sans erreur) :

```lua
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
```

Puis les handlers :

```lua
frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)
```

`EnableMouse(true)` rend **toute la frame** réactive au drag — pas seulement une barre de titre. Dans les vrais add-ons, on crée souvent une sous-frame (barre de titre) comme zone de drag.

### 6. Show / Hide / Toggle

```lua
frame:Show()
frame:Hide()
frame:SetShown(bool)           -- toggle conditionnel
frame:IsShown()                -- la frame *veut* être visible
frame:IsVisible()              -- la frame est *réellement* visible (parents inclus)
```

---

## Pièges rencontrés

| # | Piège | Ce qui se passe | Fix |
|---|-------|-----------------|-----|
| 1 | **Frame shown par défaut** | Après `CreateFrame`, la frame est déjà visible. Le premier toggle (`SetShown(not IsShown())`) la **cache** au lieu de l'afficher. | Appeler `frame:Hide()` à la fin de la création. |
| 2 | **Oublier `BackdropTemplate`** | `SetBackdrop` n'existe pas → `attempt to call method 'SetBackdrop' (a nil value)` | Toujours passer `"BackdropTemplate"` en 4e argument de `CreateFrame`. |
| 3 | **`SetBackdropColor` avant `SetBackdrop`** | Erreur silencieuse ou crash (régression 1.15.x) | Toujours appeler `SetBackdrop` en premier. |
| 4 | **Drag silencieux** | Si un des 3 prérequis manque (`SetMovable`, `EnableMouse`, `RegisterForDrag`), la frame ne bouge pas, sans aucun message d'erreur. | Les 3 sont obligatoires. |
| 5 | **Couleurs 0–255** | `SetBackdropColor(255, 255, 255)` → tout est clampé à 1 = blanc opaque | Utiliser la plage 0.0–1.0. |

---

## Test en jeu

1. Copier le dossier dans `Interface/AddOns/` (ou utiliser un symlink)
2. `/reload`
3. **Échap → Système → Addons** : vérifier que "My First Frame" apparaît
4. `/myframe` → la fenêtre apparaît au centre
5. Cliquer-glisser → la fenêtre se déplace
6. `/myframe` → la fenêtre disparaît (toggle)
7. `/myframe show` → affiche
8. `/myframe hide` → masque

---

## Fichiers

| Fichier | Rôle |
|---------|------|
| `MyFirstFrame.toc` | Métadonnées de l'add-on |
| `MyFirstFrame.lua` | Code complet : création de frame, backdrop, drag, slash command |

---

## Going Further

- → **Capsule 05 — Buttons & Text** : Boutons interactifs, FontStrings dynamiques, templates `BasicFrameTemplate`
