Voici un guide complet pour la création et la manipulation d'une première interface graphique (Frame) sur World of Warcraft Classic Era (1.15.x), basé sur les spécificités de l'API moderne utilisée dans les versions Classic.

```markdown
# Guide Complet : Création et Gestion de Frames (WoW Classic Era 1.15.x)

## 1. CreateFrame — Types et paramètres

L'API `CreateFrame(frameType, name, parent, template)` est la pierre angulaire de la création d'interface en Lua.

- **Types de frames disponibles** : L'argument `frameType` définit la classe de base. Les plus courants sont : `"Frame"` (conteneur de base), `"Button"` (cliquable), `"GameTooltip"` (infobulle), `"ScrollFrame"` (zone défilante), `"Slider"` (curseur), `"StatusBar"` (barre de progression), `"EditBox"` (saisie de texte), `"CheckButton"`, `"ColorSelect"`, `"Cooldown"`, `"Model"`, `"MessageFrame"`, `"Minimap"`, etc.
- **Le paramètre `template`** : C'est une chaîne de caractères (`string`). On peut tout à fait hériter de plusieurs templates en les séparant par des virgules (ex: `"BackdropTemplate, BasicFrameTemplate"`). Le moteur XML les fusionnera de gauche à droite.
- **Nom global vs Anonyme** : 
  - Si vous donnez un nom (ex: `"MyFrame"`), le jeu crée automatiquement une variable globale accessible via `MyFrame` ou `_G["MyFrame"]`.
  - Si vous passez `nil`, la frame est anonyme. Elle n'existe que dans la variable locale à laquelle vous l'assignez (`local f = CreateFrame(...)`). C'est la meilleure pratique pour éviter de polluer l'espace global et prévenir les conflits entre addons.

*Sources : [API CreateFrame - Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_CreateFrame), [Widget types - Warcraft Wiki](https://warcraft.wiki.gg/wiki/UI_objects)*

---

## 2. Frame methods — Taille et position

### Taille
- `SetSize(width, height)` **existe bien en Classic Era**. L'infrastructure de Classic Era 1.15.x repose sur le client Retail moderne. C'est un raccourci très pratique pour `SetWidth()` + `SetHeight()`.
- **L'unité** : Les valeurs sont en "Points UI" (UI Pixels), c'est-à-dire des pixels virtuels mis à l'échelle selon le réglage de l'interface (UI Scale) du joueur dans les options du jeu.

### Position (Anchor system)
- **Syntaxe complète** : `frame:SetPoint("point", relativeFrame, "relativePoint", offsetX, offsetY)`
- **Raccourci** : `frame:SetPoint("point", offsetX, offsetY)`. Si le `relativeFrame` est omis, il utilise le parent de la frame. Le `relativePoint` prendra la même valeur que `point`.
- **Points d'ancrage** : Il y en a 9 au total. `"TOPLEFT"`, `"TOP"`, `"TOPRIGHT"`, `"LEFT"`, `"CENTER"`, `"RIGHT"`, `"BOTTOMLEFT"`, `"BOTTOM"`, `"BOTTOMRIGHT"`.
- **Ancrages multiples** : Oui, on peut appeler `SetPoint()` plusieurs fois pour ancrer différents coins. Par exemple, ancrer le `"TOPLEFT"` et le `"BOTTOMRIGHT"` forcera la frame à s'étirer entre ces deux points, remplaçant ainsi l'usage de `SetSize()`.
- **`ClearAllPoints()`** : Indispensable avant de redéfinir la position d'une frame (ou lors d'un déplacement manuel). Sans cela, le moteur UI ajoute le nouveau point aux anciens, ce qui crée des conflits et empêche la frame de bouger correctement.
- **Sans parent ni point** : Une frame sans parent est rattachée par défaut à l'écran entier. Sans aucun point d'ancrage, elle sera par défaut placée au point `(0,0)` (généralement en bas à gauche de l'écran) avec une taille de `0x0` (elle sera donc invisible jusqu'à ce qu'on la positionne et la dimensionne).

*Sources : [API Region_SetPoint - Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_Region_SetPoint), [API Region_ClearAllPoints](https://warcraft.wiki.gg/wiki/API_Region_ClearAllPoints)*

---

## 3. Backdrop — Fond et bordure

C'est ici que se trouve le plus grand piège pour les développeurs revenant sur Classic.

### La méthode SetBackdrop
- **Changement crucial (Mixin 9.0)** : Les versions Classic Era utilisent le client moderne de WoW. Par conséquent, **la méthode `SetBackdrop` n'existe plus par défaut sur les frames**. Pour l'utiliser, il est **obligatoire** d'inclure `"BackdropTemplate"` lors du `CreateFrame`.
- La syntaxe que vous avez fournie est parfaitement correcte pour Classic Era, tant que la frame possède le bon template.

### Textures courantes
- **Fond uni (couleur pure)** : `bgFile = "Interface\\ChatFrame\\ChatFrameBackground"` (c'est une texture totalement blanche, idéale car elle peut être teintée de n'importe quelle couleur via `SetBackdropColor`).
- **Bordure standard** : `edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border"`
- **Fond transparent/baudruche (Tooltip)** : `bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"`
- **Valeurs `nil`** : Oui, vous pouvez totalement omettre le `bgFile` (pour avoir juste un cadre) ou le `edgeFile` (pour avoir juste un bloc de couleur).

