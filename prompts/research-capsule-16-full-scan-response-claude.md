# Full scan HdV en Classic Era 1.15.x — Résultats de recherche

**TL;DR : oui, `getAll = true` fonctionne en Classic Era et c'est exactement ce qu'Auctionator utilise.** J'ai cloné le dépôt officiel d'Auctionator pour vérifier le code source réel chargé en 1.15.8 — détails et sources ci-dessous.

---

## 1. `getAll = true` — comportement exact

D'après Wowpedia, les queries normales sont throttlées à ~0,3 s, tandis que le mode getAll est limité à une fois toutes les 15 minutes ; les deux modes sont signalés par les valeurs de retour de `CanSendAuctionQuery()`.

- **Tout arrive en une seule "page" géante.** Le mode getAll télécharge l'intégralité de l'HdV comme une seule page. Après l'événement `AUCTION_ITEM_LIST_UPDATE`, `GetNumAuctionItems("list")` retourne `numBatchAuctions == totalAuctions` (le batch EST la totalité). Le paramètre `page` est ignoré dans ce mode — pas de pagination.
- **`text = ""` est bien la bonne façon de demander "tout".** C'est littéralement l'appel d'Auctionator dans son code Classic (voir §6) : `QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)`.
- Attention : l'événement `AUCTION_ITEM_LIST_UPDATE` ne se déclenche qu'**une fois** que le serveur a fini d'envoyer le snapshot — sur un gros HdV ça peut prendre 10–30 secondes (et ~20 secondes pour retourner toutes les enchères selon des retours d'utilisateurs d'Auctionator).

Sources : https://wowpedia.fandom.com/wiki/API_QueryAuctionItems · https://wowwiki-archive.fandom.com/wiki/API_QueryAuctionItems

## 2. `CanSendAuctionQuery()` — retour exact

```lua
local canQuery, canQueryAll = CanSendAuctionQuery()  -- SANS argument
```

