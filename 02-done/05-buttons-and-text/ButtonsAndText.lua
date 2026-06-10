-- ButtonsAndText.lua — Capsule 05: Buttons, FontStrings, OnClick handlers
--
-- What you'll learn:
--   - CreateFrame("Button", ...) with UIPanelButtonTemplate and UIPanelCloseButton
--   - SetText() / GetText() to display and update button labels
--   - OnClick handler: function(self, button, down)
--   - Enable / Disable / SetEnabled for button states
--   - CreateFontString() for dynamic text labels
--   - Anchoring chain: each element anchored on the previous one

local addonName, ns = ...

-- Color constants for chat messages
local GREEN = "|cFF33FF99"
local RESET = "|r"

-- Click counter
local clickCount = 0

-- Forward declarations for UI elements used across sections.
-- ⚠️ GOTCHA: If a handler references a variable before it's assigned,
-- Lua won't complain at parse time (it's inside a function), but it will
-- crash at runtime with "attempt to index global 'xxx' (a nil value)".
-- Fix: declare all shared references as upvalues at the top.
local mainFrame, statusText, infoText, resetBtn, toggleBtn

-- Slash commands
SLASH_BUTTONSANDTEXT1 = "/btntest"
SLASH_BUTTONSANDTEXT2 = "/bt"

SlashCmdList["BUTTONSANDTEXT"] = function(msg)
    msg = strtrim(msg or "")
    if msg == "show" then
        mainFrame:Show()
    elseif msg == "hide" then
        mainFrame:Hide()
    else
        mainFrame:SetShown(not mainFrame:IsShown())
    end
end

-- ==========================================================================
-- 1. Create the main frame (same pattern as capsule 04)
-- BackdropTemplate is REQUIRED for SetBackdrop to work in Classic Era 1.15.x
-- ==========================================================================

mainFrame = CreateFrame("Frame", "ButtonsAndTextFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(320, 260)
mainFrame:SetPoint("CENTER")
mainFrame:SetBackdrop(BACKDROP_DIALOG_32_32)
mainFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
mainFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

-- Make it draggable — all 3 calls are mandatory:
-- SetMovable + EnableMouse + RegisterForDrag. No error if one is missing,
-- the frame just silently refuses to move.
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetClampedToScreen(true)

-- ==========================================================================
-- 2. Title text (FontString)
-- FontStrings are NOT created via CreateFrame — use frame:CreateFontString().
-- "GameFontNormalLarge" = larger font inherited from Blizzard's font system.
-- ============================================================================

local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", mainFrame, "TOP", 0, -16)
title:SetText("Buttons & Text Demo")

-- ==========================================================================
-- 3. Close button (UIPanelCloseButton)
-- UIPanelCloseButton is a template: 32×32 button with an X icon.
-- Its default OnClick handler calls self:GetParent():Hide().
-- ============================================================================

local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)

-- ==========================================================================
-- 4. Status text — dynamic text that changes on button clicks
-- This is the "anchor hub" of our UI chain:
--   title → statusText → clickBtn → resetBtn → toggleBtn → infoText
-- Moving statusText moves everything below it.
-- ============================================================================

statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("TOP", title, "BOTTOM", 0, -20)
statusText:SetText("Clicks: 0")

-- ==========================================================================
-- 5. "Click Me" button — UIPanelButtonTemplate
-- The template provides: textures (Left/Middle/Right), fonts per state,
-- highlight effect, and tooltip support. Default size: 40×22.
-- OnClick signature: function(self, button, down)
--   self    = the button itself
--   button  = "LeftButton", "RightButton", etc.
--   down    = true (pressed) or false (released)
-- ============================================================================

local clickBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
clickBtn:SetSize(120, 24)
clickBtn:SetPoint("TOP", statusText, "BOTTOM", 0, -16)
clickBtn:SetText("Click Me")

clickBtn:SetScript("OnClick", function(self, button)
    clickCount = clickCount + 1
    statusText:SetText("Clicks: " .. clickCount)

    -- Enable the Reset button when counter > 0
    resetBtn:SetEnabled(true)

    print(GREEN .. "[BtnTest]" .. RESET .. " Click #" .. clickCount .. " with " .. button)
end)

-- ==========================================================================
-- 6. "Reset" button — resets counter and disables itself
-- SetEnabled(false) grays out the button and prevents OnClick from firing.
-- Starts disabled because the counter is already at 0.
-- ============================================================================

resetBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
resetBtn:SetSize(120, 24)
resetBtn:SetPoint("TOP", clickBtn, "BOTTOM", 0, -8)
resetBtn:SetText("Reset")

resetBtn:SetScript("OnClick", function(self, button)
    clickCount = 0
    statusText:SetText("Clicks: 0")
    self:SetEnabled(false) -- disable self after reset
    infoText:Hide()
    toggleBtn:SetText("Toggle Info")

    print(GREEN .. "[BtnTest]" .. RESET .. " Counter reset!")
end)

resetBtn:SetEnabled(false) -- starts disabled (counter is already 0)

-- ==========================================================================
-- 7. "Toggle Info" button — shows/hides an info text area
-- Demonstrates: changing button text dynamically with SetText(),
-- and toggling visibility of another element.
-- ============================================================================

toggleBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
toggleBtn:SetSize(120, 24)
toggleBtn:SetPoint("TOP", resetBtn, "BOTTOM", 0, -8)
toggleBtn:SetText("Toggle Info")

toggleBtn:SetScript("OnClick", function(self, button)
    if infoText:IsShown() then
        infoText:Hide()
        self:SetText("Toggle Info")
    else
        infoText:Show()
        self:SetText("Hide Info")
    end
end)

-- ==========================================================================
-- 8. Info text — hidden by default, toggled by the button above
-- FontStrings support \n for line breaks and |cFFRRGGBB...|r for colors.
-- SetJustifyH("LEFT") aligns text to the left within its width.
-- ============================================================================

infoText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
infoText:SetPoint("TOP", toggleBtn, "BOTTOM", 0, -12)
infoText:SetWidth(280)
infoText:SetJustifyH("LEFT")
infoText:SetText(
    "This demo shows:\n"
    .. "|cFF00FF00- UIPanelButtonTemplate|r (standard buttons)\n"
    .. "|cFF00FF00- UIPanelCloseButton|r (X button)\n"
    .. "|cFF00FF00- CreateFontString()|r (text labels)\n"
    .. "|cFF00FF00- OnClick|r (click handlers)\n"
    .. "|cFF00FF00- Enable/Disable|r (button states)"
)
infoText:Hide()

-- ==========================================================================
-- 9. Hide frame at startup
-- ⚠️ GOTCHA (from capsule 04): frames are SHOWN by default after CreateFrame.
-- If we don't Hide() now, the first /btntest toggle would HIDE it instead of
-- showing it.
-- ============================================================================

mainFrame:Hide()
