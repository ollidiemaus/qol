local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions, setup)
    local ns = Stubs.LoadAddon()
    if setup then setup(Stubs.state()) end
    Stubs.Login(savedOptions)
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

-- Saved options with the ring on (a new table each time: the options are saved into it).
local function on() return { ring = true } end

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

-- The cursor this far right and up of where the ring opened.
local function moveBy(x, y)
    local state = Stubs.state()
    Stubs.SetCursor(state.cursorX + x, state.cursorY + y)
end

describe("ring", function()
    it("is off by default and makes nothing", function()
        start(nil, function(state) state.bindings.F = "CLICK QoLRingMouse:LeftButton" end)
        T.eq(QoLRingMouse, nil)
        T.eq(QoLRing, nil)
        T.eq(next(Stubs.state().overrides), nil)
    end)

    it("names its two keys in the Key Bindings window, first under the addon's header", function()
        start()
        T.eq(_G["BINDING_NAME_CLICK QoLRingMouse:LeftButton"], "Ring (aim with the mouse)")
        T.eq(_G["BINDING_NAME_CLICK QoLRingStick:LeftButton"], "Ring (aim with the right stick)")
        local xml = assert(io.open("Bindings.xml")):read("*a")
        T.truthy(xml:find('name="CLICK QoLRingMouse:LeftButton" header="QOL"', 1, true), "mouse key with the header")
        T.truthy(xml:find('name="CLICK QoLRingStick:LeftButton"', 1, true), "stick key")
    end)

    it("makes two secure buttons for buttons 1 to 8 of Action Bar 8, acting when the key is let go", function()
        start(on())
        for _, button in ipairs({ QoLRingMouse, QoLRingStick }) do
            T.truthy(button:IsProtected(), "protected")
            T.eq(button:GetAttribute("useOnKeyDown"), false)
            T.eq(button:GetAttribute("*type-s1"), "action")
            T.eq(button:GetAttribute("*action-s1"), 169)
            T.eq(button:GetAttribute("*action-s8"), 176)
            T.eq(button.wraps.OnClick.header, QoLRing)
        end
        T.eq(QoLRingMouse:GetAttribute("qol-aim"), "mouse")
        T.eq(QoLRingStick:GetAttribute("qol-aim"), "stick")
        T.truthy(QoLRing:IsProtected(), "secure header")
        T.falsy(QoLRing:IsShown(), "closed")
    end)

    it("takes the slots of the bar picked", function()
        local ns = start(on())
        set(ns, "ringBar", 6)
        T.eq(QoLRingMouse:GetAttribute("*action-s1"), 145)
        T.eq(QoLRingStick:GetAttribute("*action-s8"), 152)
        set(ns, "ringBar", 7)
        T.eq(QoLRingMouse:GetAttribute("*action-s1"), 157)
    end)

    describe("mouse", function()
        it("opens at the cursor while the key is held and uses the action aimed at when it is let go", function()
            start(on(), function(state) state.actions[171] = { texture = 134414, name = "Hearthstone" } end)
            Stubs.SetCursor(700, 300)
            Stubs.SecureClick(QoLRingMouse, true)
            T.truthy(QoLRing:IsShown(), "open")
            T.same({ QoLRing:GetCenter() }, { 700, 300 })
            T.same(Stubs.state().usedActions, {})

            local art = ringArt()
            moveBy(60, 0)
            Stubs.NextFrame()
            T.truthy(art.lit:IsShown(), "lit")
            T.eq(art.lit.rotation, -math.pi / 2)
            local lit = art.lit:PointFor("CENTER")
            T.truthy(math.abs(lit[4] - 95) < 1e-9 and math.abs(lit[5]) < 1e-9, "lit wedge on the right")
            T.eq(art.name:GetText(), "Hearthstone")

            Stubs.SecureClick(QoLRingMouse, false)
            T.falsy(QoLRing:IsShown(), "closed")
            T.same(Stubs.state().usedActions, { 171 })
        end)

        it("picks the slot in each direction, slot 1 at the top and on clockwise", function()
            local ns = start(on())
            for index = 1, 8 do
                Stubs.state().usedActions = {}
                Stubs.SetCursor(500, 400)
                Stubs.SecureClick(QoLRingMouse, true)
                moveBy(ns.Ring.Offset(index, 80))
                Stubs.SecureClick(QoLRingMouse, false)
                T.same(Stubs.state().usedActions, { 168 + index }, "slot " .. index)
                T.eq(ns.Ring.SlotAt(ns.Ring.Offset(index, 80)), index)
            end
        end)

        it("uses nothing when let go in the middle", function()
            start(on(), function(state) state.actions[169] = { texture = 134414 } end)
            Stubs.SecureClick(QoLRingMouse, true)
            moveBy(0, 15)
            Stubs.NextFrame()
            T.falsy(ringArt().lit:IsShown(), "nothing lit")
            Stubs.SecureClick(QoLRingMouse, false)
            T.falsy(QoLRing:IsShown(), "closed")
            T.same(Stubs.state().usedActions, {})
        end)

        it("lights no empty slot", function()
            start(on())
            Stubs.SecureClick(QoLRingMouse, true)
            moveBy(0, 80)
            Stubs.NextFrame()
            T.falsy(ringArt().lit:IsShown(), "nothing lit")
            T.eq(ringArt().name:GetText(), nil)
            Stubs.SecureClick(QoLRingMouse, false)
        end)

        it("shows each slot's icon, count and cooldown when it opens", function()
            start(on())
            Stubs.state().actions[169] = { texture = 136048, count = "3", cooldown = { seconds = 8 } }
            Stubs.SecureClick(QoLRingMouse, true)
            local slot = ringArt().slots[1]
            T.eq(slot.icon.texture, 136048)
            T.truthy(slot.icon:IsShown(), "icon")
            T.eq(slot.count:GetText(), "3")
            T.same(slot.cooldown.duration, { seconds = 8 })
            T.falsy(ringArt().slots[2].icon:IsShown(), "empty slot")
            Stubs.SecureClick(QoLRingMouse, false)
        end)
    end)

    describe("controller", function()
        it("opens in the middle of the screen and uses the action the right stick aims at", function()
            start(on(), function(state) state.actions[173] = { texture = 134414, name = "Hearthstone" } end)
            T.eq(QoLRing:GetAttribute("qol-stick"), 2)
            Stubs.SetStick(0, -0.9)
            Stubs.SecureClick(QoLRingStick, true)
            T.same({ QoLRing:GetCenter() }, { 960, 540 })
            Stubs.NextFrame()
            T.eq(ringArt().name:GetText(), "Hearthstone")
            T.eq(ringArt().lit.rotation, -math.pi)
            Stubs.SecureClick(QoLRingStick, false)
            T.same(Stubs.state().usedActions, { 173 })
        end)

        it("uses nothing with the stick at rest, or without a controller", function()
            start(on(), function(state) state.actions[169] = { texture = 134414 } end)
            Stubs.SetStick(0, 0.3)
            Stubs.PressKey(QoLRingStick)
            Stubs.SetStick(nil)
            Stubs.PressKey(QoLRingStick)
            T.same(Stubs.state().usedActions, {})
            T.falsy(QoLRing:IsShown(), "closed")
        end)

        it("takes the camera stick while open and until it is back at rest, but not the movement stick", function()
            start(on())
            local frame = catcher()
            Stubs.SetStick(0.9, 0)
            Stubs.SecureClick(QoLRingStick, true)
            T.truthy(frame:IsShown() and frame.gamePadStick, "camera stick taken")
            T.falsy(frame.scripts.OnGamePadStick(frame, "Camera", 0.9, 0), "camera stick kept")
            T.truthy(frame.scripts.OnGamePadStick(frame, "Movement", 0, 1), "movement stick passed on")
            Stubs.SecureClick(QoLRingStick, false)
            Stubs.NextFrame()
            T.truthy(frame:IsShown() and frame.gamePadStick, "kept while the stick is out")
            Stubs.SetStick(0, 0)
            Stubs.RunTimers()
            T.falsy(frame:IsShown() or frame.gamePadStick, "given back")
        end)

        it("leaves the sticks alone for the mouse ring", function()
            start(on())
            Stubs.SetStick(0.9, 0)
            Stubs.SecureClick(QoLRingMouse, true)
            T.falsy(catcher():IsShown(), "not taken")
            Stubs.SecureClick(QoLRingMouse, false)
        end)
    end)

    it("works in combat", function()
        start(on(), function(state) state.actions[169] = { texture = 134414 } end)
        Stubs.SetCombat(true)
        Stubs.SecureClick(QoLRingMouse, true)
        moveBy(0, 80)
        Stubs.NextFrame()
        T.truthy(ringArt().lit:IsShown(), "lit")
        Stubs.SecureClick(QoLRingMouse, false)
        T.same(Stubs.state().usedActions, { 169 })
    end)

    it("stops acting when turned off, and comes back", function()
        local ns = start(on(), function(state) state.actions[169] = { texture = 134414 } end)
        set(ns, "ring", false)
        T.eq(QoLRingMouse:GetAttribute("*type-s1"), nil)
        Stubs.SecureClick(QoLRingMouse, true)
        T.falsy(QoLRing:IsShown(), "doesn't open")
        moveBy(0, 80)
        Stubs.SecureClick(QoLRingMouse, false)
        T.same(Stubs.state().usedActions, {})
        set(ns, "ring", true)
        T.eq(QoLRingMouse:GetAttribute("*type-s1"), "action")
    end)

    it("waits for the end of combat to start", function()
        local ns = start()
        Stubs.SetCombat(true)
        set(ns, "ring", true)
        T.eq(QoLRingMouse, nil)
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(QoLRingMouse:GetAttribute("*type-s1"), "action")
    end)

    describe("bindings", function()
        it("press the ring's buttons with the keys bound to them, in the controller interface too", function()
            local ns = start(on(), function(state)
                state.bindings.F = "CLICK QoLRingMouse:LeftButton"
                state.bindings.PADLSHOULDER = "CLICK QoLRingStick:LeftButton"
            end)
            T.eq(override("F"), "CLICK QoLRingMouse:LeftButton")
            T.eq(override("PADLSHOULDER"), "CLICK QoLRingStick:LeftButton")
            set(ns, "ring", false)
            T.eq(next(Stubs.state().overrides), nil)
        end)

        it("follow a key bound in the Key Bindings window, after combat", function()
            start(on())
            Stubs.SetCombat(true)
            Stubs.state().bindings.G = "CLICK QoLRingMouse:LeftButton"
            Stubs.Fire("UPDATE_BINDINGS")
            Stubs.RunTimers()
            T.eq(override("G"), nil)
            Stubs.SetCombat(false)
            Stubs.RunTimers()
            T.eq(override("G"), "CLICK QoLRingMouse:LeftButton")
        end)

        it("wait in the controller interface until the settings are closed, with the bar change", function()
            local ns = start(on())
            Stubs.SetControllerUI(true)
            local settings = CreateFrame("Frame", nil, UIParent)
            settings:Show()
            Stubs.SetControllerWindow(settings)
            set(ns, "ringBar", 6)
            Stubs.state().bindings.G = "CLICK QoLRingMouse:LeftButton"
            Stubs.Fire("UPDATE_BINDINGS")
            Stubs.RunTimers()
            Stubs.AdvanceTime()
            T.eq(QoLRingMouse:GetAttribute("*action-s1"), 169)
            T.eq(override("G"), nil)
            Stubs.SetControllerWindow(nil)
            Stubs.AdvanceTime()
            Stubs.AdvanceTime()
            T.eq(QoLRingMouse:GetAttribute("*action-s1"), 145)
            T.eq(override("G"), "CLICK QoLRingMouse:LeftButton")
        end)
    end)

    describe("editor", function()
        local function editorSlot(index) return QoLRingEditor.art.slots[index] end

        it("opens with /qol ring, closes with Escape, and shows the ring's actions", function()
            start(nil, function(state) state.actions[169] = { texture = 136048 } end)
            SlashCmdList.QOL("ring")
            T.truthy(QoLRingEditor:IsShown(), "open")
            T.eq(UISpecialFrames[1], "QoLRingEditor")
            T.eq(editorSlot(1).icon.texture, 136048)
            SlashCmdList.QOL("ring")
            T.falsy(QoLRingEditor:IsShown(), "closed again")
        end)

        it("moves actions on and off the ring", function()
            start(nil, function(state) state.actions[170] = { texture = 136048 } end)
            SlashCmdList.QOL("ring")
            editorSlot(1):RunScript("OnReceiveDrag")
            T.same(Stubs.state().placed, { 169 })
            editorSlot(2):RunScript("OnDragStart")
            T.eq(Stubs.state().cursor, 170)
            -- A click places what's on the cursor, or takes the slot's action.
            editorSlot(3):RunScript("OnClick", "LeftButton")
            T.same(Stubs.state().placed, { 169, 171 })
            Stubs.state().cursor = nil
            editorSlot(2):RunScript("OnClick", "LeftButton")
            T.eq(Stubs.state().cursor, 170)
        end)

        it("updates when an action moves", function()
            start()
            SlashCmdList.QOL("ring")
            Stubs.state().actions[176] = { texture = 136048 }
            Stubs.Fire("ACTIONBAR_SLOT_CHANGED", 176)
            Stubs.RunTimers()
            T.eq(editorSlot(8).icon.texture, 136048)
        end)

        it("shows an action's tooltip, or where to put one", function()
            start(nil, function(state) state.actions[169] = { texture = 136048 } end)
            SlashCmdList.QOL("ring")
            editorSlot(1):RunScript("OnEnter")
            T.eq(GameTooltip.action, 169)
            T.truthy(QoLRingEditor.art.lit:IsShown(), "slot lit")
            editorSlot(2):RunScript("OnEnter")
            T.eq(GameTooltip.lines[1].text, "Ring")
            T.eq(GameTooltip.lines[2].text, "Empty. Drag a spell here, or onto Action Bar 8, button 2.")
            editorSlot(2):RunScript("OnLeave")
            T.falsy(GameTooltip.shown, "hidden")
            T.falsy(QoLRingEditor.art.lit:IsShown(), "nothing lit")
        end)

        it("closes when combat starts and doesn't open in combat", function()
            start()
            SlashCmdList.QOL("ring")
            Stubs.state().combat = true
            Stubs.Fire("PLAYER_REGEN_DISABLED")
            T.falsy(QoLRingEditor:IsShown(), "closed")
            SlashCmdList.QOL("ring")
            T.falsy(QoLRingEditor:IsShown(), "still closed")
            T.eq(Stubs.state().messages[#Stubs.state().messages],
                "|cff33ff99Quality of Life|r: The ring can't be changed in combat.")
        end)
    end)
end)
