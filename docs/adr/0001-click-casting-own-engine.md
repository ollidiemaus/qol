# Click casting runs on its own engine, not on the game's Click Casting

Forever and retail ship the game's own Click Casting, which the game saves and which changes no
frames, but it takes only mouse clicks, and the call that writes its bindings is restricted, so an
addon may not be allowed to use it. QoL's click casting sets its own click attributes on the unit
frames and binds keys while the mouse is over one, because bindings for keys, and quick bind for
them, are what the feature is for.

## Consequences

- QoL changes Blizzard's unit frames, so it has to follow the taint rules in `docs/DEVELOPMENT.md`
  for every frame it registers.
- Where the game's Click Casting binds a spell, a macro or a pet action to the same click, the game's
  binding wins: `SecureUnitButton_OnClick` asks the game's bindings first. Its Target and menu
  bindings don't get in the way, as they fall back to the frame's attributes.
