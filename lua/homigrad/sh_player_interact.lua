hg.PlayerInteract = hg.PlayerInteract or {}
local PI = hg.PlayerInteract

PI.LEFT, PI.RIGHT, PI.BOTH = 1, 2, 3
PI.RANGE_ACT = 65
PI.RANGE_OFFER = 85
PI.RANGE_MENU = 85

local LEFT, RIGHT, BOTH = PI.LEFT, PI.RIGHT, PI.BOTH
local RANGE_ACT, RANGE_OFFER = PI.RANGE_ACT, PI.RANGE_OFFER

PI.HandsClasses = {
	weapon_hands_sh = true,
	weapon_hg_coolhands = true,
}

function PI.GetHandSide(ply, preferred)
	local left = hg.GetArmEffectiveness(ply, "larm") > 0.05
	local right = hg.GetArmEffectiveness(ply, "rarm") > 0.05

	if preferred == LEFT then return left and LEFT or (right and RIGHT) or nil end

	return right and RIGHT or (left and LEFT) or nil
end

function PI.IsStanding(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive() and hg.GetCurrentCharacter(ply) == ply
end

function PI.Resolve(ent)
	if not IsValid(ent) then return end

	if ent:IsRagdoll() and hg.RagdollOwner then ent = hg.RagdollOwner(ent) end
	if IsValid(ent) and ent:IsPlayer() then return ent end
end

function PI.IsReachable(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive()
end

function PI.Pos(ply)
	local character = hg.GetCurrentCharacter(ply)

	return IsValid(character) and character:GetPos() or ply:GetPos()
end

if SERVER then
	util.AddNetworkString("hg_ia_action")

	local GIVE_TIME = 1.1
	local GIVE_HOLD = 0.6
	local TAP_TIME = 0.9
	local OFFER_TIME = 25
	local CHECK_TIME = 12
	local FIX_TIME = 40

	local states = {}
	local nextThink = 0

	local function nameOf(ply)
		local name = ply.GetPlayerName and ply:GetPlayerName()
		if isstring(name) and name ~= "" then return name end

		return ply:Nick()
	end

	local function canAct(ply)
		if not PI.IsStanding(ply) or ply:InVehicle() then return false end
		if ply:GetNetVar("handcuffed", false) or ply:GetNetVar("ducttaped_hands", false) then return false end

		local org = ply.organism
		if org and (org.otrub or not org.alive) then return false end

		return true
	end

	local function setState(ply, mode, target, hand, duration, extra)
		local now = CurTime()
		local st = {mode = mode, target = target, hand = hand, start = now, finish = now + duration}

		for k, v in pairs(extra or {}) do st[k] = v end

		states[ply] = st
		ply:SetNWString("hg_ia_mode", mode)
		ply:SetNWEntity("hg_ia_target", target)
		ply:SetNWInt("hg_ia_hand", hand)
		ply:SetNWFloat("hg_ia_start", now)
		ply:SetNWString("hg_ia_limb", st.limb or "")
		ply:SetNWString("hg_ia_item", st.item or "")

		return st
	end

	local function clearState(ply)
		local st = states[ply]
		states[ply] = nil

		if IsValid(ply) then
			ply:SetNWString("hg_ia_mode", "")
			ply:SetNWEntity("hg_ia_target", NULL)
			ply:SetNWString("hg_ia_item", "")
		end

		if st and st.mode == "give" and IsValid(st.target) and states[st.target] and states[st.target].mode == "give" then
			clearState(st.target)
		end
	end

	PI.ClearState = clearState

	local function transferWeapon(giver, receiver, wep)
		if not IsValid(wep) or wep:GetOwner() ~= giver then return false end

		local previous = receiver.force_pickup
		receiver.force_pickup = true

		if hook.Run("PlayerCanPickupWeapon", receiver, wep) == false then
			receiver.force_pickup = previous
			receiver:Notify("I can't take that.", 3)
			giver:Notify("They can't take that.", 3)

			return false
		end

		giver:DropWeapon(wep)
		wep.IsSpawned = false
		wep.init = false
		wep.DontEquipInstantly = true

		if IsValid(wep) then receiver:PickupWeapon(wep) end
		receiver.force_pickup = previous

		if not IsValid(wep) or wep:GetOwner() ~= receiver then
			giver:Notify("They couldn't hold it.", 3)

			return false
		end

		return true
	end

	local function endCheck(st, ply, target, now)
		if ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2) or ply:KeyDown(IN_RELOAD) then return true end

		return ply:GetPos():Distance(PI.Pos(target)) > RANGE_ACT + 25
	end

	local function endOffer(st, ply, target, now)
		local wep = st.wep
		if not IsValid(wep) or wep:GetOwner() ~= ply or ply:GetActiveWeapon() ~= wep then return true end

		return ply:GetPos():Distance(PI.Pos(target)) > RANGE_OFFER + 25
	end

	local function endFix(st, ply, target, now)
		local sessions = hg.MedicalMinigame and hg.MedicalMinigame.DislocationSessions
		local session = sessions and sessions[ply]
		if now - st.start > 0.5 and (not session or session.target ~= target) then return true end

		return ply:GetPos():Distance(PI.Pos(target)) > RANGE_ACT + 25
	end

	local enders = {check = endCheck, offer = endOffer, fix = endFix}

	hook.Add("Think", "HG_PlayerInteract", function()
		local now = CurTime()
		if now < nextThink then return end
		nextThink = now + 0.1

		for ply, st in pairs(states) do
			local target = st.target
			local dead = not IsValid(ply) or not ply:Alive() or not IsValid(target) or not target:Alive()

			if dead or now >= st.finish or not canAct(ply) then
				clearState(ply)
			elseif st.mode == "offer" and not PI.IsStanding(target) or st.mode ~= "give" and not PI.IsReachable(target) then
				clearState(ply)
			elseif enders[st.mode] and enders[st.mode](st, ply, target, now) then
				clearState(ply)
			elseif st.mode == "give" and st.role == "giver" and not st.done and now >= st.transferAt then
				st.done = true
				transferWeapon(ply, target, st.wep)
			end
		end
	end)

	local function release(ply)
		clearState(ply)

		for other, st in pairs(states) do
			if st.target == ply then clearState(other) end
		end
	end

	hook.Add("PlayerDeath", "HG_PlayerInteract", release)
	hook.Add("PlayerDisconnected", "HG_PlayerInteract", release)

	local actions = {}

	function actions.check(ply, target, dist)
		if dist > RANGE_ACT then ply:Notify("They are too far away.", 3) return end

		local hand = PI.GetHandSide(ply, LEFT)
		if not hand then ply:Notify("I have no arm to reach them with.", 4) return end

		local org = target.organism
		if not org then return end

		setState(ply, "check", target, hand, CHECK_TIME)
		target:Notify(nameOf(ply) .. " is checking your reaction.", 4)

		if org.CantCheckPulse then
			ply:Notify("Their armor is too thick to feel a pulse.", 4)
		elseif org.heartstop or (tonumber(org.pulse) or 0) <= 0 then
			ply:Notify("No Pulse.", 2, "vitals_nopulse")
		else
			umsg.Start("hg_StartPulseCheckECG", ply)
			umsg.Entity(target)
			umsg.End()
		end

		if hg.PrintReactionCheck then hg.PrintReactionCheck(ply, org, true) end
		if hg.PrintPerfusionDiagnosis then hg.PrintPerfusionDiagnosis(ply, org) end
		if hg.ChatLog and hg.ChatLog.InspectInjuries then hg.ChatLog.InspectInjuries(ply, org) end
	end

	function actions.tap(ply, target, dist)
		if dist > RANGE_ACT then ply:Notify("They are too far away.", 3) return end

		local hand = PI.GetHandSide(ply, RIGHT)
		if not hand then ply:Notify("I have no arm to tap them with.", 4) return end

		setState(ply, "tap", target, hand, TAP_TIME)
		target:Notify(nameOf(ply) .. " taps your shoulder.", 3)
		target:EmitSound("player/clothes_generic_foley_0" .. math.random(5) .. ".wav", 55)
		target:ViewPunch(Angle(0, math.Rand(-1.5, 1.5), 0))
	end

	function actions.fix(ply, target, dist, group)
		if dist > RANGE_ACT then ply:Notify("They are too far away.", 3) return end
		if not hg.MedicalMinigame or not hg.MedicalMinigame.StartDislocationMinigame then return end

		local hand = PI.GetHandSide(ply, LEFT)
		if not hand then ply:Notify("I have no arm to set it with.", 4) return end

		if not hg.MedicalMinigame.StartDislocationMinigame(ply, target, group) then
			ply:Notify("Nothing there looks dislocated.", 3)

			return
		end

		local session = hg.MedicalMinigame.DislocationSessions[ply]
		local both = hg.GetArmEffectiveness(ply, "larm") > 0.05 and hg.GetArmEffectiveness(ply, "rarm") > 0.05

		setState(ply, "fix", target, both and BOTH or hand, FIX_TIME, {limb = session and session.limb or "jaw"})
	end

	function actions.offer(ply, target, dist)
		if dist > RANGE_OFFER then ply:Notify("They are too far away.", 3) return end
		if not PI.IsStanding(target) or target.organism and target.organism.otrub then ply:Notify("They can't take anything right now.", 3) return end

		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or PI.HandsClasses[wep:GetClass()] then ply:Notify("I have nothing in my hand to offer.", 3) return end

		local hand = PI.GetHandSide(ply, LEFT)
		if not hand then ply:Notify("I have no hand to offer anything with.", 4) return end

		if not PI.GetHandSide(target, RIGHT) then
			ply:Notify("They have no hands to take it with.", 5)

			return
		end

		local item = wep.GetPrintName and wep:GetPrintName() or wep:GetClass()
		setState(ply, "offer", target, hand, OFFER_TIME, {wep = wep, item = item})
		target:Notify(nameOf(ply) .. " offers you a " .. item .. ". Open your menu on them to take it.", 6)
		ply:Notify("I hold out " .. item .. " to them.", 3)
	end

	function actions.accept(ply, offerer, dist)
		local offer = states[offerer]
		if not offer or offer.mode ~= "offer" or offer.target ~= ply then
			ply:Notify("They are no longer offering anything.", 3)

			return
		end

		if dist > RANGE_OFFER then ply:Notify("They are too far away.", 3) return end

		local hand = PI.GetHandSide(ply, RIGHT)
		if not hand then
			ply:Notify("I have no hand to take it with.", 4)
			offerer:Notify("They have no hand to take it with.", 4)
			clearState(offerer)

			return
		end

		local now = CurTime()
		local wep = offer.wep
		local item = offer.item

		setState(offerer, "give", ply, offer.hand, GIVE_TIME + GIVE_HOLD, {role = "giver", wep = wep, item = item, transferAt = now + GIVE_TIME})
		setState(ply, "give", offerer, hand, GIVE_TIME + GIVE_HOLD, {role = "receiver", item = item})
	end

	net.Receive("hg_ia_action", function(_, ply)
		local target = net.ReadEntity()
		local action = net.ReadString()
		local arg = net.ReadUInt(4)

		if not canAct(ply) or not actions[action] then return end
		target = PI.Resolve(target)
		if not target or target == ply or not PI.IsReachable(target) then return end
		if (ply.hgIANext or 0) > CurTime() then return end
		ply.hgIANext = CurTime() + 0.4

		actions[action](ply, target, ply:GetPos():Distance(PI.Pos(target)), arg)
	end)

	return
end

hook.Add("StartCommand", "HG_PlayerInteractCheckCrouch", function(ply, cmd)
	if ply:GetNWString("hg_ia_mode", "") ~= "check" or IsValid(ply.FakeRagdoll) then return end

	cmd:AddKey(IN_DUCK)
	cmd:RemoveKey(IN_JUMP)
end)

local ease = math.ease.InOutSine
local REACH = 26
local EASE_TIME = 0.3

local angLH = Angle(-135, -90, 180)
local angRH = Angle(-135, 90, 0)

local fingers = {
	{"Finger0", 0.5, true}, {"Finger01", 0.6, true}, {"Finger02", 0.5, true},
	{"Finger1", 1.0}, {"Finger11", 1.1}, {"Finger12", 0.55},
	{"Finger2", 1.0}, {"Finger21", 1.1}, {"Finger22", 0.55},
	{"Finger3", 0.95}, {"Finger31", 1.05}, {"Finger32", 0.55},
	{"Finger4", 0.9}, {"Finger41", 1.0}, {"Finger42", 0.5},
}
local fingerCurl = Angle(0, -72, 0)
local thumbGrip = Angle(-38, 35, 0)
local sideBones = {l = "ValveBiped.Bip01_L_", r = "ValveBiped.Bip01_R_"}

local limbBones = {
	larm = "ValveBiped.Bip01_L_Forearm",
	rarm = "ValveBiped.Bip01_R_Forearm",
	lleg = "ValveBiped.Bip01_L_Calf",
	rleg = "ValveBiped.Bip01_R_Calf",
	jaw = "ValveBiped.Bip01_Head1",
}

local function bonePos(char, name)
	local id = char:LookupBone(name)
	local mat = id and char:GetBoneMatrix(id)

	return mat and mat:GetTranslation()
end

local function reachClamp(ply, side, goal)
	local shoulder = bonePos(ply, sideBones[side] .. "UpperArm")
	if not shoulder then return goal end

	local to = goal - shoulder
	local len = to:Length()
	if len > REACH then goal = shoulder + to * (REACH / len) end

	return goal
end

local function blendHand(ply, side, pos, from, w)
	local id = ply:LookupBone(sideBones[side] .. "Hand")
	local mat = id and ply:GetBoneMatrix(id)
	if not mat then return end

	local dir = pos - (bonePos(ply, sideBones[side] .. "UpperArm") or from)
	if dir:LengthSqr() < 1 then dir = mat:GetAngles():Forward() end

	local _, ang = LocalToWorld(vector_origin, side == "l" and angLH or angRH, vector_origin, dir:Angle())
	mat:SetTranslation(LerpVector(w, mat:GetTranslation(), pos))
	mat:SetAngles(LerpAngle(w, mat:GetAngles(), ang))
	hg.bone_apply_matrix(ply, id, mat)
end

local function handPos(ply, side)
	return bonePos(ply, sideBones[side] .. "Hand")
end

local function snapshot(ply)
	return {
		mode = ply:GetNWString("hg_ia_mode", ""),
		target = ply:GetNWEntity("hg_ia_target"),
		hand = ply:GetNWInt("hg_ia_hand", 0),
		start = ply:GetNWFloat("hg_ia_start", 0),
		limb = ply:GetNWString("hg_ia_limb", ""),
	}
end

local function goalsFor(ply, tchar, st, now)
	local mine = ply:GetPos()
	local toMe = mine - tchar:GetPos()
	toMe.z = 0
	if toMe:LengthSqr() < 1 then toMe = -ply:EyeAngles():Forward() end
	toMe:Normalize()

	local side = st.hand == LEFT and "l" or "r"
	local mode = st.mode

	if mode == "check" then
		local neck = bonePos(tchar, "ValveBiped.Bip01_Neck1") or bonePos(tchar, "ValveBiped.Bip01_Head1")
		if not neck then return end

		return {{side, neck + toMe * 2.6, "cup"}}
	end

	if mode == "tap" then
		local shoulderL = bonePos(tchar, "ValveBiped.Bip01_L_UpperArm")
		local shoulderR = bonePos(tchar, "ValveBiped.Bip01_R_UpperArm")
		local shoulder = shoulderL
		if shoulderL and shoulderR and shoulderR:DistToSqr(mine) < shoulderL:DistToSqr(mine) then shoulder = shoulderR end
		shoulder = shoulder or bonePos(tchar, "ValveBiped.Bip01_Spine4")
		if not shoulder then return end

		local tap = math.max(0, math.sin((now - st.start) * 16)) * 1.2

		return {{side, shoulder + toMe * 1.5 + vector_up * (3.5 + tap), "cup"}}
	end

	if mode == "fix" then
		local limb = bonePos(tchar, limbBones[st.limb] or limbBones.jaw)
		if not limb then return end

		local across = toMe:Cross(vector_up) * 2.5
		local goals = {}
		if st.hand ~= RIGHT then goals[#goals + 1] = {"l", limb + toMe * 2 - across, "grip"} end
		if st.hand ~= LEFT then goals[#goals + 1] = {"r", limb + toMe * 2 + across, "grip"} end

		return goals
	end

	local chest = bonePos(ply, "ValveBiped.Bip01_Spine2")
	local theirChest = bonePos(tchar, "ValveBiped.Bip01_Spine2")
	if not chest or not theirChest then return end

	if mode == "offer" then
		local dir = theirChest - chest
		dir.z = 0
		dir:Normalize()

		return {{side, chest + dir * REACH * 0.9 - vector_up * 6}}
	end

	if mode == "give" then
		return {{side, (chest + theirChest) * 0.5 - vector_up * 6}}
	end
end

function hg.PlayerInteractTPIK(ent, ply, wpn)
	if ent ~= ply or not IsValid(wpn) then return end

	ply.hgIATPIKAt = CurTime()
	local mode = ply:GetNWString("hg_ia_mode", "")
	local active = mode ~= "" and not IsValid(ply:GetNWEntity("FakeRagdoll"))
	if active then ply.hgIALast = snapshot(ply) end

	ply.hgIAEase = math.Approach(ply.hgIAEase or 0, active and 1 or 0, FrameTime() / EASE_TIME)
	local w = ease(ply.hgIAEase)
	local st = ply.hgIALast
	if w <= 0 or not st then
		ply.hgIALast = nil
		ply.hgIARoles = nil

		return
	end

	if not IsValid(st.target) then return end

	local tchar = hg.GetCurrentCharacter(st.target)
	if not IsValid(tchar) then return end

	local goals = goalsFor(ply, tchar, st, CurTime())
	if not goals then return end

	local roles = {}

	for _, goal in ipairs(goals) do
		local side, pos, role = goal[1], goal[2], goal[3]
		local from = handPos(ply, side) or pos
		pos = reachClamp(ply, side, pos)
		blendHand(ply, side, pos, from, w)
		if st.mode == "check" then ply.hgIACheckHandPos = LerpVector(w, from, pos) end
		roles[side] = role
		if side == "l" then wpn.lhandik = true else wpn.rhandik = true end
	end

	ply.hgIARoles = roles
end

hook.Add("Bones", "HG_PlayerInteractFingers", function(ply, dtime)
	if (ply.hgIATPIKAt or 0) < CurTime() - 0.25 then ply.hgIAEase = 0 end
	local w = ease(ply.hgIAEase or 0)
	local roles = w > 0 and ply.hgIARoles or nil
	if not roles and not ply.hgIAFingers then return end
	ply.hgIAFingers = roles ~= nil

	for side, prefix in pairs(sideBones) do
		local role = roles and roles[side]
		for _, f in ipairs(fingers) do
			local ang = angle_zero
			if role == "grip" then ang = f[3] and thumbGrip * 0.62 or fingerCurl * (0.9 * f[2])
			elseif role == "cup" then ang = f[3] and thumbGrip * 0.25 or fingerCurl * (0.3 * f[2]) end
			hg.bone.Set(ply, prefix .. f[1], vector_origin, ang * w, "playerinteract")
		end
	end
end)

local function send(target, action, arg)
	net.Start("hg_ia_action")
	net.WriteEntity(target)
	net.WriteString(action)
	net.WriteUInt(arg or 0, 4)
	net.SendToServer()
end

function PI.GetLookTarget()
	local lply = LocalPlayer()
	if not IsValid(lply) or not PI.IsStanding(lply) then return end
	if lply.organism and lply.organism.otrub then return end

	local trace = hg.eyeTrace(lply)
	local ent = PI.Resolve(trace and trace.Entity)
	if not ent or ent == lply or not PI.IsReachable(ent) then return end
	if lply:GetPos():Distance(PI.Pos(ent)) > PI.RANGE_MENU then return end

	return ent
end

function PI.Busy(ply)
	return ply:GetNWString("hg_ia_mode", "") ~= ""
end

function hg.GetInteractOptions()
	local target = PI.GetLookTarget()
	if not target then return end

	local options = {title = target}

	if target:GetNWString("hg_ia_mode", "") == "offer" and target:GetNWEntity("hg_ia_target") == LocalPlayer() then
		options[#options + 1] = {
			function() send(target, "accept") end,
			"Take " .. target:GetNWString("hg_ia_item", "item"),
		}
	end

	local wep = LocalPlayer():GetActiveWeapon()
	if PI.IsStanding(target) and IsValid(wep) and not PI.HandsClasses[wep:GetClass()] then
		local name = wep.GetPrintName and wep:GetPrintName() or wep:GetClass()
		options[#options + 1] = {
			function() send(target, "offer") end,
			"Offer " .. name,
		}
	end

	options[#options + 1] = {
		function() send(target, "check") end,
		"Check Reaction",
	}

	options[#options + 1] = {
		function() send(target, "tap") end,
		"Tap Shoulder",
	}

	options[#options + 1] = {
		function()
			local org = target.organism or {}
			local entries = {}

			if org.llegdislocation or org.rlegdislocation then entries[#entries + 1] = {function() send(target, "fix", 1) end, "Leg"} end
			if org.larmdislocation or org.rarmdislocation then entries[#entries + 1] = {function() send(target, "fix", 2) end, "Arm"} end
			if org.jawdislocation then entries[#entries + 1] = {function() send(target, "fix", 3) end, "Jaw"} end

			if #entries == 0 then
				LocalPlayer():Notify("Nothing there looks dislocated. I can't fix anything.", 3)

				return
			end

			entries.title = target
			hg.CreateRadialMenu(entries)

			return -1
		end,
		"Fix Dislocation",
	}

	return options
end
