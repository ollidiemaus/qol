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
    [1423] = { name = "Eastern Plaguelands", mapType = 3, parentMapID = 1415 },
    [1424] = { name = "Hillsbrad Foothills", mapType = 3, parentMapID = 1415 },
    [1434] = { name = "Stranglethorn Vale", mapType = 3, parentMapID = 1415 },
    [1437] = { name = "Wetlands", mapType = 3, parentMapID = 1415 },
    [1439] = { name = "Darkshore", mapType = 3, parentMapID = 1414 },
    [1444] = { name = "Feralas", mapType = 3, parentMapID = 1414 },
    [1446] = { name = "Tanaris", mapType = 3, parentMapID = 1414 },
    [1427] = { name = "Searing Gorge", mapType = 3, parentMapID = 1415 },
    [1428] = { name = "Burning Steppes", mapType = 3, parentMapID = 1415 },
    [1451] = { name = "Silithus", mapType = 3, parentMapID = 1414 },
    [1453] = { name = "Stormwind City", mapType = 3, parentMapID = 1415 },
    [1455] = { name = "Ironforge", mapType = 3, parentMapID = 1415 },
    [2521] = { name = "Zephras Isle", mapType = 3, parentMapID = 947 },
    [2548] = { name = "Riverglades", mapType = 3, parentMapID = 1414 },
}
local AREAS = {
    [150] = "Menethil Harbor", [442] = "Auberdine", [271] = "Southshore", [717] = "The Stockade",
    [1537] = "Ironforge", [2017] = "Stratholme", [3456] = "Naxxramas", [17203] = "Stormwind Harbor",
    [16591] = "Riverglades", [977] = "Steamwheedle Port", [35] = "Booty Bay", [392] = "Ratchet",
    [718] = "Wailing Caverns", [3429] = "Ruins of Ahn'Qiraj", [3428] = "Ahn'Qiraj", [16593] = "Zephras Isle",
}

-- client: "forever" (the default) or "classicEra".
local function start(savedOptions, client)
    local ns = Stubs.LoadAddon({ client = client })
    local state = Stubs.state()
    state.maps, state.areas = MAPS, AREAS
    -- Where the zones sit on their continent: left, right, top, bottom (Classic Era's client has
    -- its own for Stormwind and the Eastern Plaguelands).
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

