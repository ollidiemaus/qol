# Quality of Life

**Small quality of life features for WoW Forever, in one addon.**

Quality of Life bundles the little things you'd otherwise install five addons for: a smaller 3D
viewport, action bars that grow the other way, square action buttons without borders, class-colored
health bars, junk selling and repairs at merchants, quests accepted and turned in for you, bookmarks
for your bank characters on the mail frame, IDs and vendor prices in tooltips, a square minimap, dungeon entrances, boats and zeppelins on the world
map, rings of actions for mouse and controller, click casting on unit frames, back buttons for the Steam Deck on Forever's
controller bar, and switches to hide UI pieces you never click (also the buff tooltips that pop up
in the controller interface). Everything is set up in the game's own options window. There's no minimap button.

It's made for WoW Forever and also runs on retail (Midnight) and Classic Era (1.15).

## Features

### Merchant

- **Sell junk automatically:** every grey item in your bags is sold when you open a merchant. The
  chat tells you how many items went and for how much.
- **Repair automatically:** your equipment is repaired at every merchant who can repair.
- **Use guild funds:** repairs come out of the guild bank first, as far as your guild lets you
  withdraw. If that doesn't cover everything, your own gold pays the rest.

### Quests

- **Accept quests automatically:** every quest an NPC offers, and every quest a group member shares.
- **Turn in quests automatically:** finished quests are turned in when you talk to the quest giver.
  A quest with rewards to choose from, or one that costs gold, stays open for you to decide.

Hold **Shift** while talking to an NPC to do everything yourself that time.

### Loot

- **Faster auto loot:** when the game auto loots, all of the loot goes into your bags at once instead
  of one item after another. When the game doesn't auto loot, nothing changes. What can't be taken
  (full bags, a bind-on-pickup item to confirm, a roll) stays in the loot window. Off until you turn
  it on.

### Tooltips

- **IDs:** spell, item, buff and debuff, NPC, quest, currency and achievement IDs in their tooltips.
- **Vendor price:** what an item sells for, everywhere, not just while a merchant is open, as a
  `Vendor` line with the price of one. Hold Shift for the whole stack.

