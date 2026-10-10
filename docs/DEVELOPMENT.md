# Developing Quality of Life

Notes for working on the addon. What it does for players is in the [README](../README.md).

## Layout

| Folder | What's in it |
|---|---|
| `Core/` | Namespace and printing (`Init`), the event frame (`Events`), saved options with defaults and change watchers (`Options`), deferred changes (`Later`), the hidden holder for hidden frames (`Hider`), `/qol` (`Slash`) and startup (`Lifecycle`) |
| `Data/` | Static game data: `MapPins` (dungeon entrances, docks, portals; how it was made is at the top of the file) |
| `Features/` | One file per feature: `Merchant`, `Quests`, `Tooltips`, `HideFrames` (also the chat buttons), `CombatLog`, `ChatClassColors`, `CombinedBagSort`, `ClassHealthBars`, `Minimap` (shape, positions, class colors and font sizes around the minimap), `MapPins`, `Viewport`, `ActionBars`, `ButtonBorders`, `BarPaging`, `ReloadCommand` |
| `UI/` | `SettingsPage.lua`, our own two-column settings page; `Settings.lua`, the pages under Options > AddOns built with it (and the Viewport page as the game's list) |
| `Locales/` | English strings, German overrides |
| `Media/` | `Icon.tga`, the addon list icon (the TOC's `IconTexture`, 128×128, 32-bit), and `Icon.svg`, its source (not packaged); `Zeppelin.tga`, `Tram.tga` and `MinimapSquareBorder.tga` (see below) |
| `tests/` | Specs run in plain Lua against `tests/wow_stubs.lua` |

Features never talk to each other or to the settings page. The page writes `ns.Options`; a feature
reads it with `Options:Get` and reacts to changes through `Options:Watch`.

## Rules for touching Blizzard frames

Forever and retail 12.x hand out secret values, and taint that leaks into Blizzard code breaks
unrelated frames ("tainted by 'QoL'"). Action Bar Button Growth Direction learned this the
hard way on the Forever beta. So:

- Never write a field on a Blizzard frame, never call its layout or update methods, and never
  `hooksecurefunc` its methods. Read fields, call widget methods (`SetPoint`, `SetParent`).
- Every change to a Blizzard frame goes through `ns.Later(key, fn)`: it runs on a fresh timer (never
  inside a Blizzard call stack) and waits for the end of combat. A change the game allows in combat
  (the health bar colors) passes `true` as a third argument and runs in combat too.
- Hide frames by parenting them to `ns.Hider`'s holder instead of `Hide()` plus hooks; Blizzard's
  own `Show()` calls then change nothing.
- Compare or compute with game values only after `ns.IsUsable(value)` (nil and secret values fail).
- Register events through `ns.Events:On`; it skips events the client doesn't know.
- The few calls into Blizzard code are listed here, each with why it's safe: the world map's
  `AddDataProvider` (the map's own extension point; it calls each provider in a secure call of its
  own) and `SetMapID` (only from a click on one of our own pins, like a click on a zone).
- Leave `WorldFrame` alone while a cutscene plays. Blizzard's `CinematicFrame` re-anchors it for
  the black bars and resets it to full screen at the end; `MovieFrame` hides it. Two hands on
  `WorldFrame` during a cutscene is how viewport addons crash the game. The viewport waits until
  `CinematicFrame` and `MovieFrame` are both hidden (checking back every second) and then applies
  itself again.

The action bar flip copies the grid math of `ActionBarMixin:UpdateGridLayout` and applies it to the
bar's button containers only. Blizzard stores a new `oldGridSettings` table each time it lays a bar
out, so events are just wake-ups: a bar is laid out again only when that table changed since our
last pass (or the settings changed).

Hiding the button borders changes only the buttons' textures and child frames, with widget methods
(the buttons are protected, so ns.Later waits for the end of combat). The frame (`NormalTexture`)
gets alpha 0: the button shows and hides its state textures itself, and Blizzard's
`UpdateButtonArt` sets the frame's atlas again without touching its alpha. The icon loses its mask
(`RemoveMaskTexture(IconMask)`; nothing in Blizzard_ActionBar adds it again). The textures drawn for
the rounded frame (their atlases start with `UI-HUD-ActionBar-IconFrame`) get the classic square
ones from `Interface\Buttons`, which Forever's client still has: `ButtonHilight-Square`,
`CheckButtonHilight`, `UI-Quickslot-Depress`, `UI-QuickslotRed` and, centered at 62/36 of the
button like on classic buttons, `UI-ActionButton-Border`. A texture showing anything else (the pet
bar's `bags-newitem` spell highlight) is left alone, and so is one whose art Blizzard put back
until the next wake-up (`UpdateButtonArt` sets the pushed frame again when Edit Mode changes a bar's
art). The fill textures keep the size Blizzard gives them, only their anchors change. The swipe
cooldowns get the icon's anchors, the slot art and background move to sublevel -1, behind the
icon, and the casting and interrupt animations get alpha 0 (their animations only animate their
children; reparenting them would break their `GetParent()` calls). Turning the option off puts
back what was saved per button.

The class-colored health bars use only `SetStatusBarDesaturated` and `SetStatusBarColor` on the
unit frame's own bar (`frame.healthbar`): the default green texture is desaturated and then tinted,
so its shading stays. Blizzard sets `lockColor` on the player, target, target of target, focus and
focus target bars and never colors them itself, so a color stays until we change it. Who gets a class color
follows Blizzard's raid frames: `UnitIsPlayer` or `UnitTreatAsPlayerForDisplay`, with a known,
non-secret class (`UnitClass` is secret while a unit's identity is restricted). The bar's own
`unit` field says what it shows, so the player frame in a vehicle (`"vehicle"`) keeps its default.

The combat log can't be closed in the default UI, and the dock's own functions (`FCF_Close`,
`FCF_UnDockFrame`) write to the chat frames and the dock. So `ChatFrame2` goes to the hidden holder
and its tab is scaled down to 0.001: the dock gives every tab its parent, width and anchor again on
each update (each tab hangs on the right edge of the one before), but never its scale, so the tab
takes no room and the next tab closes the gap.

Names in chat in class color are the game's own setting: `chatClassColorOverride` "0" means always
(see `ChatFrameUtil.ShouldColorChatByClass`). Turning the option off gives the setting its default.

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
(`MinimapCompassTexture` and its underlay). Forever's minimap skin (`Blizzard_Minimap/Camelot/Skin.lua`)
sets its round mask again when `rotateMinimap` changes, so a `CVAR_UPDATE` for it applies the square
mask again; the hybrid minimap has a mask of its own (`HybridMinimap.CircleMask`). The zone text is
the game's own `MinimapCluster.ZoneTextButton`, moved: it keeps its tooltip and click. The clock,
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
own font file and flags at the new size (`SetFont`) and gives the font object back when set to the
game's size again; the game never sets these fonts itself. A larger font makes the clock's button
wider and higher and the zone text's button and font string higher (`MinimapZoneText` has a height
of 12 and shows nothing of a line that doesn't fit), by the ratio to the game's size; a smaller one
leaves them as they are. The sizes are set before the positions, which go by the buttons' sizes.

Bar paging: each key bound to `ACTIONPAGE1` to `ACTIONPAGE6` gets an override binding on a frame of
ours that mirrors what the key without modifiers does (`GetBindingAction(base, true)`, so a bar
addon's override counts), which is how the game treats a modified key without a binding of its own.
The saved bindings are never changed. Our own overrides fire `UPDATE_BINDINGS` too; the update then
finds nothing to change.

## Settings pages

The main, Action Bars and Minimap pages are canvases (`Settings.RegisterCanvasLayoutCategory`) built
by `UI/SettingsPage.lua`: two columns of rows, each an option's name with a control from the game's
own templates (`SettingsCheckboxTemplate`, `WowStyle2DropdownTemplate`), so they look like the game's
pages and fit without scrolling (`SettingsPage.MAX_HEIGHT`, checked by the tests). All names use one
font: the game's list draws dependent options smaller. A page refreshes on `OnRefresh` (the panel
showing it) and through `Options:Watch`, and resets on `OnDefault` (the game's "all settings" reset)
and its own Defaults button, which asks with a second click: the game's confirmation dialog would
spread taint. The canvas pages don't show up in the settings search. Viewport stays the game's
vertical list with proxy settings (sliders and a color swatch).

The world map pins are buttons on a frame of our own on the map's canvas, not pins from the map's
pools. Their places are zone coordinates in percent (as `/way` reads them), from Forever's tables;
the continent maps get them through `C_Map.GetMapRectOnMap`. Names come from `C_Map.GetAreaInfo`, so
they're in the player's language. Forever's UiMap IDs (1411 and up) don't exist on retail, so there
`MapPins.IsAvailable()` is false: the settings page leaves the World map options out and the map is
never touched.

## Tests and lint

Tests and lint need only Lua 5.1 (what WoW runs); newer Lua works for the tests too.

```bash
lua tests/run.lua
```

```bash
luacheck .
```

CI runs both on Lua 5.1.5 on every push and pull request (same setup as Wayscribe: Lua 5.1 and
luacheck from `~/.lua51`, built with hererocks).

The stubs make action bars read-only (a write to a bar field fails the test), and protected frames
fail on `SetPoint`/`SetParent` in combat, so the taint rules above are checked, not just written
down.

## Trying it in game

Link or copy the repository into the client's AddOns folder as `QoL` (on the Forever beta:
`_classic_beta_/Interface/AddOns/QoL`). The client only loads what the TOC lists, so `docs/`
and `tests/` do no harm there. An unpackaged copy reports its version as `@project-version@`; only
the packager fills it in.

Things only the real client can confirm:

- The viewport margins line up with the world at your resolution and UI scale, and stay with Alt+Z.
- Cutscenes with the viewport on (margins on all four sides), see below.
- Flipped bars stay flipped after Edit Mode changes, a `/reload`, shapeshifting (stance bar) and
  summoning a pet, and no "tainted by" error shows up in combat afterwards.
- Hiding the system bar leaves the main action bar where it was (on Forever it is anchored to the
  micro menu), and the micro menu still shows on the vehicle bar.
- Junk selling and repairs (including guild repairs) at a merchant.
- The vendor price of a stack in your bags shows the stack total with and without a merchant open,
  and only once (the game's own sell price line is replaced, not doubled).
- Class-colored health bars: the shading matches the default bar, an NPC target (and a rare or
  "minus" one) shows the default green, switching targets in combat recolors at once, and turning
  an option off brings the green back without a `/reload`. Also on the target of target, focus and
  focus target.
- Quests: accepting from a gossip NPC and from a quest greeting NPC (several quests in a row), a
  shared quest, turning in with one reward and with none, a choice of rewards and a quest that costs
  gold staying open, and Shift leaving everything to the player.
- Hiding the combat log: the tabs after it close the gap, also after a whisper tab opens and with
  the combat log selected when the option is turned on (the chat stays empty until another tab is
  clicked). No "tainted by" error in combat afterwards.
- Names in class color in say, guild, party and channels; turning the option off brings back the
  per-channel setting.
- The other chat buttons stay hidden after joining a voice channel and with text to speech on.
- Square minimap: both borders (the bronze one lines up with the map's edge at every Edit Mode size),
  minimap buttons of other addons (LibDBIcon) along the square, the rotate minimap setting, and a
  zone with the hybrid minimap.
- Zone text and the clock, addon compartment, tracking button and day and night icon in every
  position, several in one spot, above and below a round and a square minimap, with and without
  coordinates, after an Edit Mode change of the minimap's size, and after a `/reload`; the tracking
  menu and the addon compartment's menu still open from their new places. Class color after zone
  changes and in combat, and on the clock and the coordinates.
- The tracking button and the day and night icon inside the map: drawn above it, clear of the round
  frame and the bronze border in every corner, clickable there, and the mail icon (anchored to the
  tracking button by the game) still readable.
- Bar paging off: Shift+1 to Shift+6 press the action buttons (a `[mod:shift]` macro sees Shift),
  also with a bar addon that binds the number keys itself; turning it off pages again, and changing
  a key binding in combat is picked up after combat.
- The settings pages: two columns at the panel's default size in English and German (no name cut
  off), checkboxes and dropdowns working, dependent options greyed out, and the Defaults button
  asking first.
- The zeppelin and tram pins' icons next to the boats', on zone and continent maps.
- Hidden button borders on every bar (also the stance and pet bars): square icons, the mouseover,
  pressed and checked (auto attack, an active stance) textures, the red auto attack flash, the
  green glow of an equipped item, the cooldown swipe over the whole icon, no casting animation;
  after changing "Hide Bar Art" of the main bar in Edit Mode, and back to the normal buttons
  without a `/reload` when turned off. No "tainted by" error in combat afterwards.
- The zone text and the clock at every font size, in the header bar and above and below the
  minimap (rows with something else in them), back to the game's look when set to Default.
- World map pins: in the right places on the zone and continent maps (the entrance positions are
  the instance portals, like retail's encounter journal pins), the tooltips' names in German, and a
  click opening the destination's map. Open the map in combat too.

### Cutscenes and the viewport

Turn the viewport on with a margin on every side, then:

1. An in-engine cinematic, the risky kind: the game re-anchors the world for its black bars. On
   Forever `/run OpeningCinematic()` plays nothing (tested 2026-10-09); the race intro only plays
   on a new character's first login, so create one with the viewport on (it's account-wide). During
   the intro you should see only Blizzard's black bars (top and bottom), none of the viewport
   margins. Right after it ends (or after Esc), the viewport is back. On retail, quest cutscenes do
   the same.
2. During such a cinematic, switch between windowed and fullscreen or resize the window. That fires
   a display change in the middle of it, the moment both Blizzard and a viewport addon want to move
   the world.
3. Cancel one right away with Esc.
4. `/run MovieFrame_PlayMovie(MovieFrame, 1)` plays a pre-rendered movie (the game hides the world
   for it). Let it run out once and cancel it once; the viewport comes back within a second.
5. Repeat 1 and 4 with the viewport off, to have something to compare with.

A crash writes a report to `_classic_beta_/Errors/` (date, time and "Error" in the name). The
`Error:` and `Description:` lines at the top say what failed. If it only happens with the viewport
on, that report is what to look at.

## Releasing

`.github/workflows/release.yml` runs the [BigWigsMods packager](https://github.com/BigWigsMods/packager)
on every pushed tag, like Wayscribe: it replaces `@project-version@` with the tag, leaves out `docs/`,
`tests/`, `README.md` and `Media/Icon.svg`, and creates the GitHub release. For CurseForge uploads, add
`## X-Curse-Project-ID` to the TOC and the `CF_API_KEY` repository secret.
