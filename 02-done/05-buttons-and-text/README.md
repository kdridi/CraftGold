# 05 — Buttons & Text

| Metadata      | Value                                                              |
|---------------|--------------------------------------------------------------------|
| Phase         | Phase 2                                                            |
| Duration      | 30 min                                                             |
| Difficulty    | ●●●○○ (3/5)                                                       |
| Prerequisites | Capsule 04 — My First Frame                                        |
| Type          | Autonomous                                                         |
| Concepts      | `CreateFrame("Button", ...)`, `FontString`, `OnClick`, templates   |

## Why This Capsule?

Dans la capsule 04, on a construit notre première fenêtre — un cadre déplaçable avec titre, fond et bordure. Mais une fenêtre vide ne sert à rien. En vrai, une fenêtre sert à afficher du contenu et à interagir avec l'utilisateur. C'est là qu'interviennent les **boutons** et le **texte**.

Dans CraftGold, on aura besoin de boutons partout : valider un scan de l'HdV, lancer un calcul de coût, naviguer entre les recettes, fermer les fenêtres. Et le texte (`FontString`) est le moyen d'afficher des informations (coûts, noms d'items, stats).

Cette capsule nous apprend à créer des boutons cliquables avec les templates Blizzard, afficher du texte dynamique, et réagir aux clics. On construit une petite fenêtre interactive avec plusieurs boutons qui modifient un texte.

## Objectifs

1. **Créer** des boutons interactifs avec `UIPanelButtonTemplate` et `UIPanelCloseButton`
2. **Afficher** du texte dynamique avec `CreateFontString()` et `SetText()`
3. **Réagir** aux clics avec `OnClick` et modifier l'interface en réponse
4. **Désactiver/réactiver** des boutons avec `Disable()`/`Enable()`

## Concepts clés

### Boutons — `CreateFrame("Button", ...)`

Un bouton est un type de frame avec des états visuels (normal, survolé, pressé, désactivé). Blizzard fournit des templates prêts à l'emploi :

- **`UIPanelButtonTemplate`** — Bouton standard avec textures, fonts et highlight. Hérite de `UIPanelButtonNoTooltipTemplate`. Taille par défaut : 40×22.
- **`UIPanelCloseButton`** — Bouton X de 32×32. Son handler par défaut cache le parent.

### Chaîne d'ancrage

Les éléments sont ancrés les uns sur les autres en cascade :

```
mainFrame
  └─ title           → ancré sur mainFrame
      └─ statusText  → ancré sur title
          └─ clickBtn  → ancré sur statusText
              └─ resetBtn  → ancré sur clickBtn
                  └─ toggleBtn  → ancré sur resetBtn
                      └─ infoText  → ancré sur toggleBtn
```

Avantage : déplacer un élément déplace toute la chaîne en dessous. Inconvénient : il faut le savoir quand on debug.

### SetPoint — les 9 points d'ancrage

Chaque widget a 9 points (`TOPLEFT`, `TOP`, `TOPRIGHT`, `LEFT`, `CENTER`, `RIGHT`, `BOTTOMLEFT`, `BOTTOM`, `BOTTOMRIGHT`). `SetPoint` dit : "Prends le point X de mon widget et colle-le sur le point Y du widget parent, avec un décalage."

On peut ancrer deux points opposés pour étirer un widget (multi-ancrage). Dans ce cas, `SetSize()` est ignoré.

### Forward declarations

Les handlers `OnClick` sont des fonctions qui ne s'exécutent qu'au clic. Mais si un handler référence une variable locale qui n'est pas encore définie, Lua crashera au runtime. Solution : déclarer toutes les variables partagées en upvalues en haut du fichier.

## Fonctions API utilisées

| Fonction | Description |
|----------|-------------|
| `CreateFrame("Button", name, parent, template)` | Crée un bouton — type de frame avec états visuels |
| `button:SetText(text)` | Définit le texte affiché sur le bouton |
| `button:SetScript("OnClick", fn)` | Handler de clic : `function(self, button, down)` |
| `button:SetEnabled(bool)` | Active ou désactive le bouton |
| `frame:CreateFontString(nil, layer, font)` | Crée un texte dans une frame |
| `fontString:SetText(text)` | Change le texte affiché |
| `fontString:SetJustifyH("LEFT")` | Aligne le texte horizontalement |
| `fontString:SetWidth(w)` | Définit la largeur (permet le wrapping) |

## Exécution

1. Copier (ou symlink) le dossier dans `Interface/AddOns/`
2. `/reload` en jeu
3. `/btntest` ou `/bt` dans le chat

## Résultat attendu

Une fenêtre avec :
- Un titre "Buttons & Text Demo"
- Un texte "Clicks: 0" qui s'incrémente
- Un bouton **"Click Me"** qui incrémente le compteur
- Un bouton **"Reset"** (grisé au départ) qui remet à 0
- Un bouton **"Toggle Info"** qui montre/cache un bloc de texte
- Un bouton **X** en haut à droite pour fermer

## Pièges rencontrés (gotchas)

1. **`toggleBtn` is nil** — Le handler de Reset référençait `toggleBtn` avant sa déclaration. Les variables `local` en Lua ne sont pas hoisted comme en JavaScript. Fix : forward declarations en upvalues.
2. **Le nom du symlink** — Le dossier dans `Interface/AddOns/` doit porter le même nom que le fichier .toc/.lua (ici `ButtonsAndText`), pas le nom du répertoire dans le repo (`05-buttons-and-text`).
3. **Frames shown par défaut** — Sans `mainFrame:Hide()` à la fin, la frame est visible au chargement et le premier `/btntest` la cache au lieu de l'afficher.

## Going Further

- → Capsule suivante : **06 — Scroll Frame** (listes dynamiques scrollables)
