# Click casting

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

Click casting (`Features/ClickCast.lua`) is its own engine, not the game's Click Casting (ADR 0001),
with each character's bindings in `QoLDB.clickCast[name-realm]` (ADR 0002):
`{ combination = "SHIFT-BUTTON1", action = { kind = "spell", id = 774 } }`. A combination is in the
game's key binding notation (`ALT-CTRL-SHIFT-`, `BUTTON1` to `BUTTON5`, `MOUSEWHEELUP`,
`MOUSEWHEELDOWN`); an action is a ring entry's shape (spell, item or macro, `RingEntries` says
whether the character has it) or `target` or `menu`. A binding works while the character has its
action; on each combination the first working one is used (the page marks a clash, quick bind never
makes one). A binding with any other action, or not shaped like one, stays saved and unused
(`ClickCast.List` leaves it out; the page's indexes are that list's).

- What it changes on a Blizzard unit frame, and only out of combat (`ns.LaterOutsideWindows`): its
  click attributes, with `SetAttribute`. Before the first change it keeps the frame's own value of
  each attribute it sets (`originals`), and gives it back when the attribute isn't wanted any more,
  the frame leaves, or the option goes off, so turning it off gives the game's clicks back without a
  reload. It writes `*type1` and `*type2` as nil (a click with no binding does nothing), then
  `<modifiers>type<n>` plus `<modifiers>spell<n>`, `item<n>` or `macro<n>` per click binding, and
  `qol-clickcast`. The frames keep the game's click registration (on release). Target and Menu
  use the frame's own `*type1` and `*type2` values. Nothing is a field write or a call into
  Blizzard code: attributes are widget state the secure templates read, and the frames' scripts are
  only wrapped (below).
- The game's unit button click handler (`SecureUnitButton_OnClick`) asks the game's Click Casting
  first: its spell, macro and pet bindings win (the page marks those, from
  `C_ClickBindings.GetProfileInfo`, in a `pcall`), and an interaction binding remaps the button to
  the one the interaction is on. Where the game binds no interaction to a combination, it blocks
  `target`, `menu` and `togglemenu` there, so Target and Menu on other combinations are a `click` on
  `QoLClickCastClicks` (`clickbutton`), a secure action button of ours that does them on the
  frame's unit. That assumes the game's own Target and Menu on Left and Right: a player who moved
  them in the game's Click Casting gets the remapped button's attributes. The game's modifier bits
  are read with `GetStringFromModifiers` against `SHIFT_KEY_TEXT`, `CTRL_KEY_TEXT` and
  `ALT_KEY_TEXT` (Shift first: German UMSCHALT has ALT in it).
