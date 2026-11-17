---
status: accepted
---

# Threat badges are our own, not the game's numeric threat

Forever's target and focus frames already have a numeric threat badge (`NumericalThreat`, shown with
the `threatShowNumeric` hidden setting), sitting on the name background exactly where QoL's threat
badge goes. QoL still draws its own badge on a frame of ours, anchored to that name background, and
hides the game's while ours is on. Only our own frame can have Forever's bronze border, the tank
colors (the game shows a tank who lost aggro in orange, never green when holding it) and one look
shared with the nameplate badge, which the game has no counterpart for; and reskinning the game's
badge would mean writing to a Blizzard frame that the game updates in combat.

## Considered options

- **Turning on `threatShowNumeric` and reskinning the game's badge**: less code, but a Blizzard frame
  written to, the game's colors kept, and nothing for nameplates.
- **Percent bands for the colors** (e.g. yellow from 50 %): the badge uses the game's four threat
  states instead, which mean the same as the game's portrait glow, while the number already shows how
  close a pull is.

## Consequences

- The badge follows the game's number: raw percent, and a tank's lead over the next player while
  tanking.
- Threat isn't secret on Forever in the open world or in dungeons (checked 2026-11 with
  `C_Secrets.ShouldUnitThreatStateBeSecret` and `ShouldUnitThreatValuesBeSecret`, both false in
  combat), so the badge compares and colors plainly. If that changes, its colors and number must move
  to status bars the game fills.
