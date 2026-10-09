local _, ns = ...

-- Every change to a Blizzard frame goes through ns.Later. It runs the change from a fresh timer,
-- so our code never executes inside a call stack Blizzard started (with secret values, taint that
-- leaks into Blizzard code breaks unrelated frames). Changes asked for in combat wait until combat
-- ends: several of the frames we touch are protected, or anchor protected ones.
--
-- Calls are keyed: asking again for the same key before it ran replaces the earlier request, so a
-- burst of events or slider movements ends in one update.
local pending = {}
local afterCombat = {}
local scheduled = false

local function runPending()
    scheduled = false
    local batch = pending
    pending = {}
    for key, fn in pairs(batch) do
        if InCombatLockdown() then
            afterCombat[key] = fn
        else
            fn()
        end
    end
end

function ns.Later(key, fn)
    pending[key] = fn
    if not scheduled then
        scheduled = true
        C_Timer.After(0, runPending)
    end
end

ns.Events:On("PLAYER_REGEN_ENABLED", function()
    for key, fn in pairs(afterCombat) do
        afterCombat[key] = nil
        ns.Later(key, fn)
    end
end)
