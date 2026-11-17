local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local GREY, YELLOW, ORANGE, RED = { 0.69, 0.69, 0.69 }, { 1, 1, 0.47 }, { 1, 0.6, 0 }, { 1, 0, 0 }

-- Logged in, in a group, with an attackable enemy as target (and focus).
local function start(savedOptions, options)
    options = options or {}
    local ns = Stubs.LoadAddon({ client = options.client })
    Stubs.SetUnit("target", { class = "WARRIOR" })
    Stubs.SetUnit("focus", { class = "WARRIOR" })
    Stubs.state().attackable = { target = true, focus = true }
    Stubs.SetGroup(options.solo ~= true)
    Stubs.Login(savedOptions)
    Stubs.RunTimers()
    return ns
end

local function contentOf(frameName)
    return _G[frameName].TargetFrameContent
end

-- Our badge on a unit frame: the frame anchored to its name background.
local function frameBadge(frameName)
    local name = contentOf(frameName).TargetFrameContentMain.ReputationColor
    local numeric = contentOf(frameName).TargetFrameContentContextual.NumericalThreat
    for _, region in ipairs(Stubs.state().regions) do
        local p = region.points[1]
        if region.kind == "Frame" and p and p[2] == name and region ~= numeric then
            return region
        end
    end
    return nil
end

-- The badge's number and its background: the one texture in it that is tinted (the border isn't).
local function parts(badge)
    local text, background
    for _, region in ipairs(Stubs.state().regions) do
        if region.parent == badge then
            if region.kind == "FontString" then text = region end
            if region.kind == "Texture" and region.vertexColor then background = region end
        end
    end
    return text, background
end

-- What a player sees: nil without a badge, else its text and background color.
local function seen(badge)
    if not (badge and badge:IsVisible()) then return nil end
    local text, background = parts(badge)
    local c = background.vertexColor
    return { text = text.text, color = { c[1], c[2], c[3] } }
end

local function target() return seen(frameBadge("TargetFrame")) end
local function focus() return seen(frameBadge("FocusFrame")) end

local function sameColor(actual, expected, what)
    T.truthy(actual, (what or "") .. ": a badge shows")
    for i = 1, 3 do
        T.truthy(math.abs(actual.color[i] - expected[i]) < 0.001,
            (what or "") .. ": color " .. table.concat(actual.color, ",") .. " is " .. table.concat(expected, ","))
    end
end

local function numericThreat(frameName)
    return contentOf(frameName).TargetFrameContentContextual.NumericalThreat
end

local GREEN = { 0.25, 0.9, 0.25 }

local function enterCombat()
    Stubs.SetCombat(true)
    Stubs.Fire("PLAYER_REGEN_DISABLED")
end

local function leaveCombat()
    Stubs.SetCombat(false)
    Stubs.RunTimers()
end

-- The player's threat changes without an event, as small changes do in the game.
local function quietThreat(unit, info)
    Stubs.state().threat[unit] = info
end

