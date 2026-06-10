Voici la version vérifiée. Point important : **pour Classic Era 1.15.8, `11508` est bien l’interface courante connue**, mais le moyen le plus sûr reste en jeu :

```lua
/dump select(4, GetBuildInfo())
```

Warcraft Wiki/Wowpedia indique explicitement `11508` pour Classic et recommande `GetBuildInfo()` comme source fiable. ([Wowpedia][1])

## Q1 — `.toc`

**Statut : Confirmed.** Ton `.toc` est valide et suffisant **si** le dossier s’appelle `HelloAzeroth` et le fichier `HelloAzeroth.toc`.

```toc
## Interface: 11508
## Title: Hello Azeroth
## Notes: My first WoW add-on

HelloAzeroth.lua
```

Facts :

* Le `.toc` est bien le manifeste de l’add-on : métadonnées + ordre des fichiers à charger. ([Warcraft Wiki][2])
* Le fichier `.toc` doit avoir le même nom que son dossier parent pour être reconnu : `Interface/AddOns/HelloAzeroth/HelloAzeroth.toc`. ([AddOn Studio][3])
* Placement : dans le dossier du client WoW, sous `Interface/AddOns/`.
* Champs réellement indispensables : en pratique, **un `.toc` correctement nommé + une liste de fichiers**. Mais il faut mettre `## Interface` pour éviter “out of date”.
* Champs utiles :

  * `## Title:`
  * `## Notes:`
  * `## Author:`
  * `## Version:`
  * `## SavedVariables:`
  * `## SavedVariablesPerCharacter:`
  * `## Dependencies:` / `## RequiredDeps:`
  * `## OptionalDeps:`
  * `## LoadOnDemand: 1`
* Si `Interface` ne correspond pas, l’add-on est marqué **out of date** et peut être ignoré sauf si l’utilisateur active **Load out of date AddOns**. ([Wowpedia][1])

Gotcha : écrire `Interface: 11508` sans `##` est une erreur fréquente. Les métadonnées doivent être en commentaire spécial :

```toc
## Interface: 11508
```

## Q2 — Lua dans WoW

**Statut : Confirmed.** Les fichiers `.lua` listés dans le `.toc` sont exécutés **dans l’ordre**, de haut en bas. Le `.toc` sert aussi à définir cet ordre. ([Warcraft Wiki][2])

Classic utilise Lua **5.1**, plus précisément une version/custom subset WoW de Lua 5.1. ([AddOn Studio][4])

Exemple minimal :

```lua
print("Hello Azeroth!")
```

`print()` fonctionne directement. Dans WoW, il affiche dans la fenêtre de chat par défaut et sert de raccourci pratique par rapport à `DEFAULT_CHAT_FRAME:AddMessage()`. ([AddOn Studio][5])

Alternative :

```lua
DEFAULT_CHAT_FRAME:AddMessage("Hello Azeroth!", 1, 0.82, 0)
```

Différence simple :

```lua
print("debug:", nil) -- accepte mieux nil / debug rapide
DEFAULT_CHAT_FRAME:AddMessage("Message coloré", 1, 0, 0) -- contrôle couleur / frame
```

Oui, les globals sont partagés entre fichiers du même add-on :

```lua
-- File1.lua
HelloAzeroth = {}

-- File2.lua
HelloAzeroth.message = "Hello"
```

Gotcha : éviter les globals nus :

```lua
-- Mauvais
message = "Hello"

-- Mieux
local addonName, addon = ...
addon.message = "Hello"
```

## Q3 — Chargement et lifecycle

**Statut : Mostly confirmed.**

Les add-ons ne se chargent pas au login screen. Ils sont chargés lors du chargement de l’UI pour un personnage : entrée en jeu, reload UI, ou chargement à la demande pour les add-ons `LoadOnDemand`. Le processus de chargement et les événements comme `ADDON_LOADED` / `PLAYER_LOGIN` sont documentés dans le flow de chargement des add-ons. ([Warcraft Wiki][6])

Code top-level :

```lua
print("This runs while the addon file is being loaded")
```

Il n’y a **pas** de `main()`. WoW exécute les fichiers listés, puis ton add-on réagit généralement via événements :

```lua
local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    print("Hello Azeroth: player login complete")
end)
```

Erreur de syntaxe : le fichier fautif échoue, l’add-on peut être partiellement chargé ou cassé selon où l’erreur arrive. Il faut activer les erreurs Lua :

```text
/console scriptErrors 1
/reload
```

`/console taintLog 2` sert plutôt aux problèmes de **taint / protected actions**, pas pour un premier “hello world”. Utile plus tard, bruité pour débutants.

`/reload` recharge l’UI et réexécute les add-ons. L’API `C_UI.Reload` est documentée comme équivalente à `/reload` / console reload. ([Warcraft Wiki][7])

## Q4 — Liste des add-ons en jeu

**Statut : Corrected.**

Sur les clients modernes, il y a souvent un bouton/menu **AddOns** accessible depuis l’écran de sélection de personnage et/ou le menu en jeu. Le chemin exact peut varier selon version UI, donc je ne présenterais pas “Escape → System → Add-ons” comme vérité universelle pour Classic Era.

La liste montre typiquement :

* nom/titre de l’add-on ;
* état activé/désactivé ;
* dépendances manquantes ;
* add-on périmé/out of date ;
* options de chargement des add-ons périmés.

Oui, les add-ons peuvent être activés/désactivés individuellement.

