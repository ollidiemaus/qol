# Group frames

The Group Frames page (WoW Forever only, `GroupFrames.IsAvailable`) is about the game's own
raid-style party and raid frames. The design for the whole area, tracked buffs included, is in issue
#110 and [ADR 0004](../adr/0004-tracked-buffs-are-our-own-icons.md), amended for "has it" icons by #135
and [ADR 0005](../adr/0005-has-it-icons-filled-by-the-game.md); this note grows with it.

## Tracked buffs

Icons on every group frame (`Features/GroupFrames.lua`), for the spells in `QoLDB.trackedBuffs`
(`{ spell, kind, spot, on }`, account-wide, in the order added; not an option, so the page's Defaults
button switches `groupFrameBuffs` off and resets the size and countdown numbers, and keeps the list).
The table's Show column picks the kind (`GroupFrames.SetKind`): a "has it" icon shows while the
player's own cast of the buff is on the member, with the cooldown sweep and a stack number above one,
in and out of combat; a "lacks it" icon, desaturated with neither, while the member has no buff of the
name at all (#121), out of combat only (#135, [ADR 0005](../adr/0005-has-it-icons-filled-by-the-game.md)).

A line applies only where the character knows the spell at some rank (`ns.KnowsAnyRank`, shared
with the reminders); the page greys out the others. An entry with a kind this QoL doesn't know (a
newer QoL's) stays in the list and is left out of everything else.

- **Places (#122, #135):** the Position column (`GroupFrames.SetSpot`) picks one of `GroupFrames.SPOTS`,
  the nine anchor points of the frame, `TOPRIGHT` for a line saved before there were spots or with one
  this QoL doesn't know. Every line that is on and known gets a place on its spot, in the list's order,
  whatever its kind and whether its icon shows: 1 pixel apart and 2 in from the edges, from a left spot
  rightwards, from a right spot leftwards, and on the middle column (top, centre, bottom) in a row
  centred on the spot. All rows run across the frame, as raid frames are wide and short. The places are
  worked out once per refresh, not per frame, so an icon is in the same place on every frame and never
  moves mid-fight: a buff that isn't up leaves a gap, a line switched off or unknown takes none. QoL
  can't tell in a fight whether a "has it" icon shows, which is why the places can't close up.
- **Size and countdown:** `groupFrameBuffSize` (16, the slider 10 to 40) sizes every icon;
  `groupFrameBuffCountdown` (off) turns on the cooldown frame's own countdown numbers
  (`SetHideCountdownNumbers`) on "has it" icons. Both are watched and redraw every frame.
- **"Has it" through the game's aura container:** each holder gets one
  `CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")`
  (`Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua`), made the first time its frame has a
  "has it" line to show, its unit the frame's member, set on every full refresh, and `none` and
  disabled for a frame with no member we draw for or with the switch off. Each "has it" line is an
  aura slot, keyed by the line's spell (`spellN`; the list has one line per spell), filter
  `HELPFUL|PLAYER`, candidate filters `{ includeSpellIDs = ranks }`; slots aren't removed (the API has
  no call for it), only disabled, so a line switched off or removed leaves the others' slots as they
  are. The slot's button gets, in the container's `initializeFrame`, our texture (`SetIcon`), a
  `CooldownFrameTemplate` cooldown (`SetDurationCooldown`) and a font string over the sweep
  (`SetApplicationCount`), all its own descendants as the API demands; the game shows and hides the
  button and fills them, in and out of combat, whether or not buff data is secret. What we made and
  where the button sits is kept on our slot table, never as a field on the game's button. A slot's
  button is anchored to its line's place like our own icons, read when the game sets it up, not when
  the slot was added. `EnableMouse(false)`:
  the button is an `AuraButton`, which would otherwise take the mouse and show a tooltip. Nothing in QoL
  reads a buff for a "has it" line. If `CreateFrame` fails (the client has no such widget), the frame
  gets no "has it" icons and nothing is printed; the "lacks it" icons still work.
- **Ranks:** the container matches spell IDs, not names, so a line's ranks are every rank of the spell
  the character knows: the spell book's spells of that name (it lists every rank, see
  `Features/RankUpgrades.lua`; any locale, as the name comes from the client), plus the client's highest
  known rank by name and the line's own spell when known, in case the book lags. Kept per line, rebuilt
  on `SPELLS_CHANGED`; a rebuilt set is a new table, which hands every slot new candidate filters.
