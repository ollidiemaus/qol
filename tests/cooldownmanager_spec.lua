local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local ROWS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
local BORDER = "UI-HUD-CoolDownManager-IconOverlay"

-- Loads the addon with the game's Cooldown Manager, three icons a row, then logs in.
local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.NewCooldownManager()
    Stubs.Login(savedOptions)
    return ns
end

-- The frame an icon's art is in: the icon itself, or on the bar row the frame beside the bar.
local function art(icon)
    return icon.Icon.kind == "Frame" and icon.Icon or icon
end

local function border(icon)
    for _, region in ipairs({ art(icon):GetRegions() }) do
        if region:GetAtlas() == BORDER then return region end
    end
    error("an icon without a border")
end

-- Every icon the four rows show, with its row's name.
local function icons()
    local all = {}
    for _, name in ipairs(ROWS) do
        for _, icon in ipairs(Stubs.CooldownIcons(name)) do all[#all + 1] = { row = name, icon = icon } end
    end
    return all
end

local function borderAlphas()
    local alphas = {}
    for index, entry in ipairs(icons()) do alphas[index] = border(entry.icon):GetAlpha() end
    return alphas
end

local function all(count, alpha)
    local alphas = {}
    for index = 1, count do alphas[index] = alpha end
    return alphas
end

-- Everything on an icon the feature could change: each texture, mask and frame in it, however deep,
-- except the border's alpha.
local function snapshot(icon)
    local shot = {}
    local function add(region)
        local points = {}
        for i, p in ipairs(region.points) do points[i] = { p[1], p[3], p[4], p[5] } end
        local masks = 0
        for _ in pairs(region.masks or {}) do masks = masks + 1 end
        shot[#shot + 1] = { kind = region.kind, atlas = region.atlas, texture = region.texture, shown = region.shown,
            alpha = region.atlas ~= BORDER and region:GetAlpha() or nil, blend = region:GetBlendMode(),
            width = region.width, height = region.height, points = points, layer = { region:GetDrawLayer() },
            masks = masks, parent = region.parent ~= nil }
    end
    local function walk(frame)
        for _, region in ipairs({ frame:GetRegions() }) do add(region) end
        for _, child in ipairs({ frame:GetChildren() }) do
            add(child)
            walk(child)
        end
    end
    walk(icon)
    return shot
end

local function snapshots()
    local shots = {}
    for index, entry in ipairs(icons()) do shots[index] = snapshot(entry.icon) end
    return shots
end

describe("cooldown manager", function()
    it("leaves the icons alone while off", function()
        start()
        local before = snapshots()
        Stubs.RebuildCooldownRow("EssentialCooldownViewer", 3)
        Stubs.RunTimers()
        T.same(borderAlphas(), all(12, 1))
        T.same(snapshots(), before)
    end)

    it("hides the border on every icon of all four rows", function()
        start({ hideCooldownManagerBorders = true })
        T.same(borderAlphas(), all(12, 0))
    end)

    it("hides it the moment the option goes on, and changes nothing else on an icon", function()
        local ns = start()
        local before = snapshots()
        ns.Options:Set("hideCooldownManagerBorders", true)
        Stubs.RunTimers()
        T.same(borderAlphas(), all(12, 0))
        T.same(snapshots(), before)
    end)

    it("hides it on icons a row hands out after a rebuild, new ones too", function()
        start({ hideCooldownManagerBorders = true })
        for _, name in ipairs(ROWS) do Stubs.RebuildCooldownRow(name, 5) end
        Stubs.RunTimers()
        T.same(borderAlphas(), all(20, 0))
    end)

    it("hides it on new icons in combat too", function()
        start({ hideCooldownManagerBorders = true })
        Stubs.SetCombat(true)
        Stubs.RebuildCooldownRow("BuffIconCooldownViewer", 4)
        Stubs.RunTimers()
        T.same(borderAlphas(), all(13, 0))
    end)

    it("puts the border back when turned off, also on icons a row isn't showing", function()
        local ns = start({ hideCooldownManagerBorders = true })
        Stubs.RebuildCooldownRow("UtilityCooldownViewer", 1)
        Stubs.RunTimers()
        ns.Options:Set("hideCooldownManagerBorders", false)
        Stubs.RunTimers()
        T.same(borderAlphas(), all(10, 1))
        Stubs.RebuildCooldownRow("UtilityCooldownViewer", 3)
        Stubs.RunTimers()
        T.same(borderAlphas(), all(12, 1))
    end)

    it("puts back the alpha the border had", function()
        local ns = start()
        local first = border(Stubs.CooldownIcons("EssentialCooldownViewer")[1])
        first:SetAlpha(0.5)
        ns.Options:Set("hideCooldownManagerBorders", true)
        Stubs.RunTimers()
        T.eq(first:GetAlpha(), 0)
        ns.Options:Set("hideCooldownManagerBorders", false)
        Stubs.RunTimers()
        T.eq(first:GetAlpha(), 0.5)
    end)

    it("does nothing without the game's Cooldown Manager, and picks it up once the game loads it", function()
        local ns = Stubs.LoadAddon()
        Stubs.Login({ hideCooldownManagerBorders = true })
        ns.Options:Set("hideCooldownManagerBorders", false)
        ns.Options:Set("hideCooldownManagerBorders", true)
        Stubs.RunTimers()

        Stubs.NewCooldownManager()
        Stubs.Fire("ADDON_LOADED", "Blizzard_CooldownViewer")
        Stubs.RunTimers()
        T.same(borderAlphas(), all(12, 0))
    end)

    it("works on the rows a client has", function()
        Stubs.LoadAddon()
        Stubs.NewCooldownManager()
        _G.BuffBarCooldownViewer, _G.UtilityCooldownViewer = nil, nil
        Stubs.Login({ hideCooldownManagerBorders = true })
        for _, name in ipairs({ "EssentialCooldownViewer", "BuffIconCooldownViewer" }) do
            for _, icon in ipairs(Stubs.CooldownIcons(name)) do T.eq(border(icon):GetAlpha(), 0, name) end
        end
    end)

    for _, client in ipairs({ "retail", "classicEra" }) do
        it("leaves the icons alone on " .. client, function()
            Stubs.LoadAddon({ client = client })
            Stubs.NewCooldownManager()
            Stubs.Login({ hideCooldownManagerBorders = true })
            Stubs.RebuildCooldownRow("EssentialCooldownViewer", 4)
            Stubs.RunTimers()
            T.same(borderAlphas(), all(13, 1))
        end)
    end
end)
