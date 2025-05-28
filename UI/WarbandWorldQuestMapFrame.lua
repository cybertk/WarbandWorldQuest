local addonName, ns = ...

local Util = ns.Util
local QuestRewards = ns.QuestRewards
local WorldQuestList = ns.WorldQuestList
local CharacterStore = ns.CharacterStore

WarbandWorldQuestNextResetButtonMixin = {}

function WarbandWorldQuestNextResetButtonMixin:OnLoad()
	self:Update()
end

function WarbandWorldQuestNextResetButtonMixin:Update()
	local quests, resetTime = WorldQuestList:NextResetQuests()

	self.ButtonText:SetText(format("Next Reset: %s (%d)", resetTime and date("%m-%d %H:%M", resetTime) or UNKNOWN, #quests))
end

function WarbandWorldQuestNextResetButtonMixin:OnEnter()
	local quests, resetTime = WorldQuestList:NextResetQuests()
	local tooltip = GetAppropriateTooltip()

	tooltip:SetOwner(self, "ANCHOR_BOTTOM")
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
	self:Update()
end

function WarbandWorldQuestCharactersButtonMixin:Update()
	local scanned, pending = self:PopulateCharactersData()

	self.ButtonText:SetText(format("%s %d/%d", CreateAtlasMarkup("common-icon-undo", 16, 16), #scanned, #pending + #scanned))
end

function WarbandWorldQuestCharactersButtonMixin:PopulateCharactersData()
	local fullilled = {}
	local pending = {}

	CharacterStore.Get():ForEach(function(character)
		local scanned = WarbandWorldQuestDB.resetStartTime and character.updatedAt > WarbandWorldQuestDB.resetStartTime
		local state = CreateAtlasMarkup(scanned and "common-icon-checkmark" or "common-icon-undo", 15, 15)

		table.insert(scanned and fullilled or pending, { character, state })
	end)

	return fullilled, pending
end

function WarbandWorldQuestCharactersButtonMixin:OnEnter()
	local scanned, pending = self:PopulateCharactersData()
	local tooltip = GetAppropriateTooltip()

	tooltip:SetOwner(self, "ANCHOR_BOTTOM")
	tooltip:SetText("Characters Scanned", 1, 1, 1)
	tooltip:AddLine(format("|cnNORMAL_FONT_COLOR:Last Reset Time:|r |cnWHITE_FONT_COLOR:%s|r", date("%m-%d %H:%M", WarbandWorldQuestDB.resetStartTime)))

	for groupName, records in pairs({ ["Pending"] = pending, ["Scanned"] = scanned }) do
		tooltip:AddLine(" ")
		tooltip:AddLine(format("|cnNORMAL_FONT_COLOR:%s:|r |cnWHITE_FONT_COLOR:%d|r", groupName, #records))
		for _, record in ipairs(records) do
			local character, state = unpack(record)
			tooltip:AddDoubleLine(
				Util.WrapTextInClassColor(character.class, format("%s %s - %s", state, character.name, character.realmName)),
				Util.FormatLastUpdateTime(character.updatedAt),
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
		if WarbandWorldQuestSettings.groups[self.data.index] == nil then
			WarbandWorldQuestSettings.groups[self.data.index] = {}
		end
		WarbandWorldQuestSettings.groups[self.data.index].isCollapsed = not self.data.isCollapsed

		self.owner:Refresh()
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

	self.TimeLeft:SetText(self:FormatTimeLeft(elementData))
	self.Rewards:SetText(elementData.aggregatedRewards:Summary())

	self.Background:SetShown(elementData.isActive or elementData.quest:IsInactive())

	self:UpdateName()
	self:UpdateProgress()
	self:AdjustHeight()
end

function WarbandWorldQuestEntryMixin:UpdateName()
	local text = self.data.quest:GetName()

	if self.data.quest:IsTracked() then
		text = text .. format(" %s", CreateAtlasMarkup("questlog-icon-checkmark-yellow", 11, 11))
	end

	self.Name:SetText(text)
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
			OpenWorldMap(quest.map)
		end
	elseif button == "RightButton" then
		local function SetQuestTracked(tracked)
			PlaySound(tracked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			quest:SetTracked(tracked)
			self:UpdateName()
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
	CharacterStore.Get():ForEach(function(character)
		local rewards = character:GetRewards(quest.ID)

		local state = CreateAtlasMarkup(rewards == nil and "common-icon-undo" or rewards:IsClaimed() and "common-icon-checkmark" or "common-icon-redx", 15, 15)

		tooltip:AddDoubleLine(
			Util.WrapTextInClassColor(character.class, format("%s %s - %s", state, character.name, character.realmName)),
			rewards and format("|c%s%s|r", self.data:GetProgressColor(character, WHITE_FONT_COLOR), rewards:Summary()) or ""
		)
	end)

	tooltip:AddLine(" ")
	tooltip:AddLine("Warband Rewards:")
	for _, reward in ipairs(self.data.aggregatedRewards:Summary(true)) do
		tooltip:AddLine(reward, 1, 1, 1)
	end

	tooltip:Show()
end

WarbandWorldQuestTabButtonMixin = CreateFromMixins(QuestLogTabButtonMixin)

function WarbandWorldQuestTabButtonMixin:OnLoad()
	self.NormalTexture:SetTexture(format("Interface/AddOns/%s/UI/Icon.blp", addonName))
	self:SetPoint("TOP", QuestMapFrame.MapLegendTab, "BOTTOM", 0, -3)
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
	self.LoadingFrame:Hide()
end

function WarbandWorldQuestPageMixin:OnShow()
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("QUEST_TURNED_IN")
	WorldMapFrame:RegisterCallback("WorldQuestsUpdate", self.OnMapUpdate, self)

	self:Refresh()
end

function WarbandWorldQuestPageMixin:OnHide()
	self:UnregisterEvent("QUEST_LOG_UPDATE")
	self:UnregisterEvent("QUEST_TURNED_IN")
	WorldMapFrame:UnregisterCallback("WorldQuestsUpdate", self)
end

function WarbandWorldQuestPageMixin:OnEvent(event)
	if event == "QUEST_LOG_UPDATE" then
		self.CharactersButton:Update()
		self.NextResetButton:Update()
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

function WarbandWorldQuestPageMixin:UpdateFilters()
	self.SettingsDropdown:SetupMenu(function(_, rootMenu)
		rootMenu:CreateTitle("Settings")

		local mapPinsMenu = rootMenu:CreateButton("Map Pins")
		mapPinsMenu:CreateCheckbox("Show Progress", function()
			return WarbandWorldQuestSettings.showProgressOnPin
		end, function()
			WarbandWorldQuestSettings.showProgressOnPin = not WarbandWorldQuestSettings.showProgressOnPin
			self.dataProvider:SetProgressOnPinShown(WarbandWorldQuestSettings.showProgressOnPin)
		end)

		mapPinsMenu:CreateCheckbox("Show Pins on the Continent Maps", function()
			return WarbandWorldQuestSettings.minPinDisplayLevel == Enum.UIMapType.Continent
		end, function()
			WarbandWorldQuestSettings.minPinDisplayLevel = WarbandWorldQuestSettings.minPinDisplayLevel == Enum.UIMapType.Continent and Enum.UIMapType.Zone
				or Enum.UIMapType.Continent
			self.dataProvider:SetMinPinDisplayLevel(WarbandWorldQuestSettings.minPinDisplayLevel)
		end)

		rootMenu:CreateTitle("Rewards Filter")

		for i, rewardType in ipairs(QuestRewards.RewardTypes) do
			local title = (rewardType.texture and format("|T%d:14|t ", rewardType.texture) or "") .. (rewardType.name or LFG_LIST_LOADING)
			local typeButton = rootMenu:CreateCheckbox(title, function()
				return bit.band(2 ^ (i - 1), WarbandWorldQuestSettings.rewardTypeFilters) ~= 0
			end, function()
				WarbandWorldQuestSettings.rewardTypeFilters = bit.bxor(WarbandWorldQuestSettings.rewardTypeFilters, 2 ^ (i - 1))

				self:Refresh()
			end)
		end
	end)
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

function WarbandWorldQuestPageMixin:Refresh(frameOnShow)
	self:UpdateFilters()

	self.dataProvider:SetProgressOnPinShown(WarbandWorldQuestSettings.showProgressOnPin)
	self.dataProvider:SetRewardTypeFilters(WarbandWorldQuestSettings.rewardTypeFilters)

	for groupIndex, group in pairs(WarbandWorldQuestSettings.groups) do
		self.dataProvider:UpdateGroupState(groupIndex, group.isCollapsed)
	end

	self.dataProvider:Reset()

	self.ScrollBox:SetDataProvider(self.dataProvider, frameOnShow and ScrollBoxConstants.RetainScrollPosition or ScrollBoxConstants.DiscardScrollPosition)
end
