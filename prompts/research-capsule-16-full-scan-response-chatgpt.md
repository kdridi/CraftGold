## Verdict court

Oui : sur l’ancienne Auction House API utilisée par Classic Era, `getAll = true` est bien le mode “full scan” : il demande à télécharger **tout l’Hôtel des Ventes comme une seule page logique**, sans pagination classique. La requête est gated par le **2e retour de `CanSendAuctionQuery()`**, et le cooldown documenté est **environ 15 minutes**. En pratique, il faut coder autour de `CanSendAuctionQuery()` plutôt qu’autour d’un timer maison, parce que le scope exact serveur — personnage, compte, session — n’est pas clairement documenté. ([addonstudio.org][1])

---

## 1. `getAll = true` — comportement exact

L’appel pertinent en Classic Era 1.15.x est bien dans cet esprit :

```lua
QueryAuctionItems("", nil, nil, 0, false, nil, true, false, nil)
```

Dans la signature moderne de l’ancienne API Classic, `QueryAuctionItems(text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)`, le paramètre `getAll` est documenté comme : télécharger **l’ENTIRE auction house as one single page**, uniquement quand le second retour de `CanSendAuctionQuery()` l’autorise. ([addonstudio.org][1])

`text = ""` est bien le bon marqueur pour “pas de restriction par nom” : la doc indique que le nom peut être une partie du nom de l’item, ou `""` pour aucune restriction. Donc `"" + getAll=true` est le pattern “tout l’HdV”. ([addonstudio.org][1])

Après le retour serveur, `GetNumAuctionItems("list")` retourne deux valeurs : `batch` et `count`. En pagination normale, `batch` est la taille du batch/page courante et `count` le nombre total de résultats. En `getAll`, comme tout est renvoyé comme une seule page logique, on s’attend à ce que `batch == count == nombre d’enchères retournées`. La doc de `GetNumAuctionItems` définit bien ces deux valeurs, et un exemple réel de full scan montre `numBatchAuctions = 59607` et `totalAuctions = 59607`. ([addonstudio.org][2])

Donc : **pas de pagination** en `getAll`. Tu ne boucles pas sur `page = 0, 1, 2...`; tu attends `AUCTION_ITEM_LIST_UPDATE`, puis tu lis tous les index de `"list"`. L’événement `AUCTION_ITEM_LIST_UPDATE` est l’événement de mise à jour de la liste d’enchères. ([addonstudio.org][1])

---

## 2. `CanSendAuctionQuery()` — retour exact

La signature documentée est :

```lua
local canQuery, canQueryAll = CanSendAuctionQuery()
```

Elle retourne deux booléens : `canQuery` pour une requête normale, `canQueryAll` pour une requête full/getAll. La page Warcraft Wiki indique explicitement que cette API existe en **Classic Era** et Mists Classic, et AddOn Studio documente aussi les deux retours. ([Warcraft Wiki][3])

Je n’ai pas trouvé de source fiable indiquant que `CanSendAuctionQuery("list")` ait une sémantique différente en Classic Era. La forme documentée est **sans argument**. Même si l’appel avec argument ne plante pas forcément, je recommanderais de standardiser sur :

```lua
local canQuery, canQueryAll = CanSendAuctionQuery()
if canQueryAll then
  QueryAuctionItems("", nil, nil, 0, false, nil, true, false, nil)
end
```

Le signal fiable pour savoir si un full scan est autorisé est donc **`canQueryAll == true`**, pas `canQuery`. ([addonstudio.org][4])

---

## 3. Cooldown du full scan

La doc historique dit : requêtes normales throttled autour de `0.3s`, et requêtes `getAll` throttled autour de **15 minutes**. AddOn Studio indique aussi que les full `getall` ne sont autorisés qu’une fois toutes les **~15 minutes**. ([addonstudio.org][1])

Auctionator Classic/LegacyAH traite ce cooldown comme **15 minutes / 900 secondes** dans son UI : il stocke `TimeOfLastGetAllScan = time()`, puis calcule le temps restant avec `15 * 60`. Auctioneer/Auc-Advanced fait pareil avec `900 = 15 * 60 sec = 15 min`. ([GitHub][5])

Sur le scope exact — personnage, compte, realm, session client — je n’ai pas trouvé de source Blizzard ou FrameXML claire. La bonne stratégie est donc : **ne pas deviner le scope**. À chaque ouverture de l’HdV, appelle `CanSendAuctionQuery()` et fais confiance à `canQueryAll`. Tu peux stocker ton propre `lastFullScanTime` uniquement pour afficher un message utilisateur, pas comme autorité.

