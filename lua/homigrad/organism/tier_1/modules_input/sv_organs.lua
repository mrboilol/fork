--local Organism = hg.organism
if SERVER then util.AddNetworkString("headtrauma_flash") end
-- Brain Chunks Logic (Ported from actually_brain_chunks_rework_check_desc_3673949172)
local GORE_CVARS = {
    scale = 0.9,
    life_span = 60,
    cleanup = true,
    visuals = true
}

local GORE_DECAL_REGISTRY = {}
local GORE_DECAL_PATH = "effects/droplets/"

for i = 2, 13 do
    local base = "drop" .. i
    local function register(name)
        if file.Exists("materials/" .. GORE_DECAL_PATH .. name .. ".vmt", "GAME") then
            local id = "Meat_" .. name
            game.AddDecal(id, GORE_DECAL_PATH .. name)
            table.insert(GORE_DECAL_REGISTRY, id)
        end
    end

    register(base)
    for j = 1, 5 do register(base .. "_" .. j) end
end

local CHUNKS_IN_WORLD = {}
local nextGoreThink = 0

local function CreateBrainChunk(origin, direction)
    if #CHUNKS_IN_WORLD >= 30 then return end

    local piece = ents.Create("prop_physics")
    if not IsValid(piece) then return end

    piece:SetModel("models/props_junk/watermelon01_chunk02c.mdl")
    piece:SetPos(origin)
    piece:SetAngles(AngleRand())
    piece:SetMaterial("models/flesh")
    piece:SetColor(Color(120, 0, 0))
    piece:DrawShadow(false)
    
    local baseScale = GORE_CVARS.scale
    piece:SetModelScale(math.Rand(baseScale * 0.9, baseScale * 1.35), 0)
    piece:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    piece:Spawn()

    piece:EmitSound("physics/flesh/flesh_squishy_impact_hard"..math.random(1,4)..".wav", 60, math.random(200, 255))

    piece.GoreState = {
        Sticking = false,
        SlideSpeed = 1,
        GravityMod = math.Rand(0.04, 0.07),
        Friction = math.Rand(0.00005, 0.00015)
    }

    local phys = piece:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMaterial("flesh")
        phys:SetVelocity(direction * 50 + VectorRand() * 20)
    end

    if GORE_CVARS.cleanup then 
        SafeRemoveEntityDelayed(piece, GORE_CVARS.life_span) 
    end
    table.insert(CHUNKS_IN_WORLD, piece)
end

hook.Add("Think", "BrainChunks_GoreSimProcessor", function()
    local curTime = CurTime()
    if curTime < nextGoreThink then return end
    nextGoreThink = curTime + 0.02
    local perfStart = HGPerf and HGPerf:Begin() or nil
    for i = #CHUNKS_IN_WORLD, 1, -1 do
        local ent = CHUNKS_IN_WORLD[i]
        if not IsValid(ent) then table.remove(CHUNKS_IN_WORLD, i) continue end

        local state = ent.GoreState
        if not state.Sticking then
            local trace = util.TraceLine({
                start = ent:GetPos(),
                endpos = ent:GetPos() + (ent:GetVelocity() * FrameTime() * 1.5),
                filter = ent
            })

            if trace.Hit and trace.HitWorld and not trace.HitSky then
                state.Sticking = true
                ent:SetMoveType(MOVETYPE_NONE)
                ent:SetPos(trace.HitPos + trace.HitNormal * 0.1)
                
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then 
                    state.ImpactDir = phys:GetVelocity():GetNormalized()
                    phys:EnableCollisions(false) 
                end

                if GORE_CVARS.visuals and #GORE_DECAL_REGISTRY > 0 then
                    util.Decal(table.Random(GORE_DECAL_REGISTRY), trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal, ent)
                end
            end
        else
            local moved, attached = false, true
            
            if state.GravityMod > 0.001 then
                local downPos = ent:GetPos() + Vector(0, 0, -state.GravityMod)
                if bit.band(util.PointContents(downPos), CONTENTS_SOLID) != CONTENTS_SOLID then
                    ent:SetPos(downPos)
                    moved = true
                else
                    attached = false
                end
                state.GravityMod = state.GravityMod - (state.Friction or 0)
            end

            if not attached and state.ImpactDir and state.SlideSpeed > 0.01 then
                local driftPos = ent:GetPos() + Vector(state.ImpactDir.x, state.ImpactDir.y, 0) * state.SlideSpeed
                if bit.band(util.PointContents(driftPos), CONTENTS_SOLID) != CONTENTS_SOLID then
                    ent:SetPos(driftPos)
                    moved = true
                end
                state.SlideSpeed = state.SlideSpeed - 0.02
            end

            if moved and GORE_CVARS.visuals and #GORE_DECAL_REGISTRY > 0 and (ent.NextDrip or 0) < curTime then
                util.Decal(table.Random(GORE_DECAL_REGISTRY), ent:GetPos() + Vector(0,0,2), ent:GetPos() - Vector(0,0,5), ent)
                ent.NextDrip = curTime + math.Rand(0.03, 0.08)
            end
        end
    end
    if HGPerf and perfStart then HGPerf:End("organs.brainchunks.think", perfStart) end
end)

