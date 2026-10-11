local _, ns = ...
local Options = ns.Options
local Entries = ns.RingEntries

-- Rings of actions, as many as the player makes in the editor (/qol ring, RingEditor.lua), each
-- with two keys: hold one, aim at an action, let go to use it. The mouse key opens the ring at the
-- cursor and aims with the mouse; the stick key opens it in the middle of the screen and aims with
-- a controller's right stick. Let go in the middle (or with the stick at rest) and nothing happens.
--
-- The rings are saved for the whole account (QoLDB.rings), each as { entries = { entry, ... },
-- mouse = key, stick = key }, entries as RingEntries.lua describes them. A character's ring shows
-- the entries it can use, at most MAX, and grows with them: the slots go round evenly, with the
-- wheel's spokes between them and the aimed slot's wedge drawn for that many slots. A ring with
-- nothing this character can use leaves its keys to the game.
--
-- In combat only secure code may choose what a click does, so the choice is made in the restricted
-- environment. Each key is an override binding that clicks our secure action button
-- (QoLRingButton) with a mouse button named after the ring and the aim: "2mouse" or "2stick". Its
-- OnClick is wrapped by a secure header (SecureHandlerWrapScript): the key going down shows the
-- header; letting go hides it and turns the click into the aimed slot's button, "2s3" for ring 2's
-- third slot, whose "*type-2s3" and "*spell-2s3" (or item, toy, macro) attributes make it that
-- entry's action. Our own code only draws: the ring's art hangs off the header and lights the
-- aimed slot from an OnUpdate, with the same sums as the secure code. Attributes, the header and
-- the override bindings change out of combat, so in combat a ring keeps the slots it had.
local Ring = {}
ns.Ring = Ring

local KEY = "ring"
-- A ring shows at most this many actions: the wedges are drawn up to there.
Ring.MAX = 12
-- A ring's keys, by how they aim.
Ring.AIMS = { "mouse", "stick" }

local OPENER = "QoLRingButton"
local MEDIA = "Interface\\AddOns\\QoL\\Media\\"
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- Sizes in UI units, from the textures (docs/DEVELOPMENT.md says how they were made): Ring.tga
-- covers SIZE with the bronze rim ending RIM units out, and the slots sit RADIUS out.
-- RingSpoke.tga is a SPOKE square with one spoke pointing up, its middle SPOKE_RADIUS out.
-- RingLit<n>.tga is the lit wedge of a slot of n: a square of LIT[n][2] units whose middle sits
-- LIT[n][1] out (for one slot, the whole wheel).
local SIZE = 343
Ring.RIM = 150
local RADIUS = 96
local SPOKE, SPOKE_RADIUS = 100, 93.5
local LIT = {
    { 0.0, 300.6 }, { 74.3, 300.6 }, { 85.4, 259.9 }, { 90.0, 212.3 }, { 92.3, 176.7 }, { 93.6, 150.5 },
    { 94.3, 130.8 }, { 94.8, 115.6 }, { 95.2, 110.3 }, { 95.4, 109.8 }, { 95.6, 109.4 }, { 95.7, 109.2 },
}
local ICON = 40
local SLOT_RIM = 58
-- The width of the middle, for the aimed action's name.
local HUB = 72
-- Up to this many slots the ring keeps its size; with more it grows, so their rims don't overlap.
local ROOMY = 10
-- The header is far bigger than the screen: the secure code reads the cursor relative to it, and
-- gets nothing once the cursor leaves it.
local HEADER = 8192
-- How far the cursor must move from the middle, in UI units, and the stick from rest (0 to 1).
local DEADZONE = 20
local STICK = 0.5
-- After the stick ring closes, the camera gets the stick back once it is at rest, or after this
-- many seconds.
local HOLD = 0.5

-- Slot 1 is at the top, the others follow clockwise, count of them evenly; the angle is clockwise
-- from the top, in radians.
function Ring.Angle(index, count)
    return (index - 1) * 2 * math.pi / count
end

-- Right and up of the middle, radius out at angle.
local function at(angle, radius)
    return radius * math.sin(angle), radius * math.cos(angle)
