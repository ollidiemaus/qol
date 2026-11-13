# Controller

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

Bar paging: each key bound to `ACTIONPAGE1` to `ACTIONPAGE6` gets an override binding on a frame of
ours that mirrors what the key without modifiers does (`GetBindingAction(base, true)`, so a bar
addon's override counts), which is how the game treats a modified key without a binding of its own.
The saved bindings are never changed. Our own overrides fire `UPDATE_BINDINGS` too; the update then
finds nothing to change.

The controller back buttons are 16 `SecureActionButtonTemplate` buttons of ours, four per controller
bar (`QoLBackButton1` to `4` for Top, `QoLBackButtonLeft1` to `4`, `...Right`, `...Bottom`; `type`
"action"), each bar's on
the last four slots of an action bar from 2 to 8 picked for it (Action Bar 8 is slots 177-180, 7 is
165-168, 6 is 153-156, and so on by the page of `MultiActionBars.lua`), so the controller bar's own
slots and its paging are left alone and a spell can also be put there from the standard bar. The
same 16 slots serve every controller page. Each button is pressed by its own keys (see "Back
buttons on every bar" below). The buttons hang off a plain frame of ours whose parent is
`GamepadMainActionBarFrame` (Blizzard_GamepadActionBars, loaded with the game on Forever, so it
exists at our `ADDON_LOADED`): they show, hide, scale and fade with the bar and nothing is hooked or
written on it. Each bar's four sit on a holder of their own (where: "Back buttons on every bar"). A
secure button makes its parents protected, so the holders are created, placed, shown and hidden
through `ns.LaterOutsideWindows` (out of combat and away from the game's controller windows), like
the `type` and `action` attributes, which are set only when they change. The art is drawn on
regions of our own, copied from the bar's buttons
(`gamepad-actionbar-circleslot-*` atlases, `CircleMask`, the round portrait mask for the empty slot
and the cooldown swipe) and updated in combat (`ns.Later(..., true)`): icon, usability color, count
(`GetActionDisplayCount`, maybe secret, only passed to `SetText`), cooldown
(`C_ActionBar.GetActionCooldownDuration` into `SetCooldownFromDurationObject` on our own Cooldown)
and the selected rim. Cooldown and usability events ask for this many times a second in combat, so
they are heard only while the buttons show (`Update` turns them on and off), and the icon, tint, count and a cleared or `SetCooldown` cooldown go through `ns.Buttons`' setters
(`SetIcon`, `SetUsable`, `SetCount`, `ClearCooldown`, `SetCooldown`), which skip a value the region
shows already; the rings' slots use them too, and every change to those regions goes through them.
A secret value, and a duration object (new on each call), is always set. Dragging calls `PickupAction`/`PlaceAction` only out of combat, and with
`lockActionBars` on only with the `PICKUPACTION` modifier, as the game's bars do.

Bindings: `Bindings.xml` adds the 16 `CLICK <button>:LeftButton` under Key Bindings > AddOns, named
by `BINDING_HEADER_QOL` and `BINDING_NAME_...` globals set when `BackButtons.lua` loads. Whether keys
saved there fire in the controller interface wasn't sure, so every key bound to a button also gets
an override binding on a frame of ours (`SetOverrideBindingClick`, not priority: Blizzard's gamepad
windows set priority overrides of their own and win while they're open). A Top button with no key
gets its paddle key (`PADPADDLE1` to `4`, SDL numbering: 2 and 4 left, 1 and 3 right) when the paddle has
neither a saved binding nor one in the controller set (`C_KeyBindings.GetBindingByKey(key,
Enum.BindingContext.GamepadModeInGameCore)`, in a `pcall`). Forever's triggers are no modifiers:
they are plain keys bound to `GAMEPADLEFTMOD` and `GAMEPADRIGHTMOD`, and the game picks a bar in its
own Lua by their key-down state (ADR 0006). A back button's key comes without a modifier whatever
trigger is held, so no modifier variants are needed. As with bar paging, the overrides fire
`UPDATE_BINDINGS` and the next update finds nothing to change; they wait for the end of combat
and, in the controller interface, until no window of the game has the controller.
Steam Input on the Steam Deck sends keyboard keys for the back buttons, which is why a key binding,
not a fixed key, is the way in.

The Controller and Back buttons pages are registered only when `GamepadMainActionBarFrame` exists
(Forever); on retail there's nothing for them to change.

The Back buttons page has the switch, the four bars' action bar dropdowns beside it and the 16 key
bindings (`Page:Binding`, rows across the page, no section titles: with them the page would be
taller than the window): the same commands as Key Bindings > AddOns, each row named by its bar and
its slot (the label is a function, asked again on each refresh, so it follows the bar's dropdown).
Each row has two buttons from the
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

## Back buttons on every bar

Each back button has a button on each controller bar, with keys of its own: Right's L4 is
`QoLBackButtonRight1`. The game picks a bar by the triggers' key-down state in its own Lua, which
secure code can't read, and owning the trigger keys to follow them hides them from the game (its own
trigger icons stop lighting). So the triggers stay the game's and the trigger is read where it's
held: Steam Input on the Steam Deck sends another key for a back button while a trigger is held (an
action layer or mode shift on the trigger), and that key is bound to that bar's button (ADR 0007).
The trigger toggle doesn't touch the back buttons beyond marking a held trigger as used when one is
pressed (`ns.Buttons.AddBackButton`).

- The bar in use, for the art only: `pageUnit:GetActiveBar()`, whose parent is one of the bars'
  anchors (a stance or possess bar over a bar counts as that bar). The game's
  `SetActiveActionBar` fires `ACTIVE_ACTION_BAR_UPDATED_EVENT` on the page unit's callback registry,
  which calls its callbacks through `securecallfunction`, so `RegisterCallback` there taints nothing.
  Our callback asks for a highlight the next frame (`ns.Later(..., true)`), in combat too. With the
  trigger toggle on, the game's active bar stays Top (it doesn't see the triggers), so the art does
  too while every key still presses its own bar's.
- Places: plain frames of ours parented to the game's six bars (`topBar` to `bottomBar`,
  `stanceBar`, `possessBar`) schedule an update from `OnShow` and `OnHide`, out of combat. A bar's
  holder shows when something the game shows sits on that bar's anchor (the bar, or a stance or
  possess bar put on it, read by `GetParent`). The possess bar on the special page (shown with
  `GamepadPossessBarOverride` on `SpecialPageTopBar`) isn't in a place, so the special page hides
  them all. A bar hidden as empty hides its back buttons, and a stance or vehicle bar in its place
  doesn't. A place that changes in combat waits for it to end. An empty slot does nothing: there's
  no fallback to Top.
- Keys: a button shows only while a key presses it (a key in `Overrides()`: its own bindings, or
  Top's paddle), and a cross's name only while one of its four does. Set with the holders, out of
  combat, so a key bound in combat shows its button once combat ends; `UPDATE_BINDINGS` brings it.
- Layout (points). Above Top sit the LB and RB prompts and the page tracker, and the bars interlock
  (each about 300 wide on anchors 195 apart), so the full layout puts all 16 on holders centred on
  the page unit (656 wide), past its sides, as a cross per back button: L4's centred at (-365, 30),
  L5's at (-365, -70), R4's at (365, 30), R5's at (365, -70), its name there. In a cross a bar sits
  where the game's cross of bars has it: Top at (0, 27), Left (-31, 0), Right (31, 0), Bottom
  (0, -27). There the buttons are 30 square, so their click areas don't overlap; the art is 38 for
  the bar in use and 30 for the others (the game's expanded and collapsed sizes). The art is a frame
  of ours inside the secure button, so it resizes in combat too.
- The compact layout: the game shows only its active bar, every anchor on Bottom's. The holders go
  on their bar's anchors and all show while anything shows, the buttons 38 square beside the one
  bar (L4 and L5 at x -182, R4 and R5 at 182, y 26 and -26), each name beside it. Only the bar in
  use's art shows (alpha, in combat too); the protected buttons can't show or hide in combat. Only
  the bar in use's buttons take the mouse, set out of combat, so a click in combat after the bar
  changed can reach another bar's button under it.
- The marker stays 512 by 160 on the bar's anchor; it doesn't reach the crosses.

To check in game (not answerable from the source or the stubs):

- Spacing: the crosses clear the bars, the LB and RB prompts and the screen edge, at the default
  scale and in Edit Mode, and a full-size button doesn't touch its neighbours.
- The highlight follows the triggers held, in combat too, and the game's own trigger icons still
  light.
- The compact layout: the back buttons beside the one bar follow the held bar, in combat too.
- Steam Input: a trigger layer's key for a back button presses that bar's, and the trigger still
  pages the game's bar.
- A stance bar in Top's place (a warrior's): Top's back buttons stay with their own actions.

## Following bars

Decided 2026-11-06; storage and the button change are in
[ADR 0003](../adr/0003-following-bars-in-spare-controller-slots.md). Terms are in `GLOSSARY.md`.
Built, in `Features/FollowingBars.lua`: all four bars following a stance, Top with its D-pad half
only, in and out of combat and across page flips, with the slots from the spare range and the stance
bars the class doesn't use, following a live switch of interfaces.

How it's built:

- A `SecureHandlerStateTemplate` frame of ours, made the first time a bar is ticked in the controller
  interface, holds everything the snippet needs as attributes: the ticks (`following-<bar>`), the
  bars' sizes (`size-<bar>`), the normal slots, the slots handed out (`slots-<stance>-<bar>`) and frame refs to both page units'
  buttons. Attribute names are lower case: the game lowers them. There are no restricted tables.
- A state driver on `[bonusbar:1]` to `[bonusbar:5]` runs the `apply` snippet on every stance change.
  A change of the ticks or of the game's setting runs the same snippet, through
  `ns.LaterOutsideWindows`.
- The snippet hands out slots, because a stance can first come up in combat, when insecure code
  can't change a secure frame's attributes. Our `HookScript` on `OnAttributeChanged` writes each
  one to the saved data: insecure code may read them, and a write to `QoLDB` taints nothing.
- A switch of interfaces (`ns.OnControllerUIChange`) goes through the same `update`. On the keyboard
  interface every `following-<bar>` is cleared and `apply` runs, so the buttons go back; from there
  `findslots` answers nil, so stance changes and flips touch nothing and no slot is handed out. The
  state driver and the wraps stay: they do nothing there, and taking them away would only add a
  second setup path. A character who logged in on the keyboard gets them on the switch, through the
  same creation as a first tick. Ticks changed on the keyboard are saved and apply on the switch.
- A switch waits like any other change: for the end of combat both ways (a stance change meanwhile
  still follows, on bars the game has hidden), and for the game's controller windows on the way to
  the controller interface. On the way to the keyboard there are no such windows to wait for:
  `ns.LaterOutsideWindows` only holds in the controller interface, so that `apply` runs a frame after
  the switch, with the settings window the player switched in possibly still open. The game's own
  gamepad init sets no page on the buttons, and if it ever did, the flip wrap and the `apply` a frame
  later cover it.
- A button that's where it belongs is never touched, so with no stance, nothing ticked or only the
  game's bar nothing happens to the game's buttons. A button that moved goes back to its normal slot,
  which is worked out once with the game's own
  `GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID`, for page 1.
- There's no record of the page: a button on neither its normal slot nor one of ours is on another
  page, and the snippet leaves it alone. That's checked per button because the editor's page unit
  flips apart from the bar. So a stance or tick change on page 2 or 3 changes nothing there, and page
  1 is put right by the flip back. "One of ours" is checked against the pools (`isours`), not as
  "265 and up": the bar the game's setting names sits on a stance bar the class uses, and `apply` must
  leave it there.
- A `SecureHandlerWrapScript` on each button's `OnAttributeChanged` (both page units) catches the
  flip back, as below. Wrapped from the same out-of-combat setup as the rest, so a character who never
  ticks a bar gets no wraps.
- The stance is the offset as the game gives it, and it only names a group of slots of ours. So no
  offset is assumed to be a certain form when handing out; only the list of free stance bars is
  per class.

What the player gets:

- The Controller page has a "Bars that follow the stance" section with a checkbox per bar, not a
  dropdown: dropdown menus have caused trouble in Forever's controller
  interface. The list is saved per character and one list holds for every stance.
- A stance is what the game treats as one: forms, warrior stances, stealth. Check with
  `GetBonusBarOffset()` or `[bonusbar:1/2/3/4/5]`; Easy Controller found plain `[bonusbar]` false in
  stealth on Forever.
- Each following bar has its own slots per stance. An empty slot stays empty, as on the game's stance
  bar; there's no fallback to the normal spell.
- Only page 1 follows. Flipping to page 2 or 3 in a stance shows those pages as usual.
- Only the Top bar's D-pad half follows: A, B, X and Y are reserved by the game. In `actionButtons`
  those are 5 to 8, which hold no slot (ID 0, `GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID`
  returns nil); a Top bar's buttons 1 to 4 are the only ones that get a frame ref or a wrap, so a
  face button is never touched. Its tooltip is its own, as it says this and has no greyed-out case.
- The game's `GamepadStanceBarOverride` is left alone. The bar it names keeps the game's stance slots
  and shows ticked and greyed out; QoL only adds bars. `Enum.GamepadStanceBarOverride` has no
  `Page1TopBar`, only pages 2 and 3 have a Top value, and only page 1 follows, so Top is never the
  game's bar: with the setting on `Page2TopBar` it can still be ticked and follows on page 1.
- Spells are placed with the game's own editor, in the stance.
- Unticking a bar or turning the feature off keeps its spells, so ticking it again brings them back.

Slots: 181-264 are the pages and 265-304 the five stance bars (bear, offset 3, is 281). 305-360 are
spare, plus the groups of stance bars the class doesn't use. A bar's Top half needs 4 slots, any other
bar 8. Each stance and bar gets its slots the first time they're needed and keeps them. When there's
no room the stances learned first keep their bars, the others stay normal, and the page says so.

Running out, as built:

- The pools fill in order, spare first, and each is its own run: a bar never spans two. A bar takes
  the first pool with room, so a Left that doesn't fit in the last 4 of one pool can go in the next,
  and a later Top can still use those 4. That's decided: first come, per bar, no all-or-nothing for a
  stance. A stance can end up with some of its bars following, which beats leaving slots unused.
- "Learned first" is really "came up first": the game doesn't say which offset a form has before
  it's used, so slots are handed out on first entering the stance. A form learned later gets its slots
  that way too, with no change to the settings.
- The free stance bars: warrior 4 and 5, druid 5 (`FREE_STANCE_GROUPS`). Only those two classes
  can run out: 56 spare slots are two stances of all four bars, so no other class is listed, and a
  class that's not listed can't lose a stance bar to a stance we didn't know of. The class's whole
  list counts, learned or not: a level 10 druid's Moonkin group stays out. `UnitClass` can be secret
  in a restricted state (a reload in a dungeon). The header then waits for it, every 5 seconds: built
  without the class, its pools would leave out the stance groups, and a bar saved in one would get
  other slots.
- `SpellShapeshiftForm.BonusActionBar` on Forever: cat 1, bear 3, warrior stances 1 to 3, stealth 1.
  Prowl isn't in there and isn't a stance of its own on Forever (seen in game 2026-11-07): a druid in
  Prowl keeps Cat's following bars. That's accepted, so group 2 goes unused; it stays out of
  `FREE_STANCE_GROUPS` as nothing needs it. Moonkin says 0, so 4 is from memory
  and stays reserved until it's measured: reserving it costs 8 slots, handing it out could cost a
  spell. What uses offset 5 at all isn't known. If a possess bar does, the game's stance bar would show
  a druid's or warrior's following slots while it's up, and `apply` would take the bar the game's
  setting names back to normal, as that slot counts as ours; check in game. The game's
  `GetFirstGamepadActionBarStorageSlotIndexForActiveStance` can't replace the list: it only knows the
  stance you're in, and a form not learned yet has to stay out too.
- A bar refused is marked in the header (`full-<stance>-<bar>`), and the hook keeps it in the saved
  data, so the line survives a reload. `IsOutOfSpace` only counts marks of bars that are ticked and not the
  game's, so unticking a bar that didn't fit hides the line. Slots are never given back, so a bar
  only gets slots after a mark if a later version frees a stance bar; handing them out clears it.
- The line is a `Page:Text` with `shown`: its row is kept empty while it's hidden, as the page's
  layout is fixed. A bar is refused inside a stance change, so the page registers
  `FollowingBars.onSpaceChanged` to refresh while it's open, on the next frame so that it's out of the
  secure snippet's stack. That's the one exception to features not calling the UI: no option
  changes, so `Options:Watch` has nothing to see.

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
button update is one of ours, which the wrap ignores. A button goes by its own slot alone: only one
that lands on its normal slot, in a stance, on a bar that follows, moves, so a flip to page 2 or 3,
or back with no stance left, passes through. The `flip` snippet in
`Features/FollowingBars.lua` is this list; `Stubs.FlipPage` runs the same order in the spec.

Tested in game on 2026-11-06, on the Left bar in bear with throwaway code: the slot changes on
entering and leaving the stance and the press casts the new spell, in and out of combat; the icon
follows; the editor writes to and clears the new slot; flips to pages 2 and 3 and back in combat
leave all 8 buttons right and block nothing. Not run in game: a spell on the normal slot with an
empty following slot, and any stance but bear. Cat is offset 1, slot 265.
Easy Controller gets no special handling; test with it on and fix what shows up.

## Trigger toggle

`Features/TriggerToggle.lua`. Terms are in `GLOSSARY.md`. Easy Controller has the same feature
(`Toggle.lua`, MIT), which is the model for the secure part.

The game shows and uses a trigger's bar only while the key bound to `GAMEPADLEFTMOD` or
`GAMEPADRIGHTMOD` is down (`GamepadMode.IsBindingDown`, read by `ActionBarModKeyDownStateCheck`), and
an addon can't keep a key down. So with the option on the triggers get override bindings to secure
buttons of ours, which keep the state on a secure header and bind the eight keys of the bar on to the
game's buttons of that bar. It works in combat. The game never sees the triggers then, so its active
bar stays Top, and it may not light a bar during a real hold either. Its highlight can't be used:
`SetActiveActionBar` writes to a Blizzard frame, and the next check resets it.

What the player gets:

- One press of a trigger alone switches its bar on, another switches it off. A trigger held with a
  button works as before. The triggers are two switches: LT and RT on is Bottom, also when pressed
  together, and from Bottom LT leaves Right.
- Held and let go with nothing pressed counts as a press. No clock turned up in the source for secure
  snippets, so "short press only" looks out. The same goes for a press of a key that isn't ours (LB, a stick);
  our back buttons can report that they were used.
- A second checkbox, on by default, goes back to Top when combat ends. A bar on takes A and with it
  jumping and interacting, which is why that's the default.
- Only the eight bar keys switch. LB, RB, the sticks, rings and the back buttons (keys of their own
  per bar, "Back buttons on every bar") stay as they are.
- A possess or vehicle bar switches the bar on off, in combat too, and it stays off.
- Page and stance: the bar on follows the page, and where the game's stance bar has taken a bar the
  press goes to the stance bar's button. Following bars need nothing, as the press is on the game's
  button, which already has the slot.
- The bar on stays on while a game window has the controller and comes back after it, with the marker
  hidden. A switch to the keyboard interface turns it off and clears it.
- The marker is the game's trigger glow (`gamepad-actionbar-fx-trigger-behind`, added on) on a frame
  of ours, shown behind the bar on and during a hold. The bar's own focus art
  (`gamepad-actionbar-focus-bg-section`) was tried first: it's pure black, so it can't be tinted and
  barely shows. The icons aren't redrawn.
- The compact layout isn't covered: the game shows only Top there, so the bar on would need its
  icons drawn over it. The tooltip says so.
- No handling of Easy Controller's toggle: nobody runs both.

Why it's taint-safe: nothing of the game's is written or hooked. The state and the bindings are on
frames of ours, in secure snippets, which is why it works in combat. The game's buttons are only read
and clicked, through frame refs made out of combat, from a secure macro, the way a key bound to them
presses them. The marker is a frame of ours parented to `PageUnit`. Our trigger overrides are set and
taken away through `ns.LaterOutsideWindows`; in combat only the secure header changes bindings.

How it's built:

- The header `QoLTriggerToggle` holds the state in attributes (`on-LT`, `held-LT`, `used-LT`, the
  same for RT, `both`, `bar`); `QoLTriggerToggleLT` and `RT` are the buttons the triggers' overrides click. The header's
  own bindings are the eight keys, in all the modifier forms the game can send, and `ClearBindings`
  drops them when no bar is on.
- The keys are fixed (`BAR_KEYS`, in the order of `GAMEPADACTIONBUTTON1-8`), not read from the
  bindings, so a player who rebound the bar's keys gets the default keys while a bar is on.
- Each key goes to a relay (`QoLTriggerToggleRelay1-8`), which picks the game's button on the press
  and runs a macro `/click <button> LeftButton true`. A `type=click` wouldn't do: `SECURE_ACTIONS.click`
  clicks without "down", and the game's buttons act on key down. A macro in the slot doesn't run from
  a macro, so a slot holding one (`GetActionInfo`) gets `type=action` instead. The relays only take
  the press, as Easy Controller's do, so press-and-hold spells don't get a release.
- Targeting and the shortcuts bar: no need to see LB or RB in secure code, since the game shows those
  bars at once on the press (`ActivateOverrideBar`), and only over Top. A relay on Top reads their
  `IsVisible`. While a trigger is really held the bar wins, as in the game.
- The stance bar is decided at the press too: `IsVisible` of the game's stance bar (visible only when
  it's active and on the page that overrides) and the bar of the game's Stance bar setting, on
  whichever page it names, which `ns.GamepadStanceBar(page)` reads and the header gets as `stancebar`.
  The possess bar has a setting of its own and is handled the same way, for a hold under it.
- `SecureHandlerWrapScript` on each back button marks the press as used. The back buttons are made
  at their own moment, so `ns.Buttons.WatchBackButtons` hands them over, now and as they're made, and
  neither feature names the other.
- A possess, vehicle or override bar is a state driver on the header. It runs `ALL_OFF`, which also
  clears the keys, in combat too, and sets `possess`, which makes a trigger going down count as used,
  so that no press under that bar switches anything on. A hold works as before.
- A window that takes the controller can eat a trigger's press or release, and a hold would then
  never end. So every `update`, which runs once the windows have closed, clears the held state
  (`LET_GO`), and `TRIGGER` ignores the release of a press it never saw. The game fires
  `Gamepad.RefreshFrameFocus` as a window takes or gives back the controller, which hides or brings
  back the marker a frame later and schedules that `update`.
- A trigger that a window doesn't bind still toggles behind it: the window's priority overrides only
  win for the keys they set.

To check in game (not answerable from the source or the stubs):

- With a bar on and LB or RB held, the targeting bars get the keys.
- A plain override beats the game's bar bindings. A window's priority overrides have to win over
  ours, also in combat when ours can't be removed, which rules out priority if a plain one works.
- Whether a real hold still lights the game's bar.
