local _, ns = ...

-- The places Features/MapPins.lua marks on the world map. Each sits on a zone map (map, a UiMap
-- ID) at x, y: the same percent coordinates /way uses. The pins also show on the zone's continent.
--   * Dungeons and raids name their instance with areas (AreaTable IDs, so the game says the name in
--     the player's language). also: more zones the same entrance lies in (Blackrock Mountain is in
--     two); those show it on their own map only.
--   * Boats, zeppelins, portals and the tram list where they go (to): an area (the stop's name) and
--     the map a click opens. A line with several stops lists the next one first.
--
-- Positions are Forever's own (build 1.60.1.70291, read through wago.tools and placed on the zone
-- maps with UiMapAssignment):
--   * instance portals: Map.db2's corpse position of each instance, which retail's encounter journal
--     also uses for its entrance pins. Naxxramas, floating above Plaguewood, has none; its position
--     is the necropolis' TaxiNode;
--   * boats and zeppelins: the stops (TaxiPathNode rows with a wait) of the transport paths, a boat
--     at sea level, a zeppelin high up. Forever adds the boat from Stormwind Harbor, the stop at
--     Southshore, the boat between Tanaris and the Riverglades and the airships to Zephras Isle;
--   * the portal between Darnassus and Rut'theran Village and the Deeprun Tram: their area triggers
--     (AreaTrigger.db2), with AzerothCore's teleport table saying which is which.
-- Forever's new dungeons aren't here: the client has no position for their entrances.
ns.MapPinData = {
    -- Dungeons
    { type = "dungeon", map = 1454, x = 53.0, y = 48.9, areas = { 2437 } }, -- Ragefire Chasm, Orgrimmar
    { type = "dungeon", map = 1413, x = 47.7, y = 35.0, areas = { 718 } }, -- Wailing Caverns, The Barrens
    { type = "dungeon", map = 1436, x = 38.2, y = 77.5, areas = { 1581 } }, -- The Deadmines, Westfall
    { type = "dungeon", map = 1421, x = 44.7, y = 67.8, areas = { 209 } }, -- Shadowfang Keep, Silverpine Forest
    { type = "dungeon", map = 1440, x = 16.5, y = 11.0, areas = { 719 } }, -- Blackfathom Deeps, Ashenvale
    { type = "dungeon", map = 1453, x = 50.4, y = 66.2, areas = { 717 } }, -- The Stockade, Stormwind City
    { type = "dungeon", map = 1426, x = 17.7, y = 39.2, areas = { 721 } }, -- Gnomeregan, Dun Morogh
    { type = "dungeon", map = 1413, x = 42.3, y = 89.9, areas = { 491 } }, -- Razorfen Kraul, The Barrens
    { type = "dungeon", map = 1420, x = 85.1, y = 31.4, areas = { 796 } }, -- Scarlet Monastery, Tirisfal Glades
    { type = "dungeon", map = 1413, x = 50.9, y = 92.9, areas = { 722 } }, -- Razorfen Downs, The Barrens
    { type = "dungeon", map = 1418, x = 35.2, y = 10.3, areas = { 1337 } }, -- Uldaman, Badlands
    { type = "dungeon", map = 1446, x = 38.7, y = 19.9, areas = { 978 } }, -- Zul'Farrak, Tanaris
    { type = "dungeon", map = 1443, x = 29.1, y = 62.9, areas = { 2100 } }, -- Maraudon, Desolace
    { type = "dungeon", map = 1435, x = 77.3, y = 35.9, areas = { 1477 } }, -- Sunken Temple, Swamp of Sorrows
    -- Blackrock Depths and Blackrock Spire, Burning Steppes and Searing Gorge
    { type = "dungeon", map = 1428, x = 22.6, y = 7.5, areas = { 1584 }, also = { { map = 1427, x = 27.1, y = 72.5 } } },
    { type = "dungeon", map = 1428, x = 33.0, y = 25.2, areas = { 1583 }, also = { { map = 1427, x = 40.8, y = 95.6 } } },
    { type = "dungeon", map = 1444, x = 62.0, y = 33.3, areas = { 2557 } }, -- Dire Maul, Feralas
    { type = "dungeon", map = 1422, x = 69.1, y = 73.0, areas = { 2057 } }, -- Scholomance, Western Plaguelands
    { type = "dungeon", map = 1423, x = 26.1, y = 10.4, areas = { 2017 } }, -- Stratholme, Eastern Plaguelands

    -- Raids
    -- Molten Core, Burning Steppes and Searing Gorge
    { type = "raid", map = 1428, x = 26.3, y = 24.6, areas = { 2717 }, also = { { map = 1427, x = 32.0, y = 94.8 } } },
    { type = "raid", map = 1445, x = 52.9, y = 77.7, areas = { 2159 } }, -- Onyxia's Lair, Dustwallow Marsh
    { type = "raid", map = 1428, x = 32.5, y = 32.4, areas = { 2677 } }, -- Blackwing Lair, Burning Steppes
    { type = "raid", map = 1434, x = 54.0, y = 17.6, areas = { 1977 } }, -- Zul'Gurub, Stranglethorn Vale
    -- Ruins of Ahn'Qiraj and Ahn'Qiraj Temple, both behind the Scarab Wall, Silithus
    { type = "raid", map = 1451, x = 29.0, y = 92.8, areas = { 3429, 3428 } },
    { type = "raid", map = 1423, x = 26.6, y = 19.5, areas = { 3456 } }, -- Naxxramas, Eastern Plaguelands

    -- Boats
    { type = "boat", map = 1413, x = 63.8, y = 38.8, to = { { area = 35, map = 1434 } } }, -- Ratchet -> Booty Bay
    { type = "boat", map = 1434, x = 25.7, y = 73.1, to = { { area = 392, map = 1413 } } }, -- Booty Bay -> Ratchet
    { type = "boat", map = 1437, x = 4.7, y = 63.8, to = { { area = 513, map = 1445 } } }, -- Menethil Harbor -> Theramore
    { type = "boat", map = 1445, x = 71.7, y = 56.7, to = { { area = 150, map = 1437 } } }, -- Theramore -> Menethil Harbor
    { type = "boat", map = 1438, x = 54.8, y = 97.2, to = { { area = 442, map = 1439 } } }, -- Rut'theran Village -> Auberdine
    { type = "boat", map = 1439, x = 33.3, y = 39.8, to = { { area = 702, map = 1438 } } }, -- Auberdine -> Rut'theran Village
    -- Menethil Harbor -> Southshore -> Auberdine -> Menethil Harbor
    { type = "boat", map = 1437, x = 4.5, y = 56.7, to = { { area = 271, map = 1424 }, { area = 442, map = 1439 } } },
    { type = "boat", map = 1424, x = 50.7, y = 70.4, to = { { area = 442, map = 1439 }, { area = 150, map = 1437 } } },
    { type = "boat", map = 1439, x = 32.3, y = 44.1, to = { { area = 150, map = 1437 }, { area = 271, map = 1424 } } },
    { type = "boat", map = 1439, x = 30.5, y = 40.9, to = { { area = 17203, map = 1453 } } }, -- Auberdine -> Stormwind Harbor
    { type = "boat", map = 1453, x = 21.8, y = 56.9, to = { { area = 442, map = 1439 } } }, -- Stormwind Harbor -> Auberdine
    { type = "boat", map = 1444, x = 31.0, y = 39.5, to = { { area = 1108, map = 1444 } } }, -- Feathermoon -> Forgotten Coast
    { type = "boat", map = 1444, x = 43.1, y = 42.8, to = { { area = 1116, map = 1444 } } }, -- Forgotten Coast -> Feathermoon
    { type = "boat", map = 1446, x = 68.6, y = 23.0, to = { { area = 16591, map = 2548 } } }, -- Steamwheedle Port -> Riverglades
    { type = "boat", map = 2548, x = 80.6, y = 54.6, to = { { area = 977, map = 1446 } } }, -- Riverglades -> Steamwheedle Port

    -- Zeppelins and airships
    { type = "zeppelin", map = 1411, x = 50.5, y = 12.7, to = { { area = 117, map = 1434 } } }, -- Orgrimmar -> Grom'gol
    { type = "zeppelin", map = 1411, x = 51.0, y = 13.9, to = { { area = 1497, map = 1420 } } }, -- Orgrimmar -> Undercity
    { type = "zeppelin", map = 1434, x = 31.2, y = 30.4, to = { { area = 1637, map = 1411 } } }, -- Grom'gol -> Orgrimmar
    { type = "zeppelin", map = 1434, x = 31.5, y = 29.1, to = { { area = 1497, map = 1420 } } }, -- Grom'gol -> Undercity
    { type = "zeppelin", map = 1420, x = 60.6, y = 58.9, to = { { area = 1637, map = 1411 } } }, -- Undercity -> Orgrimmar
    { type = "zeppelin", map = 1420, x = 61.9, y = 58.9, to = { { area = 117, map = 1434 } } }, -- Undercity -> Grom'gol
    { type = "zeppelin", map = 1416, x = 12.8, y = 51.2, to = { { area = 16593, map = 2521 } } }, -- Alterac -> Zephras Isle
    { type = "zeppelin", map = 2521, x = 65.8, y = 83.8, to = { { map = 1416 } } }, -- Zephras Isle -> Alterac Mountains
    { type = "zeppelin", map = 1412, x = 34.3, y = 26.1, to = { { area = 16593, map = 2521 } } }, -- Mulgore -> Zephras Isle
    { type = "zeppelin", map = 2521, x = 57.7, y = 81.0, to = { { map = 1412 } } }, -- Zephras Isle -> Mulgore

    -- Portals and the tram
    { type = "portal", map = 1457, x = 29.1, y = 41.2, to = { { area = 702, map = 1438 } } }, -- Darnassus -> Rut'theran
    { type = "portal", map = 1438, x = 55.9, y = 89.3, to = { { area = 1657, map = 1457 } } }, -- Rut'theran -> Darnassus
    { type = "tram", map = 1453, x = 69.6, y = 30.3, to = { { area = 1537, map = 1455 } } }, -- Stormwind -> Ironforge
    { type = "tram", map = 1455, x = 78.0, y = 51.4, to = { { area = 1519, map = 1453 } } }, -- Ironforge -> Stormwind
}
