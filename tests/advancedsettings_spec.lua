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

    it("says what these settings are above them, then puts each section's rows across the page", function()
        local ns = start()
        local p = page(ns)
        T.eq(#p.texts, 1)
        T.eq(p.texts[1].column, "wide")
        local intro = p.texts[1].text
        for _, words in ipairs({ "options don't show", "The game keeps them", "graphics settings can set",
            "Raid and Battleground graphics" }) do
            T.truthy(intro:find(words, 1, true), "the intro says " .. words)
        end
        local headers = {}
        for _, header in ipairs(p.headers) do
            T.eq(header.column, "wide", header.text)
            headers[#headers + 1] = header.text
        end
        T.same(headers, { "Graphics", "Draw distance", "Camera" })
        T.same(labels(ns), { "Ground clutter distance", "Ground clutter fade", "Ground clutter density",
            "Weather density", "Always sharpen", "World distance", "Horizon start", "Horizon end",
            "Object fade scale", "Object cull size", "Object cull distance", "Max camera distance" })
        local kinds = {}
        for _, c in ipairs(p.controls) do
            T.eq(c.column, "wide", c.name())
            kinds[#kinds + 1] = c.kind
        end
        T.same(kinds, { "slider", "slider", "slider", "slider", "checkbox", "slider", "slider", "slider", "slider",
            "slider", "slider", "slider" })
        T.truthy(p:Height() <= ns.SettingsPage.MAX_HEIGHT, "fits without scrolling: " .. p:Height())
    end)

    it("puts a setting back to its game default with its Reset button, greyed out while it's there", function()
        local ns, state = start()
        show(ns)
        local fade = row(ns, "Ground clutter fade")
        T.eq(fade.resetButton:GetText(), "Reset")
        T.falsy(fade.resetButton:IsEnabled(), "greyed out at the default")
        fade.widget.Forward:Click()
        T.eq(state.cvars.groundEffectFade, "71")
        T.truthy(fade.resetButton:IsEnabled(), "away from the default")
        fade.resetButton:Click()
        T.eq(state.cvars.groundEffectFade, "70")
        T.eq(fade.widget:GetValue(), 70)
        T.eq(fade.box:GetText(), "70")
        T.falsy(fade.resetButton:IsEnabled())

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

    it("puts a row a game slider writes back to what that slider sets, with the slider's other rows", function()
        -- View Distance at step 10, where it sets 10000 and 4000.
        local ns, state = start(function(s) s.cvars.farclip, s.cvars.horizonStart, s.cvars.horizonClip,
            s.cvars.graphicsViewDistance = "10000", "4000", "10000", "9" end)
        show(ns)
        local world, horizonStart, horizonEnd = row(ns, "World distance"), row(ns, "Horizon start"),
            row(ns, "Horizon end")
        T.truthy(world.resetButton:IsEnabled(), "never greyed out, at what the slider sets too")
        world.widget.Back:Click()
        horizonStart.widget.Back:Click()
        horizonEnd.widget.Back:Click()
        row(ns, "Object cull distance").widget.Forward:Click()
        state.cvarSets = {}
        world.resetButton:Click()
        T.same(state.cvarSets, { "graphicsViewDistance=9" })
        T.same({ state.cvars.farclip, state.cvars.horizonStart, state.cvars.horizonClip }, { "10000", "4000", "10000" })
        T.same({ world.box:GetText(), horizonStart.box:GetText(), horizonEnd.box:GetText() },
            { "10000", "4000", "10000" })
        T.eq(state.cvars.lodObjectCullDist, "31", "a row no game slider writes stays")
        T.truthy(world.resetButton:IsEnabled(), "still not greyed out")

        local fade, size = row(ns, "Object fade scale"), row(ns, "Object cull size")
        fade.widget:SetValue(200)
        size.widget.Back:Click()
        state.cvarSets = {}
        fade.resetButton:Click()
        T.same(state.cvarSets, { "graphicsEnvironmentDetail=4" })
        T.same({ state.cvars.lodObjectFadeScale, state.cvars.lodObjectCullSize }, { "90", "20" })
        T.same({ fade.box:GetText(), size.box:GetText() }, { "90", "20" })
        T.eq(state.cvars.farclip, "10000", "another game slider's rows stay")

        local distance, density, fadeIn = row(ns, "Ground clutter distance"), row(ns, "Ground clutter density"),
            row(ns, "Ground clutter fade")
        distance.widget.Forward:Click()
        density.widget.Forward:Click()
        fadeIn.widget.Forward:Click()
        state.cvarSets = {}
        density.resetButton:Click()
        T.same(state.cvarSets, { "graphicsGroundClutter=2" })
        T.same({ state.cvars.groundEffectDist, state.cvars.groundEffectDensity }, { "70", "16" })
        T.eq(state.cvars.groundEffectFade, "71", "Ground Clutter doesn't set the fade")
    end)

    it("shows what the game kept after a Reset", function()
        local ns, state = start()
        show(ns)
        local cull = row(ns, "Object cull distance")
        cull.widget.Forward:Click()
        -- A default the game itself refuses.
        state.cvarDefaults.lodObjectCullDist = "1000"
        cull.resetButton:Click()
        T.eq(state.cvars.lodObjectCullDist, "31")
        T.eq(cull.box:GetText(), "31")
    end)

    it("counts a value equal to the game default but formatted differently as at the default", function()
        local ns, state = start(function(s)
            s.cvars.groundEffectFade = "70.000000"
            s.cvarDefaults.weatherDensity = "2.0"
        end)
        show(ns)
        T.falsy(row(ns, "Ground clutter fade").resetButton:IsEnabled())
        T.falsy(row(ns, "Weather density").resetButton:IsEnabled())
        state.cvars.lodObjectCullDist = "30.5"
        page(ns):Refresh()
        T.truthy(row(ns, "Object cull distance").resetButton:IsEnabled())
    end)

    it("takes the game default from GetCVarInfo on a client without GetCVarDefault", function()
        local ns, state = start(function() C_CVar.GetCVarDefault = nil end)
        show(ns)
        local fade = row(ns, "Ground clutter fade")
        fade.widget.Forward:Click()
        T.truthy(fade.resetButton:IsEnabled())
        fade.resetButton:Click()
        T.eq(state.cvars.groundEffectFade, "70")
    end)

    it("says the game default on Reset's tooltip, and that the game's own settings may set another", function()
        local ns, state = start(function(s) s.cvarDefaults.groundEffectFade = "100" end)
        show(ns)
        local reset = row(ns, "Ground clutter fade").resetButton
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
            ["Ground clutter fade"] = "Game default: 1.9",
            ["Weather density"] = "Game default: 2",
            ["Always sharpen"] = "Game default: On",
            ["Object cull distance"] = "Game default: 30",
            ["Max camera distance"] = "Game default: 1.9",
        }
        for label, ending in pairs(expected) do
            local c = row(ns, label)
            c.row:RunScript("OnEnter")
            local tip = GameTooltip.lines[2].text
            T.eq(tip:sub(-#ending), ending, label)
            c.row:RunScript("OnLeave")
        end
    end)

    it("says on Reset's tooltip which game slider's values it puts back and which rows it resets too", function()
        local ns = start()
        show(ns)
        local resets = {
            ["Ground clutter distance"] = "Back to what the game's Ground Clutter sets. Also resets Ground clutter density.",
            ["Ground clutter density"] = "Back to what the game's Ground Clutter sets. Also resets Ground clutter distance.",
            ["World distance"] = "Back to what the game's View Distance sets. Also resets Horizon start and Horizon end.",
            ["Horizon start"] = "Back to what the game's View Distance sets. Also resets World distance and Horizon end.",
            ["Horizon end"] = "Back to what the game's View Distance sets. Also resets World distance and Horizon start.",
            ["Object fade scale"] = "Back to what the game's Environment Detail sets. Also resets Object cull size.",
            ["Object cull size"] = "Back to what the game's Environment Detail sets. Also resets Object fade scale.",
        }
        for label, text in pairs(resets) do
            local c = row(ns, label)
            c.resetButton:RunScript("OnEnter")
            T.eq(GameTooltip.lines[2].text, text, label)
            c.resetButton:RunScript("OnLeave")
            c.row:RunScript("OnEnter")
            local tip = GameTooltip.lines[2].text
            T.falsy(tip:find("Game default", 1, true), label .. " leaves out the game default: " .. tip)
            c.row:RunScript("OnLeave")
        end
        local cull = row(ns, "Object cull distance")
        cull.row:RunScript("OnEnter")
        T.eq(GameTooltip.lines[2].text:sub(-#"Game default: 30"), "Game default: 30")
        cull.row:RunScript("OnLeave")
        cull.resetButton:RunScript("OnEnter")
        T.truthy(GameTooltip.lines[2].text:find("Back to the game default: 30", 1, true), GameTooltip.lines[2].text)
    end)

    it("names on Reset's tooltip only the rows this client has", function()
        local ns = start(function(state) state.cvars.horizonClip = nil end)
        show(ns)
        row(ns, "World distance").resetButton:RunScript("OnEnter")
        T.eq(GameTooltip.lines[2].text, "Back to what the game's View Distance sets. Also resets Horizon start.")
    end)

    it("sets every row back after the Defaults button's second click, writing each game slider once", function()
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
        state.cvarSets = {}
        button:Click()
        T.eq(state.cvars.groundEffectDist, "70")
        T.eq(state.cvars.groundEffectFade, "70")
        T.eq(state.cvars.groundEffectDensity, "16")
        T.eq(state.cvars.weatherDensity, "2")
        T.eq(state.cvars.ResampleAlwaysSharpen, "0")
        T.same({ state.cvars.farclip, state.cvars.horizonStart, state.cvars.horizonClip }, { "6000", "1400", "6000" },
            "what View Distance sets")
        T.same({ state.cvars.lodObjectFadeScale, state.cvars.lodObjectCullSize }, { "90", "20" },
            "what Environment Detail sets")
        T.eq(state.cvars.lodObjectCullDist, "30")
        T.eq(state.cvars.cameraDistanceMaxZoomFactor, "1.9")
        local written = {}
        for _, set in ipairs(state.cvarSets) do
            local cvar = set:match("^[^=]+")
            if cvar:find("^graphics") then written[cvar] = (written[cvar] or 0) + 1 end
        end
        T.same(written, { graphicsViewDistance = 1, graphicsEnvironmentDetail = 1, graphicsGroundClutter = 1 },
            "each game slider once")
        -- The rows a game slider writes keep their Reset; the others are at their game default.
        local bySlider = { ["Ground clutter distance"] = true, ["Ground clutter density"] = true,
            ["World distance"] = true, ["Horizon start"] = true, ["Horizon end"] = true,
            ["Object fade scale"] = true, ["Object cull size"] = true }
        for _, c in ipairs(p.controls) do T.eq(c.resetButton:IsEnabled(), bySlider[c.name()] == true, c.name()) end
        T.eq(state.cvars.RAIDgroundEffectDist, "70", "the raid copies stay alone")
        T.eq(state.cvars.RAIDfarclip, "6000")
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

    it("covers each Draw distance setting's range in its steps, setting a change at once", function()
        local ns, state = start()
        show(ns)
        local ranges = {
            ["World distance"] = { 1000, 10000, 100 }, ["Horizon start"] = { 400, 4000, 100 },
            ["Horizon end"] = { 1500, 10000, 100 }, ["Object fade scale"] = { 50, 5000, 10 },
            ["Object cull size"] = { 1, 100, 1 }, ["Object cull distance"] = { 1, 200, 1 },
        }
        for label, range in pairs(ranges) do
            local c = row(ns, label)
            T.same({ c.widget.minValue, c.widget.maxValue, c.widget.step }, range, label)
            T.eq(c.box.template, "InputBoxTemplate", label)
        end
        local world = row(ns, "World distance")
        T.eq(world.box:GetText(), "6000")
        world.widget.Forward:Click()
        T.same(state.cvarSets, { "farclip=6100" })
        T.eq(world.box:GetText(), "6100")
        Stubs.Type(world.box, "5000")
        world.box:RunScript("OnEnterPressed")
        T.eq(state.cvars.farclip, "5000")
        local fade = row(ns, "Object fade scale")
        fade.widget:SetValue(203)
        T.eq(state.cvars.lodObjectFadeScale, "200", "rounded to its step")
        T.eq(fade.box:GetText(), "200")
        T.eq(state.cvars.horizonClip, "6000", "the game slider's other settings stay")
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

    it("greys out in combat the rows whose game slider the game protects, until combat ends", function()
        local ns, state = start(function(s) s.cvarSecure.graphicsViewDistance = true end)
        local p = show(ns)
        local world, fade = row(ns, "World distance"), row(ns, "Object fade scale")
        world.widget.Forward:Click()
        -- As the game: InCombatLockdown is still false while it sends this.
        Stubs.Fire("PLAYER_REGEN_DISABLED")
        Stubs.SetCombat(true)
        for _, label in ipairs({ "World distance", "Horizon start", "Horizon end" }) do
            T.truthy(greyedOut(row(ns, label)), label)
        end
        T.falsy(greyedOut(fade), "another game slider's row")
        fade.widget.Forward:Click()
        T.eq(state.cvars.lodObjectFadeScale, "100", "sets at once in combat")
        state.cvarSets = {}
        p.defaultsButton:Click()
        p.defaultsButton:Click()
        for _, set in ipairs(state.cvarSets) do T.falsy(set:find("graphicsViewDistance", 1, true), set) end
        T.eq(state.cvars.farclip, "6100", "left alone")
        Stubs.SetCombat(false)
        T.falsy(greyedOut(world), "back after combat")
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
        local ns = start(function(state) state.cvars.weatherDensity, state.cvars.lodObjectCullDist = nil, nil end)
        T.same(labels(ns), { "Ground clutter distance", "Ground clutter fade", "Ground clutter density",
            "Always sharpen", "World distance", "Horizon start", "Horizon end", "Object fade scale",
            "Object cull size", "Max camera distance" })
    end)

    it("leaves the page out of the list on a client that knows none of the settings", function()
        local ns = start(function(state)
            for _, cvar in ipairs({ "groundEffectDist", "groundEffectFade", "groundEffectDensity", "weatherDensity",
                "ResampleAlwaysSharpen", "farclip", "horizonStart", "horizonClip", "lodObjectFadeScale",
                "lodObjectCullSize", "lodObjectCullDist", "cameraDistanceMaxZoomFactor" }) do
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
        T.eq(#state.cvarSets, 12)
        for _, set in ipairs(state.cvarSets) do T.falsy(set:find("^RAID"), set) end
        T.eq(state.cvars.RAIDgroundEffectDist, "70")
        T.eq(state.cvars.RAIDfarclip, "6000")
    end)

    it("says what each setting does when pointed at", function()
        local ns = start()
        show(ns)
        local tips = {
            ["Ground clutter distance"] = { "how far away", "in yards", "frame rate",
                "Ground Clutter sets 40 to 320", "sets it again when you move it" },
            ["Ground clutter fade"] = { "how softly", "fades in" },
            ["Ground clutter density"] = { "how thick", "frame rate", "Ground Clutter sets 16 to 256",
                "sets it again when you move it" },
            ["Weather density"] = { "rain and snow", "0 (least)", "3 (most)" },
            ["Always sharpen"] = { "isn't upscaling", "Resample Sharpness" },
            ["World distance"] = { "how far away the world is drawn", "in yards", "higher costs frame rate",
                "View Distance sets 1500 to 10000", "sets it again when you move it" },
            ["Horizon start"] = { "horizon begins", "in yards", "View Distance sets 400 to 4000",
                "sets it again when you move it" },
            ["Horizon end"] = { "horizon ends", "keeps it equal to World distance", "sets it again when you move it" },
            ["Object fade scale"] = { "fade out", "higher keeps them longer", "frame rate",
                "Environment Detail sets 50 to 150", "sets it again when you move it" },
            ["Object cull size"] = { "smaller than this are hidden", "lower shows more", "frame rate",
                "Environment Detail sets 35 down to 14", "sets it again when you move it" },
            ["Object cull distance"] = { "whatever their size", "in yards", "higher shows more", "frame rate",
                "No game setting changes it" },
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
