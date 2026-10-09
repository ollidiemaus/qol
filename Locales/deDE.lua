local _, ns = ...

if GetLocale() ~= "deDE" then return end

local L = ns.L

L.SLASH_HELP = "/fqol öffnet die Einstellungen."

-- Settings: main page
L.SECTION_MERCHANT = "Händler"
L.SELL_JUNK = "Müll automatisch verkaufen"
L.SELL_JUNK_TIP = "Verkauft alle grauen (minderwertigen) Gegenstände, sobald du einen Händler öffnest."
L.AUTO_REPAIR = "Automatisch reparieren"
L.AUTO_REPAIR_TIP = "Repariert deine gesamte Ausrüstung, sobald du einen Händler öffnest, der reparieren kann."
L.GUILD_REPAIR = "Gildengold verwenden"
L.GUILD_REPAIR_TIP = "Bezahlt Reparaturen zuerst aus der Gildenbank, soweit die Gilde es dir erlaubt. "
    .. "Den Rest zahlt dein eigenes Gold."

L.SECTION_TOOLTIPS = "Tooltips"
L.TOOLTIP_IDS = "IDs anzeigen"
L.TOOLTIP_IDS_TIP = "Zeigt die ID von Zaubern, Gegenständen, Stärkungs- und Schwächungszaubern, NPCs, Quests, "
    .. "Währungen und Erfolgen in ihren Tooltips."
L.TOOLTIP_SELL_PRICE = "Händlerpreis anzeigen"
L.TOOLTIP_SELL_PRICE_TIP = "Zeigt, wofür ein Gegenstand beim Händler verkauft wird, auch ohne geöffneten Händler. "
    .. "Bei einem Stapel der Preis des ganzen Stapels."

L.SECTION_INTERFACE = "Oberfläche"
L.HIDE_MICRO_MENU = "Systemleiste ausblenden"
L.HIDE_MICRO_MENU_TIP = "Blendet die Systemleiste (Mikromenü) mit den Knöpfen für Charakter, Zauberbuch und "
    .. "Spielmenü aus. Deine Tastenbelegungen öffnen diese Fenster weiterhin, und in Fahrzeugen erscheinen die "
    .. "Knöpfe wie gewohnt auf der Fahrzeugleiste."
L.HIDE_BAGS_BAR = "Taschenleiste ausblenden"
L.HIDE_BAGS_BAR_TIP =
"Blendet den Rucksack und die Taschenplätze aus. Deine Taschen-Tastenbelegungen funktionieren weiterhin."
L.HIDE_MINIMAP_COORDS = "Koordinaten unter der Minimap ausblenden"
L.HIDE_MINIMAP_COORDS_TIP = "Blendet die Spielerkoordinaten unter der Minimap aus."
L.HIDE_CHAT_SOCIAL = "Sozial-Knopf über dem Chat ausblenden"
L.HIDE_CHAT_SOCIAL_TIP = "Blendet den Freunde- und Schnellbeitritt-Knopf oben am Chatfenster aus. "
    .. "Das Kontaktefenster öffnet sich weiterhin mit seiner Tastenbelegung."
L.SHOW_COMBINED_BAG_SORT = "Sortieren-Knopf an kombinierten Taschen anzeigen"
L.SHOW_COMBINED_BAG_SORT_TIP = "Fügt der kombinierten Tasche den Sortieren-Knopf (Aufräumen) neben dem Suchfeld hinzu."

L.SECTION_COMMANDS = "Chatbefehle"
L.RELOAD_COMMAND = "/rl lädt die Oberfläche neu"
L.RELOAD_COMMAND_TIP = "Fügt /rl als Kurzform von /reload hinzu. Nur wenn das Spiel und deine anderen "
    .. "Addons /rl nicht schon verwenden; dann bleibt deren Befehl."

-- Settings: viewport page
L.CATEGORY_VIEWPORT = "Viewport"
L.VIEWPORT_ENABLE = "3D-Welt verkleinern"
L.VIEWPORT_ENABLE_TIP = "Zeichnet die Spielwelt in einem kleineren Bereich und füllt die Ränder mit einer Farbe, "
    .. "damit Oberflächenelemente am Bildschirmrand die Welt nicht mehr verdecken."
L.VIEWPORT_TOP = "Rand oben"
L.VIEWPORT_BOTTOM = "Rand unten"
L.VIEWPORT_LEFT = "Rand links"
L.VIEWPORT_RIGHT = "Rand rechts"
L.VIEWPORT_MARGIN_TIP = "In Bildschirmpixeln."
L.VIEWPORT_COLOR = "Randfarbe"
L.VIEWPORT_COLOR_TIP = "Die Farbe, mit der die Ränder um die Welt gefüllt werden."
L.PIXELS = "%d px"

-- Settings: action bars page
L.CATEGORY_ACTION_BARS = "Aktionsleisten"
L.SECTION_FLIP_VERTICAL = "Vertikale Wachstumsrichtung umkehren"
L.FLIP_VERTICAL_TIP = "Füllt die Reihen von der anderen Seite: oberste und unterste Reihe tauschen. "
    .. "Nur bei Leisten mit mehr als einer Reihe sichtbar."
L.SECTION_FLIP_HORIZONTAL = "Horizontale Wachstumsrichtung umkehren"
L.FLIP_HORIZONTAL_TIP = "Füllt jede Reihe von der anderen Seite: links und rechts tauschen."
L.ACTION_BAR = "Aktionsleiste %d"
L.STANCE_BAR = "Haltungsleiste"
L.PET_BAR = "Begleiterleiste"

-- Chat messages
L.SOLD_JUNK = "%d |4Müllgegenstand:Müllgegenstände; für %s verkauft."
L.REPAIRED = "Für %s repariert."
L.REPAIRED_GUILD = "Für %s aus der Gildenbank repariert."
L.REPAIRED_GUILD_PARTIAL = "Für %s repariert (Gildenbank %s, du %s)."
L.REPAIR_NO_MONEY = "Nicht genug Gold zum Reparieren (%s benötigt)."

-- Tooltips
L.ID_ITEM = "Gegenstands-ID"
L.ID_SPELL = "Zauber-ID"
L.ID_NPC = "NPC-ID"
L.ID_QUEST = "Quest-ID"
L.ID_CURRENCY = "Währungs-ID"
L.ID_ACHIEVEMENT = "Erfolgs-ID"
L.SELL_PRICE = "Verkaufspreis"
L.SELL_PRICE_STACK = "%s (je %s)"
