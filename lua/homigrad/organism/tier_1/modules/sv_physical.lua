local max, min, Clamp, Approach = math.max, math.min, math.Clamp, math.Approach
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua

--local Organism = hg.organism

=======
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
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
local anger_pain_reduction_max = 0.16

function hg.organism.GetAdrenalinePainPacing(adrenaline)
	adrenaline = max(adrenaline or 0, 0)

	-- This is a delivery rate, not a pain-reduction multiplier. A full rush
	-- leaves most new pain in painadd, so it arrives after the rush instead of
	-- disappearing from the injury entirely.
	return max(1 / (1 + adrenaline * 2.5), 0.08)
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
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



=======
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	org.stun = 0

	org.lightstun = 0

end
module[2] = function(owner, org, timeValue)

	local adrenalineMul = min(max(1 + org.adrenaline, 1), 1.2)

	local adrenaline = org.adrenaline
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua
	local resilience = hg.organism.GetResilience and hg.organism.GetResilience(org) or 0
	local zerlkers = math.Clamp(org.zerlkers or 0, 0, 1)
	local zerlkersResistance = hg.organism.GetZerlkersResistance and hg.organism.GetZerlkersResistance(org) or zerlkers
	local anger = Clamp(org.anger or 0, 0, 1)

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



	-- A Zerlkers dose is deliberately stronger than a natural adrenaline rush:
	-- it delays new pain, rapidly settles existing pain, and raises the point at
	-- which pain can force a ragdoll. It does not alter injury or vital damage.
	local painToleranceMul = 1 + resilience * 0.2 + zerlkers * 1.3
	org.pain_turn = (org.otrub and adrenalineMul * otrub_pain_tolerance or adrenalineMul * pain_tolerance) * painToleranceMul

	local owner = org.owner

	

	if !org.lasthit or org.lasthit + 1.5 < CurTime() then org.shock = max(org.shock - timeValue * 4 * (org.otrub and 1 or 0.5) * (1 + resilience * 0.75 + zerlkersResistance * 2.25), 0) end
=======
	local analgesiaMul = (org.analgesia * 4 + 1)
	local painkillerMul = (org.painkiller * 0.5 + 1)
	org.shock_turn = 10 * (!org.otrub and 1 or 0.1)
	if org.shock > org.shock_turn * 1.5 * analgesiaMul * painkillerMul then
	end
	org.pain_turn = org.otrub and adrenalineMul * otrub_pain_tolerance or adrenalineMul * pain_tolerance
	local owner = org.owner
	if !org.lasthit or org.lasthit + 1.5 < CurTime() then org.shock = max(org.shock - timeValue * 4 * (org.otrub and 1 or 0.5), 0) end
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	org.immobilization = max(org.immobilization - timeValue * 5 * adrenalineMul, 0)
	local shouldPainAdd = not (org.otrub or org.spine2 >= hg.organism.fake_spine2 or org.spine3 >= hg.organism.fake_spine3)
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua
	
	-- Otrub blocks queued pain from reaching avgpain. Keep the queue intact so
	-- stimulants and unconsciousness defer pain instead of deleting it.
	local queuedPain = math.min(timeValue * 15, org.painadd)
	local add = shouldPainAdd and queuedPain or 0
	local sub = (add <= 0.2) and (timeValue * pain_drain_base * (org.otrub and pain_drain_otrub_mul or 1) + timeValue * ((org.painkiller * 0.3 + org.analgesia) * 4)) or (0)

	-- Adrenaline delays incoming pain. Zerlkers nearly stops it, preserving the
	-- backlog so the injury catches up once the effect has ended.
	local adrenalinePainPacing = hg.organism.GetAdrenalinePainPacing(adrenaline)
	add = add * Lerp(zerlkers, adrenalinePainPacing, 0.025)
	sub = sub * (1 + resilience * 0.35)



