# Multi-Agent Consultation — Recipe Data Architecture for CraftGold

## Your task

Run a debate between **3 agents with different personalities**. Each agent must argue their position, respond to the others, and then produce a **synthesis with a recommendation**.

## The problem

We're building a WoW Classic Era add-on called **CraftGold**. It needs recipe data (what items can be crafted, what materials they require, in what quantities). The question is: **where does this recipe data come from?**

## The 3 agents

### Agent A — "The API Purist" 🧙‍♂️
- Believes in using the game's own APIs exclusively
- Reads recipes dynamically from `C_TradeSkillUI` or equivalent when the player opens a profession
- No hardcoded data, no external databases
- Argues this is the "correct" way — always up to date, no maintenance

### Agent B — "The Database Builder" 📊
- Believes in shipping a static database of recipes embedded in the add-on's Lua files
- Recipes for all professions, all levels, pre-built from community data (Wowhead, etc.)
- Argues this lets you plan crafting without opening the profession window
- Willing to maintain and update the database when patches change things

### Agent C — "The Hybrid Strategist" 🔄
- Wants both: a static database as fallback + dynamic API reads when available
- Uses the API when the player has the profession open, caches the results
- Falls back to static data when the player doesn't have the profession open yet
- Argues this gives the best of both worlds but admits it's more complex

## The debate topics

Each agent must address:

1. **Completeness** — Can the approach provide ALL recipes for a profession, even ones the player hasn't learned yet? (Critical for the "leveling cost planner" feature)
2. **Accuracy** — Is the data guaranteed to be correct for Classic Era specifically?
3. **Maintenance burden** — How much work to keep it working across patches?
4. **Performance** — Memory usage, loading time, runtime overhead
5. **User experience** — What does the player need to do before the add-on works? (Open profession? Visit AH? Nothing?)
6. **Complexity** — How hard to implement for a Lua beginner learning add-on development?

## Output format

1. **Agent A's argument** (2-3 paragraphs)
2. **Agent B's argument** (2-3 paragraphs)
3. **Agent C's argument** (2-3 paragraphs)
4. **Round 2: Each agent responds to the others' points** (1 paragraph each)
5. **Synthesis** — An objective summary of the trade-offs and a clear recommendation for our specific use case (learning project, Classic Era, Engineering focus, two features: leveling cost planner + profit calculator)