end

function Ring.Offset(index, count, radius)
    return at(Ring.Angle(index, count), radius)
end

-- The slot of count in the direction of x, y (right and up), as the secure code below works it out.
function Ring.SlotAt(x, y, count)
    local step = 360 / count
    return math.floor((math.deg(math.atan2(x, y)) % 360 + step / 2) / step) % count + 1
end

-- How much bigger than the textures a ring of count slots is drawn.
function Ring.Scale(count)
    return math.max(1, count / ROOMY)
end

-- The opener's click, in the restricted environment (self: the opener, owner: the header). button:
-- the ring and the aim, "2mouse". A ring is open while its key is down; letting go picks the slot.
Ring.CLICK = ("local SIZE, DEADZONE, STICK = %d, %d, %s\n"):format(HEADER, DEADZONE, STICK) .. [[
    if not owner:GetAttribute("qol-on") then return false end
    local ring, aim = strmatch(button or "", "^(%d+)(%a+)$")
    local count = ring and owner:GetAttribute("qol-count-" .. ring)
    if not count then return false end
    if down then
        owner:ClearAllPoints()
        if aim == "mouse" then
            owner:SetPoint("CENTER", "$cursor")
        else
            owner:SetPoint("CENTER", "$parent", "CENTER", 0, 0)
        end
        owner:SetAttribute("qol-open", button)
        owner:Show()
        return false
    end
    if not owner:IsShown() or owner:GetAttribute("qol-open") ~= button then return false end
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
    local step = 360 / count
    return ring .. "s" .. (math.floor((math.deg(math.atan2(x, y)) % 360 + step / 2) / step) % count + 1)
]]

local function isOn()
    return Options:Get(KEY) == true
end

---------------------------------------------------------------------------------------------------
-- Rings
---------------------------------------------------------------------------------------------------

-- The saved rings.
function Ring.List()
    local db = ns.db
    if type(db.rings) ~= "table" then db.rings = {} end
    return db.rings
end

function Ring.New()
    return { entries = {} }
end

-- Drops what isn't a ring from a hand-edited or damaged file.
local function clean()
    local rings = Ring.List()
    for index = #rings, 1, -1 do
        local ring = rings[index]
        if type(ring) ~= "table" then
            table.remove(rings, index)
        elseif type(ring.entries) ~= "table" then
            ring.entries = {}
        end
    end
end

