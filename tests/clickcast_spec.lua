local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local RENEW, FLASH_HEAL, FORTITUDE, SMITE = 139, 2061, 1243, 585
local BANDAGE = 1251
local ME = "testmage-testrealm"

-- A priest with a few spells, bandages and a macro.
local function priest(state)
    state.spells[RENEW] = { name = "Renew", texture = 135953 }
    state.spells[FLASH_HEAL] = { name = "Flash Heal", texture = 135907 }
    state.spells[FORTITUDE] = { name = "Power Word: Fortitude", texture = 135987 }
    state.items[BANDAGE] = { name = "Linen Bandage", texture = 133685, count = 5, use = 746 }
    state.bags[0] = { size = 16, [1] = { itemID = BANDAGE } }
    state.macros = { { name = "Heal", texture = 134400 } }
end

local function spell(id) return { kind = "spell", id = id } end
local function bind(combination, action) return { combination = combination, action = action } end
local TARGET, MENU = { kind = "target" }, { kind = "menu" }
local BANDAGED, HEAL_MACRO = { kind = "item", id = BANDAGE }, { kind = "macro", id = "Heal" }

-- Logs in with click casting on (unless the options say otherwise) and the character's bindings
-- (none saved: a new character).
local function start(bindings, options, setup)
    local ns = Stubs.LoadAddon()
    priest(Stubs.state())
    if setup then setup(Stubs.state()) end
    Stubs.Login(options or { clickCast = true }, nil, nil, bindings and { [ME] = bindings })
    return ns
end

local function set(ns, key, value)
    ns.Options:Set(key, value)
    Stubs.RunTimers()
end

local function party(index) return Stubs.state().partyFrames[index] end

-- What was used since: the actions, joined, or nil for none.
local function usedSince(before)
    local used = Stubs.state().usedActions
    if #used == before then return nil end
    return table.concat(used, ", ", before + 1)
end

-- What pointing at the frame and clicking it with the modifiers held did.
local function click(frame, mouseButton, ...)
    local before = #Stubs.state().usedActions
    Stubs.PointAt(frame)
    Stubs.Hold(...)
    Stubs.ClickUnitFrame(frame, mouseButton)
    Stubs.Hold()
    Stubs.PointAway(frame)
    return usedSince(before)
end

-- What pressing the key (a combination) did with the mouse over the frame.
local function press(frame, combination)
    local before = #Stubs.state().usedActions
    Stubs.PointAt(frame)
    Stubs.PressOverride(combination)
    Stubs.PointAway(frame)
    return usedSince(before)
end

local function hoverBinding(key)
    local entry = Stubs.state().priorityOverrides[key]
    return entry and entry.command
end

describe("click casting", function()
    it("is off by default, and the unit frames keep the game's own clicks", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) }, {})
        T.eq(click(party(1), "LeftButton"), "target on party1")
        T.eq(click(party(1), "RightButton"), "menu on party1")
        T.eq(click(party(1), "LeftButton", "SHIFT"), nil, "the game binds no Shift-Left")
    end)

    it("casts a bound spell on the frame's unit with Shift-Left, without targeting it", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) })
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:139 on party1")
        T.eq(click(party(3), "LeftButton", "SHIFT"), "spell:139 on party3")
    end)

    it("starts a new character with Left: Target and Right: Menu", function()
        start(nil)
        T.eq(click(party(2), "LeftButton"), "target on party2")
        T.eq(click(party(2), "RightButton"), "menu on party2")
        T.same(QoLDB.clickCast[ME], { bind("BUTTON1", TARGET), bind("BUTTON2", MENU) })
    end)

    it("does nothing on a click with no binding", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) })
        T.eq(click(party(1), "LeftButton"), nil)
        T.eq(click(party(1), "RightButton"), nil)
        T.eq(click(party(1), "LeftButton", "CTRL"), nil)
    end)

    it("keeps Target and Menu working on other clicks", function()
        start({ bind("SHIFT-BUTTON1", TARGET), bind("BUTTON1", spell(FLASH_HEAL)), bind("CTRL-BUTTON3", MENU) })
        T.eq(click(party(1), "LeftButton", "SHIFT"), "target on party1")
        T.eq(click(party(1), "LeftButton"), "spell:2061 on party1")
        T.eq(click(party(1), "MiddleButton", "CTRL"), "menu on party1")
    end)

    it("uses items and macros on the frame's unit", function()
        start({ bind("BUTTON3", { kind = "item", id = BANDAGE }), bind("ALT-BUTTON1", { kind = "macro", id = "Heal" }) })
        T.eq(click(party(1), "MiddleButton"), "item:item:1251 on party1")
        T.eq(click(party(2), "LeftButton", "ALT"), "macro:Heal on party2")
    end)

    it("casts the highest rank known, by name, where spells have ranks", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) }, nil, function(state)
            state.spells[RENEW].subtext = "Rank 4"
        end)
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:Renew on party1")
    end)

    it("gives every frame the game's clicks back when turned off, and its bindings when turned on", function()
        local ns = start({ bind("SHIFT-BUTTON1", spell(RENEW)) })
        set(ns, "clickCast", false)
        T.eq(click(party(1), "LeftButton"), "target on party1")
        T.eq(click(party(1), "RightButton"), "menu on party1")
        T.eq(click(party(1), "LeftButton", "SHIFT"), nil)
        set(ns, "clickCast", true)
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:139 on party1")
        T.eq(click(party(1), "LeftButton"), nil)
    end)

    it("takes a switch flipped in combat once combat ends", function()
        local ns = start({ bind("SHIFT-BUTTON1", spell(RENEW)) }, { clickCast = false })
        Stubs.state().combat = true
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        set(ns, "clickCast", true)
        T.eq(click(party(1), "LeftButton"), "target on party1", "nothing changes in combat")
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:139 on party1")
    end)

    it("lets the game's own Click Casting win on a click it binds to a spell", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) }, nil, function(state)
            table.insert(state.clickBindings, { type = 1, actionID = SMITE, button = "LeftButton", modifiers = 1 })
        end)
        T.eq(click(party(1), "LeftButton", "SHIFT"), "game:585 on party1")
    end)
