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
		lines = {false, "You are bleeding out!"},
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

local OTRUB_REPEAT = 15
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
					org.hgOtrubSeen[line.key] = now + OTRUB_REPEAT
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
