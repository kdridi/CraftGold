# CraftGold-hs — Refaire CraftGold en Haskell EDSL compilant vers Lua 5.1

## Contexte

Je travaille sur **CraftGold**, un add-on World of Warcraft Classic Era écrit en Lua 5.1. Le projet a un double but :

1. **Produire un add-on fonctionnel** — calculer les crafts optimaux pour gagner de l'or ou monter un métier au moindre coût
2. **Apprendre à créer des add-ons WoW** — via un parcours pédagogique en capsules progressives

Le repo est ici : `/Users/kdridi/git/github.com/kdridi/CraftGold/`

## Ce qui a été fait

**16 capsules terminées** en Lua 5.1, de Hello Azeroth jusqu'à Profit Analyzer v2. Chaque capsule est un mini-add-on autonome dans `02-done/`. Voici les concepts couverts :

| # | Capsule | Concepts |
|---|---------|----------|
| 01 | Hello Azeroth | .toc, .lua, print(), /reload |
| 02 | Slash Commands | SLASH_*, SlashCmdList, chat coloré |
| 03 | Saved Variables | SavedVariables, ADDON_LOADED, persistance |
| 04 | My First Frame | CreateFrame(), backdrop, drag |
| 05 | Buttons & Text | Button, FontString, OnClick, templates |
| 06 | Recipe DB | DB statique Engineering, itemID, tests busted |
| 07 | Price & Calculator | Prix manuels, calculateur récursif min(buy, craft), mémoïsation |
| 08 | Analyze & Report | Module Report, /cg analyze, arbre buy vs craft |
| 09 | Item Info | GetItemInfo(), cache asynchrone, module ItemInfo |
| 10 | Manual Listings | Listings (stacks indivisibles), CRUD, saisie manuelle |
| 11 | Quote DP + CmdLang | DP covering knapsack 0/1, langage de commandes déclaratif |
| 12 | Bill of Materials | Expansion récursive, /cg shoplist |
| 13 | Buy vs Craft v2 | Refonte du calculateur avec quote(itemID, qty) |
| 14 | AH Scanner v1 | QueryAuctionItems, scan asynchrone d'un item |
| 15 | AH Scanner v2 | Pagination, throttling, file d'attente |
| 16 | Profit Analyzer v2 | marketPrice(), commission 5%, full scan, 1383 recettes |

Les 5 capsules restantes (17-21) sont planifiées dans ROADMAP.md.

## Ce qu'on veut maintenant

On veut **refaire le projet depuis zéro en Haskell**, en utilisant un **EDSL (Embedded Domain-Specific Language)** qui compile vers du Lua 5.1 compatible WoW. Le principe :

```
Haskell (EDSL tagless final)
    ↓  compilation (staging)
Lua 5.1 (généré automatiquement)
    ↓  chargement par WoW
Add-on fonctionnel en jeu
```

### Comment ça marche

1. On écrit le code métier en Haskell, dans l'EDSL
2. L'EDSL est basé sur le pattern **tagless final** : chaque fonction a deux instances
   - **Instance TestM** : exécution pure en Haskell (tests unitaires normaux)
   - **Instance LuaGen** : génération de code Lua (production)
3. Les fonctions Haskell s'appellent entre elles normalement — pas de `call "ns.Quote.quote"` par string
4. Le seul point de contact avec des strings, c'est le **FFI** pour les fonctions de l'API Blizzard (`GetItemInfo`, `CreateFrame`, etc.)
5. Le compilateur émet **un seul fichier Lua** (ou quelques fichiers listés dans un .toc)
6. Les tests unitaires tournent en Haskell pur — pas de Lua, pas de WoW

### Outils Haskell utilisés

- `language-lua` (Hackage) : AST Lua + pretty-printer
- GHC comme typechecker (pas de parser à écrire — Haskell EST le langage)
- Template Haskell pour dériver les encodages d'ADT
- hspec pour les tests

