# Group frames

The Group Frames page (WoW Forever only, `GroupFrames.IsAvailable`) is about the game's own
raid-style party and raid frames. The design for the whole area, tracked buffs included, is in issue
#110 and [ADR 0004](../adr/0004-tracked-buffs-are-our-own-icons.md); this note grows with it.

## Tracked buffs

Icons of QoL's own on every group frame (`Features/GroupFrames.lua`), for the spells in
`QoLDB.trackedBuffs` (`{ spell, kind, on }`, account-wide, in the order added; not an option, so the
page's Defaults button only switches `groupFrameBuffs` off). So far only the "has it" kind: the icon
shows while the player's own cast of the buff is on the member, with the cooldown sweep and a stack
number above one, all at one spot (the top right corner, side by side towards the left, 16 pixels).
A line applies only where the character knows the spell at some rank (`ns.KnowsAnyRank`, shared
with the reminders); the page greys out the others. An entry with a kind this QoL doesn't know (a
newer QoL's) stays in the list and is left out of everything else.

- **Matching:** `C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")` lists the player's own
  casts on the member; one counts when its name is the one the client gives the stored spell ID, so
  any rank and any locale match.
- **Which frames:** the same hook click casting has, `hooksecurefunc("CompactUnitFrame_SetUpFrame")`,
  a hook on a global function that only notes the frame (nameplates come through it too). Each
  refresh reads the frame's `unit` field and draws only for `player`, `partyN` and `raidN`: pets,
  arena and nameplates get nothing. The unit is read on every refresh, since the game hands a frame
  to another member on a roster change (`CompactUnitFrame_SetUnit`), and `GROUP_ROSTER_UPDATE`
  redraws every frame.
- **Taint-safe:** each frame gets a holder of ours, made the first time it shows an icon: its child,
  `SetAllPoints` on it, a few levels above it (`GetFrameLevel`, a read). Nothing is written on, hooked
  on or called on the game's frame. Neither the holder nor the icons are protected or take the mouse,
  so clicks and click casting reach the frame underneath, and they're made, shown, hidden and placed
  in combat too (`ns.Later` with `inCombat`); a frame set up in combat gets its icons at once.
- **Secrecy:** while `C_Secrets.ShouldAurasBeSecret()` says so, every icon hides and nothing is read
  (reading then is an error for addon code). Otherwise every value read goes through `ns.IsUsable`
  first: a secret aura or name hides every icon on that frame (we can't tell which buff it is), a
  secret stack count, duration or expiry hides that one icon. Nothing read is kept, so the first
  refresh once it's readable shows them again. `ADDON_RESTRICTION_STATE_CHANGED` (and combat starting
  and ending) redraw every frame.
- **Cost:** with the switch off nothing is heard (the setup hook only notes frames). On, only
  `GROUP_ROSTER_UPDATE`, to know when the character is in a group (`IsInGroup`). In a group, the
  members' `UNIT_AURA` through 23 unit listeners (player, party1-4, raid1-40, two units each), and
  `SPELLS_CHANGED`, `ADDON_RESTRICTION_STATE_CHANGED`, the combat events and `PLAYER_ENTERING_WORLD`.
  Refreshes go through one `ns.Later` key, at most one per drawn frame, and a `UNIT_AURA` redraws
  only the frames showing that unit.
- **In-game checklist** ([`in-game.md`](in-game.md)): icons above the health bar at real frame
  sizes, no taint errors after a raid fight with frames reassigned, and when Forever keeps group buff
  data secret (in and out of combat, in a dungeon).

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

When the game keeps group members' buff data secret isn't known yet: on the player, buffs are
readable out of combat and an error to read in any fight (`forever-notes.md`, Secret values). The
feature already goes quiet whenever `ShouldAurasBeSecret` says so; the in-game check tells how often.

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