end)

describe("click casting keys", function()
    it("casts a bound key on the frame under the mouse", function()
        start({ bind("F", spell(RENEW)), bind("SHIFT-MOUSEWHEELUP", spell(FORTITUDE)) })
        T.eq(press(party(2), "F"), "spell:139 on party2")
        T.eq(press(Stubs.state().partyFrames[4], "SHIFT-MOUSEWHEELUP"), "spell:1243 on party4")
    end)

    it("leaves the key to the game when the mouse isn't over a unit frame", function()
        start({ bind("F", spell(RENEW)) })
        T.eq(hoverBinding("F"), nil)
        Stubs.PointAt(party(1))
        T.eq(hoverBinding("F"), "CLICK QoLClickCastKeys:k1")
        Stubs.PointAway(party(1))
        T.eq(hoverBinding("F"), nil)
    end)

    it("keeps the keys while another unit frame hides, and drops them when the one under the mouse does", function()
        start({ bind("F", spell(RENEW)) })
        Stubs.PointAt(party(1))
        Stubs.HideUnitFrame(_G.TargetFrameToT)
        T.eq(hoverBinding("F"), "CLICK QoLClickCastKeys:k1")
        Stubs.HideUnitFrame(party(1))
        T.eq(hoverBinding("F"), nil)
    end)

    it("keeps the keys over a frame's health bar, which takes the mouse, in combat too", function()
        start({ bind("F", spell(RENEW)) })
        local bar = PlayerFrame.HealthBarsContainer.HealthBar
        -- From the frame onto its bar: the game leaves the frame first.
        Stubs.PointAt(PlayerFrame)
        Stubs.PointAway(PlayerFrame)
        Stubs.PointAt(bar)
        T.eq(hoverBinding("F"), "CLICK QoLClickCastKeys:k1")
        Stubs.PointAway(bar)
        T.eq(hoverBinding("F"), nil)
        T.eq(press(bar, "F"), "spell:139 on player", "straight onto the bar")
        Stubs.state().combat = true
        T.eq(press(party(2).HealthBarsContainer.HealthBar, "F"), "spell:139 on party2")
        Stubs.PointAt(party(3).HealthBarsContainer.HealthBar)
        Stubs.HideUnitFrame(party(3))
        T.eq(hoverBinding("F"), nil, "the frame hid under the mouse")
    end)

    it("uses Target and Menu on other clicks on the unit of the frame whose bar the mouse is over", function()
        start({ bind("ALT-BUTTON1", TARGET) })
        Stubs.PointAt(party(1))
        Stubs.PointAway(party(1))
        Stubs.PointAt(party(2).HealthBarsContainer.HealthBar)
        Stubs.Hold("ALT")
        local before = #Stubs.state().usedActions
        Stubs.ClickUnitFrame(party(2), "LeftButton")
        Stubs.Hold()
        T.eq(usedSince(before), "target on party2")
    end)

    it("acts when the key goes down", function()
        start({ bind("F", spell(RENEW)) })
        Stubs.PointAt(party(1))
        local before = #Stubs.state().usedActions
        Stubs.PressOverride("F", true)
        T.eq(usedSince(before), "spell:139 on party1")
    end)

    it("uses the binding over a unit frame and the ring everywhere else on a key both have", function()
        Stubs.LoadAddon()
        priest(Stubs.state())
        Stubs.Login({ clickCast = true, ring = true }, { { entries = { spell(FLASH_HEAL) }, mouse = "F" } }, nil,
            { [ME] = { bind("F", spell(RENEW)) } })
        local ring = "CLICK QoLRingButton:1mouse"
        T.eq(Stubs.state().overrides.F.command, ring)
        T.eq(press(party(1), "F"), "spell:139 on party1")
        T.eq(Stubs.state().overrides.F.command, ring, "the ring keeps its key")
        T.eq(GetBindingAction("F", true), ring)
    end)

    it("does nothing with keys once turned off", function()
        local ns = start({ bind("F", spell(RENEW)) })
        set(ns, "clickCast", false)
        Stubs.PointAt(party(1))
        T.eq(hoverBinding("F"), nil)
    end)
end)

