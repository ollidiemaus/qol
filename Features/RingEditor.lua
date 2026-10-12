local _, ns = ...
local L = ns.L
local Options = ns.Options
local Ring = ns.Ring
local Entries = ns.RingEntries
local Picker = ns.RingPicker

-- The rings' editor, on the Ring page of the settings window (UI/Settings.lua, also /qol ring): a
-- page of the spell book below the page's title. On the left one ring at a time, drawn smaller than
-- in game, with arrows to the others above it and buttons for a new ring and for deleting this one;
-- on the right what this character has to put on it (RingPicker): click one to put it on the ring,
-- or to take it off again. The ring shows what this character can use, plus an empty slot to add
-- one more:
-- - drag a spell, item, toy, mount or macro onto a slot to put it there (the ones from there on
--   move one slot on), or onto the empty slot to add it at the end; one already on the ring moves;
-- - drag one off, or click it, to take it off (onto the cursor); a right-click just removes it.
-- What this character can't use stays on the ring, unseen, for the characters that can.
-- Below the ring are its two keys, set as in the game's Key Bindings: click a box, then press a
-- key or a controller button; Escape or another click cancels, a right-click clears. A key is
-- taken from the ring that had it. The keys are the ring's own, not the game's bindings, so they
-- are the same on every character and only take the key while the ring is on.
-- Nothing changes in combat: the page still shows the rings, with its buttons off and a note why.
local Editor = {}
ns.RingEditor = Editor

-- The ring is drawn at this scale, in the room the biggest one takes, to leave the list its room.
local RING_SCALE = 0.66
local SIZE = math.ceil(2 * Ring.RIM * Ring.Scale(Ring.MAX)) + 16
local LIST_WIDTH = 350
-- Between the parchment's edge and the list (its tabs stand on that edge), and between the list and
-- the ring's column.
local LIST_GAP = 10
-- Below the list, whose page buttons are at its bottom.
local LIST_BOTTOM = 4
local PAGE_BUTTON = 32
local KEY_WIDTH, KEY_HEIGHT, KEY_GAP = 120, 22, 8
local BUTTON_WIDTH, BUTTON_HEIGHT = 120, 22
-- Between the ring's column and the names and the note in it.
local INSET = 8
local CONFIRM_SECONDS = 3

-- Forever's spell book page (a single one, the condensed spell book's): its dark top bar and the
-- parchment's rims, as shares of its size (measured from interface/spellbook of client 1.60.1).
-- Without it, the same bar over plain parchment.
local PAGE = "spellbook-page-condensed-c60"
local BAR = 0.081
local RIMS = { top = 0.094, bottom = 0.026, left = 0.03, right = 0.026 }
local BAR_COLOR = { 0.11, 0.08, 0.05 }
local PAPER, PAPER_EDGE = { 0.94, 0.88, 0.74 }, { 0.78, 0.68, 0.50 }

local editor, listener
-- The ring shown, by its place in the list; the box waiting for a key ("mouse" or "stick").
local current = 1
local waiting

local function rings() return Ring.List() end
local function ring() return rings()[current] end

local function keyName(index, aim)
    return (aim == "mouse" and L.RING_KEY_MOUSE or L.RING_KEY_STICK):format(index)
end

-- A message under the ring, or for nil what holds while nothing happens: combat, the rings being
-- off, else the hint.
local function say(message)
    if not message then
        message = InCombatLockdown() and L.RING_EDITOR_COMBAT
            or Options:Get("ring") and L.RING_EDITOR_HINT or L.RING_EDITOR_OFF
    end
    editor.note:SetText(message)
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
    Picker.Draw()
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

-- Whether an entry is on the ring shown.
local function onRing(entry)
    for _, other in ipairs(ring().entries) do
        if Entries.Same(other, entry) then return true end
    end
    return false
end

