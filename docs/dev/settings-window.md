# Settings window

Part of the [developer notes](../DEVELOPMENT.md); their rules for touching Blizzard frames apply here.

The settings are a window of our own (`UI/SettingsWindow.lua`), `QoLSettings`, which `/qol` opens and
closes. Under Options > AddOns there's only the information page (`UI/InfoPage.lua`), with a button
that opens the window. Until 2026-10 the pages were canvases below that page in the game's settings;
they moved out because the game, on Forever with the controller interface on, froze now and then when
its settings closed after a change in them (below). Out there, nothing of ours runs while the game's
settings are open, and closing our window is a plain `Hide` of a frame of ours.

- The window is `ns.NewWindow` (`Core/Window.lua`) with
  `PortraitFrameFlatTemplate`: the game's portrait frame, whose `UI-Frame-Metal-*` border and portrait
  corner Forever draws in bronze, with the flat dark background of the game's settings
  (`FlatPanelBackgroundTemplate`). Inside, it copies the game's `SettingsPanel`
  (`Blizzard_SettingsPanel.xml`, 920×724) without the Game and AddOns tabs, the search box and the
  buttons below: 920×696, `Options_InnerFrame` (886×618, at its own size) 60 below the top instead of
  64, the list (199 wide) 12 below that, and the page right of it, 16 from the list and 22 from the
  window's right edge, 665×601, the room the game gives a canvas (`SettingsPage.MAX_HEIGHT` is 600).
  Forever's client has `-c60` versions of the options art (`options_innerframe-c60`,
  `options_categoryheader_1-c60`, `options_list_hover-c60`, the tabs and the divider) that no UI
  code names, as it has for the metal frame: the client swaps them in for the plain names, which is
  what we use. `options_list_active` has none.