=======
	local add = math.min(timeValue * 15, org.painadd)
	local sub = (add <= 0.2) and (timeValue * pain_drain_base * (org.otrub and pain_drain_otrub_mul or 1) + timeValue * (org.painkiller * 2) + timeValue * (org.analgesia * 4)) or (0)
	if adrenaline > 0.5 then
		sub = sub * math.max(1 - adrenaline, 0.05) / 1.5// / (adrenaline >= 2 and 16 or 8)
		add = add * math.max(1 - adrenaline, 0.05) / 1.5// / (adrenaline >= 2 and 16 or 8)
	end
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	if org.pain > 60 and not org.otrub then

		-- Severe pain compounds: it is harder to settle and more readily aggravated.
		add = add * 1.5

		if org.pain > 70 and add > 0.01 then

			sub = sub / 20

		else

			sub = sub / 5

		end
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



		org.disorientation = math.max(org.pain / 50, org.disorientation)//org.disorientation + add

=======
		org.disorientation = math.max(org.pain / 50, org.disorientation)
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
		org.fearadd = 1

	end
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



	org.disorientation = math.min(org.disorientation, 10)



=======
	org.disorientation = math.min(org.disorientation, 10)
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	if org.pain > pain_shock_threshold then
		local painShockTarget = Clamp(math.Remap(org.pain, pain_shock_threshold, pain_shock_ramp_end, pain_shock_target, pain_shock_max_target), pain_shock_target, pain_shock_max_target)
		local painShockGain = Clamp(math.Remap(org.pain, pain_shock_threshold, pain_shock_ramp_end, pain_shock_gain, pain_shock_max_gain), pain_shock_gain, pain_shock_max_gain)
		local shockResistance = math.Clamp(resilience * 0.25 + zerlkersResistance * 0.50, 0, 0.75)
		painShockTarget = painShockTarget * (1 - shockResistance)
		org.shock = math.Approach(org.shock, painShockTarget, timeValue * painShockGain * (1 - shockResistance))
	end
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua

	local shockThreshold = shock_consciousness_threshold * analgesiaMul * painkillerMul * (1 + resilience * 0.6 + zerlkersResistance * 1.4)
=======
	local shockThreshold = shock_consciousness_threshold * analgesiaMul * painkillerMul
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	local shockActive = org.shock > shockThreshold
	if shockActive then
		local shockTarget = Clamp(math.Remap(org.shock, shockThreshold, shock_consciousness_max, shock_consciousness_soft_target, shock_consciousness_hard_target), shock_consciousness_hard_target, shock_consciousness_soft_target)
		local shockDrain = Clamp(math.Remap(org.shock, shockThreshold, shock_consciousness_max, shock_consciousness_drain_start, shock_consciousness_drain_end), shock_consciousness_drain_end, shock_consciousness_drain_start)
		org.consciousness = Approach(org.consciousness, shockTarget, timeValue / shockDrain)
	end
	if org.tranquilizer > 0 then

		org.tranquilizer = math.Approach(org.tranquilizer, 0, org.tranquilizer > 1 and timeValue / 5 or timeValue / 30)
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua
		--org.shock = math.Approach(org.shock, 50, timeValue * org.tranquilizer * 5)
		--org.shock = math.Approach(org.shock, 50, timeValue * org.tranquilizer * 5)

=======
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
		org.consciousness = math.Approach(org.consciousness, 0, timeValue / 30 * org.tranquilizer)
	elseif not shockActive then
		local effectiveBlood = hg.organism.GetResilientBlood and hg.organism.GetResilientBlood(org) or org.blood
		local target = effectiveBlood < 2500 and (effectiveBlood - 2000) / 500 or 1
		local recovery_speed = consciousness_recovery_speed
		if org.otrub or org.consciousness < consciousness_otrub_threshold then
			recovery_speed = otrub_consciousness_recovery_speed
		elseif org.consciousness < consciousness_fake_threshold then
			recovery_speed = low_consciousness_recovery_speed
		end
		org.consciousness = Approach(org.consciousness, target, timeValue / recovery_speed)
	end
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



	-- Brain trauma and intracranial bleeding share the normal unconsciousness
	-- pipeline, so a hemorrhage cannot be hidden by the regular recovery step.
	local brainSeverity = math.Clamp(((org.brain or 0) - 0.325) / 0.675, 0, 1)
	local hemorrhageSeverity = math.Clamp(((org.brainHemorrhage or 0) - 0.05) / 0.95, 0, 1)
	if brainSeverity > 0 or hemorrhageSeverity > 0 then
		local consciousnessDrain = brainSeverity > 0 and (0.17 + brainSeverity * 0.06) or 0
		consciousnessDrain = consciousnessDrain + hemorrhageSeverity * (0.02 + hemorrhageSeverity * 0.12)
		org.consciousness = math.max((org.consciousness or 1) - consciousnessDrain * timeValue, 0)
	end


	local consciousnessResistance = 1 - resilience * 0.3
	if org.consciousness < consciousness_otrub_threshold * consciousnessResistance then
		org.needotrub = true

	end



	if org.consciousness < consciousness_fake_threshold * consciousnessResistance then
		org.needfake = true

	end



