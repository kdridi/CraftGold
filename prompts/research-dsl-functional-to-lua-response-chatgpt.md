# Compilation Fonctionnelle vers Lua 5.1 — Recherche Ciblée

## Synthèse : Est-ce possible ? Est-ce raisonnable ?

Tu cherches une voie “hardcore” : garder la puissance Haskell/Scala/ML côté écriture — ADT, pattern matching, monades, type classes, HKTs, éventuellement Free Monad — mais émettre du **Lua 5.1 lisible, performant, compatible WoW Classic Era**, sans `require`, sans runtime lourd, sans explosions de closures/upvalues/GC. C’est bien le cahier des charges de ton prompt. 

**Verdict : oui, mais pas sous la forme “compiler Haskell général vers Lua WoW”.**

La voie raisonnable est :

```text
Haskell / Scala comme méta-langage typé
        ↓
DSL / EDSL strict, limité, spécialisé CraftGold
        ↓
IR maison en ANF / CFG impératif
        ↓
optimisations obligatoires : DCE, inlining, specialization, fusion, lambda lifting
        ↓
Lua 5.1 direct, lisible, sans runtime fonctionnel
```

La voie déraisonnable est :

```text
GHC Core / full Haskell / laziness / typeclasses dynamiques / Free runtime
        ↓
backend Lua 5.1 général
        ↓
runtime massif, closures, thunks, GC, stack traces illisibles
```

**Le point clé : il ne faut pas “porter Haskell dans WoW”. Il faut utiliser Haskell pour prouver et générer un sous-langage impératif propre.** Les abstractions fonctionnelles doivent être **consommées à la compilation**, pas réifiées en Lua.

---

## Axe 1 : Infrastructure Haskell/Scala/ML → Lua

### Outils existants

#### Haskell : `language-lua`

`language-lua` existe bien, mais il est annoncé comme un lexer/parser/pretty-printer pour **Lua 5.3**, pas comme un générateur ciblant strictement Lua 5.1. Son README expose un AST, un parser, et un pretty-printer ; il précise aussi que le pretty-printer est encore susceptible de changer. ([GitHub][1])

Conclusion : **utilisable comme base d’AST/pretty-printer**, mais pas suffisant seul pour WoW. Il faudrait ajouter un validateur dialectal :

```text
Lua51Check:
  reject goto
  reject labels
  reject _ENV
  reject table.pack / table.unpack 5.2+
  reject bit32 unless polyfill explicite
  reject integer division //
  reject 5.3 bit operators
```

Pour CraftGold, je ne partirais pas d’un AST Lua complet. Je ferais plutôt un **mini-AST Lua 5.1 volontairement incomplet**, par exemple :

```haskell
data LStmt
  = Local Name (Maybe LExp)
  | Assign LExp LExp
  | If LExp [LStmt] [LStmt]
  | While LExp [LStmt]
  | ForNum Name LExp LExp LExp [LStmt]
  | Return [LExp]
  | ExprStmt LExp
  | Function Name [Name] [LStmt]

data LExp
  = Var Name
  | Nil
  | Bool Bool
  | Num Double
  | Str Text
  | Table [(Maybe LExp, LExp)]
  | Call LExp [LExp]
  | Index LExp LExp
  | Bin Op LExp LExp
  | Un UnOp LExp
```

C’est moins glamour qu’un AST complet, mais ça rend impossible de générer accidentellement du Lua 5.3.

#### Haskell : HsLua

HsLua est un pont Haskell ↔ Lua via l’API C de Lua. Il sert à intégrer Lua dans Haskell ou exposer des fonctions Haskell à Lua ; il embarque par défaut une version récente de Lua et son usage emblématique est Pandoc/Lua filters. ([GitHub][2])

Conclusion : **utile pour des outils de build/test**, pas pour WoW. Tu pourrais t’en servir pour tester du Lua généré hors jeu, mais pas pour exécuter CraftGold dans WoW, car WoW ne charge pas ton runtime Haskell/C.

#### Template Haskell / quasiquotation

L’approche Yesod-like est viable conceptuellement. Les quasiquoters Haskell permettent de parser un DSL à la compilation, d’injecter des méta-variables, et de transformer le tout en AST Haskell ou en code généré. Le blog Well-Typed sur les quasiquoters montre précisément ce modèle : réutiliser une infrastructure de parsing/AST et y ajouter des méta-variables. ([well-typed.com][3])

Pour toi, le modèle serait :

```haskell
craftCost :: LuaFun '[RecipeDB, AuctionDB] Money
craftCost = [cg|
  fn craftCost(recipeId):
    recipe = recipes[recipeId]
    total = 0
    for reagent in recipe.reagents:
      total = total + cheapestCost(reagent.itemId, reagent.qty)
    return total
|]
```

Mais attention : **la quasiquotation ne remplace pas un compilateur**. Elle te donne un frontend pratique. Il faut quand même :

```text
Parser → Typed AST → IR → optimizations → Lua 5.1 backend
```

#### Scala 3 macros

Scala 3 peut servir de frontend : ses macros et citations/splices permettent d’inspecter ou générer du code à la compilation. La documentation officielle montre que les macros Scala 3 sont évaluées à la compilation et peuvent produire du code typé. ([nightly.scala-lang.org][4])

Il y a aussi un précédent intéressant côté “Scala comme hôte typé pour un DSL cible” : les QDSL inspirés de Quill utilisent des macros Scala pour analyser une expression Scala et générer un langage cible performant. ([idiomaticsoft.com][5])

Mais l’écosystème Lua côté Scala est maigre. `Scalup` est un parser / pretty-printer Lua écrit en Scala, mais il semble petit et sans releases solides. ([GitHub][6])

Conclusion : **Scala 3 est viable comme méta-langage**, mais Haskell est plus naturel ici si tu veux faire un DSL compilateur : ADT, pattern matching, quasiquotes, type-level programming, Megaparsec, et culture compiler/EDSL plus directe.

---

## Axe 1 : Projets utilisant ces outils

### LunarML

