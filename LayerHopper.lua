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

local tip = CreateFrame('GameTooltip', 'GuardianOwnerTooltip', nil, 'GameTooltipTemplate')
local currentLayer = 0

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
			if currentLayer == 0 then
				layerText = "Unknown Layer"
			else
				layerText = "Current Layer: " .. currentLayer
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
	UpdateLayerFromUnit("target")
end

function LayerHopper:UPDATE_MOUSEOVER_UNIT()
	UpdateLayerFromUnit("mouseover")
end

function LayerHopper:NAME_PLATE_UNIT_ADDED(unit)
	UpdateLayerFromUnit(unit)
end

function LayerHopper:GROUP_JOINED()
	if not UnitIsGroupLeader("player") then
		currentLayer = 0
		LayerHopper.LayerHopperLauncher.icon = "Interface/AddOns/LayerHopper/Media/swap"
	end
end

function LayerHopper:RequestLayerHop()
	if IsInGroup() then
		print(self.CHAT_PREFIX .. "Can't request layer hop while in a group.")
		return
	elseif currentLayer == 0 then
		print(self.CHAT_PREFIX .. "Can't request layer hop until your layer is known. Target any NPC to get current layer.")
		return
	elseif IsInInstance() then
		print(self.CHAT_PREFIX .. "Can't request layer hop while in an instance or battleground.")
		return
	end
	if currentLayer == 1 then
		self:SendCommMessage(self.DEFAULT_PREFIX, "request," .. 2, "GUILD")
		print(self.CHAT_PREFIX .. "Requesting layer hop to layer 2.")
	else
		self:SendCommMessage(self.DEFAULT_PREFIX, "request," .. 1, "GUILD")
		print(self.CHAT_PREFIX .. "Requesting layer hop to layer 1.")
	end
end

function LayerHopper:OnCommReceived(prefix, msg, distribution, sender)
	if not self.db.global.autoinvite or IsInInstance() then
		return
	end
	if sender ~= UnitName("player") and strlower(prefix) == strlower(self.DEFAULT_PREFIX) and distribution == "GUILD" then
		local command, data = strsplit(",", msg)
		if command == "request" then
			if tonumber(data) == currentLayer and UnitIsGroupLeader("player") then
				InviteByName(sender)
			end
		end
	end
end

function LayerHopper:ChatCommand(input)
  LibStub("AceConfigDialog-3.0"):Open("LayerHopper")
end

function UpdateLayerFromUnit(unit)
	if IsInInstance() then
		return
	end
	local guid = UnitGUID(unit)
	if guid ~= nil then
		local unittype, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", guid);
		if UnitExists(unit) and not UnitIsPlayer(unit) and unittype ~= "Pet" and not IsGuidOwned(guid) then
			local layer = 0
			local _,_,_,_,i = strsplit("-", guid)
			if i then
				if tonumber(i) < 500 then
					layer = 1
				else
					layer = 2
				end
			end
			if layer > 0 then
				currentLayer = layer
				LayerHopper.LayerHopperLauncher.icon = "Interface/AddOns/LayerHopper/Media/layer" .. currentLayer
			end
		end
	end
end

function IsGuidOwned(guid)
	tip:SetOwner(WorldFrame, 'ANCHOR_NONE')
	tip:SetHyperlink('unit:' .. guid or '')
	local text = GuardianOwnerTooltipTextLeft2
	local subtitle = text and text:GetText() or ''
	return strfind(subtitle, "'s Companion")
end

LayerHopper:RegisterEvent("PLAYER_TARGET_CHANGED")
LayerHopper:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
LayerHopper:RegisterEvent("NAME_PLATE_UNIT_ADDED")
LayerHopper:RegisterEvent("GROUP_JOINED")