=======
	if org.consciousness < consciousness_otrub_threshold then
		org.needotrub = true
	end
	if org.consciousness < consciousness_fake_threshold then
		org.needfake = true
	end
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	org.avgpain = min(org.avgpain + add, 150)

	if !org.lasthit or org.lasthit + 1 < CurTime() then org.avgpain = max(org.avgpain - sub, 0) end

	org.painlessen = sub
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



	-- Anger grants a small pain resistance. Stimulants defer incoming pain via
	-- painadd above instead of directly deleting pain already incurred.
	local angerPainMul = 1 - anger * anger_pain_reduction_max
	org.pain = org.avgpain * math.max(1 - (org.analgesia + org.painkiller * 0.3), 0) * angerPainMul
	org.nearpainlimit = not org.otrub and org.pain >= org.pain_turn * pain_fake_threshold

	if org.isPly and org.pain >= 85 and IsValid(owner) and owner.Thought then
		owner:Thought("You are experiencing excruciating pain.", 8, "thought_excruciatingpain", 0, Color(255, 160, 160))
	end

	-- Remove only pain that actually entered avgpain. The old queuedPain
	-- subtraction made adrenaline and Zerlkers erase deferred damage.
=======
	org.pain = org.avgpain * math.max(1 - adrenaline / 4, 0.75) * math.max(1 - org.analgesia, 0)
	org.nearpainlimit = not org.otrub and org.pain >= org.pain_turn * pain_fake_threshold
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	org.painadd = min(max(org.painadd - add * analgesiaMul, 0), 150)
	if org.nearpainlimit then
		org.needfake = true
	end
	org.analgesia =  Approach(org.analgesia, 0, timeValue / 240 * (org.naloxone * 25 + 1))
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua

=======
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	if org.analgesiaAdd > 0 then

		org.analgesia =  Approach(org.analgesia, 5, timeValue / 15)

		org.analgesiaAdd = Approach(org.analgesiaAdd, 0, timeValue / 15)

	end
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



=======
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	org.naloxone = Approach(org.naloxone, org.naloxoneadd > 0 and 4 or 0, org.naloxoneadd > 0 and timeValue / 30 or timeValue / 60)

	org.naloxoneadd = Approach(org.naloxoneadd, 0, timeValue / 15)
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua

	

	--if owner.suiciding and org.adrenaline < 1.5 then

	--	org.adrenalineAdd = Approach(org.adrenalineAdd, 4, timeValue / 5)

	--end



=======
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	if org.adrenalineAdd > 0 then

		local critical = (org.blood and org.blood < 1500) or (org.brain and org.brain > 1.5)
		local reserveK = math.Clamp(((org.adrenalineStorage or 0) / 5) * 0.75 + 0.25, 0.25, 1)

		if critical then
			org.adrenaline = Approach(org.adrenaline, 2, timeValue / 5 * reserveK)
		else
			org.adrenaline = Approach(org.adrenaline, 4, timeValue / 5 * reserveK)
		end

	end
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



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



=======
	org.adrenalineAdd = Approach(org.adrenalineAdd, 0, org.adrenalineAdd < 0 and timeValue / 30 or timeValue / 5)
	org.adrenaline = Approach(org.adrenaline, 0, timeValue / 25)
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	if org.lleg < 1 and !org.llegamputated then

		org.lleg = max(org.lleg - timeValue / 240, 0)

	end
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