- Classic Era (1.15) has no `PortraitFrameFlatTemplate` (Forever's and retail's shared templates
  have it, Classic Era's `Classic/SharedUIPanelTemplates.xml` doesn't): `CreateFrame` with it is an
  error there, which kept the window, and with it `/qol` and the information page's button, from
  being built at login. Where `C_XMLUtil.GetTemplateInfo` doesn't know it, the window is the plain
  `PortraitFrameTemplate`, which Classic Era has with the same `SetTitle`, `SetPortraitToAsset` and
  `CloseButton`, in Classic Era's own frame art and rock background. The options art inside
  (`Options_InnerFrame`, the list's atlases) exists there too.
- The Ring and Click casting pages' editors (`Features/RingPicker.lua`) have a Classic Era path for
  what Forever's and retail's spell book is built on, each taken where the newer one is missing:
  - Tabs: the game's tab system (`TabSystemTopButtonTemplate`) is only in the shared XML of TBC
    Anniversary and later clients, and `CreateFrame` with it is an error on Classic Era. Where
    `C_XMLUtil.GetTemplateInfo` doesn't know it, a tab is Classic Era's `PanelTopTabButtonTemplate`
    (its `TabButtonTemplate`, the help window's top tabs), sized with `PanelTemplates_TabResize`
    and selected with `PanelTemplates_SelectTab`/`DeselectTab` (a selected tab is disabled, as in
    the tab system), its click our `ShowKind`. The panel functions find its art by parent key, but
    the template also names it `$parentLeft` and so on, so each tab gets a name of ours
    (`QoLPickerTab<n>`) for those names to start with.
  - Spells: Classic Era has no skill lines (`C_SpellBook.GetNumSpellBookSkillLines`). Its spell
    book is read by tab and slot instead, as its own spell book does (`GetNumSpellTabs`,
    `GetSpellTabInfo`, `GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)`, `IsPassiveSpell`): `SPELL`
    slots only (not `FUTURESPELL`), no passives, no hidden or off-spec tab. The client hands out the
    ranks its spell book shows, so the game's "Show all spell ranks" decides whether lower ranks
    are listed.
  - Ring slots: Forever's `CircleMask` atlas isn't in Classic Era; its own circle mask is
    `CircleMaskScalable`.
  - Toys: Classic Era has no toy box (`C_ToyBox`, `PlayerHasToy`), so the list has no Toys tab
    there. A ring that already holds a toy (saved on another client) leaves it out as one the
    character doesn't have, and keeps it; the toy calls are behind a check all the same.
  The click casting engine needs nothing of its own: Classic Era's unit frames are the same
  `PlayerFrame`, `TargetFrame`, `PartyFrame` pool and boss frames.
- On Classic Era the pages offer only what changes something there. Each check asks the client for
  the thing the option works on, not which client it is: a row whose frame or system is missing is
  left out, and a section whose rows all are with it.
  - Combined bags (`ContainerFrameCombinedBags`): Classic Era has only the separate bags.
  - Mana in bear and cat form (`PlayerFrame.PlayerFrameContainer`): Classic Era's player frame is the
    old one, without the art container the bar is drawn into; QoL doesn't draw a bar of its own
    there. The Player frame section keeps the portrait hit text.
  - The calendar button (`ToggleCalendar`): Classic Era has no calendar; its `GameTimeFrame` is the
    time of day icon, which the day and night row moves instead (see the minimap notes).
  - The addon compartment's place (`AddonCompartmentFrame`) and the Coordinates section
    (`MinimapCluster.MinimapContainer.PlayerCoords`): Classic Era's minimap has neither.
  - Guild bank repair (`GuildBankFrame_LoadUI`, which Blizzard_GuildBankUI's bootstrap defines at
    startup on Forever and retail): Classic Era has no guild banks; its merchant frame names
    `CanGuildBankRepair` only in a button that is never shown. `Merchant:Repair` asks the same check
    before the guild bank calls, so a guild repair saved on another client pays with own gold
    there. Junk selling and own gold repairs work as everywhere.
  - The controller's buff tooltips and back buttons are on the Controller page, which only Forever
    (with `GamepadMainActionBarFrame`) lists.
- The list is drawn as the game's (`Blizzard_CategoryList`) but with frames of ours, not its
  templates: `SettingsCategoryListButtonMixin` reads its scroll box's element data and a file local
  of the game's settings. A header (`Options_CategoryHeader_1`, drawn on the list itself so the
  buttons go over its art, "Settings" in `GameFontHighlightMedium` at 20), then a button per page,
  175×20, 2 apart, its name at 36: gold (`GameFontNormal`), white on `Options_List_Active` when
  selected, `Options_List_Hover` under the mouse. A click selects with the game's sound.
- One page is shown at a time; the window refreshes it when it shows it (a selection, or the window
  opening on the page it was on), and a page follows `Options:Watch` while visible.
- Escape closes the window, other keys go on to the game (`ns.NewWindow`): not through
  `UISpecialFrames` or `RegisterGameMenuEscHandler`. The window opens in combat too. Keeping a key (`SetPropagateKeyboardInput(false)`) is restricted
  in combat, so there every key goes on to the game, Escape too, and the X closes the window; after
  Escape closed it, keys are let through again from the next frame (`ns.Later`), so the window never
  opens in combat holding the keyboard.
- The information page's button opens the window through `ns.LaterOutsideWindows`: with keyboard and
  mouse on the next frame, over the game's settings (we can't close them: hiding `SettingsPanel` from
  addon code taints its `Commit`), and Escape closes them first, then ours. In Forever's controller
  interface only once the game's settings and menu are closed, as Easy Controller's window does: they
  have the controller while open, so its cursor couldn't get to ours, and nothing of ours runs while
  they're open. A line next to the button says so while that interface is on (checked on each
  showing, as it switches without a reload).
- The information page is a short introduction, the button, the chat commands, and the author's
  other addons with their icon (copies in `Media/`), an Installed label while one is loaded (checked
  on each showing, as addons that load after us aren't loaded when the page is made) and their link
  in a read-only edit box to copy, as the game can't open web pages. It has no options, so no Defaults
  button. It doesn't scroll: it's about 540 high, within `SettingsPage.MAX_HEIGHT`, with two lines of
  text per addon (the tests can't measure wrapped text, so this one isn't checked). Not yet tried in
  Forever's controller interface: what a press on a link box does (an `EditBox` takes the keyboard
  focus).
