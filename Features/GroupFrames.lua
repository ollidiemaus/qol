local _, ns = ...
local Options = ns.Options

-- The game's group frames (raid-style party and raid frames), WoW Forever only: the Group Frames
-- page's game setting (whether the game shows its own buff icons on them), and tracked buffs: icons
-- on every group frame for spells the player dragged from the spellbook onto the page
-- (QoLDB.trackedBuffs, for the whole account, in the order added; a line applies only on a character
-- that knows the spell at some rank). ADR 0004 and ADR 0005 say why they're drawn as they are.
-- A "has it" icon is an aura slot on the game's aura container (CustomAuraContainerTemplate), one
-- container per frame with the frame's member as its unit: the game shows the slot's button, in and
-- out of combat, while a buff of the player's own (HELPFUL|PLAYER) with the spell ID of one of the
-- ranks the character knows is on the member, and fills the icon, cooldown sweep and stack count we
-- handed it. QoL never reads a buff for a "has it" line.
-- A "lacks it" icon is QoL's own, desaturated, and shows out of combat only, while the member has no
-- buff of that name from anyone, nor of its group version's or a rival's (ns.CountingNames, shared
-- with the reminders), and never on a dead or offline member (an out-of-range one's frame fades, icons with it).
-- Places: every line that is on and known has a fixed place on its spot (one of nine), in the list's
-- order towards the frame's middle, whether its icon shows or not, at one size for all
-- (groupFrameBuffSize); the game's countdown numbers show on "has it" icons while
-- groupFrameBuffCountdown is on, at groupFrameBuffCountdownSize.
-- The raid manager is hidden by Features/HideFrames.lua (hideRaidManager).
--
-- Taint: the group frames are found the way click casting finds raid-style frames (a hook on the
-- global CompactUnitFrame_SetUpFrame that only notes the frame). Each gets a holder frame of ours,
-- its child, laid over it, and the aura container is the holder's child; nothing is written on,
-- hooked on or called on a game frame but reads (its unit field, GetFrameLevel). Nothing of ours is
-- protected or takes the mouse, so clicks and click casting reach the frame; they're made, shown and
-- moved in combat too. The unit is read from the frame on every refresh, as the game hands frames
-- to other members. The game denies tainted code access to a slot's button and what was handed to
-- it while buff data is secret, so a button is set up in the container's initializeFrame and is
-- moved or restyled only while the data is readable; a slot that should move meanwhile is disabled
-- until it can be.
-- Secrecy ("lacks it" only): every value read from buff data goes through ns.IsUsable first; a
-- secret name hides the frame's "lacks it" icons, and while C_Secrets says buff data is secret they
-- all hide and nothing is read.
-- Cost: the master switch off, nothing is heard but the setup hook (which only notes frames); on,
-- GROUP_ROSTER_UPDATE tells when the character is in a group; only then are spells learned, the
-- secrecy and combat events heard, and, while a "lacks it" line is on and out of combat, the
-- members' UNIT_AURA, death (UNIT_HEALTH, redrawn only when it changes) and connection
-- (through unit listeners). Refreshes go through one ns.Later key, at most once per drawn frame, and a
-- UNIT_AURA redraws only that unit's frames, and only when it can change which buffs the unit has
-- (ns.BuffsMayHaveChanged: not for a refreshed duration or a debuff). A buff change costs QoL nothing for "has it" icons.
local GroupFrames = {}
ns.GroupFrames = GroupFrames

-- The game's "Display buffs" raid-frame setting (Blizzard_CompactUnitFrameProfiles turns it into the
-- frames' displayBuffs option whenever it changes). The game keeps it: QoL saves no copy and writes
-- it only when the player clicks its checkbox, never on its own.
GroupFrames.GAME_BUFFS_CVAR = "raidFramesDisplayBuffs"

local SWITCH, SIZE, COUNTDOWN = "groupFrameBuffs", "groupFrameBuffSize", "groupFrameBuffCountdown"
local COUNTDOWN_SIZE = "groupFrameBuffCountdownSize"
-- The countdown numbers' font when the game's countdown font string has none to keep.
local COUNTDOWN_FONT, COUNTDOWN_FLAGS = "Fonts\\FRIZQT__.TTF", "OUTLINE"
-- The pixels between two icons on a spot, and between an icon and the frame's edge.
local GAP, INSET = 1, 2
-- The nine spots a line's Position picks, in the page's order, each the anchor point it puts the icons
-- at on the frame. A line without one, or with one this QoL doesn't know, goes at the default.
GroupFrames.SPOTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM",
    "BOTTOMRIGHT" }
