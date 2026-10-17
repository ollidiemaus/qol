local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns
end

local function set(ns, key, value)
    ns.Options:Set(key, value)
    Stubs.RunTimers()
end

local function coords()
    return MinimapCluster.MinimapContainer.PlayerCoords
end

-- Our square border frame on the minimap.
local function border()
    for _, region in ipairs(Stubs.state().regions) do
        if region.parent == Minimap and region.bronze then return region end
    end
    return nil
end

-- Where a moved element sits: its center relative to the frame around the minimap.
local function center(frame)
    local point = frame:PointFor("CENTER")
    T.truthy(point, "the element was moved")
    return { relativePoint = point[3], x = point[4], y = point[5], edge = point[2] }
end

-- The frame's first anchor, compared field by field (the frames themselves are cyclic tables).
local function firstPoint(frame, point, relativeTo, relativePoint, x, y)
    local p = { frame:GetPoint(1) }
    T.eq(p[1], point)
    T.eq(p[2], relativeTo)
    T.eq(p[3], relativePoint)
    T.eq(p[4], x)
    T.eq(p[5], y)
end

local function near(actual, expected, message)
    T.truthy(math.abs(actual - expected) < 0.01, (message or "value") .. ": expected " .. expected .. ", got " .. actual)
end

local MAGE = { 0.25, 0.78, 0.92 }
local GAME_YELLOW = { 1, 0.82, 0 }
-- The rows sit 3 units outside what is drawn around the map: a square map of 198 with the bronze
-- border reaches 7 further on each side.
local BRONZE_WIDTH = 198 + 2 * 7

