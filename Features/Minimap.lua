local _, ns = ...
local Options = ns.Options

-- The minimap's shape and its zone text.
--   * Square: the map gets a square mask and a thin black border, the round frame around it goes
--     to the hidden holder. GetMinimapShape() then answers "SQUARE", the convention other addons
--     (LibDBIcon's minimap buttons, for one) read to place their buttons.
--   * Zone text above or below the minimap: the game's zone name button leaves the header bar and
--     sits centered on the minimap's edge; the bar goes to the hidden holder. Below the minimap,
--     the coordinates move under the zone text.
--   * Zone text in class color: the game colors the zone name by its PvP status each time the zone
--     changes; the class color is put back right after.
-- Only widget methods are called; the game's own minimap code is never called or hooked.
local MinimapLayout = {}
ns.MinimapLayout = MinimapLayout

local SQUARE, ZONE_TEXT, CLASS_COLOR = "squareMinimap", "minimapZoneText", "minimapZoneTextClassColor"
-- "default" (or anything else) leaves the zone text where the game puts it.
local POSITIONS = { above = true, below = true }

local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
-- Forever's minimap skin masks the map with this atlas; other clients get the classic round mask.
local ROUND_MASK_ATLAS = "ui-hud-minimap-frame-generic-mask"
local ROUND_MASK_FILE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local BORDER_SIZE = 2
local ZONE_TEXT_GAP = 4
local COORDS_GAP = 2

function MinimapLayout.RoundMask()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ROUND_MASK_ATLAS) then
        return ROUND_MASK_ATLAS
    end
    return ROUND_MASK_FILE
end

local function squareShape()
    return "SQUARE"
end

-- The round frame around the map: Forever and retail draw it with these two textures.
local function ringTextures()
    return MinimapCompassTexture, MinimapCompassTextureUnderlay
end

local function setRingHidden(hidden, ...)
    for i = 1, select("#", ...) do
        local texture = select(i, ...)
        if texture and (hidden or ns.Hider:IsHidden(texture)) then
            ns.Hider:SetHidden(texture, hidden)
        end
    end
end

-- Four black bars just outside the map's edges. Our own frame, a child of the minimap.
local border

local function createBorder()
    local frame = CreateFrame("Frame", nil, Minimap)
    frame:SetAllPoints(Minimap)
    local function edge()
        local texture = frame:CreateTexture(nil, "BORDER")
        texture:SetColorTexture(0, 0, 0, 1)
        return texture
    end
    local top, bottom, left, right = edge(), edge(), edge(), edge()
    top:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", -BORDER_SIZE, 0)
    top:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", BORDER_SIZE, 0)
    top:SetHeight(BORDER_SIZE)
    bottom:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", -BORDER_SIZE, 0)
    bottom:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", BORDER_SIZE, 0)
    bottom:SetHeight(BORDER_SIZE)
    left:SetPoint("TOPRIGHT", Minimap, "TOPLEFT")
    left:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT")
    left:SetWidth(BORDER_SIZE)
    right:SetPoint("TOPLEFT", Minimap, "TOPRIGHT")
    right:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMRIGHT")
    right:SetWidth(BORDER_SIZE)
    frame:Hide()
    return frame
end

-- Whether the map is square because of us, and the GetMinimapShape we replaced.
local squared = false
local previousShape

-- Some zones draw the minimap with the hybrid minimap (loaded on demand), masked on its own.
local function setHybridMask(mask)
    local hybridMask = HybridMinimap and HybridMinimap.CircleMask
    if hybridMask then hybridMask:SetTexture(mask) end
end

function MinimapLayout:ApplyShape()
    if Options:Get(SQUARE) then
        Minimap:SetMaskTexture(SQUARE_MASK)
        setHybridMask(SQUARE_MASK)
        setRingHidden(true, ringTextures())
        border = border or createBorder()
        border:Show()
        if not squared then
            previousShape = _G.GetMinimapShape
            _G.GetMinimapShape = squareShape
        end
        squared = true
    elseif squared then
        Minimap:SetMaskTexture(self.RoundMask())
        setHybridMask(ROUND_MASK_FILE)
        setRingHidden(false, ringTextures())
        border:Hide()
        if _G.GetMinimapShape == squareShape then
            _G.GetMinimapShape = previousShape
        end
        previousShape = nil
        squared = false
    end
end

