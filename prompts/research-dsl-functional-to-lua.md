# Recherche Ciblée : Compilation de langages fonctionnels de haut niveau vers Lua 5.1 — Approches DSL, IR et LLVM-like

## Contexte

Je développe CraftGold, un add-on World of Warcraft Classic Era (Lua 5.1). J'ai déjà fait une première recherche large sur les langages compilant vers Lua. Le résultat est décevant : les recommandations principales (TypeScriptToLua, Teal, Fennel) sont soit du "JavaScript avec des types", soit du Lua annoté, soit du Lisp non typé. Rien qui offre la puissance d'expression d'un vrai langage fonctionnel.

**Ce que je veux, c'est la voie hardcore** : écrire dans un langage qui offre les mêmes abstractions qu'Haskell ou Scala (ADT, GADT, pattern matching exhaustif, monades, type classes, higher-kinded types, Free Monad pour les effets) et compiler vers du Lua 5.1 compatible WoW.

## L'analogie qui guide cette recherche

### Modèle LLVM

```
Frontend (Rust, C++, Swift, Haskell)
    ↓
IR intermédiaire (LLVM IR) — optimisations, analyses
    ↓
Backend (x86, ARM, WebAssembly, ...)
```

Ce que je veux :
```
Frontend (Haskell, Scala, OCaml, PureScript, ou custom DSL)
    ↓
IR intermédiaire — DCE, inlining, specialization, fusion
    ↓
Backend Lua 5.1 — code lisible, performant, compatible WoW
```

### Modèle Yesod / Shakespearean Templates

Le framework web Haskell **Yesod** utilise des DSLs embarqués (quasiquotation) pour générer du HTML, CSS et JavaScript avec vérification à la compilation par le système de types Haskell :

```haskell
-- Hamlet : DSL type-safe pour HTML, vérifié par le compilateur Haskell
[hamlet|
  <h1>#{title}
  <ul>
    $forall item <- items
      <li>#{item}
|]
```

Je veux appliquer le même principe : un DSL Haskell/Scala embarqué qui **génère du Lua 5.1** avec la sécurité du système de types du langage hôte.

## Axes de recherche précis

### Axe 1 : Infrastructure existante pour générer du Lua depuis Haskell/Scala/ML

#### Hackage / HsLua / language-lua

Je sais que ces paquets existent sur Hackage :
- `language-lua` — AST Lua 5.x + pretty-printer
- `hslua` / `hslua-core` — bindings Haskell → Lua C API
- `lua` — binding bas niveau

**Questions :**
- `language-lua` peut-il générer du Lua 5.1 spécifiquement ? Quel est le niveau de maturité ?
- Existe-t-il des projets qui utilisent `language-lua` comme backend de compilation (pas juste pour embed Lua dans Haskell, mais pour **générer** du Lua source) ?
- Y a-t-il des exemples de compilateurs Haskell → Lua ou DSL Haskell → Lua ?

#### Scala / JVM

- Existe-t-il un équivalent de `language-lua` en Scala (AST Lua + codegen) ?
- Les macros Scala 3 pourraient-elles servir de frontend pour un générateur Lua ?
- Y a-t-il des projets Scala → Lua ?

#### OCaml / Standard ML

- `LunarML` compile SML vers Lua. Quelle est la qualité du Lua généré ? Est-ce compatible 5.1 ?
- Existe-t-il `lua_of_ocaml` (analogue à `js_of_ocaml`) ? Si oui, quel état ?
- OCaml a un excellent système de modules/foncteurs — peut-on compiler vers Lua en préservant ces abstractions ?

### Axe 2 : IR intermédiaire et optimisations

#### Existe-t-il un IR "functionnel" qui targete Lua ?

- **PureScript CoreFn** : PureScript a une IR appelée CoreFn. Le backend `purescript-lua` (pslua) l'utilise. Quelles optimisations fait-il ? DCE ? Inlining ? Fusion ? Quelle est la qualité du Lua généré ?
- **GHC Core** : Est-ce que quelqu'un a déjà essayé de compiler GHC Core (l'IR de Haskell) vers Lua ? Même expérimental ?
- **FLIR (Functional Language IR)** : Existe-t-il un IR fonctionnel léger conçu pour être un target de compilation facile vers des langages dynamiques comme Lua ?
- **CPS (Continuation-Passing Style) transform** : Est-ce que la transformation CPS est utilisée pour compiler des langages fonctionnels vers Lua ? Lua a des coroutines natives — est-ce un avantage ?

#### Optimisations spécifiques

