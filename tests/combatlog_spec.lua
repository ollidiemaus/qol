local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns
end

describe("hiding the combat log", function()
    it("leaves the combat log alone by default", function()
        start()
        T.eq(ChatFrame2:GetParent(), UIParent)
        T.eq(ChatFrame2Tab:GetScale(), 1)
    end)

    it("hides the window and shrinks its tab out of the row of tabs", function()
        start({ hideCombatLog = true })
        T.falsy(ChatFrame2:IsVisible())
        T.truthy(ChatFrame2Tab:GetScale() < 0.01)
        -- The dock shows the window again when its tab is selected; it stays hidden.
        ChatFrame2:Show()
        T.falsy(ChatFrame2:IsVisible())
    end)

    it("keeps the tab small when the dock lays the tabs out again", function()
        start({ hideCombatLog = true })
        -- The dock gives the tab its parent, width and anchor again, never its scale.
        ChatFrame2Tab:SetParent(UIParent)
        ChatFrame2Tab:SetWidth(80)
        Stubs.RunTimers()
        T.truthy(ChatFrame2Tab:GetScale() < 0.01)
    end)

    it("brings window and tab back as they were", function()
        local ns = Stubs.LoadAddon()
        ChatFrame2Tab:SetScale(0.9)
        Stubs.Login({ hideCombatLog = true })
        ns.Options:Set("hideCombatLog", false)
        Stubs.RunTimers()
        T.eq(ChatFrame2:GetParent(), UIParent)
        T.eq(ChatFrame2Tab:GetScale(), 0.9)
    end)

    it("copes with a client without a combat log window", function()
        Stubs.LoadAddon()
        _G.ChatFrame2Tab = nil
        Stubs.Login({ hideCombatLog = true })
        T.eq(ChatFrame2:GetParent(), UIParent)
    end)
end)
