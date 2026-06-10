Voici la synthèse de recherche pour la Capsule 04. Tout est vérifié contre warcraft.wiki.gg et les forums Blizzard, avec un focus particulier sur le piège n°1 de Classic Era 1.15.x : le Backdrop.

---

# Capsule 04 — My First Frame (Classic Era 1.15.x)

## 1. CreateFrame — Types et paramètres

**Signature** : `frame = CreateFrame(frameType [, name, parent, template, id])`

**Types de frames** : il n'existe pas de liste "officielle" dans la doc de la fonction elle-même ; les types possibles sont définis par le schéma XML du client (UI.xsd). Les principaux utilisables en Classic Era : `Frame`, `Button`, `CheckButton`, `EditBox`, `ScrollFrame`, `Slider`, `StatusBar`, `GameTooltip`, `MessageFrame`, `ScrollingMessageFrame`, `ColorSelect`, `Model`, `PlayerModel`, `Cooldown`, `SimpleHTML`. Pour ta capsule, `"Frame"` suffit.

**Le paramètre `template`** : ce n'est pas limité à un seul template. C'est une chaîne contenant une liste de templates XML virtuels séparés par des virgules — ex. `"BasicFrameTemplate, BackdropTemplate"` est valide (attention aux conflits entre templates, cependant).

**Nom global vs anonyme** : `name` est un nom globalement accessible à assigner à la frame, ou `nil` pour une frame anonyme. Oui, donner `"MyFrame"` crée bien la variable globale `_G["MyFrame"]`. Deux points importants :
- Un nom global est **requis** si tu veux que le client sauvegarde la position de la frame entre les sessions (voir §4).
- Si le template hérité a un script OnLoad, il est déclenché à la création. Les frames ne peuvent pas être supprimées ni collectées par le garbage collector — il vaut mieux les réutiliser.

À noter : le paramètre `parent` doit être un objet Frame (ou nil), pas une string.

> Sources : https://warcraft.wiki.gg/wiki/API_CreateFrame · https://warcraft.wiki.gg/wiki/UIOBJECT_Frame

## 2. Taille et position

### Taille
`SetSize(width, height)` existe bien en Classic Era (le client 1.15.x est un client moderne basé sur le code Retail). `SetSize(width, height)` est équivalent à `SetWidth(width)` + `SetHeight(height)`. L'unité n'est pas le pixel physique mais des **unités UI** ("points"), affectées par le UI scale (`SetScale`, échelle de UIParent, résolution).

Piège documenté : si la largeur/hauteur est déduite des points d'ancrage (ex. deux coins opposés ancrés, ou `SetAllPoints`), `SetSize` n'a aucun effet.

### SetPoint
Signature complète : `SetPoint(point [, relativeTo [, relativePoint]] [, offsetX, offsetY])`. Tous les raccourcis suivants sont équivalents : `f:SetPoint("BOTTOMLEFT")`, `f:SetPoint("BOTTOMLEFT", 0, 0)`, `f:SetPoint("BOTTOMLEFT", UIParent)`, `f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)` — si `relativeTo` est omis, l'ancrage se fait sur le parent, ou à défaut sur les dimensions de l'écran ; si `relativePoint` est omis, il prend la même valeur que `point`.

**Liste complète des points** : TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT, TOP, BOTTOM, LEFT, RIGHT, CENTER — il n'y en a pas d'autres, ce sont les 9 valeurs du type `FramePoint`.

**Multi-ancrage** : oui. Une région n'a besoin que d'un ou deux points pour être dessinée, mais on peut définir les neuf si on veut. Ancrer `TOPLEFT` et `BOTTOMRIGHT` à deux endroits différents permet de faire une frame qui s'étire (sa taille devient alors implicite, cf. piège SetSize ci-dessus).

**ClearAllPoints()** : typiquement utilisé avant de repositionner une frame avec SetPoint() pour éviter des rects invalides ou des textures déformées. Règle pratique : si tu re-ancres une frame avec un *point différent* de celui déjà posé, appelle d'abord `ClearAllPoints()`, sinon les deux ancres coexistent et la frame s'étire bizarrement.

**Sans parent ni point d'ancrage** : la frame n'a pas de "rect" valide et **ne s'affiche pas du tout**, même si `IsShown()` retourne true. C'est un des pièges classiques (§9). Attention aussi à l'erreur "anchor family" : ancrer une frame à la fois sur UIParent et sur les dimensions de l'écran provoque une erreur "SetPoint would result in anchor family connection".

> Sources : https://warcraft.wiki.gg/wiki/API_Region_SetPoint · https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_SetSize · https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_GetNumPoints

