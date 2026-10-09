local _, ns = ...
local Options = ns.Options

-- /rl as a short form of /reload, but only while nothing else answers to /rl: not the game, not
-- another addon. Slash commands are plain entries in SlashCmdList, so a clash can't break
-- anything; the game would just pick one of the two. We still stay out of the way.
local ReloadCommand = {}
ns.ReloadCommand = ReloadCommand

local COMMAND = "/rl"
local KEY = "FOREVERQOL_RELOAD"
local GLOBAL = "SLASH_" .. KEY .. "1"

local function reload()
    ReloadUI()
end

-- Whether any slash command already answers to COMMAND. Every command, the game's (in any
-- language) and every addon's, is a global "SLASH_<NAME><n>" holding its text, so one pass over
-- the globals finds it however and whenever it was registered.
function ReloadCommand.IsTaken()
    local upper = COMMAND:upper()
    if IsSecureCmd and IsSecureCmd(COMMAND) then return true end
    local known = hash_SlashCmdList and hash_SlashCmdList[upper]
    if known and known ~= reload then return true end
    for name, value in pairs(_G) do
        if type(name) == "string" and type(value) == "string" and ns.IsUsable(value)
            and name ~= GLOBAL and name:find("^SLASH_") and value:upper() == upper then
            return true
        end
    end
    return false
end

function ReloadCommand:IsRegistered()
    return _G[GLOBAL] == COMMAND
end

function ReloadCommand:Register()
    if self:IsRegistered() or self.IsTaken() then return end
    _G[GLOBAL] = COMMAND
    SlashCmdList[KEY] = reload
end

-- The game copies commands into hash_SlashCmdList the first time chat is used; that copy goes too.
function ReloadCommand:Unregister()
    if not self:IsRegistered() then return end
    _G[GLOBAL] = nil
    SlashCmdList[KEY] = nil
    if hash_SlashCmdList and hash_SlashCmdList[COMMAND:upper()] == reload then
        hash_SlashCmdList[COMMAND:upper()] = nil
    end
end

function ReloadCommand:Apply()
    if Options:Get("reloadCommand") then
        self:Register()
    else
        self:Unregister()
    end
end

function ReloadCommand:Init()
    Options:Watch({ "reloadCommand" }, function() ReloadCommand:Apply() end)
    -- Not before the first loading screen: other addons register their commands on PLAYER_LOGIN,
    -- and theirs come first.
    local applied = false
    ns.Events:On("PLAYER_ENTERING_WORLD", function()
        if applied then return end
        applied = true
        ReloadCommand:Apply()
    end)
end
