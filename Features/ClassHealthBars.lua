local _, ns = ...
local Options = ns.Options

-- Health bars of the player, target, target of target, focus and focus target frames in the class
-- color of the unit they show. The bar keeps its default texture, desaturated and then tinted, so the shading
-- of the default green bar stays (Blizzard greys out a disconnected party member's bar the same
-- way). Units without a clear class keep the default bar.
--
-- Blizzard never colors these bars itself (they're locked to their texture's green), so only
-- widget methods are called and nothing on the frames is written. The game allows color changes
-- in combat, so a new target gets its color right away.
local ClassHealthBars = {}
ns.ClassHealthBars = ClassHealthBars

-- Option key and the unit frame whose health bar it colors.
ClassHealthBars.BARS = {
    { key = "classColorPlayer", frame = "PlayerFrame" },
    { key = "classColorTarget", frame = "TargetFrame" },
    { key = "classColorTargetOfTarget", frame = "TargetFrameToT" },
    { key = "classColorFocus", frame = "FocusFrame" },
    { key = "classColorFocusTarget", frame = "FocusFrameToT" },
}

local KEYS = {}
for _, bar in ipairs(ClassHealthBars.BARS) do KEYS[#KEYS + 1] = bar.key end

-- The class color for a unit, or nil when its bar stays as it is by default. Players and NPCs the
-- game shows like players have a clear class, the same rule Blizzard's raid frames use; a class
-- the game keeps secret counts as unknown.
function ClassHealthBars.ClassColor(unit)
    if not ns.IsUsable(unit) then return nil end
    local isPlayer = UnitIsPlayer(unit)
    if not ns.IsUsable(isPlayer) then return nil end
    if not isPlayer then
        local treatAsPlayer = UnitTreatAsPlayerForDisplay and UnitTreatAsPlayerForDisplay(unit)
        if not ns.IsUsable(treatAsPlayer) or not treatAsPlayer then return nil end
    end
    local _, class = UnitClass(unit)
    if not ns.IsUsable(class) or not RAID_CLASS_COLORS then return nil end
    return RAID_CLASS_COLORS[class]
end

-- Color and desaturation of each bar before we first changed it, so going back restores exactly
-- what the game had. A bar is in here while it shows a class color.
local originals = {}

local function colorBar(bar, color)
    if not originals[bar] then
        local r, g, b, a = bar:GetStatusBarColor()
        originals[bar] = { r = r, g = g, b = b, a = a, desaturated = bar:IsStatusBarDesaturated() }
    end
    bar:SetStatusBarDesaturated(true)
    bar:SetStatusBarColor(color.r, color.g, color.b)
end

local function restoreBar(bar)
    local original = originals[bar]
    if not original then return end
    bar:SetStatusBarDesaturated(original.desaturated)
    bar:SetStatusBarColor(original.r, original.g, original.b, original.a)
    originals[bar] = nil
end

-- The health bar's unit is the one it shows right now: "vehicle" on the player frame in a vehicle.
function ClassHealthBars:Apply()
    for _, info in ipairs(self.BARS) do
        local frame = _G[info.frame]
        local bar = frame and frame.healthbar
        if bar and bar.SetStatusBarDesaturated then
            local color = Options:Get(info.key) and self.ClassColor(bar.unit)
            if color then
                colorBar(bar, color)
            else
                restoreBar(bar)
            end
        end
    end
end

local function schedule()
    ns.Later("classHealthBars", function() ClassHealthBars:Apply() end, true)
end

local function isActive()
    for _, key in ipairs(KEYS) do
        if Options:Get(key) then return true end
    end
    return next(originals) ~= nil
end

-- Units whose events can change what one of the bars shows.
local UNITS = { player = true, target = true, focus = true }

-- Events are wake-ups: Apply looks at every bar again. Some only matter because Blizzard redraws
-- the target and focus frames on them, giving the bar a new texture for the unit's classification;
-- Apply runs after that, in case the new texture dropped the tint.
local EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
    "GROUP_ROSTER_UPDATE", -- redraws the focus frame
}
local UNIT_EVENTS = {
    "UNIT_TARGET", -- for "target" and "focus": the target of target or focus target changed
    "UNIT_CLASSIFICATION_CHANGED",
    "UNIT_TARGETABLE_CHANGED",
    "UNIT_ENTERED_VEHICLE", -- for "player": the player frame switches to the vehicle and back
    "UNIT_EXITING_VEHICLE",
    "UNIT_EXITED_VEHICLE",
}

function ClassHealthBars:Init()
    Options:Watch(KEYS, schedule)

    local function wake()
        if isActive() then schedule() end
    end
    for _, event in ipairs(EVENTS) do
        ns.Events:On(event, wake)
    end
    for _, event in ipairs(UNIT_EVENTS) do
        ns.Events:On(event, function(_, unit)
            if UNITS[unit] then wake() end
        end)
    end
    wake()
end
