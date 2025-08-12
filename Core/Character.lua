local _, ns = ...

local Util = ns.Util

local QuestRewards = ns.QuestRewards

local Character = { enabled = true }
Character.__index = Character

function Character:New(o)
	o = o or {}
	-- self.__index = self
	setmetatable(o, self)

	if next(o) == nil then
		Character._Init(o)
	end

	for _, rewards in pairs(o.rewards) do
		setmetatable(rewards, QuestRewards)
	end

	return o
end

function Character:_Init()
	local _localizedClassName, classFile, _classID = UnitClass("player")
	local _englishFactionName, localizedFactionName = UnitFactionGroup("player")

	self.name = UnitName("player")
	self.GUID = UnitGUID("player")
	self.realmName = GetRealmName()
	self.level = UnitLevel("player")
	self.factionName = localizedFactionName
	self.class = classFile
	self.rewards = {}
	self.updatedAt = GetServerTime()

	Util:Debug("Initialized new character:", self.name)
end

function Character:GetNameInClassColor(excludeRealm)
	if excludeRealm then
		return Util.WrapTextInClassColor(self.class, self.name)
	else
		return Util.WrapTextInClassColor(self.class, format("%s - %s", self.name, self.realmName))
	end
end

function Character:GetRewards(questID)
	return self.rewards[questID]
end

function Character:ResetRewards(questID)
	self.rewards[questID] = nil

	Util:Debug("Reset rewards for quest:", questID)
end

function Character:IsRewardsClaimed(questID)
	local rewards = self.rewards[questID]

	return rewards and rewards:IsClaimed()
end

function Character:CleanupRewards(activeQuests)
	local quests = {}
	for _, quest in ipairs(activeQuests) do
		quests[quest.ID] = true
	end

	for questID, rewards in pairs(self.rewards) do
		if not quests[questID] then
			self:ResetRewards(questID)
		end
	end
end

function Character:SetQuests(quests)
	Character.Quests = Util:Filter(quests, function(quest)
		local rewards = self:GetRewards(quest.ID)

		if rewards then
			rewards:Update(quest.ID, true)
		end

		return rewards == nil or not rewards:IsClaimed()
	end)

	Util:Debug("Quests to update:", #Character.Quests, #quests)
end

function Character:Update()
	if self.Quests == nil or #self.Quests == 0 then
		return
	end

	for i = #self.Quests, 1, -1 do
		local rewards = QuestRewards:Create(self.Quests[i].ID)

		if rewards then
			self.rewards[self.Quests[i].ID] = rewards
			table.remove(self.Quests, i)
		end
	end

	Util:Debug("Remaining quests:", #self.Quests)

	if #self.Quests == 0 then
		self.updatedAt = GetServerTime()
		Util:TriggerEventAsync("CharacterStore.CharacterStateChanged")

		return true
	end
end

ns.Character = Character
