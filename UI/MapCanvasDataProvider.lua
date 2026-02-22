local _, ns = ...

local Util = ns.Util
local Settings = ns.Settings

WarbandWorldQuestIconButtonMixin = {}

function WarbandWorldQuestIconButtonMixin:OnMouseEnter()
	if self:GetParent().OnMouseEnter then
		self:GetParent():OnMouseEnter()
	end
end

function WarbandWorldQuestIconButtonMixin:OnMouseLeave()
	if self:GetParent().OnMouseLeave then
		self:GetParent():OnMouseLeave()
	end
end

function WarbandWorldQuestIconButtonMixin:OnMouseDown()
	self.Display:SetPoint("CENTER", 1, -1)
end

function WarbandWorldQuestIconButtonMixin:OnMouseUp()
	self.Display:SetPoint("CENTER")
end

function WarbandWorldQuestIconButtonMixin:OnClick(button)
	self:GetParent():ToggleTracked()
end

function WarbandWorldQuestIconButtonMixin:SetDesaturated(desaturated)
	self:GetNormalTexture():SetDesaturated(desaturated)
end

function WarbandWorldQuestIconButtonMixin:SetSelected(selected)
	if selected then
		self.selectedAtlas = self:GetNormalTexture():GetAtlas()
		self:GetNormalTexture():SetAtlas("worldquest-questmarker-epic-supertracked", true)
	else
		self:GetNormalTexture():SetAtlas(self.selectedAtlas, true)
		self.selectedAtlas = nil
	end
end

function WarbandWorldQuestIconButtonMixin:Update(questID)
	local tag = C_QuestLog.GetQuestTagInfo(questID)

	self.Display:SetAtlas(QuestUtil.GetWorldQuestAtlasInfo(questID, tag))

	if tag.worldQuestType == Enum.QuestTagType.Capstone then
		self.Underlay:SetAtlas("worldquest-Capstone-Banner", true)
	elseif tag.isElite then
		self.Underlay:SetAtlas("worldquest-questmarker-dragon", true)
	else
		self.Underlay:SetAtlas(nil)
	end
end

WarbandWorldQuestPinMixin = {}

function WarbandWorldQuestPinMixin:OnMouseEnter()
	local tooltip = WarbandWorldQuestGameTooltip

	tooltip:SetOwner(self, "ANCHOR_RIGHT")
	self:AddQuestToTooltip(tooltip)
	tooltip:Show()

	self.Progress:LockHighlight()
	self:SetFrameLevel(self:GetFrameLevel() + 1)
end

function WarbandWorldQuestPinMixin:OnMouseLeave()
	self:SetFrameLevel(self:GetFrameLevel() - 1)
	self.Progress:UnlockHighlight()

	WarbandWorldQuestGameTooltip:Hide()
end

function WarbandWorldQuestPinMixin:OnAcquired(quest, mapFrame)
	self.quest = quest
	self.questID = quest.ID -- compatible to native pin
	self.mapFrame = mapFrame

	self:SetParent(mapFrame:GetCanvas())
	self.Icon:Update(quest.ID)
	self:SetFrameLevel(WorldMapFrame:GetPinFrameLevelsManager():GetValidFrameLevel("PIN_FRAME_LEVEL_WORLD_QUEST") - 1) -- MAP_CANVAS_PIN_FRAME_LEVEL_DEFAULT PIN_FRAME_LEVEL_WORLD_QUEST

	self.Progress:GetNormalFontObject():SetFontHeight(9)

	if not HaveQuestRewardData(quest.ID) then
		C_TaskQuest.RequestPreloadRewardData(quest.ID)
	end

	self:Show()
end

function WarbandWorldQuestPinMixin:OnReleased()
	self:Hide()
	self:ClearAllPoints()
end

function WarbandWorldQuestPinMixin:SetMap(map)
	self.map = map
end

