---
status: accepted
---

# Back buttons get a key per bar, the trigger read by Steam Input

Supersedes ADR 0006. Played with, back buttons that followed a trigger only with the trigger toggle
on looked broken: holding LT changed nothing. A hold-only mode of the toggle's header was built next
(QoL owning the triggers whenever the back buttons are on), but owning the trigger keys hides them
from the game: its own trigger icons and bar focus stop moving, every bar key goes through our
relays, and a bug in that path breaks the whole controller bar. That's a lot of machinery to read
one held trigger.

So the triggers stay the game's, and each controller bar's back buttons get keys of their own: 16
buttons, 16 bindings (`QoLBackButton1` to `4` for Top, keeping the old names so bound keys stay,
then `QoLBackButtonLeft1` to `Bottom4`). On the Steam Deck, Steam Input sends another key for a
back button while a trigger is held (an action layer or mode shift on the trigger), and the player
binds that key to that bar's button. The back buttons' art follows the game's own active bar
(`ACTIVE_ACTION_BAR_UPDATED_EVENT`, read only), the bar in use full size and the others small, in
combat too. All 16 show in the full layout as a cross per back button at the far left and right of
the page unit; the compact layout shows the bar in use's beside the one bar.

## Considered options

- **Owning the triggers for holds (built, then dropped)**: works without setup outside the game,
  but takes the triggers from the game, as above.
- **Only through the trigger toggle (ADR 0006)**: no hold works without the toggle.
- **Bindings per modifier (`SHIFT-F13` and so on)**: never fire, since no modifier arrives with a
  trigger.

## Consequences

- Without a Steam Input layer (or another way to send a key per trigger), only Top's back buttons
  work by key; the others still work by mouse or touch.
- Only Top's buttons fall back to the paddle keys: a controller the game sees directly has no way
  to send another key per trigger.
- With the trigger toggle on, the game's active bar stays Top, so the art does too, while every key
  still presses its own bar's.
- The trigger toggle and the back buttons are independent again, except that a back button pressed
  during a hold marks the trigger used.
