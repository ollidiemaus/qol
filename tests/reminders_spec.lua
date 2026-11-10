local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Forever's spells for the presets, as its client names them in English, and a made-up icon each.
local WELL_FED, WELL_FED_OTHER, WELL_RESTED, CAMP = 19705, 1248406, 1225478, 1229741
local ICONS = { wellFed = 136000, wellRested = 136001, campBenefits = 136002 }

local function knowSpells(names)
    local spells = Stubs.state().gameSpells
    spells[WELL_FED] = { name = names.wellFed, texture = ICONS.wellFed }
    spells[WELL_FED_OTHER] = { name = names.wellFed, texture = 133943 }
    spells[WELL_RESTED] = { name = names.wellRested, texture = ICONS.wellRested }
    spells[CAMP] = { name = names.campBenefits, texture = ICONS.campBenefits }
end

local ENGLISH = { wellFed = "Well Fed", wellRested = "Well Rested", campBenefits = "Camp Benefits" }

-- Loads the addon on Forever with the presets' spell data and logs in.
local function start(savedOptions, options)
    options = options or {}
    local ns = Stubs.LoadAddon({ client = options.client, locale = options.locale })
    knowSpells(options.names or ENGLISH)
    Stubs.state().buffs = options.buffs or {}
    Stubs.Login(savedOptions)
    return ns
end

local function buff(name, spellId) return { name = name, spellId = spellId } end

-- The reminder row's frames: our own, on UIParent, holding the reminder icons.
local function row(ns)
    return ns.Reminders.row
end

