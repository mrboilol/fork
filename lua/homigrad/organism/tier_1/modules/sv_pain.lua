local max, min, Clamp, Approach = math.max, math.min, math.Clamp, math.Approach

--local Organism = hg.organism

hg.organism.module.pain = {}

local module = hg.organism.module.pain
local consciousness_otrub_threshold = 0.3
local consciousness_fake_threshold = 0.38
local shock_consciousness_soft_target = 0.5
local shock_consciousness_hard_target = 0
local shock_consciousness_drain_start = 10
local shock_consciousness_drain_end = 4
local consciousness_recovery_speed = 12
local low_consciousness_recovery_speed = 16
local otrub_consciousness_recovery_speed = 20
local shock_consciousness_threshold = 25
local shock_consciousness_max = 85
local pain_shock_threshold = 80
local pain_shock_target = 55
local pain_shock_gain = 2
local pain_shock_ramp_end = 120
local pain_shock_max_target = 85
local pain_shock_max_gain = 10
local pain_tolerance = 120
local otrub_pain_tolerance = 90
local pain_fake_threshold = 0.9
local pain_drain_base = 8
local pain_drain_otrub_mul = 4.5

function hg.organism.GetAdrenalinePainPacing(adrenaline)
	adrenaline = max(adrenaline or 0, 0)

	-- Natural adrenaline doses are reserve-scaled and commonly land below 0.5.
	-- Ramp smoothly from no effect so those ordinary rushes still delay both the
	-- arrival and recovery of pain, while preserving the strong full-rush floor.
	return max(max(1 - adrenaline, 0.05) / (1 + adrenaline * 1.5), 0.02)
end

module[1] = function(org)

	org.shock = 0

	org.pain = 0

	org.avgpain = 0

	org.painadd = 0
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

	org.tranquilizer = 0

	org.shock_turn = 0



	org.stun = 0

	org.lightstun = 0

end

