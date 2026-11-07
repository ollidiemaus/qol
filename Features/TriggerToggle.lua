local _, ns = ...
local Options = ns.Options

-- Trigger toggle, in Forever's controller interface: a trigger pressed alone switches its controller
-- bar on until it's pressed again, so it needn't be held. A trigger held with a button works as before.
--
-- The game shows and uses a trigger's bar only while the key of GAMEPADLEFTMOD or GAMEPADRIGHTMOD is
-- down, and an addon can't keep a key down. So with the option on the trigger keys get override
-- bindings to secure buttons of ours, which keep the state on a secure header, in combat too. While
-- a bar is on, held or switched, the header binds the eight keys of a bar to relays of ours, each of
-- which clicks the game's button it should reach, chosen on the press. Nothing else changes: LB, RB,
-- the sticks, the back buttons and the rings keep their keys. The game's active bar stays Top.
--
-- Our overrides are plain ones, so that the priority overrides of the game's windows win over them
-- on their own, also in combat, when they can't be taken away. Easy Controller's Toggle.lua (MIT) is
-- the model for the snippets. docs/dev/controller.md has the rest.
local TriggerToggle = {}
ns.TriggerToggle = TriggerToggle

local KEY = "controllerTriggerToggle"
local TOP_AFTER_COMBAT_KEY = "controllerTriggerToggleTopAfterCombat"

-- The game can make the triggers act as modifiers, so a key can come with any of these.
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local TRIGGERS = { LT = "PADLTRIGGER", RT = "PADRTRIGGER" }
-- The keys of a bar, by the game's button index (Blizzard_GamepadActionBars/Bindings.xml).
local BAR_KEYS = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1" }
local BAR_SIZE = #BAR_KEYS
local BARS = { "left", "right", "bottom" }
-- What can sit over Top while LB or RB is held; the player's bar on doesn't change that.
local OVER_TOP = { "friendlyTargeting", "hostileTargeting", "shortcuts" }
-- What can take a bar's place, where the game's settings put them, the first one found winning.
local IN_PLACE = { "possess", "stance" }
-- Any of these on: the bar on goes off, so that the face buttons use that bar.
local POSSESS_DRIVER = "[possessbar][overridebar][vehicleui] on; off"
local TRIGGER_PREFIX = "QoLTriggerToggle"
local RELAY_PREFIX = TRIGGER_PREFIX .. "Relay"

-- The marker: the glow the game draws behind a trigger's icon, spread out behind the bar. The game's
-- own bar focus (BackgroundFocus) is black, so it only dims what's behind it and can't be seen on a
-- dark scene. Below the bars, which are on levels 4 and 5 of the LOW strata (ActionBar.lua).
local MARKER_ATLAS = "gamepad-actionbar-fx-trigger-behind"
local MARKER_WIDTH, MARKER_HEIGHT, MARKER_ALPHA = 512, 160, 0.7
local MARKER_LEVEL = 3

-- The bar in use, held or switched on, into the keys' bindings. Both triggers pressed together mean Bottom
-- until both are let go. Between bars the bindings stay: the relays read the bar on the press.
local APPLY = [[
    local both = self:GetAttribute("both")
    local lt = self:GetAttribute("on-LT") or self:GetAttribute("held-LT") or both
    local rt = self:GetAttribute("on-RT") or self:GetAttribute("held-RT") or both
    local bar = lt and rt and "bottom" or lt and "left" or rt and "right" or nil
    local was = self:GetAttribute("bar")
    if bar == was then return end
    self:SetAttribute("bar", bar)
    if not bar then
        self:ClearBindings()
    elseif not was then
        for index = 1, self:GetAttribute("keycount") do
            self:SetBindingClick(false, self:GetAttribute("key-" .. index), self:GetAttribute("relay-" .. index), "LeftButton")
        end
    end
]]

-- A trigger held has been used: let go, it was a hold and not a press.
local MARK_USED = [[
    if self:GetAttribute("held-LT") then self:SetAttribute("used-LT", true) end
    if self:GetAttribute("held-RT") then self:SetAttribute("used-RT", true) end
]]

-- Going down, a trigger's bar is held. Let go unused, it flips its own switch. Both pressed together
-- flip Bottom once, when both are let go. A release we didn't see the press of isn't one (the key
-- went down in a window). A press under a possess or vehicle bar never counts as a press, so that the
-- bar stays off.
local TRIGGER = [[
    local t = self:GetAttribute("trigger")
    local other = t == "LT" and "RT" or "LT"
    if down then
        owner:SetAttribute("held-" .. t, true)
        owner:SetAttribute("used-" .. t, owner:GetAttribute("possess"))
        if owner:GetAttribute("held-" .. other) then owner:SetAttribute("both", true) end
    elseif owner:GetAttribute("held-" .. t) then
        owner:SetAttribute("held-" .. t, nil)
        if owner:GetAttribute("both") then
            if not owner:GetAttribute("held-" .. other) then
                owner:SetAttribute("both", nil)
                if not owner:GetAttribute("used-" .. t) and not owner:GetAttribute("used-" .. other) then
                    local bottom = owner:GetAttribute("on-LT") and owner:GetAttribute("on-RT")
                    owner:SetAttribute("on-LT", not bottom or nil)
                    owner:SetAttribute("on-RT", not bottom or nil)
                end
            end
        elseif not owner:GetAttribute("used-" .. t) then
            owner:SetAttribute("on-" .. t, not owner:GetAttribute("on-" .. t) or nil)
        end
    end
    owner:RunAttribute("apply")
    return false
]]

