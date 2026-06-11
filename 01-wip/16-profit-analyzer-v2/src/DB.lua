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

-------------------------------------------------
-- Engineering recipes (skill 150-300)
-- Data sourced from LibCrafts-1.0 (MIT)
-------------------------------------------------

R(12584, 10558, { {3577, 1} },                                                     150, "auto")    -- Gold Power Core (Gold Bar)
R(12589, 10559, { {3860, 3} },                                                     195, "auto")    -- Mithril Tube (Mithril Bar x3)
R(12599, 10561, { {3860, 3} },                                                     215, "auto")    -- Mithril Casing (Mithril Bar x3)
R(12760, 10646, { {4338, 1}, {10505, 3}, {10560, 1} },                              205, "auto")    -- Goblin Sapper Charge (Mageweave Cloth, Solid Blasting Powder x3, Unstable Trigger)
R(12619, 10562, { {10505, 2}, {10560, 1}, {10561, 2} },                             235, "auto")    -- Hi-Explosive Bomb (Solid Blasting Powder x2, Unstable Trigger, Mithril Casing x2)
R(19788, 15992, { {12365, 2} },                                                    250, "auto")    -- Dense Blasting Powder (Dense Stone x2)

-------------------------------------------------
-- Alchemy recipes
-- Data sourced from LibCrafts-1.0 (MIT)
-------------------------------------------------

R(17187, 12360, { {12359, 1}, {12363, 1} },                                        275, "auto")    -- Transmute: Arcanite (Thorium Bar, Arcane Crystal)
R(3175,   3387, { {8839, 2}, {8845, 1}, {8925, 1} },                                250, "auto")    -- Limited Invulnerability Potion (Blindweed x2, Ghost Mushroom, Crystal Vial)
R(11464, 9172, { {8838, 1}, {8845, 1}, {8925, 1} },                                 235, "auto")    -- Invisibility Potion (Sungrass, Ghost Mushroom, Crystal Vial)
R(17573, 13454, { {8925, 1}, {13463, 3}, {13465, 1} },                              285, "auto")    -- Greater Arcane Elixir (Crystal Vial, Dreamfoil x3, Mountain Silversage)
R(17574, 13457, { {7068, 1}, {8925, 1}, {13463, 1} },                               290, "auto")    -- Greater Fire Protection Potion (Elemental Fire, Crystal Vial, Dreamfoil)
R(17575, 13456, { {7070, 1}, {8925, 1}, {13463, 1} },                               290, "auto")    -- Greater Frost Protection Potion (Elemental Water, Crystal Vial, Dreamfoil)
R(17635, 13510, { {8846, 30}, {8925, 1}, {13423, 10}, {13468, 1} },                 300, "auto")    -- Flask of the Titans (Gromsblood x30, Crystal Vial, Stonescale Oil x10, Black Lotus)
R(17637, 13512, { {8925, 1}, {13463, 30}, {13465, 10}, {13468, 1} },                300, "auto")    -- Flask of Supreme Power (Crystal Vial, Dreamfoil x30, Mountain Silversage x10, Black Lotus)

-------------------------------------------------
-- Blacksmithing recipes
-- Data sourced from LibCrafts-1.0 (MIT)
-------------------------------------------------

R(16729, 12640, { {8146, 40}, {12359, 80}, {12360, 12}, {12361, 10}, {12800, 4} },  300, "auto")    -- Lionheart Helm (Wicked Claw x40, Thorium Bar x80, Arcanite Bar x12, Blue Sapphire x10, Azerothian Diamond x4)
R(23653, 19169, { {11371, 12}, {12360, 10}, {12364, 4}, {17010, 5}, {17011, 8} },   300, "auto")    -- Nightfall (Lava Core x12, Arcanite Bar x10, Essence of Fire x4, Essence of Earth x5, Enchanted Elementium x8)
R(27829, 22385, { {7076, 10}, {12360, 12}, {12655, 20}, {13510, 2} },               300, "auto")    -- Titanic Leggings (Essence of Earth x10, Arcanite Bar x12, Enchanted Thorium Bar x20, Flask of the Titans x2)
R(17180, 12655, { {11176, 3}, {12359, 1} },                                        250, "auto")    -- Enchanted Thorium Bar (Dream Dust x3, Thorium Bar)

-------------------------------------------------
-- Leatherworking recipes
-- Data sourced from LibCrafts-1.0 (MIT)
-------------------------------------------------

