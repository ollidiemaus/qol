local _, ns = ...

-- Every change to a Blizzard frame goes through ns.Later. It runs the change from a fresh timer,
-- so our code never executes inside a call stack Blizzard started (with secret values, taint that
-- leaks into Blizzard code breaks unrelated frames). Changes asked for in combat wait until combat
-- ends: several of the frames we touch are protected, or anchor protected ones. A change the game
-- allows in combat (a color, for one) passes inCombat and runs right away in combat too.
--
-- Calls are keyed: asking again for the same key before it ran replaces the earlier request, so a
-- burst of events or slider movements ends in one update.
local pending = {}
local runsInCombat = {}
local afterCombat = {}
local scheduled = false

local function runPending()
    scheduled = false
    local batch, inCombat = pending, runsInCombat
    pending, runsInCombat = {}, {}
    for key, fn in pairs(batch) do
        if InCombatLockdown() and not inCombat[key] then
            afterCombat[key] = fn
        else
            fn()
        end
    end
end

function ns.Later(key, fn, inCombat)
    pending[key] = fn
    runsInCombat[key] = inCombat or nil
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
