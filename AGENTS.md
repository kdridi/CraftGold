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
2. L'agent rédige le prompt de recherche et l'écrit dans `prompts/research-capsule-XX-<slug>.md`
3. L'agent crée les 3 fichiers de réponse vides dans `prompts/` :
   - `research-capsule-XX-<slug>-response-claude.md`
   - `research-capsule-XX-<slug>-response-gemini.md`
   - `research-capsule-XX-<slug>-response-chatgpt.md`
4. L'utilisateur copie le prompt dans Claude, Gemini et ChatGPT, puis colle chaque réponse dans le fichier correspondant
5. L'utilisateur dit **« c'est bon »** quand les 3 réponses sont en place
6. L'agent lit les 3 réponses, compare, extrait les faits validés, identifie les désaccords
7. L'agent crée ou met à jour les fichiers dans `docs/` (base de connaissances validée)
8. **Ce n'est qu'après cette étape** qu'on entre dans la Phase A (storytelling + checklist)

**Règle** : les capsules sont construites depuis `docs/`, pas depuis le dataset de l'agent. Le dataset sert d'inspiration pour le parcours pédagogique ; `docs/` est la source de vérité pour les faits techniques.

#### Consultation du code source Blizzard local

Avant de générer un prompt pour les LLM externes, l'agent doit **d'abord consulter le code source Blizzard exporté** (voir conventions techniques). Ce code est la source de vérité la plus fiable — c'est ce que le client exécute réellement.

1. L'agent cherche dans `BlizzardInterfaceCode/Interface/AddOns/` les fichiers pertinents (templates, mixins, API docs)
2. Si le code source Blizzard répond à la question → pas besoin de prompt externe
3. Si le code source est insuffisant ou ambigu → on génère un prompt pour validation externe

#### Règles de rédaction des prompts de recherche

