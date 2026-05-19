hg = hg or {}
if hg.__zcity_delta_sonar_fx_loaded then return end
hg.__zcity_delta_sonar_fx_loaded = true

local function StopPatchSound(station)
	if station then
		station:Stop()
	end
	return nil
end

local function CreateLoopSound(soundName)
	local lp = LocalPlayer()
	if not IsValid(lp) then return nil end

	local patch = CreateSound(lp, soundName)
	if not patch then return nil end

	patch:Play()
	patch:ChangeVolume(1, 0)
	return patch
end

local sonarStation = nil
local autoresusBlackUntil = 0
local autoresusStation = nil

local function StopSonarSound()
	sonarStation = StopPatchSound(sonarStation)
end

local function StopAutoresusSound()
	autoresusStation = StopPatchSound(autoresusStation)
	autoresusBlackUntil = 0
end

hook.Add("HUDPaint", "zcity_delta_autoresus_blackout", function()
	if (autoresusBlackUntil or 0) <= CurTime() then return end
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)

net.Receive("hg_autoresus_fx", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local duration = net.ReadFloat()
	if duration <= 0 then
		duration = 11
	end

	StopAutoresusSound()
	autoresusBlackUntil = CurTime() + duration
	autoresusStation = CreateLoopSound("zcity_delta/aed.ogg")
end)

net.Receive("hg_autoresus_after_fx", function()
	StopAutoresusSound()
	StopSonarSound()
	-- sonarStation = CreateLoopSound("zcity_delta/sonarmegaouch.ogg")
end)

net.Receive("zcity_delta_sonar_hit", function()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then return end

	StopSonarSound()
	sonarStation = CreateLoopSound("zcity_delta/sonarmegaouch.ogg")
end)

hook.Add("PlayerDeath", "zcity_delta_sonar_stop", function(ply)
	if ply ~= LocalPlayer() then return end
	StopAutoresusSound()
	StopSonarSound()
end)

hook.Add("Player_Death", "zcity_delta_sonar_stop2", function(ply)
	if ply ~= LocalPlayer() then return end
	StopAutoresusSound()
	StopSonarSound()
end)

hook.Add("PlayerSpawn", "zcity_delta_sonar_stop3", function(ply)
	if ply ~= LocalPlayer() then return end
	StopAutoresusSound()
	StopSonarSound()
end)

hook.Add("Player Spawn", "zcity_delta_sonar_stop4", function(ply)
	if ply ~= LocalPlayer() then return end
	StopAutoresusSound()
	StopSonarSound()
end)

hook.Add("Think", "zcity_delta_sonar_stop_dead", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	if lp:Alive() then return end
	StopAutoresusSound()
	StopSonarSound()
end)
