local _, ns = ...
local L = ns.L
local Options = ns.Options

-- Repairs and sells junk when a merchant window opens.
local Merchant = {}
ns.Merchant = Merchant

local POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0

local function lastBag()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

local function sellPrice(itemID)
    if not (C_Item and C_Item.GetItemInfo) then return nil end
    local price = select(11, C_Item.GetItemInfo(itemID))
    if ns.IsUsable(price) then return price end
    return nil
end

-- Every grey item in the bags that a merchant pays for: { bag, slot, count, value }.
function Merchant:FindJunk()
    local junk = {}
    for bag = 0, lastBag() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == POOR and not info.hasNoValue and not info.isLocked and info.itemID then
                local price = sellPrice(info.itemID)
                if price and price > 0 then
                    local count = info.stackCount or 1
                    junk[#junk + 1] = { bag = bag, slot = slot, count = count, value = price * count }
                end
            end
        end
    end
    return junk
end

function Merchant:SellJunk()
    local junk = self:FindJunk()
    if #junk == 0 then return end

    local total = 0
    for _, item in ipairs(junk) do
        total = total + item.value
    end

    -- The game's own "sell all junk" is a single request and keeps the buyback list intact. Some
    -- merchants turn it off; then the items go one by one, like a right-click would sell them.
    local frameAPI = C_MerchantFrame
    if frameAPI and frameAPI.SellAllJunkItems and frameAPI.IsSellAllJunkEnabled and frameAPI.IsSellAllJunkEnabled() then
        frameAPI.SellAllJunkItems()
    else
        for _, item in ipairs(junk) do
            C_Container.UseContainerItem(item.bag, item.slot)
        end
    end
    ns.Print(L.SOLD_JUNK:format(#junk, ns.FormatMoney(total)))
end

-- How much of a repair the guild bank pays: what's left of today's withdrawal limit (-1 for the
-- guild master), capped by what the bank holds.
local function guildFunds()
    local limit = GetGuildBankWithdrawMoney()
    local bank = GetGuildBankMoney() or 0
    if limit == -1 then return bank end
    return math.min(limit or 0, bank)
end

function Merchant:Repair()
    if not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    if Options:Get("guildRepair") and IsInGuild() and CanGuildBankRepair() then
        local guild = guildFunds()
        if guild >= cost then
            RepairAllItems(true)
            ns.Print(L.REPAIRED_GUILD:format(ns.FormatMoney(cost)))
            return
        end
        -- The guild covers what it can, our own gold the rest.
        local own = cost - guild
        if guild > 0 and GetMoney() >= own then
            RepairAllItems(true)
            ns.Print(L.REPAIRED_GUILD_PARTIAL:format(ns.FormatMoney(cost), ns.FormatMoney(guild), ns.FormatMoney(own)))
            return
        end
    end

    if GetMoney() >= cost then
        RepairAllItems(false)
        ns.Print(L.REPAIRED:format(ns.FormatMoney(cost)))
    else
        ns.Print(L.REPAIR_NO_MONEY:format(ns.FormatMoney(cost)))
    end
end

-- Repair first: selling is answered by the server later, so its gold isn't there yet anyway.
function Merchant:OnMerchantShow()
    if Options:Get("autoRepair") then
        self:Repair()
    end
    if Options:Get("sellJunk") then
        self:SellJunk()
    end
end

function Merchant:Init()
    ns.Events:On("MERCHANT_SHOW", function()
        Merchant:OnMerchantShow()
    end)
end
