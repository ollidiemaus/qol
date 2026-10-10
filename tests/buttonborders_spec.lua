local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local MAIN = "Interface\\Buttons\\"

-- Loads the addon with a main bar of two buttons and a pet bar of one small button, then logs in.
local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    local main = { Stubs.NewActionButton(), Stubs.NewActionButton() }
    local pet = Stubs.NewActionButton(true)
    _G.MainActionBar = Stubs.NewActionBar({ actionButtons = main })
    _G.PetActionBar = Stubs.NewActionBar({ actionButtons = { pet } })
    Stubs.Login(savedOptions)
    return ns, main[1], pet
end

-- Everything about a button the feature may change, to compare before and after.
local function snapshot(button)
    local function region(r)
        local points = {}
        for i, p in ipairs(r.points) do points[i] = { p[1], p[2], p[3], p[4], p[5] } end
        return { atlas = r.atlas, texture = r.texture, blend = r:GetBlendMode(), alpha = r:GetAlpha(),
            width = r.width, height = r.height, points = points, layer = { r:GetDrawLayer() } }
    end
    local shot = { masked = button.icon.masks[button.IconMask] == true }
    for _, key in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture", "NewActionTexture",
        "SpellHighlightTexture", "Flash", "Border", "cooldown", "lossOfControlCooldown", "chargeCooldown",
        "SlotBackground", "SlotArt", "SpellCastAnimFrame", "InterruptDisplay" }) do
        shot[key] = region(button[key])
    end
    return shot
end

local function fillsIcon(texture, button)
    local topLeft, bottomRight = texture:PointFor("TOPLEFT"), texture:PointFor("BOTTOMRIGHT")
    return #texture.points == 2 and topLeft[2] == button.icon and topLeft[4] == 0 and topLeft[5] == 0
        and bottomRight[2] == button.icon and bottomRight[4] == 0 and bottomRight[5] == 0
end

