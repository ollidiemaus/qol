local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- The first page's normal slots: the Top bar takes 181 to 184 (its face buttons have none). The
-- spec checks which slot each game button holds, never what the feature keeps.
local NORMAL = { left = 185, right = 193, bottom = 201 }
local BEAR, CAT = 3, 1
local SPARE = 305

-- The next frames, and the check for the controller's windows that lets the changes go.
local function settle()
    Stubs.RunTimers()
    Stubs.AdvanceTime()
end

-- Forever, with its controller action bar and the controller interface on. saved: what's in
-- QoLDB.followingBars.
local function start(saved, setup)
    local ns = Stubs.LoadAddon()
    local bar = Stubs.NewGamepadBar()
    Stubs.SetControllerUI(true)
    if setup then setup(Stubs.state()) end
    Stubs.Login(nil, nil, nil, nil, saved)
    settle()
    return ns, bar
end

local function tick(ns, name, on)
    ns.FollowingBars:SetTicked(name, on ~= false)
    settle()
end

local function button(frame, name, index)
    return frame.PageUnit.actionBars[name .. "Bar"].actionButtons[index]
end

-- The slots a bar's eight buttons hold, and that each shows the action it presses.
local function holds(frame, name, first)
    for index = 1, 8 do
        local game = button(frame, name, index)
        T.eq(game:GetID(), first + index - 1, name .. " button " .. index)
        T.eq(game.action, first + index - 1, name .. " button " .. index .. "'s action")
    end
end