### Contraintes WoW NON NÉGOCIABLES

Le Lua généré doit respecter ces contraintes :

1. **Lua 5.1** (pas 5.2, pas 5.3, pas JIT-only features)
2. **Pas de `require` standard** — WoW charge via `.toc` files
3. **Pas de `goto`** — pas disponible en 5.1
4. **Max 60 upvalues** par fonction, max 200 variables locales par chunk
5. **Budget CPU strict** — les scripts longs sont tués / gelés
6. **GC pressure** — minimiser les allocations de tables
7. **Interop avec `_G`** — frames, événements, API Blizzard
8. **Code lisible** — les stack traces doivent être exploitables

### L'approche technique en détail

Le cœur de l'EDSL est une monade `Gen` (génération de code) :

```haskell
newtype Gen a = Gen (State GenState a)
  deriving (Functor, Applicative, Monad, MonadState GenState)

-- GenState contient :
--   - un compteur de noms frais (v1, v2, ...)
--   - la liste de statements Lua accumulés
--   - la table des fonctions déjà émises (déduplication)
```

Les combinateurs de l'EDSL :
- `let_ :: EExp a -> Gen (EExp a)` — émet un `local vN = ...`
- `if_ :: EExp Bool -> Gen () -> Gen () -> Gen ()` — émet un `if/else/end`
- `for_ :: EExp Int -> EExp Int -> (EExp Int -> Gen ()) -> Gen ()` — émet un `for i = a, b do ... end`
- `forPairs_ :: EExp Table -> (EExp k -> EExp v -> Gen ()) -> Gen ()` — émet un `for k, v in pairs(t) do ... end`
- `fun :: Name -> [Name] -> Gen a -> Gen (EExp (a -> b))` — émet une `function name(args) ... end`
- `return_ :: EExp a -> Gen ()` — émet `return ...`
- etc.

Le tagless final pour les effets WoW :

```haskell
class Monad m => CraftDSL m where
    getItemInfo    :: ItemID -> m (Maybe ItemInfo)
    printMsg       :: String -> m ()
    createFrame    :: FrameType -> m Frame
    registerEvent  :: Frame -> Event -> m ()
    -- etc.

-- Instance pure (tests)
instance CraftDSL TestM where ...

-- Instance codegen (production)
instance CraftDSL LuaGen where ...
```

## Ce que tu dois créer

### Répertoire

Créer `/Users/kdridi/git/github.com/kdridi/CraftGold-hs/` — frère du répertoire CraftGold existant.

### Contenu

Un projet Haskell (Stack ou Cabal) avec :

1. **La bibliothèque EDSL** (`src/CraftGold/EDSL/`) — le compilateur lui-même :
   - Types phantom (ItemID, Money, Qty, etc.)
   - Monade `Gen` et combinateurs (let_, if_, for_, fun, return_, etc.)
   - Instance LuaGen (émission de Lua via language-lua)
   - Validateur Lua 5.1 (reject goto, labels, 5.2+ features)
   - FFI pour les fonctions Blizzard

2. **Les modules métier** (`src/CraftGold/`) — le code de l'add-on :
   - Money, Listings, Quote, Calculator, etc. (réécrits en Haskell)
   - Shell (déclarations des commandes slash)
   - Init (événement ADDON_LOADED)

3. **Les tests** (`test/`) — hspec pur :
   - Tests unitaires via l'instance TestM
   - Golden tests (comparaison Lua généré vs référence)

4. **Un point d'entrée codegen** (`app/Main.hs`) — compile tout et émet les fichiers .lua + .toc

5. **Un tutoriel pédagogique** — les capsules

### Les capsules

L'idée est de créer un parcours pédagogique qui reprend les concepts des 16 capsules Lua, mais adapté pour l'apprentissage du Haskell + EDSL. Les capsules ne sont pas forcément identiques — elles peuvent être réorganisées. Mais la base pédagogique est éprouvée.

