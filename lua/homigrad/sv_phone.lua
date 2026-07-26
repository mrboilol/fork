-- IED phone server bridge.
-- The planted weapon remains authoritative; this file only owns the phone UI
-- network boundary so clients cannot detonate arbitrary IED entities.

if CLIENT then return end

local hg_iedphones = ConVarExists("hg_iedphones") and GetConVar("hg_iedphones") or CreateConVar(
	"hg_iedphones",
	"1",
	FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
	"Give planted IEDs their linked Nokia phone controller and phone UI.",
	0,
	1
)

util.AddNetworkString("HG_IEDPhone_Open")
util.AddNetworkString("HG_IEDPhone_RequestOpen")
util.AddNetworkString("HG_IEDPhone_Detonate")
util.AddNetworkString("HG_IEDPhone_Feedback")

HG_PHONE_SERVER = HG_PHONE_SERVER or {}

local function IsOwnedPlantedIED(ply, phone)
	return IsValid(ply)
		and ply:IsPlayer()
		and ply:Alive()
		and IsValid(phone)
		and phone:GetClass() == "weapon_traitor_ied"
		and phone:GetOwner() == ply
		and phone.GetPlanted
		and phone:GetPlanted()
		and not phone:GetDestroyed()
		and not phone.KABOOM
end

local function SendFeedback(ply, message)
	if not IsValid(ply) then return end

	net.Start("HG_IEDPhone_Feedback")
		net.WriteString(message)
	net.Send(ply)
end

function HG_PHONE_SERVER.OpenIEDPhone(ply, phone)
	if not hg_iedphones:GetBool() then
		SendFeedback(ply, "IED phones are disabled on this server.")
		return false
	end

	if not IsOwnedPlantedIED(ply, phone) then
		SendFeedback(ply, "No linked IED is available.")
		return false
	end

	net.Start("HG_IEDPhone_Open")
		net.WriteEntity(phone)
	net.Send(ply)
	return true
end

net.Receive("HG_IEDPhone_RequestOpen", function(_, ply)
	HG_PHONE_SERVER.OpenIEDPhone(ply, net.ReadEntity())
end)

net.Receive("HG_IEDPhone_Detonate", function(_, ply)
	local phone = net.ReadEntity()
	if not hg_iedphones:GetBool() or not IsOwnedPlantedIED(ply, phone) then
		SendFeedback(ply, "That IED phone link is no longer valid.")
		return
	end

	if phone:GetDialing() or phone:GetDetonating() then return end
	if not phone.PhoneDetonate then
		SendFeedback(ply, "The linked IED cannot receive the call.")
		return
	end

	phone:PhoneDetonate()
end)
