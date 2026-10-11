local addonName, ns = ...
local L = ns.L

-- Quality of Life's own entry under Options > AddOns, which /qol opens: what the addon is, the chat
-- commands and the author's other addons, as on AutoPotion's information page. It has no options (so
-- no Defaults button) and, like the other pages, fits without scrolling below the same title bar. All
-- frames are ours and are made at login, like the other pages'.
local InfoPage = {}
InfoPage.__index = InfoPage
ns.InfoPage = InfoPage

local MARGIN = 8           -- between the page's sides and the text, as on the other pages
local TOP = 54             -- the title bar above the text
local TEXT_X = 7           -- text starts where the other pages' names do
local SECTION_GAP = 22
local LINE_GAP = 6
local ENTRY_GAP = 12
local COMMAND_WIDTH = 90
local ADDON_ICON_SIZE = 36
local ICON_GAP = 10
local LINK_WIDTH, LINK_HEIGHT = 300, 20
local LINK_BORDER = 5 -- InputBoxTemplate draws its border this far outside the box

local COMMANDS = {
    { command = "/qol", about = L.INFO_COMMAND_SETTINGS },
    { command = "/qol ring", about = L.INFO_COMMAND_RING },
    { command = "/rl", about = L.INFO_COMMAND_RELOAD },
}

-- The author's other addons. The icons are copies of each addon's own icon, so they show without the
-- addon installed; name is also its folder, for the Installed label. flavors are product names and
-- stay untranslated.
local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
local OTHER_ADDONS = {
    {
        name = "AutoPotion",
        flavors = "Retail · Classic · WoW Forever",
        url = "https://www.curseforge.com/wow/addons/auto-potion",
        about = L.INFO_AUTOPOTION,
    },
    {
        name = "AutoSetup",
        flavors = "Retail · WoW Forever",
        url = "https://www.curseforge.com/wow/addons/autosetup",
        about = L.INFO_AUTOSETUP,
    },
    {
        name = "Wayscribe",
        flavors = "WoW Forever",
        url = "https://www.curseforge.com/wow/addons/wayscribe",
        about = L.INFO_WAYSCRIBE,
    },
}

local function isAddOnLoaded(name)
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return loaded ~= nil and loaded(name) and true or false
end

-- nil for an unpackaged checkout, where the TOC still holds the packager's placeholder.
local function version()
    local text = ns.version
    if text == nil or text == "dev" or text:find("^@") then return nil end
    return text
end

function InfoPage.New()
    local frame = CreateFrame("Frame")
    frame:Hide()
    local info = setmetatable({ frame = frame, sections = {}, entries = {}, installed = {}, links = {} }, InfoPage)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -22)
    title:SetText(L.ADDON_TITLE)
    if version() then
        local versionText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        versionText:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
        versionText:SetText(L.INFO_VERSION:format(version()))
        info.versionText = versionText
    end

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", frame, "TOP", 0, -50)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -TOP)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -MARGIN, MARGIN)
    info.content = content

    info:Build()

    frame:SetScript("OnShow", function() info:Refresh() end)
    return info
end

------------------------------------------------------------------------------------------------
-- The text, each piece below the one before (self.last), which starts self.indent right of the
-- text's left edge.

function InfoPage:Text(font, text, anchor, x, y)
    local fontString = self.content:CreateFontString(nil, "ARTWORK", font)
    if anchor then
        fontString:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
    else
        fontString:SetPoint("TOPLEFT", self.content, "TOPLEFT", TEXT_X, 0)
    end
    fontString:SetPoint("RIGHT", self.content, "RIGHT")
    fontString:SetJustifyH("LEFT")
    fontString:SetText(text)
    return fontString
end