On Classic Era there are no quest IDs (buff and debuff IDs aren't confirmed there yet), and the
game's own sell price line becomes the `Vendor` line. With a bag addon there, Shift may still show
the price of one, as its buttons may not say how many items a slot holds.

### Interface

- **Hide the system bar:** the micro menu (character, spellbook, ..., game menu). Your key
  bindings still open everything, and in a vehicle the buttons still show on the vehicle bar.
- **Hide the bag bar:** the backpack and bag slots. Bag key bindings keep working.
- **Sort on open:** the game's own sort runs each time you open your bags yourself, with keyboard
  and mouse or in the controller interface, with combined or separate bags. It undoes anything you
  arranged by hand, so it's off until you turn it on. It doesn't run in combat, and doesn't catch up
  afterwards, or when the game opens your bags: at a vendor, the bank or a mailbox, in a trade, or
  for a spell that targets an item. The keyring and bank bags don't sort either.
- **Frames past the screen edge:** in Edit Mode, frames can go a little past the edge of the screen
  (30 points, more for a frame you made bigger), so their art can sit right on it. Turn off Snap to
  Elements for the last bit: it lines a frame's box up with the edge. Where you put a frame is saved
  in the Edit Mode layout, so it stays after a `/reload` and a layout switch (AutoSetup's on a
  resolution change too). Turned off, the frames are kept inside the screen again.

### Chat

- **Hide the social button** on top of the chat window (the Friends button on Classic Era).
- **Hide the other chat buttons:** the chat menu, channel, voice chat and text to speech buttons.
- **Hide the combat log:** the Combat Log tab leaves the chat window. The combat log keeps running,
  so addons that read it still work.
- **Names in class color:** player names in chat take the color of their class, in every channel.

### Mail

- **Bookmarks:** up to six characters you often send mail to, such as your bank characters, as tabs
  on the right of the Send Mail window. A click on a tab puts the name in **To** and moves on to
  **Subject**. A tab shows the character's class once they've logged in with Quality of Life, else
  the mail icon; point at it for the name. The character you're playing gets no tab. Type the names
  on the Mail page of the settings as you would in To: on WoW Forever with the surname (Name
  Surname), elsewhere the name, or Name-Realm for a character on another realm. On Classic Era the
  tabs are the small ones of its spell book.

### Minimap

- **Square minimap,** framed in the bronze of Forever's round minimap or with a thin black line.
  Addons that put buttons around the minimap and ask for its shape place them along the square.
- **Zone text above or below the minimap,** centered on the map's edge instead of in the bar at the
  top, or **inside the map,** in the middle of its top or bottom edge, drawn over the map. On a
  square map it gets the map's width; on a round one it sits a little further in, where the circle
  is wide enough for a name. A name still too long ends in "…". It can also be **hidden**; on
  Forever the clock, the calendar and the mail icon stay. Or keep it where the game puts it and tick
  **Hide its frame** for the bare zone name.
- **Zone text, clock and coordinates in class color.** The zone text normally shows the color for
  friendly, hostile or contested territory.
- **Font size of the zone text, the clock, the coordinates and FPS and ping,** from 9 to 24 or the
  game's own. With a larger font the clock's button grows with it, and the rows above and below the
  minimap make room.
- **Clock, addon compartment, tracking button and the day and night icon** (Forever's, or the
  time of day icon on Classic Era): each can move to a row above or below the minimap (left,
  center or right), or be hidden. The tracking button and the day and night icon can also sit
  inside the map: in a corner, or in the middle of its top or bottom edge. Things in the same spot
  sit side by side, the zone text taking the room the others leave; with something below the
  minimap, the coordinates move under it. On Classic
  Era the tracking button shows only while you track something, as the game has it.
- **FPS and ping** in a row above or below the minimap (left, center or right), like the clock,
  updated every second, also in class color and at another font size. The ping is the higher of
  your home and world latency. **Show** picks FPS and ping, FPS or Ping; the text takes only the
  room it needs.
- **Offset:** the zone text, the clock, FPS and ping, the addon compartment, the tracking button, the
  day and night icon and the coordinates can each shift a little from their spot, up to 30 either
  way across and up or down, by the arrows or a typed number. An offset works at the game's own
  place, in a row and inside the map, stays when you change the Position, and moves only that
  element. At its default spot the zone text moves just its name, so the clock and the buttons
  next to it stay put. The calendar button has no offset.
- **Hide the calendar button or the coordinates** under the minimap: their Position is the game's
  spot or Hidden.

On the Minimap page the Shape section comes first, then a table with a line for each element:
its Position, Font size, Class color and Offset X and Y, where it has them. Hidden is a Position;
an element set to Hidden shows no other options. Hide its frame (under the zone text) and Show
(under FPS and ping) are lines of their own, there only while they apply. Defaults puts every
element back where the game has it.

### World map

- **Dungeon and raid entrances:** marked on the zone and continent maps. Point at one to see its
  name. Blackrock Mountain's dungeons show on both Searing Gorge and the Burning Steppes.
- **Boats, zeppelins and portals:** the harbors and zeppelin towers, the portal between Darnassus
  and Rut'theran Village and the Deeprun Tram (zeppelins and the tram get icons of their own in the
  style of the boat's). Point at one to see where it goes; click it and the
  map of that place opens. Forever's new routes are there too: the boat from Stormwind Harbor, the
  stop at Southshore, the boat between Tanaris and the Riverglades and the airships to Zephras Isle.

The places come from Forever's own game data, and Classic Era has the same zone maps, so these
options show on Forever and Classic Era. On Classic Era the pins follow its world: Forever's new
routes aren't there, the boat from Menethil Harbor goes straight to Auberdine, and boats get a ship
icon (Classic Era has no ferry icon). On retail, the default map marks dungeon entrances itself.

### Unit frames

- **Health bars in class color:** the health bar of the player, target, target of target, focus and
  focus target frames takes the class color of the unit it shows, each frame switched on separately. The bar
  keeps the shading of the default green bar. Units without a clear class, like most NPCs (and the
  player frame while you're in a vehicle), keep the default bar.
- **Mana in bear and cat form:** the player frame shows your mana in a third bar under rage or
  energy while you're shapeshifted, in the frame's own art (the one the game uses for a third bar).
  Its numbers follow the game's Status Text setting, like the other bars. Off by default; it stays
  away in a vehicle.
- **Hide portrait hit text:** no more damage and heal numbers, or Dodge, Parry, Miss, Block and Immune,
  flashing over your and your pet's portrait. Floating combat text in the world stays as it is. Off by
  default.

### Group frames

On WoW Forever, a page for the game's own raid-style party and raid frames:

- **Show the game's buffs:** the game's own Display buffs setting for its group frames, right on the
  page. The checkbox shows what the game has and changes it there; QoL keeps no copy, never changes it
  on its own, and the page's Defaults button leaves it alone.
- **Show tracked buffs:** your own icons for the buffs you choose, on every group frame: raid frames,
  party frames in raid style, your own frame too (not pets, arena, target or focus). Drag a spell from
  your spellbook onto the page's table to track it; a spell dragged twice makes no second line. Its Show
  column says when the icon shows:
  - **Has it:** while your own cast of that buff is on the member (another druid's Regrowth doesn't
    count), at any rank you know, with a dark sweep for the time left and a number for more than one
    stack. Tick **Countdown numbers** to add the game's seconds-left numbers too, sized by the
    **Countdown number size** slider. It works in fights
    too, when you need it most: the game itself fills it, so it appears the moment you cast and goes the
    moment the buff ends.
  - **Lacks it:** a grey icon while the member has no buff of that name, at any rank and from anyone;
    the group version counts too (Gift of the Wild for Mark of the Wild, Arcane Brilliance for Arcane
    Intellect, Greater Blessings for Blessings, and so on), and so does a rival buff, one the game
    won't keep alongside it (see Reminders below for the list). It's gone the moment the member gets the
    buff, and never shows on a dead or offline member; an out-of-range member's frame fades, the icon with it. It shows **only out of combat**,
    when you buff the group: every one hides when a fight starts and comes back when it ends, as the
    game doesn't let addons read the group's buffs during a fight.

  Its **Position** puts the icon at one of nine spots on the frame: a corner, the middle of an edge or
  the centre (new lines start at the top right). Icons on the same spot sit side by side in the list's
  order, from the spot towards the middle. Each line keeps its place on every frame, so an icon never
  moves mid-fight: one that isn't showing leaves a gap, while a paused line or one for a spell this
  character doesn't know takes no place. The **Tracked buff size** slider sets how big all of them are.

  Each line has a checkbox to pause it and an X to remove it. The list is the same
  on all your characters, in the order you added it; lines for spells a character doesn't know are
  greyed out there and show nothing. The icons let clicks through, so clicking a frame and click
  casting work as before, and they appear on frames made in combat too. Off by default, and
  it costs nothing while it's off or you're not in a group; the Defaults button switches it off, resets
  the sizes and countdown numbers, and keeps your list. Other addons can switch it through QoL's API (`groupframes`), which never touches
  the game's Display buffs setting.
- **Hide the raid manager:** the tab at the edge of the screen that the game shows in every group (ready
  check, world markers, the group frames' options) is gone while you're in a group, and back the moment
  you untick the box. Your group frames stay. Off by default.

### Chat commands

- **`/rl`** reloads the interface, as a short form of `/reload`. It's only added when neither the
  game nor another of your addons already uses `/rl`; then theirs stays.

### Viewport

Draws the game world in a smaller area and fills the margins with a color of your choice, so chat,
action bars or unit frames at the screen edges no longer cover the world. Set each margin (top,
bottom, left, right) in screen pixels; the world always keeps at least a quarter of the screen.
The margins stay when you hide the interface with Alt+Z.

### Action Bars

Reverse the direction buttons fill a bar, separately for every bar and both directions (a table on
the Action Bars page, a line per bar with a Vertical and a Horizontal checkbox):

- **Vertical:** on a bar with several rows, the first row moves from the bottom to the top (or the
  other way round).
- **Horizontal:** button 1 starts at the right end of the row instead of the left.

Works for action bars 1 to 8, the stance bar and the pet bar, and keeps working after you change a
bar in Edit Mode.

**No bar paging with Shift+1-6:** the keys that switch the main action bar to another page (Shift+1
to Shift+6, or whatever you bound to them) act like the same key without Shift instead, so Shift+1
presses action button 1 and macros can check for Shift with `[mod:shift]`. Your saved key bindings
stay as they are; turn the option off and the keys page again.

**Hide button borders:** the buttons of action bars 1 to 8, the stance bar and the pet bar lose
their frame, and the icons are square. Pointing at a button, pressing
it, an active button, the red flash of auto attack and the green glow of an equipped item light up
as squares, with the game's classic button textures; the cooldown swipe covers the whole icon. The
casting animation on the buttons is left out, since it is drawn for the round frame. For icons
without the dark edge some of them have, use an icon pack.

With Forever's controller interface on, the game shows its own action bars instead of these, so
the options above wait until you switch back to keyboard and mouse. The rings work in both.

**Upgrade when learning a rank** (WoW Forever, off by default): when you learn a new rank of a spell,
the slots holding your previous highest rank get the new one, on every bar, page and form and on the
controller bars. Lower ranks stay where they are, so a spell you downrank on purpose isn't touched;
to keep the rank you just replaced, drag it back once and it stays from then on. It waits for the end
of combat, an empty cursor and, in the controller interface, for the game's windows to close.

**Upgrade all spells now**, under it, moves every spell on your bars to the highest rank you know,
once, downranks included, whether the option is on or off. Macros, the pet bar and rings are left
alone by both. Click casting already casts the highest rank.

### Cooldown Manager

On WoW Forever, a page for the game's own Cooldown Manager (the rows of cooldowns and tracked buffs
you set up in Edit Mode).

**Hide icon borders:** the icons of all four rows (Essential Cooldowns, Utilities, Tracked Buffs
and Tracked Bars) lose their border, so they match action buttons without borders. Everything else
on an icon stays: its rounded shape, the cooldown swipe, stack counts, the colored border of a
debuff and the out-of-range tint. Off by default; untick it and the borders are back at once.

A tracked buff whose icon shows all the time isn't QoL's doing: that is the game's own Edit Mode
setting "Hide When Inactive" on the buff row being off.

**Reminders:** an icon for a buff your character is missing, gone once you have it. Turn on **Show
reminders** and pick the presets you want in the table below it (all off by default):

- **Well Fed**, from any food or drink that makes you Well Fed, or that takes its place under a name
  of its own (Blessed Sunfruit, Alterac Spring Water, Dragonbreath Chili, "Increased Stamina", ...).
- **Well Rested**, the buff that makes your rested experience build up faster.
- **Camp Benefits**, the bonuses from the items set up at a camp.
- **Main Hand Weapon Buff** and **Off Hand Weapon Buff**, one per hand: shows while that hand's
  weapon has no weapon buff (a poison, a shaman's weapon spell such as Rockbiter Weapon, a sharpening
  stone or an oil, any of them), with the weapon's own icon so you can tell the hands apart. The off
  hand's shows only while you hold a weapon there, not a shield or a held item, and neither shows
  with a fishing pole in your hands.

Add your own by dragging a spell from your spellbook onto the table, Thorns or Mark of the Wild for
instance. Your reminders come after the presets, in the order you added them, each with a checkbox to
pause it and an X to remove it. The list is the same on all your characters: a reminder shows only on
a character that knows the spell, at any rank, and is greyed out on the others. A buff counts at any
rank and whoever cast it, and so does its group version: Gift of the Wild for Mark of the Wild,
Arcane Brilliance for Arcane Intellect, the Prayers for Power Word: Fortitude, Divine Spirit and
Shadow Protection, and the Greater Blessings for the Blessings of Might, Wisdom and Kings. So does a
rival buff, a different buff the game won't keep on you alongside it ("A more powerful spell is
already active"), whichever of the two is stronger and both ways: Fire Shield (the imp's, and the
ally spell at every rank) for Thorns, Dampen Magic for Amplify Magic, and the Scrolls of Stamina,
Intellect and Spirit for Power Word: Fortitude, Arcane Intellect and Divine Spirit. Reminders
are for buffs on yourself: a spell that leaves no buff on you, such as a heal, shows its icon all
the time.

The icons sit in a row of their own, centred, in the table's order, and look like the Cooldown
Manager's buff icons (**Hide icon borders** takes their border off too). They don't take the mouse,
and they work with the game's Cooldown Manager switched off. In combat the game hides buffs from
addons, so the reminders go away until combat ends.

The row starts in the middle of the screen's lower half. To move it, press **Unlock** next to
**Reminder row**: it shows question-mark icons, even with nothing missing, and you can drag it
anywhere. Press **Lock**, or close the settings window, to fix it there; the place is kept on all
your characters, after a reload too, and stays put whatever your screen. **Reset** next to
**Reminder row position** puts it back, and **Icon size** sets how big the icons are.

On the right, the **Hide reminders** boxes say when the reminders stay away:

- **While resting**, in an inn or a city (off by default).
- **In combat** (off). Left off, a buff that runs out mid-fight shows its reminder whenever the game
  lets addons see your buffs; for now WoW Forever hides them in every fight anyway.
- **While mounted** (off).
- **While dead or on a flight path** (on), when you can't put a buff up anyway.
- **Experience reminders at maximum level** (on): only Well Rested, once your character can't gain
  experience any more. The other reminders still show.

They come back as soon as the condition ends.

### Rings

Rings of actions, drawn in the bronze of Forever's minimap, as many as you like. Hold a ring's key,
point at an action and let go to use it; let go in the middle and nothing happens. A ring works in
combat, shows cooldowns and charges, and names the action you point at in the middle.

- **Making them:** on the Ring page of the settings (`/qol ring` opens it there). Below the switch
  that turns them on, the page is a page of the spell book: your ring on the left, what you can put
  on it on the right. The settings stay open when you open the spell book, and in combat the page
  shows your rings but changes nothing.
- **Adding actions:** the right of the page lists what this character has, as in the spell book:
  tabs for **Spells**, **Items** (the ones with a use, in the bags or worn), **Toys**, **Mounts**
  and **Macros**, a search box, and the page buttons (the mouse wheel turns pages too). Click one to
  put it on the ring, and click it again (it has a check mark) to take it off. The toys are the ones
  the Toy Box shows with its own filters. Classic Era has no Toy Box, so there's no Toys tab there;
  its spells are the ranks its spell book shows (its **Show all spell ranks** box).
- **Arranging them:** drag one from the list, the spell book, the bags or an action bar onto the
  ring's empty slot (the **+**) to add it, onto a slot to put it there, or off the ring to take it
  away; a right-click takes one away too. With a controller, click a slot to pick up or put down
  what's on it. The arrows above the ring go to your other rings; **New ring** makes one, and
  **Delete ring** deletes the one shown after a second click.
- **Grows with what's on it:** a ring has as many slots as actions, up to 12, spread evenly round
  it, so there are no empty buttons.
- **For all your characters:** the rings are saved for the account. Each character sees what it
  can use: spells it knows, items in its bags or worn, toys and mounts it has, macros it has (by
  name). The rest stays on the ring for the characters that can, and the page says how many that
  are. A ring a character can't use anything on leaves its keys to the game.
- **Two keys a ring:** below the ring, **Aim with the mouse** opens it at the mouse
  cursor, and **Aim with the right stick** opens it in the middle of the screen for a controller's
  right stick (the camera stays still while you aim). Click a box, then press the key or the
  controller button; a right-click clears it. A key belongs to one ring at a time, and while the
  rings are on it opens that ring instead of what Key Bindings gives it. The rings also work in
  Forever's controller interface.

Turn them on at the top of the Ring page.

Updating from the single ring: it was made of an action bar's buttons and its keys were in Key
Bindings. The new rings start empty: make one on the Ring page (`/qol ring`) and give it its keys there.

### Click casting

Bindings on the unit frames: click a frame with a binding's combination, or press it while the
mouse is over one, and its action is used on that frame's unit without targeting it first. Shift-Left
can heal a party member while you keep your target, and a key can heal whoever you point at.

- **Making them:** on the Click casting page of the settings (`/qol click` opens it there), right
  after the Ring page and built like it: your bindings on the left, what you can bind on the right
  (**Spells**, **Items** and **Macros**, with the search box and page buttons). Click an action, then
  click, turn the mouse wheel or press a key for it, with any of Shift, Ctrl and Alt held; Escape
  cancels. You can also drag a spell from the spell book, an item from the bags or a macro onto the
  page. Click a binding's box to give it another combination; a right-click removes it.
- **Quick bind:** click **Quick bind**, point at an action on the right and click, turn the wheel or
  press a key: that's the binding. A combination that already does something gets the new action,
  and the page says what it had ("Shift-Left: Flash Heal (was Renew)"). A binding that doesn't work
  right now (a spell of your other specialization) keeps its combination. Escape or the button ends
  it, and so do leaving the page and combat.
- **Target and Menu:** a new character starts with Left: Target and Right: Menu, as the game's
  frames have them. They are bindings like the others: move them to another combination (Alt-Left
  for Target, say) or remove them, and a plain left click is free for a spell (or does nothing). A
  removed one stays on the page as **Not Bound**: click its box to bind it again.
- **Clicks, keys and the wheel** work while the mouse is anywhere over a unit frame, its health and
  mana bars too. Everywhere else a key does what Key Bindings gives it, and a ring's key opens its
  ring.
  Escape, Shift, Ctrl or Alt on their own, Cmd on the Mac, and the keys you move, turn and jump with
  can't be bound.
- **Like the game:** a click acts when you let go of the button, a key when you press it. A spell
  casts the highest rank you know, and the page shows that rank, so a binding moves up by itself
  when you learn one and every rank of a spell counts as the same action. To keep a lower rank, bind
  a macro. An item is used on the unit (a bandage), and a macro sees the unit as `[@mouseover]`.
- **Which frames:** the player, target, target of target, focus, focus target, pet, party (with the
  party pets), the raid-style party and raid frames, and the boss and arena frames. A unit frame
  addon that uses the usual way for addons to join click casting gets your bindings too, and so do
  Grid2's frames. Friendly nameplates take your Left and Right bindings. Enemy nameplates, and the
  target, target of target, focus and focus target frames on an enemy, take yours only if you tick
  **On enemies** at the top of the page; left off,
  Left and Right there do what the game does, and keys go to what they're otherwise bound to.
- **For each character:** the bindings are saved per character. A binding works while the character
  has its action, so one combination can be one spell in one specialization and another in the
  other. The page greys out the ones that don't work now and keeps them, and marks two working
  bindings on one combination in red (only one of them works; its tooltip names the others).

Turn it on at the top of the Click casting page. While it's off, the page is greyed out and the
bindings can't be changed. Turning it off gives the frames the game's own clicks back at once.

The game's own Click Casting (in Forever and retail) takes only clicks, and each binding is made in
its dialog. This one takes keys and the wheel too, and quick bind makes many bindings fast. Both can
be on at once, but the game's spell, macro and pet bindings win on the same click: the page marks
those in red, so change them in the game's Click Casting.

What it can't do:

- In combat nothing changes: the bindings stay as they were when combat started, and frames that
  appear in combat (someone joins the raid) get them once it ends.
- Controller buttons can't be bound: click casting is for the mouse and keyboard.
- A unit frame addon's frames get the bindings when click casting is on as you log in. Turned on
  later, some of them only do after a `/reload`.

### Controller

Only on WoW Forever, and only while its controller interface is on: with keyboard and mouse the
back buttons hide and their keys press nothing, and the buff tooltips show as usual. Turning the
controller interface on or off switches them right away.

**Back buttons:** more buttons on the controller action bar for controllers with back buttons or
paddles, like the Steam Deck: L4, L5, R4 and R5. They show icons, cooldowns and charges like the
bar's other buttons.

- **Four bars:** with **Press a trigger to keep its bar on** turned on, each back button has an action on
  every controller bar, like A does: L4 alone is L4 on the Top bar, RT with L4 is L4 on the Right
  bar, LT and RT with L4 is L4 on the Bottom bar. A bar switched on counts like a held trigger. Each
  bar's four show beside it: Top's in a row above it, Bottom's in a row below it, Left's left of it
  and Right's right of it. Without the trigger toggle they act on Top only, and only Top's show.
- **Compact layout:** the game shows only one bar there, so only the back buttons of the bar a press
  goes to show, beside it, even when the game shows Top's buttons.
- An empty back button does nothing when pressed; it doesn't fall back to Top's. A bar's back
  buttons hide with that bar (hidden as empty, or the special page) but stay while a stance or
  vehicle bar sits in its place. They keep the same actions on every controller page.
- **Binding them:** the Controller page lists the four keys under **Keys** (one key serves all four
  bars), each named by its slot on the Top bar (L4: Action Bar 8, button 9, and so on), with two key boxes like the game's
  Key Bindings: click a box, then press the back button (or the key). Escape or another click on
  the box cancels, a right-click clears a key. The same bindings are under Esc > Options > Key
  Bindings > AddOns > Quality of Life. On the Steam Deck the game doesn't see the back buttons by
  themselves: give them keys in Steam Input first (keys you don't use otherwise, like F13 to F16,
  or numpad keys), then bind those here. A controller whose paddles the game sees directly needs
  nothing: a back button with no key of its own uses its paddle, as long as nothing else is bound
  to it.
- **Putting spells on them:** drag a spell onto one, as onto any action button (out of combat; with
  the action bars locked, hold Shift). Each controller bar's back buttons are the last four buttons
  of a standard action bar, picked under **Slots** for each bar (Action Bars 2 to 8; Top 8, Left 7,
  Right 6 and Bottom 5 at first), so what you put there shows on the back button too. Pick bars you
  don't use otherwise.

The buttons show and hide with the controller action bar and follow their bars when you move or
scale it in Edit Mode.

**Bars that follow the stance:** the game's Stance bar setting changes one controller bar when you
enter a stance. Tick the **Top**, **Left**, **Right** or **Bottom** bar here and that bar changes
too, so a druid in bear form can have a whole set of bear actions, also in combat. Forms, warrior
stances and stealth all count. Prowl isn't a stance of its own on Forever: it keeps Cat's actions.

- Each ticked bar has its own actions per stance. Enter the stance and fill the bar with the game's
  action bar editor; a slot you leave empty stays empty. The normal actions come back when you leave
  the stance.
- On the Top bar only the D-pad half follows: A, B, X and Y stay as they are, so you can still jump
  and interact.
- Only page 1 follows: pages 2 and 3 show as usual in a stance, and flipping back to page 1 shows
  the stance's actions again, also in combat.
- One list of bars holds for all your stances, saved per character. Unticking a bar keeps its
  actions for when you tick it again. A change made in combat applies when combat ends.
- There's room for a limited number of bars: all four in about two stances, a bit more for a warrior
  or druid. The stances you enter first keep their bars and spells never move; a bar that doesn't
  fit stays normal in the other stances, and this page says so. A form you learn later gets its bars
  by itself if there's room.
- The bar the game's Stance bar setting uses on page 1 shows ticked and greyed out: the game handles
  that one. That setting can't pick page 1's Top bar, so Top can always be ticked.
- With keyboard and mouse nothing follows. Turning the controller interface off or on switches the
  bars without a reload, after combat, and turning it on also waits for the game's options to close.

**Trigger toggle:** tick **Press a trigger to keep its bar on** and one press of a trigger keeps its
bar on, so you needn't hold it. Press it again to go back to the Top bar. LT is the Left bar, RT the
Right bar, and both on is the Bottom bar, also when you press them together.

- A trigger held while you press a button or a back button works as it always did, and doesn't
  change what's on. Held and let go with nothing pressed counts as a press, however long you held it.
- The triggers are two switches: from Bottom, a press of LT leaves the Right bar on.
- It works in combat. **Back to Top after combat** is on by default, since a bar on takes
  A and with it jumping and interacting. Untick it to keep the bar on.
- While a bar is on, a warm glow, the marker, shows behind it, so you can see what your
  buttons do. It shows during a hold as well.
- The eight buttons of the bar change, and the back buttons act on the bar on (see **Back
  buttons**). LB, RB, the sticks and the rings stay as they are, and holding LB or RB for targeting
  works with a bar on. The marker covers the bar's back buttons too.
- A possess, vehicle or override bar turns the bar off, in combat too, and it stays off: a press
  while one is up turns nothing on. The game's
  windows keep their keys while a bar is on; it's still on when you close them. Switching to
  keyboard and mouse turns it off.
- The bar on follows the page and the stance, and following bars work as usual.
- The compact layout isn't covered: it only shows the Top bar. The back buttons there show the bar on's.

**Buff tooltips:** the controller interface shows the tooltip of every buff or debuff you gain or
refresh for a few seconds. **Hide new buff tooltips** keeps those away; a buff you select or point
at still shows its tooltip.

### Graphics & Camera

Settings the game has but its options don't show, so far only reached by typing `/console`
commands, each on a row of its own with a description when you point at it. The **Graphics** section
has:

- **Ground clutter distance:** how far away grass and small plants are drawn (40 to 500 yards).
- **Ground clutter fade:** how softly grass fades in at the edge of that distance (40 to 500).
- **Ground clutter density:** how thick grass and small plants grow (16 to 256).
- **Weather density:** how much rain and snow falls (0 to 3).
- **Always sharpen:** sharpens the image even when the game isn't upscaling it; the game's Resample
  Sharpness slider sets how much.

The **Draw distance** section after them has:

- **World distance:** how far away the world is drawn (1000 to 10000 yards, in steps of 100). The
  game's View Distance sets 3000 to 10000.
- **Horizon start** and **Horizon end:** how far away the horizon begins (400 to 4000) and ends
  (1500 to 10000), in steps of 100. View Distance keeps the end equal to World distance, so move
  both, or distant terrain stops where the horizon ended.
- **Object fade scale:** how long objects stay before they fade out in the distance (50 to 5000, in
  steps of 10). The game's Environment Detail sets 50 to 150.
- **Object cull size:** objects that look smaller than this are hidden (1 to 100). Environment
  Detail sets 35 down to 14.
- **Object cull distance:** how close objects stay shown whatever their size (1 to 200 yards). No
  game setting changes it.

Higher (or, for the cull size, lower) draws more and costs frame rate. For now these rows are in
English in every language.

The **Camera** section after them has:

- **Max camera distance:** how far the camera can zoom out (1.0 to 4.0, in steps of 0.1). The game's
  own Max Camera Distance slider stops at 2.0; moving it brings this back to 2.0 or lower.

Each slider covers the range the game takes (World distance and the horizon take any value, so
theirs cover what View Distance sets, World distance down to its game default of 1000), and changes
apply at once, in combat too (a setting the game itself won't change in combat is greyed out until
combat ends). The
box next to a slider shows its value; type an exact one there and press Enter or Tab (Escape puts
it back). A number outside the range is set to its nearest end. **Reset** at the end of a row puts
that setting back to the game's own default, and is greyed out while it's already there, so you
see at a glance what you've changed; pointing at a row or its Reset shows the game default. On a
row one of the game's graphics sliders sets (Ground Clutter: ground clutter distance and density;
View Distance: World distance and the horizon; Environment Detail: object fade scale and cull
size), Reset instead puts back what that slider sets, with the other rows it sets, just as moving
the slider would; its tooltip names them, and it's never greyed out. World distance's game
default, 1000, would cut the world off shorter than anything View Distance sets.
**Defaults** at the top puts every row back at once (click twice to confirm). The
game keeps these values, as it would with `/console`; Quality of Life saves nothing of its own and
shows what the game has every time you open the page. The game's own settings can set some
of them again (moving its Ground Clutter, View Distance or Environment Detail slider changes the
rows it sets, its Max Camera Distance slider the camera distance), and in raids and
battlegrounds the game uses its Raid and Battleground graphics instead, while those are on. A
setting your client doesn't have isn't shown.

