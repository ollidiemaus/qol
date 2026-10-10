local _, ns = ...
local Options = ns.Options

-- Action buttons without their frame, with square icons (like HideActionBarBorders). For every
-- button of the bars ActionBars.lua knows (action bars 1 to 8, the stance bar and the pet bar):
--   * the frame (the button's normal texture) gets alpha 0, and the icon loses its rounded mask;
--   * the textures drawn for the rounded frame (mouseover, checked, pushed, the new action and
--     spell highlights, the red flash and the green border of an equipped item) show Blizzard's
--     classic square ones instead, made for square icons;
--   * the cooldown swipes cover the whole icon instead of the inside of the frame;
--   * the casting and interrupt animations, drawn for the round frame, get alpha 0.
-- Only widget methods on the button's textures and child frames, always from ns.Later; the button
-- itself is never touched, and a button is left alone until the player turns the option on. A
-- texture shows ours only while it shows Blizzard's frame art, so the pet bar's own spell
-- highlight stays. Blizzard puts the pushed frame back when Edit Mode changes a bar's art; the
-- next wake-up replaces it again.
local ButtonBorders = {}
ns.ButtonBorders = ButtonBorders

local KEY = "hideButtonBorders"

-- Per texture (the button's key for it): the classic texture and blend mode, and how it sits on
-- the icon: "fill" covers it, "glow" is centered and larger (the equipped border's ring sits
-- inside its texture, as on classic buttons: 62 units of texture for a 36 unit icon).
ButtonBorders.SQUARE = {
    HighlightTexture = { file = "Interface\\Buttons\\ButtonHilight-Square", blend = "ADD", fit = "fill" },
    CheckedTexture = { file = "Interface\\Buttons\\CheckButtonHilight", blend = "ADD", fit = "fill" },
    PushedTexture = { file = "Interface\\Buttons\\UI-Quickslot-Depress", blend = "BLEND", fit = "fill" },
    NewActionTexture = { file = "Interface\\Buttons\\ButtonHilight-Square", blend = "ADD", fit = "fill" },
    SpellHighlightTexture = { file = "Interface\\Buttons\\ButtonHilight-Square", blend = "ADD", fit = "fill" },
    Flash = { file = "Interface\\Buttons\\UI-QuickslotRed", blend = "BLEND", fit = "fill" },
    Border = { file = "Interface\\Buttons\\UI-ActionButton-Border", blend = "ADD", fit = "glow" },
}
local GLOW_SCALE = 62 / 36

-- The cooldowns that draw a swipe, inset for the rounded frame.
local COOLDOWNS = { "cooldown", "lossOfControlCooldown" }
-- The empty slot's art and background, kept behind the icon now that it is square.
local SLOT_ART = { "SlotBackground", "SlotArt" }
-- The spell effects drawn for the round frame.
local EFFECTS = { "SpellCastAnimFrame", "InterruptDisplay" }

-- Blizzard's art for the rounded frame: "UI-HUD-ActionBar-IconFrame", "...-Mouseover" and so on.
local function isFrameArt(atlas)
    return type(atlas) == "string" and atlas:lower():find("^ui%-hud%-actionbar%-iconframe") ~= nil
end

local function savePoints(region)
    local points = {}
    for i = 1, region:GetNumPoints() do
        points[i] = { region:GetPoint(i) }
    end
    return points
end

local function restorePoints(region, points)
    region:ClearAllPoints()
    for _, p in ipairs(points) do
        region:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
end

-- The buttons of every bar, from the bars' own lists.
function ButtonBorders.Buttons()
    local buttons = {}
    for _, info in ipairs(ns.ActionBars.BARS) do
        local bar = _G[info.frame]
        local list = bar and bar.actionButtons
        if type(list) == "table" then
            for _, button in ipairs(list) do buttons[#buttons + 1] = button end
        end
    end
    return buttons
end

-- Per button we changed: what its parts looked like before.
local saved = {}
ButtonBorders.saved = saved

local function squareTexture(button, key, square, before)
    local texture = button[key]
    if not texture then return end
    local atlas = texture:GetAtlas()
    if not isFrameArt(atlas) then return end
    -- Blizzard may have set its art again (the pushed frame); the anchors are still ours then.
    -- A texture filling the icon keeps the size Blizzard gives it, only its anchors change; the
    -- glow gets a size of ours.
    local old = before.textures[key]
    before.textures[key] = old or { points = savePoints(texture), width = texture:GetWidth(),
        height = texture:GetHeight() }
    before.textures[key].atlas = atlas
    before.textures[key].blend = texture:GetBlendMode()
    texture:SetTexture(square.file)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetBlendMode(square.blend)
    texture:ClearAllPoints()
    local icon = button.icon or button
    if square.fit == "glow" then
        texture:SetPoint("CENTER", icon, "CENTER", 0, 0)
        texture:SetSize(button:GetWidth() * GLOW_SCALE, button:GetHeight() * GLOW_SCALE)
    else
        texture:SetAllPoints(icon)
    end
end

function ButtonBorders.Hide(button)
    local before = saved[button]
    if not before then
        before = { textures = {}, cooldowns = {}, layers = {}, alphas = {} }
        saved[button] = before
    end

    local normal = button.NormalTexture
    if normal and before.normalAlpha == nil then
        before.normalAlpha = normal:GetAlpha()
        normal:SetAlpha(0)
    end
    if button.icon and button.IconMask and not before.unmasked then
        button.icon:RemoveMaskTexture(button.IconMask)
        before.unmasked = true
    end
    for key, square in pairs(ButtonBorders.SQUARE) do
        squareTexture(button, key, square, before)
    end
    for _, key in ipairs(COOLDOWNS) do
        local cooldown = button[key]
        if cooldown and button.icon and not before.cooldowns[key] then
            before.cooldowns[key] = savePoints(cooldown)
            cooldown:ClearAllPoints()
            cooldown:SetAllPoints(button.icon)
        end
    end
    for _, key in ipairs(SLOT_ART) do
        local texture = button[key]
        if texture and not before.layers[key] then
            before.layers[key] = { texture:GetDrawLayer() }
            texture:SetDrawLayer("BACKGROUND", -1)
        end
    end
    for _, key in ipairs(EFFECTS) do
        local frame = button[key]
        if frame and before.alphas[key] == nil then
            before.alphas[key] = frame:GetAlpha()
            frame:SetAlpha(0)
        end
    end
end

function ButtonBorders.Restore(button)
    local before = saved[button]
    if not before then return end
    if before.normalAlpha ~= nil then button.NormalTexture:SetAlpha(before.normalAlpha) end
    if before.unmasked then button.icon:AddMaskTexture(button.IconMask) end
    for key, old in pairs(before.textures) do
        local texture = button[key]
        -- Unless Blizzard has put its own art back in the meantime.
        if not isFrameArt(texture:GetAtlas()) then texture:SetAtlas(old.atlas) end
        texture:SetBlendMode(old.blend)
        if ButtonBorders.SQUARE[key].fit == "glow" then texture:SetSize(old.width, old.height) end
        restorePoints(texture, old.points)
    end
    for key, points in pairs(before.cooldowns) do restorePoints(button[key], points) end
    for key, layer in pairs(before.layers) do button[key]:SetDrawLayer(layer[1], layer[2]) end
    for key, alpha in pairs(before.alphas) do button[key]:SetAlpha(alpha) end
    saved[button] = nil
end

function ButtonBorders:Apply()
    if Options:Get(KEY) then
        for _, button in ipairs(self.Buttons()) do self.Hide(button) end
    else
        for button in pairs(saved) do self.Restore(button) end
    end
end

local function schedule()
    ns.Later("buttonBorders", function() ButtonBorders:Apply() end)
end

local function wake()
    if Options:Get(KEY) or next(saved) ~= nil then schedule() end
end

function ButtonBorders:Init()
    Options:Watch({ KEY }, schedule)
    -- Edit Mode puts the pushed frame back when it changes a bar's art.
    ns.Events:On("PLAYER_ENTERING_WORLD", wake)
    ns.Events:On("EDIT_MODE_LAYOUTS_UPDATED", wake)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Exit", wake, ButtonBorders)
    end
    wake()
end
