local addonName, ns = ...

local Util = ns.Util
local CharacterStore = ns.CharacterStore
local WorldQuestList = ns.WorldQuestList
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

	WorldQuestList:Load(self.db.quests, self.db.resetStartTime)
	self.WorldQuestList = WorldQuestList

	self.character:CleanupRewards(WorldQuestList:GetAllQuests())

	self.dataProvider = self:CreateDataProvider()
	self:Update(true)

	WorldMapFrame:AddDataProvider(self.dataProvider)
	for _, pin in ipairs({ WorldMap_WorldQuestPinMixin, WarbandWorldQuestPinMixin }) do
		hooksecurefunc(pin, "OnMouseEnter", function(pin)
			WarbandWorldQuestPage:HighlightRow(pin.questID, true)

			if Settings:MatchOption("pins_tooltip_shown", { ["CTRL"] = IsControlKeyDown, ["ALT"] = IsALTKeyDown }) then
				self.dataProvider:UpdatePinTooltip(GameTooltip, pin)
			end
		end)

		hooksecurefunc(pin, "OnMouseLeave", function(pin)
			WarbandWorldQuestPage:HighlightRow(pin.questID, false)
		end)
	end

	do -- Add tab to QuestMapFrame
		CreateFrame("Frame", nil, QuestMapFrame, "WarbandWorldQuestTabButtonTemplate")
	end

	do -- Add content to QuestMapFrame
		local content = CreateFrame("Frame", "WarbandWorldQuestPage", QuestMapFrame, "WarbandWorldQuestPageTemplate")
		content:SetDataProvider(self.dataProvider)
		table.insert(QuestMapFrame.ContentFrames, content)
	end

	if Settings:Get("log_is_default_tab") then
		QuestMapFrame:SetDisplayMode("WarbandWorldQuest")
	end
	self:AddTrackedQuestsToObjectivesPanel()

	Settings:RegisterCallback("maps_to_scan", self.Update, self, true)
end

function WarbandWorldQuest:RemoveQuestRewardsFromAllCharacters(quest)
	self.characterStore:ForEach(function(character)
		if character.rewards[quest.ID] then
			character.rewards[quest.ID] = nil
		end
	end)

	Util:Debug("Removed quest:", quest.ID, quest:GetName())
end

function WarbandWorldQuest:Update(isNewScanSession)
	if self.dataProvider == nil then
		return
	end

	if isNewScanSession then
		WorldQuestList:Reset(GenerateClosure(self.RemoveQuestRewardsFromAllCharacters, self))

		if self.resetTimer ~= nil then
			self.resetTimer:Cancel()
			self.resetTimer = nil
		end
	end

	local changed = WorldQuestList:Scan(Settings:Get("maps_to_scan"), isNewScanSession)
	if changed then
		local secondsToReset = select(2, WorldQuestList:NextResetQuests()) - GetServerTime() + 60

		self.resetTimer = C_Timer.NewTimer(secondsToReset, GenerateClosure(self.Update, self, true))
		self.character:SetQuests(WorldQuestList:GetAllQuests())

		self.warModeScanned = Util:IsWarModeEnabled() or self.warModeScanned
	end

	changed = self.character:Update() or changed
	if changed then
		self.dataProvider:SetShouldPopulateData(true)
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

	Settings:InvokeAndRegisterCallback("pins_min_display_level", dataProvider.SetMinPinDisplayLevel, dataProvider)
	Settings:InvokeAndRegisterCallback("pins_progress_shown", dataProvider.SetProgressOnPinShown, dataProvider)
	Settings:InvokeAndRegisterCallback("pins_completed_shown", dataProvider.SetPinOfCompletedQuestShown, dataProvider)
	Settings:InvokeAndRegisterCallback("reward_type_filters", dataProvider.UpdateRewardTypeFilters, dataProvider)
	CharacterStore:RegisterCallback("CharacterStore.CharacterStateChanged", dataProvider.SetShouldPopulateData, dataProvider, true)

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

	WarbandWorldQuest:RegisterEvent("PVP_TIMER_UPDATE", function()
		if not WarbandWorldQuest.warModeScanned and Util:IsWarModeEnabled() then
			Util:Debug("War Mode is on")

			WarbandWorldQuest:Update(true)
		end
	end)

	WarbandWorldQuest:RegisterEvent("ADDON_LOADED", function(event, name)
		if name ~= addonName then
			return
		end

		local DefaultWarbandWorldQuestDB = {
			quests = {},
			characters = {},
			resetStartTime = { [Enum.QuestTagType.Normal] = GetServerTime() },
		}

		local DefaultWarbandWorldQuestSettings = {
			["group_collapsed_states"] = {},
			["maps_to_scan"] = {
				[2274] = true, -- Khaz Algar
				[1978] = false, -- Dragon Isles
				[1550] = false, -- Shadowlands
			},
			["reward_type_filters"] = {
				["c:0"] = true, -- Gold
			},
			["pins_progress_shown"] = true,
			["pins_completed_shown"] = true,
			["pins_tooltip_shown"] = { enabled = true },
			["pins_min_display_level"] = Enum.UIMapType.Continent,
			["log_scanning_icon_shown"] = true,
			["log_is_default_tab"] = true,
			["log_time_left_shown"] = true,
			["log_warband_rewards_shown"] = { enabled = true, option = "NOT_COLLECTED" },
			["next_reset_exclude_types"] = {},
		}

		if WarbandWorldQuestSettings then -- Migration
			if type(WarbandWorldQuestSettings.reward_type_filters) == "number" then
				WarbandWorldQuestSettings.reward_type_filters = { ["c:0"] = true }
			end

			if type(WarbandWorldQuestSettings.pins_tooltip_shown) == "boolean" then
				WarbandWorldQuestSettings.pins_tooltip_shown =
					{ enabled = WarbandWorldQuestSettings.pins_tooltip_shown, option = WarbandWorldQuestSettings.pins_tooltip_modifier }
				WarbandWorldQuestSettings.pins_tooltip_modifier = nil
			end
		end

		Settings:RegisterSettings("WarbandWorldQuestSettings", DefaultWarbandWorldQuestSettings)
		WarbandWorldQuestDB = WarbandWorldQuestDB or DefaultWarbandWorldQuestDB

		WarbandWorldQuest.db = WarbandWorldQuestDB
		Util.debug = WarbandWorldQuestDB.debug
	end)
end
