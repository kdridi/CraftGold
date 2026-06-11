# Compilation Fonctionnelle vers Lua 5.1 — Recherche Ciblée

## Synthèse : Est-ce possible ? Est-ce raisonnable ?

Oui, c'est possible — mais la question cache deux problèmes très différents, et la distinction est le résultat le plus important de cette recherche :

1. **Compiler un langage fonctionnel général vers Lua 5.1** (le modèle LLVM : frontend complet → IR → backend). Des précédents existent (LunarML, Amulet, pslua, Idris2-Lua), mais aucun ne coche les 8 contraintes WoW telles quelles. Le plus proche du « production-ready » (LunarML) cible Lua 5.3+, pas 5.1. Coût d'adaptation : modéré à élevé selon le projet.

2. **Générer du Lua 5.1 depuis un EDSL Haskell stagé** (le modèle Yesod/Hamlet, ou plus précisément le modèle Feldspar/Ivory : EDSL Haskell → C). C'est la voie que je recommande pour CraftGold, et l'insight central est celui-ci : **ne compilez pas la Free Monad vers Lua — exécutez-la à la compilation Haskell pour émettre du Lua de premier ordre**. La monade n'existe qu'au moment de la génération ; le Lua produit est impératif, plat, sans closures monadiques, sans overhead. C'est de l'évaluation partielle à deux niveaux, exactement la technique de « Finally Tagless, Partially Evaluated » (Carette/Kiselyov/Shan, JFP 2009) et de « Compiling to Categories » (Elliott, ICFP 2017), appliquée avec Lua comme langage objet.

Le « surcoût runtime prohibitif » que vous craignez n'est pas une fatalité : il provient presque entièrement de trois décisions de compilation (currying naïf, bind monadique réifié en closures, ADT systématiquement alloués en tables). Les trois ont des contre-mesures connues (uncurrying/arity analysis, compilation « magic-do » du bind vers des statements, retours multiples Lua + singletons de constructeurs). Un compilateur *scoped* qui applique ces trois mesures produit du Lua comparable à du Lua écrit main.

---

## Axe 1 : Infrastructure Haskell/Scala/ML → Lua

### Outils existants (Haskell)

**`language-lua`** est exactement ce qu'il faut comme couche basse. C'est un lexer, parser et pretty-printer pour Lua 5.3, maintenu sur Hackage (mainteneurs EricMertens — l'auteur de glguy/lua tooling — et OmerAgacan/osa1). Points clés pour votre usage :

- L'AST couvre Lua 5.3, qui est un **sur-ensemble syntaxique strict** de 5.1 pour ce qui vous concerne : l'AST contient `Goto`, `Label`, les opérateurs bit à bit et la division entière — autant de nœuds que votre codegen ne doit **jamais émettre**. L'AST ne vous protège pas par construction : la discipline « 5.1-safe » doit être un invariant de votre générateur. Contre-mesure simple et robuste : un pass de validation sur l'AST émis (refuser `Goto`/`Label`/`IDiv`/ops binaires) + dans la CI, compiler chaque fichier généré avec `luac` 5.1.4 (le vrai). Ce double verrou coûte une après-midi.
- Le pretty-printer est utilisable en production (c'est l'infrastructure dont Amulet s'est inspiré, et osa1 — auteur original de language-lua — est aussi l'auteur de psc-lua).
- Maturité : le parser est très solide (testé sur de gros corpus Lua) ; le pretty-printer produit du code lisible. Pour de la *génération* pure, vous n'utilisez que `Syntax` + `PrettyPrinter`, la partie la plus stable.

**`hslua` / `lua`** : hors sujet pour vous. Ces paquets servent à *embarquer* l'interpréteur Lua dans un process Haskell (le cas d'usage canonique est pandoc). Utilité indirecte réelle cependant : **tester votre Lua généré depuis votre suite de tests Haskell** — vous générez, vous chargez dans un état hslua lié à liblua 5.1, vous comparez avec l'interprétation pure de référence. C'est le golden-testing différentiel idéal, et c'est exactement ce que fait pslua avec ses golden tests (compilation de modules PureScript de test vers Lua, comparés à des fichiers golden, plus `luacheck` sur la sortie).

### Projets utilisant ces outils comme backend de compilation

Oui, le pattern « Haskell génère du Lua source » existe :

