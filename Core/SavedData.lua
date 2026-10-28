local _, ns = ...

-- QoLDB's layout version and the migrations up to it. How they run is in docs/DEVELOPMENT.md,
-- "Saved data".
local SavedData = { VERSION = 1, MIGRATIONS = {} }
ns.SavedData = SavedData

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