describe("following bars", function()
    it("changes a ticked bar's slots on entering a stance and restores them on leaving", function()
        local ns, bar = start()
        holds(bar, "left", NORMAL.left)
        tick(ns, "left")
        holds(bar, "left", NORMAL.left)
        Stubs.SetStance(BEAR)
        holds(bar, "left", SPARE)
        holds(bar, "right", NORMAL.right)
        Stubs.SetStance(0)
        holds(bar, "left", NORMAL.left)
    end)

    it("changes the slots in combat too", function()
        local ns, bar = start()
        tick(ns, "bottom")
        Stubs.SetCombat(true)
        Stubs.SetStance(BEAR)
        holds(bar, "bottom", SPARE)
        Stubs.SetStance(0)
        holds(bar, "bottom", NORMAL.bottom)
        Stubs.SetCombat(false)
    end)

    it("gives each ticked bar different slots per stance, kept the second time", function()
        local ns, bar = start()
        tick(ns, "left")
        tick(ns, "right")
        Stubs.SetStance(BEAR)
        holds(bar, "left", SPARE)
        holds(bar, "right", SPARE + 8)
        Stubs.SetStance(CAT)
        holds(bar, "left", SPARE + 16)
        holds(bar, "right", SPARE + 24)
        Stubs.SetStance(BEAR)
        holds(bar, "left", SPARE)
        holds(bar, "right", SPARE + 8)
    end)

    it("hands out slots for a stance first entered in combat, and keeps them after a reload", function()
        local ns, bar = start()
        tick(ns, "left")
        Stubs.SetCombat(true)
        Stubs.SetStance(CAT)
        holds(bar, "left", SPARE)
        Stubs.SetCombat(false)
        local data = QoLDB.followingBars
        Stubs.SetStance(0)
        local _, after = start(data, function(state) state.bonusBarOffset = BEAR end)
        holds(after, "left", SPARE + 8)
        Stubs.SetStance(CAT)
        holds(after, "left", SPARE)
    end)

    it("moves the editor's buttons too, so that it writes to the stance's slot", function()
        local ns = start()
        tick(ns, "right")
        Stubs.SetStance(BEAR)
        holds(GamepadActionBarEditFrame, "right", SPARE)
        Stubs.SetStance(0)
        holds(GamepadActionBarEditFrame, "right", NORMAL.right)
    end)

    it("leaves an empty stance slot empty: the button stays on it", function()
        local ns, bar = start()
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        T.falsy(GetActionInfo(SPARE), "nothing placed there")
        holds(bar, "left", SPARE)
    end)

    it("saves the ticks and slots per character", function()
        local _, bar = start({ ["testmage-testrealm"] = { bars = { left = true }, slots = { ["3-left"] = SPARE + 16 } },
            ["other-testrealm"] = { bars = { right = true }, slots = { ["3-right"] = SPARE } } })
        Stubs.SetStance(BEAR)
        holds(bar, "left", SPARE + 16)
        holds(bar, "right", NORMAL.right)
    end)

    it("restores a bar that's unticked in the stance and brings its slots back when ticked again", function()
        local ns, bar = start()
        tick(ns, "left")
        tick(ns, "bottom")
        Stubs.SetStance(BEAR)
        holds(bar, "bottom", SPARE + 8)
        tick(ns, "bottom", false)
        tick(ns, "left", false)
        holds(bar, "bottom", NORMAL.bottom)
        holds(bar, "left", NORMAL.left)
        tick(ns, "bottom")
        holds(bar, "bottom", SPARE + 8)
        holds(bar, "left", NORMAL.left)
    end)

    it("leaves the bar the game's Stance bar setting names alone, and never writes the setting", function()
        local ns, bar = start(nil, function(state) state.cvars.GamepadStanceBarOverride = "2" end)
        tick(ns, "left")
        tick(ns, "right")
        Stubs.SetStance(BEAR)
        holds(bar, "left", NORMAL.left)
        holds(bar, "right", SPARE)
        T.eq(Stubs.state().cvars.GamepadStanceBarOverride, "2")
        T.eq(#Stubs.state().cvarSets, 0)
    end)

    it("hands a bar back when the game's setting comes to name it", function()
        local ns, bar = start()
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        Stubs.state().cvars.GamepadStanceBarOverride = "2"
        Stubs.Fire("GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED", 1, 2)
        settle()
        holds(bar, "left", NORMAL.left)
        Stubs.state().cvars.GamepadStanceBarOverride = "1"
        Stubs.Fire("GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED", 2, 1)
        settle()
        holds(bar, "left", SPARE)
    end)

    it("changes nothing for a character without stances", function()
        local ns, bar = start()
        tick(ns, "left")
        tick(ns, "right")
        tick(ns, "bottom")
        Stubs.SetStance(0)
        holds(bar, "left", NORMAL.left)
        T.same(QoLDB.followingBars["testmage-testrealm"].slots, {})
    end)

    it("changes nothing for a keyboard player, ticks saved or not", function()
        local ns = Stubs.LoadAddon()
        local bar = Stubs.NewGamepadBar()
        Stubs.Login(nil, nil, nil, nil, { ["testmage-testrealm"] = { bars = { left = true } } })
        settle()
        T.eq(#Stubs.state().stateDrivers, 0, "nothing secure set up")
        Stubs.SetStance(BEAR)
        holds(bar, "left", NORMAL.left)
        tick(ns, "right")
        Stubs.SetStance(0)
        Stubs.SetStance(BEAR)
        holds(bar, "right", NORMAL.right)
    end)

    it("waits for the end of combat when the ticks change", function()
        local ns, bar = start()
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        Stubs.SetCombat(true)
        tick(ns, "right")
        tick(ns, "left", false)
        holds(bar, "right", NORMAL.right)
        holds(bar, "left", SPARE)
        Stubs.SetCombat(false)
        settle()
        holds(bar, "right", SPARE + 8)
        holds(bar, "left", NORMAL.left)
    end)

    it("waits for the game's controller windows when the ticks change", function()
        local window = {}
        function window:IsShown() return true end
        local ns, bar = start()
        Stubs.SetStance(BEAR)
        Stubs.SetControllerWindow(window)
        tick(ns, "left")
        holds(bar, "left", NORMAL.left)
        Stubs.SetControllerWindow(nil)
        settle()
        settle()
        holds(bar, "left", SPARE)
    end)

    it("writes no field on the game's buttons and hooks nothing", function()
        local ns, bar = start()
        local game = button(bar, "left", 1)
        local fields = {}
        for key in pairs(game) do fields[key] = true end
        local hook = _G.hooksecurefunc
        _G.hooksecurefunc = function() error("hooksecurefunc called") end
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        Stubs.SetStance(0)
        for key in pairs(game) do
            T.truthy(fields[key], "field " .. tostring(key))
        end
        T.same(game.hooks, {})
        _G.hooksecurefunc = hook
    end)

    describe("on the Controller page", function()
        local function settingsStart(setup, forever)
            local ns = Stubs.LoadAddon()
            if forever ~= false then Stubs.NewGamepadBar() end
            Stubs.InstallSettings()
            Stubs.SetControllerUI(true)
            if setup then setup(Stubs.state()) end
            Stubs.Login()
            settle()
            return ns
        end

        local function row(ns, label)
            local page = ns.SettingsPanel.pages.controller
            for _, c in ipairs(page.controls) do
                if c.title() == label then return c end
            end
            return nil
        end

        it("ticks a bar, unticked by default, with the rows the controller cursor stops on", function()
            local ns = settingsStart()
            for _, label in ipairs({ "Left bar", "Right bar", "Bottom bar" }) do
                local c = row(ns, label)
                T.falsy(c.get())
                T.truthy(c.enabled())
                T.truthy(c.row:GetScript("OnMouseUp"), "the cursor stops on a frame with OnMouseUp")
            end
            row(ns, "Left bar").set(true)
            settle()
            T.truthy(row(ns, "Left bar").get())
            Stubs.SetStance(BEAR)
            holds(GamepadMainActionBarFrame, "left", SPARE)
        end)

        it("shows the game's bar ticked and greyed out", function()
            local ns = settingsStart(function(state) state.cvars.GamepadStanceBarOverride = "4" end)
            local c = row(ns, "Bottom bar")
            T.truthy(c.get())
            T.falsy(c.enabled())
            T.truthy(row(ns, "Left bar").enabled())
        end)

        it("has the rows in German", function()
            local ns = Stubs.LoadAddon({ locale = "deDE" })
            T.eq(ns.L.FOLLOWING_BAR_LEFT, "Linke Leiste")
            T.eq(ns.L.SECTION_FOLLOWING_BARS, "Leisten, die der Haltung folgen")
        end)

        it("isn't there off Forever", function()
            local ns = settingsStart(nil, false)
            T.falsy(ns.SettingsPanel.pages.controller)
        end)
    end)
end)
