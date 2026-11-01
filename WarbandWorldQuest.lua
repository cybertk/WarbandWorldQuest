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

	self.character:RefreshInfo()
	self.character:CleanupRewards(WorldQuestList:GetAllQuests())

	self.dataProvider = self:CreateDataProvider()
	self:Update(true)

	for _, pin in ipairs({ WorldMap_WorldQuestPinMixin, WarbandWorldQuestPinMixin }) do
		hooksecurefunc(pin, "OnMouseEnter", function(pin)
			WarbandWorldQuestPage:HighlightRow(pin.questID, true)

			local tooltip = WarbandWorldQuestGameTooltip
			if Settings:MatchOption("pins_tooltip_shown", { ["CTRL"] = IsControlKeyDown, ["ALT"] = IsALTKeyDown }) then
				if not pin.quest then
					local row = self.dataProvider:FindByQuestID(pin.questID)
					if not row then
						return
					end

					GameTooltip:SetOwner(WorldMapFrame:GetCanvas(), "ANCHOR_NONE")

					local anchor, x, y = select(3, pin:GetPointByName("CENTER"))
					tooltip:SetOwner(WorldMapFrame:GetCanvas(), "ANCHOR_" .. anchor, x + 10, y)
					WarbandWorldQuestPinMixin:AddQuestToTooltip(tooltip, row.quest)
				end

				self.dataProvider:UpdatePinTooltip(tooltip, pin)
				tooltip:Show()
			elseif not pin.quest then
				tooltip:Hide()
			end
		end)

		hooksecurefunc(pin, "OnMouseLeave", function(pin)
			WarbandWorldQuestPage:HighlightRow(pin.questID, false)
			WarbandWorldQuestGameTooltip:Hide()
		end)
	end

	do -- Add tab to QuestMapFrame
		local tab = CreateFrame("Frame", addonName .. "Tab", QuestMapFrame, "WarbandWorldQuestTabButtonTemplate")

		tab:SetContentFrame("WarbandWorldQuestPage", "WarbandWorldQuestPageTemplate")
		tab.ContentFrame:SetDataProvider(self.dataProvider)
		tab:SetChecked(Settings:Get("log_is_default_tab"))
	end

	Settings:RegisterCallback("maps_to_scan", self.Update, self, true)
	Settings:RegisterCallback("log_auto_track_filtered", self.UpdateAutoTracking, self)
	Settings:RegisterCallback("reward_type_filters", self.UpdateAutoTracking, self)
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
		self:AddTrackedQuestsToObjectivesPanel()

		self.warModeScanned = C_PvP.IsWarModeActive() or self.warModeScanned
	end

	changed = self.character:Update() or changed
	if changed then
		self.dataProvider:SetShouldPopulateData(true)
		self:UpdateAutoTracking()
	end
end

function WarbandWorldQuest:GetAutoTrackRewards(quest)
	if not quest:IsPlayerEligible() or quest:IsCompleted() or quest:IsInactive() then
		return
	end

	local rewards = self.character:GetRewards(quest.ID)
	if rewards == nil or rewards:IsClaimed() or rewards:IsLocked() then
		return
	end

	rewards = QuestRewards:Aggregate({ rewards })
	if not quest:IsFirstCompletionBonusClaimed() then
		rewards:AddFirstCompletionBonus(quest.currencies)
	end

	return rewards
end

function WarbandWorldQuest:UpdateAutoTracking()
	if self.character == nil then
		return
	end

	self.character.autoTracked = self.character.autoTracked or {}

	local autoTracked = self.character.autoTracked
	local enabled = Settings:Get("log_auto_track_filtered")
	local candidates = {}
	local activeQuests = {}

	-- reward types are only registered once a reward is inspected, so inspect all candidates before generating the mask
	for _, quest in ipairs(WorldQuestList:GetAllQuests()) do
		local rewards = enabled and self:GetAutoTrackRewards(quest)
		if rewards then
			rewards:GetRewardType()
			candidates[quest.ID] = rewards
		end
	end

	local mask = QuestRewards.RewardTypes:GenerateMask(Settings:Get("reward_type_filters"))

	for _, quest in ipairs(WorldQuestList:GetAllQuests()) do
		activeQuests[quest.ID] = true

		if quest.tracked == nil then
			local isManual = C_QuestLog.GetQuestWatchType(quest.ID) == Enum.QuestWatchType.Manual
			local shouldTrack = candidates[quest.ID] ~= nil and candidates[quest.ID]:PassRewardTypeFilters(mask)

			if shouldTrack and not isManual then
				autoTracked[quest.ID] = true
				C_QuestLog.AddWorldQuestWatch(quest.ID, Enum.QuestWatchType.Manual)
			elseif not shouldTrack and autoTracked[quest.ID] then
				autoTracked[quest.ID] = nil
				if isManual then
					C_QuestLog.RemoveWorldQuestWatch(quest.ID)
				end
			end
		end
	end

	for questID in pairs(autoTracked) do
		if not activeQuests[questID] then
			autoTracked[questID] = nil
		end
	end
end

