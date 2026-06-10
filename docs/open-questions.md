# Open Questions — Need In-Game Verification

> Questions where external LLMs disagreed. Must be verified during Phase B.

---

## Q1: Does `/reload` detect brand-new add-on folders?

| Source | Answer |
|--------|--------|
| Claude | Yes — since Classic Era 1.14.0, `/reload` detects new folders and TOC changes |
| Gemini | No — new add-on folders require a full client restart |
| ChatGPT | Maybe — "generally yes but some cases may need restart" |

**Impact:** If yes, the dev workflow is `edit → /reload → test` always. If no, beginners must restart WoW when creating a new add-on or adding files to `.toc`.

**How to verify:**
1. Start WoW, log into a character
2. While in-game, create a brand new add-on folder in `Interface/AddOns/`
3. Type `/reload`
4. Check if the new add-on appears in the add-on list

## Q2: Exact menu path to add-on list in-game

| Source | Answer |
|--------|--------|
| Claude | Escape → "AddOns" button directly |
| Gemini | Escape → Options → AddOns tab |
| ChatGPT | "Escape → System → Add-ons" (uncertain) |

**How to verify:** Press Escape in-game and look for the AddOns button/tab.

## Q3: Exact interface version

| Source | Answer |
|--------|--------|
| Claude | 11508 (patch 1.15.8, released 2025-10-21) |
| ChatGPT | 11508 |
| Gemini | 11503-11507 |

**How to verify:** `/dump select(4, GetBuildInfo())` in-game.

## Q4: Does top-level `print()` show in chat?

All 3 agree it runs during loading screen, but:
- Gemini explicitly says it likely **won't be visible** (chat frame not initialized yet)
- Claude and ChatGPT don't flag this as strongly

**How to verify:** Put `print("TOP LEVEL")` at the top of a `.lua` file, `/reload`, check if it appears in chat.
