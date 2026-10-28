local _, ns = ...

-- Click casting: a binding (a combination and an action) is used on the unit frame clicked with
-- the combination, or under the mouse when it's pressed. What it changes on Blizzard's frames and
-- why that's taint-safe is in docs/DEVELOPMENT.md, "Click casting".
local ClickCast = {}
ns.ClickCast = ClickCast

local Options = ns.Options
local Entries = ns.RingEntries
local KEY = "clickCast"

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

-- Whether the character has the binding's action now.
function ClickCast.Works(binding)
    return UNIT_ACTIONS[binding.action.kind] ~= nil or Entries.Known(binding.action)
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
-- modifiers or not), or nil.
function ClickCast.Refusal(combination)
    local _, key = ClickCast.Split(combination)
    if key == "ESCAPE" then return "escape" end
    if key:find("^[LR]?META") then return "meta" end
    if MODIFIER_KEYS[key] or IsKeyPressIgnoredForBinding(key) then return "modifier" end
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

-- Quick bind: binds the combination to the action. The working bindings on the combination make way
-- for it (it takes the first one's place), and their other actions are returned in the list's order;
-- bindings that don't work now keep theirs.
function ClickCast.Bind(action, combination)
    local list, replaced, placed = savedBindings(), {}, nil
    for index = #list, 1, -1 do
        local binding = list[index]
        if valid(binding) and binding.combination == combination and ClickCast.Works(binding) then
            if placed then table.remove(list, placed) end
            placed = index
            if not Entries.Same(binding.action, action) then table.insert(replaced, 1, binding.action) end
        end
    end
    local binding = { combination = combination, action = action }
    if placed then
        list[placed] = binding
    else
        list[#list + 1] = binding
    end
    schedule()
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

-- For the page, each binding's marks: clashes (the other working bindings on its combination, if
-- any) and takenOver (the game's own Click Casting binds its click to a spell, a macro or a pet
-- action).
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
        if #indexes > 1 then
            for _, index in ipairs(indexes) do
                local clashes = {}
                for _, other in ipairs(indexes) do
                    if other ~= index then clashes[#clashes + 1] = list[other] end
                end
                marks[index].clashes = clashes
            end
        end
    end
    return marks
end

---------------------------------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------------------------------

local header, keysButton, clicksButton
local frames, leaving, wrapped, joined = {}, {}, {}, {}
local provided, ready, started

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
    if action.kind == "spell" and C_Spell.GetSpellSubtext then
        local subtext = C_Spell.GetSpellSubtext(action.id)
        if type(subtext) == "string" and ns.IsUsable(subtext) and subtext:find("%d") then
            return "spell", C_Spell.GetSpellName(action.id)
        end
    end
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

-- Over a registered frame, its unit goes on QoL's buttons and the keys click the keys button, as
-- priority bindings so they win over the rings' keys. Leaving that frame or hiding it drops them;
-- another frame hiding (a target of target losing its unit) doesn't.
local ENTER = [[
    if not self:GetAttribute("qol-clickcast") then return end
    hovered = self
    local unit = self:GetAttribute("unit")
    local keys = owner:GetFrameRef("keys")
    keys:SetAttribute("unit", unit)
    owner:GetFrameRef("clicks"):SetAttribute("unit", unit)
    owner:ClearBindings()
    if not unit then return end
    for index = 1, owner:GetAttribute("qol-keys") or 0 do
        owner:SetBindingClick(true, owner:GetAttribute("qol-key" .. index), keys, "k" .. index)
    end
]]
local LEAVE = [[
    if hovered ~= self then return end
    hovered = nil
    owner:ClearBindings()
]]

-- The wraps stay once made (unwrapping could take off another addon's wrap made later); a frame
-- without qol-clickcast skips them.
local function wrap(frame)
    if wrapped[frame] then return end
    wrapped[frame] = true
    SecureHandlerWrapScript(frame, "OnEnter", header, ENTER)
    SecureHandlerWrapScript(frame, "OnLeave", header, LEAVE)
    SecureHandlerWrapScript(frame, "OnHide", header, LEAVE)
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

-- The shared ClickCastFrames table and ClickCastHeader, unless another click casting addon has
-- them. A ClickCastFrames table a unit frame addon made first is taken over with its frames.
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
end

---------------------------------------------------------------------------------------------------
-- Updating
---------------------------------------------------------------------------------------------------

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
        frames[frame], leaving[frame] = nil, nil
    end
    for frame in pairs(frames) do
        if on then wrap(frame) end
        apply(frame, on and clickAttributes(frame, clicks, delegated) or {})
    end
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

-- On ADDON_LOADED (Core/Lifecycle.lua), with click casting on: ClickCastHeader is there for the unit
-- frame addons that build their frames before login.
function ClickCast:Provide()
    if Options:Get(KEY) ~= true then return end
    create()
    if not provided then provide() end
end

function ClickCast:Init()
    create()
    started = true
    if CompactUnitFrame_SetUpFrame then
        hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
            add(frame)
            changed()
        end)
    end
    schedule()
    Options:Watch({ KEY }, schedule)
    for _, event in ipairs(Entries.KNOWN_EVENTS) do ns.Events:On(event, changed) end
    ns.Events:On("GROUP_ROSTER_UPDATE", changed)
    ns.Events:On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_ArenaUI" or name == "Blizzard_Deprecated_ArenaUI" then changed() end
    end)
end
