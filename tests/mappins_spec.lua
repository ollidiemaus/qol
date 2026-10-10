local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- The maps the tests open, as C_Map describes them.
local MAPS = {
    [947] = { name = "Azeroth", mapType = 1, parentMapID = 0 },
    [1414] = { name = "Kalimdor", mapType = 2, parentMapID = 947 },
    [1415] = { name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 },
    [1412] = { name = "Mulgore", mapType = 3, parentMapID = 1414 },
    [1413] = { name = "The Barrens", mapType = 3, parentMapID = 1414 },
    [1416] = { name = "Alterac Mountains", mapType = 3, parentMapID = 1415 },
    [1434] = { name = "Stranglethorn Vale", mapType = 3, parentMapID = 1415 },
    [1444] = { name = "Feralas", mapType = 3, parentMapID = 1414 },
    [1427] = { name = "Searing Gorge", mapType = 3, parentMapID = 1415 },
    [1428] = { name = "Burning Steppes", mapType = 3, parentMapID = 1415 },
    [1451] = { name = "Silithus", mapType = 3, parentMapID = 1414 },
    [2521] = { name = "Zephras Isle", mapType = 3, parentMapID = 947 },
}
local AREAS = {
    [35] = "Booty Bay", [392] = "Ratchet", [718] = "Wailing Caverns", [3429] = "Ruins of Ahn'Qiraj",
    [3428] = "Ahn'Qiraj", [16593] = "Zephras Isle",
}

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    local state = Stubs.state()
    state.maps, state.areas = MAPS, AREAS
    -- Where the zones sit on their continent: left, right, top, bottom.
    state.mapRects = { ["1413>1414"] = { 0.5, 0.7, 0.3, 0.6 }, ["1428>1415"] = { 0.4, 0.6, 0.5, 0.7 },
        ["1427>1415"] = { 0.4, 0.6, 0.4, 0.55 } }
    Stubs.Login(savedOptions)
    return ns
end

