hg.WallBang = hg.WallBang or {}
local WB = hg.WallBang

WB.Reach = 80
WB.MaxDist = 36
WB.BraceDist = 22
WB.HandReach = 32
WB.ApproachTime = 3
WB.ApproachSpeed = 120
WB.Windup = 0.22
WB.Impact = 0.29
WB.Duration = 0.68
WB.Cooldown = 0.75
WB.HandSpread = 9
WB.HandDrop = 7
WB.HandOff = 5

local vecUp = Vector(0, 0, 1)

function WB.Active(ply)
	return IsValid(ply) and ply:GetNWBool("hg_wallbang", false)
end

function WB.Plane(ply)
	return ply:GetNWVector("hg_wallbang_pos"), ply:GetNWVector("hg_wallbang_norm")
end

function WB.WallDist(ply)
	local pos, norm = WB.Plane(ply)
	return (ply:EyePos() - pos):Dot(norm)
end

function WB.SlamCurve(t)
	if t < 0 or t >= WB.Duration then return 0 end
	if t < WB.Windup then
		return -0.35 * math.ease.OutQuad(t / WB.Windup)
	end
	if t < WB.Impact then
		return Lerp(math.ease.InCubic((t - WB.Windup) / (WB.Impact - WB.Windup)), -0.35, 1)
	end
	return 1 - math.ease.OutBack((t - WB.Impact) / (WB.Duration - WB.Impact))
end

function WB.SlamValue(ply)
	local start = ply:GetNWFloat("hg_wallbang_slam", 0)
	if start <= 0 then return 0 end
	return WB.SlamCurve(CurTime() - start)
end

hook.Add("StartCommand", "hg_wallbang_input", function(ply, cmd)
	if not WB.Active(ply) then
		ply.wallbangAttackHeld = nil
		return
	end

	local attack = cmd:KeyDown(IN_ATTACK)
	if SERVER and attack and not ply.wallbangAttackHeld then
		WB.Slam(ply)
	end
	ply.wallbangAttackHeld = attack

	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_ATTACK2)
	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_SPEED)

	local _, norm = WB.Plane(ply)
	local fwd, side = 0, 0
	local dist = WB.WallDist(ply)
	if dist > WB.BraceDist then
		local ang = cmd:GetViewAngles()
		ang.p = 0
		local speed = WB.ApproachSpeed * math.Clamp((dist - WB.BraceDist) / 10, 0.3, 1)
		fwd = ang:Forward():Dot(-norm) * speed
		side = ang:Right():Dot(-norm) * speed
	end
	cmd:SetForwardMove(fwd)
	cmd:SetSideMove(side)
end)

local angBend = Angle()
hook.Add("Bones", "hg_wallbang_bones", function(ply, dtime)
	if not WB.Active(ply) or IsValid(ply.FakeRagdoll) then
		ply.wallbangBrace = nil
		return
	end

	local close = WB.WallDist(ply) <= WB.HandReach
	ply.wallbangBrace = math.Approach(ply.wallbangBrace or 0, close and 1 or 0, (dtime or FrameTime()) * 3)
	local brace = math.ease.InOutSine(ply.wallbangBrace)

	local reach = math.Clamp((WB.WallDist(ply) - 5) / 28, 0, 0.9)
	local bend = math.deg(math.asin(reach))
	local slam = WB.SlamValue(ply)
	local amount = bend * (0.15 * brace + slam * 0.85)

	angBend:SetUnpacked(0, amount * 0.25, 0)
	hg.bone.Set(ply, "spine", vector_origin, angBend, "wallbang")
	angBend:SetUnpacked(0, amount * 0.35, 0)
	hg.bone.Set(ply, "spine1", vector_origin, angBend, "wallbang")
	angBend:SetUnpacked(0, amount * 0.25, 0)
	hg.bone.Set(ply, "spine2", vector_origin, angBend, "wallbang")
	angBend:SetUnpacked(0, 6 * brace + slam * 18, slam > 0.9 and math.sin(CurTime() * 40) * 2 or 0)
	hg.bone.Set(ply, "head", vector_origin, angBend, "wallbang")
end)

