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
        -- No search box on the bag yet: pinned to the bag's top left.
        T.truthy(BagItemAutoSortButton:PointFor("TOPLEFT"))
    end)

    it("sits left of the search box when the bag has one", function()
        start({ showCombinedBagSort = true })
        BagItemSearchBox:SetParent(ContainerFrameCombinedBags)
        openBag()
        local point = BagItemAutoSortButton:PointFor("RIGHT")
        T.eq(point[2], BagItemSearchBox)
        T.eq(point[3], "LEFT")
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