On retail Max camera distance goes up to 2.6, and the game's View Distance sets World distance from
1500. On Classic Era Ground clutter distance starts at 70 (its Ground Clutter sets 70 to 320), and
Classic Era has no View Distance, so
nothing in its options changes World distance or the horizon, and their Reset puts back the game's
default (World distance 2112, Horizon start 777, Horizon end 1600), greyed out while it's there.

## Settings

Type `/qol` (or `/qualityoflife`): the settings open in a window of their own, in Forever's bronze
frame (on Classic Era in its own window art) and laid out like the game's options, with the pages
on the left and their options on the right. Drag its title bar to move it; `/qol` again, Escape or
the X closes it. It also opens in combat; Escape then goes to the game, so close it with the X.

**Esc > Options > AddOns > Quality of Life** has an information page with the chat commands, the
author's other addons (with links to copy) and an **Open settings (/qol)** button. In Forever's
controller interface the button opens the window once you close the game's options.

The pages, in five groups:

- **General**
  - **Automation:** junk selling, repairs, quests, faster auto loot, sorting the bags.
  - **Chat:** the chat buttons, the combat log, names in class color, `/rl`.
  - **Mail:** the bookmarks' names.
- **Display**
  - **Interface:** hiding the system and bag bars, frames past the screen edge, tooltips.
  - **Unit Frames:** mana in bear and cat form, portrait hit text, health bars in class color.
  - **Group Frames** (on Forever): the game's buffs and tracked buffs on the group frames, hiding the raid manager.
  - **Action Bars**, **Cooldown Manager** (on Forever) and **Viewport**.
