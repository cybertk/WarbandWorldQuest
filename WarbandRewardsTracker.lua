local addonName, ns = ...

local L = ns.L
local Util = ns.Util
local CharacterStore = ns.CharacterStore
local WarbandRewardList = ns.WarbandRewardList
local QuestRewards = ns.QuestRewards
local Settings = ns.Settings

local WarbandWorldQuest = {}

function WarbandWorldQuest:Init()
	CharacterStore.Load(self.db.characters)

	self.activePins = {}
	self.questsOnMap = {}

	self.characterStore = CharacterStore.Get()
	self.characterStore:SetSortField("rewards")
	self.characterStore:SetSortOrder("name")
	self.characterStore:SetSortOrder("updatedAt")

	self.character = self.characterStore:CurrentPlayer()

	WarbandRewardList:Load(self.db.rewards, self.db.resetStartTime)
	WarbandRewardList:Reset(GenerateClosure(self.RemoveEncountersFromAllCharacters, self))

	for _, candidate in ipairs(ns.DB:GetAllCandidates()) do
		local entry = candidate.entries[1]
		local mountItemID = candidate.items[1].item
		WarbandRewardList:AddFromEncounters(entry.encounters, entry.difficulties, mountItemID, entry.mount)
	end
	self.rewardList = WarbandRewardList

	self.dataProvider = self:CreateDataProvider()
	RequestRaidInfo()

	do -- Add tab to QuestMapFrame
		CreateFrame("Frame", nil, QuestMapFrame, "WarbandQuestTrackerTabButtonTemplate")
	end

	do -- Add content to QuestMapFrame
		local content = CreateFrame("Frame", "WarbandQuestTrackerPage", QuestMapFrame, "WarbandQuestTrackerPageTemplate")
		content:SetDataProvider(self.dataProvider)
		table.insert(QuestMapFrame.ContentFrames, content)
	end

	if Settings:Get("log_is_default_tab") then
		QuestMapFrame:SetDisplayMode("WarbandQuestTracker")
	end
end

function WarbandWorldQuest:RemoveEncountersFromAllCharacters(reward)
	self.characterStore:ForEach(function(character)
		for _, encounterID in ipairs(reward.encounters) do
			character.encounters[encounterID] = nil
		end
	end, next)

	Util:Debug("Removed encounters for reward:", reward:GetName())
end

function WarbandWorldQuest:UpdateAttempts(encounterID, numCompleted)
	local reward = WarbandRewardList:FindByEncounterID(encounterID)
	if reward == nil then
		Util:Debug("Failed to update attempts", encounterID)
		return
	end

	for i = 1, numCompleted do
		reward:Attempted()
	end

	Util:Debug("Updated attempts", encounterID, reward:GetName(), numCompleted)
end

function WarbandWorldQuest:Update(isNewScanSession)
	if self.dataProvider == nil then
		return
	end

	local numSavedInstanceEncounters = Util:GetNumSavedInstanceEncounters()
	if self.numSavedEncounters == numSavedInstanceEncounters then
		Util:Debug("Skip the update", self.numSavedEncounters)
		return
	end

	self.numSavedEncounters = numSavedInstanceEncounters
	Util:Debug("SavedEncounters:", self.numSavedEncounters)

	self.character:SetEncounters(WarbandRewardList:GetAllEncounters())

	local changed = self.character:Update(GenerateClosure(WarbandWorldQuest.UpdateAttempts, self))
	if changed then
		self.dataProvider:SetShouldPopulateData(true)
	end
end

function WarbandWorldQuest:CreateDataProvider()
	local dataProvider = CreateFromMixins(WarbandRewardsTrackerDataProviderMixin)

	dataProvider:OnLoad()
	dataProvider.character = self.character

	return dataProvider
end

function WarbandWorldQuest:ExecuteChatCommands(command)
	if command == "debug" then
		-- Toggle Debug Mode
		self.db.debug = not self.db.debug
		Util.debug = self.db.debug
		print("Debug Mode:", self.db.debug)
		return
	end

	print("Usage: |n/wrt debug - Turn on/off debugging mode")
