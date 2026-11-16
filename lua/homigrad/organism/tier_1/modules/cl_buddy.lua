CreateClientConVar("hg_buddy", "", true, true, "SteamID64 of your chosen buddy")

local HALO_COLOR = Color(70, 140, 255)

hook.Add("PreDrawHalos", "HG_BuddyHalo", function()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then return end

	local buddy = lp:GetNWEntity("hg_buddy")
	if not IsValid(buddy) or not buddy:Alive() then return end
	if not lp:GetNWBool("hg_buddycombat") and not buddy:GetNWBool("hg_buddycombat") then return end

	local ent = hg.GetCurrentCharacter and hg.GetCurrentCharacter(buddy) or buddy
	if not IsValid(ent) then ent = buddy end

	halo.Add({ent}, HALO_COLOR, 2, 2, 2, true, true)
end)
