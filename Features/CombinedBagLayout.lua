local _, ns = ...
local Options = ns.Options

-- Draws the combined bag from the top left, as the game does in its controller interface: the
-- backpack's first slot top left, the last bag at the bottom. With keyboard and mouse the game
-- starts the grid at the bottom right (ContainerFrameMixin:GetAnchorLayout, BottomRightToTopLeft
-- from the money frame), so the hearthstone, which a sort puts in the backpack's first slot, ends
-- up in the bottom right corner. Only the item buttons' anchors change, with SetPoint: same order,
-- size and spacing as Blizzard's layout (ContainerFrameMixin:UpdateItemLayout, copied here), only
-- the corner the grid starts in moves. The buttons aren't protected, so this runs in combat too.
local CombinedBagLayout = {}
ns.CombinedBagLayout = CombinedBagLayout

local KEY = "combinedBagTopLeft"
local COLUMNS = 10 -- ContainerFrameMixin:GetColumns for the combined bag
local SPACING = 5 -- ITEM_SPACING_X and ITEM_SPACING_Y
local ABOVE_MONEY = 4 -- the grid's bottom right corner sits this far above the money frame's top right

-- The bag's item buttons in Blizzard's order: bag by bag from the backpack, slot by slot, and the
-- locked extra slots of an account without an authenticator last (SortItemsByExtendedState).
local function byPlace(a, b)
    if a.extended ~= b.extended then return not a.extended end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

-- Reused on every run: it runs after every bag change while the bag is open. Each button keeps its
-- entry (the bag's buttons come from a pool, so they live on).
local ordered = {}
local entryOf = setmetatable({}, { __mode = "k" })

local function inOrder(bag)
    local count = 0
    for _, button in ipairs(bag.Items) do
        local bagID, slot = button:GetAttribute("bagid"), button:GetID()
        if not (ns.IsUsable(bagID) and ns.IsUsable(slot)) then return nil end
        local entry = entryOf[button]
        if not entry then
            entry = { button = button }
            entryOf[button] = entry
        end
        entry.bag, entry.slot, entry.extended = bagID, slot, button.isExtended == true
        count = count + 1
        ordered[count] = entry
    end
    for index = count + 1, #ordered do ordered[index] = nil end
    table.sort(ordered, byPlace)
    return ordered
end

-- Offsets of a cell of Blizzard's grid, counted from the bottom right, right to left and upwards.
local function cellOffset(cell, width, height)
    return -(cell % COLUMNS) * (width + SPACING), ABOVE_MONEY + math.floor(cell / COLUMNS) * (height + SPACING)
end

local function isAt(button, money, x, y)
    if button:GetNumPoints() ~= 1 then return false end
    local point, relativeTo, relativePoint, px, py = button:GetPoint(1)
    return point == "BOTTOMRIGHT" and relativeTo == money and relativePoint == "TOPRIGHT"
        and ns.IsUsable(px) and ns.IsUsable(py) and math.abs(px - x) < 0.01 and math.abs(py - y) < 0.01
end

local function place(button, money, x, y)
    if isAt(button, money, x, y) then return end
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", money, "TOPRIGHT", x, y)
end

-- Whether this client has the combined bag (Classic Era has only the separate bags).
function CombinedBagLayout.IsAvailable()
    return ContainerFrameCombinedBags ~= nil
end

function CombinedBagLayout:Apply()
    local bag = ContainerFrameCombinedBags
    local money = bag and bag.MoneyFrame
    if not (money and type(bag.Items) == "table" and bag:IsShown()) then return end
    -- In the controller interface the game starts at the top left itself, and switching interfaces
    -- lays the bag out again.
    if ns.IsControllerUI() then
        self.flipped = false
        return
    end
    local flip = Options:Get(KEY) == true
    if not (flip or self.flipped) then return end

    local entries = inOrder(bag)
    if not entries or #entries == 0 then return end
    local width, height = entries[1].button:GetWidth(), entries[1].button:GetHeight()
    if not (ns.IsUsable(width) and ns.IsUsable(height)) then return end
    local cells = math.ceil(#entries / COLUMNS) * COLUMNS
    for index, entry in ipairs(entries) do
        -- Item n of Blizzard's grid, counted from the bottom right, goes to the cell as far from the
        -- top left: the grid turned half way round.
        local blizzardX, blizzardY = cellOffset(index - 1, width, height)
        local ourX, ourY = cellOffset(cells - index, width, height)
        if flip then
            place(entry.button, money, ourX, ourY)
        elseif isAt(entry.button, money, ourX, ourY) then
            -- Turned off while the bag is open: back to Blizzard's cell. A closed bag gets Blizzard's
            -- layout again when it opens.
            place(entry.button, money, blizzardX, blizzardY)
        end
    end
    self.flipped = flip
end

local function apply()
    CombinedBagLayout:Apply()
end

local function schedule()
    ns.Later("combinedBagLayout", apply, true)
end

-- Blizzard lays the bag out when it opens (OnShow), when its size changes (a bag swapped, a
-- currency shown on it) and when the interface changes. Each wake-up compares the anchors first, so
-- one that changed nothing sets nothing.
function CombinedBagLayout:Init()
    Options:Watch({ KEY }, schedule)
    ns.OnControllerUIChange(schedule)
    ns.Events:On("BAG_CONTAINER_UPDATE", schedule)
    ns.Events:On("BAG_UPDATE_DELAYED", schedule)
    local bag = ContainerFrameCombinedBags
    if bag and bag.HookScript then
        bag:HookScript("OnShow", schedule)
        bag:HookScript("OnSizeChanged", schedule)
    end
end
