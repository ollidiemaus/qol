local _, ns = ...
local Options = ns.Options
local L = ns.L

-- A ring of eight actions with two keys: hold one, aim at an action, let go to use it. The mouse key
-- opens the ring at the cursor and aims with the mouse; the controller key opens it in the middle of
-- the screen and aims with the right stick.
-- Let go in the middle (or with the stick at rest) and nothing happens.
--
-- The eight actions are buttons 1 to 8 of Action Bar 6, 7 or 8 (the player picks the bar), so they
-- are filled by dragging spells onto that bar in Edit Mode, or onto the ring in its editor
-- (/qol ring).
--
-- In combat only secure code may choose what a click does, so the choice is made in the restricted
-- environment: each key clicks a secure action button of ours (QoLRingMouse, QoLRingStick), whose
-- OnClick is wrapped by a secure header (SecureHandlerWrapScript). The key going down shows the
-- header; letting go hides it and turns the click into the aimed slot's button, "s1" to "s8",
-- whose "*type-sN" and "*action-sN" attributes make it that slot's action. Our own code only draws:
-- the ring's art hangs off the header and lights the aimed slot from an OnUpdate, with the same
-- sums as the secure code. Attributes, the header and the override bindings change out of combat.
local Ring = {}
ns.Ring = Ring

local KEY = "ring"
local BAR_KEY = "ringBar"
-- Action Bars 6 to 8 are pages 13 to 15 of the action slots; the ring takes buttons 1 to 8.
local PAGES = { [6] = 13, [7] = 14, [8] = 15 }
local COUNT = 8

local MEDIA = "Interface\\AddOns\\QoL\\Media\\"
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- Sizes in UI units, from the textures (docs/DEVELOPMENT.md says how they were made): Ring.tga
-- covers SIZE with the bronze rim ending 150 units out, RingSelected.tga's lit wedge sits in the
-- middle of a LIT square that goes LIT_RADIUS out from the middle, and the slots sit RADIUS out.
local SIZE = 343
local LIT, LIT_RADIUS = 150, 95
local RADIUS = 96
local ICON = 40
local SLOT_RIM = 58
-- The width of the middle, for the aimed action's name.
local HUB = 72
-- The header is far bigger than the screen: the secure code reads the cursor relative to it, and
-- gets nothing once the cursor leaves it.
local HEADER = 8192
-- How far the cursor must move from the middle, in UI units, and the stick from rest (0 to 1).
local DEADZONE = 20
local STICK = 0.5
-- After the stick ring closes, the camera gets the stick back once it is at rest, or after this
-- many seconds.
local HOLD = 0.5

-- The two keys, in the order of the bindings.
Ring.OPENERS = {
    { name = "QoLRingMouse", aim = "mouse", label = L.RING_MOUSE },
    { name = "QoLRingStick", aim = "stick", label = L.RING_STICK },
}

-- Names in the Key Bindings window, under BackButtons.lua's header.
for _, info in ipairs(Ring.OPENERS) do
    _G["BINDING_NAME_" .. ns.Buttons.Command(info.name)] = info.label
end

function Ring.Slot(bar, index)
    return (PAGES[bar] or PAGES[8]) * 12 - 12 + index
end

-- Slot 1 is at the top, the others follow clockwise; the angle is clockwise from the top.
function Ring.Angle(index)
    return (index - 1) * math.pi / 4
end

function Ring.Offset(index, radius)
    local angle = Ring.Angle(index)
    return radius * math.sin(angle), radius * math.cos(angle)
end

-- The slot in the direction of x, y (right and up), as the secure code below works it out.
function Ring.SlotAt(x, y)
    return math.floor((math.deg(math.atan2(x, y)) % 360 + 22.5) / 45) % COUNT + 1
end

