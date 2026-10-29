local _, ns = ...
local L = ns.L
local Options = ns.Options
local ClickCast = ns.ClickCast
local Entries = ns.RingEntries
local Picker = ns.RingPicker

-- The bindings' editor, on the Click casting page of the settings window (UI/Settings.lua, also
-- /qol click): a page of the spell book below the page's title, like the Ring page's. On the left
-- this character's bindings, a page at a time, each with its action's icon and name and a box with
-- its combination; on the right what this character has to bind (RingPicker, cut down to spells,
-- items and macros):
-- - click one, or drag a spell, item or macro onto the page, to add a binding for it: its box waits
--   for the combination (a click, the wheel or a key, with any of Shift, Ctrl and Alt); Escape
--   cancels;
-- - click a binding's box to press a new combination for it; a right-click removes the binding;
-- - in quick bind, point at an action on the right and press the combination: a working binding on
--   it gets the new action, and the note says what it had.
-- A binding this character can't use now is greyed out; a clash, or a click the game's own Click
-- Casting takes over, is in red with a tooltip why. Nothing changes in combat: the page still shows
-- the bindings, with its buttons off and a note why. While click casting is off, nothing changes
-- either, and the whole editor is greyed out but for the note saying so (its pages still turn).
local Editor = {}
ns.ClickCastEditor = Editor

local LIST_WIDTH = 350
-- Between the parchment's edge and the list (its tabs stand on that edge), and between the list and
-- the bindings' column.
local LIST_GAP = 10
-- Below the list, whose page buttons are at its bottom.
local LIST_BOTTOM = 4
local PAGE_BUTTON = 32
local ROWS, ROW_HEIGHT = 7, 44
local ICON = 32
local BOX_HEIGHT = 20
local BUTTON_WIDTH, BUTTON_HEIGHT = 120, 22
-- Between the bindings' column and the rows, the box and the note in it.
local INSET = 8
local RED = { 1, 0.2, 0.2 }

-- What can be bound from the list or the cursor.
local BINDABLE = { spell = true, item = true, macro = true }
-- Target's and Menu's names and icons, the game's Click Casting's icons for them.
local UNIT_ACTIONS = {
    target = { name = L.CLICK_CAST_TARGET, icon = 132212 },
    menu = { name = L.CLICK_CAST_MENU, icon = 134331 },
}
-- Target and Menu stay in the list while nothing binds them, as in the game's Click Casting: a click
-- on their box binds them again.
local UNBOUND = { { kind = "target" }, { kind = "menu" } }
local KEY_NAMES = {
    BUTTON1 = L.CLICK_CAST_LEFT, BUTTON2 = L.CLICK_CAST_RIGHT, BUTTON3 = L.CLICK_CAST_MIDDLE,
    BUTTON4 = L.CLICK_CAST_BUTTON4, BUTTON5 = L.CLICK_CAST_BUTTON5,
    MOUSEWHEELUP = L.CLICK_CAST_WHEEL_UP, MOUSEWHEELDOWN = L.CLICK_CAST_WHEEL_DOWN,
}

local editor, listener, quickListener, picker
-- The bindings' page shown; the box waiting for a combination ({ index } of a binding, or
-- { action } of one not added yet); whether quick bind is on.
local page = 1
local waiting
local quick

local function bindings() return ClickCast.List() end

local function on() return Options:Get("clickCast") == true end

-- The bindings change out of combat only, and while click casting is on.
local function frozen() return InCombatLockdown() or not on() end

local function actionName(action)
    local unit = UNIT_ACTIONS[action.kind]
    if unit then return unit.name end
    return Entries.Name(action) or ""
end

local function actionIcon(action)
    local unit = UNIT_ACTIONS[action.kind]
    if unit then return unit.icon end
    return Entries.Icon(action)
end

-- "Shift-Left", "Ctrl-F", "Wheel up".
local function combinationText(combination)
    local held, key = ClickCast.Split(combination)
    return (held.ALT and L.CLICK_CAST_ALT or "") .. (held.CTRL and L.CLICK_CAST_CTRL or "")
        .. (held.SHIFT and L.CLICK_CAST_SHIFT or "") .. (KEY_NAMES[key] or GetBindingText(key))
end

