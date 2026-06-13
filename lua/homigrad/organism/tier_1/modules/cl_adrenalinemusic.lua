local hg_adrenalinemusic = CreateClientConVar("hg_adrenalinemusic", "1", true, false, "Enable adrenaline combat music (sorrymud.mp3)", 0, 1)

hg.adrenalineMusicStation = hg.adrenalineMusicStation or nil
hg.adrenalineMusicVol = hg.adrenalineMusicVol or 0
hg.adrenalineMusicLoading = false
hg.lastAdrenalineAdd = hg.lastAdrenalineAdd or 0
hg.lastDespair = hg.lastDespair or 0
hg.lastFear = hg.lastFear or 0
hg.lastCombatTime = hg.lastCombatTime or 0
hg.adrenalineMusicThreaded = hg.adrenalineMusicThreaded or 0
hg.lastSeverePainTime = hg.lastSeverePainTime or 0

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
	if not hg_adrenalinemusic:GetBool() then 
		MsgN("[AdrenalineMusic] Convar disabled")
		return 
	end
	if IsValid(hg.adrenalineMusicStation) then 
		MsgN("[AdrenalineMusic] Station already exists")
		return 
	end
	if hg.adrenalineMusicLoading then 
		MsgN("[AdrenalineMusic] Already loading")
		return 
	end

	MsgN("[AdrenalineMusic] Starting music...")
	hg.adrenalineMusicLoading = true
	sound.PlayFile("sound/sorrymud.mp3", "mono noblock noplay", function(channel, err)
		hg.adrenalineMusicLoading = false
		if not IsValid(channel) then 
			MsgN("[AdrenalineMusic] Failed to load sound: ", err or "unknown error")
			return 
		end
		MsgN("[AdrenalineMusic] Sound loaded successfully")
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
		if CurTime() % 1 < 0.1 then
			MsgN("[AdrenalineMusic] Convar disabled")
		end
		return
	end

	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) then return end
	if IsValid(ply:GetNWEntity("spect")) then
		stop_adrenaline_music(true)
		if CurTime() % 1 < 0.1 then
			MsgN("[AdrenalineMusic] Blocked: spectating")
		end
		return
	end
	if not ply:Alive() then
		stop_adrenaline_music(true)
		if CurTime() % 1 < 0.1 then
			MsgN("[AdrenalineMusic] Blocked: dead")
		end
		return
	end

	local org = get_target_organism()
	if not org then
		stop_adrenaline_music(true)
		if CurTime() % 1 < 0.1 then
			MsgN("[AdrenalineMusic] Blocked: no organism")
		end
		return
	end

	if org.otrub then
		stop_adrenaline_music(true)
		if CurTime() % 1 < 0.1 then
			MsgN("[AdrenalineMusic] Blocked: otrub")
		end
		return
	end

	-- Prevent playing if under noradrenaline influence (fury-13)
	if (org.noradrenaline or 0) > 0.01 then
		stop_adrenaline_music(true)
		MsgN("[AdrenalineMusic] Blocked: noradrenaline = ", org.noradrenaline)
		return
	end

	-- Prevent playing if under berserk influence
	if (org.berserk or 0) > 0.01 then
		stop_adrenaline_music(true)
		MsgN("[AdrenalineMusic] Blocked: berserk = ", org.berserk)
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

	-- Prevent playing if recently recovered from severe pain (within 30 seconds)
	if pain > 70 then
		hg.lastSeverePainTime = CurTime()
	end
	if (hg.lastSeverePainTime or 0) > CurTime() - 30 then
		stop_adrenaline_music(true)
		if CurTime() % 1 < 0.1 then
			MsgN("[AdrenalineMusic] Blocked: recently recovered from severe pain")
		end
		return
	end

	-- Play if triggered by combat (damage by player, damage to player, or suppression/weapon fire)
	-- Timer is fueled by fear and adrenaline (extends duration)
	local baseDuration = 10
	local fearExtension = fear * 10  -- Fear adds up to 10 seconds
	local adrenalineExtension = adrenaline * 5  -- Adrenaline adds up to 12.5 seconds (at 2.5)
	local totalDuration = baseDuration + fearExtension + adrenalineExtension
	local panicTrigger = CurTime() - hg.lastCombatTime < totalDuration

	if panicTrigger then
		shouldPlay = true
	end
	
	-- Debug output every 0.5 seconds
	if CurTime() % 0.5 < 0.1 then
		MsgN("[AdrenalineMusic] Triggers - adr:", adrenaline, " adrAdd:", adrenalineAdd, " fear:", fear, " combat:", panicTrigger, " shouldPlay:", shouldPlay, " org valid:", org ~= nil, " station valid:", IsValid(hg.adrenalineMusicStation), " vol:", hg.adrenalineMusicVol, " convar:", hg_adrenalinemusic:GetBool())
	end

	-- Track values for other systems but don't use them for triggering
	hg.lastAdrenalineAdd = adrenalineAdd
	hg.lastFear = fear
	hg.lastDespair = despair

	if shouldPlay then
		start_adrenaline_music()
		-- Volume: 0.75 during main duration, fades to 0 during last 20 seconds
		local timeRemaining = totalDuration - (CurTime() - hg.lastCombatTime)
		local targetVol
		if timeRemaining > 20 then
			targetVol = 0.75
		else
			targetVol = 0.75 * (timeRemaining / 20)
		end
		targetVol = math.Clamp(targetVol, 0, 1)
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

-- Detect combat situations via damage taken from players, NPCs, or suppression
hook.Add("EntityTakeDamage", "hg_adrenalinemusic_combat", function(ent, dmgInfo)
	if not hg_adrenalinemusic:GetBool() then return end
	if ent ~= LocalPlayer() then return end
	if not IsValid(ent) or not ent:Alive() then return end

	local attacker = dmgInfo:GetAttacker()
	local damage = dmgInfo:GetDamage()
	local damageType = dmgInfo:GetDamageType()

	-- Exclude fall damage (DMG_FALL) and burn damage (DMG_BURN, DMG_SLOWBURN)
	local isNaturalDamage = damageType == DMG_FALL or damageType == DMG_BURN or damageType == DMG_SLOWBURN

	MsgN("[AdrenalineMusic] Damage taken - dmg:", damage, " type:", damageType, " natural:", isNaturalDamage, " attacker:", IsValid(attacker) and attacker:GetClass() or "invalid")

	-- Trigger combat for any damage that isn't natural (fall/burn)
	if damage > 0 and not isNaturalDamage then
		hg.lastCombatTime = CurTime()
		MsgN("[AdrenalineMusic] Combat triggered by damage")
	end
end)

-- Detect combat via weapon fire
hook.Add("EntityFireBullets", "hg_adrenalinemusic_weaponfire", function(ent, data)
	if not hg_adrenalinemusic:GetBool() then return end
	if ent ~= LocalPlayer() then return end
	if not IsValid(ent) or not ent:Alive() then return end

	hg.lastCombatTime = CurTime()
	MsgN("[AdrenalineMusic] Combat triggered by weapon fire")
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
	hg.lastSeverePainTime = 0
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
		hg.lastCombatTime = CurTime()
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
