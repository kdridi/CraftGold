# Consultation multi-agents — Architecture d'un add-on WoW Classic (Lua)

---

## Tour 1 — Propositions initiales

### Expert 1 — Le Puriste Testabilité

« Le problème de votre code actuel n'est pas qu'il est petit, c'est qu'il est *inséparable*. On ne peut pas tester `increment` sans lancer WoW. Inacceptable, même pour 120 lignes.

Mon architecture, dès la capsule 03 :

```
Capsule03/
├── Capsule03.toc
├── Env.lua        -- adaptateur API WoW (CreateFrame, print, SavedVars)
├── Core.lua       -- logique métier 100% pure, zéro référence à _G WoW
├── Format.lua     -- présentation (couleurs, strings)
├── Addon.lua      -- composition root : câble tout ensemble
└── tests/
    └── test_core.lua
```

Principes :
1. **Toute** interaction externe passe par `ns.Env`. Pas un seul `print()` direct dans Core. `Env` expose `Env.print`, `Env.createFrame`, `Env.getSavedVars`.
2. **Injection de dépendances** : les modules de Core reçoivent leurs dépendances en paramètres, jamais via des globales. `Core.new(env, db)` retourne une instance via closure.
3. Les tests remplacent `Env` par un mock : une table avec des fonctions espionnes qui enregistrent les appels (`spy.printCalls = {}`).
4. État jamais global : le `db` circule en paramètre.

Avec ça, 100 % de Core et Format est testable en Lua standard, sans WoW, avec assertion sur chaque appel sortant. »

### Expert 2 — Le Pragmatiste WoW

« Quatre fichiers plus un dossier de tests pour un compteur de 120 lignes ? Les gens qui apprennent vont fuir, et les vétérans vont rire.

La réalité de l'écosystème depuis 2006 : les add-ons utilisent **le vararg `ns`** comme namespace, des **locals agressifs** (la résolution de globales coûte cher en Lua), et l'API WoW est appelée directement parce que *c'est l'environnement cible* — on n'abstrait pas le DOM dans chaque script de 100 lignes non plus.

Ce que la communauté fait vraiment :

```
Capsule03/
├── Capsule03.toc
├── Core.lua       -- la logique
└── Capsule03.lua  -- événements, slash, UI
```

Deux fichiers max. Les patterns qui comptent :
- `local addonName, ns = ...` en tête de chaque fichier — c'est LE mécanisme de modularité WoW, et il est élégant.
- Modules = tables accrochées à `ns` : `ns.Core = {}`. Pas de metatables tant qu'on n'a pas besoin d'instances multiples (on n'en a jamais besoin ici).
- Une seule globale par add-on : la SavedVariable (`Capsule03DB`), c'est imposé par le `.toc` de toute façon.
- Ace3/LibStub existent, mais pour un cours c'est une boîte noire — on les *montre* en capsule tardive, on ne construit pas dessus.

