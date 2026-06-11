# Roadmap — CraftGold

> Document unique de planification.

---

## Vue d'ensemble

14 capsules progressives, chacune un mini-add-on indépendant, pour apprendre à créer des add-ons WoW tout en construisant CraftGold.

**6 phases :**

1. **Phase 1 — Bases** — Structure d'un add-on, événements, persistance
2. **Phase 2 — UI minimale** — Frames, boutons, texte (suffisant pour le MVP)
3. **Phase 3 — Cœur métier** — DB recettes, prix, calcul récursif des coûts
4. **Phase 4 — Données du jeu** — Items, Hôtel des Ventes
5. **Phase 5 — Produit MVP** — Affichage des résultats, premier moment magique
6. **Phase 6 — Extensions** — Scroll frame, leveling planner, polish

### Principe directeur

> **Données d'abord, interface ensuite.** On ne construit pas de widgets par spéculation. On apprend les widgets quand les données réelles les rendent nécessaires.

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

### Décision MVP (Session 7)

Source : consultation multi-agents (`prompts/multiagent-mvp-strategy.md`).

**Consensus 3/3 LLM :**
- La roadmap widgets-first était une erreur ("Widget-Trap")
- Ce qu'on sait faire (frames, boutons, texte) suffit pour le MVP
- Le calculateur récursif est le cœur du produit → à débloquer en premier
- Scroll frame, minimap, options → reportés après le MVP

**Ordre retenu :**
1. DB statique (10-20 recettes Engineering, Lua pur, testable busted)
2. Prix manuels via slash command (`/cg price`) + calculateur récursif
3. ItemInfo cache (noms lisibles)
4. Scan AH ciblé (automatisation des prix)
5. UI d'affichage (fenêtre simple, Top 10)

**Premier moment magique :**
```
/cg price 2840 12s40c       -- Copper Bar = 12s40c
/cg price 2589 3s10c        -- Linen Cloth = 3s10c
/cg price 4359 18s          -- Handful of Copper Bolts = 18s
/cg analyze

→ "Copper Modulator — Coût: 41s20c — Profit: 30s80c — Marge: 74%"
→ "Conseil: craft les Copper Bolts (12s40c) au lieu de les acheter (18s)"
```

---

## Phase 1 — Bases de la création d'add-on ✅

> Objectif : comprendre comment WoW charge et exécute un add-on.

| # | Capsule | Concepts clés | Type | Statut |
|---|---------|---------------|------|--------|
| 01 | Hello Azeroth | `.toc`, `.lua`, `print()`, `/reload` | Autonomous | ✅ |
| 02 | Slash Commands | `SLASH_*`, `SlashCmdList`, arguments, chat coloré | Autonomous | ✅ |
| 03 | Saved Variables | `SavedVariables` dans `.toc`, `ADDON_LOADED`, persistance | Autonomous | ✅ |

## Phase 2 — UI minimale ✅

> Objectif : créer des interfaces en jeu avec l'API Frame de WoW. Suffisant pour le MVP.

| # | Capsule | Concepts clés | Type | Statut |
|---|---------|---------------|------|--------|
| 04 | My First Frame | `CreateFrame()`, backdrop, position, fenêtre déplaçable | Autonomous | ✅ |
| 05 | Buttons & Text | `CreateFrame("Button", ...)`, `FontString`, `OnClick`, templates | Autonomous | ✅ |

## Phase 3 — Cœur métier

> Objectif : construire le moteur économique de CraftGold. Données et algorithme avant UI.

| # | Capsule | Concepts clés | Type | Statut |
|---|---------|---------------|------|--------|
| 06 | Recipe DB | DB statique Engineering (10-20 recettes), itemID, structures Lua, tests busted | Autonomous | 🔲 |
| 07 | Price & Calculator | Prix manuels (`/cg price`), formatage money (or/argent/cuivre), calculateur récursif `min(buy, craft)`, détection de cycles, mémoïsation | Autonomous | 🔲 |
| 08 | Analyze & Report | `/cg analyze`, Top N crafts rentables, affichage chat, détail recette avec arbre de décision buy vs craft | Autonomous | 🔲 |

