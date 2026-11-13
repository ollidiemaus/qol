local _, ns = ...
local Options = ns.Options
local L = ns.L

-- Buttons on Forever's controller action bar for a controller's back buttons (the Steam Deck's L4,
-- L5, R4 and R5), four for each controller bar: Top, Left (LT), Right (RT) and Bottom (LT and RT).
-- Each controller bar's four use the last four slots of an action bar the player picks (2 to 8; the
-- controller bar's own slots stay as they are), so a spell goes on one by dragging it there, or onto
-- that action bar's buttons 9 to 12. The slots are the same on every controller page.
--
-- The game sees a back button as whatever key the controller sends: the Steam Deck's as the keys
-- picked for them in Steam Input, controllers with paddles as PADPADDLE1 to 4. Secure code can't
-- tell which trigger is held (Forever's triggers aren't modifiers, ADR 0006), so each of the 16
-- buttons has a key of its own (the commands in Bindings.xml): Steam Input sends another key for a
-- back button while a trigger is held (ADR 0007). Only Top's fall back to the paddle keys.
--
-- The buttons are secure action buttons, on a holder of ours per bar under a frame of ours that's a
-- child of GamepadMainActionBarFrame, so they hide, scale and fade with the bar. In the full layout
-- the holders sit on the page unit, the buttons in a cross per back button at its far left and
-- right; in the compact layout on their bar's anchor (which only Edit Mode moves, out of combat),
-- all on the one spot. The bar in use is the game's active bar, which its own Lua picks by the
-- triggers held: the page unit's ACTIVE_ACTION_BAR_UPDATED_EVENT says when it changes, and our art
-- follows in combat too (the bar in use's full size, the others' small; in the compact layout only
-- the bar in use's art shows). A holder shows while the game shows something in its bar's place
-- (the bar, or the stance or possess bar over it, but not the special page). Plain frames of ours on
-- the game's bars tell us when those show or hide; nothing of the game's is written, called or
-- hooked. Creating the buttons, their attributes, the holders shown, the mouse and the override
-- bindings wait for combat to end.
local BackButtons = {}
ns.BackButtons = BackButtons

local KEY = "controllerBackButtons"
-- The controller bars, by the names the trigger toggle gives the bar in use (none is Top).
local BARS = { "top", "left", "right", "bottom" }
BackButtons.BARS = BARS
local BAR_NAMES = { top = "Top", left = "Left", right = "Right", bottom = "Bottom" }
local ANCHORS = { top = "TopCenteredAnchor", left = "LeftCenteredAnchor", right = "RightCenteredAnchor",
    bottom = "BottomCenteredAnchor" }
-- What can show in a bar's place: the bar itself, or the stance or possess bar the game puts on its
-- anchor. The possess bar on the special page doesn't count: the bars are all hidden there.
local PLACE_BARS = { "topBar", "leftBar", "rightBar", "bottomBar", "stanceBar", "possessBar" }
-- Action Bars 2 to 8 by their page of action slots (MultiActionBars.lua); the back buttons take
-- buttons 9 to 12.
local PAGES = { [2] = 6, [3] = 5, [4] = 3, [5] = 4, [6] = 13, [7] = 14, [8] = 15 }
local FIRST = 8
-- The controller bar's round buttons at full size, the size of a bar not in use (the game's
-- collapsed and expanded sizes, ActionBarStyles.lua), and how much smaller one is while pressed.
local SIZE = 38
local SMALL = 30
local PRESSED = 4
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- In the order of the bindings. side: -1 left, 1 right. paddle: the key a controller with paddles
-- sends (SDL's numbering: 1 and 3 under the right hand, 2 and 4 under the left).
BackButtons.BUTTONS = {
    { label = "L4", side = -1, paddle = "PADPADDLE2" },
    { label = "L5", side = -1, paddle = "PADPADDLE4" },
    { label = "R4", side = 1, paddle = "PADPADDLE1" },
    { label = "R5", side = 1, paddle = "PADPADDLE3" },
}
local BUTTONS = BackButtons.BUTTONS

-- Where each button sits, and where its name goes. Above Top and below Bottom are the game's LB and
-- RB prompts and page tracker, and the bars interlock, so the full layout puts all 16 past the far
-- left and right of the page unit, from its centre: a cross per back button, L4's upper left, L5's
-- lower left, R4's upper right, R5's lower right, its name in the middle. A cross holds that back
-- button on each bar where the game's cross of bars has the bar: Top up, Left (LT) left, Right (RT)
-- right, Bottom (LT and RT) down. The compact layout shows one bar's, from its anchor: L4 and L5
-- left of it, R4 and R5 right, their names beside them. docs/dev/controller.md has the numbers.
local COLUMN_X, COMPACT_Y = 182, 26
-- The crosses' middles: CROSS_X out from the centre, CROSS_Y above and below a line CROSS_DOWN
-- under it (the bars' cross sits low on the page unit).
local CROSS_X, CROSS_Y, CROSS_DOWN = 365, 50, 20
local ARMS = { top = { 0, 27 }, left = { -31, 0 }, right = { 31, 0 }, bottom = { 0, -27 } }
local LAYOUTS = { full = {}, compact = {} }
-- By back button: the middle of its cross in the full layout.
local CROSSES = {}
for index, info in ipairs(BUTTONS) do
    LAYOUTS.compact[index] = { x = info.side * COLUMN_X, y = index % 2 == 1 and COMPACT_Y or -COMPACT_Y,
        label = info.side < 0 and "LEFT" or "RIGHT" }
    CROSSES[index] = { x = info.side * CROSS_X, y = (index % 2 == 1 and CROSS_Y or -CROSS_Y) - CROSS_DOWN }
end
for _, bar in ipairs(BARS) do
    LAYOUTS.full[bar] = {}
    for index in ipairs(BUTTONS) do
        local cross, arm = CROSSES[index], ARMS[bar]
        LAYOUTS.full[bar][index] = { x = cross.x + arm[1], y = cross.y + arm[2], label = "NONE" }
    end
end

-- A back button's button on a controller bar. Top's keep the names they had when there was only
-- Top, so that the keys bound to them stay.
function BackButtons.Name(bar, index)
    return "QoLBackButton" .. (bar == "top" and "" or BAR_NAMES[bar]) .. index
end

-- The binding command of a back button's key on a bar, as Bindings.xml names it.
function BackButtons.Command(bar, index)
    return ns.Buttons.Command(BackButtons.Name(bar, index))
end

-- The option with the action bar a controller bar's back buttons use.
function BackButtons.BarOption(bar)
    return "controllerBackButtonsBar" .. BAR_NAMES[bar]
end

local function actionBar(bar)
    return Options:Get(BackButtons.BarOption(bar))
end

function BackButtons.Slot(bar, index)
    return (PAGES[bar] or PAGES[8]) * 12 - 12 + FIRST + index
end

-- Which of its action bar's buttons a back button is (9 to 12).
function BackButtons.BarButton(index)
    return FIRST + index
end

-- Names in the Key Bindings window.
BINDING_HEADER_QOL = L.ADDON_TITLE
for _, bar in ipairs(BARS) do
    for index, info in ipairs(BUTTONS) do
        local name = L["BACK_BUTTON_" .. info.label]
        if bar ~= "top" then name = L.BACK_BUTTON_ON_BAR:format(name, L["CONTROLLER_BAR_" .. bar:upper()]) end
        _G["BINDING_NAME_" .. BackButtons.Command(bar, index)] = name
    end
end

-- Only in the controller interface: with keyboard and mouse the buttons hide, their keys press
-- nothing (a button without a type does nothing) and our override bindings are gone.
local function isOn()
    return Options:Get(KEY) == true and GamepadMainActionBarFrame ~= nil and ns.IsControllerUI()
end

local root
-- By bar: the holder and its four buttons.
local groups = {}
-- By back button: its name in the middle of its cross (the full layout).
local crossLabels = {}
-- The compact layout, as the last update found it.
local compactLayout = false

-- The bar in use: the place of the game's active bar (the bar its triggers picked, or the stance or
-- possess bar over it). Read from the game's frames, never written.
local function barInUse()
    local pageUnit = GamepadMainActionBarFrame.PageUnit
    local active = pageUnit and pageUnit.GetActiveBar and pageUnit:GetActiveBar()
    local parent = active and active:GetParent()
    for _, bar in ipairs(BARS) do
        if parent and pageUnit[ANCHORS[bar]] == parent then return bar end
    end
    return "top"
end

---------------------------------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------------------------------

-- The art's size: full for the bar in use, small for the others (as the game's bars), and smaller
-- while pressed. Only regions and frames of ours inside the secure button change, so in combat too.
local function sizeVisual(button)
    local size = button.size - (button.pressed and PRESSED or 0)
    button.visual:SetSize(size, size)
    button.visual:ClearAllPoints()
    button.visual:SetPoint("CENTER", 0, button.pressed and -PRESSED / 2 or 0)
