local _, ns = ...

-- Click casting: a binding (a combination and an action) is used on the unit frame clicked with
-- the combination, or under the mouse when it's pressed. What it changes on Blizzard's frames and
-- why that's taint-safe is in docs/dev/click-casting.md.
local ClickCast = {}
ns.ClickCast = ClickCast

local Options = ns.Options
local Entries = ns.RingEntries
local KEY = "clickCast"
local ENEMIES = "clickCastEnemies"

-- The mouse buttons, by their names in combinations: the button a click is, and the suffix of the
-- attributes for it.
local CLICKS = {
    BUTTON1 = { button = "LeftButton", suffix = "1" },
    BUTTON2 = { button = "RightButton", suffix = "2" },
    BUTTON3 = { button = "MiddleButton", suffix = "3" },
    BUTTON4 = { button = "Button4", suffix = "4" },
    BUTTON5 = { button = "Button5", suffix = "5" },
}
-- "LeftButton" -> "BUTTON1".
ClickCast.KEY_OF_BUTTON = {}
for key, click in pairs(CLICKS) do ClickCast.KEY_OF_BUTTON[click.button] = key end

-- Target and Menu as secure action types.
local UNIT_ACTIONS = { target = "target", menu = "togglemenu" }

---------------------------------------------------------------------------------------------------
-- Bindings
---------------------------------------------------------------------------------------------------

local IDS = { spell = "number", item = "number", macro = "string" }

local function valid(binding)
    if type(binding) ~= "table" or type(binding.combination) ~= "string" or type(binding.action) ~= "table" then
        return false
    end
    local kind = binding.action.kind
    return UNIT_ACTIONS[kind] ~= nil or (IDS[kind] ~= nil and type(binding.action.id) == IDS[kind])
end

