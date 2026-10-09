local _, ns = ...
local L = ns.L
local Options = ns.Options

-- IDs and vendor prices in tooltips. Both hook the game's tooltip data processor, which runs our
-- callbacks insecurely after Blizzard built the lines and then resizes the tooltip itself. Tooltip
-- data can hold secret values in combat (auras, units): those are left out, never compared.
local Tooltips = {}
ns.Tooltips = Tooltips

local LABEL_COLOR = { r = 0.6, g = 0.6, b = 0.6 }

local function addID(tooltip, label, id)
    if not ns.IsUsable(id) then return end
    tooltip:AddDoubleLine(label, tostring(id), LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, 1, 1, 1)
end

-- "Creature-0-1465-0-2105-448-000043F59F": the sixth field is the NPC ID.
function Tooltips.NpcIDFromGUID(guid)
    if not ns.IsUsable(guid) or type(guid) ~= "string" then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

local function onUnit(tooltip, data)
    if not Options:Get("tooltipIDs") then return end
    addID(tooltip, L.ID_NPC, Tooltips.NpcIDFromGUID(data.guid))
end

-- A tooltip type whose data.id is the ID worth showing, with the label for it.
local function idHandler(label)
    return function(tooltip, data)
        if not Options:Get("tooltipIDs") then return end
        addID(tooltip, label, data.id)
    end
end

-- The game adds its own sell price line in some places (at a merchant, at least), and it can show
-- the price of a single item for a whole stack. Where we can price the item ourselves, that line is
-- dropped in favor of ours (see onGameSellPriceLine), so there's always one line with the stack
-- total. Set by Init when the client lets us drop lines.
local replacesGameLine = false

local function sellPriceLineType()
    return Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice
end

-- A price range (minimum and maximum) is something only the game knows; such a line stays.
local function isPriceRange(lineData)
    local maxPrice = lineData.maxPrice
    return ns.IsUsable(maxPrice) and type(maxPrice) == "number" and maxPrice >= 1
end

-- The game's sell price line that stays in the tooltip, if any.
local function keptGameLine(data)
    local lineType = sellPriceLineType()
    if not lineType or type(data.lines) ~= "table" then return nil end
    for _, line in ipairs(data.lines) do
        if ns.IsUsable(line.type) and line.type == lineType then
            if not replacesGameLine or isPriceRange(line) then return line end
        end
    end
    return nil
end

local function tooltipInfo(tooltip)
    if tooltip.GetProcessingTooltipInfo then
        local info = tooltip:GetProcessingTooltipInfo()
        if info then return info end
    end
    return tooltip.GetPrimaryTooltipInfo and tooltip:GetPrimaryTooltipInfo() or nil
end

local function usableCount(count)
    return ns.IsUsable(count) and type(count) == "number" and count >= 1
end

-- How many items the tooltip is about. A bag or bank tooltip names its slot, which gives the real
-- stack size whatever bag addon shows it. Other item buttons carry it in button.count.
function Tooltips.StackCount(tooltip)
    local info = tooltipInfo(tooltip)
    local args = info and info.getterName == "GetBagItem" and info.getterArgs
    if type(args) == "table" and ns.IsUsable(args[1]) and ns.IsUsable(args[2]) then
        local item = C_Container.GetContainerItemInfo(args[1], args[2])
        if item and usableCount(item.stackCount) then
            return item.stackCount
        end
    end
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    local count = type(owner) == "table" and owner.count
    if usableCount(count) then
        return count
    end
    return 1
end

-- Total, unit price and count for an item tooltip, or nil when there's nothing to show.
local function sellPrice(tooltip, itemID)
    if tooltip.isShopping then return nil end
    if not ns.IsUsable(itemID) or not (C_Item and C_Item.GetItemInfo) then return nil end
    local price = select(11, C_Item.GetItemInfo(itemID))
    if not ns.IsUsable(price) or type(price) ~= "number" or price <= 0 then return nil end
    local count = Tooltips.StackCount(tooltip)
    return price * count, price, count
end

-- Line pre-call for the game's sell price line: returning true drops it.
local function onGameSellPriceLine(tooltip, lineData)
    if not Options:Get("tooltipSellPrice") or isPriceRange(lineData) then return false end
    local info = tooltipInfo(tooltip)
    local data = info and info.tooltipData
    return data ~= nil and sellPrice(tooltip, data.id) ~= nil
end

function Tooltips.AddSellPrice(tooltip, data)
    if not Options:Get("tooltipSellPrice") or keptGameLine(data) then return end
    local total, price, count = sellPrice(tooltip, data.id)
    if not total then return end
    local text = ns.FormatMoney(total)
    if count > 1 then
        text = L.SELL_PRICE_STACK:format(text, ns.FormatMoney(price))
    end
    tooltip:AddLine((SELL_PRICE or L.SELL_PRICE) .. ": " .. text, 1, 1, 1)
end

local function onItem(tooltip, data)
    Tooltips.AddSellPrice(tooltip, data)
    if Options:Get("tooltipIDs") then
        addID(tooltip, L.ID_ITEM, data.id)
    end
end

function Tooltips:Init()
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType) then
        return
    end
    -- By name, so a type this client lacks is skipped instead of breaking the rest.
    local handlers = {
        Item = onItem,
        Toy = idHandler(L.ID_ITEM),
        Spell = idHandler(L.ID_SPELL),
        UnitAura = idHandler(L.ID_SPELL),
        Unit = onUnit,
        Quest = idHandler(L.ID_QUEST),
        Currency = idHandler(L.ID_CURRENCY),
        Achievement = idHandler(L.ID_ACHIEVEMENT),
    }
    for typeName, handler in pairs(handlers) do
        local tooltipType = Enum.TooltipDataType[typeName]
        if tooltipType then
            TooltipDataProcessor.AddTooltipPostCall(tooltipType, function(tooltip, data)
                if data then handler(tooltip, data) end
            end)
        end
    end

    if TooltipDataProcessor.AddLinePreCall and sellPriceLineType() then
        TooltipDataProcessor.AddLinePreCall(sellPriceLineType(), function(tooltip, lineData)
            return lineData and onGameSellPriceLine(tooltip, lineData) or false
        end)
        replacesGameLine = true
    end
end
