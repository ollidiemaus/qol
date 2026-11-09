local _, ns = ...
local Options = ns.Options

-- The look of the game's Cooldown Manager, on WoW Forever: its icons without their border, in all
-- four rows (essential and utility cooldowns, tracked buff icons, tracked buff bars).
-- The border is an unnamed texture of the icon's template, found by its atlas; the game sets it
-- once and never touches it again, so it only gets alpha 0, and its former alpha back when the
-- option goes off. Only widget methods on that texture, always from ns.Later; nothing is written
-- on the game's rows or icons (the Cooldown Manager keys a table by secret aura instance IDs, so
-- its frames must stay untainted): what we changed is kept in weak tables of our own.
-- A row hands its pooled icons out again on every rebuild and builds new ones as it grows, so each
-- row's RefreshLayout gets a secure hook, which only asks for another pass. The rows are left
-- alone, without a hook, until the player turns the option on.
local CooldownManager = {}
ns.CooldownManager = CooldownManager

local KEY = "hideCooldownManagerBorders"
local ADDON = "Blizzard_CooldownViewer"
local BORDER_ATLAS = "ui-hud-cooldownmanager-iconoverlay"

-- The game's rows, by global name.
local ROWS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local function isForever()
    return WOW_PROJECT_ID ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

-- Whether the client is WoW Forever and has the Cooldown Manager's rows.
function CooldownManager.IsAvailable()
    if not isForever() then return false end
    for _, name in ipairs(ROWS) do
        if _G[name] then return true end
    end
    return false
end

-- Per icon we looked at: its border, or false for one without.
local borders = setmetatable({}, { __mode = "k" })
-- Per border we hid: its alpha before.
local saved = setmetatable({}, { __mode = "k" })
-- The rows (by name) whose rebuilds we hear of.
local hooked = {}

local function borderAmong(...)
    for index = 1, select("#", ...) do
        local region = select(index, ...)
        local atlas = region.GetAtlas and region:GetAtlas()
        if type(atlas) == "string" and atlas:lower() == BORDER_ATLAS then return region end
    end
    return nil
end

-- On the bar row the icon's art sits in a frame of its own beside the bar (item.Icon).
local function borderOf(item)
    local border = borders[item]
    if border == nil then
        border = borderAmong(item:GetRegions())
        local holder = item.Icon
        if not border and holder and type(holder.GetRegions) == "function" then
            border = borderAmong(holder:GetRegions())
        end
        border = border or false
        borders[item] = border
    end
    return border
end

local function hide(item)
    local border = borderOf(item)
    if border and saved[border] == nil then
        saved[border] = border:GetAlpha()
        border:SetAlpha(0)
    end
end

local schedule

local function rebuilt()
    if Options:Get(KEY) then schedule() end
end

function CooldownManager:Apply()
    if not Options:Get(KEY) then
        for border, alpha in pairs(saved) do
            border:SetAlpha(alpha)
            saved[border] = nil
        end
        return
    end
    for _, name in ipairs(ROWS) do
        local row = _G[name]
        if row then
            if not hooked[name] and type(row.RefreshLayout) == "function" then
                hooked[name] = true
                hooksecurefunc(row, "RefreshLayout", rebuilt)
            end
            local pool = row.itemFramePool
            if pool and pool.EnumerateActive then
                for item in pool:EnumerateActive() do hide(item) end
            end
        end
    end
end

local function apply()
    CooldownManager:Apply()
end

-- A texture's alpha may change in combat, and icons come up there too.
function schedule()
    ns.Later("cooldownManagerBorders", apply, true)
end

function CooldownManager:Init()
    if not isForever() then return end
    Options:Watch({ KEY }, schedule)
    -- Should the game load its Cooldown Manager after us.
    ns.Events:On("ADDON_LOADED", function(_, name)
        if name == ADDON then rebuilt() end
    end)
    rebuilt()
end
