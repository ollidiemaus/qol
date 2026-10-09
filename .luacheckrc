std = "lua51"
max_line_length = 140
self = false -- methods often ignore self (event handlers, mixin-style APIs)
-- .lua/, .luarocks/ and .install/ are the toolchains the CI actions install into the workspace.
exclude_files = { ".git/", ".release/", ".lua/", ".luarocks/", ".install/" }

-- Globals the addon defines.
globals = {
    "ForeverQoLDB",
    "SLASH_FOREVERQOL1",
    "SLASH_FOREVERQOL2",
    "SlashCmdList",
    "SLASH_FOREVERQOL_RELOAD1",
    "hash_SlashCmdList",
}

-- WoW API the addon reads. Keep this list explicit: an unexpected global is usually a typo.
read_globals = {
    -- Lua extensions in the WoW client
    "issecretvalue", "strsplit", "strtrim",
    -- Frames and UI
    "CreateFrame", "UIParent", "WorldFrame", "DEFAULT_CHAT_FRAME", "EventRegistry",
    "Settings", "CreateSettingsListSectionHeaderInitializer", "MinimalSliderWithSteppersMixin",
    "GridLayoutUtil", "AnchorUtil", "TooltipDataProcessor",
    "MicroMenuContainer", "ContainerFrameCombinedBags", "BagItemAutoSortButton", "BagItemSearchBox",
    "BagsBar", "QuickJoinToastButton", "MinimapCluster",
    "InCombatLockdown", "GetPhysicalScreenSize", "ReloadUI", "IsSecureCmd", "CinematicFrame", "MovieFrame",
    -- Strings and formatting
    "GetLocale", "GetMoneyString", "SELL_PRICE",
    -- Bags, items and merchants
    "NUM_BAG_SLOTS", "NUM_TOTAL_EQUIPPED_BAG_SLOTS",
    "CanMerchantRepair", "GetRepairAllCost", "RepairAllItems", "GetMoney",
    "IsInGuild", "CanGuildBankRepair", "GetGuildBankWithdrawMoney", "GetGuildBankMoney",
    "GetAddOnMetadata",
    -- Namespaces
    "Enum", "C_AddOns", "C_Container", "C_EventUtils", "C_Item", "C_MerchantFrame", "C_Timer",
}

files["Locales/"] = { max_line_length = false }

-- Tests replace the WoW API with stubs through _G.
files["tests/"] = {
    std = "max",
    ignore = { "111", "112", "113", "122", "142", "143" },
}
