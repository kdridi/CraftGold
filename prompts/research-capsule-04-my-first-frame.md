# Recherche — Capsule 04 : My First Frame

**Contexte** : Je crée un add-on World of Warcraft Classic Era (version 1.15.x, interface 11508). Cette capsule est la première capsule d'interface graphique. L'objectif est de créer une Frame visible avec fond/bordure, la positionner, et la rendre déplaçable à la souris.

**Mode** : Fais une **vraie recherche web** pour répondre. Fournis des **liens sources** (URLs) pour chaque affirmation. La réponse doit être un **seul bloc markdown** complet, pas de fichiers séparés.

---

## 1. CreateFrame — Types et paramètres

- Quels sont les types de frames disponibles via `CreateFrame()` en Classic Era ? Liste complète.
- `CreateFrame(frameType, name, parent, template)` — le paramètre `template` est-il une string unique ? Peut-on en hériter plusieurs ?
- Quelle est la différence entre créer une frame avec un nom global (`"MyFrame"`) vs anonyme (`nil`) ? Le nom devient-il une variable globale `_G["MyFrame"]` ?

**Source de référence** : https://warcraft.wiki.gg/wiki/API_CreateFrame

## 2. Frame methods — Taille et position

### Taille
- `SetSize(width, height)` — existe en Classic Era ? Ou faut-il utiliser `SetWidth(width)` + `SetHeight(height)` séparément ?
- Quelle est l'unité ? Pixels ? Points UI ?

### Position (Anchor system)
- Syntaxe complète de `SetPoint()` :
  ```lua
  frame:SetPoint(point, relativeFrame, relativePoint, offsetX, offsetY)
  frame:SetPoint(point, offsetX, offsetY) -- raccourci ?
  ```
- Liste complète des points d'ancrage : `"TOPLEFT"`, `"TOP"`, `"TOPRIGHT"`, `"LEFT"`, `"CENTER"`, `"RIGHT"`, `"BOTTOMLEFT"`, `"BOTTOM"`, `"BOTTOMRIGHT"` — y en a-t-il d'autres ?
- Peut-on appeler `SetPoint()` plusieurs fois sur une même frame ? (ex: ancrer deux coins)
- `ClearAllPoints()` — quand et pourquoi l'utiliser ?
- Que se passe-t-il si on ne donne aucun parent et aucun point d'ancrage ?

**Source** : https://warcraft.wiki.gg/wiki/API_Region_SetPoint

## 3. Backdrop — Fond et bordure

C'est le point critique de cette capsule. J'ai besoin de savoir exactement comment rendre une frame visible.

### La méthode SetBackdrop
- `frame:SetBackdrop(backdropTable)` — cette méthode est-elle disponible directement sur les Frames en Classic Era, ou faut-il utiliser un template particulier (ex: `"BackdropTemplateMixin"`) ?
- **Question clé** : Y a-t-il eu un changement dans le système de Backdrop entre les versions Retail et Classic Era ? Certains threads mentionnent que `SetBackdrop` a été déplacé vers un mixin en 9.0. Ce changement s'applique-t-il aussi à Classic Era 1.15.x ?

### Structure de la table backdrop
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
- Cette syntaxe est-elle correcte pour Classic Era ?
- Quels sont les chemins de textures les plus courants/utiles pour :
  - Un fond uni (bgFile)
  - Une bordure standard (edgeFile)
  - Un fond transparent/baudruche
- Peut-on utiliser `nil` pour `bgFile` ou `edgeFile` (uniquement un fond, ou uniquement une bordure) ?

### SetBackdropColor et SetBackdropBorderColor
- `frame:SetBackdropColor(r, g, b [, a])` — plage de valeurs (0-1 ou 0-255 ?)
- `frame:SetBackdropBorderColor(r, g, b [, a])` — idem
- Ces méthodes fonctionnent-elles seulement si un `bgFile`/`edgeFile` est défini ?

**Sources** : https://warcraft.wiki.gg/wiki/API_Frame_SetBackdrop, https://warcraft.wiki.gg/wiki/Backdrop

## 4. Dragging — Rendre une frame déplaçable

La séquence habituelle est :
```lua
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
```

- Est-ce que cette séquence est correcte et complète pour Classic Era ?
- `RegisterForDrag()` — quels arguments accepte-t-il ? (`"LeftButton"`, `"RightButton"`, `"AnyButton"` ?)
- `StartMoving()` — déplace relativement à quoi ? La position originale est-elle préservée ?
- `StopMovingOrSizing()` — sauve-t-elle la nouvelle position en mémoire ? Ou faut-il un traitement manuel ?
- `SetClampedToScreen(true)` — empêche la frame de sortir de l'écran ? Est-ce standard ?

**Source** : https://warcraft.wiki.gg/wiki/API_Frame_StartMoving

## 5. Show / Hide

- `frame:Show()` et `frame:Hide()` — syntaxe et comportement
- Différence entre `IsShown()` et `IsVisible()` :
  - `IsShown()` = la frame veut être visible (indépendamment du parent)
  - `IsVisible()` = la frame est réellement visible à l'écran (prend en compte les parents)
- Un `print(frame:IsShown())` sur une frame sans parent — que retourne-t-il ?

## 6. Frame Strata et Level

- Quels sont les stratas disponibles et leur ordre ? (`"BACKGROUND"`, `"LOW"`, `"MEDIUM"`, `"HIGH"`, `"DIALOG"`, `"FULLSCREEN"`, `"FULLSCREEN_DIALOG"`, `"TOOLTIP"` ?)
- `SetFrameStrata(strata)` vs `SetFrameLevel(level)` — comment interagissent-ils ?
- Quelle est la valeur par défaut pour une frame nouvellement créée ?

## 7. Templates XML utiles

Existe-t-il en Classic Era des templates prêts à l'emploi pour éviter de configurer le backdrop manuellement ?
- `"UIPanelDialogTemplate"` — existe-t-il ? Donne-t-il une fenêtre standard avec fond et bordure ?
- `"BasicFrameTemplate"` — existe-t-il en Classic Era ?
- `"BackdropTemplate"` / `BackdropTemplateMixin` — est-ce un concept Retail-only ou aussi Classic Era ?
- Quels templates recommanderais-tu pour un débutant qui veut une fenêtre simple ?

## 8. Exemple complet

Fournis un **exemple complet et fonctionnel** d'un add-on minimal pour Classic Era qui :
1. Crée une frame 400×300 au centre de l'écran
2. Avec un fond et une bordure visibles
3. Qui peut être déplacée à la souris
4. Avec une commande slash `/myframe` pour show/hide

L'exemple doit inclure le `.toc` et le `.lua`. Commente chaque ligne importante.

## 9. Pièges courants (gotchas)

Liste les erreurs les plus fréquentes des débutants avec les frames :
- Oublier `EnableMouse(true)` avant `RegisterForDrag`
- Backdrop non visible parce que...
- Frame créée mais invisible parce que...
- Frame positionnée mais hors écran parce que...
- Tout ce que tu sais qui fait galérer les débutants

---

**Rappel** : Toute la réponse doit être en **markdown inline** (un seul bloc). Fournis des **liens sources** pour chaque section. Merci !