end

local function setPressed(button, down)
    if button.pressed == down then return end
    button.pressed = down
    sizeVisual(button)
    button.pushedRim:SetShown(down)
end

-- The bar in use's buttons at full size, the others small. In the compact layout every bar's sit in
-- the same spots and only the bar in use's art shows, at full size: the buttons are protected and
-- can't show or hide in combat, their art can.
local function highlight()
    if not root then return end
    local inUse = barInUse()
    for bar, group in pairs(groups) do
        local current = bar == inUse
        local size = (compactLayout or current) and SIZE or SMALL
        local alpha = (current or not compactLayout) and 1 or 0
        for _, button in ipairs(group.buttons) do
            if button.size ~= size then
                button.size = size
                sizeVisual(button)
            end
            button.visual:SetAlpha(alpha)
        end
    end
end

-- The button's name beside it, on its outer side (the compact layout); NONE in a cross, whose name
-- is in its middle.
local LABEL_POINTS = {
    LEFT = { "RIGHT", "LEFT", -2, 0 },
    RIGHT = { "LEFT", "RIGHT", 2, 0 },
}

local function placeLabel(button, side)
    if button.labelSide == side then return end
    button.labelSide = side
    local point = LABEL_POINTS[side]
    button.label:SetShown(point ~= nil)
    if not point then return end
    button.label:ClearAllPoints()
    button.label:SetPoint(point[1], button, point[2], point[3], point[4])
