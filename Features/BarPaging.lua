local _, ns = ...
local Options = ns.Options

-- Turns off the keys that switch the main action bar to another page (Shift+1 to Shift+6 unless the
-- player bound them elsewhere). Each such key gets an override binding of ours that does what the
-- key does without its modifiers, the way the game treats a modified key with no binding of its
-- own: Shift+1 presses action button 1 with Shift held, so a macro can check for Shift. A key with
-- nothing to fall back to does nothing.
--
-- Override bindings belong to our own frame and are cleared when the option goes off; the saved
-- key bindings are never changed. Bindings can't change in combat, so changes wait for its end.
local BarPaging = {}
ns.BarPaging = BarPaging

local KEY = "disableBarPaging"
local PAGES = 6
local MODIFIERS = { "ALT", "CTRL", "SHIFT", "META" }
-- A button of ours without an action, for a key with nothing to fall back to.
local NOTHING = "QoLNoAction"

-- "SHIFT-1" -> "1", "CTRL-SHIFT-F" -> "F"; nil for a key without modifiers.
function BarPaging.Unmodified(key)
    local base, stripped = key, false
    local found
    repeat
        found = false
        for _, modifier in ipairs(MODIFIERS) do
            local rest = base:match("^" .. modifier .. "%-(.+)$")
            if rest then
                base, found, stripped = rest, true, true
            end
        end
    until not found
    return stripped and base or nil
end

-- What each paging key does instead: the binding command of the key without modifiers (with
-- another addon's override, a bar addon's for one), or false for nothing.
function BarPaging.Overrides()
    local overrides = {}
    for page = 1, PAGES do
        for _, key in ipairs({ GetBindingKey("ACTIONPAGE" .. page) }) do
            local base = BarPaging.Unmodified(key)
            local action = base and GetBindingAction(base, true)
            local usable = type(action) == "string" and action ~= "" and not action:find("^ACTIONPAGE")
            overrides[key] = usable and action or false
        end
    end
    return overrides
end

local function same(a, b)
    for key, value in pairs(a) do
        if b[key] ~= value then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local owner
-- The overrides in place, as Overrides() returned them.
local applied = {}

function BarPaging:Update()
    local wanted = Options:Get(KEY) and self.Overrides() or {}
    if same(wanted, applied) then return end
    owner = owner or CreateFrame("Frame")
    ClearOverrideBindings(owner)
    for key, action in pairs(wanted) do
        if action then
            SetOverrideBinding(owner, false, key, action)
        else
            if not _G[NOTHING] then CreateFrame("Button", NOTHING) end
            SetOverrideBindingClick(owner, false, key, NOTHING)
        end
    end
    applied = wanted
end

local function schedule()
    ns.Later("barPaging", function() BarPaging:Update() end)
end

function BarPaging:Init()
    Options:Watch({ KEY }, schedule)
    -- The player changed a binding, or another addon its overrides (setting ours fires this too;
    -- Update then finds nothing to change).
    ns.Events:On("UPDATE_BINDINGS", function()
        if Options:Get(KEY) or next(applied) ~= nil then schedule() end
    end)
    if Options:Get(KEY) then schedule() end
end
