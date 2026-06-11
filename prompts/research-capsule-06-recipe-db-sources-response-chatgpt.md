# Recherche — Capsule 06 : Sources de données recettes Engineering pour WoW Classic Era

## Synthèse opérationnelle

Le meilleur “jackpot technique” trouvé est **CraftLib** : il fournit exactement le type de structure dont CraftGold a besoin — `spellId`, `itemId`, `skillRequired`, seuils orange/yellow/green/gray, reagents `{ itemId, name, count }`, et source trainer/vendor/drop/quest/etc. — avec une couverture annoncée complète des métiers Classic, dont Engineering. Mais sa licence est **All Rights Reserved**, donc il ne faut pas copier sa DB dans CraftGold sans autorisation explicite. ([GitHub][1])

Le meilleur compromis **réutilisable légalement** semble être **LibCrafts-1.0** : bibliothèque Lua MIT pour Vanilla 1.12.1, conçue comme DB embarquable de crafts, avec mapping spells/recipes/reagents/results/sources. Pour CraftGold 1–150 Engineering, c’est probablement la source la plus exploitable si tu acceptes de partir de Vanilla 1.12.1 puis de valider les 15–20 recettes contre Classic Era 1.15.x. ([GitHub][2])

Pour produire une DB propre à CraftGold, je recommanderais ce pipeline : **LibCrafts-1.0 / TradeSkillsData comme base**, **WowDbScripts / DB2 comme vérification technique**, puis **Blizzard API ou Wowhead Classic comme validation ponctuelle itemID/nom/source**. ([GitHub][2])

---

## 1. Bases de données open source WoW Classic

