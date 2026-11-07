local max, min, Clamp, Approach = math.max, math.min, math.Clamp, math.Approach

--local Organism = hg.organism

hg.organism.module.pain = {}

local module = hg.organism.module.pain
local consciousness_otrub_threshold = 0.3
local consciousness_fake_threshold = 0.38
local shock_heavy_offset = 30
local shock_critical_ramp = 40
local consciousness_recovery_speed = 12
local low_consciousness_recovery_speed = 16
local otrub_consciousness_recovery_speed = 20
local otrub_rouse_consciousness_recovery_speed = 3.5
local shock_consciousness_threshold = 40
local shock_adrenaline_offset = 10
local shock_blackout_rate = 0.28
local shock_heavy_blackout_rate = 0.8
local shock_fight_threshold_mul = 1.35
local shock_consciousness_analgesia_range = 30
local pain_tolerance = 120
local otrub_pain_tolerance = 90
local pain_fake_threshold = 0.9
local pain_drain_base = 8
local pain_drain_otrub_mul = 4.5
local pain_shock_gain = 0.4
local pain_syncope_start = 65
local pain_syncope_full = 120
local pain_syncope_max_rate = 0.03
local pain_syncope_fight_resistance = 0.5
local otrub_wake_threshold_delay = 5
local otrub_wake_threshold_ramp_time = 50
local otrub_wake_shock_max = 50
local otrub_wake_pain_max = 75
local pain_linger_time = 6
local pain_settle_time = 14
local pain_linger_mul = 0.3
local pain_settle_mul = 2.6

function hg.organism.GetAdrenalinePainPacing(adrenaline)
	adrenaline = max(adrenaline or 0, 0)
	if adrenaline <= 0.5 then return 1 end
	return max(1 - adrenaline, 0.05) / 1.5
end

function hg.organism.CanFeelPain(org, region)
	if not org or org.otrub then return false end

	local spine1Broken = (org.spine1 or 0) >= (hg.organism.fake_spine1 or 1)
	local spine2Broken = (org.spine2 or 0) >= (hg.organism.fake_spine2 or 1)
	local spine3Broken = (org.spine3 or 0) >= 1

	if spine3Broken then return region == "spine3acute" and (org.spine3AcutePainUntil or 0) > CurTime() end
	if spine2Broken then return region == "head" end
	if spine1Broken and region == "lower" then return false end
	return true
end

function hg.organism.AddPain(org, amount, region)
	amount = math.max(tonumber(amount) or 0, 0)
	local owner = org and org.owner
	if IsValid(owner) and owner.GetTraitMultiplier then amount = amount * owner:GetTraitMultiplier("pain_received", 1) end
	if amount <= 0 or not hg.organism.CanFeelPain(org, region) then return 0 end

	local key = region == "head" and "headpainadd" or "painadd"
	local painCap = IsValid(owner) and owner.HasTrait and owner:HasTrait("gurajchaka_child") and 50 or 150
	org[key] = math.min((org[key] or 0) + amount, painCap)
	return amount
end

function hg.organism.AddInstantPain(org, amount, region)
	amount = math.max(tonumber(amount) or 0, 0)
	local owner = org and org.owner
	if IsValid(owner) and owner.GetTraitMultiplier then amount = amount * owner:GetTraitMultiplier("pain_received", 1) end
	if amount <= 0 or not hg.organism.CanFeelPain(org, region) then return 0 end

	local painCap = IsValid(owner) and owner.HasTrait and owner:HasTrait("gurajchaka_child") and 50 or 150
	if (org.adrenaline or 0) > 0.5 then
		local key = region == "head" and "headpainadd" or "painadd"
		org[key] = math.min((org[key] or 0) + amount, painCap)
		return amount
	end
	org.avgpain = math.min((org.avgpain or 0) + amount, painCap)
	return amount
end

