# Developing Quality of Life

Notes for working on the addon. What it does for players is in the [README](../README.md).

## Layout

| Folder | What's in it |
|---|---|
| `Core/` | Namespace and printing (`Init`), the event frame and unit listeners (`Events`), saved options with defaults and change watchers (`Options`), the saved data's version and migrations, and the character key `name-realm` (`SavedData`), deferred changes (`Later`), the hidden holder for hidden frames (`Hider`), what the back buttons and the rings share (`Buttons`: an action slot's look, override bindings), our windows' frame (`Window`: the settings), `/qol` (`Slash`) and startup (`Lifecycle`) |
| `Data/` | Static game data: `MapPins` (dungeon entrances, docks, portals; how it was made is at the top of the file), `GroupBuffs` (buffs' group versions and rival buffs, by name through `ns.CountingNames`, for the reminders and the tracked buffs) |
| `Features/` | One file per feature: `Merchant`, `Quests`, `FasterAutoLoot`, `Tooltips`, `HideFrames` (also the chat buttons), `BuffTooltips` (the controller interface's tooltips for new buffs), `CombatLog`, `ChatClassColors`, `SortOnOpen`, `MailBookmarks` (tabs on the Send Mail tab), `ClassHealthBars`, `DruidManaBar` (mana in bear and cat form), `GroupFrames` (tracked buffs on the group frames and the Group Frames page's game setting, Forever only), `ScreenEdge` (Edit Mode frames past the screen edge), `Minimap` (shape, positions, class colors and font sizes around the minimap, and the FPS and ping text), `MapPins`, `Viewport`, `ActionBars`, `ButtonBorders`, `CooldownManager` (the look of the game's Cooldown Manager, Forever only), `Reminders` (icons for missing buffs in a row of our own, Forever only), `BarPaging`, `RankUpgrades` (spells on the bars follow a learned rank, Forever only), `BackButtons` (the controller back buttons, Forever only), `FollowingBars` (controller bars that change with the stance, Forever only), `TriggerToggle` (a trigger pressed keeps its controller bar on, Forever only), `RingEntries` (what can go on a ring or a click casting binding, and what a character has of it), `Ring`, `RingPicker` (the editors' list and spell book page, the Ring and Click casting pages'), `RingEditor` (the settings' Ring page, `/qol ring`), `ClickCast` (bindings on unit frames), `ClickCastEditor` (the settings' Click casting page, `/qol click`), `ReloadCommand`, `HiddenSettings` (the hidden settings on the Graphics & Camera page) and `HiddenSettingsProbe` (`/qol probe`) |
| `UI/` | `SettingsPage.lua`, a settings page (two columns, or rows across the page, tables, and key binding rows); `SettingsWindow.lua`, the window that `/qol` opens, with the list of pages in groups; `InfoPage.lua`, the information page under Options > AddOns, with a button that opens the window; `Settings.lua`, the pages built with them, in the list's order |
| `Locales/` | English strings, German overrides |
| `Media/` | `Icon.tga`, the addon list icon (the TOC's `IconTexture`, 128×128, 32-bit), and `Icon.svg`, its source (not packaged); `Zeppelin.tga`, `Tram.tga`, `MinimapSquareBorder.tga` and the rings' `Ring.tga`, `RingSpoke.tga`, `RingLit1.tga` to `RingLit12.tga` and `RingSlot.tga` (how they were made: [`dev/minimap.md`](dev/minimap.md), [`dev/rings.md`](dev/rings.md)); `AutoPotion.tga`, `AutoSetup.tga` and `Wayscribe.tga`, copies of the other addons' icons for the information page |
| `tests/` | Specs run in plain Lua against `tests/wow_stubs.lua` |
| `Bindings.xml` | The back buttons' entries under Key Bindings > AddOns (the client loads it from the addon's folder, not the TOC) |

Features never talk to each other or to the settings pages. A page writes `ns.Options`; a feature
reads it with `Options:Get` and reacts to changes through `Options:Watch`. `RingEntries` and
`RingPicker` are the one shared part: the rings made them, and click casting uses them for what a
character has and for its page's list (the issue asked for them to be shared, not copied). A list
that isn't options goes through a small interface of its feature, as the ring and click casting
editors do: the Cooldown Manager page adds, pauses and removes the player's own reminders with
`Reminders.AddFromCursor`, `SetOn` and `Remove`, reads them with `Own`, and refreshes on
`Reminders.OnChange` (an edit, a spell learned, or the reminder row locked or unlocked). Its Unlock
and Reset position buttons call `Reminders.SetUnlocked` and `ResetPosition`, as the row's mover state
isn't an option either. The Group Frames page does the same with the tracked buffs:
`GroupFrames.AddFromCursor`, `SetOn`, `Remove`, `Lines` and `OnChange`. Whether a character knows a
spell at any rank, which both lists ask, is `ns.KnowsAnyRank` in `Core/Init.lua`.

## Saved data

Everything QoL saves is in `QoLDB`, account-wide: `options` (only values that differ from their
default), `rings`, `characters` (the mail bookmarks' class icons), `clickCast` (each character's
click casting bindings by character key, `ns.PlayerKey()`; a character without any starts with
Left: Target and Right: Menu, so it needs no migration), `followingBars` (each character's ticked
controller bars, the slots handed out and the bars that didn't fit, by the same key; missing until first used, so it needs no
migration), `reminders` (the player's own reminders, `{ spell, on }` in the order added, for the
whole account; missing until the first one is added, so it needs no migration), `trackedBuffs` (the
tracked buffs on the group frames, `{ spell, kind, on }` in the order added, for the whole account;
missing until the first one is added, so it needs no migration), `probe` (the last `/qol probe`
report, which nothing reads; missing until it first runs, so it needs no migration), and
`version`, the layout's version (`Core/SavedData.lua`, now 4). On `ADDON_LOADED`, before anything
reads the file, `SavedData:Migrate` runs `MIGRATIONS[n]` for every version from the saved one up
to `VERSION`, one at a time, and writes each version once its migration is done. A file without a
version is the layout from before versions, which version 1 kept, so 0 to 1 only writes the
number. Version 2 renamed the zone text's position `above`/`below` to the minimap elements' shared
`top`/`bottom`. Version 3 turned `hideMinimapCoords` and `hideMinimapCalendar` into the coordinates'
and the calendar button's Position (`hidden` where they were ticked) and dropped the old keys.
Version 4 gave each controller bar its own back buttons' action bar: `controllerBackButtonsBar`
became Top's (`controllerBackButtonsBarTop`), and Left, Right and Bottom take the first free of 8,
7, 6 and 5 that isn't Top's, saved only where that isn't their default.
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
(an action kind of a newer QoL) where it is and leaves it out of everything else, and so do the
reminders with an entry that has no spell ID. The one exception
is Ring: at login it drops what isn't a ring from `QoLDB.rings` (`clean` in `Features/Ring.lua`), as
it did before versions.

## Rules for touching Blizzard frames

Forever and retail 12.x hand out secret values, and taint that leaks into Blizzard code breaks
unrelated frames ("tainted by 'QoL'"), as other action bar addons learned the hard way on the
Forever beta. So:

- Never write a field on a Blizzard frame, never call its layout or update methods, and never
  `hooksecurefunc` its methods. Read fields, call widget methods (`SetPoint`, `SetParent`).
  (One hook is the exception, listed below: the Cooldown Manager rows' `RefreshLayout`.)
- Every change to a Blizzard frame goes through `ns.Later(key, fn)`: it runs from the OnUpdate of a
  frame of ours (never inside a Blizzard call stack), at most once per drawn frame, and waits for the
  end of combat. A request made while the batch runs waits for the next frame, so a change that makes
  the game fire an event asking for it again can't spin inside one frame and freeze the game
  (nothing says when the game runs a `C_Timer.After(0)` started from a timer callback). A change the
  game allows in combat (the health bar colors) passes `true` as a third argument and runs in combat
  too; Sort on open passes it so that a request made in combat ends there, instead of waiting for
  combat to end. It makes no garbage per request, since busy events (cooldowns, usability) ask many times a
  second: each key keeps one request table, reset by every new request, the batch swaps between two
  tables, and every feature's schedule helper hands it a function defined once, not a new closure.
- The back buttons, the rings, click casting, rank upgrades, following bars and the trigger toggle go through `ns.LaterOutsideWindows(key, fn)` instead: out of combat
  too, and in Forever's controller interface also away from the game's windows that have the
  controller (see [`dev/settings-window.md`](dev/settings-window.md)).
- Hide frames by parenting them to `ns.Hider`'s holder instead of `Hide()` plus hooks; Blizzard's
  own `Show()` calls then change nothing.
- Compare or compute with game values only after `ns.IsUsable(value)` (nil and secret values fail).
- Register events through `ns.Events:On`; it skips events the client doesn't know.
  `ns.Events:Off(event, handler)` takes a handler away again and unregisters the event once none is
  left, for a feature that listens only while its option is on (Faster auto loot). For several events
  with one handler, `ns.Events:NewGroup(events, handler)` does the same: `group:SetOn(on)` turns them
  all on or off and does nothing if they already are. Events a feature doesn't need while it's off or
  hidden go in one (make it once, at Init or when the frame is built).
- Events about units (`UNIT_*`, first argument a unit) go through a unit listener, never through
  `ns.Events:On`: `ns.Events:NewUnitListener(unit1[, unit2])` registers with `RegisterUnitEvent`
  on a frame of its own, so the game drops every other unit's events before QoL wakes (in a raid
  with nameplates, hundreds a second). It takes one or two units, all a feature needs so far; a
  feature that shows more units makes more listeners. Make a listener once, at Init: frames are
  never freed.
  `listener:On(event, handler)` skips an unknown event like `ns.Events:On` (one handler per event,
  a second `On` replaces it; handlers get `(event, ...)`), and `listener:Off(event)` unregisters it,
  for an event that only matters while something shows. The one exception is click casting's
  `UNIT_FACTION`, for any of 40 nameplate units: it stays on `ns.Events:On`, only while click casting
  is on, and the handler checks the unit.
- The few calls into Blizzard code are listed here, each with why it's safe: the world map's
  `AddDataProvider` (the map's own extension point; it calls each provider in a secure call of its
  own) and `SetMapID` (only from a click on one of our own pins, like a click on a zone). Click
  casting's, all out of combat (more in [`dev/click-casting.md`](dev/click-casting.md)): `SecureHandlerWrapScript` on the
  unit frames' `OnEnter`, `OnLeave` and `OnHide`, and on those of their protected parts that take the
  mouse, found with `GetChildren` (a read) (the secure handlers' own way to add a snippet to a
  frame's script, run as secure code), `SecureHandlerSetFrameRef` on our own header,
  `PartyFrame.PartyMemberFramePool:EnumerateActive()` (a read of the pool) and
  `hooksecurefunc("CompactUnitFrame_SetUpFrame", ...)`: a hook on a global function, not on a
  frame's method, which runs after it and only notes the frame. The tracked buffs hook it the same
  way, to note the frames their icons go on (see [`dev/group-frames.md`](dev/group-frames.md)), and
  their "has it" icons are the game's aura container (`CustomAuraContainerTemplate`), on a holder of
  ours: `SetUnit`, `SetEnabled`, `AddAuraSlot`, `SetAuraSlotEnabled` and `SetAuraSlotCandidateFilters`
  are its own API, unprotected, and the slot button's `SetIcon`, `SetDurationCooldown` and
  `SetApplicationCount` hand it widgets of ours, made in its `initializeFrame`. The button gets no
  field of ours, and is touched only while buff data isn't secret, as the game denies tainted access
  to it then. One
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
- Controller buff tooltips: `BuffFrameTooltip:HookScript("OnShow", ...)` and `SetAlpha(0)` on it
  right there, not through `ns.Later`. `HookScript` runs after the game's own handler and replaces
  nothing; `SetAlpha` is a widget method on a tooltip nothing else uses and that isn't protected, so it
  works in combat, and done later the tooltip would show for a frame (see
  [`dev/tooltips-chat-bags-mail.md`](dev/tooltips-chat-bags-mail.md)).
- Sort on open: `hooksecurefunc("OpenAllBags", ...)` and `hooksecurefunc("OpenAllBagsMatchingContext", ...)`,
  hooks on global functions, not on a frame's methods, which run after them, set a flag of ours and
  schedule a run; and `C_Container.SortBags()` from that run, on a frame of ours (see
  [`dev/tooltips-chat-bags-mail.md`](dev/tooltips-chat-bags-mail.md)).
- Following bars change the ID of the game's controller bar buttons, and set an attribute on them, from
  a secure snippet on a frame of ours (`HANDLE:SetID`, `HANDLE:SetAttribute`), which the game allows in
  combat; nothing is written or hooked. To catch a page flip, `SecureHandlerWrapScript` wraps those
  buttons' `OnAttributeChanged`; a wrap runs secure code and taints nothing. The wraps and the frame
  refs to those buttons are made out of combat. See
  [`dev/controller.md`](dev/controller.md).
- The trigger toggle keeps frame refs to the game's controller bar buttons, made out of combat, and
  from secure snippets on frames of ours reads them (`IsVisible`, `GetID`, `GetName`) and clicks them
  with a macro of a secure button of ours, as the game's own binding presses them; nothing on them is
  written or hooked. Its marker is a frame of ours parented to `PageUnit`, which adds a child and
  touches nothing of the game's. See [`dev/controller.md`](dev/controller.md).
- The back buttons learn when the game shows or hides a controller bar (empty bars hidden, the
  special page, a stance or possess bar in a bar's place) from plain frames of ours parented to the
  game's bars: their own `OnShow` and `OnHide` schedule an update. That adds a child and hooks
  nothing; the bars are read only (`IsShown`, `GetParent`). See [`dev/controller.md`](dev/controller.md).
- Hiding the Cooldown Manager's icon borders: `hooksecurefunc(row, "RefreshLayout", ...)` on each of
  the game's four rows, the only hook on a Blizzard frame's method, and only once the option is on.
  Nothing else tells when a row built new icons. It runs after the rebuild and only asks `ns.Later`
  for a pass; the pass reads `row.itemFramePool:EnumerateActive()` and sets one texture's alpha per
  icon. See [`dev/bars-and-frames.md`](dev/bars-and-frames.md).
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
- The other way round, the controller features (the back buttons, the buff tooltips, following
  bars, the trigger toggle, the Controller page) act only while the controller interface is on: with keyboard and mouse the back
  buttons hide, lose their `type` attribute (so their keys, saved bindings included, press nothing)
  and their override bindings, and the buff tooltip keeps its alpha. The game switches interfaces
  without a reload and fires `INPUT_DEVICE_INTERFACE_TRANSITION`; `ns.OnControllerUIChange` runs
  the features' updates on it (the bar paging overrides go and come back with it too). The rings
  aren't among them: each has a mouse key and a stick key and works in both.

## Notes per area

Each file holds the design notes of one part of the addon. Read the one for the area you change:

- [`dev/bars-and-frames.md`](dev/bars-and-frames.md): the action bar flip, button borders, the Cooldown Manager's icon borders, reminders, class-colored health bars, the druid mana bar, frames past the screen edge, portrait hit text, the frames QoL hides, quests on Classic Era
- [`dev/group-frames.md`](dev/group-frames.md): the Group Frames page: tracked buffs, hiding the raid manager, the game's buffs checkbox
- [`dev/tooltips-chat-bags-mail.md`](dev/tooltips-chat-bags-mail.md): the combat log, the vendor price line and tooltip IDs, the buff tooltips, chat class colors, faster auto loot, Sort on open, the mail bookmarks
- [`dev/minimap.md`](dev/minimap.md): the square minimap and its border, button positions, class colors and font sizes, the FPS and ping text
- [`dev/controller.md`](dev/controller.md): bar paging, the back buttons and their bindings, following bars, the trigger toggle, the Controller and Back buttons pages
- [`dev/rings.md`](dev/rings.md): the rings: secure choice, saved data, the Ring page and its editor, the textures
- [`dev/click-casting.md`](dev/click-casting.md): click casting: its engine, the unit frames it wraps, the Click casting page
- [`dev/settings-window.md`](dev/settings-window.md): the settings window, page groups and layout, `UI/SettingsPage.lua` rows, the freezes from when the pages were in the game's settings
- [`dev/advanced-settings.md`](dev/advanced-settings.md): the Graphics & Camera page and the hidden settings (CVars) it changes
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
the event for that unit, so a spec can check that other units' events never reach QoL. A frame made
as an `AuraContainer` is faked: it fills its slots from the stubbed buffs on every `UNIT_AURA` for its
unit, and touching a slot button while `Stubs.WithholdAuras(true)` fails, as on Forever.

`Stubs.Reset({ client = "classicEra" })` (or `LoadAddon` with it) makes the stubbed client Classic Era
(1.15.9, interface 11509): the tooltip data processor (its tooltips run their scripts
instead: `Stubs.ShowClassicTooltip` builds one, with the game's sell price line for an item with a
price), the spell book's skill-line calls, toys, the
addon compartment, the combined bags, `C_Container.SortBags`, Forever's `CircleMask` atlas and controller globals and the
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