LunarML est le projet le plus sérieux côté ML → Lua. Il compile Standard ML vers Lua ou JavaScript, supporte SML’97 incluant signatures et foncteurs, et vise un vrai langage ML avec système de modules. ([lunarml.readthedocs.io][7])

Mais il y a un problème critique pour WoW : les backends documentés ciblent **Lua 5.3+** ou **LuaJIT**, pas Lua 5.1 vanilla. ([GitHub][8])

Conclusion : LunarML est **excellent comme référence de design**, mais pas directement utilisable pour CraftGold. Le forker vers Lua 5.1 est possible, mais ce n’est pas un petit patch : il faut gérer les différences de langage, de librairie standard, d’entiers/bitops, et de runtime.

### PureScript Lua / `purescript-lua`

`purescript-lua` est très proche de ce que tu cherches en esprit : PureScript → Lua, avec bundling, FFI Lua, dead-code elimination, inlining, et support des bibliothèques core PureScript. Le README dit que le projet est “ready to be experimented with” mais probablement encore avec des bugs. ([GitHub][9])

Le gros avantage de PureScript est son IR CoreFn et l’existence d’un écosystème d’optimisation backend-agnostic. `purescript-backend-optimizer` consomme CoreFn et applique une pipeline agressive d’inlining et d’optimisations. ([GitHub][10])

Mais pour WoW : je n’ai pas trouvé de garantie publique claire que `purescript-lua` émet du **Lua 5.1 strictement compatible WoW**, sans dépendances ni runtime incompatible. Donc c’est probablement le **candidat existant le plus intéressant**, mais il faut l’auditer.

### Amulet

Amulet était un langage ML-like compilant notamment vers Lua, avec ADT, pattern matching, polymorphisme, et optimisations comme l’élimination de récursion terminale. Mais le projet est explicitement indiqué comme n’étant plus développé. ([GitHub][11])

Conclusion : **instructif, pas une base de production**.

### Idris2-Lua

Il existe un backend Lua pour Idris 2, et il annonce le support de Lua 5.1, 5.2, 5.3 et LuaJIT. Mais il dépend de paquets LuaRocks comme `lua-utf8`, `lua-bigint`, `lfs`, `vstruct`, et documente des limitations Lua importantes, notamment autour du nombre de variables locales et de structures imbriquées. ([GitHub][12])

Conclusion : intellectuellement fascinant, mais **mauvais fit WoW**. WoW ne te donne pas LuaRocks, `require`, ni un environnement runtime libre.

### Nox

Nox est un langage fonctionnel statiquement typé avec inférence Hindley-Milner et row polymorphism, compilant vers Lua. ([GitHub][13])

Conclusion : intéressant, mais probablement trop expérimental et pas assez aligné avec ton besoin “CraftGold production / WoW 5.1 / stack traces lisibles”.

### `lua_of_ocaml` / `loo`

Il existe une annonce récente d’un projet `loo`, “Lua of OCaml”, qui compile du bytecode OCaml vers Lua 5.1. Mais le fil de discussion indique que le projet est très jeune, en partie généré par IA, et que même le hello-world Lua 5.1 a nécessité des corrections initiales. ([OCaml][14])

Conclusion : **à surveiller**, mais pas une fondation fiable aujourd’hui.

### Haxe → Lua

Haxe a un backend Lua qui supporte Lua 5.1, 5.2, 5.3 et LuaJIT. ([Haxe - The Cross-platform Toolkit][15])

Mais Haxe n’est pas ce que tu demandes : ce n’est pas Haskell/Scala/ML avec HKTs/typeclasses/GADTs. C’est un excellent transpiler pragmatique, pas une voie “langage fonctionnel hardcore”.

---

## Axe 1 : Analyse de faisabilité

### Ce qui existe déjà

```text
Très intéressant :
  PureScript Lua
  LunarML
  Idris2-Lua

Instructif :
  Amulet
  Nox
  lua_of_ocaml

Pragmatique mais hors cible :
  Haxe Lua
```

### Ce qui n’existe pas vraiment

Je n’ai pas trouvé de backend crédible du type :

```text
GHC Core → Lua 5.1 WoW-ready
Scala 3 full language → Lua 5.1
OCaml mature → Lua 5.1 production
Haskell EDSL mature → Lua 5.1 WoW
```

Donc la réponse honnête est : **aucun projet existant ne coche toutes tes cases**.

Le plus proche est probablement :

```text
PureScript Lua
```

Mais si tu veux du contrôle total sur la lisibilité, les allocations, les upvalues, le modèle WoW et les stack traces, la meilleure voie reste :

```text
DSL custom fortement typé + backend Lua 5.1 maison
```

---

## Axe 2 : IR et Optimisations

### IR existantes

#### PureScript CoreFn

CoreFn est intéressant parce qu’il représente déjà un langage strict, typé, avec ADT, records, type classes résolues en grande partie côté compilation, et backend JS officiel. `purescript-backend-optimizer` montre qu’on peut optimiser CoreFn avec DCE, inlining et spécialisation avant émission. ([GitHub][10])

Pour toi, CoreFn est probablement plus utile comme **modèle** que comme dépendance directe.

#### GHC Core

GHC Core est trop riche et trop proche d’un runtime Haskell complet : laziness, thunks, closures, typeclass dictionaries, coercions, levity, primitive ops, runtime system implicite. Les projets Haskell → JS/WASM comme GHCJS/Asterius montrent que compiler Haskell complet vers une plateforme non-native implique un runtime lourd : CPS, heap géré, trampoline, GC/runtime. ([Chalmers Publication Library (CPL)][16])

Pour WoW, c’est quasiment un non.

#### GRIN / IR fonctionnels académiques

GRIN est une IR de recherche pour optimiser et générer du code pour langages fonctionnels stricts/lazy, avec frontends Haskell/Idris/Agda dans certains travaux. ([GitHub][17])

Mais GRIN n’est pas un raccourci pratique vers Lua 5.1 WoW. Trop général, trop runtime/compiler-heavy.

