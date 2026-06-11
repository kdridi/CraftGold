# Mini-langage déclaratif de commandes en Lua — recherche, architectures, recommandation

## 0. Verdict rapide

Pour ton besoin réel — **slash commands**, **Lua 5.1**, **zéro dépendance**, **100–300 lignes**, **testable hors WoW** — je ne recommanderais **ni LPeg**, ni un parser combinator complet, ni un générateur de parser.

Le meilleur choix est une architecture **“argparse déclaratif minimal + command tree + type registry”** :

```text
input string
  -> split batch par ; hors guillemets
  -> tokenize mots/guillemets
  -> résolution dans un arbre de commandes/sous-commandes
  -> validation/conversion des arguments typés
  -> production d’un AST/action
  -> dispatch explicite vers handler
```

C’est moins “académique” qu’un PEG, mais c’est exactement le bon niveau d’abstraction pour un langage de commandes de type :

```text
listing add 2840 3 2s50c
listing list 2840
listing clear 2840; listing add 2840 3 2s50c
```

Point important : ton exemple initial

```lua
args = { itemID = "int", count = "int", buyout = "money" }
```

est **dangereux en Lua**, car les tables associatives ne donnent pas un ordre d’itération fiable. La documentation de `next`/`pairs` précise que l’ordre d’énumération des indices n’est pas spécifié ; pour des arguments positionnels, il faut donc une forme ordonnée, par exemple `args = { "itemID:int", "count:int", "buyout:money" }`. ([FxCodeBase][1])

---

## 1. État de l’art Lua

### 1.1 LPeg

**LPeg** est la bibliothèque de référence en Lua pour les **Parsing Expression Grammars**. Elle est conçue comme une bibliothèque de pattern matching fondée sur les PEG, avec des patterns comme valeurs de première classe et des opérateurs de composition. Elle supporte aussi les grammaires récursives via des tables et `lpeg.V`. ([inf.puc-rio.br][2])

Adéquation à ton besoin :

| Critère   | Évaluation                                           |
| --------- | ---------------------------------------------------- |
| Puissance | Excellente                                           |
| Maturité  | Très élevée, auteur Lua/PUC-Rio                      |
| Licence   | Très permissive, style MIT/Lua ([inf.puc-rio.br][2]) |
| Problème  | Dépendance externe, binding C, `require "lpeg"`      |
| Verdict   | Très bon outil, mais exclu par tes contraintes       |

LPeg serait mon choix si tu écrivais un vrai DSL avec expressions, opérateurs, parenthèses, précédence, quoting complexe, etc. Pour des slash commands, c’est trop puissant, trop externe, et pas portable dans WoW sans embarquer/installer quelque chose.

### 1.2 LuLPeg

**LuLPeg** est un port 100 % Lua de LPeg, qui émule LPeg v0.12 et se présente comme un remplacement possible de LPeg côté Lua pur. ([GitHub][3])

Adéquation :

| Critère   | Évaluation                                                                        |
| --------- | --------------------------------------------------------------------------------- |
| Puissance | Élevée                                                                            |
| Lua pur   | Oui                                                                               |
| Problème  | Gros morceau à vendoriser pour un besoin simple                                   |
| Risque    | Tu importes un moteur PEG entier alors que ta grammaire est une ligne de commande |
| Verdict   | Intéressant comme inspiration, mais pas mon choix pour un cœur 100–300 lignes     |

### 1.3 Microparsel

**Microparsel** est une bibliothèque de parser combinators en Lua, single-file, sans dépendance, compatible Lua 5.1+, inspirée de Parsec. Sa licence est LGPL-2.1. ([GitHub][4])

Adéquation :

| Critère         | Évaluation                                                                      |
| --------------- | ------------------------------------------------------------------------------- |
| Style           | Parser combinators                                                              |
| Lua 5.1         | Oui                                                                             |
| Zéro dépendance | Oui                                                                             |
| Licence         | LGPL-2.1, plus contraignante que MIT                                            |
| Maturité        | Projet petit                                                                    |
| Verdict         | Très intéressant pédagogiquement, mais pas idéal à embarquer dans un add-on WoW |

Ce type de bibliothèque est pertinent si tu veux enseigner la construction de parsers. Mais pour un moteur de commandes, tu vas écrire beaucoup de plomberie pour finalement parser une suite de tokens positionnels.

### 1.4 Leftry

**Leftry** est une bibliothèque de parser combinators récursive descendante avec support de la récursion gauche. Elle vise la composition de parsers et donne des exemples de non-terminaux récursifs. ([GitHub][5])

Adéquation :

| Critère   | Évaluation                             |
| --------- | -------------------------------------- |
| Puissance | Plus élevée que nécessaire             |
| Intérêt   | Bon pour grammaires récursives         |
| Problème  | Pas nécessaire pour `verb sub arg arg` |
| Verdict   | Overkill                               |

