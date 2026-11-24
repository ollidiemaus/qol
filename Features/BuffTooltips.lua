local _, ns = ...
local Options = ns.Options

-- In the controller interface the buff frame shows the tooltip of each buff or debuff the player
-- gains or refreshes for a few seconds (BuffFrameMixin:ShowNextAuraForTooltip), in BuffFrameTooltip,
-- which nothing else uses: pointing at a buff or selecting it shows GameTooltip. With the option on,
-- a pre-call of the tooltip data processor stops the game before it fills and shows that tooltip,
-- also when the game builds it again. Nothing of the frame is touched and the aura's data, which can
-- be secret, isn't read.
--
-- A pop-up already up when the option is turned on runs out. With keyboard and mouse nothing is stopped.
local BuffTooltips = {}
ns.BuffTooltips = BuffTooltips

local KEY = "hideBuffTooltips"

-- The processor can't remove a call: added the first time the option is on, it stays and looks at
-- the option and the interface each time.
local added = false

local function addPreCall()
    if added or Options:Get(KEY) ~= true then return end
    local processor, types = TooltipDataProcessor, Enum and Enum.TooltipDataType
    local buffTooltip = BuffFrameTooltip
    if not (buffTooltip and processor and processor.AddTooltipPreCall and types and types.UnitAura) then return end
    added = true
    processor.AddTooltipPreCall(types.UnitAura, function(tooltip)
        if tooltip ~= buffTooltip then return false end
        return Options:Get(KEY) == true and ns.IsControllerUI()
    end)
end

function BuffTooltips:Init()
    Options:Watch({ KEY }, addPreCall)
    addPreCall()
end