| Projet                           |                                        Format | Couverture                                                                                                                                                                                        | Version / fraîcheur                                                                                                                              | Licence                                                                                                   | Verdict pour CraftGold                                                                                                                                 |
| -------------------------------- | --------------------------------------------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **CraftLib**                     |                        Lua tables + API addon | Recettes complètes, `spellId`, `itemId`, skill requis, seuils orange/yellow/green/gray, reagents, sources trainer/vendor/drop/quest/etc. La doc annonce Engineering “239 Complete”. ([GitHub][1]) | Support annoncé : Classic Era, Season of Discovery, Anniversary, Hardcore ; release v0.5.0 datée du 23 février 2026. ([GitHub][1])               | **All Rights Reserved**. ([GitHub][3])                                                                    | **Meilleure source technique**, mais pas copiable directement. Option : demander l’autorisation, ou l’utiliser comme dépendance/runtime si acceptable. |
| **LibCrafts-1.0**                |                       Lua library embarquable | DB ID-based de crafts : spells, recipes, reagents, results, sources ; requêtes par reagent ID, recipe ID, profession. ([GitHub][2])                                                               | Vanilla WoW 1.12.1 + Turtle WoW ; mis à jour dans l’écosystème GitHub topic fin 2025. ([GitHub][2])                                              | **MIT**. ([GitHub][2])                                                                                    | **Très bon candidat** pour extraire 15–20 recettes Engineering 1–150, puis valider contre Classic Era.                                                 |
| **TradeSkillsData**              |          Lua tables, dossier `db/`, types Lua | DB de recettes, vendors et sources pour Vanilla ; historiquement utilisée par MissingTradeSkillsList. ([GitHub][4])                                                                               | Repo archivé / plus maintenu ; mainteneur recommande de migrer vers LibCrafts. Dernière version documentée v1.2.2, 7 février 2024. ([GitHub][4]) | Licence non visible clairement dans les extraits récupérés ; à vérifier dans le repo avant réutilisation. | Bonne source de référence, mais **LibCrafts est préférable**.                                                                                          |
| **WowDbScripts**                 |                  Python scrapers + sortie Lua | Génère des informations de recettes de métiers, spells et items ; peut sortir des valeurs Python en Lua. ([GitHub][5])                                                                            | Supporte les versions `1,2,3,4,5,10`, avec `recipes_scraper.py -v 1` pour Classic. ([GitHub][5])                                                 | **BSD-2-Clause**. ([GitHub][5])                                                                           | Excellent pour créer ton propre pipeline reproductible, mais dépend de Wago DB2 et Wowhead.                                                            |
| **nexus-devs/wow-classic-items** |                            JSON + package npm | Items, propriétés, icons, tooltips, crafting, sources, professions, zones, classes. ([GitHub][6])                                                                                                 | Vanilla/TBC/WotLK Classic ; dernière release trouvée WotLK 1.0.1 en novembre 2022. ([GitHub][6])                                                 | **MIT**. ([GitHub][6])                                                                                    | Très utile pour les **items** ; insuffisant seul pour une DB complète de recettes avec seuils de couleur.                                              |
| **TradeSkillInfo**               | Lua tables (`Data.lua`, `TradeskillData.lua`) | Add-on “Complete tradeskill information”, tooltip sources, browser de recettes, difficulté de skill sous forme `40/60/80/120`. ([GitHub][7])                                                      | Dernière release GitHub v2.4.4 en octobre 2019 ; pas une source Classic Era 1.15.x fraîche. ([GitHub][7])                                        | CurseForge indique **All Rights Reserved**. ([curseforge.com][8])                                         | Très instructif pour le modèle de données ; pas idéal à copier.                                                                                        |
| **ReagentData**                  |           Lua, dont fichier `engineering.lua` | Bibliothèque Vanilla 1.12.1 de reagents de métiers, API + accès direct aux tableaux. ([GitHub][9])                                                                                                | Repo archivé en mars 2025 ; source Vanilla. ([GitHub][10])                                                                                       | Licence pas clairement vérifiée dans les extraits ; prudence.                                             | Utile comme source secondaire pour reagents, pas suffisante pour `skillRange` et sources.                                                              |
| **AtlasLootClassic**             |                                  Lua addon DB | AtlasLootClassic expose des tables de loot et un module crafting avec matériaux, objets créés et skill ranks. ([Legacy WoW][11])                                                                  | Version Classic 1.15.2 repérée sur Legacy WoW. ([Legacy WoW][11])                                                                                | Certaines variantes/forks sont GPLv2, mais il faut vérifier le fork exact utilisé. ([curseforge.com][12]) | Bon candidat à inspecter pour confirmer craft/material/skill ranks ; moins orienté coût récursif.                                                      |
| **AllTheThings**                 |                        Lua addon DB modulaire | Gros addon de collection tracking avec modules DB pour éviter les appels API Blizzard. ([GitHub][13])                                                                                             | Releases régulières annoncées ; dernière release vue 5.1.9 du 7 juin 2026. ([GitHub][14])                                                        | Licence à vérifier dans le repo.                                                                          | Peut contenir sources/collections/recipes, mais probablement trop massif pour CraftGold.                                                               |
| **Auctionator**                  |                                     Lua addon | Calcule prix, coûts de reagents et profits dans les vues de craft, mais ce n’est pas une DB statique complète de recettes. ([GitHub][15])                                                         | Maintenu comme addon AH.                                                                                                                         | Licence à vérifier par version.                                                                           | Utile pour inspiration UI/prix, **pas pour seed de recettes**.                                                                                         |
| **WoW-Pro Guides**               |                                    Lua guides | Addon de guides de leveling/questing, pas une DB normalisée de recettes Engineering. ([curseforge.com][16])                                                                                       | Mis à jour le 13 mai 2026 sur CurseForge ; support Classic. ([curseforge.com][16])                                                               | CC BY-NC 3.0 sur CurseForge. ([curseforge.com][16])                                                       | Pas adapté à CraftGold DB.                                                                                                                             |
| **WoWProfessionOptimizer**       |                                  Lua + Python | Addon Classic qui optimise le leveling métier avec données TSM et brute force. ([GitHub][17])                                                                                                     | Pas de release publiée sur GitHub au moment de la recherche. ([GitHub][17])                                                                      | GPL-3.0. ([GitHub][17])                                                                                   | Intéressant pour l’algorithme, mais la réutilisation GPL peut contaminer CraftGold.                                                                    |
| **Recipe Master**                |             Lua addon, DB extraite de Wowhead | Catalogue complet de recettes via DB intégrée extraite de Wowhead, sources, tri par skill requis. ([GitHub][18])                                                                                  | Dernière release GitHub 2.13.0, 9 mars 2026. ([GitHub][18])                                                                                      | Licence à lire précisément dans `LICENSE.txt`.                                                            | Très intéressant à inspecter, surtout le dossier `Vanilla/`, mais vérifier licence + qualité Classic Era.                                              |
| **Gethe/wow-ui-source**          |                  Lua/XML UI Blizzard exportée | Miroir du code UI Blizzard, pas une base de données items/recettes. ([GitHub][19])                                                                                                                | Repo actif, miroir du dernier code UI. ([GitHub][19])                                                                                            | Repo GitHub sans garantie de licence réutilisable des données.                                            | Utile pour comprendre API/UI professions, **pas pour les recettes statiques**.                                                                         |