**Load out of date AddOns** autorise le chargement d’add-ons dont `## Interface` ne correspond pas à la version attendue. Sans ça, le client peut les ignorer. ([Wowpedia][1])

Il existe une gestion globale et par personnage : l’écran d’add-ons permet généralement de choisir la configuration pour tous les personnages ou pour le personnage courant.

## Q5 — `/reload`

**Statut : Confirmed avec nuance.**

`/reload` recharge toute l’interface utilisateur. Il réexécute les fichiers Lua depuis zéro, donc les globals en mémoire sont recréés.

Oui, `/reload` suffit généralement après modification d’un `.lua` ou `.toc` existant. Mais pour **nouveaux fichiers / nouveaux add-ons**, certaines docs indiquent qu’un redémarrage du jeu peut être nécessaire selon le cas. La page `C_UI.Reload` précise qu’il faut redémarrer pour charger de nouveaux fichiers/addons, ou utiliser `/reload` comme équivalent reload UI ; je traiterais ce point comme “à tester selon client/version”. ([Warcraft Wiki][7])

SavedVariables :

* chargées au démarrage UI ;
* sauvegardées à logout/reload ;
* persistent après `/reload`.

Exemple :

```toc
## SavedVariables: HelloAzerothDB
```

```lua
HelloAzerothDB = HelloAzerothDB or {}
HelloAzerothDB.reloads = (HelloAzerothDB.reloads or 0) + 1

print("Reload count:", HelloAzerothDB.reloads)
```

Recharger un seul add-on : pas vraiment pour un add-on normal déjà chargé. Il existe `LoadAddOn()` pour les add-ons `LoadOnDemand`, mais pas un “unload/reload this addon cleanly” standard. ([AddOn Studio][8])

## Q6 — Structure / naming

**Statut : Confirmed.**

Structure recommandée :

```text
World of Warcraft/
  _classic_era_/
    Interface/
      AddOns/
        HelloAzeroth/
          HelloAzeroth.toc
          HelloAzeroth.lua
```

Le dossier et le `.toc` doivent correspondre :

```text
HelloAzeroth/HelloAzeroth.toc
```

Les sous-dossiers sont autorisés :

```toc
## Interface: 11508
## Title: Hello Azeroth

src/HelloAzeroth.lua
```

Deux add-ons ne peuvent pas avoir le même dossier : au niveau filesystem, un dossier écrase/remplace l’autre.

Conseils de nommage :

* éviter espaces, accents, caractères spéciaux ;
* préférer ASCII : `HelloAzeroth`;
* attention à la casse, surtout si tu distribues entre Windows/macOS/Linux ;
* ne pas nommer ton namespace comme une API WoW globale.

## Q7 — Pièges débutants

**Statut : Confirmed / best practices.**

Les erreurs les plus fréquentes :

```text
Interface/AddOns/HelloAzeroth/HelloAzeroth/HelloAzeroth.toc
```

Mauvais : dossier double après extraction ZIP.

```text
HelloAzeroth/HelloAzeroth.txt
```

Mauvais : Windows cache l’extension, le fichier est en réalité `.toc.txt`.

```toc
Interface: 11508
Title: Hello Azeroth
```

Mauvais : il manque `##`.

```toc
## Interface: 11508
## Title: Hello Azeroth

helloazeroth.lua
```

Mauvais possible : casse différente du vrai fichier.

Encodage : utilise **UTF-8 sans BOM** par prudence. Les fins de ligne Windows/macOS/Linux ne posent généralement pas problème.

Mots réservés Lua 5.1 à éviter comme variables :

```lua
and break do else elseif end false for function if in local nil not or repeat return then true until while
```

Évite aussi les noms globaux WoW :

```lua
CreateFrame = "oops" -- catastrophique
DEFAULT_CHAT_FRAME = nil -- catastrophique
```

Version finale conseillée pour ta capsule :

```toc
## Interface: 11508
## Title: Hello Azeroth
## Notes: My first WoW Classic Era add-on
## Author: Karim
## Version: 0.1.0

HelloAzeroth.lua
```

```lua
print("Hello Azeroth! Add-on loaded.")
```

Pour une version pédagogiquement plus propre :

```lua
local addonName = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function()
    print(addonName .. " loaded. Hello Azeroth!")
end)
```

[1]: https://wowpedia.fandom.com/wiki/Getting_the_current_interface_number "Getting the current interface number - Wowpedia - Your wiki guide to the World of Warcraft"
[2]: https://warcraft.wiki.gg/wiki/TOC_format?utm_source=chatgpt.com "TOC format - Warcraft Wiki"
[3]: https://addonstudio.org/wiki/WoW%3ATOC_format?utm_source=chatgpt.com "WoW:TOC format"
[4]: https://addonstudio.org/wiki/WoW%3ALua?utm_source=chatgpt.com "WoW:Lua"
[5]: https://addonstudio.org/wiki/WoW%3AAPI_print?utm_source=chatgpt.com "WoW API: print"
[6]: https://warcraft.wiki.gg/wiki/AddOn_loading_process?utm_source=chatgpt.com "AddOn loading process - Warcraft Wiki"
[7]: https://warcraft.wiki.gg/wiki/API_C_UI.Reload?utm_source=chatgpt.com "C_UI.Reload - Warcraft Wiki"
[8]: https://addonstudio.org/wiki/WoW%3AAPI_LoadAddOn?utm_source=chatgpt.com "WoW API: LoadAddOn"