#### IR recommandée pour CraftGold

Je ferais une IR en deux niveaux :

```text
Typed Core
  - fonctions pures
  - ADT simples
  - pattern matching
  - records
  - appels WoW abstraits
  - effets typés

Lowered ANF / CFG
  - plus de lambdas sauf callbacks explicites
  - plus de pattern matching riche
  - plus de typeclasses
  - plus de Free Monad runtime
  - seulement variables, branches, loops, calls, tables
```

Exemple :

```haskell
-- DSL haut niveau
cheapestCost itemId qty = do
  ah <- getAuctionPrice itemId qty
  cr <- getCraftCost itemId qty
  pure (min ah cr)
```

IR ANF :

```text
v1 = CALL getAuctionPrice(itemId, qty)
v2 = CALL getCraftCost(itemId, qty)
v3 = CALL min(v1, v2)
RETURN v3
```

Lua généré :

```lua
local function cheapestCost(itemId, qty)
  local v1 = CG_getAuctionPrice(itemId, qty)
  local v2 = CG_getCraftCost(itemId, qty)
  if v1 < v2 then
    return v1
  else
    return v2
  end
end
```

---

## Axe 2 : Optimisations essentielles pour Lua 5.1

### Essentielles

#### 1. Dead Code Elimination

WoW charge tous les fichiers listés dans le `.toc`, et les fichiers sont chargés séquentiellement. ([Warcraft Wiki][18])

Tu dois donc partir des racines :

```text
OnLoad
slash commands
event handlers
public API CraftGold
```

Puis éliminer tout le reste.

#### 2. Inlining sélectif

Indispensable pour éviter :

```lua
map(function(x)
  return f(x)
end, xs)
```

dans les chemins chauds.

Tu veux générer :

```lua
for i = 1, n do
  local x = xs[i]
  ...
end
```

#### 3. Spécialisation des type classes

En Haskell/PureScript/Scala, les type classes deviennent souvent des dictionnaires. En Lua, émettre ces dictionnaires dans les hot paths serait catastrophique.

Mauvais Lua :

```lua
local function compare(ordDict, a, b)
  return ordDict.compare(a, b)
end
```

Bon Lua généré après spécialisation :

```lua
if a < b then
  ...
end
```

#### 4. Fusion `map/filter/fold`

La fusion est essentielle pour éviter listes intermédiaires et garbage. Le modèle conceptuel ressemble au `foldr/build fusion` de GHC, qui élimine des listes intermédiaires via des règles de réécriture. ([well-typed.com][19])

Exemple DSL :

```haskell
recipes
  |> filter profitable
  |> map profit
  |> maximum
```

Lua naïf :

```lua
local tmp1 = {}
local tmp2 = {}
...
```

Lua voulu :

```lua
local best = nil
for i = 1, #recipes do
  local r = recipes[i]
  if CG_profitable(r) then
    local p = CG_profit(r)
    if best == nil or p > best then
      best = p
    end
  end
end
return best
```

#### 5. Lambda lifting / closure control

Lua 5.1 a une limite dure de **60 upvalues par fonction**. Cette limite est définie dans `luaconf.h`. ([lua.org][20])

Donc il faut éviter le style :

```lua
local a1, a2, ..., a80 = ...
return function(x)
  return a1 + a2 + ... + a80 + x
end
```

Le lambda lifting transforme les variables libres en paramètres explicites et réduit les closures. Les guides d’optimisation Haskell décrivent précisément cette optimisation pour éviter les allocations de closures. ([haskell.foundation][21])

#### 6. Defunctionalization

La defunctionalization remplace les fonctions d’ordre supérieur par des tags + dispatcher de premier ordre. C’est une technique classique de compilation des langages fonctionnels vers des cibles moins adaptées aux closures. ([SIGPLAN Blog][22])

Exemple :

```haskell
map (Add 3) xs
map (Mul 2) xs
```

Lua defunctionalisé :

```lua
local ADD = 1
local MUL = 2

local function applyFun(tag, payload, x)
  if tag == ADD then
    return x + payload
  elseif tag == MUL then
    return x * payload
  end
end
```

Mais attention : pour CraftGold, le mieux est souvent de **ne pas générer `map` du tout**, mais de fusionner en boucle.

---

## Axe 2 : Defunctionalization, lambda lifting, unboxing

### ADT en Lua

Représentation simple :

```lua
-- Just x
{ tag = "Just", value = x }

-- Nothing
{ tag = "Nothing" }
```

Lisible, mais allocation partout.

Représentation plus rapide :

```lua
-- Just x
{ 1, x }

-- Nothing
0
```

Encore plus optimisée pour `Maybe a` :

```text
Nothing = nil
Just x  = x
```

Mais seulement si `x` ne peut jamais être `nil`.

Donc la règle :

```text
Maybe NonNil      → nil | raw value
Maybe Nullable    → tagged representation
Either a b        → {0, a} | {1, b}, sauf optimisation locale
Small enum        → integer tag
Large record ADT  → table avec tag numérique
```

### Pattern matching

Le pattern matching ML peut être compilé en arbres de décision compacts. Les travaux classiques de Maranget sur la compilation du pattern matching ML traitent exactement ce problème. ([moscova.inria.fr][23])

Pour Lua :

```haskell
case x of
  Nothing -> 0
  Just n  -> n + 1
```

si `Maybe Int = nil | number` :

```lua
if x == nil then
  return 0
else
  return x + 1
end
```

Pour ADT taggé :

```lua
local tag = x[1]
if tag == 0 then
  ...
elseif tag == 1 then
  local payload = x[2]
  ...
else
  error("non-exhaustive pattern")
end
```

En production, tu peux retirer certains `error` après exhaustiveness check. En debug, garde-les.

---

## Axe 3 : Free Monad / Tagless Final → Lua

### Comment compiler une Free Monad vers Lua

Il y a deux façons très différentes.

#### Mauvaise façon : émettre la Free Monad en Lua

Haskell :

