# Developing Quality of Life

Notes for working on the addon. What it does for players is in the [README](../README.md).

## Layout

| Folder | What's in it |
|---|---|
| `Core/` | Namespace and printing (`Init`), the event frame and unit listeners (`Events`), saved options with defaults and change watchers (`Options`), the saved data's version and migrations, and the character key `name-realm` (`SavedData`), deferred changes (`Later`), the hidden holder for hidden frames (`Hider`), what the back buttons and the rings share (`Buttons`: an action slot's look, override bindings), our windows' frame (`Window`: the settings), `/qol` (`Slash`) and startup (`Lifecycle`) |
| `Data/` | Static game data: `MapPins` (dungeon entrances, docks, portals; how it was made is at the top of the file) |
| `Features/` | One file per feature: `Merchant`, `Quests`, `FasterAutoLoot`, `Tooltips`, `HideFrames` (also the chat buttons), `BuffTooltips` (the controller interface's tooltips for new buffs), `CombatLog`, `ChatClassColors`, `CombinedBagLayout`, `MailBookmarks` (tabs on the Send Mail tab), `ClassHealthBars`, `DruidManaBar` (mana in bear and cat form), `ScreenEdge` (Edit Mode frames past the screen edge), `Minimap` (shape, positions, class colors and font sizes around the minimap, and the FPS and ping text), `MapPins`, `Viewport`, `ActionBars`, `ButtonBorders`, `BarPaging`, `BackButtons` (the controller back buttons, Forever only), `RingEntries` (what can go on a ring or a click casting binding, and what a character has of it), `Ring`, `RingPicker` (the editors' list and spell book page, the Ring and Click casting pages'), `RingEditor` (the settings' Ring page, `/qol ring`), `ClickCast` (bindings on unit frames), `ClickCastEditor` (the settings' Click casting page, `/qol click`), `ReloadCommand`, `HiddenSettings` (the hidden settings on the Advanced settings page) and `HiddenSettingsProbe` (`/qol probe`) |
| `UI/` | `SettingsPage.lua`, a settings page (two columns, or rows across the page, and key binding rows); `SettingsWindow.lua`, the window that `/qol` opens, with the list of pages; `InfoPage.lua`, the information page under Options > AddOns, with a button that opens the window; `Settings.lua`, the pages built with them, in the list's order |
| `Locales/` | English strings, German overrides |
| `Media/` | `Icon.tga`, the addon list icon (the TOC's `IconTexture`, 128×128, 32-bit), and `Icon.svg`, its source (not packaged); `Zeppelin.tga`, `Tram.tga`, `MinimapSquareBorder.tga` and the rings' `Ring.tga`, `RingSpoke.tga`, `RingLit1.tga` to `RingLit12.tga` and `RingSlot.tga` (how they were made: [`dev/minimap.md`](dev/minimap.md), [`dev/rings.md`](dev/rings.md)); `AutoPotion.tga`, `AutoSetup.tga` and `Wayscribe.tga`, copies of the other addons' icons for the information page |
| `tests/` | Specs run in plain Lua against `tests/wow_stubs.lua` |
| `Bindings.xml` | The back buttons' entries under Key Bindings > AddOns (the client loads it from the addon's folder, not the TOC) |

Features never talk to each other or to the settings pages. A page writes `ns.Options`; a feature
reads it with `Options:Get` and reacts to changes through `Options:Watch`. `RingEntries` and
`RingPicker` are the one shared part: the rings made them, and click casting uses them for what a
character has and for its page's list (the issue asked for them to be shared, not copied).

## Saved data

Everything QoL saves is in `QoLDB`, account-wide: `options` (only values that differ from their
default), `rings`, `characters` (the mail bookmarks' class icons), `clickCast` (each character's
click casting bindings by character key, `ns.PlayerKey()`; a character without any starts with
Left: Target and Right: Menu, so it needs no migration), `probe` (the last `/qol probe`
report, which nothing reads; missing until it first runs, so it needs no migration), and
`version`, the layout's version (`Core/SavedData.lua`, now 1). On `ADDON_LOADED`, before anything
reads the file, `SavedData:Migrate` runs `MIGRATIONS[n]` for every version from the saved one up
to `VERSION`, one at a time, and writes each version once its migration is done. There are none
yet: a file without a version is the layout from before versions, which version 1 kept, so 0 to 1
only writes the number.
A change to the layout raises `VERSION` and adds the migration that turns the old layout into the
new one. A migration that fails (an error) stops there: the error goes to the game's error handler,
the version stays at the last one that worked, and QoL loads as usual. So a migration works out
everything it needs before it writes anything, and leaves the file as it was when it fails.

A player can go back to an older QoL, and the client writes whatever is in memory at logout, so
QoL doesn't reset what it doesn't understand. A file with a newer version than `VERSION` is left
alone: no migrations run and the version stays. A saved option whose type doesn't match its default
stays in the file too; `Options:Init` marks it, `Get` returns the default for a marked key (one table
lookup, since `Get` runs on tooltip paths) and `Set` replaces the value and clears the mark. Options
QoL has no default for are kept and never read. Click casting keeps a binding it doesn't understand
(an action kind of a newer QoL) where it is and leaves it out of everything else. The one exception
is Ring: at login it drops what isn't a ring from `QoLDB.rings` (`clean` in `Features/Ring.lua`), as
it did before versions.

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
- The back buttons, the rings and click casting go through `ns.LaterOutsideWindows(key, fn)` instead: out of combat
  too, and in Forever's controller interface also away from the game's windows that have the
  controller (see [`dev/settings-window.md`](dev/settings-window.md)).
- Hide frames by parenting them to `ns.Hider`'s holder instead of `Hide()` plus hooks; Blizzard's
  own `Show()` calls then change nothing.
- Compare or compute with game values only after `ns.IsUsable(value)` (nil and secret values fail).
- Register events through `ns.Events:On`; it skips events the client doesn't know.
  `ns.Events:Off(event, handler)` takes a handler away again and unregisters the event once none is
  left, for a feature that listens only while its option is on (Faster auto loot).
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
  own) and `SetMapID` (only from a click on one of our own pins, like a click on a zone). Click
  casting's, all out of combat (more in [`dev/click-casting.md`](dev/click-casting.md)): `SecureHandlerWrapScript` on the
  unit frames' `OnEnter`, `OnLeave` and `OnHide`, and on those of their protected parts that take the
  mouse, found with `GetChildren` (a read) (the secure handlers' own way to add a snippet to a
  frame's script, run as secure code), `SecureHandlerSetFrameRef` on our own header,
  `PartyFrame.PartyMemberFramePool:EnumerateActive()` (a read of the pool) and
  `hooksecurefunc("CompactUnitFrame_SetUpFrame", ...)`: a hook on a global function, not on a
  frame's method, which runs after it and only notes the frame. One
  Blizzard table is written to: `hash_SlashCmdList`, the chat's cache of slash commands. Whenever
  the chat parses a slash command (and once at load), `ImportAllListsToHash`
  (`Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua`) moves every new entry of `SlashCmdList` into
  it, and the chat then runs the command it finds there. So once chat has been used, QoL's `/rl` is
  in that table, and turning `/rl` off removes it there too (`ReloadCommand:Unregister`, only when
  the entry is still ours); otherwise `/rl` would keep working until a reload. It's safe: the game's
  own comment (`SlashCommandsRegistry.lua`) keeps the table global so addons can unregister their
  commands this way; the only reader is the edit box's `ParseText` (`ChatFrameEditBox.lua`), after
  the secure commands, which have a table of their own; and on a miss it tries emotes and then
  prints the usual help text for an unknown command, as for any typo. Two leftovers of the import
  stay: the copy behind `SlashCmdList`'s metatable (nothing runs it) and
  `hash_ChatTypeInfoList["/RL"]`, which names no chat type, so `/rl` still tab-completes but does
  nothing.
- Classic Era's health bars, whose color the game doesn't lock: `HookScript("OnValueChanged")` on
  the player, target, target of target, focus and focus target bars, which only schedules the
  class color again (see the class-colored health bars in [`dev/bars-and-frames.md`](dev/bars-and-frames.md)).
- Classic Era's tooltips, which lack the tooltip data processor: `HookScript` on `GameTooltip`,
  `ItemRefTooltip` and the comparison tooltips' item, spell, unit, money and cleared scripts, and,
  inside the item script, the game's `Sell Price` line's font strings rewritten in place and
  `Show()` to fit the tooltip. Not through `ns.Later`: a line added or changed a frame later would
  miss the tooltip. Why that's safe there is in the vendor price notes in [`dev/tooltips-chat-bags-mail.md`](dev/tooltips-chat-bags-mail.md).
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

## Notes per area

Each file holds the design notes of one part of the addon. Read the one for the area you change:

- [`dev/bars-and-frames.md`](dev/bars-and-frames.md): the action bar flip, button borders, class-colored health bars, the druid mana bar, frames past the screen edge, portrait hit text, the frames QoL hides, quests on Classic Era
- [`dev/tooltips-chat-bags-mail.md`](dev/tooltips-chat-bags-mail.md): the combat log, the vendor price line and tooltip IDs, the buff tooltips, chat class colors, faster auto loot, the combined bag, the mail bookmarks
- [`dev/minimap.md`](dev/minimap.md): the square minimap and its border, button positions, class colors and font sizes, the FPS and ping text
- [`dev/controller.md`](dev/controller.md): bar paging, the back buttons and their bindings, the Controller page
- [`dev/rings.md`](dev/rings.md): the rings: secure choice, saved data, the Ring page and its editor, the textures
- [`dev/click-casting.md`](dev/click-casting.md): click casting: its engine, the unit frames it wraps, the Click casting page
- [`dev/settings-window.md`](dev/settings-window.md): the settings window, page groups and layout, `UI/SettingsPage.lua` rows, the freezes from when the pages were in the game's settings
- [`dev/advanced-settings.md`](dev/advanced-settings.md): the Advanced settings page and the hidden settings (CVars) it changes
- [`dev/map-pins.md`](dev/map-pins.md): the world map pins
- [`dev/in-game.md`](dev/in-game.md): the in-game checklist, the hidden settings probe, cutscenes with the viewport

## Tests and lint

Tests and lint run on Lua 5.1, what WoW runs; `tests/run.lua` stops on any other version.

```bash
~/.lua51/bin/lua tests/run.lua
```

```bash
~/.lua51/bin/luacheck -q .
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

`Stubs.Reset({ client = "classicEra" })` (or `LoadAddon` with it) makes the stubbed client Classic Era
(1.15.9, interface 11509): the tooltip data processor (its tooltips run their scripts
instead: `Stubs.ShowClassicTooltip` builds one, with the game's sell price line for an item with a
price), the spell book's skill-line calls, toys, the
addon compartment, the combined bags, Forever's `CircleMask` atlas and controller globals and the
guild bank calls and `ToggleCalendar` are gone, the player frame's art container, the minimap's
coordinates, its tracking button and day and night icon are `false` (a stub frame answers any
other capitalized field with a no-op method, so a check reads them with `type(...) == "table"`),
the minimap is Classic Era's (140 across, `MinimapBorder`, and `MiniMapTracking` and the time of
day `GameTimeFrame` on `MinimapBackdrop`), the unit frames' health bars lose `lockColor`, the spell book is read by tab (`GetSpellTabInfo`, from
`state.spellTabs` or one tab of every slot; a slot's `future` makes it `FUTURESPELL`), and
`CreateFrame` errors on a template Classic Era lacks (`MISSING_TEMPLATES`), as the client does, so a template
only Forever and retail have can't slip into the login unnoticed. `tests/classicera_spec.lua` logs in
on it and opens the settings window; the ring and click casting specs have Classic Era cases of
their own.

Classic Era's chat has `FriendsMicroButton` and no `QuickJoinToastButton`, its player
frame `PlayerHitIndicator` and no `PlayerFrameContent`, and its quest greeting no quest IDs (no
`GetActiveQuestID`, four values from `GetAvailableQuestInfo`, the titles from `GetAvailableTitle` and
`C_QuestLog.GetQuestInfo` over `state.quest.titles`). `Stubs.SetHealth` moves a unit frame's health
bar to a new value, as the game's OnUpdate does: an unlocked bar turns green before its `OnValueChanged` hook runs.

The fake `C_CVar` refuses what the game refuses (a value outside `state.cvarRanges`, a
`state.cvarSecure` CVar in combat, an unknown CVar), drops the fraction for one in `state.cvarWhole`,
and logs every write in `state.cvarSets`. A game slider is a `state.gameSliders` entry: per step
from 0, the settings that step sets. Writing its CVar sets them, also when it already had that step,
unless `state.gameSliderRewrites` is false. `Stubs.Reset` starts every spec with the three game
sliders as retail's probe measured them (`GAME_SLIDERS` in `tests/wow_stubs.lua`), each at a step
whose values the hidden settings start at. The Classic Era client takes its probe's values instead:
its game defaults (each setting starts at its own), camera distance 1 to 4, ground clutter distance
from 70, Ground Clutter's steps, and no View Distance. `WOW_PROJECT_ID` is Forever's
(`WOW_PROJECT_CAMELOT`, 18) or, on Classic Era, `WOW_PROJECT_CLASSIC`.

## Releasing

`.github/workflows/release.yml` runs the [BigWigsMods packager](https://github.com/BigWigsMods/packager)
on every pushed tag: it replaces `@project-version@` with the tag, leaves out `docs/`,
`tests/`, `README.md` and `Media/Icon.svg`, and creates the GitHub release. For CurseForge uploads, add
`## X-Curse-Project-ID` to the TOC and the `CF_API_KEY` repository secret.
