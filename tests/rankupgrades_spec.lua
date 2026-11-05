local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Frostbolt's ranks and a spell without ranks, by spell ID.
local RANK_1, RANK_2, RANK_3, RANK_4, RANK_5 = 116, 205, 837, 7322, 8406
local BLINK = 1953

local function give(state, id, rank)
    state.spells[id] = { name = "Frostbolt", subtext = "Rank " .. rank }
end

-- Forever, knowing ranks 1 to 3 of Frostbolt and Blink. setup(state) runs before login.
local function start(savedOptions, setup, client)
    local ns = Stubs.LoadAddon({ client = client })
    local state = Stubs.state()
    give(state, RANK_1, 1)
    give(state, RANK_2, 2)
    give(state, RANK_3, 3)
    state.spells[BLINK] = { name = "Blink", subtext = "" }
    if setup then setup(state) end
    Stubs.Login(savedOptions)
    return ns
end

local ON = { upgradeSpellRanks = true }

-- The character learns a rank of Frostbolt, as a trainer teaches it.
local function learn(id, rank)
    give(Stubs.state(), id, rank)
    Stubs.Fire("LEARNED_SPELL_IN_SKILL_LINE", id, 2, false)
    Stubs.RunTimers()
end

-- The spell ID in each of the slots.
local function bars(...)
    local result = {}
    for _, slot in ipairs({ ... }) do
        local action = Stubs.state().actions[slot]
        result[#result + 1] = action and action.spell or false
    end
    return result
end

local function put(slots)
    return function(state)
        for slot, id in pairs(slots) do state.actions[slot] = { spell = id } end
    end
end

describe("rank upgrades", function()
    it("move every slot on the highest rank to a newly learned rank", function()
        start(ON, put({ [1] = RANK_3, [62] = RANK_3 }))
        learn(RANK_4, 4)
        T.same(bars(1, 62), { RANK_4, RANK_4 })
        T.eq(GetCursorInfo(), nil, "the old rank isn't left on the cursor")
    end)

    it("reach the controller bars' storage slots", function()
        start(ON, put({ [300] = RANK_3 }))
        learn(RANK_4, 4)
        T.same(bars(300), { RANK_4 })
    end)

    it("change nothing with the option off, the default", function()
        start(nil, put({ [1] = RANK_3 }))
        learn(RANK_4, 4)
        T.same(bars(1), { RANK_3 })
    end)

    it("leave a downrank alone", function()
        start(ON, put({ [1] = RANK_3, [2] = RANK_1 }))
        learn(RANK_4, 4)
        T.same(bars(1, 2), { RANK_4, RANK_1 })
    end)

    it("bring a slot up through ranks learned together, whichever comes first", function()
        start(ON, put({ [1] = RANK_3, [2] = RANK_2 }))
        give(Stubs.state(), RANK_5, 5)
        give(Stubs.state(), RANK_4, 4)
        Stubs.Fire("LEARNED_SPELL_IN_SKILL_LINE", RANK_5, 2, false)
        Stubs.Fire("LEARNED_SPELL_IN_SKILL_LINE", RANK_4, 2, false)
        Stubs.RunTimers()
        T.same(bars(1, 2), { RANK_5, RANK_2 })
    end)

    it("keep a rank dragged back through later ranks", function()
        start(ON, put({ [1] = RANK_3 }))
        learn(RANK_4, 4)
        Stubs.state().actions[1] = { spell = RANK_3 }
        learn(RANK_5, 5)
        T.same(bars(1), { RANK_3 })
    end)

    it("do nothing when a lower rank is learned after a higher one", function()
        start(ON, put({ [1] = RANK_3 }))
        learn(RANK_2, 2)
        T.same(bars(1), { RANK_3 })
    end)

    it("do nothing for a first rank or a spell without ranks", function()
        start(ON, put({ [1] = BLINK }))
        Stubs.state().spells[9999] = { name = "Ice Lance", subtext = "Rank 1" }
        Stubs.Fire("LEARNED_SPELL_IN_SKILL_LINE", 9999, 2, false)
        Stubs.Fire("LEARNED_SPELL_IN_SKILL_LINE", BLINK, 2, false)
        Stubs.RunTimers()
        T.same(bars(1), { BLINK })
    end)

    it("don't count a spell of the same name outside the spell book", function()
        start(ON, function(state)
            put({ [1] = RANK_3, [2] = 50000 })(state)
            state.spellBook = { { id = RANK_1 }, { id = RANK_2 }, { id = RANK_3 } }
            state.spells[50000] = { name = "Frostbolt", subtext = "Rank 9" }
        end)
        learn(RANK_4, 4)
        T.same(bars(1, 2), { RANK_4, 50000 })
    end)

    it("don't move to a rank the spell book only lists as still to learn", function()
        start(ON, function(state)
            put({ [1] = RANK_3 })(state)
            give(state, RANK_5, 5)
            state.spellBook = { { id = RANK_2 }, { id = RANK_3 }, { id = RANK_5, future = true } }
        end)
        learn(RANK_4, 4)
        T.same(bars(1), { RANK_4 })
    end)

    it("wait for a spell's data when the game hasn't loaded it yet", function()
        start(ON, put({ [1] = RANK_3 }))
        Stubs.state().spells[RANK_3].unloaded = true
        learn(RANK_4, 4)
        T.same(bars(1), { RANK_3 })
        Stubs.AdvanceTime()
        T.same(bars(1), { RANK_4 })
    end)

    it("go on without a spell whose data never loads", function()
        start(ON, put({ [1] = RANK_3 }))
        Stubs.state().spells[BLINK].unloaded, Stubs.state().spells[BLINK].neverLoads = true, true
        learn(RANK_4, 4)
        for _ = 1, 5 do Stubs.AdvanceTime() end
        T.same(bars(1), { RANK_4 })
    end)

    it("leave a macro casting the spell alone", function()
        start(ON, function(state) state.actions[1] = { macro = 3, casts = RANK_3 } end)
        learn(RANK_4, 4)
        T.eq(Stubs.state().actions[1].macro, 3)
    end)

    it("wait for combat to end", function()
        start(ON, put({ [1] = RANK_3 }))
        Stubs.SetCombat(true)
        learn(RANK_4, 4)
        T.same(bars(1), { RANK_3 })
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.same(bars(1), { RANK_4 })
    end)

    it("wait for an empty cursor, keeping what it holds and what's still to do", function()
        start(ON, put({ [1] = RANK_3 }))
        Stubs.state().cursorInfo = { "item", 6948 }
        learn(RANK_4, 4)
        learn(RANK_5, 5)
        T.same(bars(1), { RANK_3 })
        T.eq(GetCursorInfo(), "item", "what the player holds stays on the cursor")
        ClearCursor()
        Stubs.Fire("CURSOR_CHANGED")
        Stubs.RunTimers()
        T.same(bars(1), { RANK_5 })
    end)

    it("wait for the game's windows to close in the controller interface", function()
        start(ON, put({ [1] = RANK_3 }))
        Stubs.SetControllerUI(true)
        local window = CreateFrame("Frame", nil, UIParent)
        window:Show()
        Stubs.SetControllerWindow(window)
        learn(RANK_4, 4)
        Stubs.AdvanceTime()
        Stubs.AdvanceTime()
        T.same(bars(1), { RANK_3 })
        Stubs.SetControllerWindow(nil)
        Stubs.AdvanceTime()
        Stubs.AdvanceTime()
        Stubs.RunTimers()
        T.same(bars(1), { RANK_4 })
    end)

    it("don't run when the option goes off while they wait", function()
        local ns = start(ON, put({ [1] = RANK_3 }))
        Stubs.SetCombat(true)
        learn(RANK_4, 4)
        ns.Options:Set("upgradeSpellRanks", false)
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.same(bars(1), { RANK_3 })
    end)
end)

describe("upgrading all spells", function()
    it("moves every rank to the highest, downranks included, with the option off too", function()
        local ns = start(nil, put({ [1] = RANK_1, [2] = RANK_2, [3] = RANK_3, [4] = BLINK }))
        ns.RankUpgrades.UpgradeAll()
        Stubs.RunTimers()
        T.same(bars(1, 2, 3, 4), { RANK_3, RANK_3, RANK_3, BLINK })
        T.eq(GetCursorInfo(), nil)
    end)

    it("works with the option on, once per click", function()
        local ns = start(ON, put({ [1] = RANK_1 }))
        ns.RankUpgrades.UpgradeAll()
        Stubs.RunTimers()
        T.same(bars(1), { RANK_3 })
        Stubs.state().actions[1] = { spell = RANK_1 }
        Stubs.state().actions[2] = { spell = RANK_2 }
        learn(RANK_4, 4)
        T.same(bars(1, 2), { RANK_1, RANK_2 }, "learning doesn't repeat the click")
    end)

    it("runs after combat when clicked in combat", function()
        local ns = start(nil, put({ [1] = RANK_1 }))
        Stubs.SetCombat(true)
        ns.RankUpgrades.UpgradeAll()
        Stubs.RunTimers()
        T.same(bars(1), { RANK_1 })
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.same(bars(1), { RANK_3 })
    end)

    it("waits for an empty cursor", function()
        local ns = start(nil, put({ [1] = RANK_1 }))
        Stubs.state().cursorInfo = { "item", 6948 }
        ns.RankUpgrades.UpgradeAll()
        Stubs.RunTimers()
        T.same(bars(1), { RANK_1 })
        ClearCursor()
        Stubs.Fire("CURSOR_CHANGED")
        Stubs.RunTimers()
        T.same(bars(1), { RANK_3 })
    end)

    it("leaves a macro alone", function()
        local ns = start(nil, function(state) state.actions[1] = { macro = 3, casts = RANK_1 } end)
        ns.RankUpgrades.UpgradeAll()
        Stubs.RunTimers()
        T.eq(Stubs.state().actions[1].macro, 3)
    end)
end)

for _, client in ipairs({ "retail", "classicEra" }) do
    describe("rank upgrades on " .. client, function()
        it("stay inactive", function()
            local ns = start(ON, put({ [1] = RANK_3 }), client)
            T.falsy(ns.RankUpgrades.IsAvailable())
            learn(RANK_4, 4)
            ns.RankUpgrades.UpgradeAll()
            Stubs.RunTimers()
            T.same(bars(1), { RANK_3 })
        end)
    end)
end
