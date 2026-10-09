# Developing Forever QoL

Notes for working on the addon. What it does for players is in the [README](../README.md).

## Layout

| Folder | What's in it |
|---|---|
| `Core/` | Namespace and printing (`Init`), the event frame (`Events`), saved options with defaults and change watchers (`Options`), deferred changes (`Later`), the hidden holder for hidden frames (`Hider`), `/fqol` (`Slash`) and startup (`Lifecycle`) |
| `Features/` | One file per feature: `Merchant`, `Tooltips`, `HideFrames`, `Viewport`, `ActionBars` |
| `UI/Settings.lua` | The pages under Options > AddOns, all proxy settings onto `ns.Options` |
| `Locales/` | English strings, German overrides |
| `tests/` | Specs run in plain Lua against `tests/wow_stubs.lua` |

Features never talk to each other or to the settings page. The page writes `ns.Options`; a feature
reads it with `Options:Get` and reacts to changes through `Options:Watch`.

## Rules for touching Blizzard frames

Forever and retail 12.x hand out secret values, and taint that leaks into Blizzard code breaks
unrelated frames ("tainted by 'ForeverQoL'"). Action Bar Button Growth Direction learned this the
hard way on the Forever beta. So:

- Never write a field on a Blizzard frame, never call its layout or update methods, and never
  `hooksecurefunc` its methods. Read fields, call widget methods (`SetPoint`, `SetParent`).
- Every change to a Blizzard frame goes through `ns.Later(key, fn)`: it runs on a fresh timer (never
  inside a Blizzard call stack) and waits for the end of combat.
- Hide frames by parenting them to `ns.Hider`'s holder instead of `Hide()` plus hooks; Blizzard's
  own `Show()` calls then change nothing.
- Compare or compute with game values only after `ns.IsUsable(value)` (nil and secret values fail).
- Register events through `ns.Events:On`; it skips events the client doesn't know.
- Leave `WorldFrame` alone while a cutscene plays. Blizzard's `CinematicFrame` re-anchors it for
  the black bars and resets it to full screen at the end; `MovieFrame` hides it. Two hands on
  `WorldFrame` during a cutscene is how viewport addons crash the game. The viewport waits until
  `CinematicFrame` and `MovieFrame` are both hidden (checking back every second) and then applies
  itself again.

The action bar flip copies the grid math of `ActionBarMixin:UpdateGridLayout` and applies it to the
bar's button containers only. Blizzard stores a new `oldGridSettings` table each time it lays a bar
out, so events are just wake-ups: a bar is laid out again only when that table changed since our
last pass (or the settings changed).

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

Link or copy the repository into the client's AddOns folder as `ForeverQoL` (on the Forever beta:
`_classic_beta_/Interface/AddOns/ForeverQoL`). The client only loads what the TOC lists, so `docs/`
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
`tests/` and `README.md`, and creates the GitHub release. For CurseForge uploads, add
`## X-Curse-Project-ID` to the TOC and the `CF_API_KEY` repository secret.
