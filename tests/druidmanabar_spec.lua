local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local MANA, RAGE, ENERGY = 0, 1, 3
local GLOW = "UI-HUD-UnitFrame-Player-PortraitOn-InCombat"
local GLOW_THIRD_BAR = "UI-HUD-UnitFrame-Player-PortraitOn-ClassResource-InCombat"
local GLOW_VEHICLE = "UI-HUD-UnitFrame-Player-PortraitOn-Vehicle-InCombat"

local function druid(powerType)
    return { isPlayer = true, class = "DRUID", powerType = powerType, power = 80, maxPower = 100, mana = 600,
        maxMana = 2000 }
end

local function start(savedOptions, player)
    local ns = Stubs.LoadAddon()
    Stubs.SetUnit("player", player or druid(ENERGY))
    Stubs.Login(savedOptions)
    return ns
end

local function container()
    return Stubs.PlayerFrame().PlayerFrameContainer
end

-- Our bar: the status bar on the frame the player frame's bars sit on.
local function manaBar()
    local main = Stubs.PlayerFrame().PlayerFrameContent.PlayerFrameContentMain
    for _, region in ipairs(Stubs.state().regions) do
        if region.kind == "StatusBar" and region.parent == main then return region end
    end
    return nil
end

-- Our art: the texture on the player frame's art with room for a third bar.
local function art()
    for _, region in ipairs(Stubs.state().regions) do
        if region.parent == container() and region.atlas == "UI-HUD-UnitFrame-Player-PortraitOn-ClassResource" then
            return region
        end
    end
    return nil
end

-- The bar's texts by where they sit: CENTER, LEFT and RIGHT.
local function texts()
    local found = {}
    for _, region in ipairs(Stubs.state().regions) do
        if region.kind == "FontString" and region.parent == manaBar() then
            found[region.points[1][1]] = region.text
        end
    end
    return found
end

-- Where the threat glow is centered: the last CENTER point (SetPoint replaces it in the game).
local function glowOffset()
    local offset
    for _, p in ipairs(container().FrameFlash.points) do
        if p[1] == "CENTER" then offset = { p[4], p[5] } end
    end
    return offset
end

local function shown()
    local bar = manaBar()
    return bar ~= nil and bar:IsShown()
end

-- The frame as Blizzard draws it without a third bar.
local function untouched()
    T.falsy(shown(), "no mana bar")
    T.falsy(art() and art():IsShown(), "no third-bar art")
    T.eq(container().FrameTexture:GetAlpha(), 1)
    T.eq(container().FrameFlash.atlas, GLOW)
    T.same(glowOffset(), { -1.5, 1 })
end

local function withThirdBar()
    T.truthy(shown(), "mana bar")
    T.truthy(art():IsShown(), "third-bar art")
    T.eq(container().FrameTexture:GetAlpha(), 0)
    T.eq(container().FrameFlash.atlas, GLOW_THIRD_BAR)
    T.same(glowOffset(), { -2, 0.5 })
end

local function shift(powerType)
    Stubs.state().units.player.powerType = powerType
    Stubs.Fire("UPDATE_SHAPESHIFT_FORM")
    Stubs.Fire("UNIT_DISPLAYPOWER", "player")
    Stubs.RunTimers()
end

