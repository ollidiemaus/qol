local _, ns = ...
local Options = ns.Options

-- In the controller interface the buff frame shows the tooltip of each buff or debuff the player
-- gains or refreshes for a few seconds (BuffFrameMixin:ShowNextAuraForTooltip), in BuffFrameTooltip,
-- which nothing else uses: pointing at a buff or selecting it shows GameTooltip. With the option on
-- that tooltip is made transparent, again each time it shows, the way the game hides the tooltip of
-- its controller action bar editor (GamepadActionBarEditFrameMixin). It still shows and hides as
-- the game wants, only nothing of it is seen.
--
-- Not with the hidden holder: parented there it never showed, and on Forever pointing at a buff then
-- showed no tooltip either and the cursor stayed in sight after the game menu closed.
local BuffTooltips = {}
ns.BuffTooltips = BuffTooltips

local KEY = "hideBuffTooltips"

local hooked = false
-- Whether we made the tooltip transparent.
local faded = false

local function fade(tooltip)
    if tooltip:GetAlpha() > 0 then tooltip:SetAlpha(0) end
    faded = true
end

function BuffTooltips:Apply()
    local tooltip = BuffFrameTooltip
    if not tooltip then return end
    if Options:Get(KEY) then
        if not hooked then
            tooltip:HookScript("OnShow", function(shown)
                if Options:Get(KEY) then fade(shown) end
            end)
            hooked = true
        end
        fade(tooltip)
    elseif faded then
        -- A tooltip we never faded is left completely alone.
        tooltip:SetAlpha(1)
        faded = false
    end
end

local function schedule()
    ns.Later("buffTooltips", function() BuffTooltips:Apply() end, true)
end

function BuffTooltips:Init()
    Options:Watch({ KEY }, schedule)
    if Options:Get(KEY) then schedule() end
end