describe("click casting frames", function()
    it("works on the player, target, focus, pet, party, party pet and boss frames", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) })
        local frames = { PlayerFrame = "player", TargetFrame = "target", TargetFrameToT = "targettarget",
            FocusFrame = "focus", FocusFrameToT = "focustarget", PetFrame = "pet", Boss2TargetFrame = "boss2" }
        for name, unit in pairs(frames) do
            T.eq(click(_G[name], "LeftButton", "SHIFT"), "spell:139 on " .. unit, name)
        end
        T.eq(click(party(4).PetFrame, "LeftButton", "SHIFT"), "spell:139 on partypet4")
    end)

    it("gives raid frames that appear later the bindings, and those made in combat once combat ends", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) })
        local raid1 = Stubs.NewRaidFrame("raid1")
        Stubs.RunTimers()
        T.eq(click(raid1, "LeftButton", "SHIFT"), "spell:139 on raid1")
        Stubs.state().combat = true
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        local raid2 = Stubs.NewRaidFrame("raid2")
        Stubs.RunTimers()
        T.eq(click(raid2, "LeftButton", "SHIFT"), nil)
        T.eq(click(raid2, "LeftButton"), "target on raid2", "it keeps the game's clicks in combat")
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(click(raid2, "LeftButton", "SHIFT"), "spell:139 on raid2")
    end)

    it("leaves nameplates alone", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) })
        local plate = Stubs.NewNamePlate(1)
        Stubs.RunTimers()
        T.eq(plate.attributes, nil, "no attributes set")
        T.eq(plate.wraps, nil, "no scripts wrapped")
    end)

    it("picks up the arena frames when the arena UI loads", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) })
        Stubs.LoadArenaUI()
        Stubs.RunTimers()
        T.eq(click(ArenaEnemyMatchFrame3, "LeftButton", "SHIFT"), "spell:139 on arena3")
    end)

    it("gives a frame another addon puts in ClickCastFrames the bindings, and its own clicks when it leaves", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) })
        local frame = Stubs.NewUnitButton("raid7")
        ClickCastFrames[frame] = true
        Stubs.RunTimers()
        T.eq(click(frame, "LeftButton", "SHIFT"), "spell:139 on raid7")
        ClickCastFrames[frame] = nil
        Stubs.RunTimers()
        T.eq(click(frame, "LeftButton", "SHIFT"), nil)
        T.eq(click(frame, "LeftButton"), "target on raid7")
        Stubs.PointAt(frame)
        T.eq(Stubs.state().priorityOverrides.F, nil)
    end)

    it("takes the frames a unit frame addon put in its own ClickCastFrames table first", function()
        local frame
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) }, nil, function()
            frame = Stubs.NewUnitButton("raid8")
            _G.ClickCastFrames = { [frame] = true }
        end)
        T.eq(click(frame, "LeftButton", "SHIFT"), "spell:139 on raid8")
    end)

    it("registers the frames a secure header puts in through ClickCastHeader", function()
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) })
        -- A unit frame addon's header, running the snippet such an addon runs for each frame it makes.
        local frame = Stubs.NewUnitButton("raid9", "TheirRaidButton9")
        local theirs = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        SecureHandlerSetFrameRef(theirs, "clickcast_header", ClickCastHeader)
        SecureHandlerSetFrameRef(theirs, "button", frame)
        local function run(snippet)
            SecureHandlerExecute(theirs, ([[
                local header = self:GetFrameRef("clickcast_header")
                header:SetAttribute("clickcast_button", self:GetFrameRef("button"))
                header:RunAttribute("%s")
            ]]):format(snippet))
        end
        run("clickcast_register")
        Stubs.RunTimers()
        T.eq(click(frame, "LeftButton", "SHIFT"), "spell:139 on raid9")
        run("clickcast_unregister")
        Stubs.RunTimers()
        T.eq(click(frame, "LeftButton"), "target on raid9")
        Stubs.state().combat = true
        run("clickcast_register")
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(click(frame, "LeftButton", "SHIFT"), "spell:139 on raid9", "in again once combat is over")
    end)

    it("has ClickCastHeader ready for a unit frame addon that builds its frames while the game loads", function()
        Stubs.LoadAddon()
        priest(Stubs.state())
        _G.QoLDB = { options = { clickCast = true }, clickCast = { [ME] = { bind("SHIFT-BUTTON1", spell(RENEW)) } } }
        Stubs.Fire("ADDON_LOADED", "QoL")
        -- A unit frame addon loaded after QoL builds its header and frames now, before login.
        T.truthy(ClickCastHeader, "there before login")
        local frame = Stubs.NewUnitButton("raid9", "TheirRaidButton9")
        local theirs = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        SecureHandlerSetFrameRef(theirs, "clickcast_header", ClickCastHeader)
        SecureHandlerSetFrameRef(theirs, "button", frame)
        SecureHandlerExecute(theirs, [[
            local header = self:GetFrameRef("clickcast_header")
            header:SetAttribute("clickcast_button", self:GetFrameRef("button"))
            header:RunAttribute("clickcast_register")
        ]])
        Stubs.Fire("PLAYER_LOGIN")
        Stubs.Fire("PLAYER_ENTERING_WORLD")
        Stubs.RunTimers()
        T.eq(click(frame, "LeftButton", "SHIFT"), "spell:139 on raid9")
    end)

    -- Grid2's frames module as far as QoL looks at it: the frames it registered, by name.
    local function grid2()
        _G.Grid2Frame = { registeredFrames = {} }
        function Grid2Frame:RegisterFrame(frame) self.registeredFrames[frame:GetName()] = frame end
        local frame = Stubs.NewUnitButton("raid1", "Grid2LayoutHeader1UnitButton1")
        Grid2Frame:RegisterFrame(frame)
        return frame
    end

    it("takes Grid2's frames, those there already and those it makes later", function()
        local first
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) }, nil, function() first = grid2() end)
        T.eq(click(first, "LeftButton", "SHIFT"), "spell:139 on raid1")
        local later = Stubs.NewUnitButton("raid2", "Grid2LayoutHeader1UnitButton2")
        Grid2Frame:RegisterFrame(later)
        Stubs.RunTimers()
        T.eq(click(later, "LeftButton", "SHIFT"), "spell:139 on raid2")
    end)

    it("leaves another click casting addon's ClickCastFrames and ClickCastHeader alone", function()
        local theirs, header, grid
        start({ bind("SHIFT-BUTTON1", spell(RENEW)) }, nil, function()
            theirs, header = {}, {}
            _G.ClickCastFrames, _G.ClickCastHeader = theirs, header
            grid = grid2()
        end)
        T.eq(ClickCastFrames, theirs)
        T.eq(ClickCastHeader, header)
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:139 on party1", "Blizzard's frames still work")
        T.eq(click(grid, "LeftButton", "SHIFT"), nil, "Grid2's frames are the other addon's")
    end)
end)

