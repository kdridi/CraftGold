J'ai maintenant suffisamment d'informations pour rédiger une réponse complète et rigoureuse. Voici la recherche compilée en monobloc markdown :

---

```markdown
# GetItemInfo — Cache, Cycle de Vie et Async en WoW Classic Era (1.15.x)

> Recherche effectuée en juin 2026. Sources prioritaires : wowpedia.fandom.com, warcraft.wiki.gg, wowdev.wiki, forums Blizzard officiels, WoWInterface.

---

## 1. Architecture du Cache d'Items WoW Classic Era

### 1.1 Où sont stockées les données ?

Le système de cache d'items repose sur **deux couches distinctes** — c'est la clé pour comprendre votre problème.

**Couche 1 — Données embarquées dans le client (DBC/CASC)**

En vanilla WoW (1.12), les métadonnées de base des items étaient stockées dans des fichiers `Item.dbc` embarqués dans les archives MPQ du client. En Classic Era (1.15.x), le client Blizzard moderne utilise CASC (Content Addressable Storage Container) à la place de MPQ, mais le principe est identique : les données de base de **tous les items du jeu** sont packagées dans les archives du client lors de l'installation/mise à jour.

> Sources : [wowpedia.fandom.com/wiki/Content_Addressable_Storage_Container](https://wowpedia.fandom.com/wiki/Content_Addressable_Storage_Container) — [wowdev.wiki/WDB](https://wowdev.wiki/WDB)

**Couche 2 — Cache réseau WDB (données complémentaires serveur)**

Le fichier `ItemCache.wdb` (signature `WIDB`) est généré dans le dossier `Cache/WDB/` du client. Il stocke les données **reçues du serveur** pour les items que le personnage a rencontrés — notamment les stats détaillées, les effets de sorts, les textes de description. Selon wowdev.wiki, l'`ItemCache.wdb` est un cache **persistant** (`persistent parameter = true`) qui survit entre les sessions.

> Source : [wowdev.wiki/WDB](https://wowdev.wiki/WDB) — [wowdev.wiki/ItemCache.wdb](https://wowdev.wiki/ItemCache.wdb)

**Localisation exacte sur Classic Era 1.15.x :**
```
_classic_era_/Cache/WDB/enUS/itemcache.wdb
```
(Remplacer `enUS` par votre locale.)

> Source : [alienfusiongenerator.com — WDB parser](https://alienfusiongenerator.com/online-wow-classic-wdb-file-parser/)

**Le point crucial : depuis WoD (patch 6.0) et CASC, une troisième couche est apparue :**

`Cache/ADB/enUS/DBCache.bin` — c'est le cache des **hotfixes serveur** appliqués aux DB2 clients. Ce fichier est distinct du WDB traditionnel. Sur Classic Era (qui utilise le moteur CASC moderne), ce mécanisme de hotfix est actif.

> Source : [github.com/simulationcraft/simc — CASC Extract](https://github.com/simulationcraft/simc/wiki/Using-CASC-Extract-and-DBC-Extract)

### 1.2 Quand le client précharge-t-il les items ?

Le client WoW Classic Era charge les métadonnées de base de **tous les items du jeu** lors du démarrage (depuis les archives CASC). Ce n'est pas un préchargement sélectif : toutes les données DBC/DB2 sont mappées en mémoire au lancement du client. C'est pourquoi supprimer `Cache/WDB/` ne suffit pas à vider la connaissance des items — les données fondamentales ne viennent pas de là.

Le chargement se produit :
1. **Au lancement de l'exécutable** — chargement des DB2 depuis CASC en mémoire
2. **À la connexion au realm** — application des hotfixes serveur depuis `DBCache.bin`
3. **En jeu** — pour les items avec données complémentaires (stats de sorts, buffs) non encore reçues du serveur, une requête réseau est faite et la réponse est stockée dans `ItemCache.wdb`

### 1.3 Quels items sont préchargés ?

En Classic Era 1.15.x : **tous les items du jeu Classic** dont les données de base sont dans les DB2 intégrées au client. Cela inclut les items de craft, les items de quête, les items de raid Naxx, les items d'Engineering, etc.

La distinction Classic Era vs. Retail : en Retail, la base de données d'items est gigantesque (20 ans de contenu) et ne tient pas entièrement en mémoire simultanément. En Classic Era, l'ensemble des items 1.15 est relativement compact et tient dans les archives client. C'est pourquoi `GetItemInfo()` retourne quasi-systématiquement des données immédiates en Classic Era, alors que ce n'est pas le cas en Retail pour des items d'extensions plus récentes.

---

## 2. GetItemInfo — Comportement Exact

### 2.1 Quand retourne-t-elle `nil` ?

D'après [wowpedia.fandom.com/wiki/API_GetItemInfo](https://wowpedia.fandom.com/wiki/API_GetItemInfo) et [warcraft.wiki.gg/wiki/API_C_Item.GetItemInfo](https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfo) :

`GetItemInfo()` retourne `nil` si et seulement si **l'item n'est pas encore chargé en mémoire cliente** au moment de l'appel. En pratique sur Classic Era, cela arrive dans les cas suivants :

| Scénario | Probabilité sur Classic Era |
|---|---|
| Item inexistant (ID invalide) | Toujours nil |
| Item de Retail uniquement (ID absent des DB2 Classic) | Toujours nil |
| Item très rarement vu, données complémentaires (stats de sorts) non reçues | Rare |
| Premier appel dans une session fraîche avec WDB vidé ET DBCache.bin vidé | Possible mais court |

> **Constat de la communauté** (MMO-Champion, 2015) : un développeur d'addon a rapporté que `GetItemInfo()` ne retournait plus `nil` après avoir utilisé l'itemID plutôt qu'un item link, ce qui suggère que les données de base sont toujours disponibles côté client pour les items Classic.

> Source : [mmo-champion.com — GET_ITEM_INFO_RECEIVED not firing](https://www.mmo-champion.com/threads/1881761-GET_ITEM_INFO_RECEIVED-not-firing)

### 2.2 Items "toujours en cache"

Oui, les items de base de Classic Era (Copper Bar #2840, Linen Cloth #2589, Hearthstone #6948, etc.) sont **toujours disponibles immédiatement** car leurs données sont dans les DB2 CASC. La suppression du WDB ne change rien à cela.

### 2.3 GetItemInfo vs. GetItemInfoInstant

| Fonction | Source des données | Retourne nil ? |
|---|---|---|
| `GetItemInfo(id)` | DB2 CASC + WDB + requête serveur si nécessaire | Oui, si item inconnu du client |
| `GetItemInfoInstant(id)` | **Uniquement DB2 embarqué** (pas de requête serveur) | **Jamais pour les items valides** |

D'après [wowpedia.fandom.com/wiki/API_GetItemInfoInstant](https://wowpedia.fandom.com/wiki/API_GetItemInfoInstant) :

> *"This function only returns info that don't require a query to the server. Which has the advantage over GetItemInfo() it will always return data for valid items."*

`GetItemInfoInstant()` retourne : itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID — soit les champs disponibles **dans le DB2 local**.

**Attention** : `GetItemInfoInstant()` a été ajoutée au patch 7.0.3 (Legion). Elle est disponible en Classic Era 1.15 qui utilise le moteur client moderne.

> Source : [warcraft.wiki.gg/wiki/API_C_Item.GetItemInfoInstant](https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfoInstant)

### 2.4 Peut-on forcer le client à "oublier" un item ?

Non, pas via des outils Blizzard officiels. Le chargement des DB2 est géré au niveau du moteur C++, pas par Lua. On peut vider le WDB et le DBCache.bin, mais le moteur recharge les données de base depuis CASC au prochain démarrage. Il n'existe pas de commande console pour vider sélectivement la mémoire d'items.

---

## 3. GET_ITEM_INFO_RECEIVED — Déclencheurs Réels

### 3.1 Définition officielle

D'après [wowpedia.fandom.com/wiki/GET_ITEM_INFO_RECEIVED](https://wowpedia.fandom.com/wiki/GET_ITEM_INFO_RECEIVED) :

> *"Fired when GetItemInfo queries the server for an uncached item and the response has arrived."*

L'événement se déclenche quand `GetItemInfo()` a dû faire une **vraie requête réseau** vers le serveur et que la réponse est arrivée.

### 3.2 Pourquoi l'événement ne se déclenche jamais en Classic Era ?

**C'est le comportement attendu et normal sur Classic Era avec un personnage existant.**

En Classic Era 1.15.x :
- Les DB2 CASC contiennent les métadonnées de base de tous les items du jeu
- Le moteur client charge tout cela en mémoire au démarrage
- `GetItemInfo()` trouve les données localement sans jamais contacter le serveur
- Donc `GET_ITEM_INFO_RECEIVED` ne se déclenche jamais

**Observation confirmée par la communauté** : le même développeur (MMO-Champion 2015) rapportait : *"now I'm not getting GetItemInfo to return nil at all"* après avoir utilisé des itemIDs directs.

> Source : [mmo-champion.com — GET_ITEM_INFO_RECEIVED not firing](https://www.mmo-champion.com/threads/1881761-GET_ITEM_INFO_RECEIVED-not-firing)

### 3.3 L'événement est-il encore pertinent en Classic Era ?

**Théoriquement oui, pratiquement quasi-jamais.** Les seuls cas réalistes seraient :

1. Un item dont les données **complémentaires** (description de sorts, texte flavour) ne sont pas encore dans le WDB local — mais les données de base (nom, qualité, niveau) viennent du DB2 et ne nécessitent pas de requête.
2. Un item ajouté par **hotfix serveur** très récent, pas encore dans le DBCache.bin local.
3. Un item avec un ID qui n'existe **pas dans Classic Era** mais qui existe sur le serveur (impossible sur un realm officiel Blizzard).

### 3.4 Comportement observé : l'événement se déclenche sur des items déjà cachés

Un post du forum Blizzard (septembre 2024) signale un comportement subtil : `GET_ITEM_INFO_RECEIVED` peut se déclencher même pour des items déjà en cache, notamment lors du rechargement de l'UI. Ce serait un "refresh" interne du moteur, non une vraie requête serveur.

> Source : [us.forums.blizzard.com/en/wow/t/get-item-info-received/1944910](https://us.forums.blizzard.com/en/wow/t/get-item-info-received/1944910)

---

## 4. Méthodes pour Reproduire le Comportement Async en Développement

### 4.1 ❌ Ce qui ne marche pas

- Supprimer `Cache/WDB/` seul → Ne change rien, le moteur utilise les DB2 CASC
- Supprimer `Cache/WDB/` + relancer → Idem, les DB2 sont rechargés depuis CASC
- Utiliser des items communs de Classic → Toujours en cache DB2

### 4.2 ✅ Méthodes qui peuvent fonctionner

**Méthode 1 — IDs de Retail inexistants en Classic Era**

Des itemIDs de Retail (ex: items de Dragonflight avec des IDs dans les 200 000+) n'existent pas dans les DB2 Classic Era. En théorie, `GetItemInfo(200000)` devrait retourner `nil`. Ces IDs génèreront une requête serveur qui échouera (success=false dans `GET_ITEM_INFO_RECEIVED`).

**Test concret :**
```lua
-- En Classic Era, ces IDs n'existent pas dans les DB2 locales
-- IDs Retail qui ne devraient pas être en cache Classic Era :
-- 210502 (item Dragonflight), 191529 (item Dragonflight), etc.
local name = GetItemInfo(210502)
if name == nil then
  print("nil comme attendu!")