-- The openers' click, in the restricted environment (self: the opener, owner: the header). A key
-- bound in Key Bindings still clicks its opener with the ring turned off; then it does nothing.
Ring.CLICK = ("local SIZE, DEADZONE, STICK = %d, %d, %s\n"):format(HEADER, DEADZONE, STICK) .. [[
    if not owner:GetAttribute("qol-on") then return false end
    local aim = self:GetAttribute("qol-aim")
    if down then
        owner:ClearAllPoints()
        if aim == "mouse" then
            owner:SetPoint("CENTER", "$cursor")
        else
            owner:SetPoint("CENTER", "$parent", "CENTER", 0, 0)
        end
        owner:SetAttribute("qol-aim", aim)
        owner:Show()
        return false
    end
    if not owner:IsShown() or owner:GetAttribute("qol-aim") ~= aim then return false end
    owner:Hide()
    local x, y
    if aim == "mouse" then
        x, y = owner:GetMousePosition()
        if not x then return false end
        x, y = (x - 0.5) * SIZE, (y - 0.5) * SIZE
        if x * x + y * y < DEADZONE * DEADZONE then return false end
    else
        local state = GetGamePadState()
        local stick = state and state.sticks[owner:GetAttribute("qol-stick")]
        if not stick or stick.len < STICK then return false end
        x, y = stick.x, stick.y
    end
    return "s" .. (math.floor((math.deg(math.atan2(x, y)) % 360 + 22.5) / 45) % 8 + 1)
]]

local function isOn()
    return Options:Get(KEY) == true
end

local header, art, catcher, editor
local openers = {}

---------------------------------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------------------------------

-- The ring, for the ring itself and its editor: Forever's radial wheel inside the minimap's bronze
-- ring, eight round slots in the minimap's day and night rim, the lit wedge of the aimed slot and
-- the aimed action's name in the middle.
local function newArt(parent, slotKind)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(SIZE, SIZE)
    frame:SetPoint("CENTER")
    local wheel = frame:CreateTexture(nil, "BACKGROUND")
    wheel:SetAllPoints()
    wheel:SetTexture(MEDIA .. "Ring")
    frame.lit = frame:CreateTexture(nil, "BORDER")
    frame.lit:SetSize(LIT, LIT)
    frame.lit:SetTexture(MEDIA .. "RingSelected")
    frame.lit:Hide()
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.name:SetPoint("CENTER")
    frame.name:SetWidth(HUB)

    frame.slots = {}
    for index = 1, COUNT do
        local slot = CreateFrame(slotKind, nil, frame)
        slot.index = index
        slot:SetSize(ICON, ICON)
        local x, y = Ring.Offset(index, RADIUS)
        slot:SetPoint("CENTER", frame, "CENTER", x, y)
        local empty = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
        empty:SetAllPoints()
        empty:SetTexture(ROUND)
        empty:SetVertexColor(0, 0, 0, 0.6)
        slot.icon = slot:CreateTexture(nil, "BACKGROUND")
        slot.icon:SetAllPoints()
        local mask = slot:CreateMaskTexture()
        mask:SetAllPoints(slot.icon)
        mask:SetAtlas("CircleMask")
        slot.icon:AddMaskTexture(mask)
        slot.icon:Hide()

        local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        cooldown:SetAllPoints(slot.icon)
        cooldown:SetSwipeTexture(ROUND)
        cooldown:SetSwipeColor(0, 0, 0, 0.7)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
        slot.cooldown = cooldown

        local over = CreateFrame("Frame", nil, slot)
        over:SetAllPoints()
        over:SetFrameLevel(cooldown:GetFrameLevel() + 2)
        local rim = over:CreateTexture(nil, "ARTWORK")
        rim:SetSize(SLOT_RIM, SLOT_RIM)
        rim:SetPoint("CENTER")
        rim:SetTexture(MEDIA .. "RingSlot")
        slot.count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        slot.count:SetPoint("BOTTOMRIGHT", 2, -2)
        frame.slots[index] = slot
    end
    return frame
end

-- Lights the wedge of a slot, or none.
local function light(frame, index)
    if not index then
        frame.lit:Hide()
        return
    end
    local x, y = Ring.Offset(index, LIT_RADIUS)
    frame.lit:ClearAllPoints()
    frame.lit:SetPoint("CENTER", frame, "CENTER", x, y)
    -- The wedge is drawn pointing up; SetRotation turns counterclockwise.
    frame.lit:SetRotation(-Ring.Angle(index))
    frame.lit:Show()
end

local function setSlots(frame)
    local bar = Options:Get(BAR_KEY)
    for index, slot in ipairs(frame.slots) do
        slot.slot = Ring.Slot(bar, index)
    end
end

local function refreshArt(frame)
    for _, slot in ipairs(frame.slots) do
        ns.Buttons.RefreshAction(slot, slot.slot)
    end
end

-- The action's name, as the first line of its tooltip has it (it may be secret in combat; it only
-- goes to SetText).
local function actionName(slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetAction) then return nil end
    local data = C_TooltipInfo.GetAction(slot)
    local line = data and data.lines and data.lines[1]
    return line and line.leftText
