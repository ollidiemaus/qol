local _, ns = ...
local L = ns.L
local Options = ns.Options

-- A page of the settings window (UI/SettingsWindow.lua) with the options in two columns, so a page
-- fits without scrolling, or in rows across the whole page ("wide", for sliders). It looks like the
-- game's own settings pages: the title with a Defaults button, section headers, and each option as
-- its name with a checkbox, a dropdown, a slider, a color swatch or a text box, from the game's own
-- templates, a key binding's two keys, as in the game's Key Bindings, or a button that opens
-- something. A few lines of text can say what a page's options are for. Every name uses the same
-- font; an option that belongs to another one sits indented below it and is greyed out while it
-- can't apply. A page that is one thing of its own below its title (the rings' editor) can have its
-- switch in the title bar instead of the Defaults button ("title").
--
-- A row with a value (all but a key binding and a button) gets, sets and resets it with functions
-- of its own, so the page and its Defaults button needn't know where the value is kept. An option's
-- row keeps it in ns.Options, and the page follows Options:Watch, so it also shows changes made
-- elsewhere; a row can be backed by something else instead. The window parents and shows the page,
-- and refreshes it when it does.
local Page = {}
Page.__index = Page
ns.SettingsPage = Page

local MARGIN = 8          -- between the page's sides and the columns
local GUTTER = 24         -- between the two columns
local TOP = 54            -- the title bar above the columns
local HEADER_HEIGHT = 36
local SECTION_GAP = 16    -- above a section that follows another one, so each reads as a group
local ROW_HEIGHT = 26
local LABEL_X = 7         -- names start where the section titles do
local INDENT = 15
local LABEL_GAP = 8       -- between a name and its control
local DROPDOWN_WIDTH = 160
local SLIDER_WIDTH = 250
local SLIDER_VALUE_ROOM = 50 -- right of a slider in a column, for its value
local NUMBER_WIDTH = 36      -- a slider's box for its value, in that room
local BOX_ART_LEFT = 5       -- InputBoxTemplate's left edge art reaches this far left of the box
local WIDE_CONTROL_X = -80   -- in a wide row the control starts there from the middle, as on the game's list
local TITLE_ROW_Y, TITLE_ROW_RIGHT, TITLE_ROW_WIDTH = 14, 28, 300 -- an option in the title bar
local KEY_WIDTH, KEY_HEIGHT = 160, 22 -- a key binding's buttons, as in the game's Key Bindings
local BUTTON_WIDTH, BUTTON_HEIGHT = 160, 22
local TEXT_WIDTH, TEXT_HEIGHT = 160, 20
local TEXT_TOP = 12      -- above a paragraph, between it and the title's divider
local CONFIRM_SECONDS = 3
-- The room the settings window gives a page (as the game's settings do), checked by the tests.
Page.MAX_HEIGHT = 600
-- Where the rows start, below the title and its divider.
Page.TOP = TOP

-- Key binding rows: the frame of ours that takes the keyboard while a button waits for a key, and
-- { control, slot } of that button.
local listener, waiting

local function fontColor(color, r, g, b)
    if color and color.GetRGB then return { color:GetRGB() } end
    return { r, g, b }
end

local function playToggle(checked)
    if PlaySound and SOUNDKIT then
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
end

local function showTooltip(owner, title, text)
    if not text then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    GameTooltip:AddLine(text, nil, nil, nil, true)
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

------------------------------------------------------------------------------------------------
-- The page

-- options: defaults (false for a page without a Defaults button).
function Page.New(title, options)
    local frame = CreateFrame("Frame")
    frame:Hide()
    local page = setmetatable({ title = title, frame = frame, controls = {}, headers = {}, texts = {}, keys = {},
        y = { left = TOP, right = TOP } }, Page)

    local titleText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -22)
    titleText:SetJustifyH("LEFT")
    titleText:SetText(title)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", frame, "TOP", 0, -50)

    if not (options and options.defaults == false) then page:CreateDefaultsButton() end

    -- Leaving the page (or closing the window) stops waiting for a key.
    frame:HookScript("OnHide", function()
        if waiting and waiting.control.page == page then page:StopWaiting() end
        page:Say(nil)
    end)
    Options:Watch(function(key) return page.keys[key] ~= nil end, function()
        if frame:IsVisible() then page:Refresh() end
    end)
    return page
