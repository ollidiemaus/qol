local _, ns = ...
local Options = ns.Options

-- Takes the combat log (ChatFrame2) out of the chat panel. The game offers no way to close it, and
-- its own docking functions write to the chat frames and the dock, which would taint the chat. So
-- only widget methods are used:
--   * the window goes to the hidden holder, so it never shows, docked or not;
--   * its tab is scaled down to nothing. The dock lays the tabs out in a row, each anchored to the
--     right edge of the one before, and gives every tab its width and parent again on each update;
--     a scale it never touches, so the tab stays out of sight and the next tab moves up to close
--     the gap.
local CombatLog = {}
ns.CombatLog = CombatLog

local KEY = "hideCombatLog"
-- Small enough to be invisible and to take no room in the row of tabs (a scale of 0 isn't allowed).
local HIDDEN_SCALE = 0.001

-- The tab's own scale, while we shrank it.
local tabScale

function CombatLog:Apply()
    local frame, tab = ChatFrame2, ChatFrame2Tab
    if not (frame and tab) then return end
    local hidden = Options:Get(KEY)
    -- A window we never hid is left completely alone.
    if hidden or ns.Hider:IsHidden(frame) then
        ns.Hider:SetHidden(frame, hidden)
    end
    if hidden then
        tabScale = tabScale or tab:GetScale()
        tab:SetScale(HIDDEN_SCALE)
    elseif tabScale then
        tab:SetScale(tabScale)
        tabScale = nil
    end
end

local function schedule()
    ns.Later("combatLog", function() CombatLog:Apply() end)
end

function CombatLog:Init()
    Options:Watch({ KEY }, schedule)
    if Options:Get(KEY) then schedule() end
end