end

-- The controller bar's round button, on regions of our own: drop shadow, dark empty slot, round
-- icon and its cooldown, and above them the rim (pressed, pointed at, or current or repeating
-- action), the count and the button's name.
local function decorate(button, info)
    local visual = CreateFrame("Frame", nil, button)
    visual:SetPoint("CENTER")
    visual:SetSize(SIZE, SIZE)
    button.visual = visual

    local shadow = visual:CreateTexture(nil, "BACKGROUND", nil, -2)
    shadow:SetPoint("TOPLEFT", -4, 4)
    shadow:SetPoint("BOTTOMRIGHT", 4, -4)
    shadow:SetAtlas("gamepad-actionbar-circleslot-dropshadow")
    local empty = visual:CreateTexture(nil, "BACKGROUND", nil, -1)
    empty:SetPoint("TOPLEFT", 3, -3)
    empty:SetPoint("BOTTOMRIGHT", -3, 3)
    empty:SetTexture(ROUND)
    empty:SetVertexColor(0, 0, 0, 0.6)

    local icon = visual:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(empty)
    local mask = visual:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetAtlas("CircleMask")
    icon:AddMaskTexture(mask)
    icon:Hide()
    button.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, visual, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetSwipeTexture(ROUND)
    cooldown:SetSwipeColor(0, 0, 0, 0.7)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
    button.cooldown = cooldown

    local over = CreateFrame("Frame", nil, visual)
    over:SetAllPoints()
    over:SetFrameLevel(cooldown:GetFrameLevel() + 2)
    local function rim(atlas, sublevel)
        local texture = over:CreateTexture(nil, "ARTWORK", nil, sublevel)
        texture:SetAllPoints()
        texture:SetAtlas(atlas)
        if sublevel > 0 then texture:Hide() end
        return texture
    end
    rim("gamepad-actionbar-circleslot-border-normal", 0)
    button.selectedRim = rim("gamepad-actionbar-circleslot-border-selected", 1)
    button.hoverRim = rim("gamepad-actionbar-circleslot-border-hover", 2)
    button.pushedRim = rim("gamepad-actionbar-circleslot-border-pressed", 3)
    button.count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)

    button.label = over:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetText(info.label)
