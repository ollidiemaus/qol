local _, ns = ...

-- Every change to a Blizzard frame goes through ns.Later. It runs the change from the OnUpdate of a
-- frame of ours, so our code never executes inside a call stack Blizzard started (with secret
-- values, taint that leaks into Blizzard code breaks unrelated frames). Changes asked for in combat
-- wait until combat ends: several of the frames we touch are protected, or anchor protected ones. A
-- change the game allows in combat (a color, for one) passes inCombat and runs right away in combat
-- too.
--
-- Calls are keyed: asking again for the same key before it ran replaces the earlier request, so a
-- burst of events or slider movements ends in one update. Requests run at most once per drawn
-- frame, and one made while they run waits for the next frame: when a change makes the game fire
-- an event that asks for it again, the game goes on drawing frames instead of hanging. That holds
-- whatever the game does with a timer started from a timer, which is why this isn't C_Timer.After(0).
local pending = {}
local runsInCombat = {}
local afterCombat = {}

local function runPending()
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

-- Shown while requests wait. It has no parent, so it runs while the interface is hidden too.
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self)
    runPending()
    if next(pending) == nil then self:Hide() end
end)

function ns.Later(key, fn, inCombat)
    pending[key] = fn
    runsInCombat[key] = inCombat or nil
    driver:Show()
end

ns.Events:On("PLAYER_REGEN_ENABLED", function()
    for key, fn in pairs(afterCombat) do
        afterCombat[key] = nil
        ns.Later(key, fn)
    end
end)