---

## 2. APIs publiques

### Blizzard Battle.net / World of Warcraft Classic Game Data API

La Blizzard API Classic existe pour récupérer certaines données de jeu en JSON ; Blizzard a annoncé l’ouverture d’APIs Classic en 1.14.4 pour permettre à des sites/outils tiers d’accéder à des informations in-game. ([Blizzard Forums][20])

Base typique :

```text
https://{region}.api.blizzard.com
```

Exemples utiles à tester :

```text
GET /data/wow/item/{itemId}?namespace=static-classic1x-eu&locale=fr_FR
GET /data/wow/media/item/{itemId}?namespace=static-classic1x-eu&locale=fr_FR
GET /data/wow/search/item?namespace=static-classic1x-eu&locale=fr_FR&name.fr_FR=...
```

Les namespaces Classic Era modernes à tester sont du type `static-classic1x-{region}` ; Blizzard a aussi documenté des cas où il faut utiliser un namespace build-spécifique si l’alias n’est pas à jour. ([Blizzard Forums][21])

Pour les **items**, l’API est utile : un fil Blizzard mentionne explicitement `/data/wow/item/{itemId}` pour Classic. ([Blizzard Forums][22])

Pour les **recettes/professions**, prudence : les endpoints `/data/wow/profession/...` et `/data/wow/recipe/{id}` existent côté WoW Game Data API retail, mais la disponibilité/complétude Classic a été historiquement irrégulière. Un fil Blizzard de 2023 listait plusieurs endpoints Classic non fonctionnels, donc je ne baserais pas CraftGold uniquement dessus. ([Blizzard Forums][23])

Clé API : oui, via Battle.net developer client credentials. Rate limit officiel : 36 000 appels/heure, avec possibilité de suspension si dépassement. ([blizzard.com][24])

### Wowhead

Wowhead n’offre pas une API publique officielle propre pour récupérer des recettes structurées ; des projets comme `wow-recipe-list-to-json` ou d’anciennes libs “Wowhead API” font du scraping HTML/XML, ce qui est fragile. ([GitHub][25])

Wowhead fournit en revanche un script de tooltips qui supporte les entités comme items/spells/recipes et des domaines Classic, utile pour affichage/lien, pas pour construire proprement une DB offline. ([Wowhead][26])

Pour CraftGold, Wowhead doit rester une **source de validation ponctuelle**, pas la source primaire automatisée.

### Warcraft Wiki / wiki.gg

Warcraft Wiki documente surtout l’API Lua in-game et indique que l’API WoW est documentée dans `Blizzard_APIDocumentation`, accessible via `/api`. ([warcraft.wiki.gg][27])

