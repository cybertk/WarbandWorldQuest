local _, ns = ...

local Util = ns.Util

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

function WorldQuest:UpdateFirstCompletionBonus()
	if self.currencies or not C_QuestInfoSystem.HasQuestRewardCurrencies(self.ID) then
		return
	end

	local currencies = {}

	for _, currency in ipairs(C_QuestInfoSystem.GetQuestRewardCurrencies(self.ID)) do
		if currency.questRewardContextFlags == Enum.QuestRewardContextFlags.FirstCompletionBonus then
			table.insert(currencies, { currency.currencyID, currency.totalRewardAmount })
		end
	end

	if #currencies > 0 then
		self.currencies = currencies
		Util:Debug("Updated FirstCompletionBonus:", self.ID, self:GetName(), #currencies)
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
	local xMin, xMax, yMin, yMax = C_Map.GetMapRectOnMap(self.map, mapID)
	if xMin == xMax and yMin == yMax then
		return {}
	end

	local x = xMin + self.x * (xMax - xMin)
	local y = yMin + self.y * (yMax - yMin)

	return { x, y }
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

local QuestRewards = {}
QuestRewards.__index = QuestRewards

function QuestRewards:Create(questID)
	local o = {}
	setmetatable(o, QuestRewards)

	if o:Update(questID) then
		return o
	end
end

function QuestRewards:Aggregate(rewardsList)
	local money = 0
	local currencies = {}
	local items = {}

	for _, o in pairs(rewardsList) do
		money = (o.money or 0) + money

		for _, currency in ipairs(o.currencies or {}) do
			local currencyID, amount = unpack(currency)

			currencies[currencyID] = (currencies[currencyID] or 0) + amount
		end

		for _, item in ipairs(o.items or {}) do
			local itemID, amount = unpack(item)

			items[itemID] = (items[itemID] or 0) + amount
		end
	end

	local aggregated = { money = money, items = {}, currencies = {} }
	for ID, amount in pairs(items) do
		table.insert(aggregated.items, { ID, amount })
	end

	for ID, amount in pairs(currencies) do
		table.insert(aggregated.currencies, { ID, amount })
	end

	setmetatable(aggregated, QuestRewards)

	return aggregated
end

function QuestRewards:Release()
	self.RewardTypeTable[self] = nil
end

function QuestRewards:Update(questID, force)
	if self.claimedAt ~= nil then
		Util:Debug("Skip completed quest", questID)
		return
	end

	if C_QuestLog.IsQuestFlaggedCompleted(questID) then
		self.claimedAt = 0
		return true
	end

	local completed = true
	local changes = 0

	if not HaveQuestRewardData(questID) then
		C_TaskQuest.RequestPreloadRewardData(questID)
		return
	end

	if self.money == nil or self.money == 0 or force then
		local money = GetQuestLogRewardMoney(questID)

		if money > 0 then
			self.money = money
			changes = changes + 1
		end
	end

	if (self.currencies == nil and C_QuestInfoSystem.HasQuestRewardCurrencies(questID)) or force then
		local currencies = {}
		local hasFirstCompletionBonus = false
		for _, currency in ipairs(C_QuestInfoSystem.GetQuestRewardCurrencies(questID)) do
			if currency.questRewardContextFlags == Enum.QuestRewardContextFlags.FirstCompletionBonus then
				hasFirstCompletionBonus = true
			else
				table.insert(currencies, { currency.currencyID, currency.totalRewardAmount })
			end
		end

		if #currencies > 0 then
			self.currencies = currencies
			changes = changes + 1
		elseif not hasFirstCompletionBonus then
			completed = false
		end
	end

	if (self.items == nil and GetNumQuestLogRewards(questID) > 0) or force then
		local items = {}
		for i = 1, GetNumQuestLogRewards(questID) do
			local _, _, numItems, _, _, itemID = GetQuestLogRewardInfo(i, questID)
			table.insert(items, { itemID, numItems })
		end

		if #items > 0 then
			self.items = items
			changes = changes + 1
		else
			completed = false
		end
	end

	if changes > 0 then
		-- world quests with rep-only rewards are always marked as first-completetion-bonus
		Util:Debug("Updated rewards:", questID, changes, completed, self.money, self.currencies and #self.currencies, self.items and #self.items)
	end

	return completed
end

function QuestRewards:Summary(asList)
	local records = {}
	local s = ""

	if self.money and self.money > 0 then
		s = GetMoneyString(math.floor(self.money / COPPER_PER_GOLD) * COPPER_PER_GOLD)
		table.insert(records, s)
	end

	for _, currency in ipairs(self.currencies or {}) do
		local currencyID, amount = unpack(currency)
		local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)

		if info then
			s = s .. format(" |T%d:15|t %d", info.iconFileID, amount)

			local color = ITEM_QUALITY_COLORS[info.quality].color:GenerateHexColor()
			table.insert(records, 1, format(" |T%d:15|t |c%s[%s]|r x%d", info.iconFileID, color, info.name, amount))
		elseif asList then
			table.insert(records, 1, LFG_LIST_LOADING)
		else
			return LFG_LIST_LOADING
		end
	end

	for _, item in ipairs(self.items or {}) do
		local itemID, amount = unpack(item)

		if asList and not C_Item.IsItemDataCachedByID(itemID) then
			C_Item.RequestLoadItemDataByID(itemID)
			table.insert(records, 1, LFG_LIST_LOADING)
		elseif asList then
			local itemName, itemLink, itemQuality, itemLevel, _, itemType, itemSubType, _, itemEquipLoc, itemTexture = C_Item.GetItemInfo(itemID)
			local color = ITEM_QUALITY_COLORS[itemQuality].color:GenerateHexColor()

			if itemEquipLoc == "INVTYPE_NON_EQUIP_IGNORE" then
				record = format(" |T%d:15|t |c%s[%s]|r", itemTexture, color, itemName)
			else
				record = format(" |T%d:15|t |c%s[%s (%s/%s)]|r", itemTexture, color, itemName, _G[itemEquipLoc], itemLevel)
			end

			if itemEquipLoc == "INVTYPE_NON_EQUIP_IGNORE" or amount > 1 then
				record = record .. format(" x%d", amount)
			end

			table.insert(records, 1, record)
		else
			local _, _, _, itemEquipLoc, icon = C_Item.GetItemInfoInstant(itemID)

			if itemEquipLoc == "INVTYPE_NON_EQUIP_IGNORE" then
				s = s .. format(" |T%d:15|t %d", icon, amount)
			else
				s = s .. format(" |T%d:15|t(%s)", icon, _G[itemEquipLoc])
			end
		end
	end

	return asList and records or s
end

function QuestRewards:SetClaimed()
	self.claimedAt = GetServerTime()
end

function QuestRewards:IsClaimed()
	return self.claimedAt ~= nil
end

function QuestRewards:IsValid()
	return (self.money or self.currencies or self.items) ~= nil
end

QuestRewards.RewardTypeTable = {}
function QuestRewards:GetRewardType()
	if self.RewardTypeTable[self] == nil then
		self:UpdateRewardType()
	end

	return self.RewardTypeTable[self]
end

QuestRewards.RewardTypes = {
	{ name = WORLD_QUEST_REWARD_FILTERS_GOLD, currency = 0 },
	{ name = WORLD_QUEST_REWARD_FILTERS_EQUIPMENT },
}
function QuestRewards:UpdateRewardType()
	local rewardType = 0

	if self.money and self.money > 0 then
		rewardType = bit.bor(rewardType, WORLD_QUEST_REWARD_TYPE_FLAG_GOLD)
	end

	for _, item in ipairs(self.items or {}) do
		rewardType = bit.bor(rewardType, 2 ^ (self:GetOrAddRewardType(item[1]) - 1))
	end

	for _, currency in ipairs(self.currencies or {}) do
		rewardType = bit.bor(rewardType, 2 ^ (self:GetOrAddRewardType(nil, currency[1]) - 1))
	end

	self.RewardTypeTable[self] = rewardType
end

QuestRewards.RewardTypesCache = {}
function QuestRewards:GetOrAddRewardType(itemID, currencyID)
	local objectID = itemID or currencyID

	local index = self.RewardTypesCache[objectID]
	if index and self.RewardTypes[index].name then
		return index
	end

	local type = self.RewardTypes[index] or { itemID = itemID, currencyID = currencyID }
	if itemID then
		local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = C_Item.GetItemInfoInstant(itemID)

		if itemEquipLoc == "INVTYPE_NON_EQUIP_IGNORE" then
			local item = Item:CreateFromItemID(itemID)

			local updateName = function()
				type.name = item:GetItemName()
			end

			if item:IsItemDataCached() then
				updateName()
			else
				item:ContinueOnItemLoad(updateName)
			end

			type.texture = icon
		elseif C_Item.GetItemClassInfo(Enum.ItemClass.Armor) == itemType then
			self.RewardTypesCache[objectID] = 2
			return 2
		end
	elseif currencyID then
		local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
		if info then
			type.name = info.name
			type.texture = info.iconFileID
		end
	end

	if index == nil then
		table.insert(self.RewardTypes, type)
		self.RewardTypesCache[objectID] = #self.RewardTypes
	end

	return self.RewardTypesCache[objectID]
end

function QuestRewards:PassRewardTypeFilters(mask)
	return bit.band(self:GetRewardType(), mask) ~= 0
end

ns.QuestRewards = QuestRewards

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

function WorldQuestList:Scan(continents, isNewSession)
	local mapsToScan = {}
	local remainingQuests = {}

	if isNewSession then
		self.isScanSessionCompleted = nil
		Util:Debug("Started new scan session")
	end

	if self.isScanSessionCompleted then
		return
	end

	for _, mapID in ipairs(continents) do
		for _, map in ipairs(C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone, true)) do
			table.insert(mapsToScan, map)
		end
	end

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
	Util:Debug("Scanned maps", #mapsToScan, next(remainingQuests) == nil)

	table.sort(self.quests, function(x, y)
		return x.resetTime < y.resetTime
	end)

	if next(remainingQuests) == nil then
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
