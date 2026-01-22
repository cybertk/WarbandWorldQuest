local addonName, ns = ...

local L = ns.L
local Util = ns.Util
local QuestRewards = ns.QuestRewards
local WorldQuestList = ns.WorldQuestList
local CharacterStore = ns.CharacterStore
local Settings = ns.Settings

WarbandRewardSourceIconButtonMixin = {}

function WarbandRewardSourceIconButtonMixin:OnMouseDown()
	self.Display:SetPoint("CENTER", 1, -1)
end

function WarbandRewardSourceIconButtonMixin:OnMouseUp()
	self.Display:SetPoint("CENTER")

	local reward = self:GetParent().data.reward

	if WarbandRewardSourceIconButtonMixin.tracking == self then
		PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_OFF)
		C_Map.ClearUserWaypoint()

		WarbandRewardSourceIconButtonMixin.tracking = nil
	elseif reward.poi then
		if C_SuperTrack.IsSuperTrackingMapPin() then
			PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_OFF)
			C_SuperTrack.ClearSuperTrackedMapPin()
		else
			PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON)
			C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, reward.poi)
		end
	elseif C_Map.CanSetUserWaypointOnMap(reward.map) then
		local point = reward:GenerateMapPoint()
		C_Map.SetUserWaypoint(point)

		if point.position:IsZero() then
			Util:Info(YELLOW_FONT_COLOR:WrapTextInColorCode(L["log_entry_position_unknown"]:format(select(8, EJ_GetInstanceInfo(reward.instance)))))
			PlaySound(SOUNDKIT.QUEST_SESSION_DECLINE)
		else
			PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON)
			C_SuperTrack.SetSuperTrackedUserWaypoint(true)
			WarbandRewardSourceIconButtonMixin.tracking = self
		end
	end
end

function WarbandRewardSourceIconButtonMixin:Update(isRaid)
	self.Display:SetAtlas(isRaid and "Raid" or "Dungeon", true)
	self.Underlay:SetAtlas(nil)
end

WarbandRewardsTrackerEncounterProgressButtonMixin = {}

