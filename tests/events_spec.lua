local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

describe("events", function()
    -- An event no feature listens to.
    it("stop reaching a handler after Off, and stop listening once no handler is left", function()
        local ns = Stubs.LoadAddon()
        Stubs.Login()
        local heard = {}
        local function first() heard[#heard + 1] = "first" end
        local function second() heard[#heard + 1] = "second" end
        ns.Events:On("TEST_EVENT", first)
        ns.Events:On("TEST_EVENT", second)
        ns.Events:Off("TEST_EVENT", first)
        Stubs.Fire("TEST_EVENT")
        T.same(heard, { "second" })
        ns.Events:Off("TEST_EVENT", second)
        Stubs.Fire("TEST_EVENT")
        T.same(heard, { "second" })
        T.eq(Stubs.Listens("TEST_EVENT"), false)
        -- On again after Off: heard again.
        ns.Events:On("TEST_EVENT", first)
        Stubs.Fire("TEST_EVENT")
        T.same(heard, { "second", "first" })
    end)

    it("keep calling the other handlers when one turns itself off", function()
        local ns = Stubs.LoadAddon()
        Stubs.Login()
        local heard = {}
        local function once()
            heard[#heard + 1] = "once"
            ns.Events:Off("TEST_EVENT", once)
        end
        ns.Events:On("TEST_EVENT", once)
        ns.Events:On("TEST_EVENT", function() heard[#heard + 1] = "always" end)
        Stubs.Fire("TEST_EVENT")
        Stubs.Fire("TEST_EVENT")
        T.same(heard, { "once", "always", "always" })
    end)
end)

describe("unit listeners", function()
    it("deliver an event only for their units, with the event and its arguments", function()
        local ns = Stubs.LoadAddon()
        Stubs.Login()
        local heard = {}
        local listener = ns.Events:NewUnitListener("target", "focus")
        T.eq(listener:On("UNIT_FLAGS", function(...) heard[#heard + 1] = { ... } end), true)
        Stubs.Fire("UNIT_FLAGS", "target")
        Stubs.Fire("UNIT_FLAGS", "party1")
        Stubs.Fire("UNIT_FLAGS", "focus")
        T.same(heard, { { "UNIT_FLAGS", "target" }, { "UNIT_FLAGS", "focus" } })
        T.eq(Stubs.Listens("UNIT_FLAGS", "focus"), true)
        T.eq(Stubs.Listens("UNIT_FLAGS", "party1"), false)
    end)

    it("stop hearing an event after Off", function()
        local ns = Stubs.LoadAddon()
        Stubs.Login()
        local heard = 0
        local listener = ns.Events:NewUnitListener("player")
        listener:On("UNIT_FLAGS", function() heard = heard + 1 end)
        listener:On("UNIT_AURA", function() end)
        listener:Off("UNIT_FLAGS")
        Stubs.Fire("UNIT_FLAGS", "player")
        T.eq(heard, 0)
        T.eq(Stubs.Listens("UNIT_FLAGS", "player"), false)
        T.eq(Stubs.Listens("UNIT_AURA", "player"), true)
        -- On again after Off: heard again.
        listener:On("UNIT_FLAGS", function() heard = heard + 1 end)
        Stubs.Fire("UNIT_FLAGS", "player")
        T.eq(heard, 1)
    end)

    it("keep one handler per event: a second On replaces the first", function()
        local ns = Stubs.LoadAddon()
        Stubs.Login()
        local heard = {}
        local listener = ns.Events:NewUnitListener("player")
        listener:On("UNIT_FLAGS", function() heard[#heard + 1] = "first" end)
        listener:On("UNIT_FLAGS", function() heard[#heard + 1] = "second" end)
        Stubs.Fire("UNIT_FLAGS", "player")
        T.same(heard, { "second" })
    end)

    it("register nothing for an event the client doesn't know", function()
        local ns = Stubs.LoadAddon({ unknownEvents = { UNIT_FLAGS = true } })
        Stubs.Login()
        local listener = ns.Events:NewUnitListener("player")
        T.eq(listener:On("UNIT_FLAGS", function() end), false)
        T.eq(Stubs.Listens("UNIT_FLAGS", "player"), false)
    end)
end)