1. **Recherche sourcée obligatoire** — Chaque prompt doit exiger explicitement que le LLM fasse une **vraie recherche web** et fournisse des **liens sources** (URLs) pour chaque affirmation. On ne veut pas du savoir « training data » non vérifié, on veut des sources consultables (wowpedia, warcraft.wiki.gg, wowprogramming.com, forums, etc.).
2. **Réponse monobloc en markdown** — Le prompt doit exiger que la **totalité** de la réponse soit en **markdown dans un seul bloc texte**. Pas de fichiers séparés, pas d'artifacts, pas de pièces jointes à télécharger. Le code, les exemples, tout doit être inline dans la réponse markdown.

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
- **Dossier AddOns** : `/Applications/World of Warcraft/_classic_era_/Interface/AddOns` (utiliser des symlinks depuis ce dossier vers les capsules dans le repo)
- **Lua** + fichiers `.toc` — pas de build, pas de compilation
- Chaque capsule = un mini-add-on autonome avec son propre `.toc`
- Les capsules se testent en les copiant dans `Interface/AddOns/` + `/reload`
- Références API : [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API), [classic.wowhead.com](https://classic.wowhead.com/), [wowprogramming.com](https://wowprogramming.com/)

### Code source Blizzard exporté (source de vérité locale)

- **Chemin** : `/Applications/World of Warcraft/_classic_era_/BlizzardInterfaceCode/Interface/AddOns/`
- **Généré via** : lancer WoW avec l'option `-console`, puis dans la console : `ExportInterfaceFiles code`
- **Contenu** : l'intégralité du code source Lua/XML de l'interface Blizzard du client Classic Era (178+ add-ons)
- **Usage** : source de vérité de premier plan pour valider l'API, les templates, les mixins, les handlers, etc.
- **Répertoires clés** :
  - `Blizzard_SharedXML/` — templates partagés (Backdrop, Button, etc.)
  - `Blizzard_UIPanelTemplates/` — templates de panels (Classic)
  - `Blizzard_APIDocumentationGenerated/` — documentation auto-générée de l'API
  - `Blizzard_APIDocumentation/` — documentation supplémentaire
- ⚠️ Ce dump est lié à la version du client — à refaire si WoW est mis à jour

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

### Outils de debugging WoW (Capsule 00 — validé Session 13)

**⛔ Règle #0 : ne JAMAIS demander à l'utilisateur de lire et recopier le chat.** Utiliser le pattern de capture ci-dessous.

#### Skill disponible

Le skill `.pi/skills/wow-dev-debug/SKILL.md` contient la documentation complète des outils. **L'activer** quand l'utilisateur rencontre une erreur, veut inspecter un état, profiler, ou explorer l'API.

#### Pattern de capture agent↔utilisateur

L'add-on ManualListings expose `ns` en global via `_G.cgNS = ns` :```
/cg log on                                        → Activer capture
/run cgNS.WoW.print("debug info")                → Logger via ns
/reload                                           → Flush sur disque
→ L'agent lit SavedVariables                       → Plus rien à recopier
```

Chemin SavedVariables : `WTF/Account/125818886#1/SavedVariables/ManualListings.lua`

#### Commandes essentielles

| Commande | Usage |
|----------|-------|
| `/dump <expr>` | Évalue et affiche dans le chat |
| `/run <code>` | Exécute du Lua (utiliser `cgNS.*` pour accéder à l'add-on) |
| `/etrace` | Traceur d'événements temps réel (filtrable, toggle) |
| `/fstack` | Survol visuel des frames (toggle, ALT pour naviguer) |
| `/tinspect <table>` | Inspecteur de tables en arbre |
| `/bugsack show` | Voir les erreurs Lua capturées (stack complète) |
| `debugprofilestart()` / `debugprofilestop()` | Micro-benchmark en ms |

#### Add-ons dev installés

!BugGrabber, BugSack, DevTool — installés via CurseForge.

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

**⛔ Règle absolue :** Quel que soit le prompt de l'utilisateur, la première action de l'agent est TOUJOURS d'annoncer où on en est et ce qu'il propose de faire. **Aucun fichier de code n'est créé avant la Phase B validée.** L'agent s'arrête, résume la situation, et attend la confirmation de l'utilisateur avant de poursuivre.

**🟢 Début de session :**
1. Lire `AGENTS.md` puis `ROADMAP.md` pour le contexte
2. `ls 01-wip/` → capsule en cours ? Si oui, lire son README.md pour reprendre
3. `ls 02-done/` → combien de terminées ?
4. `ls 00-todo/ | head -1` → prochaine capsule
5. Lire le README.md de la prochaine capsule
6. **Annoncer le plan et attendre confirmation** — L'agent résume : où on en est, quelle est la prochaine capsule, quelle phase démarre, et pose la question : « On commence la Phase X de la capsule YY — tu confirmes ? ». **Ne rien exécuter avant la réponse de l'utilisateur.**
7. **Phase 0** : lister les hypothèses, générer le méga-prompt de recherche, attendre les réponses, mettre à jour `docs/`
8. Phase A : storytelling + checklist technique
9. Comparer avec ROADMAP.md → filesystem = source de vérité

**🔴 Fin de session — Checklist de cohérence :**

Le but : un `git clone` + nouvelle session doit permettre de reprendre exactement où on en est.

1. **Filesystem** — Déplacer les capsules selon leur statut :
   - Capsule validée → `git mv 01-wip/XX 02-done/`
   - Capsule en cours → reste dans `01-wip/`
2. **ROADMAP.md** — Mettre à jour l'historique des sessions (ce qui a été fait cette session)
3. **`docs/`** — Ajouter/mettre à jour les docs si de nouvelles connaissances ont été validées
4. **README.md des capsules** — S'assurer que les README des capsules concernées reflètent le vrai vécu
5. **Vérification croisée** — Comparer ces 3 sources, elles doivent être cohérentes :
   - `02-done/` ↔ ROADMAP « Historique des sessions »
   - `01-wip/` ↔ ROADMAP « en cours »
   - `00-todo/` ↔ ROADMAP « à faire »
   - Si incohérence → **filesystem = source de vérité**, mettre à jour ROADMAP en conséquence
6. ⛔ **`git add -A && git commit` AVANT `/new`** — le répertoire de travail doit être propre avant de reset la conversation. Le nouvel agent doit retrouver un état git propre et à jour.

### Conventions de commit

- Un commit = un sujet
- Format : `type: description` (`feat:`, `docs:`, `chore:`)
- Commits de déplacement séparés du code