- **psc-lua** (osa1, 2014) : backend Lua pour PureScript, historique, mort, ciblait PS 0.5.x. Instructif : la discussion d'origine sur le tracker PureScript (#339) contient une réflexion lucide sur le besoin d'une IR intermédiaire pour les optimisations, avec des nœuds dédiés (le backend Lua pouvant ignorer l'annotation TCO puisque Lua a déjà les tail calls), et note que Lua n'a pas d'expression conditionnelle ternaire — d'où la tension entre IR fonctionnelle et IR impérative. Ce point (absence de `?:` en Lua) est un détail qui structure tout un codegen : toute expression conditionnelle doit être soit hissée en statement avec une variable temporaire, soit encodée en `cond and x or y` (piégeux si `x` peut être `false`/`nil`).
- **Amulet** (amuletml) : compilateur **écrit en Haskell** qui émet du Lua. C'est votre meilleur précédent architectural même s'il est abandonné. Il avait son propre Core typé (System F-ω-like) avec un vrai optimiseur ; la doc affirme que le coût des closures issues du sucre fonctionnel est agressivement optimisé par le compilateur. Son FFI est le bon design : `external val` avec une expression Lua entre guillemets, syntax-checkée et pretty-printée par le compilateur — c'est-à-dire que le texte FFI passe par le parser Lua. Reprenez cette idée telle quelle pour l'API WoW.
- **Oczor** : langage Haskell-like (typeclasses incluses) compilant vers Lua/JS/elisp, expérimental et abandonné — preuve de concept de plus que c'est faisable en quelques milliers de lignes de Haskell, pas un outil utilisable.

### Scala

État des lieux : **rien d'utilisable**. Pas d'équivalent de `language-lua` publié sur Maven Central digne de ce nom, pas de projet Scala → Lua actif. Les macros Scala 3 (inline + quotes/splices) sont théoriquement un excellent frontend de staging — c'est le même mécanisme que MetaOCaml en plus ergonomique — mais vous écririez vous-même : l'AST Lua (1-2 jours), le printer (2-3 jours), toute la couche d'encodage. Le différentiel avec Haskell : en Haskell vous récupérez `language-lua` gratuitement, des précédents (Amulet, pslua) à lire, et GHC.Generics/Template Haskell pour dériver les encodages d'ADT. Verdict : possible, mais vous partez de plus loin pour zéro gain.

### OCaml / Standard ML

- **`lua_of_ocaml` n'existe pas.** Les discussions sur discuss.ocaml.org concluent que c'est un vrai projet de compilateur ; la piste évoquée est Rehp, un fork de js_of_ocaml conçu pour ajouter PHP comme cible, potentiellement réutilisable pour Lua — personne ne l'a fait. À noter, l'auteur du thread a fini par abandonner la transpilation OCaml→Lua au profit d'un EDSL générateur de code — il a convergé vers la même conclusion que ma recommandation.
- **LunarML** (détails complets en Axe 6) : c'est le seul compilateur ML→Lua « sérieux » vivant. Il implémente tout SML '97, y compris le système de modules — donc oui, foncteurs et signatures compilent vers Lua, via défonctorisation à la MLton (les foncteurs sont éliminés statiquement, pas représentés au runtime ; c'est la bonne nouvelle : l'abstraction modulaire SML est *gratuite* au runtime). **Mais** : par défaut LunarML produit du code pour Lua 5.3/5.4, avec une option --luajit. Pas de cible 5.1. La cible LuaJIT est la plus proche (LuaJIT = sémantique 5.1) mais LuaJIT accepte `goto` et `bit.*`, que WoW n'a pas — il faudrait auditer/patcher le backend. C'est un travail de contribution upstream réaliste (le projet est actif et bien écrit en SML), pas un fork lourd.

### Analyse de faisabilité (Axe 1)

L'infrastructure Haskell est suffisante et éprouvée : `language-lua` comme cible, golden tests via luacheck/luac/hslua, précédents lisibles (Amulet est la meilleure base de code à étudier — c'est du Haskell, archivé mais complet). Scala est un désert. OCaml n'a rien de direct mais LunarML couvre le besoin si SML vous convient.

---

## Axe 2 : IR et Optimisations

### IR existantes

**PureScript CoreFn** : c'est l'IR de sérialisation officielle de PureScript (lambda-calcul désucré, typé-effacé, sans optimisation). pslua consomme CoreFn et supporte DCE et inlining, avec sortie en modules Lua ou en application standalone. Important : CoreFn arrive **non optimisé** — toute la qualité du code dépend du backend. Le backend JS officiel fait peu ; l'écosystème a produit `purescript-backend-optimizer` (inlining agressif, élimination des dictionnaires de typeclasses, « magic-do ») mais il émet du JS — il n'est pas branchable devant pslua. Donc avec pslua, vous avez DCE + inlining maison, niveau de sophistication alpha.

**GHC Core → Lua : personne ne l'a fait**, et il y a une raison structurelle. GHC Core est *façonné par la laziness* : la compilation passe par STG, et tout backend GHC alternatif (GHCJS, le backend JS officiel de GHC 9.6+, Asterius pour Wasm) embarque **un runtime complet** — thunks, graph reduction, GC simulée, gestion d'exceptions. GHCJS ne « compile pas Haskell vers JS », il porte le RTS de GHC en JS et compile STG vers des appels à ce RTS. L'équivalent Lua serait un runtime de plusieurs milliers de lignes, avec une pression GC catastrophique (chaque thunk = une table + closure). Pour un addon WoW : **éliminatoire**. C'est l'argument décisif contre « Haskell-le-langage comme frontend via GHC API » : la sémantique lazy n'est pas négociable dans Core.

**CPS** : LunarML l'utilise — mode CPS sur le backend JS pour les continuations délimitées, et une cible `--lua-continuations` qui supporte les continuations délimitées one-shot. La leçon pour Lua est la vôtre : **les coroutines Lua rendent le CPS largement inutile**. Une coroutine Lua 5.1 est une continuation one-shot native. Pour CraftGold c'est même la technique idiomatique cruciale : un scan de l'hôtel des ventes se structure en coroutine `resume`-ée dans un handler `OnUpdate` avec budget temps par frame (c'est ce que font les addons AH sérieux depuis 2008). Concrètement : votre DSL d'effets gagne à exposer un combinateur `yield`/`await` compilé vers `coroutine.yield`, plutôt qu'une transformation CPS globale qui détruirait la lisibilité et les stack traces.

**IR fonctionnelle « légère » réutilisable ciblant Lua** : ça n'existe pas en tant qu'artefact indépendant. Chaque projet (LunarML, Amulet, pslua) a la sienne. Si vous construisez, votre IR naturelle est un ANF/let-normal form typé (pas du CPS) : l'ANF se traduit ligne à ligne en statements Lua avec des `local`, ce qui donne directement du code lisible.

### Optimisations : essentielles / possibles / impossibles pour Lua 5.1

**Essentielles** (sans elles, inutilisable dans WoW) :

