Voici le débat entre nos trois experts, suivi de la synthèse architecturale pour votre projet de capsules pédagogiques.

---

### Tour 1 — Propositions Idéales

**Expert 1 — Le Puriste Testabilité : "L'Architecture Hexagonale"**
« Pour moi, la règle d'or est stricte : **aucun appel à l'API WoW dans la logique métier**. Je propose une architecture hexagonale (Ports et Adapteurs). Le cœur de l'add-on (le domaine) doit ignorer qu'il tourne dans WoW.
Nous devons créer un système d'injection de dépendances primitif via la table `ns`. Un module `WoWAdapter.lua` encapsulera les `print`, `CreateFrame`, et `RegisterEvent`. La logique métier recevra ces fonctions en paramètres. Les tests unitaires pourront ainsi injecter des *mocks* parfaits en Lua standard. »

**Expert 2 — Le Pragmatiste WoW : "L'Approche Idiomatique"**
« Attention à ne pas réinventer la roue. Dans WoW, la norme c'est la simplicité. L'espace global et l'API native sont là pour être utilisés. Pour une capsule de 120 lignes, l'injection de dépendances est une aberration.
Ma proposition : utilisons `addonName, ns = ...` pour partager nos fonctions. Faisons un `init.lua` pour déclarer l'espace de noms, un `core.lua` pour la logique, et un `ui.lua`. Si on a besoin de mocker pour tester, on écrira simplement un fichier `mock_wow_api.lua` chargé uniquement lors des tests en ligne de commande pour simuler `_G.print` ou `_G.CreateFrame`. »

**Expert 3 — Le Pédagogue Architecte : "Le Modèle 'Noyau Pur / Coquille Impure' (Functional Core, Imperative Shell)"**
« Gardons à l'esprit la progression pédagogique. Si on commence avec l'architecture hexagonale à la capsule 03, les élèves vont abandonner. S'ils font du spaghetti comme le suggère l'Expert 2, la capsule 13 (CraftGold) sera un enfer à maintenir.
Je propose d'enseigner le pattern **Functional Core / Imperative Shell**. La logique métier est constituée uniquement de fonctions pures (qui prennent des arguments et retournent des valeurs, sans effets de bord). La "coquille" (les handlers d'événements WoW) s'occupe des effets de bord (lire les SavedVariables, appeler la logique pure, et mettre à jour l'UI). C'est élégant, très facile à tester, et parfait pour introduire la séparation des responsabilités. »

---

### Tour 2 — Critiques

**Expert 1 (Puriste) critique :**
« L'idée de l'Expert 2 de mocker `_G` globalement pour les tests est une bombe à retardement. Les APIs WoW sont colossales (des milliers de fonctions). Maintenir un mock global est ingérable. L'approche de l'Expert 3 (Noyau Pur) est bonne, mais comment gérez-vous la lecture de l'état de la base de données (SavedVariables) sans couplage ? Il faut de l'indirection ! »

**Expert 2 (Pragmatiste) critique :**
« L'Expert 1 veut nous faire écrire du Java en Lua. Créer des interfaces et des adapters en Lua, ça bouffe des cycles CPU et ça rend la lecture du `.toc` illogique pour un dev WoW classique. Le 'Noyau Pur' de l'Expert 3 me plaît davantage, car c'est assez proche de ce qu'on fait naturellement quand on refactorise un add-on trop lourd : on sort les algorithmes de calcul dans des fichiers séparés. »

**Expert 3 (Pédagogue) critique :**
« L'Expert 1 oublie la charge cognitive de l'apprenant. L'Expert 2 sous-estime la difficulté de tester des fichiers qui mélangent la déclaration d'une Frame et un calcul de TVA sur le Gold. Le code doit être divisé séquentiellement dans le `.toc` pour que les fichiers de logique n'aient même pas conscience que l'UI existe. »

---

### Tour 3 — Le Compromis

**Expert 1 (Puriste) :** « J'accepte de relâcher l'injection de dépendances stricte. Si nous isolons la logique métier dans des tables Lua totalement indépendantes de WoW, je pourrai simplement `dofile("Logic.lua")` dans mon harnais de test en Lua pur (ex: avec Busted) et tester les fonctions métier. »