- **"Lacks it":** read through the `HELPFUL` filter (anyone's buffs). The member has the buff when a name
  there is the spell's or one of its group versions': `ns.GroupVersionNames` (`Data/GroupBuffs.lua`),
  the table the reminders use too, Forever's single-target spell IDs and their group spells, by name. It
  shows only for a member that's alive (`UnitIsDeadOrGhost`), online (`UnitIsConnected`) and in range
  (`UnitInRange`, as `CompactUnitFrame_UpdateInRange` reads it: out of range only when it was checked,
  so the player's own frame counts as in range). `UnitInRange` has secret returns; a secret answer to
  any of the three hides the frame's "lacks it" icons, as a secret buff name does. From
  `PLAYER_REGEN_DISABLED` (before the lockdown, so the flag is ours, not `InCombatLockdown`) to
  `PLAYER_REGEN_ENABLED` every "lacks it" icon hides and nothing is read or heard; `ShouldAurasBeSecret`
  stays a second guard. A hidden "lacks it" icon keeps its place, so the "has it" icons beside it don't
  move when combat starts.
- **Which frames:** the same hook click casting has, `hooksecurefunc("CompactUnitFrame_SetUpFrame")`,
  a hook on a global function that only notes the frame (nameplates come through it too). Each
  refresh reads the frame's `unit` field and draws only for `player`, `partyN` and `raidN`: pets,
  arena and nameplates get nothing. The unit is read on every refresh, since the game hands a frame
  to another member on a roster change (`CompactUnitFrame_SetUnit`), and `GROUP_ROSTER_UPDATE`
  redraws every frame, which sets each container's unit, in combat too.
- **Taint-safe:** each frame gets a holder of ours, made the first time it shows an icon: its child,
  `SetAllPoints` on it, a few levels above it (`GetFrameLevel`, a read). The container is the holder's
  child. Nothing is written on, hooked on or called on the game's frame. Neither the holder, the
  container nor the icons are protected or take the mouse, so clicks and click casting reach the frame
  underneath, and they're made, shown, hidden and placed in combat too (`ns.Later` with `inCombat`); a
  frame set up in combat gets its icons at once. The container's own calls (`SetUnit`, `SetEnabled`,
  `AddAuraSlot`, `SetAuraSlotEnabled`, `SetAuraSlotCandidateFilters`) aren't restricted. Its slot
  buttons are: the game applies `DenyTaintedAccessWhenAurasAreSecret` to each after `initializeFrame`,
  so tainted code may not touch a button (or what it handed over) while buff data is secret. So a button
  is set up and placed in `initializeFrame`, and moved or restyled later only while
  `ShouldAurasBeSecret` is false. A slot whose place changed in a fight (a line moved to another spot,
  the size changed) is disabled until the fight ends, rather than shown in the wrong place; a countdown
  checkbox change waits as it is.
- **Cost:** with the switch off nothing is heard (the setup hook only notes frames). On, only
  `GROUP_ROSTER_UPDATE`, to know when the character is in a group (`IsInGroup`). In a group,
  `SPELLS_CHANGED`, `ADDON_RESTRICTION_STATE_CHANGED`, the combat events and `PLAYER_ENTERING_WORLD`.
  "Has it" icons cost QoL nothing per buff change: the containers listen for themselves. While a "lacks
  it" line is on and out of combat, the members' `UNIT_AURA`, `UNIT_CONNECTION`, `UNIT_IN_RANGE_UPDATE`
  and `UNIT_HEALTH` through 23 unit listeners (player, party1-4, raid1-40, two units each);
  `UNIT_HEALTH` fires on every hit, so it redraws only when `UnitIsDeadOrGhost` changed since the last
  one. Refreshes go through one `ns.Later` key, at most one per drawn frame; a `UNIT_AURA` redraws only
  the "lacks it" icons on the frames showing that unit, and only a full refresh touches containers.
- **Tests:** `tests/wow_stubs.lua` fakes the container (`makeAuraContainer`): it fills a slot from the
  faked buffs by the `PLAYER` filter and the included spell IDs on every `UNIT_AURA` for its unit,
  regardless of combat and secrecy, and raises the client's error when the addon touches a slot button
  while `state.aurasWithheld`.
- **In-game checklist** ([`in-game.md`](in-game.md)): icons above the health bar at real frame
  sizes, "has it" icons in fights, and no taint errors after a raid fight with frames reassigned.

## What the game already has (#119)

From Forever's UI source (2026-11-10), still to be seen in game ([`in-game.md`](in-game.md)):

- **Edit Mode** has, for the raid frames and for the party frames while they're raid style
  (`EditModeUnitFrameSystemMixin:ShouldShowSetting`), "Aura organization" (Legacy, buffs top and
  debuffs bottom, buffs right and debuffs left), "Buff icon size" (50-200%), the debuff icon size and
  the big defensive icon's size (`Blizzard_EditMode/Shared/EditModeSettingDisplayInfo.lua`). All of
  them place and size the game's own icons; none touches ours. So the page's size slider (#122) stays,
  for tracked buffs only, as #110 planned, and nothing on the page duplicates Edit Mode.
- **The Cooldown Manager's settings** have a "Group Auras" tab (`Blizzard_CooldownViewer`,
  `GroupBuffFilter.lua`, loaded on `camelot`), greyed out while the class has fewer than two group
  buffs (`C_CooldownViewer.GetGroupBuffItems`). It splits the class's group buffs into shown and
  hidden, which takes a hidden one off the game's group frames (`C_UnitAuras.SetHiddenGroupBuffs`),
  and gives a shown one a visual alert (marching ants or a flash, `SetGroupBuffVisualAlerts`) on its
  icon while it's there. That's the per-buff filter of the game's icons #110 left out of scope (Mark
  of the Wild on every member can be hidden there), not a "lacks it" signal, so nothing on the page or
  in #121 repeats it. Both setters are restricted (`HasRestrictions`, secrets only when untainted):
  QoL doesn't call them; it could read `GetHiddenGroupBuffs` if it ever needed to.

