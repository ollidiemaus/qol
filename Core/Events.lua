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

-- Returns false for an event this client doesn't know: registering one is an error on modern
-- clients, and Forever and retail don't share every event.
function Events:On(event, handler)
    local handlers = self.handlers[event]
    if not handlers then
        if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
            return false
        end
        handlers = {}
        self.handlers[event] = handlers
        frame:RegisterEvent(event)
    end
    handlers[#handlers + 1] = handler
    return true
end