-- Puts an entry from the list on the ring, at the end, or takes it off when it's there already.
local function toggle(entry)
    if InCombatLockdown() or not entry then return end
    local list = ring().entries
    for index, other in ipairs(list) do
        if Entries.Same(other, entry) then
            table.remove(list, index)
            changed()
            say(nil)
            return
        end
    end
    if #editor.indexes >= Ring.MAX then
        say(L.RING_FULL:format(Ring.MAX))
        return
    end
    list[#list + 1] = entry
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

local function newButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, BUTTON_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function fill(parent, color, layer)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetColorTexture(color[1], color[2], color[3])
    return texture
end

-- The spell book page, on the settings page below its title (top down from its top), width ×
-- height. Returns where its parchment lies, in pixels from its edges (bar: the top bar's height).
local function newPage(parent, top, width, height)
    editor = CreateFrame("Frame", "QoLRingEditor", parent)
    editor:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -top)
    editor:SetSize(width, height)
    local edges = {
        bar = math.floor(height * BAR + 0.5),
        top = math.floor(height * RIMS.top + 0.5), bottom = math.floor(height * RIMS.bottom + 0.5),
        left = math.floor(width * RIMS.left + 0.5), right = math.floor(width * RIMS.right + 0.5),
    }
    local art = editor:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    if not Picker.Atlas(art, PAGE) then
        art:SetColorTexture(PAPER_EDGE[1], PAPER_EDGE[2], PAPER_EDGE[3])
        local paper = fill(editor, PAPER, "BORDER")
        paper:SetPoint("TOPLEFT", edges.left, -edges.top)
        paper:SetPoint("BOTTOMRIGHT", -edges.right, edges.bottom)
        local bar = fill(editor, BAR_COLOR, "BORDER")
        bar:SetPoint("TOPLEFT")
        bar:SetPoint("TOPRIGHT")
        bar:SetHeight(edges.bar)
    end
    return edges
end

-- The left column, width wide: which ring it is with arrows to the others, the ring, its keys, the
-- buttons for a new ring and for deleting this one, and the note. The top bar is the list's: its
-- tabs reach over this column.
local function newRingColumn(edges, width)
    local left = edges.left
    editor.title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editor.title:SetPoint("CENTER", editor, "TOPLEFT", left + width / 2, -(edges.top + 4 + PAGE_BUTTON / 2))
    Picker.Ink(editor.title)
    editor.previous = Picker.PageButton(editor, "Prev", function() switch(-1) end)
    editor.previous:SetPoint("RIGHT", editor.title, "LEFT", -8, 0)
    editor.next = Picker.PageButton(editor, "Next", function() switch(1) end)
    editor.next:SetPoint("LEFT", editor.title, "RIGHT", 8, 0)

    -- The ring in the middle of its room. The room is at the page's scale and the ring's frame only
    -- anchored to its middle, as offsets from a smaller frame would shrink too.
    local room = CreateFrame("Frame", nil, editor)
    room:SetSize(width, SIZE * RING_SCALE)
    room:SetPoint("TOPLEFT", editor, "TOPLEFT", left, -(edges.top + 8 + PAGE_BUTTON))
    local holder = CreateFrame("Frame", nil, room)
    holder:SetScale(RING_SCALE)
    holder:SetSize(SIZE, SIZE)
    holder:SetPoint("CENTER")
    editor.art = Ring.NewArt(holder, "Button")
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

    -- Below it: its keys, a row each with the name left of the box (on two lines if need be).
    editor.keys = {}
    local above
    for _, aim in ipairs(Ring.AIMS) do
        local box = CreateFrame("Button", nil, editor, "KeyBindingFrameBindingButtonTemplate")
        box.aim = aim
        box:SetSize(KEY_WIDTH, KEY_HEIGHT)
        box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        box:SetScript("OnClick", onKeyClick)
        if above then
            box:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -KEY_GAP)
        else
            box:SetPoint("TOPRIGHT", room, "BOTTOMRIGHT", -INSET, -KEY_GAP)
        end
        local label = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("RIGHT", box, "LEFT", -INSET, 0)
        label:SetWidth(width - KEY_WIDTH - 3 * INSET)
        label:SetJustifyH("LEFT")
        label:SetText(aim == "mouse" and L.RING_AIM_MOUSE or L.RING_AIM_STICK)
        Picker.Ink(label)
        editor.keys[aim] = box
        above = box
    end

    local below = 2 * (KEY_GAP + KEY_HEIGHT) + 12
    editor.new = newButton(editor, L.RING_NEW, BUTTON_WIDTH, onNew)
    editor.new:SetPoint("TOPRIGHT", room, "BOTTOM", -4, -below)
    editor.delete = newButton(editor, L.RING_DELETE, BUTTON_WIDTH, onDelete)
    editor.delete:SetPoint("TOPLEFT", room, "BOTTOM", 4, -below)

    editor.note = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editor.note:SetPoint("TOP", room, "BOTTOM", 0, -(below + BUTTON_HEIGHT + INSET))
    editor.note:SetWidth(width - 2 * INSET)
    Picker.Ink(editor.note)
    editor.others = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editor.others:SetPoint("TOP", editor.note, "BOTTOM", 0, -4)
    editor.others:SetWidth(width - 2 * INSET)
    Picker.Ink(editor.others, true)
