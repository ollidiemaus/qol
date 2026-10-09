local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- The stub screen is 2560 x 1440 pixels; at effective scale 1 it is 768 units tall.
local UNIT = 768 / 1440

local function near(actual, expected, message)
    if math.abs(actual - expected) > 1e-6 then
        error((message or "values differ") .. ": expected " .. expected .. ", got " .. actual, 2)
    end
end

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns
end

local function borderFrame()
    -- The only parentless frame with four textures.
    for _, region in ipairs(Stubs.state().regions) do
        if region.kind == "Frame" and region.parent == nil and region.edges then return region end
    end
    return nil
end

describe("viewport", function()
    it("never touches WorldFrame while off", function()
        start({ viewportTop = 100 })
        local point, relativeTo = WorldFrame:GetPoint(1)
        T.eq(point, "TOPLEFT")
        T.eq(relativeTo, nil)
        T.eq(borderFrame(), nil)
    end)

    it("insets WorldFrame by the margins, converted from pixels", function()
        start({ viewportEnabled = true, viewportTop = 90, viewportBottom = 180, viewportLeft = 30, viewportRight = 60 })
        local topLeft = WorldFrame:PointFor("TOPLEFT")
        local bottomRight = WorldFrame:PointFor("BOTTOMRIGHT")
        T.eq(topLeft[2], UIParent)
        near(topLeft[4], 30 * UNIT)
        near(topLeft[5], -90 * UNIT)
        near(bottomRight[4], -60 * UNIT)
        near(bottomRight[5], 180 * UNIT)
    end)

    it("fills the margins with the chosen color", function()
        start({ viewportEnabled = true, viewportTop = 90, viewportColor = "ff336699" })
        local border = borderFrame()
        T.truthy(border and border.shown, "border shown")
        local top = border.edges.top
        near(top.height, 90 * UNIT)
        T.truthy(top.shown)
        T.falsy(border.edges.left.shown, "a zero margin has no texture")
        near(top.color[1], 0x33 / 255)
        near(top.color[2], 0x66 / 255)
        near(top.color[3], 0x99 / 255)
        T.eq(top.color[4], 1)
    end)

    it("restores the game's anchors when turned off", function()
        local ns = start({ viewportEnabled = true, viewportTop = 90 })
        ns.Options:Set("viewportEnabled", false)
        Stubs.RunTimers()
        T.eq(WorldFrame:GetNumPoints(), 2)
        local point, relativeTo, _, x, y = WorldFrame:GetPoint(1)
        T.eq(point, "TOPLEFT")
        T.eq(relativeTo, nil)
        T.eq(x, 0)
        T.eq(y, 0)
        T.falsy(borderFrame().shown)
    end)

    it("follows slider changes", function()
        local ns = start({ viewportEnabled = true })
        ns.Options:Set("viewportLeft", 120)
        Stubs.RunTimers()
        near(WorldFrame:PointFor("TOPLEFT")[4], 120 * UNIT)
    end)

    it("waits for the end of combat", function()
        local ns = start()
        Stubs.SetCombat(true)
        ns.Options:Set("viewportEnabled", true)
        ns.Options:Set("viewportTop", 90)
        Stubs.RunTimers()
        T.eq(WorldFrame:PointFor("TOPLEFT")[5], 0)
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        near(WorldFrame:PointFor("TOPLEFT")[5], -90 * UNIT)
    end)

    -- What Blizzard's CinematicFrame does: letterbox WorldFrame at the start, reset it at the end.
    local function startCinematic()
        CinematicFrame:Show()
        WorldFrame:ClearAllPoints()
        WorldFrame:SetPoint("TOPLEFT", nil, "TOPLEFT", 0, -100)
        WorldFrame:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", 0, 100)
        Stubs.Fire("CINEMATIC_START", true, 0)
    end

    local function stopCinematic()
        CinematicFrame:Hide()
        WorldFrame:SetAllPoints(nil)
        Stubs.Fire("CINEMATIC_STOP")
    end

    it("leaves WorldFrame to the game during a cinematic, and comes back after it", function()
        start({ viewportEnabled = true, viewportTop = 90, viewportLeft = 30 })
        startCinematic()
        T.falsy(borderFrame().shown, "margins hidden during the cinematic")
        -- A display change mid-cinematic (Alt+Enter, a window resize) must not move WorldFrame.
        Stubs.Fire("DISPLAY_SIZE_CHANGED")
        Stubs.RunTimers()
        T.eq(WorldFrame:PointFor("TOPLEFT")[5], -100, "still the game's letterbox")

        stopCinematic()
        Stubs.RunTimers()
        near(WorldFrame:PointFor("TOPLEFT")[5], -90 * UNIT)
        T.truthy(borderFrame().shown, "margins back")
    end)

    it("waits out a cinematic that is already playing at login", function()
        Stubs.LoadAddon()
        CinematicFrame:Show() -- a new character's opening cinematic
        Stubs.Login({ viewportEnabled = true, viewportTop = 90 })
        T.eq(WorldFrame:PointFor("TOPLEFT")[5], 0)
        stopCinematic()
        Stubs.RunTimers()
        near(WorldFrame:PointFor("TOPLEFT")[5], -90 * UNIT)
    end)

    it("catches the end of a movie that just ran out", function()
        local ns = start({ viewportEnabled = true })
        MovieFrame:Show()
        Stubs.Fire("PLAY_MOVIE", 1)
        ns.Options:Set("viewportTop", 90)
        Stubs.RunTimers()
        T.eq(WorldFrame:PointFor("TOPLEFT")[5], 0, "no change while the movie plays")
        Stubs.AdvanceTime()
        T.eq(WorldFrame:PointFor("TOPLEFT")[5], 0, "still playing")
        MovieFrame:Hide() -- no STOP_MOVIE: the movie simply ended
        Stubs.AdvanceTime()
        near(WorldFrame:PointFor("TOPLEFT")[5], -90 * UNIT)
    end)

    it("checks back on one timer, however many changes wait for a cutscene", function()
        local ns = start({ viewportEnabled = true })
        CinematicFrame:Show()
        for top = 1, 5 do
            ns.Options:Set("viewportTop", top)
            Stubs.RunTimers()
        end
        T.eq(#Stubs.state().delayed, 1)
    end)

    it("doesn't start checking for cutscenes while it was never on", function()
        start()
        startCinematic()
        Stubs.Fire("DISPLAY_SIZE_CHANGED")
        stopCinematic()
        Stubs.RunTimers()
        T.eq(#Stubs.state().delayed, 0)
        T.eq(borderFrame(), nil)
    end)

    it("always leaves a quarter of the screen to the world", function()
        local ns = start()
        local first, second = ns.Viewport.FitMargins(800, 800, 1440)
        near(first + second, 1440 * 0.75)
        near(first, second)
        T.same({ ns.Viewport.FitMargins(100, 50, 1440) }, { 100, 50 })
    end)

    it("reads AARRGGBB colors and falls back to black", function()
        local ns = start()
        T.same({ ns.Viewport.ParseColor("ffff8000") }, { 1, 128 / 255, 0 })
        T.same({ ns.Viewport.ParseColor("nonsense") }, { 0, 0, 0 })
    end)
end)
