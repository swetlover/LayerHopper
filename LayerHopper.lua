LayerHopper = LibStub("AceAddon-3.0"):NewAddon("LayerHopper", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
LayerHopper:RegisterChatCommand("lh", "ChatCommand")

LayerHopper.options = {
	name = "|TInterface\\AddOns\\LayerHopper\\Media\\swap:24:24:0:5|t LayerHopper v" .. GetAddOnMetadata("LayerHopper", "Version"),
	handler = LayerHopper,
	type = 'group',
	args = {
		desc = {
			type = "description",
			name = "|CffDEDE42Layer Hopper Config (You can type /lh to open this).",
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

LayerHopper.DEFAULT_PREFIX = "LayerHopper"
LayerHopper.CHAT_PREFIX = "|cFFFF69B4[LayerHopper]|r "
LayerHopper.COMM_VER = 112
LayerHopper.currentLayerId = -1
LayerHopper.foundOldVersion = false

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
				layerText = "Unknown Layer. Target any NPC or mob to get current layer."
			else
				layerText = "Current Layer: " .. GetLayerGuess(LayerHopper.currentLayerId) .. " (layer id: " .. LayerHopper.currentLayerId .. ")"
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
	self:SendCommMessage(self.DEFAULT_PREFIX, "requestlayeridswitch," .. self.COMM_VER .. "," .. self.currentLayerId, "GUILD")
	print(self.CHAT_PREFIX .. "Requesting layer hop from layer " .. GetLayerGuess(self.currentLayerId) .. " to another layer.")
end

function LayerHopper:OnCommReceived(prefix, msg, distribution, sender)
	if self.currentLayerId < 0 or self.foundOldVersion or not self.db.global.autoinvite or IsInInstance() or (IsInGroup() and not UnitIsGroupLeader("player")) then
		return
	end
	if sender ~= UnitName("player") and strlower(prefix) == strlower(self.DEFAULT_PREFIX) and distribution == "GUILD" then
		local command, ver, data = strsplit(",", msg)
		if tonumber(ver) ~= self.COMM_VER then
			if not self.foundOldVersion then
				print(self.CHAT_PREFIX .. "You are running an old version of Layer Hopper, please update from curseforge!")
				self.foundOldVersion = true
			end
			return
		end
		if command == "requestlayeridswitch" then
			if GetLayerGuess(tonumber(data)) ~= GetLayerGuess(self.currentLayerId) then
				InviteUnit(sender)
			end
		end
	end
end

function LayerHopper:ChatCommand(input)
  LibStub("AceConfigDialog-3.0"):Open("LayerHopper")
end

function LayerHopper:UpdateLayerFromUnit(unit)
	if IsInInstance() then
		return
	end
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
				self:UpdateIcon()
			end
		end
	end
end

function LayerHopper:UpdateIcon()
	if self.currentLayerId < 0 then
		LayerHopper.LayerHopperLauncher.icon = "Interface/AddOns/LayerHopper/Media/swap"
	else
		LayerHopper.LayerHopperLauncher.icon = "Interface/AddOns/LayerHopper/Media/layer" .. GetLayerGuess(self.currentLayerId)
	end
end

local tip = CreateFrame('GameTooltip', 'GuardianOwnerTooltip', nil, 'GameTooltipTemplate')

function IsGuidOwned(guid)
	tip:SetOwner(WorldFrame, 'ANCHOR_NONE')
	tip:SetHyperlink('unit:' .. guid or '')
	local text = GuardianOwnerTooltipTextLeft2
	local subtitle = text and text:GetText() or ''
	return strfind(subtitle, "'s Companion")
end

function GetLayerGuess(layerId)
	if layerId < 0 then
		return -1
	end
	local layerGuess = 1
	if layerId > 50 then -- this is a guess based on number of zones in classic https://wow.gamepedia.com/UiMapID/Classic
		layerGuess = 2
	end
	return layerGuess
end

LayerHopper:RegisterEvent("PLAYER_TARGET_CHANGED")
LayerHopper:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
LayerHopper:RegisterEvent("NAME_PLATE_UNIT_ADDED")
LayerHopper:RegisterEvent("GROUP_JOINED")
LayerHopper:RegisterEvent("PLAYER_ENTERING_WORLD")
LayerHopper:RegisterComm(LayerHopper.DEFAULT_PREFIX)
