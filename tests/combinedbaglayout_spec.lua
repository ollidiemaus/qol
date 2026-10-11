local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns
end

-- A backpack of 16 and a bag of 12: 28 slots in three rows of 10.
local function openBag(extended)
    Stubs.FillCombinedBag({ 16, 12 }, extended)
    ContainerFrameCombinedBags:Show()
    ContainerFrameCombinedBags.hooks.OnShow()
    Stubs.RunTimers()
end

-- Where a button sits, as { x, y } from the money frame's top right; nil if not anchored there.
local function offset(bagID, slot)
    local button = Stubs.CombinedBagButton(bagID, slot)
    T.eq(button:GetNumPoints(), 1)
    local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
    if point ~= "BOTTOMRIGHT" or relativeTo ~= ContainerFrameCombinedBags.MoneyFrame or relativePoint ~= "TOPRIGHT" then
        return nil
    end
    return { x, y }
end

-- The offsets of a cell: columns from the right, rows from the bottom, 37 wide with 5 between.
local function cell(columnFromRight, rowFromBottom)
    return { -columnFromRight * 42, 4 + rowFromBottom * 42 }
end

describe("combined bag from the top left", function()
    it("leaves Blizzard's layout alone by default", function()
        start()
        openBag()
        T.same(offset(0, 1), cell(0, 0))
        T.same(offset(1, 12), cell(7, 2))
    end)

    it("puts the backpack's first slot top left and the last bag at the bottom", function()
        start({ combinedBagTopLeft = true })
        openBag()
        T.same(offset(0, 1), cell(9, 2)) -- top left
        T.same(offset(0, 10), cell(0, 2)) -- top right
        T.same(offset(0, 11), cell(9, 1)) -- next row, left
        T.same(offset(1, 12), cell(2, 0)) -- last one, bottom row with two cells free on the right
    end)

    it("puts the locked extra slots last, like Blizzard", function()
        start({ combinedBagTopLeft = true })
        openBag({ ["0:16"] = true })
        T.same(offset(0, 15), cell(5, 1))
        T.same(offset(1, 1), cell(4, 1)) -- the bag follows the backpack's last open slot
        T.same(offset(0, 16), cell(2, 0)) -- the locked slot comes last
    end)

    it("lays the bag out again after Blizzard does", function()
        start({ combinedBagTopLeft = true })
        openBag()
        Stubs.LayoutCombinedBag()
        Stubs.Fire("BAG_CONTAINER_UPDATE")
        Stubs.RunTimers()
        T.same(offset(0, 1), cell(9, 2))
    end)

    it("sets nothing when the buttons are already in place", function()
        start({ combinedBagTopLeft = true })
        openBag()
        local cleared = 0
        for _, button in ipairs(ContainerFrameCombinedBags.Items) do
            local clear = button.ClearAllPoints
            button.ClearAllPoints = function(self) cleared = cleared + 1; clear(self) end
        end
        Stubs.Fire("BAG_UPDATE_DELAYED")
        Stubs.RunTimers()
        T.eq(cleared, 0)
    end)

    it("follows the option while the bag is open", function()
        local ns = start()
        openBag()
        ns.Options:Set("combinedBagTopLeft", true)
        Stubs.RunTimers()
        T.same(offset(0, 1), cell(9, 2))
        ns.Options:Set("combinedBagTopLeft", false)
        Stubs.RunTimers()
        T.same(offset(0, 1), cell(0, 0))
        T.same(offset(1, 12), cell(7, 2))
    end)

    it("works in combat: the item buttons aren't protected", function()
        start({ combinedBagTopLeft = true })
        Stubs.SetCombat(true)
        openBag()
        T.same(offset(0, 1), cell(9, 2))
        Stubs.SetCombat(false)
    end)

    it("leaves the bag to the game in the controller interface", function()
        start({ combinedBagTopLeft = true })
        Stubs.SetControllerUI(true)
        openBag()
        T.same(offset(0, 1), cell(0, 0))
    end)

    it("does nothing while the bag is closed", function()
        start({ combinedBagTopLeft = true })
        Stubs.FillCombinedBag({ 16, 12 })
        Stubs.Fire("BAG_UPDATE_DELAYED")
        Stubs.RunTimers()
        T.same(offset(0, 1), cell(0, 0))
    end)
end)
