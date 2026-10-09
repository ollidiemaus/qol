local _, ns = ...

-- Missing keys fall back to the key itself, so a forgotten translation shows up as
-- readable text instead of a Lua error.
local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

L.ADDON_TITLE = "Forever QoL"
L.SLASH_HELP = "/fqol opens the settings."

-- Settings: main page
L.SECTION_MERCHANT = "Merchant"
L.SELL_JUNK = "Sell junk automatically"
L.SELL_JUNK_TIP = "Sells all grey (poor quality) items when you open a merchant."
L.AUTO_REPAIR = "Repair automatically"
L.AUTO_REPAIR_TIP = "Repairs all your equipment when you open a merchant who can repair."
L.GUILD_REPAIR = "Use guild funds"
L.GUILD_REPAIR_TIP = "Pays for repairs from the guild bank first, as far as the guild allows you. "
    .. "Your own gold covers the rest."

L.SECTION_TOOLTIPS = "Tooltips"
L.TOOLTIP_IDS = "Show IDs"
L.TOOLTIP_IDS_TIP = "Adds the ID of spells, items, buffs and debuffs, NPCs, quests, currencies and achievements "
    .. "to their tooltips."
L.TOOLTIP_SELL_PRICE = "Show vendor price"
L.TOOLTIP_SELL_PRICE_TIP = "Shows what an item sells for at a merchant, also when no merchant is open. "
    .. "For a stack, the price of the whole stack."

L.SECTION_INTERFACE = "Interface"
L.HIDE_MICRO_MENU = "Hide system bar"
L.HIDE_MICRO_MENU_TIP = "Hides the system bar (micro menu) with the character, spellbook and game menu buttons. "
    .. "Your key bindings still open those windows, and in a vehicle the buttons show on the vehicle bar as usual."
L.HIDE_BAGS_BAR = "Hide bag bar"
L.HIDE_BAGS_BAR_TIP = "Hides the backpack and bag slot buttons. Your bag key bindings still work."
L.HIDE_MINIMAP_COORDS = "Hide coordinates under the minimap"
L.HIDE_MINIMAP_COORDS_TIP = "Hides the player coordinates shown below the minimap."
L.HIDE_CHAT_SOCIAL = "Hide social button above the chat"
L.HIDE_CHAT_SOCIAL_TIP = "Hides the friends and quick join button on top of the chat window. "
    .. "The social window still opens with its key binding."

L.SECTION_COMMANDS = "Chat commands"
L.RELOAD_COMMAND = "/rl reloads the interface"
L.RELOAD_COMMAND_TIP = "Adds /rl as a short form of /reload. Only when the game and your other addons "
    .. "don't already use /rl; then theirs stays."

-- Settings: viewport page
L.CATEGORY_VIEWPORT = "Viewport"
L.VIEWPORT_ENABLE = "Shrink the 3D world"
L.VIEWPORT_ENABLE_TIP = "Draws the game world in a smaller area and fills the margins with a solid color, "
    .. "so interface elements at the screen edges no longer cover the world."
L.VIEWPORT_TOP = "Top margin"
L.VIEWPORT_BOTTOM = "Bottom margin"
L.VIEWPORT_LEFT = "Left margin"
L.VIEWPORT_RIGHT = "Right margin"
L.VIEWPORT_MARGIN_TIP = "In screen pixels."
L.VIEWPORT_COLOR = "Margin color"
L.VIEWPORT_COLOR_TIP = "The color that fills the margins around the world."
L.PIXELS = "%d px"

-- Settings: action bars page
L.CATEGORY_ACTION_BARS = "Action Bars"
L.SECTION_FLIP_VERTICAL = "Reverse vertical growth"
L.FLIP_VERTICAL_TIP = "Fills the rows from the other side: the top and bottom rows swap. "
    .. "Only visible on bars with more than one row."
L.SECTION_FLIP_HORIZONTAL = "Reverse horizontal growth"
L.FLIP_HORIZONTAL_TIP = "Fills each row from the other side: left and right swap."
-- Used only when the game doesn't provide its own Edit Mode names.
L.ACTION_BAR = "Action Bar %d"
L.STANCE_BAR = "Stance Bar"
L.PET_BAR = "Pet Bar"

-- Chat messages
L.SOLD_JUNK = "Sold %d junk |4item:items; for %s."
L.REPAIRED = "Repaired for %s."
L.REPAIRED_GUILD = "Repaired for %s from the guild bank."
L.REPAIRED_GUILD_PARTIAL = "Repaired for %s (guild bank %s, you %s)."
L.REPAIR_NO_MONEY = "Not enough gold to repair (%s needed)."

-- Tooltips
L.ID_ITEM = "Item ID"
L.ID_SPELL = "Spell ID"
L.ID_NPC = "NPC ID"
L.ID_QUEST = "Quest ID"
L.ID_CURRENCY = "Currency ID"
L.ID_ACHIEVEMENT = "Achievement ID"
-- Used only when the game doesn't provide its own SELL_PRICE text.
L.SELL_PRICE = "Sell Price"
L.SELL_PRICE_STACK = "%s (%s each)"
