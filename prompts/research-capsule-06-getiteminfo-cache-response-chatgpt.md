# Recherche — `GetItemInfo` : cache, cycle de vie, et reproduction de l’async en WoW Classic Era

## Verdict pratique

Votre observation est normale : **supprimer `Cache/WDB/` ne suffit pas à forcer `GetItemInfo(itemID)` à redevenir asynchrone**. Le vieux modèle “l’item est dans `itemcache.wdb` ou pas” est trop simplifié pour les clients modernes/Classic Era : certaines informations item sont dans des bases client locales, certaines sont dans des caches reconstruits, certaines sont “loaded” en mémoire, et `GetItemInfo` ne déclenche `GET_ITEM_INFO_RECEIVED` que s’il a réellement dû demander une donnée item absente au serveur. Warcraft Wiki décrit précisément l’événement comme déclenché quand `GetItemInfo` interroge le serveur pour un item non caché, puis reçoit la réponse. ([Warcraft Wiki][1])

La conclusion pour CraftGold : **ne cherchez pas à dépendre d’un itemID magique pour reproduire l’async**. Implémentez votre resolver comme asynchrone par conception, puis testez l’async avec un provider mocké. En production Classic Era, pour une base de recettes Engineering vanilla/Classic, les items seront probablement résolus immédiatement dans la majorité des cas, mais votre add-on doit quand même gérer `nil` proprement, car l’API documente ce cas et les auteurs d’add-ons le rencontrent encore. ([Wowpedia][2])

---

## 1. Architecture du cache d’items WoW

Historiquement, WoW utilisait des fichiers `.wdb` pour stocker localement des données reçues du serveur. Les pages techniques WoWWiki/Wowpedia décrivent les fichiers WDB comme des fichiers créés par WoW pour mettre en cache des données récupérées depuis les serveurs, avec notamment `Itemcache.wdb` pour les données item et `Itemnamecache.wdb` pour certains noms d’items. ([WoWWiki Archive][3])

Mais cette explication historique ne suffit plus. Les clients modernes utilisent aussi des bases client de type DBC/DB2 dans les données du jeu ; WoWDev décrit DB2 comme une génération de bases client contenant des données sur items, PNJ, environnement, etc., et des outils comme DBCD lisent les formats DBC/DB2 et appliquent aussi des hotfixes/cache DB. ([wowdev.wiki][4])

Un thread WoWInterface résume bien la séparation : le dossier `Cache` ne contient pas “tout le jeu”, seulement ce qui a été chargé ; pour accéder aux DB2/CASC, il faut lire les fichiers du dossier `Data`, pas seulement le dossier `Cache`. Le même thread mentionne `Item-sparse.dba` comme cache local consulté avant une requête serveur, puis indique que des données item existent aussi dans des fichiers DB2/CASC comme `ItemSearchName.db2`. ([WoWInterface][5])

Donc, quand vous supprimez `Cache/WDB/`, vous supprimez une couche de cache, mais pas nécessairement les données item déjà présentes dans les données client installées, ni les caches reconstruits au login, ni l’état chargé en mémoire par l’UI, l’hôtel des ventes, les sacs, les professions, les tooltips, ou d’autres add-ons. Cette distinction entre “l’item est connu par une librairie/cache” et “l’item est actuellement loaded par Blizzard donc `GetItemInfo` retourne non-`nil`” est explicitement documentée par l’addon/lib ItemCache : un item peut être chargé sans être dans le cache de la lib, ou être connu par la lib sans être loaded par `GetItemInfo`. ([GitHub][6])

### Où sont stockées les données ?

Réponse fiable mais prudente :

| Couche                                                               | Rôle                                                                       | Ce que la suppression change                                         |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `Cache/WDB/.../itemcache.wdb` ou équivalent historique               | Cache de données reçues serveur dans l’ancien modèle                       | Peut supprimer des données vues, mais pas les données client de base |
| `Cache/<locale>/Item-sparse.dba` / ADB-like cache selon client/build | Cache local de données item “sparse” mentionné par des auteurs d’add-ons   | Peut être reconstruit ; chemin exact peut varier selon client/build  |
| `Data/` / CASC / DB2                                                 | Données client installées avec le jeu                                      | Non supprimées par `Cache/WDB`                                       |
| Mémoire de session                                                   | Données “loaded” par l’UI, sacs, AH, tooltips, professions, autres add-ons | Se réinitialise au redémarrage, mais peut être rechargée très vite   |

