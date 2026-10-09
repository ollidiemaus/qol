local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns
end

local function coords()
    return MinimapCluster.MinimapContainer.PlayerCoords
end

describe("hiding frames", function()
    it("leaves every frame alone by default", function()
        start()
        T.eq(MicroMenuContainer:GetParent(), UIParent)
        T.eq(BagsBar:GetParent(), UIParent)
        T.eq(QuickJoinToastButton:GetParent(), UIParent)
        T.eq(coords():GetParent(), MinimapCluster.MinimapContainer)
    end)

    it("hides the chosen frames at login, even if the game shows them again", function()
        start({ hideMicroMenu = true, hideChatSocial = true, hideMinimapCoords = true })
        T.falsy(MicroMenuContainer:IsVisible())
        T.falsy(QuickJoinToastButton:IsVisible())
        T.falsy(coords():IsVisible())
        T.truthy(BagsBar:IsVisible())
        -- Switching from controller to keyboard calls Show() on these.
        QuickJoinToastButton:Show()
        T.falsy(QuickJoinToastButton:IsVisible())
    end)

    it("puts a frame back where it was when turned off", function()
        local ns = start({ hideMinimapCoords = true })
        ns.Options:Set("hideMinimapCoords", false)
        Stubs.RunTimers()
        T.eq(coords():GetParent(), MinimapCluster.MinimapContainer)
        T.truthy(coords():IsVisible())
    end)

    it("waits for the end of combat to move a protected frame", function()
        local ns = start()
        MicroMenuContainer.protected = true
        Stubs.SetCombat(true)
        ns.Options:Set("hideMicroMenu", true)
        Stubs.RunTimers()
        T.truthy(MicroMenuContainer:IsVisible())
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.falsy(MicroMenuContainer:IsVisible())
    end)

    it("copes with a client that lacks a frame", function()
        local ns = Stubs.LoadAddon()
        _G.MinimapCluster = { MinimapContainer = {} } -- retail: no coordinates under the minimap
        Stubs.Login({ hideMinimapCoords = true })
        ns.Options:Set("hideBagsBar", true)
        Stubs.RunTimers()
        T.falsy(BagsBar:IsVisible())
    end)
end)
