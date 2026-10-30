local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- QoL on Classic Era (1.15.9): the stubbed client without what Classic Era lacks.
local function start()
    local ns = Stubs.LoadAddon({ client = "classicEra" })
    local api = Stubs.InstallSettings()
    Stubs.Login()
    return ns, api
end

describe("the stubbed Classic Era client", function()
    it("errors on a frame template Classic Era lacks, as the client does", function()
        Stubs.Reset({ client = "classicEra" })
        for _, template in ipairs({ "PortraitFrameFlatTemplate", "LargeSideTabButtonTemplate",
            "TabSystemTopButtonTemplate", "UIPanelButtonTemplate, LargeSideTabButtonTemplate" }) do
            T.falsy(pcall(CreateFrame, "Frame", nil, UIParent, template), template)
        end
        T.truthy(pcall(CreateFrame, "Frame", nil, UIParent, "PortraitFrameTemplate"))
        T.truthy(pcall(CreateFrame, "Button", nil, UIParent, "UIPanelButtonTemplate"))
    end)

    it("lacks tooltip data, the spell book's skill lines, toys, the addon compartment, combined bags, the controller", function()
        Stubs.Reset({ client = "classicEra" })
        T.eq(select(4, GetBuildInfo()), 11509)
        T.eq(TooltipDataProcessor, nil)
        T.eq(C_SpellBook.GetNumSpellBookSkillLines, nil)
        T.truthy(C_SpellBook.IsSpellKnownOrInSpellBook, "Classic Era has this one")
        T.eq(C_ToyBox, nil)
        T.eq(PlayerHasToy, nil)
        T.eq(AddonCompartmentFrame, nil)
        T.eq(ContainerFrameCombinedBags, nil)
        T.eq(C_InputInterfaceStyle, nil)
        T.eq(GamepadMode, nil)
        T.eq(BuffFrameTooltip, nil)
    end)

    it("keeps every template on Forever", function()
        Stubs.Reset()
        T.truthy(pcall(CreateFrame, "Frame", nil, UIParent, "PortraitFrameFlatTemplate"))
    end)
end)

describe("QoL on Classic Era", function()
    it("loads every file the TOC lists and logs in without errors", function()
        local ok, err = pcall(start)
        T.truthy(ok, tostring(err))
        T.same(Stubs.state().errors, {})
    end)

    it("opens the settings window from /qol, in Classic Era's own window art", function()
        start()
        SlashCmdList.QOL("")
        T.truthy(QoLSettings:IsShown())
        T.eq(QoLSettings.template, "PortraitFrameTemplate")
        T.eq(QoLSettings.titleText, "Quality of Life")
        T.same(Stubs.state().errors, {})
    end)

    it("leaves out the Ring and Click casting pages, whose tabs are the game's tab system Classic Era lacks", function()
        local ns = start()
        T.falsy(ns.SettingsPanel.pages.ring)
        T.falsy(ns.SettingsPanel.pages.clickCast)
        T.truthy(ns.SettingsPanel.pages.automation)
    end)

    it("opens the settings window from the information page's button", function()
        local ns = start()
        local info = ns.SettingsPanel.info
        info.frame:Show()
        info.openButton:Click()
        Stubs.RunTimers()
        T.truthy(QoLSettings:IsShown())
        T.same(Stubs.state().errors, {})
    end)
end)
