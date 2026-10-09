local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Loads the addon with a main bar (and optionally more bars) in place, then logs in.
local function start(savedOptions, bars)
    local ns = Stubs.LoadAddon()
    local raws = {}
    bars = bars or { MainActionBar = { numRows = 2 } }
    for name, fields in pairs(bars) do
        local bar, raw = Stubs.NewActionBar(fields)
        _G[name] = bar
        raws[name] = raw
    end
    Stubs.Login(savedOptions)
    return ns, Stubs.state(), raws
end

local function lastLayout(state)
    return state.layouts[#state.layouts]
end

describe("action bar growth", function()
    it("never touches a bar nobody flipped", function()
        local _, state = start()
        Stubs.Fire("EDIT_MODE_LAYOUTS_UPDATED")
        Stubs.TriggerRegistry("EditMode.Exit")
        Stubs.RunTimers()
        T.eq(#state.layouts, 0)
    end)

    it("flips rows: a bar that grows up grows down from the top", function()
        local _, state = start({ flipVertical_MainActionBar = true })
        local layout = lastLayout(state)
        T.eq(layout.regions, MainActionBar.shownButtonContainers)
        T.eq(layout.anchor.point, "TOPLEFT")
        T.eq(layout.anchor.relativeTo, MainActionBar)
        T.eq(layout.layout.kind, "standard")
        T.eq(layout.layout.stride, 6)
        T.eq(layout.layout.xMultiplier, 1)
        T.eq(layout.layout.yMultiplier, -1)
    end)

    it("flips columns: buttons fill each row from the right", function()
        local _, state = start({ flipHorizontal_MainActionBar = true })
        local layout = lastLayout(state)
        T.eq(layout.anchor.point, "BOTTOMRIGHT")
        T.eq(layout.layout.xMultiplier, -1)
        T.eq(layout.layout.yMultiplier, 1)
    end)

    it("uses the vertical grid for vertical bars", function()
        local _, state = start({ flipVertical_MultiBarRight = true },
            { MultiBarRight = { isHorizontal = false, addButtonsToTop = false, numRows = 1 } })
        local layout = lastLayout(state)
        T.eq(layout.layout.kind, "vertical")
        T.eq(layout.layout.stride, 12)
        T.eq(layout.anchor.point, "BOTTOMLEFT")
    end)

    it("keeps the padding Edit Mode set, but never less than the minimum", function()
        local _, state = start({ flipVertical_MainActionBar = true },
            { MainActionBar = { buttonPadding = 6, minButtonPadding = 2 } })
        T.eq(lastLayout(state).layout.xPadding, 6)
    end)

    it("lays out again only after Blizzard did", function()
        local _, state, raws = start({ flipVertical_MainActionBar = true })
        local count = #state.layouts
        Stubs.Fire("ACTIONBAR_PAGE_CHANGED")
        Stubs.RunTimers()
        T.eq(#state.layouts, count, "nothing changed")
        raws.MainActionBar.oldGridSettings = {} -- what Blizzard's UpdateGridLayout leaves behind
        Stubs.TriggerRegistry("EditMode.Exit")
        Stubs.RunTimers()
        T.eq(#state.layouts, count + 1)
    end)

    it("restores the default layout once when turned off", function()
        local ns, state = start({ flipVertical_MainActionBar = true })
        ns.Options:Set("flipVertical_MainActionBar", false)
        Stubs.RunTimers()
        local layout = lastLayout(state)
        T.eq(layout.anchor.point, "BOTTOMLEFT")
        T.eq(layout.layout.yMultiplier, 1)
        local count = #state.layouts
        ns.Options:Set("hideBagsBar", true)
        Stubs.Fire("EDIT_MODE_LAYOUTS_UPDATED")
        Stubs.RunTimers()
        T.eq(#state.layouts, count)
    end)

    it("waits for the end of combat", function()
        local ns, state = start()
        Stubs.SetCombat(true)
        ns.Options:Set("flipHorizontal_MainActionBar", true)
        Stubs.RunTimers()
        T.eq(#state.layouts, 0)
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(#state.layouts, 1)
    end)

    it("reacts to the player's pet only", function()
        local _, state, raws = start({ flipVertical_PetActionBar = true }, { PetActionBar = { numRows = 2 } })
        local count = #state.layouts
        raws.PetActionBar.oldGridSettings = {}
        Stubs.Fire("UNIT_PET", "party1")
        Stubs.RunTimers()
        T.eq(#state.layouts, count)
        Stubs.Fire("UNIT_PET", "player")
        Stubs.RunTimers()
        T.eq(#state.layouts, count + 1)
    end)

    it("names bars like Edit Mode does when the game has the names", function()
        local ns = Stubs.LoadAddon()
        HUD_EDIT_MODE_ACTION_BAR_LABEL = "Aktionsleiste %d"
        HUD_EDIT_MODE_STANCE_BAR_LABEL = "Haltungsleiste"
        T.eq(ns.ActionBars.BARS[3].label(), "Aktionsleiste 3")
        T.eq(ns.ActionBars.BARS[9].label(), "Haltungsleiste")
        T.eq(ns.ActionBars.BARS[10].label(), "Pet Bar")
    end)
end)