La récursion gauche est un vrai sujet pour des langages d’expression, mais ton mini-langage n’a pas besoin d’expression infixe ni d’ambiguïté grammaticale.

### 1.5 parser-gen / LPegLabel

**parser-gen** permet de décrire des grammaires PEG en Lua, produit un AST, et s’appuie sur LPegLabel. Il exige Lua >= 5.1 mais dépend de `lpeglabel`. ([GitHub][6])

Adéquation :

| Critère             | Évaluation                                            |
| ------------------- | ----------------------------------------------------- |
| Approche            | Générateur de parser PEG                              |
| AST                 | Oui                                                   |
| Erreurs labellisées | Oui                                                   |
| Problème            | Dépendance externe                                    |
| Verdict             | Bon pour un langage sérieux, pas pour tes contraintes |

### 1.6 argparse Lua

**argparse** pour Lua est une bibliothèque mature de parsing CLI, inspirée de Python argparse. Elle supporte arguments positionnels, options, flags, arguments optionnels, sous-commandes, génération automatique d’aide et messages d’erreur. Elle est MIT, installable via LuaRocks, et possède une suite de tests avec busted. ([GitHub][7])

Adéquation :

| Critère         | Évaluation                                                   |
| --------------- | ------------------------------------------------------------ |
| Modèle mental   | Très proche de ton besoin                                    |
| Subcommands     | Oui                                                          |
| Arguments typés | Partiellement, extensible                                    |
| Problème        | Pensée pour `argv`, options `--flag`, `require`, CLI système |
| Verdict         | Excellente inspiration, mais pas à utiliser telle quelle     |

C’est probablement la meilleure source d’inspiration côté API : déclaration, parsing, erreurs, help, subcommands. Mais ton contexte slash command est plus simple qu’une CLI Unix.

### 1.7 lua_cliargs

**lua_cliargs** est un parser d’arguments CLI pour Lua. Il supporte arguments requis, options courtes/longues, options multiples, flags, et un argument “splat”. Sa rockspec indique Lua >= 5.1 et licence MIT. ([GitHub][8])

Adéquation :

| Critère     | Évaluation                                  |
| ----------- | ------------------------------------------- |
| Lua 5.1     | Oui                                         |
| CLI flags   | Oui                                         |
| Subcommands | Pas son cœur principal                      |
| Verdict     | Moins pertinent qu’argparse pour ton design |

### 1.8 alt-getopt

**lua-alt-getopt** est un module MIT de parsing d’options style POSIX/GNU `getopt_long`. Il cible surtout les options `-x`, `--long`, pas les arbres de commandes déclaratifs. ([CTAN][9])

Adéquation :

| Critère           | Évaluation |
| ----------------- | ---------- |
| Parsing options   | Bon        |
| Slash command DSL | Faible     |
| Verdict           | Pas adapté |

### 1.9 Lummander

**Lummander** est une bibliothèque Lua pour créer des interfaces CLI, inspirée de Commander.js, sous licence MIT. ([GitHub][10])

Adéquation :

| Critère                | Évaluation                               |
| ---------------------- | ---------------------------------------- |
| Inspiration CLI        | Oui                                      |
| Slash command portable | Non directement                          |
| Verdict                | Inspiration possible, dépendance inutile |

---

## 2. Patterns d’autres écosystèmes

### 2.1 Parser combinators : Parsec, Megaparsec, nom

**Parsec** est présenté comme une bibliothèque industrielle de parser combinators monadiques pour Haskell. ([Haskell][11]) Le principe transposable est excellent : un parser est une fonction qui consomme une entrée et renvoie soit une erreur, soit une valeur + le reste. Les parser combinators permettent de construire de gros parsers en combinant de petits parsers. ([Haskell Docs][12])

**nom**, côté Rust, est aussi une bibliothèque de parser combinators, orientée sécurité, streaming et zéro copie. ([GitHub][13]) Ce qui est transposable en Lua : la discipline “parser pur = entrée -> résultat”. Ce qui ne l’est pas : typage fort, lifetimes, zéro-copy garanti, ergonomie par macros/traits.

Pour toi, je retiens seulement deux idées :

```text
parse ne doit pas exécuter
parse doit produire une action structurée testable
```

Pas besoin d’implémenter Parsec en Lua pour ça.

### 2.2 PEG : Ford, LPeg, Chevrotain

