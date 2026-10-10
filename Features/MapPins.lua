local _, ns = ...
local L = ns.L
local Options = ns.Options

-- Dungeon and raid entrances, and boats, zeppelins, portals and the tram, on the world map: on the
-- zone map they're in and on its continent (the places are in Data/MapPins.lua). The mouseover
-- names the dungeon, or where the boat goes; a click on a boat, zeppelin, portal or tram opens the
-- map of where it goes.
--
-- A MapCanvas data provider of our own, the map's extension point for addons (the map calls its
-- providers each in a secure call of its own). The pins are our own buttons on our own frame on the
-- map's canvas; the map's pin pools stay untouched. The only call into the map's code is SetMapID,
-- from a click on one of our pins, as a click on a zone would. Nothing is added to the map before
-- the player turns one of the options on.
local MapPins = {}
ns.MapPins = MapPins

local DUNGEONS, TRAVEL = "mapDungeons", "mapTravel"
local CONTINENT = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2

-- How each type looks (an atlas of the client and the size on screen), and which option shows it.
MapPins.STYLES = {
    dungeon = { atlas = "dungeon", size = 24, option = DUNGEONS, label = "MAP_DUNGEON" },
    raid = { atlas = "raid", size = 24, option = DUNGEONS, label = "MAP_RAID" },
    boat = { atlas = "flightmasterferry", size = 20, option = TRAVEL, label = "MAP_BOAT" },
    zeppelin = { atlas = "flightmasterferry", size = 20, option = TRAVEL, label = "MAP_ZEPPELIN" },
    portal = { atlas = "mageportalalliance", size = 20, option = TRAVEL, label = "MAP_PORTAL" },
    tram = { atlas = "portalpurple", size = 20, option = TRAVEL, label = "MAP_TRAM" },
}

local function mapInfo(mapID)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return type(info) == "table" and info or nil
end

local function mapName(mapID)
    local info = mapInfo(mapID)
    return info and info.name or nil
end

local function areaName(areaID)
    local name = areaID and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(areaID)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

-- Where a pin is on a continent: its place on the zone, put into the zone's rectangle there.
local function onParent(pin, parentID)
    local left, right, top, bottom = C_Map.GetMapRectOnMap(pin.map, parentID)
    if not (left and right and top and bottom) then return nil end
    return left + (right - left) * pin.x / 100, top + (bottom - top) * pin.y / 100
end

-- The pins of a map with their places (0 to 1), worked out once per map.
local placesByMap = {}

