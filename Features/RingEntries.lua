local _, ns = ...

-- What a ring holds: spells, items, toys, mounts and macros, each saved as { kind = ..., id = ... }
-- (a spell, item, toy or mount ID, a macro's name). The rings are the same on every character, and
-- each character's ring shows only the entries it can use (Known): spells it knows, items in its
-- bags or worn, toys and mounts it has, macros by that name.
--
-- Action turns an entry into what the ring's secure button does with it: type "spell" (a mount by
-- its spell), "item", "toy" or "macro". The rest draws an entry on a slot (icon, usability, count,
-- cooldown), names it and shows its tooltip. Drawing runs in combat too: values the game may hand
-- out as secrets only go to widgets, or through ns.IsUsable first. Owned lists what this character
-- has of a kind, for the editor's list (out of combat).
local Entries = {}
ns.RingEntries = Entries

-- A value safe to test, or false.
local function plain(value)
    return ns.IsUsable(value) and value
end

local function setUsable(button, usable, noMana)
    if plain(usable) then
        button.icon:SetVertexColor(1, 1, 1)
    elseif plain(noMana) then
        button.icon:SetVertexColor(0.5, 0.5, 1)
    else
        button.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

local function showSpell(button, id)
    setUsable(button, C_Spell.IsSpellUsable(id))
    -- A count for spells that use up something or have charges, as the action buttons show it.
    if plain(C_Spell.IsConsumableSpell(id)) or plain(C_Spell.GetSpellCharges(id)) then
        button.count:SetText(C_Spell.GetSpellDisplayCount(id, 9999))
    else
        button.count:SetText("")
    end
    local duration = C_Spell.GetSpellCooldownDuration(id)
    if duration then
        button.cooldown:SetCooldownFromDurationObject(duration)
    else
        button.cooldown:Clear()
    end
end

local function itemCooldown(button, id)
    local start, duration = C_Item.GetItemCooldown(id)
    button.cooldown:SetCooldown(start, duration)
end

local function showItem(button, id)
    setUsable(button, C_Item.IsUsableItem(id))
    if plain(C_Item.IsConsumableItem(id)) or (plain(C_Item.GetItemMaxStackSizeByID(id)) or 1) > 1 then
        button.count:SetText(C_Item.GetItemCount(id, false, true))
    else
        button.count:SetText("")
    end
    itemCooldown(button, id)
end

-- name, spell, icon, usable and whether this character has it, or nil for an unknown mount.
local function mount(id)
    local journal = C_MountJournal
    if not (journal and journal.GetMountInfoByID) then return nil end
    local name, spellID, icon, _, usable, _, _, _, _, hidden, collected = journal.GetMountInfoByID(id)
    if not name then return nil end
    return { name = name, spellID = spellID, icon = icon, usable = usable, known = collected and not hidden }
end

-- A toy's name and icon from the toy box, which knows them even when the item isn't loaded yet.
local function toyInfo(id)
    local box = C_ToyBox
    if box and box.GetToyInfo then
        local _, name, icon = box.GetToyInfo(id)
        return name, icon
    end
end

-- The macro's index on this character, or nil.
local function macro(name)
    local index = GetMacroIndexByName(name)
    if index and index > 0 then return index end
end

