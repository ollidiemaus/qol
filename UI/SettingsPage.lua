local _, ns = ...
local L = ns.L
local Options = ns.Options

-- A settings page of our own (a canvas in the Settings API) with the options in two columns, so a
-- page fits without scrolling. It looks like the game's own pages: the title with a Defaults
-- button, section headers, and each option as its name with a checkbox or a dropdown on the
-- right, from the game's own templates. Every name uses the same font; an option that belongs to
-- another one sits indented below it and is greyed out while it can't apply.
--
-- Every control reads and writes ns.Options, and the page follows Options:Watch, so it also shows
-- changes made elsewhere. All frames are ours: the settings panel only parents and shows the page,
-- and calls OnRefresh and OnDefault on it.
local Page = {}
Page.__index = Page
ns.SettingsPage = Page

local MARGIN = 8          -- between the page's sides and the columns
local GUTTER = 24         -- between the two columns
local TOP = 54            -- the title bar above the columns
local HEADER_HEIGHT = 36
local ROW_HEIGHT = 26
local LABEL_X = 7         -- names start where the section titles do
local INDENT = 15
local LABEL_GAP = 8       -- between a name and its control
local DROPDOWN_WIDTH = 160
local CONFIRM_SECONDS = 3
-- The room the settings panel gives a page (its default size), checked by the tests.
Page.MAX_HEIGHT = 600

local function fontColor(color, r, g, b)
    if color and color.GetRGB then return { color:GetRGB() } end
    return { r, g, b }
end

local function playToggle(checked)
    if PlaySound and SOUNDKIT then
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
end

local function tooltipFrame()
    return SettingsTooltip or GameTooltip
end

local function showTooltip(owner, title, text)
    local tooltip = tooltipFrame()
    if not (tooltip and text) then return end
    tooltip:SetOwner(owner, "ANCHOR_RIGHT")
    tooltip:SetText(title, 1, 1, 1)
    tooltip:AddLine(text, nil, nil, nil, true)
    tooltip:Show()
end

local function hideTooltip()
    local tooltip = tooltipFrame()
    if tooltip then tooltip:Hide() end
end

------------------------------------------------------------------------------------------------
-- The page

function Page.New(title)
    local frame = CreateFrame("Frame")
    frame:Hide()
    local page = setmetatable({ title = title, frame = frame, controls = {}, headers = {}, keys = {},
        y = { left = TOP, right = TOP } }, Page)

    local titleText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -22)
    titleText:SetJustifyH("LEFT")
    titleText:SetText(title)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", frame, "TOP", 0, -50)

    page:CreateDefaultsButton()

    -- The settings panel calls these: when it shows the page, and when the player resets all settings.
    function frame.OnRefresh() page:Refresh() end
    function frame.OnDefault() page:SetDefaults() end
    Options:Watch(function(key) return page.keys[key] ~= nil end, function()
        if frame:IsShown() then page:Refresh() end
    end)
    return page
end

-- Resets the page's options after a second click: the game asks before resetting too, with a
-- dialog of its own that addons can't use without spreading taint.
function Page:CreateDefaultsButton()
    local button = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    button:SetSize(96, 22)
    button:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -36, -16)
    local text = SETTINGS_DEFAULTS or L.DEFAULTS
    button:SetText(text)
    -- clicks counts the first clicks, so a timer only ends the confirmation it was started for.
    local confirming, clicks = false, 0
    local function stop()
        confirming = false
        button:SetText(text)
    end
    button:SetScript("OnClick", function()
        if confirming then
            stop()
            self:SetDefaults()
            return
        end
        confirming, clicks = true, clicks + 1
        local this = clicks
        button:SetText(L.DEFAULTS_CONFIRM)
        C_Timer.After(CONFIRM_SECONDS, function()
            if confirming and clicks == this then stop() end
        end)
    end)
    button:SetScript("OnEnter", function() showTooltip(button, text, L.DEFAULTS_TIP) end)
    button:SetScript("OnLeave", hideTooltip)
    self.frame:SetScript("OnHide", stop)
    self.defaultsButton = button
end

function Page:SetDefaults()
    for key in pairs(self.keys) do
        Options:Set(key, Options:GetDefault(key))
    end
    self:Refresh()
end

-- Shows the options' values, and greys out what can't apply.
function Page:Refresh()
    local normal = fontColor(NORMAL_FONT_COLOR, 1, 0.82, 0)
    local grey = fontColor(GRAY_FONT_COLOR, 0.5, 0.5, 0.5)
    for _, control in ipairs(self.controls) do
        local enabled = control.enabled == nil or control.enabled() == true
        local color = enabled and normal or grey
        control.text:SetTextColor(color[1], color[2], color[3])
        control.widget:SetEnabled(enabled)
        if control.kind == "checkbox" then
            control.widget:SetChecked(Options:Get(control.key) == true)
        else
            control.widget:GenerateMenu()
        end
    end
