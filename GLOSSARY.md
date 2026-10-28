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
