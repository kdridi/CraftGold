Here is your comprehensive review for **Capsule 01: Hello Azeroth**. Overall, your foundational grasp of the system is highly accurate, but there are critical technical nuances, version shifts, and hidden behaviors you must document correctly to prevent beginner frustration.

---

## Question 1 — The `.toc` file format

### 1. Status: **Confirmed** (with minor omissions)

Your sample `.toc` file is technically valid and enough for the game client to recognize your add-on. However, omitting code execution files can trick beginners if they don't understand how WoW parses line breaks.

### 2. Facts & Details

* **Current Interface Version (Classic Era 1.15.x):** The baseline interface version sequence for the 1.15 client branch is **`11503`** up to **`11507`** (and incrementally climbing depending on the sub-patch). Using `11503` or your planned `11508` is perfect for establishing the 1.15.x ecosystem.
* **Folder Name Alignment:** **Yes.** This is a strict requirement. If your folder is named `HelloAzeroth`, the file **must** be named `HelloAzeroth.toc`. If they mismatch, WoW ignores the entire folder.
* **Required Fields:** Technically, only `## Interface: [version]` is strictly required for the manifest. If you have no script lines beneath it, the add-on loads "empty."
* **Other Useful Fields:**
* `## Author`: Displays the creator's name in the add-on list.
* `## Version`: Tracks your internal release version (e.g., `1.0.0`).
* `## SavedVariables`: Saves global variables to a file on logout across all characters on an account.
* `## SavedVariablesPerCharacter`: Saves variables unique to that character.
* `## Dependencies`: A comma-separated list of other add-on folders that *must* load before this one. If missing, this add-on won't load.


* **Interface Mismatch Behavior:** If the version doesn't match the current game client version, WoW marks the add-on as **"Out of Date"**. It will refuse to load it *unless* the user has checked the "Load out of date AddOns" box in their character selection screen.
* **Exact Installation Directory:** Relative to the game root directory, the path is:
`World of Warcraft/_classic_era_/Interface/AddOns/HelloAzeroth/`

### 3. Code Example

```text
## Interface: 11503
## Title: Hello Azeroth
## Notes: My first WoW add-on for Classic Era
## Author: YourName
## Version: 1.0.0

HelloAzeroth.lua

```

### 4. Gotchas

* **Hidden File Extensions:** Windows often hides known file extensions by default. Beginners frequently end up making a file named `HelloAzeroth.toc.txt` without realizing it, which makes the add-on completely invisible to WoW.
* **Game Directory Confusion:** Make sure they use `_classic_era_`. Putting it in `_retail_` or `_classic_` (which is often Progression/Wrath/Cata) means it won't show up.

---

## Question 2 — Lua in WoW

### 1. Status: **Confirmed**

You are completely correct about the chronological loading behavior.

### 2. Facts & Details

* **Execution Order:** WoW reads your `.toc` from top to bottom. It executes every line of a `.lua` file completely before moving to the next file listed in the `.toc`. This happens sequentially for every add-on during the loading screen process.
* **Lua Version:** WoW Classic Era uses a highly customized version of **Lua 5.1** backported with several modern elements (like specialized garbage collection improvements and structural wrappers).
* **WoW Modifications:** Blizzard strips standard environment features like `os.execute`, `io` libraries (for local file system access), and `require` (to prevent external system access). They inject their own enormous API wrapper (Frame XML).
* **The `print()` Function:** You can use `print()` directly! WoW overrides Lua's default global `print()` function to redirect text strings straight into the `ChatFrame1` (the default active chat window).
* **Alternative Methods:** `DEFAULT_CHAT_FRAME:AddMessage("Message")` is the underlying engine method. `print(...)` is essentially a wrapper around this that handles multiple comma-separated variables automatically and converts them to strings.
* **Global Scope:** Yes. Any variable or function declared without the `local` keyword becomes bound to the shared global environment `_G`. It will be accessible across all files in your add-on—and globally by *all other add-ons*, which is risky.

### 3. Code Example