describe("square minimap", function()
    it("leaves the minimap round by default", function()
        start()
        T.eq(Minimap.mask, "ui-hud-minimap-frame-generic-mask")
        T.truthy(MinimapCompassTexture:IsVisible())
        T.eq(GetMinimapShape, nil)
        T.eq(border(), nil)
    end)

    it("masks the map square, hides the round frame and tells other addons", function()
        start({ squareMinimap = true })
        T.eq(Minimap.mask, "Interface\\BUTTONS\\WHITE8X8")
        T.falsy(MinimapCompassTexture:IsVisible())
        T.falsy(MinimapCompassTextureUnderlay:IsVisible())
        T.eq(GetMinimapShape(), "SQUARE")
    end)

    it("frames the square map in Forever's bronze, or with a thin black line", function()
        local ns = start({ squareMinimap = true })
        local frame = border()
        T.truthy(frame:IsVisible())
        T.truthy(frame.bronze:IsShown())
        T.eq(frame.bronze.texture, "Interface\\AddOns\\QoL\\Media\\MinimapSquareBorder")
        for _, bar in ipairs(frame.black) do T.falsy(bar:IsShown()) end
        set(ns, "squareMinimapBorder", "black")
        T.falsy(frame.bronze:IsShown())
        for _, bar in ipairs(frame.black) do T.truthy(bar:IsShown()) end
    end)

    it("turns round again with the game's own mask", function()
        local ns = start({ squareMinimap = true })
        set(ns, "squareMinimap", false)
        T.eq(Minimap.mask, "ui-hud-minimap-frame-generic-mask")
        T.truthy(MinimapCompassTexture:IsVisible())
        T.eq(GetMinimapShape, nil)
        T.falsy(border():IsVisible())
    end)

    it("uses the classic round mask on clients without Forever's", function()
        local ns = start({ squareMinimap = true })
        Stubs.state().atlases = {}
        set(ns, "squareMinimap", false)
        T.eq(Minimap.mask, "Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end)

    it("stays square when the game masks the map again for the rotate setting", function()
        start({ squareMinimap = true })
        Minimap:SetMaskTexture("ui-hud-minimap-frame-generic-mask")
        Stubs.Fire("CVAR_UPDATE", "rotateMinimap", "1")
        Stubs.RunTimers()
        T.eq(Minimap.mask, "Interface\\BUTTONS\\WHITE8X8")
    end)

    it("squares the hybrid minimap when it loads", function()
        start({ squareMinimap = true })
        _G.HybridMinimap = { CircleMask = Stubs.NewFrame(nil) }
        Stubs.Fire("ADDON_LOADED", "Blizzard_HybridMinimap")
        Stubs.RunTimers()
        T.eq(HybridMinimap.CircleMask.texture, "Interface\\BUTTONS\\WHITE8X8")
    end)
end)

describe("minimap zone text", function()
    it("stays where the game puts it by default", function()
        start()
        local point = MinimapCluster.ZoneTextButton:PointFor("LEFT")
        T.eq(point[2], MinimapCluster.BorderTop)
        T.truthy(MinimapCluster.BorderTop:IsVisible())
    end)

    it("sits centered above the minimap, without the header bar", function()
        start({ minimapZoneText = "above", squareMinimap = true })
        local where = center(MinimapCluster.ZoneTextButton)
        T.eq(where.relativePoint, "TOP")
        near(where.x, 0)
        near(where.y, 3 + 12 / 2)
        -- The frame it sits on: the square map and the bronze border around it.
        firstPoint(where.edge, "TOPLEFT", Minimap, "TOPLEFT", -7, 7)
        T.falsy(MinimapCluster.BorderTop:IsVisible())
        T.eq(MinimapZoneText.justifyH, "CENTER")
        near(MinimapZoneText:GetWidth(), BRONZE_WIDTH)
    end)

    it("clears the round frame and its north triangle when the minimap is round", function()
        start({ minimapZoneText = "above" })
        local edge = center(MinimapCluster.ZoneTextButton).edge
        firstPoint(edge, "TOPLEFT", Minimap, "TOPLEFT", -8, 24)
    end)

    it("sits below the minimap, with the coordinates under it", function()
        start({ minimapZoneText = "below", squareMinimap = true })
        local where = center(MinimapCluster.ZoneTextButton)
        T.eq(where.relativePoint, "BOTTOM")
        near(where.y, -(3 + 12 / 2))
        local coordsPoint = coords():PointFor("TOP")
        T.eq(coordsPoint[2], where.edge)
        near(coordsPoint[5], -(3 + 12 + 2))
    end)

    it("goes back to the header bar as it was", function()
        local ns = start({ minimapZoneText = "below" })
        set(ns, "minimapZoneText", "default")
        T.eq(MinimapCluster.ZoneTextButton:PointFor("LEFT")[2], MinimapCluster.BorderTop)
        T.eq(MinimapCluster.ZoneTextButton:GetWidth(), 135)
        T.eq(MinimapZoneText:GetWidth(), 130)
        T.eq(MinimapZoneText.justifyH, "LEFT")
        T.eq(coords():PointFor("BOTTOM")[2], Minimap)
        T.truthy(MinimapCluster.BorderTop:IsVisible())
    end)

    it("ignores a position it doesn't know", function()
        start({ minimapZoneText = "sideways" })
        T.eq(MinimapCluster.ZoneTextButton:PointFor("LEFT")[2], MinimapCluster.BorderTop)
    end)

    it("waits for the end of combat to move", function()
        local ns = start()
        Stubs.SetCombat(true)
        set(ns, "minimapZoneText", "above")
        T.eq(MinimapCluster.ZoneTextButton:PointFor("LEFT")[2], MinimapCluster.BorderTop)
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.truthy(MinimapCluster.ZoneTextButton:PointFor("CENTER"))
    end)
end)

-- The zone text's frame as Forever 1.60.1 draws it: the button's own textures, no BorderTop.
local function startWithoutBorderTop(savedOptions)
    local ns = Stubs.LoadAddon()
    -- false, not nil: a missing capitalized key on a stub frame answers a no-op method.
    MinimapCluster.BorderTop = false
    Stubs.Login(savedOptions)
    return ns
end

local function frameShown()
    return MinimapCluster.ZoneTextButton.StateTexture:IsVisible()
end

describe("minimap zone text frame", function()
    it("leaves Forever's frame around the moved zone text out", function()
        startWithoutBorderTop({ minimapZoneText = "above" })
        T.falsy(frameShown())
        T.truthy(MinimapZoneText:IsVisible())
    end)

    it("leaves the frame in place by default", function()
        startWithoutBorderTop()
        T.truthy(frameShown())
    end)

    it("leaves the frame and its glow out at the default spot when asked", function()
        startWithoutBorderTop({ hideMinimapZoneTextFrame = true })
        T.falsy(frameShown())
        T.truthy(MinimapCluster.ZoneTextButton:IsVisible())
        T.truthy(MinimapZoneText:IsVisible())
        -- The game shows the glow on mouse-over; it stays out of sight.
        MinimapCluster.ZoneTextButton.AddTexture:SetShown(true)
        T.falsy(MinimapCluster.ZoneTextButton.AddTexture:IsVisible())
    end)

    it("brings the frame back when the option is turned off or the zone text goes home", function()
        local ns = startWithoutBorderTop({ hideMinimapZoneTextFrame = true })
        set(ns, "hideMinimapZoneTextFrame", false)
        T.truthy(frameShown())
        T.eq(MinimapCluster.ZoneTextButton.StateTexture:GetParent(), MinimapCluster.ZoneTextButton)
        T.eq(MinimapCluster.ZoneTextButton.AddTexture:GetParent(), MinimapCluster.ZoneTextButton)
        set(ns, "minimapZoneText", "below")
        T.falsy(frameShown())
        set(ns, "minimapZoneText", "default")
        T.truthy(frameShown())
    end)

    it("leaves the older header bar out too", function()
        local ns = start({ hideMinimapZoneTextFrame = true })
        T.falsy(MinimapCluster.BorderTop:IsVisible())
        set(ns, "hideMinimapZoneTextFrame", false)
        T.truthy(MinimapCluster.BorderTop:IsVisible())
    end)
end)

describe("minimap buttons", function()
    it("stay where the game puts them by default", function()
        start({ squareMinimap = true })
        T.eq(TimeManagerClockButton:PointFor("TOPRIGHT")[2], MinimapCluster.BorderTop)
        T.eq(AddonCompartmentFrame:PointFor("TOPLEFT")[2], GameTimeFrame)
        T.eq(MinimapCluster.Tracking:PointFor("RIGHT")[2], MinimapCluster.BorderTop)
        T.eq(MinimapCluster.DielFrame:PointFor("CENTER")[2], MinimapCluster)
        T.truthy(GameTimeFrame:IsVisible())
    end)

    it("put the clock at the right end of the row above", function()
        start({ squareMinimap = true, minimapClock = "topRight" })
        local where = center(TimeManagerClockButton)
        T.eq(where.relativePoint, "TOP")
        near(where.x, BRONZE_WIDTH / 2 - 40 / 2)
        near(where.y, 3 + 16 / 2)
    end)

    it("put things in the same spot side by side, the first one at the edge", function()
        start({ squareMinimap = true, minimapClock = "bottomLeft", minimapCompartment = "bottomLeft" })
        near(center(TimeManagerClockButton).x, -BRONZE_WIDTH / 2 + 20)
        near(center(AddonCompartmentFrame).x, -BRONZE_WIDTH / 2 + 40 + 4 + 8)
        -- The row is as high as its highest member.
        near(center(AddonCompartmentFrame).y, -(3 + 16 / 2))
    end)

    it("give the zone text the room the sides leave free", function()
        start({ squareMinimap = true, minimapZoneText = "above", minimapClock = "topRight", minimapTracking = "top" })
        -- 40 for the clock on the right, the same kept free on the left; the tracking button
        -- (17) shares the middle.
        local free = BRONZE_WIDTH - 2 * (40 + 4)
        near(MinimapZoneText:GetWidth(), free - (17 + 4))
        -- Tracking first, then the zone text, centered together.
        near(center(MinimapCluster.Tracking).x, -(free / 2) + 17 / 2)
    end)

    it("hide and come back as they were", function()
        local ns = start({ minimapCompartment = "hidden", minimapTracking = "hidden" })
        T.falsy(AddonCompartmentFrame:IsVisible())
        T.falsy(MinimapCluster.Tracking:IsVisible())
        -- The game shows them again when addons register or tracking changes.
        AddonCompartmentFrame:Show()
        T.falsy(AddonCompartmentFrame:IsVisible())
        set(ns, "minimapCompartment", "default")
        set(ns, "minimapTracking", "topLeft")
        T.truthy(AddonCompartmentFrame:IsVisible())
        T.eq(AddonCompartmentFrame:PointFor("TOPLEFT")[2], GameTimeFrame)
        T.truthy(MinimapCluster.Tracking:IsVisible())
        T.truthy(MinimapCluster.Tracking:PointFor("CENTER"))
    end)

    it("hide the calendar button", function()
        local ns = start({ hideMinimapCalendar = true })
        T.falsy(GameTimeFrame:IsVisible())
        set(ns, "hideMinimapCalendar", false)
        T.truthy(GameTimeFrame:IsVisible())
    end)

    it("move the coordinates under a row below the minimap", function()
        start({ squareMinimap = true, minimapDayNight = "bottomRight" })
        local edge = center(MinimapCluster.DielFrame).edge
        local coordsPoint = coords():PointFor("TOP")
        T.eq(coordsPoint[2], edge)
        near(coordsPoint[5], -(3 + 42 + 2))
    end)

    it("put the day and night icon back after the game places it again", function()
        start({ minimapDayNight = "topLeft" })
        -- Forever's skin sets the icon's center each time the minimap's scale is set.
        MinimapCluster.DielFrame:SetPoint("CENTER", MinimapCluster, "CENTER", 63, 72)
        Stubs.TriggerRegistry("Minimap.OnScaleUpdated", 1)
        Stubs.RunTimers()
        T.eq(center(MinimapCluster.DielFrame).relativePoint, "TOP")
    end)

    it("move the clock once it loads", function()
        Stubs.LoadAddon()
        local clock = TimeManagerClockButton
        _G.TimeManagerClockButton = nil
        Stubs.Login({ minimapClock = "bottom" })
        _G.TimeManagerClockButton = clock
        Stubs.Fire("ADDON_LOADED", "Blizzard_TimeManager")
        Stubs.RunTimers()
        T.eq(center(clock).relativePoint, "BOTTOM")
    end)

    it("copes with a client without the day and night icon", function()
        local ns = Stubs.LoadAddon()
        MinimapCluster.DielFrame = false -- this client has none
        Stubs.Login({ minimapDayNight = "hidden", minimapClock = "top" })
        T.falsy(ns.MinimapLayout.HasDayNight())
        T.truthy(center(TimeManagerClockButton))
    end)
end)

describe("minimap buttons inside the map", function()
    -- Centers relative to the map's center: the map is 198 across, buttons keep 4 from its edge.
    local function inside(frame)
        local point = frame:PointFor("CENTER")
        T.truthy(point, "the element was moved")
        T.eq(point[2], Minimap)
        T.eq(point[3], "CENTER")
        return { x = point[4], y = point[5] }
    end

    it("put the tracking button in a corner of the square map, drawn above the map", function()
        start({ squareMinimap = true, minimapTracking = "insideTopLeft" })
        local where = inside(MinimapCluster.Tracking)
        near(where.x, -(99 - 4 - 17 / 2))
        near(where.y, 99 - 4 - 17 / 2)
        T.truthy(MinimapCluster.Tracking:GetFrameLevel() > Minimap:GetFrameLevel())
    end)

    it("follow the round frame along the diagonal", function()
        start({ minimapDayNight = "insideBottomRight" })
        -- The round frame covers 7% of the radius; the icon is 42 across.
        local distance = (99 * 0.93 - 4 - 42 / 2) * math.sqrt(0.5)
        local where = inside(MinimapCluster.DielFrame)
        near(where.x, distance)
        near(where.y, -distance)
    end)

    it("sit side by side in a corner, the first one nearest the corner", function()
        start({ squareMinimap = true, minimapTracking = "insideBottomLeft", minimapDayNight = "insideBottomLeft" })
        near(inside(MinimapCluster.Tracking).x, -(99 - 4 - 17 / 2))
        near(inside(MinimapCluster.DielFrame).x, -(99 - 4 - 17 / 2) + 17 / 2 + 4 + 42 / 2)
        -- As low as the highest of them allows.
        near(inside(MinimapCluster.Tracking).y, -(99 - 4 - 42 / 2))
    end)

    it("center at the top edge together", function()
        start({ squareMinimap = true, minimapTracking = "insideTop", minimapDayNight = "insideTop" })
        local total = 17 + 4 + 42
        near(inside(MinimapCluster.Tracking).x, -total / 2 + 17 / 2)
        near(inside(MinimapCluster.DielFrame).x, -total / 2 + 17 + 4 + 42 / 2)
        near(inside(MinimapCluster.DielFrame).y, 99 - 4 - 42 / 2)
    end)

    it("go back to their own level when they leave the map", function()
        local ns = start({ minimapTracking = "insideTop" })
        local level = Minimap:GetFrameLevel() + 5
        T.eq(MinimapCluster.Tracking:GetFrameLevel(), level)
        set(ns, "minimapTracking", "topLeft")
        T.eq(MinimapCluster.Tracking:GetFrameLevel(), 1)
        set(ns, "minimapTracking", "insideTop")
        set(ns, "minimapTracking", "default")
        T.eq(MinimapCluster.Tracking:GetFrameLevel(), 1)
        T.eq(MinimapCluster.Tracking:PointFor("RIGHT")[2], MinimapCluster.BorderTop)
    end)

    it("aren't offered to the clock", function()
        start({ minimapClock = "insideTop" })
        T.eq(TimeManagerClockButton:PointFor("TOPRIGHT")[2], MinimapCluster.BorderTop)
    end)
end)

describe("minimap FPS and ping", function()
    -- The frame keeps the width of "999 fps  999 ms": 15 characters, 5 units each in the stubs.
    local WIDTH = 15 * 5

    local function performance(ns)
        return ns.MinimapLayout:Performance()
    end

    it("aren't there by default", function()
        local ns = start()
        T.eq(performance(ns), nil)
        T.eq(#Stubs.state().delayed, 0)
    end)

    it("show the frame rate and the higher latency at the right end of the row above", function()
        local ns = start({ squareMinimap = true, minimapPerformance = "topRight" })
        local frame = performance(ns)
        T.eq(frame.text:GetText(), "60 fps  45 ms")
        local where = center(frame)
        T.eq(where.relativePoint, "TOP")
        near(where.x, BRONZE_WIDTH / 2 - WIDTH / 2)
        near(where.y, 3 + 16 / 2)
        -- The text keeps to the minimap's edge, however wide the numbers are.
        T.eq(frame.text:GetPoint(1), "RIGHT")
    end)

    it("sit next to the clock in the same spot", function()
        local ns = start({ squareMinimap = true, minimapClock = "bottomLeft", minimapPerformance = "bottomLeft" })
        near(center(TimeManagerClockButton).x, -BRONZE_WIDTH / 2 + 20)
        near(center(performance(ns)).x, -BRONZE_WIDTH / 2 + 40 + 4 + WIDTH / 2)
        T.eq(performance(ns).text:GetPoint(1), "LEFT")
    end)

    it("update once a second, and stop while hidden", function()
        local ns = start({ minimapPerformance = "bottom" })
        local frame = performance(ns)
        T.eq(frame.text:GetPoint(1), "CENTER")
        Stubs.state().framerate = 143.6
        Stubs.state().latencyWorld = 120
        Stubs.AdvanceTime()
        T.eq(frame.text:GetText(), "144 fps  120 ms")

        set(ns, "minimapPerformance", "hidden")
        T.falsy(frame:IsVisible())
        Stubs.state().framerate = 30
        Stubs.AdvanceTime()
        T.eq(#Stubs.state().delayed, 0)
        T.eq(frame.text:GetText(), "144 fps  120 ms")

        set(ns, "minimapPerformance", "topLeft")
        T.truthy(frame:IsVisible())
        T.eq(frame.text:GetText(), "30 fps  120 ms")
        T.eq(center(frame).relativePoint, "TOP")
    end)

    it("keep one timer when hidden and shown again within a second", function()
        local ns = start({ minimapPerformance = "top" })
        set(ns, "minimapPerformance", "hidden")
        set(ns, "minimapPerformance", "bottom")
        T.eq(#Stubs.state().delayed, 1)
        Stubs.AdvanceTime()
        T.eq(#Stubs.state().delayed, 1)
    end)

    it("have no default place and none inside the map", function()
        local ns = start({ minimapPerformance = "insideTop" })
        T.eq(performance(ns), nil)
        set(ns, "minimapPerformance", "default")
        T.eq(performance(ns), nil)
    end)

    it("show in class color, and white again when turned off", function()
        local ns = start({ minimapPerformance = "top", minimapPerformanceClassColor = true })
        local text = performance(ns).text
        T.same(text.textColor, MAGE)
        set(ns, "minimapPerformanceClassColor", false)
        T.same(text.textColor, { 1, 1, 1 })
    end)

    it("take the class color when they're placed after it was turned on", function()
        local ns = start({ minimapPerformanceClassColor = true })
        set(ns, "minimapPerformance", "bottomRight")
        T.same(performance(ns).text.textColor, MAGE)
    end)
end)

describe("minimap clock and coordinates in class color", function()
    it("color the clock, and give its own color back when turned off", function()
        local ns = start({ minimapClockClassColor = true })
        T.same(TimeManagerClockTicker.textColor, MAGE)
        set(ns, "minimapClockClassColor", false)
        T.same(TimeManagerClockTicker.textColor, { 1, 1, 1 })
    end)

    it("color the clock once it loads", function()
        Stubs.LoadAddon()
        local ticker = TimeManagerClockTicker
        _G.TimeManagerClockTicker = nil
        Stubs.Login({ minimapClockClassColor = true })
        _G.TimeManagerClockTicker = ticker
        Stubs.Fire("ADDON_LOADED", "Blizzard_TimeManager")
        Stubs.RunTimers()
        T.same(ticker.textColor, MAGE)
    end)

    it("color the coordinates", function()
        local ns = start({ minimapCoordsClassColor = true })
        T.same(coords().CoordText.textColor, MAGE)
        set(ns, "minimapCoordsClassColor", false)
        T.same(coords().CoordText.textColor, { 1, 1, 1 })
    end)

    it("leave both alone by default", function()
        start()
        T.eq(TimeManagerClockTicker.textColor, nil)
        T.eq(coords().CoordText.textColor, nil)
    end)
end)

describe("minimap zone text in class color", function()
    it("takes the class color, also after the game colors it for a new zone", function()
        start({ minimapZoneTextClassColor = true })
        T.same(MinimapZoneText.textColor, MAGE)
        MinimapZoneText:SetTextColor(0.1, 1, 0.1) -- a friendly zone
        Stubs.Fire("ZONE_CHANGED_NEW_AREA")
        Stubs.RunTimers()
        T.same(MinimapZoneText.textColor, MAGE)
    end)

    it("changes color in combat right away", function()
        start({ minimapZoneTextClassColor = true })
        Stubs.SetCombat(true)
        MinimapZoneText:SetTextColor(1, 0.1, 0.1)
        Stubs.Fire("ZONE_CHANGED")
        Stubs.RunTimers()
        T.same(MinimapZoneText.textColor, MAGE)
    end)

    it("gives back the game's latest color when turned off", function()
        local ns = start({ minimapZoneTextClassColor = true })
        MinimapZoneText:SetTextColor(0.1, 1, 0.1)
        Stubs.Fire("ZONE_CHANGED")
        Stubs.RunTimers()
        set(ns, "minimapZoneTextClassColor", false)
        T.same(MinimapZoneText.textColor, { 0.1, 1, 0.1 })
    end)

    it("leaves the color alone by default", function()
        start()
        Stubs.Fire("ZONE_CHANGED")
        Stubs.RunTimers()
        T.same(MinimapZoneText.textColor, GAME_YELLOW)
    end)
end)

describe("minimap font sizes", function()
    local function font(text) return { text:GetFont() } end

    it("leave the zone text and the clock alone by default", function()
        start()
        T.same(font(MinimapZoneText), { "Fonts\\FRIZQT__.TTF", 12, "" })
        T.same(font(TimeManagerClockTicker), { "Fonts\\ARIALN.TTF", 10, "OUTLINE" })
        T.eq(MinimapCluster.ZoneTextButton:GetHeight(), 12)
        T.eq(TimeManagerClockButton:GetWidth(), 40)
    end)

    it("set the zone text's size in its own font, and let its button and text grow with it", function()
        start({ minimapZoneTextSize = 18 })
        T.same(font(MinimapZoneText), { "Fonts\\FRIZQT__.TTF", 18, "" })
        T.eq(MinimapZoneText:GetHeight(), 18)
        T.eq(MinimapCluster.ZoneTextButton:GetHeight(), 18)
        -- Its width stays: the header bar or the row gives it that.
        T.eq(MinimapCluster.ZoneTextButton:GetWidth(), 135)
    end)

    it("let the clock's button grow both ways with a larger font", function()
        start({ minimapClockSize = 15 })
        T.same(font(TimeManagerClockTicker), { "Fonts\\ARIALN.TTF", 15, "OUTLINE" })
        T.eq(TimeManagerClockButton:GetWidth(), 40 * 1.5)
        T.eq(TimeManagerClockButton:GetHeight(), 16 * 1.5)
    end)

    it("keep the buttons' size for a smaller font", function()
        start({ minimapClockSize = 9, minimapZoneTextSize = 9 })
        T.eq(TimeManagerClockTicker.fontHeight, 9)
        T.eq(TimeManagerClockButton:GetWidth(), 40)
        T.eq(TimeManagerClockButton:GetHeight(), 16)
        T.eq(MinimapZoneText.fontHeight, 9)
        T.eq(MinimapZoneText:GetHeight(), 12)
    end)

    it("make room for the larger clock in the row", function()
        start({ squareMinimap = true, minimapClock = "topRight", minimapClockSize = 15 })
        local where = center(TimeManagerClockButton)
        near(where.x, BRONZE_WIDTH / 2 - 60 / 2)
        near(where.y, 3 + 24 / 2)
    end)

    it("give the game's font and sizes back when set to default", function()
        local ns = start({ minimapZoneTextSize = 20, minimapClockSize = 20 })
        set(ns, "minimapZoneTextSize", 0)
        set(ns, "minimapClockSize", 0)
        T.eq(MinimapZoneText:GetFontObject(), "GameFontNormal")
        T.same(font(MinimapZoneText), { "Fonts\\FRIZQT__.TTF", 12, "" })
        T.eq(MinimapZoneText:GetHeight(), 12)
        T.eq(MinimapCluster.ZoneTextButton:GetHeight(), 12)
        T.eq(TimeManagerClockTicker:GetFontObject(), "WhiteNormalNumberFont")
        T.same(font(TimeManagerClockTicker), { "Fonts\\ARIALN.TTF", 10, "OUTLINE" })
        T.eq(TimeManagerClockButton:GetWidth(), 40)
        T.eq(TimeManagerClockButton:GetHeight(), 16)
    end)

    it("go from one size to another from the game's size, not the last one", function()
        local ns = start({ minimapClockSize = 20 })
        set(ns, "minimapClockSize", 15)
        T.eq(TimeManagerClockTicker.fontHeight, 15)
        T.eq(TimeManagerClockButton:GetWidth(), 60)
    end)

    it("let the FPS and ping grow both ways with a larger font, and make room in the row", function()
        local ns = start({ squareMinimap = true, minimapPerformance = "topRight", minimapPerformanceSize = 15 })
        local frame = ns.MinimapLayout:Performance()
        T.same(font(frame.text), { "Fonts\\ARIALN.TTF", 15, "OUTLINE" })
        -- "999 fps  999 ms" is 75 wide at the clock's size of 10.
        T.eq(frame:GetWidth(), 75 * 1.5)
        T.eq(frame:GetHeight(), 16 * 1.5)
        local where = center(frame)
        near(where.x, BRONZE_WIDTH / 2 - 75 * 1.5 / 2)
        near(where.y, 3 + 24 / 2)
    end)

    it("size the FPS and ping when they get a row, and give back the clock's font", function()
        local ns = start({ minimapPerformanceSize = 20 })
        T.eq(ns.MinimapLayout:Performance(), nil)
        set(ns, "minimapPerformance", "bottom")
        local frame = ns.MinimapLayout:Performance()
        T.eq(frame.text.fontHeight, 20)
        T.eq(frame:GetWidth(), 150)
        set(ns, "minimapPerformanceSize", 0)
        T.eq(frame.text:GetFontObject(), "WhiteNormalNumberFont")
        T.same(font(frame.text), { "Fonts\\ARIALN.TTF", 10, "OUTLINE" })
        T.eq(frame:GetWidth(), 75)
        T.eq(frame:GetHeight(), 16)
    end)

    it("size the clock once it loads", function()
        Stubs.LoadAddon()
        local clock, ticker = TimeManagerClockButton, TimeManagerClockTicker
        _G.TimeManagerClockButton, _G.TimeManagerClockTicker = nil, nil
        Stubs.Login({ minimapClockSize = 20 })
        _G.TimeManagerClockButton, _G.TimeManagerClockTicker = clock, ticker
        Stubs.Fire("ADDON_LOADED", "Blizzard_TimeManager")
        Stubs.RunTimers()
        T.eq(ticker.fontHeight, 20)
        T.eq(clock:GetWidth(), 80)
    end)
end)
