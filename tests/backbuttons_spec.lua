local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- The next frames, and the check for the controller's windows that lets the buttons' changes go;
-- twice, for the trigger toggle's update the back buttons' asks for.
local function settle()
    for _ = 1, 2 do
        Stubs.RunTimers()
        Stubs.AdvanceTime()
    end
end

-- Forever, with its controller action bar and the controller interface on.
local function start(savedOptions, setup)
    local ns = Stubs.LoadAddon()
    local bar = Stubs.NewGamepadBar()
    Stubs.SetControllerUI(true)
    if setup then setup(Stubs.state()) end
    Stubs.Login(savedOptions)
    settle()
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
-- And the trigger toggle, which gives them the other three bars.
local function withToggle() return { controllerBackButtons = true, controllerTriggerToggle = true } end

-- The button shown for a back button (1 L4, 2 L5, 3 R4, 4 R5) on a controller bar.
local BARS = { "Top", "Left", "Right", "Bottom" }
local function shown(bar, index) return _G["QoLBackButton" .. bar .. index] end

-- The controller bars whose back buttons show.
local function showing()
    local list = {}
    for _, bar in ipairs(BARS) do
        if shown(bar, 1):IsVisible() then list[#list + 1] = bar end
    end
    return list
end

-- The slot a back button's key used, pressed and let go.
local function press(index)
    Stubs.PressKey(_G["QoLBackButton" .. index])
    local used = Stubs.state().usedActions
    return used[#used]
end

local LT, RT = "PADLTRIGGER", "PADRTRIGGER"
local function tap(key) Stubs.PressOverride(key) end

-- The default slots: buttons 9 to 12 of Action Bar 8 (Top), 7 (Left), 6 (Right) and 5 (Bottom).
local TOP, LEFT, RIGHT, BOTTOM = 176, 164, 152, 44

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

    it("press buttons 9 to 12 of Action Bar 8 with their keys, shown beside Top", function()
        start(on())
        for index = 1, 4 do
            local key = _G["QoLBackButton" .. index]
            T.truthy(key:IsProtected(), "the key's button is a secure one")
            T.eq(press(index), TOP + index)
            local button = shown("Top", index)
            T.eq(button:GetAttribute("type"), "action")
            T.eq(button:GetAttribute("action"), TOP + index)
            T.truthy(button:IsProtected(), "protected")
            T.truthy(button:IsVisible(), "shown")
        end
    end)

    it("take the slots of the bar picked", function()
        local ns = start(on())
        set(ns, "controllerBackButtonsBarTop", 6)
        T.eq(press(1), 153)
        T.eq(shown("Top", 4):GetAttribute("action"), 156)
        set(ns, "controllerBackButtonsBarTop", 2)
        T.eq(press(1), 69, "Action Bar 2 is page 6")
    end)

    it("hide and stop acting when turned off, and come back", function()
        local ns = start(on())
        set(ns, "controllerBackButtons", false)
        T.falsy(shown("Top", 1):IsVisible(), "hidden")
        T.eq(QoLBackButton1:GetAttribute("type"), nil)
        T.eq(next(Stubs.state().overrides), nil)
        set(ns, "controllerBackButtons", true)
        T.truthy(shown("Top", 1):IsVisible(), "shown")
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
        T.falsy(shown("Top", 1):IsVisible(), "hidden")
        T.eq(QoLBackButton1:GetAttribute("type"), nil)
        T.eq(next(Stubs.state().overrides), nil)
        switch(true)
        T.truthy(shown("Top", 1):IsVisible(), "shown")
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
            set(ns, "controllerBackButtonsBarTop", 6)
            Stubs.state().bindings["F16"] = "CLICK QoLBackButton4:LeftButton"
            Stubs.Fire("UPDATE_BINDINGS")
            Stubs.RunTimers()
            Stubs.AdvanceTime()
            T.eq(shown("Top", 1):GetAttribute("action"), 177)
            T.eq(override("F16"), nil)
            -- Closing the settings saves the bindings, which fires UPDATE_BINDINGS; nothing runs then.
            settings:Hide()
            Stubs.SetControllerWindow(nil)
            Stubs.Fire("UPDATE_BINDINGS")
            Stubs.RunTimers()
            T.eq(shown("Top", 1):GetAttribute("action"), 177)
            Stubs.AdvanceTime()
            T.eq(shown("Top", 1):GetAttribute("action"), 177)
            Stubs.AdvanceTime()
            T.eq(shown("Top", 1):GetAttribute("action"), 153)
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
            local l4, l5, r4, r5 = shown("Top", 1), shown("Top", 2), shown("Top", 3), shown("Top", 4)
            T.eq(l4.icon.texture, 136048)
            T.truthy(l4.icon:IsShown(), "icon shown")
            T.same(l4.icon.vertexColor, { 1, 1, 1 })
            T.eq(l4.count:GetText(), "3")
            T.same(l4.cooldown.duration, { seconds = 8 })
            T.same(l5.icon.vertexColor, { 0.5, 0.5, 1 })
            T.same(r4.icon.vertexColor, { 0.4, 0.4, 0.4 })
            T.truthy(r4.selectedRim:IsShown(), "current action")
            T.falsy(r5.icon:IsShown(), "empty slot")
        end)

        it("updates in combat when the slot changes", function()
            start(on())
            Stubs.SetCombat(true)
            Stubs.state().actions[180] = { texture = 136048 }
            Stubs.Fire("ACTIONBAR_SLOT_CHANGED", 180)
            Stubs.RunTimers()
            T.eq(shown("Top", 4).icon.texture, 136048)
        end)

        it("hears the cooldowns only while the buttons show", function()
            local ns = start(on())
            T.eq(Stubs.Listens("SPELL_UPDATE_COOLDOWN"), true, "on")
            set(ns, "controllerBackButtons", false)
            T.eq(Stubs.Listens("SPELL_UPDATE_COOLDOWN"), false, "off")
        end)

        it("sets only what changed on a refresh", function()
            start(on(), function(state)
                state.actions[177] = { texture = 136048, count = "3" }
            end)
            local count = shown("Top", 1).count
            local textSets = count.textSets
            Stubs.Fire("SPELL_UPDATE_COOLDOWN")
            Stubs.RunTimers()
            T.eq(count.textSets, textSets, "same count")
            Stubs.state().actions[177].count = "2"
            Stubs.Fire("SPELL_UPDATE_COOLDOWN")
            Stubs.RunTimers()
            T.eq(count:GetText(), "2")
            T.eq(count.textSets, textSets + 1)
        end)

        it("looks pressed while its key is down", function()
            start(on())
            local button = shown("Top", 1)
            Stubs.SecureClick(QoLBackButton1, true)
            QoLBackButton1:RunScript("PostClick", "LeftButton", true)
            T.truthy(button.pushedRim:IsShown(), "pressed rim")
            T.eq(button.visual:GetWidth(), 34)
            QoLBackButton1:RunScript("PostClick", "LeftButton", false)
            T.falsy(button.pushedRim:IsShown(), "released")
            T.eq(button.visual:GetWidth(), 38)
        end)

        it("looks pressed while clicked with the mouse", function()
            start(on())
            local button = shown("Top", 2)
            button:RunScript("PostClick", "LeftButton", true)
            T.truthy(button.pushedRim:IsShown(), "pressed rim")
            button:RunScript("OnMouseUp")
            T.falsy(button.pushedRim:IsShown(), "let go")
        end)
    end)

    describe("spells", function()
        it("are picked up by dragging, with the bars unlocked or the pick up modifier held", function()
            start(on(), function(state) state.actions[177] = { texture = 136048 } end)
            Stubs.InstallSettings()
            shown("Top", 1):RunScript("OnDragStart")
            T.eq(Stubs.state().cursor, 177)

            Stubs.state().cursor = nil
            Stubs.state().settingValues.lockActionBars = true
            shown("Top", 1):RunScript("OnDragStart")
            T.eq(Stubs.state().cursor, nil)
            Stubs.state().modifiedClicks.PICKUPACTION = true
            shown("Top", 1):RunScript("OnDragStart")
            T.eq(Stubs.state().cursor, 177)
        end)

        it("are placed by dropping them on a button, not in combat", function()
            start(on())
            shown("Top", 2):RunScript("OnReceiveDrag")
            T.same(Stubs.state().placed, { 178 })
            Stubs.SetCombat(true)
            shown("Top", 2):RunScript("OnReceiveDrag")
            T.same(Stubs.state().placed, { 178 })
        end)

        it("show in the tooltip, or where to put one", function()
            start(on(), function(state) state.actions[177] = { texture = 136048 } end)
            shown("Top", 1):RunScript("OnEnter")
            T.eq(GameTooltip.action, 177)
            T.truthy(GameTooltip.shown, "shown")
            shown("Top", 2):RunScript("OnEnter")
            T.eq(GameTooltip.lines[1].text, "Back button L5 (lower left)")
            T.eq(GameTooltip.lines[2].text, "Empty. Drag a spell here, or onto Action Bar 8, button 10.")
            shown("Top", 2):RunScript("OnLeave")
            T.falsy(GameTooltip.shown, "hidden")
        end)
    end)

    describe("on every controller bar", function()
        it("act on a held trigger's bar without the trigger toggle, every bar's shown", function()
            start(on())
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
            T.eq(press(1), TOP + 1)
            Stubs.PressOverride(RT, true)
            T.eq(press(1), RIGHT + 1, "RT with L4 is L4 on the Right bar")
            Stubs.PressOverride(LT, true)
            T.eq(press(2), BOTTOM + 2, "both held: Bottom")
            Stubs.PressOverride(RT, false)
            T.eq(press(3), LEFT + 3, "RT let go: LT's bar")
            Stubs.PressOverride(RT, true)
            Stubs.PressOverride(LT, false)
            T.eq(press(3), RIGHT + 3, "LT let go: RT's bar")
            Stubs.PressOverride(RT, false)
            T.eq(press(1), TOP + 1, "let go: Top")
            Stubs.PressOverride(LT, true)
            T.eq(press(3), LEFT + 3)
            Stubs.PressOverride(LT, false)
            tap(RT)
            T.eq(press(1), TOP + 1, "a tap switches nothing on without the toggle")
        end)

        it("work while held in combat without the trigger toggle", function()
            start(on())
            Stubs.SetCombat(true)
            Stubs.PressOverride(LT, true)
            T.eq(press(4), LEFT + 4)
            Stubs.PressOverride(LT, false)
            T.eq(press(4), TOP + 4)
        end)

        it("act on the bar on, which the trigger toggle switches", function()
            start(withToggle())
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
            tap(RT)
            T.eq(press(1), RIGHT + 1, "L4 on the Right bar")
            T.eq(press(4), RIGHT + 4)
            tap(LT)
            T.eq(press(2), BOTTOM + 2, "LT and RT on: Bottom")
            tap(RT)
            T.eq(press(3), LEFT + 3)
            tap(LT)
            T.eq(press(1), TOP + 1, "nothing on: Top")
        end)

        it("act on a trigger's bar while it's held, a hold adding to the bar on as for the bar keys", function()
            start(withToggle())
            Stubs.PressOverride(LT, true)
            T.eq(press(1), LEFT + 1)
            Stubs.PressOverride(LT, false)
            T.eq(press(1), TOP + 1, "the hold used, so nothing switched on")
            tap(RT)
            Stubs.PressOverride(LT, true)
            T.eq(press(1), BOTTOM + 1)
            Stubs.PressOverride(LT, false)
            T.eq(press(1), RIGHT + 1)
        end)

        it("press an empty slot of the bar's own, with nothing taken from Top", function()
            start(withToggle(), function(state) state.actions[TOP + 1] = { texture = 136048 } end)
            tap(RT)
            T.eq(press(1), RIGHT + 1)
        end)

        it("work in combat", function()
            start(withToggle())
            Stubs.SetCombat(true)
            tap(RT)
            T.eq(press(1), RIGHT + 1)
            tap(RT)
            T.eq(press(1), TOP + 1)
        end)

        it("go back to Top, holds still working, when the trigger toggle is turned off", function()
            local ns = start(withToggle())
            tap(RT)
            set(ns, "controllerTriggerToggle", false)
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
            T.eq(press(1), TOP + 1)
            Stubs.PressOverride(RT, true)
            T.eq(press(1), RIGHT + 1)
            Stubs.PressOverride(RT, false)
        end)

        it("give the triggers back when they're turned off", function()
            local ns = start(on())
            T.truthy(override(RT), "the triggers are ours while the back buttons are on")
            set(ns, "controllerBackButtons", false)
            T.eq(override(RT), nil)
        end)

        it("take each bar's slots from the action bar picked for it", function()
            local ns = start(withToggle())
            set(ns, "controllerBackButtonsBarRight", 3)
            T.eq(shown("Right", 1):GetAttribute("action"), 57, "Action Bar 3 is page 5")
            tap(RT)
            T.eq(press(1), 57)
        end)

        it("keep the same slots on every page", function()
            local _, bar = start(withToggle())
            Stubs.FlipPage(bar, 2)
            tap(RT)
            T.eq(press(1), RIGHT + 1)
            T.eq(shown("Right", 1):GetAttribute("action"), RIGHT + 1)
        end)

        it("look pressed on the bar the key acted on", function()
            start(withToggle())
            tap(RT)
            Stubs.SecureClick(QoLBackButton1, true)
            QoLBackButton1:RunScript("PostClick", "LeftButton", true)
            T.truthy(shown("Right", 1).pushedRim:IsShown(), "Right's L4")
            T.falsy(shown("Top", 1).pushedRim:IsShown(), "not Top's")
            QoLBackButton1:RunScript("PostClick", "LeftButton", false)
            T.falsy(shown("Right", 1).pushedRim:IsShown(), "let go")
        end)

        it("take spells dropped on them, and name their own slot when empty", function()
            start(withToggle())
            local button = shown("Right", 1)
            button:RunScript("OnReceiveDrag")
            T.same(Stubs.state().placed, { RIGHT + 1 })
            button:RunScript("OnEnter")
            T.eq(GameTooltip.lines[1].text, "Back button L4 (upper left), Right bar")
            T.eq(GameTooltip.lines[2].text, "Empty. Drag a spell here, or onto Action Bar 6, button 9.")
        end)

        it("show each icon from its own slot", function()
            start(withToggle(), function(state) state.actions[BOTTOM + 3] = { texture = 132222 } end)
            T.eq(shown("Bottom", 3).icon.texture, 132222)
            T.falsy(shown("Top", 3).icon:IsShown(), "Top's own is empty")
        end)

        it("sit in a grid at the far left and right in the full layout, a row per bar", function()
            local _, bar = start(on())
            for _, name in ipairs(BARS) do
                T.same({ shown(name, 1):GetParent():GetPoint() }, { "CENTER", bar.PageUnit, "CENTER", 0, 0 }, name)
            end
            local function at(name, index)
                local point = { shown(name, index):GetPoint() }
                return { point[4], point[5] }
            end
            T.same({ at("Top", 1), at("Top", 2), at("Top", 3), at("Top", 4) },
                { { -421, 66 }, { -377, 66 }, { 421, 66 }, { 377, 66 } }, "L4 and R4 outside, L5 and R5 inside")
            T.same({ at("Left", 1), at("Right", 1), at("Bottom", 1) }, { { -421, 22 }, { -421, -22 }, { -421, -66 } },
                "Top, Left, Right, Bottom from the top")
            T.same({ shown("Top", 1).label:GetPoint() }, { "TOP", shown("Top", 1), "TOP", 0, -1 }, "the name on it")
            -- They show, hide and scale with the controller bar.
            bar:Hide()
            T.same(showing(), {})
        end)

        it("hide with a bar the game hides, as an empty one", function()
            start(withToggle())
            Stubs.ShowGameBar("leftBar", false)
            settle()
            T.same(showing(), { "Top", "Right", "Bottom" })
            Stubs.ShowGameBar("leftBar", true)
            settle()
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
        end)

        it("hide on the special page", function()
            start(withToggle())
            Stubs.ShowSpecialPage(true)
            settle()
            T.same(showing(), {})
            Stubs.ShowSpecialPage(false)
            settle()
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
        end)

        it("stay with their own actions under a stance or possess bar in the bar's place", function()
            start(withToggle())
            Stubs.OverrideGameBar("stanceBar", "leftBar")
            settle()
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
            tap(LT)
            T.eq(press(1), LEFT + 1)
            Stubs.OverrideGameBar("stanceBar", nil)
            Stubs.state().cvars.GamepadPossessBarOverride = tostring(Enum.GamepadPossessBarOverride.Page1RightBar)
            Stubs.OverrideGameBar("possessBar", "rightBar")
            settle()
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
        end)

        it("wait for the end of combat to show or hide with a bar", function()
            start(withToggle())
            Stubs.SetCombat(true)
            Stubs.ShowGameBar("leftBar", false)
            settle()
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
            Stubs.SetCombat(false)
            settle()
            T.same(showing(), { "Top", "Right", "Bottom" })
        end)

        describe("in the compact layout", function()
            local function compact(saved)
                local ns, bar = start(saved)
                Stubs.SetCompactLayout(true)
                settle()
                return ns, bar
            end

            it("show only the bar the press goes to, beside it", function()
                local _, bar = compact(withToggle())
                T.same(showing(), { "Top" })
                local holder = shown("Top", 1):GetParent()
                T.same({ holder:GetPoint() }, { "CENTER", bar.PageUnit.TopCenteredAnchor, "CENTER", 0, 0 })
                local function at(index)
                    local point = { shown("Top", index):GetPoint() }
                    return { point[4], point[5] }
                end
                T.same({ at(1), at(2), at(3), at(4) }, { { -182, 26 }, { -182, -26 }, { 182, 26 }, { 182, -26 } })
                tap(RT)
                T.same(showing(), { "Right" }, "the bar on, while the game shows Top's eight")
                T.eq(press(1), RIGHT + 1)
                local point = { shown("Right", 1):GetPoint() }
                T.same({ point[4], point[5] }, { -182, 26 })
            end)

            it("follow the bar on in combat", function()
                compact(withToggle())
                Stubs.SetCombat(true)
                tap(LT)
                T.same(showing(), { "Left" })
                Stubs.PressOverride(RT, true)
                T.same(showing(), { "Bottom" }, "a hold too")
                T.eq(press(1), BOTTOM + 1, "used, so letting go switches nothing on")
                Stubs.PressOverride(RT, false)
                T.same(showing(), { "Left" })
            end)

            it("show Top's with the trigger toggle off", function()
                compact(on())
                T.same(showing(), { "Top" })
            end)

            it("go back to the full layout", function()
                compact(withToggle())
                Stubs.SetCompactLayout(false)
                settle()
                T.same(showing(), { "Top", "Left", "Right", "Bottom" })
                local point = { shown("Top", 1):GetPoint() }
                T.same({ point[4], point[5] }, { -421, 66 })
            end)

            it("hide on the special page", function()
                compact(withToggle())
                Stubs.ShowSpecialPage(true)
                settle()
                T.same(showing(), {})
            end)

            it("hide with the one bar the game shows, hidden as empty", function()
                compact(withToggle())
                tap(RT)
                Stubs.ShowGameBar("topBar", false)
                settle()
                T.same(showing(), {})
                Stubs.ShowGameBar("topBar", true)
                settle()
                T.same(showing(), { "Right" })
            end)
        end)
    end)
end)

