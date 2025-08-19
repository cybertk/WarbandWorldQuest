local addonName, ns = ...

local L = ns.L
local Util = ns.Util
local QuestRewards = ns.QuestRewards
local WorldQuestList = ns.WorldQuestList
local CharacterStore = ns.CharacterStore
local Settings = ns.Settings

WarbandWorldQuestSettingsButtonMixin = {}

function WarbandWorldQuestSettingsButtonMixin:OnMouseDown()
	self.Icon:AdjustPointsOffset(1, -1)
end

function WarbandWorldQuestSettingsButtonMixin:OnMouseUp(button, upInside)
	self.Icon:AdjustPointsOffset(-1, 1)
end

function WarbandWorldQuestSettingsButtonMixin:OnLoad()
	self:Update(true)
end

function WarbandWorldQuestSettingsButtonMixin:Update(force)
	if not force and not self:IsMenuOpen() then
		return
	end

	self:SetupMenu(function(_, rootMenu)
		rootMenu:CreateTitle(SETTINGS)

		do -- Map Pins
			local pinsMenu = rootMenu:CreateButton(MAP_PIN)

			Settings:CreateOptionsTree(
				"pins_inactive_opacity",
				pinsMenu,
				L["settings_pins_inactive_opacity_text"],
				{ range = { 0, 100, 10 }, percentage = true },
				L["settings_pins_inactive_opacity_tooltip"],
				MenuResponse.Refresh
			)

			pinsMenu:CreateDivider()
			pinsMenu:CreateTitle(L["settings_pins_section_all"])

			Settings:CreateOptionsTree(
				"pins_tooltip_shown",
				pinsMenu,
				L["settings_pins_tooltip_progress_shown_text"],
				{ { text = ALWAYS, value = "" }, { text = CTRL_KEY, value = "CTRL" }, { text = ALT_KEY, value = "ALT" } },
				L["settings_pins_tooltip_progress_shown_tooltip"],
				MenuResponse.Refresh
			)

			pinsMenu:CreateDivider()
			pinsMenu:CreateTitle(L["settings_pins_section_filtered"])

			Settings:CreateCheckboxMenu(
				"pins_progress_shown",
				pinsMenu,
				L["settings_pins_progress_label_shown_text"],
				nil,
				L["settings_pins_progress_label_shown_tooltip"]
			)

			local continentsCheckbox = pinsMenu:CreateCheckbox(
				L["settings_pins_continent_maps_shown_text"],
				Settings:GenerateComparator("pins_min_display_level", Enum.UIMapType.Continent),
				Settings:GenerateRotator("pins_min_display_level", { Enum.UIMapType.Continent, Enum.UIMapType.Zone })
			)
			continentsCheckbox:SetTooltip(
				Settings:GenerateTooltip(L["settings_pins_continent_maps_shown_tooltip"], L["settings_pins_continent_maps_shown_text"])
			)

			Settings:CreateCheckboxMenu(
				"pins_completed_shown",
				pinsMenu,
				TRACKER_FILTER_COMPLETED_QUESTS,
				nil,
				L["settings_pins_completed_quest_shown_tooltip"]
			)
		end

		do -- Quest Log
			local logMenu = rootMenu:CreateButton(QUEST_LOG)

			Settings:CreateCheckboxMenu(
				"log_is_default_tab",
				logMenu,
				L["settings_log_default_tab_text"],
				nil,
				L["settings_log_default_tab_tooltip"]:format("|cff00d9ffWarband World Quest|r")
			)

			Settings:CreateOptionsTree("log_section_completed_shown", logMenu, L["settings_section_text"]:format(CRITERIA_COMPLETED), {
				{ text = L["settings_section_completed_option_all_text"], tooltip = L["settings_section_completed_option_all_tooltip"], value = "ALL" },
				{
					text = L["settings_section_completed_option_current_text"],
					tooltip = L["settings_section_completed_option_current_tooltip"],
					value = "CURRENT",
				},
			}, L["settings_section_completed_tooltip"], MenuResponse.Refresh)

			Settings:CreateCheckboxMenu(
				"log_all_quests_shown",
				logMenu,
				L["settings_log_all_quests_shown_text"],
				nil,
				L["settings_log_all_quests_shown_tooltip"]
			)

			logMenu:CreateDivider()
			logMenu:CreateTitle(L["settings_log_section_fields"])

			Settings:CreateCheckboxMenu(
				"log_scanning_icon_shown",
				logMenu,
				L["settings_log_scanning_icon_shown_text"],
				nil,
				L["settings_log_scanning_icon_shown_tooltip"]:format("|A:common-icon-undo:10:10:0:0|a")
			)

			Settings:CreateCheckboxMenu("log_time_left_shown", logMenu, CLOSES_IN, nil, L["settings_log_time_left_shown_tooltip"])

			Settings:CreateOptionsTree(
				"log_warband_rewards_shown",
				logMenu,
				RENOWN_REWARD_ACCOUNT_UNLOCK_LABEL,
				{ "NOT_COLLECTED", "TOTAL" },
				L["settings_log_warband_rewards_shown_tooltip"],
				MenuResponse.Refresh
			)

			Settings:CreateOptionsTree("log_progress_shown", logMenu, L["settings_log_progress_shown_text"], {
				{ text = L["settings_log_progress_shown_option_1_text"], tooltip = L["settings_log_progress_shown_option_1_tooltip"], value = "CLAIMED" },
				{
					text = L["settings_log_progress_shown_option_2_text"],
					tooltip = L["settings_log_progress_shown_option_2_tooltip"],
					value = "REMAINING",
				},
			}, L["settings_log_progress_shown_tooltip"], MenuResponse.Refresh)
		end

		do -- Maps
			local function GetMapName(mapID)
				return C_Map.GetMapInfo(mapID).name
			end

			Settings:CreateMenuTree("maps_to_scan", rootMenu, L["settings_maps_title"], GetMapName, MenuResponse.CloseAll)
		end

		rootMenu:CreateDivider()

		do -- Quests Filter
			rootMenu:CreateTitle(L["settings_filters_title"])

			local allTypes = {}
			for key, rewardType in pairs(QuestRewards.RewardTypes:GetAll(not Settings:Get("maps_to_scan")[1550])) do
				table.insert(allTypes, {
					index = key,
					priority = format("%s%s", rewardType.texture and 1 or 0, rewardType.name or rewardType.texture),
					text = (rewardType.texture and format("|T%d:14|t ", rewardType.texture) or "") .. (rewardType.name or LFG_LIST_LOADING),
					tooltip = { itemID = rewardType.item, currencyID = rewardType.currency },
				})
			end

			Settings:CreateMenuTree("reward_type_filters", rootMenu, nil, allTypes)
		end
	end)
end