```lua
-- HelloAzeroth.lua

-- Safe: local to this file
local welcomeMessage = "Hello Azeroth, this is local!"

-- Global: Visible to the whole UI environment (Use unique prefixes!)
HELLO_AZEROTH_GLOBAL_VAR = "I am global!"

print("Hello Azeroth from print()!")
DEFAULT_CHAT_FRAME:AddMessage("Hello Azeroth from AddMessage!")

```

### 4. Gotchas

* **Global Namespace Pollution:** Beginners often write `status = "Active"` instead of `local status = "Active"`. If another add-on also uses the global variable `status`, they will overwrite each other, causing silent, chaotic UI bugs.

---

## Question 3 — Loading and lifecycle

### 1. Status: **Corrected** (Partial misconception about entry points)

WoW does not use a "main" entry point function; execution is strictly linear and event-driven.

### 2. Facts & Details

* **Loading Points:** Add-ons are read and compiled **during the loading screen** *after* you select your character but *before* your character appears visually inside the game world.
* **Top-Level Code Execution:** Code written at the root level of a file (outside a function block) executes **immediately** during that initial loading screen phase.
* **Main Entry Point:** There is **no** `main()` function. To run code later, developers use WoW's event engine. They register a frame for events like `PLAYER_ENTERING_WORLD` and attach a handler function.
* **Syntax Error Failure:** If a script contains a structural syntax error (e.g., a missing `end`), compilation fails on that file. The rest of the add-on files *might* attempt to load, but the broken file will immediately throw a Lua error and halt execution of its contents.
* **Success Visibility:** Users can open the Esc menu -> AddOns to see if it is checked, but the game provides no success toast. To see failures, the user *must* have Lua errors turned on.
* **The `/reload` Command:** This completely wipes the UI environment memory. It clears out all temporary variables, reads the file contents from disk again, and boots the entire user interface back up from scratch.
* **Error Logging & Taint Commands:**
* `/console scriptErrors 1`: **Correct.** This tells WoW to pop up a visual warning window whenever a Lua error happens.
* `/console taintLog 2`: Highly useful, but *not* for general debugging. This logs "taint" (when secure Blizzard code is touched by insecure add-on code, breaking action buttons). Beginners shouldn't worry about this yet.



### 3. Code Example

```lua
-- Top-level code runs during the loading screen
print("Loading screen print (Player can't see this yet!)")

-- Setting up an event listener to run code after world entry
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, ...)
    print("Welcome to the world! The game is now fully loaded.")
end)

```

### 4. Gotchas

* **The Loading Screen Trap:** If you put a simple `print("Hello")` at the top level of a file, the player often won't see it because it prints *while the loading screen is still active*. By the time the world fades in, the text has already scrolled out of view or failed to print to the uninitialized chat frame. **Always teach beginners to use events for in-game output.**

---

## Question 4 — The Add-on list in-game

### 1. Status: **Corrected** (Slight UI layout changes)

The access path differs slightly depending on whether you are on the character selection screen or actively logged into a character.

### 2. Facts & Details

* **Access Paths:**
* **Character Select Screen:** There is a dedicated, unmistakable **"AddOns"** button in the bottom-left corner.
* **In-Game World:** Pressing `Escape` brings up the Game Menu. You click **Options**, and under that menu system, there is an **AddOns** tab at the top.


* **Displayed Info:** It displays the `## Title` (the interactive toggle name), the `## Version`, the `## Notes` (on hover), and the status (e.g., "Disabled", "Banned", or "Out of Date").
* **Individual Toggles:** Yes, players can tick checkboxes next to each individual add-on.
* **"Load out of date" Checkbox:** If checked, this overrides the security check. WoW will attempt to run add-ons whose `## Interface` version does not match the game's current build version.
* **Character-Specific Settings:** In the top-left corner of the AddOn menu, there is a dropdown menu. It defaults to "All" (account-wide settings) but can be switched to a specific character's name to isolate adjustments.

### 4. Gotchas

* **In-game changes require a reload:** Toggling an add-on on or off while logged into a character does not apply instantly. The game will show an alert indicating that a UI reload (`/reload`) is required to apply the changes.

---

## Question 5 — The `/reload` command

### 1. Status: **Corrected** (Crucial limitation regarding `.toc` edits)

