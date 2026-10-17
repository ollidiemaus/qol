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
