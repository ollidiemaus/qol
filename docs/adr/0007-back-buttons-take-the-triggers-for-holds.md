---
status: accepted
---

# Back buttons take the triggers for holds, toggle or not

Supersedes the toggle-only rule of ADR 0006. Played with, the back buttons that only followed a
trigger with the trigger toggle on looked broken: holding LT changed nothing, and the other bars'
back buttons never showed. Players expect RT with L4 to just work, the way RT with A does.

So while the back buttons are on, the trigger toggle's secure header owns the triggers even with
its own option off, in a hold-only mode: a press counts as used the moment it goes down, so letting
go never switches a bar on. Everything else is the toggle's machinery as it stands: the relays press
the held bar's game buttons (the game no longer sees the triggers), the marker shows the held bar,
and LT and RT held mean Bottom; letting one go gives the other's bar. The back buttons' header says it wants
this with a `wantsbar` attribute; the toggle watches it out of combat. All 16 back buttons show in
the full layout, a cross per back button at the far left and right of the page unit (each holding
that button's four bars where the game's cross of bars has them, the bar in use's full size, the
others small), clear of the game's LB and RB prompts and of the interlocking bars.

## Consequences

- With the back buttons on, a trigger held with a bar key goes through our relays instead of the
  game's own bar switching, toggle on or off. That's the toggle's tested path, but it means the game's
  trigger icons and bar focus no longer move; our marker does instead.
- Turning the back buttons off gives the triggers back to the game, unless the toggle is on.