```haskell
data WowF next
  = GetItemInfo ItemID (Maybe ItemInfo -> next)
  | Print Text next
```

Lua naïf :

```lua
return {
  tag = "GetItemInfo",
  itemId = itemId,
  k = function(result)
    return {
      tag = "Print",
      text = result.name,
      next = ...
    }
  end
}
```

C’est mauvais pour WoW :

```text
1 table par instruction
1 closure par continuation
beaucoup d’upvalues
GC pressure énorme
stack traces illisibles
```

Free Monad est très utile comme représentation de DSL et pour interpréter vers plusieurs backends. Cats documente bien l’idée : `Free` permet de représenter un calcul comme données, puis de le retargeter vers différents interpréteurs. ([typelevel.org][24])

Mais dans ton cas, **Free doit exister côté Haskell/Scala build-time, pas côté Lua runtime**.

#### Bonne façon : compiler Free vers CFG impératif

Entrée :

```haskell
program = do
  info <- getItemInfo itemId
  case info of
    Nothing -> print "missing"
    Just i  -> print i.name
```

IR :

```text
v1 = EFFECT GetItemInfo itemId
CASE v1:
  NIL  -> EFFECT Print "missing"
  JUST -> EFFECT Print v1.name
RETURN
```

Lua :

```lua
local function program(itemId)
  local v1 = GetItemInfo(itemId)
  if v1 == nil then
    print("missing")
  else
    print(v1.name)
  end
end
```

Donc la compilation d’une Free Monad vers Lua doit faire :

```text
Free AST
  ↓
linearisation des binds
  ↓
ANF
  ↓
élimination des continuations
  ↓
statements impératifs
```

### Overhead runtime

Si tu émets Free en Lua : overhead prohibitif.

Si tu compiles Free vers statements : overhead proche de zéro.

Les papiers sur l’optimisation des Free Monads, comme “Reflection without Remorse”, existent parce que les Free Monads naïves ont des problèmes de performance liés aux chaînes de binds et à l’interprétation. ([okmij.org][25])

Dans CraftGold, le bon objectif est plus brutal :

```text
Aucune Free Monad dans le Lua généré.
Aucune closure de continuation dans le Lua généré.
Aucune table d’instruction Free dans le Lua généré.
```

### Code généré : exemple synchrone

DSL :

```haskell
profitOf recipeId = do
  recipe <- lookupRecipe recipeId
  cost   <- totalCost recipe
  price  <- auctionPrice recipe.output
  pure (price - cost)
```

Lua voulu :

```lua
local function CG_profitOf(recipeId)
  local recipe = CG_recipes[recipeId]
  if recipe == nil then
    return nil
  end

  local cost = CG_totalCost(recipe)
  local price = CG_auctionPrice(recipe.output)

  if price == nil then
    return nil
  end

  return price - cost
end
```

### Code généré : exemple asynchrone WoW

Certaines API WoW sont event-driven. Il ne faut pas compiler ça en closures imbriquées, mais en **state machine explicite**.

DSL :

```haskell
scanAuctions item = do
  queryAuctions item
  wait AuctionItemListUpdate
  xs <- readAuctionResults
  pure xs
```

Lua lisible :

```lua
local CG_scanState = nil

function CG_StartScan(itemName)
  CG_scanState = {
    step = 1,
    itemName = itemName
  }

  QueryAuctionItems(itemName, nil, nil, 0, false, nil, false, false)
end

function CG_OnEvent(event)
  if CG_scanState == nil then
    return
  end

  if CG_scanState.step == 1 and event == "AUCTION_ITEM_LIST_UPDATE" then
    local xs = CG_ReadAuctionResults()
    CG_scanState.results = xs
    CG_scanState.step = 2
    CG_FinishScan(CG_scanState)
    CG_scanState = nil
  end
end
```

Pour plusieurs scans concurrents, tu remplaces `CG_scanState` par une table de jobs indexée par ID.

### Alternative : Tagless Final

Tagless Final est souvent meilleur ici. Au lieu de construire une Free Monad puis l’interpréter, tu décris le DSL par une interface et tu donnes plusieurs interpréteurs. Le style tagless final est un encodage classique pour DSL typés avec plusieurs interprétations. ([Tech, Science, Math and more...][26])

Exemple Haskell simplifié :

```haskell
class Monad m => WowDSL m where
  getItemInfo :: ItemID -> m (Maybe ItemInfo)
  printText   :: Text -> m ()

program :: WowDSL m => ItemID -> m ()
program itemId = do
  info <- getItemInfo itemId
  case info of
    Nothing -> printText "missing"
    Just i  -> printText (itemName i)
```

Interpréteurs :

```haskell
newtype TestM a = TestM (State MockWorld a)
newtype LuaM  a = LuaM  (CodeGen a)
```

Avantage :

```text
TestM exécute réellement en Haskell.
LuaM génère du Lua.
```

Mais si tu veux optimiser globalement, le tagless final pur cache parfois trop la structure. Le compromis idéal :

```text
Tagless Final en surface
        ↓
interpréteur Reify
        ↓
IR optimisable
        ↓
Lua
```

Donc :

```text
Tagless Final pour l’ergonomie
Free/AST/IR pour l’optimisation
Lua direct pour la production
```

---

## Axe 4 : Précédents : Elm, PureScript, GHCJS, js_of_ocaml, Fable

### Elm → JavaScript

Elm 0.19 a beaucoup misé sur la réduction de taille et le dead-code elimination fonctionnel. L’annonce d’Elm 0.19 met en avant un DCE au niveau fonction, et la documentation décrit aussi le renommage de champs records et la minification. ([elm-lang.org][27])

Leçon pour Lua :

```text
Ne pas émettre une bibliothèque fonctionnelle complète.
Partir des handlers réellement utilisés.
DCE agressif.
Noms lisibles en debug, noms courts en release.
```

### PureScript → JavaScript / Lua

PureScript est très pertinent parce qu’il compile un langage strict, typé, avec ADT et type classes vers JavaScript. Le backend optimizer CoreFn montre qu’on peut éliminer une grosse partie du coût des abstractions avec inlining et optimisations backend-agnostic. ([GitHub][10])

