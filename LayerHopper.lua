LayerHopper = LibStub("AceAddon-3.0"):NewAddon("LayerHopper", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
LayerHopper:RegisterChatCommand("lh", "ChatCommand")

LayerHopper.options = {
	name = "|TInterface\\AddOns\\LayerHopper\\Media\\swap:24:24:0:5|t LayerHopper v" .. GetAddOnMetadata("LayerHopper", "Version"),
	handler = LayerHopper,
	type = 'group',
	args = {
		desc = {
			type = "description",
			name = "|CffDEDE42Layer Hopper Config (You can type /lh to open this).\n"
					.. "Auto inviting will be disabled automatically if inside an instance or battleground and when in a battleground queue.\n",
			fontSize = "medium",
			order = 1,
		},
		autoinvite = {
			type = "toggle",
			name = "Auto Invite",
			desc = "Enable auto invites for layer switch requests in the guild.",
			order = 2,
			get = "getAutoInvite",
			set = "setAutoInvite",
		},
	},
}

LayerHopper.optionDefaults = {
	global = {
		autoinvite = true,
	},
}

function LayerHopper:setAutoInvite(info, value)
	self.db.global.autoinvite = value;
end

function LayerHopper:getAutoInvite(info)
	return self.db.global.autoinvite;
end

LayerHopper.RequestLayerSwitchPrefix = "LH_rls"
LayerHopper.RequestLayerMinMaxPrefix = "LH_rlmm"
LayerHopper.SendLayerMinMaxPrefix = "LH_slmm"
LayerHopper.DEFAULT_PREFIX = "LayerHopper"
LayerHopper.CHAT_PREFIX = "|cFFFF69B4[LayerHopper]|r "
LayerHopper.COMM_VER = 122
LayerHopper.minLayerId = -1
LayerHopper.maxLayerId = -1
LayerHopper.currentLayerId = -1
LayerHopper.foundOldVersion = false
LayerHopper.SendCurrentMinMaxTimer = nil

function LayerHopper:OnInitialize()
	self.LayerHopperLauncher = LibStub("LibDataBroker-1.1"):NewDataObject("LayerHopper", {
		type = "launcher",
		text = "LayerHopper",
		icon = "Interface/AddOns/LayerHopper/Media/swap",
		OnClick = function(self, button)
			if button == "LeftButton" then
				LayerHopper:RequestLayerHop()
			elseif button == "RightButton" then
				LibStub("AceConfigDialog-3.0"):Open("LayerHopper")
			end
		end,
		OnEnter = function(self)
			local layerText = ""
			if LayerHopper.currentLayerId < 0 then
				layerText = "Unknown Layer. Target any NPC or mob to get current layer.\n(layer id: " .. LayerHopper.currentLayerId .. ", min: " .. LayerHopper.minLayerId .. ", max: " .. LayerHopper.maxLayerId .. " )"
			elseif not MinMaxValid(LayerHopper.minLayerId, LayerHopper.maxLayerId) then
				layerText = "Min/max layer IDs are unknown. Need more data from guild to determine current layer\n(but you can still request a layer switch). (layer id: " .. LayerHopper.currentLayerId .. ", min: " .. LayerHopper.minLayerId .. ", max: " .. LayerHopper.maxLayerId .. " )"
			else
				layerText = "Current Layer: " .. GetLayerGuess(LayerHopper.currentLayerId, LayerHopper.minLayerId, LayerHopper.maxLayerId) .. "\n(layer id: " .. LayerHopper.currentLayerId .. ", min: " .. LayerHopper.minLayerId .. ", max: " .. LayerHopper.maxLayerId .. " )"
			end
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:AddLine("|cFFFFFFFFLayer Hopper|r v"..GetAddOnMetadata("LayerHopper", "Version"))
			GameTooltip:AddLine(layerText)
			GameTooltip:AddLine("Left click to request a layer hop.")
			GameTooltip:AddLine("Right click to access Layer Hopper settings.")
			GameTooltip:Show()
		end,
		OnLeave = function(self)
			GameTooltip:Hide()
		end
	})
	LibStub("LibDBIcon-1.0"):Register("LayerHopper", self.LayerHopperLauncher, LayerHopperOptions)

	self.db = LibStub("AceDB-3.0"):New("LayerHopperOptions", LayerHopper.optionDefaults, "Default");
	LibStub("AceConfig-3.0"):RegisterOptionsTable("LayerHopper", LayerHopper.options);
	self.LayerHopperOptions = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("LayerHopper", "LayerHopper");
end

function LayerHopper:PLAYER_TARGET_CHANGED()
	self:UpdateLayerFromUnit("target")
end

function LayerHopper:UPDATE_MOUSEOVER_UNIT()
	self:UpdateLayerFromUnit("mouseover")
end

function LayerHopper:NAME_PLATE_UNIT_ADDED(unit)
	self:UpdateLayerFromUnit(unit)
end

function LayerHopper:GROUP_JOINED()
	if not UnitIsGroupLeader("player") then
		self.currentLayerId = -1
		self:UpdateIcon()
	end
end

function LayerHopper:PLAYER_ENTERING_WORLD()
	self.currentLayerId = -1
	self:UpdateIcon()
	self:SendCommMessage(self.DEFAULT_PREFIX, LayerHopper.RequestLayerMinMaxPrefix .. "," .. self.COMM_VER .. "," .. self.currentLayerId .. "," .. self.minLayerId .. "," .. self.maxLayerId, "GUILD")
end

function LayerHopper:RequestLayerHop()
	if IsInGroup() then
		print(self.CHAT_PREFIX .. "Can't request layer hop while in a group.")
		return
	elseif self.currentLayerId < 0 then
		print(self.CHAT_PREFIX .. "Can't request layer hop until your layer is known. Target any NPC or mob to get current layer.")
		return
	elseif IsInInstance() then
		print(self.CHAT_PREFIX .. "Can't request layer hop while in an instance or battleground.")
		return
	end
	self:SendCommMessage(self.DEFAULT_PREFIX, LayerHopper.RequestLayerSwitchPrefix .. "," .. self.COMM_VER .. "," .. self.currentLayerId .. "," .. self.minLayerId .. "," .. self.maxLayerId, "GUILD")
	print(self.CHAT_PREFIX .. "Requesting layer hop from layer " .. GetLayerGuess(self.currentLayerId, self.minLayerId, self.maxLayerId) .. " to another layer.")
end

function LayerHopper:OnCommReceived(prefix, msg, distribution, sender)
	if sender ~= UnitName("player") and strlower(prefix) == strlower(self.DEFAULT_PREFIX) and distribution == "GUILD" then
		local command, ver, layerId, minLayerId, maxLayerId = strsplit(",", msg)
		ver = tonumber(ver)
		layerId = tonumber(layerId)
		minLayerId = tonumber(minLayerId)
		maxLayerId = tonumber(maxLayerId)
		if ver ~= self.COMM_VER then
			if ver > self.COMM_VER and not self.foundOldVersion then
				print(self.CHAT_PREFIX .. "You are running an old version of Layer Hopper, please update from curseforge!")
				self.foundOldVersion = true
			end
			if floor(ver / 10) ~= floor(self.COMM_VER / 10) then
				return
			end
		end
		if command == LayerHopper.RequestLayerSwitchPrefix then
			local minOrMaxUpdated = self:UpdateMinMax(minLayerId, maxLayerId)
			local layerGuess = GetLayerGuess(layerId, self.minLayerId, self.maxLayerId)
			local myLayerGuess = GetLayerGuess(self.currentLayerId, self.minLayerId, self.maxLayerId)
			if layerGuess > 0 and myLayerGuess > 0 and layerGuess ~= myLayerGuess and self.db.global.autoinvite and not IsInBgQueue() and not IsInInstance() and CanInvite() then
				InviteUnit(sender)
			end
			if minOrMaxUpdated then
				self:UpdateIcon()
			end
		elseif command == LayerHopper.RequestLayerMinMaxPrefix then
			local minOrMaxUpdated = self:UpdateMinMax(minLayerId, maxLayerId)
			if not self.SendCurrentMinMaxTimer and not (self.minLayerId == minLayerId and self.maxLayerId == maxLayerId) and self.minLayerId >= 0 and self.maxLayerId >= 0 then
				self.SendCurrentMinMaxTimer = self:ScheduleTimer("SendCurrentMinMax", random() * 5)
			end
			if minOrMaxUpdated then
				self:UpdateIcon()
			end
		elseif command == LayerHopper.SendLayerMinMaxPrefix then
			local minUpdated = self:UpdateMin(minLayerId)
			local maxUpdated = self:UpdateMax(maxLayerId)
			local minAndMaxUpdated = minUpdated and maxUpdated
			local minOrMaxUpdated = minUpdated or maxUpdated
			if self.SendCurrentMinMaxTimer and (minAndMaxUpdated or (minUpdated and self.maxLayerId == maxLayerId) or (maxUpdated and self.minLayerId == minLayerId) or (self.minLayerId == minLayerId and self.maxLayerId == maxLayerId)) then
				self:CancelTimer(self.SendCurrentMinMaxTimer)
				self.SendCurrentMinMaxTimer = nil
			end
			if minOrMaxUpdated then
				self:UpdateIcon()
			end
		end
	end
end

function LayerHopper:SendCurrentMinMax()
	self:SendCommMessage(self.DEFAULT_PREFIX, LayerHopper.SendLayerMinMaxPrefix .. "," .. self.COMM_VER .. "," .. self.currentLayerId .. "," .. self.minLayerId .. "," .. self.maxLayerId, "GUILD")
	if self.SendCurrentMinMaxTimer then
		self:CancelTimer(self.SendCurrentMinMaxTimer)
		self.SendCurrentMinMaxTimer = nil
	end
end

function LayerHopper:ChatCommand(input)
  LibStub("AceConfigDialog-3.0"):Open("LayerHopper")
end

function LayerHopper:UpdateLayerFromUnit(unit)
	if IsInInstance() then
		return
	end
	self.currentZoneId = C_Map.GetBestMapForUnit("player")
	local guid = UnitGUID(unit)
	if guid ~= nil then
		local unittype, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", guid);
		if UnitExists(unit) and not UnitIsPlayer(unit) and unittype ~= "Pet" and not IsGuidOwned(guid) then
			local layerId = -1
			local _,_,_,_,i = strsplit("-", guid)
			if i then
				layerId = tonumber(i)
			end
			if layerId >= 0 then
				self.currentLayerId = layerId
				local minOrMaxUpdated = self:UpdateMinMax(self.currentLayerId, self.currentLayerId)
				self:UpdateIcon()
				if minOrMaxUpdated and self.minLayerId >= 0 and self.maxLayerId >= 0 then
					self:SendCurrentMinMax()
				end
			end
		end
	end
end

function LayerHopper:UpdateIcon()
	local layer = GetLayerGuess(self.currentLayerId, self.minLayerId, self.maxLayerId)
	if layer < 0 then
		LayerHopper.LayerHopperLauncher.icon = "Interface/AddOns/LayerHopper/Media/swap"
	else
		LayerHopper.LayerHopperLauncher.icon = "Interface/AddOns/LayerHopper/Media/layer" .. layer
	end
end

function LayerHopper:UpdateMinMax(min, max)
	return self:UpdateMin(min) or self:UpdateMax(max)
end

function LayerHopper:UpdateMin(min)
	if min >= 0 and (self.minLayerId < 0 or min < self.minLayerId) then
		self.minLayerId = min
		return true
	end
	return false
end

function LayerHopper:UpdateMax(max)
	if max >= 0 and (self.maxLayerId < 0 or max > self.maxLayerId) then
		self.maxLayerId = max
		return true
	end
	return false
end

local tip = CreateFrame('GameTooltip', 'GuardianOwnerTooltip', nil, 'GameTooltipTemplate')

function IsGuidOwned(guid)
	tip:SetOwner(WorldFrame, 'ANCHOR_NONE')
	tip:SetHyperlink('unit:' .. guid or '')
	local text = GuardianOwnerTooltipTextLeft2
	local subtitle = text and text:GetText() or ''
	return strfind(subtitle, "'s Companion")
end

function GetLayerGuess(layerId, minLayerId, maxLayerId)
	if layerId < 0 or not MinMaxValid(minLayerId, maxLayerId) then
		return -1
	end
	local layerGuess = 1
	local midLayerId = (minLayerId + maxLayerId) / 2
	if layerId > midLayerId then
		layerGuess = 2
	end
	return layerGuess
end

function MinMaxValid(minLayerId, maxLayerId)
	return minLayerId >= 0 and maxLayerId >= 0 and maxLayerId - minLayerId > 50 -- this is a guess based on number of zones in classic https://wow.gamepedia.com/UiMapID/Classic
end

function IsInBgQueue()
	local status, mapName, instanceID, minlevel, maxlevel;
	for i = 1, MAX_BATTLEFIELD_QUEUES do
		status, mapName, instanceID, minlevel, maxlevel, teamSize = GetBattlefieldStatus(i);
		if status == "queued" or status == "confirm" then
			return true
		end
	end
	return false
end

function CanInvite()
	return not IsInGroup() or (IsInGroup() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")))
end

LayerHopper:RegisterEvent("PLAYER_TARGET_CHANGED")
LayerHopper:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
LayerHopper:RegisterEvent("NAME_PLATE_UNIT_ADDED")
LayerHopper:RegisterEvent("GROUP_JOINED")
LayerHopper:RegisterEvent("PLAYER_ENTERING_WORLD")
LayerHopper:RegisterComm(LayerHopper.DEFAULT_PREFIX)