end

-- How far down the columns reach.
function Page:Height()
    return math.max(self.y.left, self.y.right)
end

-- Lets both columns go on at the same height (for sections that belong side by side).
function Page:Align()
    local y = self:Height()
    self.y.left, self.y.right = y, y
end

------------------------------------------------------------------------------------------------
-- Rows

local function newRow(page, column, height)
    local row = CreateFrame("Frame", nil, page.frame)
    local y = page.y[column]
    if column == "left" then
        row:SetPoint("TOPLEFT", page.frame, "TOPLEFT", MARGIN, -y)
        row:SetPoint("TOPRIGHT", page.frame, "TOP", -GUTTER / 2, -y)
    else
        row:SetPoint("TOPLEFT", page.frame, "TOP", GUTTER / 2, -y)
        row:SetPoint("TOPRIGHT", page.frame, "TOPRIGHT", -MARGIN, -y)
    end
    row:SetHeight(height)
    page.y[column] = y + height
    return row
end

function Page:Header(column, text, tooltip)
    local row = newRow(self, column, HEADER_HEIGHT)
    local title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", LABEL_X, 8)
    title:SetPoint("RIGHT", row, "RIGHT")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(text)
    if tooltip then
        row:EnableMouse(true)
        row:SetScript("OnEnter", function() showTooltip(row, text, tooltip) end)
        row:SetScript("OnLeave", hideTooltip)
    end
    self.headers[#self.headers + 1] = { column = column, text = text }
end

-- A row with an option's name, a hover highlight and its tooltip. options: indent (below the option
-- it belongs to), enabled (a function; the control is greyed out while it returns false).
local function optionRow(page, column, kind, key, label, tooltip, options)
    options = options or {}
    local row = newRow(page, column, ROW_HEIGHT)
    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints(row)
    highlight:SetColorTexture(1, 1, 1, 0.1)
    highlight:Hide()

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", row, "LEFT", LABEL_X + (options.indent and INDENT or 0), 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)

    local control = { kind = kind, key = key, label = label, tooltip = tooltip, column = column, row = row,
        text = text, indent = options.indent == true, enabled = options.enabled }
    function control.enter()
        highlight:Show()
        showTooltip(row, label, tooltip)
    end
    function control.leave()
        highlight:Hide()
        hideTooltip()
    end
    row:EnableMouse(true)
    row:SetScript("OnEnter", control.enter)
    row:SetScript("OnLeave", control.leave)
    page.controls[#page.controls + 1] = control
    page.keys[key] = true
    return control
end

function Page:Checkbox(column, key, label, tooltip, options)
    local control = optionRow(self, column, "checkbox", key, label, tooltip, options)
    local checkbox = CreateFrame("CheckButton", nil, control.row, "SettingsCheckboxTemplate")
    checkbox:SetPoint("RIGHT", control.row, "RIGHT", 0, 0)
    checkbox:SetScript("OnClick", function(button)
        local checked = button:GetChecked() and true or false
        Options:Set(key, checked)
        playToggle(checked)
    end)
    checkbox:SetScript("OnEnter", control.enter)
    checkbox:SetScript("OnLeave", control.leave)
    -- A click on the name toggles it too, as on the game's pages.
    control.row:SetScript("OnMouseUp", function()
        if checkbox:IsEnabled() then checkbox:Click() end
    end)
    control.text:SetPoint("RIGHT", checkbox, "LEFT", -LABEL_GAP, 0)
    control.widget = checkbox
    return control
end

-- choices: { { value = ..., label = ... }, ... } in the order the menu lists them.
function Page:Dropdown(column, key, label, choices, tooltip, options)
    local control = optionRow(self, column, "dropdown", key, label, tooltip, options)
    control.choices = choices
    local dropdown = CreateFrame("DropdownButton", nil, control.row, "WowStyle2DropdownTemplate")
    dropdown:SetWidth(DROPDOWN_WIDTH)
    dropdown:SetPoint("RIGHT", control.row, "RIGHT", 0, 0)
    dropdown:SetupMenu(function(_, root)
        local create = root.CreateHighlightRadio or root.CreateRadio
        for _, choice in ipairs(choices) do
            create(root, choice.label,
                function() return Options:Get(key) == choice.value end,
                function() Options:Set(key, choice.value) end)
        end
    end)
    dropdown:HookScript("OnEnter", control.enter)
    dropdown:HookScript("OnLeave", control.leave)
    control.text:SetPoint("RIGHT", dropdown, "LEFT", -LABEL_GAP, 0)
    control.widget = dropdown
    return control
end

-- The page's category in Options > AddOns, below parent when given.
function Page:Register(parent)
    if parent then
        return Settings.RegisterCanvasLayoutSubcategory(parent, self.frame, self.title)
    end
    return Settings.RegisterCanvasLayoutCategory(self.frame, self.title)
end
