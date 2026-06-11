# Tour d'Horizon : Langages compilant vers Lua pour WoW Add-on Development

## Résumé exécutif

Pour CraftGold (add-on WoW Classic Era, interface 11508, Lua 5.1), après recherche exhaustive, **aucun langage existant ne satisfait simultanément TOUS les critères** (FP de haut niveau + IO monad/Free + typage à inférence + Lua 5.1 lisible + adoption WoW prouvée). Trois approches dominent selon les priorités :

1. **TypeScriptToLua (TSTL) — recommandation principale et pragmatique.** C'est la seule chaîne avec une adoption WoW prouvée (l'add-on Ovale Spell Priority de Sidoine, dépôt 100% TypeScript transpilé en Lua, avec mocking de l'API WoW via `@wowts/wow-mock` et tests Jest). Cible Lua 5.1 officiellement supportée, unions discriminées comme ADT, typage structurel avec inférence, outillage best-in-class (VS Code, ESLint). Le dépôt `TypeScriptToLua/TypeScriptToLua` compte **2 509 stars** sur GitHub et le paquet npm `typescript-to-lua` est en v1.36.0 (publié il y a ~20 jours), avec **51 projets dépendants** dans le registre npm. La FP "pure" (monades HKT) reste idiomatiquement limitée, mais fp-ts est utilisable.

2. **Fennel — recommandation pour l'élégance FP et le mocking.** Lisp sur Lua, créé par Calvin Rose en 2016 (copyright « © 2016-2025 Calvin Rose and contributors », licence MIT), mature et maintenu (dernière version v1.6.1 ; dépôt `bakpakin/Fennel` à ~2,7k stars). Sortie Lua 5.1 lisible quasi 1:1 avec « zéro overhead » (« Compiled code should be just as efficient as hand-written Lua »), pattern matching de premier ordre (`case`/`match` avec gardes et unification), macros hygiéniques pour construire des abstractions monadiques. Pas de typage statique, pas d'ADT natif (mais tables taguées + pattern matching couvrent le besoin). REPL et hot-reload excellents.

3. **Teal — recommandation pour le typage minimal sans friction.** Dialecte typé de Lua (par Hisham Muhammad, auteur de LuaRocks/htop), cible Lua 5.1 native (« Teal works with Lua 5.1-5.4, including LuaJIT »), sortie Lua très propre, types records/enums/unions avec narrowing. Dernière release v0.24.8 (13 octobre 2025), dépôt à ~2,6k stars / 137 forks. Système de types moins expressif (pas de vraies ADT ni HKT) mais zéro impedance avec l'écosystème WoW et courbe d'apprentissage minimale.

**Verdict CraftGold :** la logique pure de CraftGold (DP knapsack, arbre de recettes récursif avec détection de cycles, min(buy,craft)) est *exactement* le type de problème où la FP brille. Si l'objectif prioritaire est la **séparation IO + testabilité + adoption éprouvée**, choisir **TSTL**. Si l'objectif est l'**élégance FP maximale et le pattern matching naturel** avec un coût d'adoption faible, choisir **Fennel**. Une approche DIY (DSL Haskell → Lua) est décrite en fin de rapport mais déconseillée sauf appétence recherche.

---

## Évaluation détaillée

### 1. TypeScriptToLua (TSTL)

**Vue d'ensemble.** Transpileur TypeScript → Lua, open source (MIT), hébergé sur GitHub (`TypeScriptToLua/TypeScriptToLua`, **2 509 stars**, très actif). Paradigme multi (OO + FP via TS), typage statique structurel avec inférence riche (le système de types complet de TypeScript). Cible Lua 5.1, 5.2, 5.3, 5.4, JIT et `universal` — la valeur `luaTarget: "5.1"` est un target de première classe. Communauté large : npm `typescript-to-lua` v1.36.0 avec **51 projets dépendants**, Discord actif, utilisé pour Dota 2, Defold, et WoW.