-- The setters the back buttons and the rings share (Core/Buttons.lua).
describe("action button setters", function()
    -- A region that counts the calls that change it.
    local function region()
        local calls = { texture = 0, color = 0, cooldown = 0 }
        return {
            calls = calls,
            SetTexture = function() calls.texture = calls.texture + 1 end,
            SetVertexColor = function() calls.color = calls.color + 1 end,
            SetCooldown = function() calls.cooldown = calls.cooldown + 1 end,
        }
    end

    it("sets an icon's texture and tint only when each changed, the one not undoing the other's", function()
        local ns = Stubs.LoadAddon({})
        local icon = region()
        for _ = 1, 3 do
            ns.Buttons.SetIcon(icon, 134414)
            ns.Buttons.SetUsable(icon, true, false)
        end
        T.eq(icon.calls.texture, 1)
        T.eq(icon.calls.color, 1)
        ns.Buttons.SetUsable(icon, false, true)
        T.eq(icon.calls.color, 2, "a new tint")
        T.eq(icon.calls.texture, 1)
    end)

    it("sets a secret cooldown every time without comparing it", function()
        local ns = Stubs.LoadAddon({})
        local cooldown = region()
        ns.Buttons.SetCooldown(cooldown, 100, 30)
        ns.Buttons.SetCooldown(cooldown, 100, 30)
        T.eq(cooldown.calls.cooldown, 1)
        ns.Buttons.SetCooldown(cooldown, Stubs.SECRET, Stubs.SECRET)
        ns.Buttons.SetCooldown(cooldown, Stubs.SECRET, 30)
        T.eq(cooldown.calls.cooldown, 3)
    end)
end)
