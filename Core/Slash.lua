local _, ns = ...
local L = ns.L

-- /qol (or /qualityoflife) opens the settings window, or closes it again; there's no minimap button.
-- /qol ring (or rings) opens it on the Ring page, where the rings are made. /qol probe measures the
-- hidden settings (Features/HiddenSettingsProbe.lua); it's for developers, so the help leaves it out.
SLASH_QOL1 = "/qol"
SLASH_QOL2 = "/qualityoflife"

SlashCmdList.QOL = function(message)
    local command = strtrim(message or ""):lower()
    if command == "help" then
        ns.Print(L.SLASH_HELP)
        return
    end
    if command == "ring" or command == "rings" then
        ns.SettingsPanel:Toggle("ring")
        return
    end
    if command == "probe" then
        ns.HiddenSettingsProbe.Run()
        return
    end
    ns.SettingsPanel:Toggle()
end
