# Consultation multi-agents — Architecture d'un add-on WoW (Lua)

Tu vas animer un débat entre 3 experts pour concevoir l'architecture d'un add-on World of Warcraft Classic Era en Lua. L'objectif : trouver l'architecture la plus propre possible qui soit **compatible avec les contraintes Lua/WoW** tout en restant **testable et bien structurée**.

**Consigne : ta réponse doit être un seul bloc markdown, sans fichiers séparés, sans artifacts.**

---

## Contexte

On crée un projet pédagogique : **13 capsules progressives**, chacune un mini-add-on autonome, pour apprendre à créer des add-ons WoW. Le projet final (CraftGold) sera un add-on de calcul de coûts de crafting.

### Contraintes de l'environnement Lua/WoW
- **Pas de `require()`** — WoW ne supporte pas le module system standard de Lua
- **Pas de class system** — pas de POO native (mais possible via metatables)
- **Espace global partagé** — tous les add-ons partagent `_G`
- **Chargement séquentiel** — les fichiers `.lua` listés dans le `.toc` sont chargés dans l'ordre, de haut en bas
- **Pas de build/bundler** — Lua brut, pas de compilation, pas de TypeScript
- **Pas de framework de test intégré** — pas de Jest, pas de pytest
- **Le vararg `...`** du fichier principal fournit `addonName` et `ns` (une table privée partagée entre les fichiers du même add-on)

### Ce qu'on peut faire
- Utiliser `ns` (namespace table du vararg) pour partager des modules entre fichiers
- Splitter le code en plusieurs fichiers `.lua` listés dans le `.toc`
- Encapsuler l'API WoW derrière des fonctions wrappées
- Créer des patterns module avec des tables Lua
- Écrire des tests unitaires dans un fichier séparé (exécutables en Lua standard hors de WoW)

### Où on en est
- Capsules 01-02 : single-file, ~60 lignes (découverte des bases)
- Capsule 03 : single-file, ~120 lignes (SavedVariables, événements, slash commands)
- Capsules 04-06 : frames, boutons, scroll (UI plus complexe)
- Capsules 07-13 : intégration jeu, données, algorithme, assemblage final

### Le problème actuel
Le code est un mélange monolithique dans un seul fichier :
- Appels directs à l'API WoW (`CreateFrame`, `RegisterEvent`, `print`)
- Logique métier (increment counter, apply defaults)
- Handlers d'événements et slash commands
- Présentation (couleurs, formatage)

### Exigences
1. **Séparation des responsabilités** — logique métier isolée de l'API WoW et de l'UI
2. **Testabilité** — pouvoir tester la logique métier hors de WoW, avec du mocking
3. **Progressivité** — l'architecture doit pouvoir grandir au fil des capsules (ne pas over-engineer la capsule 03, mais préparer le terrain)
4. **Lisibilité** — un développeur expérimenté doit sentir que c'est du code "pro", pas du tuto spaghetti
5. **Idiomatique Lua** — pas de forcer des patterns Java/Python dans Lua, utiliser les idiomes Lua (tables, closures, metatables si pertinent)

---

## Les 3 experts

### Expert 1 — Le Puriste Testabilité
- Obsédé par la séparabilité et le mocking
- Veut que chaque fonction pure soit testable unitairement
- Veut une couche d'abstraction sur TOUTE interaction externe (API WoW, SavedVars, chat)
- Risque : over-engineering, trop d'indirection pour un add-on de 200 lignes

### Expert 2 — Le Pragmatiste WoW
- 15 ans d'expérience en add-ons WoW
- Connaît les idiomes de la communauté (Ace3, LibStub, etc.)
- Sait que les add-ons WoW sont naturellement petits et que l'abstraction a un coût en Lua
- Risque : trop pragmatique, tolère le code "monolithique" parce que c'est "la tradition WoW"

### Expert 3 — Le Pédagogue Architecte
- Enseigne l'architecture logicielle depuis 20 ans
- Pense en termes de : "quel concept cette structure enseigne-t-elle ?"
- Veut que la progression des capsules suive une courbe d'apprentissage naturelle
- Risque : trop théorique, l'architecture parfait dans un cours mais pas dans la pratique

---

## Déroulement du débat

1. **Tour 1** — Chaque expert propose son architecture idéale (structure de fichiers, patterns, conventions) en tenant compte des contraintes
2. **Tour 2** — Chaque expert critique la proposition des deux autres
3. **Tour 3** — Chaque expert propose un compromis
4. **Synthèse** — Tu (le modérateur) produis une architecture de compromis finale avec :
   - Structure de fichiers recommandée
   - Patterns à utiliser (avec exemples de code concrets pour la capsule 03)
   - Conventions de nommage
   - Progression : comment l'architecture évolue de la capsule 03 à la 13
   - Ce qu'on fait pour les tests unitaires (pratique, pas théorique)