-- The pins whose first area or first destination is areaID.
local function allFor(areaID)
    local found = {}
    for _, pin in ipairs(Stubs.MapPins()) do
        local p = pin.pin
        if (p.areas and p.areas[1] == areaID) or (p.to and p.to[1].area == areaID) then found[#found + 1] = pin end
    end
    return found
end

-- The first of them.
local function pinFor(areaID)
    return allFor(areaID)[1]
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

    it("draw zeppelins with our own icon", function()
        start({ mapTravel = true })
        Stubs.OpenWorldMap(1434)
        local zeppelins = pinsOfType("zeppelin")
        T.eq(#zeppelins, 2) -- to Orgrimmar and to Undercity
        T.eq(zeppelins[1].button.icon.texture, "Interface\\AddOns\\QoL\\Media\\Zeppelin")
        T.eq(pinsOfType("boat")[1].button.icon.atlas, "flightmasterferry")
    end)

    it("draw the Deeprun Tram with our own icon, in the zeppelin's size", function()
        start({ mapTravel = true })
        Stubs.OpenWorldMap(1453)
        local trams = pinsOfType("tram")
        T.eq(#trams, 1)
        T.eq(trams[1].button.icon.texture, "Interface\\AddOns\\QoL\\Media\\Tram")
        T.same(trams[1].button.icon.texCoord, { 0, 1, 0, 1 })
        T.eq(trams[1].size, 22)
        T.eq(trams[1].button.mouseClickEnabled, true)
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

describe("map pins on Classic Era", function()
    it("leave out Forever's routes: the Southshore stop, Stormwind Harbor, the Riverglades, Zephras Isle", function()
        start({ mapTravel = true }, "classicEra")
        Stubs.OpenWorldMap(1424)
        T.eq(#pinsOfType("boat"), 0, "no boat at Southshore")
        Stubs.OpenWorldMap(1453)
        T.eq(#pinsOfType("boat"), 0, "no Stormwind Harbor")
        Stubs.OpenWorldMap(1446)
        T.eq(#allFor(16591), 0, "no boat to the Riverglades")
        Stubs.OpenWorldMap(1416)
        T.eq(#pinsOfType("zeppelin"), 0, "no airship to Zephras Isle")
        Stubs.OpenWorldMap(1412)
        T.eq(#pinsOfType("zeppelin"), 0)
        Stubs.OpenWorldMap(1439)
        T.eq(#allFor(17203), 0, "no boat to Stormwind Harbor")
        T.eq(#allFor(271), 0, "no boat by way of Southshore")
    end)

    it("have the direct boat between Menethil Harbor and Auberdine", function()
        start({ mapTravel = true }, "classicEra")
        Stubs.OpenWorldMap(1437)
        local menethil = allFor(442)
        T.eq(#menethil, 1)
        T.eq(#menethil[1].pin.to, 1, "straight to Auberdine")
        T.eq(#pinsOfType("boat"), 2) -- and the boat to Theramore
        Stubs.OpenWorldMap(1439)
        local auberdine = allFor(150)
        T.eq(#auberdine, 1)
        T.eq(#auberdine[1].pin.to, 1, "straight to Menethil Harbor")
        T.eq(#pinsOfType("boat"), 2) -- and the boat to Rut'theran Village
    end)

    it("put the Stockade and the Deeprun Tram where Classic Era's Stormwind map has them", function()
        start({ mapDungeons = true, mapTravel = true }, "classicEra")
        Stubs.OpenWorldMap(1453)
        local stockade, tram = pinFor(717), pinFor(1537)
        near(stockade.x, 0.397 * 1000)
        near(stockade.y, -0.540 * 667)
        near(tram.x, 0.645 * 1000)
        near(tram.y, -0.076 * 667)
        WorldMapFrame:SetMapID(1415)
        stockade = pinFor(717)
        near(stockade.x, (0.38 + 0.08 * 0.397) * 1000)
        near(stockade.y, -(0.66 + 0.08 * 0.540) * 667)
    end)

    it("put Stratholme and Naxxramas where Classic Era's Eastern Plaguelands map has them", function()
        start({ mapDungeons = true }, "classicEra")
        Stubs.OpenWorldMap(1423)
        near(pinFor(2017).x, 0.308 * 1000)
        near(pinFor(2017).y, -0.157 * 667)
        near(pinFor(3456).x, 0.314 * 1000)
        near(pinFor(3456).y, -0.259 * 667)
        WorldMapFrame:SetMapID(1415)
        near(pinFor(3456).x, (0.53 + 0.14 * 0.314) * 1000)
        near(pinFor(3456).y, -(0.18 + 0.15 * 0.259) * 667)
    end)

    it("draw boats with a ship icon Classic Era has", function()
        start({ mapTravel = true }, "classicEra")
        Stubs.OpenWorldMap(1413)
        T.eq(pinFor(35).button.icon.atlas, "Ships_CargoShip-Map")
    end)

    it("leave Forever's world as it is", function()
        start({ mapDungeons = true, mapTravel = true })
        Stubs.state().mapRects["1423>1415"] = { 0.53, 0.67, 0.2, 0.35 }
        Stubs.OpenWorldMap(1453)
        near(pinFor(717).x, 0.504 * 1000)
        near(pinFor(1537).x, 0.696 * 1000)
        T.eq(#allFor(442), 1, "the boat from Stormwind Harbor")
        Stubs.OpenWorldMap(1437)
        T.eq(#allFor(271), 1, "the boat by way of Southshore")
        T.eq(#allFor(442), 0, "no direct boat to Auberdine")
        Stubs.OpenWorldMap(1423)
        near(pinFor(2017).x, 0.261 * 1000)
        WorldMapFrame:SetMapID(1415)
        near(pinFor(2017).x, (0.53 + 0.14 * 0.261) * 1000)
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
            T.truthy(pin.world == nil or pin.world == "forever" or pin.world == "classicEra", where .. " world")
            if pin.classicEra then places[#places + 1] = { map = pin.map, x = pin.classicEra.x, y = pin.classicEra.y } end
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
