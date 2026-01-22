local _, ns = ...

local Util = ns.Util
local RewardTypes = ns.RewardTypes

-- ID, resetTime, map, x, y
local WorldQuest = {
	nameCache = {},
	positionCache = {},
}
WorldQuest.__index = WorldQuest

function WorldQuest:Create(info)
	local o = {
		ID = info.questID,
		map = info.mapID,
		x = info.x,
		y = info.y,
	}

	setmetatable(o, self)

	if not HaveQuestRewardData(o.ID) then
		C_TaskQuest.RequestPreloadRewardData(o.ID)
		Util:Debug("Reward data is not available", o.ID, o:GetName(), C_TaskQuest.GetQuestTimeLeftSeconds(o.ID))
		return
	end

	o:UpdateFirstCompletionBonus()

	return o
end

function WorldQuest:UpdateResetTime()
	local secondsLeft = C_TaskQuest.GetQuestTimeLeftSeconds(self.ID)
	if secondsLeft == nil then
		return false
	end

	self.resetTime = GetServerTime() + secondsLeft

	return true
end

function WorldQuest:UpdateFirstCompletionBonus(force)
	if not HaveQuestRewardData(self.ID) or not C_QuestLog.QuestContainsFirstTimeRepBonusForPlayer(self.ID) then
		return
	end

	if not force and self.currencies then
		return
	end

	local factionID = select(2, C_TaskQuest.GetQuestInfoByQuestID(self.ID))

	local currencies = {}

	for _, currency in ipairs(C_QuestInfoSystem.GetQuestRewardCurrencies(self.ID) or {}) do
		if currency.questRewardContextFlags == Enum.QuestRewardContextFlags.FirstCompletionBonus and currency.totalRewardAmount > 15 then
			table.insert(currencies, { currency.currencyID, currency.totalRewardAmount })
		end
	end

	if #currencies == 0 then
		local factionCurrency = Util:GetFactionCurrencyID(factionID)
		if factionCurrency ~= nil then
			table.insert(currencies, { factionCurrency, 50 * Util:GetFactionReputationBonusMultiplier(factionID) })
		end
	end

	if #currencies > 0 then
		self.currencies = currencies
	end

	Util:Debug("Updated FirstCompletionBonus:", self.ID, self:GetName(), factionID, #currencies, unpack(currencies[1] or {}))
end

function WorldQuest:IsFirstCompletionBonusClaimed()
	if HaveQuestRewardData(self.ID) then
		return not C_QuestLog.QuestContainsFirstTimeRepBonusForPlayer(self.ID)
	else
		return C_QuestLog.IsQuestFlaggedCompletedOnAccount(self.ID)
	end
end

function WorldQuest:GetName()
	if self.nameCache[self.ID] then
		return self.nameCache[self.ID]
	end

	self.nameCache[self.ID] = C_TaskQuest.GetQuestInfoByQuestID(self.ID)

	return self.nameCache[self.ID] or ""
end

function WorldQuest:GetQuestPOIMapInfo()
	return {
		questID = self.ID,
		mapID = self.map,
		x = self.x,
		y = self.y,
		numObjectives = 1,
	}
end

function WorldQuest:GetPositionOnMap(mapID)
	self.positionCache[self] = self.positionCache[self] or {}

	if self.positionCache[self][mapID] == nil then
		local mapGroup = C_Map.GetMapGroupID(self.map)
		if (mapGroup and mapGroup == C_Map.GetMapGroupID(mapID)) or mapID == self.map then
			self.positionCache[self][mapID] = { self.x, self.y }
		else
			local xMin, xMax, yMin, yMax = C_Map.GetMapRectOnMap(self.map, mapID)

			if xMin == xMax and yMin == yMax then
				self.positionCache[self][mapID] = {}
			else
				local x = xMin + self.x * (xMax - xMin)
				local y = yMin + self.y * (yMax - yMin)

				self.positionCache[self][mapID] = { x, y }
			end
		end
	end

	return self.positionCache[self][mapID]
end

function WorldQuest:IsCompleted()
	return C_QuestLog.IsQuestFlaggedCompleted(self.ID)
end

function WorldQuest:SetTracked(tracked)
	self.tracked = tracked or nil

	if not self:IsCompleted() then
		if self.tracked then
			C_QuestLog.AddWorldQuestWatch(self.ID, Enum.QuestWatchType.Manual)
		else
			C_QuestLog.RemoveWorldQuestWatch(self.ID)
		end
	end
end

function WorldQuest:IsTracked()
	return self.tracked or false
end

function WorldQuest:SetInactive(inactive)
	self.inactive = inactive or nil

	if inactive and self.tracked then
		self:SetTracked(false)
	end
end

function WorldQuest:IsInactive()
	return self.inactive or false
end

local WorldQuestList = {
	questCache = {},
	mapCache = {},
	questsOnMap = {},
	isScanSessionCompleted = nil,
}

function WorldQuestList:Load(quests, resetStartTime)
	self.quests = quests
	self.resetStartTime = resetStartTime

	for _, quest in ipairs(self.quests) do
		setmetatable(quest, WorldQuest)
		self:CacheQuest(quest)
	end
end

function WorldQuestList:CacheQuest(quest)
	self.questCache[quest.ID] = quest

	self.mapCache[quest.map] = self.mapCache[quest.map] or {}
	table.insert(self.mapCache[quest.map], quest)

	quest:GetName()
end

function WorldQuestList:GetAllQuests()
	return self.quests
end

-- param: QuestPOIMapInfo
function WorldQuestList:AddQuest(info)
	local quest = WorldQuest:Create(info)
	if quest == nil then
		return
	end

	if not quest:UpdateResetTime() then
		Util:Debug("Ignored quest due to unknown resetTime", quest.ID, quest:GetName())
		return true
	end

	table.insert(self.quests, quest)
	self:CacheQuest(quest)

	Util:Debug("Found quest", quest.ID, quest:GetName())

	return true
end

function WorldQuestList:IsActiveQuest(questID)
	return self.questCache[questID] ~= nil
end

function WorldQuestList:GetQuest(questID)
	return self.questCache[questID]
end

function WorldQuestList:GetQuestsByMapID(mapID)
	return self.mapCache[mapID]
end

function WorldQuestList:NextResetQuests(excludeTags)
	excludeTags = excludeTags or {}

	local quests = Util:Filter(self.quests, function(quest)
		return not excludeTags[C_QuestLog.GetQuestTagInfo(quest.ID).worldQuestType]
	end)

	if #quests == 0 then
		return {}
	end

	local resetTime = quests[1].resetTime
	quests = Util:Filter(quests, function(quest)
		return math.abs(quest.resetTime - resetTime) < 60
	end)

	table.sort(quests, function(x, y)
		return x.map < y.map
	end)

	return quests, resetTime
end

function WorldQuestList:GetQuestsOnContinent(mapID)
	if self.questsOnMap[mapID] == nil then
		self.questsOnMap[mapID] = {}

		local quests = C_Map.GetMapInfo(mapID).mapType == Enum.UIMapType.Continent and self:GetAllQuests() or {}

		for _, quest in ipairs(quests) do
			local position = quest:GetPositionOnMap(mapID)
			if #position > 0 then
				self.questsOnMap[mapID][position] = quest
			end
		end
	end

	return self.questsOnMap[mapID]
end

function WorldQuestList:RemoveQuests(maps)
	local mapsByID = {}

	for _, map in ipairs(maps) do
		mapsByID[map.mapID] = true
	end

	for i = #self.quests, 1, -1 do
		local quest = self.quests[i]

		if mapsByID[quest.map] then
			self.questCache[quest.ID] = nil
			table.remove(self.quests, i)
		end
	end
end

function WorldQuestList:Scan(continents, isNewSession)
	local mapsToScan = {}
	local mapsToRemove = {}
	local remainingQuests = {}

	if isNewSession then
		self.isScanSessionCompleted = nil
		RewardTypes:Reset()
		Util:Debug("Started new scan session")
	end

	if self.isScanSessionCompleted then
		return
	end

	for mapID, shouldScan in pairs(continents) do
		local maps = shouldScan and mapsToScan or mapsToRemove
		for _, map in ipairs(C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone, true)) do
			table.insert(maps, map)
		end
	end

	self:RemoveQuests(mapsToRemove)

	for _, map in ipairs(mapsToScan) do
		local quests = Util:Filter(C_TaskQuest.GetQuestsOnMap(map.mapID) or {}, function(info)
			return info.mapID == map.mapID and C_QuestLog.IsWorldQuest(info.questID)
		end)

		for _, info in ipairs(quests) do
			if self:GetQuest(info.questID) == nil then
				remainingQuests[info.questID] = info
			end
		end
	end

	for questID, info in pairs(remainingQuests) do
		if self:AddQuest(info) then
			remainingQuests[questID] = nil
		end
	end
	Util:Debug("Scanned maps", #mapsToScan, next(remainingQuests) == nil, #self.quests)

	table.sort(self.quests, function(x, y)
		return x.resetTime < y.resetTime
	end)

	if next(remainingQuests) == nil and #self.quests > 0 then
		self.isScanSessionCompleted = true
	end

	return self.isScanSessionCompleted
end

function WorldQuestList:Reset(callback)
	local expiredQuests = {}

	local now = GetServerTime()

	for i = #self.quests, 1, -1 do
		local resetTime = self.quests[i].resetTime

		if resetTime == nil then
			Util:Debug("Removing corrupt quest:", self.quests[i].ID, self.quests[i]:GetName())
			table.remove(self.quests, i)
		elseif now > resetTime then
			table.insert(expiredQuests, 1, self.quests[i])
			table.remove(self.quests, i)
		end
	end

	if callback then
		for _, quest in ipairs(expiredQuests) do
			callback(quest)
		end
	end

	self:UpdateResetStartTime(expiredQuests)

	if #expiredQuests > 0 then
		RewardTypes:Reset()
	end

	return expiredQuests
end

function WorldQuestList:UpdateResetStartTime(quests)
	for _, quest in ipairs(quests) do
		local tag = C_QuestLog.GetQuestTagInfo(quest.ID).worldQuestType

		if self.resetStartTime[tag] == nil or quest.resetTime > self.resetStartTime[tag] then
			self.resetStartTime[tag] = quest.resetTime
			Util:Debug("Updatd resetStartTime:", tag, date("%Y-%m-%d %H:%M", quest.resetTime))
		end
	end
end

function WorldQuestList:GetResetStartTime(excludeTags)
	local resetStartTime = 0

	for tag, time in pairs(self.resetStartTime) do
		if not excludeTags[tag] and (time > resetStartTime) then
			resetStartTime = time
		end
	end

	return resetStartTime
end

ns.WorldQuestList = WorldQuestList