end

-- The slot's art, and the selected rim while its action is current or repeating.
local function refreshButton(button)
    local slot = button.slot
    local current = ns.Buttons.RefreshAction(button, slot)
        and (C_ActionBar.IsCurrentAction(slot) or C_ActionBar.IsAutoRepeatAction(slot))
    button.selectedRim:SetShown(ns.IsUsable(current) and current == true)
end

-- The shown bars' buttons only.
function BackButtons:Refresh()
    if not (root and root:IsShown()) then return end
    for _, bar in ipairs(BARS) do
        local group = groups[bar]
        if group.holder:IsShown() then
            for _, button in ipairs(group.buttons) do
                if button:IsShown() then refreshButton(button) end
            end
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------------------------------

local function barsLocked()
    if not (Settings and Settings.GetValue) then return false end
    local ok, locked = pcall(Settings.GetValue, "lockActionBars")
    return ok and locked == true
end

local function onEnter(button)
    button.hoverRim:Show()
    GameTooltip:SetOwner(button, button.info.side < 0 and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    if C_ActionBar and C_ActionBar.HasAction(button.slot) then
        GameTooltip:SetAction(button.slot)
    else
        local title = L["BACK_BUTTON_" .. button.info.label]
        if button.bar ~= "top" then
            title = L.BACK_BUTTON_ON_BAR:format(title, L["CONTROLLER_BAR_" .. button.bar:upper()])
        end
        GameTooltip:SetText(title)
        GameTooltip:AddLine(L.SLOT_EMPTY:format(actionBar(button.bar), BackButtons.BarButton(button.index)),
            1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function onLeave(button)
    button.hoverRim:Hide()
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

-- Moving spells works as on the game's bars: not in combat, and with the bars locked only with the
-- pick up modifier held.
local function onDragStart(button)
    if InCombatLockdown() or (barsLocked() and not IsModifiedClick("PICKUPACTION")) then return end
    PickupAction(button.slot)
end

local function onReceiveDrag(button)
    if InCombatLockdown() then return end
    PlaceAction(button.slot)
end

local function onPostClick(button, _, down)
    setPressed(button, down == true)
end

-- A mouse button let go off the button clicks nothing.
local function onMouseUp(button)
    setPressed(button, false)
end

local function newButton(bar, index, holder)
    local info = BUTTONS[index]
    local button = CreateFrame("Button", BackButtons.Name(bar, index), holder, "SecureActionButtonTemplate")
    button.info, button.index, button.bar, button.size = info, index, bar, SIZE
    button:SetSize(SIZE, SIZE)
    button:SetAttribute("type", "action")
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:RegisterForDrag("LeftButton")
    decorate(button, info)
    button:SetScript("PostClick", onPostClick)
    button:SetScript("OnMouseUp", onMouseUp)
    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", onLeave)
    button:SetScript("OnDragStart", onDragStart)
    button:SetScript("OnReceiveDrag", onReceiveDrag)
    return button
end

-- Defined at Init: the next update, once out of combat.
local schedule, scheduleRefresh

-- The game changed its active bar (a trigger held or let go): the art follows a frame later, in
-- combat too; in the compact layout the mouse follows once out of combat.
local function scheduleHighlight()
    ns.Later("backButtonsHighlight", highlight, true)
    if compactLayout then schedule() end
end

local function create()
    local frame = GamepadMainActionBarFrame
    local pageUnit = frame.PageUnit
    root = CreateFrame("Frame", nil, frame)
    root:SetAllPoints()
    root:Hide()
    for _, bar in ipairs(BARS) do
        local holder = CreateFrame("Frame", nil, root)
        holder:SetSize(1, 1)
        holder:Hide()
        holder:SetScript("OnShow", scheduleRefresh)
        local group = { holder = holder, buttons = {} }
        for index = 1, #BUTTONS do
            group.buttons[index] = newButton(bar, index, holder)
            ns.Buttons.AddBackButton(group.buttons[index])
        end
        groups[bar] = group
    end
    for index = 1, #BUTTONS do
        local label = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetText(BUTTONS[index].label)
        label:Hide()
        crossLabels[index] = label
    end
    -- Plain frames of ours on the game's bars: their OnShow and OnHide say a bar's place changed.
    local bars = pageUnit and pageUnit.actionBars or {}
    for _, key in ipairs(PLACE_BARS) do
        if bars[key] then
            local watcher = CreateFrame("Frame", nil, bars[key])
            watcher:SetScript("OnShow", schedule)
            watcher:SetScript("OnHide", schedule)
        end
    end
    -- The game's callback registry calls through securecallfunction, so our callback can't taint it.
    if pageUnit and pageUnit.RegisterCallback then
        pageUnit:RegisterCallback("ACTIVE_ACTION_BAR_UPDATED_EVENT", scheduleHighlight, BackButtons)
    end
end

---------------------------------------------------------------------------------------------------
-- Bindings
---------------------------------------------------------------------------------------------------

-- The binding of a key in the controller interface's own set, if the game has one.
local function gamepadBinding(key)
    local lookup = C_KeyBindings and C_KeyBindings.GetBindingByKey
    local context = Enum and Enum.BindingContext and Enum.BindingContext.GamepadModeInGameCore
    if not (lookup and context) then return nil end
    local ok, action = pcall(lookup, key, context)
    if ok and type(action) == "string" and action ~= "" then return action end
end

-- The button each key presses: the keys bound to it in Key Bindings, or with none for Top's its
-- paddle key, while nothing is bound to that.
function BackButtons.Overrides()
    local overrides = {}
    for _, bar in ipairs(BARS) do
        for index, info in ipairs(BUTTONS) do
            local bound = { GetBindingKey(BackButtons.Command(bar, index)) }
            if #bound == 0 and bar == "top" then
                local action = GetBindingAction(info.paddle)
                if (action == nil or action == "") and not gamepadBinding(info.paddle) then
                    bound[1] = info.paddle
                end
            end
            for _, key in ipairs(bound) do
                overrides[key] = BackButtons.Name(bar, index)
            end
        end
    end
    return overrides
end

local bindings = ns.Buttons.NewOverrides()

---------------------------------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------------------------------

-- The special page: the possess bar up on it, with the game's setting that gives it that page.
local function specialPage(bars)
    local possess = bars.possessBar
    local value = C_CVar and tonumber(C_CVar.GetCVar("GamepadPossessBarOverride"))
    local special = Enum and Enum.GamepadPossessBarOverride and Enum.GamepadPossessBarOverride.SpecialPageTopBar
    return possess ~= nil and possess:IsShown() and value ~= nil and value == special
end

-- Which bars' places show something (on the special page none: the possess bar there isn't in a
-- bar's place). Shown and not visible: the whole controller bar hides with our frame anyway.
local function places()
    local pageUnit = GamepadMainActionBarFrame.PageUnit
    local found = {}
    if not pageUnit then return found end
    local bars = pageUnit.actionBars or {}
    local special = specialPage(bars)
    for _, key in ipairs(PLACE_BARS) do
        local frame = bars[key]
        if frame and frame:IsShown() and not (special and key == "possessBar") then
            local parent = frame:GetParent()
            for _, bar in ipairs(BARS) do
                if pageUnit[ANCHORS[bar]] == parent then found[bar] = true end
            end
        end
    end
    return found
end

local function setAttribute(frame, name, value)
    if frame:GetAttribute(name) ~= value then frame:SetAttribute(name, value) end
end

-- Each bar's buttons where its layout puts them: in the compact layout from the bar's anchor, in
-- the full layout from the page unit's centre. A button in a cross is as big as a small one, so
-- that the crosses' buttons don't overlap; its art grows past it while its bar is in use.
local function place(compact)
    local pageUnit = GamepadMainActionBarFrame.PageUnit
    compactLayout = compact
    local size = compact and SIZE or SMALL
    for index, label in ipairs(crossLabels) do
        label:ClearAllPoints()
        label:SetPoint("CENTER", pageUnit or root, "CENTER", CROSSES[index].x, CROSSES[index].y)
        label:SetShown(not compact)
    end
    for _, bar in ipairs(BARS) do
        local holder = groups[bar].holder
        local anchor = pageUnit and (compact and pageUnit[ANCHORS[bar]] or pageUnit) or root
        if holder.anchor ~= anchor then
            holder.anchor = anchor
            holder:ClearAllPoints()
            holder:SetPoint("CENTER", anchor, "CENTER", 0, 0)
        end
        local layout = compact and LAYOUTS.compact or LAYOUTS.full[bar]
        for index, button in ipairs(groups[bar].buttons) do
            local spot = layout[index]
            button:SetSize(size, size)
            if button.spot ~= spot then
                button.spot = spot
                button:ClearAllPoints()
                button:SetPoint("CENTER", groups[bar].holder, "CENTER", spot.x, spot.y)
                placeLabel(button, spot.label)
            end
        end
    end
end

-- The refresh events, heard while the buttons show; made at Init.
local refreshEvents

-- Out of combat: the buttons' slots, places and holders. A holder shows while the game shows
-- something in its bar's place; in the compact layout all four do while it shows anything (only the
-- bar in use's art shows), and only the bar in use's buttons take the mouse. A button shows only
-- with a key that presses it (its own, or Top's paddle), and a cross's name only with one of its.
function BackButtons:Update()
    local on = isOn()
    if on and not root then create() end
    local overrides = on and BackButtons.Overrides() or {}
    if root then
        local kind = on and "action" or nil
        local compact = GamepadMainActionBarFrame.useCompactLayout == true
        local found = places()
        local any = next(found) ~= nil
        local keyed = {}
        for _, name in pairs(overrides) do keyed[name] = true end
        place(compact)
        local inUse = barInUse()
        local crosses = {}
        for _, bar in ipairs(BARS) do
            local group = groups[bar]
            local shown = (compact and any) or (not compact and found[bar]) or false
            if group.holder:IsShown() ~= shown then group.holder:SetShown(shown) end
            for index, button in ipairs(group.buttons) do
                local slot = BackButtons.Slot(actionBar(bar), index)
                setAttribute(button, "type", kind)
                setAttribute(button, "action", slot)
                button.slot = slot
                button:EnableMouse(not compact or bar == inUse)
                local hasKey = keyed[button:GetName()] == true
                if button:IsShown() ~= hasKey then button:SetShown(hasKey) end
                crosses[index] = crosses[index] or hasKey
            end
        end
        for index, label in ipairs(crossLabels) do
            label:SetShown(not compact and crosses[index] == true)
        end
        highlight()
        if root:IsShown() ~= on then root:SetShown(on) end
    end
    refreshEvents:SetOn(on)
    bindings:Set(overrides)
    self:Refresh()
end

local function update()
    BackButtons:Update()
end

function schedule()
    ns.LaterOutsideWindows("backButtons", update)
end

-- Defined once: cooldown and usability events ask for it many times a second while the buttons show.
local function refresh()
    BackButtons:Refresh()
end

function scheduleRefresh()
    ns.Later("backButtonsArt", refresh, true)
end

function BackButtons:Init()
    if not GamepadMainActionBarFrame then return end
    refreshEvents = ns.Events:NewGroup(ns.Buttons.REFRESH_EVENTS, scheduleRefresh)
    local watched = { KEY }
    for _, bar in ipairs(BARS) do watched[#watched + 1] = BackButtons.BarOption(bar) end
    Options:Watch(watched, schedule)
    -- The player changed a binding, or another addon its overrides (setting ours fires this too;
    -- Update then finds nothing to change).
    ns.Events:On("UPDATE_BINDINGS", function()
        if isOn() or bindings:Any() then schedule() end
    end)
    ns.OnControllerUIChange(function()
        if isOn() or root then schedule() end
    end)
    -- The compact layout is set in Edit Mode.
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            if root then schedule() end
        end, BackButtons)
    end
    if isOn() then schedule() end
end
