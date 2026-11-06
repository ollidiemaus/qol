# Controller

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

Bar paging: each key bound to `ACTIONPAGE1` to `ACTIONPAGE6` gets an override binding on a frame of
ours that mirrors what the key without modifiers does (`GetBindingAction(base, true)`, so a bar
addon's override counts), which is how the game treats a modified key without a binding of its own.
The saved bindings are never changed. Our own overrides fire `UPDATE_BINDINGS` too; the update then
finds nothing to change.

The controller back buttons are four `SecureActionButtonTemplate` buttons of ours (`QoLBackButton1`
to `4`, `type` "action") on the last four slots of Action Bar 6, 7 or 8 (slots 153-156, 165-168,
177-180), so the controller bar's own slots and its paging are left alone and a spell can also be
put there from the standard bar. They hang off a plain frame of ours whose parent is
`GamepadMainActionBarFrame` (Blizzard_GamepadActionBars, loaded with the game on Forever, so it
exists at our `ADDON_LOADED`): they show, hide, scale and fade with the bar and nothing is hooked or
written on it. Their anchors are the bar's `PageUnit.LeftCenteredAnchor` and `RightCenteredAnchor`
(the d-pad and face button groups), which only Edit Mode moves, out of combat, and which the compact
layout moves too. A secure button makes its parents protected, so the holder is created, shown and
hidden through `ns.LaterOutsideWindows` (out of combat and away from the game's controller windows),
like the `type` and `action` attributes, which are set only when they change. The art is drawn on
regions of our own, copied from the bar's buttons
(`gamepad-actionbar-circleslot-*` atlases, `CircleMask`, the round portrait mask for the empty slot
and the cooldown swipe) and updated in combat (`ns.Later(..., true)`): icon, usability color, count
(`GetActionDisplayCount`, maybe secret, only passed to `SetText`), cooldown
(`C_ActionBar.GetActionCooldownDuration` into `SetCooldownFromDurationObject` on our own Cooldown)
and the selected rim. Cooldown and usability events ask for this many times a second in combat, so
the icon, tint, count and a cleared or `SetCooldown` cooldown go through `ns.Buttons`' setters
(`SetIcon`, `SetUsable`, `SetCount`, `ClearCooldown`, `SetCooldown`), which skip a value the region
shows already; the rings' slots use them too, and every change to those regions goes through them.
A secret value, and a duration object (new on each call), is always set. Dragging calls `PickupAction`/`PlaceAction` only out of combat, and with
`lockActionBars` on only with the `PICKUPACTION` modifier, as the game's bars do.

Bindings: `Bindings.xml` adds `CLICK QoLBackButtonN:LeftButton` under Key Bindings > AddOns, named
by `BINDING_HEADER_QOL` and `BINDING_NAME_...` globals set when `BackButtons.lua` loads. Whether keys
saved there fire in the controller interface wasn't sure, so every key bound to a button also gets
an override binding on a frame of ours (`SetOverrideBindingClick`, not priority: Blizzard's gamepad
windows set priority overrides of their own and win while they're open). A button with no key gets
its paddle key (`PADPADDLE1` to `4`, SDL numbering: 2 and 4 left, 1 and 3 right) when the paddle has
neither a saved binding nor one in the controller set (`C_KeyBindings.GetBindingByKey(key,
Enum.BindingContext.GamepadModeInGameCore)`, in a `pcall`). A trigger held while a back button
sends its key makes it a modified key; with nothing bound to that, the game uses the key without
modifiers, so no modifier variants are needed. As with bar paging, the overrides fire
`UPDATE_BINDINGS` and the next update finds nothing to change; they wait for the end of combat
and, in the controller interface, until no window of the game has the controller.
Steam Input on the Steam Deck sends keyboard keys for the back buttons, which is why a key binding,
not a fixed key, is the way in.

The Controller page is registered only when `GamepadMainActionBarFrame` exists (Forever); on retail
there's nothing for it to change.

The Controller page also has the back buttons' key bindings (`Page:Binding`, rows across the page):
the same `CLICK QoLBackButtonN:LeftButton` commands as Key Bindings > AddOns, each row named by its
slot on the chosen bar (the label is a function, asked again on each refresh, so it follows the
Slots dropdown). Each row has two buttons from the
game's own `KeyBindingFrameBindingButtonTemplate` and works like a row of the game's Key Bindings,
with code of our own rather than the game's `KeybindListener` (a Blizzard frame: starting it writes
its fields, which the [rules for Blizzard frames](../DEVELOPMENT.md#rules-for-touching-blizzard-frames) forbid): a click on a button shows a parentless frame of ours at
`FULLSCREEN_DIALOG` strata with an `OnKeyDown`, which takes the keyboard until a key comes
(modifiers alone wait for the rest, through `IsKeyPressIgnoredForBinding` and
`CreateKeyChordStringUsingMetaKeyState`), Escape comes, the
button is clicked again, the page hides, the row is greyed out or combat starts. The key is set as
the game's `KeybindListener:ProcessInput` sets it: both old keys cleared, the new key taken from
whatever had it (`SetBinding(key, nil, context)`), the keys bound again in their slots, in the
action's context (`C_KeyBindings.GetBindingContextForAction`). A right-click clears a slot. Gamepad
buttons are not listened for: the controller cursor needs A (a second press on the button stops
waiting) and B, and the Steam Deck's back buttons send keyboard keys anyway; a paddle needs no key.
Each change is saved right away (`SaveBindings(GetCurrentBindingSet())`), as the game's settings
save the bindings when they close: our window isn't theirs, so nothing else would save them. That
fires `UPDATE_BINDINGS`, and the back buttons' override bindings follow from there through
`ns.LaterOutsideWindows`. All frames (the buttons and the listener) are created when the pages are
built at login, not while a controller window is open, so SmartNavigation's `CreateFrame` hook
rebuilds no window for them.

## Following bars

Decided 2026-11-06; storage and the button change are in
[ADR 0003](../adr/0003-following-bars-in-spare-controller-slots.md). Terms are in `GLOSSARY.md`.
Built so far, in `Features/FollowingBars.lua`: Left, Right and Bottom following a stance, in and out
of combat, with the slots from the spare range. Still design, each with its ticket: page flips
(ticket 93, until then a stance change on page 2 or 3 moves the buttons as on page 1), the Top bar
(94), running out of slots (95, for now a stance that doesn't fit stays normal and the page says
nothing) and the live switch of interfaces (96, for now the ticks apply from the next login).

How it's built:

- A `SecureHandlerStateTemplate` frame of ours, made the first time a bar is ticked in the controller
  interface, holds everything the snippet needs as attributes: the ticks (`following-<bar>`), the
  normal slots, the slots handed out (`slots-<stance>-<bar>`) and frame refs to both page units'
  buttons. Attribute names are lower case: the game lowers them. There are no restricted tables.
- A state driver on `[bonusbar:1]` to `[bonusbar:5]` runs the `apply` snippet on every stance change.
  A change of the ticks or of the game's setting runs the same snippet, through
  `ns.LaterOutsideWindows`.
- The snippet hands out slots, because a stance can first come up in combat, when insecure code
  can't change a secure frame's attributes. Our `HookScript` on `OnAttributeChanged` writes each
  one to the saved data: insecure code may read them, and a write to `QoLDB` taints nothing.
- A bar that doesn't follow and hasn't moved is never touched, so with no stance, nothing ticked or
  only the game's bar nothing happens to the game's buttons. A bar that moved goes back to its
  normal slots, which are worked out once with the game's own
  `GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID`, for page 1.
- The stance is the offset as the game gives it, and it only names a group of slots of ours. So no
  offset is assumed to be a certain form, and nothing needs the game's own stance slots yet; ticket
  95 will, to find the groups a class doesn't use.

What the player gets:

- The Controller page has a "Bars that follow the stance" section with a checkbox per bar (Left,
  Right and Bottom so far), not a dropdown: dropdown menus have caused trouble in Forever's controller
  interface. The list is saved per character and one list holds for every stance.
- A stance is what the game treats as one: forms, warrior stances, stealth. Check with
  `GetBonusBarOffset()` or `[bonusbar:1/2/3/4/5]`; Easy Controller found plain `[bonusbar]` false in
  stealth on Forever.
- Each following bar has its own slots per stance. An empty slot stays empty, as on the game's stance
  bar; there's no fallback to the normal spell.
- Only page 1 follows. Flipping to page 2 or 3 in a stance shows those pages as usual.
- Only the Top bar's D-pad half follows: A, B, X and Y are reserved by the game.
- The game's `GamepadStanceBarOverride` is left alone. The bar it names keeps the game's stance slots
  and shows ticked and greyed out; QoL only adds bars.
- Spells are placed with the game's own editor, in the stance.
- Unticking a bar or turning the feature off keeps its spells, so ticking it again brings them back.

Slots: 181-264 are the pages and 265-304 the five stance bars (bear, offset 3, is 281). 305-360 are
spare, plus the groups of stance bars the class doesn't use. A bar's Top half needs 4 slots, any other
bar 8. Each stance and bar gets its slots the first time they're needed and keeps them. When there's
no room the stances learned first keep their bars, the others stay normal, and the page says so.

Mechanism: a secure handler calls `SetID` on the game's buttons (`HANDLE:SetID`, works in combat) and
sets an attribute so `OnAttributeChanged` runs `UpdateAction`. Two sets of buttons change, because
the editor doesn't use the bars the player sees: `GamepadMainActionBarFrame.PageUnit` and
`GamepadActionBarEditFrame.PageUnit` each have their own.

Blizzard resets the IDs on every page flip, so page 1 has to be reapplied after one, in combat too.
`ChangePageButton` isn't protected, so a wrap on it doesn't run in combat. The catch is a
`SecureHandlerWrapScript` on `OnAttributeChanged` of each button, which sees the two attributes the
flip sets. The order inside `UpdateAction` decides how they can be used:

1. `Update()` reads the slot's action and texture into locals.
2. Mid-way it sets `pressAndHoldAction` (lower case in the wrap), for every slot, empty ones too.
3. It then draws the icon from those locals, or hides the icon, count and cooldown if the slot is
   empty. A `SetID` made at step 2 runs its own full update, and this step overwrites it.
4. After `Update()`, `UpdatePingAttributes` sets `ping-receiver` if `self.action` holds an action,
   else clears it. A clear doesn't fire `OnAttributeChanged`.

So, on a flip back to page 1 in the stance, for a button on its normal slot:

- **Normal slot holds an action**: wait for `ping-receiver` (step 4), then move the button.
- **Normal slot empty**: step 4 won't fire for that slot, so move at `pressandholdaction` (step 2).
  `self.action` is the following slot by step 4, so if that holds an action `ping-receiver` does
  fire, and the button redraws there: `SetID` to the normal slot, attribute, `SetID` back, attribute,
  under a guard so that this doesn't move the button again. If it holds none, the hidden icon is right.

`HasAction` is in the restricted environment, which tells the two cases apart. The attribute that makes the
button update is one of ours, which the wrap ignores.

Tested in game on 2026-11-06, on the Left bar in bear with throwaway code: the slot changes on
entering and leaving the stance and the press casts the new spell, in and out of combat; the icon
follows; the editor writes to and clears the new slot; flips to pages 2 and 3 and back in combat
leave all 8 buttons right and block nothing. Not run in game: a spell on the normal slot with an
empty following slot, and any stance but bear. Cat is offset 1, slot 265.
Easy Controller gets no special handling; test with it on and fix what shows up.
