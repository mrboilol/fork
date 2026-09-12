local hg_adrenalinemusic = CreateClientConVar("hg_adrenalinemusic", "1", true, false, "Enable adrenaline combat music", 0, 1)

hg.adrenalineMusicStation = hg.adrenalineMusicStation or nil
hg.adrenalineMusicVol = hg.adrenalineMusicVol or 0
hg.adrenalineMusicLoading = hg.adrenalineMusicLoading or false
hg.lastCombatTime = hg.lastCombatTime or 0
hg.lastSeverePainTime = hg.lastSeverePainTime or 0

local function StopAdrenalineMusic(immediate)
	local station = hg.adrenalineMusicStation
	if not IsValid(station) then
		hg.adrenalineMusicStation = nil
		hg.adrenalineMusicVol = 0
		return
	end

	if immediate then
		station:Stop()
		hg.adrenalineMusicStation = nil
		hg.adrenalineMusicVol = 0
		return
	end

	hg.adrenalineMusicVol = Lerp(FrameTime() * 2, hg.adrenalineMusicVol, 0)
	station:SetVolume(hg.adrenalineMusicVol)
	if hg.adrenalineMusicVol <= 0.001 then
		station:Stop()
		hg.adrenalineMusicStation = nil
	end
end

local function StartAdrenalineMusic()
	if not hg_adrenalinemusic:GetBool() or IsValid(hg.adrenalineMusicStation) or hg.adrenalineMusicLoading then return end

	hg.adrenalineMusicLoading = true
	sound.PlayFile("sound/sorrymud.mp3", "mono noblock noplay", function(station)
		hg.adrenalineMusicLoading = false
		if not IsValid(station) or not hg_adrenalinemusic:GetBool() then return end

		station:SetVolume(0)
		station:EnableLooping(true)
		station:SetTime(22)
		station:Play()
		hg.adrenalineMusicStation = station
	end)
end

hook.Add("Think", "hg_adrenalinemusic_check", function()
	if not hg_adrenalinemusic:GetBool() then
		StopAdrenalineMusic(true)
		return
	end

	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) or not ply:Alive() or IsValid(ply:GetNWEntity("spect")) then
		StopAdrenalineMusic(true)
		return
	end

	local organism = ply.new_organism or ply.organism
	if not organism or organism.otrub or (organism.noradrenaline or 0) > 0.01 or (organism.berserk or 0) > 0.01 then
		StopAdrenalineMusic(true)
		return
	end

	if (organism.pain or 0) > 70 then
		hg.lastSeverePainTime = CurTime()
	end
	if CurTime() - hg.lastSeverePainTime < 30 then
		StopAdrenalineMusic(true)
		return
	end

	local duration = 10 + math.Clamp(organism.fear or 0, 0, 1) * 10 + math.Clamp(organism.adrenaline or 0, 0, 5) * 5
	local remaining = duration - (CurTime() - hg.lastCombatTime)
	if remaining <= 0 then
		StopAdrenalineMusic(false)
		return
	end

	StartAdrenalineMusic()
	hg.adrenalineMusicVol = Lerp(FrameTime() * 2, hg.adrenalineMusicVol, math.Clamp(remaining / 20, 0, 0.75))
	if IsValid(hg.adrenalineMusicStation) then
		hg.adrenalineMusicStation:SetVolume(hg.adrenalineMusicVol)
	end
end)

local function MarkCombat(ent, dmgInfo)
	if not hg_adrenalinemusic:GetBool() or ent != LocalPlayer() or not IsValid(ent) or not ent:Alive() then return end
	local damageType = dmgInfo:GetDamageType()
	if dmgInfo:GetDamage() > 0 and damageType != DMG_FALL and damageType != DMG_BURN and damageType != DMG_SLOWBURN then
		hg.lastCombatTime = CurTime()
	end
end

hook.Add("EntityTakeDamage", "hg_adrenalinemusic_combat", MarkCombat)
hook.Add("EntityFireBullets", "hg_adrenalinemusic_weaponfire", function(ent)
	if ent == LocalPlayer() and hg_adrenalinemusic:GetBool() then hg.lastCombatTime = CurTime() end
end)
hook.Add("Player_Death", "hg_adrenalinemusic_cleanup", function(ply)
	if ply == LocalPlayer() then StopAdrenalineMusic(true) end
end)
