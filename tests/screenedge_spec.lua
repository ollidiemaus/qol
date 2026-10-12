local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Two Edit Mode frames: a bar whose selection box is 4 bigger on every side, and a protected one
-- whose selection box is 10 smaller (Edit Mode's clamps: -4, 4, 4, -4 and 10, -10, -10, 10).
local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    local bar = Stubs.NewEditModeFrame(100, 20, 400, 40, 4)
    local unitFrame = Stubs.NewEditModeFrame(300, 600, 200, 80, -10, true)
    Stubs.Login(savedOptions)
    return ns, bar, unitFrame
end

local BAR_BLIZZARD = { -4, 4, 4, -4 }
local BAR_PAST = { 26, -26, -26, 26 }
local UNIT_FRAME_BLIZZARD = { 10, -10, -10, 10 }
local UNIT_FRAME_PAST = { 40, -40, -40, 40 }

-- Two drawn frames: Blizzard's change shows in the first, ours runs in the second.
local function twoFrames()
    Stubs.NextFrame()
    Stubs.NextFrame()
end

describe("frames past the screen edge", function()
    it("leaves Edit Mode's clamp alone by default", function()
        local _, bar = start()
        T.same(bar.clamp, BAR_BLIZZARD)
        T.eq(bar.clampSets, 1, "only Edit Mode's own")
        T.eq(bar.anchorings, 0)
    end)

    it("lets every frame go 30 past each edge of the screen, from its selection box", function()
        local _, bar, unitFrame = start({ pastScreenEdge = true })
        T.same(bar.clamp, BAR_PAST)
        T.same(unitFrame.clamp, UNIT_FRAME_PAST)
        T.same(bar.laidOutUnder, BAR_PAST, "laid out again under the new clamp")
        T.same(unitFrame.laidOutUnder, UNIT_FRAME_PAST)
    end)

    it("puts frames back past the edge after Edit Mode closed and applied the saved layout", function()
        local _, bar = start({ pastScreenEdge = true })
        Stubs.OpenEditMode()
        twoFrames()
        Stubs.CloseEditMode()
        T.same(bar.laidOutUnder, BAR_BLIZZARD, "the game pulls it in under Blizzard's clamp")
        local blizzardCalls = bar.overrideCalls
        Stubs.RunTimers()
        T.same(bar.clamp, BAR_PAST)
        T.same(bar.laidOutUnder, BAR_PAST, "and lays it out again under ours")
        T.eq(bar.overrideCalls, blizzardCalls, "with the frame's own SetPoint, not Edit Mode's")
        T.same({ bar:GetPoint(1) }, { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 20 }, "at the same place")
    end)

    it("clamps again after Edit Mode applied a layout, also one another addon switched to", function()
        local _, bar = start({ pastScreenEdge = true })
        Stubs.ApplyEditModeLayout(bar)
        Stubs.RenderEditMode()
        Stubs.Fire("EDIT_MODE_LAYOUTS_UPDATED")
        Stubs.RunTimers()
        T.same(bar.clamp, BAR_PAST)
        T.same(bar.laidOutUnder, BAR_PAST)
    end)

    it("clamps again in Edit Mode, where Blizzard sets its clamp without an event", function()
        local _, bar = start({ pastScreenEdge = true })
        Stubs.OpenEditMode()
        T.same(bar.clamp, BAR_BLIZZARD)
        twoFrames()
        T.same(bar.clamp, BAR_PAST, "after the highlight")

        -- A setting made the bar wider, and Edit Mode clamped its new selection box.
        bar.rect[3], bar.Selection.rect[3] = 500, 508
        Stubs.EditModeClamp(bar)
        twoFrames()
        T.same(bar.clamp, BAR_PAST, "after a setting")

        Stubs.CloseEditMode()
        Stubs.RunTimers() -- ends: nothing compares the frames once Edit Mode is closed
        T.same(bar.clamp, BAR_PAST)
    end)

    it("leaves the anchors of a frame being dragged to the drag", function()
        local _, bar = start({ pastScreenEdge = true })
        Stubs.OpenEditMode()
        bar.isDragging = true
        local anchorings = bar.anchorings
        twoFrames()
        T.same(bar.clamp, BAR_PAST)
        T.eq(bar.anchorings, anchorings)
        Stubs.CloseEditMode()
    end)

    it("clamps from the selection box also when Blizzard set 0s (a frame not laid out yet)", function()
        local _, _, unitFrame = start({ pastScreenEdge = true })
        unitFrame:SetClampRectInsets(0, 0, 0, 0)
        Stubs.Fire("EDIT_MODE_LAYOUTS_UPDATED")
        Stubs.RunTimers()
        T.same(unitFrame.clamp, UNIT_FRAME_PAST)
    end)

    it("sets nothing when nothing changed", function()
        local _, bar = start({ pastScreenEdge = true })
        local sets, anchorings = bar.clampSets, bar.anchorings
        Stubs.Fire("DISPLAY_SIZE_CHANGED")
        Stubs.Fire("UI_SCALE_CHANGED")
        Stubs.RunTimers()
        T.eq(bar.clampSets, sets)
        T.eq(bar.anchorings, anchorings)
        Stubs.OpenEditMode()
        twoFrames()
        Stubs.NextFrame()
        T.eq(bar.clampSets, sets + 2, "Edit Mode's highlight and ours after it, once")
        T.eq(bar.anchorings, anchorings + 1)
        Stubs.CloseEditMode()
    end)

    it("brings the frames back inside the screen when turned off", function()
        local ns, bar, unitFrame = start({ pastScreenEdge = true })
        -- Blizzard already set its clamp on the bar, but it's still laid out under ours.
        Stubs.EditModeClamp(bar)
        ns.Options:Set("pastScreenEdge", false)
        Stubs.RunTimers()
        T.same(bar.clamp, BAR_BLIZZARD)
        T.same(bar.laidOutUnder, BAR_BLIZZARD)
        T.same(unitFrame.clamp, UNIT_FRAME_BLIZZARD)
        T.same(unitFrame.laidOutUnder, UNIT_FRAME_BLIZZARD)

        local anchorings = bar.anchorings
        Stubs.OpenEditMode()
        Stubs.CloseEditMode()
        Stubs.RunTimers() -- ends: nothing compares the frames while it's off
        T.same(bar.clamp, BAR_BLIZZARD)
        T.eq(bar.anchorings, anchorings + 1, "only Edit Mode's own")
    end)

    it("waits for the end of combat, for protected frames", function()
        local ns, _, unitFrame = start()
        Stubs.SetCombat(true)
        ns.Options:Set("pastScreenEdge", true)
        Stubs.RunTimers()
        T.same(unitFrame.clamp, UNIT_FRAME_BLIZZARD)
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.same(unitFrame.clamp, UNIT_FRAME_PAST)
        T.same(unitFrame.laidOutUnder, UNIT_FRAME_PAST)
    end)

    it("skips a frame whose place is secret", function()
        Stubs.LoadAddon()
        local bar = Stubs.NewEditModeFrame(100, 20, 400, 40, 4)
        function bar:GetLeft() return Stubs.SECRET end
        Stubs.Login({ pastScreenEdge = true })
        T.same(bar.clamp, BAR_BLIZZARD)
        T.eq(bar.clampSets, 1, "only Edit Mode's own")
        T.eq(bar.anchorings, 0)
    end)
end)
