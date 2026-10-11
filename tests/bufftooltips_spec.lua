local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Forever with its controller interface on.
local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.SetControllerUI(true)
    Stubs.Login(savedOptions)
    return ns
end

-- The player turns the controller interface on or off.
local function switch(on)
    Stubs.SetControllerUI(on)
    Stubs.Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
    Stubs.RunTimers()
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

    it("leaves the tooltip alone with keyboard and mouse", function()
        Stubs.LoadAddon()
        Stubs.Login({ hideBuffTooltips = true })
        popUp()
        T.eq(BuffFrameTooltip:GetAlpha(), 1)
        T.eq(BuffFrameTooltip.hooks.OnShow, nil)
    end)

    it("follows the controller interface turned off and on", function()
        start({ hideBuffTooltips = true })
        switch(false)
        T.eq(BuffFrameTooltip:GetAlpha(), 1)
        popUp()
        T.eq(BuffFrameTooltip:GetAlpha(), 1)
        switch(true)
        T.eq(BuffFrameTooltip:GetAlpha(), 0)
        popUp()
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
