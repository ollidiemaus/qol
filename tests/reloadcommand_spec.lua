local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Runs /rl the way the chat box does: through the command's SLASH_ globals and SlashCmdList.
local function handlerFor(command)
    for name, value in pairs(_G) do
        if type(name) == "string" and name:find("^SLASH_") and value == command then
            local key = name:match("^SLASH_(.-)%d+$")
            return SlashCmdList[key]
        end
    end
    return nil
end

describe("/rl", function()
    it("reloads the interface", function()
        Stubs.LoadAddon()
        Stubs.Login()
        local handler = handlerFor("/rl")
        T.truthy(handler, "/rl registered")
        handler("")
        T.eq(Stubs.state().reloads, 1)
    end)

    it("waits for the first loading screen, after the other addons' PLAYER_LOGIN", function()
        local ns = Stubs.LoadAddon()
        Stubs.Fire("ADDON_LOADED", "ForeverQoL")
        Stubs.Fire("PLAYER_LOGIN")
        T.falsy(ns.ReloadCommand:IsRegistered())
        Stubs.Fire("PLAYER_ENTERING_WORLD")
        T.truthy(ns.ReloadCommand:IsRegistered())
    end)

    it("leaves /rl to another addon that has it", function()
        local ns = Stubs.LoadAddon()
        SLASH_OTHERADDON1 = "/RL"
        Stubs.Login()
        T.falsy(ns.ReloadCommand:IsRegistered())
        T.eq(SLASH_FOREVERQOL_RELOAD1, nil)
    end)

    it("leaves /rl to a command the game already copied into its lookup table", function()
        local ns = Stubs.LoadAddon()
        hash_SlashCmdList = { ["/RL"] = function() end }
        Stubs.Login()
        T.falsy(ns.ReloadCommand:IsRegistered())
    end)

    it("leaves /rl to a secure command", function()
        local ns = Stubs.LoadAddon()
        _G.IsSecureCmd = function(command) return command:upper() == "/RL" end
        Stubs.Login()
        T.falsy(ns.ReloadCommand:IsRegistered())
    end)

    it("doesn't mistake the game's own /reload for /rl", function()
        local ns = Stubs.LoadAddon()
        SLASH_RELOAD1 = "/reload"
        Stubs.Login()
        T.truthy(ns.ReloadCommand:IsRegistered())
    end)

    it("goes away when turned off, also from the game's lookup table, and comes back", function()
        local ns = Stubs.LoadAddon()
        Stubs.Login()
        -- What the game does the first time chat is used.
        hash_SlashCmdList = { ["/RL"] = SlashCmdList.FOREVERQOL_RELOAD }
        ns.Options:Set("reloadCommand", false)
        T.eq(SLASH_FOREVERQOL_RELOAD1, nil)
        T.eq(SlashCmdList.FOREVERQOL_RELOAD, nil)
        T.eq(hash_SlashCmdList["/RL"], nil)
        ns.Options:Set("reloadCommand", true)
        T.truthy(ns.ReloadCommand:IsRegistered())
    end)

    it("doesn't take /rl back from an addon that registered it in the meantime", function()
        local ns = Stubs.LoadAddon()
        Stubs.Login({ reloadCommand = false })
        SLASH_OTHERADDON1 = "/rl"
        ns.Options:Set("reloadCommand", true)
        T.falsy(ns.ReloadCommand:IsRegistered())
    end)
end)