function InfoPage:Section(text)
    self.last = self:Text("GameFontHighlightLarge", text, self.last, -self.indent, -SECTION_GAP)
    self.indent = 0
    self.sections[#self.sections + 1] = text
end

-- A name with its text next to it, wrapping in a column of its own.
function InfoPage:Entry(label, text, labelWidth)
    local labelString = self.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelString:SetPoint("TOPLEFT", self.last, "BOTTOMLEFT", -self.indent, -LINE_GAP)
    labelString:SetWidth(labelWidth)
    labelString:SetJustifyH("LEFT")
    labelString:SetText(label)
    local textString = self.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    textString:SetPoint("TOPLEFT", labelString, "TOPRIGHT")
    textString:SetPoint("RIGHT", self.content, "RIGHT")
    textString:SetJustifyH("LEFT")
    textString:SetText(text)
    self.last, self.indent = textString, labelWidth
    self.entries[#self.entries + 1] = { section = self.sections[#self.sections], label = labelString, text = textString }
end

-- An addon: its icon, its name with the flavors it's for, Installed on the right while it's loaded,
-- and what it does below the name.
function InfoPage:Addon(addon)
    local icon = self.content:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ADDON_ICON_SIZE, ADDON_ICON_SIZE)
    icon:SetPoint("TOPLEFT", self.last, "BOTTOMLEFT", -self.indent, -ENTRY_GAP)
    icon:SetTexture(MEDIA .. addon.name)

    local name = self.content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", ICON_GAP, 0)
    name:SetText(addon.name)
    local flavors = self.content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    flavors:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 8, 1)
    flavors:SetText(addon.flavors)
    local about = self:Text("GameFontHighlight", addon.about, name, 0, -3)
    -- On the name's line, at the right end of the description below it.
    local installed = self.content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    installed:SetPoint("BOTTOMRIGHT", about, "TOPRIGHT", 0, 3)
    installed:SetText(L.INFO_INSTALLED)
    installed:SetTextColor(0.1, 1, 0.1) -- GREEN_FONT_COLOR
    self.installed[addon.name] = installed

    self.last = about
    self.indent = ADDON_ICON_SIZE + ICON_GAP
    self:Link(addon)
end

-- The game can't open web pages, so a link is a read-only edit box: a click selects all of it, ready
-- to be copied.
function InfoPage:Link(addon)
    local url = addon.url
    local box = CreateFrame("EditBox", nil, self.content, "InputBoxTemplate")
    box:SetSize(LINK_WIDTH, LINK_HEIGHT)
    box:SetPoint("TOPLEFT", self.last, "BOTTOMLEFT", LINK_BORDER, -LINE_GAP)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetText(url)
    box:SetCursorPosition(0)
    box:SetScript("OnEditFocusGained", function() box:HighlightText() end)
    box:SetScript("OnEditFocusLost", function() box:HighlightText(0, 0) end)
    -- A click moves the cursor, which would drop the selection again.
    box:SetScript("OnMouseUp", function() box:HighlightText() end)
    box:SetScript("OnTextChanged", function(_, typed)
        if typed then
            box:SetText(url)
            box:HighlightText()
        end
    end)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    self.links[addon.name] = box

    local hint = self.content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", box, "RIGHT", 8, 0)
    hint:SetText(L.INFO_COPY:format(IsMacClient and IsMacClient() and "Cmd+C" or L.INFO_CTRL_C))
    self.last, self.indent = box, self.indent + LINK_BORDER
end

function InfoPage:Build()
    self.last = self:Text("GameFontNormal", L.INFO_INTRO)
    self.indent = 0

    self:Section(L.INFO_COMMANDS)
    for _, entry in ipairs(COMMANDS) do
        self:Entry(entry.command, entry.about, COMMAND_WIDTH)
    end

    self:Section(L.INFO_MORE_ADDONS:format("ollidiemaus"))
    for _, addon in ipairs(OTHER_ADDONS) do
        self:Addon(addon)
    end
end

-- Installed next to the other addons that are loaded: checked on each showing, as addons that load
-- after this one aren't loaded yet when the page is made.
function InfoPage:Refresh()
    for name, label in pairs(self.installed) do
        label:SetShown(isAddOnLoaded(name))
    end
end

-- The addon's category in Options > AddOns, which the other pages go below.
function InfoPage:Register()
    return Settings.RegisterCanvasLayoutCategory(self.frame, L.ADDON_TITLE)
end
