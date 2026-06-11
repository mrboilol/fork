local min, max, Clamp = math.min, math.max, math.Clamp
if hg and hg.despair_server_builtin then return end

local hg_despair = CreateConVar("hg_despair", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Set despair level (0-1)", 0, 1)

local function get_despair_org(ent)
	if not IsValid(ent) then return nil end
	if ent:IsPlayer() then return ent.organism end
	if hg.RagdollOwner then
		local owner = hg.RagdollOwner(ent)
		if IsValid(owner) and owner:IsPlayer() then
			return owner.organism
		end
	end
end

local function is_corpse_ragdoll(ent)
	if not IsValid(ent) or not ent:IsRagdoll() then return false end
	if hg.RagdollOwner then
		local owner = hg.RagdollOwner(ent)
		if IsValid(owner) and owner:Alive() then
			return false
		end
	end
	return true
end

hook.Add("Org Clear", "hg_despair_init", function(org)
	org.despair = 0
	org._despairLastAdrenaline = 0
	org._despairNextCorpseCheck = 0
	org._corpseAdrenalineGiven = 0
	org.panicAttack = false
	org._panicAttackEndTime = 0
	org._panicAttackCheckTime = 0
	org._panicAttackStartTime = 0
	org._hadGoodMood = false
	org._despairLastGainedTime = 0
	org._despairLastPain = 0
	org._fearDuration = 0
end)

hook.Add("HomigradDamage", "hg_despair_damage_gain", function(ply, dmgInfo)
	local org = get_despair_org(ply)
	if not org then return end
	if org.otrub then return end

	local dmg = (dmgInfo and dmgInfo.GetDamage and dmgInfo:GetDamage()) or 0
	if dmg <= 0 then return end

	local add = Clamp(dmg / 240, 0.01, 0.18)
	if dmgInfo and dmgInfo.IsDamageType and dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_BLAST + DMG_BURN + DMG_SLASH + DMG_CLUB) then
		add = add * 1.2
	end

	org.despair = min((org.despair or 0) + add, 1)
	org._despairLastGainedTime = CurTime()
end)