1. **Uncurrying / arity raising.** Le poison n°1. `f a b c` compilé naïvement = 3 closures intermédiaires + 3 appels par invocation. Tous les compilateurs sérieux (MLton, LunarML, Amulet, Fable) détectent l'arité réelle et émettent `function f(a, b, c)`. Sans ça, votre budget CPU WoW explose immédiatement.
2. **Compilation du bind monadique en statements** (« magic-do »). `m >>= \x -> ...` ne doit jamais devenir une closure au runtime quand l'interprète est connu statiquement. PureScript/JS l'a appris à ses dépens : `Effect` y est représenté par des thunks `() -> a` et l'optimisation magic-do inline `bind`/`pure` en séquences de statements. Dans l'approche stagée (Axe 3), ce problème disparaît par construction.
3. **Compilation du pattern matching en arbres de décision** (Maranget 2008) : `if t.tag == "Cons" then ... elseif ...` imbriqués, avec partage des tests. Trivial à bien faire sans `goto` : les branches partagées deviennent des fonctions locales nommées (ce qui aide aussi la lisibilité des traces). Note : Lua 5.1 sans `goto` interdit l'astuce classique « jump to shared failure branch » ; le repli standard est `local function fail_k() ... end` appelé en position tail — coût nul grâce aux tail calls.
4. **Tail calls syntaxiques.** Lua 5.1 a les *proper tail calls* natifs : `return f(x)` ne consomme pas de frame. Donc la récursion terminale est gratuite **si** votre codegen émet la forme exactement syntaxique `return f(...)`. Revers : les frames disparaissent des stack traces — pour votre contrainte n°8, prévoyez un mode debug qui désactive la forme tail (`local r = f(x); return r`).
5. **DCE au niveau des bindings top-level** : indispensable parce que votre prélude (Prelude/Data.List/etc.) ne doit pas finir intégralement dans le .lua embarqué. pslua le fait ; c'est non négociable pour la taille de l'addon.
6. **Cache des globals** : `local GetItemInfo = GetItemInfo` en tête de fichier. Optimisation WoW standard (l'accès global = hash lookup dans `_G` à chaque appel ; le local = registre). Votre codegen doit le faire automatiquement pour chaque fonction d'API utilisée — bonus : ça réduit la surface d'interaction avec le taint system.

**Possibles / rentables** :

- **Defunctionalization (Reynolds)** : transformer les fonctions d'ordre supérieur en `{tag=..., env...}` + un `apply` dispatché. Verdict nuancé : ce n'est **pas** la bonne réponse au problème des upvalues (voir ci-dessous), et ça dégrade la lisibilité et le branch-predictor de l'interpréteur Lua (un gros `if/elseif` dans `apply`). À réserver aux cas où vous devez *sérialiser* des fonctions (SavedVariables WoW !) — là, c'est la seule solution, et c'est un argument inattendu en sa faveur pour CraftGold si vous voulez persister des « stratégies » dans les SavedVariables.
- **Lambda lifting (Johnsson)** : hisser les variables libres en paramètres, transformer les closures en fonctions top-level. Rentable pour les closures non échappantes ; pour les autres, voir « consolidation d'environnement » ci-dessous.
- **Fusion** : dans un compilateur général, ça demande des rewrite rules à la GHC (`stream fusion`, Coutts et al.) — cher. **Dans un EDSL stagé, c'est presque gratuit** : vos combinateurs `map`/`filter`/`fold` manipulent des descriptions de boucles, et `fold f z (filter p (map g xs))` se génère naturellement en *une* boucle `for i = 1, #xs do` sans listes intermédiaires. C'est l'un des arguments les plus forts pour l'approche stagée : la fusion est structurelle, pas heuristique.
- **Unboxing des ADT** : faisable au cas par cas. `newtype` : effacement total (gratuit). `Maybe a` → `nil | a` : **seulement si** le système de types garantit `a` non-nullable — sinon `Just Nothing` et `Nothing` se confondent ; c'est le footgun classique (Fable l'a vécu avec `option<option<T>>` en JS et a dû boxer le cas imbriqué). Faites-le de façon dirigée par les types : votre compilateur sait si `a` peut être habité par une représentation `nil`. `Either`/ADT à champs : `{tag, v1, v2}` positionnel (array part de la table, accès indexé plus rapide et moins de mémoire que des champs nommés dans le hash part). Constructeurs nullaires : **singletons globaux** (une seule table `Nothing` partagée) — réduction massive du garbage. Et l'arme spécifique Lua : **les retours multiples**. Une fonction renvoyant `(Bool, Int, String)` doit compiler vers `return ok, n, s`, pas vers une table — zéro allocation. L'API WoW elle-même est conçue ainsi (`GetItemInfo` renvoie ~17 valeurs) ; votre FFI doit mapper multiret ↔ types produits nativement.

**Impossibles / hors de portée en 5.1** :

- Tout ce qui requiert `goto` (certains schémas de compilation de match/loops — contournables, voir plus haut).
- Le contrôle fin de la GC (vous avez `collectgarbage("step")` mais WoW pilote la GC ; votre seul levier réel est *allouer moins*).
- L'unboxing au-delà de ce que Lua offre : les nombres sont déjà unboxés (doubles), les strings internées et immuables. Pas d'int 64 fiable — en Lua 5.1/5.2, pas d'entiers 64 bits, précision max 52 bits (le double). Pour CraftGold : les sommes de cuivre tiennent largement en 2^52, non-problème, mais à documenter.

### Le problème des 60 upvalues, traité sérieusement

