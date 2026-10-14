local _, ns = ...
local L = ns.L
local Options = ns.Options

-- Quality of Life's settings: a window of our own (UI/SettingsWindow.lua), which /qol opens, with a
-- page for each part of the game: Automation, Interface, Chat, Mail, Action Bars, Minimap, World map
-- (on Forever's maps), Viewport, Ring and, on Forever (which has the controller action bar), Controller.
-- Under Options > AddOns there's only the information page (UI/InfoPage.lua), with a button that
-- opens the window. The game's settings have nothing of ours to change: on Forever, with the
-- controller interface on, the game stopped responding now and then when they closed after a
-- change (see docs/DEVELOPMENT.md). The pages only read and write ns.Options, and the features react
-- through Options:Watch.
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

-- Automation page: what's done for you at merchants and quest givers.
local function buildAutomation(page)
    page:Header("left", L.SECTION_MERCHANT)
    page:Checkbox("left", "sellJunk", L.SELL_JUNK, L.SELL_JUNK_TIP)
    page:Checkbox("left", "autoRepair", L.AUTO_REPAIR, L.AUTO_REPAIR_TIP)
    page:Checkbox("left", "guildRepair", L.GUILD_REPAIR, L.GUILD_REPAIR_TIP, { indent = true, enabled = is("autoRepair") })

    page:Header("right", L.SECTION_QUESTS)
    page:Checkbox("right", "questAccept", L.QUEST_ACCEPT, L.QUEST_ACCEPT_TIP)
    page:Checkbox("right", "questTurnIn", L.QUEST_TURN_IN, L.QUEST_TURN_IN_TIP)
end

-- Interface page: the bars to hide, the combined bags and the player frame on the left, tooltips and
-- health bars on the right.
local function buildInterface(page)
    page:Header("left", L.SECTION_HIDE)
    page:Checkbox("left", "hideMicroMenu", L.HIDE_MICRO_MENU, L.HIDE_MICRO_MENU_TIP)
    page:Checkbox("left", "hideBagsBar", L.HIDE_BAGS_BAR, L.HIDE_BAGS_BAR_TIP)

    page:Header("left", L.SECTION_COMBINED_BAGS)
    page:Checkbox("left", "showCombinedBagSort", L.SHOW_COMBINED_BAG_SORT, L.SHOW_COMBINED_BAG_SORT_TIP)
    page:Checkbox("left", "combinedBagTopLeft", L.COMBINED_BAG_TOP_LEFT, L.COMBINED_BAG_TOP_LEFT_TIP)

    page:Header("left", L.SECTION_PLAYER_FRAME)
    page:Checkbox("left", "druidManaBar", L.DRUID_MANA_BAR, L.DRUID_MANA_BAR_TIP)

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

    page:Header("left", L.SECTION_MINIMAP_COORDS)
    page:Checkbox("left", "minimapCoordsClassColor", L.MINIMAP_CLASS_COLOR, L.MINIMAP_COORDS_CLASS_COLOR_TIP,
        { enabled = isNot("hideMinimapCoords") })
    page:Checkbox("left", "hideMinimapCoords", L.HIDE_MINIMAP_COORDS, L.HIDE_MINIMAP_COORDS_TIP)

    page:Header("right", L.SECTION_MINIMAP_BUTTONS)
    page:Dropdown("right", "minimapCompartment", L.MINIMAP_COMPARTMENT, positions("minimapCompartment"),
        L.MINIMAP_POSITION_TIP)
    page:Dropdown("right", "minimapTracking", L.MINIMAP_TRACKING, positions("minimapTracking"),
        L.MINIMAP_INSIDE_POSITION_TIP)
    -- Only Forever has the day and night icon.
    if ns.MinimapLayout.HasDayNight() then
        page:Dropdown("right", "minimapDayNight", L.MINIMAP_DAY_NIGHT, positions("minimapDayNight"),
            L.MINIMAP_INSIDE_POSITION_TIP)
    end
    page:Checkbox("right", "hideMinimapCalendar", L.HIDE_MINIMAP_CALENDAR, L.HIDE_MINIMAP_CALENDAR_TIP)
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
    -- Only Forever has the controller action bar; on retail there's nothing for it to change.
    { key = "controller", title = L.CATEGORY_CONTROLLER, build = buildController,
        available = function() return GamepadMainActionBarFrame ~= nil end },
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