function MapPins.PlacesOn(mapID)
    local places = placesByMap[mapID]
    if places then return places end
    places = {}
    local info = mapInfo(mapID)
    local isContinent = info and info.mapType == CONTINENT
    for _, pin in ipairs(ns.MapPinData) do
        if pin.map == mapID then
            places[#places + 1] = { pin = pin, x = pin.x / 100, y = pin.y / 100 }
        end
        for _, other in ipairs(pin.also or {}) do
            if other.map == mapID then
                places[#places + 1] = { pin = pin, x = other.x / 100, y = other.y / 100 }
            end
        end
        if isContinent then
            local zone = mapInfo(pin.map)
            if zone and zone.parentMapID == mapID and C_Map.GetMapRectOnMap then
                local x, y = onParent(pin, mapID)
                if x then places[#places + 1] = { pin = pin, x = x, y = y } end
            end
        end
    end
    placesByMap[mapID] = places
    return places
end

------------------------------------------------------------------------------------------------
-- Tooltips and clicks

local NAME_COLOR = { 1, 1, 1 }
local LABEL_COLOR = { 0.6, 0.6, 0.6 }
local HINT_COLOR = { 0.25, 1, 0.25 }

-- "Theramore Isle (Dustwallow Marsh)": the stop, and the zone it's in when that's another name.
function MapPins.DestinationName(destination)
    local zone = mapName(destination.map)
    local area = areaName(destination.area)
    if area and zone and area ~= zone then
        return L.MAP_PLACE_IN_ZONE:format(area, zone)
    end
    return area or zone or "?"
end

-- The map a click opens, unless it is the one already shown (the ferry to Feathermoon stays in
-- Feralas).
local function clickTarget(button)
    local destination = button.pin.to and button.pin.to[1]
    local map = MapPins.map
    if destination and map and map:GetMapID() ~= destination.map then
        return destination.map
    end
    return nil
end

local function showTooltip(button)
    local pin, style = button.pin, MapPins.STYLES[button.pin.type]
    if not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if pin.areas then
        for i, area in ipairs(pin.areas) do
            local name = areaName(area) or "?"
            if i == 1 then
                GameTooltip:SetText(name)
            else
                GameTooltip:AddLine(name, NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3])
            end
        end
        GameTooltip:AddLine(L[style.label], LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3])
    else
        GameTooltip:SetText(L[style.label])
        for _, destination in ipairs(pin.to or {}) do
            GameTooltip:AddLine(MapPins.DestinationName(destination), NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3])
        end
        local target = clickTarget(button)
        if target then
            GameTooltip:AddLine(L.MAP_CLICK_TO_OPEN:format(mapName(target) or "?"),
                HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
        end
    end
    GameTooltip:Show()
end

local function hideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

local function onClick(button)
    local target = clickTarget(button)
    if not target then return end
    hideTooltip()
    MapPins.map:SetMapID(target)
end

------------------------------------------------------------------------------------------------
-- Drawing

-- buttons: pooled pins, used of them shown.
local view = { buttons = {}, used = 0 }
MapPins.view = view

local function clear()
    for i = 1, view.used do
        view.buttons[i]:Hide()
    end
    view.used = 0
end

-- At the default map's own level for dungeon entrances.
local function ensureFrame(map)
    if view.frame then return end
    local canvas = map:GetCanvas()
    local frame = CreateFrame("Frame", nil, canvas)
    frame:SetAllPoints(canvas)
    local levels = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
    local level = levels and levels.GetValidFrameLevel and levels:GetValidFrameLevel("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")
    frame:SetFrameLevel(type(level) == "number" and level or canvas:GetFrameLevel() + 2)
    view.frame = frame
end

-- Pins keep their size on screen at every zoom.
local function sizeButton(button)
    local size = MapPins.STYLES[button.pin.type].size / (view.scale or 1)
    button:SetSize(size, size)
end

local function acquire()
    view.used = view.used + 1
    local button = view.buttons[view.used]
    if not button then
        button = CreateFrame("Button", nil, view.frame)
        button.icon = button:CreateTexture(nil, "OVERLAY")
        button.icon:SetAllPoints()
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnEnter", showTooltip)
        button:SetScript("OnLeave", hideTooltip)
        button:SetScript("OnClick", onClick)
        view.buttons[view.used] = button
    end
    return button
end

local function shown(pin)
    local style = MapPins.STYLES[pin.type]
    return style ~= nil and Options:Get(style.option) == true
end

function MapPins:Redraw()
    clear()
    local map = self.map
    if not (map and map:IsShown()) then return end
    local mapID = map:GetMapID()
    local canvas = map:GetCanvas()
    if not mapID or canvas:GetWidth() <= 0 then return end
    ensureFrame(map)
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    view.scale = map.GetCanvasScale and map:GetCanvasScale() or 1
    for _, place in ipairs(self.PlacesOn(mapID)) do
        if shown(place.pin) then
            local button = acquire()
            button.pin = place.pin
            button.icon:SetAtlas(self.STYLES[place.pin.type].atlas)
            button:ClearAllPoints()
            button:SetPoint("CENTER", view.frame, "TOPLEFT", place.x * width, -place.y * height)
            sizeButton(button)
            -- A pin with nothing to open lets clicks through to the map (zooming into the zone).
            if button.SetMouseClickEnabled then
                button:SetMouseClickEnabled(clickTarget(button) ~= nil)
            end
            button:Show()
        end
    end
end

function MapPins:UpdateSize()
    if not self.map then return end
    view.scale = self.map.GetCanvasScale and self.map:GetCanvasScale() or 1
    for i = 1, view.used do
        sizeButton(view.buttons[i])
    end
end

------------------------------------------------------------------------------------------------
-- Setup

local function createProvider()
    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:OnAdded(map)
        MapCanvasDataProviderMixin.OnAdded(self, map)
        MapPins.map = map
    end
    function provider:RemoveAllData()
        clear()
    end
    function provider:RefreshAllData()
        MapPins:Redraw()
    end
    function provider:OnCanvasScaleChanged()
        MapPins:UpdateSize()
    end
    function provider:OnHide()
        hideTooltip()
        clear()
    end
    return provider
end

local function anyShown()
    return Options:Get(DUNGEONS) or Options:Get(TRAVEL)
end

function MapPins:Register()
    if self.provider then return true end
    if not (WorldMapFrame and WorldMapFrame.AddDataProvider and MapCanvasDataProviderMixin and CreateFromMixins) then
        return false
    end
    self.provider = createProvider()
    WorldMapFrame:AddDataProvider(self.provider)
    return true
end

-- Adds the provider once an option is on (or as soon as the world map has loaded), and draws the
-- pins again while the map is open.
function MapPins:Update()
    if anyShown() and not self:Register() then return end
    if self.map and self.map:IsShown() then self:Redraw() end
end

-- Showing pins is allowed in combat, so the map can change while it is open in combat.
local function schedule()
    ns.Later("mapPins", function() MapPins:Update() end, true)
end

function MapPins:Init()
    Options:Watch({ DUNGEONS, TRAVEL }, schedule)
    ns.Events:On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_WorldMap" and anyShown() then schedule() end
    end)
    if anyShown() then schedule() end
end
