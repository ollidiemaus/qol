local _, ns = ...
local Options = ns.Options

-- Names in chat in the class color of the player who wrote. The game has this built in: the
-- chatClassColorOverride setting says "0" for always, "1" for never, and anything else leaves it
-- to the class color setting of each chat channel. The option sets it to "0"; turning the option
-- off gives the setting back its default.
local ChatClassColors = {}
ns.ChatClassColors = ChatClassColors

local KEY = "chatClassColors"
local CVAR = "chatClassColorOverride"
local ALWAYS = "0"

-- Through C_CVar where the client has it. A setting this client doesn't know reads as nil.
local function call(name, ...)
    local api = C_CVar and C_CVar[name] or _G[name]
    if type(api) ~= "function" then return nil end
    local ok, value = pcall(api, ...)
    if ok then return value end
    return nil
end

function ChatClassColors.GetSetting()
    return call("GetCVar", CVAR)
end

function ChatClassColors:Apply()
    local current = self.GetSetting()
    if current == nil then return end
    if Options:Get(KEY) then
        if current ~= ALWAYS then call("SetCVar", CVAR, ALWAYS) end
    elseif current == ALWAYS then
        local default = call("GetCVarDefault", CVAR)
        if default ~= nil and default ~= current then call("SetCVar", CVAR, default) end
    end
end

local function schedule()
    ns.Later("chatClassColors", function() ChatClassColors:Apply() end)
end

-- At login only an option that is on does anything. The setting goes back to its default only
-- when the player turns the option off, so a value set some other way stays as long as the option
-- is never used.
function ChatClassColors:Init()
    Options:Watch({ KEY }, schedule)
    if Options:Get(KEY) then schedule() end
end
