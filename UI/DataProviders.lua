local _, ns = ...

local Util = ns.Util
local CharacterStore = ns.CharacterStore
local WorldQuestList = ns.WorldQuestList
local WarbandRewardList = ns.WarbandRewardList
local QuestRewards = ns.QuestRewards

local WarbandWorldQuestDataRowMixin = {}

function WarbandWorldQuestDataRowMixin:GetProgressColor(character, defaultColor)
	character = character or CharacterStore.Get():CurrentPlayer()

	if not self.isActive then
		return GRAY_FONT_COLOR:GenerateHexColor()
	end

	local color
	local rewards = character:GetRewards(self.quest.ID)

	if self.quest.faction and self.quest.faction ~= character.factionGroup then
		color = RED_FONT_COLOR
	elseif rewards == nil then
		color = GRAY_FONT_COLOR
	elseif rewards:IsClaimed() then
		color = GREEN_FONT_COLOR
	elseif not rewards:PassRewardTypeFilters(self.dataProvider.rewardFiltersMask) then
		color = RED_FONT_COLOR
	else
		color = defaultColor or YELLOW_FONT_COLOR
	end

	return color:GenerateHexColor()
end

function WarbandWorldQuestDataRowMixin:UpdateRemainingRewards()
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
	self.progress.claimed = numClaimed
end

local WarbandWorldQuestDataProviderMixin = CreateFromMixins(DataProviderMixin, QuestDataProviderMixin)
WarbandQuestTrackerDataProviderMixin = WarbandWorldQuestDataProviderMixin

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

	self.activePins = {}

	self.minPinDisplayLevel = Enum.UIMapType.Continent
	self.maxPinDisplayLevel = Enum.UIMapType.Zone

	self:Init()
end

function WarbandWorldQuestDataProviderMixin:EnumerateCharacters(predicate)
	return CreateTableEnumerator(CharacterStore.Get():ForEach(nop, function(character)
		return (CharacterStore.IsCurrentPlayer(character) or character.enabled) and (predicate == nil or predicate(character))
	end))
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
		local factionNameToEnum = { ["Alliance"] = 1, ["Horde"] = 2 }

		for _, character in self:EnumerateCharacters() do
			if quest.faction == nil or quest.faction == character.factionGroup then
				rewards[character] = character.rewards[quest.ID]

				if rewards[character] == nil then
					progress.unknown = progress.unknown + 1
				elseif rewards[character]:IsClaimed() then
					progress.claimed = progress.claimed + 1
				end

				progress.total = progress.total + 1
			end
		end

		local row = { quest = quest, rewards = rewards, progress = progress, totalRewards = QuestRewards:Aggregate(rewards) }
		row.dataProvider = self
		row.totalRewards:PassRewardTypeFilters(0)
		Mixin(row, WarbandWorldQuestDataRowMixin)
		row:UpdateRemainingRewards()

		table.insert(rows, row)
	end

	table.sort(rows, function(x, y)
		return C_Map.GetMapInfo(x.quest.map).name < C_Map.GetMapInfo(y.quest.map).name
	end)

	self.rows = rows
	self.rewardFiltersMask = QuestRewards.RewardTypes:GenerateMask(self.rewardFilters)
	self.shouldPopulateData = false
end