Pour les recettes, Warcraft Wiki est utile comme référence humaine, mais je n’ai pas trouvé de source suffisamment fiable indiquant une API REST/Cargo normalisée qui retourne directement : métier → recettes → reagents → skill colors. Je ne le recommanderais donc pas comme source principale de DB CraftGold.

### Wago.tools / DB2

Wago.tools n’est pas une API métier haut niveau, mais des projets comme WowDbScripts l’utilisent comme source DB2 pour générer des informations de recettes, spells et items. ([GitHub][5])

Le projet `wow.tools.local` permet de consulter localement des données façon wow.tools à partir d’une installation WoW, sans dépendre du site principal après téléchargement des dépendances. ([GitHub][28])

---

## 3. Dumps et datasets

### DB2 / DBC du client WoW

Les données client DB2/DBC sont la source la plus “proche du jeu”, mais elles demandent un pipeline d’extraction. CraftLib indique explicitement utiliser notamment `Spell`, `SpellName`, `SpellEffect`, `SpellReagents`, `Item`, `ItemSparse`, `SkillLine`, `SkillLineAbility`, `ItemEffect` et `Faction`, avec vérification Wowhead. ([GitHub][1])

Cela signifie que les DB2 peuvent fournir une partie essentielle : spell/recipe IDs, reagents, item IDs, skill lines. En revanche, les **sources d’obtention** précises — trainer/vendor/drop/quest — sont souvent plus difficiles à reconstruire uniquement depuis les DB2 client et nécessitent des tables complémentaires ou une validation Wowhead/addon. ([GitHub][1])

Outils utiles :

* **WowDbScripts** : scrapers Python pour Wago DB2 + Wowhead, capables de générer des informations de recettes/spells/items et de sortir en Lua. ([GitHub][5])
* **wow.tools.local** : version locale/slim de wow.tools, avec support Classic et accès DB2 local via navigateur. ([GitHub][28])
* **WoWDBDefs** : définitions de colonnes/champs pour fichiers DB WoW, mises à jour pour les builds modernes. ([GitHub][29])
* **DBCD** : bibliothèque C# MIT pour lire DBC/DB2 avec WoWDBDefs. ([GitHub][30])
* **DBC2CSV** : convertisseur DB2/DBC vers CSV, mais il ne télécharge pas les DB2 lui-même et ses contraintes de versions doivent être vérifiées pour Classic Era. ([GitHub][31])

Un point important : une issue SimpleArmory indique que wow.tools a été considéré comme discontinué / moins fiable comme source d’export CSV, et recommande de générer soi-même les CSV depuis les game data via DBC2CSV + listfile dump. ([GitHub][32])

### Datasets JSON / SQL

`nexus-devs/wow-classic-items` fournit des JSON/NPM exploitables pour items, icons, tooltips, sources et professions, sous MIT. C’est bien pour enrichir les noms/icônes/qualité, mais pas suffisant comme source unique de recettes Engineering avec seuils orange/yellow/green/gray. ([GitHub][6])

`classic-wow-item-db` fournit une base MySQL d’items Classic issue d’une base Light’s Hope privée ; c’est une source d’appoint pour item metadata, mais pas une source fiable de recettes Classic Era officielles. ([GitHub][33])

### Dumps wiki

Des dumps MediaWiki peuvent exister côté wiki.gg/Warcraft Wiki, mais les pages wiki ne sont pas une base relationnelle normalisée de recettes. Pour CraftGold, cela implique trop de parsing fragile par rapport aux alternatives Lua/DB2 déjà structurées.

---

## 4. Add-ons existants comme source

### Meilleurs candidats

1. **CraftLib** — meilleure structure, couverture Classic Era, Engineering complet, source/difficulty/reagents. Le blocage est la licence All Rights Reserved. ([GitHub][1])

2. **LibCrafts-1.0** — meilleur candidat open-source réutilisable : MIT, Lua, embeddable, Vanilla 1.12.1, mapping complet spells/recipes/reagents/results/sources. ([GitHub][2])

