# Compilation Fonctionnelle vers Lua 5.1 — Recherche Ciblée

## Synthèse : Est-ce possible ? Est-ce raisonnable ?

Oui, c'est **techniquement possible**, mais c'est un projet de R&D significatif. La contrainte "Lua 5.1" est votre plus gros obstacle. Le manque de `goto`, de tables faibles complexes, et la limite des 60 upvalues rendent la compilation de langages fonctionnels complexes (notamment les closures imbriquées) périlleuse.

L'approche "raisonnable" pour un add-on WoW est de ne pas essayer de compiler *tout* le langage, mais de concevoir un **compilateur ciblé (scoped)** utilisant **Template Haskell** pour générer du Lua 5.1 depuis des structures de données Haskell, en utilisant une stratégie de **defunctionalization** agressive.

---

## Axe 1 : Infrastructure Haskell/Scala/ML → Lua

### Outils existants

* **Haskell :** `language-lua` est mature pour l'AST, mais son pretty-printer doit être audité pour garantir la compatibilité 5.1 (il supporte parfois des syntaxes plus récentes). `hslua` est excellent pour le runtime, inutile pour le *codegen* pur.
* **Scala :** Pas d'AST Lua standard robuste. La manipulation via `metaprogramming` (macros Scala 3) vers du texte ou un AST maison est plus viable.
* **ML :** `LunarML` est actuellement le candidat le plus sérieux pour SML -> Lua.

### Analyse de faisabilité

L'utilisation de `language-lua` est la voie la plus courte. Cependant, aucun projet n'offre un pipeline "Haskell complet" vers Lua. Vous devrez construire le pont entre `GHC.Core` (ou un AST simplifié) et cet AST Lua.

---

## Axe 2 : IR et Optimisations

### Optimisations essentielles pour Lua 5.1

1. **Defunctionalization (Indispensable) :** Puisque les closures Lua 5.1 plafonnent à 60 upvalues et que la portée lexicale est coûteuse, vous *devez* transformer les fonctions en une table d'envoi (`dispatcher`) et une liste de fonctions top-level.
2. **Lambda Lifting :** Indispensable pour éviter la création de closures à chaque exécution de boucle.
3. **Unboxing (Data representation) :** Lua ne connaît que les `tables` (ou `userdata`). Pour vos ADT, utilisez des entiers pour les tags : `local EITHER_LEFT = 0; local EITHER_RIGHT = 1`. Ne créez jamais d'objets complexes si le type peut être réduit à un `tag` et une `valeur`.

---

## Axe 3 : Free Monad / Tagless Final → Lua

### Compilation

La **Free Monad** est une structure de données (un arbre syntaxique). Compiler une Free Monad vers Lua consiste à écrire un **interprète (foyer)** qui parcourt cet arbre et génère du Lua séquentiel.

* **Approche recommandée : Tagless Final.** Elle est plus légère en termes de performance. Vous définissez une classe de types `MonadWow m` et vous écrivez une instance qui génère directement le code Lua (strings) ou l'AST `language-lua`.
* **Overhead :** Le passage par une Free Monad induit une allocation par instruction. En Lua, cela signifie beaucoup de tables temporaires et une pression sur le GC. Le **Tagless Final** évite cet intermédiaire en construisant le code "à plat" via l'instance de type.

---

## Axe 4 : Précédents

* **PureScript (pslua) :** Utilise la defunctionalization. Le code généré est lisible mais verbeux. Il traite les types de haut niveau par effacement (erasure).
* **Elm / js_of_ocaml :** Ils utilisent une transformation en **CPS** (Continuation Passing Style) pour gérer les effets et le contrôle. **Lua gère nativement les coroutines** (yield/resume), ce qui est un avantage majeur : vous pouvez transformer vos monades en coroutines Lua pour suspendre l'exécution en attendant un retour d'API WoW.

---

## Axe 5 : Contraintes WoW — faisabilité

| Contrainte | Analyse |
| --- | --- |
| **Max 60 upvalues** | **Critical.** Résolu uniquement par la defunctionalization. |
| **Budget CPU** | Résolu en évitant les allocations dans la boucle principale (pooling de tables). |
| **Pas de `goto**` | Les structures de contrôle doivent être compilées via des `while` et des `if`. |
| **Interop `_G**` | Facile : générez des appels directs aux noms globaux (ex: `GetItemInfo`). |

---

## Axe 6 : Projets existants évalués

1. **LunarML :** Le plus proche d'un compilateur robuste. Il gère bien les modules SML. Recommandé comme base d'étude.
2. **purescript-lua :** Bien pour l'inspiration sur la gestion des types classes, mais souvent trop lourd pour WoW.
3. **Amulet :** Très instructif pour la compilation de closures vers des tables.

---

## Axe 7 : Build-it-yourself

### La "Voie Royale" : Le compilateur scoped

Ne cherchez pas à compiler tout Haskell. Définissez un DSL limité :

1. Utilisez **Template Haskell** pour scanner votre code source Haskell.
2. Utilisez `language-lua` pour générer les fichiers `.lua`.
3. Implémentez une **instance Tagless Final** qui traduit directement vos effets en appels d'API WoW (ex: `GetItemInfo`).

**Effort estimé :** 2 à 3 mois pour une preuve de concept fonctionnelle, mais très gratifiant pour la maintenance du code CraftGold.

### Recommandation finale

N'utilisez pas de compilateur générique. **Créez un DSL embarqué en Haskell** utilisant le *Tagless Final*.

* Votre backend sera un simple interprète Haskell qui produit du texte (votre Lua 5.1).
* Utilisez des types `newtype` en Haskell pour garantir que les types `ItemID`, `AuctionID` ne soient pas mélangés.
* **Pourquoi ?** Parce que la vérification est faite par GHC (Haskell) à la compilation, et vous produisez du Lua "propre" que vous pouvez débugger dans WoW.

---

## Sources

* *Defunctionalization at work* (Danvy, 2001) - La base pour supprimer les closures.
* *Tagless Final Interpreters* (Kiselyov) - Pour le design de votre DSL.
* *LunarML Repository* (GitHub/minoki) - Référence pour l'implémentation SML->Lua.
* *Lua 5.1 Reference Manual* - Spécifications sur les limites de upvalues.

---

L'approche Tagless Final pour générer du code Lua est-elle celle qui vous semble la plus agile pour intégrer vos besoins spécifiques à WoW, ou préférez-vous l'idée de manipuler un AST intermédiaire comme celui de `language-lua` ?