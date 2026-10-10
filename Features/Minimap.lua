local _, ns = ...
local Options = ns.Options

-- The minimap's shape and what sits around it.
--   * Square: the map gets a square mask and a border (Forever's bronze, unwrapped from its round
--     frame onto a square, or a thin black line); the round frame goes to the hidden holder.
--     GetMinimapShape() then answers "SQUARE", the convention other addons (LibDBIcon's minimap
--     buttons, for one) read to place their buttons.
--   * Positions: the zone text, the clock, the addon compartment, the tracking button and Forever's
--     day and night icon can each move to a row above or below the minimap (left, center or right),
--     or be hidden; the tracking button and the day and night icon can also go inside the map, in
--     a corner or at the middle of the top or bottom edge. The calendar button can be hidden.
--     Things that share a spot sit side by side, the zone text gets the room left in the middle,
--     and the coordinates move under a row below. The zone text leaves the header bar, which then
--     goes to the hidden holder.
--   * Class colors for the zone text, the clock and the coordinates. The game colors the zone name
--     by its PvP status each time the zone changes; the class color is put back right after.
-- Only widget methods are called; the game's own minimap code is never called or hooked.
local MinimapLayout = {}
ns.MinimapLayout = MinimapLayout

local SQUARE, BORDER = "squareMinimap", "squareMinimapBorder"
local ZONE_TEXT, CLASS_COLOR = "minimapZoneText", "minimapZoneTextClassColor"
local CLOCK_COLOR, COORDS_COLOR = "minimapClockClassColor", "minimapCoordsClassColor"
local CALENDAR = "hideMinimapCalendar"

-- The choices for a moving element, in the order the settings list them (PositionsFor). "default"
-- leaves it where the game puts it.
MinimapLayout.POSITIONS = { "default", "topLeft", "top", "topRight", "bottomLeft", "bottom", "bottomRight", "hidden" }
-- Inside the map, offered for the small round buttons (elements marked inside).
MinimapLayout.INSIDE_POSITIONS = { "insideTopLeft", "insideTop", "insideTopRight", "insideBottomLeft", "insideBottom",
    "insideBottomRight" }
local SLOTS = {
    topLeft = { row = "top", side = "left" }, top = { row = "top", side = "center" },
    topRight = { row = "top", side = "right" }, bottomLeft = { row = "bottom", side = "left" },
    bottom = { row = "bottom", side = "center" }, bottomRight = { row = "bottom", side = "right" },
    insideTopLeft = { row = "top", side = "left", inside = true },
    insideTop = { row = "top", side = "center", inside = true },
    insideTopRight = { row = "top", side = "right", inside = true },
    insideBottomLeft = { row = "bottom", side = "left", inside = true },
    insideBottom = { row = "bottom", side = "center", inside = true },
    insideBottomRight = { row = "bottom", side = "right", inside = true },
}
-- The zone text only goes to the middle of a row: "above" or "below".
local ZONE_SLOTS = { above = "top", below = "bottom" }