function WarbandWorldQuestDataProviderMixin:UpdateRewardsClaimed(questID)
	local row = self:FindByQuestID(questID, false)
	if row == nil then
		Util:Debug("Cannot UpdateRewardsClaimed", questID)
		return
	end

	row:UpdateRemainingRewards()

	if self.filterUncollectedRewards and row.isActive and not row.uncollectedRewards:PassRewardTypeFilters(self.rewardFiltersMask) then
		if #self.headers then
			local header = self.headers[#self.headers]

			header.numQuests = header.numQuests + 1
			header.dirty = true
			Util:Debug("Updated Inactive numQuests:", header.numQuests)
		end

		if self.groupState[2] then
			self:Remove(row)
		else
			self:MoveElementDataToIndex(row)
		end

		for i, quest in ipairs(self.activeQuests) do
			if quest == row.quest then
				table.remove(self.activeQuests, i)
				Util:Debug("Removed active quest:", quest.ID)
				break
			end
		end
	else
		row.dirty = true
	end

	Util:Debug("Updated rewards progress", questID, row.quest:GetName())
end

function WarbandWorldQuestDataProviderMixin:UpdateGroupState(groupIndex, isCollapsed)
	self.groupState[groupIndex] = isCollapsed
end

function WarbandWorldQuestDataProviderMixin:UpdateRewardTypeFilters(filters)
	MergeTable(self.rewardFilters, filters)

	self.rewardFiltersMask = QuestRewards.RewardTypes:GenerateMask(self.rewardFilters)
	Util:Debug("RewardTypeFilters updated", self.rewardFiltersMask)
end

function WarbandWorldQuestDataProviderMixin:SetProgressOnPinShown(shown)
	self.showProgressOnPin = shown
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
end

function WarbandWorldQuestDataProviderMixin:Reset()
	self:PopulateCharactersData()

	self.activeQuests = {}
	self.headers = {}

	if #self.rows == 0 then
		return
	end

	local groups = { continents = {} }
	function groups:GetOrCreate(mapID)
		local map = Util:GetContinentMap(mapID)

		if self.continents[map.mapID] == nil then
			self.continents[map.mapID] = { name = map.name, rows = {} }
			table.insert(groups, self.continents[map.mapID])
		end

		return self.continents[map.mapID]
	end

	for _, row in ipairs(self.rows) do
		row.isActive = true
		table.insert(groups:GetOrCreate(row.quest.map).rows, row)
		table.insert(self.activeQuests, row.quest)
	end

	local rows = {}
	for i, group in ipairs(groups) do
		local isCollapsed = self.groupState[i] or false

		if not group.virtual then
			table.insert(rows, { isHeader = true, isCollapsed = isCollapsed, name = group.name, index = i, numQuests = #group.rows })
			table.insert(self.headers, rows[#rows])
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
	local index, row = self:FindByPredicate(function(row)
		return (not isActiveOnly or row.isActive) and row.quest and row.quest.ID == questID
	end)

	return row
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
	local quest = WorldQuestList:GetQuest(questID)
	if not quest then
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
	local excludeFaction = function(character)
		return quest.faction == nil or quest.faction == character.factionGroup
	end

	tooltip:AddLine(" ")
	tooltip:AddLine("Warband Progress", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, false, offset)

	for _, character in self:EnumerateCharacters(excludeFaction) do
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

		progress:SetText(format("|c%s%d/%d|r", row:GetProgressColor(), row.progress.claimed, row.progress.total))
		progress:Show()

		updated = true
	end

	return updated
end

function WarbandWorldQuestDataProviderMixin:EnumeratePinsByPredicate(predicate)
	local pins = {}

	for _, template in ipairs({ self:GetPinTemplate() }) do
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
		or self:EnumerateActiveQuestsByMapID(mapID, self.showPinOfCompletedQuest, false)

	for position, quest in pairs(quests) do
		local pin = self.activePins[quest.ID]

		if pin then
			-- pin:RefreshVisuals()
			pin:SetPosition(unpack(position))
			pin:AddIconWidgets()
		else
			pin = self:AddQuest(quest:GetQuestPOIMapInfo())
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
	return "WarbandQuestTrackerPinTemplate"
end

local WarbandWorldQuestPinMixin = CreateFromMixins(QuestPinMixin)
WarbandQuestTrackerPinMixin = WarbandWorldQuestPinMixin

function WarbandWorldQuestPinMixin:CheckMouseButtonPassthrough(...) end

function WarbandWorldQuestPinMixin:OnClick()
	local quest = WorldQuestList:GetQuest(self.questID)
	if C_Map.CanSetUserWaypointOnMap(quest.map) then
		local pos = C_Map.GetPlayerMapPosition(quest.map, "player")
		local mapPoint = UiMapPoint.CreateFromCoordinates(quest.map, quest.x, quest.y)
		C_Map.SetUserWaypoint(mapPoint)
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)

		WarbandWorldQuestPinMixin.waypointQuest = quest
	else
		print("Cannot set waypoints on this map")
	end
end

hooksecurefunc(WorldMapFrame, "RegisterPin", function(mapCanvas, pin)
	if pin.CheckMouseButtonPassthrough ~= nop then
		pin.CheckMouseButtonPassthrough = nop
		pin.UpdateMousePropagation = nop
	end
end)

local WarbandRewardDataRowMixin = {}

function WarbandRewardDataRowMixin:GetProgressColor(character, defaultColor)
	character = character or CharacterStore.Get():CurrentPlayer()

	if not self.isActive then
		return GRAY_FONT_COLOR:GenerateHexColor()
	end

	local color
	local rewards = character:GetRewards(self.quest.ID)

	if self.quest.faction and self.quest.faction ~= character.factionGroup then
		color = RED_FONT_COLOR
	elseif rewards == nil then
		color = GRAY_FONT_COLOR
	elseif rewards:IsClaimed() then
		color = GREEN_FONT_COLOR
	elseif not rewards:PassRewardTypeFilters(self.dataProvider.rewardFiltersMask) then
		color = RED_FONT_COLOR
	else
		color = defaultColor or YELLOW_FONT_COLOR
	end

	return color:GenerateHexColor()
end

function WarbandRewardDataRowMixin:UpdateRemainingRewards()
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
	self.progress.claimed = numClaimed
end

-- ID, difficulty, pending[], fulfilled[], unknown[]
local WarbandEncounterColumnMixin = {}

function WarbandEncounterColumnMixin:Init() end

WarbandRewardsTrackerDataProviderMixin = CreateFromMixins(WarbandWorldQuestDataProviderMixin)

-- function WarbandRewardsTrackerDataProviderMixin:OnLoad() end

function WarbandRewardsTrackerDataProviderMixin:RefreshAllData() end

function WarbandRewardsTrackerDataProviderMixin:PopulateCharactersData()
	if not self.shouldPopulateData then
		return
	end

	Util:Debug("Populating Characters Data")

	local rows = {}
	for _, reward in WarbandRewardList:EnumerateAll() do
		local encounters = {}
		local numUniqueEncounters = {}

		for difficultyID, sharedDifficulties in pairs(reward:GetClaimableDifficulties()) do
			sharedDifficulties = #sharedDifficulties > 0 and sharedDifficulties or nil

			for _, encounterID in ipairs(reward.encounters) do
				-- ID, difficulty, pending[], fulfilled[], unknown[]
				local data = {}

				data.ID = encounterID
				data.difficultyID = difficultyID
				data.sharedDifficulties = sharedDifficulties
				data.unknown = {}
				data.fulfilled = {}
				data.pending = {}
				data.total = {}
				data.encounter = CharacterStore.Get():CurrentPlayer():GetEncounter(encounterID)

				for _, character in self:EnumerateCharacters() do
					local encounter = character.encounters[encounterID]

					if encounter == nil then
						table.insert(data.unknown, character)
					elseif sharedDifficulties and encounter:IsAnyDifficultyComplete() then
						table.insert(data.fulfilled, character)
					elseif not sharedDifficulties and encounter:IsComplete(difficultyID) then
						table.insert(data.fulfilled, character)
					else
						table.insert(data.pending, character)
					end
				end

				if data.encounter then
					table.insert(encounters, data)
				end
				numUniqueEncounters[encounterID] = true
			end
		end

		table.sort(encounters, function(x, y)
			return x.difficultyID > y.difficultyID
		end)

		local row = { reward = reward, encounters = encounters, numUniqueEncounters = #GetKeysArray(numUniqueEncounters) }

		row.dataProvider = self

		table.insert(rows, row)
	end

	self.rows = rows
	self.shouldPopulateData = false
end

function WarbandRewardsTrackerDataProviderMixin:Reset()
	self:PopulateCharactersData()

	local groups = { continents = {} }
	function groups:GetOrCreate(mapID)
		local map = Util:GetContinentMap(mapID)

		if self.continents[map.mapID] == nil then
			self.continents[map.mapID] = { name = map.name, rows = {} }
			table.insert(groups, self.continents[map.mapID])
		end

		return self.continents[map.mapID]
	end

	local builtinGroups = {
		FOCUSED = 1,
		{ rows = {}, virtual = true, index = 1 },
		COMPLETED = 2,
		{ name = COLLECTED, rows = {} },
		INACTIVE = 3,
		{ name = FACTION_INACTIVE, rows = {} },
	}
	for _, row in ipairs(self.rows) do
		local group

		if row.reward:IsFocused() then
			group = builtinGroups[builtinGroups.FOCUSED]
		elseif row.reward:IsClaimed() then
			group = builtinGroups[builtinGroups.COMPLETED]
		elseif row.reward:IsInactive() then
			group = builtinGroups[builtinGroups.INACTIVE]
		else
			group = groups:GetOrCreate(row.reward.map)
		end

		table.insert(group.rows, row)
	end

	for _, group in ipairs(builtinGroups) do
		if #group.rows > 0 then
			table.insert(groups, group.index or 1 + #groups, group)
		end
	end

	local rows = {}
	for i, group in ipairs(groups) do
		local isCollapsed = self.groupState[i] or false

		if not group.virtual then
			table.insert(rows, { isHeader = true, isCollapsed = isCollapsed, name = group.name, index = i, numQuests = #group.rows })
		else
			isCollapsed = false
		end

		for _, row in ipairs(isCollapsed and {} or group.rows) do
			table.insert(rows, row)
		end
	end

	self:Init(rows)

	return true
end