## 3. Backdrop — LE point critique

### La réponse à ta question clé : OUI, le changement 9.0 s'applique à Classic Era

C'est confirmé sans ambiguïté par la wiki :
- Patch 9.0.1 (2020-10-13) : BackdropTemplate ajouté à FrameXML, en remplacement de Frame:SetBackdrop() et de l'élément XML &lt;Backdrop&gt;.
- Et surtout : Patch 1.14.0 (2021-09-28) : désormais rétroporté à toutes les variantes Classic ; le code de rétrocompatibilité n'est plus nécessaire.

Donc en **Classic Era 1.15.x**, une frame "nue" créée avec `CreateFrame("Frame")` n'a **pas** de méthode `SetBackdrop`. Tu dois soit :
1. Hériter du template : `CreateFrame("Frame", "MyFrame", UIParent, "BackdropTemplate")` (méthode recommandée) ;
2. Soit appliquer le mixin sur une frame existante : `if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end`.

Le workflow officiel : créer une Frame héritant de BackdropTemplate, préparer une table backdropInfo (ou en choisir une existante dans Blizzard_SharedXML/Backdrop.lua), l'appliquer avec SetBackdrop(backdropInfo), puis changer les couleurs avec SetBackdropColor(r, g, b [, a]) et SetBackdropBorderColor(r, g, b [, a]).

