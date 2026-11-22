local ChatLog = hg.ChatLog

local CurTime = CurTime
local IsValid = IsValid

local CHECK_INTERVAL = 0.5
local MESSAGE_COOLDOWN = 6
local BAD_COLOR = Color(255, 80, 80)
local GOOD_COLOR = Color(120, 175, 255)

local function OxygenLevel(org)
	return istable(org.o2) and tonumber(org.o2[1]) or 30
end

local function Above(value, enter, exit, current, level)
	return value >= (current >= level and exit or enter)
end

local function Below(value, enter, exit, current, level)
	return value <= (current >= level and exit or enter)
end

local function LimbLevel(org, limb)
	if hg.IsLimbIncapacitated(org, limb) then return 2 end

	local dislocated = org[limb .. "dislocation"] or org[limb .. "dislocated"] or org[limb .. "_up_disl"] or org[limb .. "_down_disl"]
	if dislocated or hg.IsLimbFractured(org, limb) then return 1 end

	return 0
end

local function LimbStatus(limb, name, failLine)
	return {
		key = limb,
		level = function(org) return LimbLevel(org, limb) end,
		lines = {"Your " .. name .. " is badly hurt.", failLine},
		recover = "Your " .. name .. " feels better.",
	}
end

local CANT_STAND_TEXT = {
	standup_pain = "It hurts too much to stand.",
	standup_spine = "You can't feel your legs.",
	standup_leg = "Your leg won't hold your weight.",
	standup_dislocated = "Your leg is out of place, it won't hold you.",
	standup_dazed = "You are too dizzy to stand up.",
}

local STATUSES = {
	{
		key = "bleed",
		level = function(org, _, current)
			local bleed = tonumber(org.bleed) or 0
			if Above(bleed, 5, 3, current, 2) then return 2 end
			if Above(bleed, 1, 0.3, current, 1) then return 1 end

			return 0
		end,
		lines = {"You are bleeding.", "You are bleeding out!"},
		recover = "Your bleeding has stopped.",
	},
	{
		key = "blood",
		level = function(org, _, current)
			if hg.SimpleHealth and hg.SimpleHealth.GetState(org) then return 0 end

			local blood = tonumber(org.blood) or 5000
			if Below(blood, 2600, 2750, current, 3) then return 3 end
			if Below(blood, 3300, 3450, current, 2) then return 2 end
			if Below(blood, 4000, 4150, current, 1) then return 1 end

			return 0
		end,
		lines = {"I feel lightheaded.", "I feel very weak.", "I'M ABOUT TO PASS OUT FROM BLOOD LOSS!"},
		recover = "You feel less faint.",
	},
	{
		key = "pain",
		level = function(org, _, current)
			local pain = tonumber(org.pain) or 0
			if org.nearpainlimit or Above(pain, 85, 75, current, 3) then return 3 end
			if Above(pain, 60, 50, current, 2) then return 2 end
			if Above(pain, 30, 20, current, 1) then return 1 end

			return 0
		end,
		lines = {"I'm in pain.", "The pain is unbearable!", "I CAN'T TAKE THE PAIN!"},
		recover = "The pain fades.",
	},
	{
		key = "shock",
		level = function(org, _, current)
			return Above(tonumber(org.shock) or 0, 40, 30, current, 1) and 1 or 0
		end,
		lines = {"I'm going into shock!"},
		recover = "You feel steadier.",
	},
	{
		key = "breath",
		level = function(org, _, current)
			local o2 = OxygenLevel(org)
			if Below(o2, 8, 11, current, 2) then return 2 end
			if Below(o2, 15, 18, current, 1) then return 1 end

			return 0
		end,
		lines = {"You can't breathe!", "YOU ARE SUFFOCATING!"},
		recover = "You can breathe again.",
	},
	{
		key = "stun",
		level = function(org, ply)
			local now = CurTime()
			local forced = org.needfake or org.canmove == false or org.paralyzed or (tonumber(org.stun) or 0) > now
			if forced and IsValid(ply.FakeRagdoll) and not org.otrub then org.hgMoveHold = now + 1.5 end
			if (org.hgMoveHold or 0) <= now then return 0 end
			if ChatLog.StandUpBlockReason(ply) then return 0 end

			return 1
		end,
		quietClear = function(ply) return not IsValid(ply.FakeRagdoll) or ChatLog.StandUpBlockReason(ply) ~= nil end,
		lines = {"You can't move!"},
		recover = "You can move again.",
	},
	{
		key = "cold",
		level = function(org, _, current)
			local temperature = tonumber(org.temperature) or 36.6
			if Below(temperature, 33, 33.5, current, 2) then return 2 end
			if Below(temperature, 35, 35.5, current, 1) then return 1 end

			return 0
		end,
		lines = {"You are freezing.", "You are shivering uncontrollably!"},
		recover = "You feel warmer.",
	},
	{
		key = "heat",
		level = function(org, _, current)
			return Above(tonumber(org.temperature) or 36.6, 38.5, 38, current, 1) and 1 or 0
		end,
		lines = {"You are burning up."},
		recover = "You cool down.",
	},
	{
		key = "cantstand",
		level = function(_, ply)
			return IsValid(ply.FakeRagdoll) and ChatLog.StandUpBlockReason(ply) and 1 or 0
		end,
		quietClear = function(ply) return not IsValid(ply.FakeRagdoll) end,
		text = function(ply) return CANT_STAND_TEXT[ChatLog.StandUpBlockReason(ply)] or "You can't stand up." end,
		lines = {"You can't stand up."},
		recover = "You feel strong enough to stand.",
	},
	LimbStatus("lleg", "left leg", "Your left leg won't hold your weight!"),
	LimbStatus("rleg", "right leg", "Your right leg won't hold your weight!"),
	LimbStatus("larm", "left arm", "Your left arm won't move!"),
	LimbStatus("rarm", "right arm", "Your right arm won't move!"),
}