end

-- Resets the page's rows after a second click: the game asks before resetting too, with a
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
    for _, control in ipairs(self.controls) do
        if control.reset then control.reset() end
    end
    self:Refresh()
end

-- Shows the rows' values, and greys out what can't apply.
function Page:Refresh()
    local normal = fontColor(NORMAL_FONT_COLOR, 1, 0.82, 0)
    local grey = fontColor(GRAY_FONT_COLOR, 0.5, 0.5, 0.5)
    local white = fontColor(HIGHLIGHT_FONT_COLOR, 1, 1, 1)
    for _, control in ipairs(self.controls) do
        local enabled = control.enabled == nil or control.enabled() == true
        local color = enabled and normal or grey
        control.text:SetText(control.name())
        control.text:SetTextColor(color[1], color[2], color[3])
        control.widget:SetEnabled(enabled)
        if control.kind == "checkbox" then
            control.widget:SetChecked(control.get() == true)
        elseif control.kind == "slider" then
            control.refreshing = true
            control.widget:SetValue(control.get())
            control.refreshing = false
        elseif control.kind == "color" then
            control.widget:SetColorRGB(Page.ParseColor(control.get()))
            control.widget:SetAlpha(enabled and 1 or 0.5)
        elseif control.kind == "binding" then
            control.refreshKeys(enabled)
        elseif control.kind == "dropdown" then
            control.widget:GenerateMenu()
        end
        if control.box then
            -- A disabled box doesn't grey its text itself.
            local boxColor = enabled and white or grey
            control.box:SetEnabled(enabled)
            control.box:SetTextColor(boxColor[1], boxColor[2], boxColor[3])
            if not control.box:HasFocus() then control.box:SetText(control.boxCurrent()) end
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

-- column: "left", "right", "wide" (across both, below what either holds so far) or "title" (in the
-- title bar).
local function newRow(page, column, height)
    local row = CreateFrame("Frame", nil, page.frame)
    if column == "title" then
        -- In the title bar, where the other pages have their Defaults button; the rows below don't move.
        row:SetPoint("TOPRIGHT", page.frame, "TOPRIGHT", -TITLE_ROW_RIGHT, -TITLE_ROW_Y)
        row:SetSize(TITLE_ROW_WIDTH, height)
        return row
    end
    if column == "wide" then
        local y = page:Height()
        row:SetPoint("TOPLEFT", page.frame, "TOPLEFT", MARGIN, -y)
        row:SetPoint("TOPRIGHT", page.frame, "TOPRIGHT", -MARGIN, -y)
        row:SetHeight(height)
        page.y.left, page.y.right = y + height, y + height
        return row
    end
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

-- Leaves SECTION_GAP free in a column (in "wide", below both) that already has rows.
local function sectionGap(page, column)
    if column == "wide" then
        local y = page:Height()
        if y > TOP then page.y.left, page.y.right = y + SECTION_GAP, y + SECTION_GAP end
    elseif page.y[column] and page.y[column] > TOP then
        page.y[column] = page.y[column] + SECTION_GAP
    end
end

function Page:Header(column, text, tooltip)
    sectionGap(self, column)
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

-- How an option's row gets, sets and resets its value: through ns.Options, by the option's key.
local function optionBacking(key)
    return {
        get = function() return Options:Get(key) end,
        set = function(value) Options:Set(key, value) end,
        reset = function() Options:Set(key, Options:GetDefault(key)) end,
    }
end

