local addonName, ns = ...

local Util = ns.Util
local QuestRewards = ns.QuestRewards
local WorldQuestList = ns.WorldQuestList
local CharacterStore = ns.CharacterStore
local Settings = ns.Settings

WarbandWorldQuestNextResetButtonMixin = {}

function WarbandWorldQuestNextResetButtonMixin:OnLoad()
	self.settingsKey = "next_reset_exclude_types"

	self:SetupMenu(function(_, rootMenu)
		rootMenu:CreateTitle("Exclude World Quest Types")

		Settings:CreateCheckboxMenu(self.settingsKey, rootMenu, SHOW_PET_BATTLES_ON_MAP_TEXT, Enum.QuestTagType.PetBattle)
		Settings:CreateCheckboxMenu(self.settingsKey, rootMenu, DRAGONRIDING_RACES_MAP_TOGGLE, Enum.QuestTagType.DragonRiderRacing)
	end)

	Settings:InvokeAndRegisterCallback(self.settingsKey, self.Update, self)
end

function WarbandWorldQuestNextResetButtonMixin:Update()
	local quests, resetTime = WorldQuestList:NextResetQuests(Settings:Get(self.settingsKey))

	self.ButtonText:SetText(format("Next Reset: %s (%d)", resetTime and date("%m-%d %H:%M", resetTime) or UNKNOWN, #quests))

	self:SetWidth(self.ButtonText:GetStringWidth())
end

function WarbandWorldQuestNextResetButtonMixin:OnEnter()
	local quests, resetTime = WorldQuestList:NextResetQuests(Settings:Get(self.settingsKey))
	local tooltip = GetAppropriateTooltip()

	tooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	tooltip:SetText("Upcomming Reset of World Quests", 1, 1, 1)
	tooltip:AddLine(
		format("|cnNORMAL_FONT_COLOR:Time Left:|r |cnWHITE_FONT_COLOR:%s|r", resetTime and Util.FormatTimeDuration(resetTime - GetServerTime()) or UNKNOWN)
	)
	tooltip:AddLine(" ")
	tooltip:AddLine(format("|cnNORMAL_FONT_COLOR:Quests Count:|r |cnWHITE_FONT_COLOR:%d|r", #quests))
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
		rootMenu:CreateTitle("Exclude Characters")

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
		rootMenu:CreateTitle("|cnGREEN_FONT_COLOR:Press CTRL + |A:NPE_LeftClick:16:16|a to delete the character|r")
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
	tooltip:SetText("Characters Scanned", 1, 1, 1)
	tooltip:AddLine(format("|cnNORMAL_FONT_COLOR:Last Reset Time:|r |cnWHITE_FONT_COLOR:%s|r", date("%m-%d %H:%M", resetStartTime)))

	for groupName, records in pairs({ ["Pending"] = pending, ["Scanned"] = scanned }) do
		tooltip:AddLine(" ")
		tooltip:AddLine(format("|cnNORMAL_FONT_COLOR:%s:|r |cnWHITE_FONT_COLOR:%d|r", groupName, #records))
		for _, record in ipairs(records) do
			local character, state = unpack(record)
			tooltip:AddDoubleLine(
				state .. " " .. character:GetNameInClassColor(),
				CURRENCY_TRANSFER_LOG_TIME_FORMAT:format(Util.FormatLastUpdateTime(character.updatedAt)),
				1,
				1,
				1,
				1,
				1,
				1
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

function WarbandWorldQuestSettingsButtonMixin:OnShow()
	self:Update()
end

function WarbandWorldQuestSettingsButtonMixin:Update()
	if not self:IsShown() then
		return
	end

	self:SetupMenu(function(_, rootMenu)
		rootMenu:CreateTitle("Settings")

		do -- Map Pins
			local pinsMenu = rootMenu:CreateButton("Map Pins")

			Settings:CreateCheckboxMenu("pins_progress_shown", pinsMenu, "Show Warband Progress on Pins")

			do -- Show Warband Progress in Tooltip
				local tooltipMenu = Settings:CreateCheckboxMenu("pins_tooltip_shown", pinsMenu, "Show Warband Progress in Tooltip")

				local options = {
					["Always"] = false,
					["Press CTRL"] = "CTRL",
					["Press ALT"] = "ALT",
				}
				for description, mode in pairs(options) do
					local radio = Settings:CreateRadio("pins_tooltip_modifier", tooltipMenu, description, mode or nil)

					radio:SetResponse(MenuResponse.Refresh)
					radio:SetEnabled(Settings:GenerateGetter("pins_tooltip_shown"))
				end
			end

			pinsMenu:CreateCheckbox(
				"Show Pins on the Continent Maps",
				Settings:GenerateComparator("pins_min_display_level", Enum.UIMapType.Continent),
				Settings:GenerateRotator("pins_min_display_level", { Enum.UIMapType.Continent, Enum.UIMapType.Zone })
			)

			Settings:CreateCheckboxMenu("pins_completed_shown", pinsMenu, "Show Pins for Completed Quests")
		end

		do -- Quest Log
			local logMenu = rootMenu:CreateButton("World Quest Log")

			Settings:CreateCheckboxMenu(
				"log_is_default_tab",
				logMenu,
				"Default Tab",
				nil,
				"Set |cff00d9ffWarband World Quest|r as the default tab, it opens automatically when opening the World Map for the first time after logging in"
			)

			Settings:CreateCheckboxMenu(
				"log_scanning_icon_shown",
				logMenu,
				"Show Pending Scan Icon",
				nil,
				"Display an icon |A:common-icon-undo:10:10:0:0|a in the quest title if the quest progress hasn't been scanned on all tracked characters"
			)
		end

		do -- Rewards Filter
			rootMenu:CreateTitle("Rewards Filter")

			for i, rewardType in ipairs(QuestRewards.RewardTypes) do
				local title = (rewardType.texture and format("|T%d:14|t ", rewardType.texture) or "") .. (rewardType.name or LFG_LIST_LOADING)
				rootMenu:CreateCheckbox(title, function()
					return bit.band(2 ^ (i - 1), Settings:Get("reward_type_filters")) ~= 0
				end, function()
					Settings:Set("reward_type_filters", bit.bxor(Settings:Get("reward_type_filters"), 2 ^ (i - 1)))
				end)
			end
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

function WarbandWorldQuestEntryMixin:Init(elementData)
	self.data = elementData

	self.Name:SetText(elementData.quest:GetName())
	self.TimeLeft:SetText(self:FormatTimeLeft(elementData))
	self.Rewards:SetText(elementData.aggregatedRewards:Summary())

	self.Background:SetShown(elementData.isActive or elementData.quest:IsInactive())

	self:UpdateStatus()
	self:UpdateProgress()
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

	self.Name:SetWidth(min(self.Name:GetUnboundedStringWidth(), 220 - self.Status:GetWidth()))
end

function WarbandWorldQuestEntryMixin:UpdateProgress()
	self.Progress:SetText(format("|c%s%d/%d|r", self.data:GetProgressColor(), self.data.progress.claimed, self.data.progress.total))
end

function WarbandWorldQuestEntryMixin:FormatTimeLeft(elementData)
	return Util.FormatTimeDuration(elementData.quest.resetTime - GetServerTime()) .. " - " .. C_Map.GetMapInfo(elementData.quest.map).name
end

function WarbandWorldQuestEntryMixin:AdjustHeight()
	if self.data.isRewardsTextOverlapped then
		self.Rewards:SetPoint("TOP", self.TimeLeft, "BOTTOM", 0, -5)
	else
		self.Rewards:SetPoint("TOP", self.TimeLeft, "TOP", 0, 0)
	end
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
		local function SetQuestTracked(tracked)
			PlaySound(tracked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			quest:SetTracked(tracked)
			self:UpdateStatus()
		end

		MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
			rootDescription:SetTag("MENU_QUEST_MAP_WARBAND_WORLD_QUEST")

			local watchType = C_QuestLog.GetQuestWatchType(quest.ID)
			local isTracked = quest:IsTracked()

			rootDescription:CreateButton(isTracked and UNTRACK_QUEST or TRACK_QUEST, GenerateClosure(SetQuestTracked, not isTracked))

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
	tooltip:AddLine(format("|cnNORMAL_FONT_COLOR:Time Left:|r |cnWHITE_FONT_COLOR:%s|r", Util.FormatTimeDuration(quest.resetTime - GetServerTime())))

	tooltip:AddLine(" ")
	tooltip:AddLine(format("Characters Scanned: |cnWHITE_FONT_COLOR:%d|r", self.data.progress.total - self.data.progress.unknown))
	tooltip:AddLine(format("Characters Completed: |cnWHITE_FONT_COLOR:%d|r", self.data.progress.claimed))
	for _, character in self.owner.dataProvider:EnumerateCharacters() do
		local rewards = character:GetRewards(quest.ID)

		local state = CreateAtlasMarkup(rewards == nil and "common-icon-undo" or rewards:IsClaimed() and "common-icon-checkmark" or "common-icon-redx", 15, 15)

		tooltip:AddDoubleLine(
			Util.WrapTextInClassColor(character.class, format("%s %s - %s", state, character.name, character.realmName)),
			rewards and format("|c%s%s|r", self.data:GetProgressColor(character, WHITE_FONT_COLOR), rewards:Summary()) or ""
		)
	end

	tooltip:AddLine(" ")
	tooltip:AddLine("Warband Rewards:")
	for _, reward in ipairs(self.data.aggregatedRewards:Summary(true)) do
		tooltip:AddLine(reward, 1, 1, 1)
	end

	tooltip:Show()
end

WarbandWorldQuestTabButtonMixin = CreateFromMixins(QuestLogTabButtonMixin)

function WarbandWorldQuestTabButtonMixin:OnLoad()
	self.Icon:SetTexture(format("Interface/AddOns/%s/UI/Icon.blp", addonName))
	self.Icon:SetSize(24, 24)
	self:SetPoint("TOP", QuestMapFrame.MapLegendTab, "BOTTOM", 0, -3)
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
end

function WarbandWorldQuestPageMixin:OnShow()
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("QUEST_TURNED_IN")

	WorldMapFrame:RegisterCallback("WorldQuestsUpdate", self.OnMapUpdate, self)
	CharacterStore:RegisterCallback("CharacterStore.CharacterStateChanged", self.Refresh, self, true)
	Settings:RegisterCallback("reward_type_filters", self.Refresh, self)
	Settings:RegisterCallback("group_collapsed_states", self.Refresh, self)
	Settings:RegisterCallback("log_scanning_icon_shown", self.Refresh, self, true)

	self:Refresh()
end

function WarbandWorldQuestPageMixin:OnHide()
	self:UnregisterEvent("QUEST_LOG_UPDATE")
	self:UnregisterEvent("QUEST_TURNED_IN")

	WorldMapFrame:UnregisterCallback("WorldQuestsUpdate", self)
	CharacterStore:UnregisterCallback("CharacterStore.CharacterStateChanged", self)
	Settings:UnregisterCallback("reward_type_filters", self)
	Settings:UnregisterCallback("group_collapsed_states", self)
	Settings:UnregisterCallback("log_scanning_icon_shown", self)
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

	self.RewardsText:SetText(WarbandWorldQuestEntryMixin:FormatTimeLeft(elementData) .. elementData.aggregatedRewards:Summary())

	return self.RewardsText:GetStringWidth() + 50 > self:GetWidth()
end

function WarbandWorldQuestPageMixin:OnMapUpdate()
	if self.highlightQuest then
		self:HighlightMapPin(self.highlightQuest, true)
	end
end

function WarbandWorldQuestPageMixin:SetDataProvider(dataProvider)
	self.dataProvider = dataProvider
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
	self.dataProvider:SetRewardTypeFilters(Settings:Get("reward_type_filters"))

	for groupIndex, isCollapsed in pairs(Settings:Get("group_collapsed_states")) do
		self.dataProvider:UpdateGroupState(groupIndex, isCollapsed)
	end

	if self.dataProvider:Reset() then
		self.LoadingFrame:Hide()
	end

	self.ScrollBox:SetDataProvider(self.dataProvider, frameOnShow and ScrollBoxConstants.RetainScrollPosition or ScrollBoxConstants.DiscardScrollPosition)
end
