local _, ns = ...
local Options = ns.Options

-- Threat badges (Forever only): a small box with the player's threat on an enemy in percent, its
-- background in the color of the player's threat state. One on the target frame and one on the focus
-- frame, on top of the name background where the game puts its own numeric threat (hidden while ours
-- is on), and one left of each enemy nameplate's health bar, mirroring the level box. ADR 0008 says
-- why they are our own; docs/dev/bars-and-frames.md why they are taint-safe.
--
-- The number is the game's (UnitFrame_UpdateThreatIndicator): the raw percent, or the lead over the
-- next player while tanking; a 0 shows nothing. Threat isn't secret on Forever (ADR 0008), so values
-- are compared and formatted plainly once ns.IsUsable says they can be.
--
-- Everything drawn is a frame of ours, not protected: badges show, move and change color in combat.
-- Only the game's NumericalThreat is touched, parented to ns.Hider's holder through ns.Later.
local Threat = {}
ns.Threat = Threat

local TARGET, FOCUS, PLATES, COLORS = "threatTarget", "threatFocus", "threatNameplates", "threatColors"
local KEYS = { TARGET, FOCUS, PLATES, COLORS }
-- How often the shown badges are read again in combat: threat events don't come for every change
-- of the number.
local REFRESH_SECONDS = 0.25
local MAX_PLATES = 40

-- Tank colors: state 3 (holding aggro securely) green, then the game's yellow, orange and red the
-- other way round.
local GREEN = { 0.25, 0.9, 0.25 }
local TANK_STATES = { [2] = 1, [1] = 2, [0] = 3 }

-- Forever's bronze (Media/MinimapSquareBorder.tga, 512 square): its corners and edges, drawn at
-- CORNER units, reaching OUTSET past the badge.
local BRONZE = "Interface\\AddOns\\QoL\\Media\\MinimapSquareBorder"
local SLICE = 24 / 512
local CORNER, OUTSET = 5, 2
-- The game's numeric threat: its size and background.
local FRAME_WIDTH, FRAME_HEIGHT = 49, 18
local FRAME_BACKGROUND = "Interface\\TargetingFrame\\UI-StatusBar"
-- The nameplate's level box (Camelot/Blizzard_NamePlateLevelFrame.xml): its art, and where it sits
-- right of the health bar, mirrored here to the left.
local PLATE_ATLAS = "ui-hud-nameplates-levelindicator"
local PLATE_GAP, PLATE_TOP, PLATE_BOTTOM = 5, 3, -2
local PLATE_MIN_WIDTH, PLATE_PADDING = 20, 6

-- Whether the client is WoW Forever, the only one the badges and the Threat page are for.
function Threat.IsAvailable()
    return ns.IsForever()
end

-- The target and focus badges by unit, made the first time they're turned on.
local FRAMES = { target = { name = "TargetFrame", key = TARGET }, focus = { name = "FocusFrame", key = FOCUS } }
local frameBadges = {}
-- Nameplate badges: one per nameplate unit frame (plates are pooled and reused), and the one each
-- nameplate unit has now.
local plateBadges, unitBadges = {}, {}

-- Wake-ups for every badge: a new target or focus, the group (a pet or a group makes threat matter;
-- the role decides tank colors), a stance or form, and combat for the refresh.
local EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
    "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
-- The nameplates' threat comes on ns.Events, not on unit listeners: up to forty units. The handler
-- skips every unit but nameplates.
local PLATE_EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_THREAT_LIST_UPDATE" }

local events, plateEvents, frameListener, playerListener
local ticker
local inCombat = false
-- Tank colors now, worked out when the option, a stance or form, the role or combat changes.
local tankColors = false
-- How many badges show.
local shownCount = 0

local function readTank()
    local mode = Options:Get(COLORS)
    if mode == "tank" then return true end
    if mode == "normal" then return false end
    return PlayerUtil ~= nil and PlayerUtil.IsPlayerEffectivelyTank() == true
end

local function color(status)
    if tankColors then
        if status == 3 then return GREEN[1], GREEN[2], GREEN[3] end
        return GetThreatStatusColor(TANK_STATES[status])
    end
    return GetThreatStatusColor(status)
end

-- The number the badge shows and the threat state, or nil for no badge.
local function threatOn(unit)
    if not UnitExists(unit) then return nil end
    local attackable = UnitCanAttack("player", unit)
    if not (ns.IsUsable(attackable) and attackable) then return nil end
    local dead = UnitIsDead(unit)
    if not ns.IsUsable(dead) or dead then return nil end
    -- Solo without a pet the player always has all of it.
    if not (IsInGroup() or UnitExists("pet")) then return nil end
    local isTanking, status, _, rawPercent = UnitDetailedThreatSituation("player", unit)
    if not (ns.IsUsable(status) and ns.IsUsable(isTanking)) then return nil end
    local value = rawPercent
    if isTanking then value = UnitThreatPercentageOfLead("player", unit) end
    if not ns.IsUsable(value) or value == 0 then return nil end
    return value, status
end

local function setShown(badge, shown)
    if badge:IsShown() == shown then return end
    shownCount = shownCount + (shown and 1 or -1)
    badge:SetShown(shown)