-- A row with an option's name, a hover highlight and its tooltip. label: the name, or a function
-- giving it (asked again on each refresh). options: indent (below the option it belongs to), enabled
-- (a function; the control is greyed out while it returns false), title (the tooltip's, instead of
-- the name). key: the option, or for a value kept elsewhere { get = function, set = function(value),
-- reset = function }, where get gives what the control shows (a checkbox's true or false) and reset
-- is what the Defaults button does; nil for a key binding or a button. The row gets, sets and resets
-- its value with control.get, control.set and control.reset.
local function optionRow(page, column, kind, key, label, tooltip, options)
    options = options or {}
    local row = newRow(page, column, ROW_HEIGHT)
    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints(row)
    highlight:SetColorTexture(1, 1, 1, 0.1)
    highlight:Hide()

    local function name()
        if type(label) == "function" then return label() end
        return label
    end
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", row, "LEFT", LABEL_X + (options.indent and INDENT or 0), 0)
    -- In the title bar the name goes next to its control.
    text:SetJustifyH(column == "title" and "RIGHT" or "LEFT")
    text:SetWordWrap(false)
    text:SetText(name())

    local backing = key
    if type(key) == "string" then
        backing = optionBacking(key)
        page.keys[key] = true
    else
        key = nil
    end
    local control = { kind = kind, key = key, name = name, tooltip = tooltip, column = column, row = row,
        text = text, indent = options.indent == true, enabled = options.enabled, page = page }
    if backing then control.get, control.set, control.reset = backing.get, backing.set, backing.reset end
    function control.title() return options.title or name() end
    function control.enter()
        highlight:Show()
        showTooltip(row, control.title(), tooltip)
    end
    function control.leave()
        highlight:Hide()
        hideTooltip()
    end
    row:EnableMouse(true)
    row:SetScript("OnEnter", control.enter)
    row:SetScript("OnLeave", control.leave)
    page.controls[#page.controls + 1] = control
    return control
end

-- Puts an option's control at the right of its row (in a wide row, where the game's list has it),
-- with its name ending before it.
local function place(control, widget, rightSpace)
    if control.column == "wide" then
        widget:SetPoint("LEFT", control.row, "CENTER", WIDE_CONTROL_X, 0)
    else
        widget:SetPoint("RIGHT", control.row, "RIGHT", -(rightSpace or 0), 0)
    end
    control.text:SetPoint("RIGHT", widget, "LEFT", -LABEL_GAP, 0)
    control.widget = widget
end

-- The number of decimals a slider's step has: none for whole steps, at most 6 (to allow for the
-- float error in a step like 0.1).
local function decimalsOf(step)
    local decimals = 0
    while decimals < 6 and math.abs(step * 10 ^ decimals - math.floor(step * 10 ^ decimals + 0.5)) > 1e-9 do
        decimals = decimals + 1
    end
    return decimals
end

-- A row's input box, which commit(text) reads when it loses the keyboard (Enter, Tab, a click
-- elsewhere); then, and on Escape, it shows current() again, what the row now has. A refresh leaves it
-- alone while it has the keyboard. Tab and Shift+Tab go on to the page's next and previous box (the
-- template's EditBox_OnTabPressed reads nextEditBox and previousEditBox).
local function newTextBox(page, control, width, commit, current)
    local box = CreateFrame("EditBox", nil, control.row, "InputBoxTemplate")
    box:SetSize(width, TEXT_HEIGHT)
    box:SetAutoFocus(false)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", function()
        box:SetText(current())
        box:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function()
        box:HighlightText(0, 0)
        commit(box:GetText() or "")
        box:SetText(current())
    end)
    box:SetScript("OnEnter", control.enter)
    box:SetScript("OnLeave", control.leave)
    if page.lastTextBox then
        page.lastTextBox.nextEditBox, box.previousEditBox = box, page.lastTextBox
    end
    page.lastTextBox = box
    control.box, control.boxCurrent = box, current
    return box
end

function Page:Checkbox(column, key, label, tooltip, options)
    local control = optionRow(self, column, "checkbox", key, label, tooltip, options)
    local checkbox = CreateFrame("CheckButton", nil, control.row, "SettingsCheckboxTemplate")
    checkbox:SetScript("OnClick", function(button)
        local checked = button:GetChecked() and true or false
        control.set(checked)
        playToggle(checked)
    end)
    checkbox:SetScript("OnEnter", control.enter)
    checkbox:SetScript("OnLeave", control.leave)
    -- A click on the name toggles it too, as on the game's pages.
    control.row:SetScript("OnMouseUp", function()
        if checkbox:IsEnabled() then checkbox:Click() end
    end)
    place(control, checkbox)
    return control
end