describe("threat badges on the target frame", function()
    it("shows the player's threat in percent, in the threat state's color", function()
        start()
        Stubs.SetThreat("target", { status = 1, rawPercent = 104.4 })
        T.eq(target().text, "104%")
        sameColor(target(), YELLOW)
    end)

    it("colors each threat state as the game does: grey, yellow, orange, red", function()
        start({ threatColors = "normal" })
        for status, expected in pairs({ [0] = GREY, YELLOW, ORANGE, RED }) do
            Stubs.SetThreat("target", { status = status, rawPercent = 90, isTanking = status >= 2, lead = 120 })
            sameColor(target(), expected, "state " .. status)
        end
    end)

    it("turns the colors round in tank colors: green holding aggro securely, red when it's lost", function()
        start({ threatColors = "tank" })
        for status, expected in pairs({ [0] = RED, ORANGE, YELLOW, GREEN }) do
            Stubs.SetThreat("target", { status = status, rawPercent = 90, isTanking = status >= 2, lead = 120 })
            sameColor(target(), expected, "state " .. status)
        end
    end)

    it("uses tank colors in Automatic while the game counts the player as a tank", function()
        start()
        Stubs.SetThreat("target", { status = 3, isTanking = true, rawPercent = 100, lead = 130 })
        sameColor(target(), RED, "not a tank")
        Stubs.state().tankAura = true
        Stubs.Fire("UPDATE_SHAPESHIFT_FORM")
        sameColor(target(), GREEN, "in Defensive Stance")
        Stubs.state().tankAura = false
        Stubs.Fire("UPDATE_SHAPESHIFT_FORM")
        sameColor(target(), RED, "out of it")
        Stubs.state().role = "TANK"
        Stubs.Fire("PLAYER_ROLES_ASSIGNED")
        sameColor(target(), GREEN, "with the tank role")
    end)

    it("shows a tank's lead over the next player while tanking, the raw percent otherwise", function()
        start()
        Stubs.SetThreat("target", { status = 3, isTanking = true, rawPercent = 100, lead = 135.6 })
        T.eq(target().text, "136%")
        Stubs.SetThreat("target", { status = 0, rawPercent = 62.2 })
        T.eq(target().text, "62%")
    end)

    it("shows nothing for a 0, as the game does", function()
        start()
        Stubs.SetThreat("target", { status = 0, rawPercent = 0 })
        T.eq(target(), nil)
    end)

    it("shows no badge off the threat list, on a dead or friendly target, or with the toggle off", function()
        local ns = start()
        Stubs.SetThreat("target", nil)
        T.eq(target(), nil, "off the threat list")
        Stubs.SetThreat("target", { status = 1, rawPercent = 80 })
        T.truthy(target(), "on it")
        Stubs.state().units.target.dead = true
        Stubs.SetThreat("target", { status = 1, rawPercent = 80 })
        T.eq(target(), nil, "dead")
        Stubs.state().units.target.dead = false
        Stubs.state().attackable.target = false
        Stubs.Fire("PLAYER_TARGET_CHANGED")
        T.eq(target(), nil, "friendly")
        Stubs.state().attackable.target = true
        Stubs.Fire("PLAYER_TARGET_CHANGED")
        T.truthy(target(), "attackable again")
        ns.Options:Set("threatTarget", false)
        T.eq(target(), nil, "toggled off")
    end)

    it("is gone as soon as the target changes to nothing", function()
        start()
        Stubs.SetThreat("target", { status = 1, rawPercent = 80 })
        Stubs.SetUnit("target", nil)
        Stubs.Fire("PLAYER_TARGET_CHANGED")
        T.eq(target(), nil)
    end)

    it("shows no badge solo, but does with a pet", function()
        start(nil, { solo = true })
        Stubs.SetThreat("target", { status = 3, isTanking = true, rawPercent = 100, lead = 100 })
        T.eq(target(), nil, "solo")
        Stubs.SetUnit("pet", { class = "HUNTER" })
        Stubs.Fire("UNIT_PET", "player")
        T.eq(target().text, "100%", "with a pet")
        Stubs.SetUnit("pet", nil)
        Stubs.Fire("UNIT_PET", "player")
        T.eq(target(), nil, "pet gone")
        Stubs.SetGroup(true)
        T.truthy(target(), "in a group")
    end)

    it("sits on the name background, the game's numeric threat's size, in a bronze border", function()
        start()
        Stubs.SetThreat("target", { status = 1, rawPercent = 80 })
        local badge = frameBadge("TargetFrame")
        T.same({ badge.points[1][1], badge.points[1][3] }, { "BOTTOM", "TOP" })
        T.same({ badge.width, badge.height }, { 49, 18 })
        local bronze = 0
        for _, region in ipairs(Stubs.state().regions) do
            if region.parent == badge and region.texture == "Interface\\AddOns\\QoL\\Media\\MinimapSquareBorder" then
                bronze = bronze + 1
            end
        end
        T.eq(bronze, 8, "four corners and four edges")
    end)

    it("hides the game's numeric threat while the badge is on and gives it back when it's off", function()
        local ns = start()
        local numeric = numericThreat("TargetFrame")
        T.eq(numeric.parent, ns.Hider.holder, "hidden while ours is on")
        T.eq(numericThreat("FocusFrame").parent, contentOf("FocusFrame").TargetFrameContentContextual,
            "the focus frame's stays, its badge being off")
        ns.Options:Set("threatTarget", false)
        Stubs.RunTimers()
        T.eq(numeric.parent, contentOf("TargetFrame").TargetFrameContentContextual, "back where it was")
    end)

    it("sets the text only when the shown number changes", function()
        start()
        Stubs.SetThreat("target", { status = 1, rawPercent = 80.2 })
        local text = parts(frameBadge("TargetFrame"))
        local sets = text.textSets
        Stubs.SetThreat("target", { status = 1, rawPercent = 79.8 })
        T.eq(text.textSets, sets, "still 80%")
        Stubs.SetThreat("target", { status = 1, rawPercent = 81 })
        T.eq(text.textSets, sets + 1)
        T.eq(text.text, "81%")
    end)
end)