module[1] = function(org)

	org.shock = 0

	org.pain = 0

	org.avgpain = 0

	org.painadd = 0
	org.headpainadd = 0
	org.nearpainlimit = false
	org.hurt = 0

	org.hurtadd = 0

	org.painkiller = 0

	org.analgesia = 0

	org.analgesiaAdd = 0

	org.naloxone = 0

	org.naloxoneadd = 0

	org.immobilization = 0

	org.painlessen = 0
	org.adrenalinePainStart = nil
	org.adrenalinePainBreakthrough = nil

	org.tranquilizer = 0
	org.zerlkers = 0
	org.zerlkersOverdose = 0

	org.shock_turn = 0
	org.shockBlackout = nil



	org.stun = 0

	org.lightstun = 0
	org.otrub_rouseUntil = 0
	org.otrub_rouseSource = nil

end

module[2] = function(owner, org, timeValue)

	local adrenalineMul = min(max(1 + org.adrenaline, 1), 1.2)

	local adrenaline = org.adrenaline
	local zerlkersDose = math.Clamp(tonumber(org.zerlkers) or 0, 0, 4)
	if zerlkersDose > 0 then
		zerlkersDose = math.max(zerlkersDose - timeValue / 120, 0)
	end
	org.zerlkers = zerlkersDose
	org.zerlkersOverdose = math.Clamp(zerlkersDose - 1, 0, 1)
	local resilience = hg.organism.GetResilience and hg.organism.GetResilience(org) or 0
	if IsValid(owner) and owner.GetTraitMultiplier then
		org.painToleranceMul = owner:GetTraitMultiplier("pain_tolerance", 1)
		org.traumaResistanceMul = owner:GetTraitMultiplier("trauma_resistance", 1)
	end
	local zerlkers = math.Clamp(zerlkersDose, 0, 1)
	local zerlkersResistance = hg.organism.GetZerlkersResistance and hg.organism.GetZerlkersResistance(org) or zerlkers

	local analgesiaMul = ((org.analgesia + org.painkiller * 0.3) * 4 + 1)

	local painkillerMul = 1

	org.shock_turn = 10 * (!org.otrub and 1 or 0.1)



	if org.shock > org.shock_turn * 1.5 * analgesiaMul * painkillerMul then

		--org.needfake = true

	end



	-- A Zerlkers dose is deliberately stronger than a natural adrenaline rush:
	-- it delays new pain, rapidly settles existing pain, and raises the point at
	-- which pain can force a ragdoll. It does not alter injury or vital damage.
	local painToleranceMul = (1 + resilience * 0.2 + zerlkers * 1.3) * math.max(org.painToleranceMul or 1, 1)
	org.pain_turn = (org.otrub and adrenalineMul * otrub_pain_tolerance or adrenalineMul * pain_tolerance) * painToleranceMul

	local owner = org.owner

	

	local shockDecayMul = 1.5 + math.Clamp((org.shock - 25) / 15, 0, 1) * 1.5 + math.Clamp((org.shock - 40) / 30, 0, 1) ^ 2 * 5
	if !org.lasthit or org.lasthit + 1.5 < CurTime() then org.shock = max(org.shock - timeValue * 4 * shockDecayMul * (org.otrub and 1 or 0.5) * (1 + resilience * 0.75 + zerlkersResistance * 2.25 + math.Clamp(adrenaline, 0, 5) * 0.6), 0) end
	if adrenaline > 0 then org.shock = max(org.shock - timeValue * math.Clamp(adrenaline, 0, 5) * 0.9, 0) end
	org.immobilization = math.Clamp(max((tonumber(org.immobilization) or 0) - timeValue * 5 * adrenalineMul, 0), 0, 100)

	local spine2Broken = (org.spine2 or 0) >= (hg.organism.fake_spine2 or 1)
	local spine3Broken = (org.spine3 or 0) >= 1
	local queuedPain = math.min(timeValue * 15, org.painadd or 0)
	local queuedHeadPain = math.min(timeValue * 15, org.headpainadd or 0)
	local add = org.otrub and 0 or (spine3Broken and 0 or (spine2Broken and queuedHeadPain or queuedPain + queuedHeadPain))
	local quiet = add <= 0.2
	org.painQuiet = quiet and math.min((org.painQuiet or 0) + timeValue, 60) or 0
	local severity = 1 + Clamp(org.avgpain / 100, 0, 1.5)
	local persistMul
	if org.otrub then
		persistMul = 1
	elseif adrenaline > 0.5 then
		persistMul = 0.12 / (severity * (1 + Clamp(adrenaline, 0, 5) * 0.5))
	else
		local settle = math.Clamp((org.painQuiet - pain_linger_time) / pain_settle_time, 0, 1)
		persistMul = Lerp(settle, pain_linger_mul, pain_settle_mul) / severity
	end
	local sub = quiet and (timeValue * pain_drain_base * persistMul * (org.otrub and pain_drain_otrub_mul or 1) + timeValue * ((org.painkiller * 0.3 + org.analgesia) * 4)) or (0)

	local adrenalinePainPacing = hg.organism.GetAdrenalinePainPacing(adrenaline)
	if adrenaline > 0.5 and add > 0 then
		org.adrenalinePainStart = org.adrenalinePainStart or CurTime()
		local elapsed = CurTime() - org.adrenalinePainStart
		if not org.adrenalinePainBreakthrough and elapsed > 30 + adrenaline * 4
			and math.random() < math.min(timeValue * 0.12 / (1 + adrenaline), 1) then
			org.adrenalinePainBreakthrough = true
		end
	else
		org.adrenalinePainStart = nil
		org.adrenalinePainBreakthrough = nil
	end
	if org.adrenalinePainBreakthrough then adrenalinePainPacing = math.max(adrenalinePainPacing, 0.5) end
	add = add * Lerp(zerlkers, adrenalinePainPacing, 0.025)
	sub = sub * (1 + resilience * 0.35 + zerlkersResistance * 1.5)



	if org.pain > 60 and not org.otrub then

		-- Severe pain compounds: it is harder to settle and more readily aggravated.
		add = add * 1.5

		if org.pain > 70 and add > 0.01 then

			sub = sub / 20

		else

			sub = sub / 5

		end



		org.disorientation = math.max(org.pain / 50, org.disorientation)//org.disorientation + add

		org.shock = min(org.shock + timeValue * (org.pain - 60) * pain_shock_gain / (1 + max(adrenaline, 0) * 0.45), 95)

		org.fearadd = 1

	end



	org.disorientation = math.min(org.disorientation, 10)



	local shockAnalgesia = Clamp(org.analgesia + org.painkiller * 0.3, 0, 1)
	local fightingBack = org.panicattackActive and org.panicMode == "fight"
	local shockThreshold = (shock_consciousness_threshold + shock_adrenaline_offset * Clamp(adrenaline, 0, 1) + shock_consciousness_analgesia_range * shockAnalgesia) *(1 + resilience * 0.6 + zerlkersResistance * 1.4) * math.max(org.traumaResistanceMul or 1, 1) * (fightingBack and shock_fight_threshold_mul or 1)
	local shockHeavy = shockThreshold + shock_heavy_offset
	local o2Value = org.o2 and tonumber(org.o2[1]) or 30
	local hypoxicDrain = o2Value < 4 and 0.1 or o2Value < 8 and 0.03 or o2Value < 10 and 0.01 or 0
	if not org.otrub then
		local hypoxicShockTarget = o2Value < 4 and 80 or o2Value < 8 and 30 or 0
		if org.shock < hypoxicShockTarget then
			org.shock = math.Approach(org.shock, hypoxicShockTarget, timeValue * (o2Value < 4 and 12 or 5))
		end
	end
	if org.otrub then
		org.shockBlackout = nil
	elseif org.shock > shockThreshold then
		org.shockBlackout = math.max(org.shockBlackout or 0, org.shock >= shockHeavy and 2 or 1)
	end
	local shockActive = org.shockBlackout ~= nil
	if shockActive then
		local heavy = org.shockBlackout >= 2
		if heavy then
			local climb = Clamp((org.shock - shockHeavy) / shock_critical_ramp, 0, 1)
			org.disorientation = math.max(org.disorientation or 0, 1.5 + climb * 2)
		end
		org.consciousness = Approach(org.consciousness, 0, timeValue * (heavy and shock_heavy_blackout_rate or shock_blackout_rate))
	end
	if org.tranquilizer > 0 then

		org.tranquilizer = math.Approach(org.tranquilizer, 0, org.tranquilizer > 1 and timeValue / 5 or timeValue / 30)
		--org.shock = math.Approach(org.shock, 50, timeValue * org.tranquilizer * 5)
		--org.shock = math.Approach(org.shock, 50, timeValue * org.tranquilizer * 5)

		org.consciousness = math.Approach(org.consciousness, 0, timeValue / 30 * org.tranquilizer)
	elseif not shockActive and hypoxicDrain <= 0 then
		-- Blood pressure applies its own continuous consciousness ceiling in the
		-- circulation modules. Recovery itself must not contain a second hidden
		-- low-volume path to OTRUB.
		local target = 1
		local recovery_speed = consciousness_recovery_speed
		if (org.otrub_rouseUntil or 0) > CurTime() then
			target = 1
			recovery_speed = otrub_rouse_consciousness_recovery_speed
		elseif org.otrub or org.consciousness < consciousness_otrub_threshold then
			recovery_speed = otrub_consciousness_recovery_speed
		elseif org.consciousness < consciousness_fake_threshold then
			recovery_speed = low_consciousness_recovery_speed
		end
		org.consciousness = Approach(org.consciousness, target, timeValue / recovery_speed)
	end
	if hypoxicDrain > 0 then
		org.consciousness = math.max((org.consciousness or 1) - hypoxicDrain * timeValue, 0)
	end



	-- Brain trauma and intracranial bleeding share the normal unconsciousness
	-- pipeline, so a hemorrhage cannot be hidden by the regular recovery step.
	local structuralBrainDamage = math.max(
		org.brain or 0,
		(org.brainFrontal or 0) * 0.75,
		(org.brainParietal or 0) * 0.65,
		(org.brainTemporal or 0) * 0.65,
		(org.brainOccipital or 0) * 0.7,
		(org.brainHemorrhage or 0) * 0.8
	)
	if hg.organism.IsBrainDamageIgnored and hg.organism.IsBrainDamageIgnored(org) then structuralBrainDamage = 0 end
	local brainSeverity = math.Clamp((structuralBrainDamage - 0.1) / 0.9, 0, 1)
	local severeBrainSeverity = math.Clamp((structuralBrainDamage - 0.325) / 0.675, 0, 1)
	local hemorrhageSeverity = math.Clamp(((org.brainHemorrhage or 0) - 0.05) / 0.95, 0, 1)
	if brainSeverity > 0 or hemorrhageSeverity > 0 then
		if brainSeverity > 0 then
			org.consciousness = math.min(org.consciousness or 1, 0.94 - brainSeverity * 0.6)
		end
		local consciousnessDrain = brainSeverity > 0 and (0.025 + brainSeverity * 0.04) or 0
		if severeBrainSeverity > 0 then
			consciousnessDrain = consciousnessDrain + 0.17 + severeBrainSeverity * 0.06
		end
		consciousnessDrain = consciousnessDrain + hemorrhageSeverity * (0.02 + hemorrhageSeverity * 0.12)
		org.consciousness = math.max((org.consciousness or 1) - consciousnessDrain * timeValue, 0)
	end


	local consciousnessResistance = 1 - resilience * 0.3
	local unconsciousTime = max((org.uncon_timer or 0) - otrub_wake_threshold_delay, 0)
	local wakeThresholdProgress = Clamp(unconsciousTime / otrub_wake_threshold_ramp_time, 0, 1)
	local wakeShockThreshold = otrub_wake_shock_max * wakeThresholdProgress
	local wakePainThreshold = otrub_wake_pain_max * wakeThresholdProgress
	local recoveryBlocked = org.otrub and (org.shock > wakeShockThreshold or org.pain > wakePainThreshold)
	local persistentConsciousnessCause = org.tranquilizer > 0 or brainSeverity > 0 or hemorrhageSeverity > 0
	local consciousnessTooLow = org.consciousness < consciousness_otrub_threshold * consciousnessResistance
	if recoveryBlocked or (consciousnessTooLow and (not org.otrub or persistentConsciousnessCause)) then
		org.needotrub = true

	end



	if org.consciousness < consciousness_fake_threshold * consciousnessResistance then
		org.needfake = true

	end



	org.avgpain = min(org.avgpain + add, 150)

	if !org.lasthit or org.lasthit + 1 < CurTime() then org.avgpain = max(org.avgpain - sub, 0) end

	org.painlessen = sub



	org.pain = org.avgpain * math.max(1 - (org.analgesia + org.painkiller * 0.3), 0) / math.max(org.painResistanceMul or 1, 1) * math.max(1 - math.Clamp(adrenaline, 0, 5) * 0.14, 0.3)
	if zerlkersDose > 0 or (adrenaline >= 3 and not org.adrenalinePainBreakthrough) then
		org.pain = math.min(org.pain, 69.99)
	end
	-- Pain can now produce a vasovagal blackout before the slower shock drain has
	-- finished lowering consciousness. The smooth severity curve keeps moderate
	-- pain occasional and makes sustained extreme pain progressively less stable.
	local syncopeSeverity = Clamp((org.pain - pain_syncope_start) / (pain_syncope_full - pain_syncope_start), 0, 1)
	local syncopeResistance = Clamp(resilience * 0.35 + zerlkersResistance * 0.8 + (math.max(org.traumaResistanceMul or 1, 1) - 1) * 0.2 + (fightingBack and pain_syncope_fight_resistance or 0), 0, 0.9)
	local syncopeRate = syncopeSeverity ^ 1.7 * pain_syncope_max_rate * (1 - syncopeResistance)
	if not org.otrub and syncopeRate > 0 and math.random() < Clamp(syncopeRate * timeValue, 0, 1) then
		org.consciousness = math.min(org.consciousness or 1, consciousness_otrub_threshold * consciousnessResistance * 0.8)
	end
	org.nearpainlimit = not org.otrub and org.pain >= org.pain_turn * pain_fake_threshold
	if org.isPly and org.pain >= 85 and not org.otrub and IsValid(owner) and owner.Notify and owner:GetInfoNum("hg_newthoughts", 0) <= 0 then
		local sharpPain = hg.sharp_pain
		owner:Notify(sharpPain and sharpPain[math.random(#sharpPain)] or "AAAAAAAAAAAAAGHH!", 8, "pain_scream", 0, nil, Color(255, 80, 80))
	end

	local headApplied = spine2Broken and add or math.min(queuedHeadPain, add)
	local bodyApplied = add - headApplied
	org.headpainadd = min(max((org.headpainadd or 0) - headApplied * analgesiaMul, 0), 150)
	org.painadd = min(max((org.painadd or 0) - bodyApplied * analgesiaMul, 0), 150)

	if spine3Broken then
		org.painadd = 0
		org.headpainadd = 0
		org.avgpain = 0
		if (org.spine3AcutePainUntil or 0) > CurTime() then
			org.pain = math.max(org.spine3AcutePain or 95, 0)
		else
			org.pain = 0
		end
	elseif spine2Broken then
		org.painadd = 0
	end

	if org.otrub then
		local queueDrain = timeValue * pain_drain_base * pain_drain_otrub_mul * analgesiaMul
		org.painadd = max((org.painadd or 0) - queueDrain, 0)
		org.headpainadd = max((org.headpainadd or 0) - queueDrain, 0)
	end

	//org.painkiller = Approach(org.painkiller, 0, timeValue / 240 * (org.naloxone * 25 + 1))

	if org.nearpainlimit and not hg.organism.IsHitKnockdownImmune(org) then
		org.needfake = true
	end
	
	org.analgesia =  Approach(org.analgesia, 0, timeValue / 240 * (org.naloxone * 25 + 1))

	if org.analgesiaAdd > 0 then

		org.analgesia =  Approach(org.analgesia, 5, timeValue / 15)

		org.analgesiaAdd = Approach(org.analgesiaAdd, 0, timeValue / 15)

	end



	org.naloxone = Approach(org.naloxone, org.naloxoneadd > 0 and 4 or 0, org.naloxoneadd > 0 and timeValue / 30 or timeValue / 60)

	org.naloxoneadd = Approach(org.naloxoneadd, 0, timeValue / 15)

	

	--if owner.suiciding and org.adrenaline < 1.5 then

	--	org.adrenalineAdd = Approach(org.adrenalineAdd, 4, timeValue / 5)

	--end



	local betaBlocked = CurTime() < (org.betaBlockerUntil or 0)
	if betaBlocked then
		org.adrenalineAdd = min(org.adrenalineAdd, 0)
		org._adrenalineHoldUntil = 0
		org.adrenaline = Approach(org.adrenaline, 0, timeValue * (0.15 + org.adrenaline * 0.25))
	end

	if org.adrenalineAdd > 0 then

		local critical = (org.hemorrhagicCollapseExposure or 0) > 0.8 or (org.brain and org.brain > 1.5)
		local reserveK = math.Clamp(((org.adrenalineStorage or 0) / 5) * 0.75 + 0.25, 0.25, 1)

		if critical then
			org.adrenaline = Approach(org.adrenaline, 2, timeValue / 5 * reserveK)
		else
			org.adrenaline = Approach(org.adrenaline, 4, timeValue / 5 * reserveK)
		end

	end



	org.adrenalineAdd = Approach(org.adrenalineAdd, 0, org.adrenalineAdd < 0 and timeValue / 30 or timeValue / 5)



	-- Faster adrenaline decay when coming off berserk or noradrenaline

	local fastAdrenalineDecay = false

	if org._berserkEndTime and CurTime() < org._berserkEndTime then

		fastAdrenalineDecay = true

	elseif org._noradrenalineEndTime and CurTime() < org._noradrenalineEndTime then

		fastAdrenalineDecay = true

	end



	local adrenalineDecayRate = timeValue / 25

	if fastAdrenalineDecay then

		adrenalineDecayRate = timeValue / 8 -- Faster than normal, but still a gradual comedown

	end
	if org.adrenalinePainBreakthrough then
		adrenalineDecayRate = math.max(adrenalineDecayRate, timeValue / 8)
	end
	if CurTime() < (org._adrenalineReliefUntil or 0) then
		adrenalineDecayRate = math.max(adrenalineDecayRate, timeValue / 3)
	end



	if (org.adrenalineAdd > 0 or CurTime() < (org._adrenalineHoldUntil or 0)) and not org.adrenalinePainBreakthrough and org.pain <= 20 then
		adrenalineDecayRate = 0
	end



	org.adrenaline = Approach(org.adrenaline, 0, adrenalineDecayRate)



	local recoveryMul = hg.organism.RecoveryMul(org)

	for _, limb in ipairs({"lleg", "rleg", "rarm", "larm"}) do
		hg.organism.HealLimbSegments(org, limb, timeValue / 240 * recoveryMul * (hg.GetBandageRegenMultiplier and hg.GetBandageRegenMultiplier(org.owner, limb) or 1))
	end

	if org.chest < 1 then

		org.chest = max(org.chest - timeValue / (org.bandagedchest and 420 or 900) * recoveryMul, 0)

	end

	if org.pelvis < 1 then

		org.pelvis = max(org.pelvis - timeValue / 900 * recoveryMul * (hg.GetBandageRegenMultiplier and hg.GetBandageRegenMultiplier(org.owner, "pelvis") or 1), 0)

	end



	if org.pain > 100 then

		org.needfake = true

	end



	//local tempo = math.Clamp(5 - (org.temperature - 31), 0, 15)

	

	//org.shock = math.max(org.shock, tempo * 4)

	

	local disorientationNow = math.max(tonumber(org.disorientation) or 0, 0)
	if disorientationNow > 0.05 then
		org.disorientationExposure = math.min((org.disorientationExposure or 0) + timeValue, 30)
	else
		org.disorientationExposure = math.Approach(org.disorientationExposure or 0, 0, timeValue * 2)
	end
	-- The nervous system settles faster after the acute period instead of leaving a
	-- weak residual wobble for an excessively long time. Ongoing causes can still
	-- re-raise the value in their own modules.
	local recoveryMul = 1 + math.Clamp(((org.disorientationExposure or 0) - 4) / 12, 0, 1) * 3
	org.disorientation = math.Approach(disorientationNow, 0, timeValue / 5 * recoveryMul)



end

function hg.organism.Rouse(org, seconds, source)
	if not org or not org.alive then return end
	org.otrub_rouseUntil = math.max(org.otrub_rouseUntil or 0, CurTime() + (seconds or 20))
	if source then org.otrub_rouseSource = source end
	local owner = org.owner
	if IsValid(owner) and owner:IsPlayer() then
		net.Start("hg_otrub_rouse")
			net.WriteString(source or "")
		net.Send(owner)
		hook.Run("HG_OnOtrubRouse", owner, org, source)
	end
end

util.AddNetworkString("hg_otrub_rouse")
