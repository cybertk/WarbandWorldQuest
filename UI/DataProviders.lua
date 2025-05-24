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

	local color
	local rewards = (character or CharacterStore.Get():CurrentPlayer()):GetRewards(self.quest.ID)

	if rewards == nil then
		color = GRAY_FONT_COLOR
	elseif rewards:IsClaimed() then
		color = GREEN_FONT_COLOR
	elseif not rewards:PassRewardTypeFilters(WarbandWorldQuestSettings.rewardTypeFilters) then
		color = RED_FONT_COLOR
	else
		color = defaultColor or YELLOW_FONT_COLOR
	end

	return color:GenerateHexColor()
end

WarbandWorldQuestDataProviderMixin = CreateFromMixins(DataProviderMixin, WorldMap_WorldQuestDataProviderMixin)

function WarbandWorldQuestDataProviderMixin:OnLoad()
	for _, row in ipairs(self.rows or {}) do
		if row.aggregatedRewards then
			row.aggregatedRewards:Release()
		end
	end

	local rows = {}

	for _, quest in ipairs(WorldQuestList:GetAllQuests()) do
		local rewards = {}
		local progress = { total = 0, unknown = 0, claimed = 0 }

		CharacterStore.Get():ForEach(function(character)
			rewards[character] = character.rewards[quest.ID]

			if rewards[character] == nil then
				progress.unknown = progress.unknown + 1
			elseif rewards[character]:IsClaimed() then
				progress.claimed = progress.claimed + 1
			end

			progress.total = progress.total + 1
		end)

		local row = { quest = quest, rewards = rewards, progress = progress, aggregatedRewards = QuestRewards:Aggregate(rewards) }
		Mixin(row, WarbandWorldQuestDataRowMixin)

		table.insert(rows, row)
	end

	self.rows = rows
	self.questsOnMap = {}
	self.activeProgress = {}
	self.progressFrames = {}

	self.activeQuests = {}
	self.groupState = {}

	self.minPinDisplayLevel = self.minPinDisplayLevel and self.minPinDisplayLevel or Enum.UIMapType.Continent
	self.maxPinDisplayLevel = self.maxPinDisplayLevel and self.maxPinDisplayLevel or Enum.UIMapType.Zone

	self:Init(rows)
end

function WarbandWorldQuestDataProviderMixin:UpdateRewardsClaimed(questID)
	local row = self:FindByQuestID(questID, false)
	if row == nil then
		Util:Debug("Cannot UpdateRewardsClaimed", questID)
		return
	end

	row.progress.claimed = row.progress.claimed + 1
	Util:Debug("Updated rewards progress", questID, row.quest:GetName())
end

function WarbandWorldQuestDataProviderMixin:UpdateGroupState(groupIndex, isCollapsed)
	self.groupState[groupIndex] = isCollapsed
end

function WarbandWorldQuestDataProviderMixin:SetRewardTypeFilters(filters)
	self.rewardFilters = filters
end

function WarbandWorldQuestDataProviderMixin:SetProgressOnPinShown(shown)
	self.showProgressOnPin = shown
end

function WarbandWorldQuestDataProviderMixin:SetMinPinDisplayLevel(uiMapType)
	self.minPinDisplayLevel = uiMapType
end

function WarbandWorldQuestDataProviderMixin:Reset()
	self.activeQuests = {}

	local groups = {
		{
			name = "Active Quests",
			rows = {},
			virtual = true,
		},
		{
			name = "Inactive Quests",
			rows = {},
		},
	}

	for _, row in ipairs(self.rows) do
		if row.aggregatedRewards:PassRewardTypeFilters(self.rewardFilters) then
			row.isActive = true
			table.insert(groups[1].rows, row)
			table.insert(self.activeQuests, row.quest)
		else
			row.isActive = false
			table.insert(groups[2].rows, row)
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
end

function WarbandWorldQuestDataProviderMixin:EnumerateActiveQuestsByMapID(mapID, completedOnly)
	self.questsOnMap[mapID] = {}

	for i, quest in ipairs(self.activeQuests) do
		if not completedOnly or quest:IsCompleted() then
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
	for pin in self:GetMap():EnumeratePinsByTemplate(self:GetPinTemplate()) do
		if pin.questID == questID then
			return pin
		end
	end
end

function WarbandWorldQuestDataProviderMixin:UpdatePinTooltip(tooltip, pin)
	local questID = pin.questID
	if not WorldQuestList:IsActiveQuest(questID) then
		return
	end

	if tooltip.ItemTooltip and tooltip.ItemTooltip:IsShown() then
		if tooltip.ItemTooltip.Tooltip:GetLeft() and tooltip:GetLeft() then
			self.tooltipPadding = tooltip.ItemTooltip.Tooltip:GetLeft() - tooltip:GetLeft()
		end
		tooltip = tooltip.ItemTooltip.Tooltip
	else
		self.tooltipPadding = 0
	end

	local offset = self.tooltipPadding and -self.tooltipPadding or 0

	tooltip:AddLine(" ")
	tooltip:AddLine("Warband Progress", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, false, offset)

	CharacterStore.Get():ForEach(function(character)
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
	end)

	tooltip:Show()
end

function WarbandWorldQuestDataProviderMixin:UpdateAllPinsProgress()
	local framesToRemove = {}
	for pin in pairs(self.progressFrames) do
		framesToRemove[pin] = true
	end

	if self.showProgressOnPin then
		local mapCanvas = self:GetMap()

		for pin in mapCanvas:EnumeratePinsByTemplate(self:GetPinTemplate()) do
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

				framesToRemove[pin] = nil
			end
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
		or self:EnumerateActiveQuestsByMapID(mapID, mapType == Enum.UIMapType.Zone)

	for position, quest in pairs(quests) do
		local pin = self.activePins[quest.ID]

		if pin then
			pin:RefreshVisuals()
			pin:SetPosition(unpack(position))
			pin:AddIconWidgets()
		elseif not InCombatLockdown() then
			pin = self:AddWorldQuest(quest:GetQuestPOIMapInfo())
			pin:SetPosition(unpack(position))
			self.activePins[quest.ID] = pin

			Util:Debug("Added pin for quest", quest.ID, quest:GetName(), mapID)
		end

		pinsToRemove[quest.ID] = nil
	end

	for questID in pairs(pinsToRemove) do
		mapCanvas:RemovePin(self.activePins[questID])
		self.activePins[questID] = nil
	end

	self:UpdateAllPinsProgress()
end
