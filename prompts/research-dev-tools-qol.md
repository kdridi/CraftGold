# Recherche — Outils de développement et QoL pour add-ons WoW Classic Era

## Contexte

Je développe un add-on World of Warcraft Classic Era (patch 1.15.x, interface 11508) en Lua. Mon workflow de développement implique un agent IA (Pi Coding Agent) qui génère du code, et moi qui le teste en jeu. L'agent ne peut pas interagir directement avec le jeu — il doit lire les résultats via des fichiers sauvegardés sur disque.

## Ce qu'on a déjà

Nous avons déjà implémenté dans notre shell d'add-on :

1. **`/cg run cmd1; cmd2; ...`** — Execute plusieurs slash commands séparées par des points-virgules en une seule saisie chat
2. **`/cg log on/off/clear/show`** — Capture tout l'output de `ns.WoW.print()` dans un buffer stocké dans les SavedVariables. Après `/reload`, WoW écrit les SavedVariables sur disque et l'agent IA peut lire le fichier texte résultant. Les codes couleur WoW (`|cFF...|r`) sont stripés pour un log propre.
3. **`/cg reset`** — Nettoyage complet des données
4. **`/cg test`** — Tests unitaires in-game avec save/restore de l'état utilisateur

## Ce que WoW propose nativement (source : code source Blizzard exporté)

Voici ce que j'ai trouvé dans `BlizzardInterfaceCode/Interface/AddOns/` :

### Outils intégrés au client
- **`/dump <expr>`** — Évalue une expression Lua et l'affiche dans le chat (implémenté dans `Blizzard_SharedXML/Dump.lua`, fonction `DevTools_DumpCommand`)
- **`/script <code>`** ou **`/run <code>`** — Exécute du code Lua arbitraire (commandes C++ natives)
- **`/console scriptErrors 1`** — Active l'affichage des erreurs Lua dans une fenêtre popup (`Blizzard_ScriptErrorsFrame`)
- **`/reload`** — Recharge l'UI et les add-ons
- **`/fstack`** — Frame Stack Tooltip : survol visuel des frames under cursor avec infos détaillées (CVars : `fstack_enabled`, `fstack_showhidden`, `fstack_showregions`, `fstack_showanchors`) — implémenté dans `Blizzard_DebugTools/`
- **Developer Console** — Console de développement intégrée (`Blizzard_Console/`) avec historique des commandes, filtres, auto-complétion, `ConsoleExec()`, événement `CONSOLE_MESSAGE`
- **Table Inspector** — Inspection visuelle des tables Lua (`Blizzard_TableInspector/`)
- **`debugstack()`, `debuglocals()`** — Stack trace et variables locales (utilisés par `Blizzard_ScriptErrors`)
- **`debugprofilestart()`, `debugprofilestop()`** — Profiling en millisecondes
- **`C_Log.LogMessage()`, `C_Log.LogErrorMessage()`** — Système de log du client
- **`ConsoleGetAllCommands()`** — Liste toutes les commandes console disponibles
- **Macros WoW** — Système natif de macros dans le jeu (`Blizzard_MacroUI/`)

## Situations de développement que je veux couvrir

Pour chaque situation ci-dessous, proposez des solutions concrètes, pratiques et spécifiques à WoW Classic Era. Les solutions peuvent être :

- **A)** Des commandes WoW natives (`/dump`, `/script`, `/console`, etc.)
- **B)** Des patterns Lua à implémenter dans notre add-on
- **C)** Des outils ou add-ons existants à installer
- **D)** Des macros WoW
- **E)** Des workflows ou astuces de développement

### Situations

#### S1 — Logging et output
1. **Logger dans un fichier lisible hors-jeu** — On a déjà le pattern SavedVariables, mais y a-t-il mieux ? Est-ce que la Developer Console peut aider ? Est-ce que `ConsoleExec()` peut rediriger l'output ?
2. **Logger avec des niveaux** (DEBUG, INFO, WARN, ERROR) — Comment implémenter un logger structuré ? Faut-il utiliser `C_Log` du client ou rouler le nôtre ?
3. **Activer/désactiver le logging à chaud** — Notre `/cg log on/off` fonctionne, mais y a-t-il un pattern plus élégant ?

#### S2 — Debugging
4. **Inspecter une table Lua en jeu** — `/dump` existe mais est limité. Comment les devs d'add-ons inspectent-ils des tables profondes ? Le TableInspector est-il disponible en Classic Era ?
5. **Debugger pas-à-pas** — Existe-t-il un debugger Lua en jeu pour WoW ? Un équivalent de `pdb` ou `gdb` ?
6. **Profiler les performances** — `debugprofilestart/stop` existe. Comment l'utiliser efficacement ? Y a-t-il des add-ons de profiling ?
7. **Surveiller les événements** — Comment logguer tous les événements qui passent ? Un pattern pour écouter *tous* les événements et les filtrer ?

#### S3 — Tests
8. **Framework de tests in-game** — Notre système d'assertions maison fonctionne, mais existe-t-il un framework de tests plus complet pour les add-ons WoW ? Des patterns de test avancés ?
9. **Tests automatisés** — Est-il possible de créer des macros ou des scripts qui lancent automatiquement une suite de tests et logguent les résultats ?

#### S4 — Interaction agent IA ↔ jeu
10. **Communication bidirectionnelle** — Notre pattern actuel : l'agent écrit des fichiers Lua, l'utilisateur les teste, l'agent lit les SavedVariables. Y a-t-il un meilleur moyen ? Est-ce que les macros WoW pourraient automatiser certaines étapes ?
11. **Exécuter des scénarios complexes** — Notre `/cg run` permet les commandes chaînées. Mais peut-on faire mieux ? Des scripts multi-lignes ? Des fichiers de scénarios ?
12. **Capturer l'état complet du jeu** — Comment dump toute la state d'un add-on (SavedVariables + état runtime) pour analyse ?

#### S5 — Macros WoW et automatisation
13. **Macros pour le dev** — Quelles macros sont utiles pour un développeur d'add-ons ? (reload, dump, test, etc.)
14. **Macros conditionnelles** — Est-ce qu'on peut faire des macros qui exécutent des commandes différentes selon l'état ?
15. **Boutons d'action pour le dev** — Créer des boutons cliquables sur l'écran pour les commandes fréquentes (reload, run tests, toggle log, etc.)

#### S6 — Comfort et productivité
16. **Auto-reload** — Est-ce possible de détecter un changement de fichier et de reload automatiquement ?
17. **Coloration syntaxique / éditeur de code in-game** — Existe-t-il un moyen d'éditer du code Lua directement en jeu ?
18. **Snippets et templates** — Des patterns de code récurrents pour le dev d'add-ons WoW

## Consignes de réponse

1. **Faites une vraie recherche web** — Citez vos sources (URLs) pour chaque affirmation
2. **Réponse monobloc en markdown** — Tout dans un seul bloc texte, pas de fichiers séparés
3. **Spécifique à Classic Era** — Ne proposez pas d'outils Retail-only. Si un outil existe en Retail mais pas en Classic, dites-le explicitement
4. **Pratique avant la théorie** — Donnez des exemples de code concrets, pas juste des concepts
5. **Classez vos solutions par situation** (S1-S6) — Pour chaque situation, listez les solutions du plus pratique au plus avancé
6. **Distinguez ce qui existe déjà** (natif WoW ou add-on existant) **de ce qu'il faudrait coder** nous-mêmes
7. **Évaluez le rapport effort/bénéfice** — Un trick qui demande 2 lignes de code et qui sauve 10 minutes par session vaut plus qu'un framework complet qui demande 3 jours
