local _, ns = ...

local Util = ns.Util
local CharacterStore = ns.CharacterStore
local WorldQuestList = ns.WorldQuestList
local QuestRewards = ns.QuestRewards

local WarbandWorldQuestDataRowMixin = {}

function WarbandWorldQuestDataRowMixin:GetProgressColor(character, defaultColor)
	if not self.isActive then
		return GRAY_FONT_COLOR:GenerateHexColor()
	end

	character = character or CharacterStore.Get():CurrentPlayer()

	local color
	local rewards = character:GetRewards(self.quest.ID)

	if rewards == nil then
		color = GRAY_FONT_COLOR
	elseif rewards:IsClaimed() then
		color = GREEN_FONT_COLOR
	elseif
		not rewards:PassRewardTypeFilters(self.dataProvider.rewardFiltersMask) and not (self.progress.eligible == 1 and CharacterStore.IsCurrentPlayer(character))
	then
		color = RED_FONT_COLOR
	else
		color = defaultColor or YELLOW_FONT_COLOR
	end

	return color:GenerateHexColor()
end

function WarbandWorldQuestDataRowMixin:GetProgressText()
	local text = ""

	if self.dataProvider.progressTextOption == "CLAIMED" then
		if self.progress.claimed == 0 and self.progress.eligible == 0 then
			text = "-"
		else
			text = format("|c%s%d/%d|r", self:GetProgressColor(), self.progress.claimed, self.progress.eligible)
		end
	elseif self.dataProvider.progressTextOption == "REMAINING" then
		text = format("|c%s%d|r", self:GetProgressColor(), self.progress.eligible - self.progress.claimed)
	end

	return text
end

function WarbandWorldQuestDataRowMixin:UpdateFocused()
	local wasFocused = self.isActive or false
	local rewards = self.dataProvider.filterUncollectedRewards and self.uncollectedRewards or self.totalRewards

	if not self.quest:IsInactive() and rewards:PassRewardTypeFilters(self.dataProvider.rewardFiltersMask) then
		self.isActive = true
	else
		self.isActive = false
	end

	if wasFocused == self.isActive then
		return
	end

	if self.isActive then
		table.insert(self.dataProvider.activeQuests, self.quest)
	else
		tDeleteItem(self.dataProvider.activeQuests, self.quest)
	end

	return true
end

function WarbandWorldQuestDataRowMixin:IsFlaggedCompleted(questCompletedForPlayer)
	local option = self.dataProvider.questCompleteOption

	if option == "ALL" then
		return self.progress.eligible > 0 and self.progress.eligible == self.progress.claimed
	elseif questCompletedForPlayer and option == "CURRENT" then
		return true
	elseif option == "CURRENT" then
		return C_QuestLog.IsQuestFlaggedCompleted(self.quest.ID)
	else
		return false
	end
end

function WarbandWorldQuestDataRowMixin:UpdateRemainingRewards(claimed)
	local rewards = {}
	local numClaimed = 0

	for character, reward in pairs(self.rewards) do
		if not reward:IsClaimed() then
			rewards[character] = reward
		else
			numClaimed = numClaimed + 1
		end
	end

	self.uncollectedRewards = QuestRewards:Aggregate(rewards)
	if not claimed and not self.quest:IsFirstCompletionBonusClaimed() then
		self.uncollectedRewards:AddFirstCompletionBonus(self.quest.currencies)
	end
	self.progress.claimed = numClaimed
end

WarbandWorldQuestDataProviderMixin = CreateFromMixins(DataProviderMixin, WorldMap_WorldQuestDataProviderMixin)

function WarbandWorldQuestDataProviderMixin:OnLoad()
	self.rows = {}
	self.questsOnMap = {}
	self.activeProgress = {}
	self.progressFrames = {}
	self.activeQuests = {}
	self.groupState = {}
	self.shouldPopulateData = true
	self.rewardFilters = {}
	self.filterUncollectedRewards = true

	self.minPinDisplayLevel = Enum.UIMapType.Continent
	self.maxPinDisplayLevel = Enum.UIMapType.Zone

	self:Init()
end