## When group buff data is secret (#119)

Seen in game 2026-11-10 (a `/run` macro on an action button, a party of three, Regrowth of the
player's on party1, the macro in [`in-game.md`](in-game.md)): group members' buffs behave like the
player's own.

- **Out of combat**, in the open world and in a dungeon: `ShouldAurasBeSecret()` false,
  `ShouldUnitAuraIndexBeSecret("party1", 1, "HELPFUL|PLAYER")` false,
  `ShouldSpellAuraBeSecret(8936)` (Regrowth) false, and `GetAuraDataByIndex` returns the aura.
- **In any fight**, open world and dungeon alike: all three say true, and `GetAuraDataByIndex` raises
  `Auras cannot be accessed when secret while tainted` instead of returning secret values. The docs
  agree: every aura read (`GetAuraDataByIndex`, `GetAuraDataByAuraInstanceID`, `GetUnitAuras`,
  `GetAuraDuration`) is `RequiresUnitAuraAccess`. Only Regrowth was asked per spell.

So tracked buffs that QoL reads itself are blank for the whole of every fight and come back when it
ends. That is more than "goes quiet now and then", which #110 assumed, and it's why #135 moved "has it"
icons to the game's aura container, which reads them in the secure environment, and keeps "lacks it"
icons to between fights.

## Hiding the raid manager

The raid manager is `CompactRaidFrameManager`, the tab at the screen's edge that
`CompactRaidFrameManager_UpdateShown` shows in every group (`Blizzard_CompactRaidFrames`, loaded with
the game's UI, not on demand). `hideRaidManager` is one more target of the hide-frames feature
(`HideFrames.TARGETS`), so it's hidden the way every other target is, and is taint-safe for the same
reasons:

- It's parented to `ns.Hider`'s holder through `ns.Later`, from a frame of ours and out of combat,
  never with `Hide()` and a hook. The game's own `SetShown` from `UpdateShown` then changes nothing,
  and no field of the manager is written, no method of it called or hooked.
- Unticked, it goes back to the parent it had (`UIParent`), and the game's next `UpdateShown` decides
  as usual whether it shows.
- The group frames stay: on Forever (the `Mainline` family of `Blizzard_CompactRaidFrames`)
  `CompactRaidFrameContainer` is `UIParent`'s, not a child of the manager, so hiding the manager
  doesn't take them along. The manager keeps working while hidden; the container doesn't depend on it
  being shown. Edit Mode's preset layouts anchor the party and raid frames to the manager
  (`EditModePresetLayouts.lua`, `relativeTo = "CompactRaidFrameManager"`); a frame anchored to a hidden
  one still gets its position, and the manager keeps its own anchor to `UIParent` under the holder, so
  they stay where they were (on the in-game checklist, [`in-game.md`](in-game.md)).

## The game's buffs

The checkbox is the game's `raidFramesDisplayBuffs` CVar (`GroupFrames.GAME_BUFFS_CVAR`).
`Blizzard_CompactUnitFrameProfiles` turns it into the frames' `displayBuffs` option on every change
(`CVarCallbackRegistry`), so writing the CVar is all it takes, and nothing of ours touches a frame.
The page reads and writes it through `ns.HiddenSettings`, as the Graphics & Camera page does its rows
([`advanced-settings.md`](advanced-settings.md)): QoL keeps no copy, writes it only on a click, and its
row has no reset, so the page's Defaults button leaves it alone. It's greyed out while
`HiddenSettings.CanChange` says the game wouldn't take it (in combat, if the game protects it), and the
page refreshes on `CVAR_UPDATE` for it, so a change in the game's options shows.
