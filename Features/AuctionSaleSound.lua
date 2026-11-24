local _, ns = ...
local Options = ns.Options

-- Plays a cash register on every auction sale. The game announces one with an auction house
-- notification, whose chat line the game's chat code then writes itself, or with a system message;
-- which of them a client sends isn't said anywhere, so both count, and the throttle makes them one
-- ping. Only events heard: no chat filter, no frames.
local AuctionSaleSound = {}
ns.AuctionSaleSound = AuctionSaleSound

local KEY = "auctionSaleSound"
local FILE = "Interface\\AddOns\\QoL\\Media\\AuctionSale.ogg"

-- Sales this many seconds after a ping are silent; they don't make the silence longer.
local THROTTLE = 1
local pingedAt -- GetTime() at the last ping

-- The Master channel is heard with sound effects off; with all game sound off nothing is.
function AuctionSaleSound.Play()
    PlaySoundFile(FILE, "Master")
end

local function ping()
    local now = GetTime()
    if pingedAt and now - pingedAt < THROTTLE then return end
    pingedAt = now
    AuctionSaleSound.Play()
end

-- The game's format string as a pattern for the whole line. Its grammar escapes (French |2 for "de"
-- or "d'", Korean |1...;...; for a particle) may be in the line as they are or already replaced, so
-- they match anything; \1 to \3 keep the parts that aren't literal text through the escaping.
local function linePattern(format)
    local pattern = format:gsub("%%%%", "\1"):gsub("%%%d*%$?s", "\2")
        :gsub("|1[^;]*;[^;]*;", "\3"):gsub("|2 ?", "\3")
        :gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
        :gsub("\1", "%%%%"):gsub("\2", ".+"):gsub("\3", ".-")
    return "^" .. pattern .. "$"
end

local soldType    -- the notification type for an auction sale
local soldPattern -- the system message for one

local function onNotification(_, notification)
    if ns.IsUsable(notification) and notification == soldType then ping() end
end

local function onSystemMessage(_, text)
    if ns.IsUsable(text) and text:find(soldPattern) then ping() end
end

function AuctionSaleSound:Init()
    local notifications = Enum.AuctionHouseNotification
    soldType = notifications and notifications.AuctionSold
    soldPattern = ERR_AUCTION_SOLD_S and linePattern(ERR_AUCTION_SOLD_S)

    local groups = {}
    if soldType then
        groups[#groups + 1] = ns.Events:NewGroup(
            { "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION", "AUCTION_HOUSE_SHOW_NOTIFICATION" }, onNotification)
    end
    if soldPattern then
        groups[#groups + 1] = ns.Events:NewGroup({ "CHAT_MSG_SYSTEM" }, onSystemMessage)
    end
    local function apply()
        for _, group in ipairs(groups) do group:SetOn(Options:Get(KEY)) end
    end
    Options:Watch({ KEY }, apply)
    apply()
end
