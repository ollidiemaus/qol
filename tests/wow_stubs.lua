-- Just enough of the WoW API to load the addon in plain Lua and drive it with events.
local Stubs = {}

-- A stand-in for a secret value: issecretvalue() is true only for this.
Stubs.SECRET = setmetatable({}, { __tostring = function() return "<SECRET>" end })

local state
Stubs.state = function() return state end

local function noop() end

-- Unknown widget methods do nothing, so UI code runs; methods whose results matter are real.
local function permissive(object)
    return setmetatable(object, {
        __index = function(_, key)
            if type(key) == "string" and key:find("^%u") then return noop end
            return nil
        end,
    })
end

local function newRegion(kind, parent, template)
    local region = { kind = kind, parent = parent, template = template, shown = true, points = {}, width = 0,
        height = 0, events = {}, scripts = {}, hooks = {}, effectiveScale = 1, enabled = true }
    function region:SetParent(newParent)
        if state.combat and self.protected then
            error("ADDON_ACTION_BLOCKED: SetParent on a protected frame in combat")
        end
        self.parent = newParent
    end
    function region:GetParent() return self.parent end
    local function checkShow(self)
        if state.combat and self.protected then
            error("ADDON_ACTION_BLOCKED: Show or Hide on a protected frame in combat")
        end
    end
    -- A frame's own OnShow and OnHide run when it is shown or hidden (not those of the frames under it).
    function region:SetShown(shown)
        checkShow(self)
        local was = self.shown
        self.shown = shown and true or false
        local script = was ~= self.shown and self.scripts[self.shown and "OnShow" or "OnHide"]
        if script then script(self) end
    end
    function region:Show() self:SetShown(true) end
    function region:Hide() self:SetShown(false) end
    function region:IsShown() return self.shown end
    function region:IsVisible()
        local node = self
        while node do
            if not node.shown then return false end
            node = node.parent
        end
        return true
    end
    function region:ClearAllPoints() self.points = {} end
    function region:SetPoint(point, relativeTo, relativePoint, x, y)
        if state.combat and self.protected then
            error("ADDON_ACTION_BLOCKED: SetPoint on a protected frame in combat")
        end
        self.points[#self.points + 1] = { point, relativeTo, relativePoint, x or 0, y or 0 }
    end
    function region:SetAllPoints(relativeTo)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0)
    end
    function region:GetNumPoints() return #self.points end
    function region:GetPoint(index)
        local p = self.points[index or 1]
        if not p then return nil end
        return p[1], p[2], p[3], p[4], p[5]
    end
    -- Where a point was set, by anchor point name.
    function region:PointFor(point)
        for _, p in ipairs(self.points) do
            if p[1] == point then return p end
        end
        return nil
    end
    function region:SetWidth(width) self.width = width end
    function region:SetHeight(height) self.height = height end
    function region:SetSize(width, height) self.width, self.height = width, height end
    function region:GetWidth() return self.width end
    function region:GetHeight() return self.height end
    function region:GetEffectiveScale() return self.effectiveScale end
    -- Where the middle is: set by secure code's SetPoint (Stubs' frame handles), else the parent's.
    function region:GetCenter()
        if self.center then return self.center[1], self.center[2] end
        if self.parent then return self.parent:GetCenter() end
        return nil
    end
    function region:SetRotation(radians) self.rotation = radians end
    function region:EnableGamePadStick(enabled) self.gamePadStick = enabled end
    function region:SetScale(scale) self.scale = scale end
    function region:GetScale() return self.scale or 1 end
    function region:SetFrameLevel(level) self.frameLevel = level end
    function region:SetFrameStrata(strata) self.strata = strata end
    function region:GetFrameStrata()
        if self.strata then return self.strata end
        if self.parent then return self.parent:GetFrameStrata() end
        return "MEDIUM"
    end
    function region:EnableKeyboard(enabled) self.keyboard = enabled end
    function region:SetPropagateKeyboardInput(propagate)
        if state.combat then error("ADDON_ACTION_BLOCKED: SetPropagateKeyboardInput in combat") end
        self.propagateKeyboard = propagate
    end
    function region:GetFrameLevel() return self.frameLevel or 1 end
    function region:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function region:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
    function region:SetAtlas(atlas) self.atlas = atlas end
    function region:GetAtlas() return self.atlas end
    -- A file replaces an atlas (GetAtlas is nil afterwards) but not its texture coordinates.
    function region:SetTexture(texture) self.texture, self.atlas = texture, nil end
    function region:SetTexCoord(...) self.texCoord = { ... } end
    function region:SetBlendMode(mode) self.blendMode = mode end
    function region:GetBlendMode() return self.blendMode or "BLEND" end
    function region:SetAlpha(alpha) self.alpha = alpha end
    function region:GetAlpha() return self.alpha or 1 end
    function region:SetDrawLayer(layer, sublevel) self.drawLayer = { layer, sublevel or 0 } end
    function region:GetDrawLayer()
        local layer = self.drawLayer or { "ARTWORK", 0 }
        return layer[1], layer[2]
    end
    function region:AddMaskTexture(mask)
        self.masks = self.masks or {}
        self.masks[mask] = true
    end
    function region:RemoveMaskTexture(mask)
        if self.masks then self.masks[mask] = nil end
    end
    function region:SetMaskTexture(mask) self.mask = mask end
    function region:SetTextColor(r, g, b) self.textColor = { r, g, b } end
    function region:GetTextColor()
        local c = self.textColor or { 1, 1, 1 }
        return c[1], c[2], c[3], 1
    end
    function region:SetMouseClickEnabled(enabled) self.mouseClickEnabled = enabled end
    function region:EnableMouse(enabled) self.mouseEnabled = enabled end
    function region:SetEnabled(enabled) self.enabled = enabled and true or false end
    function region:IsEnabled() return self.enabled end
    function region:SetText(text) self.text = text end
    function region:SetFormattedText(format, ...) self.text = format:format(...) end
    function region:GetText() return self.text end
    -- 5 units a character, whatever the font.
    function region:GetStringWidth() return #(self.text or "") * 5 end
    -- Wrapped at the width SetWidth gave it, a line as high as the font.
    function region:GetStringHeight()
        local lines = 1
        if self.width and self.width > 0 then lines = math.max(1, math.ceil(self:GetStringWidth() / self.width)) end
        return lines * (self.fontHeight or 12)
    end
    -- Fonts: a font object (by name) brings its file, height and flags (state.fonts); SetFont sets
    -- them directly.
    -- Like the client, the font object the text already has changes nothing: a font SetFont gave it
    -- stays (seen in game 2026-10-12: a font size set back to Default showed only after a reload).
    function region:SetFontObject(font)
        if font == self.font then return end
        self.font = font
        local known = state.fonts[font]
        if known then self.fontFile, self.fontHeight, self.fontFlags = known[1], known[2], known[3] end
    end
    function region:GetFontObject() return self.font end
    function region:SetFont(file, height, flags) self.fontFile, self.fontHeight, self.fontFlags = file, height, flags end
    function region:GetFont() return self.fontFile, self.fontHeight, self.fontFlags end
    function region:SetJustifyH(justify) self.justifyH = justify end
    function region:GetJustifyH() return self.justifyH or "CENTER" end
    function region:IsProtected() return self.protected == true end
    function region:CreateTexture()
        local texture = newRegion("Texture", self)
        return texture
    end
    function region:CreateMaskTexture()
        return newRegion("MaskTexture", self)
    end
    function region:CreateFontString(_, _, font)
        local text = newRegion("FontString", self)
        if font then text:SetFontObject(font) end
        return text
    end
    function region:RegisterEvent(event)
        if state.unknownEvents[event] then error("Attempt to register unknown event \"" .. event .. "\"") end
        self.events[event] = true
    end
    function region:SetScript(script, fn) self.scripts[script] = fn end
    function region:GetScript(script) return self.scripts[script] end
    function region:HookScript(script, fn) self.hooks[script] = fn end
    -- Runs a script the way the game does: the handler, then the hooks.
    function region:RunScript(script, ...)
        if self.scripts[script] then self.scripts[script](self, ...) end
        if self.hooks[script] then self.hooks[script](self, ...) end
    end
    function region:Click()
        if self.kind == "CheckButton" then self.checked = not self.checked end
        self:RunScript("OnClick", "LeftButton")
    end
    -- A button's state textures: an atlas each, and a highlight texture made on first use.
    function region:SetNormalAtlas(atlas) self.normalAtlas = atlas end
    function region:SetPushedAtlas(atlas) self.pushedAtlas = atlas end
    function region:SetHighlightTexture(file, blendMode)
        self.highlight = self.highlight or newRegion("Texture", self)
        self.highlight:SetTexture(file)
        self.highlight:SetBlendMode(blendMode)
    end
    function region:GetHighlightTexture() return self.highlight end
    function region:SetChecked(checked) self.checked = checked and true or false end
    function region:GetChecked() return self.checked == true end
    -- A dropdown (DropdownButton): SetupMenu keeps the generator, GenerateMenu builds the menu as
    -- a list of radios { text, isSelected, select } and shows the selected one's text. A click
    -- calls OpenMenu, which counts the menus opened in menusOpened.
    function region:SetupMenu(generator) self.generator = generator end
    function region:OpenMenu()
        if not self:IsEnabled() then return end
        self:GenerateMenu()
        self.menusOpened = (self.menusOpened or 0) + 1
    end
    function region:GenerateMenu()
        local root = { radios = {} }
        function root:CreateRadio(text, isSelected, select)
            self.radios[#self.radios + 1] = { text = text, isSelected = isSelected, select = select }
        end
        self.generator(self, root)
        self.menu = root.radios
        self.text = nil
        for _, radio in ipairs(root.radios) do
            if radio.isSelected() then self.text = radio.text end
        end
    end
    state.regions[#state.regions + 1] = region
    return permissive(region)
end
Stubs.NewFrame = function(parent) return newRegion("Frame", parent) end

-- An edit box takes the keyboard with SetFocus (one at a time, state.focus) and gives it up with
-- ClearFocus, running OnEditFocusGained and OnEditFocusLost as the game does.
function Stubs.MakeEditBox(box)
    function box:SetFocus()
        local old = state.focus
        if old == self then return end
        state.focus = self
        if old then old:RunScript("OnEditFocusLost") end
        self:RunScript("OnEditFocusGained")
    end
    function box:ClearFocus()
        if state.focus ~= self then return end
        state.focus = nil
        self:RunScript("OnEditFocusLost")
    end
    function box:HasFocus() return state.focus == self end
    function box:HighlightText(start, stop) self.highlighted = { start, stop } end
    return box
end

-- Typing into an edit box: it takes the keyboard, and its text becomes text.
function Stubs.Type(box, text)
    box:SetFocus()
    box:SetText(text)
end

-- MinimalSliderWithSteppersTemplate: a slider with a step arrow on each side and its value in
-- RightText. As in the game, a new value (dragged, stepped or set) fires OnValueChanged, the same
-- value again doesn't.
function Stubs.BuildSlider(frame)
    frame.Slider = newRegion("Slider", frame)
    frame.Back = newRegion("Button", frame)
    frame.Forward = newRegion("Button", frame)
    frame.RightText = newRegion("FontString", frame)
    frame.callbacks = {}
    local function step(direction)
        return function() frame:SetValue(frame.value + direction * frame.step) end
    end
    frame.Back:SetScript("OnClick", step(-1))
    frame.Forward:SetScript("OnClick", step(1))
    function frame:Init(value, minValue, maxValue, steps, formatters)
        self.minValue, self.maxValue = minValue, maxValue
        self.step = (maxValue - minValue) / steps
        self.formatters = formatters
        self.value = nil
        self:SetValue(value)
    end
    function frame:RegisterCallback(event, fn, owner) self.callbacks[event] = { fn = fn, owner = owner } end
    function frame:SetValue(value)
        value = math.max(self.minValue, math.min(self.maxValue, value))
        if value == self.value then return end
        self.value = value
        local format = self.formatters and self.formatters[_G.MinimalSliderWithSteppersMixin.Label.Right]
        if format then self.RightText:SetText(format(value)) end
        local callback = self.callbacks.OnValueChanged
        if callback then callback.fn(callback.owner, value) end
    end
    function frame:GetValue() return self.value end
end

-- The player picks a color in the open color picker (r, g, b from 0 to 1), or cancels it.
function Stubs.PickColor(r, g, b)
    local picker = _G.ColorPickerFrame
    picker.picked = { r, g, b }
    picker.info.swatchFunc()
end

function Stubs.CancelColor()
    local picker = _G.ColorPickerFrame
    picker:Hide()
    picker.info.cancelFunc()
end

-- A fake tooltip: records lines, has an owner and the info it is being built from (getterName and
-- getterArgs, as the game's SetX methods record them).
function Stubs.NewTooltip(owner, info)
    local tooltip = { lines = {}, owner = owner, info = info }
    function tooltip:AddLine(text, r, g, b) self.lines[#self.lines + 1] = { left = text, color = { r, g, b } } end
    function tooltip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = { left = left, right = right } end
    function tooltip:GetOwner() return self.owner end
    function tooltip:GetProcessingTooltipInfo() return self.info end
    return tooltip
end

-- Builds a tooltip like the game's data processor: each data line (unless a line pre-call drops
-- it), then the post calls for the tooltip type. The game's sell price line reads
-- "Sell Price: <price>c (game)".
function Stubs.ShowTooltip(typeName, data, tooltip)
    tooltip = tooltip or Stubs.NewTooltip()
    tooltip.info = tooltip.info or {}
    tooltip.info.tooltipData = data
    data.type = _G.Enum.TooltipDataType[typeName]
    for _, line in ipairs(data.lines or {}) do
        local dropped = false
        for _, fn in ipairs(state.linePreCalls[line.type] or {}) do
            if fn(tooltip, line) then dropped = true end
        end
        if not dropped and line.type == _G.Enum.TooltipDataLineType.SellPrice then
            tooltip:AddLine("Sell Price: " .. line.price .. "c (game)")
        end
    end
    for _, fn in ipairs(state.postCalls[data.type] or {}) do
        fn(tooltip, data)
    end
    return tooltip
end

-- A tooltip for the item in a bag slot, the way GameTooltip:SetBagItem(bag, slot) records it.
function Stubs.BagTooltip(bag, slot, owner)
    return Stubs.NewTooltip(owner, { getterName = "GetBagItem", getterArgs = { n = 2, bag, slot } })
end

-- Action bars are read-only to the addon: any write to a bar field fails the test.
function Stubs.NewActionBar(fields, numContainers)
    local raw = {
        numRows = 1, isHorizontal = true, addButtonsToTop = true, addButtonsToRight = true,
        buttonPadding = 2, minButtonPadding = 2, oldGridSettings = {}, shownButtonContainers = {},
    }
    for key, value in pairs(fields or {}) do raw[key] = value end
    for i = 1, numContainers or 12 do
        raw.shownButtonContainers[i] = Stubs.NewFrame(nil)
    end
    return setmetatable({}, {
        __index = raw,
        __newindex = function(_, key) error("the addon wrote bar field " .. tostring(key)) end,
    }), raw
end

-- An action button as ActionButtonTemplate builds it (45 units, or 30 for the stance and pet bars'
-- small buttons): the icon with its rounded mask, the frame and the textures drawn for it, the
-- cooldowns inset for the frame and the spell effects. Protected like the real buttons.
function Stubs.NewActionButton(small)
    local size = small and 30 or 45
    local frameWidth, frameHeight = small and 31.6 or 46, small and 30.9 or 45
    local button = newRegion("CheckButton", nil)
    button.protected = true
    button:SetSize(size, size)
    local function texture(atlas, width, height, blend, layer)
        local t = newRegion("Texture", button)
        t:SetAtlas(atlas)
        t:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        t:SetSize(width or frameWidth, height or frameHeight)
        if blend then t:SetBlendMode(blend) end
        t:SetDrawLayer(layer or "OVERLAY")
        return t
    end
    button.icon = newRegion("Texture", button)
    button.icon:SetAllPoints(button)
    button.icon:SetDrawLayer("BACKGROUND")
    button.IconMask = newRegion("MaskTexture", button)
    button.icon:AddMaskTexture(button.IconMask)
    button.SlotBackground = newRegion("Texture", button)
    button.SlotBackground:SetDrawLayer("BACKGROUND")
    button.SlotArt = newRegion("Texture", button)
    button.SlotArt:SetDrawLayer("BACKGROUND")
    button.NormalTexture = texture("UI-HUD-ActionBar-IconFrame", 46, 45)
    button.PushedTexture = texture("UI-HUD-ActionBar-IconFrame-Down", 46, 45)
    button.HighlightTexture = texture("UI-HUD-ActionBar-IconFrame-Mouseover", nil, nil, "ADD", "HIGHLIGHT")
    button.CheckedTexture = texture("UI-HUD-ActionBar-IconFrame-Mouseover", nil, nil, "ADD")
    button.NewActionTexture = texture("UI-HUD-ActionBar-IconFrame-Mouseover")
    button.Flash = texture("UI-HUD-ActionBar-IconFrame-Flash", nil, nil, nil, "ARTWORK")
    button.Border = texture("UI-HUD-ActionBar-IconFrame-Border")
    if small then
        -- The pet bar's own spell highlight, not drawn for the frame.
        button.SpellHighlightTexture = texture("bags-newitem", 38, 38, "ADD")
    else
        button.SpellHighlightTexture = texture("UI-HUD-ActionBar-IconFrame-Mouseover", nil, nil, "ADD")
    end
    local function cooldown(inset)
        local c = newRegion("Cooldown", button)
        c:SetPoint("TOPLEFT", button.icon, "TOPLEFT", inset, -inset)
        c:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", -inset, inset)
        return c
    end
    button.cooldown = cooldown(3)
    button.lossOfControlCooldown = cooldown(3)
    button.chargeCooldown = cooldown(2)
    button.SpellCastAnimFrame = newRegion("Frame", button)
    button.InterruptDisplay = newRegion("Frame", button)
    return button
end

-- A unit frame's health bar, read-only to the addon like action bars: its color and desaturation
-- change only through the widget methods, which work in combat too. It starts the way Blizzard
-- leaves these bars: white (the texture's own green shows) and not desaturated.
local function newHealthBar(unit)
    local raw = { unit = unit, color = { 1, 1, 1, 1 }, desaturated = false }
    function raw.SetStatusBarColor(_, r, g, b, a) raw.color = { r, g, b, a or 1 } end
    function raw.GetStatusBarColor() return raw.color[1], raw.color[2], raw.color[3], raw.color[4] end
    function raw.SetStatusBarDesaturated(_, desaturated) raw.desaturated = desaturated and true or false end
    function raw.IsStatusBarDesaturated() return raw.desaturated end
    return setmetatable({}, {
        __index = raw,
        __newindex = function(_, key) error("the addon wrote health bar field " .. tostring(key)) end,
    }), raw
end

-- The player frame as Mainline's PlayerFrame.xml builds it, as far as the addon looks at it: the
-- art (PlayerFrameContainer: the frame texture and the threat glow, FrameFlash), the protected
-- frame the bars sit on (PlayerFrameContent.PlayerFrameContentMain) and the fields
-- PlayerFrame_ToPlayerArt keeps: state ("player" or "vehicle"), activeAlternatePowerBar (Blizzard's
-- third bar) and classPowerBar. Read-only to the addon; Stubs.DrawPlayerFrame and Stubs.PlayerFrame
-- change it the way Blizzard does.
local GLOW_ATLAS = { player = "UI-HUD-UnitFrame-Player-PortraitOn-InCombat",
    vehicle = "UI-HUD-UnitFrame-Player-PortraitOn-Vehicle-InCombat" }
local GLOW_OFFSET = { player = { -1.5, 1 }, vehicle = { -3.5, 1 } }

local function newPlayerFrame(healthBar)
    local container = newRegion("Frame", nil)
    local main = newRegion("Frame", nil)
    main.protected = true
    local raw = { unit = "player", healthbar = healthBar, state = "player", PlayerFrameContainer = container,
        PlayerFrameContent = { PlayerFrameContentMain = main } }
    container.FrameTexture = container:CreateTexture()
    container.FrameTexture:SetAtlas("UI-HUD-UnitFrame-Player-PortraitOn")
    container.FrameFlash = container:CreateTexture()
    container.FrameFlash:SetAtlas(GLOW_ATLAS.player)
    container.FrameFlash:SetPoint("CENTER", container, "CENTER", -1.5, 1)
    state.playerFrame = raw
    return setmetatable({}, {
        __index = raw,
        __newindex = function(_, key) error("the addon wrote player frame field " .. tostring(key)) end,
    })
end

-- The world map: its canvas (1000 x 667 at zoom 1), its data providers and the map it shows.
-- Blizzard_WorldMap creates it; a test can drop it to load the map later (Stubs.LoadWorldMap).
function Stubs.NewWorldMap()
    local map = newRegion("Frame", _G.UIParent)
    map:Hide()
    map.providers = {}
    map.canvas = newRegion("Frame", map)
    map.canvas:SetSize(1000, 667)
    map.canvasScale = 1
    function map:AddDataProvider(provider)
        table.insert(self.providers, provider)
        provider:OnAdded(self)
    end
    function map:GetCanvas() return self.canvas end
    function map:GetCanvasScale() return self.canvasScale end
    function map:GetMapID() return self.mapID end
    function map:SetMapID(mapID)
        if self.mapID == mapID then return end
        self.mapID = mapID
        for _, provider in ipairs(self.providers) do provider:OnMapChanged() end
    end
    function map:GetPinFrameLevelsManager()
        return { GetValidFrameLevel = function(_, name) return name == "PIN_FRAME_LEVEL_DUNGEON_ENTRANCE" and 500 or 2 end }
    end
    return map
end

-- Opens the world map at a map, the way the game refreshes every provider when it shows.
function Stubs.OpenWorldMap(mapID)
    local map = _G.WorldMapFrame
    map.mapID = mapID
    map:Show()
    for _, provider in ipairs(map.providers) do provider:RefreshAllData(true) end
end

function Stubs.CloseWorldMap()
    local map = _G.WorldMapFrame
    map:Hide()
    for _, provider in ipairs(map.providers) do provider:OnHide() end
end

function Stubs.ZoomWorldMap(scale)
    local map = _G.WorldMapFrame
    map.canvasScale = scale
    for _, provider in ipairs(map.providers) do provider:OnCanvasScaleChanged() end
end

function Stubs.LoadWorldMap()
    _G.WorldMapFrame = Stubs.NewWorldMap()
    Stubs.Fire("ADDON_LOADED", "Blizzard_WorldMap")
end

-- The pins on the map: our buttons on the canvas that are shown, with where they are.
function Stubs.MapPins()
    local pins = {}
    for _, region in ipairs(state.regions) do
        if region.kind == "Button" and region.pin and region:IsVisible() then
            local point = region.points[1]
            pins[#pins + 1] = { pin = region.pin, button = region, x = point[4], y = point[5], size = region.width }
        end
    end
    return pins
end

local function split(delimiter, text)
    local parts = {}
    for part in (text .. delimiter):gmatch("(.-)" .. delimiter:gsub("%p", "%%%0")) do
        parts[#parts + 1] = part
    end
    return (unpack or table.unpack)(parts)
end

local function install()
    local G = _G
    G.issecretvalue = function(value) return value == Stubs.SECRET end
    G.strsplit = split
    G.strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
    G.unpack = G.unpack or table.unpack
    G.GetLocale = function() return state.locale end
    G.GetMoneyString = function(copper) return tostring(copper) .. "c" end
    G.SELL_PRICE = "Sell Price"
    G.NUM_BAG_SLOTS = 4
    G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
    G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) state.messages[#state.messages + 1] = text end }

    G.CreateFrame = function(kind, name, parent, template)
        local frame = newRegion(kind or "Frame", parent, template)
        if name then G[name] = frame end
        if template == "MinimalSliderWithSteppersTemplate" then Stubs.BuildSlider(frame) end
        if template == "ColorSwatchTemplate" then
            function frame:SetColorRGB(r, g, b) self.color = { r, g, b } end
        end
        -- A secure button or handler is protected, and so are the frames it is a child of: their
        -- attributes, points and visibility can't change in combat.
        if template and (template:find("SecureActionButtonTemplate") or template:find("SecureHandler")) then
            local node = frame
            while node do
                node.protected = true
                node = node.parent
            end
            frame.attributes = {}
            function frame:SetAttribute(attribute, value)
                if state.combat then error("ADDON_ACTION_BLOCKED: SetAttribute on a protected frame in combat") end
                self.attributes[attribute] = value
            end
            function frame:GetAttribute(attribute) return self.attributes[attribute] end
            function frame:RegisterForClicks(...) self.clicks = { ... } end
        end
        -- The game's key binding button: SetSelected lights it while it waits for a key.
        if template == "KeyBindingFrameBindingButtonTemplate" then
            function frame:SetSelected(selected) self.selected = selected end
        end
        -- The game's portrait frames: the close button, and the title (in titleText).
        if template == "PortraitFrameTemplate" or template == "PortraitFrameFlatTemplate" then
            frame.CloseButton = newRegion("Button", frame)
            function frame:SetTitle(title) self.titleText = title end
        end
        -- A tab of the game's tab system (TabSystemButtonMixin): Init names it, a selected tab is
        -- disabled, and a click calls SetTab on its parent, the tab system.
        if template == "TabSystemTopButtonTemplate" then
            function frame:Init(tabID, text)
                self.tabID, self.text, self.width = tabID, text, 92
                self:SetTabSelected(false)
            end
            function frame:SetTabSelected(selected)
                self.isSelected = selected
                self:SetEnabled(not selected)
            end
            frame:SetScript("OnClick", function(self)
                local system, was = self:GetParent(), self.isSelected
                system:SetTab(self.tabID, true)
                if not was and self.isSelected then system:PlayTabSelectSound() end
            end)
        end
        -- A side tab (SidePanelTabButtonMixin): its icon, SetChecked showing the selected art, a mouse
        -- up calling the handler SetCustomOnMouseUpHandler gave, and tooltipText on hover.
        if template == "LargeSideTabButtonTemplate" then
            frame.Icon = newRegion("Texture", frame)
            frame.SelectedTexture = newRegion("Texture", frame)
            function frame:SetChecked(checked) self.SelectedTexture:SetShown(checked) end
            function frame:SetCustomOnMouseUpHandler(handler) self.customMouseUpHandler = handler end
            frame:SetScript("OnMouseUp", function(self, button, upInside)
                if self.customMouseUpHandler then self.customMouseUpHandler(self, button, upInside) end
            end)
            frame:SetScript("OnEnter", function(self)
                if not self.tooltipText then return end
                G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                G.GameTooltip:SetText(self.tooltipText)
                G.GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", function() G.GameTooltip:Hide() end)
        end
        if kind == "EditBox" then Stubs.MakeEditBox(frame) end
        if kind == "StatusBar" then
            function frame:SetStatusBarTexture(texture) self.statusBarTexture = texture end
            function frame:SetMinMaxValues(minValue, maxValue) self.minValue, self.maxValue = minValue, maxValue end
            function frame:GetMinMaxValues() return self.minValue or 0, self.maxValue or 1 end
            function frame:SetValue(value) self.value = value end
            function frame:GetValue() return self.value or 0 end
            function frame:SetMouseMotionEnabled(enabled) self.mouseMotion = enabled end
        end
        if kind == "Cooldown" then
            function frame:SetCooldownFromDurationObject(duration) self.duration = duration end
            function frame:SetCooldown(start, duration) self.duration = { start = start, seconds = duration } end
            function frame:Clear() self.duration = nil end
        end
        return frame
    end
    -- The game's color picker: SetupColorPickerAndShow keeps the info; Stubs.PickColor picks a color.
    G.ColorPickerFrame = newRegion("Frame", nil)
    G.ColorPickerFrame:Hide()
    function G.ColorPickerFrame:SetupColorPickerAndShow(info)
        self.info, self.picked = info, { info.r, info.g, info.b }
        self:Show()
    end
    function G.ColorPickerFrame:GetColorRGB() return self.picked[1], self.picked[2], self.picked[3] end
    function G.ColorPickerFrame:GetPreviousValues() return self.info.r, self.info.g, self.info.b end
    G.UIParent = newRegion("Frame", nil)
    G.UIParent.center = { 960, 540 }
    G.WorldFrame = newRegion("Frame", nil)
    G.WorldFrame.protected = true
    G.WorldFrame:SetAllPoints(nil)
    G.GetPhysicalScreenSize = function() return state.screenWidth, state.screenHeight end
    G.GetFramerate = function() return state.framerate end
    G.GetNetStats = function() return 0, 0, state.latencyHome, state.latencyWorld end
    -- Cutscenes: shown while an in-engine cinematic or a movie plays.
    G.CinematicFrame = newRegion("Frame", nil)
    G.CinematicFrame:Hide()
    G.MovieFrame = newRegion("Frame", nil)
    G.MovieFrame:Hide()

    G.InCombatLockdown = function() return state.combat end
    G.ReloadUI = function() state.reloads = state.reloads + 1 end
    -- Other addons that are loaded (state.loadedAddons, by folder), and our TOC's version
    -- (Stubs.LoadAddon({ version = ... }), else none, as in an unpackaged checkout).
    G.C_AddOns = {
        IsAddOnLoaded = function(name) return state.loadedAddons[name] == true end,
        GetAddOnMetadata = function(_, field)
            if field == "Version" then return state.version end
            return nil
        end,
    }
    -- C_Timer.After(0) runs on the next RunTimers; a real delay waits for AdvanceTime.
    G.C_Timer = {
        After = function(seconds, fn)
            local queue = seconds > 0 and state.delayed or state.timers
            queue[#queue + 1] = fn
        end,
    }
    -- The interface style: Stubs.SetControllerUI switches to the controller interface.
    G.C_InputInterfaceStyle = { GetCurrentStyle = function() return state.interfaceStyle end }
    -- Forever's manager of the windows that have the controller: Stubs.SetControllerWindow sets the
    -- one it has.
    G.GamepadMode = { FrameControlsManager = { GetActiveFrame = function() return state.controllerWindow end } }
    G.C_EventUtils = { IsEventValid = function(event) return not state.unknownEvents[event] end }
    G.EventRegistry = {
        RegisterCallback = function(_, event, fn, owner)
            state.registry[event] = state.registry[event] or {}
            table.insert(state.registry[event], { fn = fn, owner = owner })
        end,
    }

    G.Enum = {
        ItemQuality = { Poor = 0, Common = 1 },
        TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Currency = 5, UnitAura = 7, Achievement = 12, Toy = 19,
            Quest = 23 },
        TooltipDataLineType = { SellPrice = 11 },
        InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 },
        PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3 },
    }
    G.TooltipDataProcessor = {
        AddTooltipPostCall = function(tooltipType, fn)
            state.postCalls[tooltipType] = state.postCalls[tooltipType] or {}
            table.insert(state.postCalls[tooltipType], fn)
        end,
        AddLinePreCall = function(lineType, fn)
            state.linePreCalls[lineType] = state.linePreCalls[lineType] or {}
            table.insert(state.linePreCalls[lineType], fn)
        end,
    }

    -- Bags and items
    G.C_Container = {
        GetContainerNumSlots = function(bag) return state.bags[bag] and state.bags[bag].size or 0 end,
        GetContainerItemInfo = function(bag, slot) return state.bags[bag] and state.bags[bag][slot] end,
        UseContainerItem = function(bag, slot) table.insert(state.used, bag .. ":" .. slot) end,
        SortBags = function() state.bagSorts = state.bagSorts + 1 end,
    }
    G.BAG_CLEANUP_BAGS = "Clean Up Bags"
    G.BAG_CLEANUP_BAGS_DESCRIPTION = "Sort the items in your bags."
    G.C_Item = {
        GetItemInfo = function(itemID)
            local price = state.prices[itemID]
            if price == nil then return nil end
            return "Item " .. itemID, nil, 0, 1, 1, "Junk", "Junk", 1, "", 0, price
        end,
    }

    -- Merchant
    G.C_MerchantFrame = {
        IsSellAllJunkEnabled = function() return state.sellAllEnabled end,
        SellAllJunkItems = function() state.soldAll = state.soldAll + 1 end,
    }
    G.CanMerchantRepair = function() return state.canRepair end
    G.GetRepairAllCost = function() return state.repairCost, state.repairCost > 0 end
    G.RepairAllItems = function(guild) table.insert(state.repairs, guild and "guild" or "own") end
    G.GetMoney = function() return state.money end
    G.IsInGuild = function() return state.inGuild end
    G.CanGuildBankRepair = function() return state.guildCanRepair end
    G.GetGuildBankWithdrawMoney = function() return state.guildLimit end
    G.GetGuildBankMoney = function() return state.guildMoney end

    -- Frames the addon hides
    G.MicroMenuContainer = newRegion("Frame", G.UIParent)
    G.BagsBar = newRegion("Frame", G.UIParent)
    G.QuickJoinToastButton = newRegion("Frame", G.UIParent)
    -- Edit Mode, closed, with no frames yet (Stubs.NewEditModeFrame adds them).
    G.EditModeManagerFrame = newRegion("Frame", G.UIParent)
    G.EditModeManagerFrame:Hide()
    G.EditModeManagerFrame.registeredSystemFrames = {}
    -- The combined bag starts closed and empty (Stubs.FillCombinedBag); its sort button belongs to
    -- the backpack and starts hidden. Each script's hooks run in turn from hooks[script].
    G.ContainerFrameCombinedBags = newRegion("Frame", G.UIParent)
    G.ContainerFrameCombinedBags:Hide()
    G.ContainerFrameCombinedBags.hooks = {}
    function G.ContainerFrameCombinedBags:HookScript(script, fn)
        local before = self.hooks[script]
        self.hooks[script] = before and function(...) before(...) fn(...) end or fn
    end
    G.ContainerFrameCombinedBags.MoneyFrame = newRegion("Frame", G.ContainerFrameCombinedBags)
    G.ContainerFrameCombinedBags.Items = {}
    G.ContainerFrame1 = newRegion("Frame", G.UIParent)
    G.BagItemSearchBox = newRegion("Frame", G.ContainerFrame1)
    G.BagItemAutoSortButton = newRegion("Frame", G.ContainerFrame1)
    G.BagItemAutoSortButton:Hide()
    -- The mail frame, closed, with its Send Mail tab (hidden while the Inbox tab shows) and that tab's
    -- To and Subject boxes.
    G.MailFrame = newRegion("Frame", G.UIParent)
    G.MailFrame:Hide()
    G.SendMailFrame = newRegion("Frame", G.MailFrame)
    G.SendMailFrame:Hide()
    G.SendMailNameEditBox = Stubs.MakeEditBox(newRegion("EditBox", G.SendMailFrame))
    G.SendMailSubjectEditBox = Stubs.MakeEditBox(newRegion("EditBox", G.SendMailFrame))
    -- Chat: the combat log window and its tab, and the buttons next to ChatFrame1.
    G.ChatFrame2 = newRegion("Frame", G.UIParent)
    G.ChatFrame2Tab = newRegion("Button", G.UIParent)
    G.ChatFrame1ButtonFrame = newRegion("Frame", G.UIParent)
    G.ChatFrameMenuButton = newRegion("Button", G.ChatFrame1ButtonFrame)
    G.ChatFrameChannelButton = newRegion("Button", G.ChatFrame1ButtonFrame)
    G.ChatFrameToggleVoiceDeafenButton = newRegion("Button", G.UIParent)
    G.ChatFrameToggleVoiceMuteButton = newRegion("Button", G.UIParent)
    G.TextToSpeechButtonFrame = newRegion("Frame", G.UIParent)
    -- The tooltip the controller interface shows for new buffs.
    G.BuffFrameTooltip = newRegion("Frame", G.UIParent)

    -- The minimap as Forever builds it: the cluster with its header bar and zone text button, the
    -- container with the map, the round frame and the coordinates under the map.
    G.MinimapCluster = newRegion("Frame", G.UIParent)
    local cluster = G.MinimapCluster
    cluster.BorderTop = newRegion("Frame", cluster)
    cluster.BorderTop:SetPoint("TOP", cluster, "TOP", 15, -4)
    cluster.ZoneTextButton = newRegion("Button", cluster)
    cluster.ZoneTextButton:SetSize(135, 12)
    cluster.ZoneTextButton:SetPoint("LEFT", cluster.BorderTop, "LEFT", 4, 0)
    G.MinimapZoneText = newRegion("FontString", cluster.ZoneTextButton)
    G.MinimapZoneText:SetFontObject("GameFontNormal")
    G.MinimapZoneText:SetSize(130, 12)
    G.MinimapZoneText:SetJustifyH("LEFT")
    G.MinimapZoneText:SetTextColor(1, 0.82, 0)
    local minimapContainer = newRegion("Frame", cluster)
    cluster.MinimapContainer = minimapContainer
    G.Minimap = newRegion("Minimap", minimapContainer)
    G.Minimap:SetSize(198, 198)
    G.Minimap:SetMaskTexture("ui-hud-minimap-frame-generic-mask")
    local backdrop = newRegion("Frame", G.Minimap)
    G.MinimapCompassTexture = newRegion("Texture", backdrop)
    G.MinimapCompassTextureUnderlay = newRegion("Texture", backdrop)
    minimapContainer.PlayerCoords = newRegion("Frame", minimapContainer)
    minimapContainer.PlayerCoords:SetPoint("BOTTOM", G.Minimap, "BOTTOM", 0, -18)
    minimapContainer.PlayerCoords.CoordText = newRegion("FontString", minimapContainer.PlayerCoords)
    -- The buttons around it: tracking left of the header bar, clock and calendar on its right, the
    -- addon compartment under the calendar, and Forever's day and night icon on the round frame.
    cluster.Tracking = newRegion("Frame", cluster)
    cluster.Tracking:SetSize(17, 17)
    cluster.Tracking:SetPoint("RIGHT", cluster.BorderTop, "LEFT", -2, 0)
    G.TimeManagerClockButton = newRegion("Button", cluster)
    G.TimeManagerClockButton:SetSize(40, 16)
    G.TimeManagerClockButton:SetPoint("TOPRIGHT", cluster.BorderTop, "TOPRIGHT", -4, 0)
    G.TimeManagerClockTicker = newRegion("FontString", G.TimeManagerClockButton)
    G.TimeManagerClockTicker:SetFontObject("WhiteNormalNumberFont")
    G.GameTimeFrame = newRegion("Button", cluster)
    G.GameTimeFrame:SetSize(19, 18)
    G.GameTimeFrame:SetPoint("TOPLEFT", cluster.BorderTop, "TOPRIGHT", 1, 0)
    G.AddonCompartmentFrame = newRegion("Button", cluster)
    G.AddonCompartmentFrame:SetSize(16, 16)
    G.AddonCompartmentFrame:SetPoint("TOPLEFT", G.GameTimeFrame, "BOTTOMLEFT", 0, 0)
    cluster.DielFrame = newRegion("Frame", cluster)
    cluster.DielFrame:SetSize(42, 42)
    cluster.DielFrame:SetPoint("CENTER", cluster, "CENTER", 63, 72)
    G.C_Texture = {
        GetAtlasInfo = function(atlas) return state.atlases[atlas] end,
    }

    -- Key bindings: state.bindings[key] = command (the saved ones), state.overrides[key] = { owner,
    -- command } (override bindings). Changing bindings is blocked in combat.
    local function sortedKeys(map)
        local keys = {}
        for key in pairs(map) do keys[#keys + 1] = key end
        table.sort(keys)
        return keys
    end
    G.GetBindingKey = function(command)
        local keys = {}
        for _, key in ipairs(sortedKeys(state.bindings)) do
            if state.bindings[key] == command then keys[#keys + 1] = key end
        end
        return (unpack or table.unpack)(keys)
    end
    G.GetBindingAction = function(key, checkOverride)
        local override = checkOverride and state.overrides[key]
        if override then return override.command end
        return state.bindings[key] or ""
    end
    G.SetBinding = function(key, command)
        if state.combat then error("ADDON_ACTION_BLOCKED: binding changed in combat") end
        state.bindings[key] = command
        return true
    end
    -- Saving the bindings counts the saves of each set in state.bindingSaves.
    G.GetCurrentBindingSet = function() return 1 end
    G.SaveBindings = function(set)
        if state.combat then error("ADDON_ACTION_BLOCKED: bindings saved in combat") end
        state.bindingSaves[set] = (state.bindingSaves[set] or 0) + 1
    end
    G.GetBindingText = function(key) return key end
    G.GetBindingName = function(command) return G["BINDING_NAME_" .. command] or command end
    G.NOT_BOUND = "Not Bound"
    local metaKeys = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
    G.IsKeyPressIgnoredForBinding = function(key) return metaKeys[key] == true end
    G.CreateKeyChordStringUsingMetaKeyState = function(key) return (state.shift and "SHIFT-" or "") .. key end
    local function override(owner, key, command)
        if state.combat then error("ADDON_ACTION_BLOCKED: binding changed in combat") end
        state.overrides[key] = command and { owner = owner, command = command } or nil
        state.overrideCalls = state.overrideCalls + 1
    end
    G.SetOverrideBinding = function(owner, _, key, command) override(owner, key, command) end
    G.SetOverrideBindingClick = function(owner, _, key, button, mouseButton)
        override(owner, key, "CLICK " .. button .. ":" .. (mouseButton or "LeftButton"))
    end
    G.ClearOverrideBindings = function(owner)
        if state.combat then error("ADDON_ACTION_BLOCKED: binding changed in combat") end
        for _, key in ipairs(sortedKeys(state.overrides)) do
            if state.overrides[key].owner == owner then state.overrides[key] = nil end
        end
    end

    -- The controller interface's own bindings: state.gamepadBindings[key] = command.
    G.Enum.BindingContext = { None = 0, GamepadModeInGameCore = 1 }
    G.C_KeyBindings = {
        GetBindingContextForAction = function() return G.Enum.BindingContext.None end,
        GetBindingByKey = function(key, context)
            if context == G.Enum.BindingContext.GamepadModeInGameCore then return state.gamepadBindings[key] end
            return state.bindings[key]
        end,
    }

    -- Action slots: state.actions[slot] = { texture, usable (default true), noMana, count, cooldown,
    -- current, autoRepeat }. state.cursor is what PickupAction took; PlaceAction records the slot.
    local function action(slot)
        assert(type(slot) == "number" and slot >= 1 and slot <= 180, "valid action slot")
        return state.actions[slot]
    end
    G.C_ActionBar = {
        HasAction = function(slot) return action(slot) ~= nil end,
        GetActionTexture = function(slot) return (action(slot) or {}).texture end,
        IsUsableAction = function(slot)
            local a = action(slot)
            if not a then return false, false end
            return a.usable ~= false, a.noMana == true
        end,
        GetActionDisplayCount = function(slot) return (action(slot) or {}).count or "" end,
        GetActionCooldownDuration = function(slot) return (action(slot) or {}).cooldown or { seconds = 0 } end,
        IsCurrentAction = function(slot) return (action(slot) or {}).current == true end,
        IsAutoRepeatAction = function(slot) return (action(slot) or {}).autoRepeat == true end,
    }
    G.IsModifiedClick = function(name) return state.modifiedClicks[name] == true end
    G.PickupAction = function(slot) state.cursor = action(slot) and slot end
    G.PlaceAction = function(slot) state.placed[#state.placed + 1] = slot end
    G.GetCursorInfo = function()
        if state.cursorInfo then return unpack(state.cursorInfo) end
        if state.cursor then return "action", state.cursor end
        return nil
    end
    G.ClearCursor = function() state.cursor, state.cursorInfo = nil, nil end
    -- An action's tooltip: its name (state.actions[slot].name) on the first line.
    G.C_TooltipInfo = {
        GetAction = function(slot)
            local a = action(slot)
            return a and { lines = { { leftText = a.name } } } or nil
        end,
    }

    -- What a ring holds, as this character has it. state.spells[id] = { name, texture, usable,
    -- noMana, consumable, charges, count, cooldown } for the spells it knows; state.items[id] = { name,
    -- texture, count, equipped, usable, consumable, stack, cooldown = { start, duration } } for the
    -- items (count 0: not in the bags); state.toys[id] = { usable } for the toys it has (item data
    -- in state.items); state.mounts[id] = { name, spellID, texture, usable, collected, hidden };
    -- state.macros = { { name, texture, spell, item }, ... }. Picking one up puts it in
    -- state.cursorInfo, as GetCursorInfo returns it.
    local function spell(id) return state.spells[id] end
    local function item(id) return state.items[id] end
    G.C_Spell = {
        GetSpellTexture = function(id) return (spell(id) or {}).texture end,
        GetSpellName = function(id) return (spell(id) or {}).name end,
        IsSpellUsable = function(id)
            local info = spell(id) or {}
            return info.usable ~= false, info.noMana == true
        end,
        IsConsumableSpell = function(id) return (spell(id) or {}).consumable == true end,
        GetSpellCharges = function(id) return (spell(id) or {}).charges end,
        GetSpellDisplayCount = function(id) return (spell(id) or {}).count or "" end,
        GetSpellCooldownDuration = function(id) return (spell(id) or {}).cooldown or { seconds = 0 } end,
        PickupSpell = function(id)
            if spell(id) then state.cursorInfo = { "spell", 1, "spell", id, id } end
        end,
    }
    G.C_Spell.GetSpellSubtext = function(id) return (spell(id) or {}).subtext end
    -- The spell book: one line of state.spellBook's slots ({ id, passive, offSpec, flyout }), or
    -- without it the known spells by ID. A flyout's slots: state.flyouts[id] = { { spellID, known } }.
    local function bookSlots()
        if state.spellBook then return state.spellBook end
        local ids = {}
        for id in pairs(state.spells) do ids[#ids + 1] = id end
        table.sort(ids)
        local slots = {}
        for index, id in ipairs(ids) do slots[index] = { id = id } end
        return slots
    end
    G.Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }
    G.Enum.SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 }
    G.C_SpellBook = {
        IsSpellKnownOrInSpellBook = function(id) return spell(id) ~= nil end,
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function()
            return { itemIndexOffset = 0, numSpellBookItems = #bookSlots(), shouldHide = false }
        end,
        GetSpellBookItemInfo = function(slot)
            local s = bookSlots()[slot]
            if not s then return nil end
            return { actionID = s.id, itemType = s.flyout and 4 or 1, isPassive = s.passive == true,
                isOffSpec = s.offSpec == true }
        end,
    }
    G.GetFlyoutInfo = function(id)
        local slots = state.flyouts[id]
        return "Flyout " .. id, "", slots and #slots or 0, slots ~= nil
    end
    G.GetFlyoutSlotInfo = function(id, slot)
        local s = state.flyouts[id][slot]
        return s.spellID, s.spellID, s.known ~= false
    end
    -- An item with a use has a spell (state.items[id].use, its spell ID); state.equipped[slot] = id.
    G.C_Item.GetItemSpell = function(id)
        local info = item(id)
        if info and info.use then return "Use " .. tostring(info.name), info.use end
    end
    G.GetInventoryItemID = function(_, slot) return state.equipped[slot] end
    G.C_Item.GetItemCount = function(id) return (item(id) or {}).count or 0 end
    G.C_Item.IsEquippedItem = function(id) return (item(id) or {}).equipped == true end
    G.C_Item.GetItemIconByID = function(id) return (item(id) or {}).texture end
    G.C_Item.GetItemNameByID = function(id) return (item(id) or {}).name end
    G.C_Item.IsUsableItem = function(id)
        local info = item(id) or {}
        return info.usable ~= false, false
    end
    G.C_Item.IsConsumableItem = function(id) return (item(id) or {}).consumable == true end
    G.C_Item.GetItemMaxStackSizeByID = function(id) return (item(id) or {}).stack or 1 end
    G.C_Item.GetItemCooldown = function(id)
        local cooldown = (item(id) or {}).cooldown or { 0, 0 }
        return cooldown[1], cooldown[2], true
    end
    G.C_Item.GetItemInfoInstant = function(link) return tonumber(tostring(link):match("item:(%d+)")) end
    G.C_Item.PickupItem = function(id) state.cursorInfo = { "item", id, "item:" .. id } end
    G.PlayerHasToy = function(id) return state.toys[id] ~= nil end
    -- The toy box lists the toys this character has, by ID (its filter shows them all).
    G.C_ToyBox = {
        IsToyUsable = function(id) return (state.toys[id] or {}).usable ~= false end,
        PickupToyBoxItem = function(id) state.cursorInfo = { "item", id, "item:" .. id } end,
        GetNumFilteredToys = function() return #sortedKeys(state.toys) end,
        GetToyFromIndex = function(index) return sortedKeys(state.toys)[index] or -1 end,
        GetToyInfo = function(id)
            local info = item(id) or {}
            return id, info.name, info.texture
        end,
    }
    G.C_MountJournal = {
        GetMountInfoByID = function(id)
            local m = state.mounts[id]
            if not m then return nil end
            return m.name, m.spellID, m.texture, false, m.usable ~= false, 0, false, false, nil, m.hidden == true,
                m.collected ~= false, id
        end,
        GetMountIDs = function() return sortedKeys(state.mounts) end,
        GetMountFromSpell = function(spellID)
            for id, m in pairs(state.mounts) do
                if m.spellID == spellID then return id end
            end
            return nil
        end,
    }
    local function macroIndex(nameOrIndex)
        if type(nameOrIndex) == "number" then return state.macros[nameOrIndex] and nameOrIndex end
        for index, m in ipairs(state.macros) do
            if m.name == nameOrIndex then return index end
        end
        return nil
    end
    G.GetMacroIndexByName = function(name) return macroIndex(name) or 0 end
    -- All of state.macros are the account's.
    G.GetNumMacros = function() return #state.macros, 0 end
    G.MAX_ACCOUNT_MACROS = 120
    G.GetMacroInfo = function(nameOrIndex)
        local m = state.macros[macroIndex(nameOrIndex) or 0]
        if m then return m.name, m.texture, "" end
    end
    G.GetMacroSpell = function(index) return (state.macros[index] or {}).spell end
    G.GetMacroItem = function(index)
        local id = (state.macros[index] or {}).item
        if id then return "Item " .. id, "item:" .. id end
    end
    G.PickupMacro = function(nameOrIndex)
        local index = macroIndex(nameOrIndex)
        if index then state.cursorInfo = { "macro", index } end
    end

    G.GetCursorPosition = function() return state.cursorX, state.cursorY end
    -- Two sticks, as the controller settings name them.
    G.C_GamePad = {
        GetDeviceMappedState = function() return state.gamepad end,
        StickIndexToConfigName = function(index) return ({ [0] = "Movement", [1] = "Camera" })[index] end,
    }
    -- The game's Lua 5.1 has math.atan2; newer Lua only math.atan(y, x).
    G.math.atan2 = G.math.atan2 or function(y, x) return math.atan(y, x) end
    -- Secure handlers: the wrapped snippets, which Stubs.SecureClick runs.
    G.SecureHandlerWrapScript = function(frame, script, header, preBody, postBody)
        frame.wraps = frame.wraps or {}
        frame.wraps[script] = { header = header, pre = preBody, post = postBody }
    end

    -- Settings the client keeps (C_CVar), as strings.
    G.C_CVar = {
        GetCVar = function(name) return state.cvars[name] end,
        GetCVarDefault = function(name) return state.cvarDefaults[name] end,
        SetCVar = function(name, value)
            state.cvars[name] = tostring(value)
            table.insert(state.cvarSets, name .. "=" .. tostring(value))
        end,
    }

    -- Quest givers: state.quest holds what the NPC offers; every call the addon makes is recorded.
    local quest = function() return state.quest end
    local function record(call) table.insert(state.quest.calls, call) end
    G.IsShiftKeyDown = function() return state.shift end
    G.UnitGUID = function(unit) if unit == "npc" then return quest().npc end return nil end
    G.C_GossipInfo = {
        GetActiveQuests = function() return quest().gossipActive end,
        GetAvailableQuests = function() return quest().gossipAvailable end,
        SelectActiveQuest = function(questID) record("gossipActive:" .. questID) end,
        SelectAvailableQuest = function(questID) record("gossipAvailable:" .. questID) end,
    }
    G.GetNumActiveQuests = function() return #quest().greetingActive end
    G.GetActiveTitle = function(i) local q = quest().greetingActive[i] return q.title, q.isComplete end
    G.GetActiveQuestID = function(i) return quest().greetingActive[i].questID end
    G.SelectActiveQuest = function(i) record("greetingActive:" .. i) end
    G.GetNumAvailableQuests = function() return #quest().greetingAvailable end
    G.GetAvailableQuestInfo = function(i) return false, 0, false, false, quest().greetingAvailable[i].questID end
    G.SelectAvailableQuest = function(i) record("greetingAvailable:" .. i) end
    G.AcceptQuest = function() record("accept") end
    G.QuestGetAutoAccept = function() return quest().autoAccept end
    G.QuestIsFromAdventureMap = function() return false end
    G.IsQuestCompletable = function() return quest().completable end
    G.GetQuestMoneyToGet = function() return quest().money end
    G.CompleteQuest = function() record("complete") end
    G.GetNumQuestChoices = function() return quest().choices end
    G.GetQuestReward = function(choice) record("reward:" .. choice) end

    -- The world map: a MapCanvas with its data providers, at state.worldMap.
    G.Enum.UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3 }
    G.CreateFromMixins = function(...)
        local object = {}
        for i = 1, select("#", ...) do
            for key, value in pairs((select(i, ...))) do object[key] = value end
        end
        return object
    end
    G.MapCanvasDataProviderMixin = {
        OnAdded = function(self, map) self.owningMap = map end,
        GetMap = function(self) return self.owningMap end,
        OnMapChanged = function(self) self:RefreshAllData() end,
        RefreshAllData = noop, RemoveAllData = noop, OnShow = noop, OnHide = noop, OnCanvasScaleChanged = noop,
    }
    G.C_Map = {
        GetMapInfo = function(mapID) return state.maps[mapID] end,
        GetMapRectOnMap = function(mapID, topMapID)
            local rect = state.mapRects[mapID .. ">" .. topMapID]
            if not rect then return nil end
            return rect[1], rect[2], rect[3], rect[4]
        end,
        GetAreaInfo = function(areaID) return state.areas[areaID] end,
    }
    G.WorldMapFrame = Stubs.NewWorldMap()
    G.GameTooltip = { lines = {} }
    function G.GameTooltip:SetOwner(owner) self.owner, self.lines, self.shown = owner, {}, false end
    function G.GameTooltip:SetText(text) self.lines = { { text = text } } end
    function G.GameTooltip:AddLine(text, r, g, b) table.insert(self.lines, { text = text, color = { r, g, b } }) end
    function G.GameTooltip:SetAction(slot) self.action, self.lines = slot, {} end
    function G.GameTooltip:SetSpellByID(id) self.spell, self.lines = id, {} end
    function G.GameTooltip:SetItemByID(id) self.item, self.lines = id, {} end
    function G.GameTooltip:SetToyByItemID(id) self.toy, self.lines = id, {} end
    function G.GameTooltip:SetMountBySpellID(id) self.mountSpell, self.lines = id, {} end
    function G.GameTooltip:IsOwned(owner) return self.owner == owner end
    function G.GameTooltip:Show() self.shown = true end
    function G.GameTooltip:Hide() self.shown = false end

    -- Units: state.units[unit] = { isPlayer, treatAsPlayer, class }; a unit that isn't there doesn't exist.
    G.UnitIsPlayer = function(unit)
        local info = state.units[unit]
        if info and info.isPlayer ~= nil then return info.isPlayer end
        return false
    end
    G.UnitTreatAsPlayerForDisplay = function(unit)
        local info = state.units[unit]
        return info ~= nil and info.treatAsPlayer == true
    end
    -- On Forever (state.regionalNames) a character's surname comes where retail gives the realm.
    G.UnitName = function(unit)
        local info = state.units[unit]
        if not info then return nil end
        return info.name, info.surname
    end
    G.RegionalUniqueNamesEnabled = function() return state.regionalNames == true end
    G.GetNormalizedRealmName = function() return state.realm end
    G.UnitClass = function(unit)
        local info = state.units[unit]
        if not (info and info.class) then return nil end
        return "Localized " .. tostring(info.class), info.class, 1
    end
    -- Power: info.powerType (an Enum.PowerType, mana when not set), info.mana and info.maxMana, and
    -- info.power and info.maxPower for the other types.
    G.UnitPowerType = function(unit)
        local info = state.units[unit]
        return info and info.powerType or G.Enum.PowerType.Mana
    end
    G.UnitPower = function(unit, powerType)
        local info = state.units[unit] or {}
        if powerType == G.Enum.PowerType.Mana then return info.mana or 0 end
        return info.power or 0
    end
    G.UnitPowerMax = function(unit, powerType)
        local info = state.units[unit] or {}
        if powerType == G.Enum.PowerType.Mana then return info.maxMana or 0 end
        return info.maxPower or 0
    end
    G.AbbreviateLargeNumbers = function(value) return tostring(value) end
    G.RAID_CLASS_COLORS = {
        MAGE = { r = 0.25, g = 0.78, b = 0.92 },
        PRIEST = { r = 1, g = 1, b = 1 },
        ROGUE = { r = 1, g = 0.96, b = 0.41 },
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    }

    -- Unit frames, each with the health bar UnitFrame_Initialize stores in frame.healthbar.
    state.healthBars = {}
    for name, unit in pairs({ PlayerFrame = "player", TargetFrame = "target", TargetFrameToT = "targettarget",
        FocusFrame = "focus", FocusFrameToT = "focustarget" }) do
        local bar, raw = newHealthBar(unit)
        state.healthBars[name] = raw
        G[name] = { unit = unit, healthbar = bar }
    end
    G.PlayerFrame = newPlayerFrame(G.PlayerFrame.healthbar)

    -- Action bar layout helpers: record what the addon asks for.
    G.GridLayoutUtil = {
        CreateStandardGridLayout = function(stride, xPadding, yPadding, xMultiplier, yMultiplier)
            return { kind = "standard", stride = stride, xPadding = xPadding, yPadding = yPadding,
                xMultiplier = xMultiplier, yMultiplier = yMultiplier }
        end,
        CreateVerticalGridLayout = function(stride, xPadding, yPadding, xMultiplier, yMultiplier)
            return { kind = "vertical", stride = stride, xPadding = xPadding, yPadding = yPadding,
                xMultiplier = xMultiplier, yMultiplier = yMultiplier }
        end,
        ApplyGridLayout = function(regions, anchor, layout)
            if state.combat then error("ADDON_ACTION_BLOCKED: button containers moved in combat") end
            table.insert(state.layouts, { regions = regions, anchor = anchor, layout = layout })
        end,
    }
    G.AnchorUtil = {
        CreateAnchor = function(point, relativeTo, relativePoint)
            return { point = point, relativeTo = relativeTo, relativePoint = relativePoint }
        end,
    }
    -- The game's slider template (MinimalSliderWithSteppersTemplate), with or without the Settings API.
    G.MinimalSliderWithSteppersMixin = { Label = { Right = 2 }, Event = { OnValueChanged = "OnValueChanged" } }
end

-- Globals the addon or a test may leave behind.
local ADDON_GLOBALS = {
    "QoLDB", "SLASH_QOL1", "SLASH_QOL2", "SlashCmdList", "Settings",
    "CreateSettingsListSectionHeaderInitializer", "MinimalSliderWithSteppersMixin",
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar",
    "SLASH_QOL_RELOAD1", "hash_SlashCmdList", "IsSecureCmd", "SLASH_OTHERADDON1", "SLASH_RELOAD1",
    "HUD_EDIT_MODE_ACTION_BAR_LABEL", "HUD_EDIT_MODE_STANCE_BAR_LABEL", "HUD_EDIT_MODE_PET_ACTION_BAR_LABEL",
    "GetMinimapShape", "HybridMinimap", "TimeManagerClockButton", "GameTimeFrame", "AddonCompartmentFrame",
    "TimeManagerClockTicker", "QoLNoAction", "ColorPickerFrame", "SettingsPanel", "GameMenuFrame",
    "GamepadMainActionBarFrame", "BINDING_HEADER_QOL",
    "QoLRing", "QoLRingButton", "QoLRingEditor", "QoLSettings",
}
for index = 1, 4 do
    ADDON_GLOBALS[#ADDON_GLOBALS + 1] = "QoLBackButton" .. index
    ADDON_GLOBALS[#ADDON_GLOBALS + 1] = "BINDING_NAME_CLICK QoLBackButton" .. index .. ":LeftButton"
end

function Stubs.Reset(options)
    options = options or {}
    state = {
        locale = options.locale or "enUS",
        version = options.version, loadedAddons = {},
        regions = {}, timers = {}, delayed = {}, messages = {}, registry = {}, postCalls = {}, linePreCalls = {},
        unknownEvents = options.unknownEvents or {},
        combat = false,
        interfaceStyle = 0,
        screenWidth = 2560, screenHeight = 1440,
        framerate = 59.7, latencyHome = 45, latencyWorld = 38,
        bags = {}, prices = {}, used = {}, bagSorts = 0, soldAll = 0, sellAllEnabled = true,
        canRepair = false, repairCost = 0, repairs = {}, money = 0,
        inGuild = false, guildCanRepair = false, guildLimit = 0, guildMoney = 0,
        layouts = {}, reloads = 0,
        units = { player = { isPlayer = true, class = "MAGE", name = "Testmage" } }, realm = "TestRealm",
        regionalNames = false,
        focus = nil,
        atlases = { ["ui-hud-minimap-frame-generic-mask"] = { width = 215, height = 226 } },
        fonts = { GameFontNormal = { "Fonts\\FRIZQT__.TTF", 12, "" },
            WhiteNormalNumberFont = { "Fonts\\ARIALN.TTF", 10, "OUTLINE" } },
        cvars = { chatClassColorOverride = "2" }, cvarDefaults = { chatClassColorOverride = "2" }, cvarSets = {},
        shift = false,
        quest = { npc = "Creature-0-1-0-1-3139-0001", gossipActive = {}, gossipAvailable = {}, greetingActive = {},
            greetingAvailable = {}, autoAccept = false, completable = true, money = 0, choices = 0, calls = {} },
        -- A few of Forever's maps; a retail client has none of them (state.maps = {}).
        maps = { [1413] = { name = "The Barrens", mapType = 3, parentMapID = 1414 },
            [1414] = { name = "Kalimdor", mapType = 2, parentMapID = 947 } },
        mapRects = {}, areas = {},
        -- The default bindings for the action bar's buttons and pages.
        bindings = {
            ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", ["3"] = "ACTIONBUTTON3", ["4"] = "ACTIONBUTTON4",
            ["5"] = "ACTIONBUTTON5", ["6"] = "ACTIONBUTTON6",
            ["SHIFT-1"] = "ACTIONPAGE1", ["SHIFT-2"] = "ACTIONPAGE2", ["SHIFT-3"] = "ACTIONPAGE3",
            ["SHIFT-4"] = "ACTIONPAGE4", ["SHIFT-5"] = "ACTIONPAGE5", ["SHIFT-6"] = "ACTIONPAGE6",
            ["SHIFT-MOUSEWHEELUP"] = "PREVIOUSACTIONPAGE", ["SHIFT-MOUSEWHEELDOWN"] = "NEXTACTIONPAGE",
        },
        overrides = {}, overrideCalls = 0, gamepadBindings = {}, bindingSaves = {},
        actions = {}, modifiedClicks = {}, placed = {}, settingValues = {},
        spells = {}, items = {}, toys = {}, mounts = {}, macros = {}, flyouts = {}, equipped = {},
        -- The cursor in UI units, the controller's sticks (nil: no controller) and the actions
        -- secure buttons used.
        cursorX = 500, cursorY = 400, gamepad = nil, usedActions = {},
    }
    for _, name in ipairs(ADDON_GLOBALS) do _G[name] = nil end
    _G.SlashCmdList = {}
    install()
end

local function tocFiles()
    local files = {}
    for rawLine in io.lines("QoL.toc") do
        local line = rawLine:gsub("\r", "")
        if line ~= "" and not line:find("^#") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return files
end

-- Loads every file the TOC lists, in order, into a fresh namespace.
function Stubs.LoadAddon(options)
    Stubs.Reset(options)
    local ns = {}
    for _, path in ipairs(tocFiles()) do
        local chunk = assert(loadfile(path))
        chunk("QoL", ns)
    end
    return ns
end

function Stubs.Fire(event, ...)
    for _, region in ipairs(state.regions) do
        if region.events[event] and region.scripts.OnEvent then
            region.scripts.OnEvent(region, event, ...)
        end
    end
end

function Stubs.TriggerRegistry(event, ...)
    for _, callback in ipairs(state.registry[event] or {}) do
        callback.fn(callback.owner, ...)
    end
end

-- Lets the delayed C_Timer callbacks come due, then runs everything that is due.
function Stubs.AdvanceTime()
    local delayed = state.delayed
    state.delayed = {}
    for _, fn in ipairs(delayed) do state.timers[#state.timers + 1] = fn end
    Stubs.RunTimers()
end

local function onUpdateDue()
    for _, region in ipairs(state.regions) do
        if region.scripts.OnUpdate and region:IsVisible() then return true end
    end
    return false
end

-- One drawn frame: the C_Timer callbacks that are due, then the OnUpdate of every visible frame.
function Stubs.NextFrame()
    local timers = state.timers
    state.timers = {}
    for _, fn in ipairs(timers) do fn() end
    for _, region in ipairs(state.regions) do
        local onUpdate = region.scripts.OnUpdate
        if onUpdate and region:IsVisible() then onUpdate(region, 0) end
    end
    Stubs.RenderEditMode()
end

-- Draws frames until no timer is due and no frame has an OnUpdate to run (each may start more).
function Stubs.RunTimers()
    local guard = 0
    while #state.timers > 0 or onUpdateDue() do
        Stubs.NextFrame()
        guard = guard + 1
        assert(guard < 100, "the addon keeps scheduling work, frame after frame")
    end
end

local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

-- A key typed on the keyboard: the shown frames that take the keyboard get it, the highest strata
-- first, until one keeps it (it passes it on with SetPropagateKeyboardInput(true), also when set in
-- its OnKeyDown). Returns whether it reached the game's key bindings.
function Stubs.TypeKey(key)
    local takers = {}
    for _, region in ipairs(state.regions) do
        if region.keyboard and region:IsVisible() then takers[#takers + 1] = region end
    end
    table.sort(takers, function(a, b) return STRATA[a:GetFrameStrata()] > STRATA[b:GetFrameStrata()] end)
    for _, region in ipairs(takers) do
        if region.scripts.OnKeyDown then region.scripts.OnKeyDown(region, key) end
        if not region.propagateKeyboard then return false end
    end
    return true
end

-- A controller button pressed, taken by every shown frame with an OnGamePadButtonDown.
function Stubs.PressGamePadButton(key)
    for _, region in ipairs(state.regions) do
        local script = region.scripts.OnGamePadButtonDown
        if script and region:IsVisible() then script(region, key) end
    end
end

function Stubs.SetControllerUI(on)
    state.interfaceStyle = on and 1 or 0
end

-- A window of the game with the controller (shown), or none with nil.
function Stubs.SetControllerWindow(window)
    state.controllerWindow = window
end

-- Forever's controller action bar, with the anchors of its page unit: the middle of the d-pad
-- buttons (left) and of the face buttons (right). Call between LoadAddon and Login.
function Stubs.NewGamepadBar()
    local bar = _G.CreateFrame("Frame", "GamepadMainActionBarFrame", _G.UIParent)
    bar.PageUnit = _G.CreateFrame("Frame", nil, bar)
    bar.PageUnit.LeftCenteredAnchor = _G.CreateFrame("Frame", nil, bar.PageUnit)
    bar.PageUnit.RightCenteredAnchor = _G.CreateFrame("Frame", nil, bar.PageUnit)
    return bar
end

-- Secure code: frame handles that may do what restricted snippets may, in combat too.
local function descendants(region)
    local list = {}
    for _, other in ipairs(state.regions) do
        local node = other
        while node and node ~= region do node = node.parent end
        if node then list[#list + 1] = other end
    end
    return list
end

-- Shows or hides a frame and runs OnShow or OnHide of every frame under it that appears or goes.
local function setShownSecurely(region, shown)
    local list = descendants(region)
    local was = {}
    for index, other in ipairs(list) do was[index] = other:IsVisible() end
    region.shown = shown
    for index, other in ipairs(list) do
        local now = other:IsVisible()
        local script = now ~= was[index] and other.scripts[now and "OnShow" or "OnHide"]
        if script then script(other) end
    end
end

local function frameHandle(region)
    local handle = {}
    function handle:GetAttribute(name) return region.attributes[name] end
    function handle:SetAttribute(name, value) region.attributes[name] = value end
    function handle:Show() setShownSecurely(region, true) end
    function handle:Hide() setShownSecurely(region, false) end
    function handle:IsShown() return region.shown end
    function handle:GetWidth() return region.width end
    function handle:ClearAllPoints() region.points, region.center = {}, nil end
    -- Points are kept as the frame's middle, for GetCenter and GetMousePosition.
    function handle:SetPoint(point, relativeTo, relativePoint, x, y)
        assert(point == "CENTER", "only CENTER points")
        if relativeTo == "$cursor" then
            region.center = { state.cursorX, state.cursorY }
        else
            assert(relativeTo == "$parent" and relativePoint == "CENTER", "$cursor or the parent's CENTER")
            local parentX, parentY = region.parent:GetCenter()
            region.center = { parentX + (x or 0), parentY + (y or 0) }
        end
        region.points[#region.points + 1] = { point, relativeTo, relativePoint, x or 0, y or 0 }
    end
    -- The cursor relative to the frame, 0 to 1 across it, or nil outside it.
    function handle:GetMousePosition()
        local x = (state.cursorX - region.center[1]) / region.width + 0.5
        local y = (state.cursorY - region.center[2]) / region.height + 0.5
        if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
        return x, y
    end
    return handle
end

local function compile(body, env)
    if setfenv then return setfenv(assert(loadstring(body)), env) end
    return assert(load(body, "snippet", "t", env))
end

-- The restricted environment, one per header as in the game, with owner its handle.
local function runSnippet(header, frame, body, ...)
    header.snippetEnv = header.snippetEnv or {
        owner = frameHandle(header), math = math, string = string, tostring = tostring, tonumber = tonumber,
        strmatch = string.match, GetGamePadState = function() return state.gamepad end,
    }
    local chunk = compile("local self, button, down = ...\n" .. body, header.snippetEnv)
    return chunk(frameHandle(frame), ...)
end

-- A secure attribute as SecureButton_GetModifiedAttribute finds it without modifiers held.
local function modifiedAttribute(button, name, suffix)
    local attributes = button.attributes
    for _, key in ipairs({ name .. suffix, "*" .. name .. suffix, name .. "*", "*" .. name .. "*", name }) do
        if attributes[key] ~= nil then return attributes[key] end
    end
    return nil
end

-- One half of a click on a secure action button, as a CLICK binding sends it (key down, then up):
-- the wrapped OnClick snippet, then the action, on the half useOnKeyDown picks (the game's default
-- is the key going down). Actions used go to state.usedActions: an action slot, or "spell:133",
-- "item:item:6948", "toy:54452", "macro:Name" for the other types.
function Stubs.SecureClick(button, down, mouseButton)
    mouseButton = mouseButton or "LeftButton"
    local wrap = button.wraps and button.wraps.OnClick
    if wrap then
        local result = runSnippet(wrap.header, button, wrap.pre, mouseButton, down)
        if result == false then return end
        if result ~= nil then mouseButton = tostring(result) end
    end
    local onDown = button.attributes.useOnKeyDown ~= false
    if onDown ~= (down == true) then return end
    local suffix = mouseButton == "LeftButton" and "1" or ("-" .. mouseButton)
    local actionType = modifiedAttribute(button, "type", suffix)
    if actionType == "action" then
        state.usedActions[#state.usedActions + 1] = modifiedAttribute(button, "action", suffix)
    elseif actionType then
        state.usedActions[#state.usedActions + 1] = actionType .. ":" .. tostring(modifiedAttribute(button, actionType, suffix))
    end
end

-- A key with an override binding that clicks a button, going down (true), up (false) or both (nil).
function Stubs.PressOverride(key, down)
    local entry = assert(state.overrides[key], "an override binding for " .. key)
    local name, mouseButton = entry.command:match("^CLICK ([^:]+):(.+)$")
    local button = assert(_G[name], name)
    if down ~= false then Stubs.SecureClick(button, true, mouseButton) end
    if down ~= true then Stubs.SecureClick(button, false, mouseButton) end
end

-- A key bound to a secure button, pressed and let go.
function Stubs.PressKey(button)
    Stubs.SecureClick(button, true)
    Stubs.SecureClick(button, false)
end

function Stubs.SetCursor(x, y)
    state.cursorX, state.cursorY = x, y
end

-- A controller with its camera stick (the second) at x, y; nil for no controller.
function Stubs.SetStick(x, y)
    if x == nil then
        state.gamepad = nil
        return
    end
    state.gamepad = { stickCount = 2, sticks = {
        { x = 0, y = 0, len = 0 },
        { x = x, y = y, len = math.sqrt(x * x + y * y) },
    } }
end

function Stubs.SetCombat(inCombat)
    state.combat = inCombat
    if not inCombat then
        Stubs.Fire("PLAYER_REGEN_ENABLED")
    end
end

-- Loads the saved variables (options, rings, the characters seen), logs in and lets every deferred
-- change run.
function Stubs.Login(savedOptions, savedRings, savedCharacters)
    _G.QoLDB = (savedOptions or savedRings or savedCharacters)
        and { options = savedOptions, rings = savedRings, characters = savedCharacters } or nil
    Stubs.Fire("ADDON_LOADED", "QoL")
    Stubs.Fire("PLAYER_LOGIN")
    Stubs.Fire("PLAYER_ENTERING_WORLD")
    Stubs.RunTimers()
end

-- The parts of the Settings API the panel uses, recording what was registered. Call before Login.
function Stubs.InstallSettings()
    local api = { settings = {}, controls = {}, categories = {}, headers = {} }

    local function newInitializer(setting, control, extra)
        local initializer = { setting = setting, control = control }
        for key, value in pairs(extra or {}) do initializer[key] = value end
        function initializer:SetParentInitializer(parent, predicate)
            self.parent, self.predicate = parent, predicate
        end
        api.controls[#api.controls + 1] = initializer
        if setting then setting.initializer = initializer end
        return initializer
    end

    local function newCategory(name, parent, frame)
        local category = { name = name, parent = parent, frame = frame, id = #api.categories + 100, headers = {} }
        function category:GetID() return self.id end
        local layout = {
            AddInitializer = function(_, initializer)
                if initializer.header then category.headers[#category.headers + 1] = initializer.header end
            end,
        }
        api.categories[#api.categories + 1] = category
        return category, layout
    end

    _G.Settings = {
        VarType = { Boolean = "boolean", String = "string", Number = "number" },
        -- The game's own settings, by variable: state.settingValues.
        GetValue = function(variable) return state.settingValues[variable] end,
        RegisterVerticalLayoutCategory = function(name) return newCategory(name) end,
        RegisterVerticalLayoutSubcategory = function(parent, name) return newCategory(name, parent) end,
        RegisterCanvasLayoutCategory = function(frame, name) return newCategory(name, nil, frame) end,
        RegisterCanvasLayoutSubcategory = function(parent, frame, name) return newCategory(name, parent, frame) end,
        RegisterProxySetting = function(category, variable, varType, name, default, get, set)
            assert(api.settings[variable] == nil, "setting registered twice: " .. variable)
            local setting = { category = category, variable = variable, varType = varType, name = name,
                default = default, get = get, set = set }
            api.settings[variable] = setting
            return setting
        end,
        CreateCheckbox = function(_, setting, tooltip) return newInitializer(setting, "checkbox", { tooltip = tooltip }) end,
        CreateSlider = function(_, setting, options, tooltip)
            return newInitializer(setting, "slider", { options = options, tooltip = tooltip })
        end,
        CreateSliderOptions = function(minValue, maxValue, rate)
            local options = { minValue = minValue, maxValue = maxValue, rate = rate }
            function options:SetLabelFormatter(_, formatter) self.formatter = formatter end
            return options
        end,
        CreateColorSwatch = function(_, setting, tooltip) return newInitializer(setting, "color", { tooltip = tooltip }) end,
        CreateDropdown = function(_, setting, options, tooltip)
            return newInitializer(setting, "dropdown", { options = options, tooltip = tooltip })
        end,
        CreateControlTextContainer = function()
            local container = { data = {} }
            function container:Add(value, label) table.insert(self.data, { value = value, label = label }) end
            function container:GetData() return self.data end
            return container
        end,
        RegisterAddOnCategory = function(category) api.registered = category end,
        OpenToCategory = function(id) api.opened = id end,
    }
    _G.CreateSettingsListSectionHeaderInitializer = function(text, tooltip) return { header = text, tooltip = tooltip } end
    return api
end

-- Puts a unit in the world (info: isPlayer, treatAsPlayer, class), or removes it with nil.
function Stubs.SetUnit(unit, info)
    state.units[unit] = info
end

-- The player frame's raw fields (state, activeAlternatePowerBar, classPowerBar, ...), for tests to
-- change the way Blizzard does.
function Stubs.PlayerFrame()
    return state.playerFrame
end

-- Blizzard draws the player frame again (PlayerFrame_UpdateArt, on entering the world and on the
-- vehicle events): the player's or a vehicle's art, which sets the threat glow's atlas and place.
function Stubs.DrawPlayerFrame(vehicle)
    local frame = state.playerFrame
    frame.state = vehicle and "vehicle" or "player"
    local container = frame.PlayerFrameContainer
    container.FrameFlash:SetAtlas(GLOW_ATLAS[frame.state])
    local offset = GLOW_OFFSET[frame.state]
    container.FrameFlash:SetPoint("CENTER", container, "CENTER", offset[1], offset[2])
end

-- The raw state of a unit frame's health bar (unit, color, desaturated), by frame name. Tests
-- change bar.unit here, the way Blizzard switches the player frame to a vehicle.
function Stubs.HealthBar(frameName)
    return state.healthBars[frameName]
end

-- The whole bag contents: items ={ { bag, slot, itemID, quality, count, price, hasNoValue } }.
function Stubs.SetBags(items)
    state.bags = {}
    for bag = 0, 5 do state.bags[bag] = { size = 16 } end
    for _, item in ipairs(items) do
        state.bags[item.bag][item.slot] = {
            itemID = item.itemID, quality = item.quality, stackCount = item.count or 1,
            hasNoValue = item.hasNoValue or false, isLocked = item.isLocked or false,
        }
        state.prices[item.itemID] = item.price
    end
end

-- Fills the combined bag the way Blizzard makes its item buttons: sizes[1] is the backpack's size,
-- sizes[2] the first bag's and so on, and Items runs from the last bag's last slot to the
-- backpack's first. extended lists "bag:slot" of locked extra slots. Lays them out as Blizzard does.
function Stubs.FillCombinedBag(sizes, extended)
    local bag = _G.ContainerFrameCombinedBags
    bag.Items = {}
    for bagID = #sizes - 1, 0, -1 do
        for slot = sizes[bagID + 1], 1, -1 do
            local button = newRegion("Button", bag)
            button.attributes, button.slot = { bagid = bagID }, slot
            function button:GetAttribute(name) return self.attributes[name] end
            function button:GetID() return self.slot end
            button.isExtended = extended and extended[bagID .. ":" .. slot] or nil
            button:SetSize(37, 37)
            bag.Items[#bag.Items + 1] = button
        end
    end
    Stubs.LayoutCombinedBag()
end

-- Blizzard's layout of the combined bag with keyboard and mouse (ContainerFrameMixin:UpdateItemLayout):
-- by bag and slot, locked extra slots last, 10 to a row from the bottom right of the money frame
-- leftwards and upwards, 5 apart.
function Stubs.LayoutCombinedBag()
    local bag = _G.ContainerFrameCombinedBags
    local sorted = {}
    for _, button in ipairs(bag.Items) do sorted[#sorted + 1] = button end
    table.sort(sorted, function(a, b)
        if (a.isExtended or false) ~= (b.isExtended or false) then return not a.isExtended end
        if a.attributes.bagid ~= b.attributes.bagid then return a.attributes.bagid < b.attributes.bagid end
        return a.slot < b.slot
    end)
    for index, button in ipairs(sorted) do
        local cell = index - 1
        button:ClearAllPoints()
        button:SetPoint("BOTTOMRIGHT", bag.MoneyFrame, "TOPRIGHT", -(cell % 10) * 42, 4 + math.floor(cell / 10) * 42)
    end
end

-- The combined bag's item button for a bag and slot.
function Stubs.CombinedBagButton(bagID, slot)
    for _, button in ipairs(_G.ContainerFrameCombinedBags.Items) do
        if button.attributes.bagid == bagID and button.slot == slot then return button end
    end
    return nil
end

-- Blizzard's EditModeSystemMixin:UpdateClampOffsets: the frame's clamp insets go from its edges to
-- its selection box's.
function Stubs.EditModeClamp(frame)
    local selection = frame.Selection
    frame:SetClampRectInsets(selection:GetLeft() - frame:GetLeft(), selection:GetRight() - frame:GetRight(),
        selection:GetTop() - frame:GetTop(), selection:GetBottom() - frame:GetBottom())
end

-- An Edit Mode frame at left, bottom with a size, its selection box `margin` bigger on every side
-- (smaller for a negative one), and Edit Mode's clamp. clampSets counts the SetClampRectInsets calls.
-- Like the game's, its own ClearAllPoints and SetPoint sit in its metatable, and Edit Mode puts Lua
-- of its own over both (EditModeSystemMixin:OnSystemLoad), counted in overrideCalls. anchorings
-- counts the own ClearAllPoints calls. The game lays a frame out only after its anchors changed
-- (Stubs.RenderEditMode, at the end of a drawn frame): laidOutUnder is the clamp it was laid out
-- under, so whether the clamp let it past the edge.
function Stubs.NewEditModeFrame(left, bottom, width, height, margin, protected)
    local frame = newRegion("Frame", _G.UIParent)
    frame.protected = protected
    frame.Selection = newRegion("Frame", frame)
    frame.rect = { left, bottom, width, height }
    frame.Selection.rect = { left - margin, bottom - margin, width + 2 * margin, height + 2 * margin }
    for _, region in ipairs({ frame, frame.Selection }) do
        function region:GetLeft() return self.rect[1] end
        function region:GetBottom() return self.rect[2] end
        function region:GetRight() return self.rect[1] + self.rect[3] end
        function region:GetTop() return self.rect[2] + self.rect[4] end
    end
    frame.clamp, frame.clampSets = { 0, 0, 0, 0 }, 0
    function frame:SetClampRectInsets(l, r, t, b)
        if state.combat and self.protected then
            error("ADDON_ACTION_BLOCKED: SetClampRectInsets on a protected frame in combat")
        end
        self.clamp = { l, r, t, b }
        self.clampSets = self.clampSets + 1
    end
    function frame:GetClampRectInsets() return self.clamp[1], self.clamp[2], self.clamp[3], self.clamp[4] end

    local ownSetPoint, ownClearAllPoints = frame.SetPoint, frame.ClearAllPoints
    local methods = setmetatable({}, getmetatable(frame))
    function methods.SetPoint(self, ...)
        ownSetPoint(self, ...)
        self.layoutDirty = true
    end
    function methods.ClearAllPoints(self)
        ownClearAllPoints(self)
        self.layoutDirty = true
        self.anchorings = self.anchorings + 1
    end
    setmetatable(frame, { __index = methods })
    frame.anchorings, frame.overrideCalls = 0, 0
    function frame:SetPoint(...)
        self.overrideCalls = self.overrideCalls + 1
        methods.SetPoint(self, ...)
    end
    function frame:ClearAllPoints()
        self.overrideCalls = self.overrideCalls + 1
        methods.ClearAllPoints(self)
    end

    methods.SetPoint(frame, "BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", left, bottom)
    table.insert(_G.EditModeManagerFrame.registeredSystemFrames, frame)
    Stubs.EditModeClamp(frame)
    Stubs.RenderEditMode()
    return frame
end

-- The game lays out the Edit Mode frames whose anchors changed, under the clamp they have now.
function Stubs.RenderEditMode()
    for _, frame in ipairs(_G.EditModeManagerFrame.registeredSystemFrames) do
        if frame.layoutDirty then
            frame.layoutDirty = false
            frame.laidOutUnder = { frame.clamp[1], frame.clamp[2], frame.clamp[3], frame.clamp[4] }
        end
    end
end

-- Edit Mode applies a layout to a frame (EditModeSystemMixin:UpdateSystem): ApplySystemAnchor
-- anchors it again with Edit Mode's SetPoint, then UpdateClampOffsets.
function Stubs.ApplyEditModeLayout(frame)
    local points = {}
    for index = 1, frame:GetNumPoints() do points[index] = { frame:GetPoint(index) } end
    frame:ClearAllPoints()
    for _, point in ipairs(points) do frame:SetPoint(unpack(point)) end
    Stubs.EditModeClamp(frame)
end

-- Edit Mode opens: Blizzard highlights every frame, which sets its clamp again, then tells
-- EventRegistry. Draw frames with Stubs.NextFrame while it's open (Stubs.RunTimers would never end).
function Stubs.OpenEditMode()
    local manager = _G.EditModeManagerFrame
    manager:Show()
    for _, frame in ipairs(manager.registeredSystemFrames) do Stubs.EditModeClamp(frame) end
    Stubs.TriggerRegistry("EditMode.Enter")
    Stubs.RenderEditMode()
end

-- Edit Mode closes: RevertAllChanges applies the saved layout again, then EventRegistry hears of it,
-- and the game draws the frame.
function Stubs.CloseEditMode()
    local manager = _G.EditModeManagerFrame
    for _, frame in ipairs(manager.registeredSystemFrames) do Stubs.ApplyEditModeLayout(frame) end
    manager:Hide()
    Stubs.TriggerRegistry("EditMode.Exit")
    Stubs.RenderEditMode()
end

return Stubs
