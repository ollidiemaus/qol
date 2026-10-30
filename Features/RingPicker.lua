local _, ns = ...
local L = ns.L
local Entries = ns.RingEntries

-- The list of what this character has, laid out like Forever's spell book: tabs for its kinds
-- (spells, items, toys, mounts and macros) in the page's dark top bar, a search box, and two
-- columns of entries on parchment, a page at a time, with the spell book's page buttons (the mouse
-- wheel turns pages too). The page that makes it says what a click does and what the check mark
-- means; on the Ring page a click puts an entry on the ring, or takes it off when it's already
-- there. Dragging one puts it on the cursor. Also the parchment's look, for the pages around it:
-- ink, and the spell book's fonts.
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

-- One list on a page: Picker.Create makes it.
local List = {}
List.__index = List

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

-- Forever's spell book page (a single one, the condensed spell book's): its dark top bar and the
-- parchment's rims, as shares of its size (measured from interface/spellbook of client 1.60.1).
-- Without it, retail's (below), then Classic Era's; without any, the same bar over plain parchment.
local PAGE = "spellbook-page-condensed-c60"
local BAR = 0.081
local RIMS = { top = 0.094, bottom = 0.026, left = 0.03, right = 0.026 }
local BAR_COLOR = { 0.11, 0.08, 0.05 }
local PAPER, PAPER_EDGE = { 0.94, 0.88, 0.74 }, { 0.78, 0.68, 0.50 }

-- Retail's spell book page, as its halved spell book draws it (Blizzard_SpellBookFrame.xml of
-- 12.1.5): a wooden top bar 54 high, a strip of the whole book's 1614 cut to the page's width, over
-- a page that starts 3 above the bar's bottom, and the page curl at rest in its bottom right corner
-- (the first of the flipbook's 8 frames, 4 × 2), 150 × 155 at 15 from the right and 6 from the
-- bottom of a page 807 × 805. Our page starts at Forever's parchment edge, where the tabs stand as
-- on retail's (the bar 3 taller), so the editors lie the same on both.
local RETAIL = {
    bar = "spellbook-background-evergreen-header", barWidth = 1614, overlap = 3,
    page = "spellbook-background-evergreen-right", pageWidth = 807, pageHeight = 805,
    curl = "spellbook-corner-flipbook-evergreen", curlWidth = 150, curlHeight = 155, curlRight = 15, curlBottom = 6,
}

-- Classic Era's own spell book panel (Interface\Spellbook\UI-SpellbookPanel-*, the pieces of build
-- 1.15.9.70576, 256 × 256 on the left), not the Cata spell book page it also ships but doesn't use.
-- In pixels of its left pieces, measured from the files: the dark stone strip under the title, right
-- of the portrait's circle (x 80-256, y 35-77 of TopLeft); the parchment inside the metal frame,
-- without the frame's red shade at its left (x 26-256), from y 77 of TopLeft down and on in BotLeft
-- to y 175, its ragged bottom edge included, the frame's line below it not.
local CLASSIC = {
    file = "Interface\\Spellbook\\UI-SpellbookPanel-%s", size = 256,
    strip = { left = 80, top = 35, bottom = 77 }, parchment = { left = 26, top = 77, bottom = 175 },
}

local function fill(parent, color, layer)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetColorTexture(color[1], color[2], color[3])
    return texture
end

-- Retail's page on page (art: its background texture), its bar's height in edges.bar; false on a
-- client without it.
local function retailPage(page, art, edges, width, height)
    if not (C_Texture.GetAtlasInfo(RETAIL.bar) and Picker.Atlas(art, RETAIL.page)) then return false end
    edges.bar = edges.top + RETAIL.overlap
    art:ClearAllPoints()
    art:SetPoint("TOPLEFT", 0, -edges.top)
    art:SetPoint("BOTTOMRIGHT")
    -- The bar's middle: its left end has the round cut the spell book's portrait sits in.
    local bar = page:CreateTexture(nil, "BACKGROUND", nil, 2)
    bar:SetAtlas(RETAIL.bar)
    local share = math.min(1, width / RETAIL.barWidth)
    bar:SetTexCoord((1 - share) / 2, (1 + share) / 2, 0, 1)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(edges.bar)
    local curl = page:CreateTexture(nil, "BACKGROUND", nil, 1)
    if Picker.Atlas(curl, RETAIL.curl) then
        local x, y = width / RETAIL.pageWidth, (height - edges.top) / RETAIL.pageHeight
        curl:SetTexCoord(0, 0.25, 0, 0.5)
        curl:SetSize(RETAIL.curlWidth * x, RETAIL.curlHeight * y)
        curl:SetPoint("BOTTOMRIGHT", -RETAIL.curlRight * x, RETAIL.curlBottom * y)
    end
    return true