3. **TradeSkillsData** — DB Vanilla de trade skill recipes/vendors/sources, mais archivée et remplacée conceptuellement par LibCrafts. ([GitHub][4])

4. **AtlasLootClassic** — contient du crafting avec matériaux, created items et skill ranks ; utile pour croiser les informations, moins directement orienté API de coûts récursifs. ([Legacy WoW][11])

5. **Recipe Master** — annonce une DB intégrée extraite de Wowhead avec catalogue complet, sources et tri par skill requis ; intéressant à auditer, mais licence et exactitude Classic Era à vérifier avant réutilisation. ([GitHub][18])

### Add-ons utiles mais non-jackpot

* **Auctionator** : bon exemple de calcul coût/profit basé AH et reagents, mais pas une DB statique complète. ([GitHub][15])
* **Skillet-Classic** : excellent exemple d’UI/crafting queue/shopping list, mais plutôt dynamique qu’une DB statique exhaustive. ([GitHub][34])
* **Sigma Profession Filter** : filtre les recettes visibles par nom/reagent/difficulté ; utile pour UX, pas comme source primaire. ([GitHub][35])
* **Reagent Recipes Classic** : affiche recettes, quantités et difficulté dans les tooltips, mais demande l’ouverture des fenêtres de métier pour mettre en cache les recettes ; licence All Rights Reserved. ([curseforge.com][36])

---

## 5. ItemIDs Classic Era vs Vanilla

Pour les recettes Vanilla classiques, les **itemIDs historiques sont généralement conservés** dans Classic / Classic Era : les bases Wowhead Classic, les datasets Vanilla/Classic et les add-ons Vanilla réutilisent les mêmes IDs numériques pour les objets historiques. Par exemple, LibCrafts montre des exemples de liens Wowhead Classic basés sur des itemIDs Vanilla comme `2318` ou `4408`. ([GitHub][2])

Mais je n’ai pas trouvé de document officiel Blizzard disant “tous les itemIDs Vanilla 1.12 sont identiques en Classic Era 1.15.x”. Il faut donc traiter cela comme une règle pratique très fiable pour les anciens objets, pas comme une garantie formelle. Blizzard API discussions rappellent aussi que Classic n’est pas strictement “100% Vanilla” et que certains objets saisonniers/promotionnels peuvent avoir des IDs plus élevés ou des données différentes. ([Blizzard Forums][37])

Pour CraftGold Engineering 1–150, le risque est faible : les recettes de base comme Rough Blasting Powder, Handful of Copper Bolts, Rough Dynamite, Copper Modulator, etc. appartiennent au corpus Vanilla historique. Mais je validerais quand même chaque entrée finale contre au moins une source Classic Era actuelle : Wowhead Classic “up to date” pour 1.15.x, Blizzard `/data/wow/item/{itemId}` en namespace `static-classic1x-eu`, ou CraftLib comme oracle de comparaison non copié. ([Wowhead][38])

---

## Recommandation finale pour CraftGold

Pour 15–20 recettes Engineering Classic Era 1–150, je ferais ceci :

1. **Source primaire réutilisable** : extraire depuis **LibCrafts-1.0** les recettes Engineering nécessaires, car c’est Lua, MIT, embeddable et déjà structuré autour de spell/recipe/reagent/result/source. ([GitHub][2])
2. **Validation technique** : comparer avec **WowDbScripts** ou DB2 `SpellReagents` / `SkillLineAbility` pour confirmer `spellId`, reagents et skill line. ([GitHub][5])
3. **Validation Classic Era 1.15.x** : vérifier les output itemIDs/noms via Blizzard API Classic ou Wowhead Classic. ([Blizzard Forums][20])
4. **Ne pas copier CraftLib sans permission**, mais l’utiliser comme benchmark de structure : son modèle de recette est quasiment parfait pour CraftGold. ([GitHub][39])

Structure cible CraftGold possible :

