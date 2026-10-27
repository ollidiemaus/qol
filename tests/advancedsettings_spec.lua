local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- The game's settings installed, the addon loaded and logged in. before: changes the test state
-- before the addon loads (a client without a setting).
local function start(before)
    local ns = Stubs.LoadAddon()
    if before then before(Stubs.state()) end
    Stubs.InstallSettings()
    Stubs.Login()
    return ns, Stubs.state()
end

local function page(ns)
    return ns.SettingsPanel.pages.advanced
end

-- The window open on the Advanced settings page.
local function show(ns)
    ns.SettingsPanel:Open()
    ns.SettingsPanel.window:Select("advanced")
    return page(ns)
end

-- The page's rows by their names.
local function row(ns, label)
    for _, c in ipairs(page(ns).controls) do
        if c.name() == label then return c end
    end
    error("no row " .. label)
end

local function labels(ns)
    local list = {}
    for _, c in ipairs(page(ns).controls) do list[#list + 1] = c.name() end
    return list
end

local function listed(ns)
    local window = ns.SettingsPanel.window
    local names = {}
    for _, key in ipairs(window.order) do names[#names + 1] = window.buttons[key].label:GetText() end
    return names
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end

describe("advanced settings page", function()
    it("is called Advanced settings and is last in the window's list", function()
        local ns = start()
        local names = listed(ns)
        T.eq(names[#names], "Advanced settings")
        T.eq(page(ns).title, "Advanced settings")
    end)

    it("says what these settings are above them, then puts the Graphics section's rows across the page", function()
        local ns = start()
        local p = page(ns)
        T.eq(#p.texts, 1)
        T.eq(p.texts[1].column, "wide")
        local intro = p.texts[1].text
        for _, words in ipairs({ "options don't show", "The game keeps them", "graphics settings can set",
            "Raid and Battleground graphics" }) do
            T.truthy(intro:find(words, 1, true), "the intro says " .. words)
        end
        T.eq(#p.headers, 2)
        T.same({ p.headers[1].column, p.headers[1].text }, { "wide", "Graphics" })
        T.same({ p.headers[2].column, p.headers[2].text }, { "wide", "Camera" })
        T.same(labels(ns), { "Ground clutter distance", "Ground clutter fade", "Ground clutter density",
            "Weather density", "Always sharpen", "Max camera distance" })
        local kinds = {}
        for _, c in ipairs(p.controls) do
            T.eq(c.column, "wide", c.name())
            kinds[#kinds + 1] = c.kind
        end
        T.same(kinds, { "slider", "slider", "slider", "slider", "checkbox", "slider" })
        T.truthy(p:Height() <= ns.SettingsPage.MAX_HEIGHT, "fits without scrolling")
    end)

    it("puts a setting back to its game default with its Reset button, greyed out while it's there", function()
        local ns, state = start()
        show(ns)
        local distance = row(ns, "Ground clutter distance")
        T.eq(distance.resetButton:GetText(), "Reset")
        T.falsy(distance.resetButton:IsEnabled(), "greyed out at the default")
        distance.widget.Forward:Click()
        T.eq(state.cvars.groundEffectDist, "71")
        T.truthy(distance.resetButton:IsEnabled(), "away from the default")
        distance.resetButton:Click()
        T.eq(state.cvars.groundEffectDist, "70")
        T.eq(distance.widget:GetValue(), 70)
        T.eq(distance.box:GetText(), "70")
        T.falsy(distance.resetButton:IsEnabled())

        local sharpen = row(ns, "Always sharpen")
        T.falsy(sharpen.resetButton:IsEnabled())
        sharpen.widget:Click()
        T.eq(state.cvars.ResampleAlwaysSharpen, "1")
        T.truthy(sharpen.resetButton:IsEnabled())
        sharpen.resetButton:Click()
        T.eq(state.cvars.ResampleAlwaysSharpen, "0")
        T.falsy(sharpen.widget:GetChecked())
        T.falsy(sharpen.resetButton:IsEnabled())
    end)

    it("shows what the game kept after a Reset", function()
        local ns, state = start()
        show(ns)
        local density = row(ns, "Ground clutter density")
        density.widget.Forward:Click()
        -- A default the game itself refuses.
        state.cvarDefaults.groundEffectDensity = "1000"
        density.resetButton:Click()
        T.eq(state.cvars.groundEffectDensity, "17")
        T.eq(density.box:GetText(), "17")
    end)

    it("counts a value equal to the game default but formatted differently as at the default", function()
        local ns, state = start(function(s)
            s.cvars.groundEffectDist = "70.000000"
            s.cvarDefaults.weatherDensity = "2.0"
        end)
        show(ns)
        T.falsy(row(ns, "Ground clutter distance").resetButton:IsEnabled())
        T.falsy(row(ns, "Weather density").resetButton:IsEnabled())
        state.cvars.groundEffectFade = "70.5"
        page(ns):Refresh()
        T.truthy(row(ns, "Ground clutter fade").resetButton:IsEnabled())
    end)

    it("takes the game default from GetCVarInfo on a client without GetCVarDefault", function()
        local ns, state = start(function() C_CVar.GetCVarDefault = nil end)
        show(ns)
        local distance = row(ns, "Ground clutter distance")
        distance.widget.Forward:Click()
        T.truthy(distance.resetButton:IsEnabled())
        distance.resetButton:Click()
        T.eq(state.cvars.groundEffectDist, "70")
    end)

    it("says the game default on Reset's tooltip, and that the game's own settings may set another", function()
        local ns, state = start(function(s) s.cvarDefaults.groundEffectDist = "100" end)
        show(ns)
        local reset = row(ns, "Ground clutter distance").resetButton
        reset:RunScript("OnEnter")
        T.eq(GameTooltip.lines[1].text, "Reset")
        local tip = GameTooltip.lines[2].text
        T.truthy(tip:find("Back to the game default: 100", 1, true), tip)
        T.truthy(tip:find("own settings may set", 1, true), tip)
        reset:RunScript("OnLeave")
        state.cvars.ResampleAlwaysSharpen = "1"
        row(ns, "Always sharpen").resetButton:RunScript("OnEnter")
        T.truthy(GameTooltip.lines[2].text:find("Back to the game default: Off", 1, true))
    end)

    it("ends each row's tooltip with its game default, from the game", function()
        local ns = start(function(s)
            s.cvarDefaults.groundEffectFade = "1.900000"
            s.cvarDefaults.ResampleAlwaysSharpen = "1"
        end)
        show(ns)
        local expected = {
            ["Ground clutter distance"] = "Game default: 70",
            ["Ground clutter fade"] = "Game default: 1.9",
            ["Ground clutter density"] = "Game default: 16",
            ["Weather density"] = "Game default: 2",
            ["Always sharpen"] = "Game default: On",
        }
        for label, ending in pairs(expected) do
            local c = row(ns, label)
            c.row:RunScript("OnEnter")
            local tip = GameTooltip.lines[2].text
            T.eq(tip:sub(-#ending), ending, label)
            c.row:RunScript("OnLeave")
        end
    end)

    it("sets every row back to its game default after the Defaults button's second click", function()
        local ns, state = start()
        local p = show(ns)
        for _, c in ipairs(p.controls) do
            if c.kind == "slider" then c.widget.Forward:Click() else c.widget:Click() end
        end
        local changed = copy(state.cvars)
        local button = p.defaultsButton
        button:Click()
        T.eq(button:GetText(), "Sure?")
        T.same(state.cvars, changed, "nothing after one click")
        button:Click()
        T.eq(state.cvars.groundEffectDist, "70")
        T.eq(state.cvars.groundEffectFade, "70")
        T.eq(state.cvars.groundEffectDensity, "16")
        T.eq(state.cvars.weatherDensity, "2")
        T.eq(state.cvars.ResampleAlwaysSharpen, "0")
        for _, c in ipairs(p.controls) do T.falsy(c.resetButton:IsEnabled(), c.name()) end
        T.eq(state.cvars.RAIDgroundEffectDist, "70", "the raid copies stay alone")
    end)

    it("covers exactly each setting's range with its slider, one step per arrow, its value in a box next to it", function()
        local ns, state = start()
        show(ns)
        local ranges = {
            ["Ground clutter distance"] = { 40, 500 }, ["Ground clutter fade"] = { 40, 500 },
            ["Ground clutter density"] = { 16, 256 }, ["Weather density"] = { 0, 3 },
        }
        for label, range in pairs(ranges) do
            local c = row(ns, label)
            T.same({ c.widget.minValue, c.widget.maxValue, c.widget.step }, { range[1], range[2], 1 }, label)
        end
        local camera = row(ns, "Max camera distance")
        T.same({ camera.widget.minValue, camera.widget.maxValue }, { 1, 2.6 })
        T.truthy(math.abs(camera.widget.step - 0.1) < 1e-9, "Max camera distance steps 0.1")
        local c = row(ns, "Ground clutter density")
        T.eq(c.widget:GetValue(), 16)
        T.eq(c.box.template, "InputBoxTemplate")
        T.eq(c.box:GetText(), "16")
        T.eq(c.widget.RightText:GetText(), nil, "the box instead of the slider's value text")
        c.widget.Forward:Click()
        T.eq(state.cvars.groundEffectDensity, "17")
        T.eq(c.box:GetText(), "17")
        c.widget:SetValue(120.4)
        T.eq(state.cvars.groundEffectDensity, "120")
        T.eq(c.box:GetText(), "120")
        c.widget.Back:Click()
        T.eq(state.cvars.groundEffectDensity, "119")
    end)

    it("steps the camera distance by 0.1 with its arrows and slider, never drifting off one decimal", function()
        local ns, state = start()
        show(ns)
        local c = row(ns, "Max camera distance")
        T.eq(c.box:GetText(), "1.9")
        c.widget.Forward:Click()
        T.eq(tonumber(state.cvars.cameraDistanceMaxZoomFactor), 2)
        T.eq(c.box:GetText(), "2.0")
        for _ = 1, 10 do c.widget.Forward:Click() end
        T.eq(state.cvars.cameraDistanceMaxZoomFactor, "2.6", "stops at the end")
        T.eq(c.box:GetText(), "2.6")
        for _ = 1, 7 do c.widget.Back:Click() end
        T.eq(state.cvars.cameraDistanceMaxZoomFactor, "1.9")
        c.widget:SetValue(2.3400000001)
        T.eq(state.cvars.cameraDistanceMaxZoomFactor, "2.3")
        T.eq(c.box:GetText(), "2.3")
        c.resetButton:Click()
        T.eq(state.cvars.cameraDistanceMaxZoomFactor, "1.9", "Reset puts back the game default")
        T.eq(c.box:GetText(), "1.9")
        T.falsy(c.resetButton:IsEnabled())
        for _, set in ipairs(state.cvarSets) do
            T.truthy(set:match("^cameraDistanceMaxZoomFactor=%d$") or set:match("^cameraDistanceMaxZoomFactor=%d%.%d$"),
                set .. " has at most one decimal")
        end
    end)

    it("shows the camera distance's box with one decimal, rounding a typed number to it and into range", function()
        local ns, state = start(function(s) s.cvars.cameraDistanceMaxZoomFactor = "1.900000" end)
        show(ns)
        local c = row(ns, "Max camera distance")
        T.eq(c.box:GetText(), "1.9", "the game's trailing zeros left out")
        for _, case in ipairs({ { "2.37", 2.4, "2.4" }, { "9", 2.6, "2.6" }, { "0.2", 1, "1.0" },
            { "-3", 1, "1.0" }, { "2.05", 2.1, "2.1" }, { "1.5", 1.5, "1.5" } }) do
            Stubs.Type(c.box, case[1])
            c.box:RunScript("OnEnterPressed")
            T.eq(tonumber(state.cvars.cameraDistanceMaxZoomFactor), case[2], case[1])
            T.eq(c.box:GetText(), case[3], case[1])
            T.eq(c.widget:GetValue(), case[2], case[1])
        end
    end)

    it("sets a value typed into the box once it loses the keyboard, put back on Escape", function()
        local ns, state = start()
        show(ns)
        local c = row(ns, "Ground clutter distance")
        Stubs.Type(c.box, " 200 ")
        T.same(state.cvarSets, {}, "not while typing")
        c.box:RunScript("OnEnterPressed")
        T.falsy(c.box:HasFocus())
        T.same(state.cvarSets, { "groundEffectDist=200" })
        T.eq(c.widget:GetValue(), 200)
        T.eq(c.box:GetText(), "200")
        Stubs.Type(c.box, "300")
        c.box:RunScript("OnEscapePressed")
        T.eq(c.box:GetText(), "200")
        T.same(state.cvarSets, { "groundEffectDist=200" })
        -- A click elsewhere sets it too.
        Stubs.Type(c.box, "250")
        c.box:ClearFocus()
        T.eq(state.cvars.groundEffectDist, "250")
        T.eq(c.widget:GetValue(), 250)
    end)

    it("sets a typed value with Tab and goes on to the next box, back with Shift+Tab", function()
        local ns, state = start()
        show(ns)
        local distance, fade, density = row(ns, "Ground clutter distance").box, row(ns, "Ground clutter fade").box,
            row(ns, "Ground clutter density").box
        Stubs.Type(distance, "123")
        distance:RunScript("OnTabPressed")
        T.eq(state.cvars.groundEffectDist, "123")
        T.truthy(fade:HasFocus())
        fade:RunScript("OnTabPressed")
        T.truthy(density:HasFocus())
        state.shift = true
        density:RunScript("OnTabPressed")
        state.shift = false
        T.truthy(fade:HasFocus())
        T.same(state.cvarSets, { "groundEffectDist=123" }, "an unchanged box sets nothing")
        fade:ClearFocus()
    end)

    it("sets a typed number out of range to the nearest end, rounded to the step, and nothing for other text", function()
        local ns, state = start()
        show(ns)
        local c = row(ns, "Weather density")
        for _, case in ipairs({ { "2.6", "3" }, { "1.4", "1" }, { "9", "3" }, { "-5", "0" } }) do
            Stubs.Type(c.box, case[1])
            c.box:RunScript("OnEnterPressed")
            T.eq(state.cvars.weatherDensity, case[2], case[1])
            T.eq(c.box:GetText(), case[2], case[1])
            T.eq(c.widget:GetValue(), tonumber(case[2]), case[1])
        end
        local sets = #state.cvarSets
        for _, text in ipairs({ "0.3", "lots", "", " " }) do
            Stubs.Type(c.box, text)
            c.box:RunScript("OnEnterPressed")
            T.eq(c.box:GetText(), "0", "puts back the value for '" .. text .. "'")
        end
        T.eq(#state.cvarSets, sets, "nothing reaches the game, nor a number that rounds to the value")
    end)

    it("shows what the game kept of a typed value, in the box and on the slider", function()
        local ns, state = start()
        show(ns)
        local c = row(ns, "Ground clutter distance")
        state.cvarRanges.groundEffectDist = { 40, 300 }
        Stubs.Type(c.box, "400")
        c.box:RunScript("OnEnterPressed")
        T.same(state.cvarSets, { "groundEffectDist=400" })
        T.eq(c.box:GetText(), "70")
        T.eq(c.widget:GetValue(), 70)
    end)

    it("leaves a box alone while it has the keyboard when the page refreshes", function()
        local ns, state = start()
        show(ns)
        local fade, density = row(ns, "Ground clutter fade"), row(ns, "Ground clutter density")
        Stubs.Type(fade.box, "12")
        state.cvars.groundEffectFade, state.cvars.groundEffectDensity = "250", "64"
        Stubs.Fire("CVAR_UPDATE", "groundEffectFade", "250")
        T.eq(fade.box:GetText(), "12")
        T.eq(fade.widget:GetValue(), 250)
        T.eq(density.box:GetText(), "64")
        ns.SettingsPanel.window.frame:Hide()
        show(ns)
        T.eq(fade.box:GetText(), "12", "on showing too")
        fade.box:RunScript("OnEscapePressed")
        T.eq(fade.box:GetText(), "250")
        T.same(state.cvarSets, {})
    end)

    it("writes 1 and 0 for the checkbox", function()
        local ns, state = start()
        show(ns)
        local c = row(ns, "Always sharpen")
        T.falsy(c.widget:GetChecked())
        c.widget:Click()
        T.eq(state.cvars.ResampleAlwaysSharpen, "1")
        T.truthy(c.widget:GetChecked())
        c.widget:Click()
        T.eq(state.cvars.ResampleAlwaysSharpen, "0")
        T.same(state.cvarSets, { "ResampleAlwaysSharpen=1", "ResampleAlwaysSharpen=0" })
    end)

    it("sets a change at once, in combat too", function()
        local ns, state = start()
        show(ns)
        Stubs.SetCombat(true)
        row(ns, "Weather density").widget.Back:Click()
        T.eq(state.cvars.weatherDensity, "1", "not deferred")
        Stubs.SetCombat(false)
    end)

    -- Weather density as a setting the game won't change in combat.
    local function protectWeather(state) state.cvarSecure.weatherDensity = true end

    local function greyedOut(c)
        return c.text.textColor[1] == 0.5 and not c.widget:IsEnabled() and not c.box:IsEnabled()
            and not c.resetButton:IsEnabled()
    end

    it("greys out a row the game protects in combat until combat ends, the others still set at once", function()
        local ns, state = start(protectWeather)
        show(ns)
        local weather, distance = row(ns, "Weather density"), row(ns, "Ground clutter distance")
        weather.widget.Back:Click()
        T.eq(state.cvars.weatherDensity, "1", "out of combat it sets")
        T.falsy(greyedOut(weather))
        -- As the game: InCombatLockdown is still false while it sends this.
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.SetCombat(true)
        T.truthy(greyedOut(weather), "greyed out in combat")
        T.same({ weather.widget:GetValue(), weather.box:GetText() }, { 1, "1" }, "still shows its value")
        T.truthy(distance.widget:IsEnabled(), "a row the game doesn't protect")
        distance.widget.Forward:Click()
        T.eq(state.cvars.groundEffectDist, "71", "sets at once in combat")
        Stubs.SetCombat(false)
        T.falsy(greyedOut(weather), "back after combat")
        T.eq(weather.text.textColor[1], 1)
        weather.resetButton:Click()
        T.eq(state.cvars.weatherDensity, "2")
    end)

    it("writes nothing for a protected row's box typed into as combat starts", function()
        local ns, state = start(protectWeather)
        show(ns)
        local weather = row(ns, "Weather density")
        Stubs.Type(weather.box, "3")
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.SetCombat(true)
        weather.box:ClearFocus()
        T.same(state.cvarSets, {})
        T.eq(weather.box:GetText(), "2", "shows what the game has")
        Stubs.SetCombat(false)
    end)

    it("greys out a protected row when shown in combat, and its checkbox too", function()
        local ns = start(function(state) state.cvarSecure.ResampleAlwaysSharpen = true end)
        Stubs.SetCombat(true)
        show(ns)
        local sharpen = row(ns, "Always sharpen")
        T.falsy(sharpen.widget:IsEnabled())
        T.falsy(sharpen.resetButton:IsEnabled())
        T.eq(sharpen.text.textColor[1], 0.5)
        Stubs.SetCombat(false)
        T.truthy(sharpen.widget:IsEnabled())
    end)

    it("leaves a protected row alone with Defaults in combat, putting the others back", function()
        local ns, state = start(protectWeather)
        local p = show(ns)
        row(ns, "Weather density").widget.Back:Click()
        row(ns, "Ground clutter distance").widget.Forward:Click()
        -- As the game: InCombatLockdown is still false while it sends this.
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.SetCombat(true)
        state.cvarSets = {}
        p.defaultsButton:Click()
        p.defaultsButton:Click()
        T.eq(state.cvars.groundEffectDist, "70")
        T.eq(state.cvars.weatherDensity, "1", "left alone")
        for _, set in ipairs(state.cvarSets) do T.falsy(set:find("weatherDensity", 1, true), "never tried") end
        Stubs.SetCombat(false)
    end)

    it("refreshes for combat only while it's shown", function()
        local ns, state = start(protectWeather)
        show(ns)
        ns.SettingsPanel.window.frame:Hide()
        local reads = state.cvarReads
        -- As the game: InCombatLockdown is still false while it sends this.
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.SetCombat(true)
        Stubs.SetCombat(false)
        T.eq(state.cvarReads, reads)
    end)

    it("shows what the game kept after each change, the old value when it refused", function()
        local ns, state = start()
        show(ns)
        local c = row(ns, "Ground clutter distance")
        -- A client that takes less than the slider offers.
        state.cvarRanges.groundEffectDist = { 40, 300 }
        c.widget:SetValue(400)
        T.same(state.cvarSets, { "groundEffectDist=400" })
        T.eq(state.cvars.groundEffectDist, "70")
        T.eq(c.widget:GetValue(), 70)
        T.eq(c.box:GetText(), "70")
        T.same(state.cvarSets, { "groundEffectDist=400" }, "the old value isn't written back")
    end)

    it("reads the game's values each time it's shown", function()
        local ns, state = start()
        show(ns)
        ns.SettingsPanel.window.frame:Hide()
        state.cvars.weatherDensity, state.cvars.ResampleAlwaysSharpen = "3", "1"
        show(ns)
        T.eq(row(ns, "Weather density").widget:GetValue(), 3)
        T.truthy(row(ns, "Always sharpen").widget:GetChecked())
    end)

    it("follows a change made elsewhere while it's shown, without writing it back", function()
        local ns, state = start()
        show(ns)
        state.cvars.groundEffectFade = "250"
        Stubs.Fire("CVAR_UPDATE", "groundEffectFade", "250")
        T.eq(row(ns, "Ground clutter fade").widget:GetValue(), 250)
        T.eq(row(ns, "Ground clutter fade").box:GetText(), "250")
        T.same(state.cvarSets, {})
    end)

    it("reads nothing for a change while it's hidden, or for a setting not on it", function()
        local ns, state = start()
        show(ns)
        local reads = state.cvarReads
        Stubs.Fire("CVAR_UPDATE", "chatClassColorOverride", "0")
        T.eq(state.cvarReads, reads, "not a hidden setting")
        ns.SettingsPanel.window.frame:Hide()
        Stubs.Fire("CVAR_UPDATE", "groundEffectFade", "250")
        T.eq(state.cvarReads, reads, "hidden")
    end)

    it("leaves out a row whose setting the client doesn't know", function()
        local ns = start(function(state) state.cvars.weatherDensity = nil end)
        T.same(labels(ns), { "Ground clutter distance", "Ground clutter fade", "Ground clutter density",
            "Always sharpen", "Max camera distance" })
    end)

    it("leaves the page out of the list on a client that knows none of the settings", function()
        local ns = start(function(state)
            for _, cvar in ipairs({ "groundEffectDist", "groundEffectFade", "groundEffectDensity", "weatherDensity",
                "ResampleAlwaysSharpen", "cameraDistanceMaxZoomFactor" }) do
                state.cvars[cvar] = nil
            end
        end)
        T.eq(page(ns), nil)
        for _, name in ipairs(listed(ns)) do T.truthy(name ~= "Advanced settings", "no Advanced settings page") end
    end)

    it("writes no setting at login and saves nothing for them", function()
        local ns, state = start()
        T.same(state.cvarSets, {})
        local saved = copy(QoLDB)
        show(ns)
        row(ns, "Ground clutter distance").widget.Forward:Click()
        row(ns, "Always sharpen").widget:Click()
        T.same(QoLDB, saved)
    end)

    it("never writes the raid copies", function()
        local ns, state = start()
        show(ns)
        for _, c in ipairs(page(ns).controls) do
            if c.kind == "slider" then c.widget.Forward:Click() else c.widget:Click() end
        end
        T.eq(#state.cvarSets, 6)
        for _, set in ipairs(state.cvarSets) do T.falsy(set:find("^RAID"), set) end
        T.eq(state.cvars.RAIDgroundEffectDist, "70")
    end)

    it("says what each setting does when pointed at", function()
        local ns = start()
        show(ns)
        local tips = {
            ["Ground clutter distance"] = { "how far away", "in yards", "frame rate" },
            ["Ground clutter fade"] = { "how softly", "fades in" },
            ["Ground clutter density"] = { "how thick", "frame rate" },
            ["Weather density"] = { "rain and snow", "0 (least)", "3 (most)" },
            ["Always sharpen"] = { "isn't upscaling", "Resample Sharpness" },
            ["Max camera distance"] = { "zoom out", "Max Camera Distance slider", "2.0" },
        }
        for label, words in pairs(tips) do
            local c = row(ns, label)
            c.row:RunScript("OnEnter")
            T.eq(GameTooltip.lines[1].text, label)
            for _, word in ipairs(words) do
                T.truthy(GameTooltip.lines[2].text:lower():find(word:lower(), 1, true), label .. " says " .. word)
            end
            c.row:RunScript("OnLeave")
        end
    end)
end)
