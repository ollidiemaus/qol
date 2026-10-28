# QoL

A World of Warcraft addon of small quality-of-life changes, set up in a settings window of its own.

## Language

### Hidden settings

**Hidden setting**:
One of the game's own settings that the game's options don't show, or show with only part of the
range it takes, so otherwise it's reached only through `/console`. The game keeps its value, not QoL.
QoL's Advanced settings page is where they are changed.
_Avoid_: CVar (in player text), console command, advanced setting (that's the page, not one setting)

**Raid copy**:
The game's second copy of a hidden setting, used in raids and battlegrounds while the game's Raid and
Battleground graphics are on.
_Avoid_: raid setting, RAID CVar

**Game default**:
The value the game itself gives a hidden setting when nobody has changed it.
_Avoid_: default (alone, as QoL's options have defaults of their own), original value

**Draw distance**:
How far away the game draws the world and the objects in it. The Advanced settings page has a
section of that name for the hidden settings that change it.
_Avoid_: view distance (that's the game's own slider, which sets some of them), far clip

**Game slider**:
One of the game's own graphics sliders that sets several hidden settings at once whenever it's moved:
View Distance, Environment Detail and Ground Clutter.
_Avoid_: proxy, index CVar, Graphics Quality (that's the preset that moves all of them)

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
boss and arena frames, or another addon's that joins click casting. Nameplates aren't.
_Avoid_: raid frame (that's one kind), portrait

**Clash**:
Two bindings on the same combination that both work at once, because the character has both actions.
_Avoid_: conflict, duplicate (a binding that doesn't work for this character right now isn't one)