-- The character's saved bindings (QoLDB.clickCast[character]), in the order made, those QoL doesn't
-- understand (a newer QoL's) among them. A character with none saved starts with the game's own
-- clicks.
local function savedBindings()
    local db = ns.db
    if type(db.clickCast) ~= "table" then db.clickCast = {} end
    local key = ns.PlayerKey() or ""
    local list = db.clickCast[key]
    if type(list) ~= "table" then
        list = { { combination = "BUTTON1", action = { kind = "target" } },
            { combination = "BUTTON2", action = { kind = "menu" } } }
        db.clickCast[key] = list
    end
    return list
end

-- The character's bindings QoL understands, in the order made. The others stay saved, unused.
function ClickCast.List()
    local list = {}
    for _, binding in ipairs(savedBindings()) do
        if valid(binding) then list[#list + 1] = binding end
    end
    return list
end

-- The spells asked for by hasRank: the saved rank of a respec can be one that isn't loaded. The game
-- answers with SPELL_DATA_LOAD_RESULT, heard only while one is out.
local requested = {}
local onSpellData

-- Whether the spell has a rank: a digit in the line under its name, whatever the locale. "Racial"
-- is no rank. One that isn't loaded has none until it is (SPELL_DATA_LOAD_RESULT).
local function hasRank(id)
    if not C_Spell.GetSpellSubtext then return false end
    if C_Spell.IsSpellDataCached and not C_Spell.IsSpellDataCached(id) and not requested[id] then
        if next(requested) == nil then ns.Events:On("SPELL_DATA_LOAD_RESULT", onSpellData) end
        requested[id] = true
        C_Spell.RequestLoadSpellData(id)
    end
    local subtext = C_Spell.GetSpellSubtext(id)
    return type(subtext) == "string" and ns.IsUsable(subtext) and subtext:find("%d") ~= nil
end

-- What a binding's action casts: for a spell with a rank, the highest rank the character knows. The
-- saved ID only says which spell it is, and stays the answer when the character knows no rank, or
-- the name is an NPC's spell too.
function ClickCast.Highest(action)
    local lookup = C_Spell.GetSpellIDForSpellIdentifier
    if action.kind ~= "spell" or not lookup or not hasRank(action.id) then return action end
    local id = lookup(C_Spell.GetSpellName(action.id))
    local highest = { kind = "spell", id = ns.IsUsable(id) and id or nil }
    return Entries.Known(highest) and highest or action
end

-- Whether two actions are one in click casting: the ranks of a spell are. Rings hold fixed ranks,
-- so Entries.Same stays as it is for them.
function ClickCast.Same(a, b)
    return Entries.Same(ClickCast.Highest(a), ClickCast.Highest(b))
end

-- Whether the character has the binding's action now.
function ClickCast.Works(binding)
    return UNIT_ACTIONS[binding.action.kind] ~= nil or Entries.Known(ClickCast.Highest(binding.action))
end

-- A combination's modifiers ({ ALT = true, CTRL = true, SHIFT = true }) and its key.
function ClickCast.Split(combination)
    local held, key = {}, combination
    while true do
        local modifier, rest = key:match("^(%u+)%-(.+)$")
        if modifier ~= "ALT" and modifier ~= "CTRL" and modifier ~= "SHIFT" then break end
        held[modifier], key = true, rest
    end
    return held, key
end

local function combine(held, key)
    return (held.ALT and "ALT-" or "") .. (held.CTRL and "CTRL-" or "") .. (held.SHIFT and "SHIFT-" or "") .. key
end

-- The prefix of the secure attributes for the modifiers.
local function prefix(held)
    return (held.ALT and "alt-" or "") .. (held.CTRL and "ctrl-" or "") .. (held.SHIFT and "shift-" or "")
end

-- Whether the combination is a click on a unit frame (the others are keys and the wheel).
function ClickCast.IsClick(combination)
    local _, key = ClickCast.Split(combination)
    return CLICKS[key] ~= nil
end

local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    SHIFT = true, CTRL = true, ALT = true }
local MOVEMENT = { "MOVEFORWARD", "MOVEBACKWARD", "STRAFELEFT", "STRAFERIGHT", "TURNLEFT", "TURNRIGHT", "JUMP" }

-- Why the combination can't be a binding ("escape", "meta": the Mac's Cmd, which combinations leave
-- out, "modifier" or "movement": a key the character moves, turns or jumps with, held with
-- modifiers or not), or nil. IsKeyPressIgnoredForBinding is the game's Key Bindings' test, which
-- also ignores Left and Right: here they're clicks like the other mouse buttons.
function ClickCast.Refusal(combination)
    local _, key = ClickCast.Split(combination)
    if key == "ESCAPE" then return "escape" end
    if key:find("^[LR]?META") then return "meta" end
    if MODIFIER_KEYS[key] or (not CLICKS[key] and IsKeyPressIgnoredForBinding(key)) then return "modifier" end
    for _, command in ipairs(MOVEMENT) do
        for _, bound in ipairs({ GetBindingKey(command) }) do
            if bound == combination or bound == key then return "movement" end
        end
    end
    return nil
end

local schedule