GroupFrames.DEFAULT_SPOT = "TOPRIGHT"
-- Per spot, which way the places on it line up across the frame (across: 1 rightwards from the left
-- edge, -1 leftwards from the right edge, 0 a row centred on the spot) and which way they're moved in
-- from the top or bottom edge (inward: -1 down, 1 up, 0 not at all).
local LAYOUT = {
    TOPLEFT = { across = 1, inward = -1 }, TOP = { across = 0, inward = -1 }, TOPRIGHT = { across = -1, inward = -1 },
    LEFT = { across = 1, inward = 0 }, CENTER = { across = 0, inward = 0 }, RIGHT = { across = -1, inward = 0 },
    BOTTOMLEFT = { across = 1, inward = 1 }, BOTTOM = { across = 0, inward = 1 },
    BOTTOMRIGHT = { across = -1, inward = 1 },
}
local LEVEL_ABOVE = 5 -- the holder's frame level over the group frame's, above its bars
local MAX_BUFFS = 255
local OWN, ANY = "HELPFUL|PLAYER", "HELPFUL" -- buffs the player cast; anyone's
-- The kinds of tracked buff this QoL understands: "has" shows while the player's own cast is on the
-- member, "lacks" while the member has no buff of the name (any caster, its group version and rivals
-- too).
local KINDS = { has = true, lacks = true }
local PARTY, RAID = 4, 40

-- Whether the client is WoW Forever, the only one the Group Frames page is for.
function GroupFrames.IsAvailable()
    return ns.IsForever()
end

-- A spell's name from the client, or nil.
local function nameOf(spellID)
    local name = C_Spell.GetSpellName(spellID)
    if ns.IsUsable(name) then return name end
    return nil
end

-- The tracked buffs: QoLDB.trackedBuffs, { spell = the spell ID as dragged, kind = "has", on } each,
-- in the order added. An entry QoL doesn't understand (a newer QoL's) stays where it is, left out of
-- everything else (see valid).
local function list()
    local db = ns.db
    if type(db.trackedBuffs) ~= "table" then db.trackedBuffs = {} end
    return db.trackedBuffs
end

local function valid(entry)
    return type(entry) == "table" and type(entry.spell) == "number" and KINDS[entry.kind] == true
end

local function spotOf(entry)
    if LAYOUT[entry.spot] then return entry.spot end
    return GroupFrames.DEFAULT_SPOT
end

local function clear(set)
    for key in pairs(set) do set[key] = nil end
end

