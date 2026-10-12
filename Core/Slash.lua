local _, ns = ...
local L = ns.L

-- /qol (or /qualityoflife) opens the settings window, or closes it again; there's no minimap button.
-- /qol ring (or rings) opens the rings' editor.
SLASH_QOL1 = "/qol"
SLASH_QOL2 = "/qualityoflife"

SlashCmdList.QOL = function(message)
    local command = strtrim(message or ""):lower()
    if command == "help" then
        ns.Print(L.SLASH_HELP)
        return
    end
    if command == "ring" or command == "rings" then
        ns.RingEditor:Toggle()
        return
    end
    ns.SettingsPanel:Toggle()
end
