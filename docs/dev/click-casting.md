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
  `GetParent` reaches a protected parent only, so the walk works there too. A part can have the
  secret `ObjectSecurity` aspect (seen on the health bar: `IsProtected` is secret, and so is what
  `SecureHandlerWrapScript` tests on our taint; on a party frame's part `IsMouseMotionEnabled` was
  secret too), so it isn't wrapped then: `wrap` tries that frame's
  parts again at the next update, and until then the keys go off over that bar. The tests' handles are
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
  stack. Forbidden frames and nameplates known by name or unit are left out. Forever's nameplate
  unit frames aren't known that way: they come from a pool without a name, and `SetUpFrame` runs
  before `SetUnit`, so they're in. `EnableMouse` is off and the frame has no `OnClick` (checked in
  game, the template doesn't inherit `SecureUnitButtonTemplate`), yet a click on a plate casts what
  its click attributes say: the game's hit test reads them itself. It never gets `OnEnter`, so keys
  and the wheel do nothing there. A frame that turns up in combat gets the bindings once it ends.
- Enemy nameplates (`clickCastEnemies`, off by default): that click ignores `*harmbutton<n>`
  (seen in game: set, and the spell still cast), so `SecureUnitButton_OnClick`'s remapping is no way
  to tell friend from foe. Instead an enemy plate has no QoL attributes at all (`leftToGame`, a plate
  told by its mixin's `SetNamePlateFrame`), so it has the game's own values. A pooled plate changes
  unit and side in combat, so `NAME_PLATE_UNIT_ADDED` and `UNIT_FACTION` on a nameplate unit run
  `updatePlates` through `ns.Later(..., true)`, in combat too: the template isn't protected. A plate
  that answers `IsProtected` otherwise, or with a secret, waits for the end of combat.
- Enemy on the target, target of target, focus and focus target frames (`EITHER_SIDE`, same option):
  their units change in combat and they're protected, but they are real secure unit buttons, so `*harmbutton<n>` does work: `offOnEnemies` sends Left and Right to
  `qolenemy1` and 2, with the frame's own `*type1` and `*type2`, and any other button to `qolenemy`,
  which has no type. `SecureUnitButton_OnClick` looks at the real button's type first; that only
  stops `target` or `menu` the game doesn't bind, and QoL writes those as `click`. Keys: `ENTER`
  binds none on a frame with `qol-enemies-off` whose unit is `[harm]`. It's asked on entering, so
  a unit changing under a mouse that stays keeps what was bound. Boss and arena frames only show
  enemies, so they aren't covered: bindings there are meant for enemies.
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
- A binding's saved spell ID only says which spell it is: `ClickCast.Highest` works out the highest
  rank whenever it's asked, for the page's icon and tooltip, for `Works` and for `ClickCast.Same`, so
  nothing is rewritten and a rank learned needs only the page's refresh on what the character has.
  It asks `C_Spell.GetSpellIDForSpellIdentifier` with the name (seen in game on Forever, for one
  spell; Blizzard's cast sequences use it too) and takes the answer only if the character knows that
  spell, as the name can be an NPC's spell too. Otherwise, or with no such API, it's the saved ID.
  `ClickCast.Same` makes the ranks of a spell one action for the bound check, quick bind's replaced
  list and clash marks; rings hold fixed ranks, so `Entries.Same` stays. A saved rank whose subtext
  isn't loaded (the one a respec took away, likely) counts as having no rank until it is, so
  `hasRank` asks for it and `SPELL_DATA_LOAD_RESULT` updates the bindings and the page.
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
