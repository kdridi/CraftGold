# Research Prompt — Capsule 01: Hello Azeroth (WoW Add-on Basics)

## Context

I'm creating a **learning capsule** that teaches absolute beginners how to create their first World of Warcraft add-on. The target is **WoW Classic Era** (patch 1.15.x, interface version 11508). The capsule will have the learner create a minimal add-on that prints a message in the chat when loaded.

I need to verify **everything** I think I know before writing the teaching material. Please answer each question with confirmed facts, and flag anything I'm wrong about.

---

## Question 1 — The `.toc` file format

I believe the `.toc` file is the manifest that WoW reads to identify an add-on. Here's what I think a minimal valid `.toc` looks like for Classic Era:

```
## Interface: 11508
## Title: Hello Azeroth
## Notes: My first WoW add-on

HelloAzeroth.lua
```

**Questions:**
- Is this actually valid and sufficient for WoW to recognize and load the add-on?
- What is the **exact** current interface version number for Classic Era 1.15.x?
- Does the `.toc` filename need to match the folder name? (e.g. folder `HelloAzeroth/` → file `HelloAzeroth.toc`)
- Are there required fields beyond `Interface` and the file list?
- What other useful fields exist? (`## Author`, `## Version`, `## SavedVariables`, `## Dependencies`, etc.)
- What happens if `Interface` version doesn't match the game's version exactly? Does WoW still load it?
- Where exactly should the add-on folder be placed? Is it `Interface/AddOns/` relative to the WoW install directory?

## Question 2 — Lua in WoW

I believe that when WoW loads an add-on, it executes the `.lua` files listed in the `.toc` in order, top to bottom, at UI load time.

**Questions:**
- Is this correct? When exactly during the loading process are add-on Lua files executed?
- What Lua version does Classic Era use? (5.1? 5.4?)
- Are there any WoW-specific modifications to the Lua standard library?
- Can I use `print()` directly, or do I need a special function to output to chat?
- What does `print("Hello")` actually do in WoW Lua? Does it appear in the default chat window?
- Are there other ways to output debug info? (e.g. `DEFAULT_CHAT_FRAME:AddMessage()`)
- What's the difference between `print()` and other chat output methods?
- Can I define global variables and functions that persist across files in the same add-on?

## Question 3 — Loading and lifecycle

**Questions:**
- At what point during the game startup are add-on files loaded? (login screen? character selection? after entering world?)
- If I put code at the top level of a `.lua` file (not inside a function), when does it run?
- Is there a main function or entry point that WoW calls?
- What happens if a Lua file has a syntax error? Does the entire add-on fail to load?
- Can the user see which add-ons loaded successfully? How?
- What does `/reload` actually do? Does it re-execute all add-on code from scratch?
- Is there a way to enable detailed error reporting? I think it's `/console scriptErrors 1` — is that correct?
- What about `/console taintLog 2` — is this useful for debugging?

## Question 4 — The Add-on list in-game

**Questions:**
- How does the player access the add-on list? I believe it's: Escape → System → Add-ons — is that correct?
- What information does this screen show about each add-on?
- Can add-ons be enabled/disabled individually from this screen?
- What does "Load out of date" do exactly?
- Is there a character-specific vs account-wide toggle for add-ons?

## Question 5 — The `/reload` command

**Questions:**
- Does `/reload` re-read all `.toc` files from disk? (i.e. if I changed the `.toc`, do I need to restart WoW or is `/reload` enough?)
- Does `/reload` clear all Lua state (globals, etc.) or does some state persist?
- Are SavedVariables affected by `/reload`?
- Is there a way to reload just one add-on without reloading the entire UI?

## Question 6 — Folder structure and naming conventions

**Questions:**
- Must the folder name match the `.toc` filename? What happens if they differ?
- Can a `.toc` reference files in subdirectories? (e.g. `src/HelloAzeroth.lua`)
- Are there naming conventions or restrictions on folder/file names?
- Can two different add-ons have the same folder name? What happens?
- Is there a maximum path length or filename length?

## Question 7 — Common pitfalls for beginners

**Questions:**
- What are the most common mistakes first-time add-on developers make?
- What error messages are most commonly seen and what do they mean?
- Are there encoding issues? (UTF-8 BOM, line endings, etc.)
- Do `.lua` files need to be in a specific encoding?
- Are there reserved words or names that conflict with WoW's internal globals?

---

## Output format

For each question, please provide:
1. **Confirmed / Corrected / Unsure** — whether my assumption was right
2. The actual facts with as much detail as possible
3. A short Lua code example where relevant
4. Any gotchas or common mistakes specific to this topic
