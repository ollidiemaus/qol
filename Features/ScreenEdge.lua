local _, ns = ...
local Options = ns.Options

-- Lets the frames of Edit Mode go a little past the edge of the screen, so what they show can sit
-- right on it. Every Edit Mode frame is clamped to the screen (EditModeSystemTemplate's
-- clampedToScreen), and Edit Mode clamps the frame's selection box (EditModeSystemMixin:
-- UpdateClampOffsets), which takes in the empty space around the frame's art. We give each frame
-- those insets moved PAST further in on every side, with SetClampRectInsets: a widget method, like
-- SetPoint. Edit Mode saves where a dragged frame went from its anchor
-- (EditModeManagerFrameMixin:UpdateSystemAnchorInfo reads GetPoint), so a place past the edge is
-- saved in the layout as it is.
--
-- Blizzard sets its insets again whenever it lays a frame out: a layout loaded or switched (also by
-- another addon: AutoSetup's switch on a resolution change goes through C_EditMode.SetActiveLayout,
-- which fires EDIT_MODE_LAYOUTS_UPDATED), leaving Edit Mode (RevertAllChanges applies the saved
-- layout again), a specialization change, and in Edit Mode a frame highlighted or a setting
-- changed. It sets 0s for a frame not laid out yet. We don't hook its code, so the events are
-- wake-ups, and while Edit Mode is open the frames are compared every drawn frame. The insets are
-- always worked out from the selection box; a frame whose insets already are those is left alone.
--
-- New insets don't move a frame the game has already pulled in: leaving Edit Mode anchors every
-- frame again under Blizzard's insets, and the frames stayed on the screen with ours set a frame
-- later. So a frame whose insets we changed is anchored again at the same points, which lays it out
-- under the new ones. That uses the widget's own ClearAllPoints and SetPoint (from its metatable):
-- Edit Mode replaces both on its frames with Lua that writes to the frame (OnSystemLoad), which
-- would taint it. A frame being dragged (Blizzard's isDragging) is left to the drag.
local ScreenEdge = {}
ns.ScreenEdge = ScreenEdge

local KEY = "pastScreenEdge"
-- How far past the edge, in the frame's own units: a frame Edit Mode shows bigger has as much more
-- empty space around its art, and may go as much further.
local PAST = 30

-- The frames we gave insets of ours, as keys.
local extended = setmetatable({}, { __mode = "k" })

local function allUsable(...)
    for index = 1, select("#", ...) do
        if not ns.IsUsable((select(index, ...))) then return false end
    end
    return true
end

-- Edit Mode's insets for a laid out frame (UpdateClampOffsets): from its edges to its selection box's.
local function selectionInsets(frame)
    local selection = frame.Selection
    if not (selection and frame.GetClampRectInsets) then return nil end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local sLeft, sRight, sTop, sBottom = selection:GetLeft(), selection:GetRight(), selection:GetTop(),
        selection:GetBottom()
    if not allUsable(left, right, top, bottom, sLeft, sRight, sTop, sBottom) then return nil end
    return { sLeft - left, sRight - right, sTop - top, sBottom - bottom }
end

local function moved(insets)
    return { insets[1] + PAST, insets[2] - PAST, insets[3] - PAST, insets[4] + PAST }
end

local function same(a, b)
    for index = 1, 4 do
        if math.abs(a[index] - b[index]) > 0.1 then return false end
    end
    return true
end

local function widgetMethod(frame, name)
    local meta = getmetatable(frame)
    local methods = type(meta) == "table" and meta.__index
    return type(methods) == "table" and methods[name] or nil
end

-- Anchors the frame again at the points it has, so the game lays it out under its new insets.
local function relayout(frame)
    if frame.isDragging then return end
    local clearAllPoints, setPoint = widgetMethod(frame, "ClearAllPoints"), widgetMethod(frame, "SetPoint")
    local count = frame:GetNumPoints()
    if not (clearAllPoints and setPoint and ns.IsUsable(count) and count > 0) then return end
    local points = {}
    for index = 1, count do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        if not (point and relativeTo and allUsable(x, y)) then return end
        points[index] = { point, relativeTo, relativePoint, x, y }
    end
    clearAllPoints(frame)
    for _, p in ipairs(points) do
        setPoint(frame, p[1], p[2], p[3], p[4], p[5])
    end
end

function ScreenEdge:Apply()
    local on = Options:Get(KEY) == true
    if not (on or next(extended)) then return end
    local frames = EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames
    if type(frames) ~= "table" then return end
    for _, frame in ipairs(frames) do
        local wanted = (on or extended[frame]) and selectionInsets(frame)
        local current = wanted and { frame:GetClampRectInsets() }
        if current and allUsable(current[1], current[2], current[3], current[4]) then
            if on then
                wanted = moved(wanted)
                extended[frame] = true
            else
                extended[frame] = nil
            end
            local changed = not same(current, wanted)
            if changed then
                frame:SetClampRectInsets(wanted[1], wanted[2], wanted[3], wanted[4])
            end
            -- Turned off, a frame past the edge comes back in even if Blizzard's insets are back already.
            if changed or not on then relayout(frame) end
        end
    end
end

local function schedule()
    ns.Later("screenEdge", function() ScreenEdge:Apply() end)
end

-- Shown while Edit Mode is open and the option is on: Blizzard sets the insets again without an
-- event there (a frame highlighted, a setting changed).
local watcher = CreateFrame("Frame")
watcher:Hide()
watcher:SetScript("OnUpdate", schedule)

local editModeOpen = false

local function updateWatcher()
    watcher:SetShown(editModeOpen and Options:Get(KEY) == true)
end

local WAKE_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "EDIT_MODE_LAYOUTS_UPDATED", -- Edit Mode layouts loaded or switched
    "PLAYER_SPECIALIZATION_CHANGED", -- Edit Mode applies the new specialization's layout
    "DISPLAY_SIZE_CHANGED",
    "UI_SCALE_CHANGED",
}

function ScreenEdge:Init()
    Options:Watch({ KEY }, function()
        updateWatcher()
        schedule()
    end)
    for _, event in ipairs(WAKE_EVENTS) do
        ns.Events:On(event, schedule)
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            editModeOpen = true
            updateWatcher()
        end, ScreenEdge)
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            editModeOpen = false
            updateWatcher()
            schedule()
        end, ScreenEdge)
    end
    schedule()
end
