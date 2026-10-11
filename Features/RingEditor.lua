local _, ns = ...
local L = ns.L
local Options = ns.Options
local Ring = ns.Ring
local Entries = ns.RingEntries

-- The rings' editor (/qol ring), out of combat: one ring at a time in the middle of the screen,
-- with arrows to the others and buttons for a new ring and for deleting this one. The ring shows
-- what this character can use, plus an empty slot to add one more:
-- - drag a spell, item, toy, mount or macro onto a slot to put it there (the ones from there on
--   move one slot on), or onto the empty slot to add it at the end; one already on the ring moves;
-- - drag one off, or click it, to take it off (onto the cursor); a right-click just removes it.
-- What this character can't use stays on the ring, unseen, for the characters that can.
-- Below the ring are its two keys, set as in the game's Key Bindings: click a box, then press a
-- key or a controller button; Escape or another click cancels, a right-click clears. A key is
-- taken from the ring that had it. The keys are the ring's own, not the game's bindings, so they
-- are the same on every character and only take the key while the ring is on.
local Editor = {}
ns.RingEditor = Editor

-- Room for the biggest ring.
local SIZE = math.ceil(2 * Ring.RIM * Ring.Scale(Ring.MAX)) + 16
local KEY_WIDTH, KEY_HEIGHT = 160, 22
local BUTTON_WIDTH, BUTTON_HEIGHT = 130, 22
local ARROW_WIDTH = 28
local CONFIRM_SECONDS = 3

local editor, listener
-- The ring shown, by its place in the list; the box waiting for a key ("mouse" or "stick").
local current = 1
local waiting

local function rings() return Ring.List() end
local function ring() return rings()[current] end

local function keyName(index, aim)
    return (aim == "mouse" and L.RING_KEY_MOUSE or L.RING_KEY_STICK):format(index)
end

-- A message under the ring, or the hint for nil.
local function say(message)
    editor.note:SetText(message or (Options:Get("ring") and L.RING_EDITOR_HINT or L.RING_EDITOR_OFF))
end

---------------------------------------------------------------------------------------------------
-- Showing the ring
---------------------------------------------------------------------------------------------------

local function showKey(button, key)
    if key then
        button:SetText(GetBindingText(key))
        button:SetAlpha(1)
    else
        button:SetText("|cff808080" .. (NOT_BOUND or L.NOT_BOUND) .. "|r")
        button:SetAlpha(0.8)
    end
end