local function isCrush(dmgInfo)
	return not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_SLASH + DMG_BLAST)
end
local abdominal_organs = {
    ["stomach"] = true,
    ["liver"] = true,
    ["intestines"] = true,
}

local organBulletBleedMultipliers = {
	heart = 2,
	liver = 1.75,
	stomach = 1.5,
	intestines = 1.5,
	brain = 1.25,
	trachea = 1.25,
}

local function damageOrgan(org, dmg, dmgInfo, key)
	local prot = math.max(0.3 - org[key],0)
	local oldval = org[key]
	local rawDamage = math.max(dmg * (isCrush(dmgInfo) and 1 or 3), 0)
	local alreadyDamaged = oldval > 0.01
	local organBulletBleedMul = organBulletBleedMultipliers[key] or 1.5

	-- A second hit on an already wounded abdominal organ should reopen the
	-- wound, not keep stacking the full organ-trauma package.  Its only
	-- organism effects are a small external bleed and a slight internal bleed.
	if alreadyDamaged and abdominal_organs[key] and rawDamage > 0 then
		local repeatBleed = math.min(rawDamage, 0.25)
		org.internalBleed = org.internalBleed + repeatBleed * 0.35

		if hg.organism.AddBulletImpactBleeding then
			hg.organism.AddBulletImpactBleeding(org, dmgInfo, 0.35)
		end

		dmgInfo:ScaleDamage(0.8)
		return 0
	end

	org[key] = math.Round(math.min(org[key] + rawDamage, 1), 3)
		local damage_dealt = org[key] - oldval

	-- Non-abdominal organs retain their existing repeat-trauma behavior.
	if alreadyDamaged and rawDamage > 0 then
		local repeatTrauma = math.min(rawDamage, 0.25)
		local abdominalMul = 0.5

		org.internalBleed = org.internalBleed + repeatTrauma * (1 + abdominalMul * 2.5)
		org.painadd = (org.painadd or 0) + repeatTrauma * (10 + abdominalMul * 15)
		org.stamina_damage = (org.stamina_damage or 0) + repeatTrauma * (5 + abdominalMul * 15)

		-- Progressive organ damage already adds bullet bleed below; only add the
		-- extra wound bleed once the organ damage meter has stopped increasing.
		if damage_dealt <= 0 and hg.organism.AddBulletImpactBleeding then
			hg.organism.AddBulletImpactBleeding(org, dmgInfo, organBulletBleedMul * 0.5)
		end
	end
	if damage_dealt > 0 then
		org.internalBleed = org.internalBleed + damage_dealt * 1.0 -- Base internal bleeding for any organ damage (increased from 0.5)
		org.stamina_damage = (org.stamina_damage or 0) + damage_dealt * 5 -- Base stamina loss
		if hg.organism.AddBulletImpactBleeding then
			hg.organism.AddBulletImpactBleeding(org, dmgInfo, organBulletBleedMul)
		end

		if abdominal_organs[key] then
			--local multiplier = (oldval >= 1) and 3.5 or 2.0 -- Extra penalty if already destroyed
			org.internalBleed = org.internalBleed + damage_dealt * 2.5 -- Increased from 1.5
			org.stamina_damage = (org.stamina_damage or 0) + damage_dealt * 25
			org.disorientation = (org.disorientation or 0) + damage_dealt * 1

			if not alreadyDamaged and org.analgesia < 0.4 and damage_dealt > 0.15 then
				timer.Simple(0, function()
					if IsValid(org.owner) then
						hg.StunPlayer(org.owner, 1.5)
					end
				end)
			end
		end
	end
	
	//local damage = org[key] - oldval
	//dmgInfo:SetDamage(dmgInfo:GetDamage() + (damage * 5))

	dmgInfo:ScaleDamage(0.8)

	return 0//isCrush(dmgInfo) and 0 or prot
end

local input_list = hg.organism.input_list
local hitArtery
input_list.heart = function(org, bone, dmg, dmgInfo)
	-- A heart hit may create its own internal/spine-artery consequence, but it
	-- must never be treated as a follow-on carotid (arteria) hit in this pass.
	org._spineArteryTraceDmgInfo = dmgInfo
	local oldDmg = org.heart

	local result = damageOrgan(org, dmg * 0.3, dmgInfo, "heart")
	local delta = org.heart - oldDmg

	hg.AddHarmToAttacker(dmgInfo, delta * 10, "Heart damage harm")
	
	org.shock = org.shock + dmg * 20
	org.painadd = org.painadd + dmg * 18
	org.internalBleed = org.internalBleed + delta * 10
	org.heartStrain = math.Clamp((org.heartStrain or 0) + delta * 1.4, 0, 1)
	if hg.organism.AddCardiacStress then hg.organism.AddCardiacStress(org, delta * (dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) and 2.4 or 1.2)) end
	if delta > 0.08 and dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_SLASH) and math.Rand(0, 1) < math.Clamp(delta * 1.8, 0, 0.75) and hg.organism.StartFibrillation then hg.organism.StartFibrillation(org) end

	return result