end

-- Sets a crop of a piece of Classic Era's panel on texture (a new one on page without it).
local function classicTexture(page, texture, piece, left, top, right, bottom)
    texture = texture or page:CreateTexture(nil, "BACKGROUND")
    local size = CLASSIC.size
    texture:SetTexture(CLASSIC.file:format(piece))
    texture:SetTexCoord(left / size, right / size, top / size, bottom / size)
    return texture
end

-- Classic Era's panel on page (art: the parchment's top), its stone strip down to the parchment's
-- top edge, where the tabs stand, the parchment filling the rest; false on a client without its
-- files. No metal frame, no portrait.
local function classicPage(page, art, edges, height)
    local function has(piece) return GetFileIDFromPath(CLASSIC.file:format(piece)) end
    if not (GetFileIDFromPath and has("TopLeft") and has("BotLeft")) then return false end
    local size, strip, parchment = CLASSIC.size, CLASSIC.strip, CLASSIC.parchment
    edges.bar = edges.top
    local bar = classicTexture(page, nil, "TopLeft", strip.left, strip.top, size, strip.bottom)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(edges.bar)
    -- The two pieces share the parchment by their pixels in the files.
    local topRows = size - parchment.top
    local topHeight = (height - edges.top) * topRows / (topRows + parchment.bottom)
    local upper = classicTexture(page, art, "TopLeft", parchment.left, parchment.top, size, size)
    upper:ClearAllPoints()
    upper:SetPoint("TOPLEFT", 0, -edges.top)
    upper:SetPoint("TOPRIGHT", 0, -edges.top)
    upper:SetHeight(topHeight)
    local lower = classicTexture(page, nil, "BotLeft", parchment.left, 0, size, parchment.bottom)
    lower:SetPoint("BOTTOMLEFT")
    lower:SetPoint("BOTTOMRIGHT")
    lower:SetHeight(height - edges.top - topHeight)
    return true
end

