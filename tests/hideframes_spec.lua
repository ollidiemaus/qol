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
        T.eq(ChatFrameMenuButton:GetParent(), ChatFrame1ButtonFrame)
        T.eq(TextToSpeechButtonFrame:GetParent(), UIParent)
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

    it("hides every other chat button with one option, and brings them back", function()
        local ns = start()
        local buttons = { ChatFrameMenuButton, ChatFrameChannelButton, ChatFrameToggleVoiceDeafenButton,
            ChatFrameToggleVoiceMuteButton, TextToSpeechButtonFrame }
        local parents = {}
        for i, button in ipairs(buttons) do parents[i] = button:GetParent() end
        ns.Options:Set("hideChatButtons", true)
        Stubs.RunTimers()
        for _, button in ipairs(buttons) do T.falsy(button:IsVisible()) end
        T.truthy(QuickJoinToastButton:IsVisible(), "the social button has its own option")
        -- Joining a voice channel shows the voice buttons.
        ChatFrameToggleVoiceDeafenButton:Show()
        T.falsy(ChatFrameToggleVoiceDeafenButton:IsVisible())
        ns.Options:Set("hideChatButtons", false)
        Stubs.RunTimers()
        for i, button in ipairs(buttons) do T.eq(button:GetParent(), parents[i]) end
    end)

    it("hides the chat buttons this client has", function()
        Stubs.LoadAddon()
        _G.TextToSpeechButtonFrame = nil
        _G.ChatFrameToggleVoiceMuteButton = nil
        Stubs.Login({ hideChatButtons = true })
        T.falsy(ChatFrameMenuButton:IsVisible())
        T.falsy(ChatFrameToggleVoiceDeafenButton:IsVisible())
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
