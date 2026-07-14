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
local instant_pain_shock_scale = 0.75
local attacker_adrenaline_gain_window = 2
local attacker_adrenaline_cooldown = 5
local attacker_adrenaline_cap = 1.5
local player_limb_gib_threshold = 160
local player_head_gib_threshold = 175
local bonetohitgroup, hitgrouptolimb

function hg.organism.AddBulletImpactBleeding(org, dmgInfo, multiplier)
	if not org or not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then return end

	local rawDamage = math.max(dmgInfo:GetDamage(), 0)
	org._bulletImpactBleedAdd = (org._bulletImpactBleedAdd or 0) + rawDamage * 0.02 * (multiplier or 1)
end
local ragdoll_fall_skull_damage_mul = 1.2
local ragdoll_fall_jaw_damage_mul = 0.45
local ragdoll_fall_skull_break_blood_mul = 1.15
local function Trace_Bullet(box, hit, ricochet, org, organs, dmg, dmgInfo, dir)
	dmg = dmgInfo:GetDamage() / 25
	local organ = box[6] and organs[box[6]][box[7]]
	if not organ then return 0 end
	local name = organ[1]
	if not name then return 0 end
	if org.superfighter and not (string.find(name,"vest") or string.find(name,"helmet")) then return 0 end
	local bone = organ[2] or 0
	local func = input_list[name]
	local hook_info = {
		restricted = false,
		dmg = dmg,
	}
	
	hook_Run("PreTraceOrganBulletDamage", org, bone, dmg, dmgInfo, box, dir, hit, ricochet, organ, hook_info)
	
	dmg = hook_info.dmg
	
	

    if func and !hook_info.restricted then
        local old_consciousness = org.consciousness
        local result = func(org, bone, dmg, dmgInfo, box[6], dir, hit, ricochet)

        return result
    else
        return 0
    end
end

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

