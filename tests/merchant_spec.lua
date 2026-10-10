local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local POOR, COMMON = 0, 1

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns, Stubs.state()
end

local function openMerchant()
    Stubs.Fire("MERCHANT_SHOW")
end

describe("selling junk", function()
    it("sells all grey items with the game's sell-all and reports count and value", function()
        local _, state = start()
        Stubs.SetBags({
            { bag = 0, slot = 1, itemID = 100, quality = POOR, count = 3, price = 10 },
            { bag = 2, slot = 5, itemID = 101, quality = POOR, count = 1, price = 250 },
            { bag = 1, slot = 2, itemID = 200, quality = COMMON, count = 1, price = 999 },
        })
        openMerchant()
        T.eq(state.soldAll, 1)
        T.eq(#state.used, 0)
        T.same(state.messages, { "|cff33ff99Quality of Life|r: Sold 2 junk |4item:items; for 280c." })
    end)

    it("ignores grey items without value, without price and locked ones", function()
        local ns = start()
        Stubs.SetBags({
            { bag = 0, slot = 1, itemID = 100, quality = POOR, price = 10, hasNoValue = true },
            { bag = 0, slot = 2, itemID = 101, quality = POOR, price = 0 },
            { bag = 0, slot = 3, itemID = 102, quality = POOR, price = 5, isLocked = true },
        })
        T.eq(#ns.Merchant:FindJunk(), 0)
    end)

    it("sells item by item where the merchant has sell-all turned off", function()
        local _, state = start()
        state.sellAllEnabled = false
        Stubs.SetBags({
            { bag = 0, slot = 1, itemID = 100, quality = POOR, price = 10 },
            { bag = 3, slot = 7, itemID = 101, quality = POOR, price = 20 },
        })
        openMerchant()
        T.eq(state.soldAll, 0)
        T.same(state.used, { "0:1", "3:7" })
    end)

    it("does nothing without junk", function()
        local _, state = start()
        Stubs.SetBags({ { bag = 0, slot = 1, itemID = 200, quality = COMMON, price = 50 } })
        openMerchant()
        T.eq(state.soldAll, 0)
        T.eq(#state.messages, 0)
    end)

    it("does nothing while turned off", function()
        local _, state = start({ sellJunk = false })
        Stubs.SetBags({ { bag = 0, slot = 1, itemID = 100, quality = POOR, price = 10 } })
        openMerchant()
        T.eq(state.soldAll, 0)
    end)
end)

describe("repairing", function()
    -- Repairs are opt-in; these turn them on.
    local REPAIR = { autoRepair = true }
    local GUILD_REPAIR = { autoRepair = true, guildRepair = true }

    local function repairState(state, fields)
        state.canRepair = true
        for key, value in pairs(fields) do state[key] = value end
    end

    it("pays with own gold", function()
        local _, state = start(REPAIR)
        repairState(state, { repairCost = 500, money = 1000 })
        openMerchant()
        T.same(state.repairs, { "own" })
        T.eq(state.messages[1], "|cff33ff99Quality of Life|r: Repaired for 500c.")
    end)

    it("lets the guild pay when its funds cover the cost", function()
        local _, state = start(GUILD_REPAIR)
        repairState(state, { repairCost = 500, money = 0, inGuild = true, guildCanRepair = true,
            guildLimit = 800, guildMoney = 10000 })
        openMerchant()
        T.same(state.repairs, { "guild" })
        T.eq(state.messages[1], "|cff33ff99Quality of Life|r: Repaired for 500c from the guild bank.")
    end)

    it("treats a withdrawal limit of -1 (guild master) as the whole bank", function()
        local _, state = start(GUILD_REPAIR)
        repairState(state, { repairCost = 500, money = 0, inGuild = true, guildCanRepair = true,
            guildLimit = -1, guildMoney = 600 })
        openMerchant()
        T.same(state.repairs, { "guild" })
    end)

    it("splits the cost when the guild covers only part of it", function()
        local _, state = start(GUILD_REPAIR)
        repairState(state, { repairCost = 500, money = 1000, inGuild = true, guildCanRepair = true,
            guildLimit = 200, guildMoney = 10000 })
        openMerchant()
        T.same(state.repairs, { "guild" })
        T.eq(state.messages[1], "|cff33ff99Quality of Life|r: Repaired for 500c (guild bank 200c, you 300c).")
    end)

    it("pays alone while guild funds are off", function()
        local _, state = start(REPAIR)
        repairState(state, { repairCost = 500, money = 1000, inGuild = true, guildCanRepair = true,
            guildLimit = -1, guildMoney = 10000 })
        openMerchant()
        T.same(state.repairs, { "own" })
    end)

    it("says so when the gold isn't enough", function()
        local _, state = start(REPAIR)
        repairState(state, { repairCost = 500, money = 100 })
        openMerchant()
        T.same(state.repairs, {})
        T.eq(state.messages[1], "|cff33ff99Quality of Life|r: Not enough gold to repair (500c needed).")
    end)

    it("does nothing at a merchant who can't repair, or with nothing to repair", function()
        local _, state = start(REPAIR)
        state.repairCost = 500
        state.money = 1000
        openMerchant()
        repairState(state, { repairCost = 0 })
        openMerchant()
        T.same(state.repairs, {})
        T.eq(#state.messages, 0)
    end)

    it("is off until the player turns it on", function()
        local _, state = start()
        repairState(state, { repairCost = 500, money = 1000 })
        openMerchant()
        T.same(state.repairs, {})
    end)
end)
