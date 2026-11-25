local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local TANK, HEAL = 111, 222

-- Logs in with empty bags of 16 slots and the given equipment sets, by ID.
local function start(savedOptions, sets, options)
    local ns = Stubs.LoadAddon(options)
    Stubs.SetBags({})
    Stubs.state().equipmentSets = sets or {}
    Stubs.Login(savedOptions)
    return ns
end

local function set(name, icon, ...)
    return { name = name, icon = icon, locations = { ... } }
end

local ON = { setMarks = true }

local function fire(event, ...)
    Stubs.Fire(event, ...)
    Stubs.RunTimers()
end

-- The mark a button shows: "icon" or "icon+", and its corner; nil for none.
local function markOn(button)
    local icon, corner, plus
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsVisible() then
            if region.kind == "FontString" then
                plus = region:GetText()
            elseif region.texture then
                icon, corner = region.texture, region:GetPoint(1)
            end
        end
    end
    if not icon then return nil end
    return icon .. (plus or ""), corner
end

-- Every mark shown: { ["bag:slot"] = "icon" }.
local function marks()
    Stubs.RunTimers()
    local found = {}
    for _, region in ipairs(Stubs.state().regions) do
        if region.kind == "ItemButton" and region:IsVisible() then
            local bag = region.bankTabID or region.bagID
            found[bag .. ":" .. (region.containerSlotID or region.slotID)] = markOn(region)
        end
    end
    return found
end

local function corner()
    Stubs.RunTimers()
    for _, region in ipairs(Stubs.state().regions) do
        if region.kind == "ItemButton" and region:IsVisible() and markOn(region) then
            return (select(2, markOn(region)))
        end
    end
end

