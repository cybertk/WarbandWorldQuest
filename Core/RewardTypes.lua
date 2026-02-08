local _, ns = ...

local RewardTypes = {}
RewardTypes.Predefined = {
	{ i = 0, name = WORLD_QUEST_REWARD_FILTERS_GOLD, currency = 0 },
	{ i = 1, name = WORLD_QUEST_REWARD_FILTERS_EQUIPMENT, item = 0 },
	{ i = 2, name = WORLD_QUEST_REWARD_FILTERS_ANIMA, currency = 1813 },
}

function RewardTypes:Reset()
	self.objectCache = {}
	self.rewardsCache = self.rewardsCache or {}

	for i = #self, 1, -1 do
		table.remove(self, i)
	end

	for i, rewardType in ipairs(self.Predefined) do
		table.insert(self, rewardType)

		local objectID = rewardType.item or rewardType.currency
		if objectID ~= 0 then
			self:CacheByIndex(objectID, i)
		end
	end
end

function RewardTypes:GetByObjectID(objectID)
	return self.objectCache[objectID] or {}
end

function RewardTypes:CacheByIndex(objectID, index)
	self.objectCache[objectID] = self[index]

	return self[index]
end

function RewardTypes:GetByRewards(rewards)
	if self.rewardsCache[rewards] == nil then
		self:UpdateRewardType(rewards)
	end

	return self.rewardsCache[rewards]
end

function RewardTypes:Add(rewardType)
	table.insert(self, rewardType)
	rewardType.i = #self - 1

	self.objectCache[rewardType.item or rewardType.currency] = rewardType

	return rewardType.i
end

function RewardTypes:UpdateRewardType(rewards)
	local rewardType = 0

	if rewards.money and rewards.money > 0 then
		rewardType = bit.bor(rewardType, WORLD_QUEST_REWARD_TYPE_FLAG_GOLD)
	end

	for _, item in ipairs(rewards.items or {}) do
		rewardType = bit.bor(rewardType, 2 ^ self:GetOrAddRewardType(item[1]))
	end

	for _, currency in ipairs(rewards.currencies or {}) do
		rewardType = bit.bor(rewardType, 2 ^ self:GetOrAddRewardType(nil, currency[1]))
	end

	self.rewardsCache[rewards] = rewardType
end

function RewardTypes:GetOrAddRewardType(itemID, currencyID)
	local rewardType = self:GetByObjectID(itemID or currencyID)
	if rewardType.name then
		return rewardType.i
	end

	if itemID then
		local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = C_Item.GetItemInfoInstant(itemID)

		if C_Item.IsAnimaItemByID(itemID) then
			rewardType = self:CacheByIndex(itemID, 3)
		elseif itemEquipLoc == "INVTYPE_NON_EQUIP_IGNORE" then
			local item = Item:CreateFromItemID(itemID)

			local updateName = function()
				rewardType.name = item:GetItemName()
			end

			if item:IsItemDataCached() then
				updateName()
			else
				item:ContinueOnItemLoad(updateName)
			end

			rewardType.texture = icon
			rewardType.item = itemID
		else
			rewardType = self:CacheByIndex(itemID, 2)
		end
	elseif currencyID then
		local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
		if info then
			rewardType.name = info.name
			rewardType.texture = info.iconFileID
			rewardType.currency = currencyID
		end
	end

	if rewardType.i == nil or self[rewardType.i + 1] ~= rewardType then
		self:Add(rewardType)
	end

	return rewardType.i
end

function RewardTypes:GenerateMask(selectedTypes)
	local allTypes = self:GetAll()
	local mask = 0

	for key, selected in pairs(selectedTypes) do
		if selected and allTypes[key] then
			mask = mask + 2 ^ allTypes[key].i
		end
	end

	return mask
end

function RewardTypes:FindByKeys(selectedTypes)
	local allTypes = self:GetAll()
	local types = {}

	for key, selected in pairs(selectedTypes) do
		if selected and allTypes[key] then
			table.insert(types, allTypes[key])
		end
	end

	return types
end

function RewardTypes:GetAll(excludeAnima)
	local types = {}

	for _, rewardType in ipairs(self) do
		local key
		if rewardType.currency ~= nil then
			key = "c:" .. rewardType.currency
		else
			key = "i:" .. rewardType.item
		end
		types[key] = rewardType
	end

	if excludeAnima then
		types["c:" .. self.Predefined[3].currency] = nil
	end

	return types
end

ns.RewardTypes = RewardTypes
_G["RT"] = RewardTypes
