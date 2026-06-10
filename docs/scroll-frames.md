# Scroll Frames — Classic Era 1.15.x

> Source : code source Blizzard exporté via `ExportInterfaceFiles code` (client Classic Era 1.15.x, interface 11508).
> Fichiers de référence : `Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua`, `Blizzard_APIDocumentationGenerated/SimpleSliderAPIDocumentation.lua`, `Blizzard_SharedXML/HybridScrollFrame.lua`, `Blizzard_SharedXML/HybridScrollFrame.xml`.

---

## Architecture d'une liste scrollable

Une liste scrollable en WoW se compose de 4 éléments :

```
┌─────────────────────────┐
│  ScrollFrame             │  ← Zone visible (fenêtre)
│  ┌───────────────────┐  │
│  │  ScrollChild       │  │  ← Contenu total (peut être plus grand)
│  │  ┌─────────────┐  │  │
│  │  │  Button 1    │  │  │
│  │  ├─────────────┤  │  │
│  │  │  Button 2    │  │  │
│  │  ├─────────────┤  │  │
│  │  │  ...         │  │  │
│  │  │  Button N    │  │  │
│  │  └─────────────┘  │  │
│  └───────────────────┘  │
└─────────────────────────┘ ┌──┐
                            │ ▲│  ← Slider (scrollbar)
                            │ █│
                            │ ▼│
                            └──┘
```