Lua 5.1 limite à 60 upvalues par fonction (erreur de compilation au-delà), et à 200 les variables locales par fonction — et la limite des 200 locals frappe **aussi le chunk top-level**, ce qui est le vrai danger pour du code généré : un module avec 200+ bindings top-level compilés en `local` ne charge pas (CASTL, le compilateur JS→Lua, s'est cassé exactement là-dessus).

Contre-mesures, par ordre de simplicité :

1. **Sharding des bindings de module** : au-delà de ~150 locals dans un chunk, basculer les bindings dans une table de namespace (`local M = {}; M.foo = ...`). Coût : un lookup table au lieu d'un accès registre — mesurable mais faible ; appliquer seulement au-delà du seuil, et re-localiser (`local foo = M.foo`) dans les fonctions chaudes.
2. **Consolidation d'environnement** : une closure qui capturerait N variables capture *une* table `env` (1 upvalue). C'est la transformation « closure conversion avec environnement explicite » — exactement ce que fait un compilateur vers C. À n'appliquer qu'aux fonctions dépassant le seuil : en pratique, du code uncurryfié et lambda-lifté n'approche presque jamais 60 upvalues ; ce sont les chaînes de binds monadiques réifiées qui les produisent — encore un problème que le staging élimine à la racine.
3. Lambda lifting (déjà cité) pour les closures dont toutes les variables libres sont disponibles aux sites d'appel.

---

## Axe 3 : Free Monad / Tagless Final → Lua

### Les deux lectures du problème

Votre exemple `WowF`/`runLua :: WowM a -> LuaCodeGen a` mélange implicitement deux architectures qu'il faut séparer :

**(A) La Free Monad vit au runtime, en Lua.** Vous compilez la structure `Free` elle-même (constructeurs `Pure`/`Free` en tables Lua), plus un interpréteur-trampoline Lua qui la déroule. Overhead par opération : 1 table de constructeur + 1 closure de continuation + 1 dispatch — soit ~3 allocations GC et 2 appels indirects *par bind*. Le code généré est un spaghetti de closures, les stack traces sont illisibles (tout passe par `interpret`), et la gauche-associativité des binds donne le coût quadratique classique (mitigable par codensity/freer, au prix de plus de closures encore). **Verdict : viable uniquement pour de l'orchestration basse fréquence** (quelques dizaines/centaines d'opérations par frame — ce qui, honnêtement, pourrait suffire pour la logique métier de CraftGold, les scans AH étant bornés par le serveur, pas par le CPU). Mais ça viole votre contrainte n°8 (lisibilité) et stresse la n°6 (GC). Personne n'a publié de « Free Monad runtime en Lua pour WoW » ; les plus proches sont les libs promise/async Lua (qui sont des monades de continuation déguisées) — et la communauté WoW a systématiquement convergé vers les coroutines à la place, pour ces exactes raisons.

**(B) La Free Monad vit à la compilation, en Haskell — staging.** `runLua` n'est pas un compilateur de Free Monad : c'est un **interpréteur résidualisant**. Vous exécutez le programme `WowM a` en Haskell, mais les valeurs manipulées sont *symboliques* — des expressions Lua, pas des valeurs. Chaque instruction émet des statements ; les continuations Haskell sont appliquées à des `LuaExpr` (typiquement, le nom d'un `local` frais) et se déroulent **pendant la génération**. Le résultat :

```haskell
program :: WowM ()
program = do
  info <- getItemInfo (itemId 2589)   -- Linen Cloth
  case_ info
    (print_ "unknown item")
    (\i -> print_ ("vendor: " <> showCopper (vendorPrice i)))
```

génère :

```lua
local _name, _, _, _, _, _, _, _, _, _, _vendorPrice = GetItemInfo(2589)
if _name == nil then
  print("unknown item")
else
  print("vendor: " .. FormatCopper(_vendorPrice))
end
```

Zéro monade au runtime. Zéro closure. Le `do` Haskell n'est qu'une notation pour séquencer l'émission de code.

### Les trois difficultés réelles du staging (et leurs solutions connues)

C'est un territoire académiquement balisé — c'est littéralement le programme de recherche MetaOCaml/tagless-final, et la lignée d'EDSL Haskell-vers-C (**Feldspar**, **Ivory**, **Copilot**, **Atom**) l'a industrialisé. Les trois problèmes que vous rencontrerez :

1. **Le branchement sur des valeurs runtime.** Vous ne pouvez pas écrire `case info of Nothing -> ...` sur un `info :: LuaExpr (Maybe ItemInfo)` — Haskell ne connaît pas sa valeur. D'où le combinateur `case_`/`if_` explicite ci-dessus, qui émet un `if` Lua et génère *les deux* branches. C'est la perte d'ergonomie principale vs « écrire du vrai Haskell » : votre DSL est un langage à deux niveaux, et le programmeur doit savoir quel `if` est lequel. (Les `if` Haskell ordinaires restent disponibles — ils deviennent de la spécialisation à la compilation, ce qui est une *feature* : c'est votre méta-programmation gratuite.)
2. **Le partage (let-insertion).** `let x = expensive in x + x` au niveau symbolique duplique l'expression Lua si vous êtes naïf. Solution standard : un combinateur `let_ :: LuaExpr a -> (LuaExpr a -> Gen b) -> Gen b` qui émet un `local` frais — plus, si vous voulez le confort, du sharing-recovery par observation (à la Accelerate/Kansas Lava) ; pour un projet scoped, le `let_` explicite suffit largement.
3. **Les boucles et la récursion.** Vous ne pouvez pas dérouler une récursion non bornée à la génération. Le DSL doit fournir `for_`, `while_`, `forEachPair` (→ `for k, v in pairs(t)`), et un `fix`/fonction nommée pour la récursion résiduelle. Là encore : Feldspar/Ivory ont exactement ces combinateurs ; copiez leur design.

### Free Monad ou Tagless Final pour ça ?

**Tagless final est structurellement supérieur ici**, pour des raisons précises :

- Avec une classe `class WowSym repr where getItemInfo :: repr ItemId -> ...`, vous écrivez vos deux interpréteurs comme deux instances : `instance WowSym TestM` (pur, MockDB — vos tests) et `instance WowSym LuaGen` (résidualisant). Le dispatch est résolu à la compilation Haskell : zéro réification, zéro normalisation de binds, zéro coût quadratique, pas besoin de GADT d'instructions à maintenir.
- La Free Monad réifie l'arbre du programme — utile uniquement si vous voulez l'*inspecter/transformer* avant interprétation (réordonnancement d'effets, batching d'appels API à la Haxl). Si CraftGold veut un jour batcher des `GetItemInfo` ou mettre en cache automatiquement, la structure libre (ou plutôt une **Free Applicative** pour les sections sans dépendances de données) redevient pertinente. Architecture pragmatique : tagless final comme interface, avec une instance « réifiante » vers Free quand une analyse est nécessaire — vous avez les deux.
- Overhead comparé : tagless final stagé = identique au staging Free (zéro au runtime Lua) ; mais la *génération* est plus simple et plus rapide, et le code Haskell est plus court.