end

input_list.liver = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.liver
	local alreadyDamaged = oldDmg > 0.01
	local result = damageOrgan(org, dmg, dmgInfo, "liver")
	
	hg.AddHarmToAttacker(dmgInfo, (org.liver - oldDmg) * 3, "Liver damage harm")
	
	if not alreadyDamaged then
		org.shock = org.shock + dmg * 20
		org.painadd = org.painadd + dmg * 35
	end
	
	return result
end

input_list.stomach = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.stomach

	local result = damageOrgan(org, dmg, dmgInfo, "stomach")

	hg.AddHarmToAttacker(dmgInfo, (org.stomach - oldDmg) * 2, "Stomach damage harm")
	
	
	return result
end

input_list.intestines = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.intestines

	local result = damageOrgan(org, dmg, dmgInfo, "intestines")

	hg.AddHarmToAttacker(dmgInfo, (org.intestines - oldDmg) * 2, "Intestines damage harm")


	return result
end

local brainLobeProfiles = {
	brainFrontal = {brain = 0.8, consciousness = 1.2, disorientation = 1.5, shock = 2, pain = 7, hemorrhage = 0.6},
	brainParietal = {brain = 0.7, consciousness = 1.4, disorientation = 2.2, shock = 2.5, pain = 8, hemorrhage = 0.7},
	brainTemporal = {brain = 0.9, consciousness = 1.1, disorientation = 1.3, shock = 2.5, pain = 8, hemorrhage = 0.9},
	brainOccipital = {brain = 0.75, consciousness = 1.3, disorientation = 1.1, shock = 2, pain = 7, hemorrhage = 0.75}
}

local brainLobeKeys = {
	"brainFrontal",
	"brainParietal",
	"brainTemporal",
	"brainOccipital",
}

local function isBluntBrainDamage(dmgInfo)
	return dmgInfo:IsDamageType(DMG_CLUB + DMG_CRUSH + DMG_FALL + DMG_VEHICLE)
end

local function getBrainLobeDamage(org)
	return math.min(org.brainFrontal or 0, 0.2) + math.min(org.brainParietal or 0, 0.2) + math.min(org.brainTemporal or 0, 0.2) + math.min(org.brainOccipital or 0, 0.2)
end

local function addBrainHemorrhage(org, amount, rate)
	-- Zerlkers does not erase a cerebral bleed, but it substantially slows the
	-- initial secondary response so a treated patient has a real survival window.
	local resistance = hg.organism.GetZerlkersResistance and hg.organism.GetZerlkersResistance(org) or 0
	local progression = 1 - resistance * 0.55
	local baseAmount = amount or 0
	amount = baseAmount * progression
	rate = (rate or baseAmount * 0.0015) * progression
	org.brainHemorrhage = math.min((org.brainHemorrhage or 0) + amount, 1)
	-- Keep the initial rate small.  The secondary progression code scales danger
	-- from cranial damage, so a 0.1-like display value cannot erase the brain in
	-- a few seconds while an open skull remains a rapidly worsening emergency.
	org.brainBleedRate = math.min((org.brainBleedRate or 0) + rate, 0.0035)
end

hg.organism.AddBrainHemorrhage = addBrainHemorrhage

local defaultBrainTraumaProfile = {
	consciousness = 1.8,
	disorientation = 3,
	shock = 3,
	pain = 8,
	hemorrhage = 0.8,
}

local brain_concussion_per_damage = 112.5 -- 0.02 brain damage = 2.25 concussion

local function applyHeadTraumaDizziness(org, dmgInfo, impactDamage, brainDamage)
	impactDamage = math.max(impactDamage or 0, 0)
	brainDamage = math.max(brainDamage or 0, 0)
	if impactDamage <= 0 and brainDamage <= 0 then return 0 end

	local penetrating = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
	local traumatic = dmgInfo:IsDamageType(DMG_CLUB + DMG_BLAST + DMG_CRUSH + DMG_FALL + DMG_VEHICLE)
	if not penetrating and not traumatic then return 0 end

	-- A skull strike can briefly throw off balance, while damage to brain tissue
	-- makes the same reaction both substantially more likely and more severe.
	local resistance = hg.organism.GetZerlkersResistance and hg.organism.GetZerlkersResistance(org) or 0
	local traumaResponse = 1 - resistance * 0.65
	local chance = math.Clamp((0.08 + impactDamage * 0.45 + brainDamage * 6) * traumaResponse, 0.08, 0.95)
	if math.Rand(0, 1) > chance then return 0 end

	local dizziness = math.Clamp((math.Rand(0.3, 0.75) + impactDamage * 0.8 + brainDamage * 12) * traumaResponse, 0, 5)
	org.disorientation = math.min((org.disorientation or 0) + dizziness, 10)
	return dizziness
