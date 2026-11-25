local _, ns = ...
local Options = ns.Options

-- Set marks: a small copy of an equipment set's icon on every item in the game's bags and bank that
-- belongs to the set. Which places belong to which sets comes from the game (C_EquipmentSet's item
-- locations), so no items are compared; a place in several sets gets the first one's icon, by name,
-- and a plus.
-- A mark is textures of ours on the game's item button, kept in a table of ours by button. The game
-- reuses the buttons for other places, so each refresh goes through the buttons shown, reads their place
-- with their own getters, and hides every mark it didn't come across. See
-- docs/dev/tooltips-chat-bags-mail.md for how it stays taint-safe.
local SetMarks = {}
ns.SetMarks = SetMarks

local KEY, CORNER = "setMarks", "setMarkCorner"

-- In the settings' order.
SetMarks.CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

local SIZE, EDGE, INSET = 16, 1, 2
local BRONZE = { 0.66, 0.47, 0.24 }
-- Over the button's icon and border, under its search shade (OVERLAY 4).
local LAYER, SUBLEVEL = "OVERLAY", 3
-- More than a bag has slots, to make one number of a bag and a slot.
local SLOTS = 1000

-- Per corner, which way its offset goes in from the button's edges.
local INWARD = { TOPLEFT = { 1, -1 }, TOPRIGHT = { -1, -1 }, BOTTOMLEFT = { 1, 1 }, BOTTOMRIGHT = { -1, 1 } }

local on = false
-- The sets' places: bag * SLOTS + slot -> the first set's icon, and true for a place in several sets.
-- Rebuilt on the next refresh that needs them while stale.
local icons, several = {}, {}
local stale = true
-- button -> its mark, made once. mark.run is the refresh that last came across it.
local marks = {}
local run = 0

local function isNumber(value)
    return ns.IsUsable(value) and type(value) == "number"
end

