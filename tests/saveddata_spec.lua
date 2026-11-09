local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

describe("version", function()
    it("brings a saved file without a version up to date, its data unchanged", function()
        Stubs.LoadAddon()
        Stubs.Login({ hideBagsBar = true })
        T.eq(QoLDB.version, 3)
        T.eq(QoLDB.options.hideBagsBar, true)
    end)

    it("gives a new saved file the current version", function()
        Stubs.LoadAddon()
        Stubs.Login()
        T.eq(QoLDB.version, 3)
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
        T.eq(QoLDB.version, 3)
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
        T.eq(QoLDB.version, 3)
        T.eq(QoLDB.options.minimapZoneText, nil)
        T.eq(ns.Options:Get("minimapZoneText"), "default")
    end)

    it("migrates a file from before versions too", function()
        Stubs.LoadAddon()
        Stubs.Login({ minimapZoneText = "below" })
        T.eq(QoLDB.version, 3)
        T.eq(QoLDB.options.minimapZoneText, "bottom")
    end)
end)

describe("version 3", function()
    local function migrated(options)
        local ns = Stubs.LoadAddon()
        _G.QoLDB = { version = 2, options = options }
        Stubs.Fire("ADDON_LOADED", "QoL")
        T.eq(QoLDB.version, 3)
        return ns
    end

    it("turns hidden coordinates into the coordinates' Position hidden", function()
        local ns = migrated({ hideMinimapCoords = true })
        T.eq(ns.Options:Get("minimapCoords"), "hidden")
        T.eq(QoLDB.options.hideMinimapCoords, nil, "the old option is gone")
    end)

    it("turns a hidden calendar button into the calendar's Position hidden", function()
        local ns = migrated({ hideMinimapCalendar = true })
        T.eq(ns.Options:Get("minimapCalendar"), "hidden")
        T.eq(QoLDB.options.hideMinimapCalendar, nil, "the old option is gone")
    end)

    it("gives shown coordinates and a shown calendar button the game's spot", function()
        local ns = migrated({ hideMinimapCoords = false, hideMinimapCalendar = false })
        T.eq(ns.Options:Get("minimapCoords"), "default")
        T.eq(ns.Options:Get("minimapCalendar"), "default")
        T.eq(QoLDB.options.hideMinimapCoords, nil)
        T.eq(QoLDB.options.hideMinimapCalendar, nil)
    end)

    it("keeps every other option as it was", function()
        local ns = migrated({ hideMinimapCoords = true, minimapCoordsClassColor = true, minimapCoordsOffsetX = 4,
            minimapClock = "topRight", minimapClockSize = 14, squareMinimap = true })
        T.eq(ns.Options:Get("minimapCoordsClassColor"), true)
        T.eq(ns.Options:Get("minimapCoordsOffsetX"), 4)
        T.eq(ns.Options:Get("minimapClock"), "topRight")
        T.eq(ns.Options:Get("minimapClockSize"), 14)
        T.eq(ns.Options:Get("squareMinimap"), true)
        T.eq(ns.Options:Get("minimapCoordsSize"), 0, "the coordinates' new font size is the game's")
    end)

    it("migrates a file from before versions too", function()
        Stubs.LoadAddon()
        Stubs.Login({ minimapZoneText = "below", hideMinimapCoords = true, hideMinimapCalendar = true })
        T.eq(QoLDB.version, 3)
        T.eq(QoLDB.options.minimapZoneText, "bottom")
        T.eq(QoLDB.options.minimapCoords, "hidden")
        T.eq(QoLDB.options.minimapCalendar, "hidden")
    end)
end)
