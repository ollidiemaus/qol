local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns, Stubs.state()
end

describe("class colors in chat", function()
    it("leaves the game's setting alone by default", function()
        local _, state = start()
        T.eq(state.cvars.chatClassColorOverride, "2")
        T.same(state.cvarSets, {})
    end)

    it("colors names in every channel while on", function()
        local _, state = start({ chatClassColors = true })
        T.eq(state.cvars.chatClassColorOverride, "0")
    end)

    it("puts the setting back to its default when turned off", function()
        local ns, state = start({ chatClassColors = true })
        ns.Options:Set("chatClassColors", false)
        Stubs.RunTimers()
        T.eq(state.cvars.chatClassColorOverride, "2")
    end)

    it("doesn't touch a setting the player changed some other way while the option is off", function()
        local _, state = Stubs.LoadAddon(), Stubs.state()
        state.cvars.chatClassColorOverride = "0"
        Stubs.Login()
        T.same(state.cvarSets, {})
    end)

    it("does nothing on a client without the setting", function()
        local _, state = Stubs.LoadAddon(), Stubs.state()
        state.cvars.chatClassColorOverride = nil
        Stubs.Login({ chatClassColors = true })
        T.same(state.cvarSets, {})
    end)
end)
