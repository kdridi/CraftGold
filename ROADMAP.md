# Roadmap — CraftGold

> Document unique de planification.

---

## Vue d'ensemble

21 capsules progressives, chacune un mini-add-on indépendant, pour apprendre à créer des add-ons WoW tout en construisant CraftGold.

**6 phases :**

1. **Phase 1 — Bases** — Structure d'un add-on, événements, persistance
2. **Phase 2 — UI minimale** — Frames, boutons, texte (suffisant pour le MVP)
3. **Phase 3 — Cœur métier** — DB recettes, prix, calculateur récursif
4. **Phase 4 — Données réelles** — Modèle listings, DP knapsack, scanner AH
5. **Phase 5 — Produit MVP** — Profit analyzer v2, fenêtre de résultats
6. **Phase 6 — Leveling planner** — Probabilités de skill-up, plan optimal, panier réel

### Principe directeur

> **Données d'abord, interface ensuite.** On ne construit pas de widgets par spéculation. On apprend les widgets quand les données réelles les rendent nécessaires.

### Double objectif

1. **Monter un métier au moindre coût** — Calculer le chemin optimal pour monter Engineering de 0 à 300, en tenant compte des prix réels de l'HdV (stacks indivisibles) et des probabilités de skill-up (orange/jaune/vert/gris).
2. **Identifier les crafts rentables** — Achat de composants → fabrication → revente HdV, avec coût réel exact via DP covering knapsack.

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

### Stacks HdV — indivisibles (validé Session 9)

En Classic Era, un buyout achète le **listing entier** — pas d'achat fractionnaire. L'achat fractionnaire n'existe qu'en Retail (patch 8.3). Consensus 4/4 LLM + sources API.

Conséquence : le coût d'achat pour une quantité Q est un **covering knapsack 0/1**, résolu exactement par DP.

### Décision MVP (Session 7)

Source : consultation multi-agents (`prompts/multiagent-mvp-strategy.md`).

**Consensus 3/3 LLM :**
- La roadmap widgets-first était une erreur ("Widget-Trap")
- Ce qu'on sait faire (frames, boutons, texte) suffit pour le MVP
- Le calculateur récursif est le cœur du produit → à débloquer en premier
- Scroll frame, minimap, options → reportés après le MVP

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
| 04 | My First Frame | `CreateFrame()`, backdrop, position, venêtre déplaçable | Autonomous | ✅ |
| 05 | Buttons & Text | `CreateFrame("Button", ...)`, `FontString`, `OnClick`, templates | Autonomous | ✅ |

## Phase 3 — Cœur métier ✅

> Objectif : construire le moteur économique de CraftGold. Données et algorithme avant UI.

| # | Capsule | Concepts clés | Type | Statut |
|---|---------|---------------|------|--------|
| 06 | Recipe DB | DB statique Engineering (10-20 recettes), itemID, structures Lua, tests busted | Autonomous | ✅ |
| 07 | Price & Calculator | Prix manuels (`/cg price`), formatage money, calculateur récursif `min(buy, craft)`, cycles, mémoïsation | Autonomous | ✅ |
| 08 | Analyze & Report | Module Report séparé, `/cg analyze [N]`, `/cg detail`, arbre récursif buy vs craft | Autonomous | ✅ |

## Phase 4 — Données réelles

> Objectif : passer du modèle simpliste (1 prix/item) au modèle réel (listings HdV indivisibles, DP knapsack).

