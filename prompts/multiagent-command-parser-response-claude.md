# Mini-langage déclaratif de commandes en Lua 5.1 — Synthèse multi-perspectives

---

## 1. État de l'art : ce qui existe déjà en Lua

### 1.1 LPeg — le standard PEG, mais éliminatoire pour vous

LPeg est une bibliothèque de pattern-matching pour Lua basée sur les Parsing Expression Grammars (PEG), avec une base formelle, une implémentation efficace et simple. C'est *la* référence du parsing en Lua, écrite par Roberto Ierusalimschy lui-même. LPeg définit les patterns comme objets de première classe, composables via des métaméthodes (opérateurs infixes), et représente les grammaires récursives par des tables où chaque entrée est une règle.

- Référence : https://www.inf.puc-rio.br/~roberto/lpeg/
- Papier fondateur : https://www.inf.puc-rio.br/~roberto/docs/peg.pdf
- Licence : MIT. Maturité : excellente (utilisé par MoonScript, Neovim, etc.)

**Verdict pour vous : éliminé.** LPeg est une **extension C**. Le package contient les sources C de LPeg — incompatible avec votre contrainte "pas de C bindings" et avec le sandbox WoW qui interdit tout chargement de code natif.

### 1.2 LuLPeg — le port pur Lua de LPeg

LuLPeg est un port 100% Lua de LPeg, émulant LPeg v0.12 ; avec LuaJIT il est environ 2 à 10 fois plus lent que LPeg natif, et avec le JIT désactivé environ 50 fois plus lent.

- https://github.com/pygy/LuLPeg — licence "Romantic WTF Public License" (très permissive)
- **Verdict : techniquement embarquable dans un addon WoW** (pur Lua 5.1-compatible), mais c'est plusieurs milliers de lignes pour parser... des commandes slash de 50 caractères. Disproportionné face à votre cible de 100-300 lignes. À garder en tête si un jour votre grammaire devient réellement récursive (expressions, filtres imbriqués).

### 1.3 argparse — le framework CLI déclaratif de référence

argparse est un parser de ligne de commande riche pour Lua, inspiré de l'argparse de Python ; il supporte arguments positionnels, options, flags, arguments optionnels, sous-commandes, et génère automatiquement les messages d'usage, d'aide et d'erreur. C'est un fichier Lua unique, testable avec busted.

- https://github.com/luarocks/argparse (repo canonique actuel), https://luarocks.org/modules/argparse/argparse
- Tutoriel : https://argparse.readthedocs.io/ — les sous-commandes sont déclarées via parser:command, et par défaut leur usage est obligatoire si le parser en possède (modifiable via require_command)
- Licence : MIT. Maturité : c'est le parser CLI utilisé par LuaRocks lui-même.

**Verdict : la meilleure source d'inspiration, mais pas réutilisable telle quelle.** Il est orienté `argv` de processus (appelle `os.exit(1)` en cas d'erreur par défaut — si les arguments ne sont pas reconnus, le parser affiche une erreur et appelle os.exit(1), sauf si on utilise :pparse()), syntaxe `--flags` GNU peu naturelle dans un chat de jeu, et ~2000 lignes avec une OO par classes. Son *modèle mental* (déclaration → parser déduit) est exactement le vôtre.

### 1.4 Penlight `lapp` et `lua_cliargs`

Penlight lapp parse la ligne de commande à partir d'un texte d'usage : on écrit la doc des options avec leurs types et défauts, et le parser s'en déduit — un DSL déclaratif où *la documentation est la déclaration*. Lapp convertit autant que possible les paramètres vers leurs types Lua équivalents ; si une conversion échoue ou qu'un paramètre requis manque, une erreur est émise avec le texte d'usage.

- https://lua-users.org/wiki/LappFramework et https://github.com/lunarmodules/Penlight (MIT)
- lua_cliargs est un parser d'arguments en ligne de commande pour Lua supportant plusieurs types d'arguments, avec valeurs par défaut pour les options — https://github.com/lunarmodules/lua_cliargs (MIT)

