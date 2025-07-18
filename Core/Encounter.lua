local _, ns = ...

local Util = ns.Util

local Encounter = { NameCache = {}, IDCache = {}, DungeonCache = {}, DungeonEncounterCache = {}, DungeonAreaMapCache = {} }
Encounter.__index = Encounter

function Encounter:New()
	local o = {}
	setmetatable(o, self)
	return o
end

function Encounter:Update(encounterID)
	local name, description, bossID, rootSectionID, link, instanceID, dungeonEncounterID, dungeonID = EJ_GetEncounterInfo(encounterID or self:GetID())

	if name == nil then
		Util:Debug("|cnRED_FONT_COLOR:ENCOUNTER_UPDATE_FAILED:", encounterID, self:GetID())
		return 0
	end

	self.IDCache[self] = encounterID
	self.NameCache[self] = name
	self.DungeonCache[self] = dungeonID
	self.DungeonEncounterCache[self] = dungeonEncounterID

	local numCompleted = 0

	EJ_SelectInstance(instanceID)

	for _, difficultyID in pairs(DifficultyUtil.ID) do
		if (self[difficultyID] and self[difficultyID][1] == 0) or (self[difficultyID] == nil and EJ_IsValidInstanceDifficulty(difficultyID)) then
			self[difficultyID] = self[difficultyID] or { 0 }

			if C_RaidLocks.IsEncounterComplete(dungeonID, dungeonEncounterID, difficultyID) then
				self:SetCompleted(difficultyID)
				numCompleted = numCompleted + 1
			end
		end
	end

	self.DungeonAreaMapCache[self] = select(7, EJ_GetInstanceInfo(instanceID))

	return numCompleted
end

function Encounter:GetName()
	return Encounter.NameCache[self]
end

function Encounter:GetID()
	return Encounter.IDCache[self]
end

function Encounter:GetDungeonID()
	return Encounter.DungeonCache[self]
end

function Encounter:GetDungeonEncounterID()
	return Encounter.DungeonEncounterCache[self]
end

function Encounter:GetDungeonAreaMapID()
	return Encounter.DungeonAreaMapCache[self]
end

function Encounter:GetCompletedTime(difficultyID)
	return self[difficultyID] and self[difficultyID][1] or 0
end

function Encounter:SetCompleted(difficultyID)
	self[difficultyID] = { GetServerTime() }

	Util:Debug("Encounter SetCompleted", self:GetID(), self:GetName(), difficultyID)
end

function Encounter:IsComplete(difficultyID)
	return self[difficultyID] and self[difficultyID][1] > 0
end

function Encounter:IsAllDifficultiesComplete(difficultyID)
	for difficultyID, completedAt in pairs(self) do
		if not self:IsComplete(difficultyID) then
			return false
		end
	end

	return true
end

function Encounter:IsAnyDifficultyComplete()
	for difficultyID, completedAt in pairs(self) do
		if self:IsComplete(difficultyID) then
			return difficultyID
		end
	end
end

function Encounter:SetComplete(difficultyID)
	return self[difficultyID]
end

ns.Encounter = Encounter