- Keys and the wheel: one secure action button of ours, `QoLClickCastKeys` (`AnyDown`,
  `useOnKeyDown`), has `*type-k<i>` and its action per key binding. Each frame's `OnEnter`, `OnLeave`
  and `OnHide` are wrapped (`SecureHandlerWrapScript`) on our header `QoLClickCast`: over a frame with
  `qol-clickcast`, the snippet puts the frame's unit on both buttons and binds each key to a click on
  the keys button (`SetBindingClick(true, ...)`, priority override bindings, so a ring's key gives way
  over a unit frame), and keeps the frame's handle (`hovered`, in the header's environment); leaving
  or hiding that frame clears them, and another frame hiding (the target of target losing its unit)
  doesn't. The parts of a frame that take the mouse and are protected get the same wraps: Forever's
  health and mana bars (`TextStatusBar`, `enableMouseMotion`) and their containers, with
  `SecureFrameParentPropagationTemplate`, take the mouse from the frame, and the game leaves the
  frame before it enters the bar, so without them the keys went off over the bars. The snippet walks
  up from the part with `GetParent` to the frame with `qol-clickcast`, and `hovered` is the part, so
  leaving the frame for its bar keeps the keys. Only protected parts: in combat a handle's
  `GetParent` reaches a protected parent only, so the walk works there too. The tests' handles are
  one per frame, as the game's are, so they compare. The wraps stay
  once made (unwrapping could take
  off another addon's wrap made later); with click casting off, `qol-clickcast` is gone and they do
  nothing.
- Which frames: `PlayerFrame`, `TargetFrame`, `TargetFrameToT`, `FocusFrame`, `FocusFrameToT`,
  `PetFrame`, the party pool's frames and their `PetFrame`, `Boss1TargetFrame` to 5,
  `ArenaEnemyMatchFrame1` to 5 and `ArenaEnemyFrame1` to 5 (the arena UI loads on demand: on its
  `ADDON_LOADED`), and the
  raid-style frames: `hooksecurefunc("CompactUnitFrame_SetUpFrame", ...)` on the global function
  (not a frame's method) only notes the frame and schedules the change, outside Blizzard's call
  stack. Nameplates (by name or by unit) and forbidden frames are left out. A frame that turns up in
  combat gets the bindings once it ends.
- Other addons' frames: unless another addon made `ClickCastHeader` first, QoL provides the shared
  `ClickCastFrames` table (writing `ClickCastFrames[frame] = true` or nil puts a frame in or out; a
  plain table a unit frame addon made before QoL loaded is taken over with its frames) and
  `ClickCastHeader` (our header), with `clickcast_register` and `clickcast_unregister` snippets for
  the frame handle in `clickcast_button`. A handle is no use to insecure code, so the snippet sets
  the frame's name on `qol-joined` or `qol-left` and our `OnAttributeChanged` finds it with `_G`: a
  frame without a name can't join that way (it can through `ClickCastFrames`). The tests' handles
  error outside a snippet, as the game's are useless there. With click casting on, both are there
  from QoL's `ADDON_LOADED` (`ClickCast:Provide`), for unit frame addons that look for the header
  as they build their frames (at their load or at login); frames joining then get their bindings at
  login, since nothing runs before it. Turned on later, QoL provides them then, and the frames
  another addon built before only join after a reload.
- Grid2 joins click casting only through a global `Clique` (it gives its frames Clique's
  `ClickCastUnitTemplate`, and sets `Clique.header` on its headers). QoL doesn't pose as Clique: the
  template is XML another addon can't declare a second time, and other addons read `Clique` as
  "Clique is here". Instead, where QoL provides the header, it hooks `Grid2Frame:RegisterFrame`
  (`hooksecurefunc` on Grid2's method, after it) and takes the frames already in
  `Grid2Frame.registeredFrames`, so Grid2's frames join like any other, turned on later too. Where
  another click casting addon has the header, Grid2's frames are that addon's.
- A spell with a rank (a digit in `C_Spell.GetSpellSubtext`) is cast by name, so the highest rank
  known is cast. Items use `item:<id>`, macros their name.
- The header, the buttons and the frames change on the option, the bindings, and, while it's on,
  what the character has (`RingEntries.KNOWN_EVENTS`), `GROUP_ROSTER_UPDATE`, a raid-style frame
  set up and the arena UI loading. In combat everything stays as it was when it started.
- The page (`Features/ClickCastEditor.lua`) is built like the rings' editor, on `RingPicker.NewPage`
  and `RingPicker.Create` (Spells, Items and Macros, rows taking every mouse button, the wheel
  handed to the page in quick bind). A combination is waited for by a full-screen frame of ours at
  `FULLSCREEN_DIALOG` that takes the keyboard, the mouse buttons and the wheel
  (`CreateKeyChordStringUsingMetaKeyState`; a combination with the Mac's Cmd, `META-`, is refused,
  since combinations have only `ALT-CTRL-SHIFT-`); a binding added from the list or the cursor is
  saved only once it has a combination. Keys are refused where `IsKeyPressIgnoredForBinding` (the
  game's Key Bindings' test) says so, but not mouse buttons: on Forever it ignores `BUTTON1` and
  `BUTTON2` too, which kept Left and Right (Alt-Left: Target, say) from being bound. Target and Menu
  stay listed while nothing binds them, as the game's Click Casting lists them, with a box that
  binds them again and no right-click removal: they aren't in the list on the right. Quick bind
  replacing a clash replaces every working binding on the combination and names them all. Quick bind
  is a keyboard frame that keeps a key only while the mouse is over a row of the list
  (`List:EntryUnderMouse`) and passes the others on (`SetPropagateKeyboardInput`, out of combat:
  quick bind ends on `PLAYER_REGEN_DISABLED`).
- While click casting is off the page changes nothing, as in combat: everything but the note is at
  half alpha (`editor.parts`), the boxes and Quick bind are disabled, the clicks, drags and
  right-clicks do nothing, and the tooltips leave out what a click does. Turning it off stops a box
  waiting and ends quick bind. The pages still turn, so the bindings can be read.
