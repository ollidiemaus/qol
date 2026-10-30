# Trying it in game

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

Link or copy the repository into the client's AddOns folder as `QoL` (on the Forever beta:
`_classic_beta_/Interface/AddOns/QoL`). The client only loads what the TOC lists, so `docs/`
and `tests/` do no harm there. An unpackaged copy reports its version as `@project-version@`; only
the packager fills it in.

Things only the real client can confirm:

- The viewport margins line up with the world at your resolution and UI scale, and stay with Alt+Z.
- With Forever's controller interface on (Options > Controller), the viewport and the Action Bars
  options on: open the settings with `/qol` and from the information page's button (it opens once
  the game's options and menu are closed, and says so), and check that the controller cursor reaches
  the list and the pages. Look at every page (Viewport included: step a margin with its
  arrows, open the color picker; on the Controller page turn on the back buttons, press the bar
  dropdown a few times, with A and with the touch screen, and bind a back button's key: A on a key
  box, then the back button), go to another page, and close the window with its X. The dropdowns step through their choices without opening a list.
  The game must not freeze, also when opening and closing the game's options and menu afterwards, and the viewport stays. The back buttons take the new bar within a second. A back button's key still works after a `/reload` (saved right away). The game's own controller action
  bars show; the flips and borders come back after switching to keyboard and mouse.
- Cutscenes with the viewport on (margins on all four sides), see below.
- Flipped bars stay flipped after Edit Mode changes, a `/reload`, shapeshifting (stance bar) and
  summoning a pet, and no "tainted by" error shows up in combat afterwards.
- Hiding the system bar leaves the main action bar where it was (on Forever it is anchored to the
  micro menu), and the micro menu still shows on the vehicle bar.
- Hide portrait hit text: no numbers or Dodge/Parry over the player's and the pet's portrait in
  combat, also in a vehicle; unticked, they come back at once, and no "tainted by" error shows up.
- Junk selling and repairs (including guild repairs) at a merchant. Right after login a grey item
  the client hasn't loaded yet makes junk selling wait for `GET_ITEM_INFO_RECEIVED` (at most a
  second, `Merchant:SellJunk`); it then sells everything at once with the right count and value.
- The vendor price of a stack in your bags shows the price of one, and `Vendor x<count>` with the
  stack total while Shift is held (pressing Shift while pointing flips it within a moment), with
  and without a merchant open, and only once (the game's own sell price line is replaced, not
  doubled).
- On Classic Era: the same vendor price checks, in bags, at a merchant (the game's `Sell Price` line
  becomes the `Vendor` line, fitted to the tooltip, not doubled), on a chat link, and none on the
  comparison tooltips; item, spell and NPC IDs show, and whether a buff's or debuff's tooltip gets
  its spell ID (only if Classic Era runs `OnTooltipSetSpell` for auras).
- On Classic Era's minimap: the square shape hides the round border (and the compass ring with
  rotate minimap on); the tracking button (track herbs or minerals) and the time of day icon in
  every row and inside spot, and whether Forever's distances from the round frame fit its border.
- Class-colored health bars: the shading matches the default bar, an NPC target (and a rare or
  "minus" one) shows the default green, switching targets in combat recolors at once, and turning
  an option off brings the green back without a `/reload`. Also on the target of target, focus and
  focus target.
- Mana in bear and cat form (a druid): the mana bar follows casting and regeneration while
  shapeshifted (whether the server sends mana updates in a form), shifting in and out in combat
  shows and hides it, the threat glow fits the frame in combat with and without the bar, a change
  of the Status Text setting shows on the bar at once, and a vehicle shows its own art. Something
  in the bottom container (a pet frame) isn't covered by it.
- Frames past the screen edge, with Snap to Elements off: an action bar, the minimap and a unit frame
  dragged to each edge go up to 30 past it, also right after changing a setting of theirs in Edit
  Mode. After saving, a `/reload` and switching layouts (by hand and with AutoSetup on a resolution
  change), they come back to the same place, not pulled in by the screen. Turned off, they are back
  inside the screen; no "tainted by" error in combat afterwards (the action bars are protected).
- Quests: accepting from a gossip NPC and from a quest greeting NPC (several quests in a row), a
  shared quest, turning in with one reward and with none, a choice of rewards and a quest that costs
  gold staying open, and Shift leaving everything to the player. On Classic Era, a quest greeting
  NPC with several quests to accept and to turn in, and a repeatable turn-in done twice in a row.
- On Classic Era: Hide the social button hides the Friends button by the chat, and portrait hit text
  shows no numbers over the player's and the pet's portrait.
