local addonName, ns = ...

-- Settings are ready on ADDON_LOADED; the features start on PLAYER_LOGIN, once the default UI
-- (action bars, micro menu, minimap, chat) exists.
ns.Events:On("ADDON_LOADED", function(_, loaded)
    if loaded ~= addonName or ns.db then return end
    if type(QoLDB) ~= "table" then
        QoLDB = {}
    end
    ns.Options:Init(QoLDB)
    ns.SettingsPanel:Init()
end)

ns.Events:On("PLAYER_LOGIN", function()
    ns.Merchant:Init()
    ns.Quests:Init()
    ns.Tooltips:Init()
    ns.HideFrames:Init()
    ns.BuffTooltips:Init()
    ns.CombatLog:Init()
    ns.ChatClassColors:Init()
    ns.CombinedBagSort:Init()
    ns.CombinedBagLayout:Init()
    ns.MailBookmarks:Init()
    ns.ClassHealthBars:Init()
    ns.DruidManaBar:Init()
    ns.ScreenEdge:Init()
    ns.MinimapLayout:Init()
    ns.MapPins:Init()
    ns.Viewport:Init()
    ns.ActionBars:Init()
    ns.ButtonBorders:Init()
    ns.BarPaging:Init()
    ns.BackButtons:Init()
    ns.Ring:Init()
    ns.ReloadCommand:Init()
end)
