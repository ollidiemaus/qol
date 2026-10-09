local _, ns = ...
local Options = ns.Options

-- Shrinks the area the 3D world is drawn in (WorldFrame) and fills the margins with a color, like
-- the old viewport addons. Margins are set in screen pixels, so they don't change with UI scale.
local Viewport = {}
ns.Viewport = Viewport

local KEYS = {
    "viewportEnabled", "viewportTop", "viewportBottom", "viewportLeft", "viewportRight", "viewportColor",
}

-- The world keeps at least this share of the screen in each direction, whatever the margins.
local MIN_WORLD_SHARE = 0.25

-- A frame at effective scale 1 is 768 units tall, whatever the resolution.
local UNITS_PER_SCREEN_HEIGHT = 768

-- WorldFrame's own anchors, saved before the first change so turning the viewport off restores
-- exactly what the game had. nil while we haven't touched WorldFrame.
local originalPoints

local function pixelsToUnits(frame, pixels)
    local _, physicalHeight = GetPhysicalScreenSize()
    if not physicalHeight or physicalHeight <= 0 then return 0 end
    local scale = frame:GetEffectiveScale()
    if not ns.IsUsable(scale) or scale <= 0 then scale = 1 end
    return pixels * (UNITS_PER_SCREEN_HEIGHT / physicalHeight) / scale
end

-- Shrinks both margins of one axis by the same factor when together they'd leave too little world.
function Viewport.FitMargins(first, second, total)
    local allowed = total * (1 - MIN_WORLD_SHARE)
    local sum = first + second
    if sum <= allowed or sum <= 0 then
        return first, second
    end
    local factor = allowed / sum
    return first * factor, second * factor
end

-- The margins in screen pixels, fitted to the screen: top, bottom, left, right.
function Viewport:GetMarginPixels()
    local width, height = GetPhysicalScreenSize()
    local top, bottom = self.FitMargins(Options:Get("viewportTop"), Options:Get("viewportBottom"), height or 0)
    local left, right = self.FitMargins(Options:Get("viewportLeft"), Options:Get("viewportRight"), width or 0)
    return top, bottom, left, right
end

-- "AARRGGBB" to r, g, b. The margins are always opaque: behind them is nothing worth showing.
function Viewport.ParseColor(hex)
    if type(hex) == "string" and #hex == 8 then
        local r, g, b = tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), tonumber(hex:sub(7, 8), 16)
        if r and g and b then
            return r / 255, g / 255, b / 255
        end
    end
    return 0, 0, 0
end

local function saveOriginalPoints()
    if originalPoints then return end
    originalPoints = {}
    for i = 1, WorldFrame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = WorldFrame:GetPoint(i)
        originalPoints[i] = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
    end
end

local function restoreOriginalPoints()
    WorldFrame:ClearAllPoints()
    if #originalPoints > 0 then
        for _, p in ipairs(originalPoints) do
            WorldFrame:SetPoint(p.point, p.relativeTo, p.relativePoint, p.x, p.y)
        end
    else
        WorldFrame:SetAllPoints(UIParent)
    end
end

-- The margins are four color textures along the screen edges. Their frame has no parent, so it
-- stays visible when the interface is hidden (Alt+Z): the world doesn't grow back then either.
local border

local function createBorder()
    local frame = CreateFrame("Frame")
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(0)
    frame:SetAllPoints(UIParent)
    frame:EnableMouse(false)
    frame.edges = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        frame.edges[side] = frame:CreateTexture(nil, "BACKGROUND")
    end
    frame:Hide()
    return frame
end

