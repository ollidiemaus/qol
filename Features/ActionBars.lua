local _, ns = ...
local L = ns.L
local Options = ns.Options

-- Reverses the direction in which action bar buttons fill a bar, per bar and per axis.
--
-- On Forever and retail 12.x, writing to a bar's own fields or calling its layout methods taints
-- the bar for the whole session, and with secret values that taint breaks unrelated frames (party
-- frames, cooldowns, Edit Mode). So the bars themselves are only ever read: we move their button
-- containers, using the same grid math as ActionBarMixin:UpdateGridLayout with the chosen axes
-- flipped, always from ns.Later (fresh timer, out of combat). A bar the player never flipped is
-- never touched.
local ActionBars = {}
ns.ActionBars = ActionBars

local function editModeLabel(globalName, fallback)
    local label = _G[globalName]
    if type(label) == "string" and label ~= "" then return label end
    return fallback
end

local function actionBarLabel(index)
    local pattern = editModeLabel("HUD_EDIT_MODE_ACTION_BAR_LABEL", L.ACTION_BAR)
    if not pattern:find("%%d") then pattern = L.ACTION_BAR end
    return pattern:format(index)
end

-- In Edit Mode order. The labels are the names Edit Mode shows, in the client's language.
ActionBars.BARS = {
    { frame = "MainActionBar", label = function() return actionBarLabel(1) end },
    { frame = "MultiBarBottomLeft", label = function() return actionBarLabel(2) end },
    { frame = "MultiBarBottomRight", label = function() return actionBarLabel(3) end },
    { frame = "MultiBarRight", label = function() return actionBarLabel(4) end },
    { frame = "MultiBarLeft", label = function() return actionBarLabel(5) end },
    { frame = "MultiBar5", label = function() return actionBarLabel(6) end },
    { frame = "MultiBar6", label = function() return actionBarLabel(7) end },
    { frame = "MultiBar7", label = function() return actionBarLabel(8) end },
    { frame = "StanceBar", label = function() return editModeLabel("HUD_EDIT_MODE_STANCE_BAR_LABEL", L.STANCE_BAR) end },
    { frame = "PetActionBar", label = function() return editModeLabel("HUD_EDIT_MODE_PET_ACTION_BAR_LABEL", L.PET_BAR) end },
}

function ActionBars.VerticalKey(frameName) return "flipVertical_" .. frameName end
function ActionBars.HorizontalKey(frameName) return "flipHorizontal_" .. frameName end

for _, bar in ipairs(ActionBars.BARS) do
    Options:AddDefault(ActionBars.VerticalKey(bar.frame), false)
    Options:AddDefault(ActionBars.HorizontalKey(bar.frame), false)
end

-- Blizzard's layout for the bar with the chosen axes flipped. Reads the bar, moves only its
-- shown button containers.
function ActionBars.Layout(bar, flipVertical, flipHorizontal)
    local containers = bar.shownButtonContainers
    if type(containers) ~= "table" or #containers == 0 then return false end

    local addToTop = bar.addButtonsToTop
    if flipVertical then addToTop = not addToTop end
    local addToRight = bar.addButtonsToRight
    if flipHorizontal then addToRight = not addToRight end

    local stride = math.max(1, math.ceil(#containers / (bar.numRows or 1)))
    local minPadding = bar.minButtonPadding or 2
    local padding = math.max(minPadding, bar.buttonPadding or minPadding)
    local xMultiplier = addToRight and 1 or -1
    local yMultiplier = addToTop and 1 or -1

    local layout
    if bar.isHorizontal then
        layout = GridLayoutUtil.CreateStandardGridLayout(stride, padding, padding, xMultiplier, yMultiplier)
    else
        layout = GridLayoutUtil.CreateVerticalGridLayout(stride, padding, padding, xMultiplier, yMultiplier)
    end

    local anchorPoint
    if bar.addButtonsToLeft then
        anchorPoint = "LEFT"
    elseif addToTop then
        anchorPoint = addToRight and "BOTTOMLEFT" or "BOTTOMRIGHT"
    else
        anchorPoint = addToRight and "TOPLEFT" or "TOPRIGHT"
    end

    GridLayoutUtil.ApplyGridLayout(containers, AnchorUtil.CreateAnchor(anchorPoint, bar, anchorPoint), layout)
    return true
end

-- Each time Blizzard lays a bar out it stores a new oldGridSettings table, so while that table is
-- still the one we laid out over, our layout stands and the bar needs nothing.
local function layoutToken(bar)
    return bar.oldGridSettings or false
end

-- Per bar name: the layout token our layout was applied over. A bar is in here while it is (or
-- was, until we restore it) flipped.
local appliedOver = {}
local settingsChanged = true

function ActionBars:Update()
    local force = settingsChanged
    settingsChanged = false
    for _, info in ipairs(self.BARS) do
        local bar = _G[info.frame]
        if bar then
            local flipVertical = Options:Get(self.VerticalKey(info.frame))
            local flipHorizontal = Options:Get(self.HorizontalKey(info.frame))
            local flipped = flipVertical or flipHorizontal
            local token = layoutToken(bar)
            if flipped and (force or appliedOver[info.frame] ~= token) then
                if self.Layout(bar, flipVertical, flipHorizontal) then
                    appliedOver[info.frame] = token
                end
            elseif not flipped and appliedOver[info.frame] ~= nil then
                -- Turned off without a reload: lay it out once more the way Blizzard would.
                self.Layout(bar, false, false)
                appliedOver[info.frame] = nil
            end
        end
    end
end

local function schedule()
    ns.Later("actionBars", function() ActionBars:Update() end)
end

local function isFlipKey(key)
    return key:find("^flipVertical_") ~= nil or key:find("^flipHorizontal_") ~= nil
end

local function hasAnyFlip()
    for _, info in ipairs(ActionBars.BARS) do
        if Options:Get(ActionBars.VerticalKey(info.frame)) or Options:Get(ActionBars.HorizontalKey(info.frame)) then
            return true
        end
    end
    return next(appliedOver) ~= nil
end

-- Events are only wake-ups: Update re-lays out a bar only if Blizzard did since our last pass.
local WAKE_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "EDIT_MODE_LAYOUTS_UPDATED", -- Edit Mode layouts loaded or switched
    "UPDATE_SHAPESHIFT_FORMS", -- the stance bar gained or lost buttons
    "PET_BAR_UPDATE",
    "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR",
    "ACTIONBAR_PAGE_CHANGED",
}

function ActionBars:Init()
    Options:Watch(isFlipKey, function()
        settingsChanged = true
        schedule()
    end)

    local function wake()
        if hasAnyFlip() then schedule() end
    end
    for _, event in ipairs(WAKE_EVENTS) do
        ns.Events:On(event, wake)
    end
    ns.Events:On("UNIT_PET", function(_, unit)
        if unit == "player" then wake() end
    end)
    -- Changing a bar in Edit Mode lays it out again without an event.
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Exit", wake, ActionBars)
    end
    wake()
end
