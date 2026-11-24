local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local FILE = "Interface\\AddOns\\QoL\\Media\\AuctionSale.ogg"
local ONE = { { FILE, "Master" } }
local TWO = { { FILE, "Master" }, { FILE, "Master" } }
local EVENTS = { "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION", "AUCTION_HOUSE_SHOW_NOTIFICATION", "CHAT_MSG_SYSTEM" }

-- The addon, logged in. globals: globals of the client set before that, false for one it lacks.
local function start(savedOptions, globals, loadOptions)
    local ns = Stubs.LoadAddon(loadOptions)
    for name, value in pairs(globals or {}) do _G[name] = value or nil end
    Stubs.Login(savedOptions)
    return ns, Stubs.state()
end

local ON = { auctionSaleSound = true }

local function formatted(notification, text)
    Stubs.Fire("AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION", notification, text or "Copper Bar", 7)
end
local function plain(notification) Stubs.Fire("AUCTION_HOUSE_SHOW_NOTIFICATION", notification) end
local function system(text) Stubs.Fire("CHAT_MSG_SYSTEM", text) end

local SOLD = 4
local SOLD_LINE = "A buyer has been found for your auction of Copper Bar."

describe("auction sale sound", function()
    it("is silent for a fresh install and listens to nothing", function()
        local _, state = start()
        formatted(SOLD)
        plain(SOLD)
        system(SOLD_LINE)
        T.same(state.soundFiles, {})
        for _, event in ipairs(EVENTS) do T.eq(Stubs.Listens(event), false, event) end
    end)

    it("plays the cash register on the Master channel when the game says an auction sold", function()
        for _, sale in ipairs({ formatted, plain }) do
            local _, state = start(ON)
            sale(SOLD)
            T.same(state.soundFiles, ONE)
        end
    end)

    it("plays it for the system chat line", function()
        local _, state = start(ON)
        system(SOLD_LINE)
        T.same(state.soundFiles, ONE)
    end)

    it("plays it in combat", function()
        local _, state = start(ON)
        Stubs.SetCombat(true)
        formatted(SOLD)
        T.same(state.soundFiles, ONE)
    end)

    it("is silent for every other auction notification", function()
        local _, state = start(ON)
        for _, other in ipairs({ 0, 1, 2, 3, 5 }) do
            formatted(other)
            plain(other)
        end
        T.same(state.soundFiles, {})
    end)

    it("is silent for other system lines, also ones that only contain the sold line", function()
        local _, state = start(ON)
        for _, line in ipairs({ "You won an auction for Copper Bar.", "Your auction of Copper Bar has expired.",
            "You receive 5 Gold", "Bob: " .. SOLD_LINE, SOLD_LINE .. " Really",
            "A buyer has been found for your auction of Copper Bar!" }) do
            system(line)
        end
        T.same(state.soundFiles, {})
    end)

    it("knows the sold line in other languages", function()
        for _, case in ipairs({
            { "Es wurde ein Käufer für Eure Auktion gefunden: %1$s.",
                "Es wurde ein Käufer für Eure Auktion gefunden: Kupferbarren." },
            { "경매에 올린 %s의 구매자가 나타났습니다.", "경매에 올린 구리 주괴의 구매자가 나타났습니다." },
            { "На ваш товар \"%s\" нашелся покупатель.", "На ваш товар \"Медный слиток\" нашелся покупатель." },
            { "[Auction] (%s) sold - 100%%?", "[Auction] (Copper Bar) sold - 100%?" },
            { "Your auction of %s sold.", "Your auction of Copper Bar sold." }, -- Classic Era's
            -- Korean: the particle after the name, as it is or chosen.
            { "경매에 올린 %s|1이;가; 판매되었습니다.", "경매에 올린 구리 주괴|1이;가; 판매되었습니다." },
            { "경매에 올린 %s|1이;가; 판매되었습니다.", "경매에 올린 구리 주괴가 판매되었습니다." },
            -- French: the client may leave the "de" or "d'" to the text's display, or put it in itself.
            { "Un acheteur a été trouvé pour votre enchère |2 %s.",
                "Un acheteur a été trouvé pour votre enchère |2 Barre de cuivre." },
            { "Un acheteur a été trouvé pour votre enchère |2 %s.",
                "Un acheteur a été trouvé pour votre enchère d'Anneau." },
        }) do
            local _, state = start(ON, { ERR_AUCTION_SOLD_S = case[1] })
            system(case[2])
            T.same(state.soundFiles, ONE, case[2])
            Stubs.Wait(5)
            system(SOLD_LINE)
            T.same(state.soundFiles, ONE, "another language's line")
        end
    end)

    it("copes with pattern characters in the item's name", function()
        local _, state = start(ON)
        system("A buyer has been found for your auction of |cffffffff|Hitem:1|h[Plans: 100% (a-z) %s.*+?^$]|h|r.")
        T.same(state.soundFiles, ONE)
    end)

    it("pings once for a sale announced both ways", function()
        local _, state = start(ON)
        formatted(SOLD)
        plain(SOLD)
        system(SOLD_LINE)
        T.same(state.soundFiles, ONE)
    end)

    it("pings once for a burst, which doesn't keep later sales silent", function()
        local _, state = start(ON)
        formatted(SOLD)
        Stubs.Wait(0.6)
        formatted(SOLD)
        T.same(state.soundFiles, ONE)
        -- A second after the ping, half a second after the silent sale.
        Stubs.Wait(0.5)
        formatted(SOLD)
        T.same(state.soundFiles, TWO)
    end)

    it("follows the option at once, without a reload", function()
        local ns, state = start()
        ns.Options:Set("auctionSaleSound", true)
        formatted(SOLD)
        T.same(state.soundFiles, ONE)

        ns.Options:Set("auctionSaleSound", false)
        Stubs.Wait(5)
        formatted(SOLD)
        system(SOLD_LINE)
        T.same(state.soundFiles, ONE)
        for _, event in ipairs(EVENTS) do T.eq(Stubs.Listens(event), false, event) end

        ns.Options:Set("auctionSaleSound", true)
        system(SOLD_LINE)
        T.same(state.soundFiles, TWO)
    end)

    it("ignores secret payloads without an error", function()
        local _, state = start(ON)
        formatted(Stubs.SECRET, Stubs.SECRET)
        plain(Stubs.SECRET)
        system(Stubs.SECRET)
        system(nil)
        T.same(state.soundFiles, {})
    end)

    it("needs neither the notification events nor their enum: the chat line is enough", function()
        local _, state = start(ON, nil, { unknownEvents = { AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION = true,
            AUCTION_HOUSE_SHOW_NOTIFICATION = true } })
        system(SOLD_LINE)
        T.same(state.soundFiles, ONE)

        local ns = Stubs.LoadAddon()
        state = Stubs.state()
        Enum.AuctionHouseNotification = nil
        Stubs.Login(ON)
        T.truthy(ns.Options:Get("auctionSaleSound"))
        formatted(SOLD)
        formatted(nil)
        plain(nil)
        T.same(state.soundFiles, {})
        system(SOLD_LINE)
        T.same(state.soundFiles, ONE)
    end)

    it("needs no sold string: the notification is enough", function()
        local _, state = start(ON, { ERR_AUCTION_SOLD_S = false })
        system(SOLD_LINE)
        T.same(state.soundFiles, {})
        formatted(SOLD)
        T.same(state.soundFiles, ONE)
    end)

    it("plays on Classic Era too", function()
        local _, state = start(ON, nil, { client = "classicEra" })
        formatted(SOLD)
        T.same(state.soundFiles, ONE)
        Stubs.Wait(2)
        system(SOLD_LINE)
        T.same(state.soundFiles, TWO)
    end)

    it("previews from the Automation page, also while off and right after a sale", function()
        local ns = Stubs.LoadAddon()
        local state = Stubs.state()
        Stubs.InstallSettings()
        Stubs.Login()
        local preview
        for _, control in ipairs(ns.SettingsPanel.pages.automation.controls) do
            if control.kind == "button" then preview = control end
        end
        T.eq(preview.text:GetText(), "Preview sound")
        preview.widget:Click()
        T.same(state.soundFiles, ONE)

        ns.Options:Set("auctionSaleSound", true)
        formatted(SOLD)
        T.same(state.soundFiles, TWO, "a preview doesn't silence a sale")
        preview.widget:Click()
        T.eq(#state.soundFiles, 3)
    end)
end)