local function pinsOfType(kind)
    local found = {}
    for _, pin in ipairs(Stubs.MapPins()) do
        if pin.pin.type == kind then found[#found + 1] = pin end
    end
    return found
end

-- The pin whose first area or first destination is areaID.
local function pinFor(areaID)
    for _, pin in ipairs(Stubs.MapPins()) do
        local p = pin.pin
        if (p.areas and p.areas[1] == areaID) or (p.to and p.to[1].area == areaID) then return pin end
    end
    return nil
end

local function near(actual, expected)
    T.truthy(math.abs(actual - expected) < 0.01, "expected " .. expected .. ", got " .. actual)
end

local function tooltipTexts()
    local texts = {}
    for _, line in ipairs(GameTooltip.lines) do texts[#texts + 1] = line.text end
    return texts
end

describe("map pins", function()
    it("leave the world map alone by default", function()
        start()
        Stubs.OpenWorldMap(1413)
        T.eq(#WorldMapFrame.providers, 0)
        T.eq(#Stubs.MapPins(), 0)
    end)

    it("mark the dungeon entrances of a zone where they are", function()
        start({ mapDungeons = true })
        Stubs.OpenWorldMap(1413)
        T.eq(#pinsOfType("dungeon"), 3) -- Wailing Caverns, Razorfen Kraul, Razorfen Downs
        T.eq(#pinsOfType("boat"), 0)
        local caverns = pinFor(718)
        near(caverns.x, 477)
        near(caverns.y, -0.35 * 667)
        T.eq(caverns.button.icon.atlas, "dungeon")
        T.eq(caverns.button:GetParent().frameLevel, 500) -- the default map's level for dungeon entrances
    end)

    it("name the dungeon on mouseover", function()
        start({ mapDungeons = true })
        Stubs.OpenWorldMap(1413)
        local caverns = pinFor(718).button
        caverns.scripts.OnEnter(caverns)
        T.same(tooltipTexts(), { "Wailing Caverns", "Dungeon" })
        T.truthy(GameTooltip.shown)
        T.eq(caverns.mouseClickEnabled, false, "a click goes on to the map")
        caverns.scripts.OnLeave(caverns)
        T.falsy(GameTooltip.shown)
    end)

    it("list both raids behind the Scarab Wall on one pin", function()
        start({ mapDungeons = true })
        Stubs.OpenWorldMap(1451)
        local gates = pinFor(3429).button
        gates.scripts.OnEnter(gates)
        T.same(tooltipTexts(), { "Ruins of Ahn'Qiraj", "Ahn'Qiraj", "Raid" })
    end)

    it("show a boat's destination and open its map on click", function()
        start({ mapTravel = true })
        Stubs.OpenWorldMap(1413)
        T.eq(#pinsOfType("dungeon"), 0)
        local ratchet = pinFor(35).button
        T.eq(ratchet.icon.atlas, "flightmasterferry")
        ratchet.scripts.OnEnter(ratchet)
        T.same(tooltipTexts(), { "Boat", "Booty Bay (Stranglethorn Vale)", "Click to open the map of Stranglethorn Vale" })
        T.eq(ratchet.mouseClickEnabled, true)
        ratchet.scripts.OnClick(ratchet)
        T.eq(WorldMapFrame:GetMapID(), 1434)
        -- The map shows Stranglethorn now, with the dock back to Ratchet.
        T.truthy(pinFor(392))
    end)

    it("name a place by its zone when the game has no name for the stop", function()
        start({ mapTravel = true })
        Stubs.OpenWorldMap(2521)
        local dock = Stubs.MapPins()[1].button
        dock.scripts.OnEnter(dock)
        T.same(tooltipTexts(), { "Zeppelin", "Alterac Mountains", "Click to open the map of Alterac Mountains" })
    end)

    it("don't offer to open the map that is already shown", function()
        start({ mapTravel = true })
        Stubs.OpenWorldMap(1444)
        local ferry = pinsOfType("boat")[1].button
        ferry.scripts.OnEnter(ferry)
        T.eq(#tooltipTexts(), 2)
        T.eq(ferry.mouseClickEnabled, false)
        ferry.scripts.OnClick(ferry)
        T.eq(WorldMapFrame:GetMapID(), 1444)
    end)

    it("show a zone's pins on its continent", function()
        start({ mapDungeons = true })
        Stubs.OpenWorldMap(1414)
        local caverns = pinFor(718)
        near(caverns.x, (0.5 + 0.2 * 0.477) * 1000)
        near(caverns.y, -(0.3 + 0.3 * 0.35) * 667)
    end)

    it("show Blackrock Mountain on both its zones, and once on the continent", function()
        start({ mapDungeons = true })
        Stubs.OpenWorldMap(1427)
        T.eq(#pinsOfType("dungeon"), 2) -- Blackrock Depths and Blackrock Spire
        T.eq(#pinsOfType("raid"), 1) -- Molten Core (Blackwing Lair lies outside this map)
        WorldMapFrame:SetMapID(1415)
        T.eq(#pinsOfType("dungeon"), 2)
        T.eq(#pinsOfType("raid"), 2)
    end)

    it("keep their size on screen at every zoom", function()
        start({ mapDungeons = true })
        Stubs.OpenWorldMap(1413)
        T.eq(pinFor(718).size, 24)
        Stubs.ZoomWorldMap(2)
        T.eq(pinFor(718).button.width, 12)
    end)

    it("follow the options while the map is open", function()
        local ns = start({ mapDungeons = true })
        Stubs.OpenWorldMap(1413)
        ns.Options:Set("mapTravel", true)
        Stubs.RunTimers()
        T.eq(#pinsOfType("boat"), 1)
        ns.Options:Set("mapDungeons", false)
        ns.Options:Set("mapTravel", false)
        Stubs.RunTimers()
        T.eq(#Stubs.MapPins(), 0)
    end)

    it("go away with the map", function()
        start({ mapDungeons = true })
        Stubs.OpenWorldMap(1413)
        Stubs.CloseWorldMap()
        T.eq(#Stubs.MapPins(), 0)
    end)

    it("wait for the world map to load", function()
        Stubs.LoadAddon()
        local worldMap = WorldMapFrame
        _G.WorldMapFrame = nil
        Stubs.state().maps = MAPS
        Stubs.Login({ mapDungeons = true })
        T.eq(#worldMap.providers, 0)
        Stubs.LoadWorldMap()
        Stubs.RunTimers()
        T.eq(#WorldMapFrame.providers, 1)
    end)

    it("stay off the world map on a client without Forever's maps", function()
        local ns = Stubs.LoadAddon()
        Stubs.state().maps = {}
        Stubs.Login({ mapDungeons = true, mapTravel = true })
        T.falsy(ns.MapPins.IsAvailable())
        Stubs.OpenWorldMap(1413)
        T.eq(#WorldMapFrame.providers, 0)
    end)

    it("are added only once", function()
        local ns = start({ mapDungeons = true })
        ns.Options:Set("mapTravel", true)
        Stubs.RunTimers()
        T.eq(#WorldMapFrame.providers, 1)
    end)
end)

-- Forever's maps (UiMap.db2 of build 1.60.1.70291): the world, continents, zones and cities.
local FOREVER_MAPS = { [947] = true, [2482] = true, [2521] = true, [2524] = true, [2548] = true, [2652] = true }
for id = 1411, 1461 do FOREVER_MAPS[id] = true end

describe("map pin data", function()
    it("places every pin on one of Forever's maps, within the map", function()
        local ns = Stubs.LoadAddon()
        T.truthy(#ns.MapPinData > 50, "found the pins")
        for i, pin in ipairs(ns.MapPinData) do
            local where = "pin " .. i
            T.truthy(ns.MapPins.STYLES[pin.type], where .. " type")
            local places = { pin }
            for _, other in ipairs(pin.also or {}) do places[#places + 1] = other end
            for _, place in ipairs(places) do
                T.truthy(FOREVER_MAPS[place.map], where .. " map")
                T.truthy(place.x >= 0 and place.x <= 100 and place.y >= 0 and place.y <= 100, where .. " position")
            end
            if pin.type == "dungeon" or pin.type == "raid" then
                T.truthy(pin.areas and #pin.areas > 0, where .. " names its instance")
                T.eq(pin.to, nil, where)
            else
                T.truthy(pin.to and #pin.to > 0, where .. " goes somewhere")
                for _, destination in ipairs(pin.to) do
                    T.truthy(FOREVER_MAPS[destination.map], where .. " destination map")
                end
            end
        end
    end)
end)