Les sources publiques ne donnent pas, à ma connaissance, un cycle officiel détaillé “à la milliseconde” pour Classic Era : login, sélection perso, chargement monde, préchargement exact par catégorie. Ce qui est documenté publiquement, c’est le comportement observable de l’API : `GetItemInfo` peut retourner `nil` si l’item n’est pas caché/loaded, et l’événement n’arrive que si une requête serveur a été faite. ([Wowpedia][2])

---

## 2. `GetItemInfo` — comportement exact

`GetItemInfo(item)` retourne un tuple complet : nom localisé, lien, qualité, item level, type, sous-type, stack count, equip loc, texture, prix vendeur, classID, subclassID, bindType, expansionID, setID, etc. La page Wowpedia/Warcraft Wiki précise qu’un itemID valide peut retourner `nil` si l’item n’est pas encore caché, et que la fonction retourne aussi `nil` si l’item n’existe pas. ([Wowpedia][2])

Le cas important est donc :

```lua
local name, link = GetItemInfo(itemID)

if name then
  -- donnée disponible immédiatement
else
  -- item non loaded OU item inexistant/non disponible
  -- il faut attendre GET_ITEM_INFO_RECEIVED, mais seulement si une requête réelle part
end
```

L’argument peut être un itemID, un lien, un item string du type `item:%d`, ou un nom localisé. Mais la recherche par nom est plus limitée : elle requiert que l’item ait été dans les sacs/la banque ou équipé dans la session, selon la documentation. ([Wowpedia][2])

### `GetItemInfo()` vs `GetItemInfoInstant()`

`GetItemInfoInstant()` retourne seulement les informations “readily available” : itemID, type, sous-type, equip loc, icon, classID, subclassID. La documentation précise que cette fonction ne demande pas les données nécessitant une requête serveur, et qu’elle retourne les infos disponibles pour les items valides. ([Wowpedia][7])

En pratique :

```lua
-- Peut être nil si l’item complet n’est pas loaded.
local name, link, quality = GetItemInfo(16054)

-- Donne seulement les infos statiques disponibles localement.
local itemID, itemType, itemSubType, equipLoc, icon = GetItemInfoInstant(16054)
```

Pour CraftGold, `GetItemInfoInstant()` peut suffire pour icône/type/classe, mais pas pour obtenir le **nom complet localisé** et le **lien item complet** comme `GetItemInfo`. ([Wowpedia][7])

### Les items de base sont-ils toujours en cache ?

Pas “toujours” au sens contractuel, mais **très souvent disponibles immédiatement** en Classic Era. Les exemples de documentation utilisent des items comme `4306` — Silk Cloth — et montrent un retour complet immédiat ; les matériaux très communs comme Linen Cloth, Copper Bar, Silk Cloth, etc. sont typiquement dans les données locales ou chargés très tôt par l’UI, les sacs, l’AH, les professions, ou d’autres add-ons. ([Wowpedia][2])

Donc votre test avec des items Engineering basiques ne prouve pas que `GET_ITEM_INFO_RECEIVED` est cassé : il prouve surtout que ces IDs sont déjà résolus par le client dans votre environnement.

### Peut-on forcer le client à oublier un item ?

Je n’ai pas trouvé de commande console officielle ni d’API Lua permettant de vider sélectivement l’état “loaded” d’un item. Les anciennes pratiques consistent à supprimer/renommer des dossiers de cache, mais cela ne supprime pas les données client DB2/CASC et ne garantit pas un `nil` pour un item de base. Les sources WDB décrivent la suppression comme une suppression de cache local, pas comme un effacement des bases client installées. ([WoWWiki Archive][3])

---

## 3. `GET_ITEM_INFO_RECEIVED` — déclencheurs réels

`GET_ITEM_INFO_RECEIVED` se déclenche quand `GetItemInfo` a dû demander au serveur un item non caché et que la réponse est arrivée. Son payload est `itemID, success`, avec `success == true` si l’item a été obtenu, `false` si l’item ne peut pas être obtenu, et parfois `nil` selon les cas documentés. ([Warcraft Wiki][1])

