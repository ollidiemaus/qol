local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local FIREBALL, BLINK, FROSTBOLT, UNKNOWN = 133, 1953, 116, 999
local HEARTHSTONE, TOY, MOUNT, MOUNT_SPELL = 6948, 54452, 6, 458

-- A mage with a few spells, a hearthstone, a toy, a mount and a macro.
local function mage(state)
    state.spells[FIREBALL] = { name = "Fireball", texture = 135812 }
    state.spells[BLINK] = { name = "Blink", texture = 135736 }
    state.spells[FROSTBOLT] = { name = "Frostbolt", texture = 135846 }
    state.items[HEARTHSTONE] = { name = "Hearthstone", texture = 134414, count = 1 }
    state.items[TOY] = { name = "Toy Train Set", texture = 133000, count = 0 }
    state.toys[TOY] = {}
    state.mounts[MOUNT] = { name = "Brown Horse", spellID = MOUNT_SPELL, texture = 132261 }
    state.macros = { { name = "Pull", texture = 134400 } }
end

local function spell(id) return { kind = "spell", id = id } end
local function item(id) return { kind = "item", id = id } end

local function ringOf(entries, mouse, stick)
    return { entries = entries, mouse = mouse, stick = stick }
end

-- Logs in with the options and rings given (the ring on by default), as the mage unless setup
-- says otherwise.
local function start(rings, options, setup)
    local ns = Stubs.LoadAddon()
    mage(Stubs.state())
    if setup then setup(Stubs.state()) end
    Stubs.Login(options or { ring = true }, rings)
    return ns
end

local function set(ns, key, value)
    ns.Options:Set(key, value)
    Stubs.RunTimers()
end

local function override(key)
    local entry = Stubs.state().overrides[key]
    return entry and entry.command
end

local function attribute(name) return QoLRingButton:GetAttribute(name) end

-- The ring's art under the secure header, and the frame that takes the camera stick.
local function ringArt()
    for _, region in ipairs(Stubs.state().regions) do
        if region.parent == QoLRing and region.slots then return region end
    end
end

local function catcher()
    for _, region in ipairs(Stubs.state().regions) do
        if region.scripts.OnGamePadStick then return region end
    end
end

local function shownCount(list)
    local count = 0
    for _, region in ipairs(list) do
        if region:IsShown() then count = count + 1 end
    end
    return count
end

-- The cursor this far right and up of where the ring opened.
local function moveBy(x, y)
    local state = Stubs.state()
    Stubs.SetCursor(state.cursorX + x, state.cursorY + y)
end

local function close(a, b) return math.abs(a - b) < 1e-6 end

