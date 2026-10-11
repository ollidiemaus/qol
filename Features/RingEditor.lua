local _, ns = ...
local L = ns.L
local Options = ns.Options
local Ring = ns.Ring
local Entries = ns.RingEntries
local Picker = ns.RingPicker

-- The rings' editor (/qol ring, or the Ring page's button), out of combat: a window in the game's
-- portrait frame (bronze on Forever) with a spell book page in it, moved by its title bar. On the
-- left one ring at a time, with arrows to the others in the page's top bar and buttons for a new
-- ring and for deleting this one; on the right what this character has to put on it (RingPicker):
-- click one to put it on the ring, or to take it off again. The ring shows what this character can
-- use, plus an empty slot to add one more:
-- - drag a spell, item, toy, mount or macro onto a slot to put it there (the ones from there on
--   move one slot on), or onto the empty slot to add it at the end; one already on the ring moves;
-- - drag one off, or click it, to take it off (onto the cursor); a right-click just removes it.
-- What this character can't use stays on the ring, unseen, for the characters that can.
-- Below the ring are its two keys, set as in the game's Key Bindings: click a box, then press a
-- key or a controller button; Escape or another click cancels, a right-click clears. A key is
-- taken from the ring that had it. The keys are the ring's own, not the game's bindings, so they
-- are the same on every character and only take the key while the ring is on.
-- Escape closes it; every other key goes on to the game, and opening the game's windows leaves it
-- open (the spell book, to drag from).
local Editor = {}
ns.RingEditor = Editor

local WIDTH, HEIGHT = 860, 640
-- Room for the biggest ring.
local SIZE = math.ceil(2 * Ring.RIM * Ring.Scale(Ring.MAX)) + 16
local LIST_WIDTH = 396
-- Between the parchment's edge and the list (its tabs stand on that edge).
local LIST_GAP = 10
local KEY_WIDTH, KEY_HEIGHT = 160, 22
local BUTTON_WIDTH, BUTTON_HEIGHT = 130, 22
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

-- The settings and the game menu take Escape before the editor, which the Ring page opens over them.
local function gameWindowOpen()
    return (SettingsPanel and SettingsPanel:IsShown()) or (GameMenuFrame and GameMenuFrame:IsShown())
end

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

local function newButton(text, width, onClick)
    local button = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
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

-- The spell book page inside the frame's border. Returns it and where its parchment lies, in pixels
-- from its edges (bar: the top bar's height).
local function newPage()
    local page = CreateFrame("Frame", nil, editor)
    page:SetPoint("TOPLEFT", 2, -21)
    page:SetPoint("BOTTOMRIGHT", -2, 2)
    local width, height = WIDTH - 4, HEIGHT - 23
    local edges = {
        bar = math.floor(height * BAR + 0.5),
        top = math.floor(height * RIMS.top + 0.5), bottom = math.floor(height * RIMS.bottom + 0.5),
        left = math.floor(width * RIMS.left + 0.5), right = math.floor(width * RIMS.right + 0.5),
    }
    local art = page:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    if not Picker.Atlas(art, PAGE) then
        art:SetColorTexture(PAPER_EDGE[1], PAPER_EDGE[2], PAPER_EDGE[3])
        local paper = fill(page, PAPER, "BORDER")
        paper:SetPoint("TOPLEFT", edges.left, -edges.top)
        paper:SetPoint("BOTTOMRIGHT", -edges.right, edges.bottom)
        local bar = fill(page, BAR_COLOR, "BORDER")
        bar:SetPoint("TOPLEFT")
        bar:SetPoint("TOPRIGHT")
        bar:SetHeight(edges.bar)
    end
    return page, edges
end

-- The window: the game's portrait frame, with the addon's icon and a title bar to move it by. Its
-- close button hides it directly (the template's would go through the game's panel code).
local function newWindow()
    editor = CreateFrame("Frame", "QoLRingEditor", UIParent, "PortraitFrameTemplate")
    editor:SetSize(WIDTH, HEIGHT)
    editor:SetPoint("CENTER")
    editor:SetFrameStrata("DIALOG")
    editor:SetToplevel(true)
    editor:SetMovable(true)
    editor:SetClampedToScreen(true)
    editor:SetDontSavePosition(true)
    editor:EnableMouse(true)
    editor:Hide()
    editor:SetTitle(L.RING_EDITOR)
    editor:SetPortraitToAsset("Interface\\AddOns\\QoL\\Media\\Icon")
    editor.CloseButton:SetScript("OnClick", function() editor:Hide() end)
    -- A drag, not a mouse down: the controller's cursor would stop on a frame with OnMouseDown.
    local titleBar = CreateFrame("Frame", nil, editor)
    titleBar:SetPoint("TOPLEFT", 58, 0)
    titleBar:SetPoint("TOPRIGHT", -24, 0)
    titleBar:SetHeight(21)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() editor:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() editor:StopMovingOrSizing() end)