Ce point explique votre symptôme :

```lua
local name = GetItemInfo(itemID)

if name then
  -- aucun GET_ITEM_INFO_RECEIVED attendu
else
  -- GET_ITEM_INFO_RECEIVED possible, mais pas garanti si item inexistant/non requêtable
end
```

Un auteur sur WoWInterface résume le pattern : appeler `GetItemInfo`, vérifier si le retour est `nil`, enregistrer/écouter `GET_ITEM_INFO_RECEIVED`, comparer `arg1`/`itemID`, puis rappeler `GetItemInfo` dans le handler. Le même échange précise que si le premier appel ne retourne pas `nil`, il ne faut pas attendre un événement pour cet item. ([WoWInterface][8])

Il existe aussi une API parallèle : `C_Item.RequestLoadItemDataByID(itemInfo)`, qui déclenche `ITEM_DATA_LOAD_RESULT` plutôt que `GET_ITEM_INFO_RECEIVED`. Cette API est documentée comme demandant les données item et déclenchant `ITEM_DATA_LOAD_RESULT`; l’événement porte aussi `itemID, success`. ([Wowpedia][9])

Attention : certains items peuvent “exister” côté API mais ne jamais fournir de données complètes. La page `ItemMixin` cite par exemple l’itemID `17`, qui peut retourner `true` avec `C_Item.DoesItemExistByID` mais finir en `ITEM_DATA_LOAD_RESULT` avec `success:false`, et `GetItemInfo` ne retournera jamais les infos. ([Wowpedia][10])

---

## 4. Méthodes pour reproduire l’async en développement

### Méthode A — Test réel en jeu, non garanti

Essayez des items rares, saisonniers, réputation, ou haut niveau Classic Era, de préférence sur un client fraîchement relancé, avec tous les autres add-ons désactivés, sans ouvrir l’AH ni les professions avant le test.

Candidats à tester :

|  itemID | Item                             | Pourquoi le tester                    |
| ------: | -------------------------------- | ------------------------------------- |
| `16054` | Schematic: Arcanite Dragonling   | Schematic Engineering rare/high-level |
| `18650` | Schematic: EZ-Thro Dynamite II   | Schematic Engineering moins courant   |
| `19999` | Bloodvine Goggles                | Craft Engineering ZG/high-level       |
| `20000` | Schematic: Bloodvine Goggles     | Schematic réputation Zandalar         |
| `22729` | Schematic: Steam Tonk Controller | Schematic Darkmoon Faire              |
| `21524` | Red Winter Hat                   | Item saisonnier Winter Veil           |

Ces IDs sont bien des items Classic/vanilla selon Wowhead Classic ou ClassicDB, mais ils ne garantissent pas un comportement async : si le client les a déjà dans ses données locales ou les charge immédiatement, `GetItemInfo` retournera le nom tout de suite. ([Wowhead][11])

Macro/add-on de test :

```lua
/run CraftGoldTestGIIR()
```

Fichier Lua de test :

```lua
local ids = {
  2842,   -- Silver Bar / basique
  4306,   -- Silk Cloth / basique
  16054,  -- Schematic: Arcanite Dragonling
  18650,  -- Schematic: EZ-Thro Dynamite II
  19999,  -- Bloodvine Goggles
  20000,  -- Schematic: Bloodvine Goggles
  22729,  -- Schematic: Steam Tonk Controller
  21524,  -- Red Winter Hat
  999999, -- invalide Classic Era probable : ne doit PAS servir à tester un succès async
}

local f = CreateFrame("Frame")
local pending = {}

f:RegisterEvent("GET_ITEM_INFO_RECEIVED")

f:SetScript("OnEvent", function(_, event, itemID, success)
  print("GET_ITEM_INFO_RECEIVED", itemID, "success=", tostring(success))

  local name, link = GetItemInfo(itemID)
  print("After event:", itemID, name or "nil", link or "nil")

  pending[itemID] = nil
end)

function CraftGoldTestGIIR()
  wipe(pending)

  for _, itemID in ipairs(ids) do
    local name, link = GetItemInfo(itemID)
    print("Initial:", itemID, name or "nil", link or "nil")

    if not name then
      pending[itemID] = true
    end
  end

  C_Timer.After(5, function()
    for itemID in pairs(pending) do
      print("Still pending after 5s:", itemID)
    end
  end)
end
```

