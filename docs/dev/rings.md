# Rings

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

The rings (`Features/Ring.lua`) pick an action in combat, so the choice is made by secure code.
They are the player's own, as many as they make, saved for the account in `QoLDB.rings`:
`{ entries = { { kind = "spell", id = 133 }, ... }, mouse = "F", stick = "PADLSHOULDER" }`.
`Features/RingEntries.lua` knows the kinds (spell, item, toy, mount, macro by name): whether this
character has one, its secure action, icon, name, tooltip, how it looks on a slot, how to put it on
the cursor and how to read it off the cursor. A character's ring is the entries it has, the first
12 (`Ring.MAX`), so it has no empty slots and other characters' entries stay saved.

- One secure header (`SecureHandlerBaseTemplate`, `QoLRing`, hidden, DIALOG strata) and one
  `SecureActionButtonTemplate` button of ours, `QoLRingButton` (child of UIParent, no size), with
  `useOnKeyDown` false, so the action happens when the key is let go. Its OnClick is wrapped by the
  header (`SecureHandlerWrapScript(opener, "OnClick", header, Ring.CLICK)`). For each ring `r` with
  `n` entries this character has, the header has `qol-count-r` = `n`, and the button
  `*type-rsN` and `*spell-rsN` (or `item`, `toy`, `macro`) for slots 1 to `n`: `"spell", id`
  (`CastSpellByID`), `"item", "item:id"` (`SecureCmdItemParse`; it equips what's worn), `"toy", id`
  (`UseToy`), a mount as its spell, `"macro", name` (`RunMacro`). Attributes set before and no longer
  wanted are cleared, so a ring that shrank leaves nothing behind.
- Each key of a ring is an override binding (`ns.Buttons.NewOverrides`) that clicks the button with
  a made-up mouse button naming the ring and the aim: `SetOverrideBindingClick(owner, false, key,
  "QoLRingButton", "2mouse")`. A ring with nothing this character has gets no bindings, so its keys
  keep doing what Key Bindings gives them. The keys aren't game bindings (Bindings.xml doesn't list
  them): the ring decides which keys, and a key belongs to one ring at a time.