R(10487,  8173, { {4291, 1}, {4304, 5} },                                          200, "auto")    -- Thick Armor Kit (Thick Leather, Silken Thread x5)
R(10499,  8175, { {4291, 2}, {4304, 7} },                                          205, "auto")    -- Nightscape Tunic (Thick Leather x2, Silken Thread x7)
R(19047, 15407, { {8171, 1}, {15409, 1} },                                         230, "auto")    -- Cured Rugged Hide (Rugged Hide, Refined Deeprock Salt)
R(19084, 15063, { {8170, 30}, {14341, 1}, {15417, 8} },                            290, "auto")    -- Devilsaur Gauntlets (Devilsaur Leather x30, Rune Thread, Rugged Leather x8)
R(19097, 15062, { {8170, 30}, {14341, 1}, {15407, 1}, {15417, 14} },               300, "auto")    -- Devilsaur Leggings (Devilsaur Leather x30, Rune Thread, Cured Rugged Hide, Rugged Leather x14)
R(22927, 18510, { {7080, 10}, {8170, 30}, {12803, 12}, {14341, 8}, {15407, 3}, {18512, 8} }, 300, "auto") -- Hide of the Wild (Essence of Water x10, Devilsaur Leather x30, Living Essence x12, Rune Thread x8, Cured Rugged Hide x3, Larval Acid x8)
R(23709, 19162, { {12810, 10}, {14227, 4}, {15407, 4}, {17010, 8}, {17012, 12} },  300, "auto")    -- Corehound Belt (Cored Leather x10, Heavy Silken Thread x4, Cured Rugged Hide x4, Essence of Earth x8, Mooncloth x12)

-------------------------------------------------
-- Tailoring recipes
-- Data sourced from LibCrafts-1.0 (MIT)
-------------------------------------------------

R(18560, 14342, { {14256, 2} },                                                    250, "auto")    -- Mooncloth (Felcloth x2)
R(18445, 14155, { {14048, 4}, {14341, 1}, {14342, 1} },                             300, "auto")    -- Mooncloth Bag (Bolt of Runecloth x4, Rune Thread, Mooncloth)
R(18455, 14156, { {14048, 8}, {14341, 2}, {14342, 12}, {14344, 2}, {17012, 2} },    300, "auto")    -- Bottomless Bag (Bolt of Runecloth x8, Rune Thread x2, Mooncloth x12, Large Brilliant Shard x2, Mooncloth x2)
R(18457, 14152, { {7076, 10}, {7078, 10}, {7080, 10}, {7082, 10}, {14048, 12}, {14341, 2} }, 300, "auto") -- Robe of the Archmage (Essence of Earth x10, Essence of Fire x10, Essence of Water x10, Essence of Air x10, Bolt of Runecloth x12, Rune Thread x2)
R(24091, 19682, { {12804, 4}, {14048, 4}, {14227, 2}, {14342, 3}, {19726, 5} },    300, "auto")    -- Bloodvine Vest (Powerful Mojo x4, Bolt of Runecloth x4, Heavy Silken Thread x2, Mooncloth x3, Bloodvine x5)
R(24092, 19683, { {12804, 4}, {14048, 4}, {14227, 2}, {14342, 4}, {19726, 4} },    300, "auto")    -- Bloodvine Leggings (Powerful Mojo x4, Bolt of Runecloth x4, Heavy Silken Thread x2, Mooncloth x4, Bloodvine x4)

-------------------------------------------------
-- Enchanting recipes
-- Data sourced from LibCrafts-1.0 (MIT)
-------------------------------------------------

R(25129, 20749, { {4625, 3}, {14344, 2}, {18256, 1} },                             300, "auto")    -- Brilliant Wizard Oil (Firebloom x3, Large Brilliant Shard x2, Imbued Vial)
R(25130, 20748, { {8831, 3}, {14344, 2}, {18256, 1} },                              300, "auto")    -- Brilliant Mana Oil (Stranglekelp x3, Large Brilliant Shard x2, Imbued Vial)

-------------------------------------------------
-- Cooking & First Aid
-- Data sourced from LibCrafts-1.0 (MIT)
-------------------------------------------------

R(15933, 12218, { {3713, 2}, {12207, 1} },                                         225, "auto")    -- Monster Omelet (Giant Egg x2, Soothing Spices)
R(18629, 14529, { {14047, 1} },                                                    260, "auto")    -- Runecloth Bandage (Runecloth)
