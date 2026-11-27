local _, ns = ...
local Options = ns.Options

-- Forever's character window loses its list of equipment sets when the game switches interfaces (and
-- at login in the controller interface): its switch code leaves the list one anchor and a height, so
-- no width. In the controller interface it also hides Equip and Save, whose "more actions" menu
-- doesn't open. This gives the list and its scroll bar the anchors of the game's layout file again,
-- which leave room for the buttons under New Set, and shows the game's Equip and Save. A list with a
-- width and a shown Save is left alone, so a fix of the game's ends this; a hidden Save also tells
-- that the controller interface is on.
--
-- Never while the character window is shown: re-anchoring could run the game's list code from here
-- and taint its rows. docs/dev/controller.md has the rest.
local EquipmentSets = {}
ns.EquipmentSets = EquipmentSets

local KEY = "showEquipmentSets"

-- The window was open when the list was to be checked: its close asks again.
local waitingForClose = false

local function repair()
    waitingForClose = false
    local window, pane = CharacterFrame, PaperDollFrame and PaperDollFrame.EquipmentManagerPane
    local list, scrollBar = pane and pane.ScrollBox, pane and pane.ScrollBar
    if not (window and list and scrollBar) or Options:Get(KEY) ~= true then return end
    local width, equip, save = list:GetWidth(), pane.EquipSet, pane.SaveSet
    -- A secret width doesn't count as missing; a hidden Save is the controller interface's either way.
    local noWidth = ns.IsUsable(width) and width <= 0
    local saveHidden = save and not save:IsShown()
    if not (noWidth or saveHidden) then return end
    if window:IsShown() then
        waitingForClose = true
        return
    end
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", pane, "TOPLEFT", 5, -8)
    list:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -20, 105)
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", list, "TOPRIGHT", -5, -12)
    scrollBar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 0, 0)
    if equip then equip:Show() end
    if save then save:Show() end
end

local function schedule()
    if Options:Get(KEY) == true then ns.Later("equipmentSets", repair) end
end

local function onWindowClosed()
    if waitingForClose then schedule() end
end

function EquipmentSets:Init()
    if not ns.IsForever() then return end
    Options:Watch({ KEY }, schedule)
    ns.OnControllerUIChange(schedule)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("CharacterFrame.Hide", onWindowClosed, EquipmentSets)
    end
    schedule()
end