- **Maps:** **Minimap** and **World map** (on Forever and Classic Era).
- **Input:** **Ring**, **Click casting** and **Controller** (on Forever).
- **System**
  - **Graphics & Camera:** the game's hidden graphics, draw distance and camera settings.

On Classic Era the pages leave out what it doesn't have: Sort on open, mana in bear and cat
form, guild bank repairs, the addon compartment's place, the calendar button and the player
coordinates. Junk selling and repairs with your own gold work as everywhere.

Every page fits without scrolling, most in two columns, and every option's name fits on one line,
in English and German; point at it for the whole story. With a controller, the
arrows next to a viewport margin move it one pixel per press. In Forever's controller interface a
dropdown doesn't open its list: each press (or click) switches it to the next choice, as the game
froze when its options closed after one of these lists had been opened there. Changes apply right
away, key bindings set on the Controller page too; the few that touch protected parts of the
interface (action bars, key bindings, viewport, system bar) wait until you leave combat. In
Forever's controller interface the back buttons and the rings also wait until the game's options
and menu are closed (a second at most).

Forever's beta can freeze when you close its options after changing something there with the
controller interface on (its own Invert X Axis did it). Quality of Life's settings are in their own
window, outside the game's options, so changing them doesn't involve those.

Quality of Life is available in English and German.

## Good to know

- Quality of Life never replaces Blizzard's action bar, Edit Mode or tooltip code or hooks their
  functions. It only moves the button slots of the bars you flipped, changes the textures of the
  buttons whose borders you hid, widens how far Edit Mode frames may go, parents hidden frames to
  a hidden holder, adds lines to tooltips (on Classic Era from the tooltips' own scripts, turning
  the game's sell price line into its vendor line), and puts a bookmark's name in the mail's To
  box. That keeps it clear of the "tainted by an addon" errors Midnight-era clients are strict about.
- Don't run it together with another viewport or action bar growth addon: both would move the
  same frames. Hiding the button borders is the same: leave it off when another addon styles your
  buttons.
- Other tooltip addons may show vendor prices too; turn one of them off if you see the price twice.
- The same goes for other quest automation and minimap addons: use one of them for the same job.
- Use one click casting addon: two would set the same unit frames' clicks. When another one is
  there first, Quality of Life leaves the way unit frame addons join click casting to it and only
  covers Blizzard's frames.
- Another controller addon may put back paddle buttons of its own around the controller action bar.
  Use its paddles or these back buttons, not both: they would sit in the same place and want the
  same keys.