local KINDS = {
    spell = {
        known = function(id) return C_SpellBook.IsSpellKnownOrInSpellBook(id) end,
        action = function(id) return "spell", id end,
        icon = function(id) return C_Spell.GetSpellTexture(id) end,
        name = function(id) return C_Spell.GetSpellName(id) end,
        show = showSpell,
        tooltip = function(tooltip, id) tooltip:SetSpellByID(id) end,
        pickup = function(id) C_Spell.PickupSpell(id) end,
        -- The line under its name in the spell book (a rank, "Racial"), or "".
        subtext = function(id) return C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id) end,
    },
    item = {
        known = function(id) return C_Item.GetItemCount(id) > 0 or C_Item.IsEquippedItem(id) end,
        action = function(id) return "item", "item:" .. id end,
        icon = function(id) return C_Item.GetItemIconByID(id) end,
        name = function(id) return C_Item.GetItemNameByID(id) end,
        show = showItem,
        tooltip = function(tooltip, id) tooltip:SetItemByID(id) end,
        pickup = function(id) C_Item.PickupItem(id) end,
    },
    toy = {
        known = function(id) return PlayerHasToy ~= nil and PlayerHasToy(id) end,
        action = function(id) return "toy", id end,
        icon = function(id) return select(2, toyInfo(id)) or C_Item.GetItemIconByID(id) end,
        name = function(id) return toyInfo(id) or C_Item.GetItemNameByID(id) end,
        show = function(button, id)
            -- Not in Blizzard's API documentation; a client without it shows every toy as usable.
            setUsable(button, not C_ToyBox.IsToyUsable or C_ToyBox.IsToyUsable(id))
            button.count:SetText("")
            itemCooldown(button, id)
        end,
        tooltip = function(tooltip, id)
            if tooltip.SetToyByItemID then tooltip:SetToyByItemID(id) else tooltip:SetItemByID(id) end
        end,
        pickup = function(id) C_ToyBox.PickupToyBoxItem(id) end,
    },
    -- A mount is summoned by its spell. It can't be put on the cursor by its ID, only by its place
    -- in the mount journal's list; its spell may go there instead (FromCursor makes it a mount
    -- again), else taking it off the ring just removes it.
    mount = {
        known = function(id)
            local info = mount(id)
            return info ~= nil and info.known
        end,
        action = function(id) return "spell", mount(id).spellID end,
        icon = function(id) return (mount(id) or {}).icon end,
        name = function(id) return (mount(id) or {}).name end,
        show = function(button, id)
            local info = mount(id)
            setUsable(button, info and info.usable)
            button.count:SetText("")
            local duration = info and C_Spell.GetSpellCooldownDuration(info.spellID)
            if duration then
                button.cooldown:SetCooldownFromDurationObject(duration)
            else
                button.cooldown:Clear()
            end
        end,
        tooltip = function(tooltip, id)
            local info = mount(id)
            if not info then return end
            if tooltip.SetMountBySpellID then
                tooltip:SetMountBySpellID(info.spellID)
            else
                tooltip:SetSpellByID(info.spellID)
            end
        end,
        pickup = function(id)
            local info = mount(id)
            if info then C_Spell.PickupSpell(info.spellID) end
        end,
    },
    -- A macro looks like the spell or item it uses (#showtooltip), else just its icon.
    macro = {
        known = function(name) return macro(name) ~= nil end,
        action = function(name) return "macro", name end,
        icon = function(name)
            local index = macro(name)
            return index and select(2, GetMacroInfo(index))
        end,
        name = function(name) return name end,
        show = function(button, name)
            local index = macro(name)
            local spell = index and GetMacroSpell(index)
            local item = index and not spell and select(2, GetMacroItem(index))
            local itemID = item and C_Item.GetItemInfoInstant(item)
            if spell then
                showSpell(button, spell)
            elseif itemID then
                showItem(button, itemID)
            else
                setUsable(button, true)
                button.count:SetText("")
                button.cooldown:Clear()
            end
        end,
        tooltip = function(tooltip, name) tooltip:SetText(name) end,
        pickup = function(name) PickupMacro(name) end,
    },
}

local function kind(entry)
    return type(entry) == "table" and KINDS[entry.kind]
end

-- Whether this character can use the entry (out of combat: items and toys are counted).
function Entries.Known(entry)
    local info = kind(entry)
    return info and entry.id ~= nil and info.known(entry.id) == true or false
end

-- The secure action: type, and the value of the attribute named like the type.
function Entries.Action(entry)
    return kind(entry).action(entry.id)
end

function Entries.Name(entry)
    local info = kind(entry)
    return info and info.name(entry.id)
end

function Entries.Icon(entry)
    local info = kind(entry)
    return info and info.icon(entry.id)
end

-- A spell's line under its name, or nil.
function Entries.Subtext(entry)
    local info = kind(entry)
    local text = info and info.subtext and info.subtext(entry.id)
    return text ~= "" and text or nil
end

function Entries.Same(a, b)
    return a.kind == b.kind and a.id == b.id
end

-- Draws an entry on a button's icon, count and cooldown regions, or clears them for nil.
function Entries.Refresh(button, entry)
    local info = kind(entry)
    if not info then
        button.icon:Hide()
        button.count:SetText("")
        button.cooldown:Clear()
        return
    end
    button.icon:SetTexture(info.icon(entry.id))
    button.icon:Show()
    info.show(button, entry.id)
end

function Entries.Tooltip(tooltip, entry)
    kind(entry).tooltip(tooltip, entry.id)
end

-- Puts the entry on the cursor, as far as the game lets us.
function Entries.Pickup(entry)
    kind(entry).pickup(entry.id)
end

-- A spell as an entry: a mount's spell is the mount.
function Entries.FromSpell(id)
    local journal = C_MountJournal
    local mountID = journal and journal.GetMountFromSpell and journal.GetMountFromSpell(id)
    if mountID then return { kind = "mount", id = mountID } end
    return { kind = "spell", id = id }