- **Deux valeurs de retour.** `canQuery` (booléen, vrai si une query normale est possible) et `canQueryAll` (booléen, vrai si une query getAll est possible ; ajouté en 2.3). Les queries getAll ne sont autorisées qu'environ toutes les 15 minutes.
- **Oui, `canQueryAll` existe en Classic Era.** Preuve directe : le code d'Auctionator chargé en Era fait exactement `local _, canDoGetAll = CanSendAuctionQuery()` et n'autorise le full scan que si ce second retour est vrai ([Source_LegacyAH/FullScan/Mixins/Frame.lua](https://github.com/TheMouseNest/Auctionator/blob/master/Source_LegacyAH/FullScan/Mixins/Frame.lua)).
- Le paramètre `"list"` que tu mentionnes n'existe pas pour cette fonction — elle se prend sans argument.

Source : https://warcraft.wiki.gg/wiki/API_CanSendAuctionQuery

## 3. Cooldown du full scan

- **~15 minutes**, confirmé par toutes les sources (wiki + code Auctionator qui affiche un compte à rebours basé sur `15 - minutes écoulées`).
- **Par compte**, pas par personnage : le scan GetAll ne peut être fait qu'une fois toutes les 15 minutes par compte, et cela inclut tous les addons susceptibles de l'utiliser. Changer de perso ne reset pas le cooldown.
- Le cooldown est **côté serveur** : si tu appelles getAll trop tôt, soit rien ne se passe, soit tu reçois une page quasi vide. C'est pourquoi il faut vérifier `canQueryAll` ET mémoriser localement `time()` du dernier scan (Auctionator fait les deux, car `canQueryAll` ne dit pas combien de temps il reste).

Sources : https://www.mmo-champion.com/threads/1337281-Auctioneer-Which-Scan-to-use · https://wowwiki-archive.fandom.com/wiki/API_CanSendAuctionQuery

## 4. Limitations et pièges

1. **Limite de résultats** : en 4.0.1, le mode getAll ne récupérait que jusqu'à 42 554 items, ce qui suffit en général mais peut être dépassé sur les royaumes très peuplés. En Classic Era officiel, les HdV dépassent rarement ce seuil, mais des utilisateurs ont signalé sur SoD et Cata Classic que le full scan d'Auctionator semblait plafonner autour de ~22k items alors que davantage d'enchères existaient — donc considère le résultat comme un *snapshot possiblement incomplet* sur méga-realms.
2. **Risque de déconnexion** : le mode getAll peut déconnecter les joueurs à faible bande passante. C'est le piège n°1 historiquement. Auctionator propose d'ailleurs un mode alternatif : "le mode de scan rapide peut causer des déconnexions sur les serveurs chargés ; ce réglage utilise une méthode de scan plus lente mais moins susceptible de déconnecter" (= scan paginé classique).
3. **Freeze du client** : le vrai danger n'est pas la query mais le **traitement**. Si tu itères 30 000 × `GetAuctionItemInfo` dans une seule frame, le client gèle plusieurs secondes. Pire : les *autres* addons écoutant `AUCTION_ITEM_LIST_UPDATE` vont eux aussi traiter la liste géante. Auctionator contourne ça en **désenregistrant temporairement tous les autres frames** de cet événement pendant le scan (via `GetFramesRegisteredForEvent`), puis en les ré-enregistrant à la fin.
4. **Items non cachés** : `GetAuctionItemInfo` retourne `name = nil` et `GetAuctionItemLink` retourne `nil` pour les items absents du cache client. Il faut `Item:CreateFromItemID(itemID):ContinueOnItemLoad(...)` pour les résoudre. En revanche `count`, `buyoutPrice`, `minBid` et `itemId` sont disponibles immédiatement — si tu ne veux que itemID/count/buyout, tu peux ignorer le chargement asynchrone.
5. **`text` > 63 octets = déconnexion** (pas un souci avec `""`).
6. **Fiabilité variable** : la fonctionnalité dépend du serveur ; par exemple un utilisateur rapporte que sur l'anniversary, le full scan d'Auctionator reste bloqué à 10 % depuis le pré-patch. Prévois un timeout/fallback.

**Pattern recommandé** (celui d'Auctionator) : vérifier `canQueryAll` → désenregistrer les autres listeners → `QueryAuctionItems("", ..., true, ...)` → attendre `AUCTION_ITEM_LIST_UPDATE` (une seule fois) → traiter par **batchs de 250 items** espacés de `C_Timer.After(0.01)` pour ne pas freezer → gérer `AUCTION_HOUSE_CLOSED` comme échec du scan.

## 5. Exemple de code complet (Classic Era 1.15.x)

Adapté directement du pattern Auctionator, simplifié pour ta structure `{ itemID = { {count, buyout}, ... } }` :

```lua
local CraftGoldScanner = CreateFrame("Frame")
local BATCH_SIZE = 250

local scanner = {
  inProgress = false,
  results = {},          -- { [itemID] = { {count=N, buyout=N}, ... } }
  lastGetAll = 0,        -- mémorise localement le dernier scan
  suspendedFrames = {},
}

-- 1. Vérifier qu'on peut lancer un full scan
function scanner:CanFullScan()
  local _, canQueryAll = CanSendAuctionQuery()
  return canQueryAll and AuctionFrame and AuctionFrame:IsShown()
end

-- 2. Lancer le scan
function scanner:Start()
  if self.inProgress then return end
  if not self:CanFullScan() then
    local remaining = math.max(0, 900 - (time() - self.lastGetAll))
    print(("CraftGold: full scan indisponible (~%d min %d s restantes)")
      :format(math.floor(remaining/60), remaining % 60))
    return
  end

  self.inProgress = true
  self.results = {}
  self.lastGetAll = time()

  -- Évite que les autres addons/l'UI Blizzard traitent la liste géante
  self.suspendedFrames = { GetFramesRegisteredForEvent("AUCTION_ITEM_LIST_UPDATE") }
  for _, f in ipairs(self.suspendedFrames) do
    f:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  end

  CraftGoldScanner:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
  CraftGoldScanner:RegisterEvent("AUCTION_HOUSE_CLOSED")

  -- getAll = true ; les autres filtres doivent être vides/nil
  QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)
end

-- 3. Collecter les résultats par batchs (anti-freeze)
function scanner:ProcessBatch(startIndex, total)
  if startIndex > total then
    self:Finish(total)
    return
  end
  for i = startIndex, math.min(startIndex + BATCH_SIZE - 1, total) do
    -- count(3), buyout(10), itemId(17) sont dispo même sans cache item
    local _, _, count, _, _, _, _, _, _, buyout,
          _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
    if itemID and itemID ~= 0 and buyout and buyout > 0 then
      self.results[itemID] = self.results[itemID] or {}
      table.insert(self.results[itemID], { count = count, buyout = buyout })
    end
  end
  C_Timer.After(0.01, function()
    self:ProcessBatch(startIndex + BATCH_SIZE, total)
  end)
end

-- 4. Fin de scan
function scanner:Finish(total)
  self.inProgress = false
  self:RestoreListeners()
  print(("CraftGold: full scan terminé, %d enchères."):format(total))
  -- self.results est prêt : { [itemID] = { {count=, buyout=}, ... } }
end

function scanner:RestoreListeners()
  CraftGoldScanner:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  CraftGoldScanner:UnregisterEvent("AUCTION_HOUSE_CLOSED")
  for _, f in ipairs(self.suspendedFrames) do
    f:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
  end
  self.suspendedFrames = {}
end

CraftGoldScanner:SetScript("OnEvent", function(_, event)
  if event == "AUCTION_ITEM_LIST_UPDATE" and scanner.inProgress then
    -- Un seul événement attendu en mode getAll : on se désabonne tout de suite
    CraftGoldScanner:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
    local numBatch, totalAuctions = GetNumAuctionItems("list")
    -- en getAll : numBatch == totalAuctions
    scanner:ProcessBatch(1, numBatch)
  elseif event == "AUCTION_HOUSE_CLOSED" and scanner.inProgress then
    scanner.inProgress = false
    scanner:RestoreListeners()
    print("CraftGold: scan interrompu (HdV fermé).")
  end
end)

-- Usage : /run CraftGold_FullScan()
function CraftGold_FullScan() scanner:Start() end
```

Notes : si tu as besoin du **nom/lien** des items (pas seulement itemID), il faut ajouter la résolution asynchrone `Item:CreateFromItemID(itemID):ContinueOnItemLoad(...)` comme le fait Auctionator — pour des prix par itemID, c'est inutile. Garde aussi un timeout (ex. 30 s) au cas où `AUCTION_ITEM_LIST_UPDATE` ne vient jamais (cooldown serveur silencieux).

## 6. Auctionator Classic — comment il procède exactement

Code source accessible : dépôt officiel [TheMouseNest/Auctionator](https://github.com/TheMouseNest/Auctionator). Le `.toc` (`## Interface: ... 11508`) charge `Source_LegacyAH\Manifest.xml [AllowLoadGameType vanilla, tbc, wrath]` — c'est donc **`Source_LegacyAH/FullScan/Mixins/Frame.lua`** qui tourne en Classic Era (le dossier `Source_Mainline`, lui, utilise `C_AuctionHouse.ReplicateItems()`, l'équivalent Retail post-8.3).

Ce que fait le module FullScan Classic, ligne par ligne :

1. **`CanInitiate()`** : `local _, canDoGetAll = CanSendAuctionQuery()` — n'autorise que si le 2ᵉ retour est vrai.
2. **Lancement** : `QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)` — donc **oui, `getAll = true`**, pas une autre méthode.
3. **Cooldown** : stocke `TimeOfLastGetAllScan = time()` dans ses SavedVariables et calcule le temps restant sur une base de **15 minutes** pour le message "prochain scan dans X min".
4. **Anti-freeze** : avant la query, il désenregistre tous les autres frames écoutant `AUCTION_ITEM_LIST_UPDATE` (récupérés via `GetFramesRegisteredForEvent`), et les ré-enregistre à la fin.
5. **Collecte** : au premier `AUCTION_ITEM_LIST_UPDATE`, il lit `GetNumAuctionItems("list")` puis traite par **batchs de 250** avec `C_Timer.After(0.01)` entre chaque batch ; pour chaque index il prend `GetAuctionItemInfo("list", i)` + `GetAuctionItemLink`, et résout les items non cachés via `Item:CreateFromItemID():ContinueOnItemLoad()`.
6. **Fin** : quand le compteur `waitingForData` tombe à 0 (avec un filet de sécurité `C_Timer.After(2, ...)`), il agrège en `{ [dbKey] = { {price=buyout/count, available=count}, ... } }` — quasi identique à ta structure cible — et déclenche `ScanComplete`. `AUCTION_HOUSE_CLOSED` pendant le scan = échec propre.

Fichier exact : https://github.com/TheMouseNest/Auctionator/blob/master/Source_LegacyAH/FullScan/Mixins/Frame.lua

---

**En résumé pour CraftGold** : ton approche est la bonne et validée par Auctionator en production sur 1.15.x. Les trois points critiques à ne pas rater : (a) vérifier le **2ᵉ retour** de `CanSendAuctionQuery()` + tracker le cooldown 15 min toi-même (par compte), (b) **désenregistrer les autres listeners** de `AUCTION_ITEM_LIST_UPDATE` pendant le scan, (c) traiter par **batchs throttlés** pour ne pas freezer le client, en acceptant que le snapshot puisse être incomplet sur un HdV énorme.