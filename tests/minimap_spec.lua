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

local MAGE = { 0.25, 0.78, 0.92 }
local GAME_YELLOW = { 1, 0.82, 0 }

describe("square minimap", function()
    it("leaves the minimap round by default", function()
        start()
        T.eq(Minimap.mask, "ui-hud-minimap-frame-generic-mask")
        T.truthy(MinimapCompassTexture:IsVisible())
        T.eq(GetMinimapShape, nil)
    end)

    it("masks the map square, hides the round frame and tells other addons", function()
        start({ squareMinimap = true })
        T.eq(Minimap.mask, "Interface\\BUTTONS\\WHITE8X8")
        T.falsy(MinimapCompassTexture:IsVisible())
        T.falsy(MinimapCompassTextureUnderlay:IsVisible())
        T.eq(GetMinimapShape(), "SQUARE")
    end)

    it("draws a border around the square map", function()
        start({ squareMinimap = true })
        local border
        for _, region in ipairs(Stubs.state().regions) do
            if region.kind == "Frame" and region.parent == Minimap and region:IsShown() then border = region end
        end
        T.truthy(border, "a border frame on the minimap")
    end)

    it("turns round again with the game's own mask", function()
        local ns = start({ squareMinimap = true })
        set(ns, "squareMinimap", false)
        T.eq(Minimap.mask, "ui-hud-minimap-frame-generic-mask")
        T.truthy(MinimapCompassTexture:IsVisible())
        T.eq(GetMinimapShape, nil)
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
        local point = MinimapCluster.ZoneTextButton:PointFor("BOTTOM")
        T.eq(point[2], Minimap)
        T.eq(point[3], "TOP")
        T.falsy(MinimapCluster.BorderTop:IsVisible())
        T.eq(MinimapZoneText.justifyH, "CENTER")
        T.eq(MinimapZoneText:GetWidth(), 198)
    end)

    it("clears the round frame when the minimap is round", function()
        start({ minimapZoneText = "above" })
        T.eq(MinimapCluster.ZoneTextButton:PointFor("BOTTOM")[2], MinimapCompassTexture)
    end)

    it("sits below the minimap, with the coordinates under it", function()
        start({ minimapZoneText = "below", squareMinimap = true })
        local point = MinimapCluster.ZoneTextButton:PointFor("TOP")
        T.eq(point[2], Minimap)
        T.eq(point[3], "BOTTOM")
        local coordsPoint = coords():PointFor("TOP")
        T.eq(coordsPoint[2], MinimapCluster.ZoneTextButton)
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
        T.truthy(MinimapCluster.ZoneTextButton:PointFor("BOTTOM"))
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
