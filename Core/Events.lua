local _, ns = ...

-- One frame for every game event the addon listens to. Handlers get (event, ...).
local Events = { handlers = {} }
ns.Events = Events

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(_, event, ...)
    local handlers = Events.handlers[event]
    if not handlers then return end
    for i = 1, #handlers do
        handlers[i](event, ...)
    end
end)

-- Registering an event the client doesn't know is an error on modern clients, and Forever and
-- retail don't share every event.
local function isKnown(event)
    return not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event)
end

-- Returns false for an event this client doesn't know.
function Events:On(event, handler)
    local handlers = self.handlers[event]
    if not handlers then
        if not isKnown(event) then return false end
        handlers = {}
        self.handlers[event] = handlers
        frame:RegisterEvent(event)
    end
    handlers[#handlers + 1] = handler
    return true
end

-- Removes a handler On added, and unregisters the event once none is left. The event's handlers
-- get a new list, so an event running right now (a handler turning itself off) skips none of them.
function Events:Off(event, handler)
    local handlers = self.handlers[event]
    if not handlers then return end
    local kept = {}
    for i = 1, #handlers do
        if handlers[i] ~= handler then kept[#kept + 1] = handlers[i] end
    end
    if #kept > 0 then
        self.handlers[event] = kept
    else
        self.handlers[event] = nil
        frame:UnregisterEvent(event)
    end
end

-- A unit listener hears events about one or two units, so the game drops other units' events
-- before QoL wakes. Each listener has a frame of its own: registering an event again on one frame
-- replaces its units. Make one once, at Init, and turn its events on and off as things show.
local UnitListener = {}
UnitListener.__index = UnitListener

function Events:NewUnitListener(unit1, unit2)
    local listener = setmetatable({ unit1 = unit1, unit2 = unit2, handlers = {} }, UnitListener)
    listener.frame = CreateFrame("Frame")
    listener.frame:SetScript("OnEvent", function(_, event, ...)
        local handler = listener.handlers[event]
        if handler then handler(event, ...) end
    end)
    return listener
end

-- One handler per event: a second On replaces the first. Returns false for an event this client
-- doesn't know, like Events:On.
function UnitListener:On(event, handler)
    if not self.handlers[event] then
        if not isKnown(event) then return false end
        -- The API's units aren't nilable: a trailing nil may be rejected.
        if self.unit2 then
            self.frame:RegisterUnitEvent(event, self.unit1, self.unit2)
        else
            self.frame:RegisterUnitEvent(event, self.unit1)
        end
    end
    self.handlers[event] = handler
    return true
end

function UnitListener:Off(event)
    if not self.handlers[event] then return end
    self.handlers[event] = nil
    self.frame:UnregisterEvent(event)
end