La réponse à « quelqu'un l'a-t-il fait pour Lua ? » : pas publiquement à ma connaissance pour Lua spécifiquement — mais c'est exactement le schéma Feldspar (Haskell→C, Ericsson), Ivory (Haskell→C, Galois, code embarqué critique), et côté quasi-quotation, le schéma Yesod que vous citez. La nouveauté de votre projet est la cible, pas la technique. Le risque technique est faible.

---

## Axe 4 : Précédents (Elm, PureScript, GHCJS, js_of_ocaml, Fable, Idris)

**Elm → JS.** Pas d'IR d'optimisation générale : codegen assez direct depuis l'AST typé, DCE au grain de la déclaration (le fameux « small assets »), ADT compilés en objets `{$: tag, a, b}` avec champs positionnels, currying avec fonctions spécialisées `F2`/`F3`/`A2`/`A3` pour court-circuiter les applications saturées (technique directement transposable en Lua : `A2(f, x, y)` teste l'arité et appelle directement), tail-call elimination *uniquement* pour l'auto-récursion directe (réécrite en `while`). Les effets : pas compilés — gérés par un petit runtime (managed effects). Leçons pour Lua : le couple « champs positionnels + dispatch sur tag + DCE par déclaration » est le sweet spot lisibilité/perf, et l'astuce F2/A2 résout le currying résiduel à coût borné.

**PureScript → JS.** Typeclasses → dictionnaires (records de fonctions) passés en arguments — c'est le coût caché majeur : sans inlining des dictionnaires, chaque `map` générique fait deux indirections. Monades → ordinaires fonctions ; `Effect a` = thunk `() -> a` ; l'optimisation « magic-do » inline `bind`/`discard` en séquences de statements. La leçon n°1 pour vous : **les typeclasses doivent être spécialisées/monomorphisées à la compilation** autant que possible (LunarML, étant whole-program comme MLton, monomorphise ; PureScript non, et le paie).

**GHCJS / backend JS de GHC.** Porte le RTS entier (thunks, évaluation paresseuse, scheduler de threads légers, exceptions) en JS ; STG → appels au RTS. Sortie volumineuse, opaque, pression mémoire élevée. Confirme : **la laziness est le tueur**, ne prenez jamais un frontend lazy pour cibler Lua/WoW.

**js_of_ocaml.** Compile le *bytecode* OCaml (pas le source) vers JS via sa propre IR avec un vrai optimiseur (inlining, DCE, spécialisation). Marche remarquablement bien parce qu'OCaml est strict et que son modèle de données (blocs taggés) se mappe sur les arrays JS — exactement comme il se mapperait sur les tables Lua `{tag, ...}`. C'est la preuve d'existence que « ML strict → langage dynamique » est un mariage heureux ; le portage Lua n'a juste jamais été financé.

