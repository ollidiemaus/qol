# Developing Quality of Life

Notes for working on the addon. What it does for players is in the [README](../README.md).

## Layout

| Folder | What's in it |
|---|---|
| `Core/` | Namespace and printing (`Init`), the event frame and unit listeners (`Events`), saved options with defaults and change watchers (`Options`), deferred changes (`Later`), the hidden holder for hidden frames (`Hider`), what the back buttons and the rings share (`Buttons`: an action slot's look, override bindings), our windows' frame (`Window`: the settings), `/qol` (`Slash`) and startup (`Lifecycle`) |
| `Data/` | Static game data: `MapPins` (dungeon entrances, docks, portals; how it was made is at the top of the file) |
| `Features/` | One file per feature: `Merchant`, `Quests`, `Tooltips`, `HideFrames` (also the chat buttons), `BuffTooltips` (the controller interface's tooltips for new buffs), `CombatLog`, `ChatClassColors`, `CombinedBagSort`, `CombinedBagLayout`, `MailBookmarks` (tabs on the Send Mail tab), `ClassHealthBars`, `DruidManaBar` (mana in bear and cat form), `ScreenEdge` (Edit Mode frames past the screen edge), `Minimap` (shape, positions, class colors and font sizes around the minimap, and the FPS and ping text), `MapPins`, `Viewport`, `ActionBars`, `ButtonBorders`, `BarPaging`, `BackButtons` (the controller back buttons, Forever only), `RingEntries` (what can go on a ring, and what a character has of it), `Ring`, `RingPicker` (the editor's list), `RingEditor` (the settings' Ring page, `/qol ring`), `ReloadCommand` |
| `UI/` | `SettingsPage.lua`, a settings page (two columns, or rows across the page, and key binding rows); `SettingsWindow.lua`, the window that `/qol` opens, with the list of pages; `InfoPage.lua`, the information page under Options > AddOns, with a button that opens the window; `Settings.lua`, the pages built with them, in the list's order |
| `Locales/` | English strings, German overrides |
| `Media/` | `Icon.tga`, the addon list icon (the TOC's `IconTexture`, 128×128, 32-bit), and `Icon.svg`, its source (not packaged); `Zeppelin.tga`, `Tram.tga`, `MinimapSquareBorder.tga` and the rings' `Ring.tga`, `RingSpoke.tga`, `RingLit1.tga` to `RingLit12.tga` and `RingSlot.tga` (see below); `AutoPotion.tga`, `AutoSetup.tga` and `Wayscribe.tga`, copies of the other addons' icons for the information page |
| `tests/` | Specs run in plain Lua against `tests/wow_stubs.lua` |
| `Bindings.xml` | The back buttons' entries under Key Bindings > AddOns (the client loads it from the addon's folder, not the TOC) |

Features never talk to each other or to the settings pages. A page writes `ns.Options`; a feature
reads it with `Options:Get` and reacts to changes through `Options:Watch`.

## Rules for touching Blizzard frames

Forever and retail 12.x hand out secret values, and taint that leaks into Blizzard code breaks
unrelated frames ("tainted by 'QoL'"), as other action bar addons learned the hard way on the
Forever beta. So:

- Never write a field on a Blizzard frame, never call its layout or update methods, and never
  `hooksecurefunc` its methods. Read fields, call widget methods (`SetPoint`, `SetParent`).
- Every change to a Blizzard frame goes through `ns.Later(key, fn)`: it runs from the OnUpdate of a
  frame of ours (never inside a Blizzard call stack), at most once per drawn frame, and waits for the
  end of combat. A request made while the batch runs waits for the next frame, so a change that makes
  the game fire an event asking for it again can't spin inside one frame and freeze the game
  (nothing says when the game runs a `C_Timer.After(0)` started from a timer callback). A change the
  game allows in combat (the health bar colors) passes `true` as a third argument and runs in combat
  too. It makes no garbage per request, since busy events (cooldowns, usability) ask many times a
  second: each key keeps one request table, reset by every new request, the batch swaps between two
  tables, and every feature's schedule helper hands it a function defined once, not a new closure.
- The back buttons and the rings go through `ns.LaterOutsideWindows(key, fn)` instead: out of combat
  too, and in Forever's controller interface also away from the game's windows that have the
  controller (see Settings pages below).
- Hide frames by parenting them to `ns.Hider`'s holder instead of `Hide()` plus hooks; Blizzard's
  own `Show()` calls then change nothing.
- Compare or compute with game values only after `ns.IsUsable(value)` (nil and secret values fail).
- Register events through `ns.Events:On`; it skips events the client doesn't know.
- Events about units (`UNIT_*`, first argument a unit) go through a unit listener, never through
  `ns.Events:On`: `ns.Events:NewUnitListener(unit1[, unit2])` registers with `RegisterUnitEvent`
  on a frame of its own, so the game drops every other unit's events before QoL wakes (in a raid
  with nameplates, hundreds a second). It takes one or two units, all a feature needs so far; a
  feature that shows more units makes more listeners. Make a listener once, at Init: frames are
  never freed.
  `listener:On(event, handler)` skips an unknown event like `ns.Events:On` (one handler per event,
  a second `On` replaces it; handlers get `(event, ...)`), and `listener:Off(event)` unregisters it,
  for an event that only matters while something shows.
- The few calls into Blizzard code are listed here, each with why it's safe: the world map's
  `AddDataProvider` (the map's own extension point; it calls each provider in a secure call of its
  own) and `SetMapID` (only from a click on one of our own pins, like a click on a zone).
- Leave `WorldFrame` alone while a cutscene plays. Blizzard's `CinematicFrame` re-anchors it for
  the black bars and resets it to full screen at the end; `MovieFrame` hides it. Two hands on
  `WorldFrame` during a cutscene is how viewport addons crash the game. The viewport waits until
  `CinematicFrame` and `MovieFrame` are both hidden (checking back every second) and then applies
  itself again.
- Set a Blizzard frame only when it would change. The viewport compares WorldFrame's anchors with the
  ones it wants (and its margins with their last layout) and leaves both alone when they match, so
  the events it follows (display size, UI scale, loading screens) cost nothing when nothing changed.
  WorldFrame is anchored to the screen (`nil`), like `CinematicFrame` anchors it, not to UIParent.
- With Forever's controller interface on (`C_InputInterfaceStyle.GetCurrentStyle()` is
  `Enum.InputDeviceInterfaceType.Gamepad`, `ns.IsControllerUI()`), the game hides the standard
  action bars for its own (`MainActionBar_InitializeGamepad`; `ActionBarMixin:SetShowGrid` says
  they "should never be shown with gamepad UI"), and those bars don't follow the keyboard's action
  page. So the bar flips, the hidden button borders and the bar paging overrides stand aside while
  it's on: nothing of ours on those bars or key bindings. Closing the settings saves the bindings
  (`SaveBindings` in `SettingsPanel`'s OnHide), which fires `UPDATE_BINDINGS`; in controller mode
  the bar features ignore it, and the back buttons and the rings update only once the settings have
  been closed for half a second (`ns.LaterOutsideWindows`).
- The other way round, the controller features (the back buttons and the buff tooltips, the
  Controller page) act only while the controller interface is on: with keyboard and mouse the back
  buttons hide, lose their `type` attribute (so their keys, saved bindings included, press nothing)
  and their override bindings, and the buff tooltip keeps its alpha. The game switches interfaces
  without a reload and fires `INPUT_DEVICE_INTERFACE_TRANSITION`; `ns.OnControllerUIChange` runs
  the features' updates on it (the bar paging overrides go and come back with it too). The rings
  aren't among them: each has a mouse key and a stick key and works in both.

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

Forever's player frame has a third bar only for the druid's astral power (moonkin), so bear and cat
form show no mana. The druid mana bar follows the rule of Blizzard's Wrath to Mists clients
(`AlternatePowerBar_UpdatePowerType`): the player's power isn't mana and `UnitPowerMax(mana)` is
above 0. It is drawn the way `PlayerFrame_ToPlayerArt` draws a third bar: a texture of ours with the
`AlternatePowerFrameTexture` atlas at its place on `PlayerFrameContainer` (not protected), and a
status bar of ours with the mana bar texture at the place and size of
`PlayerFrameAlternatePowerBarBaseTemplate`. The bar is a child of `PlayerFrameContentMain`, which is
protected, but the bar itself isn't, so it shows and hides in combat (druids shift in combat). On
Blizzard's frame only widget methods: the usual art (`FrameTexture`) gets alpha 0, which Blizzard
never sets (it only shows and hides it), and the threat glow (`FrameFlash`) gets the
`ClassResource-InCombat` atlas and its point, since the usual glow misses the third bar's border.
Blizzard sets the glow again in `PlayerFrame_UpdateArt` (entering the world, the vehicle events), so
those events are wake-ups. When the bar hides, the glow gets the usual atlas back only while the
frame shows the player (not a vehicle), Blizzard has no third bar of its own, and the glow still has
ours. The bar stands aside for Blizzard's own third bar (`activeAlternatePowerBar`, moonkin on
retail) and for a shown `classPowerBar` (retail's combo points sit where it goes). Left as they are:
the rage or energy bar's mask (Blizzard switches it to `Unit_BarMask` for a third bar; the two differ
by a pixel the frame art covers) and the bottom managed container (pet frame and the like), which
Blizzard moves 10 down for its third bar. The text follows `TextStatusBar`: `statusText` shows it
always or on hover, `statusTextDisplay` picks numbers, percent or both.

