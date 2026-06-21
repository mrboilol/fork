hg = hg or {}

local vpang = Angle(1,-2,1)

local function IsFirearm(wep)
	if not IsValid(wep) then return false end
	if not ishgweapon(wep) then return false end
	if not wep.Primary or not wep.Primary.Ammo or wep.Primary.Ammo == "" then return false end
	return wep:Clip1() > 0
end

local function GetFearChanceBonus(ply)
	local org = IsValid(ply) and ply.organism or nil
	return math.Clamp(org and org.fear or 0, 0, 2) * 0.15
end

function hg.AccidentalFire(ply, wep, baseChance)
	if not IsValid(ply) or not IsValid(wep) then return false end
	if not IsFirearm(wep) then return false end
	if (ply.hg_accidental_fire_cd or 0) > CurTime() then return false end

	local chance = math.min(baseChance + GetFearChanceBonus(ply), 0.8)
	if math.random() >= chance then return false end

	ply.hg_accidental_fire_cd = CurTime() + 0.5

	local oldOwner = wep:GetOwner()
	if not IsValid(oldOwner) then oldOwner = nil end

	wep:SetOwner(ply)
	wep:PrimaryAttack(true)

	if oldOwner == nil then
		wep:SetOwner()
	elseif oldOwner ~= ply then
		wep:SetOwner(oldOwner)
	end

	return true
end

local function GetHeldFirearm(ply)
	local wep = IsValid(ply.ActiveWeapon) and ply.ActiveWeapon or ply:GetActiveWeapon()
	if IsFirearm(wep) then return wep end
	return nil
end

local function drop(ply, wep, newWeapon, vel)
	local wep = isentity(wep) and wep or ply:GetActiveWeapon()
	if not IsValid(wep) or wep.NoDrop then return end
	if ply:GetNWFloat("willsuicide", 0) > 0 then return end -- you cant escape.
	local eyeAngles = ply:LocalEyeAngles()

	hg.AccidentalFire(ply, wep, IsValid(ply.FakeRagdoll) and 0.35 or 0.1)

	ply:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_1HAND)
	ply:ViewPunch(vpang)
	timer.Simple(0,function()
		if not IsValid(ply) or not IsValid(wep) then return end
		local pos, ang
		
		if wep.WorldModel_Transform then
			pos, ang = wep:WorldModel_Transform(true)
		end
		
		if not IsValid(newWeapon) then
			ply:SelectWeapon("weapon_hands_sh")
			ply:SetActiveWeapon(ply:GetWeapon("weapon_hands_sh"))
		else
			ply:SelectWeapon(newWeapon:GetClass())
			ply:SetActiveWeapon(newWeapon)
		end

		ply:DropWeapon(wep, nil, not IsValid(wep.fakeGun) and (eyeAngles:Forward() * (isnumber(vel) and vel or 250)) + ply:GetVelocity() or nil)
		
		wep.init = true
		wep.IsSpawned = true

		timer.Simple(0,function()
			if pos and ang then
				local tr = {}
				tr.start = ply:EyePos()
				tr.endpos = pos
				tr.filter = {ply,wep}
				tr.mask = MASK_SOLID
				local tr = util.TraceLine(tr)
				if tr.Hit then pos = ply:EyePos() end
				wep:SetPos(pos)
				wep:SetAngles(ang)
			end
		end)

		ply:ViewPunch(Angle(-1,5,-2))
		wep:SetOwner()
		if IsValid(wep.fakeGun) then wep:RemoveFake() end	
	end)
end

hg.drop = drop

concommand.Add("drop", drop)
concommand.Add("dropweapon", drop)
concommand.Add("-drop", drop)
concommand.Add("-dropweapon", drop)
local whitelist = {
	["*drop"] = true,
	["/drop"] = true,
	["!drop"] = true
}

hook.Add("HG_PlayerSay", "homigrad-drop-weapons", function(ply, txtTbl, text)
	if whitelist[text] then
		drop(ply)
		txtTbl[1] = ""
	end
end)

hook.Add("Fake", "hg-accidental-fire-fake", function(ply, ragdoll)
	if not IsValid(ply) then return end
	local wep = GetHeldFirearm(ply)
	if not wep then return end
	hg.AccidentalFire(ply, wep, 0.15)
end)

hook.Add("DoPlayerDeath", "hg-accidental-fire-track", function(ply)
	if not IsValid(ply) then return end
	local wep = ply:GetActiveWeapon()
	ply.hg_deathWep = IsFirearm(wep) and wep or nil
end)

hook.Add("PlayerDropWeapon", "hg-accidental-fire-track-drop", function(ply, wep)
	if not IsValid(ply) or not IsValid(wep) then return end
	ply.hg_lastDroppedWep = wep
	ply.hg_lastDroppedWepTime = CurTime()
end)

hook.Add("RagdollDeath", "hg-accidental-fire-death", function(ply, ragdoll)
	if not IsValid(ply) then return end
	local wep = ply.hg_deathWep
	ply.hg_deathWep = nil
	if not IsValid(wep) and (CurTime() - (ply.hg_lastDroppedWepTime or 0)) < 1 then
		wep = ply.hg_lastDroppedWep
		ply.hg_lastDroppedWep = nil
	end
	if not IsValid(wep) then return end
	hg.AccidentalFire(ply, wep, 0.2)
end)