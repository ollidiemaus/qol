local _, ns = ...

-- QoLDB's layout version and the migrations up to it. How they run is in docs/DEVELOPMENT.md,
-- "Saved data".
local SavedData = { VERSION = 4, MIGRATIONS = {} }
ns.SavedData = SavedData

-- 2: the zone text takes the minimap elements' shared positions, so its own "above" and "below"
-- become "top" and "bottom".
SavedData.MIGRATIONS[2] = function(db)
    local options = db.options
    if type(options) ~= "table" then return end
    local renamed = ({ above = "top", below = "bottom" })[options.minimapZoneText]
    if renamed then options.minimapZoneText = renamed end
end

-- 3: the coordinates and the calendar button are hidden through a Position like the other minimap
-- elements, so their checkboxes become that Position's "hidden".
SavedData.MIGRATIONS[3] = function(db)
    local options = db.options
    if type(options) ~= "table" then return end
    if options.hideMinimapCoords == true then options.minimapCoords = "hidden" end
    if options.hideMinimapCalendar == true then options.minimapCalendar = "hidden" end
    options.hideMinimapCoords, options.hideMinimapCalendar = nil, nil
end

-- 4: the back buttons have an action bar per controller bar. The one picked before is Top's, and
-- Left, Right and Bottom take the first free of Action Bars 8, 7, 6 and 5 that isn't Top's. Only
-- values that differ from the defaults (Top 8, Left 7, Right 6, Bottom 5, as then) are saved. A value
-- of another kind isn't QoL's to understand, so it stays.
SavedData.MIGRATIONS[4] = function(db)
    local options = db.options
    if type(options) ~= "table" then return end
    local top = options.controllerBackButtonsBar
    if type(top) ~= "number" then return end
    local order = { 8, 7, 6, 5 }
    local free = {}
    for _, bar in ipairs(order) do
        if bar ~= top then free[#free + 1] = bar end
    end
    options.controllerBackButtonsBar = nil
    if top ~= order[1] then options.controllerBackButtonsBarTop = top end
    for index, name in ipairs({ "Left", "Right", "Bottom" }) do
        local key = "controllerBackButtonsBar" .. name
        if options[key] == nil and free[index] ~= order[index + 1] then options[key] = free[index] end
    end
end

function SavedData:Migrate(db)
    local version = type(db.version) == "number" and db.version or 0
    if version > self.VERSION then return end
    for target = version + 1, self.VERSION do
        local migrate = self.MIGRATIONS[target]
        if migrate then
            local ok, err = pcall(migrate, db)
            if not ok then
                geterrorhandler()(err)
                return
            end
        end
        db.version = target
    end
end

-- A character's key in what QoL saves for each character: "name-realm" in lower case, one space
-- between Forever's name and surname, and the realm as GetNormalizedRealmName writes it (no spaces
-- or dashes), so "Bankalt", "bankalt" and "Bankalt-Your Realm" are the same character. A name
-- without a realm is on the player's realm.
function ns.CharacterKey(text)
    local name, realm = text:match("^([^%-]+)%-(.+)$")
    if not name then
        name, realm = text, GetNormalizedRealmName and GetNormalizedRealmName() or ""
    end
    name = strtrim(name):gsub("%s+", " ")
    return (name .. "-" .. realm:gsub("[%s%-]", "")):lower()
end

-- The player's key. On Forever every character has a surname and first names repeat: UnitName
-- gives the surname where retail gives the realm, and the full name is both with a space between
-- (NameUtil.FormatUnitNameForDisplay), as the mail's To takes it.
function ns.PlayerKey()
    local name, surname = UnitName("player")
    if not ns.IsUsable(name) then return nil end
    if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() and ns.IsUsable(surname) and surname ~= ""
        and not name:find(" ", 1, true) then
        name = name .. " " .. surname
    end
    return ns.CharacterKey(name)
end