Interprétez ainsi :

| Résultat                                            | Interprétation                                                 |
| --------------------------------------------------- | -------------------------------------------------------------- |
| `Initial: 16054 Schematic: Arcanite Dragonling ...` | Item déjà loaded ; aucun event attendu                         |
| `Initial: 16054 nil nil`, puis event `success=true` | Async réel reproduit                                           |
| `Initial: 999999 nil nil`, aucun event              | ID inexistant/non valide ; ce n’est pas un test d’async réussi |
| Event `success=false`                               | Le client/serveur refuse ou ne peut pas fournir les données    |

### Méthode B — Utiliser `C_Item.RequestLoadItemDataByID`

Sur les clients où `C_Item.RequestLoadItemDataByID` existe, vous pouvez tester le chemin moderne `ITEM_DATA_LOAD_RESULT` :

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("ITEM_DATA_LOAD_RESULT")

f:SetScript("OnEvent", function(_, event, itemID, success)
  print(event, itemID, "success=", tostring(success))
  print("GetItemInfo after:", GetItemInfo(itemID))
end)

C_Item.RequestLoadItemDataByID(16054)
```

Ce chemin est plus explicite pour “demander le chargement de données item”, mais il ne remplace pas automatiquement `GET_ITEM_INFO_RECEIVED` si votre code repose déjà sur `GetItemInfo`. Les discussions d’auteurs d’add-ons indiquent que les deux événements ont des payloads très proches, mais sont déclenchés par des APIs différentes. ([WoWInterface][12])

### Méthode C — La bonne méthode pour CraftGold : mocker l’async

Pour un add-on pédagogique/testable, ne testez pas l’async Blizzard directement. Testez votre propre abstraction.

Exemple minimal :

```lua
CraftGold_ItemResolver = {}
CraftGold_ItemResolver.pending = {}

function CraftGold_ItemResolver:Resolve(itemID, callback)
  local name, link, quality, itemLevel, _, itemType, itemSubType, stackCount, equipLoc, icon =
    GetItemInfo(itemID)

  if name then
    callback({
      itemID = itemID,
      name = name,
      link = link,
      quality = quality,
      itemLevel = itemLevel,
      itemType = itemType,
      itemSubType = itemSubType,
      stackCount = stackCount,
      equipLoc = equipLoc,
      icon = icon,
      async = false,
    })
    return true
  end

  self.pending[itemID] = self.pending[itemID] or {}
  table.insert(self.pending[itemID], callback)
  return false
end