function WarbandWorldQuestDataProviderMixin:EnumerateCharacters()
	return CreateTableEnumerator(CharacterStore.Get():ForEach(nop, function(character)
		return CharacterStore.IsCurrentPlayer(character) or character.enabled
	end))
end

function WarbandWorldQuestDataProviderMixin:UpdateEligibleCharactersData()
	Util:Debug("Update Eligible Characters Data")

	for _, row in ipairs(self.rows) do
		local quest, progress = row.quest, row.progress

		progress.eligible = 0
		progress.claimed = 0

		for _, reward in pairs(row.rewards) do
			if reward:PassRewardTypeFilters(self.rewardFiltersMask) then
				progress.eligible = progress.eligible + 1

				if reward:IsClaimed() then
					progress.claimed = progress.claimed + 1
				end
			end
		end

		if progress.eligible == 0 and row.totalRewards:PassRewardTypeFilters(self.rewardFiltersMask) then
			progress.eligible = 1

			if quest:IsFirstCompletionBonusClaimed() then
				progress.claimed = 1
			end
		end
	end
end

function WarbandWorldQuestDataProviderMixin:PopulateCharactersData()
	if not self.shouldPopulateData then
		return
	end

	Util:Debug("Populating Characters Data")

	local rows = {}

	for _, quest in ipairs(WorldQuestList:GetAllQuests()) do
		local rewards = {}
		local progress = { total = 0, unknown = 0, claimed = 0 }

		for _, character in self:EnumerateCharacters() do
			rewards[character] = character.rewards[quest.ID]

			if rewards[character] == nil then
				progress.unknown = progress.unknown + 1
			end

			progress.total = progress.total + 1
		end

		local row = { quest = quest, rewards = rewards, progress = progress, totalRewards = QuestRewards:Aggregate(rewards) }
		row.dataProvider = self
		row.totalRewards:AddFirstCompletionBonus(quest.currencies)
		row.totalRewards:PassRewardTypeFilters(0)
		Mixin(row, WarbandWorldQuestDataRowMixin)
		row:UpdateRemainingRewards()

		table.insert(rows, row)
	end

	self.rows = rows
	self.activeQuests = {}
	self.rewardFiltersMask = QuestRewards.RewardTypes:GenerateMask(self.rewardFilters)
	self:UpdateEligibleCharactersData()

	self.shouldPopulateData = false
end

function WarbandWorldQuestDataProviderMixin:UpdateRewardsClaimed(questID)
	local row = self:FindByQuestID(questID, false)
	if row == nil then
		Util:Debug("Cannot UpdateRewardsClaimed", questID)
		return
	end

	local groupChanged = false

	row:UpdateRemainingRewards(true)
	if row:UpdateFocused() or row:IsFlaggedCompleted(true) then
		groupChanged = true
	end

	Util:Debug("Updated rewards progress", questID, row.quest:GetName(), groupChanged)

	return groupChanged
end

function WarbandWorldQuestDataProviderMixin:UpdateGroupState(groupIndex, isCollapsed)
	self.groupState[groupIndex] = isCollapsed
end

function WarbandWorldQuestDataProviderMixin:UpdateRewardTypeFilters(filters)
	MergeTable(self.rewardFilters, filters)

	local newMask = QuestRewards.RewardTypes:GenerateMask(self.rewardFilters)
	if newMask == self.rewardFiltersMask then
		return
	end

	self.rewardFiltersMask = newMask
	self:UpdateEligibleCharactersData()

	Util:Debug("RewardTypeFilters updated", self.rewardFiltersMask)
end

function WarbandWorldQuestDataProviderMixin:SetQuestCompleteOption(option)
	self.questCompleteOption = option
end

function WarbandWorldQuestDataProviderMixin:SetProgressOnPinShown(shown)
	self.showProgressOnPin = shown
end

function WarbandWorldQuestDataProviderMixin:SetProgressTextOption(option)
	self.progressTextOption = option
end

function WarbandWorldQuestDataProviderMixin:SetMinPinDisplayLevel(uiMapType)
	self.minPinDisplayLevel = uiMapType
end

function WarbandWorldQuestDataProviderMixin:SetPinOfCompletedQuestShown(shown)
	self.showPinOfCompletedQuest = shown
end

function WarbandWorldQuestDataProviderMixin:SetFilterUncollectedRewards(enabled)
	self.filterUncollectedRewards = enabled
