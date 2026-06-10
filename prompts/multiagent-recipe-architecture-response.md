# CraftGold Recipe Data Architecture — Agent Debate

## 1. Agent A — "The API Purist" 🧙‍♂️

The game already knows everything. Every recipe, every reagent, every quantity — it lives inside the client, maintained by Blizzard, guaranteed correct for whatever patch the player is running. Why would we ever copy that into a stale, hand-typed Lua table that rots the moment a hotfix lands? When the player opens a profession, `C_TradeSkillUI` hands us the recipe IDs, and `GetRecipeInfo` plus the reagent calls give us names and quantities. Zero maintenance, zero drift, zero risk of shipping a typo that tells someone a Handful of Copper Bolts needs the wrong amount of bars. **Accuracy is free and permanent.** That is the whole argument, and it's a strong one.

On performance and footprint I win cleanly too. I ship essentially no data — a few hundred lines of event-handling logic instead of a multi-hundred-kilobyte recipe blob loaded into memory at every login. The add-on stays lean. And philosophically, this is simply the *correct* layer to read from: the source of truth, not a photocopy of a photocopy from Wowhead that may have been scraped from a Season of Discovery page or a Cata Classic build without anyone noticing.

I'll concede my weak point up front so nobody has to drag it out of me: I can only see recipes the player has **learned**. That's a real limitation and I won't pretend otherwise — but I'd argue we lean into dynamic reads and design features around what's actually knowable, rather than maintaining a database forever to support one speculative planner screen.

## 2. Agent B — "The Database Builder" 📊

Agent A just talked himself out of the headline feature. Read that last paragraph again: the API *only returns recipes the player has already learned.* There is no `C_TradeSkillUI` call that enumerates every Engineering recipe from skill 1 to 300 for a character who just trained Apprentice. The "leveling cost planner" — the thing that tells a new engineer "here's everything you'll craft on the way to 300 and what it'll cost" — is **literally impossible** with API-only data, because the player hasn't learned those recipes yet and the client won't list them. That's not a nitpick; it's a hard wall. A static database is the *only* approach that can answer "what comes next." That alone should end the debate.

Beyond completeness, the database works the instant the add-on loads. The player doesn't have to open their profession window, doesn't have to be near a trainer, doesn't have to do anything — they install CraftGold, open it, and see the full Engineering tree. For a planning tool, that's the entire user experience. And for a *learning project*, a static table is the gentlest possible Lua: it's a nested table literal, and the whole feature becomes a lookup. No event soup, no asynchronous list updates that fire three times and make beginners cry.

Yes, I own maintenance. But be honest about the actual burden: this is **Classic Era** — frozen 1.x content. Engineering's recipe list isn't changing month to month the way retail does. I curate it once, verify it against the in-game trainer, and it's stable for years barring the rare hotfix. A few hundred kilobytes of Lua is nothing on modern machines. The "drift" Agent A fears is a retail problem; here it's a non-issue.

## 3. Agent C — "The Hybrid Strategist" 🔄

Both of them are right, which is exactly why neither should win outright. Agent B is correct that the API physically cannot enumerate unlearned recipes, so a static database is *mandatory* for the leveling planner — there's no debating that. But Agent A is correct that the API is ground truth, and it gives us something a static table never can: it tells us what *this specific player* has learned, their current skill level, and (combined with their bags) what they can actually craft right now. That's gold for the profit calculator's "craftable now" filter.

So I'd ship the static Engineering database as the foundation — it's the floor that guarantees both features work with nothing open. Then, when the player opens their Engineering window, I listen for the trade-skill events, read the learned recipes via the API, and *reconcile*: confirm reagent quantities against live data, flag any recipe where my static table disagrees with the client (free QA on my own database!), and light up which recipes the player has actually trained. The static data is the map; the API is the "you are here" pin. Cache the API results so the enhancement persists after they close the window.

My honest cost is complexity, and I won't soft-pedal it. Now there are two data sources that can disagree, a cache to invalidate, a merge step, and a beginner staring at `TRADE_SKILL_LIST_UPDATE` firing repeatedly while also maintaining a table. That's a lot of moving parts for someone learning Lua. The best-of-both-worlds is real, but so is the worst-of-both-debugging-sessions.