- The snippet reads the ring and the aim with `strmatch(button, "^(%d+)(%a+)$")` and does nothing
  without that ring's `qol-count-r`. On the key going down: anchor the header at the cursor
  (`"$cursor"`, a fixed point on the screen) or the middle of UIParent, note the button in its
  `qol-open` attribute, show it, return false (no action). On the key going up (only for the ring
  that's open): hide it, read the aim and return the aimed slot's button, `"2s3"`;
  `SecureButton_GetButtonSuffix` makes that the `-2s3` suffix of the attributes above. Aim with the
  mouse: `owner:GetMousePosition()`, which is 0 to 1 across the header and nil outside it, hence the
  header's 8192 units; less than 20 units from the middle is none. Aim with the stick:
  `GetGamePadState().sticks[i]` (the restricted environment's `C_GamePad.GetDeviceMappedState`), `i`
  the stick `C_GamePad.StickIndexToConfigName` calls "Camera" (counted from 0 there, from 1 in
  `sticks`, found out of combat into the header's `qol-stick`); `len` under 0.5 is none. The slot is
  `floor((deg(atan2(x, y)) % 360 + step / 2) / step) % n + 1` with `step = 360 / n` (the global
  `atan2` works in degrees, so `math.atan2`): slot 1 at the top, the others clockwise, evenly. The
  header's `qol-on` attribute is false while the rings are turned off.
- Our code only draws. The art is a plain frame under the header, so it shows and hides with it
  without being protected. Every slot and spoke (12 of each) is made with it, so opening a ring in
  combat makes no frames. Its OnShow lays it out for the open ring (`Ring.Layout`: slots `96` units
  out at `(i - 1) * 360 / n` degrees, spokes between them, the frame scaled by `max(1, n / 10)` so
  the slot rims don't overlap past ten) from the entries the last update gave the secure code, and
  shows each entry's icon, count, usability and cooldown (`RingEntries.Refresh`). Its OnUpdate
  works out the aimed slot with the same sums (`Ring.SlotAt`, cursor from `GetCursorPosition()` over
  the effective scale against `GetCenter()`), lights its wedge and puts the entry's name in the
  middle. If another ring's key goes down while one is open, `qol-open` changes and the art lays
  itself out again.
- Values that may be secret in 12.x (a spell's usability, charges and cooldown, an item's count)
  are tested only through `ns.IsUsable`; cooldowns go to the widget as the game gives them
  (`C_Spell.GetSpellCooldownDuration` into `SetCooldownFromDurationObject`, `C_Item.GetItemCooldown`
  into `SetCooldown`), counts to `SetText`.
- While the stick ring is open, a plain frame of ours has `EnableGamePadStick(true)` and an
  `OnGamePadStick` that returns true for the "Left" and "Movement" stick (passed on to the game, so
  the player can walk) and nothing for the others (kept from the camera), as `Blizzard_RadialWheel`
  does. It keeps the stick after the ring closes until the stick is at rest (`len` under 0.1) or for
  half a second, like `InputAxisBinding`'s `waitForCentering`, so letting go of the key with the
  stick out doesn't swing the camera.
- The rings' editor (`Features/RingEditor.lua`) is the settings window's Ring page; `/qol ring`
  opens the window there (`SettingsPanel:Toggle("ring")`: from another page it goes there instead of
  closing). Until 2026-10 it was a window of its own, opened by a button on that page, which only
  held the switch besides: the editor is now the page. Its title bar (`SettingsPage.TOP`, 54) keeps
  the page's title, with the switch where the other pages have their Defaults button (a `"title"`
  row; no Defaults button, which would only turn the rings off). Below it, filling the rest of the
  page (665×547), lies `QoLRingEditor`: one spell book page, `spellbook-page-condensed-c60`
  stretched over it; its dark top bar is its upper 8.1% and the parchment lies inside rims of 9.4%
  (top), 2.6% (bottom), 3% (left) and 2.6% (right), measured from the texture of client 1.60.1.
  Without that atlas (retail) it's retail's spell book page as its halved spell book draws it
  (`Blizzard_SpellBookFrame.xml`): `spellbook-background-evergreen-header` as the bar, cut to the
  page's width from the middle of the book's 1614 (its left end has the portrait's round cut), over
  `spellbook-background-evergreen-right` from Forever's parchment edge, where the tabs stand, with
  the page curl (`spellbook-corner-flipbook-evergreen`, the first of its 4 × 2 frames, still) in the
  bottom right corner, all scaled from a page of 807 × 805. The bar reaches 3 below the paper's top,
  as the game's 54 over its page from 51, where its tabs stand too; so it comes out near the game's
  own height. Don't squash it to Forever's bar: the paper would then start above the tabs. The
  parchment's edges stay Forever's, so the editors lie the same on both; retail's paper reaches
  past them. Without either, Classic Era's own spell book panel, found by its files
  (`GetFileIDFromPath("Interface\\Spellbook\\UI-SpellbookPanel-TopLeft")` and `-BotLeft`), not by
  the flavor: the dark stone strip under its title, right of the portrait's circle, stretched to the
  page's width down to Forever's parchment edge, where the tabs stand, and under it the parchment
  inside the panel's metal frame, the top-left piece's on the bottom-left piece's, which ends in the
  ragged edge at the page's bottom. No frame, no portrait: the page sits in our bronze window. The
  crops are pixels of the 256 × 256 left pieces of build 1.15.9.70576 (`CLASSIC` in
  `RingPicker.lua`); after a client update, check them against the files (wow-data `file 136839`,
  `136836 -f classic --png`). It's the panel and not `Spellbook-Page-1/2`, the Cata page Classic
  Era also ships: Classic Era's spell book doesn't use that one, and the editor stands on its
  client's own spell book. Without any of the three, a dark bar over plain parchment colors. Text
  on the paper is ink: `SPELLBOOK_FONT_COLOR` (or Forever 1.60.1's value) without the font's shadow
  (`RingPicker.Ink`). The page wraps `Page:Refresh` to refresh the editor too, so it's up to date
  whenever the window shows the page and when the switch changes.
- The room is the game's canvas (665 wide) where the window was 860, so the left column is 256
  wide and the list 350 (2×9 rows of 175, which cuts long names shorter; the tooltip has them). The
  ring is drawn at 0.66 (`SetScale` on its frame, anchored only to the middle of a room at the
  page's scale, as offsets from a scaled frame shrink too), in the room the biggest one takes. The
  list's five tabs (at least 92 units each, as wide as their side art) reach 464 into the top bar
  from the list's right edge, past its left one, over the left column: so "Ring 1 of 3" and its
  arrows stand on the parchment above the ring instead of in the bar. The keys' names are left of
  their boxes, on two lines when they need them.
- The editor's left column holds the ring (the same art, with Buttons for slots, plus one empty
  slot to add to), with "Ring 1 of 3" and the spell book's page buttons (`UI-SpellbookIcon-*Page-*`)
  above it. It shows the ring as this character sees it and maps a slot to its place in the saved
  list, so an entry dropped on slot 3 goes before the entry shown there, with other characters'
  entries kept where they are. Dropping reads `GetCursorInfo()` (a spell that's a mount's,
  `C_MountJournal.GetMountFromSpell`, is the mount; an item that's a toy, `PlayerHasToy`, the toy);
  an entry already on the ring moves. Taking one off puts it on the cursor (`C_Spell.PickupSpell`,
  `C_Item.PickupItem`, `C_ToyBox.PickupToyBoxItem`, `PickupMacro`; a mount by its spell). It only
  changes our saved table and asks for an update; out of combat only. The settings open in combat,
  so the page does too: it shows the rings, its buttons and key boxes are off (`SetEnabled`), a
  click, drop or drag changes nothing, and the note says why. `PLAYER_REGEN_DISABLED` comes while
  `InCombatLockdown` is still false, so that handler locks the page itself; `PLAYER_REGEN_ENABLED`
  refreshes it, with what changed meanwhile.
- Escape and the other keys are the settings window's (`ns.NewWindow`, in [`settings-window.md`](settings-window.md)): Escape closes it,
  every other key goes on to the game, so P opens the spell book with the window open (it isn't in
  `UISpecialFrames`, which the spell book would close). The key boxes' listener sits above the
  window and keeps every key, so there Escape only cancels. Leaving the page or closing the window
  (the editor's `OnHide`) stops waiting for a key and takes the focus from the search box.
- The editor's right column is `Features/RingPicker.lua`, built after Forever's spell book: tabs from
  the game's `TabSystemTopButtonTemplate` standing on the parchment's top edge (the tab system they
  call, their parent, is a strip of ours with `SetTab`, `GetTabWidthConstraints` and
  `PlayTabSelectSound`; five tabs are 92 units each at least, so they end at the list's right edge
  instead of starting at its left one), a `SearchBoxTemplate` (case-insensitive substring of the
  name), and 2×9 rows filled down the first column, then the second, a page at a time, with the
  spell book's page buttons and the mouse wheel. Paging instead of a scroll box: the controller's
  cursor gets to every row and the page buttons, and it's how the spell book does it. A row is the
  spell book's entry: icon (`spellbook-item-spellicon-mask`) in `spellbook-item-iconframe-c60`,
  `spellbook-item-iconframe-hover` and `spellbook-item-backplate` as highlight, name and subtext in
  ink, and a check mark when the entry is on the ring shown. A click puts it at the end of the ring
  (refused past 12 shown) or takes it off; a drag picks it up (`RingEntries.Pickup`). The list is
  read again when the page is shown and on the rings' known events while it is.
- What a character has (`RingEntries.Owned`): the spell book's skill lines that aren't hidden
  (`C_SpellBook.GetSpellBookSkillLineInfo`), their spells without passives and other
  specializations' (a mount's spell as the mount), a flyout's known spells in its place
  (`GetFlyoutInfo`, `GetFlyoutSlotInfo`); items with a use (`C_Item.GetItemSpell`) in the bags and
  the equipment slots 1 to 19, toys left out; toys through the Toy Box's own filter
  (`C_ToyBox.GetNumFilteredToys`, `GetToyFromIndex`), which is the only list of them, so its
  filters and search apply (changing them would change the Toy Box); collected mounts
  (`C_MountJournal.GetMountIDs`); the account's macros, then the character's (`GetNumMacros`, from
  `MAX_ACCOUNT_MACROS + 1`). Spells and macros in the game's order, the rest by name.
- The editor's key boxes are the game's `KeyBindingFrameBindingButtonTemplate`, with a listener of
  our own like the settings pages' ([`settings-window.md`](settings-window.md)), which also takes gamepad buttons
  (`EnableGamePadButton`, `OnGamePadButtonDown`): the first key or button pressed is the key, Escape
  cancels. Setting it only changes the saved ring (taking the key from the ring that had it); no
  `SetBinding`, so nothing for `SaveBindings`.
- The header, the button, their attributes and the override bindings are made and changed through
  `ns.LaterOutsideWindows`, out of combat and away from the game's controller windows, on the
  option, on the editor's changes and on what changes what a character has (`SPELLS_CHANGED`,
  `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`, `UPDATE_MACROS`, the toy and mount events). In
  combat a ring keeps what it had. The settings window is no such window (the controller manager
  doesn't know it), so the rings change while the page is open.

The rings' textures come from Forever's own art (build 1.60.1.70291). `Media/Ring.tga` (512×512,
drawn 343 units wide) is a dark disc, the radial menu's wheel (`gamepad-radial-menu-wheelbg`, file
6227249) and the minimap's bronze ring (`ui-hud-minimap-frame-circle-c60-2x`, file 8026708) scaled
over the wheel's rim, which ends 150 units out, with the wheel's eight spokes painted over by its
own radial profile (the median of the sectors between them). `Media/RingSpoke.tga` (256×256, drawn
100 units wide, its middle 93.5 units out) is one of those spokes turned to point up; a ring of `n`
draws `n` of them between its slots, turned with `SetRotation(-angle)` (counterclockwise in
radians). `Media/RingLit1.tga` to `RingLit12.tga` (256×256) are the radial menu's lit wedge
(`gamepad-radial-menu-selected`, drawn for eight slots) remapped around the ring's middle for `n`
slots: each side's bronze border kept at its width and the fill between stretched or squeezed to
the slot's sector, `RingLit1` the whole wheel. `Ring.lua`'s `LIT` table has each one's size and how
far out its middle sits. `Media/RingSlot.tga` (128×128, 58 units around a 40-unit icon) is the
minimap's day and night rim (`ui-hud-minimap-frame-cycle-c60-2x`). They were cropped, scaled,
remapped and laid over each other with small Pillow and numpy scripts, not kept in the repository.