local function byName(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
end

local function addPlaces(set)
    local locations = C_EquipmentSet.GetItemLocations(set.id)
    if not ns.IsUsable(locations) then return end
    for _, location in pairs(locations) do
        -- Worn items, empty set slots (0), ignored ones (1) and missing items (-1) have no bag.
        local place = isNumber(location) and EquipmentManager_GetLocationData(location)
        if place and place.bag and place.slot then
            local key = place.bag * SLOTS + place.slot
            if icons[key] == nil then
                icons[key] = set.icon
            else
                several[key] = true
            end
        end
    end
end

local function readSets()
    stale = false
    icons, several = {}, {}
    local sets = {}
    for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
        if isNumber(id) and ns.IsUsable(name) and ns.IsUsable(icon) then
            sets[#sets + 1] = { id = id, name = name, icon = icon }
        end
    end
    table.sort(sets, byName)
    for _, set in ipairs(sets) do addPlaces(set) end
end

local function newEdge(button, icon, from, to)
    local edge = button:CreateTexture(nil, LAYER, nil, SUBLEVEL)
    edge:SetColorTexture(BRONZE[1], BRONZE[2], BRONZE[3])
    edge:SetPoint(from[1], icon, from[2], from[3], from[4])
    edge:SetPoint(to[1], icon, to[2], to[3], to[4])
    return edge
end

local function newMark(button)
    local icon = button:CreateTexture(nil, LAYER, nil, SUBLEVEL)
    icon:SetSize(SIZE - 2 * EDGE, SIZE - 2 * EDGE)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local plus = button:CreateFontString(nil, LAYER, "NumberFontNormalSmall")
    plus:SetDrawLayer(LAYER, SUBLEVEL)
    plus:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    plus:SetText("+")
    -- The frame: four edges around the icon.
    return { icon = icon, plus = plus, shown = true, edges = {
        newEdge(button, icon, { "BOTTOMLEFT", "TOPLEFT", -EDGE, 0 }, { "TOPRIGHT", "TOPRIGHT", EDGE, EDGE }),
        newEdge(button, icon, { "TOPLEFT", "BOTTOMLEFT", -EDGE, 0 }, { "BOTTOMRIGHT", "BOTTOMRIGHT", EDGE, -EDGE }),
        newEdge(button, icon, { "TOPLEFT", "TOPLEFT", -EDGE, 0 }, { "BOTTOMRIGHT", "BOTTOMLEFT", 0, 0 }),
        newEdge(button, icon, { "TOPLEFT", "TOPRIGHT", 0, 0 }, { "BOTTOMRIGHT", "BOTTOMRIGHT", EDGE, 0 }),
    } }
end

local function setShown(mark, shown)
    if mark.shown == shown then return end
    mark.shown = shown
    mark.icon:SetShown(shown)
    for _, edge in ipairs(mark.edges) do edge:SetShown(shown) end
end

local function hide(mark)
    setShown(mark, false)
    mark.plus:Hide()
end

local function place(mark, button, corner)
    if mark.corner == corner then return end
    mark.corner = corner
    local inward, offset = INWARD[corner], INSET + EDGE
    mark.icon:ClearAllPoints()
    mark.icon:SetPoint(corner, button, corner, inward[1] * offset, inward[2] * offset)
end

local refresh

-- The buttons of the bags and the bank aren't protected; if one turns out to be, it waits for combat
-- to end.
local function mustWait(button)
    if not InCombatLockdown() then return false end
    local protected = button:IsProtected()
    if ns.IsUsable(protected) and not protected then return false end
    ns.Later("setMarksAfterCombat", refresh)
    return true
end

local function markButton(button, bag, slot, corner)
    if not (isNumber(bag) and isNumber(slot)) then return end
    if stale then readSets() end
    local key = bag * SLOTS + slot
    local icon, mark = icons[key], marks[button]
    if not (icon or mark) then return end
    if mustWait(button) then
        if mark then mark.run = run end
        return
    end
    if not icon then return end
    if not mark then
        mark = newMark(button)
        marks[button] = mark
    end
    mark.run = run
    place(mark, button, corner)
    mark.icon:SetTexture(icon)
    mark.plus:SetShown(several[key] == true)
    setShown(mark, true)
end

local function markBag(frame, corner)
    if not (frame and frame:IsVisible() and frame.Items) then return end
    for _, button in ipairs(frame.Items) do
        markButton(button, button:GetBagID(), button:GetID(), corner)
    end
end

local function markBank(panel, corner)
    if not (panel and panel:IsVisible() and panel.itemButtonPool) then return end
    for button in panel.itemButtonPool:EnumerateActive() do
        markButton(button, button:GetBankTabID(), button:GetContainerSlotID(), corner)
    end
end

function refresh()
    run = run + 1
    if on then
        local corner = Options:Get(CORNER)
        if not INWARD[corner] then corner = Options:GetDefault(CORNER) end
        markBag(ContainerFrameCombinedBags, corner)
        for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do markBag(frame, corner) end
        markBank(BankPanel, corner)
    end
    for _, mark in pairs(marks) do
        if mark.run ~= run then hide(mark) end
    end
end

local function schedule()
    ns.Later("setMarks", refresh, true)
end

local function onChange()
    stale = true
    schedule()
end

local events = ns.Events:NewGroup({ "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANK_TABS_CHANGED",
    "EQUIPMENT_SETS_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }, onChange)

-- The game generates an open frame's buttons anew when a bag is collapsed in the controller interface,
-- which no event says. A hook can't be removed: it's installed the first time the option is on.
local hooked = false

local function hookBags()
    if hooked or not ContainerFrame_GenerateFrame then return end
    hooked = true
    hooksecurefunc("ContainerFrame_GenerateFrame", function()
        if on then schedule() end
    end)
end

-- Forever announces the bank's pages through EventRegistry; retail's bank has tabs, which only the
-- panel's own callbacks announce.
local function setListening(listen)
    events:SetOn(listen)
    local panel = BankPanel and BankPanel.RegisterCallback and BankPanel
    if listen then
        hookBags()
        EventRegistry:RegisterCallback("ContainerFrame.OpenBag", schedule, SetMarks)
        EventRegistry:RegisterCallback("BankPanelMixin.PageInfoChanged", schedule, SetMarks)
        if panel then panel:RegisterCallback("NewBankTabSelected", schedule, SetMarks) end
    else
        EventRegistry:UnregisterCallback("ContainerFrame.OpenBag", SetMarks)
        EventRegistry:UnregisterCallback("BankPanelMixin.PageInfoChanged", SetMarks)
        if panel then panel:UnregisterCallback("NewBankTabSelected", SetMarks) end
    end
end

local function apply()
    local wanted = Options:Get(KEY) == true
    if wanted == on then return end
    on = wanted
    setListening(on)
    onChange()
end

local function moveMarks()
    if on then schedule() end
end

-- Forever and retail, not Classic Era.
function SetMarks.IsAvailable()
    return C_EquipmentSet ~= nil and C_EquipmentSet.GetItemLocations ~= nil and EquipmentManager_GetLocationData ~= nil
        and ContainerFrameContainer ~= nil and ContainerFrameContainer.ContainerFrames ~= nil
        and ContainerFrameCombinedBags ~= nil
end

function SetMarks:Init()
    if not self.IsAvailable() then return end
    Options:Watch({ KEY }, apply)
    Options:Watch({ CORNER }, moveMarks)
    apply()
end
