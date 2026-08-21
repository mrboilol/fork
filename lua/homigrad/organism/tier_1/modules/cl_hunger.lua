if hg and hg.hunger_client_builtin then return end

local function get_target_organism()
	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) then return nil end
	if IsValid(ply:GetNWEntity("spect")) then return nil end
	if not ply:Alive() then return nil end
	return ply.new_organism or ply.organism
end

local hungerThoughts = {
	"You are becoming hungry.",
	"You need food.",
	"Hunger is causing stomach discomfort.",
	"You have not eaten recently.",
	"You should find food.",
	"You are very hungry.",
	"You need food soon.",
	"You are starving.",
	"Hunger is severely weakening you.",
	"Starvation is worsening.",
}

local hungerThoughtIndex = 0
local hungerThoughtNextTime = 0
local hungerThoughtColor = Color(255, 165, 0)

hook.Add("Think", "hg_hunger_thoughts_notify", function()
	local org = get_target_organism()
	if not org then return end
	
	-- Only show hunger thoughts if hunger system is enabled
	local hungerSystem = GetConVar("hg_hungersystem")
	if not hungerSystem or not hungerSystem:GetBool() then
		hungerThoughtIndex = 0
		hungerThoughtNextTime = 0
		return
	end
	
	local hungry = org.hungry or 0
	local time = CurTime()

	-- Start hunger thoughts when hungry (>30)
	if hungry > 30 then
		if time >= hungerThoughtNextTime then
			hungerThoughtIndex = (hungerThoughtIndex % #hungerThoughts) + 1
			local thought = hungerThoughts[hungerThoughtIndex]
			
			-- More frequent thoughts as hunger increases
			local thoughtInterval = math.Remap(hungry, 30, 100, 30, 10)
			
			local newThoughts = GetConVar("hg_newthoughts")
			if newThoughts and newThoughts:GetBool() and hg and hg.CreateThought then
				hg.CreateThought(thought, hungerThoughtColor)
			elseif hg and hg.CreateNotification then
				hg.CreateNotification(thought, 2, hungerThoughtColor)
			end
			
			hungerThoughtNextTime = time + thoughtInterval
		end
	else
		hungerThoughtIndex = 0
		hungerThoughtNextTime = 0
	end
end)

hook.Add("Player_Death", "hg_hunger_cleanup", function(ply)
	if not IsValid(lply) then return end
	if ply ~= lply and ply ~= lply:GetNWEntity("spect") then return end
	hungerThoughtIndex = 0
	hungerThoughtNextTime = 0
end)

hook.Add("Player Spawn", "hg_hunger_cleanup", function(ply)
	if not IsValid(lply) then return end
	if ply ~= lply then return end
	hungerThoughtIndex = 0
	hungerThoughtNextTime = 0
end)
