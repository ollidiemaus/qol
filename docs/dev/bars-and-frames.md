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
retail) and for a shown `classPowerBar` (retail's combo points sit where it goes). Left as they are:
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
two Status Text CVars are read when the bar is made and on `CVAR_UPDATE` for them, not on a tick:
the game's Status Text dropdown sets both with `SetCVar`, which fires it.

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
