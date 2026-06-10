-- MyFirstFrame.lua — Capsule 04: CreateFrame, Backdrop, Drag

local addonName = "MyFirstFrame"

-- Forward declaration: our main frame (created on first use)
local mainFrame = nil

-- ---------------------------------------------------------------------------
-- Frame creation (called once, on first /myframe)
-- ---------------------------------------------------------------------------
local function CreateMainFrame()
    -- CreateFrame(type, name, parent, template)
    -- "BackdropTemplate" is MANDATORY in 1.15.x to get SetBackdrop()
    local frame = CreateFrame("Frame", "CraftGoldMainFrame", UIParent, "BackdropTemplate")

    -- Size in UI units (affected by UI Scale)
    frame:SetSize(400, 300)

    -- Anchor: center of the screen
    frame:SetPoint("CENTER")

    -- Backdrop: background + border
    -- NOTE: always call SetBackdrop BEFORE SetBackdropColor!
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    -- Tint the background (r, g, b, a — values 0.0 to 1.0, NOT 0-255!)
    frame:SetBackdropColor(0, 0, 0, 0.8)

    -- Tint the border (white = show original border colors)
    frame:SetBackdropBorderColor(1, 1, 1, 1)

    -- Title text: CreateFontString on the frame
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("My First Frame")

    -- Configure drag: all 3 are required or nothing happens (silently!)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Keep the frame inside the screen
    frame:SetClampedToScreen(true)

    -- Frames are SHOWN by default after CreateFrame.
    -- Hide it so the first /myframe toggle shows it.
    frame:Hide()

    return frame
end

-- ---------------------------------------------------------------------------
-- Slash command: /myframe [show|hide]
-- ---------------------------------------------------------------------------
SLASH_MYFIRSTFRAME1 = "/myframe"
SlashCmdList["MYFIRSTFRAME"] = function(msg)
    msg = msg and strtrim(msg):lower() or ""

    -- Lazy init: create the frame on first call
    if not mainFrame then
        mainFrame = CreateMainFrame()
    end

    if msg == "show" then
        mainFrame:Show()
        print("|cFF00FF00[MyFirstFrame]|r Frame shown.")
    elseif msg == "hide" then
        mainFrame:Hide()
        print("|cFF00FF00[MyFirstFrame]|r Frame hidden.")
    else
        -- Toggle: shown -> hide, hidden -> show
        mainFrame:SetShown(not mainFrame:IsShown())
        print("|cFF00FF00[MyFirstFrame]|r Toggled.")
    end
end

print("|cFF00FF00[" .. addonName .. "]|r Loaded! Type /myframe to begin.")
