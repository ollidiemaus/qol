local _, ns = ...
local Options = ns.Options

-- Reminders, on WoW Forever: an icon in the reminder row for each switched-on preset whose buff the
-- character lacks, gone once the buff is there. The reminder row is a frame of our own on UIParent,
-- not part of the game's Cooldown Manager and not protected, so it shows, hides and lays itself out
-- in combat too, and works with the game's Cooldown Manager switched off. Its icons look like the
-- Cooldown Manager's buff icons (mask and overlay of CooldownViewerBuffIconItemTemplate), lose the
-- overlay with the Cooldown Manager page's border checkbox, and let the mouse through.
-- Having the buff means a buff on the player of the same name; the names come from the client for
-- the presets' spell IDs, so any rank, any food and any locale count. The game may keep buff data
-- secret (Forever does in combat, and reading it then is an error): while C_Secrets says so, or a
-- value read is secret, the whole row hides and nothing read is kept.
-- Updates come from the player's UNIT_AURA, combat starting and ending (the data turns secret and
-- readable again, with no event of its own) and the options, through one ns.Later key: one refresh
-- per frame at most, and nothing at all while no preset is on.
local Reminders = {}
ns.Reminders = Reminders

local SWITCH = "reminders"
local BORDER_KEY = "hideCooldownManagerBorders"
local SIZE, GAP = 40, 4
local MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local OVERLAY_X, OVERLAY_Y = 8, 7 -- how far the overlay reaches past the icon, as on a tracked buff
local MAX_BUFFS = 255

-- The presets, in the list's order. spells: Forever's spell IDs whose names count as the buff (from
-- its Spell table, build 1.60.1.70862); the first one's icon is the reminder's. text: its strings in
-- ns.L (the name, should the client give none, and its tooltip). experience: the buff is about
-- experience.
Reminders.PRESETS = {
    { key = "reminderWellFed", text = "REMINDER_WELL_FED", spells = { 19705, 19706, 19708, 19709, 19710, 19711, 24799, 24870, 25694, 25941,
        1225778, 1225779, 1225780, 1225782, 1248406, 1248420, 1248421, 1248422, 1248688, 1249519, 1249520,
        1249521, 1249523, 1249907, 1249926, 1249927, 1283082, 1294007, 1302064, 1319310 } },
    -- Rested experience accumulates faster.
    { key = "reminderWellRested", text = "REMINDER_WELL_RESTED", spells = { 1225478 }, experience = true },
    -- The camp's bonuses, from the items set up at a camp.
    { key = "reminderCampBenefits", text = "REMINDER_CAMP_BENEFITS", spells = { 1229741 } },
}

local function isForever()
    return WOW_PROJECT_ID ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

function Reminders.IsAvailable()
    return isForever()
end

-- Per preset: the set of its buff's names, kept once the client has given every one.
local names = {}

-- The names its buff goes by, or nil while the client gives none.
local function namesOf(preset)
    local set = names[preset]
    if set then return set end
    set = {}
    local complete, any = true, false
    for _, spellID in ipairs(preset.spells) do
        local name = C_Spell.GetSpellName(spellID)
        if name then
            set[name], any = true, true
        else
            complete = false
        end
    end
    if complete then names[preset] = set end
    return any and set or nil
end

-- The name a preset goes by in the player's language.
function Reminders.NameOf(preset)
    return C_Spell.GetSpellName(preset.spells[1])
end

function Reminders.IconOf(preset)
    return C_Spell.GetSpellTexture(preset.spells[1])
end

-- The player's buff names, refilled by each refresh.
local present = {}

local function clear(set)
    for key in pairs(set) do set[key] = nil end
end

local function withheld()
    return C_Secrets ~= nil and C_Secrets.ShouldAurasBeSecret ~= nil and C_Secrets.ShouldAurasBeSecret() == true
end

-- Fills present; false when the game keeps any of it secret.
local function readBuffs()
    clear(present)
    if withheld() then return false end
    for index = 1, MAX_BUFFS do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
        -- nil: the end of the list.
        if not ns.IsUsable(aura) then return aura == nil end
        local name = aura.name
        if not ns.IsUsable(name) then return false end
        present[name] = true
    end
    return true
end

local function hasAny(set)
    for name in pairs(set) do
        if present[name] then return true end
    end
    return false
end

local row
local icons = {}

local function newIcon()
    local icon = CreateFrame("Frame", nil, row)
    icon:SetSize(SIZE, SIZE)
    icon:EnableMouse(false)
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints(icon)
    local mask = icon:CreateMaskTexture()
    mask:SetAtlas(MASK_ATLAS)
    mask:SetAllPoints(icon)
    icon.Icon:AddMaskTexture(mask)
    icon.Overlay = icon:CreateTexture(nil, "OVERLAY")
    icon.Overlay:SetAtlas(OVERLAY_ATLAS)
    icon.Overlay:SetPoint("TOPLEFT", icon, "TOPLEFT", -OVERLAY_X, OVERLAY_Y)
    icon.Overlay:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", OVERLAY_X, -OVERLAY_Y)
    return icon
end

-- The row covers the screen's lower half and lets the mouse through; its icons sit in its middle.
local function newRow()
    row = CreateFrame("Frame", nil, UIParent)
    row:SetPoint("TOPLEFT", UIParent, "LEFT")
    row:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
    row:EnableMouse(false)
    Reminders.row = row
end

-- Shows the reminders that are due, centred, in the presets' order.
local function refresh()
    local count = 0
    if Options:Get(SWITCH) then
        local read = false
        for _, preset in ipairs(Reminders.PRESETS) do
            local set = Options:Get(preset.key) and namesOf(preset)
            if set then
                if not read then
                    if not readBuffs() then
                        count = 0
                        break
                    end
                    read = true
                end
                if not hasAny(set) then
                    count = count + 1
                    if not row then newRow() end
                    local icon = icons[count] or newIcon()
                    icons[count] = icon
                    icon.Icon:SetTexture(Reminders.IconOf(preset))
                    icon:Show()
                end
            end
        end
        clear(present)
    end
    if not row then return end
    local hideOverlay = Options:Get(BORDER_KEY) == true
    local left = -((count * SIZE) + (count - 1) * GAP) / 2 + SIZE / 2
    for index, icon in ipairs(icons) do
        if index <= count then
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", row, "CENTER", left + (index - 1) * (SIZE + GAP), 0)
            icon.Overlay:SetShown(not hideOverlay)
        else
            icon:Hide()
        end
    end
    row:SetShown(count > 0)
end

local function schedule()
    ns.Later("reminders", refresh, true)
end

local function active()
    if not Options:Get(SWITCH) then return false end
    for _, preset in ipairs(Reminders.PRESETS) do
        if Options:Get(preset.key) then return true end
    end
    return false
end

local unitEvents
local events = ns.Events:NewGroup({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" },
    schedule)

-- Hears the events only while a reminder can show, then refreshes.
local function update()
    local on = active()
    events:SetOn(on)
    if on then unitEvents:On("UNIT_AURA", schedule) else unitEvents:Off("UNIT_AURA") end
    schedule()
end

function Reminders:Init()
    if not isForever() then return end
    unitEvents = ns.Events:NewUnitListener("player")
    local keys = { SWITCH, BORDER_KEY }
    for _, preset in ipairs(Reminders.PRESETS) do keys[#keys + 1] = preset.key end
    Options:Watch(keys, update)
    update()
end
