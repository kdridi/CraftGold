Voilà les résultats de recherche complets. Voici la synthèse structurée :

---

# Recherche — Sources de données recettes Engineering (WoW Classic Era)

## 1. Bases de données open source WoW Classic

### 🏆 CraftLib — **La trouvaille jackpot**

- **Lien** : https://github.com/kaldown/CraftLib · https://www.curseforge.com/wow/addons/craftlib
- **Format** : Tables Lua générées automatiquement depuis DB2 (wago.tools) + Wowhead
- **Couverture** : Recettes complètes avec SpellID, itemID produit, reagents + quantités, skill level min, couleurs de difficulté (orange/yellow/green/gray). Source de chaque recette (TRAINER, VENDOR, DROP, QUEST, REPUTATION).
- **Version** : Supporte Classic Era (1.15.x) et Classic TBC (2.5.x), avec des packages séparés par flavour. DB2 Tables utilisées : Spell, SpellName, SpellEffect, SpellReagents, Item, ItemSparse, SkillLine, SkillLineAbility, ItemEffect, Faction.
- **API Lua** :
```lua
local recipes = CraftLib:GetRecipes("engineering")
local recipe  = CraftLib:GetRecipeBySpellId("engineering", 3928)
local recipe  = CraftLib:GetRecipeByItemId(4357)
local diff    = CraftLib:GetRecipeDifficulty(recipe, 150)
```
- **Licence** : All Rights Reserved (CurseForge) — mais le code source est sur GitHub public. À vérifier avant réutilisation directe dans CraftGold, mais les données Lua sont lisibles et la structure est parfaitement réutilisable comme *référence* pour construire votre propre DB.
- **Maintenance** : Très actif — dernière release v0.5.0 en février 2026, 9 500+ téléchargements.
- **Pipeline de données** : Scripts Python pour extraire depuis DB2 (`extract_db2_sources.py`) et depuis Wowhead (`fetch_wowhead_sources.py`). Le repo associé `kaldown/db2-parser` expose exactement ce pipeline.

**Verdict : c'est votre meilleure source directe.** Les fichiers Lua générés contiennent exactement ce dont vous avez besoin pour les 15–20 recettes Engineering niveau 1–150.

---

### refaim/TradeSkillsData

- **Lien** : https://github.com/refaim/TradeSkillsData
- **Format** : Tables Lua
- **Couverture** : Base de données de recettes de trade skills pour Vanilla 1.12.1, avec vendors et sources.
- **Version** : Vanilla 1.12.1 — itemIDs identiques à Classic Era (voir section 5)
- **Licence** : Open source GitHub, licence à vérifier dans le repo
- **Maintenance** : Peu d'activité récente, mais les données Vanilla sont stables

---

### refaim/MissingTradeSkillsList

- **Lien** : https://github.com/refaim/MissingTradeSkillsList
- **Format** : Tables Lua
- **Couverture** : Liste complète de tous les skills et recettes avec données correctes pour Engineering, Alchemy, Blacksmithing, Cooking, Enchanting, et tous les autres métiers. Inclut les sources (où obtenir chaque recette).
- **Version** : Vanilla 1.12.1 + Turtle WoW
- **Maintenance** : Actif (Turtle WoW est un serveur privé vanilla maintenu)

---

### refaim/ReagentData