-- The elements that move, in the order they sit side by side within a spot (the first one at the
-- minimap's edge for left and right, the first one on the left in the middle).
MinimapLayout.ELEMENTS = {
    { key = "minimapTracking", inside = true,
        frame = function() return MinimapCluster and MinimapCluster.Tracking end },
    { key = ZONE_TEXT, isZoneText = true,
        frame = function() return MinimapCluster and MinimapCluster.ZoneTextButton end },
    { key = "minimapClock", frame = function() return TimeManagerClockButton end },
    { key = "minimapCompartment", frame = function() return AddonCompartmentFrame end },
    -- Forever only: the day and night icon on the round frame.
    { key = "minimapDayNight", inside = true,
        frame = function() return MinimapCluster and MinimapCluster.DielFrame end },
}

local function elementFor(key)
    for _, element in ipairs(MinimapLayout.ELEMENTS) do
        if element.key == key then return element end
    end
    return nil
end

-- The positions an element can take, in the order the settings list them.
function MinimapLayout.PositionsFor(key)
    local element = elementFor(key)
    local list = {}
    for _, value in ipairs(MinimapLayout.POSITIONS) do
        if value == "hidden" and element and element.inside then
            for _, inside in ipairs(MinimapLayout.INSIDE_POSITIONS) do list[#list + 1] = inside end
        end
        list[#list + 1] = value
    end
    return list
end

local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
-- Forever's minimap skin masks the map with this atlas; other clients get the classic round mask.
local ROUND_MASK_ATLAS = "ui-hud-minimap-frame-generic-mask"
local ROUND_MASK_FILE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- Forever's bronze ring on a square (Media/MinimapSquareBorder.tga): the texture reaches this far
-- past the map's edges, the band itself about 6.5.
local BRONZE_BORDER = "Interface\\AddOns\\ForeverQoL\\Media\\MinimapSquareBorder"
local BRONZE_MARGIN = 9
local BLACK_SIZE = 2

-- How far past the map's edges what is drawn around it reaches, per shape: the rows sit just
-- outside. The round frame's north triangle reaches higher at the top.
local EDGES = {
    round = { side = 8, top = 24, bottom = 8 },
    bronze = { side = 7, top = 7, bottom = 7 },
    black = { side = BLACK_SIZE, top = BLACK_SIZE, bottom = BLACK_SIZE },
}
local ROW_GAP = 3       -- between the drawn edge and a row
local SPACING = 4       -- between elements side by side
local COORDS_GAP = 2    -- between a row below and the coordinates
local MIN_ZONE_WIDTH = 40
-- Inside the map: the share of the radius the round frame covers at the map's edge (Forever's
-- ring reaches 13 of the map's 198 texture pixels in), the gap to the drawn edge, and how far
-- above the map a button inside it is drawn.
local ROUND_COVER = 0.07
local INSIDE_GAP = 4
local INSIDE_LEVELS = 5

function MinimapLayout.RoundMask()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ROUND_MASK_ATLAS) then
        return ROUND_MASK_ATLAS
    end
    return ROUND_MASK_FILE
end

local function squareShape()
    return "SQUARE"
end

local function setHidden(hidden, ...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        -- A frame we never hid is left completely alone.
        if region and (hidden or ns.Hider:IsHidden(region)) then
            ns.Hider:SetHidden(region, hidden)
        end
    end
end

-- The round frame around the map: Forever and retail draw it with these two textures.
local function ringTextures()
    return MinimapCompassTexture, MinimapCompassTextureUnderlay
end

local function borderStyle()
    return Options:Get(BORDER) == "black" and "black" or "bronze"
end

------------------------------------------------------------------------------------------------
-- Shape

-- Our own frame on the minimap with both borders: four black bars just outside the edges, and the
-- bronze texture.
local border

local function createBorder()
    local frame = CreateFrame("Frame", nil, Minimap)
    frame:SetAllPoints(Minimap)
    local function bar()
        local texture = frame:CreateTexture(nil, "BORDER")
        texture:SetColorTexture(0, 0, 0, 1)
        return texture
    end
    local top, bottom, left, right = bar(), bar(), bar(), bar()
    top:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", -BLACK_SIZE, 0)
    top:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", BLACK_SIZE, 0)
    top:SetHeight(BLACK_SIZE)
    bottom:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", -BLACK_SIZE, 0)
    bottom:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", BLACK_SIZE, 0)
    bottom:SetHeight(BLACK_SIZE)
    left:SetPoint("TOPRIGHT", Minimap, "TOPLEFT")
    left:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT")
    left:SetWidth(BLACK_SIZE)
    right:SetPoint("TOPLEFT", Minimap, "TOPRIGHT")
    right:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMRIGHT")
    right:SetWidth(BLACK_SIZE)
    frame.black = { top, bottom, left, right }

    local bronze = frame:CreateTexture(nil, "ARTWORK")
    bronze:SetTexture(BRONZE_BORDER)
    bronze:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -BRONZE_MARGIN, BRONZE_MARGIN)
    bronze:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", BRONZE_MARGIN, -BRONZE_MARGIN)
    frame.bronze = bronze
    frame:Hide()
    return frame
end

local function showBorder(style)
    border = border or createBorder()
    for _, bar in ipairs(border.black) do bar:SetShown(style == "black") end
    border.bronze:SetShown(style == "bronze")
    border:Show()
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
        setHidden(true, ringTextures())
        showBorder(borderStyle())
        if not squared then
            previousShape = _G.GetMinimapShape
            _G.GetMinimapShape = squareShape
        end
        squared = true
    elseif squared then
        Minimap:SetMaskTexture(self.RoundMask())
        setHybridMask(ROUND_MASK_FILE)
        setHidden(false, ringTextures())
        border:Hide()
        if _G.GetMinimapShape == squareShape then
            _G.GetMinimapShape = previousShape
        end
        previousShape = nil
        squared = false
    end
end

------------------------------------------------------------------------------------------------
-- Positions

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

-- What each frame we moved looked like before (anchors, and the zone text's width and alignment).
local originals = {}

local function remember(frame, extra)
    if originals[frame] then return end
    local saved = { points = savePoints(frame), level = frame:GetFrameLevel() }
    if extra then extra(saved) end
    originals[frame] = saved
end

-- A button inside the map is drawn above it (the cluster's buttons sit below the map's level).
local function setInside(frame, inside)
    local level = originals[frame].level
    if inside then level = math.max(level, Minimap:GetFrameLevel() + INSIDE_LEVELS) end
    if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
end

local function putBack(frame, extra)
    local saved = originals[frame]
    if not saved then return end
    restorePoints(frame, saved.points)
    if frame:GetFrameLevel() ~= saved.level then frame:SetFrameLevel(saved.level) end
    if extra then extra(saved) end
    originals[frame] = nil
end

local function rememberZoneText(saved)
    saved.width = MinimapCluster.ZoneTextButton:GetWidth()
    saved.textWidth = MinimapZoneText:GetWidth()
    saved.justify = MinimapZoneText:GetJustifyH()
end

local function putBackZoneText(saved)
    MinimapCluster.ZoneTextButton:SetWidth(saved.width)
    MinimapZoneText:SetWidth(saved.textWidth)
    MinimapZoneText:SetJustifyH(saved.justify)
end

-- Where an element goes: "default", "hidden" or a row and side.
local function positionOf(element)
    local value = Options:Get(element.key)
    if element.isZoneText then
        local row = ZONE_SLOTS[value]
        return row and { row = row, side = "center" } or "default"
    end
    if value == "hidden" then return "hidden" end
    local slot = SLOTS[value]
    if slot and (element.inside or not slot.inside) then return slot end
    return "default"
end

-- An invisible frame of ours around what is drawn of the minimap; the rows sit just outside it.
local edgeFrame

local function edge()
    edgeFrame = edgeFrame or CreateFrame("Frame", nil, Minimap)
    local shape = Options:Get(SQUARE) and borderStyle() or "round"
    local insets = EDGES[shape]
    edgeFrame:ClearAllPoints()
    edgeFrame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -insets.side, insets.top)
    edgeFrame:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", insets.side, -insets.bottom)
    return edgeFrame, Minimap:GetWidth() + 2 * insets.side
end

-- Sizes in screen units, so frames of different scales (Edit Mode scales the minimap alone) line up.
local function screen(frame, size) return size * frame:GetEffectiveScale() end

local function widthOf(item)
    return item.width or screen(item.frame, item.frame:GetWidth())
end

local function sumWidths(list, skipZoneText)
    local total, count = 0, 0
    for _, item in ipairs(list) do
        if not (skipZoneText and item.element.isZoneText) then
            total, count = total + widthOf(item), count + 1
        end
    end
    return count > 0 and total + SPACING * (count - 1) or 0
end

-- Puts a row's elements in place; returns the row's height (screen units), 0 for an empty row.
local function layoutRow(row, which, anchor, edgeWidth)
    if #row.left + #row.center + #row.right == 0 then return 0 end
    local height = 0
    for _, side in pairs(row) do
        for _, item in ipairs(side) do
            height = math.max(height, screen(item.frame, item.frame:GetHeight()))
        end
    end

    -- The zone text gets the middle that the left and right groups leave free.
    local sides = math.max(sumWidths(row.left), sumWidths(row.right))
    local free = edgeWidth - (sides > 0 and 2 * (sides + SPACING) or 0)
    local others = sumWidths(row.center, true)
    for _, item in ipairs(row.center) do
        if item.element.isZoneText then
            item.width = math.max(MIN_ZONE_WIDTH, free - (others > 0 and others + SPACING or 0))
            local width = item.width / item.frame:GetEffectiveScale()
            item.frame:SetWidth(width)
            MinimapZoneText:SetWidth(width)
            MinimapZoneText:SetJustifyH("CENTER")
        end
    end

    local point = which == "top" and "TOP" or "BOTTOM"
    local y = which == "top" and ROW_GAP + height / 2 or -(ROW_GAP + height / 2)
    local function place(item, x)
        local scale = item.frame:GetEffectiveScale()
        item.frame:ClearAllPoints()
        item.frame:SetPoint("CENTER", anchor, point, x / scale, y / scale)
    end
    local cursor = -edgeWidth / 2
    for _, item in ipairs(row.left) do
        place(item, cursor + widthOf(item) / 2)
        cursor = cursor + widthOf(item) + SPACING
    end
    cursor = edgeWidth / 2
    for _, item in ipairs(row.right) do
        place(item, cursor - widthOf(item) / 2)
        cursor = cursor - widthOf(item) - SPACING
    end
    cursor = -sumWidths(row.center) / 2
    for _, item in ipairs(row.center) do
        place(item, cursor + widthOf(item) / 2)
        cursor = cursor + widthOf(item) + SPACING
    end
    return height
end

-- Puts the elements of a spot inside the map in place: in a corner (along the diagonal on a round
-- map), the first one nearest the corner and the others next to it towards the middle, or
-- centered at the top or bottom edge.
local function layoutInside(row, which)
    local mapScale = Minimap:GetEffectiveScale()
    local halfWidth = Minimap:GetWidth() * mapScale / 2
    local halfHeight = Minimap:GetHeight() * mapScale / 2
    local round = not Options:Get(SQUARE)
    local radius = halfHeight * (1 - ROUND_COVER)
    local up = which == "top" and 1 or -1
    local function place(item, x, y)
        local scale = item.frame:GetEffectiveScale()
        item.frame:ClearAllPoints()
        item.frame:SetPoint("CENTER", Minimap, "CENTER", x / scale, y / scale)
    end
    for side, items in pairs(row) do
        if #items > 0 then
            local height = 0
            for _, item in ipairs(items) do
                height = math.max(height, screen(item.frame, item.frame:GetHeight()))
            end
            if side == "center" then
                local y = up * ((round and radius or halfHeight) - INSIDE_GAP - height / 2)
                local cursor = -sumWidths(items) / 2
                for _, item in ipairs(items) do
                    place(item, cursor + widthOf(item) / 2, y)
                    cursor = cursor + widthOf(item) + SPACING
                end
            else
                local out = side == "left" and -1 or 1
                local first = widthOf(items[1])
                local x, y
                if round then
                    local distance = (radius - INSIDE_GAP - math.max(first, height) / 2) * math.sqrt(0.5)
                    x, y = out * distance, up * distance
                else
                    x = out * (halfWidth - INSIDE_GAP - first / 2)
                    y = up * (halfHeight - INSIDE_GAP - height / 2)
                end
                for i, item in ipairs(items) do
                    if i > 1 then x = x - out * (widthOf(items[i - 1]) / 2 + SPACING + widthOf(item) / 2) end
                    place(item, x, y)
                end
            end
        end
    end
end

local function newRows()
    return {
        top = { left = {}, center = {}, right = {} },
        bottom = { left = {}, center = {}, right = {} },
    }
end

function MinimapLayout:ApplyPositions()
    local cluster = MinimapCluster
    if not cluster then return end
    local rows, inside = newRows(), newRows()
    local zoneTextMoved = false
    for _, element in ipairs(self.ELEMENTS) do
        local frame = element.frame()
        if frame then
            local position = positionOf(element)
            setHidden(position == "hidden", frame)
            if type(position) == "table" then
                remember(frame, element.isZoneText and rememberZoneText or nil)
                setInside(frame, position.inside == true)
                local side = (position.inside and inside or rows)[position.row][position.side]
                side[#side + 1] = { element = element, frame = frame }
                zoneTextMoved = zoneTextMoved or element.isZoneText == true
            else
                putBack(frame, element.isZoneText and putBackZoneText or nil)
            end
        end
    end
    -- The header bar without its zone name has nothing left to frame.
    setHidden(zoneTextMoved, cluster.BorderTop)

    local anchor, edgeWidth = edge()
    edgeWidth = screen(Minimap, edgeWidth)
    layoutRow(rows.top, "top", anchor, edgeWidth)
    local below = layoutRow(rows.bottom, "bottom", anchor, edgeWidth)
    layoutInside(inside.top, "top")
    layoutInside(inside.bottom, "bottom")

    local container = cluster.MinimapContainer
    local coords = container and container.PlayerCoords
    if coords then
        if below > 0 then
            remember(coords)
            coords:ClearAllPoints()
            coords:SetPoint("TOP", anchor, "BOTTOM", 0, -(ROW_GAP + below + COORDS_GAP) / coords:GetEffectiveScale())
        else
            putBack(coords)
        end
    end

    setHidden(Options:Get(CALENDAR), GameTimeFrame)
end

function MinimapLayout:Apply()
    if not Minimap then return end
    self:ApplyShape()
    self:ApplyPositions()
end

------------------------------------------------------------------------------------------------
-- Class colors

local function coordsText()
    local container = MinimapCluster and MinimapCluster.MinimapContainer
    local coords = container and container.PlayerCoords
    return coords and coords.CoordText
end

-- The texts that can show in class color, with the option for each.
MinimapLayout.COLORED = {
    { key = CLASS_COLOR, text = function() return MinimapZoneText end },
    { key = CLOCK_COLOR, text = function() return TimeManagerClockTicker end },
    { key = COORDS_COLOR, text = coordsText },
}

local function classColor()
    local _, class = UnitClass("player")
    if not ns.IsUsable(class) or not RAID_CLASS_COLORS then return nil end
    return RAID_CLASS_COLORS[class]
end

local function isColor(color, r, g, b)
    local function near(a, c) return ns.IsUsable(a) and math.abs(a - c) < 0.01 end
    return near(r, color.r) and near(g, color.g) and near(b, color.b)
end

-- Per option: the color the text had (the zone text: the one the game last gave it) while we show
-- the class color instead.
local gameColors = {}

local function applyColor(key, text, color)
    local r, g, b = text:GetTextColor()
    local gameColor = gameColors[key]
    if Options:Get(key) and color then
        -- Anything but our own color is a new one from the game (a zone change) to go back to.
        if not isColor(color, r, g, b) then gameColors[key] = { r, g, b } end
        text:SetTextColor(color.r, color.g, color.b)
    elseif gameColor then
        if color and isColor(color, r, g, b) then
            text:SetTextColor(gameColor[1], gameColor[2], gameColor[3])
        end
        gameColors[key] = nil
    end
end

function MinimapLayout:ApplyColors()
    local color = classColor()
    for _, colored in ipairs(self.COLORED) do
        local text = colored.text()
        if text then applyColor(colored.key, text, color) end
    end
end

------------------------------------------------------------------------------------------------
-- Setup

-- Whether this client has Forever's day and night icon (the settings offer it only there).
function MinimapLayout.HasDayNight()
    return MinimapCluster ~= nil and type(MinimapCluster.DielFrame) == "table"
end

local LAYOUT_KEYS = { SQUARE, BORDER, CALENDAR }
for _, element in ipairs(MinimapLayout.ELEMENTS) do LAYOUT_KEYS[#LAYOUT_KEYS + 1] = element.key end

local function scheduleLayout()
    ns.Later("minimapLayout", function() MinimapLayout:Apply() end)
end

-- A color is allowed in combat, so a zone change in combat gets the class color at once.
local function scheduleColor()
    ns.Later("minimapColors", function() MinimapLayout:ApplyColors() end, true)
end

local COLOR_KEYS = {}
for _, colored in ipairs(MinimapLayout.COLORED) do COLOR_KEYS[#COLOR_KEYS + 1] = colored.key end

local function colorActive()
    if next(gameColors) ~= nil then return true end
    for _, key in ipairs(COLOR_KEYS) do
        if Options:Get(key) then return true end
    end
    return false
end

local function layoutActive()
    if Options:Get(SQUARE) or next(originals) ~= nil then return true end
    for _, key in ipairs(LAYOUT_KEYS) do
        local value = Options:Get(key)
        if value ~= Options:GetDefault(key) then return true end
    end
    return false
end

function MinimapLayout:Init()
    Options:Watch(LAYOUT_KEYS, scheduleLayout)
    Options:Watch(COLOR_KEYS, scheduleColor)

    local function relayout()
        if layoutActive() then scheduleLayout() end
    end
    local function recolor()
        if colorActive() then scheduleColor() end
    end
    -- Forever's minimap skin masks the map again when the rotate setting changes, and the hybrid
    -- minimap brings its own round mask when it loads. The clock loads on demand.
    ns.Events:On("CVAR_UPDATE", function(_, name)
        if name == "rotateMinimap" then relayout() end
    end)
    ns.Events:On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_HybridMinimap" or name == "Blizzard_TimeManager" then relayout() end
        if name == "Blizzard_TimeManager" then recolor() end
    end)
    -- Edit Mode resizes the minimap, and Forever's skin puts the day and night icon back in place
    -- whenever the minimap's scale is set.
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Exit", relayout, MinimapLayout)
        EventRegistry:RegisterCallback("Minimap.OnScaleUpdated", relayout, MinimapLayout)
    end

    -- The game sets the zone text's color again on these.
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
        "ZONE_CHANGED_NEW_AREA", "SETTINGS_LOADED" }) do
        ns.Events:On(event, recolor)
    end

    relayout()
    recolor()
end
