# QoL

A World of Warcraft addon of small quality-of-life changes, set up in a settings window of its own.

## Language

### Game clients

**WoW Forever**:
Blizzard's new game client of the original World of Warcraft, still in beta, with a controller interface
and changes of its own to the world (new boats and airships, new dungeons). The client QoL is made for;
**Forever** for short.
_Avoid_: Camelot, Forever classic, the beta (alone)

**Retail**:
The current World of Warcraft, Midnight (version 12). QoL also runs on it.
_Avoid_: Mainline, Midnight (except as the expansion's name), modern WoW

**Classic Era**:
The game client of the original World of Warcraft as Blizzard runs it today, version 1.15, with its
Era, Hardcore and Season of Discovery realms. One of the clients QoL runs on, next to WoW Forever and
retail.
_Avoid_: Classic (alone, as it also means the later classic clients such as TBC Anniversary and
Mists), Vanilla, 1.15

### Settings window

**Page**:
One entry in the settings window's list, with its settings shown beside the list when picked, such as
Minimap or Chat.
_Avoid_: category, tab, section

**Group**:
A header in the settings window's list over a few related pages, such as Maps over Minimap and World
map. A group shows only while it has a page the client can use.
_Avoid_: category, section

**Section**:
A header inside a page over a few of its settings, such as Shape on the Minimap page.
_Avoid_: group, category

**Table**:
Settings on a page laid out with a line per thing and a column per setting they share, such as the
Minimap page's elements (Position, Font size, Class color, Offset) or the Action Bars page's bars.
_Avoid_: grid, list

### Hidden settings

**Hidden setting**:
One of the game's own settings that the game's options don't show, or show with only part of the
range it takes, so otherwise it's reached only through `/console`. The game keeps its value, not QoL.
QoL's Graphics & Camera page is where they are changed.
_Avoid_: CVar (in player text), console command, advanced setting (the page's old name)

**Raid copy**:
The game's second copy of a hidden setting, used in raids and battlegrounds while the game's Raid and
Battleground graphics are on.
_Avoid_: raid setting, RAID CVar

**Game default**:
The value the game itself gives a hidden setting when nobody has changed it.
_Avoid_: default (alone, as QoL's options have defaults of their own), original value

**Draw distance**:
How far away the game draws the world and the objects in it. The Graphics & Camera page has a
section of that name for the hidden settings that change it.
_Avoid_: view distance (that's the game's own slider, which sets some of them), far clip

**Game slider**:
One of the game's own graphics sliders that sets several hidden settings at once whenever it's moved:
View Distance, Environment Detail and Ground Clutter.
_Avoid_: proxy, index CVar, Graphics Quality (that's the preset that moves all of them)

### Minimap

**Minimap element**:
Something around or on the minimap that the player can place on its own: the zone text, the clock, FPS
and ping, the addon compartment, the tracking button, the day and night icon, the calendar button, or
the coordinates. Each can be hidden through its Position.
_Avoid_: minimap feature, minimap widget

**Spot**:
Where an element's Position puts it: the game's own place, a row above or below the minimap, or a place
inside the map.
_Avoid_: position (that's the setting that picks the spot), slot, anchor

**Offset**:
A small shift of one element from its spot, across and up or down. It moves only that element; the
others stay where their spots put them.
_Avoid_: nudge, position, custom position

**Ping**:
The higher of the player's home and world latency, shown next to the FPS.
_Avoid_: latency (alone, as the game has two), lag, ms

### Tooltips

**Vendor price**:
What a merchant pays for an item, shown on its tooltip: for one item, or with Shift held for the
whole stack.
_Avoid_: sell price (that's the game's own tooltip line), merchant price

### Loot

**Auto loot**:
The game taking loot straight into the bags when a corpse or container is opened, without the loot window
waiting for a click. Whether it happens is the game's call: its Auto Loot setting, flipped by the auto
loot key, or on a controller by tapping or holding the interact button.
_Avoid_: autoloot, loot all

**Faster auto loot**:
Taking all of the loot at once when the game auto loots, instead of one item after another. When the game
doesn't auto loot, it changes nothing, and anything that can't be taken (full bags, a confirmation) stays
in the loot window.
_Avoid_: fast loot, instant loot

### Bags

**Sort on open**:
The game's own bag sort, run for the player each time they open their bags themselves. Bags the game opens
on its own (at a vendor, for a spell that targets an item) and bags opened in combat aren't sorted.
_Avoid_: auto sort, clean up

### Click casting

**Click casting**:
Using a spell or another action on a unit by clicking its unit frame, or pressing a key while the
mouse is over it, without targeting it first. QoL's own; the game has a feature of the same name that
takes only clicks.
_Avoid_: hover casting, mouseover casting, the game's Click Casting (that's Blizzard's own)

**Binding**:
A combination (a mouse button, the mouse wheel or a key, with any of Shift, Ctrl and Alt) and the
action it does on the unit frame it's used over.
_Avoid_: key binding (that's the game's Key Bindings, which work anywhere), click bind, keybind

**Quick bind**:
A mode of the Click casting page in which pointing at an action in the page's list and pressing a
combination makes a binding of them.
_Avoid_: quickbind mode, binding mode, Quick Keybind (that's the game's mode for action bar keys)

**Unit frame**:
A frame that shows a unit and can be clicked: the game's player, target, focus, pet, party, raid,
boss and arena frames, or another addon's that joins click casting. Nameplates aren't. All of it
counts: a binding works over its portrait, name and bars alike.
_Avoid_: raid frame (that's one kind), portrait

**Clash**:
Two bindings on the same combination that both work at once, because the character has both actions.
_Avoid_: conflict, duplicate (a binding that doesn't work for this character right now isn't one)

**Portrait hit text**:
The damage, healing and miss text the game flashes over the player's and the pet's portrait when they
take a hit or a heal.
_Avoid_: combat text (that's the floating combat text in the world), unit frame numbers

### Action bars

**Highest rank**:
The highest rank of a spell the character knows, not the highest that exists in the game.
_Avoid_: max rank, top rank

**Rank upgrade**:
Replacing a spell in an action slot with a higher rank of it.
_Avoid_: auto-rank, rank replace

**Downrank**:
Keeping a lower rank of a spell on the bars on purpose, such as a cheap Rank 1 Frostbolt to slow a target.
_Avoid_: low rank (that's any rank below the highest, kept on purpose or not), old rank

**Controller bar**:
One of the four bars on a page of the controller interface: Top (no trigger), Left, Right and Bottom (both triggers). Each has a D-pad half and a face button half; Top's face buttons are reserved by the game.
_Avoid_: gamepad bar, trigger bar

**Stance**:
Anything that makes the game swap in other actions: a warrior's stance, a druid's form, stealth.
_Avoid_: form (that's one kind of stance), bonus bar

**Following bar**:
A controller bar that shows its own actions while the character is in a stance.
_Avoid_: overridden bar (the game uses that for its own stance and possess bars), stance bar (that's the game's single bar)

**Trigger toggle**:
Pressing a trigger alone to switch its controller bar on until it's pressed again, so it doesn't have to be held. Holding a trigger and pressing a button still works as before.
_Avoid_: sticky triggers, trigger lock

**Bar on**:
The controller bar the trigger toggle has switched on, which Top goes back to being when it's switched off.
_Avoid_: active bar (that's the bar the game highlights, which stays Top), toggled bar

**Marker**:
The game's trigger glow on a frame of ours, behind the bar on and during a hold of a trigger, because the game's own highlight stays on Top.
_Avoid_: highlight (that's the game's)

### Player frame

**Status text**:
The numbers or percentage on a player frame bar, chosen by the game's Status Text setting.
_Avoid_: label, bar text

**Druid mana bar**:
The third bar on the player frame that shows a druid's mana while bear or cat form uses rage or energy.
_Avoid_: druid-only mana bar, alternate power bar (that's Blizzard's own third bar)

### Cooldown Manager

**Cooldown Manager**:
The game's own rows of icons and bars for the character's cooldowns and tracked buffs, set up in the
game's Edit Mode. Which spells it shows is the game's call; QoL changes only its look.
_Avoid_: cooldown viewer, CDM, cooldown bar

**Reminder**:
An icon shown while the character lacks a buff, gone once they have it. A buff of that name counts at
any rank and from any caster, and so does its group version. A reminder for a spell shows only on a
character that knows the spell.
_Avoid_: missing buff, tracker, custom spell, alert

**Preset**:
A reminder QoL comes with, such as Well Fed, as opposed to one the player adds. It can be switched off
but not removed, and it shows on every character.
_Avoid_: default reminder, built-in

**Reminder row**:
The row of QoL's own that the reminders show in, placed by the player. It isn't part of the Cooldown
Manager.
_Avoid_: reminder bar, tracker bar

**Group version**:
The buff that puts another buff on the whole group at once, such as Gift of the Wild for Mark of the
Wild. Having it counts as having the buff.
_Avoid_: equivalent, raid buff, greater buff

**Weapon buff**:
A temporary effect put on a weapon rather than on the character: a poison, a shaman's weapon spell
such as Rockbiter, a sharpening stone or an oil. The game doesn't count it as a buff.
_Avoid_: weapon enchant (alone, as that also means the permanent one), imbue, temporary enchant

### Group frames

**Group frame**:
One of the game's raid-style frames for a player in the party or raid: a raid frame, or a party frame
set to raid style. The classic party frames, pet frames and arena frames aren't.
_Avoid_: raid frame (a party frame can be one too), compact frame, unit frame (that's any clickable frame)

**Tracked buff**:
A buff the player chose to show as an icon on group frames, either while the member has it (a heal
over time) or while the member lacks it (a buff still to cast). QoL draws the icon; the game's own
buff icons on the frame are a separate thing.
_Avoid_: indicator, aura, reminder (that's the character's own missing buff, in the reminder row)

**Raid manager**:
The game's tab at the screen's edge that slides out with the group's controls: ready check, world
markers, group filters, convert to raid. It appears while in a group.
_Avoid_: raid frame manager, group manager, side panel
