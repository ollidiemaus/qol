local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Forever with its controller interface on.
local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.SetControllerUI(true)
    Stubs.Login(savedOptions)
    return ns
end

local function auraData()
    return { id = 774, lines = { { text = "Rejuvenation" } } }
end

-- The game fills the tooltip again while it is up, when its data arrived late.
local function rebuild()
    Stubs.ShowTooltip("UnitAura", auraData(), BuffFrameTooltip)
end

-- The buff frame shows the tooltip for a buff gained; setting its owner hides it first.
local function popUp()
    BuffFrameTooltip:Hide()
    rebuild()
end

local function assertShown()
    T.truthy(BuffFrameTooltip:IsVisible())
    T.eq(#BuffFrameTooltip.lines, 1)
end

local function assertKeptAway()
    T.falsy(BuffFrameTooltip:IsVisible())
    T.eq(#BuffFrameTooltip.lines, 0)
end

describe("buff tooltips", function()
    it("leaves the game's tooltips alone by default", function()
        start()
        popUp()
        assertShown()
        T.eq(next(Stubs.state().preCalls), nil)
    end)

    it("keeps the tooltip for a new buff away, also when the game builds it again", function()
        start({ hideBuffTooltips = true })
        popUp()
        assertKeptAway()
        rebuild()
        assertKeptAway()
    end)

    it("reads nothing from the tooltip's data", function()
        start({ hideBuffTooltips = true })
        Stubs.ShowTooltip("UnitAura", { id = Stubs.SECRET, lines = Stubs.SECRET }, BuffFrameTooltip)
        assertKeptAway()
    end)

    it("leaves the other aura tooltips and their IDs alone", function()
        start({ hideBuffTooltips = true, tooltipIDs = true })
        local tooltip = Stubs.ShowTooltip("UnitAura", auraData())
        T.truthy(tooltip.shown)
        T.eq(tooltip.lines[1].left, "Rejuvenation")
        T.eq(tooltip.lines[2].right, "774")
    end)

    it("turns off and on again without a reload", function()
        local ns = start()
        ns.Options:Set("hideBuffTooltips", true)
        popUp()
        assertKeptAway()
        ns.Options:Set("hideBuffTooltips", false)
        popUp()
        assertShown()
        ns.Options:Set("hideBuffTooltips", true)
        popUp()
        assertKeptAway()
    end)

    it("lets a pop-up that is up when the option is turned on run out", function()
        local ns = start()
        popUp()
        ns.Options:Set("hideBuffTooltips", true)
        Stubs.RunTimers()
        assertShown()
    end)

    it("can be turned on in combat", function()
        local ns = start()
        Stubs.SetCombat(true)
        ns.Options:Set("hideBuffTooltips", true)
        popUp()
        assertKeptAway()
    end)

    it("leaves the tooltip alone with keyboard and mouse", function()
        Stubs.LoadAddon()
        Stubs.Login({ hideBuffTooltips = true })
        popUp()
        assertShown()
    end)

    it("follows the interface turned on and off, without the switch event", function()
        Stubs.LoadAddon()
        Stubs.Login({ hideBuffTooltips = true })
        Stubs.SetControllerUI(true)
        popUp()
        assertKeptAway()
        Stubs.SetControllerUI(false)
        popUp()
        assertShown()
    end)

    it("follows the interface with the switch event", function()
        start({ hideBuffTooltips = true })
        for _, on in ipairs({ false, true }) do
            Stubs.SetControllerUI(on)
            Stubs.Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
            Stubs.RunTimers()
            popUp()
            if on then assertKeptAway() else assertShown() end
        end
    end)

    local function copesWithout(what, remove)
        it("copes with a client without " .. what, function()
            local ns = Stubs.LoadAddon()
            Stubs.SetControllerUI(true)
            remove()
            Stubs.Login({ hideBuffTooltips = true })
            ns.Options:Set("hideBuffTooltips", false)
            ns.Options:Set("hideBuffTooltips", true)
            T.eq(next(Stubs.state().preCalls), nil)
        end)
    end

    copesWithout("the tooltip", function() _G.BuffFrameTooltip = nil end)
    copesWithout("the tooltip data processor", function() _G.TooltipDataProcessor = nil end)
    copesWithout("tooltip pre-calls", function() TooltipDataProcessor.AddTooltipPreCall = nil end)
    copesWithout("tooltip data types", function() Enum.TooltipDataType = nil end)
    copesWithout("the aura tooltip type", function() Enum.TooltipDataType.UnitAura = nil end)
end)