end

hg.organism.ApplyHeadTraumaDizziness = applyHeadTraumaDizziness

local function applyBrainTraumaEffects(org, delta, dmgInfo, profile)
	if delta <= 0 then return end
	profile = profile or defaultBrainTraumaProfile
	local resistance = hg.organism.GetZerlkersResistance and hg.organism.GetZerlkersResistance(org) or 0
	local traumaResponse = 1 - resistance * 0.65

	org.concussion = math.min((org.concussion or 0) + math.min(delta * brain_concussion_per_damage, 4) * traumaResponse, 10)
	org.consciousness = math.Approach(org.consciousness or 1, 0, delta * profile.consciousness * 1.6 * traumaResponse)
	org.disorientation = (org.disorientation or 0) + delta * profile.disorientation * 1.5 * traumaResponse
	org.shock = (org.shock or 0) + delta * profile.shock * 5 * traumaResponse
	org.painadd = (org.painadd or 0) + delta * profile.pain
	applyHeadTraumaDizziness(org, dmgInfo, 0, delta)

	local penetrating = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
	local impact = dmgInfo:IsDamageType(DMG_CLUB + DMG_BLAST + DMG_CRUSH + DMG_FALL)
	local hemorrhageScale = profile.hemorrhage or 0.8
	local hemorrhageChance = penetrating and math.Clamp(0.4 + delta * 2, 0, 0.98)
		or impact and math.Clamp(0.12 + delta * hemorrhageScale * 1.5, 0, 0.8)
		or math.Clamp(0.04 + delta * hemorrhageScale, 0, 0.5)

	if math.Rand(0, 1) <= hemorrhageChance then
		addBrainHemorrhage(org, delta * hemorrhageScale * 1.25, delta * (penetrating and 0.0035 or 0.0015))
	end
end

hg.organism.ApplyBrainTraumaEffects = applyBrainTraumaEffects

local function damageBrainLobe(org, bone, dmg, dmgInfo, key)
	local profile = brainLobeProfiles[key]
	if not profile then return 0 end
	if dmgInfo:IsDamageType(DMG_BLAST) then dmg = dmg / 50 end

	local oldBrainLobeDamage = getBrainLobeDamage(org)
	local oldDmg = org[key] or 0
	local result = damageOrgan(org, dmg, dmgInfo, key)
	local delta = (org[key] or 0) - oldDmg

	org.brain = math.min((org.brain or 0) + (getBrainLobeDamage(org) - oldBrainLobeDamage) * 1.5, 1)
	org.consciousness = math.Approach(org.consciousness, 0, delta * profile.consciousness)
	org.disorientation = org.disorientation + delta * profile.disorientation
	org.shock = org.shock + dmg * profile.shock
	org.painadd = org.painadd + dmg * profile.pain
	applyHeadTraumaDizziness(org, dmgInfo, 0, delta)

	hg.AddHarmToAttacker(dmgInfo, delta * 15, key .. " damage harm")

	if key == "brainTemporal" and delta > 0.02 and math.random(2) == 1 and IsValid(org.owner) and org.owner.AddTinnitus then
		org.owner:AddTinnitus(math.Clamp(delta * 35, 1.5, 12), true)
	end

	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then
		local dmgPos = dmgInfo:GetDamagePosition()
		local dirCool = dmgInfo:GetDamageForce():GetNormalized()
		-- Bullet impacts already route through hg_bloodimpact, which renders the
		-- small physical blood pellets. Do not layer the red vanilla BloodImpact
		-- particles over that same hit.

		local ent = hg.GetCurrentCharacter(org.owner)
		if IsValid(ent) and ent.organism and not ent.organism.SpawnedBrainChunks and math.random(5) == 1 then
			SpawnMeatGore(ent, dmgPos + dirCool * 5, 3, dirCool * 1000, 0.4)
			ent.organism.SpawnedBrainChunks = true
		end
	end

	if org.brain >= 0.01 and delta > 0.01 and math.random(3) == 1 then
		org.shock = 70
	end

	return result
end

