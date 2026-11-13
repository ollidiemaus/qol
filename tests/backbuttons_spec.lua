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
-- And the trigger toggle.
local function withToggle() return { controllerBackButtons = true, controllerTriggerToggle = true } end

-- A back button's button (1 L4, 2 L5, 3 R4, 4 R5) on a controller bar; Top's keep their old names.
local BARS = { "Top", "Left", "Right", "Bottom" }
local function shown(bar, index)
    return _G["QoLBackButton" .. (bar == "Top" and "" or bar) .. index]
end

-- The controller bars whose back buttons show (in the compact layout, their art).
local function showing()
    local list = {}
    for _, bar in ipairs(BARS) do
        local button = shown(bar, 1)
        if button:IsVisible() and button.visual:GetAlpha() > 0 then list[#list + 1] = bar end
    end
    return list
end

-- The slot a back button's key on a bar (Top without one) used, pressed and let go.
local function press(index, bar)
    Stubs.PressKey(shown(bar or "Top", index))
    local used = Stubs.state().usedActions
    return used[#used]
end

local RT = "PADRTRIGGER"

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
        T.eq(_G["BINDING_NAME_CLICK QoLBackButtonRight1:LeftButton"], "Back button L4 (upper left), Right bar")
        T.eq(_G["BINDING_NAME_CLICK QoLBackButtonBottom4:LeftButton"], "Back button R5 (lower right), Bottom bar")
        local xml = assert(io.open("Bindings.xml")):read("*a")
        for _, bar in ipairs({ "", "Left", "Right", "Bottom" }) do
            for index = 1, 4 do
                local name = "QoLBackButton" .. bar .. index
                T.truthy(xml:find('name="CLICK ' .. name .. ':LeftButton"', 1, true), name)
                T.truthy(_G["BINDING_NAME_CLICK " .. name .. ":LeftButton"], "named " .. name)
            end
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

        it("give every bar's buttons keys of their own, the paddles only Top's", function()
            start(on(), function(state)
                state.bindings["F17"] = "CLICK QoLBackButtonRight1:LeftButton"
                state.bindings["F21"] = "CLICK QoLBackButtonBottom1:LeftButton"
            end)
            T.eq(override("F17"), "CLICK QoLBackButtonRight1:LeftButton")
            T.eq(override("F21"), "CLICK QoLBackButtonBottom1:LeftButton")
            T.eq(override("PADPADDLE2"), "CLICK QoLBackButton1:LeftButton", "Top's L4 still has its paddle")
            local paddles = 0
            for _, entry in pairs(Stubs.state().overrides) do
                if entry.command:find("Left%d") or entry.command:find("Right%d") or entry.command:find("Bottom%d") then
                    paddles = paddles + 1
                end
            end
            T.eq(paddles, 2, "no paddle for the other bars' buttons")
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
        -- Starts with a key bound to each of the 16, F13 to F28, so that they all show.
        local unbound = start
        local function start(saved, setup) -- luacheck: ignore 431 (this section's start)
            return unbound(saved, function(state)
                for bar, prefix in ipairs({ "", "Left", "Right", "Bottom" }) do
                    for index = 1, 4 do
                        state.bindings["F" .. (8 + bar * 4 + index)] = "CLICK QoLBackButton" .. prefix .. index .. ":LeftButton"
                    end
                end
                if setup then setup(state) end
            end)
        end

        it("show only the buttons a key presses, Top's paddles counting", function()
            unbound(on(), function(state) state.bindings["F17"] = "CLICK QoLBackButtonRight1:LeftButton" end)
            for index = 1, 4 do T.truthy(shown("Top", index):IsVisible(), "Top's " .. index .. ", its paddle") end
            T.truthy(shown("Right", 1):IsVisible(), "Right's L4, bound")
            T.falsy(shown("Right", 2):IsVisible(), "Right's L5, no key")
            T.falsy(shown("Left", 1):IsVisible(), "Left's L4, no key")
            T.falsy(shown("Bottom", 4):IsVisible(), "Bottom's R5, no key")
            -- A key bound later shows it, once out of combat.
            Stubs.SetCombat(true)
            Stubs.state().bindings["F21"] = "CLICK QoLBackButtonLeft1:LeftButton"
            Stubs.Fire("UPDATE_BINDINGS")
            settle()
            T.falsy(shown("Left", 1):IsVisible(), "waits for the end of combat")
            Stubs.SetCombat(false)
            settle()
            T.truthy(shown("Left", 1):IsVisible(), "bound now")
            -- And one taken away hides it.
            Stubs.state().bindings["F17"] = nil
            Stubs.Fire("UPDATE_BINDINGS")
            settle()
            T.falsy(shown("Right", 1):IsVisible(), "unbound")
        end)

        it("show a cross's name only with one of its buttons", function()
            unbound(on(), function(state) state.bindings["PADPADDLE2"] = "TOGGLEWORLDMAP" end)
            T.falsy(shown("Top", 1):IsVisible(), "L4's paddle is taken")
            local names = {}
            for _, region in ipairs(Stubs.state().regions) do
                if region.GetText and region:IsShown() and region:GetText() and region:GetText():find("^[LR][45]$") then
                    names[#names + 1] = region:GetText()
                end
            end
            table.sort(names)
            T.same(names, { "L5", "R4", "R5" })
        end)

        it("press each bar's slots with its own keys, every bar's shown", function()
            start(on())
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
            for index = 1, 4 do
                T.eq(press(index), TOP + index)
                T.eq(press(index, "Left"), LEFT + index)
                T.eq(press(index, "Right"), RIGHT + index)
                T.eq(press(index, "Bottom"), BOTTOM + index)
            end
        end)

        it("leave the triggers to the game", function()
            start(on())
            T.eq(override(RT), nil)
            T.eq(override("PADLTRIGGER"), nil)
        end)

        it("work in combat", function()
            start(on())
            Stubs.SetCombat(true)
            T.eq(press(1, "Right"), RIGHT + 1)
            T.eq(press(1), TOP + 1)
        end)

        it("keep their own keys with the trigger toggle on, a bar on or not", function()
            start(withToggle())
            Stubs.PressOverride(RT)
            T.eq(press(1), TOP + 1, "Top's key presses Top's")
            T.eq(press(2, "Left"), LEFT + 2)
        end)

        it("take each bar's slots from the action bar picked for it", function()
            local ns = start(on())
            set(ns, "controllerBackButtonsBarRight", 3)
            T.eq(shown("Right", 1):GetAttribute("action"), 57, "Action Bar 3 is page 5")
            T.eq(press(1, "Right"), 57)
        end)

        it("keep the same slots on every page", function()
            local _, bar = start(on())
            Stubs.FlipPage(bar, 2)
            T.eq(press(1, "Right"), RIGHT + 1)
            T.eq(shown("Right", 1):GetAttribute("action"), RIGHT + 1)
        end)

        it("look pressed on the bar of the key pressed", function()
            start(on())
            local button = shown("Right", 1)
            Stubs.SecureClick(button, true)
            button:RunScript("PostClick", "LeftButton", true)
            T.truthy(button.pushedRim:IsShown(), "Right's L4")
            T.falsy(shown("Top", 1).pushedRim:IsShown(), "not Top's")
            button:RunScript("PostClick", "LeftButton", false)
            T.falsy(button.pushedRim:IsShown(), "let go")
        end)

        it("take spells dropped on them, and name their own slot when empty", function()
            start(on())
            local button = shown("Right", 1)
            button:RunScript("OnReceiveDrag")
            T.same(Stubs.state().placed, { RIGHT + 1 })
            button:RunScript("OnEnter")
            T.eq(GameTooltip.lines[1].text, "Back button L4 (upper left), Right bar")
            T.eq(GameTooltip.lines[2].text, "Empty. Drag a spell here, or onto Action Bar 6, button 9.")
        end)

        it("show each icon from its own slot", function()
            start(on(), function(state) state.actions[BOTTOM + 3] = { texture = 132222 } end)
            T.eq(shown("Bottom", 3).icon.texture, 132222)
            T.falsy(shown("Top", 3).icon:IsShown(), "Top's own is empty")
        end)

        it("show the game's bar in use at full size and the others small, in combat too", function()
            start(on())
            local function art(name) return (shown(name, 1).visual:GetSize()) end
            T.same({ art("Top"), art("Left"), art("Right"), art("Bottom") }, { 38, 30, 30, 30 })
            T.eq((shown("Top", 1):GetSize()), 30, "a button in a cross clicks as a small one")
            Stubs.SetCombat(true)
            Stubs.SetActiveBar("rightBar")
            Stubs.RunTimers()
            T.same({ art("Top"), art("Left"), art("Right"), art("Bottom") }, { 30, 30, 38, 30 })
            Stubs.SetActiveBar("topBar")
            Stubs.RunTimers()
            T.same({ art("Top"), art("Right") }, { 38, 30 })
        end)

        it("sit in a cross per back button at the far left and right in the full layout", function()
            local _, bar = start(on())
            for _, name in ipairs(BARS) do
                T.same({ shown(name, 1):GetParent():GetPoint() }, { "CENTER", bar.PageUnit, "CENTER", 0, 0 }, name)
            end
            local function at(name, index)
                local point = { shown(name, index):GetPoint() }
                return { point[4], point[5] }
            end
            T.same({ at("Top", 1), at("Left", 1), at("Right", 1), at("Bottom", 1) },
                { { -365, 57 }, { -396, 30 }, { -334, 30 }, { -365, 3 } }, "L4's cross, upper left, bars as the game's")
            T.same({ at("Top", 2), at("Top", 3), at("Top", 4) }, { { -365, -43 }, { 365, 57 }, { 365, -43 } },
                "L5 lower left, R4 upper right, R5 lower right")
            T.falsy(shown("Top", 1).label:IsShown(), "no name on a button")
            local names = {}
            for _, region in ipairs(Stubs.state().regions) do
                if region.GetText and region:IsShown() and region:GetText() == "L4" then
                    local point = { region:GetPoint() }
                    names[#names + 1] = { point[2], point[4], point[5] }
                end
            end
            T.same(names, { { bar.PageUnit, -365, 30 } }, "the name in the cross's middle")
            -- They show, hide and scale with the controller bar.
            bar:Hide()
            T.same(showing(), {})
        end)

        it("hide with a bar the game hides, as an empty one", function()
            start(on())
            Stubs.ShowGameBar("leftBar", false)
            settle()
            T.same(showing(), { "Top", "Right", "Bottom" })
            Stubs.ShowGameBar("leftBar", true)
            settle()
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
        end)

        it("hide on the special page", function()
            start(on())
            Stubs.ShowSpecialPage(true)
            settle()
            T.same(showing(), {})
            Stubs.ShowSpecialPage(false)
            settle()
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
        end)

        it("stay with their own actions under a stance or possess bar in the bar's place", function()
            start(on())
            Stubs.OverrideGameBar("stanceBar", "leftBar")
            settle()
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
            T.eq(press(1, "Left"), LEFT + 1)
            Stubs.OverrideGameBar("stanceBar", nil)
            Stubs.state().cvars.GamepadPossessBarOverride = tostring(Enum.GamepadPossessBarOverride.Page1RightBar)
            Stubs.OverrideGameBar("possessBar", "rightBar")
            settle()
            T.same(showing(), { "Top", "Left", "Right", "Bottom" })
        end)

        it("wait for the end of combat to show or hide with a bar", function()
            start(on())
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

            it("show only the bar in use's, beside it, which alone takes the mouse", function()
                local _, bar = compact(on())
                T.same(showing(), { "Top" })
                local holder = shown("Top", 1):GetParent()
                T.same({ holder:GetPoint() }, { "CENTER", bar.PageUnit.TopCenteredAnchor, "CENTER", 0, 0 })
                local function at(name, index)
                    local point = { shown(name, index):GetPoint() }
                    return { point[4], point[5] }
                end
                T.same({ at("Top", 1), at("Top", 2), at("Top", 3), at("Top", 4) },
                    { { -182, 26 }, { -182, -26 }, { 182, 26 }, { 182, -26 } })
                T.eq(shown("Top", 1).mouseEnabled, true)
                T.eq(shown("Right", 1).mouseEnabled, false)
                Stubs.SetActiveBar("rightBar")
                settle()
                T.same(showing(), { "Right" })
                T.same(at("Right", 1), { -182, 26 })
                T.same({ shown("Right", 1):GetParent():GetPoint() },
                    { "CENTER", bar.PageUnit.RightCenteredAnchor, "CENTER", 0, 0 })
                T.eq(shown("Right", 1).mouseEnabled, true)
                T.eq(shown("Top", 1).mouseEnabled, false)
            end)

            it("follow the bar in use in combat, every key still pressing its own", function()
                compact(on())
                Stubs.SetCombat(true)
                Stubs.SetActiveBar("leftBar")
                Stubs.RunTimers()
                T.same(showing(), { "Left" })
                T.eq(press(1, "Bottom"), BOTTOM + 1)
                Stubs.SetActiveBar("topBar")
                Stubs.RunTimers()
                T.same(showing(), { "Top" })
            end)

            it("go back to the full layout", function()
                compact(on())
                Stubs.SetCompactLayout(false)
                settle()
                T.same(showing(), { "Top", "Left", "Right", "Bottom" })
                local point = { shown("Top", 1):GetPoint() }
                T.same({ point[4], point[5] }, { -365, 57 })
            end)

            it("hide on the special page", function()
                compact(on())
                Stubs.ShowSpecialPage(true)
                settle()
                T.same(showing(), {})
            end)

            it("hide with the one bar the game shows, hidden as empty", function()
                compact(on())
                Stubs.SetActiveBar("rightBar")
                settle()
                Stubs.ShowGameBar("rightBar", false)
                settle()
                T.same(showing(), {})
                Stubs.ShowGameBar("rightBar", true)
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