describe("druid mana bar", function()
    it("leaves the player frame alone by default", function()
        start()
        T.falsy(manaBar(), "no bar created")
        untouched()
    end)

    it("shows the mana in a third bar under energy, in the frame's third-bar art", function()
        start({ druidManaBar = true })
        withThirdBar()
        local bar = manaBar()
        T.same(bar.points[1], { "TOPLEFT", Stubs.PlayerFrame().PlayerFrameContent.PlayerFrameContentMain,
            "TOPLEFT", 85, -73 })
        T.eq(bar.width, 124)
        T.eq(bar.height, 9)
        T.eq(bar.statusBarTexture, "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana")
        T.eq(bar.maxValue, 2000)
        T.eq(bar.value, 600)
        T.same(art().points[1], { "CENTER", container(), "CENTER", 0, -1.5 })
        T.eq(bar.mouseMotion, true)
        T.eq(bar.mouseClickEnabled, false)
    end)

    it("comes and goes with bear and cat form", function()
        start({ druidManaBar = true }, druid(MANA))
        untouched()
        shift(RAGE)
        withThirdBar()
        shift(MANA)
        untouched()
        shift(ENERGY)
        withThirdBar()
    end)

    it("shifts in combat too", function()
        start({ druidManaBar = true }, druid(MANA))
        Stubs.SetCombat(true)
        shift(RAGE)
        withThirdBar()
        shift(MANA)
        untouched()
    end)

    it("stays away from characters without mana", function()
        start({ druidManaBar = true }, { isPlayer = true, class = "WARRIOR", powerType = RAGE, power = 50,
            maxPower = 100 })
        untouched()
    end)

    it("follows the mana as it changes", function()
        start({ druidManaBar = true })
        Stubs.state().units.player.mana = 750
        Stubs.Fire("UNIT_POWER_FREQUENT", "player", "ENERGY")
        T.eq(manaBar().value, 600, "energy changes leave it")
        Stubs.Fire("UNIT_POWER_FREQUENT", "player", "MANA")
        T.eq(manaBar().value, 750)
        Stubs.state().units.player.maxMana = 2500
        Stubs.Fire("UNIT_MAXPOWER", "player", "MANA")
        Stubs.RunTimers()
        T.eq(manaBar().maxValue, 2500)
    end)

    it("gives the glow its atlas again after Blizzard draws the frame", function()
        start({ druidManaBar = true })
        Stubs.DrawPlayerFrame()
        Stubs.Fire("PLAYER_ENTERING_WORLD")
        Stubs.RunTimers()
        withThirdBar()
    end)

    it("stands aside in a vehicle and leaves the vehicle's glow alone", function()
        start({ druidManaBar = true })
        Stubs.DrawPlayerFrame(true)
        Stubs.Fire("UNIT_ENTERED_VEHICLE", "player")
        Stubs.RunTimers()
        T.falsy(shown(), "no mana bar")
        T.falsy(art():IsShown(), "no third-bar art")
        T.eq(container().FrameTexture:GetAlpha(), 1)
        T.eq(container().FrameFlash.atlas, GLOW_VEHICLE)
        Stubs.DrawPlayerFrame()
        Stubs.Fire("UNIT_EXITED_VEHICLE", "player")
        Stubs.RunTimers()
        withThirdBar()
    end)

    it("stands aside for a third bar of Blizzard's or a class bar under the frame", function()
        start({ druidManaBar = true })
        Stubs.PlayerFrame().activeAlternatePowerBar = Stubs.NewFrame()
        Stubs.DrawPlayerFrame()
        Stubs.PlayerFrame().PlayerFrameContainer.FrameFlash:SetAtlas(GLOW_THIRD_BAR)
        Stubs.Fire("UNIT_DISPLAYPOWER", "player")
        Stubs.RunTimers()
        T.falsy(shown(), "no mana bar beside Blizzard's")
        T.eq(container().FrameFlash.atlas, GLOW_THIRD_BAR, "Blizzard's glow for its bar")
        Stubs.PlayerFrame().activeAlternatePowerBar = nil
        Stubs.PlayerFrame().classPowerBar = Stubs.NewFrame()
        shift(ENERGY)
        T.falsy(shown(), "no mana bar over the combo points")
        Stubs.PlayerFrame().classPowerBar:Hide()
        shift(RAGE)
        T.truthy(shown(), "back once the class bar hides")
    end)

    it("puts the frame back when switched off", function()
        local ns = start({ druidManaBar = true })
        withThirdBar()
        ns.Options:Set("druidManaBar", false)
        Stubs.RunTimers()
        untouched()
    end)

    it("shows its numbers like the frame's other bars, by the Status Text setting", function()
        start({ druidManaBar = true })
        T.same(texts(), { CENTER = "", LEFT = "", RIGHT = "" }, "only under the mouse by default")
        manaBar():RunScript("OnEnter")
        T.same(texts(), { CENTER = "600 / 2000", LEFT = "", RIGHT = "" })
        manaBar():RunScript("OnLeave")
        T.same(texts(), { CENTER = "", LEFT = "", RIGHT = "" })

        local cvars = Stubs.state().cvars
        cvars.statusText, cvars.statusTextDisplay = "1", "PERCENT"
        Stubs.Fire("CVAR_UPDATE", "statusText", "1")
        T.same(texts(), { CENTER = "30%", LEFT = "", RIGHT = "" })
        cvars.statusTextDisplay = "BOTH"
        Stubs.Fire("CVAR_UPDATE", "statusTextDisplay", "BOTH")
        T.same(texts(), { CENTER = "", LEFT = "30%", RIGHT = "600" })
    end)

    it("passes secret mana on to the bar without doing sums with it", function()
        start({ druidManaBar = true })
        Stubs.state().cvars.statusText = "1"
        Stubs.state().units.player.mana = Stubs.SECRET
        Stubs.Fire("UNIT_POWER_FREQUENT", "player", "MANA")
        T.eq(manaBar().value, Stubs.SECRET)
        T.same(texts(), { CENTER = "", LEFT = "", RIGHT = "" })
    end)
end)
