local _, ns = ...

-- Following bars: controller bars that show actions of their own while the character is in a
-- stance, in Forever's controller interface. The game's Stance bar setting changes one bar; each
-- bar ticked here changes too. The player fills them with the game's own editor, in the stance.
--
-- A following bar's buttons really change their ID, so the press, the icon and the editor (which
-- writes to button:GetID()) all use the stance's slot. A secure handler does that, in combat too:
-- a state driver on the stance runs a snippet that calls SetID on the game's buttons and sets an
-- attribute, whose OnAttributeChanged makes the button update its action. Only secure snippets
-- touch the buttons: no field is written and nothing is hooked. The editor has a page unit of its
-- own, so both page units' buttons change.
--
-- Only page 1 follows. The game resets the IDs on every page flip, so a wrap on each button's
-- OnAttributeChanged, which runs in combat, moves it again when it lands on its normal slot in the
-- stance. A page unit's page is read off its buttons: one on neither its normal slot nor a spare one
-- is on another page and is left alone. docs/dev/controller.md has why the wrap works as it does.
--
-- The slots are the spare ones after the five stance bars (ADR 0003). Each stance and bar gets its
-- slots the first time it's needed, which can be in combat, so the snippet hands them out; they're
-- kept, so spells stay put whatever is ticked. The stance is the game's bonus bar offset, whichever
-- form that is: nothing here knows which offset is which stance. Plain [bonusbar] is false in
-- stealth on Forever.
--
-- The list of bars and the slots are saved per character (QoLDB.followingBars[character]). The bar
-- the game's Stance bar setting names on page 1 is left to the game. That setting is only read.
local FollowingBars = {}
ns.FollowingBars = FollowingBars

-- Top is left out: its face buttons are reserved.
local BARS = { "left", "right", "bottom" }
FollowingBars.BARS = BARS
local SLOTS_PER_BAR = 8
local FIRST_SPARE_SLOT, LAST_SPARE_SLOT = 305, 360
local STANCE_DRIVER = "[bonusbar:1] 1; [bonusbar:2] 2; [bonusbar:3] 3; [bonusbar:4] 4; [bonusbar:5] 5; 0"
local STANCE_BAR_CVAR = "GamepadStanceBarOverride"
-- Its Enum.GamepadStanceBarOverride value for each bar.
local GAME_BAR_SETTINGS = { left = "Page1LeftBar", right = "Page1RightBar", bottom = "Page1BottomBar" }

-- The first of the slots a bar shows on page 1 in the stance now, nil if it stays on its normal ones.
local FIND_SLOTS = ([[
    local name = ...
    local stance = tonumber(self:GetAttribute("state-stance")) or 0
    if stance == 0 or not self:GetAttribute("following-" .. name) then return nil end
    local key = "slots-" .. stance .. "-" .. name
    local first = self:GetAttribute(key)
    local free = self:GetAttribute("nextslot")
    if not first and free + %d <= %d then
        first = free
        self:SetAttribute("nextslot", free + %d)
        self:SetAttribute(key, first)
    end
    return first
]]):format(SLOTS_PER_BAR - 1, LAST_SPARE_SLOT, SLOTS_PER_BAR)

-- Changes a button's slot. The attribute is what makes it update.
local MOVE = [[
    local ref, id = ...
    local button = self:GetFrameRef(ref)
    button:SetID(id)
    button:SetAttribute("qolfollowing", id)
]]

-- Moves every button on page 1 to where it belongs now. One that's there already is left alone, so
-- with nothing following the game's buttons aren't touched, and so is one on another page.
local APPLY = ([[
    for bar = 1, self:GetAttribute("barcount") do
        local name = self:GetAttribute("bar-" .. bar)
        local first = self:RunAttribute("findslots", name)
        for index = 1, %d do
            local normal = self:GetAttribute("normal-" .. name .. index)
            local id = first and first + index - 1 or normal
            for pageUnit = 1, 2 do
                local ref = (pageUnit == 1 and "main" or "edit") .. name .. index
                local current = self:GetFrameRef(ref):GetID()
                if current ~= id and (current == normal or current >= %d) then
                    self:RunAttribute("move", ref, id)
                end
            end
        end
    end
]]):format(SLOTS_PER_BAR, FIRST_SPARE_SLOT)

-- Runs inside the game's update of a button, on the two attributes it sets (controller.md has their
-- order). A button that lands on its normal slot in the stance moves on the last one it'll get. An
-- empty normal slot gets no ping-receiver, so that one moves at pressandholdaction, but the game then
-- draws the empty slot over it, and only if the new slot holds an action is there a ping-receiver
-- to redraw it at. The redraw goes by the normal slot since the attribute alone updates nothing on
-- the slot the button is on.
local FLIP = [[
    if self:GetAttribute("redrawing") then return end
    local ref, name, index, normal, attribute = ...
    local id = self:GetFrameRef(ref):GetID()
    if attribute == "ping-receiver" and self:GetAttribute("redraw-" .. ref) then
        self:SetAttribute("redraw-" .. ref, nil)
        self:SetAttribute("redrawing", true)
        self:RunAttribute("move", ref, normal)
        self:RunAttribute("move", ref, id)
        self:SetAttribute("redrawing", nil)
    elseif id == normal and (attribute == "ping-receiver" or not HasAction(normal)) then
        local first = self:RunAttribute("findslots", name)
        if first then
            local slot = first + index - 1
            self:RunAttribute("move", ref, slot)
            if attribute ~= "ping-receiver" and HasAction(slot) then
                self:SetAttribute("redraw-" .. ref, true)
            end
        end
    end
]]

