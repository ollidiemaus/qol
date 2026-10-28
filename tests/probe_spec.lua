local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- The addon loaded and logged in. before: changes the test state before the addon loads.
local function start(before)
    local ns = Stubs.LoadAddon()
    if before then before(Stubs.state()) end
    Stubs.Login()
    return ns, Stubs.state()
end

-- The last report's key = value lines by key.
local function report()
    local lines = {}
    for _, line in ipairs(QoLDB.probe.lines) do
        local key, value = line:match("^(%S+) = (.*)$")
        if key then lines[key] = value end
    end
    return lines
end

-- A client like Forever's (the values retail gave by hand): the settings considered for the page,
-- with their game defaults and ranges, and the three game sliders with what each step sets.
local function client(s)
    local candidates = {
        farclip = { "6000", "1000" }, horizonStart = { "1400", "800" }, horizonClip = { "6000", "1600" },
        lodObjectCullSize = { "20", "15", 1, 100 }, lodObjectCullDist = { "30", "30", 1, 200 },
        lodObjectFadeScale = { "90", "100", 50, 5000 }, lodObjectMinSize = { "0", "20", 0, 1000 },
    }
    for cvar, c in pairs(candidates) do
        s.cvars[cvar], s.cvarDefaults[cvar] = c[1], c[2]
        if c[3] then s.cvarRanges[cvar] = { c[3], c[4] } end
    end
    local columns = {
        graphicsViewDistance = {
            farclip = { 1500, 2500, 3500, 4500, 6000, 7000, 7500, 8000, 9000, 10000 },
            horizonClip = { 1500, 2500, 3500, 4500, 6000, 7000, 7500, 8000, 9000, 10000 },
            horizonStart = { 400, 600, 800, 1000, 1400, 1600, 2000, 2400, 3000, 4000 },
        },
        graphicsEnvironmentDetail = {
            lodObjectCullSize = { 35, 32, 29, 26, 20, 18, 17, 16, 15, 14 },
            lodObjectFadeScale = { 50, 60, 70, 80, 90, 100, 110, 120, 130, 150 },
            lodObjectMinSize = { 0, 0, 0, 0, 0, 0, 0, 10, 15, 20 },
        },
        graphicsGroundClutter = {
            groundEffectDist = { 40, 50, 60, 65, 70, 80, 100, 120, 140, 160 },
            groundEffectDensity = { 16, 16, 16, 16, 16, 24, 32, 48, 64, 80 },
        },
    }
    for slider, settings in pairs(columns) do
        s.cvars[slider], s.cvarDefaults[slider], s.cvarRanges[slider] = "4", "4", { 0, 9 }
        local steps = {}
        for step = 0, 9 do
            steps[step] = {}
            for cvar, values in pairs(settings) do steps[step][cvar] = tostring(values[step + 1]) end
        end
        s.gameSliders[slider] = steps
    end
end

