local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- QoL on Classic Era (1.15.9): the stubbed client without what Classic Era lacks.
local function start()
    local ns = Stubs.LoadAddon({ client = "classicEra" })
    local api = Stubs.InstallSettings()
    Stubs.Login()
    return ns, api
end

describe("the stubbed Classic Era client", function()
    it("errors on a frame template Classic Era lacks, as the client does", function()
        Stubs.Reset({ client = "classicEra" })
        for _, template in ipairs({ "PortraitFrameFlatTemplate", "LargeSideTabButtonTemplate",
            "TabSystemTopButtonTemplate", "UIPanelButtonTemplate, LargeSideTabButtonTemplate" }) do
            T.falsy(pcall(CreateFrame, "Frame", nil, UIParent, template), template)
        end
        T.truthy(pcall(CreateFrame, "Frame", nil, UIParent, "PortraitFrameTemplate"))
        T.truthy(pcall(CreateFrame, "Button", nil, UIParent, "UIPanelButtonTemplate"))
    end)

    it("lacks tooltip data, the spell book's skill lines, toys, the addon compartment, combined bags, the controller, "
        .. "the player frame's art, the minimap's coordinates, guild banks, the calendar", function()
        Stubs.Reset({ client = "classicEra" })
        T.eq(select(4, GetBuildInfo()), 11509)
        T.eq(TooltipDataProcessor, nil)
        T.eq(C_SpellBook.GetNumSpellBookSkillLines, nil)
        T.truthy(C_SpellBook.IsSpellKnownOrInSpellBook, "Classic Era has this one")
        T.eq(C_ToyBox, nil)
        T.eq(PlayerHasToy, nil)
        T.eq(AddonCompartmentFrame, nil)
        T.eq(ContainerFrameCombinedBags, nil)
        T.eq(C_InputInterfaceStyle, nil)
        T.eq(GamepadMode, nil)
        T.eq(BuffFrameTooltip, nil)
        T.falsy(PlayerFrame.PlayerFrameContainer)
        T.falsy(MinimapCluster.MinimapContainer.PlayerCoords)
        T.eq(GuildBankFrame_LoadUI, nil)
        T.eq(CanGuildBankRepair, nil)
        T.eq(ToggleCalendar, nil)
    end)

    it("has Forever's zone maps but Zephras Isle, Stormwind and the Eastern Plaguelands on their own rects", function()
        Stubs.Reset({ client = "classicEra" })
        local state = Stubs.state()
        state.maps[2521] = { name = "Zephras Isle", mapType = 3, parentMapID = 947 }
        state.mapRects["1453>1415"] = { 0.36, 0.46, 0.64, 0.74 }
        state.mapRects["1413>1414"] = { 0.5, 0.7, 0.3, 0.6 }
        T.eq(C_Map.GetMapInfo(2521), nil)
        T.truthy(C_Map.GetMapInfo(1413))
        T.same({ C_Map.GetMapRectOnMap(1453, 1415) }, { 0.38, 0.46, 0.66, 0.74 })
        T.truthy(C_Map.GetMapRectOnMap(1423, 1415))
        T.same({ C_Map.GetMapRectOnMap(1413, 1414) }, { 0.5, 0.7, 0.3, 0.6 })
        T.eq(C_Texture.GetAtlasInfo("flightmasterferry"), nil)
        T.truthy(C_Texture.GetAtlasInfo("Ships_CargoShip-Map"))
    end)

    it("has its own minimap: the round border, the tracking button and the time of day icon", function()
        Stubs.Reset({ client = "classicEra" })
        T.truthy(MinimapBorder:IsVisible())
        T.falsy(MiniMapTracking:IsShown(), "shown only while something is tracked")
        T.falsy(MinimapCluster.Tracking)
        T.falsy(MinimapCluster.DielFrame)
        T.eq(GameTimeFrame:GetParent(), MinimapBackdrop)
    end)

    it("turns its health bars green again on every value change, where Forever keeps their color", function()
        Stubs.Reset({ client = "classicEra" })
        local bar = Stubs.HealthBar("TargetFrame")
        T.falsy(bar.lockColor)
        bar.color = { 0.5, 0.5, 0.5, 1 }
        Stubs.SetHealth("TargetFrame", 0.4)
        T.same(bar.color, { 0, 1, 0, 1 })

        Stubs.Reset()
        bar = Stubs.HealthBar("TargetFrame")
        bar.color = { 0.5, 0.5, 0.5, 1 }
        Stubs.SetHealth("TargetFrame", 0.4)
        T.same(bar.color, { 0.5, 0.5, 0.5, 1 })
    end)

    it("keeps every template on Forever", function()
        Stubs.Reset()
        T.truthy(pcall(CreateFrame, "Frame", nil, UIParent, "PortraitFrameFlatTemplate"))
    end)
end)