-- Whether the character knows the spell at any rank, and the spell IDs of the ranks it knows (a set,
-- a new table each time it's built, so a slot can tell it changed), kept until SPELLS_CHANGED.
local known, ranks = {}, {}

local function knows(spellID)
    local answer = known[spellID]
    if answer == nil then
        answer = ns.KnowsAnyRank(spellID)
        known[spellID] = answer
    end
    return answer
end

-- The ranks of the spell called name that the character knows: the spell book lists every rank (its
-- "Show all spell ranks" only filters the window), found by name so any locale matches; and the
-- client's highest known rank and the line's own spell, in case the book doesn't have it yet.
local function ranksOf(spellID, name)
    local set = ranks[spellID]
    if set then return set end
    set = {}
    local book, bank = C_SpellBook, Enum.SpellBookSpellBank.Player
    for line = 1, book.GetNumSpellBookSkillLines() do
        local info = book.GetSpellBookSkillLineInfo(line)
        if info then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = book.GetSpellBookItemInfo(slot, bank)
                if item and item.itemType == Enum.SpellBookItemType.Spell and nameOf(item.actionID) == name then
                    set[item.actionID] = true
                end
            end
        end
    end
    local highest = C_Spell.GetSpellIDForSpellIdentifier and C_Spell.GetSpellIDForSpellIdentifier(name)
    if ns.IsUsable(highest) and type(highest) == "number" and book.IsSpellKnownOrInSpellBook(highest) == true then
        set[highest] = true
    end
    if book.IsSpellKnownOrInSpellBook(spellID) == true then set[spellID] = true end
    ranks[spellID] = set
    return set
end

-- The tracked buffs that draw on this character, in the list's order, refilled by each refresh: each
-- one's line, the name it goes by, for a "lacks it" one its group versions' and rivals' names or nil (asked once
-- per refresh, not per frame), for a "has it" one its ranks, and its place: spot and offsets. One
-- without a name from the client yet is left out. hasCount, lacksCount: how many of each kind.
-- size, countdown, countdownSize: the size slider's, the countdown numbers checkbox's and the countdown
-- size slider's values, read with them.
local due, dueNames, dueCounting, dueRanks, dueSpots, dueX, dueY = {}, {}, {}, {}, {}, {}, {}
local hasCount, lacksCount = 0, 0
local size, countdown, countdownSize
local onSpot, placed = {}, {}

local function fillDue()
    for index = #due, 1, -1 do
        due[index], dueNames[index], dueCounting[index], dueRanks[index] = nil, nil, nil, nil
        dueSpots[index], dueX[index], dueY[index] = nil, nil, nil
    end
    hasCount, lacksCount = 0, 0
    size, countdown, countdownSize = Options:Get(SIZE), Options:Get(COUNTDOWN) == true, Options:Get(COUNTDOWN_SIZE)
    local counting
    for _, entry in ipairs(list()) do
        local name = valid(entry) and entry.on == true and knows(entry.spell) and nameOf(entry.spell)
        if name then
            local index = #due + 1
            due[index], dueNames[index] = entry, name
            if entry.kind == "lacks" then
                counting = counting or ns.CountingNames()
                dueCounting[index] = counting[name]
                lacksCount = lacksCount + 1
            else
                dueRanks[index] = ranksOf(entry.spell, name)
                hasCount = hasCount + 1
            end
            local spot = spotOf(entry)
            dueSpots[index] = spot
            onSpot[spot] = (onSpot[spot] or 0) + 1
        end
    end
    -- Each line's place: from a corner or an edge's middle along the edge towards the frame's middle,
    -- or in a row centred on the spot, whether its icon shows or not.
    local step = size + GAP
    for index = 1, #due do
        local spot = dueSpots[index]
        local layout, nth = LAYOUT[spot], (placed[spot] or 0) + 1
        placed[spot] = nth
        if layout.across == 0 then
            dueX[index] = (nth - 1) * step - (onSpot[spot] - 1) * step / 2
        else
            dueX[index] = layout.across * (INSET + (nth - 1) * step)
        end
        dueY[index] = layout.inward * INSET
    end
    clear(onSpot)
    clear(placed)
end

