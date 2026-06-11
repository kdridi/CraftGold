# 11 — Quote DP (Covering Knapsack) + CmdLang

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données réelles                                   |
| Prerequisites | Capsule 10 — Manual Listings                                |
| Type          | Autonomous (Quote DP), Autonomous (CmdLang)                 |
| Concepts      | DP covering knapsack 0/1, `quote(itemID, quantity)`, reconstruction du panier, surplus, parser déclaratif, types custom, conditions dynamiques |

## Why This Capsule?

### Problème 1 : Le prix n'est pas un nombre

Jusqu'ici, le Calculator utilisait un prix unitaire simple (`price[item]`). Mais à l'HdV, les stacks sont **indivisibles** — on ne peut pas acheter 5 unités dans un stack de 20. Le coût d'achat pour une quantité Q est un **problème d'optimisation combinatoire**, pas une simple multiplication.

Exemple : on veut 7 Copper Bars. L'HdV propose :
- 3 stacks de 3 à 2s50c (83c/unité — moins cher à l'unité)
- 1 stack de 8 à 7s (87.5c/unité — plus cher à l'unité)

Le glouton prend les 3 stacks de 3 (7s50c, 2 de surplus). La DP prend le stack de 8 (7s, 1 de surplus). **50c d'économie**.

### Problème 2 : Le dispatch de commandes est fragile

Le shell de la capsule 10 avait un gros `if/elseif` pour dispatcher les commandes, un `/cg run` qui rebouclait dans le handler (bug : `quote` ne marchait pas dans les batches), et aucun mécanisme de validation, d'aide auto-générée, ou de conditions dynamiques.

On a consulté 4 LLM (Claude, Gemini, ChatGPT, Copilot) pour concevoir un **mini-langage déclaratif** inspiré de argparse/cobra. Résultat : CmdLang, une bibliothèque Lua pur, testable, extensible.

## Quote DP — Algorithme

```
dp[q] = coût minimum pour obtenir AU MOINS q unités
dp[0] = 0
Pour chaque listing (0/1) : dp[min(Q, k+count)] = min(dp[…], dp[k] + buyout)
Résultat : dp[need]
```

- **0/1** : chaque listing est pris au plus une fois (on ne peut pas acheter le même stack deux fois)
- **Covering** : on veut *au moins* Q unités, pas exactement Q → le surplus est inévitable dans certains cas
- **Cap** : `min(need, k+count)` plafonne la DP à `need` entrées → O(need × nbListings)

### Contre-exemple glouton vs DP

| Listing | Coût | Par unité |
|---------|------|-----------|
| 100 items | 1000c | 10c/unité ← moins cher |
| 3 items | 200c | 66.7c/unité |
| 3 items | 200c | 66.7c/unité |

Besoin : 6. Glouton prend le stack de 100 (1000c, 94 de surplus). DP prend les deux stacks de 3 (400c, 0 surplus).

## CmdLang — Architecture

### Principes

1. **Déclaration = donnée** — une table Lua décrit la commande
2. **Parser = interprète générique** — il lit la table, pas le code métier
3. **Types = fonctions** — `int`, `money`, `string`, `bool`, `enum(a|b|c)`, `rest`, et customs
4. **Help = auto-généré** — depuis les déclarations
5. **Condition = fonction** — chaque commande peut être activée/désactivée dynamiquement

### Enregistrement

```lua
cmd:register {
    name = "listing",
    help = "Manage AH listings",
    subs = {
        add = {
            help = "Add a listing",
            args = {
                { "itemID:int",   "Item ID" },
                { "count:int",    "Stack size" },
                { "buyout:money", "Price" },
            },
            handler = function(args)
                ns.Listings.add(args.itemID, args.count, args.buyout)
            end,
        },
    },
}
```

### Commandes dynamiques (condition)

```lua
cmd:register {
    name = "scan",
    help = "Scan AH",
    condition = function()
        return state.ahOpen, "auction house must be open"
    end,
    handler = function() ... end,
}
```

- `help` → cache les commandes désactivées
- `helpall` → montre tout, avec la raison
- Taper une commande désactivée → « unavailable — auction house must be open »

### Fonctionnalités

| Fonctionnalité | Syntaxe |
|---|---|
| Args requis | `{ "name:type", "help" }` |
| Args optionnels | `{ "name:type?", "help" }` |
| Enum | `{ "state:enum(on\|off\|clear)", "help" }` |
| Rest (greedy) | `{ "msg:rest?", "help" }` |
| Batch natif | `cmd1 arg; cmd2 arg; cmd3` |
| Types custom | `cmd:registerType("itemlink", fn)` |
| Help auto | `cmd:help()`, `cmd:helpAll()` |

## Ce qu'on a appris

### DP Knapsack
- Le glouton (tri par coût unitaire) est **souvent bon mais parfois mauvais** — la DP garantit l'optimalité
- La reconstruction du panier se fait en remontant les choix dans la table `choice[]`
- Le plafonnement à `need` entrées rend la DP compacte

### CmdLang
- **`pairs()` ne préserve pas l'ordre en Lua** — les args doivent être un tableau ordonné `{"name:type"}`, pas `{name="type"}`
- Un seul enregistrement par commande — le parser déduit tout de la table
- Le batch `;` est géré au niveau tokenizer (les guillemets protègent les `;`)
- La séparation parse/execute rend le système 100% testable avec busted

### Découverte multi-agents (4 LLM consultés)
- **Consensus 4/4** : argparse déclaratif + command tree + type registry
- **Consensus 3/4** : le bug `pairs()` (Copilot l'a dans son code)
- **LPeg/PEG** : éliminé (C binding ou trop gros)
- **Parser combinators** : overkill pour une grammaire plate
- **Argparse Lua** : meilleure inspiration (modèle mental identique, mais orienté CLI)

## Fichiers

```
11-quote-dp/
├── ManualListings.toc       ← CmdLang.lua ajouté
├── ManualListings.lua       ← Shell réécrit avec CmdLang (plus de if/elseif)
├── src/
│   ├── Quote.lua            ← DP covering knapsack + greedy
│   ├── CmdLang.lua          ← Mini-langage déclaratif (nouveau)
│   └── ...                  ← Modules préservés des capsules précédentes
├── tests/
│   ├── helpers.lua
│   ├── test_quote.lua       ← 19 tests DP
│   └── test_cmdlang.lua     ← 57 tests CmdLang
└── README.md
```

## Tests

- **76 tests busted** (19 Quote + 57 CmdLang) — tous verts
- **Tests in-game** via `/cg test` — CmdLang parsing, Quote DP, DP vs Greedy

## Pitfalls rencontrés

1. **`quote` ne marchait pas dans `/cg run`** — le batch rebouclait dans `SlashCmdList` → abandon de l'architecture if/elseif, remplacée par CmdLang
2. **`pairs()` non ordonné** — découvert par 3/4 LLM, les args doivent être un tableau ordonné
3. **`rest` type retournait `""` au lieu de `nil`** quand aucun token restant → corrigé
4. **CmdLang `return` ignoré par WoW .toc** → ajout d'un `ns.CmdLang = CmdLang` conditionnel
