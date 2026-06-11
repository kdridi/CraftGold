Voici les résultats de la recherche concernant les sources de données structurées pour les recettes d'Ingénierie de WoW Classic Era, afin d'alimenter votre add-on **CraftGold**.

### 1. Bases de données open source WoW Classic

Voici plusieurs projets pertinents hébergeant des données brutes exploitables pour votre besoin :

* **LibTradeSkillRecipes**
* **Lien** : [GitHub - thespags/LibTradeSkillRecipes](https://github.com/thespags/LibTradeSkillRecipes)
* **Format** : Tables Lua (conçues pour être intégrées en tant que librairie d'add-on).
* **Couverture** : Lie les `recipeId` à la création du `spellId`, au résultat `itemId`, et aux `craftingDataId` (composants).
* **Licence** : Open Source (souvent MIT ou GPL selon les forks, vérifiable dans les sources).
* **Utilité** : C'est exactement le mapping de recettes/sorts qu'il vous faut pour un add-on de craft.


* **wow-classic-items**
* **Lien** : [NPM - wow-classic-items](https://www.google.com/search?q=https://www.npmjs.com/package/wow-classic-items)
* **Format** : Fichiers JSON.
* **Couverture** : Projet Node.js générant une vaste DB (scrappée via Wowhead et l'API Blizzard). Il inclut une classe `Database.Professions` et `Database.Items` avec prix de revente, qualité, niveaux requis, composants.
* **Version** : Adapté à WoW Classic.
* **Licence** : Open source (MIT en général pour les packages npm de ce type).


* **AtlasLootClassic**
* **Lien** : [GitHub - Hoizame/AtlasLootClassic](https://github.com/Hoizame/AtlasLootClassic)
* **Format** : Tables Lua brutes (`AtlasLootClassic_Crafting`).
* **Couverture** : Contient un module spécifique pour le Crafting avec les ID des matériaux, l'item créé, et les niveaux de compétence (`skill ranks` / color difficulty).
* **Version** : Maintenu pour Classic Era / SoD.



### 2. APIs publiques

L'API de référence est la **Blizzard Battle.net Game Data API**. Il n'y a pas d'API communautaire "gratuite et illimitée" aussi fiable que la source officielle.

* **URL de base** : `https://eu.api.blizzard.com/data/wow/` (ou `us.api.blizzard.com`)
* **Endpoints pertinents** :
* Items : `/data/wow/item/{itemId}` (Renvoie le nom, l'icône, la qualité).
* Recettes : `/data/wow/recipe/{recipeId}` (Renvoie les `reagents` avec leurs items associés et quantités, ainsi que l'item fabriqué).
* Professions : `/data/wow/profession/{professionId}/skill-tier/{skillTierId}`


* **Namespaces** : Pour interroger les serveurs Classic Era, vous devez ajouter le paramètre de requête `?namespace=static-classic-eu` (ou `us`).
* **Rate limits** : L'API permet 36 000 requêtes par heure par client.
* **Clé API** : **Oui**, nécessite la création gratuite d'un client sur le [Portail Développeur Battle.net](https://develop.battle.net/) pour obtenir un `access_token` (via OAuth2 / Client Credentials).

### 3. Dumps et datasets

Si vous préférez travailler depuis la base de données brute du client WoW plutôt que l'API :

* **wow.tools.local / Wago Tools** :
* **Lien** : [GitHub - Marlamin/wow.tools.local](https://github.com/Marlamin/wow.tools.local) / [Wago.tools](https://wago.tools/)
* **Principe** : L'ancien site wow.tools a été fermé, mais le projet open source a été repris via l'application locale de *Marlamin* ou l'outil web de *Wago*.
* **Exploitation** : Vous pouvez y extraire au format CSV ou JSON les fameux fichiers **DBC (DataBaseClient)** ou **DB2** de la version `1.15.x`.
* **Fichiers DBC intéressants** :
* `Spell.dbc` (Infos du sort de craft)
* `SpellReagents.dbc` (Mapping entre un sort de craft, les itemIDs des composants et leurs quantités)
* `SkillLineAbility.dbc` (Fait le lien entre le sort, le métier (Engineering), et donne les niveaux de couleurs : gris, vert, jaune, orange).





### 4. Add-ons existants comme source

Pour récupérer directement un fichier `.lua` exploitable ou extraire une structure propre, deux projets sortent du lot :

* **MissingTradeSkillsList (MTSL)**
* **Lien** : [GitHub - refaim/MissingTradeSkillsList](https://github.com/refaim/MissingTradeSkillsList) (ou les forks de Thumbkin).
* **Pourquoi c'est le jackpot** : Cet add-on liste toutes les recettes manquantes d'un joueur. Sa DB interne (`Data/Engineering.lua` par exemple) structure parfaitement les recettes par profession, contenant les IDs de sorts, la source (Vendor, Trainer, Mob Drop), et les skill levels requis.


* **Skillet-Classic**
* **Lien** : [GitHub - b-morgan/Skillet-Classic](https://github.com/b-morgan/Skillet-Classic)
* **Pourquoi c'est le jackpot** : C'est une refonte intégrale de l'interface de craft. Son code source inclut les logiques de regroupement par métier et les listes de matériaux nécessaires.



### 5. ItemIDs Classic Era vs Vanilla

**Les itemIDs de Vanilla (1.12) et de Classic Era (1.15.x) sont-ils identiques ?**

**Oui, absolument**, pour tout le contenu d'origine. La base de données de WoW a été construite pour être rétro-compatible au niveau des identifiants (un Minerai de Cuivre garde son ID `2770` que vous soyez sur le patch 1.12 de 2006, Classic Era 1.15, ou même sur Retail).

**Ce qui change :**
Classic Era 1.15 (et SoD) inclut de **nouveaux items** (ex: le *Déplaceur chronobonique / Chronoboon Displacer*, les runes de la Saison de la Découverte, etc.) qui possèdent des ID beaucoup plus récents (qui n'existaient pas en 1.12). Cependant, tout le mapping historique des recettes d'Ingénierie de 1 à 300 est resté strictement le même.

### Conclusion pour votre besoin "Jackpot"

La méthode la plus efficiente pour 15-20 recettes :
Allez sur le dépôt de **MissingTradeSkillsList** ou **AtlasLootClassic_Crafting**, ouvrez le fichier des données `Engineering.lua`. Vous y trouverez la structure exacte que vous cherchez (Skill levels de couleur, Sources, ItemIDs). Croisez cela si besoin avec une requête ponctuelle sur **Wago.tools** (`SpellReagents.dbc`) pour vérifier les quantités exactes des composants sans vous épuiser à parser Wowhead.