end

-- Reads the badge's unit again. Sets the text only when the shown number changes and the color
-- only when the state or the colors do: this runs a few times a second for every badge.
-- A nameplate badge: wide enough for its number, and at least the level box's width (read when the
-- plate gets its unit, not on every number).
local function fitPlateWidth(badge)
    local width = badge.levelWidth
    local needed = badge.text:GetStringWidth()
    if ns.IsUsable(needed) and needed + PLATE_PADDING > width then width = needed + PLATE_PADDING end
    badge:SetWidth(width)
end

local function update(badge)
    local value, status
    if badge.unit then value, status = threatOn(badge.unit) end
    if not value then
        setShown(badge, false)
        return
    end
    local number = math.floor(value + 0.5)
    if number ~= badge.number then
        badge.number = number
        badge.text:SetFormattedText("%d%%", number)
        if badge.isPlate then fitPlateWidth(badge) end
    end
    if status ~= badge.status or tankColors ~= badge.tank then
        badge.status, badge.tank = status, tankColors
        badge.background:SetVertexColor(color(status))
    end
    setShown(badge, true)
end

local function updateTicker()
    local want = inCombat and shownCount > 0
    if want and not ticker then
        ticker = C_Timer.NewTicker(REFRESH_SECONDS, Threat.Refresh)
    elseif not want and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- Every badge read again.
function Threat.Refresh()
    for _, badge in pairs(frameBadges) do update(badge) end
    for _, badge in pairs(unitBadges) do update(badge) end
    updateTicker()
end

-- Forever's bronze around a badge: four corners and four edges cut from the square border.
local function addBronze(badge)
    local function piece(left, right, top, bottom)
        local texture = badge:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(BRONZE)
        texture:SetTexCoord(left, right, top, bottom)
        return texture
    end
    local far = 1 - SLICE
    local corners = {
        { "TOPLEFT", 0, SLICE, 0, SLICE, -OUTSET, OUTSET },
        { "TOPRIGHT", far, 1, 0, SLICE, OUTSET, OUTSET },
        { "BOTTOMLEFT", 0, SLICE, far, 1, -OUTSET, -OUTSET },
        { "BOTTOMRIGHT", far, 1, far, 1, OUTSET, -OUTSET },
    }
    local placed = {}
    for _, c in ipairs(corners) do
        local texture = piece(c[2], c[3], c[4], c[5])
        texture:SetSize(CORNER, CORNER)
        texture:SetPoint(c[1], badge, c[1], c[6], c[7])
        placed[c[1]] = texture
    end
    local top = piece(SLICE, far, 0, SLICE)
    top:SetPoint("TOPLEFT", placed.TOPLEFT, "TOPRIGHT")
    top:SetPoint("BOTTOMRIGHT", placed.TOPRIGHT, "BOTTOMLEFT")
    local bottom = piece(SLICE, far, far, 1)
    bottom:SetPoint("TOPLEFT", placed.BOTTOMLEFT, "TOPRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", placed.BOTTOMRIGHT, "BOTTOMLEFT")
    local left = piece(0, SLICE, SLICE, far)
    left:SetPoint("TOPLEFT", placed.TOPLEFT, "BOTTOMLEFT")
    left:SetPoint("BOTTOMRIGHT", placed.BOTTOMLEFT, "TOPRIGHT")
    local right = piece(far, 1, SLICE, far)
    right:SetPoint("TOPLEFT", placed.TOPRIGHT, "BOTTOMLEFT")
    right:SetPoint("BOTTOMRIGHT", placed.BOTTOMRIGHT, "TOPRIGHT")
end

-- The badge on the target or focus frame: the game's numeric threat's size, on the same spot, on
-- the frame's contextual layer (above its art, hidden with the frame, at its scale).
local function newFrameBadge(unit)
    local content = _G[FRAMES[unit].name].TargetFrameContent
    local badge = CreateFrame("Frame", nil, content.TargetFrameContentContextual)
    badge:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    badge:SetPoint("BOTTOM", content.TargetFrameContentMain.ReputationColor, "TOP", 0, 0)
    badge.background = badge:CreateTexture(nil, "BACKGROUND")
    badge.background:SetTexture(FRAME_BACKGROUND)
    badge.background:SetAllPoints(badge)
    addBronze(badge)
    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badge:Hide()
    badge.unit = unit
    return badge
end

