# Combat log, tooltips, chat, loot, bags and mail

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

The combat log can't be closed in the default UI, and the dock's own functions (`FCF_Close`,
`FCF_UnDockFrame`) write to the chat frames and the dock. So `ChatFrame2` goes to the hidden holder
and its tab is scaled down to 0.001: the dock gives every tab its parent, width and anchor again on
each update (each tab hangs on the right edge of the one before), but never its scale, so the tab
takes no room and the next tab closes the gap.

The vendor price line reads Shift (`IsShiftKeyDown`) once, while the tooltip data processor builds
the item tooltip, and QoL never listens for modifier changes or refreshes a tooltip itself: that
would call the game's tooltip rebuild (`RefreshData`, `SetBagItem`, ...) from insecure code, which
can blank tooltips holding secret lines. Bag, bank and merchant buttons rebuild their own tooltip
about every 0.2 s while hovered, so the line flips there anyway; a chat link or quest reward keeps
what it showed when it opened.

Classic Era (1.15) has no tooltip data processor: `Blizzard_SharedXMLGame.toc` loads
`TooltipDataHandler.lua` for every game type but vanilla. Its tooltips still run the scripts older
clients had, so there `Tooltips.InitScripts` hooks them (`HookScript`, which runs after the game's
own handler and leaves it in place) on `GameTooltip`, `ItemRefTooltip` and the two comparison
tooltips: `OnTooltipSetItem`, `OnTooltipSetSpell` and `OnTooltipSetUnit` add the ID lines (the item
from `GetItem`'s link, the spell from `GetSpell`, the NPC from `UnitGUID` of `GetUnit`'s unit), and
the item one the vendor price on `GameTooltip` and `ItemRefTooltip`. Quests, currencies and
achievements have no such script, so those IDs don't show there (Classic Era has neither of the
last two anyway). The game's own sell price comes from `OnTooltipAddMoney`, which the client runs
while it builds an item tooltip, before `OnTooltipSetItem`; the frame's handler
(`GameTooltip_OnTooltipAddMoney`) adds a `Sell Price: <money>` line, or a heading and two lines for
a price range. Lines can't be taken out of a tooltip, so the `OnTooltipAddMoney` hook notes which
line the game's is (`NumLines`; a range is kept, as on retail), and where QoL can price the item the
`OnTooltipSetItem` hook turns that line into the vendor line in place, after checking it still
starts with `SELL_PRICE` (another addon's money hook may have run first and added a line; then the
game's line stays and QoL adds none): the label in the line's left
font string (`<tooltip>TextLeft<n>`), the money in its right one, shown, then `Show()` to fit the
tooltip to the new text. Without a game line it adds its own line, as on retail. `OnTooltipCleared`
forgets the noted line, so one left over from an item tooltip the client gave up on can't be
rewritten in the next one. Classic Era hands out no secret values and these tooltips aren't
protected, so the hooks and the font string writes can't taint anything that matters there; on
Forever and retail, which have the data processor, none of this runs.
Classic Era has no `GetProcessingTooltipInfo`, so a stack's size comes only from the hovered
button's `count`, which Blizzard's item buttons carry (`SetItemButtonCount`); a bag addon's
button without it gets the price of one with Shift held too.

The tooltips Forever's controller interface shows for new buffs come from the buff frame
(`BuffFrameMixin:Update` queues each aura gained or refreshed, `ShowNextAuraForTooltip` shows it
for 4 seconds) in `BuffFrameTooltip`, which nothing else uses: pointing at a buff or selecting it
with the controller shows `GameTooltip`. So the option makes `BuffFrameTooltip` transparent
(`SetAlpha(0)`, again from an `OnShow` hook each time it shows), the way the game's controller
action bar editor hides its own tooltip (`GamepadActionBarEditFrameMixin`): the tooltip still shows
and hides as the game wants, only unseen. It first went to the hidden holder like the frames above,
where it never showed at all; on the Steam Deck, pointing at a buff then showed no tooltip either,
and after the game menu closed the cursor jumped to the middle as usual but stayed in sight
(2026-10, cause not found in the UI code; both gone with the alpha, confirmed 2026-10-11). The game has a
setting for it too, `GamepadShowAutoAuraTooltip`, which isn't in its options. It's left alone:
`CVarCallbackRegistry` caches it and the buff frame reads it on every aura change, and a
`SetCVar` from our code would fire `CVAR_UPDATE`, whose handler writes that cache without the
`issecure()` check its reads have. If that handler runs with our taint, every later read would taint
the buff frame's update, where right-clicking a buff calls `CancelUnitBuff`.

Names in chat in class color are the game's own setting: `chatClassColorOverride` "0" means always
(see `ChatFrameUtil.ShouldColorChatByClass`). Turning the option off gives the setting its default.

Faster auto loot touches no Blizzard frame: the loot window isn't hidden, moved or hooked. On
`LOOT_READY` it calls `LootSlot` for every slot, the last first, as Leatrix Plus does, and the game
leaves what it can't take in the window (full bags, a bind confirmation, a roll). It acts only when
the event's `autoloot` argument says the game auto loots. Leatrix compares the Auto Loot setting with
the auto loot key instead, which misses Forever's controller: tapping or holding the interact button
switches auto loot through `C_AutoLoot.SetUseAutoLootToggle`, and the event's flag has that too. The
event can come more than once for the same loot, so loot is taken at most once in 0.3 s (Leatrix's
throttle). While the option is off, nothing listens to `LOOT_READY` (`ns.Events:Off`).

Sort on open runs `C_Container.SortBags()`, the call behind Blizzard's sort button, when the player
opens their bags themselves. Nothing of Blizzard's is written or moved, and it stays taint-safe this way:

- It hears of an open from Blizzard's `ContainerFrame.OpenBag` EventRegistry callback, which
  `ContainerFrame_OnShow` triggers for every bag frame. The combined bag gets there too
  (`ContainerFrameCombinedBagsMixin:OnShow` calls `ContainerFrameTokenWatcherMixin.OnShow`, which calls it),
  so one callback covers the combined bag in both interfaces and separate bags, and no script of a
  frame is hooked. The frame's `GetID()` (a widget method) says which bag: from the backpack to
  `NUM_TOTAL_BAG_FRAMES` count, so the keyring (-1) and the bank bags don't. The combined bag has the
  backpack's ID (`OpenBag_Combined`).
- The game's own opens go through two globals: `OpenAllBags` for its windows and, in Forever's
  controller interface only, for a spell that targets an item (`CURRENT_SPELL_CAST_CHANGED`, which
  `ContainerFrameCombinedBagsMixin:InitializeGamepad` registers; the game doesn't open the bags for
  one otherwise), and `OpenAllBagsMatchingContext` for retail's enchants and its item upgrade, keystone and soulbind windows
  (`ItemButtonUtil.OpenAndFilterBags`; on Forever `ShouldOpenBagsForEnchantSelection` is false). The
  player's key bindings, bag bar, controller button and radial menu use `ToggleAllBags`, `ToggleBackpack`
  and `ToggleBag`, which reach the local `OpenAllBagsInternal` and `OpenBag` and pass through neither.
  So a `hooksecurefunc` on each of the two marks an open as the game's, without a list of windows that
  differs per client. These are hooks on global functions, not on a frame's methods: they run after
  the function, set a flag of ours and schedule a run. The run is scheduled there too because
  `OpenAllBags` shows nothing with a bag already open, and the flag has to go all the same, or the
  player's next open wouldn't sort.
- Every open schedules one `ns.Later` run on a frame of ours, so several separate bags opening at
  once give one sort, and the hooks, in the same call stack as the open, have run by then. The run
  clears the flag and stops if it was set, the option is off or the player is in combat. It's the form of
  `ns.Later` that also runs in combat: the plain one would catch up when combat ends, which this
  feature rules out, and `ns.LaterOutsideWindows` wouldn't sort until the bag closed, as the bag is a
  window that has the controller. `C_Container.SortBags` works outside a click or key press in both
  interfaces (in game, 2026-11-07). Blizzard's button plays a sound and its controller menu entry doesn't; this
  plays none. There is no wait between sorts and no check whether the bags changed; add a short
  wait only if a quick reopen turns out to give an error.

Known gaps, both rare, which stay as they are unless they turn out to matter:

- In the controller interface the professions window can open the backpack to point at a reagent
  (`OpenBagTo`, `OpenBackpack`), which passes through neither global, so a sort runs there and can
  move the item it points at.
- `ContainerFrame.OpenBag` comes with every show, not only an open. Swapping a bag with the combined
  bag open reopens it (`ContainerFrameSettingsManager:CheckReopenBags`, `OpenBag`), and showing the
  interface again with the bags open (Alt+Z) should show it too, so those sort as well.

The mail bookmarks are side tabs of ours on `SendMailFrame` (Blizzard shows it only on the Send Mail
tab, so the tabs come and go with it), made from `LargeSideTabButtonTemplate`, the template of
Forever's own side tabs (Collections, Inspect, Group Finder; its `common-sidetab` art has `-c60`
versions in Forever's client). A tab is 55 high, so six fit along the mail frame (424) below its
title bar; the first starts 60 below the frame's top right, as the Group Finder's do, each next one
2 below. Each is made without a parent and parented afterwards (SmartNavigation's `CreateFrame`
hook), and its icon is the `classicon-<class>` atlas (what `GetClassAtlas` gives, square class
portraits) of a character QoL has seen log in (`QoLDB.characters`, name and normalized realm in
lower case), else `Interface\MailFrame\Mail-Icon`, the mail frame's portrait. On Forever every
character has a surname and first names repeat (two characters can both be Scoopz), and
`UnitName` gives the surname as its second value, where retail gives the realm. So with
`RegionalUniqueNamesEnabled()` the player's name is both with a space between, as the game's
`NameUtil.FormatUnitNameForDisplay` writes it and as To takes it (a mail to Scoopz Scoopzi went
out, 2026-10-14); the first name alone matched no
bookmark (seen in game 2026-10-14). Names are compared with their spaces trimmed and runs of them
made one. The template's mixin
writes its own fields on our frame (the tooltip text, the icon's pressed offset) and shows
`tooltipText` on hover. A left click (`SetCustomOnMouseUpHandler`, let go over the tab) puts the
name in To with `SendMailNameEditBox:SetText` and gives `SendMailSubjectEditBox` the keyboard, the
widget methods the game's own Reply and the To box's Enter use, from `ns.Later` (in combat too: the
boxes aren't protected). `SetText` runs the box's `OnTextChanged` (autocomplete, which does nothing
for text that wasn't typed, and `SendMailFrame_CanSend`) from our call. Nothing on the mail frame is
hooked or written. `OpenMailFrame` sits 46 right of the mail frame (`MailFrame.xml`), so a letter
left open covers the tabs' right edge, mostly their transparent part.

The first tab is placed against `MailFrame`'s top right, not `SendMailFrame`'s: on Forever and
retail the Send Mail frame fills the mail frame, so it's the same place, but Classic Era's
(`Classic/MailFrame.xml`) is its old 384×512 art frame anchored top left inside a mail frame 338
wide (`ButtonFrameTemplate`), and against it the tabs hung 46 off the edge. Classic Era (1.15) also
has no `LargeSideTabButtonTemplate` (its Cooldown Viewer inherits it, but nothing there defines it),
so `CreateFrame` with it was an error each time a bookmark was saved. Where
`C_XMLUtil.GetTemplateInfo` doesn't know it, a tab is Classic Era's spell book side tab,
`SpellBookSkillLineTabTemplate` (a CheckButton, 32×32, in `Vanilla/SpellBookFrame.xml`, which
`Blizzard_UIPanels_Game` loads at startup): its icon is its `NormalTexture`, sized by the template
(the element is empty, so the mail icon is set with `SetNormalTexture` before `GetNormalTexture`),
its OnClick (the spell book's `SpellBookSkillLineTab_OnClick`) is replaced by ours on our frame,
which unchecks it and fills in To, and it shows `tooltip` on hover. The tabs are 17 apart, as the
spell book spaces them. The `classicon-<class>` atlases are in Classic Era too.
