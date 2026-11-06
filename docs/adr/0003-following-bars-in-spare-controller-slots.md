---
status: proposed
---

# Following bars keep their spells in the spare controller slots

Forever accepts controller actions in slots 181-360, but its UI only accounts for 181-304 (the three
pages and the five stance bars), which leaves 305-360 with no documented use. Following bars keep
their spells there, because the player must be able to fill them in the game's own editor, and that
editor refuses any slot outside the valid range, so slots of QoL's own outside it were out. It's an
undocumented range in a beta client: a spell did survive a logout there (2026-11-06), but Blizzard
may claim it later, and then this has to move.

The game's editor writes to the slot in `button:GetID()`, so a following bar's buttons really change
their ID, from a secure handler so it works in combat, rather than being covered by buttons of ours.
This depends on an in-game test that hasn't been done yet; this stays proposed until it passes.

## Considered options

- **Borrowing bars from pages 2 and 3**: storage the game surely saves, and the fallback if the spare
  slots stop working, but it takes bars away from the player and gives only two spare pages.
- **Slots outside the valid range, with an editor of our own**: no space limit, but a second editor
  for something the game's already does.
- **Our own buttons over the bars**: no touching of the game's buttons, but they'd need their own key
  routing and art, and the game's editor couldn't fill them.
