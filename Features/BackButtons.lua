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
-- picked for them in Steam Input, controllers with paddles as PADPADDLE1 to 4. One key serves all
-- four bars, so the keys press four hidden secure buttons of ours (QoLBackButton1 to 4, the
-- commands in Bindings.xml), each of which takes the slot of the bar in use. Forever's triggers
-- aren't modifiers (ADR 0006), so the bar in use is the trigger toggle's: it sets it on our header
-- (ns.Buttons.AddBarFollower), held or switched on, in combat too, and the header puts that bar's
-- slots on the keys' buttons. Without the trigger toggle that's Top, and only Top's show.
--
-- Each bar's four shown buttons are secure action buttons too, for the mouse, on a holder of ours
-- anchored to the bar's anchor on the page unit (which only Edit Mode moves, out of combat), under a
-- frame of ours that's a child of GamepadMainActionBarFrame, so they hide, scale and fade with the
-- bar. In the full layout they sit on the bar's outer side, in the compact layout beside it. A
-- holder shows while the game shows something in its bar's place (the bar, or the stance or possess
-- bar over it, but not the special page), and in the compact layout only the bar in use's shows. Plain
-- frames of ours on the game's bars tell us when those show or hide; nothing of the game's is written,
-- called or hooked. Creating the buttons, their attributes, the holders shown and the override
-- bindings wait for combat to end, except what the header does in combat: the keys' slots and, in
-- the compact layout, which holder shows. The art updates in combat, on regions of our own.
local BackButtons = {}
ns.BackButtons = BackButtons

local KEY = "controllerBackButtons"
-- Only read: with it off, the back buttons act on Top only.
local TOGGLE_KEY = "controllerTriggerToggle"
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
-- The controller bar's round buttons at full size, and how much smaller one is while pressed.
local SIZE = 38
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

-- Where each button sits from its bar's anchor, and the side its name goes. The full layout's bars
-- interlock, so each bar's go on its free outer side: a row above Top and below Bottom, a column left
-- of Left and right of Right. The compact layout shows one bar: L4 and L5 left of it, R4 and R5
-- right. docs/dev/controller.md has the numbers.
local ROW_X, ROW_Y = { -114, -70, 70, 114 }, 85
local COLUMN_X, COLUMN_Y = 182, { 66, 22, -22, -66 }
local LAYOUTS = { full = {}, compact = {} }
for index, info in ipairs(BUTTONS) do
    LAYOUTS.compact[index] = { x = info.side * COLUMN_X, y = index % 2 == 1 and 26 or -26,
        label = info.side < 0 and "LEFT" or "RIGHT" }
end
LAYOUTS.full.top, LAYOUTS.full.bottom, LAYOUTS.full.left, LAYOUTS.full.right = {}, {}, {}, {}
for index = 1, #BUTTONS do
    LAYOUTS.full.top[index] = { x = ROW_X[index], y = ROW_Y, label = "TOP" }
    LAYOUTS.full.bottom[index] = { x = ROW_X[index], y = -ROW_Y, label = "BOTTOM" }
    LAYOUTS.full.left[index] = { x = -COLUMN_X, y = COLUMN_Y[index], label = "LEFT" }
    LAYOUTS.full.right[index] = { x = COLUMN_X, y = COLUMN_Y[index], label = "RIGHT" }
end

function BackButtons.Name(index)
    return "QoLBackButton" .. index
end

-- The binding command of a back button's key, as Bindings.xml names it.
function BackButtons.Command(index)
    return ns.Buttons.Command(BackButtons.Name(index))
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
for index, info in ipairs(BUTTONS) do
    _G["BINDING_NAME_" .. BackButtons.Command(index)] = L["BACK_BUTTON_" .. info.label]
end

-- Only in the controller interface: with keyboard and mouse the buttons hide, their keys press
-- nothing (a button without a type does nothing) and our override bindings are gone.
local function isOn()
    return Options:Get(KEY) == true and GamepadMainActionBarFrame ~= nil and ns.IsControllerUI()
end

local header, root
-- By bar: the holder and its four shown buttons.
local groups = {}
-- The keys' hidden buttons.
local keys = {}