Les PEG ont été formalisés par Bryan Ford comme une fondation de syntaxe orientée reconnaissance, avec choix priorisé au lieu d’ambiguïté CFG classique. ([Bryan Ford's Home Page][14]) LPeg applique cette idée à Lua, avec des patterns composables et des grammaires récursives. ([inf.puc-rio.br][2])

**Chevrotain**, côté JavaScript, est un toolkit de parsing LL(k) / DSL de parsing pour construire des parsers, compilateurs ou interpréteurs sans phase de génération de code. ([Chevrotain][15]) L’idée transposable est l’**internal DSL** : utiliser le langage hôte pour déclarer la grammaire. Ce qui ne l’est pas : l’écosystème JS, les classes, l’outillage IDE, et la complexité LL(k).

### 2.3 CLI déclaratifs : argparse, click, clap, cobra

Python `argparse` supporte les sous-commandes via `add_subparsers()`, un modèle directement proche de `listing add`, `listing remove`, etc. ([Python documentation][16]) Python Click met l’accent sur la composition, les groupes et l’imbrication arbitraire de commandes. ([Click Documentation][17]) Rust clap peut parser les arguments vers des structs et les sous-commandes vers des enums, avec une approche déclarative via derive. ([Docs.rs][18]) Go Cobra est conçu pour des CLIs modernes avec sous-commandes, utilisé comme modèle pour des outils style `git`. ([GitHub][19])

Ce qui est très transposable en Lua :

```text
Command tree
  node.name
  node.args
  node.subs
  node.handler
  node.help
```

Ce qui ne l’est pas :

```text
annotations Rust
decorators Python
flags POSIX complexes
génération automatique lourde
```

### 2.4 ANTLR, yacc, bison

ANTLR est un générateur de parser qui produit un parser à partir d’une grammaire et peut construire/parcourir des parse trees. ([ANTLR][20]) Bison convertit une grammaire context-free annotée en parser LR/GLR. ([GNU][21])

Pour ton besoin, c’est clairement trop lourd. Le coût mental, le build, la génération, les artefacts et les dépendances vont à l’encontre de “Lua pur, un fichier, testable avec busted”.

### 2.5 Command dispatch, CQRS, event sourcing

Même si CQRS/event sourcing ne sont pas des bibliothèques de parsing, l’inspiration est bonne : séparer **commande demandée**, **validation**, **exécution**, **effets**, et éventuellement **journalisation/replay**. Dans ton cas, ça donne :

```text
"listing add 2840 3 2s50c"
  -> { path={"listing","add"}, args={itemID=2840,count=3,buyout=250}, raw=... }
  -> handler(ctx, args, action)
```

C’est idéal pour WoW : l’agent IA peut générer des commandes, le jeu les exécute, puis tu peux logger l’AST/action/résultat dans SavedVariables.

---

## 3. Trois architectures possibles

## Architecture A — “Argparse slash minimal” — recommandée

### Principe

Tu écris un tokenizer minimal, puis tu résous les premiers tokens dans un arbre de commandes. Une fois arrivé sur une feuille, tu parses les tokens restants comme arguments positionnels typés. Le batch `;` est géré avant le parsing, en séparant seulement les `;` hors guillemets.

### Exemple d’enregistrement

```lua
local cmd = MiniCmd.new()

cmd:register {
  name = "price",
  args = { "itemID:int", "buyout:money" },
  handler = function(ctx, args)
    ctx.print("item " .. args.itemID .. " = " .. args.buyout .. " copper")
  end
}
```

### Exemple avec sous-commandes

```lua
cmd:register {
  name = "listing",
  subs = {
    add = {
      args = { "itemID:int", "count:int", "buyout:money" },
      handler = function(ctx, a)
        ctx.addListing(a.itemID, a.count, a.buyout)
      end
    },
    list = {
      args = { "itemID:int?" },
      handler = function(ctx, a)
        ctx.listListings(a.itemID)
      end
    },
    remove = {
      args = { "itemID:int", "index:int" },
      handler = function(ctx, a)
        ctx.removeListing(a.itemID, a.index)
      end
    },
    clear = {
      args = { "itemID:int" },
      handler = function(ctx, a)
        ctx.clearListings(a.itemID)
      end
    }
  }
}
```

### Batch

```lua
cmd:dispatch("listing clear 2840; listing add 2840 3 2s50c", ctx)
```

### Test busted

```lua
describe("MiniCmd", function()
  it("parses typed listing add", function()
    local cmd = MiniCmd.new()
    cmd:register {
      name = "listing",
      subs = {
        add = { args = { "itemID:int", "count:int", "buyout:money" }, handler = function() end }
      }
    }

    local ast, err = cmd:parse("listing add 2840 3 2s50c")
    assert.is_nil(err)
    assert.are.equal(2840, ast[1].args.itemID)
    assert.are.equal(3, ast[1].args.count)
    assert.are.equal(250, ast[1].args.buyout)
  end)
end)
```

### Évaluation

| Critère        | Note                                |
| -------------- | ----------------------------------- |
| Complexité     | 180–260 lignes                      |
| Idiomacité Lua | Très bonne                          |
| Extensibilité  | Très bonne pour types/commandes     |
| Testabilité    | Excellente                          |
| Limite         | Pas fait pour expressions complexes |
| Verdict        | Choix n°1                           |

---

## Architecture B — “Micro parser combinators maison”

### Principe

Tu représentes chaque parseur comme une fonction `(tokens, index) -> ok, value, nextIndex, err`. Les commandes déclaratives compilent vers des combinateurs : `literal("listing") * literal("add") * arg("itemID", int)`.

### Exemple conceptuel

```lua
local P = MiniParse

local listingAdd =
  P.seq {
    P.lit("listing"),
    P.lit("add"),
    P.arg("itemID", P.int),
    P.arg("count", P.int),
    P.arg("buyout", P.money),
  }:map(function(x)
    return {
      path = { "listing", "add" },
      args = {
        itemID = x.itemID,
        count = x.count,
        buyout = x.buyout,
      }
    }
  end)
```

### Batch

```lua
local batch = P.sepBy(commandParser, P.lit(";"))
```

### Test

```lua
local ok, ast = listingAdd:parseTokens({ "listing", "add", "2840", "3", "2s50c" })
assert(ok)
assert(ast.args.buyout == 250)
```

### Évaluation

| Critère        | Note                                                |
| -------------- | --------------------------------------------------- |
| Complexité     | 250–450 lignes                                      |
| Élégance       | Très bonne si tu aimes le style fonctionnel         |
| Idiomacité Lua | Moyenne à bonne                                     |
| Extensibilité  | Excellente                                          |
| Testabilité    | Excellente                                          |
| Limite         | Plus abstrait, moins direct pour des slash commands |
| Verdict        | Bon projet pédagogique, pas nécessaire ici          |

Je ne le choisirais que si tu veux explicitement enseigner les parser combinators ou prévoir rapidement des syntaxes plus riches : parenthèses, alternatives, listes, filtres, expressions.

---

## Architecture C — “PEG/DSL ambitieux”

### Principe

Tu crées ou embarques un moteur PEG pur Lua, puis tu déclares une grammaire du type :

```text
Batch    <- Command (';' Command)*
Command  <- Verb Sub* Arg*
Arg      <- Quoted / Word
Money    <- [0-9]+ ('g' / 's' / 'c')
```

### Exemple conceptuel

```lua
local grammar = peg.compile [[
  batch    <- command (';' command)*
  command  <- word word* arg*
  arg      <- quoted / word
]]
```

### Test

```lua
local ast = grammar:match("listing add 2840 3 2s50c")
assert(ast[1].path[1] == "listing")
```

### Évaluation

| Critère        | Note                                            |
| -------------- | ----------------------------------------------- |
| Complexité     | 400–1000+ lignes si tu fais ça proprement       |
| Élégance       | Haute pour un vrai langage                      |
| Idiomacité Lua | Variable                                        |
| Extensibilité  | Très haute                                      |
| Testabilité    | Bonne                                           |
| Limite         | Overkill massif                                 |
| Verdict        | À garder pour un futur vrai DSL, pas pour la V1 |

---

# 4. Recommandation finale

Je recommande **Architecture A : command tree déclaratif + tokenizer + type registry**.

Pourquoi :

1. Ton langage n’est pas une grammaire générale, c’est une **CLI miniature**.
2. Les sous-commandes se modélisent naturellement par un **arbre**.
3. Les arguments sont positionnels et typés : pas besoin de PEG.
4. Le batch `;` est lexical, pas grammaticalement complexe.
5. La séparation `parse()` / `dispatch()` donne une excellente testabilité.
6. Le système reste portable hors WoW.
7. Tu peux ajouter plus tard : aliases, help, completion, flags, dry-run, AST logging.

Compromis acceptés :

| Compromis                               | Raison                        |
| --------------------------------------- | ----------------------------- |
| Arguments positionnels uniquement en V1 | Suffisant pour slash commands |
| Optionnels seulement en fin de liste    | Évite l’ambiguïté             |
| Pas de `--flags` en V1                  | Pas nécessaire dans WoW       |
| Pas de PEG                              | Trop lourd pour ce besoin     |
| `args` ordonné sous forme array         | Indispensable en Lua          |

---

# 5. Code complet recommandé

Le code ci-dessous est **Lua 5.1 pur**, sans dépendance, testable avec busted, et utilisable hors WoW. En environnement WoW, tu peux soit le mettre dans un fichier chargé avant ton shell, soit retirer le `return MiniCmd` final et exposer `MiniCmd` dans ton namespace d’add-on.

```lua
-- MiniCmd.lua
-- Lua 5.1 pure declarative slash-command parser.
-- No external dependency. Parsing and dispatch are separated.

local MiniCmd = {}
MiniCmd.__index = MiniCmd

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function keys(t)
  local r = {}
  for k in pairs(t or {}) do
    r[#r + 1] = k
  end
  table.sort(r)
  return table.concat(r, ", ")
end

local function split_commands(input)
  local out, buf = {}, {}
  local quote, esc = nil, false

  for i = 1, #input do
    local c = input:sub(i, i)

    if esc then
      buf[#buf + 1] = c
      esc = false
    elseif c == "\\" and quote then
      esc = true
    elseif quote then
      if c == quote then
        quote = nil
      else
        buf[#buf + 1] = c
      end
    elseif c == '"' or c == "'" then
      quote = c
    elseif c == ";" then
      local part = trim(table.concat(buf))
      if part ~= "" then
        out[#out + 1] = part
      end
      buf = {}
    else
      buf[#buf + 1] = c
    end
  end

  if quote then
    return nil, "unterminated quote"
  end

  local part = trim(table.concat(buf))
  if part ~= "" then
    out[#out + 1] = part
  end

  return out
end

local function tokenize(input)
  local out, buf = {}, {}
  local quote, esc = nil, false

  local function flush()
    if #buf > 0 then
      out[#out + 1] = table.concat(buf)
      buf = {}
    end
  end

  for i = 1, #input do
    local c = input:sub(i, i)

    if esc then
      if c == "n" then
        buf[#buf + 1] = "\n"
      else
        buf[#buf + 1] = c
      end
      esc = false
    elseif c == "\\" and quote then
      esc = true
    elseif quote then
      if c == quote then
        quote = nil
      else
        buf[#buf + 1] = c
      end
    elseif c == '"' or c == "'" then
      quote = c
    elseif c:match("%s") then
      flush()
    else
      buf[#buf + 1] = c
    end
  end

  if quote then
    return nil, "unterminated quote"
  end

  flush()
  return out
end

local function parse_spec(spec)
  if type(spec) == "string" then
    local name, typ = spec:match("^([%w_%-]+)%s*:%s*(.+)$")
    assert(name and typ, "bad arg spec: " .. tostring(spec))

    local optional = false
    if typ:sub(-1) == "?" then
      optional = true
      typ = typ:sub(1, -2)
    end

    return {
      name = name,
      type = typ,
      optional = optional,
    }
  elseif type(spec) == "table" then
    assert(spec.name, "arg table missing name")

    local t = {}
    for k, v in pairs(spec) do
      t[k] = v
    end

    t.type = t.type or t[1]
    assert(t.type, "arg table missing type")

    if type(t.type) == "string" and t.type:sub(-1) == "?" then
      t.optional = true
      t.type = t.type:sub(1, -2)
    end

    return t
  else
    error("bad arg spec type: " .. type(spec))
  end
end

local function normalize_args(args)
  local r = {}
  local seen_optional = false

  for i = 1, #(args or {}) do
    local a = parse_spec(args[i])

    if seen_optional and not a.optional then
      error("required arg after optional arg: " .. a.name)
    end

    if a.optional then
      seen_optional = true
    end

    r[#r + 1] = a
  end

  return r
end

local function parse_money(s)
  -- Raw copper form: "250"
  if s:match("^%d+$") then
    return tonumber(s)
  end

  -- WoW-style money: "2g50s", "35s12c", "50c", "1g2s3c"
  local rest = s
  local total = 0
  local last_rank = 4
  local matched = false

  local rank = { g = 3, s = 2, c = 1 }
  local mult = { g = 10000, s = 100, c = 1 }

  while rest ~= "" do
    local n, u = rest:match("^(%d+)([gGsScC])")
    if not n then
      return nil, "expected money like 2g50s or 35c"
    end

    u = u:lower()

    if rank[u] >= last_rank then
      return nil, "money units must be in g/s/c order"
    end

    total = total + tonumber(n) * mult[u]
    last_rank = rank[u]
    matched = true
    rest = rest:sub(#n + 2)
  end

  if not matched then
    return nil, "expected money"
  end

  return total
end

local function parse_enum(spec, s)
  local list = spec.values

  if not list and type(spec.type) == "string" then
    local body = spec.type:match("^enum%((.*)%)$")
    if body then
      list = {}
      for v in body:gmatch("[^,|]+") do
        list[#list + 1] = trim(v)
      end
    end
  end

  if not list then
    return nil, "enum missing values"
  end

  for i = 1, #list do
    if s == list[i] then
      return s
    end
  end

  return nil, "expected one of: " .. table.concat(list, ", ")
end

function MiniCmd.new()
  local self = setmetatable({}, MiniCmd)

  self.root = {
    name = "<root>",
    subs = {},
  }

  self.types = {
    string = function(s)
      return s
    end,

    word = function(s)
      if s:match("%s") then
        return nil, "expected word"
      end
      return s
    end,

    int = function(s)
      if not s:match("^%-?%d+$") then
        return nil, "expected int"
      end
      return tonumber(s)
    end,

    number = function(s)
      local n = tonumber(s)
      if not n then
        return nil, "expected number"
      end
      return n
    end,

    money = parse_money,
  }

  return self
end

function MiniCmd:type(name, fn)
  assert(type(name) == "string", "type name must be string")
  assert(type(fn) == "function", "type parser must be function")

  self.types[name] = fn
  return self
end

local function install(self, parent, name, desc)
  assert(type(name) == "string" and name ~= "", "command name expected")

  desc = desc or {}

  local node = parent.subs[name] or {
    name = name,
    subs = {},
  }

  parent.subs[name] = node

  node.help = desc.help
  node.args = normalize_args(desc.args)
  node.handler = desc.handler or desc.run

  if desc.subs then
    for sub, subdesc in pairs(desc.subs) do
      install(self, node, sub, subdesc)
    end
  end
end

function MiniCmd:register(desc)
  assert(type(desc) == "table", "register expects a table")
  assert(desc.name, "command missing name")

  install(self, self.root, desc.name, desc)
  return self
end

function MiniCmd:coerce(spec, token)
  if spec.type:match("^enum%(") or spec.values then
    return parse_enum(spec, token)
  end

  local p = self.types[spec.type]
  if not p then
    return nil, "unknown type: " .. tostring(spec.type)
  end

  return p(token, spec)
end

function MiniCmd:parse_one(line)
  local tokens, err = tokenize(line)
  if not tokens then
    return nil, err
  end

  if #tokens == 0 then
    return nil, "empty command"
  end

  local node = self.root
  local i = 1
  local path = {}

  while tokens[i] and node.subs and node.subs[tokens[i]] do
    node = node.subs[tokens[i]]
    path[#path + 1] = tokens[i]
    i = i + 1
  end

  if #path == 0 then
    return nil, "unknown command: " .. tokens[1]
  end

  if (not node.handler) and node.subs and next(node.subs) then
    local got

    if tokens[i] then
      got = "unknown subcommand: " .. tokens[i]
    else
      got = "missing subcommand"
    end

    return nil,
      got
      .. " after "
      .. table.concat(path, " ")
      .. " (expected: "
      .. keys(node.subs)
      .. ")"
  end

  local args = {}
  local specs = node.args or {}

  for ai = 1, #specs do
    local spec = specs[ai]
    local tok = tokens[i]

    if tok == nil then
      if spec.optional then
        args[spec.name] = spec.default
      else
        return nil,
          "missing argument <"
          .. spec.name
          .. "> for "
          .. table.concat(path, " ")
      end
    else
      local value, e = self:coerce(spec, tok)

      if e then
        return nil,
          "bad argument <"
          .. spec.name
          .. ">: "
          .. e
          .. " (got "
          .. tok
          .. ")"
      end

      args[spec.name] = value
      i = i + 1
    end
  end

  if tokens[i] then
    return nil, "too many arguments near: " .. tokens[i]
  end

  return {
    path = path,
    args = args,
    node = node,
    raw = line,
  }
end

function MiniCmd:parse(input)
  local parts, err = split_commands(input)
  if not parts then
    return nil, err
  end

  local ast = {}

  for i = 1, #parts do
    local item, e = self:parse_one(parts[i])
    if not item then
      return nil, "command #" .. i .. ": " .. e
    end

    ast[#ast + 1] = item
  end

  return ast
end

function MiniCmd:dispatch(input, ctx)
  local ast, err = self:parse(input)
  if not ast then
    return nil, err
  end

  local results = {}

  for i = 1, #ast do
    local item = ast[i]
    local h = item.node.handler

    if not h then
      return nil, "no handler for " .. table.concat(item.path, " ")
    end

    results[i] = h(ctx or {}, item.args, item)
  end

  return results, ast
end

-- Exposed for unit tests.
MiniCmd._tokenize = tokenize
MiniCmd._split_commands = split_commands

return MiniCmd
```

---

# 6. Utilisation complète

```lua
local MiniCmd = require "MiniCmd"

local cmd = MiniCmd.new()

local ctx = {
  print = print,

  addListing = function(itemID, count, buyout)
    print("ADD", itemID, count, buyout)
  end,

  listListings = function(itemID)
    print("LIST", itemID or "all")
  end,

  removeListing = function(itemID, index)
    print("REMOVE", itemID, index)
  end,

  clearListings = function(itemID)
    print("CLEAR", itemID)
  end,
}

cmd:register {
  name = "listing",
  subs = {
    add = {
      args = { "itemID:int", "count:int", "buyout:money" },
      handler = function(ctx, a)
        return ctx.addListing(a.itemID, a.count, a.buyout)
      end,
    },

    list = {
      args = { "itemID:int?" },
      handler = function(ctx, a)
        return ctx.listListings(a.itemID)
      end,
    },

    remove = {
      args = { "itemID:int", "index:int" },
      handler = function(ctx, a)
        return ctx.removeListing(a.itemID, a.index)
      end,
    },

    clear = {
      args = { "itemID:int" },
      handler = function(ctx, a)
        return ctx.clearListings(a.itemID)
      end,
    },
  },
}

local ok, err = cmd:dispatch("listing clear 2840; listing add 2840 3 2s50c", ctx)

if not ok then
  print("ERROR:", err)
end
```

---

# 7. Enregistrement de types custom

## Enum inline

```lua
cmd:register {
  name = "log",
  args = { "state:enum(on,off,clear,show)" },
  handler = function(ctx, a)
    print("log state:", a.state)
  end,
}
```

Commandes valides :

```text
log on
log off
log clear
log show
```

Commande invalide :

```text
log maybe
```

Erreur :

```text
bad argument <state>: expected one of: on, off, clear, show
```

## Type custom

```lua
cmd:type("item", function(token)
  local id = tonumber(token)

  if id and id > 0 then
    return id
  end

  return nil, "expected positive item id"
end)

cmd:register {
  name = "inspect",
  args = { "itemID:item" },
  handler = function(ctx, a)
    print("inspect item", a.itemID)
  end,
}
```

---

# 8. Tests unitaires busted

```lua
local MiniCmd = require "MiniCmd"

describe("MiniCmd", function()
  local function make()
    local cmd = MiniCmd.new()

    cmd:register {
      name = "listing",
      subs = {
        add = {
          args = { "itemID:int", "count:int", "buyout:money" },
          handler = function() return "add-ok" end,
        },
        list = {
          args = { "itemID:int?" },
          handler = function() return "list-ok" end,
        },
      },
    }

    return cmd
  end

  it("tokenizes quoted strings", function()
    local t = MiniCmd._tokenize([[say "hello world" 'x y']])
    assert.are.equal("say", t[1])
    assert.are.equal("hello world", t[2])
    assert.are.equal("x y", t[3])
  end)

  it("splits batch outside quotes", function()
    local parts = MiniCmd._split_commands([[a 1; say "x;y"; b 2]])
    assert.are.equal(3, #parts)
    assert.are.equal("a 1", parts[1])
    assert.are.equal([[say x;y]], parts[2])
    assert.are.equal("b 2", parts[3])
  end)

  it("parses typed command", function()
    local cmd = make()

    local ast, err = cmd:parse("listing add 2840 3 2s50c")

    assert.is_nil(err)
    assert.are.equal("listing", ast[1].path[1])
    assert.are.equal("add", ast[1].path[2])
    assert.are.equal(2840, ast[1].args.itemID)
    assert.are.equal(3, ast[1].args.count)
    assert.are.equal(250, ast[1].args.buyout)
  end)

  it("supports optional trailing args", function()
    local cmd = make()

    local ast, err = cmd:parse("listing list")

    assert.is_nil(err)
    assert.is_nil(ast[1].args.itemID)
  end)

  it("rejects invalid int", function()
    local cmd = make()

    local ast, err = cmd:parse("listing add abc 3 2s")

    assert.is_nil(ast)
    assert.matches("bad argument <itemID>", err)
  end)

  it("dispatches batch", function()
    local cmd = make()

    local results, ast = cmd:dispatch("listing list; listing add 2840 3 2s50c", {})

    assert.are.equal("list-ok", results[1])
    assert.are.equal("add-ok", results[2])
    assert.are.equal(2, #ast)
  end)
end)
```

Note : dans le test `split batch outside quotes`, le tokenizer/splitter ci-dessus retire les guillemets et garde le contenu. Si tu veux préserver les guillemets dans `raw`, conserve `raw = line`, déjà présent dans l’AST.

---

# 9. Intégration WoW

Dans WoW, tu ne veux pas que la librairie connaisse `SlashCmdList`, `print`, `SavedVariables`, `GetItemInfo`, etc. Tu fais un shell très mince :

```lua
local addonName, ns = ...

ns.cmd = MiniCmd.new()

ns.cmd:register {
  name = "listing",
  subs = {
    add = {
      args = { "itemID:int", "count:int", "buyout:money" },
      handler = function(ctx, a)
        ns.Listings.add(a.itemID, a.count, a.buyout)
        ctx.print("listing added")
      end,
    },
  },
}

SLASH_CRAFTGOLD1 = "/cg"

SlashCmdList["CRAFTGOLD"] = function(msg)
  local results, err = ns.cmd:dispatch(msg, {
    print = function(s)
      ns.WoW.print(s)
    end,
  })

  if not results then
    ns.WoW.print("|cffff4040Error:|r " .. err)
  end
end
```

Le cœur reste testable hors WoW ; seul l’adaptateur WoW est impur.

---

# 10. Roadmap réaliste

## Étape 1 — V1 solide

Déjà couvert par le code :

```text
verbes
sous-commandes
arguments obligatoires
arguments optionnels en fin
types int/string/word/number/money/enum
batch par ;
parse sans effet
dispatch séparé
tests busted
```

## Étape 2 — Ergonomie

Ajouter :

```lua
aliases = { "ls", "show" }
help = "List known listings"
```

Exemple :

```lua
list = {
  aliases = { "ls" },
  args = { "itemID:int?" },
  help = "List listings, optionally filtered by itemID",
  handler = ...
}
```

Il faudra modifier `install()` pour enregistrer les alias vers le même node.

## Étape 3 — Help automatique

Comme argparse/click/clap/cobra, tu peux générer une aide depuis l’arbre de commandes. Les frameworks CLI modernes convergent tous vers ce modèle : déclaration structurée → parsing → aide → erreurs cohérentes. ([GitHub][7])

Commande possible :

```text
help
help listing
help listing add
```

## Étape 4 — Completion

Dans WoW, tu peux exposer une fonction pure :

```lua
cmd:suggest("listing a")
-- { "add" }
```

Le modèle en arbre rend ça très facile.

## Étape 5 — Flags simples

À ajouter seulement si nécessaire :

```text
listing list 2840 --verbose
scan --limit 50
```

Mais je ne le mettrais pas en V1. Les slash commands WoW gagnent à rester courtes, prédictibles et faciles à logger.

---

# 11. Design final recommandé pour tes déclarations

Je te conseille cette forme :

```lua
cmd:register {
  name = "listing",
  help = "Manage manual auction-house listings",

  subs = {
    add = {
      args = { "itemID:int", "count:int", "buyout:money" },
      handler = function(ctx, a)
        ctx.model:add(a.itemID, a.count, a.buyout)
      end,
    },

    list = {
      args = { "itemID:int?" },
      handler = function(ctx, a)
        ctx.model:list(a.itemID)
      end,
    },

    remove = {
      args = { "itemID:int", "index:int" },
      handler = function(ctx, a)
        ctx.model:remove(a.itemID, a.index)
      end,
    },

    clear = {
      args = { "itemID:int" },
      handler = function(ctx, a)
        ctx.model:clear(a.itemID)
      end,
    },
  },
}
```

C’est l’équilibre optimal entre :

```text
déclaratif
simple
Lua idiomatique
sans dépendance
testable
suffisamment extensible
pas couplé à WoW
```

La phrase clé : **ne construis pas un parser général ; construis un parseur de commandes déclaratif.** C’est plus petit, plus robuste, et plus directement utile pour CraftGold.

[1]: https://fxcodebase.com/documents/IndicoreSDK-2.3/lua/pdf-next.html?utm_source=chatgpt.com "Lua 5.1 Reference Manual - next (table [, index])"
[2]: https://www.inf.puc-rio.br/~roberto/lpeg/ "LPeg - Parsing Expression Grammars For Lua"
[3]: https://github.com/pygy/LuLPeg "GitHub - pygy/LuLPeg: A port of LPeg 100% written in Lua. · GitHub"
[4]: https://github.com/RegularTetragon/microparsel "GitHub - RegularTetragon/microparsel: A single file, dependency-less, maximally compatible parser combinator library for Lua · GitHub"
[5]: https://github.com/meric/leftry "GitHub - meric/leftry: Leftry - A left-recursion enabled recursive-descent parser combinator library for Lua. · GitHub"
[6]: https://github.com/vsbenas/parser-gen "GitHub - vsbenas/parser-gen: A parser generator in Lua using PEG syntax. · GitHub"
[7]: https://github.com/mpeterv/argparse "GitHub - mpeterv/argparse: Feature-rich command line parser for Lua · GitHub"
[8]: https://github.com/lunarmodules/lua_cliargs?utm_source=chatgpt.com "lunarmodules/lua_cliargs: A command-line argument ..."
[9]: https://ctan.org/pkg/lua-alt-getopt?utm_source=chatgpt.com "Package lua-alt-getopt"
[10]: https://github.com/Desvelao/lummander?utm_source=chatgpt.com "Desvelao/lummander: Create a simple CLI with Lua."
[11]: https://www.haskell.org/haskellwiki/parsec?utm_source=chatgpt.com "Parsec - HaskellWiki"
[12]: https://haskell-docs.netlify.app/packages/megaparsec/?utm_source=chatgpt.com "Parsing"
[13]: https://github.com/rust-bakery/nom?utm_source=chatgpt.com "rust-bakery/nom: Rust parser combinator framework"
[14]: https://bford.info/pub/lang/peg/?utm_source=chatgpt.com "Parsing Expression Grammars: A Recognition-Based ..."
[15]: https://chevrotain.io/documentation/0_32_1/index.html?utm_source=chatgpt.com "Chevrotain"
[16]: https://docs.python.org/3/library/argparse.html?utm_source=chatgpt.com "argparse — Parser for command-line options, arguments ..."
[17]: https://click.palletsprojects.com/?utm_source=chatgpt.com "Welcome to Click — Click Documentation (8.4.x)"
[18]: https://docs.rs/clap/latest/clap/_derive/_tutorial/index.html?utm_source=chatgpt.com "clap::_derive::_tutorial - Rust"
[19]: https://github.com/spf13/cobra?utm_source=chatgpt.com "spf13/cobra: A Commander for modern Go CLI interactions"
[20]: https://www.antlr.org/?utm_source=chatgpt.com "ANTLR"
[21]: https://www.gnu.org/software/bison/manual/bison.html?utm_source=chatgpt.com "Bison 3.8.1"
