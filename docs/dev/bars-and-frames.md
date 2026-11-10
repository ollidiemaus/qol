# Action bars, unit frames and hidden frames

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

The action bar flip copies the grid math of `ActionBarMixin:UpdateGridLayout` and applies it to the
bar's button containers only. Blizzard stores a new `oldGridSettings` table each time it lays a bar
out, so events are just wake-ups: a bar is laid out again only when that table changed since our
last pass (or the settings changed).

Hiding the button borders changes only the buttons' textures and child frames, with widget methods
(the buttons are protected, so ns.Later waits for the end of combat). The frame (`NormalTexture`)
gets alpha 0: the button shows and hides its state textures itself, and Blizzard's
`UpdateButtonArt` sets the frame's atlas again without touching its alpha. The icon loses its mask
(`RemoveMaskTexture(IconMask)`; nothing in Blizzard_ActionBar adds it again). The textures drawn for
the rounded frame (their atlases start with `UI-HUD-ActionBar-IconFrame`) get the classic square
ones from `Interface\Buttons`, which Forever's client still has: `ButtonHilight-Square`,
`CheckButtonHilight`, `UI-Quickslot-Depress`, `UI-QuickslotRed` and, centered at 62/36 of the
button like on classic buttons, `UI-ActionButton-Border`. A texture showing anything else (the pet
bar's `bags-newitem` spell highlight) is left alone, and so is one whose art Blizzard put back
until the next wake-up (`UpdateButtonArt` sets the pushed frame again when Edit Mode changes a bar's
art). The fill textures keep the size Blizzard gives them, only their anchors change. The swipe
cooldowns get the icon's anchors, the slot art and background move to sublevel -1, behind the
icon, and the casting and interrupt animations get alpha 0 (their animations only animate their
children; reparenting them would break their `GetParent()` calls). Turning the option off puts
back what was saved per button.

Hiding the Cooldown Manager's icon borders (`Features/CooldownManager.lua`, Forever only) changes one
texture per icon. The border is an unnamed `OVERLAY` texture in each of the four item templates
(`Blizzard_CooldownViewer/CooldownViewer.xml`), with the atlas `UI-HUD-CoolDownManager-IconOverlay`;
on the bar row it sits in the icon's own frame (`item.Icon`), not on the item. The game sets it in
the template and never touches it again, so it is found among the regions by its atlas, gets
`SetAlpha(0)`, and gets its former alpha back when the option goes off. The Cooldown Manager's code
runs partly in the game's secure environment and keys a table by secret aura instance IDs, so
nothing is written on a row or an icon: which border belongs to which icon, and each hidden
border's former alpha, live in weak-keyed tables of ours. The rows and icons aren't protected and a
texture's alpha may change in combat, so the pass runs in combat too (`ns.Later` with `true`).
A row keeps its icons in a pool (`row.itemFramePool`): `RefreshLayout` releases them all and
acquires as many as the row shows, building new ones as it grows. A hidden border stays hidden on a
pooled icon, so only new icons need a pass, and nothing but the rebuild says when there are any (it
runs from the game's settings, Edit Mode, auras and the row's `OnShow`). So each row's
`RefreshLayout` gets a `hooksecurefunc`, the one hook QoL has on a method of a Blizzard frame: the
hook is the game's own secure wrapper (the field stays secure, unlike a written one), it runs after
the rebuild, and all it does is ask `ns.Later` for a pass over `itemFramePool:EnumerateActive()` (a
read of the pool) from our own frame's OnUpdate. The hook's body does run inside the game's call
stack (a rebuild from `UNIT_AURA`, say), so it touches no game frame: it reads our option and calls
`ns.Later`, nothing else. The rows get no hook until the player turns the option on; a hook can't
be taken off, so it stays for the session and asks for nothing while the option is off. Turning
the option off restores every border in our table, also on icons a row isn't showing. Retail has
the same rows, but the page and the feature are Forever's for now, so `WOW_PROJECT_ID` gates them.
If the game loads `Blizzard_CooldownViewer` after QoL (`ADDON_LOADED`), the rows are picked up then.

Reminders (`Features/Reminders.lua`, Forever only; the terms are in the glossary) touch no
Blizzard frame. The reminder row is a plain frame of ours on `UIParent`, covering the screen's lower
half with the mouse off, and its icons are pooled frames of ours, centred in it in the presets'
order. It isn't the Cooldown Manager's: the game's rows are filled by its secure code from secret
aura data and keyed by secret instance IDs, so an icon of ours among them would taint them, and the
game decides what they show. Our frames aren't protected and nothing secure anchors to them, so
showing, hiding and laying them out in combat is allowed: the refresh is `ns.Later("reminders", ...,
true)`, which also folds a burst of `UNIT_AURA` into one pass per frame. An icon copies
`CooldownViewerBuffIconItemTemplate` (40 by 40, the `UI-HUD-CoolDownManager-Mask` mask, the
`IconOverlay` atlas 8 and 7 past the edges), and the overlay hides with the page's border option.
A preset's buff counts when a buff on the player has one of the names `C_Spell.GetSpellName` gives
for the preset's spell IDs (Forever's Spell table: Well Fed is thirty spells of one name, Well
Rested 1225478, Camp Benefits 1229741), so food, rank and locale don't matter. The names are cached
once the client has given them all. Forever withholds buff data in combat, and reading it there is
an error for tainted code rather than a secret value (see `forever-notes.md`), so a refresh asks
`C_Secrets.ShouldAurasBeSecret()` first and then checks each aura and name with `issecretvalue`;
either way the row hides and nothing read is kept. No event says the data is readable again, so
combat ending (`PLAYER_REGEN_ENABLED`) and `PLAYER_ENTERING_WORLD` ask for a refresh as well as the
player's `UNIT_AURA`. Those events are registered only while the switch and at least one reminder
are on, so with reminders off QoL hears nothing and does no work.