---

## 4. Limitations et pièges

Il n’y a pas de limite officielle clairement documentée dans les sources que j’ai trouvées. Les docs disent “entire auction house as one single page”, mais des retours terrain montrent des listes énormes — par exemple un full scan avec `59607` enchères — et des issues Auctionator récentes signalent des cas où le full scan semble ne pas couvrir autant d’enchères qu’attendu sur certains environnements Classic/Cata/SoD. Donc je ne baserais pas CraftGold sur l’hypothèse “impossible d’être tronqué”, même si l’API est censée renvoyer tout. ([addonstudio.org][1])

Le risque de déconnexion/freezing est réel. La doc `QueryAuctionItems` avertit que `getAll` peut déconnecter les joueurs avec faible bande passante, et la doc `GetAuctionItemInfo` explique que certaines infos — notamment résolution GUID→nom du vendeur — peuvent générer du trafic client→serveur ; sur un full scan, faire ça massivement peut suffire à se déconnecter si ce n’est pas throttlé. ([addonstudio.org][1])

Le piège important pour CraftGold : **ne lis pas plus que nécessaire**. Pour calculer des prix de craft, tu as principalement besoin de `itemId`, `count`, `buyoutPrice`, éventuellement `minBid`. Évite `owner`, évite les liens si tu n’en as pas besoin, évite de déclencher des résolutions asynchrones d’items à grande échelle. `GetAuctionItemInfo` retourne déjà `count`, `buyoutPrice`, `itemId`, `hasAllInfo`. ([Vanilla WoW Archive][6])

Autre piège : la Blizzard Auction UI peut ne pas aimer le résultat `getAll`. Un rapport WoWInterface montre un full scan `QueryAuctionItems("", ..., true, ...)` qui déclenche une erreur dans `Blizzard_AuctionUI.lua`, avec `quality = -1`. Auctionator contourne explicitement ça en ajoutant `ITEM_QUALITY_COLORS[-1]` avant son full scan, et en désenregistrant temporairement les autres frames de `AUCTION_ITEM_LIST_UPDATE`. ([WoWInterface][7])

Le pattern recommandé est donc :

1. Vérifier `canQueryAll`.
2. Lancer un unique `QueryAuctionItems(..., getAll=true, ...)`.
3. Attendre `AUCTION_ITEM_LIST_UPDATE`.
4. Lire `GetNumAuctionItems("list")`.
5. Traiter les résultats **par batch** pour éviter un freeze UI.
6. Ne collecter que les champs nécessaires.
7. Restaurer les events si tu as désenregistré des frames Blizzard/addons.

Auctionator traite par batches de `250` entrées et relance le batch suivant via `C_Timer.After(0.01, ...)`, ce qui est une bonne inspiration pour ne pas bloquer le client. ([GitHub][5])

---

## 5. Exemple minimal robuste pour CraftGold

Version orientée CraftGold : pas de `GetAuctionItemLink`, pas de vendeur, pas de résolution de nom. On stocke seulement `{ itemID = { {count=N, buyout=N, buyoutEach=N}, ... } }`.