## Phase 4 — Données du jeu

> Objectif : connecter CraftGold aux données réelles du jeu.

| # | Capsule | Concepts clés | Type | Statut |
|---|---------|---------------|------|--------|
| 09 | Item Info | `GetItemInfo()`, `GetItemInfoInstant()`, cache asynchrone, `GET_ITEM_INFO_RECEIVED`, fallback itemID si pas en cache | Semi-autonomous | 🔲 |
| 10 | AH Scanner | `QueryAuctionItems`, `GetAuctionItemInfo`, `AUCTION_ITEM_LIST_UPDATE`, pagination, throttling, prix par stack vs unité, scan ciblé des items de la DB | Semi-autonomous | 🔲 |

## Phase 5 — Produit MVP

> Objectif : assembler le premier CraftGold fonctionnel avec UI.

| # | Capsule | Concepts clés | Type | Statut |
|---|---------|---------------|------|--------|
| 11 | Profit Window | Fenêtre CraftGold, boutons Scan/Analyze, Top 10 crafts, détail recette, sélection | Sequential (07, 08) | 🔲 |

## Phase 6 — Extensions

> Objectif : enrichir CraftGold au-delà du MVP. Widgets apprism quand les données les rendent nécessaires.

| # | Capsule | Concepts clés | Type | Statut |
|---|---------|---------------|------|--------|
| 12 | Scroll Frame | `ScrollFrame`, `Slider`, button pooling — **uniquement si la liste dépasse l'écran** | Autonomous | 🔲 |
| 13 | Leveling Planner | Plan 1→300 optimal, seuils orange/jaune/vert/gris, quantités estimées, coût total | Sequential (06, 07) | 🔲 |
| 14 | CraftGold v1 | DB complète Engineering, intégration Trade Skill UI, minimap button, options, polish | Sequential (01-13) | 🔲 |

---

## Dépendances

```
01 → 02 → 03 → 04 → 05
                   ↓
               06 → 07 → 08 → 11
                ↓         ↑
               09 → 10 ───┘
               
Après MVP:
12 (quand la liste déborde)
13 (quand le profit fonctionne)
14 (assemblage final)
```

---

## Bilan

| Phase | Capsules | Statut |
|-------|----------|--------|
| Phase 1 — Bases | 3 | ✅ Terminé |
| Phase 2 — UI minimale | 2 | ✅ Terminé |
| Phase 3 — Cœur métier | 3 | 🔲 À faire |
| Phase 4 — Données du jeu | 2 | 🔲 À faire |
| Phase 5 — Produit MVP | 1 | 🔲 À faire |
| Phase 6 — Extensions | 3 | 🔲 À faire |
| **Total** | **14** | |

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

### Session 6 — Capsule 05 complétée
- ✅ `AGENTS.md` mis à jour : ajout du code source Blizzard exporté (`BlizzardInterfaceCode/`) comme source de vérité locale
- ✅ Phase 0 : toutes les réponses trouvées dans le code source Blizzard — pas besoin de prompt externe
  - `SimpleButtonAPIDocumentation.lua` : API complète des boutons
  - `SecureUIPanelTemplates.xml` / `Classic/SharedUIPanelTemplates.xml` : templates de boutons
  - `SecureUIPanelTemplates.lua` : handlers Lua des boutons
