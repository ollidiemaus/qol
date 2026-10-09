local addonName, ns = ...

-- Settings are ready on ADDON_LOADED; the features start on PLAYER_LOGIN, once the default UI
-- (action bars, micro menu, minimap, chat) exists.
ns.Events:On("ADDON_LOADED", function(_, loaded)
    if loaded ~= addonName or ns.db then return end
    if type(ForeverQoLDB) ~= "table" then
        ForeverQoLDB = {}
    end
    ns.Options:Init(ForeverQoLDB)
    ns.SettingsPanel:Init()
end)

ns.Events:On("PLAYER_LOGIN", function()
    ns.Merchant:Init()
    ns.Tooltips:Init()
    ns.HideFrames:Init()
    ns.Viewport:Init()
    ns.ActionBars:Init()
    ns.ReloadCommand:Init()
end)
