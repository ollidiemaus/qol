local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    Stubs.RunTimers()
    return ns
end

-- What Blizzard's ContainerFrameMixin:UpdateSearchBox does on every bag update with keyboard and
-- mouse: the search box onto the bag, and its own sort button to the bag's top right.
local function blizzardBagUpdate()
    local bag = ContainerFrameCombinedBags
    BagItemSearchBox:SetParent(bag)
    BagItemSearchBox:ClearAllPoints()
    BagItemSearchBox:SetPoint("TOPLEFT", bag, "TOPLEFT", 62, -37)
    BagItemAutoSortButton:SetParent(bag)
    BagItemAutoSortButton:SetPoint("TOPRIGHT", bag, "TOPRIGHT", -9, -34)
    BagItemAutoSortButton:Show()
end

local function openBag()
    ContainerFrameCombinedBags:Show()
    blizzardBagUpdate()
    Stubs.RunTimers()
end

describe("combined bag sort button", function()
    it("adds nothing by default", function()
        local ns = start()
        openBag()
        T.falsy(ns.CombinedBagSort.button)
    end)

    it("shows on the combined bag, left of the search box, when the option is on", function()
        local ns = start({ showCombinedBagSort = true })
        local button = ns.CombinedBagSort.button
        T.eq(button:GetParent(), ContainerFrameCombinedBags)
        T.eq(button:GetNumPoints(), 1)
        local point = button:PointFor("RIGHT")
        T.eq(point[2], BagItemSearchBox)
        T.eq(point[3], "LEFT")
        T.falsy(button:IsVisible())
        openBag()
        T.truthy(button:IsVisible())
        T.eq(button.normalAtlas, "bags-button-autosort-up")
    end)

    it("stays put when Blizzard lays the bag out again", function()
        local ns = start({ showCombinedBagSort = true })
        openBag()
        ns.CombinedBagSort.button:Click()
        blizzardBagUpdate()
        local button = ns.CombinedBagSort.button
        T.truthy(button:IsVisible())
        T.eq(button:GetNumPoints(), 1)
        T.eq(button:PointFor("RIGHT")[2], BagItemSearchBox)
    end)

    it("sorts the bags when clicked", function()
        local ns = start({ showCombinedBagSort = true })
        openBag()
        ns.CombinedBagSort.button:Click()
        T.eq(Stubs.state().bagSorts, 1)
    end)

    it("explains itself in a tooltip", function()
        local ns = start({ showCombinedBagSort = true })
        local button = ns.CombinedBagSort.button
        button:RunScript("OnEnter")
        T.eq(GameTooltip.owner, button)
        T.eq(GameTooltip.lines[1].text, BAG_CLEANUP_BAGS)
        T.eq(GameTooltip.lines[2].text, BAG_CLEANUP_BAGS_DESCRIPTION)
        button:RunScript("OnLeave")
        T.falsy(GameTooltip.shown)
    end)

    it("follows the option while the bag is open", function()
        local ns = start()
        openBag()
        ns.Options:Set("showCombinedBagSort", true)
        Stubs.RunTimers()
        T.truthy(ns.CombinedBagSort.button:IsVisible())
        ns.Options:Set("showCombinedBagSort", false)
        Stubs.RunTimers()
        T.falsy(ns.CombinedBagSort.button:IsVisible())
    end)

    it("leaves Blizzard's sort button alone", function()
        start({ showCombinedBagSort = true })
        T.eq(BagItemAutoSortButton:GetParent(), ContainerFrame1)
        T.falsy(BagItemAutoSortButton:IsShown())
    end)
end)
