local _, ns = ...
local L = ns.L

-- /fqol (or /foreverqol) opens the settings; there's no minimap button.
SLASH_FOREVERQOL1 = "/fqol"
SLASH_FOREVERQOL2 = "/foreverqol"

SlashCmdList.FOREVERQOL = function(message)
    local command = strtrim(message or ""):lower()
    if command == "help" then
        ns.Print(L.SLASH_HELP)
        return
    end
    ns.SettingsPanel:Open()
end
