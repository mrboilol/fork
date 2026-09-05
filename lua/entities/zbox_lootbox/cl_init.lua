include("shared.lua")

function ENT:Initialize()
end

function ENT:OnRemove()
	if IsValid(hg and hg.ContainerLootMenu) and hg.ContainerLootMenu.ent == self then
		hg.ContainerLootMenu:Close()
	end
end

function ENT:Draw()
	self:DrawModel()
end

net.Receive("ZBox_LootSystem_net", function()
	local ent = net.ReadEntity()
	local loot = util.JSONToTable(net.ReadString()) or {}
	if not IsValid(ent) then return end

	hg.OpenedContainer = ent
	hg.OpenContainerLootGrid({
		ent = ent,
		items = loot,
		title = "Container",
		helpText = "Hold LMB - Search | LMB - Take | R - Close",
		maxDistance = 400,
		onTake = function(container, itemID)
			net.Start("ZBox_LootSystem_net")
				net.WriteEntity(container)
				net.WriteUInt(itemID, 10)
			net.SendToServer()
		end,
	})
end)
