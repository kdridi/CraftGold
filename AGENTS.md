# Consignes Agent — CraftGold

## Contexte du projet

**CraftGold** est un add-on World of Warcraft Classic Era (focus initial : Ingénierie) qui poursuit deux objectifs :

1. **Monter un métier au moindre coût** — Déterminer les crafts optimaux et les matériaux les moins chers pour monter de 1 à N
2. **Gagner de l'or en craftant** — Identifier les crafts rentables (achat de mats → fabrication → revente HdV)

Le cœur technique est un **calcul récursif des coûts** : pour chaque composant fabricable, on descend dans l'arbre et on choisit le chemin le moins cher entre acheter directement et fabriquer à partir de sous-composants.

Ce projet a un **double but** : produire un add-on fonctionnel ET apprendre à créer des add-ons WoW.

## Mode de travail — Protocole en 3 phases (+ phase de recherche)

### Phase 0 — Recherche pré-capsule (validation des faits)

**Avant chaque capsule**, l'agent identifie tout ce qu'il « sait » ou « suppose » pour cette capsule et génère un **méga-prompt de vérification**. Ce prompt couvre toutes les connaissances nécessaires : API, syntaxe Lua, comportements en jeu, exemples d'add-ons existants.

1. L'agent liste ses hypothèses pour la capsule
2. L'agent rédige un prompt exhaustif à copier dans Claude/Gemini
3. L'utilisateur copie le prompt, récupère les réponses
4. L'utilisateur rapporte les réponses
5. L'agent traite les réponses, extrait les faits validés, identifie les corrections
6. L'agent crée ou met à jour les fichiers dans `docs/` (base de connaissances validée)
7. **Ce n'est qu'après cette étape** qu'on entre dans la Phase A (storytelling + checklist)

**Règle** : les capsules sont construites depuis `docs/`, pas depuis le dataset de l'agent. Le dataset sert d'inspiration pour le parcours pédagogique ; `docs/` est la source de vérité pour les faits techniques.

#### Répertoire `docs/`

La base de connaissances validée du projet. Chaque fichier couvre un sujet :
- `docs/toc-format.md` — Format du fichier .toc
- `docs/lua-basics-wow.md` — Bases du Lua spécifiques à WoW
- `docs/wow-api-functions.md` — Dictionnaire des fonctions API WoW rencontrées au fil des capsules
- `docs/events.md` — Système d'événements WoW
- etc.

Chaque doc contient du **code testable** et des **exemples concrets** — pas de la théorie abstraite.

### Phase A — Conception (on discute, zéro fichier)

On valide 6 points :

#### Étape 0 — Mise en scène (storytelling)

L'agent raconte la capsule en story simple : où on en est, quel problème on va rencontrer, ce qu'on va apprendre, pourquoi maintenant, à quoi ça servira plus tard. **La mise en scène atterrit dans le README** sous `## Why This Capsule?`.

#### Étapes 1-5 — Checklist technique

