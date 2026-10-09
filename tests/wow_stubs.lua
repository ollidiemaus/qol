-- Just enough of the WoW API to load the addon in plain Lua and drive it with events.
local Stubs = {}

-- A stand-in for a secret value: issecretvalue() is true only for this.
Stubs.SECRET = setmetatable({}, { __tostring = function() return "<SECRET>" end })

local state
Stubs.state = function() return state end

local function noop() end

-- Unknown widget methods do nothing, so UI code runs; methods whose results matter are real.
local function permissive(object)
    return setmetatable(object, {
        __index = function(_, key)
            if type(key) == "string" and key:find("^%u") then return noop end
            return nil
        end,
    })
end

local function newRegion(kind, parent)
    local region = { kind = kind, parent = parent, shown = true, points = {}, width = 0, height = 0, events = {},
        scripts = {}, effectiveScale = 1 }
    function region:SetParent(newParent)
        if state.combat and self.protected then
            error("ADDON_ACTION_BLOCKED: SetParent on a protected frame in combat")
        end
        self.parent = newParent
    end
    function region:GetParent() return self.parent end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:SetShown(shown) self.shown = shown and true or false end
    function region:IsShown() return self.shown end
    function region:IsVisible()
        local node = self
        while node do
            if not node.shown then return false end
            node = node.parent
        end
        return true
    end
    function region:ClearAllPoints() self.points = {} end
    function region:SetPoint(point, relativeTo, relativePoint, x, y)
        if state.combat and self.protected then
            error("ADDON_ACTION_BLOCKED: SetPoint on a protected frame in combat")
        end
        self.points[#self.points + 1] = { point, relativeTo, relativePoint, x or 0, y or 0 }
    end
    function region:SetAllPoints(relativeTo)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0)
    end
    function region:GetNumPoints() return #self.points end
    function region:GetPoint(index)
        local p = self.points[index or 1]
        if not p then return nil end
        return p[1], p[2], p[3], p[4], p[5]
    end
    -- Where a point was set, by anchor point name.
    function region:PointFor(point)
        for _, p in ipairs(self.points) do
            if p[1] == point then return p end
        end
        return nil
    end
    function region:SetWidth(width) self.width = width end
    function region:SetHeight(height) self.height = height end
    function region:SetSize(width, height) self.width, self.height = width, height end
    function region:GetWidth() return self.width end
    function region:GetHeight() return self.height end
    function region:GetEffectiveScale() return self.effectiveScale end
    function region:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function region:IsProtected() return self.protected == true end
    function region:CreateTexture()
        local texture = newRegion("Texture", self)
        return texture
    end
    function region:RegisterEvent(event)
        if state.unknownEvents[event] then error("Attempt to register unknown event \"" .. event .. "\"") end
        self.events[event] = true
    end
    function region:SetScript(script, fn) self.scripts[script] = fn end
    state.regions[#state.regions + 1] = region
    return permissive(region)
end
Stubs.NewFrame = function(parent) return newRegion("Frame", parent) end

-- A fake tooltip: records lines, has an owner and the info it is being built from (getterName and
-- getterArgs, as the game's SetX methods record them).
function Stubs.NewTooltip(owner, info)
    local tooltip = { lines = {}, owner = owner, info = info }
    function tooltip:AddLine(text, r, g, b) self.lines[#self.lines + 1] = { left = text, color = { r, g, b } } end
    function tooltip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = { left = left, right = right } end
    function tooltip:GetOwner() return self.owner end
    function tooltip:GetProcessingTooltipInfo() return self.info end
    return tooltip
end

-- Builds a tooltip like the game's data processor: each data line (unless a line pre-call drops
-- it), then the post calls for the tooltip type. The game's sell price line reads
-- "Sell Price: <price>c (game)".
function Stubs.ShowTooltip(typeName, data, tooltip)
    tooltip = tooltip or Stubs.NewTooltip()
    tooltip.info = tooltip.info or {}
    tooltip.info.tooltipData = data
    data.type = _G.Enum.TooltipDataType[typeName]
    for _, line in ipairs(data.lines or {}) do
        local dropped = false
        for _, fn in ipairs(state.linePreCalls[line.type] or {}) do
            if fn(tooltip, line) then dropped = true end
        end
        if not dropped and line.type == _G.Enum.TooltipDataLineType.SellPrice then
            tooltip:AddLine("Sell Price: " .. line.price .. "c (game)")
        end
    end
    for _, fn in ipairs(state.postCalls[data.type] or {}) do
        fn(tooltip, data)
    end
    return tooltip
end

-- A tooltip for the item in a bag slot, the way GameTooltip:SetBagItem(bag, slot) records it.
function Stubs.BagTooltip(bag, slot, owner)
    return Stubs.NewTooltip(owner, { getterName = "GetBagItem", getterArgs = { n = 2, bag, slot } })
end

-- Action bars are read-only to the addon: any write to a bar field fails the test.
function Stubs.NewActionBar(fields, numContainers)
    local raw = {
        numRows = 1, isHorizontal = true, addButtonsToTop = true, addButtonsToRight = true,
        buttonPadding = 2, minButtonPadding = 2, oldGridSettings = {}, shownButtonContainers = {},
    }
    for key, value in pairs(fields or {}) do raw[key] = value end
    for i = 1, numContainers or 12 do
        raw.shownButtonContainers[i] = Stubs.NewFrame(nil)
    end
    return setmetatable({}, {
        __index = raw,
        __newindex = function(_, key) error("the addon wrote bar field " .. tostring(key)) end,
    }), raw
end

local function split(delimiter, text)
    local parts = {}
    for part in (text .. delimiter):gmatch("(.-)" .. delimiter:gsub("%p", "%%%0")) do
        parts[#parts + 1] = part
    end
    return (unpack or table.unpack)(parts)
end

local function install()
    local G = _G
    G.issecretvalue = function(value) return value == Stubs.SECRET end
    G.strsplit = split
    G.strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
    G.unpack = G.unpack or table.unpack
    G.GetLocale = function() return state.locale end
    G.GetMoneyString = function(copper) return tostring(copper) .. "c" end
    G.SELL_PRICE = "Sell Price"
    G.NUM_BAG_SLOTS = 4
    G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
    G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) state.messages[#state.messages + 1] = text end }

    G.CreateFrame = function(_, _, parent) return newRegion("Frame", parent) end
    G.UIParent = newRegion("Frame", nil)
    G.WorldFrame = newRegion("Frame", nil)
    G.WorldFrame.protected = true
    G.WorldFrame:SetAllPoints(nil)
    G.GetPhysicalScreenSize = function() return state.screenWidth, state.screenHeight end
    -- Cutscenes: shown while an in-engine cinematic or a movie plays.
    G.CinematicFrame = newRegion("Frame", nil)
    G.CinematicFrame:Hide()
    G.MovieFrame = newRegion("Frame", nil)
    G.MovieFrame:Hide()

    G.InCombatLockdown = function() return state.combat end
    G.ReloadUI = function() state.reloads = state.reloads + 1 end
    -- C_Timer.After(0) runs on the next RunTimers; a real delay waits for AdvanceTime.
    G.C_Timer = {
        After = function(seconds, fn)
            local queue = seconds > 0 and state.delayed or state.timers
            queue[#queue + 1] = fn
        end,
    }
    G.C_EventUtils = { IsEventValid = function(event) return not state.unknownEvents[event] end }
    G.EventRegistry = {
        RegisterCallback = function(_, event, fn, owner)
            state.registry[event] = state.registry[event] or {}
            table.insert(state.registry[event], { fn = fn, owner = owner })
        end,
    }

    G.Enum = {
        ItemQuality = { Poor = 0, Common = 1 },
        TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Currency = 5, UnitAura = 7, Achievement = 12, Toy = 19,
            Quest = 23 },
        TooltipDataLineType = { SellPrice = 11 },
    }
    G.TooltipDataProcessor = {
        AddTooltipPostCall = function(tooltipType, fn)
            state.postCalls[tooltipType] = state.postCalls[tooltipType] or {}
            table.insert(state.postCalls[tooltipType], fn)
        end,
        AddLinePreCall = function(lineType, fn)
            state.linePreCalls[lineType] = state.linePreCalls[lineType] or {}
            table.insert(state.linePreCalls[lineType], fn)
        end,
    }

    -- Bags and items
    G.C_Container = {
        GetContainerNumSlots = function(bag) return state.bags[bag] and state.bags[bag].size or 0 end,
        GetContainerItemInfo = function(bag, slot) return state.bags[bag] and state.bags[bag][slot] end,
        UseContainerItem = function(bag, slot) table.insert(state.used, bag .. ":" .. slot) end,
    }
    G.C_Item = {
        GetItemInfo = function(itemID)
            local price = state.prices[itemID]
            if price == nil then return nil end
            return "Item " .. itemID, nil, 0, 1, 1, "Junk", "Junk", 1, "", 0, price
        end,
    }

    -- Merchant
    G.C_MerchantFrame = {
        IsSellAllJunkEnabled = function() return state.sellAllEnabled end,
        SellAllJunkItems = function() state.soldAll = state.soldAll + 1 end,
    }
    G.CanMerchantRepair = function() return state.canRepair end
    G.GetRepairAllCost = function() return state.repairCost, state.repairCost > 0 end
    G.RepairAllItems = function(guild) table.insert(state.repairs, guild and "guild" or "own") end
    G.GetMoney = function() return state.money end
    G.IsInGuild = function() return state.inGuild end
    G.CanGuildBankRepair = function() return state.guildCanRepair end
    G.GetGuildBankWithdrawMoney = function() return state.guildLimit end
    G.GetGuildBankMoney = function() return state.guildMoney end

    -- Frames the addon hides
    G.MicroMenuContainer = newRegion("Frame", G.UIParent)
    G.BagsBar = newRegion("Frame", G.UIParent)
    G.QuickJoinToastButton = newRegion("Frame", G.UIParent)
    -- The combined bag starts closed; its sort button belongs to the backpack and starts hidden.
    G.ContainerFrameCombinedBags = newRegion("Frame", G.UIParent)
    G.ContainerFrameCombinedBags:Hide()
    G.ContainerFrameCombinedBags.hooks = {}
    function G.ContainerFrameCombinedBags:HookScript(script, fn) self.hooks[script] = fn end
    G.ContainerFrame1 = newRegion("Frame", G.UIParent)
    G.BagItemAutoSortButton = newRegion("Frame", G.ContainerFrame1)
    G.BagItemAutoSortButton:Hide()
    local minimapContainer = newRegion("Frame", G.UIParent)
    minimapContainer.PlayerCoords = newRegion("Frame", minimapContainer)
    G.MinimapCluster = { MinimapContainer = minimapContainer }

    -- Action bar layout helpers: record what the addon asks for.
    G.GridLayoutUtil = {
        CreateStandardGridLayout = function(stride, xPadding, yPadding, xMultiplier, yMultiplier)
            return { kind = "standard", stride = stride, xPadding = xPadding, yPadding = yPadding,
                xMultiplier = xMultiplier, yMultiplier = yMultiplier }
        end,
        CreateVerticalGridLayout = function(stride, xPadding, yPadding, xMultiplier, yMultiplier)
            return { kind = "vertical", stride = stride, xPadding = xPadding, yPadding = yPadding,
                xMultiplier = xMultiplier, yMultiplier = yMultiplier }
        end,
        ApplyGridLayout = function(regions, anchor, layout)
            if state.combat then error("ADDON_ACTION_BLOCKED: button containers moved in combat") end
            table.insert(state.layouts, { regions = regions, anchor = anchor, layout = layout })
        end,
    }
    G.AnchorUtil = {
        CreateAnchor = function(point, relativeTo, relativePoint)
            return { point = point, relativeTo = relativeTo, relativePoint = relativePoint }
        end,
    }
end

-- Globals the addon or a test may leave behind.
local ADDON_GLOBALS = {
    "ForeverQoLDB", "SLASH_FOREVERQOL1", "SLASH_FOREVERQOL2", "SlashCmdList", "Settings",
    "CreateSettingsListSectionHeaderInitializer", "MinimalSliderWithSteppersMixin",
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar",
    "SLASH_FOREVERQOL_RELOAD1", "hash_SlashCmdList", "IsSecureCmd", "SLASH_OTHERADDON1", "SLASH_RELOAD1",
    "HUD_EDIT_MODE_ACTION_BAR_LABEL", "HUD_EDIT_MODE_STANCE_BAR_LABEL", "HUD_EDIT_MODE_PET_ACTION_BAR_LABEL",
}

function Stubs.Reset(options)
    options = options or {}
    state = {
        locale = options.locale or "enUS",
        regions = {}, timers = {}, delayed = {}, messages = {}, registry = {}, postCalls = {}, linePreCalls = {},
        unknownEvents = options.unknownEvents or {},
        combat = false,
        screenWidth = 2560, screenHeight = 1440,
        bags = {}, prices = {}, used = {}, soldAll = 0, sellAllEnabled = true,
        canRepair = false, repairCost = 0, repairs = {}, money = 0,
        inGuild = false, guildCanRepair = false, guildLimit = 0, guildMoney = 0,
        layouts = {}, reloads = 0,
    }
    for _, name in ipairs(ADDON_GLOBALS) do _G[name] = nil end
    _G.SlashCmdList = {}
    install()
end

local function tocFiles()
    local files = {}
    for rawLine in io.lines("ForeverQoL.toc") do
        local line = rawLine:gsub("\r", "")
        if line ~= "" and not line:find("^#") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return files
end

-- Loads every file the TOC lists, in order, into a fresh namespace.
function Stubs.LoadAddon(options)
    Stubs.Reset(options)
    local ns = {}
    for _, path in ipairs(tocFiles()) do
        local chunk = assert(loadfile(path))
        chunk("ForeverQoL", ns)
    end
    return ns
end

function Stubs.Fire(event, ...)
    for _, region in ipairs(state.regions) do
        if region.events[event] and region.scripts.OnEvent then
            region.scripts.OnEvent(region, event, ...)
        end
    end
end

function Stubs.TriggerRegistry(event, ...)
    for _, callback in ipairs(state.registry[event] or {}) do
        callback.fn(callback.owner, ...)
    end
end

-- Lets the delayed C_Timer callbacks come due, then runs everything that is due.
function Stubs.AdvanceTime()
    local delayed = state.delayed
    state.delayed = {}
    for _, fn in ipairs(delayed) do state.timers[#state.timers + 1] = fn end
    Stubs.RunTimers()
end

-- Runs C_Timer callbacks until none are left (callbacks may schedule more).
function Stubs.RunTimers()
    local guard = 0
    while #state.timers > 0 do
        local timers = state.timers
        state.timers = {}
        for _, fn in ipairs(timers) do fn() end
        guard = guard + 1
        assert(guard < 100, "timers keep scheduling timers")
    end
end

function Stubs.SetCombat(inCombat)
    state.combat = inCombat
    if not inCombat then
        Stubs.Fire("PLAYER_REGEN_ENABLED")
    end
end

-- Loads the saved variables, logs in and lets every deferred change run.
function Stubs.Login(savedOptions)
    _G.ForeverQoLDB = savedOptions and { options = savedOptions } or nil
    Stubs.Fire("ADDON_LOADED", "ForeverQoL")
    Stubs.Fire("PLAYER_LOGIN")
    Stubs.Fire("PLAYER_ENTERING_WORLD")
    Stubs.RunTimers()
end

-- The parts of the Settings API the panel uses, recording what was registered. Call before Login.
function Stubs.InstallSettings()
    local api = { settings = {}, controls = {}, categories = {}, headers = {} }

    local function newInitializer(setting, control, extra)
        local initializer = { setting = setting, control = control }
        for key, value in pairs(extra or {}) do initializer[key] = value end
        function initializer:SetParentInitializer(parent, predicate)
            self.parent, self.predicate = parent, predicate
        end
        api.controls[#api.controls + 1] = initializer
        if setting then setting.initializer = initializer end
        return initializer
    end

    local function newCategory(name, parent)
        local category = { name = name, parent = parent, id = #api.categories + 100, headers = {} }
        function category:GetID() return self.id end
        local layout = {
            AddInitializer = function(_, initializer)
                if initializer.header then category.headers[#category.headers + 1] = initializer.header end
            end,
        }
        api.categories[#api.categories + 1] = category
        return category, layout
    end

    _G.Settings = {
        VarType = { Boolean = "boolean", String = "string", Number = "number" },
        RegisterVerticalLayoutCategory = function(name) return newCategory(name) end,
        RegisterVerticalLayoutSubcategory = function(parent, name) return newCategory(name, parent) end,
        RegisterProxySetting = function(category, variable, varType, name, default, get, set)
            assert(api.settings[variable] == nil, "setting registered twice: " .. variable)
            local setting = { category = category, variable = variable, varType = varType, name = name,
                default = default, get = get, set = set }
            api.settings[variable] = setting
            return setting
        end,
        CreateCheckbox = function(_, setting, tooltip) return newInitializer(setting, "checkbox", { tooltip = tooltip }) end,
        CreateSlider = function(_, setting, options, tooltip)
            return newInitializer(setting, "slider", { options = options, tooltip = tooltip })
        end,
        CreateSliderOptions = function(minValue, maxValue, rate)
            local options = { minValue = minValue, maxValue = maxValue, rate = rate }
            function options:SetLabelFormatter(_, formatter) self.formatter = formatter end
            return options
        end,
        CreateColorSwatch = function(_, setting, tooltip) return newInitializer(setting, "color", { tooltip = tooltip }) end,
        RegisterAddOnCategory = function(category) api.registered = category end,
        OpenToCategory = function(id) api.opened = id end,
    }
    _G.CreateSettingsListSectionHeaderInitializer = function(text, tooltip) return { header = text, tooltip = tooltip } end
    _G.MinimalSliderWithSteppersMixin = { Label = { Right = 2 } }
    return api
end

-- The whole bag contents: items ={ { bag, slot, itemID, quality, count, price, hasNoValue } }.
function Stubs.SetBags(items)
    state.bags = {}
    for bag = 0, 5 do state.bags[bag] = { size = 16 } end
    for _, item in ipairs(items) do
        state.bags[item.bag][item.slot] = {
            itemID = item.itemID, quality = item.quality, stackCount = item.count or 1,
            hasNoValue = item.hasNoValue or false, isLocked = item.isLocked or false,
        }
        state.prices[item.itemID] = item.price
    end
end

return Stubs