Leçon pour Lua :

```text
PureScript-like strictness > Haskell-like laziness.
Typeclasses doivent être spécialisées.
Monades doivent disparaître dans les hot paths.
```

### GHCJS / Asterius / GHC WASM

GHCJS compile Haskell vers JavaScript, mais au prix d’un runtime sophistiqué : CPS, trampoline, heap géré, interaction complexe avec le GC JS. ([Chalmers Publication Library (CPL)][16])

Le backend WebAssembly de GHC/Asterius va encore plus loin en portant le runtime GHC, avec GC et RTS, pour préserver les fonctionnalités Haskell. ([tweag.io][28])

Leçon pour Lua/WoW :

```text
Full Haskell = runtime.
Runtime = pas acceptable dans WoW.
Donc ne compile pas Haskell général.
Compile un DSL strict et borné.
```

### js_of_ocaml

`js_of_ocaml` compile du bytecode OCaml vers JavaScript et supporte du code OCaml pur dans navigateur/Node. ([OCaml][29])

Il dispose de niveaux d’optimisation et d’une vraie pipeline de compilation. ([ocsigen.org][30])

Leçon :

```text
Compiler un langage ML vers un scripting language est possible.
Mais les projets sérieux investissent massivement dans runtime + optimiseur.
Pour WoW, il faut réduire l’ambition : pas OCaml complet.
```

### Fable

Fable compile F# vers JavaScript et documente la représentation des unions discriminées, du pattern matching et des constructs F# vers des formes JS. ([Fable][31])

Leçon :

```text
ADT/pattern matching vers langage dynamique = problème résolu.
Le vrai problème n’est pas la sémantique.
Le vrai problème est l’overhead runtime.
```

---

## Axe 5 : Contraintes WoW — faisabilité

### 1. Lua 5.1

WoW utilise une variante de Lua 5.1 pour l’interface. ([addonstudio.org][32])

Lua 5.1 n’a pas `goto`; `goto` arrive avec Lua 5.2. ([lua.org][33])

Donc ton backend doit être explicitement Lua 5.1 :

```text
pas de goto
pas de labels
pas de _ENV
pas de table.unpack 5.2
pas de bit operators 5.3
pas d’entiers 5.3
pas de __pairs 5.2
```

### 2. Pas de `require` standard

Les add-ons WoW sont chargés via `.toc`, qui liste les fichiers et leur ordre de chargement. ([Warcraft Wiki][18])

Donc le compilateur doit générer :

```text
CraftGold.toc
src/generated/Core.lua
src/generated/Data.lua
src/generated/UI.lua
```

et non :

```lua
local Core = require("Core")
```

### 3. Pas de `goto`

Sans `goto`, les state machines doivent utiliser :

```lua
if state == 1 then
  ...
elseif state == 2 then
  ...
end
```

ou des dispatch tables :

```lua
local steps = {}

steps[1] = function(job)
  ...
end

steps[job.step](job)
```

Mais attention : dispatch table de fonctions = closures potentielles. Pour hot path, préfère `if/elseif` généré.

### 4. Max 60 upvalues

Lua 5.1 limite les upvalues à 60 par fonction. ([lua.org][20])

Règles backend :

```text
- Ne jamais capturer un environnement riche.
- Passer les dépendances en paramètres ou via une table module.
- Générer des fonctions top-level.
- Limiter les local aliases d’API WoW.
- Lambda lifting obligatoire.
- Defunctionalization pour callbacks internes.
```

Mauvais :

```lua
local GetItemInfo = _G.GetItemInfo
local QueryAuctionItems = _G.QueryAuctionItems
local GetNumAuctionItems = _G.GetNumAuctionItems
-- ...
-- 80 locals capturés par toutes les fonctions
```

Meilleur :

```lua
local CG = CraftGold
local API = _G

function CG.ResolveItem(itemId)
  return API.GetItemInfo(itemId)
end
```

### 5. Budget CPU strict

La communauté WoW documente le fameux problème “script ran too long”, avec des seuils non officiels et variables selon machine/contexte ; des tests communautaires parlent d’ordres de grandeur autour de dizaines/centaines de ms, pas d’un contrat stable. ([WoWInterface][34])

Donc :

```text
- pas de full recompute dans un OnEvent
- pas de DP massif dans un OnUpdate
- scheduler par chunks
- cache agressif
- calculs incrémentaux
- précompilation des tables statiques
```

### 6. GC pressure

Les allocations Lua peuvent provoquer des pauses ; la communauté WoW critique notamment les appels forcés à `collectgarbage` parce qu’ils peuvent bloquer l’exécution. ([GitHub][35])

Donc :

```text
Interdit dans hot path :
  - ADT table pour chaque Maybe
  - Free instruction table
  - closure par bind
  - map/filter intermédiaires
  - string concat en boucle

Préféré :
  - tags numériques
  - nil encoding
  - arrays réutilisés
  - caches
  - boucles fusionnées
```

### 7. Interop avec `_G`

Le backend doit considérer `_G` comme une dépendance explicite :

```lua
local CG = CraftGold or {}
CraftGold = CG

function CG.GetItemName(itemId)
  local name = _G.GetItemInfo(itemId)
  return name
end
```

En test hors WoW :

```lua
_G.GetItemInfo = function(itemId)
  return MockItems[itemId]
end
```

Donc le modèle “seam” que tu utilises déjà reste bon.

### 8. Code lisible

Le Lua généré doit avoir :

```text
- une fonction Lua par fonction DSL importante
- noms stables en debug
- commentaires source
- pas de CPS généralisé
- pas de runtime opaque
- option --debug-readable
- option --release-minified plus tard
```

Exemple :

```lua
-- generated from CraftGold.Cost.cheapestCost
function CG_cheapestCost(itemId, qty)
  ...
end
```

---

## Axe 6 : Projets existants évalués

### 1. `purescript-lua` / `pslua`

