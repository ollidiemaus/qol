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

-- The placeholder icon of the row while it's unlocked: the game's question mark.
local QUESTION_MARK = 134400

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

-- Where a frame is: its one point, with the points of the frame it's placed on (if not UIParent)
-- spelled out after it.
local function placed(frame)
    T.eq(frame:GetNumPoints(), 1)
    local point = { frame:GetPoint(1) }
    if point[2] ~= _G.UIParent then
        local holder = point[2]
        point[2] = "holder"
        for index = 1, holder:GetNumPoints() do point[#point + 1] = { holder:GetPoint(index) } end
    end
    return point
end

-- The middle of the screen's lower half: the row's default spot.
local function defaultSpot()
    return { "CENTER", "holder", "CENTER", 0, 0,
        { "TOPLEFT", _G.UIParent, "LEFT", 0, 0 }, { "BOTTOMRIGHT", _G.UIParent, "BOTTOMRIGHT", 0, 0 } }
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

-- The player's own reminders: Thorns (ranks 1 and 3), Mark of the Wild (ranks 1 and 7) and Gift of
-- the Wild, as Forever numbers them, with made-up icons.
local THORNS_1, THORNS_3, MARK_1, MARK_7, GIFT = 467, 1075, 1126, 9885, 21849
local THORNS_ICON, MARK_ICON = 136104, 136078

-- The client has data for these spells on every character.
local function gameSpells()
    local spells = Stubs.state().gameSpells
    spells[THORNS_1] = { name = "Thorns", texture = THORNS_ICON }
    spells[THORNS_3] = { name = "Thorns", texture = THORNS_ICON }
    spells[MARK_1] = { name = "Mark of the Wild", texture = MARK_ICON }
    spells[MARK_7] = { name = "Mark of the Wild", texture = MARK_ICON }
    spells[GIFT] = { name = "Gift of the Wild", texture = 136038 }
end

-- The character knows these spells ({ id, name, rank } each).
local function learn(spells)
    for _, s in ipairs(spells) do
        Stubs.state().spells[s[1]] = { name = s[2], texture = s[2] == "Thorns" and THORNS_ICON or MARK_ICON,
            subtext = "Rank " .. s[3] }
    end
end

-- Loads the addon on Forever, with the account's own reminders saved (reminders: { { spell, on } }),
-- the character knowing known, and logs in.
local function startOwn(savedOptions, reminders, known)
    local ns = Stubs.LoadAddon()
    knowSpells(ENGLISH)
    gameSpells()
    learn(known or {})
    _G.QoLDB = { options = savedOptions, reminders = reminders }
    Stubs.Fire("ADDON_LOADED", "QoL")
    Stubs.Fire("PLAYER_LOGIN")
    Stubs.Fire("PLAYER_ENTERING_WORLD")
    Stubs.RunTimers()
    return ns
end

local DRUID = { { THORNS_1, "Thorns", 1 }, { MARK_1, "Mark of the Wild", 1 } }

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
        T.same(placed(frame), defaultSpot())
    end)

    it("keeps a dragged position, relative to the screen's centre, across a reload", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        ns.Reminders.SetUnlocked(true)
        Stubs.RunTimers()
        Stubs.DragTo(row(ns), 1060, 340)
        T.same(placed(row(ns)), { "CENTER", _G.UIParent, "CENTER", 100, -200 })
        ns.Reminders.SetUnlocked(false)
        Stubs.RunTimers()
        T.same(placed(row(ns)), { "CENTER", _G.UIParent, "CENTER", 100, -200 }, "where it was left")
        ns = start(QoLDB.options)
        T.same(seen(ns), { ICONS.wellFed })
        T.same(placed(row(ns)), { "CENTER", _G.UIParent, "CENTER", 100, -200 }, "after a reload")
    end)

    it("sizes its icons by the icon size option, 40 by default", function()
        local ns = start({ reminders = true, reminderWellFed = true, reminderWellRested = true })
        T.same({ shownIcons(ns)[1]:GetSize() }, { 40, 40 })
        ns.Options:Set("reminderIconSize", 30)
        Stubs.RunTimers()
        for _, icon in ipairs(shownIcons(ns)) do T.same({ icon:GetSize() }, { 30, 30 }) end
        T.same(offsets(ns), { -17, 17 })
        T.same({ row(ns):GetSize() }, { 64, 30 })
        ns = start(QoLDB.options)
        T.same({ shownIcons(ns)[1]:GetSize() }, { 30, 30 }, "after a reload")
    end)

    it("can't be dragged while locked", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        T.falsy(pcall(Stubs.DragTo, row(ns), 1060, 340))
        T.same(placed(row(ns)), defaultSpot())
    end)

    it("goes back to the default spot with Reset position", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        ns.Reminders.SetUnlocked(true)
        Stubs.RunTimers()
        Stubs.DragTo(row(ns), 1060, 340)
        ns.Reminders.ResetPosition()
        Stubs.RunTimers()
        T.same(placed(row(ns)), defaultSpot())
        ns = start(QoLDB.options)
        T.same(placed(row(ns)), defaultSpot(), "after a reload too")
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

    it("shows the player's own reminder while its buff is missing, after the presets", function()
        local ns = startOwn({ reminders = true, reminderWellFed = true },
            { { spell = THORNS_3, on = true }, { spell = MARK_1, on = true } }, DRUID)
        T.same(seen(ns), { ICONS.wellFed, THORNS_ICON, MARK_ICON })
        Stubs.SetBuffs({ buff("Thorns", THORNS_3) })
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed, MARK_ICON })
    end)

    it("counts a buff at any rank, from any caster", function()
        local ns = startOwn({ reminders = true }, { { spell = THORNS_3, on = true } }, DRUID)
        T.same(seen(ns), { THORNS_ICON }, "rank 3 saved, rank 1 known")
        Stubs.SetBuffs({ buff("Thorns", 9910) })
        Stubs.RunTimers()
        T.same(seen(ns), {}, "another druid's rank 6")
        Stubs.SetBuffs({ buff("Thorns", THORNS_1) })
        Stubs.RunTimers()
        T.same(seen(ns), {}, "a lower-level friend's rank 1")
    end)

    it("counts the group version", function()
        local ns = startOwn({ reminders = true }, { { spell = MARK_7, on = true } }, DRUID)
        T.same(seen(ns), { MARK_ICON })
        Stubs.SetBuffs({ buff("Gift of the Wild", GIFT) })
        Stubs.RunTimers()
        T.same(seen(ns), {})
    end)

    it("shows nothing for a switched-off reminder of the player's own", function()
        local ns = startOwn({ reminders = true }, { { spell = THORNS_3, on = false }, { spell = MARK_1, on = true } },
            DRUID)
        T.same(seen(ns), { MARK_ICON })
        ns.Reminders.SetOn(2, false)
        Stubs.RunTimers()
        T.same(seen(ns), {})
        ns.Reminders.SetOn(1, true)
        Stubs.RunTimers()
        T.same(seen(ns), { THORNS_ICON })
        T.same(QoLDB.reminders, { { spell = THORNS_3, on = true }, { spell = MARK_1, on = false } })
    end)

    it("leaves out a reminder for a spell the character doesn't know, until it learns it", function()
        local ns = startOwn({ reminders = true }, { { spell = THORNS_3, on = true } })
        T.same(seen(ns), {})
        T.same(ns.Reminders.Own(), { { index = 1, name = "Thorns", icon = THORNS_ICON, on = true, known = false } })
        learn({ { THORNS_1, "Thorns", 1 } })
        Stubs.Fire("SPELLS_CHANGED")
        Stubs.RunTimers()
        T.same(seen(ns), { THORNS_ICON })
        T.same(ns.Reminders.Own(), { { index = 1, name = "Thorns", icon = THORNS_ICON, on = true, known = true } })
    end)

    it("adds a spell from the cursor, once, and nothing else", function()
        local ns = startOwn({ reminders = true }, nil, DRUID)
        local state = Stubs.state()
        state.cursorInfo = { "spell", 1, "spell", THORNS_1, THORNS_1 }
        T.truthy(ns.Reminders.AddFromCursor())
        T.eq(state.cursorInfo, nil, "taken off the cursor")
        Stubs.RunTimers()
        T.same(seen(ns), { THORNS_ICON })
        state.cursorInfo = { "spell", 1, "spell", THORNS_3, THORNS_3 }
        T.falsy(ns.Reminders.AddFromCursor(), "another rank of a spell in the list")
        state.cursorInfo = { "item", 4540, "item:4540" }
        T.falsy(ns.Reminders.AddFromCursor())
        state.cursorInfo = nil
        T.falsy(ns.Reminders.AddFromCursor())
        state.cursorInfo = { "spell", 1, "spell", MARK_1, MARK_1 }
        T.truthy(ns.Reminders.AddFromCursor())
        T.same(QoLDB.reminders, { { spell = THORNS_1, on = true }, { spell = MARK_1, on = true } })
    end)

    it("removes a reminder of the player's own", function()
        local ns = startOwn({ reminders = true }, { { spell = THORNS_3, on = true }, { spell = MARK_1, on = true } },
            DRUID)
        ns.Reminders.Remove(1)
        Stubs.RunTimers()
        T.same(seen(ns), { MARK_ICON })
        T.same(QoLDB.reminders, { { spell = MARK_1, on = true } })
    end)

    it("keeps the account's list and its order across a reload and on another character", function()
        local ns = startOwn({ reminders = true }, nil, DRUID)
        local state = Stubs.state()
        for _, id in ipairs({ MARK_1, THORNS_1 }) do
            state.cursorInfo = { "spell", 1, "spell", id, id }
            ns.Reminders.AddFromCursor()
        end
        local saved = QoLDB
        ns = startOwn(saved.options, saved.reminders, DRUID)
        T.same(seen(ns), { MARK_ICON, THORNS_ICON })
        ns = startOwn(saved.options, saved.reminders)
        T.same(seen(ns), {}, "a warrior knows neither")
        T.eq(#ns.Reminders.Own(), 2)
    end)

    it("hears the player's buffs with only a reminder of the player's own on", function()
        startOwn({ reminders = true }, { { spell = THORNS_3, on = true } }, DRUID)
        T.truthy(Stubs.Listens("UNIT_AURA", "player"))
    end)

    it("hears nothing of the player's buffs on a character that knows none of the player's own spells", function()
        startOwn({ reminders = true }, { { spell = THORNS_3, on = true } })
        T.falsy(Stubs.Listens("UNIT_AURA", "player"))
        learn({ { THORNS_1, "Thorns", 1 } })
        Stubs.Fire("SPELLS_CHANGED")
        Stubs.RunTimers()
        T.truthy(Stubs.Listens("UNIT_AURA", "player"), "once it learns one")
    end)

    it("keeps a saved reminder it doesn't understand, and leaves it out", function()
        local newer = { aura = 12345, on = true }
        local ns = startOwn({ reminders = true }, { newer, { spell = MARK_1, on = true } }, DRUID)
        T.same(seen(ns), { MARK_ICON })
        local own = ns.Reminders.Own()
        T.eq(#own, 1)
        T.eq(own[1].index, 2)
        ns.Reminders.SetOn(own[1].index, false)
        local state = Stubs.state()
        state.cursorInfo = { "spell", 1, "spell", THORNS_1, THORNS_1 }
        ns.Reminders.AddFromCursor()
        ns.Reminders.Remove(1)
        T.same(QoLDB.reminders, { newer, { spell = MARK_1, on = false }, { spell = THORNS_1, on = true } },
            "a newer QoL's entry stays, and Remove doesn't take it")
    end)

    it("shows placeholder icons to drag while unlocked, even with nothing missing, and locks again", function()
        local ns = start()
        T.same(seen(ns), {})
        ns.Reminders.SetUnlocked(true)
        Stubs.RunTimers()
        T.truthy(ns.Reminders.IsUnlocked())
        T.same(seen(ns), { QUESTION_MARK, QUESTION_MARK, QUESTION_MARK })
        local frame = row(ns)
        T.truthy(frame:IsMouseClickEnabled())
        T.truthy(frame:IsMovable())
        T.truthy(frame.scripts.OnDragStart and frame.scripts.OnDragStop)
        ns.Reminders.SetUnlocked(false)
        Stubs.RunTimers()
        T.falsy(ns.Reminders.IsUnlocked())
        T.same(seen(ns), {})
        T.falsy(frame:IsMouseClickEnabled())
    end)

    it("shows the reminders again once locked, and takes no mouse input", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        ns.Reminders.SetUnlocked(true)
        Stubs.RunTimers()
        T.same(seen(ns), { QUESTION_MARK, QUESTION_MARK, QUESTION_MARK })
        ns.Reminders.SetUnlocked(false)
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
        for _, frame in ipairs({ row(ns), shownIcons(ns)[1] }) do
            T.falsy(frame:IsMouseMotionEnabled())
            T.falsy(frame:IsMouseClickEnabled())
        end
    end)

    for _, client in ipairs({ "retail", "classicEra" }) do
        it("shows nothing on " .. client, function()
            local ns = start({ reminders = true, reminderWellFed = true }, { client = client })
            T.same(seen(ns), {})
            T.falsy(Stubs.Listens("UNIT_AURA", "player"))
        end)
    end
end)
