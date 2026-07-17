--local Organism = hg.organism
hg.organism.module = hg.organism.module or {}
local module = hg.organism.module
hg.organism.lastindex = hg.organism.lastindex or 1000000

function hg.organism.ZeroVitals(org)
	if not org then return end
	org.heartstop = true
	org.heartbeat = 0
	org.pulse = 0
	org.ecgState = "asystole"
	org.cardiacOutput = 0
	org.bloodpressure = 0
	org.systolic = 0
	org.diastolic = 0
end

-- Wounds are owned by the organism, but both kinds of player ragdoll are
-- rendered as separate entities. Keep their replicated wound lists in lockstep
-- so a hit remains visible and targetable through fake/death ragdoll changes.
function hg.organism.SyncWounds(org)
	if not org or not IsValid(org.owner) then return end

	local owner = org.owner
	local wounds = org.wounds or {}
	local arterialWounds = org.arterialwounds or {}
	local targets = {owner}
	local fakeRagdoll = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner:GetNWEntity("FakeRagdoll", NULL)
	local deathRagdoll = IsValid(owner.RagdollDeath) and owner.RagdollDeath or owner:GetNWEntity("RagdollDeath", NULL)

	if IsValid(fakeRagdoll) and fakeRagdoll != owner then
		table.insert(targets, fakeRagdoll)
	end

	if IsValid(deathRagdoll) and deathRagdoll != owner and deathRagdoll != fakeRagdoll then
		table.insert(targets, deathRagdoll)
	end

	for _, target in ipairs(targets) do
		target:SetNetVar("wounds", wounds)
		target:SetNetVar("arterialwounds", arterialWounds)
	end
end

function hg.organism.KillFatalBrainDamage(org)
	if not org or org.fatalBrainDeath then return false end

	org.fatalBrainDeath = true
	org.alive = false
	org.needotrub = false
	org.otrub = false
	org.incapacitated = false
	org.deathStateEnd = nil
	org.deathStateStart = nil
	org.deathStatePendingEnd = nil
	org.deathStateFadeStart = nil
	hg.organism.ZeroVitals(org)

	local owner = org.owner
	if IsValid(owner) and owner:IsPlayer() and owner:Alive() then
		owner:Kill()
	end

	return true
end

local panicattack_threshold = 0.35
local panicattack_add_decay_time = 120
local panicattack_rise_time = 5
local panicattack_decay_time = 200
local panicattack_gain_mul = 0.5
local panicattack_disorientation = 0.45
local panicattack_adrenaline_add_target = 4
local panicattack_adrenaline_add_rise_time = 14
local panicattack_heart_roll_delay = 15
local panicattack_heart_roll_chance = 1
local panicattack_damage_scale = 0.006
local panicattack_witness_radius = 850
local panicattack_death_radius = 900
local debug_destroy_eyes = CreateConVar("hg_debug_destroy_eyes", "0", FCVAR_CHEAT, "Force eye destruction for visual debugging: 0 = off, 1 = left, 2 = right, 3 = both", 0, 3)
local seizure_duration = 15
local seizure_end_shock = 20
local seizure_pose_force = 850
local seizure_pose_damp = 42
local seizure_leg_buckle = 46
local seizure_shake_freq = 5.8
local seizure_shake_amp = 1.35
local seizure_brain_trauma_gain_mul = 2
local seizure_brain_heal_gain_mul = 1.1
local seizure_temperature_gain_mul = 0.013
local seizure_temperature_low_start = 35
local seizure_temperature_high_start = 39
local seizure_brain_roll_delay = 20
local seizure_brain_roll_chance = 15
local seizure_brain_roll_gain_min = 0.04
local seizure_brain_roll_gain_max = 0.11
hook.Add("Org Clear", "Main", function(org)
	org.alive = true
	org.otrub = false
	org.entindex = IsValid(org.owner) and org.owner:EntIndex() or hg.organism.lastindex + 1
	module.pulse[1](org)
	module.blood[1](org)
	module.pain[1](org)
	module.stamina[1](org)
	module.lungs[1](org)
	module.liver[1](org)
	module.metabolism[1](org)
	module.concussion[1](org)
	module.random_events[1](org)
	module.goodmood[1](org)
	if module.teeth and module.teeth[1] then module.teeth[1](org) end
	org.brain = 0
	org.brainFrontal = 0
	org.brainParietal = 0
	org.brainTemporal = 0
	org.brainOccipital = 0
	org.brainHemorrhage = 0
	org.brainBleedRate = 0
	org.eyeL = 0
	org.eyeR = 0
	org.eyeLDestroyed = nil
	org.eyeRDestroyed = nil
	org.consciousness = 1
	org.disorientation = 0
	org.jaw = 0
	org.spine1 = 0
	org.spine2 = 0
	org.spine3 = 0
	org.chest = 0
	org.pelvis = 0
	org.skull = 0
	org.eyeL = 0
	org.eyeR = 0
	org.stomach = 0
	org.intestines = 0
	org.headtrauma = 0

	org.tranexamic_acid = 0

	org.thiamine = 0
	org.thiamine_timer = 0
	org.thiamine_healed = false

	org.lleg = 0
	org.rleg = 0
	org.larm = 0
	org.rarm = 0
	org.llegdislocation = false
	org.rlegdislocation = false
	org.rarmdislocation = false
	org.larmdislocation = false
	org.jawdislocation = false

	org.llegamputated = false
	org.rlegamputated = false
	org.rarmamputated = false
	org.larmamputated = false
	org.headamputated = false

	org.furryinfected = false

	org.health = 100
	org.canmove = true
	org.recoilmul = 1
	org.legstrength = 1
	org.armstrength = 1
	org.meleespeed = 1
	org.breathing = 1
	org.temperature = 36.7
	org.superfighter = false
	org.CantCheckPulse = nil
	org.HEV = nil
	org.bleedingmul = 1
	org.neckslitSoundName = nil
	org.neckslitSoundEnt = nil

	--\\ info for rp addition
	org.last_heartbeat = CurTime()
	org.bulletwounds = 0
	org.stabwounds = 0
	org.slashwounds = 0
	org.bruises = 0
	org.burns = 0
	org.explosionwounds = 0

	org.fear = 0
	org.fearadd = 0
	org.givingUp = false
	org._giveUpHeartStopCheck = 0
	--//

	org.assimilated = 0
	org.berserk = 0
	org.noradrenaline = 0
	org.panicattackadd = 0
	org.panicattack = 0
	org.panicattackActive = false
	org.nextPanicHeartRoll = 0
	org.seizure = 0
	org.seizureActive = false
	org.seizureStart = 0
	org.seizureEnd = 0
	org.nextSeizureSpasm = 0
	org.nextSeizureRoll = 0
	org.lastSeizureBrain = 0
	org.lastSeizureLobeDamage = 0
	org.lastSeizureTemperature = org.temperature
	org.fatalBrainDeath = nil
	org.deathStateEnd = nil
	org.deathStateStart = nil
	org.deathStatePendingEnd = nil
	org.deathStateFadeStart = nil
	org.deathStateKilled = nil

	org.noradrenalineEndTime = nil
	org.blindness = nil

	-- Hand dominance for limb impairment calculations
	org.hand_dominance = "right"

	-- Permanent aiming impairment from repeated arm trauma
	org.permanent_aim_impairment = 0

	if IsValid(org.owner) then
		if org.owner:IsPlayer() and org.owner:Alive() then
			org.owner:SetHealth(100)
			org.owner:SetNetVar("wounds",{})
			org.owner:SetNetVar("arterialwounds",{})
		end

		org.owner:SetNetVar("zableval_masku", false)
	end

	org.allowholster = false
	
	org.just_damaged_bone = nil
	org.LodgedEntities = nil
	
	
	org.dmgstack = {}
end)

hook.Add("Should Fake Up", "organism", function(ply)
	local org = ply.organism
	if org.seizureActive or org.otrub or org.fake or org.nearpainlimit or org.shock > 40 or org.spine1 >= hg.organism.fake_spine1 or org.spine2 >= hg.organism.fake_spine2 or org.spine3 >= hg.organism.fake_spine3 or (org.lleg == 1 and org.rleg == 1) and org.berserk <= 0.3 or (org.blood < 2900) or org.consciousness <= 0.4 then
		return false
	end
end)

