hg = hg or {}
hg.organism = hg.organism or {}
hg.organism.fake_spine1 = 1
hg.organism.fake_spine2 = 1
hg.organism.fake_spine3 = 0.75
hg.organism.fake_legs = 1
hg.organism.input_list = hg.organism.input_list or {}

local vecZero, angZero = Vector(), Angle()
local hook_Run = hook.Run
local input_list = hg.organism.input_list
local head_otrub_min_damage = 0.05
local head_otrub_chance_mul = 1.25
local head_otrub_max_chance = 0.35
local head_consciousness_mul = 28
local head_otrub_consciousness_cap = 0.04
local brain_exposure_partial = 0.6
local brain_exposure_full = 1
local instant_pain_shock_scale = 0.75
local melee_pain_scale = 0.85
local melee_shock_scale = 0.45
local melee_nosebleed_pain_scale = 0.3
local goodmood_damage_max_bonus = 0.05
local attacker_adrenaline_gain_window = 2
local attacker_adrenaline_cooldown = 5
local attacker_adrenaline_cap = 1.5
local severe_damage_adrenaline_threshold = 25
local severe_damage_adrenaline_delay = 0.75
local catastrophic_brain_shot_chance_min = 0.25
local catastrophic_brain_shot_chance_max = 0.7
local catastrophic_brain_shot_damage_max = 50
local neck_break_kill_force_start = 800
local neck_break_kill_force_certain = 2400
local neck_break_decap_force_start = 1600
local neck_break_decap_force_certain = 3600
local player_limb_gib_threshold = 130
-- Heads should come apart before limbs under concentrated rifle fire.  This is
-- still high enough that ordinary rifle rounds need repeated hits, while a
-- true high-energy headshot can gib a standing target in one hit.
local player_head_gib_threshold = 85
local player_stomach_gib_threshold = 260
local player_blast_limb_gib_threshold = 80
local player_fall_head_gib_threshold = 1.2
local full_body_blast_gib_threshold = 3500
local full_body_blast_damage_threshold = 1000
local full_body_physics_speed_threshold = 2800
local full_body_physics_damage_threshold = 3000
local blast_gib_damage_mul = 700
local melee_gib_damage_mul = 0.35
local gore_damage_mul = 0.67
local ragdoll_fall_skull_damage_mul = 1.2
local ragdoll_fall_jaw_damage_mul = 0.45
local ragdoll_fall_skull_break_blood_mul = 1.15
local gib_damage_decay = {
	[HITGROUP_HEAD] = 3,
}
local body_part_health = {
	[HITGROUP_HEAD] = player_head_gib_threshold,
	[HITGROUP_LEFTLEG] = player_limb_gib_threshold,
	[HITGROUP_RIGHTLEG] = player_limb_gib_threshold,
	[HITGROUP_LEFTARM] = player_limb_gib_threshold,
	[HITGROUP_RIGHTARM] = player_limb_gib_threshold,
	[HITGROUP_STOMACH] = player_stomach_gib_threshold,
}
local body_part_heal = {
	[HITGROUP_HEAD] = 1,
	[HITGROUP_LEFTLEG] = 1,
	[HITGROUP_RIGHTLEG] = 1,
	[HITGROUP_LEFTARM] = 1,
	[HITGROUP_RIGHTARM] = 1,
	[HITGROUP_STOMACH] = 1,
}

-- Keep a penetrating bullet from damaging a limb bone belonging to a different
-- limb that happens to overlap the trace. This table was removed
-- with the old gib system even though Trace_Bullet still relies on it.
local bulletLimbBoneHitgroups = {
	larmup = HITGROUP_LEFTARM,
	larmdown = HITGROUP_LEFTARM,
	rarmup = HITGROUP_RIGHTARM,
	rarmdown = HITGROUP_RIGHTARM,
	llegup = HITGROUP_LEFTLEG,
	llegdown = HITGROUP_LEFTLEG,
	rlegup = HITGROUP_RIGHTLEG,
	rlegdown = HITGROUP_RIGHTLEG,
}

local function isFistInflictor(dmgInfo)
	local inflictor = dmgInfo and dmgInfo.GetInflictor and dmgInfo:GetInflictor() or nil
	if not IsValid(inflictor) or not inflictor:IsWeapon() then return false end

	local class = inflictor:GetClass()
	return class == "weapon_hands_sh" or class == "weapon_hg_coolhands"
end

local function Trace_Bullet(box, hit, ricochet, org, organs, dmg, dmgInfo, dir)
	dmg = dmgInfo:GetDamage() / 25
	local organ = box[6] and organs[box[6]][box[7]]
	if not organ then return 0 end
	local name = organ[1]
	if not name then return 0 end
	local requiredLimbHitgroup = bulletLimbBoneHitgroups[name]
	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
		and requiredLimbHitgroup
		and org._bulletImpactHitgroup
		and requiredLimbHitgroup ~= org._bulletImpactHitgroup then
		return 0
	end
	local isBrain = name == "brain" or string.StartWith(name, "brain")
	-- A fist can concuss through the skull, but cannot directly strike a protected
	-- brain hitbox. Snapshot this at the start of the trace so one punch that
	-- fractures the skull cannot also tunnel into the brain on that same hit.
	if org._fistHeadTraceSkullIntact and isBrain then return 0 end
	if org.superfighter and not (string.find(name,"vest") or string.find(name,"helmet")) then return 0 end
	if name == "stomach" or name == "intestines" then
		org.lastGibHitGroup = HITGROUP_STOMACH
		org.lastGibHitTime = CurTime()
	end
	local bone = organ[2] or 0
	local func = input_list[name]
	local brainExposure = 1
	local thoracicTrachea = name == "trachea" and box[6] == "ValveBiped.Bip01_Spine2"
	if thoracicTrachea then
		-- The thoracic airway is behind the ribs. It only becomes reachable
		-- after the ribcage has taken meaningful damage; neck hits remain direct.
		local chestExposure = math.Clamp(((org.chest or 0) - 0.35) / 0.65, 0, 1)
		if chestExposure <= 0 then return 0 end
		dmg = dmg * Lerp(chestExposure, 0.2, 1)
	end
	if isBrain then
		local skullDamage = math.Clamp(org.skull or 0, 0, brain_exposure_full)
		local bulletHeadPenetration = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
			and org._bulletImpactHitgroup == HITGROUP_HEAD
			and not (org.owner and org.owner.armors and org.owner.armors["head"] ~= nil)
		if skullDamage < brain_exposure_partial and not bulletHeadPenetration then return 0 end

		if not bulletHeadPenetration then
			brainExposure = math.Clamp((skullDamage - brain_exposure_partial) / (brain_exposure_full - brain_exposure_partial), 0, 1)
			-- At 0.6 the brain has only just become reachable; damage then ramps to
			-- its full traced value as the skull reaches complete destruction at 1.0.
			dmg = dmg * Lerp(brainExposure, 0.25, 1)
		end
	end
	local hook_info = {
		restricted = false,
		dmg = dmg,
		brainExposure = brainExposure,
	}
	
	hook_Run("PreTraceOrganBulletDamage", org, bone, dmg, dmgInfo, box, dir, hit, ricochet, organ, hook_info)
	
	dmg = hook_info.dmg
	
	

    if func and !hook_info.restricted then
        local old_consciousness = org.consciousness
        local directBrainBefore = isBrain and (org[name] or 0) or nil
        local result = func(org, bone, dmg, dmgInfo, box[6], dir, hit, ricochet)
        if isBrain and (org[name] or 0) > directBrainBefore then
            org._directBrainDamageThisHit = true
        end

		-- Vital-organ hits are more likely to retain enough energy to leave an
		-- exit wound. A negative resistance extends the remaining organ trace,
		-- while keeping exits probabilistic rather than guaranteeing them.
		if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) and (isBrain or name == "heart") then
			org._bulletHitVitalThisHit = true
			local exitBoostChance = isBrain and 0.8 or 0.7
			if math.Rand(0, 1) <= exitBoostChance then
				return (result or 0) - (isBrain and 0.45 or 0.35)
			end
		end

        return result
    else
        return 0
    end
end

local hitgrouptolimb

local function Trace_Blast(box, amt, org, organs, dmg, dmgInfo)
	dmg = dmgInfo:GetDamage() / 25
	local organ = box[6] and organs[box[6]][box[7]]
	if not organ then return 0 end
	local name = organ[1]
	if not name then return 0 end
	if org.superfighter and not (string.find(name,"vest") or string.find(name,"helmet")) then return 0 end
	local bone = organ[2] or 0
	local func = input_list[name]

	local amount = amt * dmg
	
	    if func then
        local limb = hitgrouptolimb[bonetohitgroup[organ[2]]]
        if limb then
            org.just_damaged_bone_limb = limb
        end
        return func(org, 1, amount, dmgInfo, box[6], vector_origin, true, false)
    end
end

local dir = Vector(0, 0, 0)
local CurTime = CurTime
local angZero = Angle(0, 0, 0)

local function AddGibDamageStack(org, hitgroup, damage)
	org.gibdmgstack = org.gibdmgstack or {}
	org.gibdmgstack[hitgroup] = org.gibdmgstack[hitgroup] or {0, CurTime()}
	local stack = org.gibdmgstack[hitgroup]
	local curtime = CurTime()
	stack[1] = math.max((stack[1] or 0) - (curtime - (stack[2] or curtime)) * (gib_damage_decay[hitgroup] or 0), 0) + damage
	stack[2] = curtime
	return stack[1]
end

local function DamageBodyPart(org, hitgroup, damage, maxHealth)
	maxHealth = maxHealth or body_part_health[hitgroup]
	if not maxHealth then return end

	org.gibhealth = org.gibhealth or {}
	org.gibhealth[hitgroup] = org.gibhealth[hitgroup] or {maxHealth, CurTime()}

	local health = org.gibhealth[hitgroup]
	local curtime = CurTime()
	health[1] = math.min((health[1] or maxHealth) + (curtime - (health[2] or curtime)) * body_part_heal[hitgroup], maxHealth)
	health[1] = math.max(health[1] - damage, 0)
	health[2] = curtime

	return maxHealth - health[1]
end

local RagdollDamageBoneMul = {
	[HITGROUP_LEFTLEG] = 0.25,
	[HITGROUP_RIGHTLEG] = 0.25,
	[HITGROUP_GENERIC] = 1,
	[HITGROUP_LEFTARM] = 0.25,
	[HITGROUP_RIGHTARM] = 0.25,
	[HITGROUP_CHEST] = 1,
	[HITGROUP_STOMACH] = 1,
	[HITGROUP_HEAD] = 0.1
}

local RagdollForceBoneMul = {
	[HITGROUP_LEFTLEG] = 0.5,
	[HITGROUP_RIGHTLEG] = 0.5,
	[HITGROUP_GENERIC] = 1,
	[HITGROUP_LEFTARM] = 0.5,
	[HITGROUP_RIGHTARM] = 0.5,
	[HITGROUP_CHEST] = 1,
	[HITGROUP_STOMACH] = 1,
	[HITGROUP_HEAD] = 0.5
}

bonetohitgroup = {
	["ValveBiped.Bip01_Head1"] = HITGROUP_HEAD,
	["ValveBiped.Bip01_L_UpperArm"] = HITGROUP_LEFTARM,
	["ValveBiped.Bip01_L_Forearm"] = HITGROUP_LEFTARM,
	["ValveBiped.Bip01_L_Hand"] = HITGROUP_LEFTARM,
	["ValveBiped.Bip01_R_UpperArm"] = HITGROUP_RIGHTARM,
	["ValveBiped.Bip01_R_Forearm"] = HITGROUP_RIGHTARM,
	["ValveBiped.Bip01_R_Hand"] = HITGROUP_RIGHTARM,
	["ValveBiped.Bip01_Pelvis"] = HITGROUP_STOMACH,
	["ValveBiped.Bip01_Spine2"] = HITGROUP_CHEST,
	["ValveBiped.Bip01_Spine1"] = HITGROUP_STOMACH,
	["ValveBiped.Bip01_Spine4"] = HITGROUP_CHEST,
	["ValveBiped.Bip01_Spine"] = HITGROUP_STOMACH,
	["ValveBiped.Bip01_L_Thigh"] = HITGROUP_LEFTLEG,
	["ValveBiped.Bip01_L_Calf"] = HITGROUP_LEFTLEG,
	["ValveBiped.Bip01_L_Foot"] = HITGROUP_LEFTLEG,
	["ValveBiped.Bip01_R_Thigh"] = HITGROUP_RIGHTLEG,
	["ValveBiped.Bip01_R_Calf"] = HITGROUP_RIGHTLEG,
	["ValveBiped.Bip01_R_Foot"] = HITGROUP_RIGHTLEG
}

local stomachFallbackBones = {
	"ValveBiped.Bip01_Spine1",
	"ValveBiped.Bip01_Spine",
	"ValveBiped.Bip01_Pelvis",
}

local stomachFallbackPhys = {
	0,
	1,
}

local function getDamageHitgroup(ent, bone, dmgPos)
	local bonename = ent:GetBoneName(ent:TranslatePhysBoneToBone(bone or 0))
	local hitgroup = bonetohitgroup[bonename] or 0
	if not ent:IsRagdoll() then return hitgroup, bonename end
	if hitgroup ~= 0 then return hitgroup, bonename end

	for i, physNum in ipairs(stomachFallbackPhys) do
		local realPhysNum = hg.realPhysNum and hg.realPhysNum(ent, physNum) or physNum
		local phys = ent:GetPhysicsObjectNum(realPhysNum)
		if IsValid(phys) and dmgPos:DistToSqr(phys:GetPos()) < 1225 then return HITGROUP_STOMACH, "ValveBiped.Bip01_Pelvis" end
	end

	for i, name in ipairs(stomachFallbackBones) do
		local fallbackBone = ent:LookupBone(name)
		local pos = fallbackBone and ent:GetBonePosition(fallbackBone)
		if pos and dmgPos:DistToSqr(pos) < 625 then return HITGROUP_STOMACH, name end
	end

	return hitgroup, bonename
end

local gibbedHeadForceBones = {
	"ValveBiped.Bip01_Neck1",
	"ValveBiped.Bip01_Spine4",
	"ValveBiped.Bip01_Spine2"
}

local function getGibbedHeadForcePhys(ent, bone)
	if not ent.headexploded or bone ~= ent:LookupBone("ValveBiped.Bip01_Head1") then return bone end
	for i, name in ipairs(gibbedHeadForceBones) do
		local newBone = ent:LookupBone(name)
		if newBone then return ent:TranslateBoneToPhysBone(newBone) end
	end
	return bone
end

hitgrouptolimb = {
	[HITGROUP_LEFTLEG] = "lleg",
	[HITGROUP_RIGHTLEG] = "rleg",
	[HITGROUP_LEFTARM] = "larm",
	[HITGROUP_RIGHTARM] = "rarm",
}

hg.bonetohitgroup = bonetohitgroup

hg.amputeetable = {
	--["ValveBiped.Bip01_L_UpperArm"] = "larm",
	["ValveBiped.Bip01_L_Forearm"] = "larm",
	["ValveBiped.Bip01_L_Hand"] = "larm",
	--["ValveBiped.Bip01_R_UpperArm"] = "rarm",
	["ValveBiped.Bip01_R_Forearm"] = "rarm",
	["ValveBiped.Bip01_R_Hand"] = "rarm",
	--["ValveBiped.Bip01_L_Thigh"] = "lleg",
	["ValveBiped.Bip01_L_Calf"] = "lleg",
	["ValveBiped.Bip01_L_Foot"] = "lleg",
	--["ValveBiped.Bip01_R_Thigh"] = "rleg",
	["ValveBiped.Bip01_R_Calf"] = "rleg",
	["ValveBiped.Bip01_R_Foot"] = "rleg"
}

local hitgrouptobone = {}
for bon,hitgroup in pairs(bonetohitgroup) do
	hitgrouptobone[hitgroup] = hitgrouptobone[hitgroup] or {}
	table.insert(hitgrouptobone[hitgroup],bon)
end

hg.DeathCam = false

function hg.organism.GasDamage(org, dmg, dmgInfo)
	hg.organism.input_list.lungsR(org, 1, dmg / 10, dmgInfo)
	hg.organism.input_list.lungsL(org, 1, dmg / 10, dmgInfo)
	hg.organism.input_list.trachea(org, 1, dmg / 10, dmgInfo)

end

function hg.organism.RadDamage(org, dmg, dmgInfo)
	hg.organism.GasDamage(org, dmg, dmgInfo)

	hg.organism.input_list.liver(org,nil,dmg / 20,dmgInfo)
	hg.organism.input_list.stomach(org,nil,dmg / 20,dmgInfo)
	hg.organism.input_list.intestines(org,nil,dmg / 20,dmgInfo)
end

local limbs = {
	["lleg"] = "ValveBiped.Bip01_L_Calf",
	["rleg"] = "ValveBiped.Bip01_R_Calf",
	["larm"] = "ValveBiped.Bip01_L_Forearm",
	["rarm"] = "ValveBiped.Bip01_R_Forearm",
}

local function getHeadImpactPos(ent, fallback)
	local headBone = ent:LookupBone("ValveBiped.Bip01_Head1")
	if headBone then
		local matrix = ent:GetBoneMatrix(headBone)
		if matrix then return matrix:GetTranslation() end
		local pos = ent:GetBonePosition(headBone)
		if pos and pos ~= ent:GetPos() then return pos end
	end

	return fallback
end

local sounds = {
	Sound("gore/blast.mp3"),
	Sound("gore/blast2.mp3"),
	Sound("gore/blast3.mp3"),
	Sound("gore/blast4.mp3"),
	Sound("gore/chop2.mp3"),
	Sound("gore/chop3.mp3"),
	Sound("gore/chop4.mp3"),
	Sound("gore/chop5.mp3"),
	Sound("gore/chop6.mp3")
}

local limb_loss_messages = {
    lleg = {
        "Your left leg was shattered by an impact.",
    },
    rleg = {
        "Your right leg was shattered by an impact.",
    },
    larm = {
        "Your left arm was shattered by an impact.",
    },
    rarm = {
        "Your right arm was shattered by an impact.",
    }
}