=======
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	if org.rleg < 1 and !org.rlegamputated then

		org.rleg = max(org.rleg - timeValue / 240, 0)

	end
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



=======
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	if org.rarm < 1 then

		org.rarm = max(org.rarm - timeValue / 240, 0)

	end
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



=======
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	if org.larm < 1 then

		org.larm = max(org.larm - timeValue / 240, 0)

	end
<<<<<<< HEAD:lua/homigrad/organism/tier_1/modules/sv_pain.lua



	if org.pain > 100 then

		org.needfake = true

	end



	//local tempo = math.Clamp(5 - (org.temperature - 31), 0, 15)

	

	//org.shock = math.max(org.shock, tempo * 4)

	

=======
	if org.pain > 100 then
	end
>>>>>>> 8e5ef9bd (some changes i already made):lua/homigrad/organism/tier_1/modules/sv_physical.lua
	org.disorientation = math.Approach(org.disorientation, 0, timeValue / 5)



	-- Reduce goodmood when pain is high

	if org.pain > 50 then

		local painFactor = math.Clamp((org.pain - 50) / 50, 0, 1)

		org.goodmood = math.Clamp((org.goodmood or 1) - painFactor * timeValue * 0.02, 0, 1)

	end

end
local min, max, Round = math.min, math.max, math.Round
local hg_organism_stamina_sprint_mul = CreateConVar("hg_organism_stamina_sprint_mul","1",{FCVAR_ARCHIVE,FCVAR_NOTIFY,FCVAR_NEVER_AS_STRING},"Multiply stamina drain when sprinting",0,10)
local panicattack_stamina_drain_mul = 1.35
hg.organism.module.stamina = {}
local module = hg.organism.module.stamina
module[1] = function(org)
	org.adrenaline = 0
	org.adrenalineAdd = 0
	org.adrenalineStorage = 5
	org.stamina = {
		range = 60 * 3,
		regen = 1,
		sub = 0,
		subadd = 0,
		weight = 0,
		max = 60 * 3,
		regenMul = 1,
	}
	org.energy = 0
	org.hemotransfusionshock = 0
	org.stamina[1] = org.stamina.range
	local owner = org.owner
	org.moveMaxSpeed = IsValid(owner) and owner:IsPlayer() and owner:GetMaxSpeed() or 250