local function render()
    local list = rings()
    -- The editor always has a ring to show.
    if #list == 0 then list[1] = Ring.New() end
    current = math.max(1, math.min(current, #list))
    local shown = Ring.Shown(ring())
    local art = editor.art
    art.entries = {}
    for position, index in ipairs(shown) do art.entries[position] = ring().entries[index] end
    editor.indexes = shown
    Ring.Layout(art, math.min(#shown + 1, Ring.MAX))
    Ring.Refresh(art)
    for index, slot in ipairs(art.slots) do
        slot.plus:SetShown(index <= art.count and art.entries[index] == nil)
    end

    editor.title:SetText(L.RING_OF:format(current, #list))
    editor.previous:SetEnabled(current > 1)
    editor.next:SetEnabled(current < #list)
    local unknown = 0
    for _, entry in ipairs(ring().entries) do
        if not Entries.Known(entry) then unknown = unknown + 1 end
    end
    editor.others:SetText(unknown > 0 and L.RING_OTHERS:format(unknown) or "")
    for aim, box in pairs(editor.keys) do
        showKey(box, ring()[aim])
        box:SetSelected(waiting == aim)
    end
end

-- The rings changed: show it, and let the ring follow.
local function changed()
    render()
    Ring.Changed()
end

---------------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------------

-- Puts what's on the cursor at a slot of the ring as shown (past the last: at the end).
local function drop(position)
    local entry = Entries.FromCursor()
    if not entry then
        say(L.RING_CANT_HOLD)
        return
    end
    local list = ring().entries
    local existing
    for index, other in ipairs(list) do
        if Entries.Same(other, entry) then existing = index end
    end
    if not existing and #editor.indexes >= Ring.MAX then
        say(L.RING_FULL:format(Ring.MAX))
        return
    end
    local target = editor.indexes[position] or #list + 1
    if existing then
        table.remove(list, existing)
        if existing < target then target = target - 1 end
    end
    table.insert(list, target, entry)
    ClearCursor()
    changed()
    say(not Entries.Known(entry) and L.RING_NOT_HERE or nil)
end

-- Takes the entry at a slot off the ring, onto the cursor or away.
local function take(position, toCursor)
    local index = editor.indexes[position]
    if not index then return end
    local entry = table.remove(ring().entries, index)
    if toCursor then Entries.Pickup(entry) end
    changed()
    say(nil)
end

local function onSlotClick(slot, mouseButton)
    if InCombatLockdown() then return end
    if mouseButton == "RightButton" then
        take(slot.index, false)
    elseif GetCursorInfo() then
        drop(slot.index)
    else
        take(slot.index, true)
    end
end

local function onDragStart(slot)
    if InCombatLockdown() then return end
    take(slot.index, true)
end

local function onReceiveDrag(slot)
    if InCombatLockdown() then return end
    drop(slot.index)
end

local function onSlotEnter(slot)
    Ring.Light(editor.art, slot.index)
    GameTooltip:SetOwner(slot, "ANCHOR_RIGHT")
    local entry = editor.art.entries[slot.index]
    if entry then
        Entries.Tooltip(GameTooltip, entry)
    else
        GameTooltip:SetText(L.CATEGORY_RING)
        GameTooltip:AddLine(L.RING_ADD, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function onSlotLeave(slot)
    Ring.Light(editor.art, nil)
    if GameTooltip:IsOwned(slot) then GameTooltip:Hide() end
end

---------------------------------------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------------------------------------

local function stopWaiting()
    waiting = nil
    if listener then listener:Hide() end
    for _, box in pairs(editor.keys) do box:SetSelected(false) end
end

-- Gives this ring's aim the key (nil clears it), taking it from whichever ring had it. Returns the
-- name of that one.
local function setKey(aim, key)
    local previous
    for index, other in ipairs(rings()) do
        for _, otherAim in ipairs(Ring.AIMS) do
            if key and other[otherAim] == key and not (index == current and otherAim == aim) then
                other[otherAim] = nil
                previous = keyName(index, otherAim)
            end
        end
    end
    ring()[aim] = key
    changed()
    return previous
end

local function keyPressed(key)
    if not waiting then return end
    if key == "ESCAPE" then
        stopWaiting()
        say(nil)
        return
    end
    -- A modifier alone: wait for the key that goes with it.
    if IsKeyPressIgnoredForBinding(key) then return end
    local chord = CreateKeyChordStringUsingMetaKeyState(key)
    local aim = waiting
    stopWaiting()
    local previous = setKey(aim, chord)
    local name = keyName(current, aim)
    local message = previous and L.BINDING_MOVED:format(GetBindingText(chord), name, previous)
        or L.BINDING_SET:format(GetBindingText(chord), name)
    local action = GetBindingAction(chord)
    if action and action ~= "" then
        message = message .. " " .. L.RING_KEY_TAKEN:format(GetBindingName(action))
    end
    say(message)
end

-- Above the editor while a box waits, it takes the keyboard and the controller's buttons.
local function newListener()
    local frame = CreateFrame("Frame", nil, editor)
    frame:Hide()
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(_, key) keyPressed(key) end)
    if frame.EnableGamePadButton then
        frame:EnableGamePadButton(true)
        frame:SetScript("OnGamePadButtonDown", function(_, key) keyPressed(key) end)
    end
    return frame
end

local function onKeyClick(box, mouseButton)
    if InCombatLockdown() then return end
    local aim = box.aim
    if mouseButton == "RightButton" then
        stopWaiting()
        setKey(aim, nil)
        say(nil)
    elseif waiting == aim then
        stopWaiting()
        say(nil)
    else
        waiting = aim
        listener = listener or newListener()
        listener:Show()
        render()
        say(L.BINDING_WAIT:format(keyName(current, aim)))
    end
end

---------------------------------------------------------------------------------------------------
-- Rings
---------------------------------------------------------------------------------------------------

local function switch(offset)
    stopWaiting()
    current = current + offset
    render()
    say(nil)
end

local function onNew()
    stopWaiting()
    local list = rings()
    list[#list + 1] = Ring.New()
    current = #list
    changed()
    say(nil)
end

-- Deleting takes a second click within a few seconds.
local function onDelete(button)
    stopWaiting()
    if not button.confirm then
        local confirm = {}
        button.confirm = confirm
        button:SetText(L.RING_DELETE_CONFIRM)
        C_Timer.After(CONFIRM_SECONDS, function()
            if button.confirm ~= confirm then return end
            button.confirm = nil
            button:SetText(L.RING_DELETE)
        end)
        return
    end
    button.confirm = nil
    button:SetText(L.RING_DELETE)
    table.remove(rings(), current)
    changed()
    say(nil)
end

---------------------------------------------------------------------------------------------------
-- Editor
---------------------------------------------------------------------------------------------------

local function newButton(text, width, onClick)
    local button = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    button:SetSize(width, BUTTON_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function create()
    editor = CreateFrame("Frame", "QoLRingEditor", UIParent)
    editor:SetSize(SIZE, SIZE)
    editor:SetPoint("CENTER")
    editor:SetFrameStrata("DIALOG")
    editor:EnableMouse(true)
    editor:Hide()
    -- Escape closes it.
    table.insert(UISpecialFrames, "QoLRingEditor")
    editor:SetScript("OnHide", stopWaiting)

    editor.art = Ring.NewArt(editor, "Button")
    for _, slot in ipairs(editor.art.slots) do
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        slot:RegisterForDrag("LeftButton")
        slot:SetScript("OnClick", onSlotClick)
        slot:SetScript("OnDragStart", onDragStart)
        slot:SetScript("OnReceiveDrag", onReceiveDrag)
        slot:SetScript("OnEnter", onSlotEnter)
        slot:SetScript("OnLeave", onSlotLeave)
        slot.plus = slot.over:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        slot.plus:SetPoint("CENTER")
        slot.plus:SetText("+")
    end
    local close = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT")

    -- Above the ring: which one it is, with arrows to the others.
    editor.title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editor.title:SetPoint("BOTTOM", editor, "TOP", 0, 8)
    editor.previous = newButton("<", ARROW_WIDTH, function() switch(-1) end)
    editor.previous:SetPoint("RIGHT", editor.title, "LEFT", -12, 0)
    editor.next = newButton(">", ARROW_WIDTH, function() switch(1) end)
    editor.next:SetPoint("LEFT", editor.title, "RIGHT", 12, 0)

    -- Below it: its keys, a row each with the name left of the box.
    editor.keys = {}
    local above = editor
    for _, aim in ipairs(Ring.AIMS) do
        local box = CreateFrame("Button", nil, editor, "KeyBindingFrameBindingButtonTemplate")
        box.aim = aim
        box:SetSize(KEY_WIDTH, KEY_HEIGHT)
        box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        box:SetScript("OnClick", onKeyClick)
        if above == editor then
            box:SetPoint("TOPLEFT", editor, "BOTTOM", 8, -4)
        else
            box:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -4)
        end
        local label = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("RIGHT", box, "LEFT", -8, 0)
        label:SetText(aim == "mouse" and L.RING_AIM_MOUSE or L.RING_AIM_STICK)
        editor.keys[aim] = box
        above = box
    end

    local new = newButton(L.RING_NEW, BUTTON_WIDTH, onNew)
    new:SetPoint("TOPRIGHT", editor, "BOTTOM", -4, -(2 * KEY_HEIGHT + 20))
    local delete = newButton(L.RING_DELETE, BUTTON_WIDTH, onDelete)
    delete:SetPoint("TOPLEFT", editor, "BOTTOM", 4, -(2 * KEY_HEIGHT + 20))

    editor.note = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    editor.note:SetPoint("TOP", editor, "BOTTOM", 0, -(2 * KEY_HEIGHT + BUTTON_HEIGHT + 30))
    editor.note:SetWidth(SIZE + 60)
    editor.others = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editor.others:SetPoint("TOP", editor.note, "BOTTOM", 0, -4)
    editor.others:SetWidth(SIZE + 60)

    -- Nothing changes in combat, and the ring's actions may change while it's open.
    ns.Events:On("PLAYER_REGEN_DISABLED", function() editor:Hide() end)
    local function refresh()
        if editor:IsShown() and not InCombatLockdown() then
            ns.Later("ringEditor", function()
                if editor:IsShown() then render() end
            end)
        end
    end
    for _, event in ipairs(Ring.KNOWN_EVENTS) do ns.Events:On(event, refresh) end
    for _, event in ipairs(Ring.REFRESH_EVENTS) do ns.Events:On(event, refresh) end
end

function Editor:Toggle()
    if editor and editor:IsShown() then
        editor:Hide()
        return
    end
    if InCombatLockdown() then
        ns.Print(L.RING_EDITOR_COMBAT)
        return
    end
    if not editor then create() end
    render()
    say(nil)
    editor:Show()
end