| Étape | Question |
|-------|----------|
| 1 | Objectifs observables (2-4 verbes d'action) |
| 2 | Critères de réussite (ce qu'on voit quand ça marche) |
| 3 | Prérequis & limites (frontière explicite) |
| 4 | **Fonctions API utilisées** (liste des fonctions WoW utilisées avec une explication courte — l'apprenant doit comprendre chaque fonction avant de coder) |
| 5 | Plan du code (sections du .lua dans l'ordre) |
| 6 | Plan du README (points à documenter) |

🔒 **Aucun fichier généré en Phase A.**

### Phase B — Exploration pas-à-pas (l'apprenant fait)

L'agent **guide** : « crée ce fichier avec ce contenu », « copie le dossier dans `Interface/AddOns/` », « `/reload` dans le chat, tape `/monaddon` ».

- L'apprenant exécute, observe, fait des retours
- Si ça ne marche pas comme prévu → on creuse, on ne rationalise pas, on corrige
- L'agent ne produit pas les fichiers — il guide pour que l'apprenant les crée

**Workflow de test :**
1. Copier le dossier capsule dans `Interface/AddOns/`
2. `/reload` en jeu (ou relancer WoW)
3. Vérifier dans Échap → Système → Addons
4. Tester le comportement
5. `/console scriptErrors 1` pour voir les erreurs Lua

### Phase C — Polissage (l'agent finalise)

1. Intégrer la mise en scène dans le README
2. Ajouter les commentaires pédagogiques dans le code (en anglais)
3. Reformater et organiser le code
4. Écrire le README reflétant le vrai vécu (pitfalls rencontrés, ordre réel des choses)
5. L'apprenant relit et valide

## Conventions linguistiques

| Élément | Langue |
|---|---|
| AGENTS.md, ROADMAP.md, README.md (racine) | 🇫🇷 Français |
| README.md des capsules | 🇫🇷 Français |
| docs/ (toute la base de connaissances) | 🇫🇷 Français |
| Nos discussions | 🇫🇷 Français |
| Prompts de recherche (futurs) | 🇫🇷 Français |
| Code Lua (fonctions, variables, commentaires) | 🇬🇧 Anglais |
| Noms de fichiers et répertoires | 🇬🇧 Anglais |
| Prompts existants (prompts/) | 🇬🇧 Anglais (laissés tels quels) |

## Recherche et validation externe

Pi Coding Agent n'a pas un accès web fiable. Pour toute recherche ou prise de décision importante, l'agent doit **produire des prompts** que l'utilisateur copiera dans d'autres LLM (Claude, Gemini, etc.) puis rapportera les réponses.

### Pattern 1 — Recherche web (info technique)

Quand l'agent a besoin d'informations factuelles (API WoW, syntaxe Lua, comportement d'une fonction, exemples d'add-ons existants), il génère un prompt de recherche :

1. L'agent rédige un prompt clair et ciblé pour un LLM avec accès web
2. L'utilisateur le copie dans Claude / Gemini / autre
3. L'utilisateur rapporte la réponse
4. L'agent intègre l'information et lève l'ambiguïté

**Déclencheur** : à la moindre hésitation sur un fait technique, une API, un comportement en jeu — ne pas deviner, demander.

### Pattern 2 — Consultation multi-agents (décision architecturale)

Quand l'agent doit prendre une décision de conception (architecture, UX, choix entre plusieurs approches), il génère un prompt pour une consultation multi-agents :

1. L'agent définit **2-3 personnalités d'agents** avec des points de vue différents (ex: un puriste performance, un pragmatiste simplicité, un défenseur de l'UX)
2. L'agent rédige un prompt pour Claude Code qui fera interagir ces personnalités
3. L'utilisateur copie le prompt dans Claude Code
4. Le multi-agent débat et produit une synthèse
5. L'utilisateur rapporte la synthèse
6. L'agent et l'utilisateur en tirent une décision

**Déclencheur** : choix d'architecture, conception d'UI, stratégie d'algorithme, ou toute décision qui mérite d'être challengée.

### Règle générale

**Ne jamais supposer.** Si on n'est pas sûr à 100% d'un fait technique ou d'un choix de conception → produire un prompt, demander à l'utilisateur de consulter, attendre la réponse avant de continuer.

---

## Conventions techniques

- **WoW Classic Era** (version 1.15.x, interface **11508** au moment de l'écriture — vérifier en jeu avec `/dump select(4, GetBuildInfo())`)
- **Lua** + fichiers `.toc` — pas de build, pas de compilation
- Chaque capsule = un mini-add-on autonome avec son propre `.toc`
- Les capsules se testent en les copiant dans `Interface/AddOns/` + `/reload`
- Références API : [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API), [classic.wowhead.com](https://classic.wowhead.com/), [wowprogramming.com](https://wowprogramming.com/)

### API WoW Classic Era — Findings validés (Session 1)

Ces informations ont été validées via consultation externe (voir `prompts/research-wow-api-response.md`).

#### Trade Skill API
- `C_TradeSkillUI` **existe** en Classic Era (version pré-10.0, les retraits "Removed in 10.0" sont Retail-only)
- `GetAllRecipeIDs()` → liste les recettes du métier ouvert (apprises ET non apprises)
- `GetRecipeInfo(recipeID)` → détails d'une recette
- `GetRecipeNumReagents(recipeID)` → nombre de composants
- `GetRecipeReagentInfo(recipeID, index)` → nom, icône, quantité requise, quantité possédée
- `GetRecipeReagentItemLink(recipeID, index)` → item link du composant (pour extraire l'itemID)
- ⚠️ Ne fonctionne que si la fenêtre de métier est ouverte
- ⚠️ Ne montre que les recettes **apprises** par le personnage

#### Auction House API
- `C_AuctionHouse` **n'existe PAS** en Classic Era — c'est du Retail (8.3+)
- API utilisable : `QueryAuctionItems(text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)`
- Résultats via `GetAuctionItemInfo("list", index)` → `buyoutPrice`, `count`, `itemId`, etc.
- ⚠️ Pas de recherche par itemID — recherche par **nom** uniquement
- ⚠️ `buyoutPrice` est **par stack**, pas par unité — diviser par `count`
- ⚠️ Asynchrone : attendre l'événement `AUCTION_ITEM_LIST_UPDATE`
- ⚠️ Pagination : 50 résultats par page (index à partir de 0)
- ⚠️ Throttling : ~0.3s entre les queries, 15min pour `getAll`
- Vérifier `CanSendAuctionQuery()` avant chaque requête
- La fenêtre de l'HdV **doit être ouverte**

### Architecture — Décision validée (Session 1)

Source de données pour les recettes : voir `prompts/multiagent-recipe-architecture-response.md`.

- **v1 : Base de données statique** (fichiers Lua avec les recettes codées en dur)
  - Nécessaire car l'API ne liste que les recettes apprises → impossible de planifier un leveling 1→300
  - Engineering est un set borné (quelques dizaines de recettes) → maintenance faible
  - Plus simple pour un projet d'apprentissage
- **v2 (roadmap) : Hybride** — DB statique + validation dynamique via l'API
  - L'API sert de QA pour la DB statique
  - Les résultats API peuvent surcharger les entrées statiques
- **Règle de design** : stocker les composants en **itemID**, pas en nom
- **Règle de design** : structurer la DB pour que l'API puisse overrider les entrées (passage v1→v2 sans rewrite)

### Types de capsules

| Type | Définition |
|------|-----------|
| **Autonomous** | Pas besoin d'être connecté avec un personnage spécifique |
| **Semi-autonomous** | Nécessite d'être connecté en jeu |
| **Sequential** | Nécessite qu'une capsule précédente ait été comprise |

## Organisation filesystem

```
00-todo/     ← Capsules non commencées (squelettes README.md)
01-wip/      ← Capsule en cours (au plus une)
02-done/     ← Capsules terminées et validées
```

- **Prochaine capsule** = premier répertoire dans `00-todo/` (trié par numéro)
- **Capsule en cours** = contenu de `01-wip/`

### ⛔ `git mv` toujours, jamais `mv`

### Rituel de session

**🟢 Début de session :**
1. Lire `AGENTS.md` puis `ROADMAP.md` pour le contexte
2. `ls 01-wip/` → capsule en cours ? Si oui, lire son README.md pour reprendre
3. `ls 02-done/` → combien de terminées ?
4. `ls 00-todo/ | head -1` → prochaine capsule
5. Lire le README.md de la prochaine capsule
6. **Phase 0** : lister les hypothèses, générer le méga-prompt de recherche, attendre les réponses, mettre à jour `docs/`
7. Phase A : storytelling + checklist technique
8. Comparer avec ROADMAP.md → filesystem = source de vérité

**🔴 Fin de session :**
1. Capsule validée → `git mv 01-wip/XX 02-done/` + commit
2. Capsule en cours → reste dans `01-wip/`
3. Mettre à jour ROADMAP.md (historique)
4. Vérifier cohérence
5. ⛔ **`git add -A && git commit` AVANT `/new`** — le répertoire de travail doit être propre avant de reset la conversation. Le nouvel agent doit retrouver un état git propre et à jour.

### Conventions de commit

- Un commit = un sujet
- Format : `type: description` (`feat:`, `docs:`, `chore:`)
- Commits de déplacement séparés du code
