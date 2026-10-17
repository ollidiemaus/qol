local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

describe("version", function()
    it("gives a saved file without a version version 1, its data unchanged", function()
        Stubs.LoadAddon()
        Stubs.Login({ hideBagsBar = true })
        T.eq(QoLDB.version, 1)
        T.eq(QoLDB.options.hideBagsBar, true)
    end)

    it("gives a new saved file version 1", function()
        Stubs.LoadAddon()
        Stubs.Login()
        T.eq(QoLDB.version, 1)
    end)

    it("leaves a file from a newer QoL at its version", function()
        local ns = Stubs.LoadAddon()
        _G.QoLDB = { version = 7, options = { hideBagsBar = true, futureOption = "x" } }
        Stubs.Fire("ADDON_LOADED", "QoL")
        T.eq(QoLDB.version, 7)
        T.eq(QoLDB.options.futureOption, "x")
        T.eq(ns.Options:Get("hideBagsBar"), true)
    end)

    it("runs the migrations one version at a time, from the saved version up", function()
        local ns = Stubs.LoadAddon()
        local ran = {}
        ns.SavedData.MIGRATIONS[2] = function(db) ran[#ran + 1] = 2; db.two = true end
        ns.SavedData.MIGRATIONS[3] = function(db) ran[#ran + 1] = 3; db.three = db.two end
        ns.SavedData.VERSION = 3
        _G.QoLDB = { version = 1 }
        Stubs.Fire("ADDON_LOADED", "QoL")
        T.same(ran, { 2, 3 })
        T.eq(QoLDB.three, true)
        T.eq(QoLDB.version, 3)
    end)

    it("stops at the version before a migration that fails, and reports the error", function()
        local ns = Stubs.LoadAddon()
        ns.SavedData.MIGRATIONS[2] = function(db) db.two = true end
        ns.SavedData.MIGRATIONS[3] = function() error("broken") end
        ns.SavedData.VERSION = 3
        _G.QoLDB = { version = 1, options = { hideBagsBar = true } }
        Stubs.Fire("ADDON_LOADED", "QoL")
        T.eq(QoLDB.version, 2)
        T.eq(QoLDB.two, true)
        T.eq(#Stubs.state().errors, 1)
        T.eq(ns.Options:Get("hideBagsBar"), true)
    end)
end)