-- The choice after value, back to the first after the last.
local function nextChoice(value, choices)
    for index, choice in ipairs(choices) do
        if choice.value == value then
            return choices[index % #choices + 1]
        end
    end
    return choices[1]
end

-- choices: { { value = ..., label = ... }, ... } in the order the menu lists them.
-- With Forever's controller interface on, a click steps to the next choice instead of opening the
-- game's menu: in that interface the menu brings controller wiring of its own (a prompted binding
-- footer, binding groups, suspending the focus of the window that has the controller), and the
-- game stopped responding when its settings closed after one was opened from our page, back when
-- the pages were in them (see docs/DEVELOPMENT.md).
function Page:Dropdown(column, key, label, choices, tooltip, options)
    local control = optionRow(self, column, "dropdown", key, label, tooltip, options)
    control.choices = choices
    local dropdown = CreateFrame("DropdownButton", nil, control.row, "WowStyle2DropdownTemplate")
    dropdown:SetWidth(DROPDOWN_WIDTH)
    dropdown:SetupMenu(function(_, root)
        local create = root.CreateHighlightRadio or root.CreateRadio
        for _, choice in ipairs(choices) do
            create(root, choice.label,
                function() return control.get() == choice.value end,
                function() control.set(choice.value) end)
        end
    end)
    local openMenu = dropdown.OpenMenu
    function dropdown:OpenMenu(...)
        if not ns.IsControllerUI() then return openMenu(self, ...) end
        if self:IsEnabled() then control.set(nextChoice(control.get(), choices).value) end
    end
    dropdown:HookScript("OnEnter", control.enter)
    dropdown:HookScript("OnLeave", control.leave)
    place(control, dropdown)
    return control
end

-- A value from minValue to maxValue in steps of options.step (1 when not given), one step per click
-- on its arrows. format turns the value into the text shown right of the slider (L.PIXELS, for one).
-- With options.textBox (and no format) the value is in a box there instead, where an exact one can be typed: a
-- number is set to the nearest step in range, anything else puts back the value.
function Page:Slider(column, key, label, minValue, maxValue, format, tooltip, options)
    local control = optionRow(self, column, "slider", key, label, tooltip, options)
    local step = options and options.step or 1
    local decimals = decimalsOf(step)
    local function show(value) return string.format("%." .. decimals .. "f", value) end
    -- To the nearest step, through show so 0.1 steps don't drift (0.30000000000000004).
    local function round(value)
        value = minValue + math.floor((value - minValue) / step + 0.5) * step
        return math.max(minValue, math.min(maxValue, tonumber(show(value))))
    end
    local slider = CreateFrame("Frame", nil, control.row, "MinimalSliderWithSteppersTemplate")
    -- The template is taller than a row; at a row's height it doesn't take the mouse from the next.
    slider:SetSize(SLIDER_WIDTH, ROW_HEIGHT)
    local formatters = {}
    if format and not (options and options.textBox) then
        formatters[MinimalSliderWithSteppersMixin.Label.Right] = function(value) return format(round(value)) end
    end
    slider:Init(control.get(), minValue, maxValue, math.floor((maxValue - minValue) / step + 0.5), formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if control.refreshing then return end
        control.set(round(value))
        if control.box then control.box:SetText(control.boxCurrent()) end
    end, control)
    for _, part in ipairs({ slider, slider.Slider, slider.Back, slider.Forward }) do
        part:HookScript("OnEnter", control.enter)
        part:HookScript("OnLeave", control.leave)
    end
    place(control, slider, SLIDER_VALUE_ROOM)
    if options and options.textBox then
        -- Through the slider, so a typed value goes where a dragged one does; the same value sets nothing.
        local box = newTextBox(self, control, NUMBER_WIDTH, function(text)
            local number = tonumber(strtrim(text))
            if number then slider:SetValue(round(number)) end
        end, function() return show(control.get()) end)
        box:SetPoint("LEFT", slider, "RIGHT", LABEL_GAP + BOX_ART_LEFT, 0)
    end
    return control
end

-- "AARRGGBB", the format the game's color swatches save, to r, g, b from 0 to 1.
function Page.ParseColor(hex)
    if type(hex) == "string" and #hex == 8 then
        local r, g, b = tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), tonumber(hex:sub(7, 8), 16)
        if r and g and b then return r / 255, g / 255, b / 255 end
    end
    return 0, 0, 0
end

