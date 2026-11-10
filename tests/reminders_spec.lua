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

-- The hands' inventory slots, and items to hold in them with made-up icons: weapons (class 2), a
-- fishing pole (weapon subclass 20), a shield and a held item (armor, class 4).
local MAIN_HAND, OFF_HAND = 16, 17
local SWORD, DAGGER, POLE, SHIELD, HELD = 2131, 2632, 6256, 2129, 4984
local SWORD_ICON, DAGGER_ICON = 135274, 135650
local ITEMS = {
    [SWORD] = { texture = SWORD_ICON, classID = 2, subclassID = 7 },
    [DAGGER] = { texture = DAGGER_ICON, classID = 2, subclassID = 15 },
    [POLE] = { texture = 132932, classID = 2, subclassID = 20 },
    [SHIELD] = { texture = 134955, classID = 4, subclassID = 6 },
    [HELD] = { texture = 134333, classID = 4, subclassID = 0 },
}

-- Loads the addon on Forever holding equipped ({ [slot] = item }), its hands' weapon buffs
-- weaponBuffs ({ [0] main hand, [1] off hand }), and logs in.
local function armed(savedOptions, equipped, weaponBuffs)
    local ns = Stubs.LoadAddon()
    knowSpells(ENGLISH)
    local state = Stubs.state()
    for id, info in pairs(ITEMS) do state.items[id] = info end
    for slot, id in pairs(equipped) do state.equipped[slot] = id end
    state.weaponBuffs = weaponBuffs or {}
    Stubs.Login(savedOptions)
    return ns
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

    it("hides every reminder while resting, with that box ticked, and shows them again after", function()
        local ns = startOwn({ reminders = true, reminderWellFed = true, reminderHideResting = true },
            { { spell = THORNS_3, on = true } }, DRUID)
        T.same(seen(ns), { ICONS.wellFed, THORNS_ICON })
        Stubs.SetCharacter({ resting = true }, "PLAYER_UPDATE_RESTING")
        Stubs.RunTimers()
        T.same(seen(ns), {})
        Stubs.SetCharacter({ resting = false }, "PLAYER_UPDATE_RESTING")
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed, THORNS_ICON })
    end)

    it("hides every reminder while mounted, with that box ticked, and shows them again after", function()
        local ns = start({ reminders = true, reminderWellFed = true, reminderHideMounted = true })
        Stubs.SetCharacter({ mounted = true }, "PLAYER_MOUNT_DISPLAY_CHANGED")
        Stubs.RunTimers()
        T.same(seen(ns), {})
        Stubs.SetCharacter({ mounted = false }, "PLAYER_MOUNT_DISPLAY_CHANGED")
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
    end)

    it("hides every reminder while dead or a ghost, by default, and shows them again once alive", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        Stubs.SetCharacter({ dead = true }, "PLAYER_DEAD")
        Stubs.RunTimers()
        T.same(seen(ns), {})
        Stubs.SetCharacter({}, "PLAYER_ALIVE") -- released: a ghost, still dead
        Stubs.RunTimers()
        T.same(seen(ns), {})
        Stubs.SetCharacter({ dead = false }, "PLAYER_UNGHOST")
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
    end)

    it("hides every reminder on a flight path, by default, and shows them again on landing", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        Stubs.SetCharacter({ onTaxi = true }, "PLAYER_CONTROL_LOST")
        Stubs.RunTimers()
        T.same(seen(ns), {})
        Stubs.SetCharacter({ onTaxi = false }, "PLAYER_CONTROL_GAINED")
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
    end)

    it("hides them too when the game says it's a flight path only after taking control", function()
        local ns = start({ reminders = true, reminderWellFed = true })
        Stubs.SetCharacter({}, "PLAYER_CONTROL_LOST")
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
        Stubs.SetCharacter({ onTaxi = true }, "UPDATE_BONUS_ACTIONBAR")
        Stubs.RunTimers()
        T.same(seen(ns), {})
    end)

    it("shows reminders while dead or flying with that box unticked", function()
        local ns = start({ reminders = true, reminderWellFed = true, reminderHideDeadOrFlying = false })
        Stubs.SetCharacter({ dead = true }, "PLAYER_DEAD")
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
        Stubs.SetCharacter({ dead = false, onTaxi = true }, "PLAYER_CONTROL_LOST")
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
    end)

    it("hides every reminder in combat, with that box ticked, and shows them again after", function()
        local ns = start({ reminders = true, reminderWellFed = true, reminderHideCombat = true })
        Stubs.SetCombat(true)
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.RunTimers()
        T.same(seen(ns), {})
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
    end)

    it("shows a buff lost in combat as a reminder with that box unticked, while buff data is readable", function()
        local ns = start({ reminders = true, reminderWellFed = true }, { buffs = { buff("Well Fed", WELL_FED) } })
        T.same(seen(ns), {})
        Stubs.SetCombat(true)
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.SetBuffs({})
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
    end)

    it("hides only the experience reminders at maximum level, by default, from the level-up on", function()
        local ns = startOwn({ reminders = true, reminderWellFed = true, reminderWellRested = true },
            { { spell = THORNS_3, on = true } }, DRUID)
        Stubs.SetCharacter({ level = 59, maxLevel = 60 }, "PLAYER_LEVEL_UP", 59)
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed, ICONS.wellRested, THORNS_ICON })
        -- The game may give the new level only after its event.
        Stubs.SetCharacter({}, "PLAYER_LEVEL_UP", 60)
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed, THORNS_ICON })
    end)

    it("hides the experience reminders of a character at maximum level from login", function()
        local ns = start({ reminders = true, reminderWellFed = true, reminderWellRested = true })
        Stubs.SetCharacter({ level = 60 })
        Stubs.Fire("PLAYER_ENTERING_WORLD")
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed })
    end)

    it("shows the experience reminders at maximum level with that box unticked", function()
        local ns = start({ reminders = true, reminderWellRested = true, reminderHideMaxLevel = false })
        Stubs.SetCharacter({ level = 60 }, "PLAYER_LEVEL_UP", 60)
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellRested })
    end)

    it("starts hiding reminders while dead or on a flight path and at maximum level only", function()
        local ns = start()
        local ticked = {}
        for _, key in ipairs({ "reminderHideResting", "reminderHideCombat", "reminderHideMounted",
            "reminderHideDeadOrFlying", "reminderHideMaxLevel" }) do
            ticked[#ticked + 1] = ns.Options:Get(key)
        end
        T.same(ticked, { false, false, false, true, true })
    end)

    it("hears a Hide reminders box's events only while it's ticked and a reminder is on", function()
        local ns = start({ reminderWellFed = true })
        T.falsy(Stubs.Listens("PLAYER_DEAD"))
        T.falsy(Stubs.Listens("PLAYER_UPDATE_RESTING"))
        ns.Options:Set("reminders", true)
        T.truthy(Stubs.Listens("PLAYER_DEAD"))
        T.truthy(Stubs.Listens("PLAYER_LEVEL_UP"))
        T.falsy(Stubs.Listens("PLAYER_UPDATE_RESTING"))
        ns.Options:Set("reminderHideResting", true)
        T.truthy(Stubs.Listens("PLAYER_UPDATE_RESTING"))
        ns.Options:Set("reminderHideDeadOrFlying", false)
        T.falsy(Stubs.Listens("PLAYER_DEAD"))
        ns.Options:Set("reminders", false)
        T.falsy(Stubs.Listens("PLAYER_UPDATE_RESTING"))
        T.falsy(Stubs.Listens("PLAYER_LEVEL_UP"))
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

    it("shows a hand's weapon buff reminder while that hand has none, with the weapon's icon", function()
        local ns = armed({ reminders = true, reminderMainHand = true, reminderOffHand = true },
            { [MAIN_HAND] = SWORD, [OFF_HAND] = DAGGER })
        T.same(seen(ns), { SWORD_ICON, DAGGER_ICON })
        Stubs.SetWeaponBuffs({ [0] = true })
        Stubs.RunTimers()
        T.same(seen(ns), { DAGGER_ICON }, "the main hand's buff")
        Stubs.SetWeaponBuffs({ [0] = true, [1] = true })
        Stubs.RunTimers()
        T.same(seen(ns), {})
        Stubs.SetWeaponBuffs({ [1] = true })
        Stubs.RunTimers()
        T.same(seen(ns), { SWORD_ICON }, "the main hand's ran out")
    end)

    it("doesn't count a weapon's enchantment as a weapon buff", function()
        local ns = armed({ reminders = true, reminderMainHand = true }, { [MAIN_HAND] = SWORD },
            { [0] = "permanent" })
        T.same(seen(ns), { SWORD_ICON })
    end)

    it("shows the off hand's reminder only while the off hand holds a weapon", function()
        local ns = armed({ reminders = true, reminderMainHand = true, reminderOffHand = true },
            { [MAIN_HAND] = SWORD, [OFF_HAND] = SHIELD })
        T.same(seen(ns), { SWORD_ICON }, "a shield")
        Stubs.Equip(OFF_HAND, HELD)
        Stubs.RunTimers()
        T.same(seen(ns), { SWORD_ICON }, "a held item")
        Stubs.Equip(OFF_HAND, nil)
        Stubs.RunTimers()
        T.same(seen(ns), { SWORD_ICON }, "nothing, as with a two-handed weapon")
        Stubs.Equip(OFF_HAND, DAGGER)
        Stubs.RunTimers()
        T.same(seen(ns), { SWORD_ICON, DAGGER_ICON })
    end)

    it("follows the weapon equipped", function()
        local ns = armed({ reminders = true, reminderMainHand = true }, { [MAIN_HAND] = SWORD })
        Stubs.Equip(MAIN_HAND, DAGGER)
        Stubs.RunTimers()
        T.same(seen(ns), { DAGGER_ICON })
        Stubs.Equip(MAIN_HAND, nil)
        Stubs.RunTimers()
        T.same(seen(ns), {}, "no weapon, nothing to buff")
    end)

    it("shows neither hand's reminder with a fishing pole", function()
        local ns = armed({ reminders = true, reminderMainHand = true, reminderOffHand = true },
            { [MAIN_HAND] = POLE, [OFF_HAND] = DAGGER })
        T.same(seen(ns), {})
        Stubs.Equip(MAIN_HAND, SWORD)
        Stubs.RunTimers()
        T.same(seen(ns), { SWORD_ICON, DAGGER_ICON })
    end)

    it("hides everything while a weapon buff is secret", function()
        local ns = armed({ reminders = true, reminderWellFed = true, reminderMainHand = true },
            { [MAIN_HAND] = SWORD }, { [0] = Stubs.SECRET })
        T.same(seen(ns), {})
        Stubs.SetWeaponBuffs({})
        Stubs.RunTimers()
        T.same(seen(ns), { ICONS.wellFed, SWORD_ICON })
    end)

    it("hears weapon buffs change only while a weapon buff reminder is on", function()
        local ns = armed({ reminders = true, reminderWellFed = true }, { [MAIN_HAND] = SWORD })
        T.falsy(Stubs.Listens("WEAPON_ENCHANT_CHANGED"))
        ns.Options:Set("reminderOffHand", true)
        T.truthy(Stubs.Listens("WEAPON_ENCHANT_CHANGED"))
        ns.Options:Set("reminders", false)
        T.falsy(Stubs.Listens("WEAPON_ENCHANT_CHANGED"))
    end)

    it("starts with the weapon buff reminders off, after the other presets", function()
        local ns = armed({ reminders = true }, { [MAIN_HAND] = SWORD, [OFF_HAND] = DAGGER })
        T.same(seen(ns), {})
        local keys = {}
        for _, preset in ipairs(ns.Reminders.PRESETS) do keys[#keys + 1] = preset.key end
        T.same(keys, { "reminderWellFed", "reminderWellRested", "reminderCampBenefits", "reminderMainHand",
            "reminderOffHand" })
    end)

    for _, client in ipairs({ "retail", "classicEra" }) do
        it("shows nothing on " .. client, function()
            local ns = start({ reminders = true, reminderWellFed = true }, { client = client })
            T.same(seen(ns), {})
            T.falsy(Stubs.Listens("UNIT_AURA", "player"))
        end)
    end
end)
