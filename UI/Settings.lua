local _, ns = ...
local L = ns.L
local Options = ns.Options

-- Forever QoL's pages under Options > AddOns: the main page, plus Viewport and Action Bars as
-- subcategories. Every setting is a proxy onto ns.Options, so the page never owns data and the
-- features react through Options:Watch. Without the Settings API the page is skipped.
local SettingsPanel = {}
ns.SettingsPanel = SettingsPanel

local VIEWPORT_MAX_MARGIN = 600

local function varType(name)
    return Settings.VarType and Settings.VarType[name] or name:lower()
end

local function addHeader(layout, text, tooltip)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text, tooltip))
end

local function register(category, key, kind, label)
    return Settings.RegisterProxySetting(category, "ForeverQoL_" .. key, varType(kind), label,
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

local function addMain(category, layout)
    addHeader(layout, L.SECTION_MERCHANT)
    addCheckbox(category, "sellJunk", L.SELL_JUNK, L.SELL_JUNK_TIP)
    local repair = addCheckbox(category, "autoRepair", L.AUTO_REPAIR, L.AUTO_REPAIR_TIP)
    dependsOn(addCheckbox(category, "guildRepair", L.GUILD_REPAIR, L.GUILD_REPAIR_TIP), repair, "autoRepair")

    addHeader(layout, L.SECTION_TOOLTIPS)
    addCheckbox(category, "tooltipIDs", L.TOOLTIP_IDS, L.TOOLTIP_IDS_TIP)
    addCheckbox(category, "tooltipSellPrice", L.TOOLTIP_SELL_PRICE, L.TOOLTIP_SELL_PRICE_TIP)

    addHeader(layout, L.SECTION_INTERFACE)
    addCheckbox(category, "hideMicroMenu", L.HIDE_MICRO_MENU, L.HIDE_MICRO_MENU_TIP)
    addCheckbox(category, "hideBagsBar", L.HIDE_BAGS_BAR, L.HIDE_BAGS_BAR_TIP)
    addCheckbox(category, "hideMinimapCoords", L.HIDE_MINIMAP_COORDS, L.HIDE_MINIMAP_COORDS_TIP)
    addCheckbox(category, "hideChatSocial", L.HIDE_CHAT_SOCIAL, L.HIDE_CHAT_SOCIAL_TIP)
    addCheckbox(category, "showCombinedBagSort", L.SHOW_COMBINED_BAG_SORT, L.SHOW_COMBINED_BAG_SORT_TIP)

    addHeader(layout, L.SECTION_UNIT_FRAMES)
    addCheckbox(category, "classColorPlayer", L.CLASS_COLOR_PLAYER, L.CLASS_COLOR_TIP)
    addCheckbox(category, "classColorTarget", L.CLASS_COLOR_TARGET, L.CLASS_COLOR_TIP)
    addCheckbox(category, "classColorTargetOfTarget", L.CLASS_COLOR_TARGET_OF_TARGET, L.CLASS_COLOR_TIP)
    addCheckbox(category, "classColorFocus", L.CLASS_COLOR_FOCUS, L.CLASS_COLOR_TIP)
    addCheckbox(category, "classColorFocusTarget", L.CLASS_COLOR_FOCUS_TARGET, L.CLASS_COLOR_TIP)

    addHeader(layout, L.SECTION_COMMANDS)
    addCheckbox(category, "reloadCommand", L.RELOAD_COMMAND, L.RELOAD_COMMAND_TIP)
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

local function addActionBars(category, layout)
    local ActionBars = ns.ActionBars
    addHeader(layout, L.SECTION_FLIP_VERTICAL, L.FLIP_VERTICAL_TIP)
    for _, bar in ipairs(ActionBars.BARS) do
        addCheckbox(category, ActionBars.VerticalKey(bar.frame), bar.label(), L.FLIP_VERTICAL_TIP)
    end
    addHeader(layout, L.SECTION_FLIP_HORIZONTAL, L.FLIP_HORIZONTAL_TIP)
    for _, bar in ipairs(ActionBars.BARS) do
        addCheckbox(category, ActionBars.HorizontalKey(bar.frame), bar.label(), L.FLIP_HORIZONTAL_TIP)
    end
end

function SettingsPanel:Init()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting) then
        return
    end
    local category, layout = Settings.RegisterVerticalLayoutCategory(L.ADDON_TITLE)
    addMain(category, layout)

    local viewport = Settings.RegisterVerticalLayoutSubcategory(category, L.CATEGORY_VIEWPORT)
    addViewport(viewport)

    local actionBars, actionBarsLayout = Settings.RegisterVerticalLayoutSubcategory(category, L.CATEGORY_ACTION_BARS)
    addActionBars(actionBars, actionBarsLayout)

    Settings.RegisterAddOnCategory(category)
    self.category = category
end

function SettingsPanel:Open()
    if self.category and Settings.OpenToCategory then
        Settings.OpenToCategory(self.category:GetID())
    end
end