end

-- What this character has, to put on the ring, on the right of the page.
local function newListColumn(edges, height)
    local column = CreateFrame("Frame", nil, editor)
    column:SetSize(LIST_WIDTH, height - edges.top - edges.bottom - LIST_GAP - LIST_BOTTOM)
    column:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -(edges.right + 12), -(edges.top + LIST_GAP))
    Picker.Create(column, LIST_GAP, { has = onRing, toggle = toggle })
    editor.list = column
end

-- The buttons and key boxes work out of combat only.
local function lock(locked)
    editor.new:SetEnabled(not locked)
    editor.delete:SetEnabled(not locked)
    for _, box in pairs(editor.keys) do box:SetEnabled(not locked) end
end

-- Builds the editor on a settings page (parent), top down from its top, width × height.
function Editor:Create(parent, top, width, height)
    local edges = newPage(parent, top, width, height)
    newRingColumn(edges, width - edges.left - edges.right - 12 - LIST_WIDTH - LIST_GAP)
    newListColumn(edges, height)
    -- Leaving the page, or closing the window, stops waiting for a key and typing in the search.
    editor:SetScript("OnHide", function()
        stopWaiting()
        Picker.Hide()
    end)

    -- Nothing changes in combat (InCombatLockdown is still false while it starts), and afterwards
    -- the page shows what changed meanwhile. The ring's actions, and what this character has, may
    -- change while it's shown.
    ns.Events:On("PLAYER_REGEN_DISABLED", function()
        stopWaiting()
        lock(true)
        say(L.RING_EDITOR_COMBAT)
    end)
    ns.Events:On("PLAYER_REGEN_ENABLED", function()
        if editor:IsVisible() then self:Refresh() end
    end)
    local function later(key, fn)
        if editor:IsVisible() and not InCombatLockdown() then
            ns.Later(key, function()
                if editor:IsVisible() then fn() end
            end)
        end
    end
    for _, event in ipairs(Ring.KNOWN_EVENTS) do
        ns.Events:On(event, function()
            later("ringEditor", render)
            later("ringEditorList", Picker.Fill)
        end)
    end
    for _, event in ipairs(Ring.REFRESH_EVENTS) do
        ns.Events:On(event, function() later("ringEditor", render) end)
    end
end

-- Shows the rings and what this character has as they are now: the settings window does it when it
-- shows the page, and when the switch changes.
function Editor:Refresh()
    if not editor then return end
    render()
    Picker.Fill()
    lock(InCombatLockdown())
    say(nil)
end
