local min, max, Clamp = math.min, math.max, math.Clamp
if hg and hg.despair_server_builtin then return end
hg.despair_server_builtin = true

local hg_despair_override = CreateConVar("hg_despair_override", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Global despair override (0-1)", 0, 1)
local hg_despairsystem = CreateConVar("hg_despairsystem", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Despair system mode (0 = normal, 1 = giving-up only: despair/panic disabled, give up driven by fear and dying severity)", 0, 1)

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
	org.givingUp = false
	org._giveUpCheckTime = 0
	org._panicAdrenalineGiven = false
	org._postPanicEndTime = 0
	org._giveUpHeartStopCheck = 0
	org._despairLastBP = nil
end)

hook.Add("HomigradDamage", "hg_despair_damage_gain", function(ply, dmgInfo)
	local org = get_despair_org(ply)
	if not org then return end
	if org.otrub then return end
	if hg_despairsystem:GetInt() == 1 then return end

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

	local time = CurTime()
	local simpleMode = hg_despairsystem:GetInt() == 1

	-- In simple mode despair and panic are fully disabled
	if simpleMode then
		org.despair = 0
		org.panicAttack = false
		org._panicAttackEndTime = 0
		org._panicAttackStartTime = nil
		org._panicAttackCheckTime = nil
	end

	-- Give up mechanic: chance to give up when dying or bleeding out
	-- Cannot give up during a panic attack (panic and giving up must not stack)
	if not org.givingUp then
		local o2val = org.o2 and org.o2[1] or 0
		local blood = org.blood or 5000
		local bleed = org.bleed or 0

		local isDying = (o2val > 50 and not org.otrub)
		local isBleedingOut = blood >= 3000 and blood <= 3250 and bleed > 0
		local isUnconsciousDying = org.otrub and o2val > 20

		if (isDying or isBleedingOut or isUnconsciousDying) and not org.panicAttack then
			org._giveUpCheckTime = org._giveUpCheckTime or 0
			if CurTime() > org._giveUpCheckTime then
				org._giveUpCheckTime = CurTime() + 1

				local chance = 0.02 -- 2% per second base
				if isDying and isBleedingOut then
					chance = 0.05 -- 5% if both dying and bleeding out
				end
				-- After a panic attack ends, the body is more likely to give up
				if not simpleMode and org._postPanicEndTime and (CurTime() - org._postPanicEndTime) < 20 then
					chance = chance + 0.03 * (1 - (CurTime() - org._postPanicEndTime) / 20)
				end

				-- Fear and how badly the player is dying push them toward giving up.
				-- In simple mode this fully replaces the despair/panic-driven path.
				local fearFactor = Clamp((org.fear or 0) / 2, 0, 1)
				local severity = 0
				if isDying then severity = max(severity, Clamp((o2val - 50) / 50, 0, 1)) end
				if isBleedingOut then severity = max(severity, Clamp((3250 - blood) / 250, 0, 1)) end
				if isUnconsciousDying then severity = max(severity, Clamp((o2val - 20) / 80, 0, 1)) end
				if simpleMode then
					chance = 0.015 + severity * 0.05 + fearFactor * 0.04
				else
					chance = chance + fearFactor * severity * 0.02
				end

				if math.random() < chance then
					org.givingUp = true
					org._panicAdrenalineGiven = false
				end
			end
		else
			org._giveUpCheckTime = 0
		end
	else
		local o2val = org.o2 and org.o2[1] or 0
		local blood = org.blood or 5000
		local bleed = org.bleed or 0

		local isDying = (o2val > 50 and not org.otrub)
		local isBleedingOut = blood >= 3000 and blood <= 3250 and bleed > 0
		local isUnconsciousDying = org.otrub and o2val > 20

		if not isDying and not isBleedingOut and not isUnconsciousDying then
			org.givingUp = false
			org._giveUpCheckTime = 0
			org._giveUpHeartStopCheck = 0
			-- Recovery: treated or no longer dying, despair fades and goodmood returns
			org.goodmood = math.min((org.goodmood or 0) + timeValue * 0.03, 1)
			org._postPanicEndTime = 0
		else
			org.despair = math.max(org.despair, 0.25)
			org.panicAttack = false
			org._panicAttackEndTime = 0
			org._panicAttackStartTime = nil
			org._panicAttackCheckTime = nil
			org._panicAdrenalineGiven = false
			-- Giving up: chance of heartstop every few seconds; not a guaranteed death
			if not org._giveUpHeartStopCheck or time > org._giveUpHeartStopCheck then
				org._giveUpHeartStopCheck = time + 4
				local bp = org.bloodpressure or 93
				local hb = org.heartbeat or 70
				-- Base 6% chance every 4 seconds; scales up with critically low vitals
				local stopChance = 0.06
				if bp < 50 then
					stopChance = stopChance + (50 - bp) / 50 * 0.10
				end
				if hb < 50 then
					stopChance = stopChance + (50 - hb) / 50 * 0.08
				end
				local totalAdrenaline = (org.adrenaline or 0) + (org.adrenalineAdd or 0)
				if totalAdrenaline > 0.5 then
					stopChance = stopChance * math.max(0.1, 1 - (totalAdrenaline - 0.5) * 0.3)
				end
				if math.random() < stopChance then
					org.heartstop = true
					org.lungsfunction = false
				end
			end
		end
	end

	-- Simple mode: despair and panic are disabled, only giving up remains
	if simpleMode then
		org.despair = 0
		org.panicAttack = false
		return
	end

	-- Apply convar override if set
	local convarValue = hg_despair_override:GetFloat()
	if convarValue > 0 then
		org.despair = Clamp(convarValue, 0, 1)
		return
	end

	org.despair = Clamp(org.despair or 0, 0, 1)
	-- Berserk and noradrenaline block and remove despair
	if (org.berserk or 0) > 0 or (org.noradrenaline or 0) > 0 then
		org.despair = 0
		return
	end

	-- If they just gained despair, make it hard for it to go away
	local currentDespair = org.despair or 0
	local lastDespair = org._lastDespair or 0
	if currentDespair > lastDespair then
		-- Lock decay based on the amount of despair gained (e.g., if it went all the way up to 1.0, lock for 30 seconds)
		local gained = currentDespair - lastDespair
		org._despairLockUntil = math.max(org._despairLockUntil or 0, CurTime() + 10 + (gained * 30))
	end
	local isLocked = CurTime() < (org._despairLockUntil or 0)

	-- Despair budge less unless despair hasn't been gained for a little bit
	local timeSinceGain = CurTime() - (org._despairLastGainedTime or 0)
	local despairDecay = timeValue / 180
	if isLocked then
		despairDecay = 0
	else
		-- Faster decay when unconscious (otrub) - unconsciousness helps despair go away
		if org.otrub then
			despairDecay = despairDecay * 3
		end
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
	end
	org.despair = math.Approach(org.despair, 0, despairDecay)

	-- Opiates (analgesia) help reduce despair
	local analgesia = org.analgesia or 0
	local analgesiaAdd = org.analgesiaAdd or 0
	if analgesia > 0.5 or analgesiaAdd > 0.5 then
		local opiateRelief = (analgesia + analgesiaAdd) * timeValue * 0.05
		if isLocked then
			opiateRelief = 0
		end
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

	-- During a panic attack the body is flooded with adrenaline and fear as the
	-- panic response itself - feeding those back into despair creates a runaway loop.
	if not org.panicAttack then
		if adrenaline > 2.5 then
			add = add + (adrenaline - 2.5) * timeValue * 0.045
		end

		if adrenalineAdd > 0.35 then
			add = add + min(adrenalineAdd, 2) * timeValue * 0.03
		end

		if adrenalineDelta > 0 then
			add = add + min(adrenalineDelta * 0.25, 0.03)
		end

		if (org.fear or 0) > 0 then
			-- Transfer fear to despair only when in incredible pain or dying
			local pain = org.pain or 0
			local blood = org.blood or 5000
			local o2val = org.o2 and org.o2[1] or 100
			local dyingOrAgony = pain > 70 or blood < 3000 or o2val > 60
			if dyingOrAgony then
				local fear = org.fear
				local fearTransferRate = 0.004 -- Base transfer rate
				-- Scale transfer rate with fear duration - up to 2x multiplier after 60 seconds of sustained fear
				local fearDurationMultiplier = 1 + math.min((org._fearDuration or 0) / 60, 1)
				add = add + Clamp(fear, 0, 2) * timeValue * fearTransferRate * fearDurationMultiplier
			end
		end
	end

	if (org.pain or 0) > 45 then
		add = add + Clamp((org.pain - 45) / 85, 0, 1) * timeValue * 0.14
	end

	if (org.shock or 0) > 20 then
		add = add + Clamp((org.shock - 20) / 50, 0, 1) * timeValue * 0.07
	end

	local currentBP = org.bloodpressure or 93
	local lastBP = org._despairLastBP or currentBP
	local bpRising = currentBP > lastBP
	org._despairLastBP = currentBP

	local bleedRate = org.bleed or 0
	local bleedStopped = bleedRate < 0.05 -- negligible bleed rate (clotted/stopped)

	if bleedRate > 0 and not bleedStopped and not bpRising then
		-- Bleeding despair - 2 is severe bleeding (pouring blood)
		local bleedSeverity = Clamp(bleedRate / 2, 0, 1)
		add = add + bleedSeverity * timeValue * 0.14
	elseif bleedStopped or bpRising then
		-- Bleeding stopped or cardiac recovering: relieve despair
		local relief = timeValue * 0.15
		if CurTime() < (org._despairLockUntil or 0) then
			relief = 0
		end
		org.despair = math.max((org.despair or 0) - relief, 0)
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

	-- Despair from dying state (critical health/blood) - only while still bleeding
	local blood = org.blood or 5000
	if blood < 3750 and not bleedStopped then
		add = add + Clamp((3750 - blood) / 3750, 0, 1) * timeValue * 0.18
	end

	-- Despair from bleeding out (low blood + active bleeding - won't clot)
	if blood < 3750 and bleedRate > 0 and not bleedStopped and not bpRising then
		local bleedSeverity = Clamp((3750 - blood) / 3750, 0, 1)
		-- Higher despair gain when actively bleeding out (blood won't clot)
		add = add + bleedSeverity * timeValue * 0.2
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
			add = add + Clamp((18 - o2) / 18, 0, 1) * timeValue * 0.22
		end

		local curregen = org.o2.curregen or 0
		local losing = org.losing_oxy or 0
		if curregen < losing then
			add = add + Clamp(losing - curregen, 0, 2) * timeValue * 0.15
		end
	end

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
			add = add + timeValue * 0.06 * math.min(corpsesSeen, 2)

			local maxCorpseAdrenaline = 0.3
			local given = org._corpseAdrenalineGiven or 0
			if given < maxCorpseAdrenaline then
				local boost = min(0.008 * corpsesSeen, maxCorpseAdrenaline - given)
				org.adrenalineAdd = (org.adrenalineAdd or 0) + boost
				org._corpseAdrenalineGiven = given + boost
			end
		else
			org._corpseAdrenalineGiven = math.max((org._corpseAdrenalineGiven or 0) - 0.015, 0)
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
            local totalAdrenaline = (org.adrenaline or 0) + (org.adrenalineAdd or 0)
            if totalAdrenaline > 1.0 then
                chance = chance * math.max(0, 1 - (totalAdrenaline - 1.0) * 0.4)
            end
            if math.random() < chance then
                org.heartstop = true
                org.lungsfunction = false
            end
        end
    end

	-- Panic attack logic
	if org.panicAttack then
		-- Decrease despair slowly during panic attack
		org.despair = math.Approach(org.despair, 0.65, timeValue * 0.3)
		
		-- Check if panic attack should end (timed out or recovered)
		if time > org._panicAttackEndTime then
			org.panicAttack = false
			org._panicAttackEndTime = 0
			org._panicAttackStartTime = nil
			org._panicAttackCheckTime = nil
			org._panicAdrenalineGiven = false
			org._postPanicEndTime = time
			-- Panic didn't save them: chance to give up after panic ends if still in danger
			local o2val = org.o2 and org.o2[1] or 0
			local blood = org.blood or 5000
			local bleed = org.bleed or 0
			local stillDying = (o2val > 50 and not org.otrub) or (blood >= 3000 and blood <= 3250 and bleed > 0) or (org.otrub and o2val > 20)
			if stillDying and math.random() < 0.55 then
				org.givingUp = true
				org._panicAdrenalineGiven = false
			end
		else
			-- Check recovery: healed / no longer dying
			local o2val = org.o2 and org.o2[1] or 0
			local blood = org.blood or 5000
			local bleed = org.bleed or 0
			local isDying = (o2val > 50 and not org.otrub)
			local isBleedingOut = blood < 4000 and bleed > 0
			local isUnconsciousDying = org.otrub and o2val > 20

			if not isDying and not isBleedingOut and not isUnconsciousDying then
				org.panicAttack = false
				org._panicAttackEndTime = 0
				org._panicAttackStartTime = nil
				org._panicAttackCheckTime = nil
				org._panicAdrenalineGiven = false
				org._postPanicEndTime = time
			end
			-- No heartstop chance during panic
		end
	else
		-- Check if panic attack should trigger (despair > 0.7)
		if org.despair > 0.7 then
			-- Start tracking time if not already tracking
			if not org._panicAttackStartTime then
				org._panicAttackStartTime = time
			end

			if not org._panicAttackCheckTime or time > org._panicAttackCheckTime then
				org._panicAttackCheckTime = time + 1

				-- Small chance to skip panic entirely and go straight to giving up
				local skipToPanic = math.random() > 0.12 -- 12% chance to skip panic, 88% to panic

				-- Guaranteed panic after 20 seconds at despair > 0.7
				local triggerChance = (org.despair - 0.7) / 0.3 * 0.18 -- up to 18% chance per second at max despair
				local forceTrigger = (time - org._panicAttackStartTime >= 20)

				if forceTrigger or math.random() < triggerChance then
					if skipToPanic then
						org.panicAttack = true
						org._panicAttackEndTime = time + math.random(8, 18)
						org._panicAttackStartTime = nil
						if not org._panicAdrenalineGiven then
							local reserve = min(org.adrenaline or 0, 1.5)
							org.adrenaline = (org.adrenaline or 0) - reserve
							org.adrenalineAdd = (org.adrenalineAdd or 0) + 1.5
							org._panicAdrenalineGiven = true
						end
					else
						-- Skip to giving up only if in a dying state
						local o2val = org.o2 and org.o2[1] or 0
						local blood = org.blood or 5000
						local bleed = org.bleed or 0
						local isDying = (o2val > 50 and not org.otrub) or (blood >= 3000 and blood <= 3250 and bleed > 0) or (org.otrub and o2val > 20)
						if isDying then
							org.givingUp = true
							org._panicAdrenalineGiven = false
							org._panicAttackStartTime = nil
						else
							-- Not dying, just panic normally
							org.panicAttack = true
							org._panicAttackEndTime = time + math.random(8, 18)
							org._panicAttackStartTime = nil
							if not org._panicAdrenalineGiven then
								local reserve = min(org.adrenaline or 0, 1.5)
								org.adrenaline = (org.adrenaline or 0) - reserve
								org.adrenalineAdd = (org.adrenalineAdd or 0) + 1.5
								org._panicAdrenalineGiven = true
							end
						end
					end
				end
			end
		else
			-- Reset timer if despair drops below threshold
			org._panicAttackStartTime = nil
		end
	end

	org._lastDespair = org.despair
end)

hook.Add("HG_MovementCalc_2", "hg_panic_attack_slow", function(mul, ply, cmd, mv)
	local org = ply.organism
	if not org then return end
	
	if org.panicAttack then
		mul[1] = mul[1] * 0.3 -- reduce movement speed to 30% during panic attack
	end
end)

concommand.Add("hg_despair", function(ply, cmd, args)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if not ply:IsAdmin() then return end

	local val = tonumber(args[1])
	if val == nil then
		ply:ChatPrint("Usage: hg_despair <0-1>")
		return
	end

	local org = ply.organism
	if not org then return end

	org.despair = Clamp(val, 0, 1)
	ply:ChatPrint("[Debug] Despair set to " .. tostring(org.despair))
end)

concommand.Add("hg_panic", function(ply, cmd, args)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if not ply:IsAdmin() then return end

	local val = tobool(args[1])
	local org = ply.organism
	if not org then return end

	if val then
		org.despair = 1.0
		org.panicAttack = true
		org._panicAttackEndTime = CurTime() + math.random(8, 15)
		org._panicHeartAttackCheck = 0
		org._panicAttackStartTime = nil
		if not org._panicAdrenalineGiven then
			local reserve = min(org.adrenaline or 0, 0.75)
			org.adrenaline = (org.adrenaline or 0) - reserve
			org.adrenalineAdd = (org.adrenalineAdd or 0) + 0.75
			org._panicAdrenalineGiven = true
		end
		ply:ChatPrint("[Debug] Panic attack triggered. Set despair level to 1.0 to create a panic attack.")
	else
		org.panicAttack = false
		org._panicAttackEndTime = 0
		org._panicAttackStartTime = nil
		org._panicAttackCheckTime = nil
		org._panicAdrenalineGiven = false
		org._postPanicEndTime = CurTime()
		ply:ChatPrint("[Debug] Panic attack ended.")
	end
end)

concommand.Add("hg_giveup", function(ply, cmd, args)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if not ply:IsAdmin() then return end

	local val = tobool(args[1])
	local org = ply.organism
	if not org then return end

	if val then
		org.blood = 3000
		org.bleed = 1
		org.despair = 0.85
		org.givingUp = true
		org._panicAdrenalineGiven = false
		org._panicAttackEndTime = 0
		org.panicAttack = false
		ply:ChatPrint("[Debug] Give up triggered. Reduced blood to 3000 to create dying/bleeding out state, added some despair, and initiated give up (itssofuckingover.mp3).")
	else
		org.givingUp = false
		org._giveUpCheckTime = 0
		org._giveUpHeartStopCheck = 0
		ply:ChatPrint("[Debug] Give up ended.")
	end
end)