local function savePoints(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do
        points[i] = { frame:GetPoint(i) }
    end
    return points
end

local function restorePoints(frame, points)
    frame:ClearAllPoints()
    for _, p in ipairs(points) do
        frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
end

-- What the zone text looked like before we moved it; nil while it is where the game put it.
local moved

-- The zone text sits on the edge of what is drawn: the square map, or the round frame around it.
local function edgeRegion()
    if not Options:Get(SQUARE) and MinimapCompassTexture then return MinimapCompassTexture end
    return Minimap
end

-- The minimap's width in the zone text button's own units (Edit Mode scales the minimap alone).
local function minimapWidthFor(frame)
    local width = Minimap:GetWidth()
    local scale, ownScale = Minimap:GetEffectiveScale(), frame:GetEffectiveScale()
    if ns.IsUsable(scale) and ns.IsUsable(ownScale) and ownScale > 0 then
        width = width * scale / ownScale
    end
    return width
end

function MinimapLayout:ApplyZoneText()
    local cluster = MinimapCluster
    local button, text = cluster and cluster.ZoneTextButton, MinimapZoneText
    if not (button and text) then return end
    local container = cluster.MinimapContainer
    local coords = container and container.PlayerCoords
    local position = Options:Get(ZONE_TEXT)

    if POSITIONS[position] then
        moved = moved or {
            buttonPoints = savePoints(button), buttonWidth = button:GetWidth(),
            textWidth = text:GetWidth(), justify = text:GetJustifyH(),
            coordsPoints = coords and savePoints(coords),
        }
        if cluster.BorderTop then ns.Hider:SetHidden(cluster.BorderTop, true) end
        local width = minimapWidthFor(button)
        button:SetWidth(width)
        text:SetWidth(width)
        text:SetJustifyH("CENTER")
        button:ClearAllPoints()
        if position == "above" then
            button:SetPoint("BOTTOM", edgeRegion(), "TOP", 0, ZONE_TEXT_GAP)
        else
            button:SetPoint("TOP", edgeRegion(), "BOTTOM", 0, -ZONE_TEXT_GAP)
        end
        if coords then
            if position == "below" then
                coords:ClearAllPoints()
                coords:SetPoint("TOP", button, "BOTTOM", 0, -COORDS_GAP)
            else
                restorePoints(coords, moved.coordsPoints)
            end
        end
    elseif moved then
        restorePoints(button, moved.buttonPoints)
        button:SetWidth(moved.buttonWidth)
        text:SetWidth(moved.textWidth)
        text:SetJustifyH(moved.justify)
        if coords and moved.coordsPoints then restorePoints(coords, moved.coordsPoints) end
        if cluster.BorderTop and ns.Hider:IsHidden(cluster.BorderTop) then
            ns.Hider:SetHidden(cluster.BorderTop, false)
        end
        moved = nil
    end
end

function MinimapLayout:Apply()
    if not Minimap then return end
    self:ApplyShape()
    self:ApplyZoneText()
end

local function classColor()
    local _, class = UnitClass("player")
    if not ns.IsUsable(class) or not RAID_CLASS_COLORS then return nil end
    return RAID_CLASS_COLORS[class]
end

local function isColor(color, r, g, b)
    local function near(a, c) return ns.IsUsable(a) and math.abs(a - c) < 0.01 end
    return near(r, color.r) and near(g, color.g) and near(b, color.b)
end

-- The color the game last gave the zone text, while we show the class color instead.
local gameColor

function MinimapLayout:ApplyZoneColor()
    local text = MinimapZoneText
    if not text then return end
    local color = classColor()
    local r, g, b = text:GetTextColor()
    if Options:Get(CLASS_COLOR) and color then
        -- Anything but our own color is a new one from the game (a zone change) to go back to.
        if not isColor(color, r, g, b) then gameColor = { r, g, b } end
        text:SetTextColor(color.r, color.g, color.b)
    elseif gameColor then
        if color and isColor(color, r, g, b) then
            text:SetTextColor(gameColor[1], gameColor[2], gameColor[3])
        end
        gameColor = nil
    end
end

local function scheduleLayout()
    ns.Later("minimapLayout", function() MinimapLayout:Apply() end)
end

-- A color is allowed in combat, so a zone change in combat gets the class color at once.
local function scheduleColor()
    ns.Later("minimapZoneColor", function() MinimapLayout:ApplyZoneColor() end, true)
end

local function layoutActive()
    return Options:Get(SQUARE) or POSITIONS[Options:Get(ZONE_TEXT)] ~= nil
end

function MinimapLayout:Init()
    Options:Watch({ SQUARE, ZONE_TEXT }, scheduleLayout)
    Options:Watch({ CLASS_COLOR }, scheduleColor)

    -- Forever's minimap skin masks the map again when the rotate setting changes, and the hybrid
    -- minimap brings its own round mask when it loads. Edit Mode may resize the minimap.
    ns.Events:On("CVAR_UPDATE", function(_, name)
        if name == "rotateMinimap" and Options:Get(SQUARE) then scheduleLayout() end
    end)
    ns.Events:On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_HybridMinimap" and Options:Get(SQUARE) then scheduleLayout() end
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            if layoutActive() then scheduleLayout() end
        end, MinimapLayout)
    end

    -- The game sets the zone text's color again on these.
    local function recolor()
        if Options:Get(CLASS_COLOR) then scheduleColor() end
    end
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
        "ZONE_CHANGED_NEW_AREA", "SETTINGS_LOADED" }) do
        ns.Events:On(event, recolor)
    end

    if layoutActive() then scheduleLayout() end
    recolor()
end