-- Picks the game's button a press reaches, the one the game shows there: with no trigger held
-- whatever LB or RB put over Top, as the game would with Top its active bar; else the stance bar's
-- or possess bar's where it has taken the bar, else the bar's own, whatever slot that holds on this page.
--
-- A button acts going down, and the secure "click" type clicks going up, so the press is a macro,
-- as the game's binding presses it. A macro in the slot doesn't run from a macro: that one is used
-- directly.
local RELAY = [[
    local index = self:GetAttribute("index")
    local held = owner:GetAttribute("held-LT") or owner:GetAttribute("held-RT")
    owner:RunAttribute("markused")
    local button
    if not held then
        for bar = 1, owner:GetAttribute("overtopcount") do
            local over = owner:GetFrameRef(owner:GetAttribute("overtop-" .. bar) .. index)
            if over and over:IsVisible() then button = over end
        end
    end
    local bar = owner:GetAttribute("bar")
    for place = 1, owner:GetAttribute("inplacecount") do
        local name = owner:GetAttribute("inplace-" .. place)
        if not button and bar == owner:GetAttribute(name .. "bar") then
            local game = owner:GetFrameRef(name .. index)
            if game:IsVisible() then button = game end
        end
    end
    button = button or owner:GetFrameRef(bar .. index)
    local slot = button:GetID()
    if slot > 0 and GetActionInfo(slot) == "macro" then
        self:SetAttribute("type", "action")
        self:SetAttribute("action", slot)
    else
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", "/click " .. button:GetName() .. " LeftButton true")
    end
]]

-- A back button pressed counts as using the trigger held.
local BACK_BUTTON = [[
    if down then owner:RunAttribute("markused") end
]]

-- Every switch off. A trigger still held has been used, so that letting go switches nothing on.
local ALL_OFF = [[
    self:RunAttribute("markused")
    self:SetAttribute("on-LT", nil)
    self:SetAttribute("on-RT", nil)
    self:RunAttribute("apply")
]]

-- A trigger let go where we can't see it counts as let go, and doesn't count as a press.
local LET_GO = [[
    self:SetAttribute("held-LT", nil)
    self:SetAttribute("held-RT", nil)
    self:SetAttribute("both", nil)
    self:RunAttribute("apply")
]]

local header
local marker = {}
local markerHolder
local triggerKeys = {}
for trigger, key in pairs(TRIGGERS) do
    for _, prefix in ipairs(PREFIXES) do
        triggerKeys[prefix .. key] = TRIGGER_PREFIX .. trigger
    end
end

-- Only in the controller interface: with keyboard and mouse nothing is bound.
local function isOn()
    return Options:Get(KEY) == true and ns.IsControllerUI()
end

---------------------------------------------------------------------------------------------------
-- Marker
---------------------------------------------------------------------------------------------------

-- Hidden while a game window has the controller. Frames of ours, so in combat too.
local function refreshMarker()
    if not header then return end
    local bar = not ns.ControllerWindowOpen() and header:GetAttribute("bar")
    for name, texture in pairs(marker) do
        texture:SetShown(name == bar)
    end
end

local function onAttribute(_, name)
    if name == "bar" then refreshMarker() end
end

---------------------------------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------------------------------