-- The group frames seen (the game's raid-style frames, nameplates among them), and our holder on each.
local frames, holders = {}, {}

local function note(frame)
    if type(frame) ~= "table" or type(frame.GetFrameLevel) ~= "function" then return end
    -- A secret answer counts as forbidden: it can't be tested.
    if frame.IsForbidden then
        local forbidden = frame:IsForbidden()
        if not ns.IsUsable(forbidden) or forbidden then return end
    end
    frames[frame] = true
end

-- A member's frame's unit: the player, a party member or a raid member; nil for anything else
-- (pets, arena, nameplates) and for a frame without one.
local function unitOf(frame)
    local unit = frame.unit
    if not ns.IsUsable(unit) or type(unit) ~= "string" then return nil end
    if unit == "player" or unit:find("^party%d$") or unit:find("^raid%d+$") then return unit end
    return nil
end

-- Our holder on a group frame, made the first time it has an icon to show.
local function holderOf(frame)
    local holder = holders[frame]
    if holder then return holder end
    holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:EnableMouse(false)
    local level = frame:GetFrameLevel()
    if ns.IsUsable(level) and type(level) == "number" then holder:SetFrameLevel(level + LEVEL_ABOVE) end
    holder.icons, holder.slots = {}, {}
    holders[frame] = holder
    return holder
end

-- Puts an icon (ours or a slot's button) at the index-th due line's place at the slider's size.
-- Moved only when its place or size changed; at keeps where it is (the icon itself when it's ours,
-- the slot's table for the game's button, which gets no field of ours).
local function place(icon, at, holder, index)
    local spot, x, y = dueSpots[index], dueX[index], dueY[index]
    if at.spot == spot and at.x == x and at.y == y and at.size == size then return end
    at.spot, at.x, at.y, at.size = spot, x, y, size
    icon:ClearAllPoints()
    icon:SetPoint(spot, holder, spot, x, y)
    icon:SetSize(size, size)
end

local function placedAt(at, index)
    return at.spot == dueSpots[index] and at.x == dueX[index] and at.y == dueY[index] and at.size == size
end

local function withheld()
    return C_Secrets ~= nil and C_Secrets.ShouldAurasBeSecret ~= nil and C_Secrets.ShouldAurasBeSecret() == true
end

-- "Has it" icons --------------------------------------------------------------------------------

-- The game's countdown numbers on the cooldown frame, shown while the checkbox is on, at the slider's
-- size in the game's font file and outline for them.
local function styleButton(slot)
    local cooldown = slot.cooldown
    if not cooldown then return end
    if slot.countdown ~= countdown then
        slot.countdown = countdown
        cooldown:SetHideCountdownNumbers(not countdown)
    end
    if slot.countdownSize ~= countdownSize then
        local text = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
        if not text then return end
        slot.countdownSize = countdownSize
        local file, _, flags = text:GetFont()
        if not ns.IsUsable(file) or type(file) ~= "string" then file, flags = COUNTDOWN_FONT, COUNTDOWN_FLAGS end
        if not ns.IsUsable(flags) or type(flags) ~= "string" then flags = COUNTDOWN_FLAGS end
        text:SetFont(file, countdownSize, flags)
    end
end

-- Gives a slot's button (the game's, made for us) what the game fills: our texture, a cooldown frame
-- for the sweep and the countdown numbers, and the stack count over the sweep. It doesn't take the
-- mouse: no tooltip, and clicks reach the group frame. Placed at the slot's line as it is now, in
-- case the game sets the button up later than the slot was added. What we made is kept on the slot,
-- never as a field on the game's button.
local function setUpButton(button, holder, slot)
    slot.button = button
    button:EnableMouse(false)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    button:SetIcon(icon)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:EnableMouse(false)
    cooldown:SetDrawEdge(false)
    button:SetDurationCooldown(cooldown)
    local over = CreateFrame("Frame", nil, button)
    over:SetAllPoints(button)
    over:EnableMouse(false)
    over:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    local count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    button:SetApplicationCount(count, {})
    slot.cooldown = cooldown
    styleButton(slot)
    place(button, slot, holder, slot.index)
end

-- The holder's aura container, made the first time; nil when the game can't make one (and then
-- never tried again on that frame).
local function containerOf(holder)
    if holder.container or holder.noContainer then return holder.container end
    local made, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    if not made or type(container) ~= "table" then
        holder.noContainer = true
        return nil
    end
    container:SetAllPoints(holder)
    holder.container, holder.containerOn = container, true
    return container
end

-- Turns a holder's container off: no unit, disabled, so the game shows none of its slots.
local function stopContainer(holder)
    local container = holder and holder.container
    if not container or not holder.containerOn then return end
    holder.containerOn = false
    container:SetEnabled(false)
    container:SetUnit("none")
end

local function candidates(set)
    return { includeSpellIDs = set }
end

-- Sets the slot of the index-th due line, a "has it" one, keyed by the line's spell (lines are one per
-- spell), so a line switched off or removed leaves the others' slots alone: its ranks, its place,
-- enabled. While buff data is secret its button can't be touched: one that should move stays
-- disabled until it can be; one that only needs the countdown numbers restyled waits as it is.
local function showSlot(holder, container, index, secret, stamp)
    local key, set = "spell" .. due[index].spell, dueRanks[index]
    local slot = holder.slots[key]
    if not slot then
        slot = { key = key, ranks = set, enabled = true, index = index, stamp = stamp }
        holder.slots[key] = slot
        container:AddAuraSlot(key, OWN, { candidateFilters = candidates(set),
            initializeFrame = function(button) setUpButton(button, holder, slot) end })
        return
    end
    slot.index, slot.stamp = index, stamp
    if slot.ranks ~= set then
        slot.ranks = set
        container:SetAuraSlotCandidateFilters(key, candidates(set))
    end
    local enable = true -- one the game hasn't set up yet is placed when it is
    if slot.cooldown then
        if secret then
            enable = placedAt(slot, index)
        else
            place(slot.button, slot, holder, index)
            styleButton(slot)
        end
    end
    if slot.enabled ~= enable then
        slot.enabled = enable
        container:SetAuraSlotEnabled(key, enable)
    end
