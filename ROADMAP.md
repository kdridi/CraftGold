# Roadmap — CraftGold

> Document unique de planification.

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

## Décisions architecturales

### Source de données pour les recettes

| Version | Approche | Justification |
|---------|----------|---------------|
| **v1** | Base de données statique (fichiers Lua) | L'API Trade Skill ne liste que les recettes apprises → impossible de planifier un leveling 1→300 sans DB. Engineering est borné, maintenance faible. |
| **v2 (roadmap)** | Hybride : DB statique + validation/surcharge par l'API | L'API sert de QA et enrichit les données live. |

**Règles de design :**
- Composants stockés en **itemID**, pas en nom
- DB structurée pour être overridable par l'API (passage v1→v2 sans rewrite)

### API WoW Classic Era

| API | Disponible en Classic Era ? | Notes |
|-----|----------------------------|-------|
| `C_TradeSkillUI.*` | ✅ Oui (version pré-10.0) | Ne liste que les recettes apprises |
| `C_AuctionHouse.*` | ❌ Non (Retail 8.3+ uniquement) | — |
| `QueryAuctionItems()` | ✅ Oui | Recherche par nom, pas par ID |
| `GetAuctionItemInfo()` | ✅ Oui | `buyoutPrice` = par stack, diviser par `count` |

Voir `prompts/research-wow-api-response.md` pour les détails complets.

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
| 09 | Item Info | `GetItemInfo()`, `GetItemInfoInstant()`, cache, callbacks | Semi-autonomous |
| 10 | Trade Skill API | `C_TradeSkillUI` (GetAllRecipeIDs, GetRecipeReagentInfo, etc.), événement TRADE_SKILL_LIST_UPDATE | Semi-autonomous |
| 11 | Auction House Scan | `QueryAuctionItems`, `GetAuctionItemInfo`, `AUCTION_ITEM_LIST_UPDATE`, throttling, prix par stack vs unité | Semi-autonomous |

## Phase 5 — Algorithme

> Objectif : implémenter le calcul récursif des coûts.

| # | Capsule | Concepts clés | Type |
|---|---------|---------------|------|
| 12 | Cost Calculator | Graphe, récursion, `min(buy, craft)`, cycles, memoization | Sequential (10, 11) |

## Phase 6 — Assemblage

> Objectif : assembler tous les composants dans CraftGold.

| # | Capsule | Concepts clés | Type |
|---|---------|---------------|------|
| 13 | CraftGold Final | DB statique Engineering, scan AH, calcul coûts, UI complète | Sequential (01-12) |

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

### Session 1 — Fondations & validation
- ✅ Discussion du concept CraftGold (calcul récursif des coûts)
- ✅ Double objectif défini : monter un métier au moindre coût + gagner de l'or en craftant
- ✅ Focus initial : Ingénierie sur WoW Classic Era
- ✅ Étude du workshop Playwright → reproduction du protocole pédagogique (Phases A/B/C)
- ✅ Création de AGENTS.md, README.md, ROADMAP.md
- ✅ Génération des 13 squelettes dans `00-todo/`
- ✅ Initialisation du dépôt git
- ✅ Test du Pattern 1 (recherche web) — API WoW Classic Era validée via Claude
  - `C_AuctionHouse` n'existe PAS en Classic Era → `QueryAuctionItems` + `GetAuctionItemInfo`
  - `C_TradeSkillUI` existe (version pré-10.0) mais ne liste que les recettes apprises
  - Interface version : 11508 (patch 1.15.8)