-- What a button knows of itself goes in here, so that the snippet builds no strings for every update:
-- its frame ref, bar, index and normal slot.
local WRAP = [[
    if name == "pressandholdaction" or name == "ping-receiver" then
        owner:RunAttribute("flip", "%s", "%s", %d, %d, name)
    end
]]

local header
local driven = false

-- This character's saved data.
local function saved()
    local db = ns.db
    if type(db.followingBars) ~= "table" then db.followingBars = {} end
    local key = ns.PlayerKey() or ""
    local data = db.followingBars[key]
    if type(data) ~= "table" then
        data = {}
        db.followingBars[key] = data
    end
    if type(data.bars) ~= "table" then data.bars = {} end
    if type(data.slots) ~= "table" then data.slots = {} end
    return data
end

-- The bar the game's Stance bar setting names on page 1, if any.
local function gameBar()
    local value = tonumber(C_CVar.GetCVar(STANCE_BAR_CVAR))
    for _, name in ipairs(BARS) do
        if value == Enum.GamepadStanceBarOverride[GAME_BAR_SETTINGS[name]] then return name end
    end
    return nil
end

function FollowingBars.IsGameBar(name)
    return gameBar() == name
end

function FollowingBars.IsTicked(name)
    return saved().bars[name] == true
end

local function validGroup(first)
    return type(first) == "number" and first >= FIRST_SPARE_SLOT and first + SLOTS_PER_BAR - 1 <= LAST_SPARE_SLOT
end

-- Saves the slots the snippet hands out, also in combat.
local function onAttribute(_, name, value)
    local key = type(name) == "string" and name:match("^slots%-(%d%-%a+)$")
    if key then saved().slots[key] = value end
end

local function barButton(pageUnit, name, index)
    return pageUnit.actionBars[name .. "Bar"].actionButtons[index]
end

local function create()
    header = CreateFrame("Frame", "QoLFollowingBars", UIParent, "SecureHandlerStateTemplate")
    header:SetAttribute("barcount", #BARS)
    local nextSlot = FIRST_SPARE_SLOT
    for key, first in pairs(saved().slots) do
        if validGroup(first) then
            header:SetAttribute("slots-" .. key, first)
            nextSlot = math.max(nextSlot, first + SLOTS_PER_BAR)
        end
    end
    header:SetAttribute("nextslot", nextSlot)
    local main = GamepadMainActionBarFrame.PageUnit
    local pageUnits = { main = main, edit = GamepadActionBarEditFrame.PageUnit }
    for bar, name in ipairs(BARS) do
        header:SetAttribute("bar-" .. bar, name)
        for index = 1, SLOTS_PER_BAR do
            local normal = GamepadActionBarBindingUtil.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID(1,
                barButton(main, name, index):GetGamepadPageUnitSlotID())
            header:SetAttribute("normal-" .. name .. index, normal)
            for prefix, pageUnit in pairs(pageUnits) do
                local button, ref = barButton(pageUnit, name, index), prefix .. name .. index
                SecureHandlerSetFrameRef(header, ref, button)
                SecureHandlerWrapScript(button, "OnAttributeChanged", header, WRAP:format(ref, name, index, normal))
            end
        end
    end
    header:SetAttribute("findslots", FIND_SLOTS)
    header:SetAttribute("move", MOVE)
    header:SetAttribute("apply", APPLY)
    header:SetAttribute("flip", FLIP)
    header:SetAttribute("_onstate-stance", [[ self:RunAttribute("apply") ]])
    header:HookScript("OnAttributeChanged", onAttribute)
end

local function anyTicked(data)
    for _, name in ipairs(BARS) do
        if data.bars[name] == true then return true end
    end
    return false
end

-- Out of combat and away from the game's controller windows.
local function update()
    if not (ns.IsControllerUI() and GamepadMainActionBarFrame) then return end
    local data = saved()
    if not header then
        if not anyTicked(data) then return end
        create()
    end
    local byGame = gameBar()
    for _, name in ipairs(BARS) do
        header:SetAttribute("following-" .. name, data.bars[name] == true and name ~= byGame or nil)
    end
    if not driven then
        driven = true
        RegisterStateDriver(header, "stance", STANCE_DRIVER)
    end
    SecureHandlerExecute(header, [[ self:RunAttribute("apply") ]])
end

local function schedule()
    ns.LaterOutsideWindows("FollowingBars", update)
end

function FollowingBars:SetTicked(name, ticked)
    saved().bars[name] = ticked and true or nil
    schedule()
end

function FollowingBars:Init()
    if not GamepadMainActionBarFrame then return end
    ns.Events:On("GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED", schedule)
    schedule()
end