| # | Capsule | Concepts clés | Type | Statut |
|---|---------|---------------|------|--------|
| 09 | Item Info | `GetItemInfo()`, `GetItemInfoInstant()`, cache asynchrone, `GET_ITEM_INFO_RECEIVED`, fallback itemID | Semi-autonomous | ✅ |
| 10 | Manual Listings | Remplacer `price[item]` par `listings[item] = {{count, buyout}, …}`, saisie manuelle `/cg listing add`, prix par stack vs unité | Autonomous | 🔲 |
| 11 | Quote DP | DP covering knapsack 0/1 exact, `quote(itemID, quantity)`, reconstruction du panier, surplus | Autonomous | 🔲 |
| 12 | Bill of Materials | Expansion récursive d'un craft en quantités agrégées de matières premières, `/cg shoplist` | Autonomous | 🔲 |
| 13 | Buy vs Craft v2 | Refonte du calculateur avec `quote(itemID, qty)` au lieu de prix unitaire, `/cg analyze` mis à jour | Autonomous | 🔲 |
| 14 | AH Scanner v1 | `QueryAuctionItems`, filtrage par itemID, événement `AUCTION_ITEM_LIST_UPDATE`, scan d'un item | Semi-autonomous | 🔲 |
| 15 | AH Scanner v2 | Pagination (50 résultats/page), throttling, file d'attente, fraîcheur des données | Semi-autonomous | 🔲 |

## Phase 5 — Produit MVP

> Objectif : assembler CraftGold avec les vrais coûts et une UI.

| # | Capsule | Concepts clés | Type | Statut |
|---|---------|---------------|------|--------|
| 16 | Profit Analyzer v2 | `/cg analyze` refondu avec coûts exacts via DP, prix de vente estimé | Semi-autonomous | 🔲 |
| 17 | Profit Window | Fenêtre CraftGold, bouton Scan/Analyze, Top 10 crafts, sélection, détail | Sequential (11, 13) | 🔲 |

## Phase 6 — Leveling Planner

> Objectif : plan optimal pour monter un métier au moindre coût.

| # | Capsule | Concepts clés | Type | Statut |
|---|---------|---------------|------|--------|
| 18 | Skill Difficulty | Seuils orange/jaune/vert/gris par recette, `p(recipe, skill)` interchangeable, espérance géométrique `1/p` | Autonomous | 🔲 |
| 19 | Leveling DP | DP plus court chemin skill 0→300, plan affiché avec coût espéré par segment | Autonomous | 🔲 |
| 20 | Shopping List | Panier global du plan + cotation réelle via DP knapsack + marge de sécurité sur recettes non-orange | Sequential (11, 19) | 🔲 |
| 21 | CraftGold v1 | DB complète Engineering, intégration Trade Skill UI, polish | Sequential (01-20) | 🔲 |

---

## Dépendances

```
01 → 02 → 03 → 04 → 05
                   ↓
               06 → 07 → 08
                       ↓
                       09
                       ↓
            10 → 11 → 12 → 13 → 14 → 15 → 16 → 17
                   ↓                              ↑
                   └──────────────────────────────┘
                   
            18 → 19 → 20 → 21
             ↑         ↑
            09       11, 13
```

---

## Bilan

| Phase | Capsules | Statut |
|-------|----------|--------|
| Phase 1 — Bases | 3 | ✅ Terminé |
| Phase 2 — UI minimale | 2 | ✅ Terminé |
| Phase 3 — Cœur métier | 3 | ✅ Terminé |
| Phase 4 — Données réelles | 7 | 🔄 En cours (09 fait, 10-15 à faire) |
| Phase 5 — Produit MVP | 2 | 🔲 À faire |
| Phase 6 — Leveling Planner | 4 | 🔲 À faire |
| **Total** | **21** | |

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

### Session 9 — Capsule 07 + Refonte roadmap
- ✅ Capsule 07 (Price & Calculator) implémentée et testée en jeu :
  - Module Money : parse/format or/argent/cuivre
  - Module Prices : stockage itemID → copper (SavedVariables)
  - Module Calculator : récursif `min(buy, craft)`, cycles, mémoïsation
  - Commandes `/cg price|cost|analyze`, tests busted 40/40, tests in-game OK
  - Commande `/cg savings` retirée (redondante avec les tips de `/cg analyze`)
