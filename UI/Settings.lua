local _, ns = ...
local L = ns.L
local Options = ns.Options

-- Quality of Life's pages under Options > AddOns: the main page, plus Viewport, Action Bars and Minimap
-- as subcategories. The main, Action Bars and Minimap pages are our own two-column pages
-- (UI/SettingsPage.lua), so they fit without scrolling; Viewport, a short page with sliders and a
-- color, is the game's own list with proxy settings. Either way the pages only read and write
-- ns.Options, and the features react through Options:Watch. Without the Settings API the pages
-- are skipped.
local SettingsPanel = {}
ns.SettingsPanel = SettingsPanel

local VIEWPORT_MAX_MARGIN = 600

local function varType(name)
    return Settings.VarType and Settings.VarType[name] or name:lower()
end

local function register(category, key, kind, label)
    return Settings.RegisterProxySetting(category, "QoL_" .. key, varType(kind), label,
        Options:GetDefault(key),
        function() return Options:Get(key) end,
        function(value) Options:Set(key, value) end)
end

local function addCheckbox(category, key, label, tooltip)
    local setting = register(category, key, "Boolean", label)
    local create = Settings.CreateCheckbox or Settings.CreateCheckBox
    return create(category, setting, tooltip)
end

-- Greys out a control while the option it depends on is off.
local function dependsOn(initializer, parentInitializer, parentKey)
    if initializer and parentInitializer and initializer.SetParentInitializer then
        initializer:SetParentInitializer(parentInitializer, function() return Options:Get(parentKey) end)
    end
end

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

local function addViewport(category)
    local enabled = addCheckbox(category, "viewportEnabled", L.VIEWPORT_ENABLE, L.VIEWPORT_ENABLE_TIP)

    local createSlider = Settings.CreateSlider
    local margins = {
        { key = "viewportTop", label = L.VIEWPORT_TOP },
        { key = "viewportBottom", label = L.VIEWPORT_BOTTOM },
        { key = "viewportLeft", label = L.VIEWPORT_LEFT },
        { key = "viewportRight", label = L.VIEWPORT_RIGHT },
    }
    for _, margin in ipairs(margins) do
        local setting = register(category, margin.key, "Number", margin.label)
        local options = Settings.CreateSliderOptions(0, VIEWPORT_MAX_MARGIN, 1)
        if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                return L.PIXELS:format(math.floor(value + 0.5))
            end)
        end
        dependsOn(createSlider(category, setting, options, L.VIEWPORT_MARGIN_TIP), enabled, "viewportEnabled")
    end

    if Settings.CreateColorSwatch then
        local setting = register(category, "viewportColor", "String", L.VIEWPORT_COLOR)
        dependsOn(Settings.CreateColorSwatch(category, setting, L.VIEWPORT_COLOR_TIP), enabled, "viewportEnabled")
    end
end

function SettingsPanel:Init()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterVerticalLayoutSubcategory
        and Settings.RegisterProxySetting) then
        return
    end
    local Page = ns.SettingsPage
    local main = Page.New(L.ADDON_TITLE)
    buildMain(main)
    local category = main:Register()

    local viewport = Settings.RegisterVerticalLayoutSubcategory(category, L.CATEGORY_VIEWPORT)
    addViewport(viewport)

    local actionBars = Page.New(L.CATEGORY_ACTION_BARS)
    buildActionBars(actionBars)
    actionBars:Register(category)

    local minimap = Page.New(L.CATEGORY_MINIMAP)
    buildMinimap(minimap)
    minimap:Register(category)

    Settings.RegisterAddOnCategory(category)
    self.category = category
    self.pages = { main = main, actionBars = actionBars, minimap = minimap }
end

function SettingsPanel:Open()
    if self.category and Settings.OpenToCategory then
        Settings.OpenToCategory(self.category:GetID())
    end
end