end
local hg_infstamina = CreateConVar("hg_infstamina", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Toggle infinite stamina (excausts only from other organism effects, not from running/attacking)", 0, 1)
module[2] = function(owner, org, timeValue)
	local stamina = org.stamina
	local painfrommoving = (stamina.sub * (org.chest))
	if painfrommoving > 0 then
		if (org.jaw == 1) or org.jawdislocation then
		end
		if (org.chest > 0.25) then
		end
	end
	stamina.sub = 0
	local velLen = 0
	if owner:IsPlayer() then
		local wep = owner:GetActiveWeapon()
		local walk = owner:KeyDown(IN_FORWARD) or owner:KeyDown(IN_BACK) or owner:KeyDown(IN_MOVELEFT) or owner:KeyDown(IN_MOVERIGHT)
		velLen = max(min(owner:GetVelocity():Length(), org.moveMaxSpeed), 0) / (owner:GetRunSpeed() / hg_organism_stamina_sprint_mul:GetFloat())
		if (owner:OnGround() or owner:WaterLevel() >= 2) and walk and not owner:InVehicle() and owner.hg_isJogging and org.stamina[1] > 20 then
			stamina.sub = (owner:WaterLevel() >= 2 and 2 or 1) * (velLen ^ 0.5) * 0.6
		elseif (owner:OnGround() or owner:WaterLevel() >= 2) and walk and not owner:InVehicle() and owner.hg_isSprinting and org.stamina[1] > 20 then
			stamina.sub = (owner:WaterLevel() >= 2 and 2 or 1) * (velLen ^ 0.5) * 1.10
		end
	end
	if org.superfighter then
		org.stamina.subadd = org.stamina.subadd / 4
	end
	if org.chest > 0.3 then
		org.lungsL[2] = math.min(org.lungsL[2] + stamina.sub / 200 * org.chest, 1)
		org.lungsR[2] = math.min(org.lungsR[2] + stamina.sub / 200 * org.chest, 1)
	end
	stamina.sub = stamina.sub + stamina.subadd + (org.painkiller > 1.6 and (stamina[1] > 10 and 0.8 or 0) or 0) + (org.analgesia > 1.7 and (stamina[1] > 10 and 2 or 0) or 0)
	stamina.sub = stamina.sub * (owner.StaminaExhaustMul or 1)
	stamina.sub = stamina.sub / (1 + org.berserk)
	if org.o2[1] < 10 then
		stamina.sub = 0
	end
	stamina.subadd = 0
	stamina.weight = owner:IsPlayer() and math.Clamp((1 / hg.CalculateWeight(owner,250)) - 1,0,1) or 0
	local muffed = owner.armors and owner.armors["face"] == "mask2"
	stamina.sub = stamina.sub + stamina.sub * stamina.weight * (muffed and 2 or 1)
	if (org.panicattack or 0) >= 0.45 then
		stamina.sub = stamina.sub * panicattack_stamina_drain_mul
	end
	org.hungry = org.hungry or 0
	stamina.max = (org.superfighter and 2 or 1) * ((stamina.range * (1 - (org.pneumothorax) / 2) + org.adrenaline * 20 ) * math.max(1 - org.hemotransfusionshock,0.2)) * math.max(1 - (org.hungry/100),0.65)
	stamina[1] = max(stamina[1] - stamina.sub * timeValue * 16 * (2 - (org.o2[1] / org.o2.range)), 0)
	stamina[1] = min(stamina[1] + stamina.regen * timeValue * 8 * 1.5 * math.max(org.stamina[1] / org.stamina.max, 0.2) ^ 0.5 * (org.noradrenaline / 2 + 1) * (org.o2[1] / org.o2.range) * (org.adrenaline / 16 + 1) * (org.satiety/700 + 1) * ((owner:IsPlayer() and owner:Crouching() and velLen < 0.1) and 1.1 or 1) * (org.holdingbreath and 0 or 1) * (org.lungsfunction and 1 or 0) * (stamina.regenMul or 1), stamina.max)
	stamina.regenMul = math.Approach(stamina.regenMul or 1, 1, timeValue * (org.BlockRegenRecoverRate or 0.25))

	if cvars.Number("developer", 0) >= 1 and stamina.regenMul < 0.999 then
		if (org._nextRegenDebug or 0) < CurTime() then
			org._nextRegenDebug = CurTime() + 0.5
			print("[stamina] regenMul=" .. math.Round(stamina.regenMul, 2) .. " stamina[1]=" .. math.Round(stamina[1], 1) .. "/" .. math.Round(stamina.max, 0))
		end
	end
	if org.nextAdrenalineRegen and org.nextAdrenalineRegen < CurTime() then
		org.adrenalineStorage = math.Approach(org.adrenalineStorage, 5, timeValue / 60 * (org.satiety * 0.01 + 1))
	end
	if hg_infstamina:GetBool() then
		stamina.sub = 0
		stamina[1] = stamina.max
	end
end
function hg.organism.AddNaturalAdrenaline(org, fAmount)
	if org.adrenalineStorage == 0 then return end
	if fAmount < 0 then return end
	local amt = math.min(org.adrenalineStorage, fAmount)
	org.adrenaline = math.min(org.adrenaline + amt, 5)
	org.adrenalineStorage = org.adrenalineStorage - amt
	org.nextAdrenalineRegen = CurTime() + 30
end
local entMeta = FindMetaTable("Entity")
function entMeta:AddNaturalAdrenaline(fAmount)
	local org = self.organism
	if !org then return end
	hg.organism.AddNaturalAdrenaline(org, fAmount)
end
local vecZero = Vector(0, 0, 0)
hook.Add("FinishMove", "!homigrad-organism", function(ply, move)
	local vel = move:GetFinalJumpVelocity()
	if !ply.organism then return end
	if vel ~= vecZero then ply.organism.stamina[1] = max(ply.organism.stamina[1] - ply:GetJumpPower() / 10,0) end
	ply.organism.moveMaxSpeed = move:GetMaxSpeed()
end)
