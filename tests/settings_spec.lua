local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    local api = Stubs.InstallSettings()
    Stubs.Login(savedOptions)
    return ns, api
end

local function setting(api, key)
    return api.settings["ForeverQoL_" .. key]
end

describe("settings page", function()
    it("registers one AddOns category with Viewport, Action Bars and Minimap below it", function()
        local _, api = start()
        local main = api.registered
        T.eq(main.name, "Forever QoL")
        T.eq(#api.categories, 4)
        T.eq(api.categories[2].name, "Viewport")
        T.eq(api.categories[2].parent, main)
        T.eq(api.categories[3].name, "Action Bars")
        T.eq(api.categories[3].parent, main)
        T.eq(api.categories[4].name, "Minimap")
        T.eq(api.categories[4].parent, main)
        T.same(main.headers, { "Merchant", "Quests", "Tooltips", "Interface", "Chat", "World map",
            "Unit frames", "Chat commands" })
        T.same(api.categories[4].headers, { "Shape", "Zone text", "Buttons" })
    end)

    it("has a control for every option", function()
        local ns, api = start()
        for key in pairs(ns.Options.DEFAULTS) do
            local s = setting(api, key)
            T.truthy(s, "setting for " .. key)
            T.truthy(s.initializer, "control for " .. key)
            T.eq(s.default, ns.Options:GetDefault(key), key)
        end
    end)

    it("reads and writes ns.Options", function()
        local ns, api = start({ hideBagsBar = true })
        local s = setting(api, "hideBagsBar")
        T.eq(s.get(), true)
        s.set(false)
        T.eq(ns.Options:Get("hideBagsBar"), false)
    end)

    it("greys out dependent options while their parent is off", function()
        local ns, api = start()
        local guild = setting(api, "guildRepair").initializer
        T.eq(guild.parent, setting(api, "autoRepair").initializer)
        T.falsy(guild.predicate())
        ns.Options:Set("autoRepair", true)
        T.truthy(guild.predicate())

        local slider = setting(api, "viewportTop").initializer
        T.eq(slider.control, "slider")
        T.falsy(slider.predicate())
        T.eq(slider.options.maxValue, 600)
        T.eq(slider.options.formatter(12.4), "12 px")
    end)

    it("offers the zone text positions in a dropdown", function()
        local ns, api = start()
        local s = setting(api, "minimapZoneText")
        T.eq(s.initializer.control, "dropdown")
        T.eq(s.varType, "string")
        T.same(s.initializer.options(), {
            { value = "default", label = "Default" },
            { value = "above", label = "Above the minimap" },
            { value = "below", label = "Below the minimap" },
        })
        s.set("below")
        T.eq(ns.Options:Get("minimapZoneText"), "below")
    end)

    it("leaves out the world map options on a client without Forever's maps", function()
        Stubs.LoadAddon()
        local api = Stubs.InstallSettings()
        Stubs.state().maps = {}
        Stubs.Login()
        T.same(api.registered.headers, { "Merchant", "Quests", "Tooltips", "Interface", "Chat",
            "Unit frames", "Chat commands" })
        T.eq(setting(api, "mapDungeons"), nil)
        T.eq(setting(api, "mapTravel"), nil)
    end)

    it("offers every position for the minimap's buttons", function()
        local _, api = start()
        local clock = setting(api, "minimapClock")
        T.eq(clock.category.name, "Minimap")
        local values = {}
        for _, choice in ipairs(clock.initializer.options()) do values[#values + 1] = choice.value end
        T.same(values, { "default", "topLeft", "top", "topRight", "bottomLeft", "bottom", "bottomRight", "hidden" })
        T.eq(clock.initializer.options()[2].label, "Above, left")
        T.truthy(setting(api, "minimapDayNight"))
    end)

    it("greys out the border choice while the minimap is round", function()
        local ns, api = start()
        local borderChoice = setting(api, "squareMinimapBorder").initializer
        T.eq(borderChoice.parent, setting(api, "squareMinimap").initializer)
        T.falsy(borderChoice.predicate())
        ns.Options:Set("squareMinimap", true)
        T.truthy(borderChoice.predicate())
    end)

    it("offers the day and night icon only where the game has one", function()
        Stubs.LoadAddon()
        local api = Stubs.InstallSettings()
        MinimapCluster.DielFrame = false -- this client has none
        Stubs.Login()
        T.eq(setting(api, "minimapDayNight"), nil)
    end)

    it("lists every bar twice on the action bar page", function()
        local ns, api = start()
        local page = api.categories[3]
        T.same(page.headers, { "Reverse vertical growth", "Reverse horizontal growth" })
        for _, bar in ipairs(ns.ActionBars.BARS) do
            T.eq(setting(api, ns.ActionBars.VerticalKey(bar.frame)).category, page)
            T.eq(setting(api, ns.ActionBars.HorizontalKey(bar.frame)).category, page)
        end
    end)

    it("opens from the slash command", function()
        local _, api = start()
        SlashCmdList.FOREVERQOL("")
        T.eq(api.opened, api.registered:GetID())
    end)

    it("is skipped without the Settings API", function()
        Stubs.LoadAddon()
        Stubs.Login()
        SlashCmdList.FOREVERQOL("")
    end)
end)
