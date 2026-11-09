local _, ns = ...
local Options = ns.Options

-- Hides pieces of the default UI the player doesn't want: the system bar (micro menu), the bag
-- bar, the social button above the chat and the other buttons next to the chat, and the hit text
-- over the player's and the pet's portrait. The minimap's coordinates are hidden through their
-- Position, by Features/Minimap.lua.
local HideFrames = {}
ns.HideFrames = HideFrames

-- Option key -> the frames it hides. Looked up when needed, since not every client has every frame
-- (Classic Era has no Quick Join button, for example).
HideFrames.TARGETS = {
    -- The container, not MicroMenu itself: in vehicles and pet battles the game moves MicroMenu
    -- onto the vehicle bar, where it should still show.
    hideMicroMenu = function() return MicroMenuContainer end,
    hideBagsBar = function() return BagsBar end,
    -- Quick Join's toast button, or on Classic Era (no Quick Join) the Friends button by the chat.
    hideChatSocial = function() return QuickJoinToastButton or FriendsMicroButton end,
    -- The chat menu, the channel button, the voice buttons (only shown in a voice channel) and the
    -- text to speech button (only shown while text to speech is on).
    hideChatButtons = function()
        return ChatFrameMenuButton, ChatFrameChannelButton, ChatFrameToggleVoiceDeafenButton,
            ChatFrameToggleVoiceMuteButton, TextToSpeechButtonFrame
    end,
    -- The damage, heal and miss text over the player's and the pet's portrait. The game shows it on
    -- every hit and fades it with an OnUpdate that only runs while it's visible. Classic Era's old
    -- player frame has no content frames: its hit text is PlayerHitIndicator.
    hidePortraitHitText = function()
        local content = PlayerFrame and PlayerFrame.PlayerFrameContent
        local main = content and content.PlayerFrameContentMain
        local indicator = main and main.HitIndicator
        return (indicator and indicator.HitText) or PlayerHitIndicator, PetHitIndicator
    end,
}

local KEYS = {}
for key in pairs(HideFrames.TARGETS) do KEYS[#KEYS + 1] = key end

local function setHidden(hidden, ...)
    for i = 1, select("#", ...) do
        local frame = select(i, ...)
        -- A frame we never hid is left completely alone.
        if frame and (hidden or ns.Hider:IsHidden(frame)) then
            ns.Hider:SetHidden(frame, hidden)
        end
    end
end

function HideFrames:Apply()
    for key, getFrames in pairs(self.TARGETS) do
        setHidden(Options:Get(key), getFrames())
    end
end

local function apply()
    HideFrames:Apply()
end

local function schedule()
    ns.Later("hideFrames", apply)
end

function HideFrames:Init()
    Options:Watch(KEYS, schedule)
    schedule()
end
