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

-- The item's sell price, or nil; and false as the second value while the client hasn't loaded the
-- item's info yet (C_Item.GetItemInfo returns nothing for it then).
local function sellPrice(itemID)
    if not (C_Item and C_Item.GetItemInfo) then return nil, true end
    local name, _, _, _, _, _, _, _, _, _, price = C_Item.GetItemInfo(itemID)
    if name == nil then return nil, false end
    if ns.IsUsable(price) then return price, true end
    return nil, true
end

-- Every grey item in the bags that a merchant pays for: { bag, slot, count, value }. Second, the
-- IDs of grey items whose info isn't loaded yet, as keys (nil when there are none).
function Merchant:FindJunk()
    local junk, unloaded = {}, nil
    for bag = 0, lastBag() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == POOR and not info.hasNoValue and not info.isLocked and info.itemID then
                local price, loaded = sellPrice(info.itemID)
                if not loaded then
                    unloaded = unloaded or {}
                    unloaded[info.itemID] = true
                elseif price and price > 0 then
                    local count = info.stackCount or 1
                    junk[#junk + 1] = { bag = bag, slot = slot, count = count, value = price * count }
                end
            end
        end
    end
    return junk, unloaded
end

local function sell(junk)
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

-- A grey item whose info the client hasn't loaded has no price yet, so the junk waits for the
-- client to load it (GET_ITEM_INFO_RECEIVED), at most LOAD_SECONDS, and is then sold all at once:
-- "sell all junk" would sell such an item too, and the count and value said would leave it out.
-- Closing the merchant ends the wait.
local LOAD_SECONDS = 1
local unloadedIDs -- the item IDs waited for, as keys, while waiting
local waits = 0 -- counts the waits, so an earlier wait's timer ends none after it
local onItemInfo, stopWaiting

local function finish()
    if not unloadedIDs then return end
    stopWaiting()
    sell((Merchant:FindJunk()))
end

function onItemInfo(_, itemID)
    if not (unloadedIDs and unloadedIDs[itemID]) then return end
    unloadedIDs[itemID] = nil
    if next(unloadedIDs) == nil then finish() end
end

function stopWaiting()
    unloadedIDs = nil
    ns.Events:Off("GET_ITEM_INFO_RECEIVED", onItemInfo)
    ns.Events:Off("MERCHANT_CLOSED", stopWaiting)
end

function Merchant:SellJunk()
    if unloadedIDs then return end
    local junk, unloaded = self:FindJunk()
    if not unloaded then
        sell(junk)
        return
    end
    unloadedIDs = unloaded
    ns.Events:On("GET_ITEM_INFO_RECEIVED", onItemInfo)
    ns.Events:On("MERCHANT_CLOSED", stopWaiting)
    if C_Item.RequestLoadItemDataByID then
        for itemID in pairs(unloaded) do C_Item.RequestLoadItemDataByID(itemID) end
    end
    waits = waits + 1
    local wait = waits
    C_Timer.After(LOAD_SECONDS, function()
        if wait == waits then finish() end
    end)
end

local function guildFunds()
    local limit = GetGuildBankWithdrawMoney()
    local bank = GetGuildBankMoney() or 0
    if limit == -1 then return bank end
    return math.min(limit or 0, bank)
end

-- Whether this client has guild banks: Blizzard_GuildBankUI's bootstrap defines the loader at
-- startup on Forever and retail. Classic Era has no guild banks; its UI names the guild bank calls
-- only in dead code.
function Merchant.HasGuildBank()
    return GuildBankFrame_LoadUI ~= nil
end

function Merchant:Repair()
    if not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    if Options:Get("guildRepair") and Merchant.HasGuildBank() and IsInGuild() and CanGuildBankRepair() then
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
