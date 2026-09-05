if SERVER then return end

hg = hg or {}

net.Receive("hg_sandbox_container_open", function()
	local ent = net.ReadEntity()
	local loot = net.ReadTable()
	net.ReadUInt(2)
	if not IsValid(ent) then return end

	hg.OpenedContainer = ent
	hg.OpenContainerLootGrid({
		ent = ent,
		items = loot,
		title = "Container",
		helpText = "Hold LMB - Search | LMB - Take | R - Let go",
		onTake = function(container, itemID)
			net.Start("hg_sandbox_container_take")
				net.WriteEntity(container)
				net.WriteUInt(itemID, 10)
			net.SendToServer()
		end,
		onClose = function(container)
			net.Start("hg_sandbox_container_close")
				net.WriteEntity(container)
			net.SendToServer()
		end,
	})
end)
