# Recherche Ultime : Langages de haut niveau compilant vers Lua pour le développement d'add-ons World of Warcraft

## Contexte et motivation

Je développe **CraftGold**, un add-on World of Warcraft Classic Era (interface 11508) écrit en Lua 5.1. L'add-on analyse les recettes de métiers (Engineering, Alchemy, Blacksmithing, etc.), calcule les coûts optimaux de craft via un algorithme récursif (DP knapsack pour les achats HdV, arbre de recettes pour buy vs craft), et identifie les crafts rentables.

**Mon problème fondamental** : Lua 5.1 est un langage très limité. Pas de système de types, pas de pattern matching, pas de structures monadiques, pas d'ADT (Algebraic Data Types), pas d'abstraction IO. Le mocking de l'API WoW est fait manuellement via une "seam" (un module WoW.lua qui wrappe chaque fonction). Les tests sont lourds à configurer. Le code métier pur (algorithmes récursifs) est mélangé à des préoccupations d'état mutable, de cycle detection via sets manuels, etc.

**Ce que je veux** : écrire dans un langage de très haut niveau, fonctionnel et/ou déclaratif, qui **compile/transpile vers du Lua 5.1 compatible**. Ce langage doit permettre :
- Des abstractions fonctionnelles puissantes (monades, ADT, pattern matching, higher-kinded types si possible)
- La séparation nette entre logique pure et effets de bord (IO monad, Free Monad, ou équivalent)
- Un système de mocking élégant et naturel de l'API WoW
- Des tests unitaires propres
- Si possible, des optimisations à la compilation (IR intermédiaire, dead code elimination, etc.)
- Un typage statique (optionnel mais fortement souhaité)

**IMPORTANT** : Le Lua généré doit être compatible Lua 5.1 (JIT-compatible), car c'est ce que le client WoW Classic Era embarque. Pas de Lua 5.3+ features (bitwise operators, etc.).

## Architecture actuelle du projet CraftGold

Pour comprendre ce que le langage devra exprimer, voici l'architecture :

### Modules (dernière capsule, 16 modules)

```
WoW.lua         → Seam : wrappe toutes les fonctions WoW (GetItemInfo, QueryAuctionItems, etc.)
DB.lua          → Base de données statique de recettes (1500+ recettes, ~1500 lignes de données)
Core.lua        → Requêtes sur la DB (getByOutput, getByReagent, isCraftable, etc.)
Money.lua       → Formatage monétaire (copper → "2g 50s 30c")
Prices.lua      → Prix manuels (SavedVariables-backed)
Listings.lua    → Stockage des annonces HdV (itemID → [{count, buyout}])
Quote.lua       → Algorithme DP knapsack 0/1 pour coût d'achat optimal
Calculator.lua  → Calcul récursif min(buy, craft) avec détection de cycles
BOM.lua         → Expansion récursive en matières premières (Bill of Materials)
Scanner.lua     → Machine à états pour le scan HdV (pagination, throttling, queue)
ItemInfo.lua    → Cache et formatage des noms d'items via GetItemInfo
ItemPreloader.lua → Préchargement asynchrone des données d'items
Report.lua      → Formatage des résultats pour le chat WoW
CmdLang.lua     → Langage de commandes déclaratif (parsing, types, help auto)
FullScan.lua    → Scan complet de l'HdV (getAll)
Core.lua (main) → Event handlers, initialisation, enregistrer les slash commands
```

### Patterns récurrents à traduire

#### 1. Seam WoW (mocking manuel)
```lua
-- src/WoW.lua — Actuellement : wrapping manuel de chaque fonction
local WoW = {}
WoW.GetItemInfo = function() return nil end  -- fallback
WoW.QueryAuctionItems = function() end

function WoW.init(env)
    WoW.GetItemInfo = env.GetItemInfo or WoW.GetItemInfo
    WoW.QueryAuctionItems = env.QueryAuctionItems or WoW.QueryAuctionItems
    -- ... 10+ autres fonctions
end

-- Dans le code métier :
local name = ns.WoW.GetItemInfo(itemID)
```
**Ce que je veux** : un système où l'API WoW est un type/interface/effet, et où le mocking se fait par injection de type ou par interprétation différente d'une monade IO.