1. **ScrollFrame** — La fenêtre visible (clip les enfants)
2. **ScrollChild** — Le contenu total, potentiellement plus grand que le ScrollFrame
3. **Slider** — La barre de défilement (contrôle l'offset)
4. **Boutons** — Les éléments de la liste (dans le ScrollChild)

---

## API ScrollFrame

> Source : `SimpleScrollFrameAPIDocumentation.lua`

| Méthode | Description |
|---------|-------------|
| `SetScrollChild(frame)` | Définit la frame enfant qui sera scrollée |
| `GetScrollChild()` | Retourne la frame enfant |
| `SetVerticalScroll(offset)` | Déplace le scroll vertical (en unités UI) |
| `GetVerticalScroll()` | Retourne l'offset vertical actuel |
| `GetVerticalScrollRange()` | Retourne la range max de scroll (`scrollChild.height - scrollFrame.height`) |
| `SetHorizontalScroll(offset)` | Scroll horizontal |
| `GetHorizontalScroll()` | Offset horizontal actuel |
| `GetHorizontalScrollRange()` | Range max horizontal |
| `UpdateScrollChildRect()` | Force la mise à jour des dimensions du ScrollChild |

### Principe

- Le ScrollFrame agit comme une **fenêtre** : il ne montre que la portion visible
- Le ScrollChild est le **contenu** : il peut être plus grand que le ScrollFrame
- `SetVerticalScroll(offset)` déplace la "fenêtre" vers le bas dans le contenu
- `GetVerticalScrollRange()` = `scrollChildHeight - scrollFrameHeight`

### Événements

| Script | Déclenché quand |
|--------|-----------------|
| `OnVerticalScroll(self, offset)` | Le scroll vertical change |
| `OnHorizontalScroll(self, offset)` | Le scroll horizontal change |
| `OnScrollRangeChanged(self, xrange, yrange)` | La range de scroll change (resize) |

---

## API Slider

> Source : `SimpleSliderAPIDocumentation.lua`

| Méthode | Description |
|---------|-------------|
| `GetValue()` | Position actuelle du curseur |
| `SetValue(value)` | Déplace le curseur |
| `SetMinMaxValues(min, max)` | Définit la range |
| `GetMinMaxValues()` | Retourne min, max |
| `SetValueStep(step)` | Incrément discret (snap) |
| `GetValueStep()` | Retourne le step |
| `SetStepsPerPage(n)` | Nombre de steps par page de scroll |
| `GetStepsPerPage()` | Retourne les steps par page |
| `SetThumbTexture(asset)` | Texture du curseur |
| `GetThumbTexture()` | Retourne la texture du curseur |
| `SetOrientation(orient)` | `"HORIZONTAL"` ou `"VERTICAL"` |
| `Enable()` / `Disable()` | Active/désactive le slider |
| `IsEnabled()` | État |

### Événements

| Script | Déclenché quand |
|--------|-----------------|
| `OnValueChanged(self, value)` | La valeur du slider change |

### Orientation

- `"VERTICAL"` par défaut pour une scrollbar
- ⚠️ En vertical, la valeur **0 est en haut** et la valeur **max est en bas**

---

## Molette de souris

```lua
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    -- delta = 1 → scroll vers le haut (recule dans la liste)
    -- delta = -1 → scroll vers le bas (avance dans la liste)
    local current = scrollBar:GetValue()
    local step = buttonHeight  -- hauteur d'un élément
    if delta > 0 then
        scrollBar:SetValue(math.max(0, current - step))
    else
        scrollBar:SetValue(math.min(scrollBar:GetMinMaxValues(), current + step))
    end
end)
```

⚠️ `EnableMouseWheel(true)` est **obligatoire**. Sans ça, `OnMouseWheel` ne se déclenche pas.

---

## Pattern simple : ScrollFrame + Slider manuel

C'est le pattern le plus pédagogique — chaque pièce est visible.

```lua
-- 1. Créer le ScrollFrame
local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "BackdropTemplate")
scrollFrame:SetSize(300, 400)
scrollFrame:SetPoint("LEFT", parent, "LEFT", 20, 0)

-- 2. Créer le ScrollChild (contenu)
local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollFrame:SetScrollChild(scrollChild)
scrollChild:SetWidth(300)
scrollChild:SetHeight(2000)  -- taille totale du contenu

-- 3. Créer le Slider (scrollbar)
local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
slider:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 5, 0)
slider:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 5, 0)
slider:SetWidth(16)
slider:SetMinMaxValues(0, 1600)  -- scrollChild.height - scrollFrame.height
slider:SetValueStep(30)
slider:SetValue(0)

-- 4. Lier slider → scrollFrame
slider:SetScript("OnValueChanged", function(self, value)
    scrollFrame:SetVerticalScroll(value)
end)

-- 5. Lier molette → slider
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local current = slider:GetValue()
    local step = 30
    if delta > 0 then
        slider:SetValue(math.max(0, current - step))
    else
        slider:SetValue(math.min(1600, current + step))
    end
end)

-- 6. Remplir le ScrollChild avec des boutons
for i = 1, 50 do
    local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
    btn:SetSize(280, 30)
    btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -(i-1) * 35)
    -- ... configurer le bouton
end
```

---

## Pattern avancé : Button Pooling (HybridScrollFrame)

Le pattern simple crée **N boutons** même si on ne peut en voir que ~10. Pour les grandes listes, c'est du gaspillage.

Le **button pooling** ne crée que les boutons visibles (+ 1 tampon) et les recycle quand on scroll.

### Principe

```
Données : [item1, item2, item3, ..., item100]
Boutons : [btn1, btn2, btn3, ..., btn11]   ← seulement ceil(height/btnHeight)+1

Offset = 0 → btn1=item1, btn2=item2, ..., btn11=item11
Offset = 3 → btn1=item4, btn2=item5, ..., btn11=item14
```

### Pattern (simplifié)

```lua
local BUTTON_HEIGHT = 30
local DATA = { ... }  -- liste de données
local buttons = {}     -- pool de boutons

local function UpdateList()
    local scrollChild = scrollFrame:GetScrollChild()
    local offset = math.floor(scrollFrame:GetVerticalScroll() / BUTTON_HEIGHT)
    local visibleCount = math.ceil(scrollFrame:GetHeight() / BUTTON_HEIGHT) + 1

    for i = 1, visibleCount do
        local btn = buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            btn:SetSize(280, BUTTON_HEIGHT)
            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -(i-1) * BUTTON_HEIGHT)
            buttons[i] = btn
        end

        local dataIndex = offset + i
        if dataIndex <= #DATA then
            btn:SetText(DATA[dataIndex])
            btn:Show()
        else
            btn:Hide()
        end
    end
end
```

---

## Templates Blizzard disponibles

> Source : `HybridScrollFrame.xml`

| Template | Description |
|----------|-------------|
| `"HybridScrollFrameTemplate"` | ScrollFrame avec OnLoad + OnMouseWheel + ScrollChild intégré |
| `"BasicHybridScrollFrameTemplate"` | Template complet : ScrollFrame + ScrollBar (boutons up/down) |
| `"MinimalHybridScrollFrameTemplate"` | ScrollFrame + scrollbar minimaliste (fond noir) |
| `"HybridScrollBarTemplate"` | Scrollbar avec boutons up/down + thumb texture |
| `"MinimalHybridScrollBarTemplate"` | Scrollbar minimaliste |
| `"HybridScrollBarBackgroundTemplate"` | Scrollbar avec fond + textures d'encadrement |

### Fonctions utilitaires HybridScrollFrame

> Source : `HybridScrollFrame.lua`

| Fonction | Description |
|----------|-------------|
| `HybridScrollFrame_OnLoad(self)` | Initialise le scroll frame |
| `HybridScrollFrame_CreateButtons(self, template, ...)` | Crée le pool de boutons |
| `HybridScrollFrame_Update(self, totalHeight, displayedHeight)` | Met à jour range + visibilité scrollbar |
| `HybridScrollFrame_GetOffset(self)` | Retourne offset (integer, float) |
| `HybridScrollFrame_SetOffset(self, offset)` | Définit l'offset et appelle `self:update()` |
| `HybridScrollFrame_OnMouseWheel(self, delta)` | Handler molette |

### Propriétés du HybridScrollFrame

| Propriété | Description |
|-----------|-------------|
| `self.buttons` | Liste des boutons du pool |
| `self.buttonHeight` | Hauteur d'un bouton |
| `self.scrollBar` | Référence au Slider |
| `self.scrollChild` | Référence au ScrollChild |
| `self.update` | Fonction de callback pour mettre à jour les boutons |
| `self.offset` | Offset actuel |
| `self.range` | Range max de scroll |

---

## Gotchas

1. **ScrollChild height** — Doit être défini **manuellement**. WoW ne calcule pas automatiquement la taille du ScrollChild à partir de ses enfants.
2. **Slider min/max** — Doit être mis à jour quand le contenu change : `max = scrollChildHeight - scrollFrameHeight`.
3. **Molette** — `EnableMouseWheel(true)` est obligatoire. Sans ça, rien ne se passe, sans erreur.
4. **Slider vertical inversé** — En vertical, valeur 0 = haut, max = bas. C'est intuitif pour une scrollbar.
5. **SetScrollChild obligatoire** — Sans `SetScrollChild`, le ScrollFrame n'a rien à scroller.
6. **Button pooling et ancres** — Les boutons du pool sont ancrés séquentiellement (TOPLEFT → BOTTOMLEFT du précédent). Ne pas les ré-ancrer à chaque update, juste modifier leur contenu.
7. **ScrollFrame clips les enfants** — Seul le contenu dans les limites du ScrollFrame est visible. C'est le comportement voulu.
8. **`OnVerticalScroll` est un callback** — Si défini, il se déclenche quand `SetVerticalScroll` est appelé. Utile pour synchro le slider.
