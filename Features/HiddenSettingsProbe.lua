local _, ns = ...
local L = ns.L

-- /qol probe, a developer tool: measures the hidden settings in the client it runs in and prints a
-- report, kept in QoLDB.probe to be copied out of the SavedVariables file (docs/DEVELOPMENT.md,
-- "The hidden settings probe"). Every value it writes is put back before it ends.
local HiddenSettings = ns.HiddenSettings
local Probe = {}
ns.HiddenSettingsProbe = Probe

-- Settings considered for the page, measured with the table's. One the table takes in is measured
-- with the table's, and can come off.
local CANDIDATES = { "lodObjectMinSize" }

-- The game's 1 to 10 graphics sliders that set several of them. Their CVars count from 0.
local GAME_SLIDERS = { "graphicsViewDistance", "graphicsEnvironmentDetail", "graphicsGroundClutter" }

-- Past this either way, a side counts as having no range check.
local LIMIT = 10000000

local function show(value)
    local number = tonumber(value)
    if number == nil then return tostring(value) end
    if number % 1 == 0 then return string.format("%d", number) end
    return (string.format("%.4f", number):gsub("%.?0+$", ""))
end

-- Whether the game keeps value: reading it back gives that number.
local function takes(cvar, value)
    HiddenSettings.Set(cvar, value)
    return tonumber(HiddenSettings.Get(cvar)) == value
end