**Fable (F# → JS).** AST typé F# → IR Fable → AST Babel. Unions discriminées → classes avec tag entier + champs ; pattern matching → switch/if sur le tag ; computation expressions (les « monades » F#) **désucrées en appels de méthodes du builder dès le frontend**, puis inlinées — c'est le précédent le plus proche de « compiler le do-notation vers des statements plats ». `option<T>` unboxé en `T | null` avec boxing du cas imbriqué (le footgun Maybe évoqué en Axe 2, et sa solution).

**Idris → Lua : oui, ça existe.** Idris2-Lua (Russoul), backend Lua officiel-externe pour Idris 2, qui demande de spécifier la version cible via une variable `LuaVersion` valant 5.1, 5.2 ou 5.3 — donc **support 5.1 explicite**, le seul de toute cette liste. Le README est honnête sur le fond : les limites de Lua sur les variables locales et les structures imbriquées ont forcé des choix de design qui dégradent la performance (il a affronté vos contraintes n°4 et les 200 locals frontalement). Dépendances : bigint et lua-utf8 — problématique pour WoW (pas de luarocks in-game ; il faudrait vendorer et probablement élaguer bigint). Dernière activité ~2022 : stale. Agda → Lua : n'existe pas, confirmé par l'absence totale de traces.

---

## Axe 5 : Contraintes WoW — analyse point par point

1. **Lua 5.1.** Aucun outil sur étagère ne garantit du 5.1 pur sauf Idris2-Lua (stale) et Haxe (Lua 5.1, 5.2, 5.3 et LuaJIT supportés, mais avec des libs supplémentaires recommandées — dont bit32 sur 5.1, à vendorer pour WoW ; précédent réel : haxecraft, démo Haxe/Lua d'addon WoW</parameter>... et le thread d'époque confirme que le support Lua 5.1 et le multireturn ont été ajoutés à Haxe précisément pour le scripting WoW). En custom : trivial à garantir (validation AST + luac 5.1 en CI). N'oubliez pas les spécificités WoW au-delà de 5.1 : pas de `io`/`os` (partiel), `loadstring` taint-sensible, et quelques extensions Blizzard (`strsplit`, `table.wipe`, `bit` lib présente côté WoW — vous *avez* en fait une lib bit in-game).
2. **Pas de `require`.** Solution universelle : bundler. Soit un fichier unique (pslua sait émettre une application standalone), soit N fichiers listés dans le .toc partageant le namespace privé d'addon via `local ADDON_NAME, ns = ...`. Votre codegen émet chaque module comme `ns.M_CraftGold_Scan = (function() ... end)()` — ordre topologique calculé à la compilation, déterministe, lisible. Problème entièrement soluble, 2-3 jours de travail.
3. **Pas de `goto`.** Impacte uniquement les *schémas* de codegen (match, `continue`). Repli : fonctions locales en position tail (coût nul, cf. tail calls 5.1) et l'idiome `repeat ... until true` + `break` pour `continue`. Soluble proprement.
4. **60 upvalues / 200 locals.** Traité en Axe 2 : sharding des modules, consolidation d'environnement, lambda lifting. Avec uncurrying + staging (pas de chaînes de binds réifiées), vous n'approcherez ces limites que dans le top-level des gros modules — le sharding automatique au-delà d'un seuil règle le cas. Risque résiduel : faible, mais mettez le check dans le validateur AST (compter locals/upvalues statiquement, c'est mécanique).
5. **Budget CPU.** Précision factuelle : WoW ne tue pas les scripts d'addon ordinaires par frame — il *gèle la frame* (et le watchdog ne frappe que certains contextes restreints) ; la sanction est l'expérience utilisateur, pas un kill. La discipline : coroutines + time-slicing (`debugprofilestop()` pour mesurer le budget consommé, `yield` au-delà de ~2-5 ms, reprise au prochain `OnUpdate`). Votre DSL d'effets devrait avoir un combinateur `checkpoint` compilé en test-budget-et-yield. Avec uncurrying, magic-do et fusion, le Lua généré est dans la même classe de perf que du Lua manuel — pas de surcoût prohibitif, à condition de refuser l'option (A) de l'Axe 3 pour les chemins chauds.
6. **Pression GC.** Le levier dominant : singletons de constructeurs nullaires + retours multiples au lieu de tuples + fusion (pas de listes intermédiaires) + pas de closures par bind. Mesure d'appoint : `tableau de structs → struct de tableaux` pour les gros datasets (scans AH : stockez `prices[i], counts[i], itemIds[i]` en trois arrays plutôt que 10 000 tables `{price=, count=, itemId=}` — c'est 10 000 allocations contre 3, et c'est le genre de représentation qu'un compilateur dirigé par les types peut choisir automatiquement pour les types produits homogènes en masse).
7. **Interop `_G`.** Design FFI à la Amulet/PureScript : déclarations externes typées par fonction d'API, compilées en appel direct (jamais de wrapper générique), avec mapping natif multiret↔produits et `nil`↔Maybe contrôlé. Les frames/événements : exposez `CreateFrame`, `RegisterEvent`, `SetScript` comme effets du DSL ; les handlers sont des fonctions du DSL compilées en closures Lua nommées (lisibilité des traces). Le taint system ne vous concerne quasiment pas (CraftGold ne touche pas aux fonctions protégées de combat).
8. **Lisibilité.** C'est là que le custom scoped écrase les compilateurs généraux : vous contrôlez le nommage (préserver les noms source), vous émettez des statements ANF (une opération par ligne), vous insérez des commentaires `-- CraftGold/Scan.hs:42`, et vous avez un mode debug sans tail calls. LunarML/Idris2-Lua produisent du code correct mais machinique (noms mangled, registres numérotés).

**Réponse à la question clé** : oui, sans surcoût prohibitif — *à condition* que le langage source soit strict, que le compilateur uncurryfie et compile les effets en statements, et que les ADT exploitent multiret/singletons. Toutes ces conditions sont automatiquement réunies dans l'approche EDSL stagée ; elles sont partiellement réunies dans LunarML/pslua.

---

## Axe 6 : Projets existants évalués

