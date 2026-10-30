local _, ns = ...
local L = ns.L
local Options = ns.Options

-- Quality of Life's settings: a window of our own (UI/SettingsWindow.lua), which /qol opens, with a
-- page for each part of the game: Automation, Interface, Chat, Mail, Action Bars, Minimap, World map
-- (on Forever's maps), Viewport, Ring, on Forever (which has the controller action bar) Controller,
-- and Advanced settings, the game's hidden settings.
-- Under Options > AddOns there's only the information page (UI/InfoPage.lua), with a button that
-- opens the window. The game's settings have nothing of ours to change: on Forever, with the
-- controller interface on, the game stopped responding now and then when they closed after a
-- change (see docs/dev/settings-window.md). The pages read and write ns.Options, and the features react
-- through Options:Watch; the Advanced settings page reads and writes the game's own values through
-- ns.HiddenSettings.
local SettingsPanel = {}
ns.SettingsPanel = SettingsPanel

local VIEWPORT_MAX_MARGIN = 600

-- For the pages' enabled predicates.
local function is(key)
    return function() return Options:Get(key) == true end
end

local function isNot(key)
    return function() return Options:Get(key) ~= true end
end

-- Automation page: what's done for you at merchants, quest givers and loot.
local function buildAutomation(page)
    page:Header("left", L.SECTION_MERCHANT)
    page:Checkbox("left", "sellJunk", L.SELL_JUNK, L.SELL_JUNK_TIP)
    page:Checkbox("left", "autoRepair", L.AUTO_REPAIR, L.AUTO_REPAIR_TIP)
    -- Classic Era has no guild banks.
    if ns.Merchant.HasGuildBank() then
        page:Checkbox("left", "guildRepair", L.GUILD_REPAIR, L.GUILD_REPAIR_TIP,
            { indent = true, enabled = is("autoRepair") })
    end

    page:Header("right", L.SECTION_QUESTS)
    page:Checkbox("right", "questAccept", L.QUEST_ACCEPT, L.QUEST_ACCEPT_TIP)
    page:Checkbox("right", "questTurnIn", L.QUEST_TURN_IN, L.QUEST_TURN_IN_TIP)

    page:Header("right", L.SECTION_LOOT)
    page:Checkbox("right", "fasterAutoLoot", L.FASTER_AUTO_LOOT, L.FASTER_AUTO_LOOT_TIP)
end

-- Interface page: the bars to hide, the combined bags and the player frame on the left, tooltips and
-- health bars on the right.
local function buildInterface(page)
    page:Header("left", L.SECTION_HIDE)
    page:Checkbox("left", "hideMicroMenu", L.HIDE_MICRO_MENU, L.HIDE_MICRO_MENU_TIP)
    page:Checkbox("left", "hideBagsBar", L.HIDE_BAGS_BAR, L.HIDE_BAGS_BAR_TIP)

    -- Classic Era has neither the combined bag nor the player frame the druid mana bar is drawn on.
    if ns.CombinedBagLayout.IsAvailable() then
        page:Header("left", L.SECTION_COMBINED_BAGS)
        page:Checkbox("left", "combinedBagTopLeft", L.COMBINED_BAG_TOP_LEFT, L.COMBINED_BAG_TOP_LEFT_TIP)
    end

    page:Header("left", L.SECTION_PLAYER_FRAME)
    if ns.DruidManaBar.IsAvailable() then
        page:Checkbox("left", "druidManaBar", L.DRUID_MANA_BAR, L.DRUID_MANA_BAR_TIP)
    end
    page:Checkbox("left", "hidePortraitHitText", L.HIDE_PORTRAIT_HIT_TEXT, L.HIDE_PORTRAIT_HIT_TEXT_TIP)

    page:Header("left", L.SECTION_EDIT_MODE)
    page:Checkbox("left", "pastScreenEdge", L.PAST_SCREEN_EDGE, L.PAST_SCREEN_EDGE_TIP)

    page:Header("right", L.SECTION_TOOLTIPS)
    page:Checkbox("right", "tooltipIDs", L.TOOLTIP_IDS, L.TOOLTIP_IDS_TIP)
    page:Checkbox("right", "tooltipSellPrice", L.TOOLTIP_SELL_PRICE, L.TOOLTIP_SELL_PRICE_TIP)

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

-- Minimap page: the map and the texts around it on the left; the clock, FPS and ping, and the
-- buttons on the right. The sections go side by side in pairs, so their headers line up.
local function buildMinimap(page)
    page:Header("left", L.SECTION_MINIMAP_SHAPE)
    page:Checkbox("left", "squareMinimap", L.SQUARE_MINIMAP, L.SQUARE_MINIMAP_TIP)
    page:Dropdown("left", "squareMinimapBorder", L.SQUARE_MINIMAP_BORDER, {
        { value = "bronze", label = L.BORDER_BRONZE },
        { value = "black", label = L.BORDER_BLACK },
    }, L.SQUARE_MINIMAP_BORDER_TIP, { indent = true, enabled = is("squareMinimap") })

    page:Header("right", L.SECTION_MINIMAP_CLOCK)
    page:Dropdown("right", "minimapClock", L.MINIMAP_POSITION, positions("minimapClock"), L.MINIMAP_POSITION_TIP)
    local clockShown = function() return Options:Get("minimapClock") ~= "hidden" end
    page:Checkbox("right", "minimapClockClassColor", L.MINIMAP_CLASS_COLOR, L.MINIMAP_CLOCK_CLASS_COLOR_TIP,
        { enabled = clockShown })
    page:Dropdown("right", "minimapClockSize", L.FONT_SIZE, fontSizes(), L.MINIMAP_CLOCK_SIZE_TIP,
        { enabled = clockShown })
    page:Align()

    page:Header("left", L.SECTION_MINIMAP_ZONE_TEXT)
    page:Dropdown("left", "minimapZoneText", L.MINIMAP_POSITION, {
        { value = "default", label = L.POSITION_DEFAULT },
        { value = "above", label = L.ZONE_TEXT_ABOVE },
        { value = "below", label = L.ZONE_TEXT_BELOW },
    }, L.MINIMAP_ZONE_TEXT_TIP)
    page:Checkbox("left", "hideMinimapZoneTextFrame", L.HIDE_MINIMAP_ZONE_TEXT_FRAME,
        L.HIDE_MINIMAP_ZONE_TEXT_FRAME_TIP,
        { indent = true, enabled = function() return Options:Get("minimapZoneText") == "default" end })
    page:Checkbox("left", "minimapZoneTextClassColor", L.MINIMAP_CLASS_COLOR, L.MINIMAP_ZONE_TEXT_CLASS_COLOR_TIP)
    page:Dropdown("left", "minimapZoneTextSize", L.FONT_SIZE, fontSizes(), L.MINIMAP_ZONE_TEXT_SIZE_TIP)

    page:Header("right", L.SECTION_MINIMAP_PERFORMANCE)
    page:Dropdown("right", "minimapPerformance", L.MINIMAP_POSITION, positions("minimapPerformance"),
        L.MINIMAP_PERFORMANCE_TIP)
    local performanceShown = function() return Options:Get("minimapPerformance") ~= "hidden" end
    page:Checkbox("right", "minimapPerformanceClassColor", L.MINIMAP_CLASS_COLOR, L.MINIMAP_PERFORMANCE_CLASS_COLOR_TIP,
        { enabled = performanceShown })
    page:Dropdown("right", "minimapPerformanceSize", L.FONT_SIZE, fontSizes(), L.MINIMAP_PERFORMANCE_SIZE_TIP,
        { enabled = performanceShown })
    page:Align()

    -- Classic Era shows no coordinates under the minimap and has no addon compartment.
    if ns.MinimapLayout.HasCoords() then
        page:Header("left", L.SECTION_MINIMAP_COORDS)
        page:Checkbox("left", "minimapCoordsClassColor", L.MINIMAP_CLASS_COLOR, L.MINIMAP_COORDS_CLASS_COLOR_TIP,
            { enabled = isNot("hideMinimapCoords") })
        page:Checkbox("left", "hideMinimapCoords", L.HIDE_MINIMAP_COORDS, L.HIDE_MINIMAP_COORDS_TIP)
    end

    page:Header("right", L.SECTION_MINIMAP_BUTTONS)
    if ns.MinimapLayout.HasCompartment() then
        page:Dropdown("right", "minimapCompartment", L.MINIMAP_COMPARTMENT, positions("minimapCompartment"),
            L.MINIMAP_POSITION_TIP)
    end
    page:Dropdown("right", "minimapTracking", L.MINIMAP_TRACKING, positions("minimapTracking"),
        L.MINIMAP_INSIDE_POSITION_TIP)
    -- Forever's day and night icon, or Classic Era's time of day icon; retail has neither.
    if ns.MinimapLayout.HasDayNight() then
        page:Dropdown("right", "minimapDayNight", L.MINIMAP_DAY_NIGHT, positions("minimapDayNight"),
            L.MINIMAP_INSIDE_POSITION_TIP)
    end
    if ns.MinimapLayout.HasCalendar() then
        page:Checkbox("right", "hideMinimapCalendar", L.HIDE_MINIMAP_CALENDAR, L.HIDE_MINIMAP_CALENDAR_TIP)
    end
end

-- Action bar page: the two flips side by side for each bar, then the paging keys and the buttons'
-- look.
local function buildActionBars(page)
    local ActionBars = ns.ActionBars
    page:Header("left", L.SECTION_FLIP_VERTICAL, L.FLIP_VERTICAL_TIP)
    page:Header("right", L.SECTION_FLIP_HORIZONTAL, L.FLIP_HORIZONTAL_TIP)
    for _, bar in ipairs(ActionBars.BARS) do
        page:Checkbox("left", ActionBars.VerticalKey(bar.frame), bar.label(), L.FLIP_VERTICAL_TIP)
        page:Checkbox("right", ActionBars.HorizontalKey(bar.frame), bar.label(), L.FLIP_HORIZONTAL_TIP)
    end
    page:Align()
    page:Header("left", L.SECTION_BAR_PAGING)
    page:Checkbox("left", "disableBarPaging", L.DISABLE_BAR_PAGING, L.DISABLE_BAR_PAGING_TIP)
    page:Header("right", L.SECTION_BUTTONS)
    page:Checkbox("right", "hideButtonBorders", L.HIDE_BUTTON_BORDERS, L.HIDE_BUTTON_BORDERS_TIP)
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
    local Window, top = ns.SettingsWindow, ns.SettingsPage.TOP
    ns.ClickCastEditor:Create(page.frame, top, Window.PAGE_WIDTH, Window.PAGE_HEIGHT - top)
    local refresh = page.Refresh
    function page:Refresh()
        refresh(self)
        ns.ClickCastEditor:Refresh()
    end
end

-- Controller page: the back buttons and the bar whose slots they use next to the buff tooltips,
-- then the back buttons' keys across the page (as in Key Bindings > AddOns), each named by its slot
-- on that bar.
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
    page:Header("right", L.SECTION_BUFFS)
    page:Checkbox("right", "hideBuffTooltips", L.HIDE_BUFF_TOOLTIPS, L.HIDE_BUFF_TOOLTIPS_TIP)

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

-- Advanced settings page: what the game's hidden settings are, then a section of rows across the
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

-- The window's pages, in the order of its list. available: whether the page has anything to change
-- on this client; defaults: false for a page without a Defaults button.
local PAGES = {
    { key = "automation", title = L.CATEGORY_AUTOMATION, build = buildAutomation },
    { key = "interface", title = L.CATEGORY_INTERFACE, build = buildInterface },
    { key = "chat", title = L.CATEGORY_CHAT, build = buildChat },
    { key = "mail", title = L.CATEGORY_MAIL, build = buildMail },
    { key = "actionBars", title = L.CATEGORY_ACTION_BARS, build = buildActionBars },
    { key = "minimap", title = L.CATEGORY_MINIMAP, build = buildMinimap },
    -- Only where there are pins to show: they are on Forever's maps.
    { key = "worldMap", title = L.CATEGORY_WORLD_MAP, build = buildWorldMap,
        available = function() return ns.MapPins.IsAvailable() end },
    { key = "viewport", title = L.CATEGORY_VIEWPORT, build = buildViewport },
    -- Its only option is the switch: no Defaults button, as resetting it would turn the rings off.
    { key = "ring", title = L.CATEGORY_RING, build = buildRing, defaults = false },
    -- Likewise: resetting its switch would turn click casting off.
    { key = "clickCast", title = L.CATEGORY_CLICK_CAST, build = buildClickCast, defaults = false },
    -- Only Forever has the controller action bar; on retail there's nothing for it to change.
    { key = "controller", title = L.CATEGORY_CONTROLLER, build = buildController,
        available = function() return GamepadMainActionBarFrame ~= nil end },
    -- Only where the client knows a hidden setting. Its Defaults button puts them back to the game's
    -- defaults.
    { key = "advanced", title = L.CATEGORY_ADVANCED, build = buildAdvanced,
        available = function() return #ns.HiddenSettings.Known() > 0 end },
}

function SettingsPanel:Init()
    self.window = ns.SettingsWindow.New()
    self.pages = {}
    for _, info in ipairs(PAGES) do
        if not info.available or info.available() then
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
