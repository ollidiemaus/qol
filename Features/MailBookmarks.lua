local _, ns = ...
local Options = ns.Options

-- Bookmarks on the Send Mail tab: characters the player often mails (a bank character), each a tab
-- on the mail frame's right edge, like the side tabs of Forever's own windows (Collections, Inspect,
-- Group Finder: LargeSideTabButtonTemplate, whose common-sidetab art Forever draws in bronze). A tab
-- shows the character's class icon once QoL has seen them log in (QoLDB.characters, account-wide),
-- else the mail frame's own portrait, and their name on hover. A click puts the name in To and goes
-- on to Subject, as the game's Reply and Enter in To do.
--
-- The tabs are frames of ours, children of SendMailFrame, so they show only on the Send Mail tab.
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
local ICON_SIZE = 50 -- the inside of the tab art (SidePanelTabButtonMixin's interior)
local UNKNOWN_ICON = "Interface\\MailFrame\\Mail-Icon"

-- "name-realm" in lower case, one space between Forever's name and surname, and the realm as
-- GetNormalizedRealmName writes it (no spaces or dashes), so "Bankalt", "bankalt" and
-- "Bankalt-Your Realm" are the same character. A name without a realm is on the player's realm.
local function characterKey(text)
    local name, realm = text:match("^([^%-]+)%-(.+)$")
    if not name then
        name, realm = text, GetNormalizedRealmName and GetNormalizedRealmName() or ""
    end
    name = strtrim(name):gsub("%s+", " ")
    return (name .. "-" .. realm:gsub("[%s%-]", "")):lower()
end

local function characters()
    local db = ns.db
    if not db then return {} end
    if type(db.characters) ~= "table" then db.characters = {} end
    return db.characters
end

-- The player's name as To takes it. On Forever every character has a surname and first names
-- repeat: UnitName gives the surname where retail gives the realm, and the full name is both with
-- a space between (NameUtil.FormatUnitNameForDisplay).
local function playerKey()
    local name, surname = UnitName("player")
    if not ns.IsUsable(name) then return nil end
    if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() and ns.IsUsable(surname) and surname ~= ""
        and not name:find(" ", 1, true) then
        name = name .. " " .. surname
    end
    return characterKey(name)
end

-- Keeps the class of the character that logged in, for its icon on the others' tabs.
local function remember()
    local key = playerKey()
    local _, class = UnitClass("player")
    if key and ns.IsUsable(class) then characters()[key] = class end
end

-- The names to show, in the order set: no blanks, no repeats, and not the player (the game doesn't
-- send mail to yourself).
local function bookmarks()
    local names, seen = {}, {}
    local player = playerKey()
    if player then seen[player] = true end
    for _, key in ipairs(KEYS) do
        local name = Options:Get(key)
        local id = name ~= "" and characterKey(name)
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
local function newTab()
    local tab = CreateFrame("Frame", nil, nil, "LargeSideTabButtonTemplate")
    tab:SetChecked(false)
    tab.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    tab:SetCustomOnMouseUpHandler(function(self, button, upInside)
        if button == "LeftButton" and upInside then MailBookmarks.Fill(self.name) end
    end)
    return tab
end

local function setIcon(tab, name)
    local class = characters()[characterKey(name)]
    if type(class) == "string" then
        tab.Icon:SetAtlas("classicon-" .. class:lower())
    else
        -- A file keeps the texture coordinates an atlas set before.
        tab.Icon:SetTexture(UNKNOWN_ICON)
        tab.Icon:SetTexCoord(0, 1, 0, 1)
    end
    tab.Icon:SetSize(ICON_SIZE, ICON_SIZE)
end

function MailBookmarks:Apply()
    local frame = SendMailFrame
    if not frame then return end
    local names = bookmarks()
    for index, name in ipairs(names) do
        local tab = self.tabs[index]
        if not tab then
            tab = newTab()
            tab:SetParent(frame)
            if index == 1 then
                tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, FIRST_TAB_Y)
            else
                tab:SetPoint("TOPLEFT", self.tabs[index - 1], "BOTTOMLEFT", 0, -TAB_GAP)
            end
            self.tabs[index] = tab
        end
        -- tooltipText is what SidePanelTabButtonMixin's OnEnter shows.
        tab.name, tab.tooltipText = name, name
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
