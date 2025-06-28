local addonName, ns = ...

local L = ns.L
local Util = ns.Util
local QuestRewards = ns.QuestRewards
local WorldQuestList = ns.WorldQuestList
local CharacterStore = ns.CharacterStore
local Settings = ns.Settings

WarbandWorldQuestNextResetButtonMixin = {}

function WarbandWorldQuestNextResetButtonMixin:OnLoad()
	self.settingsKey = "next_reset_exclude_types"

	self:SetupMenu(function(_, rootMenu)
		rootMenu:CreateTitle(L["next_reset_dropdown_exclude_types"])

		Settings:CreateCheckboxMenu(self.settingsKey, rootMenu, SHOW_PET_BATTLES_ON_MAP_TEXT, Enum.QuestTagType.PetBattle)
		Settings:CreateCheckboxMenu(self.settingsKey, rootMenu, DRAGONRIDING_RACES_MAP_TOGGLE, Enum.QuestTagType.DragonRiderRacing)
	end)

	Settings:InvokeAndRegisterCallback(self.settingsKey, self.Update, self)
end

function WarbandWorldQuestNextResetButtonMixin:Update()
	local quests, resetTime = WorldQuestList:NextResetQuests(Settings:Get(self.settingsKey))

	self.ButtonText:SetText(L["next_reset_button_text"]:format(resetTime and date("%m-%d %H:%M", resetTime) or UNKNOWN, #quests))

	self:SetWidth(self.ButtonText:GetStringWidth())
end

function WarbandWorldQuestNextResetButtonMixin:OnEnter()
	local quests, resetTime = WorldQuestList:NextResetQuests(Settings:Get(self.settingsKey))
	local tooltip = GetAppropriateTooltip()

	tooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	tooltip:SetText(L["next_reset_tooltip_title"], WHITE_FONT_COLOR:GetRGB())
	tooltip:AddLine(
		AUCTION_HOUSE_TIME_LEFT_FORMAT_ACTIVE:format(resetTime and Util.FormatTimeDuration(resetTime - GetServerTime()) or UNKNOWN),
		NORMAL_FONT_COLOR:GetRGB()
	)
	tooltip:AddLine(" ")
	tooltip:AddLine(L["next_reset_tooltip_quest_num"]:format(#quests), NORMAL_FONT_COLOR:GetRGB())

	for _, quest in ipairs(quests) do
		local icon = CreateAtlasMarkup(QuestUtil.GetWorldQuestAtlasInfo(quest.ID, C_QuestLog.GetQuestTagInfo(quest.ID)))

		tooltip:AddDoubleLine(
			format("|cnWHITE_FONT_COLOR:%s %s|r", icon, quest:GetName()),
			EVENT_SCHEDULER_LOCATION_COLOR_CODE .. C_Map.GetMapInfo(quest.map).name .. "|r"
		)
	end

	tooltip:Show()
end

function WarbandWorldQuestNextResetButtonMixin:OnLeave()
	GetAppropriateTooltip():Hide()
end

WarbandWorldQuestCharactersButtonMixin = {}

function WarbandWorldQuestCharactersButtonMixin:OnLoad()
	Settings:InvokeAndRegisterCallback("next_reset_exclude_types", self.Update, self)
	CharacterStore:RegisterCallback("CharacterStore.CharacterStateChanged", self.Update, self)

	self:SetupMenu(function(_, rootMenu)
		rootMenu:CreateTitle(L["characters_dropdown_title"])

		local function CharactersFilter(character)
			return not CharacterStore.IsCurrentPlayer(character)
		end

		local characterStore = CharacterStore.Get()
		characterStore:ForEach(function(character)
			local checkbox = rootMenu:CreateCheckbox(character:GetNameInClassColor(), function()
				return not character.enabled
			end)

			checkbox:SetResponder(function(data, menuInputData, menu)
				if IsControlKeyDown() then
					self:RemoveCharacter(character)
					return MenuResponse.CloseAll
				else
					characterStore:SetCharacterEnabled(character, not character.enabled)
					return MenuResponse.Refresh
				end
			end)
		end, CharactersFilter)

		rootMenu:CreateSpacer()
		rootMenu:CreateTitle(GREEN_FONT_COLOR:WrapTextInColorCode(L["characters_dropdown_instruction"]:format("CTRL + |A:NPE_LeftClick:16:16|a")))
	end)
end

function WarbandWorldQuestCharactersButtonMixin:RemoveCharacter(character)
	Util:Debug("Removing character:", character.name)

	StaticPopup_ShowGenericConfirmation(CONFIRM_COMPACT_UNIT_FRAME_PROFILE_DELETION:format(character:GetNameInClassColor()), function()
		CharacterStore:Get():RemoveCharacter(character.GUID)
	end)
end

function WarbandWorldQuestCharactersButtonMixin:Update()
	local scanned, pending = self:PopulateCharactersData()

	self.ButtonText:SetText(format("%s %d/%d", CreateAtlasMarkup("common-icon-undo", 16, 16), #scanned, #pending + #scanned))
end

function WarbandWorldQuestCharactersButtonMixin:PopulateCharactersData()
	local fullilled = {}
	local pending = {}

	local resetStartTime = WorldQuestList:GetResetStartTime(Settings:Get("next_reset_exclude_types"))

	CharacterStore.Get():ForEach(function(character)
		local scanned = character.updatedAt > resetStartTime
		local state = CreateAtlasMarkup(scanned and "checkmark-minimal" or "common-icon-undo", 15, 15)

		table.insert(scanned and fullilled or pending, { character, state })
	end)

	if not CharacterStore.Get():CurrentPlayer().enabled then
		table.insert(fullilled, 1, { CharacterStore.Get():CurrentPlayer(), CreateAtlasMarkup("checkmark-minimal-disabled", 15, 15) })
	end

	return fullilled, pending
end

function WarbandWorldQuestCharactersButtonMixin:OnEnter()
	local scanned, pending = self:PopulateCharactersData()
	local tooltip = GetAppropriateTooltip()
	local resetStartTime = WorldQuestList:GetResetStartTime(Settings:Get("next_reset_exclude_types"))

	tooltip:SetOwner(self, "ANCHOR_BOTTOM")
	tooltip:SetText(L["characters_tooltip_title"], WHITE_FONT_COLOR:GetRGB())
	tooltip:AddLine(L["characters_tooltip_last_reset_time"]:format(date("%m-%d %H:%M", resetStartTime)), NORMAL_FONT_COLOR:GetRGB())

	for groupName, records in pairs({ [NOT_COLLECTED] = pending, [COLLECTED] = scanned }) do
		tooltip:AddLine(" ")
		tooltip:AddLine(format("|cnNORMAL_FONT_COLOR:%s:|r |cnWHITE_FONT_COLOR:%d|r", groupName, #records))
		for _, record in ipairs(records) do
			local character, state = unpack(record)
			tooltip:AddDoubleLine(
				state .. " " .. character:GetNameInClassColor(),
				WHITE_FONT_COLOR_CODE .. CURRENCY_TRANSFER_LOG_TIME_FORMAT:format(Util.FormatLastUpdateTime(character.updatedAt)) .. "|r"
			)
		end
	end

	tooltip:Show()
end

function WarbandWorldQuestCharactersButtonMixin:OnLeave()
	GetAppropriateTooltip():Hide()
end

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

			Settings:CreateCheckboxMenu("pins_progress_shown", pinsMenu, L["settings_pins_progress_label_shown_text"])

			Settings:CreateOptionsTree(
				"pins_tooltip_shown",
				pinsMenu,
				L["settings_pins_tooltip_progress_shown_text"],
				{ { text = ALWAYS, value = "" }, { text = CTRL_KEY, value = "CTRL" }, { text = ALT_KEY, value = "ALT" } },
				L["settings_pins_tooltip_progress_shown_tooltip"],
				MenuResponse.Refresh
			)

			pinsMenu:CreateCheckbox(
				L["settings_pins_continent_maps_shown_text"],
				Settings:GenerateComparator("pins_min_display_level", Enum.UIMapType.Continent),
				Settings:GenerateRotator("pins_min_display_level", { Enum.UIMapType.Continent, Enum.UIMapType.Zone })
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

			Settings:CreateCheckboxMenu(
				"log_scanning_icon_shown",
				logMenu,
				L["settings_log_scanning_icon_shown_text"],
				nil,
				L["settings_log_scanning_icon_shown_tooltip"]:format("|A:common-icon-undo:10:10:0:0|a")
			)

			Settings:CreateCheckboxMenu("log_time_left_shown", logMenu, CLOSES_IN, nil, L["settings_log_time_left_shown_tooltip"])
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

WarbandWorldQuestHeaderMixin = {}

function WarbandWorldQuestHeaderMixin:Init(elementData)
	self.ButtonText:SetText(format("%s (%d)", elementData.name, elementData.numQuests))
	self.CollapseButton:UpdateCollapsedState(elementData.isCollapsed)

	self.data = elementData
end

function WarbandWorldQuestHeaderMixin:OnLoad()
	self:CheckHighlightTitle(false)
	self:SetPushedTextOffset(1, -1)
end

function WarbandWorldQuestHeaderMixin:OnClick(button)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	if button == "LeftButton" then
		Settings:GenerateTableToggler("group_collapsed_states")(self.data.index)
	elseif button == "RightButton" then
	end
end

function WarbandWorldQuestHeaderMixin:OnEnter()
	self:CheckHighlightTitle(true)
	if self.CollapseButton then
		self.CollapseButton:LockHighlight()
	end
end

function WarbandWorldQuestHeaderMixin:OnLeave()
	self:CheckHighlightTitle(false)
	if self.CollapseButton then
		self.CollapseButton:UnlockHighlight()
	end
end

function WarbandWorldQuestHeaderMixin:GetTitleRegion()
	return self.ButtonText or self.Text
end

function WarbandWorldQuestHeaderMixin:GetTitleColor(useHighlight)
	return useHighlight and HIGHLIGHT_FONT_COLOR or DISABLED_FONT_COLOR
end

function WarbandWorldQuestHeaderMixin:IsTruncated()
	return self:GetTitleRegion():IsTruncated()
end

function WarbandWorldQuestHeaderMixin:CheckHighlightTitle(isMouseOver)
	local color = self:GetTitleColor(isMouseOver)
	self:GetTitleRegion():SetTextColor(color:GetRGB())
end

function WarbandWorldQuestHeaderMixin:OnMouseDown()
	local pressed = true
	if self.Text then
		self.Text:AdjustPointsOffset(1, -1)
	end
	self.CollapseButton:UpdatePressedState(pressed)
end

function WarbandWorldQuestHeaderMixin:OnMouseUp()
	local pressed = false
	if self.Text then
		self.Text:AdjustPointsOffset(-1, 1)
	end
	self.CollapseButton:UpdatePressedState(pressed)
end

WarbandWorldQuestEntryMixin = {}
WarbandWorldQuestEntryMixin.MaxNameWidth = 205

function WarbandWorldQuestEntryMixin:Init(elementData)
	self.data = elementData

	self.Name:SetText(elementData.quest:GetName())
	self.TimeLeft:SetText(self:FormatTimeLeft(elementData))
	self.Rewards:SetText(elementData.aggregatedRewards:Summary())

	self.Background:SetShown(elementData.isActive or elementData.quest:IsInactive())
	self.IconButton:Update(elementData.quest.ID)

	self:UpdateStatus()
	self:UpdateProgress()
	self:UpdateLocation()
	self:AdjustHeight()
end

function WarbandWorldQuestEntryMixin:UpdateStatus()
	local text = ""

	if Settings:Get("log_scanning_icon_shown") and self.data.progress.unknown > 0 then
		text = text .. " " .. CreateAtlasMarkup("common-icon-undo", 10, 10)
	end

	if self.data.quest:IsTracked() then
		text = text .. " " .. CreateAtlasMarkup("questlog-icon-checkmark-yellow", 11, 11)
	end

	self.Status:SetTextToFit(text)

	self.Name:SetWidth(min(self.Name:GetUnboundedStringWidth(), self.MaxNameWidth - self.Status:GetWidth()))
end

function WarbandWorldQuestEntryMixin:UpdateProgress()
	self.Progress:SetText(format("|c%s%d/%d|r", self.data:GetProgressColor(), self.data.progress.claimed, self.data.progress.total))
end

function WarbandWorldQuestEntryMixin:UpdateLocation(mapID)
	local location = C_Map.GetMapInfo(self.data.quest.map).name

	mapID = mapID or WorldMapFrame:GetMapID()
	self.Location:SetText(mapID == self.data.quest.map and YELLOW_FONT_COLOR:WrapTextInColorCode(location) or location)
end

function WarbandWorldQuestEntryMixin:FormatTimeLeft(elementData)
	return Settings:Get("log_time_left_shown") and Util.FormatTimeDuration(elementData.quest.resetTime - GetServerTime()) .. " - " or ""
end

function WarbandWorldQuestEntryMixin:AdjustHeight()
	if self.data.isRewardsTextOverlapped then
		self.Rewards:SetPoint("TOP", self.TimeLeft, "BOTTOM", 0, -5)
	else
		self.Rewards:SetPoint("TOP", self.TimeLeft, "TOP", 0, 0)
	end
end

function WarbandWorldQuestEntryMixin:ToggleTracked()
	PlaySound(tracked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	self.data.quest:SetTracked(not self.data.quest:IsTracked())
	self:UpdateStatus()
end

function WarbandWorldQuestEntryMixin:OnShow()
	if self.data then
		self:UpdateProgress()
	end

	EventRegistry:RegisterCallback("MapCanvas.MapSet", self.UpdateLocation, self)
end

function WarbandWorldQuestEntryMixin:OnHide()
	EventRegistry:UnregisterCallback("MapCanvas.MapSet", self)
end

function WarbandWorldQuestEntryMixin:OnEnter()
	self:UpdateTooltip()
	self.owner:HighlightMapPin(self.data.quest.ID, true)
end

function WarbandWorldQuestEntryMixin:OnLeave()
	GetAppropriateTooltip():Hide()
	self.owner:HighlightMapPin(self.data.quest.ID, false)
end

function WarbandWorldQuestEntryMixin:OnClick(button)
	local quest = self.data.quest

	if button == "LeftButton" then
		if IsShiftKeyDown() then
			ChatEdit_TryInsertQuestLinkForQuestID(quest.ID)
		else
			C_Map.OpenWorldMap(quest.map)
		end
	elseif button == "RightButton" then
		MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
			rootDescription:SetTag("MENU_QUEST_MAP_WARBAND_WORLD_QUEST")

			local watchType = C_QuestLog.GetQuestWatchType(quest.ID)
			local isTracked = quest:IsTracked()

			rootDescription:CreateButton(isTracked and UNTRACK_QUEST or TRACK_QUEST, GenerateClosure(self.ToggleTracked, self))

			if C_SuperTrack.GetSuperTrackedQuestID() ~= quest.ID then
				rootDescription:CreateButton(SUPER_TRACK_QUEST, function()
					C_SuperTrack.SetSuperTrackedQuestID(quest.ID)
					if watchType ~= Enum.QuestWatchType.Manual then
						QuestUtil.TrackWorldQuest(quest.ID, Enum.QuestWatchType.Automatic)
					end
				end)
			else
				rootDescription:CreateButton(STOP_SUPER_TRACK_QUEST, function()
					C_SuperTrack.SetSuperTrackedQuestID(0)
				end)
			end

			local isInactive = quest:IsInactive()
			if self.data.isActive or isInactive then
				rootDescription:CreateButton((isInactive and CANCEL .. ": " or "") .. MOVE_TO_INACTIVE, function()
					quest:SetInactive(not isInactive)
					self.owner:Refresh()
				end)
			end
		end)
	end
end

function WarbandWorldQuestEntryMixin:UpdateTooltip()
	local quest = self.data.quest

	local tooltip = GetAppropriateTooltip()

	tooltip:SetOwner(self, "ANCHOR_RIGHT")
	tooltip:SetText(quest:GetName(), 1, 1, 1)
	tooltip:AddLine(AUCTION_HOUSE_TIME_LEFT_FORMAT_ACTIVE:format(Util.FormatTimeDuration(quest.resetTime - GetServerTime())), NORMAL_FONT_COLOR:GetRGB())

	tooltip:AddLine(" ")
	tooltip:AddLine(L["log_entry_tooltip_characters_scanned"] .. format(": |cnWHITE_FONT_COLOR:%d|r", self.data.progress.total - self.data.progress.unknown))
	tooltip:AddLine(L["log_entry_tooltip_characters_completed"] .. format(": |cnWHITE_FONT_COLOR:%d|r", self.data.progress.claimed))
	for _, character in self.owner.dataProvider:EnumerateCharacters() do
		local rewards = character:GetRewards(quest.ID)

		local state = CreateAtlasMarkup(rewards == nil and "common-icon-undo" or rewards:IsClaimed() and "common-icon-checkmark" or "common-icon-redx", 15, 15)

		tooltip:AddDoubleLine(
			Util.WrapTextInClassColor(character.class, format("%s %s - %s", state, character.name, character.realmName)),
			rewards and format("|c%s%s|r", self.data:GetProgressColor(character, WHITE_FONT_COLOR), rewards:Summary()) or ""
		)
	end

	tooltip:AddLine(" ")
	tooltip:AddLine(L["log_entry_tooltip_total_rewards"])
	for _, reward in ipairs(self.data.aggregatedRewards:Summary(true)) do
		tooltip:AddLine(reward, 1, 1, 1)
	end

	tooltip:Show()
end

WarbandWorldQuestIconButtonMixin = {}

function WarbandWorldQuestIconButtonMixin:OnMouseDown()
	self.Display:SetPoint("CENTER", 1, -1)
end

function WarbandWorldQuestIconButtonMixin:OnMouseUp()
	self.Display:SetPoint("CENTER")

	self:GetParent():ToggleTracked()
end

function WarbandWorldQuestIconButtonMixin:Update(questID)
	local tag = C_QuestLog.GetQuestTagInfo(questID)

	self.Display:SetAtlas(QuestUtil.GetWorldQuestAtlasInfo(questID, tag))

	if tag.worldQuestType == Enum.QuestTagType.Capstone then
		self.Underlay:SetAtlas("worldquest-Capstone-Banner", true)
	elseif tag.isElite then
		self.Underlay:SetAtlas("worldquest-questmarker-dragon", true)
	else
		self.Underlay:SetAtlas(nil)
	end
end

WarbandWorldQuestTabButtonMixin = CreateFromMixins(QuestLogTabButtonMixin)

function WarbandWorldQuestTabButtonMixin:OnLoad()
	self.Icon:SetTexture(format("Interface/AddOns/%s/UI/Icon.blp", addonName))
	self.Icon:SetSize(24, 24)
	self:SetPoint("TOP", QuestMapFrame.TabButtons[#QuestMapFrame.TabButtons - 1], "BOTTOM", 0, -3)
	self:SetChecked(false)
end

function WarbandWorldQuestTabButtonMixin:SetChecked(checked)
	self.SelectedTexture:SetShown(checked)
end

function WarbandWorldQuestTabButtonMixin:OnMouseUp(button, upInside)
	QuestLogTabButtonMixin.OnMouseUp(self, button, upInside)
	if button == "LeftButton" and upInside then
		QuestMapFrame:SetDisplayMode(self.displayMode)
	end
end

WarbandWorldQuestPageMixin = {}

function WarbandWorldQuestPageMixin:OnLoad()
	local indent = 0
	local topPadding = 3
	local bottomPadding = 15
	local leftPadding = 8
	local rightPadding = 5
	local elementSpacing = 3
	local view = CreateScrollBoxListTreeListView(indent, topPadding, bottomPadding, leftPadding, rightPadding, elementSpacing)

	view:SetElementFactory(function(factory, data)
		local function Initializer(frame)
			frame.owner = self
			frame:Init(data)
		end

		local template = data.isHeader and "WarbandWorldQuestHeaderTemplate" or "WarbandWorldQuestEntryTemplate"

		factory(template, Initializer)
	end)

	view:SetElementIndentCalculator(function(elementData)
		return elementData.isHeader and -2 or 0
	end)

	view:SetElementExtentCalculator(function(dataIndex, elementData)
		if elementData.isHeader then
			return 22
		elseif self:IsRewardsTextOverlapped(elementData) then
			elementData.isRewardsTextOverlapped = true
			return 56
		else
			elementData.isRewardsTextOverlapped = false
			return 39
		end
	end)

	ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)

	self.pinsHooked = {}

	CharacterStore:RegisterCallback("CharacterStore.CharacterStateChanged", self.Refresh, self, true)
end

function WarbandWorldQuestPageMixin:OnShow()
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("QUEST_TURNED_IN")

	WorldMapFrame:RegisterCallback("WorldQuestsUpdate", self.OnMapUpdate, self)
	Settings:RegisterCallback("reward_type_filters", self.Refresh, self)
	Settings:RegisterCallback("group_collapsed_states", self.Refresh, self)
	Settings:RegisterCallback("log_scanning_icon_shown", self.Refresh, self, true)
	Settings:RegisterCallback("log_time_left_shown", self.Refresh, self, true)
end

function WarbandWorldQuestPageMixin:OnHide()
	self:UnregisterEvent("QUEST_LOG_UPDATE")
	self:UnregisterEvent("QUEST_TURNED_IN")

	WorldMapFrame:UnregisterCallback("WorldQuestsUpdate", self)
	Settings:UnregisterCallback("reward_type_filters", self)
	Settings:UnregisterCallback("group_collapsed_states", self)
	Settings:UnregisterCallback("log_scanning_icon_shown", self)
	Settings:UnregisterCallback("log_time_left_shown", self)
end

function WarbandWorldQuestPageMixin:OnEvent(event)
	if event == "QUEST_LOG_UPDATE" then
		self.CharactersButton:Update()
		self.NextResetButton:Update()
		self.SettingsDropdown:Update()
	else
		self:Refresh(true)
	end
end

function WarbandWorldQuestPageMixin:IsRewardsTextOverlapped(elementData)
	if self.RewardsText == nil then
		self.RewardsText = self:CreateFontString()
		self.RewardsText:SetFontObject("GameFontNormalSmall")
	end

	self.RewardsText:SetText(
		WarbandWorldQuestEntryMixin:FormatTimeLeft(elementData) .. C_Map.GetMapInfo(elementData.quest.map).name .. elementData.aggregatedRewards:Summary()
	)

	return self.RewardsText:GetStringWidth() > WarbandWorldQuestEntryMixin.MaxNameWidth + 35
end

function WarbandWorldQuestPageMixin:OnMapUpdate()
	if self.highlightQuest then
		self:HighlightMapPin(self.highlightQuest, true)
	end
end

function WarbandWorldQuestPageMixin:SetDataProvider(dataProvider)
	self.dataProvider = dataProvider
	self:Refresh()
end

function WarbandWorldQuestPageMixin:HighlightMapPin(questID, shown)
	local pin = self.dataProvider:FindPinByQuestID(questID)
	if pin == nil then
		self.highlightQuest = shown and questID or nil
		return
	end

	pin:ChangeSelected(shown)
	self.highlightPin = shown and pin or nil
	self.highlightQuest = nil

	if self.pinsHooked[pin] == nil then
		hooksecurefunc(pin, "RefreshVisuals", function(pin)
			if pin == self.highlightPin then
				pin:ChangeSelected(true)
			end
		end)
	end
end

function WarbandWorldQuestPageMixin:HighlightRow(questID, shown)
	local frame = self.ScrollBox:FindFrameByPredicate(function(frame)
		return frame.data.quest and frame.data.quest.ID == questID
	end)

	if frame == nil or not frame:IsShown() then
		return
	end

	frame:SetDrawLayerEnabled("HIGHLIGHT", shown)
end

function WarbandWorldQuestPageMixin:Refresh(frameOnShow)
	for groupIndex, isCollapsed in pairs(Settings:Get("group_collapsed_states")) do
		self.dataProvider:UpdateGroupState(groupIndex, isCollapsed)
	end

	if self.dataProvider:Reset() then
		self.LoadingFrame:Hide()
	end

	self.ScrollBox:SetDataProvider(self.dataProvider, frameOnShow and ScrollBoxConstants.RetainScrollPosition or ScrollBoxConstants.DiscardScrollPosition)
end