-- The spell book page a page's editor stands on, on the settings page below its title (top down
-- from its top), width × height. Returns it and where its parchment lies, in pixels from its edges
-- (bar: the top bar's height).
function Picker.NewPage(name, parent, top, width, height)
    local page = CreateFrame("Frame", name, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -top)
    page:SetSize(width, height)
    local edges = {
        bar = math.floor(height * BAR + 0.5),
        top = math.floor(height * RIMS.top + 0.5), bottom = math.floor(height * RIMS.bottom + 0.5),
        left = math.floor(width * RIMS.left + 0.5), right = math.floor(width * RIMS.right + 0.5),
    }
    local art = page:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    if not (Picker.Atlas(art, PAGE) or retailPage(page, art, edges, width, height)
            or classicPage(page, art, edges, height)) then
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

---------------------------------------------------------------------------------------------------
-- Showing the list
---------------------------------------------------------------------------------------------------

local function perPage() return Picker.COLUMNS * Picker.ROWS end

local function pages(shown) return math.max(1, math.ceil(#shown.entries / perPage())) end

-- Draws the shown page, with a check mark on what the page has already.
function List:Draw()
    local shown = self.shown
    shown.page = math.max(1, math.min(shown.page, pages(shown)))
    local first = (shown.page - 1) * perPage()
    for index, row in ipairs(self.rows) do
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
            row.check:SetShown(self.handlers.has(entry))
        end
    end
    self.pageText:SetText(L.RING_PAGE:format(shown.page, pages(shown)))
    self.previous:SetEnabled(shown.page > 1)
    self.nextPage:SetEnabled(shown.page < pages(shown))
    local none = shown.kind == "toy" and L.RING_LIST_EMPTY_TOYS or L.RING_LIST_EMPTY
    self.empty:SetText(#shown.entries > 0 and "" or (shown.query ~= "" and L.RING_LIST_NO_MATCH or none))
end

-- Reads again what this character has of the shown kind, through the search.
function List:Fill()
    local shown = self.shown
    local query = strtrim(shown.query):lower()
    shown.entries = {}
    for _, entry in ipairs(Entries.Owned(shown.kind)) do
        if query == "" or (Entries.Name(entry) or ""):lower():find(query, 1, true) then
            shown.entries[#shown.entries + 1] = entry
        end
    end
    self:Draw()
end

function List:Turn(step)
    self.shown.page = self.shown.page + step
    self:Draw()
end

function List:SelectTab(kind)
    for _, tab in ipairs(self.tabs) do tab:SetTabSelected(tab.kind == kind) end
end

-- Shows a kind's tab, from its first page.
function List:ShowKind(kind)
    self.shown.kind, self.shown.page = kind, 1
    self:SelectTab(kind)
    self:Fill()
end

-- The entry of the row under the mouse, or nil.
function List:EntryUnderMouse()
    for _, row in ipairs(self.rows) do
        if row.entry and row:IsVisible() and row:IsMouseOver() then return row.entry end
    end
    return nil
end

-- The page was left: no more typing into the search box.
function List:Hide()
    self.search:ClearFocus()
end

---------------------------------------------------------------------------------------------------
-- Building it
---------------------------------------------------------------------------------------------------

local function onRowEnter(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    Entries.Tooltip(GameTooltip, row.entry)
    local hint = row.list.handlers.hint(row.entry)
    if hint then GameTooltip:AddLine(hint, 0, 1, 0, true) end
    GameTooltip:Show()
end

local function onRowLeave(row)
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function newRow(self, index)
    local parent = self.frame
    local row = CreateFrame("Button", nil, parent)
    row.list = self
    row:SetSize(math.floor(parent:GetWidth() / Picker.COLUMNS), Picker.ROW_HEIGHT)
    -- Down the first column, then the second, like the spell book.
    local column, line = math.floor((index - 1) / Picker.ROWS), (index - 1) % Picker.ROWS
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", column * row:GetWidth(), -line * Picker.ROW_HEIGHT)
    row:RegisterForClicks(unpack(self.handlers.clicks))
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnClick", function(_, mouseButton) self.handlers.click(row.entry, mouseButton) end)
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

local function playTabSound()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
end

-- A tab of the game's tab system (TabSystemTopButtonTemplate, as the spell book's). A strip of
-- ours stands in for the tab system (newTabs): a tab calls its parent's SetTab when clicked.
local function newSystemTab(_, strip, index, kind)
    local tab = CreateFrame("Button", nil, strip, "TabSystemTopButtonTemplate")
    tab:Init(index, LABELS[kind])
    return tab
end

-- Classic Era has no tab system: there a top tab of its panel templates (PanelTopTabButtonTemplate,
-- its help window's), selected as the panel templates do it. Named, so the template's "$parent.."
-- art gets our prefix too.
local panelTabs = 0
local function newPanelTab(self, strip, _, kind)
    panelTabs = panelTabs + 1
    local tab = CreateFrame("Button", "QoLPickerTab" .. panelTabs, strip, "PanelTopTabButtonTemplate")
    tab:SetText(LABELS[kind])
    PanelTemplates_TabResize(tab, 10)
    tab.SetTabSelected = function(_, selected)
        if selected then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
    end
    tab:SetScript("OnClick", function()
        playTabSound()
        self:ShowKind(kind)
    end)
    return tab
end

-- The tabs stand on the parchment's top edge, rise above the column's top: from its left edge, or
-- ending at its right one when they're wider.
local function newTabs(self, column, rise)
    local strip = CreateFrame("Frame", nil, column)
    strip:SetAllPoints()
    strip.GetTabWidthConstraints = function() return nil, nil end
    strip.PlayTabSelectSound = playTabSound
    strip.SetTab = function(_, id) self:ShowKind(self.handlers.kinds[id]) end
    local newTab = C_XMLUtil.GetTemplateInfo("TabSystemTopButtonTemplate") and newSystemTab or newPanelTab
    local tabs = {}
    self.tabs = tabs
    local width = -1
    for index, kind in ipairs(self.handlers.kinds) do
        local tab = newTab(self, strip, index, kind)
        tab.kind = kind
        if index > 1 then tab:SetPoint("BOTTOMLEFT", tabs[index - 1], "BOTTOMRIGHT", 1, 0) end
        width = width + tab:GetWidth() + 1
        tabs[index] = tab
    end
    tabs[1]:SetPoint("BOTTOMLEFT", column, "TOPLEFT", math.min(0, column:GetWidth() - width), rise)
end

-- Builds a list into column (a frame on the parchment, its size set), with its tabs on the
-- parchment's top edge, rise above the column, and returns it. handlers: has(entry), whether the
-- page has it (the check mark); toggle(entry), what a left click does (the Ring page puts it on or
-- takes it off). A page can also give: kinds, the tabs (all by default); click(entry, mouseButton)
-- for the clicks it registers (clicks, the arguments of RegisterForClicks); hint(entry), the
-- tooltip's last line (nil for none); wheel(delta), true when it took the wheel (else it turns the
-- page).
function Picker.Create(column, rise, handlers)
    local self = setmetatable({ handlers = handlers, shown = { query = "", page = 1, entries = {} } }, List)
    -- Without the toy box (Classic Era), no toys tab.
    local kinds = {}
    for _, kind in ipairs(handlers.kinds or KINDS) do
        if kind ~= "toy" or C_ToyBox then kinds[#kinds + 1] = kind end
    end
    handlers.kinds = kinds
    handlers.clicks = handlers.clicks or { "LeftButtonUp" }
    handlers.click = handlers.click or function(entry) handlers.toggle(entry) end
    handlers.hint = handlers.hint or function(entry)
        return handlers.has(entry) and L.RING_LIST_REMOVE or L.RING_LIST_ADD
    end
    self.shown.kind = handlers.kinds[1]
    column.list = self
    local search = CreateFrame("EditBox", nil, column, "SearchBoxTemplate")
    self.search = search
    search:SetPoint("TOPLEFT", 6, 0)
    search:SetPoint("TOPRIGHT", 0, 0)
    search:SetHeight(SEARCH_HEIGHT)
    search:SetAutoFocus(false)
    search:HookScript("OnTextChanged", function(box)
        self.shown.query, self.shown.page = box:GetText() or "", 1
        self:Fill()
    end)

    local frame = CreateFrame("Frame", nil, column)
    self.frame = frame
    frame:SetPoint("TOPLEFT", 0, -(SEARCH_HEIGHT + 8))
    frame:SetSize(column:GetWidth(), Picker.ROWS * Picker.ROW_HEIGHT)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if not (handlers.wheel and handlers.wheel(delta)) then self:Turn(delta > 0 and -1 or 1) end
    end)
    self.rows = {}
    for index = 1, perPage() do self.rows[index] = newRow(self, index) end
    self.empty = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.empty:SetPoint("TOP", 0, -24)
    Picker.Ink(self.empty, true)

    -- "Page 2/3" and the page buttons at the bottom right, as in the spell book.
    self.nextPage = Picker.PageButton(column, "Next", function() self:Turn(1) end)
    self.nextPage:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", 0, 0)
    self.previous = Picker.PageButton(column, "Prev", function() self:Turn(-1) end)
    self.previous:SetPoint("RIGHT", self.nextPage, "LEFT", -4, 0)
    self.pageText = column:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.pageText:SetPoint("RIGHT", self.previous, "LEFT", -8, 0)
    Picker.Ink(self.pageText)

    -- Filled when the page is shown.
    newTabs(self, column, rise)
    self:SelectTab(self.shown.kind)
    column.search, column.rows, column.tabs, column.empty = search, self.rows, self.tabs, self.empty
    column.previous, column.next, column.page = self.previous, self.nextPage, self.pageText
    return self
end