function CraftGold_ItemResolver:OnItemInfoReceived(itemID, success)
  local callbacks = self.pending[itemID]
  if not callbacks then return end
  self.pending[itemID] = nil

  if not success then
    for _, callback in ipairs(callbacks) do
      callback({
        itemID = itemID,
        error = "GET_ITEM_INFO_FAILED",
        async = true,
      })
    end
    return
  end

  local name, link, quality, itemLevel, _, itemType, itemSubType, stackCount, equipLoc, icon =
    GetItemInfo(itemID)

  for _, callback in ipairs(callbacks) do
    callback({
      itemID = itemID,
      name = name,
      link = link,
      quality = quality,
      itemLevel = itemLevel,
      itemType = itemType,
      itemSubType = itemSubType,
      stackCount = stackCount,
      equipLoc = equipLoc,
      icon = icon,
      async = true,
    })
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:SetScript("OnEvent", function(_, _, itemID, success)
  CraftGold_ItemResolver:OnItemInfoReceived(itemID, success)
end)
```

Puis, pour vos tests hors WoW ou en mode dev, simulez simplement :

```lua
-- Test : premier appel retourne nil, puis callback async simulé.
local fakeProvider = {
  calls = 0,
  GetItemInfo = function(self, itemID)
    self.calls = self.calls + 1

    if self.calls == 1 then
      return nil
    end

    return "Fake Copper Bar", "|cffffffff|Hitem:" .. itemID .. "|h[Fake Copper Bar]|h|r"
  end
}
```

Cette approche suit exactement le pattern recommandé par les libs comme `GetItemInfoAsync`, qui appellent `GetItemInfo`, exécutent le callback immédiatement si les données sont là, ou mettent le callback en attente jusqu’à `GET_ITEM_INFO_RECEIVED` si `GetItemInfo` retourne `nil`. ([CurseForge][13])

---

## 5. Scénarios de production pour CraftGold

Pour une base statique de recettes Engineering Classic Era avec ~100+ itemIDs, je classerais le risque ainsi :

| Type d’item                                                                    | Risque réel de `nil`                 |
| ------------------------------------------------------------------------------ | ------------------------------------ |
| Matériaux communs : Copper Bar, Linen Cloth, Coarse Stone, Bronze Bar          | Très faible                          |
| Produits Engineering basiques : Rough Blasting Powder, Handful of Copper Bolts | Très faible                          |
| Schematics rares, réputation, événement, raid/ZG/AQ                            | Faible à moyen selon client/session  |
| Items Retail/non-Classic IDs                                                   | `nil`, mais pas un async valide      |
| Items “spéciaux” ou retirés/non requêtables                                    | Peut rester `nil` ou `success=false` |

Un joueur qui n’a jamais monté Engineering peut quand même avoir beaucoup d’items Engineering résolus immédiatement, parce que la disponibilité ne dépend pas uniquement de son historique métier : les données peuvent être dans les bases client, dans le cache global du client, ou chargées par l’AH/tooltips/add-ons. Les docs API disent seulement que `GetItemInfo` peut retourner `nil` si l’item n’est pas caché ; elles ne disent pas que le cache est strictement “par personnage” ou “par profession connue”. ([Wowpedia][2])

Un niveau 1 et un niveau 60 sur la même installation peuvent partager des caches client/fichiers de cache au niveau installation/locale, mais leur session peut charger des choses différentes via sacs, banque, quêtes, AH, métiers, ou UI. Les fichiers WDB ont une notion de build/locale, et la lib ItemCache note aussi que son cache persistant est locale-specific ; ce n’est donc pas un modèle purement “par personnage”. ([WoWWiki Archive][3])

Pour CraftGold, la stratégie robuste est :

```lua
-- UI immédiate
AfficherItem(itemID, "Loading...", placeholderIcon)

-- Résolution
CraftGold_ItemResolver:Resolve(itemID, function(item)
  if item.error then
    AfficherItem(itemID, "#" .. itemID, placeholderIcon)
  else
    AfficherItem(itemID, item.name, item.icon)
  end
end)
```

Et surtout : **ne bloquez jamais l’ouverture de la fenêtre sur la résolution des noms**. Affichez `#itemID` ou `"Loading..."`, puis mettez à jour ligne par ligne si un event arrive. C’est exactement le modèle utilisé par les libs et recommandé dans les discussions d’auteurs d’add-ons : premier appel synchrone si possible, mise en attente si `nil`, refresh au retour de l’événement. ([WoWInterface][14])

---

## Réponses directes à vos questions

### `Cache/WDB/itemcache.wdb` est-il la source principale ?

Historiquement oui pour une partie du cache item, mais non comme source unique actuelle. WDB est une ancienne couche de cache de données serveur ; les clients modernes/Classic ont aussi des données client DB2/CASC et des caches sparse/ADB/hotfix selon build. ([WoWWiki Archive][3])

### Quand le client précharge-t-il les items ?

Je n’ai pas trouvé de documentation Blizzard publique donnant la liste exacte des préchargements Classic Era au login/sélection personnage/chargement monde. Les sources publiques décrivent plutôt le comportement API : si l’item est déjà disponible, `GetItemInfo` retourne immédiatement ; sinon, il peut demander au serveur et déclencher `GET_ITEM_INFO_RECEIVED`. ([Warcraft Wiki][1])

### Précharge-t-il tous les items ?

Je ne peux pas l’affirmer. Ce qu’on peut dire : le dossier `Cache` ne contient pas tout, les DB2/CASC contiennent des données client, et beaucoup d’items Classic de base semblent disponibles immédiatement. Votre résultat “tous mes items Engineering répondent immédiatement” est plausible sans impliquer que tout le jeu est préchargé. ([WoWInterface][15])

### `GetItemInfo(itemID)` retourne `nil` quand ?

