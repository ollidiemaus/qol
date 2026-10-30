local addonName, ns = ...

-- Settings are ready on ADDON_LOADED; the features start on PLAYER_LOGIN, once the default UI
-- (action bars, micro menu, minimap, chat) exists. Once loaded, it stops listening.
local function onLoaded(_, loaded)
    if loaded ~= addonName or ns.db then return end
    ns.Events:Off("ADDON_LOADED", onLoaded)
    if type(QoLDB) ~= "table" then
        QoLDB = {}
    end
    ns.SavedData:Migrate(QoLDB)
    ns.Options:Init(QoLDB)
    ns.SettingsPanel:Init()
    -- Before login, for the unit frame addons that look for it as they build their frames.
    ns.ClickCast:Provide()
end
ns.Events:On("ADDON_LOADED", onLoaded)

ns.Events:On("PLAYER_LOGIN", function()
    ns.Merchant:Init()
    ns.Quests:Init()
    ns.FasterAutoLoot:Init()
    ns.Tooltips:Init()
    ns.HideFrames:Init()
    ns.BuffTooltips:Init()
    ns.CombatLog:Init()
    ns.ChatClassColors:Init()
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
    ns.ClickCast:Init()
    ns.ReloadCommand:Init()
end)