describe("ring", function()
    it("is off by default and makes nothing", function()
        start({ ringOf({ spell(FIREBALL) }, "F") }, {})
        T.eq(QoLRingButton, nil)
        T.eq(QoLRing, nil)
        T.eq(next(Stubs.state().overrides), nil)
    end)

    it("no longer has entries in the Key Bindings window, which start with the back buttons", function()
        local xml = assert(io.open("Bindings.xml")):read("*a")
        T.falsy(xml:find("QoLRing", 1, true), "no ring bindings")
        T.truthy(xml:find('name="CLICK QoLBackButton1:LeftButton" header="QOL"', 1, true), "header on the first back button")
    end)

    it("makes one secure button with the actions this character can use, acting when the key is let go", function()
        start({ ringOf({ spell(FIREBALL), spell(UNKNOWN), item(HEARTHSTONE), { kind = "toy", id = TOY },
            { kind = "mount", id = MOUNT }, { kind = "macro", id = "Pull" }, { kind = "macro", id = "Gone" } }) })
        T.truthy(QoLRingButton:IsProtected(), "protected")
        T.eq(attribute("useOnKeyDown"), false)
        T.eq(QoLRingButton.wraps.OnClick.header, QoLRing)
        T.truthy(QoLRing:IsProtected(), "secure header")
        T.falsy(QoLRing:IsShown(), "closed")
        T.eq(attribute("*type-1s1"), "spell")
        T.eq(attribute("*spell-1s1"), FIREBALL)
        T.eq(attribute("*type-1s2"), "item")
        T.eq(attribute("*item-1s2"), "item:6948")
        T.eq(attribute("*type-1s3"), "toy")
        T.eq(attribute("*toy-1s3"), TOY)
        T.eq(attribute("*type-1s4"), "spell")
        T.eq(attribute("*spell-1s4"), MOUNT_SPELL)
        T.eq(attribute("*type-1s5"), "macro")
        T.eq(attribute("*macro-1s5"), "Pull")
        T.eq(attribute("*type-1s6"), nil)
        T.eq(QoLRing:GetAttribute("qol-count-1"), 5)
    end)

    it("binds each ring's keys, and leaves the keys of a ring with nothing to use to the game", function()
        local ns = start({
            ringOf({ spell(FIREBALL) }, "F", "PADLSHOULDER"),
            ringOf({ spell(UNKNOWN) }, "G"),
            ringOf({ spell(BLINK) }, nil, "SHIFT-F"),
        })
        T.eq(override("F"), "CLICK QoLRingButton:1mouse")
        T.eq(override("PADLSHOULDER"), "CLICK QoLRingButton:1stick")
        T.eq(override("G"), nil)
        T.eq(override("SHIFT-F"), "CLICK QoLRingButton:3stick")
        T.eq(QoLRing:GetAttribute("qol-count-2"), nil)
        set(ns, "ring", false)
        T.eq(next(Stubs.state().overrides), nil)
    end)

    it("drops what isn't a ring from the saved rings", function()
        start({ "junk", { mouse = "F" } })
        T.same(QoLDB.rings, { { entries = {}, mouse = "F" } })
    end)

    describe("mouse", function()
        it("opens at the cursor while the key is held and uses the action aimed at when it is let go", function()
            start({ ringOf({ spell(FIREBALL), spell(BLINK), spell(FROSTBOLT), item(HEARTHSTONE) }, "F") })
            Stubs.SetCursor(700, 300)
            Stubs.PressOverride("F", true)
            T.truthy(QoLRing:IsShown(), "open")
            T.same({ QoLRing:GetCenter() }, { 700, 300 })
            T.same(Stubs.state().usedActions, {})

            local art = ringArt()
            moveBy(60, 0)
            Stubs.NextFrame()
            T.truthy(art.lit:IsShown(), "lit")
            T.eq(art.lit.texture, "Interface\\AddOns\\QoL\\Media\\RingLit4")
            T.eq(art.lit.rotation, -math.pi / 2)
            local lit = art.lit:PointFor("CENTER")
            T.truthy(close(lit[4], 90) and close(lit[5], 0), "lit wedge on the right")
            T.eq(art.name:GetText(), "Blink")

            Stubs.PressOverride("F", false)
            T.falsy(QoLRing:IsShown(), "closed")
            T.same(Stubs.state().usedActions, { "spell:1953" })
        end)

        it("picks the slot in each direction, slot 1 at the top and on clockwise, for every size", function()
            local rings = {}
            for count = 1, 12 do
                local entries = {}
                for index = 1, count do entries[index] = spell(1000 + index) end
                rings[count] = ringOf(entries, "K" .. count)
            end
            local ns = start(rings, nil, function(state)
                for index = 1, 12 do state.spells[1000 + index] = { name = "Spell " .. index } end
            end)
            for count = 1, 12 do
                T.eq(QoLRing:GetAttribute("qol-count-" .. count), count)
                for index = 1, count do
                    Stubs.state().usedActions = {}
                    Stubs.SetCursor(500, 400)
                    Stubs.PressOverride("K" .. count, true)
                    moveBy(ns.Ring.Offset(index, count, 80))
                    Stubs.PressOverride("K" .. count, false)
                    T.same(Stubs.state().usedActions, { "spell:" .. (1000 + index) }, count .. " slots, slot " .. index)
                    local x, y = ns.Ring.Offset(index, count, 80)
                    T.eq(ns.Ring.SlotAt(x, y, count), index)
                end
            end
        end)

        it("uses nothing when let go in the middle", function()
            start({ ringOf({ spell(FIREBALL) }, "F") })
            Stubs.PressOverride("F", true)
            moveBy(0, 15)
            Stubs.NextFrame()
            T.falsy(ringArt().lit:IsShown(), "nothing lit")
            Stubs.PressOverride("F", false)
            T.falsy(QoLRing:IsShown(), "closed")
            T.same(Stubs.state().usedActions, {})
        end)

        it("draws a slot for each action with spokes between them, and grows past ten", function()
            local twelve = {}
            for index = 1, 12 do twelve[index] = spell(1000 + index) end
            start({ ringOf({ spell(FIREBALL), spell(BLINK), spell(FROSTBOLT) }, "F"), ringOf({ spell(BLINK) }, "G"),
                ringOf(twelve, "H") }, nil, function(state)
                for index = 1, 12 do state.spells[1000 + index] = {} end
            end)
            Stubs.PressOverride("F", true)
            local art = ringArt()
            T.eq(shownCount(art.slots), 3)
            T.eq(shownCount(art.spokes), 3)
            T.eq(art:GetScale(), 1)
            local spoke = art.spokes[1]
            T.eq(spoke.rotation, -math.pi / 3)
            local point = spoke:PointFor("CENTER")
            T.truthy(close(point[4], 93.5 * math.sin(math.pi / 3)) and close(point[5], 93.5 * math.cos(math.pi / 3)),
                "first spoke between slots 1 and 2")
            local slot = art.slots[2]:PointFor("CENTER")
            T.truthy(close(slot[4], 96 * math.sin(2 * math.pi / 3)), "slot 2 a third of the way round")
            Stubs.PressOverride("F", false)

            Stubs.PressOverride("G", true)
            T.eq(shownCount(art.slots), 1)
            T.eq(shownCount(art.spokes), 0)
            moveBy(0, -80)
            Stubs.NextFrame()
            T.eq(art.lit.texture, "Interface\\AddOns\\QoL\\Media\\RingLit1")
            Stubs.PressOverride("G", false)
            T.same(Stubs.state().usedActions, { "spell:1953" })

            Stubs.PressOverride("H", true)
            T.eq(shownCount(art.slots), 12)
            T.truthy(close(art:GetScale(), 1.2), "bigger")
            Stubs.PressOverride("H", false)
        end)

        it("opens the ring whose key went down last", function()
            start({ ringOf({ spell(FIREBALL) }, "F"), ringOf({ spell(BLINK), spell(FROSTBOLT) }, "G") })
            Stubs.PressOverride("F", true)
            Stubs.PressOverride("G", true)
            Stubs.NextFrame()
            T.eq(ringArt().count, 2)
            moveBy(0, 80)
            Stubs.PressOverride("G", false)
            Stubs.PressOverride("F", false)
            T.same(Stubs.state().usedActions, { "spell:1953" })
        end)

        it("shows each slot's icon, count and cooldown when it opens", function()
            start({ ringOf({ spell(FIREBALL), item(HEARTHSTONE) }, "F") }, nil, function(state)
                state.spells[FIREBALL] = { texture = 135812, consumable = true, count = "3", cooldown = { seconds = 8 } }
                state.items[HEARTHSTONE] = { texture = 134414, count = 5, stack = 20, cooldown = { 100, 30 }, usable = false }
            end)
            Stubs.PressOverride("F", true)
            local spellSlot, itemSlot = ringArt().slots[1], ringArt().slots[2]
            T.eq(spellSlot.icon.texture, 135812)
            T.truthy(spellSlot.icon:IsShown(), "icon")
            T.eq(spellSlot.count:GetText(), "3")
            T.same(spellSlot.cooldown.duration, { seconds = 8 })
            T.eq(itemSlot.icon.texture, 134414)
            T.eq(itemSlot.count:GetText(), 5)
            T.same(itemSlot.cooldown.duration, { start = 100, seconds = 30 })
            T.same(itemSlot.icon.vertexColor, { 0.4, 0.4, 0.4 }, "not usable")
            Stubs.PressOverride("F", false)
        end)
    end)

    describe("controller", function()
        it("opens in the middle of the screen and uses the action the right stick aims at", function()
            start({ ringOf({ spell(FIREBALL), spell(BLINK), item(HEARTHSTONE), spell(FROSTBOLT) }, nil, "PADLSHOULDER") })
            T.eq(QoLRing:GetAttribute("qol-stick"), 2)
            Stubs.SetStick(0, -0.9)
            Stubs.PressOverride("PADLSHOULDER", true)
            T.same({ QoLRing:GetCenter() }, { 960, 540 })
            Stubs.NextFrame()
            T.eq(ringArt().name:GetText(), "Hearthstone")
            T.eq(ringArt().lit.rotation, -math.pi)
            Stubs.PressOverride("PADLSHOULDER", false)
            T.same(Stubs.state().usedActions, { "item:item:6948" })
        end)

        it("uses nothing with the stick at rest, or without a controller", function()
            start({ ringOf({ spell(FIREBALL) }, nil, "PADLSHOULDER") })
            Stubs.SetStick(0, 0.3)
            Stubs.PressOverride("PADLSHOULDER")
            Stubs.SetStick(nil)
            Stubs.PressOverride("PADLSHOULDER")
            T.same(Stubs.state().usedActions, {})
            T.falsy(QoLRing:IsShown(), "closed")
        end)

        it("takes the camera stick while open and until it is back at rest, but not the movement stick", function()
            start({ ringOf({ spell(FIREBALL) }, "F", "PADLSHOULDER") })
            local frame = catcher()
            Stubs.SetStick(0.9, 0)
            Stubs.PressOverride("PADLSHOULDER", true)
            T.truthy(frame:IsShown() and frame.gamePadStick, "camera stick taken")
            T.falsy(frame.scripts.OnGamePadStick(frame, "Camera", 0.9, 0), "camera stick kept")
            T.truthy(frame.scripts.OnGamePadStick(frame, "Movement", 0, 1), "movement stick passed on")
            Stubs.PressOverride("PADLSHOULDER", false)
            Stubs.NextFrame()
            T.truthy(frame:IsShown() and frame.gamePadStick, "kept while the stick is out")
            Stubs.SetStick(0, 0)
            Stubs.RunTimers()
            T.falsy(frame:IsShown() or frame.gamePadStick, "given back")
        end)

        it("leaves the sticks alone for the mouse key", function()
            start({ ringOf({ spell(FIREBALL) }, "F", "PADLSHOULDER") })
            Stubs.SetStick(0.9, 0)
            Stubs.PressOverride("F", true)
            T.falsy(catcher():IsShown(), "not taken")
            Stubs.PressOverride("F", false)
        end)
    end)

    it("works in combat, with the actions it had when combat started", function()
        start({ ringOf({ spell(FIREBALL), spell(BLINK), spell(UNKNOWN) }, "F") })
        Stubs.SetCombat(true)
        Stubs.state().spells[UNKNOWN] = { name = "New Spell" }
        Stubs.Fire("SPELLS_CHANGED")
        Stubs.RunTimers()
        Stubs.PressOverride("F", true)
        T.eq(ringArt().count, 2)
        moveBy(0, -80)
        Stubs.NextFrame()
        T.truthy(ringArt().lit:IsShown(), "lit")
        Stubs.PressOverride("F", false)
        T.same(Stubs.state().usedActions, { "spell:1953" })
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(QoLRing:GetAttribute("qol-count-1"), 3)
        T.eq(attribute("*spell-1s3"), UNKNOWN)
    end)

    it("follows what the character can use: spells learned, items used up", function()
        start({ ringOf({ item(HEARTHSTONE), spell(FIREBALL), spell(UNKNOWN) }, "F") })
        T.eq(attribute("*item-1s1"), "item:6948")
        Stubs.state().items[HEARTHSTONE].count = 0
        Stubs.Fire("BAG_UPDATE_DELAYED")
        Stubs.RunTimers()
        T.eq(QoLRing:GetAttribute("qol-count-1"), 1)
        T.eq(attribute("*type-1s1"), "spell")
        T.eq(attribute("*spell-1s1"), FIREBALL)
        T.eq(attribute("*type-1s2"), nil)
        T.eq(attribute("*item-1s1"), nil)
        Stubs.state().spells[FIREBALL] = nil
        Stubs.Fire("SPELLS_CHANGED")
        Stubs.RunTimers()
        T.eq(QoLRing:GetAttribute("qol-count-1"), nil)
        T.eq(override("F"), nil)
    end)

    it("stops acting when turned off, and comes back", function()
        local ns = start({ ringOf({ spell(FIREBALL) }, "F") })
        local opener = QoLRingButton
        set(ns, "ring", false)
        T.eq(attribute("*type-1s1"), nil)
        T.eq(QoLRing:GetAttribute("qol-count-1"), nil)
        Stubs.SecureClick(opener, true, "1mouse")
        T.falsy(QoLRing:IsShown(), "doesn't open")
        moveBy(0, 80)
        Stubs.SecureClick(opener, false, "1mouse")
        T.same(Stubs.state().usedActions, {})
        set(ns, "ring", true)
        T.eq(attribute("*type-1s1"), "spell")
    end)

    it("waits for the end of combat to start", function()
        local ns = start({ ringOf({ spell(FIREBALL) }, "F") }, {})
        Stubs.SetCombat(true)
        set(ns, "ring", true)
        T.eq(QoLRingButton, nil)
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(attribute("*type-1s1"), "spell")
        T.eq(override("F"), "CLICK QoLRingButton:1mouse")
    end)

    it("waits in the controller interface until the settings are closed", function()
        local ns = start({ ringOf({ spell(FIREBALL) }, "F") }, {})
        Stubs.SetControllerUI(true)
        local settings = CreateFrame("Frame", nil, UIParent)
        settings:Show()
        Stubs.SetControllerWindow(settings)
        set(ns, "ring", true)
        Stubs.AdvanceTime()
        T.eq(override("F"), nil)
        Stubs.SetControllerWindow(nil)
        Stubs.AdvanceTime()
        Stubs.AdvanceTime()
        T.eq(override("F"), "CLICK QoLRingButton:1mouse")
    end)

    describe("editor", function()
        local function editorSlot(index) return QoLRingEditor.art.slots[index] end
        local function cursor(...) Stubs.state().cursorInfo = { ... } end
        local function entries(ring) return QoLDB.rings[ring or 1].entries end
        local function ids(ring)
            local list = {}
            for index, entry in ipairs(entries(ring)) do list[index] = entry.id end
            return list
        end
        local function note() return QoLRingEditor.note:GetText() end

        it("opens with /qol ring, closes again, and makes a first ring to fill", function()
            start()
            SlashCmdList.QOL("ring")
            T.truthy(QoLRingEditor:IsShown(), "open")
            T.same(QoLDB.rings, { { entries = {} } })
            T.eq(QoLRingEditor.title:GetText(), "Ring 1 of 1")
            T.eq(QoLRingEditor.art.count, 1)
            T.truthy(editorSlot(1).plus:IsShown(), "a slot to add one")
            SlashCmdList.QOL("ring")
            T.falsy(QoLRingEditor:IsShown(), "closed again")
        end)

        it("adds what's dropped on the empty slot, and puts what's dropped on a slot there", function()
            start({ ringOf({ spell(FIREBALL) }, "F") })
            SlashCmdList.QOL("ring")
            T.eq(editorSlot(1).icon.texture, 135812)
            cursor("spell", 5, "spell", BLINK, BLINK)
            editorSlot(2):RunScript("OnReceiveDrag")
            T.same(ids(), { FIREBALL, BLINK })
            T.eq(Stubs.state().cursorInfo, nil)
            T.eq(QoLRingEditor.art.count, 3)
            cursor("item", HEARTHSTONE, "item:6948")
            editorSlot(1):RunScript("OnClick", "LeftButton")
            T.same(ids(), { HEARTHSTONE, FIREBALL, BLINK })
            T.eq(entries()[1].kind, "item")
            cursor("mount", MOUNT)
            editorSlot(4):RunScript("OnReceiveDrag")
            cursor("macro", 1)
            editorSlot(5):RunScript("OnReceiveDrag")
            T.same(ids(), { HEARTHSTONE, FIREBALL, BLINK, MOUNT, "Pull" })
            -- A toy from the toy box comes as its item; a mount's spell is the mount.
            cursor("item", TOY, "item:54452")
            editorSlot(6):RunScript("OnReceiveDrag")
            cursor("spell", 1, "spell", MOUNT_SPELL)
            editorSlot(7):RunScript("OnReceiveDrag")
            T.same(ids(), { HEARTHSTONE, FIREBALL, BLINK, "Pull", TOY, MOUNT }, "the mount moved instead of coming twice")
            T.same(entries()[5], { kind = "toy", id = TOY })
            T.same(entries()[6], { kind = "mount", id = MOUNT })
            Stubs.RunTimers()
            T.eq(attribute("*item-1s1"), "item:6948")
            T.eq(attribute("*spell-1s3"), BLINK)
        end)

        it("moves what's already on the ring instead of adding it twice", function()
            start({ ringOf({ spell(FIREBALL), spell(BLINK), spell(FROSTBOLT) }) })
            SlashCmdList.QOL("ring")
            cursor("spell", 1, "spell", FROSTBOLT, FROSTBOLT)
            editorSlot(1):RunScript("OnReceiveDrag")
            T.same(ids(), { FROSTBOLT, FIREBALL, BLINK })
            cursor("spell", 1, "spell", FROSTBOLT, FROSTBOLT)
            editorSlot(4):RunScript("OnReceiveDrag")
            T.same(ids(), { FIREBALL, BLINK, FROSTBOLT })
        end)

        it("takes an action off onto the cursor, or away with a right-click", function()
            start({ ringOf({ spell(FIREBALL), spell(BLINK), { kind = "macro", id = "Pull" } }) })
            SlashCmdList.QOL("ring")
            editorSlot(1):RunScript("OnDragStart")
            T.same(ids(), { BLINK, "Pull" })
            T.same(Stubs.state().cursorInfo, { "spell", 1, "spell", FIREBALL, FIREBALL })
            -- Clicking with something on the cursor puts it down.
            editorSlot(3):RunScript("OnClick", "LeftButton")
            T.same(ids(), { BLINK, "Pull", FIREBALL })
            editorSlot(2):RunScript("OnClick", "LeftButton")
            T.same(Stubs.state().cursorInfo, { "macro", 1 })
            Stubs.state().cursorInfo = nil
            editorSlot(1):RunScript("OnClick", "RightButton")
            T.same(ids(), { FIREBALL })
            T.eq(Stubs.state().cursorInfo, nil)
        end)

        it("keeps what this character can't use, unseen, and says so", function()
            start({ ringOf({ spell(UNKNOWN), spell(FIREBALL) }) })
            SlashCmdList.QOL("ring")
            T.eq(QoLRingEditor.art.count, 2)
            T.eq(QoLRingEditor.others:GetText(), "Also on this ring, for other characters: 1 more.")
            cursor("spell", 1, "spell", BLINK, BLINK)
            editorSlot(1):RunScript("OnReceiveDrag")
            T.same(ids(), { UNKNOWN, BLINK, FIREBALL })
            -- An item that isn't in the bags is kept for the characters that have it.
            cursor("item", 5512, "item:5512")
            editorSlot(3):RunScript("OnReceiveDrag")
            T.same(ids(), { UNKNOWN, BLINK, FIREBALL, 5512 })
            T.eq(note(), "Added, but this character can't use it, so it doesn't show here.")
            T.eq(QoLRingEditor.others:GetText(), "Also on this ring, for other characters: 2 more.")
        end)

        it("takes only what a ring can hold, and shows twelve at most", function()
            local twelve = {}
            for index = 1, 12 do twelve[index] = spell(1000 + index) end
            start({ ringOf(twelve) }, nil, function(state)
                for index = 1, 12 do state.spells[1000 + index] = {} end
            end)
            SlashCmdList.QOL("ring")
            T.eq(QoLRingEditor.art.count, 12)
            T.falsy(editorSlot(12).plus:IsShown(), "no slot to add one")
            cursor("battlepet", "BattlePet-0-1")
            editorSlot(1):RunScript("OnReceiveDrag")
            T.eq(note(), "That can't go on a ring, only spells, items, toys, mounts and macros.")
            T.same(Stubs.state().cursorInfo, { "battlepet", "BattlePet-0-1" })
            cursor("spell", 1, "spell", FIREBALL, FIREBALL)
            editorSlot(1):RunScript("OnReceiveDrag")
            T.eq(note(), "A ring shows up to 12 actions. Take one off first, or make a new ring.")
            T.eq(#entries(), 12)
            -- One already on it still moves.
            cursor("spell", 1, "spell", 1012, 1012)
            editorSlot(1):RunScript("OnReceiveDrag")
            T.eq(entries()[1].id, 1012)
        end)

        it("makes, switches between and deletes rings, deleting after a second click", function()
            start({ ringOf({ spell(FIREBALL) }) })
            SlashCmdList.QOL("ring")
            T.falsy(QoLRingEditor.next:IsEnabled(), "no next ring")
            local new, delete
            for _, region in ipairs(Stubs.state().regions) do
                if region.parent == QoLRingEditor and region.text == "New ring" then new = region end
                if region.parent == QoLRingEditor and region.text == "Delete ring" then delete = region end
            end
            new:Click()
            T.eq(#QoLDB.rings, 2)
            T.eq(QoLRingEditor.title:GetText(), "Ring 2 of 2")
            T.eq(QoLRingEditor.art.count, 1)
            QoLRingEditor.previous:Click()
            T.eq(QoLRingEditor.title:GetText(), "Ring 1 of 2")
            T.eq(editorSlot(1).icon.texture, 135812)
            delete:Click()
            T.eq(delete:GetText(), "Click again")
            T.eq(#QoLDB.rings, 2)
            Stubs.AdvanceTime()
            T.eq(delete:GetText(), "Delete ring")
            delete:Click()
            delete:Click()
            T.eq(#QoLDB.rings, 1)
            T.same(QoLDB.rings[1], { entries = {} })
            T.eq(QoLRingEditor.title:GetText(), "Ring 1 of 1")
            -- The last one goes too, and an empty ring takes its place.
            delete:Click()
            delete:Click()
            T.same(QoLDB.rings, { { entries = {} } })
        end)

        it("sets a ring's keys, a key or a controller button, taking them from the ring that had them", function()
            start({ ringOf({ spell(FIREBALL) }, "F"), ringOf({ spell(BLINK) }) })
            SlashCmdList.QOL("ring")
            QoLRingEditor.next:Click()
            local mouse, stick = QoLRingEditor.keys.mouse, QoLRingEditor.keys.stick
            T.eq(mouse.text, "|cff808080Not Bound|r")
            mouse:RunScript("OnClick", "LeftButton")
            T.truthy(mouse.selected, "waiting")
            T.eq(note(), "Press the key for Ring 2 (aim with the mouse). Escape or another click on the box cancels.")
            Stubs.TypeKey("LSHIFT")
            T.truthy(mouse.selected, "still waiting for the key with the modifier")
            Stubs.TypeKey("F")
            T.falsy(mouse.selected, "done")
            T.eq(QoLDB.rings[2].mouse, "F")
            T.eq(QoLDB.rings[1].mouse, nil)
            T.eq(mouse.text, "F")
            T.eq(note(), "F is now the key for Ring 2 (aim with the mouse), no longer for Ring 1 (aim with the mouse).")
            Stubs.RunTimers()
            T.eq(override("F"), "CLICK QoLRingButton:2mouse")

            stick:RunScript("OnClick", "LeftButton")
            Stubs.PressGamePadButton("PADLSHOULDER")
            T.eq(QoLDB.rings[2].stick, "PADLSHOULDER")
            Stubs.RunTimers()
            T.eq(override("PADLSHOULDER"), "CLICK QoLRingButton:2stick")

            mouse:RunScript("OnClick", "RightButton")
            T.eq(QoLDB.rings[2].mouse, nil)
            Stubs.RunTimers()
            T.eq(override("F"), nil)

            stick:RunScript("OnClick", "LeftButton")
            Stubs.TypeKey("ESCAPE")
            T.falsy(stick.selected, "cancelled")
            T.eq(QoLDB.rings[2].stick, "PADLSHOULDER")
        end)

        it("names what a key did before the ring took it", function()
            start({ ringOf({ spell(FIREBALL) }) })
            SlashCmdList.QOL("ring")
            QoLRingEditor.keys.mouse:RunScript("OnClick", "LeftButton")
            Stubs.TypeKey("1")
            T.eq(note(), "1 is now the key for Ring 1 (aim with the mouse). While the rings are on, it no longer does "
                .. "ACTIONBUTTON1.")
        end)

        it("shows an action's tooltip, or what the empty slot is for", function()
            start({ ringOf({ spell(FIREBALL), item(HEARTHSTONE), { kind = "mount", id = MOUNT } }) })
            SlashCmdList.QOL("ring")
            editorSlot(1):RunScript("OnEnter")
            T.eq(GameTooltip.spell, FIREBALL)
            T.truthy(QoLRingEditor.art.lit:IsShown(), "slot lit")
            T.eq(QoLRingEditor.art.lit.texture, "Interface\\AddOns\\QoL\\Media\\RingLit4")
            editorSlot(2):RunScript("OnEnter")
            T.eq(GameTooltip.item, HEARTHSTONE)
            editorSlot(3):RunScript("OnEnter")
            T.eq(GameTooltip.mountSpell, MOUNT_SPELL)
            editorSlot(4):RunScript("OnEnter")
            T.eq(GameTooltip.lines[1].text, "Ring")
            T.eq(GameTooltip.lines[2].text, "Drag a spell, item, toy, mount or macro here to add it.")
            editorSlot(4):RunScript("OnLeave")
            T.falsy(GameTooltip.shown, "hidden")
            T.falsy(QoLRingEditor.art.lit:IsShown(), "nothing lit")
        end)

        it("says so while the rings are off", function()
            start(nil, {})
            SlashCmdList.QOL("ring")
            T.eq(note(), "The rings are off: turn them on in the settings, on the Ring page.")
        end)

        it("closes when combat starts and doesn't open in combat", function()
            start()
            SlashCmdList.QOL("ring")
            QoLRingEditor.keys.mouse:RunScript("OnClick", "LeftButton")
            Stubs.state().combat = true
            Stubs.Fire("PLAYER_REGEN_DISABLED")
            T.falsy(QoLRingEditor:IsShown(), "closed")
            T.falsy(QoLRingEditor.keys.mouse.selected, "no longer waiting")
            SlashCmdList.QOL("ring")
            T.falsy(QoLRingEditor:IsShown(), "still closed")
            T.eq(Stubs.state().messages[#Stubs.state().messages],
                "|cff33ff99Quality of Life|r: The rings can't be changed in combat.")
        end)

        it("closes on Escape and passes the other keys on to the game, so P opens the spell book", function()
            start()
            SlashCmdList.QOL("ring")
            T.truthy(Stubs.TypeKey("P"), "P reached the key bindings")
            T.truthy(QoLRingEditor:IsShown(), "still open")
            -- Waiting for a key, Escape only cancels that.
            QoLRingEditor.keys.mouse:RunScript("OnClick", "LeftButton")
            T.falsy(Stubs.TypeKey("ESCAPE"), "kept by the key box")
            T.falsy(QoLRingEditor.keys.mouse.selected, "cancelled")
            T.truthy(QoLRingEditor:IsShown(), "still open after cancelling")
            T.falsy(Stubs.TypeKey("ESCAPE"), "kept from the game menu")
            T.falsy(QoLRingEditor:IsShown(), "closed")
            SlashCmdList.QOL("rings")
            T.truthy(QoLRingEditor:IsShown(), "open again, with /qol rings too")
            T.truthy(Stubs.TypeKey("W"), "keys go on to the game again")
        end)

        it("leaves Escape to the game's settings and menu while they're open", function()
            start()
            local settings = CreateFrame("Frame", "SettingsPanel", UIParent)
            settings:SetFrameStrata("HIGH")
            local menu = CreateFrame("Frame", "GameMenuFrame", UIParent)
            menu:Hide()
            SlashCmdList.QOL("ring")
            T.truthy(Stubs.TypeKey("ESCAPE"), "Escape went to the game, for the settings")
            T.truthy(QoLRingEditor:IsShown(), "still open")
            settings:Hide()
            menu:Show()
            T.truthy(Stubs.TypeKey("ESCAPE"), "and for the game menu the settings went back to")
            T.truthy(QoLRingEditor:IsShown(), "still open")
            menu:Hide()
            T.falsy(Stubs.TypeKey("ESCAPE"))
            T.falsy(QoLRingEditor:IsShown(), "closed")
        end)
    end)
end)