```lua
CraftGoldDB = CraftGoldDB or {}

CraftGoldDB.Engineering = {
  {
    spellId = 3918,
    output = { itemId = 4357, name = "Rough Blasting Powder", count = 1 },
    reagents = {
      { itemId = 2835, name = "Rough Stone", count = 1 },
    },
    skill = {
      learn = 1,
      orange = 1,
      yellow = 20,
      green = 30,
      gray = 40,
    },
    source = {
      type = "trainer",
    },
  },
}
```

Conclusion nette : **LibCrafts-1.0 + validation DB2/Wowhead/Blizzard** est le meilleur chemin pour CraftGold. **CraftLib** est le meilleur modèle de données, mais sa licence impose de ne pas l’embarquer directement sans accord.

[1]: https://github.com/kaldown/CraftLib "GitHub - kaldown/CraftLib: WoW addon library providing profession recipe data with skill-up difficulty ranges · GitHub"
[2]: https://github.com/refaim/LibCrafts-1.0 "GitHub - refaim/LibCrafts-1.0: Vanilla WoW 1.12.1 addon library designed to provide an embeddable database of crafting spells, recipes, reagents, results, sources etc · GitHub"
[3]: https://github.com/kaldown/CraftLib/blob/main/LICENSE "CraftLib/LICENSE at main · kaldown/CraftLib · GitHub"
[4]: https://github.com/refaim/TradeSkillsData "GitHub - refaim/TradeSkillsData: Vanilla WoW 1.12.1 addon. Provides database of trade skill recipes, vendors and sources. · GitHub"
[5]: https://github.com/thespags/WowDbScripts "GitHub - thespags/WowDbScripts: Scrapers for https://wago.tools/db2/ and https://www.wowhead.com/ · GitHub"
[6]: https://github.com/nexus-devs/wow-classic-items "GitHub - nexus-devs/wow-classic-items: Collection of all WoW Vanilla, TBC and WotLK Classic items, professions, zones and classes · GitHub"
[7]: https://github.com/Ravendwyr/TradeSkillInfo "GitHub - Ravendwyr/TradeSkillInfo: WoW Addon - Complete tradeskill information. · GitHub"
[8]: https://www.curseforge.com/wow/addons/tradeskill-info/files/871795?utm_source=chatgpt.com "TradeSkillInfo - v2.3.6 - World of Warcraft Addons"
[9]: https://github.com/refaim/ReagentData?utm_source=chatgpt.com "refaim/ReagentData: Vanilla WoW 1.12.1 addon. A ..."
[10]: https://github.com/refaim/ReagentData/blob/master/engineering.lua "ReagentData/engineering.lua at master · refaim/ReagentData · GitHub"
[11]: https://legacy-wow.com/classic-addons/atlaslootclassic/ "AtlasLootClassic"
[12]: https://www.curseforge.com/wow/addons/atlaslootclassic-for-20th-anniversary-fresh/files/6604321?utm_source=chatgpt.com "AtlasLootClassic for 20th anniversary fresh - Addons"
[13]: https://github.com/ATTWoWAddon/AllTheThings "GitHub - ATTWoWAddon/AllTheThings: ALL THE THINGS - Addon for Tracking Collections & Account Completion in World of Warcraft · GitHub"
[14]: https://github.com/DFortun81/AllTheThings/releases?utm_source=chatgpt.com "Releases · ATTWoWAddon/AllTheThings"
[15]: https://github.com/TheMouseNest/Auctionator "GitHub - TheMouseNest/Auctionator: The Auctionator addon for World of Warcraft. · GitHub"
[16]: https://www.curseforge.com/wow/addons/wow-pro "WoW-Pro Guides - World of Warcraft Addons - CurseForge"
[17]: https://github.com/KevinTyrrell/WoWProfessionOptimizer "GitHub - KevinTyrrell/WoWProfessionOptimizer: World of Warcraft: Classic Addon that optimizes profession leveling using TradeSkillMaster price data and an efficient brute force algorithm. · GitHub"
[18]: https://github.com/BrenoLudgero/Recipe_Master "GitHub - BrenoLudgero/Recipe_Master: The ultimate recipe tracking add-on for World of Warcraft · GitHub"
[19]: https://github.com/Gethe/wow-ui-source "GitHub - Gethe/wow-ui-source: git mirror of the user interface source code for World of Warcraft · GitHub"
[20]: https://eu.forums.blizzard.com/en/wow/t/new-apis-now-available-for-testing/461426?utm_source=chatgpt.com "New APIs Now Available for Testing - WoW Classic Hardcore"
[21]: https://us.forums.blizzard.com/en/blizzard/t/wow-classic-datawowitemitemid-results-in/56949?utm_source=chatgpt.com "WoW Classic: /data/wow/item/{itemId} results in"
[22]: https://us.forums.blizzard.com/en/blizzard/t/wow-classic-item-stats/16515?utm_source=chatgpt.com "WoW Classic Item Stats - API Discussion"
[23]: https://us.forums.blizzard.com/en/blizzard/t/how-to-locate-recipe-ids/7129?utm_source=chatgpt.com "How to locate Recipe IDs - API Discussion"
[24]: https://www.blizzard.com/legal/a2989b50-5f16-43b1-abec-2ae17cc09dd6/blizzard-developer-api-terms-of-use?utm_source=chatgpt.com "Blizzard Developer Api Terms Of Use - Legal"
[25]: https://github.com/ArekusuNaito/wow-recipe-list-to-json "GitHub - ArekusuNaito/wow-recipe-list-to-json: A system that by scraping the html code from Wowhead and using the official Blizzard WoW API can give you a recipe list and the list of every item used in the recipes. · GitHub"
[26]: https://www.wowhead.com/tooltips?utm_source=chatgpt.com "Tooltips"
[27]: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API?utm_source=chatgpt.com "World of Warcraft API"
[28]: https://github.com/Marlamin/wow.tools.local/blob/main/README.md "wow.tools.local/README.md at main · Marlamin/wow.tools.local · GitHub"
[29]: https://github.com/wowdev/WoWDBDefs "GitHub - wowdev/WoWDBDefs: Client database definitions for World of Warcraft · GitHub"
[30]: https://github.com/wowdev/DBCD "GitHub - wowdev/DBCD: C# library for reading DBC/DB2 database files from World of Warcraft · GitHub"
[31]: https://github.com/Marlamin/DBC2CSV "GitHub - Marlamin/DBC2CSV: DBC/DB2 to CSV converter · GitHub"
[32]: https://github.com/kevinclement/SimpleArmory/issues/474?utm_source=chatgpt.com "Alternative to wow.tools for sourcing data · Issue #474"
[33]: https://github.com/thatsmybis/classic-wow-item-db?utm_source=chatgpt.com "thatsmybis/classic-wow-item-db: A MySQL database of the ..."
[34]: https://github.com/b-morgan/Skillet-Classic "GitHub - b-morgan/Skillet-Classic: World of Warcraft Classic addon · GitHub"
[35]: https://github.com/Sigma88/Sigma-ProfessionFilter?utm_source=chatgpt.com "Sigma Profession Filter (Classic)"
[36]: https://www.curseforge.com/wow/addons/reagent-recipes-classic "Reagent Recipes Classic - World of Warcraft Addons - CurseForge"
[37]: https://us.forums.blizzard.com/en/blizzard/t/classic-wow-api-not-returning-item-stats/15884?utm_source=chatgpt.com "Classic Wow API Not returning Item Stats"
[38]: https://www.wowhead.com/classic/items/recipes?utm_source=chatgpt.com "Classic Recipes - Classic World of Warcraft"
[39]: https://github.com/kaldown/CraftLib/blob/main/SCHEMA.md "CraftLib/SCHEMA.md at main · kaldown/CraftLib · GitHub"
