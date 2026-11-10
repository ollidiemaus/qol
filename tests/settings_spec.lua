local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- The addon loaded last, for show.
local loaded

-- forever: with Forever's controller action bar, which brings the Controller page, and the game's
-- Cooldown Manager, which brings the Cooldown Manager page.
local function start(savedOptions, forever)
    local ns = Stubs.LoadAddon()
    if forever then
        Stubs.NewGamepadBar()
        Stubs.NewCooldownManager()
    end
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

-- The window's list as it reads from the top: a group's header as "[name]", a page by its name.
local function listed(ns)
    local window = ns.SettingsPanel.window
    local names = {}
    for _, entry in ipairs(window.entries) do
        if entry.group then
            names[#names + 1] = "[" .. entry.label:GetText() .. "]"
        else
            names[#names + 1] = window.buttons[entry.key].label:GetText()
        end
    end
    return names
end

-- The list on a client without Forever's controller action bar.
local LISTED = { "[General]", "Automation", "Chat", "Mail", "[Display]", "Interface", "Unit Frames", "Action Bars",
    "Viewport", "[Maps]", "Minimap", "World map", "[Input]", "Ring", "Click casting", "[System]",
    "Graphics & Camera" }

local function radio(c, text)
    c.widget:GenerateMenu()
    for _, entry in ipairs(c.widget.menu) do
        if entry.text == text then return entry end
    end
    error("no menu entry " .. text)
end

-- A table of a page as it reads: its captions, then each line shown, by its name (after two spaces for
-- a line that belongs to the one above it, indented) and what each column has: a control's kind, or
-- "-" for nothing.
local function tableRows(page, index)
    local settingsTable = page.tables[index or 1]
    local captions = {}
    for _, caption in ipairs(settingsTable.captions) do captions[#captions + 1] = caption:GetText() end
    local rows = { table.concat(captions, " | ") }
    local shown = {}
    for _, line in ipairs(settingsTable.lines) do
        if line.frame:IsShown() then shown[#shown + 1] = line end
    end
    -- From the top down.
    table.sort(shown, function(a, b) return a.frame:PointFor("TOPLEFT")[5] > b.frame:PointFor("TOPLEFT")[5] end)
    for _, line in ipairs(shown) do
        do
            local name = line.label:GetText()
            if line.indent then name = "  " .. name end
            local row = { name }
            for column = 2, #settingsTable.captions do
                local c = line.cells[column]
                row[#row + 1] = c and c.row:IsShown() and c.kind or "-"
            end
            rows[#rows + 1] = table.concat(row, " | ")
        end
    end
    return rows
end

-- The top of a table's line, by its name.
local function lineTop(page, name)
    for _, line in ipairs(page.tables[1].lines) do
        if line.label:GetText() == name then return -line.frame:PointFor("TOPLEFT")[5] end
    end
    error("no line " .. name)
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
        T.same(listed(ns), LISTED)
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

    it("heads each group with the game's category header, its pages below it, in the game's list spacing", function()
        local ns = start()
        local window = ns.SettingsPanel.window
        local arts, last = {}, nil
        for _, entry in ipairs(window.entries) do
            local top
            if entry.group then
                top = -entry.header:PointFor("TOPLEFT")[5]
                arts[#arts + 1] = entry.header:GetAtlas()
                T.eq(entry.label:GetFontObject(), "GameFontHighlightMedium")
                -- The game's list leaves a spacer of 18 between groups.
                if last then T.eq(top, last + 2 + 18, entry.label:GetText() .. " after a spacer") end
                last = top + 30
            else
                top = -window.buttons[entry.key]:PointFor("TOPLEFT")[5]
                T.eq(top, last + 2, entry.key .. " right below")
                last = top + 20
            end
        end
        -- The game's list takes its three header arts in turn.
        T.same(arts, { "Options_CategoryHeader_1", "Options_CategoryHeader_2", "Options_CategoryHeader_3",
            "Options_CategoryHeader_1", "Options_CategoryHeader_2" })
        T.truthy(last <= window.PAGE_HEIGHT, "the list fits the window: " .. last)
    end)

    it("groups the pages in German too", function()
        local ns = Stubs.LoadAddon({ locale = "deDE" })
        Stubs.InstallSettings()
        Stubs.Login()
        T.same(listed(ns), { "[Allgemein]", "Automatisierung", "Chat", "Post", "[Darstellung]", "Oberfläche",
            "Einheitenfenster", "Aktionsleisten", "Viewport", "[Karten]", "Minimap", "Weltkarte", "[Eingabe]", "Ring",
            "Klickzauber", "[System]", "Grafik & Kamera" })
    end)

    it("lists on retail only the groups it has pages for, Maps with only the Minimap", function()
        local ns = Stubs.LoadAddon({ client = "retail" })
        Stubs.InstallSettings()
        Stubs.state().maps = {}
        Stubs.Login()
        T.same(listed(ns), { "[General]", "Automation", "Chat", "Mail", "[Display]", "Interface", "Unit Frames",
            "Action Bars", "Viewport", "[Maps]", "Minimap", "[Input]", "Ring", "Click casting", "[System]",
            "Graphics & Camera" })
    end)

    it("leaves out a group none of whose pages the client has", function()
        local ns = Stubs.LoadAddon()
        Stubs.InstallSettings()
        for _, setting in ipairs(ns.HiddenSettings.SETTINGS) do Stubs.state().cvars[setting.cvar] = nil end
        Stubs.Login()
        local names = listed(ns)
        T.eq(names[#names], "Click casting", "no System group without a hidden setting")
        T.eq(pages(ns).advanced, nil)
    end)

    it("opens a page by its old key, wherever its group put it", function()
        local ns = start()
        ns.SettingsPanel:Open("advanced")
        T.truthy(pages(ns).advanced.frame:IsShown())
        T.eq(pages(ns).advanced.title, "Graphics & Camera")
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
        T.eq(#names, #LISTED + 2)
        T.same({ names[15], names[16], names[17], names[18] }, { "Ring", "Click casting", "Controller", "[System]" },
            "under Input")
        T.same(headers(pages(ns).controller, "left"), { "Back buttons", "Triggers" })
        T.same(headers(pages(ns).controller, "right"), { "Buffs", "Bars that follow the stance" })
        T.same(headers(pages(ns).controller, "wide"), { "Keys" })
        T.truthy(control(ns, "hideBuffTooltips"))
        local c = control(ns, "controllerBackButtonsBar")
        T.same(values(c), { 6, 7, 8 })
        T.falsy(c.enabled(), "the bar waits for the back buttons")
        ns.Options:Set("controllerBackButtons", true)
        T.truthy(c.enabled(), "enabled with the back buttons")
    end)

    it("adds a Cooldown Manager page on Forever, in Display after Action Bars", function()
        local ns = start(nil, true)
        local names = listed(ns)
        T.same({ names[8], names[9], names[10] }, { "Action Bars", "Cooldown Manager", "Viewport" })
        local page = pages(ns).cooldownManager
        T.same(headers(page, "left"), { "Look", "Reminders" })
        local c = control(ns, "hideCooldownManagerBorders")
        T.eq(c.kind, "checkbox")
        T.eq(c.text:GetText(), "Hide icon borders")
        for _, row in ipairs({ "Essential Cooldowns", "Utilities", "Tracked Buffs", "Tracked Bars" }) do
            T.truthy(c.tooltip:find(row, 1, true), "the tooltip names " .. row)
        end
    end)

    it("has a Reminders section under Look, with its switch and a line per preset", function()
        local ns = Stubs.LoadAddon()
        Stubs.NewCooldownManager()
        Stubs.state().gameSpells[19705] = { name = "Well Fed", texture = 136000 }
        Stubs.state().gameSpells[1225478] = { name = "Well Rested", texture = 136001 }
        Stubs.state().gameSpells[1229741] = { name = "Camp Benefits", texture = 136002 }
        Stubs.state().items[2131] = { texture = 135274, classID = 2, subclassID = 7 }
        Stubs.state().equipped[16] = 2131
        Stubs.InstallSettings()
        Stubs.Login()
        loaded = ns
        local page = pages(ns).cooldownManager
        T.same(headers(page, "left"), { "Look", "Reminders" })
        local switch = control(ns, "reminders")
        T.eq(switch.kind, "checkbox")
        T.eq(switch.text:GetText(), "Show reminders")
        T.falsy(switch.get(), "off by default")
        T.same(tableRows(page), { "Reminder | On | ", "Well Fed | checkbox | -", "Well Rested | checkbox | -",
            "Camp Benefits | checkbox | -", "Main Hand Weapon Buff | checkbox | -",
            "Off Hand Weapon Buff | checkbox | -", "Drag a spell here from your spellbook | - | -" })
        show(page)
        local icons = {}
        for index = 1, 4 do icons[index] = page.tables[1].lines[index].icon.texture end
        T.same(icons, { 136000, 136001, 136002, 135274 }, "the main hand's: the sword in it")
        local wellFed = control(ns, "reminderWellFed")
        T.falsy(wellFed.get(), "off by default")
        wellFed.widget:Click()
        T.truthy(ns.Options:Get("reminderWellFed"))
        T.truthy(lineTop(page, "Well Fed") > 0)
    end)

    it("has a Hide reminders section beside Reminders, a box per condition", function()
        local ns = start(nil, true)
        T.same(headers(pages(ns).cooldownManager, "right"), { "Hide reminders" })
        local seen = {}
        for _, key in ipairs({ "reminderHideResting", "reminderHideCombat", "reminderHideMounted",
            "reminderHideDeadOrFlying", "reminderHideMaxLevel" }) do
            local c = control(ns, key)
            T.eq(c.kind, "checkbox")
            T.eq(c.column, "right")
            seen[#seen + 1] = c.text:GetText() .. (c.get() and " (on)" or "")
        end
        T.same(seen, { "While resting", "In combat", "While mounted", "While dead or on a flight path (on)",
            "Experience reminders at maximum level (on)" })
        T.truthy(control(ns, "reminderHideMaxLevel").tooltip:find("Well Rested", 1, true))
    end)

    -- The Cooldown Manager page with the presets' and Thorns' and Mark of the Wild's spell data, for
    -- a character that knows Thorns (rank 1); the account's own reminders saved.
    local THORNS_1, THORNS_3, MARK = 467, 1075, 1126
    local function remindersPage(savedReminders)
        local ns = Stubs.LoadAddon()
        Stubs.NewCooldownManager()
        local state = Stubs.state()
        state.gameSpells[19705] = { name = "Well Fed", texture = 136000 }
        state.gameSpells[1225478] = { name = "Well Rested", texture = 136001 }
        state.gameSpells[1229741] = { name = "Camp Benefits", texture = 136002 }
        state.gameSpells[THORNS_3] = { name = "Thorns", texture = 136104 }
        state.gameSpells[MARK] = { name = "Mark of the Wild", texture = 136078 }
        state.spells[THORNS_1] = { name = "Thorns", texture = 136104, subtext = "Rank 1" }
        Stubs.InstallSettings()
        _G.QoLDB = { options = { reminders = true }, reminders = savedReminders }
        Stubs.Fire("ADDON_LOADED", "QoL")
        Stubs.Fire("PLAYER_LOGIN")
        Stubs.Fire("PLAYER_ENTERING_WORLD")
        Stubs.RunTimers()
        loaded = ns
        local page = pages(ns).cooldownManager
        show(page)
        return ns, page
    end

    -- The line of a reminder of the player's own, by its name.
    local function ownLine(page, name)
        for _, line in ipairs(page.tables[1].lines) do
            if line.frame:IsShown() and line.label:GetText() == name then return line end
        end
        return nil
    end

    local PRESET_ROWS = { "Reminder | On | ", "Well Fed | checkbox | -", "Well Rested | checkbox | -",
        "Camp Benefits | checkbox | -", "Main Hand Weapon Buff | checkbox | -", "Off Hand Weapon Buff | checkbox | -" }
    local DROP_ROW = "Drag a spell here from your spellbook | - | -"

    local function rowsWith(...)
        local rows = {}
        for _, row in ipairs(PRESET_ROWS) do rows[#rows + 1] = row end
        for _, row in ipairs({ ... }) do rows[#rows + 1] = row end
        rows[#rows + 1] = DROP_ROW
        return rows
    end

    it("adds a line for a spell dropped on the reminders, once, and nothing for anything else", function()
        local _, page = remindersPage()
        local state = Stubs.state()
        local drop = page.tables[1].lines[6]
        T.truthy(drop.tooltip:find("buffs on your character", 1, true))
        state.cursorInfo = { "spell", 1, "spell", THORNS_1, THORNS_1 }
        drop.frame:RunScript("OnReceiveDrag")
        T.same(tableRows(page), rowsWith("Thorns | checkbox | remove"))
        T.eq(ownLine(page, "Thorns").icon.texture, 136104)
        T.eq(state.cursorInfo, nil)
        state.cursorInfo = { "spell", 1, "spell", THORNS_3, THORNS_3 }
        page.tables[1].frame:RunScript("OnReceiveDrag")
        state.cursorInfo = { "item", 4540, "item:4540" }
        ownLine(page, "Thorns").frame:RunScript("OnReceiveDrag")
        T.same(tableRows(page), rowsWith("Thorns | checkbox | remove"), "a duplicate and an item add nothing")
        T.same(state.cursorInfo, { "item", 4540, "item:4540" }, "the item stays on the cursor")
        state.cursorInfo = { "spell", 1, "spell", MARK, MARK }
        drop.frame:RunScript("OnMouseUp", "LeftButton")
        T.same(tableRows(page), rowsWith("Thorns | checkbox | remove", "Mark of the Wild | checkbox | remove"),
            "in the order added")
    end)

    it("pauses a reminder of the player's own with its checkbox and removes it with its X", function()
        local _, page = remindersPage({ { spell = THORNS_3, on = true }, { spell = MARK, on = true } })
        local thorns = ownLine(page, "Thorns")
        T.truthy(thorns.cells[2].widget:GetChecked())
        thorns.cells[2].widget:Click()
        T.same(QoLDB.reminders[1], { spell = THORNS_3, on = false })
        T.falsy(thorns.cells[2].widget:GetChecked())
        thorns.cells[3].widget:Click()
        T.same(tableRows(page), rowsWith("Mark of the Wild | checkbox | remove"))
        T.same(QoLDB.reminders, { { spell = MARK, on = true } })
        T.truthy(ownLine(page, "Mark of the Wild").cells[2].widget:GetChecked(), "the line below moved up, its own state")
    end)

    it("greys out the line of a spell the character doesn't know, still removable, until it learns it", function()
        local _, page = remindersPage({ { spell = MARK, on = true } })
        local mark = ownLine(page, "Mark of the Wild")
        T.same({ mark.label:GetTextColor() }, { 0.5, 0.5, 0.5, 1 })
        T.truthy(mark.icon:IsDesaturated())
        T.falsy(mark.cells[2].widget:IsEnabled())
        T.truthy(mark.cells[3].widget:IsEnabled())
        Stubs.state().spells[MARK] = { name = "Mark of the Wild", texture = 136078, subtext = "Rank 1" }
        Stubs.Fire("SPELLS_CHANGED")
        Stubs.RunTimers()
        T.same({ mark.label:GetTextColor() }, { 1, 0.82, 0, 1 })
        T.falsy(mark.icon:IsDesaturated())
        T.truthy(mark.cells[2].widget:IsEnabled())
        mark.cells[3].widget:Click()
        T.same(tableRows(page), rowsWith())
    end)

    -- A button row on a page, by its name.
    local function buttonRow(page, name)
        for _, c in ipairs(page.controls) do
            if c.kind == "button" and c.text:GetText() == name then return c end
        end
        error("no button row " .. name)
    end

    it("has an icon size slider for the reminder row, 40 by default", function()
        local ns = remindersPage()
        local size = control(ns, "reminderIconSize")
        T.eq(size.kind, "slider")
        T.eq(size.text:GetText(), "Icon size")
        T.eq(size.get(), 40)
    end)

    it("unlocks the reminder row with its button, and locks it with the button again or by closing the window", function()
        local ns, page = remindersPage()
        local move = buttonRow(page, "Reminder row")
        T.eq(move.widget:GetText(), "Unlock")
        move.widget:Click()
        T.truthy(ns.Reminders.IsUnlocked())
        T.eq(move.widget:GetText(), "Lock")
        move.widget:Click()
        T.falsy(ns.Reminders.IsUnlocked())
        T.eq(move.widget:GetText(), "Unlock")
        move.widget:Click()
        ns.SettingsPanel.window.frame:Hide()
        T.falsy(ns.Reminders.IsUnlocked(), "closing the window locks it")
        show(page)
        T.eq(move.widget:GetText(), "Unlock")
    end)

    it("puts the reminder row back at its default spot with Reset position", function()
        local ns, page = remindersPage()
        ns.Options:Set("reminderRowX", 100)
        ns.Options:Set("reminderRowY", -200)
        buttonRow(page, "Reminder row position").widget:Click()
        T.eq(QoLDB.options.reminderRowX, nil)
        T.eq(QoLDB.options.reminderRowY, nil)
    end)

    it("leaves the Cooldown Manager page out on Forever without the game's rows", function()
        local ns = start()
        T.eq(pages(ns).cooldownManager, nil)
    end)

    for _, client in ipairs({ "retail", "classicEra" }) do
        it("leaves the Cooldown Manager page out on " .. client .. ", even with the game's rows", function()
            local ns = Stubs.LoadAddon({ client = client })
            Stubs.NewCooldownManager()
            Stubs.InstallSettings()
            Stubs.Login()
            T.eq(pages(ns).cooldownManager, nil)
            T.eq(control(ns, "hideCooldownManagerBorders"), nil)
        end)
    end

    it("hides the Cooldown Manager's borders with the checkbox, and shows them again with Defaults", function()
        local ns = start(nil, true)
        local c, page = control(ns, "hideCooldownManagerBorders")
        show(page)
        local border
        for _, region in ipairs({ Stubs.CooldownIcons("EssentialCooldownViewer")[1]:GetRegions() }) do
            if region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then border = region end
        end
        c.widget:Click()
        Stubs.RunTimers()
        T.eq(ns.Options:Get("hideCooldownManagerBorders"), true)
        T.eq(border:GetAlpha(), 0)
        page.defaultsButton:Click()
        page.defaultsButton:Click()
        Stubs.RunTimers()
        T.eq(ns.Options:Get("hideCooldownManagerBorders"), false)
        T.eq(c.widget:GetChecked(), false)
        T.eq(border:GetAlpha(), 1)
    end)

    it("names the Cooldown Manager page and its row in German", function()
        local ns = Stubs.LoadAddon({ locale = "deDE" })
        Stubs.NewCooldownManager()
        Stubs.InstallSettings()
        Stubs.Login()
        T.eq(ns.SettingsPanel.window.buttons.cooldownManager.label:GetText(), "Abklingzeitmanager")
        T.same(headers(pages(ns).cooldownManager, "left"), { "Aussehen", "Erinnerungen" })
        T.same(headers(pages(ns).cooldownManager, "right"), { "Erinnerungen ausblenden" })
        T.eq(control(ns, "reminderHideResting").text:GetText(), "Beim Ausruhen")
        local c = control(ns, "hideCooldownManagerBorders")
        T.eq(c.text:GetText(), "Symbolränder ausblenden")
        T.truthy(c.tooltip:find("Verfolgte Stärkungseffekte", 1, true))
        T.eq(control(ns, "reminders").text:GetText(), "Erinnerungen anzeigen")
        T.same(tableRows(pages(ns).cooldownManager), { "Erinnerung | An | ", "Satt | checkbox | -",
            "Gut ausgeruht | checkbox | -", "Lagervorteile | checkbox | -", "Waffenbuff Waffenhand | checkbox | -",
            "Waffenbuff Schildhand | checkbox | -",
            "Zieht einen Zauber aus Eurem Zauberbuch hierher | - | -" }, "without the client's names, the presets' own")
        local drop = pages(ns).cooldownManager.tables[1].lines[6]
        T.truthy(drop.tooltip:find("Stärkungseffekte auf Eurem Charakter", 1, true))
    end)

    it("greys out going back to Top while the trigger toggle is off", function()
        local ns = start(nil, true)
        T.eq(ns.Options:Get("controllerTriggerToggle"), false, "off by default")
        T.eq(ns.Options:Get("controllerTriggerToggleTopAfterCombat"), true, "on by default")
        T.truthy(control(ns, "controllerTriggerToggle").tooltip:find("compact layout", 1, true))
        local c = control(ns, "controllerTriggerToggleTopAfterCombat")
        T.falsy(c.enabled(), "waits for the trigger toggle")
        ns.Options:Set("controllerTriggerToggle", true)
        T.truthy(c.enabled(), "enabled with the trigger toggle")
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
        T.same(headers(pages(ns).automation, "left"), { "Merchant", "Bags" })
        T.same(headers(pages(ns).automation, "right"), { "Quests", "Loot" })
        T.same(headers(pages(ns).interface, "left"), { "Hide", "Edit Mode" })
        T.same(headers(pages(ns).interface, "right"), { "Tooltips" })
        T.same(headers(pages(ns).unitFrames, "left"), { "Player frame" })
        T.same(headers(pages(ns).unitFrames, "right"), { "Health bars in class color" })
        T.same(headers(pages(ns).chat, "left"), { "Chat window" })
        T.same(headers(pages(ns).chat, "right"), { "Chat commands" })
        T.same(headers(pages(ns).mail, "left"), { "Bookmarks" })
    end)

    it("puts each option of the old Interface page on the page now named for it", function()
        local ns = start()
        for key, page in pairs({ hideMicroMenu = "interface", hideBagsBar = "interface", pastScreenEdge = "interface",
            tooltipIDs = "interface", tooltipSellPrice = "interface", druidManaBar = "unitFrames",
            hidePortraitHitText = "unitFrames", classColorPlayer = "unitFrames", classColorTarget = "unitFrames",
            classColorTargetOfTarget = "unitFrames", classColorFocus = "unitFrames",
            classColorFocusTarget = "unitFrames", sortOnOpen = "automation" }) do
            local _, on = control(ns, key)
            T.eq(on, pages(ns)[page], key .. " on " .. page)
        end
        T.eq(pages(ns).unitFrames.title, "Unit Frames")
    end)

    it("offers only Sort on open in the Bags section", function()
        local ns = start()
        local left = {}
        for _, c in ipairs(pages(ns).automation.controls) do
            if c.column == "left" then left[#left + 1] = c.key end
        end
        -- Below the Merchant section.
        T.eq(left[#left], "sortOnOpen")
        T.eq(control(ns, "sortOnOpen").text:GetText(), "Sort on open")
        T.eq(control(ns, "showCombinedBagSort"), nil)
        T.eq(control(ns, "combinedBagTopLeft"), nil)
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

    it("shows a slider's box with its step's decimals, and greys it out with its row", function()
        local ns = start()
        local value, on = 1.2, true
        local page = ns.SettingsPage.New("Test")
        local c = page:Slider("wide", { get = function() return value end, set = function(v) value = v end },
            "Zoom", 0, 2, nil, nil, { step = 0.1, textBox = true, enabled = function() return on end })
        page:Refresh()
        T.eq(c.widget.step, 0.1)
        T.eq(c.box:GetText(), "1.2")
        Stubs.Type(c.box, "1.66")
        c.box:RunScript("OnEnterPressed")
        T.eq(value, 1.7)
        T.eq(c.box:GetText(), "1.7")
        c.widget.Back:Click()
        T.eq(c.box:GetText(), "1.6")
        value = 1
        page:Refresh()
        T.eq(c.box:GetText(), "1.0")
        T.truthy(c.box.enabled)
        T.same(c.box.textColor, { 1, 1, 1 })
        on = false
        page:Refresh()
        T.falsy(c.box.enabled)
        T.falsy(c.widget.enabled)
        T.same(c.box.textColor, { 0.5, 0.5, 0.5 })
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

    it("writes every name in the same font, also the indented ones and a table's lines", function()
        local ns = start()
        for _, page in pairs(pages(ns)) do
            for _, c in ipairs(page.controls) do
                -- A table's cells have their line's name.
                if c.text then T.eq(c.text.font, "GameFontNormal", c.key) end
            end
            for _, settingsTable in ipairs(page.tables) do
                for _, line in ipairs(settingsTable.lines) do T.eq(line.label.font, "GameFontNormal", line.label:GetText()) end
            end
        end
    end)
    it("offers the zone text positions in a dropdown", function()
        local ns = start()
        local c, page = control(ns, "minimapZoneText")
        show(page)
        T.eq(c.kind, "dropdown")
        T.same(values(c), { "default", "top", "bottom", "insideTop", "insideBottom", "hidden" })
        T.eq(c.widget.text, "Default")
        radio(c, "Below, center").select()
        T.eq(ns.Options:Get("minimapZoneText"), "bottom")
        T.eq(c.widget.text, "Below, center")
        radio(c, "Inside, top center").select()
        T.eq(ns.Options:Get("minimapZoneText"), "insideTop")
        c.widget:OpenMenu()
        T.eq(c.widget.menusOpened, 1, "a click opens the game's menu")
        T.eq(ns.Options:Get("minimapZoneText"), "insideTop")
    end)

    it("hides the zone text's font size, class color and offsets while it is hidden", function()
        local ns = start()
        local _, page = control(ns, "minimapZoneText")
        show(page)
        local keys = { "minimapZoneTextSize", "minimapZoneTextClassColor", "minimapZoneTextOffsetX",
            "minimapZoneTextOffsetY" }
        for _, key in ipairs(keys) do T.truthy(control(ns, key).widget:IsVisible(), key) end
        ns.Options:Set("minimapZoneText", "hidden")
        for _, key in ipairs(keys) do T.falsy(control(ns, key).widget:IsVisible(), key) end
        ns.Options:Set("minimapZoneText", "insideBottom")
        for _, key in ipairs(keys) do T.truthy(control(ns, key).widget:IsVisible(), key) end
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

    it("lays the minimap's elements out in a table across the page, below the Shape section", function()
        local ns = start()
        local page = pages(ns).minimap
        show(page)
        T.same(headers(page, "left"), { "Shape" })
        T.same(headers(page, "right"), {})
        T.same(tableRows(page), {
            "Element | Position | Font size | Class color | Offset X | Y",
            "Zone text | dropdown | dropdown | checkbox | number | number",
            "  Hide its frame | checkbox | - | - | - | -",
            "Clock | dropdown | dropdown | checkbox | number | number",
            "Coordinates | dropdown | dropdown | checkbox | number | number",
            "FPS and ping | dropdown | - | - | - | -",
            "Addon compartment | dropdown | - | - | number | number",
            "Tracking button | dropdown | - | - | number | number",
            "Day and night icon | dropdown | - | - | number | number",
            "Calendar button | dropdown | - | - | - | -",
        })
        local border = -control(ns, "squareMinimapBorder").row:PointFor("TOPLEFT")[5]
        T.eq(-page.tables[1].frame:PointFor("TOPLEFT")[5], border + 26 + 16, "a section's gap below the border")
    end)

    it("shows only a hidden element's name and Position, and an extra line only while it applies", function()
        local ns = start()
        local page = pages(ns).minimap
        show(page)
        local compartment = lineTop(page, "Addon compartment")
        ns.Options:Set("minimapPerformance", "bottomRight")
        local rows = tableRows(page)
        T.eq(rows[6], "FPS and ping | dropdown | dropdown | checkbox | number | number")
        T.eq(rows[7], "  Show | dropdown | - | - | - | -")
        T.eq(lineTop(page, "Show"), lineTop(page, "FPS and ping") + 26, "right below")
        T.eq(lineTop(page, "Addon compartment"), compartment + 26, "one line further down")
        ns.Options:Set("minimapZoneText", "top")
        T.eq(tableRows(page)[3], "Clock | dropdown | dropdown | checkbox | number | number",
            "the zone text's frame only at the game's spot")
        T.eq(lineTop(page, "Addon compartment"), compartment)
        ns.Options:Set("minimapClock", "hidden")
        ns.Options:Set("minimapCoords", "hidden")
        rows = tableRows(page)
        T.same({ rows[3], rows[4] }, { "Clock | dropdown | - | - | - | -", "Coordinates | dropdown | - | - | - | -" })
    end)

    it("offers the coordinates and the calendar button the game's spot or Hidden", function()
        local ns = start()
        for _, key in ipairs({ "minimapCoords", "minimapCalendar" }) do
            local c, page = control(ns, key)
            show(page)
            T.eq(c.kind, "dropdown")
            T.same(values(c), { "default", "hidden" })
            T.eq(c.widget.text, "Default")
            radio(c, "Hidden").select()
            T.eq(ns.Options:Get(key), "hidden")
        end
    end)

    it("names a table's cell by its line and column when pointed at, and a line by what it sets", function()
        local ns = start()
        local c, page = control(ns, "minimapClockClassColor")
        show(page)
        c.widget:RunScript("OnEnter")
        T.eq(GameTooltip.lines[1].text, "Clock: Class color")
        T.eq(GameTooltip.lines[2].text, ns.L.MINIMAP_CLOCK_CLASS_COLOR_TIP)
        for _, line in ipairs(page.tables[1].lines) do
            if line.label:GetText() == "Clock" then line.frame:RunScript("OnEnter") end
        end
        T.eq(GameTooltip.lines[1].text, "Clock")
        T.eq(GameTooltip.lines[2].text, ns.L.MINIMAP_POSITION_TIP)
    end)

    it("offers FPS and ping a spot in a row or hidden", function()
        local ns = start()
        local position, page = control(ns, "minimapPerformance")
        show(page)
        T.same(values(position), { "topLeft", "top", "topRight", "bottomLeft", "bottom", "bottomRight", "hidden" })
        radio(position, "Below, right").select()
        T.eq(ns.Options:Get("minimapPerformance"), "bottomRight")
    end)
    it("steps a minimap offset with its arrows and shows it in its box", function()
        local ns = start()
        local x, page = control(ns, "minimapClockOffsetX")
        local y = control(ns, "minimapClockOffsetY")
        show(page)
        T.eq(x.kind, "number")
        T.eq(y.kind, "number")
        T.eq(x.box:GetText(), "0")
        x.widget.Forward:Click()
        x.widget.Forward:Click()
        T.eq(ns.Options:Get("minimapClockOffsetX"), 2)
        T.eq(x.box:GetText(), "2")
        y.widget.Back:Click()
        T.eq(ns.Options:Get("minimapClockOffsetY"), -1)
        T.eq(y.box:GetText(), "-1")
        T.eq(ns.Options:Get("minimapClockOffsetX"), 2, "the other value stays")
    end)

    it("takes a typed offset on Enter, within its range, and Escape puts it back", function()
        local ns = start()
        local x, page = control(ns, "minimapClockOffsetX")
        show(page)
        Stubs.Type(x.box, "12")
        x.box:RunScript("OnEnterPressed")
        T.eq(ns.Options:Get("minimapClockOffsetX"), 12)
        Stubs.Type(x.box, "99")
        x.box:ClearFocus()
        T.eq(ns.Options:Get("minimapClockOffsetX"), 30)
        T.eq(x.box:GetText(), "30")
        Stubs.Type(x.box, "-99")
        x.box:RunScript("OnEnterPressed")
        T.eq(ns.Options:Get("minimapClockOffsetX"), -30)
        Stubs.Type(x.box, "2.6")
        x.box:RunScript("OnEnterPressed")
        T.eq(ns.Options:Get("minimapClockOffsetX"), 3)
        Stubs.Type(x.box, "7")
        x.box:RunScript("OnEscapePressed")
        T.eq(ns.Options:Get("minimapClockOffsetX"), 3)
        T.eq(x.box:GetText(), "3")
        Stubs.Type(x.box, "nothing")
        x.box:RunScript("OnEnterPressed")
        T.eq(ns.Options:Get("minimapClockOffsetX"), 3)
        T.eq(x.box:GetText(), "3")
    end)

    it("stops an offset's arrows at the end of its range", function()
        local ns = start({ minimapClockOffsetX = 30 })
        local x, page = control(ns, "minimapClockOffsetX")
        show(page)
        x.widget.Forward:Click()
        T.eq(ns.Options:Get("minimapClockOffsetX"), 30)
    end)

    it("goes from box to box with Tab, in reading order", function()
        local ns = start()
        local x = control(ns, "minimapClockOffsetX")
        local y = control(ns, "minimapClockOffsetY")
        T.eq(x.box.nextEditBox, y.box)
        T.eq(y.box.previousEditBox, x.box)
    end)

    it("skips the boxes of a hidden element with Tab, both ways", function()
        local ns = start()
        local coords, page = control(ns, "minimapCoordsOffsetY")
        local compartment = control(ns, "minimapCompartmentOffsetX")
        show(page)
        coords.box:SetFocus()
        coords.box:RunScript("OnTabPressed")
        T.truthy(compartment.box:HasFocus(), "past FPS and ping's, hidden")
        Stubs.state().shift = true
        compartment.box:RunScript("OnTabPressed")
        Stubs.state().shift = false
        T.truthy(coords.box:HasFocus(), "and back")
    end)
    it("hides an element's offsets while it is hidden", function()
        local ns = start()
        for _, case in ipairs({
            { "minimapClock", "default" },
            { "minimapZoneText", "insideTop" },
            { "minimapPerformance", "top" },
            { "minimapCompartment", "default" },
            { "minimapTracking", "default" },
            { "minimapDayNight", "default" },
            { "minimapCoords", "default" },
        }) do
            local key = case[1]
            local x, page = control(ns, key .. "OffsetX")
            local y = control(ns, key .. "OffsetY")
            show(page)
            ns.Options:Set(key, case[2])
            T.truthy(x.box:IsVisible(), key .. " shown")
            T.truthy(y.widget.Forward:IsVisible(), key .. " shown")
            ns.Options:Set(key, "hidden")
            T.falsy(x.box:IsVisible(), key .. " hidden")
            T.falsy(y.widget.Forward:IsVisible(), key .. " hidden")
        end
    end)
    it("resets the offsets, the Show choice and the Positions with the page's Defaults", function()
        local ns = start({ minimapClockOffsetX = 5, minimapCoordsOffsetY = -5, minimapPerformanceShow = "ping",
            minimapCoords = "hidden", minimapCalendar = "hidden", minimapCoordsSize = 14 })
        local x, page = control(ns, "minimapClockOffsetX")
        show(page)
        T.eq(x.box:GetText(), "5")
        page:SetDefaults()
        T.eq(ns.Options:Get("minimapClockOffsetX"), 0)
        T.eq(ns.Options:Get("minimapCoordsOffsetY"), 0)
        T.eq(ns.Options:Get("minimapPerformanceShow"), "both")
        T.eq(ns.Options:Get("minimapCoords"), "default")
        T.eq(ns.Options:Get("minimapCalendar"), "default")
        T.eq(ns.Options:Get("minimapCoordsSize"), 0)
        T.eq(x.box:GetText(), "0")
    end)
    it("offers what FPS and ping show, on a line of its own while they're shown", function()
        local ns = start()
        local c, page = control(ns, "minimapPerformanceShow")
        show(page)
        T.same(values(c), { "both", "fps", "ping" })
        T.eq(c.choices[1].label, "FPS and ping")
        T.falsy(c.widget:IsVisible())
        ns.Options:Set("minimapPerformance", "top")
        T.truthy(c.widget:IsVisible())
        radio(c, "Ping").select()
        T.eq(ns.Options:Get("minimapPerformanceShow"), "ping")
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
        T.truthy(frame.widget:IsVisible())
        for _, value in ipairs({ "top", "insideTop", "hidden" }) do
            ns.Options:Set("minimapZoneText", value)
            T.falsy(frame.widget:IsVisible(), value)
        end
        ns.Options:Set("minimapZoneText", "default")
        T.truthy(frame.widget:IsVisible())
        frame.widget:Click()
        T.eq(ns.Options:Get("hideMinimapZoneTextFrame"), true)
    end)
    it("offers font sizes for the zone text, the clock, the coordinates and FPS and ping, the game's own first", function()
        local ns = start()
        for _, key in ipairs({ "minimapZoneTextSize", "minimapClockSize", "minimapCoordsSize", "minimapPerformanceSize" }) do
            local c = control(ns, key)
            T.eq(c.kind, "dropdown")
            T.eq(c.choices[1].value, 0)
            T.eq(c.choices[1].label, "Default")
            T.eq(c.choices[2].label, "9")
            T.same(values(c), ns.MinimapLayout.FONT_SIZES)
        end
        local c, page = control(ns, "minimapClockSize")
        show(page)
        radio(c, "16").select()
        T.eq(ns.Options:Get("minimapClockSize"), 16)
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

    it("lists every bar in a table on the action bar page, then paging and buttons side by side", function()
        local ns = start()
        local page = pages(ns).actionBars
        show(page)
        T.same(headers(page, "wide"), { "Reverse growth" })
        T.same(headers(page, "left"), { "Paging", "Spell ranks" })
        T.same(headers(page, "right"), { "Buttons" })
        local expected = { "Bar | Vertical | Horizontal" }
        for _, bar in ipairs(ns.ActionBars.BARS) do
            expected[#expected + 1] = bar.label() .. " | checkbox | checkbox"
        end
        T.eq(#expected, 11, "ten bars")
        T.same(tableRows(page), expected)
        local key = ns.ActionBars.HorizontalKey("MultiBarRight")
        control(ns, key).widget:Click()
        T.eq(ns.Options:Get(key), true)
        T.eq(control(ns, "disableBarPaging").row:PointFor("TOPLEFT")[5],
            control(ns, "hideButtonBorders").row:PointFor("TOPLEFT")[5], "paging and buttons side by side")
    end)

    it("says what each flip does when its column's caption is pointed at", function()
        local ns = start()
        local captions = pages(ns).actionBars.tables[1].captions
        captions[2]:GetParent():RunScript("OnEnter")
        T.eq(GameTooltip.lines[1].text, "Vertical")
        T.eq(GameTooltip.lines[2].text, ns.L.FLIP_VERTICAL_TIP)
        captions[3]:GetParent():RunScript("OnEnter")
        T.eq(GameTooltip.lines[1].text, "Horizontal")
        T.eq(GameTooltip.lines[2].text, ns.L.FLIP_HORIZONTAL_TIP)
    end)
    it("has the spell ranks section on the action bar page on Forever, its button upgrading all spells", function()
        local ns = start()
        local page = pages(ns).actionBars
        T.same(headers(page, "left"), { "Paging", "Spell ranks" })
        T.eq(control(ns, "upgradeSpellRanks").column, "left")
        local button
        for _, c in ipairs(page.controls) do
            if c.kind == "button" then button = c end
        end
        T.truthy(button, "the button")
        T.eq(button.widget:GetText(), "Upgrade all spells now")
        local state = Stubs.state()
        state.spells[10] = { name = "Frostbolt", subtext = "Rank 1" }
        state.spells[20] = { name = "Frostbolt", subtext = "Rank 2" }
        state.actions[1] = { spell = 10 }
        button.widget:RunScript("OnClick")
        Stubs.RunTimers()
        T.eq(state.actions[1].spell, 20)
    end)

    for _, client in ipairs({ "retail", "classicEra" }) do
        it("leaves the spell ranks section out on " .. client, function()
            local ns = Stubs.LoadAddon({ client = client })
            Stubs.InstallSettings()
            Stubs.Login()
            T.eq(control(ns, "upgradeSpellRanks"), nil)
            T.same(headers(pages(ns).actionBars, "left"), { "Paging" })
        end)
    end

    it("names the trigger and spell rank rows in German short enough for one line, the rest in their tooltips", function()
        local ns = Stubs.LoadAddon({ locale = "deDE" })
        Stubs.NewGamepadBar()
        Stubs.InstallSettings()
        Stubs.Login()
        local toggle = control(ns, "controllerTriggerToggle")
        T.eq(toggle.text:GetText(), "Leiste per Trigger halten")
        T.truthy(toggle.tooltip:find("du musst ihn also nicht halten", 1, true))
        local top = control(ns, "controllerTriggerToggleTopAfterCombat")
        T.eq(top.text:GetText(), "Nach Kampf: obere Leiste")
        T.truthy(top.tooltip:find("zurück zur oberen Leiste", 1, true))
        local button
        for _, c in ipairs(pages(ns).actionBars.controls) do
            if c.kind == "button" then button = c end
        end
        T.eq(button.text:GetText(), "Ränge auf den Leisten")
        T.eq(button.widget:GetText(), "Jetzt aufwerten")
        -- The button is as wide as its name needs, which leaves the row's name the rest.
        T.truthy(button.widget:GetWidth() < 160, "narrower than the English button: " .. button.widget:GetWidth())
        T.truthy(button.widget:GetWidth() >= button.widget:GetTextWidth() + 40, "room around its name")
    end)

    it("names each Ring and Click casting tab in full, in German too", function()
        Stubs.LoadAddon({ locale = "deDE" })
        Stubs.InstallSettings()
        Stubs.Login()
        SlashCmdList.QOL("ring")
        SlashCmdList.QOL("click")
        local names = {}
        for _, editor in ipairs({ QoLRingEditor, QoLClickCastEditor }) do
            for _, tab in ipairs(editor.list.tabs) do
                local name = tab.Text:GetText()
                names[name] = true
                -- Held to the width the game measures, a name came out cut off ("Reittie…").
                T.eq(tab.Text:GetWidth(), 0, name .. " takes the width it needs")
                T.truthy(tab:GetWidth() >= tab.Text:GetStringWidth() + 10, name .. " fits its tab")
            end
        end
        T.truthy(names.Reittiere and names.Makros, "the mounts and macros tabs")
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
        T.same(commands, { "/qol", "/qol ring", "/qol click", "/rl" })
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