- **Lien** : https://github.com/refaim/ReagentData
- **Format** : Tables Lua (structure par catégorie d'items, pas par itemID)
- **Couverture** : Ensemble complet de tous les reagents et composants utilisés par les trade skills. Inclut `spellreagents` (multi-dimensionnel par classe de sort) et des tables par catégorie (vendor, monster drops, etc.).
- **Limite** : Les items sont référencés par *nom localisé*, pas par itemID — nécessite un mapping supplémentaire.
- **Version** : Vanilla 1.12.1
- **Maintenance** : Archivé, mais données stables

---

### nexus-devs/wow-classic-items

- **Lien** : https://github.com/nexus-devs/wow-classic-items
- **Format** : JSON + Node.js
- **Couverture** : Collection de tous les items WoW Vanilla, TBC et WotLK Classic, avec professions, zones et classes. Scrappe Wowhead et l'API Blizzard officielle. La DB des professions est "faite à la main" (`handmade`).
- **Limitation** : La DB professions est manuelle et probablement incomplète/non maintenue pour les reagents détaillés.
- **Licence** : Open source
- **Maintenance** : Peu active (dernier commit 2021–2022)

---

### dkpminus/Classic-Wow-Database

- **Lien** : https://github.com/dkpminus/Classic-Wow-Database
- **Format** : SQL (MySQL, moteur DBSimple)
- **Couverture** : Base de données open source pour le patch 1.12.1, port du projet aowow (WoW v3.3.5). Contient items, NPCs, quêtes — structure orientée serveur web.
- **Version** : 1.12.1
- **Utilité pour CraftGold** : Utile pour lookups d'itemIDs/noms via SQL, moins pratique pour extraction directe de recettes.

---

### Ravendwyr/TradeSkillInfo

- **Lien** : https://github.com/Ravendwyr/TradeSkillInfo
- **Format** : Lua (`Data.lua` généré par dataminer Java)
- **Couverture** : Informations complètes sur les trade skills, incluant les niveaux de skill auxquels une recette change de couleur de difficulté (ex : "40/60/80/120").
- **Dataminer** : Outil Java (`TradeSkillInfo_DataMiner`) qui scrape Wowhead et WoWDB pour générer le fichier `Data.lua`.
- **Limite** : TradeSkillInfo n'est pas compatible WoW Classic — conçu pour Retail. Les données restent réutilisables comme référence.

---

## 2. APIs publiques

### Blizzard Battle.net API (officielle)

- **Base URL** : `https://{region}.api.blizzard.com`
- **Namespace Classic Era** : `static-classic-{region}` (ex : `static-classic-us`)
- **Documentation** : https://community.developer.battle.net/documentation/world-of-warcraft-classic/game-data-apis
- **Auth** : OAuth2 client credentials (clé API gratuite via https://develop.battle.net)
- **Endpoints pertinents** :
  - Item par ID : `GET /data/wow/item/{itemId}?namespace=static-classic-us`
  - Item media (icône) : `GET /data/wow/media/item/{itemId}?namespace=static-classic-us`
- **Limite** : Les endpoints Classic couvrent les données statiques et dynamiques, mais les endpoints de professions/recettes sont très limités côté Game Data API. Il n'existe **pas** d'endpoint `GET /profession/{id}/recipes` avec reagents pour Classic Era — l'API Blizzard pour les recettes détaillées est quasi-inexistante pour Classic.
- **Rate limits** : 100 req/s, 36 000 req/h (standard Battle.net)
- **Utilité** : Bon pour résoudre `itemID → nom + icône`. Pas utilisable pour les recettes complètes.

---

### Wowhead (scraping/toolhead)

- **URL** : `https://www.wowhead.com/classic/spell={spellID}`
- **API JSON cachée** : `https://www.wowhead.com/classic/spell={spellID}&json` (non documentée, fragile)
- **Pas d'API officielle REST publique.** Wowhead propose le *Wowhead Looter* (addon client), pas une API serveur.
- **Alternative** : Le projet `kaldown/db2-parser` (https://github.com/kaldown/db2-parser) automatise la récupération depuis wago.tools et Wowhead via Python — c'est la voie la plus propre.

---

### warcraft.wiki.gg

- Le wiki n'expose pas d'API de données de jeu structurées. C'est une source de documentation, pas de données machine-readable pour les recettes.

---

## 3. Dumps et datasets

### Fichiers DBC (DataBaseClient)

Les DBC sont les bases de données client-side de WoW. Pour Vanilla/Classic Era :

- **Spell.dbc** : Contient les champs `reagent_1` à `reagent_8` (itemIDs) et `reagent_count_1` à `reagent_count_8` — c'est exactement les composants de chaque recette/sort.
- **SkillLineAbility.dbc** : Relie les spellIDs aux skill lines (Engineering = 202) et contient les skill levels requis.
- **Item.dbc** / **ItemSparse** : Noms et métadonnées des items.
- **Structure DBC** : Documentée sur https://wowdev.wiki/DBC et https://wowdev.wiki/DB/Spell

**Outils pour parser les DBC Vanilla :**
- `gtker/wow_dbc` (Rust) : https://github.com/gtker/wow_dbc — Librairie Rust pour lire/écrire les DBC WoW 1.12, 2.4.3 et 3.3.5. Inclut `wow_dbc_converter` pour convertir en SQLite.
- `stoneharry/WoW-Spell-Editor` : https://github.com/stoneharry/WoW-Spell-Editor — importe Spell.dbc vers MySQL, permet l'export SQL.

**Comment obtenir les DBC Vanilla :** Les fichiers `.dbc` sont dans les MPQ du client WoW 1.12.1 (que vous avez si vous jouez sur Classic Era). Ils peuvent être extraits avec des outils comme *MPQ Editor* ou *Ladik's MPQ Editor*.

---

### wago.tools (successeur de wow.tools)

- **URL** : https://wago.tools/
- Wago.io a lancé wago.tools comme remplacement de WoW.tools. L'ancien wow.tools a été retiré en mai 2025.
- Wago.tools permet de browser les fichiers DB2 des builds récents, mais la couverture des builds Vanilla/Classic Era via l'interface web est limitée.
- Le projet `kaldown/db2-parser` (https://github.com/kaldown/db2-parser) utilise wago.tools en backend pour extraire les tables DB2 — c'est l'approche recommandée.

---

### wow.tools.local

- **Lien** : https://github.com/Marlamin/wow.tools.local
- Version locale installable de wow.tools, maintenue activement. Permet de browser les DBC/DB2 de n'importe quel build WoW, y compris Classic Era.

---

## 4. Add-ons existants comme source directe

### 🥇 CraftLib (kaldown) — **Recommandé #1**

Voir section 1. Le fichier `Data/Era/engineering.lua` (ou équivalent dans le repo) contient directement les données structurées pour Classic Era 1.15.x. C'est la source la plus fraîche, la mieux maintenue, et conçue exactement pour l'usage add-on.

### 🥈 refaim/MissingTradeSkillsList — **Recommandé #2**

Données Lua directement utilisables pour Vanilla, couvrant Engineering complet avec sources. Approche plus simple si CraftLib est trop récent ou si la licence pose problème.

### LazyProf (kaldown)

- **CurseForge** : https://www.curseforge.com/wow/addons/lazyprof
- Add-on de leveling optimizer qui utilise CraftLib comme dépendance — Calculate the cheapest path to level your professions. Works with TSM and Auctionator for real prices. Pas une source de données en soi, mais confirme que CraftLib est production-ready.

### AtlasLoot / AtlasLootClassic

- Contient des données de loot et de craft, mais orienté *loot de boss*, pas leveling de profession. Pas le meilleur choix pour une DB Engineering 1–150.

### Auctionator

- Aucune DB de recettes embarquée. C'est un addon AH, pas une source de données de craft.

---

## 5. ItemIDs Classic Era vs Vanilla 1.12

**Réponse courte : oui, les itemIDs sont identiques.**

WoW Classic utilise la version 1.12 comme référence. Les stats des items existants sont fixées à leur version finale de patch 1.12. Les itemIDs eux-mêmes (identifiants numériques) n'ont pas changé entre Vanilla 1.12 et Classic Era 1.15.x pour les items existants — Classic Era est une continuation du même client avec les mêmes IDs.

**Nuances importantes :**
- Les items *ajoutés* par Blizzard dans Classic Era (ex : récompenses de quêtes SoD, items de saisons) ont des IDs nouveaux qui n'existaient pas en Vanilla 1.12.
- Pour les recettes Engineering niveau 1–150 (items basiques comme Copper Bolts, Rough Blasting Powder, Rough Copper Bomb, etc.), les itemIDs sont **strictement identiques** à ceux de 1.12. N'importe quelle source Vanilla fiable est donc valide pour Classic Era.
- Wowhead Classic (https://www.wowhead.com/classic/) utilise ces mêmes IDs dans ses URLs (`item=4357` = Handful of Copper Bolts sur les deux).

**Pas de mapping nécessaire** pour les items craftés de base. Si vous trouviez un cas isolé d'ID différent, wowhead.com/classic serait la référence de vérification.

---

## Recommandation finale : pipeline suggéré pour CraftGold

```
1. Récupérer CraftLib (GitHub kaldown/CraftLib)
   → Ouvrir Data/Era/ (ou l'équivalent Classic)
   → Extraire les entrées Engineering dans le .lua généré
   → Vous avez : spellID, outputItemID, reagents[], skillLevel, couleurs, source

2. Pour les noms d'items :
   → Blizzard API : GET /data/wow/item/{itemId}?namespace=static-classic-us
   → Ou wowhead.com/classic/item={itemId}&json (non officiel mais fonctionnel)

3. Pour vérification :
   → Croiser avec refaim/MissingTradeSkillsList (Lua vanilla)
   → Ou wowhead.com/classic/items/recipes/engineering pour validation manuelle
```

Le projet `kaldown/CraftLib` + son pipeline `db2-parser` est à ce jour la source la plus complète, la plus récente (actif en 2026), et conçue spécifiquement pour le cas d'usage add-on Classic Era 1.15.x.