The mana bar costs nothing while it hides and little on a mana tick. A "player" listener made at
Init hears `UNIT_DISPLAYPOWER`, `UNIT_MAXPOWER` and the vehicle events; `UNIT_POWER_FREQUENT` goes
on it in `Apply` when the bar shows and off when it hides, so with the option off, as a non-druid
and in caster and travel form no mana event reaches QoL. A tick sets the value (passed as it
is, never compared: it can be secret) and only the texts that changed, so with Status Text off and
the bar not hovered it sets no text. The range is set in `Apply`, which `UNIT_MAXPOWER` wakes. The
two Status Text CVars are read when the bar is made and on `CVAR_UPDATE` for them, not on a tick:
the game's Status Text dropdown sets both with `SetCVar`, which fires it.

Every Edit Mode frame is clamped to the screen (`EditModeSystemTemplate`), and Edit Mode makes the
clamped rectangle the frame's selection box: `EditModeSystemMixin:UpdateClampOffsets` sets the clamp
insets from the frame's edges to its `Selection`'s. That box takes in the empty space around the
art, so the art can't reach the edge. Frames past the screen edge gives each frame Blizzard's insets
moved 30 further in on every side (in the frame's own units, so a frame shown bigger may go further),
with `SetClampRectInsets`, a widget method, on the frames of
`EditModeManagerFrame.registeredSystemFrames` (a field read). Nothing else is needed for saving:
`UpdateSystemAnchorInfo` saves a dragged frame's anchor from `GetPoint`, past the edge or not.
Blizzard sets its insets again whenever it lays a frame out (`UpdateSystem`, `UpdateSystemSetting`,
`HighlightSystem`; 0s for a frame not laid out yet): on `EDIT_MODE_LAYOUTS_UPDATED` (a layout loaded
or switched; AutoSetup's `SelectLayout` goes through `C_EditMode.SetActiveLayout`, which fires it,
since that's how the new layout gets applied), on leaving Edit Mode (`ExitEditMode` calls
`RevertAllChanges`, which applies the saved layout again), `PLAYER_SPECIALIZATION_CHANGED`, and in
Edit Mode on a highlight or a setting change, without an event. So the events are wake-ups, and
between `EditMode.Enter` and `EditMode.Exit` (EventRegistry) a frame of ours compares the frames
every drawn frame while the option is on. The insets are always worked out from the selection box,
whatever Blizzard set; a frame that has them already is left alone. That check makes no garbage of its own:
insets go around as four numbers (multiple returns), never tables, the watcher and the schedule
helper call one function defined at file scope, and a frame anchored again reuses its own copy of
its anchors.

New insets alone don't bring back a frame the game already pulled in: the first version set them a
frame after Edit Mode closed, and everything placed past the edge stayed on the screen (seen
2026-10-12). Leaving Edit Mode anchors every frame again under Blizzard's insets, the game lays them
out inside the screen, and as far as we can tell a change of insets alone doesn't lay a frame out
again (not yet confirmed in game). So a frame whose insets
we changed is anchored again at the points it has, which makes the game lay it out under the new
ones. That uses the widget's own `ClearAllPoints` and `SetPoint`, from the frame's metatable:
`EditModeSystemMixin:OnSystemLoad` replaces both on its frames with Lua that writes to the frame
(`SetSnappedToFrame`, `ClearFrameSnap`), which would taint it; the same points again leave its snap
bookkeeping right. A frame being dragged (`isDragging`, a field read) is left to the drag. Turning
the option off gives the frames we changed Blizzard's insets back and anchors them again, so they
come back inside the screen. Several frames are protected, so `ns.Later` waits for the end of combat
(Edit Mode can't open in combat anyway).

The combat log can't be closed in the default UI, and the dock's own functions (`FCF_Close`,
`FCF_UnDockFrame`) write to the chat frames and the dock. So `ChatFrame2` goes to the hidden holder
and its tab is scaled down to 0.001: the dock gives every tab its parent, width and anchor again on
each update (each tab hangs on the right edge of the one before), but never its scale, so the tab
takes no room and the next tab closes the gap.

The tooltips Forever's controller interface shows for new buffs come from the buff frame
(`BuffFrameMixin:Update` queues each aura gained or refreshed, `ShowNextAuraForTooltip` shows it
for 4 seconds) in `BuffFrameTooltip`, which nothing else uses: pointing at a buff or selecting it
with the controller shows `GameTooltip`. So the option makes `BuffFrameTooltip` transparent
(`SetAlpha(0)`, again from an `OnShow` hook each time it shows), the way the game's controller
action bar editor hides its own tooltip (`GamepadActionBarEditFrameMixin`): the tooltip still shows
and hides as the game wants, only unseen. It first went to the hidden holder like the frames above,
where it never showed at all; on the Steam Deck, pointing at a buff then showed no tooltip either,
and after the game menu closed the cursor jumped to the middle as usual but stayed in sight
(2026-10, cause not found in the UI code; both gone with the alpha, confirmed 2026-10-11). The game has a
setting for it too, `GamepadShowAutoAuraTooltip`, which isn't in its options. It's left alone:
`CVarCallbackRegistry` caches it and the buff frame reads it on every aura change, and a
`SetCVar` from our code would fire `CVAR_UPDATE`, whose handler writes that cache without the
`issecure()` check its reads have. If that handler runs with our taint, every later read would taint
the buff frame's update, where right-clicking a buff calls `CancelUnitBuff`.

Names in chat in class color are the game's own setting: `chatClassColorOverride` "0" means always
(see `ChatFrameUtil.ShouldColorChatByClass`). Turning the option off gives the setting its default.

The combined bag's sort button is a button of ours, a child of the bag anchored left of
`BagItemSearchBox`, that plays Blizzard's sound and calls `C_Container.SortBags()` (no restrictions)
with Blizzard's art and tooltip strings. Forever's own `BagItemAutoSortButton` sits at the bag's top
right under `GamepadBagBar` (a child of the combined bag in both interfaces, its backpack icon in
sight with keyboard and mouse), and the controller interface hides it. The option first moved
Blizzard's button instead, but `ContainerFrameMixin:UpdateSearchBox` anchors it at the top right
again on every `Update()`, without `ClearAllPoints`: from the bag updater's OnUpdate after a
`BAG_UPDATE` (a sort, loot), and on `BAG_NEW_ITEMS_UPDATED` and quest changes. A wake-up on
`BAG_UPDATE_DELAYED` raced that OnUpdate, so after a click the button went back under the bag icon
(2026-10-14). Blizzard's code never touches our button, so it needs no wake-up but the option. It's
made without a parent and parented afterwards, for SmartNavigation's `CreateFrame` hook (see
Forever's controller notes).

The combined bag from the top left: with keyboard and mouse, Blizzard lays the combined bag's item
buttons out from the bottom right of its money frame, leftwards and upwards
(`ContainerFrameMixin:GetAnchorLayout`, `BottomRightToTopLeft`), in the order bag by bag from the
backpack, slot by slot, locked extra slots last (`UpdateItemLayout`, `SortItemsByExtendedState`). So
the backpack's first slot, where a sort puts the hearthstone, is the bottom right corner. The
controller interface lays it out from the top left (`ContainerFrameCombinedBagsMixin:GetAnchorLayout`).
The option gives the keyboard and mouse bag the same corner by moving each button to the cell as
far from the top left as Blizzard's is from the bottom right, still anchored to the money frame, so
the frame's size and everything else on it stay Blizzard's. It reads the bag and slot with widget
methods (`GetAttribute("bagid")`, as Blizzard keeps it to avoid taint, and `GetID()`), reads the
`Items` and `isExtended` fields, and only calls `ClearAllPoints` and `SetPoint` on the buttons. The
buttons are plain `ItemButton`s, not protected, so this runs in combat too. Blizzard lays the bag
out again when it opens, when its size changes and when the interface changes; the OnShow and
OnSizeChanged hooks, `BAG_CONTAINER_UPDATE`, `BAG_UPDATE_DELAYED` and the interface change wake the
feature up, and it sets a button only when its anchor differs (works in game, confirmed 2026-10-11). The C_Container setting for the sort
direction (`SetSortBagsRightToLeft`, Blizzard's old "Reverse Clean Up Bags") is no way around this:
Forever's client keeps it (it reads back after a relog), but its sort ignores it (2026-10-11).

The mail bookmarks are side tabs of ours on `SendMailFrame` (Blizzard shows it only on the Send Mail
tab, so the tabs come and go with it), made from `LargeSideTabButtonTemplate`, the template of
Forever's own side tabs (Collections, Inspect, Group Finder; its `common-sidetab` art has `-c60`
versions in Forever's client). A tab is 55 high, so six fit along the mail frame (424) below its
title bar; the first starts 60 below the frame's top right, as the Group Finder's do, each next one
2 below. Each is made without a parent and parented afterwards (SmartNavigation's `CreateFrame`
hook), and its icon is the `classicon-<class>` atlas (what `GetClassAtlas` gives, square class
portraits) of a character QoL has seen log in (`QoLDB.characters`, name and normalized realm in
lower case), else `Interface\MailFrame\Mail-Icon`, the mail frame's portrait. On Forever every
character has a surname and first names repeat (two characters can both be Scoopz), and
`UnitName` gives the surname as its second value, where retail gives the realm. So with
`RegionalUniqueNamesEnabled()` the player's name is both with a space between, as the game's
`NameUtil.FormatUnitNameForDisplay` writes it and as To takes it (a mail to Scoopz Scoopzi went
out, 2026-10-14); the first name alone matched no
bookmark (seen in game 2026-10-14). Names are compared with their spaces trimmed and runs of them
made one. The template's mixin
writes its own fields on our frame (the tooltip text, the icon's pressed offset) and shows
`tooltipText` on hover. A left click (`SetCustomOnMouseUpHandler`, let go over the tab) puts the
name in To with `SendMailNameEditBox:SetText` and gives `SendMailSubjectEditBox` the keyboard, the
widget methods the game's own Reply and the To box's Enter use, from `ns.Later` (in combat too: the
boxes aren't protected). `SetText` runs the box's `OnTextChanged` (autocomplete, which does nothing
for text that wasn't typed, and `SendMailFrame_CanSend`) from our call. Nothing on the mail frame is
hooked or written. `OpenMailFrame` sits 46 right of the mail frame (`MailFrame.xml`), so a letter
left open covers the tabs' right edge, mostly their transparent part.

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
own font file and flags at the new size (`SetFont`); the game never sets these fonts itself. Set to
the game's size again, the text gets the game's font back with `SetFont` too, then its font object:
after `SetFont` the text still has that font object, and the client ignores a `SetFontObject` with
the one a text already has, so that alone left the larger font until a `/reload` (seen in game
2026-10-12; the stubs' `SetFontObject` does the same). A larger font makes the clock's button
wider and higher and the zone text's button and font string higher (`MinimapZoneText` has a height
of 12 and shows nothing of a line that doesn't fit), by the ratio to the game's size; a smaller one
leaves them as they are. The sizes are set before the positions, which go by the buttons' sizes.

The FPS and ping text is a frame of ours (a child of `MinimapCluster`, like the clock) that the rows
place like any other element. The game has no place for it, so it has no "Default" position (an
unknown or inside value hides it), and it's only made the first time it has a row. It shows
`GetFramerate()` and the higher of `GetNetStats()`'s home and world latency, as the game's own latency
meter on the micro menu does. A `C_Timer.After(1)` chain updates it while it has a row and ends itself
once it hasn't; no OnUpdate of ours runs every frame for it. The frame keeps the width of a reading of
999 and 999 and is as high as the clock's button, so its row never moves as the numbers change; the
text is anchored to the side of its spot (left, right or center), so it keeps to the minimap's edge or
to its neighbor. Its class color goes through the same code as the clock's, applied once more when the
frame is made, in case the colors ran before it was there. Its font size goes through the clock's code
too: the frame grows both ways with a larger font, and Default gives the text the clock's font object
(`WhiteNormalNumberFont`) back. The sizes are applied before the positions, so the frame is made there
when it gets a row and has its size before it's first placed.

Bar paging: each key bound to `ACTIONPAGE1` to `ACTIONPAGE6` gets an override binding on a frame of
ours that mirrors what the key without modifiers does (`GetBindingAction(base, true)`, so a bar
addon's override counts), which is how the game treats a modified key without a binding of its own.
The saved bindings are never changed. Our own overrides fire `UPDATE_BINDINGS` too; the update then
finds nothing to change.

The controller back buttons are four `SecureActionButtonTemplate` buttons of ours (`QoLBackButton1`
to `4`, `type` "action") on the last four slots of Action Bar 6, 7 or 8 (slots 153-156, 165-168,
177-180), so the controller bar's own slots and its paging are left alone and a spell can also be
put there from the standard bar. They hang off a plain frame of ours whose parent is
`GamepadMainActionBarFrame` (Blizzard_GamepadActionBars, loaded with the game on Forever, so it
exists at our `ADDON_LOADED`): they show, hide, scale and fade with the bar and nothing is hooked or
written on it. Their anchors are the bar's `PageUnit.LeftCenteredAnchor` and `RightCenteredAnchor`
(the d-pad and face button groups), which only Edit Mode moves, out of combat, and which the compact
layout moves too. A secure button makes its parents protected, so the holder is created, shown and
hidden through `ns.LaterOutsideWindows` (out of combat and away from the game's controller windows),
like the `type` and `action` attributes, which are set only when they change. The art is drawn on
regions of our own, copied from the bar's buttons
(`gamepad-actionbar-circleslot-*` atlases, `CircleMask`, the round portrait mask for the empty slot
and the cooldown swipe) and updated in combat (`ns.Later(..., true)`): icon, usability color, count
(`GetActionDisplayCount`, maybe secret, only passed to `SetText`), cooldown
(`C_ActionBar.GetActionCooldownDuration` into `SetCooldownFromDurationObject` on our own Cooldown)
and the selected rim. Dragging calls `PickupAction`/`PlaceAction` only out of combat, and with
`lockActionBars` on only with the `PICKUPACTION` modifier, as the game's bars do.

Bindings: `Bindings.xml` adds `CLICK QoLBackButtonN:LeftButton` under Key Bindings > AddOns, named
by `BINDING_HEADER_QOL` and `BINDING_NAME_...` globals set when `BackButtons.lua` loads. Whether keys
saved there fire in the controller interface wasn't sure, so every key bound to a button also gets
an override binding on a frame of ours (`SetOverrideBindingClick`, not priority: Blizzard's gamepad
windows set priority overrides of their own and win while they're open). A button with no key gets
its paddle key (`PADPADDLE1` to `4`, SDL numbering: 2 and 4 left, 1 and 3 right) when the paddle has
neither a saved binding nor one in the controller set (`C_KeyBindings.GetBindingByKey(key,
Enum.BindingContext.GamepadModeInGameCore)`, in a `pcall`). A trigger held while a back button
sends its key makes it a modified key; with nothing bound to that, the game uses the key without
modifiers, so no modifier variants are needed. As with bar paging, the overrides fire
`UPDATE_BINDINGS` and the next update finds nothing to change; they wait for the end of combat
and, in the controller interface, until no window of the game has the controller.
Steam Input on the Steam Deck sends keyboard keys for the back buttons, which is why a key binding,
not a fixed key, is the way in.

The rings (`Features/Ring.lua`) pick an action in combat, so the choice is made by secure code.
They are the player's own, as many as they make, saved for the account in `QoLDB.rings`:
`{ entries = { { kind = "spell", id = 133 }, ... }, mouse = "F", stick = "PADLSHOULDER" }`.
`Features/RingEntries.lua` knows the kinds (spell, item, toy, mount, macro by name): whether this
character has one, its secure action, icon, name, tooltip, how it looks on a slot, how to put it on
the cursor and how to read it off the cursor. A character's ring is the entries it has, the first
12 (`Ring.MAX`), so it has no empty slots and other characters' entries stay saved.

- One secure header (`SecureHandlerBaseTemplate`, `QoLRing`, hidden, DIALOG strata) and one
  `SecureActionButtonTemplate` button of ours, `QoLRingButton` (child of UIParent, no size), with
  `useOnKeyDown` false, so the action happens when the key is let go. Its OnClick is wrapped by the
  header (`SecureHandlerWrapScript(opener, "OnClick", header, Ring.CLICK)`). For each ring `r` with
  `n` entries this character has, the header has `qol-count-r` = `n`, and the button
  `*type-rsN` and `*spell-rsN` (or `item`, `toy`, `macro`) for slots 1 to `n`: `"spell", id`
  (`CastSpellByID`), `"item", "item:id"` (`SecureCmdItemParse`; it equips what's worn), `"toy", id`
  (`UseToy`), a mount as its spell, `"macro", name` (`RunMacro`). Attributes set before and no longer
  wanted are cleared, so a ring that shrank leaves nothing behind.
- Each key of a ring is an override binding (`ns.Buttons.NewOverrides`) that clicks the button with
  a made-up mouse button naming the ring and the aim: `SetOverrideBindingClick(owner, false, key,
  "QoLRingButton", "2mouse")`. A ring with nothing this character has gets no bindings, so its keys
  keep doing what Key Bindings gives them. The keys aren't game bindings (Bindings.xml doesn't list
  them): the ring decides which keys, and a key belongs to one ring at a time.
- The snippet reads the ring and the aim with `strmatch(button, "^(%d+)(%a+)$")` and does nothing
  without that ring's `qol-count-r`. On the key going down: anchor the header at the cursor
  (`"$cursor"`, a fixed point on the screen) or the middle of UIParent, note the button in its
  `qol-open` attribute, show it, return false (no action). On the key going up (only for the ring
  that's open): hide it, read the aim and return the aimed slot's button, `"2s3"`;
  `SecureButton_GetButtonSuffix` makes that the `-2s3` suffix of the attributes above. Aim with the
  mouse: `owner:GetMousePosition()`, which is 0 to 1 across the header and nil outside it, hence the
  header's 8192 units; less than 20 units from the middle is none. Aim with the stick:
  `GetGamePadState().sticks[i]` (the restricted environment's `C_GamePad.GetDeviceMappedState`), `i`
  the stick `C_GamePad.StickIndexToConfigName` calls "Camera" (counted from 0 there, from 1 in
  `sticks`, found out of combat into the header's `qol-stick`); `len` under 0.5 is none. The slot is
  `floor((deg(atan2(x, y)) % 360 + step / 2) / step) % n + 1` with `step = 360 / n` (the global
  `atan2` works in degrees, so `math.atan2`): slot 1 at the top, the others clockwise, evenly. The
  header's `qol-on` attribute is false while the rings are turned off.
- Our code only draws. The art is a plain frame under the header, so it shows and hides with it
  without being protected. Every slot and spoke (12 of each) is made with it, so opening a ring in
  combat makes no frames. Its OnShow lays it out for the open ring (`Ring.Layout`: slots `96` units
  out at `(i - 1) * 360 / n` degrees, spokes between them, the frame scaled by `max(1, n / 10)` so
  the slot rims don't overlap past ten) from the entries the last update gave the secure code, and
  shows each entry's icon, count, usability and cooldown (`RingEntries.Refresh`). Its OnUpdate
  works out the aimed slot with the same sums (`Ring.SlotAt`, cursor from `GetCursorPosition()` over
  the effective scale against `GetCenter()`), lights its wedge and puts the entry's name in the
  middle. If another ring's key goes down while one is open, `qol-open` changes and the art lays
  itself out again.
- Values that may be secret in 12.x (a spell's usability, charges and cooldown, an item's count)
  are tested only through `ns.IsUsable`; cooldowns go to the widget as the game gives them
  (`C_Spell.GetSpellCooldownDuration` into `SetCooldownFromDurationObject`, `C_Item.GetItemCooldown`
  into `SetCooldown`), counts to `SetText`.
- While the stick ring is open, a plain frame of ours has `EnableGamePadStick(true)` and an
  `OnGamePadStick` that returns true for the "Left" and "Movement" stick (passed on to the game, so
  the player can walk) and nothing for the others (kept from the camera), as `Blizzard_RadialWheel`
  does. It keeps the stick after the ring closes until the stick is at rest (`len` under 0.1) or for
  half a second, like `InputAxisBinding`'s `waitForCentering`, so letting go of the key with the
  stick out doesn't swing the camera.
- The rings' editor (`Features/RingEditor.lua`) is the settings window's Ring page; `/qol ring`
  opens the window there (`SettingsPanel:Toggle("ring")`: from another page it goes there instead of
  closing). Until 2026-10 it was a window of its own, opened by a button on that page, which only
  held the switch besides: the editor is now the page. Its title bar (`SettingsPage.TOP`, 54) keeps
  the page's title, with the switch where the other pages have their Defaults button (a `"title"`
  row; no Defaults button, which would only turn the rings off). Below it, filling the rest of the
  page (665×547), lies `QoLRingEditor`: one spell book page, `spellbook-page-condensed-c60`
  stretched over it; its dark top bar is its upper 8.1% and the parchment lies inside rims of 9.4%
  (top), 2.6% (bottom), 3% (left) and 2.6% (right), measured from the texture of client 1.60.1.
  Without that atlas (retail) it's a dark bar over plain parchment colors. Text on the paper is
  ink: `SPELLBOOK_FONT_COLOR` (or Forever 1.60.1's value) without the font's shadow
  (`RingPicker.Ink`). The page wraps `Page:Refresh` to refresh the editor too, so it's up to date
  whenever the window shows the page and when the switch changes.
- The room is the game's canvas (665 wide) where the window was 860, so the left column is 256
  wide and the list 350 (2×9 rows of 175, which cuts long names shorter; the tooltip has them). The
  ring is drawn at 0.66 (`SetScale` on its frame, anchored only to the middle of a room at the
  page's scale, as offsets from a scaled frame shrink too), in the room the biggest one takes. The
  list's five tabs (at least 92 units each, as wide as their side art) reach 464 into the top bar
  from the list's right edge, past its left one, over the left column: so "Ring 1 of 3" and its
  arrows stand on the parchment above the ring instead of in the bar. The keys' names are left of
  their boxes, on two lines when they need them.
- The editor's left column holds the ring (the same art, with Buttons for slots, plus one empty
  slot to add to), with "Ring 1 of 3" and the spell book's page buttons (`UI-SpellbookIcon-*Page-*`)
  above it. It shows the ring as this character sees it and maps a slot to its place in the saved
  list, so an entry dropped on slot 3 goes before the entry shown there, with other characters'
  entries kept where they are. Dropping reads `GetCursorInfo()` (a spell that's a mount's,
  `C_MountJournal.GetMountFromSpell`, is the mount; an item that's a toy, `PlayerHasToy`, the toy);
  an entry already on the ring moves. Taking one off puts it on the cursor (`C_Spell.PickupSpell`,
  `C_Item.PickupItem`, `C_ToyBox.PickupToyBoxItem`, `PickupMacro`; a mount by its spell). It only
  changes our saved table and asks for an update; out of combat only. The settings open in combat,
  so the page does too: it shows the rings, its buttons and key boxes are off (`SetEnabled`), a
  click, drop or drag changes nothing, and the note says why. `PLAYER_REGEN_DISABLED` comes while
  `InCombatLockdown` is still false, so that handler locks the page itself; `PLAYER_REGEN_ENABLED`
  refreshes it, with what changed meanwhile.
- Escape and the other keys are the settings window's (`ns.NewWindow`, below): Escape closes it,
  every other key goes on to the game, so P opens the spell book with the window open (it isn't in
  `UISpecialFrames`, which the spell book would close). The key boxes' listener sits above the
  window and keeps every key, so there Escape only cancels. Leaving the page or closing the window
  (the editor's `OnHide`) stops waiting for a key and takes the focus from the search box.
- The editor's right column is `Features/RingPicker.lua`, built after Forever's spell book: tabs from
  the game's `TabSystemTopButtonTemplate` standing on the parchment's top edge (the tab system they
  call, their parent, is a strip of ours with `SetTab`, `GetTabWidthConstraints` and
  `PlayTabSelectSound`; five tabs are 92 units each at least, so they end at the list's right edge
  instead of starting at its left one), a `SearchBoxTemplate` (case-insensitive substring of the
  name), and 2×9 rows filled down the first column, then the second, a page at a time, with the
  spell book's page buttons and the mouse wheel. Paging instead of a scroll box: the controller's
  cursor gets to every row and the page buttons, and it's how the spell book does it. A row is the
  spell book's entry: icon (`spellbook-item-spellicon-mask`) in `spellbook-item-iconframe-c60`,
  `spellbook-item-iconframe-hover` and `spellbook-item-backplate` as highlight, name and subtext in
  ink, and a check mark when the entry is on the ring shown. A click puts it at the end of the ring
  (refused past 12 shown) or takes it off; a drag picks it up (`RingEntries.Pickup`). The list is
  read again when the page is shown and on the rings' known events while it is.
- What a character has (`RingEntries.Owned`): the spell book's skill lines that aren't hidden
  (`C_SpellBook.GetSpellBookSkillLineInfo`), their spells without passives and other
  specializations' (a mount's spell as the mount), a flyout's known spells in its place
  (`GetFlyoutInfo`, `GetFlyoutSlotInfo`); items with a use (`C_Item.GetItemSpell`) in the bags and
  the equipment slots 1 to 19, toys left out; toys through the Toy Box's own filter
  (`C_ToyBox.GetNumFilteredToys`, `GetToyFromIndex`), which is the only list of them, so its
  filters and search apply (changing them would change the Toy Box); collected mounts
  (`C_MountJournal.GetMountIDs`); the account's macros, then the character's (`GetNumMacros`, from
  `MAX_ACCOUNT_MACROS + 1`). Spells and macros in the game's order, the rest by name.
- The editor's key boxes are the game's `KeyBindingFrameBindingButtonTemplate`, with a listener of
  our own like the settings pages' (below), which also takes gamepad buttons
  (`EnableGamePadButton`, `OnGamePadButtonDown`): the first key or button pressed is the key, Escape
  cancels. Setting it only changes the saved ring (taking the key from the ring that had it); no
  `SetBinding`, so nothing for `SaveBindings`.
- The header, the button, their attributes and the override bindings are made and changed through
  `ns.LaterOutsideWindows`, out of combat and away from the game's controller windows, on the
  option, on the editor's changes and on what changes what a character has (`SPELLS_CHANGED`,
  `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`, `UPDATE_MACROS`, the toy and mount events). In
  combat a ring keeps what it had. The settings window is no such window (the controller manager
  doesn't know it), so the rings change while the page is open.

The rings' textures come from Forever's own art (build 1.60.1.70291). `Media/Ring.tga` (512×512,
drawn 343 units wide) is a dark disc, the radial menu's wheel (`gamepad-radial-menu-wheelbg`, file
6227249) and the minimap's bronze ring (`ui-hud-minimap-frame-circle-c60-2x`, file 8026708) scaled
over the wheel's rim, which ends 150 units out, with the wheel's eight spokes painted over by its
own radial profile (the median of the sectors between them). `Media/RingSpoke.tga` (256×256, drawn
100 units wide, its middle 93.5 units out) is one of those spokes turned to point up; a ring of `n`
draws `n` of them between its slots, turned with `SetRotation(-angle)` (counterclockwise in
radians). `Media/RingLit1.tga` to `RingLit12.tga` (256×256) are the radial menu's lit wedge
(`gamepad-radial-menu-selected`, drawn for eight slots) remapped around the ring's middle for `n`
slots: each side's bronze border kept at its width and the fill between stretched or squeezed to
the slot's sector, `RingLit1` the whole wheel. `Ring.lua`'s `LIT` table has each one's size and how
far out its middle sits. `Media/RingSlot.tga` (128×128, 58 units around a 40-unit icon) is the
minimap's day and night rim (`ui-hud-minimap-frame-cycle-c60-2x`). They were cropped, scaled,
remapped and laid over each other with small Pillow and numpy scripts, not kept in the repository.

## Settings pages

The settings are a window of our own (`UI/SettingsWindow.lua`), `QoLSettings`, which `/qol` opens and
closes. Under Options > AddOns there's only the information page (`UI/InfoPage.lua`), with a button
that opens the window. Until 2026-10 the pages were canvases below that page in the game's settings;
they moved out because the game, on Forever with the controller interface on, froze now and then when
its settings closed after a change in them (below). Out there, nothing of ours runs while the game's
settings are open, and closing our window is a plain `Hide` of a frame of ours.

- The window is `ns.NewWindow` (`Core/Window.lua`) with
  `PortraitFrameFlatTemplate`: the game's portrait frame, whose `UI-Frame-Metal-*` border and portrait
  corner Forever draws in bronze, with the flat dark background of the game's settings
  (`FlatPanelBackgroundTemplate`). Inside, it copies the game's `SettingsPanel`
  (`Blizzard_SettingsPanel.xml`, 920×724) without the Game and AddOns tabs, the search box and the
  buttons below: 920×696, `Options_InnerFrame` (886×618, at its own size) 60 below the top instead of
  64, the list (199 wide) 12 below that, and the page right of it, 16 from the list and 22 from the
  window's right edge, 665×601, the room the game gives a canvas (`SettingsPage.MAX_HEIGHT` is 600).
  Forever's client has `-c60` versions of the options art (`options_innerframe-c60`,
  `options_categoryheader_1-c60`, `options_list_hover-c60`, the tabs and the divider) that no UI
  code names, as it has for the metal frame: the client swaps them in for the plain names, which is
  what we use. `options_list_active` has none.
- The list is drawn as the game's (`Blizzard_CategoryList`) but with frames of ours, not its
  templates: `SettingsCategoryListButtonMixin` reads its scroll box's element data and a file local
  of the game's settings. A header (`Options_CategoryHeader_1`, drawn on the list itself so the
  buttons go over its art, "Settings" in `GameFontHighlightMedium` at 20), then a button per page,
  175×20, 2 apart, its name at 36: gold (`GameFontNormal`), white on `Options_List_Active` when
  selected, `Options_List_Hover` under the mouse. A click selects with the game's sound.
- One page is shown at a time; the window refreshes it when it shows it (a selection, or the window
  opening on the page it was on), and a page follows `Options:Watch` while visible.
- Escape closes the window, other keys go on to the game (`ns.NewWindow`): not through
  `UISpecialFrames` or `RegisterGameMenuEscHandler`. The window opens in combat too. Keeping a key (`SetPropagateKeyboardInput(false)`) is restricted
  in combat, so there every key goes on to the game, Escape too, and the X closes the window; after
  Escape closed it, keys are let through again from the next frame (`ns.Later`), so the window never
  opens in combat holding the keyboard.
- The information page's button opens the window through `ns.LaterOutsideWindows`: with keyboard and
  mouse on the next frame, over the game's settings (we can't close them: hiding `SettingsPanel` from
  addon code taints its `Commit`), and Escape closes them first, then ours. In Forever's controller
  interface only once the game's settings and menu are closed, as Easy Controller's window does: they
  have the controller while open, so its cursor couldn't get to ours, and nothing of ours runs while
  they're open. A line next to the button says so while that interface is on (checked on each
  showing, as it switches without a reload).
- The information page is a short introduction, the button, the chat commands, and the author's
  other addons with their icon (copies in `Media/`), an Installed label while one is loaded (checked
  on each showing, as addons that load after us aren't loaded when the page is made) and their link
  in a read-only edit box to copy, as the game can't open web pages. It has no options, so no Defaults
  button. It doesn't scroll: it's about 540 high, within `SettingsPage.MAX_HEIGHT`, with two lines of
  text per addon (the tests can't measure wrapped text, so this one isn't checked). Not yet tried in
  Forever's controller interface: what a press on a link box does (an `EditBox` takes the keyboard
  focus).
- All frames (the window, the pages, the information page) are made on `ADDON_LOADED`, never while a
  window of the game has the controller, so SmartNavigation's `CreateFrame` hook rebuilds no window
  for them.

The options are grouped by part of the game: Automation (merchant and quests), Interface
(the bars to hide, the combined bags, tooltips, health bars), Chat (the chat window, `/rl`), Mail
(the bookmarks' names), Action Bars, Minimap, World map (only where `MapPins.IsAvailable()`), Viewport, Ring and Controller (only
on Forever). Every page is built by `UI/SettingsPage.lua`: two columns of rows, or rows across the
page (`"wide"`, the Viewport page, as its sliders need the room, and the World map page, with two),
or an option in the title bar instead of the Defaults button (`"title"`, the Ring page's switch,
with the rings' editor below it), each an option's name with a control from the game's own
templates (`SettingsCheckboxTemplate`, `WowStyle2DropdownTemplate`,
`MinimalSliderWithSteppersTemplate`, `ColorSwatchTemplate` opening `ColorPickerFrame`,
`InputBoxTemplate` for a name), so they look like the game's pages and fit without scrolling
(`SettingsPage.MAX_HEIGHT`, checked by the tests). A text row saves when its box loses the keyboard
(Enter, Tab, a click elsewhere), trimmed, and Escape puts the saved text back; Tab goes on to the
page's next text row through the template's own `nextEditBox` and `previousEditBox`. A refresh
leaves a box alone while it has the keyboard. Not yet tried in Forever's controller interface.
A page can start with a few lines that say what its options are for (`Page:Text`, the Mail page's):
the font string gets the column's width from `SettingsWindow.PAGE_WIDTH`, so its wrapped height
(`GetStringHeight`) is known while the page is built, before the window lays it out.
A section that follows another one in its column gets 16 more above its header, so a page reads
as groups rather than one long list, and sections side by side start at the same height where the
columns' rows would leave their headers out of line (`Page:Align`: the Minimap page goes in pairs).
All names use one font: the game's list draws dependent options smaller. A page resets with its own
Defaults button, which asks with a second click: the game's confirmation dialog would spread taint.
The game's "all settings" reset doesn't reach our pages any more, and they don't show up in the
settings search. Tooltips are `GameTooltip`.

The history below is from the time the pages were in the game's settings; the workarounds it led to
stay since they cost nothing.

No page is the game's vertical list (`RegisterVerticalLayoutSubcategory` with proxy settings).
Viewport was one, with sliders and a color swatch, and on Forever with the controller interface on
the game stopped responding (no Lua error, no Errors folder) when the settings closed after that
page had been shown, whichever page was open when closing, even with nothing changed. The canvas
pages closed fine. The list's slider and swatch controls bring controller wiring of their own
(SmartNavigation focus overrides, a prompted binding footer for the D-pad on `UIParent`); the line
that hangs wasn't found, so we stay off the list. On our canvas the controller cursor reaches the
slider's arrows (one pixel a click) and the swatch; a slider set from `Options` (a refresh) doesn't
write itself back.

The game's dropdown menu froze it the same way: with the controller interface on, opening one of
our dropdowns (the back buttons' bar on the Controller page), picking a choice and closing the
settings stopped the game. In that interface the menu (`Blizzard_Menu`) brings the same kind of
wiring as the list's slider: `MenuProxyMixin:SetupGamepad` creates a prompted binding footer whose
binding groups take the face buttons while it's open, and `GamepadFrameControlsManager` suspends
the settings panel's focus for it (`MenuProxy.OnShow`) and never unsuspends it on close. Which of
these hangs isn't known (the game's own pages open the same menu), but it is the one thing of the
game's controller wiring our pages used, and it was the step that turned closing into a freeze. So with the
controller interface on (`ns.IsControllerUI()`, checked on each click so switching interfaces needs
no reload), our dropdowns never open the menu: `Page:Dropdown` replaces `OpenMenu` on our own
dropdown with a step to the next choice, wrapping around, for the controller cursor's press, the
mouse and the touch screen alike. The mouse wheel's step (`Rotate`) opens no menu either and stays.
With keyboard and mouse the menu opens as usual.

Without the menu the game still froze now and then on closing the settings after the back buttons'
bar had been changed (not reproduced reliably, and with no error). Our change then ran while the
settings were open: new `action` attributes on our secure buttons and new override bindings, set
while `GamepadFrameControlsManager` had the settings as its window, and again on the
`UPDATE_BINDINGS` that closing fires. So the back buttons and the rings, the only features that set
bindings or secure attributes in the controller interface, change nothing while a window of the
game has the controller: they go through `ns.LaterOutsideWindows` (`Core/Later.lua`), which holds
their updates while `ns.ControllerWindowOpen()` (`GamepadMode.FrameControlsManager:GetActiveFrame()`,
if shown: the settings, the game menu, the bags...). Bindings already set stay while a window is
open (they aren't priority overrides, so the window's own win); only changes are held back. A
`C_Timer.After` check every half second lets them go once one check found no window and the one
before found none either, so they run at least half a second after the window closed, from our
OnUpdate, whatever order the game closes it in. Without the controller interface they run on the
next frame as before. With this the back buttons froze it no more (2026-10, Steam Deck).

Then it froze again after the buff tooltips' option was turned on (a `SetParent` of
`BuffFrameTooltip` while the settings were open). Holding every `ns.Later` request while the settings
or the game menu were open didn't stop it: toggling that checkbox off and on and closing froze it
with nothing of ours changed, and so did toggling the game's own Invert X Axis checkbox on its
Controller page (2026-10-11, Steam Deck). So the freeze is most likely Forever's own, on closing the
settings after a change in the controller interface, and no rule of ours prevents it; the hold was
dropped again, as it only took away live changes. The workarounds above (canvas pages, dropdowns
that step, the back buttons waiting for windows) stay since they cost nothing, but they probably
weren't the cause either. Not yet tried: the same with all addons off, which would rule out taint.

The world map pins are buttons on a frame of our own on the map's canvas, not pins from the map's
pools. Their places are zone coordinates in percent (as `/way` reads them), from Forever's tables;
the continent maps get them through `C_Map.GetMapRectOnMap`. Names come from `C_Map.GetAreaInfo`, so
they're in the player's language. Forever's UiMap IDs (1411 and up) don't exist on retail, so there
`MapPins.IsAvailable()` is false: the settings leave the World map page out and the map is never
touched.

The Controller page is registered only when `GamepadMainActionBarFrame` exists (Forever); on retail
there's nothing for it to change.

The Controller page also has the back buttons' key bindings (`Page:Binding`, rows across the page):
the same `CLICK QoLBackButtonN:LeftButton` commands as Key Bindings > AddOns, each row named by its
slot on the chosen bar (the label is a function, asked again on each refresh, so it follows the
Slots dropdown). Each row has two buttons from the
game's own `KeyBindingFrameBindingButtonTemplate` and works like a row of the game's Key Bindings,
with code of our own rather than the game's `KeybindListener` (a Blizzard frame: starting it writes
its fields, which the rules above forbid): a click on a button shows a parentless frame of ours at
`FULLSCREEN_DIALOG` strata with an `OnKeyDown`, which takes the keyboard until a key comes
(modifiers alone wait for the rest, through `IsKeyPressIgnoredForBinding` and
`CreateKeyChordStringUsingMetaKeyState`), Escape comes, the
button is clicked again, the page hides, the row is greyed out or combat starts. The key is set as
the game's `KeybindListener:ProcessInput` sets it: both old keys cleared, the new key taken from
whatever had it (`SetBinding(key, nil, context)`), the keys bound again in their slots, in the
action's context (`C_KeyBindings.GetBindingContextForAction`). A right-click clears a slot. Gamepad
buttons are not listened for: the controller cursor needs A (a second press on the button stops
waiting) and B, and the Steam Deck's back buttons send keyboard keys anyway; a paddle needs no key.
Each change is saved right away (`SaveBindings(GetCurrentBindingSet())`), as the game's settings
save the bindings when they close: our window isn't theirs, so nothing else would save them. That
fires `UPDATE_BINDINGS`, and the back buttons' override bindings follow from there through
`ns.LaterOutsideWindows`. All frames (the buttons and the listener) are created when the pages are
built at login, not while a controller window is open, so SmartNavigation's `CreateFrame` hook
rebuilds no window for them.

## Tests and lint

Tests and lint need only Lua 5.1 (what WoW runs); newer Lua works for the tests too.

```bash
lua tests/run.lua
```

```bash
luacheck .
```

CI runs both on Lua 5.1.5 on every push and pull request (locally: Lua 5.1 and luacheck from
`~/.lua51`, built with hererocks).

The stubs make action bars read-only (a write to a bar field fails the test), and protected frames
fail on `SetPoint`/`SetParent` (and `Show`/`Hide`) in combat, so the taint rules above are checked,
not just written down. A frame made from `SecureActionButtonTemplate` marks itself and its parents
protected and fails on `SetAttribute` in combat; `Stubs.NewGamepadBar()` (between `LoadAddon` and
`Login`) makes Forever's controller bar with its `PageUnit` anchors. `Stubs.Fire` delivers an event
to a frame registered with `RegisterUnitEvent` only when its first argument is one of that frame's
units, as the game does, and `Stubs.Listens(event, unit)` says whether any of our frames would get
the event for that unit, so a spec can check that other units' events never reach QoL.

## Trying it in game

Link or copy the repository into the client's AddOns folder as `QoL` (on the Forever beta:
`_classic_beta_/Interface/AddOns/QoL`). The client only loads what the TOC lists, so `docs/`
and `tests/` do no harm there. An unpackaged copy reports its version as `@project-version@`; only
the packager fills it in.

Things only the real client can confirm:

- The viewport margins line up with the world at your resolution and UI scale, and stay with Alt+Z.
- With Forever's controller interface on (Options > Controller), the viewport and the Action Bars
  options on: open the settings with `/qol` and from the information page's button (it opens once
  the game's options and menu are closed, and says so), and check that the controller cursor reaches
  the list and the pages. Look at every page (Viewport included: step a margin with its
  arrows, open the color picker; on the Controller page turn on the back buttons, press the bar
  dropdown a few times, with A and with the touch screen, and bind a back button's key: A on a key
  box, then the back button), go to another page, and close the window with its X. The dropdowns step through their choices without opening a list.
  The game must not freeze, also when opening and closing the game's options and menu afterwards, and the viewport stays. The back buttons take the new bar within a second. A back button's key still works after a `/reload` (saved right away). The game's own controller action
  bars show; the flips and borders come back after switching to keyboard and mouse.
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
- Mana in bear and cat form (a druid): the mana bar follows casting and regeneration while
  shapeshifted (whether the server sends mana updates in a form), shifting in and out in combat
  shows and hides it, the threat glow fits the frame in combat with and without the bar, a change
  of the Status Text setting shows on the bar at once, and a vehicle shows its own art. Something
  in the bottom container (a pet frame) isn't covered by it.
- Frames past the screen edge, with Snap to Elements off: an action bar, the minimap and a unit frame
  dragged to each edge go up to 30 past it, also right after changing a setting of theirs in Edit
  Mode. After saving, a `/reload` and switching layouts (by hand and with AutoSetup on a resolution
  change), they come back to the same place, not pulled in by the screen. Turned off, they are back
  inside the screen; no "tainted by" error in combat afterwards (the action bars are protected).
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
  minimap buttons of other addons along the square, the rotate minimap setting, and a
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
- The settings window: Forever's bronze frame and the bronze options art (inner frame, the list's
  header and hover highlight; the selected page's highlight is the plain one), lined up as in the
  game's options, also at other UI scales; the portrait icon; dragging the title bar; `/qol` opening
  and closing it, Escape and the X closing it; opened from the information page's button over the
  game's options, Escape closing those first. In combat it opens, every key (Escape too) goes to
  the game, the X closes it. The pages: two columns in English and German (no name cut off),
  checkboxes and dropdowns working, dependent options greyed out, and the Defaults button asking
  first. The Ring page: the switch in the title bar lined up with the title, the parchment below
  the divider, nothing past the page's edges (English and German).
- The zeppelin and tram pins' icons next to the boats', on zone and continent maps.
- Hidden button borders on every bar (also the stance and pet bars): square icons, the mouseover,
  pressed and checked (auto attack, an active stance) textures, the red auto attack flash, the
  green glow of an equipped item, the cooldown swipe over the whole icon, no casting animation;
  after changing "Hide Bar Art" of the main bar in Edit Mode, and back to the normal buttons
  without a `/reload` when turned off. No "tainted by" error in combat afterwards.
- The zone text and the clock at every font size, in the header bar and above and below the
  minimap (rows with something else in them), back to the game's look when set to Default.
- FPS and ping in every row position, next to the clock in the same spot, at the minimap's edge
  with one- and three-digit numbers, updating every second, in class color, at every font size (the
  row making room, nothing cut off), and gone when hidden.
- World map pins: in the right places on the zone and continent maps (the entrance positions are
  the instance portals, like retail's encounter journal pins), the tooltips' names in German, and a
  click opening the destination's map. Open the map in combat too.
- Controller back buttons (Options > Controller), on a Steam Deck with F13 to F16 (or other free
  keys) given to L4, L5, R4 and R5 in Steam Input, bound under Key Bindings > AddOns > Quality of
  Life:
  - The keys press the buttons in the controller interface, alone and with LT, RT or both held, and
    the button looks pressed while held. If they don't, the saved bindings or the overrides don't
    reach the controller interface; that's the first thing to find out. Does the client see F13
    and up from Steam Input at all (try binding them to something else)?
  - A controller with paddles the game sees (Xbox Elite, DualSense Edge) without anything bound:
    which paddle presses which button (the PADPADDLE numbering is SDL's, not checked in game).
  - The buttons sit clear of the d-pad and face buttons in the normal and the compact layout, at
    several Edit Mode sizes, and the labels don't overlap anything; they hide with the bar (keyboard
    and mouse, vehicles, cutscenes).
  - Switching to keyboard and mouse without a reload: the keys press nothing (try F13 to F16 on
    the keyboard's bars); switching back, they press the buttons again.
  - Icons, counts, cooldowns (also in combat: the cooldown call on our Cooldown), out-of-mana and
    unusable colors, the auto attack rim; dragging a spell on and off, with the action bars locked
    (Shift) and unlocked; the tooltip.
  - The keys still work after opening and closing a gamepad window (bags, map, the settings), and
    no "tainted by" error shows up in combat afterwards.
- The rings (the Ring page on, rings made with `/qol ring`):
  - The Ring page: the parchment page and its top bar line up below the title (also at other UI
    scales); the tabs in the bar clear of "Ring 1 of 3" and its arrows; the smaller ring with 12
    actions inside its column; the keys' names on two lines where needed (German too). The list: each
    tab, the search box, the page buttons and the mouse wheel, clicking an entry on and off the
    ring, its check mark, dragging one onto a slot, a full ring refused, the tooltips; with the
    controller cursor, the tabs, rows and page buttons. A spell learned while it's open shows up.
  - The editor: dragging spells (from the spell book and from action bars), items from the bags,
    toys from the toy box, mounts from the mount journal and macros onto the empty slot, onto a
    slot and off the ring; picking up and putting down with clicks, also with the controller cursor;
    right-click; the tooltips; a 13th action refused; new, switching, deleting; in combat the
    buttons off and nothing changing, back once it ends. P opens the spell book with the page open,
    and both stay open; moving with the keys while it's open. Entries for another class show on that
    class only, and the page counts them.
  - Keys in the editor: a key, a key with a modifier, a controller button (in the controller
    interface too), Escape, right-click, a key taken from another ring. While the rings are on the
    key opens its ring instead of its Key Bindings action; with them off (or the ring empty for this
    character) it does that action again.
  - Mouse key: the ring opens at the cursor, the wedge and name follow the mouse, letting go uses
    that action (also in combat: a spell, an item, an equippable item, a toy, a mount, a macro),
    and letting go in the middle does nothing. Near a screen edge, and at several UI scales. Rings
    of 1, 2, 3, 8 and 12 actions: the slots and spokes go round evenly, the wedge sits on the aimed
    slot in every direction, 11 and 12 are drawn bigger.
  - Controller key, in the controller interface and with keyboard and mouse: the ring opens in the
    middle, the right stick aims, the camera stays still while aiming and doesn't swing when the key
    is let go with the stick out, and the left stick still moves the character. If the camera stick
    isn't the second in `GetGamePadState().sticks`, the aim is wrong or none: check `qol-stick`.
  - Learning a spell, using up the last of an item, equipping one: the ring grows and shrinks
    after the event (after combat when it happens in combat).
  - The art: wheel, bronze rim, spokes and slot rims line up, cooldowns and counts show, long names
    wrap in the middle.
  - No "tainted by" error in combat after using a ring or the editor.
- Hide new buff tooltips (Options > Controller), in the controller interface: gaining or refreshing a
  buff (a food buff, a flask, a party member's buff) and a debuff shows no tooltip; selecting a buff
  through the buff frame (the radial's Buffs) and pointing at one with the mouse still do. After the
  game menu closes, the cursor goes to the middle and hides (these three confirmed 2026-10-11, Steam
  Deck). Turning it off brings the pop-ups back without a reload. Right-clicking a buff away in
  combat still works.

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
on every pushed tag: it replaces `@project-version@` with the tag, leaves out `docs/`,
`tests/`, `README.md` and `Media/Icon.svg`, and creates the GitHub release. For CurseForge uploads, add
`## X-Curse-Project-ID` to the TOC and the `CF_API_KEY` repository secret.
