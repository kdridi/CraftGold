# Roadmap — CraftGold

> Document unique de planification. Remplace l'ancien PLAN-FORMATION.md et TUTORIALS.md.

---

## Vue d'ensemble

13 capsules progressives, chacune un mini-add-on indépendant, pour apprendre à créer des add-ons WoW tout en construisant CraftGold.

**6 phases :**

1. **Phase 1 — Bases** — Structure d'un add-on, événements, persistance
2. **Phase 2 — Interface** — Frames, boutons, listes scrollables
3. **Phase 3 — Intégration** — Minimap, options panel
4. **Phase 4 — Données du jeu** — Items, recettes, Hôtel des Ventes
5. **Phase 5 — Algorithme** — Calcul récursif des coûts
6. **Phase 6 — Assemblage** — Intégration finale de CraftGold

---

## Phase 1 — Bases de la création d'add-on

> Objectif : comprendre comment WoW charge et exécute un add-on.

| # | Capsule | Concepts clés | Type |
|---|---------|---------------|------|
| 01 | Hello Azeroth | `.toc`, `.lua`, `print()`, `/reload` | Autonomous |
| 02 | Slash Commands | `SLASH_*`, `SlashCmdList`, arguments, chat coloré | Autonomous |
| 03 | Saved Variables | `SavedVariables` dans `.toc`, `ADDON_LOADED`, persistance | Autonomous |

## Phase 2 — Interface graphique

> Objectif : créer des interfaces en jeu avec l'API Frame de WoW.

| # | Capsule | Concepts clés | Type |
|---|---------|---------------|------|
| 04 | My First Frame | `CreateFrame()`, backdrop, position, fenêtre déplaçable | Autonomous |
| 05 | Buttons & Text | `CreateFrame("Button", ...)`, `FontString`, `OnClick`, templates | Autonomous |
| 06 | Scroll Frame | `ScrollFrame`, `Slider`, pool de boutons, liste dynamique | Autonomous |

## Phase 3 — Intégration au jeu

> Objectif : intégrer l'add-on dans l'interface existante de WoW.

| # | Capsule | Concepts clés | Type |
|---|---------|---------------|------|
| 07 | Minimap Button | Bouton minimap, position angulaire, tooltip, icône | Autonomous |
| 08 | Options Panel | `InterfaceOptions_AddCategory()`, checkboxes, sliders | Autonomous |

## Phase 4 — Données du jeu

> Objectif : récupérer et manipuler les données du jeu.

| # | Capsule | Concepts clés | Type |
|---|---------|---------------|------|
| 09 | Item Info | `GetItemInfo()`, cache, callbacks de chargement | Semi-autonomous |
| 10 | Trade Skill API | `C_TradeSkillUI`, recettes, reagents, arbre de fabrication | Semi-autonomous |
| 11 | Auction House Scan | `C_AuctionHouse`, scan, callbacks, tableau de prix | Semi-autonomous |

## Phase 5 — Algorithme

> Objectif : implémenter le calcul récursif des coûts.

| # | Capsule | Concepts clés | Type |
|---|---------|---------------|------|
| 12 | Cost Calculator | Graphe, récursion, `min(buy, craft)`, cycles, memoization | Sequential (10, 11) |

## Phase 6 — Assemblage

> Objectif : assembler tous les composants dans CraftGold.

| # | Capsule | Concepts clés | Type |
|---|---------|---------------|------|
| 13 | CraftGold Final | Scan AH → calcul → UI, intégration complète | Sequential (01-12) |

---

## Dépendances

```
01 → 02 → 03 → 04 → 05 → 06 → 07 → 08
                   ↓
                   09 → 10 → 11
                            ↓
                           12
                            ↓
                           13
```

---

## Bilan

| Phase | Capsules | Durée estimée |
|-------|----------|---------------|
| Phase 1 — Bases | 3 | ~1,5-3h |
| Phase 2 — Interface | 3 | ~1,5-3h |
| Phase 3 — Intégration | 2 | ~1-2h |
| Phase 4 — Données | 3 | ~1,5-3h |
| Phase 5 — Algorithme | 1 | ~1h |
| Phase 6 — Assemblage | 1 | ~1h |
| **Total** | **13** | **~7-13h** |

---

## Historique des sessions

### Session 1 — Fondations
- ✅ Discussion du concept CraftGold (calcul récursif des coûts)
- ✅ Double objectif défini : monter un métier au moindre coût + gagner de l'or en craftant
- ✅ Focus initial : Ingénierie sur WoW Classic Era
- ✅ Étude du workshop Playwright → reproduction du protocole pédagogique (Phases A/B/C)
- ✅ Création de AGENTS.md, README.md, ROADMAP.md
- ✅ Génération des 13 squelettes dans `00-todo/`
- ✅ Initialisation du dépôt git
