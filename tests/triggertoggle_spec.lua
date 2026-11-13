local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local LT, RT = "PADLTRIGGER", "PADRTRIGGER"
-- The eight keys of a bar, by the game's button index: D-pad left, up, right, down, then X, Y, B, A.
local KEYS = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1" }
local A = "PAD1"

-- The next frames, and the check for the controller's windows that lets the changes go.
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
    settle()
    return ns, bar
end

-- Saved options with the trigger toggle on (a new table each time: the options are saved into it).
local function on() return { controllerTriggerToggle = true } end

local function down(key) Stubs.PressOverride(key, true) end
local function up(key) Stubs.PressOverride(key, false) end
local function tap(key) Stubs.PressOverride(key) end

local function gameButton(bar, name, index)
    return bar.PageUnit.actionBars[name .. "Bar"].actionButtons[index]
end

-- What a key reaches now, pressed and let go: the game's button we click, or nil where nothing of
-- ours is bound, so that the game's own binding has it (its active bar, Top).
local function reached(key)
    local state = Stubs.state()
    if not state.overrides[key] then return nil end
    local before = #state.barClicks
    tap(key)
    return state.barClicks[before + 1]
end

-- The slot the last press used.
local function lastSlot()
    local used = Stubs.state().usedActions
    return used[#used]
end

-- The bar the marker shows on: the game's trigger glow behind it, on its anchor.
local function marked(bar)
    local anchors = { left = bar.PageUnit.LeftCenteredAnchor, right = bar.PageUnit.RightCenteredAnchor,
        bottom = bar.PageUnit.BottomCenteredAnchor }
    local found
    for _, region in ipairs(Stubs.state().regions) do
        if region.atlas == "gamepad-actionbar-fx-trigger-behind" and region:IsVisible() then
            local _, anchor = region:GetPoint()
            for name, frame in pairs(anchors) do
                if frame == anchor then
                    T.eq(found, nil, "one marker")
                    found = name
                end
            end
        end
    end
    return found
end

-- A game window takes the controller, and gives it back. Our changes wait half a second at least
-- after it closed: two checks that find no window.
local function openWindow()
    Stubs.SetControllerWindow(CreateFrame("Frame"))
    Stubs.TriggerRegistry("Gamepad.RefreshFrameFocus")
    settle()
end

local function closeWindow()
    Stubs.SetControllerWindow(nil)
    Stubs.TriggerRegistry("Gamepad.RefreshFrameFocus")
    settle()
    settle()
end

-- The player turns the controller interface on or off.
local function switch(enabled)
    Stubs.SetControllerUI(enabled)
    Stubs.Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
    settle()
end

describe("trigger toggle", function()
    it("is off by default: nothing is made or bound", function()
        start()
        T.eq(QoLTriggerToggle, nil)
        T.eq(next(Stubs.state().overrides), nil)
    end)

    it("does nothing without the controller action bar (not Forever)", function()
        Stubs.LoadAddon()
        Stubs.Login(on())
        settle()
        T.eq(QoLTriggerToggle, nil)
        T.eq(next(Stubs.state().overrides), nil)
    end)

    it("switches a bar on with a press and off with another", function()
        local _, bar = start(on())
        T.eq(reached(A), nil, "Top before")
        tap(LT)
        T.eq(reached(A), gameButton(bar, "left", 8))
        tap(LT)
        T.eq(reached(A), nil, "Top again")
        tap(RT)
        T.eq(reached(A), gameButton(bar, "right", 8))
        tap(RT)
        T.eq(reached(A), nil, "Top again")
    end)

    it("gives Bottom for LT and RT one after the other, each a switch of its own", function()
        local _, bar = start(on())
        tap(LT)
        tap(RT)
        T.eq(reached(A), gameButton(bar, "bottom", 8))
        tap(LT)
        T.eq(reached(A), gameButton(bar, "right", 8), "LT taken away leaves Right")
        tap(LT)
        tap(RT)
        T.eq(reached(A), gameButton(bar, "left", 8), "RT taken away leaves Left")
    end)

    it("takes both triggers pressed together as one action, there and back", function()
        local _, bar = start(on())
        local function together()
            down(LT)
            down(RT)
            up(RT)
            up(LT)
        end
        together()
        T.eq(reached(A), gameButton(bar, "bottom", 8))
        together()
        T.eq(reached(A), nil, "Top again")
    end)

    it("goes to Bottom from one trigger's bar when both are pressed together", function()
        local _, bar = start(on())
        tap(LT)
        down(LT)
        down(RT)
        up(LT)
        up(RT)
        T.eq(reached(A), gameButton(bar, "bottom", 8))
    end)

    it("lets a trigger held with a button work as it does, and brings back the bar on", function()
        local _, bar = start(on())
        down(LT)
        T.eq(reached(A), gameButton(bar, "left", 8), "while held")
        up(LT)
        T.eq(reached(A), nil, "not switched on")
        tap(RT)
        down(LT)
        T.eq(reached(A), gameButton(bar, "bottom", 8), "held on top of Right")
        up(LT)
        T.eq(reached(A), gameButton(bar, "right", 8), "the bar on is back")
    end)

    it("doesn't switch off the bar on when held with a button", function()
        local _, bar = start(on())
        tap(LT)
        down(LT)
        reached(A)
        up(LT)
        T.eq(reached(A), gameButton(bar, "left", 8))
    end)

    it("counts a trigger held and let go with nothing pressed as a press", function()
        local _, bar = start(on())
        down(LT)
        Stubs.AdvanceTime()
        up(LT)
        T.eq(reached(A), gameButton(bar, "left", 8))
    end)

    it("takes all eight keys of a bar, with every modifier, and no other key", function()
        local _, bar = start(on())
        tap(LT)
        for index, key in ipairs(KEYS) do
            T.eq(reached(key), gameButton(bar, "left", index), key)
            T.eq(reached("SHIFT-" .. key), gameButton(bar, "left", index), "with a trigger acting as shift")
            T.eq(reached("ALT-CTRL-SHIFT-" .. key), gameButton(bar, "left", index))
        end
        local overrides = Stubs.state().overrides
        for _, key in ipairs({ "PADLSHOULDER", "PADRSHOULDER", "PADLSTICK", "PADRSTICK", "PADPADDLE1" }) do
            T.eq(overrides[key], nil, key)
        end
        local count = 0
        for _ in pairs(overrides) do count = count + 1 end
        T.eq(count, 8 * 8 + 2 * 8, "the bar's keys and the triggers, in the eight modifier sets")
    end)

    it("takes both triggers with the modifiers the game can make of them", function()
        local _, bar = start(on())
        tap("SHIFT-" .. LT)
        T.eq(reached(A), gameButton(bar, "left", 8))
        tap("CTRL-" .. RT)
        T.eq(reached(A), gameButton(bar, "bottom", 8))
    end)

    it("uses plain overrides, so that the priority ones of the game's windows win", function()
        start(on())
        tap(LT)
        T.eq(next(Stubs.state().priorityOverrides), nil)
    end)

    it("works in combat", function()
        local _, bar = start(on())
        Stubs.SetCombat(true)
        tap(LT)
        T.eq(reached(A), gameButton(bar, "left", 8))
        tap(LT)
        T.eq(reached(A), nil)
    end)

    it("counts a back button pressed during a hold as using the trigger", function()
        local _, bar = start({ controllerTriggerToggle = true, controllerBackButtons = true })
        down(LT)
        Stubs.SecureClick(QoLBackButton1, true)
        Stubs.SecureClick(QoLBackButton1, false)
        up(LT)
        T.eq(reached(A), nil, "nothing switched on")
        T.eq(Stubs.state().usedActions[1], 165, "and the back button acted, L4 on the Left bar")
        tap(LT)
        T.eq(reached(A), gameButton(bar, "left", 8), "a press alone still switches it")
    end)

    it("sees the back buttons made after it too", function()
        local ns = start(on())
        ns.Options:Set("controllerBackButtons", true)
        settle()
        down(LT)
        Stubs.SecureClick(QoLBackButton2, true)
        up(LT)
        T.eq(reached(A), nil)
    end)

    it("marks the bar on, also during a hold", function()
        local _, bar = start(on())
        T.eq(marked(bar), nil)
        tap(LT)
        T.eq(marked(bar), "left")
        tap(RT)
        T.eq(marked(bar), "bottom")
        tap(LT)
        T.eq(marked(bar), "right")
        tap(RT)
        T.eq(marked(bar), nil)
        down(RT)
        T.eq(marked(bar), "right", "during a hold")
        reached(A)
        up(RT)
        T.eq(marked(bar), nil)
    end)

    it("draws the marker in combat too, and hides it with the bar", function()
        local _, bar = start(on())
        Stubs.SetCombat(true)
        tap(LT)
        T.eq(marked(bar), "left")
        bar:Hide()
        T.eq(marked(bar), nil)
    end)

    it("makes the marker taller while back buttons show beside the bars", function()
        local function height()
            for _, region in ipairs(Stubs.state().regions) do
                if region.atlas == "gamepad-actionbar-fx-trigger-behind" and region:IsVisible() then
                    local _, h = region:GetSize()
                    return h
                end
            end
        end
        local ns, bar = start(on())
        tap(LT)
        T.eq(height(), 160)
        ns.Options:Set("controllerBackButtons", true)
        settle()
        T.eq(marked(bar), "left")
        T.eq(height(), 224, "covering the bar's back buttons")
        ns.Options:Set("controllerBackButtons", false)
        settle()
        T.eq(height(), 160)
    end)

    describe("after combat", function()
        it("goes back to Top", function()
            local _, bar = start(on())
            Stubs.SetCombat(true)
            tap(LT)
            Stubs.SetCombat(false)
            settle()
            T.eq(reached(A), nil)
            T.eq(marked(bar), nil)
            tap(LT)
            T.eq(reached(A), gameButton(bar, "left", 8), "a single press switches it on again")
        end)

        it("stays with the setting off", function()
            local _, bar = start({ controllerTriggerToggle = true, controllerTriggerToggleTopAfterCombat = false })
            Stubs.SetCombat(true)
            tap(LT)
            Stubs.SetCombat(false)
            settle()
            T.eq(reached(A), gameButton(bar, "left", 8))
        end)

        it("waits for a window that has the controller", function()
            local _, bar = start(on())
            Stubs.SetCombat(true)
            tap(LT)
            openWindow()
            Stubs.SetCombat(false)
            settle()
            T.eq(reached(A), gameButton(bar, "left", 8), "nothing changes while it's open")
            closeWindow()
            T.eq(reached(A), nil)
        end)
    end)

    describe("a possess or vehicle bar", function()
        it("takes no press while it's up, so nothing comes on after it", function()
            local _, bar = start(on())
            Stubs.SetMacroCondition("vehicleui", true)
            tap(LT)
            T.eq(reached(A), nil, "the game has A")
            T.eq(marked(bar), nil)
            Stubs.SetMacroCondition("vehicleui", false)
            T.eq(reached(A), nil, "still off")
        end)

        it("lets a hold reach the possess bar where it has taken that bar", function()
            local _, bar = start(on(), function(state) state.cvars.GamepadPossessBarOverride = "2" end)
            Stubs.SetMacroCondition("possessbar", true)
            Stubs.ShowGameBar("possessBar", true)
            down(LT)
            T.eq(reached(A), gameButton(bar, "possess", 8))
            up(LT)
            T.eq(reached(A), nil)
        end)

        for _, condition in ipairs({ "possessbar", "vehicleui", "overridebar" }) do
            it("switches the bar on off in combat: " .. condition, function()
                local _, bar = start(on())
                Stubs.SetCombat(true)
                tap(LT)
                Stubs.SetMacroCondition(condition, true)
                T.eq(reached(A), nil, "the game's bar has the keys")
                T.eq(marked(bar), nil)
                Stubs.SetMacroCondition(condition, false)
                T.eq(reached(A), nil, "it stays off")
            end)
        end

        it("doesn't switch a bar on when the trigger held then is let go", function()
            start(on())
            down(LT)
            Stubs.SetMacroCondition("vehicleui", true)
            up(LT)
            T.eq(reached(A), nil)
        end)
    end)

    describe("a game window", function()
        it("hides the marker and brings it back with the bar still on", function()
            local _, bar = start(on())
            tap(LT)
            openWindow()
            T.eq(marked(bar), nil, "not under the window")
            closeWindow()
            T.eq(marked(bar), "left", "back with the window closed")
            T.eq(reached(A), gameButton(bar, "left", 8), "and the bar on with it")
        end)

        it("does the same in combat", function()
            local _, bar = start(on())
            Stubs.SetCombat(true)
            tap(LT)
            openWindow()
            T.eq(marked(bar), nil)
            closeWindow()
            T.eq(marked(bar), "left")
        end)

        it("gives back a trigger whose release it took", function()
            local _, bar = start(on())
            down(LT)
            openWindow()
            closeWindow()
            T.eq(reached(A), nil, "not held any more")
            T.eq(marked(bar), nil)
        end)

        it("ignores a release it never saw the press of", function()
            local _, bar = start(on())
            up(LT)
            T.eq(reached(A), nil)
            T.eq(marked(bar), nil)
        end)

        it("changes nothing while it's open", function()
            local ns = start(on())
            openWindow()
            local calls = Stubs.state().overrideCalls
            ns.Options:Set("controllerTriggerToggle", false)
            settle()
            T.eq(Stubs.state().overrideCalls, calls)
            T.truthy(Stubs.state().overrides[LT], "still bound")
            closeWindow()
            T.eq(next(Stubs.state().overrides), nil, "gone once it's closed")
        end)
    end)

    describe("the page and the stance", function()
        it("follows the page", function()
            local _, bar = start(on())
            tap(LT)
            Stubs.FlipPage(bar, 2)
            T.eq(reached(A), gameButton(bar, "left", 8))
            T.eq(lastSlot(), 192 + 28, "that page's Left")
        end)

        it("goes to the stance bar's button where it has taken the bar on, in combat too", function()
            local _, bar = start(on(), function(state) state.cvars.GamepadStanceBarOverride = "2" end)
            tap(LT)
            Stubs.SetCombat(true)
            Stubs.SetStance(3)
            T.eq(reached(A), gameButton(bar, "stance", 8))
            T.eq(lastSlot(), 265 + 2 * 8 + 7, "the stance's slot")
            Stubs.SetStance(0)
            T.eq(reached(A), gameButton(bar, "left", 8))
        end)

        it("stays on the bar on where the stance bar has another bar or another page", function()
            local _, bar = start(on(), function(state) state.cvars.GamepadStanceBarOverride = "3" end)
            tap(LT)
            Stubs.SetStance(3)
            T.eq(reached(A), gameButton(bar, "left", 8), "the stance bar is on Right")
            tap(LT)
            tap(RT)
            T.eq(reached(A), gameButton(bar, "stance", 8))
            Stubs.FlipPage(bar, 2)
            T.eq(reached(A), gameButton(bar, "right", 8), "page 2 has no stance bar")
        end)

        it("goes to the stance bar's button on the page the setting names", function()
            local _, bar = start(on(), function(state) state.cvars.GamepadStanceBarOverride = "6" end)
            tap(LT)
            Stubs.SetStance(3)
            T.eq(reached(A), gameButton(bar, "left", 8), "the stance bar is on page 2")
            Stubs.FlipPage(bar, 2)
            T.eq(reached(A), gameButton(bar, "stance", 8))
        end)

        it("follows the game's Stance bar setting when it changes", function()
            local _, bar = start(on())
            tap(LT)
            Stubs.state().cvars.GamepadStanceBarOverride = "2"
            Stubs.Fire("GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED")
            settle()
            Stubs.SetStance(3)
            T.eq(reached(A), gameButton(bar, "stance", 8))
        end)

        it("presses a following bar's button, which holds the stance's slot", function()
            local ns, bar = start(on())
            ns.FollowingBars:SetTicked("left", true)
            settle()
            tap(LT)
            Stubs.SetStance(3)
            T.eq(reached(A), gameButton(bar, "left", 8))
            T.eq(lastSlot(), 305 + 7)
        end)

        it("uses a macro in the slot directly: it wouldn't run from our macro", function()
            local state
            local _, bar = start(on(), function(s) state = s end)
            state.actions[192] = { texture = "macro", macro = true }
            tap(LT)
            local before = #state.barClicks
            tap(A)
            T.eq(lastSlot(), 192)
            T.eq(#state.barClicks, before, "not through the game's button")
            state.actions[192] = nil
            T.eq(reached(A), gameButton(bar, "left", 8), "and through it again without one")
        end)
    end)

    describe("LB and RB", function()
        for _, key in ipairs({ "friendlyTargeting", "hostileTargeting", "shortcuts" }) do
            it("leave the keys to " .. key .. " with a bar on", function()
                local _, bar = start(on())
                tap(LT)
                Stubs.ShowGameBar(key .. "Bar", true)
                T.eq(reached(A), gameButton(bar, key, 8))
                Stubs.ShowGameBar(key .. "Bar", false)
                T.eq(reached(A), gameButton(bar, "left", 8))
            end)
        end

        it("don't take a trigger held: it wins, as without the toggle", function()
            local _, bar = start(on())
            down(LT)
            Stubs.ShowGameBar("friendlyTargetingBar", true)
            T.eq(reached(A), gameButton(bar, "left", 8))
        end)
    end)

    describe("a switch of interfaces", function()
        it("turns off and clears on the way to the keyboard, and works again on the way back", function()
            local _, bar = start(on())
            tap(LT)
            switch(false)
            T.eq(next(Stubs.state().overrides), nil, "nothing bound")
            T.eq(marked(bar), nil)
            switch(true)
            T.eq(reached(A), nil, "the bar on didn't carry over")
            tap(LT)
            T.eq(reached(A), gameButton(bar, "left", 8))
        end)

        it("appears on the first switch after a login with keyboard and mouse", function()
            local _, bar = start(on(), function() Stubs.SetControllerUI(false) end)
            T.eq(QoLTriggerToggle, nil)
            switch(true)
            tap(LT)
            T.eq(reached(A), gameButton(bar, "left", 8))
        end)
    end)

    it("clears everything when turned off, and comes back", function()
        local ns, bar = start(on())
        tap(LT)
        ns.Options:Set("controllerTriggerToggle", false)
        settle()
        T.eq(next(Stubs.state().overrides), nil)
        T.eq(marked(bar), nil)
        ns.Options:Set("controllerTriggerToggle", true)
        settle()
        T.eq(reached(A), nil)
        tap(LT)
        T.eq(reached(A), gameButton(bar, "left", 8))
    end)

    it("waits for the end of combat to appear", function()
        local ns, bar = start()
        Stubs.SetCombat(true)
        ns.Options:Set("controllerTriggerToggle", true)
        settle()
        T.eq(QoLTriggerToggle, nil)
        Stubs.SetCombat(false)
        settle()
        tap(LT)
        T.eq(reached(A), gameButton(bar, "left", 8))
    end)
end)
