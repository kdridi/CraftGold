# Compilation Fonctionnelle vers Lua 5.1 — Recherche Ciblée

## Synthèse : Est-ce possible ? Est-ce raisonnable ?

Oui, **c’est possible** de compiler un sous-ensemble riche de style Haskell/ML/Scala vers Lua 5.1 pour WoW, mais pas “gratuitement” : il faut accepter un runtime compilé, des passes de réduction d’allocations, et une discipline de compilation très ciblée. Les précédents les plus proches montrent que le chemin viable n’est pas “Haskell complet → Lua”, mais plutôt “langage fonctionnel avec IR propre → Lua impératif raisonnablement lisible”. [github](https://github.com/Unisay/purescript-lua)

La bonne nouvelle est qu’un compilateur **scoped** pour CraftGold est beaucoup plus réaliste qu’un compilateur général : fonctions pures, ADT simples, pattern matching, modules statiques, et une couche d’effets interprétée via Free/Tagless Final sont un domaine où l’on peut contrôler le code généré et le coût runtime. La mauvaise nouvelle est qu’en Lua 5.1, les points durs sont très concrets : allocations de tables, fermeture/closures, upvalues, absence de garbage-collection fine-grained, et surtout la nécessité de produire du code lisible et stable sous contrainte WoW. [api7](https://api7.ai/fr/learning-center/openresty/luajit-vs-lua)

## Axe 1 : Infrastructure Haskell/Scala/ML → Lua

### Outils existants

`language-lua` existe bien comme **parser / pretty-printer / AST Lua** en Haskell, mais sa documentation et son usage public le positionnent comme bibliothèque de manipulation de code Lua, pas comme backend de compilation mature avec passes d’optimisation ou ciblage spécifique Lua 5.1. `hslua` et `hslua-core` existent surtout pour le **binding Haskell ↔ Lua C API**, donc ils servent à embarquer Lua dans Haskell, pas à générer du Lua source comme produit principal. [github](https://github.com/osa1/language-lua)

Côté Scala, je n’ai pas trouvé d’équivalent largement reconnu de `language-lua` avec écosystème comparable ; les pistes les plus crédibles sont des AST Lua custom ou des macros Scala 3 servant de frontend, mais pas un backend établi et standardisé. Cela rend Scala faisable, mais moins “outillé” que Haskell pour ce cas précis.

### Projets utilisant ces outils

Le signal le plus fort que j’ai trouvé est `purescript-lua` / `pslua`, qui compile PureScript vers Lua et montre qu’un frontend fonctionnel typé peut être abaissé vers Lua source. LunarML est encore plus important pour ton cas : c’est un compilateur Standard ML qui produit Lua et JavaScript, avec une ligne de compilation claire et des modes Lua/continuations/LuaJIT. [github](https://github.com/Unisay/purescript-lua/blob/main/pslua.cabal)

Pour `language-lua`, je n’ai pas trouvé de preuve solide qu’il soit utilisé comme backend principal d’un compilateur fonctionnel “sérieux”; il semble davantage servir d’outil de manipulation et d’émission de Lua que de cible industrielle de compilation. [github](https://github.com/osa1/language-lua)

### Analyse de faisabilité

Pour CraftGold, `language-lua` est utile si tu veux **émettre du Lua lisible** à partir d’un IR maison ou d’un DSL Haskell/TH. En revanche, si tu veux optimiser sérieusement les closures, l’ADT representation, et la spécialisation, il faut une IR intermédiaire plus riche que l’AST Lua brut. En pratique, `language-lua` doit être le **backend de rendu**, pas l’IR centrale. [github](https://github.com/osa1/language-lua)

## Axe 2 : IR et Optimisations

### IR existantes

PureScript a déjà une IR de compilation, et `purescript-lua` montre que ce modèle “Core-like IR → backend Lua” est viable. LunarML a aussi une architecture de compilateur de ML vers Lua/JS, ce qui suggère qu’un IR de haut niveau, avant la génération de Lua, est la bonne abstraction pour préserver les garanties et faire de la transformation structurelle. [github](https://github.com/minoki/LunarML)

Je n’ai pas trouvé de backend public de **GHC Core vers Lua** crédible et reconnu. Donc, pour Haskell, la voie réaliste est plutôt un **DSL ou frontend spécialisé** qui ressemble à Haskell, mais compile vers un IR maison avant Lua.

### Optimisations essentielles pour Lua 5.1

Essentielles :
- **Defunctionalization** pour réduire le nombre de closures et rendre les appels explicites.
- **Lambda lifting** pour faire sortir les variables libres des closures.
- **DCE** et **inlining** pour éliminer les couches d’abstraction coûteuses.
- **Specialization** sur les ADT et les cas fréquents.
- **Représentation compacte des effets** si tu utilises Free Monad ou une variante.

Possibles mais secondaires :
- **Fusion / stream fusion** si CraftGold a des pipelines de collection récurrents.
- **Unboxing partiel** sur les types à très haute fréquence.
- **Worker/wrapper** pour séparer API lisible et noyau rapide.

L’impossible ou très coûteux dans Lua 5.1 :
- Une optimisation agressive dépendant d’un GC finement contrôlable.
- Une représentation sophistiquée de polymorphisme runtime sans surcharge.
- Des optimisations “magiques” qui supposent un runtime Haskell complet.

### Defunctionalization, lambda lifting, unboxing

La **defunctionalization** est probablement ta meilleure arme pour contourner la limite pratique des closures/upvalues et garder le code explicite. Elle remplace les fonctions de première classe par des tags + apply ; dans un backend Lua, cela se traduit naturellement en tables de tags et `if/elseif` ou tables de dispatch. [fxcodebase](https://fxcodebase.com/documents/IndicoreSDK.fr/lua.html)

Le **lambda lifting** est aussi central : plus tu élimines de fermetures imbriquées, plus tu réduis la pression sur les upvalues et le coût de capture. Pour les ADT, l’**unboxing** opportuniste est crucial : `Maybe` peut être codé par `nil | value`, certains `Either` ou petits enregistrements par couple `(tag, payload)` plutôt que table allouée à chaque valeur.

## Axe 3 : Free Monad / Tagless Final → Lua

### Comment compiler une Free Monad vers du Lua

Une Free Monad se compile bien vers Lua si tu la **reifies** en une séquence d’instructions ou en arbre de commandes, puis que tu l’interprètes en code impératif Lua. Le schéma “Free → iterM/interpréteur” se transforme en `local r = ...; if ... then ... end` ou en boucle avec état explicite, ce qui évite d’exécuter une pile de closures à runtime.

Le point clé est de ne pas compiler Free Monad “naïvement” comme une tour de closures. Il faut faire une passe de **représentation aplatie** : liste d’opérations, blocs de continuation nommés, ou petite machine à états.

### Overhead runtime

Le surcoût runtime d’une Free Monad compilée naïvement est élevé : chaque instruction devient potentiellement une allocation de closure et/ou de table. En Lua 5.1, c’est souvent trop cher pour du hot path WoW, surtout si l’interaction avec l’API Blizzard est fréquente.

En revanche, si tu compiles la Free Monad vers un **IR d’effets aplati**, puis vers du Lua impératif, l’overhead peut être raisonnable. Le coût devient alors celui d’un interpréteur léger ou d’une machine à états, ce qui est beaucoup plus acceptable qu’une pile d’interprétation fonctionnelle.

### Code généré (exemples)

Un effet comme `GetItemInfo` peut devenir :
```lua
local itemInfo = GetItemInfo(itemID)
if itemInfo ~= nil then
  -- suite
end
```
au lieu d’une chaîne de `liftF` et continuations. Pour les boucles d’événements WoW, cela suggère une compilation orientée **state machine** plutôt qu’interprétation de Free brute.

### Alternative : Tagless Final

Tagless Final est souvent plus facile à compiler vers Lua, parce qu’il évite la construction explicite d’un arbre syntaxique d’effets. Mais il est aussi plus dépendant du frontend et plus difficile à “réifier” si tu veux inspections, analyses, ou interprétations multiples.

Pour CraftGold, je vois Tagless Final comme bon **frontend d’API**, et Free comme bon **modèle d’analyse/test**, mais je compilerais au final vers un IR impératif commun, pas directement depuis Free ou Tagless au backend.

## Axe 4 : Précédents (Elm, PureScript, GHCJS, js_of_ocaml, Fable)

### Techniques de compilation

PureScript et Elm ont montré qu’un langage fonctionnel peut cibler un runtime dynamique en utilisant un IR propriétaire et une forte normalisation des expressions avant émission. `purescript-lua` indique que ce schéma s’étend au Lua target; LunarML montre la même idée pour SML. [github](https://github.com/Unisay/purescript-lua)

Les compilateurs vers JS comme `js_of_ocaml` ou `Fable` suivent en général une approche similaire : ADT encodés, pattern matching abaissé, runtime ciblé, et passage par un IR stable plutôt que génération directe depuis les AST source.

### Leçons applicables à Lua

La leçon principale est que le backend ne doit pas essayer de “recréer Haskell dans Lua”. Il doit choisir des représentations efficaces pour le sous-ensemble réellement utilisé : ADT compacts, appels directs, tables partagées, et effets explicités.

Autre leçon : pour la lisibilité et le debug, il faut préserver des noms stables, des blocs structurés, et éviter d’inventer un style de code trop machine. C’est particulièrement important dans WoW où la stack trace doit rester exploitable.

## Axe 5 : Contraintes WoW — faisabilité

### Analyse point par point des 8 contraintes

1. Lua 5.1 : faisable, et même souhaitable pour WoW Classic Era. [api7](https://api7.ai/fr/learning-center/openresty/luajit-vs-lua)
2. Pas de `require` standard : faisable, il suffit d’émettre du code “bundle” ou des modules enregistrés via la chaîne de chargement WoW ; LunarML montre déjà un mode module/exe. [github](https://github.com/minoki/LunarML)
3. Pas de `goto` : pas un vrai problème si ton IR est structuré ; la compilation de contrôle doit produire `if`, `while`, fonctions, ou state machines.
4. Max 60 upvalues : contrainte sérieuse, elle favorise lambda lifting, regroupement d’environnement, et defunctionalization.
5. Budget CPU strict : contrainte majeure ; impose DCE, inlining ciblé, évitement des allocations inutiles et du dispatch indirect.
6. GC pressure : contrainte majeure ; impose unboxing, réutilisation d’objets, tables cachées, et évitement des ADT en boucle chaude.
7. Interop `_G` : faisable si le backend sait référencer les globals WoW et les enregistrer proprement.
8. Code lisible : faisable si tu gardes un backend “pretty” et non obfusqué.

La conclusion pratique est que **oui**, c’est possible, mais seulement si le compilateur est conçu autour des contraintes WoW dès le départ, pas ajouté après coup.

## Axe 6 : Projets existants évalués

### Pour chaque projet : statut, qualité, compatibilité 5.1, overhead

| Projet | Statut | Qualité du code généré | Lua 5.1 | Overhead |
|---|---|---:|---:|---:|
| `purescript-lua` / `pslua` | Existant, actif sur GitHub | Prometteuse, cible compile backend Lua | Pas clairement centré sur 5.1 dans les sources trouvées | Probablement modéré si l’IR est bien abaissée  [github](https://github.com/Unisay/purescript-lua) |
| LunarML | Existant, documenté, releases récentes | Bon pour SML source, backend Lua/JS sérieux | Documentation trouvée surtout Lua 5.3+, LuaJIT, continuations  [github](https://github.com/minoki/LunarML) | Contient un runtime non trivial, mais instructif  [github](https://github.com/minoki/LunarML) |
| `language-lua` | Bibliothèque Haskell | AST + pretty-printer, pas compilateur complet | Oui, pour l’émission source Lua ; maturité correcte comme lib | Dépend de ton usage, pas de runtime propre  [github](https://github.com/osa1/language-lua) |
| `hslua` / `hslua-core` | Binding Haskell↔Lua | Pas un backend de compilation | Oui côté API Lua, mais cible d’embedding | N/A pour compilation source |
| `lua_of_ocaml` | Je n’ai pas trouvé de projet établi et crédible sous ce nom | Non vérifié | Non vérifié | Non vérifié |
| Idris2-Lua | Je n’ai pas trouvé de backend Lua établi et reconnu | Non vérifié | Non vérifié | Non vérifié |
| Nox | Je n’ai pas trouvé de preuve solide dans les sources récupérées | Non vérifié | Non vérifié | Non vérifié |
| Amulet | Le projet existe/historiquement pertinent, mais je n’ai pas assez de sources fiables ici | Instructif, mais non confirmé pour ton besoin | À vérifier au cas par cas | À vérifier |
| Haxe LLVM→Lua | Je n’ai pas trouvé de chaîne crédible et standard | Non vérifié | Non vérifié | Non vérifié |
| Crystal→Lua / Carp→Lua | Je n’ai pas trouvé de backend établi et pertinent | Non vérifié | Non vérifié | Non vérifié |

Le sous-ensemble utile ici est donc principalement **LunarML**, **purescript-lua**, et `language-lua` comme brique technique. [github](https://github.com/Unisay/purescript-lua)

## Axe 7 : Build-it-yourself

### Stack Haskell : faisabilité et effort

La voie Haskell est la plus naturelle pour toi si tu veux exploiter le type system du frontend et générer du Lua propre. Un stack raisonnable serait : DSL ou EDSL Haskell, IR intermédiaire maison, passes de simplification, puis rendu Lua via `language-lua` ou un pretty-printer dédié.

L’effort réel dépend du périmètre. Pour un compilateur **scoped** orienté CraftGold, je dirais qu’un premier prototype sérieux est faisable, mais un vrai backend robuste avec analyses, spécialisation, debug symbolique et optimisation d’allocations demande un effort non trivial.

### Stack Scala : faisabilité et effort

Scala 3 peut servir de frontend via macros, mais l’écosystème de compilation vers Lua est beaucoup moins mûr. Tu peux y écrire un EDSL, mais tu réinventeras probablement plus de plomberie qu’en Haskell.

Le principal avantage de Scala serait peut-être la familiarité si ton code métier est déjà Scala-like, mais pour la génération de Lua lisible et le contrôle fin des représentations, Haskell semble plus direct.

### Le "compilateur scoped" : combien de travail ?

Oui, un compilateur scoped est **beaucoup** plus simple qu’un compilateur général. Si tu limites la source à fonctions pures, ADT simples, pattern matching exhaustif, une sémantique d’effets restreinte, et des données statiques, tu évites le système d’évaluation lazy complet, le polymorphisme runtime complexe, et une grande partie du travail de backend.

C’est précisément la zone où la compilation vers Lua est plausible sans coût runtime prohibitif : tu compiles ce que tu utilises, pas un langage universel. C’est aussi la seule approche que je considérerais sérieusement pour WoW Classic Era.

## Recommandation finale

Pour CraftGold, la meilleure stratégie n’est pas de chercher un “Haskell complet vers Lua 5.1”, mais de construire un **frontend fonctionnel spécialisé** avec :
- un IR maison de type Core/SSA simple,
- defunctionalization et lambda lifting,
- représentation compacte des ADT,
- backend Lua 5.1 lisible,
- et une sémantique d’effets orientée state machine plutôt que Free Monad brute.

Si tu veux un point de départ réaliste, je classerais les options ainsi : **Haskell DSL + IR maison + Lua backend** en premier, **LunarML** comme source d’inspiration technique, et **purescript-lua** comme preuve qu’un compilateur fonctionnel vers Lua n’est pas fantasmatique. En revanche, essayer de faire entrer Haskell/Scala/OCaml généraliste complet dans Lua 5.1 sans IR ciblé te fera très probablement exploser en complexité et en coût runtime. [github](https://github.com/minoki/LunarML)

## Sources (URLs pour chaque affirmation)

- `language-lua` / parser / pretty-printer Lua : [https://github.com/osa1/language-lua](https://github.com/osa1/language-lua) [github](https://github.com/osa1/language-lua)
- `purescript-lua` / `pslua` backend Lua : [https://github.com/Unisay/purescript-lua](https://github.com/Unisay/purescript-lua) [github](https://github.com/Unisay/purescript-lua/blob/main/pslua.cabal)
- LunarML, compiler Standard ML → Lua/JavaScript : [https://github.com/minoki/LunarML](https://github.com/minoki/LunarML) [github](https://github.com/minoki/LunarML)
- Lua 5.1 / 5.1-compatible context and syntax compatibility note: [https://api7.ai/fr/learning-center/openresty/luajit-vs-lua](https://api7.ai/fr/learning-center/openresty/luajit-vs-lua) [api7](https://api7.ai/fr/learning-center/openresty/luajit-vs-lua)
- Lua general properties / `_G` / table model context: [https://www.codeporting.ai/fr/language/lua](https://www.codeporting.ai/fr/language/lua) [codeporting](https://www.codeporting.ai/fr/language/lua)
- LLVM IR / architecture concept: [https://llvm.org](https://llvm.org) [llvm](https://llvm.org)