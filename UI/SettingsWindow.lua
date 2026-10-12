local _, ns = ...
local L = ns.L

-- The settings window (/qol, or the button on our information page under Options > AddOns): a
-- window of our own (ns.NewWindow, with the flat background of the game's settings) laid out like
-- the game's settings, with the list of pages on the left and the page shown on the right. The art
-- is the game's own (Options_InnerFrame, the list's header and highlights), which Forever draws in
-- bronze like the window's frame. The pages are UI/SettingsPage.lua's, and get the room the game's
-- settings give a page. Being outside the game's settings, nothing of ours runs inside them: on
-- Forever, with the controller interface on, the game froze now and then when they closed after a
-- change in them (see docs/DEVELOPMENT.md).
local Window = {}
Window.__index = Window
ns.SettingsWindow = Window

-- The game's settings panel (Blizzard_SettingsPanel.xml, 920×724) without its tabs, search box and
-- buttons: the inner frame (Options_InnerFrame, 886×618, drawn at its own size), the list in it and
-- the page right of the list.
local WIDTH, HEIGHT = 920, 696
local INNER_X, INNER_Y = 17, -60
local LIST_X, LIST_Y = 18, -72
local LIST_WIDTH = 199
local PAGE_GAP = 16    -- between the list and the page
local PAGE_RIGHT = 22  -- right of the page
local PAGE_HEIGHT = 601
-- The list as the game's draws it (Blizzard_CategoryList): a header, then a button per page.
local HEADER_HEIGHT = 30
local HEADER_LABEL_X = 20
local BUTTON_WIDTH, BUTTON_HEIGHT = 175, 20
local BUTTON_GAP = 2
local LABEL_X = 36

-- A list button as the game's list shows it: white on the selected page's highlight, else gold,
-- with the hover highlight under the mouse.
local function paint(button, selected)
    local texture = button.highlight
    if selected then
        button.label:SetFontObject("GameFontHighlight")
        texture:SetAtlas("Options_List_Active", true)
        texture:Show()
        return
    end
    button.label:SetFontObject("GameFontNormal")
    if button.over then
        texture:SetAtlas("Options_List_Hover", true)
        texture:Show()
    else
        texture:Hide()
    end
end

function Window.New()
    local frame = ns.NewWindow("QoLSettings", L.ADDON_TITLE, WIDTH, HEIGHT, "PortraitFrameFlatTemplate")
    local window = setmetatable({ frame = frame, pages = {}, buttons = {}, order = {} }, Window)

    local inner = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    inner:SetAtlas("Options_InnerFrame", true)
    inner:SetPoint("TOPLEFT", INNER_X, INNER_Y)

    -- The header's art reaches down behind the first buttons, so it's the list's own: its buttons,
    -- child frames, draw over it.
    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", LIST_X, LIST_Y)
    list:SetSize(LIST_WIDTH, PAGE_HEIGHT)
    local header = list:CreateTexture(nil, "BACKGROUND")
    header:SetAtlas("Options_CategoryHeader_1", true)
    header:SetPoint("TOPLEFT")
    local title = list:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    title:SetPoint("LEFT", list, "TOPLEFT", HEADER_LABEL_X, -HEADER_HEIGHT / 2 - 1)
    title:SetText(L.SETTINGS)
    window.list = list

    local container = CreateFrame("Frame", nil, frame)
    container:SetPoint("TOPLEFT", list, "TOPRIGHT", PAGE_GAP, 0)
    container:SetPoint("RIGHT", frame, "RIGHT", -PAGE_RIGHT, 0)
    container:SetHeight(PAGE_HEIGHT)
    window.container = container

    frame:SetScript("OnShow", function() window:Select(window.selected) end)
    return window
end

-- A page (a SettingsPage) and its button at the end of the list. The first page added is the one
-- shown first.
function Window:Add(key, title, page)
    local button = CreateFrame("Button", nil, self.list)
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    local y = HEADER_HEIGHT + BUTTON_GAP + #self.order * (BUTTON_HEIGHT + BUTTON_GAP)
    button:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
    button.highlight = button:CreateTexture(nil, "BACKGROUND")
    button.highlight:SetPoint("CENTER")
    button.highlight:Hide()
    button.label = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    button.label:SetPoint("TOPLEFT", LABEL_X, 1)
    button.label:SetPoint("BOTTOMRIGHT", 0, 1)
    button.label:SetJustifyH("LEFT")
    button.label:SetText(title)
    button:SetScript("OnClick", function()
        if self.selected == key then return end
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
        self:Select(key)
    end)
    button:SetScript("OnEnter", function()
        button.over = true
        paint(button, self.selected == key)
    end)
    button:SetScript("OnLeave", function()
        button.over = false
        paint(button, self.selected == key)
    end)

    page.frame:SetParent(self.container)
    page.frame:SetAllPoints(self.container)
    page.frame:Hide()
    self.order[#self.order + 1] = key
    self.pages[key], self.buttons[key] = page, button
    self.selected = self.selected or key
end

-- Shows a page (by its key; the first one for an unknown key), up to date, and lights its button.
function Window:Select(key)
    if not self.pages[key] then key = self.order[1] end
    if not key then return end
    self.selected = key
    for other, page in pairs(self.pages) do
        if other ~= key then page.frame:Hide() end
    end
    for other, button in pairs(self.buttons) do
        paint(button, other == key)
    end
    local page = self.pages[key]
    page.frame:Show()
    page:Refresh()
end

function Window:Open()
    if self.frame:IsShown() then
        self.frame:Raise()
        return
    end
    ns.ShowWindow(self.frame)
end

function Window:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
        return
    end
    self:Open()
end