-- The game's buttons, by frame ref. Those that take a bar's place are only read on a press.
local function setRefs(pageUnit)
    local bars = pageUnit.actionBars
    local function set(prefix, bar)
        for index = 1, BAR_SIZE do
            SecureHandlerSetFrameRef(header, prefix .. index, bar.actionButtons[index])
        end
    end
    for _, name in ipairs(BARS) do set(name, bars[name .. "Bar"]) end
    for index, name in ipairs(IN_PLACE) do
        header:SetAttribute("inplace-" .. index, name)
        set(name, bars[name .. "Bar"])
    end
    header:SetAttribute("inplacecount", #IN_PLACE)
    for index, name in ipairs(OVER_TOP) do
        header:SetAttribute("overtop-" .. index, name)
        set(name, bars[name .. "Bar"])
    end
    header:SetAttribute("overtopcount", #OVER_TOP)
end

local function newSecureButton(name)
    local button = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
    button:Hide()
    return button
end

local function createRelays()
    local count = 0
    for index, key in ipairs(BAR_KEYS) do
        local name = RELAY_PREFIX .. index
        local relay = newSecureButton(name)
        relay:RegisterForClicks("AnyDown")
        relay:SetAttribute("useOnKeyDown", true)
        relay:SetAttribute("index", index)
        SecureHandlerWrapScript(relay, "OnClick", header, RELAY)
        for _, prefix in ipairs(PREFIXES) do
            count = count + 1
            header:SetAttribute("key-" .. count, prefix .. key)
            header:SetAttribute("relay-" .. count, name)
        end
    end
    header:SetAttribute("keycount", count)
end

local function createTriggers()
    for trigger in pairs(TRIGGERS) do
        local button = newSecureButton(TRIGGER_PREFIX .. trigger)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("trigger", trigger)
        SecureHandlerWrapScript(button, "OnClick", header, TRIGGER)
    end
end

local function createMarker(pageUnit)
    markerHolder = CreateFrame("Frame", nil, pageUnit)
    markerHolder:SetFrameStrata("LOW")
    markerHolder:SetFrameLevel(MARKER_LEVEL)
    local anchors = {
        left = pageUnit.LeftCenteredAnchor,
        right = pageUnit.RightCenteredAnchor,
        bottom = pageUnit.BottomCenteredAnchor,
    }
    for _, name in ipairs(BARS) do
        local texture = markerHolder:CreateTexture(nil, "BACKGROUND")
        texture:SetPoint("CENTER", anchors[name], "CENTER")
        texture:SetSize(MARKER_WIDTH, MARKER_HEIGHT)
        texture:SetAtlas(MARKER_ATLAS)
        texture:SetBlendMode("ADD")
        texture:SetAlpha(MARKER_ALPHA)
        texture:Hide()
        marker[name] = texture
    end
end

local function create()
    local pageUnit = GamepadMainActionBarFrame.PageUnit
    header = CreateFrame("Frame", TRIGGER_PREFIX, UIParent, "SecureHandlerStateTemplate")
    header:SetAttribute("apply", APPLY)
    header:SetAttribute("markused", MARK_USED)
    header:SetAttribute("_onstate-possess", [[
        self:SetAttribute("possess", newstate == "on" or nil)
        if newstate == "on" then self:RunAttribute("alloff") end
    ]])
    header:SetAttribute("alloff", ALL_OFF)
    setRefs(pageUnit)
    createRelays()
    createTriggers()
    createMarker(pageUnit)
    header:HookScript("OnAttributeChanged", onAttribute)
    ns.Buttons.WatchBackButtons(function(button)
        SecureHandlerWrapScript(button, "OnClick", header, BACK_BUTTON)
    end)
    RegisterStateDriver(header, "possess", POSSESS_DRIVER)
end

---------------------------------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------------------------------

local bindings = ns.Buttons.NewOverrides()

local function allOff()
    SecureHandlerExecute(header, [[ self:RunAttribute("alloff") ]])
end

-- The bar a setting of the game gives away on whichever page it names; a press checks that page.
local function onAnyPage(find)
    for page = 1, 3 do
        local bar = find(page)
        if bar then return bar end
    end
    return nil
end

-- Out of combat and away from the game's controller windows.
local function update()
    local on = isOn()
    if not header then
        if not on then return end
        create()
    end
    header:SetAttribute("stancebar", on and onAnyPage(ns.GamepadStanceBar) or nil)
    header:SetAttribute("possessbar", on and onAnyPage(ns.GamepadPossessBar) or nil)
    if not on then allOff() end
    SecureHandlerExecute(header, LET_GO)
    bindings:Set(on and triggerKeys or {})
    refreshMarker()
end

local function schedule()
    ns.LaterOutsideWindows("triggerToggle", update)
end

local function goToTop()
    if header and isOn() and Options:Get(TOP_AFTER_COMBAT_KEY) then allOff() end
end

-- A window took or gave back the controller. The manager says so as it changes, so a frame later.
local function onWindow()
    if not header then return end
    ns.Later("triggerToggleMarker", refreshMarker, true)
    schedule()
end

function TriggerToggle:Init()
    if not GamepadMainActionBarFrame then return end
    Options:Watch({ KEY }, schedule)
    ns.OnControllerUIChange(schedule)
    local function onBarSetting()
        if header then schedule() end
    end
    ns.Events:On("GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED", onBarSetting)
    ns.Events:On("GAMEPAD_POSSESS_BAR_OVERRIDE_CHANGED", onBarSetting)
    ns.Events:On("PLAYER_REGEN_ENABLED", function()
        if header then ns.LaterOutsideWindows("triggerToggleTop", goToTop) end
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("Gamepad.RefreshFrameFocus", onWindow, TriggerToggle)
    end
    if isOn() then schedule() end
end