describe("set marks", function()
    it("are off by default", function()
        start(nil, { [0] = set("Tank", TANK, Stubs.BagLocation(1, 3)) })
        ToggleAllBags()
        T.same(marks(), {})
        T.falsy(Stubs.Listens("EQUIPMENT_SETS_CHANGED"))
    end)

    it("mark a set's items with its icon in the combined bag", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(1, 3), Stubs.BagLocation(0, 16)) })
        ToggleAllBags()
        T.same(marks(), { ["1:3"] = "111", ["0:16"] = "111" })
    end)

    it("mark them in separate bags", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(1, 3), Stubs.BagLocation(4, 1)) })
        Stubs.SetSeparateBags(true)
        ToggleAllBags()
        T.same(marks(), { ["1:3"] = "111", ["4:1"] = "111" })
    end)

    it("mark them in the controller interface, and after a switch to it and back", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(1, 3)) })
        for _, controller in ipairs({ true, false }) do
            Stubs.SetControllerUI(controller)
            ToggleAllBags()
            T.same(marks(), { ["1:3"] = "111" })
            ToggleAllBags()
        end
    end)

    it("stay with their items when the game hands out the bag's buttons anew", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(1, 3)) })
        ToggleAllBags()
        T.same(marks(), { ["1:3"] = "111" })
        Stubs.CollapseBag()
        T.same(marks(), { ["1:3"] = "111" })
    end)

    it("show the first set by name, then by ID, with a plus for an item in several", function()
        local here = Stubs.BagLocation(0, 1)
        start(ON, { [0] = set("Tank", TANK, here, Stubs.BagLocation(0, 2)), [1] = set("Heal", HEAL, here) })
        ToggleAllBags()
        T.same(marks(), { ["0:1"] = "222+", ["0:2"] = "111" })
        Stubs.state().equipmentSets = { [7] = set("Same", TANK, here), [3] = set("Same", HEAL, here) }
        fire("EQUIPMENT_SETS_CHANGED")
        T.same(marks(), { ["0:1"] = "222+" })
    end)

    it("mark only the copy that's in the set", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(0, 2)) })
        local copies = {}
        for slot = 1, 2 do copies[slot] = { bag = 0, slot = slot, itemID = 5, quality = 1 } end
        Stubs.SetBags(copies)
        ToggleAllBags()
        T.same(marks(), { ["0:2"] = "111" })
    end)

    it("mark nothing for worn items, missing items and empty or ignored set slots", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.WornLocation(1), -1, 0, 1) })
        ToggleAllBags()
        T.same(marks(), {})
    end)

    it("copes with gaps in a set's locations, and a set without any", function()
        start(ON, { [0] = { name = "Tank", icon = TANK, locations = { [16] = Stubs.BagLocation(0, 2) } },
            [1] = { name = "Heal", icon = HEAL } })
        ToggleAllBags()
        T.same(marks(), { ["0:2"] = "111" })
    end)

    it("follow an item that moves, with the bags open", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(0, 2)) })
        ToggleAllBags()
        T.same(marks(), { ["0:2"] = "111" })
        Stubs.state().equipmentSets[0].locations = { Stubs.BagLocation(3, 4) }
        fire("BAG_UPDATE_DELAYED")
        T.same(marks(), { ["3:4"] = "111" })
        Stubs.state().equipmentSets[0].locations = { Stubs.WornLocation(5) }
        fire("PLAYER_EQUIPMENT_CHANGED", 5)
        T.same(marks(), {})
    end)

    it("follow sets created, renamed, given another icon and deleted", function()
        local here = Stubs.BagLocation(0, 2)
        start(ON)
        local sets = Stubs.state().equipmentSets
        ToggleAllBags()
        T.same(marks(), {})
        sets[0] = set("Tank", TANK, here)
        fire("EQUIPMENT_SETS_CHANGED")
        T.same(marks(), { ["0:2"] = "111" })
        sets[1] = set("Heal", HEAL, here)
        fire("EQUIPMENT_SETS_CHANGED")
        T.same(marks(), { ["0:2"] = "222+" })
        sets[0].name = "Bear"
        fire("EQUIPMENT_SETS_CHANGED")
        T.same(marks(), { ["0:2"] = "111+" })
        sets[0].icon = 333
        fire("EQUIPMENT_SETS_CHANGED")
        T.same(marks(), { ["0:2"] = "333+" })
        sets[0] = nil
        fire("EQUIPMENT_SETS_CHANGED")
        T.same(marks(), { ["0:2"] = "222" })
        sets[1] = nil
        fire("EQUIPMENT_SETS_CHANGED")
        T.same(marks(), {})
    end)

    it("show what changed while the bags were closed", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(0, 2)) })
        ToggleAllBags()
        T.same(marks(), { ["0:2"] = "111" })
        ToggleAllBags()
        Stubs.state().equipmentSets[0].locations = { Stubs.BagLocation(0, 5) }
        fire("BAG_UPDATE_DELAYED")
        ToggleAllBags()
        T.same(marks(), { ["0:5"] = "111" })
    end)

    for name, retail in pairs({ ["the bank"] = false, ["retail's bank"] = true }) do
        it("mark items in " .. name .. " and leave none behind on another page", function()
            start(ON, { [0] = set("Tank", TANK, Stubs.BankLocation(6, 1), Stubs.BankLocation(7, 2)) })
            local state = Stubs.state()
            state.retailBank = retail
            state.bankPages = { { { 6, 1 }, { 6, 2 } }, { { 7, 1 }, { 7, 2 } }, { { 8, 1 } } }
            Stubs.OpenBank()
            T.same(marks(), { ["6:1"] = "111" })
            Stubs.TurnBankPage(2)
            T.same(marks(), { ["7:2"] = "111" })
            Stubs.TurnBankPage(3)
            T.same(marks(), {})
            Stubs.TurnBankPage(1)
            T.same(marks(), { ["6:1"] = "111" })
            Stubs.CloseBank()
            T.same(marks(), {})
        end)
    end

    it("mark bags and bank together", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.BankLocation(6, 1), Stubs.BagLocation(0, 1)) })
        Stubs.state().bankPages = { { { 6, 1 } } }
        Stubs.OpenBank()
        OpenAllBags()
        T.same(marks(), { ["6:1"] = "111", ["0:1"] = "111" })
    end)

    it("sit in the top right corner, or the one chosen, at once", function()
        local ns = start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(0, 2)) })
        ToggleAllBags()
        T.eq(corner(), "TOPRIGHT")
        for _, choice in ipairs({ "TOPLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOPRIGHT" }) do
            ns.Options:Set("setMarkCorner", choice)
            T.eq(corner(), choice)
        end
    end)

    it("sit in the top right corner for a saved corner QoL doesn't know", function()
        start({ setMarks = true, setMarkCorner = "MIDDLE" }, { [0] = set("Tank", TANK, Stubs.BagLocation(0, 2)) })
        ToggleAllBags()
        T.eq(corner(), "TOPRIGHT")
    end)

    it("come and go with the option while the bags are open", function()
        local ns = start(nil, { [0] = set("Tank", TANK, Stubs.BagLocation(0, 2)) })
        ToggleAllBags()
        T.same(marks(), {})
        ns.Options:Set("setMarks", true)
        T.same(marks(), { ["0:2"] = "111" })
        ns.Options:Set("setMarks", false)
        T.same(marks(), {})
        T.falsy(Stubs.Listens("BAG_UPDATE_DELAYED"))
        Stubs.state().equipmentSets[0].locations = { Stubs.BagLocation(0, 9) }
        ns.Options:Set("setMarks", true)
        T.same(marks(), { ["0:9"] = "111" })
    end)

    it("show and change in combat", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(0, 2)) })
        Stubs.SetCombat(true)
        ToggleAllBags()
        T.same(marks(), { ["0:2"] = "111" })
    end)

    it("wait for combat to end on buttons that are protected, or may be", function()
        start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(0, 2), Stubs.BagLocation(0, 3)) })
        ToggleAllBags()
        ToggleAllBags()
        for _, button in ipairs(ContainerFrameCombinedBags.Items) do button.secretSecurity = true end
        Stubs.RunTimers()
        Stubs.state().equipmentSets[0].locations = { Stubs.BagLocation(0, 5) }
        Stubs.SetCombat(true)
        ToggleAllBags()
        fire("BAG_UPDATE_DELAYED")
        T.same(marks(), {})
        Stubs.SetCombat(false)
        T.same(marks(), { ["0:5"] = "111" })
    end)

    it("leave out what the game keeps secret", function()
        local SECRET = Stubs.SECRET
        start(ON, {
            [0] = set("Tank", TANK, SECRET, Stubs.BagLocation(0, 2)),
            [1] = set(SECRET, HEAL, Stubs.BagLocation(0, 3)),
            [2] = set("Icon", SECRET, Stubs.BagLocation(0, 4)),
            [3] = { name = "Locations", icon = HEAL, locations = SECRET },
        })
        ToggleAllBags()
        T.same(marks(), { ["0:2"] = "111" })
        ContainerFrameCombinedBags.Items[1].bagID = SECRET
        ContainerFrameCombinedBags.Items[2].slotID = SECRET
        fire("BAG_UPDATE_DELAYED")
        T.eq(markOn(ContainerFrameCombinedBags.Items[1]), nil)
        Stubs.state().bankPages = { {} }
    end)

    it("do nothing where the bank panel is missing", function()
        Stubs.LoadAddon()
        Stubs.SetBags({})
        _G.BankPanel = nil
        Stubs.state().equipmentSets = { [0] = set("Tank", TANK, Stubs.BagLocation(0, 2)) }
        Stubs.Login(ON)
        ToggleAllBags()
        T.same(marks(), { ["0:2"] = "111" })
    end)

    it("aren't there on Classic Era", function()
        local ns = start(ON, { [0] = set("Tank", TANK, Stubs.BagLocation(0, 2)) }, { client = "classicEra" })
        T.falsy(ns.SetMarks.IsAvailable())
        fire("BAG_UPDATE_DELAYED")
        T.falsy(Stubs.Listens("EQUIPMENT_SETS_CHANGED"))
        ns.Options:Set("setMarks", false)
        ns.Options:Set("setMarks", true)
        Stubs.RunTimers()
        T.falsy(Stubs.Listens("EQUIPMENT_SETS_CHANGED"))
    end)
end)
