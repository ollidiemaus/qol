local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

describe("version", function()
    it("brings a saved file without a version up to date, its data unchanged", function()
        Stubs.LoadAddon()
        Stubs.Login({ hideBagsBar = true })
        T.eq(QoLDB.version, 2)
        T.eq(QoLDB.options.hideBagsBar, true)
    end)

    it("gives a new saved file the current version", function()
        Stubs.LoadAddon()
        Stubs.Login()
        T.eq(QoLDB.version, 2)
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

describe("version 2", function()
    local function migrated(value)
        local ns = Stubs.LoadAddon()
        _G.QoLDB = { version = 1, options = { minimapZoneText = value } }
        Stubs.Fire("ADDON_LOADED", "QoL")
        T.eq(QoLDB.version, 2)
        return ns.Options:Get("minimapZoneText")
    end

    it("turns the zone text's above into the shared top", function()
        T.eq(migrated("above"), "top")
    end)

    it("turns the zone text's below into the shared bottom", function()
        T.eq(migrated("below"), "bottom")
    end)

    it("leaves any other zone text position alone", function()
        T.eq(migrated("insideTop"), "insideTop")
        T.eq(migrated("sideways"), "sideways")
    end)

    it("leaves a file without a zone text position without one", function()
        local ns = Stubs.LoadAddon()
        _G.QoLDB = { version = 1, options = { hideBagsBar = true } }
        Stubs.Fire("ADDON_LOADED", "QoL")
        T.eq(QoLDB.version, 2)
        T.eq(QoLDB.options.minimapZoneText, nil)
        T.eq(ns.Options:Get("minimapZoneText"), "default")
    end)

    it("migrates a file from before versions too", function()
        Stubs.LoadAddon()
        Stubs.Login({ minimapZoneText = "below" })
        T.eq(QoLDB.version, 2)
        T.eq(QoLDB.options.minimapZoneText, "bottom")
    end)
end)
