local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns
end

local function set(ns, key, value)
    ns.Options:Set(key, value)
    Stubs.RunTimers()
end

-- What a key does through an override binding, or nil.
local function override(key)
    local entry = Stubs.state().overrides[key]
    return entry and entry.command
end

describe("bar paging keys", function()
    it("are left alone by default", function()
        start()
        T.eq(next(Stubs.state().overrides), nil)
    end)

    it("press the action button of the same number instead", function()
        start({ disableBarPaging = true })
        for i = 1, 6 do
            T.eq(override("SHIFT-" .. i), "ACTIONBUTTON" .. i)
        end
        -- Only the keys for the pages, not the scroll wheel's next and previous page.
        T.eq(override("SHIFT-MOUSEWHEELUP"), nil)
    end)

    it("follow a bar addon that took over the plain key", function()
        Stubs.LoadAddon()
        Stubs.state().overrides["1"] = { owner = "BarAddon", command = "CLICK BarAddonButton1:Keybind" }
        Stubs.Login({ disableBarPaging = true })
        T.eq(override("SHIFT-1"), "CLICK BarAddonButton1:Keybind")
    end)

    it("do nothing where the plain key has no binding", function()
        Stubs.LoadAddon()
        Stubs.state().bindings["3"] = nil
        Stubs.Login({ disableBarPaging = true })
        T.eq(override("SHIFT-3"), "CLICK ForeverQoLNoAction:LeftButton")
        T.truthy(ForeverQoLNoAction)
    end)

    it("follow the player's own paging keys", function()
        start({ disableBarPaging = true })
        local bindings = Stubs.state().bindings
        bindings["SHIFT-1"] = nil
        bindings["CTRL-SHIFT-7"] = "ACTIONPAGE1"
        bindings["7"] = "ACTIONBUTTON7"
        Stubs.Fire("UPDATE_BINDINGS")
        Stubs.RunTimers()
        T.eq(override("CTRL-SHIFT-7"), "ACTIONBUTTON7")
        T.eq(override("SHIFT-1"), nil)
    end)

    it("change nothing when their own overrides fire the bindings event", function()
        start({ disableBarPaging = true })
        local calls = Stubs.state().overrideCalls
        Stubs.Fire("UPDATE_BINDINGS")
        Stubs.RunTimers()
        T.eq(Stubs.state().overrideCalls, calls)
    end)

    it("page again when turned off", function()
        local ns = start({ disableBarPaging = true })
        set(ns, "disableBarPaging", false)
        T.eq(next(Stubs.state().overrides), nil)
        T.eq(Stubs.state().bindings["SHIFT-1"], "ACTIONPAGE1")
    end)

    it("wait for the end of combat", function()
        local ns = start()
        Stubs.SetCombat(true)
        set(ns, "disableBarPaging", true)
        T.eq(override("SHIFT-1"), nil)
        Stubs.SetCombat(false)
        Stubs.RunTimers()
        T.eq(override("SHIFT-1"), "ACTIONBUTTON1")
    end)

    it("know the key under the modifiers", function()
        local ns = start()
        local unmodified = ns.BarPaging.Unmodified
        T.eq(unmodified("SHIFT-1"), "1")
        T.eq(unmodified("CTRL-SHIFT-F"), "F")
        T.eq(unmodified("SHIFT--"), "-")
        T.eq(unmodified("F"), nil)
    end)
end)