end
```

**Méthode 2 — Vider DBCache.bin ET WDB**

Pour simuler un client vraiment frais :
1. Fermer WoW complètement
2. Supprimer `_classic_era_/Cache/WDB/enUS/` (tout le dossier)
3. Supprimer `_classic_era_/Cache/ADB/enUS/DBCache.bin`
4. Relancer WoW

Cela force la re-téléchargement des hotfixes depuis le serveur. Pour les items modifiés récemment par hotfix, `GET_ITEM_INFO_RECEIVED` pourrait se déclencher. C'est toutefois rare si le serveur n'a pas de hotfix récent.

**Méthode 3 — Addon de test avec `C_Item.RequestLoadItemDataByID()`**

Sur les clients modernes (qui tournent sous Classic Era 1.15), la fonction interne `C_Item.RequestLoadItemDataByID()` peut forcer une requête. Cependant cette API n'est pas documentée publiquement et son comportement en Classic Era est incertain.

**Méthode 4 — ItemCache addon (recommandé pour les tests)**

L'addon [ItemCache (CurseForge)](https://www.curseforge.com/wow/addons/itemcache) expose `IsLoaded()` qui distingue "données DB2 disponibles" de "données réseau chargées". Il permet de monitorer quels items déclenchent réellement une requête réseau.

> Source : [github.com/Anonomit/ItemCache](https://github.com/Anonomit/ItemCache)

**Méthode 5 — Tester sur un environnement de serveur privé**

Pour tester proprement le comportement async, certains développeurs utilisent un serveur privé (émulateur comme CMaNGOS) avec une base d'items réduite. Ainsi, des items absents de la DB du serveur priv déclenchent de vraies requêtes async. Pas idéal pour un développement de production, mais utile pour valider le code de gestion async.

### 4.3 ItemIDs pour tests concrets

```lua
-- Items Classic Era standards (TOUJOURS en cache immédiatement) :
-- 2840 = Copper Bar
-- 2589 = Linen Cloth
-- 6948 = Hearthstone
-- 4306 = Silk Cloth
-- 16846 = Giantstalker's Helmet

