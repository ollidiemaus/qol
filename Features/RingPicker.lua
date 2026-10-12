local _, ns = ...
local L = ns.L
local Entries = ns.RingEntries

-- The ring editor's list of what this character can put on a ring, laid out like Forever's spell
-- book: tabs for spells, items, toys, mounts and macros in the page's dark top bar, a search box,
-- and two columns of entries on parchment, a page at a time, with the spell book's page buttons
-- (the mouse wheel turns pages too). A click puts an entry on the ring, or takes it off when it's
-- already there (it has a check mark); dragging one puts it on the cursor, to drop on a slot.
-- Also the parchment's look, for the editor around it: ink, and the spell book's fonts.
local Picker = {}
ns.RingPicker = Picker

local KINDS = { "spell", "item", "toy", "mount", "macro" }
local LABELS = {
    spell = L.RING_SPELLS, item = L.RING_ITEMS, toy = L.RING_TOYS, mount = L.RING_MOUNTS, macro = L.RING_MACROS,
}
-- Two columns of nine: what fits the settings page below its search box and above its page buttons.
Picker.COLUMNS, Picker.ROWS = 2, 9
Picker.ROW_HEIGHT = 44
local ICON = 36
local SEARCH_HEIGHT = 22
local PAGE_BUTTON = 32

-- SPELLBOOK_FONT_COLOR on Forever 1.60.1 (as Wayscribe found it), for a client without the global.
local INK = { 0.18, 0.106, 0.059 }
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local PAGE_ART = "Interface\\Buttons\\UI-SpellbookIcon-%sPage-%s"

local list, rows, tabs, search, pageText, previous, nextPage, empty, actions
local shown = { kind = "spell", query = "", page = 1, entries = {} }

-- Ink on paper: dark brown, a little lighter when faded, without the font's shadow (it blurs dark
-- text on paper).
function Picker.Ink(text, faded)
    local color = SPELLBOOK_FONT_COLOR
    local r, g, b = INK[1], INK[2], INK[3]
    if type(color) == "table" and color.GetRGB then r, g, b = color:GetRGB() end
    text:SetTextColor(r, g, b, faded and 0.75 or 1)
    text:SetShadowOffset(0, 0)
end

-- Sets the first of the atlases this client has; false if it has none.
function Picker.Atlas(texture, ...)
    for index = 1, select("#", ...) do
        local name = select(index, ...)
        if C_Texture.GetAtlasInfo(name) then
            texture:SetAtlas(name)
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------------------------------
-- Showing the list
---------------------------------------------------------------------------------------------------

local function perPage() return Picker.COLUMNS * Picker.ROWS end

local function pages() return math.max(1, math.ceil(#shown.entries / perPage())) end

-- Draws the shown page, with a check mark on what's on the ring already.
function Picker.Draw()
    if not list then return end
    shown.page = math.max(1, math.min(shown.page, pages()))
    local first = (shown.page - 1) * perPage()
    for index, row in ipairs(rows) do
        local entry = shown.entries[first + index]
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            row.icon:SetTexture(Entries.Icon(entry))
            row.name:SetText(Entries.Name(entry) or "")
            local subtext = Entries.Subtext(entry)
            row.subtext:SetText(subtext or "")
            -- One line in the middle, or two around it.
            local y = subtext and 7 or 0
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, y)
            row.name:SetPoint("RIGHT", row, "RIGHT", -4, y)
            row.check:SetShown(actions.has(entry))
        end
    end
    pageText:SetText(L.RING_PAGE:format(shown.page, pages()))
    previous:SetEnabled(shown.page > 1)
    nextPage:SetEnabled(shown.page < pages())
    local none = shown.kind == "toy" and L.RING_LIST_EMPTY_TOYS or L.RING_LIST_EMPTY
    empty:SetText(#shown.entries > 0 and "" or (shown.query ~= "" and L.RING_LIST_NO_MATCH or none))
end

-- Reads again what this character has of the shown kind, through the search.
function Picker.Fill()
    if not list then return end
    local query = strtrim(shown.query):lower()
    shown.entries = {}
    for _, entry in ipairs(Entries.Owned(shown.kind)) do
        if query == "" or (Entries.Name(entry) or ""):lower():find(query, 1, true) then
            shown.entries[#shown.entries + 1] = entry
        end
    end
    Picker.Draw()
end

local function turn(step)
    shown.page = shown.page + step
    Picker.Draw()
end

local function selectTab(kind)
    for _, tab in ipairs(tabs) do tab:SetTabSelected(tab.kind == kind) end
end

-- Shows a kind's tab, from its first page.
local function showKind(kind)
    shown.kind, shown.page = kind, 1
    selectTab(kind)
    Picker.Fill()
end

---------------------------------------------------------------------------------------------------
-- Building it
---------------------------------------------------------------------------------------------------

local function onRowEnter(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    Entries.Tooltip(GameTooltip, row.entry)
    GameTooltip:AddLine(actions.has(row.entry) and L.RING_LIST_REMOVE or L.RING_LIST_ADD, 0, 1, 0, true)
    GameTooltip:Show()
end

local function onRowLeave(row)
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function newRow(index)
    local row = CreateFrame("Button", nil, list)
    row:SetSize(math.floor(list:GetWidth() / Picker.COLUMNS), Picker.ROW_HEIGHT)
    -- Down the first column, then the second, like the spell book.
    local column, line = math.floor((index - 1) / Picker.ROWS), (index - 1) % Picker.ROWS
    row:SetPoint("TOPLEFT", list, "TOPLEFT", column * row:GetWidth(), -line * Picker.ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnClick", function() actions.toggle(row.entry) end)
    row:SetScript("OnDragStart", function()
        if not InCombatLockdown() then Entries.Pickup(row.entry) end
    end)
    row:SetScript("OnEnter", onRowEnter)
    row:SetScript("OnLeave", onRowLeave)

    -- The spell book's entry: the icon in its bronze frame (room on the left for the frame's leaves),
    -- the name in ink, and a soft light behind it while pointed at.
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", 14, 0)
    local mask = row:CreateMaskTexture()
    if Picker.Atlas(mask, "spellbook-item-spellicon-mask") then
        mask:SetAllPoints(row.icon)
        row.icon:AddMaskTexture(mask)
    end
    local frame = row:CreateTexture(nil, "OVERLAY")
    frame:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -13, 3)
    frame:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 3, -9)
    Picker.Atlas(frame, "spellbook-item-iconframe-c60", "spellbook-item-iconframe")
    local glow = row:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(frame)
    if Picker.Atlas(glow, "spellbook-item-iconframe-hover") then
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0.35)
    end
    local backplate = row:CreateTexture(nil, "HIGHLIGHT", nil, -1)
    backplate:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 0, 2)
    backplate:SetPoint("BOTTOMRIGHT", 0, 2)
    Picker.Atlas(backplate, "spellbook-item-backplate")
    row.check = row:CreateTexture(nil, "OVERLAY", nil, 1)
    row.check:SetSize(22, 22)
    row.check:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 7, -6)
    row.check:SetTexture(CHECK)

    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    Picker.Ink(row.name)
    row.subtext = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.subtext:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.subtext:SetPoint("TOPRIGHT", row.name, "BOTTOMRIGHT", 0, -3)
    row.subtext:SetJustifyH("LEFT")
    row.subtext:SetWordWrap(false)
    Picker.Ink(row.subtext, true)
    return row
