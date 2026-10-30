# World map pins

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

The world map pins are buttons on a frame of our own on the map's canvas, not pins from the map's
pools. Their places are zone coordinates in percent (as `/way` reads them), from Forever's tables;
the continent maps get them through `C_Map.GetMapRectOnMap`. Names come from `C_Map.GetAreaInfo`, so
they're in the player's language. Forever's UiMap IDs (1411 and up) don't exist on retail, so there
`MapPins.IsAvailable()` is false: the settings leave the World map page out and the map is never
touched.

Classic Era (1.15) has the same UiMap IDs for its zones, so the pins show there too, with a path of
their own for the places where its world differs from Forever's. `MapPins.World()` tells the two
apart by asking for Forever's Zephras Isle map (2521), not the build: a pin marked `world =
"forever"` (the Southshore stop, Stormwind Harbor, the Riverglades boat, the Zephras Isle airships)
is left out on Classic Era, and one marked `world = "classicEra"` (its direct Menethil Harbor–Auberdine
boat) on Forever. Classic Era's Stormwind City and Eastern Plaguelands maps cover another part of
the world than Forever's (Forever's Stormwind takes in the harbor), so the Stockade, the Deeprun
Tram, Stratholme and Naxxramas carry a `classicEra = { x, y }` place, converted through both
clients' zone rects; the continent pins follow from it, since `GetMapRectOnMap` gives Classic
Era's own rects. Classic Era has no `flightmasterferry` atlas, so the boat style names an
`orAtlas`, the garrison's `Ships_CargoShip-Map`, used where `C_Texture.GetAtlasInfo` doesn't know
the first.
