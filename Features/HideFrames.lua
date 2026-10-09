local _, ns = ...
local Options = ns.Options

-- Hides pieces of the default UI the player doesn't want: the system bar (micro menu), the bag
-- bar, the coordinates under the minimap and the social button above the chat.
local HideFrames = {}
ns.HideFrames = HideFrames

-- Option key -> the frame it hides. Looked up when needed, since not every client has every frame
-- (retail has no minimap coordinates, for example).
HideFrames.TARGETS = {
    -- The container, not MicroMenu itself: in vehicles and pet battles the game moves MicroMenu
    -- onto the vehicle bar, where it should still show.
    hideMicroMenu = function() return MicroMenuContainer end,
    hideBagsBar = function() return BagsBar end,
    hideMinimapCoords = function()
        local container = MinimapCluster and MinimapCluster.MinimapContainer
        return container and container.PlayerCoords
    end,
    hideChatSocial = function() return QuickJoinToastButton end,
}

local KEYS = {}
for key in pairs(HideFrames.TARGETS) do KEYS[#KEYS + 1] = key end

function HideFrames:Apply()
    for key, getFrame in pairs(self.TARGETS) do
        local frame = getFrame()
        if frame then
            local hidden = Options:Get(key)
            -- A frame we never hid is left completely alone.
            if hidden or ns.Hider:IsHidden(frame) then
                ns.Hider:SetHidden(frame, hidden)
            end
        end
    end
end

local function schedule()
    ns.Later("hideFrames", function() HideFrames:Apply() end)
end

function HideFrames:Init()
    Options:Watch(KEYS, schedule)
    schedule()
end
