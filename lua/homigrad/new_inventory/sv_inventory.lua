util.AddNetworkString("NI_SelectWeapon")

net.Receive("NI_SelectWeapon", function(len, ply)
	local wep = net.ReadEntity()
	if IsValid(wep) and ply:HasWeapon(wep:GetClass()) and wep:GetOwner() == ply and ply:GetActiveWeapon() ~= wep then
		ply:SelectWeapon(wep)
	end
end)

local inventorySystem = GetConVar("hg_invsystem") or CreateConVar(
	"hg_invsystem",
	1,
	{FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE},
	"Inventory system: 0 = body/backpack, 1 = simple selector, 2 = radial",
	0,
	2
)

local function SyncInventorySystem()
	local mode = math.Clamp(inventorySystem:GetInt(), 0, 2)
	SetGlobalInt("InventorySystem", mode)
	SetGlobalBool("RadialInventory", mode == 2)
end

cvars.AddChangeCallback("hg_invsystem", SyncInventorySystem, "HomigradInventorySystem")
SyncInventorySystem()