-- IDs Retail inexistants en Classic Era (devraient retourner nil) :
-- ~200000+ = items Dragonflight/TWW

-- Test à coller dans le chat en jeu :
/script local n = GetItemInfo(210502); print("ID 210502:", n == nil and "NIL (async needed)" or n)
/script local n = GetItemInfo(2840); print("Copper Bar:", n == nil and "NIL" or n)
```

---

## 5. Scénarios de Production : CraftGold et ses ~100+ itemIDs

### 5.1 Un joueur normal rencontrera-t-il des items non cachés ?

**Réponse courte : très rarement, voire jamais, pour les items Classic Era standards.**

Pour un add-on comme CraftGold qui référence des recettes de craft Classic Era, **les items seront quasi-systématiquement disponibles immédiatement** via `GetItemInfo()`, car :
- Tous les items de craft Classic (ingots, cloth, herbs, etc.) sont dans les DB2 CASC
- Les joueurs expérimentés ont ces items en WDB depuis longtemps
- Même les nouveaux personnages ont accès aux DB2 locales

### 5.2 Quels items sont les plus susceptibles d'être manquants ?

| Type d'item | Risque d'absence | Raison |
|---|---|---|
| Items de craft communs (Cloth, Bar, Herb) | **Quasi-nul** | DB2 CASC + WDB très courants |
| Items d'Engineering niveau 60 | **Faible** | Dans les DB2, mais WDB peut manquer si joueur novice Engi |
| Items de raid (Naxx, AQ) | **Faible** | DB2 CASC, mais données complémentaires serveur peu vues |
| Items ajoutés par hotfix récent | **Modéré** | Dépend du DBCache.bin local |
| Items custom d'un realm privé | **Élevé** | Absents des DB2 officiels |

### 5.3 Un joueur sans Engineering aura-t-il les items Engineering en cache ?

**Oui.** Les métadonnées de base (nom, qualité, niveau, type) sont dans les DB2 CASC pour tout le monde. En revanche, les données complémentaires détaillées (description du sort associé à l'item, etc.) pourraient nécessiter une requête réseau si le joueur n'a jamais eu l'item dans son inventaire. Pour les besoins de CraftGold (noms, qualités, icônes), tout est disponible immédiatement.

### 5.4 Nouveau personnage niveau 1 vs. niveau 60

**Aucune différence** pour la disponibilité de `GetItemInfo()`. Les DB2 CASC sont locales au client, pas au personnage. Un personnage niveau 1 a accès aux mêmes données de base qu'un niveau 60. Ce qui diffère, c'est le WDB (données vues en jeu), mais pour les items de craft communs, le WDB est typiquement déjà rempli par les sessions précédentes.

---

## 6. Conclusions et Recommandations pour CraftGold

### 6.1 Votre comportement est normal

Le fait que `GetItemInfo()` retourne immédiatement les noms **est le comportement attendu** en Classic Era 1.15.x pour les items de craft. L'événement `GET_ITEM_INFO_RECEIVED` ne se déclenche jamais parce qu'il n'y a jamais de requête réseau à faire — les données sont dans les DB2 CASC chargées au démarrage.

### 6.2 Devez-vous quand même gérer le cas async ?

**Oui, par robustesse**, même si le cas ne se produit pas sur votre machine :
- Des serveurs privés avec items custom pourraient ne pas avoir les données en DB2
- Des hotfixes très frais pourraient manquer dans le DBCache.bin d'un joueur
- Le comportement pourrait évoluer avec de futurs patches 1.15.x

### 6.3 Pattern recommandé pour CraftGold

```lua
-- Pattern robuste pour Classic Era
-- GetItemInfo() retournera presque toujours immédiatement,
-- mais on gère le cas async au cas où