end

-- The ring, which one it is with arrows to the others in the bar above it, and the actions on it.
local function newRingColumn(page, edges)
    local holder = CreateFrame("Frame", nil, page)
    holder:SetSize(SIZE, SIZE)
    holder:SetPoint("TOPLEFT", edges.left, -(edges.top + 4))
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

    editor.title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editor.title:SetPoint("CENTER", page, "TOPLEFT", edges.left + SIZE / 2, -edges.bar / 2)
    editor.previous = Picker.PageButton(page, "Prev", function() switch(-1) end)
    editor.previous:SetPoint("RIGHT", editor.title, "LEFT", -8, 0)
    editor.next = Picker.PageButton(page, "Next", function() switch(1) end)
    editor.next:SetPoint("LEFT", editor.title, "RIGHT", 8, 0)

    -- Below it: its keys, a row each with the name left of the box.
    editor.keys = {}
    local above
    for _, aim in ipairs(Ring.AIMS) do
        local box = CreateFrame("Button", nil, editor, "KeyBindingFrameBindingButtonTemplate")
        box.aim = aim
        box:SetSize(KEY_WIDTH, KEY_HEIGHT)
        box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        box:SetScript("OnClick", onKeyClick)
        if above then
            box:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -4)
        else
            box:SetPoint("TOPLEFT", holder, "BOTTOM", 8, 0)
        end
        local label = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("RIGHT", box, "LEFT", -8, 0)
        label:SetText(aim == "mouse" and L.RING_AIM_MOUSE or L.RING_AIM_STICK)
        Picker.Ink(label)
        editor.keys[aim] = box
        above = box
    end

    local below = 2 * KEY_HEIGHT + 12
    local new = newButton(L.RING_NEW, BUTTON_WIDTH, onNew)
    new:SetPoint("TOPRIGHT", holder, "BOTTOM", -4, -below)
    local delete = newButton(L.RING_DELETE, BUTTON_WIDTH, onDelete)
    delete:SetPoint("TOPLEFT", holder, "BOTTOM", 4, -below)

    editor.note = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editor.note:SetPoint("TOP", holder, "BOTTOM", 0, -(below + BUTTON_HEIGHT + 8))
    editor.note:SetWidth(SIZE - 16)
    Picker.Ink(editor.note)
    editor.others = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editor.others:SetPoint("TOP", editor.note, "BOTTOM", 0, -4)
    editor.others:SetWidth(SIZE - 16)
    Picker.Ink(editor.others, true)
end

-- What this character has, to put on the ring, on the right of the page.
local function newListColumn(page, edges)
    local column = CreateFrame("Frame", nil, page)
    column:SetSize(LIST_WIDTH, HEIGHT - 23 - edges.top - edges.bottom - 2 * LIST_GAP)
    column:SetPoint("TOPRIGHT", -(edges.right + 12), -(edges.top + LIST_GAP))
    Picker.Create(column, LIST_GAP, { has = onRing, toggle = toggle })
    editor.list = column
end

local function create()
    newWindow()
    -- Escape closes it, and the other keys go on to the game. Not through UISpecialFrames: the game
    -- closes those whenever one of its windows opens in the middle of the screen, the spell book too.
    editor:EnableKeyboard(true)
    editor:SetScript("OnKeyDown", function(_, key)
        if key ~= "ESCAPE" or InCombatLockdown() or gameWindowOpen() then return end
        editor:SetPropagateKeyboardInput(false)
        editor:Hide()
    end)
    editor:SetScript("OnHide", function()
        stopWaiting()
        Picker.Hide()
    end)
    local page, edges = newPage()
    newRingColumn(page, edges)
    newListColumn(page, edges)

    -- Nothing changes in combat, and the ring's actions, and what this character has, may change
    -- while it's open.
    ns.Events:On("PLAYER_REGEN_DISABLED", function() editor:Hide() end)
    local function later(key, fn)
        if editor:IsShown() and not InCombatLockdown() then
            ns.Later(key, function()
                if editor:IsShown() then fn() end
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

function Editor:Open()
    if InCombatLockdown() then
        ns.Print(L.RING_EDITOR_COMBAT)
        return
    end
    if not editor then create() end
    -- Restricted in combat; the editor is only open out of it.
    editor:SetPropagateKeyboardInput(true)
    render()
    Picker.Fill()
    say(nil)
    editor:Show()
end

function Editor:Toggle()
    if editor and editor:IsShown() then
        editor:Hide()
        return
    end
    self:Open()
end
