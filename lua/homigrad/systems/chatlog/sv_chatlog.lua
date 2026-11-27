util.AddNetworkString("hg_chatlog_event")

local ChatLog = hg.ChatLog

local CurTime = CurTime
local IsValid = IsValid

local HEAD_BONE = "ValveBiped.Bip01_Head1"
local CUT_DAMAGE_MIN = 5
local CUT_COOLDOWN = 0.4
local BLOCKED_COOLDOWN = 4
local GUNSHOT_ARG_NONE = 0
local SEVERITY_STRAINED = 0.4
local SEVERITY_PANIC = 0.75
local RUN_STAMINA_FRACTION = 0.25
local RUN_OXYGEN_MIN = 15
local BLOCKED_COLOR = Color(255, 205, 170)

local HAND_WEAPONS = {
	weapon_hg_coolhands = true,
	weapon_hands_sh = true,
}

local function NewThoughts(ply)
	return ply:GetInfoNum("hg_newthoughts", 0) > 0
end

local function IsAware(ply)
	if not ply:Alive() then return false end

	return not (ply.organism and ply.organism.otrub)
end

local function IsStunned(ply)
	local org = ply.organism
	if not org then return false end

	local now = CurTime()

	return (org.stun or 0) > now or (org.lightstun or 0) > now
end

local function SourcePos(actor)
	local character = hg.GetCurrentCharacter(actor)
	if IsValid(character) and character ~= actor then
		local bone = character:LookupBone(HEAD_BONE)
		local pos = bone and character:GetBonePosition(bone)
		if pos then return pos end

		return character:WorldSpaceCenter()
	end

	return actor:EyePos()
end

function ChatLog.Emit(key, actor, target, extraEnt, arg)
	local event = ChatLog.ByKey[key]
	if not event or not IsValid(actor) then return end

	local now = CurTime()
	actor.hgChatLogNext = actor.hgChatLogNext or {}
	if (actor.hgChatLogNext[event.id] or 0) > now then return end
	actor.hgChatLogNext[event.id] = now + (event.cooldown or 0.5)

	local pos = SourcePos(actor)
	local rangeSqr = event.range * event.range
	local visualOnly = event.heard == nil
	local filter = RecipientFilter()
	local told
	if event.repeatEvery then
		local group = event.repeatGroup or event.key
		actor.hgChatLogTold = actor.hgChatLogTold or {}
		told = actor.hgChatLogTold[group]
		if not told then
			told = setmetatable({}, {__mode = "k"})
			actor.hgChatLogTold[group] = told
		end
	end

	for _, ply in player.Iterator() do
		if (ply == actor and not event.toActor) or not IsAware(ply) then continue end
		if ply:EyePos():DistToSqr(pos) > rangeSqr then continue end
		if visualOnly and not ply:TestPVS(pos) then continue end
		if told and (told[ply] or 0) > now then continue end

		if told then told[ply] = now + event.repeatEvery end
		filter:AddPlayer(ply)
	end

	if filter:GetCount() == 0 then return end

	net.Start("hg_chatlog_event")
		net.WriteUInt(event.id, ChatLog.NET_ID_BITS)
		net.WriteEntity(actor)
		net.WriteEntity(IsValid(target) and target or NULL)
		net.WriteEntity(IsValid(extraEnt) and extraEnt or NULL)
		net.WriteUInt(arg or 0, ChatLog.NET_ARG_BITS)
		net.WriteVector(pos)
	net.Send(filter)
end

function ChatLog.EmitWorld(key, pos, recipient)
	local event = ChatLog.ByKey[key]
	if not event or not IsValid(recipient) or not IsAware(recipient) then return end

	local now = CurTime()
	recipient.hgChatLogNext = recipient.hgChatLogNext or {}
	if (recipient.hgChatLogNext[event.id] or 0) > now then return end
	recipient.hgChatLogNext[event.id] = now + (event.cooldown or 0.5)

	net.Start("hg_chatlog_event")
		net.WriteUInt(event.id, ChatLog.NET_ID_BITS)
		net.WriteEntity(NULL)
		net.WriteEntity(NULL)
		net.WriteEntity(NULL)
		net.WriteUInt(0, ChatLog.NET_ARG_BITS)
		net.WriteVector(pos)
	net.Send(recipient)
