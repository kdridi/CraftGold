-- src/DB.lua
-- Static Engineering recipe database for CraftGold.
-- Data sourced from LibCrafts-1.0 (MIT) — itemIDs verified against Vanilla 1.12.
-- All items referenced by itemID, never by name (names come from GetItemInfo in capsule 09).

local _, ns = ...

local DB = {}
ns.DB = DB

-------------------------------------------------
-- Recipe data
-------------------------------------------------
-- Structure:
--   recipes[spellID] = {
--       spellID      = number,
--       output        = number,          -- itemID produced
--       reagents      = { { id, count }, { id, count }, ... },
--       skillRequired = number,          -- minimum Engineering skill to learn
--       source        = string,          -- "trainer" | "vendor" | "drop" | "quest" | "auto"
--   }

DB.recipes = {}

-- Helper to register a recipe (keeps the data section clean)
local function R(spellID, output, reagents, skillRequired, source)
    DB.recipes[spellID] = {
        spellID      = spellID,
        output       = output,
        reagents     = reagents,
        skillRequired = skillRequired,
        source       = source,
    }
end

-------------------------------------------------
-- Engineering recipes (skill 1-150)
-------------------------------------------------

-- Skill 1 — Blasting Powders & Basics
R(3918, 4357, { {2835, 1} },                                                        1,   "auto")    -- Rough Blasting Powder (Rough Stone)
R(3919, 4358, { {2589, 1}, {4357, 2} },                                             1,   "auto")    -- Rough Dynamite (Linen Cloth, Rough Blasting Powder)
R(3920, 8067, { {2840, 1}, {4357, 1} },                                             1,   "auto")    -- Crafted Light Shot (Copper Bar, Rough Blasting Powder)

-- Skill 30 — Copper Bolts & Bombs
R(3922, 4359, { {2840, 1} },                                                        30,  "trainer") -- Handful of Copper Bolts (Copper Bar)
R(3923, 4360, { {2589, 1}, {2840, 1}, {4357, 2}, {4359, 1} },                      30,  "trainer") -- Rough Copper Bomb (Linen Cloth, Copper Bar, Rough Blasting Powder, Copper Bolts)

-- Skill 50 — Tubes, Guns, Tools
R(3924, 4361, { {2840, 2}, {2880, 1} },                                             50,  "trainer") -- Copper Tube (Copper Bar x2, Weak Flux)
R(3925, 4362, { {4359, 1}, {4361, 1}, {4399, 1} },                                  50,  "trainer") -- Rough Boomstick (Copper Bolts, Copper Tube, Wooden Stock)
R(7430, 6219, { {2840, 6} },                                                        50,  "trainer") -- Arclight Spanner (Copper Bar x6)

-- Skill 60 — Scope
R(3977, 4405, { {774, 1}, {4359, 1}, {4361, 1} },                                   60,  "trainer") -- Crude Scope (Malachite, Copper Bolts, Copper Tube)

-- Skill 65 — Modulator
R(3926, 4363, { {2589, 2}, {2840, 1}, {4359, 2} },                                  65,  "trainer") -- Copper Modulator (Linen Cloth x2, Copper Bar, Copper Bolts x2)

-- Skill 75 — Coarse tier
R(3929, 4364, { {2836, 1} },                                                        75,  "trainer") -- Coarse Blasting Powder (Coarse Stone)
R(3930, 8068, { {2840, 1}, {4364, 1} },                                             75,  "trainer") -- Crafted Heavy Shot (Copper Bar, Coarse Blasting Powder)
R(3931, 4365, { {2589, 1}, {4364, 3} },                                             75,  "trainer") -- Coarse Dynamite (Linen Cloth, Coarse Blasting Powder x3)

-- Skill 85 — Target Dummy
R(3932, 4366, { {2592, 1}, {2841, 1}, {4359, 2}, {4363, 1} },                      85,  "trainer") -- Target Dummy (Wool Cloth, Bronze Bar, Copper Bolts x2, Copper Modulator)

-- Skill 90 — Silver Contact (intermediate material)
R(3973, 4404, { {2842, 1} },                                                        90,  "trainer") -- Silver Contact (Silver Bar)

-- Skill 100 — Bronze tier starts
R(3934, 4368, { {818, 2}, {2318, 6} },                                              100, "trainer") -- Flying Tiger Goggles (Tigerseye x2, Light Leather x6)
R(3938, 4371, { {2841, 2}, {2880, 1} },                                             105, "trainer") -- Bronze Tube (Bronze Bar x2, Weak Flux)
R(3937, 4370, { {2840, 3}, {4364, 4}, {4404, 1} },                                  105, "trainer") -- Large Copper Bomb (Copper Bar x3, Coarse Blasting Powder x4, Silver Contact)
R(3941, 4374, { {2592, 1}, {2841, 2}, {4364, 4}, {4404, 1} },                       120, "trainer") -- Small Bronze Bomb (Wool Cloth, Bronze Bar x2, Coarse Blasting Powder x4, Silver Contact)

-- Skill 125 — Heavy tier
R(3942, 4375, { {2592, 1}, {2841, 2} },                                             125, "trainer") -- Whirring Bronze Gizmo (Wool Cloth, Bronze Bar x2)
R(3945, 4377, { {2838, 1} },                                                        125, "trainer") -- Heavy Blasting Powder (Heavy Stone)
R(3946, 4378, { {2592, 1}, {4377, 2} },                                             125, "trainer") -- Heavy Dynamite (Wool Cloth, Heavy Blasting Powder x2)

-- Skill 135 — Ornate Spyglass
R(6458, 5507, { {1206, 1}, {4363, 1}, {4371, 2}, {4375, 2} },                       135, "trainer") -- Ornate Spyglass (Moss Agate, Copper Modulator, Bronze Tube x2, Whirring Bronze Gizmo x2)

-- Skill 145 — Bronze Framework
R(3953, 4382, { {2319, 1}, {2592, 1}, {2841, 2} },                                  145, "trainer") -- Bronze Framework (Medium Leather, Wool Cloth, Bronze Bar x2)

-- Skill 150 — Explosive Sheep & Goggles
R(3955, 4384, { {2592, 2}, {4375, 1}, {4377, 2}, {4382, 1} },                       150, "trainer") -- Explosive Sheep (Wool Cloth x2, Whirring Bronze Gizmo, Heavy Blasting Powder x2, Bronze Framework)
R(3956, 4385, { {1206, 2}, {2319, 4}, {4368, 1} },                                  150, "trainer") -- Green Tinted Goggles (Moss Agate x2, Medium Leather x4, Flying Tiger Goggles)