local ents_Create = ents.Create
function hg.organism.AmputateLimb(org, limb)
	if org[limb.."amputated"] == nil then return end

	local bone = limbs[limb]
	if !IsValid(org.owner) then return end
	local ownerBone = org.owner:LookupBone(bone)
	local len = ownerBone and org.owner:BoneLength(ownerBone) or 8
	local vec = Vector(len, 0, 0)
	local ang = Angle()
	local boneup = ownerBone and org.owner:GetBoneName(math.max(ownerBone - 1, 0)) or bone
	
	local wnds = {}

	for i, tbl in pairs(org.arterialwounds or {}) do
		if tbl[7] != limb.."artery" then
			table.insert(wnds, tbl)
		end
	end
	-- Amputation has a broad stump bleed, not a full-pressure generic arterial
	-- jet.  The final marker is consumed by blood/client effects to avoid the
	-- normal arterial multipliers and excessive spray range.
	table.insert(wnds, {10, vec, ang, boneup, CurTime(), Vector(-100, 0, 0), bone.."artery", false, true})
	
	org.arterialwounds = wnds
	hg.organism.SyncWounds(org)

	org[limb.."amputated"] = true

	-- Track that this limb was previously amputated for stable healing approach
	org.owner.HG_PreviouslyAmputated = org.owner.HG_PreviouslyAmputated or {}
	org.owner.HG_PreviouslyAmputated[limb] = true

	for i = 1, 5 do
		hg.organism.AddWoundManual(org.owner, 50, vec + VectorRand(-2, 2), ang, boneup, CurTime() + math.Rand(0, 2))
	end

	local damageInput = hg.organism.input_list[limb.."up"]
	if damageInput then
		local dmgInfo = DamageInfo()
		damageInput(org, 0, 5, dmgInfo)
	end

	org.owner:EmitSound(sounds[math.random(#sounds)], 95, math.random(95, 105), 2)



	
	local ent = hg.GetCurrentCharacter(org.owner)
	if IsValid(ent) then
		local limbBone = ent:LookupBone(bone)
		local pos = limbBone and select(1, ent:GetBonePosition(limbBone)) or ent:GetPos()
		if hg.SpawnLimbGore then
			hg.SpawnLimbGore(ent, pos, limb)
		else
			SpawnMeatGore(ent, pos, 4)
		end
	end

	hook.Run("OnAmputateLimb", org, ent, limb)

	if org.owner:IsNPC() then
		org.shock = 100
	end

	net.Start("organism_send")
	local tbl = {}
	tbl[limb.."amputated"] = true
	tbl.owner = org.owner
	net.WriteTable(tbl)
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(false)
	net.WriteBool(true) // вот эта шняга отвечает за то чтобы оно просто мерджнуло и всё
	net.Broadcast()
end

--hg.organism.AmputateLimb(Entity(2).organism, "rarm")

function hg.organism.CompleteDislocationFix(org, limb, ply)
	if not org[limb .. "dislocation"] then return end

	org[limb .. "dislocation"] = false
	org.painadd = (org.painadd or 0) + 6
	org.fearadd = (org.fearadd or 0) + 0.1

	if IsValid(org.owner) then
		org.owner:EmitSound("physics/flesh/flesh_impact_hard6.ogg", 65)
	end

	-- Reapply floppy limb constraints if the limb is broken
	-- Skip if limb is amputated
	if ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
		local isAmputated = org[limb .. "amputated"]
		if isAmputated then
			-- Don't apply constraints to amputated limbs
		elseif org[limb] and org[limb] >= 1 then
			local ent = hg.GetCurrentCharacter(org.owner)
			if IsValid(ent) then
				hg.BreakLimb(ent, limb, nil, false)
			end
		else
			-- Remove floppy constraints if the limb is no longer broken
			-- But if it was previously amputated, use stable approach - don't mess with it
			local wasAmputated = org.owner.HG_PreviouslyAmputated and org.owner.HG_PreviouslyAmputated[limb]
			if wasAmputated then
				-- Let the organism stabilize naturally
			else
				local ent = hg.GetCurrentCharacter(org.owner)
				if IsValid(ent) then
					hg.RemoveLimbConstraints(ent, limb)
				end
			end
		end
	end
end

function hg.organism.AddWound(ent, tr, bone, dmgInfo, dmgPos, dmgBlood, inputHole, outputHole)
	local org = ent.organism
	if org.superfighter then return end
	
	local physBone = bone != -1 and bone or math.random(0, ent:GetPhysicsObjectCount() - 1)
	local bone = ent:TranslatePhysBoneToBone(physBone)
	dmgPos = ent:GetBonePosition(bone)
	
	if bone and dmgBlood > 0 then
		for i = 1, 2 do
			local bonePos, boneAng = ent:GetBonePosition(bone)
			
			if not bonePos then return end

			dmgPos = (i == 1 and inputHole[1] or outputHole[1]) or dmgPos
			
			if i == 2 and not outputHole[1] then continue end
			if i == 1 and not outputHole[1] then dmgBlood = dmgBlood * 2 end

			if dmgInfo:IsDamageType(DMG_BLAST) or dmgInfo:GetAttacker():IsNPC() or (ent:IsPlayer() and ent:InVehicle()) then dmgPos = bonePos end

			local localPos, localAng = WorldToLocal(dmgPos + ((i == 1 and 1 or -1) * tr.HitNormal), (i == 1 and -1 or 1) * tr.Normal:Angle(), bonePos, boneAng)
			if #org.wounds < 30 then
				table.insert(org.wounds,{dmgBlood / 2, localPos, localAng, ent:GetBoneName(bone), CurTime()})
			else
				if org.wounds[1] then org.wounds[1][1] = org.wounds[1][1] + dmgBlood / 2 end
			end
			if hg.AddOrganismBloodDecal then hg.AddOrganismBloodDecal(org.owner) end
			
			table.sort(org.wounds, function(a, b) return a[1] > b[1] end)
			
			if #org.wounds <= 30 then
				timer.Create("WoundsSend"..ent:EntIndex(),0.1,1,function()
					hg.organism.SyncWounds(org)
				end)
			end
		end
	end
end

function hg.organism.AddWoundManual(ent,dmgBlood,localPos,localAng,bone,time)
	local org = ent.organism
	if org.superfighter then return end
	
	if isnumber(bone) then bone = ent:GetBoneName(bone) end

	if #org.wounds < 30 then
		table.insert(org.wounds,{dmgBlood / 2, localPos, localAng, bone, time})
	else
		if org.wounds[1] then org.wounds[1][1] = org.wounds[1][1] + dmgBlood / 2 end
	end
	if hg.AddOrganismBloodDecal then hg.AddOrganismBloodDecal(org.owner) end
	
	table.sort(org.wounds, function(a, b) return a[1] > b[1] end)

	if #org.wounds <= 30 then
		timer.Create("WoundsSend"..ent:EntIndex(),0.1,1,function()
			hg.organism.SyncWounds(org)
		end)
	end
end

local NOSEBLEED_MIN_HARM = 18
local NOSEBLEED_COOLDOWN = 12
local NOSEBLEED_PAIN_MIN = 4
local NOSEBLEED_PAIN_MAX = 11
local nosebleedLocalPos = Vector(3.5, 0, -3.5)
local nosebleedLocalAng = Angle(90, 0, 0)

local function nosebleedTimerName(ply)
	return "ZCity_NosebleedCleanup" .. ply:EntIndex()
end

local function resetNosebleed(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	if ply.organism then
		ply.organism.nextNosebleed = 0
	end

	ply:SetNWFloat("ZCity_NosebleedUntil", 0)
	timer.Remove(nosebleedTimerName(ply))
end

local function queueNosebleedCleanup(ply, bleedUntil)
	timer.Remove(nosebleedTimerName(ply))
	timer.Create(nosebleedTimerName(ply), math.max(bleedUntil - CurTime(), 0) + 0.1, 1, function()
		if not IsValid(ply) then return end
		if ply:GetNWFloat("ZCity_NosebleedUntil", 0) <= CurTime() then
			resetNosebleed(ply)
		end
	end)
end

local function isBluntMeleeInflictor(dmgInfo)
	local inflictor = dmgInfo and dmgInfo.GetInflictor and dmgInfo:GetInflictor() or nil
	if not IsValid(inflictor) or not inflictor:IsWeapon() then return false end

	local class = inflictor:GetClass()
	if class == "weapon_hands_sh" or class == "weapon_hg_coolhands" then return true end

	local stored = weapons.GetStored(class)
	return inflictor.Base == "weapon_melee" or (stored and stored.Base == "weapon_melee")
end

local function isBluntFaceHit(dmgInfo, hitgroup, harm)
	if hitgroup ~= HITGROUP_HEAD then return false end
	if not isnumber(harm) or harm < NOSEBLEED_MIN_HARM then return false end
	if not dmgInfo or not dmgInfo.IsDamageType then return false end
	if not isBluntMeleeInflictor(dmgInfo) then return false end

	return dmgInfo:IsDamageType(DMG_CLUB) or dmgInfo:IsDamageType(DMG_CRUSH)
end

local function applyNosebleed(ent, harm, ignoreCooldown)
	local ply = hg and hg.RagdollOwner and hg.RagdollOwner(ent) or ent
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

	local org = ply.organism
	if not org or not org.alive or org.superfighter then return end

	local time = CurTime()
	if not ignoreCooldown and (org.nextNosebleed or 0) > time then return end

	local character = hg and hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) or ply
	if not IsValid(character) or not character.organism then character = ply end
	if not IsValid(character) or not character.LookupBone then return end

	local headBone = character:LookupBone("ValveBiped.Bip01_Head1")
	if not headBone then return end

	org.nextNosebleed = time + NOSEBLEED_COOLDOWN

	local woundPower = math.Clamp(harm * 0.55, 10, 28)
	org.painadd = (org.painadd or 0) + math.Clamp(harm * 0.2, NOSEBLEED_PAIN_MIN, NOSEBLEED_PAIN_MAX) * melee_nosebleed_pain_scale
	hg.organism.AddWoundManual(character, woundPower, nosebleedLocalPos, nosebleedLocalAng, headBone, time)
	local bleedUntil = math.max(ply:GetNWFloat("ZCity_NosebleedUntil", 0), time + math.Clamp(harm * 2.2, 28, 75))
	ply:SetNWFloat("ZCity_NosebleedUntil", bleedUntil)
	queueNosebleedCleanup(ply, bleedUntil)

	if ply.Notify then
		ply:Notify("My nose is bleeding.", 8, "nosebleed", 0)
	end

	return true
end

hg.applyNosebleed = applyNosebleed

hook.Add("PlayerSpawn", "ZCity_ResetNosebleed", function(ply)
	resetNosebleed(ply)
	timer.Simple(0, function()
		resetNosebleed(ply)
	end)
end)

hook.Add("HomigradDamage", "ZCity_BluntFaceNosebleed", function(ent, dmgInfo, hitgroup, attackerEnt, harm)
	if not isBluntFaceHit(dmgInfo, hitgroup, harm) then return end

	applyNosebleed(ent, harm)
end)

-- Deliberate sharp melee strikes close to the neck create a throat-cut state,
-- not merely an ordinary head hit. Bullets continue to use the normal organ
-- trace/artery path.
local THROAT_CUT_MIN_DAMAGE = 5
local THROAT_CUT_NECK_DIST_SQR = 22 * 22

local function isSharpMeleeInflictor(dmgInfo)
	local inflictor = dmgInfo and dmgInfo.GetInflictor and dmgInfo:GetInflictor() or nil
	if not IsValid(inflictor) or not inflictor:IsWeapon() or inflictor.ThroatCutCapable == false then return false end
	if inflictor.DamageType == DMG_SLASH then return true end
	local stored = weapons.GetStored(inflictor:GetClass())
	return stored and stored.DamageType == DMG_SLASH
end

hook.Add("HomigradDamage", "ZCity_SlashThroatCut", function(ent, dmgInfo, hitgroup, attackerEnt, harm)
	if hitgroup ~= HITGROUP_HEAD and hitgroup ~= HITGROUP_GENERIC and hitgroup ~= 0 then return end
	if not dmgInfo or not dmgInfo:IsDamageType(DMG_SLASH) or dmgInfo:GetDamage() < THROAT_CUT_MIN_DAMAGE then return end
	if not isSharpMeleeInflictor(dmgInfo) then return end

	local owner = hg.RagdollOwner and hg.RagdollOwner(ent) or ent
	if not IsValid(owner) or not owner.organism or owner.organism.throatcut then return end
	local character = hg.GetCurrentCharacter and hg.GetCurrentCharacter(owner) or ent
	if not IsValid(character) or not character.LookupBone then return end
	local neckBone = character:LookupBone("ValveBiped.Bip01_Neck1")
	if not neckBone then return end
	local neckPos = character:GetBonePosition(neckBone)
	local hitPos = dmgInfo:GetDamagePosition()
	if not isvector(neckPos) or not isvector(hitPos) or hitPos:DistToSqr(neckPos) > THROAT_CUT_NECK_DIST_SQR then return end

	local force = dmgInfo:GetDamageForce()
	local dir = isvector(force) and force:LengthSqr() > 1 and force:GetNormalized() or nil
	local severity = math.Clamp((dmgInfo:GetDamage() + (tonumber(harm) or 0) * 0.18) / 18, 0.6, 1.15)
	hg.organism.CutThroat(ent, dmgInfo, hitPos, dir, severity)
end)

concommand.Add("zc_debug_nosebleed", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	local enabled = not GetGlobalBool("ZCity_DebugNosebleed", false)
	SetGlobalBool("ZCity_DebugNosebleed", enabled)

	if IsValid(ply) then
		ply:ChatPrint("Nosebleed debug " .. (enabled and "enabled" or "disabled") .. ".")
	else
		print("Nosebleed debug " .. (enabled and "enabled" or "disabled") .. ".")
	end
end)

hook.Add("HomigradDamage", "ZCity_BluntFaceNosebleedDebug", function(ent, dmgInfo, hitgroup, attackerEnt, harm)
	if not GetGlobalBool("ZCity_DebugNosebleed", false) then return end
	if hitgroup ~= HITGROUP_HEAD then return end

	local attacker = dmgInfo and dmgInfo.GetAttacker and dmgInfo:GetAttacker() or nil
	local inflictor = dmgInfo and dmgInfo.GetInflictor and dmgInfo:GetInflictor() or nil
	if not IsValid(attacker) or not attacker:IsPlayer() then return end

	local msg = string.format(
		"[NosebleedDebug] victim=%s harm=%.2f dmgClub=%s dmgCrush=%s inflictor=%s base=%s melee=%s",
		IsValid(ent) and tostring(ent) or "NULL",
		isnumber(harm) and harm or -1,
		tostring(dmgInfo and dmgInfo.IsDamageType and dmgInfo:IsDamageType(DMG_CLUB) or false),
		tostring(dmgInfo and dmgInfo.IsDamageType and dmgInfo:IsDamageType(DMG_CRUSH) or false),
		IsValid(inflictor) and inflictor:GetClass() or "NULL",
		IsValid(inflictor) and tostring(inflictor.Base) or "nil",
		tostring(isBluntMeleeInflictor(dmgInfo))
	)

	attacker:ChatPrint(msg)
	print(msg)
end)

concommand.Add("zc_test_nosebleed", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsAdmin() then return end

	local target = ply
	if IsValid(ply) then
		local tr = ply:GetEyeTrace()
		if tr and IsValid(tr.Entity) then
			target = hg and hg.RagdollOwner and hg.RagdollOwner(tr.Entity) or tr.Entity
		end
	elseif args and args[1] then
		target = Entity(tonumber(args[1]) or 0)
	end

	if not IsValid(target) or not target:IsPlayer() then
		if IsValid(ply) then ply:ChatPrint("Look at a player/fake ragdoll or run zc_test_nosebleed on yourself.") end
		return
	end

	local harm = tonumber(args and args[1]) or 30
	if applyNosebleed(target, harm, true) and IsValid(ply) then
		ply:ChatPrint("Forced nosebleed on " .. target:Name() .. " with harm " .. tostring(harm) .. ".")
	end
end)

--[[hook.Add( "PlayerDeath", "GlobalDeathMessage", function( victim, inflictor, attacker )
	if victim:IsAdmin() or victim:IsSuperAdmin() then return end
    victim:Kick("uh... you died")
end )
PrintMessage(HUD_PRINTCENTER,"SYNC ON")]]--
--

local headcrabs = {
	["npc_headcrab"] = true,
	["npc_headcrab_fast"] = true,
	["npc_headcrab_black"] = true,
}

local headcrabsmodels = {
	["npc_headcrab"] = "models/headcrabclassic.mdl",
	["npc_headcrab_fast"] = "models/headcrab.mdl",
	["npc_headcrab_black"] = "models/headcrabblack.mdl",
}

local hg_norespawn = ConVarExists("hg_norespawn") and GetConVar("hg_norespawn") or CreateConVar("hg_norespawn",0,FCVAR_SERVER_CAN_EXECUTE,"Disable respawns in any gamemode (useful for hg_sync)",0,1)

hook.Add("PlayerDeathThink","stoprespawning",function()
	if hg_norespawn:GetBool() then return true end
end)

hook.Add("PlayerSpawn", "hg_brain_burst_reset", function(ply)
	local org = ply.organism
	if not org then return end
	org.brainBurstDamage = 0
	org.brainBurstWindowStart = 0
	org.brainBurstLast = 0
end)

hook.Add("PlayerSpawn", "hg_spine_floppy_reset", function(ply)
	ply.HG_SpineFloppyPersist = nil
	if hg.RemoveSpineConstraints then
		hg.RemoveSpineConstraints(ply)
	end
end)

hook.Add("PlayerDeath", "hg_death_organism_cleanup", function(victim)
	local org = victim.organism

	if not org then return end

	org.brainBurstDamage = 0
	org.brainBurstWindowStart = 0
	org.brainBurstLast = 0

	if math.Round(victim:GetInfoNum("hg_deathfadeout", 1)) == 1 then
		QueueHeadDisfigurement(victim, org)
	end
end)

--util.AddNetworkString("tracePosesSend")
--util.AddNetworkString("wound_debug")
util.AddNetworkString("hg_bloodimpact")
--util.AddNetworkString("blood particle explode")
util.AddNetworkString("bloodsquirt")
util.AddNetworkString("hg_brainmist")


--util.AddNetworkString("tracePosesSend")
--util.AddNetworkString("wound_debug")
util.AddNetworkString("hg_bloodimpact")
--util.AddNetworkString("blood particle explode")
util.AddNetworkString("bloodsquirt")

local hg_developer = ConVarExists("hg_developer") and GetConVar("hg_developer") or CreateConVar("hg_developer",0,FCVAR_SERVER_CAN_EXECUTE,"Toggle developer mode (enables damage traces)",0,1)

local npcDmg = {
	npc_combine_s = {
		["ValveBiped.Bip01_Head1"] = 0.5,
		["ValveBiped.Bip01_L_UpperArm"] = 0.5,
		["ValveBiped.Bip01_L_Forearm"] = 0.5,
		["ValveBiped.Bip01_L_Hand"] = 1,
		["ValveBiped.Bip01_R_UpperArm"] = 0.5,
		["ValveBiped.Bip01_R_Forearm"] = 0.5,
		["ValveBiped.Bip01_R_Hand"] = 1,
		["ValveBiped.Bip01_Pelvis"] = {0.1,{"MetalSpark"}},
		["ValveBiped.Bip01_Spine2"] = {0.1,{"MetalSpark"}},
		["ValveBiped.Bip01_L_Thigh"] = 0.5,
		["ValveBiped.Bip01_L_Calf"] = 1,
		["ValveBiped.Bip01_L_Foot"] = 1,
		["ValveBiped.Bip01_R_Thigh"] = 0.5,
		["ValveBiped.Bip01_R_Calf"] = 1,
		["ValveBiped.Bip01_R_Foot"] = 1,
	},
	npc_hunter = 1,
	npc_metropolice = {
		["ValveBiped.Bip01_Head1"] = 1,
		["ValveBiped.Bip01_L_UpperArm"] = 1,
		["ValveBiped.Bip01_L_Forearm"] = 1,
		["ValveBiped.Bip01_L_Hand"] = 1,
		["ValveBiped.Bip01_R_UpperArm"] = 1,
		["ValveBiped.Bip01_R_Forearm"] = 1,
		["ValveBiped.Bip01_R_Hand"] = 1,
		["ValveBiped.Bip01_Pelvis"] = {0.25,{"Impact",77}},
		["ValveBiped.Bip01_Spine2"] = {0.25,{"Impact",77}},
		["ValveBiped.Bip01_L_Thigh"] = 1,
		["ValveBiped.Bip01_L_Calf"] = 1,
		["ValveBiped.Bip01_L_Foot"] = 1,
		["ValveBiped.Bip01_R_Thigh"] = 1,
		["ValveBiped.Bip01_R_Calf"] = 1,
		["ValveBiped.Bip01_R_Foot"] = 1,
	},
	npc_zombie = 1,
	npc_zombie_torso = 1,
	npc_zombine = 1,
	npc_poisonzombie = 1,
	npc_fastzombie = 1,
}

function hg.NPCDamage(ent,dmgInfo,npcdmg)
	local tr = hg.GetTraceDamage(ent, dmgInfo:GetDamagePosition(), dmgInfo:GetDamageForce())
	local bone = ent:GetBoneName(ent:TranslatePhysBoneToBone(tr.PhysicsBone))
	
	if istable(npcdmg) then
		if npcdmg[bone] then
			local val = istable(npcdmg[bone]) and npcdmg[bone][1] or npcdmg[bone]
			dmgInfo:ScaleDamage(val)
			if istable(npcdmg[bone]) and npcdmg[bone][2] then
				hg.ArmorEffectEx(ent,dmgInfo,unpack(npcdmg[bone][2]))
			end
		end
	else
		dmgInfo:ScaleDamage(npcdmg)
	end
end

function hg.AddHarmToAttacker(dmgInfo, harm, reason)
	local ply = dmgInfo:GetAttacker()

	if IsValid(ply) and ply:IsPlayer() then
		hg.AddHarm(ply, harm, reason)
	end
end

function hg.AddHarm(ply, harm, reason)
	if hg_developer:GetBool() and isstring(reason) then
		//ply:ChatPrint(reason..": harm count is "..math.Round(harm,2))
	end

	ply.harm = (ply.harm or 0) + (harm or 0)
end

function hg.ExplodeHead(ent, damage, slash, force)
	if !IsValid(ent) then return end

	local ply = ent:IsRagdoll() and hg.RagdollOwner(ent) or ent
	if ent:IsNPC() and ent.organism then ent.organism.shock = 100 end
	local target = ent
	target._headGibPending = target._headGibPending or false
	if target._headGibPending then return end
	target._headGibPending = true
	local standingPlayer = IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply or nil
	local deathHookName = standingPlayer and "HG_StandingHeadGib_" .. standingPlayer:EntIndex() or nil

	local attempts = 0
	local function finishHeadGib(createdRagdoll)
		if not IsValid(target) then return end

		local ent = IsValid(createdRagdoll) and createdRagdoll or target:IsRagdoll() and target or target:GetNWEntity("RagdollDeath")
		if not IsValid(ent) then ent = target.FakeRagdoll end
		if not IsValid(ent) then
			attempts = attempts + 1
			-- Player death and the death ragdoll are not guaranteed to be created in
			-- the same tick.  A head hit can therefore kill the player successfully
			-- while the old 0.25 second retry window expires before there is anything
			-- to gib.  Keep the pending result alive long enough for the ragdoll path
			-- to finish on busy servers as well.
			if attempts < 30 then
				timer.Simple(0.05, finishHeadGib)
			else
				target._headGibPending = nil
			end
			return
		end
		if ent.headexploded then
			target._headGibPending = nil
			return
		end
		--[[if not isbool(ent) then
			hook.Run("OnHeadExplode", ply, ent)
		end]]

		-- sv_input can be hot-reloaded independently of the head-gib module.  Do
		-- not mark the ragdoll as exploded until the implementation that removes
		-- the head bone is actually present; otherwise later hits cannot recover
		-- and this timer used to throw a nil-global error.
		if not isfunction(Gib_Input) then
			include("homigrad/headgib/init_sv.lua")
		end

		if not isfunction(Gib_Input) then
			attempts = attempts + 1
			if attempts < 30 then
				timer.Simple(0.05, finishHeadGib)
			else
				target._headGibPending = nil
			end
			return
		end

		Gib_Input(ent, ent:LookupBone("ValveBiped.Bip01_Head1"), force, damage)
		
		ent.organism.headamputated = true
		ent.organism.brain = 1.0
		ent.organism.skull = 1.0
		ent.organism.alive = false
		ent.headexploded = true

		-- Track that head was previously amputated for stable healing approach
		ent.organism.owner.HG_PreviouslyAmputated = ent.organism.owner.HG_PreviouslyAmputated or {}
		ent.organism.owner.HG_PreviouslyAmputated["head"] = true

		ent.organism.owner.fullsend = true
		hg.send_bareinfo(ent.organism)
	end

	-- DoPlayerDeath creates the ragdoll and emits RagdollDeath during Kill(). Arm
	-- this listener before making a standing player fatal so we gib the exact
	-- corpse rather than hoping its replicated reference exists next frame.
	if standingPlayer then
		hook.Add("RagdollDeath", deathHookName, function(deadPlayer, ragdoll)
			if deadPlayer != standingPlayer then return end
			hook.Remove("RagdollDeath", deathHookName)
			timer.Simple(0, function() finishHeadGib(ragdoll) end)
		end)

		local org = standingPlayer.organism
		if org then
			org.brain = 1.0
			org.skull = 1.0
			org.needfake = true
			if hg.organism.KillFatalBrainDamage then
				hg.organism.KillFatalBrainDamage(org)
			else
				org.alive = false
				standingPlayer:Kill()
			end
		else
			standingPlayer:Kill()
		end

		-- Keep a fallback for death paths that do not emit RagdollDeath.
		timer.Simple(0.05, function()
			if deathHookName then hook.Remove("RagdollDeath", deathHookName) end
			finishHeadGib()
		end)
	else
		timer.Simple(0, finishHeadGib)
	end
end

local hg_bloodimpacts = ConVarExists("hg_bloodimpacts") and GetConVar("hg_bloodimpacts") or CreateConVar("hg_bloodimpacts", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable custom blood impact effects spray cool kill death", 0, 1)

local net, math, hg, IsValid = net, math, hg, IsValid
local takeRagdollDamage

-- Rapid-fire damage can arrive several times inside one server tick.  Keep the
-- entry and exit streams separate, but coalesce each stream without replacing
-- its pending timer or losing the accumulated impact count.
local function queueBulletBloodImpact(ent, stream, pos, velocity, damage, severe)
	if not IsValid(ent) then return end

	ent._pendingBulletBloodImpacts = ent._pendingBulletBloodImpacts or {}
	local pending = ent._pendingBulletBloodImpacts[stream]
	if not pending then
		pending = {amount = 0}
		ent._pendingBulletBloodImpacts[stream] = pending
	end

	pending.pos = pos
	pending.velocity = velocity
	pending.damage = damage
	pending.severe = pending.severe or severe
	pending.amount = math.min((pending.amount or 0) + 1, 32)
	if pending.queued then return end
	pending.queued = true

	timer.Simple(0.02, function()
		if not IsValid(ent) then return end
		local queued = ent._pendingBulletBloodImpacts and ent._pendingBulletBloodImpacts[stream]
		if not queued then return end
		ent._pendingBulletBloodImpacts[stream] = nil

		net.Start("hg_bloodimpact")
		net.WriteVector(queued.pos)
		net.WriteVector(queued.velocity)
		net.WriteFloat(queued.damage)
		net.WriteInt(queued.amount, 8)
		net.WriteBool(queued.severe or false)
		net.WriteBool(stream == "exit")
		net.Broadcast()
	end)
end

hook.Add("EntityTakeDamage", "homigrad-damage", function(ent, dmgInfo)

	if dmgInfo:IsDamageType(DMG_DISSOLVE) then return end

	local attacker = dmgInfo:GetAttacker()
	
	local org = ent.organism
    if dmgInfo:IsDamageType(DMG_FALL) and dmgInfo:GetDamage() > 40 then
        timer.Simple(0, function()
            if not IsValid(ent) or not ent:IsPlayer() then return end
            ent:Notify("The fall knocked the wind out of you.")
        end)
    end

	if hg.TryExtinguisherBulletBlock and hg.TryExtinguisherBulletBlock(ent, dmgInfo) then return true end

	-- Glass damage to ragdoll...
	if IsValid(ent) and string.find(ent:GetClass(),"break") and 
		ent:GetBrushSurfaces() and ent:GetBrushSurfaces()[1] and string.find(ent:GetBrushSurfaces()[1]:GetMaterial():GetName(),"glass") and 
		IsValid(dmgInfo:GetInflictor()) and dmgInfo:GetInflictor() == dmgInfo:GetAttacker() and dmgInfo:GetInflictor().organism then
			hg.organism.AddWoundManual(dmgInfo:GetInflictor(),math.random(35,45),vector_origin,angle_zero,math.random(0,ent:GetBoneCount()),CurTime()) 
	end
	
	if ent:GetClass() == "npc_bullseye" then
		if dmgInfo:IsDamageType(DMG_BLAST) then return true end

		local rag = IsValid(ent.rag) and ent.rag or IsValid(ent.ply) and ent.ply
	
		if IsValid(rag) then
			rag:TakeDamageInfo(dmgInfo)
		end
		
		return true
	end

	if not org then return end

	if dmgInfo:GetAttacker():GetClass() == "npc_zombie" then
		--if not org then return end 
		dmgInfo:SetDamageType( org and org.immobilization > 50 and DMG_BLAST or DMG_SLASH )
		attacker.ImmobilizationMul = 2
		attacker.PainMultiplier = 0.5
		attacker.BleedMultiplier = 5
		attacker.Penetration = 5
		dmgInfo:ScaleDamage(1.2)
		--dmgInfo:SetDamagePosition(ent:GetPos())
	end

	--[[if hgIsDoor(ent) and ent.LockedDoor and dmgInfo:IsDamageType(DMG_SLASH) then
		ent.LockedDoor = ent.LockedDoor - dmgInfo:GetDamage()
		if ent.LockedDoor <= 0 then
			ent:Fire("unlock","",0)
		end
	end

	if dmgInfo:IsDamageType(DMG_SLASH) and ent.DuctTape and next(ent.DuctTape) then
		local key = next(ent.DuctTape)
		local duct = ent.DuctTape[key]
		
		duct[2] = duct[2] - dmgInfo:GetDamage()
		if duct[2] <= 0 then
			if IsValid(duct[1]) then
				duct[1]:Remove()
				duct[1] = nil
			end
			ent.DuctTape[key] = nil
		end
	end--]]
	
	--if ent:IsNPC() and npcDmg[ent:GetClass()] then hg.NPCDamage(ent,dmgInfo,npcDmg[ent:GetClass()]) return end
	if ent:IsPlayer() and IsValid(ent.FakeRagdoll) then ent.FakeRagdoll:TakeDamageInfo(dmgInfo) return true end
	
	if dmgInfo:IsDamageType(DMG_CRUSH) then
		return true
		--if ent:GetVelocity():Length() < 500 - math.min( ((IsValid(dmgInfo:GetAttacker():GetPhysicsObject()) and dmgInfo:GetAttacker():GetClass() == "prop_physics") and dmgInfo:GetAttacker():GetPhysicsObject():GetMass() + dmgInfo:GetAttacker():GetVelocity():Length()/2) or 0, 300) then return end
	end

	local dmgtype = dmgInfo:GetDamageType()
	
	if org.godmode then return true end

	local ply = (ent:IsPlayer() and ent) or hg.RagdollOwner(ent)

	org.isPly = IsValid(ply)

	if ent == ply and IsValid(ply.FakeRagdoll) and dmgInfo:IsDamageType(DMG_BURN) then
		return true
	end

	local time = CurTime()

	local inf = IsValid(dmgInfo:GetInflictor()) and not dmgInfo:GetInflictor():IsPlayer() and dmgInfo:GetInflictor() or (dmgInfo:GetAttacker():IsPlayer() and dmgInfo:GetAttacker():GetActiveWeapon()) or dmgInfo:GetAttacker()
	inf = IsValid(inf.weapon) and inf.weapon or inf
	if IsValid(inf) then dmgInfo:SetInflictor(inf) end

	if dmgInfo:IsDamageType(DMG_BUCKSHOT) then
		dmgInfo:ScaleDamage(1.35)
	elseif dmgInfo:IsDamageType(DMG_BULLET) then
		dmgInfo:ScaleDamage(1.15)
	end
	
	local dmg = dmgInfo:GetDamage()

	local bullet = inf.bullet
	
	local pen = 	( bullet ~= nil and bullet.Penetration ) or 
					( IsValid(inf) and inf.Penetration ) or dmg / 2

	pen = pen * (dmgInfo:IsDamageType(DMG_CLUB+DMG_GENERIC) and 1 or 1)
	--pen = pen * ( IsValid(inf) and inf.PenetrationMultiplier or 1 )
	
	local size = 	( bullet ~= nil and bullet.Diameter ) or 
					( IsValid(inf) and inf.PenetrationSize ) or pen / 50

	local maxpen = 	( bullet ~= nil and bullet.MaxPenLen ) or 
					( IsValid(inf) and inf.MaxPenLen ) or 0
	
	if PenetrationGlobal then
		pen = PenetrationGlobal
		
		PenetrationGlobal = nil
	end

	if MaxPenLenGlobal then
		maxpen = MaxPenLenGlobal

		MaxPenLenGlobal = nil
	end

	local shockMul = 	( bullet ~= nil and bullet.ShockMultiplier ) or
						( IsValid(inf) and inf.ShockMultiplier ) or 1

	local bleedMul = 	( bullet ~= nil and bullet.BleedMultiplier ) or
						( IsValid(inf) and inf.BleedMultiplier ) or 1

	local painMul = 	( bullet ~= nil and bullet.PainMultiplier ) or 
						( IsValid(inf) and inf.PainMultiplier ) or 1

	local rolePainMul = hg.GetSubRolePerk and hg.GetSubRolePerk(org.owner, "PainMul", 1) or 1
	local roleShockMul = hg.GetSubRolePerk and hg.GetSubRolePerk(org.owner, "ShockMul", 1) or 1
	painMul = painMul * rolePainMul
	shockMul = shockMul * roleShockMul

	local immobilizationMul = 	( bullet ~= nil and bullet.ImmobilizationMul) or 
								( IsValid(inf) and inf.ImmobilizationMul ) or 1

	local hurtMul = 	( bullet ~= nil and bullet.HurtMultiplier) or 
						( IsValid(inf) and inf.HurtMultiplier ) or 1

	if bullet and bullet.dmgtype then
		dmgInfo:SetDamageType( bullet.dmgtype )
	end

	if org.superfighter then
		dmgInfo:ScaleDamage(1)
	end

	if dmgInfo:IsDamageType(DMG_BURN) then
		painMul = 0.1
		shockMul = 0.1
	end

	if !dmgInfo:IsDamageType(DMG_BURN) then
		timer.Create("send_info_org"..org.owner:EntIndex(),0.01,1,function()
			if !IsValid(org.owner) then return end

			org.owner.fullsend = true
			hg.send_bareinfo(org)

			if IsValid(org.owner) and org.owner.Alive and org.owner:Alive() then
				hg.send_organism(org, org.owner)
			end
		end)
	end

	dir:Set(dmgInfo:GetDamageForce())
	dir:Normalize()
	dir:Mul(pen)
	--print(bullet.Penetration, pen, bullet ~= nil)
	--print(dmgInfo:GetDamageType() == DMG_BULLET)

	ent.armors = ent.armors or {}
	
	if dmgInfo:GetInflictor().poisoned2 and dmgInfo:IsDamageType(DMG_SLASH) then
		org.poison4 = CurTime()

		local attacker = dmgInfo:GetAttacker()
		if IsValid(attacker) and attacker:IsPlayer() then
			dmgInfo:GetInflictor().poisoned2 = nil
		end
	else
			dmgInfo:GetInflictor().poisoned2 = nil
	end

	
	local organs = hg.organism.GetHitBoxOrgans(ent:GetModel(), ent)
	local boxs, pos, sphere = hg.organism.ShootMatrix(ent, organs)
	local dmgPos = dmgInfo:GetDamagePosition()
	local tr = util.QuickTrace(dmgPos, dir:GetNormalized() * 100)
	if tr.Hit and tr.Entity == ent then
		dmgPos = tr.HitPos
	else
		tr = util.QuickTrace(dmgPos, -(dmgPos - (ent:GetPos() + ent:OBBCenter())))
		if tr.Hit and tr.Entity == ent then
			dir = tr.Normal * pen
			dmgPos = tr.HitPos
		end
	end
	local entryPhysicsBone = tr.Entity == ent and tr.PhysicsBone or nil
	if type(entryPhysicsBone) ~= "number" then
		local fallbackDir = -(dmgPos - (ent:GetPos() + ent:OBBCenter())):GetNormalized()
		local fallbackTrace = util.QuickTrace(dmgPos, fallbackDir * 100)
		if fallbackTrace.Entity == ent and type(fallbackTrace.PhysicsBone) == "number" then
			entryPhysicsBone = fallbackTrace.PhysicsBone
		end
	end
	local entryBone = type(entryPhysicsBone) == "number" and ent:TranslatePhysBoneToBone(entryPhysicsBone) or nil
	local entryBoneName = entryBone ~= nil and ent:GetBoneName(entryBone) or nil
	local entryHitgroup = entryBoneName and bonetohitgroup[entryBoneName] or 0

	attacker.harm = dmgInfo:GetDamage() / 100
	
	if ply or org.fakePlayer then
		hook_Run("PreHomigradDamage", org.fakePlayer and ent or ply, dmgInfo, entryHitgroup, ent, attacker.harm, hitBoxs, inputHole)
	end
	
	local dmg_before = dmgInfo:GetDamage()

	local lastPos, hitBoxs, inputHole, outputHole, outputDir, distance, tracePoses = nil,{},{},{},{},nil,nil
	org._bulletImpactBleedAdd = nil
	org._armorPainMul = nil
	org._directBrainDamageThisHit = nil
	org._bulletHitVitalThisHit = nil
	org._fistHeadTraceSkullIntact = isFistInflictor(dmgInfo) and (org.skull or 0) < 1 or nil
	-- Limb bone and artery damage must stay on the physics limb the bullet
	-- actually entered; a long penetration trace may still cross other limbs.
	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then
		org._bulletImpactHitgroup = entryHitgroup ~= 0 and entryHitgroup or nil
	end
	local selfInflictedBrainShot = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
		and attacker == org.owner
		and entryHitgroup == HITGROUP_HEAD
	if selfInflictedBrainShot then
		-- Only point-blank head shots bypass the normal organ trace.
		input_list.brain(org, 1, dmg / 25, dmgInfo)
		org._directBrainDamageThisHit = true
	elseif dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT+DMG_SLASH+DMG_CLUB+DMG_GENERIC) then
		lastPos, hitBoxs, inputHole, outputHole, outputDir, distance, tracePoses = hg.organism.Trace(dmgPos, dir, size, maxpen, boxs, pos, sphere, organs, dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT), Trace_Bullet, ent.organism, organs, dmg / 25, dmgInfo, dir)
	elseif dmgInfo:IsDamageType(DMG_BLAST) then
		local organs = hg.organism.GetHitBoxOrgans(ent:GetModel(), ent)
		local boxs, pos, sphere = hg.organism.ShootMatrix(ent, organs)
		
		hg.organism.BlastTrace(dmgInfo:GetDamagePosition(), (ent:GetPos() - dmgInfo:GetDamagePosition()):Length() / 200, dmg * 2, boxs, organs, Trace_Blast, ent.organism, organs, dmg / 300, dmgInfo)
		hg.organism.AddWoundManual(ent,dmg,vector_origin,angle_zero,math.random(0,ent:GetBoneCount()),CurTime())
	end
	local directBrainDamageThisHit = org._directBrainDamageThisHit == true
	local bulletHitVitalThisHit = org._bulletHitVitalThisHit == true
	-- `fatalBrainShotCandidate` used to be referenced below without ever being
	-- created.  As a result, even a traced, unarmored brain hit could not use
	-- the fatal-brain path.  Keep this deliberately limited to real head entry
	-- wounds so body shots that happen to reach an organ trace cannot trigger it.
	local fatalBrainShotCandidate = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
		and entryHitgroup == HITGROUP_HEAD
		and not (org.owner and org.owner.armors and org.owner.armors["head"] ~= nil)
	org._bulletImpactHitgroup = nil
	org._directBrainDamageThisHit = nil
	org._bulletHitVitalThisHit = nil
	org._fistHeadTraceSkullIntact = nil
	org._spineArteryTraceDmgInfo = nil

	if attacker:IsPlayer() then
		ent:SetPhysicsAttacker(attacker, 15)
	end

	--\\ rp dopolneniye
	if !inf.ShouldAttackOnce or !inf.attackedOnce then
		if dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT) then
			org.bulletwounds = org.bulletwounds + 1
		end

		if dmgInfo:IsDamageType(DMG_SLASH) then
			if dmgInfo:GetInflictor().slash then
				org.slashwounds = org.slashwounds + 1
			else
				org.stabwounds = org.stabwounds + 1
			end
		end

		if dmgInfo:IsDamageType(DMG_CLUB+DMG_GENERIC) then
			org.bruises = org.bruises + 1
			
			-- Blunt hits have a chance to open wounds based on damage
			local bluntDamage = dmgInfo:GetDamage()
			local woundChance = math.Clamp(bluntDamage / 100, 0, 0.5) -- 0-50% chance based on damage
			
			if math.random() < woundChance then
				local physBone = bone != -1 and bone or math.random(0, ent:GetPhysicsObjectCount() - 1)
				local boneIndex = ent:TranslatePhysBoneToBone(physBone)
				local boneName = ent:GetBoneName(boneIndex)
				local bonePos, boneAng = ent:GetBonePosition(boneIndex)
				
				if bonePos then
					local localPos, localAng = WorldToLocal(dmgPos, dmgInfo:GetDamageForce():GetNormalized():Angle(), bonePos, boneAng)
					local woundSeverity = math.Clamp(bluntDamage / 20, 1, 10) -- Wound size based on damage
					
					if #org.wounds < 30 then
						table.insert(org.wounds, {woundSeverity, localPos, localAng, boneName, CurTime()})
					else
						if org.wounds[1] then org.wounds[1][1] = org.wounds[1][1] + woundSeverity end
					end
					if hg.AddOrganismBloodDecal then hg.AddOrganismBloodDecal(org.owner) end
					
					table.sort(org.wounds, function(a, b) return a[1] > b[1] end)
					
					if #org.wounds <= 30 then
						timer.Create("WoundsSend"..ent:EntIndex(), 0.1, 1, function()
							hg.organism.SyncWounds(org)
						end)
					end
				end
			end
		end

		if dmgInfo:IsDamageType(DMG_BURN) then
			org.burns = org.burns + 1
			-- Severe burns cause immune suppression
			if dmgInfo:GetDamage() > 20 then
				org.immunesuppression = math.min((org.immunesuppression or 0) + dmgInfo:GetDamage() * 0.01, 1)
			end
		end

		if dmgInfo:IsDamageType(DMG_BLAST) then
			org.explosionwounds = org.explosionwounds + 1
		end
	end
	--//

	local att = dmgInfo:GetAttacker()
	if true and outputHole and #outputHole > 0 and dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT) then
		local bullet = inf.bullet
		org.blood = org.blood - 75
		
		timer.Simple(0, function()
			if !IsValid(ent) then return end

			if bullet and true then
				local mul = distance / pen
				bullet.Src = outputHole[#outputHole]
				bullet.Dir = dir:GetNormalized()//outputDir:GetNormalized()
				bullet.Force = bullet.Force * mul
				bullet.Damage = bullet.Damage * mul
				bullet.Num = 1
				bullet.Attacker = att
				bullet.Tracer = 0
				bullet.TracerName = "nil"
				bullet.IgnoreEntity = ent
				bullet.Filter = {ent, ply and ply:InVehicle() and ply:GetVehicle() or nil}
				bullet.penetrated = bullet.penetrated or 0
				bullet.limit_ricochet = bullet.limit_ricochet or 0
				bullet.penetrated = bullet.penetrated + 1
				bullet.limit_ricochet = bullet.limit_ricochet + 1
				bullet.Penetration = distance
				inf:FireLuaBullets(bullet, true)

				local tr = util.QuickTrace(outputHole[#outputHole], -outputDir:GetNormalized() * 10, ent)
				local effectdata1 = EffectData()
				effectdata1:SetOrigin(outputHole[#outputHole])
				effectdata1:SetStart(tr.HitPos)
				effectdata1:SetEntity(inf)
				effectdata1:SetMagnitude(2)
				util.Effect("eff_tracer", effectdata1)
			end

			--[[local ent = ents.Create("prop_physics")
			ent:SetModel("models/props_c17/lampShade001a.mdl")
			ent:SetPos(outputHole[#outputHole])
			ent:Spawn()
			ent:SetSolidFlags(FSOLID_NOT_SOLID)
			ent:GetPhysicsObject():EnableMotion(false)--]]
		end)

	end
	
	local bone = tr.Entity == ent and tr.PhysicsBone
	if not bone then
		local dir = -(dmgPos - (ent:GetPos() + ent:OBBCenter())):GetNormalized()
		local tr = util.QuickTrace(dmgPos, dir * 100)
		bone = tr.PhysicsBone
	end

	-- if tracePoses then
	-- 	local mat = ent:GetBoneMatrix(ent:TranslatePhysBoneToBone(bone))

	-- 	table.insert(tracePoses,1,dmgPos - dir * 100)
	-- 	table.insert(tracePoses,1,dmgPos - dir * 200)

	-- 	local rf = RecipientFilter()
	-- 	if org.owner:IsPlayer() then rf:AddPlayer(org.owner) end
	-- 	if dmgInfo:GetAttacker():IsPlayer() then rf:AddPlayer(dmgInfo:GetAttacker()) end
		
	-- 	local name = dmgInfo:GetAttacker():IsPlayer() and dmgInfo:GetAttacker():Name() or dmgInfo:GetAttacker():GetClass()
	-- 	net.Start("tracePosesSend")
	-- 	net.WriteTable(tracePoses)
	-- 	net.WriteEntity(ent)
	-- 	net.WriteTable(hitBoxs)
	-- 	net.WriteFloat(pen)
	-- 	net.WriteFloat(size)
	-- 	net.WriteInt(ent:TranslatePhysBoneToBone(bone) or 0,32)
	-- 	net.WriteVector(mat:GetTranslation())
	-- 	net.WriteAngle(mat:GetAngles())
	-- 	net.WriteString(ent:GetModel())
	-- 	net.WriteMatrix(ent:GetBoneMatrix(0))
	-- 	net.WriteString(tostring(inf.PrintName or "Unknown"))
	-- 	net.WriteString(tostring(name))
	-- 	net.Send(rf)
	-- end
	
	local dmgPos = dmgInfo:GetDamagePosition()
	local dirCool = dmgInfo:GetDamageForce():GetNormalized()
	local tr = util.QuickTrace(dmgPos, dirCool * 100)
	local len = math.abs(dmgInfo:GetDamageForce():Length())

	local hitgroup, bonename = getDamageHitgroup(ent, bone, dmgPos)
	if org.lastGibHitGroup and org.lastGibHitTime and org.lastGibHitTime + 0.1 > CurTime() then
		hitgroup = org.lastGibHitGroup
		bonename = hitgroup == HITGROUP_STOMACH and "ValveBiped.Bip01_Pelvis" or bonename
	end
	if hitgroup == HITGROUP_HEAD and IsValid(inf) and inf.ForceHeadKnockout then
		org.needotrub = true
		org.shock = math.max(org.shock or 0, 40)
		org.consciousness = 0
	end
	-- Remorseism's headshot burst is a hit confirmation, not only a skull-gib
	-- effect. Send it on a penetrating head hit and rate-limit shotgun pellets.
	if hitgroup == HITGROUP_HEAD and dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) and (org._headshotVisualNext or 0) <= CurTime() then
		org._headshotVisualNext = CurTime() + 0.08
		local visualAng = dirCool:LengthSqr() > 0 and dirCool:Angle() or angle_zero
		net.Start("hg_brainmist")
			net.WriteEntity(ent)
			net.WriteVector(dmgPos)
			net.WriteAngle(visualAng)
			net.WriteBool(true)
			net.WriteBool(false)
			net.WriteBool(false)
		net.Broadcast()
	end
	--print(dmg_before, 1)
	--if ent:IsRagdoll() then
		if RagdollForceBoneMul[hitgroup] then len = len * RagdollForceBoneMul[hitgroup] end
		if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) and RagdollDamageBoneMul[hitgroup] then
			dmgInfo:ScaleDamage(RagdollDamageBoneMul[hitgroup])
			dmg_before = dmg_before * RagdollDamageBoneMul[hitgroup]
			-- я даже не знаю, может это снова убрать? ^
			-- у нас это так давно было неправильно, что, наверное,
			-- все уже привыкли
		end
	--end

	if inputHole and #inputHole > 0 and dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT) then
		queueBulletBloodImpact(ent, "entry", inputHole[1], dir / 2, dmg, severeBulletImpact)
	end

	if outputHole and #outputHole > 0 and dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT) then
		-- An exit hole carries the projectile's remaining energy out of the body.
		-- Give its spray enough velocity to reach surrounding geometry, unlike the
		-- more contained entry impact.
		queueBulletBloodImpact(ent, "exit", outputHole[#outputHole], -outputDir * 1.8, dmg, severeBulletImpact)
	end

	--print(dmg_before, 2)
	local armorPainMul = org._armorPainMul or 1
	org._armorPainMul = nil
	local dmgBlood, dmgHurt, instaPain, immobilization = hg.organism.DamageTypeAffliction(dmg_before * armorPainMul / 12, dmgInfo, ent, org)
	
	local hitbody = #inputHole > 0 or not dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT)
	
	--if hitbody then
	if not org.superfighter then
		dmgBlood = dmgBlood * 1.5
		local bleed_add = dmgBlood * bleedMul// / (RagdollDamageBoneMul[hitgroup] or 1)
		--org.bleed = org.bleed + bleed_add
		attacker.harm = (attacker.harm or 0) + bleed_add / 50
		local hurt_add = dmgHurt * 0.5 * hurtMul
		org.hurtadd = org.hurtadd + hurt_add
		local painadd = dmgHurt * painMul * 0.75 * (org.painresist or 1)
		local instantPainMul = 0.2
		local instant_pain = (instantPainMul or 0) * painadd
		local slow_pain = (1 - (instantPainMul or 0)) * painadd
		
		local instant_pain = instantPainMul * painadd
		local slow_pain = (1 - instantPainMul) * painadd
		org.painadd = org.painadd + slow_pain
		//org.avgpain = org.avgpain + instant_pain
		org.shock = math.min(org.shock + instaPain * shockMul * 4.5 * instant_pain_shock_scale * math.Clamp(pen / 5,1,2), 70)
		org.immobilization = math.min(org.immobilization + immobilization * immobilizationMul, 30)
		org.lasthit = CurTime()
		
		local adrenalineMul = math.min(math.max(1 + org.adrenaline, 1), 1.2)
		local adrenaline = org.adrenaline
		local analgesiaMul = ((org.analgesia + org.painkiller * 0.3) * 4 + 1)
		local painkillerMul = 1
		local inflictor = dmgInfo:GetInflictor()
		local inflictorClass = IsValid(inflictor) and inflictor:GetClass() or ""
		local inflictorBase = IsValid(inflictor) and inflictor.Base or ""
		local meleeHit = dmgInfo:IsDamageType(DMG_CLUB + DMG_SLASH) or inflictorBase == "weapon_melee" or inflictorClass == "weapon_melee"
	
		org.shock_turn = 10 * (!org.otrub and 1 or 0.1)
	
		

		if org.shock > collapseThreshold then
			timer.Simple(0, function() hg.Fake(org.owner) end)
		end

		if bullet and hg.ammotypeshuy[bullet.AmmoType] and hg.ammotypeshuy[bullet.AmmoType].BulletSettings.tranquilizer then
			org.tranquilizer = org.tranquilizer + dmgInfo:GetDamage()
		end

		if dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT+DMG_SLASH+DMG_BURN) then
			org.fearadd = org.fearadd + 0.3
			if IsValid(att) and att ~= org.owner and att:IsPlayer() and att.organism then
				local attackerOrg = att.organism
				local now = CurTime()

				if now >= (attackerOrg._attackAdrenalineCooldownUntil or 0) then
					attackerOrg._attackAdrenalineGainUntil = now + attacker_adrenaline_gain_window
					attackerOrg._attackAdrenalineCooldownUntil = attackerOrg._attackAdrenalineGainUntil + attacker_adrenaline_cooldown
				end

				if now <= (attackerOrg._attackAdrenalineGainUntil or 0) then
					if (attackerOrg.adrenaline or 0) < attacker_adrenaline_cap then
						att:AddNaturalAdrenaline(0.15)
						attackerOrg.adrenaline = math.min(attackerOrg.adrenaline or 0, attacker_adrenaline_cap)
					end
				end
			end
		end

		org.fearadd = org.fearadd + hurt_add * 0.5

		if dmgInfo:IsDamageType(DMG_BURN) then
			local bigRand = math.Rand(0.0005,0.0008)
			local smallRand = math.Rand(0.0001,0.0002)
			//org.lungsL[2] = math.min(org.lungsL[2] + bigRand,1)
			//org.lungsR[2] = math.min(org.lungsR[2] + bigRand,1)
			org.lungsL[1] = math.min(org.lungsL[1] + bigRand, 1)
			org.lungsR[1] = math.min(org.lungsR[1] + bigRand, 1)
			hg.organism.input_list.liver(org, nil, smallRand, dmgInfo)
			hg.organism.input_list.stomach(org, nil,smallRand, dmgInfo)
			hg.organism.input_list.intestines(org, nil, smallRand, dmgInfo)
			hg.AddHarmToAttacker(dmgInfo, bigRand, "Burns harm")
			--org.liver = math.min(org.liver + math.Rand(0.0005,0.0008),1) 
			--org.stomach = math.min(org.stomach + math.Rand(0.0005,0.0008),1) 
			//org.trachea = math.min(org.trachea + smallRand, 1)
		end
	else
		local sfd = org.fakePlayer and ent or ply
		if not IsValid(sfd) then return true end
		if sfd:Health() < 0 then
			sfd:Kill() 
			return true -- кодинг это просто :fumo_bounce:
		else
			sfd:SetHealth(sfd:Health()-dmg_before * .15)
		end
	end
	--end
	
	if not org.otrub and org.adrenalineAdd >= 0 then// and dmgInfo:IsDamageType(DMG_BULLET + DMG_BLAST + DMG_BUCKSHOT + DMG_SLASH + DMG_CLUB + DMG_BURN) then
		local reserveK = math.Clamp((org.adrenalineStorage or 0) / 5, 0, 1)
		org.adrenalineAdd = math.max(org.adrenalineAdd or 0, math.min(instaPain * 0.25, 1.5) * (0.35 + reserveK * 0.65))
		org.owner:AddNaturalAdrenaline(instaPain * 1.15 * (dmgInfo:IsDamageType(DMG_BLAST) and 4 or 1) * (dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT) and 4 or 1))

		-- Keep a clear floor for severe trauma even when its calculated pain is
		-- reduced by armour or damage-type scaling. Fractures keep their own boost.
		if dmgInfo:GetDamage() >= severe_damage_adrenaline_threshold and (org._severeDamageAdrenalineNext or 0) <= CurTime() then
			org._severeDamageAdrenalineNext = CurTime() + severe_damage_adrenaline_delay
			org.owner:AddNaturalAdrenaline(0.65)
		end
	end
	
	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST + DMG_SLASH) or (dmgInfo:IsDamageType(DMG_GENERIC + DMG_VEHICLE + DMG_FALL + DMG_CLUB)) then
		local hook_info = {
			bleed = dmgBlood + (org._bulletImpactBleedAdd or 0),
			input_hole = inputHole,
			output_hole = outputHole,
			bone = bone,
			restricted = false,
		}
		
		hook_Run("PreHomigradDamageBulletBleedAdd", org.fakePlayer and ent or ply, org, dmgInfo, hitgroup, attacker.harm, hitBoxs, inputHole, hook_info)
		
		if(!hook_info.restricted)then
			hg.organism.AddWound(ent, tr, bone, dmgInfo, dmgPos, hook_info.bleed, inputHole, outputHole)
		end
	end
	
	if ply or org.fakePlayer then
		hook_Run("HomigradDamage", org.fakePlayer and ent or ply, dmgInfo, bonetohitgroup[bonename], ent, attacker.harm, hitBoxs, inputHole)
	end
	
	attacker.harm = 0

	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST + DMG_SLASH + DMG_CLUB + DMG_GENERIC) then
		local force = dirCool * len
		--print("HIT")
		if ply then
			--if ply.lastFake then ply.lastFake = ply.lastFake - len end
			ply.HitBones = ply.HitBones or {}

			if hitgrouptobone[hitgroup] then
				for i,bon in ipairs(hitgrouptobone[hitgroup]) do
					if hitgroup == HITGROUP_STOMACH or hitgroup == HITGROUP_CHEST then dmg = dmg / 2 end
					ply.HitBones[bon] = CurTime() + dmg
				end
			end
			
			hg.AddForceRag(ply, bone, force * 0.5, 0.5)

			local ragForce = ply.AddForceRag and ply.AddForceRag[bone] and ply.AddForceRag[bone][2]
			if isvector(ragForce) and ragForce:Length() > 4500 then //по-моему какие-то большие значения, не?
				if ragForce:Length() > 7000 then
					hg.StunPlayer(ply, 0.5)
					hg.LightStunPlayer(ply, 2)
				else
					hg.LightStunPlayer(ply, 2)
				end
			end
		end
		
		if ent:IsRagdoll() then
			ent:GetPhysicsObjectNum(getGibbedHeadForcePhys(ent, bone) or 0):ApplyForceCenter(force * 1)
		end
	end

	if dmgInfo:IsDamageType(DMG_BLAST) then
		hitgroup = table.Random({
			HITGROUP_LEFTARM,
			HITGROUP_RIGHTARM,
			HITGROUP_RIGHTLEG,
			HITGROUP_LEFTLEG,
			HITGROUP_HEAD,
			HITGROUP_STOMACH
		})
	end

	local lend = math.max(0.1, (ent:GetPos() - dmgInfo:GetDamagePosition()):Length())
	local damageStack = dmg_before / (dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) and RagdollDamageBoneMul[hitgroup] or 1)
	if dmgInfo:IsDamageType(DMG_SLASH + DMG_CLUB + DMG_GENERIC) then damageStack = damageStack * melee_gib_damage_mul end
	if hitgroup == HITGROUP_HEAD and dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then
		-- The hitgroup damage is intentionally reduced for normal ragdoll physics,
		-- then restored above for the gib calculation.  Give only high-energy
		-- rounds an additional cranial destruction bonus; a Beowulf-class round
		-- remains a severe survivable head injury unless it actually reaches brain.
		local highCaliberImpact = math.Clamp((dmg_before - 75) / 75, 0, 1)
		damageStack = damageStack * Lerp(highCaliberImpact, 1, 1.75)
	end
	if hitgroup == HITGROUP_HEAD and IsValid(inf) and inf.HeadGibDamageMul then damageStack = damageStack * inf.HeadGibDamageMul end
	if hitgroup == HITGROUP_HEAD and dmgInfo:IsDamageType(DMG_SLASH) then damageStack = damageStack * 25 end
	local inflictorClass = IsValid(dmgInfo:GetInflictor()) and dmgInfo:GetInflictor():GetClass() or ""
	local grenadeBlastMul = string.find(inflictorClass, "ent_hg_grenade") and 1.8 or 1
	--print(damageStack, 3)
	damageStack = damageStack * (dmgInfo:IsDamageType(DMG_BLAST) and blast_gib_damage_mul / lend * grenadeBlastMul or 1) * (!dmgInfo:IsDamageType(DMG_CLUB+DMG_SLASH+DMG_BULLET+DMG_BUCKSHOT+DMG_BLAST+DMG_SNIPER) and 0 or 1) * (ent:IsNPC() and 3 or 1)
	if impact.armorStopped then damageStack = 0 end
	--damageStack = damageStack * (bullet and bullet.AmmoType and hg.ammotypeshuy[bullet.AmmoType] and hg.ammotypeshuy[bullet.AmmoType].BulletSettings and hg.ammotypeshuy[bullet.AmmoType].BulletSettings.Mass or 1) / 8
	if hg.FullBodyExplode and !org.fullbodyexploded and dmgInfo:IsDamageType(DMG_BLAST) and hg.CanFullBodyGib and hg.CanFullBodyGib(ent, org, ply) and (damageStack >= full_body_blast_gib_threshold or dmg_before >= full_body_blast_damage_threshold) then
		return hg.FullBodyExplode(ent, dirCool * len, dmgInfo) or true
	end
	
	org.dmgstack = org.dmgstack or {}
	org.dmgstack[hitgroup] = org.dmgstack[hitgroup] or {}
	local bodyPartMaxHealth = body_part_health[hitgroup]
	if bodyPartMaxHealth and hitgrouptolimb[hitgroup] and not org.isPly then bodyPartMaxHealth = 100 end
	if bodyPartMaxHealth and hitgroup == HITGROUP_HEAD and not org.isPly then bodyPartMaxHealth = 100 end
	local gibStack
	local headGoreStack
	if bodyPartMaxHealth then
		gibStack = DamageBodyPart(org, hitgroup, damageStack, bodyPartMaxHealth)
		if hitgroup == HITGROUP_HEAD then headGoreStack = AddGibDamageStack(org, hitgroup, damageStack) end
	else
		local mul = (org.dmgstack[hitgroup][3] or 0) + 1
		org.dmgstack[hitgroup][1] = ((org.dmgstack[hitgroup][2] and (ent.organism.dmgstack[hitgroup][2] + 0.05 * mul) > CurTime()) and ent.organism.dmgstack[hitgroup][1] * ((ent.organism.dmgstack[hitgroup][2] + 0.05 * mul) - CurTime()) / (0.05 * mul) or 0) + damageStack * mul
		org.dmgstack[hitgroup][2] = CurTime()
		org.dmgstack[hitgroup][3] = (org.dmgstack[hitgroup][3] or 0) + damageStack / 500
		gibStack = hitgroup == HITGROUP_HEAD and AddGibDamageStack(org, hitgroup, damageStack) or org.dmgstack[hitgroup][1]
	end
	org.dmgstack[hitgroup][1] = headGoreStack or gibStack
	if hitgroup == HITGROUP_HEAD and ent.headexploded and Gib_UpdateHeadGoreStage then
		Gib_UpdateHeadGoreStage(ent, headGoreStack or gibStack)
	end
	if hitgroup == HITGROUP_STOMACH and not org.stomachgibbed and hg.AttachStomachGore and gibStack >= player_stomach_gib_threshold then
		hg.AttachStomachGore(ent, dirCool * len)
	end

	local mat = ent:GetBoneMatrix(ent:TranslatePhysBoneToBone(bone))
	local hitgroup_max = 100
	if org.isPly then
		hitgroup_max = hitgroup == HITGROUP_HEAD and player_head_gib_threshold or hitgrouptolimb[hitgroup] and player_limb_gib_threshold or hitgroup_max
	end
	-- Once the skull is open there is no intact cranial shell left to absorb a
	-- follow-up impact.  Keep this scoped to the head so open-skull victims are
	-- visibly more prone to decapitation without changing ordinary gib balance.
	if hitgroup == HITGROUP_HEAD and (org.skull or 0) >= 1 then
		hitgroup_max = hitgroup_max * 0.55
	end
	if dmgInfo:IsDamageType(DMG_BLAST) and hitgrouptolimb[hitgroup] then hitgroup_max = player_blast_limb_gib_threshold end
	local instant = bodyPartMaxHealth and gibStack >= hitgroup_max or gibStack > hitgroup_max
	--print(damageStack, org.dmgstack[hitgroup][1], org.dmgstack[hitgroup][3])
	local blast = dmgInfo:IsDamageType(DMG_BLAST)
	local slash = dmgInfo:IsDamageType(DMG_SLASH)
	if instant and blast and hitgroup == HITGROUP_HEAD and !ent.headexploded then
		hg.ExplodeHead(ent, org.dmgstack[hitgroup][1], false, dirCool * len)
	end
	if instant and !blast and hitgroup == HITGROUP_HEAD and !ent.headexploded then
		hg.ExplodeHead(ent, org.dmgstack[hitgroup][1], slash, force)
	end

	if instant and hitgrouptolimb[hitgroup] then
		local damagedLimb = hitgrouptolimb[hitgroup]
		if blast then
			for i, limb in ipairs({"lleg", "rleg", "larm", "rarm"}) do
				if !org[limb.."amputated"] and math.random(5) < math.Clamp(500 / lend, 1.2, 4.5) then
					hg.organism.AmputateLimb(org, limb)
				end
			end
		elseif !org[damagedLimb.."amputated"] then
			hg.organism.AmputateLimb(org, damagedLimb)
		end
	end
	
	if not bodyPartMaxHealth then
		timer.Create("dmgstack"..org.entindex, !instant and 1 or 0, 1, function()
		--if !IsValid(ply) then return end
		
		local rag = IsValid(ply) and (IsValid(ply:GetNWEntity("RagdollDeath", ply.FakeRagdoll)) and ply:GetNWEntity("RagdollDeath", ply.FakeRagdoll)) or ent:IsRagdoll() and ent or ent:IsNPC() and ent
		local org = rag and rag.organism or ent.organism

		timer.Simple(0.01, function()
			if !org then return end
			if !org.dmgstack then return end
			if !org.dmgstack[hitgroup] then return end
			if !org.dmgstack[hitgroup][1] then return end
			local stack = org.dmgstack[hitgroup][1]
			local should = stack > hitgroup_max

			if !IsValid(rag) then
				org.dmgstack[hitgroup][1] = nil
				org.dmgstack[hitgroup][2] = nil

				return
			end

			-- Allow decapitation on living players
			if IsValid(ply) and ply:Alive() and hitgroup ~= HITGROUP_HEAD then
				org.dmgstack[hitgroup][1] = nil
				org.dmgstack[hitgroup][2] = nil

				return
			end

			should = org.dmgstack[hitgroup] and org.dmgstack[hitgroup][1] > hitgroup_max
			--print(rag, should, hitgroup == HITGROUP_HEAD, bonename, hitgroup, HITGROUP_HEAD)
			if should and hitgroup == HITGROUP_HEAD then
				hg.ExplodeHead(ent, org.dmgstack[hitgroup][1], slash, force)

				if org.dmgstack[hitgroup] then
					org.dmgstack[hitgroup][1] = nil
					org.dmgstack[hitgroup][2] = nil
				end
			end
			
			if IsValid(rag) then
				if !rag.bloodsquirted and !rag.headexploded and (hitgroup == HITGROUP_HEAD) and (bit.band(dmgtype, DMG_BULLET + DMG_BUCKSHOT) > 0) and org.brain >= 1.0 then
					rag.bloodsquirted = true

					net.Start("bloodsquirt")
					net.WriteEntity(rag)
					net.WriteString(bonename)
					net.WriteMatrix(mat)
					net.WriteVector(dmgPos + dirCool * 2)
					net.WriteVector(-dirCool * 2)
					net.Broadcast()

					if outputHole and #outputHole > 0 then
						net.Start("bloodsquirt")
						net.WriteEntity(rag)
						net.WriteString(bonename)
						net.WriteMatrix(mat)
						net.WriteVector(outputHole[1] - dirCool * 2)
						net.WriteVector(dirCool * 2)
						net.Broadcast()
					end
				end
			end

			if org.dmgstack[hitgroup] then
				org.dmgstack[hitgroup][1] = nil
				org.dmgstack[hitgroup][2] = nil
			end

			org.owner.fullsend = true
			hg.send_bareinfo(org)
		end)
		end)
	end

	--[[if !org.llegamputated and dmgInfo:IsDamageType(DMG_BLAST) then
		hg.organism.AmputateLimb(org, "lleg")
	end

	if !org.rlegamputated and dmgInfo:IsDamageType(DMG_BLAST) then
		hg.organism.AmputateLimb(org, "rleg")
	end

	if !org.larmamputated and dmgInfo:IsDamageType(DMG_BLAST) then
		hg.organism.AmputateLimb(org, "larm")
	end

	if !org.rarmamputated and dmgInfo:IsDamageType(DMG_BLAST) then
		hg.organism.AmputateLimb(org, "rarm")
	end--]]

	-- A bullet to the face can dislodge an attached headcrab. Gun suicides get
	-- a higher chance because the muzzle is deliberately pressed to the head.
	-- This must happen before fatal brain-shot handling creates the death ragdoll,
	-- otherwise the attached model has already been transferred to it.
	local isGunshot = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
	local isGunSuicide = isGunshot and ply and dmgInfo:GetAttacker() == ply
		and ply.suiciding and IsValid(inf) and inf.ishgweapon
	local hitsFace = isGunshot and hitgroup == HITGROUP_HEAD
	if ply and ply:GetNetVar("headcrab") and (hitsFace or isGunSuicide) then
		local dislodgeChance = isGunSuicide and 0.6 or 0.3
		if math.Rand(0, 1) <= dislodgeChance then
			ply:RemoveHeadcrabFromTrauma()
		end
	end

	dmgInfo:ScaleDamage(dmgInfo:IsDamageType(DMG_BURN) and 0.015 or (dmgInfo:IsDamageType(DMG_CLUB) and 0.25 or 0.15))
	
	takeRagdollDamage(ent, dmgInfo)

	-- A bullet which actually intersects unarmored brain tissue can either leave
	-- regional damage or catastrophically destroy the brain. Higher-energy shots
	-- are more likely to be immediately fatal, while a failed roll preserves the
	-- lobe damage produced by the organ trace (commonly about 0.15-0.3 overall).
	if fatalBrainShotCandidate and directBrainDamageThisHit and (org.brain or 0) < 0.7 then
		local shotDamage = math.max(dmg, 0)
		local damageFraction = math.Clamp(shotDamage / catastrophic_brain_shot_damage_max, 0, 1)
		local catastrophicChance = Lerp(damageFraction, catastrophic_brain_shot_chance_min, catastrophic_brain_shot_chance_max)
		if math.Rand(0, 1) <= catastrophicChance then
			org.brain = 1
		end
	end

	-- Direct central-brain destruction remains certainly fatal; regional wounds
	-- only become fatal here when the catastrophic roll succeeds.
	if fatalBrainShotCandidate and directBrainDamageThisHit and (org.brain or 0) >= 0.7 and hg.organism.KillFatalBrainDamage then
		hg.organism.KillFatalBrainDamage(org)
	end

	if org.isPly then
		hook.Run("Org Think Call", ply, org)
		
		if (not ply:Alive() or not org.alive) and (math.Round(ply:GetInfoNum("hg_deathfadeout", 1)) == 1) then// or org.otrub or hg.organism.paincheck(org) or (ply:Health() <= 0) then
			QueueHeadDisfigurement(ply, org, ent)
			
			ply:ScreenFade(0, color_black, 1, 1)
			ply:ConCommand("soundfade 100 99999")
		end
	end

	local brokenSkullHeadImpact = hitgroup == HITGROUP_HEAD and org.skull == 1
	if brokenSkullHeadImpact or (dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) and dmgBlood > 1 and #inputHole > 0) then
		net.Start("hg_bloodimpact")
		net.WriteVector(dmgPos)
		net.WriteVector(dirCool / 15)
		net.WriteFloat(brokenSkullHeadImpact and math.max(dmg / 8, 1) or dmg / 10)
		net.WriteInt(1, 8)
		net.WriteBool(brokenSkullHeadImpact or severeBulletImpact)
		net.WriteBool(false)
		net.Broadcast()
	end

	if ply and !ply:GetNetVar("headcrab") and (ply.PlayerClassName != "Gordon" or ply.armors.head != "gordon_helmet") and ply.PlayerClassName ~= "headcrabzombie" then
		local class = dmgInfo:GetAttacker():GetClass()

		if dmgInfo:GetAttacker():IsNPC() and headcrabs[class] then
			local armors = ply:GetNetVar("Armor",{})
			local isHelm = armors["head"] and !hg.armor["head"][armors["head"]].nodrop
			local isMask = armors["face"] and !hg.armor["face"][armors["face"]].nodrop

			if isHelm or isMask then
				hg.DropArmorForce(ply, isHelm and armors["head"] or armors["face"])
				ply.ArmorCD = CurTime() + 5

				return
			end

			ply.PreZombClass = ply.PlayerClassName

			ply:AddHeadcrab(headcrabsmodels[class])
			
			dmgInfo:GetAttacker():Remove()
		end
	end

	return !ent:IsNPC()
end)

hook.Add("CanEquipArmor", "HeadcrabArmorCD", function(ply, armor_name)
	if IsValid(ply) and ((ply.ArmorCD or 0) > CurTime() or ply:GetNetVar("headcrab")) then
		return false
	end
end)

local paintable = {
	[HITGROUP_STOMACH] = function(ply,ent)
		local snd = (ply.painCD and CurTime() < ply.painCD + 10 ) and "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".ogg" or "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/mygut02.ogg"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
	[HITGROUP_CHEST] = function(ply,ent)
		local snd = "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".ogg"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
	[HITGROUP_LEFTARM] = function(ply,ent)
		local snd = (ply.painCD and CurTime() < ply.painCD + 10 ) and "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".ogg" or "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/myarm0"..math.random(1,2)..".ogg"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
	[HITGROUP_RIGHTARM] = function(ply,ent)
		local snd = (ply.painCD and CurTime() < ply.painCD + 10 ) and "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".ogg" or "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/myarm0"..math.random(1,2)..".ogg"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
	[HITGROUP_RIGHTLEG] = function(ply,ent)
		local snd = (ply.painCD and CurTime() < ply.painCD + 10 ) and "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".ogg" or "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/myleg0"..math.random(1,2)..".ogg"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
	[HITGROUP_LEFTLEG] = function(ply,ent)
		local snd = (ply.painCD and CurTime() < ply.painCD + 10 ) and "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".ogg" or "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/myleg0"..math.random(1,2)..".ogg"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
}

--[[hook.Add("HomigradDamage", "painsounds",function(ply, dmgInfo, hitgroup, ent) -- Пример использования HomigradDamage
	--ply.painCD = ply.painCD or 0
	--if paintable[hitgroup] and ply.painCD and ply.painCD < CurTime() and ply.organism and !ply.organism.otrub and ply:Alive() and !ply.organism.holdingbreath then 
	--	paintable[hitgroup](ply,ent)
	--end
end)--	]]

function hg.organism.DamageTypeAffliction(dmg, dmgInfo, ply, org)
	local dmgBlood, dmgHurt, instaPain, immobilization = dmg, dmg, dmg, 0
	
	if dmgInfo:IsDamageType(DMG_VEHICLE + DMG_SHOCK) then
		dmgBlood = (math.random(15) == 1) and dmg / 4 or 0
		dmgHurt = dmg * 1
		instaPain = dmg * 1
	end

	if dmgInfo:IsDamageType(DMG_CRUSH + DMG_FALL) then
		dmgBlood = 0
		dmgHurt = 0
		instaPain = 0
	end

	if dmgInfo:IsDamageType(DMG_GENERIC+DMG_SHOCK+DMG_CRUSH) then
		if dmgInfo:GetInflictor():GetClass() == "trigger_hurt" then
			hg.organism.input_list.brain(org, 1, dmg / 50, dmgInfo)
		end
	end

	if dmgInfo:IsDamageType(DMG_GENERIC+DMG_CLUB) then
		dmgBlood = (math.random(4) == 1) and dmg * 0.65 or dmg * 0.08
		dmgHurt = dmg * 10
		instaPain = dmg * 6
		immobilization = dmg * 5
	end
	
	if dmgInfo:IsDamageType(DMG_BURN) then
		dmgBlood = 0
		dmgHurt = dmg * 3
		instaPain = dmg * 3
	end

	if dmgInfo:IsDamageType(DMG_BULLET) then
		dmgBlood = dmg * 4.5
		dmgHurt = dmg * 5
		instaPain = dmg * 5
		immobilization = dmg * 5
	end
	
	if dmgInfo:IsDamageType(DMG_SLASH) then
		dmgBlood = dmg * 12
		dmgHurt = dmg * 8
		instaPain = dmg * 9
		immobilization = dmg * 6
	end
	
	if dmgInfo:IsDamageType(DMG_BUCKSHOT) then
		dmgBlood = dmg * 4.5
		dmgHurt = dmg * 5
		instaPain = dmg * 3
		immobilization = dmg * 5
	end

	if dmgInfo:IsDamageType(DMG_BLAST) then
		dmgBlood = dmg * 5
		dmgHurt = dmg * 4
		instaPain = dmg * 3
	end
	
	if dmgInfo:IsDamageType(DMG_NERVEGAS) then
		if ply.armors.face == "mask2" or ply.PlayerClassName == "Combine" then
			dmgInfo:ScaleDamage(0)
			dmgBlood = 0
			dmgHurt = 0
			instaPain = 0
		else
			hg.organism.GasDamage(org, dmg, dmgInfo)
			dmgBlood = 0
			dmgHurt = dmg * 5
			instaPain = 0
		end
	end

	if dmgInfo:IsDamageType(DMG_ACID + DMG_POISON) then
		if not (ply.armors.face == "mask2" or ply.PlayerClassName == "Combine") then
			hg.organism.GasDamage(org, dmg, dmgInfo)
		end
		dmgBlood = dmg * 2
		dmgHurt = dmg * 5
		instaPain = dmg * 5
		immobilization = dmg * 5
	end

	if dmgInfo:IsDamageType(DMG_RADIATION) then
		dmg = dmg * 2
		hg.organism.RadDamage(org, dmg, dmgInfo)
	end

	return dmgBlood * 2, dmgHurt, instaPain / 20, immobilization
end

local util_TraceLine = util.TraceLine
local endpos = Vector(0, 0, 0)
local dir, start
local filterEnt
local tr = {
	ignoreworld = true,
	mins = Vector(-3,-3,-3),
	maxs = Vector(3,3,3),
}
local util_TraceHull = util.TraceHull

local function GetTraceDamage(ent, start, dir)
	dir = -(-dir)
	dir:Normalize()
	dir:Mul(512)
	start = -(-start)
	tr.start = start
	endpos:Set(start)
	endpos:Add(dir) --вероятнее всего х3
	tr.endpos = endpos
	--tr.filter = ent --gunius
	local traceResult = util_TraceLine(tr)
	if not traceResult.Hit then
		endpos:Set(start)
		endpos:Sub(dir)
		traceResult = util_TraceHull(tr)
	end
	return traceResult
end

hg.GetTraceDamage = GetTraceDamage
util.AddNetworkString("headtrauma_flash")
--local Organism = hg.organism
local abs = math.abs
takeRagdollDamage = function(ent, dmgInfo)
	if not ent:IsRagdoll() then return end
	local ply = hg.RagdollOwner(ent)
	if not IsValid(ply) then return end
	if ply.organism and ply.organism.godmode then return end
	local traceResult = GetTraceDamage(ent, dmgInfo:GetDamagePosition(), dmgInfo:GetDamageForce())
	--я не ебу как

	if not IsValid(ply) or not ply:Alive() then return end

	if traceResult.Hit then
		local bone = traceResult.PhysicsBone
		local hitgroup
		local bonename = ent:GetBoneName(ent:TranslatePhysBoneToBone(bone))
		if bonetohitgroup[bonename] ~= nil then hitgroup = bonetohitgroup[bonename] end
		--if RagdollDamageBoneMul[hitgroup] then dmgInfo:ScaleDamage(RagdollDamageBoneMul[hitgroup]) end
		if RagdollForceBoneMul[hitgroup] then dmgInfo:SetDamageForce(dmgInfo:GetDamageForce() * RagdollForceBoneMul[hitgroup]) end
		
		local org = ply.organism
		if dmgInfo:GetInflictor():IsWeapon() and not dmgInfo:IsDamageType(DMG_CRUSH) then
			if hitgroup == HITGROUP_LEFTARM then
				if IsValid(ent.ConsLH) then
					ent.ConsLH:Remove()
					ent.ConsLH = nil
				end
			end

			if hitgroup == HITGROUP_RIGHTARM then
				if IsValid(ent.ConsRH) then
					ent.ConsRH:Remove()
					ent.ConsRH = nil
				end
			end
		end
	end
	
	//if not dmgInfo:IsDamageType(DMG_CRUSH) then
	//	ply:SetHealth(ply:Health() - dmgInfo:GetDamage())
	//	if ply:Health() <= 0 and ply:Alive() then timer.Simple(0,function() if ply:Alive() then ply:Kill() end end) end
	//end
end

hg.takeRagdollDamage = takeRagdollDamage

local bleedSurfaces = { -- https://developer.valvesoftware.com/wiki/Material_surface_properties
	["boulder"] = true,
	["gravel"] = true,
	["rock"] = true,
	["concrete"] = true,
	["chain"] = true,
	["chainlink"] = true,
	["metalgrate"] = true,
	["glass"] = true,
	["glassbottle"] = true,
	["pottery"] = true,
	["combine_Metal"] = true,
	["cavern_rock"] = true,
	["glassfloor"] = true,
	["asphalt"] = true,
	["clay"] = true,
	["brokenglass"] = true,
	["boncretegrit"] = true,
	["glass_breakable"] = true
}

local hg_safe_landing_legmul = 0.6
local hg_safe_landing_painmul = 0.7
local hg_safe_landing_minspeed = 350
local hg_safe_landing_maxspeed = 900

local function velocityDamage(ent, data)
	local speed = (data.OurOldVelocity - data.TheirOldVelocity):Length()
	if speed < 250 then return end
	if data.HitEntity.Throwable then return end
	
	if !data.HitEntity:IsWorld() and data.HitEntity.lasttouched and data.HitEntity.lasttouched[ent] then
		if data.HitEntity.lasttouched[ent] + 0.5 > CurTime() then
			return
		end
	end

	data.HitEntity.lasttouched = data.HitEntity.lasttouched or {}
	data.HitEntity.lasttouched[ent] = CurTime()

	--print(data.HitObject:GetEntity():IsWorld())
	local dmg = speed / 4300 * data.DeltaTime * ((IsValid(data.HitObject) && !data.HitObject:GetEntity():IsWorld()) && math.min(data.HitObject:GetMass() / 20, 1) || 1)
	dmg = dmg * math.abs(data.OurOldVelocity:GetNormalized():Dot(data.HitNormal))
	if !data.HitObject:GetEntity():IsWorld() && !data.HitObject:GetEntity():IsRagdoll() then
		//dmg = dmg * math.max(data.HitObject:GetMass()*(speed/50000),5)
	end
	
	if !ent.organism then return end
	if dmg * 20 < 0.1 then return end
	dmg = dmg * 1.5
	local rawPhysicsDamage = dmg * 20

	dmg = math.min(dmg, 7)

	local bone
	for i = 0, ent:GetPhysicsObjectCount() do
		local phys = ent:GetPhysicsObjectNum(i)
		if phys == data.PhysObject then
			bone = i
		end
	end

	local dmgInfo = DamageInfo()
	dmgInfo:SetDamage(dmg * 20)
	dmgInfo:SetDamagePosition(data.HitPos or ent:GetPos())
	dmgInfo:SetDamageForce(data.OurOldVelocity - data.TheirOldVelocity)
	local surfaceType = util.GetSurfacePropName(data["TheirSurfaceProps"])
	--[[if surfaceType and surfaceType ~= nil and bleedSurfaces[surfaceType] then
		--print(surfaceType)
		--print(bleedSurfaces[surfaceType])
		dmgInfo:SetDamageType(DMG_SLASH)
	else]]
		dmgInfo:SetDamageType(DMG_CRUSH + DMG_FALL)
	--end
	local att = data.HitObject:GetEntity():GetPhysicsAttacker(15)
	att = IsValid(att) and att or ent:GetPhysicsAttacker(15)
	dmgInfo:SetAttacker(IsValid(att) and att or IsValid(dmgInfo:GetAttacker()) and dmgInfo:GetAttacker() or game.GetWorld())

	-- Slam bonus: if a player launched this ragdoll and it hit the world (wall/curb/floor), deal extra damage
	if data.HitObject:GetEntity():IsWorld() and IsValid(att) and att:IsPlayer() then
		local slamMul = math.Clamp(speed / 500, 1.5, 4.0)
		dmgInfo:ScaleDamage(slamMul)
	end

	att.harm = dmgInfo:GetDamage() / 15
	-- 100 is kil
	
	local ply = hg.RagdollOwner(ent)
        if IsValid(ply) and ply.hgSprintCollisionDamageUntil and ply.hgSprintCollisionDamageUntil > CurTime() then
                dmg = dmg * (ply.hgSprintCollisionDamageMul or 0.08)
        end

	-- Crouching only softens moderate, mostly vertical impacts.
	local safeLanding = false
	local safeLegMul = hg_safe_landing_legmul
	local safePainMul = hg_safe_landing_painmul
	if normalSpeed >= hg_safe_landing_minspeed and normalSpeed <= hg_safe_landing_maxspeed
		and IsValid(ply) and ply:Alive() and ply:KeyDown(IN_DUCK) then
		safeLanding = true
	end

    if not bone then
        bone = traceResult.PhysicsBone
    end

	if IsValid(att) and att:IsPlayer() and att.organism and att.organism.fear and att.organism.fear < 0 then
		att.organism.fear = 0
	end


	local hitgroup
	local bonename = ent:GetBoneName(ent:TranslatePhysBoneToBone(bone or 0))
	
	if bonetohitgroup[bonename] ~= nil then hitgroup = bonetohitgroup[bonename] end
	if RagdollDamageBoneMul[hitgroup] then dmgInfo:ScaleDamage(RagdollDamageBoneMul[hitgroup]) end

	local org = ent.organism
	if org.godmode then return end
	if hg.FullBodyExplode and !org.fullbodyexploded and hg.CanFullBodyGib and hg.CanFullBodyGib(ent, org, ply) and (speed >= full_body_physics_speed_threshold or rawPhysicsDamage >= full_body_physics_damage_threshold) then
		if hg.FullBodyExplode(ent, data.OurOldVelocity - data.TheirOldVelocity, dmgInfo) then return end
	end
	org.fearadd = org.fearadd + dmg * 0.5

	if not org.superfighter then
		if hitgroup == HITGROUP_LEFTLEG and (dmg * 3 > 0.25) then hg.organism.input_list.llegup(org, bone, dmg * 1 * math.Rand(1, 2), dmgInfo) end--org.lleg = math.min(org.lleg + dmg, 1) end
		if hitgroup == HITGROUP_RIGHTLEG and (dmg * 3 > 0.25) then hg.organism.input_list.rlegup(org, bone, dmg * 1 * math.Rand(1, 2), dmgInfo) end
		if hitgroup == HITGROUP_LEFTARM and (dmg * 2 > 0.2) then hg.organism.input_list.larmup(org, bone, dmg * 1 * math.Rand(1, 2), dmgInfo) end
		if hitgroup == HITGROUP_RIGHTARM and (dmg * 2 > 0.2) then hg.organism.input_list.rarmup(org, bone, dmg * 1 * math.Rand(1, 2), dmgInfo) end
		if hitgroup == HITGROUP_CHEST and (dmg * 3 > 0.25) then hg.organism.input_list.chest(org, bone, dmg * 3, dmgInfo) end
		if hitgroup == HITGROUP_STOMACH and (dmg * 3 > 0.25) then hg.organism.input_list.pelvis(org, bone, dmg * 3, dmgInfo) end
		local physAng = data.PhysObject:GetAngles()
		
		if hitgroup == HITGROUP_STOMACH and physAng:Forward():Dot(data.HitNormal) > 0.6 then hg.organism.input_list.spine1(org, bone, dmg * (math.random(3) > 1 and 1 or 0) * 3, dmgInfo) end -- | И В ПРАВДУ ПОЧЕМУ У НАС СПИНА ЛОМАЕТСЯ ОТ ПАДЕНИЯ НА ГРУДЬ ИЛИ ЖИВОТ...
		if hitgroup == HITGROUP_CHEST and physAng:Forward():Dot(data.HitNormal) > 0.6 then hg.organism.input_list.spine2(org, bone, dmg * (math.random(3) > 1 and 1 or 0) * 3, dmgInfo) end


		--print(dmg * 3, dmg * 80)
		if surfaceType and surfaceType ~= nil and bleedSurfaces[surfaceType] and (dmg * 3 > 0.17) and math.random(3) ~= 1 then
			hg.organism.AddWoundManual(ent,dmg*7,vector_origin,angle_zero,bone,CurTime() + (dmg * 250))
			--PrintTable(org.wounds)
		end
		--print(dmg)
		if dmg > 0.2 then
			org.internalBleed = org.internalBleed + (dmg * 2.5) 
		end

		org.owner:AddNaturalAdrenaline( math.min( dmg * 0.5, 4) )

		if hitgroup == HITGROUP_HEAD then
			local hadhelmet = org.owner.armors and org.owner.armors["head"] != nil
			local head_otrub_chance = math.Clamp((dmg - head_otrub_min_damage) * head_otrub_chance_mul, 0, head_otrub_max_chance)
			local headDamageMul = hadhelmet and 0.2 or 1
			local oldSkull = org.skull
			local isMeleeHit = dmgInfo:IsDamageType(DMG_CLUB) or dmgInfo:IsDamageType(DMG_SLASH)
			local skullDmgMul = isMeleeHit and 0.08 or 6
			
			hg.organism.input_list.skull(org, bone, dmg * skullDmgMul * headDamageMul * ragdoll_fall_skull_damage_mul, dmgInfo)
			hg.organism.input_list.jaw(org, bone, dmg * headDamageMul * ragdoll_fall_jaw_damage_mul, dmgInfo)
			org._deferHeadTraumaFlash = nil

			if hg.organism.SendHeadTraumaFlash then
				hg.organism.SendHeadTraumaFlash(
					org,
					dmg,
					dmgInfo,
					math.max((org.skull or 0) - oldSkull, 0),
					math.max((org.concussion or 0) - oldConcussion, 0),
					math.max((org.brain or 0) - oldBrain, 0),
					"collision"
				)
			end
			
			org.consciousness = math.Approach(org.consciousness, 0, dmg * head_consciousness_mul * headDamageMul)
			
			//if dmg > 0.5 then
				hg.organism.input_list.spine3(org, bone, dmg * (math.random(4) == 1 and 1 or 0) * 3 * (hadhelmet and 0.5 or 1), dmgInfo)
			//end
			if dmg > head_otrub_min_damage and !hadhelmet and math.Rand(0, 1) < head_otrub_chance then
				org.needotrub = true
				org.shock = org.shock + 10
				org.consciousness = math.min(org.consciousness, head_otrub_consciousness_cap)
			end

			if oldSkull < 1 and org.skull == 1 then
				net.Start("hg_bloodimpact")
				net.WriteVector(getHeadImpactPos(ent, data.HitPos))
				net.WriteVector((data.OurOldVelocity - data.TheirOldVelocity):GetNormalized() / 10)
				net.WriteFloat(math.max(dmg * ragdoll_fall_skull_break_blood_mul, 1))
				net.WriteInt(1, 8)
				net.WriteBool(true)
				net.WriteBool(false)
				net.Broadcast()
			end

			-- Collisions used to bypass the normal body-part gib health entirely,
			-- leaving heads far more durable than arms against walls, falls and map
			-- props.  Feed the impact into the same persistent pool as other gib
			-- damage so repeated head impacts can destroy the head naturally.
			local headGibDamage = DamageBodyPart(org, HITGROUP_HEAD, dmg * 30 * headDamageMul)
			if !ent.headexploded and (headGibDamage >= player_head_gib_threshold or dmg * headDamageMul > player_fall_head_gib_threshold) then
				hg.ExplodeHead(ent, headGibDamage, false, data.OurOldVelocity - data.TheirOldVelocity)
			end
		end
	else
		local sfd = org.fakePlayer and ent or ply
		if not IsValid(sfd) then return end
		if sfd:Health() > 0 then
			sfd:SetHealth(sfd:Health()-dmg * 1)
		else
			sfd:Kill() 
			return
		end
	end

	hook_Run("HomigradDamage", ent, dmgInfo, hitgroup, ent, att.harm, {}, {})
	
	if org.isPly and ply then
		hook.Run("Org Think Call", ply, org)
		
if (not ply:Alive() or not org.alive) and (math.Round(ply:GetInfoNum("hg_deathfadeout", 1)) == 1) then// or org.otrub or hg.organism.paincheck(org) or (ply:Health() <= 0) then
			QueueHeadDisfigurement(ply, org, ent)
			
			ply:ScreenFade(0, color_black, 1, 1)
			ply:ConCommand("soundfade 100 99999")
		end
	end

	timer.Create("send_info_org"..ent:EntIndex(),0.01,1,function()
		if !IsValid(ent) then return end

		hg.send_bareinfo(org)

		if IsValid(ply) and ply.Alive and ply:Alive() then
			ply.fullsend = true
			hg.send_organism(org, ply)
		end
	end)

	att.harm = 0

	local dmghuy = dmg * 20 * (safeLanding and safePainMul or 1) * (org.painresist or 1)

	if not org.superfighter then
		org.painadd = org.painadd + dmghuy
		org.shock = org.shock + dmghuy
	else
		dmghuy = dmghuy * 0.5
	end

	//if dmghuy >= 1 then
	//	ply:SetHealth(ply:Health() - dmghuy)
	//	if ply:Health() <= 0 and ply:Alive() then ply:Kill() end
	//end
end

-- Apply a small bone manipulation offset to make a broken bone look
-- displaced/out-of-place rather than just a freely moving joint.
-- Stores prior values so they can be restored on heal. Declared before
-- hg.BreakNeck because BreakNeck calls it (Lua resolves free variables
-- lexically at parse time, so the local must already be in scope).
local getPhysBoneForAnimationBone
local function applyFloppyBoneOffset(rag, boneName, offsetPos, offsetAng, key)
    if not IsValid(rag) then return end
    local boneID = rag:LookupBone(boneName)
    if not boneID then return end
    rag.FloppyBoneOffsets = rag.FloppyBoneOffsets or {}
    rag.FloppyBoneOffsets[key] = rag.FloppyBoneOffsets[key] or {}
    -- Avoid stacking offsets if the same offset was already applied
    if rag.FloppyBoneOffsets[key][boneName] then return end
    
    -- Get current bone manipulation values
    local currentPos = rag:GetManipulateBonePosition(boneID)
    local currentAng = rag:GetManipulateBoneAngles(boneID)
    
    -- Validate that values are not NaN before storing
    local isValidPos = currentPos and not (currentPos.x ~= currentPos.x or currentPos.y ~= currentPos.y or currentPos.z ~= currentPos.z)
    local isValidAng = currentAng and not (currentAng.p ~= currentAng.p or currentAng.y ~= currentAng.y or currentAng.r ~= currentAng.r)
    
    rag.FloppyBoneOffsets[key][boneName] = {
        pos = isValidPos and currentPos or vector_origin,
        ang = isValidAng and currentAng or angle_zero,
    }
    
    -- Only apply offset if the offset values themselves are valid
    if offsetPos and not (offsetPos.x ~= offsetPos.x or offsetPos.y ~= offsetPos.y or offsetPos.z ~= offsetPos.z) then
        rag:ManipulateBonePosition(boneID, offsetPos)
    end
    if offsetAng and not (offsetAng.p ~= offsetAng.p or offsetAng.y ~= offsetAng.y or offsetAng.r ~= offsetAng.r) then
        rag:ManipulateBoneAngles(boneID, offsetAng)
    end
end

local function removeFloppyBoneOffset(rag, key)
    if not IsValid(rag) then return end
    if not rag.FloppyBoneOffsets or not rag.FloppyBoneOffsets[key] then return end
    for boneName, prev in pairs(rag.FloppyBoneOffsets[key]) do
        local boneID = rag:LookupBone(boneName)
        if boneID then
            -- Validate stored values before restoring
            local restorePos = prev.pos
            local restoreAng = prev.ang
            
            if restorePos and (restorePos.x ~= restorePos.x or restorePos.y ~= restorePos.y or restorePos.z ~= restorePos.z) then
                restorePos = vector_origin
            end
            if restoreAng and (restoreAng.p ~= restoreAng.p or restoreAng.y ~= restoreAng.y or restoreAng.r ~= restoreAng.r) then
                restoreAng = angle_zero
            end
            
            rag:ManipulateBonePosition(boneID, restorePos or vector_origin)
            rag:ManipulateBoneAngles(boneID, restoreAng or angle_zero)
        end
    end
    rag.FloppyBoneOffsets[key] = nil
end

-- Preserve the original snapped-neck pose when the model exposes the expected
-- head and upper-spine physics bones.  Some custom models do not, so callers
-- must fall back to the model-agnostic neck implementation below.
local function tryOriginalNeckFloppy(ragdoll, org)
	if not IsValid(ragdoll) or not ragdoll:IsRagdoll() then return false end
	if not org or (org.spine3 or 0) < hg.organism.fake_spine3 then return false end
	if ragdoll.FloppyConstraints and IsValid(ragdoll.FloppyConstraints.neck) then return true end

	local spineBone = ragdoll:LookupBone("ValveBiped.Bip01_Spine2")
	local headBone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")
	if not spineBone or not headBone then return false end

	local spinePhysBone = getPhysBoneForAnimationBone(ragdoll, spineBone)
	local headPhysBone = getPhysBoneForAnimationBone(ragdoll, headBone)
	if not spinePhysBone or not headPhysBone or spinePhysBone < 0 or headPhysBone < 0 or spinePhysBone == headPhysBone then return false end

	local spinePhys = ragdoll:GetPhysicsObjectNum(spinePhysBone)
	local headPhys = ragdoll:GetPhysicsObjectNum(headPhysBone)
	if not IsValid(spinePhys) or not IsValid(headPhys) then return false end

	local jointPos = headPhys:GetPos() + headPhys:GetAngles():Forward() * -2 + headPhys:GetAngles():Up() * -1.5
	local localPos = WorldToLocal(jointPos, angle_zero, spinePhys:GetPos(), spinePhys:GetAngles())
	if not localPos then return false end

	-- This is the original neck break placement and angular range.  It is kept
	-- separate from the generic implementation because it depends on Spine2.
	ragdoll:RemoveInternalConstraint(headPhysBone)
	headPhys:SetPos(spinePhys:GetPos() + spinePhys:GetAngles():Forward() * 12.9 + spinePhys:GetAngles():Right() * -1)
	local constraintEnt = constraint.AdvBallsocket(ragdoll, ragdoll, spinePhysBone, headPhysBone, localPos, nil, 0, 0, -55, -90, -50, 55, 35, 50, 0, 0, 0, 0, 0)
	if not IsValid(constraintEnt) then return false end

	ragdoll.FloppyConstraints = ragdoll.FloppyConstraints or {}
	ragdoll.FloppyConstraints.neck = constraintEnt
	return true
end

function hg.BreakNeck(ent, fromDamage, force)
	print("[HG Floppy] BreakNeck called: ent=" .. tostring(ent) .. " fromDamage=" .. tostring(fromDamage) .. " force=" .. tostring(force))
	if not IsValid(ent) then
		print("[HG Floppy] BreakNeck FAIL: ent invalid")
		return
	end

	local ply = ent:IsRagdoll() and hg.RagdollOwner(ent) or ent

	print("[HG Floppy] BreakNeck: ply=" .. tostring(ply) .. " isRagdoll=" .. tostring(ent:IsRagdoll()))

	-- A low-force spine3 break remains a paralyzing floppy-neck injury. Higher
	-- force progressively restores the old instant-death result, while extreme
	-- force can tear the head free through the normal head-amputation pipeline.
	local forceAmount = math.max(tonumber(force) or 0, 0)
	local decapChance = math.Clamp(
		(forceAmount - neck_break_decap_force_start) / (neck_break_decap_force_certain - neck_break_decap_force_start),
		0,
		1
	)
	if decapChance > 0 and math.Rand(0, 1) < decapChance then
		hg.ExplodeHead(ent)
		return
	end

	local killChance = math.Clamp(
		(forceAmount - neck_break_kill_force_start) / (neck_break_kill_force_certain - neck_break_kill_force_start),
		0,
		1
	)
	if killChance > 0 and IsValid(ply) and ply:IsPlayer() and ply:Alive() and math.Rand(0, 1) < killChance then
		ply:Kill()
	end

	-- Store the player reference for later
	local playerRef = ply
	
	-- Use a longer delay to ensure ragdoll is created and networked
	timer.Simple(0.2, function()
		print("[HG Floppy] BreakNeck timer START")
		-- Get the ragdoll - try multiple sources
		local ragdoll = nil
		
		if IsValid(ent) and ent:IsRagdoll() then
			ragdoll = ent
			print("[HG Floppy] BreakNeck timer: using ent as ragdoll")
		elseif IsValid(playerRef) then
			ragdoll = playerRef:GetNWEntity("RagdollDeath")
			print("[HG Floppy] BreakNeck timer: RagdollDeath=" .. tostring(ragdoll))
			if not IsValid(ragdoll) and isfunction(playerRef.GetRagdollEntity) then
				ragdoll = playerRef:GetRagdollEntity()
				print("[HG Floppy] BreakNeck timer: GetRagdollEntity=" .. tostring(ragdoll))
			end
		end
		
		if not IsValid(ragdoll) then
			print("[HG Floppy] BreakNeck timer FAIL: no valid ragdoll found")
			return
		end
		print("[HG Floppy] BreakNeck timer: ragdoll valid")
		
		-- Update the organism if available
		local org = IsValid(playerRef) and playerRef.organism or ragdoll.organism
		if org then
			org.spine3 = math.max(org.spine3 or 0, hg.organism.fake_spine3)
			print("[HG Floppy] BreakNeck timer: confirmed spine3 break")
		end

		-- Prefer the established snapped-neck effect for standard ragdolls.  The
		-- generic version below remains available for models without its bones.
		if tryOriginalNeckFloppy(ragdoll, org) then
			if fromDamage then ragdoll:EmitSound("neck_snap_01.ogg", 60, 100, 1, CHAN_AUTO) end
			print("[HG Floppy] BreakNeck timer: applied original neck floppy")
			return
		end
		
		-- Play sound on the ragdoll (only if from damage, not reapplication)
		if fromDamage then
			ragdoll:EmitSound("neck_snap_01.ogg", 60, 100, 1, CHAN_AUTO)
		end

		-- Lookup bones and validate
		local headBoneName = "ValveBiped.Bip01_Head1"
		
		local headBoneId = ragdoll:LookupBone(headBoneName)
		if not headBoneId then
			print("[HG Floppy] BreakNeck timer FAIL: head bone lookup failed")
			return
		end
		
		-- Use the head's parent bone (neck/upper spine) instead of hardcoded Bip01_Neck1.
		-- This avoids incorrect physics bone mappings on models where Neck1 maps weirdly.
		local neckBoneId = ragdoll:GetBoneParent(headBoneId)
		if not neckBoneId or neckBoneId == -1 then
			print("[HG Floppy] BreakNeck timer FAIL: neck bone (parent of head) not found")
			return
		end
		local neckBoneName = ragdoll:GetBoneName(neckBoneId)
		print("[HG Floppy] BreakNeck timer: headBoneId=" .. tostring(headBoneId) .. " neckBoneId=" .. tostring(neckBoneId) .. " neckBoneName=" .. tostring(neckBoneName))
		
		local headPhysBone = getPhysBoneForAnimationBone(ragdoll, headBoneId)
		local neckPhysBone = getPhysBoneForAnimationBone(ragdoll, neckBoneId)
		print("[HG Floppy] BreakNeck timer: headPhysBone=" .. tostring(headPhysBone) .. " neckPhysBone=" .. tostring(neckPhysBone))
		
		if not headPhysBone or not neckPhysBone or headPhysBone == -1 or neckPhysBone == -1 then
			print("[HG Floppy] BreakNeck timer FAIL: phys bone invalid")
			return
		end
		if headPhysBone == 0 then
			print("[HG Floppy] BreakNeck timer FAIL: headPhysBone == 0")
			return
		end
		
		-- Check if neck already floppy on this ragdoll
		if ragdoll.FloppyConstraints and ragdoll.FloppyConstraints.neck and IsValid(ragdoll.FloppyConstraints.neck) then
			print("[HG Floppy] BreakNeck timer: neck already floppy, skipping")
			return -- Already has neck floppy, don't reapply
		end
		
		-- Can't create constraint between same physics bone - try alternative approach
		if headPhysBone == neckPhysBone then
			print("[HG Floppy] BreakNeck timer: head and neck share physics bone, attempting alternative method")
			-- Traverse up the bone hierarchy to find a valid anchor with different physics bone
			local currentBoneId = neckBoneId
			local anchorBoneId = nil
			local anchorPhysBone = nil
			
			for i = 1, 10 do -- Try up to 10 bones up the hierarchy
				currentBoneId = ragdoll:GetBoneParent(currentBoneId)
				if not currentBoneId or currentBoneId == -1 then
					break
				end
				
				local currentPhysBone = getPhysBoneForAnimationBone(ragdoll, currentBoneId)
				if currentPhysBone and currentPhysBone ~= -1 and currentPhysBone ~= headPhysBone then
					anchorBoneId = currentBoneId
					anchorPhysBone = currentPhysBone
					print("[HG Floppy] BreakNeck timer: found anchor bone " .. ragdoll:GetBoneName(currentBoneId) .. " with physBone=" .. tostring(currentPhysBone))
					break
				end
			end
			
			if not anchorPhysBone then
				print("[HG Floppy] BreakNeck timer FAIL: could not find valid anchor bone with different physics bone")
				return
			end
			
			-- Use the found anchor as the neck constraint anchor
			neckPhysBone = anchorPhysBone
			print("[HG Floppy] BreakNeck timer: using anchor as neckPhysBone=" .. tostring(neckPhysBone))
		end
		
		local pneck = ragdoll:GetPhysicsObjectNum(neckPhysBone)
		local phead = ragdoll:GetPhysicsObjectNum(headPhysBone)

		if not IsValid(pneck) or not IsValid(phead) then
			print("[HG Floppy] BreakNeck timer FAIL: physics object invalid")
			return
		end

		-- Wake physics objects
		phead:Wake()
		pneck:Wake()
		phead:EnableMotion(true)
		pneck:EnableMotion(true)

		-- When the organism is dead, leave the normal GMod ragdoll neck
		-- constraints untouched instead of applying the floppy neck effect.
		local org = IsValid(playerRef) and playerRef.organism
		local isDead = org and not org.alive
		print("[HG Floppy] BreakNeck timer: isDead=" .. tostring(isDead))
		if isDead then
			print("[HG Floppy] BreakNeck timer: organism dead, leaving normal neck constraints")
			return
		end

		-- Create constraint at current pose
		local head_pos = phead:GetPos()
		local neck_pos = pneck:GetPos()
		
		-- Use child physical origin as jointPos to eliminate physical mismatch and stretching
		local jointPos = head_pos
		
		-- Calculate local positions for both physics objects
		local lpos1 = WorldToLocal(jointPos, angle_zero, pneck:GetPos(), pneck:GetAngles())
		local lpos2 = vector_origin

		-- Neck break: keep it less stretchy than a full floppy limb (tighter
		-- angular range) but still very noticeable via the bone offset below.
		local newConstraint = constraint.AdvBallsocket(ragdoll, ragdoll, neckPhysBone, headPhysBone, lpos1, lpos2, 0, 0, -45, -45, -45, 45, 45, 45, 0, 0, 0, 0, 0)
		print("[HG Floppy] BreakNeck timer: Created floppy neck constraint")
		
		-- Track the constraint to prevent duplicates
		if newConstraint then
			-- Only remove the internal constraint AFTER the replacement is confirmed valid.
			pcall(function() ragdoll:RemoveInternalConstraint(headPhysBone) end)
			ragdoll.FloppyConstraints = ragdoll.FloppyConstraints or {}
			ragdoll.FloppyConstraints.neck = newConstraint

			-- Very noticeable head tilt with no positional offset so the neck
			-- looks clearly snapped without any stretched appearance.
			applyFloppyBoneOffset(ragdoll, headBoneName,
				vector_origin, Angle(-35, 0, 25), "neck")
			applyFloppyBoneOffset(ragdoll, neckBoneName,
				vector_origin, Angle(-18, 0, 12), "neck")

			print("[HG Floppy] BreakNeck timer SUCCESS: neck constraint created")
		else
			print("[HG Floppy] BreakNeck timer FAIL: constraint.AdvBallsocket returned nil")
		end
	end)
end

-- Limb bone mapping for floppy effects - OLD LUA STYLE
-- Each limb has 3 segments, we pick one randomly to break
local limb_segments = {
    larm = {
        {"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_Spine2"},    -- upper arm to spine
        {"ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_UpperArm"}, -- forearm to upper arm (ELBOW)
        {"ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_L_Forearm"}      -- hand to forearm
    },
    rarm = {
        {"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_Spine2"},    -- upper arm to spine
        {"ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_UpperArm"}, -- forearm to upper arm (ELBOW)
        {"ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Forearm"}      -- hand to forearm
    },
    lleg = {
        {"ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_Pelvis"},       -- thigh to pelvis
        {"ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Thigh"},       -- calf to thigh (KNEE)
        {"ValveBiped.Bip01_L_Foot", "ValveBiped.Bip01_L_Calf"}         -- foot to calf
    },
    rleg = {
        {"ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_Pelvis"},       -- thigh to pelvis
        {"ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Thigh"},       -- calf to thigh (KNEE)
        {"ValveBiped.Bip01_R_Foot", "ValveBiped.Bip01_R_Calf"}         -- foot to calf
    }
}

-- OLD LUA: Bone Buster angle limits for ragdoll constraints
local bb_constraints_limit = {
    ["ValveBiped.Bip01_R_UpperArm"] = {
        [0] = { [0] = "100", [1] = "-100" },
        [1] = { [0] = "50",  [1] = "-50" },
        [2] = { [0] = "30",  [1] = "-30" },
    },
    ["ValveBiped.Bip01_L_UpperArm"] = {
        [0] = { [0] = "100", [1] = "-100" },
        [1] = { [0] = "50",  [1] = "-50" },
        [2] = { [0] = "30",  [1] = "-30" },
    },
    ["ValveBiped.Bip01_L_Forearm"] = {
        [0] = { [0] = "90",  [1] = "-135" },
        [1] = { [0] = "45",  [1] = "-45" },
        [2] = { [0] = "90",  [1] = "-90" },
    },
    ["ValveBiped.Bip01_R_Forearm"] = {
        [0] = { [0] = "90",  [1] = "-135" },
        [1] = { [0] = "45",  [1] = "-45" },
        [2] = { [0] = "90",  [1] = "-90" },
    },
    ["ValveBiped.Bip01_L_Hand"] = {
        [0] = { [0] = "90",  [1] = "-90" },
        [1] = { [0] = "90",  [1] = "-90" },
        [2] = { [0] = "90",  [1] = "-90" },
    },
    ["ValveBiped.Bip01_R_Hand"] = {
        [0] = { [0] = "90",  [1] = "-90" },
        [1] = { [0] = "90",  [1] = "-90" },
        [2] = { [0] = "90",  [1] = "-90" },
    },
    ["ValveBiped.Bip01_R_Thigh"] = {
        [0] = { [0] = "100", [1] = "-60" },
        [1] = { [0] = "10",  [1] = "-60" },
        [2] = { [0] = "45",  [1] = "-5" },
    },
    ["ValveBiped.Bip01_R_Calf"] = {
        [0] = { [0] = "60",  [1] = "-135" },
        [1] = { [0] = "20",  [1] = "-45" },
        [2] = { [0] = "45",  [1] = "-5" },
    },
    ["ValveBiped.Bip01_L_Thigh"] = {
        [0] = { [0] = "100", [1] = "-60" },
        [1] = { [0] = "60",  [1] = "-10" },
        [2] = { [0] = "5",   [1] = "-45" },
    },
    ["ValveBiped.Bip01_L_Calf"] = {
        [0] = { [0] = "60",  [1] = "-135" },
        [1] = { [0] = "45",  [1] = "-20" },
        [2] = { [0] = "5",   [1] = "-45" },
    },
    ["ValveBiped.Bip01_L_Foot"] = {
        [0] = { [0] = "45",  [1] = "-45" },
        [1] = { [0] = "45",  [1] = "-45" },
        [2] = { [0] = "45",  [1] = "-45" },
    },
    ["ValveBiped.Bip01_R_Foot"] = {
        [0] = { [0] = "45",  [1] = "-45" },
        [1] = { [0] = "45",  [1] = "-45" },
        [2] = { [0] = "45",  [1] = "-45" },
    },
    ["ValveBiped.Bip01_Spine2"] = {
        [0] = { [0] = "40",  [1] = "-40" },
        [1] = { [0] = "30",  [1] = "-30" },
        [2] = { [0] = "20",  [1] = "-20" },
    },
    ["ValveBiped.Bip01_Pelvis"] = {
        [0] = { [0] = "90",  [1] = "-90" },
        [1] = { [0] = "90",  [1] = "-90" },
        [2] = { [0] = "90",  [1] = "-90" },
    },
}

-- Limb-specific constraint limits for better floppy physics
-- More generous limits for noticeably floppy but still realistic movement
local limb_constraint_limits = {
    -- Arms: moderate limits for floppy but not insane arm hang/flop
    larm = {minYaw = -90, minRoll = -100, minPitch = -90, maxYaw = 90, maxRoll = 50, maxPitch = 90},
    rarm = {minYaw = -90, minRoll = -50, minPitch = -90, maxYaw = 90, maxRoll = 100, maxPitch = 90},
    -- Legs: moderate limits for noticeable limp/flop without spinning wildly
    lleg = {minYaw = -70, minRoll = -80, minPitch = -70, maxYaw = 70, maxRoll = 50, maxPitch = 70},
    rleg = {minYaw = -70, minRoll = -50, minPitch = -70, maxYaw = 70, maxRoll = 80, maxPitch = 70},
}

-- Spine segment mapping for floppy effects
-- The HL2 player ragdoll only has one physical spine joint (between
-- physbone 0 = Pelvis and physbone 1 = Spine2), so all spine segments
-- break the same joint but with distinct constraint limits, anchor bias
-- and bone-offset directions to give visually distinct effects.
-- bone1 must be the non-root physbone side (Spine2) because createFloppyLimbConstraint
-- bails out if phys1 == 0.
local spine_segments = {
    -- spine1 / pelvis: pelvis flops loose; lower spine sags forward.
    spine1 = {
        bone1 = "ValveBiped.Bip01_Spine2",
        bone2 = "ValveBiped.Bip01_Pelvis",
        limits = {minPitch = -90, maxPitch = 90, minYaw = -90, maxYaw = 90, minRoll = -90, maxRoll = 90},
        -- Bias the constraint anchor towards the pelvis end of the joint
        anchorBias = 0.85,
        offsetBones = {
            {name = "ValveBiped.Bip01_Pelvis", pos = Vector(0, 0, -4),  ang = Angle(15, 0, 10)},
            {name = "ValveBiped.Bip01_Spine",  pos = Vector(0, 1.5, -1.5), ang = Angle(10, 0, 5)},
        },
    },
    -- spine2: back is snapped; chest hangs back/loose ("broken back").
    spine2 = {
        bone1 = "ValveBiped.Bip01_Spine2",
        bone2 = "ValveBiped.Bip01_Pelvis",
        limits = {minPitch = -120, maxPitch = 60, minYaw = -80, maxYaw = 80, minRoll = -60, maxRoll = 60},
        -- Bias the constraint anchor towards the chest end of the joint
        anchorBias = 0.15,
        offsetBones = {
            -- Keep the visual break on the middle-torso physics bone.  Spine4
            -- is above this joint and carries the Neck1/Head1 descendants, so
            -- offsetting it here made a spine2 break look like a neck flop.
            {name = "ValveBiped.Bip01_Spine2", pos = Vector(0, -3, 4),  ang = Angle(-25, 0, 0)},
        },
    },
}

-- (applyFloppyBoneOffset / removeFloppyBoneOffset are declared above
--  hg.BreakNeck because BreakNeck references them; see top of this section.)

local matrix_cache = {}

local function getBoneMatrix(rag, boneID)
    local model = rag:GetModel()
    if not matrix_cache[model] then
        local _, tab = util.GetModelMeshes(model)
        if not tab then return end

        matrix_cache[model] = {}
        for i = 0, rag:GetPhysicsObjectCount() - 1 do
            local id = rag:TranslatePhysBoneToBone(i)
            if tab[id] and tab[id].matrix then
                local mat = tab[id].matrix:GetInverse()
                matrix_cache[model][id] = mat
            end
        end
    end
    return matrix_cache[model] and matrix_cache[model][boneID]
end

-- Helper: reliably map an animation bone to its physics bone index.
-- TranslateBoneToPhysBone is unreliable on some ragdolls, so we build a
-- reverse lookup with TranslatePhysBoneToBone and fall back to distance.
getPhysBoneForAnimationBone = function(rag, boneID)
    if not boneID then return nil end
    -- Method 1: reverse mapping via TranslatePhysBoneToBone
    for i = 0, rag:GetPhysicsObjectCount() - 1 do
        if rag:TranslatePhysBoneToBone(i) == boneID then
            return i
        end
    end
    -- Method 2: closest physics object by world position
    local bonePos = rag:GetBonePosition(boneID)
    if not bonePos then return nil end
    local bestPhys, bestDist = -1, math.huge
    for i = 0, rag:GetPhysicsObjectCount() - 1 do
        local phys = rag:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            local dist = phys:GetPos():DistToSqr(bonePos)
            if dist < bestDist then
                bestDist = dist
                bestPhys = i
            end
        end
    end
    return bestPhys
end

--- Create stiff constraint to prevent limb stretching (used for dead organisms or broken necks)
local function createStiffLimbConstraint(rag, bone1Name, bone2Name)
    print("[HG Floppy] createStiffLimbConstraint START: rag=" .. tostring(rag) .. " bone1=" .. tostring(bone1Name) .. " bone2=" .. tostring(bone2Name))

    if not IsValid(rag) or not rag:IsRagdoll() then
        print("[HG Floppy] createStiffLimbConstraint FAIL: rag invalid or not ragdoll")
        return false
    end

    local bone1ID = rag:LookupBone(bone1Name)
    local bone2ID = rag:LookupBone(bone2Name)
    if not bone1ID or not bone2ID then
        print("[HG Floppy] createStiffLimbConstraint FAIL: bone lookup failed")
        return false
    end

    local phys1 = getPhysBoneForAnimationBone(rag, bone1ID)
    local phys2 = getPhysBoneForAnimationBone(rag, bone2ID)
    if not phys1 or not phys2 or phys1 < 0 or phys2 < 0 then
        print("[HG Floppy] createStiffLimbConstraint FAIL: phys bone invalid")
        return false
    end

    if phys1 == phys2 or phys1 == 0 then
        print("[HG Floppy] createStiffLimbConstraint FAIL: invalid phys bone")
        return false
    end

    local pBone1 = rag:GetPhysicsObjectNum(phys1)
    local pBone2 = rag:GetPhysicsObjectNum(phys2)
    if not (IsValid(pBone1) and IsValid(pBone2)) then
        print("[HG Floppy] createStiffLimbConstraint FAIL: physics object invalid")
        return false
    end

    -- Wake physics objects
    pBone1:Wake()
    pBone2:Wake()
    pBone1:EnableMotion(true)
    pBone2:EnableMotion(true)

    -- Get joint position
    local jointPos = pBone1:GetPos()
    local lpos = vector_origin
    local lpos2 = WorldToLocal(jointPos, angle_zero, pBone2:GetPos(), pBone2:GetAngles())

    -- Create stiff constraint with very limited movement to prevent stretching
    -- Use very small angular limits (±5 degrees) to keep limbs from stretching
    local cons = constraint.AdvBallsocket(rag, rag, phys1, phys2, lpos, lpos2, 0, 0, -5, -5, -5, 5, 5, 5, 0, 0, 0, 0, 0)

    if IsValid(cons) then
        -- Remove internal constraint after replacement is valid
        pcall(function() rag:RemoveInternalConstraint(phys1) end)
        print("[HG Floppy] createStiffLimbConstraint SUCCESS: stiff constraint created")
        return cons
    else
        print("[HG Floppy] createStiffLimbConstraint FAIL: constraint creation failed")
        return false
    end
end

--- Create floppy limb constraint at current pose
local function createFloppyLimbConstraint(rag, bone1Name, bone2Name, limbType)
    print("[HG Floppy] createFloppyLimbConstraint START: rag=" .. tostring(rag) .. " bone1=" .. tostring(bone1Name) .. " bone2=" .. tostring(bone2Name) .. " limbType=" .. tostring(limbType))

    if not IsValid(rag) or not rag:IsRagdoll() then
        print("[HG Floppy] createFloppyLimbConstraint FAIL: rag invalid or not ragdoll")
        return false
    end

    local bone1ID = rag:LookupBone(bone1Name)
    local bone2ID = rag:LookupBone(bone2Name)
    if not bone1ID or not bone2ID then
        print("[HG Floppy] createFloppyLimbConstraint FAIL: bone lookup failed bone1ID=" .. tostring(bone1ID) .. " bone2ID=" .. tostring(bone2ID))
        return false
    end
    print("[HG Floppy] createFloppyLimbConstraint: bone1ID=" .. tostring(bone1ID) .. " bone2ID=" .. tostring(bone2ID))
    -- Debug: Show actual bone names from the ragdoll
    local actualBone1Name = bone1ID and rag:GetBoneName(bone1ID) or "nil"
    local actualBone2Name = bone2ID and rag:GetBoneName(bone2ID) or "nil"
    print("[HG Floppy] createFloppyLimbConstraint: actual bone names from ragdoll: bone1=" .. actualBone1Name .. " bone2=" .. actualBone2Name)

    local matrix = getBoneMatrix(rag, bone1ID)
    local matrix_par = getBoneMatrix(rag, bone2ID)
    if not matrix or not matrix_par then
        print("[HG Floppy] createFloppyLimbConstraint FAIL: matrix missing matrix=" .. tostring(matrix) .. " matrix_par=" .. tostring(matrix_par))
        return false
    end

    local phys1 = getPhysBoneForAnimationBone(rag, bone1ID)
    local phys2 = getPhysBoneForAnimationBone(rag, bone2ID)
    if not phys1 or not phys2 or phys1 < 0 or phys2 < 0 then
        print("[HG Floppy] createFloppyLimbConstraint FAIL: phys bone invalid phys1=" .. tostring(phys1) .. " phys2=" .. tostring(phys2))
        return false
    end
    print("[HG Floppy] createFloppyLimbConstraint: phys1=" .. tostring(phys1) .. " phys2=" .. tostring(phys2))
    
    if phys1 == phys2 then
        print("[HG Floppy] createFloppyLimbConstraint FAIL: phys1 == phys2")
        return false
    end
    if phys1 == 0 then
        print("[HG Floppy] createFloppyLimbConstraint FAIL: phys1 == 0 (root bone)")
        return false
    end

    local pBone1 = rag:GetPhysicsObjectNum(phys1)
    local pBone2 = rag:GetPhysicsObjectNum(phys2)
    if not (IsValid(pBone1) and IsValid(pBone2)) then
        print("[HG Floppy] createFloppyLimbConstraint FAIL: physics object invalid pBone1=" .. tostring(pBone1) .. " pBone2=" .. tostring(pBone2))
        return false
    end
    -- Debug: Get bone names from physics objects to verify we're targeting the right bones
    local debugName1 = pBone1.GetName and pBone1:GetName() or "unknown"
    local debugName2 = pBone2.GetName and pBone2:GetName() or "unknown"
    print("[HG Floppy] createFloppyLimbConstraint: pBone1 name=" .. debugName1 .. " pBone2 name=" .. debugName2)

    -- Get Bone Buster style limits
    local limits = bb_constraints_limit[bone1Name]
    if not limits then
        print("[HG Floppy] createFloppyLimbConstraint FAIL: no limits for bone1Name=" .. tostring(bone1Name))
        return false
    end
    print("[HG Floppy] createFloppyLimbConstraint: limits found for " .. bone1Name)

    if pBone1.EnableCollisions then pBone1:EnableCollisions(true) end
    if pBone2.EnableCollisions then pBone2:EnableCollisions(true) end
    if pBone1.Wake then pBone1:Wake() end
    if pBone2.Wake then pBone2:Wake() end
    pBone1:EnableMotion(true)
    pBone2:EnableMotion(true)

    -- Set constraint position to the child bone's physical origin, which is exactly the joint location in Source ragdolls.
    -- This prevents any mismatch between the animated skeleton and simulated physics objects, eliminating stretch.
    local jointPos = pBone1:GetPos()
    print("[HG Floppy] createFloppyLimbConstraint: jointPos=" .. tostring(jointPos))

    -- Use constraint.AdvBallsocket like the neck constraint (more reliable)
    -- Calculate local positions for both physics objects at the joint
    local lpos = vector_origin
    local lpos2 = WorldToLocal(jointPos, angle_zero, pBone2:GetPos(), pBone2:GetAngles())

    -- Convert limits to numbers for AdvBallsocket
    local minPitch = tonumber(limits[0][1]) or -45
    local maxPitch = tonumber(limits[0][0]) or 45
    local minYaw = tonumber(limits[1][1]) or -45
    local maxYaw = tonumber(limits[1][0]) or 45
    local minRoll = tonumber(limits[2][1]) or -45
    local maxRoll = tonumber(limits[2][0]) or 45

    print("[HG Floppy] createFloppyLimbConstraint: Creating AdvBallsocket with limits: pitch[" .. minPitch .. "," .. maxPitch .. "] yaw[" .. minYaw .. "," .. maxYaw .. "] roll[" .. minRoll .. "," .. maxRoll .. "]")

    -- Create constraint at joint position on both bones (matching neck constraint style)
    local cons = constraint.AdvBallsocket(rag, rag, phys1, phys2, lpos, lpos2, 0, 0, minPitch, minYaw, minRoll, maxPitch, maxYaw, maxRoll, 0, 0, 0, 0, 0)

    if IsValid(cons) then
        -- Only remove the internal constraint AFTER the replacement is confirmed valid.
        -- Removing it beforehand and having AdvBallsocket fail leaves the bone unconstrained,
        -- which causes it to stretch infinitely when the ragdoll is moved.
        if rag.Constraints then
            for k, v in pairs(rag.Constraints) do
                if v.Ent1 == rag and v.Ent2 == rag then
                    if (v.Bone1 == phys1 and v.Bone2 == phys2) or (v.Bone1 == phys2 and v.Bone2 == phys1) then
                        if IsValid(v.Constraint) and v.Constraint ~= cons then v.Constraint:Remove() end
                        rag.Constraints[k] = nil
                    end
                end
            end
        end
        pcall(function() rag:RemoveInternalConstraint(phys1) end)
        print("[HG Floppy] createFloppyLimbConstraint SUCCESS: AdvBallsocket created for " .. bone1Name .. " (phys" .. phys1 .. ") -> " .. bone2Name .. " (phys" .. phys2 .. ")")
        return cons
    else
        print("[HG Floppy] createFloppyLimbConstraint FAIL: constraint.AdvBallsocket returned invalid")
        return false
    end
end

--- Create a semi-stiff "dislocated" limb constraint. The joint can still move
--- freely like a floppy bone, but a tight angular range plus high friction make
--- it hard to move, so the limb looks jammed out of place rather than limp.
local function createDislocatedLimbConstraint(rag, bone1Name, bone2Name, limbType)
    print("[HG Floppy] createDislocatedLimbConstraint START: rag=" .. tostring(rag) .. " bone1=" .. tostring(bone1Name) .. " bone2=" .. tostring(bone2Name))

    if not IsValid(rag) or not rag:IsRagdoll() then return false end

    local bone1ID = rag:LookupBone(bone1Name)
    local bone2ID = rag:LookupBone(bone2Name)
    if not bone1ID or not bone2ID then
        print("[HG Floppy] createDislocatedLimbConstraint FAIL: bone lookup failed")
        return false
    end

    local phys1 = getPhysBoneForAnimationBone(rag, bone1ID)
    local phys2 = getPhysBoneForAnimationBone(rag, bone2ID)
    if not phys1 or not phys2 or phys1 < 0 or phys2 < 0 then
        print("[HG Floppy] createDislocatedLimbConstraint FAIL: phys bone invalid")
        return false
    end
    if phys1 == phys2 or phys1 == 0 then
        print("[HG Floppy] createDislocatedLimbConstraint FAIL: invalid phys bone")
        return false
    end

    local pBone1 = rag:GetPhysicsObjectNum(phys1)
    local pBone2 = rag:GetPhysicsObjectNum(phys2)
    if not (IsValid(pBone1) and IsValid(pBone2)) then
        print("[HG Floppy] createDislocatedLimbConstraint FAIL: physics object invalid")
        return false
    end

    if pBone1.EnableCollisions then pBone1:EnableCollisions(true) end
    if pBone2.EnableCollisions then pBone2:EnableCollisions(true) end
    pBone1:Wake()
    pBone2:Wake()
    pBone1:EnableMotion(true)
    pBone2:EnableMotion(true)

    -- Anchor at the child bone's physical origin (the joint) so it can't stretch.
    local jointPos = pBone1:GetPos()
    local lpos = vector_origin
    local lpos2 = WorldToLocal(jointPos, angle_zero, pBone2:GetPos(), pBone2:GetAngles())

    -- Tight angular range + high rotational friction = semi-stiff. The joint
    -- still moves, but strongly resists, so it stays at its abnormal angle.
    local lim = 30
    local fric = 8
    local cons = constraint.AdvBallsocket(rag, rag, phys1, phys2, lpos, lpos2, 0, 0,
        -lim, -lim, -lim, lim, lim, lim, fric, fric, fric, 0, 0)

    if IsValid(cons) then
        if rag.Constraints then
            for k, v in pairs(rag.Constraints) do
                if v.Ent1 == rag and v.Ent2 == rag then
                    if (v.Bone1 == phys1 and v.Bone2 == phys2) or (v.Bone1 == phys2 and v.Bone2 == phys1) then
                        if IsValid(v.Constraint) and v.Constraint ~= cons then v.Constraint:Remove() end
                        rag.Constraints[k] = nil
                    end
                end
            end
        end
        pcall(function() rag:RemoveInternalConstraint(phys1) end)
        print("[HG Floppy] createDislocatedLimbConstraint SUCCESS for " .. bone1Name)
        return cons
    end
    print("[HG Floppy] createDislocatedLimbConstraint FAIL: constraint creation failed")
    return false
end

function hg.BreakLimb(ent, limb, segmentOverride, isDislocated)
    if not IsValid(ent) then return end
    if not limb_segments[limb] then return end

    local ply = ent:IsRagdoll() and hg.RagdollOwner(ent) or ent
    local playerRef = ply

    local fakeFlop = hg.fakeBoneFlop
    if fakeFlop and fakeFlop.SetLimbSegmentState then
        timer.Simple(0, function()
            local owner = IsValid(playerRef) and playerRef:IsPlayer() and playerRef or nil
            local ragdoll

            if IsValid(ent) and ent:IsRagdoll() then
                ragdoll = ent
                if not IsValid(owner) and hg.RagdollOwner then
                    owner = hg.RagdollOwner(ent)
                end
            elseif IsValid(owner) then
                ragdoll = owner:GetNWEntity("RagdollDeath")
                if not IsValid(ragdoll) and isfunction(owner.GetRagdollEntity) then
                    ragdoll = owner:GetRagdollEntity()
                end
                if not IsValid(ragdoll) then
                    ragdoll = owner:GetNWEntity("FakeRagdoll")
                end
            end

            local org = IsValid(owner) and owner.organism or (IsValid(ragdoll) and ragdoll.organism)
            if not org or not org.alive then return end

            local segment = segmentOverride or 2
            local state = isDislocated and "dislocated" or "broken"
            local changed, bone = fakeFlop.SetLimbSegmentState(org, limb, segment, true, {
                state = state,
                limb = limb,
                segment = segment
            })
            if not bone then return end

            if IsValid(owner) and owner:IsPlayer() then
                owner.HG_FloppyPersistSeg = owner.HG_FloppyPersistSeg or {}
                owner.HG_FloppyPersistSeg[limb] = segment
                owner.HG_FloppyPersist = owner.HG_FloppyPersist or {}
                owner.HG_FloppyPersist[limb] = true
            end

            if IsValid(ragdoll) and fakeFlop.ApplyBone then
                local stored = org.fake_floppy_bones and org.fake_floppy_bones[bone]
                fakeFlop.ApplyBone(ragdoll, bone, stored)

                timer.Simple(0, function()
                    if IsValid(ragdoll) and fakeFlop.BendBone then
                        fakeFlop.BendBone(ragdoll, bone, isDislocated and 0.5 or 0.35)
                    end
                end)
            elseif changed and IsValid(owner) and owner:IsPlayer() and fakeFlop.ScheduleRebuild then
                fakeFlop.ScheduleRebuild(owner)
            end
        end)

        return
    end

    print("[HG Floppy] BreakLimb called: ent=" .. tostring(ent) .. " limb=" .. tostring(limb) .. " seg=" .. tostring(segmentOverride) .. " isDislocated=" .. tostring(isDislocated))

    -- OLD LUA: Use delay to ensure ragdoll exists
    timer.Simple(0.1, function()
        -- Get the ragdoll - try multiple sources
        local ragdoll = nil

        if IsValid(ent) and ent:IsRagdoll() then
            ragdoll = ent
        elseif IsValid(playerRef) then
            ragdoll = playerRef:GetNWEntity("RagdollDeath")
            if not IsValid(ragdoll) and isfunction(playerRef.GetRagdollEntity) then
                ragdoll = playerRef:GetRagdollEntity()
            end
            if not IsValid(ragdoll) then
                ragdoll = playerRef:GetNWEntity("FakeRagdoll")
            end
        end

        if not IsValid(ragdoll) then
            print("[HG Floppy] BreakLimb timer: no ragdoll found for limb=" .. tostring(limb))
            return
        end

        -- Prevent duplicate floppy constraints on the same limb/ragdoll
        if ragdoll.floppyLimbs and ragdoll.floppyLimbs[limb] and IsValid(ragdoll.floppyLimbs[limb].constraint) then
            print("[HG Floppy] BreakLimb timer: limb already floppy, skipping")
            return
        end

        local segments = limb_segments[limb]
        if not segments then return end

        -- Default breaks stay at elbows/knees, but callers that know which
        -- joint failed can request the shoulder/hip/wrist/ankle segment.
        local randomSegment = segmentOverride or 2
        randomSegment = math.Clamp(math.Round(randomSegment), 1, #segments)
        local selectedSegment = segments[randomSegment]
        if not selectedSegment then return end

        local bone1Name, bone2Name = selectedSegment[1], selectedSegment[2]

        print("[HG Floppy] BreakLimb timer: ragdoll=" .. tostring(ragdoll) .. " limb=" .. tostring(limb) .. " seg=" .. tostring(randomSegment) .. " bone1=" .. tostring(bone1Name) .. " bone2=" .. tostring(bone2Name))

        -- Check bones exist
        local bone1 = ragdoll:LookupBone(bone1Name)
        local bone2 = ragdoll:LookupBone(bone2Name)
        if not bone1 or not bone2 then
            print("[HG Floppy] BreakLimb timer: bone lookup failed bone1=" .. tostring(bone1) .. " bone2=" .. tostring(bone2))
            return
        end

        -- When the organism is dead, leave the normal GMod ragdoll constraints
        -- untouched instead of applying floppy/dislocation effects.
        local org = IsValid(playerRef) and playerRef.organism
        local isDead = org and not org.alive

        print("[HG Floppy] BreakLimb timer: isDead=" .. tostring(isDead) .. " isDislocated=" .. tostring(isDislocated))

        if isDead then
            print("[HG Floppy] BreakLimb timer: organism dead, leaving normal constraints")
            return
        end

        local cons
        if isDislocated then
            -- Dislocations are semi-stiff: still movable but resists motion,
            -- and visually jammed at an abnormal angle (offset below).
            cons = createDislocatedLimbConstraint(ragdoll, bone1Name, bone2Name, limb)
        else
            cons = createFloppyLimbConstraint(ragdoll, bone1Name, bone2Name, limb)
        end
        if cons then
            print("[HG Floppy] BreakLimb timer: constraint created successfully")
            if isDislocated then
                -- Dislocations: noticeable positional displacement + abnormal
                -- angle so the joint clearly looks out of its socket.
                local dislocOffsets = {
                    larm = {pos = Vector(-1.5, -2, -1.5), ang = Angle(0, -35, -30)},
                    rarm = {pos = Vector(-1.5,  2, -1.5), ang = Angle(0,  35,  30)},
                    lleg = {pos = Vector(0, -2, -2),      ang = Angle(0, -25, -30)},
                    rleg = {pos = Vector(0,  2, -2),      ang = Angle(0,  25,  30)},
                }
                local off = dislocOffsets[limb]
                if off then
                    applyFloppyBoneOffset(ragdoll, bone1Name, off.pos, off.ang, "limb_" .. limb)
                end
            else
                -- Broken bones: angle-only offset so the limb hangs at a wrong
                -- angle without any stretched/elongated appearance.
                local breakAngles = {
                    larm = Angle(0, -10, -10),
                    rarm = Angle(0,  10,  10),
                    lleg = Angle(0,  -6, -10),
                    rleg = Angle(0,   6, -10),
                }
                local ang = breakAngles[limb]
                if ang then
                    applyFloppyBoneOffset(ragdoll, bone1Name, vector_origin, ang, "limb_" .. limb)
                end
            end

            -- Store floppy data for healing restoration
            ragdoll.floppyLimbs = ragdoll.floppyLimbs or {}
            ragdoll.floppyLimbs[limb] = {
                segment = randomSegment,
                bone1 = bone1Name,
                bone2 = bone2Name,
                constraint = cons
            }
            
            -- OLD LUA: Persist segment across ragdolls on the player
            if IsValid(playerRef) and playerRef:IsPlayer() then
                playerRef.HG_FloppyPersistSeg = playerRef.HG_FloppyPersistSeg or {}
                playerRef.HG_FloppyPersistSeg[limb] = randomSegment
                playerRef.HG_FloppyPersist = playerRef.HG_FloppyPersist or {}
                playerRef.HG_FloppyPersist[limb] = true
            end
        else
            print("[HG Floppy] BreakLimb timer: constraint creation FAILED")
        end
	end)
end

local function IsPlayerOwnedRagdoll(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayer() then return true end
    if ent:IsRagdoll() then
        local owner = hg.RagdollOwner and hg.RagdollOwner(ent)
        if not IsValid(owner) then
            owner = ent:GetNWEntity("ply")
        end
        return IsValid(owner) and owner:IsPlayer()
    end
    return false
end

function hg.RemoveLimbConstraints(ent, limb)
    if not IsValid(ent) then return end

    local ragdoll = ent:IsRagdoll() and ent or nil
    if not IsValid(ragdoll) and ent:IsPlayer() then
        ragdoll = ent:GetNWEntity("FakeRagdoll")
        if not IsValid(ragdoll) then
            ragdoll = ent:GetNWEntity("RagdollDeath")
        end
    end
    if not IsValid(ragdoll) then return end

    local owner = ent:IsPlayer() and ent or (hg.RagdollOwner and hg.RagdollOwner(ragdoll))
    local fakeFlop = hg.fakeBoneFlop
    if fakeFlop and fakeFlop.ClearStoredLimb and IsValid(owner) and owner:IsPlayer() and owner.organism then
        if fakeFlop.ClearStoredLimb(owner.organism, limb) and fakeFlop.ScheduleRebuild then
            fakeFlop.ScheduleRebuild(owner)
        end
    end

    -- Don't tear constraints out from under a player-owned ragdoll.
    -- The next time they ragdoll the constraints will match the current organism state.
    if IsPlayerOwnedRagdoll(ragdoll) then
        print("[HG Floppy] RemoveLimbConstraints: skipped player-owned ragdoll, limb=" .. tostring(limb))
        return
    end

    -- OLD LUA STYLE: Restore limb using floppyLimbs data
    if ragdoll.floppyLimbs and ragdoll.floppyLimbs[limb] then
        local floppyData = ragdoll.floppyLimbs[limb]
        print("[HG Floppy] RemoveLimbConstraints: Removing " .. limb .. " constraint, bone1=" .. tostring(floppyData.bone1) .. " bone2=" .. tostring(floppyData.bone2))
        local bone1 = ragdoll:LookupBone(floppyData.bone1)
        local bone2 = ragdoll:LookupBone(floppyData.bone2)
        if bone1 and bone2 then
            local phys1 = getPhysBoneForAnimationBone(ragdoll, bone1)
            local phys2 = getPhysBoneForAnimationBone(ragdoll, bone2)
            if phys1 and phys2 then
                -- Remove floppy constraint
                pcall(function() ragdoll:RemoveInternalConstraint(phys1) end)
                if IsValid(floppyData.constraint) then 
                    floppyData.constraint:Remove() 
                    print("[HG Floppy] RemoveLimbConstraints: Removed constraint for " .. limb)
                else
                    print("[HG Floppy] RemoveLimbConstraints: Constraint for " .. limb .. " was already invalid")
                end
                
                -- Recreate a stiff joint to prevent stretching, using original limits and friction
                local pBone1 = ragdoll:GetPhysicsObjectNum(phys1)
                local pBone2 = ragdoll:GetPhysicsObjectNum(phys2)
                if IsValid(pBone1) and IsValid(pBone2) then
                    -- Prevent physical explosion when healing by gently snapping bones back if they stretched too far
                    local pos1 = pBone1:GetPos()
                    local pos2 = pBone2:GetPos()
                    if pos1:Distance(pos2) > 25 then
                        local dir = (pos1 - pos2):GetNormalized()
                        pBone1:SetPos(pos2 + dir * 15)
                        pBone1:Wake()
                    end

                    -- Use child physical origin as the jointPos for perfect alignment
                    local jointPos = pBone1:GetPos()
                    local lpos1 = vector_origin
                    local lpos2 = WorldToLocal(jointPos, angle_zero, pBone2:GetPos(), pBone2:GetAngles())
                    
                    local limits = bb_constraints_limit[floppyData.bone1]
                    if limits then
                        local minPitch = tonumber(limits[0][1]) or -45
                        local maxPitch = tonumber(limits[0][0]) or 45
                        local minYaw = tonumber(limits[1][1]) or -45
                        local maxYaw = tonumber(limits[1][0]) or 45
                        local minRoll = tonumber(limits[2][1]) or -45
                        local maxRoll = tonumber(limits[2][0]) or 45
                        
                        -- Use friction = 0.1 to act like a normal stable GMod ragdoll joint and prevent spazzing/freaking out
                        constraint.AdvBallsocket(ragdoll, ragdoll, phys1, phys2, lpos1, lpos2, 0, 0, minPitch, minYaw, minRoll, maxPitch, maxYaw, maxRoll, 0.1, 0.1, 0.1, 0, 0)
                    end
                end
                
                ragdoll.floppyLimbs[limb] = nil
            else
                print("[HG Floppy] RemoveLimbConstraints: Failed to get phys bones for " .. limb)
            end
        else
            print("[HG Floppy] RemoveLimbConstraints: Failed to lookup bones for " .. limb)
        end
    else
        print("[HG Floppy] RemoveLimbConstraints: No floppy data for " .. limb .. " (may have been removed already)")
    end

    -- Restore the bone offset that was applied for this limb
    removeFloppyBoneOffset(ragdoll, "limb_" .. limb)
end

-- Create a floppy spine constraint using explicit limits/anchor bias from
-- spine_segments. Mirrors createFloppyLimbConstraint but tailored for spine.
local function createFloppySpineConstraint(rag, segData)
    if not IsValid(rag) or not rag:IsRagdoll() then return false end
    if not segData then return false end

    local bone1ID = rag:LookupBone(segData.bone1)
    local bone2ID = rag:LookupBone(segData.bone2)
    if not bone1ID or not bone2ID then
        print("[HG Floppy] createFloppySpineConstraint FAIL: bone lookup failed")
        return false
    end

    local phys1 = getPhysBoneForAnimationBone(rag, bone1ID)
    local phys2 = getPhysBoneForAnimationBone(rag, bone2ID)
    if not phys1 or not phys2 or phys1 < 0 or phys2 < 0 then
        print("[HG Floppy] createFloppySpineConstraint FAIL: phys bone invalid")
        return false
    end
    if phys1 == phys2 then
        print("[HG Floppy] createFloppySpineConstraint FAIL: same physbone")
        return false
    end
    if phys1 == 0 then
        print("[HG Floppy] createFloppySpineConstraint FAIL: phys1 == 0 (root)")
        return false
    end

    local pBone1 = rag:GetPhysicsObjectNum(phys1)
    local pBone2 = rag:GetPhysicsObjectNum(phys2)
    if not (IsValid(pBone1) and IsValid(pBone2)) then return false end

    -- Remove any conflicting constraints between these two bones
    if pBone1.EnableCollisions then pBone1:EnableCollisions(true) end
    if pBone2.EnableCollisions then pBone2:EnableCollisions(true) end
    if pBone1.Wake then pBone1:Wake() end
    if pBone2.Wake then pBone2:Wake() end
    pBone1:EnableMotion(true)
    pBone2:EnableMotion(true)

    -- Anchor lerped between the two physics bones according to anchorBias
    -- 0 = at pBone1 (chest), 1 = at pBone2 (pelvis)
    local bias = segData.anchorBias or 0.5
    local pos1 = pBone1:GetPos()
    local pos2 = pBone2:GetPos()
    local jointPos = LerpVector(bias, pos1, pos2)

    local lpos = WorldToLocal(jointPos, angle_zero, pBone1:GetPos(), pBone1:GetAngles())
    local lpos2 = WorldToLocal(jointPos, angle_zero, pBone2:GetPos(), pBone2:GetAngles())

    local l = segData.limits
    local cons = constraint.AdvBallsocket(rag, rag, phys1, phys2, lpos, lpos2, 0, 0,
        l.minPitch, l.minYaw, l.minRoll, l.maxPitch, l.maxYaw, l.maxRoll,
        0, 0, 0, 0, 0)
    if IsValid(cons) then
        -- Only remove the internal constraint AFTER the replacement is confirmed valid.
        if rag.Constraints then
            for k, v in pairs(rag.Constraints) do
                if v.Ent1 == rag and v.Ent2 == rag then
                    if (v.Bone1 == phys1 and v.Bone2 == phys2) or (v.Bone1 == phys2 and v.Bone2 == phys1) then
                        if IsValid(v.Constraint) and v.Constraint ~= cons then v.Constraint:Remove() end
                        rag.Constraints[k] = nil
                    end
                end
            end
        end
        pcall(function() rag:RemoveInternalConstraint(phys1) end)
        print("[HG Floppy] createFloppySpineConstraint SUCCESS")
        return cons
    end
    return false
end

function hg.BreakSpine(ent, segment, isDislocated)
    if not IsValid(ent) then return end

    -- spine3 is the neck segment.  It has its own head-to-neck constraint;
    -- never apply the pelvis-to-torso spine constraint to it.
    if segment == "spine3" then
        if hg.BreakNeck then hg.BreakNeck(ent, false) end
        return
    end

    local segData = spine_segments[segment]
    if not segData then
        print("[HG Floppy] BreakSpine: unknown segment " .. tostring(segment))
        return
    end

    local ply = ent:IsRagdoll() and hg.RagdollOwner(ent) or ent
    local playerRef = ply

    print("[HG Floppy] BreakSpine called: ent=" .. tostring(ent) .. " segment=" .. tostring(segment) .. " isDislocated=" .. tostring(isDislocated))

    timer.Simple(0.1, function()
        local ragdoll = nil

        if IsValid(ent) and ent:IsRagdoll() then
            ragdoll = ent
        elseif IsValid(playerRef) then
            ragdoll = playerRef:GetNWEntity("RagdollDeath")
            if not IsValid(ragdoll) and isfunction(playerRef.GetRagdollEntity) then
                ragdoll = playerRef:GetRagdollEntity()
            end
            if not IsValid(ragdoll) then
                ragdoll = playerRef:GetNWEntity("FakeRagdoll")
            end
        end

        if not IsValid(ragdoll) then
            print("[HG Floppy] BreakSpine timer: no ragdoll found for segment=" .. tostring(segment))
            return
        end

        -- When the organism is dead, leave the normal GMod ragdoll constraints
        -- untouched instead of applying the floppy spine effect.
        local org = IsValid(playerRef) and playerRef.organism
        if org and not org.alive then
            print("[HG Floppy] BreakSpine timer: organism dead, leaving normal constraints")
            return
        end

        ragdoll.FloppyConstraints = ragdoll.FloppyConstraints or {}
        if IsValid(ragdoll.FloppyConstraints[segment]) then
            print("[HG Floppy] BreakSpine timer: segment already floppy, skipping")
            return
        end

        local cons = createFloppySpineConstraint(ragdoll, segData)
        if cons then
            ragdoll.FloppyConstraints[segment] = cons

            -- Apply visual offsets to the configured offset bones
            local offsetScale = isDislocated and 1.4 or 1.0
            for _, ob in ipairs(segData.offsetBones) do
                applyFloppyBoneOffset(ragdoll, ob.name,
                    ob.pos * offsetScale, ob.ang * offsetScale,
                    "spine_" .. segment)
            end

            if IsValid(playerRef) and playerRef:IsPlayer() then
                playerRef.HG_SpineFloppyPersist = playerRef.HG_SpineFloppyPersist or {}
                playerRef.HG_SpineFloppyPersist[segment] = true
            end
            print("[HG Floppy] BreakSpine SUCCESS for " .. segment)
        else
            print("[HG Floppy] BreakSpine FAIL: constraint creation failed for " .. segment)
        end
    end)
end

function hg.RemoveSpineConstraints(ent, segment)
    if not IsValid(ent) then return end

    if segment == "spine3" then
        if hg.RemoveNeckConstraints then hg.RemoveNeckConstraints(ent) end
        return
    end

    local ragdoll = ent:IsRagdoll() and ent or nil
    if not IsValid(ragdoll) and ent:IsPlayer() then
        ragdoll = ent:GetNWEntity("FakeRagdoll")
        if not IsValid(ragdoll) then
            ragdoll = ent:GetNWEntity("RagdollDeath")
        end
    end
    if not IsValid(ragdoll) then return end

    -- Don't tear constraints out from under a player-owned ragdoll.
    -- The next time they ragdoll the constraints will match the current organism state.
    if IsPlayerOwnedRagdoll(ragdoll) then
        print("[HG Floppy] RemoveSpineConstraints: skipped player-owned ragdoll, segment=" .. tostring(segment))
        return
    end

    local segments = segment and {segment} or {"spine1", "spine2"}
    for _, seg in ipairs(segments) do
        local segData = spine_segments[seg]
        if segData and ragdoll.FloppyConstraints and IsValid(ragdoll.FloppyConstraints[seg]) then
            local bone1ID = ragdoll:LookupBone(segData.bone1)
            if bone1ID then
                local phys1 = getPhysBoneForAnimationBone(ragdoll, bone1ID)
                if phys1 then
                    pcall(function() ragdoll:RemoveInternalConstraint(phys1) end)
                end
            end
            ragdoll.FloppyConstraints[seg]:Remove()
            ragdoll.FloppyConstraints[seg] = nil
            removeFloppyBoneOffset(ragdoll, "spine_" .. seg)
            print("[HG Floppy] RemoveSpineConstraints: removed " .. seg)
        end
    end
end

hook.Add("OnAmputateLimb", "amputate_cuffs", function(org, ent, limb)
	if (limb == "larm" or limb == "rarm") and (org.handcuffed and ent:GetNetVar("handcuffed", false)) then
		if ent.handcuffs then
			if IsValid(ent.handcuffs[1]) then ent.handcuffs[1]:Remove() end
			if IsValid(ent.handcuffs[2]) then ent.handcuffs[2]:Remove() end
			ent.handcuffed = false
		end

		local ply = hg.RagdollOwner(ent)
		org.handcuffed = false
		ent:SetNetVar("handcuffed", false)
		if ply then ply:SetNetVar("handcuffed", false) end

		local cuffs = ents_Create("weapon_handcuffs")
		cuffs:SetPos(ent:GetPos())
		cuffs.IsSpawned = true
		cuffs.init = true
		cuffs:Spawn()
	end
end)

hook.Add("OnAmputateLimb", "amputate_flashlight", function(org, ent, limb)
	local inv = ent:GetNetVar("Inventory", {})
	if limb == "larm" and inv["Weapons"] and inv["Weapons"]["hg_flashlight"] and ent:GetNetVar("flashlight", false) then
		local flashlight = ents.Create("hg_flashlight")
		flashlight:SetPos(ent:EyePos())
		flashlight:SetAngles(ent:EyeAngles())
		flashlight:Spawn()
		flashlight:SetNetVar("enabled", ent:GetNetVar("flashlight",false))
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:ApplyForceCenter(ent:GetAimVector() * 150 * phys:GetMass())
		end
		ent:SetNetVar("flashlight",false)
		inv["Weapons"]["hg_flashlight"] = nil
		ent:SetNetVar("Inventory", inv)
	end
end)

function hg.RemoveNeckConstraints(ent)
	if not IsValid(ent) then return end

	local ragdoll = ent:IsRagdoll() and ent or nil
	if not IsValid(ragdoll) and ent:IsPlayer() then
		ragdoll = ent:GetNWEntity("FakeRagdoll")
		if not IsValid(ragdoll) then
			ragdoll = ent:GetNWEntity("RagdollDeath")
		end
		if not IsValid(ragdoll) and isfunction(ent.GetRagdollEntity) then
			ragdoll = ent:GetRagdollEntity()
		end
	end
	if IsValid(ragdoll) and ragdoll.FloppyConstraints then
		local neckCons = ragdoll.FloppyConstraints.neck
		if IsValid(neckCons) then neckCons:Remove() end
		ragdoll.FloppyConstraints.neck = nil
	end
	if IsValid(ragdoll) then
		removeFloppyBoneOffset(ragdoll, "neck")
	end
	print("[HG Floppy] RemoveNeckConstraints: removed neck floppy from " .. tostring(ent))
end

local jointStressThinkDelay = 0.12
local nextJointStressThink = 0
local crushPressureHoldTime = 0.55
local crushPressureDecay = 2

-- PhysObj:GetStress() reports received stress in kilograms. Require it to be
-- sustained so a heavy object pinning a body part can sever it without making
-- ordinary impacts or the ragdoll's own weight trigger amputations.
local crushPressureThresholds = {
	head = 180,
	larm = 260,
	rarm = 260,
	lleg = 300,
	rleg = 300,
}

local crushPressureParts = {
	[HITGROUP_HEAD] = "head",
	[HITGROUP_LEFTARM] = "larm",
	[HITGROUP_RIGHTARM] = "rarm",
	[HITGROUP_LEFTLEG] = "lleg",
	[HITGROUP_RIGHTLEG] = "rleg",
}

local function getJointPhys(ragdoll, boneName)
	local boneID = ragdoll:LookupBone(boneName)
	if not boneID then return end

	local physID = getPhysBoneForAnimationBone(ragdoll, boneID)
	if not physID or physID < 0 then return end

	local phys = ragdoll:GetPhysicsObjectNum(physID)
	if not IsValid(phys) then return end

	return phys, physID
end

local function getRagdollOrganism(ragdoll)
	local ply = hg.RagdollOwner and hg.RagdollOwner(ragdoll)
	if IsValid(ply) and ply.organism then return ply.organism, ply end
	if ragdoll.organism then return ragdoll.organism, ragdoll.organism.owner end
end

local function isUnderMedicalTreatment(ragdoll, org)
	local now = CurTime()
	if (ragdoll.HG_MedicalTreatmentUntil or 0) > now then return true end
	local owner = org.owner
	return IsValid(owner) and (owner.HG_MedicalTreatmentUntil or 0) > now
end

local function amputateFromCrushPressure(ragdoll, org, part, pressure)
	if org[part .. "amputated"] then return end
	if not IsValid(org.owner) then return end

	ragdoll.HG_CrushPressureTriggered = ragdoll.HG_CrushPressureTriggered or {}
	if ragdoll.HG_CrushPressureTriggered[part] then return end
	ragdoll.HG_CrushPressureTriggered[part] = true

	if part == "head" then
		hg.ExplodeHead(ragdoll)
	else
		hg.organism.AmputateLimb(org, part)
	end

	print("[HG CrushPressure] AMPUTATED " .. part .. " pressure=" .. tostring(math.Round(pressure)) .. "kg")
end

local function checkRagdollCrushPressure(ragdoll)
	if not IsValid(ragdoll) or not ragdoll:IsRagdoll() then return end

	local org = getRagdollOrganism(ragdoll)
	if not org or org.godmode then return end
	if isUnderMedicalTreatment(ragdoll, org) then
		-- Do not let handling during medical treatment carry over as a delayed
		-- crush amputation when the short protection window ends.
		ragdoll.HG_CrushPressureTime = {}
		return
	end

	local pressureByPart = {}
	for physID = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(physID)
		if IsValid(phys) then
			local boneID = ragdoll:TranslatePhysBoneToBone(physID)
			local boneName = boneID and ragdoll:GetBoneName(boneID)
			local part = crushPressureParts[bonetohitgroup[boneName]]
			if part and not org[part .. "amputated"] then
				local _, receivedStress = phys:GetStress()
				receivedStress = tonumber(receivedStress) or 0
				pressureByPart[part] = math.max(pressureByPart[part] or 0, receivedStress)
			end
		end
	end

	ragdoll.HG_CrushPressureTime = ragdoll.HG_CrushPressureTime or {}
	for part, threshold in pairs(crushPressureThresholds) do
		if not org[part .. "amputated"] then
			local pressure = pressureByPart[part] or 0
			local exposure = ragdoll.HG_CrushPressureTime[part] or 0
			if pressure >= threshold then
				exposure = exposure + jointStressThinkDelay * math.Clamp(pressure / threshold, 1, 3)
			else
				exposure = math.max(exposure - jointStressThinkDelay * crushPressureDecay, 0)
			end
			ragdoll.HG_CrushPressureTime[part] = exposure

			if exposure >= crushPressureHoldTime then
				amputateFromCrushPressure(ragdoll, org, part, pressure)
				ragdoll.HG_CrushPressureTime[part] = 0
			end
		end
	end
end

local function jointStressValue(ragdoll, cacheKey, phys1, phys2)
	local pos1 = phys1:GetPos()
	local pos2 = phys2:GetPos()
	local delta = pos1 - pos2
	local dist = delta:Length()
	if dist <= 0 then return 0 end

	ragdoll.HG_JointStressRest = ragdoll.HG_JointStressRest or {}
	local restDist = ragdoll.HG_JointStressRest[cacheKey]
	if not restDist then
		ragdoll.HG_JointStressRest[cacheKey] = dist
		return 0
	end

	local dir = delta / dist
	local relVel = phys1:GetVelocity() - phys2:GetVelocity()
	local separatingSpeed = math.max(relVel:Dot(dir), 0)
	local speedDiff = relVel:Length()
	local stretch = math.max(dist - restDist, 0)

	-- Muscle/self-control can create high relative velocity without actually
	-- pulling the joint apart. Only count a real yank: visible stretch or
	-- strong separating motion away from the parent bone.
	if stretch < 10 and separatingSpeed < 420 then return 0 end

	return stretch * 22 + separatingSpeed * 0.75 + speedDiff * 0.05
end

local function breakSpineFromJointStress(ragdoll, org, ply, segment, stress)
	local threshold = (hg.organism and hg.organism["fake_" .. segment]) or 0.8
	if org[segment] and org[segment] >= threshold then return end

	local chance = math.Clamp((stress - 760) / 720, 0.08, 0.65)
	if math.random() > chance then
		org.painadd = (org.painadd or 0) + math.Clamp(stress / 45, 4, 18)
		org.shock = (org.shock or 0) + math.Clamp(stress / 80, 2, 10)
		return
	end

	org[segment] = math.max(org[segment] or 0, threshold)
	org.painadd = (org.painadd or 0) + math.Clamp(stress / 10, 35, 90)
	org.shock = (org.shock or 0) + math.Clamp(stress / 18, 20, 60)
	org.internalBleed = (org.internalBleed or 0) + math.Clamp(stress / 1400, 0.15, 0.75)
	org.just_damaged_bone = CurTime()

	if IsValid(ply) and ply.AddNaturalAdrenaline then ply:AddNaturalAdrenaline(1) end
	if IsValid(ply) then
		ply:EmitSound("newbonebreak/break" .. math.random(10) .. ".wav", 85, math.random(105, 125), 1, CHAN_AUTO)
	end

	if segment == "spine3" then
		if hg.BreakNeck then hg.BreakNeck(ragdoll, false, stress) end
	elseif hg.BreakSpine and ConVarExists("hg_floppy_limbs") and GetConVar("hg_floppy_limbs"):GetBool() then
		hg.BreakSpine(ragdoll, segment, false)
	end

	print("[HG JointStress] BROKE " .. tostring(segment) .. " stress=" .. tostring(math.Round(stress)) .. " chance=" .. tostring(math.Round(chance * 100)) .. "%")
end

local jointStressSpine = {
	{segment = "spine1", child = "ValveBiped.Bip01_Pelvis", parent = "ValveBiped.Bip01_Spine2", threshold = 900},
	{segment = "spine2", child = "ValveBiped.Bip01_Spine2", parent = "ValveBiped.Bip01_Pelvis", threshold = 940},
	{segment = "spine3", child = "ValveBiped.Bip01_Head1", parent = "ValveBiped.Bip01_Spine2", threshold = 1020},
}

local function checkRagdollJointStress(ragdoll)
	if not IsValid(ragdoll) or not ragdoll:IsRagdoll() then return end

	local org, ply = getRagdollOrganism(ragdoll)
	if not org or not org.alive then return end

	ragdoll.HG_JointStressCooldown = ragdoll.HG_JointStressCooldown or {}

	for _, def in ipairs(jointStressSpine) do
		if (ragdoll.HG_JointStressCooldown[def.segment] or 0) <= CurTime() then
			local phys1 = getJointPhys(ragdoll, def.child)
			local phys2 = getJointPhys(ragdoll, def.parent)
			if IsValid(phys1) and IsValid(phys2) then
				local stress = jointStressValue(ragdoll, "spine_" .. def.segment, phys1, phys2)
				if stress >= def.threshold then
					ragdoll.HG_JointStressCooldown[def.segment] = CurTime() + 2.5
					breakSpineFromJointStress(ragdoll, org, ply, def.segment, stress)
				end
			end
		end
	end
end

hook.Add("Think", "HG_JointForceDislocation", function()
	if nextJointStressThink > CurTime() then return end
	nextJointStressThink = CurTime() + jointStressThinkDelay

	for _, ragdoll in ipairs(ents.FindByClass("prop_ragdoll")) do
		checkRagdollJointStress(ragdoll)
		checkRagdollCrushPressure(ragdoll)
	end
end)

hook.Add("OnAmputateLimb", "amputate_remove_floppy", function(org, ent, limb)
	if not IsValid(ent) then return end

	if limb == "head" then
		hg.RemoveNeckConstraints(ent)
	else
		-- Remove from current entity if it's a ragdoll
		hg.RemoveLimbConstraints(ent, limb)

		-- Also remove from all player ragdolls and clear persistence so it never comes back
		local ply = ent:IsPlayer() and ent or nil
		if not IsValid(ply) then ply = hg.RagdollOwner(ent) end

		if IsValid(ply) then
			local ragdolls = {
				ply:GetNWEntity("FakeRagdoll"),
				ply:GetNWEntity("RagdollDeath"),
				isfunction(ply.GetRagdollEntity) and ply:GetRagdollEntity() or nil
			}
			for _, rag in ipairs(ragdolls) do
				if IsValid(rag) then
					hg.RemoveLimbConstraints(rag, limb)
				end
			end

			if ply.HG_FloppyPersist then
				ply.HG_FloppyPersist[limb] = nil
			end
			if ply.HG_FloppyPersistSeg then
				ply.HG_FloppyPersistSeg[limb] = nil
			end
		end
	end
end)

hg.velocityDamage = velocityDamage

hook.Add("Ragdoll Collide", "organism", function(ragdoll, data)
	if ragdoll == data.HitEntity then return end
	if data.DeltaTime < 0.25 then return end
	if not ragdoll:IsRagdoll() then return end
	if data.HitEntity:IsPlayerHolding() then return end
	velocityDamage(ragdoll, data)
	--if data.Speed < 250 then return end
	--if data.HitEntity:IsPlayer() then hg.Fake(data.HitEntity) end
end)

hook.Add("Player Spawn", "huyhuyhuy22", function(ply)
	if OverrideSpawn then return end

	--local wnds = table.Copy(ply.wounds)
	--local artwnds = table.Copy(ply.arterialwounds)
	ply.HitBones = {}
	ply.AddForceRag = {}

	ply.wounds = nil
	ply.arterialwounds = nil

	ply.wounds = {}
	ply.arterialwounds = {}

	timer.Simple(0, function()
		if !IsValid(ply) or !ply.organism then return end
		ply.organism.gibhealth = nil
		ply.organism.stomachgibbed = false
		ply.organism.fullbodyexploded = false
		ply.fullbodyexploded = nil
	end)
end)

hook.Add("Player Getup", "huyhhgss", function(ply)
	if ply.callback_physics then ply:RemoveCallback("PhysicsCollide",ply.callback_physics) ply.callback_physics = nil end
	
	ply.callback_physics = ply:AddCallback("PhysicsCollide",function(ply,data)
		if data.HitEntity:IsPlayerHolding() then return end
		if ply:GetGroundEntity() == data.HitEntity then return end
		if data.TheirOldVelocity:Length() < 50 then return end
		--if data.DeltaTime < 0.25 then return end
		local vel = data.TheirOldVelocity
		
		local needed = (data.HitEntity:IsRagdoll() and 200 or 4000)
		local force = vel:Length() * (data.HitObject:GetEntity():GetPhysicsObject():GetMass() / 24)
		if (force) > needed then 
			if ply:IsBerserk() then -- unstoppable
				return
			end
			local ent = data.HitObject:GetEntity()
			if ent:IsRagdoll() and hg.RagdollOwner(ent) then
				local attacker = hg.RagdollOwner(ent)
				hook.Run("ZC_SomeoneGetFallBy",attacker,ply)
				--attacker.Guilt = attacker.Guilt or 0
				--attacker.Guilt = attacker.Guilt < 4 and 5 or attacker.Guilt 
				--print(attacker.Guilt)
			end
			timer.Simple(0, function()
				hg.LightStunPlayer(ply,math.min(force / needed,4)) 
			end)
		end
	end)
end)

--local PLAYER = FindMetaTable("PLAYER")
--function PLAYER:ApplyPain(number)
	--self.organism.painadd = self.organism.painadd + number
--end
function hg.VehicleHitFunc(ent, tr, bullet, details)
	local maxdmg = 0
	local penetration = true
	local bulletPenetration = bullet and bullet.Penetration or 0

	for i, detail in pairs(details) do
		local lpos, lang, mins, maxs = detail.lpos, detail.lang, detail.mins, detail.maxs

		if detail.boxcalc then
			lpos, lang, mins, maxs = detail.boxcalc(ent)
		end
		
		if !lpos then continue end

		local pos, ang = LocalToWorld(lpos, lang, ent:GetPos(), ent:GetAngles())

		local hitpos, hitnormal, frac = util.IntersectRayWithOBB(tr.HitPos, tr.Normal * 1000, pos, ang, mins, maxs)
		
		debugoverlay.BoxAngles(pos, mins, maxs, ang, 1, color_white)
		debugoverlay.Line(tr.HitPos, tr.HitPos + tr.Normal * 1000, 1, color_white, true)
		
		if hitpos then
			maxdmg = math.max(maxdmg, detail.dmgmul)
			penetration = penetration and detail.penetration < bulletPenetration

			-- maybe some other effects
		end
	end
	
	return penetration, maxdmg
end

local defaultEngineMins = Vector(-25, -35, -8)
local defaultEngineMaxs = Vector(35, 35, 35)
local defaultEngineOffset = Vector(65, 0, 0)
hg.vehicledetails = {
	["prop_vehicle_prisoner_pod"] = {},
	["default"] = {
		{
			name = "engine",
			dmgmul = 1, -- how much to damage the vehicle
			penetration = 20, -- will be penetrated with calibers higher than this (damage will still apply)
			boxcalc = function(ent)
				-- we need to calculate the approximate position of the engine
				-- it is usually between 2 front wheels, so let's search for them

				local engineoffset = lpos
				if ent.IsGlideVehicle then
					if ent.wheelCount >= 2 then
						local w1 = ent.wheels[1]
						local w2 = ent.wheels[2]

						local middle = (w2:GetPos() - w1:GetPos()) * 0.5 + w1:GetPos()

						local lpos, _ = WorldToLocal(middle, angle_zero, ent:GetPos(), ent:GetAngles())
					
						engineoffset = lpos
					end
				end

				-- not a glide vehicle, skip to defaults
				return engineoffset, angZero, defaultEngineMins, defaultEngineMaxs
			end
		},
	},
	["gtav_infernus"] = {
		{
			name = "engine",
			dmgmul = 1,
			penetration = 20,
			lpos = Vector(-65, 0, 5),
			lang = Angle(0, 0, 0),
			mins = Vector(-25, -35, -12),
			maxs = Vector(35, 35, 10)
		},
	},
	["gtav_dukes"] = {
		{
			name = "engine",
			dmgmul = 1,
			penetration = 20,
			lpos = Vector(65, 0, 0),
			lang = Angle(0, 0, 0),
			mins = Vector(-25, -35, -12),
			maxs = Vector(35, 35, 10)
		},
	},
}

hook.Add("Think", "jajaja", function()
	if hg_developer:GetBool() then
		for i, ent in pairs(ents.GetAll()) do
			if !ent:IsVehicle() then continue end
			
			local details = hg.GetVehicleDetails(ent)

			if details then
				for i, detail in pairs(details) do
					local lpos, lang, mins, maxs = detail.lpos, detail.lang, detail.mins, detail.maxs
					
					if detail.boxcalc then
						lpos, lang, mins, maxs = detail.boxcalc(ent)
					end

					if !lpos then continue end

					local pos, ang = LocalToWorld(lpos, lang, ent:GetPos(), ent:GetAngles())
										
					debugoverlay.BoxAngles(pos, mins, maxs, ang, 0.1, color_white)
				end
			end
		end
	end
end)

function hg.GetVehicleDetails(ent)
	return hg.vehicledetails[ent:GetClass()] or hg.vehicledetails["default"]
end

function hg.VehiclePenetration(ent, tr, bullet)
	local details = hg.GetVehicleDetails(ent)
	
	return hg.VehicleHitFunc(ent, tr, bullet, details)
end
