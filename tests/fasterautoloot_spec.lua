local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns, Stubs.state()
end

-- The game has the loot ready; autoLoot is whether it auto loots this time.
local function lootReady(state, slots, autoLoot)
    state.lootSlots = slots
    Stubs.Fire("LOOT_READY", autoLoot)
end

describe("faster auto loot", function()
    it("takes every slot at once, the last first, when the game auto loots", function()
        local _, state = start({ fasterAutoLoot = true })
        lootReady(state, 3, true)
        T.same(state.looted, { 3, 2, 1 })
    end)

    it("leaves the loot window alone when the game doesn't auto loot", function()
        local _, state = start({ fasterAutoLoot = true })
        lootReady(state, 3, false)
        T.same(state.looted, {})
    end)

    it("is off for a fresh install", function()
        local _, state = start()
        lootReady(state, 3, true)
        T.same(state.looted, {})
        T.eq(Stubs.Listens("LOOT_READY"), false)
    end)

    it("follows the option at once, without a reload", function()
        local ns, state = start()
        ns.Options:Set("fasterAutoLoot", true)
        lootReady(state, 2, true)
        T.same(state.looted, { 2, 1 })

        ns.Options:Set("fasterAutoLoot", false)
        Stubs.Wait(5)
        lootReady(state, 2, true)
        T.same(state.looted, { 2, 1 })
        T.eq(Stubs.Listens("LOOT_READY"), false)

        -- On again: taken once, not once for every time it was turned on.
        ns.Options:Set("fasterAutoLoot", true)
        Stubs.Wait(5)
        lootReady(state, 1, true)
        T.same(state.looted, { 2, 1, 1 })
    end)

    it("does nothing with an empty loot window", function()
        local _, state = start({ fasterAutoLoot = true })
        lootReady(state, 0, true)
        T.same(state.looted, {})
    end)

    it("takes the same loot once when the game says it's ready again", function()
        local _, state = start({ fasterAutoLoot = true })
        lootReady(state, 2, true)
        Stubs.Fire("LOOT_READY", true)
        T.same(state.looted, { 2, 1 })

        -- The next corpse's loot.
        Stubs.Wait(1)
        lootReady(state, 1, true)
        T.same(state.looted, { 2, 1, 1 })
    end)
end)