module[2] = function(owner, org, timeValue)

	local adrenalineMul = min(max(1 + org.adrenaline, 1), 1.2)

	local adrenaline = org.adrenaline

	local analgesiaMul = ((org.analgesia + org.painkiller * 0.3) * 4 + 1)

	local painkillerMul = 1

	local goodmood = math.Clamp(org.goodmood or 0, 0, 1)

	local goodmoodResistance = 1 - goodmood * 0.25



	-- Check for left hand mitigation: working left hand + damaged right hand

	-- Mitigation applies unless one-handing or left arm is damaged

	local leftHandHealthy = not org.larmamputated and not (org.larm and org.larm >= 1) and not (org.larmdislocation or org.larmdislocated)

	local rightHandDamaged = (org.rarm and org.rarm >= 1) or (org.rarmdislocation or org.rarmdislocated) or org.rarmamputated

	local isOneHanding = false

	

	if IsValid(owner) and owner:IsPlayer() then

		local wep = owner:GetActiveWeapon()

		isOneHanding = IsValid(wep) and wep.TwoHanded == false

	end

	

	local painMitigation = 1

	if leftHandHealthy and rightHandDamaged and not isOneHanding then

		painMitigation = 0.5 -- Halve pain

	end



	org.shock_turn = 10 * (!org.otrub and 1 or 0.1)



	if org.shock > org.shock_turn * 1.5 * analgesiaMul * painkillerMul then

		--org.needfake = true

	end



	org.pain_turn = org.otrub and adrenalineMul * otrub_pain_tolerance or adrenalineMul * pain_tolerance

	local owner = org.owner

	

	if !org.lasthit or org.lasthit + 1.5 < CurTime() then org.shock = max(org.shock - timeValue * 4 * (org.otrub and 1 or 0.5), 0) end
	org.immobilization = max(org.immobilization - timeValue * 5 * adrenalineMul, 0)

	local shouldPainAdd = not (org.otrub or org.spine2 >= hg.organism.fake_spine2 or org.spine3 >= hg.organism.fake_spine3)
	
	-- Otrub blocks incoming pain.  Apply that rule to the accumulator itself so
	-- queued pain cannot keep avgpain pinned at its 150 cap indefinitely.
	local add = shouldPainAdd and math.min(timeValue * 15, org.painadd) or 0
	local sub = (add <= 0.2) and (timeValue * pain_drain_base * (org.otrub and pain_drain_otrub_mul or 1) + timeValue * ((org.painkiller * 0.3 + org.analgesia) * 4)) or (0)

	-- Adrenaline delays both the pain arriving and the body settling it, so the
	-- stored injury survives the rush and catches up afterward.
	local adrenalinePainPacing = hg.organism.GetAdrenalinePainPacing(adrenaline)
	add = add * adrenalinePainPacing
	sub = sub * adrenalinePainPacing



	if org.pain > 60 and not org.otrub then

		-- Severe pain compounds: it is harder to settle and more readily aggravated.
		add = add * 1.5

		if org.pain > 70 and add > 0.01 then

			sub = sub / 20

		else

			sub = sub / 5

		end



		org.disorientation = math.max(org.pain / 50, org.disorientation)//org.disorientation + add

		org.fearadd = 1

	end



	org.disorientation = math.min(org.disorientation, 10)



	if org.pain > pain_shock_threshold then
		local painShockTarget = Clamp(math.Remap(org.pain, pain_shock_threshold, pain_shock_ramp_end, pain_shock_target, pain_shock_max_target), pain_shock_target, pain_shock_max_target)
		local painShockGain = Clamp(math.Remap(org.pain, pain_shock_threshold, pain_shock_ramp_end, pain_shock_gain, pain_shock_max_gain), pain_shock_gain, pain_shock_max_gain)
		org.shock = math.Approach(org.shock, painShockTarget, timeValue * painShockGain)
	end

	local shockThreshold = shock_consciousness_threshold * analgesiaMul * painkillerMul
	local shockActive = org.shock > shockThreshold
	if shockActive then
		local shockTarget = Clamp(math.Remap(org.shock, shockThreshold, shock_consciousness_max, shock_consciousness_soft_target, shock_consciousness_hard_target), shock_consciousness_hard_target, shock_consciousness_soft_target)
		local shockDrain = Clamp(math.Remap(org.shock, shockThreshold, shock_consciousness_max, shock_consciousness_drain_start, shock_consciousness_drain_end), shock_consciousness_drain_end, shock_consciousness_drain_start)
		org.consciousness = Approach(org.consciousness, shockTarget, timeValue / shockDrain)
	end
	if org.tranquilizer > 0 then

		org.tranquilizer = math.Approach(org.tranquilizer, 0, org.tranquilizer > 1 and timeValue / 5 or timeValue / 30)
		--org.shock = math.Approach(org.shock, 50, timeValue * org.tranquilizer * 5)
		--org.shock = math.Approach(org.shock, 50, timeValue * org.tranquilizer * 5)

		org.consciousness = math.Approach(org.consciousness, 0, timeValue / 30 * org.tranquilizer)
	elseif not shockActive then
		local target = org.blood < 2500 and (org.blood - 2000) / 500 or 1
		local recovery_speed = consciousness_recovery_speed
		if org.otrub or org.consciousness < consciousness_otrub_threshold then
			recovery_speed = otrub_consciousness_recovery_speed
		elseif org.consciousness < consciousness_fake_threshold then
			recovery_speed = low_consciousness_recovery_speed
		end
		org.consciousness = Approach(org.consciousness, target, timeValue / recovery_speed)
	end



	-- Brain trauma and intracranial bleeding share the normal unconsciousness
	-- pipeline, so a hemorrhage cannot be hidden by the regular recovery step.
	local brainSeverity = math.Clamp(((org.brain or 0) - 0.325) / 0.675, 0, 1)
	local hemorrhageSeverity = math.Clamp(((org.brainHemorrhage or 0) - 0.05) / 0.95, 0, 1)
	if brainSeverity > 0 or hemorrhageSeverity > 0 then
		local consciousnessDrain = brainSeverity > 0 and (0.17 + brainSeverity * 0.06) or 0
		consciousnessDrain = consciousnessDrain + hemorrhageSeverity * (0.02 + hemorrhageSeverity * 0.12)
		org.consciousness = math.max((org.consciousness or 1) - consciousnessDrain * timeValue, 0)
	end


	if org.consciousness < consciousness_otrub_threshold then
		org.needotrub = true

	end



	if org.consciousness < consciousness_fake_threshold then
		org.needfake = true

	end



	org.avgpain = min(org.avgpain + add, 150)

	if !org.lasthit or org.lasthit + 1 < CurTime() then org.avgpain = max(org.avgpain - sub, 0) end

	org.painlessen = sub



	-- Adrenaline can blunt pain, but it cannot erase nearly all of it.  Keep the
	-- Remorseism 75% floor so injuries remain readable during the rush.
	org.pain = org.avgpain * math.max(1 - adrenaline / 4, 0.75) * math.max(1 - (org.analgesia + org.painkiller * 0.3), 0)
	org.nearpainlimit = not org.otrub and org.pain >= org.pain_turn * pain_fake_threshold

	if shouldPainAdd then
		org.painadd = min(max(org.painadd - add * analgesiaMul, 0), 150)
	else
		org.painadd = 0
	end



	//org.painkiller = Approach(org.painkiller, 0, timeValue / 240 * (org.naloxone * 25 + 1))

	if org.nearpainlimit then
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



	if org.adrenalineAdd > 0 then

		local critical = (org.blood and org.blood < 1500) or (org.brain and org.brain > 1.5)
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



	local adrenalineDecayRate = timeValue / (org.otrub and 8 or 25)

	if fastAdrenalineDecay then

		adrenalineDecayRate = timeValue / 8 -- Faster than normal, but still a gradual comedown

	end



	-- When in fear, adrenaline decays faster

	if org.fear and org.fear > 0 then

		adrenalineDecayRate = adrenalineDecayRate * (1 + org.fear * 0.5)

	end

	if org.adrenalineAdd > 0 or CurTime() < (org._adrenalineHoldUntil or 0) then
		adrenalineDecayRate = 0
	end



	org.adrenaline = Approach(org.adrenaline, 0, adrenalineDecayRate)



	if org.lleg < 1 and !org.llegamputated then

		org.lleg = max(org.lleg - timeValue / 240, 0)

	end



	if org.rleg < 1 and !org.rlegamputated then

		org.rleg = max(org.rleg - timeValue / 240, 0)

	end



	if org.rarm < 1 then

		org.rarm = max(org.rarm - timeValue / 240, 0)

	end



	if org.larm < 1 then

		org.larm = max(org.larm - timeValue / 240, 0)

	end



	if org.pain > 100 then

		org.needfake = true

	end



	//local tempo = math.Clamp(5 - (org.temperature - 31), 0, 15)

	

	//org.shock = math.max(org.shock, tempo * 4)

	

	org.disorientation = math.Approach(org.disorientation, 0, timeValue / 5)



	-- Reduce goodmood when pain is high

	if org.pain > 50 then

		local painFactor = math.Clamp((org.pain - 50) / 50, 0, 1)

		org.goodmood = math.Clamp((org.goodmood or 1) - painFactor * timeValue * 0.02, 0, 1)

	end

end
