local max, min, Clamp, Approach = math.max, math.min, math.Clamp, math.Approach

--local Organism = hg.organism

hg.organism.module.pain = {}

local module = hg.organism.module.pain
local consciousness_otrub_threshold = 0.08
local consciousness_fake_threshold = 0.38
local shock_consciousness_target = 0.18
local otrub_consciousness_target = 0.08
local shock_consciousness_drain = 7
local otrub_consciousness_drain = 8
local consciousness_recovery_speed = 12
local low_consciousness_recovery_speed = 16
local otrub_consciousness_recovery_speed = 20
module[1] = function(org)

	org.shock = 0

	org.pain = 0

	org.avgpain = 0

	org.painadd = 0

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



function hg.organism.paincheck(org)

	local analgesiaMul = (org.analgesia * 4 + 1)

	local adrenalineMul = min(max(1 + org.adrenaline, 1), 1.2)



	return (org.shock > org.shock_turn * 4 * analgesiaMul)

end



module[2] = function(owner, org, timeValue)

	local adrenalineMul = min(max(1 + org.adrenaline, 1), 1.2)

	local adrenaline = org.adrenaline

	local analgesiaMul = (org.analgesia * 4 + 1)

	local painkillerMul = (org.painkiller * 0.5 + 1)

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



	org.pain_turn = org.otrub and adrenalineMul * 80 or adrenalineMul * 90



	local owner = org.owner

	

	if !org.lasthit or org.lasthit + 1.5 < CurTime() then org.shock = max(org.shock - timeValue * 4 * (org.otrub and 1 or 0.5), 0) end

	org.immobilization = max(org.immobilization - timeValue * 2 * adrenalineMul, 0)



	local shouldPainAdd = not (org.otrub or org.spine2 >= hg.organism.fake_spine2 or org.spine3 >= hg.organism.fake_spine3)

	

	local add = math.min(timeValue * 100, org.painadd) * goodmoodResistance * painMitigation

	local sub = (add <= 0.2) and (timeValue * 2 * (org.otrub and 5 or 1) + timeValue * (org.painkiller * 2) + timeValue * (org.analgesia * 4)) or (0)



	if adrenaline > 0.5 then

		local suppression = math.max(1 - adrenaline, 0.05) / 1.5

		sub = sub * suppression

		add = add * suppression

	end



	if org.pain > 60 and not org.otrub then

		add = add / 5

		if org.pain > 70 and add > 0.01 then

			sub = sub / 20

		else

			sub = sub / 5

		end



		org.disorientation = math.max(org.pain / 50, org.disorientation)//org.disorientation + add

		org.fearadd = 1

	end



	org.disorientation = math.min(org.disorientation, 10)



	if org.pain > 80 then

		org.shock = math.Approach(org.shock, 70 * goodmoodResistance, timeValue * 4)

	end



	



	if org.otrub then
		org.consciousness = Approach(org.consciousness, otrub_consciousness_target, timeValue / otrub_consciousness_drain)
	elseif org.shock > (30 * analgesiaMul) then
		org.consciousness = Approach(org.consciousness, shock_consciousness_target, timeValue / shock_consciousness_drain)
	end

	if org.tranquilizer > 0 then

		org.tranquilizer = math.Approach(org.tranquilizer, 0, org.tranquilizer > 1 and timeValue / 5 or timeValue / 30)

		--org.shock = math.Approach(org.shock, 50, timeValue * org.tranquilizer * 5)

		org.consciousness = math.Approach(org.consciousness, 0, timeValue / 30 * org.tranquilizer)

	else
		local target = org.blood < 3000 and (org.blood - 2500) / 500 or 1
		local recovery_speed = consciousness_recovery_speed
		if org.otrub then
			recovery_speed = otrub_consciousness_recovery_speed
		elseif org.consciousness < consciousness_fake_threshold then
			recovery_speed = low_consciousness_recovery_speed
		end
		org.consciousness = Approach(org.consciousness, target, timeValue / recovery_speed)
	end



	-- Brain damage tanks consciousness above 0.325

	if (org.brain or 0) > 0.325 then

		local brainSeverity = (org.brain - 0.325) / 0.675 -- 0 to 1 scaling

		-- At 0.325: drains to 0 in ~10s; at max brain damage: drains to 0 in ~6s
		local consciousnessDrain = (0.17 + brainSeverity * 0.06) * timeValue

		org.consciousness = math.max((org.consciousness or 1) - consciousnessDrain, 0)

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



	org.pain = org.avgpain * math.max(1 - adrenaline / 4, 0.75) * math.max(1 - org.analgesia, 0)


	org.painadd = min(max(org.painadd - add * analgesiaMul, 0), 150)



	//org.painkiller = Approach(org.painkiller, 0, timeValue / 240 * (org.naloxone * 25 + 1))



	if hg.organism.paincheck(org) then

		local shockCap = org.shock_turn * 4 * ((org.analgesia * 4 + 1))

		local shockSeverity = math.Clamp((org.shock - shockCap) / 50, 0.1, 1)

		org.consciousness = math.max((org.consciousness or 1) - timeValue * shockSeverity * 0.4, 0.25)

	end

	if org.consciousness < 0.1 then
		org.needotrub = true
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
			org.adrenaline = Approach(org.adrenaline, math.min(org.adrenaline, 2), timeValue / 5 * reserveK)
		else
			org.adrenaline = Approach(org.adrenaline, 3.2, timeValue / 5 * reserveK)
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



	local adrenalineDecayRate = timeValue / (org.otrub and 5 or 12)

	if fastAdrenalineDecay then

		adrenalineDecayRate = timeValue / 5 -- Much faster decay

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