local function layoutBorder(top, bottom, left, right)
    local edges = border.edges
    local function units(pixels) return pixelsToUnits(border, pixels) end

    edges.top:ClearAllPoints()
    edges.top:SetPoint("TOPLEFT", border, "TOPLEFT")
    edges.top:SetPoint("TOPRIGHT", border, "TOPRIGHT")
    edges.top:SetHeight(units(top))

    edges.bottom:ClearAllPoints()
    edges.bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT")
    edges.bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT")
    edges.bottom:SetHeight(units(bottom))

    -- The side edges run between the top and bottom edges.
    edges.left:ClearAllPoints()
    edges.left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, -units(top))
    edges.left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, units(bottom))
    edges.left:SetWidth(units(left))

    edges.right:ClearAllPoints()
    edges.right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, -units(top))
    edges.right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, units(bottom))
    edges.right:SetWidth(units(right))

    local sizes = { top = top, bottom = bottom, left = left, right = right }
    local r, g, b = Viewport.ParseColor(Options:Get("viewportColor"))
    for side, texture in pairs(edges) do
        texture:SetColorTexture(r, g, b, 1)
        texture:SetShown(sizes[side] > 0)
    end
end

-- During cutscenes the game owns WorldFrame: an in-engine cinematic (CinematicFrame) re-anchors it
-- for its black bars and resets it to full screen when it ends, and a movie (MovieFrame) hides it.
-- A second hand moving WorldFrame at the same time is how viewport addons crash the game in
-- cutscenes, so the viewport steps aside: while one runs, no changes and no margins; afterwards,
-- everything is applied again.
function Viewport.IsCutsceneRunning()
    return (CinematicFrame and CinematicFrame:IsShown()) or (MovieFrame and MovieFrame:IsShown()) or false
end

-- A cutscene can end without an event we could rely on (a movie just runs out), so a change that
-- had to wait checks back on this timer, one check at a time.
local CUTSCENE_RETRY_SECONDS = 1
local retryPending = false
local schedule

local function retryAfterCutscene()
    if retryPending then return end
    retryPending = true
    C_Timer.After(CUTSCENE_RETRY_SECONDS, function()
        retryPending = false
        schedule()
    end)
end

function Viewport:Apply()
    local enabled = Options:Get("viewportEnabled")
    -- WorldFrame is only ever touched after the player turned the viewport on.
    if not enabled and not originalPoints then
        if border then border:Hide() end
        return
    end

    if self.IsCutsceneRunning() then
        if border then border:Hide() end
        retryAfterCutscene()
        return
    end

    if not enabled then
        restoreOriginalPoints()
        originalPoints = nil
        if border then border:Hide() end
        return
    end

    saveOriginalPoints()
    local top, bottom, left, right = self:GetMarginPixels()
    local function units(pixels) return pixelsToUnits(WorldFrame, pixels) end
    WorldFrame:ClearAllPoints()
    WorldFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", units(left), -units(top))
    WorldFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -units(right), units(bottom))

    border = border or createBorder()
    layoutBorder(top, bottom, left, right)
    border:Show()
end

schedule = function()
    ns.Later("viewport", function() Viewport:Apply() end)
end

function Viewport:Init()
    Options:Watch(KEYS, schedule)
    -- Pixel margins depend on the resolution, and a loading screen is where the game or another
    -- addon may have reset WorldFrame.
    local function scheduleIfEnabled()
        if Options:Get("viewportEnabled") then schedule() end
    end
    ns.Events:On("DISPLAY_SIZE_CHANGED", scheduleIfEnabled)
    ns.Events:On("UI_SCALE_CHANGED", scheduleIfEnabled)
    ns.Events:On("PLAYER_ENTERING_WORLD", scheduleIfEnabled)

    -- Cutscenes: the margins go away at once (our own frame, nothing to wait for), WorldFrame is
    -- left to the game, and the viewport comes back when the cutscene ends.
    local function hideBorder()
        if border then border:Hide() end
    end
    ns.Events:On("CINEMATIC_START", hideBorder)
    ns.Events:On("PLAY_MOVIE", hideBorder)
    ns.Events:On("CINEMATIC_STOP", scheduleIfEnabled)
    ns.Events:On("STOP_MOVIE", scheduleIfEnabled)

    scheduleIfEnabled()
end