describe("threat badges in combat", function()
    it("refreshes the number a few times a second without a threat event, and stops out of combat", function()
        start()
        enterCombat()
        Stubs.SetThreat("target", { status = 1, rawPercent = 80 })
        quietThreat("target", { status = 2, rawPercent = 112 })
        Stubs.AdvanceTime()
        T.eq(target().text, "112%")
        sameColor(target(), ORANGE)
        leaveCombat()
        quietThreat("target", { status = 2, rawPercent = 130 })
        Stubs.AdvanceTime()
        T.eq(target().text, "112%", "no refresh out of combat")
    end)

    it("turns on mid-fight, with the game's numeric threat hidden once combat ends", function()
        local ns = start({ threatTarget = false })
        enterCombat()
        Stubs.SetThreat("target", { status = 1, rawPercent = 80 })
        ns.Options:Set("threatTarget", true)
        Stubs.RunTimers()
        T.eq(target().text, "80%")
        local numeric = numericThreat("TargetFrame")
        T.eq(numeric.parent, contentOf("TargetFrame").TargetFrameContentContextual, "waits for combat")
        leaveCombat()
        T.eq(numeric.parent, ns.Hider.holder)
    end)
end)

describe("threat badges on the focus frame", function()
    it("is off by default and shows the focus's threat once turned on", function()
        local ns = start()
        Stubs.SetThreat("focus", { status = 3, rawPercent = 100, isTanking = true, lead = 110 })
        T.eq(focus(), nil, "off by default")
        ns.Options:Set("threatFocus", true)
        T.eq(focus().text, "110%")
        Stubs.SetUnit("focus", nil)
        Stubs.Fire("PLAYER_FOCUS_CHANGED")
        T.eq(focus(), nil, "focus cleared")
    end)
end)

-- Our badge on a pooled nameplate: the frame anchored left of its health bar.
local function plateBadge(plate)
    local healthBar = plate.HealthBarsContainer.healthBar
    for _, region in ipairs(Stubs.state().regions) do
        local p = region.points[1]
        if region.kind == "Frame" and region.parent == plate and p and p[2] == healthBar and p[1] == "TOPRIGHT" then
            return region
        end
    end
    return nil
end

local function enemy(unit)
    Stubs.SetUnit(unit, { class = "WARRIOR" })
    Stubs.state().attackable[unit] = true
end