end

local function drawHas(frame, unit)
    local holder = holders[frame]
    if not unit or hasCount == 0 then
        stopContainer(holder)
        return
    end
    holder = holder or holderOf(frame)
    local container = containerOf(holder)
    if not container then return end
    container:SetUnit(unit)
    if not holder.containerOn then
        holder.containerOn = true
        container:SetEnabled(true)
    end
    local secret = withheld()
    holder.stamp = (holder.stamp or 0) + 1
    for index, entry in ipairs(due) do
        if entry.kind == "has" then showSlot(holder, container, index, secret, holder.stamp) end
    end
    -- Slots of lines no longer shown "has it" (switched off, removed, made "lacks it") go off.
    for _, slot in pairs(holder.slots) do
        if slot.stamp ~= holder.stamp and slot.enabled then
            slot.enabled = false
            container:SetAuraSlotEnabled(slot.key, false)
        end
    end
end

-- "Lacks it" icons ------------------------------------------------------------------------------

local function newIcon(holder)
    local icon = CreateFrame("Frame", nil, holder)
    icon:EnableMouse(false)
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints(icon)
    icon.Icon:SetDesaturated(true)
    return icon
end

local function hideFrom(holder, first)
    for index = first, #holder.icons do holder.icons[index]:Hide() end
end

-- Anyone's buffs on the unit by name, refilled per frame drawn.
local found = {}

-- Fills found with the unit's buffs; false when the game keeps a buff's name secret.
local function readBuffs(unit)
    for index = 1, MAX_BUFFS do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, ANY)
        -- nil: the end of the list.
        if not ns.IsUsable(aura) then return aura == nil end
        local name = aura.name
        if not ns.IsUsable(name) then return false end
        found[name] = true
    end
    return true
end

-- Whether a "lacks it" icon may show for the unit: alive and online. A secret answer counts as no: we
-- can't tell. Range isn't asked: UnitInRange's answers are always secret to an addon (SecretReturns),
-- and the game already fades an out-of-range member's frame, our holder and its icons with it.
local function present(unit)
    local dead, connected = UnitIsDeadOrGhost(unit), UnitIsConnected(unit)
    if not (ns.IsUsable(dead) and ns.IsUsable(connected)) then return false end
    return not dead and connected
end

-- Whether the unit has a buff of the "lacks it" line's name or of its group versions' or rivals'.
local function hasAny(index)
    if found[dueNames[index]] then return true end
    local others = dueCounting[index]
    if not others then return false end
    for _, name in ipairs(others) do
        if found[name] then return true end
    end
    return false
end

-- Whether a fight is on: from PLAYER_REGEN_DISABLED (before the lockdown starts) to
-- PLAYER_REGEN_ENABLED. "Lacks it" icons are only for between fights.
local fighting = false

