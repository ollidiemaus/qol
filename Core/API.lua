local _, ns = ...
local Options = ns.Options

-- A small public surface for other addons (AutoSetup switches features per resolution with it).
-- Features are addressed by a short name, not by their option key, so the saved variables stay free
-- to change. Setting goes through Options:Set, so the feature reacts at once, exactly as if the
-- player had used the settings page.
local API = {}
ns.API = API

local FEATURES = {
    viewport = "viewportEnabled",
}

-- Feature names are matched case-insensitively.
local function optionKey(feature)
    return type(feature) == "string" and FEATURES[feature:lower()] or nil
end

function API.GetFeatureNames()
    local names = {}
    for name in pairs(FEATURES) do names[#names + 1] = name end
    table.sort(names)
    return names
end

-- True or false, or nil for a feature that doesn't exist.
function API.IsFeatureEnabled(feature)
    local key = optionKey(feature)
    if not key then return nil end
    return Options:Get(key) and true or false
end

-- Returns true when the feature exists and now has the requested state.
function API.SetFeatureEnabled(feature, enabled)
    local key = optionKey(feature)
    if not key or not ns.db then return false end
    Options:Set(key, enabled and true or false)
    return true
end

_G.QoLAPI = API
