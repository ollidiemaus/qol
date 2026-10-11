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
--
-- In Forever's controller interface nothing runs while the game's settings or game menu are open
-- (ns.ControllerSettingsOpen): the game froze on closing the settings, with no error, each time a
-- feature had changed something while they were open (the back buttons, the buff tooltips). So a
-- change made from the settings applies once they're closed. ns.LaterOutsideWindows keeps away from
-- every window of the game that has the controller (ns.ControllerWindowOpen: also bags, the map...),
-- for the back buttons and the ring, which set key bindings: those windows drive the controller with
-- bindings and focus handling of their own. A request held back runs only from a check made every
-- half second, once a check found no window and the one before it found none either: half a second
-- at least after a window closed, so none of our code runs while the game is still closing one,
-- whatever order it does that in.
local WINDOW_CHECK_SECONDS = 0.5

-- key -> { fn = ..., inCombat = true or nil, outsideWindows = true or nil, released = true or nil }
local pending = {}
local afterCombat = {}
local afterWindows = {}
local checkingWindows = false
-- The last check found a window.
local windowSeen = false

-- Shown while requests wait. It has no parent, so it runs while the interface is hidden too.
local driver = CreateFrame("Frame")
driver:Hide()

-- A new request replaces any earlier one for its key, also one waiting for combat or windows.
local function queue(key, request)
    afterCombat[key], afterWindows[key] = nil, nil
    pending[key] = request
    driver:Show()
end

local function checkWindows()
    if ns.ControllerWindowOpen() then
        windowSeen = true
    elseif windowSeen then
        windowSeen = false
    else
        checkingWindows = false
        for key, request in pairs(afterWindows) do
            request.released = true
            queue(key, request)
        end
        return
    end
    C_Timer.After(WINDOW_CHECK_SECONDS, checkWindows)
end

local function waitForWindows(key, request)
    afterWindows[key] = request
    if not checkingWindows then
        checkingWindows = true
        C_Timer.After(WINDOW_CHECK_SECONDS, checkWindows)
    end
end

local function mustWait(request, released)
    if not ns.IsControllerUI() then return false end
    if request.outsideWindows then
        return not released or ns.ControllerWindowOpen()
    end
    return ns.ControllerSettingsOpen()
end

local function runPending()
    local batch = pending
    pending = {}
    for key, request in pairs(batch) do
        local released = request.released
        request.released = nil
        if InCombatLockdown() and not request.inCombat then
            afterCombat[key] = request
        elseif mustWait(request, released) then
            waitForWindows(key, request)
        else
            request.fn()
        end
    end
end

driver:SetScript("OnUpdate", function(self)
    runPending()
    if next(pending) == nil then self:Hide() end
end)

function ns.Later(key, fn, inCombat)
    queue(key, { fn = fn, inCombat = inCombat or nil })
end

-- Never in combat.
function ns.LaterOutsideWindows(key, fn)
    queue(key, { fn = fn, outsideWindows = true })
end

ns.Events:On("PLAYER_REGEN_ENABLED", function()
    for key, request in pairs(afterCombat) do
        queue(key, request)
    end
end)