describe("QoL on Classic Era", function()
    it("loads every file the TOC lists and logs in without errors", function()
        local ok, err = pcall(start)
        T.truthy(ok, tostring(err))
        T.same(Stubs.state().errors, {})
    end)

    it("opens the settings window from /qol, in Classic Era's own window art", function()
        start()
        SlashCmdList.QOL("")
        T.truthy(QoLSettings:IsShown())
        T.eq(QoLSettings.template, "PortraitFrameTemplate")
        T.eq(QoLSettings.titleText, "Quality of Life")
        T.same(Stubs.state().errors, {})
    end)

    it("opens the Ring and Click casting pages without errors", function()
        local ns = start()
        SlashCmdList.QOL("ring")
        T.eq(ns.SettingsPanel.window.selected, "ring")
        T.truthy(QoLRingEditor:IsVisible())
        SlashCmdList.QOL("click")
        T.eq(ns.SettingsPanel.window.selected, "clickCast")
        T.truthy(QoLClickCastEditor:IsVisible())
        T.same(Stubs.state().errors, {})
    end)

    it("lists only the pages that change something on Classic Era", function()
        local ns = start()
        T.same(ns.SettingsPanel.window.order, { "automation", "interface", "chat", "mail", "actionBars",
            "minimap", "worldMap", "viewport", "ring", "clickCast", "advanced" })
    end)

    it("leaves out the options Classic Era has nothing for", function()
        local ns = start()
        local keys = {}
        for _, page in pairs(ns.SettingsPanel.pages) do
            for _, c in ipairs(page.controls) do keys[c.key or c.command or "?"] = true end
        end
        -- Combined bags, the second mana bar of Forever's and retail's player frame, the addon
        -- compartment, the player coordinates, guild banks, the controller's buff tooltips and back
        -- buttons.
        for _, key in ipairs({ "combinedBagTopLeft", "druidManaBar", "minimapCompartment",
            "hideMinimapCoords", "minimapCoordsClassColor", "guildRepair", "hideBuffTooltips",
            "controllerBackButtons", "hideMinimapCalendar" }) do
            T.falsy(keys[key], key)
        end
        T.truthy(keys.sellJunk)
        T.truthy(keys.autoRepair)
        T.truthy(keys.minimapDayNight, "its time of day icon")
        T.truthy(keys.minimapTracking)
        local headers = {}
        for _, header in ipairs(ns.SettingsPanel.pages.interface.headers) do headers[header.text] = true end
        for _, header in ipairs(ns.SettingsPanel.pages.minimap.headers) do headers[header.text] = true end
        T.falsy(headers[ns.L.SECTION_COMBINED_BAGS], "the Combined bags section")
        T.falsy(headers[ns.L.SECTION_MINIMAP_COORDS], "the Coordinates section")
        T.truthy(headers[ns.L.SECTION_PLAYER_FRAME], "the Player frame section keeps its other row")
        T.same(Stubs.state().errors, {})
    end)

    it("opens the settings window from the information page's button", function()
        local ns = start()
        local info = ns.SettingsPanel.info
        info.frame:Show()
        info.openButton:Click()
        Stubs.RunTimers()
        T.truthy(QoLSettings:IsShown())
        T.same(Stubs.state().errors, {})
    end)
end)
