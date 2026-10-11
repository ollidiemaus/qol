local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns
end

-- The buff frame shows the tooltip for a buff gained; the game may give it its alpha back.
local function popUp()
    BuffFrameTooltip:SetAlpha(1)
    BuffFrameTooltip:Show()
    BuffFrameTooltip:RunScript("OnShow")
end

describe("buff tooltips", function()
    it("leaves the tooltip alone by default", function()
        start()
        popUp()
        T.eq(BuffFrameTooltip:GetAlpha(), 1)
        T.eq(BuffFrameTooltip.hooks.OnShow, nil)
    end)

    it("makes the tooltip for new buffs transparent each time it shows, and lets it show", function()
        start({ hideBuffTooltips = true })
        T.eq(BuffFrameTooltip:GetAlpha(), 0)
        popUp()
        T.eq(BuffFrameTooltip:GetAlpha(), 0)
        -- Still shown and in its place, for the game; only nothing of it is seen.
        T.truthy(BuffFrameTooltip:IsVisible())
        T.eq(BuffFrameTooltip:GetParent(), UIParent)
    end)

    it("shows the tooltip again when turned off", function()
        local ns = start({ hideBuffTooltips = true })
        ns.Options:Set("hideBuffTooltips", false)
        Stubs.RunTimers()
        T.eq(BuffFrameTooltip:GetAlpha(), 1)
        popUp()
        T.eq(BuffFrameTooltip:GetAlpha(), 1)
    end)

    it("changes the tooltip only once the settings are closed, in the controller interface", function()
        local ns = start()
        Stubs.SetControllerUI(true)
        SettingsPanel:Show()
        Stubs.SetControllerWindow(SettingsPanel)
        ns.Options:Set("hideBuffTooltips", true)
        Stubs.RunTimers()
        Stubs.AdvanceTime()
        T.eq(BuffFrameTooltip:GetAlpha(), 1)
        T.eq(BuffFrameTooltip.hooks.OnShow, nil)
        SettingsPanel:Hide()
        Stubs.SetControllerWindow(nil)
        Stubs.AdvanceTime()
        Stubs.AdvanceTime()
        T.eq(BuffFrameTooltip:GetAlpha(), 0)
    end)

    it("works in combat", function()
        local ns = start()
        Stubs.SetCombat(true)
        ns.Options:Set("hideBuffTooltips", true)
        Stubs.RunTimers()
        T.eq(BuffFrameTooltip:GetAlpha(), 0)
    end)

    it("copes with a client without the tooltip", function()
        Stubs.LoadAddon()
        _G.BuffFrameTooltip = nil
        Stubs.Login({ hideBuffTooltips = true, hideBagsBar = true })
        T.falsy(BagsBar:IsVisible())
    end)
end)
