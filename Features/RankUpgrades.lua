local _, ns = ...
local Options = ns.Options

-- Rank upgrades, on Forever, where a spell on an action bar is a fixed rank of it. Learning a rank
-- moves the slots holding the previous highest rank to the new one; lower ranks stay, so a downrank
-- is recognised by this rule and nothing is saved per slot. UpgradeAll moves every spell on the
-- bars to its highest rank, downranks included, once per call and whatever the option says.
--
-- Slots only change through the game's API, out of combat and, in the controller interface, away
-- from the game's windows (ns.LaterOutsideWindows), and only with an empty cursor, as placing a spell
-- would take what the player holds.
local RankUpgrades = {}
ns.RankUpgrades = RankUpgrades

local KEY = "upgradeSpellRanks"
-- A spell's subtext is missing until the game has loaded its data, and without it a rank would go
-- unnoticed. This often and this far apart a run waits for what it asked to load, then goes on.
local LOAD_WAITS, LOAD_WAIT_SECONDS = 5, 1

-- The spells learned since the last upgrade: spell ID -> true.
local learned = {}
-- UpgradeAll was called and is waiting.
local upgradeAllAsked = false
-- How often this run waited for spell data.
local loadWaits = 0

-- The number in a spell's subtext ("Rank 3", "Rang 3"), nil for a spell without ranks.
local function rankOf(id)
    local subtext = C_Spell.GetSpellSubtext(id)
    if type(subtext) ~= "string" or not ns.IsUsable(subtext) then return nil end
    return tonumber(subtext:match("%d+"))
end

-- The ranks the character knows, by the spell's name: name -> { spell ID -> rank }. A name match
-- counts only here in the spell book, as NPC spells can share a name. The book lists every rank:
-- "Show all spell ranks" only filters what its window shows. What was just learned counts even if
-- the book doesn't have it yet. Also returns whether some spell's data had to be asked for.
local function knownRanks()
    local ranks, unloaded = {}, false
    local function add(id)
        if not C_Spell.IsSpellDataCached(id) then
            C_Spell.RequestLoadSpellData(id)
            unloaded = true
        end
        local rank, name = rankOf(id), C_Spell.GetSpellName(id)
        if rank and ns.IsUsable(name) then
            ranks[name] = ranks[name] or {}
            ranks[name][id] = rank
        end
    end
    local book, bank = C_SpellBook, Enum.SpellBookSpellBank.Player
    for line = 1, book.GetNumSpellBookSkillLines() do
        local info = book.GetSpellBookSkillLineInfo(line)
        if info and not info.shouldHide then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = book.GetSpellBookItemInfo(slot, bank)
                if item and item.itemType == Enum.SpellBookItemType.Spell and not item.isOffSpec then
                    add(item.actionID)
                end
            end
        end
    end
    for id in pairs(learned) do add(id) end
    return ranks, unloaded
end

-- The spell ID of the highest of a spell's ranks, leaving out those in skip.
local function highestSpell(ranks, skip)
    local best, bestRank
    for id, rank in pairs(ranks) do
        if not (skip and skip[id]) and (not bestRank or rank > bestRank) then best, bestRank = id, rank end
    end
    return best
end

-- FindSpellActionButtons also finds macros casting the spell: only a slot holding the spell itself
-- changes. The old spell lands on the cursor and is dropped.
local function replace(from, to)
    for _, slot in ipairs(C_ActionBar.FindSpellActionButtons(from) or {}) do
        local kind, id = GetActionInfo(slot)
        if ns.IsUsable(id) and kind == "spell" and id == from then
            C_Spell.PickupSpell(to)
            PlaceAction(slot)
            ClearCursor()
        end
    end
end

-- A spell's rank upgrade on learning: the slots on what was its highest rank before the ranks just
-- learned go to the highest of those. A lower rank learned late changes nothing.
local function upgradeLearned(ranks)
    local newest, previous = highestSpell(ranks), highestSpell(ranks, learned)
    if learned[newest] and previous then replace(previous, newest) end
end

local function upgradeEveryRank(ranks)
    local highest = highestSpell(ranks)
    for id in pairs(ranks) do
        if id ~= highest then replace(id, highest) end
    end
end

local upgrade

local function schedule()
    ns.LaterOutsideWindows("rankUpgrades", upgrade)
end

local function cursorChanged()
    ns.Events:Off("CURSOR_CHANGED", cursorChanged)
    schedule()
end

upgrade = function()
    if GetCursorInfo() then
        -- Off first: more requests can meet the same full cursor.
        ns.Events:Off("CURSOR_CHANGED", cursorChanged)
        ns.Events:On("CURSOR_CHANGED", cursorChanged)
        return
    end
    local known, unloaded = knownRanks()
    if unloaded and loadWaits < LOAD_WAITS then
        loadWaits = loadWaits + 1
        C_Timer.After(LOAD_WAIT_SECONDS, schedule)
        return
    end
    for _, ranks in pairs(known) do
        if upgradeAllAsked then
            upgradeEveryRank(ranks)
        elseif Options:Get(KEY) then
            upgradeLearned(ranks)
        end
    end
    learned, upgradeAllAsked, loadWaits = {}, false, 0
end

local function learnedSpell(_, id)
    if not (Options:Get(KEY) and ns.IsUsable(id)) then return end
    learned[id] = true
    schedule()
end

-- Forever only: retail has no ranks, and Classic Era has neither this nor the spell book API here.
function RankUpgrades.IsAvailable()
    return C_ActionBar ~= nil and C_ActionBar.IsHighestSpellRank ~= nil
end

function RankUpgrades.UpgradeAll()
    if not RankUpgrades.IsAvailable() then return end
    upgradeAllAsked = true
    schedule()
end

function RankUpgrades:Init()
    if RankUpgrades.IsAvailable() then ns.Events:On("LEARNED_SPELL_IN_SKILL_LINE", learnedSpell) end
end