**Statut :** expérimental mais actif/utilisable pour expérimentation. Le README annonce bundling, FFI Lua, DCE, inlining, package set, et bibliothèques core. ([GitHub][9])

**Qualité :** probablement la piste la plus proche si tu veux un vrai langage fonctionnel strict avec ADT/typeclasses.

**Compatibilité Lua 5.1 :** non garantie publiquement dans les sources que j’ai vérifiées. Audit nécessaire.

**Overhead :** potentiellement acceptable si l’optimizer élimine les abstractions ; dangereux sinon.

**Verdict :** à tester sérieusement avec un micro-benchmark WoW-like.

---

### 2. LunarML

**Statut :** solide, vrai compiler Standard ML. Supporte SML’97, modules, signatures, foncteurs. ([lunarml.readthedocs.io][7])

**Compatibilité Lua 5.1 :** non, les targets Lua documentés sont Lua 5.3+ ou LuaJIT. ([GitHub][8])

**Overhead :** probablement raisonnable pour du ML strict, mais dépend du runtime généré.

**Verdict :** excellente référence, mauvais fit direct WoW.

---

### 3. Amulet

**Statut :** abandonné. ([GitHub][11])

**Qualité :** instructif pour compiler un ML-like vers Lua.

**Compatibilité :** à auditer, mais l’abandon suffit à l’écarter.

**Verdict :** lire le code, ne pas bâtir dessus.

---

### 4. Idris2-Lua

**Statut :** réel. Supporte Lua 5.1/5.2/5.3/LuaJIT. ([GitHub][12])

**Problème :** dépendances LuaRocks, runtime, limitations Lua documentées.

**Verdict :** théoriquement impressionnant, pratiquement inadapté à WoW sans fork massif.

---

### 5. Nox

**Statut :** langage fonctionnel typé compilant vers Lua. ([GitHub][13])

**Qualité :** intéressant mais petit/expérimental.

**Verdict :** référence d’architecture, pas fondation CraftGold.

---

### 6. `lua_of_ocaml` / `loo`

**Statut :** très récent, expérimental, annoncé en 2026, avec discussions publiques indiquant une maturité faible. ([OCaml][14])

**Verdict :** pas utilisable pour CraftGold maintenant.

---

### 7. Haxe Lua

**Statut :** backend réel, Lua 5.1 supporté. ([Haxe - The Cross-platform Toolkit][15])

**Problème :** ce n’est pas un langage FP à la Haskell/Scala/ML.

**Verdict :** bon fallback pragmatique, pas la réponse à ta recherche.

---

### 8. Crystal → Lua

Je n’ai pas trouvé de backend Crystal → Lua crédible et maintenu. Crystal vise plutôt du natif via LLVM ; ce n’est pas une piste réaliste pour WoW Lua.

**Verdict :** non.

---

### 9. Carp → Lua

Carp est un Lisp statiquement typé orienté performance, avec ownership et compilation vers C, notamment pour jeux/son/visualisation. ([GitHub][36])

Je n’ai pas trouvé de backend Lua crédible.

**Verdict :** non pour CraftGold.

---

### 10. Autres “ML to Lua”

Il existe des inventaires de langages compilant vers Lua, listant notamment LunarML, PureScript Lua, Idris2-Lua, Nox, Amulet et d’autres projets plus petits. ([GitHub][37])

**Verdict :** l’écosystème existe, mais aucun projet ne donne directement :

```text
Haskell/Scala/ML-level abstractions
+ Lua 5.1 strict
+ no require
+ low GC
+ readable stack traces
+ WoW-ready
```

---

## Axe 7 : Build-it-yourself

### Stack Haskell : faisabilité et effort

C’est la voie que je recommande.

Architecture :

```text
CraftGold DSL
  - Haskell EDSL ou quasiquoted DSL
  - types fantômes pour ItemID, Money, Qty, RecipeID
  - ADT Haskell côté compile-time

Typed Core
  - fonctions pures
  - effets WoW abstraits
  - records/ADT simples

Optimizer
  - DCE
  - inlining
  - specialization
  - lambda lifting
  - fusion map/filter/fold
  - unboxing Maybe/Either
  - monomorphization

Lua51 Backend
  - AST Lua 5.1 restreint
  - pretty-printer
  - dialect checker
  - debug comments
```

Effort réaliste, estimation personnelle :

```text
Prototype minimal :
  2–4 semaines
  - expressions
  - fonctions pures
  - appels WoW
  - génération Lua lisible
  - tests hors WoW

Version CraftGold utile :
  2–3 mois
  - ADT simples
  - pattern matching
  - Free/Tagless effects
  - DCE
  - inlining simple
  - scheduler WoW basique
  - fixtures de test

Version robuste :
  3–6 mois
  - fusion
  - spécialisation typeclass-like
  - source maps/commentaires
  - benchmark Lua 5.1
  - vérificateur upvalues/locals
  - CI avec Lua 5.1

Compilateur général :
  12–24+ mois
  - parser complet
  - inférence
  - modules
  - erreurs propres
  - optimizer sérieux
  - tooling
```

### Stack Scala : faisabilité et effort

Scala 3 macros peuvent clairement faire le frontend typé. ([nightly.scala-lang.org][4])

Mais il te manquera plus vite :

```text
- un bon AST Lua mature
- un écosystème compiler DSL aussi naturel que Haskell
- une quasiquotation Lua robuste
- un typage d’EDSL aussi direct que GADT Haskell
```

Effort estimé :

```text
Prototype Scala macro DSL :
  3–6 semaines

Version CraftGold robuste :
  3–6 mois

Mais avec plus de friction tooling qu’en Haskell.
```

### Le “compilateur scoped” : combien de travail ?

Oui, un compilateur scoped est **beaucoup plus simple** qu’un compilateur général.

Tu n’as pas besoin de supporter :

```text
- récursion arbitraire non contrôlée
- laziness
- modules utilisateur
- higher-rank runtime
- exceptions générales
- concurrency générale
- type inference complète si Haskell/Scala host type déjà
- optimisations universelles
```

