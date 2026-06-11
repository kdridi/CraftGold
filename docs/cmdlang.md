# CmdLang — Mini-langage déclaratif de commandes

> Source : consultation multi-agents (Claude, Gemini, ChatGPT, Copilot) — voir `prompts/multiagent-command-parser.md`

## Problème

Le dispatch de commandes slash dans un add-on WoW est typiquement un monolithe `if/elseif` non testable. Le batch (`;`) est fragile. L'aide est codée en dur. Les commandes ne peuvent pas être conditionnelles.

## Solution : CmdLang

Bibliothèque Lua 5.1 pur, zéro dépendance, ~300 lignes, testable avec busted.

### Principes

1. **Déclaration = donnée** — une table Lua décrit chaque commande
2. **Parser = interprète générique** — parse, valide, convertit les types depuis la déclaration
3. **Types = fonctions** — `int`, `money`, `string`, `bool`, `enum(a|b|c)`, `rest`, customs
4. **Help = auto-généré** — `help()` (activées), `helpAll()` (tout avec raisons)
5. **Condition = fonction** — activation/désactivation dynamique sans register/unregister
6. **Parse et execute séparés** — testable indépendamment

### Types fournis

| Type | Exemple | Résultat |
|------|---------|----------|
| `int` | `42` | `42` (number) |
| `number` | `3.14` | `3.14` |
| `string` | `hello` | `"hello"` |
| `bool` | `on`, `off`, `yes`, `no`, `1`, `0` | `true` / `false` |
| `money` | `2g50s30c` | `25030` (cuivre) |
| `enum(a\|b\|c)` | `on` | `"on"` (validé) |
| `rest` | `hello world` | `"hello world"` (greedy) |

### Déclaration d'args

```lua
args = {
    { "itemID:int",      "Item ID" },         -- requis
    { "count:int",       "Stack size" },       -- requis
    { "buyout:money",    "Price" },            -- requis
    { "itemID:int?",     "Filter (optional)"}, -- optionnel (? en suffixe)
    { "state:enum(on|off|clear|show)", "" },   -- enum
    { "msg:rest?",       "Message" },          -- avale tout le reste
}
```

**Règle** : les optionnels doivent être en fin de liste. Validé à l'enregistrement.

### Condition dynamique

```lua
cmd:register {
    name = "scan",
    condition = function()
        return state.ahOpen, "auction house must be open"
    end,
    handler = function() ... end,
}
```

- `condition` retourne `(bool, reason)` — évaluée au moment du parse
- L'événement WoW modifie `state.ahOpen`, pas les commandes
- `help()` cache les désactivées, `helpAll()` les montre avec la raison

### Batch natif

Le séparateur `;` est géré au niveau tokenizer. Les guillemets protègent :

```
/cg listing clear 2840; listing add 2840 3 2s50c; quote 2840 7
```

### Messages d'erreur

```
listing add: argument 'itemID': integer expected, got 'abc'
listing: unknown subcommand 'explode' (expected: add, clear, list, remove)
scan: unavailable — auction house must be open
```

### État de l'art (recherche 4 LLM)

| Bibliothèque | Verdict |
|---|---|
| LPeg (PEG) | Éliminé — C binding |
| LuLPeg (PEG pur Lua) | Trop gros (milliers de lignes) |
| argparse Lua | Meilleure inspiration, mais orienté CLI `--flags` |
| Parser combinators | Overkill pour grammaire plate |
| AceConsole/AceConfig | Inspiration partielle (déclaration = données) |

**Résultat** : rien n'existait pour ce besoin précis (déclaratif + sous-commandes + types métier + batch + pur Lua 5.1 + conditions). CmdLang est original.

### Bug connu : `pairs()` en Lua

`{ itemID = "int", count = "int" }` ne préserve pas l'ordre. Il faut un tableau ordonné : `{ "itemID:int", "count:int" }`. Découvert par 3/4 LLM.
