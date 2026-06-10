# Research Prompt — WoW Classic Era Add-on API

## Context

I'm building a World of Warcraft **Classic Era** (version 1.15.x) add-on in Lua. I need to know which APIs are available for two things:

1. **Trade Skill / Profession API** — listing recipes and their reagents for a profession like Engineering
2. **Auction House API** — querying item prices from the Auction House

## What I need to know

### Trade Skill API
- What function(s) do I use to list all recipes the character knows for an open profession?
- How do I get the reagents (materials) for a specific recipe, including item ID and quantity?
- Is it `C_TradeSkillUI.GetAllRecipeIDs()` or something else? Does `C_TradeSkillUI` even exist in Classic Era?
- Are there differences between Classic Era 1.14.x and 1.15.x for this API?

### Auction House API
- Does `C_AuctionHouse` exist in Classic Era? Or is it Retail-only?
- If not, what's the old API? (`QueryAuctionItems`, `GetAuctionItemInfo`, etc.?)
- How do I search for a specific item by item ID and get its current buyout price?
- Is the AH API synchronous or event-based (callbacks)?
- Are there throttling limits I should know about?

### General
- What's the current `## Interface:` version number for Classic Era 1.15.x? (e.g. 11507, 11505, etc.)
- Any good resources/documentation specifically for Classic Era add-on development?

## Constraints
- This is **Classic Era** (vanilla recreation), NOT Classic Cataclysm, NOT Retail, NOT SoD (Season of Discovery) — though if SoD differs, mention it
- I need the **actual API** available in-game, not theoretical documentation
- If you're unsure about something, say so — wrong information is worse than no information

## Output format

For each API function, please provide:
1. Function signature (name + parameters + return values)
2. Whether it's available in Classic Era (confirmed / probably / unsure)
3. A short Lua code example showing how to use it
4. Any gotchas or common mistakes
