local _, ns = ...

-- The game's group frames (raid-style party and raid frames), WoW Forever only. So far the Group
-- Frames page's game setting: whether the game shows its own buff icons on them. The raid manager is
-- hidden by Features/HideFrames.lua (hideRaidManager).
local GroupFrames = {}
ns.GroupFrames = GroupFrames

-- The game's "Display buffs" raid-frame setting (Blizzard_CompactUnitFrameProfiles turns it into the
-- frames' displayBuffs option whenever it changes). The game keeps it: QoL saves no copy and writes
-- it only when the player clicks its checkbox, never on its own.
GroupFrames.GAME_BUFFS_CVAR = "raidFramesDisplayBuffs"

-- Whether the client is WoW Forever, the only one the Group Frames page is for.
function GroupFrames.IsAvailable()
    return ns.IsForever()
end
