local _, ns = ...

local L = {}
ns.L = L

L["next_reset_dropdown_exclude_types"] = "Exclude World Quest Types"
L["next_reset_button_text"] = "Next Reset: %s (%d)"
L["next_reset_tooltip_title"] = "Upcomming Reset of World Quests"
L["next_reset_tooltip_quest_num"] = "Quests Count: |cnWHITE_FONT_COLOR:%d|r"

L["characters_dropdown_title"] = "Exclude Characters"
L["characters_dropdown_instruction"] = "Press %s to delete the character"
L["characters_tooltip_title"] = "Tracked Characters Status"
L["characters_tooltip_last_reset_time"] = "Last World Quests Reset Time: |cnWHITE_FONT_COLOR:%s|r"

L["warmode_tooltip_instruction"] = "Click to %s War Mode button"

L["settings_pins_section_all"] = "Applied to All Pins"
L["settings_pins_section_filtered"] = "Pins of Filtered Quests Only"
L["settings_pins_progress_label_shown_text"] = "Warband Progress Label"
L["settings_pins_progress_label_shown_tooltip"] =
	"Show progress text on quest pins offering filtered rewards|n|nThe text format can be adjusted in the |cnWHITE_FONT_COLOR:Quest Log|r settings"
L["settings_pins_inactive_opacity_text"] = "Inactive Quests Opacity"
L["settings_pins_inactive_opacity_tooltip"] = "Hide or fade pins for inactive quests by adjusting opacity"
L["settings_pins_tooltip_progress_shown_text"] = "Progress in Tooltip"
L["settings_pins_tooltip_progress_shown_tooltip"] = "Show quest progress and rewards for all tracked characters in the map pin's tooltip"
L["settings_pins_continent_maps_shown_text"] = "Continent Maps"
L["settings_pins_continent_maps_shown_tooltip"] = "Show quest pins on continent maps"
L["settings_pins_completed_quest_shown_text"] = "Completed Quests"
L["settings_pins_completed_quest_shown_tooltip"] = "Show pins for completed quests, with a |A:common-icon-checkmark:15:15:0:0|a indicator"
L["settings_log_default_tab_text"] = "Default Tab"
L["settings_log_default_tab_tooltip"] = "Set %s as the default tab, it opens automatically when opening the World Map for the first time after logging in"
L["settings_log_section_fields"] = "Quest Info Fields"
L["settings_log_scanning_icon_shown_text"] = "Pending Scan Icon"
L["settings_log_scanning_icon_shown_tooltip"] = "Display an icon %s in the quest title if the quest progress hasn't been scanned on all tracked characters"
L["settings_log_progress_shown_text"] = "Warband Progress"
L["settings_log_progress_shown_tooltip"] =
	"Show progress label indicating quest completion status across your characters|n|n|cnWHITE_FONT_COLOR:Red Text|r|nThe quest does not provide any filtered rewards for the current character|n|n|cnWHITE_FONT_COLOR:Green Text|r|nThe quest is completed by the current character."
L["settings_log_progress_shown_option_1_text"] = "Rewards Claimed Characters"
L["settings_log_progress_shown_option_1_tooltip"] =
	"Show progress as |cnWHITE_FONT_COLOR:X/Y|r|n|n|cnWHITE_FONT_COLOR:X|r|nThe number of characters who have completed the quest and claimed the filtered rewards|n|n|cnWHITE_FONT_COLOR:Y|r|nThe number of characters eligible to claim the filtered reward from the quest"
L["settings_log_progress_shown_option_2_text"] = "Remaining Characters"
L["settings_log_progress_shown_option_2_tooltip"] =
	"Show the number of characters who are eligible to claim the filtered rewards from the quest but have not yet completed it"
L["settings_log_time_left_shown_tooltip"] = "Show time left label in the quest log"
L["settings_log_warband_rewards_shown_tooltip"] =
	"Show accumulated rewards for all characters in the quest log, either as a total or uncollected.|nWhen disabled, show rewards of current logged-in character"
L["settings_maps_title"] = "Scanning Maps"
L["settings_filters_title"] = "Quest Filters by Rewards"
L["settings_section_text"] = "%s Section"
L["settings_section_completed_tooltip"] = "Show completed quests under the Completed section|n|nWhen disabled, completed quests will be shown under the Inactive section"
L["settings_section_completed_option_all_text"] = "All Eligible Characters"
L["settings_section_completed_option_all_tooltip"] = "The quest is considered completed only if all characters have claimed the filtered rewards"
L["settings_section_completed_option_current_text"] = "Current Character Only"
L["settings_section_completed_option_current_tooltip"] = "The quest is considered completed if the current character has completed it"

L["log_entry_tooltip_characters_scanned"] = "Characters Scanned"
L["log_entry_tooltip_characters_completed"] = "Characters Completed"
L["log_entry_tooltip_total_rewards"] = "Total Warband Rewards:"