- ✅ `docs/buttons.md` créé (API complète, templates, RegisterForClicks, OnClick, exemples, gotchas)
- ✅ `docs/wow-api-functions.md` enrichi avec les fonctions boutons
- ✅ Phase A (storytelling + checklist) validée
- ✅ Phase B — Capsule 05 testée en jeu :
  - Fenêtre avec titre, status text, 3 boutons (Click Me / Reset / Toggle Info), bouton fermer X
  - Compteur de clics fonctionnel
  - Reset grisé au départ, activé après un clic, se re-grise après reset
  - Toggle Info montre/cache un bloc de texte coloré
  - `/btntest` et `/bt` fonctionnels
  - **Gotcha vécu** : `toggleBtn` nil dans le handler de Reset → forward declarations manquantes
  - **Gotcha vécu** : le symlink doit porter le nom de l'add-on (ButtonsAndText), pas du répertoire repo
  - Exploration SetPoint : chaîne d'ancrage, multi-ancrage, signe des offsets
- ✅ Phase C — README et code polis

### Session 7 — Pivot stratégique MVP
- ✅ Remise en question de la roadmap widgets-first
- ✅ Consultation multi-agents (`prompts/multiagent-mvp-strategy.md`) — 3 LLM consultés
  - **Consensus** : roadmap actuelle = "Widget-Trap" (apprendre des widgets par spéculation)
  - **Consensus** : ce qu'on sait faire (frames, boutons, texte) suffit pour le MVP
  - **Consensus** : calculateur récursif = cœur du produit, à débloquer en premier
- ✅ **Nouvelle roadmap** : données d'abord, interface ensuite
  - Phase 3 = cœur métier (DB recettes, prix manuels, calculateur récursif)
  - Phase 4 = données jeu (ItemInfo, scan AH)
  - Phase 5 = produit MVP (fenêtre résultats)
  - Phase 6 = extensions (scroll frame, leveling planner, polish)
- ✅ `docs/scroll-frames.md` créé (servira plus tard, phase 6)
### Session 8 — Capsule 06 complétée
- ✅ Phase 0 — Sources de données recettes Engineering
  - 4 LLM consultés (Claude, Gemini, ChatGPT, GitHub)
  - **Source retenue** : LibCrafts-1.0 (MIT) — DB Vanilla complète, itemIDs identiques en Classic Era
  - **CraftLib** (kaldown) identifié comme meilleur modèle de données mais licence All Rights Reserved
  - ItemIDs Vanilla 1.12 = Classic Era 1.15.x (consensus 4/4)
  - `docs/recipe-db-sources.md` créé
- ✅ Phase A (storytelling + checklist) validée
- ✅ Phase B — Capsule 06 testée en jeu :
  - 26 recettes Engineering (skill 1-150) en DB statique
  - 7 fonctions de requête dans Core.lua (getByOutput, getByReagent, getBySkill, etc.)
  - 19 tests busted + 82 assertions in-game
  - Fenêtre navigateur `/cgdb show` avec vrais noms d'items (GetItemInfo)
  - Tooltips avec détails recette, composants, qualité, tag (craftable)
- ✅ Recherche GetItemInfo cache — 4 LLM consultés
  - `GetItemInfo()` quasi-toujours synchrone en Classic Era (données DB2/CASC locales)
  - Supprimer `Cache/WDB/` ne suffit pas — les DB2 sont dans les archives du jeu
  - IDs Retail (210502) reproduisent le nil + événement `GET_ITEM_INFO_RECEIVED` avec `success=false`
  - `docs/getiteminfo-cache.md` créé
- ✅ Recherche architecture UI — 4 LLM consultés
  - **Pattern retenu** : Component Mixin + `ContinueOnItemLoad` (fourni par Blizzard)
  - `ContinueOnItemLoad` disponible en Classic Era (vérifié dans `Blizzard_ObjectAPI/Classic/Item.lua`)
  - UI.lua réécrit : chaque RecipeLine est un composant autonome
  - Plus d'index externe `itemToTexts` — création et mise à jour au même endroit
  - `docs/ui-architecture.md` créé (patterns évalués, recommandations futures)
  - `docs/wow-api-functions.md` enrichi avec GetItemInfo, ContinueOnItemLoad, Mixin
- ✅ Phase C — README et docs polis
- ⬜ Prochaine capsule : **07 — Price & Calculator**