end

function WarbandWorldQuestDataProviderMixin:SetShouldPopulateData(shouldPopulateData)
	self.shouldPopulateData = shouldPopulateData
	Util:Debug("Queued PopulateCharactersData")
end

function WarbandWorldQuestDataProviderMixin:Reset()
	self:PopulateCharactersData()

	if #self.rows == 0 then
		return
	end

	local groups = {
		FOCUSED = 1,
		{ rows = {}, virtual = true, index = 1 },
		COMPLETED = 2,
		{ name = CRITERIA_COMPLETED, rows = {}, virtual = self.questCompleteOption == nil },
		INACTIVE = 3,
		{ name = FACTION_INACTIVE, rows = {} },
	}

	for _, row in ipairs(self.rows) do
		row:UpdateFocused()

		if row:IsFlaggedCompleted() then
			table.insert(groups[groups.COMPLETED].rows, row)
		elseif row.isActive then
			table.insert(groups[groups.FOCUSED].rows, row)
		else
			table.insert(groups[groups.INACTIVE].rows, row)
		end
	end

	local rows = {}
	for i, group in ipairs(groups) do
		local isCollapsed = self.groupState[i] or false

		if not group.virtual then
			table.insert(rows, { isHeader = true, isCollapsed = isCollapsed, name = group.name, index = i, numQuests = #group.rows })
		end

		for _, row in ipairs(isCollapsed and {} or group.rows) do
			table.insert(rows, row)
		end
	end

	self:Init(rows)

	return true
end

function WarbandWorldQuestDataProviderMixin:EnumerateActiveQuestsByMapID(mapID, includeCompleted, completedOnly)
	self.questsOnMap[mapID] = {}

	for i, quest in ipairs(self.activeQuests) do
		local matched = true
		if not includeCompleted and quest:IsCompleted() then
			matched = false
		elseif completedOnly and not quest:IsCompleted() then
			matched = false
		end

		if matched then
			local position = {}

			local mapGroup = C_Map.GetMapGroupID(quest.map)
			if (mapGroup and mapGroup == C_Map.GetMapGroupID(mapID)) or mapID == quest.map then
				position = { quest.x, quest.y }
			else
				position = quest:GetPositionOnMap(mapID)
			end

			if #position > 0 then
				self.questsOnMap[mapID][position] = quest
			end
		end
	end

	return self.questsOnMap[mapID]
end

function WarbandWorldQuestDataProviderMixin:FindByQuestID(questID, isActiveOnly)
	for _, row in ipairs(self.rows) do
		if (not isActiveOnly or row.isActive) and row.quest and row.quest.ID == questID then
			return row
		end
	end
end

function WarbandWorldQuestDataProviderMixin:FindPinByQuestID(questID)
	local function MatchPin(pin)
		return pin.questID == questID
	end

	for pin in self:EnumeratePinsByPredicate(MatchPin) do
		return pin
	end
end

function WarbandWorldQuestDataProviderMixin:UpdatePinTooltip(tooltip, pin)
	local questID = pin.questID
	if not WorldQuestList:IsActiveQuest(questID) then
		return
	end

	if tooltip.ItemTooltip and tooltip.ItemTooltip:IsShown() then
		tooltip.ItemTooltip.Tooltip:GetLeft()

		local embeddedLeft, left = tooltip.ItemTooltip.Tooltip:GetLeft(), tooltip:GetLeft()
		if embeddedLeft and left then
			self.tooltipPadding = embeddedLeft - left
		end
		tooltip = tooltip.ItemTooltip.Tooltip
	else
		self.tooltipPadding = 0
	end

	local offset = self.tooltipPadding and -self.tooltipPadding or 0

	tooltip:AddLine(" ")
	tooltip:AddLine("Warband Progress", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, false, offset)

	for _, character in self:EnumerateCharacters() do
		local rewards = character:GetRewards(questID)
		local state = CreateAtlasMarkup(rewards == nil and "common-icon-undo" or rewards:IsClaimed() and "common-icon-checkmark" or "common-icon-redx", 15, 15)

		tooltip:AddDoubleLine(
			Util.WrapTextInClassColor(character.class, format("%s %s - %s", state, character.name, character.realmName)),
			rewards and rewards:Summary(),
			NORMAL_FONT_COLOR.r,
			NORMAL_FONT_COLOR.g,
			NORMAL_FONT_COLOR.b,
			WHITE_FONT_COLOR.r,
			WHITE_FONT_COLOR.g,
			WHITE_FONT_COLOR.b,
			false,
			offset
		)
	end

	tooltip:Show()
end

function WarbandWorldQuestDataProviderMixin:UpdatePinProgress(pin)
	local updated = false
	local row = self:FindByQuestID(pin.questID, true)

	if row then
		local progress = self.progressFrames[pin]
		if progress == nil then
			progress = pin:CreateFontString(nil, "OVERLAY")
			progress:SetPoint("TOP", pin, "BOTTOM", 0, -1)
			progress:SetFontObject("SystemFont_Shadow_Small_Outline")

			self.progressFrames[pin] = progress
		end

		progress:SetText(row:GetProgressText())
		progress:Show()

		updated = true
	end

	return updated
end

function WarbandWorldQuestDataProviderMixin:EnumeratePinsByPredicate(predicate)
	local pins = {}

	for _, template in ipairs({ self:GetPinTemplate(), WorldMap_WorldQuestDataProviderMixin:GetPinTemplate() }) do
		for pin in self:GetMap():EnumeratePinsByTemplate(template) do
			if predicate(pin) then
				table.insert(pins, pin)
			end
		end
	end

	local index = 0

	local function Enumerator(tbl)
		index = index + 1
		if index <= #tbl then
			local value = tbl[index]
			if value ~= nil then
				return value
			end
		end
	end

	return Enumerator, pins
end

function WarbandWorldQuestDataProviderMixin:UpdateAllPinsProgress()
	local framesToRemove = {}
	for pin in pairs(self.progressFrames) do
		framesToRemove[pin] = true
	end

	if self.showProgressOnPin then
		for pin in self:EnumeratePinsByPredicate(GenerateClosure(self.UpdatePinProgress, self)) do
			framesToRemove[pin] = nil
		end
	end

	for pin in pairs(framesToRemove) do
		self.progressFrames[pin]:Hide()
	end
end

function WarbandWorldQuestDataProviderMixin:RefreshAllData()
	local pinsToRemove = {}
	for questID in pairs(self.activePins) do
		pinsToRemove[questID] = true
	end

	local mapCanvas = self:GetMap()
	local mapID = mapCanvas:GetMapID()
	local mapType = C_Map.GetMapInfo(mapID).mapType

	local quests = (mapType < self.minPinDisplayLevel or mapType > self.maxPinDisplayLevel) and {}
		or self:EnumerateActiveQuestsByMapID(mapID, self.showPinOfCompletedQuest, mapType == Enum.UIMapType.Zone)

	for position, quest in pairs(quests) do
		local pin = self.activePins[quest.ID]

		if pin then
			pin:RefreshVisuals()
			pin:SetPosition(unpack(position))
			pin:AddIconWidgets()
		else
			pin = self:AddWorldQuest(quest:GetQuestPOIMapInfo())
			pin:SetPosition(unpack(position))
			self.activePins[quest.ID] = pin

			Util:Debug("Added pin for quest", quest.ID, quest:GetName(), mapID)
		end
		pin.CompletedIndicator:SetShown(quest:IsCompleted())

		pinsToRemove[quest.ID] = nil
	end

	for questID in pairs(pinsToRemove) do
		mapCanvas:RemovePin(self.activePins[questID])
		self.activePins[questID] = nil
	end

	self:UpdateAllPinsProgress()
end

function WarbandWorldQuestDataProviderMixin:GetPinTemplate()
	return "WarbandWorldQuestPinTemplate"
end

WarbandWorldQuestPinMixin = CreateFromMixins(WorldQuestPinMixin)

function WarbandWorldQuestPinMixin:CheckMouseButtonPassthrough(...) end

hooksecurefunc(WorldMapFrame, "RegisterPin", function(mapCanvas, pin)
	if pin.CheckMouseButtonPassthrough ~= nop then
		pin.CheckMouseButtonPassthrough = nop
		pin.UpdateMousePropagation = nop
	end
end)
