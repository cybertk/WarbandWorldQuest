if GetLocale() ~= "ruRU" then
	return
end

local _, ns = ...
local L = ns.L
--Translator ZamestoTV
L["next_reset_dropdown_exclude_types"] = "Исключить типы локальных заданий"
L["next_reset_button_text"] = "Следующий сброс: %s (%d)"
L["next_reset_tooltip_title"] = "Предстоящий сброс локальных заданий"
L["next_reset_tooltip_quest_num"] = "Количество заданий: |cnWHITE_FONT_COLOR:%d|r"

L["characters_dropdown_title"] = "Исключить персонажей"
L["characters_dropdown_instruction"] = "Нажмите %s для удаления персонажа"
L["characters_tooltip_title"] = "Статус отслеживаемых персонажей"
L["characters_tooltip_last_reset_time"] = "Время последнего сброса локальных заданий: |cnWHITE_FONT_COLOR:%s|r"

L["settings_pins_progress_label_shown_text"] = "Метка прогресса группы"
L["settings_pins_tooltip_progress_shown_text"] = "Прогресс в подсказке"
L["settings_pins_tooltip_progress_shown_tooltip"] = "Показывать прогресс заданий и награды для всех отслеживаемых персонажей в подсказке на карте"
L["settings_pins_continent_maps_shown_text"] = "Континентальные карты"
L["settings_pins_completed_quest_shown_text"] = "Завершённые задания"
L["settings_pins_completed_quest_shown_tooltip"] = "Показывать метки на карте для завершённых локальных заданий"
L["settings_log_default_tab_text"] = "Вкладка по умолчанию"
L["settings_log_default_tab_tooltip"] = "Установить %s как вкладку по умолчанию, она открывается автоматически при первом открытии мировой карты после входа в игру"
L["settings_log_scanning_icon_shown_text"] = "Иконка ожидания сканирования"
L["settings_log_scanning_icon_shown_tooltip"] = "Отображать иконку %s в заголовке задания, если прогресс задания не был отсканирован для всех отслеживаемых персонажей"
L["settings_log_time_left_shown_tooltip"] = "Показывать метку оставшегося времени в журнале заданий"
L["settings_maps_title"] = "Сканирование карт"
L["settings_filters_title"] = "Фильтры заданий по наградам"

L["log_entry_tooltip_characters_scanned"] = "Отсканированные персонажи"
L["log_entry_tooltip_characters_completed"] = "Завершившие персонажи"
L["log_entry_tooltip_total_rewards"] = "Общие награды группы:"
