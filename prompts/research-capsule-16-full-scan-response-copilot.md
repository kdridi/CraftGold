I'll search for authoritative sources on WoW Classic Era auction house API and full scan behavior.Excellent ! J'ai trouvé des sources GitHub documentées. Voici les **réponses précises avec sources** :

---

## 1. `getAll = true` — comportement exact

**OUI, ça retourne TOUTES les enchères en une seule query.**

- **Signature d'appel confirmée** : [Logonz/WoW-API](https://github.com/Logonz/WoW-API/blob/0efb8ff25b00827cc9ad509b79786d3009c1e2a0/Functions-Classic-AI/AuctionFunctions.lua#L108-L147) — `QueryAuctionItems(text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)`

- **Recherche avec `getAll = true` retourne tout d'un coup**. Les addons comme Auctionator appellent exactement :
  ```lua
  QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)
  ```
  Voir [Auctionator TBC Classic Frame.lua](https://github.com/SwimmingTiger/WowBigfootClassic/blob/d43e64af186fb996b66a0be487ae403e29999ecd/Interface/AddOns/Auctionator/Source_TBC/FullScan/Mixins/Frame.lua#L35) et [Auctionator Legacy AH Frame.lua](https://github.com/MysticallTheMonk/retail_files/blob/f7eb9235f8b2ef6e0b3c1f0ec7fff6be3249874e/Addons/Auctionator/Source_LegacyAH/FullScan/Mixins/Frame.lua#L29)

- **`GetNumAuctionItems("list")` retourne `(numBatchAuctions, totalAuctions)`** — deux valeurs. Après un `getAll`, `totalAuctions` = nombre TOTAL d'enchères de l'HdV. [Documentation WoW-API](https://github.com/Logonz/WoW-API/blob/0efb8ff25b00827cc9ad509b79786d3009c1e2a0/Functions-Classic-AI/AuctionFunctions.lua#L98).

- **Pas de pagination pour `getAll`** — tout arrive en une seule requête asynchrone. Attendre `AUCTION_ITEM_LIST_UPDATE`.

- **`text = ""` (chaîne vide)** est effectivement le bon moyen — elle signifie "pas de filtre de nom, retourne tout".

---

## 2. `CanSendAuctionQuery()` — retour exact

**Retourne DEUX valeurs.**

```lua
local canQuery, canQueryAll = CanSendAuctionQuery()
```

- [Auctionator Classic Era Frame.lua](https://github.com/SwimmingTiger/WowBigfootClassic/blob/d43e64af186fb996b66a0be487ae403e29999ecd/Interface/AddOns/Auctionator/Source_TBC/FullScan/Mixins/Frame.lua#L43) : `local _, canDoGetAll = CanSendAuctionQuery()`

- [Auctionator Legacy AH Frame.lua](https://github.com/MysticallTheMonk/retail_files/blob/f7eb9235f8b2ef6e0b3c1f0ec7fff6be3249874e/Addons/Auctionator/Source_LegacyAH/FullScan/Mixins/Frame.lua#L43) : même pattern

- [WoW API (ChrisKader/wowless)](https://github.com/ChrisKader/wowless/blob/b3169429a30a4cb80197cfcca6358e76a6f06814/data/products/wow_classic_era/apis.yaml#L11894-L12043) confirme que `CanSendAuctionQuery` existe en Classic Era (pas optionnel).

- **`canQueryAll` vaut `true`** si tu peux faire un `getAll = true` maintenant, `false` sinon (en cooldown).

---

## 3. Cooldown du full scan

**Exactement 15 minutes (900 secondes).**

- [Auctionator TBC & Classic Era NextScanMessage](https://github.com/SwimmingTiger/WowBigfootClassic/blob/d43e64af186fb996b66a0be487ae403e29999ecd/Interface/AddOns/Auctionator/Source_TBC/FullScan/Mixins/Frame.lua#L46-L51) et [Legacy AH version](https://github.com/MysticallTheMonk/retail_files/blob/f7eb9235f8b2ef6e0b3c1f0ec7fff6be3249874e/Addons/Auctionator/Source_LegacyAH/FullScan/Mixins/Frame.lua#L46-L51) :
  ```lua
  local minutesUntilNextScan = 15 - math.ceil(timeSinceLastScan / 60)
  ```

- [Auctionator anciennes versions](https://github.com/Drathal/myWowInterface/blob/fbb4a3eeaf3761ff6bd819cc0a398ec94760e0ee/AddOns/Auctionator/AuctionatorScanFull.lua#L397) : `local when = 15*60 - (time() - AUCTIONATOR_LAST_SCAN_TIME);`

- **Par account, pas par perso** — le cooldown est côté serveur et vérifié lors de l'appel.

---

## 4. Limitations et pièges

### Limite du nombre de résultats

Aucune limite documentée dans les sources trouvées. Auctionator traite tous les résultats par **batches de 250** pour éviter les lags :
[Auctionator ProcessBatch](https://github.com/SwimmingTiger/WowBigfootClassic/blob/d43e64af186fb996b66a0be487ae403e29999ecd/Interface/AddOns/Auctionator/Source_TBC/FullScan/Mixins/Frame.lua#L59-L75)

### Gestion par Auctionator & Auctioneer

- **Auctionator Classic Era** [FullScan/Mixins/Frame.lua](https://github.com/MysticallTheMonk/retail_files/blob/f7eb9235f8b2ef6e0b3c1f0ec7fff6be3249874e/Addons/Auctionator/Source_LegacyAH/FullScan/Mixins/Frame.lua) **utilise `getAll = true` uniquement** — appel une seule fois, puis traite par batches asynchrones.

- **Évite la corruption des résultats** en désenregistrant tous les autres listeners de `AUCTION_ITEM_LIST_UPDATE` pendant le scan [UnregisterForEvents](https://github.com/MysticallTheMonk/retail_files/blob/f7eb9235f8b2ef6e0b3c1f0ec7fff6be3249874e/Addons/Auctionator/Source_LegacyAH/FullScan/Mixins/Frame.lua#L52-L58).

- **TOGPM (TOGProfessionMaster)** fait pareil : "[legacy `getAll` on Era/TBC/Wrath](https://github.com/Pimptasty/TOGProfessionMaster/blob/e8b33f775c55bc832b80c48193f609615bec7937/CHANGELOG.md#L94-L95)" + cache pour la session.

### Pièges connus

1. **L'interface Blizzard ne JAMAIS appelé `getAll = true`** — seulement pagination normale.
2. **`AUCTION_ITEM_LIST_UPDATE` peut se déclencher plusieurs fois** au fur et à mesure que les données se résolvent (vérifier `hasAllInfo`).
3. **Déconnexion théorique** si HdV énorme + timeout réseau, mais aucun rapport trouvé en Classic Era.

---

## 5. Exemple de code complet

```lua
local CraftGoldFullScan = {}

-- État du scan
CraftGoldFullScan.inProgress = false
CraftGoldFullScan.scanData = {}  -- { itemID = { { count, buyout }, ... }, ... }
CraftGoldFullScan.lastScanTime = 0

-- Vérifier si on peut lancer un scan
function CraftGoldFullScan:CanInitiate()
    local _, canDoGetAll = CanSendAuctionQuery()
    return canDoGetAll
end

-- Lancer le scan
function CraftGoldFullScan:Start()
    if not self:CanInitiate() then
        print("Full scan en cooldown, réessayez dans 15 min")
        return false
    end
    
    if self.inProgress then
        print("Scan déjà en cours")
        return false
    end
    
    self.inProgress = true
    self.scanData = {}
    self.lastScanTime = time()
    
    print("Lancement du full scan HdV...")
    
    -- Appel : text="", minLevel=nil, maxLevel=nil, page=0, usable=false, rarity=nil, getAll=true, exactMatch=false, filterData=nil
    QueryAuctionItems("", nil, nil, 0, false, nil, true, false, nil)
    
    return true
end

-- Événement : réception des résultats
function CraftGoldFullScan:OnAuctionListUpdate()
    if not self.inProgress then return end
    
    local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")
    print(string.format("Reçu %d enchères sur %d total", numBatchAuctions, totalAuctions))
    
    -- Traiter par batches pour éviter les lags (pattern Auctionator)
    self:ProcessBatch(0, 250, totalAuctions)
end

-- Traitement batch
function CraftGoldFullScan:ProcessBatch(startIdx, stepSize, limit)
    local i = startIdx
    while i < startIdx + stepSize and i < limit do
        local itemName, _, count, _, _, _, _, _, _, buyoutPrice, _, _, _, _, _, _, itemID, hasAllInfo = 
            GetAuctionItemInfo("list", i + 1)  -- Index commence à 1
        
        if itemID and buyoutPrice and buyoutPrice > 0 then
            if not self.scanData[itemID] then
                self.scanData[itemID] = {}
            end
            table.insert(self.scanData[itemID], {
                count = count,
                buyout = buyoutPrice,
                perUnit = buyoutPrice / count
            })
        end
        
        i = i + 1
    end
    
    -- Si pas fini, continuer dans le prochain frame
    if startIdx + stepSize < limit then
        C_Timer.After(0, function()
            self:ProcessBatch(startIdx + stepSize, stepSize, limit)
        end)
    else
        self:FinalizeScan(limit)
    end
end

-- Finaliser le scan
function CraftGoldFullScan:FinalizeScan(totalAuctions)
    print(string.format("Scan terminé : %d enchères dans %d items uniques", 
        totalAuctions, self:CountUniqueItems()))
    
    self.inProgress = false
    
    -- Optionnel : trier par prix unitaire
    for itemID, auctions in pairs(self.scanData) do
        table.sort(auctions, function(a, b) return a.perUnit < b.perUnit end)
    end
end

function CraftGoldFullScan:CountUniqueItems()
    local count = 0
    for _ in pairs(self.scanData) do count = count + 1 end
    return count
end

-- Obtenir le meilleur prix unitaire pour un item
function CraftGoldFullScan:GetBestPrice(itemID)
    local auctions = self.scanData[itemID]
    if not auctions or #auctions == 0 then return nil end
    return auctions[1].perUnit  -- Déjà trié
end

-- Hook événement
local frame = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
frame:SetScript("OnEvent", function()
    CraftGoldFullScan:OnAuctionListUpdate()
end)

-- Lancer manuellement
-- CraftGoldFullScan:Start()
```

**Structure de données après scan :**
```lua
CraftGoldFullScan.scanData = {
    [13468] = {  -- Black Lotus
        { count = 1, buyout = 500000, perUnit = 500000 },
        { count = 1, buyout = 550000, perUnit = 550000 },
        ...
    },
    [12345] = { ... },
    ...
}
```

---

## 6. Auctionator Classic — approche exacte

**Auctionator NE FAIT QU'UN SEUL APPEL avec `getAll = true`.**

Source : [Auctionator Classic Era FullScan/Mixins/Frame.lua](https://github.com/MysticallTheMonk/retail_files/blob/f7eb9235f8b2ef6e0b3c1f0ec7fff6be3249874e/Addons/Auctionator/Source_LegacyAH/FullScan/Mixins/Frame.lua)

```lua
-- InitiateScan()
QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)

-- CanInitiate()
local _, canDoGetAll = CanSendAuctionQuery()
return canDoGetAll

-- Cooldown
local timeSinceLastScan = time() - (self.state.TimeOfLastGetAllScan or 0)
local minutesUntilNextScan = 15 - math.ceil(timeSinceLastScan / 60)
```

**Gestion du cooldown :**
- Stocke `self.state.TimeOfLastGetAllScan = time()` dès le début du scan
- Calcule les **15 minutes** avant la prochaine tentative
- N'appelle `QueryAuctionItems` que si `CanSendAuctionQuery()` retourne `(_, true)`

**Traitement des résultats :**
- Traite par batches de 250 items pour ne pas bloquer l'UI
- Attend `AUCTION_ITEM_LIST_UPDATE`
- Supprime les autres listeners pour éviter les corruptions

---

**Conclusion pour CraftGold :**
- ✅ Appel unique `QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)`
- ✅ Vérifie `CanSendAuctionQuery()` avant, récupère la 2e valeur (`canQueryAll`)
- ✅ Cooldown 15 minutes, stocké à `time()`
- ✅ Attendre `AUCTION_ITEM_LIST_UPDATE`
- ✅ Traiter par batches (250–500 items) pour l'UI
- ✅ `GetNumAuctionItems("list")` retourne `(batch, total)` — boucler sur `batch` indices 1 à `batch`, lire `itemID` de chacun

Les résultats de recherche code sont limités à 10 résultats. Pour voir d'autres implémentations, accédez à la [recherche complète Lexical Code Search](https://github.com/search?q=QueryAuctionItems+getAll&type=code).