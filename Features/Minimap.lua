local _, ns = ...
local L = ns.L
local Options = ns.Options

-- The minimap's shape and what sits around it.
--   * Square: the map gets a square mask and a border (Forever's bronze, unwrapped from its round
--     frame onto a square, or a thin black line); the round frame goes to the hidden holder.
--     GetMinimapShape() then answers "SQUARE", the convention other addons read to place their
--     minimap buttons.
--   * Positions: the zone text, the clock, the addon compartment, the tracking button and Forever's
--     day and night icon can each move to a row above or below the minimap (left, center or right;
--     the zone text only the center), or be hidden; the zone text, the tracking button and the day
--     and night icon can also go inside the map, in a corner (not the zone text) or at the middle of
--     the top or bottom edge. The calendar button and the coordinates stay at the game's spot or are
--     hidden. Things that share a spot sit side by side, the zone text gets the room left in the
--     middle, and the coordinates move under a row below. Away from its default spot the zone text
--     leaves the header bar, which then goes to the hidden holder; at its default spot the header
--     bar can go too.
--   * Class colors for the zone text, the clock and the coordinates. The game colors the zone name
--     by its PvP status each time the zone changes; the class color is put back right after.
--   * Font sizes for the zone text, the clock, the coordinates and the FPS and ping. Their frames
--     grow with a larger font, so the rows around the minimap make room for them.
--   * FPS and ping: a text of ours with the frame rate, the ping or both, placed in the rows like
--     the clock, also in class color and at another font size.
--   * Offsets: each of these can shift a little from its spot, the coordinates too.
-- Classic Era names some of these differently (see its frames below).
-- Only widget methods are called; the game's own minimap code is never called or hooked.
local MinimapLayout = {}
ns.MinimapLayout = MinimapLayout

local SQUARE, BORDER = "squareMinimap", "squareMinimapBorder"
local ZONE_TEXT, CLASS_COLOR = "minimapZoneText", "minimapZoneTextClassColor"
local CLOCK_COLOR, COORDS_COLOR = "minimapClockClassColor", "minimapCoordsClassColor"
local CALENDAR, ZONE_TEXT_FRAME = "minimapCalendar", "hideMinimapZoneTextFrame"
local ZONE_TEXT_SIZE, CLOCK_SIZE = "minimapZoneTextSize", "minimapClockSize"
local PERFORMANCE, PERFORMANCE_COLOR = "minimapPerformance", "minimapPerformanceClassColor"
local PERFORMANCE_SIZE, PERFORMANCE_SHOW = "minimapPerformanceSize", "minimapPerformanceShow"
-- The coordinates' Position, which their offset and size options start with too.
local COORDS, COORDS_SIZE = "minimapCoords", "minimapCoordsSize"

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

-- A frame the cluster holds, or nil where this client has none (Classic Era's cluster lacks them).
local function clusterFrame(key)
    local frame = MinimapCluster and MinimapCluster[key]
    return type(frame) == "table" and frame or nil
end

-- The player's coordinates under the minimap, or nil where this client has none (Classic Era,
-- retail).
local function coordsFrame()
    local container = clusterFrame("MinimapContainer")
    local coords = container and container.PlayerCoords
    return type(coords) == "table" and coords or nil
end

local function coordsText()
    local coords = coordsFrame()
    return coords and coords.CoordText
end

-- Classic Era has no calendar: its GameTimeFrame is the time of day icon on the round border,
-- which the day and night option moves. Elsewhere it is the calendar button.
local function hasCalendar()
    return ToggleCalendar ~= nil and GameTimeFrame ~= nil
end

local function dayNightFrame()
    -- Without a calendar, GameTimeFrame is the time of day icon.
    return clusterFrame("DielFrame") or (ToggleCalendar == nil and GameTimeFrame or nil)
end

