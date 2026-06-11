# Recherche : Full scan AH via QueryAuctionItems getAll en Classic Era 1.15.x

## Contexte

CraftGold est un add-on WoW Classic Era (1.15.x, interface 11508). On veut implémenter un **full scan de l'HdV** — télécharger TOUTES les enchères en une seule query pour avoir les prix de tous les items d'un coup.

L'API disponible en Classic Era est l'ancienne API (pas `C_AuctionHouse` qui est Retail 8.3+).

## Ce qu'on sait déjà (validé par code source Blizzard exporté)

```lua
-- Signature complète (8 paramètres en Classic Era, le 9e filterData est optionnel)
QueryAuctionItems(text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)

-- L'UI Blizzard appelle TOUJOURS avec getAll = false :
QueryAuctionItems(text, minLevel, maxLevel, page, usable, rarity, false, exactMatch, filterData)

-- Résultats :
numBatchAuctions, totalAuctions = GetNumAuctionItems("list")
name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", index)

-- Événement :
AUCTION_ITEM_LIST_UPDATE — se déclenche quand les résultats sont prêts

-- Throttling pagination normale : ~0.3s entre queries
-- 50 résultats par page (NUM_AUCTION_ITEMS_PER_PAGE = 50)
```

## Questions précises

**Fais une vraie recherche web avec des sources.** Réponds en markdown dans un seul bloc texte (pas de fichiers séparés). Pour chaque affirmation, donne une source URL.

### 1. `getAll = true` — comportement exact

```lua
QueryAuctionItems("", nil, nil, 0, false, nil, true)  -- getAll = true
```

- Est-ce que ça retourne TOUTES les enchères de l'HdV en une seule query ?
- Combien de résultats ? `GetNumAuctionItems("list")` retourne quoi après un `getAll` ?
- Est-ce qu'il y a une pagination ou tout arrive d'un coup ?
- Est-ce que `text = ""` (chaîne vide) est le bon way de demander "tout" ?

### 2. `CanSendAuctionQuery()` — retour exact

```lua
local canQuery, canQueryAll = CanSendAuctionQuery()
-- ou
local canQuery, canQueryAll = CanSendAuctionQuery("list")
```

- Combien de valeurs retourne cette fonction ?
- `canQueryAll` existe-il en Classic Era ?
- Comment savoir si un full scan est autorisé ?

### 3. Cooldown du full scan

- Quel est le cooldown exact entre deux `getAll = true` ?
- 15 minutes ? Plus ? Moins ?
- Est-ce que le cooldown est par personnage ? Par compte ?

### 4. Limitations et pièges

- Y a-t-il une limite sur le nombre total d'enchères retournées ?
- Risque de déconnexion si l'HdV est très gros ?
- Comment les addons existants (Auctionator, Auctioneer) gèrent-ils le full scan en Classic Era ?
- Quel est le pattern recommandé ?

### 5. Exemple de code complet

Donne un exemple fonctionnel minimal pour faire un full scan en Classic Era :

```lua
-- 1. Vérifier qu'on peut lancer un full scan
-- 2. Lancer QueryAuctionItems avec getAll = true
-- 3. Collecter TOUS les résultats dans AUCTION_ITEM_LIST_UPDATE
-- 4. Savoir quand c'est terminé
-- 5. Structure de données résultante : { itemID = { {count=N, buyout=N}, ... } }
```

### 6. Auctionator Classic

Auctionator a un module FullScan en Classic. Comment procède-t-il exactement ?
- Code source ou documentation accessible ?
- Utilise-t-il `getAll = true` ou une autre méthode ?
- Comment gère-t-il le cooldown ?

## Environnement

- WoW Classic Era 1.15.x (patch 1.15.8, interface 11508)
- PAS Retail, PAS Wrath Classic
- API ancienne : `QueryAuctionItems`, `GetAuctionItemInfo`, pas `C_AuctionHouse`
