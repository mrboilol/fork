local hg_adrenalinemusic = CreateClientConVar("hg_adrenalinemusic", "0", true, false, "Enable adrenaline combat music (sorrymud.ogg)", 0, 1)

hg.adrenalineMusicStation = hg.adrenalineMusicStation or nil
hg.adrenalineMusicVol = hg.adrenalineMusicVol or 0
hg.adrenalineMusicLoading = false
hg.lastAdrenalineAdd = hg.lastAdrenalineAdd or 0
hg.lastDespair = hg.lastDespair or 0
hg.lastCombatTime = hg.lastCombatTime or 0

local function stop_adrenaline_music(force)
	if not IsValid(hg.adrenalineMusicStation) then return end
	if force then
		hg.adrenalineMusicStation:Stop()
		hg.adrenalineMusicStation = nil
		hg.adrenalineMusicVol = 0
		return
	end
	hg.adrenalineMusicVol = math.max(hg.adrenalineMusicVol - FrameTime() * 0.5, 0)
	hg.adrenalineMusicStation:SetVolume(hg.adrenalineMusicVol)
	if hg.adrenalineMusicVol <= 0.001 then
		hg.adrenalineMusicStation:Stop()
		hg.adrenalineMusicStation = nil
	end
end

local function start_adrenaline_music()
	if not hg_adrenalinemusic:GetBool() then return end
	if IsValid(hg.adrenalineMusicStation) then return end
	if hg.adrenalineMusicLoading then return end

	hg.adrenalineMusicLoading = true
	sound.PlayFile("sound/sorrymud.ogg", "noblock noplay", function(channel)
		hg.adrenalineMusicLoading = false
		if not IsValid(channel) then return end
		channel:SetVolume(0)
		channel:Play()
		channel:EnableLooping(true)
		channel:SetTime(10) -- Skip 10 seconds
		hg.adrenalineMusicStation = channel
		hg.adrenalineMusicEndTime = nil
	end)
end

local function get_target_organism()
	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) then return nil end
	if IsValid(ply:GetNWEntity("spect")) then return nil end
	if not ply:Alive() then return nil end
	return ply.new_organism or ply.organism
end

hook.Add("Think", "hg_adrenalinemusic_check", function()
	if not hg_adrenalinemusic:GetBool() then
		stop_adrenaline_music(true)
		return
	end

	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) then return end
	if IsValid(ply:GetNWEntity("spect")) then
		stop_adrenaline_music(true)
		return
	end
	if not ply:Alive() then
		stop_adrenaline_music(true)
		return
	end

	local org = get_target_organism()
	if not org then
		stop_adrenaline_music(true)
		return
	end

	if org.otrub then
		stop_adrenaline_music(true)
		return
	end

	local shouldPlay = false
	local adrenalineAdd = org.adrenalineAdd or 0
	local despair = org.despair or 0
	local adrenaline = org.adrenaline or 0
	local fear = org.fear or 0
	local pain = org.pain or 0

	-- Check if adrenaline increased
	if adrenalineAdd > hg.lastAdrenalineAdd + 0.1 then
		shouldPlay = true
	end
	hg.lastAdrenalineAdd = adrenalineAdd

	-- Check if fear increased
	if despair > hg.lastDespair + 0.05 then
		shouldPlay = true
	end
	hg.lastDespair = despair

	-- Check if in combat (recent damage or weapon fire)
	if CurTime() - hg.lastCombatTime < 5 then
		shouldPlay = true
	end

	-- Also play if currently has adrenaline, fear, pain, or despair
	if adrenalineAdd > 0.25 or despair > 0.3 or adrenaline > 0.5 or fear > 0.5 or pain > 30 then
		shouldPlay = true
	end

	if shouldPlay then
		start_adrenaline_music()
		local targetVol = math.Clamp(math.max((adrenalineAdd - 0.25) / 1.25, despair / 0.3, (adrenaline - 0.5) / 2, fear / 2, (pain - 30) / 70), 0, 1)
		hg.adrenalineMusicVol = math.Approach(hg.adrenalineMusicVol, targetVol, FrameTime() * 0.3)
		if IsValid(hg.adrenalineMusicStation) then
			hg.adrenalineMusicStation:SetVolume(hg.adrenalineMusicVol)
			-- Get song length and loop back to 10 seconds when near end
			if not hg.adrenalineMusicEndTime then
				hg.adrenalineMusicEndTime = hg.adrenalineMusicStation:GetLength()
			end
			local currentTime = hg.adrenalineMusicStation:GetTime()
			if currentTime > hg.adrenalineMusicEndTime - 20 then
				hg.adrenalineMusicStation:SetTime(10)
			end
		end
	else
		stop_adrenaline_music(false)
	end
end)

-- Detect combat situations via damage taken
hook.Add("EntityTakeDamage", "hg_adrenalinemusic_combat", function(ent, dmgInfo)
	if not hg_adrenalinemusic:GetBool() then return end
	if ent ~= LocalPlayer() then return end
	if not IsValid(ent) or not ent:Alive() then return end
	
	local attacker = dmgInfo:GetAttacker()
	if IsValid(attacker) and (attacker:IsPlayer() or attacker:IsNPC()) then
		hg.lastCombatTime = CurTime()
	end
end)

-- Detect combat via weapon fire
hook.Add("EntityFireBullets", "hg_adrenalinemusic_weaponfire", function(ent, data)
	if not hg_adrenalinemusic:GetBool() then return end
	if ent ~= LocalPlayer() then return end
	if not IsValid(ent) or not ent:Alive() then return end
	
	hg.lastCombatTime = CurTime()
end)

hook.Add("Player_Death", "hg_adrenalinemusic_cleanup", function(ply)
	if not IsValid(lply) then return end
	if ply ~= lply and ply ~= lply:GetNWEntity("spect") then return end
	stop_adrenaline_music(true)
end)

hook.Add("Player Spawn", "hg_adrenalinemusic_cleanup", function(ply)
	if not IsValid(lply) then return end
	if ply ~= lply then return end
	stop_adrenaline_music(true)
	hg.lastAdrenalineAdd = 0
	hg.lastDespair = 0
	hg.lastCombatTime = 0
end)
