local _, ns = ...
local Options = ns.Options

-- Bookmarks on the Send Mail tab: characters the player often mails (a bank character), each a tab
-- on the mail frame's right edge, like the side tabs of Forever's own windows (Collections, Inspect,
-- Group Finder: LargeSideTabButtonTemplate, whose common-sidetab art Forever draws in bronze). A tab
-- shows the character's class icon once QoL has seen them log in (QoLDB.characters, account-wide),
-- else the mail frame's own portrait, and their name on hover. A click puts the name in To and goes
-- on to Subject, as the game's Reply and Enter in To do.
--
-- The tabs are frames of ours, children of SendMailFrame, so they show only on the Send Mail tab,
-- placed against MailFrame (Classic Era's Send Mail frame is wider than the mail frame it sits in).
-- Classic Era has no large side tab: there they are its spell book's side tabs.
-- On Blizzard's frames only widget methods (SetText, SetFocus), through ns.Later.
local MailBookmarks = {}
ns.MailBookmarks = MailBookmarks

-- As many tabs as fit along the mail frame (424 high) below its title bar.
local COUNT = 6
local KEYS = {}
for index = 1, COUNT do KEYS[index] = "mailBookmark" .. index end
MailBookmarks.KEYS = KEYS

local FIRST_TAB_Y = -60 -- below the title bar, where the Group Finder starts its tabs
local TAB_GAP = 2
local SKILL_LINE_TAB_GAP = 17 -- as Classic Era's spell book spaces them (32 high, art past that)
local ICON_SIZE = 50 -- the inside of the tab art (SidePanelTabButtonMixin's interior)
local UNKNOWN_ICON = "Interface\\MailFrame\\Mail-Icon"

local function characters()
    local db = ns.db
    if not db then return {} end
    if type(db.characters) ~= "table" then db.characters = {} end
    return db.characters
end

-- Keeps the class of the character that logged in, for its icon on the others' tabs.
local function remember()
    local key = ns.PlayerKey()
    local _, class = UnitClass("player")
    if key and ns.IsUsable(class) then characters()[key] = class end
end

-- The names to show, in the order set: no blanks, no repeats, and not the player (the game doesn't
-- send mail to yourself).
local function bookmarks()
    local names, seen = {}, {}
    local player = ns.PlayerKey()
    if player then seen[player] = true end
    for _, key in ipairs(KEYS) do
        local name = Options:Get(key)
        local id = name ~= "" and ns.CharacterKey(name)
        if id and not seen[id] then
            seen[id] = true
            names[#names + 1] = name
        end
    end
    return names
end

-- Puts the name in To and moves on to Subject. The name box isn't protected, so in combat too.
function MailBookmarks.Fill(name)
    ns.Later("mailBookmark", function()
        local frame, to, subject = SendMailFrame, SendMailNameEditBox, SendMailSubjectEditBox
        if not (frame and to and frame:IsVisible()) then return end
        to:SetText(name)
        if subject then subject:SetFocus() end
    end, true)
end

-- Made without a parent: SmartNavigation hooks CreateFrame, and a frame made inside an open
-- controller window makes it rebuild that window from our code.
local function newSideTab()
    local tab = CreateFrame("Frame", nil, nil, "LargeSideTabButtonTemplate")
    tab:SetChecked(false)
    tab.iconSize, tab.gap = ICON_SIZE, TAB_GAP
    tab:SetCustomOnMouseUpHandler(function(self, button, upInside)
        if button == "LeftButton" and upInside then MailBookmarks.Fill(self.name) end
    end)
    return tab
end

-- Classic Era's spell book tab: a CheckButton whose NormalTexture is the icon, sized by the
-- template, and whose OnClick (the spell book's) is replaced by ours. Its NormalTexture element is
-- empty, so a file is set first, as the spell book does, for there to be a texture to draw on.
local function newSkillLineTab()
    local tab = CreateFrame("CheckButton", nil, nil, "SpellBookSkillLineTabTemplate")
    tab:SetNormalTexture(UNKNOWN_ICON)
    tab.Icon, tab.gap = tab:GetNormalTexture(), SKILL_LINE_TAB_GAP
    tab:SetScript("OnClick", function(self)
        self:SetChecked(false)
        MailBookmarks.Fill(self.name)
    end)
    return tab
end

local function newTab()
    if C_XMLUtil.GetTemplateInfo("LargeSideTabButtonTemplate") then return newSideTab() end
    return newSkillLineTab()
end

local function setIcon(tab, name)
    local class = characters()[ns.CharacterKey(name)]
    if type(class) == "string" then
        tab.Icon:SetAtlas("classicon-" .. class:lower())
    else
        -- A file keeps the texture coordinates an atlas set before.
        tab.Icon:SetTexture(UNKNOWN_ICON)
        tab.Icon:SetTexCoord(0, 1, 0, 1)
    end
    if tab.iconSize then tab.Icon:SetSize(tab.iconSize, tab.iconSize) end
end

function MailBookmarks:Apply()
    local frame = SendMailFrame
    if not (frame and MailFrame) then return end
    local names = bookmarks()
    for index, name in ipairs(names) do
        local tab = self.tabs[index]
        if not tab then
            tab = newTab()
            tab:SetParent(frame)
            if index == 1 then
                tab:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 0, FIRST_TAB_Y)
            else
                tab:SetPoint("TOPLEFT", self.tabs[index - 1], "BOTTOMLEFT", 0, -tab.gap)
            end
            self.tabs[index] = tab
        end
        -- tooltipText is what SidePanelTabButtonMixin's OnEnter shows, tooltip the spell book tab's.
        tab.name, tab.tooltipText, tab.tooltip = name, name, name
        setIcon(tab, name)
        tab:Show()
    end
    for index = #names + 1, #self.tabs do
        self.tabs[index]:Hide()
    end
end

local function schedule()
    ns.Later("mailBookmarks", function() MailBookmarks:Apply() end, true)
end

function MailBookmarks:Init()
    self.tabs = {}
    remember()
    Options:Watch(KEYS, schedule)
    ns.Events:On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_MailFrame" then schedule() end
    end)
    schedule()
end