describe("button borders", function()
    it("leaves the buttons alone while off", function()
        local _, button = start()
        local before = snapshot(button)
        Stubs.Fire("EDIT_MODE_LAYOUTS_UPDATED")
        Stubs.TriggerRegistry("EditMode.Exit")
        Stubs.RunTimers()
        T.same(snapshot(button), before)
    end)

    it("hides the frame and makes the icon square", function()
        local _, button = start({ hideButtonBorders = true })
        T.eq(button.NormalTexture:GetAlpha(), 0)
        T.eq(button.icon.masks[button.IconMask], nil)
        T.eq(button.SlotBackground.drawLayer[2], -1)
        T.eq(button.SlotArt.drawLayer[2], -1)
    end)

    it("draws the classic square textures over the icon instead of the frame's", function()
        local _, button = start({ hideButtonBorders = true })
        local expected = {
            HighlightTexture = { "ButtonHilight-Square", "ADD" },
            CheckedTexture = { "CheckButtonHilight", "ADD" },
            PushedTexture = { "UI-Quickslot-Depress", "BLEND" },
            NewActionTexture = { "ButtonHilight-Square", "ADD" },
            SpellHighlightTexture = { "ButtonHilight-Square", "ADD" },
            Flash = { "UI-QuickslotRed", "BLEND" },
        }
        for key, want in pairs(expected) do
            local texture = button[key]
            T.eq(texture.texture, MAIN .. want[1], key)
            T.eq(texture:GetAtlas(), nil, key)
            T.same(texture.texCoord, { 0, 1, 0, 1 }, key)
            T.eq(texture:GetBlendMode(), want[2], key)
            T.truthy(fillsIcon(texture, button), key .. " covers the icon")
        end
    end)

    it("centers the equipped item's glow on the icon, larger like on classic buttons", function()
        local _, button = start({ hideButtonBorders = true })
        T.eq(button.Border.texture, MAIN .. "UI-ActionButton-Border")
        T.eq(button.Border:GetBlendMode(), "ADD")
        T.same(button.Border.points, { { "CENTER", button.icon, "CENTER", 0, 0 } })
        T.truthy(math.abs(button.Border.width - 45 * 62 / 36) < 1e-9)
        T.truthy(math.abs(button.Border.height - 45 * 62 / 36) < 1e-9)
    end)

    it("lets the cooldown swipes cover the whole icon, and leaves the charge cooldown", function()
        local _, button = start({ hideButtonBorders = true })
        T.truthy(fillsIcon(button.cooldown, button))
        T.truthy(fillsIcon(button.lossOfControlCooldown, button))
        T.eq(button.chargeCooldown:PointFor("TOPLEFT")[4], 2)
    end)

    it("hides the casting and interrupt animations", function()
        local _, button = start({ hideButtonBorders = true })
        T.eq(button.SpellCastAnimFrame:GetAlpha(), 0)
        T.eq(button.InterruptDisplay:GetAlpha(), 0)
    end)

    it("does the pet bar's small buttons too, but keeps their own spell highlight", function()
        local _, _, pet = start({ hideButtonBorders = true })
        T.eq(pet.NormalTexture:GetAlpha(), 0)
        T.eq(pet.HighlightTexture.texture, MAIN .. "ButtonHilight-Square")
        T.truthy(math.abs(pet.Border.width - 30 * 62 / 36) < 1e-9)
        T.eq(pet.SpellHighlightTexture:GetAtlas(), "bags-newitem")
        T.eq(pet.SpellHighlightTexture.texture, nil)
    end)

    it("puts everything back when turned off", function()
        local ns, button, pet = start()
        local before, petBefore = snapshot(button), snapshot(pet)
        ns.Options:Set("hideButtonBorders", true)
        Stubs.RunTimers()
        ns.Options:Set("hideButtonBorders", false)
        Stubs.RunTimers()
        -- The textures keep the classic file name underneath the atlas; what shows is the atlas.
        local after, petAfter = snapshot(button), snapshot(pet)
        for _, shot in ipairs({ before, after, petBefore, petAfter }) do
            for _, region in pairs(shot) do
                if type(region) == "table" then region.texture = nil end
            end
        end
        T.same(after, before)
        T.same(petAfter, petBefore)
        T.eq(next(ns.ButtonBorders.saved), nil)
    end)

    it("waits for the end of combat", function()
        local ns, button = start()
        Stubs.SetCombat(true)
        ns.Options:Set("hideButtonBorders", true)
        Stubs.RunTimers()
        T.eq(button.NormalTexture:GetAlpha(), 1)
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(button.NormalTexture:GetAlpha(), 0)
    end)

    it("squares the pushed frame again after Edit Mode changed the bar's art, and restores the new art", function()
        local ns, button = start({ hideButtonBorders = true })
        -- UpdateButtonArt for a bar without art: the larger frame, at a new size.
        button.PushedTexture:SetAtlas("UI-HUD-ActionBar-IconFrame-AddRow-Down")
        button.PushedTexture:SetSize(51, 51)
        Stubs.TriggerRegistry("EditMode.Exit")
        Stubs.RunTimers()
        T.eq(button.PushedTexture.texture, MAIN .. "UI-Quickslot-Depress")
        T.truthy(fillsIcon(button.PushedTexture, button))

        ns.Options:Set("hideButtonBorders", false)
        Stubs.RunTimers()
        T.eq(button.PushedTexture:GetAtlas(), "UI-HUD-ActionBar-IconFrame-AddRow-Down")
        T.same(button.PushedTexture.points, { { "TOPLEFT", button, "TOPLEFT", 0, 0 } })
        T.eq(button.PushedTexture.width, 51)
    end)

    it("keeps a texture Blizzard gave its art back to while on, when turned off", function()
        local ns, button = start({ hideButtonBorders = true })
        button.PushedTexture:SetAtlas("UI-HUD-ActionBar-IconFrame-AddRow-Down")
        ns.Options:Set("hideButtonBorders", false)
        Stubs.RunTimers()
        T.eq(button.PushedTexture:GetAtlas(), "UI-HUD-ActionBar-IconFrame-AddRow-Down")
    end)
end)
