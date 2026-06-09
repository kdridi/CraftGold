I'll research this carefully, focusing on verifying the version-sensitive details since you've emphasized accuracy. Let me dig into current sources.Good — Interface version confirmed. Now the trickier part: the Trade Skill API in Classic Era, which is a known source of confusion.Important nuance here: some of these `C_TradeSkillUI` functions were *removed* in Retail's 10.0 rewrite but survive in Classic. Let me confirm the Classic-specific availability and the reagent-item-link function for getting item IDs.Now the Auction House API — the other major divergence point. Let me verify whether Classic Era uses the old `QueryAuctionItems` or the newer `C_AuctionHouse`.Let me confirm one high-stakes point: that the `C_TradeSkillUI` reagent functions (marked "Removed in 10.0.0" on the wiki, which refers to Retail) are actually retained in Classic Era.I've verified the key version-sensitive and divergence-prone points. Here's the rundown, with confidence levels flagged as you asked.

## Bottom line up front

Classic Era (1.15.x) is built on the **modern engine but retains the *pre-Dragonflight* API surface** for both of your systems. That's the crux:

- **Trade skills:** use `C_TradeSkillUI` — but the *pre-10.0* version of it, with the reagent functions that the wiki marks "Removed in 10.0.0." That removal was **Retail-only**; Classic Era kept them. The wiki's "Patch 10.0.0 (2022-10-25): Removed" note refers to the Dragonflight crafting rewrite, which Classic Era never received. Active Classic Era addons (Missing TradeSkills List, Recipe Radar, Ackis Recipe List) all use this API, confirming it's live in 1.15.
- **Auction House:** `C_AuctionHouse` is **Retail-only** (and Cata/MoP Classic). It was added in Patch 8.3.0 (2020-01-14), replacing QueryAuctionItems with C_AuctionHouse.SendBrowseQuery() and ReplicateItems(). Classic Era still uses the **old `QueryAuctionItems` / `GetAuctionItemInfo`** browse-based API — the Wowpedia "WoW API/Classic" page lists QueryAuctionItems, GetAuctionItemInfo, GetOwnerAuctionItems, PostAuction, and PlaceAuctionBid as the Classic auction functions.

---

## Trade Skill API (Classic Era)

### `C_TradeSkillUI.GetAllRecipeIDs()`
**Signature:** `recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()`
**Availability:** Confirmed in Classic Era.
Returns a table of recipe IDs for the currently open profession, including both learned and unlearned recipes, ignoring all filtering. The table is empty if the trade skill window hasn't been opened yet.

```lua
for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
    local info = C_TradeSkillUI.GetRecipeInfo(id)
    if info and info.learned then
        print(info.recipeID, info.name)
    end
end
```

**Gotcha:** It returns *every* recipe for the profession, learned or not. Filter on `recipeInfo.learned` to get only what the character actually knows. Also, this only works while the trade skill window is open and `TRADE_SKILL_LIST_UPDATE` has fired — calling it cold returns an empty table.

### `C_TradeSkillUI.GetRecipeInfo(recipeID)`
**Signature:** `recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID [, recipeLevel])`
**Availability:** Confirmed.
Returns a table with fields including `.recipeID`, `.name`, `.learned`, `.icon`, `.numAvailable`, etc.

### `C_TradeSkillUI.GetRecipeNumReagents(recipeID)`
**Signature:** `numReagents = C_TradeSkillUI.GetRecipeNumReagents(recipeID)`
**Availability:** Confirmed in Classic Era (wiki "Removed" tag is Retail-only).
Returns the number of distinct reagent types for the recipe.

### `C_TradeSkillUI.GetRecipeReagentInfo(recipeID, reagentIndex)`
**Signature:** `name, icon, reagentCount, playerReagentCount = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, reagentIndex)`
**Availability:** Confirmed in Classic Era.
For each reagent it returns name, icon, the required count, and how many the player currently has.

⚠️ **Important gotcha:** This does **not** return the reagent's item ID. To get the item ID you need the next function.

### `C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, reagentIndex)`
**Signature:** `itemLink = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, reagentIndex)`
**Availability:** Confirmed in Classic Era.
Returns an item link for the requested reagent, with reagentIndex between 1 and GetRecipeNumReagents(recipeID). Parse the link (or feed it to `GetItemInfoInstant`) to extract the numeric item ID.

### Putting it together — recipe + reagents with item IDs and quantities

```lua
local function DumpRecipe(recipeID)
    local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if not (info and info.learned) then return end

    print("Recipe:", info.name, "(", recipeID, ")")
    local n = C_TradeSkillUI.GetRecipeNumReagents(recipeID)
    for i = 1, n do
        local name, _, reqCount, have =
            C_TradeSkillUI.GetRecipeReagentInfo(recipeID, i)
        local link = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, i)
        local itemID = link and GetItemInfoInstant(link)  -- numeric ID
        print(string.format("  %s x%d (itemID %s, have %d)",
            name or "?", reqCount or 0, tostring(itemID), have or 0))
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
f:SetScript("OnEvent", function()
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
        DumpRecipe(id)
    end
end)
```

**Gotchas for the whole flow:**
- Everything is gated on the trade skill window being open. Register `TRADE_SKILL_SHOW` / `TRADE_SKILL_LIST_UPDATE` rather than polling.
- The first `TRADE_SKILL_LIST_UPDATE` can arrive before item data is cached. If `GetRecipeReagentItemLink` returns nil, the item isn't cached yet — handle that gracefully or re-query.
- `GetItemInfoInstant` is fine for just the item ID (it works on uncached items); use `GetItemInfo` only when you need name/price/etc., and be ready for it to return nil on a cold cache.