---------------------------------------------------------------------------------------------------
-- Secure part
---------------------------------------------------------------------------------------------------

-- The bar in use (the trigger toggle's, or Top without it) gives the keys' buttons their slots.
-- Then the holders: in the compact layout the bar in use's, beside the one bar the game shows there
-- (on Top's anchor), while something is in Top's place; in the full layout every bar's with
-- something in its place, but only Top's without the trigger toggle.
-- Attribute names are lower case: the game lowers them.
local REFRESH = [[
    local trigger = self:GetAttribute("trigger")
    local bar = trigger and self:GetAttribute("bar") or "top"
    for index = 1, 4 do
        self:GetFrameRef("key-" .. index):SetAttribute("action", self:GetAttribute("slot-" .. bar .. "-" .. index))
    end
    local compact = self:GetAttribute("compact")
    for index = 1, 4 do
        local name = self:GetAttribute("name-" .. index)
        local shown
        if compact then
            shown = name == bar and self:GetAttribute("place-top")
        else
            shown = (trigger or name == "top") and self:GetAttribute("place-" .. name)
        end
        local holder = self:GetFrameRef("holder-" .. name)
        if shown then holder:Show() else holder:Hide() end
    end
]]

-- The trigger toggle sets "bar" as it changes, in combat too.
local ON_ATTRIBUTE = [[
    if name == "bar" then self:RunAttribute("refresh") end
]]

---------------------------------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------------------------------

local function setPressed(button, down)
    if button.pressed == down then return end
    button.pressed = down
    local size = down and SIZE - PRESSED or SIZE
    button.visual:SetSize(size, size)
    button.visual:ClearAllPoints()
    button.visual:SetPoint("CENTER", 0, down and -PRESSED / 2 or 0)
    button.pushedRim:SetShown(down)
end

local OPPOSITE = { LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP" }
local NUDGE = { LEFT = { -2, 0 }, RIGHT = { 2, 0 }, TOP = { 0, 2 }, BOTTOM = { 0, -2 } }

-- The button's name on its outer side.
local function placeLabel(button, side)
    if button.labelSide == side then return end
    button.labelSide = side
    local nudge = NUDGE[side]
    button.label:ClearAllPoints()
    button.label:SetPoint(OPPOSITE[side], button, side, nudge[1], nudge[2])
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
            for _, button in ipairs(group.buttons) do refreshButton(button) end
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

-- The bar a key acts on now, as the header has it.
local function barInUse()
    return header:GetAttribute("trigger") and header:GetAttribute("bar") or "top"
end

-- A key looks pressed on the button of the bar it acted on.
local function onKeyPostClick(key, _, down)
    if key.shownPressed then
        setPressed(key.shownPressed, false)
        key.shownPressed = nil
    end
    if down then
        local group = groups[barInUse()]
        key.shownPressed = group and group.buttons[key.index]
        if key.shownPressed then setPressed(key.shownPressed, true) end
    end
end

local function newShownButton(bar, index, holder)
    local info = BUTTONS[index]
    local button = CreateFrame("Button", "QoLBackButton" .. BAR_NAMES[bar] .. index, holder,
        "SecureActionButtonTemplate")
    button.info, button.index, button.bar = info, index, bar
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

local function newKey(index)
    local key = CreateFrame("Button", BackButtons.Name(index), nil, "SecureActionButtonTemplate")
    key:Hide()
    key.index = index
    key:RegisterForClicks("AnyDown", "AnyUp")
    key:SetScript("PostClick", onKeyPostClick)
    return key
end

-- Defined at Init: the next update, once out of combat.
local schedule, scheduleRefresh

local function create()
    local frame = GamepadMainActionBarFrame
    local pageUnit = frame.PageUnit
    root = CreateFrame("Frame", nil, frame)
    root:SetAllPoints()
    root:Hide()
    header = CreateFrame("Frame", "QoLBackButtons", UIParent, "SecureHandlerAttributeTemplate")
    header:SetAttribute("refresh", REFRESH)
    for index, bar in ipairs(BARS) do
        header:SetAttribute("name-" .. index, bar)
        local holder = CreateFrame("Frame", nil, root)
        holder:SetSize(1, 1)
        holder:SetPoint("CENTER", pageUnit and pageUnit[ANCHORS[bar]] or root, "CENTER", 0, 0)
        holder:Hide()
        holder:SetScript("OnShow", scheduleRefresh)
        local group = { holder = holder, buttons = {} }
        for button = 1, #BUTTONS do
            group.buttons[button] = newShownButton(bar, button, holder)
        end
        groups[bar] = group
        SecureHandlerSetFrameRef(header, "holder-" .. bar, holder)
    end
    for index = 1, #BUTTONS do
        keys[index] = newKey(index)
        SecureHandlerSetFrameRef(header, "key-" .. index, keys[index])
    end
    header:SetAttribute("_onattributechanged", ON_ATTRIBUTE)
    -- Plain frames of ours on the game's bars: their OnShow and OnHide say a bar's place changed.
    local bars = pageUnit and pageUnit.actionBars or {}
    for _, key in ipairs(PLACE_BARS) do
        if bars[key] then
            local watcher = CreateFrame("Frame", nil, bars[key])
            watcher:SetScript("OnShow", schedule)
            watcher:SetScript("OnHide", schedule)
        end
    end
    for _, key in ipairs(keys) do ns.Buttons.AddBackButton(key) end
    ns.Buttons.AddBarFollower(header)
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

-- The button each key presses: the keys bound to it in Key Bindings, or with none its paddle key,
-- while nothing is bound to that.
function BackButtons.Overrides()
    local overrides = {}
    for index, info in ipairs(BUTTONS) do
        local bound = { GetBindingKey(BackButtons.Command(index)) }
        if #bound == 0 then
            local action = GetBindingAction(info.paddle)
            if (action == nil or action == "") and not gamepadBinding(info.paddle) then
                bound[1] = info.paddle
            end
        end
        for _, key in ipairs(bound) do
            overrides[key] = BackButtons.Name(index)
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

-- Each bar's buttons where its layout puts them.
local function place(compact)
    for _, bar in ipairs(BARS) do
        local layout = compact and LAYOUTS.compact or LAYOUTS.full[bar]
        for index, button in ipairs(groups[bar].buttons) do
            local spot = layout[index]
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

function BackButtons:Update()
    local on = isOn()
    if on and not header then create() end
    if header then
        local kind = on and "action" or nil
        for index, key in ipairs(keys) do
            setAttribute(key, "type", kind)
            for _, bar in ipairs(BARS) do
                local slot = BackButtons.Slot(actionBar(bar), index)
                setAttribute(header, "slot-" .. bar .. "-" .. index, slot)
                local button = groups[bar].buttons[index]
                setAttribute(button, "action", slot)
                button.slot = slot
            end
        end
        local compact = GamepadMainActionBarFrame.useCompactLayout == true
        local found = places()
        setAttribute(header, "trigger", Options:Get(TOGGLE_KEY) == true or nil)
        setAttribute(header, "compact", compact or nil)
        for _, bar in ipairs(BARS) do setAttribute(header, "place-" .. bar, found[bar] or nil) end
        place(compact)
        SecureHandlerExecute(header, [[ self:RunAttribute("refresh") ]])
        if root:IsShown() ~= on then root:SetShown(on) end
        setAttribute(header, "beside", on or nil)
    end
    refreshEvents:SetOn(on)
    bindings:Set(on and BackButtons.Overrides() or {})
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
    local watched = { KEY, TOGGLE_KEY }
    for _, bar in ipairs(BARS) do watched[#watched + 1] = BackButtons.BarOption(bar) end
    Options:Watch(watched, schedule)
    -- The player changed a binding, or another addon its overrides (setting ours fires this too;
    -- Update then finds nothing to change).
    ns.Events:On("UPDATE_BINDINGS", function()
        if isOn() or bindings:Any() then schedule() end
    end)
    ns.OnControllerUIChange(function()
        if isOn() or header then schedule() end
    end)
    -- The compact layout is set in Edit Mode.
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            if header then schedule() end
        end, BackButtons)
    end
    if isOn() then schedule() end
end
