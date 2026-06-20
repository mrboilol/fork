local min, max, Round, halfValue2 = math.min, math.max, math.Round, util.halfValue2
--local Organism = hg.organism
hg.organism.module.pulse = {}
local module = hg.organism.module.pulse



module[1] = function(org)
	org.heart = 0
	org.heartstop = false
	org.pulse = 70 -- that's the blood pressure
	org.heartbeat = 70
		org.bloodpressure = 93
	org.systolic = 120
	org.diastolic = 80

	org.tempchanging = 0
	org.heatbuff = 30 -- seconds of heat supply
	org.needed_temp = 36.7
end

function hg.organism.should_gain_fear(org)
	return ((org.pain > 30) or (org.blood < 4000) or (org.bleed > 1))// + (org.just_damaged_bone and ((org.just_damaged_bone + 10 - CurTime()) >= 10) and 10 or 0)
end

module[2] = function(owner, org, timeValue)
	local heart = 1 - org.heart
	-- Brain damage weakens the heart but never fully stops it (floor keeps a baseline pulse)
	local brain = math.Clamp(1 - org.brain * 1.5,0.35,1)
	local o2 = org.o2
	local o2 = halfValue2(o2[1], o2.range, o2.k)

	//if org.isPly and not org.otrub and (heart == 0) then org.owner:Notify("My torso hurts.",true,"heart",6) end
	//if org.isPly and not org.otrub and org.heartstop then org.owner:Notify("",true,"heartstop",6) end

	local stamina = org.stamina
	
	local pulse = 70-- + 120 * ((stamina.max or 180) - stamina[1]) / (stamina.max or 180) * (org.lungsfunction and 1 or 0)
	--pulse = pulse + math.min(org.adrenaline, 2) * 40 + (!org.otrub and math.max(org.fear * 50, 0) or 0)
	pulse = org.alive and pulse or 0
	pulse = math.Clamp(pulse, 0, 200)
	
	org.pulse = math.Approach(org.pulse, pulse, pulse > org.pulse and timeValue * 2 or timeValue * 2)
	
	--local k = heart * o2 * (1 / math.Clamp((org.blood - 2000) / 3000,0.2,1)) * brain * (org.heartstop and 0.1 or 1) --* halfValue2(stamina[2], stamina.fatigueRange, stamina.fatigueK)
	local k = heart * o2 * (math.Clamp((org.blood - 1500) / 3500, 0.5, 1)) * brain * (org.heartstop and 0.1 or 1)
	pulse = pulse * k
	pulse = pulse * (math.Clamp(math.Remap(org.temperature, 28, 36.7, 0.5, 1), 0.5, 1))
	
	org.pulse = math.Approach(org.pulse, pulse, heart == 0 and timeValue * 10 or timeValue * 5)

	org.fearadd = math.Clamp(org.fearadd, 0, 3)

	-- Convert excess fearadd to despair only when in incredible pain or dying
	if org.fearadd > 1.5 then
		local excessFear = org.fearadd - 1.5
		local pain = org.pain or 0
		local blood = org.blood or 5000
		local o2val = org.o2 and org.o2[1] or 100
		local dyingOrAgony = pain > 70 or blood < 3000 or o2val > 60
		if dyingOrAgony then
			local despairConversion = excessFear * timeValue * 0.005
			org.despair = math.min((org.despair or 0) + despairConversion, 1)
			org.fearadd = math.max(org.fearadd - despairConversion, 1.5)
			org._despairLastGainedTime = CurTime()
		end
	end

	-- If goodmood was fully chipped away by fear and we got some excess fearadd, add it to despair
	-- Guarded: only convert if the player is actually hurt/dying, so fresh-spawn players never spiral into panic.
	if (org.goodmood or 0) <= 0 and org.fearadd > 0.5 and hg.organism.should_gain_fear(org) then
		local excessFear = org.fearadd - 0.5
		local despairConversion = excessFear * timeValue * 0.02
		org.despair = math.min((org.despair or 0) + despairConversion, 1)
		org.fearadd = math.max(org.fearadd - despairConversion, 0.5)
		org._despairLastGainedTime = CurTime()
	end

	local heartbeat = org.pulse < 70 and (org.brain > 0 and org.pulse or 70 + (70 - org.pulse) * 4) or org.pulse

	local runnin_or_exhausted = org.analgesia < 1 and (org.stamina.sub > 0 or org.stamina[1] < (org.stamina.max * 0.66))
	org.heartbeat = math.Approach(org.heartbeat, math.max(heartbeat - 10, runnin_or_exhausted and ((1 - math.min(1, org.stamina[1] / (org.stamina.max * 1))) * 110 + 90) or 60), !runnin_or_exhausted and timeValue * 2 or timeValue * 15)
	
	heartbeat = heartbeat + (owner.suiciding and 50 or 0)
	heartbeat = heartbeat + 40 * math.max(0, org.fear)
	heartbeat = heartbeat + math.Clamp(org.shock, 0, 40)
	heartbeat = heartbeat + math.Clamp(org.pain, 40, 80) - 40
	local adrenalineHeartBoost = 15 * math.min(org.adrenaline, 3)
	if org.givingUp then adrenalineHeartBoost = adrenalineHeartBoost * 0.3 end
	heartbeat = heartbeat + adrenalineHeartBoost
	heartbeat = heartbeat - 40 * math.min(org.analgesia / 2.5, 1)
	heartbeat = heartbeat + 100 * math.Clamp(math.Remap(org.temperature, 40, 42, 0, 1), 0, 1)
	heartbeat = heartbeat - 160 * (1 - math.Clamp(math.Remap(org.temperature, 28, 36.7, 0, 1), 0, 1))
	if org.panicAttack then heartbeat = heartbeat + 20 end -- adrenaline handles most of the boost
	local despairHeartBoost = math.Clamp((org.despair or 0) - 0.3, 0, 0.7) / 0.7 * 35
	if org.panicAttack then despairHeartBoost = despairHeartBoost * 0.5 end
	heartbeat = heartbeat + despairHeartBoost
	if org.givingUp then heartbeat = heartbeat * 0.6 end

	-- Brain damage drags the heart rate down (weaker pumping) but never to zero
	local brainHeartMul = math.Clamp(1 - org.brain, 0.35, 1)
	heartbeat = heartbeat * brainHeartMul

	org.heartbeat = math.Approach(org.heartbeat, heartbeat, heartbeat > org.heartbeat and timeValue * 5 or timeValue * 3)
	
	-- Probabilistic heartstop based on heart rate
	if not org._heart_rate_check_time or CurTime() > org._heart_rate_check_time then
		org._heart_rate_check_time = CurTime() + 1 -- check every second

		local hb = org.heartbeat
		local chance = 0
		if hb >= 400 then
			chance = 0.25
		elseif hb >= 375 then
			chance = 0.1
		elseif hb >= 350 then
			chance = 0.075
		elseif hb >= 300 then
			chance = 0.05
		elseif hb >= 200 then
			chance = 0.025
		end

		if org.panicAttack then chance = chance * 0.5 end
		if org.givingUp then chance = chance * 1.5 end

		if chance > 0 and math.random() < chance then
			org.heartstop = true
		end
	end
	
	local blood = math.Clamp(org.blood or 5000, 0, 5000)
	local bloodK = math.Clamp((blood - 2000) / 2000, 0, 1)
	local o2K = math.Clamp(o2, 0, 1)
	local heartK = math.Clamp(1 - org.heart, 0, 1)
	local brainK = math.Clamp(1 - org.brain * 1.25, 0, 1)
	local hypothermiaK = math.Clamp(math.Remap(org.temperature, 28, 36.7, 0.45, 1), 0.45, 1)
	local adrenalineHyperMul = math.Clamp(org.adrenaline, 0, 5) * 0.15
	if org.givingUp then adrenalineHyperMul = adrenalineHyperMul * 0.3 end
	local hypertensionMul = 1 + adrenalineHyperMul + math.Clamp(org.fear, 0, 2) * 0.05 + math.Clamp(org.pain, 0, 120) / 120 * 0.06 + math.Clamp(org.shock, 0, 80) / 80 * 0.08
	hypertensionMul = hypertensionMul * (1 - math.Clamp(org.analgesia / 4, 0, 1) * 0.08)
	hypertensionMul = math.Clamp(hypertensionMul, 0.72, 2.0)

	local compensation = 1 + math.Clamp((3000 - blood) / 1000, 0, 1) * 0.16
	compensation = compensation * (1 - math.Clamp((2250 - blood) / 500, 0, 1) * 0.5)
	compensation = math.Clamp(compensation, 0.35, 1.2)

	local pulse_factor = org.pulse / 70
	local map = 93 * pulse_factor * hypertensionMul * compensation
	map = org.alive and map or 0

	if org.heartstop then
		map = 0
	end

	-- High velocity reduces blood pressure (falling or fast vehicle movement)
	local velocity = owner:GetVelocity():Length()
	if velocity > 500 then
		local velocityPenalty = math.Clamp((velocity - 500) / 300, 0, 0.65) -- Up to 65% reduction at very high speeds
		map = map * (1 - velocityPenalty)
	end

	if org.givingUp then map = map * 0.5 end

	map = math.Clamp(map, 0, 190)
	org.bloodpressure = math.Approach(org.bloodpressure or 93, map, timeValue * (map > (org.bloodpressure or 93) and 14 or 10))

	local pulsePressure = 40 * heartK * math.max(bloodK, 0.3)
	pulsePressure = pulsePressure * (1 + math.Clamp((org.heartbeat - 70) / 180, -0.2, 0.6))
	pulsePressure = math.Clamp(pulsePressure, 8, 95)

	local targetDiastolic = math.Clamp(org.bloodpressure - pulsePressure * 0.5, 0, 180)
	local targetSystolic = math.Clamp(targetDiastolic + pulsePressure, 0, 260)

	org.diastolic = math.Approach(org.diastolic or 80, targetDiastolic, timeValue * 16)
	org.systolic = math.Approach(org.systolic or 120, targetSystolic, timeValue * 16)

    if org.bloodpressure < 50 then
        -- Adrenaline, tranexamic acid and thiamine prevent organ damage from low blood pressure
        local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
        local hasAntiIschemia = totalAdrenaline > 0.5 or (org.tranexamic_acid or 0) > 0 or (org.thiamine or 0) > 0
        if not hasAntiIschemia then
            local ischemiaK = math.Clamp((50 - org.bloodpressure) / 30, 0, 1)
            local damage = timeValue * ischemiaK * 0.005
            org.brain = math.min(org.brain + damage * 0.2, 1)
            org.heart = math.min(org.heart + damage, 1)
            org.liver = math.min(org.liver + damage * 0.5, 1)
            org.stomach = math.min(org.stomach + damage * 0.3, 1)
            org.intestines = math.min(org.intestines + damage * 0.3, 1)
        end
    end

	local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
	local adrenalineStabilizer = totalAdrenaline > 0.5
	
	-- Tranexamic acid and thiamine accelerate ischemia regression
	local hasAntiIschemia = (org.tranexamic_acid or 0) > 0 or (org.thiamine or 0) > 0

	if org.ischemia > 0 then
		if org.ischemia > 1 and not adrenalineStabilizer and not hasAntiIschemia then
			local ischemiaK = math.Clamp((org.ischemia - 1) / 5, 0, 1)
			local damage = timeValue * ischemiaK * 0.007
			org.brain = math.min(org.brain + damage * 0.2, 1)
			org.heart = math.min(org.heart + damage, 1)
			org.liver = math.min(org.liver + damage * 0.5, 1)
			org.stomach = math.min(org.stomach + damage * 0.3, 1)
			org.intestines = math.min(org.intestines + damage * 0.3, 1)
		end

		-- Epinephrine/adrenaline above 0.5 accelerates ischemia regression
		-- Tranexamic acid and thiamine also accelerate ischemia regression
		local decayRate = (adrenalineStabilizer or hasAntiIschemia) and timeValue / 2 or timeValue / 10
		org.ischemia = math.max(org.ischemia - decayRate, 0)
	end

	-- Disorientation: 0.5 at BP 75, 1.5 at BP 40
	if org.bloodpressure < 75 then
		local disorientK = math.Clamp((75 - org.bloodpressure) / 35, 0, 1)
		org.disorientation = math.max(org.disorientation, 0.5 + disorientK * 1.0)
	end

	-- Stamina loss: starts at BP 80, small/slow, builds to 2/3 at BP 50
	if org.bloodpressure < 80 then
		local staminaK = math.Clamp((80 - org.bloodpressure) / 30, 0, 1)
		local staminaLoss = staminaK * staminaK * (org.stamina.max * 2 / 3) / 60 -- scales quadratically, reaches 2/3 over ~60 seconds at BP 50
		org.stamina[1] = math.max(org.stamina[1] - timeValue * staminaLoss, 0)
	end

	-- Shock: only starts at BP 45, slower buildup
	if org.bloodpressure < 45 then
		local shockK = math.Clamp((45 - org.bloodpressure) / 30, 0, 1)
		org.shock = math.Approach(org.shock, 20 + shockK * 45, timeValue * (0.5 + shockK * 1.5))
	end

	if org.bloodpressure < 55 then
		local lowK = math.Clamp((65 - org.bloodpressure) / 35, 0, 1)
		org.consciousness = math.Approach(org.consciousness, 0.75, timeValue * (0.08 + lowK * 0.11))
	end

	-- Low pulse affects consciousness (below 40 BPM)
	if org.pulse < 40 then
		local pulseK = math.Clamp((40 - org.pulse) / 40, 0, 1)
		org.consciousness = math.max(org.consciousness - timeValue * pulseK * 0.15, 0)
	end

	if org.bloodpressure > 115 then
		local highK = math.Clamp((org.bloodpressure - 115) / 55, 0, 1)
		local adrenalineMitigation = math.Clamp(org.adrenaline / 3, 0, 1) * 0.5
		local effectiveHighK = highK * (1 - adrenalineMitigation)
		org.disorientation = math.max(org.disorientation, effectiveHighK * 1)
		org.painadd = math.min(org.painadd + timeValue * (0.6 + effectiveHighK * 1.8), 150)
		org.shock = math.Approach(org.shock, math.max(org.shock, 10 + effectiveHighK * 20), timeValue * (0.4 + effectiveHighK * 1.4))
	end

	if org.heartstop then
		org.heartbeat = 0
	end

	org.fear = math.Approach(org.fear, (org.otrub and 0 or (org.fearadd > 0 and 1 or -1)), org.otrub and timeValue * 0.5 or (org.fearadd > 0 and (org.fear < 0 and timeValue * 5 * org.fearadd or timeValue / 5 * org.fearadd) or (org.fear <= 0 and timeValue / 240 or timeValue / 50)))
	-- less time to start fearing, more time to become calm again
	-- if no fear, in 3 minutes become slightly talkative, so would say random phrases to calm themselves in a current situation
	local gainfear = hg.organism.should_gain_fear(org)
	org.fearadd = math.Approach(org.fearadd, 0, gainfear and timeValue or timeValue / 4.9) -- 15 seconds to stop fearing something and start to calm down
	local fearGainRate = gainfear and timeValue / 5 or 0
	if org.givingUp then fearGainRate = fearGainRate * 0.25 end
	org.fearadd = math.Approach(org.fearadd, 1, fearGainRate)
	
	local adrenK = max(1 + org.adrenaline, 1)
	local adren = org.adrenaline

	if org.pulse < 10 or org.brain >= 0.85 or org.bloodpressure < 25 then org.heartstop = true end
	if org.temperature < 28 or org.temperature > 42 then org.heartstop = true end

	if org.temperature < 34 or org.temperature > 38 or org.blood < 4000 or org.pain > 20 then
		org.fear = math.max(org.fear, 0)
	end

	-- temperature
	local needed_temp = math.min(math.max(37 * (org.pulse / 45), 35), 36.7)
	local changeRate = timeValue / 60
	changeRate = changeRate * (org.temperature < needed_temp and math.Clamp(org.heatbuff / 60, 1, 2) or 1)
	if math.abs(org.tempchanging) < changeRate then
		org.temperature = math.Approach(org.temperature, needed_temp, changeRate)
	else
		org.needed_temp = needed_temp
	end
	
	if not org.heartstop then
		org.last_heartbeat = CurTime()
	end

	if org.heartstop and adren > 0 and (org.adrenaline_try or 0) < CurTime() then
		-- Scale chance with adrenaline level: significantly improved effectiveness
		-- Low dose (1): ~70% chance, Medium dose (2): ~90% chance, High dose (4+): near-certain
		local chance = math.Clamp(adren * 50 + adren * adren * 10, 0, 99)
		local rand = math.random(100)

		-- High adrenaline retries faster (0.02s at adren>=3, 0.04s otherwise)
		org.adrenaline_try = CurTime() + (adren >= 3 and 0.02 or 0.04)

		if chance > rand then
			org.heartstop = false
			-- Reset heartbeat to a safe range when restarting to prevent immediate fibrillation
			org.heartbeat = math.Clamp(org.heartbeat, 80, 140)
			-- Also attempt to restore O2 to a minimum survivable level so breathing can resume
			if org.o2 then
				local o2Restore = math.Clamp(adren * 2, 2, 8)
				org.o2[1] = math.max(org.o2[1], o2Restore)
			end
		end
	end

	if org.heartstop then
		org.heartstoptime = org.heartstoptime or CurTime()
		if org.isPly then
	        org.owner:Notify("I'm feeling dizzy...", true, "heartstop", 10)
		end
	else
		if org.isPly then
			org.owner:ResetNotification("heartstop")
		end
		org.heartstoptime = nil
	end

	if org.alive and org.heartstoptime and org.heartstoptime + 30 < CurTime() and (org.lastsoundtime or 0) < CurTime() and org.otrub then
		org.owner:EmitSound("breathing/agonalbreathing_"..math.random(13)..".wav", 60)
		--org.owner:EmitSound("breathing/agonalbreathing_"..math.random(13)..".wav", 50)
		
		org.lastsoundtime = CurTime() + math.random(25,35)
	end

	if org.fear > 1.5 then
        if not org._fear_check_time or CurTime() > org._fear_check_time then
            org._fear_check_time = CurTime() + 1 -- check every second

            local chance = (org.fear - 1.5) / 0.5 * 0.025 -- at 2.0 fear, 2.5% chance
            local totalAdrenaline = (org.adrenaline or 0) + (org.adrenalineAdd or 0)
            if totalAdrenaline > 1.0 then
                chance = chance * math.max(0, 1 - (totalAdrenaline - 1.0) * 0.35)
            end
            if math.random() < chance then
                org.heartstop = true
                org.lungsfunction = false
            end
        end
    end

	-- Small heartstop chance from despair alone (not panic-only)
	if (org.despair or 0) > 0.4 and not org.panicAttack then
		if not org._despair_pulse_check or CurTime() > org._despair_pulse_check then
			org._despair_pulse_check = CurTime() + 5 -- check every 5 seconds
			local despairChance = math.Clamp((org.despair - 0.4) / 0.6, 0, 1) * 0.008 -- up to 0.8% per 5s at max despair
			if org.givingUp then despairChance = despairChance * 1.5 end
			local totalAdrenaline = (org.adrenaline or 0) + (org.adrenalineAdd or 0)
			if totalAdrenaline > 1.0 then
				despairChance = despairChance * math.max(0, 1 - (totalAdrenaline - 1.0) * 0.4)
			end
			if math.random() < despairChance then
				org.heartstop = true
			end
		end
	end
end

--if org.heartstop then org.needotrub = true end --не совсем...
util.AddNetworkString("pulse")
function hg.organism.Pulse(owner, org, timeValue)
	local stamina = org.stamina
	if org.o2[1] > 1 and org.alive and org.heart < 1 and org.brain < 0.6 then
		--org.brain = max(org.brain - timeValue / 30, 0) --regen
	end--brain damage is usually permanent

	if owner:IsPlayer() and owner:Alive() then
		net.Start("pulse")
		net.Send(owner)
	end
end