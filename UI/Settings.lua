local _, ns = ...
local L = ns.L
local Options = ns.Options

-- Quality of Life's pages under Options > AddOns: the main page, plus Viewport, Action Bars, Ring,
-- Minimap and, on Forever (which has the controller action bar), Controller as subcategories. Every
-- page is our own (UI/SettingsPage.lua), none is the game's own list of settings: on Forever, with
-- the controller interface on, the game stopped responding when the settings closed after showing
-- Viewport as the game's list, with its sliders and color swatch (see docs/DEVELOPMENT.md). The
-- pages only read and write ns.Options, and the features react through Options:Watch. Without the
-- Settings API the pages are skipped.
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

-- Main page: two columns of about the same length.
local function buildMain(page)
    page:Header("left", L.SECTION_MERCHANT)
    page:Checkbox("left", "sellJunk", L.SELL_JUNK, L.SELL_JUNK_TIP)
    page:Checkbox("left", "autoRepair", L.AUTO_REPAIR, L.AUTO_REPAIR_TIP)
    page:Checkbox("left", "guildRepair", L.GUILD_REPAIR, L.GUILD_REPAIR_TIP, { indent = true, enabled = is("autoRepair") })

    page:Header("left", L.SECTION_QUESTS)
    page:Checkbox("left", "questAccept", L.QUEST_ACCEPT, L.QUEST_ACCEPT_TIP)
    page:Checkbox("left", "questTurnIn", L.QUEST_TURN_IN, L.QUEST_TURN_IN_TIP)

    page:Header("left", L.SECTION_TOOLTIPS)
    page:Checkbox("left", "tooltipIDs", L.TOOLTIP_IDS, L.TOOLTIP_IDS_TIP)
    page:Checkbox("left", "tooltipSellPrice", L.TOOLTIP_SELL_PRICE, L.TOOLTIP_SELL_PRICE_TIP)

    page:Header("left", L.SECTION_INTERFACE)
    page:Checkbox("left", "hideMicroMenu", L.HIDE_MICRO_MENU, L.HIDE_MICRO_MENU_TIP)
    page:Checkbox("left", "hideBagsBar", L.HIDE_BAGS_BAR, L.HIDE_BAGS_BAR_TIP)
    page:Checkbox("left", "showCombinedBagSort", L.SHOW_COMBINED_BAG_SORT, L.SHOW_COMBINED_BAG_SORT_TIP)
    page:Checkbox("left", "combinedBagTopLeft", L.COMBINED_BAG_TOP_LEFT, L.COMBINED_BAG_TOP_LEFT_TIP)

    page:Header("left", L.SECTION_COMMANDS)
    page:Checkbox("left", "reloadCommand", L.RELOAD_COMMAND, L.RELOAD_COMMAND_TIP)

    page:Header("right", L.SECTION_CHAT)
    page:Checkbox("right", "hideChatSocial", L.HIDE_CHAT_SOCIAL, L.HIDE_CHAT_SOCIAL_TIP)
    page:Checkbox("right", "hideChatButtons", L.HIDE_CHAT_BUTTONS, L.HIDE_CHAT_BUTTONS_TIP)
    page:Checkbox("right", "hideCombatLog", L.HIDE_COMBAT_LOG, L.HIDE_COMBAT_LOG_TIP)
    page:Checkbox("right", "chatClassColors", L.CHAT_CLASS_COLORS, L.CHAT_CLASS_COLORS_TIP)

    -- Only where there are pins to show: they are on Forever's maps.
    if ns.MapPins.IsAvailable() then
        page:Header("right", L.SECTION_WORLD_MAP)
        page:Checkbox("right", "mapDungeons", L.MAP_DUNGEONS, L.MAP_DUNGEONS_TIP)
        page:Checkbox("right", "mapTravel", L.MAP_TRAVEL, L.MAP_TRAVEL_TIP)
    end

    page:Header("right", L.SECTION_UNIT_FRAMES)
    page:Checkbox("right", "classColorPlayer", L.CLASS_COLOR_PLAYER, L.CLASS_COLOR_TIP)
    page:Checkbox("right", "classColorTarget", L.CLASS_COLOR_TARGET, L.CLASS_COLOR_TIP)
    page:Checkbox("right", "classColorTargetOfTarget", L.CLASS_COLOR_TARGET_OF_TARGET, L.CLASS_COLOR_TIP)
    page:Checkbox("right", "classColorFocus", L.CLASS_COLOR_FOCUS, L.CLASS_COLOR_TIP)
    page:Checkbox("right", "classColorFocusTarget", L.CLASS_COLOR_FOCUS_TARGET, L.CLASS_COLOR_TIP)
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