if CLIENT then
	local angLH = Angle(-135, -90, 0)
	local angRH = Angle(-135, 90, 180)

	local function placeHand(ply, bone, pos, ang)
		local id = ply:LookupBone(bone)
		local mat = id and ply:GetBoneMatrix(id)
		if not mat then return end
		mat:SetTranslation(pos)
		mat:SetAngles(ang)
		hg.bone_apply_matrix(ply, id, mat)
	end

	function hg.WallBangTPIK(ent, ply, wpn)
		if ent ~= ply or not IsValid(wpn) or not WB.Active(ply) or WB.WallDist(ply) > WB.HandReach then return end

		local wallPos, norm = WB.Plane(ply)
		local eye = ply:EyePos()
		local center = eye - norm * (eye - wallPos):Dot(norm)
		local inAng = (-norm):Angle()
		local right = inAng:Right()
		local slam = math.max(WB.SlamValue(ply), 0)

		local base = center - vecUp * (WB.HandDrop - slam * 1.5) + norm * (WB.HandOff - slam * 0.6)
		local _, lang = LocalToWorld(vector_origin, angLH, vector_origin, inAng)
		local _, rang = LocalToWorld(vector_origin, angRH, vector_origin, inAng)

		placeHand(ply, "ValveBiped.Bip01_L_Hand", base - right * WB.HandSpread, lang)
		placeHand(ply, "ValveBiped.Bip01_R_Hand", base + right * WB.HandSpread, rang)

		wpn.lhandik = true
		wpn.rhandik = true
	end

	return
end

local function stop(ply)
	if not IsValid(ply) then return end
	ply:SetNWBool("hg_wallbang", false)
	ply:SetNWFloat("hg_wallbang_slam", 0)
	ply.wallbangNext = nil
	ply.wallbangReached = nil
	ply.wallbangApproachEnd = nil
end
WB.Stop = stop

local function canBrace(ply)
	if not IsValid(ply) or not ply:Alive() or IsValid(ply.FakeRagdoll) or ply:InVehicle() then return false end
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() ~= "weapon_hands_sh" then return false end
	if IsValid(ply:GetNetVar("carryent")) or IsValid(ply:GetNetVar("carryent2")) then return false end
	if ply:GetNetVar("handcuffed", false) then return false end
	local org = ply.organism
	if org and (org.otrub or not org.canmove) then return false end
	return hg.CanUseLeftHand(ply) and hg.CanUseRightHand(ply)
end

local function wallSurface(ent)
	if not IsValid(ent) then return false end
	if ent:IsPlayer() or ent:IsNPC() or ent:IsRagdoll() then return false end
	local phys = ent:GetPhysicsObject()
	return not IsValid(phys) or not phys:IsMotionEnabled()
end

function WB.Start(ply)
	if not canBrace(ply) then return false end

	local dir = ply:GetAimVector()
	dir.z = 0
	dir:Normalize()

	local eye = ply:EyePos()
	local tr = util.TraceLine({
		start = eye,
		endpos = eye + dir * WB.Reach,
		filter = ply,
		mask = MASK_PLAYERSOLID
	})

	if not tr.Hit or math.abs(tr.HitNormal.z) > 0.4 then return false end
	if not tr.HitWorld and not wallSurface(tr.Entity) then return false end

	local norm = Vector(tr.HitNormal.x, tr.HitNormal.y, 0)
	norm:Normalize()

	local wep = ply:GetActiveWeapon()
	if wep.SetFists then wep:SetFists(false) end

	ply:SetNWVector("hg_wallbang_pos", tr.HitPos)
	ply:SetNWVector("hg_wallbang_norm", norm)
	ply:SetNWFloat("hg_wallbang_slam", 0)
	ply:SetNWBool("hg_wallbang", true)
	ply.wallbangCount = ply.wallbangCount or 0
	ply.wallbangReached = nil
	ply.wallbangApproachEnd = CurTime() + WB.ApproachTime

	return true
end

local function headPos(ply)
	local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
	return bone and ply:GetBonePosition(bone) or ply:EyePos()
end

