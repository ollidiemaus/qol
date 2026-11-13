local _, ns = ...

-- Buffs that count as having another one, shared by the reminders and the tracked buffs' "lacks it"
-- kind. Spell IDs are Forever's (its Spell table); the names come from the client, so any locale works.

-- Group versions: a single-target spell (any of its ranks) and the group spells whose buff counts for
-- it too. Forever has Greater Blessings of Might, Wisdom and Kings only.
local GROUP_VERSIONS = {
    [1126] = { 21849 },  -- Mark of the Wild: Gift of the Wild
    [1459] = { 23028 },  -- Arcane Intellect: Arcane Brilliance
    [1243] = { 21562 },  -- Power Word: Fortitude: Prayer of Fortitude
    [14752] = { 27681 }, -- Divine Spirit: Prayer of Spirit
    [976] = { 27683 },   -- Shadow Protection: Prayer of Shadow Protection
    [19740] = { 25782 }, -- Blessing of Might: Greater Blessing of Might
    [19742] = { 25894 }, -- Blessing of Wisdom: Greater Blessing of Wisdom
    [20217] = { 25898 }, -- Blessing of Kings: Greater Blessing of Kings
}

-- Rival buffs: two different buffs the game won't keep on one character together ("A more powerful
-- spell is already active"). Having either counts as having the other, whichever is stronger. The
-- stacking rules are the server's, not in the client's tables, so the pairs are written by hand (see
-- docs/dev/bars-and-frames.md, Reminders). Each side is a list of spell IDs, for ranks that go by different names.
local RIVALS = {
    -- Thorns: Fire Shield, the imp's (its ranks share the name) and Forever's ally spell, I to IV.
    { { 467 }, { 2947, 134, 184, 2601, 2602 } },
    { { 1008 }, { 604 } },  -- Amplify Magic: Dampen Magic
    { { 1243 }, { 8099 } }, -- Power Word: Fortitude: Scroll of Stamina's "Stamina"
    { { 1459 }, { 8096 } }, -- Arcane Intellect: Scroll of Intellect's "Intellect"
    { { 14752 }, { 8112 } }, -- Divine Spirit: Scroll of Spirit's "Spirit"
}

-- A buff's name -> the other names that count as having it, and whether the client gave every one.
-- Kept either way: an incomplete map is built again only after ns.RetryCountingNames.
local countingNames, countingComplete

-- The client's names for the spell IDs it has given, and whether it gave every one.
local function spellNames(ids)
    local names, complete = {}, true
    for _, id in ipairs(ids) do
        local name = C_Spell.GetSpellName(id)
        if ns.IsUsable(name) then names[#names + 1] = name else complete = false end
    end
    return names, complete
end

-- Adds to map[name] each of others not yet there.
local function add(map, name, others)
    local list = map[name] or {}
    map[name] = list
    for _, other in ipairs(others) do
        local seen = other == name
        for _, known in ipairs(list) do
            if known == other then seen = true end
        end
        if not seen then list[#list + 1] = other end
    end
end

-- The names by the buffs' names (any rank and locale goes by the same name): a single spell's group
-- versions, and each rival pair both ways. A group version doesn't get its single spell's rivals. Also
-- whether the map is complete (the client gave every name).
function ns.CountingNames()
    if countingNames then return countingNames, countingComplete end
    local map, complete = {}, true
    -- Adds others to each of names, noting a side the client hasn't fully named yet.
    local function link(names, namesComplete, others, othersComplete)
        complete = complete and namesComplete and othersComplete
        for _, name in ipairs(names) do add(map, name, others) end
    end
    for single, groups in pairs(GROUP_VERSIONS) do
        local names, namesComplete = spellNames({ single })
        local groupNames, groupsComplete = spellNames(groups)
        link(names, namesComplete, groupNames, groupsComplete)
    end
    for _, pair in ipairs(RIVALS) do
        local left, leftComplete = spellNames(pair[1])
        local right, rightComplete = spellNames(pair[2])
        link(left, leftComplete, right, rightComplete)
        link(right, rightComplete, left, leftComplete)
    end
    countingNames, countingComplete = map, complete
    return map, complete
end

-- Lets an incomplete map be built again, once the client may have loaded the missing names.
function ns.RetryCountingNames()
    if not countingComplete then countingNames = nil end
end
