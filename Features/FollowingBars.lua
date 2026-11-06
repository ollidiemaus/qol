local _, ns = ...

-- Following bars: controller bars that show actions of their own while the character is in a
-- stance, in Forever's controller interface. The game's Stance bar setting changes one bar; each
-- bar ticked here changes too. The player fills them with the game's own editor, in the stance.
--
-- A following bar's buttons really change their ID, so the press, the icon and the editor (which
-- writes to button:GetID()) all use the stance's slot. A secure handler does that, in combat too:
-- a state driver on the stance runs a snippet that calls SetID on the game's buttons and sets an
-- attribute, whose OnAttributeChanged makes the button update its action. Nothing else touches the
-- buttons: no field is written and nothing is hooked. The editor has a page unit of its own, so
-- both page units' buttons change.
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

-- Moves every bar to where it belongs now. A bar that isn't following and hasn't moved is left alone.
local APPLY = ([[
    local stance = tonumber(self:GetAttribute("state-stance")) or 0
    for bar = 1, self:GetAttribute("barcount") do
        local name = self:GetAttribute("bar-" .. bar)
        local first
        if stance > 0 and self:GetAttribute("following-" .. name) then
            local key = "slots-" .. stance .. "-" .. name
            first = self:GetAttribute(key)
            local free = self:GetAttribute("nextslot")
            if not first and free + %d <= %d then
                first = free
                self:SetAttribute("nextslot", free + %d)
                self:SetAttribute(key, first)
            end
        end
        if first or self:GetAttribute("moved-" .. name) then
            self:SetAttribute("moved-" .. name, first and true or nil)
            for index = 1, %d do
                local id = first and first + index - 1 or self:GetAttribute("normal-" .. name .. index)
                local shown, edited = self:GetFrameRef("main" .. name .. index), self:GetFrameRef("edit" .. name .. index)
                shown:SetID(id)
                shown:SetAttribute("qolfollowing", id)
                edited:SetID(id)
                edited:SetAttribute("qolfollowing", id)
            end
        end
    end
]]):format(SLOTS_PER_BAR - 1, LAST_SPARE_SLOT, SLOTS_PER_BAR, SLOTS_PER_BAR)

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
    local main, edit = GamepadMainActionBarFrame.PageUnit, GamepadActionBarEditFrame.PageUnit
    for bar, name in ipairs(BARS) do
        header:SetAttribute("bar-" .. bar, name)
        for index = 1, SLOTS_PER_BAR do
            local shown = barButton(main, name, index)
            header:SetAttribute("normal-" .. name .. index, GamepadActionBarBindingUtil
                .GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID(1, shown:GetGamepadPageUnitSlotID()))
            SecureHandlerSetFrameRef(header, "main" .. name .. index, shown)
            SecureHandlerSetFrameRef(header, "edit" .. name .. index, barButton(edit, name, index))
        end
    end
    header:SetAttribute("apply", APPLY)
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