local function impact(ply)
	local org = ply.organism
	if not org or not hg.organism or not hg.organism.input_list then return end

	local wallPos, norm = WB.Plane(ply)
	local pos = headPos(ply)
	local hit = pos - norm * (pos - wallPos):Dot(norm)

	ply.wallbangCount = (ply.wallbangCount or 0) + 1

	local helmet = ply.armors and ply.armors["head"]
	local mul = helmet and 0.25 or 1

	local dmgInfo = DamageInfo()
	dmgInfo:SetDamageType(DMG_CLUB)
	dmgInfo:SetAttacker(ply)
	dmgInfo:SetInflictor(ply)
	dmgInfo:SetDamage(8 * mul)
	dmgInfo:SetDamagePosition(hit)
	dmgInfo:SetDamageForce(-norm * 50)

	local oldSkull = org.skull or 0
	local input = hg.organism.input_list

	if input.skull then input.skull(org, 0, math.Rand(0.12, 0.2) * mul, dmgInfo, nil, -norm) end
	if input.brainFrontal then input.brainFrontal(org, 0, math.Rand(0.05, 0.1) * mul, dmgInfo) end

	if oldSkull >= 1 then
		org.brain = math.min((org.brain or 0) + 0.07 * mul, 1)
		if hg.organism.AddBrainHemorrhage then hg.organism.AddBrainHemorrhage(org, 0.05 * mul, 0.002) end
	end

	local concussion = hg.organism.module and hg.organism.module.concussion
	if concussion and concussion.AddConcussion then
		local intensity = math.Clamp(0.4 + ply.wallbangCount * 0.15, 0.4, 3) * mul
		concussion.AddConcussion(org, intensity, math.Clamp(10 + intensity * 15, 12, 60))
	end

	if hg.organism.AddInstantPain then
		hg.organism.AddInstantPain(org, 12 * mul, "head")
	end

	org.consciousness = math.max((org.consciousness or 1) - 0.06 * mul, 0.2)
	org.disorientation = (org.disorientation or 0) + 0.4 * mul

	if oldSkull >= 0.5 and math.Rand(0, 1) < math.min(0.04 * ply.wallbangCount, 0.3) * mul then
		org.needotrub = true
	end

	if (org.skull or 0) >= 0.3 then
		hg.organism.AddWoundManual(ply, 6 + (org.skull or 0) * 6, VectorRand(-1.5, 1.5), angle_zero, "ValveBiped.Bip01_Head1", CurTime())
		util.Decal("Blood", hit + norm * 4, hit - norm * 8, ply)
	end

	ply:AddNaturalAdrenaline(0.2)
	ply:ViewPunch(Angle(math.Rand(6, 9), math.Rand(-2, 2), math.Rand(-4, 4)))

	ply:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav", 70, math.random(90, 105))
	ply:EmitSound("physics/flesh/flesh_impact_hard" .. math.random(1, 6) .. ".wav", 65, math.random(85, 100), 0.7)

	hook.Run("HomigradDamage", ply, dmgInfo, HITGROUP_HEAD, ply, 2 * mul)
end

function WB.Slam(ply)
	if (ply.wallbangNext or 0) > CurTime() then return end
	if not ply.wallbangReached or WB.WallDist(ply) > WB.HandReach then return end

	ply.wallbangNext = CurTime() + WB.Cooldown
	local start = CurTime()
	ply:SetNWFloat("hg_wallbang_slam", start)

	timer.Simple(WB.Impact, function()
		if not IsValid(ply) or not WB.Active(ply) or ply:GetNWFloat("hg_wallbang_slam", 0) ~= start then return end
		if not ply:Alive() then return end
		impact(ply)
	end)
end

hook.Add("Player Think", "hg_wallbang_think", function(ply)
	if not WB.Active(ply) then return end

	local dist = WB.WallDist(ply)
	if not ply.wallbangReached and dist <= WB.HandReach then
		ply.wallbangReached = true
		ply:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 55, math.random(95, 110), 0.5)
	end

	if not canBrace(ply) or dist < 1
		or (ply.wallbangReached and dist > WB.MaxDist)
		or (not ply.wallbangReached and (dist > WB.Reach + 8 or (ply.wallbangApproachEnd or 0) < CurTime())) then
		stop(ply)
	end
end)

hook.Add("PlayerDeath", "hg_wallbang_death", function(ply)
	stop(ply)
	ply.wallbangCount = nil
end)

hook.Add("PlayerSpawn", "hg_wallbang_spawn", function(ply)
	stop(ply)
	ply.wallbangCount = nil
end)
