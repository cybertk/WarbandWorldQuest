local _, ns = ...

local Util = ns.Util
local CharacterStore = ns.CharacterStore
local WorldQuestList = ns.WorldQuestList
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
	elseif not rewards:PassRewardTypeFilters(self.dataProvider.rewardFilters) then
		color = RED_FONT_COLOR
	else
		color = defaultColor or YELLOW_FONT_COLOR
	end

	return color:GenerateHexColor()
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

	for _, row in ipairs(self.rows) do
		if row.aggregatedRewards then
			row.aggregatedRewards:Release()
		end
	end

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

		local row = { quest = quest, rewards = rewards, progress = progress, aggregatedRewards = QuestRewards:Aggregate(rewards) }
		row.dataProvider = self
		Mixin(row, WarbandWorldQuestDataRowMixin)

		table.insert(rows, row)
	end

	table.sort(rows, function(x, y)
		return C_Map.GetMapInfo(x.quest.map).name < C_Map.GetMapInfo(y.quest.map).name
	end)

	self.rows = rows
	self.shouldPopulateData = false
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

function WarbandWorldQuestDataProviderMixin:SetPinOfCompletedQuestShown(shown)
	self.showPinOfCompletedQuest = shown
end

function WarbandWorldQuestDataProviderMixin:SetShouldPopulateData(shouldPopulateData)
	self.shouldPopulateData = shouldPopulateData
end

function WarbandWorldQuestDataProviderMixin:Reset()
	self:PopulateCharactersData()

	self.activeQuests = {}

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
	print("WarbandWorldQuestPinMixin:OnClick", self.questID)

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