#### 2. Calcul récursif avec état mutable (Calculator)
```lua
function Calculator._calculate(itemID, qty, state)
    qty = qty or 1
    if state.visiting[itemID] then return nil end  -- cycle detection
    state.visiting[itemID] = true

    -- Buy option
    local buyCost = nil
    local quoteResult = ns.Quote.quote(itemID, qty)
    if quoteResult then
        buyCost = quoteResult.cost
    else
        local unitPrice = ns.Prices.get(itemID)
        if unitPrice then buyCost = unitPrice * qty end
    end

    -- Craft option
    local craftCost = nil
    local recipe = ns.Core.getByOutput(itemID)
    if recipe then
        local total = 0
        for _, reagent in ipairs(recipe.reagents) do
            local r = Calculator._calculate(reagent[1], reagent[2] * qty, state)
            if r then total = total + r.cost end
        end
        craftCost = total
    end

    state.visiting[itemID] = nil
    -- min(buy, craft) decision
    ...
end
```
**Ce que je veux** : écrire ceci de manière fonctionnelle pure, avec un type Result/Option, du pattern matching, et la cycle detection comme un effet ou un State monad.

#### 3. Machine à états asynchrone (Scanner)
```lua
-- Scanner.lua : IDLE → SCANNING → accumulate results → deliver → dequeue
-- Utilise des callbacks, des frames OnUpdate, des événements WoW
function Scanner.onItemListUpdate()
    if not Scanner._active then return end
    local numBatch, total = ns.WoW.GetNumAuctionItems("list")
    -- Parse results, check pagination, deliver or request next page
    ...
end
```
**Ce que je veux** : une abstraction sur l'asynchrone (Free Monad, async/await, coroutines structurées) qui compile vers des callbacks Lua.

#### 4. Base de données déclarative
```lua
-- DB.lua : 1500+ entrées comme celle-ci
R(3928, 4401, {{774, 2}, {2840, 1}, {4359, 1}, {4363, 1}}, 75, "trainer")
-- spellID, output itemID, reagents[{id, count}], skillRequired, source
```
**Ce que je veux** : pouvoir écrire la DB dans un format type-safe, éventuellement avec des smart constructors, et la valider à la compilation.

#### 5. Langage de commandes déclaratif (CmdLang)
```lua
cmd:register {
    name = "listing",
    help = "Manage AH listings",
    subs = {
        add = {
            help = "Add a listing",
            args = {
                { "itemID:int", "Item ID" },
                { "count:int", "Stack size" },
                { "buyout:money", "Buyout price" },
            },
            handler = function(args, ctx) ... end,
        },
    },
}
```
**Ce que je veux** : des ADT pour les commandes, du pattern matching sur les args, validation par le système de types.

### Tests actuels (busted)

```lua
-- tests/helpers.lua — Chargement manuel de chaque module
local ns = {}
for _, file in ipairs(files) do
    assert(loadfile(file))("QuoteDP", ns)
end

-- tests/test_calculator_v2.lua
describe("Calculator v2 — buy vs craft", function()
    before_each(function()
        ns = testHelper.setup()  -- charge tous les modules avec mocks
    end)

    it("chooses buy when cheaper", function()
        ns.Prices.set(2840, 1000)
        ns.Listings.add(4359, 1, 800)
        local result = ns.Calculator.calculate(4359)
        assert.are.equal(800, result.cost)
        assert.are.equal("buy", result.method)
    end)
end)
```
**Ce que je veux** : des tests qui s'écrivent naturellement, avec un mocking qui découle du système de types, pas d'un fichier helpers.lua custom.

## Spécification du Lua cible

