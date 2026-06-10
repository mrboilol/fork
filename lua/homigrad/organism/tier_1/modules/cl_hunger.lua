if hg and hg.hunger_client_builtin then return end

local function get_target_organism()
	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) then return nil end
	if IsValid(ply:GetNWEntity("spect")) then return nil end
	if not ply:Alive() then return nil end
	return ply.new_organism or ply.organism
end

local hungerThoughts = {
	"I'm getting hungry...",
	"I need to eat something.",
	"My stomach is growling.",
	"When was the last time I ate?",
	"I should find some food.",
	"I'm so hungry.",
	"I need food now.",
	"I'm starving...",
	"I can't go on like this.",
	"I'm wasting away...",
}

local hungerThoughtIndex = 0
local hungerThoughtNextTime = 0

hook.Add("Think", "hg_hunger_thoughts_notify", function()
	local org = get_target_organism()
	if not org then return end
	
	-- Only show hunger thoughts if hunger system is enabled
	if not GetConVar("hg_hungersystem"):GetBool() then
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
			
			if hg and hg.CreateNotification then
				hg.CreateNotification(thought, 2, Color(255, 165, 0), true)
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
