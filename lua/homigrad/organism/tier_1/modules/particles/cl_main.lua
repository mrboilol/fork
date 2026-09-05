local fps = 1 / 24
local delay = 0
local math_min = math.min
local CurTime, FrameTime = CurTime, FrameTime
bloodparticles_hook = bloodparticles_hook or {}
local bloodparticles_hook = bloodparticles_hook

local hg_blood_fps = ConVarExists("hg_blood_fps") and GetConVar("hg_blood_fps") or CreateClientConVar("hg_blood_fps", 24, true, nil, "fps to draw blood", 12, 165)

hook.Add("PostDrawTranslucentRenderables", "bloodpartciels", function()
	local time = CurTime()
	local fps = 1 / hg_blood_fps:GetInt()-- / game.GetTimeScale()
	if not bloodparticles_hook then return end
	local animpos = math_min((delay - time) / fps, 1)
	local drawBlood = bloodparticles_hook[1]
	local drawWaterBlood = bloodparticles_hook[3]

	if isfunction(drawBlood) then drawBlood(animpos, fps) end
	if isfunction(drawWaterBlood) then drawWaterBlood(animpos, fps) end

	if delay < time then
		delay = time + fps

		local updateBlood = bloodparticles_hook[2]
		local updateWaterBlood = bloodparticles_hook[4]

		if isfunction(updateBlood) then updateBlood(fps) end
		if isfunction(updateWaterBlood) then updateWaterBlood(fps) end
	end
end)

hook.Add("PostCleanupMap","remove_decals",function()
	table.Empty(hg.bloodparticles1)
	table.Empty(hg.bloodparticles2)
end)