Typiquement, les premières capsules doivent :
- Montrer que l'EDSL compile et que le Lua généré fonctionne en jeu
- Introduire progressivement les combinateurs (let_, if_, for_, etc.)
- Construire les briques métier (Money, Listings, Quote, Calculator)
- Aboutir au même résultat fonctionnel que la version Lua

Les capsules sont organisées comme la version Lua :

```
00-todo/     ← Capsules non commencées (squelettes README.md)
01-wip/      ← Capsule en cours (au plus une)
02-done/     ← Capsules terminées et validées
```

Chaque capsule a un `README.md` qui documente :
- Ce qu'on apprend
- Le code Haskell écrit
- Le Lua généré attendu
- Comment tester (compilation → copie dans AddOns/ → /reload)

### Exemple de progression possible (à adapter)

**Phase A — Bootstrapping** (construire l'EDSL minimal)
- Capsule 01 : Hello Azeroth — une fonction Haskell → un fichier Lua → `/reload` → ça parle dans le chat
- Capsule 02 : Types + Opérations — phantom types, let_, if_, return_
- Capsule 03 : Boucles + Fonctions — for_, fun, récursion

**Phase B — Cœur métier** (construire CraftGold dans l'EDSL)
- Capsule 04 : Money — parse/format en Haskell, testé en Haskell, généré en Lua
- Capsule 05 : Recipe DB — données statiques, requêtes
- Capsule 06 : Calculator — récursion, mémoïsation, cycles
- Capsule 07 : Quote DP — l'algorithme knapsack en Haskell, testé en Haskell

**Phase C — Intégration WoW** (FFI + événements)
- Capsule 08 : Slash Commands — déclarer des commandes, générer le SlashCmdList
- Capsule 09 : Saved Variables — persistance via ADDON_LOADED
- Capsule 10 : AH Scanner — FFI vers QueryAuctionItems, événements, coroutines

**Phase D — Assemblage**
- Capsule 11 : Profit Analyzer — assembler toutes les briques
- etc.

### Fichiers de référence dans CraftGold (à lire)

Pour comprendre le code existant en Lua, lire dans l'ordre :

- `AGENTS.md` — conventions du projet
- `ROADMAP.md` — historique complet et architecture
- `02-done/07-price-calculator/src/Calculator.lua` — le cœur récursif min(buy, craft)
- `02-done/11-quote-dp/src/Quote.lua` — l'algorithme DP knapsack
- `02-done/11-quote-dp/src/CmdLang.lua` — le langage de commandes (sera remplacé par le système de types Haskell)
- `02-done/11-quote-dp/ManualListings.lua` — le shell WoW (slash commands + events)
- `02-done/11-quote-dp/src/WoW.lua` — la seam d'API WoW
- `02-done/16-profit-analyzer-v2/` — la capsule la plus avancée

Pour comprendre l'approche EDSL, lire :

- `prompts/research-dsl-functional-to-lua.md` — le prompt de recherche technique
- `prompts/research-dsl-functional-to-lua-response-claude.md` — la réponse la plus détaillée (axes 1-7, recommandation EDSL stagé)

## Ce que je veux de toi

1. **Proposer une roadmap détaillée** des capsules Haskell — combien, dans quel ordre, quels concepts chacune
2. **Implémenter la capsule 01** (Hello Azeroth) en entier : code Haskell, codegen, fichier Lua généré, instructions pour tester en jeu
3. **Mettre en place l'infrastructure de build** (Stack ou Cabal, structure de répertoires)

La capsule 01 doit être la **preuve de concept** : un fichier Haskell minimal qui génère du Lua valide, qu'on copie dans `Interface/AddOns/`, `/reload`, et ça fonctionne.

## Conventions

| Élément | Langue |
|---|---|
| Code Haskell | 🇬🇧 Anglais |
| README des capsules | 🇫🇷 Français |
| Noms de fichiers | 🇬🇧 Anglais |
| Discussions | 🇫🇷 Français |
