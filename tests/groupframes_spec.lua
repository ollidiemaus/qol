local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Forever's Regrowth (ranks 1 and 2) and Rejuvenation, with made-up icons.
local REGROWTH_1, REGROWTH_2, REJUVENATION = 8936, 8938, 774
local REGROWTH_ICON, REJUVENATION_ICON = 136085, 136081
local LIFEBLOOM, LIFEBLOOM_ICON = 33763, 134206
-- Mark of the Wild (ranks 1 and 2) and its group version, Gift of the Wild.
local MARK_1, MARK_2, GIFT = 1126, 5232, 21849
local MARK_ICON, GIFT_ICON = 136078, 136038
local ICONS = { Regrowth = REGROWTH_ICON, Rejuvenation = REJUVENATION_ICON, Lifebloom = LIFEBLOOM_ICON,
    ["Mark of the Wild"] = MARK_ICON, ["Gift of the Wild"] = GIFT_ICON }

local DRUID = {
    [REGROWTH_1] = { name = "Regrowth", texture = REGROWTH_ICON, subtext = "Rank 1" },
    [REJUVENATION] = { name = "Rejuvenation", texture = REJUVENATION_ICON, subtext = "Rank 1" },
    [LIFEBLOOM] = { name = "Lifebloom", texture = LIFEBLOOM_ICON, subtext = "" },
    [MARK_1] = { name = "Mark of the Wild", texture = MARK_ICON, subtext = "Rank 1" },
}
local REGROWTH_RANK_2 = { name = "Regrowth", texture = REGROWTH_ICON, subtext = "Rank 2" }

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
    state.gameSpells[LIFEBLOOM] = { name = "Lifebloom", texture = LIFEBLOOM_ICON }
    state.gameSpells[MARK_1] ={ name = "Mark of the Wild", texture = MARK_ICON }
    state.gameSpells[MARK_2] = { name = "Mark of the Wild", texture = MARK_ICON }
    state.gameSpells[GIFT] = { name = "Gift of the Wild", texture = GIFT_ICON }
    for id, info in pairs(known or DRUID) do state.spells[id] = info end
    state.inGroup = not options.solo
    state.noAuraContainer = options.noAuraContainer
    -- A copy: the addon writes into its saved options, and ON is every case's.
    local copy
    if savedOptions then
        copy = {}
        for key, value in pairs(savedOptions) do copy[key] = value end
    end
    _G.QoLDB = { options = copy, trackedBuffs = tracked }
    Stubs.Fire("ADDON_LOADED", "QoL")
    Stubs.Fire("PLAYER_LOGIN")
    Stubs.Fire("PLAYER_ENTERING_WORLD")
    Stubs.RunTimers()
    return ns
end

local ON = { groupFrameBuffs = true }
local function has(spell, on, spot) return { spell = spell, kind = "has", on = on ~= false, spot = spot } end
local function lacks(spell, on, spot) return { spell = spell, kind = "lacks", on = on ~= false, spot = spot } end

-- A buff on a member: the player's own cast unless caster says otherwise, 30 seconds of 60 left.
local function buff(name, spellId, caster, extra)
    local b = { name = name, spellId = spellId, icon = ICONS[name], sourceUnit = caster or "player", duration = 60,
        expirationTime = Stubs.state().now + 30 }
    for key, value in pairs(extra or {}) do b[key] = value end
    return b
end

-- A fight starts (true) or ends (false): the game keeps buff data secret for the whole of it, as
-- Forever does with group members' buffs.
local function fight(on)
    if on then
        Stubs.state().combat = true
        Stubs.WithholdAuras(true)
        Stubs.Fire("PLAYER_REGEN_DISABLED")
    else
        Stubs.WithholdAuras(false)
        Stubs.SetCombat(false)
    end
    Stubs.RunTimers()
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

local function within(region, holders)
    local node = region.parent
    while node do
        if holders[node] then return true end
        node = node.parent
    end
    return false
end

