# Forever QoL

**Small quality of life features for WoW Forever, in one addon.**

Forever QoL bundles the little things you'd otherwise install five addons for: a smaller 3D
viewport, action bars that grow the other way, junk selling and repairs at merchants, IDs and
vendor prices in tooltips, and switches to hide UI pieces you never click. Everything is set up in
the game's own options window. There's no minimap button.

It's made for WoW Forever and also runs on retail (Midnight).

## Features

### Merchant

- **Sell junk automatically:** every grey item in your bags is sold when you open a merchant. The
  chat tells you how many items went and for how much.
- **Repair automatically:** your equipment is repaired at every merchant who can repair.
- **Use guild funds:** repairs come out of the guild bank first, as far as your guild lets you
  withdraw. If that doesn't cover everything, your own gold pays the rest.

### Tooltips

- **IDs:** spell, item, buff and debuff, NPC, quest, currency and achievement IDs in their tooltips.
- **Vendor price:** what an item sells for, everywhere, not just while a merchant is open. For a
  stack in your bags you see the whole stack's price and the price of one.

### Interface

- **Hide the system bar:** the micro menu (character, spellbook, ..., game menu). Your key
  bindings still open everything, and in a vehicle the buttons still show on the vehicle bar.
- **Hide the bag bar:** the backpack and bag slots. Bag key bindings keep working.
- **Hide the coordinates under the minimap.**
- **Hide the social button** on top of the chat window.

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

**Esc > Options > AddOns > Forever QoL**, or type `/fqol`. The Viewport and Action Bars pages are
listed below Forever QoL. Changes apply right away; the few that touch protected parts of the
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