local function StatusMessage(ply, msgKey, text, clr)
	ply:Thought(text, MESSAGE_COOLDOWN, msgKey, 0, clr)
end

local function UpdateStatus(ply, org, status, levels)
	local current = levels[status.key] or 0
	local level = status.level(org, ply, current)
	if level == current then return end

	levels[status.key] = level

	if level > current then
		local text = status.text and status.text(ply) or status.lines[math.min(level, #status.lines)]
		if text then StatusMessage(ply, "hgstatus_" .. status.key .. level, text, BAD_COLOR) end
		return
	end

	if level > 0 or not status.recover then return end
	if status.quietClear and status.quietClear(ply) then return end

	StatusMessage(ply, "hggood_" .. status.key, status.recover, GOOD_COLOR)
end

local OTRUB_LINES = {
	{key = "hgOtrubBreath", text = "You stopped breathing.", clr = Color(255, 120, 120), active = function(org)
		return org.respiratoryArrest or not org.lungsfunction
	end},
	{key = "hgOtrubFlat", text = "You are flatlining.", clr = Color(255, 70, 70), active = function(org)
		return org.heartstop or org.ecgState == "asystole"
	end},
}

local function RestoreThoughts(ply)
	if not ply.hgThoughtsForced then return end
	ply.hgThoughtsForced = nil
	ply:ConCommand("hg_newthoughts 0")
end

hook.Add("Org Think", "hg/chatlog/otrub-thoughts", function(ply, org)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	if not ply:Alive() or not org.otrub then
		org.hgOtrubSeen = nil
		RestoreThoughts(ply)
		return
	end

	if ply:GetInfoNum("hg_newthoughts", 0) <= 0 and not ply.hgThoughtsForced then
		ply.hgThoughtsForced = true
		ply:ConCommand("hg_newthoughts 1")
	end

	local now = CurTime()
	org.hgOtrubSeen = org.hgOtrubSeen or {}
	for _, line in ipairs(OTRUB_LINES) do
		if line.active(org) then
			if (org.hgOtrubSeen[line.key] or 0) <= now then
				if hg.OtrubThought(ply, line.text, line.clr) then
					org.hgOtrubSeen[line.key] = math.huge
				end
			end
		else
			org.hgOtrubSeen[line.key] = nil
		end
	end
end)

hook.Add("PlayerDeath", "hg/chatlog/otrub-thoughts-restore", function(ply)
	RestoreThoughts(ply)
end)

hook.Add("PlayerSpawn", "hg/chatlog/otrub-thoughts-restore", function(ply)
	RestoreThoughts(ply)
end)

hook.Add("Org Think", "hg/chatlog/status-effects", function(ply, org)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
	if org.otrub or not ply.Thought then return end

	local now = CurTime()
	if (org.hgStatusNext or 0) > now then return end
	org.hgStatusNext = now + CHECK_INTERVAL

	if ply:GetInfoNum("hg_newthoughts", 0) <= 0 then
		org.hgStatusLevels = nil
		return
	end

	org.hgStatusLevels = org.hgStatusLevels or {}
	for _, status in ipairs(STATUSES) do
		UpdateStatus(ply, org, status, org.hgStatusLevels)
	end
end)

local WAKE_DELAY = 1.5

hook.Add("HG_OnWakeOtrub", "hg/chatlog/wake-good", function(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	timer.Simple(WAKE_DELAY, function()
		if not IsValid(ply) or not ply:Alive() then return end

		local org = ply.organism
		if not org or org.otrub or not ply.Thought then return end

		local bleed = tonumber(org.bleed) or 0
		if bleed > 5 then
			ply:InterruptThought("There is a pool of blood below you.", BAD_COLOR)
		elseif (tonumber(org.pain) or 0) < 15 and bleed < 0.3 then
			ply:InterruptThought("You woke up. You are not in much pain.", GOOD_COLOR)
		end
	end)
end)

local INSPECT_DURATION = 2
local INSPECT_COLOR = Color(225, 225, 225)
local INSPECT_GOOD = Color(120, 175, 255)

local FRAGILE_FROM = 0.6
local TISSUE_NAMES = {
	head = "head", torso = "torso",
	larm = "left arm", rarm = "right arm",
	lleg = "left leg", rleg = "right leg",
}
local FRAGILE_BONES = {
	{key = "skull", text = "Your skull aches, it feels ready to crack."},
	{key = "jaw", text = "Your jaw feels like it could snap."},
	{key = "spine3", text = "Your neck feels dangerously fragile."},
	{key = "spine2", text = "Your back feels like it could give out."},
	{key = "spine1", text = "Your lower back feels like it could give out."},
	{key = "pelvis", text = "Your hips feel like they could break."},
	{key = "chest", text = "Your ribs feel like they are about to break."},
	{key = "lleg_up", text = "Your left thigh feels like it is about to break."},
	{key = "lleg_down", text = "Your left shin feels like it is about to break."},
	{key = "rleg_up", text = "Your right thigh feels like it is about to break."},
	{key = "rleg_down", text = "Your right shin feels like it is about to break."},
	{key = "larm_up", text = "Your left upper arm feels like it is about to break."},
	{key = "larm_down", text = "Your left forearm feels like it is about to break."},
	{key = "rarm_up", text = "Your right upper arm feels like it is about to break."},
	{key = "rarm_down", text = "Your right forearm feels like it is about to break."},
}

local function InspectLines(ply, org)
	local lines = {}
	local function add(text) lines[#lines + 1] = text end

	for _, injury in ipairs(ChatLog.Injuries) do
		if injury.check(org) then add("Your " .. injury.text .. ".") end
	end

	for _, limb in ipairs({"lleg", "rleg", "larm", "rarm"}) do
		local name = (string.sub(limb, 1, 1) == "l" and "left " or "right ") .. (string.sub(limb, 2) == "leg" and "leg" or "arm")
		if org[limb .. "amputated"] then
			add("Your " .. name .. " is gone.")
		elseif hg.IsLimbIncapacitated and hg.IsLimbIncapacitated(org, limb) then
			add("Your " .. name .. " is useless.")
		elseif org[limb .. "dislocation"] or org[limb .. "_up_disl"] or org[limb .. "_down_disl"] then
			add("Your " .. name .. " is out of place.")
		elseif hg.IsLimbFractured and hg.IsLimbFractured(org, limb) then
			add("Your " .. name .. " is broken.")
		end
	end

	if org.headamputated then add("Your head is gone.") end

	local ribs = tonumber(org.brokenribs) or math.Round((tonumber(org.chest) or 0) * 12)
	if ribs >= 6 then add("Your ribcage is crushed, most of your ribs are broken.")
	elseif ribs > 1 then add("You have " .. ribs .. " broken ribs.")
	elseif ribs == 1 then add("One of your ribs is broken.") end

	for _, bone in ipairs(FRAGILE_BONES) do
		local value = tonumber(org[bone.key]) or 0
		if value >= FRAGILE_FROM and value < 1 then add(bone.text) end
	end

	local SoftTissue = hg.SoftTissue
	if SoftTissue and org.softBrute then
		local config = SoftTissue.Config
		local heavyRank = config.severityRank.heavy
		for _, limb in ipairs(SoftTissue.LIMBS) do
			local name = TISSUE_NAMES[limb]
			local brute = SoftTissue.GetSeverityKey(SoftTissue.Get(org, "brute", limb))
			local burn = SoftTissue.GetSeverityKey(SoftTissue.Get(org, "burn", limb))
			local muscle = SoftTissue.GetSeverityKey(SoftTissue.GetMuscle(org, limb), config.muscle.severity)
			if (config.severityRank[brute] or 0) >= heavyRank then add("Your " .. name .. " is " .. config.wording.brute[brute] .. ", the flesh is badly damaged.") end
			if (config.severityRank[burn] or 0) >= heavyRank then add("Your " .. name .. " is " .. config.wording.burn[burn] .. ".") end
			if (config.severityRank[muscle] or 0) >= heavyRank then add("The muscle in your " .. name .. " is " .. string.gsub(config.wording.muscle[muscle], " muscle", "") .. ".") end
		end
	end

	local simple = hg.SimpleHealth and hg.SimpleHealth.GetState(org)
	if simple then
		local health = hg.SimpleHealth.GetHealth(simple)
		if health <= 0 then add("You are barely clinging on.")
		elseif health < 25 then add("You are in terrible shape.")
		elseif health < 50 then add("You are badly hurt.")
		elseif health < 75 then add("You are hurt.")
		elseif health < 95 then add("You have a few scrapes and bruises.") end
	end

	local teeth = tonumber(org.teethLost) or 0
	if teeth >= 32 then add("You have no teeth left.") elseif teeth > 0 then add("You are missing " .. teeth .. (teeth == 1 and " tooth." or " teeth.")) end

	local bleed = tonumber(org.bleed) or 0
	if bleed > 5 then add("You are bleeding heavily.") elseif bleed > 1 then add("You are bleeding.") elseif bleed > 0.3 then add("You are bleeding a little.") end

	local arterial = istable(ply.arterialwounds) and #ply.arterialwounds or 0
	if arterial > 0 then add("Blood is pulsing out of you.") end

	local wounds = istable(ply.wounds) and #ply.wounds or 0
	if wounds > 0 then add("You have " .. wounds .. (wounds == 1 and " open wound." or " open wounds.")) end

	local blood = tonumber(org.blood) or 5000
	if blood < 2600 then add("You are about to pass out from blood loss.")
	elseif blood < 3300 then add("You feel very weak.")
	elseif blood < 4000 then add("You feel lightheaded.") end

	local pain = tonumber(org.pain) or 0
	if org.nearpainlimit or pain > 85 then add("The pain is unbearable.")
	elseif pain > 60 then add("You are in severe pain.")
	elseif pain > 30 then add("You are in pain.")
	elseif pain > 10 then add("You ache.") end

	if (tonumber(org.shock) or 0) > 40 then add("You feel cold and clammy, like you are going into shock.") end

	local o2 = OxygenLevel(org)
	if o2 < 8 then add("You are suffocating.") elseif o2 < 15 then add("You are short of breath.") end

	local co2 = tonumber(org.co2) or 0
	if co2 > 22 then add("Your head pounds and you can barely stay awake from the stale air in your lungs.")
	elseif co2 > 14 then add("Your head pounds and you feel dizzy.") end

	if (tonumber(org.consciousness) or 1) < 0.65 then add("Your vision swims and you struggle to stay conscious.") end

	local temperature = tonumber(org.temperature) or 36.6
	if temperature < 33 then add("You are shivering uncontrollably.") elseif temperature < 35 then add("You are freezing.") elseif temperature > 38.5 then add("You are burning up.") end

	return lines
end

concommand.Add("hg_inspect_self", function(ply)
	if not IsValid(ply) or not ply:Alive() then return end

	local org = ply.organism
	if not org or org.otrub then return end
	if (ply.hgInspectUntil or 0) > CurTime() then return end

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or not wep.GetBlocking then return end

	ply.hgInspectUntil = CurTime() + INSPECT_DURATION
	wep.ForceBlockUntil = CurTime() + INSPECT_DURATION

	timer.Simple(INSPECT_DURATION, function()
		if not IsValid(ply) or not ply:Alive() then return end

		local current = ply.organism
		if not current or current.otrub then return end

		local lines = InspectLines(ply, current)
		ply:zChatPrint(INSPECT_COLOR, "You check yourself over.")
		if #lines == 0 then
			ply:zChatPrint(INSPECT_GOOD, "You seem fine.")

			return
		end

		for _, line in ipairs(lines) do
			ply:zChatPrint(INSPECT_COLOR, line)
		end
	end)
end)