local RagdollDamageBoneMul = {
	[HITGROUP_LEFTLEG] = 0.25,
	[HITGROUP_RIGHTLEG] = 0.25,
	[HITGROUP_GENERIC] = 1,
	[HITGROUP_LEFTARM] = 0.25,
	[HITGROUP_RIGHTARM] = 0.25,
	[HITGROUP_CHEST] = 1,
	[HITGROUP_STOMACH] = 1,
	[HITGROUP_HEAD] = 2
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
	["ValveBiped.Bip01_Pelvis"] = HITGROUP_CHEST,
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
	Sound("player/zombie_head_explode_01.wav"),
	Sound("player/zombie_head_explode_02.wav"),
	Sound("player/zombie_head_explode_03.wav"),
	Sound("player/zombie_head_explode_04.wav"),
	Sound("player/zombie_head_explode_05.wav"),
	Sound("player/zombie_head_explode_06.wav")
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
	local len = org.owner:BoneLength(org.owner:LookupBone(bone))
	local vec = Vector(len, 0, 0)
	local ang = Angle()
	local boneup = org.owner:GetBoneName(org.owner:LookupBone(bone) - 1)
	
	local wnds = {}

	for i, tbl in pairs(org.arterialwounds) do
		if tbl[7] != limb.."artery" then
			table.insert(wnds, tbl)
		end
	end
	table.insert(wnds, {10, vec, ang, boneup, CurTime(), Vector(-100, 0, 0), bone.."artery"})
	
	org.arterialwounds = wnds
	hg.organism.SyncWounds(org)

	org[limb.."amputated"] = true

	-- Track that this limb was previously amputated for stable healing approach
	org.owner.HG_PreviouslyAmputated = org.owner.HG_PreviouslyAmputated or {}
	org.owner.HG_PreviouslyAmputated[limb] = true

	for i = 1, 5 do
		hg.organism.AddWoundManual(org.owner, 50, vec + VectorRand(-2, 2), ang, boneup, CurTime() + math.Rand(0, 2))
	end

	local dmgInfo = DamageInfo()
	hg.organism.input_list[limb.."up"](org, 0, 5, dmgInfo)

	org.owner:EmitSound(sounds[math.random(#sounds)], 70, math.random(95, 105), 2)



	
	local ent = hg.GetCurrentCharacter(org.owner)
	SpawnMeatGore(ent, select(1, ent:GetBonePosition(ent:LookupBone(bone))), 4)

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
		org.owner:EmitSound("physics/flesh/flesh_impact_hard6.wav", 65)
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
	org.painadd = (org.painadd or 0) + math.Clamp(harm * 0.2, NOSEBLEED_PAIN_MIN, NOSEBLEED_PAIN_MAX)
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
	["npc_headcrab"] = "models/nova/w_headcrab.mdl",
	["npc_headcrab_fast"] = "models/headcrab.mdl",
	["npc_headcrab_black"] = "models/headcrabblack.mdl",
}

local hg_norespawn = ConVarExists("hg_norespawn") and GetConVar("hg_norespawn") or CreateConVar("hg_norespawn",0,FCVAR_SERVER_CAN_EXECUTE,"Disable respawns in any gamemode (useful for hg_sync)",0,1)

hook.Add("PlayerDeathThink","stoprespawning",function()
	if hg_norespawn:GetBool() then return true end
end)

hook.Add("PlayerSpawn", "hg_forsaken_deathscene_reset", function(ply)
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

hook.Add("PlayerDeath", "hg_forsaken_deathscene", function(victim)
	local org = victim.organism

	-- Forsaken now represents every real death, not only a recent brain-damage burst.
	net.Start("hg_forsaken_deathscene")
	net.Send(victim)

	if not org then return end

	org.brainBurstDamage = 0
	org.brainBurstWindowStart = 0
	org.brainBurstLast = 0

	if (math.Round(victim:GetInfoNum("hg_deathfadeout", 1)) == 1) and (org.skull >= 0.6 or org.jaw == 1) then
		victim:SetNWString("PlayerName", "disfigured nigga")
		local rag = IsValid(victim:GetNWEntity("RagdollDeath")) and victim:GetNWEntity("RagdollDeath") or victim.FakeRagdoll
		if IsValid(rag) then rag:SetNWString("PlayerName", "disfigured nigga") end
	end
end)

--util.AddNetworkString("tracePosesSend")
--util.AddNetworkString("wound_debug")
util.AddNetworkString("hg_bloodimpact")
--util.AddNetworkString("blood particle explode")
util.AddNetworkString("bloodsquirt")
util.AddNetworkString("hg_brainmist")
util.AddNetworkString("hg_forsaken_deathscene")


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

	ply.harm = ply.harm + harm
end

function hg.ExplodeHead(ent)
	if !IsValid(ent) then return end

	local ply = ent:IsRagdoll() and hg.RagdollOwner(ent) or ent
	if ply:IsPlayer() and ply:Alive() then ply:Kill() end
	if ent:IsNPC() and ent.organism then ent.organism.shock = 100 end
	local target = ent

	timer.Simple(0, function()
		if not IsValid(target) then return end

		local ent = target:IsRagdoll() and target or target:GetNWEntity("RagdollDeath")
		if not IsValid(ent) then return end
		--[[if not isbool(ent) then
			hook.Run("OnHeadExplode", ply, ent)
		end]]

		Gib_Input(ent, ent:LookupBone("ValveBiped.Bip01_Head1"))
		hook.Run("HG_HeadExploded", ent, ply)

		-- Remove neck floppy constraints when head is amputated
		if IsValid(ent) then
			if ent.FloppyConstraints then
				local neckCons = ent.FloppyConstraints.neck
				if IsValid(neckCons) then neckCons:Remove() end
				ent.FloppyConstraints.neck = nil
			end
			local neckBoneId = ent:LookupBone("ValveBiped.Bip01_Neck1")
			if neckBoneId then
				ent:ManipulateBonePosition(neckBoneId, vector_origin)
				ent:ManipulateBoneAngles(neckBoneId, angle_zero)
			end
		end
		
		ent.organism.headamputated = true
		ent.headexploded = true

		-- Track that head was previously amputated for stable healing approach
		ent.organism.owner.HG_PreviouslyAmputated = ent.organism.owner.HG_PreviouslyAmputated or {}
		ent.organism.owner.HG_PreviouslyAmputated["head"] = true

		ent.organism.owner.fullsend = true
		hg.send_bareinfo(ent.organism)
	end)
end

local hg_bloodimpacts = ConVarExists("hg_bloodimpacts") and GetConVar("hg_bloodimpacts") or CreateConVar("hg_bloodimpacts", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable custom blood impact effects spray cool kill death", 0, 1)

local net, math, hg, IsValid = net, math, hg, IsValid
local takeRagdollDamage

-- Rapid-fire damage can arrive several times inside one server tick.  Keep the
-- entry and exit streams separate, but coalesce each stream without replacing
-- its pending timer or losing the accumulated impact count.
local function queueBulletBloodImpact(ent, stream, pos, velocity, damage)
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

	-- Glass damage to ragdoll...
	if IsValid(ent) and string.find(ent:GetClass(),"break") and 
		ent:GetBrushSurfaces() and ent:GetBrushSurfaces()[1] and string.find(ent:GetBrushSurfaces()[1]:GetMaterial():GetName(),"glass") and 
		IsValid(dmgInfo:GetInflictor()) and dmgInfo:GetInflictor() == dmgInfo:GetAttacker() and dmgInfo:GetInflictor().organism then
			--hg.organism.AddWoundManual(dmgInfo:GetInflictor(),math.random(15,25),vector_origin,angle_zero,math.random(0,ent:GetBoneCount()),CurTime()) 
	end
	
	if ent:GetClass() == "npc_bullseye" then
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

	local inflictorClass = IsValid(inf) and inf:GetClass() or ""
	local inflictorBase = IsValid(inf) and inf.Base or ""
	local isClubMelee = dmgInfo:IsDamageType(DMG_CLUB) and (inflictorBase == "weapon_melee" or inflictorClass == "weapon_melee")
	if isClubMelee then
		dmgInfo:ScaleDamage(1.65)
	end

	local isMeleeDmg = dmgInfo:IsDamageType(DMG_CLUB + DMG_SLASH + DMG_CRUSH) and
		(inflictorBase == "weapon_melee" or inflictorClass == "weapon_melee" or
		 inflictorClass == "weapon_hands_sh" or inflictorClass == "weapon_hg_coolhands")
	if isMeleeDmg then
		dmgInfo:ScaleDamage(1.05)
	end
	local isSharpMelee = isMeleeDmg and dmgInfo:IsDamageType(DMG_SLASH)
	
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

	attacker.harm = dmgInfo:GetDamage() / 100
	
	if ply or org.fakePlayer then
		hook_Run("PreHomigradDamage", org.fakePlayer and ent or ply, dmgInfo, hitgroup, ent, attacker.harm, hitBoxs, inputHole)
	end
	
	local dmg_before = dmgInfo:GetDamage()

	local lastPos, hitBoxs, inputHole, outputHole, outputDir, distance, tracePoses = nil,{},{},{},{},nil,nil
	org._bulletImpactBleedAdd = nil
	-- Limb artery damage must stay on the side of the physics bone the bullet
	-- actually entered; do not let a long trace rupture the opposite limb.
	if dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then
		org._bulletImpactHitgroup = hitgroup ~= 0 and hitgroup or nil
	end
	if dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT+DMG_SLASH+DMG_CLUB+DMG_GENERIC) then
		lastPos, hitBoxs, inputHole, outputHole, outputDir, distance, tracePoses = hg.organism.Trace(dmgPos, dir, size, maxpen, boxs, pos, sphere, organs, dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT), Trace_Bullet, ent.organism, organs, dmg / 25, dmgInfo, dir)
	elseif dmgInfo:IsDamageType(DMG_BLAST) then
		local organs = hg.organism.GetHitBoxOrgans(ent:GetModel(), ent)
		local boxs, pos, sphere = hg.organism.ShootMatrix(ent, organs)
		
		hg.organism.BlastTrace(dmgInfo:GetDamagePosition(), (ent:GetPos() - dmgInfo:GetDamagePosition()):Length() / 200, dmg * 2, boxs, organs, Trace_Blast, ent.organism, organs, dmg / 300, dmgInfo)
		hg.organism.AddWoundManual(ent,dmg,vector_origin,angle_zero,math.random(0,ent:GetBoneCount()),CurTime())
	end
	org._bulletImpactHitgroup = nil
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

			queueBulletBloodImpact(ent, "exit", outputHole[#outputHole], -outputDir, dmg)
			
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

	local bonename = ent:GetBoneName(ent:TranslatePhysBoneToBone(bone))
	local hitgroup = bonetohitgroup[bonename] or 0
	local hasHeadArmor = org.owner.armors and org.owner.armors["head"] ~= nil
	local fatalHeadshot = hitgroup == HITGROUP_HEAD
		and dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
		and not hasHeadArmor
	--print(dmg_before, 1)
	--if ent:IsRagdoll() then
		if RagdollForceBoneMul[hitgroup] then len = len * RagdollForceBoneMul[hitgroup] end
		if dmgInfo:IsDamageType(DMG_BULLET) and RagdollDamageBoneMul[hitgroup] then
			dmgInfo:ScaleDamage(RagdollDamageBoneMul[hitgroup])
			dmg_before = dmg_before * RagdollDamageBoneMul[hitgroup]
			-- я даже не знаю, может это снова убрать? ^
			-- у нас это так давно было неправильно, что, наверное,
			-- все уже привыкли
		end
	--end

	if inputHole and #inputHole > 0 and dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT) then
		queueBulletBloodImpact(ent, "entry", inputHole[1], dir / 2, dmg)
	end

	--print(dmg_before, 2)
	local dmgBlood, dmgHurt, instaPain, immobilization = hg.organism.DamageTypeAffliction(dmg_before / 12, dmgInfo, ent, org)
	
	local hitbody = #inputHole > 0 or not dmgInfo:IsDamageType(DMG_BULLET+DMG_BUCKSHOT)
	
	--if hitbody then
	if not org.superfighter then
		dmgBlood = dmgBlood * 1.5
		local bleed_add = dmgBlood * bleedMul// / (RagdollDamageBoneMul[hitgroup] or 1)
		--org.bleed = org.bleed + bleed_add
		attacker.harm = attacker.harm + bleed_add / 50
		local hurt_add = dmgHurt * 0.5 * hurtMul
		org.hurtadd = org.hurtadd + hurt_add
		local meleePainMul = isSharpMelee and 0.75 or 1
		local painadd = dmgHurt * painMul * 1.5 * meleePainMul
		local instantPainMul = 0.2
		local instant_pain = (instantPainMul or 0) * painadd
		local slow_pain = (1 - (instantPainMul or 0)) * painadd
		
		local instant_pain = instantPainMul * painadd
		local slow_pain = (1 - instantPainMul) * painadd
		org.painadd = org.painadd + slow_pain
		//org.avgpain = org.avgpain + instant_pain
		local meleeShockMul = isMeleeDmg and (isSharpMelee and 0.44 or 0.56) or 1
		local shockAdd = instaPain * shockMul * 4.5 * instant_pain_shock_scale * meleeShockMul * math.Clamp(pen / 5,1,2)
		org.shock = math.min(org.shock + shockAdd, 70)
		org.immobilization = math.min(org.immobilization + immobilization * immobilizationMul, 30)
		org.lasthit = CurTime()
		
		local adrenalineMul = math.min(math.max(1 + org.adrenaline, 1), 1.2)
		local adrenaline = org.adrenaline
		local analgesiaMul = (org.analgesia * 4 + 1)
		local painkillerMul = (org.painkiller * 0.5 + 1)
		local inflictor = dmgInfo:GetInflictor()
		local inflictorClass = IsValid(inflictor) and inflictor:GetClass() or ""
		local inflictorBase = IsValid(inflictor) and inflictor.Base or ""
		local meleeHit = dmgInfo:IsDamageType(DMG_CLUB + DMG_SLASH) or inflictorBase == "weapon_melee" or inflictorClass == "weapon_melee"
	
		org.shock_turn = 10 * (!org.otrub and 1 or 0.1)
	
		

		local shockFakeThreshold = org.shock_turn * 3.6 * analgesiaMul * painkillerMul * (meleeHit and 1.5 or 1)
		if shockAdd > 2 and org.shock > shockFakeThreshold and (org.nextShockFake or 0) < CurTime() then
			org.nextShockFake = CurTime() + (meleeHit and 3.5 or 2.75)
			timer.Simple(0, function()
				if not IsValid(org.owner) then return end
				hg.Fake(org.owner)
			end)
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

			if ply.AddForceRag[bone][2] and ply.AddForceRag[bone][2]:Length() > 4500 then //по-моему какие-то большие значения, не?
				if ply.AddForceRag[bone][2]:Length() > 7000 then
					hg.StunPlayer(ply, 0.5)
					hg.LightStunPlayer(ply, 2)
				else
					hg.LightStunPlayer(ply, 2)
				end
			end
		end
		
		if ent:IsRagdoll() then
			ent:GetPhysicsObjectNum(bone or 0):ApplyForceCenter(force * 1)
		end
	end

	if dmgInfo:IsDamageType(DMG_BLAST) then
		hitgroup = table.Random({
			HITGROUP_LEFTARM,
			HITGROUP_RIGHTARM,
			HITGROUP_RIGHTLEG,
			HITGROUP_LEFTLEG,
			HITGROUP_HEAD
		})
	end

	local lend = math.max(0.1, (ent:GetPos() - dmgInfo:GetDamagePosition()):Length())
	local damageStack = dmg_before / (dmgInfo:IsDamageType(DMG_BULLET) and RagdollDamageBoneMul[hitgroup] or 1)
	--print(damageStack, 3)
	damageStack = damageStack * (dmgInfo:IsDamageType(DMG_BLAST) and 200 / lend or 1) * (!dmgInfo:IsDamageType(DMG_CLUB+DMG_SLASH+DMG_BULLET+DMG_BLAST+DMG_SNIPER) and 0 or 1) * (ent:IsNPC() and 3 or 1)
	--damageStack = damageStack * (bullet and bullet.AmmoType and hg.ammotypeshuy[bullet.AmmoType] and hg.ammotypeshuy[bullet.AmmoType].BulletSettings and hg.ammotypeshuy[bullet.AmmoType].BulletSettings.Mass or 1) / 8
	
	org.dmgstack = org.dmgstack or {}
	org.dmgstack[hitgroup] = org.dmgstack[hitgroup] or {}
	local mul = (org.dmgstack[hitgroup][3] or 0) + 1
	org.dmgstack[hitgroup][1] = ((org.dmgstack[hitgroup][2] and (ent.organism.dmgstack[hitgroup][2] + 0.05 * mul) > CurTime()) and ent.organism.dmgstack[hitgroup][1] * ((ent.organism.dmgstack[hitgroup][2] + 0.05 * mul) - CurTime()) / (0.05 * mul) or 0) + damageStack * mul
	org.dmgstack[hitgroup][2] = CurTime()
	org.dmgstack[hitgroup][3] = (org.dmgstack[hitgroup][3] or 0) + damageStack / 500

	local mat = ent:GetBoneMatrix(ent:TranslatePhysBoneToBone(bone))
	local hitgroup_max = 100
	if org.isPly then
		hitgroup_max = hitgroup == HITGROUP_HEAD and player_head_gib_threshold or hitgrouptolimb[hitgroup] and player_limb_gib_threshold or hitgroup_max
	end
	local hitgroup_max = (hitgroup == HITGROUP_HEAD) and 85 or 135 -- heads remain easier to sever than limbs, but not from light damage
	local instant = org.dmgstack[hitgroup][1] > hitgroup_max
	--print(damageStack, org.dmgstack[hitgroup][1], org.dmgstack[hitgroup][3])
	local blast = dmgInfo:IsDamageType(DMG_BLAST)
	
	timer.Create("dmgstack"..org.entindex, !instant and 1 or 0, 1, function()
		--if !IsValid(ply) then return end
		
		local rag = IsValid(ply) and (IsValid(ply:GetNWEntity("RagdollDeath", ply.FakeRagdoll)) and ply:GetNWEntity("RagdollDeath", ply.FakeRagdoll)) or ent:IsRagdoll() and ent or ent:IsNPC() and ent
		local org = rag and rag.organism or ent.organism

		timer.Simple(0.01, function()
			if !org then return end
			if !org.dmgstack then return end
			if !org.dmgstack[hitgroup] then return end
			if !org.dmgstack[hitgroup][1] then return end
			local should = org.dmgstack[hitgroup][1] > hitgroup_max

			local limbs = {
				"lleg",
				"rleg",
				"larm",
				"rarm",
			}

			if should and hitgrouptolimb[hitgroup] then
				if blast then
					for i, limb in ipairs(limbs) do
						if !org[limb.."amputated"] and math.random(5) < 200 / lend then
							hg.organism.AmputateLimb(org, limb)
						end
					end
				else
					if !org[hitgrouptolimb[hitgroup].."amputated"] then
						hg.organism.AmputateLimb(org, hitgrouptolimb[hitgroup])
					end
				end
			end

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
				hg.ExplodeHead(ent)

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

	dmgInfo:ScaleDamage(dmgInfo:IsDamageType(DMG_BURN) and 0.015 or (dmgInfo:IsDamageType(DMG_CLUB) and 0.25 or 0.15))
	
	takeRagdollDamage(ent, dmgInfo)

	if fatalHeadshot and hg.organism.KillFatalBrainDamage then
		hg.organism.KillFatalBrainDamage(org)
	end

	if org.isPly then
		hook.Run("Org Think Call", ply, org)
		
		if (not ply:Alive() or not org.alive) and (math.Round(ply:GetInfoNum("hg_deathfadeout", 1)) == 1) then// or org.otrub or hg.organism.paincheck(org) or (ply:Health() <= 0) then
			if org.skull == 1 then
				//ent:SetNWString("PlayerName", "Unidentifiable person")
			end
			
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
		local snd = (ply.painCD and CurTime() < ply.painCD + 10 ) and "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".wav" or "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/mygut02.wav"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
	[HITGROUP_CHEST] = function(ply,ent)
		local snd = "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".wav"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
	[HITGROUP_LEFTARM] = function(ply,ent)
		local snd = (ply.painCD and CurTime() < ply.painCD + 10 ) and "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".wav" or "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/myarm0"..math.random(1,2)..".wav"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
	[HITGROUP_RIGHTARM] = function(ply,ent)
		local snd = (ply.painCD and CurTime() < ply.painCD + 10 ) and "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".wav" or "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/myarm0"..math.random(1,2)..".wav"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
	[HITGROUP_RIGHTLEG] = function(ply,ent)
		local snd = (ply.painCD and CurTime() < ply.painCD + 10 ) and "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".wav" or "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/myleg0"..math.random(1,2)..".wav"
		ent:EmitSound(snd,75,ply.VoicePitch)
		ply.painCD = CurTime() + SoundDuration(snd)
		ply.lastPhr = snd
	end,
	[HITGROUP_LEFTLEG] = function(ply,ent)
		local snd = (ply.painCD and CurTime() < ply.painCD + 10 ) and "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/pain0"..math.random(1,9)..".wav" or "vo/npc/"..(ThatPlyIsFemale(ply) and "female" or "male").."01/myleg0"..math.random(1,2)..".wav"
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
		dmgBlood = dmg * 3
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
		dmgBlood = dmg * 3
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
	dmg = dmg * 2

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

	local traceResult = GetTraceDamage(ent, data.HitPos, -(data.OurOldVelocity - data.TheirOldVelocity))

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
			
			hg.organism.input_list.skull(org, bone, dmg * 6 * headDamageMul * ragdoll_fall_skull_damage_mul, dmgInfo)
			hg.organism.input_list.jaw(org, bone, dmg * headDamageMul * ragdoll_fall_jaw_damage_mul, dmgInfo)
			
			org.consciousness = math.Approach(org.consciousness, 0, dmg * head_consciousness_mul * headDamageMul)
			
			local neck_not_broken = org.spine3 < 0.8
			
			//if dmg > 0.5 then
				hg.organism.input_list.spine3(org, bone, dmg * (math.random(4) == 1 and 1 or 0) * 3 * (hadhelmet and 0.5 or 1), dmgInfo)
			//end
			if dmg > head_otrub_min_damage and !hadhelmet and math.Rand(0, 1) < head_otrub_chance then
				org.needotrub = true
				org.shock = org.shock + 10
				org.consciousness = math.min(org.consciousness, head_otrub_consciousness_cap)
			end

			if neck_not_broken and org.spine3 >= 0.8 then
				hg.BreakNeck(ent, true)
			end

			if oldSkull < 1 and org.skull == 1 then
				net.Start("hg_bloodimpact")
				net.WriteVector(getHeadImpactPos(ent, data.HitPos))
				net.WriteVector((data.OurOldVelocity - data.TheirOldVelocity):GetNormalized() / 10)
				net.WriteFloat(math.max(dmg * ragdoll_fall_skull_break_blood_mul, 1))
				net.WriteInt(1, 8)
				net.Broadcast()
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
			if org.skull >= 0.6 or org.jaw == 1 then
				ent:SetNWString("PlayerName", "disfigured nigga")
				if IsValid(ply) and ply ~= ent then ply:SetNWString("PlayerName", "disfigured nigga") end

				local body = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply:GetNWEntity("RagdollDeath")
				if IsValid(body) and body ~= ent then body:SetNWString("PlayerName", "disfigured nigga") end
			end
			
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

	local dmghuy = dmg * 20

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

function hg.BreakNeck(ent, fromDamage)
	print("[HG Floppy] BreakNeck called: ent=" .. tostring(ent) .. " fromDamage=" .. tostring(fromDamage))
	if not IsValid(ent) then
		print("[HG Floppy] BreakNeck FAIL: ent invalid")
		return
	end

	local ply = ent:IsRagdoll() and hg.RagdollOwner(ent) or ent
	print("[HG Floppy] BreakNeck: ply=" .. tostring(ply) .. " isRagdoll=" .. tostring(ent:IsRagdoll()))
	
	-- A broken spine3 is a paralyzing neck injury, not an immediate kill.
	-- Keep the player alive long enough for the organism incapacitation state
	-- and the floppy-neck constraint to take effect.

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
		if playerRef.organism then
			playerRef.organism.spine3 = 1
			print("[HG Floppy] BreakNeck timer: set spine3 = 1")
		end
		
		-- Play sound on the ragdoll (only if from damage, not reapplication)
		if fromDamage then
			ragdoll:EmitSound("neck_snap_01.wav", 60, 100, 1, CHAN_AUTO)
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
		if hg.BreakNeck then hg.BreakNeck(ragdoll, false) end
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
	
	-- OLD LUA: Clear floppy persistence on spawn so player starts fresh
	ply.HG_FloppyPersist = nil
	ply.HG_FloppyPersistSeg = nil
end)

-- Clean up floppy constraints when a ragdoll is removed
hook.Add("EntityRemoved", "CleanupFloppyConstraints", function(ent)
	if not ent:IsRagdoll() then return end
	-- OLD LUA STYLE: Cleanup floppyLimbs
	if ent.floppyLimbs then
		for limb, data in pairs(ent.floppyLimbs) do
			if IsValid(data.constraint) then data.constraint:Remove() end
			-- Also remove internal constraint
			local bone1 = ent:LookupBone(data.bone1)
			if bone1 then
				local phys1 = ent:TranslateBoneToPhysBone(bone1)
				if phys1 then
					pcall(function() ent:RemoveInternalConstraint(phys1) end)
				end
			end
		end
		ent.floppyLimbs = nil
	end
	-- Legacy cleanup
	if ent.FloppyConstraints then
		for limb, cons in pairs(ent.FloppyConstraints) do
			if IsValid(cons) then cons:Remove() end
		end
		ent.FloppyConstraints = nil
	end
end)

-- OLD LUA: Heal/respawn cleanup via organism clearing
hook.Add("Org Clear", "HG_ResetFloppyOnOrgClear", function(org)
    if not org or not IsValid(org.owner) then return end
    local ply = org.owner
    -- Clear persistence flags to fully reset visuals
    ply.HG_FloppyPersist = nil
    ply.HG_FloppyPersistSeg = nil
    ply.HG_SpineFloppyPersist = nil
    -- Clear any active ragdoll floppy constraints
    local rag = ply:GetNWEntity("RagdollDeath")
    if not IsValid(rag) then rag = ply:GetNWEntity("FakeRagdoll") end
    if not IsValid(rag) and IsValid(ply.FakeRagdoll) then rag = ply.FakeRagdoll end
    if IsValid(rag) and not IsPlayerOwnedRagdoll(rag) then
        -- Player-owned ragdolls are left alone on organism reset/death.
        -- The next ragdoll will use the reset organism state, avoiding the stretch caused by
        -- removing internal constraints while the ragdoll is still active/visible.
        if rag.floppyLimbs then
            for limb, data in pairs(rag.floppyLimbs) do
                if IsValid(data.constraint) then data.constraint:Remove() end
                local bone1 = rag:LookupBone(data.bone1)
                if bone1 then
                    local phys1 = rag:TranslateBoneToPhysBone(bone1)
                    if phys1 then pcall(function() rag:RemoveInternalConstraint(phys1) end) end
                end
            end
            rag.floppyLimbs = nil
        end
        if rag.FloppyConstraints then
            for seg, cons in pairs(rag.FloppyConstraints) do
                if IsValid(cons) then cons:Remove() end
                removeFloppyBoneOffset(rag, "spine_" .. seg)
            end
            rag.FloppyConstraints = nil
        end
        if rag.FloppyBoneOffsets then
            for key, _ in pairs(rag.FloppyBoneOffsets) do
                removeFloppyBoneOffset(rag, key)
            end
        end
    end
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
			penetration = penetration and detail.penetration < bullet.Penetration

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