end

local function ResolvePlayer(ent)
	if not IsValid(ent) then return end
	if ent:IsPlayer() then return ent end
	if ent:IsRagdoll() and hg.RagdollOwner then
		local owner = hg.RagdollOwner(ent)
		if IsValid(owner) and owner:IsPlayer() then return owner end
	end
end

local BULLET_IMPACT_DIST = 350
local BULLET_FLYBY_DIST = 120
local BULLET_FLYBY_CUE_DIST = 300

function ChatLog.BulletPath(shooter, src, hitPos, hitEnt)
	if not isvector(src) or not isvector(hitPos) then return end

	local dir = hitPos - src
	local length = dir:Length()
	if length <= 0 then return end
	dir:Mul(1 / length)

	local hitPly = ResolvePlayer(hitEnt)
	for _, ply in player.Iterator() do
		if ply == shooter or ply == hitPly or not IsAware(ply) then continue end

		local eye = ply:EyePos()
		if eye:DistToSqr(hitPos) <= BULLET_IMPACT_DIST * BULLET_IMPACT_DIST then
			ChatLog.EmitWorld("bulletimpact", hitPos, ply)

			continue
		end

		local projection = (eye - src):Dot(dir)
		if projection <= 0 or projection >= length then continue end

		local offset = src + dir * projection - eye
		if offset:LengthSqr() > BULLET_FLYBY_DIST * BULLET_FLYBY_DIST then continue end

		if offset:LengthSqr() < 1 then offset = -dir end
		offset:Normalize()
		ChatLog.EmitWorld("bulletflyby", eye + offset * BULLET_FLYBY_CUE_DIST, ply)
	end
end

function ChatLog.Swing(owner, wep)
	if not IsValid(owner) or not owner:IsPlayer() then return end

	local fist = IsValid(wep) and HAND_WEAPONS[wep:GetClass()]
	ChatLog.Emit(fist and "swingfist" or "swingnear", owner, nil, wep)
end

local function IsMeleeWeapon(wep)
	return IsValid(wep) and wep:IsWeapon() and (wep.ismelee or wep.ismelee2)
end

local function ClassifyHit(attacker, inflictor, dmgInfo)
	if dmgInfo:IsDamageType(DMG_BULLET) or dmgInfo:IsDamageType(DMG_BUCKSHOT) then return "shoot" end

	local slash = dmgInfo:IsDamageType(DMG_SLASH)
	if not slash and not dmgInfo:IsDamageType(DMG_CLUB) then return end

	if IsValid(inflictor) and HAND_WEAPONS[inflictor:GetClass()] then return "punch" end

	local wep = IsMeleeWeapon(inflictor) and inflictor or attacker:GetActiveWeapon()
	if IsMeleeWeapon(wep) then return slash and "slash" or "melee", wep end

	if inflictor == attacker or not IsValid(inflictor) then return "strike" end
end

local function SendThoughtCut(ply)
	local now = CurTime()
	if (ply.hgThoughtCutNext or 0) > now then return end
	ply.hgThoughtCutNext = now + CUT_COOLDOWN

	net.Start("HGThought")
		net.WriteString("")
		net.WriteColor(color_white)
		net.WriteString("cut")
	net.Send(ply)
end

hook.Add("HomigradDamage", "hg/chatlog/hits", function(victimEnt, dmgInfo)
	local victim = ResolvePlayer(victimEnt)
	if not victim then return end

	if dmgInfo:GetDamage() >= CUT_DAMAGE_MIN and NewThoughts(victim) then SendThoughtCut(victim) end

	local attacker = dmgInfo:GetAttacker()
	if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end

	local key, wep = ClassifyHit(attacker, dmgInfo:GetInflictor(), dmgInfo)
	if key then ChatLog.Emit(key, attacker, victim, wep) end
end)

