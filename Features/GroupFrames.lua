local _, ns = ...
local Options = ns.Options

-- The game's group frames (raid-style party and raid frames), WoW Forever only: the Group Frames
-- page's game setting (whether the game shows its own buff icons on them), and tracked buffs: icons
-- of QoL's own on every group frame for spells the player dragged from the spellbook onto the page
-- (QoLDB.trackedBuffs, for the whole account, in the order added; a line applies only on a character
-- that knows the spell at some rank). A "has it" icon shows while the player's own cast of the buff
-- is on the member, matched by the name the client gives the stored spell ID (any rank, any locale),
-- with the cooldown sweep and a stack number above one. A "lacks it" icon, desaturated with neither,
-- shows while the member has no buff of that name from anyone, nor of its group version's
-- (ns.GroupVersionNames, shared with the reminders), and never on a dead, offline or out-of-range
-- member. Each line's spot (one of nine) places its icon on the frame; icons on a spot line up in the
-- list's order towards the frame's middle, packed, at one size for all (groupFrameBuffSize), and the
-- game's countdown numbers show on "has it" icons while groupFrameBuffCountdown is on.
-- ADR 0004 says why they're icons of our own.
-- The raid manager is hidden by Features/HideFrames.lua (hideRaidManager).
--
-- Taint: the group frames are found the way click casting finds raid-style frames (a hook on the
-- global CompactUnitFrame_SetUpFrame that only notes the frame). Each gets a holder frame of ours,
-- its child, laid over it; nothing is written on, hooked on or called on a game frame but reads
-- (its unit field, GetFrameLevel). The holder and icons aren't protected and don't take the mouse,
-- so clicks and click casting reach the frame, and they're made, shown and moved in combat too.
-- The unit is read from the frame on every refresh, as the game hands frames to other members.
-- Secrecy: every value read from buff data goes through ns.IsUsable first. A tracked buff whose data
-- is secret draws nothing on that frame (a secret name: nothing on the frame at all), and while
-- C_Secrets says buff data is secret every icon hides; nothing read is kept, so the next refresh
-- after the data is readable shows them again.
-- Cost: the master switch off, nothing is heard but the setup hook (which only notes frames); on,
-- GROUP_ROSTER_UPDATE tells when the character is in a group; only then are the members' UNIT_AURA
-- (through unit listeners), spells learned and the secrecy events heard, and, while a "lacks it" line
-- is on, the members' death (UNIT_HEALTH, redrawn only when it changes), connection and range.
-- A secret answer to any of those hides the "lacks it" icons on that frame. Refreshes go through one
-- ns.Later key, at most once per drawn frame, and a UNIT_AURA redraws only that unit's frames.
local GroupFrames = {}
ns.GroupFrames = GroupFrames

-- The game's "Display buffs" raid-frame setting (Blizzard_CompactUnitFrameProfiles turns it into the
-- frames' displayBuffs option whenever it changes). The game keeps it: QoL saves no copy and writes
-- it only when the player clicks its checkbox, never on its own.
GroupFrames.GAME_BUFFS_CVAR = "raidFramesDisplayBuffs"

local SWITCH, SIZE, COUNTDOWN = "groupFrameBuffs", "groupFrameBuffSize", "groupFrameBuffCountdown"
-- The pixels between two icons on a spot, and between an icon and the frame's edge.
local GAP, INSET = 1, 2
-- The nine spots a line's Position picks, in the page's order, each the anchor point it puts the icons
-- at on the frame. A line without one, or with one this QoL doesn't know, goes at the default.
GroupFrames.SPOTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM",
    "BOTTOMRIGHT" }
GroupFrames.DEFAULT_SPOT = "TOPRIGHT"
-- Per spot, which way the icons on it line up across the frame (1 rightwards from the left edge, -1
-- leftwards from the right edge, 0 a row centred on the spot) and which way they're moved in from the
-- top or bottom edge (-1 down, 1 up, 0 not at all).
local LAYOUT = {
    TOPLEFT = { 1, -1 }, TOP = { 0, -1 }, TOPRIGHT = { -1, -1 },
    LEFT = { 1, 0 }, CENTER = { 0, 0 }, RIGHT = { -1, 0 },
    BOTTOMLEFT = { 1, 1 }, BOTTOM = { 0, 1 }, BOTTOMRIGHT = { -1, 1 },
}
local LEVEL_ABOVE = 5 -- the holder's frame level over the group frame's, above its bars
local MAX_BUFFS = 255
local OWN, ANY = "HELPFUL|PLAYER", "HELPFUL" -- buffs the player cast; anyone's
-- The kinds of tracked buff this QoL understands: "has" shows while the player's own cast is on the
-- member, "lacks" while the member has no buff of the name (any caster, its group version too).
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