function WarbandWorldQuest:QueueLockedQuestsCheck()
	if self.lockedQuestsCheckPending or self.dataProvider == nil then
		return
	end

	self.lockedQuestsCheckPending = true
	C_Timer.After(2, function()
		self.lockedQuestsCheckPending = nil

		if WorldQuestList:UpdateLockedQuests() then
			Util:Debug("Locked Special Assignments changed")
			self:Update(true)

			-- the unlocked quest may not be on the map yet when the lock disappears
			C_Timer.After(5, function()
				self:Update(true)
			end)
		end
	end)
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
	local dataProvider = CreateFromMixins(ns.WarbandWorldQuestDataProviderMixin)

	dataProvider:OnLoad()
	dataProvider.character = self.character

	Settings:InvokeAndRegisterCallback("reward_type_filters", dataProvider.UpdateRewardTypeFilters, dataProvider)
	Settings:InvokeAndRegisterCallback(Settings:WrapOptionCallback("log_progress_shown", dataProvider.SetProgressTextOption, dataProvider))

	WarbandWorldQuestMapCanvasDataProvider = CreateFromMixins(ns.WarbandWorldQuestMapCanvasDataProviderMixin)
	WarbandWorldQuestMapCanvasDataProvider:OnLoad(dataProvider)

	return dataProvider
end

function WarbandWorldQuest:AddTrackedQuestsToObjectivesPanel()
	for _, quest in ipairs(self.WorldQuestList:GetAllQuests()) do
		quest:SyncWarbandTracking()
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
		if not WarbandWorldQuest.updatePending then
			WarbandWorldQuest.updatePending = true
			C_Timer.After(0, function()
				WarbandWorldQuest.updatePending = nil
				WarbandWorldQuest:Update()
			end)
		end
	end)

	WarbandWorldQuest:RegisterEvent("QUEST_TURNED_IN", function(event, questID, xpReward, moneyReward)
		WarbandWorldQuest:SetRewardsClaimed(questID)
		WarbandWorldQuest:QueueLockedQuestsCheck()
	end)

	WarbandWorldQuest:RegisterEvent("QUEST_WATCH_LIST_CHANGED", function(event, questID)
		local quest = questID and WorldQuestList:GetQuest(questID)
		if quest == nil then
			return
		end

		-- a turn-in or expiry also removes the watch, which should not untrack the quest for the warband
		C_Timer.After(0.5, function()
			if quest:IsCompleted() or not C_TaskQuest.IsActive(questID) then
				return
			end

			local watchType = C_QuestLog.GetQuestWatchType(questID)
			local autoTracked = WarbandWorldQuest.character.autoTracked or {}

			if watchType == Enum.QuestWatchType.Manual then
				if not autoTracked[questID] then
					quest:SetWarbandTracked(true)
				end
			elseif watchType == nil and (quest.tracked or autoTracked[questID]) then
				autoTracked[questID] = nil
				quest:SetWarbandTracked(false)
			end
		end)
	end)

	WarbandWorldQuest:RegisterEvent("AREA_POIS_UPDATED", function()
		WarbandWorldQuest:QueueLockedQuestsCheck()
	end)

	WarbandWorldQuest:RegisterEvent("PLAYER_FLAGS_CHANGED", function()
		if not WarbandWorldQuest.warModeScanned and C_PvP.IsWarModeActive() then
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
				[2537] = true, -- Quel'Thalas
				[2274] = false, -- Khaz Algar
				[1978] = false, -- Dragon Isles
				[1550] = false, -- Shadowlands
				[619] = false, -- Legion
				[875] = false, -- Zandalar
				[876] = false, -- Kul Tiras
			},
			["reward_type_filters"] = {
				["c:0"] = true, -- Gold
			},
			["pins_progress_shown"] = true,
			["pins_completed_shown"] = true,
			["pins_tooltip_shown"] = { enabled = true },
			["pins_inactive_opacity"] = 0.6,
			["pins_min_display_level"] = Enum.UIMapType.Continent,
			["log_scanning_icon_shown"] = true,
			["log_is_default_tab"] = true,
			["log_section_completed_shown"] = { enabled = true, option = "CURRENT" },
			["log_all_quests_shown"] = false,
			["log_auto_track_filtered"] = false,
			["log_time_left_shown"] = true,
			["log_warband_rewards_shown"] = { enabled = true, option = "NOT_COLLECTED" },
			["log_progress_shown"] = { enabled = true, option = "CLAIMED" },
			["next_reset_exclude_types"] = {},
			["next_reset_exclude_maps"] = {
				[2599] = false, -- Val
				[2600] = false, -- Naigtal
			},
		}

		if WarbandWorldQuestSettings then -- Migration
		end

		Settings:RegisterSettings("WarbandWorldQuestSettings", DefaultWarbandWorldQuestSettings)
		WarbandWorldQuestDB = WarbandWorldQuestDB or DefaultWarbandWorldQuestDB

		WarbandWorldQuest.db = WarbandWorldQuestDB
		Util.debug = WarbandWorldQuestDB.debug
	end)
end
