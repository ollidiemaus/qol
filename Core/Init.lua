local addonName, ns = ...

ns.name = addonName
ns.version = "dev"
do
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if getMetadata then
        local ok, version = pcall(getMetadata, addonName, "Version")
        if ok and type(version) == "string" and version ~= "" then
            ns.version = version
        end
    end
end

local PREFIX = "|cff33ff99Quality of Life|r: "

function ns.Print(message)
    local text = PREFIX .. tostring(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

-- Midnight-era clients (Forever and retail 12.x) hand out "secret" values in combat. Addon code
-- may pass them on but not compare or do arithmetic with them, so every game value we compute with
-- goes through this first.
function ns.IsUsable(value)
    if value == nil then return false end
    if issecretvalue and issecretvalue(value) then return false end
    return true
end

-- Forever's controller interface (Enable Controller UI in the controller settings) brings action
-- bars of its own. The game hides the standard bars then and never shows them while it's on, so the
-- features for those bars stand aside.
function ns.IsControllerUI()
    local getStyle = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
    local styles = Enum and Enum.InputDeviceInterfaceType
    if not (getStyle and styles and styles.Gamepad ~= nil) then return false end
    return getStyle() == styles.Gamepad
end

function ns.FormatMoney(copper)
    if GetMoneyString then
        return GetMoneyString(copper, true)
    end
    return tostring(copper)
end