hook.Add("Org Think", "hg_despair_think", function(owner, org, timeValue)
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end

	-- Apply convar override if set
	local convarValue = hg_despair:GetFloat()
	if convarValue > 0 then
		org.despair = Clamp(convarValue, 0, 1)
		return
	end

	org.despair = Clamp(org.despair or 0, 0, 1)
	-- Despair budge less unless despair hasn't been gained for a little bit
	local timeSinceGain = CurTime() - (org._despairLastGainedTime or 0)
	local despairDecay = timeValue / 180
	-- Slower decay if despair was gained recently (within 30 seconds)
	if timeSinceGain < 30 then
		if org.despair > 0.7 then
			despairDecay = timeValue / 360 -- Half decay rate when despair is high and recently gained
		elseif org.despair > 0.5 then
			despairDecay = timeValue / 270 -- Slower decay when despair is moderate and recently gained
		else
			despairDecay = timeValue / 240 -- Slower decay when recently gained
		end
	elseif org.despair > 0.7 then
		despairDecay = timeValue / 360 -- Half decay rate when despair is high
	elseif org.despair > 0.5 then
		despairDecay = timeValue / 270 -- Slower decay when despair is moderate
	end
	-- Faster decay if despair hasn't been gained in a while (60+ seconds)
	if timeSinceGain > 60 then
		despairDecay = despairDecay * (1 + (timeSinceGain - 60) / 60) -- Up to 2x faster after 120 seconds
	end
	org.despair = math.Approach(org.despair, 0, despairDecay)

	-- Opiates (analgesia) help reduce despair
	local analgesia = org.analgesia or 0
	local analgesiaAdd = org.analgesiaAdd or 0
	if analgesia > 0.5 or analgesiaAdd > 0.5 then
		local opiateRelief = (analgesia + analgesiaAdd) * timeValue * 0.05
		org.despair = math.max(org.despair - opiateRelief, 0)
	end

	-- Track fear duration for cumulative despair induction
	local fear = org.fear or 0
	if fear > 0.1 then
		org._fearDuration = (org._fearDuration or 0) + timeValue
	else
		org._fearDuration = math.max((org._fearDuration or 0) - timeValue * 0.5, 0)
	end

	-- Track if player had goodmood
	if (org.goodmood or 0) > 0.3 then
		org._hadGoodMood = true
	end

	local add = 0
	local adrenaline = org.adrenaline or 0
	local adrenalineAdd = org.adrenalineAdd or 0
	local prevAdrenaline = org._despairLastAdrenaline or adrenaline
	local adrenalineDelta = max(adrenaline - prevAdrenaline, 0)
	org._despairLastAdrenaline = adrenaline

	if adrenaline > 2.5 then
		add = add + (adrenaline - 2.5) * timeValue * 0.045
	end

	if adrenalineAdd > 0.35 then
		add = add + min(adrenalineAdd, 2) * timeValue * 0.03
	end

	if adrenalineDelta > 0 then
		add = add + min(adrenalineDelta * 0.25, 0.08)
	end

	if (org.fear or 0) > 0 then
		-- Transfer fear to despair - moderate rate regardless of fearAdd
		local fear = org.fear
		local fearTransferRate = 0.025 -- Base transfer rate
		-- Scale transfer rate with fear duration - up to 3x multiplier after 60 seconds of fear
		local fearDurationMultiplier = 1 + math.min((org._fearDuration or 0) / 60, 2)
		add = add + Clamp(fear, 0, 2) * timeValue * fearTransferRate * fearDurationMultiplier
	end

	if (org.pain or 0) > 45 then
		add = add + Clamp((org.pain - 45) / 85, 0, 1) * timeValue * 0.25
	end

	if (org.shock or 0) > 20 then
		add = add + Clamp((org.shock - 20) / 50, 0, 1) * timeValue * 0.12
	end

	if (org.bleed or 0) > 0 then
		-- Bleeding despair - 2 is severe bleeding (pouring blood)
		local bleedSeverity = Clamp(org.bleed / 2, 0, 1)
		add = add + bleedSeverity * timeValue * 0.25
	end

	-- Despair from damaged limbs (broken bones, fractures)
	local brokenLimbs = 0
	if (org.lleg or 0) >= 1 then brokenLimbs = brokenLimbs + 1 end
	if (org.rleg or 0) >= 1 then brokenLimbs = brokenLimbs + 1 end
	if (org.larm or 0) >= 1 then brokenLimbs = brokenLimbs + 1 end
	if (org.rarm or 0) >= 1 then brokenLimbs = brokenLimbs + 1 end
	if (org.pelvis or 0) >= 1 then brokenLimbs = brokenLimbs + 1 end
	if (org.skull or 0) >= 0.6 then brokenLimbs = brokenLimbs + 1 end
	if (org.chest or 0) >= 1 then brokenLimbs = brokenLimbs + 1 end
	if (org.spine1 or 0) >= 1 then brokenLimbs = brokenLimbs + 1 end
	if (org.spine2 or 0) >= 1 then brokenLimbs = brokenLimbs + 1 end
	if (org.spine3 or 0) >= 1 then brokenLimbs = brokenLimbs + 1 end

	if brokenLimbs > 0 then
		add = add + brokenLimbs * timeValue * 0.04
	end

	-- Despair from dying state (critical health/blood)
	if (org.blood or 5000) < 3750 then
		add = add + Clamp((3750 - org.blood) / 3750, 0, 1) * timeValue * 0.35
	end

	-- Despair from bleeding out (low blood + active bleeding - won't clot)
	local blood = org.blood or 5000
	local bleed = org.bleed or 0
	if blood < 3750 and bleed > 0 then
		local bleedSeverity = Clamp((3750 - blood) / 3750, 0, 1)
		-- Higher despair gain when actively bleeding out (blood won't clot)
		add = add + bleedSeverity * timeValue * 0.4
	end

	-- Despair from lack of goodmood (if goodmood has been low for a while)
	local goodmood = org.goodmood or 0
	if goodmood < 0.3 then
		org._lowGoodMoodTime = (org._lowGoodMoodTime or 0) + timeValue
		-- After 60 seconds of low goodmood, start adding despair
		if org._lowGoodMoodTime > 60 then
			add = add + (0.3 - goodmood) * timeValue * 0.03
		end
	else
		org._lowGoodMoodTime = 0
	end



	if (org.consciousness or 1) < 0.7 then
		add = add + Clamp((0.7 - org.consciousness) / 0.7, 0, 1) * timeValue * 0.12
	end

	if (org.hungry or 0) > 55 then
		add = add + Clamp((org.hungry - 55) / 45, 0, 1) * timeValue * 0.05
	end

	if org.o2 and org.o2[1] then
		local o2 = org.o2[1]
		if o2 < 18 then
			add = add + Clamp((18 - o2) / 18, 0, 1) * timeValue * 0.4
		end

		local curregen = org.o2.curregen or 0
		local losing = org.losing_oxy or 0
		if curregen < losing then
			add = add + Clamp(losing - curregen, 0, 2) * timeValue * 0.15
		end
	end

	local time = CurTime()
	if (org._despairNextCorpseCheck or 0) <= time then
		org._despairNextCorpseCheck = time + 0.25

		local eyePos = owner:EyePos()
		local aim = owner:GetAimVector()
		local corpsesSeen = 0
		local rag = owner.FakeRagdoll
		local traceFilter = IsValid(rag) and {owner, rag} or owner

		for _, ent in ipairs(ents.FindInCone(eyePos, aim, 1024, math.cos(math.rad(26)))) do
			if ent == owner or ent == rag then continue end
			if not is_corpse_ragdoll(ent) then continue end

			local tr = util.TraceLine({
				start = eyePos,
				endpos = ent:WorldSpaceCenter(),
				filter = traceFilter
			})

			if tr.Entity == ent or not tr.Hit then
				corpsesSeen = corpsesSeen + 1
			end

			if corpsesSeen >= 3 then break end
		end

		if corpsesSeen > 0 then
			add = add + timeValue * 0.15 * corpsesSeen

			-- Give a tiny bit of adrenaline from seeing corpses, but cap total contribution
			local maxCorpseAdrenaline = 0.3
			local given = org._corpseAdrenalineGiven or 0
			if given < maxCorpseAdrenaline then
				local boost = min(0.02 * corpsesSeen, maxCorpseAdrenaline - given)
				org.adrenalineAdd = (org.adrenalineAdd or 0) + boost
				org._corpseAdrenalineGiven = given + boost
			end
		end
	end

	if add > 0 then
		-- Chip away at goodmood first before adding despair
		local goodmood = org.goodmood or 0
		if goodmood > 0 then
			local goodmoodLoss = min(add, goodmood)
			org.goodmood = goodmood - goodmoodLoss
			add = add - goodmoodLoss
		end
		org.despair = min(org.despair + add, 1)
		org._despairLastGainedTime = CurTime()
	end

	-- Cap despair at 0.5 if player had goodmood and still has some goodmood left
	-- BUT: Allow despair to exceed 0.5 during the 30-second penalty window after losing goodmood
	local timeSinceLoss = CurTime() - (org._goodmoodLostTime or 0)
	local inPenaltyWindow = timeSinceLoss < 30

	if org._hadGoodMood and (org.goodmood or 0) > 0 and not inPenaltyWindow then
		org.despair = min(org.despair, 0.5)
	end

	if org.despair >= 0.8 then
		org.disorientation = max(org.disorientation or 0, 1)
	end

	if org.despair > 0.9 then
        if not org._despair_check_time or CurTime() > org._despair_check_time then
            org._despair_check_time = CurTime() + 1 -- check every second

            local chance = (org.despair - 0.9) / 0.1 * 0.05 -- at 1.0 despair, 5% chance
            if math.random() < chance then
                org.heartstop = true
                org.lungsfunction = false
            end
        end
    end

	-- Panic attack logic
	local time = CurTime()
	if org.panicAttack then
		-- Decrease despair slowly during panic attack
		org.despair = math.Approach(org.despair, 0, timeValue * 0.3)
		
		-- Check if panic attack should end
		if time > org._panicAttackEndTime then
			org.panicAttack = false
		else
			-- Small chance of heart attack during panic attack
			if not org._panicHeartAttackCheck or time > org._panicHeartAttackCheck then
				org._panicHeartAttackCheck = time + 2
				if math.random() < 0.02 then -- 2% chance every 2 seconds during panic attack
					org.heartstop = true
					org.lungsfunction = false
				end
			end
		end
	else
		-- Check if panic attack should trigger (despair > 0.85)
		if org.despair > 0.85 then
			-- Start tracking time if not already tracking
			if not org._panicAttackStartTime then
				org._panicAttackStartTime = time
			end

			-- Check if 30 seconds have passed (guaranteed trigger)
			if time - org._panicAttackStartTime >= 30 then
				org.panicAttack = true
				org._panicAttackEndTime = time + math.random(8, 15)
				org._panicHeartAttackCheck = 0
				org._panicAttackStartTime = nil
			-- Before 30 seconds, use random chance
			elseif not org._panicAttackCheckTime or time > org._panicAttackCheckTime then
				org._panicAttackCheckTime = time + 1
				local triggerChance = (org.despair - 0.85) / 0.15 * 0.1 -- up to 10% chance per second at max despair
				if math.random() < triggerChance then
					org.panicAttack = true
					org._panicAttackEndTime = time + math.random(8, 15)
					org._panicHeartAttackCheck = 0
					org._panicAttackStartTime = nil
				end
			end
		else
			-- Reset timer if despair drops below threshold
			org._panicAttackStartTime = nil
		end
	end
end)

hook.Add("HG_MovementCalc_2", "hg_panic_attack_slow", function(mul, ply, cmd, mv)
	local org = ply.organism
	if not org then return end
	
	if org.panicAttack then
		mul[1] = mul[1] * 0.3 -- reduce movement speed to 30% during panic attack
	end
end)