### Couleurs
- `frame:SetBackdropColor(r, g, b [, a])` et `frame:SetBackdropBorderColor(...)`
- **Plage de valeurs** : Les valeurs vont de **0 à 1** (0 = 0%, 1 = 100%). Ex: Blanc = `(1, 1, 1, 1)`, Rouge = `(1, 0, 0, 1)`.
- **Condition** : Ces méthodes ne sont que des "teintes" appliquées à la texture existante. Si le `bgFile` est noir, le teinter en rouge le laissera noir. Il **faut** utiliser une texture blanche (comme `ChatFrameBackground`) pour que la couleur voulue s'affiche correctement.

*Sources : [Frame:SetBackdrop - Wowpedia](https://wowpedia.fandom.com/wiki/API_Frame_SetBackdrop), [BackdropTemplate issues - Blizzard Forums](https://us.forums.blizzard.com/en/wow/t/backdroptemplate-issues/1125674)*

---

## 4. Dragging — Rendre une frame déplaçable

La séquence que vous avez fournie est parfaite et standard pour Classic Era.

- **`RegisterForDrag(...)`** : Accepte des chaînes de caractères représentant les boutons de la souris : `"LeftButton"`, `"RightButton"`, `"MiddleButton"`. Vous pouvez en passer plusieurs d'un coup : `frame:RegisterForDrag("LeftButton", "RightButton")`.
- **`StartMoving()`** : Attache temporairement la frame au curseur de la souris. Cela efface techniquement les points d'ancrage précédents (`SetPoint`) et les remplace par des coordonnées absolues relatives à l'écran (le `UIParent`).
- **`StopMovingOrSizing()`** : Arrête le déplacement et ancre la frame à sa nouvelle position sur l'écran. **Attention** : cette position n'est conservée que jusqu'au rechargement de l'interface (`/reload`) ou la déconnexion. Pour la rendre persistante, vous devez sauvegarder les coordonnées dans les `SavedVariables` de votre addon.
- **`SetClampedToScreen(true)`** : Très recommandé. Cela empêche l'utilisateur de glisser la frame hors des limites de l'écran (ce qui la rendrait impossible à récupérer).

*Sources : [API Frame_RegisterForDrag - Wowpedia](https://wowpedia.fandom.com/wiki/API_Frame_RegisterForDrag), [API Frame_StartMoving - Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_Frame_StartMoving)*

---

## 5. Show / Hide

- **`Show()` et `Hide()`** : Modifient l'état désiré de la frame.
- **Différence `IsShown()` vs `IsVisible()`** :
  - `IsShown()` : Retourne `true` si `Show()` a été appelé sur cette frame (elle *veut* être visible).
  - `IsVisible()` : Retourne `true` **uniquement** si la frame a été "Shown" **ET** que tous ses parents sont également visibles à l'écran. C'est l'état réel de rendu.
- Un `print(frame:IsShown())` sur une frame sans parent retournera `true` si elle a été affichée, car elle ne dépend de personne pour déterminer son affichage de base. `IsVisible()` sera également `true`.

*Sources : [API ScriptRegionResizing_IsShown - Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_IsShown)*

---

## 6. Frame Strata et Level

Le système de profondeur de WoW fonctionne sur deux dimensions (le calque, puis le z-index dans ce calque).

- **Stratas disponibles (du fond vers le devant)** : `"BACKGROUND"`, `"LOW"`, `"MEDIUM"`, `"HIGH"`, `"DIALOG"`, `"FULLSCREEN"`, `"FULLSCREEN_DIALOG"`, `"TOOLTIP"`.
- **Interactions** : 
  - `SetFrameStrata(strata)` place votre frame dans une "couche globale" de l'UI.
  - `SetFrameLevel(level)` définit un ordre de superposition numérique (1, 2, 3...) **à l'intérieur** d'une même strata.
- **Valeurs par défaut** : Une frame nouvellement créée hérite de la strata de son parent. Si son parent est l'UI globale (`UIParent`), elle est généralement en `"MEDIUM"`.

*Sources : [FrameStrata - Warcraft Wiki](https://warcraft.wiki.gg/wiki/FrameStrata)*

---

## 7. Templates XML utiles en Classic Era

- **`"BackdropTemplate"`** : Absolument requis pour tout panneau personnalisé avec `SetBackdrop`.
- **`"BasicFrameTemplate"`** : Extrêmement utile. Il génère la fenêtre standard de WoW (bordures grises/métalliques, fond marbré) avec une icône de portrait en haut à gauche et un bouton de fermeture natif (`X`) en haut à droite. Il gère le Backdrop pour vous.
- **`"UIPanelDialogTemplate"`** : Existe également, produit un résultat similaire mais plus typé "dialogue de confirmation" avec les bordures dorées de quêtes/PNJ.

**Recommandation** : Pour apprendre et maîtriser la mécanique (`SetBackdrop`), utilisez **`"BackdropTemplate"`**. Pour aller vite en production et s'intégrer au look du jeu, utilisez **`"BasicFrameTemplate"`**.

---

## 8. Exemple complet

Voici une capsule minimaliste, propre et fonctionnelle, avec `.toc` et `.lua`.

### Fichier `MyFirstFrame.toc`
```toc
## Interface: 11508
## Title: My First Frame
## Notes: Une capsule d'apprentissage pour la création de Frame.
## Author: Vous
## Version: 1.0

MyFirstFrame.lua

```

### Fichier `MyFirstFrame.lua`

```lua
-- 1. Création de la frame avec BackdropTemplate (obligatoire en 1.15.x)
local myFrame = CreateFrame("Frame", "MyAddonMainFrame", UIParent, "BackdropTemplate")

-- 2. Taille et position au centre
myFrame:SetSize(400, 300)
myFrame:SetPoint("CENTER", 0, 0)

-- 3. Configuration du fond et de la bordure
myFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground", -- Texture blanche pour fond uni
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", -- Bordure standard WoW
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

-- On teinte le fond blanc en noir semi-transparent (RGBA)
myFrame:SetBackdropColor(0, 0, 0, 0.8)

-- 4. Rendre la frame déplaçable
myFrame:SetMovable(true)             -- Permet le mouvement technique
myFrame:EnableMouse(true)            -- Rend la frame interactive
myFrame:RegisterForDrag("LeftButton")-- Écoute le clic gauche pour le glisser
myFrame:SetClampedToScreen(true)     -- Empêche la frame de sortir de l'écran

-- Scripts de déplacement
myFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

myFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- 5. Commande Slash pour Show/Hide
SLASH_MYFIRSTFRAME1 = "/myframe"
SlashCmdList["MYFIRSTFRAME"] = function()
    if myFrame:IsShown() then
        myFrame:Hide()
        print("MyFirstFrame: Cachée")
    else
        myFrame:Show()
        print("MyFirstFrame: Affichée")
    end
end

-- Masquer la frame au chargement par défaut (optionnel)
-- myFrame:Hide()

```

---

## 9. Pièges courants (Gotchas pour les débutants)

1. **Le Crash de `SetBackdrop**` : `attempt to call method 'SetBackdrop' (a nil value)`. L'erreur la plus commune sur WoW Classic. Oublier de passer `"BackdropTemplate"` au `CreateFrame`.
2. **Couleurs qui ne marchent pas** : Utiliser un `bgFile` comme une texture de marbre noir ("UI-DialogBox-Background") et essayer de la teinter en rouge clair avec `SetBackdropColor`. Comme dit plus haut, on ne peut pas teinter une texture sombre en clair. Utilisez `ChatFrameBackground`.
3. **Le Glisser-Déposer qui ne répond pas** : Oublier `frame:EnableMouse(true)`. Une frame par défaut laisse passer les clics au travers d'elle. Sans cette commande, `OnDragStart` ne s'activera jamais.
4. **La frame qui s'étire au lieu de bouger** : Déplacer ou redéfinir dynamiquement un `SetPoint` sans appeler `frame:ClearAllPoints()` au préalable. Les points d'ancrage se cumulent et font "bugger" la géométrie de la frame.
5. **Amnésie de l'Interface** : La position issue de `StopMovingOrSizing()` est temporaire. Au prochain redémarrage du jeu, la frame retournera au centre. Gérer la sauvegarde nécessite la mise en place d'une table `SavedVariables` dans le fichier `.toc` et d'injecter ses valeurs dans le `SetPoint` à l'événement `ADDON_LOADED`.

```

```