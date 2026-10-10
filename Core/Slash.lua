local _, ns = ...
local L = ns.L

-- /qol (or /qualityoflife) opens the settings; there's no minimap button.
SLASH_QOL1 = "/qol"
SLASH_QOL2 = "/qualityoflife"

SlashCmdList.QOL = function(message)
    local command = strtrim(message or ""):lower()
    if command == "help" then
        ns.Print(L.SLASH_HELP)
        return
    end
    ns.SettingsPanel:Open()
end
