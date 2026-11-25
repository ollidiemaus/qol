local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Forever with its character window, which the game has broken if the controller interface is on.
local function load(controller, options)
    local ns = Stubs.LoadAddon(options)
    Stubs.SetControllerUI(controller)
    Stubs.NewCharacterWindow()
    return ns
end

local function start(controller, savedOptions)
    local ns = load(controller)
    Stubs.Login(savedOptions)
    return ns
end

local function pane() return PaperDollFrame.EquipmentManagerPane end

-- The pane is 220 wide: 5 free on the left, 20 on the right for the scroll bar, 105 below for New Set.
local function assertRepaired()
    local list, bar = pane().ScrollBox, pane().ScrollBar
    T.eq(list:GetWidth(), 195)
    T.same(list.points, { { "TOPLEFT", pane(), "TOPLEFT", 5, -8 }, { "BOTTOMRIGHT", pane(), "BOTTOMRIGHT", -20, 105 } })
    T.same(bar.points, { { "TOPLEFT", list, "TOPRIGHT", -5, -12 }, { "BOTTOMLEFT", list, "BOTTOMRIGHT", 0, 0 } })
end

local function assertBroken()
    T.eq(pane().ScrollBox:GetWidth(), 0)
end

describe("equipment sets", function()
    it("shows the list at login in the controller interface, by default", function()
        start(true)
        assertRepaired()
    end)

    it("shows the list after each switch of the interface", function()
        start(false)
        for _, controller in ipairs({ true, false, true }) do
            Stubs.SwitchInterface(controller)
            assertBroken()
            Stubs.RunTimers()
            assertRepaired()
        end
    end)

    it("leaves a list that has a width where the game put it", function()
        load(true)
        local list, bar = pane().ScrollBox, pane().ScrollBar
        list:SetWidth(180)
        bar:ClearAllPoints()
        Stubs.Login()
        T.eq(list:GetWidth(), 180)
        T.eq(list:GetNumPoints(), 1)
        T.eq(bar:GetNumPoints(), 0)
    end)

    it("leaves a list whose width is secret alone", function()
        load(true)
        Stubs.state().secretListWidth = true
        Stubs.Login()
        T.eq(pane().ScrollBox:GetNumPoints(), 1)
        T.same(Stubs.state().errors, {})
    end)

    it("leaves the list alone while it's off, and shows it once turned on", function()
        local ns = start(true, { showEquipmentSets = false })
        assertBroken()
        Stubs.SwitchInterface(false)
        Stubs.RunTimers()
        assertBroken()
        ns.Options:Set("showEquipmentSets", true)
        Stubs.RunTimers()
        assertRepaired()
    end)

    it("keeps the list when turned off, until a reload", function()
        local ns = start(true)
        ns.Options:Set("showEquipmentSets", false)
        Stubs.RunTimers()
        assertRepaired()
    end)

    it("waits for the end of combat", function()
        start(false)
        Stubs.SetCombat(true)
        Stubs.SwitchInterface(true)
        Stubs.RunTimers()
        assertBroken()
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        assertRepaired()
    end)

    it("waits for the character window to close", function()
        start(false)
        CharacterFrame:Show()
        Stubs.SwitchInterface(true)
        Stubs.RunTimers()
        assertBroken()
        CharacterFrame:Hide()
        assertBroken()
        Stubs.RunTimers()
        assertRepaired()
    end)

    it("waits for the end of combat when the window closes in combat", function()
        start(false)
        CharacterFrame:Show()
        Stubs.SwitchInterface(true)
        Stubs.RunTimers()
        Stubs.SetCombat(true)
        CharacterFrame:Hide()
        Stubs.RunTimers()
        assertBroken()
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        assertRepaired()
    end)

    it("waits for the next close when the window is open again by then", function()
        start(false)
        CharacterFrame:Show()
        Stubs.SwitchInterface(true)
        Stubs.RunTimers()
        CharacterFrame:Hide()
        CharacterFrame:Show()
        Stubs.RunTimers()
        assertBroken()
        CharacterFrame:Hide()
        Stubs.RunTimers()
        assertRepaired()
    end)

    it("does nothing at the close when turned off meanwhile", function()
        local ns = start(false)
        CharacterFrame:Show()
        Stubs.SwitchInterface(true)
        Stubs.RunTimers()
        ns.Options:Set("showEquipmentSets", false)
        CharacterFrame:Hide()
        Stubs.RunTimers()
        assertBroken()
    end)

    local function copesWithout(what, remove)
        it("copes with a client without " .. what, function()
            load(true)
            remove()
            Stubs.Login()
            Stubs.Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
            Stubs.RunTimers()
            T.same(Stubs.state().errors, {})
        end)
    end

    -- A frame's missing child is false: a stub frame answers any other with a no-op method.
    copesWithout("the character window", function() _G.CharacterFrame = nil end)
    copesWithout("the paper doll", function() _G.PaperDollFrame = nil end)
    copesWithout("the pane", function() PaperDollFrame.EquipmentManagerPane = false end)
    copesWithout("the list", function() pane().ScrollBox = false end)
    copesWithout("the scroll bar", function() pane().ScrollBar = false end)

    for _, client in ipairs({ "retail", "classicEra" }) do
        it("does nothing on " .. client, function()
            load(false, { client = client })
            Stubs.Login()
            Stubs.SwitchInterface(true)
            Stubs.RunTimers()
            assertBroken()
        end)
    end
end)