```lua
-- CraftGold_FullScan.lua
-- Minimal full AH scan for WoW Classic Era old AH API.
-- Requires the Auction House window to be open.

CraftGoldDB = CraftGoldDB or {}
CraftGoldDB.fullScan = CraftGoldDB.fullScan or {}

local FullScan = CreateFrame("Frame")
FullScan.active = false
FullScan.results = nil
FullScan.savedEventFrames = nil

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CraftGold|r: " .. tostring(msg))
end

local function SaveAndSilenceAuctionListUpdateFrames(self)
  -- Optional but recommended: avoid Blizzard_AuctionUI trying to render the getAll list.
  -- Auctionator does something similar.
  self.savedEventFrames = { GetFramesRegisteredForEvent("AUCTION_ITEM_LIST_UPDATE") }

  for _, frame in ipairs(self.savedEventFrames) do
    if frame ~= self then
      frame:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
    end
  end
end

local function RestoreAuctionListUpdateFrames(self)
  if not self.savedEventFrames then
    return
  end

  for _, frame in ipairs(self.savedEventFrames) do
    if frame ~= self then
      frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    end
  end

  self.savedEventFrames = nil
end

local function StoreAuction(results, itemID, count, buyoutPrice)
  if not itemID or itemID <= 0 then
    return
  end

  if not count or count <= 0 then
    return
  end

  -- buyoutPrice == 0 means "no buyout"; useless for direct crafting cost.
  if not buyoutPrice or buyoutPrice <= 0 then
    return
  end

  local bucket = results[itemID]
  if bucket == nil then
    bucket = {}
    results[itemID] = bucket
  end

  table.insert(bucket, {
    count = count,
    buyout = buyoutPrice,
    buyoutEach = math.ceil(buyoutPrice / count),
  })
end

function FullScan:CanStart()
  if self.active then
    return false, "scan already in progress"
  end

  if AuctionFrame == nil or not AuctionFrame:IsShown() then
    return false, "open the Auction House first"
  end

  local canQuery, canQueryAll = CanSendAuctionQuery()
  if not canQueryAll then
    return false, "full scan cooldown active"
  end

  return true
end

function FullScan:Start()
  local ok, reason = self:CanStart()
  if not ok then
    Print("Cannot start full scan: " .. reason)
    return false
  end

  self.active = true
  self.results = {}
  self.startedAt = time()

  -- Defensive patch used by Auctionator too:
  -- some getAll results can have quality = -1 and Blizzard UI may error.
  if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[-1] == nil then
    ITEM_QUALITY_COLORS[-1] = { r = 0, g = 0, b = 0 }
  end

  SaveAndSilenceAuctionListUpdateFrames(self)

  self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
  self:RegisterEvent("AUCTION_HOUSE_CLOSED")

  Print("Starting full AH scan...")

  -- Classic Era old AH API:
  -- text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData
  QueryAuctionItems("", nil, nil, 0, false, nil, true, false, nil)

  return true
end

function FullScan:Finish(success, message)
  self:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  self:UnregisterEvent("AUCTION_HOUSE_CLOSED")
  RestoreAuctionListUpdateFrames(self)

  self.active = false

  if success then
    CraftGoldDB.fullScan = {
      scannedAt = time(),
      auctionsByItemID = self.results,
    }

    local itemKinds = 0
    for _ in pairs(self.results) do
      itemKinds = itemKinds + 1
    end

    Print("Full scan complete: " .. itemKinds .. " distinct itemIDs.")
  else
    Print("Full scan failed: " .. tostring(message))
  end

  self.results = nil
end

function FullScan:ProcessResults()
  local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")

  -- In getAll mode, these should normally be equal.
  if totalAuctions and numBatchAuctions ~= totalAuctions then
    Print("Warning: batch != total (" .. tostring(numBatchAuctions) .. " / " .. tostring(totalAuctions) .. "). This may not be a true getAll result.")
  end

  local total = numBatchAuctions or 0
  local index = 1
  local batchSize = 500

  local function ProcessChunk()
    if not self.active then
      return
    end

    local stop = math.min(index + batchSize - 1, total)

    for i = index, stop do
      local name,
            texture,
            count,
            quality,
            canUse,
            level,
            levelColHeader,
            minBid,
            minIncrement,
            buyoutPrice,
            bidAmount,
            highBidder,
            bidderFullName,
            owner,
            ownerFullName,
            saleStatus,
            itemID,
            hasAllInfo = GetAuctionItemInfo("list", i)

      StoreAuction(self.results, itemID, count, buyoutPrice)
    end

    index = stop + 1

    if index <= total then
      C_Timer.After(0.01, ProcessChunk)
    else
      self:Finish(true)
    end
  end

  Print("Received " .. tostring(numBatchAuctions) .. " auctions; processing...")
  ProcessChunk()
end

FullScan:SetScript("OnEvent", function(self, event)
  if event == "AUCTION_ITEM_LIST_UPDATE" then
    -- One server response for getAll.
    self:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
    self:ProcessResults()

  elseif event == "AUCTION_HOUSE_CLOSED" then
    if self.active then
      self:Finish(false, "auction house closed")
    end
  end
end)

-- Slash command for testing:
SLASH_CRAFTGOLDFULLSCAN1 = "/cgfullscan"
SlashCmdList.CRAFTGOLDFULLSCAN = function()
  FullScan:Start()
end
```

Notes sur ce code :

* La boucle utilise les index `1..numBatchAuctions`, cohérents avec la doc `GetAuctionItemInfo`, qui décrit l’index comme normalement `1-50` pour une page classique. ([Vanilla WoW Archive][6])
* Le traitement par chunks évite un gros freeze Lua si l’HdV retourne 50k+ lignes.
* La structure stockée est volontairement brute : plusieurs enchères par `itemID`, chacune avec `count`, `buyout`, `buyoutEach`.
* Pour ton calcul CraftGold, tu trieras ensuite `auctionsByItemID[itemID]` par `buyoutEach`, puis tu simuleras l’achat des stacks entiers.

