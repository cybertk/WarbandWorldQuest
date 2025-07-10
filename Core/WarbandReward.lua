local _, ns = ...

local Util = ns.Util

-- mount, map, x, y, instance, encounters, difficulties, resetTime, totalAttempts, attempts
local WarbandReward = {
	NameCache = {},
}
WarbandReward.__index = WarbandReward

function WarbandReward:CreateFromEncounters(encounters, difficulties)
	local o = {}

	o.totalAttempts = 0
	o.attempts = 0
	o.encounters = encounters
	o.difficulties = difficulties

	WarbandReward.UpdateDungeonPosition(o)

	if not WarbandReward.UpdateResetTime(o) then
		return
	end

	setmetatable(o, self)

	return o
end

function WarbandReward:UpdateDungeonPosition()
	local encounterID = self.encounters[1]
	local name, description, bossID, rootSectionID, link, instanceID, dungeonEncounterID, dungeonID = EJ_GetEncounterInfo(encounterID)

	EJ_SelectInstance(instanceID)

	local map = Util:GetDungeonMap(select(7, EJ_GetInstanceInfo(instanceID)))

	local dungeonEntrance
	for _, entrance in ipairs(C_EncounterJournal.GetDungeonEntrancesForMap(map.mapID) or {}) do
		if entrance.journalInstanceID == instanceID then
			dungeonEntrance = entrance
		end
	end

	self.instance = instanceID
	self.dungeon = dungeonID
	self.map = map.mapID

	if dungeonEntrance == nil then
		return
	end

	self.x, self.y = dungeonEntrance.position:GetXY()

	return true
end

function WarbandReward:UpdateResetTime()
	if self.difficulties then
		local timeToReset = DifficultyUtil.GetMaxPlayers(self.difficulties[1]) > 5 and C_DateAndTime.GetSecondsUntilWeeklyReset()
			or C_DateAndTime.GetSecondsUntilDailyReset()

		self.resetTime = GetServerTime() + timeToReset

		return true
	end

	return
end

function WarbandReward:Reset()
	self.attempts = 0
	self:UpdateResetTime()
end

function WarbandReward:GetName()
	if self.NameCache[self] then
		return self.NameCache[self]
	end

	if self.mount then
		self.NameCache[self] = C_MountJournal.GetMountInfoByID(self.mount)
	end

	return self.NameCache[self]
end

function WarbandReward:IsClaimed()
	local isClaimed

	if self.mount then
		isClaimed = select(11, C_MountJournal.GetMountInfoByID(self.mount))
	end

	return isClaimed == true
end

function WarbandReward:GetClaimableDifficulties()
	if IsLegacyDifficulty(self.difficulties[1]) then
		return { math.max(unpack(self.difficulties)) }
	end

	return self.difficulties
end

function WarbandReward:GenerateMapPoint()
	return UiMapPoint.CreateFromCoordinates(self.map, self.x or 0, self.y or 0)
end

function WarbandReward:SetFocused(focused)
	self.focused = focused or nil
end

function WarbandReward:IsFocused()
	return self.focused or false
end

function WarbandReward:SetInactive(inactive)
	self.inactive = inactive or nil
end

function WarbandReward:IsInactive()
	return self.inactive or false
end

function WarbandReward:Attempted()
	self.attempts = self.attempts + 1
	self.totalAttempts = self.totalAttempts + 1

	Util:Debug("Attempted", self:GetName())
end

local WarbandRewardList = {
	mountCache = {},
	encounterCache = {},
	dungeonEncounterCache = {},
}

function WarbandRewardList:Load(rewards, resetStartTime)
	self.rewards = rewards
	self.resetStartTime = resetStartTime

	for _, reward in ipairs(self.rewards) do
		setmetatable(reward, WarbandReward)
		self:CacheReward(reward)
	end

	self:Update()
end

function WarbandRewardList:Reset(callback)
	local expiredRewards = {}

	local now = GetServerTime()

	for _, reward in ipairs(self.rewards) do
		if now > reward.resetTime then
			reward:Reset()
			table.insert(expiredRewards, reward)
		end
	end

	if callback then
		for _, reward in ipairs(expiredRewards) do
			callback(reward)
		end
	end

	return expiredRewards
end

_G["WarbandRewardList"] = WarbandRewardList

function WarbandRewardList:CacheReward(reward)
	if reward.mount then
		self.mountCache[reward.mount] = reward
	end

	for _, encounterID in ipairs(reward.encounters) do
		if self.encounterCache[encounterID] == nil then
			local name, description, bossID, rootSectionID, link, instanceID, dungeonEncounterID, dungeonID = EJ_GetEncounterInfo(encounterID)

			self.encounterCache[encounterID] = reward
			self.dungeonEncounterCache[dungeonEncounterID] = encounterID
		end
	end
end

function WarbandRewardList:EnumerateAll()
	return CreateTableEnumerator(self.rewards)
end

function WarbandRewardList:FindByMountID(mountID)
	return self.mountCache[mountID]
end

function WarbandRewardList:FindByDungeonEncounterID(dungeonEncounterID)
	local encounterID = self.dungeonEncounterCache[dungeonEncounterID]

	return self.encounterCache[encounterID], encounterID
end

function WarbandRewardList:AddFromEncounters(encounters, difficulties, mount)
	if self:FindByMountID(mount) then
		return
	end

	local reward = WarbandReward:CreateFromEncounters(encounters, difficulties)
	if not reward then
		Util:Debug("Cannot recoginized encounters", encounters[1])
		return
	end

	reward.mount = mount

	table.insert(self.rewards, reward)
	self:CacheReward(reward)

	Util:Debug("Added reward", mount, reward:GetName())

	return true
end

function WarbandRewardList:Update()
	local changed = {}
	for _, reward in ipairs(self.rewards) do
		if reward.x == nil then
			if reward:UpdateDungeonPosition() then
				table.insert(changed, reward:GetName())
			end
		end
	end

	Util:Debug("Updated reward:", #changed, unpack(changed))
end

function WarbandRewardList:GetAllEncounters()
	local uniqueEncounters = {}

	for _, reward in self:EnumerateAll() do
		for _, encounterID in ipairs(reward.encounters) do
			uniqueEncounters[encounterID] = true
		end
	end

	return GetKeysArray(uniqueEncounters)
end

function WarbandRewardList:GetResetStartTime(excludeTags)
	return C_DateAndTime.GetWeeklyResetStartTime()
end

ns.WarbandRewardList = WarbandRewardList