-- The icons the player sees in the reminder row, left to right.
local function shownIcons(ns)
    local frame = row(ns)
    if not frame or not frame:IsVisible() then return {} end
    local icons = {}
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsShown() then icons[#icons + 1] = child end
    end
    table.sort(icons, function(a, b) return a:PointFor("CENTER")[4] < b:PointFor("CENTER")[4] end)
    return icons
end

-- Each icon's texture, left to right.
local function seen(ns)
    local textures = {}
    for index, icon in ipairs(shownIcons(ns)) do textures[index] = icon.Icon.texture end
    return textures
end

-- How far each icon's middle is from the row's, left to right.
local function offsets(ns)
    local xs = {}
    for index, icon in ipairs(shownIcons(ns)) do
        local point = icon:PointFor("CENTER")
        T.eq(point[2], row(ns))
        T.eq(point[3], "CENTER")
        xs[index] = point[4]
    end
    return xs
end

-- The Cooldown Manager's overlay on an icon.
local function overlay(icon)
    for _, region in ipairs({ icon:GetRegions() }) do
        if region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then return region end
    end
    error("an icon without the overlay")
end

describe("reminders", function()
    it("shows a switched-on preset while its buff is missing, and drops it once the buff is there", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        T.same(seen(ns), { ICONS.wellFed })
        Stubs.SetBuffs({ buff("Well Fed", WELL_FED) })
        Stubs.RunTimers()
        T.same(seen(ns), {})
        Stubs.SetBuffs({})
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
    end)

    it("counts any Well Fed buff, whichever food it came from", function()
        local ns = start({ reminders = true, reminderWellFed = true }, { buffs = { buff("Well Fed", WELL_FED_OTHER) } })
        T.same(seen(ns), {})
    end)

    it("goes by the client's names, in any language", function()
        local names = { wellFed = "Satt", wellRested = "Gut ausgeruht", campBenefits = "Lagervorteile" }
        local ns = start({ reminders = true, reminderWellFed = true, reminderWellRested = true,
            reminderCampBenefits = true }, { locale = "deDE", names = names,
            buffs = { buff("Satt", WELL_FED_OTHER), buff("Lagervorteile", CAMP) } })
        T.same(seen(ns), { ICONS.wellRested })
        Stubs.SetBuffs({ buff("Well Fed", WELL_FED) })
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed, ICONS.wellRested, ICONS.campBenefits }, "an English name isn't Satt")
    end)

    it("shows nothing for a switched-off preset, nor with the Reminders switch off", function()
        local ns = start({ reminders = true, reminderWellFed = true, reminderWellRested = true })
        T.same(seen(ns), { ICONS.wellFed, ICONS.wellRested })
        ns.Options:Set("reminderWellFed", false)
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellRested })
        ns.Options:Set("reminders", false)
        Stubs.RunTimers()
        T.same(seen(ns), {})
        ns.Options:Set("reminders", true)
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellRested })
    end)

    it("starts with every reminder off", function()
        local ns = start()
        T.same(seen(ns), {})
        ns.Options:Set("reminders", true)
        Stubs.RunTimers()
        T.same(seen(ns), {}, "the presets are off too")
    end)

    it("hides everything while the game withholds buff data, and shows it again once it's readable", function()
        local ns = start({ reminders = true, reminderWellFed = true, reminderWellRested = true })
        Stubs.WithholdAuras(true)
        Stubs.SetCombat(true)
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.RunTimers()
        T.same(seen(ns), {})
        Stubs.SetBuffs({ buff("Well Fed", WELL_FED) })
        Stubs.RunTimers()
        T.same(seen(ns), {}, "a buff changing reads nothing")
        Stubs.WithholdAuras(false)
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellRested }, "what's readable after combat, nothing kept from before")
    end)

    it("hides everything while a buff's name is secret", function()
        local ns = start({ reminders = true, reminderWellFed = true, reminderWellRested = true })
        Stubs.SetBuffs({ buff("Well Fed", WELL_FED), buff(Stubs.SECRET, 12345) })
        Stubs.RunTimers()
        T.same(seen(ns), {})
        Stubs.SetBuffs({ buff("Well Fed", WELL_FED) })
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellRested })
    end)

    it("keeps the row centred in the presets' order as icons come and go", function()
        local ns = start({ reminders = true, reminderWellFed = true, reminderWellRested = true,
            reminderCampBenefits = true })
        T.same(seen(ns), { ICONS.wellFed, ICONS.wellRested, ICONS.campBenefits })
        T.same(offsets(ns), { -44, 0, 44 })
        Stubs.SetBuffs({ buff("Well Rested", WELL_RESTED) })
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed, ICONS.campBenefits })
        T.same(offsets(ns), { -22, 22 })
        Stubs.SetBuffs({ buff("Well Rested", WELL_RESTED), buff("Camp Benefits", CAMP) })
        Stubs.RunTimers()
        T.same(offsets(ns), { 0 })
    end)

    it("sits centred in the screen's lower half", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        local frame = row(ns)
        T.eq(frame:GetParent(), _G.UIParent)
        T.same({ frame:GetPoint(1) }, { "TOPLEFT", _G.UIParent, "LEFT", 0, 0 })
        T.same({ frame:GetPoint(2) }, { "BOTTOMRIGHT", _G.UIParent, "BOTTOMRIGHT", 0, 0 })
    end)

    it("looks like the Cooldown Manager's icons, and loses the border with the page's checkbox", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        local icon = shownIcons(ns)[1]
        T.eq(icon.Icon:GetAtlas(), nil)
        local mask = next(icon.Icon.masks)
        T.eq(mask:GetAtlas(), "UI-HUD-CoolDownManager-Mask")
        T.truthy(overlay(icon):IsShown())
        ns.Options:Set("hideCooldownManagerBorders", true)
        Stubs.RunTimers()
        T.falsy(overlay(shownIcons(ns)[1]):IsShown())
        ns.Options:Set("hideCooldownManagerBorders", false)
        Stubs.RunTimers()
        T.truthy(overlay(shownIcons(ns)[1]):IsShown())
    end)

    it("lets the mouse through", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        for _, frame in ipairs({ row(ns), shownIcons(ns)[1] }) do
            T.falsy(frame:IsMouseMotionEnabled())
            T.falsy(frame:IsMouseClickEnabled())
        end
    end)

    it("changes in combat while buff data is readable", function()
        local ns = start({ reminders = true, reminderWellFed = true, reminderWellRested = true })
        Stubs.SetCombat(true)
        Stubs.SetBuffs({ buff("Well Fed", WELL_FED) })
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellRested })
        T.same(offsets(ns), { 0 })
        T.same(Stubs.state().errors, {})
    end)

    it("hears the player's buffs only while a reminder is on", function()
        local ns = start()
        T.falsy(Stubs.Listens("UNIT_AURA", "player"))
        ns.Options:Set("reminders", true)
        ns.Options:Set("reminderWellFed", true)
        T.truthy(Stubs.Listens("UNIT_AURA", "player"))
        ns.Options:Set("reminders", false)
        T.falsy(Stubs.Listens("UNIT_AURA", "player"))
    end)

    it("marks Well Rested as being about experience", function()
        local ns = start()
        local marked = {}
        for _, preset in ipairs(ns.Reminders.PRESETS) do
            if preset.experience then marked[#marked + 1] = preset.key end
        end
        T.same(marked, { "reminderWellRested" })
    end)

    for _, client in ipairs({ "retail", "classicEra" }) do
        it("shows nothing on " .. client, function()
            local ns = start({ reminders = true, reminderWellFed = true }, { client = client })
            T.same(seen(ns), {})
            T.falsy(Stubs.Listens("UNIT_AURA", "player"))
        end)
    end
end)
