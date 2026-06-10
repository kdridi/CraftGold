# Capsule 04 — My First Frame : Index de documentation

> Ce fichier liste toutes les ressources documentaires nécessaires pour préparer et implémenter la capsule 04.
> Toutes les informations ont été vérifiées dans le code source Blizzard exporté (`BlizzardInterfaceCode`).

---

## Docs du projet (`docs/`)

| Fichier | Contenu | Pertinence |
|---------|---------|------------|
| `docs/frames.md` | **Doc principale de la capsule 04** — CreateFrame, taille, position, Backdrop, drag, show/hide, strata, templates, fontstrings, gotchas | 🔴 Essentiel |
| `docs/wow-api-functions.md` | Dictionnaire progressif des fonctions API — mis à jour avec toutes les fonctions Frame | 🔴 Essentiel |
| `docs/lua-basics-wow.md` | Bases du Lua dans WoW — portée, cycle de chargement, erreurs | 🟡 Rappel |
| `docs/toc-format.md` | Format du fichier .toc | 🟡 Rappel |
| `docs/slash-commands.md` | Slash commands — déjà vu en capsule 02 | 🟡 Rappel |
| `docs/saved-variables.md` | SavedVariables — déjà vu en capsule 03 | 🟢 Optionnel |
| `docs/open-questions.md` | Questions résolues des capsules précédentes | 🟢 Optionnel |

## Code source Blizzard de référence

Tous les chemins sont relatifs à `BlizzardInterfaceCode/Interface/AddOns/`.

| Fichier | Ce qu'il contient | Pourquoi c'est utile |
|---------|-------------------|---------------------|
| `Blizzard_SharedXML/Backdrop.lua` | BackdropTemplateMixin + tous les backdrops prédéfinis (`BACKDROP_*`) | Comprendre comment le backdrop fonctionne |
| `Blizzard_SharedXML/Backdrop.xml` | Template XML `BackdropTemplate` | Confirme le mixin et les scripts |
| `Blizzard_UIPanelTemplates/Classic/UIPanelTemplates.xml` | `BaseBasicFrameTemplate`, `BasicFrameTemplate`, `BasicFrameTemplateWithInset` | Templates de fenêtre |
| `Blizzard_SharedXML/SharedBasicControls.xml` | `UIPanelDialogTemplate` | Template de dialogue |
| `Blizzard_SharedXML/Classic/SharedUIPanelTemplates.lua` | `ClickToDragMixin` — pattern de drag canonique | Voir comment Blizzard fait le drag |
| `Blizzard_Fonts_Shared/Shared/FontStyles.xml` | Définitions de `GameFontNormal`, `GameFontNormalLarge`, etc. | Fonts disponibles |
| `Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua` | Toutes les méthodes des frames | Référence complète |
| `Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua` | `SetSize`, `SetPoint`, `SetWidth`, `SetHeight`, `ClearAllPoints` | API de position/taille |

## Ressources externes validées

| URL | Contenu |
|-----|---------|
| https://warcraft.wiki.gg/wiki/API_CreateFrame | Doc CreateFrame |
| https://warcraft.wiki.gg/wiki/BackdropTemplate | Doc BackdropTemplate |
| https://warcraft.wiki.gg/wiki/Making_draggable_frames | Pattern de drag officiel |
| https://warcraft.wiki.gg/wiki/API_Region_SetPoint | Doc SetPoint |

## Points validés sans ambiguïté

1. ✅ `BackdropTemplate` est **obligatoire** — `SetBackdrop` n'existe pas sur les frames nues en 1.15.x
2. ✅ `SetBackdrop()` doit être appelé **avant** `SetBackdropColor()` (régression 1.15.x)
3. ✅ 9 points d'ancrage (TOPLEFT…BOTTOMRIGHT)
4. ✅ `SetSize(w, h)` existe en Classic Era
5. ✅ Séquence drag : `SetMovable` + `EnableMouse` + `RegisterForDrag` + `StartMoving`/`StopMovingOrSizing`
6. ✅ Frames sont `shown` par défaut après `CreateFrame`
7. ✅ `IsShown()` ≠ `IsVisible()`
8. ✅ Frames non garbage-collectables
9. ✅ `parent = nil` ne donne pas `UIParent`
10. ✅ `SetBackdropColor` plage 0–1, pas 0–255
11. ✅ 17 backdrops prédéfinis (`BACKDROP_DIALOG_32_32`, etc.)
12. ✅ `BasicFrameTemplate` existe en Classic Era (avec `TitleText` + `CloseButton`)
13. ✅ `UIPanelDialogTemplate` existe en Classic Era
14. ✅ `GameFontNormal`, `GameFontNormalLarge`, `GameFontHighlight` existent