**Expert 2 (Pragmatiste) :** « D'accord pour structurer via la table `ns`. On utilise l'idiome WoW du namespace partagé. Le `.toc` chargera d'abord les utilitaires, puis la logique (pure), et enfin les événements et l'UI (qui eux appelleront l'API WoW). »

**Expert 3 (Pédagogue) :** « C'est le compromis parfait. On enseigne le concept de "Séparation des préoccupations" non pas par des abstractions complexes, mais par la frontière des fichiers et des responsabilités des fonctions. C'est évolutif. »

---

### Synthèse : L'Architecture Finale

Voici l'architecture de compromis, pensée pour être idiomatique, testable sans douleur, et pédagogiquement évolutive.

#### 1. Structure de fichiers (via le fichier `.toc`)

L'ordre de chargement dans le `.toc` dicte l'architecture (du plus abstrait/pur au plus concret/impure).

```text
## Interface: 11403
## Title: Capsule 03
## SavedVariables: Capsule03DB

# 1. Initialisation (Le namespace)
Init.lua

# 2. Noyau Pur (Testable en Lua standard)
Logic.lua

# 3. Coquille Impure (Interactions avec WoW)
Events.lua
Commands.lua

```

#### 2. Patterns et Exemples de Code (Capsule 03)

On utilise le vararg `...` pour peupler le namespace `ns`.

**Fichier 1 : `Init.lua` (Configuration de base)**

```lua
local addonName, ns = ...

-- Initialisation de notre namespace interne
ns.Config = {
    DefaultCount = 0,
    Version = "1.0.0"
}

-- Espaces pour nos modules
ns.Logic = {}
ns.Events = {}

```

**Fichier 2 : `Logic.lua` (Le Noyau Pur - Sans API WoW)**
*Ce fichier contient la logique métier pure. Il est testable unitairement hors de WoW.*

```lua
local _, ns = ...
local Logic = ns.Logic

-- Fonction pure : prend un état, retourne un nouvel état (ou effectue un calcul)
function Logic.IncrementCounter(currentValue, step)
    if type(currentValue) ~= "number" then return 0 end
    step = step or 1
    return currentValue + step
end

function Logic.InitializeDatabase(db, defaults)
    db = db or {}
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v
        end
    end
    return db
end

```

**Fichier 3 : `Events.lua` (La Coquille Impure - API WoW)**
*Ce fichier fait le lien. Il n'est pas testé unitairement en Lua pur (on le testera in-game).*

```lua
local addonName, ns = ...

local frame = CreateFrame("Frame")

local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- 1. Lecture de l'état externe (SavedVariables globales)
        Capsule03DB = ns.Logic.InitializeDatabase(Capsule03DB, ns.Config)
        
        print("|cFF00FF00" .. addonName .. " chargé !|r")
        self:UnregisterEvent("ADDON_LOADED")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnEvent)

-- Exemple d'utilisation de la logique pure depuis l'UI/Events
function ns.Events.AddOneToCounter()
    Capsule03DB.counter = ns.Logic.IncrementCounter(Capsule03DB.counter, 1)
    print("Nouveau compteur : " .. Capsule03DB.counter)
end

```

#### 3. Conventions de nommage

* **Fichiers :** `PascalCase.lua` (ex: `CraftingAlgo.lua`).
* **Modules dans `ns` :** `PascalCase` (ex: `ns.Logic`, `ns.UI`).
* **Fonctions publiques (API du module) :** `PascalCase` (ex: `ns.Logic.CalculateCost`).
* **Fonctions privées (locales au fichier) :** `camelCase` avec ou sans underscore (ex: `local function formatGold(...)`).

#### 4. Progression (De la Capsule 03 à 13)

* **Capsule 03 :** Introduction de `Init.lua`, `Logic.lua`, et `Events.lua`. On enseigne que `Logic.lua` ne doit contenir aucun `print` ni `CreateFrame`.
* **Capsules 04-06 (UI) :** Ajout de `UI.lua`. L'UI est "bête". Elle affiche les données qu'on lui donne et délègue les clics au contrôleur (Events/Commands).
* **Capsules 07-10 (Données) :** Ajout de `Data.lua` (gestion des bases de données d'objets, scan de l'Action House). Le pattern reste le même : pureté du parsing, impureté de la récupération.
* **Capsules 11-13 (CraftGold) :** La `Logic` devient `CraftingAlgo.lua`. Parce qu'on a gardé le noyau pur depuis le début, tester l'algorithme complexe de calcul de rentabilité (TVA de l'AH, coût des compos, procs) se fera instantanément dans le terminal, sans lancer WoW.

#### 5. Les Tests Unitaires (En pratique)

Pas besoin d'outils complexes au début. Un simple fichier `tests.lua` (non inclus dans le `.toc`) exécuté avec la commande `lua tests.lua` suffit :

```lua
-- tests.lua
-- On simule le vararg "..." de WoW en créant le namespace
local ns = { Logic = {} }
local addonName = "TestAddon"

-- On charge uniquement le noyau pur (sans require, à la manière de WoW)
local function loadModule(file)
    local f = assert(loadfile(file))
    f(addonName, ns) -- On passe les arguments simulés
end

loadModule("Logic.lua")

-- Les tests (avec assert natif de Lua)
print("Testing Logic.IncrementCounter...")
assert(ns.Logic.IncrementCounter(5, 2) == 7, "Erreur: 5+2 devrait faire 7")
assert(ns.Logic.IncrementCounter(nil, 2) == 0, "Erreur: un current nil devrait retourner 0")
print("Tous les tests passent ! ✅")

```

---

Souhaitez-vous que nous approfondissions la façon de structurer la partie `UI.lua` (Capsules 04-06) pour s'assurer qu'elle reste complètement découplée de cette logique métier ?