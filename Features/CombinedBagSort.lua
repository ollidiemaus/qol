local _, ns = ...
local Options = ns.Options

-- Shows the sort (clean up) button on the combined bag, which the default UI leaves out on some
-- clients. The button is Blizzard's own BagItemAutoSortButton; it is only reparented, anchored and
-- shown, never written to, and only while the combined bag is open.
local CombinedBagSort = {}
ns.CombinedBagSort = CombinedBagSort

local KEY = "showCombinedBagSort"

function CombinedBagSort:Apply()
    local bag, button = ContainerFrameCombinedBags, BagItemAutoSortButton
    if not (bag and button) then return end
    if Options:Get(KEY) then
        if bag:IsShown() then
            if button:GetParent() ~= bag then
                button:SetParent(bag)
            end
            button:ClearAllPoints()
            -- Left of the search box: the right side already has another button.
            local search = BagItemSearchBox
            if search and search:GetParent() == bag then
                button:SetPoint("RIGHT", search, "LEFT", -4, 0)
            else
                button:SetPoint("TOPLEFT", bag, "TOPLEFT", 10, -34)
            end
            button:Show()
            self.shownByUs = true
        end
    elseif self.shownByUs then
        -- Blizzard shows the button again by itself the next time the bag is laid out, if the
        -- client wants it there.
        self.shownByUs = false
        if button:GetParent() == bag then
            button:Hide()
        end
    end
end

local function schedule()
    ns.Later("combinedBagSort", function() CombinedBagSort:Apply() end)
end

function CombinedBagSort:Init()
    Options:Watch({ KEY }, schedule)
    ns.Events:On("BAG_UPDATE_DELAYED", schedule)
    local bag = ContainerFrameCombinedBags
    if bag and bag.HookScript then
        bag:HookScript("OnShow", schedule)
    end
    schedule()
end
