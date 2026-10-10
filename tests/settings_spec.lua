local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    local api = Stubs.InstallSettings()
    Stubs.Login(savedOptions)
    return ns, api
end

local function pages(ns)
    return ns.SettingsPanel.pages
end

-- The control for an option on one of our own pages, and that page.
local function control(ns, key)
    for _, page in pairs(pages(ns)) do
        for _, c in ipairs(page.controls) do
            if c.key == key then return c, page end
        end
    end
    return nil
end

local function headers(page, column)
    local texts = {}
    for _, header in ipairs(page.headers) do
        if header.column == column then texts[#texts + 1] = header.text end
    end
    return texts
end

local function setting(api, key)
    return api.settings["QoL_" .. key]
end

local function values(c)
    local list = {}
    for _, choice in ipairs(c.choices) do list[#list + 1] = choice.value end
    return list
end

-- The page as the settings panel shows it.
local function show(page)
    page.frame:Show()
    page.frame:OnRefresh()
end

local function radio(c, text)
    c.widget:GenerateMenu()
    for _, entry in ipairs(c.widget.menu) do
        if entry.text == text then return entry end
    end
    error("no menu entry " .. text)
end

describe("settings pages", function()
    it("registers one AddOns category with Viewport, Action Bars and Minimap below it", function()
        local _, api = start()
        local main = api.registered
        T.eq(main.name, "Quality of Life")
        T.truthy(main.frame, "the main page is our own")
        T.eq(#api.categories, 4)
        T.eq(api.categories[2].name, "Viewport")
        T.eq(api.categories[2].parent, main)
        T.eq(api.categories[2].frame, nil) -- the game's own list
        T.eq(api.categories[3].name, "Action Bars")
        T.eq(api.categories[3].parent, main)
        T.truthy(api.categories[3].frame)
        T.eq(api.categories[4].name, "Minimap")
        T.eq(api.categories[4].parent, main)
        T.truthy(api.categories[4].frame)
    end)

    it("puts the main page's sections in two columns", function()
        local ns = start()
        local main = pages(ns).main
        T.same(headers(main, "left"), { "Merchant", "Quests", "Tooltips", "Interface", "Chat commands" })
        T.same(headers(main, "right"), { "Chat", "World map", "Health bars in class color" })
        local minimap = pages(ns).minimap
        T.same(headers(minimap, "left"), { "Shape", "Zone text", "Coordinates" })
        T.same(headers(minimap, "right"), { "Clock", "Buttons" })
    end)

    it("fits every page without scrolling", function()
        local ns = start()
        for name, page in pairs(pages(ns)) do
            T.truthy(page:Height() <= ns.SettingsPage.MAX_HEIGHT, name .. " is " .. page:Height() .. " high")
        end
    end)

    it("has one control for every option", function()
        local ns, api = start()
        local found = {}
        for _, page in pairs(pages(ns)) do
            for _, c in ipairs(page.controls) do
                T.eq(found[c.key], nil, "one control for " .. c.key)
                found[c.key] = true
            end
        end
        for variable, s in pairs(api.settings) do
            local key = variable:gsub("^QoL_", "")
            T.eq(found[key], nil, "one control for " .. key)
            T.truthy(s.initializer, "control for " .. key)
            T.eq(s.default, ns.Options:GetDefault(key), key)
            found[key] = true
        end
        for key in pairs(ns.Options.DEFAULTS) do
            T.truthy(found[key], "control for " .. key)
        end
    end)

    it("checks a box for an option that is on, and turns it off with a click", function()
        local ns = start({ hideBagsBar = true })
        local c, page = control(ns, "hideBagsBar")
        show(page)
        T.eq(c.kind, "checkbox")
        T.truthy(c.widget:GetChecked())
        c.widget:Click()
        T.eq(ns.Options:Get("hideBagsBar"), false)
        -- A click on the name toggles it too.
        c.row:RunScript("OnMouseUp")
        T.eq(ns.Options:Get("hideBagsBar"), true)
    end)

    it("shows changes made elsewhere while open", function()
        local ns = start()
        local c, page = control(ns, "questAccept")
        show(page)
        T.falsy(c.widget:GetChecked())
        ns.Options:Set("questAccept", true)
        T.truthy(c.widget:GetChecked())
    end)

    it("shows the option's name and description when pointed at", function()
        local ns = start()
        local c = control(ns, "sellJunk")
        c.row:RunScript("OnEnter")
        T.eq(GameTooltip.lines[1].text, "Sell junk automatically")
        T.eq(GameTooltip.lines[2].text, "Sells all grey (poor quality) items when you open a merchant.")
        T.truthy(GameTooltip.shown)
        c.widget:RunScript("OnLeave")
        T.falsy(GameTooltip.shown)
    end)

    it("indents and greys out an option while the one it belongs to is off", function()
        local ns = start()
        local guild, page = control(ns, "guildRepair")
        show(page)
        T.truthy(guild.indent)
        T.falsy(guild.widget:IsEnabled())
        T.eq(guild.text.textColor[1], 0.5)
        ns.Options:Set("autoRepair", true)
        T.truthy(guild.widget:IsEnabled())
        T.eq(guild.text.textColor[1], 1)
    end)

    it("writes every name in the same font, also the indented ones", function()
        local ns = start()
        for _, page in pairs(pages(ns)) do
            for _, c in ipairs(page.controls) do
                T.eq(c.text.font, "GameFontNormal", c.key)
            end
        end
    end)

    it("offers the zone text positions in a dropdown", function()
        local ns = start()
        local c, page = control(ns, "minimapZoneText")
        show(page)
        T.eq(c.kind, "dropdown")
        T.same(values(c), { "default", "above", "below" })
        T.eq(c.widget.text, "Default")
        radio(c, "Below the minimap").select()
        T.eq(ns.Options:Get("minimapZoneText"), "below")
        T.eq(c.widget.text, "Below the minimap")
    end)

    it("offers the inside of the map only to the tracking button and the day and night icon", function()
        local ns = start()
        local outside = { "default", "topLeft", "top", "topRight", "bottomLeft", "bottom", "bottomRight", "hidden" }
        local inside = { "default", "topLeft", "top", "topRight", "bottomLeft", "bottom", "bottomRight",
            "insideTopLeft", "insideTop", "insideTopRight", "insideBottomLeft", "insideBottom", "insideBottomRight",
            "hidden" }
        T.same(values(control(ns, "minimapClock")), outside)
        T.same(values(control(ns, "minimapCompartment")), outside)
        T.same(values(control(ns, "minimapTracking")), inside)
        T.same(values(control(ns, "minimapDayNight")), inside)
        T.eq(control(ns, "minimapTracking").choices[9].label, "Inside, top center")
        T.eq(control(ns, "minimapClock").choices[2].label, "Above, left")
    end)

    it("greys out the border choice while the minimap is round", function()
        local ns = start()
        local border, page = control(ns, "squareMinimapBorder")
        show(page)
        T.truthy(border.indent)
        T.falsy(border.widget:IsEnabled())
        ns.Options:Set("squareMinimap", true)
        T.truthy(border.widget:IsEnabled())
    end)

    it("offers font sizes for the zone text and the clock, the game's own first", function()
        local ns = start()
        for _, key in ipairs({ "minimapZoneTextSize", "minimapClockSize" }) do
            local c = control(ns, key)
            T.eq(c.kind, "dropdown")
            T.eq(c.choices[1].value, 0)
            T.eq(c.choices[1].label, "Default")
            T.eq(c.choices[2].label, "9")
            T.same(values(c), ns.MinimapLayout.FONT_SIZES)
        end
        local c = control(ns, "minimapClockSize")
        T.eq(c.column, "right")
        radio(c, "16").select()
        T.eq(ns.Options:Get("minimapClockSize"), 16)
    end)

    it("greys out the class colors and size of a hidden clock, and the color of hidden coordinates", function()
        local ns = start()
        local clock, page = control(ns, "minimapClockClassColor")
        local clockSize = control(ns, "minimapClockSize")
        local coords = control(ns, "minimapCoordsClassColor")
        show(page)
        T.truthy(clock.widget:IsEnabled())
        T.truthy(clockSize.widget:IsEnabled())
        T.truthy(coords.widget:IsEnabled())
        ns.Options:Set("minimapClock", "hidden")
        ns.Options:Set("hideMinimapCoords", true)
        T.falsy(clock.widget:IsEnabled())
        T.falsy(clockSize.widget:IsEnabled())
        T.falsy(coords.widget:IsEnabled())
    end)

    it("offers the day and night icon only where the game has one", function()
        local ns = Stubs.LoadAddon()
        Stubs.InstallSettings()
        MinimapCluster.DielFrame = false -- this client has none
        Stubs.Login()
        T.eq(control(ns, "minimapDayNight"), nil)
    end)

    it("leaves out the world map options on a client without Forever's maps", function()
        local ns = Stubs.LoadAddon()
        Stubs.InstallSettings()
        Stubs.state().maps = {}
        Stubs.Login()
        T.same(headers(pages(ns).main, "right"), { "Chat", "Health bars in class color" })
        T.eq(control(ns, "mapDungeons"), nil)
        T.eq(control(ns, "mapTravel"), nil)
    end)

    it("lists every bar in both columns of the action bar page, side by side, then paging and buttons", function()
        local ns = start()
        local page = pages(ns).actionBars
        T.same(headers(page, "left"), { "Reverse vertical growth", "Paging" })
        T.same(headers(page, "right"), { "Reverse horizontal growth", "Buttons" })
        for _, bar in ipairs(ns.ActionBars.BARS) do
            local vertical = control(ns, ns.ActionBars.VerticalKey(bar.frame))
            local horizontal = control(ns, ns.ActionBars.HorizontalKey(bar.frame))
            T.eq(vertical.column, "left")
            T.eq(horizontal.column, "right")
            T.eq(vertical.row:PointFor("TOPLEFT")[5], horizontal.row:PointFor("TOPLEFT")[5], bar.frame .. " side by side")
        end
        T.eq(control(ns, "disableBarPaging").column, "left")
        T.eq(control(ns, "hideButtonBorders").column, "right")
        T.eq(control(ns, "disableBarPaging").row:PointFor("TOPLEFT")[5],
            control(ns, "hideButtonBorders").row:PointFor("TOPLEFT")[5], "paging and buttons side by side")
    end)

    it("resets a page to its defaults after a second click", function()
        local ns = start({ squareMinimap = true, minimapClock = "bottom", sellJunk = false })
        local page = pages(ns).minimap
        show(page)
        local button = page.defaultsButton
        T.eq(button:GetText(), "Defaults")
        button:Click()
        T.eq(button:GetText(), "Sure?")
        T.eq(ns.Options:Get("squareMinimap"), true)
        button:Click()
        T.eq(button:GetText(), "Defaults")
        T.eq(ns.Options:Get("squareMinimap"), false)
        T.eq(ns.Options:Get("minimapClock"), "default")
        T.eq(control(ns, "minimapClock").widget.text, "Default")
        -- Only this page's options.
        T.eq(ns.Options:Get("sellJunk"), false)
    end)

    it("asks again once the confirmation has run out", function()
        local ns = start({ squareMinimap = true })
        local button = pages(ns).minimap.defaultsButton
        button:Click()
        Stubs.AdvanceTime()
        T.eq(button:GetText(), "Defaults")
        button:Click()
        T.eq(ns.Options:Get("squareMinimap"), true)
    end)

    it("resets with the game's reset of all settings", function()
        local ns = start({ hideMicroMenu = true })
        pages(ns).main.frame:OnDefault()
        T.eq(ns.Options:Get("hideMicroMenu"), false)
    end)

    it("keeps the viewport page as the game's list, its margins greyed out while off", function()
        local _, api = start()
        local slider = setting(api, "viewportTop")
        T.eq(slider.category.name, "Viewport")
        T.eq(slider.initializer.control, "slider")
        T.eq(slider.initializer.parent, setting(api, "viewportEnabled").initializer)
        T.falsy(slider.initializer.predicate())
        T.eq(slider.initializer.options.maxValue, 600)
        T.eq(slider.initializer.options.formatter(12.4), "12 px")
        slider.set(30)
        T.truthy(slider.get() == 30)
    end)

    it("opens from the slash command", function()
        local _, api = start()
        SlashCmdList.QOL("")
        T.eq(api.opened, api.registered:GetID())
    end)

    it("is skipped without the Settings API", function()
        Stubs.LoadAddon()
        Stubs.Login()
        SlashCmdList.QOL("")
    end)
end)
