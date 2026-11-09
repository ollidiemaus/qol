local _, ns = ...
local L = ns.L
local Options = ns.Options

-- Quality of Life's settings: a window of our own (UI/SettingsWindow.lua), which /qol opens, with a
-- page for each part of the game, in groups: General (Automation, Chat, Mail), Display (Interface,
-- Unit Frames, Action Bars, Viewport), Maps (Minimap, World map on Forever's maps), Input (Ring, Click
-- casting, Controller on Forever, which has the controller action bar) and System (Graphics &
-- Camera, the game's hidden settings).
-- Under Options > AddOns there's only the information page (UI/InfoPage.lua), with a button that
-- opens the window. The game's settings have nothing of ours to change: on Forever, with the
-- controller interface on, the game stopped responding now and then when they closed after a
-- change (see docs/dev/settings-window.md). The pages read and write ns.Options, and the features react
-- through Options:Watch; the Graphics & Camera page reads and writes the game's own values through
-- ns.HiddenSettings.
local SettingsPanel = {}
ns.SettingsPanel = SettingsPanel

local VIEWPORT_MAX_MARGIN = 600

-- For the pages' enabled predicates.
local function is(key)
    return function() return Options:Get(key) == true end
end

-- Automation page: what's done for you at merchants, with your bags, at quest givers and with loot.
local function buildAutomation(page)
    page:Header("left", L.SECTION_MERCHANT)
    page:Checkbox("left", "sellJunk", L.SELL_JUNK, L.SELL_JUNK_TIP)
    page:Checkbox("left", "autoRepair", L.AUTO_REPAIR, L.AUTO_REPAIR_TIP)
    -- Classic Era has no guild banks.
    if ns.Merchant.HasGuildBank() then
        page:Checkbox("left", "guildRepair", L.GUILD_REPAIR, L.GUILD_REPAIR_TIP,
            { indent = true, enabled = is("autoRepair") })
    end

    -- Classic Era has no C_Container sort.
    if ns.SortOnOpen.IsAvailable() then
        page:Header("left", L.SECTION_BAGS)
        page:Checkbox("left", "sortOnOpen", L.SORT_ON_OPEN, L.SORT_ON_OPEN_TIP)
    end

    page:Header("right", L.SECTION_QUESTS)
    page:Checkbox("right", "questAccept", L.QUEST_ACCEPT, L.QUEST_ACCEPT_TIP)
    page:Checkbox("right", "questTurnIn", L.QUEST_TURN_IN, L.QUEST_TURN_IN_TIP)

    page:Header("right", L.SECTION_LOOT)
    page:Checkbox("right", "fasterAutoLoot", L.FASTER_AUTO_LOOT, L.FASTER_AUTO_LOOT_TIP)
end

-- Interface page: the bars to hide and Edit Mode on the left, tooltips on the right.
local function buildInterface(page)
    page:Header("left", L.SECTION_HIDE)
    page:Checkbox("left", "hideMicroMenu", L.HIDE_MICRO_MENU, L.HIDE_MICRO_MENU_TIP)
    page:Checkbox("left", "hideBagsBar", L.HIDE_BAGS_BAR, L.HIDE_BAGS_BAR_TIP)

    page:Header("left", L.SECTION_EDIT_MODE)
    page:Checkbox("left", "pastScreenEdge", L.PAST_SCREEN_EDGE, L.PAST_SCREEN_EDGE_TIP)

    page:Header("right", L.SECTION_TOOLTIPS)
    page:Checkbox("right", "tooltipIDs", L.TOOLTIP_IDS, L.TOOLTIP_IDS_TIP)
    page:Checkbox("right", "tooltipSellPrice", L.TOOLTIP_SELL_PRICE, L.TOOLTIP_SELL_PRICE_TIP)
end

-- Unit Frames page: the player frame on the left, the health bars in class color on the right.
local function buildUnitFrames(page)
    page:Header("left", L.SECTION_PLAYER_FRAME)
    -- Classic Era's player frame has no art for the druid mana bar.
    if ns.DruidManaBar.IsAvailable() then
        page:Checkbox("left", "druidManaBar", L.DRUID_MANA_BAR, L.DRUID_MANA_BAR_TIP)
    end
    page:Checkbox("left", "hidePortraitHitText", L.HIDE_PORTRAIT_HIT_TEXT, L.HIDE_PORTRAIT_HIT_TEXT_TIP)

    page:Header("right", L.SECTION_UNIT_FRAMES)
    page:Checkbox("right", "classColorPlayer", L.CLASS_COLOR_PLAYER, L.CLASS_COLOR_TIP)
    page:Checkbox("right", "classColorTarget", L.CLASS_COLOR_TARGET, L.CLASS_COLOR_TIP)
    page:Checkbox("right", "classColorTargetOfTarget", L.CLASS_COLOR_TARGET_OF_TARGET, L.CLASS_COLOR_TIP)
    page:Checkbox("right", "classColorFocus", L.CLASS_COLOR_FOCUS, L.CLASS_COLOR_TIP)
    page:Checkbox("right", "classColorFocusTarget", L.CLASS_COLOR_FOCUS_TARGET, L.CLASS_COLOR_TIP)
end

-- Chat page: the chat window on the left, the chat commands on the right.
local function buildChat(page)
    page:Header("left", L.SECTION_CHAT_WINDOW)
    page:Checkbox("left", "hideChatSocial", L.HIDE_CHAT_SOCIAL, L.HIDE_CHAT_SOCIAL_TIP)
    page:Checkbox("left", "hideChatButtons", L.HIDE_CHAT_BUTTONS, L.HIDE_CHAT_BUTTONS_TIP)
    page:Checkbox("left", "hideCombatLog", L.HIDE_COMBAT_LOG, L.HIDE_COMBAT_LOG_TIP)
    page:Checkbox("left", "chatClassColors", L.CHAT_CLASS_COLORS, L.CHAT_CLASS_COLORS_TIP)

    page:Header("right", L.SECTION_COMMANDS)
    page:Checkbox("right", "reloadCommand", L.RELOAD_COMMAND, L.RELOAD_COMMAND_TIP)
end

-- Mail page: what the bookmarks are, then the bookmarks on the Send Mail tab, a name each.
local function buildMail(page)
    page:Text("wide", L.MAIL_INTRO)
    page:Header("left", L.SECTION_MAIL_BOOKMARKS)
    for index, key in ipairs(ns.MailBookmarks.KEYS) do
        page:TextBox("left", key, L.MAIL_BOOKMARK:format(index), L.MAIL_BOOKMARK_TIP)
    end
end

-- World map page: what's marked on the map, in rows across the page.
local function buildWorldMap(page)
    page:Checkbox("wide", "mapDungeons", L.MAP_DUNGEONS, L.MAP_DUNGEONS_TIP)
    page:Checkbox("wide", "mapTravel", L.MAP_TRAVEL, L.MAP_TRAVEL_TIP)
end

-- The places a minimap element can go, as dropdown choices.
local function positions(key)
    local choices = {}
    for _, value in ipairs(ns.MinimapLayout.PositionsFor(key)) do
        choices[#choices + 1] = { value = value, label = L["POSITION_" .. value:upper()] }
    end
    return choices
end

-- The font sizes for a text, as dropdown choices.
local function fontSizes()
    local choices = {}
    for _, size in ipairs(ns.MinimapLayout.FONT_SIZES) do
        choices[#choices + 1] = { value = size, label = size == 0 and L.FONT_SIZE_DEFAULT or tostring(size) }
    end
    return choices
end

-- Whether a minimap element isn't hidden, for what only applies while it shows.
local function shown(key)
    return function() return Options:Get(key) ~= "hidden" end
end

-- The minimap table's columns: the elements' names, then these.
local POSITION, FONT_SIZE, CLASS_COLOR, OFFSET_X, OFFSET_Y = 2, 3, 4, 5, 6

-- Minimap page: the Shape section, then a table across the page with a line for each element around
-- the minimap: where it goes and, while it isn't hidden, a text's font size and class color and how
-- far it's shifted from its spot. An element's extra setting is on an indented line below it, there
-- only while it applies. Classic Era has no coordinates, addon compartment or calendar button, retail
-- no day and night icon.
local function buildMinimap(page)
    local Layout = ns.MinimapLayout
    page:Header("left", L.SECTION_MINIMAP_SHAPE)
    page:Checkbox("left", "squareMinimap", L.SQUARE_MINIMAP, L.SQUARE_MINIMAP_TIP)
    page:Dropdown("left", "squareMinimapBorder", L.SQUARE_MINIMAP_BORDER, {
        { value = "bronze", label = L.BORDER_BRONZE },
        { value = "black", label = L.BORDER_BLACK },
    }, L.SQUARE_MINIMAP_BORDER_TIP, { indent = true, enabled = is("squareMinimap") })

    local elements = page:Table({
        { caption = L.MINIMAP_ELEMENT },
        { caption = L.MINIMAP_POSITION, width = 150 },
        { caption = L.FONT_SIZE, width = 84 },
        { caption = L.CLASS_COLOR, width = 76 },
        { caption = L.MINIMAP_OFFSET_X, width = ns.SettingsPage.NUMBER_FIELD_WIDTH },
        { caption = L.MINIMAP_OFFSET_Y, width = ns.SettingsPage.NUMBER_FIELD_WIDTH },
    })
    -- tips: position, and for a text size and color, and offset for an element that can be shifted.
    local function element(key, label, tips)
        local isShown = shown(key)
        local cells = { [POSITION] = { kind = "dropdown", key = key, choices = positions(key), tooltip = tips.position } }
        if tips.size then
            cells[FONT_SIZE] = { kind = "dropdown", key = key .. "Size", choices = fontSizes(), tooltip = tips.size,
                shown = isShown }
            cells[CLASS_COLOR] = { kind = "checkbox", key = key .. "ClassColor", tooltip = tips.color, shown = isShown }
        end
        if tips.offset then
            local x, y = Layout.OffsetKeys(key)
            cells[OFFSET_X] = { kind = "number", key = x, min = -Layout.MAX_OFFSET, max = Layout.MAX_OFFSET,
                tooltip = tips.offset, shown = isShown }
            cells[OFFSET_Y] = { kind = "number", key = y, min = -Layout.MAX_OFFSET, max = Layout.MAX_OFFSET,
                tooltip = tips.offset, shown = isShown }
        end
        elements:Line(label, tips.position, cells)
    end

    element("minimapZoneText", L.MINIMAP_ZONE_TEXT, { position = L.MINIMAP_ZONE_TEXT_TIP,
        size = L.MINIMAP_ZONE_TEXT_SIZE_TIP, color = L.MINIMAP_ZONE_TEXT_CLASS_COLOR_TIP,
        offset = L.MINIMAP_ZONE_TEXT_OFFSET_TIP })
    elements:Line(L.HIDE_MINIMAP_ZONE_TEXT_FRAME, L.HIDE_MINIMAP_ZONE_TEXT_FRAME_TIP, {
        [POSITION] = { kind = "checkbox", key = "hideMinimapZoneTextFrame", tooltip = L.HIDE_MINIMAP_ZONE_TEXT_FRAME_TIP },
    }, { indent = true, shown = function() return Options:Get("minimapZoneText") == "default" end })
    element("minimapClock", L.MINIMAP_CLOCK, { position = L.MINIMAP_POSITION_TIP, size = L.MINIMAP_CLOCK_SIZE_TIP,
        color = L.MINIMAP_CLOCK_CLASS_COLOR_TIP, offset = L.MINIMAP_OFFSET_TIP })
    if Layout.HasCoords() then
        element("minimapCoords", L.MINIMAP_COORDS, { position = L.MINIMAP_COORDS_TIP, size = L.MINIMAP_COORDS_SIZE_TIP,
            color = L.MINIMAP_COORDS_CLASS_COLOR_TIP, offset = L.MINIMAP_COORDS_OFFSET_TIP })
    end
    element("minimapPerformance", L.MINIMAP_PERFORMANCE, { position = L.MINIMAP_PERFORMANCE_TIP,
        size = L.MINIMAP_PERFORMANCE_SIZE_TIP, color = L.MINIMAP_PERFORMANCE_CLASS_COLOR_TIP,
        offset = L.MINIMAP_OFFSET_TIP })
    elements:Line(L.MINIMAP_PERFORMANCE_SHOW, L.MINIMAP_PERFORMANCE_SHOW_TIP, {
        [POSITION] = { kind = "dropdown", key = "minimapPerformanceShow", tooltip = L.MINIMAP_PERFORMANCE_SHOW_TIP,
            choices = {
                { value = "both", label = L.PERFORMANCE_SHOW_BOTH },
                { value = "fps", label = L.PERFORMANCE_SHOW_FPS },
                { value = "ping", label = L.PERFORMANCE_SHOW_PING },
            } },
    }, { indent = true, shown = shown("minimapPerformance") })
    if Layout.HasCompartment() then
        element("minimapCompartment", L.MINIMAP_COMPARTMENT, { position = L.MINIMAP_POSITION_TIP,
            offset = L.MINIMAP_OFFSET_TIP })
    end
    element("minimapTracking", L.MINIMAP_TRACKING, { position = L.MINIMAP_INSIDE_POSITION_TIP,
        offset = L.MINIMAP_OFFSET_TIP })
    -- Forever's day and night icon, or Classic Era's time of day icon.
    if Layout.HasDayNight() then
        element("minimapDayNight", L.MINIMAP_DAY_NIGHT, { position = L.MINIMAP_INSIDE_POSITION_TIP,
            offset = L.MINIMAP_OFFSET_TIP })
    end
    if Layout.HasCalendar() then
        element("minimapCalendar", L.MINIMAP_CALENDAR, { position = L.MINIMAP_CALENDAR_TIP })
    end
end

-- Action bar page: a table with both flips for each bar, then the paging keys and the buttons' look
-- side by side, and on clients with spell ranks the rank upgrades.
local function buildActionBars(page)
    local ActionBars = ns.ActionBars
    local VERTICAL, HORIZONTAL = 2, 3 -- the table's columns after the bars' names
    local flips = page:Table({
        { caption = L.FLIP_BAR, width = 200 },
        { caption = L.FLIP_VERTICAL, width = 100, tooltip = L.FLIP_VERTICAL_TIP },
        { caption = L.FLIP_HORIZONTAL, width = 100, tooltip = L.FLIP_HORIZONTAL_TIP },
    }, L.SECTION_FLIP)
    for _, bar in ipairs(ActionBars.BARS) do
        flips:Line(bar.label(), nil, {
            [VERTICAL] = { kind = "checkbox", key = ActionBars.VerticalKey(bar.frame), tooltip = L.FLIP_VERTICAL_TIP },
            [HORIZONTAL] = { kind = "checkbox", key = ActionBars.HorizontalKey(bar.frame),
                tooltip = L.FLIP_HORIZONTAL_TIP },
        })
    end
    page:Header("left", L.SECTION_BAR_PAGING)
    page:Checkbox("left", "disableBarPaging", L.DISABLE_BAR_PAGING, L.DISABLE_BAR_PAGING_TIP)
    page:Header("right", L.SECTION_BUTTONS)
    page:Checkbox("right", "hideButtonBorders", L.HIDE_BUTTON_BORDERS, L.HIDE_BUTTON_BORDERS_TIP)
    if ns.RankUpgrades.IsAvailable() then
        page:Align()
        page:Header("left", L.SECTION_RANK_UPGRADES)
        page:Checkbox("left", "upgradeSpellRanks", L.UPGRADE_SPELL_RANKS, L.UPGRADE_SPELL_RANKS_TIP)
        page:Button("left", L.UPGRADE_ALL_SPELLS_LABEL, L.UPGRADE_ALL_SPELLS, L.UPGRADE_ALL_SPELLS_TIP,
            function() ns.RankUpgrades.UpgradeAll() end)
    end
end

-- Cooldown Manager page (Forever): how the game's Cooldown Manager looks.
local function buildCooldownManager(page)
    page:Header("left", L.SECTION_LOOK)
    page:Checkbox("left", "hideCooldownManagerBorders", L.HIDE_COOLDOWN_BORDERS, L.HIDE_COOLDOWN_BORDERS_TIP)
end

-- Ring page (also /qol ring): the switch in the title bar, and below it, on a page of the spell
-- book, the rings' editor (Features/RingEditor.lua), which follows the page when it's shown.
local function buildRing(page)
    page:Checkbox("title", "ring", L.RING, L.RING_TIP)
    local Window, top = ns.SettingsWindow, ns.SettingsPage.TOP
    ns.RingEditor:Create(page.frame, top, Window.PAGE_WIDTH, Window.PAGE_HEIGHT - top)
    local refresh = page.Refresh
    function page:Refresh()
        refresh(self)
        ns.RingEditor:Refresh()
    end
end

-- Click casting page (also /qol click): the switch in the title bar, and below it, on a page of the
-- spell book, the bindings' editor (Features/ClickCastEditor.lua), which follows the page when it's
-- shown.
local function buildClickCast(page)
    page:Checkbox("title", "clickCast", L.CLICK_CAST, L.CLICK_CAST_TIP)
    page:Checkbox("title", "clickCastEnemies", L.CLICK_CAST_ENEMIES, L.CLICK_CAST_ENEMIES_TIP)
    local Window, top = ns.SettingsWindow, ns.SettingsPage.TOP
    ns.ClickCastEditor:Create(page.frame, top, Window.PAGE_WIDTH, Window.PAGE_HEIGHT - top)
    local refresh = page.Refresh
    function page:Refresh()
        refresh(self)
        ns.ClickCastEditor:Refresh()
    end
end

-- Controller page: the back buttons with the bar whose slots they use and the trigger toggle, next to
-- the buff tooltips and the bars that follow the stance, then the back buttons' keys across the page
-- (as in Key Bindings > AddOns), each named by its slot on that bar.
local function buildController(page)
    local BackButtons = ns.BackButtons
    local enabled = is("controllerBackButtons")
    page:Header("left", L.SECTION_BACK_BUTTONS)
    page:Checkbox("left", "controllerBackButtons", L.BACK_BUTTONS, L.BACK_BUTTONS_TIP)
    local bars = {}
    for bar = 6, 8 do
        bars[#bars + 1] = { value = bar, label = L.BACK_BUTTONS_BAR_CHOICE:format(bar) }
    end
    page:Dropdown("left", "controllerBackButtonsBar", L.BACK_BUTTONS_BAR, bars, L.BACK_BUTTONS_BAR_TIP,
        { indent = true, enabled = enabled })
    page:Header("left", L.SECTION_TRIGGER_TOGGLE)
    page:Checkbox("left", "controllerTriggerToggle", L.TRIGGER_TOGGLE, L.TRIGGER_TOGGLE_TIP)
    page:Checkbox("left", "controllerTriggerToggleTopAfterCombat", L.TRIGGER_TOGGLE_TOP, L.TRIGGER_TOGGLE_TOP_TIP,
        { indent = true, enabled = is("controllerTriggerToggle") })
    page:Header("right", L.SECTION_BUFFS)
    page:Checkbox("right", "hideBuffTooltips", L.HIDE_BUFF_TOOLTIPS, L.HIDE_BUFF_TOOLTIPS_TIP)
    page:Header("right", L.SECTION_FOLLOWING_BARS)
    local FollowingBars = ns.FollowingBars
    for _, name in ipairs(FollowingBars.BARS) do
        -- Saved per character, so not an option. The game's Stance bar setting has its bar already.
        local backing = {
            get = function() return FollowingBars.IsGameBar(name) or FollowingBars.IsTicked(name) end,
            set = function(value) FollowingBars:SetTicked(name, value) end,
            reset = function() FollowingBars:SetTicked(name, false) end,
            isDefault = function() return not FollowingBars.IsTicked(name) end,
        }
        page:Checkbox("right", backing, L["FOLLOWING_BAR_" .. name:upper()],
            name == "top" and L.FOLLOWING_BAR_TOP_TIP or L.FOLLOWING_BAR_TIP,
            { enabled = function() return not FollowingBars.IsGameBar(name) end })
    end
    page:Text("right", L.FOLLOWING_BARS_FULL, { shown = FollowingBars.IsOutOfSpace })
    -- A stance can run out of slots at any moment, inside the secure snippet: the next frame, in
    -- combat too. The one feature that gets a callback from the UI (docs/dev/controller.md).
    local function refreshShown()
        if page.frame:IsVisible() then page:Refresh() end
    end
    function FollowingBars.onSpaceChanged()
        ns.Later("followingBarsRefresh", refreshShown, true)
    end

    page:Header("wide", L.SECTION_KEYS)
    for index, info in ipairs(BackButtons.BUTTONS) do
        local function label()
            return L.BACK_BUTTON_KEY:format(info.label, Options:Get("controllerBackButtonsBar"),
                BackButtons.BarButton(index))
        end
        page:Binding("wide", BackButtons.Command(index), label, L.BACK_BUTTON_KEY_TIP,
            { title = L["BACK_BUTTON_" .. info.label], enabled = enabled })
    end
    page:Note("wide", L.BINDING_HINT)
end

-- Viewport page: rows across the page, as the sliders need the room.
local function buildViewport(page)
    page:Checkbox("wide", "viewportEnabled", L.VIEWPORT_ENABLE, L.VIEWPORT_ENABLE_TIP)
    local enabled = { indent = true, enabled = is("viewportEnabled") }
    local margins = {
        { key = "viewportTop", label = L.VIEWPORT_TOP },
        { key = "viewportBottom", label = L.VIEWPORT_BOTTOM },
        { key = "viewportLeft", label = L.VIEWPORT_LEFT },
        { key = "viewportRight", label = L.VIEWPORT_RIGHT },
    }
    local function pixels(value) return L.PIXELS:format(value) end
    for _, margin in ipairs(margins) do
        page:Slider("wide", margin.key, margin.label, 0, VIEWPORT_MAX_MARGIN, pixels, L.VIEWPORT_MARGIN_TIP, enabled)
    end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        page:Color("wide", "viewportColor", L.VIEWPORT_COLOR, L.VIEWPORT_COLOR_TIP, enabled)
    end
end

-- How a hidden setting's row gets, sets and resets the game's value, and its game default. After
-- each set the page shows what the game kept, so a value it refused shows the old one; the Defaults
-- button refreshes the page after resetting every row. canChange: whether the game takes a change
-- now (inCombat: whether the page is in combat); the row is greyed out, and sets and resets
-- nothing, while it doesn't, so a box typed into as combat starts writes nothing either. A row its
-- game slider sets is never at what Reset sets: QoL can't know what the slider would set.
local function hiddenBacking(page, setting, inCombat)
    local Hidden = ns.HiddenSettings
    local cvar = setting.cvar
    local backing = {
        canChange = function() return Hidden.CanChange(cvar, inCombat()) end,
        isDefault = function() return not Hidden.GameSlider(cvar) and Hidden.IsAtGameDefault(cvar) end,
    }
    -- done: shared by the rows of one Defaults click, which write each game slider once.
    backing.reset = function(done)
        if not backing.canChange() then return end
        local slider = Hidden.GameSlider(cvar)
        if done and slider then
            if done[slider] then return end
            done[slider] = true
        end
        Hidden.Reset(cvar)
    end
    local function set(value)
        if backing.canChange() then Hidden.Set(cvar, value) end
        page:Refresh()
    end
    if setting.kind == "checkbox" then
        backing.get = function() return Hidden.Get(cvar) == "1" end
        backing.set = function(checked) set(checked and "1" or "0") end
    else
        backing.get = function() return tonumber(Hidden.Get(cvar)) or setting.min end
        backing.set = set
    end
    return backing
end

-- A hidden setting's game default as its row shows it: On or Off, or the number without the
-- trailing zeros the game may add (1.900000).
local function gameDefaultText(setting)
    local gameDefault = ns.HiddenSettings.GetGameDefault(setting.cvar)
    if gameDefault == nil then return nil end
    if setting.kind == "checkbox" then return tonumber(gameDefault) == 1 and L.ON or L.OFF end
    local number = tonumber(gameDefault)
    return number and ("%g"):format(number) or gameDefault
end

-- Reset's tooltip on a row its game slider sets: that it puts back what the slider sets, and the
-- other rows here it puts back with it (known: the settings on the page).
local function gameSliderResetText(setting, known)
    local others = {}
    for _, other in ipairs(known) do
        if other.gameSlider == setting.gameSlider and other ~= setting then others[#others + 1] = other.label end
    end
    local text = L.RESET_TO_GAME_SLIDER_TIP:format(ns.HiddenSettings.GAME_SLIDER_NAMES[setting.gameSlider])
    if #others == 0 then return text end
    local list = others[#others]
    if #others > 1 then list = L.LIST_AND:format(table.concat(others, ", ", 1, #others - 1), list) end
    return text .. " " .. L.ALSO_RESETS:format(list)
end

-- Graphics & Camera page: what the game's hidden settings are, then a section of rows across the
-- page for each part of the game (Features/HiddenSettings.lua), those this client knows.
local function buildAdvanced(page)
    page:Text("wide", L.ADVANCED_INTRO)
    -- From PLAYER_REGEN_DISABLED, which comes while InCombatLockdown is still false, to
    -- PLAYER_REGEN_ENABLED.
    local combat = false
    local function inCombat() return combat or InCombatLockdown() end
    local section
    local known = ns.HiddenSettings.Known()
    for _, setting in ipairs(known) do
        if setting.section ~= section then
            section = setting.section
            page:Header("wide", section)
        end
        local backing = hiddenBacking(page, setting, inCombat)
        -- The game default, from the game, ends the row's tooltip and is on its Reset button's. Not
        -- on a row its game slider sets, as Reset doesn't go there.
        local gameSlider = ns.HiddenSettings.GameSlider(setting.cvar)
        local gameDefault = not gameSlider and gameDefaultText(setting)
        local tooltip, resetTooltip = setting.tooltip, nil
        if gameSlider then
            resetTooltip = gameSliderResetText(setting, known)
        elseif gameDefault then
            tooltip = tooltip .. "\n\n" .. L.GAME_DEFAULT:format(gameDefault)
            resetTooltip = L.RESET_TO_GAME_DEFAULT_TIP:format(gameDefault)
        end
        local options = { resetButton = true, resetTooltip = resetTooltip, enabled = backing.canChange }
        if setting.kind == "checkbox" then
            page:Checkbox("wide", backing, setting.label, tooltip, options)
        else
            options.step, options.textBox = setting.step, true
            page:Slider("wide", backing, setting.label, setting.min, setting.max, nil, tooltip, options)
        end
    end
    -- A change through /console, the game's options or another addon. The window refreshes the page
    -- each time it shows it too, in case the game doesn't send this for every change. Once on the
    -- next frame for a burst of them, in combat too: a game slider writes several, and /qol probe
    -- hundreds.
    local function refreshShown()
        if page.frame:IsVisible() then page:Refresh() end
    end
    ns.Events:On("CVAR_UPDATE", function(_, cvar)
        if page.frame:IsVisible() and ns.HiddenSettings.Find(cvar) then
            ns.Later("advancedSettingsRefresh", refreshShown, true)
        end
    end)
    -- A protected setting's row greys out in combat and comes back after it.
    local function combatChanged(inCombatNow)
        combat = inCombatNow
        if page.frame:IsVisible() then page:Refresh() end
    end
    ns.Events:On("PLAYER_REGEN_DISABLED", function() combatChanged(true) end)
    ns.Events:On("PLAYER_REGEN_ENABLED", function() combatChanged(false) end)
end

-- The window's list: its groups and their pages, in order. Page keys are what /qol and the other
-- pages open a page by, wherever its group is. A page's available: whether it has anything to change
-- on this client; defaults: false for a page without a Defaults button. A group none of whose pages
-- the client has is left out.
local GROUPS = {
    { title = L.GROUP_GENERAL, pages = {
        { key = "automation", title = L.CATEGORY_AUTOMATION, build = buildAutomation },
        { key = "chat", title = L.CATEGORY_CHAT, build = buildChat },
        { key = "mail", title = L.CATEGORY_MAIL, build = buildMail },
    } },
    { title = L.GROUP_DISPLAY, pages = {
        { key = "interface", title = L.CATEGORY_INTERFACE, build = buildInterface },
        { key = "unitFrames", title = L.CATEGORY_UNIT_FRAMES, build = buildUnitFrames },
        { key = "actionBars", title = L.CATEGORY_ACTION_BARS, build = buildActionBars },
        -- Only on Forever, where the game has its Cooldown Manager's rows.
        { key = "cooldownManager", title = L.CATEGORY_COOLDOWN_MANAGER, build = buildCooldownManager,
            available = function() return ns.CooldownManager.IsAvailable() end },
        { key = "viewport", title = L.CATEGORY_VIEWPORT, build = buildViewport },
    } },
    { title = L.GROUP_MAPS, pages = {
        { key = "minimap", title = L.CATEGORY_MINIMAP, build = buildMinimap },
        -- Only where there are pins to show: they are on Forever's maps.
        { key = "worldMap", title = L.CATEGORY_WORLD_MAP, build = buildWorldMap,
            available = function() return ns.MapPins.IsAvailable() end },
    } },
    { title = L.GROUP_INPUT, pages = {
        -- Its only option is the switch: no Defaults button, as resetting it would turn the rings off.
        { key = "ring", title = L.CATEGORY_RING, build = buildRing, defaults = false },
        -- Likewise: resetting its switch would turn click casting off.
        { key = "clickCast", title = L.CATEGORY_CLICK_CAST, build = buildClickCast, defaults = false },
        -- Only Forever has the controller action bar; on retail there's nothing for it to change.
        { key = "controller", title = L.CATEGORY_CONTROLLER, build = buildController,
            available = function() return GamepadMainActionBarFrame ~= nil end },
    } },
    { title = L.GROUP_SYSTEM, pages = {
        -- Only where the client knows a hidden setting. Its Defaults button puts them back to the
        -- game's defaults.
        { key = "advanced", title = L.CATEGORY_ADVANCED, build = buildAdvanced,
            available = function() return #ns.HiddenSettings.Known() > 0 end },
    } },
}

function SettingsPanel:Init()
    self.window = ns.SettingsWindow.New()
    self.pages = {}
    for _, group in ipairs(GROUPS) do
        local available = {}
        for _, info in ipairs(group.pages) do
            if not info.available or info.available() then available[#available + 1] = info end
        end
        if #available > 0 then self.window:AddGroup(group.title) end
        for _, info in ipairs(available) do
            local page = ns.SettingsPage.New(info.title, { defaults = info.defaults })
            info.build(page)
            self.window:Add(info.key, info.title, page)
            self.pages[info.key] = page
        end
    end

    -- Without the Settings API there's no AddOns list for the information page; /qol still works.
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    -- In Forever's controller interface the window waits until the game's settings and menu are
    -- closed: they have the controller while open, so it couldn't get to the window, and nothing of
    -- ours should change while they're open.
    self.info = ns.InfoPage.New(function()
        ns.LaterOutsideWindows("settingsWindow", function() self:Open() end)
    end)
    self.category = self.info:Register()
    Settings.RegisterAddOnCategory(self.category)
end

-- key: a page to open the window on (else the one it was on).
function SettingsPanel:Open(key)
    self.window:Open(key)
end

function SettingsPanel:Toggle(key)
    self.window:Toggle(key)
end