end

---------------------------------------------------------------------------------------------------
-- Aiming
---------------------------------------------------------------------------------------------------

-- The aiming stick's position and how far it is out, as the secure code reads it.
local function stickPosition()
    local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    local stick = state and state.sticks and state.sticks[header:GetAttribute("qol-stick")]
    if stick then return stick.x, stick.y, stick.len end
end

-- The slot aimed at, as letting go would pick it.
local function aimed(frame)
    local x, y
    if frame.aim == "mouse" then
        local cursorX, cursorY = GetCursorPosition()
        local middleX, middleY = frame:GetCenter()
        if not (cursorX and middleX) then return nil end
        local scale = frame:GetEffectiveScale()
        x, y = cursorX / scale - middleX, cursorY / scale - middleY
        if x * x + y * y < DEADZONE * DEADZONE then return nil end
    else
        local len
        x, y, len = stickPosition()
        if not (x and len >= STICK) then return nil end
    end
    return Ring.SlotAt(x, y)
end

local function track(frame)
    local index = aimed(frame)
    if index == frame.aimed then return end
    frame.aimed = index
    local slot = index and frame.slots[index].slot
    if slot and not C_ActionBar.HasAction(slot) then slot = nil end
    light(frame, slot and index)
    frame.name:SetText(slot and actionName(slot))
end

-- The camera stick aims while the stick ring is open. A frame of ours takes that stick from the
-- game then, and after the ring closes until the stick is at rest, so letting go of the key with
-- the stick still out doesn't swing the camera. The movement stick goes on to the game.
local function releaseStick()
    catcher:EnableGamePadStick(false)
    catcher:Hide()
end

local function newCatcher()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:SetScript("OnGamePadStick", function(_, stick)
        return stick == "Left" or stick == "Movement"
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if header:IsShown() then return end
        self.held = self.held + elapsed
        local _, _, len = stickPosition()
        if not len or len < 0.1 or self.held > HOLD then releaseStick() end
    end)
    return frame
end

local function onOpen(frame)
    frame.aim = header:GetAttribute("qol-aim")
    frame.aimed = nil
    light(frame, nil)
    frame.name:SetText(nil)
    refreshArt(frame)
    if frame.aim == "stick" then
        catcher.held = 0
        catcher:Show()
        catcher:EnableGamePadStick(true)
    end
    track(frame)
end

---------------------------------------------------------------------------------------------------
-- Ring
---------------------------------------------------------------------------------------------------

-- The stick the controller settings give the camera (the right stick), counted from 1 as the
-- secure code's GetGamePadState() counts them.
local function stickIndex()
    local configName = C_GamePad and C_GamePad.StickIndexToConfigName
    if configName then
        for index = 0, 3 do
            if configName(index) == "Camera" then return index + 1 end
        end
    end
    return 2
end

