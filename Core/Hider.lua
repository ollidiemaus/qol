local _, ns = ...

-- Blizzard frames the player chose to hide are parented to one hidden frame. Blizzard's own Show()
-- calls (switching between controller and keyboard shows the micro menu, bags and social button
-- again, for example) then change nothing, and no Blizzard method is hooked or replaced. The holder
-- is a child of UIParent, so a reparented frame keeps its effective scale and everything anchored
-- to it stays where it was (on Forever the main action bar is anchored to the micro menu).
local Hider = { parents = {} }
ns.Hider = Hider

local holder = CreateFrame("Frame", nil, UIParent)
holder:Hide()
Hider.holder = holder

-- Only call this through ns.Later: some of these frames are protected in combat.
function Hider:SetHidden(frame, hidden)
    if hidden then
        if frame:GetParent() ~= holder then
            self.parents[frame] = frame:GetParent()
            frame:SetParent(holder)
        end
    elseif frame:GetParent() == holder then
        frame:SetParent(self.parents[frame] or UIParent)
        self.parents[frame] = nil
    end
end

function Hider:IsHidden(frame)
    return frame:GetParent() == holder
end