- Faster auto loot: with Auto Loot on, a corpse, an herb, a catch and a container empty at once; the
  auto loot key held keeps the window open; with Auto Loot off, holding the key takes it all at once.
  Full bags leave the rest in the window, a bind-on-pickup item in a group asks first, and a group
  roll still comes up. On Forever with a controller: tapping and holding the interact button. With
  Open loot window at mouse on, a window with something left in it still opens at the mouse.
- Hiding the combat log: the tabs after it close the gap, also after a whisper tab opens and with
  the combat log selected when the option is turned on (the chat stays empty until another tab is
  clicked). No "tainted by" error in combat afterwards.
- Names in class color in say, guild, party and channels; turning the option off brings back the
  per-channel setting.
- The other chat buttons stay hidden after joining a voice channel and with text to speech on.
- Square minimap: both borders (the bronze one lines up with the map's edge at every Edit Mode size),
  minimap buttons of other addons along the square, the rotate minimap setting, and a
  zone with the hybrid minimap.
- Zone text and the clock, addon compartment, tracking button and day and night icon in every
  position, several in one spot, above and below a round and a square minimap, with and without
  coordinates, after an Edit Mode change of the minimap's size, and after a `/reload`; the tracking
  menu and the addon compartment's menu still open from their new places. The zone text's frame
  gone when it moves and with the option at its default spot, also on mouse-over; its click and
  tooltip still working. Class color after zone
  changes and in combat, and on the clock and the coordinates.
- The tracking button and the day and night icon inside the map: drawn above it, clear of the round
  frame and the bronze border in every corner, clickable there, and the mail icon (anchored to the
  tracking button by the game) still readable.
- Bar paging off: Shift+1 to Shift+6 press the action buttons (a `[mod:shift]` macro sees Shift),
  also with a bar addon that binds the number keys itself; turning it off pages again, and changing
  a key binding in combat is picked up after combat.
- The settings window: Forever's bronze frame and the bronze options art (inner frame, the list's
  header and hover highlight; the selected page's highlight is the plain one), lined up as in the
  game's options, also at other UI scales; the portrait icon; dragging the title bar; `/qol` opening
  and closing it, Escape and the X closing it; opened from the information page's button over the
  game's options, Escape closing those first. In combat it opens, every key (Escape too) goes to
  the game, the X closes it. The pages: two columns in English and German (no name cut off),
  checkboxes and dropdowns working, dependent options greyed out, and the Defaults button asking
  first. The Ring page: the switch in the title bar lined up with the title, the parchment below
  the divider, nothing past the page's edges (English and German).
- The zeppelin and tram pins' icons next to the boats', on zone and continent maps.
- Hidden button borders on every bar (also the stance and pet bars): square icons, the mouseover,
  pressed and checked (auto attack, an active stance) textures, the red auto attack flash, the
  green glow of an equipped item, the cooldown swipe over the whole icon, no casting animation;
  after changing "Hide Bar Art" of the main bar in Edit Mode, and back to the normal buttons
  without a `/reload` when turned off. No "tainted by" error in combat afterwards.
- The zone text and the clock at every font size, in the header bar and above and below the
  minimap (rows with something else in them), back to the game's look when set to Default.
- FPS and ping in every row position, next to the clock in the same spot, at the minimap's edge
  with one- and three-digit numbers, updating every second, in class color, at every font size (the
  row making room, nothing cut off), and gone when hidden.
- World map pins: in the right places on the zone and continent maps (the entrance positions are
  the instance portals, like retail's encounter journal pins), the tooltips' names in German, and a
  click opening the destination's map. Open the map in combat too. On Classic Era: the Stockade
  (~39.7, 54.0) and the Deeprun Tram (~64.5, 7.6) in Stormwind, Stratholme (~30.8, 15.7) and
  Naxxramas (~31.4, 25.9) in the Eastern Plaguelands, the Menethil Harbor–Auberdine boat at both
  docks, and the ship icon's size next to the others.
- Controller back buttons (Options > Controller), on a Steam Deck with F13 to F16 (or other free
  keys) given to L4, L5, R4 and R5 in Steam Input, bound under Key Bindings > AddOns > Quality of
  Life:
  - The keys press the buttons in the controller interface, alone and with LT, RT or both held, and
    the button looks pressed while held. If they don't, the saved bindings or the overrides don't
    reach the controller interface; that's the first thing to find out. Does the client see F13
    and up from Steam Input at all (try binding them to something else)?
  - A controller with paddles the game sees (Xbox Elite, DualSense Edge) without anything bound:
    which paddle presses which button (the PADPADDLE numbering is SDL's, not checked in game).
  - The buttons sit clear of the d-pad and face buttons in the normal and the compact layout, at
    several Edit Mode sizes, and the labels don't overlap anything; they hide with the bar (keyboard
    and mouse, vehicles, cutscenes).
  - Switching to keyboard and mouse without a reload: the keys press nothing (try F13 to F16 on
    the keyboard's bars); switching back, they press the buttons again.
  - Icons, counts, cooldowns (also in combat: the cooldown call on our Cooldown), out-of-mana and
    unusable colors, the auto attack rim; dragging a spell on and off, with the action bars locked
    (Shift) and unlocked; the tooltip.
  - The keys still work after opening and closing a gamepad window (bags, map, the settings), and
    no "tainted by" error shows up in combat afterwards.
- The rings (the Ring page on, rings made with `/qol ring`):
  - The Ring page: the parchment page and its top bar line up below the title (also at other UI
    scales); the tabs in the bar clear of "Ring 1 of 3" and its arrows; the smaller ring with 12
    actions inside its column; the keys' names on two lines where needed (German too). The list: each
    tab, the search box, the page buttons and the mouse wheel, clicking an entry on and off the
    ring, its check mark, dragging one onto a slot, a full ring refused, the tooltips; with the
    controller cursor, the tabs, rows and page buttons. A spell learned while it's open shows up.
  - The editor: dragging spells (from the spell book and from action bars), items from the bags,
    toys from the toy box, mounts from the mount journal and macros onto the empty slot, onto a
    slot and off the ring; picking up and putting down with clicks, also with the controller cursor;
    right-click; the tooltips; a 13th action refused; new, switching, deleting; in combat the
    buttons off and nothing changing, back once it ends. P opens the spell book with the page open,
    and both stay open; moving with the keys while it's open. Entries for another class show on that
    class only, and the page counts them.
  - Keys in the editor: a key, a key with a modifier, a controller button (in the controller
    interface too), Escape, right-click, a key taken from another ring. While the rings are on the
    key opens its ring instead of its Key Bindings action; with them off (or the ring empty for this
    character) it does that action again.
  - Mouse key: the ring opens at the cursor, the wedge and name follow the mouse, letting go uses
    that action (also in combat: a spell, an item, an equippable item, a toy, a mount, a macro),
    and letting go in the middle does nothing. Near a screen edge, and at several UI scales. Rings
    of 1, 2, 3, 8 and 12 actions: the slots and spokes go round evenly, the wedge sits on the aimed
    slot in every direction, 11 and 12 are drawn bigger.
  - Controller key, in the controller interface and with keyboard and mouse: the ring opens in the
    middle, the right stick aims, the camera stays still while aiming and doesn't swing when the key
    is let go with the stick out, and the left stick still moves the character. If the camera stick
    isn't the second in `GetGamePadState().sticks`, the aim is wrong or none: check `qol-stick`.
  - Learning a spell, using up the last of an item, equipping one: the ring grows and shrinks
    after the event (after combat when it happens in combat).
  - The art: wheel, bronze rim, spokes and slot rims line up, cooldowns and counts show, long names
    wrap in the middle.
  - No "tainted by" error in combat after using a ring or the editor.
- Click casting (on, on Forever and retail):
  - The page: the parchment and the list line up as on the Ring page; a long name and a German
    combination fit their row; the page buttons, the wheel and the controller cursor reach every row.
    Adding with a click, a key, the wheel, Button 4 and 5 and every modifier; Escape; a box's new
    combination; right-click; dragging from the spell book, the bags and the macro window. Quick bind
    with each of those over a row, keys going on to the game away from the list, Escape not closing
    the window. Click casting off: the page greyed out (the note isn't) and nothing changes; on
    again, it is as before. Alt-Left and Ctrl-Right bound to Target and Menu, and Left to a spell.
  - Clicks on the player, target, target of target, focus, pet, party (and party pet), raid-style
    party and raid, boss and arena frames: a spell, an item (a bandage), a macro with
    `[@mouseover]`, Target and Menu on other combinations, a plain click with nothing bound. Retail
    12.x still lets an addon set the raid-style frames' click attributes out of combat.
  - A key over a frame, its portrait and its health and mana bars (moving between them, in combat
    too), acts on press, does its Key Bindings action away from frames, and a ring's
    key opens the ring away from frames (the priority override wins over the ring's). A frame
    hiding under the mouse (a party member leaving) drops the keys (the `OnHide` wrap).
  - The arena frames get the bindings when the arena UI loads; frames that appear in combat get
    them after it.
  - The game's own Click Casting: a spell on Shift-Left there wins and the page marks it; its
    modifier bits decode right, in German too. Turning QoL's off gives every frame the game's
    clicks back. A unit frame addon that joins through `ClickCastHeader` or `ClickCastFrames`, and
    Grid2's party and raid frames (clicks and keys, a raid joined in combat getting them after it).
  - No "tainted by" error in combat afterwards.
- Hide new buff tooltips (Options > Controller), in the controller interface: gaining or refreshing a
  buff (a food buff, a flask, a party member's buff) and a debuff shows no tooltip; selecting a buff
  through the buff frame (the radial's Buffs) and pointing at one with the mouse still do. After the
  game menu closes, the cursor goes to the middle and hides (these three confirmed 2026-10-11, Steam
  Deck). Turning it off brings the pop-ups back without a reload. Right-clicking a buff away in
  combat still works.

## The hidden settings probe

`/qol probe` (`Features/HiddenSettingsProbe.lua`) measures what the Advanced settings page needs to
know about the client it runs in, so Forever's client and every patch can be measured with one
command instead of `/run` lines pasted into chat. It's in the release package but not in
`/qol help` or the README.

- **What it measures.** Every hidden setting in the table and the candidates for the page
  (`CANDIDATES`, now only `lodObjectMinSize`; one comes off that list once it's in the table): its
  value, game default, the lowest and highest value the game takes, whether it keeps halves (the
  value plus or minus 0.5) and whether it's protected in combat.
  A range is searched from the value outward in steps that double until the game refuses one, then
  by halving the gap on whole numbers, so a range that ends between two (the camera distance's 2.6)
  shows the last whole number in it. A side that still takes 10,000,000 is "no range check". Then
  each game slider (`graphicsViewDistance`, `graphicsEnvironmentDetail`, `graphicsGroundClutter`:
  CVars from 0 to 9, reported from 1 to 10 as the game's options show them): its step and game
  default, and for each step the value of every setting that changes with it. Last, the same-value
  test: with the settings behind a slider set to what another step sets, it writes the slider's step
  again and says whether they came back, so whether a Reset can put back what that slider sets. A
  setting the game wouldn't set to another value is named as not tested.
- **Putting things back.** Before it writes anything it saves every value it may touch. Each setting
  gets its value back right after its range search. At the end the sliders are written back first,
  then every setting, as writing a slider sets the settings behind it again: so a value set with
  `/console` that differs from what its slider sets comes back too. Then it reads everything again
  and names a value that didn't come back. An error halfway still puts everything back, then shows
  as a `failed` line and goes to the game's error handler. It saves only what it measures: a CVar a
  slider sets that isn't on the lists gets back what the slider sets, not a value set with
  `/console`.
- **Safe to run.** It all happens at once, so the game never draws a frame with a changed value (at
  most the screen stutters once). It refuses in combat and writes nothing then. It never writes the
  raid copies, the Raid and Battleground graphics (`raidGraphics…`), Graphics Quality or any other
  graphics option, so the game reloads nothing, and it touches no frame.
- **The report.** `key = value` lines, as in Wayscribe's `/ws probe`: `client` (version, build,
  locale) and `date`, then `cvar.<setting>`, `slider.<slider>`, `slider.<slider>.<setting>` (its
  values from step 1 to 10), `rewrite.<slider>` and `restore` (or `restore.<setting>` for one that
  didn't come back). It's printed to chat and kept in `QoLDB.probe` (`client`, `date`, `lines`),
  replaced each run; after a `/reload` or logout it's in
  `WTF/Account/<account>/SavedVariables/QoL.lua`. Nothing reads it back: it's diagnostics, and the
  CVar stays the only truth for the page. Classic Era's row overrides (`classicEra` in
  `Features/HiddenSettings.lua`) are copied from its run on 1.15.9 build 70576 (2026-10-30); after a
  patch, run it again and compare. The report lines aren't translated; its two chat lines
  (the refusal in combat, where the report is kept) are in `ns.L` in English only, which
  `tests/locales_spec.lua` lists in `ENGLISH_ONLY`, as it does the Draw distance section's labels
  and tooltips, not translated yet.

## Cutscenes and the viewport

Turn the viewport on with a margin on every side, then:

1. An in-engine cinematic, the risky kind: the game re-anchors the world for its black bars. On
   Forever `/run OpeningCinematic()` plays nothing (tested 2026-10-09); the race intro only plays
   on a new character's first login, so create one with the viewport on (it's account-wide). During
   the intro you should see only Blizzard's black bars (top and bottom), none of the viewport
   margins. Right after it ends (or after Esc), the viewport is back. On retail, quest cutscenes do
   the same.
2. During such a cinematic, switch between windowed and fullscreen or resize the window. That fires
   a display change in the middle of it, the moment both Blizzard and a viewport addon want to move
   the world.
3. Cancel one right away with Esc.
4. `/run MovieFrame_PlayMovie(MovieFrame, 1)` plays a pre-rendered movie (the game hides the world
   for it). Let it run out once and cancel it once; the viewport comes back within a second.
5. Repeat 1 and 4 with the viewport off, to have something to compare with.

A crash writes a report to `_classic_beta_/Errors/` (date, time and "Error" in the name). The
`Error:` and `Description:` lines at the top say what failed. If it only happens with the viewport
on, that report is what to look at.