local function drawLacks(frame, unit)
    local holder = holders[frame]
    if fighting or not unit or lacksCount == 0 or withheld() or not present(unit) or not readBuffs(unit) then
        if holder then hideFrom(holder, 1) end
        clear(found)
        return
    end
    local nth = 0
    for index, entry in ipairs(due) do
        if entry.kind == "lacks" then
            nth = nth + 1
            local icon = holder and holder.icons[nth]
            if hasAny(index) then
                if icon then icon:Hide() end
            else
                holder = holder or holderOf(frame)
                if not icon then
                    icon = newIcon(holder)
                    holder.icons[nth] = icon
                end
                if icon.spell ~= entry.spell then
                    icon.spell = entry.spell
                    icon.Icon:SetTexture(C_Spell.GetSpellTexture(entry.spell))
                end
                place(icon, icon, holder, index)
                icon:Show()
            end
        end
    end
    clear(found)
    if holder then hideFrom(holder, nth + 1) end
end

-- Refreshes ---------------------------------------------------------------------------------------

-- Whether icons can show: the switch on, on Forever, in a group.
local function active()
    return Options:Get(SWITCH) == true and ns.IsForever() and IsInGroup() == true
end

-- The units whose buffs changed since the last refresh ("lacks it" icons only), or all of them.
local dirty, allDirty = {}, true

local function refresh()
    local all = allDirty
    allDirty = false
    if not active() then
        for _, holder in pairs(holders) do
            hideFrom(holder, 1)
            stopContainer(holder)
        end
        clear(dirty)
        allDirty = true
        return
    end
    fillDue()
    for frame in pairs(frames) do
        local unit = unitOf(frame)
        if all then drawHas(frame, unit) end
        if all or (unit and dirty[unit]) then drawLacks(frame, unit) end
    end
    clear(dirty)
end

local function schedule()
    ns.Later("groupFrameBuffs", refresh, true)
end

local function scheduleAll()
    allDirty = true
    schedule()
end

local function onAura(_, unit, updateInfo)
    if type(unit) ~= "string" or not ns.BuffsMayHaveChanged(updateInfo) then return end
    dirty[unit] = true
    schedule()
end

-- Whether each unit was dead when last asked: UNIT_HEALTH fires on every hit, a redraw only on a change.
local wasDead = {}

local function onHealth(_, unit)
    if type(unit) ~= "string" then return end
    local dead = UnitIsDeadOrGhost(unit)
    if not ns.IsUsable(dead) then dead = "unknown" end
    if wasDead[unit] == dead then return end
    wasDead[unit] = dead
    onAura(nil, unit)
end

-- The members' units in pairs, one unit listener per pair: the player, the party, the raid.
local unitListeners = {}
local hearingMembers, drawing = false, false
-- What "lacks it" icons depend on: a member's buffs, death and connection.
local MEMBER_EVENTS = { UNIT_AURA = onAura, UNIT_HEALTH = onHealth, UNIT_CONNECTION = onAura }