function Page.FormatColor(r, g, b)
    local function byte(value) return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5) end
    return ("ff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- A color, saved as "AARRGGBB". A click opens the game's color picker; cancelling it puts the color
-- back. A click on the name opens it too.
function Page:Color(column, key, label, tooltip, options)
    local control = optionRow(self, column, "color", key, label, tooltip, options)
    local swatch = CreateFrame("Button", nil, control.row, "ColorSwatchTemplate")
    -- The template passes clicks on to its parent, the row, which would open the picker again.
    swatch:SetPropagateMouseClicks(false)
    local function pick()
        local r, g, b = Page.ParseColor(control.get())
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() control.set(Page.FormatColor(ColorPickerFrame:GetColorRGB())) end,
            cancelFunc = function() control.set(Page.FormatColor(ColorPickerFrame:GetPreviousValues())) end,
        })
    end
    swatch:SetScript("OnClick", pick)
    swatch:HookScript("OnEnter", control.enter)
    swatch:HookScript("OnLeave", control.leave)
    control.row:SetScript("OnMouseUp", function()
        if swatch:IsEnabled() then pick() end
    end)
    place(control, swatch)
    return control
end

------------------------------------------------------------------------------------------------
-- Key bindings
--
-- A row works like one in the game's Key Bindings: two buttons with the command's keys. A click on
-- one waits for a key (a click on it again, or Escape, stops waiting), a right-click clears it.
-- While a button waits, a frame of ours above the window takes the keyboard, as the game's own
-- KeybindListener does. Gamepad buttons stay with the controller cursor, which needs them (in
-- Forever's controller interface A on the button again stops waiting); the Steam Deck's back
-- buttons send keys anyway. A key is taken from whatever had it, as in Key Bindings, and the
-- bindings are saved right away: the game's settings save them when they close, and these aren't
-- theirs. Not in combat.

-- The binding's context, as the game's Key Bindings pass it to GetBindingKey and SetBinding.
local function contextFor(command)
    local lookup = C_KeyBindings and C_KeyBindings.GetBindingContextForAction
    if lookup then return lookup(command) end
end

-- Puts key in the command's first or second slot, keeping its other key, like the game's
-- KeybindListener. Returns the command that had the key, if another one.
local function bind(command, slot, key)
    local context = contextFor(command)
    local key1, key2 = GetBindingKey(command, nil, context)
    local keys = { key1, key2 }
    for index = 1, 2 do
        if keys[index] then SetBinding(keys[index], nil, context) end
    end
    local previous = GetBindingAction(key, nil, context)
    SetBinding(key, nil, context)
    keys[slot] = key
    for index = 1, 2 do
        if keys[index] then SetBinding(keys[index], command, context) end
    end
    if previous ~= "" and previous ~= command then return previous end
end

local function unbind(command, slot)
    local context = contextFor(command)
    local key = select(slot, GetBindingKey(command, nil, context))
    if key then SetBinding(key, nil, context) end
end

-- As the game's settings do when they close: into the set in use (the account's or the
-- character's). It fires UPDATE_BINDINGS.
local function saveBindings()
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
end

function Page:StopWaiting()
    waiting = nil
    listener:Hide()
    self:Refresh()
end

local function keyPressed(key)
    if not waiting then return end
    local control, slot = waiting.control, waiting.slot
    local page = control.page
    if key == "ESCAPE" then
        page:StopWaiting()
        page:Say(nil)
        return
    end
    -- A modifier alone: wait for the key that goes with it.
    if IsKeyPressIgnoredForBinding(key) then return end
    local chord = CreateKeyChordStringUsingMetaKeyState(key)
    local previous = bind(control.command, slot, chord)
    saveBindings()
    page:StopWaiting()
    if previous then
        page:Say(L.BINDING_MOVED:format(GetBindingText(chord), control.title(), GetBindingName(previous)))
    else
        page:Say(L.BINDING_SET:format(GetBindingText(chord), control.title()))
    end
end

local function newListener()
    local frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(_, key) keyPressed(key) end)
    ns.Events:On("PLAYER_REGEN_DISABLED", function()
        if not waiting then return end
        local page = waiting.control.page
        page:StopWaiting()
        page:Say(L.BINDING_COMBAT)
    end)
    return frame
end

