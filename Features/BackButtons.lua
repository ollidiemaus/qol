local _, ns = ...
local Options = ns.Options
local L = ns.L

-- Four more buttons on Forever's controller action bar, for a controller's back buttons (the Steam
-- Deck's L4, L5, R4 and R5): two left of the d-pad buttons, two right of the face buttons. They act
-- without a trigger held. Each is a secure action button of ours for one of the last four slots of
-- Action Bar 6, 7 or 8 (the player picks the bar; the controller bar's own slots stay as they are),
-- so a spell goes on it by dragging it there, or onto that bar's buttons 9 to 12.
--
-- The game sees a back button as whatever key the controller sends: the Steam Deck's as the keys
-- picked for them in Steam Input, controllers with paddles as PADPADDLE1 to 4. The buttons are bound
-- under Key Bindings > AddOns (Bindings.xml); each key bound there also gets an override binding of
-- ours, so it presses its button in the controller interface too. A button with no key bound takes
-- its paddle key while nothing else has that key. A trigger held makes it a modified key, which
-- the game hands to the same key without modifiers when nothing is bound to it.
--
-- The buttons hang off a frame of ours that is a child of GamepadMainActionBarFrame, so they show,
-- hide, scale and fade with the bar without a hook on it, and are anchored to the bar's PageUnit
-- anchors, which only Edit Mode moves (out of combat), so they follow its compact layout too.
-- Nothing of the bar is written or called. Creating them, their attributes and the override
-- bindings wait for combat to end; the art updates in combat, on regions of our own.
local BackButtons = {}
ns.BackButtons = BackButtons

local KEY = "controllerBackButtons"
local BAR_KEY = "controllerBackButtonsBar"
-- Action Bars 6 to 8 are pages 13 to 15 of the action slots; the back buttons take buttons 9 to 12.
local PAGES = { [6] = 13, [7] = 14, [8] = 15 }
local FIRST = 8
-- The controller bar's round buttons at full size, and how much smaller one is while pressed.
local SIZE = 38
local PRESSED = 4
-- From the middle of the d-pad buttons (and the face buttons) to the back buttons'.
local OFFSET_X, OFFSET_Y = 182, 26
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- In the order of the bindings. side: -1 left of the bar, 1 right of it. paddle: the key a controller
-- with paddles sends (SDL's numbering: 1 and 3 under the right hand, 2 and 4 under the left).
BackButtons.BUTTONS = {
    { label = "L4", side = -1, y = OFFSET_Y, paddle = "PADPADDLE2" },
    { label = "L5", side = -1, y = -OFFSET_Y, paddle = "PADPADDLE4" },
    { label = "R4", side = 1, y = OFFSET_Y, paddle = "PADPADDLE1" },
    { label = "R5", side = 1, y = -OFFSET_Y, paddle = "PADPADDLE3" },
}
local BUTTONS = BackButtons.BUTTONS

function BackButtons.Name(index)
    return "QoLBackButton" .. index
end

-- The binding command of a button, as Bindings.xml names it.
function BackButtons.Command(index)
    return ns.Buttons.Command(BackButtons.Name(index))
end

function BackButtons.Slot(bar, index)
    return (PAGES[bar] or PAGES[8]) * 12 - 12 + FIRST + index
end

-- Names in the Key Bindings window.
BINDING_HEADER_QOL = L.ADDON_TITLE
for index, info in ipairs(BUTTONS) do
    _G["BINDING_NAME_" .. BackButtons.Command(index)] = L["BACK_BUTTON_" .. info.label]
end

local function isOn()
    return Options:Get(KEY) == true and GamepadMainActionBarFrame ~= nil
end

local holder
local buttons = {}

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

-- The controller bar's round button, on regions of our own: drop shadow, dark empty slot, round
-- icon and its cooldown, and above them the rim (pressed, pointed at, or current or repeating
-- action), the count and the button's name on its outer side.
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

    local name = over:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local outer = info.side < 0 and "RIGHT" or "LEFT"
    name:SetPoint(outer, button, info.side < 0 and "LEFT" or "RIGHT", -info.side * 2, 0)
    name:SetText(info.label)
end

-- The slot's art, and the selected rim while its action is current or repeating.
local function refreshButton(button)
    local slot = button.slot
    local current = ns.Buttons.RefreshAction(button, slot)
        and (C_ActionBar.IsCurrentAction(slot) or C_ActionBar.IsAutoRepeatAction(slot))
    button.selectedRim:SetShown(ns.IsUsable(current) and current == true)
end

function BackButtons:Refresh()
    if not (holder and holder:IsShown()) then return end
    for _, button in ipairs(buttons) do
        refreshButton(button)
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
        GameTooltip:SetText(L["BACK_BUTTON_" .. button.info.label])
        GameTooltip:AddLine(L.SLOT_EMPTY:format(Options:Get(BAR_KEY), FIRST + button.index), 1, 1, 1, true)
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

local function create()
    local bar = GamepadMainActionBarFrame
    holder = CreateFrame("Frame", nil, bar)
    holder:SetAllPoints()
    holder:Hide()
    local pageUnit = bar.PageUnit
    for index, info in ipairs(BUTTONS) do
        local button = CreateFrame("Button", BackButtons.Name(index), holder, "SecureActionButtonTemplate")
        button.info, button.index = info, index
        button:SetSize(SIZE, SIZE)
        local anchor = pageUnit and pageUnit[info.side < 0 and "LeftCenteredAnchor" or "RightCenteredAnchor"]
        if anchor then
            button:SetPoint("CENTER", anchor, "CENTER", info.side * OFFSET_X, info.y)
        else
            local outer = info.side < 0 and "LEFT" or "RIGHT"
            button:SetPoint(info.side < 0 and "RIGHT" or "LEFT", holder, outer, 0, info.y)
        end
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:RegisterForDrag("LeftButton")
        decorate(button, info)
        button:SetScript("PostClick", function(self, _, down) setPressed(self, down == true) end)
        -- A mouse button let go off the button clicks nothing.
        button:SetScript("OnMouseUp", function(self) setPressed(self, false) end)
        button:SetScript("OnEnter", onEnter)
        button:SetScript("OnLeave", onLeave)
        button:SetScript("OnDragStart", onDragStart)
        button:SetScript("OnReceiveDrag", onReceiveDrag)
        buttons[index] = button
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

-- The button each key presses: the keys bound to it in Key Bindings, or with none its paddle key,
-- while nothing is bound to that.
function BackButtons.Overrides()
    local overrides = {}
    for index, info in ipairs(BUTTONS) do
        local keys = { GetBindingKey(BackButtons.Command(index)) }
        if #keys == 0 then
            local action = GetBindingAction(info.paddle)
            if (action == nil or action == "") and not gamepadBinding(info.paddle) then
                keys[1] = info.paddle
            end
        end
        for _, key in ipairs(keys) do
            overrides[key] = BackButtons.Name(index)
        end
    end
    return overrides
end

local bindings = ns.Buttons.NewOverrides()

---------------------------------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------------------------------

function BackButtons:Update()
    local on = isOn()
    if on and not holder then create() end
    if holder then
        local bar = Options:Get(BAR_KEY)
        local kind = on and "action" or nil
        for index, button in ipairs(buttons) do
            local slot = BackButtons.Slot(bar, index)
            if button:GetAttribute("type") ~= kind then button:SetAttribute("type", kind) end
            if button:GetAttribute("action") ~= slot then button:SetAttribute("action", slot) end
            button.slot = slot
        end
        if holder:IsShown() ~= on then holder:SetShown(on) end
    end
    bindings:Set(on and BackButtons.Overrides() or {})
    self:Refresh()
end

local function schedule()
    ns.LaterOutsideWindows("backButtons", function() BackButtons:Update() end)
end

local function scheduleRefresh()
    if holder and holder:IsShown() then
        ns.Later("backButtonsArt", function() BackButtons:Refresh() end, true)
    end
end

function BackButtons:Init()
    if not GamepadMainActionBarFrame then return end
    Options:Watch({ KEY, BAR_KEY }, schedule)
    -- The player changed a binding, or another addon its overrides (setting ours fires this too;
    -- Update then finds nothing to change).
    ns.Events:On("UPDATE_BINDINGS", function()
        if isOn() or bindings:Any() then schedule() end
    end)
    for _, event in ipairs(ns.Buttons.REFRESH_EVENTS) do
        ns.Events:On(event, scheduleRefresh)
    end
    if isOn() then schedule() end
end