-- The settings listed under a game slider, sorted.
local function listedUnder(r, slider)
    local cvars = {}
    for key in pairs(r) do
        local cvar = key:match("^slider%." .. slider .. "%.(.+)$")
        if cvar then cvars[#cvars + 1] = cvar end
    end
    table.sort(cvars)
    return cvars
end

local function copy(list)
    local result = {}
    for k, v in pairs(list) do result[k] = v end
    return result
end

local function has(text, words)
    return text ~= nil and text:find(words, 1, true) ~= nil
end

describe("hidden settings probe", function()
    it("reports each hidden setting's value, game default, range, halves and whether it's protected", function()
        local _, state = start(function(s)
            s.cvarWhole.weatherDensity = true
            s.cvarSecure.groundEffectDensity = true
            s.cvars.groundEffectDist = "120"
            -- At the top of its range: a half is tried below.
            s.cvars.groundEffectDensity = "256"
        end)
        SlashCmdList.QOL("probe")
        local r = report()
        local distance = r["cvar.groundEffectDist"]
        for _, words in ipairs({ "120 (default 70)", "40..500", "halves", "not protected" }) do
            T.truthy(has(distance, words), "distance says " .. words .. ": " .. tostring(distance))
        end
        local weather = r["cvar.weatherDensity"]
        T.truthy(has(weather, "0..3"), weather)
        T.truthy(has(weather, "whole numbers"), weather)
        T.truthy(has(r["cvar.groundEffectDensity"], "16..256"), r["cvar.groundEffectDensity"])
        T.truthy(has(r["cvar.groundEffectDensity"], ", protected"), r["cvar.groundEffectDensity"])
        T.truthy(has(r["cvar.groundEffectDensity"], "halves"), r["cvar.groundEffectDensity"])
        T.truthy(has(r["cvar.groundEffectFade"], "no range check"), r["cvar.groundEffectFade"])
        -- On whole numbers: the camera distance takes 1 to 2.6.
        T.truthy(has(r["cvar.cameraDistanceMaxZoomFactor"], "1.9 (default 1.9), 1..2, halves"),
            r["cvar.cameraDistanceMaxZoomFactor"])
        T.falsy(has(r["cvar.groundEffectFade"], "000"), "no number in the millions")
        T.eq(state.cvars.groundEffectDist, "120")
    end)

    it("prints the report and keeps it, starting with the client and the date", function()
        local _, state = start(client)
        SlashCmdList.QOL("probe")
        local probe = QoLDB.probe
        local r = report()
        for _, words in ipairs({ "1.60.1", "70630", "enUS" }) do
            T.truthy(has(probe.client, words), "client " .. words .. ": " .. tostring(probe.client))
            T.truthy(has(r.client, words), "client line " .. words .. ": " .. tostring(r.client))
        end
        T.truthy(probe.date:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d$"), probe.date)
        T.eq(r.date, probe.date)
        T.truthy(probe.lines[1]:match("^client = ") and probe.lines[2]:match("^date = "), "starts with them")
        T.eq(#state.messages, #probe.lines + 1)
        for index, line in ipairs(probe.lines) do
            T.eq(state.messages[index], "|cff33ff99Quality of Life|r: " .. line)
        end
        T.truthy(has(state.messages[#state.messages], "SavedVariables"), state.messages[#state.messages])
    end)

    it("replaces the last report each run", function()
        local _, state = start(client)
        SlashCmdList.QOL("probe")
        local count = #QoLDB.probe.lines
        state.cvars.farclip = "4000"
        SlashCmdList.QOL("probe")
        T.eq(#QoLDB.probe.lines, count)
        T.truthy(has(report()["cvar.farclip"], "4000 (default 1000)"), report()["cvar.farclip"])
    end)

    it("reports a setting the client doesn't know as missing, and goes on", function()
        start(function(s)
            s.cvars.weatherDensity = nil
            s.cvarDefaults.groundEffectFade = nil
        end)
        SlashCmdList.QOL("probe")
        local r = report()
        T.eq(r["cvar.weatherDensity"], "missing")
        T.truthy(has(r["cvar.groundEffectFade"], "70 (no game default), "), r["cvar.groundEffectFade"])
        T.truthy(has(r["cvar.ResampleAlwaysSharpen"], "(default 0)"), r["cvar.ResampleAlwaysSharpen"])
        T.truthy(has(r["cvar.cameraDistanceMaxZoomFactor"], "(default 1.9)"), r["cvar.cameraDistanceMaxZoomFactor"])
    end)

    it("measures the settings considered for the page too", function()
        start(client)
        SlashCmdList.QOL("probe")
        local r = report()
        T.truthy(has(r["cvar.farclip"], "6000 (default 1000), no range check, halves"), r["cvar.farclip"])
        T.truthy(has(r["cvar.lodObjectFadeScale"], "90 (default 100), 50..5000"), r["cvar.lodObjectFadeScale"])
        for _, cvar in ipairs({ "horizonStart", "horizonClip", "lodObjectCullSize", "lodObjectCullDist",
            "lodObjectMinSize" }) do
            T.truthy(has(r["cvar." .. cvar], "(default "), cvar .. ": " .. tostring(r["cvar." .. cvar]))
        end
        T.truthy(has(r["cvar.lodObjectMinSize"], "0..1000"), r["cvar.lodObjectMinSize"])
    end)

    it("measures a candidate once it's in the table only once", function()
        local ns = start(client)
        T.truthy(ns.HiddenSettings.Find("farclip"), "farclip is in the table")
        SlashCmdList.QOL("probe")
        local count = 0
        for _, line in ipairs(QoLDB.probe.lines) do
            if line:find("^cvar%.farclip = ") then count = count + 1 end
        end
        T.eq(count, 1)
    end)

    it("lists under each game slider its step and game default, from 1, and what each step sets", function()
        start(function(s)
            client(s)
            s.cvars.graphicsViewDistance = "7"
        end)
        SlashCmdList.QOL("probe")
        local r = report()
        T.truthy(has(r["slider.graphicsViewDistance"], "8 (default 5)"), r["slider.graphicsViewDistance"])
        T.truthy(has(r["slider.graphicsEnvironmentDetail"], "5 (default 5)"), r["slider.graphicsEnvironmentDetail"])
        T.same(listedUnder(r, "graphicsViewDistance"), { "farclip", "horizonClip", "horizonStart" })
        T.eq(r["slider.graphicsViewDistance.farclip"], "1500 2500 3500 4500 6000 7000 7500 8000 9000 10000")
        T.eq(r["slider.graphicsViewDistance.horizonStart"], "400 600 800 1000 1400 1600 2000 2400 3000 4000")
        T.same(listedUnder(r, "graphicsEnvironmentDetail"), { "lodObjectCullSize", "lodObjectFadeScale",
            "lodObjectMinSize" })
        T.eq(r["slider.graphicsEnvironmentDetail.lodObjectMinSize"], "0 0 0 0 0 0 0 10 15 20")
        T.same(listedUnder(r, "graphicsGroundClutter"), { "groundEffectDensity", "groundEffectDist" })
        T.eq(r["slider.graphicsGroundClutter.groundEffectDensity"], "16 16 16 16 16 24 32 48 64 80")
    end)

    it("says whether writing a game slider's step again sets the settings behind it again", function()
        start(client)
        SlashCmdList.QOL("probe")
        T.eq(report()["rewrite.graphicsViewDistance"], "yes")
        T.eq(report()["rewrite.graphicsEnvironmentDetail"], "yes")

        start(function(s)
            client(s)
            s.gameSliderRewrites = false
        end)
        SlashCmdList.QOL("probe")
        local r = report()
        T.eq(r["rewrite.graphicsViewDistance"], "no: farclip, horizonStart, horizonClip")
        T.eq(r["rewrite.graphicsGroundClutter"], "no: groundEffectDist, groundEffectDensity")
    end)

    it("names a setting behind a game slider that it couldn't set to another value for that test", function()
        start(function(s)
            client(s)
            s.cvarRanges.lodObjectMinSize = { 0, 0 }
        end)
        SlashCmdList.QOL("probe")
        T.eq(report()["rewrite.graphicsEnvironmentDetail"], "yes, not tested for lodObjectMinSize")
    end)

    it("puts every value back, also one the player set apart from what its game slider sets", function()
        local _, state = start(function(s)
            client(s)
            s.cvars.farclip = "5000"
            s.cvars.lodObjectFadeScale = "200"
            s.cvars.graphicsGroundClutter = "8"
            s.cvars.cameraDistanceMaxZoomFactor = "2.6"
        end)
        local before = copy(state.cvars)
        SlashCmdList.QOL("probe")
        T.truthy(#state.cvarSets > 100, "it wrote values")
        T.same(state.cvars, before)
        T.eq(report().restore, "everything back")
    end)

    it("names a value it couldn't put back", function()
        local _, state = start(function(s)
            client(s)
            -- A value the game takes no more.
            s.cvars.farclip = "500"
            s.cvarRanges.farclip = { 1000, 20000 }
        end)
        SlashCmdList.QOL("probe")
        T.eq(state.cvars.farclip, "6000")
        T.eq(report()["restore.farclip"], "6000, was 500")
        T.eq(report().restore, nil)
        T.eq(state.cvars.horizonStart, "1400")
    end)

    it("refuses in combat with a line in chat, writing nothing", function()
        local _, state = start(client)
        QoLDB.probe = { lines = { "cvar.farclip = earlier" } }
        Stubs.SetCombat(true)
        SlashCmdList.QOL("probe")
        T.same(state.cvarSets, {})
        T.eq(#state.messages, 1)
        T.truthy(has(state.messages[1], "in combat"), state.messages[1])
        T.same(QoLDB.probe.lines, { "cvar.farclip = earlier" })
    end)

    it("never writes the raid copies, the Raid and Battleground graphics or Graphics Quality", function()
        local _, state = start(function(s)
            client(s)
            for _, cvar in ipairs({ "RAIDfarclip", "RAIDhorizonStart", "RAIDlodObjectCullSize",
                "raidGraphicsViewDistance", "raidGraphicsEnvironmentDetail", "raidGraphicsGroundClutter",
                "graphicsQuality", "raidGraphicsQuality", "graphicsTextureResolution" }) do
                s.cvars[cvar] = "4"
            end
        end)
        SlashCmdList.QOL("probe")
        local sliders = {}
        for _, set in ipairs(state.cvarSets) do
            local cvar = set:match("^[^=]+")
            T.falsy(cvar:find("^RAID") or cvar:find("^raid"), set)
            if cvar:find("^graphics") then sliders[cvar] = true end
        end
        T.same(sliders, { graphicsViewDistance = true, graphicsEnvironmentDetail = true, graphicsGroundClutter = true })
    end)

    it("runs as /qol probe in any case, and /qol help leaves it out", function()
        local _, state = start(client)
        SlashCmdList.QOL("help")
        T.eq(#state.messages, 1)
        T.falsy(state.messages[1]:lower():find("probe"), state.messages[1])
        SlashCmdList.QOL(" Probe ")
        T.truthy(QoLDB.probe, "ran")
    end)

    it("reports a game slider the client doesn't have as missing", function()
        start(function(s)
            client(s)
            s.cvars.graphicsGroundClutter = nil
        end)
        SlashCmdList.QOL("probe")
        local r = report()
        T.eq(r["slider.graphicsGroundClutter"], "missing")
        T.same(listedUnder(r, "graphicsGroundClutter"), {})
        T.truthy(has(r["slider.graphicsViewDistance"], "5 (default 5)"), r["slider.graphicsViewDistance"])
    end)
end)
