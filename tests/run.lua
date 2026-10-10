-- Usage (from the repository root): lua tests/run.lua
package.path = "./tests/?.lua;" .. package.path

local T = require("testlib")

local SPECS = {
    "options", "api", "later", "merchant", "quests", "tooltips", "hideframes", "combatlog", "chatclasscolors",
    "combinedbagsort", "classhealthbars", "minimap", "mappins", "viewport", "actionbars", "reloadcommand",
    "settings", "locales",
}

for _, name in ipairs(SPECS) do
    T.describe(name, function()
        dofile("tests/" .. name .. "_spec.lua")
    end)
end

os.exit(T.report())
