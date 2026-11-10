---
status: accepted
---

# "Has it" icons are filled by the game's aura container

In every fight Forever keeps group members' buffs secret, and reading them from addon code raises an
error, so a tracked buff that QoL reads itself is blank for the whole fight (#119), exactly when a
healer needs it. The game's aura container (`CreateFrame("AuraContainer", ..., "CustomAuraContainerTemplate")`)
runs in the secure environment: given a unit, a filter and a set of spell IDs, it fills an icon,
cooldown and stack text of ours in and out of combat. So a "has it" icon is an aura slot on such a
container, and QoL only makes, places and enables it. A "lacks it" icon stays one QoL reads and draws
itself: the container shows only a buff that's there, never one that's missing, so "lacks it" icons
show only out of combat.

## Considered options

- **Reading buffs ourselves, blank in fights** (ADR 0004 as it was): no heal over time icons when they
  matter.
- **One container row per spot, laid out by the game**: no gaps, but the game picks the order, so an
  icon's place moves mid-fight.

## Consequences

- Each tracked buff has a fixed place in its spot's row, as QoL can't tell in a fight whether a "has
  it" icon shows: a buff that isn't up leaves a gap.
- The container matches spell IDs, not names, so "has it" is given every rank of the spell the
  character knows, taken from the spellbook and rebuilt when the spells change.
