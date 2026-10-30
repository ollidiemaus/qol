local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions, client)
    local ns = Stubs.LoadAddon({ client = client })
    Stubs.Login(savedOptions)
    return ns
end

local function coords()
    return MinimapCluster.MinimapContainer.PlayerCoords
end

local function isUnder(region, frame)
    local node = region:GetParent()
    while node and node ~= frame do node = node:GetParent() end
    return node == frame
end

local function playerHitText()
    return PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HitIndicator.HitText
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
        playerHitText():Show()
        PetHitIndicator:Show()
        T.truthy(playerHitText():IsVisible())
        T.truthy(PetHitIndicator:IsVisible())
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

    it("hides the player's and the pet's portrait hit text, even when the game shows it", function()
        start({ hidePortraitHitText = true })
        local hitText = playerHitText()
        T.falsy(isUnder(hitText, PlayerFrame.PlayerFrameContent.PlayerFrameContentMain), "left the player frame")
        T.falsy(isUnder(PetHitIndicator, PetFrame), "left the pet frame")
        -- CombatFeedback_OnCombatEvent shows the text on every hit.
        hitText:Show()
        PetHitIndicator:Show()
        T.falsy(hitText:IsVisible())
        T.falsy(PetHitIndicator:IsVisible())
    end)

    it("puts a frame back where it was when turned off", function()
        local ns = start({ hideMinimapCoords = true })
        ns.Options:Set("hideMinimapCoords", false)
        Stubs.RunTimers()
        T.eq(coords():GetParent(), MinimapCluster.MinimapContainer)
        T.truthy(coords():IsVisible())
    end)

    it("brings the portrait hit text back when turned off", function()
        local ns = start()
        local playerParent, petParent = playerHitText():GetParent(), PetHitIndicator:GetParent()
        ns.Options:Set("hidePortraitHitText", true)
        Stubs.RunTimers()
        ns.Options:Set("hidePortraitHitText", false)
        Stubs.RunTimers()
        T.eq(playerHitText():GetParent(), playerParent)
        T.eq(PetHitIndicator:GetParent(), petParent)
        playerHitText():Show()
        PetHitIndicator:Show()
        T.truthy(playerHitText():IsVisible())
        T.truthy(PetHitIndicator:IsVisible())
    end)

    it("hides the player's hit text on a client without the pet's", function()
        Stubs.LoadAddon()
        _G.PetHitIndicator = nil
        Stubs.Login({ hidePortraitHitText = true })
        playerHitText():Show()
        T.falsy(playerHitText():IsVisible())
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

    it("hides Classic Era's Friends button by the chat with the social button option", function()
        local ns = start({ hideChatSocial = true }, "classicEra")
        T.falsy(FriendsMicroButton:IsVisible())
        FriendsMicroButton:Show()
        T.falsy(FriendsMicroButton:IsVisible())
        ns.Options:Set("hideChatSocial", false)
        Stubs.RunTimers()
        T.eq(FriendsMicroButton:GetParent(), ChatFrame1ButtonFrame)
        T.truthy(FriendsMicroButton:IsVisible())
    end)

    it("hides the portrait hit text on Classic Era's player and pet hit indicators", function()
        local ns = start({ hidePortraitHitText = true }, "classicEra")
        -- CombatFeedback_OnCombatEvent shows them on every hit.
        PlayerHitIndicator:Show()
        PetHitIndicator:Show()
        T.falsy(PlayerHitIndicator:IsVisible())
        T.falsy(PetHitIndicator:IsVisible())
        ns.Options:Set("hidePortraitHitText", false)
        Stubs.RunTimers()
        T.eq(PlayerHitIndicator:GetParent(), PlayerFrame)
        T.truthy(PlayerHitIndicator:IsVisible())
    end)

    it("hides the micro menu, bags bar and chat buttons on Classic Era", function()
        start({ hideMicroMenu = true, hideBagsBar = true, hideChatButtons = true }, "classicEra")
        T.falsy(MicroMenuContainer:IsVisible())
        T.falsy(BagsBar:IsVisible())
        T.falsy(ChatFrameMenuButton:IsVisible())
        T.falsy(ChatFrameChannelButton:IsVisible())
        T.truthy(FriendsMicroButton:IsVisible(), "the Friends button has its own option")
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