- ✅ Règle ajoutée dans AGENTS.md : confirmation obligatoire au début de chaque session
- ✅ Consultation multi-agents sur le problème des prix réels HdV (`prompts/multiagent-ah-pricing-problem.md`)
  - 4 LLM consultés (Claude, Gemini, ChatGPT, Copilot)
  - **Consensus** : le prix devient `quote(itemID, quantity)` (fonction, pas nombre)
  - **Consensus** : DP covering knapsack 0/1 pour le coût exact
  - **Consensus** : aucun add-on existant (TSM, Auctionator) ne résout ce problème
  - **Consensus** : leveling planner = DP backward O(300 × nbRecettes)
  - **Désaccord** : glouton vs DP (Copilot suppose achat fractionnaire — erreur factuelle)
- ✅ Consultation suivi : stacks indivisibles vs fractionnaires (`prompts/research-ah-stack-divisibility.md`)
  - **Consensus 4/4** : stacks indivisibles en Classic Era (Option B)
  - Source : API `PlaceAuctionBid` sans paramètre quantité, achat fractionnaire = nouveauté Retail 8.3
  - Algorithme recommandé : DP 0/1 exact (Claude, ChatGPT, Gemini) vs unbounded (Copilot — erreur)
- ✅ **Roadmap révisée** : 21 capsules (08→21)
  - Phase 4 nouvelle : Manual Listings → Quote DP → Bill of Materials → Buy vs Craft v2
  - AH Scanner en 2 capsules (v1 simple + v2 pagination)
  - Leveling Planner en 3 capsules (Skill Difficulty → Leveling DP → Shopping List)
  - Inspirée des meilleures propositions de chaque LLM

### Session 10 — Capsule 08 complétée
- ✅ Capsule 08 (Analyze & Report) implémentée et testée en jeu :
  - Module `Report.lua` extrait du shell monolithique de la capsule 07
  - `/cg analyze [N]` — Top N paramétrable (défaut : tous)
  - `/cg detail <itemID>` — rapport complet avec arbre récursif buy vs craft
  - `/cg cost` → alias de `/cg detail`
  - Shell réduit de ~300 à ~80 lignes
- ✅ **Phase 3 complétée** (DB + Prix + Calculateur + Report)
- ✅ Pas de Phase 0 nécessaire (aucune nouvelle API WoW)
- ✅ Pas de pitfall rencontré — tout passé du premier coup

### Session 11 — Capsule 09 complétée
- ✅ Capsule 09 (Item Info) implémentée et testée en jeu :
  - Module `ItemInfo.lua` : API centralisée pour tout accès aux données d'items (12 fonctions)
  - Exploration des API `C_Item.*` : `GetItemNameByID`, `IsItemDataCachedByID`, `GetItemQualityByID`, `GetItemIconByID`, `RequestLoadItemDataByID`
  - `/iteminfo <id>` : inspection complète d'un item (instant data, cache status, full info, async callback)
  - `/iteminfo scan` : scan de tous les items de la DB Engineering avec statut cache
  - `/iteminfo test` : tests unitaires du module ItemInfo
- ✅ Refactoring : `Report.lua` et le shell n'appellent plus `GetItemInfo()` directement → tout passe par `ns.ItemInfo`
- ✅ Phase 0 : pas de prompt externe nécessaire — code source Blizzard + docs existantes suffisantes
- ✅ `docs/wow-api-functions.md` enrichi avec les fonctions `C_Item.*` et l'événement `ITEM_DATA_LOAD_RESULT`
- ✅ Découvertes en jeu :
  - `C_Item.*` partage le même cache que `GetItemInfo()`
  - En Classic Era, le cache se charge quasi-instantanément (entre deux commandes chat)
  - `GetItemInfoInstant` retourne `nil` pour un itemID invalide
  - Le callback async `onLoad` se déclenche rarement en pratique
- ✅ Pitfall : tests localisation-dépendants (hardcodé "Copper Bar") → fix avec `GetItemInfo()` dynamique
