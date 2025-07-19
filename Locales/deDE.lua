if GetLocale() ~= "deDE" then
	return
end

local _, ns = ...
local L = ns.L

L["info_reward_claimed"] = "Herzlichen Glückwunsch! Du hast %s erhalten"
L["info_reward_attempt"] = "Aufzeichnung: %s - Dies ist der %d. Versuch diese Woche, %d Versuche insgesamt"

L["next_reset_dropdown_exclude_types"] = "Weltquest-Typen ausschließen"
L["next_reset_button_text"] = "Nächster Reset: %s (%d)"
L["next_reset_tooltip_title"] = "Anstehender Reset der Weltquests"
L["next_reset_tooltip_quest_num"] = "Anzahl der Quests: |cnWHITE_FONT_COLOR:%d|r"

L["characters_dropdown_title"] = "Charaktere ausschließen"
L["characters_dropdown_instruction"] = "Drücke %s, um den Charakter zu löschen"
L["characters_tooltip_title"] = "Status der getrackten Charaktere"
L["characters_tooltip_last_reset_time"] = "Letzter Instanz-Reset: |cnWHITE_FONT_COLOR:%s|r"

L["settings_reward_announcement_tooltip"] =
	"Zeigt eine Chat-Nachricht an, wenn die getrackte Belohnung erhalten oder versucht wurde.|n|nSpielt einen Ton ab, wenn sie erhalten wurde."
L["settings_pins_progress_label_shown_text"] = "Kriegsmeute-Fortschrittsanzeige"
L["settings_pins_tooltip_progress_shown_text"] = "Fortschritt im Tooltip"
L["settings_pins_tooltip_progress_shown_tooltip"] = "Zeigt den Questfortschritt und die Belohnungen für alle getrackten Charaktere im Tooltip des Karten-Pins an."
L["settings_pins_continent_maps_shown_text"] = "Kontinentkarten"
L["settings_pins_completed_quest_shown_text"] = "Abgeschlossene Quests"
L["settings_pins_completed_quest_shown_tooltip"] = "Zeigt Karten-Pins für abgeschlossene Weltquests an."
L["settings_log_default_tab_text"] = "Standard-Reiter"
L["settings_log_default_tab_tooltip"] = "Setzt %s als Standard-Reiter, der sich beim ersten Öffnen der Weltkarte nach dem Einloggen automatisch öffnet."
L["settings_log_scanning_icon_shown_text"] = "Symbol für ausstehenden Scan"
L["settings_log_scanning_icon_shown_tooltip"] = "Zeigt ein Symbol (%s) im Questtitel an, wenn der Questfortschritt nicht auf allen getrackten Charakteren gescannt wurde."
L["settings_log_time_left_shown_tooltip"] = "Zeigt die verbleibende Zeit im Questlog an."
L["settings_log_warband_rewards_shown_tooltip"] =
	"Zeigt die gesammelten Belohnungen für alle Charaktere im Questlog an, entweder als Gesamtsumme oder nicht eingesammelt.|nWenn deaktiviert, werden die Belohnungen des aktuell eingeloggten Charakters angezeigt."
L["settings_maps_title"] = "Karten zum Scannen"
L["settings_filters_title"] = "Questfilter nach Belohnungen"

L["log_entry_tooltip_characters_scanned"] = "Gescannte Charaktere"
L["log_entry_tooltip_characters_completed"] = "Abgeschlossene Charaktere"
L["log_entry_tooltip_characters_pending"] = "Ausstehende Charaktere"
L["log_entry_tooltip_characters_unknown"] = "Unbekannte Charaktere"
L["log_entry_tooltip_total_rewards"] = "Gesamtbelohnungen der Kriegsmeute:"
L["log_entry_tooltip_attempts_reset"] = "Versuche dieser ID: %s"
L["log_entry_tooltip_attempts_total"] = "Versuche insgesamt: %s"

L["log_enounter_tooltip_difficulity_instruction"] = "%s (Setzen)"

L["log_entry_position_unknown"] = "Position von %s ist unbekannt"
