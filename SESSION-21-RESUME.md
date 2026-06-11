# Session 21 — Reprise de contexte

## Où on en est

CraftGold est un add-on WoW Classic Era (Lua 5.1) — 16 capsules terminées (01 à 16), 5 en todo (17 à 21). On fait une pause dans le flux de progression pour résoudre un problème fondamental : **on ne veut plus écrire en Lua**.

## Le problème

Lua 5.1 est trop limité pour les abstractions qu'on veut (ADT, monades, pattern matching, séparation IO). On veut écrire dans un langage fonctionnel de haut niveau (Haskell, Scala, ou équivalent) et compiler vers du Lua 5.1 compatible WoW.

## Ce qui a été fait cette session

### Recherche large (lot 1)

On a généré un prompt de recherche large et obtenu 5 réponses (Claude, Gemini, ChatGPT, Copilot, Perplexity) :

- **Prompt** : `prompts/research-lua-transpilation-ultimate.md`
- **Réponses** : `prompts/research-lua-transpilation-ultimate-response-{claude,gemini,chatgpt,copilot,perplexity}.md`

**Résultat** : consensus décevant — les 5 LLM recommandent tous TypeScriptToLua (TSTL) ou Fennel. C'est du "JavaScript avec des types" ou du Lisp non typé. Pas ce qu'on veut.

### Recherche ciblée (lot 2)

On a relancé une recherche beaucoup plus technique et ambitieuse, axée sur :
- DSL Haskell/Scala embarqué générant du Lua (modèle Yesod/Shakespearean Templates)
- Compilation avec IR intermédiaire (modèle LLVM)
- Free Monad / Tagless Final comme abstraction IO pour l'API WoW
- Optimisations concrètes (defunctionalization, lambda lifting, unboxing)

- **Prompt** : `prompts/research-dsl-functional-to-lua.md`
- **Réponses** : `prompts/research-dsl-functional-to-lua-response-{claude,gemini,chatgpt,copilot,perplexity}.md`

**Résultat** : beaucoup plus intéressant. La réponse de Claude notamment est exceptionnelle de profondeur technique.

## Ce que le prochain agent doit faire

1. **Lire le prompt de recherche ciblée** : `prompts/research-dsl-functional-to-lua.md`
2. **Lire les 5 réponses** du lot 2 (dans `prompts/`)
3. **Synthétiser** les réponses, identifier les convergences et divergences
4. **Proposer une direction concrète** pour CraftGold

Les points clés à évaluer :
- **EDSL Haskell stagé (tagless final + language-lua)** — recommandation principale de Claude, modèle Feldspar/Yesod
- **LunarML** (SML → Lua) — le compilateur général le plus mature, mais pas de cible 5.1
- **purescript-lua** — le seul avec typeclasses/HKT, mais alpha et bus factor 1
- **Compilateur scoped DIY** — effort estimé, risques, faisabilité
- Les optimisations essentielles (uncurrying, magic-do, fusion structurelle)
- La compilation des effets (Free Monad vs Tagless Final, staging vs runtime)

## Fichiers importants

- `AGENTS.md` — consignes du projet
- `ROADMAP.md` — historique et progression
- `02-done/16-profit-analyzer-v2/` — dernière capsule, code le plus avancé
  - `src/Calculator.lua` — algorithme récursif min(buy, craft)
  - `src/Quote.lua` — DP knapsack 0/1
  - `src/Scanner.lua` — machine à états asynchrone (scan HdV)
  - `src/WoW.lua` — seam pour mocker l'API WoW
  - `src/DB.lua` — base de données statique (1500+ recettes)
  - `tests/` — tests busted avec helpers de mocking

## L'utilisateur

Il adore les langages fonctionnels (Haskell, Scala), les abstractions de haut niveau (monades, ADT, type classes), et veut quelque chose de "sexy" et ambitieux — pas du TypeScript.
