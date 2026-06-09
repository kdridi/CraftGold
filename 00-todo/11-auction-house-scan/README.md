# 11 — Auction House Scan

| Metadata      | Value                                                             |
|---------------|-------------------------------------------------------------------|
| Phase         | Phase 4                                                           |
| Duration      | 45 min                                                            |
| Difficulty    | ●●●●● (5/5)                                                      |
| Prerequisites | Capsule 10 — Trade Skill API                                      |
| Type          | Semi-autonomous                                                   |
| Concepts      | `QueryAuctionItems`, `GetAuctionItemInfo`, async events, throttling |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Query** the Auction House for item prices using `QueryAuctionItems()`
2. **Parse** results with `GetAuctionItemInfo()` to get buyout prices
3. **Handle** async events (`AUCTION_ITEM_LIST_UPDATE`) and throttling
4. **Build** a price table: `{ itemID → minBuyoutPerUnit }`

## Key Concepts

### Classic Era Auction House API

**⚠️ `C_AuctionHouse` does NOT exist in Classic Era.** Use the old API:

```lua
-- Check if we can query
canQuery, canQueryAll = CanSendAuctionQuery()

-- Search by name (NOT by itemID!)
QueryAuctionItems(name, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData)
-- page starts at 0, 50 results per page

-- Read results when AUCTION_ITEM_LIST_UPDATE fires
numOnPage, totalAuctions = GetNumAuctionItems("list")

name, texture, count, quality, canUse, level, levelColHeader, minBid,
minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,
ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", index)
```

### Critical gotchas

1. **`buyoutPrice` is per-stack, NOT per-unit.** Divide by `count` for unit price.
2. **Search is by name string, not itemID.** Must resolve itemID → name via `GetItemInfo()` first.
3. **Async.** Call `QueryAuctionItems()`, then wait for `AUCTION_ITEM_LIST_UPDATE` event.
4. **Pagination.** 50 results per page. Loop pages for large result sets.
5. **Throttling.** ~0.3s between queries. Always check `CanSendAuctionQuery()`.
6. **AH window must be open.** Queries fail silently otherwise.
7. **Item must be cached.** `GetItemInfo(itemID)` may return nil on first call.

*(To be expanded during Phase C)*

## Execution

1. Copy to `Interface/AddOns/`
2. `/reload` in-game (must be logged in)
3. Go to the Auction House NPC, interact to open the AH window
4. Type `/ahscan item 2589` (Linen Cloth)

## Expected Output

```
[AHScan] Searching for: Linen Cloth
[AHScan] Page 1: 47 auctions found
[AHScan] Min buyout per unit: 2s 50c
[AHScan] Total auctions scanned: 47
```

## Common Pitfalls

- **Forgetting to divide buyoutPrice by count** → prices appear 20x too high for stacks of 20
- **QueryAuctionItems before AH window is open** → silently fails
- **Not checking CanSendAuctionQuery()** → throttled/disconnected
- **GetItemInfo returns nil** → item not cached, search fails

## Going Further

- → Next capsule: **12 — Cost Calculator**