local function applyBluntBrainTrauma(org, amount, dmgInfo, regionalChance)
	amount = math.max(amount or 0, 0)
	if amount <= 0 then return 0 end

	if math.Rand(0, 1) <= (regionalChance or 0.5) then
		local key = brainLobeKeys[math.random(#brainLobeKeys)]
		local oldLobeDamage = getBrainLobeDamage(org)
		local oldDmg = org[key] or 0
		org[key] = math.min(oldDmg + amount, 1)
		local delta = (org[key] or 0) - oldDmg

		org.brain = math.min((org.brain or 0) + getBrainLobeDamage(org) - oldLobeDamage, 1)
		applyBrainTraumaEffects(org, delta, dmgInfo, brainLobeProfiles[key])

		if key == "brainTemporal" and delta > 0.02 and math.random(2) == 1 and IsValid(org.owner) and org.owner.AddTinnitus then
			org.owner:AddTinnitus(math.Clamp(delta * 35, 1.5, 12), true)
		end

		return delta
	end

	local oldDmg = org.brain or 0
	org.brain = math.min(oldDmg + amount, 1)
	local delta = (org.brain or 0) - oldDmg
	applyBrainTraumaEffects(org, delta, dmgInfo)
	return delta
end

hg.organism.ApplyBluntBrainTrauma = applyBluntBrainTrauma

input_list.brainFrontal = function(org, bone, dmg, dmgInfo) return damageBrainLobe(org, bone, dmg, dmgInfo, "brainFrontal") end
input_list.brainParietal = function(org, bone, dmg, dmgInfo) return damageBrainLobe(org, bone, dmg, dmgInfo, "brainParietal") end
input_list.brainTemporal = function(org, bone, dmg, dmgInfo) return damageBrainLobe(org, bone, dmg, dmgInfo, "brainTemporal") end
input_list.brainOccipital = function(org, bone, dmg, dmgInfo) return damageBrainLobe(org, bone, dmg, dmgInfo, "brainOccipital") end
input_list.brain = function(org, bone, dmg, dmgInfo)
	if isBluntBrainDamage(dmgInfo) and math.random(2) == 1 then
		local key = brainLobeKeys[math.random(#brainLobeKeys)]
		return damageBrainLobe(org, bone, dmg, dmgInfo, key)
	end

	if dmgInfo:IsDamageType(DMG_BLAST) then dmg = dmg / 50 end

	local oldDmg = org.brain or 0
	local result = damageOrgan(org, dmg, dmgInfo, "brain")
	local delta = math.max((org.brain or 0) - oldDmg, 0)
	if delta > 0 then
		applyBrainTraumaEffects(org, delta, dmgInfo)
		hg.AddHarmToAttacker(dmgInfo, delta * 15, "Brain damage harm")
	end

	return result
end

local brainLobes = {
	brainFrontal = true,
	brainParietal = true,
	brainTemporal = true,
	brainOccipital = true,
	brain = true
}

hook.Add("PreTraceOrganBulletDamage", "hg_skull_melee_penetration", function(org, bone, dmg, dmgInfo, box, dir, hit, ricochet, organ, hook_info)
	if not organ or not hook_info then return end
	if not brainLobes[organ[1]] then return end
	if not dmgInfo:IsDamageType(DMG_SLASH + DMG_CLUB) then return end

	local skull = org.skull or 0
	if skull >= 1 then return end

	local chance = math.Clamp(0.04 + skull * 0.18 + dmg * 0.025, 0, 0.28)
	if math.Rand(0, 1) > chance then hook_info.restricted = true end
end)

hook.Add("HomigradDamage", "BrainHemorrhageTrauma", function(ply, dmgInfo, hitgroup)
	local org = ply.organism
	if not org or hitgroup ~= HITGROUP_HEAD or not org.skull then return end
	if org.skull < 0.7 then return end

	local chance = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) and 0.45 or dmgInfo:IsDamageType(DMG_CLUB + DMG_BLAST + DMG_CRUSH) and 0.22 or 0
	chance = chance + math.max(org.skull - 0.7, 0) * 0.55
	if math.Rand(0, 1) <= chance then
		addBrainHemorrhage(org, math.Rand(0.03, 0.09), math.Rand(0.0005, 0.0018))
	end
end)

local angZero = Angle(0, 0, 0)
local vecZero = Vector(0, 0, 0)
local function getlocalshit(ent, bone, dmgInfo, dir, hit)
	if IsValid(ent) and bone then
		local ent = IsValid(ent.FakeRagdoll) and ent.FakeRagdoll or ent
		local bonePos, boneAng = ent:GetBonePosition(bone)
		local dmgPos = not isbool(hit) and hit or bonePos
		
		local localPos, localAng = WorldToLocal(dmgPos, angZero, bonePos, boneAng)
		local _, dir2 = WorldToLocal(vecZero, dir:Angle(), vecZero, boneAng)
		dir2 = dir2:Forward()
		return localPos, localAng, dir2
	end
end

local arterySize = {
	["arteria"] = 14,
	["rarmartery"] = 6,
	["larmartery"] = 6,
	["rlegartery"] = 9,
	["llegartery"] = 9,
	["spineartery"] = 10,
}

local o2DebuffArteries = {
	["arteria"] = true,
	["spineartery"] = true,
}

local arteryMessages ={
	"I can feel blood rushing from my neck...",
	"My neck.. it's... pumping out blood.",
	"I'm bleeding out of my neck!"
}

-- A carotid puncture and a deliberate throat cut share the arterial wound,
-- but the latter also damages the airway and immediately compromises cerebral
-- delivery.  The Vottur mechanics are kept as a separate state so treatment
-- can stop the bleeding without pretending the airway was never cut.
local applyThroatCutEffects

local slashToArtery = {
	["rarmup"] = "rarmartery",
	["rarmdown"] = "rarmartery",
	["larmup"] = "larmartery",
	["larmdown"] = "larmartery",
	["rlegup"] = "rlegartery",
	["rlegdown"] = "rlegartery",
	["llegup"] = "llegartery",
	["llegdown"] = "llegartery",
}

local function getMeleeArteryChance(dmg, dmgInfo)
	local inflictor = dmgInfo:GetInflictor()
	local chanceMul = IsValid(inflictor) and (inflictor.ArteryChance or 1) or 1
	local strikeDamage = math.max(dmgInfo:GetDamage() or 0, dmg or 0)

	-- Light cuts can nick an artery, while committed high-damage swings are
	-- substantially more likely to tear one without becoming guaranteed.
	return math.Clamp(math.Clamp(strikeDamage / 40, 0.1, 0.8) * chanceMul, 0.1, 0.8)
end

local arteryHitgroups = {
	rarmartery = HITGROUP_RIGHTARM,
	larmartery = HITGROUP_LEFTARM,
	rlegartery = HITGROUP_RIGHTLEG,
	llegartery = HITGROUP_LEFTLEG,
}

hitArtery = function(artery, org, dmg, dmgInfo, boneindex, dir, hit, skipThroatCutTracheaDamage)
	if isCrush(dmgInfo) then return 1 end
	if dmgInfo:IsDamageType(DMG_BLAST) then return 1 end
	-- The spine-artery debug box is a non-injuring trace marker.  A shot that
	-- reached it must not turn into a separate carotid hit farther along the
	-- same damage trace.
	if artery == "arteria" and org._spineArteryTraceDmgInfo == dmgInfo then return 0 end

	local requiredHitgroup = arteryHitgroups[artery]
	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
		and requiredHitgroup
		and org._bulletImpactHitgroup
		and requiredHitgroup ~= org._bulletImpactHitgroup then
		return 0
	end
	org.painadd = org.painadd + dmg * 1
	
	-- Central arterial wounds impair oxygen delivery while they are open.
	if o2DebuffArteries[artery] then
		org.arterialO2Drain = true
	end
	if artery == "arteria" then
		org.arteriaO2Drain = true
	end
	
	if org[artery] == 1 then return 0 end
	if org[string.Replace(artery, "artery", "").."amputated"] then return end
	local owner = org.owner

	if artery ~= "arteria" then
		hg.AddHarmToAttacker(dmgInfo, 4, "Random artery punctured harm")//((1 - org[artery]) - math.max((1 - org[artery]) - dmg,0)) / 4
	else
		if org.isPly and not org.otrub then
			org.owner:Notify(table.Random(arteryMessages), true, "arteria", 0)
		end
		
		hg.AddHarmToAttacker(dmgInfo, 15, "Carotid artery punctured harm")
		org.neckslit = true
		org.needfake = true
		
		local ent = hg.GetCurrentCharacter(owner)
		if IsValid(ent) and not org.otrub and not org.needotrub and (owner:IsPlayer() and owner:Alive() or not owner:IsPlayer()) then
			ent:EmitSound("neckslit.ogg", 70, 100, 1, CHAN_AUTO)
		end
		
		local snd = (ThatPlyIsFemale and ThatPlyIsFemale(owner)) and "femaleneck.mp3" or "maleneck.mp3"
		timer.Simple(0, function()
			if IsValid(owner) then
				if owner:IsPlayer() and owner:Alive() then
					hg.Fake(owner, nil, true, true)
				end
				local rag = hg.GetCurrentCharacter(owner)
				if IsValid(rag) and not org.otrub and not org.needotrub and (owner:IsPlayer() and owner:Alive() or not owner:IsPlayer()) then
					rag:EmitSound(snd, 70, 100, 1, CHAN_VOICE)
					org.neckslitSoundName = snd
					org.neckslitSoundEnt = rag
				end
			end
		end)
	end

	org[artery] = math.min(org[artery] + 1, 1)

	local bonea = owner:LookupBone(boneindex)
	local localPos, localAng, dir2 = getlocalshit(owner, bonea, dmgInfo, dir, hit)
	
	-- Store local position relative to bone so it follows organism movement
	table.insert(org.arterialwounds, {arterySize[artery], localPos, localAng, boneindex, CurTime(), (dir2 or Vector(0,0,1)) * 5, artery, false}) -- false = local position
	if hg.AddOrganismBloodDecal then hg.AddOrganismBloodDecal(owner) end
	hg.organism.SyncWounds(org)
	if artery == "arteria" and dmgInfo:IsDamageType(DMG_SLASH) and applyThroatCutEffects then
		applyThroatCutEffects(owner, org, dmgInfo, math.Clamp(dmg / 4, 0.65, 1.15), skipThroatCutTracheaDamage)
	end

	--if IsValid(owner:GetNWEntity("RagdollDeath")) then owner:GetNWEntity("RagdollDeath"):SetNetVar("wounds",org.arterialwounds) end
	return 0
end
hg.hitArtery = hitArtery

applyThroatCutEffects = function(owner, org, dmgInfo, severity, skipTracheaDamage)
	if not IsValid(owner) or not org or not org.alive or org.superfighter then return false end

	local firstCut = not org.throatcut
	local time = CurTime()
	severity = math.Clamp(tonumber(severity) or 1, 0.35, 1.25)
	for _, wound in pairs(org.arterialwounds or {}) do
		if wound[7] == "arteria" then
			wound[1] = math.max(wound[1] or 0, 24 * severity)
			wound[5] = math.min(wound[5] or time, time - 1)
		end
	end

	if not skipTracheaDamage then
		local oldTrachea = org.trachea or 0
		org.trachea = math.min(math.max(oldTrachea, 0.72 * severity), 1)
		hg.AddHarmToAttacker(dmgInfo, math.max(org.trachea - oldTrachea, 0) * 12, "Throat cut trachea harm")
	end
	org.throatcut = true
	org.throatCutTime = org.throatCutTime and org.throatCutTime > 0 and org.throatCutTime or time
	org.throatCutUntil = time + 24
	org.throatCutSeverity = math.max(org.throatCutSeverity or 0, severity)
	org.throatCutPressureShock = org.throatCutPressureShock or 0
	org.neckBrainOxygenPenalty = org.neckBrainOxygenPenalty or 0
	org.shock = math.min(math.max(org.shock or 0, 40 * severity), 90)
	org.fearadd = (org.fearadd or 0) + 1.5 * severity

	if firstCut then
		for i = 1, 3 do
			hg.organism.AddWoundManual(owner, 45 * severity, VectorRand(-1.5, 1.5), Angle(90, 0, 0), "ValveBiped.Bip01_Neck1", time + math.Rand(0, 0.25))
		end
		if org.isPly and not org.otrub and owner.Notify then
			owner:Notify("My throat is open... I can't breathe...", true, "throatcut", 0)
		end
	end

	owner:SetNWFloat("HG_ThroatCutUntil", org.throatCutUntil)
	hg.organism.SyncWounds(org)
	hook.Run("HG_ThroatCut", owner, org, dmgInfo, severity)
	return true
end

function hg.organism.CutThroat(ent, dmgInfo, hitPos, dir, severity)
	local owner = hg.RagdollOwner and hg.RagdollOwner(ent) or ent
	if not IsValid(owner) or not owner.organism or not owner.organism.alive then return false end
	local org = owner.organism
	if org.superfighter then return false end

	local character = hg.GetCurrentCharacter and hg.GetCurrentCharacter(owner) or owner
	if not IsValid(character) or not character.LookupBone then character = owner end
	local neckBone = character:LookupBone("ValveBiped.Bip01_Neck1") or character:LookupBone("ValveBiped.Bip01_Head1")
	if not neckBone then return false end
	local bonePos, boneAng = character:GetBonePosition(neckBone)
	if not bonePos then return false end

	severity = math.Clamp(tonumber(severity) or 1, 0.35, 1.25)
	dmgInfo = dmgInfo or DamageInfo()
	dmgInfo:SetDamageType(DMG_SLASH)
	local cutPos = isvector(hitPos) and hitPos or (bonePos + boneAng:Forward() * 2 - boneAng:Right())
	local cutDir = isvector(dir) and dir:GetNormalized() or -boneAng:Forward()
	hitArtery("arteria", org, 6 * severity, dmgInfo, "ValveBiped.Bip01_Neck1", cutDir, cutPos)
	return org.throatcut or applyThroatCutEffects(owner, org, dmgInfo, severity)
end

hook.Add("PreTraceOrganBulletDamage", "hg_melee_artery_hit", function(org, bone, dmg, dmgInfo, box, dir, hit, ricochet, organ)
	if not dmgInfo:IsDamageType(DMG_SLASH) then return end

	local artery = organ and slashToArtery[organ[1]]
	if not artery then return end
	if math.Rand(0, 1) > getMeleeArteryChance(dmg, dmgInfo) then return end

	hitArtery(artery, org, dmg, dmgInfo, box[6], dir, hit)
end)

input_list.arteria = function(org, bone, dmg, dmgInfo, boneindex, dir, hit, skipThroatCutTracheaDamage)
	return hitArtery("arteria", org, dmg, dmgInfo, "ValveBiped.Bip01_Neck1", dir, hit, skipThroatCutTracheaDamage)
end

input_list.rarmartery = function(org, bone, dmg, dmgInfo, boneindex, dir, hit) return hitArtery("rarmartery", org, dmg, dmgInfo, boneindex, dir, hit) end
input_list.larmartery = function(org, bone, dmg, dmgInfo, boneindex, dir, hit) return hitArtery("larmartery", org, dmg, dmgInfo, boneindex, dir, hit) end
input_list.rlegartery = function(org, bone, dmg, dmgInfo, boneindex, dir, hit) return hitArtery("rlegartery", org, dmg, dmgInfo, boneindex, dir, hit) end
input_list.llegartery = function(org, bone, dmg, dmgInfo, boneindex, dir, hit) return hitArtery("llegartery", org, dmg, dmgInfo, boneindex, dir, hit) end
input_list.spineartery = function(org, bone, dmg, dmgInfo, boneindex, dir, hit) return hitArtery("spineartery", org, dmg, dmgInfo, boneindex, dir, hit) end
input_list.eyeL = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.eyeL or 0
	dmg = dmg * 0.75
	org.eyeL = math.min((org.eyeL or 0) + dmg, 1)

	hg.AddHarmToAttacker(dmgInfo, dmg * 5, "Left eye damage harm")
	org.painadd = org.painadd + dmg * 20
	org.shock = org.shock + dmg * 10
	
	dmgInfo:ScaleDamage(0.8)
	return 0
end

input_list.eyeR = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.eyeR or 0
	dmg = dmg * 0.75
	org.eyeR = math.min((org.eyeR or 0) + dmg, 1)

	hg.AddHarmToAttacker(dmgInfo, dmg * 5, "Right eye damage harm")
	org.painadd = org.painadd + dmg * 20
	org.shock = org.shock + dmg * 10
	
	dmgInfo:ScaleDamage(0.8)
	return 0
end

input_list.lungsL = function(org, bone, dmg, dmgInfo)
	local prot = math.max(0.3 - org.lungsL[1],0)
	local oldval = org.lungsL[1]

	hg.AddHarmToAttacker(dmgInfo, (dmg * 0.25), "Lung left damage harm")

	org.lungsL[1] = math.min(org.lungsL[1] + dmg / 4, 1)
	if (dmgInfo:IsDamageType(DMG_BULLET+DMG_SLASH+DMG_BUCKSHOT)) or (math.random(3) == 1) then org.lungsL[2] = math.min(org.lungsL[2] + dmg * 1, 1) end

	org.internalBleed = org.internalBleed + (org.lungsL[1] - oldval) * 2

	-- Expel air when lung is hit
	if org.o2 and org.o2[1] then
		org.o2[1] = math.max(org.o2[1] - math.min(dmg * 2, 5), 15) -- Cap at -5 O2 per hit, minimum 15 overall
	end

	dmgInfo:ScaleDamage(0.8)

	return 0//isCrush(dmgInfo) and 1 or prot
end

input_list.lungsR = function(org, bone, dmg, dmgInfo)
	local oldval = org.lungsR[1]

	hg.AddHarmToAttacker(dmgInfo, (dmg * 0.25), "Lung right damage harm")

	org.lungsR[1] = math.min(org.lungsR[1] + dmg / 4, 1)
	if (dmgInfo:IsDamageType(DMG_BULLET+DMG_SLASH+DMG_BUCKSHOT)) or (math.random(3) == 1) then org.lungsR[2] = math.min(org.lungsR[2] + dmg * 1, 1) end

	org.internalBleed = org.internalBleed + (org.lungsR[1] - oldval) * 2

	-- Expel air when lung is hit
	if org.o2 and org.o2[1] then
		org.o2[1] = math.max(org.o2[1] - math.min(dmg * 2, 5), 15) -- Cap at -5 O2 per hit, minimum 15 overall
	end

	dmgInfo:ScaleDamage(0.8)

	return 0//isCrush(dmgInfo) and 1 or prot
end

input_list.trachea = function(org, bone, dmg, dmgInfo)
	local oldDmg = org.trachea

    dmg = dmg * 0.05 -- 95% resistance; the airway is no longer excessively delicate

    if isCrush(dmgInfo) then
        if math.random() < 0.5 then
            return 0
        else
            dmg = dmg * 10
        end
    end

	if dmgInfo:IsDamageType(DMG_BLAST) then dmg = dmg / 5 end

	local result = damageOrgan(org, dmg * 2, dmgInfo, "trachea")

	hg.AddHarmToAttacker(dmgInfo, (org.trachea - oldDmg) * 8, "Trachea damage harm")

	org.internalBleed = org.internalBleed + dmg * 2

	return result
end