function WarbandWorldQuestPinMixin:SetPosition(x, y)
	local canvas = self.mapFrame:GetCanvas()
	local scale = 1.0 / self.mapFrame:GetCanvasScale() * Lerp(1, 1, Saturate(self.mapFrame:GetCanvasZoomPercent()))

	self:SetScale(scale)
	self:ClearAllPoints()
	self:SetPoint("CENTER", canvas, "TOPLEFT", (canvas:GetWidth() * x) / scale, -(canvas:GetHeight() * y) / scale)
end

function WarbandWorldQuestPinMixin:SetIconShown(shown)
	self.Icon:SetShown(shown)
end

function WarbandWorldQuestPinMixin:RefreshVisuals()
	local completed = self.quest:IsCompleted()
	local ineligible = not self.quest:IsPlayerEligible()

	local iconShown = completed or ineligible or (self.map.mapType ~= Enum.UIMapType.Zone and C_SuperTrack.GetSuperTrackedQuestID() ~= self.quest.ID)

	self.CompletedCheck:SetShown(completed)
	self.Icon:SetShown(iconShown)
	self.Icon:SetDesaturated(ineligible)

	self.Debug:SetColorTexture(iconShown and 0 or 1, 0, 0)
end

function WarbandWorldQuestPinMixin:UpdateProgressLabel(text)
	self.Progress:SetText(text or "")
	self.Progress:SetShown(text ~= nil)
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

local WarbandWorldQuestMapCanvasDataProviderMixin = {}

function WarbandWorldQuestMapCanvasDataProviderMixin:OnLoad(data)
	self.data = data

	self.minPinDisplayLevel = Enum.UIMapType.Continent
	self.maxPinDisplayLevel = Enum.UIMapType.Zone

	self.activePins = {}
	self.pinPool = CreateFramePool("Frame", nil, "WarbandWorldQuestPinTemplate", function(pool, pin)
		pin:OnReleased()
	end)

	Settings:InvokeAndRegisterCallback("pins_min_display_level", self.SetMinPinDisplayLevel, self)
	Settings:InvokeAndRegisterCallback("pins_progress_shown", self.SetProgressOnPinShown, self)
	Settings:InvokeAndRegisterCallback("pins_completed_shown", self.SetPinOfCompletedQuestShown, self)
	Settings:InvokeAndRegisterCallback("pins_inactive_opacity", self.SetPinOfInactiveQuestOpacity, self)
	Settings:RegisterCallback("log_progress_shown", self.RefreshAllData, self)

	hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function(mapFrame)
		local scale = mapFrame:GetCanvasScale()

		if self.scale ~= scale then
			self.scale = scale
			self:RefreshAllData()
		end
	end)

	hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
		self:RefreshAllData()
	end)

	WorldMapFrame:HookScript("OnShow", function()
		self.data:RegisterCallback(DataProviderMixin.Event.OnSizeChanged, self.OnDataProviderSizeChanged, self)
	end)

	WorldMapFrame:HookScript("OnHide", function()
		self.data:UnregisterCallback(DataProviderMixin.Event.OnSizeChanged, self)
	end)

	hooksecurefunc(C_SuperTrack, "SetSuperTrackedQuestID", function(questID)
		if questID == 0 then
			self:RefreshAllData()
		elseif self.activePins[questID] then
			self.activePins[questID]:SetIconShown(false)
		end
	end)
end

function WarbandWorldQuestMapCanvasDataProviderMixin:OnDataProviderSizeChanged()
	Util:Debug("OnDataProviderSizeChanged")

	self:RefreshAllData()
	self:UpdateAllInactivePinsOpacity()
end

