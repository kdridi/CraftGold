# 00 — Dev Tools : Maîtriser les outils de debugging WoW

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Transverse (applicable à toutes les phases)                 |
| Prerequisites | Capsule 01 — Hello Azeroth                                  |
| Type          | Semi-autonomous (nécessite d'être connecté en jeu)          |
| Concepts      | `/dump`, `/etrace`, `/fstack`, `/tinspect`, BugSack, DevTool, profiling, event spy, breakpoints manuels |

## Why This Capsule?

On a codé 10 capsules en utilisant uniquement `print()` et `/reload` pour debugger. C'est comme construire une maison avec seulement un marteau. WoW possède une boîte à outils complète d'outils de debugging intégrés au client — mais ils sont cachés, non documentés dans le jeu, et la plupart des développeurs d'add-ons ne les découvrent qu'après des années.

Pire : sans les bons outils, **l'agent IA est aveugle**. Il doit demander à l'utilisateur de lire et recopier le contenu du chat — frustrant, imprécis, et ça tue le flow de la session. Cette capsule résout ce problème de fond.

Le moment est idéal : on a un add-on fonctionnel (ManualListings) avec des données réelles, des frames, des événements, un calculateur récursif — le terrain de jeu parfait. Et les capsules suivantes (DP knapsack, AH scanner) vont complexifier le code. Mieux vaut avoir les bons réflexes maintenant.

6 scènes, 6 problèmes concrets, 6 outils à maîtriser.

## Add-ons tiers requis

Installer via CurseForge **avant** la Phase B :

| Add-on | Rôle |
|--------|------|
| **!BugGrabber** | Intercepte les erreurs Lua (se charge en premier grâce au `!`) |
| **BugSack** | UI de visualisation des erreurs capturées par BugGrabber |
| **DevTool** | Inspection visuelle de tables, comme une console navigateur |

## Le pattern de base : exposer `ns` en global

**Problème vécu** : `ns` est déclaré `local _, ns = ...` dans l'add-on → inaccessible depuis `/run`. Conséquence : impossible d'appeler `ns.WoW.print()` depuis le chat pour alimenter le log. L'agent est aveugle.

**Solution** : ajouter une ligne dans le shell de l'add-on :

```lua
local _, ns = ...
_G.cgNS = ns  -- Expose namespace for /run debugging
```

À partir de là, `/run cgNS.WoW.print(...)` fonctionne et le log capture tout. L'agent peut lire les SavedVariables après `/reload`.

## Les 6 scènes — Vrai vécu

### Scène 1 — "Ça crash et je sais pas pourquoi"

**Outils** : `/console scriptErrors`, BugSack, `debugstack()`, `debuglocals()`

**Déroulement** :
- `/console scriptErrors 1` est activé, mais **la popup Blizzard n'apparaît pas** car BugGrabber l'intercepte silencieusement.
- `/bugsack` ouvre la config. **Mais c'est `/bugsack show`** qu'il faut taper pour voir les erreurs capturées.
- `debuglocals(1)` fonctionne bien : affiche les variables locales du scope courant.

**Gotchas** :
- BugGrabber **remplace** le handler d'erreurs par défaut → la popup Blizzard ne s'affiche plus jamais tant que BugGrabber est actif. C'est un choix délibéré : BugSack offre plus d'infos.
- Les erreurs `/run` avec des guillemets imbriqués provoquent des erreurs de parsing avant même l'exécution → attention aux `"` dans les one-liners.

### Scène 2 — "Qu'est-ce qu'il y a dans cette table ?"

**Outils** : `/dump`, `/tinspect`, DevTool

**Déroulement** :
- `/dump ManualListingsDB` → affiche le contenu dans le chat. Quick mais illisible pour les tables profondes.
- `/tinspect ManualListingsDB` → ouvre une fenêtre en arbre. Les tables apparaissent d'abord "vides" avec un label `N/A` à droite — **cliquer sur ce label** navigue dans la sous-table.
- `/tinspect cgNS.Prices.getAll()` → fonctionne aussi avec une expression (pas juste un nom de variable).
- DevTool (`/dev`) → champ de saisie à gauche, arbre dépliable à droite, exactement comme la console d'un navigateur web. On saisit `cgNS.DB` dans le champ et on explore.

**Gotchas** :
- `/tinspect` : les tables ne sont PAS vides — il faut **cliquer sur le label** pour les déplier, pas sur la flèche.
- `formatName()` retourne `item:3919` au lieu du vrai nom quand le cache n'a pas encore chargé l'item.

**Quand utiliser quoi** :
| Outil | Force | Usage |
|---|---|---|
| `/dump` | Quick check dans le chat | Une valeur, un booléen, un compteur |
| `/tinspect` | Navigation en profondeur, natif | Explorer une table rapidement |
| DevTool | Console navigateur-like, persistant | Exploration approfondie, données complexes |

### Scène 3 — "Quel événement se déclenche ?"

**Outils** : `/etrace`, EventSpy maison

**Déroulement** :
- `/etrace` → ouvre une fenêtre avec un flux d'événements en temps réel. Le débit est **massif** (des dizaines par seconde).
- En tapant `ITEM` dans le champ de filtre, on ne voit que les événements `ITEM_*`. Testé avec `GetItemInfo(99999)` → on voit `GET_ITEM_INFO_RECEIVED` avec `success=false`.
- EventSpy maison via `/run` : `RegisterAllEvents()` + `cgNS.WoW.print()` → capture dans le log. Résultat : 45 événements en quelques secondes, majorité = `SPELL_ACTIVATION_OVERLAY_HIDE` (spam de buffs).

**Leçons** :
- `/etrace` avec filtre = outil rapide pour "quel événement se déclenche quand je fais X ?"
- EventSpy = pour capturer et analyser après coup (l'agent peut lire le log)
- `RegisterAllEvents()` est un firehose — toujours filtrer en pratique

### Scène 4 — "Quelle frame est là-dessus ?"

**Outil** : `/fstack`

**Déroulement** :
- `/fstack` est un **toggle** — on tape `/fstack` pour activer, et on **retape `/fstack`** pour désactiver (pas ESC !).
- En survolant la fenêtre CraftGold, les noms des frames s'affichent à l'écran.
- **ALT gauche/droite** permet de naviguer dans la hiérarchie : widget survolé → parent → enfant → etc.

**Gotchas** :
- ESC ne quitte PAS `/fstack`. C'est un toggle par commande chat.

### Scène 5 — "C'est lent, combien de temps ça prend ?"

**Outil** : `debugprofilestart()` / `debugprofilestop()`

**Déroulement** — Profilage du Calculator :

| Test | Temps | Temps/appel |
|---|---|---|
| Shallow recipe (3918) ×1000 | 5.8 ms | **5.8 µs** |
| Recursive recipe (4359 Copper Bolts) ×1000 | 18.3 ms | **18.3 µs** |
| Shallow ×10000 | 44.9 ms | **4.5 µs** |
| Recursive ×10000 | 149.9 ms | **15.0 µs** |

**Leçons** :
- Recipe récursive = **3x plus lente** que shallow (descend dans l'arbre des composants).
- Même la récursive : 15 µs par appel → **66 000 calculs/seconde** → largement suffisant.
- `debugprofilestart/stop` est simple, fiable, et précis (résolution ms).

**Gotchas** :
- Le cache de mémoïsation du Calculator est local à chaque appel de `calculate()` — il n'y a pas de `_clearCache()` à appeler. Chaque `calculate()` repart de zéro.

### Scène 6 — "Je veux que l'agent voie ce qui se passe"

**Outil** : `/cg log on` + lecture SavedVariables

Ce pattern a été utilisé **tout au long de la session**. Workflow :

1. `/cg log on` → capture active
2. Commandes en jeu → tout passe dans le log via `cgNS.WoW.print()`
3. `/reload` → flush sur disque
4. L'agent lit le fichier `WTF/Account/.../SavedVariables/ManualListings.lua`

C'est le pattern qui rend la collaboration agent↔utilisateur fluide. L'utilisateur n'a plus rien à recopier.

## Cheat Sheet — Outils de debugging WoW

### Commandes chat

| Commande | Usage | Exemple |
|----------|-------|---------|
| `/dump <expr>` | Évalue et affiche | `/dump cgNS.Core.count()` |
| `/run <code>` | Exécute du Lua arbitraire | `/run print(GetTime())` |
| `/etrace` | Traceur d'événements temps réel | Filtrer avec le champ texte |
| `/fstack` | Survol visuel des frames | Toggle : retaper pour désactiver |
| `/tinspect <table>` | Inspecteur de tables en arbre | `/tinspect cgNS.DB` |
| `/console scriptErrors 1` | Active popup erreurs | Masquée si BugGrabber actif |
| `/bugsack show` | Voir erreurs capturées | Stack complète + locals |

### Navigation /fstack

| Touche | Action |
|--------|--------|
| ALT gauche/droite | Naviguer dans la hiérarchie frame (parent/enfant) |
| CTRL | Ouvrir tinspect sur la frame sélectionnée |
| `/fstack` | Retaper pour désactiver |

### Fonctions Lua de debug

| Fonction | Usage |
|----------|-------|
| `debugstack(level)` | Stack trace à partir du niveau |
| `debuglocals(level)` | Variables locales au niveau |
| `debugprofilestart()` | Démarre timer (ms) |
| `debugprofilestop()` | Temps écoulé depuis dernier start |
| `pcall(fn, ...)` | Appel protégé → ok, result |

### Pattern de capture pour l'agent IA

```
/cg log on                          → Activer capture
/run cgNS.WoW.print("debug info")  → Logger via ns
/reload                             → Flush sur disque
→ L'agent lit SavedVariables        → Plus rien à recopier
```

## Going Further

- Les outils dev deviennent des réflexes pour toutes les capsules suivantes
- Le skill `wow-dev-debug` permettra à l'agent de suggérer le bon outil au bon moment
- `WowLua` (recommandé) : éditeur/REPL Lua in-game pour prototyper des snippets plus longs
