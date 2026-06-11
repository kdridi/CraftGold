# API WoW Classic Era — Référence validée

> Source : recherche LLM externe (Session 1). Voir `prompts/research-wow-api-response.md` pour les réponses brutes.

## Version d'interface

- Classic Era patch 1.15.8 → Interface **11508**
- Vérifier en jeu : `/dump select(4, GetBuildInfo())`
- Ce numéro change avec les patches — toujours vérifier avant de mettre à jour les fichiers `.toc`

---

## API Trade Skill (`C_TradeSkillUI`)

**Disponible en Classic Era** — version pré-10.0. Les notes « Removed in 10.0.0 » sur le wiki sont **Retail-only**.

### Fonctions

```lua
-- Lister tous les IDs de recette pour le métier actuellement ouvert
recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()

-- Obtenir les détails d'une recette
info = C_TradeSkillUI.GetRecipeInfo(recipeID)
-- Retourne : .recipeID, .name, .learned, .icon, .numAvailable

-- Obtenir le nombre de composants d'une recette
numReagents = C_TradeSkillUI.GetRecipeNumReagents(recipeID)

-- Obtenir les détails d'un composant (index : 1 à numReagents)
name, icon, requiredCount, playerCount = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, reagentIndex)

-- Obtenir l'item link d'un composant (pour extraire l'itemID)
itemLink = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, reagentIndex)
itemID = itemLink and GetItemInfoInstant(itemLink)
```

### Événements

- `TRADE_SKILL_SHOW` — se déclenche quand la fenêtre de métier s'ouvre
- `TRADE_SKILL_LIST_UPDATE` — se déclenche quand les données du métier sont prêtes
- Toujours attendre `TRADE_SKILL_LIST_UPDATE` avant de faire des requêtes

### Limitation critique

**Ne montre que les recettes que le personnage a APPRISES.** Impossible d'énumérer les recettes non apprises. C'est pourquoi CraftGold v1 utilise une base de données statique pour le leveling planner.

### Exemple : lister toutes les recettes apprises avec leurs composants

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
f:SetScript("OnEvent", function()
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned then
            print("Recipe:", info.name, "(", id, ")")
            local n = C_TradeSkillUI.GetRecipeNumReagents(id)
            for i = 1, n do
                local name, _, reqCount, have =
                    C_TradeSkillUI.GetRecipeReagentInfo(id, i)
                local link = C_TradeSkillUI.GetRecipeReagentItemLink(id, i)
                local itemID = link and GetItemInfoInstant(link)
                print(string.format("  %s x%d (itemID %s, have %d)",
                    name or "?", reqCount or 0, tostring(itemID), have or 0))
            end
        end
    end
end)
```

### Pièges

- L'API retourne des tables vides si la fenêtre de métier n'est pas ouverte
- `GetRecipeReagentItemLink` peut retourner nil si l'item n'est pas en cache
- Le premier `TRADE_SKILL_LIST_UPDATE` peut arriver avant que tous les items soient en cache
- Utiliser `GetItemInfoInstant()` pour l'itemID (fonctionne sur les items non cachés), `GetItemInfo()` seulement quand on a besoin du nom/prix/etc.

---

## API Hôtel des Ventes

**`C_AuctionHouse` n'existe PAS en Classic Era.** Il a été ajouté dans Retail 8.3. Classic Era utilise l'ancienne API.

### Fonctions

```lua
-- Vérifier si une requête est autorisée
canQuery, canQueryAll = CanSendAuctionQuery()

-- Recherche par NOM (pas par itemID !)
-- page commence à 0, 50 résultats par page
QueryAuctionItems(text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)

-- Obtenir le nombre de résultats
numOnPage, totalAuctions = GetNumAuctionItems("list")

-- Obtenir les détails d'une enchère (index : 1 à numOnPage)
name, texture, count, quality, canUse, level, levelColHeader, minBid,
minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,
ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", index)
```

### Événements

- `AUCTION_ITEM_LIST_UPDATE` — se déclenche quand les résultats de la requête sont prêts
- Peut se déclencher **plusieurs fois** au fur et à mesure que les données se résolvent (vérifier `hasAllInfo`)
- `AUCTION_HOUSE_SHOW` — se déclenche quand l'HdV s'ouvre
- `AUCTION_HOUSE_CLOSED` — se déclenche quand l'HdV se ferme

### Pièges découverts en jeu (Session 17)

1. **`QueryAuctionItems` échoue silencieusement** si l'HdV n'est pas ouvert. Aucun événement `AUCTION_ITEM_LIST_UPDATE` ne se déclenche. Le scanner peut rester bloqué dans l'état "active" à jamais si l'HdV est fermé entre le lancement du scan et la réception des résultats.
2. **`CanSendAuctionQuery()`** — le code source Blizzard appelle `CanSendAuctionQuery("list")` avec un argument, mais la version sans argument fonctionne aussi.
3. **`exactMatch=true`** — le code Blizzard extrait le texte entre guillemets (`"Copper Bar"`) et active `exactMatch`. Sans guillemets, c'est une recherche de sous-chaîne.

### Exemple : trouver le buyout le moins cher pour un item

```lua
local TARGET_ITEM_ID = 13468  -- Black Lotus

local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")

local function StartSearch()
    local canQuery = CanSendAuctionQuery()
    if not canQuery then return false end
    local name = GetItemInfo(TARGET_ITEM_ID)
    if not name then return false end  -- item pas en cache
    QueryAuctionItems(name, nil, nil, 0, nil, nil, false, true, nil)
    return true
end

f:SetScript("OnEvent", function()
    local numOnPage = GetNumAuctionItems("list")
    local bestPerUnit
    for i = 1, numOnPage do
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemId =
            GetAuctionItemInfo("list", i)
        if itemId == TARGET_ITEM_ID and buyout and buyout > 0 and count > 0 then
            local perUnit = buyout / count
            if not bestPerUnit or perUnit < bestPerUnit then
                bestPerUnit = perUnit
            end
        end
    end
    if bestPerUnit then
        print("Min buyout per unit:", GetCoinTextureString(math.floor(bestPerUnit)))
    end
end)
```

### Pièges

1. **`buyoutPrice` est par STACK, pas par unité.** Diviser par `count`. C'est le bug #1 du scan HdV.
2. **La recherche est par chaîne de nom**, pas par itemID. Résoudre itemID → nom via `GetItemInfo()` d'abord.
3. **Asynchrone.** Attendre `AUCTION_ITEM_LIST_UPDATE` après `QueryAuctionItems()`.
4. **Pagination.** 50 résultats/page. Boucler sur les pages pour les grands résultats.
5. **Throttling.** ~0,3s entre les requêtes, 15min pour le mode getAll.
6. **La fenêtre de l'HdV doit être ouverte.** Les requêtes échouent silencieusement sinon.
7. **L'item doit être en cache.** `GetItemInfo(itemID)` peut retourner nil au premier appel.

### Formatage des prix

```lua
-- Convertir un montant en cuivre en chaîne lisible
GetCoinTextureString(copperAmount)  -- "2g 50s 12c" (avec icônes)
```
