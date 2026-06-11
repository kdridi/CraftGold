-- src/UI.lua
-- Recipe browser window using Component Mixin pattern.
-- Each RecipeLine is autonomous: it knows how to render and update itself.
-- Uses Blizzard's ContinueOnItemLoad for async item name resolution.

local _, ns = ...

local UI = {}
ns.UI = UI

local FRAME_WIDTH = 480
local LINE_HEIGHT = 18
local PADDING_TOP = 45
local PADDING_BOTTOM = 15
local PADDING_SIDE = 20

-------------------------------------------------
-- Source tag with color
-------------------------------------------------

local function sourceTag(source)
    local tags = {
        auto    = "|cFF00FF00auto|r",
        trainer = "|cFF4FC3F7trainer|r",
        vendor  = "|cFFFF9800vendor|r",
        drop    = "|cFFFF5722drop|r",
        quest   = "|cFF9C27B0quest|r",
    }
    return tags[source] or source
end

-------------------------------------------------
-- Quality colors for item rarity
-------------------------------------------------

local QUALITY_COLORS = {
    [0] = "|cFF9D9D9D", -- Poor (gray)
    [1] = "|cFFFFFFFF", -- Common (white)
    [2] = "|cFF1EFF00", -- Uncommon (green)
    [3] = "|cFF0070DD", -- Rare (blue)
    [4] = "|cFFA335EE", -- Epic (purple)
}

local function qualityColor(itemID)
    local _, _, quality = GetItemInfo(itemID)
    if quality and QUALITY_COLORS[quality] then
        return QUALITY_COLORS[quality]
    end
    return "|cFFFFFFFF"
end

-------------------------------------------------
-- RecipeLineMixin — autonomous line component
-------------------------------------------------
-- Each line encapsulates:
--   - its data (recipe)
--   - its render logic (Render)
--   - its async lifecycle (ContinueOnItemLoad)
-- No external index needed.

RecipeLineMixin = {}

function RecipeLineMixin:Init(recipe)
    self.recipe = recipe

    -- Create the highlight texture
    self.highlight = self:CreateTexture(nil, "BACKGROUND")
    self.highlight:SetAllPoints(self)
    self.highlight:SetColorTexture(1, 1, 1, 0.08)
    self.highlight:Hide()

    -- Create the text
    self.text = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.text:SetPoint("LEFT", self, "LEFT", 4, 0)
    self.text:SetJustifyH("LEFT")
    self.text:SetWordWrap(false)

    -- Hover handlers
    self:SetScript("OnEnter", function()
        self.highlight:Show()
        UI.ShowTooltip(self, self.recipe)
    end)
    self:SetScript("OnLeave", function()
        self.highlight:Hide()
        GameTooltip:Hide()
    end)

    -- Set the recipe data and start async resolution
    self:SetRecipe(recipe)
end

function RecipeLineMixin:SetRecipe(recipe)
    self.recipe = recipe
    self:Render()

    -- If item name is not cached, ask Blizzard to call us back when it arrives
    local name = GetItemInfo(recipe.output)
    if not name then
        local item = Item:CreateFromItemID(recipe.output)
        item:ContinueOnItemLoad(function()
            -- Guard: this line might have been recycled for another recipe
            if self.recipe == recipe then
                self:Render()
            end
        end)
    end
end

function RecipeLineMixin:Render()
    local name = GetItemInfo(self.recipe.output)
    local display = name or ("|cff808080item:" .. self.recipe.output .. "|r")

    self.text:SetText(string.format("|cFFFFFF00[%3d]|r %s %s",
        self.recipe.skillRequired,
        display,
        sourceTag(self.recipe.source)
    ))
end

-------------------------------------------------
-- Show GameTooltip with recipe details
-------------------------------------------------

function UI.ShowTooltip(owner, recipe)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    -- Header: output item name with quality color
    local color = qualityColor(recipe.output)
    local name = GetItemInfo(recipe.output) or ("item:" .. recipe.output)
    GameTooltip:AddDoubleLine(color .. name .. "|r", "item:" .. recipe.output)

    -- Spell ID and source
    GameTooltip:AddLine(string.format("Spell: %d  |  Skill: %d  |  Source: %s",
        recipe.spellID, recipe.skillRequired, recipe.source), 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")

    -- Reagents
    GameTooltip:AddLine("Reagents:", 1, 1, 0)
    for _, reagent in ipairs(recipe.reagents) do
        local craftable = ns.Core.isCraftable(reagent[1])
        local tag = craftable and " |cFF00FF00(craftable)|r" or ""
        local rColor = qualityColor(reagent[1])
        local rName = GetItemInfo(reagent[1]) or ("item:" .. reagent[1])
        GameTooltip:AddDoubleLine(
            string.format("  %s%s|r%s", rColor, rName, tag),
            "|cFFFFFFFFx" .. reagent[2] .. "|r"
        )
    end

    GameTooltip:Show()
end

-------------------------------------------------
-- Create the recipe browser window
-------------------------------------------------

function UI.Create()
    local DB = ns.DB

    -- Main frame
    local frame = CreateFrame("Frame", "RecipeDBFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(FRAME_WIDTH)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFF00FF00RecipeDB|r — Engineering (1-150)")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    -- Sort recipes by skillRequired then spellID
    local sorted = {}
    for _, recipe in pairs(DB.recipes) do
        sorted[#sorted + 1] = recipe
    end
    table.sort(sorted, function(a, b)
        if a.skillRequired ~= b.skillRequired then
            return a.skillRequired < b.skillRequired
        end
        return a.spellID < b.spellID
    end)

    -- Create a RecipeLine for each recipe using the Mixin pattern
    local yOffset = -PADDING_TOP

    for i, recipe in ipairs(sorted) do
        local line = CreateFrame("Button", nil, frame)
        line:SetHeight(LINE_HEIGHT)
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING_SIDE, yOffset)
        line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING_SIDE, yOffset)

        -- Inject the mixin methods into this frame
        Mixin(line, RecipeLineMixin)
        line:Init(recipe)

        yOffset = yOffset - LINE_HEIGHT
    end

    -- Resize frame to fit content
    local contentHeight = #sorted * LINE_HEIGHT + PADDING_TOP + PADDING_BOTTOM
    frame:SetHeight(contentHeight)

    return frame
end

-------------------------------------------------
-- Toggle show/hide
-------------------------------------------------

function UI.Toggle(frame)
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
