local _, ns = ...

-- What the addon's own action buttons (the controller back buttons, the rings) share: the look of
-- an action slot (the back buttons'), and override bindings that press a button with its keys.
local Buttons = {}
ns.Buttons = Buttons

-- The binding command that clicks a button, as Bindings.xml names it.
function Buttons.Command(name)
    return "CLICK " .. name .. ":LeftButton"
end

-- What changes a slot's icon, count, usability, cooldown or current state.
Buttons.REFRESH_EVENTS = {
    "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED",
    "BAG_UPDATE_DELAYED", "UPDATE_SHAPESHIFT_FORM", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
    "PLAYER_ENTERING_WORLD",
}

-- Setters for a slot's regions that skip a value the region shows already: the slots refresh on
-- every cooldown and usability event, many times a second in combat. A secret value can't be
-- compared, so it is always set. Every change to these regions goes through them.
local shown = setmetatable({}, { __mode = "k" })
local shownDuration = setmetatable({}, { __mode = "k" })

local function differs(region, value)
    if not ns.IsUsable(value) then
        shown[region] = nil
        return true
    end
    if shown[region] == value then return false end
    shown[region] = value
    return true
end

function Buttons.SetIcon(icon, texture)
    if differs(icon, texture) then icon:SetTexture(texture) end
end

function Buttons.SetCount(count, text)
    if differs(count, text) then count:SetText(text) end
end

-- The icon's tint for an action that can be used, lacks the power for it, or can't be used.
local TINTS = { usable = { 1, 1, 1 }, noMana = { 0.5, 0.5, 1 }, unusable = { 0.4, 0.4, 0.4 } }

function Buttons.SetUsable(icon, usable, noMana)
    local tint = (ns.IsUsable(usable) and usable and "usable")
        or (ns.IsUsable(noMana) and noMana and "noMana") or "unusable"
    if differs(icon, tint) then
        local color = TINTS[tint]
        icon:SetVertexColor(color[1], color[2], color[3])
    end
end

local CLEARED = "cleared"

function Buttons.ClearCooldown(cooldown)
    if differs(cooldown, CLEARED) then cooldown:Clear() end
end

-- A duration object is new on each call and can't be compared: it is always set.
function Buttons.SetCooldownDuration(cooldown, duration)
    shown[cooldown] = nil
    cooldown:SetCooldownFromDurationObject(duration)
end

function Buttons.SetCooldown(cooldown, start, duration)
    if shown[cooldown] == start and shownDuration[cooldown] == duration and ns.IsUsable(start)
        and ns.IsUsable(duration) then
        return
    end
    shown[cooldown] = ns.IsUsable(start) and start or nil
    shownDuration[cooldown] = ns.IsUsable(duration) and duration or nil
    cooldown:SetCooldown(start, duration)
end

-- Icon, usability, count and cooldown of an action slot on a button's own regions (icon, count,
-- cooldown), as the game's action buttons show them. Returns whether the slot holds an action.
function Buttons.RefreshAction(button, slot)
    local actions = C_ActionBar
    if not (slot and actions and actions.HasAction(slot)) then
        button.icon:Hide()
        Buttons.SetCount(button.count, "")
        Buttons.ClearCooldown(button.cooldown)
        return false
    end
    Buttons.SetIcon(button.icon, actions.GetActionTexture(slot))
    button.icon:Show()
    Buttons.SetUsable(button.icon, actions.IsUsableAction(slot))
    if actions.GetActionDisplayCount then
        Buttons.SetCount(button.count, actions.GetActionDisplayCount(slot, 9999))
    end
    local duration = actions.GetActionCooldownDuration and actions.GetActionCooldownDuration(slot)
    if duration then
        Buttons.SetCooldownDuration(button.cooldown, duration)
    else
        Buttons.ClearCooldown(button.cooldown)
    end
    return true
end

local function same(a, b)
    for key, value in pairs(a) do
        if b[key] ~= value then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

-- Override bindings on a frame of their own. Set takes { [key] = button name } and changes the
-- bindings only when that differs from the ones in place (not in combat). A name may end in
-- ":mouse button" for a click with another button than LeftButton (the rings' keys). With an
-- override binding the key presses the button in Forever's controller interface too.
function Buttons.NewOverrides()
    local overrides = { applied = {} }
    local owner
    function overrides:Set(wanted)
        if same(wanted, self.applied) then return end
        owner = owner or CreateFrame("Frame")
        ClearOverrideBindings(owner)
        for key, target in pairs(wanted) do
            local name, mouseButton = target:match("^([^:]+):?(.*)$")
            SetOverrideBindingClick(owner, false, key, name, mouseButton ~= "" and mouseButton or "LeftButton")
        end
        self.applied = wanted
    end
    function overrides:Any()
        return next(self.applied) ~= nil
    end
    return overrides
end