---

## 6. Auctionator Classic / LegacyAH

Auctionator a bien un module de full scan pour l’ancienne AH. Dans le repo actuel, la partie ancienne AH est sous `Source_LegacyAH/FullScan`, avec des events `ScanStart`, `ScanProgress`, `ScanComplete`, `ScanFailed`. ([GitHub][8])

Auctionator utilise explicitement `getAll = true` :

```lua
QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)
```

Juste avant, il vérifie `CanSendAuctionQuery()` et utilise le second retour `canDoGetAll`. Il stocke aussi `TimeOfLastGetAllScan = time()` et affiche le prochain scan en calculant autour de `15 * 60`. ([GitHub][5])

Auctionator gère aussi deux pièges importants :

* Il patche `ITEM_QUALITY_COLORS[-1]` avant le full scan pour éviter une erreur côté UI Classic.
* Il désenregistre temporairement les autres frames de `AUCTION_ITEM_LIST_UPDATE`, puis les restaure après traitement. ([GitHub][5])

Après l’event `AUCTION_ITEM_LIST_UPDATE`, Auctionator appelle `GetNumAuctionItems("list")`, puis traite les résultats par batch de `250` avec `C_Timer.After(0.01, ...)`. Il récupère `GetAuctionItemInfo("list", index)`, parfois `GetAuctionItemLink`, attend le chargement des items si nécessaire, puis finit par merger les prix effectifs par clé d’item. ([GitHub][5])

Auctioneer/Auc-Advanced a un pattern similaire côté ancien code : il vérifie `CanSendAuctionQuery()`, refuse le scan si `CanQueryAll` est faux, utilise `900` secondes comme cooldown local, marque `private.isGetAll = true`, puis appelle `QueryAuctionItems(..., GetAll)`. ([GitHub][9])

---

## Recommandation pour CraftGold

Pour CraftGold, je ferais **deux modes** :

1. **Full scan rapide** : `getAll=true`, uniquement quand `canQueryAll` est vrai. C’est le meilleur mode pour construire une table globale des prix.
2. **Fallback ciblé** : requêtes paginées par item/nom si `canQueryAll` est faux, pour rafraîchir seulement les composants des recettes affichées.

Le full scan est parfait pour un snapshot global, mais il ne doit pas être ton unique chemin critique : cooldown long, risque de freeze/déco, résultats massifs, et comportement possiblement fragile selon les versions Classic. Le bon design est : **snapshot opportuniste + cache SavedVariables + refresh ciblé quand nécessaire**.

[1]: https://addonstudio.org/wiki/WoW%3AAPI_QueryAuctionItems "WoW API: QueryAuctionItems - AddOn Studio"
[2]: https://addonstudio.org/wiki/WoW%3AAPI_GetNumAuctionItems "WoW API: GetNumAuctionItems - AddOn Studio"
[3]: https://warcraft.wiki.gg/wiki/API_CanSendAuctionQuery?utm_source=chatgpt.com "CanSendAuctionQuery - Warcraft Wiki"
[4]: https://addonstudio.org/wiki/WoW%3AAPI_CanSendAuctionQuery "WoW API: CanSendAuctionQuery - AddOn Studio"
[5]: https://github.com/TheMouseNest/Auctionator/blob/master/Source_LegacyAH/FullScan/Mixins/Frame.lua "Auctionator/Source_LegacyAH/FullScan/Mixins/Frame.lua at master · TheMouseNest/Auctionator · GitHub"
[6]: https://vanilla-wow-archive.fandom.com/wiki/API_GetAuctionItemInfo "API GetAuctionItemInfo | Vanilla WoW Wiki | Fandom"
[7]: https://wowinterface.com/forums/showthread.php?t=53939 "QueryAuctionItems causes error in Blizzard_AuctionUI.lua - WoWInterface"
[8]: https://github.com/TheMouseNest/Auctionator/tree/master/Source_LegacyAH/FullScan "Auctionator/Source_LegacyAH/FullScan at master · TheMouseNest/Auctionator · GitHub"
[9]: https://github.com/ckrebs95/WoW/blob/master/interface/AddOns/Auc-Advanced/CoreScan.lua "WoW/interface/AddOns/Auc-Advanced/CoreScan.lua at master · ckrebs95/WoW · GitHub"
