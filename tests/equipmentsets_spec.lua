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

-- Equip and Save, side by side under New Set.
local function assertButtons(shown)
    T.eq(pane().EquipSet:IsShown(), shown)
    T.eq(pane().SaveSet:IsShown(), shown)
end

-- The pane is 220 wide: 5 free on the left, 20 on the right for the scroll bar, 105 below for New Set
-- and, under it, Equip and Save.
local function assertListRepaired()
    local list, bar = pane().ScrollBox, pane().ScrollBar
    T.same(list.points, { { "TOPLEFT", pane(), "TOPLEFT", 5, -8 }, { "BOTTOMRIGHT", pane(), "BOTTOMRIGHT", -20, 105 } })
    T.same(bar.points, { { "TOPLEFT", list, "TOPRIGHT", -5, -12 }, { "BOTTOMLEFT", list, "BOTTOMRIGHT", 0, 0 } })
end

-- The tab as with keyboard and mouse.
local function assertRepaired()
    T.eq(pane().ScrollBox:GetWidth(), 195)
    assertListRepaired()
    assertButtons(true)
end

-- As the game's switch code left it: no list, and no Equip or Save in the controller interface.
local function assertBroken()
    T.eq(pane().ScrollBox:GetWidth(), 0)
    assertButtons(Stubs.state().interfaceStyle ~= 1)
end

describe("equipment sets", function()
    it("shows the list at login in the controller interface, by default", function()
        start(true)
        assertRepaired()
    end)

    it("shows Equip and Save at login in the controller interface", function()
        start(true)
        assertButtons(true)
    end)

    -- Equip and Save come back after each switch to the controller interface; with keyboard and
    -- mouse the game shows them itself.
    it("shows the list, Equip and Save after each switch of the interface", function()
        start(false)
        for _, controller in ipairs({ true, false, true }) do
            Stubs.SwitchInterface(controller)
            assertBroken()
            Stubs.RunTimers()
            assertRepaired()
        end
    end)

    it("leaves Equip and Save to the game with keyboard and mouse", function()
        start(true)
        Stubs.SwitchInterface(false)
        Stubs.RunTimers()
        assertButtons(true)
        T.same(pane().EquipSet.points, { { "BOTTOM", pane(), "BOTTOM", -50, 20 } })
        T.same(pane().SaveSet.points, { { "BOTTOM", pane(), "BOTTOM", 50, 20 } })
    end)

    -- A later client that gives the list its width, but over the space of the buttons it still hides.
    it("shows Equip and Save and makes room for them when the game fixes only the list", function()
        load(false)
        Stubs.state().fixedEquipmentSetList = true
        Stubs.Login()
        Stubs.SwitchInterface(true)
        T.eq(pane().ScrollBox:GetWidth(), 195)
        assertButtons(false)
        Stubs.RunTimers()
        assertRepaired()
    end)

    -- In the controller interface, as a later client that shows Equip and Save there would leave it;
    -- each test gives the list the layout of that client's own.
    local function loadWithButtonsShown()
        load(true)
        pane().EquipSet:Show()
        pane().SaveSet:Show()
    end

    it("leaves a list that has a width, with Save shown, where the game put it", function()
        loadWithButtonsShown()
        local list, bar = pane().ScrollBox, pane().ScrollBar
        list:SetWidth(180)
        bar:ClearAllPoints()
        Stubs.Login()
        T.eq(list:GetWidth(), 180)
        T.eq(list:GetNumPoints(), 1)
        T.eq(bar:GetNumPoints(), 0)
        assertButtons(true)
    end)

    it("leaves a list whose width is secret alone while Save is shown", function()
        loadWithButtonsShown()
        Stubs.state().secretListWidth = true
        Stubs.Login()
        T.eq(pane().ScrollBox:GetNumPoints(), 1)
        T.same(Stubs.state().errors, {})
    end)

    it("repairs a list whose width is secret while Save is hidden", function()
        load(true)
        Stubs.state().secretListWidth = true
        Stubs.Login()
        assertListRepaired()
        assertButtons(true)
        T.same(Stubs.state().errors, {})
    end)

    it("leaves the tab alone while it's off, and repairs it once turned on", function()
        local ns = start(true, { showEquipmentSets = false })
        assertBroken()
        for _, controller in ipairs({ false, true }) do
            Stubs.SwitchInterface(controller)
            Stubs.RunTimers()
            assertBroken()
        end
        ns.Options:Set("showEquipmentSets", true)
        Stubs.RunTimers()
        assertRepaired()
    end)

    it("keeps the list, Equip and Save when turned off, until a reload", function()
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
    copesWithout("Equip", function() pane().EquipSet = false end)
    copesWithout("Save", function() pane().SaveSet = false end)

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
