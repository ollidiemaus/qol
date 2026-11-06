local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- The first page's normal slots: the Top bar takes 181 to 184 (its face buttons have none). The
-- spec checks which slot each game button holds, never what the feature keeps.
local NORMAL = { top = 181, left = 185, right = 193, bottom = 201 }
-- The same bars on pages 2 and 3, 28 slots further each.
local PAGE2_LEFT, PAGE3_LEFT = 213, 241
local PAGE2_TOP = 209
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

-- The slots a bar's buttons hold (eight, or count), and that each shows the action it presses.
local function holds(frame, name, first, count)
    for index = 1, count or 8 do
        local game = button(frame, name, index)
        T.eq(game:GetID(), first + index - 1, name .. " button " .. index)
        T.eq(game.action, first + index - 1, name .. " button " .. index .. "'s action")
    end
end

-- The slots the Top bar's D-pad half holds. Its face buttons never hold one.
local function holdsTop(frame, first)
    holds(frame, "top", first, 4)
    for index = 5, 8 do
        local game = button(frame, "top", index)
        T.eq(game:GetID(), 0, "top face button " .. index)
        T.eq(game.action, 0, "top face button " .. index .. "'s action")
    end
end

-- Puts a spell in each of the eight slots from first; each has an icon of its own.
local function fill(first)
    local actions = Stubs.state().actions
    for slot = first, first + 7 do actions[slot] = { texture = "icon" .. slot } end
end

