# Mini-langage déclaratif de commandes en Lua — Consultation Multi-Agents

## Le vrai problème

Je veux concevoir et implémenter en **Lua pur** un **mini-langage interprétable** pour des commandes slash. Le problème est générique : un parser déclaratif qui transforme une chaîne de caractères en actions structurées. L'application immédiate est un add-on World of Warcraft, mais le système doit être conçu comme une **bibliothèque réutilisable** — pas couplée à WoW.

## Ce que je veux

Un **mini-langage** avec :
- Des **verbes** (commandes) et des **arguments** typés (int, string, enum, money...)
- Des **sous-commandes** imbriquées (`listing add`, `listing remove`, `listing list`)
- Des arguments **obligatoires** et **optionnels**
- Un séparateur de commandes (`;`) pour le batch
- Une **syntaxe déclarative** pour enregistrer les commandes — le parser se déduit de la déclaration

## Exemple de ce que je veux pouvoir écrire

```lua
-- Déclaration d'une commande (le design exact est ce que je vous demande)
cmd:register {
    name = "listing",
    subs = {
        add    = { args = { itemID = "int", count = "int", buyout = "money" } },
        list   = { args = { itemID = "int?" } },  -- optionnel
        remove = { args = { itemID = "int", index = "int" } },
        clear  = { args = { itemID = "int" } },
    }
}
```

Et quand l'utilisateur tape `listing add 2840 3 2s50c`, le système parse, valide les types, et appelle le handler avec des arguments déjà convertis.

## Ce que je connais (et ce que je ne connais pas)

Je sais que dans la littérature il existe plusieurs approches pour ce genre de problème :
- **Parser combinators** (Haskell Parsec, et équivalents dans d'autres langages)
- **PEG parsers** (Parsing Expression Grammars)
- **Generateur de parsers** (ANTLR, yacc/bison — probablement overkill ici)
- **Argparse-like** (Python argparse, Rust clap, Go cobra)
- **Command pattern** avec dispatch table

Je ne suis pas sûr de laquelle est la mieux adaptée pour Lua, ni de ce qui existe déjà comme bibliothèque dans l'écosystème Lua.

## Ce que je demande

### 1. Recherche web obligatoire — SOURCES ET LIENS

**Faites une vraie recherche web.** Je veux des URLs pour chaque affirmation.

### 2. État de l'art — parser libraries en Lua

Recherchez et analysez ce qui existe **déjà en Lua** :
- Bibliothèques de **parser combinators** en Lua (LPeg ? autres ?)
- Bibliothèques de **PEG** en Lua (LPeg est le standard ? y en a-t-il d'autres ?)
- Bibliothèques **argparse/CLI** en Lua (pour Lua CLI tools)
- Toute bibliothèque de parsing déclaratif en Lua

Pour chaque : lien, licence, maturité, adéquation à mon besoin.

### 3. Patterns dans d'autres langages — inspiration

Analysez les patterns éprouvés dans d'autres écosystèmes qui pourraient inspirer un design Lua idiomatique :
- **Parser combinators** : Haskell Parsec/Attoparsec, Rust nom, JS chevrotain
- **CLI frameworks déclaratifs** : Python click/argparse, Rust clap, Go cobra/pflag
- **Mini-langages DSL** : comment les gens construisent-ils un petit DSL interprété ?
- **Command dispatch** : pattern CQRS, event sourcing (inspiration conceptuelle)

Pour chacun : qu'est-ce qui est transposable en Lua ? Qu'est-ce qui ne l'est pas ?

### 4. Propositions concrètes

Proposez **2-3 architectures** pour mon système, depuis "simple mais élégant" jusqu'à "ambitieux mais futur-proof". Pour chaque :

- **Principe** (en 2-3 phrases)
- **Exemple de code** montrant :
  - Comment une commande simple s'enregistre
  - Comment une commande avec sous-commandes s'enregistre
  - Comment le batch (`;`) fonctionne
  - Comment on teste unitairement le parser
- **Évaluation** :
  - Complexité (lignes de code estimées)
  - Élégance / idiomacité Lua
  - Extensibilité (nouveaux types, nouvelles commandes)
  - Testabilité

### 5. Recommandation finale

Votre **choix n°1** avec :
- Pourquoi cette approche et pas les autres
- Le code complet du système (parser + registry + dispatch)
- Les compromis acceptés
- La roadmap d'évolution possible

### 6. Contraintes techniques

- **Lua 5.1** (pas 5.3+ — c'est ce que WoW utilise)
- **Pas de dépendance externe** (la bibliothèque doit être auto-contenue — pas de C bindings, pas de `require "lpeg"`)
- **Pas d'OO lourde** (pas de classes, d'héritage — les metatables Lua sont OK si c'est idiomatique)
- **Taille cible** : 100-300 lignes pour le cœur du système (parser + registry)
- Doit tourner en **Lua pur** hors de WoW (testable avec busted)

### 7. Format de réponse

**Réponse monobloc en markdown** — tout inline dans un seul bloc texte. Pas de fichiers séparés, pas d'artifacts. Code, exemples, liens sources : tout dans la réponse.
