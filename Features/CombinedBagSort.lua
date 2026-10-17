local _, ns = ...
local Options = ns.Options

-- Shows a sort (clean up) button on the combined bag, left of the search box. Forever's combined bag
-- has one only out of sight: Blizzard's BagItemAutoSortButton sits at the bag's top right, under the
-- bag bar (GamepadBagBar, a child of the bag in both interfaces), and the controller interface hides
-- it. Moving Blizzard's button didn't last: the bag's UpdateSearchBox, run on every bag update (a
-- sort, loot, a quest), anchors it at the top right again. So this is a button of our own that does
-- what Blizzard's does (same art, tooltip, sound and C_Container.SortBags), which Blizzard's code
-- never touches. Blizzard's button is left alone.
local CombinedBagSort = {}
ns.CombinedBagSort = CombinedBagSort

local KEY = "showCombinedBagSort"

local function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(BAG_CLEANUP_BAGS, 1, 1, 1)
    GameTooltip:AddLine(BAG_CLEANUP_BAGS_DESCRIPTION, nil, nil, nil, true)
    GameTooltip:Show()
end

local function sort()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.UI_BAG_SORTING_01) end
    C_Container.SortBags()
end

-- Made without a parent: SmartNavigation hooks CreateFrame, and a frame made inside an open
-- controller window makes it rebuild that window from our code.
local function createButton()
    local button = CreateFrame("Button")
    button:SetSize(28, 26)
    button:SetNormalAtlas("bags-button-autosort-up")
    button:SetPushedAtlas("bags-button-autosort-down")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local highlight = button:GetHighlightTexture()
    highlight:ClearAllPoints()
    highlight:SetSize(24, 23)
    highlight:SetPoint("CENTER")
    button:SetScript("OnClick", sort)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function CombinedBagSort:Apply()
    local bag, search = ContainerFrameCombinedBags, BagItemSearchBox
    if not (bag and search) then return end
    local button = self.button
    if Options:Get(KEY) then
        if not button then
            button = createButton()
            self.button = button
            button:SetParent(bag)
            -- Left of the search box, which Blizzard puts on the combined bag each time the bag is
            -- laid out; the right side has the bag bar.
            button:SetPoint("RIGHT", search, "LEFT", -4, 0)
        end
        button:Show()
    elseif button then
        button:Hide()
    end
end

local function apply()
    CombinedBagSort:Apply()
end

local function schedule()
    ns.Later("combinedBagSort", apply)
end

function CombinedBagSort:Init()
    Options:Watch({ KEY }, schedule)
    schedule()
end
