local _, ns = ...

-- What the addon's own action buttons (the controller back buttons, the ring) share: the look of an
-- action slot, and override bindings that press a button with the keys bound to it.
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

-- Icon, usability, count and cooldown of an action slot on a button's own regions (icon, count,
-- cooldown), as the game's action buttons show them. Returns whether the slot holds an action.
function Buttons.RefreshAction(button, slot)
    local actions = C_ActionBar
    if not (slot and actions and actions.HasAction(slot)) then
        button.icon:Hide()
        button.count:SetText("")
        button.cooldown:Clear()
        return false
    end
    button.icon:SetTexture(actions.GetActionTexture(slot))
    button.icon:Show()
    local usable, noMana = actions.IsUsableAction(slot)
    if ns.IsUsable(usable) and usable then
        button.icon:SetVertexColor(1, 1, 1)
    elseif ns.IsUsable(noMana) and noMana then
        button.icon:SetVertexColor(0.5, 0.5, 1)
    else
        button.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
    if actions.GetActionDisplayCount then
        button.count:SetText(actions.GetActionDisplayCount(slot, 9999))
    end
    local duration = actions.GetActionCooldownDuration and actions.GetActionCooldownDuration(slot)
    if duration then
        button.cooldown:SetCooldownFromDurationObject(duration)
    else
        button.cooldown:Clear()
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
-- bindings only when that differs from the ones in place (not in combat). With an override binding
-- the key presses the button in Forever's controller interface too.
function Buttons.NewOverrides()
    local overrides = { applied = {} }
    local owner
    function overrides:Set(wanted)
        if same(wanted, self.applied) then return end
        owner = owner or CreateFrame("Frame")
        ClearOverrideBindings(owner)
        for key, name in pairs(wanted) do
            SetOverrideBindingClick(owner, false, key, name, "LeftButton")
        end
        self.applied = wanted
    end
    function overrides:Any()
        return next(self.applied) ~= nil
    end
    return overrides
end