local CRIT_HEALTH_LOSS = 25
local CRIT_ORGAN_DELTA = 0.05
local CRIT_INTERNAL_BLEED_DELTA = 0.5
local KNOCKOUT_WINDOW = 1.5
local CRIT_ORGAN_KEYS = {"heart", "liver", "flank", "gut", "trachea", "brainFrontal", "brainParietal", "brainTemporal", "brainOccipital"}
local CRIT_LUNG_KEYS = {"lungsL", "lungsR"}
local CRIT_BONES = {
	chest = 1, skull = 2, jaw = 3, spine3 = 4, spine1 = 5, spine2 = 5, pelvis = 6,
	larm_up = 7, larm_down = 7, rarm_up = 8, rarm_down = 8,
	lleg_up = 9, lleg_down = 9, rleg_up = 10, rleg_down = 10,
}

local function CritSnapshot(org)
	local organs = 0
	for _, key in ipairs(CRIT_ORGAN_KEYS) do
		organs = organs + (tonumber(org[key]) or 0)
	end
	for _, key in ipairs(CRIT_LUNG_KEYS) do
		local lung = org[key]
		organs = organs + (istable(lung) and tonumber(lung[1]) or 0)
	end

	local bones = {}
	for key in pairs(CRIT_BONES) do
		bones[key] = tonumber(org[key]) or 0
	end

	local state = hg.SimpleHealth.GetState and hg.SimpleHealth.GetState(org)

	return {
		organs = organs,
		bones = bones,
		internalBleed = tonumber(org.internalBleed) or 0,
		health = state and hg.SimpleHealth.GetHealth(state),
	}
end

local function ReportCrits(attacker, victim, org, before, shot)
	if not IsValid(attacker) or not IsValid(victim) then return end

	local after = CritSnapshot(org)
	for key, index in pairs(CRIT_BONES) do
		if before.bones[key] < 1 and after.bones[key] >= 1 then
			ChatLog.Emit("bonebreak", attacker, victim, nil, index)

			break
		end
	end

	if after.organs - before.organs >= CRIT_ORGAN_DELTA or after.internalBleed - before.internalBleed >= CRIT_INTERNAL_BLEED_DELTA then
		ChatLog.Emit("organhit", attacker, victim)
	elseif before.health and after.health and before.health - after.health >= CRIT_HEALTH_LOSS then
		ChatLog.Emit(shot and "critshot" or "critblow", attacker, victim)
	end
end

hook.Add("PreHomigradDamage", "hg/chatlog/crits", function(victimEnt, dmgInfo, hitgroup, ent)
	local victim = ResolvePlayer(victimEnt)
	if not victim then return end

	local attacker = dmgInfo:GetAttacker()
	if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end

	local org = (IsValid(ent) and ent.organism) or victim.organism
	if not org then return end

	victim.hgChatLogHitBy = attacker
	victim.hgChatLogHitTime = CurTime()

	local tick = engine.TickCount()
	if org.hgCritTick == tick then return end
	org.hgCritTick = tick

	local before = CritSnapshot(org)
	local shot = dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT)
	timer.Simple(0, function() ReportCrits(attacker, victim, org, before, shot) end)
end)

function ChatLog.Gunshot(owner, wep)
	if not IsValid(owner) or not owner:IsPlayer() then return end

	ChatLog.Emit("gunshot", owner, nil, wep, GUNSHOT_ARG_NONE)
end

function ChatLog.Gesture(ply, gestureName)
	local index = ChatLog.GestureIndex[gestureName or ""]
	if not index then return end

	ChatLog.Emit("gesture", ply, nil, nil, index)
end

