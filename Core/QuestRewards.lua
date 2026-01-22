local _, ns = ...

local Util = ns.Util
local RewardTypes = ns.RewardTypes

local QuestRewards = {}
QuestRewards.__index = QuestRewards
QuestRewards.RewardTypes = RewardTypes

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

function QuestRewards:AddFirstCompletionBonus(currencies)
	if currencies == nil or #currencies == 0 then
		return
	end

	self.currencies = self.currencies or {}

	for _, reward in ipairs(currencies) do
		local currencyID, amount = unpack(reward)
		table.insert(self.currencies, { currencyID, amount, true })
	end
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
			elseif not Util:IsPvPCurrency(currency.currencyID) or (C_QuestLog.GetQuestTagInfo(questID) or {}).worldQuestType == Enum.QuestTagType.PvP then
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

	if self.items then
		completed = self:ConvertAnimaItemsToCurrency() and completed
	end

	if changes > 0 then
		-- world quests with rep-only rewards are always marked as first-completetion-bonus
		Util:Debug("Updated rewards:", questID, changes, completed, self.money, self.currencies and #self.currencies, self.items and #self.items)
	end

	return completed
end

function QuestRewards:GetAnimaAmount(itemID)
	self.AnimaCache = self.AnimaCache or {}

	if self.AnimaCache[itemID] then
		return self.AnimaCache[itemID]
	end

	local lines = C_TooltipInfo.GetItemByID(itemID).lines
	for i = 4, #lines do
		local amount = lines[i].leftText:match("%d+")
		if amount then
			self.AnimaCache[itemID] = amount
			break
		end
	end

	return self.AnimaCache[itemID] or 0
end

function QuestRewards:ConvertAnimaItemsToCurrency()
	local completed = true

	for i = #self.items, 1, -1 do
		local itemID, numItems = unpack(self.items[i])

		if C_Item.IsAnimaItemByID(itemID) then
			local animaAmount = self:GetAnimaAmount(itemID)

			if animaAmount ~= 0 then
				self.currencies = self.currencies or {}

				table.insert(self.currencies, { 1813, numItems * animaAmount })
				table.remove(self.items, i)
			else
				completed = false
			end
		end
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
		local currencyID, amount, firstCompletionBonus = unpack(currency)
		local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)

		if info then
			if firstCompletionBonus then
				s = format("|T%d:15|t |cnACCOUNT_WIDE_FONT_COLOR:%d|r ", info.iconFileID, amount) .. s
			else
				s = s .. format(" |T%d:15|t %d", info.iconFileID, amount)
			end

			local color = ITEM_QUALITY_COLORS[info.quality].color:GenerateHexColor()
			table.insert(records, 1, format(" |T%d:15|t |c%s[%s]|r x%d", info.iconFileID, color, info.name, amount))
		elseif asList then
			table.insert(records, 1, LFG_LIST_LOADING)
		else
			return LFG_LIST_LOADING
		end

		if firstCompletionBonus and asList then
			records[1] = records[1] .. CreateAtlasMarkup("questlog-questtypeicon-account", 15, 15, 8)
		end
	end

	local equipments = {}
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
				if equipments[itemEquipLoc] == nil then
					equipments[itemEquipLoc] = { amount = amount, icon = icon }
				else
					equipments[itemEquipLoc].amount = equipments[itemEquipLoc].amount + amount
				end
			end
		end
	end

	for itemEquipLoc, equipment in pairs(equipments) do
		s = s .. format(" |T%d:15|t(%s) %d", equipment.icon, _G[itemEquipLoc], equipment.amount)
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

function QuestRewards:GetRewardType()
	return self.RewardTypes:GetByRewards(self)
end

function QuestRewards:PassRewardTypeFilters(mask)
	return bit.band(self:GetRewardType(), mask or 0) ~= 0
end

ns.QuestRewards = QuestRewards