Le Lua généré doit :
1. Être **Lua 5.1 compatible** (pas de `goto`, pas d'opérateurs bitwise `&|~`, pas de `<` pour les strings, etc.)
2. Fonctionner dans l'environnement WoW (pas de `require` standard, chargement via `.toc` files)
3. Interopérer avec le code Blizzard existant (accès à `_G`, frames, événements)
4. Être performant (WoW a un budget CPU/tick limité)
5. Générer du code lisible (si un bug survient en jeu, on doit pouvoir le debugger)

## Critères d'évaluation

Pour chaque langage/outil, évaluez sur ces axes (notez de 1 à 5 et justifiez) :

| Critère | Description |
|---------|-------------|
| **Maturité** | Stabilité, communauté, documentation, maintenance active |
| **Paradigme FP** | Types algébriques, pattern matching, monades, higher-order functions, immutabilité |
| **Séparation IO** | Capacité à séparer logique pure des effets (IO monad, Free Monad, tagless final, etc.) |
| **Typage** | Statique, inférence, expressive (ADT, GADT, type classes, etc.) |
| **Mocking** | Facilité de mocker une API externe (WoW) pour les tests |
| **Qualité du Lua généré** | Lisibilité, performance, compatibilité 5.1 |
| **Testing** | Framework de test intégré ou compatible |
| **Optimisation** | Optimisations à la compilation (IR, dead code elimination, inlining) |
| **Interop Lua** | Capacité à appeler du Lua existant et être appelé par du Lua |
| **DX (Developer Experience)** | Tooling, LSP, REPL, hot reload, error messages |
| **Adoption WoW** | Existant dans la communauté WoW add-on dev |

## Langages et outils à investiguer

### Catégorie 1 : Langages fonctionnels compilant vers Lua

1. **Fennel** — Lisp sur Lua. Très mature, utilisé dans LÖVE, Neovim, TIC-80. Évaluez : pattern matching, macro système, capacité d'abstraction monadique.

2. **Amulet** — ML-style (OCaml-like) compilant vers Lua. Évaluez : types, pattern matching, modules functors, état du projet.

3. **Urn** — Lisp sur Lua avec influence Scheme. Évaluez : capacités fonctionnelles, macros, types.

4. **Nelua** — Langage système avec typage optionnel compilant vers Lua ou C. Évaluez : paradigme, capacités fonctionnelles.

5. **Lea** (ou tout projet Haskell-like → Lua) — Existe-t-il un langage Haskell-like qui compile vers Lua ?

6. **Vale** — S'il compile vers Lua.

7. Tout autre langage ML/Haskell/Scala-like qui compile vers Lua et que vous trouveriez.

### Catégorie 2 : Langages multi-cibles incluant Lua

8. **Haxe** — Multi-paradigme, compile vers Lua (et 10+ autres cibles). Évaluez : capacités fonctionnelles, types, pattern matching, qualité du Lua généré.

9. **TypeScriptToLua (TSTL)** — TypeScript → Lua. Très utilisé dans la communauté WoW (Delve, etc.). Évaluez : capacités fonctionnelles (monades, ADT?), qualité du Lua, mocking, interop WoW.

10. **ClojureScript** — Si un backend Lua existe (Lumen? Clojure2D?).

### Catégorie 3 : Langages typés pour Lua

11. **Teal** — Langage typé qui compile vers Lua (et vérifie les types). Évaluez : expressivité du système de types, capacités fonctionnelles.

12. **Luau** (Roblox) — Typed Lua. Pas applicable directement (Roblox only?) mais évaluez si des idées s'appliquent.

13. **Selene** — Linter/typer pour Lua. Pas un langage, mais évaluez son utilité.

### Catégorie 4 : Approches méta/outils

14. **Macro systems sur Lua** — Terra, LuaJIT FFI, ou systèmes de macros qui ajouteraient des capacités fonctionnelles.

15. **Source-to-source compilers** — Outils qui prennent un langage et génèrent du Lua 5.1 (OCaml → Lua? PureScript → Lua? Elm → Lua?).

16. **Embedded DSL en Haskell/Scala/FP** — Écrire un DSL en Haskell ou Scala qui génère du Lua. Évaluez la faisabilité et les outils existants.

## Pour chaque option, je veux

### 1. Vue d'ensemble
- Nom, URL, licence, année de création, dernière mise à jour
- Paradigme principal (fonctionnel, impératif, multi)
- Système de types (dynamique, statique, graduel, aucun)
- Runtime requirements (Lua 5.1? 5.3? JIT?)
- Taille de la communauté (GitHub stars, Discord members, etc.)

### 2. Exemples concrets appliqués à CraftGold

Montrez comment on écrirait **exactement** ces morceaux de CraftGold dans le langage :

#### a) Calculator — calcul récursif min(buy, craft)
```lua
-- Version Lua actuelle (simplifiée) :
function Calculator._calculate(itemID, qty, state)
    if state.visiting[itemID] then return nil end
    state.visiting[itemID] = true

    local buyCost = nil
    local quoteResult = ns.Quote.quote(itemID, qty)
    if quoteResult then
        buyCost = quoteResult.cost
    else
        local p = ns.Prices.get(itemID)
        if p then buyCost = p * qty end
    end

    local craftCost = nil
    local recipe = ns.Core.getByOutput(itemID)
    if recipe then
        local total = 0
        for _, r in ipairs(recipe.reagents) do
            local sub = Calculator._calculate(r[1], r[2] * qty, state)
            if sub then total = total + sub.cost end
        end
        craftCost = total
    end

    state.visiting[itemID] = nil

    if buyCost and craftCost then
        return buyCost <= craftCost
            and { cost = buyCost, method = "buy", craftCost = craftCost }
            or { cost = craftCost, method = "craft", buyPrice = buyCost }
    elseif buyCost then
        return { cost = buyCost, method = "buy" }
    elseif craftCost then
        return { cost = craftCost, method = "craft" }
    end
    return nil
end
```

Montrez la version dans VOTRE langage avec :
- Types (ADT pour Method = Buy | Craft, Option/Maybe pour les coûts)
- Pattern matching
- Cycle detection élégante (State monad? ReaderT? Effet?)
- Séparation de la logique pure (Calculator) des effets (Quote.quote, Prices.get)

#### b) WoW API Seam + Mocking
```lua
-- Version Lua actuelle :
-- Chaque fonction WoW est wrappée dans WoW.lua, mockée dans les tests
-- par injection d'un env de test via WoW.init(env)
```

Montrez comment on définirait l'API WoW comme une interface/effet/type class, et comment on la mockerait dans les tests.

#### c) Test unitaire
```lua
-- Version Lua actuelle (busted) :
it("chooses buy when cheaper", function()
    ns.Prices.set(2840, 1000)
    ns.Listings.add(4359, 1, 800)
    local result = ns.Calculator.calculate(4359)
    assert.are.equal(800, result.cost)
    assert.are.equal("buy", result.method)
end)
```

Montrez le test équivalent dans votre langage, en mettant en évidence comment le mocking est naturel.

#### d) Code généré
Montrez le **Lua 5.1 généré** pour l'un des exemples ci-dessus. Est-il lisible ? Performant ? Compatible WoW ?

### 3. Système de build et tooling
- Comment build ? (CLI, build system, intégration possible avec un workflow WoW add-on ?)
- LSP / IDE support ?
- REPL / interactive development ?
- Hot reload possible ?
- Source maps / debug ?

### 4. Optimisations à la compilation
- Y a-t-il un IR intermédiaire ?
- Optimisations possibles (inlining, DCE, specialization, tail-call optimization) ?
- Possibilité d'écrire des passes d'optimisation custom ?

### 5. Limites et risques
- Qu'est-ce qui manque ?
- Quels sont les bugs connus ?
- Quelle est la probabilité que le projet soit abandonné ?
- Y a-t-il des limitations fondamentales (features Lua 5.1 non supportées, etc.) ?

## Sources exigées

**Chaque affirmation doit être sourcée.** Fournissez des liens vers :
- Documentation officielle
- GitHub repositories
- Articles de blog, talks
- Exemples d'add-ons WoW écrits dans ce langage (s'ils existent)
- Discussions sur les forums (WoWInterface, CurseForge, Reddit, Discord)
- Comparaisons entre langages

