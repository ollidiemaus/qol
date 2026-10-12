local _, ns = ...

-- Our windows (the settings, /qol, with the rings' editor on its Ring page): the game's portrait
-- frame, which Forever draws in bronze, with the addon's icon as portrait and a title bar of ours to
-- move it by. Its close button hides it directly (the template's would go through the game's panel
-- code).
--
-- Escape closes it, and every other key goes on to the game. Not through UISpecialFrames: the game
-- closes those whenever one of its windows opens in the middle of the screen, the spell book too.
-- While the game's settings or its menu are open, Escape is theirs first.

-- The settings and the game menu take Escape before our windows, which open over them.
local function gameWindowOpen()
    return (SettingsPanel and SettingsPanel:IsShown()) or (GameMenuFrame and GameMenuFrame:IsShown())
end

-- template: PortraitFrameTemplate (the rock background, under a page of our own) or
-- PortraitFrameFlatTemplate (the flat dark one of the game's settings).
function ns.NewWindow(name, title, width, height, template)
    local window = CreateFrame("Frame", name, UIParent, template or "PortraitFrameTemplate")
    window:SetSize(width, height)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:SetDontSavePosition(true)
    window:EnableMouse(true)
    window:Hide()
    window:SetTitle(title)
    window:SetPortraitToAsset("Interface\\AddOns\\QoL\\Media\\Icon")
    window.CloseButton:SetScript("OnClick", function() window:Hide() end)
    -- A drag, not a mouse down: the controller's cursor would stop on a frame with OnMouseDown.
    local titleBar = CreateFrame("Frame", nil, window)
    titleBar:SetPoint("TOPLEFT", 58, 0)
    titleBar:SetPoint("TOPRIGHT", -24, 0)
    titleBar:SetHeight(21)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() window:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)

    -- Keeping a key is restricted in combat: there every key, Escape too, goes on to the game.
    window:EnableKeyboard(true)
    window:SetScript("OnKeyDown", function(_, key)
        if key ~= "ESCAPE" or InCombatLockdown() or gameWindowOpen() then return end
        window:SetPropagateKeyboardInput(false)
        window:Hide()
        -- Keys go on to the game again from the next frame (now this Escape would too), so the
        -- window lets them through when it opens next, in combat as well.
        ns.Later(name, function() window:SetPropagateKeyboardInput(true) end)
    end)
    return window
end

-- Shows a window made by ns.NewWindow, letting keys through.
function ns.ShowWindow(window)
    if not InCombatLockdown() then window:SetPropagateKeyboardInput(true) end
    window:Show()
end
