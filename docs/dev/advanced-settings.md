# Advanced settings

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

The Advanced settings page (last in the list) changes the game's **hidden settings**
(`Features/HiddenSettings.lua`, see `GLOSSARY.md`): CVars the game's options don't show, or show
with only part of their range. The module holds them as one table in the page's order (CVar, label
and tooltip, kind, range, step, section, game slider) and owns reading, setting and reading back
through `C_CVar`, falling back to the global functions, where a CVar the client doesn't know reads
as nil. Adding a row takes a table entry and its strings; the page builds a wide row per known
setting (sliders need the room) under a header per section, and leaves out unknown ones, the page
itself when the client knows none.

- **The CVar is the only truth.** There are no option keys and no saved data for these, and nothing
  is written at login: the game keeps the values as it would after `/console`. Don't "fix" this into
  a QoL copy that is applied at login: the game's own settings (its Ground Clutter, View Distance
  and Environment Detail sliders, a graphics quality preset, its Max Camera Distance slider) write
  some of these CVars too, so a copy would drift from what the game uses and then overwrite the
  player's later choice.
- **Read back after every set.** The game quietly ignores a value outside a CVar's range (no error,
  no clamping), so after each `SetCVar` the page refreshes and shows what `GetCVar` returns: a
  refused value shows the old one. The sliders cover exactly the ranges measured in Forever's client
  (2026-10-27); Classic Era's differ (below). `cameraDistanceMaxZoomFactor` takes 1.0 to 2.6 on
  Forever, while the game's own Max Camera Distance slider (`Camelot/ControlsOverrides.lua`) stops at 2.0 and moving it sets 2.0 or lower.
  Draw distance's were measured with `/qol probe` in retail's client (12.1.5, 2026-10-28), not yet in
  Forever's, which has the same CVars, game defaults and first-run values. `farclip`, `horizonStart`
  and `horizonClip` take any number, so their sliders cover what View Distance sets and a bit below
  (`farclip` from its game default of 1000). Sets happen at once, in combat too: none of these CVars
  is protected.
- **Protected in combat.** A CVar `C_CVar.GetCVarInfo` marks secure (its sixth value, `isSecure`)
  is one the game won't change in combat; `HiddenSettings.CanChange` is false for one of those in
  combat, and so is one whose game slider is, as its Reset writes that. The page tracks combat
  itself, from `PLAYER_REGEN_DISABLED` (which comes while `InCombatLockdown` is still false) to
  `PLAYER_REGEN_ENABLED`, and refreshes on both while it's shown. A row's `canChange` is its
  `enabled`, so the name, slider or checkbox, box and Reset grey out, and it guards the row's set
  and reset: Defaults leaves it alone, and a box typed into as combat starts writes nothing when it
  loses the keyboard. Every other row still sets at once. None of them was secure where it was
  measured (Forever's client, retail's for Draw distance); this guards later rows and other clients.
- **The raid copies stay alone.** `RAIDgroundEffectDist` and the rest are the game's, used while its
  Raid and Battleground graphics are on; the page never writes them, and its intro says raids and
  battlegrounds use those instead.
- **Following changes.** The window refreshes the page each time it shows it, and while it's shown the
  page refreshes on `CVAR_UPDATE` for a CVar in the table (`/console`, the game's options, another
  addon). Once for a burst, through `ns.Later` (in combat too): a game slider writes several CVars at
  once, the Defaults button a few for each slider, and `/qol probe` hundreds in one go. Whether
  Forever's client sends `CVAR_UPDATE` for every `SetCVar` isn't confirmed; the refresh on showing is
  the fallback.
- **Taint-safe.** The page touches no Blizzard frame: it only calls `SetCVar` and `GetCVar` on
  these CVars and the game sliders' (`graphicsViewDistance` and the others), from our own window,
  and leaves a protected one alone in combat.
- **The game default comes from the game.** Each row's Reset and the page's Defaults set the CVar to
  `GetCVarDefault` (on a client without it, `C_CVar.GetCVarInfo`'s second value), never to a value
  of ours, except on a row a game slider sets (below); the row's tooltip ends with the same default
  and Reset's tooltip shows it. Whether it's
  at the default is compared as numbers, as the game formats them inconsistently (`1.9` and
  `1.900000`); a client that doesn't say a default leaves Reset greyed out and the tooltips without
  it. Reset reads back like any set. Each slider row passes its `step` to `Page:Slider`, and has a
  box to type an exact value (see the input boxes in [`settings-window.md`](settings-window.md)).
- **Reset goes to the game slider, not the game default, where one sets the row.** The game's
  View Distance, Environment Detail and Ground Clutter sliders (`graphicsViewDistance` and the
  others, see `GLOSSARY.md`) set several hidden settings whenever they're moved; the table names
  that slider as the row's `gameSlider`. Writing a slider's current value again makes the client set
  every setting behind it again (measured in retail: `farclip` at 5000 went back to the 8000 its
  View Distance sets), so `HiddenSettings.Reset` does that for such a row, which also puts back the
  slider's other rows, just as moving the slider would. Don't "fix" it back to the game default:
  `farclip`'s (1000) is below anything View Distance sets (1500 to 10000), so Reset, and Defaults
  for every player, would cut the world off short. QoL can't know what a slider sets without a table
  of its own, so these rows' `isDefault` is always false (Reset never greys out), their tooltips
  leave out the game default, and Reset's tooltip names the slider and the other rows it resets.
  Defaults writes each slider once, through the `done` table its rows share. Rows the probe found
  no slider setting (`groundEffectFade`, `weatherDensity`, `lodObjectCullDist` and the camera
  distance) keep the game default. A game slider the client doesn't know counts as none
  (`HiddenSettings.GameSlider`): Classic Era has no View Distance, so its World distance and horizon
  rows Reset to the game default, grey out there and show it in their tooltips, as any row no
  slider sets; and in combat only their own secure flag counts. Writing the missing slider would
  do nothing, leaving no way back to the game's values.
- **Measuring them.** `/qol probe` measures the ranges, game defaults and the game sliders in the
  client it runs in; see "The hidden settings probe" under "Trying it in game".
- **Classic Era** has the same `C_CVar` calls and the Environment Detail and Ground Clutter
  sliders, but no View Distance (`slider.graphicsViewDistance = missing`). It knows every hidden
  setting in the table, Always sharpen too. `/qol probe` there (1.15.9 build 70576, deDE,
  2026-10-30) measured other ranges than Forever's: `cameraDistanceMaxZoomFactor` 1 to 4 (its own
  Max Camera Distance slider still stops at 2.0), `groundEffectDist` from 70 (its Ground Clutter sets
  70 to 320), and game defaults `farclip` 2112, `horizonStart` 777, `horizonClip` 1600. A row's
  `classicEra` table holds what it takes there in place of its own (min, max, tooltip), so one row
  says what a setting does on each client; `HiddenSettings` applies it at load when `WOW_PROJECT_ID`
  is `WOW_PROJECT_CLASSIC`. That's the one place the page names the flavor: elsewhere QoL tells
  clients apart by what they have, but the game doesn't report a setting's range. Other Classic
  clients (TBC Anniversary and later) have their own project IDs and keep the row's values until
  they're measured. Their World distance and horizon tooltips say no game setting changes them,
  in English only like the rest of Draw distance; Ground clutter distance's names 70 to 320 in
  German too. The probe's report stays diagnostics: nothing reads it back.