end

-- The spell book's page button ("Prev" or "Next"), also the editor's for its rings.
function Picker.PageButton(parent, direction, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(PAGE_BUTTON, PAGE_BUTTON)
    button:SetNormalTexture(PAGE_ART:format(direction, "Up"))
    button:SetPushedTexture(PAGE_ART:format(direction, "Down"))
    button:SetDisabledTexture(PAGE_ART:format(direction, "Disabled"))
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    button:SetScript("OnClick", onClick)
    return button
end

-- The tabs are the game's (TabSystemTopButtonTemplate, as the spell book's), standing on the
-- parchment's top edge, rise above the column's top: from its left edge, or ending at its right one
-- when they're wider. A strip of ours stands in for the game's tab system: a tab calls its parent's
-- SetTab when clicked.
local function newTabs(column, rise)
    local strip = CreateFrame("Frame", nil, column)
    strip:SetAllPoints()
    function strip:GetTabWidthConstraints() return nil, nil end
    function strip:PlayTabSelectSound()
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
    end
    function strip:SetTab(id) showKind(KINDS[id]) end
    tabs = {}
    local width = -1
    for index, kind in ipairs(KINDS) do
        local tab = CreateFrame("Button", nil, strip, "TabSystemTopButtonTemplate")
        tab.kind = kind
        tab:Init(index, LABELS[kind])
        if index > 1 then tab:SetPoint("BOTTOMLEFT", tabs[index - 1], "BOTTOMRIGHT", 1, 0) end
        width = width + tab:GetWidth() + 1
        tabs[index] = tab
    end
    tabs[1]:SetPoint("BOTTOMLEFT", column, "TOPLEFT", math.min(0, column:GetWidth() - width), rise)
end

-- Builds the list into column (a frame on the parchment, its size set), with its tabs on the
-- parchment's top edge, rise above the column. handlers: has(entry), whether it's on the ring;
-- toggle(entry), put it on or take it off.
function Picker.Create(column, rise, handlers)
    actions = handlers
    search = CreateFrame("EditBox", nil, column, "SearchBoxTemplate")
    search:SetPoint("TOPLEFT", 6, 0)
    search:SetPoint("TOPRIGHT", 0, 0)
    search:SetHeight(SEARCH_HEIGHT)
    search:SetAutoFocus(false)
    search:HookScript("OnTextChanged", function(box)
        shown.query, shown.page = box:GetText() or "", 1
        Picker.Fill()
    end)

    list = CreateFrame("Frame", nil, column)
    list:SetPoint("TOPLEFT", 0, -(SEARCH_HEIGHT + 8))
    list:SetSize(column:GetWidth(), Picker.ROWS * Picker.ROW_HEIGHT)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) turn(delta > 0 and -1 or 1) end)
    rows = {}
    for index = 1, perPage() do rows[index] = newRow(index) end
    empty = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    empty:SetPoint("TOP", 0, -24)
    Picker.Ink(empty, true)

    -- "Page 2/3" and the page buttons at the bottom right, as in the spell book.
    nextPage = Picker.PageButton(column, "Next", function() turn(1) end)
    nextPage:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", 0, 0)
    previous = Picker.PageButton(column, "Prev", function() turn(-1) end)
    previous:SetPoint("RIGHT", nextPage, "LEFT", -4, 0)
    pageText = column:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pageText:SetPoint("RIGHT", previous, "LEFT", -8, 0)
    Picker.Ink(pageText)

    -- Filled when the Ring page is shown.
    newTabs(column, rise)
    selectTab(shown.kind)
    column.search, column.rows, column.tabs, column.empty = search, rows, tabs, empty
    column.previous, column.next, column.page = previous, nextPage, pageText
end

-- The Ring page was left: no more typing into the search box.
function Picker.Hide()
    if search then search:ClearFocus() end
end