Subtilités importantes :
- SetBackdrop() avec une nouvelle table change les propriétés (échoue silencieusement si c'est la même table, même modifiée) ; SetBackdrop() sans argument retire le backdrop.
- Il existe des tables backdrop prédéfinies globales (ex. `BACKDROP_TUTORIAL_16_16`, `BACKDROP_TOOLTIP_8_8_1111`) — on peut aussi assigner `frame.backdropInfo` puis appeler `ApplyBackdrop()`.
- ⚠️ Régression récente signalée : depuis des mises à jour du client Classic Era mi-2025 (1.15.x+), de nombreux addons utilisant BackdropTemplate ou appelant SetBackdropColor/SetBackdropBorderColor pendant le chargement précoce lèvent une erreur "table index is nil", provenant du backdropInfo interne non initialisé. Moralité : appelle toujours `SetBackdrop(table)` **avant** `SetBackdropColor`/`SetBackdropBorderColor`.

### Structure de la table backdrop
Ta syntaxe est correcte. Champs et défauts documentés : bgFile (chemin de texture du fond), edgeFile, tile = false, tileEdge = false, tileSize = 0, edgeSize = 32, insets = { left/right/top/bottom = 0 }.

- **Oui**, on peut omettre (`nil`) `bgFile` ou `edgeFile` pour n'avoir qu'un fond ou qu'une bordure.
- Chemins de textures courants et fiables en Classic Era :
  - Fond style tooltip : `"Interface\\Tooltips\\UI-Tooltip-Background"` (utilisé dans l'exemple officiel de la wiki avec edgeFile "Interface/Tooltips/UI-Tooltip-Border" et edgeSize 16)
  - Fond style boîte de dialogue : `"Interface\\DialogFrame\\UI-DialogBox-Background"` + bordure `"Interface\\DialogFrame\\UI-DialogBox-Border"` (ta table est le combo classique, avec tileSize/edgeSize 32 et insets ~11)
  - Fond uni colorable : `"Interface\\ChatFrame\\ChatFrameBackground"` comme bgFile et `"Interface\\Buttons\\WHITE8x8"` comme edgeFile fin (edgeSize 1) — la texture blanche 8×8 prend exactement la couleur passée à SetBackdropColor. Pour un "fond transparent", utilise WHITE8x8 + `SetBackdropColor(0,0,0,0.5)` (le canal alpha fait le travail).

### SetBackdropColor / SetBackdropBorderColor
- Plage **0–1** (pas 0–255), alpha optionnel : l'exemple officiel utilise `f:SetBackdropColor(0, 0, 1, .5)`.
- `SetBackdropColor` teinte la texture `bgFile`, `SetBackdropBorderColor` teinte `edgeFile`. Sans fichier correspondant défini, l'appel n'a rien à teinter (et peut même planter si appelé avant tout SetBackdrop, cf. la régression ci-dessus).

> Sources : https://warcraft.wiki.gg/wiki/BackdropTemplate · https://warcraft.wiki.gg/wiki/API_Frame_SetBackdrop · https://eu.forums.blizzard.com/en/wow/t/590913

## 4. Dragging

Ta séquence est **correcte et complète**. C'est mot pour mot le pattern officiel de la wiki : marquer la frame comme déplaçable avec frame:SetMovable(true), activer la souris avec frame:EnableMouse(true) ou frame:RegisterForDrag("LeftButton"), puis appeler StartMoving() dans OnDragStart et StopMovingOrSizing() dans OnDragStop. Note élégante : les méthodes StartMoving et StopMovingOrSizing peuvent être réutilisées directement comme handlers (`frame:SetScript("OnDragStart", frame.StartMoving)`), évitant de créer des fonctions supplémentaires.

- **RegisterForDrag** : `Frame:RegisterForDrag([button1, ...])` — enregistre la frame pour le drag avec un ou plusieurs boutons de souris. Arguments valides : `"LeftButton"`, `"RightButton"`, `"MiddleButton"`, `"Button4"`, `"Button5"` (tu peux en passer plusieurs ; il n'y a pas de `"AnyButton"`). ⚠️ EnableMouse (ou SetMouseClickEnabled) est requis, car ce n'est pas automatiquement impliqué par OnDragStart ; RegisterForDrag est requis également — les deux pièges les plus courants.
- **StartMoving()** : la frame suit la souris (il faut bouger un peu la souris avant que le drag ne démarre). La position d'origine n'est pas "préservée" : après le déplacement, les anciens points d'ancrage sont remplacés.
- **StopMovingOrSizing()** : arrête le déplacement/redimensionnement et ancre le point le plus proche d'un point de UIParent. Donc l'ancre change (ce ne sera plus forcément ton "CENTER" original). Pour la persistance entre sessions, deux options :
  - Laisser le client faire : déplacer une frame avec StartMoving active le flag "user placed", ce qui fait que le client sauvegarde sa position et la repositionne au reload ; pour éviter ce comportement, appeler frame:SetUserPlaced(false) juste après StopMovingOrSizing(). Condition : la frame doit avoir un nom non-nil et être marquée movable avant que PLAYER_LOGIN ne se déclenche.
  - Ou gérer manuellement : lire `frame:GetPoint()` dans OnDragStop et le stocker dans une SavedVariable.
- **SetClampedToScreen(true)** : oui, c'est standard et recommandé : si tu ne veux pas que l'utilisateur puisse (accidentellement) glisser la frame hors écran, utilise frame:SetClampedToScreen(true). Attention : si la frame se retrouve bloquée (par le clamp), la souris et la frame peuvent se désynchroniser.

> Sources : https://warcraft.wiki.gg/wiki/Making_draggable_frames · https://warcraft.wiki.gg/wiki/API_Frame_StopMovingOrSizing · https://wowwiki-archive.fandom.com/wiki/API_Frame_StartMoving

## 5. Show / Hide

`frame:Show()` et `frame:Hide()` basculent l'état "shown" de la frame (et déclenchent les scripts `OnShow`/`OnHide`). Les frames sont shown par défaut à leur création — d'où le pattern courant de faire `frame:Hide()` à la fin de la création si la fenêtre doit être ouverte à la demande.

Ta compréhension est exacte et documentée : IsShown() retourne true si la région devrait être affichée, mais sa visibilité réelle dépend des parents ; IsVisible() retourne true si la région ET ses parents sont shown. L'exemple officiel : une frame visible retourne (true, true) ; si on la reparente à une frame cachée, elle retourne (true, false).

Pour ta question : `print(frame:IsShown())` sur une frame sans parent fraîchement créée retourne **true** (shown par défaut) — même si elle est invisible faute de taille/ancrage. Autre nuance utile : mettre l'alpha à zéro rend la frame invisible mais toujours interactive (et IsShown/IsVisible restent true).

> Source : https://warcraft.wiki.gg/wiki/API_ScriptRegion_IsShown

## 6. Frame Strata et Level

Les stratas divisent l'axe Z en neuf intervalles (de l'arrière vers l'avant) : `WORLD`, `BACKGROUND`, `LOW`, `MEDIUM`, `HIGH`, `DIALOG`, `FULLSCREEN`, `FULLSCREEN_DIALOG`, `TOOLTIP` — sachant que WORLD est réservé à la world frame et ne peut pas être assigné.

Interaction strata/level : les frame levels subdivisent chaque strata en intervalles numérotés 0–10000 ; un nombre plus élevé apparaît au-dessus, mais seulement entre frames de la même strata. La strata gagne toujours : un level 10000 en `BACKGROUND` reste derrière un level 0 en `DIALOG`.

Valeurs par défaut : chaque frame apparaît par défaut légèrement au-dessus de son parent : même strata, mais un level de plus. Concrètement : un parent direct de UIParent a le level 1, ses enfants le level 2. Une frame parentée à UIParent est en strata `MEDIUM` (la strata de UIParent). Pour une fenêtre de type dialogue, `SetFrameStrata("DIALOG")` est le choix habituel. Outils : Frame:Raise() monte le frameLevel au-dessus des frames de la même strata ; Frame:Lower() fait l'inverse.

> Sources : https://warcraft.wiki.gg/wiki/Frame_Strata · https://warcraft.wiki.gg/wiki/Frame_Level

## 7. Templates XML utiles

- **`BackdropTemplate`** : n'est **pas** Retail-only — rétroporté à toutes les variantes Classic depuis le patch 1.14.0. C'est LE template indispensable de cette capsule.
- **`BasicFrameTemplate`** et **`BasicFrameTemplateWithInset`** : existent (définis dans UIPanelTemplates.xml, où BasicFrameTemplate hérite de BaseBasicFrameTemplate, et BasicFrameTemplateWithInset hérite de BasicFrameTemplate). `BasicFrameTemplateWithInset` est très populaire pour les débutants : il fournit fond, bordure, barre de titre **et bouton de fermeture** (`frame.TitleText`, `frame.CloseButton`). Il est disponible en Classic Era — mais vérifie toujours en jeu, car Blizzard retire parfois des templates des clients Classic sans préavis : OptionsSliderTemplate, par exemple, a été retiré en 1.15.4 alors qu'il était toujours présent en Retail 11.0.2.
- **`UIPanelDialogTemplate`** : existe aussi (fenêtre style dialogue avec titre et close button), mais il gère le "UI panel system" de Blizzard, ce qui peut surprendre un débutant (positionnement automatique à gauche, fermeture avec Échap via UIPanelWindows).
- **Recommandation débutant** : commence avec `"BackdropTemplate"` seul pour comprendre la mécanique (c'est l'objet de ta capsule), puis essaie `"BasicFrameTemplateWithInset"` pour voir ce qu'un template prêt-à-l'emploi t'offre gratuitement.

> Sources : https://warcraft.wiki.gg/wiki/BackdropTemplate · https://www.wowinterface.com/forums/archive/index.php/t-40444.html · https://us.forums.blizzard.com/en/wow/t/optionsslidertemplate-in-classic-era/1968743

## 8. Exemple complet

**MyFrame.toc** :

```
## Interface: 11508
## Title: MyFrame
## Notes: Capsule 04 - Ma premiere frame
## Author: Toi
## Version: 1.0
## SavedVariables: MyFrameDB

MyFrame.lua
```

**MyFrame.lua** :

```lua
-- IMPORTANT : "BackdropTemplate" est OBLIGATOIRE en 1.15.x pour avoir SetBackdrop
-- (le systeme Backdrop a ete deplace dans un mixin en 9.0, retroporte en Classic 1.14.0)
-- On donne un nom global ("MyFrameWindow") : utile pour /fstack et la persistance de position
local frame = CreateFrame("Frame", "MyFrameWindow", UIParent, "BackdropTemplate")

-- 1) Taille et position : 400x300, centre de l'ecran
frame:SetSize(400, 300)              -- equivalent SetWidth(400) + SetHeight(300)
frame:SetPoint("CENTER")             -- raccourci de SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- 2) Fond + bordure : TOUJOURS SetBackdrop AVANT SetBackdropColor (regression 1.15.x sinon)
frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:SetBackdropColor(1, 1, 1, 1)        -- teinte du fond, valeurs 0-1 (pas 0-255)
frame:SetBackdropBorderColor(1, 1, 1, 1)  -- teinte de la bordure

-- 3) Strata : une fenetre de dialogue passe au-dessus de l'UI standard (MEDIUM)
frame:SetFrameStrata("DIALOG")

-- 4) Drag : la sequence canonique complete
frame:SetMovable(true)                       -- autorise le deplacement
frame:EnableMouse(true)                      -- OBLIGATOIRE : sans ca, OnDragStart ne tire jamais
frame:RegisterForDrag("LeftButton")          -- OBLIGATOIRE aussi
frame:SetClampedToScreen(true)               -- empeche de perdre la fenetre hors ecran
frame:SetScript("OnDragStart", frame.StartMoving)          -- la methode sert de handler
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)    -- re-ancre au point UIParent le plus proche

-- 5) Un petit titre pour verifier que tout marche
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("Ma premiere frame !")

-- 6) Cachee par defaut (les frames sont SHOWN a la creation)
frame:Hide()

-- 7) Commande slash /myframe : toggle show/hide
SLASH_MYFRAME1 = "/myframe"
SlashCmdList["MYFRAME"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
```

Le pattern drag est exactement celui de la page officielle "Making draggable frames" : SetMovable(true), EnableMouse(true), RegisterForDrag("LeftButton"), puis StartMoving dans OnDragStart et StopMovingOrSizing dans OnDragStop, et l'exemple officiel combine BackdropTemplate, SetPoint("CENTER"), SetSize et cette même séquence de drag.

## 9. Pièges courants (gotchas)

1. **`attempt to call method 'SetBackdrop' (a nil value)`** — le piège n°1 absolu en Classic Era moderne : tu as oublié `"BackdropTemplate"` dans CreateFrame. Depuis 1.14.0, le système Backdrop de 9.0 est rétroporté à toutes les variantes Classic. Les vieux tutos pré-2020 (et beaucoup de réponses d'IA !) montrent du code sans le template : il plantera.
2. **`SetBackdropColor` avant `SetBackdrop`** → erreur "table index is nil" due au backdropInfo interne non initialisé, apparue avec les builds 1.15.x récents. Ordre strict : SetBackdrop d'abord.
3. **Drag qui ne marche pas** : EnableMouse n'est pas automatiquement impliqué par OnDragStart, et RegisterForDrag est requis. Il faut les **trois** : SetMovable + EnableMouse + RegisterForDrag. Oublier n'importe lequel = frame immobile, sans aucun message d'erreur.
4. **Frame créée mais invisible** : pas de point d'ancrage et/ou pas de taille → pas de rect → rien à l'écran, alors que `IsShown()` dit true. Une frame a besoin (a) d'une taille (explicite ou déduite de 2+ ancres) ET (b) d'au moins un point.
5. **`SetSize` ignoré** : si la taille est déduite des ancres (SetAllPoints ou deux coins ancrés), SetSize n'a aucun effet.
6. **Frame "shown" mais cachée par son parent** : IsShown() peut être true alors qu'IsVisible() est false si un parent est caché. Vérifie la chaîne de parents avec `/fstack`.
7. **Frame qui revient à une position bizarre après /reload** : StartMoving active le flag "user placed", donc le client sauvegarde et restaure la position tout seul — ça entre en conflit avec ton propre code de sauvegarde de position. Soit tu laisses le client gérer (frame nommée + movable avant PLAYER_LOGIN), soit tu désactives avec `SetUserPlaced(false)` et tu gères via SavedVariables.
8. **Repositionnement qui étire la frame** : appeler SetPoint avec un nouveau point sans `ClearAllPoints()` ajoute une seconde ancre au lieu de remplacer — ClearAllPoints est typiquement utilisé avant SetPoint pour éviter les rects invalides ou textures déformées.
9. **Frame derrière tout le reste** : strata trop basse, ou même strata mais level inférieur. Les levels ne comptent qu'au sein d'une même strata — passe en `"DIALOG"` pour une fenêtre.
10. **Couleurs invisibles** : tu passes des valeurs 0–255 à SetBackdropColor au lieu de 0–1 — tout > 1 est clampé à 1, donc tout devient blanc/opaque.
11. **Pas de garbage collection** : les frames ne peuvent pas être supprimées ; réutilise-les au lieu d'en recréer (typique des bugs de "fenêtres dupliquées" après plusieurs ouvertures).

---

**Sources principales** : [API_CreateFrame](https://warcraft.wiki.gg/wiki/API_CreateFrame) · [BackdropTemplate](https://warcraft.wiki.gg/wiki/BackdropTemplate) · [API_Frame_SetBackdrop](https://warcraft.wiki.gg/wiki/API_Frame_SetBackdrop) · [API_Region_SetPoint](https://warcraft.wiki.gg/wiki/API_ScriptRegionResizing_SetPoint) · [Making draggable frames](https://warcraft.wiki.gg/wiki/Making_draggable_frames) · [API_Frame_StopMovingOrSizing](https://warcraft.wiki.gg/wiki/API_Frame_StopMovingOrSizing) · [API_ScriptRegion_IsShown](https://warcraft.wiki.gg/wiki/API_ScriptRegion_IsShown) · [Frame_Strata](https://warcraft.wiki.gg/wiki/Frame_Strata) · [Forum Blizzard : régression backdropInfo 1.15.x](https://eu.forums.blizzard.com/en/wow/t/590913)

Un conseil pour tester tout ça en jeu : `/fstack` (montre les frames sous le curseur, leur strata et leur level) et `/dump MyFrameWindow:GetPoint()` sont tes deux meilleurs amis pour cette capsule.