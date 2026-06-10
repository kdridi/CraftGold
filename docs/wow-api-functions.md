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
- Pas de couleur possible directement
- **Visible même au top-level** après `/reload` (vérifié Session 2)

---

## Frames

### `CreateFrame(frameType [, name] [, parent] [, template])`

**Rôle** : Crée un élément d'interface (frame). Les frames sont des conteneurs invisibles qui peuvent afficher du texte, recevoir des cliccs, écouter des événements, etc.

**Paramètres** :
- `frameType` (string, requis) — Type de frame : `"Frame"`, `"Button"`, `"Slider"`, `"EditBox"`, `"ScrollFrame"`, etc.
- `name` (string, optionnel) — Nom global de la frame (utile pour le debug). `nil` = anonyme.
- `parent` (frame, optionnel) — Frame parente. Les enfants héritent de la visibilité et de l'échelle du parent. `nil` = pas de parent.
- `template` (string, optionnel) — Template XML hérité (ex: `"UIPanelButtonTemplate"`).

```lua
local frame = CreateFrame("Frame")                      -- frame anonyme, sans parent
local frame = CreateFrame("Frame", "MyFrame")           -- frame nommée
local frame = CreateFrame("Frame", "MyFrame", UIParent) -- frame attachée à l'UI
local btn = CreateFrame("Button", "MyBtn", UIParent, "UIPanelButtonTemplate")
```

**Types de frames courants** :
| Type | Rôle |
|------|------|
| `"Frame"` | Conteneur de base, invisible — utilisé pour écouter des événements |
| `"Button"` | Cliquable, a des états (normal, survolé, pressé) |
| `"Slider"` | Barre de défilement ou slider de valeur |
| `"EditBox"` | Zone de saisie de texte |
| `"ScrollFrame"` | Zone avec défilement |

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

---

## Événements WoW rencontrés

| Événement | Se déclenche quand... | Capsule |
|-----------|----------------------|---------|
| `PLAYER_LOGIN` | Le personnage se connecte (une seule fois par session) | 01 |
| `PLAYER_ENTERING_WORLD` | Entrée dans le monde (login + chaque changement de zone/instance) | 01 |
| `ADDON_LOADED` | Un add-on a fini de charger (une fois par add-on) | 03 |

---

## Add-ons

### `C_AddOns.GetAddOnMetadata(addonName, field)`

**Rôle** : Récupère un champ `##` du fichier `.toc` d'un add-on.

```lua
local version = C_AddOns.GetAddOnMetadata("HelloAzeroth", "Version")
local notes = C_AddOns.GetAddOnMetadata("HelloAzeroth", "Notes")
```

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
