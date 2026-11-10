local _, ns = ...

-- Account-wide settings (QoLDB.options) with their defaults. Features read them with Get
-- and react to changes through Watch, so the settings page never calls into a feature directly.
local Options = { watchers = {} }
ns.Options = Options

-- Only junk selling, the vendor price and /rl (which only exists when nothing else has it) are on
-- by default. Repairs spend gold (yours or the guild's), IDs are clutter for most players, quest
-- automation decides for the player, and everything that changes the look of the interface waits
-- for the player to opt in.
local DEFAULTS = {
    sellJunk = true,
    autoRepair = false,
    guildRepair = false,

    questAccept = false,
    questTurnIn = false,

    fasterAutoLoot = false,

    tooltipIDs = false,
    tooltipSellPrice = true,

    hideMicroMenu = false,
    hideBagsBar = false,
    sortOnOpen = false,

    hideChatSocial = false,
    hideChatButtons = false,
    hideCombatLog = false,
    chatClassColors = false,

    -- Names for the mail bookmarks, "" for none.
    mailBookmark1 = "",
    mailBookmark2 = "",
    mailBookmark3 = "",
    mailBookmark4 = "",
    mailBookmark5 = "",
    mailBookmark6 = "",

    squareMinimap = false,
    squareMinimapBorder = "bronze", -- "bronze" or "black"
    minimapZoneText = "default", -- a minimap position (MinimapLayout.PositionsFor)
    minimapZoneTextClassColor = false,
    hideMinimapZoneTextFrame = false, -- the zone text's frame at its default spot
    minimapZoneTextSize = 0, -- a font size, 0 for the game's own
    -- Each element's offset: a small shift from its spot, in screen units, across and up.
    minimapZoneTextOffsetX = 0,
    minimapZoneTextOffsetY = 0,
    minimapCoords = "default", -- the coordinates: "default" (the game's spot) or "hidden"
    minimapCoordsClassColor = false,
    minimapCoordsSize = 0,
    minimapCoordsOffsetX = 0,
    minimapCoordsOffsetY = 0,
    -- Where the minimap's buttons go: "default", "hidden", or "topLeft", "top", "topRight",
    -- "bottomLeft", "bottom", "bottomRight" (a row above or below the minimap). The tracking button
    -- and the day and night icon can also go inside the map: "insideTopLeft", "insideTop" and so on.
    minimapClock = "default",
    minimapClockClassColor = false,
    minimapClockSize = 0,
    minimapClockOffsetX = 0,
    minimapClockOffsetY = 0,
    minimapPerformance = "hidden", -- FPS and ping: a row's spot or "hidden", no "default"
    minimapPerformanceClassColor = false,
    minimapPerformanceSize = 0,
    minimapPerformanceShow = "both", -- "both", "fps" or "ping"
    minimapPerformanceOffsetX = 0,
    minimapPerformanceOffsetY = 0,
    minimapCompartment = "default",
    minimapCompartmentOffsetX = 0,
    minimapCompartmentOffsetY = 0,
    minimapTracking = "default",
    minimapTrackingOffsetX = 0,
    minimapTrackingOffsetY = 0,
    minimapDayNight = "default",
    minimapDayNightOffsetX = 0,
    minimapDayNightOffsetY = 0,
    minimapCalendar = "default", -- the calendar button: "default" (the game's spot) or "hidden"

    mapDungeons = false,
    mapTravel = false,

    classColorPlayer = false,
    classColorTarget = false,
    classColorTargetOfTarget = false,
    classColorFocus = false,
    classColorFocusTarget = false,
    druidManaBar = false,
    hidePortraitHitText = false,
    pastScreenEdge = false,
    hideRaidManager = false, -- Forever only, on the Group Frames page
    groupFrameBuffs = false, -- tracked buffs on the group frames, Forever only; the list is QoLDB.trackedBuffs
    groupFrameBuffSize = 16, -- the tracked buff icons' size, in pixels
    groupFrameBuffCountdown = false, -- the game's countdown numbers on "has it" icons

    reloadCommand = true,

    viewportEnabled = false,
    viewportTop = 0,
    viewportBottom = 0,
    viewportLeft = 0,
    viewportRight = 0,
    viewportColor = "ff000000", -- AARRGGBB, the format the settings color swatch uses

    disableBarPaging = false,
    hideButtonBorders = false,
    hideCooldownManagerBorders = false,
    reminders = false,
    reminderWellFed = false,
    reminderWellRested = false,
    reminderCampBenefits = false,
    reminderIconSize = 40,
    -- The reminder row's position, reminderRowX and reminderRowY (its middle's offset from the
    -- screen's), has no default: unset, the row sits in the middle of the screen's lower half.
    reminderMainHand = false,
    reminderOffHand = false,
    reminderHideResting = false,
    reminderHideCombat = false,
    reminderHideMounted = false,
    reminderHideDeadOrFlying = true,
    reminderHideMaxLevel = true,
    upgradeSpellRanks = false,
    ring = false,
    clickCast = false,
    clickCastEnemies = false,

    controllerBackButtons = false,
    controllerBackButtonsBar = 8, -- Action Bar 6, 7 or 8, whose buttons 9 to 12 the back buttons use
    controllerTriggerToggle = false,
    controllerTriggerToggleTopAfterCombat = true,
    hideBuffTooltips = false,
}
-- Action bar flips ("flipVertical_MainActionBar" and so on) default to false and are added by
-- ActionBars.lua through Options:AddDefault, next to the list of bars they belong to.
Options.DEFAULTS = DEFAULTS

local function stored()
    return ns.db and ns.db.options
end

-- Saved values whose type doesn't match their default (a hand-edited file, or one from a QoL that
-- stores the option differently). They stay in the file, so that QoL finds them again, while Get
-- returns the default; Set replaces them. Worked out once at Init, since Get runs on tooltip paths.
local mismatched = {}

function Options:AddDefault(key, value)
    DEFAULTS[key] = value
end

function Options:GetDefault(key)
    return DEFAULTS[key]
end

function Options:Get(key)
    local options = stored()
    local value = options and options[key]
    if value == nil or mismatched[key] then
        return DEFAULTS[key]
    end
    return value
end

-- A value equal to the default is stored as nil, so the saved file only holds real choices.
function Options:Set(key, value)
    local options = stored()
    if not options then return end
    local old = self:Get(key)
    if value == DEFAULTS[key] then
        value = nil
    end
    options[key] = value
    mismatched[key] = nil
    local new = self:Get(key)
    if new ~= old then
        for _, watcher in ipairs(self.watchers) do
            if watcher.keys[key] then
                watcher.fn(key, new)
            end
        end
    end
end

-- Calls fn(key, value) whenever one of the keys changes. keys is a list or a function(key) that
-- returns true for the keys of interest (used for the many action bar flips).
function Options:Watch(keys, fn)
    local lookup
    if type(keys) == "function" then
        lookup = setmetatable({}, { __index = function(_, key) return keys(key) end })
    else
        lookup = {}
        for _, key in ipairs(keys) do lookup[key] = true end
    end
    self.watchers[#self.watchers + 1] = { keys = lookup, fn = fn }
end

-- Called once QoLDB is loaded.
function Options:Init(db)
    ns.db = db
    if type(db.options) ~= "table" then
        db.options = {}
    end
    mismatched = {}
    for key, value in pairs(db.options) do
        local default = DEFAULTS[key]
        if default ~= nil and type(value) ~= type(default) then
            mismatched[key] = true
        end
    end
end