end

-- What's on the cursor as an entry, or nil for anything a ring can't hold (battle pets, equipment
-- sets, flyouts, money...).
function Entries.FromCursor()
    local cursorType, info1, _, spellID, baseSpellID = GetCursorInfo()
    if cursorType == "spell" then
        local id = baseSpellID or spellID
        return id and Entries.FromSpell(id)
    elseif cursorType == "item" then
        if PlayerHasToy and PlayerHasToy(info1) then return { kind = "toy", id = info1 } end
        return { kind = "item", id = info1 }
    elseif cursorType == "mount" then
        return { kind = "mount", id = info1 }
    elseif cursorType == "macro" then
        local name = GetMacroInfo(info1)
        return name and { kind = "macro", id = name }
    end
    return nil
end

---------------------------------------------------------------------------------------------------
-- What this character has
---------------------------------------------------------------------------------------------------

-- A list of entries that takes each one once.
local function collector()
    local list, seen = {}, {}
    return list, function(entry)
        local key = entry.kind .. ":" .. tostring(entry.id)
        if seen[key] then return end
        seen[key] = true
        list[#list + 1] = entry
    end
end

-- The spell book's spells in its order, a flyout's known spells in its place (a mage's portals);
-- passives and other specializations' spells left out.
local function spellBook()
    local list, add = collector()
    local book = C_SpellBook
    if not (book and book.GetNumSpellBookSkillLines) then return list end
    local bank, types = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType
    for line = 1, book.GetNumSpellBookSkillLines() do
        local info = book.GetSpellBookSkillLineInfo(line)
        if info and not info.shouldHide then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = book.GetSpellBookItemInfo(slot, bank)
                if item and item.itemType == types.Spell and not item.isPassive and not item.isOffSpec then
                    add(Entries.FromSpell(item.actionID))
                elseif item and item.itemType == types.Flyout then
                    local _, _, slots = GetFlyoutInfo(item.actionID)
                    for flyoutSlot = 1, slots or 0 do
                        local spellID, _, known = GetFlyoutSlotInfo(item.actionID, flyoutSlot)
                        if known then add(Entries.FromSpell(spellID)) end
                    end
                end
            end
        end
    end
    return list
end

-- Items with a use, in the bags or worn (equipment slots 1 to 19), toys left to the toy box.
local function items()
    local list, add = collector()
    local function addItem(id)
        if id and C_Item.GetItemSpell(id) and not (PlayerHasToy and PlayerHasToy(id)) then
            add({ kind = "item", id = id })
        end
    end
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            addItem(info and info.itemID)
        end
    end
    for slot = 1, 19 do addItem(GetInventoryItemID("player", slot)) end
    return list
end

-- The toys this character has, as far as the toy box's own filter shows them (its search box
-- too): it lists toys only through that filter, and changing it would change the Toy Box.
local function toys()
    local list, add = collector()
    local box = C_ToyBox
    if not (box and box.GetNumFilteredToys) then return list end
    for index = 1, box.GetNumFilteredToys() do
        local id = box.GetToyFromIndex(index)
        if id and id > 0 and PlayerHasToy(id) then add({ kind = "toy", id = id }) end
    end
    return list
end

local function mounts()
    local list, add = collector()
    local journal = C_MountJournal
    if not (journal and journal.GetMountIDs) then return list end
    for _, id in ipairs(journal.GetMountIDs()) do
        local info = mount(id)
        if info and info.known then add({ kind = "mount", id = id }) end
    end
    return list
end

-- The account's macros, then this character's, as the macro window lists them.
local function macros()
    local list, add = collector()
    local account, character = GetNumMacros()
    local first = MAX_ACCOUNT_MACROS or 120
    local function addMacro(index)
        local name = GetMacroInfo(index)
        if name then add({ kind = "macro", id = name }) end
    end
    for index = 1, account or 0 do addMacro(index) end
    for index = first + 1, first + (character or 0) do addMacro(index) end
    return list
end

local function byName(list)
    table.sort(list, function(a, b)
        return (Entries.Name(a) or ""):lower() < (Entries.Name(b) or ""):lower()
    end)
    return list
end

local OWNED = {
    spell = spellBook,
    item = function() return byName(items()) end,
    toy = function() return byName(toys()) end,
    mount = function() return byName(mounts()) end,
    macro = macros,
}

-- What this character has of a kind ("spell", "item", "toy", "mount" or "macro"), as entries:
-- spells in the spell book's order, macros in the macro window's, the rest by name.
function Entries.Owned(kindName)
    return OWNED[kindName]()
end