end

do
	_G["WarbandRewardsTracker"] = WarbandWorldQuest

	SLASH_WARBAND_REWARDS_TRACKER1 = "/WarbandRewardsTracker"
	SLASH_WARBAND_REWARDS_TRACKER2 = "/wrt"
	function SlashCmdList.WARBAND_REWARDS_TRACKER(msg, editBox)
		WarbandWorldQuest:ExecuteChatCommands(msg)
	end

	WarbandWorldQuest.frame = CreateFrame("Frame")

	WarbandWorldQuest.frame:SetScript("OnEvent", function(self, event, ...)
		WarbandWorldQuest.eventsHandler[event](event, ...)
	end)

	function WarbandWorldQuest:RegisterEvent(name, handler)
		if self.eventsHandler == nil then
			self.eventsHandler = {}
		end
		self.eventsHandler[name] = handler
		self.frame:RegisterEvent(name)
	end

	EventRegistry:RegisterCallback("CK_LOOT_SCANNER_ITEM_LOOTED", function(self, source, quantity, item, currency)
		if IsInInstance() and item then
			local reward = WarbandRewardList:FindByItemID(item)
			if reward then
				reward:SetClaimed()
				Util:Info(L["info_reward_claimed"]:format(reward:GetLink()))
			end
		end
	end, WarbandWorldQuest)

	WarbandWorldQuest:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isInitialLogin, isReloadingUi)
		if isInitialLogin == false and isReloadingUi == false then
			return
		end

		WarbandWorldQuest:Init()
	end)

	WarbandWorldQuest:RegisterEvent("UPDATE_INSTANCE_INFO", function()
		WarbandWorldQuest:Update()
	end)

	WarbandWorldQuest:RegisterEvent("ENCOUNTER_START", function(event, dungeonEncounterID, encounterName, difficultyID, groupSize)
		local reward, encounterID = WarbandRewardList:FindByDungeonEncounterID(dungeonEncounterID)
		Util:Debug("ENCOUNTER_START", reward, encounterID, encounterID and C_EncounterJournal.IsEncounterComplete(encounterID))

		if reward then
			Util:Info(L["info_reward_attempt"]:format(reward:GetLink(), reward.attempts, reward.totalAttempts))
		end
	end)

	WarbandWorldQuest:RegisterEvent("ENCOUNTER_END", function(event, dungeonEncounterID, encounterName, difficultyID, groupSize, success)
		local reward, encounterID = WarbandRewardList:FindByDungeonEncounterID(dungeonEncounterID)
		Util:Debug("ENCOUNTER_END", reward, encounterID, encounterID and C_EncounterJournal.IsEncounterComplete(encounterID))

		if reward == nil then
			return
		end

		local encounter = WarbandWorldQuest.character:GetEncounter(encounterID)
		if encounter:IsComplete(difficultyID) then
			return
		end

		if success == 1 then
			-- encounter:SetCompleted(difficultyID)
			-- reward:Attempted()
			WarbandWorldQuest:Update()
			return
		end

		RequestRaidInfo()
	end)

	WarbandWorldQuest:RegisterEvent("ADDON_LOADED", function(event, name)
		if name ~= addonName then
			return
		end

		local DefaultWarbandRewardsTrackerDB = {
			rewards = {},
			characters = {},
		}

		local DefaultWarbandRewardsTrackerSettings = {
			["group_collapsed_states"] = {},
			["log_is_default_tab"] = true,
			["log_time_left_shown"] = true,
			["log_attempts_shown"] = { enabled = true, option = "TOTAL" },
		}

		Settings:RegisterSettings("WarbandRewardsTrackerSettings", DefaultWarbandRewardsTrackerSettings)
		WarbandRewardsTrackerDB = WarbandRewardsTrackerDB or DefaultWarbandRewardsTrackerDB

		WarbandWorldQuest.db = WarbandRewardsTrackerDB
		Util.debug = WarbandRewardsTrackerDB.debug
	end)
end
