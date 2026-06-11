# Tour d'Horizon : Langages compilant vers Lua pour WoW Add-on Development

## Résumé exécutif

Pour CraftGold (addon WoW Classic Lua 5.1), les trois approches les plus réalistes aujourd’hui sont :

1. **TypeScriptToLua (TSTL)** – meilleur compromis global : typage statique puissant (union types, discriminated unions, generics), tooling de très haut niveau, usage réel dans la communauté d’addons WoW, support direct de Lua 5.1. [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)
2. **Teal** – Lua « ++ typé » minimaliste, très proche de Lua, support officiel de Lua 5.1‑5.4 (dont LuaJIT), excellente compatibilité avec l’écosystème Lua, ergonomie proche de TypeScript mais sans changement de runtime. [news.ycombinator](https://news.ycombinator.com/item?id=44000759)
3. **Fennel** – Lisp compilant vers Lua avec macros puissantes, très adapté à la construction de DSLs, abstraction fonctionnelle avancée, zéro overhead par rapport à Lua, support 5.1‑5.5. [sr](https://sr.ht/~technomancy/fennel/)

Pour les besoins ultra‑FP (ADT avancés, monades « sérieuses ») tu peux envisager **un noyau en langage ML‑like compilant vers Lua** (Amulet, PureScript-Lua, Nox…), mais ce sont des projets plus expérimentaux, avec moins de tooling et aucune adoption WoW connue. [github](https://github.com/Unisay/purescript-lua)

En pratique, pour CraftGold, je recommande :

- **Option A (pragmatique)** : tout migrer progressivement vers **TypeScriptToLua**, avec une couche « WoW API » typée et un cœur métier pur (calculateur, DP knapsack, BOM) sans effets.  
- **Option B (minimaliste)** : garder Lua mais ajouter **Teal** par-dessus pour le typage + un peu de structuration FP.  
- **Option C (macro‑heavy)** : combiner **Fennel** pour les parties à forte abstraction (command DSL, scanner async) et Lua/Teal pour le reste.

Le reste de la réponse détaille les options les plus pertinentes, puis un tableau comparatif et une recommandation focalisée sur CraftGold.

***

## Évaluation détaillée

### TypeScriptToLua (TSTL)

#### Vue d’ensemble

- **Nom / URL / licence**  
  - TypeScriptToLua – « A generic TypeScript to Lua transpiler ». [github](https://github.com/TypeScriptToLua/TypescriptToLua)
  - Repo : https://github.com/TypeScriptToLua/TypeScriptToLua. [github](https://github.com/TypeScriptToLua/TypescriptToLua)
  - Licence MIT. [github](https://github.com/TypeScriptToLua/TypescriptToLua)
- **Création et activité**  
  - Projet démarré autour de 2017 ; repository actif avec mises à jour jusqu’en 2026 (par ex. upgrade à TypeScript 6.0 et corrections en 2026). [github](https://github.com/TypeScriptToLua/TypescriptToLua)
- **Paradigme**  
  - Multi‑paradigme : OO, FP (fonctions d’ordre supérieur, generics, discriminated unions). [github](https://github.com/TypeScriptToLua/TypescriptToLua)
- **Système de types**  
  - TypeScript complet : typage statique, inférence, union/intersection types, discriminated unions, generics, mapped types, etc. [github](https://github.com/TypeScriptToLua/TypescriptToLua)
- **Runtime / cibles**  
  - Génère du Lua, configurable pour `luaTarget` 5.1, 5.2, 5.3, LuaJIT. [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)
  - Génère un runtime « lualib_bundle.lua » avec polyfills (Promises, classes, etc.), importé via `require("lualib_bundle")` par défaut. [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)
- **Communauté / maturité**  
  - Utilisé dans divers projets de jeu et outils, plusieurs milliers de stars GitHub, commits récents en 2026. [github](https://github.com/TypeScriptToLua/TypescriptToLua)
  - Adoption *WoW* explicitement documentée : tuto et retour d’expérience de migration d’un addon WoW vers TypeScript via TSTL. [wowinterface](https://wowinterface.com/forums/showthread.php?t=56829)

#### Exemples CraftGold – Calculator / IO boundary / mocking

Je montre ici une esquisse idiomatique en TypeScript, orientée vers :

- ADT pour la méthode (`"buy"` | `"craft"`).  
- Option sous forme `T | undefined`.  
- Séparation nette entre logique pure et dépendances (env WoW + services prix / hdv).  

##### Types métiers

```ts
// ADT pour la méthode choisie
type MethodKind = "buy" | "craft";

interface BuyResult {
  kind: "buy";
  cost: number;
  craftCost?: number;
}

interface CraftResult {
  kind: "craft";
  cost: number;
  buyPrice?: number;
}

type QuoteResult = BuyResult | CraftResult;

// Option type simple
type Option<T> = T | undefined;

// Interfaces d’accès aux données (effets)
interface PriceService {
  get(itemId: number): Option<number>;
}

interface QuoteService {
  quote(itemId: number, qty: number): Option<BuyResult>;
}

interface RecipeReagent {
  itemId: number;
  count: number;
}

interface Recipe {
  output: number;
  reagents: RecipeReagent[];
}

interface RecipeService {
  getByOutput(itemId: number): Option<Recipe>;
}

// « Effet » injecté dans la logique pure
interface Env {
  prices: PriceService;
  quote: QuoteService;
  recipes: RecipeService;
}
```

##### Calculateur pur avec cycle detection paramétrée

```ts
type VisitingSet = Record<number, true>;

function calculateInternal(
  env: Env,
  itemId: number,
  qty: number,
  visiting: VisitingSet
): Option<QuoteResult> {
  if (visiting[itemId]) return undefined;
  visiting[itemId] = true;

  // Option buy
  let buyCost: Option<number>;
  const quote = env.quote.quote(itemId, qty);
  if (quote) {
    buyCost = quote.cost;
  } else {
    const p = env.prices.get(itemId);
    buyCost = p !== undefined ? p * qty : undefined;
  }

  // Option craft
  let craftCost: Option<number>;
  const recipe = env.recipes.getByOutput(itemId);
  if (recipe) {
    let total = 0;
    for (const r of recipe.reagents) {
      const sub = calculateInternal(env, r.itemId, r.count * qty, visiting);
      if (!sub) {
        total = undefined as any;
        break;
      }
      total += sub.cost;
    }
    craftCost = total;
  }

  delete visiting[itemId];

  if (buyCost !== undefined && craftCost !== undefined) {
    if (buyCost <= craftCost) {
      return { kind: "buy", cost: buyCost, craftCost } as BuyResult;
    } else {
      return { kind: "craft", cost: craftCost, buyPrice: buyCost } as CraftResult;
    }
  } else if (buyCost !== undefined) {
    return { kind: "buy", cost: buyCost } as BuyResult;
  } else if (craftCost !== undefined) {
    return { kind: "craft", cost: craftCost } as CraftResult;
  }
  return undefined;
}

export function calculate(env: Env, itemId: number, qty = 1): Option<QuoteResult> {
  return calculateInternal(env, itemId, qty, {});
}
```

- **Séparation IO** : la fonction pure `calculate` ne touche pas à l’API WoW. Elle ne dépend que de l’interface `Env`, que tu peux implémenter via l’API WoW en production ou via mocks en test.  
- **Cycling** : `visiting` est un dictionnaire `itemId → true`, passé par référence (modèle proche de ton code Lua actuel, mais localisé dans une fonction pure sur `Env`).

##### Seam WoW + mocking via interfaces

Tu peux typer l’API WoW dans TypeScript et fournir **deux implémentations** :

- `RealWoWEnv` qui appelle `_G` via les bindings générés à partir de la doc Blizzard (le post Reddit montre comment générer un `wow.d.ts`). [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)
- `TestEnv` qui renvoie des valeurs de test en mémoire.

```ts
interface WoWApi {
  GetItemInfo(itemId: number): [string, string] | undefined;
  -- etc.
}

interface RuntimeEnv extends Env {
  wow: WoWApi;
}

// Implémentation réelle pour le client WoW
const realEnv: Env = {
  prices: { get: id => /* savedvariables */ undefined },
  quote: { quote: (id, qty) => /* hdv knapsack */ undefined },
  recipes: { getByOutput: id => /* DB statique */ undefined },
};

// En test : simple objet sans aucune référence WoW
const testEnv: Env = {
  prices: { get: id => (id === 2840 ? 1000 : undefined) },
  quote:  { quote: (id, qty) => (id === 4359 ? { kind: "buy", cost: 800 } : undefined) },
  recipes: { getByOutput: id => undefined },
};
```

##### Test unitaire en TypeScript

```ts
test("chooses buy when cheaper", () => {
  const env: Env = testEnv;
  const result = calculate(env, 4359)!;
  expect(result.cost).toBe(800);
  expect(result.kind).toBe("buy");
});
```

Tu testes ici **la logique pure** sans lancer WoW ni Lua ; Jest/Vitest ou autre runner fonctionnent directement sur TypeScript. TSTL ne sert que pour la phase de build de l’addon.

#### Code Lua 5.1 généré (exemple réaliste)

Le post « Developping Addons in Typescript » montre le type de code généré pour une simple classe statique : TSTL génère des helpers dans `lualib_bundle.lua` puis du Lua 5.1 pur qui les utilise. [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)

```ts
// TypeScript
class Test {
  static sayHello() {
    print("hello");
  }
}
Test.sayHello();
```

Compile typiquement vers :

```lua
-- extrait représentatif documenté dans le post WoW + TSTL
local ____lualib = require("lualib_bundle")
local __TS__Class = ____lualib.__TS__Class
local ____exports = {}
local Test = __TS__Class()
Test.name = "Test"
function Test.prototype.____constructor(self) end
function Test.sayHello(self)
  print("hello")
end
Test:sayHello()
return ____exports
```

- **Compatibilité 5.1** : le code ne dépend que de fonctionnalités 5.1 (`local`, `function`, `:`), et TSTL permet de cibler explicitement Lua 5.1. [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)
- **WoW et `require`** : WoW n’a pas `require`. Le tutoriel WoW+TSTL montre comment contourner : soit en réécrivant `require` via un mini‑loader et en empaquetant `lualib_bundle` dans le même namespace, soit en configurant `luaLibImport: "inline"` pour que les helpers soient inlinés dans chaque fichier et ne reposent plus sur `require`. [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)

#### Tooling et build

- **Build**  
  - `npx tstl` compile tout un projet TS en Lua. [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)
  - `tsconfig.json` avec section `tstl` (par ex. `luaTarget: "5.1"`). [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)
- **IDE / LSP**  
  - Tout l’écosystème TypeScript : VSCode, WebStorm, ESLint, Prettier, language server TS. [github](https://github.com/TypeScriptToLua/TypescriptToLua)
- **Tests**  
  - Tests sur le code TS via Jest/Vitest etc.  
  - Tu peux éventuellement lancer les tests aussi côté Lua (busted) si tu veux vérifier le code généré (mais ce n’est pas nécessaire tant que TSTL est stable).  
- **Hot reload / DX**  
  - TS + TSTL ne fournissent pas de hot‑reload WoW « clé en main », mais la boucle `TS → Lua → /reload` est scriptable ; on peut automatiser ça avec un script Node + symlink vers ton répertoire d’addons.  
- **Debug**  
  - Tu débogues le *code TS* avec stacktraces TS pendant les tests, et le *Lua généré* en jeu. Le code généré reste assez lisible, surtout si tu évites les gros patterns OO.

#### Optimisations

- TSTL est un **transpileur** : il générère du Lua relativement direct, sans IR complexe ni passes d’optimisation lourdes ; les perfs dépendent surtout de l’implémentation Lua (ici WoW/Lua 5.1). [github](https://github.com/TypeScriptToLua/TypescriptToLua)
- Il ajoute un petit runtime (`lualib`) pour features JS/TS (classes, spread, Promises, etc.), mais tu peux configurer l’import pour en limiter l’impact (`luaLibImport: "inline"`). [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)
- Le gros gain vient du **typage et du refactoring plus sûrs**, pas d’optimisations à la Haskell/OCaml.

#### Limites et risques

- **Paradigme FP** : très correct (generics, sum types via discriminated unions), mais pas de higher‑kinded types ni type classes : les monades/Free monads sont possibles mais un peu verbeuses.  
- **Interop WoW** : nécessite un petit travail de build (gestion de `require`, bundling du runtime) comme documenté dans l’article WoW+TSTL. [wowinterface](https://wowinterface.com/forums/showthread.php?t=56829)
- **Taille du runtime** : pour une grosse base de code, le surcoût de `lualib` reste modeste, mais pour un tout petit addon ça peut sembler lourd.  
- **Adoption WoW** : déjà utilisée dans la communauté, mais tu seras quand même dans une minorité par rapport aux addons 100 % Lua. [wowinterface](https://wowinterface.com/forums/showthread.php?t=56829)

***

### Teal

#### Vue d’ensemble

- **Nom / URL / licence**  
  - Teal – « a statically-typed dialect of Lua ». [github](https://github.com/terralang/terra)
  - Site : https://teal-language.org ; repo : https://github.com/teal-language/tl. [github](https://github.com/teal-language/tl)
  - Licence MIT. [github](https://github.com/teal-language/tl)
- **Création / activité**  
  - Projet démarré autour de 2019 ; version v0.24.7 publiée en 2025. [github](https://github.com/teal-language/tl)
- **Paradigme**  
  - Lua‑like, avec accent sur typage statique ; multi‑paradigme, très adapté à un style impératif/FP léger. [github](https://github.com/terralang/terra)
- **Système de types**  
  - Typage statique avec annotations facultatives, union types, generics, arrays, maps, records, interfaces. [github](https://github.com/terralang/terra)
- **Runtime / cibles**  
  - Fonctionne avec Lua 5.1‑5.4, y compris LuaJIT. [github](https://github.com/teal-language/tl)
  - `tl gen` compile `.tl` en `.lua` en **supprimant** simplement les types, donc pas de runtime additionnel. [github](https://github.com/teal-language/tl)
- **Communauté**  
  - ~2.6k stars GitHub, plusieurs dizaines de contributeurs, build tool dédié (Cyan), LSP et plugins d’éditeur. [github](https://github.com/teal-language/tl)

#### Exemples CraftGold – Calculator, seam, tests

##### Types

```lua
-- File: types.tl

-- ADT résultat via union de records
type BuyResult = {
  method: "buy",
  cost: number,
  craft_cost: number?
}

type CraftResult = {
  method: "craft",
  cost: number,
  buy_price: number?
}

type CalcResult = BuyResult | CraftResult

-- Services
record PriceService
  get: function(item_id: integer): number?
end

record QuoteService
  quote: function(item_id: integer, qty: integer): BuyResult?
end

record Reagent
  item_id: integer
  count: integer
end

record Recipe
  output: integer
  reagents: {Reagent}
end

record RecipeService
  get_by_output: function(item_id: integer): Recipe?
end

record Env
  prices: PriceService
  quote: QuoteService
  recipes: RecipeService
end
```

##### Calculateur pur + cycle detection

```lua
-- File: calculator.tl
local types = require "types"

local CalcResult = types.CalcResult
local Env = types.Env

local Visiting = { [integer]: boolean }

local function _calculate(env: Env, item_id: integer, qty: integer, visiting: Visiting): CalcResult?
  if visiting[item_id] then
    return nil
  end
  visiting[item_id] = true

  local buy_cost: number?
  local q = env.quote:quote(item_id, qty)
  if q then
    buy_cost = q.cost
  else
    local p = env.prices:get(item_id)
    if p then
      buy_cost = p * qty
    end
  end

  local craft_cost: number?
  local recipe = env.recipes:get_by_output(item_id)
  if recipe then
    local total = 0
    for _, r in ipairs(recipe.reagents) do
      local sub = _calculate(env, r.item_id, r.count * qty, visiting)
      if not sub then
        total = nil
        break
      end
      total = total + sub.cost
    end
    craft_cost = total
  end

  visiting[item_id] = false

  if buy_cost and craft_cost then
    if buy_cost <= craft_cost then
      return { method = "buy", cost = buy_cost, craft_cost = craft_cost }
    else
      return { method = "craft", cost = craft_cost, buy_price = buy_cost }
    end
  elseif buy_cost then
    return { method = "buy", cost = buy_cost }
  elseif craft_cost then
    return { method = "craft", cost = craft_cost }
  end
  return nil
end

local function calculate(env: Env, item_id: integer, qty: integer): CalcResult?
  qty = qty or 1
  return _calculate(env, item_id, qty, {})
end

return {
  calculate = calculate,
}
```

On reste très proche de ton Lua actuel, mais :

- La **logique pure** est isolée : `calculate` dépend de `Env`, pas de `_G`.  
- Le compilateur Teal vérifie les types et les unions (`CalcResult`) ; tu peux pattern matcher via `if result.method == "buy" then ... end`.

##### Seam WoW / mocking

L’API WoW peut être modélisée comme un `record` séparé, injecté au travers de tes services :

```lua
-- File: wow_api.tl
record WoWApi
  GetItemInfo: function(item_id: integer): (string?, string?) -- etc.
  QueryAuctionItems: function(...) -- à détailler
end

record RuntimeEnv extends Env
  wow: WoWApi
end
```

En production tu construis `Env` en utilisant `_G` ; en test tu crées un `Env` purement en mémoire.

##### Test unitaire avec Busted

Teal compile vers Lua ; tu peux donc écrire tes tests soit :

- en Teal + `tl gen` + busted,  
- soit directement en Lua en typant juste le code sous test en Teal.

Exemple en Lua (pour rester proche de ton existant) :

```lua
-- test_calculator_spec.lua (busted)
local calc = require "calculator"      -- Lua généré par tl

describe("Calculator — buy vs craft (Teal)", function()
  it("chooses buy when cheaper", function()
    local env = {
      prices = { get = function(id) return id == 2840 and 1000 or nil end },
      quote  = { quote = function(id, qty)
        return id == 4359 and { method = "buy", cost = 800 } or nil
      end },
      recipes = { get_by_output = function(_) return nil end },
    }
    local result = calc.calculate(env, 4359, 1)
    assert.is_truthy(result)
    assert.are.equal("buy", result.method)
    assert.are.equal(800, result.cost)
  end)
end)
```

#### Code Lua 5.1 généré

`tl gen module.tl` génère `module.lua` en supprimant les types et en gardant la structure du code. [github](https://github.com/teal-language/tl)

Par exemple, la fonction suivante :

```lua
-- Teal
local function add(a: number, b: number): number
   return a + b
end
```

est transformée en :

```lua
-- Lua 5.1 compatible
local function add(a, b)
  return a + b
end
```

Le compilateur Teal ne rajoute pas de runtime ; tu obtiens un Lua lisible, quasi identique à ton code source, seulement sans annotations. [github](https://github.com/teal-language/tl)

#### Tooling

- **CLI** : `tl run`, `tl check`, `tl gen`, plus un fichier `tlconfig.lua` pour configurer ton projet. [github](https://github.com/teal-language/tl)
- **Build system** : Cyan, un outil dédié pour builder des projets Teal complets. [github](https://github.com/teal-language/tl)
- **IDE / LSP** : support pour Vim, VSCode, Helix, etc., via le language server Teal. [news.ycombinator](https://news.ycombinator.com/item?id=44000759)
- **Intégration WoW** : tu peux garder exactement ta chaîne de build actuelle, et insérer un step `tl gen` qui te produit les `.lua` à mettre dans le `.toc`.

#### Optimisations

- Teal n’a pas d’IR sophistiqué ; il se contente de faire du **type‑checking** + génération directe de Lua. [news.ycombinator](https://news.ycombinator.com/item?id=44000759)
- Les perfs seront très proches de ton Lua actuel — tu peux éventuellement profiter d’erreurs détectées à la compilation pour simplifier certaines branches.

#### Limites et risques

- **Paradigme FP** : pas de pattern matching natif ni de higher‑kinded types ; tu peux émuler ADT via unions + champs `tag`, mais ce n’est pas Haskell‑like.  
- **Séparation IO** : tout repose sur ta discipline (interfaces `record`) ; Teal n’impose pas de monades.  
- **Adoption WoW** : je n’ai trouvé aucune preuve publique d’addons WoW écrits en Teal ; l’écosystème WoW est plutôt resté sur Lua ou est parti vers TypeScriptToLua. [wowinterface](https://wowinterface.com/forums/showthread.php?t=56829)

***

### Fennel

#### Vue d’ensemble

- **Nom / URL / licence**  
  - Fennel – « a lisp that compiles to Lua ». [sr](https://sr.ht/~technomancy/fennel/)
  - Site : https://fennel-lang.org ; repo hébergé sur SourceHut, miroir sur GitHub. [oylenshpeegul.gitlab](https://oylenshpeegul.gitlab.io/blog/posts/20240106/)
  - Licence MIT. [sr](https://sr.ht/~technomancy/fennel/)
- **Création / activité**  
  - Projet démarré autour de 2016, maintenu activement jusqu’en 2025. [sr](https://sr.ht/~technomancy/fennel/)
- **Paradigme**  
  - Lisp Clojure‑inspiré : macros, homoiconicité, fonctions d’ordre supérieur, style FP très naturel. [code.likeagirl](https://code.likeagirl.io/the-hidden-gem-of-lua-programming-c02103402ed6)
- **Système de types**  
  - Dynamique (comme Lua), pas de typage statique intégré.  
- **Runtime / cibles**  
  - Fennel requiert Lua 5.1–5.5 ou LuaJIT ; il compile vers du Lua avec « almost zero overhead compared to writing Lua directly ». [sr](https://sr.ht/~technomancy/fennel/)
- **Communauté / usages**  
  - Utilisé pour config/plugins Neovim, jeux Love2D, TIC‑80, etc. [reddit](https://www.reddit.com/r/neovim/comments/1q3hqzl/fennel_as_neovim_config/)

#### Exemples CraftGold

Je n’essaie pas d’être 100 % idiomatique Fennel, mais de montrer la structure.

##### ADT + calculateur

En Fennel, une ADT se représente naturellement comme une table avec un tag :

```clojure
;; types.fnl
(fn Buy [cost craft-cost]
  {:method :buy :cost cost :craft-cost craft-cost})

(fn Craft [cost buy-price]
  {:method :craft :cost cost :buy-price buy-price})
```

Calculateur avec environnement injecté :

```clojure
;; calculator.fnl
(local types (require :types))

;; visiting : table { [item-id] = true }
(fn calculate-internal [env item-id qty visiting]
  (when (?. visiting item-id)
    (values nil)) ; Option = nil ou table résultat

  (tset visiting item-id true)

  ;; buy option
  (var buy-cost nil)
  (let [quote ((. env.quote :quote) item-id qty)]
    (if quote
        (set buy-cost (. quote :cost))
        (let [p ((. env.prices :get) item-id)]
          (when p
            (set buy-cost (* p qty)))))

  ;; craft option
  (var craft-cost nil)
  (let [recipe ((. env.recipes :get-by-output) item-id)]
    (when recipe
      (var total 0)
      (each [_ r (ipairs (. recipe :reagents))]
        (let [sub (calculate-internal env (. r :item-id) (* (. r :count) qty) visiting)]
          (if (not sub)
              (do (set total nil) (lua :break))
              (set total (+ total (. sub :cost))))))
      (set craft-cost total)))

  (tset visiting item-id nil)

  (if (and buy-cost craft-cost)
      (if (<= buy-cost craft-cost)
          (types.Buy buy-cost craft-cost)
          (types.Craft craft-cost buy-cost))
      buy-cost (types.Buy buy-cost nil)
      craft-cost (types.Craft craft-cost nil)
      nil))

(fn calculate [env item-id qty]
  (calculate-internal env item-id (or qty 1) {}))
```

- **Séparation IO** : `env` est une table contenant `prices`, `quote`, `recipes`, éventuellement `wow`. Aucun accès direct à `_G`.  
- **Pattern matching** : Fennel ne fournit pas un `match` natif dans le cœur, mais il existe un *pattern matcher* utilisé assez largement et même porté vers Clojure (`fnl-match`, décrit comme « the pattern matcher from Fennel »). Tu peux très facilement écrire une macro de matching sur `:method`. [git.sr](https://git.sr.ht/~technomancy/fnl-match)

##### Seam WoW

Tu peux définir ton seam comme macro ou simple table :

```clojure
;; wow.fnl (Fennel)
(local wow {})

(fn wow.init [env]
  (set wow.GetItemInfo (or (. env :GetItemInfo) (fn [_] nil)))
  (set wow.QueryAuctionItems (or (. env :QueryAuctionItems) (fn [...] nil)))
  ;; ...
  )

(export {:wow wow})
```

En production tu appelles `wow.init(_G)` ; en test tu passes une table mock.

##### Test unitaire

Fennel se compile vers Lua ; tu peux donc :

- soit compiler ton code Fennel vers Lua et utiliser Busted ;  
- soit utiliser la bibliothèque de test de Fennel (il en existe plusieurs, mais même Busted reste compatible). [github](https://github.com/chrisman/fennel-pong)

Exemple Busted (sur Lua généré) :

```lua
local calc = require "calculator"  -- Lua issu de Fennel

describe("Calculator in Fennel", function()
  it("chooses buy when cheaper", function()
    local env = {
      prices = { get = function(id) return id == 2840 and 1000 or nil end },
      quote  = { quote = function(id, qty)
        if id == 4359 then return { method = ":buy", cost = 800 } end
      end },
      recipes = { get_by_output = function(_) return nil end },
    }
    local result = calc.calculate(env, 4359, 1)
    assert.truthy(result)
    assert.are.equal(":buy", result.method)
    assert.are.equal(800, result.cost)
  end)
end)
```

#### Code Lua généré

Fennel fournit un compilateur `fennel --compile`, ou tu peux l’embarquer (`fennel.lua`) et appeler `fennel.eval`. [sr](https://sr.ht/~benthor/absolutely-minimal-love2d-fennel/)

Par exemple, le `fib` Fennel :

```clojure
(fn fib [n]
  (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))
(print (fib 10))
```

se compile vers un Lua 5.1 lisible de la forme :

```lua
local function fib(n)
  if n < 2 then
    return n
  else
    return fib(n - 1) + fib(n - 2)
  end
end

print(fib(10))
```

La doc insiste sur le fait que Fennel a « almost zero overhead compared to writing Lua directly », donc le code généré reste très proche de ce que tu aurais écrit à la main. [code.likeagirl](https://code.likeagirl.io/the-hidden-gem-of-lua-programming-c02103402ed6)

#### Tooling

- **Installation** : un seul fichier `fennel.lua` ou une binaire autonome ; fonctionne sur n’importe quel Lua 5.1–5.5/LuaJIT. [sr](https://sr.ht/~technomancy/fennel/)
- **REPL** : REPL interactif ; largement utilisé dans l’écosystème Neovim. [dev](https://dev.to/dmass/setting-up-neovim-with-fennel-2apb)
- **Intégration build** : facilement intégrable dans une étape Makefile ou script Lua (`fennel --compile src > src.lua`). [github](https://github.com/chrisman/fennel-pong)
- **LSP / IDE** : il existe un language server Fennel, plus des plugins pour Neovim/Emacs ; ce n’est pas au niveau de TypeScript, mais suffisant pour un usage quotidien. [github](https://github.com/Olical/nfnl)

#### Optimisations

- Fennel ne dispose pas d’IR complexe ni d’optimisations agressives ; l’objectif est d’être une « thin layer » au‑dessus de Lua. [sr](https://sr.ht/~technomancy/fennel/)
- Les perfs dépendront de tes choix d’algorithmes et du VM Lua de WoW ; pas de JIT, mais pas d’overhead supplémentaire non plus.

#### Limites et risques

- **Pas de typage statique** : toute la sécurité passe par tests et discipline.  
- **Pattern matching / monades** : tu peux tout écrire via macros, mais tu ne bénéficies pas de garanties de type.  
- **Adoption WoW** : pas de traces publiques d’addons WoW en Fennel ; les usages documentés sont surtout Neovim, TIC‑80, Love2D. [en.wikipedia](https://en.wikipedia.org/wiki/TIC-80)

***

### Amulet (ML‑like → Lua)

#### Vue d’ensemble

- **Nom / URL / licence**  
  - Amulet (Amulet ML) – « a simple, modern programming language based on the ML family », compilant vers Lua. [squiddev](https://squiddev.cc/2019/08/30/amulet-backend.html)
  - Site : https://amulet.works ; repo : https://github.com/amuletml/amulet. [github](https://github.com/amuletml/amulet)
- **Paradigme**  
  - ML‑like strict, fortement typé, avec type system très expressif (GADTs, higher‑rank polymorphism, type classes, etc.). [amulet](https://amulet.works)
- **Système de types**  
  - Typage statique riche avec inference, vecteurs à longueur de type, fonctions de type, etc. [amulet](https://amulet.works/tutorials/01-intro.html)
- **Runtime / cibles**  
  - Amulet est conçu pour compiler vers Lua, mais aussi pour fonctionner comme langage autonome ; la doc ne détaille pas explicitement la version de Lua ciblée, mais l’outil est présenté comme visant « a lightweight, dynamically typed language commonly used for embedded scripting » (Lua). [squiddev](https://squiddev.cc/2019/08/30/amulet-backend.html)
- **Maturité**  
  - Dernière release 1.0.0.0 en 2020 ; l’activité récente est bien moindre que Teal ou TSTL. [github](https://github.com/amuletml/amulet)
  - Le méta‑repo « lua-languages » le marque comme fonctionnel mais non mainstream. [github](https://github.com/hengestone/lua-languages)

#### Exemples CraftGold (conceptuel)

Amulet a la syntaxe ML ; on peut y définir des ADT et du pattern matching très naturellement.

```ml
(* types.amulet *)
type method_ =
  | Buy of { cost : int; craft_cost : int option }
  | Craft of { cost : int; buy_price : int option }

type option 'a = None | Some of 'a

type reagent = { item_id : int; count : int }
type recipe  = { output : int; reagents : list reagent }

type env = {
  prices  : int -> int option;
  quote   : int -> int -> method_ option; (* buy quote only *)
  recipe  : int -> recipe option;
}
```

Calculateur :

```ml
let rec calculate_internal env item_id qty visiting =
  if Set.mem item_id visiting then None else
  let visiting = Set.add item_id visiting in
  let buy_cost =
    match env.quote item_id qty with
    | Some (Buy { cost; _ }) -> Some cost
    | _ ->
      (match env.prices item_id with
       | Some p -> Some (p * qty)
       | None -> None)
  in
  let craft_cost =
    match env.recipe item_id with
    | None -> None
    | Some r ->
      let rec loop acc = function
        | [] -> Some acc
        | { item_id = rid; count }::rs ->
          (match calculate_internal env rid (count * qty) visiting with
           | None -> None
           | Some (Buy { cost; _ })
           | Some (Craft { cost; _ }) -> loop (acc + cost) rs)
      in
      loop 0 r.reagents
  in
  match buy_cost, craft_cost with
  | Some b, Some c when b <= c ->
      Some (Buy { cost = b; craft_cost = Some c })
  | Some b, Some c ->
      Some (Craft { cost = c; buy_price = Some b })
  | Some b, None ->
      Some (Buy { cost = b; craft_cost = None })
  | None, Some c ->
      Some (Craft { cost = c; buy_price = None })
  | None, None -> None
```

- **Séparation IO** : l’API WoW serait représentée comme type classe ou paramètre de `env`.  
- **Monades** : Amulet supporte type classes ; tu peux implémenter `Monad` et modéliser IO comme dans Haskell, avant de compiler vers Lua. [amulet](https://amulet.works)

#### Tooling / limitations

- CLI `amc` pour compiler des fichiers vers Lua ou utiliser un REPL ; la doc parle de compilation vers Lua mais montre surtout l’usage en REPL. [amulet](https://amulet.works/tutorials/01-intro.html)
- Pas de tooling spécifique WoW ni de communauté autour de ce cas d’usage.  
- Projet visiblement en **ralentissement** (peu d’activité depuis 2020), ce qui rend risqué de miser tout ton addon dessus. [github](https://github.com/amuletml/amulet)

En résumé, Amulet est intéressant comme *noyau expérimental* pour quelques modules très algorithmiques (DP, BOM) si tu acceptes d’avoir un compilateur un peu « niche ».

***

### PureScript-Lua, Nox et autres langages FP → Lua

Le dépôt `lua-languages` recense plusieurs langages fonctionnels compilant vers Lua, dont Hypatia, LunarML, Oczor, Lua-ML, Idris2-Lua, PureScript-Lua et Nox. [github](https://github.com/hengestone/lua-languages)

Parmi eux :

- **PureScript-Lua**  
  - Backend Lua pour PureScript (langage Haskell‑like pur et typé). [github](https://github.com/Unisay/purescript-lua)
  - Génère des modules Lua ou des applications complètes. [github](https://github.com/Unisay/purescript-lua)
  - Très bonne adéquation conceptuelle (monades, ADT, type classes), mais backend encore confidentiel, tooling principalement côté JS.  
- **Nox**  
  - Langage fonctionnel statiquement typé qui compile vers Lua, avec interpréteur et REPL. [github](https://github.com/coetaur0/nox)
  - L’auteur souligne que c’est un projet d’apprentissage sur l’inférence de types ; pas conçu comme stack de production pour un gros addon WoW. [reddit](https://www.reddit.com/r/ProgrammingLanguages/comments/12dod7u/the_nox_programming_language/)
- **LunarML**  
  - Compilateur Standard ML vers Lua/JS. [github](https://github.com/minoki/LunarML)
  - Typage fort, ADT, pattern matching ; mais encore très expérimental.

Ces projets sont excitants sur le plan FP, mais :

- peu de documentation sur la **compatibilité exacte Lua 5.1**,  
- aucune trace d’usage dans des environnements embarqués comme WoW,  
- communautés réduites, activité variable. [github](https://github.com/coetaur0/nox)

Je les vois plutôt comme **backends pour un noyau expérimental** (quelques modules math/DP) qu’une base complète d’addon.

***

### Haxe (cible Lua)

#### Vue d’ensemble

- **Nom / URL**  
  - Haxe – toolkit multi‑plateforme avec langage typé, compile vers Lua (entre autres). [haxe](https://haxe.org/manual/target-lua.html)
- **Cible Lua**  
  - La doc officielle indique le support de Lua 5.1, 5.2, 5.3 et LuaJIT 2.0/2.1. [haxe](https://haxe.org/manual/target-lua-getting-started.html)
- **Paradigme / types**  
  - Langage fortement typé, OO + FP, avec enums algébriques et pattern matching via `switch`. [haxe](https://haxe.org/manual/target-lua.html)

#### Avantages potentiels

- Typage riche, ADT, pattern matching ; bon pour exprimer ton calculateur et tes DSL (CmdLang, DB).  
- Cible Lua 5.1 explicitement supportée ; tu peux donc générer du Lua compatible WoW. [haxe](https://haxe.org/manual/target-lua-getting-started.html)

#### Limites pour WoW

- Haxe traîne son **standard library** et certains helpers runtime sur la cible Lua ; il faudrait vérifier la taille et la compatibilité exactes avec WoW (absence de `require`, etc.), ce qui est moins documenté que pour TSTL. [haxe](https://haxe.org/manual/target-lua-getting-started.html)
- Aucune adoption WoW connue dans la communauté ou les forums. [stackoverflow](https://stackoverflow.com/questions/5369745/how-do-i-make-a-world-of-warcraft-addon)

***

### Typed Lua, Pallene, NattLua, Selene

La famille des « typed Lua » est utile en complément, même si ce ne sont pas tous des langages de haut niveau compilant vers Lua.

- **Teal** – déjà détaillé ; c’est aujourd’hui l’option la plus active dans cette catégorie. [news.ycombinator](https://news.ycombinator.com/item?id=44000759)
- **Typed Lua**  
  - Superset typé de Lua compilant vers Lua, mais le projet n’est plus activement maintenu ; la page recommande Teal comme alternative. [github](https://github.com/andremm/typedlua)
- **Pallene**  
  - Langage « sœur » statiquement typé de Lua, compilant vers C qui manipule directement l’API Lua pour gagner en performance comparable à LuaJIT ; conçu comme compagnon système de Lua, pas comme transpileur vers Lua. [lua](https://www.lua.org/wshop22/Ierusalimschy.pdf)
  - Inapplicable directement pour un addon WoW, qui ne peut pas embarquer du C supplémentaire.  
- **NattLua**  
  - Variante de LuaJIT avec types optionnels, visant à analyser toutes les branches d’exécution possibles. [github](https://github.com/capsadmin/nattlua)
  - Intéressant comme **analyseur statique offline**, mais pas utilisable dans le runtime WoW (qui n’embarque ni LuaJIT ni ce fork).  
- **Selene**  
  - Linter moderne en Rust pour Lua, axé sur les diagnostics rapides ; ne change pas le langage mais améliore la qualité de code. [github](https://github.com/Kampfkarren/selene)

***

### Urn et autres Lisp → Lua

Le méta‑repo `lua-languages` liste plusieurs Lisp qui compilent vers Lua, dont Urn, Lux, l2l, etc. [github](https://github.com/hengestone/lua-languages)

- **Urn**  
  - Lisp minimaliste compilant vers Lua, avec macros et exécution de code à la compilation ; support de Lua 5.1–5.3 et LuaJIT. [photonsphere](https://photonsphere.org/post/2018-09-22-lua-lisp/)
  - Marqué comme non maintenu (`*`) dans `lua-languages`. [github](https://github.com/hengestone/lua-languages)
- **Lux**  
  - Lisp statiquement typé, fonctionnel, avec module system ML‑like. [github](https://github.com/hengestone/lua-languages)

Ces options sont intéressantes pour des DSLs et métaprogrammation, mais leur statut expérimental et l’absence de communauté WoW les rendent peu attractives pour CraftGold par rapport à Fennel.

***

### Macro systems et approches méta

- **Metalua**  
  - Extension de Lua 5.1 avec macros, permettant de manipuler l’AST à la compilation et d’ajouter de nouveaux idiomes au langage ; décrit comme « backward compatible with Lua 5.1 ». [lua-users](http://lua-users.org/wiki/MetaLua)
  - Tu pourrais y implémenter un DSL avec pattern matching, ADT simulées et monades *au moment de la compilation*, générant du Lua pur 5.1.  
- **Terra**  
  - Langage système bas niveau interopérant étroitement avec Lua, compilant vers du code natif via LLVM. [github](https://github.com/terralang/terra)
  - Génial pour des parties C‑like haute perf, mais inutilisable dans WoW (pas de code natif additionnel).  
- **Nelua**  
  - Langage système inspiré de Lua, compilant d’abord vers C, puis vers binaire natif. [nelua](https://nelua.io)
  - Même limitation que Terra pour WoW, même si sa métaprogrammation pourrait servir pour générer du Lua offline.  

Ces approches sont plutôt des **outils de génération** si tu veux écrire ton propre petit compilateur (par exemple un DSL en Lua+Metalua qui génère du Lua 5.1 pour CraftGold).

***

### Haskell / OCaml DSL générant du Lua

Tu as aussi l’option « DIY sérieux » : écrire un DSL FP dans Haskell ou OCaml qui **génère du Lua 5.1**.

Les briques techniques existent :

- **OCaml-lua** fournit des bindings complets à l’API Lua 5.1 pour OCaml. [github](https://github.com/pdonadeo/ocaml-lua)
- **HsLua** fournit bindings, wrappers et utilitaires pour interconnecter Haskell et Lua (dans le sens Haskell → embed Lua). [github](https://github.com/hslua/hslua)

Même si ces bibliothèques servent plutôt à *intégrer Lua* dans Haskell/OCaml, rien n’empêche de s’en servir comme base pour :

- définir un AST Haskell/OCaml de ton DSL (Recettes, Graphes, DP),  
- écrire un pretty‑printer Lua 5.1,  
- compiler les modules « core » de CraftGold (calculateur, BOM) vers Lua.

C’est la voie la plus flexible pour obtenir exactement l’ADT/monades/pattern matching que tu souhaites, mais c’est aussi la plus coûteuse en temps (tu écris ton propre mini‑compilateur).

***

## Tableau comparatif (notes 1–5)

> Les notes sont qualitatives ; les justifications dans le texte ci‑dessus sont sourcées.

| Langage / outil      | Maturité | Paradigme FP | Séparation IO | Typage | Mocking | Qualité Lua généré | Testing | Optimisation | Interop Lua | DX / Tooling | Adoption WoW |
|----------------------|----------|--------------|---------------|--------|---------|---------------------|---------|--------------|-------------|--------------|-------------|
| TypeScriptToLua      | 5        | 4            | 4             | 5      | 5       | 4                   | 5       | 3            | 4           | 5            | 4           |
| Teal                 | 4        | 3            | 3             | 4      | 4       | 5                   | 4       | 3            | 5           | 4            | 2           |
| Fennel               | 4        | 5            | 4             | 1      | 4       | 4                   | 4       | 3            | 5           | 4            | 1           |
| Amulet               | 3        | 5            | 4             | 5      | 4       | 3                   | 3       | 3            | 3           | 3            | 1           |
| PureScript-Lua       | 3        | 5            | 5             | 5      | 4       | 3                   | 3       | 3            | 3           | 3            | 1           |
| Nox                  | 2        | 4            | 4             | 5      | 3       | 3                   | 2       | 2            | 2           | 2            | 1           |
| Haxe (Lua target)    | 4        | 4            | 4             | 5      | 4       | 3                   | 4       | 3            | 3           | 4            | 1           |
| Urn / Lisp exp.      | 2        | 4            | 3             | 1      | 3       | 3                   | 2       | 2            | 3           | 2            | 1           |
| TypedLua (legacy)    | 2        | 2            | 2             | 3      | 3       | 5                   | 3       | 3            | 5           | 2            | 1           |
| Metalua + Lua        | 3        | 4            | 3             | 1      | 3       | 4                   | 3       | 3            | 5           | 3            | 1           |

(5 = excellent, 1 = faible)

***

## Recommandation finale pour CraftGold

### 1. Choix du langage principal

Pour un addon WoW Classic sérieux, maintenu sur la durée, avec beaucoup de logique métier et des besoins avancés, je recommande :

**TypeScriptToLua comme langage principal de développement**, pour les raisons suivantes :

- Typage très expressif (generics, unions, discriminated unions) permettant de modéliser proprement tes ADT (recipes, méthodes buy/craft, états de scanner). [github](https://github.com/TypeScriptToLua/TypescriptToLua)
- Tooling de haut niveau (VSCode, LSP, refactoring, navigation) qui change la vie sur un projet de 16 modules comme CraftGold. [github](https://github.com/TypeScriptToLua/TypescriptToLua)
- Expérience réelle documentée pour des addons WoW, avec gestion des particularités de l’environnement (absence de `require`, Lua 5.1, API Blizzard typée). [wowinterface](https://wowinterface.com/forums/showthread.php?t=56829)
- Possibilité de structurer **clairement la frontière IO** : interfaces `Env`/`WoWApi` d’un côté, fonctions pures de calcul de l’autre, avec tests unitaires sur Node sans lancer WoW.

Si tu es prêt à accepter un niveau de FP moins « académique » qu’en Haskell, TypeScript couvre cependant 80 % de tes besoins (monades via generics, ADT, pattern matching via `switch` + type guards).

### 2. Architecture proposée

Une architecture cible réaliste pourrait être :

1. **Core métier pur en TypeScript**  
   - Modules `Calculator`, `Quote`, `BOM`, `Core` (requêtes DB, DP, expansion) écrits comme fonctions pures paramétrées par `Env`.  
   - Types riches (ADTs pour `Method`, `Command`, `RecipeSource`, etc.).  

2. **Interop WoW via seam typée**  
   - Un module `WoWEnv.ts` qui fournit une implémentation de `Env` en se basant sur `_G` et l’API Blizzard typée (`wow.d.ts` généré). [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)
   - Pas d’accès direct à `_G` ailleurs que dans ce module.

3. **CmdLang et DB**  
   - `CmdLang` en TS avec ADT pour les commandes, parsing typé, pattern matching via `switch` sur l’ADT.  
   - DB recettes déclarée dans un module de données TS : tu peux utiliser des **smart constructors** pour valider à la compilation (e.g. `mkRecipe(output: ItemId, reagents: NonEmptyArray<...>)`).  

4. **Scanner asynchrone**  
   - Modéliser ton scanner HdV en `async`/`await` + Promises côté TS, transpiler via TSTL et laisser le runtime `lualib` gérer la traduction en callbacks Lua. [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)
   - Comme montré dans le retour d’expérience WoW+TSTL, cela permet d’écrire du code asynchrone quasi synchrone, ce qui correspond très bien à ta machine à états actuelle. [reddit](https://www.reddit.com/r/wowaddons/comments/16df1iz/developping_addons_in_typescript/)

5. **Tests**  
   - Tests unitaires en TypeScript (Jest) sur `Calculator`, `Quote`, `BOM`, `CmdLang` en utilisant des mocks de `Env`.  
   - Tests d’intégration supplémentaires possibles sur le Lua généré avec Busted si tu veux.

### 3. Rôle des autres langages

- **Teal**  
  - Excellente option si tu veux une migration plus douce (tu peux annoter progressivement ton Lua existant) et rester très proche de Lua.  
  - Je le verrais plutôt comme **alternative** à TSTL si tu ne veux pas sortir de l’écosystème Lua, ou comme outil de typage sur des modules auxiliaires (Money, ItemInfo, DB).  

- **Fennel**  
  - Très intéressant pour les parties où tu veux construire des DSLs ou abstractions complexes :  
    - `CmdLang` pourrait être réécrit en Fennel avec macros pour le parsing et l’aide interactive.  
    - Le scanner HdV pourrait bénéficier d’un mini DSL en Fennel pour décrire les machines à états.  
  - Mais l’absence de typage statique le rend moins adapté comme langage principal pour tout CraftGold.

- **Amulet / PureScript-Lua / Nox**  
  - À garder en tête si tu veux expérimenter un **noyau ultra‑fonctionnel** (par exemple, une lib `CraftGold.Core.Pure` publiant des fonctions de calcul compilées vers Lua).  
  - Vu la maturité moindre et l’absence de tooling WoW, je les déconseille comme base principale.

- **Metalua + Lua**  
  - Si tu préfères rester 100 % dans Lua 5.1 mais avoir des macros, Metalua peut t’aider à ajouter pattern matching et ADT « syntactiques » à ton code, tout en générant du Lua pur. [lua-users](http://lua-users.org/wiki/MetaLua)
  - C’est une bonne voie pour un **DSL sur mesure** autour de ton calculateur, mais ça ne te donne pas de typage statique.

### 4. Concrètement : plan de migration

1. **Isoler l’API WoW** dans ton code actuel (ce que tu as déjà fait avec `WoW.lua`), et définir une interface équivalente en TypeScript (`Env` + `WoWApi`).  
2. **Porter d’abord les modules les plus « purs » vers TypeScript** : `Money`, `Quote`, `Calculator`, `BOM`, `Core`.  
3. **Introduire les tests TypeScript** pour ces modules, basés sur des mocks d’`Env`.  
4. **Porter ensuite `CmdLang`**, en profitant des ADT pour avoir un langage de commandes typé.  
5. **Terminer par le scanner HdV**, en transformant la machine à états en `async`/`await`.  

À ce stade, ton Lua ne sera plus qu’un artefact de build, et tu auras un environnement très FP‑friendly (monades génériques, ADT, pattern matching via `switch`) tout en restant compatible Lua 5.1 et avec un workflow déjà testé par d’autres devs d’addons WoW. [wowinterface](https://wowinterface.com/forums/showthread.php?t=56829)

***

## Annexes (liens principaux)

- Liste de langages compilant vers Lua (dont Hypatia, LunarML, Amulet, PureScript-Lua, Nox, Lisp, typed Lua) : https://github.com/hengestone/lua-languages. [github](https://github.com/hengestone/lua-languages)
- Fennel – doc & sources : https://fennel-lang.org, https://sr.ht/~technomancy/fennel. [code.likeagirl](https://code.likeagirl.io/the-hidden-gem-of-lua-programming-c02103402ed6)
- Teal – doc & compiler : https://teal-language.org, https://github.com/teal-language/tl. [github](https://github.com/terralang/terra)
- TypeScriptToLua – doc & sources : https://github.com/TypeScriptToLua/TypeScriptToLua. [github](https://github.com/TypeScriptToLua/TypescriptToLua)
- Article « Developping Addons in Typescript » (WoW + TSTL) : Reddit /r/wowaddons. [wowinterface](https://wowinterface.com/forums/showthread.php?t=56829)
- Metalua – macros Lua 5.1 : http://lua-users.org/wiki/MetaLua. [lua-users](http://lua-users.org/wiki/MetaLua)
- Amulet ML : https://amulet.works, https://github.com/amuletml/amulet. [squiddev](https://squiddev.cc/2019/08/30/amulet-backend.html)
- PureScript-Lua : https://github.com/Unisay/purescript-lua. [github](https://github.com/Unisay/purescript-lua)
- Nox : https://github.com/coetaur0/nox. [reddit](https://www.reddit.com/r/ProgrammingLanguages/comments/12dod7u/the_nox_programming_language/)
- OCaml-lua : https://github.com/pdonadeo/ocaml-lua. [github](https://github.com/pdonadeo/ocaml-lua)
- HsLua : https://github.com/hslua/hslua. [github](https://github.com/hslua/hslua)