-- Adds a binding, sets one's combination or removes one (by its place in ClickCast.List()).
function ClickCast.Add(action, combination)
    local list = savedBindings()
    list[#list + 1] = { combination = combination, action = action }
    schedule()
end

function ClickCast.SetCombination(index, combination)
    ClickCast.List()[index].combination = combination
    schedule()
end

function ClickCast.Remove(index)
    local binding, list = ClickCast.List()[index], savedBindings()
    for at = #list, 1, -1 do
        if list[at] == binding then table.remove(list, at) end
    end
    schedule()
end

-- The bindings with an action other than this one, one binding for each action.
local function otherActions(action, bindings)
    local others = {}
    for _, binding in ipairs(bindings) do
        local seen = ClickCast.Same(binding.action, action)
        for _, other in ipairs(others) do
            seen = seen or ClickCast.Same(binding.action, other.action)
        end
        if not seen then others[#others + 1] = binding end
    end
    return others
end

-- Quick bind: binds the combination to the action. The working bindings on the combination make way
-- for it (it takes the first one's place), and their other actions are returned in the list's
-- order, each once; bindings that don't work now keep theirs.
function ClickCast.Bind(action, combination)
    local list, moved, placed = savedBindings(), {}, nil
    for index = #list, 1, -1 do
        local binding = list[index]
        if valid(binding) and binding.combination == combination and ClickCast.Works(binding) then
            if placed then table.remove(list, placed) end
            placed = index
            table.insert(moved, 1, binding)
        end
    end
    local binding = { combination = combination, action = action }
    if placed then
        list[placed] = binding
    else
        list[#list + 1] = binding
    end
    schedule()
    local replaced = {}
    for index, other in ipairs(otherActions(action, moved)) do replaced[index] = other.action end
    return replaced
end

---------------------------------------------------------------------------------------------------
-- The game's own Click Casting
---------------------------------------------------------------------------------------------------

-- Which modifiers the game's modifier bits hold. GetStringFromModifiers names each bit, in English
-- or the client's language (Shift first: German UMSCHALT has ALT in it).
local function decode(modifiers)
    local held, bit = {}, 1
    while bit <= modifiers do
        if modifiers % (bit * 2) >= bit then
            local name = GetStringFromModifiers(bit):upper()
            local function names(english, localized)
                return name:find(english, 1, true) or (localized and name:find(localized:upper(), 1, true))
            end
            if names("SHIFT", SHIFT_KEY_TEXT) then
                held.SHIFT = true
            elseif names("CTRL", CTRL_KEY_TEXT) then
                held.CTRL = true
            elseif names("ALT", ALT_KEY_TEXT) then
                held.ALT = true
            end
        end
        bit = bit * 2
    end
    return held
end

-- The type of the game's binding on each click combination ({} on clients without it).
local function gameBindings()
    local types = {}
    if not (C_ClickBindings and C_ClickBindings.GetProfileInfo and GetStringFromModifiers) then return types end
    local ok, profile = pcall(C_ClickBindings.GetProfileInfo)
    if not ok or type(profile) ~= "table" then return types end
    for _, info in ipairs(profile) do
        local key = ClickCast.KEY_OF_BUTTON[info.button]
        if key and type(info.modifiers) == "number" then types[combine(decode(info.modifiers), key)] = info.type end
    end
    return types
end

local function takenOver(kind)
    local types = Enum.ClickBindingType
    return kind ~= nil and (kind == types.Spell or kind == types.Macro or kind == types.PetAction)
end

-- For the page, each binding's marks: clashes (the working bindings on its combination with another
-- action, if any) and takenOver (the game's own Click Casting binds its click to a spell, a macro
-- or a pet action).
function ClickCast.Marks()
    local list, marks, working = ClickCast.List(), {}, {}
    local game = gameBindings()
    for index, binding in ipairs(list) do
        marks[index] = { takenOver = takenOver(game[binding.combination]) }
        if ClickCast.Works(binding) then
            local indexes = working[binding.combination] or {}
            working[binding.combination] = indexes
            indexes[#indexes + 1] = index
        end
    end
    for _, indexes in pairs(working) do
        local bindings = {}
        for at, index in ipairs(indexes) do bindings[at] = list[index] end
        for _, index in ipairs(indexes) do
            local clashes = otherActions(list[index].action, bindings)
            marks[index].clashes = clashes[1] and clashes or nil
        end
    end
    return marks
end

---------------------------------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------------------------------

local header, keysButton, clicksButton
local frames, leaving, wrapped, joined = {}, {}, {}, {}
local unwrappedParts = {}
local provided, ready, started, grid2

-- QoL's header and buttons, made once.
local function create()
    if header then return end
    header = CreateFrame("Frame", "QoLClickCast", UIParent, "SecureHandlerBaseTemplate")
    keysButton = CreateFrame("Button", "QoLClickCastKeys", UIParent, "SecureActionButtonTemplate")
    keysButton:RegisterForClicks("AnyDown")
    clicksButton = CreateFrame("Button", "QoLClickCastClicks", UIParent, "SecureActionButtonTemplate")
end

-- Blizzard's unit frames that are always there; the party, boss and arena frames come and go.
local NAMED = { "PlayerFrame", "TargetFrame", "TargetFrameToT", "FocusFrame", "FocusFrameToT", "PetFrame" }

-- A nameplate known by its name or unit is left out. Forever's pooled ones have neither when
-- CompactUnitFrame_SetUpFrame runs, so they're in; the enemy ones can be left out (leftToGame).
local function usable(frame)
    if type(frame) ~= "table" or type(frame.SetAttribute) ~= "function" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    local name, unit = frame:GetName(), frame.unit
    return not ((type(name) == "string" and name:find("NamePlate", 1, true))
        or (type(unit) == "string" and unit:find("^nameplate")))
end

local function add(frame)
    if usable(frame) then
        frames[frame], leaving[frame] = true, nil
    end
end

local function findBlizzardFrames()
    for _, name in ipairs(NAMED) do add(_G[name]) end
    for index = 1, 5 do
        add(_G["Boss" .. index .. "TargetFrame"])
        add(_G["ArenaEnemyMatchFrame" .. index])
        add(_G["ArenaEnemyFrame" .. index])
    end
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if pool then
        for frame in pool:EnumerateActive() do
            add(frame)
            add(frame.PetFrame)
        end
    end
end

-- An attribute to clear.
local NIL = {}
-- The click bindings in use and those delegated, for updatePlates; nil while click casting is off.
local plateClicks, plateDelegated
-- Per frame: its own value of each attribute changed (NIL: it had none), and what was set.
local originals, written = {}, {}

local function setAttribute(frame, attribute, value)
    if value == NIL then value = nil end
    if frame:GetAttribute(attribute) ~= value then frame:SetAttribute(attribute, value) end
end

-- The frame's own value of an attribute, from before the first change.
local function own(frame, attribute)
    local saved = originals[frame] and originals[frame][attribute]
    if saved == nil then return frame:GetAttribute(attribute) end
    if saved == NIL then return nil end
    return saved
end

-- Sets the attributes wanted, and gives the frame back its own value of each one set before and
-- not wanted now.
local function apply(frame, wanted)
    local saved = originals[frame] or {}
    originals[frame] = saved
    for attribute in pairs(written[frame] or {}) do
        if wanted[attribute] == nil then
            setAttribute(frame, attribute, saved[attribute])
            saved[attribute] = nil
        end
    end
    for attribute, value in pairs(wanted) do
        if saved[attribute] == nil then
            local current = frame:GetAttribute(attribute)
            saved[attribute] = current == nil and NIL or current
        end
        setAttribute(frame, attribute, value)
    end
    written[frame] = wanted
end

-- The secure action for a binding's spell, item or macro: a spell with a rank is cast by name, so
-- the highest rank known is cast.
local function actionOf(action)
    if action.kind == "spell" and hasRank(action.id) then return "spell", C_Spell.GetSpellName(action.id) end
    return Entries.Action(action)
end

-- The bindings in use: the first working one on each combination, clicks and keys apart.
local function inUse()
    local clicks, keys, taken = {}, {}, {}
    for _, binding in ipairs(ClickCast.List()) do
        if not taken[binding.combination] and ClickCast.Works(binding) then
            taken[binding.combination] = true
            local held, key = ClickCast.Split(binding.combination)
            local list = CLICKS[key] and clicks or keys
            list[#list + 1] = { held = held, key = key, combination = binding.combination, action = binding.action }
        end
    end
    return clicks, keys
end

-- A unit frame's click attributes. A click with no binding does nothing. Target and Menu use the
-- frame's own attribute values, unless the game's Click Casting doesn't bind the click to an
-- interaction: the game's click handler then does nothing for them, so the click goes to QoL's
-- button for them (delegated).
local function clickAttributes(frame, clicks, delegated)
    local wanted = { ["*type1"] = NIL, ["*type2"] = NIL, ["qol-clickcast"] = true }
    for _, use in ipairs(clicks) do
        local attributePrefix, suffix = prefix(use.held), CLICKS[use.key].suffix
        local kind = use.action.kind
        if delegated[use.combination] then
            wanted[attributePrefix .. "type" .. suffix] = "click"
            wanted[attributePrefix .. "clickbutton" .. suffix] = clicksButton
        elseif UNIT_ACTIONS[kind] then
            local frameType = own(frame, kind == "target" and "*type1" or "*type2")
            wanted[attributePrefix .. "type" .. suffix] = frameType or UNIT_ACTIONS[kind]
        else
            local actionType, value = actionOf(use.action)
            wanted[attributePrefix .. "type" .. suffix] = actionType
            wanted[attributePrefix .. actionType .. suffix] = value
        end
    end
    return wanted
end

-- Whether the frame is a nameplate of a unit click casting leaves to the game. Asked of a pooled
-- plate (see usable); an answer the game keeps secret counts as an enemy.
local function leftToGame(frame)
    if not frame.SetNamePlateFrame or Options:Get(ENEMIES) == true then return false end
    local unit = frame:GetAttribute("unit")
    if not unit then return false end
    local attackable = UnitCanAttack("player", unit)
    return not ns.IsUsable(attackable) or attackable == true
end

-- The frames whose unit can be an enemy or not (the boss and arena frames only show enemies).
local EITHER_SIDE = {
    TargetFrame = true, TargetFrameToT = true, FocusFrame = true, FocusFrameToT = true,
}

-- These frames' units change in combat, when attributes can't, but they are secure unit buttons:
-- when a click comes, the game sends a click on a unit the player can attack to the button
-- named by *harmbutton<n>. Those have the frame's own Target and Menu, any other button nothing.
local function offOnEnemies(frame, wanted)
    wanted["qol-enemies-off"] = true
    wanted["*harmbutton*"] = "qolenemy"
    for _, suffix in ipairs({ "1", "2" }) do
        wanted["*harmbutton" .. suffix] = "qolenemy" .. suffix
        wanted["*type-qolenemy" .. suffix] = own(frame, "*type" .. suffix)
    end
end

-- What leftToGame last said of each frame that got its attributes. Between two update()s it's all
-- that differs for a plate, so a plate with the same answer keeps the attributes it has.
local leftLast = {}

local function attributesOf(frame, clicks, delegated)
    local left = leftToGame(frame)
    leftLast[frame] = left
    if left then return {} end
    local wanted = clickAttributes(frame, clicks, delegated)
    if EITHER_SIDE[frame:GetName()] and Options:Get(ENEMIES) ~= true then offOnEnemies(frame, wanted) end
    return wanted
end

-- The keys button's attributes: key index acts as "k<index>".
local function keyAttributes(keys)
    local wanted = { useOnKeyDown = true }
    for index, use in ipairs(keys) do
        local suffix = "-k" .. index
        local kind = use.action.kind
        if UNIT_ACTIONS[kind] then
            wanted["*type" .. suffix] = UNIT_ACTIONS[kind]
        else
            local actionType, value = actionOf(use.action)
            wanted["*type" .. suffix] = actionType
            wanted["*" .. actionType .. suffix] = value
        end
    end
    return wanted
end

-- Over a registered frame, or a part of one that takes the mouse (below), its unit goes on QoL's
-- buttons and the keys click the keys button, as priority bindings so they win over the rings' keys.
-- Leaving that frame or part, or hiding it, drops them; another frame hiding (a target of target
-- losing its unit) doesn't. The game leaves the one before entering the next, so going from a frame
-- onto its health bar drops the keys and binds them again.
local ENTER = [[
    local frame = self
    while frame and not frame:GetAttribute("qol-clickcast") do frame = frame:GetParent() end
    if not frame then return end
    hovered = self
    local unit = frame:GetAttribute("unit")
    local keys = owner:GetFrameRef("keys")
    keys:SetAttribute("unit", unit)
    owner:GetFrameRef("clicks"):SetAttribute("unit", unit)
    owner:ClearBindings()
    if not unit then return end
    if frame:GetAttribute("qol-enemies-off") and SecureCmdOptionParse("[@" .. unit .. ",harm] 1") then return end
    for index = 1, owner:GetAttribute("qol-keys") or 0 do
        owner:SetBindingClick(true, owner:GetAttribute("qol-key" .. index), keys, "k" .. index)
    end
]]
local LEAVE = [[
    if hovered ~= self then return end
    hovered = nil
    owner:ClearBindings()
]]

local function wrapScripts(frame)
    if wrapped[frame] then return end
    wrapped[frame] = true
    SecureHandlerWrapScript(frame, "OnEnter", header, ENTER)
    SecureHandlerWrapScript(frame, "OnLeave", header, LEAVE)
    SecureHandlerWrapScript(frame, "OnHide", header, LEAVE)
end

-- Wrapping sets a script with SetScript, which turns clicks on, on a part that only follows the
-- mouse too: it then catches them before the frame does (seen on Forever's health and mana bars).
-- So a part gets back the click state it had: a party frame's bars take clicks themselves. With no
-- answer to put back (a secret one) it waits for a later update, as in wrapParts.
local function wrapPart(part, top)
    if wrapped[part] then return end
    local clicks = part:IsMouseClickEnabled()
    if not ns.IsUsable(clicks) then
        unwrappedParts[top] = true
        return
    end
    wrapScripts(part)
    if not clicks then part:SetMouseClickEnabled(false) end
end

-- The parts of a frame that take the mouse and are protected, as Forever's health and mana bars
-- (TextStatusBar, with SecureFrameParentPropagationTemplate on them and the frames between): the
-- mouse going onto one leaves the frame. Their snippets find the frame through their parents,
-- protected too, so in combat as well. A part can answer IsProtected and IsForbidden with a secret
-- (ObjectSecurity aspect, seen on the health bar), and whether it takes the mouse too (seen on a
-- party frame's part). SecureHandlerWrapScript can't take it either, it tests the same aspect on
-- our taint, so that part waits for a later update.
local function wrapParts(frame, top)
    for _, child in ipairs({ frame:GetChildren() }) do
        if ns.IsUsable(child) then
            local takesMouse = child.IsMouseMotionEnabled or child.IsMouseEnabled
            local mouse = takesMouse(child)
            if not ns.IsUsable(mouse) then
                unwrappedParts[top] = true
            elseif mouse then
                local protected, forbidden = child:IsProtected(), child:IsForbidden()
                if not ns.IsUsable(protected) or not ns.IsUsable(forbidden) then
                    unwrappedParts[top] = true
                elseif protected and not forbidden then
                    wrapPart(child, top)
                end
            end
            wrapParts(child, top)
        end
    end
end

-- The wraps stay once made (unwrapping could take off another addon's wrap made later); a frame
-- without qol-clickcast, and a part of none, skips them.
local function wrap(frame)
    if wrapped[frame] and not unwrappedParts[frame] then return end
    unwrappedParts[frame] = nil
    wrapScripts(frame)
    wrapParts(frame, frame)
end

---------------------------------------------------------------------------------------------------
-- Other addons' frames
---------------------------------------------------------------------------------------------------

-- A frame another addon puts in or takes out of click casting.
local function join(frame, on)
    if type(frame) ~= "table" then return end
    joined[frame] = on and true or nil
    if on then
        add(frame)
    elseif frames[frame] then
        leaving[frame] = true
    end
    schedule()
end

-- The snippets a unit frame addon's secure header runs on ClickCastHeader for a frame it made,
-- with the frame's handle in clickcast_button. A handle is no use to insecure code, so the frame
-- goes out by name (cleared again, so the same frame joining twice changes the attribute twice).
local EXPORT = [[
    local button = self:GetAttribute("clickcast_button")
    self:SetAttribute("%s", button and button:GetName())
    self:SetAttribute("%s", nil)
]]
local REGISTER = EXPORT:format("qol-joined", "qol-joined")
local UNREGISTER = EXPORT:format("qol-left", "qol-left")

-- Grid2 hands its secure headers' frames to click casting only through a global Clique (Clique's
-- header, and its ClickCastUnitTemplate for the frames, which a second addon can't declare too), so
-- QoL takes the frames Grid2 registers itself: those there already and each one it makes later.
local function takeGrid2()
    local grid = Grid2Frame
    if grid2 or type(grid) ~= "table" or type(grid.RegisterFrame) ~= "function" then return end
    grid2 = true
    hooksecurefunc(grid, "RegisterFrame", function(_, frame) join(frame, true) end)
    if type(grid.registeredFrames) == "table" then
        for _, frame in pairs(grid.registeredFrames) do join(frame, true) end
    end
end

-- The shared ClickCastFrames table and ClickCastHeader, unless another click casting addon has
-- them. A ClickCastFrames table a unit frame addon made first is taken over with its frames, and
-- Grid2's frames come along.
local function provide()
    provided = true
    if ClickCastHeader ~= nil or (ClickCastFrames ~= nil and type(ClickCastFrames) ~= "table") then return end
    local existing = ClickCastFrames
    ClickCastFrames = setmetatable({}, {
        __index = joined,
        __newindex = function(_, frame, on) join(frame, on) end,
    })
    for frame, on in pairs(existing or {}) do join(frame, on) end
    ClickCastHeader = header
    header:SetAttribute("clickcast_register", REGISTER)
    header:SetAttribute("clickcast_unregister", UNREGISTER)
    header:SetScript("OnAttributeChanged", function(_, name, value)
        if (name == "qol-joined" or name == "qol-left") and type(value) == "string" then
            join(_G[value], name == "qol-joined")
        end
    end)
    takeGrid2()
end

---------------------------------------------------------------------------------------------------
-- Updating
---------------------------------------------------------------------------------------------------

-- What only matters while click casting is on; made at Init.
local watched, plateEvents

local function update()
    if not ready then
        SecureHandlerSetFrameRef(header, "keys", keysButton)
        SecureHandlerSetFrameRef(header, "clicks", clicksButton)
        ready = true
    end
    local on = Options:Get(KEY) == true
    if on and not provided then provide() end
    findBlizzardFrames()
    local clicks, keys = {}, {}
    if on then clicks, keys = inUse() end
    local delegated, delegate = {}, { useOnKeyDown = false }
    if C_ClickBindings then
        local game = gameBindings()
        for _, use in ipairs(clicks) do
            local kind = use.action.kind
            if UNIT_ACTIONS[kind] and game[use.combination] ~= Enum.ClickBindingType.Interaction then
                delegated[use.combination] = true
                delegate[prefix(use.held) .. "type" .. CLICKS[use.key].suffix] = UNIT_ACTIONS[kind]
            end
        end
    end
    for frame in pairs(leaving) do
        apply(frame, {})
        frames[frame], leaving[frame], leftLast[frame] = nil, nil, nil
    end
    for frame in pairs(frames) do
        if on then wrap(frame) end
        apply(frame, on and attributesOf(frame, clicks, delegated) or {})
    end
    plateClicks, plateDelegated = on and clicks or nil, delegated
    watched:SetOn(on)
    plateEvents:SetOn(on)
    apply(clicksButton, delegate)
    apply(keysButton, keyAttributes(keys))
    local wanted = { ["qol-keys"] = #keys }
    for index, use in ipairs(keys) do wanted["qol-key" .. index] = use.combination end
    apply(header, wanted)
    if not on then ClearOverrideBindings(header) end
end

-- Changes wait until combat ends; the bindings stay as they were when it started. Nothing runs
-- before login: frames that join while the game loads get their bindings then.
function schedule()
    if started then ns.LaterOutsideWindows("clickCast", update) end
end

-- What changes the bindings in use or the frames, while click casting is on.
local function changed()
    if Options:Get(KEY) == true then schedule() end
end

function onSpellData(_, id)
    if not requested[id] then return end
    requested[id] = nil
    if next(requested) == nil then ns.Events:Off("SPELL_DATA_LOAD_RESULT", onSpellData) end
    changed()
end

-- A plate gets another unit, or its unit another side, in combat too, so this runs then as well: a
-- plate isn't a protected frame. Should one be, it waits for the end of combat. Plates come and go
-- all through a pull, and most keep their side, so only one that changed sides is built again.
local function updatePlates()
    if not plateClicks then return end
    for frame in pairs(frames) do
        if frame.SetNamePlateFrame and frame:GetAttribute("unit")
            and leftToGame(frame) ~= leftLast[frame] then
            local protected = frame:IsProtected()
            if InCombatLockdown() and not (ns.IsUsable(protected) and not protected) then
                changed()
            else
                apply(frame, attributesOf(frame, plateClicks, plateDelegated))
            end
        end
    end
end

local function plateChanged(_, unit)
    if type(unit) == "string" and unit:find("^nameplate") then ns.Later("clickCastPlates", updatePlates, true) end
end

-- On ADDON_LOADED (Core/Lifecycle.lua), with click casting on: ClickCastHeader is there for the unit
-- frame addons that build their frames before login.
function ClickCast:Provide()
    if Options:Get(KEY) ~= true then return end
    create()
    if not provided then provide() end
end

function ClickCast:Init()
    create()
    local events = { "GROUP_ROSTER_UPDATE" }
    for _, event in ipairs(Entries.KNOWN_EVENTS) do events[#events + 1] = event end
    watched = ns.Events:NewGroup(events, changed)
    plateEvents = ns.Events:NewGroup({ "NAME_PLATE_UNIT_ADDED", "UNIT_FACTION" }, plateChanged)
    started = true
    if CompactUnitFrame_SetUpFrame then
        hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
            add(frame)
            changed()
        end)
    end
    schedule()
    Options:Watch({ KEY, ENEMIES }, schedule)
    ns.Events:On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_ArenaUI" or name == "Blizzard_Deprecated_ArenaUI" then changed() end
    end)
end
