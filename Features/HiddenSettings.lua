local _, ns = ...
local L = ns.L

-- The game's hidden settings: settings its options don't show, or show with only part of the range
-- the game takes, otherwise reached only through /console. The game keeps their values (CVars), and
-- they are the only truth: QoL saves nothing for them and writes none at login, only when the player
-- changes one on the Advanced settings page (UI/Settings.lua), which reads them through here. The
-- raid copies (RAIDgroundEffectDist and the rest) are the game's, for its Raid and Battleground
-- graphics, and stay alone.
local HiddenSettings = {}
ns.HiddenSettings = HiddenSettings

-- In the page's order. kind: "slider" (min to max in steps of step) or "checkbox" ("1" or "0").
-- The ranges were measured in Forever's client (2026-10-27): the game quietly ignores a value
-- outside them. Ground clutter fade takes any value, but goes no further than the distance. The
-- camera distance goes to 2.6, past the 2.0 where the game's own Max Camera Distance slider stops.
HiddenSettings.SETTINGS = {
    { cvar = "groundEffectDist", label = L.GROUND_CLUTTER_DISTANCE, tooltip = L.GROUND_CLUTTER_DISTANCE_TIP,
        kind = "slider", min = 40, max = 500, step = 1, section = L.SECTION_HIDDEN_GRAPHICS },
    { cvar = "groundEffectFade", label = L.GROUND_CLUTTER_FADE, tooltip = L.GROUND_CLUTTER_FADE_TIP,
        kind = "slider", min = 40, max = 500, step = 1, section = L.SECTION_HIDDEN_GRAPHICS },
    { cvar = "groundEffectDensity", label = L.GROUND_CLUTTER_DENSITY, tooltip = L.GROUND_CLUTTER_DENSITY_TIP,
        kind = "slider", min = 16, max = 256, step = 1, section = L.SECTION_HIDDEN_GRAPHICS },
    { cvar = "weatherDensity", label = L.WEATHER_DENSITY, tooltip = L.WEATHER_DENSITY_TIP,
        kind = "slider", min = 0, max = 3, step = 1, section = L.SECTION_HIDDEN_GRAPHICS },
    { cvar = "ResampleAlwaysSharpen", label = L.ALWAYS_SHARPEN, tooltip = L.ALWAYS_SHARPEN_TIP,
        kind = "checkbox", section = L.SECTION_HIDDEN_GRAPHICS },
    { cvar = "cameraDistanceMaxZoomFactor", label = L.MAX_CAMERA_DISTANCE, tooltip = L.MAX_CAMERA_DISTANCE_TIP,
        kind = "slider", min = 1, max = 2.6, step = 0.1, section = L.SECTION_HIDDEN_CAMERA },
}

local byCVar = {}
for _, setting in ipairs(HiddenSettings.SETTINGS) do byCVar[setting.cvar] = setting end

-- Through C_CVar where the client has it. A setting this client doesn't know reads as nil.
local function call(name, ...)
    local api = C_CVar and C_CVar[name] or _G[name]
    if type(api) ~= "function" then return nil end
    local ok, value = pcall(api, ...)
    if ok then return value end
    return nil
end

-- The game's value, a string; nil for a setting this client doesn't know.
function HiddenSettings.Get(cvar)
    return call("GetCVar", cvar)
end

function HiddenSettings.IsKnown(cvar)
    return HiddenSettings.Get(cvar) ~= nil
end

-- Sets it at once, in combat too. The game may refuse it and keep the old value, so read it back
-- with Get.
function HiddenSettings.Set(cvar, value)
    call("SetCVar", cvar, tostring(value))
end

-- The game's own default, a string; nil where the client doesn't say. From GetCVarDefault, or the
-- second value of C_CVar.GetCVarInfo on a client without it, never from QoL.
function HiddenSettings.GetGameDefault(cvar)
    local gameDefault = call("GetCVarDefault", cvar)
    if gameDefault ~= nil then return gameDefault end
    local info = C_CVar and C_CVar.GetCVarInfo
    if type(info) ~= "function" then return nil end
    local ok, _, infoGameDefault = pcall(info, cvar)
    if ok then return infoGameDefault end
    return nil
end

-- Whether the game's value is its default, as numbers where both are: the game formats them
-- inconsistently ("1.9" and "1.900000"). True where the client doesn't say its default.
function HiddenSettings.IsAtGameDefault(cvar)
    local gameDefault = HiddenSettings.GetGameDefault(cvar)
    if gameDefault == nil then return true end
    local value = HiddenSettings.Get(cvar)
    local number, gameDefaultNumber = tonumber(value), tonumber(gameDefault)
    if number and gameDefaultNumber then return number == gameDefaultNumber end
    return value == gameDefault
end

-- Sets it to the game's default; like Set, read back what the game kept.
function HiddenSettings.Reset(cvar)
    local gameDefault = HiddenSettings.GetGameDefault(cvar)
    if gameDefault ~= nil then HiddenSettings.Set(cvar, gameDefault) end
end

-- The setting for a CVar, nil for one that isn't a hidden setting.
function HiddenSettings.Find(cvar)
    return byCVar[cvar]
end

-- The settings this client knows, in the page's order.
function HiddenSettings.Known()
    local known = {}
    for _, setting in ipairs(HiddenSettings.SETTINGS) do
        if HiddenSettings.IsKnown(setting.cvar) then known[#known + 1] = setting end
    end
    return known
end
