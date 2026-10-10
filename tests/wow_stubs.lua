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
    function region:SetScale(scale) self.scale = scale end
    function region:GetScale() return self.scale or 1 end
    function region:SetFrameLevel(level) self.frameLevel = level end
    function region:GetFrameLevel() return self.frameLevel or 1 end
    function region:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function region:SetAtlas(atlas) self.atlas = atlas end
    function region:SetTexture(texture) self.texture = texture end
    function region:SetMaskTexture(mask) self.mask = mask end
    function region:SetTextColor(r, g, b) self.textColor = { r, g, b } end
    function region:GetTextColor()
        local c = self.textColor or { 1, 1, 1 }
        return c[1], c[2], c[3], 1
    end
    function region:SetMouseClickEnabled(enabled) self.mouseClickEnabled = enabled end
    function region:SetJustifyH(justify) self.justifyH = justify end
    function region:GetJustifyH() return self.justifyH or "CENTER" end
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

-- A unit frame's health bar, read-only to the addon like action bars: its color and desaturation
-- change only through the widget methods, which work in combat too. It starts the way Blizzard
-- leaves these bars: white (the texture's own green shows) and not desaturated.
local function newHealthBar(unit)
    local raw = { unit = unit, color = { 1, 1, 1, 1 }, desaturated = false }
    function raw.SetStatusBarColor(_, r, g, b, a) raw.color = { r, g, b, a or 1 } end
    function raw.GetStatusBarColor() return raw.color[1], raw.color[2], raw.color[3], raw.color[4] end
    function raw.SetStatusBarDesaturated(_, desaturated) raw.desaturated = desaturated and true or false end
    function raw.IsStatusBarDesaturated() return raw.desaturated end
    return setmetatable({}, {
        __index = raw,
        __newindex = function(_, key) error("the addon wrote health bar field " .. tostring(key)) end,
    }), raw
end

-- The world map: its canvas (1000 x 667 at zoom 1), its data providers and the map it shows.
-- Blizzard_WorldMap creates it; a test can drop it to load the map later (Stubs.LoadWorldMap).
function Stubs.NewWorldMap()
    local map = newRegion("Frame", _G.UIParent)
    map:Hide()
    map.providers = {}
    map.canvas = newRegion("Frame", map)
    map.canvas:SetSize(1000, 667)
    map.canvasScale = 1
    function map:AddDataProvider(provider)
        table.insert(self.providers, provider)
        provider:OnAdded(self)
    end
    function map:GetCanvas() return self.canvas end
    function map:GetCanvasScale() return self.canvasScale end
    function map:GetMapID() return self.mapID end
    function map:SetMapID(mapID)
        if self.mapID == mapID then return end
        self.mapID = mapID
        for _, provider in ipairs(self.providers) do provider:OnMapChanged() end
    end
    function map:GetPinFrameLevelsManager()
        return { GetValidFrameLevel = function(_, name) return name == "PIN_FRAME_LEVEL_DUNGEON_ENTRANCE" and 500 or 2 end }
    end
    return map
end

-- Opens the world map at a map, the way the game refreshes every provider when it shows.
function Stubs.OpenWorldMap(mapID)
    local map = _G.WorldMapFrame
    map.mapID = mapID
    map:Show()
    for _, provider in ipairs(map.providers) do provider:RefreshAllData(true) end
end

function Stubs.CloseWorldMap()
    local map = _G.WorldMapFrame
    map:Hide()
    for _, provider in ipairs(map.providers) do provider:OnHide() end
end

function Stubs.ZoomWorldMap(scale)
    local map = _G.WorldMapFrame
    map.canvasScale = scale
    for _, provider in ipairs(map.providers) do provider:OnCanvasScaleChanged() end
end

function Stubs.LoadWorldMap()
    _G.WorldMapFrame = Stubs.NewWorldMap()
    Stubs.Fire("ADDON_LOADED", "Blizzard_WorldMap")
end

-- The pins on the map: our buttons on the canvas that are shown, with where they are.
function Stubs.MapPins()
    local pins = {}
    for _, region in ipairs(state.regions) do
        if region.kind == "Button" and region.pin and region:IsVisible() then
            local point = region.points[1]
            pins[#pins + 1] = { pin = region.pin, button = region, x = point[4], y = point[5], size = region.width }
        end
    end
    return pins
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

    G.CreateFrame = function(kind, _, parent) return newRegion(kind or "Frame", parent) end
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
    G.BagItemSearchBox = newRegion("Frame", G.ContainerFrame1)
    G.BagItemAutoSortButton = newRegion("Frame", G.ContainerFrame1)
    G.BagItemAutoSortButton:Hide()
    -- Chat: the combat log window and its tab, and the buttons next to ChatFrame1.
    G.ChatFrame2 = newRegion("Frame", G.UIParent)
    G.ChatFrame2Tab = newRegion("Button", G.UIParent)
    G.ChatFrame1ButtonFrame = newRegion("Frame", G.UIParent)
    G.ChatFrameMenuButton = newRegion("Button", G.ChatFrame1ButtonFrame)
    G.ChatFrameChannelButton = newRegion("Button", G.ChatFrame1ButtonFrame)
    G.ChatFrameToggleVoiceDeafenButton = newRegion("Button", G.UIParent)
    G.ChatFrameToggleVoiceMuteButton = newRegion("Button", G.UIParent)
    G.TextToSpeechButtonFrame = newRegion("Frame", G.UIParent)

    -- The minimap as Forever builds it: the cluster with its header bar and zone text button, the
    -- container with the map, the round frame and the coordinates under the map.
    G.MinimapCluster = newRegion("Frame", G.UIParent)
    local cluster = G.MinimapCluster
    cluster.BorderTop = newRegion("Frame", cluster)
    cluster.BorderTop:SetPoint("TOP", cluster, "TOP", 15, -4)
    cluster.ZoneTextButton = newRegion("Button", cluster)
    cluster.ZoneTextButton:SetSize(135, 12)
    cluster.ZoneTextButton:SetPoint("LEFT", cluster.BorderTop, "LEFT", 4, 0)
    G.MinimapZoneText = newRegion("FontString", cluster.ZoneTextButton)
    G.MinimapZoneText:SetWidth(130)
    G.MinimapZoneText:SetJustifyH("LEFT")
    G.MinimapZoneText:SetTextColor(1, 0.82, 0)
    local minimapContainer = newRegion("Frame", cluster)
    cluster.MinimapContainer = minimapContainer
    G.Minimap = newRegion("Minimap", minimapContainer)
    G.Minimap:SetSize(198, 198)
    G.Minimap:SetMaskTexture("ui-hud-minimap-frame-generic-mask")
    local backdrop = newRegion("Frame", G.Minimap)
    G.MinimapCompassTexture = newRegion("Texture", backdrop)
    G.MinimapCompassTextureUnderlay = newRegion("Texture", backdrop)
    minimapContainer.PlayerCoords = newRegion("Frame", minimapContainer)
    minimapContainer.PlayerCoords:SetPoint("BOTTOM", G.Minimap, "BOTTOM", 0, -18)
    -- The buttons around it: tracking left of the header bar, clock and calendar on its right, the
    -- addon compartment under the calendar, and Forever's day and night icon on the round frame.
    cluster.Tracking = newRegion("Frame", cluster)
    cluster.Tracking:SetSize(17, 17)
    cluster.Tracking:SetPoint("RIGHT", cluster.BorderTop, "LEFT", -2, 0)
    G.TimeManagerClockButton = newRegion("Button", cluster)
    G.TimeManagerClockButton:SetSize(40, 16)
    G.TimeManagerClockButton:SetPoint("TOPRIGHT", cluster.BorderTop, "TOPRIGHT", -4, 0)
    G.GameTimeFrame = newRegion("Button", cluster)
    G.GameTimeFrame:SetSize(19, 18)
    G.GameTimeFrame:SetPoint("TOPLEFT", cluster.BorderTop, "TOPRIGHT", 1, 0)
    G.AddonCompartmentFrame = newRegion("Button", cluster)
    G.AddonCompartmentFrame:SetSize(16, 16)
    G.AddonCompartmentFrame:SetPoint("TOPLEFT", G.GameTimeFrame, "BOTTOMLEFT", 0, 0)
    cluster.DielFrame = newRegion("Frame", cluster)
    cluster.DielFrame:SetSize(42, 42)
    cluster.DielFrame:SetPoint("CENTER", cluster, "CENTER", 63, 72)
    G.C_Texture = {
        GetAtlasInfo = function(atlas) return state.atlases[atlas] end,
    }

    -- Settings the client keeps (C_CVar), as strings.
    G.C_CVar = {
        GetCVar = function(name) return state.cvars[name] end,
        GetCVarDefault = function(name) return state.cvarDefaults[name] end,
        SetCVar = function(name, value)
            state.cvars[name] = tostring(value)
            table.insert(state.cvarSets, name .. "=" .. tostring(value))
        end,
    }

    -- Quest givers: state.quest holds what the NPC offers; every call the addon makes is recorded.
    local quest = function() return state.quest end
    local function record(call) table.insert(state.quest.calls, call) end
    G.IsShiftKeyDown = function() return state.shift end
    G.UnitGUID = function(unit) if unit == "npc" then return quest().npc end return nil end
    G.C_GossipInfo = {
        GetActiveQuests = function() return quest().gossipActive end,
        GetAvailableQuests = function() return quest().gossipAvailable end,
        SelectActiveQuest = function(questID) record("gossipActive:" .. questID) end,
        SelectAvailableQuest = function(questID) record("gossipAvailable:" .. questID) end,
    }
    G.GetNumActiveQuests = function() return #quest().greetingActive end
    G.GetActiveTitle = function(i) local q = quest().greetingActive[i] return q.title, q.isComplete end
    G.GetActiveQuestID = function(i) return quest().greetingActive[i].questID end
    G.SelectActiveQuest = function(i) record("greetingActive:" .. i) end
    G.GetNumAvailableQuests = function() return #quest().greetingAvailable end
    G.GetAvailableQuestInfo = function(i) return false, 0, false, false, quest().greetingAvailable[i].questID end
    G.SelectAvailableQuest = function(i) record("greetingAvailable:" .. i) end
    G.AcceptQuest = function() record("accept") end
    G.QuestGetAutoAccept = function() return quest().autoAccept end
    G.QuestIsFromAdventureMap = function() return false end
    G.IsQuestCompletable = function() return quest().completable end
    G.GetQuestMoneyToGet = function() return quest().money end
    G.CompleteQuest = function() record("complete") end
    G.GetNumQuestChoices = function() return quest().choices end
    G.GetQuestReward = function(choice) record("reward:" .. choice) end

    -- The world map: a MapCanvas with its data providers, at state.worldMap.
    G.Enum.UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3 }
    G.CreateFromMixins = function(...)
        local object = {}
        for i = 1, select("#", ...) do
            for key, value in pairs((select(i, ...))) do object[key] = value end
        end
        return object
    end
    G.MapCanvasDataProviderMixin = {
        OnAdded = function(self, map) self.owningMap = map end,
        GetMap = function(self) return self.owningMap end,
        OnMapChanged = function(self) self:RefreshAllData() end,
        RefreshAllData = noop, RemoveAllData = noop, OnShow = noop, OnHide = noop, OnCanvasScaleChanged = noop,
    }
    G.C_Map = {
        GetMapInfo = function(mapID) return state.maps[mapID] end,
        GetMapRectOnMap = function(mapID, topMapID)
            local rect = state.mapRects[mapID .. ">" .. topMapID]
            if not rect then return nil end
            return rect[1], rect[2], rect[3], rect[4]
        end,
        GetAreaInfo = function(areaID) return state.areas[areaID] end,
    }
    G.WorldMapFrame = Stubs.NewWorldMap()
    G.GameTooltip = { lines = {} }
    function G.GameTooltip:SetOwner(owner) self.owner, self.lines, self.shown = owner, {}, false end
    function G.GameTooltip:SetText(text) self.lines = { { text = text } } end
    function G.GameTooltip:AddLine(text, r, g, b) table.insert(self.lines, { text = text, color = { r, g, b } }) end
    function G.GameTooltip:Show() self.shown = true end
    function G.GameTooltip:Hide() self.shown = false end

    -- Units: state.units[unit] = { isPlayer, treatAsPlayer, class }; a unit that isn't there doesn't exist.
    G.UnitIsPlayer = function(unit)
        local info = state.units[unit]
        if info and info.isPlayer ~= nil then return info.isPlayer end
        return false
    end
    G.UnitTreatAsPlayerForDisplay = function(unit)
        local info = state.units[unit]
        return info ~= nil and info.treatAsPlayer == true
    end
    G.UnitClass = function(unit)
        local info = state.units[unit]
        if not (info and info.class) then return nil end
        return "Localized " .. tostring(info.class), info.class, 1
    end
    G.RAID_CLASS_COLORS = {
        MAGE = { r = 0.25, g = 0.78, b = 0.92 },
        PRIEST = { r = 1, g = 1, b = 1 },
        ROGUE = { r = 1, g = 0.96, b = 0.41 },
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    }

    -- Unit frames, each with the health bar UnitFrame_Initialize stores in frame.healthbar.
    state.healthBars = {}
    for name, unit in pairs({ PlayerFrame = "player", TargetFrame = "target", TargetFrameToT = "targettarget",
        FocusFrame = "focus", FocusFrameToT = "focustarget" }) do
        local bar, raw = newHealthBar(unit)
        state.healthBars[name] = raw
        G[name] = { unit = unit, healthbar = bar }
    end

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
    "GetMinimapShape", "HybridMinimap", "TimeManagerClockButton", "GameTimeFrame", "AddonCompartmentFrame",
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
        units = { player = { isPlayer = true, class = "MAGE" } },
        atlases = { ["ui-hud-minimap-frame-generic-mask"] = { width = 215, height = 226 } },
        cvars = { chatClassColorOverride = "2" }, cvarDefaults = { chatClassColorOverride = "2" }, cvarSets = {},
        shift = false,
        quest = { npc = "Creature-0-1-0-1-3139-0001", gossipActive = {}, gossipAvailable = {}, greetingActive = {},
            greetingAvailable = {}, autoAccept = false, completable = true, money = 0, choices = 0, calls = {} },
        -- A few of Forever's maps; a retail client has none of them (state.maps = {}).
        maps = { [1413] = { name = "The Barrens", mapType = 3, parentMapID = 1414 },
            [1414] = { name = "Kalimdor", mapType = 2, parentMapID = 947 } },
        mapRects = {}, areas = {},
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
        CreateDropdown = function(_, setting, options, tooltip)
            return newInitializer(setting, "dropdown", { options = options, tooltip = tooltip })
        end,
        CreateControlTextContainer = function()
            local container = { data = {} }
            function container:Add(value, label) table.insert(self.data, { value = value, label = label }) end
            function container:GetData() return self.data end
            return container
        end,
        RegisterAddOnCategory = function(category) api.registered = category end,
        OpenToCategory = function(id) api.opened = id end,
    }
    _G.CreateSettingsListSectionHeaderInitializer = function(text, tooltip) return { header = text, tooltip = tooltip } end
    _G.MinimalSliderWithSteppersMixin = { Label = { Right = 2 } }
    return api
end

-- Puts a unit in the world (info: isPlayer, treatAsPlayer, class), or removes it with nil.
function Stubs.SetUnit(unit, info)
    state.units[unit] = info
end

-- The raw state of a unit frame's health bar (unit, color, desaturated), by frame name. Tests
-- change bar.unit here, the way Blizzard switches the player frame to a vehicle.
function Stubs.HealthBar(frameName)
    return state.healthBars[frameName]
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