local function bindingClicked(control, slot, mouseButton)
    local page = control.page
    if InCombatLockdown() then
        page:Say(L.BINDING_COMBAT)
        return
    end
    if mouseButton == "RightButton" then
        unbind(control.command, slot)
        saveBindings()
        page:StopWaiting()
        page:Say(nil)
    elseif mouseButton == "LeftButton" then
        local again = waiting and waiting.control == control and waiting.slot == slot
        if again then
            page:StopWaiting()
            page:Say(nil)
            return
        end
        waiting = { control = control, slot = slot }
        listener:Show()
        page:Refresh()
        page:Say(L.BINDING_WAIT:format(control.title()))
    end
end

-- The key in a binding button, or "Not Bound" in grey, as the game's Key Bindings show them.
local function showKey(button, key)
    if key then
        button:SetText(GetBindingText(key))
        button:SetAlpha(1)
    else
        button:SetText("|cff808080" .. (NOT_BOUND or L.NOT_BOUND) .. "|r")
        button:SetAlpha(0.8)
    end
end

-- A binding command's two keys (command as Bindings.xml names it). label may be a function, for a
-- name that follows an option; options.title then names the binding in its tooltip and the note.
function Page:Binding(column, command, label, tooltip, options)
    local control = optionRow(self, column, "binding", nil, label, tooltip, options)
    control.command, control.buttons = command, {}
    listener = listener or newListener()
    for slot = 1, 2 do
        local button = CreateFrame("Button", nil, control.row, "KeyBindingFrameBindingButtonTemplate")
        button:SetSize(KEY_WIDTH, KEY_HEIGHT)
        button:SetScript("OnClick", function(_, mouseButton) bindingClicked(control, slot, mouseButton) end)
        button:SetScript("OnEnter", control.enter)
        button:SetScript("OnLeave", control.leave)
        control.buttons[slot] = button
    end
    control.buttons[2]:SetPoint("LEFT", control.buttons[1], "RIGHT", 0, 0)
    function control.refreshKeys(enabled)
        if not enabled and waiting and waiting.control == control then
            waiting = nil
            listener:Hide()
            control.page:Say(nil)
        end
        local keys = { GetBindingKey(command, nil, contextFor(command)) }
        for slot, button in ipairs(control.buttons) do
            button:SetEnabled(enabled)
            showKey(button, keys[slot])
            button:SetSelected(waiting ~= nil and waiting.control == control and waiting.slot == slot)
        end
    end
    place(control, control.buttons[1], KEY_WIDTH)
    return control
end

-- A line of text (a character's name), in the game's input box. It's saved without spaces around it.
function Page:TextBox(column, key, label, tooltip, options)
    local control = optionRow(self, column, "text", key, label, tooltip, options)
    local box = newTextBox(self, control, TEXT_WIDTH, function(text) control.set(strtrim(text)) end, control.get)
    place(control, box)
    return control
end

-- A button named text, for something that isn't an option (onClick does it).
function Page:Button(column, label, text, tooltip, onClick, options)
    local control = optionRow(self, column, "button", nil, label, tooltip, options)
    local button = CreateFrame("Button", nil, control.row, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", control.enter)
    button:SetScript("OnLeave", control.leave)
    place(control, button)
    return control
end

-- A few lines that say what the options below are for, wrapped to the column. The text is
-- measured at the column's width (the window's page less the margins) to know the row's height.
function Page:Text(column, text)
    local width = ns.SettingsWindow.PAGE_WIDTH - 2 * MARGIN
    if column ~= "wide" then width = (width - GUTTER) / 2 end
    local paragraph = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    paragraph:SetWidth(width - LABEL_X)
    paragraph:SetJustifyH("LEFT")
    paragraph:SetText(text)
    sectionGap(self, column)
    local row = newRow(self, column, TEXT_TOP + paragraph:GetStringHeight())
    paragraph:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_X, -TEXT_TOP)
    self.texts[#self.texts + 1] = { column = column, text = text, string = paragraph }
end

-- A line of small text below the key bindings: hint while nothing happens, else what they report.
function Page:Note(column, hint)
    local row = newRow(self, column, ROW_HEIGHT)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", row, "LEFT", LABEL_X, 0)
    text:SetPoint("RIGHT", row, "RIGHT")
    text:SetJustifyH("LEFT")
    self.note, self.hint = text, hint
    self:Say(nil)
end

function Page:Say(message)
    if self.note then self.note:SetText(message or self.hint) end
end