function WarbandRewardsTrackerEncounterProgressButtonMixin:Init(elementData)
	self.data = elementData

	local displayInfo = select(4, EJ_GetCreatureInfo(1, elementData.ID))
	if displayInfo then
		SetPortraitTextureFromCreatureDisplayID(self.Background, displayInfo)
		self.Background:Show()
	else
		self.Background:Hide()
	end

	self.Difficulty:SetText(self.difficultyShown and Util:GetDifficultyCode(self.data.difficultyID) or "")
	local complete = self:IsFlaggedDefeat()

	self.Progress:SetText(format("%d/%d", #self.data.fulfilled, #self.data.fulfilled + #self.data.unknown + #self.data.pending))
	self.Progress:SetTextColor((complete and GREEN_FONT_COLOR or YELLOW_FONT_COLOR):GetRGB())

	self.DefeatedOpacity:SetShown(complete)
	self.DefeatedOverlay:SetShown(complete)
	self.Background:SetDesaturation(complete and 0.7 or 0)

	self:UpdateHighlight()
end

function WarbandRewardsTrackerEncounterProgressButtonMixin:SetDifficultyShown(show)
	self.difficultyShown = show
end

function WarbandRewardsTrackerEncounterProgressButtonMixin:IsFlaggedDefeat()
	if self.data.sharedDifficulties then
		return self.data.encounter:IsAnyDifficultyComplete()
	else
		return self.data.encounter:IsComplete(self.data.difficultyID)
	end
end

function WarbandRewardsTrackerEncounterProgressButtonMixin:UpdateHighlight()
	if not IsInInstance() then
		return
	end

	local isCurrentInstance, isCurrentDifficulty =
		Util:IsInInstance(self.data.encounter:GetDungeonID(), unpack(self.data.sharedDifficulties or { self.data.difficultyID }))

	local color = isCurrentInstance
			and (isCurrentDifficulty and (self:IsFlaggedDefeat() and GREEN_FONT_COLOR or YELLOW_FONT_COLOR) or self.data.sharedDifficulties and RED_FONT_COLOR or DISABLED_FONT_COLOR)
		or DISABLED_FONT_COLOR

	self.Background:SetDesaturation((isCurrentInstance and isCurrentDifficulty) and 0 or 0.9)
	self.Progress:SetTextColor(color:GetRGB())

	if self.difficultyShown then
		self.Difficulty:SetTextColor(color:GetRGB())
	end
end

function WarbandRewardsTrackerEncounterProgressButtonMixin:OnEnter()
	local tooltip = GetAppropriateTooltip()
	local encounter = self.data.encounter

	tooltip:SetOwner(self, "ANCHOR_RIGHT")
	tooltip:SetText(self.data.encounter:GetName(), WHITE_FONT_COLOR:GetRGB())

	if self.data.sharedDifficulties then
		tooltip:AddLine(L["log_enounter_tooltip_difficulty_shared"])
		for _, difficultyID in ipairs(self.data.sharedDifficulties) do
			local defeated = self.data.encounter:IsComplete(difficultyID)
			tooltip:AddDoubleLine(
				WHITE_FONT_COLOR:WrapTextInColorCode(Util:GetDifficultyName(difficultyID)),
				format("|cn%s_FONT_COLOR:%s|r", defeated and "RED" or "GREEN", defeated and BOSS_DEAD or AVAILABLE)
			)
		end
	else
		tooltip:AddDoubleLine(
			LFG_LIST_DIFFICULTY .. ": " .. WHITE_FONT_COLOR:WrapTextInColorCode(Util:GetDifficultyName(self.data.difficultyID)),
			GREEN_FONT_COLOR:WrapTextInColorCode(L["log_enounter_tooltip_difficulity_instruction"]:format("|A:NPE_RightClick:16:16|a"))
		)
	end

	if IsInInstance() then
		local isCurrentInstance, isCurrentDifficulty =
			Util:IsInInstance(self.data.encounter:GetDungeonID(), unpack(self.data.sharedDifficulties or { self.data.difficultyID }))

		if isCurrentInstance and not isCurrentDifficulty then
			tooltip:AddLine(L["log_enounter_tooltip_difficulty_invalid"], RED_FONT_COLOR:GetRGB())
		end
	end

	tooltip:AddLine(" ")
	tooltip:AddLine(L["log_entry_tooltip_characters_completed"] .. ": " .. WHITE_FONT_COLOR:WrapTextInColorCode(#self.data.fulfilled), NORMAL_FONT_COLOR:GetRGB())
	for _, character in ipairs(self.data.fulfilled) do
		tooltip:AddDoubleLine(
			character:GetNameInClassColor(),
			WHITE_FONT_COLOR:WrapTextInColorCode(date("%m-%d %H:%M", character:GetEncounter(self.data.ID):GetCompletedTime(self.data.difficultyID)))
		)
	end

	if #self.data.fulfilled > 0 then
		tooltip:AddLine(" ")
	end

	tooltip:AddLine(L["log_entry_tooltip_characters_pending"] .. ": " .. WHITE_FONT_COLOR:WrapTextInColorCode(#self.data.pending), NORMAL_FONT_COLOR:GetRGB())
	for _, character in ipairs(self.data.pending) do
		tooltip:AddLine(character:GetNameInClassColor())
	end

	if #self.data.unknown > 0 then
		tooltip:AddLine(" ")
		tooltip:AddLine(L["log_entry_tooltip_characters_unknown"] .. ": " .. WHITE_FONT_COLOR:WrapTextInColorCode(#self.data.unknown), NORMAL_FONT_COLOR:GetRGB())
		for _, character in ipairs(self.data.unknown) do
			tooltip:AddLine(character:GetNameInClassColor())
		end
	end

	tooltip:Show()
end

function WarbandRewardsTrackerEncounterProgressButtonMixin:OnLeave()
	GetAppropriateTooltip():Hide()
end

function WarbandRewardsTrackerEncounterProgressButtonMixin:OnClick(button)
	if button == "LeftButton" then
		PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
		C_Map.OpenWorldMap(self.data.encounter:GetDungeonAreaMapID())
	elseif button == "RightButton" then
		local difficultyID = self.data.difficultyID

		if difficultyID == GetRaidDifficultyID() or difficultyID == GetLegacyRaidDifficultyID() or difficultyID == GetDungeonDifficultyID() then
			PlaySound(SOUNDKIT.LFG_DENIED)
		else
			PlaySound(SOUNDKIT.LFG_ROLE_CHECK)
			if IsLegacyDifficulty(difficultyID) then
				SetLegacyRaidDifficultyID(difficultyID, true)
			else
				SetDungeonDifficultyID(difficultyID)
				SetRaidDifficultyID(difficultyID)
			end
		end
	end
end

WarbandRewardsTrackerInstanceEntryMixin = {}
WarbandRewardsTrackerInstanceEntryMixin.EncounterWidth = 35

function WarbandRewardsTrackerInstanceEntryMixin:Init(elementData)
	self.data = elementData

	self.Background:SetShown(self.data.reward:IsFocused())
	self.Name:SetText(self.data.reward:GetName())
	self.TimeLeft:SetText(self:FormatTimeLeft(self.data))

	if self.data.reward.dungeon then
		self.IconButton:Update(DifficultyUtil.GetMaxPlayers(self.data.reward.difficulties[1]) > 5)
	else
		self.IconButton:Update(false, true)
	end

	self:UpdateStatus()
	self:UpdateProgress()
	self:UpdateLocation()

	elementData.dirty = nil
end

function WarbandRewardsTrackerInstanceEntryMixin:UpdateStatus()
	local reward = self.data.reward
	local text = ""

	local attemptsOption = Settings:GetOption("log_attempts_shown")

	if attemptsOption == "TOTAL" then
		text = text .. " - " .. reward.totalAttempts
	elseif attemptsOption == "RESET" then
		text = text .. " - " .. reward.attempts
	end

	self.Status:SetTextToFit(text)

	local encountersWidth = self.data.showEncountersOnNewLine and 0 or self.EncounterWidth * (2 + #self.data.encounters)
	self.Name:SetWidth(math.min(self.Name:GetUnboundedStringWidth(), self:GetWidth() - self.Status:GetWidth() - encountersWidth))
end

function WarbandRewardsTrackerInstanceEntryMixin:UpdateLocation(mapID)
	mapID = mapID or WorldMapFrame:GetMapID()

	local reward = self.data.reward
	local text = self.showZone and C_Map.GetMapInfo(reward.map).name or EJ_GetInstanceInfo(reward.instance)

	if reward.dungeon == select(8, GetInstanceInfo()) or mapID == reward.map then
		text = YELLOW_FONT_COLOR:WrapTextInColorCode(text)
	end

	self.Location:SetText(text)
	if self.Location:GetRight() > self:GetRight() then
		self.Location:SetWidth(self:GetRight() - self.Location:GetLeft() - 40)
	else
		self.Location:SetWidth(0)
	end
end

function WarbandRewardsTrackerInstanceEntryMixin:UpdateProgress()
	for _, button in ipairs(self.Encounters or {}) do
		self.owner.encounterButtonPool:Release(button)
	end

	self.Encounters = {}

	for i, encounterData in ipairs(self.data.encounters) do
		local button = self.owner.encounterButtonPool:Acquire()
		button:SetParent(self)
		button:SetDifficultyShown(#self.data.encounters > self.data.numUniqueEncounters)
		button:Init(encounterData)
		button:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -#self.Encounters * (button:GetWidth() - 2) - 3, 0)
		button:Show()

		table.insert(self.Encounters, 1, button)
	end
end

function WarbandRewardsTrackerInstanceEntryMixin:FormatTimeLeft(elementData)
	return Settings:Get("log_time_left_shown") and Util.FormatTimeDuration(elementData.reward.resetTime - GetServerTime()) .. " - " or ""
end

function WarbandRewardsTrackerInstanceEntryMixin:ToggleTracked()
	PlaySound(tracked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	self.data.quest:SetTracked(not self.data.quest:IsTracked())
	self:UpdateStatus()
end

function WarbandRewardsTrackerInstanceEntryMixin:OnEnter()
	self:UpdateTooltip()
	-- self.owner:HighlightMapPin(self.data.quest.ID, true)
end

function WarbandRewardsTrackerInstanceEntryMixin:OnLeave()
	GetAppropriateTooltip():Hide()
	-- self.owner:HighlightMapPin(self.data.quest.ID, false)
end

function WarbandRewardsTrackerInstanceEntryMixin:OnClick(button)
	local reward = self.data.reward

	self:UpdateLocation()

	if button == "LeftButton" then
		if IsShiftKeyDown() then
			local link = select(8, EJ_GetInstanceInfo(reward.instance))
			ChatEdit_TryInsertChatLink(link)
		elseif IsControlKeyDown() then
			DressUpMount(reward:GetMountID())
		else
			PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
			C_Map.OpenWorldMap(reward.map)
		end
	elseif button == "RightButton" then
		MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
			rootDescription:SetTag("MENU_QUEST_MAP_WARBAND_REWARD_LOG")

			local isFocused = reward:IsFocused()
			rootDescription:CreateButton(isFocused and STOP_SUPER_TRACK_QUEST or SUPER_TRACK_QUEST, function()
				reward:SetFocused(not isFocused)
				self.owner:Refresh(true, true)
			end)

			local isInactive = reward:IsInactive()
			rootDescription:CreateButton((isInactive and CANCEL .. ": " or "") .. MOVE_TO_INACTIVE, function()
				reward:SetInactive(not isInactive)
				self.owner:Refresh(true, true)
			end)
		end)
	end
end

function WarbandRewardsTrackerInstanceEntryMixin:UpdateTooltip()
	local tooltip = GetAppropriateTooltip()
	local reward = self.data.reward

	tooltip:SetOwner(self, "ANCHOR_RIGHT")

	if reward.mount then
		tooltip:SetSpellByID(select(2, C_MountJournal.GetMountInfoByID(reward:GetMountID())))
	end

	if reward:HasClaimedDate() then
		tooltip:AddLine(COLLECTED .. ": " .. date("%m-%d %H:%M", reward.claimedAt), GREEN_FONT_COLOR:GetRGB())
	elseif not reward:IsClaimed() then
		tooltip:AddLine(MOUNT_JOURNAL_NOT_COLLECTED, RED_FONT_COLOR:GetRGB())
	end

	tooltip:AddLine(" ")
	tooltip:AddLine(L["log_entry_tooltip_attempts_reset"]:format(WHITE_FONT_COLOR:WrapTextInColorCode(reward.attempts), NORMAL_FONT_COLOR:GetRGB()))
	tooltip:AddLine(L["log_entry_tooltip_attempts_total"]:format(WHITE_FONT_COLOR:WrapTextInColorCode(reward.totalAttempts), NORMAL_FONT_COLOR:GetRGB()))

	tooltip:AddLine(" ")
	tooltip:AddLine(VIEW_IN_DRESSUP_FRAME .. " (CTRL+|A:NPE_LeftClick:16:16|a)", GREEN_FONT_COLOR:GetRGB())

	tooltip:Show()
end
