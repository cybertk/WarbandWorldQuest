local addonName, ns = ...

local Util = ns.Util
local CharacterStore = ns.CharacterStore
local WorldQuestList = ns.WorldQuestList
local QuestRewards = ns.QuestRewards

local MAPS = {
	2274, -- Khaz Algar
}

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

	WorldQuestList:Load(self.db.quests)
	self:RemoveExpiredQuests()
	WorldQuestList:Scan(MAPS)
	self.WorldQuestList = WorldQuestList

	self.character:CleanupRewards(WorldQuestList:GetAllQuests())

	self.dataProvider = self:CreateDataProvider()

	WorldMapFrame:AddDataProvider(self.dataProvider)
	for _, pin in ipairs({ WorldMap_WorldQuestPinMixin }) do
		hooksecurefunc(pin, "OnMouseEnter", function(pin)
			WarbandWorldQuestDataProviderMixin.UpdatePinTooltip(WarbandWorldQuestDataProviderMixin, GameTooltip, pin)
		end)
	end

	do -- Add tab to QuestMapFrame
		local tab = CreateFrame("Frame", nil, QuestMapFrame, "WarbandWorldQuestTabButtonTemplate")
		table.insert(QuestMapFrame.TabButtons, tab)
	end

	do -- Add content to QuestMapFrame
		local content = CreateFrame("Frame", "WarbandWorldQuestPage", QuestMapFrame, "WarbandWorldQuestPageTemplate")
		content:SetDataProvider(self.dataProvider)
		table.insert(QuestMapFrame.ContentFrames, content)
	end

	QuestMapFrame:SetDisplayMode("WarbandWorldQuest")
	self:AddTrackedQuestsToObjectivesPanel()
end

function WarbandWorldQuest:RemoveExpiredQuests()
	local resetStartTime = WorldQuestList:Reset(function(quest)
		self.characterStore:ForEach(function(character)
			if character.rewards[quest.ID] then
				character.rewards[quest.ID] = nil
			end
		end)

		Util:Debug("Removed quest:", quest.ID, quest:GetName())
	end)

	if WarbandWorldQuestDB.resetStartTime == nil and resetStartTime == 0 then
		resetStartTime = GetServerTime()
	end

	if resetStartTime > 0 then
		WarbandWorldQuestDB.resetStartTime = resetStartTime
		Util:Debug("Updatd resetStartTime:", date("%Y-%m-%d %H:%M", resetStartTime))
	end
end

function WarbandWorldQuest:Update()
	local changed = WorldQuestList:Scan(MAPS)
	if changed then
		self.character:SetQuests(WorldQuestList:GetAllQuests())
	end

	changed = self.character:Update() or changed
	if changed then
		self.dataProvider:OnLoad()
	end
end

function WarbandWorldQuest:SetRewardsClaimed(questID)
	if not WorldQuestList:IsActiveQuest(questID) then
		return
	end

	local rewards = self.character:GetRewards(questID)
	if rewards == nil then
		Util:Debug("Failed to SetRewardsClaimed", questID)
		return
	end

	rewards:SetClaimed()
	self.dataProvider:UpdateRewardsClaimed(questID)
end

function WarbandWorldQuest:CreateDataProvider()
	local dataProvider = CreateFromMixins(WarbandWorldQuestDataProviderMixin)

	dataProvider:OnLoad()
	dataProvider.character = self.character

	return dataProvider
end

function WarbandWorldQuest:AddTrackedQuestsToObjectivesPanel()
	for _, quest in ipairs(self.WorldQuestList:GetAllQuests()) do
		quest:SetTracked(quest:IsTracked())
	end
end

function WarbandWorldQuest:ExecuteChatCommands(command)
	if command == "debug" then
		-- Toggle Debug Mode
		self.db.debug = not self.db.debug
		Util.debug = self.db.debug
		print("Debug Mode:", self.db.debug)
		return
	end

	print("Usage: |n/wwq debug - Turn on/off debugging mode")
end

do
	_G["WarbandWorldQuest"] = WarbandWorldQuest

	SLASH_WARBAND_WORLD_QUEST1 = "/WarbandWorldQuest"
	SLASH_WARBAND_WORLD_QUEST2 = "/wwq"
	function SlashCmdList.WARBAND_WORLD_QUEST(msg, editBox)
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

	WarbandWorldQuest:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isInitialLogin, isReloadingUi)
		if isInitialLogin == false and isReloadingUi == false then
			return
		end

		WarbandWorldQuest:Init()
	end)

	WarbandWorldQuest:RegisterEvent("QUEST_LOG_UPDATE", function()
		WarbandWorldQuest:Update()
	end)

	WarbandWorldQuest:RegisterEvent("QUEST_TURNED_IN", function(event, questID, xpReward, moneyReward)
		WarbandWorldQuest:SetRewardsClaimed(questID)
	end)

	WarbandWorldQuest:RegisterEvent("ADDON_LOADED", function(event, name)
		if name ~= addonName then
			return
		end

		local DefaultWarbandWorldQuestDB = {
			quests = {},
			characters = {},
			resetStartTime = GetServerTime(),
		}

		local DefaultWarbandWorldQuestSettings = {
			rewardTypeFilters = 1,
			groups = {},
			showProgressOnPin = true,
		}

		WarbandWorldQuestDB = WarbandWorldQuestDB or DefaultWarbandWorldQuestDB
		WarbandWorldQuestSettings = WarbandWorldQuestSettings or DefaultWarbandWorldQuestSettings

		WarbandWorldQuest.db = WarbandWorldQuestDB
		Util.debug = WarbandWorldQuestDB.debug
	end)
end