Pour un langage fonctionnel compilant vers Lua 5.1, quelles optimisations sont :
- **Essentielles** (sans elles, le code est trop lent/gros pour WoW) ?
- **Possibles** (améliorent les perfs mais pas critiques) ?
- **Impossible** dans le contexte Lua 5.1 ?

Spécifiquement :
- **Defunctionalization** : transformer les closures en tables + fonctions nommées pour éviter la limite des 60 upvalues de Lua 5.1 ?
- **Lambda lifting** : éliminer les closures en remontant les variables libres en paramètres ?
- **Unboxing** : les ADT en Lua sont des tables — peut-on optimiser les cas simples (Maybe = nil | value, Either = {tag, value}) en évitant l'allocation de table ?
- **Fusion / stream fusion** : peut-on fusionner les `map`/`filter`/`fold` successifs en une seule boucle Lua ?

### Axe 3 : Free Monad / Tagless Final comme abstraction IO pour l'API WoW

C'est le cœur du problème CraftGold. L'API WoW est un ensemble de fonctions impures (GetItemInfo, QueryAuctionItems, etc.). En Haskell/Scala, on modélise ça avec des effets.

**Free Monad approach :**
```haskell
data WowF next where
  GetItemInfo    :: ItemID -> (Maybe ItemInfo -> next) -> WowF next
  QueryAuctions  :: Text -> Int -> ([AuctionItem] -> next) -> WowF next
  Print          :: Text -> next -> WowF next

type WowM = Free WowF

getItemInfo :: ItemID -> WowM (Maybe ItemInfo)
getItemInfo id = liftF (GetItemInfo id id)

-- Interprétation test (pure, pas de WoW)
runTest :: WowM a -> State MockDB a
runTest = iterM $ \case
  GetItemInfo id k -> k (Map.lookup id mockItems)
  Print msg next   -> trace msg next

-- Interprétation production → génère du Lua qui appelle l'API WoW
runLua :: WowM a -> LuaCodeGen a
-- Génère : local result = GetItemInfo(itemID); if result then ... end
```

**Questions :**
- Comment compile-t-on une Free Monad vers du Lua impératif ? Est-ce que quelqu'un l'a fait ?
- La compilation de Free Monad génère-t-elle du code lisible ou un spaghetti de closures ?
- Quel est le overhead runtime (en closures Lua, tables, upvalues) d'une Free Monad compilée ?
- **Alternative : Tagless Final** — est-ce plus facile à compiler vers Lua ? Moins de overhead ?

### Axe 4 : Exemples concrets dans d'autres domaines

Je cherche des précédents où quelqu'un a compilé un langage fonctionnel de haut niveau vers un langage de scripting contraint :

