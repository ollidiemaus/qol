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
-- gameSlider: the CVar of the game's own graphics slider that sets it whenever it's moved, for
-- Reset (HiddenSettings.Reset). The ranges were measured in Forever's client (2026-10-27): the game
-- quietly ignores a value outside them. Ground clutter fade takes any value, but goes no further
-- than the distance. The camera distance goes to 2.6, past the 2.0 where the game's own Max Camera
-- Distance slider stops. Draw distance's were measured in retail's (2026-10-28): World distance and
-- the horizon take any value, so their sliders cover what View Distance sets, World distance down
-- to its game default of 1000.
HiddenSettings.SETTINGS = {
    { cvar = "groundEffectDist", label = L.GROUND_CLUTTER_DISTANCE, tooltip = L.GROUND_CLUTTER_DISTANCE_TIP,
        kind = "slider", min = 40, max = 500, step = 1, section = L.SECTION_HIDDEN_GRAPHICS,
        gameSlider = "graphicsGroundClutter" },
    { cvar = "groundEffectFade", label = L.GROUND_CLUTTER_FADE, tooltip = L.GROUND_CLUTTER_FADE_TIP,
        kind = "slider", min = 40, max = 500, step = 1, section = L.SECTION_HIDDEN_GRAPHICS },
    { cvar = "groundEffectDensity", label = L.GROUND_CLUTTER_DENSITY, tooltip = L.GROUND_CLUTTER_DENSITY_TIP,
        kind = "slider", min = 16, max = 256, step = 1, section = L.SECTION_HIDDEN_GRAPHICS,
        gameSlider = "graphicsGroundClutter" },
    { cvar = "weatherDensity", label = L.WEATHER_DENSITY, tooltip = L.WEATHER_DENSITY_TIP,
        kind = "slider", min = 0, max = 3, step = 1, section = L.SECTION_HIDDEN_GRAPHICS },
    { cvar = "ResampleAlwaysSharpen", label = L.ALWAYS_SHARPEN, tooltip = L.ALWAYS_SHARPEN_TIP,
        kind = "checkbox", section = L.SECTION_HIDDEN_GRAPHICS },
    { cvar = "farclip", label = L.WORLD_DISTANCE, tooltip = L.WORLD_DISTANCE_TIP,
        kind = "slider", min = 1000, max = 10000, step = 100, section = L.SECTION_DRAW_DISTANCE,
        gameSlider = "graphicsViewDistance" },
    { cvar = "horizonStart", label = L.HORIZON_START, tooltip = L.HORIZON_START_TIP,
        kind = "slider", min = 400, max = 4000, step = 100, section = L.SECTION_DRAW_DISTANCE,
        gameSlider = "graphicsViewDistance" },
    { cvar = "horizonClip", label = L.HORIZON_END, tooltip = L.HORIZON_END_TIP,
        kind = "slider", min = 1500, max = 10000, step = 100, section = L.SECTION_DRAW_DISTANCE,
        gameSlider = "graphicsViewDistance" },
    { cvar = "lodObjectFadeScale", label = L.OBJECT_FADE_SCALE, tooltip = L.OBJECT_FADE_SCALE_TIP,
        kind = "slider", min = 50, max = 5000, step = 10, section = L.SECTION_DRAW_DISTANCE,
        gameSlider = "graphicsEnvironmentDetail" },
    { cvar = "lodObjectCullSize", label = L.OBJECT_CULL_SIZE, tooltip = L.OBJECT_CULL_SIZE_TIP,
        kind = "slider", min = 1, max = 100, step = 1, section = L.SECTION_DRAW_DISTANCE,
        gameSlider = "graphicsEnvironmentDetail" },
    { cvar = "lodObjectCullDist", label = L.OBJECT_CULL_DISTANCE, tooltip = L.OBJECT_CULL_DISTANCE_TIP,
        kind = "slider", min = 1, max = 200, step = 1, section = L.SECTION_DRAW_DISTANCE },
    { cvar = "cameraDistanceMaxZoomFactor", label = L.MAX_CAMERA_DISTANCE, tooltip = L.MAX_CAMERA_DISTANCE_TIP,
        kind = "slider", min = 1, max = 2.6, step = 0.1, section = L.SECTION_HIDDEN_CAMERA },
}

-- The game sliders by their CVar, as the game's options name them.
HiddenSettings.GAME_SLIDER_NAMES = { graphicsViewDistance = L.GAME_VIEW_DISTANCE,
    graphicsEnvironmentDetail = L.GAME_ENVIRONMENT_DETAIL, graphicsGroundClutter = L.GAME_GROUND_CLUTTER }

local byCVar = {}
for _, setting in ipairs(HiddenSettings.SETTINGS) do byCVar[setting.cvar] = setting end

-- The CVar of the game slider that sets it, nil for one none sets.
local function gameSliderOf(cvar)
    local setting = byCVar[cvar]
    return setting and setting.gameSlider
end

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

-- Whether the game won't change it in combat: the secure flag, the sixth value of
-- C_CVar.GetCVarInfo. False on a client without it.
function HiddenSettings.IsProtected(cvar)
    local info = C_CVar and C_CVar.GetCVarInfo
    if type(info) ~= "function" then return false end
    local ok, _, _, _, _, _, isSecure = pcall(info, cvar)
    return ok and isSecure == true
end

-- Whether the game takes a change to it, in combat or out: always, but in combat not a protected
-- one, nor one whose game slider (which its Reset writes) is protected. The caller says whether it's
-- in combat, as PLAYER_REGEN_DISABLED comes before InCombatLockdown.
function HiddenSettings.CanChange(cvar, inCombat)
    if not inCombat then return true end
    local slider = gameSliderOf(cvar)
    return not (HiddenSettings.IsProtected(cvar) or (slider and HiddenSettings.IsProtected(slider)))
end

-- Sets it at once, in combat too (the page leaves a protected one alone then). The game may
-- refuse it and keep the old value, so read it back with Get.
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

-- Sets it to what its game slider sets, or else to the game's default; like Set, read back what the
-- game kept. Writing a game slider's step again makes the game set every setting behind it again, so
-- that puts back the slider's other settings too. Not to the game default for these: farclip's
-- (1000) is below anything View Distance sets.
function HiddenSettings.Reset(cvar)
    local slider = gameSliderOf(cvar)
    if slider then
        HiddenSettings.Set(slider, HiddenSettings.Get(slider))
        return
    end
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
