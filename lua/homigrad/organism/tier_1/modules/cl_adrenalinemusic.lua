local hg_adrenalinemusic = CreateClientConVar("hg_adrenalinemusic", "1", true, false, "Enable adrenaline combat music (sorrymud.mp3)", 0, 1)

hg.adrenalineMusicStation = hg.adrenalineMusicStation or nil
hg.adrenalineMusicVol = hg.adrenalineMusicVol or 0
hg.adrenalineMusicLoading = false
hg.lastAdrenalineAdd = hg.lastAdrenalineAdd or 0
hg.lastDespair = hg.lastDespair or 0
hg.lastFear = hg.lastFear or 0
hg.lastCombatTime = hg.lastCombatTime or 0
hg.adrenalineMusicThreaded = hg.adrenalineMusicThreaded or 0

local function stop_adrenaline_music(force)
	if not IsValid(hg.adrenalineMusicStation) then return end
	if force then
		hg.adrenalineMusicStation:Stop()
		hg.adrenalineMusicStation = nil
		hg.adrenalineMusicVol = 0
		return
	end
	hg.adrenalineMusicVol = LerpFT(0.02, hg.adrenalineMusicVol, 0)
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
	sound.PlayFile("sound/sorrymud.mp3", "mono noblock noplay", function(channel)
		hg.adrenalineMusicLoading = false
		if not IsValid(channel) then return end
		channel:SetVolume(0)
		channel:Play()
		channel:EnableLooping(true)
		channel:SetTime(22) -- Skip 22 seconds
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

	-- Prevent playing if under noradrenaline influence (fury-13)
	if (org.noradrenaline or 0) > 0.01 then
		stop_adrenaline_music(true)
		return
	end

	-- Prevent playing if under berserk influence
	if (org.berserk or 0) > 0.01 then
		stop_adrenaline_music(true)
		return
	end

	local shouldPlay = false
	local adrenalineAdd = org.adrenalineAdd or 0
	local despair = org.despair or 0
	local adrenaline = org.adrenaline or 0
	local fear = org.fear or 0
	local pain = org.pain or 0
	local blood = org.blood or 0
	local o2 = org.o2 and org.o2.curregen or 0
	local pulse = org.pulse or 0

	-- Prevent playing if in big pain or dying
	if pain > 50 then
		stop_adrenaline_music(true)
		return
	end

	-- Prevent playing if bleeding out (low blood)
	if blood < 4000 then
		stop_adrenaline_music(true)
		return
	end

	-- Prevent playing if great drop in o2 (oxygen regeneration)
	if o2 < 0.3 then
		stop_adrenaline_music(true)
		return
	end

	-- Prevent playing if great drop in pulse (too low)
	if pulse < 40 then
		stop_adrenaline_music(true)
		return
	end

	-- Play if triggered by adrenaline, adrenalineAdd, fear, or panic (recent damage)
	local adrenalineTrigger = (adrenaline or 0) > 0.25
	local adrenalineAddTrigger = (adrenalineAdd or 0) > 0.25
	local fearTrigger = (fear or 0) > 0.25
	local panicTrigger = CurTime() - hg.lastCombatTime < 15
	
	if adrenalineTrigger or adrenalineAddTrigger or fearTrigger or panicTrigger then
		shouldPlay = true
	end

	-- Track values for other systems but don't use them for triggering
	hg.lastAdrenalineAdd = adrenalineAdd
	hg.lastFear = fear
	hg.lastDespair = despair

	if shouldPlay then
		start_adrenaline_music()
		local combatFactor = math.max(0, (15 - (CurTime() - hg.lastCombatTime)) / 15) * 1.0
		local threadedFactor = math.Clamp(hg.adrenalineMusicThreaded / 100, 0, 0.5)
		local targetVol = math.Clamp(math.max(combatFactor, threadedFactor), 0, 1)
		hg.adrenalineMusicVol = LerpFT(0.02, hg.adrenalineMusicVol, targetVol)
		if IsValid(hg.adrenalineMusicStation) then
			hg.adrenalineMusicStation:SetVolume(hg.adrenalineMusicVol)
			-- Get song length and loop back to 22 seconds when near end
			if not hg.adrenalineMusicEndTime then
				hg.adrenalineMusicEndTime = hg.adrenalineMusicStation:GetLength()
			end
			local currentTime = hg.adrenalineMusicStation:GetTime()
			if currentTime > hg.adrenalineMusicEndTime - 20 then
				hg.adrenalineMusicStation:SetTime(22)
			end
		end
	else
		stop_adrenaline_music(false)
	end

	-- Decay threaded intensity over time
	hg.adrenalineMusicThreaded = math.max(hg.adrenalineMusicThreaded - FrameTime() * 10, 0)
end)

-- Detect combat situations via damage taken
hook.Add("EntityTakeDamage", "hg_adrenalinemusic_combat", function(ent, dmgInfo)
	if not hg_adrenalinemusic:GetBool() then return end
	if ent ~= LocalPlayer() then return end
	if not IsValid(ent) or not ent:Alive() then return end
	
	local attacker = dmgInfo:GetAttacker()
	local damage = dmgInfo:GetDamage()
	
	-- Trigger combat time for any significant damage from any source
	if damage > 0 then
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
	hg.lastFear = 0
	hg.lastCombatTime = 0
	hg.adrenalineMusicThreaded = 0
end)

if SERVER then
	util.AddNetworkString("hg_adrenalinemusic_panic")

	function hg.AddAdrenalineMusicPanic(ply, amount)
		net.Start("hg_adrenalinemusic_panic")
			net.WriteFloat(amount)
		net.Send(ply)
	end
elseif CLIENT then
	net.Receive("hg_adrenalinemusic_panic", function()
		local amount = net.ReadFloat()
		hg.adrenalineMusicThreaded = hg.adrenalineMusicThreaded + amount
	end)
end

hook.Add("HomigradDamage", "hg_adrenalinemusic_panic", function(ply, dmgInfo, hitgroup, ent, harm, hitBoxs, inputHole)
	if SERVER and ent:IsPlayer() then
		local damage = dmgInfo:GetDamage()
		hg.AddAdrenalineMusicPanic(ply, damage * 25)
		local attacker = dmgInfo:GetAttacker()
		if IsValid(attacker) and attacker:IsPlayer() then
			hg.AddAdrenalineMusicPanic(attacker, damage * 5)
		end
	end
end)