-- Minimap page: the map and the texts around it on the left, the buttons on the right.
local function buildMinimap(page)
    page:Header("left", L.SECTION_MINIMAP_SHAPE)
    page:Checkbox("left", "squareMinimap", L.SQUARE_MINIMAP, L.SQUARE_MINIMAP_TIP)
    page:Dropdown("left", "squareMinimapBorder", L.SQUARE_MINIMAP_BORDER, {
        { value = "bronze", label = L.BORDER_BRONZE },
        { value = "black", label = L.BORDER_BLACK },
    }, L.SQUARE_MINIMAP_BORDER_TIP, { indent = true, enabled = is("squareMinimap") })

    page:Header("left", L.SECTION_MINIMAP_ZONE_TEXT)
    page:Dropdown("left", "minimapZoneText", L.MINIMAP_POSITION, {
        { value = "default", label = L.POSITION_DEFAULT },
        { value = "above", label = L.ZONE_TEXT_ABOVE },
        { value = "below", label = L.ZONE_TEXT_BELOW },
    }, L.MINIMAP_ZONE_TEXT_TIP)
    page:Checkbox("left", "minimapZoneTextClassColor", L.MINIMAP_CLASS_COLOR, L.MINIMAP_ZONE_TEXT_CLASS_COLOR_TIP)
    page:Dropdown("left", "minimapZoneTextSize", L.FONT_SIZE, fontSizes(), L.MINIMAP_ZONE_TEXT_SIZE_TIP)

    page:Header("left", L.SECTION_MINIMAP_COORDS)
    page:Checkbox("left", "minimapCoordsClassColor", L.MINIMAP_CLASS_COLOR, L.MINIMAP_COORDS_CLASS_COLOR_TIP,
        { enabled = isNot("hideMinimapCoords") })
    page:Checkbox("left", "hideMinimapCoords", L.HIDE_MINIMAP_COORDS, L.HIDE_MINIMAP_COORDS_TIP)

    page:Header("right", L.SECTION_MINIMAP_CLOCK)
    page:Dropdown("right", "minimapClock", L.MINIMAP_POSITION, positions("minimapClock"), L.MINIMAP_POSITION_TIP)
    local clockShown = function() return Options:Get("minimapClock") ~= "hidden" end
    page:Checkbox("right", "minimapClockClassColor", L.MINIMAP_CLASS_COLOR, L.MINIMAP_CLOCK_CLASS_COLOR_TIP,
        { enabled = clockShown })
    page:Dropdown("right", "minimapClockSize", L.FONT_SIZE, fontSizes(), L.MINIMAP_CLOCK_SIZE_TIP,
        { enabled = clockShown })

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

-- Ring page: the switch, and a button to where the rings are made (their editor, also /qol ring).
local function buildRing(page)
    page:Checkbox("wide", "ring", L.RING, L.RING_TIP)
    page:Button("wide", L.RING_EDITOR, L.RING_EDITOR_OPEN, L.RING_EDITOR_TIP, function() ns.RingEditor:Open() end)
    page:Note("wide", L.RING_NOTE)
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

function SettingsPanel:Init()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterCanvasLayoutSubcategory) then
        return
    end
    local Page = ns.SettingsPage
    local main = Page.New(L.ADDON_TITLE)
    buildMain(main)
    local category = main:Register()

    local viewport = Page.New(L.CATEGORY_VIEWPORT)
    buildViewport(viewport)
    viewport:Register(category)

    local actionBars = Page.New(L.CATEGORY_ACTION_BARS)
    buildActionBars(actionBars)
    actionBars:Register(category)

    local ring = Page.New(L.CATEGORY_RING)
    buildRing(ring)
    ring:Register(category)

    local minimap = Page.New(L.CATEGORY_MINIMAP)
    buildMinimap(minimap)
    minimap:Register(category)

    self.pages = { main = main, viewport = viewport, actionBars = actionBars, ring = ring, minimap = minimap }
    if GamepadMainActionBarFrame then
        local controller = Page.New(L.CATEGORY_CONTROLLER)
        buildController(controller)
        controller:Register(category)
        self.pages.controller = controller
    end

    Settings.RegisterAddOnCategory(category)
    self.category = category
end

function SettingsPanel:Open()
    if self.category and Settings.OpenToCategory then
        Settings.OpenToCategory(self.category:GetID())
    end
end
