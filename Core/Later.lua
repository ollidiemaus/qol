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
-- ns.LaterOutsideWindows also keeps away from the windows of the game that have the controller in
-- Forever's controller interface (ns.ControllerWindowOpen: the settings, the game menu, bags...).
-- Those windows drive the controller with key bindings and focus handling of their own, and the game
-- froze when the settings closed after the back buttons had been changed in them. In that interface
-- such a request runs only from a check made every half second, once a check found no window and the
-- one before it found none either: half a second at least after a window closed, so none of our code
-- runs while the game is still closing one, whatever order it does that in.
local WINDOW_CHECK_SECONDS = 0.5

-- One request per key, reused for every request for it: busy events ask again every frame.
-- key -> { fn = ..., inCombat = true or nil, outsideWindows = true or nil, released = true or nil }
local requests = {}
-- key -> its request, for the requests waiting for the next frame, for combat to end and for the
-- windows. A request waits in one of them at most.
local pending = {}
-- The requests of the frame being run; swapped with pending, so neither is made anew each frame.
local batch = {}
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

local function runPending()
    batch, pending = pending, batch
    for key, request in pairs(batch) do
        -- Taken out before it runs: when one raises an error, the others still run a frame later.
        batch[key] = nil
        -- Asked for again while the batch runs: that request replaced this one and waits for the
        -- next frame.
        if pending[key] == nil then
            local released = request.released
            request.released = nil
            if InCombatLockdown() and not request.inCombat then
                afterCombat[key] = request
            elseif request.outsideWindows and ns.IsControllerUI() and (not released or ns.ControllerWindowOpen()) then
                waitForWindows(key, request)
            else
                request.fn()
            end
        end
    end
end

driver:SetScript("OnUpdate", function(self)
    runPending()
    if next(pending) == nil then self:Hide() end
end)

-- Resets the key's request to a fresh one and queues it.
local function renew(key, fn, inCombat, outsideWindows)
    local record = requests[key]
    if not record then
        record = {}
        requests[key] = record
    end
    record.fn, record.inCombat, record.outsideWindows, record.released = fn, inCombat, outsideWindows, nil
    queue(key, record)
end

function ns.Later(key, fn, inCombat)
    renew(key, fn, inCombat or nil, nil)
end

-- Never in combat.
function ns.LaterOutsideWindows(key, fn)
    renew(key, fn, nil, true)
end

ns.Events:On("PLAYER_REGEN_ENABLED", function()
    for key, request in pairs(afterCombat) do
        queue(key, request)
    end
end)