local function members()
    local units = { "player" }
    for index = 1, PARTY do units[#units + 1] = "party" .. index end
    for index = 1, RAID do units[#units + 1] = "raid" .. index end
    return units
end

local function hearMembers(on)
    if on == hearingMembers then return end
    hearingMembers = on
    clear(wasDead)
    for _, listener in ipairs(unitListeners) do
        for event, handler in pairs(MEMBER_EVENTS) do
            if on then listener:On(event, handler) else listener:Off(event) end
        end
    end
end

-- Whether a "lacks it" line is switched on (known or not: SPELLS_CHANGED doesn't change what's heard).
local function lacksOn()
    for _, entry in ipairs(list()) do
        if valid(entry) and entry.kind == "lacks" and entry.on == true then return true end
    end
    return false
end

local update

-- Heard while the switch is on: whether the character is in a group, and frames handed around.
local rosterEvents = ns.Events:NewGroup({ "GROUP_ROSTER_UPDATE" }, function()
    update()
end)
-- Heard while icons can show: the data turning secret and back, a loading screen.
local activeEvents = ns.Events:NewGroup({ "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_ENTERING_WORLD" }, scheduleAll)
-- A fight starting and ending: "lacks it" icons hide and come back, their events with them.
local combatEvents = ns.Events:NewGroup({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }, function(event)
    fighting = event == "PLAYER_REGEN_DISABLED"
    hearMembers(drawing and not fighting and lacksOn())
    scheduleAll()
end)
local spellEvents = ns.Events:NewGroup({ "SPELLS_CHANGED" }, function()
    clear(known)
    clear(ranks)
    scheduleAll()
end)

-- Hears what it needs for the switch and the group, then redraws every frame.
function update()
    if not ns.IsForever() then return end
    local on = Options:Get(SWITCH) == true
    local inGroup = on and IsInGroup() == true
    rosterEvents:SetOn(on)
    activeEvents:SetOn(inGroup)
    -- Combat may have started while its events weren't heard.
    if inGroup and not drawing then fighting = InCombatLockdown() == true end
    drawing = inGroup
    combatEvents:SetOn(inGroup)
    -- Spells may have been learned while SPELLS_CHANGED wasn't heard. Kept across roster changes
    -- otherwise: new ranks give every container new candidate filters.
    if inGroup and not spellEvents.on then
        clear(known)
        clear(ranks)
    end
    spellEvents:SetOn(inGroup)
    hearMembers(inGroup and not fighting and lacksOn())
    scheduleAll()
end

-- Who hears of changes to the list (the page).
local listeners = {}

function GroupFrames.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function afterEdit()
    update()
    for _, fn in ipairs(listeners) do fn() end
end

-- The tracked buffs QoL understands, in the list's order, as the page shows them:
-- { index (its place in the saved list, for SetOn, SetKind, SetSpot and Remove), name, icon, kind, spot,
-- on, known }.
function GroupFrames.Lines()
    local lines = {}
    for index, entry in ipairs(list()) do
        if valid(entry) then
            lines[#lines + 1] = { index = index, name = nameOf(entry.spell),
                icon = C_Spell.GetSpellTexture(entry.spell), kind = entry.kind, spot = spotOf(entry),
                on = entry.on == true, known = ns.KnowsAnyRank(entry.spell) }
        end
    end
    return lines
end

-- Adds the spell on the cursor as a "has it" line, unless it's in the list already at some rank;
-- anything else stays on the cursor. Whether it was added.
function GroupFrames.AddFromCursor()
    local cursorType, _, _, spellID, baseSpellID = GetCursorInfo()
    local id = cursorType == "spell" and (baseSpellID or spellID)
    if type(id) ~= "number" then return false end
    local name, entries = nameOf(id), list()
    -- Any line with the spell counts, one of a kind this QoL doesn't know too (not just valid ones).
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and type(entry.spell) == "number"
            and (entry.spell == id or (name and nameOf(entry.spell) == name)) then
            return false
        end
    end
    entries[#entries + 1] = { spell = id, kind = "has", spot = GroupFrames.DEFAULT_SPOT, on = true }
    ClearCursor()
    afterEdit()
    return true
end

-- index: the line's place in the saved list (Lines' index).
function GroupFrames.Remove(index)
    local entries = list()
    if not valid(entries[index]) then return end
    table.remove(entries, index)
    afterEdit()
end

function GroupFrames.SetOn(index, on)
    local entry = list()[index]
    if not valid(entry) then return end
    entry.on = on == true
    afterEdit()
end

-- kind: "has" or "lacks".
function GroupFrames.SetKind(index, kind)
    local entry = list()[index]
    if not valid(entry) or KINDS[kind] ~= true then return end
    entry.kind = kind
    afterEdit()
end

-- spot: one of GroupFrames.SPOTS.
function GroupFrames.SetSpot(index, spot)
    local entry = list()[index]
    if not valid(entry) or not LAYOUT[spot] then return end
    entry.spot = spot
    afterEdit()
end

function GroupFrames:Init()
    if not ns.IsForever() then return end
    local units = members()
    for index = 1, #units, 2 do
        unitListeners[#unitListeners + 1] = ns.Events:NewUnitListener(units[index], units[index + 1])
    end
    if CompactUnitFrame_SetUpFrame then
        hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
            note(frame)
            if drawing then scheduleAll() end
        end)
    end
    Options:Watch({ SWITCH, SIZE, COUNTDOWN, COUNTDOWN_SIZE }, update)
    update()
end
