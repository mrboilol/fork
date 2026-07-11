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
	local hasRealInjury = (org.blood and org.blood < 4000) or (org.bleed and org.bleed > 1) or (org.pain and org.pain > 30 and (org.blood and org.blood < 4500 or org.bleed and org.bleed > 0))
	if not hasRealInjury then return false end
	return true
end

module[2] = function(owner, org, timeValue)
	local heart = 1 - org.heart
	-- Brain damage weakens the heart's neurological drive.
	local brain = math.Clamp(1 - org.brain * 1.5, 0, 1)
	local o2 = org.o2
	local o2 = halfValue2(o2[1], o2.range, o2.k)

	if org.isPly and not org.otrub and (heart == 0) then org.owner:Notify("My torso hurts a lot...",true,"heart",6) end
	if org.isPly and not org.otrub and org.heartstop then org.owner:Notify("",true,"heartstop",6) end

	local stamina = org.stamina
	
	if not org.alive then
		if hg.organism and hg.organism.ZeroVitals then
			hg.organism.ZeroVitals(org)
		else
			org.heartstop = true
			org.heartbeat = 0
			org.pulse = 0
			org.bloodpressure = 0
			org.systolic = 0
			org.diastolic = 0
		end
		return
	end

	if org.heartstop then
		org.heartbeat = 0
		org.pulse = 0
		org.bloodpressure = 0
		org.systolic = 0
		org.diastolic = 0
	end

	local pulse = org.heartstop and 0 or 70-- + 120 * ((stamina.max or 180) - stamina[1]) / (stamina.max or 180) * (org.lungsfunction and 1 or 0)
	--pulse = pulse + math.min(org.adrenaline, 2) * 40 + (!org.otrub and math.max(org.fear * 50, 0) or 0)
	pulse = org.alive and pulse or 0
	pulse = math.Clamp(pulse, 0, 200)
	
	org.pulse = math.Approach(org.pulse, pulse, pulse > org.pulse and timeValue * 2 or timeValue * 2)
	
	local bloodNow = org.blood or 5000
	local hemorrhageCompensation = math.Clamp(org.hemorrhageCompensation or 0, 0, 1)
	local hypovolemicShock = math.Clamp(org.hypovolemicShock or 0, 0, 1)
	-- Old Z-City compensation curve: blood volume directly weakens effective pulse.
	local bloodPerfusionK = math.Clamp((bloodNow - 1000) / 4000, 0, 1)
	local k = heart * o2 * math.Clamp(bloodPerfusionK, 0, 1) * brain * (org.heartstop and 0 or 1)
	pulse = pulse * k
	pulse = pulse * (math.Clamp(math.Remap(org.temperature, 28, 36.7, 0.5, 1), 0.5, 1))

	local bloodCrash = org.blood ~= nil and org.blood < 1500
	local dropRate = (heart == 0 or org.heartstop or bloodCrash) and timeValue * 30 or timeValue * 5
	org.pulse = math.Approach(org.pulse, pulse, dropRate)

	org.fearadd = math.Clamp(org.fearadd, 0, 3)

	-- Convert excess fearadd to despair only when in incredible pain or dying
	if org.fearadd > 1.5 then
		local excessFear = org.fearadd - 1.5
		local pain = org.pain or 0
		local blood = org.blood or 5000
		local o2val = org.o2 and org.o2[1] or 100
		local dyingOrAgony = pain > 70 or blood < 2500 or o2val < 18
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

	-- Old Z-City compensation: when effective pulse pressure falls below 70,
	-- heartbeat races hard to keep perfusion moving.
	local perfusionPulse = org.pulse or 70
	local compensationRate = perfusionPulse < 70 and 70 + (70 - perfusionPulse) * 4 or perfusionPulse
	compensationRate = math.Clamp(compensationRate, 45, 300)
	-- Severe hypovolemia drives the heart from its compensated rate toward
	-- ventricular tachycardia: the ramp begins at 2500 blood and reaches
	-- roughly 300 BPM by 2250 blood.
	local bloodTachyK = math.Clamp((2500 - bloodNow) / 250, 0, 1)
	local bloodTachyRate = Lerp(bloodTachyK, compensationRate, 300)

	local heartbeat = math.max(compensationRate, bloodTachyRate)

	local staminaMax = math.max(org.stamina.max or 180, 1)
	local stamina = math.Clamp(org.stamina[1] or staminaMax, 0, staminaMax)
	-- Exertion only elevates the heart rate once 50 stamina has actually been lost.
	local exertionK = org.analgesia < 1 and math.Clamp((staminaMax - 50 - stamina) / math.max(staminaMax - 50, 1), 0, 1) or 0
	local exertionHeartBoost = exertionK * 32
	
	heartbeat = heartbeat + (owner.suiciding and 50 or 0)
	heartbeat = heartbeat + math.Clamp((org.shock or 0) - 20, 0, 40)
	heartbeat = heartbeat + math.Clamp(org.pain, 40, 80) - 40
	heartbeat = heartbeat + exertionHeartBoost
	local adrenalineHeartBoost = 9 * math.min(math.max((org.adrenaline or 0) - 1.5, 0), 3)
	if org.givingUp then adrenalineHeartBoost = adrenalineHeartBoost * 0.55 end
	heartbeat = heartbeat + adrenalineHeartBoost
	heartbeat = heartbeat - 40 * math.min(org.analgesia / 2.5, 1)
	heartbeat = heartbeat + 100 * math.Clamp(math.Remap(org.temperature, 40, 42, 0, 1), 0, 1)
	heartbeat = heartbeat - 160 * (1 - math.Clamp(math.Remap(org.temperature, 28, 36.7, 0, 1), 0, 1))
	if org.panicattackActive then heartbeat = heartbeat + 20 end -- adrenaline handles most of the boost
	local despairHeartBoost = math.Clamp((org.despair or 0) - 0.3, 0, 0.7) / 0.7 * 35
	if org.panicattackActive then despairHeartBoost = despairHeartBoost * 0.5 end
	heartbeat = heartbeat + despairHeartBoost
	if org.givingUp then heartbeat = heartbeat * 0.8 end

	-- Viability limits the maximum rate the body can sustain, but compensation
	-- should still exist. Do not multiply BPM down into impossible states like
	-- 45 pulse / 15 heartbeat unless the heart has actually stopped.
	local survivalK = math.Clamp(k, 0, 1)
	local maxCompensatedRate = math.Clamp(150 + survivalK * 110 + hemorrhageCompensation * 60 - hypovolemicShock * 12, 110, 270)
	if bloodTachyK > 0 then
		maxCompensatedRate = math.max(maxCompensatedRate, bloodTachyRate)
	end
	if heart < 0.35 or brain < 0.35 then
		maxCompensatedRate = math.min(maxCompensatedRate, 85)
	end
	if org.heartstop then
		maxCompensatedRate = 0
	else
		local minPumpRate = perfusionPulse < 60 and 60 + (60 - perfusionPulse) * 0.4 or 45
		heartbeat = math.max(heartbeat, minPumpRate)
	end

	-- Hard physiological ceiling. Sustained rates above ~250 BPM are ventricular
	-- tachycardia/fibrillation; above ~300 the heart cannot fill and arrests.
	heartbeat = math.Clamp(heartbeat, 0, maxCompensatedRate)

	org.heartbeat = math.Approach(org.heartbeat, heartbeat, heartbeat > org.heartbeat and timeValue * 2.4 or timeValue * 4.5)

	-- Only sustained extreme tachycardia collapses into cardiac arrest. Short
	-- event spikes should look scary without instantly killing a viable player.
	if org.heartbeat > 250 and k < 0.65 then
		org._tachycardiaSince = org._tachycardiaSince or CurTime()
		if org._tachycardiaSince + 4 < CurTime() then
			org.heartstop = true
		end
	else
		org._tachycardiaSince = nil
	end

	-- Probabilistic heartstop based on heart rate (kept as a softer fallback for
	-- the 200-300 range where rhythms become dangerous but not yet lethal).
	if not org._heart_rate_check_time or CurTime() > org._heart_rate_check_time then
		org._heart_rate_check_time = CurTime() + 1 -- check every second

		local hb = org.heartbeat
		local chance = 0
		local sustainedTachy = org._tachycardiaSince and org._tachycardiaSince + 3 < CurTime()
		if sustainedTachy and hb >= 250 and k < 0.8 then
			chance = 0.06
		elseif sustainedTachy and hb >= 230 and k < 0.55 then
			chance = 0.025
		end

		if org.panicattackActive then chance = chance * 0.5 end
		if org.givingUp then chance = chance * 1.5 end

		if chance > 0 and math.random() < chance then
			org.heartstop = true
		end
	end

	if not org.heartstop then
		-- A faster heartbeat can partially restore effective pulse pressure, but
		-- very high rates lose filling efficiency and stop helping.
		local pumpRateK = math.Clamp((org.heartbeat or 70) / 70, 0.25, 2.4)
		local fillingK = 1 - math.Clamp(((org.heartbeat or 70) - 185) / 85, 0, 0.55)
		local pumpSupport = math.Clamp(pumpRateK * fillingK, 0.25, 1.45)
		local supportedPulse = math.Clamp(pulse * pumpSupport, 0, 200)
		if supportedPulse > org.pulse then
			org.pulse = math.Approach(org.pulse, supportedPulse, timeValue * 8)
		end
	end
	
	local blood = math.Clamp(org.blood or 5000, 0, 5000)
	local bloodK = math.Clamp((blood - 2000) / 2000, 0, 1)
	local o2K = math.Clamp(o2, 0, 1)
	local heartK = math.Clamp(1 - org.heart, 0, 1)
	local brainK = math.Clamp(1 - org.brain * 1.25, 0, 1)
	local hypothermiaK = math.Clamp(math.Remap(org.temperature, 28, 36.7, 0.45, 1), 0.45, 1)
	local adrenalineHyperMul = math.Clamp(org.adrenaline, 0, 5) * 0.025
	if org.givingUp then adrenalineHyperMul = adrenalineHyperMul * 0.55 end
	local hypertensionMul = 1 + adrenalineHyperMul + math.Clamp(org.pain, 0, 120) / 120 * 0.06 + math.Clamp(org.shock, 0, 80) / 80 * 0.08
	hypertensionMul = hypertensionMul * (1 - math.Clamp(org.analgesia / 4, 0, 1) * 0.08)
	hypertensionMul = math.Clamp(hypertensionMul, 0.72, 1.45)

	local compensation = 1 + hemorrhageCompensation * 0.45
	compensation = compensation * (1 - hypovolemicShock * 0.2)
	compensation = math.Clamp(compensation, 0.45, 1.4)

	local pumpRateK = math.Clamp((org.heartbeat or 70) / 70, 0.25, 2.4)
	local fillingK = 1 - math.Clamp(((org.heartbeat or 70) - 185) / 85, 0, 0.55)
	local pulse_factor = (org.pulse / 70) * math.Clamp(pumpRateK * fillingK, 0.45, 1.12)
	local volumeMapK = blood >= 3600 and 1 or math.Remap(math.Clamp(blood, 900, 3600), 900, 3600, 0.12, 1)
	local map = 93 * pulse_factor * hypertensionMul * compensation * volumeMapK
	map = org.alive and map or 0

	if org.heartstop then
		map = 0
	end

	-- High velocity reduces blood pressure (falling or rapid acceleration only)
	-- Skip for ragdolled players: ragdoll physics jitter causes false velocity spikes
	local velocityPenalty = 0
	local isRagdolled = owner:IsPlayer() and (IsValid(owner.FakeRagdoll) or IsValid(owner:GetNWEntity("FakeRagdoll", NULL)) or org.needfake or org.otrub)
	if not isRagdolled then
		local velocity = owner:GetVelocity()
		local speed = velocity:Length()
		local fallSpeed = math.max(0, -velocity.z)

		-- Falling causes G-force blood pressure loss
		if fallSpeed > 100 then
			velocityPenalty = math.Clamp((fallSpeed - 100) / 400, 0, 0.9)
		end

		-- Rapid deceleration (e.g., vehicle crashes, slamming into walls) causes G-force loss
		local prevSpeed = org._pulsePrevSpeed or speed
		local decel = math.max(0, prevSpeed - speed) / math.max(timeValue, 0.001)
		if decel > 800 and velocity.z <= 0 then
			velocityPenalty = math.min(velocityPenalty + math.Clamp((decel - 800) / 800, 0, 0.2), 0.95)
		end
		org._pulsePrevSpeed = speed
	else
		org._pulsePrevSpeed = nil
	end

	if velocityPenalty > 0 then
		map = map * (1 - velocityPenalty)
	end

	if org.givingUp then map = map * 0.75 end

	map = math.Clamp(map, 0, 190)
	local bpTarget = map
	local bpCurrent = org.bloodpressure or 93
	local bpRate = (bpTarget > bpCurrent) and 14 or 10
	if velocityPenalty > 0 then
		bpRate = bpRate * (1 + velocityPenalty * 4)
	end
	org.bloodpressure = math.Approach(bpCurrent, bpTarget, timeValue * bpRate)

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
	local adrenalineStabilizer = totalAdrenaline > 0.8
	
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
		local decayRate = (adrenalineStabilizer or hasAntiIschemia) and timeValue / 4 or timeValue / 10
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
		local adrenalineMitigation = math.Clamp(org.adrenaline / 3, 0, 1) * 0.25
		local effectiveHighK = highK * (1 - adrenalineMitigation)
		org.disorientation = math.max(org.disorientation, 0.25 + effectiveHighK * 1.5)
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

	if org.pulse < 10 or org.brain >= 0.85 or org.bloodpressure < 25 or (org.heart >= 0.8 and org.blood < 1500) then org.heartstop = true end
	if org.temperature < 28 or org.temperature > 42 then org.heartstop = true end

	-- Exsanguination: with under ~800 mL of blood there is not enough volume
	-- left to circulate; the heart goes into pulseless electrical activity.
	-- This is independent of heart organ damage (you can bleed out with a
	-- perfectly healthy heart).
	if (org.blood or 5000) < 800 then org.heartstop = true end

	-- Severe hypovolemia (1500 mL or under) should not instantly flatline just
	-- because MAP is low; sv_blood.lua owns the short delayed collapse window.
	-- Only hard pump failure ends circulation immediately here.
	if (org.blood or 5000) < 1500 then
		local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
		local hasStabilizer = totalAdrenaline > 0.5 or (org.tranexamic_acid or 0) > 0
		if not hasStabilizer and (org.heart >= 0.5 or (org.bloodpressure or 93) < 25 or (org.pulse or 70) < 15) then
			org.heartstop = true
		end
	end

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
		local canRestartHeart = org.alive and (org.blood or 5000) >= 800 and (org.heart or 0) < 1 and (org.brain or 0) < 0.85 and (org.temperature or 36.7) >= 28 and (org.temperature or 36.7) <= 42
		-- Scale chance with adrenaline level: significantly improved effectiveness
		-- Low dose (1): ~70% chance, Medium dose (2): ~90% chance, High dose (4+): near-certain
		local chance = math.Clamp(adren * 60 + adren * adren * 12, 0, 99)
		chance = chance * math.Clamp(1 - (org.heart or 0) * 0.65, 0.2, 1)
		if (org.o2 and (org.o2[1] or 0) < 5) or (org.bloodpressure or 0) < 15 then
			chance = chance * 0.6
		end
		local rand = math.random(100)

		-- High adrenaline retries faster (0.02s at adren>=3, 0.04s otherwise)
		org.adrenaline_try = CurTime() + (adren >= 3 and 0.02 or 0.04)

		if canRestartHeart and chance > rand then
			org.heartstop = false
			-- Reset heartbeat to a safe range when restarting to prevent immediate fibrillation
			org.heartbeat = math.Clamp(org.heartbeat > 0 and org.heartbeat or 90, 80, 140)
			org.pulse = math.max(org.pulse or 0, 35)
			org.bloodpressure = math.max(org.bloodpressure or 0, 45)
			-- Also attempt to restore O2 to a minimum survivable level so breathing can resume
			if org.o2 then
				local o2Restore = math.Clamp(adren * 2.5, 3, 12)
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

	local circulatoryRisk = (org.bloodpressure or 93) < 55 or (org.pulse or 70) < 35 or (org.blood or 5000) < 2200 or (org.o2 and (org.o2[1] or 30) < 8)

	if org.fear > 1.5 and circulatoryRisk then
        if not org._fear_check_time or CurTime() > org._fear_check_time then
            org._fear_check_time = CurTime() + 1 -- check every second

            local riskMul = math.Clamp((55 - (org.bloodpressure or 93)) / 35, 0.25, 1)
            local chance = (org.fear - 1.5) / 0.5 * 0.012 * riskMul
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
	if (org.despair or 0) > 0.65 and not org.panicattackActive and circulatoryRisk then
		if not org._despair_pulse_check or CurTime() > org._despair_pulse_check then
			org._despair_pulse_check = CurTime() + 5 -- check every 5 seconds
			local riskMul = math.Clamp((55 - (org.bloodpressure or 93)) / 35, 0.25, 1)
			local despairChance = math.Clamp((org.despair - 0.65) / 0.35, 0, 1) * 0.0025 * riskMul
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
