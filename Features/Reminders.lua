local _, ns = ...
local Options = ns.Options

-- Reminders, on WoW Forever: an icon in the reminder row for each switched-on reminder whose buff
-- the character lacks, gone once the buff is there: the presets first, then the player's own, spells
-- dragged from the spellbook onto the settings page, in the order added (QoLDB.reminders, for the
-- whole account; one applies only on a character that knows the spell, at any rank). The reminder row is a frame of our own on UIParent,
-- not part of the game's Cooldown Manager and not protected, so it shows, hides and lays itself out
-- in combat too, and works with the game's Cooldown Manager switched off. Its icons look like the
-- Cooldown Manager's buff icons (mask and overlay of CooldownViewerBuffIconItemTemplate), lose the
-- overlay with the Cooldown Manager page's border checkbox, and let the mouse through.
-- Having the buff means a buff on the player of the same name, or of its group version's; the names
-- come from the client for the spell IDs we have, so any rank, any caster, any food and any locale
-- count. The game may keep buff data
-- secret (Forever does in combat, and reading it then is an error): while C_Secrets says so, or a
-- value read is secret, the whole row hides and nothing read is kept.
-- Updates come from the player's UNIT_AURA, combat starting and ending (the data turns secret and
-- readable again, with no event of its own), spells learned, the options and the player's list,
-- through one ns.Later key: one refresh per frame at most, and nothing at all while no reminder is on.
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

-- Group versions: a single-target spell (any of its ranks) and the group spells whose buff counts
-- for it too, in Forever's Spell table. Applied to any reminder. Forever has Greater Blessings of
-- Might, Wisdom and Kings only.
local GROUP_VERSIONS = {
    [1126] = { 21849 },  -- Mark of the Wild: Gift of the Wild
    [1459] = { 23028 },  -- Arcane Intellect: Arcane Brilliance
    [1243] = { 21562 },  -- Power Word: Fortitude: Prayer of Fortitude
    [14752] = { 27681 }, -- Divine Spirit: Prayer of Spirit
    [976] = { 27683 },   -- Shadow Protection: Prayer of Shadow Protection
    [19740] = { 25782 }, -- Blessing of Might: Greater Blessing of Might
    [19742] = { 25894 }, -- Blessing of Wisdom: Greater Blessing of Wisdom
    [20217] = { 25898 }, -- Blessing of Kings: Greater Blessing of Kings
}

local function isForever()
    return WOW_PROJECT_ID ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

function Reminders.IsAvailable()
    return isForever()
end

-- A spell's name from the client, or nil.
local function nameOf(spellID)
    local name = C_Spell.GetSpellName(spellID)
    if ns.IsUsable(name) then return name end
    return nil
end

-- A spell's name -> the names of its group versions, kept once the client has given every one.
local groupNames

local function groupVersions()
    if groupNames then return groupNames end
    local map, complete = {}, true
    for single, groups in pairs(GROUP_VERSIONS) do
        local name = nameOf(single)
        for _, group in ipairs(groups) do
            local groupName = nameOf(group)
            if name and groupName then
                map[name] = map[name] or {}
                map[name][#map[name] + 1] = groupName
            else
                complete = false
            end
        end
    end
    if complete then groupNames = map end
    return map
end

-- Per reminder: the set of its buff's names, its group versions' among them, kept once the client
-- has given every one.
local names = {}

-- The names its buff goes by, or nil while the client gives none.
local function namesOf(reminder)
    local set = names[reminder]
    if set then return set end
    set = {}
    local groups = groupVersions()
    local complete, any = groupNames ~= nil, false
    for _, spellID in ipairs(reminder.spells) do
        local name = nameOf(spellID)
        if name then
            set[name], any = true, true
            for _, groupName in ipairs(groups[name] or {}) do set[groupName] = true end
        else
            complete = false
        end
    end
    if complete then names[reminder] = set end
    return any and set or nil
end

-- The player's own reminders: QoLDB.reminders, { spell = the spell ID as dragged, on = boolean } each,
-- in the order added. An entry QoL doesn't understand (a newer QoL's) stays where it is, left out of
-- everything else (see valid).
local function ownList()
    local db = ns.db
    if type(db.reminders) ~= "table" then db.reminders = {} end
    return db.reminders
end

local function valid(entry)
    return type(entry) == "table" and type(entry.spell) == "number"
end

-- An own reminder as a preset is one ({ spells }), made once per spell.
local ownReminders = {}

local function ownReminder(spellID)
    local reminder = ownReminders[spellID]
    if not reminder then
        reminder = { spells = { spellID } }
        ownReminders[spellID] = reminder
    end
    return reminder
end

-- Whether the character knows the spell at any rank: the client's answer for the spell's name is the
-- rank it knows, taken only if it knows that spell, as the name can be an NPC's too. The answers are
-- kept until SPELLS_CHANGED, so a refresh on UNIT_AURA asks the client nothing.
local known = {}

