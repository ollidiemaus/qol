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
        T.eq(frame.bronze.texture, "Interface\\AddOns\\ForeverQoL\\Media\\MinimapSquareBorder")
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
