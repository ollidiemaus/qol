local _, ns = ...
local Options = ns.Options

-- Runs the game's sort each time the player opens their bags themselves. Every bag frame announces
-- itself through EventRegistry, the combined bag too, so one callback covers keyboard and mouse, the
-- controller interface and separate bags. The game's own opens announce themselves the same way, and
-- items moving then can make a click hit the wrong item, so hooks mark those: the game goes through
-- two global functions, the player's opens through Blizzard's local ones. The sort waits for the next
-- drawn frame, which puts it after a hook in the same call stack. It's ns.Later's form that also runs
-- in combat: the plain one would catch up when combat ends, and ns.LaterOutsideWindows would wait
-- for the bag itself to close.
local SortOnOpen = {}
ns.SortOnOpen = SortOnOpen

local KEY = "sortOnOpen"

-- The game opened the bags, or tried to, since the last run.
local openedByGame = false

local function run()
    local byGame = openedByGame
    openedByGame = false
    if byGame or not Options:Get(KEY) or InCombatLockdown() then return end
    C_Container.SortBags()
end

local function schedule()
    ns.Later("sortOnOpen", run, true)
end

-- The backpack and the bags carried count, not the keyring or the bank bags. The combined bag has
-- the backpack's ID.
local function onBagOpen(_, frame)
    local bag = frame:GetID()
    if ns.IsUsable(bag) and bag >= Enum.BagIndex.Backpack and bag <= NUM_TOTAL_BAG_FRAMES then schedule() end
end

-- Schedules a run too: with a bag already open OpenAllBags shows nothing, and the flag still has to go.
local function onGameOpen()
    openedByGame = true
    schedule()
end

-- Whether this client has the sort: Forever and retail, not Classic Era.
function SortOnOpen.IsAvailable()
    return C_Container ~= nil and C_Container.SortBags ~= nil
end

function SortOnOpen:Init()
    if not self.IsAvailable() then return end
    EventRegistry:RegisterCallback("ContainerFrame.OpenBag", onBagOpen, SortOnOpen)
    hooksecurefunc("OpenAllBags", onGameOpen)
    hooksecurefunc("OpenAllBagsMatchingContext", onGameOpen)
end