-- The badge on a nameplate: a child of its unit frame (so it follows the plate's scale), left of
-- the health bar as the level box sits right of it, in the level box's art.
local function newPlateBadge(unitFrame)
    local healthBar = unitFrame.HealthBarsContainer.healthBar
    local badge = CreateFrame("Frame", nil, unitFrame)
    badge:SetPoint("TOPRIGHT", healthBar, "TOPLEFT", -PLATE_GAP, PLATE_TOP)
    badge:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMLEFT", -PLATE_GAP, PLATE_BOTTOM)
    badge.background = badge:CreateTexture(nil, "BACKGROUND")
    badge.background:SetAtlas(PLATE_ATLAS)
    badge.background:SetAllPoints(badge)
    badge.text = badge:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlateLevel")
    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badge.text:SetTextColor(1, 1, 1)
    badge.isPlate = true
    badge:Hide()
    return badge
end

-- What the badge takes from the plate's level box, read when the plate gets a unit (the game sets
-- the box up again when the nameplate size changes): its width, its frame level (above the health
-- bar's border) and its number's font.
local function matchLevelBox(badge, unitFrame)
    local box = unitFrame.PlayerLevelDiffFrame
    local width = box and box:GetWidth()
    if not (ns.IsUsable(width) and width > PLATE_MIN_WIDTH) then width = PLATE_MIN_WIDTH end
    badge.levelWidth = width
    if not box then return end
    local level = box:GetFrameLevel()
    if ns.IsUsable(level) then badge:SetFrameLevel(level) end
    local text = box.playerLevelDiffText
    local file, height, flags
    if text then file, height, flags = text:GetFont() end
    if ns.IsUsable(file) and ns.IsUsable(height) then badge.text:SetFont(file, height, flags) end
end

local function detachPlate(unit)
    local badge = unitBadges[unit]
    if not badge then return end
    unitBadges[unit] = nil
    badge.unit = nil
    setShown(badge, false)
end

-- A nameplate unit came: its plate's badge (made once per plate) now reads that unit. Minus mobs
-- get none, as the game gives them no numeric threat.
local function attachPlate(unit)
    detachPlate(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    local unitFrame = plate and plate.UnitFrame
    if not (unitFrame and unitFrame.HealthBarsContainer) then return end
    local badge = plateBadges[unitFrame]
    -- A pooled plate that still reads another unit lets it go first.
    if badge and badge.unit then detachPlate(badge.unit) end
    if UnitClassification(unit) == "minus" then return end
    if not badge then
        badge = newPlateBadge(unitFrame)
        plateBadges[unitFrame] = badge
    end
    matchLevelBox(badge, unitFrame)
    badge.number = nil
    badge.unit = unit
    unitBadges[unit] = badge
    update(badge)
end

-- The threat event comes for every unit: only nameplate units have a badge in unitBadges, so one
-- lookup skips the rest.
local function onPlateEvent(event, unit)
    if event == "UNIT_THREAT_LIST_UPDATE" then
        local badge = unitBadges[unit]
        if badge then
            update(badge)
            updateTicker()
        end
        return
    end
    if not (type(unit) == "string" and unit:find("^nameplate")) then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        attachPlate(unit)
    else
        detachPlate(unit)
    end
    updateTicker()
end

local function onFrameEvent(_, unit)
    local badge = frameBadges[unit]
    if badge then update(badge) end
    updateTicker()
end

-- Every one of these may change the tank colors too (a stance or form, the role, entering combat),
-- so they're asked again here, not on every update.
local function onEvent(event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    end
    tankColors = readTank()
    Threat.Refresh()
end

-- The game's numeric threat, hidden on a frame while our badge there is on.
local function applyNumeric()
    for _, info in pairs(FRAMES) do
        local numeric = _G[info.name].TargetFrameContent.TargetFrameContentContextual.NumericalThreat
        ns.Hider:SetHidden(numeric, Options:Get(info.key) == true)
    end
end

local function apply()
    local framesOn = false
    for unit, info in pairs(FRAMES) do
        local on = Options:Get(info.key) == true
        if on and not frameBadges[unit] then frameBadges[unit] = newFrameBadge(unit) end
        local badge = frameBadges[unit]
        if badge then
            badge.unit = on and unit or nil
        end
        framesOn = framesOn or on
    end
    ns.Later("threatNumeric", applyNumeric)

    local platesOn = Options:Get(PLATES) == true
    plateEvents:SetOn(platesOn)
    for unit in pairs(unitBadges) do detachPlate(unit) end
    if platesOn then
        for index = 1, MAX_PLATES do
            local unit = "nameplate" .. index
            if C_NamePlate.GetNamePlateForUnit(unit) then attachPlate(unit) end
        end
    end

    local anyOn = framesOn or platesOn
    events:SetOn(anyOn)
    if framesOn then
        frameListener:On("UNIT_THREAT_LIST_UPDATE", onFrameEvent)
    else
        frameListener:Off("UNIT_THREAT_LIST_UPDATE")
    end
    -- The player's own threat situation, and a pet (UNIT_PET comes for its owner).
    for _, event in ipairs({ "UNIT_THREAT_SITUATION_UPDATE", "UNIT_PET" }) do
        if anyOn then playerListener:On(event, Threat.Refresh) else playerListener:Off(event) end
    end
    tankColors = readTank()
    Threat.Refresh()
end

function Threat:Init()
    if not self.IsAvailable() then return end
    inCombat = InCombatLockdown() == true
    events = ns.Events:NewGroup(EVENTS, onEvent)
    plateEvents = ns.Events:NewGroup(PLATE_EVENTS, onPlateEvent)
    frameListener = ns.Events:NewUnitListener("target", "focus")
    playerListener = ns.Events:NewUnitListener("player")
    Options:Watch(KEYS, apply)
    apply()
end
