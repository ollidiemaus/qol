local _, ns = ...

-- Group versions of buffs, shared by the reminders and the tracked buffs' "lacks it" kind: a
-- single-target spell (any of its ranks) and the group spells whose buff counts for it too, in
-- Forever's Spell table. Forever has Greater Blessings of Might, Wisdom and Kings only.
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

-- A spell's name -> the names of its group versions, kept once the client has given every one.
local groupNames

-- The names by the single-target spells' names (any rank and locale goes by the same name), and
-- whether the map is complete (the client gave every name): an incomplete one is asked again later.
function ns.GroupVersionNames()
    if groupNames then return groupNames, true end
    local map, complete = {}, true
    for single, groups in pairs(GROUP_VERSIONS) do
        local name = C_Spell.GetSpellName(single)
        if not ns.IsUsable(name) then name = nil end
        for _, group in ipairs(groups) do
            local groupName = C_Spell.GetSpellName(group)
            if name and ns.IsUsable(groupName) then
                map[name] = map[name] or {}
                map[name][#map[name] + 1] = groupName
            else
                complete = false
            end
        end
    end
    if complete then groupNames = map end
    return map, complete
end