-- A message under the bindings, or for nil what holds while nothing happens: combat, quick bind,
-- click casting being off, else the hint.
local function say(message)
    if not message then
        message = InCombatLockdown() and L.CLICK_CAST_EDITOR_COMBAT
            or quick and L.CLICK_CAST_QUICK_HINT
            or on() and L.CLICK_CAST_EDITOR_HINT or L.CLICK_CAST_EDITOR_OFF
    end
    editor.note:SetText(message)
end

---------------------------------------------------------------------------------------------------
-- Showing the bindings
---------------------------------------------------------------------------------------------------

-- The rows: the bindings (with their place in the list), the one waiting to be added, then Target
-- and Menu where nothing binds them (unbound).
local function rows()
    local shown, bound = {}, {}
    for index, binding in ipairs(bindings()) do
        shown[index] = { action = binding.action, index = index, binding = binding }
        bound[binding.action.kind] = true
    end
    if waiting and waiting.action and not UNIT_ACTIONS[waiting.action.kind] then
        shown[#shown + 1] = { action = waiting.action }
    end
    for _, action in ipairs(UNBOUND) do
        if not bound[action.kind] then shown[#shown + 1] = { action = action, unbound = true } end
    end
    return shown
end

local function pages(count) return math.max(1, math.ceil((count or #rows()) / ROWS)) end

local function showBox(box, combination)
    if combination then
        box:SetText(combinationText(combination))
        box:SetAlpha(1)
    else
        box:SetText("|cff808080" .. (NOT_BOUND or L.NOT_BOUND) .. "|r")
        box:SetAlpha(0.8)
    end
end

local function render()
    local shown, marks = rows(), ClickCast.Marks()
    page = math.max(1, math.min(page, pages(#shown)))
    local first = (page - 1) * ROWS
    for position, row in ipairs(editor.rows) do
        local item = shown[first + position] or {}
        local binding, index = item.binding, item.index
        row.index, row.binding, row.mark = index, binding, index and marks[index]
        row.unbound = item.unbound and item.action
        row:SetShown(item.action ~= nil)
        if item.action then
            row.icon:SetTexture(actionIcon(item.action))
            row.name:SetText(actionName(item.action))
            showBox(row.box, binding and binding.combination)
            row.box:SetSelected(waiting ~= nil
                and (index and waiting.index == index or not index and waiting.action == item.action))
            local works = not binding or ClickCast.Works(binding)
            row:SetAlpha(works and 1 or 0.5)
            local mark = row.mark
            if works and mark and (mark.clashes or mark.takenOver) then
                row.name:SetTextColor(RED[1], RED[2], RED[3])
            else
                Picker.Ink(row.name, not works)
            end
        end
    end
    editor.pageText:SetText(L.RING_PAGE:format(page, pages(#shown)))
    editor.previous:SetEnabled(page > 1)
    editor.nextPage:SetEnabled(page < pages(#shown))
    editor.quick:SetText(quick and L.CLICK_CAST_QUICK_END or L.CLICK_CAST_QUICK_BIND)
    if picker then picker:Draw() end
end

local function turn(step)
    page = math.max(1, math.min(page + step, pages()))
    render()
end

---------------------------------------------------------------------------------------------------
-- Combinations
---------------------------------------------------------------------------------------------------

local function stopWaiting()
    waiting = nil
    if listener then listener:Hide() end
end

local function endQuick()
    if not quick then return end
    quick = nil
    if quickListener then quickListener:Hide() end
end

-- Says why the combination can't be a binding, and returns true; nil when it can.
local function refused(combination)
    local why = ClickCast.Refusal(combination)
    if why == "meta" then
        say(L.CLICK_CAST_REFUSED_META)
    elseif why == "modifier" then
        say(L.CLICK_CAST_REFUSED_MODIFIER)
    elseif why == "movement" then
        local _, key = ClickCast.Split(combination)
        say(L.CLICK_CAST_REFUSED_MOVEMENT:format(GetBindingText(key)))
    end
    return why ~= nil
end

-- The waiting box got a key, a mouse button or the wheel (its name in combinations).
local function pressed(key)
    if not waiting or not key then return end
    local combination = CreateKeyChordStringUsingMetaKeyState(key)
    if ClickCast.Refusal(combination) == "escape" then
        stopWaiting()
        render()
        say(nil)
        return
    end
    -- Refused: keep waiting for one that can.
    if refused(combination) then return end
    local target = waiting
    stopWaiting()
    if target.action then
        ClickCast.Add({ kind = target.action.kind, id = target.action.id }, combination)
    else
        ClickCast.SetCombination(target.index, combination)
    end
    render()
    say(nil)
end

-- Above the window while a box waits, it takes the keyboard, the mouse buttons and the wheel.
local function newListener()
    local frame = CreateFrame("Frame", nil, editor)
    frame:Hide()
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetAllPoints(UIParent)
    frame:EnableKeyboard(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnKeyDown", function(_, key) pressed(key) end)
    frame:SetScript("OnMouseDown", function(_, button) pressed(ClickCast.KEY_OF_BUTTON[button]) end)
    frame:SetScript("OnMouseWheel", function(_, delta) pressed(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
    return frame
end

-- The box of a binding (index), or of a new one for the action, waits for its combination, on the
-- page with its row.
local function wait(target)
    endQuick()
    waiting = target
    listener = listener or newListener()
    listener:Show()
    if target.action then
        for position, item in ipairs(rows()) do
            if not item.index and item.action == target.action then page = math.ceil(position / ROWS) end
        end
    end
    render()
    say(L.CLICK_CAST_WAIT:format(actionName(target.action or bindings()[target.index].action)))
end

local function add(entry)
    wait({ action = { kind = entry.kind, id = entry.id } })
end

local function remove(index)
    stopWaiting()
    ClickCast.Remove(index)
    render()
    say(nil)
end

---------------------------------------------------------------------------------------------------
-- Quick bind
---------------------------------------------------------------------------------------------------

-- Binds the action under the mouse to the combination of the key (its name in combinations).
local function quickBind(entry, key)
    if not key then return end
    local combination = CreateKeyChordStringUsingMetaKeyState(key)
    if refused(combination) then return end
    local action = { kind = entry.kind, id = entry.id }
    local replaced = ClickCast.Bind(action, combination)
    render()
    local name = actionName(action)
    if #replaced > 0 then
        for index, old in ipairs(replaced) do replaced[index] = actionName(old) end
        name = L.CLICK_CAST_REPLACED:format(name, table.concat(replaced, ", "))
    end
    say(combinationText(combination) .. ": " .. name)
end

-- While quick bind is on, a key over an action on the right binds it; Escape ends quick bind, and
-- every other key goes on to the game.
local function onQuickKey(frame, key)
    if key == "ESCAPE" then
        frame:SetPropagateKeyboardInput(false)
        endQuick()
        render()
        say(nil)
        return
    end
    local entry = picker:EntryUnderMouse()
    if not entry or ClickCast.Refusal(key) == "modifier" then
        frame:SetPropagateKeyboardInput(true)
        return
    end
    frame:SetPropagateKeyboardInput(false)
    quickBind(entry, key)
end

local function onQuick()
    if frozen() then return end
    if quick then
        endQuick()
    else
        stopWaiting()
        quick = true
        if not quickListener then
            quickListener = CreateFrame("Frame", nil, editor)
            quickListener:SetFrameStrata("FULLSCREEN_DIALOG")
            quickListener:EnableKeyboard(true)
            quickListener:SetScript("OnKeyDown", onQuickKey)
        end
        quickListener:Show()
    end
    render()
    say(nil)
end

---------------------------------------------------------------------------------------------------
-- The list on the right, and the cursor
---------------------------------------------------------------------------------------------------

local function bound(entry)
    for _, binding in ipairs(bindings()) do
        if Entries.Same(binding.action, entry) then return true end
    end
    return false
end

local function onListClick(entry, mouseButton)
    if frozen() or not entry then return end
    if quick then
        quickBind(entry, ClickCast.KEY_OF_BUTTON[mouseButton])
    elseif mouseButton == "LeftButton" then
        add(entry)
    end
end

local function onListWheel(delta)
    local entry = quick and picker:EntryUnderMouse()
    if not entry or InCombatLockdown() then return false end
    quickBind(entry, delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    return true
end

-- A spell, item or macro dropped on the page gets a binding.
local function onReceiveDrag()
    if frozen() or not GetCursorInfo() then return end
    local entry = Entries.FromCursor()
    ClearCursor()
    if entry and BINDABLE[entry.kind] then
        add(entry)
    else
        say(L.CLICK_CAST_CANT_BIND)
    end
end

---------------------------------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------------------------------

-- The tooltips say what a click does only while click casting is on.
local function onRowEnter(row)
    local binding = row.binding
    if row.unbound then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(actionName(row.unbound))
        if on() then GameTooltip:AddLine(L.CLICK_CAST_UNBOUND_TIP, 0, 1, 0, true) end
        GameTooltip:Show()
    end
    if not binding then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if UNIT_ACTIONS[binding.action.kind] then
        GameTooltip:SetText(actionName(binding.action))
    else
        Entries.Tooltip(GameTooltip, binding.action)
    end
    local mark = row.mark or {}
    if not ClickCast.Works(binding) then
        GameTooltip:AddLine(L.CLICK_CAST_UNUSABLE, 0.6, 0.6, 0.6, true)
    else
        if mark.clashes then
            local names = {}
            for index, other in ipairs(mark.clashes) do names[index] = actionName(other.action) end
            local list = names[#names]
            if #names > 1 then list = L.LIST_AND:format(table.concat(names, ", ", 1, #names - 1), list) end
            GameTooltip:AddLine(L.CLICK_CAST_CLASH:format(list), RED[1], RED[2], RED[3], true)
        end
        if mark.takenOver then GameTooltip:AddLine(L.CLICK_CAST_TAKEN_OVER, RED[1], RED[2], RED[3], true) end
    end
    if on() then GameTooltip:AddLine(L.CLICK_CAST_BINDING_TIP, 0, 1, 0, true) end
    GameTooltip:Show()
end

local function onRowLeave(row)
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function onRowClick(row, mouseButton)
    if frozen() or not row.index then return end
    if mouseButton == "RightButton" then remove(row.index) end
end

local function onBoxClick(box, mouseButton)
    local row = box:GetParent()
    if frozen() then return end
    if mouseButton == "RightButton" then
        if row.index then
            remove(row.index)
        else
            stopWaiting()
            render()
            say(nil)
        end
    elseif row.index then
        wait({ index = row.index })
    elseif row.unbound then
        wait({ action = row.unbound })
    end
end

local function newRow(column, position)
    local row = CreateFrame("Button", nil, column)
    row:SetSize(column:GetWidth(), ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(position - 1) * ROW_HEIGHT)
    row:RegisterForClicks("RightButtonUp")
    row:SetScript("OnClick", onRowClick)
    row:SetScript("OnReceiveDrag", onReceiveDrag)
    row:SetScript("OnEnter", onRowEnter)
    row:SetScript("OnLeave", onRowLeave)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", INSET, 0)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", INSET, 0)
    row.name:SetPoint("RIGHT", -INSET, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    Picker.Ink(row.name)

    local box = CreateFrame("Button", nil, row, "KeyBindingFrameBindingButtonTemplate")
    row.box = box
    box:SetHeight(BOX_HEIGHT)
    box:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", INSET, 0)
    box:SetPoint("RIGHT", -INSET, 0)
    box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    box:SetScript("OnClick", onBoxClick)
    box:SetScript("OnEnter", function() onRowEnter(row) end)
    box:SetScript("OnLeave", function() onRowLeave(row) end)
    return row
end

---------------------------------------------------------------------------------------------------
-- Editor
---------------------------------------------------------------------------------------------------

-- The left column, width wide: its title, the bindings a page at a time, the page buttons, the
-- Quick bind button and the note. The top bar is the list's: its tabs reach over this column.
local function newBindingsColumn(edges, width)
    local left = edges.left
    editor.title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editor.title:SetPoint("CENTER", editor, "TOPLEFT", left + width / 2, -(edges.top + 4 + PAGE_BUTTON / 2))
    editor.title:SetText(L.CLICK_CAST_BINDINGS)
    Picker.Ink(editor.title)

    local column = CreateFrame("Frame", nil, editor)
    column:SetSize(width, ROWS * ROW_HEIGHT)
    column:SetPoint("TOPLEFT", editor, "TOPLEFT", left, -(edges.top + 8 + PAGE_BUTTON))
    column:EnableMouse(true)
    column:SetScript("OnReceiveDrag", onReceiveDrag)
    column:EnableMouseWheel(true)
    column:SetScript("OnMouseWheel", function(_, delta) turn(delta > 0 and -1 or 1) end)
    editor.rows = {}
    for position = 1, ROWS do editor.rows[position] = newRow(column, position) end

    -- "Page 2/3" and the page buttons at the bottom right, as in the list; Quick bind on the left.
    editor.nextPage = Picker.PageButton(editor, "Next", function() turn(1) end)
    editor.nextPage:SetPoint("TOPRIGHT", column, "BOTTOMRIGHT", 0, -6)
    editor.previous = Picker.PageButton(editor, "Prev", function() turn(-1) end)
    editor.previous:SetPoint("RIGHT", editor.nextPage, "LEFT", -4, 0)
    editor.pageText = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    editor.pageText:SetPoint("RIGHT", editor.previous, "LEFT", -8, 0)
    Picker.Ink(editor.pageText)
    editor.quick = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    editor.quick:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    editor.quick:SetPoint("LEFT", column, "BOTTOMLEFT", INSET, -(6 + PAGE_BUTTON / 2))
    editor.quick:SetScript("OnClick", onQuick)

    editor.note = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editor.note:SetPoint("TOP", column, "BOTTOM", 0, -(6 + PAGE_BUTTON + INSET))
    editor.note:SetWidth(width - 2 * INSET)
    Picker.Ink(editor.note)
    -- What's greyed out while click casting is off (the list joins them).
    editor.parts = { editor.title, column, editor.nextPage, editor.previous, editor.pageText, editor.quick }
end

-- What this character has, to bind, on the right of the page.
local function newListColumn(edges, height)
    local column = CreateFrame("Frame", nil, editor)
    column:SetSize(LIST_WIDTH, height - edges.top - edges.bottom - LIST_GAP - LIST_BOTTOM)
    column:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -(edges.right + 12), -(edges.top + LIST_GAP))
    picker = Picker.Create(column, LIST_GAP, {
        kinds = { "spell", "item", "macro" },
        has = bound,
        clicks = { "AnyUp" },
        click = onListClick,
        hint = function()
            if not on() then return nil end
            return quick and L.CLICK_CAST_LIST_QUICK or L.CLICK_CAST_LIST_ADD
        end,
        wheel = onListWheel,
    })
    editor.list = column
    editor.parts[#editor.parts + 1] = column
end

-- The buttons and boxes work out of combat only (locked), and while click casting is on; while it's
-- off, the editor is greyed out but for the note.
local function lock(locked)
    locked = locked or not on()
    editor.quick:SetEnabled(not locked)
    for _, row in ipairs(editor.rows) do row.box:SetEnabled(not locked) end
    for _, part in ipairs(editor.parts) do part:SetAlpha(on() and 1 or 0.5) end
end

-- Builds the editor on a settings page (parent), top down from its top, width × height.
function Editor:Create(parent, top, width, height)
    local edges
    editor, edges = Picker.NewPage("QoLClickCastEditor", parent, top, width, height)
    newBindingsColumn(edges, width - edges.left - edges.right - 12 - LIST_WIDTH - LIST_GAP)
    newListColumn(edges, height)
    -- Leaving the page, or closing the window, stops waiting, quick bind and typing in the search.
    editor:SetScript("OnHide", function()
        stopWaiting()
        endQuick()
        picker:Hide()
    end)

    -- Nothing changes in combat (InCombatLockdown is still false while it starts), and afterwards
    -- the page shows what changed meanwhile. What this character has may change while it's shown.
    ns.Events:On("PLAYER_REGEN_DISABLED", function()
        stopWaiting()
        endQuick()
        render()
        lock(true)
        say(L.CLICK_CAST_EDITOR_COMBAT)
    end)
    ns.Events:On("PLAYER_REGEN_ENABLED", function()
        if editor:IsVisible() then self:Refresh() end
    end)
    -- Made once: the events ask for them many times a second while the editor shows.
    local function shownNow()
        if not editor:IsVisible() then return end
        render()
        picker:Fill()
    end
    for _, event in ipairs(Entries.KNOWN_EVENTS) do
        ns.Events:On(event, function()
            if editor:IsVisible() and not InCombatLockdown() then ns.Later("clickCastEditor", shownNow) end
        end)
    end
end

-- Shows the bindings and what this character has as they are now: the settings window does it
-- when it shows the page, and when the switch changes (off stops a box waiting and quick bind).
function Editor:Refresh()
    if not editor then return end
    if not on() then
        stopWaiting()
        endQuick()
    end
    render()
    picker:Fill()
    lock(InCombatLockdown())
    say(nil)
end
