local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns
end

local MAGE = { 0.25, 0.78, 0.92, 1 }
local DEFAULT = { 1, 1, 1, 1 }

-- The color the bar shows and whether its texture is desaturated.
local function look(frameName)
    local bar = Stubs.HealthBar(frameName)
    return { color = bar.color, desaturated = bar.desaturated }
end

local function classColored(frameName, color)
    T.same(look(frameName), { color = color, desaturated = true }, frameName)
end

local function untouched(frameName)
    T.same(look(frameName), { color = DEFAULT, desaturated = false }, frameName)
end

local function target(info)
    Stubs.SetUnit("target", info)
    Stubs.Fire("PLAYER_TARGET_CHANGED")
    Stubs.RunTimers()
end

describe("class colored health bars", function()
    it("leave every bar alone by default", function()
        start()
        target({ isPlayer = true, class = "ROGUE" })
        for _, frameName in ipairs({ "PlayerFrame", "TargetFrame", "TargetFrameToT", "FocusFrame", "FocusFrameToT" }) do
            untouched(frameName)
        end
    end)

    it("tint the desaturated default bar in the class color", function()
        start({ classColorPlayer = true })
        classColored("PlayerFrame", MAGE)
        untouched("TargetFrame")
    end)

    it("follow the target, and give units without a clear class the default bar", function()
        start({ classColorTarget = true })
        target({ isPlayer = true, class = "ROGUE" })
        classColored("TargetFrame", { 1, 0.96, 0.41, 1 })
        -- Most NPCs report a class (warrior, usually) without having one that means anything.
        target({ isPlayer = false, class = "WARRIOR" })
        untouched("TargetFrame")
        target(nil)
        untouched("TargetFrame")
    end)

    it("color NPCs the game shows like players", function()
        start({ classColorTarget = true })
        target({ isPlayer = false, treatAsPlayer = true, class = "PRIEST" })
        classColored("TargetFrame", { 1, 1, 1, 1 })
    end)

    it("follow the target of target, the focus and the focus target", function()
        start({ classColorTargetOfTarget = true, classColorFocus = true, classColorFocusTarget = true })
        Stubs.SetUnit("targettarget", { isPlayer = true, class = "WARRIOR" })
        Stubs.Fire("UNIT_TARGET", "target")
        Stubs.RunTimers()
        classColored("TargetFrameToT", { 0.78, 0.61, 0.43, 1 })

        Stubs.SetUnit("focus", { isPlayer = true, class = "MAGE" })
        Stubs.Fire("PLAYER_FOCUS_CHANGED")
        Stubs.RunTimers()
        classColored("FocusFrame", MAGE)

        Stubs.SetUnit("focustarget", { isPlayer = true, class = "ROGUE" })
        Stubs.Fire("UNIT_TARGET", "focus")
        Stubs.RunTimers()
        classColored("FocusFrameToT", { 1, 0.96, 0.41, 1 })
    end)

    it("change color in combat, without waiting for it to end", function()
        start({ classColorTarget = true })
        Stubs.SetCombat(true)
        target({ isPlayer = true, class = "MAGE" })
        classColored("TargetFrame", MAGE)
    end)

    it("show the default bar for a vehicle on the player frame", function()
        start({ classColorPlayer = true })
        Stubs.HealthBar("PlayerFrame").unit = "vehicle"
        Stubs.Fire("UNIT_ENTERED_VEHICLE", "player")
        Stubs.RunTimers()
        untouched("PlayerFrame")
        Stubs.HealthBar("PlayerFrame").unit = "player"
        Stubs.Fire("UNIT_EXITED_VEHICLE", "player")
        Stubs.RunTimers()
        classColored("PlayerFrame", MAGE)
    end)

    it("restore exactly what the bar had when turned off", function()
        local ns = Stubs.LoadAddon()
        local bar = Stubs.HealthBar("PlayerFrame")
        bar.color = { 0.2, 0.9, 0.2, 0.8 }
        Stubs.Login({ classColorPlayer = true })
        classColored("PlayerFrame", MAGE)
        ns.Options:Set("classColorPlayer", false)
        Stubs.RunTimers()
        T.same(look("PlayerFrame"), { color = { 0.2, 0.9, 0.2, 0.8 }, desaturated = false })
    end)

    it("treat a secret class or player flag as unknown", function()
        start({ classColorTarget = true })
        target({ isPlayer = true, class = Stubs.SECRET })
        untouched("TargetFrame")
        target({ isPlayer = Stubs.SECRET, class = "MAGE" })
        untouched("TargetFrame")
    end)

    it("ignore events for units none of the bars show", function()
        start({ classColorTarget = true })
        Stubs.SetUnit("target", { isPlayer = true, class = "MAGE" })
        Stubs.Fire("UNIT_TARGET", "raid7")
        Stubs.RunTimers()
        untouched("TargetFrame")
    end)
end)
