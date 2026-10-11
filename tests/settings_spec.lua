local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- forever: with Forever's controller action bar, which brings the Controller page.
local function start(savedOptions, forever)
    local ns = Stubs.LoadAddon()
    if forever then Stubs.NewGamepadBar() end
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

-- The key binding row of back button index on the Controller page.
local function keyRow(ns, index)
    for _, c in ipairs(pages(ns).controller.controls) do
        if c.command == "CLICK QoLBackButton" .. index .. ":LeftButton" then return c end
    end
    error("no key binding row for back button " .. index)
end

-- The frame that takes the keyboard while a key binding button waits for a key.
local function waitingForKey()
    for _, region in ipairs(Stubs.state().regions) do
        if region.scripts.OnKeyDown and region:IsShown() then return true end
    end
    return false
end

local function headers(page, column)
    local texts = {}
    for _, header in ipairs(page.headers) do
        if header.column == column then texts[#texts + 1] = header.text end
    end
    return texts
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
    it("registers one AddOns category with Viewport, Action Bars and Minimap below it, all our own pages", function()
        local _, api = start()
        local main = api.registered
        T.eq(main.name, "Quality of Life")
        T.truthy(main.frame, "the main page is our own")
        T.eq(#api.categories, 4)
        T.eq(api.categories[2].name, "Viewport")
        T.eq(api.categories[2].parent, main)
        T.truthy(api.categories[2].frame)
        T.eq(api.categories[3].name, "Action Bars")
        T.eq(api.categories[3].parent, main)
        T.truthy(api.categories[3].frame)
        T.eq(api.categories[4].name, "Minimap")
        T.eq(api.categories[4].parent, main)
        T.truthy(api.categories[4].frame)
    end)

    it("adds a Controller page on Forever, for the controller action bar", function()
        local ns, api = start(nil, true)
        T.eq(#api.categories, 5)
        T.eq(api.categories[5].name, "Controller")
        T.eq(api.categories[5].parent, api.registered)
        T.same(headers(pages(ns).controller, "left"), { "Back buttons" })
        T.same(headers(pages(ns).controller, "wide"), { "Keys" })
        local c = control(ns, "controllerBackButtonsBar")
        T.same(values(c), { 6, 7, 8 })
        T.falsy(c.enabled(), "the bar waits for the back buttons")
        ns.Options:Set("controllerBackButtons", true)
        T.truthy(c.enabled(), "enabled with the back buttons")
    end)

    it("names each back button's keys by its slot on the chosen bar", function()
        local ns = start(nil, true)
        local page = pages(ns).controller
        show(page)
        T.eq(keyRow(ns, 1).text.text, "L4: Action Bar 8, button 9")
        T.eq(keyRow(ns, 4).text.text, "R5: Action Bar 8, button 12")
        ns.Options:Set("controllerBackButtons", true)
        ns.Options:Set("controllerBackButtonsBar", 6)
        T.eq(keyRow(ns, 1).text.text, "L4: Action Bar 6, button 9")
        T.eq(keyRow(ns, 3).text.text, "R4: Action Bar 6, button 11")
        keyRow(ns, 1).row:RunScript("OnEnter")
        T.eq(GameTooltip.lines[1].text, "Back button L4 (upper left)")
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
        local ns = start(nil, true)
        for name, page in pairs(pages(ns)) do
            T.truthy(page:Height() <= ns.SettingsPage.MAX_HEIGHT, name .. " is " .. page:Height() .. " high")
        end
    end)

    it("has one control for every option", function()
        local ns, api = start(nil, true)
        local found = {}
        for _, page in pairs(pages(ns)) do
            for _, c in ipairs(page.controls) do
                -- Key binding rows have no option.
                if c.key then
                    T.eq(found[c.key], nil, "one control for " .. c.key)
                    found[c.key] = true
                end
            end
        end
        -- None in the game's own list: with the controller interface on, Forever stopped responding
        -- when the settings closed after showing one.
        T.eq(next(api.settings), nil, "no setting in the game's list")
        T.eq(#api.controls, 0, "no control in the game's list")
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
        c.widget:OpenMenu()
        T.eq(c.widget.menusOpened, 1, "a click opens the game's menu")
        T.eq(ns.Options:Get("minimapZoneText"), "below")
    end)

    it("steps a dropdown to its next choice in the controller interface, without the game's menu", function()
        local ns = start(nil, true)
        Stubs.SetControllerUI(true)
        local c, page = control(ns, "controllerBackButtonsBar")
        show(page)
        T.eq(c.widget.text, "Action Bar 8, buttons 9-12")
        c.widget:OpenMenu()
        T.eq(ns.Options:Get("controllerBackButtonsBar"), 8, "greyed out while the back buttons are off")
        ns.Options:Set("controllerBackButtons", true)
        c.widget:OpenMenu()
        T.eq(ns.Options:Get("controllerBackButtonsBar"), 6, "back to the first after the last")
        T.eq(c.widget.text, "Action Bar 6, buttons 9-12")
        c.widget:OpenMenu()
        T.eq(ns.Options:Get("controllerBackButtonsBar"), 7)
        T.eq(c.widget.menusOpened, nil, "no menu opened")
    end)

    it("binds a back button's key from the Controller page, as in Key Bindings", function()
        local ns = start({ controllerBackButtons = true }, true)
        local page = pages(ns).controller
        show(page)
        local row = keyRow(ns, 1)
        local first, second = row.buttons[1], row.buttons[2]
        T.eq(first.text, "|cff808080Not Bound|r")
        T.eq(page.note.text, "Click a box, then press the key. A right-click clears a key.")

        first:Click()
        T.truthy(waitingForKey())
        T.truthy(first.selected)
        T.eq(page.note.text, "Press the key for Back button L4 (upper left). Escape or another click on the box cancels.")
        -- A modifier alone waits for the key that goes with it.
        Stubs.TypeKey("LSHIFT")
        T.truthy(waitingForKey())
        Stubs.TypeKey("F13")
        T.falsy(waitingForKey())
        T.falsy(first.selected)
        T.eq(GetBindingAction("F13"), "CLICK QoLBackButton1:LeftButton")
        T.eq(first.text, "F13")
        T.eq(page.note.text, "F13 is now the key for Back button L4 (upper left).")

        -- The second box adds a key, a key taken from another binding says so.
        second:Click()
        Stubs.TypeKey("1")
        T.same({ GetBindingKey("CLICK QoLBackButton1:LeftButton") }, { "1", "F13" })
        T.eq(GetBindingKey("ACTIONBUTTON1"), nil)
        T.eq(page.note.text, "1 is now the key for Back button L4 (upper left), no longer for ACTIONBUTTON1.")

        -- A right-click clears a key.
        first:RunScript("OnClick", "RightButton")
        T.same({ GetBindingKey("CLICK QoLBackButton1:LeftButton") }, { "F13" })

        -- The back button presses with it once the settings have closed (closing them saves the bindings).
        Stubs.Fire("UPDATE_BINDINGS")
        Stubs.RunTimers()
        T.eq(Stubs.state().overrides.F13.command, "CLICK QoLBackButton1:LeftButton")
    end)

    it("stops waiting for a key on Escape, a second click, leaving the page and combat", function()
        local ns = start({ controllerBackButtons = true }, true)
        local page = pages(ns).controller
        show(page)
        local button = keyRow(ns, 2).buttons[1]
        local hint = "Click a box, then press the key. A right-click clears a key."

        button:Click()
        Stubs.TypeKey("ESCAPE")
        T.falsy(waitingForKey())
        T.eq(page.note.text, hint)
        button:Click()
        button:Click()
        T.falsy(waitingForKey())
        button:Click()
        page.frame:RunScript("OnHide")
        T.falsy(waitingForKey())
        T.eq(page.note.text, hint)
        T.eq(GetBindingKey("CLICK QoLBackButton2:LeftButton"), nil, "nothing bound")

        show(page)
        button:Click()
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.SetCombat(true)
        T.falsy(waitingForKey())
        T.eq(page.note.text, "Key bindings can't be changed in combat.")
        button:Click()
        T.falsy(waitingForKey(), "no waiting in combat")
        button:RunScript("OnClick", "RightButton")
        Stubs.SetCombat(false)
    end)

    it("greys out the back buttons' keys while the back buttons are off", function()
        local ns = start(nil, true)
        local page = pages(ns).controller
        show(page)
        local row = keyRow(ns, 1)
        T.falsy(row.buttons[1]:IsEnabled())
        T.falsy(row.buttons[2]:IsEnabled())
        ns.Options:Set("controllerBackButtons", true)
        T.truthy(row.buttons[1]:IsEnabled())
        -- Turning them off while a box waits for a key stops waiting.
        row.buttons[1]:Click()
        ns.Options:Set("controllerBackButtons", false)
        T.falsy(waitingForKey())
        T.falsy(row.buttons[1].selected)
        T.eq(page.note.text, "Click a box, then press the key. A right-click clears a key.")
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

    it("lists every bar in both columns of the action bar page, side by side, then paging, buttons and the ring", function()
        local ns = start()
        local page = pages(ns).actionBars
        T.same(headers(page, "left"), { "Reverse vertical growth", "Paging", "Ring" })
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
        T.eq(control(ns, "ring").column, "left")
        T.eq(control(ns, "ringBar").column, "left")
        T.truthy(control(ns, "ring").row:PointFor("TOPLEFT")[5] < control(ns, "hideButtonBorders").row:PointFor("TOPLEFT")[5],
            "the ring below paging and buttons")
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

    it("puts the viewport options in rows across the page, the margins greyed out while it's off", function()
        local ns = start()
        local page = pages(ns).viewport
        show(page)
        local keys, kinds = {}, {}
        for _, c in ipairs(page.controls) do
            keys[#keys + 1], kinds[#kinds + 1] = c.key, c.kind
            T.eq(c.column, "wide", c.key)
        end
        T.same(keys, { "viewportEnabled", "viewportTop", "viewportBottom", "viewportLeft", "viewportRight",
            "viewportColor" })
        T.same(kinds, { "checkbox", "slider", "slider", "slider", "slider", "color" })
        local top = control(ns, "viewportTop")
        T.truthy(top.indent)
        T.falsy(top.widget:IsEnabled())
        T.eq(top.text.textColor[1], 0.5)
        T.falsy(control(ns, "viewportColor").widget:IsEnabled())
        control(ns, "viewportEnabled").widget:Click()
        T.truthy(top.widget:IsEnabled())
        T.truthy(control(ns, "viewportColor").widget:IsEnabled())
    end)

    it("sets a margin with its slider and its arrows, in whole pixels", function()
        local ns = start({ viewportEnabled = true, viewportBottom = 278 })
        local c, page = control(ns, "viewportBottom")
        show(page)
        T.eq(c.widget:GetValue(), 278)
        T.eq(c.widget.RightText:GetText(), "278 px")
        T.eq(c.widget.maxValue, 600)
        c.widget:SetValue(30.4)
        T.eq(ns.Options:Get("viewportBottom"), 30)
        c.widget.Forward:Click()
        T.eq(ns.Options:Get("viewportBottom"), 31)
        c.widget.Back:Click()
        c.widget.Back:Click()
        T.eq(ns.Options:Get("viewportBottom"), 29)
        T.eq(c.widget.RightText:GetText(), "29 px")
        -- A change made elsewhere moves the slider, which doesn't write it back.
        ns.Options:Set("viewportBottom", 120)
        T.eq(c.widget:GetValue(), 120)
        T.eq(ns.Options:Get("viewportBottom"), 120)
    end)

    it("picks the margin color in the game's color picker, and puts it back on cancel", function()
        local ns = start({ viewportEnabled = true })
        local c, page = control(ns, "viewportColor")
        show(page)
        T.same(c.widget.color, { 0, 0, 0 })
        c.widget:Click()
        T.truthy(ColorPickerFrame:IsShown())
        T.same({ ColorPickerFrame.info.r, ColorPickerFrame.info.g, ColorPickerFrame.info.b }, { 0, 0, 0 })
        Stubs.PickColor(1, 128 / 255, 0)
        T.eq(ns.Options:Get("viewportColor"), "ffff8000")
        T.same(c.widget.color, { 1, 128 / 255, 0 })
        Stubs.CancelColor()
        T.eq(ns.Options:Get("viewportColor"), "ff000000")
        -- A click on the name opens it too, unless the option is greyed out.
        ColorPickerFrame:Hide()
        c.row:RunScript("OnMouseUp")
        T.truthy(ColorPickerFrame:IsShown())
        ColorPickerFrame:Hide()
        ns.Options:Set("viewportEnabled", false)
        c.row:RunScript("OnMouseUp")
        T.falsy(ColorPickerFrame:IsShown())
    end)

    it("reads and writes colors as AARRGGBB", function()
        local ns = start()
        local Page = ns.SettingsPage
        T.eq(Page.FormatColor(1, 0, 0.5), "ffff0080")
        T.eq(Page.FormatColor(2, -1, 0), "ffff0000")
        local r, g, b = Page.ParseColor("ff336699")
        T.same({ r, g, b }, { 0x33 / 255, 0x66 / 255, 0x99 / 255 })
        T.same({ Page.ParseColor("nope") }, { 0, 0, 0 })
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
