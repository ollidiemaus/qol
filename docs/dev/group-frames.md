# Group frames

The Group Frames page (WoW Forever only, `GroupFrames.IsAvailable`) is about the game's own
raid-style party and raid frames. The design for the whole area, tracked buffs included, is in issue
#110 and [ADR 0004](../adr/0004-tracked-buffs-are-our-own-icons.md); this note grows with it.

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
  being shown.

## The game's buffs

The checkbox is the game's `raidFramesDisplayBuffs` CVar (`GroupFrames.GAME_BUFFS_CVAR`).
`Blizzard_CompactUnitFrameProfiles` turns it into the frames' `displayBuffs` option on every change
(`CVarCallbackRegistry`), so writing the CVar is all it takes, and nothing of ours touches a frame.
The page reads and writes it through `ns.HiddenSettings`, as the Graphics & Camera page does its rows
([`advanced-settings.md`](advanced-settings.md)): QoL keeps no copy, writes it only on a click, and its
row has no reset, so the page's Defaults button leaves it alone. It's greyed out while
`HiddenSettings.CanChange` says the game wouldn't take it (in combat, if the game protects it), and the
page refreshes on `CVAR_UPDATE` for it, so a change in the game's options shows.