- All frames (the window, the pages, the information page) are made on `ADDON_LOADED`, never while a
  window of the game has the controller, so SmartNavigation's `CreateFrame` hook rebuilds no window
  for them.

The options are grouped by part of the game: Automation (merchant, quests and loot), Interface
(the bars to hide, the combined bags, tooltips, health bars), Chat (the chat window, `/rl`), Mail
(the bookmarks' names), Action Bars, Minimap, World map (only where `MapPins.IsAvailable()`), Viewport, Ring, Click casting, Controller (only
on Forever) and Advanced settings ([`advanced-settings.md`](advanced-settings.md)). Every page is built by `UI/SettingsPage.lua`: two columns of rows, or rows across the
page (`"wide"`, the Viewport page, as its sliders need the room, and the World map page, with two),
or an option in the title bar instead of the Defaults button (`"title"`, the Ring page's switch,
with the rings' editor below it, and the Click casting page's, with the bindings' editor), each an option's name with a control from the game's own
templates (`SettingsCheckboxTemplate`, `WowStyle2DropdownTemplate`,
`MinimalSliderWithSteppersTemplate`, `ColorSwatchTemplate` opening `ColorPickerFrame`,
`InputBoxTemplate` for a name), so they look like the game's pages and fit without scrolling
(`SettingsPage.MAX_HEIGHT`, checked by the tests). Every input box (a text row's, a slider's with
`textBox`) is built by one helper and behaves the same: what's typed is set when the box loses the
keyboard (Enter, Tab, a click elsewhere), and then, and on Escape, the box shows what the row has
again; Tab goes on to the page's next box through the template's own `nextEditBox` and
`previousEditBox`. A refresh leaves a box alone while it has the keyboard, and greys a disabled
box's text, which the game doesn't. A text row trims what's typed. A slider's box (the Advanced
page's, in place of the slider's value text) takes a number, set through the slider so it goes
where a dragged value does: rounded to the row's `step`, out of range to the nearest end, and
anything else, or a number that rounds to the value, sets nothing. It shows as many decimals as the
step. A fractional step (Max camera distance's 0.1) rounds through those decimals, so stepping or
typing never sets a value like `1.9000000001`, and halfway rounds up with room for float error
(`2.05` is `2.1`, though `(2.05 - 1) / 0.1` comes out just under 10.5). Typing into either kind in
Forever's controller interface (the Steam Deck's on-screen keyboard) isn't tried yet.
A page can start with a few lines that say what its options are for (`Page:Text`, the Mail page's):
the font string gets the column's width from `SettingsWindow.PAGE_WIDTH`, so its wrapped height
(`GetStringHeight`) is known while the page is built, before the window lays it out.
A section that follows another one in its column gets 16 more above its header, so a page reads
as groups rather than one long list, and sections side by side start at the same height where the
columns' rows would leave their headers out of line (`Page:Align`: the Minimap page goes in pairs).
All names use one font: the game's list draws dependent options smaller. A page resets with its own
Defaults button, which asks with a second click: the game's confirmation dialog would spread taint.
The game's "all settings" reset doesn't reach our pages any more, and they don't show up in the
settings search. Tooltips are `GameTooltip`.
A row with a value (all but key bindings and buttons) gets, sets and resets it with functions of
its own (`control.get`, `control.set`, `control.reset`), and the Defaults button calls each row's
`reset`, handing all of them one table for that click (`done`), so that rows which reset the same
thing (a game slider) do it once. Given an option's key, a row is backed by `ns.Options` and the
page follows `Options:Watch`; given `{ get, set, reset }` instead, it's backed by a value kept
elsewhere, which the page reads whenever it refreshes. `get` gives what the control shows: a
checkbox wants `true` or `false`. A row made with the `resetButton` option ends with a Reset button
(`UIPanelButtonTemplate`, at the row's right end, so they line up below each other) that calls just
its own `reset`, greyed out while the backing's `isDefault()` says it's already there; its tooltip
(`resetTooltip`) shows while it's greyed out too.

The history below is from the time the pages were in the game's settings; the workarounds it led to
stay since they cost nothing.

No page is the game's vertical list (`RegisterVerticalLayoutSubcategory` with proxy settings).
Viewport was one, with sliders and a color swatch, and on Forever with the controller interface on
the game stopped responding (no Lua error, no Errors folder) when the settings closed after that
page had been shown, whichever page was open when closing, even with nothing changed. The canvas
pages closed fine. The list's slider and swatch controls bring controller wiring of their own
(SmartNavigation focus overrides, a prompted binding footer for the D-pad on `UIParent`); the line
that hangs wasn't found, so we stay off the list. On our canvas the controller cursor reaches the
slider's arrows (one pixel a click) and the swatch; a slider set from `Options` (a refresh) doesn't
write itself back.

The game's dropdown menu froze it the same way: with the controller interface on, opening one of
our dropdowns (the back buttons' bar on the Controller page), picking a choice and closing the
settings stopped the game. In that interface the menu (`Blizzard_Menu`) brings the same kind of
wiring as the list's slider: `MenuProxyMixin:SetupGamepad` creates a prompted binding footer whose
binding groups take the face buttons while it's open, and `GamepadFrameControlsManager` suspends
the settings panel's focus for it (`MenuProxy.OnShow`) and never unsuspends it on close. Which of
these hangs isn't known (the game's own pages open the same menu), but it is the one thing of the
game's controller wiring our pages used, and it was the step that turned closing into a freeze. So with the
controller interface on (`ns.IsControllerUI()`, checked on each click so switching interfaces needs
no reload), our dropdowns never open the menu: `Page:Dropdown` replaces `OpenMenu` on our own
dropdown with a step to the next choice, wrapping around, for the controller cursor's press, the
mouse and the touch screen alike. The mouse wheel's step (`Rotate`) opens no menu either and stays.
With keyboard and mouse the menu opens as usual.

Without the menu the game still froze now and then on closing the settings after the back buttons'
bar had been changed (not reproduced reliably, and with no error). Our change then ran while the
settings were open: new `action` attributes on our secure buttons and new override bindings, set
while `GamepadFrameControlsManager` had the settings as its window, and again on the
`UPDATE_BINDINGS` that closing fires. So the back buttons and the rings, the only features that set
bindings or secure attributes in the controller interface, change nothing while a window of the
game has the controller: they go through `ns.LaterOutsideWindows` (`Core/Later.lua`), which holds
their updates while `ns.ControllerWindowOpen()` (`GamepadMode.FrameControlsManager:GetActiveFrame()`,
if shown: the settings, the game menu, the bags...). Bindings already set stay while a window is
open (they aren't priority overrides, so the window's own win); only changes are held back. A
`C_Timer.After` check every half second lets them go once one check found no window and the one
before found none either, so they run at least half a second after the window closed, from our
OnUpdate, whatever order the game closes it in. Without the controller interface they run on the
next frame as before. With this the back buttons froze it no more (2026-10, Steam Deck).

Then it froze again after the buff tooltips' option was turned on (a `SetParent` of
`BuffFrameTooltip` while the settings were open). Holding every `ns.Later` request while the settings
or the game menu were open didn't stop it: toggling that checkbox off and on and closing froze it
with nothing of ours changed, and so did toggling the game's own Invert X Axis checkbox on its
Controller page (2026-10-11, Steam Deck). So the freeze is most likely Forever's own, on closing the
settings after a change in the controller interface, and no rule of ours prevents it; the hold was
dropped again, as it only took away live changes. The workarounds above (canvas pages, dropdowns
that step, the back buttons waiting for windows) stay since they cost nothing, but they probably
weren't the cause either. Not yet tried: the same with all addons off, which would rule out taint.