-- Where the entries this character can use are in the ring's list, the first MAX of them.
function Ring.Shown(ring)
    local shown = {}
    for index, entry in ipairs(ring.entries) do
        if #shown == Ring.MAX then break end
        if Entries.Known(entry) then shown[#shown + 1] = index end
    end
    return shown
end

---------------------------------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------------------------------

local function newSlot(frame, slotKind, index)
    local slot = CreateFrame(slotKind, nil, frame)
    slot.index = index
    slot:SetSize(ICON, ICON)
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
    slot.over = over
    return slot
end

-- A ring, for the ring itself and its editor: Forever's radial wheel inside the minimap's bronze
-- ring, round slots in the minimap's day and night rim with spokes between them, the aimed slot's
-- lit wedge and the aimed action's name in the middle. Every slot is made here, so opening a ring
-- in combat makes no frames; Ring.Layout spreads them out for a number of slots.
function Ring.NewArt(parent, slotKind)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(SIZE, SIZE)
    frame:SetPoint("CENTER")
    local wheel = frame:CreateTexture(nil, "BACKGROUND")
    wheel:SetAllPoints()
    wheel:SetTexture(MEDIA .. "Ring")
    frame.lit = frame:CreateTexture(nil, "BORDER")
    frame.lit:Hide()
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.name:SetPoint("CENTER")
    frame.name:SetWidth(HUB)
    frame.slots, frame.spokes, frame.entries, frame.count = {}, {}, {}, 0
    for index = 1, Ring.MAX do
        frame.slots[index] = newSlot(frame, slotKind, index)
        local spoke = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        spoke:SetSize(SPOKE, SPOKE)
        spoke:SetTexture(MEDIA .. "RingSpoke")
        frame.spokes[index] = spoke
    end
    return frame
end

-- Lights the wedge of a slot, or none.
function Ring.Light(frame, index)
    local count = frame.count
    if not (index and LIT[count]) then
        frame.lit:Hide()
        return
    end
    local middle, side = LIT[count][1], LIT[count][2]
    local angle = Ring.Angle(index, count)
    frame.lit:SetTexture(MEDIA .. "RingLit" .. count)
    frame.lit:SetSize(side, side)
    frame.lit:ClearAllPoints()
    frame.lit:SetPoint("CENTER", frame, "CENTER", at(angle, middle))
    -- The textures are drawn pointing up; SetRotation turns counterclockwise.
    frame.lit:SetRotation(-angle)
    frame.lit:Show()
end

-- Spreads the art out for count slots (1 to MAX), with a spoke between each two.
function Ring.Layout(frame, count)
    frame.count = count
    frame:SetScale(Ring.Scale(count))
    for index, slot in ipairs(frame.slots) do
        slot:ClearAllPoints()
        if index <= count then
            slot:SetPoint("CENTER", frame, "CENTER", Ring.Offset(index, count, RADIUS))
        end
        slot:SetShown(index <= count)
    end
    for index, spoke in ipairs(frame.spokes) do
        local shown = count > 1 and index <= count
        if shown then
            local angle = (index - 0.5) * 2 * math.pi / count
            spoke:ClearAllPoints()
            spoke:SetPoint("CENTER", frame, "CENTER", at(angle, SPOKE_RADIUS))
            spoke:SetRotation(-angle)
        end
        spoke:SetShown(shown)
    end
    Ring.Light(frame, nil)
end

-- Draws frame.entries on the slots in use (a slot without an entry is empty).
function Ring.Refresh(frame)
    for index = 1, frame.count do
        Entries.Refresh(frame.slots[index], frame.entries[index])
    end
end

---------------------------------------------------------------------------------------------------
-- Aiming
---------------------------------------------------------------------------------------------------

local header, art, catcher, opener
-- What each ring shows, as the last update gave it to the secure code: [ring] = { entry, ... }.
local shown = {}

-- The aiming stick's position and how far it is out, as the secure code reads it.
local function stickPosition()
    local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState()
    local stick = state and state.sticks and state.sticks[header:GetAttribute("qol-stick")]
    if stick then return stick.x, stick.y, stick.len end
end

-- The slot aimed at, as letting go would pick it.
local function aimed(frame)
    if frame.count < 1 then return nil end
    local x, y
    if frame.aim == "mouse" then
        local cursorX, cursorY = GetCursorPosition()
        local middleX, middleY = header:GetCenter()
        if not (cursorX and middleX) then return nil end
        local scale = header:GetEffectiveScale()
        x, y = cursorX / scale - middleX, cursorY / scale - middleY
        if x * x + y * y < DEADZONE * DEADZONE then return nil end
    else
        local len
        x, y, len = stickPosition()
        if not (x and len >= STICK) then return nil end
    end
    return Ring.SlotAt(x, y, frame.count)
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

local onOpen

local function track(frame)
    -- Another ring's key went down while this one was open.
    if header:GetAttribute("qol-open") ~= frame.open then
        onOpen(frame)
        return
    end
    local index = aimed(frame)
    if index == frame.aimed then return end
    frame.aimed = index
    Ring.Light(frame, index)
    frame.name:SetText(index and Entries.Name(frame.entries[index]))
end

function onOpen(frame)
    frame.open = header:GetAttribute("qol-open")
    local ring, aim = tostring(frame.open):match("^(%d+)(%a+)$")
    frame.aim = aim
    frame.entries = ring and shown[tonumber(ring)] or {}
    Ring.Layout(frame, #frame.entries)
    Ring.Refresh(frame)
    frame.aimed = nil
    frame.name:SetText(nil)
    if aim == "stick" then
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
    art = Ring.NewArt(header, "Frame")
    art:SetScript("OnShow", onOpen)
    art:SetScript("OnUpdate", track)
    catcher = newCatcher()
    opener = CreateFrame("Button", OPENER, UIParent, "SecureActionButtonTemplate")
    -- The action happens when the key is let go.
    opener:SetAttribute("useOnKeyDown", false)
    opener:RegisterForClicks("AnyDown", "AnyUp")
    SecureHandlerWrapScript(opener, "OnClick", header, Ring.CLICK)
end

-- The keys of the rings this character has something on: { [key] = "QoLRingButton:2mouse" }.
function Ring.Overrides()
    local overrides = {}
    for index, ring in ipairs(Ring.List()) do
        if shown[index] and #shown[index] > 0 then
            for _, aim in ipairs(Ring.AIMS) do
                local key = ring[aim]
                if type(key) == "string" then overrides[key] = OPENER .. ":" .. index .. aim end
            end
        end
    end
    return overrides
end

local bindings = ns.Buttons.NewOverrides()

---------------------------------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------------------------------

local function setAttribute(frame, name, value)
    if frame:GetAttribute(name) ~= value then frame:SetAttribute(name, value) end
end

-- [frame] = the attributes apply set on it last time.
local applied = {}

-- Sets the attributes in wanted on frame and clears those it set before that aren't in it.
local function apply(frame, wanted)
    for name in pairs(applied[frame] or {}) do
        if wanted[name] == nil then frame:SetAttribute(name, nil) end
    end
    for name, value in pairs(wanted) do
        setAttribute(frame, name, value)
    end
    applied[frame] = wanted
end

function Ring:Update()
    local on = isOn()
    if on and not header then create() end
    shown = {}
    if header then
        local counts, actions = {}, {}
        for index, ring in ipairs(on and Ring.List() or {}) do
            local list = {}
            for _, entryIndex in ipairs(Ring.Shown(ring)) do
                list[#list + 1] = ring.entries[entryIndex]
            end
            shown[index] = list
            if #list > 0 then counts["qol-count-" .. index] = #list end
            for slot, entry in ipairs(list) do
                local suffix = "-" .. index .. "s" .. slot
                local actionType, value = Entries.Action(entry)
                actions["*type" .. suffix] = actionType
                actions["*" .. actionType .. suffix] = value
            end
        end
        setAttribute(header, "qol-on", on)
        setAttribute(header, "qol-stick", stickIndex())
        apply(header, counts)
        apply(opener, actions)
        if not on and header:IsShown() then header:Hide() end
        -- Open while it changed: show it as the secure code has it now.
        if art:IsVisible() then onOpen(art) end
    end
    bindings:Set(on and Ring.Overrides() or {})
end

local function schedule()
    ns.LaterOutsideWindows("ring", function() Ring:Update() end)
end

-- The rings changed (the editor).
function Ring.Changed()
    schedule()
end

local function scheduleRefresh()
    if art and art:IsVisible() then
        ns.Later("ringArt", function()
            if art:IsVisible() then Ring.Refresh(art) end
        end, true)
    end
end

-- What changes the entries a character can use: spells learned, items gained or used up, toys,
-- mounts and macros made or renamed.
Ring.KNOWN_EVENTS = {
    "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_MACROS", "NEW_TOY_ADDED",
    "TOYS_UPDATED", "NEW_MOUNT_ADDED", "COMPANION_LEARNED",
}

-- What changes an entry's look: the action buttons' events, and item cooldowns.
Ring.REFRESH_EVENTS = { "BAG_UPDATE_COOLDOWN" }
for _, event in ipairs(ns.Buttons.REFRESH_EVENTS) do
    Ring.REFRESH_EVENTS[#Ring.REFRESH_EVENTS + 1] = event
end

function Ring:Init()
    clean()
    Options:Watch({ KEY }, schedule)
    for _, event in ipairs(Ring.KNOWN_EVENTS) do
        ns.Events:On(event, function()
            if isOn() then schedule() end
        end)
    end
    for _, event in ipairs(Ring.REFRESH_EVENTS) do
        ns.Events:On(event, scheduleRefresh)
    end
    if isOn() then schedule() end
end
