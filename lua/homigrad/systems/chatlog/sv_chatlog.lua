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

	for _, ply in player.Iterator() do
		if ply == actor or not IsAware(ply) then continue end
		if ply:EyePos():DistToSqr(pos) > rangeSqr then continue end
		if visualOnly and not ply:TestPVS(pos) then continue end

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

local function ResolvePlayer(ent)
	if not IsValid(ent) then return end
	if ent:IsPlayer() then return ent end
	if ent:IsRagdoll() and hg.RagdollOwner then
		local owner = hg.RagdollOwner(ent)
		if IsValid(owner) and owner:IsPlayer() then return owner end
	end
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
	ChatLog.Emit(collapsed and "softcrit" or voluntary and "drop" or "fall", ply)
end)

hook.Add("Fake Up", "hg/chatlog/getup", function(ply)
	if IsValid(ply) and ply:IsPlayer() then ChatLog.Emit("getup", ply) end
end)

hook.Add("HG_OnOtrub", "hg/chatlog/collapse", function(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

	ChatLog.Emit(hg.SimpleHealth.GetState(ply.organism) and "hardcrit" or "collapse", ply)
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
		"You can't stand on your broken leg.",
		"Your leg gives out under you!",
		"YOUR LEG WON'T HOLD YOU!",
	},
	standup_dislocated = {
		"You can't stand on your dislocated leg.",
		"Your leg is out of place, you can't stand on it!",
		"YOU CAN'T STAND ON YOUR DISLOCATED LEG!",
	},
	standup_pain = {
		"You can't stand up, it hurts too much.",
		"The pain keeps you on the ground!",
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
		"You can't fix it, the pain is too much!",
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

	return ply:Thought(lines[tier], BLOCKED_COOLDOWN, "blocked_" .. kind, 0, clr)
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