**1. purescript-lua / pslua (Unisay).** Statut : alpha, PureScript 0.15.9, développement par à-coups. Architecture saine : CoreFn → Lua, avec DCE, inlining, FFI Lua, sortie module ou standalone, golden tests luacheck-és, intégration Spago comme backend custom. Compatibilité 5.1 : non garantie contractuellement — le code émis est du Lua « plat » a priori portable, mais à auditer (et le runtime PS suppose des semantics d'entiers à vérifier). Overhead : dictionnaires de typeclasses non systématiquement éliminés + currying résiduel → s'attendre à du JS-PureScript-sans-backend-optimizer, transposé. Atout unique : c'est **le seul accès à un langage à typeclasses + HKT + do-notation ciblant Lua**. Pour vous : candidat sérieux si vous acceptez de contribuer (audit 5.1 + bundler WoW), avec le risque d'un projet à bus factor 1.

**2. LunarML (minoki).** Le plus mûr : actif, releases, SML '97 complet, modules/foncteurs, auto-hébergé (le standard library suffit à compiler LunarML lui-même), cibles --lua (5.3+), --lua-continuations (continuations délimitées one-shot), --luajit. Qualité du Lua : correcte, whole-program, uncurrying et monomorphisation à la MLton. Blocker : **pas de cible 5.1** ; la cible LuaJIT (sémantique 5.1) émet probablement `goto`/`bit.*` (LuaJIT les a, WoW non) — travail d'adaptation backend nécessaire, upstream-able vu la qualité du projet. Pas de typeclasses ni HKT (c'est SML) ; ADT/match/foncteurs/effets-par-modules : oui. Si « ML de haut niveau » vous suffit (vous citez OCaml dans votre liste), c'est l'option « compilateur général » la plus crédible.

**3. Amulet.** Officiellement abandonné (archivé, dernier commit 2021). Mais c'était le projet le plus ambitieux : types à la Haskell sur Lua — typeclasses multi-paramètres avec types associés et dépendances fonctionnelles, quantified constraints, Rank-N, types imprédicatifs via Quick Look, records extensibles par row polymorphism — avec optimiseur agressif sur un Core typé. À évaluer non comme outil mais comme **base de code de référence** (Haskell, ~30k lignes, lisible) : son pipeline frontend→Core→optimiseur→codegen Lua est le plan de votre Axe 7 déjà écrit. Reprendre/raviver Amulet est une option réelle mais c'est adopter un compilateur général orphelin — plus de surface que votre besoin.

**4. Idris2-Lua.** Existe, support 5.1 explicite, stale (~2022), dépendances bigint et lua-utf8 incompatibles WoW sans vendoring/élagage, perf « raisonnable » revendiquée avec des compromis assumés. Types dépendants dans un addon WoW : séduisant intellectuellement, déraisonnable opérationnellement (chaîne d'outils, taille de sortie, projet mort).

**5. Nox (coetaur0).** Langage fonctionnel statiquement typé avec inférence Hindley-Milner et row polymorphism, interpréteur + compilation vers Lua, implémenté en OCaml. Jeune, petit, expérimental, sans ADT riches ni écosystème. Pas au niveau d'expressivité que vous exigez (pas de typeclasses/HKT/GADT).

**6. lua_of_ocaml.** **N'existe pas.** Discussions OCaml : piste Rehp (fork js_of_ocaml multi-cibles) jamais concrétisée pour Lua.

**7. Haxe → Lua.** Cible Lua *officielle* du compilateur Haxe, versions 5.1 à 5.3 et LuaJIT supportées, et précédent WoW direct (haxecraft). Pas de route « Haxe → LLVM → Lua » (la cible Lua est un codegen AST direct ; LLVM n'apparaît nulle part et n'aurait aucun sens ici — LLVM IR est trop bas niveau pour ré-émettre du Lua lisible). Haxe a des enums-ADT (GADT-light), du pattern matching, des macros puissantes — mais ni HKT, ni typeclasses, ni monades ergonomiques. C'est le milieu de gamme que vous refuserez probablement, mais c'est le seul de la liste avec un support 5.1 *officiel et maintenu*.

**8-9. Crystal → Lua, Carp → Lua.** N'existent pas (Crystal → natif via LLVM ; Carp → C). Rien trouvé, même expérimental.

**10. Autres « ML to Lua » sur GitHub.** La liste hengestone/lua-languages recense l'essentiel : Hypatia (ML-like → Lua), oczor (Haskell-like → Lua/JS/elisp/Ruby), Lua-ML (ML basique), pumpkin (ML-like, backend Lua expérimental), LunarML, Idris2-Lua, purescript-lua, nox. Hypatia a un cas d'usage documenté sur Roblox (langage typé à la Elm/PureScript compilant vers Lua, fonctionnel dans Roblox via Rojo) ; tous ces projets sont des one-person-shows abandonnés ou dormants. Luml (Elm-like en OCaml) : explicitement gelé, conservé comme curiosité historique.

---

## Axe 7 : Build-it-yourself

### Stack Haskell — l'EDSL stagé (recommandé)

Architecture : pas de parser, pas d'inférence de types — **Haskell est votre frontend, GHC est votre typechecker**. Le « langage » est une bibliothèque :

- Couche 0 — AST + printer : `language-lua` tel quel, plus votre validateur 5.1 (compte des locals/upvalues, interdiction goto/bitops) et le pretty-printing commenté. *~3-5 jours.*
- Couche 1 — expressions typées : `newtype E a = E LuaExp` avec phantom types, instances `Num (E Int)`, opérateurs, accès tables typés, monade `Gen` (State pour les noms frais + Writer pour les statements), `let_`. *~1-2 semaines.*
- Couche 2 — contrôle : `if_`, `for_`, `whilst`, `forPairs`, fonctions nommées (`defun`), coroutines (`task`/`yieldBudget`). *~1 semaine.*
- Couche 3 — données : encodage des ADT dirigé par Template Haskell ou GHC.Generics (`deriveLua ''AuctionItem` génère constructeurs, `match_` exhaustif vérifié par le système de types via une église-encodage des branches, représentation positionnelle + singletons + multiret pour les retours). C'est le morceau le plus délicat. *~2-4 semaines.*
- Couche 4 — effets WoW : la classe tagless final `WowSym`, l'instance `Gen` (résidualisante) et l'instance pure de test ; externs typés pour la vingtaine de fonctions d'API dont CraftGold a besoin (GetItemInfo en multiret, QueryAuctionItems + événements AUCTION_ITEM_LIST_UPDATE modélisés en continuation/coroutine). *~1-2 semaines.*
- Couche 5 — bundler .toc + golden tests (luac 5.1 + exécution différentielle via hslua liée à Lua 5.1 + mock de l'API WoW en Lua). *~1 semaine.*

**Effort total réaliste : 2-3 mois à mi-temps pour une v1 solide**, sachant que les couches 0-2 donnent déjà de la valeur (vous pouvez générer les données statiques et les fonctions pures de CraftGold dès la semaine 3). Oui, le compilateur *scoped* est **massivement** plus simple qu'un compilateur général : vous supprimez parser, résolution de noms, inférence HM, classes, et 90 % de l'optimiseur (la fusion et le magic-do sont structurels dans un EDSL ; l'uncurrying est un non-problème puisque vos `defun` ont des arités explicites). Les précédents de compilateurs ciblés comparables sont exactement Feldspar, Ivory, Copilot, Atom (Haskell→C, tous nés de besoins applicatifs précis, tous de taille « une personne-année max ») — et côté quasi-quotation, le modèle Hamlet que vous citez. La variante « Template Haskell + quasiquoter Lua » (un `[lua| ... ]` avec antiquotations `#{...}` parsé par `language-lua` à la compilation) est viable et complémentaire : parfaite pour les fragments FFI et les templates de frames, insuffisante seule (pas d'abstraction sur le contrôle) — combinez-la avec l'EDSL plutôt que de choisir.

Le piège à éviter absolument : « utiliser GHC comme frontend » via GHC API/plugins pour compiler du *vrai* Haskell. Vous hériteriez de Core, donc de la laziness, donc du problème GHCJS (Axe 4). Ne le faites pas.

### Stack Scala

Même architecture possible (macros/inline de Scala 3 = staging très propre, les ADT Scala 3 + `derives` remplacent Template Haskell élégamment), mais : AST Lua + printer + validateur à écrire from scratch, zéro précédent, zéro outillage de test équivalent à hslua. Comptez +3-4 semaines vs Haskell pour un résultat équivalent. Justifiable uniquement si votre équipe est Scala-native.

---

## Recommandation finale

Pour CraftGold, dans l'ordre :

1. **Voie principale : l'EDSL Haskell stagé** (tagless final + `language-lua`, modèle Feldspar/Yesod). C'est la seule option qui satisfait les 8 contraintes *par construction* — 5.1 garanti par validateur, lisibilité contrôlée, zéro overhead monadique, fusion structurelle, coroutines de première classe pour le budget CPU — avec un effort borné (2-3 mois mi-temps) et un risque technique faible car académiquement et industriellement balisé. Vous gardez les tests purs en Haskell via la seconde interprétation, ce qui était votre motivation Free Monad initiale.
2. **Voie « compilateur général », si vous voulez écrire du *vrai* langage source** : LunarML + contribution d'une cible 5.1/WoW (projet actif, bien conçu, whole-program optimizer ; vous perdez les typeclasses/HKT mais gagnez les foncteurs SML, qui couvrent honnêtement le besoin d'abstraction d'un addon). Alternative : pslua si les typeclasses sont non négociables, en acceptant un statut alpha et un audit 5.1 à votre charge.
3. **À écarter avec preuves** : GHC→Lua (inexistant, et structurellement condamné par la laziness/RTS), lua_of_ocaml (inexistant), Agda/Crystal/Carp→Lua (inexistants), Free Monad interprétée au runtime Lua pour les chemins chauds (overhead allocatoire et illisibilité — réservez-la, en version freer, à l'orchestration ou à la sérialisation de stratégies dans les SavedVariables), Idris2-Lua (5.1 supporté mais projet stale + dépendances incompatibles WoW).

## Sources

- pslua (Unisay/purescript-lua) : https://github.com/Unisay/purescript-lua — architecture CoreFn/DCE/inlining : https://github.com/Unisay/purescript-lua/blob/main/CLAUDE.md — statut alpha : https://github.com/purescript/documentation/blob/master/ecosystem/Alternate-backends.md
- psc-lua historique et discussion IR : https://github.com/osa1/psc-lua ; https://github.com/purescript/purescript/issues/339
- LunarML : https://github.com/minoki/LunarML ; annonce et cibles Lua 5.3/5.4/LuaJIT : https://minoki.github.io/posts/2023-12-17-lunarml-release.html ; https://github.com/minoki/LunarML/releases
- Amulet (archivé, features de types, optimisation des closures, FFI) : https://github.com/amuletml/amulet ; https://amulet.works/tutorials/01-intro.html ; https://andregarzia.com/2020/06/languages-that-compile-to-lua.html
- Idris2-Lua (support 5.1/5.2/5.3, limites Lua, dépendances) : https://github.com/Russoul/Idris2-Lua ; https://github.com/idris-lang/Idris2/issues/460 ; cookbook backends Idris2 : https://idris2.readthedocs.io/en/latest/backends/backend-cookbook.html
- language-lua (Hackage, AST 5.3, parser/printer) : https://hackage.haskell.org/package/language-lua ; https://hackage.haskell.org/package/language-lua-0.11.0.2/docs/Language-Lua-Annotated-Syntax.html
- Limites Lua 5.1 (60 upvalues, 200 locals) : https://github.com/LuaLS/lua-language-server/issues/2578 ; https://luau.org/compatibility/ ; cas réel CASTL : https://github.com/PaulBernier/castl/issues/24
- OCaml→Lua (inexistant, piste Rehp, repli EDSL) : https://discuss.ocaml.org/t/what-will-be-required-to-transpile-ocaml-to-lua/10493 ; https://discuss.ocaml.org/t/any-tutorial-on-designing-edsl-in-ocaml/10781
- Haxe cible Lua (5.1-5.3, deps) et précédent WoW : https://haxe.org/manual/target-lua-getting-started.html ; https://github.com/jdonaldson/haxecraft ; https://groups.google.com/g/haxelang/c/fjCu49DQADg
- Recensement des langages → Lua (Hypatia, oczor, pumpkin, Lua-ML, nox…) : https://github.com/hengestone/lua-languages ; Nox : https://github.com/coetaur0/nox ; Hypatia sur Roblox : https://dev.to/jesterxl/strictly-typed-functional-programming-for-roblox-2bcn ; Luml : https://github.com/merle-lang/luml
- WoW/Lua 5.1, modèle de sécurité/taint : https://www.lua.org/wshop08/lua-whitehead.pdf
- Littérature (non liée à des résultats de recherche web, citée de mémoire — à vérifier sur les sites des auteurs) : Carette/Kiselyov/Shan, *Finally Tagless, Partially Evaluated* (JFP 2009) ; Elliott, *Compiling to Categories* (ICFP 2017) ; Maranget, *Compiling Pattern Matching to Good Decision Trees* (ML Workshop 2008) ; Reynolds, *Definitional Interpreters* (defunctionalization) ; Johnsson, *Lambda Lifting* (FPCA 1985) ; Coutts et al., *Stream Fusion* (ICFP 2007) ; Kiselyov/Ishii, *Freer Monads, More Extensible Effects* (Haskell 2015) ; EDSL→C : Feldspar (Axelsson et al.), Ivory (Galois), Copilot, Atom.

Deux vérifications que je vous suggère de faire vous-même avant de trancher (je n'ai pas pu les établir avec certitude depuis la documentation) : (a) si la sortie LuaJIT de LunarML émet `goto`/`bit.*` (un `lunarml compile --luajit` sur un exemple avec pattern matching le dira en cinq minutes), et (b) le degré exact de compatibilité 5.1 du Lua émis par pslua (compiler un golden test et le passer à `luac5.1`).