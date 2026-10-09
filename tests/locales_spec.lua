local T = require("testlib")
local Stubs = require("wow_stubs")
local describe, it = T.describe, T.it

-- Strings that are the same in both languages.
local SAME = { ADDON_TITLE = true, SECTION_TOOLTIPS = true, PIXELS = true, CATEGORY_VIEWPORT = true }

local function strings(locale)
    return Stubs.LoadAddon({ locale = locale }).L
end

local function placeholders(text)
    local found = {}
    for placeholder in text:gmatch("%%[%d%.]*[sd]") do found[#found + 1] = placeholder end
    return table.concat(found, " ")
end

describe("locales", function()
    it("translate every English string into German, with the same placeholders", function()
        local english = strings("enUS")
        local german = strings("deDE")
        local count = 0
        for key, value in pairs(english) do
            count = count + 1
            if not SAME[key] then
                T.truthy(german[key] ~= value, "German for " .. key)
            end
            T.eq(placeholders(german[key]), placeholders(value), "placeholders of " .. key)
        end
        T.truthy(count > 50, "found the English strings")
    end)

    it("show the key for a missing string instead of failing", function()
        local L = strings("enUS")
        T.eq(L.NOT_A_REAL_KEY, "NOT_A_REAL_KEY")
    end)
end)
