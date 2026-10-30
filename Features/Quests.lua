local _, ns = ...
local Options = ns.Options

-- Accepts quests and turns them in when talking to quest givers. Holding Shift while talking to an
-- NPC leaves the whole conversation to the player.
--   * Accepting: every quest an NPC offers (in the gossip window or the old quest greeting) and
--     every quest a group member shares. Quests the game accepts by itself, and the offers it moves
--     to the quest tracker (quests started by an item), are left alone.
--   * Turning in: every finished quest, as long as there's no reward to choose and no gold to
--     pay. Then the reward (or progress) page stays open for the player.
-- These are plain API calls, like the merchant's, made from our own event handlers.
local Quests = {}
ns.Quests = Quests

local ACCEPT, TURN_IN = "questAccept", "questTurnIn"

-- Quests we opened from an NPC's list ourselves, by quest ID (by title in Classic Era's greeting,
-- which has no quest IDs). Each is opened once per NPC: one we couldn't finish (a reward to choose,
-- gold to pay, a full quest log) would otherwise open again every time the NPC's list shows.
-- Accepting or turning a quest in takes it off the list.
local opened = {}
local openedAt -- the NPC they were opened at

local function paused()
    return IsShiftKeyDown and IsShiftKeyDown() or false
end

local function on(key)
    return Options:Get(key) and not paused()
end

-- Starts a new list of opened quests when the player talks to another NPC. An NPC the game keeps
-- secret counts as the same one, so nothing opens twice.
local function rememberNpc()
    local guid = UnitGUID and UnitGUID("npc")
    if not ns.IsUsable(guid) then return end
    if guid ~= openedAt then
        opened = {}
        openedAt = guid
    end
end

local function usableID(questID)
    return ns.IsUsable(questID) and type(questID) == "number" and questID > 0
end

local function usableIDOrTitle(key)
    return usableID(key) or (ns.IsUsable(key) and type(key) == "string" and key ~= "")
end

-- Opens the quest with choose() unless we did before at this NPC. Returns whether it did.
local function open(key, choose)
    if not usableIDOrTitle(key) or opened[key] then return false end
    opened[key] = true
    choose()
    return true
end

-- An NPC with gossip lists its finished quests (active ones) and the quests it offers (available
-- ones). Finished quests go first: turning one in can make the NPC offer the next.
function Quests:OnGossipShow()
    local gossip = C_GossipInfo
    if not gossip then return end
    rememberNpc()
    if on(TURN_IN) then
        for _, quest in ipairs(gossip.GetActiveQuests() or {}) do
            if quest.isComplete and open(quest.questID, function() gossip.SelectActiveQuest(quest.questID) end) then
                return
            end
        end
    end
    if on(ACCEPT) then
        for _, quest in ipairs(gossip.GetAvailableQuests() or {}) do
            if open(quest.questID, function() gossip.SelectAvailableQuest(quest.questID) end) then
                return
            end
        end
    end
end

-- The same for NPCs that greet with a plain list of quests, addressed by their place in it. Classic
-- Era's has no quest IDs (no GetActiveQuestID, and GetAvailableQuestInfo stops before the ID), so
-- there a quest is known by its title.
local function byTitle()
    return not GetActiveQuestID
end

function Quests:OnQuestGreeting()
    rememberNpc()
    if on(TURN_IN) then
        for i = 1, GetNumActiveQuests() do
            local title, isComplete = GetActiveTitle(i)
            local key = byTitle() and title or GetActiveQuestID(i)
            if isComplete and open(key, function() SelectActiveQuest(i) end) then
                return
            end
        end
    end
    if on(ACCEPT) then
        for i = 1, GetNumAvailableQuests() do
            local key = byTitle() and GetAvailableTitle(i) or select(5, GetAvailableQuestInfo(i))
            if open(key, function() SelectAvailableQuest(i) end) then
                return
            end
        end
    end
end

-- questStartItemID is set for a quest an item started: the game moves that offer to the quest
-- tracker and closes the window.
function Quests:OnQuestDetail(questStartItemID)
    if not on(ACCEPT) then return end
    if ns.IsUsable(questStartItemID) and questStartItemID and questStartItemID ~= 0 then return end
    if QuestGetAutoAccept and QuestGetAutoAccept() then return end
    if QuestIsFromAdventureMap and QuestIsFromAdventureMap() then return end
    AcceptQuest()
end

local function costsGold()
    local money = GetQuestMoneyToGet()
    return ns.IsUsable(money) and type(money) == "number" and money > 0
end

-- The page that lists what the quest still needs.
function Quests:OnQuestProgress()
    if not on(TURN_IN) then return end
    if IsQuestCompletable() and not costsGold() then
        CompleteQuest()
    end
end

-- The reward page. With one reward there's nothing to choose: it is the one the game gives.
function Quests:OnQuestComplete()
    if not on(TURN_IN) then return end
    local choices = GetNumQuestChoices()
    if not ns.IsUsable(choices) or choices > 1 or costsGold() then return end
    GetQuestReward(choices)
end

-- The quest's title, for a client whose greeting knows quests by their title. Nil where the
-- client can't say.
local function titleOf(questID)
    local log = C_QuestLog
    local getTitle = log and log.GetQuestInfo
    return getTitle and getTitle(questID)
end

local function forget(questID)
    if not usableID(questID) then return end
    opened[questID] = nil
    if not byTitle() then return end
    local title = titleOf(questID)
    if usableIDOrTitle(title) then opened[title] = nil end
end

function Quests:Init()
    local events = {
        GOSSIP_SHOW = function() Quests:OnGossipShow() end,
        QUEST_GREETING = function() Quests:OnQuestGreeting() end,
        QUEST_DETAIL = function(_, questStartItemID) Quests:OnQuestDetail(questStartItemID) end,
        QUEST_PROGRESS = function() Quests:OnQuestProgress() end,
        QUEST_COMPLETE = function() Quests:OnQuestComplete() end,
        -- Classic Era's QUEST_ACCEPTED carries the quest log index first, then the quest ID.
        QUEST_ACCEPTED = function(_, first, second) forget(second or first) end,
        QUEST_TURNED_IN = function(_, questID) forget(questID) end,
    }
    for event, handler in pairs(events) do
        ns.Events:On(event, handler)
    end
end
