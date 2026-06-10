Voici une analyse détaillée et sourcée de ton architecture, basée sur les pratiques actuelles de la communauté de développement d'add-ons World of Warcraft.

---

## 1. Frameworks et outils de test pour add-ons WoW

L'écosystème de test hors-jeu pour WoW repose presque exclusivement sur les standards de la communauté Lua, adaptés pour simuler l'environnement de Blizzard.

* **Busted** : C'est le framework de test unitaire de référence en Lua. Il est massivement utilisé par les développeurs d'add-ons pour les tests hors-jeu. Il supporte le mocking, les spies, et s'intègre parfaitement dans des pipelines CI/CD. [Source: Documentation Questie](https://github.com/Questie/Questie/blob/master/AGENTS.md)
* **WoWUnit** : Il s'agit d'un framework de test *in-game*. Contrairement à ton approche (hors jeu), WoWUnit permet d'exécuter des tests directement dans le client WoW, branchés sur des événements du jeu (ex: `PLAYER_UPDATE`). C'est utile pour des tests d'intégration, mais inadapté pour un cycle TDD rapide hors-jeu. [Source: GitHub - Jaliborc/WoWUnit](https://github.com/Jaliborc/WoWUnit)
* **CI/CD et Automatisation** : Les projets modernes utilisent GitHub Actions avec des conteneurs Docker spécifiques (comme `runeberry/wow-addon-container`) qui incluent `busted`, `luacheck` (pour le linting avec le standard `wow`), et `luacov` (pour la couverture de code). [Source: wow-addon-container](https://github.com/runeberry/wow-addon-container)

## 2. Architecture et patterns dans les add-ons populaires

La majorité des add-ons WoW souffrent historiquement d'un couplage fort avec l'API globale (`_G`). Cependant, les add-ons très maintenus ont structuré leur code :

* **Questie** : C'est un excellent exemple. Ils ont un dossier `tests/` avec des fichiers `*.test.lua`. Ils utilisent `busted` pour leurs tests et excluent ces fichiers des builds de release. Leur code est hautement modulaire, avec des namespaces séparés pour la base de données, l'UI et la logique de quête. [Source: Questie GitHub Repo](https://github.com/Questie/Questie)
* **WeakAuras / DBM** : Ces add-ons gèrent la complexité via un découpage massif en sous-modules (souvent des add-ons distincts qui se chargent à la demande, ex: `DBM-Onyxia`). Ils s'appuient fortement sur des événements (Event Dispatchers) internes pour éviter le couplage direct entre les modules.
* **Justification de l'absence de tests (générale)** : L'écrasante majorité des add-ons (même complexes comme Leatrix Plus) n'ont pas de tests automatisés. La justification historique est que la logique métier et l'UI de WoW sont trop intriquées, et que simuler les retours exacts de l'API C de Blizzard (qui change à chaque patch) est trop coûteux à maintenir. Ils se reposent sur du QA manuel en jeu et des rapports d'erreurs (BugSack).

## 3. Dependency Injection en Lua WoW

Ton pattern de *seam* via `WoW.init(env)` est **très pur d'un point de vue de l'ingénierie logicielle**, mais **très peu commun** dans l'écosystème WoW.

* **L'approche communautaire (Mocking Global)** : La norme pour tester du Lua WoW hors-jeu n'est pas d'injecter les dépendances via un constructeur, mais de simuler l'environnement global de Blizzard. Avec `busted`, les développeurs écrasent simplement la table globale `_G` (qui contient `print`, `GetTime()`, `UnitAura()`, etc.) avant chaque test.
* **LibStub et Ace3** : `LibStub` agit comme un *Service Locator* et un gestionnaire de versions, pas comme un container d'Injection de Dépendances (DI). Vous faites `local AceGUI = LibStub("AceGUI-3.0")`. Ce n'est pas de l'injection au sens strict, mais en environnement de test, on peut facilement moquer ce que `LibStub` retourne. [Source: Ace3 Documentation](https://www.wowace.com/projects/ace3)
* **Verdict sur le "DI Container"** : Il n'y a pas de framework de DI populaire pour WoW. Ton pattern est une forme élégante d'inversion de contrôle, parfaitement valide pour du Lua pur.

## 4. Le namespace `ns` comme module system

Ton utilisation de `local addonName, ns = ...` est **la norme absolue et officielle**.

* C'est le mécanisme natif fourni par Blizzard. Lors du chargement d'un add-on, l'exécutable C de WoW passe deux arguments vararg (`...`) à chaque fichier défini dans le `.toc` : le nom de l'add-on en string, et une table vide partagée entre tous les fichiers de cet add-on. [Source: Warcraft Wiki - Writing Addons](https://www.google.com/search?q=https://warcraft.wiki.gg/wiki/Getting_started_with_writing_addons)
* **Convention de nommage** : `ns` (pour *namespace*), `addonTable`, ou `core` sont les conventions standard.
* Les add-ons utilisant Ace3 font souvent un mix : ils utilisent `ns` pour la portée interne locale, et `LibStub("AceAddon-3.0"):NewAddon("Nom")` pour exposer l'add-on globalement (ce qui facilite les modules externes). Si tu fais du Lua brut, `ns` est parfait.

## 5. Bonnes pratiques de la communauté

Pour un add-on de 500-2000 lignes en Classic Era :

1. **Ordre du `.toc**` : Fichiers purs (Math, Constantes) > Fichiers Métier (Core) > Fichiers API/Events > Fichiers UI. Le `.toc` dicte l'ordre de chargement.
2. **SavedVariables** : Ne jamais lire/écrire dedans avant le déclenchement de l'événement `ADDON_LOADED`. Prévoir une table de `defaults` et une fonction pour fusionner (merge) les variables sauvegardées avec les valeurs par défaut lors du chargement pour gérer les montées de version.
3. **UI Separation** : Isoler la création des *Frames* (XML ou Lua brut) de la logique qui les remplit. Ton `Style.lua` est une bonne pratique.

## 6. Exemples de code testé dans la communauté

Voici comment Questie mock l'API de WoW dans ses tests avec **Busted** :

```lua
-- Extrait inspiré des conventions de tests de Questie (busted)
-- Fichier: src/Core.test.lua

local assert = require("luassert")

describe("Core Business Logic", function()
    -- Mock de l'environnement WoW avant chaque test
    before_each(function()
        _G.GetTime = function() return 1000 end
        _G.UnitName = function(unit) 
            if unit == "player" then return "Thrall" end
            return nil
        end
    end)

    it("devrait calculer la bonne logique sans UI", function()
        local Core = require("src.Core")
        -- Utilisation directe de la logique
        local result = Core.CalculateSomething("player")
        assert.are.equal("Thrall", result.name)
    end)
end)

```

[Source: Questie AGENTS.md conventions](https://github.com/Questie/Questie/blob/master/AGENTS.md)

---

## Synthèse et évaluation de ton architecture

### Ce qui est bien (et très solide)

* **L'utilisation de `ns**` : 100% idiomatique.
* **Functional Core / Imperative Shell** : C'est brillant. Séparer l'état et l'I/O (le client WoW) de la logique métier est une pratique trop rare dans l'écosystème WoW. Cela rend ton code prédictible.
* **L'isolation du styling** : Découpler `Style.lua` permet de remanier l'interface sans casser les tests métier.

### Ce qui est "over-engineered"

* **Le test runner custom (`run.lua` via `loadfile`)** : Réinventer un runner de test en Lua est inutile. La communauté utilise `busted`. Il gère la découverte de fichiers (`_spec.lua`), la coloration syntaxique, les assertions enrichies (`luassert`), les spies/stubs et l'intégration continue.
* **Le Seam explicite `WoW.init(env)**` : Bien que ce soit un excellent design pattern de génie logiciel, en Lua "façon WoW", il est plus standard (et moins verbeux) de simplement simuler l'environnement C de Blizzard en surchargeant la variable globale `_G` dans le setup de tes tests via `busted`.

### Recommandations concrètes (3 changements)

1. **Remplace ton script `run.lua` par Busted.** Installe `luarocks install busted` et nomme tes tests `test_core_spec.lua`. Cela standardisera ton dépôt.
2. **Simplifie ton Seam (Optionnel).** Tu peux supprimer `WoW.init()` et utiliser directement les appels API dans ton Imperative Shell, en utilisant `busted` pour moquer l'environnement global (`_G`) lors de tes tests. Si tu préfères l'explicite strict, garde ton approche, mais sache qu'elle est inhabituelle pour les contributeurs externes.
3. **Ajoute `Luacheck`.** Configure un `.luacheckrc` avec `std = "wow"`. C'est le linter standard de la communauté qui connaît toutes les variables globales de l'API de Blizzard et signalera les erreurs avant même que tu lances WoW ou tes tests.

Souhaites-tu que je détaille comment configurer un pipeline GitHub Actions avec Busted et Luacheck pour automatiser l'exécution de tes tests à chaque commit ?