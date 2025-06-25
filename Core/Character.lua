local _, ns = ...

local Util = ns.Util

local Encounter = ns.Encounter

local Character = { enabled = true }
Character.__index = Character

function Character:New(o)
	o = o or {}
	-- self.__index = self
	setmetatable(o, self)

	if next(o) == nil then
		Character._Init(o)
	end

	for _, encounter in pairs(o.encounters) do
		setmetatable(encounter, Encounter)
	end

	return o
end

function Character:_Init()
	local _localizedClassName, classFile, _classID = UnitClass("player")
	local _englishFactionName, localizedFactionName = UnitFactionGroup("player")
	local factionNameToEnum = { ["Alliance"] = 1, ["Horde"] = 2 }

	self.name = UnitName("player")
	self.GUID = UnitGUID("player")
	self.realmName = GetRealmName()
	self.level = UnitLevel("player")
	self.factionName = localizedFactionName
	self.factionGroup = factionNameToEnum[_englishFactionName]
	self.class = classFile
	self.encounters = {}
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

function Character:GetEncounter(encounterID)
	self.encounters = self.encounters or {}
	return self.encounters[encounterID]
end

function Character:SetEncounters(encounters)
	Character.Encounters = Util:Filter(encounters, function(encounterID)
		local encounter = self:GetEncounter(encounterID)

		return encounter == nil or not encounter:IsAllDifficultiesComplete()
	end)

	Util:Debug("Encounters to update:", #Character.Encounters, #encounters)
end

function Character:Update()
	if self.Encounters == nil or #self.Encounters == 0 then
		return
	end

	for i = #self.Encounters, 1, -1 do
		local encounter = self:GetEncounter(self.Encounters[i])

		if encounter == nil then
			self.encounters[self.Encounters[i]] = Encounter:Create(self.Encounters[i])
		else
			encounter:Update(self.Encounters[i])
		end

		if encounter then
			table.remove(self.Encounters, i)
		end
	end

	Util:Debug("Remaining encounters:", #self.Encounters)

	if #self.Encounters == 0 then
		self.updatedAt = GetServerTime()
		-- Util:TriggerEventAsync("CharacterStore.CharacterStateChanged")

		return true
	end
end

ns.Character = Character
