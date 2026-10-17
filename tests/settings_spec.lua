local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- The addon loaded last, for show.
local loaded

-- forever: with Forever's controller action bar, which brings the Controller page.
local function start(savedOptions, forever)
    local ns = Stubs.LoadAddon()
    if forever then Stubs.NewGamepadBar() end
    local api = Stubs.InstallSettings()
    Stubs.Login(savedOptions)
    loaded = ns
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

-- The frame that takes the keyboard while a key binding button waits for a key: above the window,
-- which takes it too, for Escape.
local function waitingForKey()
    for _, region in ipairs(Stubs.state().regions) do
        if region.scripts.OnKeyDown and region:IsShown() and region.strata == "FULLSCREEN_DIALOG" then return true end
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

-- The page as the settings window shows it.
local function show(page)
    local panel = loaded.SettingsPanel
    for key, other in pairs(panel.pages) do
        if other == page then
            panel:Open()
            panel.window:Select(key)
            return
        end
    end
    error("not a page of the window")
end

-- The pages' names in the window's list, in its order.
local function listed(ns)
    local window = ns.SettingsPanel.window
    local names = {}
    for _, key in ipairs(window.order) do names[#names + 1] = window.buttons[key].label:GetText() end
    return names
end

local function radio(c, text)
    c.widget:GenerateMenu()
    for _, entry in ipairs(c.widget.menu) do
        if entry.text == text then return entry end
    end
    error("no menu entry " .. text)
end

describe("settings pages", function()
    it("puts a page for each part of the game in a window of their own, and only the information page under AddOns", function()
        local ns, api = start()
        T.eq(api.registered.name, "Quality of Life")
        T.eq(api.registered.frame, ns.SettingsPanel.info.frame, "the information page is our own")
        T.eq(#api.categories, 1, "no pages in the game's list")
        local window = ns.SettingsPanel.window
        T.eq(QoLSettings, window.frame)
        T.eq(QoLSettings.template, "PortraitFrameFlatTemplate")
        T.eq(QoLSettings.titleText, "Quality of Life")
        T.same(listed(ns), { "Automation", "Interface", "Chat", "Mail", "Action Bars", "Minimap", "World map",
            "Viewport", "Ring" })
        for key, page in pairs(pages(ns)) do
            T.eq(page.frame:GetParent(), window.container, key)
        end
    end)

    it("draws the window with the game's settings art, which Forever draws in bronze", function()
        start()
        local atlases = {}
        for _, region in ipairs(Stubs.state().regions) do
            if region.atlas and (region.parent == QoLSettings or region.parent == loaded.SettingsPanel.window.list) then
                atlases[region.atlas] = true
            end
        end
        T.truthy(atlases.Options_InnerFrame, "the inner frame")
        T.truthy(atlases.Options_CategoryHeader_1, "the list's header")
    end)

    it("shows one page at a time, the first when it opens, its button lit in the list", function()
        local ns = start()
        local window = ns.SettingsPanel.window
        local automation, minimap = window.buttons.automation, window.buttons.minimap
        SlashCmdList.QOL("")
        T.truthy(QoLSettings:IsShown())
        T.truthy(pages(ns).automation.frame:IsShown())
        T.falsy(pages(ns).minimap.frame:IsShown())
        T.eq(automation.highlight:GetAtlas(), "Options_List_Active")
        T.truthy(automation.highlight:IsShown())
        T.eq(automation.label:GetFontObject(), "GameFontHighlight")
        T.eq(minimap.label:GetFontObject(), "GameFontNormal")
        T.falsy(minimap.highlight:IsShown())

        minimap:RunScript("OnEnter")
        T.eq(minimap.highlight:GetAtlas(), "Options_List_Hover")
        T.truthy(minimap.highlight:IsShown())
        minimap:Click()
        T.truthy(pages(ns).minimap.frame:IsShown())
        T.falsy(pages(ns).automation.frame:IsShown())
        T.falsy(automation.highlight:IsShown())
        T.eq(minimap.highlight:GetAtlas(), "Options_List_Active")
        minimap:RunScript("OnLeave")
        T.truthy(minimap.highlight:IsShown(), "still lit")

        SlashCmdList.QOL("")
        T.falsy(QoLSettings:IsShown(), "/qol again closes it")
        ns.Options:Set("squareMinimap", true)
        SlashCmdList.QOL("")
        T.truthy(pages(ns).minimap.frame:IsShown(), "back on the page it was on")
        T.truthy(control(ns, "squareMinimap").widget:GetChecked(), "up to date")
    end)

    it("closes on Escape and passes the other keys on to the game, in combat every key", function()
        start()
        SlashCmdList.QOL("")
        T.truthy(Stubs.TypeKey("P"), "P reached the key bindings")
        T.truthy(QoLSettings:IsShown(), "still open")
        T.falsy(Stubs.TypeKey("ESCAPE"), "kept from the game menu")
        T.falsy(QoLSettings:IsShown(), "closed")
        Stubs.RunTimers()
        Stubs.SetCombat(true)
        SlashCmdList.QOL("")
        T.truthy(QoLSettings:IsShown(), "opens in combat")
        T.truthy(Stubs.TypeKey("W"), "keys go on to the game again")
        T.truthy(Stubs.TypeKey("ESCAPE"), "Escape too, in combat")
        T.truthy(QoLSettings:IsShown(), "still open")
        QoLSettings.CloseButton:Click()
        T.falsy(QoLSettings:IsShown(), "closed by its button")
        Stubs.SetCombat(false)
    end)

    it("leaves Escape to the game's settings while they're open, which it opens over", function()
        start()
        local settings = CreateFrame("Frame", "SettingsPanel", UIParent)
        settings:SetFrameStrata("HIGH")
        SlashCmdList.QOL("")
        T.truthy(Stubs.TypeKey("ESCAPE"), "Escape went to the game, for its settings")
        T.truthy(QoLSettings:IsShown(), "still open")
        settings:Hide()
        T.falsy(Stubs.TypeKey("ESCAPE"))
        T.falsy(QoLSettings:IsShown(), "closed")
    end)

    it("adds a Controller page on Forever, for the controller action bar", function()
        local ns = start(nil, true)
        local names = listed(ns)
        T.eq(#names, 10)
        T.eq(names[10], "Controller")
        T.same(headers(pages(ns).controller, "left"), { "Back buttons" })
        T.same(headers(pages(ns).controller, "right"), { "Buffs" })
        T.same(headers(pages(ns).controller, "wide"), { "Keys" })
        T.truthy(control(ns, "hideBuffTooltips"))
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

    it("puts each page's sections in two columns", function()
        local ns = start()
        T.same(headers(pages(ns).automation, "left"), { "Merchant" })
        T.same(headers(pages(ns).automation, "right"), { "Quests" })
        T.same(headers(pages(ns).interface, "left"), { "Hide", "Combined bags", "Player frame", "Edit Mode" })
        T.same(headers(pages(ns).interface, "right"), { "Tooltips", "Health bars in class color" })
        T.same(headers(pages(ns).chat, "left"), { "Chat window" })
        T.same(headers(pages(ns).chat, "right"), { "Chat commands" })
        T.same(headers(pages(ns).mail, "left"), { "Bookmarks" })
        local minimap = pages(ns).minimap
        T.same(headers(minimap, "left"), { "Shape", "Zone text", "Coordinates" })
        T.same(headers(minimap, "right"), { "Clock", "FPS and ping", "Buttons" })
    end)

    it("says what the mail bookmarks are above them, wrapped across the page", function()
        local ns = start()
        local text = pages(ns).mail.texts[1]
        T.eq(text.column, "wide")
        T.eq(text.string:GetText(), ns.L.MAIL_INTRO)
        T.eq(text.string:GetWidth(), ns.SettingsWindow.PAGE_WIDTH - 2 * 8 - 7, "the page less its margins")
        local bottom = ns.SettingsPage.TOP + 12 + text.string:GetStringHeight()
        T.truthy(text.string:GetStringHeight() > 12, "more than one line")
        local first = control(ns, "mailBookmark1").row:PointFor("TOPLEFT")
        T.truthy(-first[5] >= bottom + 36, "the first bookmark is below the text and the section's title")
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

    it("takes a bookmark's name in a text box, saved without spaces once typed, put back on Escape", function()
        local ns = start({ mailBookmark1 = "Bankalt" })
        local c, page = control(ns, "mailBookmark1")
        show(page)
        T.eq(c.kind, "text")
        T.eq(c.text:GetText(), "Bookmark 1")
        local box = c.widget
        T.eq(box.template, "InputBoxTemplate")
        T.eq(box:GetText(), "Bankalt")
        Stubs.Type(box, "  Herbbank ")
        T.eq(ns.Options:Get("mailBookmark1"), "Bankalt", "not while typing")
        box:RunScript("OnEnterPressed")
        T.falsy(box:HasFocus())
        T.eq(ns.Options:Get("mailBookmark1"), "Herbbank")
        T.eq(box:GetText(), "Herbbank")
        Stubs.Type(box, "Typo")
        box:RunScript("OnEscapePressed")
        T.eq(ns.Options:Get("mailBookmark1"), "Herbbank")
        T.eq(box:GetText(), "Herbbank")
        -- Emptied, the bookmark is gone; a click elsewhere saves too.
        Stubs.Type(box, " ")
        box:ClearFocus()
        T.eq(ns.Options:Get("mailBookmark1"), "")
    end)

    it("goes on to the next bookmark with Tab and back with Shift+Tab", function()
        local ns = start()
        local first, second = control(ns, "mailBookmark1").widget, control(ns, "mailBookmark2").widget
        T.eq(first.nextEditBox, second)
        T.eq(second.previousEditBox, first)
        T.falsy(first.previousEditBox)
        T.falsy(control(ns, "mailBookmark6").widget.nextEditBox)
    end)

    it("keeps what is being typed when the page shows a change", function()
        local ns = start()
        local c, page = control(ns, "mailBookmark2")
        show(page)
        Stubs.Type(c.widget, "Half")
        ns.Options:Set("mailBookmark1", "Bankalt")
        T.eq(c.widget:GetText(), "Half")
        T.eq(control(ns, "mailBookmark1").widget:GetText(), "Bankalt")
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
        Stubs.SetControllerUI(true)
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

        -- Each change is saved right away, as the game's settings save theirs when they close. That
        -- fires UPDATE_BINDINGS, and the back button presses with the key.
        T.eq(Stubs.state().bindingSaves[1], 3, "saved three times, in the set in use")
        Stubs.Fire("UPDATE_BINDINGS")
        Stubs.RunTimers()
        Stubs.AdvanceTime()
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

    it("offers FPS and ping a spot in a row or hidden, and greys out their color and size while hidden", function()
        local ns = start()
        local position = control(ns, "minimapPerformance")
        T.same(values(position), { "topLeft", "top", "topRight", "bottomLeft", "bottom", "bottomRight", "hidden" })
        T.eq(position.column, "right")
        local color, page = control(ns, "minimapPerformanceClassColor")
        local size = control(ns, "minimapPerformanceSize")
        show(page)
        T.falsy(color.widget:IsEnabled())
        T.falsy(size.widget:IsEnabled())
        radio(position, "Below, right").select()
        T.eq(ns.Options:Get("minimapPerformance"), "bottomRight")
        T.truthy(color.widget:IsEnabled())
        T.truthy(size.widget:IsEnabled())
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

    it("offers the zone text's frame only while the zone text is at its default spot", function()
        local ns = start()
        local frame, page = control(ns, "hideMinimapZoneTextFrame")
        show(page)
        T.eq(frame.kind, "checkbox")
        T.truthy(frame.indent)
        T.truthy(frame.widget:IsEnabled())
        ns.Options:Set("minimapZoneText", "above")
        T.falsy(frame.widget:IsEnabled())
    end)

    it("offers font sizes for the zone text, the clock and FPS and ping, the game's own first", function()
        local ns = start()
        for _, key in ipairs({ "minimapZoneTextSize", "minimapClockSize", "minimapPerformanceSize" }) do
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

    it("puts what's marked on the world map in rows across its page", function()
        local ns = start()
        local page = pages(ns).worldMap
        T.eq(#page.controls, 2)
        T.eq(page.controls[1].key, "mapDungeons")
        T.eq(page.controls[2].key, "mapTravel")
        T.eq(page.controls[1].column, "wide")
    end)

    it("leaves out the world map page on a client without Forever's maps", function()
        local ns, api = Stubs.LoadAddon(), Stubs.InstallSettings()
        Stubs.state().maps = {}
        Stubs.Login()
        T.eq(pages(ns).worldMap, nil)
        T.eq(control(ns, "mapDungeons"), nil)
        for _, category in ipairs(api.categories) do
            T.truthy(category.name ~= "World map", "no World map page")
        end
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

    it("puts the ring on a page of its own: the switch in the title bar, and the rings' editor below it", function()
        local ns = start()
        local page = pages(ns).ring
        show(page)
        T.eq(#page.controls, 1)
        local switch = page.controls[1]
        T.eq(switch.key, "ring")
        T.eq(switch.column, "title")
        T.eq(switch.text.justifyH, "RIGHT", "its name next to its box")
        T.eq(page:Height(), ns.SettingsPage.TOP, "the rows below the title stay free")
        T.eq(page.defaultsButton, nil, "no Defaults button, which would only turn the rings off")
        T.eq(QoLRingEditor:GetParent(), page.frame)
        T.truthy(QoLRingEditor:IsVisible(), "the editor")
        T.eq(QoLRingEditor.note:GetText(), "The rings are off: turn them on at the top of this page.")
        switch.widget:Click()
        T.truthy(ns.Options:Get("ring"), "on")
        T.truthy(QoLRingEditor.note:GetText():find("^Click a spell"), "the editor follows the switch")
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

    it("shows the chat commands and the other addons on the information page", function()
        local ns = start()
        local info = ns.SettingsPanel.info
        T.same(info.sections, { "Commands", "More addons by ollidiemaus" })
        local commands = {}
        for _, entry in ipairs(info.entries) do commands[#commands + 1] = entry.label:GetText() end
        T.same(commands, { "/qol", "/qol ring", "/rl" })
        T.eq(info.defaultsButton, nil, "nothing on it to reset")
    end)

    it("marks the other addons that are loaded as installed, each time the information page shows", function()
        local ns = start()
        local info = ns.SettingsPanel.info
        Stubs.state().loadedAddons.AutoPotion = true
        info.frame:Show()
        T.truthy(info.installed.AutoPotion:IsShown())
        T.falsy(info.installed.AutoSetup:IsShown())
        T.falsy(info.installed.Wayscribe:IsShown())
        info.frame:Hide()
        Stubs.state().loadedAddons.Wayscribe = true
        info.frame:Show()
        T.truthy(info.installed.Wayscribe:IsShown())
    end)

    it("keeps an addon's link as it is when typed into, ready to be copied", function()
        local ns = start()
        local box = ns.SettingsPanel.info.links.AutoPotion
        T.eq(box:GetText(), "https://www.curseforge.com/wow/addons/auto-potion")
        box:SetText("https://example.com")
        box:RunScript("OnTextChanged", true)
        T.eq(box:GetText(), "https://www.curseforge.com/wow/addons/auto-potion")
    end)

    it("shows the version of a packaged addon next to the title, none in a checkout", function()
        local ns = Stubs.LoadAddon({ version = "1.4.0" })
        Stubs.InstallSettings()
        Stubs.Login()
        T.eq(ns.SettingsPanel.info.versionText:GetText(), "Version 1.4.0")
        ns = Stubs.LoadAddon({ version = "@project-version@" })
        Stubs.InstallSettings()
        Stubs.Login()
        T.eq(ns.SettingsPanel.info.versionText, nil)
    end)

    it("opens the settings from a button on the information page", function()
        local ns = start()
        local info = ns.SettingsPanel.info
        info.frame:Show()
        T.eq(info.openButton:GetText(), "Open settings (/qol)")
        T.falsy(info.openLater:IsShown(), "no note with keyboard and mouse")
        info.openButton:Click()
        Stubs.RunTimers()
        T.truthy(QoLSettings:IsShown(), "open, over the game's options")
    end)

    it("opens the settings only once the game's options are closed, in the controller interface", function()
        local ns = start()
        local info = ns.SettingsPanel.info
        Stubs.SetControllerUI(true)
        info.frame:Show()
        T.truthy(info.openLater:IsShown(), "says so next to the button")
        T.eq(info.openLater:GetText(), "They open once you close the game's options.")
        local options = CreateFrame("Frame", "SettingsPanel", UIParent)
        Stubs.SetControllerWindow(options)
        info.openButton:Click()
        Stubs.RunTimers()
        Stubs.AdvanceTime()
        T.falsy(QoLSettings:IsShown(), "not while the game's options have the controller")
        options:Hide()
        Stubs.SetControllerWindow(nil)
        Stubs.AdvanceTime()
        Stubs.AdvanceTime()
        T.truthy(QoLSettings:IsShown(), "open once they closed")
        info.frame:Hide()
        Stubs.SetControllerUI(false)
        info.frame:Show()
        T.falsy(info.openLater:IsShown(), "follows the interface")
    end)

    it("opens the window without the Settings API too, only the information page missing", function()
        local ns = Stubs.LoadAddon()
        Stubs.Login()
        T.eq(ns.SettingsPanel.info, nil)
        SlashCmdList.QOL("")
        T.truthy(QoLSettings:IsShown())
    end)
end)