The Hide reminders checkboxes are `CONDITIONS` in the feature: an option, a test of the character's
state and the events that say it may have changed. A refresh asks each ticked one; resting
(`IsResting`, `PLAYER_UPDATE_RESTING`), combat (`InCombatLockdown`, on the combat events the row
hears anyway), mounted (`IsMounted`, `PLAYER_MOUNT_DISPLAY_CHANGED`) and dead or on a flight path
(`UnitIsDeadOrGhost` or `UnitOnTaxi`; `PLAYER_DEAD`, `PLAYER_ALIVE` (released, still a ghost),
`PLAYER_UNGHOST`, and `PLAYER_CONTROL_LOST` and `_GAINED` for taking off and landing, plus
`UPDATE_BONUS_ACTIONBAR`, on which the game's early-landing button asks `UnitOnTaxi`, in case it
turns true only after control is lost; not yet checked in game) leave the row empty. The maximum level one (`UnitLevel` against `GetMaxPlayerLevel`, `PLAYER_LEVEL_UP`) leaves out
only the presets marked `experience`; it also takes the level the event names, as the game may update
`UnitLevel` after it. A condition's events are heard only while its box is ticked and the row hears
anything at all. Forever withholds buff data in every fight (#108's in-game check), so "In combat"
changes nothing there today; left off, a buff lost mid-fight shows as soon as the data is readable.

The player's own reminders are `QoLDB.reminders`, account-wide: `{ spell = ID as dragged, on }` in
the order added. The ID only says which spell it is: the buff matches by the name the client gives
for it, so any rank on any character, and a character knows it when `IsSpellKnownOrInSpellBook` says
so for the ID, or for what `C_Spell.GetSpellIDForSpellIdentifier` answers for its name (the rank it
knows, as click casting asks; taken only if known, as an NPC spell can share the name). The answers
are kept until `SPELLS_CHANGED`, so a refresh on `UNIT_AURA` asks the spellbook nothing, and only an
own reminder whose spell is known makes the row listen: a warrior with only the druid's Thorns
reminder hears no `UNIT_AURA`. An entry without a spell ID (a newer QoL's) stays saved, out of the
row and the page. A drop is
the cursor's `"spell"` (its base spell ID); another rank of a spell in the list, or anything else,
does nothing and stays on the cursor. Group versions (`GROUP_VERSIONS`, Forever's IDs) add the group
spell's name to any reminder's set of names; Forever has only three Greater Blessings. While the list
has entries, `SPELLS_CHANGED` refreshes the row and tells the page (`Reminders.OnChange`), so
learning a spell shows its reminder and ungreys its line. The page's own lines are table lines made
as the list grows and reused: each shows the entry at its place, so removing one moves the rest up.
The page doesn't scroll, so a very long list runs past the window's bottom.

Rank upgrades (`Features/RankUpgrades.lua`, the terms are in the glossary) touch no Blizzard frame:
only action slots, through the game's API, so there's no taint to reason about beyond staying out of
combat, which `ns.LaterOutsideWindows` does, along with the controller windows. A slot is replaced
the way the game's controller bars place an action (`AssignActionToGamepadStandardSlot`):
`C_Spell.PickupSpell`, `PlaceAction`, `ClearCursor` for the old spell that lands on the cursor. So
the run needs an empty cursor; with one in use it waits for `CURSOR_CHANGED`, listening only then.

The rule on learning: the ranks learned since the last run (a set, kept while the run waits, so
ranks learned together are one step, in any event order) go to the highest of them, for the slots
holding the highest rank not in that set; nothing else moves. A rank learned below a known one
changes nothing. This is why nothing is saved per slot: a downrank is any slot below the previous
highest rank, and a rank dragged back counts as one from then on. The button ignores the rule and
the option.

Ranks come from the spell book: the Spell entries (not FutureSpell) with a digit in their subtext,
grouped by name, compared by that number. A subtext is missing until the game has loaded the
spell's data (`GetSpellBookItemInfo`'s `subName` documents it), so a run asks for what isn't cached
and tries again a second later, five times at most. So a spell of the same name that's not in the book never
counts, slots are looked up by spell ID only, and "highest" means highest known. The game's "Show
all spell ranks" filters only the book's window (`IsSpellBookItemLowRank` in
`Blizzard_SpellBookFrame.lua`), the book's data keeps every rank. `FindSpellActionButtons` with its
default set searches the keyboard and the controller bars (Blizzard asks it for
`Enum.ActionBarSet.Gamepad` for the latter), so no storage slot scan. Every slot it returns is
checked with `GetActionInfo`, so a macro casting the spell stays. `C_ActionBar.IsHighestSpellRank`
is only what tells a client with ranks: retail and Classic Era don't have it.

The class-colored health bars use only `SetStatusBarDesaturated` and `SetStatusBarColor` on the
unit frame's own bar (`frame.healthbar`): the default green texture is desaturated and then tinted,
so its shading stays. Blizzard sets `lockColor` on the player, target, target of target, focus and
focus target bars and never colors them itself, so a color stays until we change it. Who gets a class color
follows Blizzard's raid frames: `UnitIsPlayer` or `UnitTreatAsPlayerForDisplay`, with a known,
non-secret class (`UnitClass` is secret while a unit's identity is restricted). The bar's own
`unit` field says what it shows, so the player frame in a vehicle (`"vehicle"`) keeps its default.

Classic Era (1.15) is the exception: Blizzard sets `lockColor` there only on its arena frames
(`Blizzard_ArenaUI.lua`), so the player, target and other bars are recolored green on every value
change (`HealthBar_OnValueChanged`, run by `UnitFrameHealthBar_OnValueChanged`) and on every
`UnitFrameHealthBar_Update`. Its bars poll their health (`frequentUpdates`, `UnitFrameHealthBar_OnUpdate`
calls `SetValue`), so no event marks the change. So at Init each bar without `lockColor` (a read)
gets `HookScript("OnValueChanged", ...)`, which runs after the game's handler and, while that bar's
option is on or it shows a class color, only asks `ns.Later("classHealthBar<n>", ..., true)` to color
that one bar again (`ApplyBar`), in combat too; a colored bar is then tinted again within a drawn
frame. This runs on every health change of the target and focus, so the options that are on are kept
in a table the option watcher updates, and `colorBar` sets the desaturation and color only where
they differ. It asks for the client's lack of `lockColor`, not which client
it is, so Forever's and retail's bars (locked in their OnLoad) get no hook. Whether the game draws
the green for one frame before `Apply` runs (our OnUpdate may run before or after the bar's) is
for the in-game check. An `UnitFrameHealthBar_Update` that sets green without a new value (no
`OnValueChanged`) comes from the events `Apply` already follows (target and focus changes, login),
except `UNIT_MAXHEALTH` at unchanged health, rare enough to wait for the next health change.

Forever's player frame has a third bar only for the druid's astral power (moonkin), so bear and cat
form show no mana. The druid mana bar follows the rule of Blizzard's Wrath to Mists clients
(`AlternatePowerBar_UpdatePowerType`): the player's power isn't mana and `UnitPowerMax(mana)` is
above 0. It is drawn the way `PlayerFrame_ToPlayerArt` draws a third bar: a texture of ours with the
`AlternatePowerFrameTexture` atlas at its place on `PlayerFrameContainer` (not protected), and a
status bar of ours with the mana bar texture at the place and size of
`PlayerFrameAlternatePowerBarBaseTemplate`. The bar is a child of `PlayerFrameContentMain`, which is
protected, but the bar itself isn't, so it shows and hides in combat (druids shift in combat). On
Blizzard's frame only widget methods: the usual art (`FrameTexture`) gets alpha 0, which Blizzard
never sets (it only shows and hides it), and the threat glow (`FrameFlash`) gets the
`ClassResource-InCombat` atlas and its point, since the usual glow misses the third bar's border.
Blizzard sets the glow again in `PlayerFrame_UpdateArt` (entering the world, the vehicle events), so
those events are wake-ups. When the bar hides, the glow gets the usual atlas back only while the
frame shows the player (not a vehicle), Blizzard has no third bar of its own, and the glow still has
ours. The bar stands aside for Blizzard's own third bar (`activeAlternatePowerBar`, moonkin on
retail) and for a shown `classPowerBar` (retail's combo points sit where it goes), unless that class
bar is the Personal Resource Display's.

`PlayerFrame.classPowerBar` doesn't mean "on the player frame". Every `ClassPowerBar` writes it in
`Setup`, so the last one wins, and the display's bar keeps doing that once it is built (the first time
the display shows, also in Edit Mode). Forever has no class bar on the player frame, its combo points
are around the target portrait, so the one it reports is always the display's, shown while the power
is energy. So the test is the bar's parent, the display's `ClassFrameContainer`. Not the bar's
visibility, or our bar would vanish in cat form when the display shows in combat, and not the player
frame's own managed container, since retail's layout may nest that frame and a wrong answer there puts
our bar over the combo points. On retail the display's bar can hide the real one from that field, so
a shown `DruidComboPointBarFrame` stops our bar too. Forever doesn't load that frame, and the display's
setting to hide class info on the player frame hides it, which brings our bar back.

Left as they are:
the rage or energy bar's mask (Blizzard switches it to `Unit_BarMask` for a third bar; the two differ
by a pixel the frame art covers) and the bottom managed container (pet frame and the like), which
Blizzard moves 10 down for its third bar. The text follows `TextStatusBar`: `statusText` shows it
always or on hover, `statusTextDisplay` picks numbers, percent or both.

The mana bar costs nothing while it hides and little on a mana tick. A "player" listener made at
Init hears `UNIT_DISPLAYPOWER`, `UNIT_MAXPOWER` and the vehicle events; `UNIT_POWER_FREQUENT` goes
on it in `Apply` when the bar shows and off when it hides, so with the option off, as a non-druid
and in caster and travel form no mana event reaches QoL. A tick sets the value (passed as it
is, never compared: it can be secret) and only the texts that changed, so with Status Text off and
the bar not hovered it sets no text. The range is set in `Apply`, which `UNIT_MAXPOWER` wakes. The
two Status Text CVars are read in `Apply` while the bar shows (so also when it is made and when it
comes back) and on `CVAR_UPDATE` for them, not on a tick: the game's Status Text dropdown sets both
with `SetCVar`, which fires it, but a value that arrives another way, as at login, doesn't.

On Forever a druid's mana is secret in bear form, in and out of combat (its maximum isn't, but the
text checks it with `ns.IsUsable` too and handles it the same way if that changes; `ShouldShow` then
hides the bar at the next `Apply`), so the text can't come from sums. On that path the mana goes through `AbbreviateLargeNumbers`, and the percentage comes from
`UnitPowerPercent` with `CurveConstants.ScaleTo100`, and both reach the font string through
`SetFormattedText`; the API docs allow secret arguments there in tainted code. `AbbreviateLargeNumbers`
hands back a secret string, so its result isn't tested either (no `x and y or z`). The specs can't
catch that one: plain Lua has no hook for a truth test. A secret text can't be compared, so it is set
on every tick, nothing of it is kept, and the next usable text is set in turn. This percentage
rounds to nearest while `TextStatusBar` rounds up, so it can read 1% lower; a curve to match isn't
worth it. Clients without secret values keep the computed percentage and never touch those two
globals.

