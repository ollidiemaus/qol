local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

local function start(savedOptions)
    local ns = Stubs.LoadAddon()
    Stubs.Login(savedOptions)
    return ns, Stubs.state()
end

local IDS = { tooltipIDs = true }

local function lineTexts(tooltip)
    local texts = {}
    for _, line in ipairs(tooltip.lines) do
        texts[#texts + 1] = line.right and (line.left .. " = " .. line.right) or line.left
    end
    return texts
end

describe("item tooltips", function()
    it("show the sell price, and the item ID when IDs are on", function()
        local _, state = start(IDS)
        state.prices[1234] = 75
        local tooltip = Stubs.ShowTooltip("Item", { id = 1234, lines = {} })
        T.same(lineTexts(tooltip), { "Sell Price: 75c", "Item ID = 1234" })
    end)

    it("price a bag stack by the stack size in that bag slot", function()
        start()
        Stubs.SetBags({ { bag = 2, slot = 7, itemID = 4536, quality = 1, count = 6, price = 1 } })
        -- No count on the owner: a bag addon's button, for example.
        local tooltip = Stubs.ShowTooltip("Item", { id = 4536, lines = {} }, Stubs.BagTooltip(2, 7, {}))
        T.same(lineTexts(tooltip), { "Sell Price: 6c (1c each)" })
    end)

    it("price a stack by the count on the hovered button elsewhere", function()
        local _, state = start()
        state.prices[1234] = 75
        local tooltip = Stubs.ShowTooltip("Item", { id = 1234, lines = {} }, Stubs.NewTooltip({ count = 20 }))
        T.eq(lineTexts(tooltip)[1], "Sell Price: 1500c (75c each)")
    end)

    it("replace the game's own sell price line, so a stack shows its total", function()
        start()
        Stubs.SetBags({ { bag = 0, slot = 3, itemID = 4536, quality = 1, count = 6, price = 1 } })
        local data = { id = 4536, lines = { { type = 11, price = 1 } } }
        local tooltip = Stubs.ShowTooltip("Item", data, Stubs.BagTooltip(0, 3))
        T.same(lineTexts(tooltip), { "Sell Price: 6c (1c each)" })
    end)

    it("keep the game's line for a price range", function()
        local _, state = start()
        state.prices[1234] = 75
        local data = { id = 1234, lines = { { type = 11, price = 75, maxPrice = 300 } } }
        T.same(lineTexts(Stubs.ShowTooltip("Item", data)), { "Sell Price: 75c (game)" })
    end)

    it("keep the game's line while turned off", function()
        local _, state = start({ tooltipSellPrice = false })
        state.prices[1234] = 75
        local data = { id = 1234, lines = { { type = 11, price = 75 } } }
        T.same(lineTexts(Stubs.ShowTooltip("Item", data)), { "Sell Price: 75c (game)" })
    end)

    it("keep the game's line when they can't price the item themselves", function()
        start()
        local data = { id = 999, lines = { { type = 11, price = 40 } } }
        T.same(lineTexts(Stubs.ShowTooltip("Item", data)), { "Sell Price: 40c (game)" })
    end)

    it("show no price for items a merchant won't buy or the game doesn't know yet", function()
        local _, state = start()
        state.prices[1] = 0
        T.same(lineTexts(Stubs.ShowTooltip("Item", { id = 1, lines = {} })), {})
        T.same(lineTexts(Stubs.ShowTooltip("Item", { id = 2, lines = {} })), {})
    end)

    it("show no price on comparison tooltips", function()
        local _, state = start()
        state.prices[1234] = 75
        local shopping = Stubs.NewTooltip()
        shopping.isShopping = true
        T.same(lineTexts(Stubs.ShowTooltip("Item", { id = 1234, lines = {} }, shopping)), {})
    end)

    it("respect both options", function()
        local _, state = start({ tooltipSellPrice = false })
        state.prices[1234] = 75
        T.same(lineTexts(Stubs.ShowTooltip("Item", { id = 1234, lines = {} })), {})
    end)
end)

describe("ID lines", function()
    -- IDs are opt-in; these turn them on.
    it("label spells, auras, quests, currencies and achievements", function()
        start(IDS)
        T.same(lineTexts(Stubs.ShowTooltip("Spell", { id = 133 })), { "Spell ID = 133" })
        T.same(lineTexts(Stubs.ShowTooltip("UnitAura", { id = 774 })), { "Spell ID = 774" })
        T.same(lineTexts(Stubs.ShowTooltip("Quest", { id = 747 })), { "Quest ID = 747" })
        T.same(lineTexts(Stubs.ShowTooltip("Currency", { id = 1792 })), { "Currency ID = 1792" })
        T.same(lineTexts(Stubs.ShowTooltip("Achievement", { id = 6 })), { "Achievement ID = 6" })
    end)

    it("take the NPC ID from a creature's GUID and skip players", function()
        start(IDS)
        T.same(lineTexts(Stubs.ShowTooltip("Unit", { guid = "Creature-0-1465-0-2105-448-000043F59F" })), { "NPC ID = 448" })
        T.same(lineTexts(Stubs.ShowTooltip("Unit", { guid = "Player-1305-0A1B2C3D" })), {})
    end)

    it("leave secret values out instead of touching them", function()
        start(IDS)
        T.same(lineTexts(Stubs.ShowTooltip("UnitAura", { id = Stubs.SECRET })), {})
        T.same(lineTexts(Stubs.ShowTooltip("Unit", { guid = Stubs.SECRET })), {})
    end)

    it("are off until the player turns them on", function()
        start()
        T.same(lineTexts(Stubs.ShowTooltip("Spell", { id = 133 })), {})
    end)
end)
