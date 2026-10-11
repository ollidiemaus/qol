# Developing Quality of Life

Notes for working on the addon. What it does for players is in the [README](../README.md).

## Layout

| Folder | What's in it |
|---|---|
| `Core/` | Namespace and printing (`Init`), the event frame (`Events`), saved options with defaults and change watchers (`Options`), deferred changes (`Later`), the hidden holder for hidden frames (`Hider`), what the back buttons and the ring share (`Buttons`: an action slot's look, override bindings), `/qol` (`Slash`) and startup (`Lifecycle`) |
| `Data/` | Static game data: `MapPins` (dungeon entrances, docks, portals; how it was made is at the top of the file) |
| `Features/` | One file per feature: `Merchant`, `Quests`, `Tooltips`, `HideFrames` (also the chat buttons), `BuffTooltips` (the controller interface's tooltips for new buffs), `CombatLog`, `ChatClassColors`, `CombinedBagSort`, `ClassHealthBars`, `Minimap` (shape, positions, class colors and font sizes around the minimap), `MapPins`, `Viewport`, `ActionBars`, `ButtonBorders`, `BarPaging`, `BackButtons` (the controller back buttons, Forever only), `Ring`, `ReloadCommand` |
| `UI/` | `SettingsPage.lua`, our own settings page (two columns, or rows across the page, and key binding rows); `Settings.lua`, the pages under Options > AddOns built with it |
| `Locales/` | English strings, German overrides |
| `Media/` | `Icon.tga`, the addon list icon (the TOC's `IconTexture`, 128×128, 32-bit), and `Icon.svg`, its source (not packaged); `Zeppelin.tga`, `Tram.tga`, `MinimapSquareBorder.tga` and the ring's `Ring.tga`, `RingSelected.tga` and `RingSlot.tga` (see below) |
| `tests/` | Specs run in plain Lua against `tests/wow_stubs.lua` |
| `Bindings.xml` | The ring's and the back buttons' entries under Key Bindings > AddOns (the client loads it from the addon's folder, not the TOC) |

Features never talk to each other or to the settings page. The page writes `ns.Options`; a feature
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
  too.
- The back buttons and the ring go through `ns.LaterOutsideWindows(key, fn)` instead: out of combat
  too, and in Forever's controller interface also away from the game's windows that have the
  controller (see Settings pages below).
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
  the bar features ignore it, and the back buttons and the ring update only once the settings have
  been closed for half a second (`ns.LaterOutsideWindows`).
- The other way round, the controller features (the back buttons and the buff tooltips, the
  Controller page) act only while the controller interface is on: with keyboard and mouse the back
  buttons hide, lose their `type` attribute (so their keys, saved bindings included, press nothing)
  and their override bindings, and the buff tooltip keeps its alpha. The game switches interfaces
  without a reload and fires `INPUT_DEVICE_INTERFACE_TRANSITION`; `ns.OnControllerUIChange` runs
  the features' updates on it (the bar paging overrides go and come back with it too). The ring
  isn't one of them: it has a mouse key and a stick key and works in both.

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

The ring (`Features/Ring.lua`) picks an action in combat, so the choice is made by secure code:

- A secure header (`SecureHandlerBaseTemplate`, `QoLRing`, hidden, DIALOG strata) and two
  `SecureActionButtonTemplate` buttons of ours, `QoLRingMouse` and `QoLRingStick` (children of
  UIParent, no size). Each has `*type-s1` to `*type-s8` "action" and `*action-sN` set to buttons 1 to
  8 of Action Bar 6, 7 or 8 (slots 145-152, 157-164, 169-176), and `useOnKeyDown` false, so its action
  happens when the key is let go. Their OnClick is wrapped by the header
  (`SecureHandlerWrapScript(opener, "OnClick", header, Ring.CLICK)`).
- The snippet, on the key going down: anchor the header at the cursor (`"$cursor"`, a fixed point
  on the screen) or the middle of UIParent, note which key in its `qol-aim` attribute, show it,
  return false (no action). On the key going up: hide it, read the aim and return the aimed slot's
  button, `"s1"` to `"s8"`; `SecureButton_GetButtonSuffix` makes that the `-sN` suffix of the
  attributes above. Aim with the mouse: `owner:GetMousePosition()`, which is 0 to 1 across the header
  and nil outside it, hence the header's 8192 units; less than 20 units from the middle is none.
  Aim with the stick: `GetGamePadState().sticks[i]` (the restricted environment's
  `C_GamePad.GetDeviceMappedState`), `i` the stick `C_GamePad.StickIndexToConfigName` calls
  "Camera" (counted from 0 there, from 1 in `sticks`, found out of combat into the header's
  `qol-stick`); `len` under 0.5 is none. The angle is `math.atan2(x, y)` (the global `atan2` works
  in degrees), slot 1 at the top, clockwise. The header's `qol-on` attribute is false while the ring
  is turned off, as a key saved in Key Bindings still clicks its button then.
- Our code only draws. The art is a plain frame under the header, so it shows and hides with it
  without being protected. Its OnShow refreshes the slots (`ns.Buttons.RefreshAction`, as on the
  back buttons) and its OnUpdate works out the aimed slot with the same sums (`Ring.SlotAt`, cursor
  from `GetCursorPosition()` over the effective scale against `GetCenter()`), lights its wedge
  (only on a slot with an action) and puts the action's name in the middle:
  `C_TooltipInfo.GetAction(slot).lines[1].leftText`, maybe secret, only passed to `SetText`.
- While the stick ring is open, a plain frame of ours has `EnableGamePadStick(true)` and an
  `OnGamePadStick` that returns true for the "Left" and "Movement" stick (passed on to the game, so
  the player can walk) and nothing for the others (kept from the camera), as `Blizzard_RadialWheel`
  does. It keeps the stick after the ring closes until the stick is at rest (`len` under 0.1) or for
  half a second, like `InputAxisBinding`'s `waitForCentering`, so letting go of the key with the
  stick out doesn't swing the camera.
- `/qol ring` opens the editor: a plain frame, `QoLRingEditor` (in `UISpecialFrames` for Escape;
  the game reads that list in `securecall("CloseSpecialWindows")`, so our entry's taint stays there),
  with the same art and Buttons for slots: dragging and clicking call `PickupAction` and
  `PlaceAction`, out of combat only, and combat closes it. It's a slash command, not a button on the
  settings page, because hiding `SettingsPanel` from addon code taints its `Commit`.
- The header, the buttons, their attributes and the override bindings (the keys bound to the two
  buttons, as for the back buttons, `ns.Buttons.NewOverrides`) are made and changed through
  `ns.LaterOutsideWindows`, out of combat and away from the game's controller windows. The editor
  is no such window (the controller manager doesn't know it), so the ring changes while it is open.

The ring's textures come from Forever's own art (build 1.60.1.70291). `Media/Ring.tga` (512×512,
drawn 343 units wide) is a dark disc, the radial menu's wheel (`gamepad-radial-menu-wheelbg`, file
6227249) and the minimap's bronze ring (`ui-hud-minimap-frame-circle-c60-2x`, file 8026708) scaled
over the wheel's rim, which ends 150 units out. `Media/RingSelected.tga` (256×256, 150 units) is the
radial menu's lit wedge (`gamepad-radial-menu-selected`) turned to point up; it is drawn 95 units out
and turned with `SetRotation(-angle)` (counterclockwise in radians). `Media/RingSlot.tga` (128×128,
58 units around a 40-unit icon) is the minimap's day and night rim
(`ui-hud-minimap-frame-cycle-c60-2x`). They were cropped, scaled and laid over each other with small
Pillow and numpy scripts, not kept in the repository.

## Settings pages

Every page is a canvas (`Settings.RegisterCanvasLayoutCategory`) built by `UI/SettingsPage.lua`:
two columns of rows, or rows across the page (`"wide"`, the Viewport page, as its sliders need the
room), each an option's name with a control from the game's own templates
(`SettingsCheckboxTemplate`, `WowStyle2DropdownTemplate`, `MinimalSliderWithSteppersTemplate`,
`ColorSwatchTemplate` opening `ColorPickerFrame`), so they look like the game's pages and fit without
scrolling (`SettingsPage.MAX_HEIGHT`, checked by the tests). All names use one font: the game's list
draws dependent options smaller. A page refreshes on `OnRefresh` (the panel showing it) and through
`Options:Watch`, and resets on `OnDefault` (the game's "all settings" reset) and its own Defaults
button, which asks with a second click: the game's confirmation dialog would spread taint. The
canvas pages don't show up in the settings search.

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
`UPDATE_BINDINGS` that closing fires. So the back buttons and the ring, the only features that set
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
`MapPins.IsAvailable()` is false: the settings page leaves the World map options out and the map is
never touched.

The Controller page is registered only when `GamepadMainActionBarFrame` exists (Forever); on retail
there's nothing for it to change.

The Controller page also has the back buttons' key bindings (`Page:Binding`, rows across the page):
the same `CLICK QoLBackButtonN:LeftButton` commands as Key Bindings > AddOns, each row named by its
slot on the chosen bar (the label is a function, asked again on each refresh, so it follows the
Slots dropdown). Each row has two buttons from the game's own `KeyBindingFrameBindingButtonTemplate`
and works like a row of the game's Key Bindings, with code of our own rather than the game's
`KeybindListener` (a Blizzard frame: starting it writes its fields, which the rules above
forbid): a click on a button shows a parentless frame of ours at `FULLSCREEN_DIALOG` strata with an
`OnKeyDown`, which takes the keyboard until a key comes (modifiers alone wait for the rest, through
`IsKeyPressIgnoredForBinding` and `CreateKeyChordStringUsingMetaKeyState`), Escape comes, the
button is clicked again, the page hides, the row is greyed out or combat starts. The key is set as
the game's `KeybindListener:ProcessInput` sets it: both old keys cleared, the new key taken from
whatever had it (`SetBinding(key, nil, context)`), the keys bound again in their slots, in the
action's context (`C_KeyBindings.GetBindingContextForAction`). A right-click clears a slot. Gamepad
buttons are not listened for: the controller cursor needs A (a second press on the button stops
waiting) and B, and the Steam Deck's back buttons send keyboard keys anyway; a paddle needs no key.
Nothing calls `SaveBindings`: the settings panel saves the bindings when it closes, which fires
`UPDATE_BINDINGS`, and the back buttons' override bindings follow from there through
`ns.LaterOutsideWindows`, after the settings closed. So the only thing done while the settings are
open is `SetBinding`, which the game's own Key Bindings page does there too. All frames (the
buttons and the listener) are created when the pages are built at login, not while a controller
window is open, so SmartNavigation's `CreateFrame` hook rebuilds no window for them.

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
`Login`) makes Forever's controller bar with its `PageUnit` anchors.

## Trying it in game

Link or copy the repository into the client's AddOns folder as `QoL` (on the Forever beta:
`_classic_beta_/Interface/AddOns/QoL`). The client only loads what the TOC lists, so `docs/`
and `tests/` do no harm there. An unpackaged copy reports its version as `@project-version@`; only
the packager fills it in.

Things only the real client can confirm:

- The viewport margins line up with the world at your resolution and UI scale, and stay with Alt+Z.
- With Forever's controller interface on (Options > Controller), the viewport and the Action Bars
  options on: open the settings, look at every page (Viewport included: step a margin with its
  arrows, open the color picker; on the Controller page turn on the back buttons, press the bar
  dropdown a few times, with A and with the touch screen, and bind a back button's key: A on a key
  box, then the back button), go to another page, and close the settings with B and with Esc. The dropdowns step through their choices without opening a list.
  The game must not freeze, and the viewport stays. The back buttons (and the ring, with its bar
  changed) take the new bar only after the settings and the game menu are closed, within a second. The game's own controller action
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
- The ring (Action Bars > Ring), with both keys bound under Key Bindings > AddOns > Quality of Life:
  - Mouse key: the ring opens at the cursor, the wedge and name follow the mouse, letting go uses
    that action (also in combat, a spell, an item and a macro), and letting go in the middle or on an
    empty slot does nothing. Near a screen edge, and at several UI scales.
  - Controller key, in the controller interface and with keyboard and mouse: the ring opens in the
    middle, the right stick aims, the camera stays still while aiming and doesn't swing when the key
    is let go with the stick out, and the left stick still moves the character. If the camera stick
    isn't the second in `GetGamePadState().sticks`, the aim is wrong or none: check `qol-stick`.
  - The art: wheel, bronze rim and slot rims line up, the lit wedge sits on the aimed slot in all
    eight directions, cooldowns and counts show, long names wrap in the middle.
  - `/qol ring`: dragging on, off and between slots, clicking with the controller cursor, the
    tooltip, Escape and the close button, closing when combat starts.
  - No "tainted by" error in combat after using it.
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
