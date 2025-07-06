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
	for _, pin in ipairs({ WarbandQuestTrackerPinMixin }) do
		hooksecurefunc(pin, "OnMouseEnter", function(pin)
			WarbandQuestTrackerPage:HighlightRow(pin.questID, true)

			if Settings:Get("pins_tooltip_shown") then
				local tooltipModifier = Settings:Get("pins_tooltip_modifier")

				if not tooltipModifier or (tooltipModifier == "CTRL" and IsControlKeyDown()) or (tooltipModifier == "ALT" and IsAltKeyDown()) then
					self.dataProvider:UpdatePinTooltip(GameTooltip, pin)
				end
			end
		end)

		hooksecurefunc(pin, "OnMouseLeave", function(pin)
			WarbandQuestTrackerPage:HighlightRow(pin.questID, false)
		end)
	end

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

local QuestsFilter = {
	remainingQuests = {
		11813, -- Honor the Flame
		11772, -- Desecrate the Fire!
	},
	filters = {},
}

function QuestsFilter:Load()
	for i = #self.remainingQuests, 1, -1 do
		local title = C_QuestLog.GetTitleForQuestID(self.remainingQuests[i])

		if title then
			self.filters[title] = true
			table.remove(self.remainingQuests, i)
		end
	end

	if #self.remainingQuests == 0 then
		self.loaded = true
	end
end

function QuestsFilter:Pass(info)
	if not self.loaded then
		self:Load()
	end

	return self.filters[C_QuestLog.GetTitleForQuestID(info.questID)]
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

	if self.activeEvent == nil then
		self.activeEvent = Util:GetCalendarActiveEvents()[341]
	end

	local changed
	if self.activeEvent then
		changed = WorldQuestList:Scan(
			Settings:Get("maps_to_scan"),
			isNewScanSession,
			GenerateClosure(QuestsFilter.Pass, QuestsFilter),
			{ resetTime = Util:GetTimestampFromCalendarTime(self.activeEvent.endTime), tag = -1, tagName = self.activeEvent.title }
		)
	end

	if changed then
		local secondsToReset = (select(2, WorldQuestList:NextResetQuests()) or 0) - GetServerTime() + 60
		if secondsToReset > 0 and secondsToReset < SECONDS_PER_DAY then
			self.resetTimer = C_Timer.NewTimer(secondsToReset, GenerateClosure(self.Update, self, true))
		end
		self.character:SetQuests(WorldQuestList:GetAllQuests())
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
	local dataProvider = CreateFromMixins(WarbandQuestTrackerDataProviderMixin)

	dataProvider:OnLoad()
	dataProvider.character = self.character

	Settings:InvokeAndRegisterCallback("pins_min_display_level", dataProvider.SetMinPinDisplayLevel, dataProvider)
	Settings:InvokeAndRegisterCallback("pins_progress_shown", dataProvider.SetProgressOnPinShown, dataProvider)
	Settings:InvokeAndRegisterCallback("pins_completed_shown", dataProvider.SetPinOfCompletedQuestShown, dataProvider)
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

	print("Usage: |n/wqt debug - Turn on/off debugging mode")
end

do
	_G["WarbandQuestTracker"] = WarbandWorldQuest

	SLASH_WARBAND_QUEST_TRACKER1 = "/WarbandQuestTracker"
	SLASH_WARBAND_QUEST_TRACKER2 = "/wqt"
	function SlashCmdList.WARBAND_QUEST_TRACKER(msg, editBox)
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

		if WarbandQuestTrackerPinMixin.waypointQuest.ID == questID then
			print("remove waypoint", questID)
			C_Map.ClearUserWaypoint()
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
		-- /dump WorldMapFrame:GetMapID()
		local DefaultWarbandWorldQuestSettings = {
			["group_collapsed_states"] = {},
			["maps_to_scan"] = {
				[2274] = true, -- Khaz Algar
				[1978] = false, -- Dragon Isles
				[876] = false, -- Kul Tiras
				[875] = false, -- Zandalar
				[619] = false, -- Broken Isles
				[424] = false, -- Pandaria
				[113] = false, -- Northend
				[101] = false, -- Outland
				[13] = false, -- Eastern Kingdoms
				[12] = false, -- Kalimdor
			},
			["reward_type_filters"] = 1,
			["pins_progress_shown"] = true,
			["pins_completed_shown"] = true,
			["pins_tooltip_shown"] = true,
			["pins_tooltip_modifier"] = nil,
			["pins_min_display_level"] = Enum.UIMapType.Continent,
			["log_scanning_icon_shown"] = true,
			["log_is_default_tab"] = true,
			["next_reset_exclude_types"] = {},
		}

		Settings:RegisterSettings("WarbandQuestTrackerSettings", DefaultWarbandWorldQuestSettings)
		WarbandQuestTrackerDB = WarbandQuestTrackerDB or DefaultWarbandWorldQuestDB

		WarbandWorldQuest.db = WarbandQuestTrackerDB
		Util.debug = WarbandQuestTrackerDB.debug
	end)
end