**Adoption WoW (point fort décisif).** L'add-on **Ovale Spell Priority** (`Sidoine/Ovale`, 100% TypeScript, MIT, ~47 stars / 46 forks) est l'exemple canonique : code source en `src/` (TS), sortie Lua dans `dist/` (configuration via `tsconfig.lua.json`). Note importante : Ovale utilise en réalité un compilateur dérivé maison, `@wowts/tstolua` ("Simple Typescript to Lua 5.1 compiler, used for World of Warcraft addons"), et tout un écosystème `@wowts/*` (libs Ace3, lua std, etc.). Le mocking WoW y est documenté (issue #446 : « @wowts/wow-mock is not updated for 8.0. It will still compile it without problems »). Le mainline TSTL et tstolua coexistent ; pour un nouveau projet, le mainline TSTL est recommandé (plus mature, switch supporté en 5.1, plugins). D'autres POC existent : `tstirrat/tsCoolDown` (React + TSTL), `@brusalk/react-wow-addon`.

**Exemples CraftGold.**

*(a) Calculator avec ADT + pattern matching + effets injectés.* Les unions discriminées TS font office d'ADT :
```typescript
type Method =
  | { kind: "buy"; cost: number }
  | { kind: "craft"; cost: number; reagents: ReagentCost[] };

interface Effects {
  quote(itemID: number, qty: number): number | undefined;  // Quote.quote
  priceOf(itemID: number): number | undefined;             // Prices.get
  recipeFor(itemID: number): Recipe | undefined;           // Core.getByOutput
}

function calculate(
  fx: Effects, itemID: number, qty: number, visiting: LuaSet<number>
): Method | undefined {
  if (visiting.has(itemID)) return undefined;       // détection de cycle
  visiting.add(itemID);
  const buy = fx.quote(itemID, qty) ?? fx.priceOf(itemID);
  const recipe = fx.recipeFor(itemID);
  let craft: number | undefined;
  if (recipe) {
    craft = 0;
    for (const r of recipe.reagents) {
      const sub = calculate(fx, r.itemID, r.qty * qty, visiting);
      if (!sub) { craft = undefined; break; }
      craft += sub.cost;
    }
  }
  visiting.delete(itemID);
  if (buy !== undefined && (craft === undefined || buy <= craft))
    return { kind: "buy", cost: buy };
  if (craft !== undefined)
    return { kind: "craft", cost: craft, reagents: [] };
  return undefined;
}
```
La séparation pure/effets se fait par l'interface `Effects` injectée (tagless-final "à la main"). Pas de vrai IO monad, mais le pattern d'injection de dépendances typé est idiomatique et testable.

*(b) Seam API WoW + mocking.* On déclare l'API WoW comme interface TypeScript (déclarations ambiantes type `wow-declarations` / `@wowts/wow-mock`), puis on injecte une implémentation mock dans les tests :
```typescript
interface WowApi {
  GetItemInfo(item: number | string): LuaMultiReturn<[string, string, ...]>;
  QueryAuctionItems(name: string, ...): void;
}
```
`@wowts/wow-mock` ("This package provides mocks for World of Warcraft scripts written in Typescript") fournit `fakePlayer`, `fakeTarget`, `FakeUnit`, etc., permettant d'exécuter le code TS sous Node/Jest.

*(c) Test unitaire (Jest, équivalent busted).*
```typescript
test("chooses buy when cheaper", () => {
  const fx = makeFakeEffects();
  fx.setPrice(2840, 1000);
  fx.addListing(4359, 1, 800);
  const result = calculate(fx, 4359, 1, new LuaSet());
  expect(result?.cost).toBe(800);
  expect(result?.kind).toBe("buy");
});
```
Le mocking est naturel : on substitue `fx`, exactement le pattern de votre `WoW.init(env)` mais typé.

*(d) Lua généré.* TSTL produit un Lua 5.1 lisible. Les `else if` deviennent `elseif`, les unions discriminées compilent en accès de champ `.kind` + chaînes `if/elseif`. Le `switch` est désormais supporté en 5.1 (historiquement retiré pour ≤5.1 puis réintroduit « Added support for the switch statement in all versions »). Chaque module est émis comme un fichier `.lua` retournant une table.

**Tooling.** CLI `tstl` (identique à `tsc`), `--watch`, extension VS Code officielle, ESLint/Prettier, plugins de transformation AST (`tstl.luaPlugins`), source maps. Intégration `.toc` : soit multi-fichiers `.lua` listés dans le `.toc` (approche Ovale), soit bundle unique via `luaBundle` + `luaBundleEntry`. TSWoW génère automatiquement le `.toc`.

**Optimisations.** DCE basique, inlining limité, utilise les infos de type pour émettre du Lua plus optimisé. `LuaTable`/`LuaMap`/`LuaSet`/`$range`/`$multi` (language extensions) évitent les surcoûts JS. Pas d'IR fonctionnelle dédiée pour fusions monadiques.

**Limites et risques.** (1) **Limite des 200 variables locales Lua** : caveat officiel — chaque `import` crée deux locals ; un gros projet peut planter au runtime sans erreur de compilation. (2) Lua 5.1 sans `goto` : `try/catch` interdit dans async/generator en 5.1 (flag `lua51AllowTryCatchInAsyncAwait`). (3) FP pure idiomatiquement absente (pas de HKT, monades verbeuses). (4) Le runtime `lualib_bundle` doit être inclus. (5) tstolua (variante Ovale) ne supporte qu'un sous-ensemble de TS.

**Sources.** typescripttolua.github.io (docs, configuration, caveats, language-extensions) ; GitHub TypeScriptToLua, Sidoine/Ovale, wowts/tstolua, wowts/wow-mock ; npm typescript-to-lua, @wowts/wow-mock ; wartoshika/wow-declarations ; tstirrat/tsCoolDown.

---

### 2. Fennel

**Vue d'ensemble.** Lisp compilant vers Lua, créé par Calvin Rose en 2016 (initialement "fnl"), MIT, dépôt principal sur Sourcehut (`~technomancy/fennel`) et miroir GitHub `bakpakin/Fennel` (~2,7k stars), très actif (dernière version v1.6.1). Paradigme fonctionnel/Lisp, **dynamiquement typé** (aucun typage statique). Sortie Lua sans dépendance runtime ; compatible Lua 5.1–5.4 et LuaJIT. Communauté solide (LÖVE, TIC-80, Neovim, game jams lisp annuels). « Full Lua compatibility - You can use any function or library from Lua » et « Zero overhead - Compiled code should be just as efficient as hand-written Lua ».

**Exemples CraftGold.**

*(a) Calculator avec pattern matching + détection de cycle.* Fennel n'a pas d'ADT statique, mais les tables taguées + `case`/`match` couvrent le besoin avec élégance :
```fennel
(fn calculate [fx item-id qty visiting]
  (if (. visiting item-id)
      nil                              ; cycle détecté
      (do
        (tset visiting item-id true)
        (let [buy (or (fx.quote item-id qty) (fx.price-of item-id))
              recipe (fx.recipe-for item-id)
              craft (when recipe
                      (accumulate [sum 0 _ r (ipairs recipe.reagents) &until (= sum nil)]
                        (case (calculate fx r.item-id (* r.qty qty) visiting)
                          {:cost c} (+ sum c)
                          _ nil)))]
          (tset visiting item-id nil)
          (case (values buy craft)
            (where (b c) (and b c (<= b c))) {:cost b :method :buy}
            (where (b nil) b)                {:cost b :method :buy}
            (where (nil c) c)                {:cost c :method :craft}
            _ nil)))))
```
Le pattern matching `case` avec gardes `where` et unification est un atout majeur — directement adapté à votre `min(buy,craft)`.

*(b) Seam API WoW + mocking.* Fennel appelle le Lua nativement. On passe l'environnement WoW (ou un mock) comme une table d'effets :
```fennel
(fn make-effects [wow]
  {:quote (fn [id qty] (wow.QueryAuctionQuote id qty))
   :price-of (fn [id] (. prices id))
   :recipe-for (fn [id] (core.get-by-output id))})
```
Le mocking consiste à fournir une table `wow` factice — équivalent direct et plus concis de `WoW.init(env)`.

*(c) Test unitaire.* Fennel s'intègre avec busted (en Lua) ou Faith (test runner Fennel). Le test "choisit buy si moins cher" se mappe directement :
```fennel
(it "chooses buy when cheaper"
  (fn []
    (prices.set 2840 1000)
    (listings.add 4359 1 800)
    (let [r (calculator.calculate 4359)]
      (assert (= r.cost 800))
      (assert (= r.method :buy)))))
```

*(d) Lua généré.* Quasi 1:1, lisible, déboggable in-game ; l'option `correlate` aligne les numéros de ligne Fennel/Lua. `match`/`case` compilent en chaînes `if/elseif` plates.

**Tooling.** CLI `fennel` (compilateur AOT + compilateur runtime via `package.searchers`), REPL en navigateur, hot-reload natif, support éditeur (Neovim first-class). Pas de LSP riche typé (langage dynamique). Intégration `.toc` : compiler les `.fnl` en `.lua` puis lister dans le `.toc`, ou embarquer `fennel.lua` (mais surcoût — préférer l'AOT).

**Optimisations.** « Zero overhead » : la sortie est aussi efficace que du Lua à la main. Macros à la compilation (DCE manuelle possible via macros). Pas d'IR ni d'inlining inter-procédural automatique ; les algorithmes purement fonctionnels restent limités par le GC de Lua.

**Limites et risques.** (1) Aucun typage statique → pas de garanties à la compilation, pas d'inférence d'ADT/GADT. (2) Pas d'ADT/HKT natifs ; les monades se construisent à la main via macros/tables. (3) Documentation Fennel moins abondante que Lua pour les contributeurs externes. (4) Adoption WoW quasi nulle (pas d'add-on connu publié), donc défrichage. (5) Syntaxe Lisp = courbe d'adoption pour une équipe.

**Sources.** fennel-lang.org (reference, documentation, see/compile) ; sr.ht/~technomancy/fennel ; github.com/bakpakin/Fennel ; compilerspotlight Substack ; andregarzia.com ; drake.dev (pattern matching).

---

### 3. Teal

**Vue d'ensemble.** Dialecte typé de Lua, créé par Hisham Muhammad (auteur de LuaRocks/htop), MIT, dépôt `teal-language/tl` (~2,6k stars / 137 forks, dernière release v0.24.8 du 13 octobre 2025), compilateur en un seul fichier `tl.lua` sans dépendances. Typage statique graduel (records, enums, unions, génériques, interfaces) avec inférence. Cible **Lua 5.1–5.4 + LuaJIT** (« Teal works with Lua 5.1-5.4, including LuaJIT ») ; `--gen-target 5.1` supporté, et les opérateurs/métamethodes 5.4 (// bitwise) sont émulés même sur 5.1. « Teal is to Lua what TypeScript is to JavaScript. »

**Exemples CraftGold.**

*(a) Calculator.* Teal modélise `Method` via record + enum (pas de vraie ADT à variantes mais union discriminable) :
```lua
local enum MethodKind  "buy"  "craft" end
local record Method
  kind: MethodKind
  cost: number
end
local type Effects = record
  quote: function(number, number): number
  price_of: function(number): number
  recipe_for: function(number): Recipe
end

local function calculate(fx: Effects, id: number, qty: number,
                         visiting: {number:boolean}): Method
  if visiting[id] then return nil end
  visiting[id] = true
  local buy = fx.quote(id, qty) or fx.price_of(id)
  -- ... récursion sur reagents, craft = somme ...
  visiting[id] = nil
  if buy and (not craft or buy <= craft) then
    return { kind = "buy", cost = buy }
  elseif craft then
    return { kind = "craft", cost = craft }
  end
  return nil
end
```

*(b/c) Seam + mocking + test.* On type l'API WoW via un record `Effects` ou un fichier de déclaration `.d.tl`. Le mocking = fournir un record concret. Tests via busted (Lua) — votre `helpers.lua` reste quasi inchangé, on compile juste les `.tl` en `.lua` au préalable.

*(d) Lua généré.* Très propre — Teal supprime simplement les annotations de type, ce qui donne du Lua quasi identique à l'écrit manuel. Idéal pour le débogage in-game.

**Tooling.** `tl check`/`tl gen`, build system **Cyan**, loader `tl.loader()` pour charger des `.tl` à la volée, extension VS Code, Teal Language Server (en cours), dépôt collaboratif `teal-types` pour les déclarations tierces.

**Optimisations.** Minimes — Teal est un type-checker + générateur, pas un optimiseur. Pas d'IR, pas de DCE, pas d'inlining. Le gain est la sûreté de types, pas la performance.

**Limites et risques.** (1) **Pas d'ADT/sum types véritables** : les unions existent mais avec limitations (l'opérateur `is` ne discrimine qu'une variable, pas une expression arbitraire ; pas de pattern matching). (2) Pas de monades/HKT/type classes. (3) Pas de mocking "magique" — c'est du Lua typé. (4) Adoption WoW nulle. (5) Système de types encore en évolution (édition 2024/2025).

**Sources.** teal-language.org (book, union_types, tutorial) ; GitHub teal-language/tl (CHANGELOG, releases) ; OpenMW & Dora SSR docs ; Hacker News.

---

### 4. Amulet

**Vue d'ensemble.** Langage fonctionnel ML/OCaml-like compilant vers Lua, écrit en Haskell. **PROJET ABANDONNÉ** : le README officiel indique « Amulet is no longer under development » et le dépôt GitHub `amuletml/amulet` est archivé. Système de types très expressif (polymorphisme de rang supérieur, records row-polymorphic, GADTs, type classes avec types associés, dépendances fonctionnelles, kind polymorphism). Pattern matching, ADT, élimination de récursion terminale. Sortie Lua agressivement optimisée (curry éliminé).

**Pertinence CraftGold.** Sur le papier, **le candidat techniquement le plus séduisant** : ADT + GADT + type classes + pattern matching = exactement ce que demande CraftGold. FFI via `external val "lua-expr"`. MAIS l'abandon est rédhibitoire pour un projet de production : aucun support, bugs non corrigés, pas d'adoption WoW, toolchain Haskell lourde à builder (~125 fichiers objets).

**Limites et risques.** Abandon confirmé (risque maximal). Pas de système de modules complet. Pas de LSP. Aucune communauté active.

**Sources.** github.com/amuletml/amulet (archivé) ; amulet.works/tutorials ; andregarzia.com.

---

### 5. Urn

**Vue d'ensemble.** Lisp pour Lua (SquidDev & demhydraz), influencé par Common Lisp et Clojure, plus "Lisp-family" que Fennel. **PROJET ARCHIVÉ** (dépôt `SquidDev/urn` archivé le 7 juillet 2024, 365 stars). Implémentation minimale, macros + exécution à la compilation, pattern matching (`case` avec patterns structurels), support Lua 5.1/5.2/5.3 + LuaJIT, scoping Lisp-1, produit du Lua optimisé autonome. Pas de typage statique.

**Pertinence CraftGold.** Pattern matching et macros intéressants, optimiseur intégré (inlining de lambdas, abaissement de nœuds). Mais l'archivage + l'absence d'adoption WoW + la communauté éteinte le disqualifient face à Fennel (vivant, même niche).

**Sources.** github.com/SquidDev/urn (archivé) ; urn-lang.com ; squiddev.github.io/urn.

---

### 6. Nelua

**Vue d'ensemble.** "Native Extensible Lua" (edubart, 2019), MIT, statiquement typé, méta-programmable. **Compile vers C puis code natif — PAS vers Lua dans le cas d'usage typique.** En alpha. Inspiré de Lua mais c'est un langage système (comme un "meilleur C").

**Pertinence CraftGold : NULLE.** Nelua ne peut pas être `require()` par Lua et ne s'exécute pas dans la VM Lua de WoW : « Nelua transpiles to C and then to native, it cannot be required by Lua ». Inadapté à un add-on WoW. À écarter.

**Sources.** nelua.io (faq, overview) ; github.com/edubart/nelua-lang (discussion #266).

---

### 7. LunarML

**Vue d'ensemble.** Compilateur Standard ML → Lua/JavaScript (minoki/Mizuki), actif (v0.3+, 2023–), implémente la majeure partie de SML '97 (signatures, foncteurs, ML Basis/MLB). ADT, pattern matching, foncteurs, type system ML complet avec inférence. Backend Lua : **5.3/5.4/LuaJIT** (continuations délimitées sur certains backends).

**Pertinence CraftGold.** SML = ADT + pattern matching + foncteurs + inférence, idéal pour la logique pure. MAIS le backend Lua cible **5.3/5.4/LuaJIT**, **pas 5.1 PUC** explicitement — risque majeur de contrainte dure violée (WoW = 5.1). Le code SML compilé peut être lourd et peu lisible pour le débogage in-game. Aucune adoption WoW. À considérer seulement si la compatibilité 5.1 peut être validée empiriquement (non confirmée par les sources).

**Sources.** github.com/minoki/LunarML ; minoki.github.io (blog release) ; lunarml.readthedocs.io.

---

### 8. PureScript → Lua (purescript-lua / pslua)

**Vue d'ensemble.** Backend Lua pour PureScript (Unisay/purescript-lua, écrit en Haskell, **alpha**, ~56 stars). PureScript = Haskell-like pur, typage fort, row polymorphism, type classes, HKT, monades (IO/Effect, Free). pslua prend la CoreFn de PureScript et émet du Lua avec **DCE, inlining, FFI Lua, bundling module/application**, IR avec indices de De Bruijn. Plusieurs backends Lua historiques existent (osa1/psc-lua, lua-purescript) mais sont obsolètes.

**Pertinence CraftGold (le rêve FP).** PureScript est **le seul candidat offrant nativement IO monad, Free monad, tagless final, type classes et HKT** — exactement la liste de souhaits. pslua fait DCE + inlining (optimisations demandées). MAIS : (1) alpha, mono-mainteneur, risque d'abandon élevé ; (2) compatibilité Lua 5.1 non garantie explicitement (à valider) ; (3) Lua généré peu lisible (style CPS/monadique) → débogage in-game difficile ; (4) toolchain Nix/Cabal/Spago lourde ; (5) aucune adoption WoW. C'est l'option "puriste" à haut risque.

**Sources.** github.com/Unisay/purescript-lua (CLAUDE.md, README) ; purescript/documentation (Alternate-backends) ; discourse.purescript.org.

---

### 9. Haxe (cible Lua)

**Vue d'ensemble.** Langage multi-cible mûr et stable, fortement typé, FP + OO. **enums = vraies ADT** (avec GADTs possibles), pattern matching riche (`switch` avec enum/structure/array matching, gardes, vérification d'exhaustivité), exhaustiveness checks. Cible Lua 5.1–5.4 + LuaJIT.

**Pertinence CraftGold.** ADT + pattern matching exhaustif + typage statique = très bon fit fonctionnel. MAIS le **Lua généré est volumineux et plus lent** : la doc tierce (gmodhaxe, reflaxe.Lua) reconnaît « The compiled code has a larger file size, and is slower » et liste des surcoûts (opérateurs unaires/OpAssignOp via fonctions, null-checks créant des variables). De plus, le runtime Haxe requiert des libs externes (lrexlib-pcre, lfs via LuaRocks) pour regex/IO — problématique dans WoW (pas d'installation de packages). Avec `-dce full` on réduit le bloat. Adoption WoW nulle. Verdict : bon FP, mais qualité/poids du Lua généré et runtime externe sont des freins sérieux pour l'environnement contraint de WoW.

**Sources.** haxe.org/manual (target-lua, pattern matching, enums) ; code.haxe.org (enum-gadt) ; lib.haxe.org/p/reflaxe.Lua, gmodhaxe ; haxe.org/blog/hello-lua.

---

### 10. Luau (Roblox)

**Vue d'ensemble.** Fork de Lua 5.1 par Roblox (open source MIT depuis nov. 2021), typage graduel + inférence, sandboxing, perf. Rétrocompatible Lua 5.1. Adopté hors Roblox (Alan Wake 2, Warframe, Farming Simulator 2025, SLua de Second Life).

**Pertinence CraftGold : très limitée.** Luau est une **VM/runtime** distincte, pas un transpileur vers du Lua 5.1 portable. On ne peut pas exécuter du bytecode Luau dans WoW. Le type-checker Luau pourrait servir d'outil d'analyse statique sur du Lua "presque standard", mais Luau retire une partie de la stdlib et modifie les globals/métamethodes (cf. discussion Teal : « Luau removing most of the Lua standard library... completely breaks ABI/bytecode »). Pas de chemin de compilation vers du Lua 5.1 exécutable par WoW. À écarter comme langage source ; intérêt seulement conceptuel (idées de typage).

**Sources.** Wikipedia (Luau) ; github.com/luau-lang ; create.roblox.com/docs/luau ; discussions Teal/Luvit.

---

### 11. Selene

**Vue d'ensemble.** Linter Lua (écrit en Rust), pas un langage. Supporte des standards (Roblox, Lua 5.1, etc.). Utilitaire complémentaire.

**Pertinence CraftGold.** Utile comme **outil qualité** sur le Lua généré ou écrit à la main (détection d'erreurs, globals non déclarés), quel que soit le langage source choisi. Pas une solution d'abstraction en soi. À adopter en complément.

---

### 12. Approches méta : Terra, macros Lua, DSL Haskell/Scala

**Terra** : langage bas niveau multi-stage avec Lua comme méta-langage ; compile vers code natif via LLVM, pas vers Lua 5.1 portable → inadapté à WoW.

**DSL embarqué en Haskell générant du Lua** : faisable via `hslua`, `language-lua` (AST Lua sur Hackage) pour pretty-print du Lua 5.1. C'est l'**approche DIY** : on écrit la logique CraftGold dans un DSL fonctionnel typé Haskell (avec vraies ADT, monades, GADTs), on interprète/compile vers un AST Lua 5.1 émis par `language-lua`. Avantages : contrôle total, IR custom, DCE/inlining sur mesure, typage Haskell complet, Lua 5.1 garanti et lisible. Inconvénients : effort de développement majeur (écrire le compilateur), maintenance, pas d'adoption.

**Sources.** Hackage (language-lua, hslua) ; jackkelly.name (Haskell+Lua+Fennel).

---

## Tableau comparatif

Notation 1 (faible) à 5 (excellent). "—" = non applicable / disqualifiant.

| Critère | TSTL | Fennel | Teal | Amulet | Urn | LunarML | PureScript→Lua | Haxe | Luau |
|---|---|---|---|---|---|---|---|---|---|
| **Maturité** | 5 | 4 | 4 | 1 (abandonné) | 1 (archivé) | 3 | 2 (alpha) | 5 | 4 |
| **Paradigme FP** (ADT, PM, monades, HOF) | 4 | 4 | 3 | 5 | 4 | 5 | 5 | 4 | 3 |
| **Séparation IO** (IO/Free/tagless) | 3 | 3 | 2 | 4 | 3 | 4 | 5 | 3 | 2 |
| **Typage** (statique, inférence, ADT/GADT/classes) | 4 | 1 | 3 | 5 | 1 | 5 | 5 | 4 | 3 |
| **Mocking API WoW** | 5 | 4 | 3 | 3 | 3 | 3 | 3 | 3 | 2 |
| **Qualité Lua généré** (lisibilité, perf, 5.1) | 4 | 5 | 5 | 4 | 4 | 2 (5.3+) | 2 | 2 | — |
| **Testing** | 5 | 4 | 4 | 2 | 2 | 3 | 3 | 3 | 3 |
| **Optimisation** (IR, DCE, inlining) | 3 | 2 | 1 | 4 | 3 | 4 | 4 | 4 | 4 |
| **Interop Lua** | 5 | 5 | 5 | 4 | 4 | 3 | 3 | 3 | 3 |
| **DX** (LSP, REPL, hot reload, erreurs) | 5 | 4 | 3 | 2 | 2 | 2 | 2 | 4 | 4 |
| **Adoption WoW** | 5 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| **Compatibilité Lua 5.1 (contrainte dure)** | 5 | 5 | 5 | 4 | 5 | 2 | 2 | 4 | — |
| **TOTAL /60** | **53** | **42** | **39** | **35** | **31** | **34** | **35** | **40** | **— (disq.)** |

*(Nelua, Terra exclus du tableau : ne s'exécutent pas dans la VM Lua de WoW.)*

---

## Recommandation finale (spécifique CraftGold)

**Choix recommandé : TypeScriptToLua (mainline), avec un style fonctionnel discipliné.**

Justification pour le cas précis de CraftGold :

1. **C'est la seule option avec adoption WoW prouvée** (Ovale), donc les pièges spécifiques (`.toc`, interop `_G`/frames/events, mocking de l'API) sont déjà résolus par la communauté (`@wowts/*`, `wow-declarations`, `wow-mock`). Vous réduisez radicalement le risque de défrichage.

2. **Vos besoins structurels sont parfaitement couverts** : les unions discriminées TS sont des ADT pragmatiques pour `Method = Buy | Craft` ; `Option`/`Maybe` se modélise via `T | undefined` + `??` ; le pattern matching se fait par `switch`/narrowing ; la séparation pure/effets se fait par **injection d'interface `Effects`** (style tagless-final manuel) — ce qui correspond *exactement* à votre seam `WoW.lua` actuel, mais typé statiquement. Votre détection de cycle (`visiting` set) se traduit directement avec `LuaSet`.

3. **Testabilité et mocking de premier ordre** : Jest + `wow-mock` reproduisent votre `helpers.lua`/busted avec un mocking plus naturel et typé. Vos 16 modules deviennent des modules TS testables hors-jeu.

4. **Lua 5.1 lisible et débogable in-game**, target officiellement supporté, `elseif` propres, multi-fichiers `.lua` listables dans le `.toc` (ou bundle).

**Garde-fous (benchmarks/seuils qui changeraient la décision) :**

- **Surveiller la limite des 200 locals** : si l'architecture à 16 modules génère trop d'`import` (202 locals = crash runtime), activer `luaBundle` ou regrouper les modules. *Seuil d'alerte : > ~80 imports cumulés dans un même scope.*
- **Si l'élégance FP devient prioritaire sur l'adoption** (équipe à l'aise avec Lisp, envie de pattern matching natif et de macros pour les abstractions monadiques) → **basculer sur Fennel**, qui offre le meilleur pattern matching et la sortie Lua 5.1 la plus propre, au prix du typage statique et de l'adoption WoW.
- **Si le typage minimal sans friction suffit** (vous voulez juste sécuriser le Lua existant) → **Teal** : migration incrémentale `.lua` → `.tl`, busted inchangé.
- **Ne PAS** partir sur LunarML/PureScript-Lua/Amulet en production : compatibilité 5.1 non garantie (LunarML/PureScript ciblent 5.3+), abandon (Amulet/Urn), ou Lua généré non débogable. Réserver PureScript→Lua à un prototype recherche si l'objectif est de prouver une architecture Free-monad.

**Approche DIY (DSL Haskell → Lua) :** justifiée *uniquement* si vous voulez le Saint-Graal (ADT/GADT/monades + Lua 5.1 garanti + IR/DCE custom) ET que vous acceptez d'écrire et maintenir un compilateur. Stack : modéliser CraftGold comme un eDSL typé Haskell (Free monad pour les effets WoW : `Quote`, `PriceOf`, `RecipeFor`), interpréter en pur pour les tests, compiler vers un AST `language-lua` pretty-printé en Lua 5.1. C'est élégant et donne un contrôle total, mais c'est un projet en soi — déconseillé sauf appétence recherche/plaisir.

---

## Annexes — Liens et ressources

**Langages compilant vers Lua (méta-listes) :**
- github.com/hengestone/lua-languages (liste exhaustive, statut maintenu/archivé)
- andregarzia.com/2020/06/languages-that-compile-to-lua.html
- en.wikipedia.org/wiki/Lua_(programming_language)

**TSTL & écosystème WoW :**
- typescripttolua.github.io (docs : getting-started, configuration, caveats, language-extensions, publishing-modules, plugins)
- github.com/TypeScriptToLua/TypeScriptToLua (2 509 stars) ; npm typescript-to-lua (v1.36.0, 51 dépendants)
- github.com/Sidoine/Ovale (exemple WoW canonique, ~47 stars) ; github.com/wowts (tstolua, wow-mock, libs) ; npm @wowts/wow-mock
- github.com/wartoshika/wow-declarations + wow-classic-declarations
- github.com/tstirrat/tsCoolDown ; npm @brusalk/react-wow-addon
- tswow.github.io (génération auto du .toc)

**Fennel :**
- fennel-lang.org (reference, documentation, /see) ; sr.ht/~technomancy/fennel ; github.com/bakpakin/Fennel (~2,7k stars)
- compilerspotlight.substack.com/p/language-showcase-fennel ; drake.dev/log/e/fennel-pattern-match

**Teal :**
- teal-language.org (book, union_types, tutorial) ; github.com/teal-language/tl (v0.24.8, ~2,6k stars) ; github.com/teal-language/teal-types

**Autres langages :**
- github.com/amuletml/amulet (archivé) ; amulet.works
- github.com/SquidDev/urn (archivé) ; urn-lang.com
- github.com/minoki/LunarML ; lunarml.readthedocs.io
- github.com/Unisay/purescript-lua ; purescript/documentation
- haxe.org (target-lua, pattern matching) ; lib.haxe.org/p/reflaxe.Lua
- github.com/luau-lang ; en.wikipedia.org/wiki/Luau_(programming_language)
- github.com/edubart/nelua-lang (écarté : compile vers C)

**Outillage WoW :**
- github.com/JuanjoSalvador/awesome-wow (ressources dev add-on)
- WoW = Lua 5.1 (sous-ensemble) : vanilla-wow-archive.fandom.com/wiki/Lua

**Contexte communautaire :** Discord TypeScriptToLua (actif) ; IRC/Matrix #fennel (Libera.Chat) ; Matrix #teal-language ; forums WoWInterface & CurseForge (dev add-on).

---

*Note de fiabilité : le nombre exact de commits du dépôt Sidoine/Ovale n'a pas pu être confirmé par les sources consultées (estimé à plusieurs milliers ; stars/forks vérifiés à ~47/46). La compatibilité Lua 5.1 de LunarML et PureScript→Lua n'est pas explicitement garantie par leur documentation (cibles 5.3/5.4/LuaJIT) et doit être validée empiriquement avant tout engagement. Le détail exact du Lua généré par TSTL pour un `switch` sur champ discriminant en cible 5.1 devrait être vérifié via le Playground TSTL (typescripttolua.github.io/play) avant adoption.*