-- The bar holds those slots and draws what's in them, a hidden icon for an empty one.
local function draws(frame, name, first)
    holds(frame, name, first)
    for index = 1, 8 do
        local slot = Stubs.state().actions[first + index - 1]
        T.eq(button(frame, name, index).icon, slot and slot.texture, name .. " button " .. index .. "'s icon")
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

    it("shows pages 2 and 3 as usual in a stance", function()
        local ns, bar = start()
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        Stubs.FlipPage(bar, 2)
        holds(bar, "left", PAGE2_LEFT)
        Stubs.FlipPage(bar, 3)
        holds(bar, "left", PAGE3_LEFT)
    end)

    it("shows the stance's slots again on flipping back to page 1, also in combat", function()
        local ns, bar = start()
        fill(NORMAL.left)
        fill(SPARE)
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        Stubs.SetCombat(true)
        Stubs.FlipPage(bar, 2)
        Stubs.FlipPage(bar, 1)
        draws(bar, "left", SPARE)
        Stubs.SetCombat(false)
    end)

    it("draws the stance's actions when the normal slots are empty, also in combat", function()
        local ns, bar = start()
        fill(SPARE)
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        Stubs.SetCombat(true)
        Stubs.FlipPage(bar, 2)
        Stubs.FlipPage(bar, 1)
        draws(bar, "left", SPARE)
        Stubs.SetCombat(false)
    end)

    it("draws an empty stance slot empty, whatever the normal slot holds", function()
        local ns, bar = start()
        fill(NORMAL.left)
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        Stubs.FlipPage(bar, 2)
        Stubs.FlipPage(bar, 1)
        draws(bar, "left", SPARE)
    end)

    it("handles a bar of mixed slots, and flips again after that", function()
        local ns, bar = start()
        local actions = Stubs.state().actions
        actions[NORMAL.left] = { texture = "normal" }
        actions[SPARE + 1] = { texture = "stance" }
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        for _ = 1, 2 do
            Stubs.FlipPage(bar, 2)
            Stubs.FlipPage(bar, 1)
            draws(bar, "left", SPARE)
        end
    end)

    it("shows page 1's normal slots after leaving the stance on another page", function()
        local ns, bar = start()
        fill(NORMAL.left)
        fill(SPARE)
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        Stubs.FlipPage(bar, 2)
        Stubs.SetStance(0)
        holds(bar, "left", PAGE2_LEFT)
        Stubs.FlipPage(bar, 1)
        draws(bar, "left", NORMAL.left)
    end)

    it("leaves pages 2 and 3 alone when the stance changes on them, and follows on flipping back", function()
        local ns, bar = start()
        tick(ns, "left")
        Stubs.FlipPage(bar, 2)
        Stubs.SetStance(BEAR)
        holds(bar, "left", PAGE2_LEFT)
        Stubs.SetStance(CAT)
        holds(bar, "left", PAGE2_LEFT)
        Stubs.FlipPage(bar, 1)
        holds(bar, "left", SPARE + 8)
    end)

    it("leaves other pages alone when the ticks change, and page 1 gets them on flipping back", function()
        local ns, bar = start()
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        Stubs.FlipPage(bar, 2)
        tick(ns, "left", false)
        holds(bar, "left", PAGE2_LEFT)
        Stubs.FlipPage(bar, 1)
        holds(bar, "left", NORMAL.left)
    end)

    it("leaves the game's bar alone on flipping back", function()
        local ns, bar = start()
        tick(ns, "left")
        Stubs.state().cvars.GamepadStanceBarOverride = tostring(Enum.GamepadStanceBarOverride.Page1LeftBar)
        Stubs.Fire("GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED")
        settle()
        Stubs.SetStance(BEAR)
        Stubs.FlipPage(bar, 2)
        Stubs.FlipPage(bar, 1)
        holds(bar, "left", NORMAL.left)
    end)

    it("follows the editor's own page: it flips apart from the bar", function()
        local ns, bar = start()
        local editor = _G.GamepadActionBarEditFrame
        tick(ns, "left")
        Stubs.FlipPage(editor, 2)
        Stubs.SetStance(BEAR)
        holds(bar, "left", SPARE)
        holds(editor, "left", PAGE2_LEFT)
        Stubs.FlipPage(editor, 1)
        holds(editor, "left", SPARE)
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

    it("follows with the Top bar's D-pad half, on 4 slots, and the next bar's slots come after them", function()
        local ns, bar = start()
        tick(ns, "top")
        tick(ns, "left")
        Stubs.SetStance(BEAR)
        holdsTop(bar, SPARE)
        holds(bar, "left", SPARE + 4)
        Stubs.SetStance(0)
        holdsTop(bar, NORMAL.top)
    end)

    it("keeps the Top bar's face buttons as they are, on page flips and in the editor too", function()
        local ns, bar = start()
        tick(ns, "top")
        Stubs.state().actions[NORMAL.top] = { texture = "normal" }
        Stubs.SetCombat(true)
        Stubs.SetStance(BEAR)
        Stubs.FlipPage(bar, 2)
        T.eq(button(bar, "top", 1):GetID(), PAGE2_TOP)
        for index = 5, 8 do T.eq(button(bar, "top", index):GetID(), 0) end
        Stubs.FlipPage(bar, 1)
        holdsTop(bar, SPARE)
        holdsTop(GamepadActionBarEditFrame, SPARE)
    end)

    it("keeps a Top group in the last 4 spare slots after a reload", function()
        local ns, bar = start()
        for _, name in ipairs({ "top", "left", "right", "bottom" }) do tick(ns, name) end
        Stubs.SetStance(CAT)
        tick(ns, "top", false)
        Stubs.SetStance(BEAR)
        tick(ns, "top")
        holdsTop(bar, 357)
        Stubs.SetStance(0)
        local _, after = start(QoLDB.followingBars, function(state) state.bonusBarOffset = BEAR end)
        holdsTop(after, 357)
    end)

    it("reads a saved Top group as 4 slots: the next bar's slots come right after", function()
        local ns = start()
        tick(ns, "top")
        Stubs.SetStance(BEAR)
        Stubs.SetStance(0)
        local again, bar = start(QoLDB.followingBars, function(state) state.bonusBarOffset = BEAR end)
        tick(again, "left")
        holdsTop(bar, SPARE)
        holds(bar, "left", SPARE + 4)
    end)

    it("never counts the Top bar as the game's: its setting can't name it on page 1", function()
        for _, value in ipairs({ "1", "5", "9" }) do
            local ns, bar = start(nil, function(state) state.cvars.GamepadStanceBarOverride = value end)
            T.falsy(ns.FollowingBars.IsGameBar("top"), value)
            tick(ns, "top")
            Stubs.SetStance(BEAR)
            holdsTop(bar, SPARE)
        end
        local ns = start()
        T.falsy(ns.FollowingBars.IsGameBar("top"), "with the setting unset")
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
        Stubs.FlipPage(bar, 2)
        Stubs.FlipPage(bar, 1)
        Stubs.SetStance(0)
        for key in pairs(game) do
            T.truthy(fields[key], "field " .. tostring(key))
        end
        T.same(game.hooks, {})
        _G.hooksecurefunc = hook
    end)

    describe("out of spare slots", function()
        local PROWL, MOONKIN = 2, 4
        local FIFTH_GROUP = 297
        local ALL = { "left", "right", "bottom" }

        local function as(class)
            return function(state) state.units.player.class = class end
        end

        -- Ticks Left, Right and Bottom, then enters each stance once, using 24 slots each.
        local function fillStances(ns, ...)
            for _, name in ipairs(ALL) do tick(ns, name) end
            for _, stance in ipairs({ ... }) do Stubs.SetStance(stance) end
        end

        it("goes on in the stance groups a druid doesn't use, and then stays normal", function()
            local ns, bar = start(nil, as("DRUID"))
            fillStances(ns, CAT, PROWL, BEAR)
            holds(bar, "left", 353)
            holds(bar, "right", FIFTH_GROUP)
            holds(bar, "bottom", NORMAL.bottom)
            Stubs.SetStance(MOONKIN)
            holds(bar, "left", NORMAL.left)
            holds(bar, "right", NORMAL.right)
            holds(bar, "bottom", NORMAL.bottom)
        end)

        it("gives a warrior the two groups of stances it doesn't have", function()
            local ns, bar = start(nil, as("WARRIOR"))
            tick(ns, "top")
            fillStances(ns, 1, 2)
            holdsTop(bar, 305 + 28)
            Stubs.SetStance(3)
            holdsTop(bar, 289)
            holds(bar, "left", FIFTH_GROUP)
            holds(bar, "right", NORMAL.right)
            holds(bar, "bottom", NORMAL.bottom)
        end)

        it("never takes a stance group for any other class", function()
            local ns, bar = start(nil, as("ROGUE"))
            fillStances(ns, 1, 2)
            for stance = 3, 5 do
                Stubs.SetStance(stance)
                holds(bar, "right", NORMAL.right)
                holds(bar, "bottom", NORMAL.bottom)
            end
            Stubs.SetStance(3)
            holds(bar, "left", 353)
        end)

        it("moves a bar in a stance group back on leaving the stance, and on flipping back", function()
            local ns, bar = start(nil, as("DRUID"))
            fillStances(ns, CAT, PROWL, BEAR)
            Stubs.SetStance(0)
            holds(bar, "right", NORMAL.right)
            Stubs.SetStance(BEAR)
            holds(bar, "right", FIFTH_GROUP)
            fill(NORMAL.right)
            Stubs.SetCombat(true)
            Stubs.FlipPage(bar, 2)
            Stubs.FlipPage(bar, 1)
            holds(bar, "right", FIFTH_GROUP)
        end)

        it("leaves the game's bar on the game's stance slots", function()
            local ns, bar = start(nil, function(state)
                state.units.player.class = "DRUID"
                state.cvars.GamepadStanceBarOverride = "2"
            end)
            tick(ns, "right")
            Stubs.SetStance(BEAR)
            local gameSlot = 281
            for index = 1, 8 do button(bar, "left", index):SetSecureID(gameSlot + index - 1) end
            tick(ns, "bottom")
            Stubs.SetStance(CAT)
            for index = 1, 8 do T.eq(button(bar, "left", index):GetID(), gameSlot + index - 1) end
        end)

        it("keeps a group in a stance group after a reload, and the next stays free of it", function()
            local ns = start(nil, as("DRUID"))
            fillStances(ns, CAT, PROWL, BEAR)
            Stubs.SetStance(0)
            local _, bar = start(QoLDB.followingBars, function(state)
                state.units.player.class = "DRUID"
                state.bonusBarOffset = BEAR
            end)
            holds(bar, "right", FIFTH_GROUP)
            Stubs.SetStance(MOONKIN)
            holds(bar, "left", NORMAL.left)
        end)

        it("ignores a saved group in a stance group the class uses", function()
            local ns = start(nil, as("DRUID"))
            tick(ns, "left")
            local key = ns.PlayerKey()
            local saved = { [key] = { bars = { left = true }, slots = { ["3-left"] = 281 } } }
            local _, bar = start(saved, function(state)
                state.units.player.class = "DRUID"
                state.bonusBarOffset = BEAR
            end)
            holds(bar, "left", SPARE)
        end)

        it("gives a stance that's first entered later its slots, settings untouched", function()
            local ns, bar = start(nil, as("DRUID"))
            fillStances(ns, BEAR)
            Stubs.SetStance(CAT)
            holds(bar, "left", SPARE + 24)
        end)

        it("keeps every slot handed out when the ticks change", function()
            local ns, bar = start(nil, as("DRUID"))
            fillStances(ns, CAT, PROWL, BEAR)
            tick(ns, "left", false)
            tick(ns, "bottom", false)
            tick(ns, "top")
            holds(bar, "right", FIFTH_GROUP)
            holds(bar, "left", NORMAL.left)
            tick(ns, "left")
            holds(bar, "left", 353)
            Stubs.SetStance(CAT)
            holds(bar, "right", SPARE + 8)
        end)
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
            for _, label in ipairs({ "Top bar", "Left bar", "Right bar", "Bottom bar" }) do
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

        it("says on the Top bar's row that only its D-pad half follows", function()
            local ns = settingsStart()
            T.truthy(ns.L.FOLLOWING_BAR_TOP_TIP:find("D-pad", 1, true))
            T.eq(row(ns, "Top bar").tooltip, ns.L.FOLLOWING_BAR_TOP_TIP)
            T.eq(row(ns, "Left bar").tooltip, ns.L.FOLLOWING_BAR_TIP)
        end)

        it("shows the game's bar ticked and greyed out", function()
            local ns = settingsStart(function(state) state.cvars.GamepadStanceBarOverride = "4" end)
            local c = row(ns, "Bottom bar")
            T.truthy(c.get())
            T.falsy(c.enabled())
            T.truthy(row(ns, "Left bar").enabled())
        end)

        it("leaves the Top bar's row free when the game's setting names Top on another page", function()
            local ns = settingsStart(function(state) state.cvars.GamepadStanceBarOverride = "5" end)
            local c = row(ns, "Top bar")
            T.falsy(c.get())
            T.truthy(c.enabled())
        end)

        it("has the rows in German", function()
            local ns = Stubs.LoadAddon({ locale = "deDE" })
            T.eq(ns.L.FOLLOWING_BAR_TOP, "Obere Leiste")
            T.truthy(ns.L.FOLLOWING_BAR_TOP_TIP:find("Steuerkreuz", 1, true))
            T.eq(ns.L.FOLLOWING_BAR_LEFT, "Linke Leiste")
            T.eq(ns.L.SECTION_FOLLOWING_BARS, "Leisten, die der Haltung folgen")
        end)

        describe("when something didn't fit", function()
            local LINE = "Out of slots: the bars that didn't fit stay normal in the stances that came last."

            local function openAsDruid(setup)
                local ns = settingsStart(function(state)
                    state.units.player.class = "DRUID"
                    if setup then setup(state) end
                end)
                ns.SettingsPanel:Open("controller")
                return ns
            end

            local function fillUp(ns)
                for _, name in ipairs({ "left", "right", "bottom" }) do tick(ns, name) end
                for stance = 1, 3 do Stubs.SetStance(stance) end
                settle()
            end

            local function line(ns)
                for _, text in ipairs(ns.SettingsPanel.pages.controller.texts) do
                    if text.shown then return text end
                end
                return nil
            end

            it("shows no line while everything fits", function()
                local ns = openAsDruid()
                for _, name in ipairs({ "left", "right", "bottom" }) do tick(ns, name) end
                Stubs.SetStance(1)
                Stubs.SetStance(2)
                settle()
                T.eq(line(ns).text, LINE)
                T.falsy(line(ns).string:IsShown())
            end)

            it("shows the line as soon as a bar doesn't fit, and hides it once that bar is unticked", function()
                local ns = openAsDruid()
                fillUp(ns)
                T.truthy(line(ns).string:IsShown())
                row(ns, "Bottom bar").set(false)
                settle()
                T.falsy(line(ns).string:IsShown())
            end)

            it("hides the line while the game's setting has the bar that didn't fit", function()
                local ns = openAsDruid()
                fillUp(ns)
                Stubs.state().cvars.GamepadStanceBarOverride = "4"
                Stubs.Fire("GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED", 1, 4)
                settle()
                T.falsy(line(ns).string:IsShown())
            end)

            it("still shows the line after a reload, before the stance comes up again", function()
                local ns = openAsDruid()
                fillUp(ns)
                Stubs.SetStance(0)
                local saved = QoLDB.followingBars
                local again = Stubs.LoadAddon()
                Stubs.NewGamepadBar()
                Stubs.InstallSettings()
                Stubs.SetControllerUI(true)
                Stubs.state().units.player.class = "DRUID"
                Stubs.Login(nil, nil, nil, nil, saved)
                settle()
                again.SettingsPanel:Open("controller")
                T.truthy(line(again).string:IsShown())
            end)

            it("hides the line once a bar that didn't fit gets its slots", function()
                local first = settingsStart()
                local saved = { [first.PlayerKey()] = { bars = { left = true }, full = { ["3-left"] = true } } }
                local ns = Stubs.LoadAddon()
                Stubs.NewGamepadBar()
                Stubs.InstallSettings()
                Stubs.SetControllerUI(true)
                Stubs.Login(nil, nil, nil, nil, saved)
                settle()
                ns.SettingsPanel:Open("controller")
                T.truthy(line(ns).string:IsShown())
                Stubs.SetStance(BEAR)
                settle()
                T.falsy(line(ns).string:IsShown())
            end)

            it("has the line in German", function()
                local ns = Stubs.LoadAddon({ locale = "deDE" })
                Stubs.NewGamepadBar()
                Stubs.InstallSettings()
                Stubs.SetControllerUI(true)
                Stubs.Login()
                settle()
                T.truthy(line(ns).text:find("Haltung"))
            end)
        end)

        it("isn't there off Forever", function()
            local ns = settingsStart(nil, false)
            T.falsy(ns.SettingsPanel.pages.controller)
        end)
    end)
end)