local pendingItems = {}
local frame = CreateFrame("Frame")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function(self, event, itemID, success)
    if pendingItems[itemID] then
        if success then
            -- Mettre à jour l'UI avec GetItemInfo(itemID)
            CraftGold:UpdateItemDisplay(itemID)
        end
        pendingItems[itemID] = nil
    end
end)

function CraftGold:GetItemNameSafe(itemID, callback)
    local name = GetItemInfo(itemID)
    if name then
        callback(name)
    else
        -- Enregistrer pour traitement async
        pendingItems[itemID] = callback
        -- GetItemInfo() déclenche la requête serveur si appelé avec nil return
        GetItemInfo(itemID)
    end
end
```

### 6.4 Alternative moderne : `Item:ContinueOnItemLoad()`

Sur les clients Retail (et potentiellement Classic Era avec le moteur moderne), l'API `ItemMixin:ContinueOnItemLoad()` est l'approche recommandée par Blizzard pour gérer l'async proprement :

```lua
local item = Item:CreateFromItemID(itemID)
item:ContinueOnItemLoad(function()
    local name = item:GetItemName()
    -- ...
end)
```

> Source : [wowpedia.fandom.com/wiki/API_GetItemInfo](https://wowpedia.fandom.com/wiki/API_GetItemInfo) — [warcraft.wiki.gg/wiki/API_C_Item.GetItemInfo](https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfo)

**Vérifier la disponibilité de `Item:ContinueOnItemLoad()` en Classic Era 1.15.x** — cette API fait partie du framework OOP des items introduit en Retail, qui a été partiellement backporté en Classic. Tester avec `/script local i = Item:CreateFromItemID(2840); print(type(i))` en jeu.

---

## Sources

| URL | Contenu |
|---|---|
| https://wowpedia.fandom.com/wiki/API_GetItemInfo | Signature, comportement nil, exemples |
| https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfo | Idem, plus récent |
| https://wowpedia.fandom.com/wiki/GET_ITEM_INFO_RECEIVED | Déclencheurs de l'événement |
| https://wowpedia.fandom.com/wiki/API_GetItemInfoInstant | Différence Instant vs normal |
| https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfoInstant | Idem warcraft.wiki |
| https://wowdev.wiki/WDB | Architecture des fichiers WDB |
| https://wowdev.wiki/ItemCache.wdb | Structure de ItemCache.wdb |
| https://wowpedia.fandom.com/wiki/Content_Addressable_Storage_Container | Architecture CASC |
| https://github.com/Anonomit/ItemCache | Addon ItemCache, distinction loaded/cached |
| https://www.mmo-champion.com/threads/1881761-GET_ITEM_INFO_RECEIVED-not-firing | Discussion communauté |
| https://us.forums.blizzard.com/en/wow/t/get-item-info-received/1944910 | Forum Blizzard officiel |
| https://alienfusiongenerator.com/online-wow-classic-wdb-file-parser/ | Localisation des WDB en Classic Era |
| https://github.com/simulationcraft/simc/wiki/Using-CASC-Extract-and-DBC-Extract | DBCache.bin et hotfixes CASC |
```