local function knows(spellID)
    local answer = known[spellID]
    if answer ~= nil then return answer end
    local book = C_SpellBook
    answer = book.IsSpellKnownOrInSpellBook(spellID) == true
    local name, lookup = nameOf(spellID), C_Spell.GetSpellIDForSpellIdentifier
    if not answer and name and lookup then
        local found = lookup(name)
        answer = ns.IsUsable(found) and book.IsSpellKnownOrInSpellBook(found) == true
    end
    known[spellID] = answer
    return answer
end

-- An own reminder that can show on this character: understood, switched on, its spell known.
local function applies(entry)
    return valid(entry) and entry.on == true and knows(entry.spell)
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

-- The reminders that apply, switched on, in the list's order: the presets', then the player's own
-- for spells the character knows. Refilled by each refresh.
local dueList = {}

local function due()
    for index = #dueList, 1, -1 do dueList[index] = nil end
    for _, preset in ipairs(Reminders.PRESETS) do
        if Options:Get(preset.key) then dueList[#dueList + 1] = preset end
    end
    for _, entry in ipairs(ownList()) do
        if applies(entry) then dueList[#dueList + 1] = ownReminder(entry.spell) end
    end
    return dueList
end

-- Shows the reminders whose buff is missing, centred, in the list's order.
local function refresh()
    local count = 0
    local reminders = Options:Get(SWITCH) and due() or {}
    if #reminders > 0 and readBuffs() then
        for _, reminder in ipairs(reminders) do
            local set = namesOf(reminder)
            if set and not hasAny(set) then
                count = count + 1
                if not row then newRow() end
                local icon = icons[count] or newIcon()
                icons[count] = icon
                icon.Icon:SetTexture(Reminders.IconOf(reminder))
                icon:Show()
            end
        end
    end
    clear(present)
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
    for _, entry in ipairs(ownList()) do
        if applies(entry) then return true end
    end
    return false
end

-- Who hears of changes to the player's list, or to which spells the character knows (the page).
local listeners = {}

function Reminders.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function changed()
    for _, fn in ipairs(listeners) do fn() end
end

local unitEvents
local events = ns.Events:NewGroup({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" },
    schedule)
local update

-- Learning a spell (or a respec) changes which of the player's own reminders apply, and so whether
-- any can show.
local spellEvents = ns.Events:NewGroup({ "SPELLS_CHANGED" }, function()
    clear(known)
    update()
    changed()
end)

-- Hears the events only while a reminder can show (SPELLS_CHANGED while the player has reminders of
-- their own), then refreshes.
function update()
    local on = active()
    events:SetOn(on)
    spellEvents:SetOn(#ownList() > 0)
    if on then unitEvents:On("UNIT_AURA", schedule) else unitEvents:Off("UNIT_AURA") end
    schedule()
end

-- The player's own reminders QoL understands, in the list's order, as the page shows them:
-- { index (its place in the saved list, for SetOn and Remove), name, icon, on, known }.
function Reminders.Own()
    local lines = {}
    for index, entry in ipairs(ownList()) do
        if valid(entry) then
            lines[#lines + 1] = { index = index, name = nameOf(entry.spell),
                icon = C_Spell.GetSpellTexture(entry.spell), on = entry.on == true, known = knows(entry.spell) }
        end
    end
    return lines
end

-- After the player's list changed: what the row hears and shows, and the page.
local function afterEdit()
    update()
    changed()
end

-- Adds the spell on the cursor, unless it's in the list already at some rank; anything else stays on
-- the cursor. Whether it was added.
function Reminders.AddFromCursor()
    local cursorType, _, _, spellID, baseSpellID = GetCursorInfo()
    local id = cursorType == "spell" and (baseSpellID or spellID)
    if type(id) ~= "number" then return false end
    local name, list = nameOf(id), ownList()
    for _, entry in ipairs(list) do
        if valid(entry) and (entry.spell == id or (name and nameOf(entry.spell) == name)) then return false end
    end
    list[#list + 1] = { spell = id, on = true }
    ClearCursor()
    afterEdit()
    return true
end

-- index: the reminder's place in the saved list (Own's index).
function Reminders.Remove(index)
    local list = ownList()
    if not valid(list[index]) then return end
    table.remove(list, index)
    afterEdit()
end

function Reminders.SetOn(index, on)
    local entry = ownList()[index]
    if not valid(entry) then return end
    entry.on = on == true
    afterEdit()
end

function Reminders:Init()
    if not isForever() then return end
    unitEvents = ns.Events:NewUnitListener("player")
    local keys = { SWITCH, BORDER_KEY }
    for _, preset in ipairs(Reminders.PRESETS) do keys[#keys + 1] = preset.key end
    Options:Watch(keys, update)
    update()
end
