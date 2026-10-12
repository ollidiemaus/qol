local _, ns = ...
local Options = ns.Options

-- Mana in bear and cat form: a third bar on the player frame, under the rage or energy bar, while
-- the player's power isn't mana but the character has mana. That is Blizzard's rule for the druid
-- mana bar of its Wrath to Mists clients (AlternatePowerBar_UpdatePowerType). Forever's frame has
-- a third bar only for astral power (moonkin on retail), which Forever doesn't have.
--
-- It is drawn the way PlayerFrame_ToPlayerArt draws the frame with that third bar: the frame's art
-- with room for it (the AlternatePowerFrameTexture atlas, at its place), the mana bar's texture at
-- the place and size of PlayerFrameAlternatePowerBarBaseTemplate, and the threat glow that fits
-- that art. The rage or energy bar keeps its mask: the one Blizzard gives it then differs by a
-- pixel the frame covers.
--
-- The bar, its text and the art are ours. On Blizzard's frame only widget methods are called: the
-- usual art (FrameTexture) gets alpha 0, which Blizzard never sets (it only shows and hides it), and
-- the threat glow (FrameFlash) gets the other atlas. Blizzard sets the glow again whenever it draws
-- the frame (entering the world, vehicles), so those events are wake-ups. Druids shift in combat
-- and none of this is protected, so it runs in combat too.
local DruidManaBar = {}
ns.DruidManaBar = DruidManaBar

local KEY = "druidManaBar"
local MANA = Enum.PowerType.Mana

-- From PlayerFrame.xml, AlternatePowerBarBase.xml and PlayerFrame_ToPlayerArt.
local ART = "UI-HUD-UnitFrame-Player-PortraitOn-ClassResource"
local BAR = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana"
local GLOW = "UI-HUD-UnitFrame-Player-PortraitOn-InCombat"
local GLOW_THIRD_BAR = "UI-HUD-UnitFrame-Player-PortraitOn-ClassResource-InCombat"

-- Created the first time the bar shows.
local bar, art, text, leftText, rightText
local hovered = false
-- The usual art's alpha before we hid it, while it is hidden.
local frameAlpha
-- The threat glow has the third bar's atlas from us.
local glowChanged = false

