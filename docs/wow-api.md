# WoW Classic Era API — Validated Reference

> Source: external LLM research (Session 1). See `prompts/research-wow-api-response.md` for raw responses.

## Interface Version

- Classic Era patch 1.15.8 → Interface **11508**
- Verify in-game: `/dump select(4, GetBuildInfo())`
- This number changes with patches — always verify before updating `.toc` files

---

## Trade Skill API (`C_TradeSkillUI`)

**Available in Classic Era** — pre-10.0 version. "Removed in 10.0.0" notes on wiki are **Retail-only**.

### Functions

```lua
-- List all recipe IDs for the currently open profession
recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()

-- Get recipe details
info = C_TradeSkillUI.GetRecipeInfo(recipeID)
-- Returns: .recipeID, .name, .learned, .icon, .numAvailable

-- Get reagent count for a recipe
numReagents = C_TradeSkillUI.GetRecipeNumReagents(recipeID)

-- Get reagent details (index: 1 to numReagents)
name, icon, requiredCount, playerCount = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, reagentIndex)

-- Get reagent item link (for extracting itemID)
itemLink = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, reagentIndex)
itemID = itemLink and GetItemInfoInstant(itemLink)
```

### Events

- `TRADE_SKILL_SHOW` — fires when profession window opens
- `TRADE_SKILL_LIST_UPDATE` — fires when profession data is ready
- Always wait for `TRADE_SKILL_LIST_UPDATE` before querying

### Critical limitation

**Only shows recipes the character has LEARNED.** Cannot enumerate unlearned recipes. This is why CraftGold v1 uses a static database for the leveling planner.

### Example: Dump all learned recipes with reagents

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

### Gotchas

- API returns empty tables if profession window is not open
- `GetRecipeReagentItemLink` may return nil if item is not cached
- First `TRADE_SKILL_LIST_UPDATE` can arrive before all items are cached
- Use `GetItemInfoInstant()` for itemID (works on uncached items), `GetItemInfo()` only when you need name/price/etc.

---

## Auction House API

**`C_AuctionHouse` does NOT exist in Classic Era.** It was added in Retail 8.3. Classic Era uses the old API.

### Functions

```lua
-- Check if query is allowed
canQuery, canQueryAll = CanSendAuctionQuery()

-- Search by NAME (not itemID!)
-- page starts at 0, 50 results per page
QueryAuctionItems(text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)

-- Get result counts
numOnPage, totalAuctions = GetNumAuctionItems("list")

-- Get auction details (index: 1 to numOnPage)
name, texture, count, quality, canUse, level, levelColHeader, minBid,
minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,
ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", index)
```

### Events

- `AUCTION_ITEM_LIST_UPDATE` — fires when query results are ready
- Can fire **multiple times** as data resolves (check `hasAllInfo`)

### Example: Find cheapest buyout for an item

```lua
local TARGET_ITEM_ID = 13468  -- Black Lotus

local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")

local function StartSearch()
    local canQuery = CanSendAuctionQuery()
    if not canQuery then return false end
    local name = GetItemInfo(TARGET_ITEM_ID)
    if not name then return false end  -- item not cached
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

### Gotchas

1. **`buyoutPrice` is per-STACK, not per-unit.** Divide by `count`. This is the #1 AH scanning bug.
2. **Search is by name string**, not itemID. Resolve itemID → name via `GetItemInfo()` first.
3. **Async.** Wait for `AUCTION_ITEM_LIST_UPDATE` after `QueryAuctionItems()`.
4. **Pagination.** 50 results/page. Loop pages for large result sets.
5. **Throttling.** ~0.3s between queries, 15min for getAll mode.
6. **AH window must be open.** Queries fail silently otherwise.
7. **Item must be cached.** `GetItemInfo(itemID)` may return nil on first call.

### Price formatting

```lua
-- Convert copper amount to readable string
GetCoinTextureString(copperAmount)  -- "2g 50s 12c" (with icons)
```
