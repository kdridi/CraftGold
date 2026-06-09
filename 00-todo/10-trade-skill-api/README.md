# 10 — Trade Skill API

| Metadata      | Value                                                                |
|---------------|----------------------------------------------------------------------|
| Phase         | Phase 4                                                              |
| Duration      | 45 min                                                               |
| Difficulty    | ●●●●○ (4/5)                                                         |
| Prerequisites | Capsule 09 — Item Info                                               |
| Type          | Semi-autonomous                                                      |
| Concepts      | `C_TradeSkillUI`, recipe listing, reagents, TRADE_SKILL_LIST_UPDATE  |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **List** all recipes for an open profession using `C_TradeSkillUI.GetAllRecipeIDs()`
2. **Read** reagent information for each recipe (name, itemID, quantity)
3. **Understand** the limitation: API only shows **learned** recipes (why we need a static DB)
4. **Build** a simple recipe tree structure in Lua tables

## Key Concepts

### Available API (Classic Era, pre-10.0 version)

```lua
-- Get all recipe IDs for the open profession
recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()

-- Get recipe details
info = C_TradeSkillUI.GetRecipeInfo(recipeID)
-- info.name, info.learned, info.recipeID, info.icon, info.numAvailable

-- Get reagent count
numReagents = C_TradeSkillUI.GetRecipeNumReagents(recipeID)

-- Get reagent details (index 1..numReagents)
name, icon, requiredCount, playerCount = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, reagentIndex)

-- Get reagent item link (to extract itemID)
itemLink = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, reagentIndex)
itemID = itemLink and GetItemInfoInstant(itemLink)
```

### Event-driven

- Register `TRADE_SKILL_LIST_UPDATE` — fires when profession data is ready
- Register `TRADE_SKILL_SHOW` — fires when profession window opens
- API returns empty tables if called before the profession window is open

### Critical limitation

The API only lists recipes the **character has learned**. It cannot enumerate all recipes for a profession. This is why CraftGold v1 uses a static database for the leveling planner.

*(To be expanded during Phase C)*

## Execution

1. Copy to `Interface/AddOns/`
2. `/reload` in-game (must be logged in with a character)
3. Open a profession (e.g. Engineering)
4. Type `/recipes list`

## Expected Output

```
[Recipes] Engineering — 45 recipes known
  1. Rough Blasting Powder
     - Copper Ore × 1 (itemID 2770)
  2. Handful of Copper Bolts
     - Copper Bar × 3 (itemID 2841)
  ...
```

## Common Pitfalls

- **Calling API before TRADE_SKILL_LIST_UPDATE fires** → empty results
- **GetRecipeReagentItemLink returns nil** → item not cached yet, need to retry
- **Assuming API shows all recipes** → only learned ones are visible

## Going Further

- → Next capsule: **11 — Auction House Scan**