describe("click casting bindings", function()
    it("uses a binding only while the character has its action", function()
        start({ bind("SHIFT-BUTTON1", spell(SMITE)) })
        T.eq(click(party(1), "LeftButton", "SHIFT"), nil)
        Stubs.state().spells[SMITE] = { name = "Smite", texture = 135924 }
        Stubs.Fire("SPELLS_CHANGED")
        Stubs.RunTimers()
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:585 on party1")
        T.same(QoLDB.clickCast[ME], { bind("SHIFT-BUTTON1", spell(SMITE)) }, "it stays saved")
    end)

    it("lets two bindings on one combination share it by specialization", function()
        start({ bind("SHIFT-BUTTON1", spell(SMITE)), bind("SHIFT-BUTTON1", spell(RENEW)) })
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:139 on party1")
    end)

    it("keeps a binding it doesn't understand (a newer QoL's) and uses the others", function()
        local toy = bind("ALT-BUTTON1", { kind = "toy", id = 54452 })
        start({ toy, bind("SHIFT-BUTTON1", spell(RENEW)) })
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:139 on party1")
        T.eq(click(party(1), "LeftButton", "ALT"), nil)
        T.same(QoLDB.clickCast[ME], { toy, bind("SHIFT-BUTTON1", spell(RENEW)) })
    end)

    it("keeps each character's bindings apart", function()
        local saved = { [ME] = { bind("SHIFT-BUTTON1", spell(RENEW)) } }
        Stubs.LoadAddon()
        priest(Stubs.state())
        Stubs.state().units.player.name = "Altpriest"
        Stubs.Login({ clickCast = true }, nil, nil, saved)
        T.eq(click(party(1), "LeftButton", "SHIFT"), nil)
        T.eq(click(party(1), "LeftButton"), "target on party1", "a new character starts with Target")
        T.same(QoLDB.clickCast[ME], { bind("SHIFT-BUTTON1", spell(RENEW)) })
        T.same(QoLDB.clickCast["altpriest-testrealm"], { bind("BUTTON1", TARGET), bind("BUTTON2", MENU) })
    end)

    it("keeps the bindings in combat as they were when it started", function()
        start({ bind("SHIFT-BUTTON1", spell(SMITE)), bind("F", spell(SMITE)) })
        Stubs.state().combat = true
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.state().spells[SMITE] = { name = "Smite", texture = 135924 }
        Stubs.Fire("SPELLS_CHANGED")
        Stubs.RunTimers()
        T.eq(click(party(1), "LeftButton", "SHIFT"), nil)
        Stubs.PointAt(party(1))
        T.eq(hoverBinding("F"), nil, "no key until combat ends")
        Stubs.PointAway(party(1))
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:585 on party1")
        T.eq(press(party(1), "F"), "spell:585 on party1")
    end)
end)

