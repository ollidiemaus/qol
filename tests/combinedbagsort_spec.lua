local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns
end

local function openBag()
    ContainerFrameCombinedBags:Show()
    ContainerFrameCombinedBags.hooks.OnShow()
    Stubs.RunTimers()
end

describe("combined bag sort button", function()
    it("is left alone by default", function()
        start()
        openBag()
        T.eq(BagItemAutoSortButton:GetParent(), ContainerFrame1)
        T.falsy(BagItemAutoSortButton:IsVisible())
    end)

    it("shows on the combined bag when the option is on", function()
        start({ showCombinedBagSort = true })
        openBag()
        T.eq(BagItemAutoSortButton:GetParent(), ContainerFrameCombinedBags)
        T.truthy(BagItemAutoSortButton:IsVisible())
        T.truthy(BagItemAutoSortButton:PointFor("TOPRIGHT"))
    end)

    it("follows the option while the bag is open", function()
        local ns = start()
        openBag()
        ns.Options:Set("showCombinedBagSort", true)
        Stubs.RunTimers()
        T.truthy(BagItemAutoSortButton:IsVisible())
        ns.Options:Set("showCombinedBagSort", false)
        Stubs.RunTimers()
        T.falsy(BagItemAutoSortButton:IsVisible())
    end)

    it("does not take the button while the combined bag is closed", function()
        start({ showCombinedBagSort = true })
        Stubs.RunTimers()
        T.eq(BagItemAutoSortButton:GetParent(), ContainerFrame1)
    end)
end)