function WarbandWorldQuestMapCanvasDataProviderMixin:RefreshAllData()
	Util:Debug("RefreshAllData")

	local mapFrame = WorldMapFrame
	if not mapFrame:IsShown() then
		return
	end

	local pinsToRemove = {}
	for questID in pairs(self.activePins) do
		pinsToRemove[questID] = true
	end

	local map = C_Map.GetMapInfo(mapFrame:GetMapID())

	for position, row in pairs(self:ShouldMapShowPins(map) and self.data:EnumerateActiveQuestsByMapID(map.mapID, self.showPinOfCompletedQuest) or {}) do
		local quest = row.quest
		local pin = self.activePins[quest.ID]

		if not pin then
			pin = self.pinPool:Acquire()
			pin:OnAcquired(quest, mapFrame)

			self.activePins[quest.ID] = pin
			Util:Debug("Added pin for quest", quest.ID, quest:GetName(), map.mapID)
		end

		pin:SetMap(map)
		pin:SetPosition(unpack(position))
		pin:RefreshVisuals()
		pin:UpdateProgressLabel(self.showProgressOnPin and row:GetProgressText() or nil)

		pinsToRemove[quest.ID] = nil
	end

	for questID in pairs(pinsToRemove) do
		local pin = self.activePins[questID]

		self.activePins[questID] = nil
		self.pinPool:Release(pin)
	end
end

function WarbandWorldQuestMapCanvasDataProviderMixin:ShouldMapShowPins(mapInfo)
	local mapType = mapInfo.mapType

	return mapType >= self.minPinDisplayLevel and mapType <= self.maxPinDisplayLevel
end

function WarbandWorldQuestMapCanvasDataProviderMixin:UpdatePinAlpha(pin, force)
	if self.pinOfInactiveQuestOpacity or force then
		local alpha = self.data:IsFilteredQuest(pin.questID) and 1 or self.pinOfInactiveQuestOpacity
		if alpha ~= pin:GetAlpha() then
			pin:SetAlpha(alpha)
		end
	end
end

function WarbandWorldQuestMapCanvasDataProviderMixin:UpdateAllInactivePinsOpacity()
	for pin in WorldMapFrame:EnumeratePinsByTemplate(WorldMap_WorldQuestDataProviderMixin:GetPinTemplate()) do
		self:UpdatePinAlpha(pin)
	end

	if not self.alphaHooked and self.pinOfInactiveQuestOpacity ~= 1 then
		hooksecurefunc(WorldMap_WorldQuestPinMixin, "ApplyCurrentAlpha", function(pin)
			self:UpdatePinAlpha(pin)
		end)

		self.alphaHooked = true
	end
end

function WarbandWorldQuestMapCanvasDataProviderMixin:SetProgressOnPinShown(shown)
	self.showProgressOnPin = shown
	self:RefreshAllData()
end

function WarbandWorldQuestMapCanvasDataProviderMixin:SetMinPinDisplayLevel(uiMapType)
	self.minPinDisplayLevel = uiMapType
	self:RefreshAllData()
end

function WarbandWorldQuestMapCanvasDataProviderMixin:SetPinOfCompletedQuestShown(shown)
	self.showPinOfCompletedQuest = shown
	self:RefreshAllData()
end

function WarbandWorldQuestMapCanvasDataProviderMixin:SetPinOfInactiveQuestOpacity(alpha)
	self.pinOfInactiveQuestOpacity = alpha
	self:UpdateAllInactivePinsOpacity()
end

function WarbandWorldQuestMapCanvasDataProviderMixin:SetPinGlowingByQuest(quest, shown)
	local position = quest:GetPositionOnMap(WorldMapFrame:GetMapID())
	if #position == 0 then
		Util:Debug("No position found for quest", quest.ID, quest:GetName(), "on map")
		return
	end

	local pin = self.glowedPin
	if not pin then
		pin = self.pinPool:Acquire()

		pin:OnAcquired(quest, WorldMapFrame)
		pin:SetFrameLevel(3000)
		pin.Icon:SetSelected(true)
		pin.Glow:SetShown(true)

		self.glowedPin = pin
	end

	if shown then
		pin:SetPosition(unpack(position))
		pin.Progress:LockHighlight()
	else
		pin.Progress:UnlockHighlight()
	end

	pin:SetShown(shown)
end

ns.WarbandWorldQuestMapCanvasDataProviderMixin = WarbandWorldQuestMapCanvasDataProviderMixin