Every Edit Mode frame is clamped to the screen (`EditModeSystemTemplate`), and Edit Mode makes the
clamped rectangle the frame's selection box: `EditModeSystemMixin:UpdateClampOffsets` sets the clamp
insets from the frame's edges to its `Selection`'s. That box takes in the empty space around the
art, so the art can't reach the edge. Frames past the screen edge gives each frame Blizzard's insets
moved 30 further in on every side (in the frame's own units, so a frame shown bigger may go further),
with `SetClampRectInsets`, a widget method, on the frames of
`EditModeManagerFrame.registeredSystemFrames` (a field read). Nothing else is needed for saving:
`UpdateSystemAnchorInfo` saves a dragged frame's anchor from `GetPoint`, past the edge or not.
Blizzard sets its insets again whenever it lays a frame out (`UpdateSystem`, `UpdateSystemSetting`,
`HighlightSystem`; 0s for a frame not laid out yet): on `EDIT_MODE_LAYOUTS_UPDATED` (a layout loaded
or switched; AutoSetup's `SelectLayout` goes through `C_EditMode.SetActiveLayout`, which fires it,
since that's how the new layout gets applied), on leaving Edit Mode (`ExitEditMode` calls
`RevertAllChanges`, which applies the saved layout again), `PLAYER_SPECIALIZATION_CHANGED`, and in
Edit Mode on a highlight or a setting change, without an event. So the events are wake-ups, and
between `EditMode.Enter` and `EditMode.Exit` (EventRegistry) a frame of ours compares the frames
ten times a second (and on the first frame it shows) while the option is on: each comparison reads
every frame's rect and its selection box's. The insets are always worked out from the selection box,
whatever Blizzard set; a frame that has them already is left alone. That check makes no garbage of its own:
insets go around as four numbers (multiple returns), never tables, the watcher and the schedule
helper call one function defined at file scope, and a frame anchored again reuses its own copy of
its anchors.

New insets alone don't bring back a frame the game already pulled in: the first version set them a
frame after Edit Mode closed, and everything placed past the edge stayed on the screen (seen
2026-10-12). Leaving Edit Mode anchors every frame again under Blizzard's insets, the game lays them
out inside the screen, and as far as we can tell a change of insets alone doesn't lay a frame out
again (not yet confirmed in game). So a frame whose insets
we changed is anchored again at the points it has, which makes the game lay it out under the new
ones. That uses the widget's own `ClearAllPoints` and `SetPoint`, from the frame's metatable:
`EditModeSystemMixin:OnSystemLoad` replaces both on its frames with Lua that writes to the frame
(`SetSnappedToFrame`, `ClearFrameSnap`), which would taint it; the same points again leave its snap
bookkeeping right. A frame being dragged (`isDragging`, a field read) is left to the drag. Turning
the option off gives the frames we changed Blizzard's insets back and anchors them again, so they
come back inside the screen. Several frames are protected, so `ns.Later` waits for the end of combat
(Edit Mode can't open in combat anyway).

Portrait hit text (the damage, heal and miss text over the player's and the pet's portrait) has no
setting of the game's. The player frame's `HitIndicator.HitText` and the global `PetHitIndicator`
font strings go to the hidden holder like the frames above. `CombatFeedback_OnCombatEvent` calls
`Show()` on the text on every hit, and the fade (`CombatFeedback_OnUpdate`) only runs while it
`IsVisible()`, so under the holder nothing shows and the fade does nothing. Text left shown when the
option is turned off is hidden by that fade on the next drawn frame, since its time is up. No
Blizzard function is hooked and the frames' events and scripts stay theirs. Font strings aren't
protected, but the change goes through `ns.Later` like the other HideFrames options. Forever has no Camelot copy of this code;
its player and pet frames use Mainline's `CombatFeedback`.

Classic Era (1.15) names two of these frames differently, so `HideFrames.TARGETS` takes whichever
the client has, the same way. It has no Quick Join: the social button by its chat is
`FriendsMicroButton` on `ChatFrame1ButtonFrame` (`Blizzard_ChatFrameBase/Classic/FloatingChatFrame.xml`),
which the Hide the social button option hides instead of `QuickJoinToastButton`. Its player frame is
the old one, without `PlayerFrameContent`: the player's hit text is the global `PlayerHitIndicator`
font string straight on `PlayerFrame` (`Blizzard_UnitFrame/Classic/PlayerFrame.xml`), next to the same
`PetHitIndicator`. The micro menu (`MicroMenuContainer`), the bags bar and the chat menu and channel
buttons have the same names there; it has no voice buttons, which are skipped as missing.

Quests on Classic Era: its quest greeting (`QUEST_GREETING`, the old list of quests) has no quest
IDs: there's no `GetActiveQuestID`, and `GetAvailableQuestInfo` returns only isTrivial, isDaily,
isRepeatable and isLegendary (`Blizzard_UIPanels_Game/Classic/QuestFrame.lua`). Where
`GetActiveQuestID` is missing, `Quests:OnQuestGreeting` keys the quests it opened by their title
(`GetActiveTitle`, `GetAvailableTitle`) instead of their ID, so each still opens once per NPC.
`QUEST_ACCEPTED` there carries the quest log index before the quest ID, so the handler takes the
second value when there is one. Accepting or turning a quest in forgets its ID and, there, its title
(`C_QuestLog.GetQuestInfo`), so a repeatable turn-in
opens again at the same NPC. The gossip window (`C_GossipInfo`) has quest IDs there as everywhere.
