std = "lua51"
max_line_length = 140
self = false -- methods often ignore self (event handlers, mixin-style APIs)
-- .lua/, .luarocks/ and .install/ are the toolchains the CI actions install into the workspace.
exclude_files = { ".git/", ".release/", ".lua/", ".luarocks/", ".install/" }

-- Globals the addon defines.
globals = {
    "QoLAPI",
    "QoLDB",
    "SLASH_QOL1",
    "SLASH_QOL2",
    "SlashCmdList",
    "SLASH_QOL_RELOAD1",
    "hash_SlashCmdList",
    "GetMinimapShape", -- answers "SQUARE" while the minimap is square
    "BINDING_HEADER_QOL", -- Bindings.xml's header; BackButtons.lua names its bindings through _G
}

-- WoW API the addon reads. Keep this list explicit: an unexpected global is usually a typo.
read_globals = {
    -- Lua extensions in the WoW client
    "issecretvalue", "strsplit", "strtrim",
    -- Frames and UI
    "CreateFrame", "UIParent", "WorldFrame", "DEFAULT_CHAT_FRAME", "EventRegistry",
    "Settings", "CreateSettingsListSectionHeaderInitializer", "MinimalSliderWithSteppersMixin",
    "ColorPickerFrame",
    "SETTINGS_DEFAULTS", "RESET", "NORMAL_FONT_COLOR", "GRAY_FONT_COLOR", "HIGHLIGHT_FONT_COLOR", "PlaySound", "SOUNDKIT",
    "GridLayoutUtil", "AnchorUtil", "TooltipDataProcessor",
    "MicroMenuContainer", "ContainerFrameCombinedBags",
    "BagsBar", "QuickJoinToastButton", "MinimapCluster", "Minimap", "MinimapZoneText", "MinimapCompassTexture",
    "MinimapCompassTextureUnderlay", "HybridMinimap", "TimeManagerClockButton",
    "TimeManagerClockTicker", "GameTimeFrame", "AddonCompartmentFrame", "WorldMapFrame", "MapCanvasDataProviderMixin", "CreateFromMixins",
    "GameTooltip",
    "ChatFrame2", "ChatFrame2Tab", "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton", "TextToSpeechButtonFrame", "BuffFrameTooltip",
    "InCombatLockdown", "GetPhysicalScreenSize", "ReloadUI", "IsSecureCmd", "geterrorhandler", "CinematicFrame", "MovieFrame",
    "IsShiftKeyDown", "GamepadMainActionBarFrame", "GamepadMode", "SettingsPanel", "GameMenuFrame", "GetCursorPosition", "GetCursorInfo",
    "SecureHandlerWrapScript", "EditModeManagerFrame",
    "SendMailFrame", "SendMailNameEditBox", "SendMailSubjectEditBox",
    -- Performance
    "GetFramerate", "GetNetStats",
    -- Key bindings
    "GetBindingKey", "GetBindingAction", "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings",
    "IsModifiedClick", "SetBinding", "GetBindingText", "GetBindingName", "IsKeyPressIgnoredForBinding",
    "CreateKeyChordStringUsingMetaKeyState", "NOT_BOUND", "SaveBindings", "GetCurrentBindingSet",
    -- Action slots, and what goes on a ring
    "PickupAction", "PlaceAction", "ClearCursor", "PlayerHasToy", "GetMacroInfo", "GetMacroIndexByName",
    "GetMacroSpell", "GetMacroItem", "PickupMacro", "GetNumMacros", "MAX_ACCOUNT_MACROS", "GetInventoryItemID",
    "GetFlyoutInfo", "GetFlyoutSlotInfo", "SPELLBOOK_FONT_COLOR",
    -- Strings and formatting
    "GetLocale", "GetMoneyString", "AbbreviateLargeNumbers",
    -- Units
    "UnitIsPlayer", "UnitTreatAsPlayerForDisplay", "UnitClass", "UnitGUID", "UnitName", "GetNormalizedRealmName",
    "RegionalUniqueNamesEnabled", "RAID_CLASS_COLORS",
    "UnitPowerType", "UnitPower", "UnitPowerMax", "PlayerFrame",
    -- Quests
    "AcceptQuest", "CompleteQuest", "GetQuestReward", "GetNumQuestChoices", "IsQuestCompletable", "GetQuestMoneyToGet",
    "QuestGetAutoAccept", "QuestIsFromAdventureMap", "GetNumActiveQuests", "GetNumAvailableQuests", "GetActiveTitle",
    "GetActiveQuestID", "GetAvailableQuestInfo", "SelectActiveQuest", "SelectAvailableQuest",
    -- Bags, items and merchants
    "NUM_BAG_SLOTS", "NUM_TOTAL_EQUIPPED_BAG_SLOTS",
    "CanMerchantRepair", "GetRepairAllCost", "RepairAllItems", "GetMoney",
    "IsInGuild", "CanGuildBankRepair", "GetGuildBankWithdrawMoney", "GetGuildBankMoney",
    "GetAddOnMetadata", "IsAddOnLoaded", "IsMacClient",
    -- Namespaces
    "Enum", "C_ActionBar", "C_AddOns", "C_Container", "C_CVar", "C_EventUtils", "C_GossipInfo", "C_Item", "C_Map", "C_MerchantFrame",
    "C_InputInterfaceStyle", "C_KeyBindings", "C_Texture", "C_Timer",
    "C_GamePad", "C_TooltipInfo", "C_Spell", "C_SpellBook", "C_MountJournal", "C_ToyBox",
}

files["Locales/"] = { max_line_length = false }

-- Tests replace the WoW API with stubs through _G.
files["tests/"] = {
    std = "max",
    ignore = { "111", "112", "113", "122", "142", "143" },
}
