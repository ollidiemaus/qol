local _, ns = ...

-- Account-wide settings (ForeverQoLDB.options) with their defaults. Features read them with Get
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

    tooltipIDs = false,
    tooltipSellPrice = true,

    hideMicroMenu = false,
    hideBagsBar = false,
    showCombinedBagSort = false,

    hideChatSocial = false,
    hideChatButtons = false,
    hideCombatLog = false,
    chatClassColors = false,

    hideMinimapCoords = false,
    squareMinimap = false,
    minimapZoneText = "default", -- "default", "above" or "below"
    minimapZoneTextClassColor = false,

    mapDungeons = false,
    mapTravel = false,

    classColorPlayer = false,
    classColorTarget = false,
    classColorTargetOfTarget = false,
    classColorFocus = false,
    classColorFocusTarget = false,

    reloadCommand = true,

    viewportEnabled = false,
    viewportTop = 0,
    viewportBottom = 0,
    viewportLeft = 0,
    viewportRight = 0,
    viewportColor = "ff000000", -- AARRGGBB, the format the settings color swatch uses
}
-- Action bar flips ("flipVertical_MainActionBar" and so on) default to false and are added by
-- ActionBars.lua through Options:AddDefault, next to the list of bars they belong to.
Options.DEFAULTS = DEFAULTS

local function stored()
    return ns.db and ns.db.options
end

function Options:AddDefault(key, value)
    DEFAULTS[key] = value
end

function Options:GetDefault(key)
    return DEFAULTS[key]
end

function Options:Get(key)
    local options = stored()
    local value = options and options[key]
    if value == nil then
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

-- Called once ForeverQoLDB is loaded.
function Options:Init(db)
    ns.db = db
    if type(db.options) ~= "table" then
        db.options = {}
    end
    -- Drop values whose type no longer matches the default (a hand-edited or outdated file), so
    -- every Get returns what the features expect.
    for key, value in pairs(db.options) do
        local default = DEFAULTS[key]
        if default ~= nil and type(value) ~= type(default) then
            db.options[key] = nil
        end
    end
end