-- Shown while the player's own art is drawn (not a vehicle's), without a third bar of Blizzard's
-- (moonkin on retail) or a class bar where ours goes (retail's combo points in cat form).
function DruidManaBar.ShouldShow()
    if not Options:Get(KEY) then return false end
    local frame = PlayerFrame
    if not (frame and frame.PlayerFrameContainer and frame.state == "player") then return false end
    if frame.activeAlternatePowerBar then return false end
    local classBar = frame.classPowerBar
    if classBar and classBar:IsShown() then return false end
    local powerType = UnitPowerType("player")
    if not ns.IsUsable(powerType) or powerType == MANA then return false end
    local maxMana = UnitPowerMax("player", MANA)
    return ns.IsUsable(maxMana) and maxMana > 0
end

local function number(value)
    return AbbreviateLargeNumbers and AbbreviateLargeNumbers(value) or tostring(value)
end

local function percent(value, maxValue)
    return math.ceil(value / maxValue * 100) .. "%"
end

-- Like the frame's other bars (TextStatusBar): the game's Status Text setting shows the text always
-- ("statusText") or only under the mouse, as numbers, a percentage or both ("statusTextDisplay";
-- both puts the percentage left and the mana right, as on a mana bar).
local function updateText()
    text:SetText("")
    leftText:SetText("")
    rightText:SetText("")
    if not (hovered or C_CVar.GetCVar("statusText") == "1") then return end
    local value, maxValue = UnitPower("player", MANA), UnitPowerMax("player", MANA)
    if not (ns.IsUsable(value) and ns.IsUsable(maxValue)) or maxValue <= 0 then return end
    local mode = C_CVar.GetCVar("statusTextDisplay")
    if mode == "BOTH" then
        leftText:SetText(percent(value, maxValue))
        rightText:SetText(number(value))
    elseif mode == "PERCENT" then
        text:SetText(percent(value, maxValue))
    else
        text:SetText(number(value) .. " / " .. number(maxValue))
    end
end

local function updateValue()
    bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
    bar:SetValue(UnitPower("player", MANA))
    updateText()
end

local function newText(point, x)
    local fontString = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    fontString:SetPoint(point, bar, point, x, 0)
    return fontString
end

-- The art goes on the frame's art layer, under the bars; the bar where Blizzard's third bar goes,
-- above the art.
local function create()
    local container = PlayerFrame.PlayerFrameContainer
    art = container:CreateTexture(nil, "BACKGROUND", nil, 2)
    art:SetAtlas(ART, true)
    art:SetPoint("CENTER", container, "CENTER", 0, -1.5)
    art:Hide()

    local main = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
    bar = CreateFrame("StatusBar", nil, main)
    bar:SetSize(124, 9)
    bar:SetPoint("TOPLEFT", main, "TOPLEFT", 85, -73)
    bar:SetStatusBarTexture(BAR)
    bar:Hide()
    text, leftText, rightText = newText("CENTER", 0), newText("LEFT", 2), newText("RIGHT", -2)
    -- Under the mouse it shows its text, like the frame's mana bar; clicks reach the frame.
    bar:SetMouseMotionEnabled(true)
    bar:SetMouseClickEnabled(false)
    bar:SetScript("OnEnter", function()
        hovered = true
        updateText()
    end)
    bar:SetScript("OnLeave", function()
        hovered = false
        updateText()
    end)
end

local function hasAtlas(texture, atlas)
    local current = texture:GetAtlas()
    return current ~= nil and current:lower() == atlas:lower()
end

function DruidManaBar:Apply()
    local show = self.ShouldShow()
    if not bar then
        if not show then return end
        create()
    end
    local container = PlayerFrame.PlayerFrameContainer
    local frameArt, glow = container.FrameTexture, container.FrameFlash
    if show then
        if not frameAlpha then frameAlpha = frameArt:GetAlpha() end
        if frameArt:GetAlpha() ~= 0 then frameArt:SetAlpha(0) end
        art:Show()
        if not hasAtlas(glow, GLOW_THIRD_BAR) then
            glow:SetAtlas(GLOW_THIRD_BAR, true)
            glow:SetPoint("CENTER", container, "CENTER", -2, 0.5)
        end
        glowChanged = true
        updateValue()
        bar:Show()
        return
    end
    bar:Hide()
    art:Hide()
    if frameAlpha then
        frameArt:SetAlpha(frameAlpha)
        frameAlpha = nil
    end
    -- The glow PlayerFrame_ToPlayerArt gives the frame without a third bar, unless Blizzard has
    -- drawn the frame since (a vehicle's glow) or draws a third bar of its own.
    if glowChanged then
        glowChanged = false
        if PlayerFrame.state == "player" and not PlayerFrame.activeAlternatePowerBar
            and hasAtlas(glow, GLOW_THIRD_BAR) then
            glow:SetAtlas(GLOW, true)
            glow:SetPoint("CENTER", container, "CENTER", -1.5, 1)
        end
    end
end

local function schedule()
    ns.Later("druidManaBar", function() DruidManaBar:Apply() end, true)
end

local function isActive()
    return Options:Get(KEY) or (bar ~= nil and bar:IsShown())
end

-- Wake-ups for whether the bar shows: a new form (its power), the mana pool, and Blizzard drawing
-- the frame again, which gives the glow back its own atlas.
local EVENTS = { "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM" }
local UNIT_EVENTS = {
    "UNIT_DISPLAYPOWER",
    "UNIT_MAXPOWER",
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITING_VEHICLE",
    "UNIT_EXITED_VEHICLE",
}

function DruidManaBar:Init()
    Options:Watch({ KEY }, schedule)

    local function wake()
        if isActive() then schedule() end
    end
    for _, event in ipairs(EVENTS) do
        ns.Events:On(event, wake)
    end
    for _, event in ipairs(UNIT_EVENTS) do
        ns.Events:On(event, function(_, unit)
            if unit == "player" then wake() end
        end)
    end
    -- The mana as it changes, and the Status Text setting, while the bar shows.
    ns.Events:On("UNIT_POWER_FREQUENT", function(_, unit, powerToken)
        if unit == "player" and powerToken == "MANA" and bar and bar:IsShown() then updateValue() end
    end)
    ns.Events:On("CVAR_UPDATE", function(_, name)
        if (name == "statusText" or name == "statusTextDisplay") and bar and bar:IsShown() then updateText() end
    end)
    wake()
end
