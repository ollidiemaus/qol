local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- The next frames, and the check for the controller's windows that lets the buttons' changes go.
local function settle()
    Stubs.RunTimers()
    Stubs.AdvanceTime()
end

-- Forever, with its controller action bar and the controller interface on.
local function start(savedOptions, setup)
    local ns = Stubs.LoadAddon()
    local bar = Stubs.NewGamepadBar()
    Stubs.SetControllerUI(true)
    if setup then setup(Stubs.state()) end
    Stubs.Login(savedOptions)
    Stubs.AdvanceTime()
    return ns, bar
end

local function set(ns, key, value)
    ns.Options:Set(key, value)
    settle()
end

-- The player turns the controller interface on or off.
local function switch(on)
    Stubs.SetControllerUI(on)
    Stubs.Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
    settle()
end

local function override(key)
    local entry = Stubs.state().overrides[key]
    return entry and entry.command
end

-- Saved options with the back buttons on (a new table each time: the options are saved into it).
local function on() return { controllerBackButtons = true } end

describe("controller back buttons", function()
    it("are off by default and make nothing", function()
        start()
        T.eq(QoLBackButton1, nil)
        T.eq(next(Stubs.state().overrides), nil)
    end)

    it("do nothing without the controller action bar (not Forever)", function()
        local ns = Stubs.LoadAddon()
        Stubs.Login(on())
        T.eq(QoLBackButton1, nil)
        T.eq(next(Stubs.state().overrides), nil)
        T.eq(ns.SettingsPanel.pages.controller, nil, "no Controller page")
    end)

    it("name their bindings in the Key Bindings window", function()
        start()
        T.eq(BINDING_HEADER_QOL, "Quality of Life")
        T.eq(_G["BINDING_NAME_CLICK QoLBackButton1:LeftButton"], "Back button L4 (upper left)")
        T.eq(_G["BINDING_NAME_CLICK QoLBackButton4:LeftButton"], "Back button R5 (lower right)")
        local xml = assert(io.open("Bindings.xml")):read("*a")
        for index = 1, 4 do
            T.truthy(xml:find('name="CLICK QoLBackButton' .. index .. ':LeftButton"', 1, true), "binding " .. index)
        end
    end)

    it("are secure action buttons for buttons 9 to 12 of Action Bar 8", function()
        start(on())
        for index = 1, 4 do
            local button = _G["QoLBackButton" .. index]
            T.eq(button:GetAttribute("type"), "action")
            T.eq(button:GetAttribute("action"), 176 + index)
            T.truthy(button:IsProtected(), "protected")
            T.truthy(button:IsVisible(), "shown")
        end
    end)

    it("take the slots of the bar picked", function()
        local ns = start(on())
        set(ns, "controllerBackButtonsBar", 6)
        T.eq(QoLBackButton1:GetAttribute("action"), 153)
        T.eq(QoLBackButton4:GetAttribute("action"), 156)
        set(ns, "controllerBackButtonsBar", 7)
        T.eq(QoLBackButton1:GetAttribute("action"), 165)
    end)

    it("sit outside the d-pad and face buttons of the bar, two on each side", function()
        local _, bar = start(on())
        local left, right = bar.PageUnit.LeftCenteredAnchor, bar.PageUnit.RightCenteredAnchor
        local function point(button) return { button:GetPoint() } end
        T.same(point(QoLBackButton1), { "CENTER", left, "CENTER", -182, 26 })
        T.same(point(QoLBackButton2), { "CENTER", left, "CENTER", -182, -26 })
        T.same(point(QoLBackButton3), { "CENTER", right, "CENTER", 182, 26 })
        T.same(point(QoLBackButton4), { "CENTER", right, "CENTER", 182, -26 })
        -- A frame of ours below the bar holds them, so they show, hide and scale with it.
        local holder = QoLBackButton1:GetParent()
        T.eq(holder:GetParent(), bar)
        bar:Hide()
        T.falsy(QoLBackButton1:IsVisible(), "hidden with the bar")
    end)

    it("hide and stop acting when turned off, and come back", function()
        local ns = start(on())
        set(ns, "controllerBackButtons", false)
        T.falsy(QoLBackButton1:IsVisible(), "hidden")
        T.eq(QoLBackButton1:GetAttribute("type"), nil)
        T.eq(next(Stubs.state().overrides), nil)
        set(ns, "controllerBackButtons", true)
        T.truthy(QoLBackButton1:IsVisible(), "shown")
        T.eq(QoLBackButton1:GetAttribute("type"), "action")
    end)

    it("wait for the end of combat to appear", function()
        local ns = start()
        Stubs.SetCombat(true)
        set(ns, "controllerBackButtons", true)
        T.eq(QoLBackButton1, nil)
        Stubs.SetCombat(false)
        settle()
        T.eq(QoLBackButton1:GetAttribute("type"), "action")
    end)

    it("do nothing with keyboard and mouse", function()
        start(on(), function(state)
            Stubs.SetControllerUI(false)
            state.bindings["F13"] = "CLICK QoLBackButton1:LeftButton"
        end)
        T.eq(QoLBackButton1, nil)
        T.eq(next(Stubs.state().overrides), nil)
        -- Logged in like that, they appear once the controller interface is turned on.
        switch(true)
        T.eq(QoLBackButton1:GetAttribute("type"), "action")
        T.eq(override("F13"), "CLICK QoLBackButton1:LeftButton")
    end)

    it("hide and stop acting when the controller interface is turned off, and come back", function()
        start(on(), function(state) state.bindings["F13"] = "CLICK QoLBackButton1:LeftButton" end)
        switch(false)
        T.falsy(QoLBackButton1:IsVisible(), "hidden")
        T.eq(QoLBackButton1:GetAttribute("type"), nil)
        T.eq(next(Stubs.state().overrides), nil)
        switch(true)
        T.truthy(QoLBackButton1:IsVisible(), "shown")
        T.eq(QoLBackButton1:GetAttribute("type"), "action")
        T.eq(override("F13"), "CLICK QoLBackButton1:LeftButton")
    end)

    describe("bindings", function()
        it("press a button with the keys bound to it", function()
            start(on(), function(state)
                state.bindings["F13"] = "CLICK QoLBackButton1:LeftButton"
                state.bindings["F14"] = "CLICK QoLBackButton3:LeftButton"
            end)
            T.eq(override("F13"), "CLICK QoLBackButton1:LeftButton")
            T.eq(override("F14"), "CLICK QoLBackButton3:LeftButton")
            -- A button with a key of its own doesn't take its paddle.
            T.eq(override("PADPADDLE2"), nil)
            T.eq(override("PADPADDLE1"), nil)
        end)

        it("give a button without a key its paddle, while nothing else has the paddle", function()
            start(on(), function(state)
                state.bindings["PADPADDLE4"] = "TOGGLEWORLDMAP"
                state.gamepadBindings["PADPADDLE3"] = "INTERACTTARGET"
            end)
            T.eq(override("PADPADDLE2"), "CLICK QoLBackButton1:LeftButton")
            T.eq(override("PADPADDLE1"), "CLICK QoLBackButton3:LeftButton")
            T.eq(override("PADPADDLE4"), nil)
            T.eq(override("PADPADDLE3"), nil)
        end)

        it("follow a key bound in the Key Bindings window", function()
            start(on())
            Stubs.state().bindings["F15"] = "CLICK QoLBackButton2:LeftButton"
            Stubs.Fire("UPDATE_BINDINGS")
            settle()
            T.eq(override("F15"), "CLICK QoLBackButton2:LeftButton")
            T.eq(override("PADPADDLE4"), nil)
            -- Setting our overrides fires UPDATE_BINDINGS again; nothing changes then.
            local calls = Stubs.state().overrideCalls
            Stubs.Fire("UPDATE_BINDINGS")
            settle()
            T.eq(Stubs.state().overrideCalls, calls)
        end)

        it("wait for the end of combat to change", function()
            start(on())
            Stubs.SetCombat(true)
            Stubs.state().bindings["F16"] = "CLICK QoLBackButton4:LeftButton"
            Stubs.Fire("UPDATE_BINDINGS")
            Stubs.RunTimers()
            T.eq(override("F16"), nil)
            Stubs.SetCombat(false)
            settle()
            T.eq(override("F16"), "CLICK QoLBackButton4:LeftButton")
        end)

        it("wait in the controller interface until the settings are closed, with the bar change", function()
            local ns = start(on())
            local settings = CreateFrame("Frame", nil, UIParent)
            settings:Show()
            Stubs.SetControllerWindow(settings)
            set(ns, "controllerBackButtonsBar", 6)
            Stubs.state().bindings["F16"] = "CLICK QoLBackButton4:LeftButton"
            Stubs.Fire("UPDATE_BINDINGS")
            Stubs.RunTimers()
            Stubs.AdvanceTime()
            T.eq(QoLBackButton1:GetAttribute("action"), 177)
            T.eq(override("F16"), nil)
            -- Closing the settings saves the bindings, which fires UPDATE_BINDINGS; nothing runs then.
            settings:Hide()
            Stubs.SetControllerWindow(nil)
            Stubs.Fire("UPDATE_BINDINGS")
            Stubs.RunTimers()
            T.eq(QoLBackButton1:GetAttribute("action"), 177)
            Stubs.AdvanceTime()
            T.eq(QoLBackButton1:GetAttribute("action"), 177)
            Stubs.AdvanceTime()
            T.eq(QoLBackButton1:GetAttribute("action"), 153)
            T.eq(override("F16"), "CLICK QoLBackButton4:LeftButton")
        end)
    end)

    describe("look", function()
        it("shows the slot's icon, count, usability and cooldown", function()
            start(on(), function(state)
                state.actions[177] = { texture = 136048, count = "3", cooldown = { seconds = 8 } }
                state.actions[178] = { texture = 135808, usable = false, noMana = true }
                state.actions[179] = { texture = 132222, usable = false, current = true }
            end)
            T.eq(QoLBackButton1.icon.texture, 136048)
            T.truthy(QoLBackButton1.icon:IsShown(), "icon shown")
            T.same(QoLBackButton1.icon.vertexColor, { 1, 1, 1 })
            T.eq(QoLBackButton1.count:GetText(), "3")
            T.same(QoLBackButton1.cooldown.duration, { seconds = 8 })
            T.same(QoLBackButton2.icon.vertexColor, { 0.5, 0.5, 1 })
            T.same(QoLBackButton3.icon.vertexColor, { 0.4, 0.4, 0.4 })
            T.truthy(QoLBackButton3.selectedRim:IsShown(), "current action")
            T.falsy(QoLBackButton4.icon:IsShown(), "empty slot")
        end)

        it("updates in combat when the slot changes", function()
            start(on())
            Stubs.SetCombat(true)
            Stubs.state().actions[180] = { texture = 136048 }
            Stubs.Fire("ACTIONBAR_SLOT_CHANGED", 180)
            Stubs.RunTimers()
            T.eq(QoLBackButton4.icon.texture, 136048)
        end)

        it("looks pressed while its key is down", function()
            start(on())
            QoLBackButton1:RunScript("PostClick", "LeftButton", true)
            T.truthy(QoLBackButton1.pushedRim:IsShown(), "pressed rim")
            T.eq(QoLBackButton1.visual:GetWidth(), 34)
            QoLBackButton1:RunScript("PostClick", "LeftButton", false)
            T.falsy(QoLBackButton1.pushedRim:IsShown(), "released")
            T.eq(QoLBackButton1.visual:GetWidth(), 38)
        end)
    end)

    describe("spells", function()
        it("are picked up by dragging, with the bars unlocked or the pick up modifier held", function()
            start(on(), function(state) state.actions[177] = { texture = 136048 } end)
            Stubs.InstallSettings()
            QoLBackButton1:RunScript("OnDragStart")
            T.eq(Stubs.state().cursor, 177)

            Stubs.state().cursor = nil
            Stubs.state().settingValues.lockActionBars = true
            QoLBackButton1:RunScript("OnDragStart")
            T.eq(Stubs.state().cursor, nil)
            Stubs.state().modifiedClicks.PICKUPACTION = true
            QoLBackButton1:RunScript("OnDragStart")
            T.eq(Stubs.state().cursor, 177)
        end)

        it("are placed by dropping them on a button, not in combat", function()
            start(on())
            QoLBackButton2:RunScript("OnReceiveDrag")
            T.same(Stubs.state().placed, { 178 })
            Stubs.SetCombat(true)
            QoLBackButton2:RunScript("OnReceiveDrag")
            T.same(Stubs.state().placed, { 178 })
        end)

        it("show in the tooltip, or where to put one", function()
            start(on(), function(state) state.actions[177] = { texture = 136048 } end)
            QoLBackButton1:RunScript("OnEnter")
            T.eq(GameTooltip.action, 177)
            T.truthy(GameTooltip.shown, "shown")
            QoLBackButton2:RunScript("OnEnter")
            T.eq(GameTooltip.lines[1].text, "Back button L5 (lower left)")
            T.eq(GameTooltip.lines[2].text, "Empty. Drag a spell here, or onto Action Bar 8, button 10.")
            QoLBackButton2:RunScript("OnLeave")
            T.falsy(GameTooltip.shown, "hidden")
        end)
    end)
end)