describe("threat badges on nameplates", function()
    it("is off by default", function()
        start()
        enemy("nameplate1")
        local plate = Stubs.NewPooledNamePlate(1)
        Stubs.SetThreat("nameplate1", { status = 1, rawPercent = 90 })
        T.eq(plateBadge(plate), nil)
    end)

    it("shows a badge left of the health bar, in the level box's art, mirroring it", function()
        start({ threatNameplates = true })
        enemy("nameplate1")
        local plate = Stubs.NewPooledNamePlate(1)
        Stubs.SetThreat("nameplate1", { status = 2, rawPercent = 105 })
        local badge = plateBadge(plate)
        T.eq(seen(badge).text, "105%")
        sameColor(seen(badge), ORANGE)
        local _, background = parts(badge)
        T.eq(background.atlas, "ui-hud-nameplates-levelindicator")
        local healthBar = plate.HealthBarsContainer.healthBar
        T.same(badge:PointFor("TOPRIGHT"), { "TOPRIGHT", healthBar, "TOPLEFT", -5, 3 })
        T.same(badge:PointFor("BOTTOMRIGHT"), { "BOTTOMRIGHT", healthBar, "BOTTOMLEFT", -5, -2 })
        T.truthy(badge.width >= 20, "at least the level box's width")
    end)

    it("badges the plates already there when turned on", function()
        local ns = start()
        enemy("nameplate2")
        local plate = Stubs.NewPooledNamePlate(2)
        Stubs.SetThreat("nameplate2", { status = 0, rawPercent = 40 })
        ns.Options:Set("threatNameplates", true)
        T.eq(seen(plateBadge(plate)).text, "40%")
        ns.Options:Set("threatNameplates", false)
        T.eq(seen(plateBadge(plate)), nil, "gone when turned off")
    end)

    it("skips minus mobs", function()
        start({ threatNameplates = true })
        enemy("nameplate1")
        Stubs.state().classification.nameplate1 = "minus"
        local plate = Stubs.NewPooledNamePlate(1)
        Stubs.SetThreat("nameplate1", { status = 1, rawPercent = 90 })
        T.eq(seen(plateBadge(plate)), nil)
    end)

    it("follows plates removed and reused for another unit, in combat too", function()
        start({ threatNameplates = true })
        enterCombat()
        enemy("nameplate1")
        enemy("nameplate3")
        local plate = Stubs.NewPooledNamePlate(1)
        Stubs.SetThreat("nameplate1", { status = 1, rawPercent = 90 })
        T.eq(seen(plateBadge(plate)).text, "90%")
        Stubs.RemovePlate(plate)
        T.eq(seen(plateBadge(plate)), nil, "removed")
        Stubs.state().threat.nameplate3 = { status = 3, isTanking = true, rawPercent = 100, lead = 150 }
        Stubs.SetPlateUnit(plate, "nameplate3")
        T.eq(seen(plateBadge(plate)).text, "150%", "the plate reused for another unit")
        Stubs.SetThreat("nameplate1", { status = 1, rawPercent = 95 })
        T.eq(seen(plateBadge(plate)).text, "150%", "the old unit's events change nothing")
        quietThreat("nameplate3", { status = 3, isTanking = true, rawPercent = 100, lead = 170 })
        Stubs.AdvanceTime()
        T.eq(seen(plateBadge(plate)).text, "170%", "refreshed in combat")
    end)

    it("hears nameplate threat only while the nameplate badges are on", function()
        local ns = start({ threatTarget = false })
        T.falsy(Stubs.Listens("UNIT_THREAT_LIST_UPDATE", "nameplate1"))
        ns.Options:Set("threatNameplates", true)
        T.truthy(Stubs.Listens("UNIT_THREAT_LIST_UPDATE", "nameplate1"))
        ns.Options:Set("threatNameplates", false)
        T.falsy(Stubs.Listens("UNIT_THREAT_LIST_UPDATE", "nameplate1"), "off again")
    end)
end)

describe("threat badges on other clients", function()
    for _, client in ipairs({ "retail", "classicEra" }) do
        it("draws nothing on " .. client, function()
            start(nil, { client = client })
            Stubs.SetThreat("target", { status = 1, rawPercent = 80 })
            T.eq(frameBadge("TargetFrame"), nil)
        end)
    end
end)