## Format de réponse

**Répondez ENTIÈREMENT en markdown dans un seul bloc texte.** Pas de fichiers séparés, pas d'artifacts à télécharger. Tout (code, exemples, tableaux, liens) doit être inline dans la réponse markdown.

Structurez votre réponse ainsi :

```markdown
# Tour d'Horizon : Langages compilant vers Lua pour WoW Add-on Development

## Résumé exécutif
[Top 3 recommandations avec justification]

## Évaluation détaillée

### [Langage 1]
#### Vue d'ensemble
#### Exemples CraftGold
#### Code généré
#### Tooling
#### Optimisations
#### Limites
#### Sources

### [Langage 2]
...

## Tableau comparatif
[Tableau avec tous les critères notés de 1 à 5]

## Recommandation finale
[Pour CraftGold spécifiquement, quelle approche recommandez-vous et pourquoi]

## Annexes
[Liens, resources, community info]
```

## Ambition

Je veux une recherche **exhaustive et ambitieuse**. N'hésitez pas à mentionner des projets expérimentaux, des proof-of-concepts académiques, des approches non conventionnelles. L'objectif n'est pas seulement de trouver "un langage qui compile vers Lua" mais de trouver la **meilleure abstraction possible** pour le problème spécifique de CraftGold : des algorithmes purs sur des données structurées, avec une IO boundary claire pour l'API WoW.

Si aucun langage existant ne satisfait les critères, dites-le clairement et proposez une approche DIY (ex: DSL en Haskell générant du Lua, avec un compilateur custom).

**Faites trois fois le tour d'Internet.** Cherchez sur GitHub, npm, LuaRocks, Hackage, les forums WoW, les game dev communities, les academic papers sur les compilateurs vers Lua, les Language Server Protocol implementations, etc.