`/reload` is powerful, but it cannot register brand new files or structural directory changes.

### 2. Facts & Details

* **Reading `.toc` Files:** `/reload` **does NOT** scan for new `.toc` files or folder additions. If you create a brand new add-on folder or add a new file entry inside the `.toc` list, you **must completely restart the World of Warcraft client**. If you only edit the *internal logic* of an existing `.lua` file, `/reload` is enough.
* **State Wiping:** It completely purges the active Lua state from your computer's RAM. All global and local values are reset back to zero or whatever their baseline file code sets them to.
* **SavedVariables Behavior:** Right before the memory wipe occurs, WoW flushes current global states tied to your `## SavedVariables` configuration out to disk (`WTF/Account/...`). Then it boots the UI back up and reads those saved parameters back into memory.
* **Isolating Reloads:** No. You cannot reload an isolated add-on. The UI engine is a singular, monolithic ecosystem; you reload everything or nothing.

### 4. Gotchas

* **The `/reload` Loop Frustration:** Beginners will spend hours adding a new `.lua` file to their `.toc`, typing `/reload`, and crying because their changes aren't appearing. Emphasize early: **New files = Restart WoW. Code edits = `/reload` is okay.**

---

## Question 6 — Folder structure and naming conventions

### 1. Status: **Confirmed**

Your assumptions about structural requirements are spot on.

### 2. Facts & Details

* **Folder / File Mismatch:** If `FolderA/` contains `FolderB.toc`, WoW walks right past it. They must align explicitly.
* **Subdirectory Referencing:** Yes, a `.toc` can look deep into folders. You can structure your assets cleanly using relative paths.
* **Naming Restrictions:** Avoid spaces and symbols. Stick to alphanumeric characters (`A-Z`, `a-z`, `0-9`) and underscores (`_`).
* **Folder Collisions:** You cannot have two folders with the exact same name in the same operating system directory. If two different add-on developers use the folder name `MyAddon`, the second installation will overwrite the first.
* **Path Lengths:** Standard Windows API path limitations ($260$ characters) apply. Keep path depths reasonably shallow to avoid file tracking errors.

### 3. Code Example

```text
## Interface: 11503
## Title: Clean Addon

code\Core.lua
code\utils\MathHelpers.lua

```

---

## Question 7 — Common pitfalls for beginners

### 1. Facts & Details

* **Encoding Requirements:** `.lua` and `.toc` files **must be saved in UTF-8 encoding**. If a beginner uses standard Windows Notepad and types an accent mark or a special character, it might save as ANSI or UTF-16, which triggers immediate compilation crashes or scrambles text string displays in-game.
* **BOM (Byte Order Mark):** Avoid **UTF-8 with BOM**. Files should ideally be saved as **UTF-8 without BOM** (frequently designated as just `UTF-8` in editors like VS Code or Notepad++). A BOM at the start of a `.toc` file can corrupt the header data, blinding WoW to the interface version.
* **Reserved Word Clashes:** Beginners must never name variables after internal engine functions or protected tables. Overwriting things like `tinsert`, `pair`, `ipairs`, `print`, or `Frames` will cause cascading global errors across the entire game UI.

---

### Suggested Lesson Outline for Capsule 01

1. **Setup:** Install VS Code, change encoding default to UTF-8, and turn on file extensions in Windows.
2. **Directory Creation:** Navigate to `_classic_era_/Interface/AddOns/` and create `HelloAzeroth`.
3. **The Manifest:** Build `HelloAzeroth.toc` using the matching folder name syntax.
4. **The Event Trap:** Explain why a bare `print()` script fails on load, and teach them how to hook into `PLAYER_ENTERING_WORLD`.
5. **Testing:** Launch the game client and use `/console scriptErrors 1` to ensure they have a clear path to fix typos.

For a deeper dive into establishing the frame lifecycle, you might find this guide on handling events and initializing add-ons helpful: [WoW Addon Event Handling Tutorial](https://www.youtube.com/watch?v=u1fL4Atox18). This video breaks down how the game engine interacts with your custom code scripts once the world finishes loading.