-- What an icon shows with: our own icon's fields, or what the game's aura button was handed.
local function parts(region)
    local icon = rawget(region, "Icon") or rawget(region, "handedIcon")
    return type(icon) == "table" and icon or nil,
        rawget(region, "Cooldown") or rawget(region, "handedCooldown"),
        rawget(region, "Count") or rawget(region, "handedCount")
end

local function iconOf(region) return (parts(region)) end
local function cooldownOf(region) return select(2, parts(region)) end

-- The tracked buff icons the player sees on a group frame (anything of ours under it with an icon
-- texture, the game's aura buttons too), from the frame's right edge leftwards.
local function shownIcons(frame)
    local icons = {}
    if not frame:IsVisible() then return icons end
    local holders = {}
    for _, holder in ipairs(ours(frame)) do holders[holder] = true end
    for _, region in ipairs(Stubs.state().regions) do
        if parts(region) and within(region, holders) and region:IsVisible() then icons[#icons + 1] = region end
    end
    table.sort(icons, function(a, b) return a:GetPoint(1) and select(4, a:GetPoint(1)) > select(4, b:GetPoint(1)) end)
    return icons
end

-- Where each shown icon sits, by texture: { point, relativePoint, x, y } of its anchor on the frame.
local function places(frame)
    local found = {}
    for _, icon in ipairs(shownIcons(frame)) do
        local point, _, relativePoint, x, y = icon:GetPoint(1)
        found[(parts(icon)).texture] = { point, relativePoint, x, y }
    end
    return found
end

-- The sweep an icon shows ({ start, seconds }), or nil.
local function sweep(icon)
    local _, cooldown = parts(icon)
    return cooldown and cooldown.duration
end

-- The stack number an icon shows, or nil.
local function number(icon)
    local _, _, count = parts(icon)
    local text = count and count:IsVisible() and count:GetText()
    if text and text ~= "" then return text end
    return nil
end

-- Each shown icon's texture.
local function seen(frame)
    local textures = {}
    for index, icon in ipairs(shownIcons(frame)) do textures[index] = iconOf(icon).texture end
    return textures
end

describe("Group frames: tracked buffs", function()
    it("shows a \"has it\" icon while the player's own cast is on the member, and drops it once gone", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.RunTimers()
        T.same(seen(frame), {})
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON })
        Stubs.SetUnitBuffs("raid1", {})
        Stubs.RunTimers()
        T.same(seen(frame), {})
    end)

    it("shows a \"has it\" icon in a fight, with its sweep, stacks and countdown numbers", function()
        local ns = start(ON, { has(REGROWTH_1) })
        ns.Options:Set("groupFrameBuffCountdown", true)
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.RunTimers()
        fight(true)
        local now = Stubs.state().now
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1, nil, { applications = 2, duration = 21,
            expirationTime = now + 6 }) })
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON }, "in combat, buff data secret")
        local icon = shownIcons(frame)[1]
        T.same(cooldownOf(icon).duration, { start = now - 15, seconds = 21 })
        T.eq(number(icon), "2")
        T.falsy(cooldownOf(icon).hideCountdownNumbers, "the countdown numbers")
        T.falsy(iconOf(icon).desaturated)
        Stubs.SetUnitBuffs("raid1", {})
        Stubs.RunTimers()
        T.same(seen(frame), {}, "gone the moment it ends")
    end)

    it("counts only the player's own cast, in and out of combat", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("party1")
        Stubs.SetUnitBuffs("party1", { buff("Regrowth", REGROWTH_1, "party2") })
        Stubs.RunTimers()
        T.same(seen(frame), {}, "another druid's Regrowth")
        fight(true)
        T.same(seen(frame), {}, "in a fight")
    end)

    it("counts every rank the character knows, not one it doesn't, and a rank learnt without a reload", function()
        start(ON, { has(REGROWTH_2) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON }, "a lower rank, the line's spell dragged at rank 2 elsewhere")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_2) })
        Stubs.RunTimers()
        T.same(seen(frame), {}, "a rank the character doesn't know")
        Stubs.state().spells[REGROWTH_2] = REGROWTH_RANK_2
        Stubs.Fire("SPELLS_CHANGED")
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON }, "rank 2 learnt")
    end)

    it("shows a \"lacks it\" icon on a member without the buff, desaturated with no sweep, gone once they get it", function()
        start(ON, { lacks(MARK_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", {})
        Stubs.RunTimers()
        T.same(seen(frame), { MARK_ICON })
        local icon = shownIcons(frame)[1]
        T.truthy(iconOf(icon).desaturated, "desaturated")
        T.eq(sweep(icon), nil, "no sweep")
        T.eq(number(icon), nil, "no number")
        Stubs.SetUnitBuffs("raid1", { buff("Mark of the Wild", MARK_2, "party3") })
        Stubs.RunTimers()
        T.same(seen(frame), {}, "another caster's, another rank")
        Stubs.SetUnitBuffs("raid1", { buff("Gift of the Wild", GIFT, "raid7") })
        Stubs.RunTimers()
        T.same(seen(frame), {}, "the group version")
        Stubs.SetUnitBuffs("raid1", {})
        Stubs.RunTimers()
        T.same(seen(frame), { MARK_ICON })
    end)

    it("shows a \"has it\" icon in colour next to a \"lacks it\" one, each at its own place", function()
        start(ON, { has(REGROWTH_1), lacks(MARK_1) })
        local frame = Stubs.NewGroupFrame("party1")
        Stubs.SetUnitBuffs("party1", { buff("Regrowth", REGROWTH_1, nil, { applications = 2 }) })
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON, MARK_ICON })
        local icons = shownIcons(frame)
        T.falsy(iconOf(icons[1]).desaturated)
        T.truthy(cooldownOf(icons[1]).duration)
        T.truthy(iconOf(icons[2]).desaturated)
        Stubs.SetUnitBuffs("party1", { buff("Mark of the Wild", MARK_1, "player") })
        Stubs.RunTimers()
        T.same(seen(frame), {})
        Stubs.SetUnitBuffs("party1", {})
        Stubs.RunTimers()
        T.same(places(frame), { [MARK_ICON] = { "TOPRIGHT", "TOPRIGHT", -19, -2 } }, "its own place, not Regrowth's")
        local mark = shownIcons(frame)[1]
        T.truthy(iconOf(mark).desaturated)
        T.eq(sweep(mark), nil)
        T.eq(number(mark), nil)
    end)

    it("shows no \"lacks it\" icon on a dead or offline member, and shows it again once back", function()
        start(ON, { lacks(MARK_1) })
        local frame = Stubs.NewGroupFrame("raid2")
        Stubs.SetUnitBuffs("raid2", {})
        Stubs.RunTimers()
        T.same(seen(frame), { MARK_ICON })
        for _, change in ipairs({ "dead", "offline" }) do
            Stubs.SetMember("raid2", { [change] = true })
            Stubs.RunTimers()
            T.same(seen(frame), {}, change)
            Stubs.SetMember("raid2", { [change] = false })
            Stubs.RunTimers()
            T.same(seen(frame), { MARK_ICON }, change .. ", back")
        end
        for _, change in ipairs({ "dead", "offline" }) do
            Stubs.SetMember("raid2", { [change] = Stubs.SECRET })
            Stubs.RunTimers()
            T.same(seen(frame), {}, "a secret answer: " .. change)
            Stubs.SetMember("raid2", { [change] = false })
            Stubs.RunTimers()
        end
        T.same(seen(frame), { MARK_ICON })
    end)

    -- UnitInRange is always secret to an addon on Forever; the game fades the member's whole frame.
    it("shows a \"lacks it\" icon on an out-of-range member, the range being the frame's fade", function()
        start(ON, { lacks(MARK_1) })
        local frame = Stubs.NewGroupFrame("raid2")
        Stubs.SetUnitBuffs("raid2", {})
        Stubs.SetMember("raid2", { outOfRange = true })
        Stubs.RunTimers()
        T.same(seen(frame), { MARK_ICON })
    end)

    it("hides every \"lacks it\" icon when a fight starts and shows them again once it ends", function()
        start(ON, { lacks(MARK_1), has(REGROWTH_1) })
        local own, party = Stubs.NewGroupFrame("player"), Stubs.NewGroupFrame("party1")
        Stubs.SetUnitBuffs("party1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(own), { MARK_ICON }, "on the player's own frame too")
        T.same(seen(party), { MARK_ICON, REGROWTH_ICON })
        local regrowthPlace = places(party)[REGROWTH_ICON]
        Stubs.state().combat = true
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.RunTimers()
        T.same(seen(own), {}, "the moment combat starts, before buff data turns secret")
        T.same(seen(party), { REGROWTH_ICON })
        T.same(places(party)[REGROWTH_ICON], regrowthPlace, "the \"has it\" icon doesn't move")
        Stubs.WithholdAuras(true)
        Stubs.SetUnitBuffs("party1", {})
        Stubs.RunTimers()
        T.same(seen(party), {})
        fight(false)
        T.same(seen(own), { MARK_ICON }, "back once the fight ends")
        T.same(seen(party), { MARK_ICON })
    end)

    it("hides a \"lacks it\" icon while a buff's name is secret or the game withholds buff data", function()
        start(ON, { lacks(MARK_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff(Stubs.SECRET, REGROWTH_1, "raid3") })
        Stubs.RunTimers()
        T.same(seen(frame), {}, "another caster's buff with a secret name")
        Stubs.SetUnitBuffs("raid1", {})
        Stubs.RunTimers()
        T.same(seen(frame), { MARK_ICON })
        Stubs.WithholdAuras(true)
        Stubs.Fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
        Stubs.RunTimers()
        T.same(seen(frame), {})
        Stubs.WithholdAuras(false)
        Stubs.Fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
        Stubs.RunTimers()
        T.same(seen(frame), { MARK_ICON })
    end)

    it("shows nothing with the master switch off, its default, and removes every icon when it goes off", function()
        local ns = start(nil, { has(REGROWTH_1), lacks(MARK_1) })
        T.eq(ns.Options:Get("groupFrameBuffs"), false)
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), {})
        ns.Options:Set("groupFrameBuffs", true)
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON, MARK_ICON })
        ns.Options:Set("groupFrameBuffs", false)
        Stubs.RunTimers()
        T.same(seen(frame), {})
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1, nil, { applications = 2 }) })
        Stubs.RunTimers()
        T.same(seen(frame), {}, "the game fills no \"has it\" icon either")
        ns.Options:Set("groupFrameBuffs", true)
        Stubs.RunTimers()
        fight(true)
        ns.Options:Set("groupFrameBuffs", false)
        Stubs.RunTimers()
        T.same(seen(frame), {}, "switched off in a fight")
    end)

    it("gives each tracked buff a fixed place in the list's order from the top right inwards, a gap where one isn't up", function()
        start(ON, { has(REJUVENATION), has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1), buff("Rejuvenation", REJUVENATION) })
        Stubs.RunTimers()
        T.same(seen(frame), { REJUVENATION_ICON, REGROWTH_ICON })
        T.same(places(frame), {
            [REJUVENATION_ICON] = { "TOPRIGHT", "TOPRIGHT", -2, -2 },
            [REGROWTH_ICON] = { "TOPRIGHT", "TOPRIGHT", -19, -2 },
        })
        local icon = shownIcons(frame)[1]
        T.eq(icon:GetWidth(), icon:GetHeight())
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(places(frame), { [REGROWTH_ICON] = { "TOPRIGHT", "TOPRIGHT", -19, -2 } }, "Rejuvenation's place left empty")
    end)

    -- The anchor each spot gives a lone 16-pixel icon, 2 pixels in from the frame's edges.
    local SPOT_PLACES = {
        TOPLEFT = { "TOPLEFT", "TOPLEFT", 2, -2 }, TOP = { "TOP", "TOP", 0, -2 },
        TOPRIGHT = { "TOPRIGHT", "TOPRIGHT", -2, -2 }, LEFT = { "LEFT", "LEFT", 2, 0 },
        CENTER = { "CENTER", "CENTER", 0, 0 }, RIGHT = { "RIGHT", "RIGHT", -2, 0 },
        BOTTOMLEFT = { "BOTTOMLEFT", "BOTTOMLEFT", 2, 2 }, BOTTOM = { "BOTTOM", "BOTTOM", 0, 2 },
        BOTTOMRIGHT = { "BOTTOMRIGHT", "BOTTOMRIGHT", -2, 2 },
    }
    for spot, place in pairs(SPOT_PLACES) do
        it("puts an icon at its spot on the frame: " .. spot, function()
            start(ON, { has(REGROWTH_1, true, spot), lacks(MARK_1, true, spot) })
            local frame = Stubs.NewGroupFrame("raid1")
            Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1), buff("Mark of the Wild", MARK_1) })
            Stubs.RunTimers()
            local spotPlaces = places(frame)
            if place[3] == 0 then
                T.same(spotPlaces, { [REGROWTH_ICON] = { place[1], place[2], -8.5, place[4] } },
                    "the middle column centres the row of both places")
            else
                T.same(spotPlaces, { [REGROWTH_ICON] = place })
            end
        end)
    end

    it("puts a line without a spot, or with one this QoL doesn't know, at the top right", function()
        start(ON, { has(REGROWTH_1), has(REJUVENATION, true, "SOMEWHERE") })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1), buff("Rejuvenation", REJUVENATION) })
        Stubs.RunTimers()
        T.same(places(frame), {
            [REGROWTH_ICON] = { "TOPRIGHT", "TOPRIGHT", -2, -2 },
            [REJUVENATION_ICON] = { "TOPRIGHT", "TOPRIGHT", -19, -2 },
        })
    end)

    it("lines up places on one spot in the list's order; switched-off and unknown lines take none", function()
        start(ON, { has(REGROWTH_1, true, "BOTTOMLEFT"), lacks(MARK_1, true, "CENTER"),
            has(REJUVENATION, false, "BOTTOMLEFT"), has(LIFEBLOOM, true, "BOTTOMLEFT"), has(GIFT, true, "CENTER"),
            has(REJUVENATION, true, "CENTER") }, {
            [REGROWTH_1] = DRUID[REGROWTH_1], [MARK_1] = DRUID[MARK_1], [LIFEBLOOM] = DRUID[LIFEBLOOM],
            [REJUVENATION] = DRUID[REJUVENATION] })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1), buff("Rejuvenation", REJUVENATION),
            buff("Lifebloom", LIFEBLOOM) })
        Stubs.RunTimers()
        T.same(places(frame), {
            [REGROWTH_ICON] = { "BOTTOMLEFT", "BOTTOMLEFT", 2, 2 },
            [LIFEBLOOM_ICON] = { "BOTTOMLEFT", "BOTTOMLEFT", 19, 2 },
            [MARK_ICON] = { "CENTER", "CENTER", -8.5, 0 },
            [REJUVENATION_ICON] = { "CENTER", "CENTER", 8.5, 0 },
        }, "a switched-off line and Gift of the Wild (unknown) take no place, the centre's row is centred")
        Stubs.SetUnitBuffs("raid1", { buff("Lifebloom", LIFEBLOOM), buff("Rejuvenation", REJUVENATION),
            buff("Mark of the Wild", MARK_1) })
        Stubs.RunTimers()
        T.same(places(frame), {
            [LIFEBLOOM_ICON] = { "BOTTOMLEFT", "BOTTOMLEFT", 19, 2 },
            [REJUVENATION_ICON] = { "CENTER", "CENTER", 8.5, 0 },
        }, "gaps where Regrowth and the Mark's \"lacks it\" icon would be")
    end)

    it("sizes every icon by the size slider", function()
        local ns = start(ON, { has(REGROWTH_1), lacks(MARK_1, true, "BOTTOM") })
        T.eq(ns.Options:Get("groupFrameBuffSize"), 16)
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        ns.Options:Set("groupFrameBuffSize", 24)
        Stubs.RunTimers()
        for _, icon in ipairs(shownIcons(frame)) do
            T.eq(icon:GetWidth(), 24)
            T.eq(icon:GetHeight(), 24)
        end
        T.eq(#shownIcons(frame), 2)
        T.same(places(frame)[REGROWTH_ICON], { "TOPRIGHT", "TOPRIGHT", -2, -2 })
    end)

    it("sets the countdown numbers' size from its slider, in the game's font, and waits out a fight", function()
        local ns = start(ON, { has(REGROWTH_1) })
        T.eq(ns.Options:Get("groupFrameBuffCountdownSize"), 10)
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        local text = cooldownOf(shownIcons(frame)[1]):GetCountdownFontString()
        T.same({ text:GetFont() }, { "Fonts\\ARIALN.TTF", 10, "OUTLINE" })
        ns.Options:Set("groupFrameBuffCountdownSize", 16)
        Stubs.RunTimers()
        T.eq(select(2, text:GetFont()), 16)
        fight(true)
        ns.Options:Set("groupFrameBuffCountdownSize", 12)
        Stubs.RunTimers()
        T.eq(select(2, text:GetFont()), 16, "the button can't be touched while buffs are secret")
        fight(false)
        T.eq(select(2, text:GetFont()), 12, "once readable again")
    end)

    it("adds the game's countdown numbers to \"has it\" icons once ticked, off by default", function()
        local ns = start(ON, { has(REGROWTH_1) })
        T.eq(ns.Options:Get("groupFrameBuffCountdown"), false)
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.truthy(cooldownOf(shownIcons(frame)[1]).hideCountdownNumbers)
        ns.Options:Set("groupFrameBuffCountdown", true)
        Stubs.RunTimers()
        T.falsy(cooldownOf(shownIcons(frame)[1]).hideCountdownNumbers)
        ns.GroupFrames.SetKind(1, "lacks")
        Stubs.SetUnitBuffs("raid1", {})
        Stubs.RunTimers()
        T.eq(sweep(shownIcons(frame)[1]), nil, "a \"lacks it\" icon has no cooldown to count down")
        ns.GroupFrames.SetKind(1, "has")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON })
        ns.Options:Set("groupFrameBuffCountdown", false)
        Stubs.RunTimers()
        T.truthy(cooldownOf(shownIcons(frame)[1]).hideCountdownNumbers)
    end)

    it("shows the time left as a sweep and the stacks above one", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        local now = Stubs.state().now
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1, nil, { duration = 21, expirationTime = now + 6 }) })
        Stubs.RunTimers()
        local icon = shownIcons(frame)[1]
        T.same(cooldownOf(icon).duration, { start = now - 15, seconds = 21 })
        T.eq(number(icon), nil, "one stack: no number")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1, nil, { applications = 3 }) })
        Stubs.RunTimers()
        icon = shownIcons(frame)[1]
        T.eq(number(icon), "3")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1, nil, { duration = 0, expirationTime = 0 }) })
        Stubs.RunTimers()
        T.eq(cooldownOf(shownIcons(frame)[1]).duration, nil, "no sweep for a buff without a duration")
    end)

    it("shows nothing for a switched-off line or a spell the character doesn't know", function()
        local ns = start(ON, { has(REGROWTH_1, false), has(REJUVENATION) }, { [REGROWTH_1] = DRUID[REGROWTH_1] })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1), buff("Rejuvenation", REJUVENATION) })
        Stubs.RunTimers()
        T.same(seen(frame), {})
        ns.GroupFrames.SetOn(1, true)
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON })
        ns.GroupFrames.SetOn(1, false)
        Stubs.RunTimers()
        T.same(seen(frame), {}, "switched off again")
        ns.GroupFrames.SetOn(1, true)
        ns.GroupFrames.Remove(1)
        Stubs.RunTimers()
        T.same(seen(frame), {}, "removed")
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
        start(ON, { has(REGROWTH_1), lacks(MARK_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        for _, holder in ipairs(ours(frame)) do T.falsy(holder.mouseEnabled) end
        T.eq(#shownIcons(frame), 2)
        for _, icon in ipairs(shownIcons(frame)) do T.falsy(icon.mouseEnabled) end
    end)

    it("follows when the game hands a frame to another member, in a fight too", function()
        start(ON, { has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.state().unitBuffs.raid1 = { buff("Regrowth", REGROWTH_1) }
        Stubs.state().unitBuffs.raid2 = {}
        Stubs.Fire("UNIT_AURA", "raid1")
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON })
        fight(true)
        Stubs.SetFrameUnit(frame, "raid2")
        Stubs.RunTimers()
        T.same(seen(frame), {})
        Stubs.SetUnitBuffs("raid2", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), { REGROWTH_ICON }, "raid2's buffs now count on it")
        Stubs.SetFrameUnit(frame, "raidpet2")
        Stubs.RunTimers()
        T.same(seen(frame), {}, "a frame with no member we draw for")
    end)

    it("puts \"has it\" icons on frames set up in a fight", function()
        start(ON, { has(REGROWTH_1), has(REJUVENATION) })
        fight(true)
        Stubs.state().unitBuffs.raid3 = { buff("Rejuvenation", REJUVENATION) }
        local frame = Stubs.NewGroupFrame("raid3")
        Stubs.RunTimers()
        T.same(places(frame), { [REJUVENATION_ICON] = { "TOPRIGHT", "TOPRIGHT", -19, -2 } })
        Stubs.SetUnitBuffs("raid3", {})
        Stubs.RunTimers()
        T.same(seen(frame), {})
    end)

    it("holds back a \"has it\" icon whose place changes in a fight, as the game forbids moving it, until the fight ends", function()
        local ns = start(ON, { has(REJUVENATION), has(REGROWTH_1) })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1), buff("Rejuvenation", REJUVENATION) })
        Stubs.RunTimers()
        fight(true)
        ns.GroupFrames.SetSpot(2, "BOTTOMLEFT")
        Stubs.RunTimers()
        T.same(seen(frame), { REJUVENATION_ICON }, "Regrowth not shown at its old place")
        fight(false)
        T.same(places(frame), {
            [REJUVENATION_ICON] = { "TOPRIGHT", "TOPRIGHT", -2, -2 },
            [REGROWTH_ICON] = { "BOTTOMLEFT", "BOTTOMLEFT", 2, 2 },
        })
    end)

    it("leaves the other \"has it\" icons showing when a line is switched off in a fight", function()
        local ns = start(ON, { has(REJUVENATION), has(REGROWTH_1, true, "BOTTOMLEFT") })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1), buff("Rejuvenation", REJUVENATION) })
        Stubs.RunTimers()
        fight(true)
        ns.GroupFrames.SetOn(1, false)
        Stubs.RunTimers()
        T.same(places(frame), { [REGROWTH_ICON] = { "BOTTOMLEFT", "BOTTOMLEFT", 2, 2 } })
        T.same(Stubs.state().errors, {})
    end)

    it("shows no \"has it\" icon and raises no error when the game can't make its aura container", function()
        start(ON, { has(REGROWTH_1), lacks(MARK_1) }, nil, { noAuraContainer = true })
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), { MARK_ICON })
        fight(true)
        T.same(seen(frame), {})
        T.same(Stubs.state().errors, {})
    end)

    -- GROUP_ROSTER_UPDATE and SPELLS_CHANGED are other features' too, so the spec can't tell ours.
    it("hears nothing while the switch is off, and the restriction state only while in a group", function()
        local ns = start(nil, { has(REGROWTH_1) }, nil, { solo = true })
        T.falsy(Stubs.Listens("ADDON_RESTRICTION_STATE_CHANGED"), "off")
        Stubs.SetGroup(true)
        Stubs.RunTimers()
        T.falsy(Stubs.Listens("ADDON_RESTRICTION_STATE_CHANGED"), "off, in a group")
        Stubs.SetGroup(false)
        ns.Options:Set("groupFrameBuffs", true)
        Stubs.RunTimers()
        T.falsy(Stubs.Listens("ADDON_RESTRICTION_STATE_CHANGED"), "solo")
        Stubs.SetGroup(true)
        Stubs.RunTimers()
        T.truthy(Stubs.Listens("ADDON_RESTRICTION_STATE_CHANGED"))
        T.falsy(Stubs.Listens("UNIT_AURA", "raid1"), "no buff of a \"has it\" line is read")
        ns.Options:Set("groupFrameBuffs", false)
        Stubs.RunTimers()
        T.falsy(Stubs.Listens("ADDON_RESTRICTION_STATE_CHANGED"), "switched off")
    end)

    it("hears members' buffs, death and connection only on, in a group, out of combat, with a \"lacks it\" line on", function()
        local EVENTS = { "UNIT_AURA", "UNIT_HEALTH", "UNIT_CONNECTION" }
        local function hears(unit)
            for _, event in ipairs(EVENTS) do
                if not Stubs.Listens(event, unit) then return false end
            end
            return true
        end
        local function hearsAny(unit)
            for _, event in ipairs(EVENTS) do
                if Stubs.Listens(event, unit) then return true end
            end
            return false
        end
        local ns = start(nil, { has(REGROWTH_1), lacks(MARK_1) }, nil, { solo = true })
        T.falsy(hearsAny("raid1"), "off")
        ns.Options:Set("groupFrameBuffs", true)
        Stubs.RunTimers()
        T.falsy(hearsAny("raid1"), "solo")
        Stubs.SetGroup(true)
        Stubs.RunTimers()
        for _, unit in ipairs({ "player", "party1", "party4", "raid1", "raid40" }) do T.truthy(hears(unit), unit) end
        ns.GroupFrames.SetOn(2, false)
        T.falsy(hearsAny("raid1"), "the \"lacks it\" line paused")
        ns.GroupFrames.SetOn(2, true)
        T.truthy(hears("raid1"))
        fight(true)
        T.falsy(hearsAny("raid1"), "in a fight")
        fight(false)
        T.truthy(hears("raid1"), "after the fight")
        Stubs.SetGroup(false)
        Stubs.RunTimers()
        T.falsy(hearsAny("raid1"), "left the group")
        Stubs.SetGroup(true)
        ns.Options:Set("groupFrameBuffs", false)
        Stubs.RunTimers()
        T.falsy(hearsAny("raid1"), "switched off")
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
        T.same(QoLDB.trackedBuffs, { newer, has(REGROWTH_1, true, "TOPRIGHT"), has(REJUVENATION, true, "TOPRIGHT") },
            "at the top right")
        ns.GroupFrames.SetSpot(3, "BOTTOMLEFT")
        ns.GroupFrames.SetSpot(2, "NOWHERE")
        T.same(ns.GroupFrames.Lines(), {
            { index = 2, name = "Regrowth", icon = REGROWTH_ICON, kind = "has", spot = "TOPRIGHT", on = true, known = true },
            { index = 3, name = "Rejuvenation", icon = REJUVENATION_ICON, kind = "has", spot = "BOTTOMLEFT", on = true,
                known = true },
        })
        ns.GroupFrames.SetOn(2, false)
        ns.GroupFrames.Remove(3)
        T.same(QoLDB.trackedBuffs, { newer, has(REGROWTH_1, false, "TOPRIGHT") })
    end)

    it("keeps the account's list across a reload and on a character that knows none of it", function()
        start(ON, { has(REGROWTH_1) })
        local saved = QoLDB
        local ns = start(saved.options, saved.trackedBuffs, {})
        local frame = Stubs.NewGroupFrame("raid1")
        Stubs.SetUnitBuffs("raid1", { buff("Regrowth", REGROWTH_1) })
        Stubs.RunTimers()
        T.same(seen(frame), {})
        T.same(ns.GroupFrames.Lines(), { { index = 1, name = "Regrowth", icon = REGROWTH_ICON, kind = "has",
            spot = "TOPRIGHT", on = true, known = false } })
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