describe("click casting page", function()
    local function page() return QoLClickCastEditor end
    local function note() return page().note:GetText() end
    -- The bindings shown on the left: "name: combination" each.
    local function shown()
        local list = {}
        for _, row in ipairs(page().rows) do
            if row:IsShown() then list[#list + 1] = row.name:GetText() .. ": " .. row.box.text end
        end
        return list
    end
    -- The action on the right with that name.
    local function action(name)
        for _, row in ipairs(page().list.rows) do
            if row:IsShown() and row.name:GetText() == name then return row end
        end
        error("no " .. name .. " in the list")
    end
    -- Whether a binding's name is in red.
    local function red(row)
        local r, g = row.name:GetTextColor()
        return r == 1 and g < 0.5
    end
    local function tooltip()
        local lines = {}
        for index, line in ipairs(GameTooltip.lines) do lines[index] = line.text end
        return lines
    end
    local function open(bindings, options, setup)
        local ns = start(bindings, options, setup)
        SlashCmdList.QOL("click")
        return ns
    end

    it("is the settings' Click casting page, right after Ring, which /qol click opens and closes", function()
        local ns = open(nil, {})
        local window = ns.SettingsPanel.window
        T.truthy(QoLSettings:IsShown(), "the settings open")
        T.eq(window.selected, "clickCast")
        local ring
        for index, key in ipairs(window.order) do
            if key == "ring" then ring = index end
        end
        T.eq(window.order[ring + 1], "clickCast")
        T.eq(page():GetParent(), ns.SettingsPanel.pages.clickCast.frame)
        T.same(shown(), { "Target: Left", "Menu: Right" })
        T.eq(note(), "Click casting is off: turn it on at the top of this page to change your bindings.")
        SlashCmdList.QOL("click")
        T.falsy(QoLSettings:IsShown(), "closed again")
    end)

    it("lists each binding with its action's icon, name and combination, a page at a time", function()
        open({ bind("SHIFT-BUTTON1", spell(RENEW)), bind("CTRL-F", spell(FLASH_HEAL)), bind("MOUSEWHEELUP", BANDAGED),
            bind("ALT-CTRL-SHIFT-BUTTON4", HEAL_MACRO), bind("BUTTON1", TARGET), bind("BUTTON2", MENU),
            bind("BUTTON3", spell(FORTITUDE)), bind("BUTTON5", TARGET), bind("MOUSEWHEELDOWN", MENU) })
        T.same(shown(), { "Renew: Shift-Left", "Flash Heal: Ctrl-F", "Linen Bandage: Wheel up",
            "Heal: Alt-Ctrl-Shift-Button 4", "Target: Left", "Menu: Right", "Power Word: Fortitude: Middle" })
        T.eq(page().rows[1].icon.texture, 135953)
        T.eq(page().rows[5].icon.texture, 132212, "the game's own icon for Target")
        T.eq(page().pageText:GetText(), "Page 1/2")
        T.falsy(page().previous:IsEnabled(), "no page before")
        page().nextPage:Click()
        T.same(shown(), { "Target: Button 5", "Menu: Wheel down" })
        T.falsy(page().nextPage:IsEnabled(), "no page after")
        page().rows[1]:GetParent():RunScript("OnMouseWheel", 1)
        T.eq(page().pageText:GetText(), "Page 1/2", "the wheel turns back")
    end)

    it("greys out what this character can't use now, and marks clashes and the game's own clicks in red", function()
        open({ bind("SHIFT-BUTTON1", spell(RENEW)), bind("SHIFT-BUTTON1", spell(FLASH_HEAL)), bind("BUTTON3", BANDAGED),
            bind("BUTTON3", spell(FORTITUDE)), bind("CTRL-BUTTON1", spell(FORTITUDE)) }, nil, function(state)
            state.items[BANDAGE].count = 0
            -- The game's own Click Casting: Ctrl-Left casts Renew.
            state.clickBindings[#state.clickBindings + 1] =
                { type = 1, actionID = RENEW, button = "LeftButton", modifiers = 2 }
        end)
        local rows = page().rows
        T.same({ red(rows[1]), red(rows[2]), red(rows[3]), red(rows[4]), red(rows[5]) },
            { true, true, false, false, true })
        T.same({ rows[1]:GetAlpha(), rows[3]:GetAlpha(), rows[4]:GetAlpha() }, { 1, 0.5, 1 })
        rows[1]:RunScript("OnEnter")
        T.eq(GameTooltip.spell, RENEW)
        T.eq(tooltip()[1], "Clashes with Flash Heal on the same combination: only one of them works.")
        rows[2]:RunScript("OnEnter")
        T.eq(tooltip()[1], "Clashes with Renew on the same combination: only one of them works.")
        rows[3]:RunScript("OnEnter")
        T.eq(tooltip()[1], "This character can't use it now. It stays for when it can (another specialization, or "
            .. "once it's in the bags again).")
        rows[4]:RunScript("OnEnter")
        T.same(tooltip(), { "Click the box to change the combination. A right-click removes the binding." })
        rows[5].box:RunScript("OnEnter")
        T.eq(tooltip()[1], "The game's own Click Casting binds this click, and its binding wins. Change it there.")
    end)

    it("leaves out a binding it doesn't understand, and keeps it while the others change", function()
        local toy = bind("ALT-BUTTON1", { kind = "toy", id = 54452 })
        open({ toy, bind("SHIFT-BUTTON1", spell(RENEW)), bind("CTRL-BUTTON1", spell(FORTITUDE)) })
        T.same(shown(), { "Renew: Shift-Left", "Power Word: Fortitude: Ctrl-Left", "Target: |cff808080Not Bound|r",
            "Menu: |cff808080Not Bound|r" })
        page().rows[1].box:RunScript("OnClick", "LeftButton")
        Stubs.TypeKey("G")
        page().rows[2]:RunScript("OnClick", "RightButton")
        T.same(shown(), { "Renew: G", "Target: |cff808080Not Bound|r", "Menu: |cff808080Not Bound|r" })
        T.same(QoLDB.clickCast[ME], { toy, bind("G", spell(RENEW)) })
    end)

    it("names every other binding a clash is with", function()
        open({ bind("SHIFT-BUTTON1", spell(RENEW)), bind("SHIFT-BUTTON1", spell(FLASH_HEAL)),
            bind("SHIFT-BUTTON1", spell(FORTITUDE)) })
        page().rows[1]:RunScript("OnEnter")
        T.eq(tooltip()[1], "Clashes with Flash Heal and Power Word: Fortitude on the same combination: only one of "
            .. "them works.")
        page().rows[3]:RunScript("OnEnter")
        T.eq(tooltip()[1], "Clashes with Renew and Flash Heal on the same combination: only one of them works.")
    end)

    it("adds a binding for an action clicked on the right, whose box waits for a click, the wheel or a key", function()
        open()
        action("Flash Heal"):Click()
        T.same(shown(), { "Target: Left", "Menu: Right", "Flash Heal: |cff808080Not Bound|r" })
        T.truthy(page().rows[3].box.selected, "waiting")
        T.eq(note(), "Click, turn the wheel or press a key for Flash Heal, with any of Shift, Ctrl and Alt. Escape "
            .. "cancels.")
        T.same(QoLDB.clickCast[ME], { bind("BUTTON1", TARGET), bind("BUTTON2", MENU) }, "not saved yet")
        Stubs.Hold("SHIFT")
        Stubs.PressMouse("LeftButton")
        Stubs.Hold()
        T.same(shown(), { "Target: Left", "Menu: Right", "Flash Heal: Shift-Left" })
        T.falsy(page().rows[3].box.selected, "done")
        T.truthy(action("Flash Heal").check:IsShown(), "bound")
        Stubs.RunTimers()
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:2061 on party1")

        action("Renew"):Click()
        Stubs.TurnWheel(-1)
        T.eq(shown()[4], "Renew: Wheel down")
        page().list.tabs[2]:Click()
        action("Linen Bandage"):Click()
        Stubs.Hold("CTRL")
        Stubs.TypeKey("F")
        Stubs.Hold()
        T.eq(shown()[5], "Linen Bandage: Ctrl-F")
        Stubs.RunTimers()
        T.eq(press(party(2), "MOUSEWHEELDOWN"), "spell:139 on party2")
        T.eq(press(party(2), "CTRL-F"), "item:item:1251 on party2")
    end)

    it("cancels a waiting box with Escape, changes a combination from its box, and removes with a right-click",
        function()
            open()
            action("Renew"):Click()
            Stubs.TypeKey("ESCAPE")
            T.same(shown(), { "Target: Left", "Menu: Right" }, "not added")
            T.eq(note(), "Click a spell, item or macro on the right to bind it, or drag one here. Click a "
                .. "binding's box to change its combination; a right-click removes the binding.")

            local box = page().rows[1].box
            box:RunScript("OnClick", "LeftButton")
            T.truthy(box.selected, "waiting")
            T.eq(note(), "Click, turn the wheel or press a key for Target, with any of Shift, Ctrl and Alt. Escape "
                .. "cancels.")
            Stubs.Hold("ALT")
            Stubs.PressMouse("LeftButton")
            Stubs.Hold()
            T.same(shown(), { "Target: Alt-Left", "Menu: Right" })
            box:RunScript("OnClick", "LeftButton")
            Stubs.TypeKey("ESCAPE")
            T.same(shown(), { "Target: Alt-Left", "Menu: Right" }, "kept")
            Stubs.RunTimers()
            T.eq(click(party(1), "LeftButton"), nil, "a plain left click is free")
            T.eq(click(party(1), "LeftButton", "ALT"), "target on party1")

            page().rows[2]:RunScript("OnClick", "RightButton")
            T.same(shown(), { "Target: Alt-Left", "Menu: |cff808080Not Bound|r" })
            page().rows[1].box:RunScript("OnClick", "RightButton")
            T.same(shown(), { "Target: |cff808080Not Bound|r", "Menu: |cff808080Not Bound|r" })
            T.same(QoLDB.clickCast[ME], {})
            Stubs.RunTimers()
            T.eq(click(party(1), "RightButton"), nil)
        end)

    it("lists Target and Menu while nothing binds them, and binds them again from their box", function()
        open({ bind("SHIFT-BUTTON1", spell(RENEW)) })
        T.same(shown(), { "Renew: Shift-Left", "Target: |cff808080Not Bound|r", "Menu: |cff808080Not Bound|r" })
        local rows = page().rows
        rows[2]:RunScript("OnClick", "RightButton")
        rows[2].box:RunScript("OnClick", "RightButton")
        T.eq(#shown(), 3, "they stay")
        rows[3]:RunScript("OnEnter")
        T.same(tooltip(), { "Menu", "Not bound: click the box to give it a combination." })
        rows[3].box:RunScript("OnClick", "LeftButton")
        T.truthy(rows[3].box.selected, "waiting")
        T.eq(note(), "Click, turn the wheel or press a key for Menu, with any of Shift, Ctrl and Alt. Escape "
            .. "cancels.")
        Stubs.PressMouse("RightButton")
        T.same(shown(), { "Renew: Shift-Left", "Menu: Right", "Target: |cff808080Not Bound|r" })
        T.same(QoLDB.clickCast[ME], { bind("SHIFT-BUTTON1", spell(RENEW)), bind("BUTTON2", MENU) })
        Stubs.RunTimers()
        T.eq(click(party(1), "RightButton"), "menu on party1")
        T.eq(click(party(1), "LeftButton"), nil, "Target stays unbound")
    end)

    it("refuses a modifier on its own, Cmd and the keys the character moves with, and keeps waiting", function()
        open()
        action("Renew"):Click()
        Stubs.Hold("SHIFT")
        Stubs.TypeKey("LSHIFT")
        T.eq(note(), "Shift, Ctrl and Alt can't be a binding on their own: hold them while you click, turn the "
            .. "wheel or press a key.")
        Stubs.TypeKey("W")
        T.eq(note(), "You move, turn or jump with W, so it can't be a binding: you'd stop whenever the mouse "
            .. "crosses a unit frame.")
        Stubs.Hold()
        Stubs.TypeKey("SPACE")
        T.eq(note(), "You move, turn or jump with SPACE, so it can't be a binding: you'd stop whenever the mouse "
            .. "crosses a unit frame.")
        Stubs.Hold("META")
        Stubs.TypeKey("G")
        T.eq(note(), "Cmd can't be part of a binding: hold Shift, Ctrl or Alt instead.")
        Stubs.Hold()
        T.truthy(page().rows[3].box.selected, "still waiting")
        Stubs.TypeKey("G")
        T.same(shown(), { "Target: Left", "Menu: Right", "Renew: G" })
    end)

    it("adds a binding for a spell, item or macro dropped on the page, and says what it can't bind", function()
        open()
        local state = Stubs.state()
        state.cursorInfo = { "spell", 1, "spell", RENEW, RENEW }
        page().rows[1]:GetParent():RunScript("OnReceiveDrag")
        T.eq(state.cursorInfo, nil, "taken off the cursor")
        T.same(shown(), { "Target: Left", "Menu: Right", "Renew: |cff808080Not Bound|r" })
        Stubs.TypeKey("1")
        state.cursorInfo = { "macro", 1 }
        page().rows[2]:RunScript("OnReceiveDrag")
        Stubs.TypeKey("2")
        state.cursorInfo = { "item", BANDAGE, "item:" .. BANDAGE }
        page().rows[1]:RunScript("OnReceiveDrag")
        Stubs.TypeKey("3")
        T.same(shown(), { "Target: Left", "Menu: Right", "Renew: 1", "Heal: 2", "Linen Bandage: 3" })
        state.cursorInfo = { "money", 100 }
        page().rows[1]:RunScript("OnReceiveDrag")
        T.eq(note(), "Only spells, items and macros can be bound.")
        T.eq(#shown(), 5, "nothing added")
    end)

    it("changes nothing in combat, says why, and shows what changed once it's over", function()
        open({ bind("BUTTON1", TARGET), bind("SHIFT-BUTTON1", BANDAGED) }, nil, function(state)
            state.items[BANDAGE].count = 0
        end)
        local state = Stubs.state()
        T.eq(page().rows[2]:GetAlpha(), 0.5, "no bandages")
        page().rows[1].box:RunScript("OnClick", "LeftButton")
        state.combat = true
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        T.truthy(page():IsVisible(), "still shown")
        T.falsy(page().rows[1].box.selected, "no longer waiting")
        T.eq(note(), "The bindings can't be changed in combat.")
        T.falsy(page().quick:IsEnabled(), "no quick bind")
        T.falsy(page().rows[1].box:IsEnabled(), "no boxes")
        page().rows[1]:RunScript("OnClick", "RightButton")
        page().rows[1].box:RunScript("OnClick", "LeftButton")
        action("Renew"):Click()
        state.cursorInfo = { "spell", 1, "spell", RENEW, RENEW }
        page().rows[1]:RunScript("OnReceiveDrag")
        Stubs.TypeKey("F")
        T.same(shown(), { "Target: Left", "Linen Bandage: Shift-Left", "Menu: |cff808080Not Bound|r" },
            "nothing removed or added")
        T.same(QoLDB.clickCast[ME], { bind("BUTTON1", TARGET), bind("SHIFT-BUTTON1", BANDAGED) })

        state.items[BANDAGE].count = 5
        Stubs.Fire("BAG_UPDATE_DELAYED")
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(page().rows[2]:GetAlpha(), 1, "the bandages came in combat")
        T.truthy(page().quick:IsEnabled(), "quick bind again")
        T.truthy(page().rows[1].box:IsEnabled(), "boxes again")
        T.eq(note(), "Click a spell, item or macro on the right to bind it, or drag one here. Click a "
            .. "binding's box to change its combination; a right-click removes the binding.")
    end)

    it("greys out and changes nothing while click casting is off, and follows the switch", function()
        local ns = open({ bind("SHIFT-BUTTON1", spell(RENEW)) }, {})
        local state = Stubs.state()
        local switch = ns.SettingsPanel.pages.clickCast.controls[1]
        T.eq(switch.key, "clickCast")
        local function dimmed()
            return { page().rows[1]:GetParent():GetAlpha(), page().list:GetAlpha(), page().quick:GetAlpha(),
                page().note:GetAlpha() }
        end
        T.same(dimmed(), { 0.5, 0.5, 0.5, 1 }, "all but the note")
        T.falsy(page().quick:IsEnabled(), "no quick bind")
        T.falsy(page().rows[1].box:IsEnabled(), "no boxes")
        page().rows[1]:RunScript("OnEnter")
        T.same(tooltip(), {}, "no word on what a click does")
        Stubs.Hover(action("Flash Heal"))
        T.same(tooltip(), {})
        Stubs.Hover(nil)
        page().rows[1].box:RunScript("OnClick", "LeftButton")
        T.falsy(page().rows[1].box.selected, "no box waits")
        page().quick:Click()
        T.eq(page().quick.text, "Quick bind")
        page().rows[1]:RunScript("OnClick", "RightButton")
        action("Flash Heal"):Click()
        state.cursorInfo = { "spell", 1, "spell", FLASH_HEAL, FLASH_HEAL }
        page().rows[1]:RunScript("OnReceiveDrag")
        state.cursorInfo = nil
        T.same(shown(), { "Renew: Shift-Left", "Target: |cff808080Not Bound|r", "Menu: |cff808080Not Bound|r" },
            "nothing removed or added")
        T.same(QoLDB.clickCast[ME], { bind("SHIFT-BUTTON1", spell(RENEW)) })

        switch.widget:Click()
        T.truthy(ns.Options:Get("clickCast"), "on")
        T.same(dimmed(), { 1, 1, 1, 1 })
        T.truthy(page().quick:IsEnabled(), "quick bind")
        T.truthy(page().rows[1].box:IsEnabled(), "boxes")
        T.truthy(note():find("^Click a spell"))

        page().rows[1].box:RunScript("OnClick", "LeftButton")
        switch.widget:Click()
        T.falsy(page().rows[1].box.selected, "turning it off stops a box waiting")
        T.truthy(Stubs.TypeKey("G"), "keys go on to the game")
        switch.widget:Click()
        page().quick:Click()
        switch.widget:Click()
        T.eq(page().quick.text, "Quick bind", "and ends quick bind")
        T.same(QoLDB.clickCast[ME], { bind("SHIFT-BUTTON1", spell(RENEW)) })
    end)

    describe("quick bind", function()
        -- Clicks the action with the mouse button, the modifiers held.
        local function clickAction(row, mouseButton, ...)
            Stubs.Hold(...)
            row:RunScript("OnClick", mouseButton)
            Stubs.Hold()
        end

        it("binds the action pointed at to a click, the wheel or a key", function()
            open()
            page().quick:Click()
            T.eq(page().quick.text, "End quick bind")
            T.eq(note(), "Quick bind is on: point at an action on the right and click, turn the wheel or press a "
                .. "key, with any of Shift, Ctrl and Alt. Escape ends it.")
            local renew = action("Renew")
            Stubs.Hover(renew)
            T.eq(tooltip()[#tooltip()], "Click, turn the wheel or press a key to bind it.")
            clickAction(renew, "LeftButton", "SHIFT")
            T.eq(note(), "Shift-Left: Renew")
            clickAction(renew, "LeftButton")
            T.eq(note(), "Left: Renew (was Target)", "a plain left click binds Left, too")
            Stubs.TurnWheel(1)
            T.falsy(Stubs.TypeKey("G"), "taken")
            T.same(shown(), { "Renew: Left", "Menu: Right", "Renew: Shift-Left", "Renew: Wheel up", "Renew: G",
                "Target: |cff808080Not Bound|r" })

            T.truthy(Stubs.TypeKey("LSHIFT"), "a modifier on its own goes on to the game")
            T.falsy(Stubs.TypeKey("W"), "a movement key over an action is refused")
            T.eq(note(), "You move, turn or jump with W, so it can't be a binding: you'd stop whenever the mouse "
                .. "crosses a unit frame.")
            Stubs.Hover(nil)
            T.truthy(Stubs.TypeKey("H"), "away from the list, keys go on to the game")
            T.eq(#shown(), 6, "nothing bound")

            Stubs.RunTimers()
            T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:139 on party1")
            T.eq(press(party(1), "G"), "spell:139 on party1")
        end)

        it("moves a working binding to the new action and says what it had, leaving one that doesn't work now",
            function()
                open({ bind("SHIFT-BUTTON1", spell(RENEW)), bind("SHIFT-BUTTON1", BANDAGED) }, nil, function(state)
                    state.items[BANDAGE].count = 0
                end)
                page().quick:Click()
                local flash = action("Flash Heal")
                Stubs.Hover(flash)
                clickAction(flash, "LeftButton", "SHIFT")
                T.eq(note(), "Shift-Left: Flash Heal (was Renew)")
                T.same(QoLDB.clickCast[ME], { bind("SHIFT-BUTTON1", spell(FLASH_HEAL)), bind("SHIFT-BUTTON1", BANDAGED) })
                clickAction(flash, "LeftButton", "SHIFT")
                T.eq(note(), "Shift-Left: Flash Heal", "nothing replaced")
                T.eq(#QoLDB.clickCast[ME], 2)
            end)

        it("moves both working bindings of a clash to the new action and names both", function()
            open({ bind("SHIFT-BUTTON1", spell(RENEW)), bind("SHIFT-BUTTON1", spell(FORTITUDE)) })
            page().quick:Click()
            local flash = action("Flash Heal")
            Stubs.Hover(flash)
            clickAction(flash, "LeftButton", "SHIFT")
            T.eq(note(), "Shift-Left: Flash Heal (was Renew, Power Word: Fortitude)")
            T.same(QoLDB.clickCast[ME], { bind("SHIFT-BUTTON1", spell(FLASH_HEAL)) })
        end)

        it("ends on Escape, with the button, on leaving the page and when combat starts", function()
            local ns = open()
            local quick, renew = page().quick, action("Renew")
            local function over()
                T.eq(quick.text, "Quick bind")
                Stubs.Hover(renew)
                T.truthy(Stubs.TypeKey("G"), "keys go on to the game")
                Stubs.Hover(nil)
            end
            quick:Click()
            T.falsy(Stubs.TypeKey("ESCAPE"), "Escape ends it, and the window stays")
            over()
            quick:Click()
            quick:Click()
            over()
            quick:Click()
            ns.SettingsPanel.window.buttons.ring:Click()
            -- The game runs the editor's OnHide with its page's.
            page():RunScript("OnHide")
            SlashCmdList.QOL("click")
            over()
            quick:Click()
            Stubs.state().combat = true
            Stubs.Fire("PLAYER_REGEN_DISABLED")
            T.eq(quick.text, "Quick bind")
            T.same(shown(), { "Target: Left", "Menu: Right" }, "nothing bound")
        end)

        it("adds the usual way once it's over", function()
            open()
            page().quick:Click()
            page().quick:Click()
            action("Renew"):Click()
            T.eq(shown()[3], "Renew: |cff808080Not Bound|r")
        end)
    end)

    it("shows only spells, items and macros on the right", function()
        open()
        local tabs = {}
        for index, tab in ipairs(page().list.tabs) do tabs[index] = tab.text end
        T.same(tabs, { "Spells", "Items", "Macros" })
    end)

    it("stands its tabs on the parchment's top edge, where retail's page starts", function()
        local ns = open()
        local list = page().list
        local _, edges = ns.RingPicker.NewPage(nil, UIParent, 0, page():GetWidth(), page():GetHeight())
        local tabsBottom = list:PointFor("TOPRIGHT")[5] + list.tabs[1]:PointFor("BOTTOMLEFT")[5]
        T.eq(tabsBottom, -edges.top)
    end)
end)

describe("click casting on Classic Era", function()
    local function page() return QoLClickCastEditor end
    local function note() return page().note:GetText() end
    local function action(name)
        for _, row in ipairs(page().list.rows) do
            if row:IsShown() and row.name:GetText() == name then return row end
        end
        error("no " .. name .. " in the list")
    end
    local function names()
        local found = {}
        for _, row in ipairs(page().list.rows) do
            if row:IsShown() then found[#found + 1] = row.name:GetText() end
        end
        return found
    end
    -- Logs in on Classic Era as the priest, click casting on, and opens the page.
    local function open()
        Stubs.LoadAddon({ client = "classicEra" })
        priest(Stubs.state())
        Stubs.Login({ clickCast = true })
        SlashCmdList.QOL("click")
    end

    it("lists the spell book's spells, and its tabs switch to items and macros", function()
        open()
        T.same(names(), { "Renew", "Power Word: Fortitude", "Flash Heal" }, "the spell book's order")
        local labels = {}
        for index, tab in ipairs(page().list.tabs) do labels[index] = tab:GetText() end
        T.same(labels, { "Spells", "Items", "Macros" })
        page().list.tabs[2]:Click()
        T.same(names(), { "Linen Bandage" })
        page().list.tabs[3]:Click()
        T.same(names(), { "Heal" })
        T.same(Stubs.state().errors, {})
    end)

    it("binds an action clicked on the right, which then acts on a party frame", function()
        open()
        action("Flash Heal"):Click()
        Stubs.Hold("SHIFT")
        Stubs.PressMouse("LeftButton")
        Stubs.Hold()
        Stubs.RunTimers()
        T.eq(click(party(1), "LeftButton", "SHIFT"), "spell:2061 on party1")
        T.same(Stubs.state().errors, {})
    end)

    it("binds through quick bind, and the binding acts on the player frame", function()
        open()
        page().quick:Click()
        local renew = action("Renew")
        Stubs.Hover(renew)
        Stubs.Hold("CTRL")
        renew:RunScript("OnClick", "RightButton")
        Stubs.Hold()
        T.eq(note(), "Ctrl-Right: Renew")
        Stubs.RunTimers()
        T.eq(click(PlayerFrame, "RightButton", "CTRL"), "spell:139 on player")
        T.same(Stubs.state().errors, {})
    end)
end)