-- The furthest value it takes from start in direction (1 or -1): steps that double in size until
-- the game refuses one, then halving the gap on whole numbers, so a range that ends between two
-- (the camera distance's 2.6) gives the last whole number in it. Nil past LIMIT.
local function rangeEnd(cvar, start, direction)
    local good, bad, step = start, nil, 1
    while not bad do
        local value = start + direction * step
        if math.abs(value) > LIMIT then return nil end
        if takes(cvar, value) then good, step = value, step * 2 else bad = value end
    end
    while true do
        local first = math.floor(math.min(good, bad)) + 1
        local last = math.ceil(math.max(good, bad)) - 1
        if first > last then return good end
        local middle = math.floor((first + last) / 2)
        if takes(cvar, middle) then good = middle else bad = middle end
    end
end

-- The value and, where the client says it, the game default.
local function showWithDefault(value, gameDefault)
    if gameDefault == nil then return value .. " (no game default)" end
    return value .. " (default " .. gameDefault .. ")"
end

local function describeSetting(cvar)
    local value = HiddenSettings.Get(cvar)
    if value == nil then return "missing" end
    local gameDefault = HiddenSettings.GetGameDefault(cvar)
    local parts = { showWithDefault(show(value), gameDefault and show(gameDefault)) }
    local start = tonumber(value)
    if start then
        local low, high = rangeEnd(cvar, start, -1), rangeEnd(cvar, start, 1)
        if low or high then
            parts[#parts + 1] = (low and show(low) or "no range check") .. ".."
                .. (high and show(high) or "no range check")
        else
            parts[#parts + 1] = "no range check"
        end
        parts[#parts + 1] = (takes(cvar, start + 0.5) or takes(cvar, start - 0.5)) and "halves" or "whole numbers"
        HiddenSettings.Set(cvar, value)
    else
        parts[#parts + 1] = "not a number"
    end
    parts[#parts + 1] = HiddenSettings.IsProtected(cvar) and "protected" or "not protected"
    return table.concat(parts, ", ")
end

local function same(a, b)
    local numberA, numberB = tonumber(a), tonumber(b)
    if numberA and numberB then return numberA == numberB end
    return a == b
end

-- As the game's options show it, from 1.
local function showStep(value)
    local number = tonumber(value)
    return number and show(number + 1) or show(value)
end

-- Whether writing the slider's step again sets the settings behind it again, after they were set to
-- what another step sets. Says which ones stayed, and which the game wouldn't set to another value.
local function testRewrite(add, slider, step, behind, columns)
    if #behind == 0 then
        add("rewrite." .. slider, "sets none of these")
        return
    end
    HiddenSettings.Set(slider, step)
    local expected, moved, untested = {}, {}, {}
    for _, cvar in ipairs(behind) do
        expected[cvar] = HiddenSettings.Get(cvar)
        for _, other in ipairs(columns[cvar]) do
            if not same(other, expected[cvar]) then
                HiddenSettings.Set(cvar, other)
                break
            end
        end
        local list = same(HiddenSettings.Get(cvar), expected[cvar]) and untested or moved
        list[#list + 1] = cvar
    end
    if #moved == 0 then
        add("rewrite." .. slider, "not tested, the game took no other value")
        return
    end
    HiddenSettings.Set(slider, step)
    local stayed = {}
    for _, cvar in ipairs(moved) do
        if not same(HiddenSettings.Get(cvar), expected[cvar]) then stayed[#stayed + 1] = cvar end
    end
    local result = #stayed == 0 and "yes" or "no: " .. table.concat(stayed, ", ")
    if #untested > 0 then result = result .. ", not tested for " .. table.concat(untested, ", ") end
    add("rewrite." .. slider, result)
end

-- Writes each step and lists the settings that change with it, their values in step order.
local function scanSlider(add, slider, cvars)
    local value = HiddenSettings.Get(slider)
    if value == nil then
        add("slider." .. slider, "missing")
        return
    end
    local gameDefault = HiddenSettings.GetGameDefault(slider)
    add("slider." .. slider, showWithDefault(showStep(value), gameDefault and showStep(gameDefault)))
    local columns = {}
    for _, cvar in ipairs(cvars) do columns[cvar] = {} end
    for step = 0, 9 do
        HiddenSettings.Set(slider, step)
        for _, cvar in ipairs(cvars) do columns[cvar][step + 1] = HiddenSettings.Get(cvar) end
    end
    local behind = {}
    for _, cvar in ipairs(cvars) do
        local values, changes = columns[cvar], false
        for step = 2, 10 do changes = changes or not same(values[step], values[1]) end
        if changes then
            local shown = {}
            for step = 1, 10 do shown[step] = show(values[step]) end
            add("slider." .. slider .. "." .. cvar, table.concat(shown, " "))
            behind[#behind + 1] = cvar
        end
    end
    testRewrite(add, slider, value, behind, columns)
end

-- The table's settings, then the candidates it doesn't have.
local function watched()
    local cvars, inTable = {}, {}
    for _, setting in ipairs(HiddenSettings.SETTINGS) do
        cvars[#cvars + 1] = setting.cvar
        inTable[setting.cvar] = true
    end
    for _, cvar in ipairs(CANDIDATES) do
        if not inTable[cvar] then cvars[#cvars + 1] = cvar end
    end
    return cvars
end

local function measure(add, cvars)
    local known = {}
    for _, cvar in ipairs(cvars) do
        add("cvar." .. cvar, describeSetting(cvar))
        if HiddenSettings.IsKnown(cvar) then known[#known + 1] = cvar end
    end
    for _, slider in ipairs(GAME_SLIDERS) do scanSlider(add, slider, known) end
end

-- Writes back what was saved in touched's order, then names what didn't come back.
local function restore(add, touched, saved)
    for _, cvar in ipairs(touched) do
        if saved[cvar] ~= nil then HiddenSettings.Set(cvar, saved[cvar]) end
    end
    local allBack = true
    for _, cvar in ipairs(touched) do
        local value = HiddenSettings.Get(cvar)
        if saved[cvar] ~= nil and not same(value, saved[cvar]) then
            add("restore." .. cvar, show(value) .. ", was " .. show(saved[cvar]))
            allBack = false
        end
    end
    if allBack then add("restore", "everything back") end
end

function Probe.Run()
    if InCombatLockdown() then
        ns.Print(L.PROBE_COMBAT)
        return
    end
    local lines = {}
    local function add(key, value) lines[#lines + 1] = key .. " = " .. value end
    local version, build = GetBuildInfo()
    local client = tostring(version) .. " (build " .. tostring(build) .. "), " .. GetLocale()
    local when = date("%Y-%m-%d %H:%M")
    add("client", client)
    add("date", when)
    -- Everything it may write, the sliders first: writing one sets the settings behind it, which then
    -- get their own values back.
    local cvars, touched, saved = watched(), {}, {}
    for _, slider in ipairs(GAME_SLIDERS) do touched[#touched + 1] = slider end
    for _, cvar in ipairs(cvars) do touched[#touched + 1] = cvar end
    for _, cvar in ipairs(touched) do saved[cvar] = HiddenSettings.Get(cvar) end
    -- Whatever goes wrong, the values go back first.
    local ok, err = pcall(measure, add, cvars)
    if not ok then add("failed", tostring(err)) end
    restore(add, touched, saved)
    if not ok then geterrorhandler()(err) end
    QoLDB.probe = { client = client, date = when, lines = lines }
    for _, line in ipairs(lines) do ns.Print(line) end
    ns.Print(L.PROBE_SAVED)
end
