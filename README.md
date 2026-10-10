# Forever QoL

**Small quality of life features for WoW Forever, in one addon.**

Forever QoL bundles the little things you'd otherwise install five addons for: a smaller 3D
viewport, action bars that grow the other way, class-colored health bars, junk selling and repairs
at merchants, quests accepted and turned in for you, IDs and vendor prices in tooltips, a square
minimap, dungeon entrances, boats and zeppelins on the world map, and switches to hide UI pieces
you never click. Everything is set up in the game's own options window. There's no minimap button.

It's made for WoW Forever and also runs on retail (Midnight).

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

### Tooltips

- **IDs:** spell, item, buff and debuff, NPC, quest, currency and achievement IDs in their tooltips.
- **Vendor price:** what an item sells for, everywhere, not just while a merchant is open. For a
  stack in your bags you see the whole stack's price and the price of one.

### Interface

- **Hide the system bar:** the micro menu (character, spellbook, ..., game menu). Your key
  bindings still open everything, and in a vehicle the buttons still show on the vehicle bar.
- **Hide the bag bar:** the backpack and bag slots. Bag key bindings keep working.
- **Show the sort button on combined bags:** adds the sort (clean up) button next to the search box
  of the combined bag.

### Chat

- **Hide the social button** on top of the chat window.
- **Hide the other chat buttons:** the chat menu, channel, voice chat and text to speech buttons.
- **Hide the combat log:** the Combat Log tab leaves the chat window. The combat log keeps running,
  so addons that read it still work.
- **Names in class color:** player names in chat take the color of their class, in every channel.

### Minimap

- **Square minimap,** framed in the bronze of Forever's round minimap or with a thin black line.
  Addons that put buttons around the minimap and ask for its shape place them along the square.
- **Zone text above or below the minimap,** centered on the map's edge instead of in the bar at the
  top.
- **Zone text in class color** instead of the color for friendly, hostile or contested territory.
- **Clock, addon compartment, tracking button and Forever's day and night icon:** each can move to
  a row above or below the minimap (left, center or right), or be hidden. Things in the same spot
  sit side by side; with something below the minimap, the coordinates move under it.
- **Hide the calendar button.**
- **Hide the coordinates under the minimap.**

### World map

- **Dungeon and raid entrances:** marked on the zone and continent maps. Point at one to see its
  name. Blackrock Mountain's dungeons show on both Searing Gorge and the Burning Steppes.
- **Boats, zeppelins and portals:** the harbors and zeppelin towers, the portal between Darnassus
  and Rut'theran Village and the Deeprun Tram (zeppelins get an icon of their own in the style of
  the boat's). Point at one to see where it goes; click it and the
  map of that place opens. Forever's new routes are there too: the boat from Stormwind Harbor, the
  stop at Southshore, the boat between Tanaris and the Riverglades and the airships to Zephras Isle.

The places come from Forever's own game data, so these options only show on Forever. On retail,
the default map marks dungeon entrances itself.

### Unit frames

- **Health bars in class color:** the health bar of the player, target, target of target, focus and
  focus target frames takes the class color of the unit it shows, each frame switched on separately. The bar
  keeps the shading of the default green bar. Units without a clear class, like most NPCs (and the
  player frame while you're in a vehicle), keep the default bar.

### Chat commands

- **`/rl`** reloads the interface, as a short form of `/reload`. It's only added when neither the
  game nor another of your addons already uses `/rl`; then theirs stays.

### Viewport

Draws the game world in a smaller area and fills the margins with a color of your choice, so chat,
action bars or unit frames at the screen edges no longer cover the world. Set each margin (top,
bottom, left, right) in screen pixels; the world always keeps at least a quarter of the screen.
The margins stay when you hide the interface with Alt+Z.

### Action Bars

Reverse the direction buttons fill a bar, separately for every bar and both directions:

- **Vertical:** on a bar with several rows, the first row moves from the bottom to the top (or the
  other way round).
- **Horizontal:** button 1 starts at the right end of the row instead of the left.

Works for action bars 1 to 8, the stance bar and the pet bar, and keeps working after you change a
bar in Edit Mode.

## Settings

**Esc > Options > AddOns > Forever QoL**, or type `/fqol`. The Viewport, Action Bars and Minimap
pages are listed below Forever QoL. Changes apply right away; the few that touch protected parts of the
interface (action bars, viewport, system bar) wait until you leave combat.

Forever QoL is available in English and German.

## Good to know

- Forever QoL never replaces or hooks Blizzard's action bar, Edit Mode or tooltip code. It only
  moves the button slots of the bars you flipped, parents hidden frames to a hidden holder, and
  adds lines to tooltips. That keeps it clear of the "tainted by an addon" errors Midnight-era
  clients are strict about.
- Don't run it together with another viewport or action bar growth addon (for example Midnight
  Viewport or Action Bar Button Growth Direction): both would move the same frames.
- Other tooltip addons may show vendor prices too (Auctionator, for one); turn one of them off if
  you see the price twice.
- The same goes for other quest automation and minimap addons (Leatrix Plus, SexyMap and the like):
  use one of them for the same job.