local function create()
    header = CreateFrame("Frame", "QoLRing", UIParent, "SecureHandlerBaseTemplate")
    header:SetSize(HEADER, HEADER)
    header:SetFrameStrata("DIALOG")
    header:Hide()
    art = newArt(header, "Frame")
    art:SetScript("OnShow", onOpen)
    art:SetScript("OnUpdate", track)
    catcher = newCatcher()
    for _, info in ipairs(Ring.OPENERS) do
        local opener = CreateFrame("Button", info.name, UIParent, "SecureActionButtonTemplate")
        opener:SetAttribute("qol-aim", info.aim)
        -- The action happens when the key is let go.
        opener:SetAttribute("useOnKeyDown", false)
        opener:RegisterForClicks("AnyDown", "AnyUp")
        SecureHandlerWrapScript(opener, "OnClick", header, Ring.CLICK)
        openers[#openers + 1] = opener
    end
end

-- The opener each key presses: the keys bound to it in Key Bindings.
function Ring.Overrides()
    local overrides = {}
    for _, info in ipairs(Ring.OPENERS) do
        for _, key in ipairs({ GetBindingKey(ns.Buttons.Command(info.name)) }) do
            overrides[key] = info.name
        end
    end
    return overrides
end

local bindings = ns.Buttons.NewOverrides()

---------------------------------------------------------------------------------------------------
-- Editor (/qol ring)
---------------------------------------------------------------------------------------------------

-- The ring in the middle of the screen, out of combat, for moving actions on and off it: drag one
-- onto a slot, or click a slot with one on the cursor; drag one off, or click it, to take it.
local function onEditorEnter(slot)
    light(editor.art, slot.index)
    GameTooltip:SetOwner(slot, "ANCHOR_RIGHT")
    if C_ActionBar.HasAction(slot.slot) then
        GameTooltip:SetAction(slot.slot)
    else
        GameTooltip:SetText(L.CATEGORY_RING)
        GameTooltip:AddLine(L.SLOT_EMPTY:format(Options:Get(BAR_KEY), slot.index), 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function onEditorLeave(slot)
    light(editor.art, nil)
    if GameTooltip:IsOwned(slot) then GameTooltip:Hide() end
end

local function pickUp(slot)
    if InCombatLockdown() then return end
    PickupAction(slot.slot)
end

local function place(slot)
    if InCombatLockdown() then return end
    PlaceAction(slot.slot)
end

local function onEditorClick(slot)
    if GetCursorInfo() then place(slot) else pickUp(slot) end
end

local function createEditor()
    editor = CreateFrame("Frame", "QoLRingEditor", UIParent)
    editor:SetSize(SIZE, SIZE)
    editor:SetPoint("CENTER")
    editor:SetFrameStrata("DIALOG")
    editor:EnableMouse(true)
    editor:Hide()
    -- Escape closes it.
    table.insert(UISpecialFrames, "QoLRingEditor")
    editor.art = newArt(editor, "Button")
    for _, slot in ipairs(editor.art.slots) do
        slot:RegisterForClicks("LeftButtonUp")
        slot:RegisterForDrag("LeftButton")
        slot:SetScript("OnClick", onEditorClick)
        slot:SetScript("OnDragStart", pickUp)
        slot:SetScript("OnReceiveDrag", place)
        slot:SetScript("OnEnter", onEditorEnter)
        slot:SetScript("OnLeave", onEditorLeave)
    end
    local hint = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOP", editor, "BOTTOM", 0, -4)
    hint:SetWidth(SIZE + 60)
    hint:SetText(L.RING_EDITOR_HINT)
    local close = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -24, -24)
end

function Ring:ToggleEditor()
    if editor and editor:IsShown() then
        editor:Hide()
        return
    end
    if InCombatLockdown() then
        ns.Print(L.RING_EDITOR_COMBAT)
        return
    end
    if not editor then createEditor() end
    setSlots(editor.art)
    refreshArt(editor.art)
    editor:Show()
end

---------------------------------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------------------------------

local function setAttribute(frame, name, value)
    if frame:GetAttribute(name) ~= value then frame:SetAttribute(name, value) end
end

function Ring:Update()
    local on = isOn()
    if on and not header then create() end
    if header then
        setAttribute(header, "qol-on", on)
        if not on and header:IsShown() then header:Hide() end
        local bar = Options:Get(BAR_KEY)
        for _, opener in ipairs(openers) do
            for index = 1, COUNT do
                setAttribute(opener, "*type-s" .. index, on and "action" or nil)
                setAttribute(opener, "*action-s" .. index, Ring.Slot(bar, index))
            end
        end
        setAttribute(header, "qol-stick", stickIndex())
        setSlots(art)
    end
    if editor then
        setSlots(editor.art)
        if editor:IsShown() then refreshArt(editor.art) end
    end
    bindings:Set(on and Ring.Overrides() or {})
end

local function schedule()
    ns.LaterOutsideWindows("ring", function() Ring:Update() end)
end

local function scheduleRefresh()
    if (art and art:IsVisible()) or (editor and editor:IsShown()) then
        ns.Later("ringArt", function()
            if art and art:IsVisible() then refreshArt(art) end
            if editor and editor:IsShown() then refreshArt(editor.art) end
        end, true)
    end
end

function Ring:Init()
    Options:Watch({ KEY, BAR_KEY }, schedule)
    -- The player changed a binding, or another addon its overrides.
    ns.Events:On("UPDATE_BINDINGS", function()
        if isOn() or bindings:Any() then schedule() end
    end)
    -- Actions can't be moved in combat.
    ns.Events:On("PLAYER_REGEN_DISABLED", function()
        if editor then editor:Hide() end
    end)
    for _, event in ipairs(ns.Buttons.REFRESH_EVENTS) do
        ns.Events:On(event, scheduleRefresh)
    end
    if isOn() then schedule() end
end