Attention aux pièges que le Puriste ignore : les SavedVariables n'existent qu'à `ADDON_LOADED`, l'ordre du `.toc` est votre seul "import system", et chaque couche d'indirection rend le débogage in-game (où il n'y a pas de stack trace confortable) plus pénible. »

### Expert 3 — Le Pédagogue Architecte

« Vous parlez tous les deux de structure, moi je parle de *courbe d'apprentissage*. La question n'est pas "quelle est la bonne architecture" mais "quel concept la capsule 03 doit-elle enseigner, et lequel attend la capsule 07".

Le concept central à enseigner, c'est **Functional Core / Imperative Shell** :
- Un **noyau pur** : fonctions qui prennent des données, retournent des données. Testables trivialement.
- Une **coquille impérative** : le code qui touche WoW (frames, événements, print). Fine, presque sans logique, pas testée unitairement.

C'est plus enseignable que l'injection de dépendances (qui demande de comprendre closures + mocks + spies d'un coup) et plus structurant que le "deux fichiers et débrouille-toi" du Pragmatiste.

Ma progression :
- **Capsule 03** : introduire UN concept — la séparation Core/Shell en deux fichiers, plus un premier test. Le moment "aha" : *voir le même Core.lua tourner dans WoW et dans le terminal*.
- **Capsules 04-06** : ajouter `UI.lua` quand l'UI grossit. Concept : la présentation est une troisième responsabilité.
- **Capsules 07-09** : introduire un module `Data` et les premières fonctions de formatage pures complexes. Concept : modules par domaine, pas par couche technique.
- **Capsules 10-13** : CraftGold assemble tout ; on introduit alors un mini-seam pour mocker une API WoW précise (`GetItemInfo`) parce qu'on en a *réellement besoin*. Concept : on abstrait quand le coût se justifie.

L'erreur à éviter : montrer l'architecture finale dès le début. L'élève doit *ressentir* la douleur du monolithe (capsules 01-02), puis recevoir le remède (capsule 03). »

---

## Tour 2 — Critiques croisées

### Le Puriste critique

« Au Pragmatiste : "c'est la tradition WoW" est un argument d'autorité, pas d'ingénierie. La tradition WoW a produit des milliers d'add-ons impossibles à maintenir. Et ton `Capsule03.lua` mélange encore événements, slash ET print — où est la frontière testable ? Le jour où `formatCount` a un bug, l'élève le découvre en jeu, pas en CI.

Au Pédagogue : Functional Core / Imperative Shell, très bien — mais ta coquille "non testée" va grossir. À la capsule 09, ton shell contiendra des handlers d'événements avec de la vraie logique de séquencement (attendre `ADDON_LOADED` *puis* `PLAYER_LOGIN`), et tu n'auras aucun moyen de la tester parce que tu as refusé l'abstraction `Env` au départ. Tu repousses la dette. »

### Le Pragmatiste critique

« Au Puriste : ton `Env.lua` est un mensonge de confort. Tu vas wrapper `CreateFrame` ? Cette fonction retourne un objet avec 200 méthodes (`SetScript`, `RegisterEvent`, `SetPoint`...). Soit ton wrapper est trivial (`Env.createFrame = CreateFrame` — et il ne sert à rien), soit tu réimplémentes un framework UI complet pour pouvoir le mocker — et là c'est des semaines de travail pour tester... quoi ? Que tu appelles bien `SetPoint` ? Tester l'UI WoW unitairement n'a jamais payé ; on la teste en jeu avec `/reload`. Abstrais ce qui a de la valeur à mocker : les **données** (`GetItemInfo`, SavedVars), pas les **frames**.

Au Pédagogue : d'accord sur presque tout, une réserve : "modules par domaine" en capsule 07, attention à ne pas exploser le nombre de fichiers. Un `.toc` de 9 entrées pour 400 lignes, c'est du bruit. Et précise un point que tu élude : *comment* l'élève exécute le test. S'il faut installer busted/luarocks, tu perds la moitié de la classe à l'installation. »

### Le Pédagogue critique

« Au Puriste : ton tour 1 demande à un élève de capsule 03 de comprendre simultanément : namespaces, injection de dépendances, closures-comme-instances, mocks et spies. C'est 4 concepts pour un compteur. La charge cognitive tue l'apprentissage. Et ton risque annoncé se réalise : `Core.new(env, db)` introduit un pattern instance là où le Pragmatiste a raison de dire qu'on n'aura jamais deux instances.

Au Pragmatiste : ton "deux fichiers" est bien, mais ta version ne dit rien des **conventions**. Sans règle explicite ("Core ne contient JAMAIS un appel à une fonction commençant par une majuscule de l'API WoW"), l'élève va remettre un `print` dans Core dès la capsule 04 et la séparation s'effondre. Une architecture pédagogique a besoin de règles vérifiables, pas d'intuition de vétéran. Et "on teste en jeu avec /reload" est exactement l'habitude que ce cours veut casser. »

---

## Tour 3 — Compromis

### Le Puriste

« Je lâche l'injection de dépendances généralisée et le wrapper de frames — le Pragmatiste a raison, mocker l'UI WoW est un puits sans fond. Je garde deux exigences non négociables :
1. **Core.lua doit charger dans Lua standard** (`lua tests/run.lua` doit passer sans WoW). C'est vérifiable mécaniquement : si Core touche une globale WoW, le test crashe. C'est la règle vérifiable que demande le Pédagogue.
2. Quand on abstrait (capsules 10+ pour `GetItemInfo`), on le fait par **seam minimal** : une table `ns.WoW` avec uniquement les fonctions de *données* qu'on a besoin de mocker, remplaçable dans les tests. Pas un Env universel. »

### Le Pragmatiste

« J'accepte le test dès la capsule 03 *si* c'est du Lua pur : un fichier `test_core.lua` avec des `assert`, exécuté avec l'interpréteur Lua nu, zéro dépendance, zéro luarocks. Et j'accepte la règle "Core = zéro API WoW" — elle est même conforme à ce que font les bons add-ons (les libs de calcul d'Auctionator sont pures, par exemple). En échange : la coquille reste *idiomatique* — appels directs à `CreateFrame`, `SlashCmdList`, locals partout — et on ne dépasse jamais 1 fichier de plus que nécessaire par capsule. »

### Le Pédagogue

« J'accepte le seam `ns.WoW` du Puriste, à condition qu'il apparaisse à la capsule où le besoin est *vécu* (quand `GetItemInfo` rend les tests de CraftGold impossibles, capsule ~10). Et j'adopte le critère du Puriste comme énoncé pédagogique : "*Si ton fichier Core.lua ne tourne pas dans un terminal, tu as cassé le contrat.*" C'est une règle qu'un élève peut auto-vérifier en 5 secondes. La progression devient : douleur (01-02) → séparation (03) → présentation (04-06) → domaines (07-09) → seam et mocking (10-13). Chaque capsule introduit exactement un concept architectural. »

---

## Synthèse du modérateur — Architecture finale

### Principe directeur

**Functional Core / Imperative Shell**, version Lua/WoW :
- **Core** : tables de fonctions pures accrochées à `ns`. Contrat absolu : *aucune* globale WoW. Vérifiable : le fichier charge en Lua standard.
- **Shell** : un fichier de câblage idiomatique WoW (frames, événements, slash). Appels API directs, pas d'abstraction. Non testé unitairement — il est volontairement trop fin pour contenir des bugs.
- **Seam tardif** : `ns.WoW` (table de fonctions de *données* uniquement) introduit en capsule 10 quand `GetItemInfo` l'exige réellement.

### Structure de fichiers — Capsule 03

```
Capsule03/
├── Capsule03.toc
├── Core.lua          -- logique pure (chargé en premier dans le .toc)
├── Capsule03.lua     -- shell : événements, slash, SavedVars, print
└── tests/
    └── test_core.lua -- exécutable avec : lua tests/test_core.lua
```

**`Capsule03.toc`** (l'ordre EST le système d'import) :

```
## Interface: 11507
## Title: Capsule 03 - Compteur persistant
## SavedVariables: Capsule03DB

Core.lua
Capsule03.lua
```

**`Core.lua`** — pur, aucune référence à WoW :

```lua
local _, ns = ...          -- vararg WoW ; simulé par le runner de test
local Core = {}
ns.Core = Core

Core.DEFAULTS = { count = 0 }

-- Complète db avec les valeurs par défaut manquantes (sans écraser)
function Core.applyDefaults(db, defaults)
    db = db or {}
    for key, value in pairs(defaults) do
        if db[key] == nil then
            db[key] = value
        end
    end
    return db
end

-- Incrémente et retourne la nouvelle valeur
function Core.increment(db, step)
    db.count = db.count + (step or 1)
    return db.count
end

-- Présentation : pure aussi (une string colorée reste une string)
function Core.formatCount(count)
    return ("Compteur : |cff33ff99%d|r"):format(count)
end
```

**`Capsule03.lua`** — le shell, idiomatique, sans logique :

```lua
local addonName, ns = ...
local Core = ns.Core

-- SavedVariables : disponibles seulement à ADDON_LOADED
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, loadedName)
    if loadedName ~= addonName then return end
    Capsule03DB = Core.applyDefaults(Capsule03DB, Core.DEFAULTS)
    ns.db = Capsule03DB
    frame:UnregisterEvent("ADDON_LOADED")
end)

SLASH_CAPSULE031 = "/cap3"
SlashCmdList.CAPSULE03 = function()
    Core.increment(ns.db)
    print(Core.formatCount(ns.db.count))
end
```

**`tests/test_core.lua`** — Lua nu, zéro dépendance. L'astuce clé : `loadfile` + appel du chunk avec deux arguments pour **simuler le vararg WoW** :

```lua
-- Exécution : lua tests/test_core.lua  (depuis le dossier Capsule03/)
local ns = {}
local chunk = assert(loadfile("Core.lua"))
chunk("Capsule03", ns)   -- simule : local addonName, ns = ...
local Core = ns.Core

local pass, fail = 0, 0
local function check(label, condition)
    if condition then
        pass = pass + 1
        print("OK   " .. label)
    else
        fail = fail + 1
        print("FAIL " .. label)
    end
end

-- applyDefaults
local db = Core.applyDefaults(nil, Core.DEFAULTS)
check("defaults sur db nil", db.count == 0)

local existing = Core.applyDefaults({ count = 7 }, Core.DEFAULTS)
check("ne pas ecraser une valeur existante", existing.count == 7)

-- increment
check("increment simple", Core.increment({ count = 0 }) == 1)
check("increment avec pas", Core.increment({ count = 10 }, 5) == 15)

-- formatCount
check("format contient la valeur", Core.formatCount(42):find("42") ~= nil)

print(("\n%d reussis, %d echoues"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
```

Si quelqu'un glisse un `print` WoW-colorisé ou un `CreateFrame` dans Core, ce runner crashe ou échoue : **le contrat est auto-vérifiant**.

### Conventions de nommage

| Élément | Convention | Exemple |
|---|---|---|
| Modules sur `ns` | PascalCase | `ns.Core`, `ns.UI`, `ns.Data` |
| Fonctions | camelCase | `Core.applyDefaults` |
| Constantes | UPPER_SNAKE | `Core.DEFAULTS` |
| SavedVariables (seule globale autorisée) | `<Addon>DB` | `Capsule03DB` |
| Fichiers | un module = un fichier du même nom | `Core.lua` → `ns.Core` |
| API WoW | jamais référencée hors du shell (et plus tard `WoW.lua`) | — |

Règle énonçable à l'élève : *« Une majuscule en début de nom global = API Blizzard = interdit dans Core. »* (Approximation volontairement simple, mais efficace.)

### Progression capsule par capsule

| Capsules | Fichiers | Concept architectural introduit |
|---|---|---|
| 01-02 | 1 fichier | Aucun — on vit le monolithe |
| 03 | `Core` + shell + test | Functional Core / Imperative Shell ; le test hors-jeu |
| 04-06 | + `UI.lua` | La présentation est une responsabilité distincte ; `UI` construit les frames, le shell ne fait que câbler |
| 07-09 | + `Data.lua` (recettes, prix) | Modules par **domaine** ; les tables de données pures sont testables aussi |
| 10-11 | + `WoW.lua` (seam : `ns.WoW.getItemInfo`, `ns.WoW.getMoney`) | L'abstraction *justifiée par le besoin* : on mocke `GetItemInfo` dans les tests parce que CraftGold en dépend |
| 12-13 (CraftGold) | `Core`, `Data`, `WoW`, `UI`, shell + suite de tests | Assemblage ; mention d'Ace3/LibStub comme « ce que vous sauriez maintenant évaluer » |

Le seam de la capsule 10 ressemble à ceci — minimal, données uniquement :

```lua
-- WoW.lua (en jeu)
local _, ns = ...
ns.WoW = {
    getItemInfo = GetItemInfo,
    getMoney    = GetMoney,
}

-- dans les tests : on injecte un faux avant de charger les modules qui l'utilisent
ns.WoW = {
    getItemInfo = function(id) return FIXTURES.items[id] end,
    getMoney    = function() return 123456 end,
}
```

### Les tests, en pratique

1. **Outillage zéro** : interpréteur Lua 5.1 (la version de WoW) ou LuaJIT, un fichier de runner par capsule, exécution `lua tests/test_core.lua`. Pas de luarocks, pas de busted en cours principal (mentionné en annexe pour les curieux).
2. **Périmètre assumé** : on teste Core, Data, et le formatage. On ne teste **pas** les frames ni les handlers — le shell est maintenu assez fin pour que sa vérification en jeu (`/reload`, `/cap3`) suffise.
3. **Le rituel pédagogique** : chaque capsule à partir de la 03 se termine par deux validations — le test passe dans le terminal, ET l'add-on fonctionne en jeu. Le même `Core.lua`, deux environnements : c'est la démonstration vivante de ce que « découplé » veut dire.

### Ce que chaque expert a cédé — et gardé

Le Puriste a abandonné l'injection de dépendances et le wrapper d'UI, mais a imposé le contrat vérifiable « Core charge en Lua nu » et le seam de données. Le Pragmatiste a accepté les tests dès la capsule 03, mais a gardé un shell 100 % idiomatique et un nombre de fichiers minimal. Le Pédagogue a obtenu sa règle d'or : un concept par capsule, et l'abstraction introduite seulement au moment où l'élève en ressent le besoin.