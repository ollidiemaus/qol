local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local BOTH = { questAccept = true, questTurnIn = true }

local function start(savedOptions)
    Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return Stubs.state().quest
end

-- The calls the addon made since the last look.
local function calls(quest)
    local made = quest.calls
    quest.calls = {}
    return made
end

describe("quest automation", function()
    it("does nothing by default", function()
        local quest = start()
        quest.gossipActive = { { questID = 10, isComplete = true } }
        quest.gossipAvailable = { { questID = 20 } }
        Stubs.Fire("GOSSIP_SHOW")
        Stubs.Fire("QUEST_DETAIL", 0)
        Stubs.Fire("QUEST_PROGRESS")
        Stubs.Fire("QUEST_COMPLETE")
        T.same(calls(quest), {})
    end)

    it("accepts what an NPC offers, one quest after the other", function()
        local quest = start({ questAccept = true })
        quest.gossipAvailable = { { questID = 20 }, { questID = 21 } }
        Stubs.Fire("GOSSIP_SHOW")
        Stubs.Fire("QUEST_DETAIL", 0)
        T.same(calls(quest), { "gossipAvailable:20", "accept" })
        -- The NPC lists what's left.
        Stubs.Fire("QUEST_ACCEPTED", 20)
        quest.gossipAvailable = { { questID = 21 } }
        Stubs.Fire("GOSSIP_SHOW")
        T.same(calls(quest), { "gossipAvailable:21" })
    end)

    it("accepts a quest a group member shares", function()
        local quest = start({ questAccept = true })
        Stubs.Fire("QUEST_DETAIL", nil)
        T.same(calls(quest), { "accept" })
    end)

    it("leaves quests the game accepts itself and offers from items alone", function()
        local quest = start({ questAccept = true })
        Stubs.Fire("QUEST_DETAIL", 5678)
        quest.autoAccept = true
        Stubs.Fire("QUEST_DETAIL", 0)
        T.same(calls(quest), {})
    end)

    it("turns in finished quests before taking new ones", function()
        local quest = start(BOTH)
        quest.gossipActive = { { questID = 10, isComplete = false }, { questID = 11, isComplete = true } }
        quest.gossipAvailable = { { questID = 20 } }
        Stubs.Fire("GOSSIP_SHOW")
        Stubs.Fire("QUEST_PROGRESS")
        Stubs.Fire("QUEST_COMPLETE")
        T.same(calls(quest), { "gossipActive:11", "complete", "reward:0" })
    end)

    it("takes the only reward, and leaves a choice of rewards to the player", function()
        local quest = start({ questTurnIn = true })
        quest.choices = 1
        Stubs.Fire("QUEST_COMPLETE")
        T.same(calls(quest), { "reward:1" })
        quest.choices = 3
        Stubs.Fire("QUEST_COMPLETE")
        T.same(calls(quest), {})
    end)

    it("doesn't pay gold or turn in an unfinished quest", function()
        local quest = start({ questTurnIn = true })
        quest.money = 500
        Stubs.Fire("QUEST_PROGRESS")
        Stubs.Fire("QUEST_COMPLETE")
        quest.money = 0
        quest.completable = false
        Stubs.Fire("QUEST_PROGRESS")
        T.same(calls(quest), {})
    end)

    it("opens a quest it couldn't finish only once at the same NPC", function()
        local quest = start(BOTH)
        quest.gossipActive = { { questID = 11, isComplete = true } }
        quest.gossipAvailable = { { questID = 20 } }
        quest.choices = 2
        Stubs.Fire("GOSSIP_SHOW")
        Stubs.Fire("QUEST_COMPLETE")
        T.same(calls(quest), { "gossipActive:11" })
        -- Back at the NPC's list: the quest with the choice is left to the player, the offer is taken.
        Stubs.Fire("GOSSIP_SHOW")
        T.same(calls(quest), { "gossipAvailable:20" })
        Stubs.Fire("GOSSIP_SHOW")
        T.same(calls(quest), {})
        -- Another NPC starts afresh.
        quest.npc = "Creature-0-1-0-1-3140-0002"
        Stubs.Fire("GOSSIP_SHOW")
        T.same(calls(quest), { "gossipActive:11" })
    end)

    it("works with NPCs that greet with a list of quests", function()
        local quest = start(BOTH)
        quest.greetingActive = { { title = "A", isComplete = false, questID = 10 },
            { title = "B", isComplete = true, questID = 11 } }
        quest.greetingAvailable = { { questID = 20 }, { questID = 21 } }
        Stubs.Fire("QUEST_GREETING")
        T.same(calls(quest), { "greetingActive:2" })
        Stubs.Fire("QUEST_TURNED_IN", 11, 0, 0)
        quest.greetingActive = { { title = "A", isComplete = false, questID = 10 } }
        Stubs.Fire("QUEST_GREETING")
        T.same(calls(quest), { "greetingAvailable:1" })
    end)

    it("leaves everything to the player while Shift is held", function()
        local quest = start(BOTH)
        Stubs.state().shift = true
        quest.gossipActive = { { questID = 11, isComplete = true } }
        quest.gossipAvailable = { { questID = 20 } }
        Stubs.Fire("GOSSIP_SHOW")
        Stubs.Fire("QUEST_DETAIL", 0)
        Stubs.Fire("QUEST_PROGRESS")
        Stubs.Fire("QUEST_COMPLETE")
        T.same(calls(quest), {})
    end)

    it("treats a secret NPC as the one before", function()
        local quest = start({ questAccept = true })
        quest.gossipAvailable = { { questID = 20 } }
        Stubs.Fire("GOSSIP_SHOW")
        quest.npc = Stubs.SECRET
        Stubs.Fire("GOSSIP_SHOW")
        T.same(calls(quest), { "gossipAvailable:20" })
    end)
end)
