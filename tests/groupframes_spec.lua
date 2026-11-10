local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Forever's Regrowth (ranks 1 and 2) and Rejuvenation, with made-up icons.
local REGROWTH_1, REGROWTH_2, REJUVENATION = 8936, 8938, 774
local REGROWTH_ICON, REJUVENATION_ICON = 136085, 136081

local DRUID = {
    [REGROWTH_1] = { name = "Regrowth", texture = REGROWTH_ICON, subtext = "Rank 1" },
    [REJUVENATION] = { name = "Rejuvenation", texture = REJUVENATION_ICON, subtext = "Rank 1" },
}

-- Loads the addon on Forever with the druid spells' data, the account's tracked buffs saved
-- ({ spell, kind, on } each), the character knowing known (DRUID by default; {} for none), in a group
-- unless options.solo, and logs in.
local function start(savedOptions, tracked, known, options)
    options = options or {}
    local ns = Stubs.LoadAddon({ client = options.client })
    local state = Stubs.state()
    state.gameSpells[REGROWTH_1] = { name = "Regrowth", texture = REGROWTH_ICON }
    state.gameSpells[REGROWTH_2] = { name = "Regrowth", texture = REGROWTH_ICON }
    state.gameSpells[REJUVENATION] = { name = "Rejuvenation", texture = REJUVENATION_ICON }
    for id, info in pairs(known or DRUID) do state.spells[id] = info end
    state.inGroup = not options.solo
    _G.QoLDB = { options = savedOptions, trackedBuffs = tracked }
    Stubs.Fire("ADDON_LOADED", "QoL")
    Stubs.Fire("PLAYER_LOGIN")
    Stubs.Fire("PLAYER_ENTERING_WORLD")
    Stubs.RunTimers()
    return ns
end

local ON = { groupFrameBuffs = true }
local function has(spell, on) return { spell = spell, kind = "has", on = on ~= false } end

-- A buff on a member: the player's own cast unless caster says otherwise, 30 seconds of 60 left.
local function buff(name, spellId, caster, extra)
    local b = { name = name, spellId = spellId, sourceUnit = caster or "player", duration = 60,
        expirationTime = Stubs.state().now + 30 }
    for key, value in pairs(extra or {}) do b[key] = value end
    return b
end