-- Whether the character knows the spell at any rank, kept until SPELLS_CHANGED for the refreshes.
local known = {}

local function knows(spellID)
    local answer = known[spellID]
    if answer == nil then
        answer = ns.KnowsAnyRank(spellID)
        known[spellID] = answer
    end
    return answer
end

local function clear(set)
    for key in pairs(set) do set[key] = nil end
end

-- The tracked buffs that draw on this character, in the list's order, the name each goes by and, for
-- a "lacks it" one, its group versions' names or nil (asked once per refresh, not per frame); refilled
-- by each refresh. One without a name from the client yet is left out. needOwn, needAny: whether a
-- "has it" and a "lacks it" line is among them, so a frame reads only the buff lists it needs.
-- size, countdown: the size slider's and the countdown numbers checkbox's values, read with them.
local due, dueNames, dueGroups = {}, {}, {}
local needOwn, needAny = false, false
local size, countdown = 16, false

local function fillDue()
    for index = #due, 1, -1 do due[index], dueNames[index], dueGroups[index] = nil, nil, nil end
    needOwn, needAny = false, false
    size, countdown = Options:Get(SIZE), Options:Get(COUNTDOWN) == true
    local groups
    for _, entry in ipairs(list()) do
        local name = valid(entry) and entry.on == true and knows(entry.spell) and nameOf(entry.spell)
        if name then
            due[#due + 1] = entry
            dueNames[#due] = name
            if entry.kind == "lacks" then
                groups = groups or ns.GroupVersionNames()
                dueGroups[#due] = groups[name]
                needAny = true
            else
                needOwn = true
            end
        end
    end
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

local function newIcon(holder)
    local icon = CreateFrame("Frame", nil, holder)
    icon:EnableMouse(false)
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints(icon)
    icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.Cooldown:SetAllPoints(icon)
    icon.Cooldown:EnableMouse(false)
    icon.Cooldown:SetHideCountdownNumbers(true)
    icon.hideNumbers = true
    icon.Cooldown:SetDrawEdge(false)
    -- Over the sweep, so the stack number isn't darkened.
    local over = CreateFrame("Frame", nil, icon)
    over:SetAllPoints(icon)
    over:EnableMouse(false)
    over:SetFrameLevel(icon.Cooldown:GetFrameLevel() + 1)
    icon.Count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    icon.Count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    return icon
end

-- Our holder on a group frame, made the first time it shows an icon.
local function holderOf(frame)
    local holder = holders[frame]
    if holder then return holder end
    holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:EnableMouse(false)
    local level = frame:GetFrameLevel()
    if ns.IsUsable(level) and type(level) == "number" then holder:SetFrameLevel(level + LEVEL_ABOVE) end
    holder.icons = {}
    holders[frame] = holder
    return holder
end

-- The holder's icon for the index-th icon shown, made the first time. Where it goes is place's.
local function iconAt(holder, index)
    local icon = holder.icons[index]
    if not icon then
        icon = newIcon(holder)
        holder.icons[index] = icon
    end
    icon:Show()
    return icon
end

-- Puts an icon at its spot as the nth of count icons there, at the slider's size: from a corner or
-- an edge's middle along the edge towards the frame's middle, or in a row centred on the spot. Moved
-- only when its place or size changed.
local function place(icon, holder, spot, nth, count)
    local layout, step = LAYOUT[spot], size + GAP
    local across, x = layout[1]
    if across == 0 then
        x = (nth - 1) * step - (count - 1) * step / 2
    else
        x = across * (INSET + (nth - 1) * step)
    end
    local y = layout[2] * INSET
    if icon.spot == spot and icon.x == x and icon.y == y and icon.size == size then return end
    icon.spot, icon.x, icon.y, icon.size = spot, x, y, size
    icon:ClearAllPoints()
    icon:SetPoint(spot, holder, spot, x, y)
    icon:SetSize(size, size)
end

local function hideFrom(holder, first)
    for index = first, #holder.icons do holder.icons[index]:Hide() end
end

local function withheld()
    return C_Secrets ~= nil and C_Secrets.ShouldAurasBeSecret ~= nil and C_Secrets.ShouldAurasBeSecret() == true
end

-- The unit's buffs by name, refilled per frame drawn: the player's own (the buff), and anyone's (true).
local found, foundAny = {}, {}

-- Fills set with the unit's buffs through filter; false when the game keeps a buff's name secret.
local function readBuffs(set, unit, filter, keep)
    for index = 1, MAX_BUFFS do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        -- nil: the end of the list.
        if not ns.IsUsable(aura) then return aura == nil end
        local name = aura.name
        if not ns.IsUsable(name) then return false end
        if set[name] == nil then set[name] = keep and aura or true end
    end
    return true
end

-- Fills the sets the due lines need; false when a name is secret.
local function read(unit)
    if needOwn and not readBuffs(found, unit, OWN, true) then return false end
    return not needAny or readBuffs(foundAny, unit, ANY, false)
end

-- Whether a "lacks it" icon may show for the unit: alive, online and in range (the game doesn't check
-- the player's own range). A secret answer counts as no: we can't tell.
local function present(unit)
    local dead, connected = UnitIsDeadOrGhost(unit), UnitIsConnected(unit)
    if not (ns.IsUsable(dead) and ns.IsUsable(connected)) or dead or not connected then return false end
    local inRange, checked = UnitInRange(unit)
    if not (ns.IsUsable(inRange) and ns.IsUsable(checked)) then return false end
    return not checked or inRange == true
end

-- Whether the unit has a buff of the "lacks it" line's name or of its group versions'.
local function hasAny(index)
    if foundAny[dueNames[index]] then return true end
    local groups = dueGroups[index]
    if not groups then return false end
    for _, name in ipairs(groups) do
        if foundAny[name] then return true end
    end
    return false
end

-- The numbers an icon needs from a buff, or nil while any is secret.
local function numbers(aura)
    local stacks, duration, expires = aura.applications, aura.duration, aura.expirationTime
    if not (ns.IsUsable(stacks) and ns.IsUsable(duration) and ns.IsUsable(expires)) then return nil end
    if type(stacks) ~= "number" or type(duration) ~= "number" or type(expires) ~= "number" then return nil end
    return stacks, duration, expires
end

-- Sets an icon (our own frame, which keeps what it shows) only where it changed: a UNIT_AURA redraw
-- mostly finds it as it was. A "lacks it" icon has no numbers (0 each): no sweep, no stacks, and is
-- desaturated.
local function draw(icon, entry, stacks, duration, expires)
    if icon.spell ~= entry.spell then
        icon.spell = entry.spell
        icon.Icon:SetTexture(C_Spell.GetSpellTexture(entry.spell))
    end
    local lacking = entry.kind == "lacks"
    if icon.lacking ~= lacking then
        icon.lacking = lacking
        icon.Icon:SetDesaturated(lacking)
    end
    if icon.expires ~= expires or icon.duration ~= duration then
        icon.expires, icon.duration = expires, duration
        if duration > 0 and expires > 0 then
            icon.Cooldown:SetCooldown(expires - duration, duration)
        else
            icon.Cooldown:Clear()
        end
    end
    if icon.stacks ~= stacks then
        icon.stacks = stacks
        if stacks > 1 then icon.Count:SetText(tostring(stacks)) end
        icon.Count:SetShown(stacks > 1)
    end
    -- The game's countdown numbers come with the sweep, so a "lacks it" icon never shows them.
    local hideNumbers = not countdown
    if icon.hideNumbers ~= hideNumbers then
        icon.hideNumbers = hideNumbers
        icon.Cooldown:SetHideCountdownNumbers(hideNumbers)
    end
end

-- The icons a frame shows, refilled per frame drawn: each one's line and numbers, and how many go on
-- each spot (so a centred row knows its length before its first icon is placed), then how many of them
-- are placed so far.
local shownEntries, shownStacks, shownDurations, shownExpiries = {}, {}, {}, {}
local onSpot, placed = {}, {}

-- Draws the tracked buffs on one group frame for its unit (nil: none).
local function drawFrame(frame, unit)
    local holder = holders[frame]
    if not unit or #due == 0 or not read(unit) then
        if holder then hideFrom(holder, 1) end
        clear(found)
        clear(foundAny)
        return
    end
    local count, canLack = 0, nil
    for index, entry in ipairs(due) do
        local stacks, duration, expires
        if entry.kind == "lacks" then
            if canLack == nil then canLack = present(unit) end
            if canLack and not hasAny(index) then stacks, duration, expires = 0, 0, 0 end
        else
            local aura = found[dueNames[index]]
            if aura then stacks, duration, expires = numbers(aura) end
        end
        if stacks then
            count = count + 1
            shownEntries[count], shownStacks[count] = entry, stacks
            shownDurations[count], shownExpiries[count] = duration, expires
            local spot = spotOf(entry)
            onSpot[spot] = (onSpot[spot] or 0) + 1
        end
    end
    clear(found)
    clear(foundAny)
    if count > 0 then holder = holder or holderOf(frame) end
    for index = 1, count do
        local entry = shownEntries[index]
        local spot = spotOf(entry)
        local nth = (placed[spot] or 0) + 1
        placed[spot] = nth
        local icon = iconAt(holder, index)
        place(icon, holder, spot, nth, onSpot[spot])
        draw(icon, entry, shownStacks[index], shownDurations[index], shownExpiries[index])
        shownEntries[index] = nil
    end
    clear(onSpot)
    clear(placed)
    if holder then hideFrom(holder, count + 1) end
end

-- Whether icons can show: the switch on, on Forever, in a group.
local function active()
    return Options:Get(SWITCH) == true and ns.IsForever() and IsInGroup() == true
end

-- The units whose buffs changed since the last refresh, or all of them.
local dirty, allDirty = {}, true

local function hideAll()
    for _, holder in pairs(holders) do hideFrom(holder, 1) end
end

local function refresh()
    local all = allDirty
    allDirty = false
    if not active() or withheld() then
        hideAll()
        clear(dirty)
        -- Once readable again, every frame is drawn anew.
        allDirty = true
        return
    end
    fillDue()
    for frame in pairs(frames) do
        local unit = unitOf(frame)
        if all or (unit and dirty[unit]) then drawFrame(frame, unit) end
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

local function onAura(_, unit)
    if type(unit) ~= "string" then return end
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
local listening, hearingStatus = false, false
-- A member's death, connection and range: only "lacks it" icons care.
local STATUS_EVENTS = { UNIT_HEALTH = onHealth, UNIT_CONNECTION = onAura, UNIT_IN_RANGE_UPDATE = onAura }

local function members()
    local units = { "player" }
    for index = 1, PARTY do units[#units + 1] = "party" .. index end
    for index = 1, RAID do units[#units + 1] = "raid" .. index end
    return units
end

local function hearAuras(on)
    if on == listening then return end
    listening = on
    for _, listener in ipairs(unitListeners) do
        if on then listener:On("UNIT_AURA", onAura) else listener:Off("UNIT_AURA") end
    end
end

local function hearStatus(on)
    if on == hearingStatus then return end
    hearingStatus = on
    clear(wasDead)
    for _, listener in ipairs(unitListeners) do
        for event, handler in pairs(STATUS_EVENTS) do
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
-- Heard while icons can show: the data turning secret and back, a loading screen, spells learned.
local activeEvents = ns.Events:NewGroup({ "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }, scheduleAll)
local spellEvents = ns.Events:NewGroup({ "SPELLS_CHANGED" }, function()
    clear(known)
    scheduleAll()
end)

-- Hears what it needs for the switch and the group, then redraws every frame.
function update()
    if not ns.IsForever() then return end
    local on = Options:Get(SWITCH) == true
    local inGroup = on and IsInGroup() == true
    rosterEvents:SetOn(on)
    activeEvents:SetOn(inGroup)
    -- Spells may have been learned while SPELLS_CHANGED wasn't heard.
    clear(known)
    spellEvents:SetOn(inGroup)
    hearAuras(inGroup)
    hearStatus(inGroup and lacksOn())
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
            if listening then scheduleAll() end
        end)
    end
    Options:Watch({ SWITCH, SIZE, COUNTDOWN }, update)
    update()
end
