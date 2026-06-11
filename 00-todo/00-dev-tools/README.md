# 00 — Dev Tools : Maîtriser les outils de debugging WoW

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Transverse (applicable à toutes les phases)                 |
| Prerequisites | Capsule 01 — Hello Azeroth                                  |
| Type          | Semi-autonomous (nécessite d'être connecté en jeu)          |
| Concepts      | `/dump`, `/etrace`, `/fstack`, `/tinspect`, BugSack, DevTool, profiling, event spy, breakpoints manuels |

## Why This Capsule?

On a codé 10 capsules en utilisant uniquement `print()` et `/reload` pour debugger. C'est comme construire une maison avec seulement un marteau. WoW possède une boîte à outils complète d'outils de debugging intégrés au client — mais ils sont cachés, non documentés dans le jeu, et la plupart des développeurs d'add-ons ne les découvrent qu'après des années.

Cette capsule est une **mise en situation pratique** : on va utiliser chaque outil dans un contexte réel pour comprendre quand et comment l'utiliser. L'objectif n'est pas de produire du code, mais d'acquérir des réflexes de debugging qui serviront pour toutes les capsules suivantes.

## Objectifs

1. **Maîtriser** les commandes natives (`/dump`, `/etrace`, `/fstack`, `/tinspect`)
2. **Installer et utiliser** BugSack + DevTool
3. **Comprendre** les patterns de debug (breakpoints manuels, profiling, event spy)
4. **Créer** une cheat sheet personnelle des outils disponibles

## Ce qu'on va faire (mise en situation)

### Scène 1 — "Ça crash et je sais pas pourquoi"
- Activer `/console scriptErrors 1`
- Provoquer une erreur Lua → voir la popup
- Installer BugSack + BugGrabber → voir la même erreur avec stack complète
- Utiliser `debugstack()` et `debuglocals()` dans le code

### Scène 2 — "Qu'est-ce qu'il y a dans cette table ?"
- `/dump ns.DB.recipes` → inspection rapide dans le chat
- `/tinspect ns.DB.recipes` → inspection visuelle en arbre
- Installer DevTool → `DevTool:AddData(ns.DB, "CraftGold DB")` → exploration complète
- Comparer les 3 approches (quand utiliser laquelle)

### Scène 3 — "Quel événement se déclenche ?"
- `/etrace` → voir TOUS les événements en temps réel
- Filtrer sur `ITEM` → ne voir que les événements item
- `/etrace mark BEFORE` → poser un marqueur
- Faire une action → voir les événements déclenchés
- Comparer avec un EventSpy maison (RegisterAllEvents)

### Scène 4 — "Quelle frame est là-dessus ?"
- `/fstack` → survol visuel des frames
- Identifier les frames CraftGold existantes
- `ALT` pour naviguer, `CTRL` pour inspecter
- Découvrir `fsobj` (la dernière frame sélectionnée)

### Scène 5 — "C'est lent, combien de temps ça prend ?"
- `debugprofilestart()` / `debugprofilestop()` → micro-benchmark
- Mesurer le calcul récursif du Calculator
- Comparer avec/sans mémoïsation

### Scène 6 — "Je veux que l'agent voie ce qui se passe"
- `/cg log on` → capturer l'output
- Faire des actions → `/reload`
- L'agent lit le fichier SavedVariables
- Pattern inbox : l'agent écrit dans les SavedVariables, l'add-on exécute

## Going Further

- Les outils dev deviennent des réflexes pour toutes les capsules suivantes
- Le skill `wow-dev-debug` permettra à l'agent de suggérer le bon outil au bon moment
