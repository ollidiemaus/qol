local _, ns = ...
local Options = ns.Options

-- Takes all of the loot at once when the game auto loots, instead of one item after another (on
-- Forever each item slides out of the loot window first). Whether it auto loots is the game's call,
-- and LOOT_READY says what it decided: its setting, the auto loot key, or a controller's tap or hold
-- on Forever (which comparing the setting with the key would miss). What can't be taken (full bags,
-- a bind confirmation, a roll) the game leaves in the loot window. Only loot API calls, no frames.
local FasterAutoLoot = {}
ns.FasterAutoLoot = FasterAutoLoot

local KEY = "fasterAutoLoot"

-- The game can say the same loot is ready more than once. As in Leatrix Plus, loot is taken at most
-- once in THROTTLE seconds.
local THROTTLE = 0.3
local takenAt -- GetTime() when loot was last taken

local function takeAll(_, autoLoot)
    if not autoLoot then return end
    local count = GetNumLootItems()
    if count == 0 then return end
    local now = GetTime()
    if takenAt and now - takenAt < THROTTLE then return end
    takenAt = now
    for slot = count, 1, -1 do
        LootSlot(slot)
    end
end

-- Whether LOOT_READY reaches takeAll: only while the option is on.
local listening = false

local function apply()
    local on = Options:Get(KEY) == true
    if on == listening then return end
    listening = on
    if on then
        ns.Events:On("LOOT_READY", takeAll)
    else
        ns.Events:Off("LOOT_READY", takeAll)
    end
end

function FasterAutoLoot:Init()
    Options:Watch({ KEY }, apply)
    apply()
end
