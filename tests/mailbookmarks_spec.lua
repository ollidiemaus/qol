local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local MAIL_ICON = "Interface\\MailFrame\\Mail-Icon"

local function start(savedOptions, savedCharacters)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions, nil, savedCharacters)
    return ns
end

-- The mail frame on its Send Mail tab, as MailFrameTab_OnClick shows it.
local function openSendMail()
    MailFrame:Show()
    SendMailFrame:Show()
    Stubs.RunTimers()
end

local function tabs(ns)
    return ns.MailBookmarks.tabs
end

-- The names on the tabs that show, top to bottom.
local function shown(ns)
    local names = {}
    for _, tab in ipairs(tabs(ns)) do
        if tab:IsShown() then names[#names + 1] = tab.tooltipText end
    end
    return names
end

-- A mouse button let go on a tab (upInside: still over it, as for a click).
local function click(tab, button, upInside)
    tab:RunScript("OnMouseUp", button or "LeftButton", upInside ~= false)
    Stubs.RunTimers()
end

local function fields(frame)
    local keys = {}
    for key in pairs(frame) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    return keys
end

describe("mail bookmarks", function()
    it("adds no tabs without bookmarks", function()
        local ns = start()
        openSendMail()
        T.eq(#tabs(ns), 0)
    end)

    it("shows a side tab per bookmark down the mail frame's right edge, only on the Send Mail tab", function()
        local ns = start({ mailBookmark1 = "Bankalt", mailBookmark3 = "Herbbank" })
        local first, second = tabs(ns)[1], tabs(ns)[2]
        T.eq(#tabs(ns), 2)
        T.eq(first.template, "LargeSideTabButtonTemplate", "Forever's side tab, as on its Collections")
        T.eq(first:GetParent(), SendMailFrame)
        local point = first:PointFor("TOPLEFT")
        T.eq(point[2], SendMailFrame)
        T.eq(point[3], "TOPRIGHT")
        T.eq(point[5], -60)
        point = second:PointFor("TOPLEFT")
        T.eq(point[2], first)
        T.eq(point[3], "BOTTOMLEFT")
        T.falsy(first.SelectedTexture:IsShown(), "not drawn as the selected tab")
        T.falsy(first:IsVisible(), "the mail frame is closed")
        openSendMail()
        T.truthy(first:IsVisible())
        T.same(shown(ns), { "Bankalt", "Herbbank" })
    end)

    it("shows the name when pointed at", function()
        local ns = start({ mailBookmark1 = "Bankalt" })
        openSendMail()
        local tab = tabs(ns)[1]
        tab:RunScript("OnEnter")
        T.eq(GameTooltip.owner, tab)
        T.eq(GameTooltip.lines[1].text, "Bankalt")
        tab:RunScript("OnLeave")
        T.falsy(GameTooltip.shown)
    end)

    it("puts the name in To and goes on to Subject when clicked", function()
        local ns = start({ mailBookmark1 = "Bankalt" })
        openSendMail()
        Stubs.Type(SendMailNameEditBox, "Someone")
        click(tabs(ns)[1])
        T.eq(SendMailNameEditBox:GetText(), "Bankalt")
        T.truthy(SendMailSubjectEditBox:HasFocus())
    end)

    it("ignores a right click and a mouse button let go off the tab", function()
        local ns = start({ mailBookmark1 = "Bankalt" })
        openSendMail()
        SendMailNameEditBox:SetText("Someone")
        click(tabs(ns)[1], "RightButton")
        click(tabs(ns)[1], "LeftButton", false)
        T.eq(SendMailNameEditBox:GetText(), "Someone")
    end)

    it("fills in To in combat too", function()
        local ns = start({ mailBookmark1 = "Bankalt" })
        openSendMail()
        Stubs.SetCombat(true)
        click(tabs(ns)[1])
        T.eq(SendMailNameEditBox:GetText(), "Bankalt")
        Stubs.SetCombat(false)
    end)

    it("writes nothing on the mail frame's own frames", function()
        local before = {}
        local ns = Stubs.LoadAddon()
        -- The stubs keep the text (a widget's own) in a field.
        SendMailNameEditBox:SetText("")
        for _, name in ipairs({ "MailFrame", "SendMailFrame", "SendMailNameEditBox", "SendMailSubjectEditBox" }) do
            before[name] = fields(_G[name])
        end
        Stubs.Login({ mailBookmark1 = "Bankalt" })
        openSendMail()
        click(tabs(ns)[1])
        for name, keys in pairs(before) do
            T.same(fields(_G[name]), keys, name)
        end
    end)

    it("shows the class of characters seen on this account, the mail icon for the others", function()
        local ns = start({ mailBookmark1 = "Bankalt", mailBookmark2 = "Friend" }, { ["bankalt-testrealm"] = "WARRIOR" })
        local icon = tabs(ns)[1].Icon
        T.eq(icon:GetAtlas(), "classicon-warrior")
        T.eq(icon.width, 50)
        T.eq(tabs(ns)[2].Icon.texture, MAIL_ICON)
    end)

    it("remembers the class of the character that logs in", function()
        start()
        T.eq(QoLDB.characters["testmage-testrealm"], "MAGE")
    end)

    it("knows a character whatever the case, and with the realm written out", function()
        local ns = start({ mailBookmark1 = "bankalt", mailBookmark2 = "Twink-Other Realm", mailBookmark3 = "Alt-TestRealm" },
            { ["bankalt-testrealm"] = "WARRIOR", ["twink-otherrealm"] = "ROGUE", ["alt-testrealm"] = "PRIEST" })
        T.eq(tabs(ns)[1].Icon:GetAtlas(), "classicon-warrior")
        T.eq(tabs(ns)[2].Icon:GetAtlas(), "classicon-rogue")
        T.eq(tabs(ns)[3].Icon:GetAtlas(), "classicon-priest")
    end)

    it("leaves out blank and repeated bookmarks and the character playing", function()
        local ns = start({ mailBookmark1 = "Testmage", mailBookmark2 = "Bankalt", mailBookmark4 = "BANKALT",
            mailBookmark5 = "Herbbank", mailBookmark6 = "Testmage-TestRealm" })
        T.same(shown(ns), { "Bankalt", "Herbbank" })
    end)

    it("follows the settings while the mail frame is open", function()
        local ns = start({ mailBookmark1 = "Bankalt", mailBookmark2 = "Herbbank" }, { ["bankalt-testrealm"] = "WARRIOR" })
        openSendMail()
        ns.Options:Set("mailBookmark1", "")
        Stubs.RunTimers()
        T.same(shown(ns), { "Herbbank" })
        T.eq(#tabs(ns), 2, "the tab is kept for later")
        ns.Options:Set("mailBookmark3", "Goldmule")
        Stubs.RunTimers()
        T.same(shown(ns), { "Herbbank", "Goldmule" })
        -- The first tab had the warrior's icon; a file draws all of itself.
        local icon = tabs(ns)[1].Icon
        T.eq(icon.texture, MAIL_ICON)
        T.falsy(icon:GetAtlas())
        T.same(icon.texCoord, { 0, 1, 0, 1 })
        click(tabs(ns)[2])
        T.eq(SendMailNameEditBox:GetText(), "Goldmule")
    end)

    it("waits for the mail frame when the game loads it later", function()
        local ns = Stubs.LoadAddon()
        local frame = SendMailFrame
        _G.SendMailFrame = nil
        Stubs.Login({ mailBookmark1 = "Bankalt" })
        T.eq(#tabs(ns), 0)
        _G.SendMailFrame = frame
        Stubs.Fire("ADDON_LOADED", "Blizzard_MailFrame")
        Stubs.RunTimers()
        T.eq(#tabs(ns), 1)
    end)
end)