### 1.14.x vs 1.15.x differences
I'm **not aware of any breaking changes** to the `C_TradeSkillUI` recipe/reagent functions between 1.14.x and 1.15.x — this API has been stable across Classic Era's lifetime. I can't prove a negative here, so treat that as "probably stable, verify in-game" rather than "confirmed identical." If something did shift, it would more likely be in peripheral fields of the returned tables than in these core signatures.

---

## Auction House API (Classic Era)

`C_AuctionHouse` does **not** exist in Classic Era — don't use it. The old API is **event-based**, not synchronous: you fire a query, then read results when `AUCTION_ITEM_LIST_UPDATE` fires.

### `QueryAuctionItems(...)`
**Signature:** `QueryAuctionItems(text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)`
**Availability:** Confirmed in Classic Era.
Performs a search of the auction house with the specified characteristics. Pages start at **0**, and a page holds up to 50 results.

⚠️ **There is no search-by-item-ID** in this API. You search by **name string**. So the workflow to price a specific item ID is: resolve the ID to a name, query by exact name, then match the `itemId` field in the results.

### `GetNumAuctionItems("list")`
**Signature:** `numOnPage, totalAuctions = GetNumAuctionItems("list")`
**Availability:** Confirmed.

### `GetAuctionItemInfo("list", index)`
**Signature:**
```
name, texture, count, quality, canUse, level, levelColHeader, minBid,
minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,
ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", index)
```
**Availability:** Confirmed. The `buyoutPrice` (copper) and `itemId` are the fields you want.

### `CanSendAuctionQuery()`
**Signature:** `canQuery, canQueryAll = CanSendAuctionQuery()`
**Availability:** Confirmed. Always check this before querying.

### Example — cheapest per-unit buyout for a specific item ID

```lua
local TARGET_ITEM_ID = 13468  -- e.g. Black Lotus
local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")

local function StartSearch()
    local canQuery = CanSendAuctionQuery()
    if not canQuery then return false end
    local name = GetItemInfo(TARGET_ITEM_ID)  -- may be nil if uncached
    if not name then return false end
    -- text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData
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

**Gotchas (these bite everyone):**
- **`buyoutPrice` is per-stack, not per-item.** Divide by `count` for a per-unit price. This is the single most common AH-scanning bug.
- **Synchronicity:** the query is async. Don't read results in the same call as `QueryAuctionItems` — wait for `AUCTION_ITEM_LIST_UPDATE`. Note that event can fire **multiple times** as data resolves; `owner` and other fields are nil until the client caches them (`hasAllInfo` tells you when a row is fully resolved).
- **Item must be cached** for `GetItemInfo(itemID)` to return a name; if it's nil, the item isn't loaded yet — retry shortly.
- **Pagination:** more than 50 matches means multiple pages. Loop pages until you've covered `totalAuctions`, re-querying with incrementing `page` and respecting the throttle between each.
- **AH window must be open** — `QueryAuctionItems` has no effect otherwise.

### Throttling
Regular queries are throttled at roughly 0.3 seconds; getAll mode is throttled at about 15 minutes, and the two return values of CanSendAuctionQuery() tell you when each mode is permitted. Also: search text longer than 63 bytes can disconnect the player, and getAll mode can disconnect low-bandwidth clients. For a single-item lookup, stick to normal paged queries with the ~0.3s gap; avoid `getAll` unless you're doing a full-AH scan.

---

## General

**Interface version (1.15.x):** The current Classic Era patch is **1.15.8**, interface number **`11508`**. Patch 1.15.8 shipped 2025-10-21 and includes modern changes up to 11.2.0, and 11508 is the Classic Era interface number for Patch 1.15.8. Recent progression for reference: 11504 (1.15.4) → 11505 → 11506 → 11507 → 11508. Since these numbers do change with patches, **verify in-game** rather than trusting any doc — run `/dump select(4, GetBuildInfo())`, which is the authoritative local value.

```
## Interface: 11508
## Title: My Addon
```

**SoD (Season of Discovery):** SoD runs on the **same 1.15.x Classic Era client**, so the add-on API is **identical** for both of your systems — same `C_TradeSkillUI`, same `QueryAuctionItems`. SoD differences are content/balance (runes, level caps, etc.), not API surface. Same Interface number applies.

**Resources:**
- **warcraft.wiki.gg** (formerly Wowpedia) is the authoritative API reference. Crucially, individual API pages show version/flavor availability — but read the "Removed" notes carefully, since they usually mean *Retail*, not Classic.
- The **"WoW API/Classic"** page on the wiki is specifically the Classic-flavor function list — useful for confirming what's actually present.
- For ground truth, **read source from active Classic Era addons** that do exactly what you want: Ackis Recipe List and Missing TradeSkills List for professions; the Auctionator / TradeSkillMaster Classic builds for the AH API. If a maintained 1.15 addon calls a function, it exists in 1.15.
- The in-game `/dump` and `/etrace` (event trace) commands are your fastest verification loop for confirming a function exists and seeing what it returns on your build.

One honest caveat to repeat: the two API *families* and the `C_AuctionHouse`-is-Retail-only point are well-confirmed. The exact field list of returned tables (e.g. `GetRecipeInfo`'s table members) is the thing most likely to have minor build-specific variation, so `/dump` the actual return on 1.15.8 before relying on any specific field name beyond the core ones above.