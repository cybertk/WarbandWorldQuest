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

	if CharacterStore.Get():GetNumEnabledCharacters() == 1 then
		nop()
	elseif self.dataProvider.progressTextOption == "CLAIMED" then
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

	self.dataProvider.activeRows[self.quest.ID] = self.isActive and self or nil

	return wasFocused ~= self.isActive
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

local WarbandWorldQuestDataProviderMixin = CreateFromMixins(DataProviderMixin)

function WarbandWorldQuestDataProviderMixin:OnLoad()
	self.rows = {}
	self.filteredRows = {}
	self.questsOnMap = {}
	self.activeRows = {}
	self.groupState = {}
	self.shouldPopulateData = true
	self.rewardFilters = {}
	self.filterUncollectedRewards = true

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
	self.filteredRows = {}
	self.activeRows = {}
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

function WarbandWorldQuestDataProviderMixin:SetProgressTextOption(option)
	self.progressTextOption = option
end

function WarbandWorldQuestDataProviderMixin:SetFilterUncollectedRewards(enabled)
	self.filterUncollectedRewards = enabled
end

function WarbandWorldQuestDataProviderMixin:SetShouldShowAllQuests(enabled)
	self.shouldShowAllQuests = enabled
end

function WarbandWorldQuestDataProviderMixin:SetShouldPopulateData(shouldPopulateData)
	self.shouldPopulateData = shouldPopulateData
	Util:Debug("Queued PopulateCharactersData", shouldPopulateData)

	if not self:IsEmpty() then
		self:Flush()
	end
end

function WarbandWorldQuestDataProviderMixin:FilterRows()
	local map = Util:GetBestMap(WorldMapFrame:GetMapID(), Enum.UIMapType.Zone)
	if #self.filteredRows > 0 and map.mapID == self.lastFilteredMap then
		Util:Debug("Skip filtering", map.name)
		return
	end

	wipe(self.filteredRows)

	for _, row in ipairs(self.rows) do
		if #row.quest:GetPositionOnMap(map.mapID) > 0 then
			table.insert(self.filteredRows, row)
		end
	end

	self.lastFilteredMap = map.mapID
end

function WarbandWorldQuestDataProviderMixin:Reset()
	self:PopulateCharactersData()

	if #self.rows == 0 then
		return
	end

	local rows = self.rows
	if not self.shouldShowAllQuests then
		self:FilterRows()
		rows = self.filteredRows
	end

	local groups = {
		FOCUSED = 1,
		{ rows = {}, virtual = true, index = 1, uncollapsible = true },
		COMPLETED = 2,
		{ name = CRITERIA_COMPLETED, rows = {}, virtual = self.questCompleteOption == nil },
		INACTIVE = 3,
		{ name = FACTION_INACTIVE, rows = {} },
	}

	for _, row in ipairs(rows) do
		row:UpdateFocused()

		if row:IsFlaggedCompleted() then
			table.insert(groups[groups.COMPLETED].rows, row)
		elseif row.isActive then
			table.insert(groups[groups.FOCUSED].rows, row)
		else
			table.insert(groups[groups.INACTIVE].rows, row)
		end
	end

	wipe(self.collection)
	for i, group in ipairs(groups) do
		local isCollapsed = not group.uncollapsible and self.groupState[i]

		if not group.virtual then
			table.insert(self.collection, { isHeader = true, isCollapsed = isCollapsed, name = group.name, index = i, numQuests = #group.rows })
		end

		for _, row in ipairs(isCollapsed and {} or group.rows) do
			table.insert(self.collection, row)
		end
	end

	self:TriggerEvent(self.Event.OnSizeChanged)

	return true
end

function WarbandWorldQuestDataProviderMixin:IsFilteredQuest(questID)
	return self.activeRows[questID] ~= nil
end

function WarbandWorldQuestDataProviderMixin:EnumerateActiveQuestsByMapID(mapID, includeCompleted, completedOnly)
	self.questsOnMap[mapID] = {}

	for _, row in pairs(self.activeRows) do
		local quest = row.quest
		local matched = true
		if not includeCompleted and quest:IsCompleted() then
			matched = false
		elseif completedOnly and not quest:IsCompleted() then
			matched = false
		end

		if matched then
			local position = quest:GetPositionOnMap(mapID)

			if #position > 0 then
				self.questsOnMap[mapID][position] = row
			end
		end
	end

	return self.questsOnMap[mapID]
end

function WarbandWorldQuestDataProviderMixin:FindByQuestID(questID, isActiveOnly)
	if isActiveOnly then
		return self.activeRows[questID]
	end

	for _, row in ipairs(self.rows) do
		if (not isActiveOnly or row.isActive) and row.quest and row.quest.ID == questID then
			return row
		end
	end
end

function WarbandWorldQuestDataProviderMixin:UpdatePinTooltip(tooltip, pin)
	local questID = pin.questID
	if not WorldQuestList:IsActiveQuest(questID) then
		return
	end

	local offset = 0
	if tooltip.ItemTooltip and tooltip.ItemTooltip:IsShown() then
		tooltip = tooltip.ItemTooltip.Tooltip
		offset = -38 -- GameTooltip.ItemTooltip.x(10) + InternalEmbeddedItemTooltipTemplate.x(28)
	end

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

ns.WarbandWorldQuestDataProviderMixin = WarbandWorldQuestDataProviderMixin