## 4. Round 2 — Responses

**Agent A:** Fine — I concede the leveling planner can't run on dynamic reads, and that's the feature in the brief, so pure-API is off the table for CraftGold specifically. But I'd push back on B's "maintenance is trivial" framing only to this degree: the moment you hand-type quantities, you own every typo forever, and Classic Era *has* had hotfixes touch recipes. My data is never wrong; yours is right until it isn't. If we go static, at least validate it against me when the window's open — which is precisely C's idea, so I'll grudgingly throw my weight behind the hybrid as the *eventually* correct shape.

**Agent B:** C's reconciliation idea is genuinely clever — using the live API to QA my own table is the best argument anyone's made for touching the API at all. My only objection is sequencing. For a beginner shipping a v1, the hybrid is a trap: you'll spend three weekends fighting event timing and cache logic before either headline feature works. Build the static database first, ship something that *works*, and treat the API layer as a v2 enhancement once the Lua fundamentals have clicked. Don't let "best of both worlds" become "neither world finished."

**Agent C:** I'll accept B's sequencing critique entirely — that's the responsible read. My architecture is the right *destination*, but it's a bad *starting line* for a learning project. The mistake would be building the merge layer on day one. So I'll restate my position as a roadmap rather than a v1: static foundation now, API reconciliation later, with the database designed from the start to be *overridable* by live data so the upgrade is additive rather than a rewrite.

## 5. Synthesis & Recommendation

The debate collapses around one hard technical fact that isn't a matter of opinion: **the trade-skill API only exposes recipes the player has already learned.** There is no way to enumerate a full profession tree for an unlearned character. Because the leveling cost planner depends entirely on showing recipes the player *hasn't* trained yet, API-only (Agent A) is disqualified for your headline feature — full stop. Recipe data must come from a static source.

Here's how the three approaches actually score for your situation:

| Criterion | A: API-only | B: Static DB | C: Hybrid |
|---|---|---|---|
| **Completeness** (unlearned recipes) | ❌ Impossible | ✅ Full tree | ✅ Full tree |
| **Accuracy** (Classic Era) | ✅ Ground truth | ⚠️ Curation risk | ✅ Static + API check |
| **Maintenance** | ✅ None | ⚠️ Low (Era is frozen) | ⚠️ Low–moderate |
| **Performance** | ✅ Tiny | ✅ Fine (Eng. is small) | ⚠️ Slightly more |
| **UX** (player setup) | ❌ Must open window | ✅ Works instantly | ✅ Works instantly |
| **Complexity** (Lua beginner) | ⚠️ Moderate | ✅ Easiest | ❌ Hardest |

One thing all three agents skipped that you should keep separate in your head: **neither recipe source gives you gold prices.** The profit calculator needs auction-house data, which comes from a price-scanning add-on (Auctionator/TSM-style) or the player's own scans — that's a third data source entirely. Recipe data tells you *what* a craft consumes; it never tells you what the reagents *cost*. Don't let the recipe-architecture decision bleed into assuming pricing is solved.

**Recommendation: Build Agent B's static database, scoped to Engineering, as your v1 — with Agent C's hybrid as the explicit v2 roadmap.**

This wins for three converging reasons. It's the *only* design that satisfies the leveling cost planner at all. Engineering specifically is a small, well-bounded recipe set — a few dozen recipes you can curate by hand and verify against the trainer in an afternoon, which sidesteps B's main weakness (curation errors scale with size, and your size is tiny). And as a learning project, a nested Lua table plus lookup logic is the right difficulty curve: you'll ship working features while your fundamentals solidify, instead of drowning in `TRADE_SKILL_LIST_UPDATE` event timing on week one.

Two design notes to make the future painless. First, store each reagent as an **itemID**, not a name — IDs are stable in Classic Era and let you query the player's bags and AH data directly. Second, structure the database so live API data can *override* a static entry per-recipe; that single decision turns Agent C's hybrid from a rewrite into a clean additive upgrade once you're comfortable. You get B's shippable simplicity now and a clear path to C's correctness later, with A's API serving as a free validation pass against your own table when you get there.