- ✅ Test du Pattern 2 (multi-agents) — Architecture recettes validée
  - **Décision : DB statique pour v1** (API seule ne permet pas le leveling planner)
  - **v2 roadmap : hybride** (DB statique + validation/surcharge par l'API)
  - Règle : stocker en itemID, structurer pour overridable
- ✅ Mise à jour des squelettes capsules 10 et 11 avec les bonnes API
- ✅ Phase 0 (capsule 01) : méga-prompt de recherche envoyé à ChatGPT, Claude, Gemini
- ✅ docs/ seedé avec 4 fichiers validés : toc-format, lua-basics-wow, addon-list-access, open-questions
- ✅ 3 désaccords identifiés (nécessitent vérification en jeu Phase B) :
  - `/reload` détecte nouveaux add-ons ? (Claude: oui, Gemini: non)
  - Chemin menu add-ons en jeu (Claude vs Gemini vs ChatGPT)
  - `print()` top-level visible dans le chat ? (Gemini: probablement non)

### Session 2 — Capsule 01 complétée
- ✅ Dépôt déplacé de AddOns/ vers ~/git/ + workflow symlink
- ✅ Phase A (storytelling + checklist) validée
- ✅ Phase B — Capsule 01 testée en jeu :
  - 4 questions ouvertes résolues (Q1-Q4 dans docs/open-questions.md)
  - Exploration du vararg `...`, du namespace `ns`, des événements
  - Ajout de `DumpTable()` pour inspecter les tables Lua
- ✅ Phase C — Polissage :
  - Convention linguistique mise à jour (docs en FR, code en EN, prompts futurs en FR)
  - docs/ traduites en français
  - `docs/wow-api-functions.md` créé (dictionnaire progressif des fonctions API)
  - Règle ajoutée : Phase A étape 4 = lister les fonctions API utilisées
  - README capsule traduit en français avec le déroulement réel

### Session 4 — Capsule 03 complétée
- ✅ Phase 0 (capsule 03) : recherche SavedVariables — 3 LLM consultés, consensus total
- ✅ `docs/saved-variables.md` créé (cycle de vie, sérialisation, patterns, gotchas)
- ✅ Phase A (storytelling + checklist) validée
- ✅ Phase B — Capsule 03 testée en jeu :
  - SavedVariables persistées à travers les `/reload`
  - Fichier `WTF/Account/.../SavedVariables/SavedVarsDemo.lua` observé
  - `_G.SavedVarsDemoDB` pour expliciter les globales
  - `ADDON_LOADED` se déclenche pour TOUS les add-ons (filtrage obligatoire)
- ✅ Consultation multi-agents (architecture) — 3 LLM consultés
  - **Décision : Functional Core / Imperative Shell**
  - `src/` : Core (pur), Style (pur), WoW (seam injectable), Logger (via seam), Test (in-game)
  - Règle d'or : Core doit charger en Lua pur
  - Architecture progressive : 5 modules (capsule 03) → +UI → +Data → +WoW seam étendu (capsule 10)
- ✅ Validation architecture auprès de 3 LLM (pratiques réelles : Questie, DBM, WeakAuras, Auctionator)
  - Notre architecture validée comme "plus propre que la moyenne"
  - wowmock = notre pattern packagé, wow-ui-sim pour tests intégration
  - Recommandation : luacheck + CI (plus tard)
- ✅ Style sémantique (`highlight`, `command`, `prefix`) au lieu de hex brut
- ✅ Logger séparé de Style (Style = forme, Logger = sortie)
- ✅ Seam `WoW.lua` avec fallbacks immuables (bug `WoW.init` corrigé suite à review)
- ✅ busted installé et configuré (`.busted`, `tests/helpers.lua`)
- ✅ 32 tests busted (24 Core + 4 Style + 3 Logger + 5 WoW) passant en Lua pur
- ✅ Tests in-game via `/svars test` (19 assertions, mêmes résultats que busted)
- ✅ Chemin AddOns ajouté dans AGENTS.md

### Session 5 — Capsule 04 complétée
- ✅ Phase 0 déjà complétée : recherche validée dans le code source Blizzard exporté (BlizzardInterfaceCode/)
- ✅ `docs/frames.md` créé (CreateFrame, Backdrop, ancres, drag, strata, templates, FontString, gotchas)
- ✅ `docs/capsule-04-index.md` créé (index de toutes les ressources documentaires)
- ✅ Phase A (storytelling + checklist) validée
- ✅ Phase B — Capsule 04 testée en jeu :
  - Frame visible avec fond sombre, bordure grise, titre
  - Drag fonctionnel (clic gauche + glisser)
  - `/myframe` toggle, `/myframe show/hide` explicite
  - **Gotcha vécu** : frame shown par défaut → premier toggle la cache au lieu de l'afficher
  - Fix : `frame:Hide()` à la fin de la création
- ✅ Phase C — README polis avec le vrai vécu (gotchas documentés)