util.AddNetworkString("organism_send")
util.AddNetworkString("organism_sendply")
util.AddNetworkString("rem_deathstate_sound")
local CurTime = CurTime
local nullTbl = {}
local hg_developer = ConVarExists("hg_developer") and GetConVar("hg_developer") or CreateConVar("hg_developer",0,FCVAR_SERVER_CAN_EXECUTE,"Toggle developer mode (enables damage traces)",0,1)
local hg_scavdying = ConVarExists("hg_scavdying") and GetConVar("hg_scavdying") or CreateConVar("hg_scavdying", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Incapacitated display mode: 0=fade ring then text, 1=flatline ring, 2=ring and countdown text", 0, 2)
local hg_incapacitation = ConVarExists("hg_incapacitation") and GetConVar("hg_incapacitation") or CreateConVar("hg_incapacitation", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Incapacitated dying: 0=disabled, 1=immediate, 2=delayed by injury severity", 0, 2)
local function send_organism(org, ply)
	if not IsValid(org.owner) then return end
	local sendtable = {}

	sendtable.alive = org.alive
	sendtable.otrub = org.otrub
	sendtable.owner = org.owner
	sendtable.stamina = org.stamina
	sendtable.immobilization = org.immobilization
	sendtable.adrenaline = org.adrenaline
	sendtable.adrenalineAdd = org.adrenalineAdd
	sendtable.analgesia = org.analgesia
	sendtable.lleg = org.lleg
	sendtable.rleg = org.rleg
	sendtable.rarm = org.rarm
	sendtable.larm = org.larm
	sendtable.pelvis = org.pelvis
	sendtable.skull = org.skull
	sendtable.chest = org.chest
	sendtable.internalBleed = org.internalBleed
	sendtable.internalBleedHeal = org.internalBleedHeal
	sendtable.disorientation = org.disorientation
	sendtable.brain = org.brain
	sendtable.brainFrontal = org.brainFrontal
	sendtable.brainParietal = org.brainParietal
	sendtable.brainTemporal = org.brainTemporal
	sendtable.brainOccipital = org.brainOccipital
	sendtable.brainHemorrhage = org.brainHemorrhage
	sendtable.brainBleedRate = org.brainBleedRate
	sendtable.o2 = org.o2
	sendtable.CO = org.CO
	sendtable.blood = org.blood
	sendtable.bloodtype = org.bloodtype
	sendtable.bleed = org.bleed
	sendtable.hurt = org.hurt
	sendtable.pain = org.pain
	sendtable.shock = org.shock
	sendtable.pulse = org.pulse
	sendtable.heartbeat = org.heartbeat
	sendtable.heartstop = org.heartstop
	sendtable.ecgState = org.ecgState
	sendtable.cardiacOutput = org.cardiacOutput
	sendtable.hemorrhageCompensation = org.hemorrhageCompensation
	sendtable.compensationPulseMultiplier = org.compensationPulseMultiplier
	sendtable.compensationHeartRateTarget = org.compensationHeartRateTarget
	sendtable.hypovolemia = org.hypovolemia
	sendtable.hypovolemicShock = org.hypovolemicShock
	sendtable.bloodO2Cap = org.bloodO2Cap
	sendtable.bloodpressure = org.bloodpressure
	sendtable.systolic = org.systolic
	sendtable.diastolic = org.diastolic
	sendtable.timeValue = org.timeValue
	sendtable.holdingbreath = org.holdingbreath
	sendtable.arteria = org.arteria
	sendtable.recoilmul = org.recoilmul
	sendtable.meleespeed = org.meleespeed
	sendtable.legstrength = org.legstrength
	sendtable.armstrength = org.armstrength
	sendtable.breathing = org.breathing
	sendtable.temperature = org.temperature
	sendtable.canmove = org.canmove
	sendtable.fear = org.fear
	sendtable.goodmood = org.goodmood
	sendtable.llegdislocation = org.llegdislocation
	sendtable.rlegdislocation = org.rlegdislocation
	sendtable.rarmdislocation = org.rarmdislocation
	sendtable.larmdislocation = org.larmdislocation
	sendtable.jawdislocation = org.jawdislocation
	sendtable.llegamputated = org.llegamputated
	sendtable.rlegamputated = org.rlegamputated
	sendtable.rarmamputated = org.rarmamputated
	sendtable.larmamputated = org.larmamputated
	sendtable.headamputated = org.headamputated
	sendtable.lungsfunction = org.lungsfunction
	sendtable.eyeL = org.eyeL
	sendtable.eyeR = org.eyeR
	sendtable.consciousness = org.consciousness
	sendtable.concussion = org.concussion
	sendtable.assimilated = org.assimilated
	sendtable.berserk = org.berserk
	sendtable.noradrenaline = org.noradrenaline
	sendtable.panicattackadd = org.panicattackadd
	sendtable.panicattack = org.panicattack
	sendtable.seizure = org.seizure
	sendtable.seizureActive = org.seizureActive
	sendtable.seizureStart = org.seizureStart
	sendtable.seizureEnd = org.seizureEnd
	sendtable.LodgedEntities = org.LodgedEntities
	sendtable.CantCheckPulse = org.CantCheckPulse
	sendtable.blindness = org.blindness

	sendtable.critical = org.critical
	sendtable.incapacitated = org.incapacitated
	sendtable.deathStateEnd = org.deathStateEnd or 0
	sendtable.deathStateStart = org.deathStateStart or 0
	sendtable.deathStatePendingEnd = org.deathStatePendingEnd or 0
	sendtable.deathStateFadeStart = org.deathStateFadeStart or 0
	sendtable.berserkActive2 = org.berserkActive2
	sendtable.noradrenalineActive = org.noradrenalineActive
	sendtable.aiming_fatigue = org.aiming_fatigue
	sendtable.hand_dominance = org.hand_dominance
	sendtable.permanent_aim_impairment = org.permanent_aim_impairment
	sendtable.givingUp = org.givingUp
	sendtable.panicattackActive = org.panicattackActive

	sendtable.superfighter = org.superfighter

	net.Start("organism_send")
	net.WriteTable(org)
	net.WriteBool(org.owner.fullsend)
	net.WriteBool(false)
	net.WriteBool(true)
	net.WriteBool(false)
	if IsValid(ply) and ply:IsPlayer() then
		net.Send(ply)
	else
		net.Broadcast()
	end
	if org.owner == ply or not IsValid(ply) or not ply:IsPlayer() then
		org.owner.fullsend = nil
	end
end

local function send_bareinfo(org)
	if not IsValid(org.owner) then return end

	org.owner:SetNWBool("SkullBrokenFully", (org.skull or 0) >= 1)

	local sendtable = {}

	sendtable.alive = org.alive
	sendtable.otrub = org.otrub
	sendtable.owner = org.owner
	sendtable.bloodtype = org.bloodtype
	sendtable.pulse = org.pulse
	sendtable.blood = org.blood
	sendtable.heartbeat = org.heartbeat
	sendtable.heartstop = org.heartstop
	sendtable.ecgState = org.ecgState
	sendtable.cardiacOutput = org.cardiacOutput
	sendtable.hemorrhageCompensation = org.hemorrhageCompensation
	sendtable.compensationPulseMultiplier = org.compensationPulseMultiplier
	sendtable.compensationHeartRateTarget = org.compensationHeartRateTarget
	sendtable.hypovolemia = org.hypovolemia
	sendtable.hypovolemicShock = org.hypovolemicShock
	sendtable.bloodO2Cap = org.bloodO2Cap
	sendtable.bloodpressure = org.bloodpressure
	sendtable.systolic = org.systolic
	sendtable.diastolic = org.diastolic
	sendtable.analgesia = org.analgesia
	sendtable.o2 = org.o2
	sendtable.timeValue = org.timeValue
	sendtable.superfighter = org.superfighter
	sendtable.lungsfunction = org.lungsfunction
	sendtable.eyeL = org.eyeL
	sendtable.eyeR = org.eyeR
	sendtable.eyeL = org.eyeL
	sendtable.eyeR = org.eyeR
	sendtable.lleg = org.lleg
	sendtable.rleg = org.rleg
	sendtable.rarm = org.rarm
	sendtable.larm = org.larm
	sendtable.llegdislocation = org.llegdislocation
	sendtable.rlegdislocation = org.rlegdislocation
	sendtable.rarmdislocation = org.rarmdislocation
	sendtable.larmdislocation = org.larmdislocation
	sendtable.jawdislocation = org.jawdislocation
	sendtable.llegamputated = org.llegamputated
	sendtable.rlegamputated = org.rlegamputated
	sendtable.rarmamputated = org.rarmamputated
	sendtable.larmamputated = org.larmamputated
	sendtable.headamputated = org.headamputated
	sendtable.LodgedEntities = org.LodgedEntities
	sendtable.berserkActive2 = org.berserkActive2
	sendtable.CantCheckPulse = org.CantCheckPulse
	sendtable.noradrenalineActive = org.noradrenalineActive
	sendtable.panicattackadd = org.panicattackadd
	sendtable.panicattack = org.panicattack
	sendtable.seizure = org.seizure
	sendtable.seizureActive = org.seizureActive
	sendtable.seizureStart = org.seizureStart
	sendtable.seizureEnd = org.seizureEnd
	sendtable.brainFrontal = org.brainFrontal
	sendtable.brainParietal = org.brainParietal
	sendtable.brainTemporal = org.brainTemporal
	sendtable.brainOccipital = org.brainOccipital
	sendtable.brainHemorrhage = org.brainHemorrhage
	sendtable.brainBleedRate = org.brainBleedRate

	local rf = RecipientFilter()
	--rf:AddAllPlayers()
	rf:AddPVS(org.owner:GetPos())
	if org.owner:IsPlayer() then rf:RemovePlayer(org.owner) end

	net.Start("organism_send")
	net.WriteTable(org)
	net.WriteBool(org.owner.fullsend)
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(false)
	net.Send(rf)
end

hg.send_organism = send_organism
hg.send_bareinfo = send_bareinfo

local META = FindMetaTable("Player")
function META:IsBerserk()
	if !IsValid(self) then return false end
	if self:IsPlayer() and not self:Alive() then return false end

	local org = self.organism
	return org.berserkActive2 or false
end

function META:IsStimulated()
	if !IsValid(self) then return false end
	if self:IsPlayer() and not self:Alive() then return false end

	local org = self.organism
	return org.noradrenalineActive or false
end

local META2 = FindMetaTable("Entity")
function META2:IsBerserk()
	return false
end

function META2:IsStimulated()
	return false
end

function hg.organism.AddPanicAttack(org, amount, silent, chanceMultiplier)
	if not org then return 0 end
	if not isnumber(amount) or amount <= 0 then return org.panicattackadd or 0 end
	local adrenalineRisk = math.Clamp(((org.adrenaline or 0) + (org.adrenalineAdd or 0) - 1.5) / 3, 0, 0.65)
	local analgesiaRisk = math.Clamp(((org.analgesia or 0) + (org.analgesiaAdd or 0) - 0.2) / 2.8, 0, 1) * 0.2
	local vulnerability = 1 + math.Clamp(org.ptsdPanicRisk or 0, 0, 1) * 1.6 + adrenalineRisk + analgesiaRisk
	local eventScale = math.max(tonumber(chanceMultiplier) or 1, 0)

	-- Every real panic event advances the live panic-attack meter. PTSD and the
	-- other vulnerability sources decide how much it advances, rather than
	-- randomly discarding the event and leaving the displayed Panic value inert.
	org.panicattackadd = math.Clamp((org.panicattackadd or 0) + amount * panicattack_gain_mul * eventScale * math.min(vulnerability, 1.75), 0, 1)

	return org.panicattackadd
end

function hg.organism.AddSeizure(org, amount)
	if not org then return 0 end
	if not isnumber(amount) or amount <= 0 then return org.seizure or 0 end

	org.seizure = math.Clamp((org.seizure or 0) + amount, 0, 1)

	return org.seizure
end

local function getSeizureLobeDamage(org)
	return math.Clamp((org.brainFrontal or 0) + (org.brainParietal or 0) + (org.brainTemporal or 0) + (org.brainOccipital or 0), 0, 1)
end

local function apply_seizure_pose(rag, org, time)
	if hg.applySeizurePostureToRagdoll then hg.applySeizurePostureToRagdoll(rag, org, 1) end
end

local function stop_seizure(owner, org)
	local wasActive = org.seizureActive
	org.seizure = 0
	org.seizureActive = false
	org.seizureStart = 0
	org.seizureEnd = 0
	org.nextSeizureSpasm = 0

	if wasActive and IsValid(owner) and owner:IsPlayer() and owner:Alive() then
		owner.fullsend = true
		send_organism(org, owner)
	end
end

local function start_seizure(owner, org)
	if org.seizureActive or not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end

	local time = CurTime()
	org.seizure = 1
	org.seizureActive = true
	org.seizureStart = time
	org.seizureEnd = time + seizure_duration
	org.nextSeizureSpasm = time
	owner.fullsend = true
	send_organism(org, owner)
end

local function resolve_panic_attacker(victim, attacker)
	if IsValid(attacker) then
		if attacker:IsPlayer() then
			return attacker
		end

		local owner = attacker.GetOwner and attacker:GetOwner()
		if IsValid(owner) and owner:IsPlayer() then
			return owner
		end
	end

	if IsValid(victim) and victim.GetPhysicsAttacker then
		local physicsAttacker = victim:GetPhysicsAttacker()
		if IsValid(physicsAttacker) and physicsAttacker:IsPlayer() then
			return physicsAttacker
		end
	end
end

local function panic_witness_event(victim, attacker, amount, radius, chanceMultiplier)
	if not IsValid(victim) then return end
	if not isnumber(amount) or amount <= 0 then return end

	local victimEnt = hg.GetCurrentCharacter(victim) or victim
	local victimPos = victimEnt.WorldSpaceCenter and victimEnt:WorldSpaceCenter() or victimEnt:GetPos()

	for _, watcher in ipairs(ents.FindInSphere(victimPos, radius)) do
		if not watcher:IsPlayer() or watcher == victim then continue end
		if not watcher:Alive() or not watcher.organism or watcher.organism.otrub then continue end
		if IsValid(attacker) and watcher == attacker then continue end

		local watcherEnt = hg.GetCurrentCharacter(watcher) or watcher
		local tr = util.TraceLine({
			start = watcher:EyePos(),
			endpos = victimPos,
			filter = {watcher, watcherEnt, victim, victimEnt, attacker},
			mask = MASK_SHOT
		})

		if tr.Hit then continue end

		hg.organism.AddPanicAttack(watcher.organism, amount, true, chanceMultiplier)
	end
end

local numerical = {
	"One.",
	"Two.",
	"Three.",
	"Four.",
	"Five.",
	"Six.",
	"Seven.",
	"Eight.",
	"Nine.",
	"Ten.",
	"Eleven.",
	"Twelve.",
	"Thirteen.",
	"Fourteen.",
	"Fifteen.",
	"Sixteen.",
	"Seventeen.",
	"Eighteen.",
	"Nineteen.",
	"Twenty."
}

hook.Add("HomigradDamage", "Berserk", function(ply, dmgInfo, hitgroup, ent)
	local attacker, victim = dmgInfo:GetAttacker(), ply
	if !attacker or !IsValid(attacker) or (IsValid(attacker) and !attacker:IsPlayer()) then
		attacker = ply:GetPhysicsAttacker()
	end

	if not IsValid(attacker) or not attacker:IsPlayer() then return end
	if not IsValid(victim) or not victim:IsPlayer() then return end
	if attacker == victim then return end
	if !attacker:IsBerserk() then return end

	timer.Simple(0, function()
		if IsValid(attacker) and IsValid(victim) and not victim:Alive() then
			attacker.BerserkKills = (attacker.BerserkKills or 0) + 1
			attacker:NotifyBerserk(numerical[attacker.BerserkKills] or (attacker.BerserkKills .. "."))

			attacker.organism.berserk = attacker.organism.berserk + 0.5
		end
	end)
end)

hook.Add("HomigradDamage", "PanicAttackDamage", function(ply, dmgInfo)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
	if not ply.organism then return end

	local amount = math.Clamp(dmgInfo:GetDamage() * panicattack_damage_scale + (dmgInfo:IsDamageType(DMG_BLAST) and 0.08 or 0), 0.03, 0.35)
	local attacker = resolve_panic_attacker(ply, dmgInfo:GetAttacker())

	hg.organism.AddPanicAttack(ply.organism, amount)
	if dmgInfo:GetDamage() <= 0 and not dmgInfo:IsDamageType(DMG_BLAST) then return end
	panic_witness_event(ply, attacker, math.Clamp(amount * 0.75, 0.04, 0.2), panicattack_witness_radius)
end)

hook.Add("EntityEmitSound", "PanicAttackExplosionNearby", function(data)
	local name = string.lower(data.SoundName or "")
	if name == "" then return end
	if not string.find(name, "explode", 1, true) and not string.find(name, "explosion", 1, true) then return end

	local pos = data.Pos
	if not pos or pos == vector_origin then
		local ent = data.Entity
		if isnumber(ent) then
			ent = Entity(ent)
		elseif not IsEntity(ent) then
			ent = nil
		end
		if not IsValid(ent) then return end
		pos = ent:GetPos()
	end

	local now = CurTime()
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then continue end
		local org = ply.organism
		if not org or org.otrub then continue end
		if (org.berserk or 0) > 0 or (org.noradrenaline or 0) > 0 then continue end
		if (org._panicNextExplosionEvent or 0) > now then continue end

		local dist = ply:GetPos():Distance(pos)
		if dist > 900 then continue end

		local threat = math.Clamp(1 - dist / 900, 0, 1)
		if threat <= 0 then continue end
		hg.organism.AddPanicAttack(org, 0.14 + threat * 0.28, true, 2.25)
		org._panicNextExplosionEvent = now + 0.75
	end
end)

hook.Add("EntityFireBullets", "PanicAttackNearBullets", function(ent, bulletData)
	if not IsValid(ent) then return end
	local src = bulletData and bulletData.Src
	local dir = bulletData and bulletData.Dir
	if not src or not dir then return end
	if dir:LengthSqr() <= 0 then return end
	local shooter = resolve_panic_attacker(nil, ent)
	if not IsValid(shooter) then
		shooter = resolve_panic_attacker(nil, bulletData.Attacker)
	end
	dir = dir:GetNormalized()
	local range = math.max(tonumber(bulletData.Distance) or 0, 1800)

	local now = CurTime()
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() or ply == shooter then continue end
		local org = ply.organism
		if not org or org.otrub then continue end
		if (org.berserk or 0) > 0 or (org.noradrenaline or 0) > 0 then continue end
		if (org._panicNextSuppression or 0) > now then continue end

		local eye = ply:EyePos()
		local toEye = eye - src
		local t = toEye:Dot(dir)

		local gunfightDist = ply:GetPos():Distance(src)
		if (org._panicNextGunfire or 0) <= now and gunfightDist <= 700 then
			local gunfightFalloff = math.Clamp(1 - gunfightDist / 700, 0, 1)
			hg.organism.AddPanicAttack(org, 0.12 + gunfightFalloff * 0.2, true, 2)
			org._panicNextGunfire = now + 0.9
		end

		if t <= 0 or t >= range then continue end
		local closest = src + dir * t
		local dist = eye:Distance(closest)
		if dist > 130 then continue end

		local tr = util.TraceLine({
			start = src,
			endpos = eye,
			filter = {ent, ply}
		})
		if tr.Hit and tr.Entity ~= ply then continue end

		local threat = math.Clamp(1 - dist / 130, 0, 1)
		if threat > 0 then
			hg.organism.AddPanicAttack(org, 0.18 + threat * 0.3, true, 2.75)
			org._panicNextSuppression = now + 0.45
		end

	end
end)

hook.Add("Org Think", "PanicAttackNearbyFire", function(owner, org, timeValue)
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
	if not org or org.otrub or org.givingUp then return end
	if (org._panicNextFireCheck or 0) > CurTime() then return end
	org._panicNextFireCheck = CurTime() + 1

	local closest = nil
	for _, ent in ipairs(ents.FindInSphere(owner:GetPos(), 450)) do
		if not IsValid(ent) or ent == owner then continue end
		local isFire = ent:GetClass() == "env_fire" or ent:GetClass() == "vfire" or ent:IsOnFire()
		if not isFire then continue end
		local dist = owner:GetPos():Distance(ent:GetPos())
		if not closest or dist < closest then closest = dist end
	end

	if closest then
		local falloff = math.Clamp(1 - closest / 450, 0, 1)
		hg.organism.AddPanicAttack(org, 0.06 + falloff * 0.12, true, 1.5)
	end
end)

-- One-handed behavior: wrist damage from heavy calibers and reduced control
hook.Add("EntityFireBullets", "OneHandedBehavior", function(ent, bulletData)
	if not IsValid(ent) or not ent:IsPlayer() then return end
	local org = ent.organism
	if not org or org.otrub then return end
	if string.lower(ent.PlayerClassName or "") == "slugcat" then return end

	-- Get weapon info
	local wep = ent:GetActiveWeapon()
	if not IsValid(wep) then return end
	if wep:GetClass() == "weapon_slugcat" then return end

	-- Determine if caliber is heavy based on ammo type
	local ammoType = wep:GetPrimaryAmmoType()
	local ammoData = hg.ammotypes[game.GetAmmoName(ammoType)]
	local isHeavyCaliber = false
	local caliberWeight = 0

	if ammoData and ammoData.BulletSettings then
		local bullet = ammoData.BulletSettings
		-- Heavy caliber criteria: high force, mass, or diameter
		local force = bullet.Force or 0
		local mass = bullet.Mass or 0
		local diameter = bullet.Diameter or 0

		-- Calculate caliber weight score
		caliberWeight = (force / 180) + (mass / 18) + (diameter / 14)
		if wep:GetClass() == "weapon_ptrd" or wep.Base == "weapon_ptrd" then
			caliberWeight = caliberWeight * 1.35
		end
		isHeavyCaliber = caliberWeight > 0.8
	end

	-- Check if left arm is damaged or amputated (one-handed condition)
	local leftArmDamaged = (org.larm and org.larm >= 1) or org.larmamputated or (org.larmdislocation or org.larmdislocated)
	local isPostureOneHanded = IsValid(wep) and wep.TwoHanded == false
	if not leftArmDamaged and not isPostureOneHanded then return end

	-- Posture-only one-handing (healthy left arm, weapon set TwoHanded = false): only penalize for heavy calibers
	if not leftArmDamaged and isPostureOneHanded then
		if not isHeavyCaliber then return end
		if not org.rarmamputated then
			local wristDamage = caliberWeight * 0.10
			org.rarm = math.min((org.rarm or 0) + wristDamage, 1)
		end
		org.painadd = (org.painadd or 0) + caliberWeight * 7
		return
	end

	-- Apply wrist damage for heavy calibers when one-handed
	if isHeavyCaliber then
		local wristDamage = caliberWeight * 0.15
		-- Damage the right arm (the only usable arm)
		if not org.rarmamputated then
			org.rarm = math.min((org.rarm or 0) + wristDamage, 1)
		end
		-- Add pain
		org.painadd = (org.painadd or 0) + wristDamage * 10
	end

	-- Chance to drop weapon based on caliber weight and arm damage
	if not org.rarmamputated then
		local armDamage = org.rarm or 0
		local dropChance = caliberWeight * 0.1 + armDamage * 0.15
		if math.random() < dropChance then
			ent:DropWeapon(wep)
			if ent:HasWeapon("weapon_hands_sh") then ent:SelectWeapon("weapon_hands_sh") end
		end
	end

	-- Apply reduced control for one-handed usage
	-- Increase recoil multiplier based on caliber weight and one-handed status.
	-- Keep it bounded so repeated shots do not permanently multiply recoil.
	local oneHandedPenalty = math.Clamp(1 + caliberWeight * 0.35, 1, 2.35)
	org.recoilmul = math.max(org.recoilmul or 1, oneHandedPenalty)

	-- Reduce arm strength for one-handed usage
	local armStrengthPenalty = math.Clamp(1 - caliberWeight * 0.12, 0.35, 1)
	org.armstrength = math.min(org.armstrength or 1, armStrengthPenalty)

	-- Apply worse control for one-handed postures (if weapon is two-handed but being used one-handed)
	local isTwoHandedWeapon = wep.TwoHanded ~= false
	if isTwoHandedWeapon then
		-- Additional penalty for using two-handed weapons one-handed
		org.recoilmul = math.max(org.recoilmul, 1.35)
		org.armstrength = math.min(org.armstrength, 0.7)
	end
end)



hook.Add("Org Think", "Main", function(owner, org, timeValue)
	if not IsValid(owner) then
		hg.organism.list[owner] = nil
		return
	end

	if owner:IsPlayer() and not owner:Alive() then
		org.alive = false
		hg.organism.ZeroVitals(org)
		return
	end

	local isPly = owner:IsPlayer()

	org.isPly = isPly

	if isPly or org.fakePlayer then
		if not org.fakePlayer then
			org.alive = owner:Alive()
		end
	else
		org.alive = false
	end

	org.needotrub = false
	org.needfake = false
	if isPly then
		org.ownerFake = org.FakeRagdoll and true
	else
		org.ownerFake = false
	end

	org.timeValue = timeValue
	org.incapacitated = false
	org.critical = false

	-- Aiming fatigue tracking (affects recoil multipliers)
	if isPly then
		local wep = owner:GetActiveWeapon()
		local isAiming = IsValid(wep) and wep.IsZoom and wep:IsZoom()

		if isAiming then
			if not org.aiming_start_time then
				org.aiming_start_time = CurTime()
			end
			local duration = CurTime() - org.aiming_start_time
			if duration >= 0.5 then
				-- Define debuff variables (include amputated arms)
				local rarm_broken_debuff = (org.rarm and org.rarm >= 1) or org.rarmamputated
				local larm_broken_debuff = (org.larm and org.larm >= 1) or org.larmamputated
				-- Define pain variables (exclude amputated arms)
				local rarm_broken_pain = (org.rarm and org.rarm >= 1) and not org.rarmamputated
				local larm_broken_pain = (org.larm and org.larm >= 1) and not org.larmamputated
				local rarm_dislocated = org.rarmdislocated or org.rarmdislocation
				local larm_dislocated = org.larmdislocated or org.larmdislocation

				-- Check for left hand mitigation: working left hand + damaged right hand
				-- Mitigation applies unless one-handing or left arm is damaged
				local leftHandHealthy = not org.larmamputated and not (org.larm and org.larm >= 1) and not (org.larmdislocation or org.larmdislocated)
				local rightHandDamaged = (org.rarm and org.rarm >= 1) or (org.rarmdislocation or org.rarmdislocated) or org.rarmamputated
				local isOneHanding = IsValid(wep) and wep.TwoHanded == false
				
				local debuffMitigation = 1
				if leftHandHealthy and rightHandDamaged and not isOneHanding then
					debuffMitigation = 0.6 -- Slightly mitigate debuffs (40% reduction)
				end

				-- Fatigue kicks in faster the longer you hold the aim.
				local duration_ramp = 1 + math.Clamp(duration - 0.5, 0, 12) * 0.18

				-- Stance affects fatigue: high ready (3) / low ready (4) are steadier
				-- (slower fatigue); any other stance fatigues slightly faster.
				local posture = owner.posture or 0
				local posture_fatigue_mult = (posture == 3 or posture == 4) and 0.7 or 1.25

				local fatigue_rate = timeValue * 0.7 * duration_ramp * posture_fatigue_mult

				org.aiming_fatigue = math.min((org.aiming_fatigue or 0) + fatigue_rate, 10)

				-- Increase aiming fatigue accumulation for broken/amputated arms
				if rarm_broken_debuff or larm_broken_debuff then
					local fatigue_multiplier = 1.5 * debuffMitigation
					if org.rarmamputated or org.larmamputated then
						fatigue_multiplier = 2.0 * debuffMitigation -- More severe for amputated arms
					end
					org.aiming_fatigue = math.min((org.aiming_fatigue or 0) + fatigue_rate * fatigue_multiplier, 10)
				end

				local pain_threshold = 4.0
				if rarm_broken_pain then
					pain_threshold = 1.5
				elseif rarm_dislocated then
					pain_threshold = 2.5
				end

				if duration > pain_threshold then
					local pain_rate = timeValue * 1.5
					if rarm_broken_pain then
						pain_rate = pain_rate * 3.0 * debuffMitigation
					elseif rarm_dislocated then
						pain_rate = pain_rate * 1.8 * debuffMitigation
					end

					org.painadd = org.painadd + pain_rate
				end
			end
		else
			org.aiming_start_time = nil
			org.aiming_fatigue = math.max((org.aiming_fatigue or 0) - timeValue * 0.3, 0)
		end
	end

	if isPly then
		module.stamina[2](owner, org, timeValue)
	end

	if isPly or org.fakePlayer then
		module.lungs[2](owner, org, timeValue)
	end

	local debugEyes = debug_destroy_eyes:GetInt()
	if debugEyes ~= (org.debugEyesMode or 0) then
		if debugEyes == 1 or debugEyes == 3 then
			org.eyeL = 1
		end
		if debugEyes == 2 or debugEyes == 3 then
			org.eyeR = 1
		end
		org.debugEyesMode = debugEyes
	end

	-- Latch a destroyed eye until its damage is fully healed. Passive recovery
	-- dipping from 1 to 0.99 must not make the blind side vanish immediately.
	if (org.eyeL or 0) >= 1 then org.eyeLDestroyed = true end
	if (org.eyeR or 0) >= 1 then org.eyeRDestroyed = true end
	if (org.eyeL or 0) <= 0 then org.eyeLDestroyed = nil end
	if (org.eyeR or 0) <= 0 then org.eyeRDestroyed = nil end

	local leftEyeBlind = org.eyeLDestroyed == true
	local rightEyeBlind = org.eyeRDestroyed == true
	if not leftEyeBlind and not rightEyeBlind then
		org.blindness = nil
	elseif leftEyeBlind and not rightEyeBlind then
		org.blindness = 2
	elseif rightEyeBlind and not leftEyeBlind then
		org.blindness = 1
	else
		org.blindness = 0
	end

	if isPly then
		module.liver[2](owner, org, timeValue)
	end

	--module.blood[3](owner,org,timeValue)--arteria
	module.blood[2](owner, org, timeValue)
	local neckslit = false
	if org.arterialwounds then
		for i, wound in pairs(org.arterialwounds) do
			if wound[7] == "arteria" and wound[1] > 0 then
				neckslit = true
				break
			end
		end
	end
	org.neckslit = neckslit

	if isPly then
		module.pain[2](owner, org, timeValue)
		module.metabolism[2](owner, org, timeValue)
		module.concussion[2](owner, org, timeValue)
		module.random_events[2](owner, org, timeValue)
		module.goodmood[2](owner, org, timeValue)
		if module.teeth and module.teeth[2] then module.teeth[2](owner, org, timeValue) end
	end



	module.pulse[2](owner, org, timeValue)

	if org.owner.PlayerClassName == "furry" then
		org.assimilated = 0
	end

	if org.owner.PlayerClassName != "furry" and org.furryinfected then
		org.assimilated = math.Approach(org.assimilated, 1, timeValue / 30 * org.pulse / 70)

		if org.assimilated == 1 then
			hg.Furrify(org.owner)

			org.furryinfected = false
		end
	else
		if (org.lightstun - CurTime()) <= 0 then
			org.assimilated = math.Approach(org.assimilated, 0, (timeValue / 60 * org.pulse / 70) * 6)
		end
	end

	if org.assimilated == 1 then
		org.assimilated = 0
		org.owner:SetPlayerClass("furry")
	end

	org.berserk = math.Approach(org.berserk, 0, timeValue / 60)
	org.noradrenaline = math.Approach(org.noradrenaline, 0, timeValue / 45)
	local oldPanicAttack = org.panicattack or 0
	org.panicattackadd = math.Approach(org.panicattackadd or 0, 0, timeValue / panicattack_add_decay_time)
	org.panicattack = math.Approach(oldPanicAttack, org.panicattackadd or 0, timeValue / ((org.panicattackadd or 0) > oldPanicAttack and panicattack_rise_time or panicattack_decay_time))
	local oldSeizureBrain = org.lastSeizureBrain or (org.brain or 0)
	local lobeDamage = getSeizureLobeDamage(org)
	local oldSeizureLobeDamage = org.lastSeizureLobeDamage or lobeDamage
	local oldSeizureTemperature = org.lastSeizureTemperature or (org.temperature or 36.7)
	org.tranexamic_acid = math.Approach(org.tranexamic_acid, 0, timeValue / 120) -- Tranexamic acid decays over 2 minutes

	if org.berserk > 0 and !org.berserkActive then
		org.berserkActive = true

		owner.lastBerserkLaughSoundCD = CurTime() + 5

		timer.Simple(3.95, function()
			org.berserkActive2 = true
		end)
	elseif org.berserk <= 0 then
		org.berserkActive = false
		org.berserkActive2 = false
		owner.BerserkKills = nil
	end

	if org.noradrenaline > 0 then
		org.noradrenalineActive = true
		org.noradrenalineEndTime = nil
	elseif org.noradrenaline <= 0 then
		if org.noradrenalineActive then
			org.noradrenalineEndTime = CurTime()
		end
		org.noradrenalineActive = false
	end

	if oldPanicAttack < panicattack_threshold and org.panicattack >= panicattack_threshold and isPly and owner:Alive() then
		owner:Notify("I can't calm down.", 2, "panicattack_start", 2, nil, Color(255, 140, 140))
	end

	if org.panicattack >= panicattack_threshold then
		org.panicattackActive = true
		org.disorientation = math.max(org.disorientation, 0.6 + panicattack_disorientation * org.panicattack)
		org.adrenalineAdd = math.Approach(org.adrenalineAdd or 0, math.Remap(org.panicattack, panicattack_threshold, 1, panicattack_adrenaline_add_target * 0.5, panicattack_adrenaline_add_target), timeValue / panicattack_adrenaline_add_rise_time)

		if isPly and CurTime() >= (org.nextPanicHeartRoll or 0) then
			org.nextPanicHeartRoll = CurTime() + panicattack_heart_roll_delay
			if math.random(100) <= panicattack_heart_roll_chance then
				org.heartstop = true
				owner:Notify("My heart just stopped.", 2, "panicattack_heartstop", 2, nil, Color(255, 120, 120))
			end
		end
	else
		org.panicattackActive = false
		org.nextPanicHeartRoll = CurTime() + panicattack_heart_roll_delay
	end

	local brainDelta = (org.brain or 0) - oldSeizureBrain
	local lobeDelta = lobeDamage - oldSeizureLobeDamage
	if brainDelta > 0 then
		hg.organism.AddSeizure(org, math.Clamp(brainDelta * seizure_brain_trauma_gain_mul, 0, 1))
	elseif brainDelta < 0 and oldSeizureBrain > 0 then
		hg.organism.AddSeizure(org, math.Clamp(-brainDelta * seizure_brain_heal_gain_mul, 0, 1))
	end
	if lobeDelta > 0 then
		hg.organism.AddSeizure(org, math.Clamp(lobeDelta * seizure_brain_trauma_gain_mul, 0, 1))
	end

	local temperature = org.temperature or 36.7
	local previousTemperature = oldSeizureTemperature
	local heatStress = math.max(temperature - seizure_temperature_high_start, previousTemperature - seizure_temperature_high_start, 0)
	local coldStress = math.max(seizure_temperature_low_start - temperature, seizure_temperature_low_start - previousTemperature, 0)
	local temperatureStress = math.max(heatStress, coldStress)
	if temperatureStress > 0 then
		hg.organism.AddSeizure(org, timeValue * temperatureStress * seizure_temperature_gain_mul)
	end

	local curTime = CurTime()
	local seizureBrainDamage = math.max(org.brain or 0, lobeDamage)
	if seizureBrainDamage > 0.05 then
		org.nextSeizureRoll = org.nextSeizureRoll or (curTime + seizure_brain_roll_delay)
		if curTime >= org.nextSeizureRoll then
			org.nextSeizureRoll = curTime + seizure_brain_roll_delay
			if math.random(seizure_brain_roll_chance) == 1 then
				hg.organism.AddSeizure(org, math.Rand(seizure_brain_roll_gain_min, seizure_brain_roll_gain_max) * math.Clamp(math.Remap(seizureBrainDamage, 0.05, 1, 0.75, 1.5), 0.75, 1.5))
			end
		end
	else
		org.nextSeizureRoll = curTime + seizure_brain_roll_delay
	end

	org.lastSeizureBrain = org.brain or 0
	org.lastSeizureLobeDamage = lobeDamage
	org.lastSeizureTemperature = temperature

	if org.seizure >= 1 and !org.seizureActive and isPly and owner:Alive() then
		start_seizure(owner, org)
	elseif org.seizureActive and org.seizure <= 0 then
		stop_seizure(owner, org)
	end

	if org.seizureActive then
		local time = CurTime()
		local seizureEnd = org.seizureEnd or time

		org.needfake = true
		owner.fakecd = math.max(owner.fakecd or 0, seizureEnd)

		if time >= seizureEnd then
			org.shock = math.max(org.shock or 0, seizure_end_shock)
			org.consciousness = 0
			org.needotrub = true
			stop_seizure(owner, org)
		else
			local rag = owner.FakeRagdoll
			if IsValid(rag) then
				apply_seizure_pose(rag, org, time)
			end
		end
	end

	if (org.llegamputated or org.rlegamputated) and org.berserk <= 0.3 then
		org.needfake = true
	end

	if org.rarmamputated and org.larmamputated and owner:IsPlayer() then
		local hands = owner:GetWeapon("weapon_hands_sh")
		if owner:GetActiveWeapon() != hands then
			owner:SetActiveWeapon(hands)
		end
	end

	if isPly then
		owner.aimed_at = owner.aimed_at or 0
		local aimed_at_target = owner.aimed_at_target

		if (org._nextAimedAtCheck or 0) <= CurTime() then
			org._nextAimedAtCheck = CurTime() + 0.15
			local aimed = false
			local aimedPos = nil
			local aimedDist = nil
			local ownerPos = owner:EyePos()
			local aimThreshold = -0.9
			local maxDistance = 800

			for _, ent in ipairs(player.GetAll()) do
				if ent == owner then continue end
				if not ent:Alive() then continue end

				local wep = ent:GetActiveWeapon()
				if not ishgweapon(wep) then continue end

				local entPos = ent:EyePos()
				local dist = ownerPos:Distance(entPos)
				if dist > maxDistance then continue end

				local toTarget = (ownerPos - entPos):GetNormalized()
				local aimDot = ent:GetAimVector():Dot(toTarget)

				if aimDot < aimThreshold then
					aimed = true
					aimedPos = entPos
					aimedDist = dist
					break
				end
			end

			if aimed and aimedPos then
				local canSee = util.TraceLine({
					start = ownerPos,
					endpos = aimedPos,
					filter = owner,
					mask = MASK_VISIBLE
				}).Fraction > 0.5

				if canSee or aimedDist < 200 then
					owner.aimed_at_target = true
				else
					owner.aimed_at_target = false
				end
			else
				owner.aimed_at_target = false
			end
		end

		if owner.aimed_at_target then
			owner.aimed_at = math.Approach(owner.aimed_at, 1, timeValue / 3)
			org.fearadd = org.fearadd + timeValue * 1.5
		else
			owner.aimed_at = math.Approach(owner.aimed_at, 0, timeValue / 5)
		end
	end

	if org.otrub then
		org.uncon_timer = org.uncon_timer or 0
		org.uncon_timer = org.uncon_timer + timeValue
	else
		org.uncon_timer = 0
	end

	local just_went_uncon = not org.otrub and org.needotrub
	

	local just_woke_up = not org.needotrub and org.otrub and (org.uncon_timer or 0) > 6
	if isPly and just_went_uncon then hook.Run("HG_OnOtrub", owner); hook.Run("PlayerDropWeapon", owner) end
	if isPly and just_woke_up then hook.Run("HG_OnWakeOtrub", owner) end

	org.canmove = (org.spine2 < hg.organism.fake_spine2 and org.spine3 < hg.organism.fake_spine3) and not org.otrub
	org.canmovehead = (org.spine3 < hg.organism.fake_spine3) and not org.otrub
	
	-- Spine damage effects: reduce capabilities based on which part is damaged
	-- spine1 = lower spine (legs), spine2 = chest (arms), spine3 = neck (breathing + everything)
	-- Effects start at spine damage > 0.4 (broken at 0.8), never go below 0.1
	local fake1 = hg.organism and hg.organism.fake_spine1 or 1
	local fake2 = hg.organism and hg.organism.fake_spine2 or 1
	local fake3 = hg.organism and hg.organism.fake_spine3 or 0.75
	local threshold = 0.4
	
	-- Default values
	org.legstrength = 1
	org.armstrength = 1
	org.meleespeed = 1
	org.breathing = 1
	
	-- spine1 damage (> 0.4) reduces leg strength - affects walk/run/jump/kick
	if org.spine1 and org.spine1 > threshold then
		local damageFactor = (org.spine1 - threshold) / (fake1 - threshold)
		org.legstrength = math.max(1 - damageFactor * 0.9, 0.1)
	end
	
	-- spine2 damage (> 0.4) reduces arm strength and melee speed - affects weapon control/dragging/melee
	if org.spine2 and org.spine2 > threshold then
		local damageFactor = (org.spine2 - threshold) / (fake2 - threshold)
		org.armstrength = math.max(1 - damageFactor * 0.9, 0.1)
		org.meleespeed = math.max(1 - damageFactor * 0.6, 0.4)
	end
	
	-- spine3 damage (> 0.4) reduces breathing and overall strength
	if org.spine3 and org.spine3 > threshold then
		local damageFactor = (org.spine3 - threshold) / (fake3 - threshold)
		org.breathing = math.max(1 - damageFactor * 0.7, 0.1)
		-- spine3 also affects leg and arm strength when severe
		org.legstrength = org.legstrength * math.max(1 - damageFactor * 0.5, 0.1)
		org.armstrength = org.armstrength * math.max(1 - damageFactor * 0.5, 0.1)
	end

	-- One-handed posture penalties (continuous effects when left arm is damaged/amputated)
	if isPly then
		local leftArmDamaged = (org.larm and org.larm >= 1) or org.larmamputated or (org.larmdislocation or org.larmdislocated)
		if leftArmDamaged then
			-- General reduced control for one-handed posture
			org.recoilmul = (org.recoilmul or 1) * 1.15
			org.armstrength = (org.armstrength or 1) * 0.85

			-- Additional penalty if holding a two-handed weapon
			local wep = owner:GetActiveWeapon()
			if IsValid(wep) and wep.TwoHanded ~= false then
				org.recoilmul = org.recoilmul * 1.3
				org.armstrength = org.armstrength * 0.75
			end

		end
	end

	if not (org.canmove and org.canmovehead and (org.stun - CurTime()) < 0) then org.needfake = true end
	if (org.blood < 2500) then org.needfake = true end

	local just_went_uncon = not org.otrub and org.needotrub

	if org.postureType == "decerebrate" then //-- the decerebrate one
		local ent = hg.GetCurrentCharacter(org.owner)

		local rleg = ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_R_Foot")))
		local lleg = ent:GetPhysicsObjectNum(ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_L_Foot")))

		local down = -ent:GetBoneMatrix(ent:LookupBone("ValveBiped.Bip01_Spine")):GetAngles():Forward()
		if IsValid(rleg) and IsValid(lleg)then
			rleg:ApplyForceCenter(down * 500)
			lleg:ApplyForceCenter(down * 500)
		end
	end

	-- Thiamine healing logic
	org.thiamine = math.Approach(org.thiamine, 0, timeValue / 240)

	if org.thiamine > 0 then
		if not org.thiamine_healed then
			org.thiamine_timer = org.thiamine_timer + timeValue
			local heal_delay = (org.satiety or 0) > 50 and 20 or 60

			if org.thiamine_timer > heal_delay then
				org.thiamine_healed = true
			end
		end
	else
		org.thiamine_timer = 0
		org.thiamine_healed = false
	end

	if org.thiamine_healed then
		local thiamineHealRate = timeValue / 480
		-- Heal all organs
		local organs_to_heal = {
			"liver", "heart", "stomach", "intestines", "brain", "jaw",
			"spine1", "spine2", "spine3", "chest", "pelvis", "skull", "trachea",
			"lleg", "rleg", "larm", "rarm"
		}

		local oldSpine1 = org.spine1 or 0
		local oldSpine2 = org.spine2 or 0
		local oldPelvis = org.pelvis or 0

		for _, organ in ipairs(organs_to_heal) do
			if org[organ] and org[organ] > 0 then
				org[organ] = math.Approach(org[organ], 0, thiamineHealRate)
			end
		end

		-- Remove spine floppy constraints when spine heals below break threshold
		if hg.RemoveSpineConstraints then
			local fake1 = hg.organism and hg.organism.fake_spine1 or 1
			local fake2 = hg.organism and hg.organism.fake_spine2 or 1
			if (oldSpine1 >= fake1 and org.spine1 < fake1) or (oldPelvis >= 1 and org.pelvis < 1) then
				hg.RemoveSpineConstraints(org.owner, "spine1")
			end
			if oldSpine2 >= fake2 and org.spine2 < fake2 then
				hg.RemoveSpineConstraints(org.owner, "spine2")
			end
		end

		if org.lungsR and org.lungsR[1] > 0 then org.lungsR[1] = math.Approach(org.lungsR[1], 0, thiamineHealRate) end
		if org.lungsL and org.lungsL[1] > 0 then org.lungsL[1] = math.Approach(org.lungsL[1], 0, thiamineHealRate) end
		if org.lungsR and org.lungsR[2] > 0 then org.lungsR[2] = math.Approach(org.lungsR[2], 0, thiamineHealRate) end
		if org.lungsL and org.lungsL[2] > 0 then org.lungsL[2] = math.Approach(org.lungsL[2], 0, thiamineHealRate) end
	end

	if org.otrub and isPly and org.owner:Alive() then
		//org.owner:ScreenFade(SCREENFADE.PURGE, color_black, 0.5, 0)
		//org.owner:ConCommand("soundfade 100 99999")
	end

	if not org.otrub and isPly and org.owner:Alive() then
		--org.owner:ConCommand("soundfade 0 1")
	end

	local incapacitationMode = hg_incapacitation:GetInt()
	local scavDyingMode = hg_scavdying:GetInt()
	local flatlined = org.heartstop or (org.heartbeat or 0) < 1 or (org.pulse or 0) < 1
	local dyingIncapacitated = isPly and org.otrub and org.incapacitated

	if incapacitationMode > 0 and dyingIncapacitated then
		if not org.deathStateStart and not org.deathStatePendingEnd then
			local delay = 0
			-- Ring mode is an immediate, fixed twenty-second countdown once the
			-- player is incapacitated.  Do not hold it behind the injury/asystole
			-- delay used by the non-ring delayed-death mode.
			if incapacitationMode == 2 and scavDyingMode ~= 1 then
				local injury = math.max(
					math.Clamp((3000 - (org.blood or 5000)) / 1800, 0, 1),
					math.Clamp((10 - (org.o2 and org.o2[1] or 30)) / 10, 0, 1),
					math.Clamp(((org.brain or 0) - 0.2) / 0.5, 0, 1),
					flatlined and 1 or 0
				)
				delay = Lerp(injury, 30, 10)
			end
			org.deathStateFadeStart = scavDyingMode == 0 and (CurTime() + delay) or nil
			org.deathStatePendingEnd = CurTime() + delay + (scavDyingMode == 0 and 2 or 0)
		end

		if not org.deathStateStart and CurTime() >= org.deathStatePendingEnd then
			org.deathStateStart = CurTime()
			local duration = 20
			org.deathStateEnd = org.deathStateStart + duration
		end

		if org.deathStateEnd and CurTime() >= org.deathStateEnd and not org.deathStateKilled then
			org.deathStateKilled = true
			owner:Kill()
			return
		end
	else
		org.deathStateEnd = nil
		org.deathStateStart = nil
		org.deathStatePendingEnd = nil
		org.deathStateFadeStart = nil
		org.deathStateKilled = nil
	end

	if just_went_uncon then
		org.owner.fullsend = true
	end

	if org.brain > 0.05 then
		if math.random(600) < org.brain * 20 then
			org.needfake = true
		end
	end

	if org.neckslitSoundName and (org.otrub or org.needotrub) then
		if IsValid(org.neckslitSoundEnt) then
			org.neckslitSoundEnt:StopSound(org.neckslitSoundName)
		end
		if IsValid(owner) then
			owner:StopSound(org.neckslitSoundName)
		end
		org.neckslitSoundName = nil
		org.neckslitSoundEnt = nil
	end

	    org.was_otrub = org.otrub

	org.otrub = org.needotrub
	org.fake = org.needfake
		if org.needfake and owner:IsNPC() then
		local dmgInfo = DamageInfo()
		dmgInfo:SetDamage(10000)
		dmgInfo:SetAttacker(owner)
		owner:TakeDamageInfo(dmgInfo)
	end

	org.health = owner:Health()
	local rag = owner:IsPlayer() and owner.FakeRagdoll or owner
	if IsValid(rag) and rag:IsRagdoll() and (not owner.lastFake or owner.lastFake == 0) then
		local wantedCollisionGroup = (rag:GetVelocity():LengthSqr() > (200 * 200)) and COLLISION_GROUP_NONE or COLLISION_GROUP_WEAPON
		if rag:GetCollisionGroup() ~= wantedCollisionGroup then
			hg.ApplySetCollisionGroupNow(rag, wantedCollisionGroup)
		end
	end
	if isPly then
		if org.otrub or org.fake then hg.Fake(owner,nil,true) end
		if not org.alive and owner:Alive() then owner:Kill() end
	end

	if not org.otrub and isPly then
		local mul = hg.likely_to_phrase(owner)

		if not org.likely_phrase then org.likely_phrase = 0 end

				org.likely_phrase = math.max(org.likely_phrase + math.Rand(0, mul) / 50, 0)
		//print(org.likely_phrase)
		if org.likely_phrase >= 1 and !hg.GetCurrentCharacter(owner):IsOnFire() then
			org.likely_phrase = 0

			local str = hg.get_status_message(owner)
			//print(str)
			-- (msg, delay, msgKey, showTime, func, clr)
			owner:Notify(str, 1, "phrase", 1, nil, hg.get_notify_color(owner))
		end
	end

	if !org.alive then org.otrub = true end

	if !org.alive then
		org.lungsfunction = false
		hg.organism.ZeroVitals(org)
	end

	-- A heartstop can be triggered by systems that run after the pulse module
	-- (for example panic). Normalize the replicated state before clients draw
	-- the ECG or organism stats so the rhythm can never lag behind heartstop.
	if hg.organism.GetECGState then
		org.ecgState = hg.organism.GetECGState(org.heartbeat or 0, org.heartstop, org)
	end
	if org.heartstop then
		org.cardiacArrestStart = org.cardiacArrestStart or CurTime()
		org.cardiacArrestO2Start = math.Clamp(org.cardiacArrestO2Start or (org.o2 and org.o2[1] or 0), 0, 6)
		org.pulse = 0
		org.cardiacOutput = 0
		org.bloodpressure = 0
		org.systolic = 0
		org.diastolic = 0
	end

	time = CurTime()

	if IsValid(owner) then
		org.sendPlyTime = org.sendPlyTime or CurTime()
		if (org.sendPlyTime > time) and !just_went_uncon then return end
		org.sendPlyTime = CurTime() + 1 + (not isPly and 2 or 0)
		send_bareinfo(org)
		hg.organism.SyncWounds(org)

		if isPly and owner:Alive() then
			send_organism(org, owner)
		end
	end
end)

hook.Add("Org Think", "regenerationberserk", function(owner, org, timeValue)
	if not owner:IsPlayer() or not owner:Alive() then return end
	if !owner:IsBerserk() then return end
	//if org.heartstop then return end

	org.blood = math.Approach(org.blood, 5000, timeValue * 60)

	for i, wound in pairs(org.wounds) do
		wound[1] = math.max(wound[1] - timeValue * 10,0)
	end

	for i, wound in pairs(org.arterialwounds) do
		wound[1] = math.max(wound[1] - timeValue * 10,0)
	end

	org.internalBleed = math.max(org.internalBleed - timeValue * 10, 0)

	local regen = timeValue / 120 * org.berserk

	local oldLleg, oldRleg, oldRarm, oldLarm = org.lleg, org.rleg, org.rarm, org.larm
	org.lleg = math.max(org.lleg - regen, 0)
	org.rleg = math.max(org.rleg - regen, 0)
	org.rarm = math.max(org.rarm - regen, 0)
	org.larm = math.max(org.larm - regen, 0)
	-- Constraints are only applied on death/heal/neck break events and persist until next ragdoll
	-- Do not remove constraints when limbs heal
	org.chest = math.max(org.chest - regen, 0)
	local oldPelvis = org.pelvis
	org.pelvis = math.max(org.pelvis - regen, 0)
	local oldSpine1 = org.spine1
	local oldSpine2 = org.spine2
	local oldSpine3 = org.spine3
	org.spine1 = math.max(org.spine1 - regen, 0)
	org.spine2 = math.max(org.spine2 - regen, 0)
	org.spine3 = math.max(org.spine3 - regen, 0)
	-- Constraints are only applied on death/heal/neck break events and persist until next ragdoll
	-- Do not remove spine/neck constraints when they heal
	org.skull = math.max(org.skull - regen, 0)

	org.liver = math.max(org.liver - regen, 0)
	org.intestines = math.max(org.intestines - regen, 0)
	org.heart = math.max(org.heart - regen, 0)
	org.stomach = math.max(org.stomach - regen, 0)
	org.lungsR[1] = math.max(org.lungsR[1] - regen, 0)
	org.lungsL[1] = math.max(org.lungsL[1] - regen, 0)
	org.lungsR[2] = math.max((org.lungsR[2] or 0) - regen, 0)
	org.lungsL[2] = math.max((org.lungsL[2] or 0) - regen, 0)
	org.eyeL = math.max((org.eyeL or 0) - regen, 0)
	org.eyeR = math.max((org.eyeR or 0) - regen, 0)
	local oldBrain = org.brain or 0
	org.brain = math.max(oldBrain - regen, 0)
	hg.organism.AddSeizure(org, math.Clamp((oldBrain - org.brain) * seizure_brain_heal_gain_mul, 0, 1))
	org.lastSeizureBrain = org.brain

	org.hungry = 0

	org.pain = math.Approach(org.pain, 0, timeValue * 10)
	org.painadd = math.Approach(org.painadd, 0, timeValue * 10)
	org.avgpain = math.Approach(org.avgpain, 0, timeValue * 10)
	org.shock = math.Approach(org.shock, 0, timeValue * 10)
	org.immobilization = math.Approach(org.immobilization, 0, timeValue * 10)
	org.disorientation = math.Approach(org.disorientation, 0, timeValue * 10)

	org.lungsfunction = true
	org.heartstop = false

	owner:SetRunSpeed(math.min(500, 400 + (25 * org.berserk)))
end)

hook.Add("Org Think", "regenerationnoradrenaline", function(owner, org, timeValue)
	if not owner:IsPlayer() or not owner:Alive() then return end
	if org.noradrenaline <= 0 then return end
	
	local regen = timeValue / 60 * org.noradrenaline

	org.lungsR[1] = math.max(org.lungsR[1] - regen, 0)
	org.lungsL[1] = math.max(org.lungsL[1] - regen, 0)
	org.lungsR[2] = math.max((org.lungsR[2] or 0) - regen, 0)
	org.lungsL[2] = math.max((org.lungsL[2] or 0) - regen, 0)
	org.eyeL = math.max((org.eyeL or 0) - regen, 0)
	org.eyeR = math.max((org.eyeR or 0) - regen, 0)

	org.hungry = 0

	org.pain = math.Approach(org.pain, 0, regen * 10)
	org.painadd = math.Approach(org.painadd, 0, regen * 10)
	org.avgpain = math.Approach(org.avgpain, 0, regen * 10)
	org.shock = math.Approach(org.shock, 0, regen * 10)
	org.immobilization = math.Approach(org.immobilization, 0, regen * 10)
	org.disorientation = math.Approach(org.disorientation, 0, regen * 10)
	org.adrenaline = math.Approach(org.adrenaline, 4, regen * 10)
	org.analgesia = math.Approach(org.analgesia, 1, regen * 10)

	if org.noradrenaline > 2 then
		local oldBrain = org.brain or 0
		org.brain = math.Approach(oldBrain, 0.3, timeValue / 60)
		hg.organism.AddSeizure(org, math.Clamp((oldBrain - org.brain) * seizure_brain_heal_gain_mul, 0, 1))
		org.lastSeizureBrain = org.brain
	end

	org.pulse = math.Approach(org.pulse, 70, regen * 10)
	org.heartbeat = math.Approach(org.heartbeat, 220, regen * 10)
	org.bloodpressure = math.Approach(org.bloodpressure or 93, 110, regen * 8)
	org.systolic = math.Approach(org.systolic or 120, 140, regen * 8)
	org.diastolic = math.Approach(org.diastolic or 80, 90, regen * 8)

	org.lungsfunction = true
	org.heartstop = false
end)

concommand.Add("hg_organism_setvalue", function(ply, cmd, args)
	if not ply:IsAdmin() then return end

	if not args[3] then
		if isbool(ply.organism[args[1]]) then
			ply.organism[args[1]] = tonumber(args[2]) != 0
		else
			ply.organism[args[1]] = tonumber(args[2])
		end
	end

	if args[3] then
		for i,pl in pairs(player.GetListByName(args[3])) do
			if isbool(pl.organism[args[1]]) then
				pl.organism[args[1]] = tonumber(args[2]) != 0
			else
				pl.organism[args[1]] = tonumber(args[2])
			end
		end
	end
end)

concommand.Add("hg_organism_setvalue2", function(ply, cmd, args)
	if not ply:IsAdmin() then return end

	ply.organism[args[1]][tonumber(args[2])] = tonumber(args[3])
end)

concommand.Add("hg_organism_clear", function(ply, cmd, args)
	if not ply:IsAdmin() then return end

	if not args[1] then
		hg.organism.Clear(ply.organism)
	end

	if args[1] then
		for i,pl in pairs(player.GetListByName(args[1])) do
			hg.organism.Clear(pl.organism)
		end
	end
end)

hook.Add("SetupMove", "hg-speed", function(ply, mv) end) --mv:SetMaxClientSpeed(100) --mv:SetMaxSpeed(100)

hook.Add("StartCommand","hg_lol",function(ply,cmd)
	if not ply:Alive() or not ply.organism then return end
	if ply.organism.seizureActive then
		cmd:ClearMovement()
		cmd:ClearButtons()
	elseif ply.organism.otrub then
		cmd:ClearMovement()
	end
end)

hook.Add("PlayerDeath","next-respawn-full",function(ply)
	ply.fullsend = true
end)

hook.Add("PlayerDeath", "PanicAttackWitnessDeath", function(victim, inflictor, attacker)
	local realAttacker = resolve_panic_attacker(victim, attacker)
	panic_witness_event(victim, realAttacker, 0.22, panicattack_death_radius, 2)
end)

hook.Add("OnNPCKilled", "PanicAttackWitnessNPCDeath", function(victim, attacker, inflictor)
	local realAttacker = resolve_panic_attacker(victim, attacker)
	panic_witness_event(victim, realAttacker, 0.16, panicattack_death_radius, 2)
end)

hook.Add("HG_OnWakeOtrub", "afterOtrub", function( owner )
	owner.organism.after_otrub = true
	local str = hg.get_status_message(owner)
	owner.organism.after_otrub = nil
	//print(str)
	-- (msg, delay, msgKey, showTime, func, clr, traumatic)
	timer.Simple(0.1,function()
		if not IsValid(owner) then return end
		owner:Notify(str, 1, "wake", 1, nil, hg.get_notify_color(owner))
	end)

	owner.organism.fearadd = owner.organism.fearadd + 5

	owner:SendLua("system.FlashWindow()")
end)

hook.Add("HG_OnOtrub", "fearful", function( plya )// ЧЕ
	local ent = hg.GetCurrentCharacter(plya)
	for i,ply in ipairs(ents.FindInSphere(ent:GetPos(),256)) do
		if not ply:IsPlayer() or not ply.organism or plya == ply then continue end

		local tr = {}
		tr.start = ply:GetPos()
		tr.endpos = ent:GetPos()
		tr.filter = {ply,ent}
		if not util.TraceLine(tr).Hit then
			ply.organism.adrenalineAdd = ply.organism.adrenalineAdd + 0.3
			ply.organism.fearadd = ply.organism.fearadd + 0.3
		end
	end
end)

local unlucky_dislocations = {
	"Why can't I fix this goddamn dislocation...",
	"Please... why is it so hard.",
	"Just go back in place already...",
	"This is irritating",
	"I should try again",
}

local finally_fixed = {
	"Finally.",
	"That was harder than I thought",
	"One dislocation away.",
}

local function fixlimb(org, key, fixer)
	if math.random(100) > (97 + (fixer != org.owner and (fixer.organism and fixer.organism.pain or 0) or 0) - (org.analgesia * 50 + org.painkiller * 15) - (fixer != org.owner and 30 or 0) - (fixer.tries or 0) * 10 - (fixer.Profession == "doctor" and 100 or 0) - (org.owner == fixer and (IsValid(org.owner.FakeRagdoll) or (org.owner.Crouching and org.owner:Crouching())) and 10 or 0)) then
		org[key.."dislocation"] = false
		if hg.fakeBoneFlop and hg.fakeBoneFlop.ClearStoredLimb(org, key) then
			hg.fakeBoneFlop.ScheduleRebuild(org.owner)
		end
		org.painadd = org.painadd + 5 * math.random(1, 3)
		org.fearadd = org.fearadd + 0.1

		org.owner:EmitSound("physics/flesh/flesh_impact_hard6.wav", 65)

		if fixer == org.owner and (fixer.tries or 0) > 3 and math.random(3) == 1 then
			fixer:Notify(finally_fixed[math.random(#finally_fixed)], 1, "dislocations_unlucky", 1, nil, Color(255, 255, 255, 255))
		end

		fixer.tries = 0
	else
		fixer.tries = (fixer.tries or 0) + 1
		org.painadd = org.painadd + 15 * math.random(1, 3)

		org.fearadd = org.fearadd + 0.3

		org.owner:EmitSound("physics/body/body_medium_impact_soft"..math.random(7)..".wav", 65)
		
		if fixer.Profession != "doctor" and math.random(5) == 1 then
			local dmgInfo = DamageInfo()
			dmgInfo:SetDamage(50)
			dmgInfo:SetDamageType(DMG_CLUB)
			hg.organism.input_list[key.."down"](org.owner.organism, 1, 6, dmgInfo, 0, vector_up)
		end

		if fixer == org.owner and fixer.tries > 3 and math.random(3) == 1 then
			fixer:Notify(unlucky_dislocations[math.random(#unlucky_dislocations)], 1, "dislocations_unlucky", 1, nil, Color(255, 255, 255, 255))
		end
	end
end

concommand.Add("hg_fixdislocation", function(ply, cmd, args)
	local fixer = ply

	if args and args[2] and math.Round(tonumber(args[2])) == 1 then
		ply = hg.eyeTrace(fixer).Entity
	end

	if !IsValid(ply) or !ply.organism then return end

	ply = ply.organism.owner

	local org = ply.organism
	if !fixer:Alive() or !org or fixer.organism.otrub then return end
	if (fixer.tried_fixing_limb or 0) > CurTime() then return end
	if !fixer.organism.canmove or !fixer.organism.canmovehead or fixer.organism.pain > 60 then return end
	fixer.tried_fixing_limb = CurTime() + fixer.organism.pain / 30

	if math.Round(tonumber(args[1])) == 1 then
		if org.llegdislocation then
			fixlimb(org, "lleg", fixer)
		elseif org.rlegdislocation then
			fixlimb(org, "rleg", fixer)
		end
	elseif math.Round(tonumber(args[1])) == 2 then
		if org.larmdislocation then
			fixlimb(org, "larm", fixer)
		elseif org.rarmdislocation then
			fixlimb(org, "rarm", fixer)
		end
	elseif math.Round(tonumber(args[1])) == 3 then
		if org.jawdislocation then
			fixlimb(org, "jaw", fixer)
		end
	end
end)

hook.Add("OnEntityWaterLevelChanged", "ClearBlood", function(ent, old, new)
	if new >= 2 then
		if ent:IsOnFire() then ent:Extinguish() end
		ent:RemoveAllDecals()
	end
end)
