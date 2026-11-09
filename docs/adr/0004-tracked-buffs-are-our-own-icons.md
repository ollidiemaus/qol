---
status: accepted
---

# Tracked buffs are QoL's own icons on the group frames

On Forever a group frame's buff icons aren't frames an addon can reach: the frame hands the client a
few numbers (how many buffs, their size, one of three layouts, buffs on or off), and a Blizzard addon
in the secure environment picks and draws the icons. So QoL can't resize, move or filter the game's
icons one by one. Tracked buffs are therefore icons of QoL's own, anchored to the group frames, and
the game's icons are left to the game's switches: the page offers the game's "Display buffs" setting
so the player can turn them all off and keep only tracked buffs.

## Considered options

- **A page that only sets the game's own settings** (buff icon size, aura layout, the group buff
  filter, Display buffs): no icons of ours, but no free position, no spell list of the player's and no
  icon for a buff a member lacks.

## Consequences

- QoL reads the group's buffs itself, so a tracked buff hides while the game keeps that buff's data
  secret, and shows again once it's readable.
- The icons are plain and let the mouse through: a button that casts would have to be protected, and
  click casting on the group frame underneath already does that job.
