-- Usage (from the repository root): ~/.lua51/bin/lua tests/run.lua
-- WoW runs Lua 5.1; a newer interpreter would pass code the game rejects.
if _VERSION ~= "Lua 5.1" then
    io.stderr:write("tests/run.lua needs Lua 5.1 (got " .. _VERSION .. "): run ~/.lua51/bin/lua tests/run.lua\n")
    os.exit(1)
end
package.path = "./tests/?.lua;" .. package.path

local T = require("testlib")

local SPECS = {
    "options", "saveddata", "api", "events", "later", "merchant", "quests", "fasterautoloot", "tooltips", "hideframes", "bufftooltips",
    "combatlog", "chatclasscolors", "combinedbaglayout", "mailbookmarks", "classhealthbars",
    "druidmanabar", "screenedge", "minimap",
    "mappins", "viewport", "actionbars", "buttonborders", "barpaging", "backbuttons", "ring", "clickcast", "reloadcommand",
    "settings", "classicera", "advancedsettings", "probe", "locales",
}

for _, name in ipairs(SPECS) do
    T.describe(name, function()
        dofile("tests/" .. name .. "_spec.lua")
    end)
end

os.exit(T.report())