**Verdict : non adaptés directement** (mêmes raisons qu'argparse : orientés process CLI, flags GNU), mais l'idée de lapp — *types déclarés, coercition automatique, erreur = usage* — est précieuse.

### 1.5 Parser combinators purs Lua

L'écosystème est maigre mais existe :
- leftry, une bibliothèque de parser combinators à descente récursive gérant la récursion gauche, pour créer et composer des parsers — https://github.com/meric/leftry
- jacoblusk/lua-parser-combinators expose les briques classiques : char, str, digits, between, many, many1, separated_by, sequence_of, choice, eof — https://github.com/jacoblusk/lua-parser-combinators

**Verdict :** projets peu maintenus, peu d'utilisateurs. Pour une grammaire aussi plate que la vôtre (verbe → sous-verbe → args typés), les combinators sont un luxe — mais l'écriture d'un micro-jeu de combinators maison est l'architecture C ci-dessous.

### 1.6 Côté WoW : Ace3 (le prior art de votre domaine exact)

AceConsole-3.0 fournit l'enregistrement de commandes slash et une fonction GetArgs pour les parser selon les besoins de l'addon. GetArgs(str, numargs, startpos) retourne les arguments découpés, les manquants en nil, et gère même les guillemets et hyperlinks non terminés — c'est un tokenizer, pas un parser typé. Au-dessus, AceConfig-3.0 permet d'enregistrer une table d'options et de l'associer à une commande slash via AceConfigCmd : la table d'options déclarative (faite pour générer une GUI) *génère aussi* le parsing des commandes. AceConfigCmd reçoit l'input de la ligne de commande tel que fourni par le handler WoW, sans la commande elle-même.

- https://www.wowace.com/projects/ace3/pages/api/ace-console-3-0, https://www.wowace.com/projects/ace3/pages/api/ace-config-cmd-3-0

**Leçon clé d'Ace3 :** une seule déclaration, plusieurs interpréteurs (GUI + slash). Votre design devrait préserver cette propriété : la table de déclaration est une *donnée*, le parser n'est qu'un *interpréteur* de cette donnée. Mais AceConfigCmd est couplé à WoW et son modèle "options" (get/set de settings) colle mal aux commandes-actions (`listing add ...`).

**Conclusion de l'état de l'art : rien ne couvre exactement votre besoin** (déclaratif + sous-commandes + types métier comme `money` + batch `;` + pur Lua 5.1 auto-contenu + testable hors WoW). Vous êtes légitime à écrire les ~200 lignes.

---

## 2. Patterns d'autres écosystèmes — ce qui se transpose, ce qui ne se transpose pas

**Parser combinators** (Haskell Parsec https://hackage.haskell.org/package/parsec, Rust nom https://github.com/rust-lang/nom, JS Chevrotain https://chevrotain.io/, Python parsy https://pypi.org/project/parsy/ — une bibliothèque de combinators monadiques dans l'esprit de Parsec).
*Transposable :* la composition de petites fonctions `(input, pos) → (value, newPos) | échec`, les closures Lua s'y prêtent parfaitement.
*Non transposable :* le typage statique qui rend les combinators sûrs en Haskell/Rust ; en Lua dynamique, une erreur de composition n'explose qu'à l'exécution. Et sans sucre syntaxique (do-notation, opérateurs), un combinator Lua est verbeux.

**CLI frameworks déclaratifs** (Python argparse https://docs.python.org/3/library/argparse.html, click https://click.palletsprojects.com/, Rust clap https://github.com/clap-rs/clap, Go cobra https://github.com/spf13/cobra).
*Transposable :* le cœur conceptuel — **spec déclarative → arbre de commandes → résolution récursive des sous-commandes → binding + coercition typée → handler**. Cobra montre que `subs` doit être récursif (sous-sous-commandes gratuites). Clap (mode *derive*) montre que la déclaration doit produire *aussi* l'aide auto-générée — gratuit chez vous si la spec est une table inspectable.
*Non transposable :* la syntaxe `--flags` GNU. Dans un chat de jeu, tout est positionnel : `listing add 2840 3 2s50c`, pas `listing add --item 2840`. Cela *simplifie* énormément votre parser (pas de réordonnancement, pas d'options interleavées).

**Mini-DSL interprétés.** Le pattern dominant (cf. *Crafting Interpreters*, https://craftinginterpreters.com/) : tokenizer → parser → représentation interne → évaluateur. Pour une grammaire non récursive comme la vôtre, le "parser" dégénère en simple *binding* de tokens sur une spec — pas besoin d'AST.

**Command dispatch / CQRS** (https://martinfowler.com/bliki/CommandQuerySeparation.html). *Transposable conceptuellement :* séparer la **résolution** (quelle commande ?) de l'**exécution** (handler), et matérialiser la commande parsée comme une valeur (`{cmd="listing.add", args={...}}`). Ça rend le batch `;` trivial (liste de valeurs-commandes, exécutées séquentiellement) et ouvre la porte au logging/undo/macro-replay plus tard. *Non transposable :* tout l'appareillage event-sourcing — overkill absolu.

---

## 3. Un piège de design dans votre esquisse (important)

Votre exemple déclare les arguments comme **table à clés nommées** :

```lua
args = { itemID = "int", count = "int", buyout = "money" }
```

En Lua, **l'ordre d'itération des clés d'une table est indéfini** — or vos arguments sont positionnels : l'ordre *est* la sémantique. Il faut une déclaration ordonnée. La forme la plus compacte et lisible est un tableau de chaînes `"nom:type"` :

```lua
args = { "itemID:int", "count:int", "buyout:money" }
```

C'est exactement le compromis que fait lapp (le type vit dans la chaîne déclarative) appliqué à la structure d'argparse. Tous les designs ci-dessous l'adoptent.

---

## 4. Trois architectures candidates

### Architecture A — Dispatch table + `GetArgs`-like (simple mais limitée)

**Principe.** À la Ace3 minimal : un tokenizer (split sur espaces, guillemets gérés), une table `commands[verbe][sousVerbe] = fonction`, et chaque handler valide/convertit ses arguments lui-même.

```lua
local commands = {
  listing = {
    add = function(a, b, c)
      local itemID, count = tonumber(a), tonumber(b)
      if not itemID then return print("itemID invalide") end
      -- ... validation manuelle de c en money ...
    end,
  },
}

local function dispatch(input)
  local toks = tokenize(input)
  local node = commands[toks[1]]
  if type(node) == "table" then node = node[toks[2]] end
  if node then node(unpack(toks, 3)) end
end
```

**Évaluation.** Complexité : ~60-80 lignes. Idiomacité : correcte (c'est ce que font 90% des addons). Mais **pas déclaratif** : la validation est dupliquée dans chaque handler, les messages d'erreur sont incohérents, l'aide ne peut pas s'auto-générer, et le batch/les types sont à refaire à la main. Testabilité moyenne (il faut tester chaque handler, pas le parser). C'est le statu quo dont vous voulez sortir.

### Architecture B — Spec déclarative interprétée (tokenizer + binder typé) ★ recommandée

**Principe.** La déclaration est une **donnée** (table) ; un unique moteur générique fait : tokenize → split batch sur `;` → résolution récursive des sous-commandes → binding positionnel des tokens sur la spec avec coercition via un **registre de types extensible** → appel du handler avec des arguments déjà convertis. Aucune classe, juste des tables et des closures. C'est le modèle argparse/cobra réduit à votre grammaire positionnelle.

(Code complet en section 5 — c'est ma recommandation.)

**Évaluation.** Complexité : ~200 lignes cœur. Idiomacité : excellente (tables-as-data, closures, pas d'OO). Extensibilité : nouveau type = une fonction enregistrée ; nouvelle commande = une table ; sous-sous-commandes gratuites par récursion ; aide auto-générable en parcourant la spec. Testabilité : maximale — le moteur retourne des valeurs (jamais de side-effect), les handlers sont des fonctions injectées.

### Architecture C — Micro parser-combinators maison (ambitieux, futur-proof)

**Principe.** Écrire ~100 lignes de combinators (`seq`, `alt`, `many`, `token`, `map`) à la Parsec/nom, puis **compiler la déclaration en un parser composé** : `register` traduit la table en `alt(seq(word"add", int, int, money), seq(word"list", opt(int)), ...)`.

```lua
-- esquisse
local P = require "combinators"
local function compileCmd(def)
  local alts = {}
  for name, sub in pairs(def.subs) do
    alts[#alts+1] = P.map(P.seq(P.word(name), compileArgs(sub.args)),
                          function(_, args) return { sub = name, args = args } end)
  end
  return P.seq(P.word(def.name), P.alt(unpack(alts)))
end
-- batch = P.sepBy(command, P.sym";")
-- test busted : assert.same({sub="add", args={2840,3,250}}, run(parser, "listing add 2840 3 2s50c"))
```

**Évaluation.** Complexité : ~300-400 lignes (combinators + compilateur de spec + erreurs). Idiomacité : moyenne — élégant pour qui connaît Parsec, opaque pour un contributeur d'addon lambda ; les messages d'erreur de qualité ("attendu int à la position 12") demandent un vrai travail supplémentaire (c'est le point dur de tous les combinators, cf. la doc d'erreurs de nom : https://github.com/rust-lang/nom/blob/main/doc/error_management.md). Extensibilité : la meilleure si votre langage devient *récursif* (expressions, conditions, pipes). Testabilité : excellente, chaque combinator est testable isolément. **À choisir seulement si vous anticipez une vraie grammaire** — pour verbe+args, c'est une cathédrale pour ranger des vélos.

---

## 5. Recommandation finale : Architecture B, code complet

**Pourquoi B et pas les autres.** A ne résout pas votre problème (pas déclaratif). C résout un problème que vous n'avez pas encore (grammaire récursive) au prix de la lisibilité et des messages d'erreur. B donne exactement la propriété recherchée — *le parser se déduit de la déclaration* — dans la cible de taille, en Lua 5.1 pur, zéro dépendance, et la spec-as-data garde la porte ouverte (génération d'aide, d'autocomplétion, voire d'une GUI à la AceConfig plus tard). Le batch `;` est géré au niveau tokenizer (donc `"a;b"` entre guillemets ne casse rien).

### `cmdlang.lua` — la bibliothèque (≈210 lignes, Lua 5.1, zéro dépendance)

```lua
-- cmdlang.lua — mini-langage déclaratif de commandes (Lua 5.1, pur, auto-contenu)
-- MIT. Aucune dépendance, aucune API WoW.

local CmdLang = {}

------------------------------------------------------------------ types
-- Un type = fonction(texte) -> valeur | nil, "message d'erreur"
local baseTypes = {}

baseTypes["int"] = function(s)
  local n = tonumber(s)
  if n and n == math.floor(n) then return n end
  return nil, "entier attendu, reçu '" .. s .. "'"
end

baseTypes["number"] = function(s)
  local n = tonumber(s)
  if n then return n end
  return nil, "nombre attendu, reçu '" .. s .. "'"
end

baseTypes["string"] = function(s) return s end

baseTypes["bool"] = function(s)
  local v = s:lower()
  if v == "true" or v == "on" or v == "1" or v == "yes" then return true end
  if v == "false" or v == "off" or v == "0" or v == "no" then return false end
  return nil, "booléen attendu (on/off), reçu '" .. s .. "'"
end

-- "2g3s50c" -> 20350 (cuivre). Un nombre nu est du cuivre.
baseTypes["money"] = function(s)
  local v = s:lower()
  if v:match("^%d+$") then return tonumber(v) end
  if not v:match("^%d+[gsc]") or v:gsub("%d+[gsc]", "") ~= "" then
    return nil, "format monnaie invalide (ex: 2g3s50c), reçu '" .. s .. "'"
  end
  local total, mult = 0, { g = 10000, s = 100, c = 1 }
  for num, unit in v:gmatch("(%d+)([gsc])") do
    total = total + tonumber(num) * mult[unit]
  end
  return total
end

------------------------------------------------------------------ spec
-- "buyout:money" / "itemID:int?" / "mode:enum(on|off)" / "msg:rest"
local function parseArgSpec(s, where)
  local name, rest = s:match("^([%w_]+):(.+)$")
  assert(name, ("spec d'argument invalide '%s' dans %s"):format(s, where))
  local optional = false
  if rest:sub(-1) == "?" then optional, rest = true, rest:sub(1, -2) end
  local spec = { name = name, optional = optional }
  local enums = rest:match("^enum%((.+)%)$")
  if enums then
    spec.enum, spec.typeName = {}, rest
    for v in enums:gmatch("[^|]+") do spec.enum[v] = true end
  elseif rest == "rest" then
    spec.rest, spec.typeName = true, "rest"
  else
    spec.typeName = rest
  end
  return spec
end

local function compileNode(def, types, path)
  local node = { handler = def.handler, subs = nil, args = nil, path = path }
  if def.args then
    node.args = {}
    local seenOptional = false
    for i, s in ipairs(def.args) do
      local a = parseArgSpec(s, path)
      if not a.enum and not a.rest then
        assert(types[a.typeName], ("type inconnu '%s' dans %s"):format(a.typeName, path))
      end
      assert(not (seenOptional and not a.optional),
        "argument obligatoire après un optionnel dans " .. path)
      assert(not (node.args[i - 1] and node.args[i - 1].rest),
        "aucun argument ne peut suivre un 'rest' dans " .. path)
      seenOptional = seenOptional or a.optional
      node.args[i] = a
    end
  end
  if def.subs then
    node.subs = {}
    for name, subDef in pairs(def.subs) do
      node.subs[name] = compileNode(subDef, types, path .. " " .. name)
    end
  end
  return node
end

------------------------------------------------------------------ tokenizer
-- Découpe sur espaces ; "..." et '...' protègent espaces et ';' ;
-- ';' nu est un séparateur de batch.
local function tokenize(input)
  local toks, i, n = {}, 1, #input
  while i <= n do
    local c = input:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c == ";" then
      toks[#toks + 1] = { sep = true, pos = i }
      i = i + 1
    elseif c == '"' or c == "'" then
      local close = input:find(c, i + 1, true)
      if not close then return nil, "guillemet non fermé (position " .. i .. ")" end
      toks[#toks + 1] = { text = input:sub(i + 1, close - 1), pos = i }
      i = close + 1
    else
      local j = input:find("[%s;]", i)
      local stop = j and (j - 1) or n
      toks[#toks + 1] = { text = input:sub(i, stop), pos = i }
      i = stop + 1
    end
  end
  return toks
end

local function splitBatches(toks)
  local batches, cur = {}, {}
  for _, t in ipairs(toks) do
    if t.sep then
      if #cur > 0 then batches[#batches + 1] = cur end
      cur = {}
    else
      cur[#cur + 1] = t
    end
  end
  if #cur > 0 then batches[#batches + 1] = cur end
  return batches
end

------------------------------------------------------------------ binding
local function bindArgs(node, toks, idx, types)
  local out = {}
  for _, spec in ipairs(node.args or {}) do
    local tok = toks[idx]
    if tok == nil then
      if spec.optional then break end
      return nil, ("%s : argument '%s' (%s) manquant")
        :format(node.path, spec.name, spec.typeName)
    end
    if spec.rest then
      local parts = {}
      while toks[idx] do parts[#parts + 1] = toks[idx].text; idx = idx + 1 end
      out[spec.name] = table.concat(parts, " ")
    elseif spec.enum then
      if not spec.enum[tok.text] then
        return nil, ("%s : '%s' invalide pour '%s' (attendu : %s)")
          :format(node.path, tok.text, spec.name, spec.typeName)
      end
      out[spec.name] = tok.text
      idx = idx + 1
    else
      local v, err = types[spec.typeName](tok.text)
      if v == nil then
        return nil, ("%s : argument '%s' : %s"):format(node.path, spec.name, err)
      end
      out[spec.name] = v
      idx = idx + 1
    end
  end
  if toks[idx] then
    return nil, ("%s : argument inattendu '%s'"):format(node.path, toks[idx].text)
  end
  return out
end

------------------------------------------------------------------ API publique
local Registry = {}
Registry.__index = Registry

function CmdLang.new()
  local types = {}
  for k, v in pairs(baseTypes) do types[k] = v end
  return setmetatable({ commands = {}, types = types }, Registry)
end

function Registry:registerType(name, fn)
  self.types[name] = fn
end

function Registry:register(def)
  assert(type(def) == "table" and type(def.name) == "string",
    "register attend une table avec un champ 'name'")
  self.commands[def.name] = compileNode(def, self.types, def.name)
end

-- Parse un batch (liste de tokens) -> commande "valeur" {node=, args=} | nil, err
function Registry:resolve(toks)
  local first = toks[1]
  if not first then return nil, "commande vide" end
  local node, idx = self.commands[first.text], 2
  if not node then return nil, "commande inconnue : '" .. first.text .. "'" end
  while node.subs do
    local tok = toks[idx]
    if not tok or not node.subs[tok.text] then
      local names = {}
      for k in pairs(node.subs) do names[#names + 1] = k end
      table.sort(names)
      return nil, ("%s : sous-commande attendue (%s)%s")
        :format(node.path, table.concat(names, ", "),
                tok and (", reçu '" .. tok.text .. "'") or "")
    end
    node, idx = node.subs[tok.text], idx + 1
  end
  local args, err = bindArgs(node, toks, idx, self.types)
  if not args then return nil, err end
  return { node = node, args = args }
end

-- Exécute une ligne complète (batch ';' inclus).
-- Retourne ok(boolean), résultats|message d'erreur. Tout-ou-rien :
-- toutes les commandes sont parsées AVANT que la première ne s'exécute.
function Registry:execute(line, ctx)
  local toks, terr = tokenize(line or "")
  if not toks then return false, terr end
  local batches = splitBatches(toks)
  if #batches == 0 then return false, "commande vide" end
  local parsed = {}
  for i, batch in ipairs(batches) do
    local cmd, err = self:resolve(batch)
    if not cmd then return false, err end
    if not cmd.node.handler then
      return false, cmd.node.path .. " : pas de handler enregistré"
    end
    parsed[i] = cmd
  end
  local results = {}
  for i, cmd in ipairs(parsed) do
    results[i] = cmd.node.handler(cmd.args, ctx)
  end
  return true, results
end

return CmdLang
```

### Utilisation — déclaration et intégration WoW

```lua
local CmdLang = require "cmdlang"   -- hors WoW ; dans l'addon : local CmdLang = MyAddon.CmdLang
local cmd = CmdLang.new()

-- commande simple, sans sous-commandes
cmd:register {
  name = "ping",
  args = { "msg:rest?" },                 -- 'rest' avale tout le reste de la ligne
  handler = function(a) print("pong", a.msg or "") end,
}

-- commande à sous-commandes (récursif : un sub peut avoir des subs)
cmd:register {
  name = "listing",
  subs = {
    add = {
      args = { "itemID:int", "count:int", "buyout:money" },
      handler = function(a, ctx) ctx.db:add(a.itemID, a.count, a.buyout) end,
    },
    list = {
      args = { "itemID:int?" },
      handler = function(a, ctx) ctx.db:list(a.itemID) end,
    },
    remove = {
      args = { "itemID:int", "index:int" },
      handler = function(a, ctx) ctx.db:remove(a.itemID, a.index) end,
    },
    clear  = {
      args = { "itemID:int" },
      handler = function(a, ctx) ctx.db:clear(a.itemID) end,
    },
  },
}

-- type métier supplémentaire : une fonction, c'est tout
cmd:registerType("itemlink", function(s)
  local id = s:match("item:(%d+)")
  if id then return tonumber(id) end
  return nil, "lien d'objet attendu"
end)

-- couplage WoW : DEUX lignes, tout le reste est pur
SLASH_MONADDON1 = "/mab"
SlashCmdList["MONADDON"] = function(input)
  local ok, res = cmd:execute(input, { db = MyAddonDB })
  if not ok then print("|cffff0000" .. res .. "|r") end
end
```

`cmd:execute("listing add 2840 3 2s50c; listing list", ctx)` parse les deux commandes, valide tout, *puis* exécute — un batch dont la 2ᵉ commande est mal typée ne lance pas la 1ʳᵉ (sémantique tout-ou-rien, prévisible pour l'utilisateur).

### Tests unitaires (busted, hors WoW)

```lua
-- spec/cmdlang_spec.lua    ($ busted spec)
local CmdLang = require "cmdlang"

describe("cmdlang", function()
  local cmd, calls
  before_each(function()
    cmd, calls = CmdLang.new(), {}
    cmd:register {
      name = "listing",
      subs = {
        add  = { args = { "itemID:int", "count:int", "buyout:money" },
                 handler = function(a) calls[#calls+1] = a; return a end },
        list = { args = { "itemID:int?" },
                 handler = function(a) calls[#calls+1] = a; return a end },
      },
    }
  end)

  it("parse, convertit les types et appelle le handler", function()
    local ok, res = cmd:execute("listing add 2840 3 2s50c")
    assert.is_true(ok)
    assert.same({ itemID = 2840, count = 3, buyout = 250 }, res[1])
  end)

  it("gère les arguments optionnels", function()
    assert.is_true(cmd:execute("listing list"))
    assert.same({}, calls[1])
  end)

  it("rejette un type invalide avec un message localisé sur l'argument", function()
    local ok, err = cmd:execute("listing add abc 3 2s")
    assert.is_false(ok)
    assert.matches("itemID", err)
  end)

  it("exécute un batch, en tout-ou-rien", function()
    local ok = cmd:execute("listing add 2840 3 1g; listing list 2840")
    assert.is_true(ok)
    assert.equals(2, #calls)
    local ok2 = cmd:execute("listing list; listing add oops 1 1g")
    assert.is_false(ok2)
    assert.equals(2, #calls)  -- rien d'autre n'a tourné
  end)

  it("protège ';' et espaces entre guillemets", function()
    cmd:register { name = "say", args = { "msg:string" },
                   handler = function(a) return a.msg end }
    local ok, res = cmd:execute([[say "a;b c"]])
    assert.is_true(ok)
    assert.equals("a;b c", res[1])
  end)

  it("liste les sous-commandes en cas d'erreur", function()
    local ok, err = cmd:execute("listing frobnicate")
    assert.is_false(ok)
    assert.matches("add", err)
  end)
end)
```

### Compromis acceptés

D'abord, **arguments positionnels uniquement** : pas de `--flags` nommés ni d'arguments dans le désordre — c'est le bon trade-off pour un chat de jeu, et un type `key=value` pourrait s'ajouter en 10 lignes si besoin. Ensuite, **un seul optionnel "en escalier"** : les optionnels doivent être en fin de spec (vérifié à l'enregistrement, pas à l'exécution — fail fast pour le développeur). Enfin, **pas de grammaire récursive** : si un jour vous voulez `listing add (2840 or 2841)`, ce moteur ne suffira plus — c'est le moment où l'architecture C (ou LuLPeg) redevient pertinente.

### Roadmap d'évolution

1. **Aide auto-générée** (`/mab help listing`) : parcourir `self.commands` et formatter `node.path` + `args[i].name/typeName/optional` — la spec est déjà inspectable, ~30 lignes.
2. **Autocomplétion d'onglet** : même parcours de l'arbre, branché sur l'édition du chat WoW.
3. **Alias et abréviations** (`listing a` → `add`) : résolution par préfixe unique dans `resolve`.
4. **Defaults et validation à plage** : étendre la mini-grammaire de spec (`"count:int(1..200)=1"`), uniquement dans `parseArgSpec` + `bindArgs`.
5. **Middlewares** (confirmation, throttling, undo) : puisque `resolve` retourne la commande comme *valeur* avant exécution (le petit héritage CQRS), on peut intercaler n'importe quoi entre parsing et handler sans toucher au moteur.

---

## Récapitulatif des sources

LPeg : https://www.inf.puc-rio.br/~roberto/lpeg/ · papier PEG : https://www.inf.puc-rio.br/~roberto/docs/peg.pdf · tutoriel leafo : https://leafo.net/guides/parsing-expression-grammars.html · LuLPeg : https://github.com/pygy/LuLPeg · argparse : https://github.com/luarocks/argparse + https://argparse.readthedocs.io/ · Penlight/lapp : https://github.com/lunarmodules/Penlight + https://lua-users.org/wiki/LappFramework · lua_cliargs : https://github.com/lunarmodules/lua_cliargs · leftry : https://github.com/meric/leftry · combinators Lua : https://github.com/jacoblusk/lua-parser-combinators · AceConsole : https://www.wowace.com/projects/ace3/pages/api/ace-console-3-0 · AceConfigCmd : https://www.wowace.com/projects/ace3/pages/api/ace-config-cmd-3-0 · Parsec : https://hackage.haskell.org/package/parsec · nom : https://github.com/rust-lang/nom · Chevrotain : https://chevrotain.io/ · parsy : https://pypi.org/project/parsy/ · click : https://click.palletsprojects.com/ · clap : https://github.com/clap-rs/clap · cobra : https://github.com/spf13/cobra · Crafting Interpreters : https://craftinginterpreters.com/