hook.Add("Fake", "hg/chatlog/fall", function(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if ply.organism and ply.organism.otrub then return end

	local voluntary = ply._godFakeBypass
	local collapsed = hg.SimpleHealth.GetCrit(ply) >= hg.SimpleHealth.CRIT_SOFT
	if not voluntary and NewThoughts(ply) then SendThoughtCut(ply) end

	if collapsed or voluntary then
		ChatLog.Emit(collapsed and "softcrit" or "drop", ply)

		return
	end

	timer.Simple(0, function()
		if not IsValid(ply) or not ply:Alive() or not IsValid(ply.FakeRagdoll) then return end
		if not IsStunned(ply) then return end

		ChatLog.Emit("fall", ply)
	end)
end)

function ChatLog.InspectInjuries(viewer, org)
	if not IsValid(viewer) or not org then return end

	for _, injury in ipairs(ChatLog.Injuries) do
		if injury.check(org) then viewer:ChatPrint("Their " .. injury.text .. ".") end
	end
end

hook.Add("HG_OnOtrub", "hg/chatlog/collapse", function(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

	ChatLog.Emit(hg.SimpleHealth.GetState(ply.organism) and "hardcrit" or "collapse", ply)

	local attacker = ply.hgChatLogHitBy
	ply.hgChatLogHitBy = nil
	if IsValid(attacker) and attacker ~= ply and (ply.hgChatLogHitTime or 0) > CurTime() - KNOCKOUT_WINDOW then
		ChatLog.Emit("knockout", attacker, ply)
	end
end)

hook.Add("PlayerDeath", "hg/chatlog/death", function(ply)
	ChatLog.Emit("death", ply)
end)

hook.Add("PlayerDroppedWeapon", "hg/chatlog/disarm", function(ply, wep)
	if not IsValid(ply) or not ply:Alive() or not IsValid(wep) or HAND_WEAPONS[wep:GetClass()] then return end
	if (ply.hgLastEnemyHitTime or 0) < CurTime() - 1 then return end

	local attacker = ply.hgLastEnemyHit
	if not IsValid(attacker) or not attacker:IsPlayer() or attacker == ply then return end

	ChatLog.Emit("disarm", attacker, ply, wep)
end)

local BLOCKED_LINES = {
	standup_leg = {
		{
			"You can't stand on your broken leg.",
			"Your broken leg prevents you from getting up.",
			"Your leg is too broken to stand on.",
			"The bone won't take your weight.",
		},
		{
			"Your leg gives out under you!",
			"Your broken leg won't let you get up!",
			"Your leg is too broken to stand on it..",
		},
		{
			"YOUR LEG WON'T HOLD YOU!",
			"YOUR BROKEN LEG WON'T LET YOU UP!",
			"YOUR LEG IS TOO BROKEN TO STAND!",
		},
	},
	standup_dislocated = {
		{
			"You can't stand on your dislocated leg.",
			"Your dislocated leg prevents you from getting up.",
			"Your leg is out of its socket, it won't hold you.",
		},
		{
			"Your leg is out of place, you can't stand on it!",
			"Your leg is too out of place to stand on..",
		},
		{
			"YOU CAN'T STAND ON YOUR DISLOCATED LEG!",
			"YOUR LEG IS OUT OF PLACE, YOU CAN'T GET UP!",
		},
	},
	standup_pain = {
		"I can't stand up, it hurts too much.",
		"The pain keeps me on the ground!",
		"IT HURTS TOO MUCH TO STAND!",
	},
	standup_spine = {
		"You can't feel your legs.",
		"Your legs won't respond!",
		"YOU CAN'T MOVE YOUR LEGS!",
	},
	standup_dazed = {
		"You are too dizzy to stand up.",
		"The world spins as you try to stand!",
		"YOU CAN'T GET UP!",
	},
	fix_pain = {
		"It hurts too much to fix it.",
		"I can't fix it, the pain is too much!",
		"IT HURTS TOO MUCH TO FIX IT!",
	},
	fix_arms = {
		"Your arms won't move.",
		"You can't get your arms to work!",
		"YOUR ARMS WON'T MOVE!",
	},
	arm_fire = {
		"Your arm won't move.",
		"Your arm won't respond, you can't shoot!",
		"YOUR ARM WON'T MOVE!",
	},
	arm_punch = {
		"You can't swing with your useless arms.",
		"Your arms won't let you fight!",
		"YOU CAN'T LIFT YOUR ARMS!",
	},
	run_leg = {
		"You can't run on your injured leg.",
		"Your leg buckles as you try to run!",
		"YOUR LEG WON'T LET YOU RUN!",
	},
	run_breath = {
		"You can't breathe enough to run.",
		"You are too out of breath to run!",
		"YOU CAN'T BREATHE!",
	},
	jump_leg = {
		"You can't jump on your injured leg.",
		"Your leg won't push off the ground!",
		"YOUR LEG WON'T LET YOU JUMP!",
	},
}

local function Severity(org)
	local pain = math.Clamp((tonumber(org.pain) or 0) / 100, 0, 1)
	local panic = org.panicattackActive and 0.35 or math.Clamp(tonumber(org.panicattack) or 0, 0, 1) * 0.35
	local adrenaline = math.Clamp((tonumber(org.adrenaline) or 0) / 4, 0, 1) * 0.15

	return pain + panic + adrenaline
end

function ChatLog.BlockedThought(ply, kind)
	if not IsValid(ply) or not ply:IsPlayer() or not IsAware(ply) then return false end
	if not NewThoughts(ply) or not ply.Thought then return false end

	local lines = BLOCKED_LINES[kind]
	local org = ply.organism
	if not lines or not org then return false end

	local severity = Severity(org)
	local tier = severity >= SEVERITY_PANIC and 3 or severity >= SEVERITY_STRAINED and 2 or 1
	local clr = tier == 3 and Color(255, 90, 90) or BLOCKED_COLOR

	local line = lines[tier]
	if istable(line) then line = line[math.random(#line)] end

	return ply:Thought(line, BLOCKED_COOLDOWN, "blocked_" .. kind, 0, clr)
end

local function IsLegDislocated(org, limb)
	return org[limb .. "dislocation"] or org[limb .. "dislocated"] or org[limb .. "_up_disl"] or org[limb .. "_down_disl"]
end

local function BadLeg(org)
	for _, limb in ipairs({"lleg", "rleg"}) do
		if IsLegDislocated(org, limb) then return "dislocated" end
		if hg.IsLimbFractured(org, limb) or hg.IsLimbIncapacitated(org, limb) then return "broken" end
	end
end

function ChatLog.StandUpBlockReason(ply)
	local org = ply.organism
	if not org then return end

	if hg.SimpleHealth.GetCrit(ply) >= hg.SimpleHealth.CRIT_SOFT then return "standup_crit" end

	local orgLib = hg.organism
	if org.spine1 >= orgLib.fake_spine1 or org.spine2 >= orgLib.fake_spine2 or org.spine3 >= orgLib.fake_spine3 then
		return "standup_spine"
	end

	if hg.IsLimbIncapacitated(org, "lleg") or hg.IsLimbIncapacitated(org, "rleg") then
		return BadLeg(org) == "dislocated" and "standup_dislocated" or "standup_leg"
	end

	if hg.IsLimbFractured(org, "lleg") and hg.IsLimbFractured(org, "rleg") then return "standup_leg" end
	if org.nearpainlimit or (org.shock or 0) > 40 then return "standup_pain" end
	if (org.consciousness or 1) <= 0.4 then return "standup_dazed" end
end

local function RunBlockReason(org)
	if BadLeg(org) then return "run_leg" end

	local stamina = org.stamina
	local lowStamina = istable(stamina) and stamina[1] and stamina.max and stamina[1] < stamina.max * RUN_STAMINA_FRACTION
	local lowOxygen = istable(org.o2) and (tonumber(org.o2[1]) or RUN_OXYGEN_MIN) < RUN_OXYGEN_MIN
	if lowStamina or lowOxygen then return "run_breath" end
end

local function FiringArmBlocked(ply, org)
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) then return end

	if HAND_WEAPONS[wep:GetClass()] then
		if hg.IsLimbIncapacitated(org, "rarm") and hg.IsLimbIncapacitated(org, "larm") then return "arm_punch" end
		return
	end

	if not wep.GetHandSupportState then return end

	local state = wep:GetHandSupportState(ply)
	if state and state.firingArm and hg.IsLimbIncapacitated(org, state.firingArm) then return "arm_fire" end
end

hook.Add("KeyPress", "hg/chatlog/blocked-actions", function(ply, key)
	if key ~= IN_SPEED and key ~= IN_JUMP and key ~= IN_ATTACK then return end
	if IsValid(ply.FakeRagdoll) or not NewThoughts(ply) then return end

	local org = ply.organism
	if not org or org.otrub then return end

	local kind
	if key == IN_SPEED then
		if not ply:KeyDown(IN_FORWARD) then return end
		kind = RunBlockReason(org)
	elseif key == IN_JUMP then
		kind = ply:OnGround() and BadLeg(org) and "jump_leg"
	else
		kind = FiringArmBlocked(ply, org)
	end

	if kind then ChatLog.BlockedThought(ply, kind) end
end)

local WORLD_SCAN_INTERVAL = 0.2
local IMPACT_MIN_SPEED = 300
local IMPACT_MIN_MOMENTUM = 9000
local IMPACT_MIN_DELTA = 0.15
local IMPACT_QUEUE_MAX = 16
local FLYBY_MIN_SPEED = 450
local FLYBY_MAX_DIST = 220
local FLYBY_MIN_DIST = 30
local ROLL_MIN_SPEED = 25
local ROLL_MAX_SPEED = 250
local ROLL_MAX_DIST = 450
local BLEED_DRIP = 0.35
local BLEED_POOL = 1.5

local impactQueue = {}
local grenades = {}

local function IsGrenade(ent)
	return ent.Base == "ent_hg_grenade" or string.find(ent:GetClass(), "^ent_hg_grenade", 1) ~= nil
end

local function TrackEntity(ent)
	if not IsValid(ent) then return end

	local class = ent:GetClass()
	if class == "prop_physics" and not ent.hgChatLogCallback then
		ent.hgChatLogCallback = true
		ent:AddCallback("PhysicsCollide", function(prop, data)
			if data.Speed < IMPACT_MIN_SPEED or data.DeltaTime < IMPACT_MIN_DELTA then return end
			if #impactQueue >= IMPACT_QUEUE_MAX then return end

			local phys = prop:GetPhysicsObject()
			local mass = IsValid(phys) and phys:GetMass() or 0
			if data.Speed * mass < IMPACT_MIN_MOMENTUM then return end

			impactQueue[#impactQueue + 1] = data.HitPos
		end)
	elseif IsGrenade(ent) then
		grenades[ent] = true
	end
end

hook.Add("OnEntityCreated", "hg/chatlog/track", function(ent)
	timer.Simple(0, function() TrackEntity(ent) end)
end)

local function TrackExisting()
	for _, ent in ents.Iterator() do TrackEntity(ent) end
end

hook.Add("InitPostEntity", "hg/chatlog/track-existing", TrackExisting)
hook.Add("PostCleanupMap", "hg/chatlog/track-existing", TrackExisting)

local function Aware()
	local list = {}
	for _, ply in player.Iterator() do
		if IsAware(ply) then list[#list + 1] = ply end
	end

	return list
end

local function Passing(ent, speed, players, now)
	if ent:IsPlayerHolding() then return end

	local pos = ent:GetPos()
	ent.hgFlybyNext = ent.hgFlybyNext or {}
	for _, ply in ipairs(players) do
		local distSqr = ply:EyePos():DistToSqr(pos)
		if distSqr > FLYBY_MAX_DIST * FLYBY_MAX_DIST or distSqr < FLYBY_MIN_DIST * FLYBY_MIN_DIST then continue end
		if (ent.hgFlybyNext[ply] or 0) > now then continue end

		ent.hgFlybyNext[ply] = now + 2
		ChatLog.EmitWorld("propflyby", pos, ply)
	end
end

local function Rolling(ent, players)
	if ent:IsPlayerHolding() then return end

	local pos = ent:GetPos()
	for _, ply in ipairs(players) do
		if ply:EyePos():DistToSqr(pos) <= ROLL_MAX_DIST * ROLL_MAX_DIST then ChatLog.EmitWorld("grenaderoll", pos, ply) end
	end
end

timer.Create("hg/chatlog/world", WORLD_SCAN_INTERVAL, 0, function()
	local players = Aware()
	if #players == 0 then
		impactQueue = {}

		return
	end

	local now = CurTime()
	local range = ChatLog.RANGE_TALK
	for _, pos in ipairs(impactQueue) do
		for _, ply in ipairs(players) do
			if ply:EyePos():DistToSqr(pos) <= range * range then ChatLog.EmitWorld("propimpact", pos, ply) end
		end
	end
	impactQueue = {}

	for _, prop in ipairs(ents.FindByClass("prop_physics")) do
		local speed = prop:GetVelocity():Length()
		if speed >= FLYBY_MIN_SPEED then Passing(prop, speed, players, now) end
	end

	for ent in pairs(grenades) do
		if not IsValid(ent) then
			grenades[ent] = nil

			continue
		end

		local speed = ent:GetVelocity():Length()
		if speed >= FLYBY_MIN_SPEED then
			Passing(ent, speed, players, now)
		elseif speed >= ROLL_MIN_SPEED and speed <= ROLL_MAX_SPEED then
			Rolling(ent, players)
		end
	end
end)

timer.Create("hg/chatlog/bleeding", 1, 0, function()
	for _, ply in player.Iterator() do
		local org = ply:Alive() and ply.organism
		local bleed = org and tonumber(org.bleed) or 0
		if bleed >= BLEED_POOL then
			ChatLog.Emit("bloodpool", ply)
		elseif bleed >= BLEED_DRIP then
			ChatLog.Emit("blooddrip", ply)
		end
	end
end)

hook.Add("Fake Up", "hg/chatlog/getup", function(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
	if ply.organism and ply.organism.otrub then return end

	ChatLog.Emit("getup", ply)
end)

hook.Add("HG_OnWakeOtrub", "hg/chatlog/wake", function(ply)
	if IsValid(ply) and ply:IsPlayer() and ply:Alive() then ChatLog.Emit("wake", ply) end
end)

local PILL_CLASSES = {
	weapon_painkillers = true,
	weapon_zerlkers = true,
}

local function MedicalKey(minigameType, wep)
	if minigameType == "bandage" then
		return IsValid(wep) and wep.IsSplintMode and wep:IsSplintMode() and "medsplint" or "medbandage"
	end

	if minigameType == "tourniquet" then return "medtourniquet" end
	if minigameType == "suture" then return "medsuture" end
	if minigameType == "amputation" then return "medamputate" end
	if minigameType == "dislocation" then return "medfixdisloc" end
	if minigameType ~= "syringe" or not IsValid(wep) then return end

	local class = wep:GetClass()
	if PILL_CLASSES[class] then return "medpills" end
	if class == "weapon_needle" or class == "weapon_medkit_sh" and wep.mode == 5 then return "medneedle" end

	return "medinject"
end

function ChatLog.Medical(actor, target, key, wep)
	if not IsValid(actor) or not actor:IsPlayer() then return end

	local patient = ResolvePlayer(target)
	ChatLog.Emit(key, actor, patient, wep)
end

hook.Add("hg_medical_minigame_finished", "hg/chatlog/medical", function(actor, target, minigameType)
	if not IsValid(actor) or not actor:IsPlayer() then return end

	local wep = actor:GetActiveWeapon()
	local key = MedicalKey(minigameType, wep)
	if key then ChatLog.Medical(actor, target, key, wep) end
end)