- **Elm → JavaScript** : Elm compile un langage fonctionnel pur vers JS. Quelles techniques utilisent-ils ? IR ? Optimisations ? Comment gèrent-ils les effets (Elm a un système d'effets builtin) ?
- **PureScript → JavaScript** : Le backend JS officiel de PureScript. Comment compile-t-il les monades, type classes, ADT ? Qualité du JS généré ?
- **GHC → JavaScript** : `ghcjs` ou `asterius` (GHC → WebAssembly). Comment gèrent-ils le runtime (lazy evaluation, GC, threads) ?
- **OCaml → JavaScript** : `js_of_ocaml`. Techniques de compilation ? Optimisations ?
- **F# → JavaScript** : `Fable`. Comment compile-t-il les discriminated unions, pattern matching, computation expressions (monades) vers JS ?
- **Idris → Lua** : Existe-t-il un backend Lua pour Idris ou Idris 2 ?
- **Agda → Lua** : Quelqu'un a-t-il fait un backend Lua pour Agda (probablement non, mais je demande) ?

### Axe 5 : Le cas spécifique WoW — contraintes dures

Le Lua généré doit respecter ces contraintes NON NEGOCIABLES :

1. **Lua 5.1** (pas 5.2, pas 5.3, pas JIT-only features)
2. **Pas de `require` standard** — WoW charge via `.toc` files
3. **Pas de `goto`** — pas disponible en 5.1
4. **Max 60 upvalues** par fonction — les closures Haskell génèrent beaucoup de closures imbriquées
5. **Budget CPU strict** — WoW tue les scripts qui prennent trop de temps par frame
6. **GC pressure** — les ADT compilés en tables créent beaucoup de garbage. Comment minimiser ?
7. **Interop avec `_G`** — les frames WoW, les événements, l'API Blizzard sont accessibles via `_G`
8. **Code lisible** — si un bug survient en jeu, on doit pouvoir lire le stack trace Lua

**La question clé** : est-il possible de compiler un langage fonctionnel typé vers du Lua 5.1 qui respecte ces contraintes SANS un surcoût runtime prohibitif ?

### Axe 6 : Projets existants à évaluer en détail

Pour chacun de ces projets, je veux savoir : statut, qualité du code généré, compatibilité Lua 5.1, overhead runtime, tooling :

1. **purescript-lua / pslua** (Unisay) — PureScript → Lua
2. **LunarML** (minoki) — Standard ML → Lua
3. **Amulet** (archivé mais instructif) — ML → Lua, quelles techniques de compilation ?
4. **Idris2-Lua** — si ça existe
5. **Nox** — langage FP typé → Lua
6. **lua_of_ocaml** — si ça existe
7. **Haxe LLVM target** — Haxe peut-il target LLVM puis Lua via un backend custom ?
8. **Crystal → Lua** — si un backend existe
9. **Carp → Lua** — si un backend existe
10. **Any "ML to Lua" compiler** sur GitHub, même expérimental

### Axe 7 : Le build-it-yourself path

Si aucun projet existant ne convient, je veux évaluer la faisabilité d'un compilateur custom :

**Stack Haskell :**
- `language-lua` pour l'AST + pretty-printer Lua 5.1
- `megaparsec` ou `parsec` pour le parsing du DSL (si on crée un langage custom)
- Ou utiliser GHC directement comme frontend (via GHC API / plugins)
- Quasiquotation pour les templates Lua (comme Yesod/Hamlet)
- Template Haskell pour la génération de code à la compilation

**Questions :**
- Quel est l'effort réaliste pour construire un compilateur "DSL Haskell → Lua 5.1" qui couvre les besoins de CraftGold (pas un compilateur général) ?
- Est-ce qu'un compilateur "scoped" (qui ne compile que les patterns CraftGold : fonctions pures, ADT simples, Free Monad pour les effets, données statiques) est beaucoup plus simple qu'un compilateur général ?
- Exemples de gens qui ont construit des compilateurs ciblés similaires ?
- Est-ce que l'approche "Template Haskell + language-lua" (génération de Lua à la compilation Haskell) est viable sans écrire un vrai compilateur ?

**Stack Scala :**
- Macros Scala 3 comme frontend
- AST Lua custom ou réutiliser un existant
- Questions similaires sur la faisabilité

## Format de réponse exigé

**Répondez ENTIÈREMENT en markdown dans un seul bloc texte.** Pas de fichiers séparés, pas d'artifacts. Tout inline.

Structurez ainsi :

```markdown
# Compilation Fonctionnelle vers Lua 5.1 — Recherche Ciblée

## Synthèse : Est-ce possible ? Est-ce raisonnable ?

## Axe 1 : Infrastructure Haskell/Scala/ML → Lua
### Outils existants
### Projets utilisant ces outils
### Analyse de faisabilité

## Axe 2 : IR et Optimisations
### IR existantes
### Optimisations essentielles pour Lua 5.1
### Defunctionalization, lambda lifting, unboxing

## Axe 3 : Free Monad / Tagless Final → Lua
### Comment compiler une Free Monad vers Lua
### Overhead runtime
### Code généré (exemples)
### Alternative : Tagless Final

## Axe 4 : Précédents (Elm, PureScript, GHCJS, js_of_ocaml, Fable)
### Techniques de compilation
### Leçons applicables à Lua

## Axe 5 : Contraintes WoW — faisabilité
### Analyse point par point des 8 contraintes

## Axe 6 : Projets existants évalués
### Pour chaque projet : statut, qualité, compatibilité 5.1, overhead

## Axe 7 : Build-it-yourself
### Stack Haskell : faisabilité et effort
### Stack Scala : faisabilité et effort
### Le "compilateur scoped" : combien de travail ?

## Recommandation finale

## Sources (URLs pour chaque affirmation)
```

## Ambition

Je ne veux pas entendre "utilise TypeScript". Je veux savoir si on peut **réellement** compiler du Haskell/Scala/ML de haut niveau vers du Lua 5.1 qui tourne dans WoW, quels sont les obstacles techniques concrets (upvalues, GC, closures), et comment les contourner. Si c'est impossible, dites-le avec des preuves. Si c'est possible mais cher, dites combien. Si c'est possible et raisonnable, montrez comment.

**Faites trois fois le tour d'Internet.** Cherchez sur Hackage, GitHub, academic papers (ICFP, POPL, IFL), blog posts de chercheurs en compilation, discussions sur r/ProgrammingLanguages, r/haskell, Lambda the Ultimate, etc.

Soyez techniques. Je connais Haskell, Scala, la théorie des compilateurs. Ne m'expliquez pas ce qu'est une monade — dites-moi comment la compiler vers Lua.