Tu as besoin de supporter :

```text
- fonctions pures
- boucles/folds
- records
- ADT simples
- pattern matching exhaustif
- effets WoW abstraits
- state machines event-driven
- données statiques
```

Donc oui : **pour CraftGold, un compilateur scoped est raisonnable**.

---

## Recommandation finale

### Ne fais pas ça

```text
Full Haskell → Lua 5.1
GHC Core → Lua
OCaml bytecode → Lua pour WoW
Idris → Lua pour addon WoW
Free Monad runtime en Lua
```

Trop lourd, trop de runtime, trop de GC, stack traces illisibles.

### Fais plutôt ça

```text
Haskell EDSL / Tagless Final
        ↓
Reified Core IR
        ↓
ANF / CFG impératif
        ↓
Lua 5.1 lisible
```

### Design concret recommandé pour CraftGold

```haskell
class Monad m => CraftDSL m where
  getItemInfo     :: ItemID -> m (Maybe ItemInfo)
  getAuctionPrice :: ItemID -> Qty -> m (Maybe Money)
  printLine       :: Text -> m ()

  lookupRecipe    :: ItemID -> m (Maybe Recipe)
  cheapestCost    :: ItemID -> Qty -> m (Maybe Money)
```

Interpréteurs :

```haskell
TestM  :: exécute en pur avec MockWorld
TraceM :: produit un log de décisions
LuaM   :: génère une IR
```

Puis backend :

```text
LuaM
  ↓
IR
  ↓
optimize
  ↓
emit Lua 5.1
```

### Représentation cible

```text
Maybe Money:
  nil | number

Recipe:
  table statique précompilée

Enum profession:
  integer tag

Effect Wow:
  appel direct _G ou wrapper CG_API

Async:
  state machine explicite

Collections:
  arrays Lua 1-based

map/filter/fold:
  jamais runtime ; toujours fusionnés si hot path
```

### Exemple final attendu

Source DSL :

```haskell
bestProfit recipes = do
  foldRecipes recipes Nothing $ \best recipe -> do
    cost <- craftCost recipe
    sale <- auctionSellPrice (output recipe)
    let profit = sale - cost
    pure (maxMaybe best profit)
```

Lua généré :

```lua
function CG_bestProfit(recipes)
  local best = nil

  for i = 1, #recipes do
    local recipe = recipes[i]
    local cost = CG_craftCost(recipe)
    local sale = CG_auctionSellPrice(recipe.output)

    if cost ~= nil and sale ~= nil then
      local profit = sale - cost
      if best == nil or profit > best then
        best = profit
      end
    end
  end

  return best
end
```

C’est exactement le genre de Lua que tu veux : lisible, debuggable, sans runtime fonctionnel, sans closures inutiles.

### Conclusion brutale

**Compiler un langage fonctionnel typé vers Lua 5.1 pour WoW est possible.**

Mais :

```text
possible ≠ compiler Haskell général
possible = compiler un sous-langage strict, spécialisé, optimisé, sans runtime
```

La meilleure architecture est :

```text
Haskell pour penser.
Lua pour exécuter.
IR maison pour contrôler.
WoW comme contrainte absolue.
```

---

## Sources

* Cahier des charges utilisateur : contraintes CraftGold, Lua 5.1, WoW, Free Monad, IR, optimisations. 
* `language-lua` : lexer/parser/pretty-printer Lua 5.3, AST et pretty-printer. ([GitHub][1])
* HsLua : bridge Haskell/Lua, embedding Lua, usage Pandoc. ([GitHub][2])
* Quasiquotation Haskell : parsing DSL, méta-variables, génération AST. ([well-typed.com][3])
* Scala 3 macros et QDSL : génération de code à la compilation, DSL typé vers langage cible. ([nightly.scala-lang.org][4])
* Scalup : parser/pretty-printer Lua en Scala. ([GitHub][6])
* LunarML : SML vers Lua/JavaScript, support SML’97, modules/foncteurs, targets Lua 5.3+/LuaJIT. ([lunarml.readthedocs.io][7])
* PureScript Lua : backend Lua, FFI, bundling, DCE, inlining. ([GitHub][9])
* PureScript backend optimizer : CoreFn, pipeline d’inlining/optimisation. ([GitHub][10])
* Amulet : langage ML-like, ADT/pattern matching, projet arrêté. ([GitHub][11])
* Idris2-Lua : backend Lua 5.1/5.2/5.3/LuaJIT, dépendances et limitations. ([GitHub][12])
* Nox : langage fonctionnel typé avec inférence HM et compilation Lua. ([GitHub][13])
* `lua_of_ocaml` / `loo` : projet récent OCaml bytecode → Lua 5.1, maturité faible. ([OCaml][14])
* Haxe Lua : backend Lua 5.1/5.2/5.3/LuaJIT. ([Haxe - The Cross-platform Toolkit][15])
* Carp : langage Lisp statiquement typé, compilation C, pas backend Lua crédible trouvé. ([GitHub][36])
* Inventaires de langages compilant vers Lua. ([GitHub][37])
* Lua 5.1 : limite 60 upvalues, 200 locals, absence de `goto` avant Lua 5.2. ([lua.org][20])
* WoW add-ons : `.toc`, ordre de chargement, Lua 5.1 custom. ([Warcraft Wiki][18])
* WoW runtime : “script ran too long” et GC pressure, sources communautaires. ([WoWInterface][34])
* Free Monad : DSL comme données, interprétation multiple. ([typelevel.org][24])
* Performance Free Monad / bind chains : Reflection without Remorse. ([okmij.org][25])
* Tagless Final : DSL typé par classes/interpréteurs. ([Tech, Science, Math and more...][26])
* Defunctionalization : transformation higher-order vers first-order. ([SIGPLAN Blog][22])
* Lambda lifting : réduction des closures et variables libres. ([haskell.foundation][21])
* Pattern matching ML : compilation efficace en arbres de décision. ([moscova.inria.fr][23])
* Fusion `foldr/build` : élimination de listes intermédiaires. ([well-typed.com][19])
* Elm : DCE, minification, réduction de taille. ([elm-lang.org][27])
* GHCJS / GHC WASM / Asterius : runtime, CPS, heap, GC, trampoline. ([Chalmers Publication Library (CPL)][16])
* `js_of_ocaml` : OCaml bytecode vers JavaScript, niveaux d’optimisation. ([OCaml][29])
* Fable : compilation F# vers JS, unions/pattern matching. ([Fable][31])