-- What QoL put on a group frame: its children that aren't the game's (those are protected).
local function ours(frame)
    local raw = Stubs.state().rawFrames[frame] or frame
    local found = {}
    for _, region in ipairs(Stubs.state().regions) do
        if (region.parent == frame or region.parent == raw) and not region.protected and region.kind == "Frame" then
            found[#found + 1] = region
        end
    end
    return found
end

-- The tracked buff icons the player sees on a group frame, from the frame's corner inwards.
local function shownIcons(frame)
    local icons = {}
    if not frame:IsVisible() then return icons end
    for _, holder in ipairs(ours(frame)) do
        for _, child in ipairs({ holder:GetChildren() }) do
            if child:IsVisible() then icons[#icons + 1] = child end
        end
    end
    table.sort(icons, function(a, b) return a:GetPoint(1) and select(4, a:GetPoint(1)) > select(4, b:GetPoint(1)) end)
    return icons
end

-- Each shown icon's texture.
local function seen(frame)
    local textures = {}
    for index, icon in ipairs(shownIcons(frame)) do textures[index] = icon.Icon.texture end
    return textures
end

describe("Group frames: tracked buffs", function()
    it("shows a \"has it\" icon while the player's own cast is on the member, and drops it once gone", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.RunTimers()
        T.same(seen(frame), {})
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_2) })
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON }, "matched by name, any rank")
        Stubs.SetUnitBuffs("raid1", {})
        Stubs.RunTimers()
        T.same(seen(frame), {})
    end)

    it("counts only the player's own cast", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("party1")
        Stubs.SetUnitBuffs("party1", { buff("Regrowth", REGROWTH_1, "party2") })
        Stubs.RunTimers()
        T.same(seen(frame), {}, "another druid's Regrowth")
    end)

    it("shows nothing with the master switch off, its default, and removes every icon when it goes off", function()
        local ns = start(nil, { has(REGROWTH_1) })
        T.eq(ns.Options:Get("groupFrameBuffs"), false)
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), {})
        ns.Options:Set("groupFrameBuffs", true)
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON })
        ns.Options:Set("groupFrameBuffs", false)
        Stubs.RunTimers()
        T.same(seen(frame), {})
    end)

    it("shows the tracked buffs in the list's order, side by side from the top right corner inwards", function()
        start(ON, { has(REJUVENATION), has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1), buff("Rejuvenation", REJUVENATION) })
        Stubs.RunTimers()
        T.same(seen(frame), { REJUVENATION_ICON, REGROWTH_ICON })
        local icons = shownIcons(frame)
        local first, second = { icons[1]:GetPoint(1) }, { icons[2]:GetPoint(1) }
        T.eq(first[1], "TOPRIGHT")
        T.eq(first[3], "TOPRIGHT")
        T.truthy(second[4] < first[4], "the second one left of the first")
        T.eq(second[5], first[5], "on one line")
        T.eq(icons[1]:GetWidth(), icons[1]:GetHeight())
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same({ shownIcons(frame)[1]:GetPoint(1) }, first, "a hidden one leaves no gap")
    end)

    it("shows the time left as a sweep and the stacks above one", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        local now = Stubs.state().now
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1, nil, { duration = 21, expirationTime = now + 6 }) })
        Stubs.RunTimers()
        local icon = shownIcons(frame)[1]
        T.same(icon.Cooldown.duration, { start = now - 15, seconds = 21 })
        T.falsy(icon.Count:IsShown() and icon.Count:GetText() ~= "", "one stack: no number")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1, nil, { applications = 3 }) })
        Stubs.RunTimers()
        icon = shownIcons(frame)[1]
        T.truthy(icon.Count:IsShown())
        T.eq(icon.Count:GetText(), "3")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1, nil, { duration = 0, expirationTime = 0 }) })
        Stubs.RunTimers()
        T.eq(shownIcons(frame)[1].Cooldown.duration, nil, "no sweep for a buff without a duration")
    end)

    it("shows nothing for a switched-off line or a spell the character doesn't know", function()
        start(ON, { has(REGROWTH_1, false), has(REJUVENATION) }, { [REGROWTH_1] = DRUID[REGROWTH_1] })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1), buff("Rejuvenation", REJUVENATION) })
        Stubs.RunTimers()
        T.same(seen(frame), {})
    end)

    it("is on the player's own frame and the raid-style party frames, not on pet or arena frames", function()
        start(ON, { has(REGROWTH_1) })
        local own, party = Stubs.NewGroupFrame("player"), Stubs.NewGroupFrame("party2")
        local pet, raidPet, arena = Stubs.NewGroupFrame("partypet1"), Stubs.NewGroupFrame("raidpet1"),
            Stubs.NewGroupFrame("arena1")
        for _, unit in ipairs({ "player", "party2", "partypet1", "raidpet1", "arena1" }) do
            Stubs.SetUnitBuffs(unit, { buff("Regrowth", REGROWTH_1) })
        end
        Stubs.RunTimers()
        T.same(seen(own), { REGROWTH_ICON })
        T.same(seen(party), { REGROWTH_ICON })
        T.same(seen(pet), {})
        T.same(seen(raidPet), {})
        T.same(seen(arena), {})
    end)

    it("lets the mouse through to the group frame", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        for _, holder in ipairs(ours(frame)) do T.falsy(holder.mouseEnabled) end
        T.falsy(shownIcons(frame)[1].mouseEnabled)
    end)

    it("follows when the game hands a frame to another member", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.state().unitBuffs.raid1 = { buff("Regrowth", REGROWTH_1) }
        Stubs.state().unitBuffs.raid2 = {}
        Stubs.Fire("UNIT_AURA", "raid1")
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON })
        Stubs.SetFrameUnit(frame, "raid2")
        Stubs.RunTimers()
        T.same(seen(frame), {})
        Stubs.SetUnitBuffs("raid2", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON }, "raid2's buffs now count on it")
    end)

    it("puts icons on frames set up in combat, and changes them in combat", function()
        start(ON, { has(REGROWTH_1) })
        Stubs.SetCombat(true)
        Stubs.state().unitBuffs.raid3 = { buff("Regrowth", REGROWTH_1) }
        local frame = Stubs.NewGroupFrame("raid3")
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON })
        Stubs.SetUnitBuffs("raid3", {})
        Stubs.RunTimers()
        T.same(seen(frame), {})
    end)

    it("hides a tracked buff while its data is secret, and shows it again once readable", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1, nil, { applications = Stubs.SECRET }) })
        Stubs.RunTimers()
        T.same(seen(frame), {}, "a secret stack count")
        Stubs.SetUnitBuffs("raid1", { buff(Stubs.SECRET, REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), {}, "a secret name")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1, nil, { expirationTime = Stubs.SECRET }) })
        Stubs.RunTimers()
        T.same(seen(frame), {}, "a secret expiry")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON })
    end)

    it("hides every icon while the game withholds buff data, and shows them again once it's readable", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        Stubs.WithholdAuras(true)
        Stubs.Fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
        Stubs.RunTimers()
        T.same(seen(frame), {})
        Stubs.WithholdAuras(false)
        Stubs.Fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON })
    end)

    -- GROUP_ROSTER_UPDATE and SPELLS_CHANGED are other features' too, so the spec can't tell ours.
    it("hears nothing while the switch is off, and the members' buffs only while in a group", function()
        local ns = start(nil, { has(REGROWTH_1) }, nil, { solo = true })
        T.falsy(Stubs.Listens("ADDON_RESTRICTION_STATE_CHANGED"), "off")
        T.falsy(Stubs.Listens("UNIT_AURA", "player"), "off")
        Stubs.SetGroup(true)
        Stubs.RunTimers()
        T.falsy(Stubs.Listens("UNIT_AURA", "raid1"), "off, in a group")
        Stubs.SetGroup(false)
        ns.Options:Set("groupFrameBuffs", true)
        Stubs.RunTimers()
        T.falsy(Stubs.Listens("UNIT_AURA", "player"), "solo")
        T.falsy(Stubs.Listens("UNIT_AURA", "raid1"), "solo")
        T.falsy(Stubs.Listens("ADDON_RESTRICTION_STATE_CHANGED"), "solo")
        Stubs.SetGroup(true)
        Stubs.RunTimers()
        for _, unit in ipairs({ "player", "party1", "party4", "raid1", "raid40" }) do
            T.truthy(Stubs.Listens("UNIT_AURA", unit), unit)
        end
        T.truthy(Stubs.Listens("ADDON_RESTRICTION_STATE_CHANGED"))
        Stubs.SetGroup(false)
        Stubs.RunTimers()
        T.falsy(Stubs.Listens("UNIT_AURA", "raid1"), "left the group")
        Stubs.SetGroup(true)
        ns.Options:Set("groupFrameBuffs", false)
        Stubs.RunTimers()
        T.falsy(Stubs.Listens("UNIT_AURA", "raid1"), "switched off")
        T.falsy(Stubs.Listens("ADDON_RESTRICTION_STATE_CHANGED"), "switched off")
    end)

    it("shows a spell once the character learns it", function()
        start(ON, { has(REJUVENATION) }, { [REGROWTH_1] = DRUID[REGROWTH_1] })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Rejuvenation", REJUVENATION) })
        Stubs.RunTimers()
        T.same(seen(frame), {})
        Stubs.state().spells[REJUVENATION] = DRUID[REJUVENATION]
        Stubs.Fire("SPELLS_CHANGED")
        Stubs.RunTimers()
        T.same(seen(frame), { REJUVENATION_ICON })
    end)

    it("adds a spell from the cursor once, pauses and removes a line, and keeps a line it doesn't understand", function()
        local newer = { aura = 1, on = true }
        local ns = start(ON, { newer })
        local state = Stubs.state()
        state.cursorInfo = { "spell", 1, "spell", REGROWTH_1, REGROWTH_1 }
        T.truthy(ns.GroupFrames.AddFromCursor())
        T.eq(state.cursorInfo, nil)
        state.cursorInfo = { "spell", 1, "spell", REGROWTH_2, REGROWTH_2 }
        T.falsy(ns.GroupFrames.AddFromCursor(), "another rank of a spell in the list")
        state.cursorInfo = { "item", 4540, "item:4540" }
        T.falsy(ns.GroupFrames.AddFromCursor())
        state.cursorInfo = { "spell", 1, "spell", REJUVENATION, REJUVENATION }
        T.truthy(ns.GroupFrames.AddFromCursor())
        T.same(QoLDB.trackedBuffs, { newer, has(REGROWTH_1), has(REJUVENATION) })
        T.same(ns.GroupFrames.Lines(), {
            { index = 2, name = "Regrowth", icon = REGROWTH_ICON, on = true, known = true },
            { index = 3, name = "Rejuvenation", icon = REJUVENATION_ICON, on = true, known = true },
        })
        ns.GroupFrames.SetOn(2, false)
        ns.GroupFrames.Remove(3)
        T.same(QoLDB.trackedBuffs, { newer, has(REGROWTH_1, false) })
    end)

    it("keeps the account's list across a reload and on a character that knows none of it", function()
        start(ON, { has(REGROWTH_1) })
        local saved = QoLDB
        local ns = start(saved.options, saved.trackedBuffs, {})
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), {})
        T.same(ns.GroupFrames.Lines(), { { index = 1, name = "Regrowth", icon = REGROWTH_ICON, on = true, known = false } })
    end)

    for _, client in ipairs({ "retail", "classicEra" }) do
        it("does nothing on " .. client, function()
            start(ON, { has(REGROWTH_1) }, nil, { client = client })
            Stubs.SetGroup(true)
            Stubs.RunTimers()
            T.falsy(Stubs.Listens("ADDON_RESTRICTION_STATE_CHANGED"))
            T.falsy(Stubs.Listens("UNIT_AURA", "raid1"))
        end)
    end
end)
