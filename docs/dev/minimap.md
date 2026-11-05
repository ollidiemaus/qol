# Minimap

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

The square minimap's bronze border, `Media/MinimapSquareBorder.tga` (512×512), is Forever's own
round frame (`ui-hud-minimap-frame-c60-2x`, file 8026708 of build 1.60.1.70291) unwrapped onto a
square: each pixel of a band along the square's edges, with rounded corners, takes the ring's pixel
at the same distance from the map's edge, walking around the ring as it walks around the square. The
north triangle is left out and the two ends of the walk are cross-faded at the top. The texture
reaches 9 units past each edge of the 198-unit map. `Media/Zeppelin.tga` and `Media/Tram.tga`
(64×64) are drawn in the style and colors of the boat's atlas (`flightmasterferry`): gold rims, a
dark brown body darker towards the bottom, a black outline. The client has no zeppelin or tram of
that kind. All three were made with small numpy scripts, not kept in the repository.

The square minimap replaces the minimap's mask and hides the round frame textures
(`MinimapCompassTexture` and its underlay). Forever's minimap code (`Blizzard_Minimap/Camelot/Minimap.lua`)
sets its round mask again when `rotateMinimap` changes, so a `CVAR_UPDATE` for it applies the square
mask again; the hybrid minimap has a mask of its own (`HybridMinimap.CircleMask`). `GetMinimapShape`
is set on `ADDON_LOADED`, not with the rest of the layout: LibDBIcon places its buttons on
`PLAYER_LOGIN` by what it answers then, and `ns.Later` runs a frame later, which would put them on the
circle after every reload. It is only a global of ours, so it needs no `ns.Later`. The zone text is
the game's own `MinimapCluster.ZoneTextButton`, moved: it keeps its tooltip and click. Its frame
goes to the hidden holder when it moves, or at its default spot when the player asks: before
Forever 1.60.1 the separate `MinimapCluster.BorderTop`, since then the button's own `StateTexture`
and `AddTexture` (the mouse-over glow, which the game shows with `SetShown` on every button state
change, so `Hide()` wouldn't hold). Only the textures are reparented; the button is untouched. The clock,
addon compartment, tracking button and day and night icon are moved the same way, into a row above
or below a frame of ours around what is drawn of the minimap (the square and its border, or the
round frame with its north triangle). The tracking button and the day and night icon can also go
inside the map, anchored to its center: on a round map along the diagonal, clear of the round frame
(which covers about 7% of the radius). Inside the map they're raised above its frame level (the
cluster's buttons sit below the map) and get their level back when they leave. Positions are worked
out in screen units, since Edit Mode scales the minimap but not its header. Forever's skin sets the
day and night icon's center again whenever the minimap's scale is set; `Minimap.OnScaleUpdated` lays
it out again after that. The clock's text (`TimeManagerClockTicker`) and the coordinates'
(`PlayerCoords.CoordText`) keep their color once set; the zone text is colored again by the game on
every zone change, so the class color is put back on the zone events. A font size sets the text's
own font file and flags at the new size (`SetFont`); the game never sets these fonts itself. Set to
the game's size again, the text gets the game's font back with `SetFont` too, then its font object:
after `SetFont` the text still has that font object, and the client ignores a `SetFontObject` with
the one a text already has, so that alone left the larger font until a `/reload` (seen in game
2026-10-12; the stubs' `SetFontObject` does the same). A larger font makes the clock's button
wider and higher and the zone text's button and font string higher (`MinimapZoneText` has a height
of 12 and shows nothing of a line that doesn't fit), by the ratio to the game's size; a smaller one
leaves them as they are. The sizes are set before the positions, which go by the buttons' sizes.

Classic Era (1.15) has the same minimap with other names (`Blizzard_Minimap/Classic/Minimap.xml`),
so a few frames have a Classic Era path. Each asks the client for the frame, not which client it is:
- The round border is `MinimapBorder`, a texture on `MinimapBackdrop`; there is no compass
  underlay, and `MinimapCompassTexture` is the compass ring the game shows only while the map
  rotates. The square shape hides all three that exist.
- The tracking button is `MiniMapTracking` on `MinimapBackdrop` (`MinimapTracking_Simple.xml`), not
  `MinimapCluster.Tracking`. The game shows it only while something is tracked; the layout moves it
  the same either way.
- There is no calendar (no `ToggleCalendar`, which Forever's calendar bootstrap defines at startup):
  `GameTimeFrame` is the time of day icon on the round border (`GameTime_NoCalendar.xml`), not the
  calendar button. So without `ToggleCalendar` the day and night option moves `GameTimeFrame` (where
  the cluster has no `DielFrame`), and the calendar option and its row are left out, or it would
  hide the icon.
- The map is 140 across, not 198. The rows' distances from the round frame (`EDGES.round`) and the
  inside spots' cover of the round frame (`ROUND_COVER`) keep Forever's numbers until they're checked
  in game.
The zone text, the clock, the class colors, the font sizes and the FPS and ping text use the same
frames as Forever.

The FPS and ping text is a frame of ours (a child of `MinimapCluster`, like the clock) that the rows
place like any other element. The game has no place for it, so it has no "Default" position (an
unknown or inside value hides it), and it's only made the first time it has a row. It shows
`GetFramerate()` and the higher of `GetNetStats()`'s home and world latency, as the game's own latency
meter on the micro menu does. One `C_Timer.NewTicker(1)` updates it while it has a row and cancels itself
once it hasn't; no OnUpdate of ours runs every frame for it. The frame keeps the width of a reading of
999 and 999 and is as high as the clock's button, so its row never moves as the numbers change; the
text is anchored to the side of its spot (left, right or center), so it keeps to the minimap's edge or
to its neighbor. Its class color goes through the same code as the clock's, applied once more when the
frame is made, in case the colors ran before it was there. The Show choice (both, FPS or ping) has a
format string each; the frame is measured again from a three-digit reading of the chosen format when
the choice changes. With a font size of ours the text is measured at that size, so the width is
divided back to the game's size for `gameFonts`, from which the sizes grow it. Its font size goes
through the clock's code too: the frame grows both ways with a larger font, and Default gives the text the clock's font object
(`WhiteNormalNumberFont`) back. The sizes are applied before the positions, so the frame is made there
when it gets a row and has its size before it's first placed.

## Offsets

An offset is a shift of one element in screen units (`x / GetEffectiveScale()`), so a scaled minimap
doesn't change it. The rows and the spots inside the map work out places and widths without it and add
it only in `placeItem`: neighbors and the coordinates under a row don't move. The coordinates have no
element entry and no Position; their offset goes on the row's anchor or on the game's.

At the game's own place the game's saved anchors are shifted (`shift`, through `ns.Later` like all the
layout). With an offset of 0 a frame we don't hold isn't touched at all, and the offset keys count
towards `layoutActive` only when they aren't 0, as they're compared with their defaults.

Some elements hold other frames up, so there the offset moves what's inside the frame (`parts`):
- The zone text's button: on Forever the clock, the calendar, the mail indicator (and through the
  calendar the compartment) and the instance difficulty hang on it (`GameTimeFrameTemplate.xml`,
  `MinimapIndicatorFrameTemplate.xml`, `Blizzard_TimeManager.xml`), so only `MinimapZoneText` moves
  and the button with its hover area stays. In a row the whole button moves. Classic Era and Retail get
  the same, for one way of working.
- `MinimapCluster.Tracking`: Retail's indicator frame anchors to it (`Minimap.xml`), so
  `Tracking.Button` and `Tracking.Background` move. Forever's template anchors the indicator to the
  zone text's button, but its source still has `MiniMapIndicatorFrame_UpdatePosition`, which anchors
  to `Tracking`; it gets the same path. `Background` has no anchors in the XML, which we take as
  filling its parent (to check in game). Classic Era's `MiniMapTracking` has nothing on it and moves
  whole.
Checked in Forever's, Retail's and Classic Era's UI source: nothing anchors to the clock, the
compartment, the day and night icon or the coordinates.

Edit Mode's "Header underneath" anchors the zone text and the compartment anew, and Forever's skin
the day and night icon on every minimap scale. A layout runs after leaving Edit Mode and on
`EDIT_MODE_LAYOUTS_UPDATED`, for a layout that changes outside it; inside Edit Mode the offset waits
for the exit. `originals` holds the game's anchors and `placed` what
the last layout left: anchors that aren't `placed` are the game's new ones (`followGame`) and become
the originals, also with the offset back at 0 or for a frame in a row.

## The page's fit

With the offset rows the sections go in pairs by height, so every header stays level within the
page's 600: Shape | Coordinates, Clock | Zone text, Buttons | FPS and ping, 584 on Forever. The old
order and Shape | Clock, Buttons | FPS and ping, Zone text | Coordinates would both take 610 with
level headers, as each leaves a short section beside a much taller one.
