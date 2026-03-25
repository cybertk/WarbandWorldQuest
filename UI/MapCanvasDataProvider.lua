local _, ns = ...

WarbandWorldQuestPinMixin = CreateFromMixins(WorldQuestPinMixin)

function WarbandWorldQuestPinMixin:CheckMouseButtonPassthrough(...) end

function WarbandWorldQuestPinMixin:OnMouseEnter()
	local tooltip = WarbandWorldQuestGameTooltip

	tooltip:SetOwner(self, "ANCHOR_RIGHT")
	self:AddQuestToTooltip(tooltip)
	tooltip:Show()

	POIButtonMixin.OnEnter(self)
end

function WarbandWorldQuestPinMixin:OnMouseLeave()
	WarbandWorldQuestGameTooltip:Hide()
	POIButtonMixin.OnLeave(self)
end

function WarbandWorldQuestPinMixin:OnClick(button)
	self:ToggleTracked()
end

function WarbandWorldQuestPinMixin:AddQuestToTooltip(tooltip)
	local questID = self.quest.ID

	if not HaveQuestData(questID) then
		GameTooltip_SetTitle(tooltip, RETRIEVING_DATA, RED_FONT_COLOR)
		GameTooltip_SetTooltipWaitingForData(tooltip, true)
		tooltip:Show()
		return
	end

	local quest = self.quest

	do
		local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(questID)

		GameTooltip_SetTitle(tooltip, title)
		QuestUtils_AddQuestTypeToTooltip(tooltip, questID, NORMAL_FONT_COLOR)

		local factionData = factionID and C_Reputation.GetFactionDataByID(factionID)
		if factionData then
			local questAwardsReputationWithFaction = C_QuestLog.DoesQuestAwardReputationWithFaction(questID, factionID)
			local reputationYieldsRewards = (not capped) or C_Reputation.IsFactionParagonForCurrentPlayer(factionID)
			if questAwardsReputationWithFaction and reputationYieldsRewards then
				tooltip:AddLine(factionData.name)
			else
				tooltip:AddLine(factionData.name, GRAY_FONT_COLOR:GetRGB())
			end
		end
	end

	do
		local secondsRemaining = quest.resetTime - GetServerTime()
		local formattedTime = WorldQuestsSecondsFormatter:Format(secondsRemaining)

		GameTooltip_AddNormalLine(tooltip, MAP_TOOLTIP_TIME_LEFT:format(QuestUtils_GetQuestTimeColor(secondsRemaining):WrapTextInColorCode(formattedTime)))
	end

	do
		local questCompleted = quest:IsCompleted()
		local numObjectives = self.numbObjectives or C_QuestLog.GetNumQuestObjectives(questID)

		for objectiveIndex = 1, numObjectives do
			local objectiveText, objectiveType, finished, numFulfilled, numRequired = GetQuestObjectiveInfo(questID, objectiveIndex, false)

			local color = questCompleted and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR

			if questCompleted then
				if objectiveType == "progressbar" then
					objectiveText = objectiveText:gsub("0%%", "100%%")
				else
					objectiveText = objectiveText:gsub("0/" .. numRequired, numRequired .. "/" .. numRequired)
				end
			end
			GameTooltip_AddColoredLine(tooltip, QUEST_DASH .. objectiveText, color)
		end

		if questCompleted then
			GameTooltip_AddBlankLineToTooltip(tooltip)
			GameTooltip_AddColoredLine(tooltip, ERR_QUEST_ALREADY_DONE, GREEN_FONT_COLOR)
		elseif not quest:IsPlayerEligible() then
			GameTooltip_AddBlankLineToTooltip(tooltip)
			GameTooltip_AddColoredLine(tooltip, ERR_QUEST_NEED_PREREQS, RED_FONT_COLOR)
		else
			GameTooltip_AddQuestRewardsToTooltip(tooltip, questID, TOOLTIP_QUEST_REWARDS_STYLE_WORLD_QUEST)
		end
	end
end

function WarbandWorldQuestPinMixin:ToggleTracked()
	local questID = self.quest.ID

	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

	if ChatFrameUtil.TryInsertQuestLinkForQuestID(questID) then
		return
	end

	if not self.quest:IsPlayerEligible() then
		return
	end

	local watchType = C_QuestLog.GetQuestWatchType(questID)
	local isSuperTracked = C_SuperTrack.GetSuperTrackedQuestID() == questID

	if IsShiftKeyDown() then
		if watchType == Enum.QuestWatchType.Manual or (watchType == Enum.QuestWatchType.Automatic and isSuperTracked) then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			QuestUtil.UntrackWorldQuest(self.questID)
		else
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			QuestUtil.TrackWorldQuest(self.questID, Enum.QuestWatchType.Manual)
		end
	else
		if isSuperTracked then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			C_SuperTrack.SetSuperTrackedQuestID(0)
		else
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

			if watchType ~= Enum.QuestWatchType.Manual then
				QuestUtil.TrackWorldQuest(questID, Enum.QuestWatchType.Automatic)
			end

			C_SuperTrack.SetSuperTrackedQuestID(questID)
		end
	end
end