[1]: https://github.com/osa1/language-lua "GitHub - osa1/language-lua: Lua parser and pretty-printer · GitHub"
[2]: https://github.com/hslua/hslua "GitHub - hslua/hslua: Haskell bindings to Lua, an embeddable scripting language. · GitHub"
[3]: https://well-typed.com/blog/2014/10/quasi-quoting-dsls/ "Quasi-quoting DSLs for free - Well-Typed: The Haskell Consultants"
[4]: https://nightly.scala-lang.org/docs/reference/metaprogramming/macros.html "Macros"
[5]: https://idiomaticsoft.com/post/2023-08-08-qdsl/ "Exploring Scala 3 Macros: A Toy Quoted Domain Specific Language"
[6]: https://github.com/FredyH/scalup "GitHub - FredyH/scalup: A Scala (G)Lua parser · GitHub"
[7]: https://lunarml.readthedocs.io/en/v0.2.1/intro.html "Introduction — LunarML  documentation"
[8]: https://github.com/minoki/LunarML "GitHub - minoki/LunarML: The Standard ML compiler that produces Lua/JavaScript · GitHub"
[9]: https://github.com/Unisay/purescript-lua "GitHub - Unisay/purescript-lua: Purescript compiler back-end for Lua · GitHub"
[10]: https://github.com/aristanetworks/purescript-backend-optimizer?utm_source=chatgpt.com "aristanetworks/purescript-backend-optimizer"
[11]: https://github.com/amuletml/amulet "GitHub - amuletml/amulet: An ML-like functional programming language · GitHub"
[12]: https://github.com/Russoul/Idris2-Lua "GitHub - Russoul/Idris2-Lua: Lua backend for Idris 2 · GitHub"
[13]: https://github.com/coetaur0/nox "GitHub - coetaur0/nox: The Nox programming language · GitHub"
[14]: https://discuss.ocaml.org/t/ann-loo-lua-of-ocaml/18143/1 "[ANN] loo - lua of ocaml - Community - OCaml"
[15]: https://haxe.org/manual/target-lua-getting-started.html "Getting started with Haxe/Lua - Haxe - The Cross-platform Toolkit"
[16]: https://publications.lib.chalmers.se/records/fulltext/227615/227615.pdf?utm_source=chatgpt.com "A Distributed Haskell for the Modern Web"
[17]: https://github.com/grin-compiler/grin?utm_source=chatgpt.com "GRIN is a compiler back-end for lazy and strict functional ..."
[18]: https://warcraft.wiki.gg/wiki/TOC_format?utm_source=chatgpt.com "TOC format - Warcraft Wiki"
[19]: https://well-typed.com/blog/2024/03/haskell-unfolder-episode-22-foldr-build-fusion/?utm_source=chatgpt.com "The Haskell Unfolder Episode 22: foldr-build fusion"
[20]: https://www.lua.org/source/5.1/luaconf.h.html "Lua 5.1.5 source code - luaconf.h"
[21]: https://haskell.foundation/hs-opt-handbook.github.io/src/Optimizations/GHC_opt/lambda_lifting.html?utm_source=chatgpt.com "3.2.3. Lambda Lifting | Haskell Optimization Handbook"
[22]: https://blog.sigplan.org/2019/12/30/defunctionalization-everybody-does-it-nobody-talks-about-it/?utm_source=chatgpt.com "Defunctionalization: Everybody Does It, Nobody Talks ..."
[23]: https://moscova.inria.fr/~maranget/papers/ml05e-maranget.pdf?utm_source=chatgpt.com "Compiling Pattern Matching to Good Decision Trees - Moscova"
[24]: https://typelevel.org/cats/datatypes/freemonad.html?utm_source=chatgpt.com "Free Monad"
[25]: https://okmij.org/ftp/Haskell/zseq.pdf?utm_source=chatgpt.com "Reflection without Remorse - okmij.org"
[26]: https://jproyo.github.io/posts/2019-03-17-tagless-final-haskell/?utm_source=chatgpt.com "Tagless Final Encoding in Haskell"
[27]: https://elm-lang.org/news/small-assets-without-the-headache?utm_source=chatgpt.com "Small Assets without the Headache"
[28]: https://tweag.io/blog/2022-11-22-wasm-backend-merged-in-ghc/?utm_source=chatgpt.com "WebAssembly backend merged into GHC"
[29]: https://ocaml.org/p/js_of_ocaml-compiler/6.0.1?utm_source=chatgpt.com "js_of_ocaml-compiler 6.0.1 · OCaml Package"
[30]: https://ocsigen.org/js_of_ocaml/latest/manual/options?utm_source=chatgpt.com "Command-line options"
[31]: https://fable.io/docs/typescript/features.html?utm_source=chatgpt.com "Features"
[32]: https://addonstudio.org/wiki/WoW%3ALua?utm_source=chatgpt.com "WoW:Lua"
[33]: https://www.lua.org/versions.html?utm_source=chatgpt.com "Lua: version history"
[34]: https://wowinterface.com/forums/printthread.php?pp=60&t=45431&utm_source=chatgpt.com "Constant errors across addons, 'script ran too long'"
[35]: https://github.com/bkader/GarbageProtector?utm_source=chatgpt.com "bkader/GarbageProtector"
[36]: https://github.com/carp-lang/Carp?utm_source=chatgpt.com "carp-lang/Carp: A statically typed lisp, without a GC, for real ..."
[37]: https://github.com/hengestone/lua-languages?utm_source=chatgpt.com "hengestone/lua-languages: Languages that compile to Lua"