-- The elements that move, in the order they sit side by side within a spot (the first one at the
-- minimap's edge for left and right, the first one on the left in the middle). parts: what an
-- offset moves at the game's own place instead of the frame, where the game anchors other frames
-- to it (the zone text's button holds the clock, the calendar and the mail icon, Retail's tracking
-- frame the mail icon).
MinimapLayout.ELEMENTS = {
    { key = "minimapTracking", inside = true,
        frame = function() return clusterFrame("Tracking") or MiniMapTracking end,
        parts = function()
            local tracking = clusterFrame("Tracking")
            return tracking and { tracking.Button, tracking.Background } or nil
        end },
    -- A long name has no room at the sides of a row or in a corner: only the middle spots.
    { key = ZONE_TEXT, isZoneText = true, inside = true, centerOnly = true,
        frame = function() return MinimapCluster and MinimapCluster.ZoneTextButton end,
        parts = function() return { MinimapZoneText } end },
    { key = "minimapClock", frame = function() return TimeManagerClockButton end },
    -- Our own FPS and ping text (see below): the game has no place for it, so it has no default,
    -- and its text keeps to the side of the row it's on.
    { key = PERFORMANCE, own = true,
        frame = function() return MinimapLayout:Performance() end,
        align = function(frame, side) MinimapLayout.AlignPerformance(frame, side) end },
    { key = "minimapCompartment", frame = function() return AddonCompartmentFrame end },
    -- Forever's day and night icon on the round frame, Classic Era's time of day icon.
    { key = "minimapDayNight", inside = true, frame = dayNightFrame },
}

-- Whether an element can take a spot: inside the map only one marked inside, and only the middle
-- spots for one marked centerOnly.
local function fits(element, slot)
    return (element.inside or not slot.inside) and not (element.centerOnly and slot.side ~= "center")
end

local function elementFor(key)
    for _, element in ipairs(MinimapLayout.ELEMENTS) do
        if element.key == key then return element end
    end
    return nil
end

-- The elements that stay at the game's spot unless hidden: the coordinates and the calendar button.
local AT_GAME_SPOT = { [COORDS] = true, [CALENDAR] = true }

-- The positions an element can take, in the order the settings list them.
function MinimapLayout.PositionsFor(key)
    if AT_GAME_SPOT[key] then return { "default", "hidden" } end
    local element = elementFor(key)
    local list = {}
    local function add(value)
        if element and SLOTS[value] and not fits(element, SLOTS[value]) then return end
        list[#list + 1] = value
    end
    for _, value in ipairs(MinimapLayout.POSITIONS) do
        if value == "hidden" and element and element.inside then
            for _, inside in ipairs(MinimapLayout.INSIDE_POSITIONS) do add(inside) end
        end
        if not (value == "default" and element and element.own) then add(value) end
    end
    return list
end

local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
-- Forever's minimap skin masks the map with this atlas; other clients get the classic round mask.
local ROUND_MASK_ATLAS = "ui-hud-minimap-frame-generic-mask"
local ROUND_MASK_FILE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- Forever's bronze ring on a square (Media/MinimapSquareBorder.tga): the texture reaches this far
-- past the map's edges, the band itself about 6.5.
local BRONZE_BORDER = "Interface\\AddOns\\QoL\\Media\\MinimapSquareBorder"
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
-- On a round map the zone text inside moves in from the edge until the circle is this share of
-- the map's width across (docs/dev/minimap.md).
local ROUND_ZONE_WIDTH = 0.6

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

-- The round frame around the map: Forever and retail draw it with the two compass textures,
-- Classic Era with MinimapBorder (its compass ring shows only while the map rotates).
local function ringTextures()
    return MinimapCompassTexture, MinimapCompassTextureUnderlay, MinimapBorder
end

-- The zone text's frame: before Forever 1.60.1 the header bar BorderTop, since then the zone text
-- button's own frame and mouse-over glow.
local function zoneTextFrame(cluster)
    local button = cluster.ZoneTextButton
    return cluster.BorderTop, button and button.StateTexture, button and button.AddTexture
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

-- Whether the map is square because of us, whether GetMinimapShape says so, and the one we replaced.
local squared = false
local shapeAnswered = false
local previousShape

local function answerShape(square)
    if square and not shapeAnswered then
        previousShape = _G.GetMinimapShape
        _G.GetMinimapShape = squareShape
        shapeAnswered = true
    elseif not square and shapeAnswered then
        if _G.GetMinimapShape == squareShape then
            _G.GetMinimapShape = previousShape
        end
        previousShape = nil
        shapeAnswered = false
    end
end

-- Before login: LibDBIcon places its buttons on PLAYER_LOGIN by what GetMinimapShape answers then,
-- and the layout runs after that. Only a global of ours is set, no Blizzard frame is touched.
function MinimapLayout:ProvideShape()
    answerShape(Options:Get(SQUARE))
end

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
        answerShape(true)
        squared = true
    elseif squared then
        Minimap:SetMaskTexture(self.RoundMask())
        setHybridMask(ROUND_MASK_FILE)
        setHidden(false, ringTextures())
        border:Hide()
        answerShape(false)
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

-- An anchor's offset, 0 if it isn't one we can compute with.
local function anchorOffset(value)
    return ns.IsUsable(value) and value or 0
end

-- dx, dy (optional): a shift on top, in the frame's own units.
local function restorePoints(frame, points, dx, dy)
    frame:ClearAllPoints()
    for _, p in ipairs(points) do
        if dx then
            frame:SetPoint(p[1], p[2], p[3], anchorOffset(p[4]) + dx, anchorOffset(p[5]) + dy)
        else
            frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
        end
    end
end

local POINT_TOLERANCE = 0.01

local function samePoints(a, b)
    if #a ~= #b then return false end
    for i, p in ipairs(a) do
        local q = b[i]
        if p[1] ~= q[1] or p[2] ~= q[2] or p[3] ~= q[3]
            or math.abs(anchorOffset(p[4]) - anchorOffset(q[4])) > POINT_TOLERANCE
            or math.abs(anchorOffset(p[5]) - anchorOffset(q[5])) > POINT_TOLERANCE then
            return false
        end
    end
    return true
end

-- What each frame we moved looked like before (anchors, and the zone text's width and alignment),
-- and in placed the anchors the last layout left it with. Font strings and textures have no level.
local originals = {}

local function remember(frame, extra)
    if originals[frame] then return end
    local points = savePoints(frame)
    -- A texture with no anchors in the game's XML fills its parent.
    if #points == 0 then
        local parent = frame:GetParent()
        points = { { "TOPLEFT", parent, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0 } }
    end
    local saved = { points = points, level = frame.GetFrameLevel and frame:GetFrameLevel() }
    if extra then extra(saved) end
    originals[frame] = saved
end

-- The game can anchor a frame anew while we hold it (Edit Mode's "Header underneath", Forever's day
-- and night icon on every minimap scale). Anchors that aren't the ones we left are the game's new
-- originals, or a shift or going back would use an old place.
local function followGame()
    for frame, saved in pairs(originals) do
        local points = savePoints(frame)
        if saved.placed and not samePoints(points, saved.placed) then saved.points = points end
    end
end

local function notePlaced()
    for frame, saved in pairs(originals) do saved.placed = savePoints(frame) end
end

-- A button inside the map is drawn above it (the cluster's buttons sit below the map's level).
local function setInside(frame, inside)
    local level = originals[frame].level
    if not level then return end
    if inside then level = math.max(level, Minimap:GetFrameLevel() + INSIDE_LEVELS) end
    if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
end

local function putBack(frame, extra)
    local saved = originals[frame]
    if not saved then return end
    restorePoints(frame, saved.points)
    if saved.level and frame:GetFrameLevel() ~= saved.level then frame:SetFrameLevel(saved.level) end
    if extra then extra(saved) end
    originals[frame] = nil
end

-- At the game's own place: its anchors, moved by dx, dy (screen units at this scale). A frame with
-- no offset goes back, and one we never held isn't touched at all.
local function shift(frame, dx, dy, scale, extra)
    if dx == 0 and dy == 0 then return putBack(frame, extra) end
    remember(frame, extra)
    restorePoints(frame, originals[frame].points, dx / scale, dy / scale)
    setInside(frame, false)
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

-- Where an element goes: "default", "hidden" or a row and side. One of our own is hidden unless
-- it has a row.
local function positionOf(element)
    local value = Options:Get(element.key)
    if value == "hidden" then return "hidden" end
    local slot = SLOTS[value]
    if slot and fits(element, slot) then return slot end
    return element.own and "hidden" or "default"
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

-- The largest offset either way; Position is what moves something far.
MinimapLayout.MAX_OFFSET = 30

-- The two options of an offset: an element's key, or COORDS for the coordinates.
function MinimapLayout.OffsetKeys(key)
    return key .. "OffsetX", key .. "OffsetY"
end

-- An offset, in screen units.
local function offsetOf(key)
    local x, y = MinimapLayout.OffsetKeys(key)
    return Options:Get(x), Options:Get(y)
end

-- Puts a row's or the map's element at x, y (screen units) from a point of relativeTo. The layouts
-- work out places and widths without the offsets, so neighbors don't make room for a shifted element.
local function placeItem(item, relativeTo, point, x, y)
    local scale = item.frame:GetEffectiveScale()
    local dx, dy = offsetOf(item.element.key)
    item.frame:ClearAllPoints()
    item.frame:SetPoint("CENTER", relativeTo, point, (x + dx) / scale, (y + dy) / scale)
end

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

-- Gives the zone text among the items of a middle spot the room the others leave of free (screen
-- units), its name centered; the game cuts off a name still too long with "...".
local function fitZoneText(items, free)
    local others = sumWidths(items, true)
    for _, item in ipairs(items) do
        if item.element.isZoneText then
            item.width = math.max(MIN_ZONE_WIDTH, free - (others > 0 and others + SPACING or 0))
            local width = item.width / item.frame:GetEffectiveScale()
            item.frame:SetWidth(width)
            MinimapZoneText:SetWidth(width)
            MinimapZoneText:SetJustifyH("CENTER")
        end
    end
end

local function hasZoneText(items)
    for _, item in ipairs(items) do
        if item.element.isZoneText then return true end
    end
    return false
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
    fitZoneText(row.center, edgeWidth - (sides > 0 and 2 * (sides + SPACING) or 0))

    local point = which == "top" and "TOP" or "BOTTOM"
    local y = which == "top" and ROW_GAP + height / 2 or -(ROW_GAP + height / 2)
    local function place(item, x) placeItem(item, anchor, point, x, y) end
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
    local function place(item, x, y) placeItem(item, Minimap, "CENTER", x, y) end
    for side, items in pairs(row) do
        if #items > 0 then
            local height = 0
            for _, item in ipairs(items) do
                height = math.max(height, screen(item.frame, item.frame:GetHeight()))
            end
            if side == "center" then
                -- How far from the center the spot's outer edge is.
                local outer = (round and radius or halfHeight) - INSIDE_GAP
                if hasZoneText(items) then
                    local free = 2 * (halfWidth - INSIDE_GAP)
                    if round then
                        -- The circle's width at the outer edge, and further in where that is too
                        -- narrow for a name (at Forever's top edge only about 54 across).
                        free = 2 * math.sqrt(math.max(0, radius * radius - outer * outer))
                        local least = ROUND_ZONE_WIDTH * 2 * halfWidth
                        if free < least then
                            free = least
                            outer = math.sqrt(math.max(0, radius * radius - (least / 2) ^ 2))
                        end
                    end
                    fitZoneText(items, free)
                end
                local y = up * (outer - height / 2)
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
    followGame()
    local rows, inside = newRows(), newRows()
    local zoneTextMoved = false
    for _, element in ipairs(self.ELEMENTS) do
        local frame = element.frame()
        if frame then
            local position = positionOf(element)
            setHidden(position == "hidden", frame)
            if element.isZoneText then zoneTextMoved = position ~= "default" end
            -- The offset at the game's own place; anywhere else what it moved goes back.
            local dx, dy = 0, 0
            if position == "default" then dx, dy = offsetOf(element.key) end
            local parts = element.parts and element.parts()
            local scale = frame:GetEffectiveScale()
            for _, part in ipairs(parts or {}) do shift(part, dx, dy, scale) end
            if type(position) == "table" then
                remember(frame, element.isZoneText and rememberZoneText or nil)
                setInside(frame, position.inside == true)
                if element.align then element.align(frame, position.side) end
                local side = (position.inside and inside or rows)[position.row][position.side]
                side[#side + 1] = { element = element, frame = frame }
            elseif parts then
                putBack(frame, element.isZoneText and putBackZoneText or nil)
            else
                shift(frame, dx, dy, scale)
            end
        end
    end
    -- The header bar without its zone name (moved or hidden) has nothing left to frame, and at the
    -- default spot the player may want the bare name.
    setHidden(zoneTextMoved or Options:Get(ZONE_TEXT_FRAME), zoneTextFrame(cluster))

    local anchor, edgeWidth = edge()
    edgeWidth = screen(Minimap, edgeWidth)
    layoutRow(rows.top, "top", anchor, edgeWidth)
    local below = layoutRow(rows.bottom, "bottom", anchor, edgeWidth)
    layoutInside(inside.top, "top")
    layoutInside(inside.bottom, "bottom")

    local coords = coordsFrame()
    if coords then
        setHidden(Options:Get(COORDS) == "hidden", coords)
        local scale = coords:GetEffectiveScale()
        local dx, dy = offsetOf(COORDS)
        if below > 0 then
            remember(coords)
            coords:ClearAllPoints()
            coords:SetPoint("TOP", anchor, "BOTTOM", dx / scale, (dy - (ROW_GAP + below + COORDS_GAP)) / scale)
        else
            shift(coords, dx, dy, scale)
        end
    end

    if hasCalendar() then setHidden(Options:Get(CALENDAR) == "hidden", GameTimeFrame) end
    notePlaced()
end

------------------------------------------------------------------------------------------------
-- Font sizes

-- The font sizes the settings offer; 0 is the game's own.
MinimapLayout.FONT_SIZES = { 0, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24 }

-- The texts whose font size can change, each with the frame around it. The frame grows with a
-- larger font (the clock's button and the FPS and ping in both directions, the zone text's button
-- only in height: the rows give it its width). The zone text's font string has a height of its own,
-- which grows too: a font string shows nothing of a line that doesn't fit its height. The FPS and
-- ping is made here when it has a row, so it's sized before it's placed.
MinimapLayout.SIZED = {
    { key = ZONE_TEXT_SIZE, textHeight = true,
        text = function() return MinimapZoneText end,
        frame = function() return MinimapCluster and MinimapCluster.ZoneTextButton end },
    { key = CLOCK_SIZE, frameWidth = true,
        text = function() return TimeManagerClockTicker end,
        frame = function() return TimeManagerClockButton end },
    -- The text fills its frame (setAllPoints), so it grows with it.
    { key = COORDS_SIZE, frameWidth = true, text = coordsText, frame = coordsFrame },
    { key = PERFORMANCE_SIZE, frameWidth = true,
        text = function()
            local frame = MinimapLayout:Performance()
            return frame and frame.text
        end,
        frame = function() return MinimapLayout:Performance() end },
}

-- Per option: the text's font and the sizes that grow with it, from before we changed them.
local gameFonts = {}

local function applySize(sized)
    local text, frame = sized.text(), sized.frame()
    if not (text and frame) then return end
    local size = Options:Get(sized.key)
    local saved = gameFonts[sized.key]
    if size > 0 then
        if not saved then
            local file, height, flags = text:GetFont()
            if not (file and ns.IsUsable(height) and height > 0) then return end
            saved = { object = text:GetFontObject(), file = file, height = height, flags = flags,
                textHeight = text:GetHeight(), frameWidth = frame:GetWidth(), frameHeight = frame:GetHeight() }
            gameFonts[sized.key] = saved
        end
        text:SetFont(saved.file, size, saved.flags)
        -- A smaller font keeps the button's size, so it stays as easy to click.
        local grow = math.max(1, size / saved.height)
        frame:SetHeight(saved.frameHeight * grow)
        if sized.frameWidth then frame:SetWidth(saved.frameWidth * grow) end
        if sized.textHeight then text:SetHeight(saved.textHeight * grow) end
    elseif saved then
        -- The text still has its font object after SetFont, and the client ignores the one a text
        -- already has: only SetFont brings the game's font back.
        text:SetFont(saved.file, saved.height, saved.flags)
        if saved.object then text:SetFontObject(saved.object) end
        frame:SetHeight(saved.frameHeight)
        if sized.frameWidth then frame:SetWidth(saved.frameWidth) end
        if sized.textHeight then text:SetHeight(saved.textHeight) end
        gameFonts[sized.key] = nil
    end
end

function MinimapLayout:ApplySizes()
    for _, sized in ipairs(self.SIZED) do applySize(sized) end
end

function MinimapLayout:Apply()
    if not Minimap then return end
    self:ApplyShape()
    -- Before the positions: they go by the buttons' sizes.
    self:ApplySizes()
    self:ApplyPositions()
end

------------------------------------------------------------------------------------------------
-- FPS and ping

-- A frame of ours with the frame rate, the ping (the higher of home and world latency, as the
-- game's own latency meter goes by) or both, made the first time it has a row. A timer updates it
-- once a second while it has one; no OnUpdate runs every frame for it. It keeps the width of a
-- three-digit reading of what it shows, so nothing in its row moves as the numbers change, and its
-- text keeps to its side.
local PERFORMANCE_SECONDS = 1
local PERFORMANCE_HEIGHT = 16 -- the clock button's, so either sits alike in a row
local performance
local ticker
local measuredShow -- the Show choice the frame's width was measured for

local function performanceShown()
    return type(positionOf(elementFor(PERFORMANCE))) == "table"
end

local function setReading(fps, ping)
    local show = Options:Get(PERFORMANCE_SHOW)
    if show == "fps" then
        performance.text:SetFormattedText(L.MINIMAP_PERFORMANCE_FPS, fps)
    elseif show == "ping" then
        performance.text:SetFormattedText(L.MINIMAP_PERFORMANCE_PING, ping)
    else
        performance.text:SetFormattedText(L.MINIMAP_PERFORMANCE_TEXT, fps, ping)
    end
end

local function updatePerformance()
    local fps = GetFramerate()
    local _, _, home, world = GetNetStats()
    fps = ns.IsUsable(fps) and math.floor(fps + 0.5) or 0
    local ping = (ns.IsUsable(home) and ns.IsUsable(world)) and math.max(home, world) or 0
    setReading(fps, ping)
end

-- Measures the frame for the Show choice, once per change. The text may be at a font size of ours:
-- applySize grows the width from what it is at the game's font, which it then gets from here.
local function fitPerformance()
    local show = Options:Get(PERFORMANCE_SHOW)
    if show == measuredShow then return end
    measuredShow = show
    setReading(999, 999)
    local width = performance.text:GetStringWidth()
    local saved = gameFonts[PERFORMANCE_SIZE]
    if saved then
        local _, height = performance.text:GetFont()
        saved.frameWidth = ns.IsUsable(height) and width * saved.height / height or width
    else
        performance:SetWidth(width)
    end
    updatePerformance()
end

local function tick()
    if not performanceShown() then
        ticker:Cancel()
        ticker = nil
        return
    end
    updatePerformance()
end

function MinimapLayout:Performance()
    local shown = performanceShown()
    if not (performance or shown) then return nil end
    if not performance then
        performance = CreateFrame("Frame", nil, MinimapCluster)
        local text = performance:CreateFontString(nil, "ARTWORK", "WhiteNormalNumberFont")
        performance:SetHeight(PERFORMANCE_HEIGHT)
        performance.text = text
        -- The colors may have been applied before it was there.
        self:ApplyColors()
    end
    fitPerformance()
    if shown and not ticker then
        updatePerformance()
        ticker = C_Timer.NewTicker(PERFORMANCE_SECONDS, tick)
    end
    return performance
end

function MinimapLayout.AlignPerformance(frame, side)
    local point = side == "left" and "LEFT" or side == "right" and "RIGHT" or "CENTER"
    frame.text:ClearAllPoints()
    frame.text:SetPoint(point)
end

------------------------------------------------------------------------------------------------
-- Class colors

-- The texts that can show in class color, with the option for each.
MinimapLayout.COLORED = {
    { key = CLASS_COLOR, text = function() return MinimapZoneText end },
    { key = CLOCK_COLOR, text = function() return TimeManagerClockTicker end },
    { key = COORDS_COLOR, text = coordsText },
    { key = PERFORMANCE_COLOR, text = function() return performance and performance.text end },
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

-- Whether this client has the addon compartment (Classic Era doesn't).
function MinimapLayout.HasCompartment()
    return AddonCompartmentFrame ~= nil
end

-- Whether this client shows the player's coordinates under the minimap (Classic Era doesn't).
function MinimapLayout.HasCoords()
    return coordsFrame() ~= nil
end

-- Whether this client has a day and night icon: Forever's, or Classic Era's time of day icon.
function MinimapLayout.HasDayNight()
    return dayNightFrame() ~= nil
end

-- Whether this client has the calendar button (Classic Era doesn't).
function MinimapLayout.HasCalendar()
    return hasCalendar()
end

local LAYOUT_KEYS = { SQUARE, BORDER, CALENDAR, COORDS, ZONE_TEXT_FRAME, ZONE_TEXT_SIZE, CLOCK_SIZE, COORDS_SIZE,
    PERFORMANCE_SIZE, PERFORMANCE_SHOW }
local function addOffsetKeys(key)
    local x, y = MinimapLayout.OffsetKeys(key)
    LAYOUT_KEYS[#LAYOUT_KEYS + 1] = x
    LAYOUT_KEYS[#LAYOUT_KEYS + 1] = y
end
for _, element in ipairs(MinimapLayout.ELEMENTS) do
    LAYOUT_KEYS[#LAYOUT_KEYS + 1] = element.key
    addOffsetKeys(element.key)
end
addOffsetKeys(COORDS)

local function apply()
    MinimapLayout:Apply()
end

local function scheduleLayout()
    ns.Later("minimapLayout", apply)
end

local function applyColors()
    MinimapLayout:ApplyColors()
end

-- A color is allowed in combat, so a zone change in combat gets the class color at once.
local function scheduleColor()
    ns.Later("minimapColors", applyColors, true)
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
    if Options:Get(SQUARE) or next(originals) ~= nil or next(gameFonts) ~= nil then return true end
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
    -- A layout can also change outside Edit Mode (a spec with its own), with "Header underneath".
    ns.Events:On("EDIT_MODE_LAYOUTS_UPDATED", relayout)
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