Quand l’item complet n’est pas caché/loaded, ou quand l’item n’existe pas / n’est pas requêtable. La documentation dit explicitement qu’un itemID valide peut retourner `nil` si non caché, et que la fonction retourne `nil` si l’item n’est pas caché ou n’existe pas. ([Wowpedia][2])

### `GetItemInfoInstant()` évite-t-il le cache ?

Il évite surtout la requête serveur : il ne retourne que les infos immédiatement disponibles, en sous-ensemble. Il ne donne pas le nom/lien complet comme `GetItemInfo`. ([Wowpedia][7])

### Peut-on utiliser des IDs Retail pour forcer `nil` ?

Oui pour obtenir `nil`, mais **non pour tester un async réussi**. Un ID absent de Classic Era risque de rester `nil` ou d’échouer ; ce n’est pas le même scénario qu’un item Classic valide non chargé qui finit par déclencher `GET_ITEM_INFO_RECEIVED(success=true)`. La page `ItemMixin` documente même des cas où un item peut “exister” mais ne jamais fournir de données exploitables, avec `success:false`. ([Wowpedia][10])

### Existe-t-il un itemID exotique garanti async ?

Je n’ai trouvé aucune source fiable donnant un itemID Classic Era “garanti non préchargé”. Les candidats listés plus haut peuvent aider, mais le résultat dépendra du client, du cache, des add-ons, de la session, et du build.

### Est-ce que `GET_ITEM_INFO_RECEIVED` est encore pertinent en Classic Era ?

Oui, parce que l’API documente encore le cas `nil` et des libs Classic comme `GetItemInfoAsync` existent précisément pour encapsuler ce pattern. Mais pour une base de recettes Classic courante, vous le verrez probablement rarement si les IDs sont déjà dans les données locales ou chargés rapidement. ([CurseForge][13])

[1]: https://warcraft.wiki.gg/wiki/GET_ITEM_INFO_RECEIVED?utm_source=chatgpt.com "GET_ITEM_INFO_RECEIVED - Warcraft Wiki"
[2]: https://wowpedia.fandom.com/wiki/API_GetItemInfo "GetItemInfo - Wowpedia - Your wiki guide to the World of Warcraft"
[3]: https://wowwiki-archive.fandom.com/wiki/WDB_file "WDB file | WoWWiki | Fandom"
[4]: https://wowdev.wiki/DB2?utm_source=chatgpt.com "DB2"
[5]: https://www.wowinterface.com/forums/showthread.php?t=55219&utm_source=chatgpt.com "Can you get db for every single items exist in WoW ..."
[6]: https://github.com/Anonomit/ItemCache "GitHub - Anonomit/ItemCache: WoW addon. Caches item data returned by GetItemInfo() and more. Can be run standalone to store data between sessions, or can be embedded as a library. · GitHub"
[7]: https://wowpedia.fandom.com/wiki/API_GetItemInfoInstant "GetItemInfoInstant - Wowpedia - Your wiki guide to the World of Warcraft"
[8]: https://www.wowinterface.com/forums/showthread.php?t=56836&utm_source=chatgpt.com "GetItemInfo() returning lots of nil values"
[9]: https://wowpedia.fandom.com/wiki/API_C_Item.RequestLoadItemData "C_Item.RequestLoadItemData - Wowpedia - Your wiki guide to the World of Warcraft"
[10]: https://wowpedia.fandom.com/wiki/ItemMixin?utm_source=chatgpt.com "ItemMixin - Wowpedia - Your wiki guide to the World of Warcraft"
[11]: https://www.wowhead.com/classic/item%3D16054/schematic-arcanite-dragonling?utm_source=chatgpt.com "Schematic: Arcanite Dragonling - Item"
[12]: https://www.wowinterface.com/forums/showthread.php?t=56735&utm_source=chatgpt.com "GET_ITEM_INFO_RECEIVED vs. ..."
[13]: https://www.curseforge.com/wow/addons/getiteminfoasync "GetItemInfoAsync - World of Warcraft Addons - CurseForge"
[14]: https://www.wowinterface.com/forums/showthread.php?t=55352&utm_source=chatgpt.com "WoW LUA - cache issue"
[15]: https://www.wowinterface.com/forums/printthread.php?t=55219&utm_source=chatgpt.com "Can you get db for every single items exist in WoW (in-game)?"
