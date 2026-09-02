local max, min, Round, Lerp = math.max, math.min, math.Round, Lerp

--local Organism = hg.organism

hg.organism.module.lungs = {}

local module = hg.organism.module.lungs

local cardiacArrestO2DrainTime = 20
local lowStaminaO2Start = 50
-- Ordinary fatigue should make breathing harder, not turn a short sprint into
-- an immediate blackout.  Only sustained, near-total exhaustion is allowed to
-- build enough oxygen debt to cause hypoxia on its own.
local criticalStaminaO2Start = 10
local lowStaminaO2DebtMax = 4
local opioidRespiratoryArrestThreshold = 0.85

module[1] = function(org)

	org.lungsL = {

		0, --состояние,пневмотаракс

		0

	}



	org.lungsR = {0, 0}

	org.trachea = 0

	org.pneumothorax = 0

	org.hemothorax = 0
	org.hemothoraxTrauma = 0
	org.hemothoraxL = 0
	org.hemothoraxR = 0
	org.internalBleedLungSide = nil

	org.needle = 0

	org.tracheaPath = nil -- "trachea" or "pneumothorax" determined when first > 0.5

	org.nextCough = nil

	org.o2 = {

		range = 30,

		regen = 4,

		k = 0.5,

	}



	



			org.lungsfunction = true



	org.o2.curregen = org.o2.regen

	

	org.o2[1] = org.o2.range

	org.CO = 0

	org.COregen = 0
	org.fireCOExposure = 0

	org.lastCOBreathe = nil
	org.exertionO2Debt = 0
	org.opioidRespiratoryDepression = 0
	org.drugRespiratoryDepression = 0
	org.bradyapnea = 0
	org.respiratoryRate = 14
	org.respiratoryArrest = false



	org.mannitol = 0

end



function hg.organism.HasUnderwaterOxygen(org)
	local owner = org and org.owner
	if not IsValid(owner) then return false end

	local armors = owner.armors or owner:GetNetVar("Armor", {})
	local backArmor = istable(armors) and armors.back
	local armorData = backArmor and hg.armor and hg.armor.back and hg.armor.back[backArmor]
	return armorData and armorData.underwaterOxygen == true or false
end



function hg.organism.OxygenateBlood(org)

	local canDrawBreath = org.owner:WaterLevel() < 3 or hg.organism.HasUnderwaterOxygen(org)
	-- Each lung contributes its remaining functional tissue.  The former 50%
	-- floor let heavily damaged lungs oxygenate blood exactly like a single
	-- healthy lung, so lung damage never reached tissue O2 until total failure.
	local lungFunction = math.Clamp(((1 - org.lungsL[1]) + (1 - org.lungsR[1])) / 2, 0, 1)
	return (lungFunction * (1 - org.trachea * 0.8)) * org.o2.regen / 4 * (canDrawBreath and 1 or 0)// * (1 - org.pneumothorax)

end



function hg.organism.CanBreath(org)

	return org.o2 and org.o2.curregen >= org.losing_oxy

end



local function insta_send_holdingbreath(org)

	net.Start("organism_send") // отправляем только дизориентацию (чтобы не нагружать нет), и сразу

	

	local tbl = {}

	tbl.holdingbreath = org.holdingbreath

	tbl.owner = org.owner



	net.WriteTable(tbl)

	net.WriteBool(true)

	net.WriteBool(false)

	net.WriteBool(false)

	net.WriteBool(true) // вот эта шняга отвечает за то чтобы оно просто мерджнуло и всё

	net.Send(org.owner)

end



local function togglebreath(ply, toggle)

	local org = ply.organism

	

	if isbool(toggle) then

		if toggle then

			if not ply.organism.holdingbreath then

				ply.organism.holdingbreath = true

				ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/inhale/female/inhale_0"..math.random(5)..".ogg" or "breathing/inhale/male/inhale_0"..math.random(4)..".ogg",65)

				insta_send_holdingbreath(ply.organism)

			end

		else

			if ply.organism.holdingbreath then

				ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/exhale/female/exhale_0"..math.random(5)..".ogg" or "breathing/exhale/male/exhale_0"..math.random(5)..".ogg",65)

				ply.organism.holdingbreath = false

				ply.releasebreathe = nil

				insta_send_holdingbreath(ply.organism)

			end

		end

	else

		if ply.organism.holdingbreath then

			ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/exhale/female/exhale_0"..math.random(5)..".ogg" or "breathing/exhale/male/exhale_0"..math.random(5)..".ogg",65)

			ply.organism.holdingbreath = false

			ply.releasebreathe = nil

			insta_send_holdingbreath(ply.organism)

		else

			ply.organism.holdingbreath = true

			ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/inhale/female/inhale_0"..math.random(5)..".ogg" or "breathing/inhale/male/inhale_0"..math.random(4)..".ogg",65)

			insta_send_holdingbreath(ply.organism)

		end

	end



	local ent = hg.GetCurrentCharacter(ply)

	ent:StopSound(ply.lastPhr or "")

	ply.phrCld = 0

end



concommand.Add("hmcd_holdbreath",function(ply)

	if not ply.organism then return end

	if not ply:Alive() then return end

	if ply.organism.stamina[1] < 90 then return end

	if ply.organism.o2.curregen == 0 then return end



	if (ply.cooldownbreathe or 0) > CurTime() then return end

	ply.cooldownbreathe = CurTime() + 0.5



	togglebreath(ply)

end)



concommand.Add("+hmcd_holdbreath",function(ply)

	if not ply.organism then return end

	if not ply:Alive() then return end

	if ply.organism.stamina[1] < 90 then return end

	if ply.organism.o2.curregen == 0 then return end



	if (ply.cooldownbreathe or 0) > CurTime() then return end

	ply.cooldownbreathe = CurTime() + 0.5



	togglebreath(ply,true)

end)



concommand.Add("-hmcd_holdbreath",function(ply)

	if not ply.organism then return end

	if ply.organism.stamina[1] < 90 then return end

	if ply.organism.o2.curregen == 0 then return end



	if (ply.cooldownbreathe or 0) > CurTime() then ply.releasebreathe = ply.cooldownbreathe return end



	togglebreath(ply,false)

end)



local lowoxy = {
	"I NEED AIR... I CAN'T BREATHE...",
	"IM SUFFOCATING TO FUCKING DEATH.",
	"WHY CANT I BREATHE. I NEED AIR...",
	"IT'S GETTING HARDER TO BREATHE... I NEED AIR...",
	"I CANT FUCKING BREATHE."
}

local multiCauseDying = {
	"Everything is fading... I don't think I can keep going.",
	"My body is shutting down...",
	"I can't stay awake much longer...",
}

local function notifyCriticalHypoxia(org)
	local owner = org.owner
	if not IsValid(owner) or not owner:IsPlayer() then return end
	local now = CurTime()
	if (org.nextCriticalStatusNotify or 0) > now then return end

	local multipleCauses = (org.internalBleed or 0) > 0.75
		or (org.bleed or 0) > 0
		or (org.brain or 0) > 0.08
		or (org.heart or 0) > 0.2
		or (org.pneumothorax or 0) > 0.2
		or (org.hemothorax or 0) > 0.15
		or org.cervicalRespiratoryArrest

	local message = (multipleCauses and math.Rand(0, 1) < 0.58)
		and multiCauseDying[math.random(#multiCauseDying)]
		or lowoxy[math.random(#lowoxy)]
	owner:Notify(message, 28, "hypoxia_critical", 0, nil, color_red3)
	org.nextCriticalStatusNotify = now + 24
end

local not_enough_intake = {

	//"I have to breathe...",

	//"I gotta take a break...",

	//"Need a break from this... to breathe...",

	//"Resting sounds like a nice idea.",
	"I need to breathe...",
	"I'm struggling to get air.",
}

local barely_breathing = {
	"Breathing is so hard for some reason...",
	"I can't get enough air in...",
	"Every breath feels weak...",
}

local function oxygenIntakeThoughtExpired(ply)
	local current = IsValid(ply) and ply.organism
	if not current or not current.o2 then return true end

	local oxygen = tonumber(current.o2[1]) or 30
	local intake = tonumber(current.o2.curregen) or 0
	local demand = tonumber(current.losing_oxy) or 0
	return current.heartstop or current.otrub or (current.analgesia or 0) > 1.5 or intake >= demand or oxygen <= 12 or oxygen >= 25
end

local function barelyBreathingThoughtExpired(ply)
	local current = IsValid(ply) and ply.organism
	if not current or not current.o2 then return true end

	local intake = tonumber(current.o2.curregen) or 0
	local demand = tonumber(current.losing_oxy) or 0
	return current.heartstop or current.otrub or current.choking or (current.analgesia or 0) > 1.5 or intake < demand or intake >= demand * 1.3
end

local low_stamina = {
	"I'm tired of this...",
	"I need to slow down and catch my breath...",
	"I can barely keep going...",
}

local drop_mask = {
	"Drop the fucking mask.",
	"I cant breathe in this mask...",
	"It's fucking disgusting in this mask, I cant breathe...",
	"Fucking stinks... Gotta take this mask off...",
}



local drugged = {

	"Ohhh hohoohoooo Ie-like it.....",

	"Fukkenh awesomee..... ffffeeelin gooooood..",

	"That's theh sStuffff DUDeeee",

	"I reallly like whatEvER I'm feeling right now....",

	"Oh yeahhhh this feels gooood!",

	"I want to feel likhe this for theRRRREST of my life",

	"Why am I here even?.. wWhatever whuhhh heh",

	"Whoa re you? Gett outtaheree...",

	"Don't want anything else... this is pERRRfect!..",

}



local bit_band,util_PointContents = bit.band,util.PointContents



local color_white, color_red, color_red2, color_red3 = Color(255, 255, 255), Color(255, 0, 0), Color(200, 55, 55), Color(255, 100, 100)

module[2] = function(owner, org, timeValue)

	local o2 = org.o2
	if not org.alive then
		if hg.organism and hg.organism.BeginPostMortemDecay then
			hg.organism.BeginPostMortemDecay(org)
		end
		o2.curregen = 0
		org.oxygenIntakeAvailable = false
		org.lungsfunction = false
		return
	end

	if hg.organism.OrganSystemsEnabled and not hg.organism.OrganSystemsEnabled() then
		o2[1] = o2.range
		o2.curregen = o2.regen
		org.bloodO2Cap = o2.range
		org.bloodCarryO2Cap = o2.range
		org.oxygenIntakeAvailable = true
		org.lungsfunction = true
		org.exertionO2Debt = 0
		org.opioidRespiratoryDepression = 0
		org.drugRespiratoryDepression = 0
		org.bradyapnea = 0
		org.respiratoryRate = 14
		org.respiratoryArrest = false
		org._zeroO2Time = 0
		if org.brain >= 0.7 and org.alive then
			if hg.organism.KillFatalBrainDamage then
				hg.organism.KillFatalBrainDamage(org)
			else
				org.alive = false
			end
		end
		return
	end

	if (org.spawnOxygenGraceUntil or 0) > CurTime() then
		o2[1] = o2.range
		o2.curregen = o2.regen
		org.exertionO2Debt = 0
		org.oxygenIntakeAvailable = true
		org.lungsfunction = true
		return
	end

	local staminaValue = org.stamina and org.stamina[1] or lowStaminaO2Start
	local activelyExerting = org.stamina and (org.stamina.sub or 0) > 0.05 or false
	if owner:IsPlayer() and not owner:InVehicle() then
		local deliberatelyMoving = owner:KeyDown(IN_FORWARD) or owner:KeyDown(IN_BACK) or owner:KeyDown(IN_MOVELEFT) or owner:KeyDown(IN_MOVERIGHT)
		activelyExerting = activelyExerting or (deliberatelyMoving and owner:GetVelocity():Length2D() > 25)
	end

	local exertionO2Debt = math.Clamp(org.exertionO2Debt or 0, 0, o2.range)
	if activelyExerting and staminaValue < lowStaminaO2Start then
		if staminaValue > criticalStaminaO2Start then
			local severity = math.Clamp((lowStaminaO2Start - staminaValue) / (lowStaminaO2Start - criticalStaminaO2Start), 0, 1)
			exertionO2Debt = math.Approach(exertionO2Debt, lowStaminaO2DebtMax * severity, timeValue * 0.45)
		else
			local criticalSeverity = math.Clamp((criticalStaminaO2Start - staminaValue) / criticalStaminaO2Start, 0, 1)
			-- Reaching zero stamina is dangerous only if the player keeps pushing.
			-- At full exhaustion this takes roughly forty seconds to reach the
			-- blackout band, giving the player a meaningful chance to stop and rest.
			exertionO2Debt = math.min(exertionO2Debt + timeValue * (0.2 + criticalSeverity * 0.35), o2.range)
		end
	else
		exertionO2Debt = math.Approach(exertionO2Debt, 0, timeValue * 1.5)
	end
	org.exertionO2Debt = exertionO2Debt
	local exertionO2Cap = math.max(o2.range - exertionO2Debt, 0)

	-- Opioid overdose suppresses breathing directly. Naloxone lowers the active
	-- load, and a sufficiently severe overdose stops respiration until the load
	-- falls again; death then proceeds through the normal hypoxia/O2 path.
	local analgesiaLoad = math.Clamp(((org.analgesia or 0) - 1.5) / 2.5, 0, 1)
	local painkillerLoad = math.Clamp(((org.painkiller or 0) - 2.4) / 1.6, 0, 1)
	local naloxoneProtection = math.Clamp((org.naloxone or 0) / 4, 0, 1)
	local opioidRespiratoryDepression = math.Clamp((analgesiaLoad + painkillerLoad) * (1 - naloxoneProtection), 0, 1)
	local zerlkersRespiratoryDepression = math.Clamp(org.zerlkersOverdose or 0, 0, 1)
	local drugRespiratoryDepression = math.max(opioidRespiratoryDepression, zerlkersRespiratoryDepression)
	local bradyapnea = math.Clamp((drugRespiratoryDepression - 0.08) / 0.92, 0, 1)
	org.opioidRespiratoryDepression = opioidRespiratoryDepression
	org.drugRespiratoryDepression = drugRespiratoryDepression
	org.bradyapnea = bradyapnea
	org.respiratoryRate = math.Round(Lerp(bradyapnea, 14, 4))
	local cervicalOxygenLoss = 0
	if (org.spine3 or 0) >= 1 then
		org.spine3OxygenLossAt = org.spine3OxygenLossAt or CurTime() + 4
		cervicalOxygenLoss = math.Clamp((CurTime() - org.spine3OxygenLossAt) / 10, 0, 1)
		if cervicalOxygenLoss > 0 and not org.spine3OxygenLossWarned then
			org.spine3OxygenLossWarned = true
			if org.isPly and IsValid(owner) and owner:Alive() then
				owner:Notify("I'm starting to lose oxygen... I can't breathe.", 20, "spine3_oxygen_loss", 0, nil, Color(255, 95, 95))
			end
		end
	else
		org.spine3OxygenLossAt = nil
		org.spine3OxygenLossWarned = nil
	end
	org.cervicalOxygenLoss = cervicalOxygenLoss
	org.respiratoryArrest = drugRespiratoryDepression >= opioidRespiratoryArrestThreshold

	-- Blood volume affects oxygen delivery through cardiac output, pulse, and
	-- pressure. It is not itself an arterial saturation cap; the lungs own the
	-- blood's oxygen saturation and the circulation module owns delivery.
	org.bloodCarryO2Cap = o2.range
	org.hemorrhageOxygenTransport = 1
	org.hemorrhageAdrenalineO2Support = 0
	local bloodO2Cap = org.bloodO2Cap or o2.range

	local bodyTemperature = org.temperature or 36.7
	local coldO2Stress = bodyTemperature < 35 and math.Clamp(math.Remap(bodyTemperature, 35, 26, 0, 1), 0, 1) or 0
	-- Shivering raises demand early in hypothermia, then deeper cooling reduces
	-- whole-body metabolism and oxygen consumption. This is protective only while
	-- the lungs and circulation still provide oxygen; the cold lung penalties
	-- below continue to limit regeneration and maximum O2.
	local shiveringO2Demand = bodyTemperature < 35 and math.Clamp(math.Remap(bodyTemperature, 35, 32, 0, 0.25), 0, 0.25) or 0
	local coldMetabolicPreservation = bodyTemperature < 32 and math.Clamp(math.Remap(bodyTemperature, 32, 28, 0, 0.45), 0, 0.45) or 0
	local altitudeO2K = 1
	org.altitudeMeters = 0
	if ZCityWind and ZCityWind.Config and ZCityWind.Config.AtmosphereEnabled and ZCityWind.GetAtmosphereAtZ then
		local altitude, _, _, _, _, _, pressureRatio = ZCityWind.GetAtmosphereAtZ(owner:GetPos().z)
		org.altitudeMeters = altitude
		altitudeO2K = math.Clamp(pressureRatio, 0.35, 1)
	end
	org.airPressureRatio = altitudeO2K
	local coldOxygenUseMul = (1 + shiveringO2Demand) * (1 - coldMetabolicPreservation)
	local losing_oxy = timeValue * math.Clamp(org.o2[1] / 30, 0.25, 1) * coldOxygenUseMul

	org.losing_oxy = losing_oxy

	if not org.heartstop then
		o2[1] = max(o2[1] - losing_oxy, 0)
	end

	local ent = hg.GetCurrentCharacter(owner)

	local bone = ent:LookupBone("ValveBiped.Bip01_Head1")



	if (not bone) or (bone < 0) then bone = 6 end



	local head = ent:GetBonePosition(bone)

	

	if not head then

		head = ent:GetBonePosition(0)

	end



	if org.o2.curregen == 0 and org.holdingbreath then

		togglebreath(owner, false)

	end



	if org.holdingbreath then

		//org.stamina[1] = max(org.stamina[1] - timeValue * 15,0)

		if org.stamina[1] < 90 or org.o2[1] <= 10 then

			togglebreath(owner, false)

		end

		

		if owner.releasebreathe and owner.releasebreathe < CurTime() then

			togglebreath(owner, false)

			owner.releasebreathe = nil

		end

	end



	if not head then head = owner:GetPos() end

	

	local inwater = bit_band(util_PointContents(head),CONTENTS_WATER) == CONTENTS_WATER
	local scubaOxygenActive = owner:IsPlayer() and inwater and hg.organism.HasUnderwaterOxygen(org)
	org.scubaOxygenActive = scubaOxygenActive

	

	local success = owner:IsBerserk() or (not org.heartstop and not org.respiratoryArrest and org.alive and not (org.brain >= 0.4 and math.random(10 - (org.brain * 10)) < 4) and org.lungsfunction)

	if success and owner:IsPlayer() and inwater and not scubaOxygenActive then success = false end

	if success and org.choking then org.needfake = true success = false end

	if success and org.vomitInThroat then success = false end

	org.choking = false

	org.needle = math.max(tonumber(org.needle) or 0, 0)
	org.pneumothorax = math.Clamp(tonumber(org.pneumothorax) or 0, 0, 1)
	org.hemothorax = math.Clamp(tonumber(org.hemothorax) or 0, 0, 1)
	org.hemothoraxTrauma = math.Clamp(tonumber(org.hemothoraxTrauma) or 0, 0, 1)
	org.hemothoraxL = math.Clamp(tonumber(org.hemothoraxL) or 0, 0, 1)
	org.hemothoraxR = math.Clamp(tonumber(org.hemothoraxR) or 0, 0, 1)

	local hasPneumothorax = org.lungsR[2] == 1 or org.lungsL[2] == 1
	local needleActive = org.needle > 0
	org.needle = math.Approach(org.needle, 0, timeValue / 1200)

	-- A decompression needle vents an existing pneumothorax; it must never make
	-- an uninjured lung become punctured. The actual puncture remains until the
	-- lung is repaired, so the condition can return after the temporary vent ends.
	if hasPneumothorax and not needleActive then
		org.pneumothorax = min(org.pneumothorax + timeValue / 90 * (org.lungsL[2] + org.lungsR[2]) * math.Clamp(org.conditionResistanceMul or 1, 0.05, 1), (org.lungsL[2] + org.lungsR[2]) / 2)
	else
		org.pneumothorax = max(org.pneumothorax - timeValue / 10, 0)
	end

	local internalBleedPeak = math.max(tonumber(org.internalBleedPeak) or 0, tonumber(org.internalBleed) or 0, 0)
	local internalBleedComplication = math.Clamp(tonumber(org.internalBleedComplication) or 0, 0, 1)
	local thoracicOrganDamage = math.Clamp(math.max(
		org.heart or 0,
		org.trachea or 0,
		org.lungsL[1] or 0,
		org.lungsR[1] or 0
	), 0, 1)
	local bleedSeverity = math.Clamp(internalBleedPeak / 10, 0, 1)
	local delayedBleed = internalBleedComplication * bleedSeverity
	local incidentalHemothorax = org.internalBleedHemothoraxRisk and delayedBleed * 0.35 or 0
	local hemothoraxDrive = math.max(thoracicOrganDamage * delayedBleed, incidentalHemothorax)
	if needleActive then
		org.hemothoraxTrauma = max(org.hemothoraxTrauma - timeValue / 120, 0)
		org.hemothoraxL = max(org.hemothoraxL - timeValue / 120, 0)
		org.hemothoraxR = max(org.hemothoraxR - timeValue / 120, 0)
	elseif hemothoraxDrive > 0.005 then
		if org.internalBleedLungSide != "L" and org.internalBleedLungSide != "R" then
			org.internalBleedLungSide = math.random(2) == 1 and "L" or "R"
		end

		local fillTime = Lerp(delayedBleed, 900, 180)
		local bilateral = delayedBleed >= 0.6 and thoracicOrganDamage >= 0.75
		local hemothoraxTarget = hemothoraxDrive
		local targetL = (bilateral or org.internalBleedLungSide == "L") and hemothoraxTarget or 0
		local targetR = (bilateral or org.internalBleedLungSide == "R") and hemothoraxTarget or 0

		local conditionMul = math.Clamp(org.conditionResistanceMul or 1, 0.05, 1)
		org.hemothoraxL = math.Approach(org.hemothoraxL, targetL, timeValue / fillTime * conditionMul)
		org.hemothoraxR = math.Approach(org.hemothoraxR, targetR, timeValue / fillTime * conditionMul)
	else
		-- Blood in the pleural space does not vanish on its own. It needs a
		-- prolonged recovery period unless the player uses a needle.
		org.hemothoraxTrauma = max(org.hemothoraxTrauma - timeValue / 480, 0)
		org.hemothoraxL = max(org.hemothoraxL - timeValue / 360, 0)
		org.hemothoraxR = max(org.hemothoraxR - timeValue / 360, 0)
		if org.hemothoraxL <= 0 and org.hemothoraxR <= 0 then org.internalBleedLungSide = nil end
	end

	org.hemothorax = math.Clamp(max(org.hemothoraxTrauma, (org.hemothoraxL + org.hemothoraxR) / 2), 0, 1)

	-- Relative arterial oxygenation (0..30 game scale). The nonlinear reserve
	-- means moderate gas-exchange impairment does not immediately equal severe
	-- arterial desaturation.
	local lungGasExchange = math.Clamp(((1 - (org.lungsL[1] or 0)) + (1 - (org.lungsR[1] or 0))) / 2, 0, 1)
	local airwayGasExchange = math.Clamp(1 - (org.trachea or 0) * 0.8, 0, 1)
	local thoracicGasExchange = math.Clamp(1 - (org.pneumothorax or 0) * 0.70 - (org.hemothorax or 0) * 0.65, 0, 1)
	local respiratoryDrive = math.Clamp(1 - drugRespiratoryDepression * 0.95, 0, 1)
	local ventilationAvailable = success and 1 or 0
	local rawGasExchange = math.Clamp(lungGasExchange * airwayGasExchange * thoracicGasExchange * respiratoryDrive * ventilationAvailable, 0, 1)
	local saturationReserve = rawGasExchange > 0 and (1 - (1 - rawGasExchange) ^ 3.2) or 0
	local altitudeSaturation = Lerp(altitudeO2K, 0.55, 1)
	local arterialO2Target = o2.range * saturationReserve * altitudeSaturation
	-- Desaturation/reoxygenation takes time instead of teleporting with one tick.
	local currentBloodO2 = math.Clamp(tonumber(org.bloodO2Cap) or o2.range, 0, o2.range)
	local arterialChangeRate = arterialO2Target < currentBloodO2 and 0.055 or 0.22
	bloodO2Cap = math.Approach(currentBloodO2, arterialO2Target, timeValue * o2.range * arterialChangeRate)
	org.bloodO2Cap = bloodO2Cap



		if org.lastCOBreathe and org.lastCOBreathe + 1 > CurTime() then

		org.COregen = math.Approach(org.COregen, 30, timeValue * 1)

	else

		org.COregen = math.Approach(org.COregen, 0, timeValue * 0.5)

	end

	if not org._lastFireCOExposure or org._lastFireCOExposure + 1.5 < CurTime() then
		org.fireCOExposure = math.Approach(org.fireCOExposure or 0, 0, timeValue * 8)
	end

	

	if o2[1] < 8 then
		org._lowO2Time = (org._lowO2Time or 0) + timeValue
	else
		org._lowO2Time = math.max((org._lowO2Time or 0) - timeValue * 2, 0)
	end

	if org._lowO2Time > 5 then
		local buildRate = math.Clamp((org._lowO2Time - 5) / 30, 0, 1)
		org.CO = math.min(org.CO + timeValue * buildRate * 0.4, 10)
	end

	org.CO = max(org.CO - timeValue, 0)

	if success then

		local oxygenate = hg.organism.OxygenateBlood(org) * 0.5

		local lerp = min(max(org.pulse - 20, 0) / 20, 1)

		local regen = Lerp(lerp, 0, o2.regen * oxygenate * math.Rand(0.95, 1.05))



		org.CO = min(org.CO + (org.COregen > 0 and timeValue * 1.5 or 0), 30)

		if (org.fireCOExposure or 0) > 0 and not org.holdingbreath then
			local breathMul = math.Clamp(regen / math.max(o2.regen or 4, 1), 0.25, 2)
			org.CO = min(org.CO + timeValue * (0.45 + org.fireCOExposure * 0.125) * breathMul, 30)
		end



		-- CO poisoning only affects consciousness once meaningful (above ~10).
		-- Below that, hemoglobin still carries enough oxygen.
		if org.CO > 10 then
			org.consciousness = math.min(org.consciousness, (30 - org.CO) / 30)
		end

		local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
		if totalAdrenaline > 0.5 then
			org.CO = math.max(org.CO - timeValue * math.Clamp(totalAdrenaline * 0.5, 0.25, 2), 0)
			org.COregen = math.max(org.COregen - timeValue * math.Clamp(totalAdrenaline * 0.5, 0.25, 2), 0)
			org._lowO2Time = math.max((org._lowO2Time or 0) - timeValue * totalAdrenaline * 2, 0)
		end



		local mask_blevota = owner:GetNetVar("zableval_masku", false)



		local sprayed = org.is_sprayed_at

		org.is_sprayed_at = nil



		local pulseMultiplier = math.Clamp((org.heartbeat or 75) / 75, 0.8, 1.5)
		local pulsePerfusionK = math.Clamp(((org.pulse or 70) - 15) / 55, 0.12, 1)
		local circulationK = math.Clamp(org.cardiacOutput or (pulseMultiplier * pulsePerfusionK), 0.05, 1.5)

		local coBreathePenalty = org.CO > 0 and (1 - math.Clamp(org.CO / 15, 0, 0.8)) or 1
		local coldO2RegenK = Lerp(coldO2Stress, 1, 0.55)
		local opioidBreathingK = math.Clamp(1 - drugRespiratoryDepression * 1.15, 0.05, 1)
		local roleO2RegenMul = hg.GetSubRolePerk and hg.GetSubRolePerk(owner, "O2RegenMul", 1) or 1
		local regenerate = regen * timeValue * 4 * circulationK * (mask_blevota and 0 or 1) * ((org.temperature > 38) and math.Clamp(math.Remap(org.temperature, 38, 41, 1, 0.1), 0.1, 1) or 1) * coldO2RegenK * altitudeO2K * coBreathePenalty * opioidBreathingK * roleO2RegenMul
		regenerate = regenerate * Lerp(cervicalOxygenLoss, 1, 0.12)
		-- Berserk repairs the airway and makes it immune to both the ongoing
		-- breathing deterioration below and its associated oxygen penalties.
		local berserkAirwayProtected = owner:IsBerserk()
		if berserkAirwayProtected then
			org.trachea = 0
			org.tracheaPath = nil
		end
		local tracheaDamage = berserkAirwayProtected and 0 or math.Clamp(org.trachea or 0, 0, 1)
		local tracheaIntakeK = 1 - (tracheaDamage * 0.15 + tracheaDamage * tracheaDamage * 0.55)
		regenerate = regenerate * math.Clamp(tracheaIntakeK, 0.3, 1)

		local coldO2Cap = o2.range * Lerp(coldO2Stress, 1, 0.7)
		-- Thin air reduces intake directly, while blood saturation falls more
		-- gradually than ambient pressure itself.
		local altitudeO2Cap = o2.range * Lerp(altitudeO2K, 0.5, 1)
		-- The reserve cap must follow remaining lung tissue as well as the intake
		-- rate above.  A small floor keeps a critically injured but not yet fully
		-- failed lung from snapping to zero in one tick.
		local lungO2Cap = o2.range * math.max(1 - org.pneumothorax * org.pneumothorax, 0.1) * math.max(1 - (org.hemothorax or 0) * (org.hemothorax or 0), 0.1) * math.max(1 - (org.lungsL[1] + org.lungsR[1]) / 2, 0.1)
		o2[1] = min(o2[1] + regenerate * math.Clamp(org.o2[1] / 30, 0.25, 1) * (org.holdingbreath and 0 or 1) * (sprayed and 0 or 1) * min((10 / max(org.CO,1)),1), min(lungO2Cap, bloodO2Cap, coldO2Cap, altitudeO2Cap, exertionO2Cap))



		-- Hypotension/low pulse are applied once through current cardiac output
		-- and the delivery cap below; do not drain tissue O2 a second time here.

		-- Trachea damage from breathing - damages trachea when breathing, more breathing = more damage

		-- Needle prevents trachea damage, only triggers when trachea > 0.65

		if not berserkAirwayProtected and org.trachea > 0.65 and org.trachea < 1.0 and org.needle <= 0 then

			local breatheAmount = regenerate * 0.008

			if breatheAmount > 0.005 then

				org.trachea = min(org.trachea + breatheAmount, 1)

			end

		end



		-- Trachea gradual deterioration from 0.5+ based on lung function (hyperventilating = more damage)

		if not berserkAirwayProtected and org.trachea >= 0.5 and org.trachea < 1.0 and org.needle <= 0 then

			local breatheIntensity = math.max((regenerate / math.max(timeValue, 0.001)) / (o2.regen or 4), 0.1) * math.Clamp((org.pulse or 70) / 70, 0.8, 2.0)

			local damageFactor = (org.trachea - 0.4) / 0.6

			org.trachea = min(org.trachea + timeValue * 0.06 * breatheIntensity * damageFactor, 1)

		end



		-- Any trachea damage leaks O2. Above 0.5 the airway becomes progressively
		-- lethal: intake is already weaker and O2 is lost increasingly quickly.
		if tracheaDamage > 0 then
			local lethalSeverity = math.Clamp((tracheaDamage - 0.5) / 0.5, 0, 1)
			local tracheaDrain = tracheaDamage * tracheaDamage * 0.25 + lethalSeverity * lethalSeverity * 1.2
			o2[1] = max(o2[1] - timeValue * tracheaDrain, 0)
		end



		-- Open central arteries reduce cerebral inflow locally. Their systemic
		-- effect is already represented by actual blood loss -> preload/output ->
		-- perfusion, so do not delete arterial O2 here as a second hemorrhage path.
		if org.arterialwounds then
			local centralImpairment = 0
			for _, wound in pairs(org.arterialwounds) do
				local artery = wound[7]
				local boneName = string.lower(tostring(wound[4] or ""))
				local isCerebralInflow = artery == "arteria"
					and (string.find(boneName, "neck", 1, true) or string.find(boneName, "head", 1, true) or string.find(boneName, "spine4", 1, true))
				if isCerebralInflow and (wound[1] or 0) > 0 then
					local held = org.manualHoldWound and org.manualHoldWoundArterial and org.manualHoldWoundTarget == wound
					local heldMul = held and 0.2 or 1
					centralImpairment = centralImpairment + heldMul
				end
			end

			local impairmentTarget = math.Clamp(centralImpairment, 0, 1)
			local impairmentNow = math.Clamp(org.arterialO2Impairment or 0, 0, 1)
			local impairmentRate = impairmentTarget > impairmentNow and timeValue / 18 or timeValue / 8
			org.arterialO2Impairment = math.Approach(impairmentNow, impairmentTarget, impairmentRate)
			org.arteriaO2Drain = false
			org.arterialO2Drain = false
		else
			org.arterialO2Impairment = math.Approach(org.arterialO2Impairment or 0, 0, timeValue / 8)
		end



		-- Trachea > 0.65: determine path once, then stick with it

		-- Needle prevents both

		if not berserkAirwayProtected and org.trachea > 0.65 and org.trachea < 1.0 and org.needle <= 0 and regenerate > 0 then

			-- First time above 0.65: choose path

			if not org.tracheaPath then

				org.tracheaPath = math.random() < 0.5 and "trachea" or "pneumothorax"

			end



			local damageSeverity = (org.trachea - 0.65) / 0.35

			local drainRate = regenerate * 0.003 * damageSeverity



			if org.tracheaPath == "trachea" then

				org.trachea = min(org.trachea + drainRate, 1)

			else

				org.pneumothorax = min(org.pneumothorax + drainRate * 0.5 * math.Clamp(org.conditionResistanceMul or 1, 0.05, 1), 1)

			end

		end



		o2.curregen = regenerate
		-- Downstream delivery values must only recover while the lungs are
		-- actually supplying oxygen. Keeping this separate from the stored O2
		-- pool prevents stale reserve from making vitals rebound after breathing
		-- has stopped.
		org.oxygenIntakeAvailable = regenerate > 0



		-- Struggling to catch breath: when curregen can't match O2 demand, extra drain from shallow breathing

		if o2.curregen >= 0 and o2.curregen < losing_oxy then

			local struggleRatio = 1 - (o2.curregen / losing_oxy)

			o2[1] = max(o2[1] - timeValue * struggleRatio * 0.65, 0)

		end

		if bradyapnea > 0 and not org.heartstop then
			o2[1] = max(o2[1] - timeValue * bradyapnea ^ 1.35 * 0.55, 0)
		end



		o2[1] = max(o2[1] - (org.CO > 0 and o2.curregen * 1.1 * (org.CO / 30) or 0),0)



		//org.owner:ResetNotification("oxygen_cantbreathe")

		//org.owner:ResetNotification("oxygen_cantbreathe2")

	else

		o2.curregen = 0
		org.oxygenIntakeAvailable = false

	end



	if owner:IsBerserk() and not org.heartstop then

		o2[1] = math.max(5, o2[1])

	end

	-- Tissue oxygen follows effective pump output and palpable pulse. This is
	-- the downstream low-blood path: poor filling lowers pulse/perfusion first,
	-- then the resulting delivery failure drains O2.
	local tissuePerfusion = math.min(
		math.Clamp(org.cardiacOutput or 1, 0, 1),
		math.Clamp((org.pulse or 0) / 70, 0, 1)
	)
	-- Tissue oxygen is a delivered value, not an independent reservoir. With no
	-- perfusion there is no delivery, so its cap must be zero as well.
	local perfusionO2Cap = o2.range * tissuePerfusion
	org.perfusionO2Cap = perfusionO2Cap
	-- Do not snap the current reserve to a new cap. A minor, short-lived change
	-- in cardiac output used to instantly delete O2 here, which made players
	-- pass out far too often. Intake is still capped above; an existing reserve
	-- now drains at a rate proportional to the actual delivery failure.
	local deliveryReserve = hg.organism.GetLimitingReserve(
		bloodO2Cap / o2.range,
		perfusionO2Cap / o2.range,
		exertionO2Cap / o2.range
	)
	local deliveryO2Cap = o2.range * deliveryReserve
	if o2[1] > deliveryO2Cap then
		local deliveryFailure = math.Clamp(1 - deliveryO2Cap / math.max(o2.range, 1), 0, 1)
		local decayRate = 0.16 + deliveryFailure * 0.45
		local deliveryResponse = 1 - math.exp(-timeValue * decayRate)
		o2[1] = o2[1] + (deliveryO2Cap - o2[1]) * deliveryResponse
	end

	-- Hemorrhage is already represented by carrying capacity and current cardiac
	-- output. Do not add another raw-blood/bleed/pulse drain on top of delivery.

	o2[1] = math.Clamp(o2[1], 0, o2.range)
	if org.heartstop then
		org.cardiacArrestO2Start = math.Clamp(org.cardiacArrestO2Start or o2[1], 0, o2.range)
		-- Arrest stops new delivery, but it does not erase already oxygenated tissue.
		-- Drain the captured reserve over the arrest window without snapping it to
		-- an arbitrary low cap first.
		o2[1] = min(o2[1], org.cardiacArrestO2Start)
		local arrestDrainRate = max(org.cardiacArrestO2Start, 0.1) / cardiacArrestO2DrainTime
		o2[1] = math.Approach(o2[1], 0, timeValue * arrestDrainRate)
	end

	

	if org.isPly and not org.otrub and not org.holdingbreath and o2.curregen < losing_oxy and org.analgesia <= 1.5 and !org.heartstop then

		if mask_blevota then

			if o2[1] < 15 then

				org.owner:Notify("DROP THE FUCKING MASK", 25, "take_gasmask2", 0, nil, color_red2)

			else

				org.owner:Notify(drop_mask[math.random(#drop_mask)], 15, "take_gasmask", 0)

			end

		else

			if o2[1] < 25 and o2[1] > 12 then

				org.owner:Notify(not_enough_intake[math.random(#not_enough_intake)], 61, "oxygen_lowintake", 3, oxygenIntakeThoughtExpired)

			end

		end



		-- The final warning band starts before severe hypoxia so the player gets
		-- a clear dying message while there is still a brief response window.
		if o2[1] <= 15 then





			notifyCriticalHypoxia(org)

		end

	end



	-- Barely breathing (low curregen but just enough) - 2nd priority, bypassed if choking

	if org.isPly and not org.otrub and not org.holdingbreath and not org.choking and o2.curregen >= losing_oxy and o2.curregen < losing_oxy * 1.3 and org.analgesia <= 1.5 and !org.heartstop then

		org.owner:Notify(barely_breathing[math.random(#barely_breathing)], 45, "barely_breathing", 2, barelyBreathingThoughtExpired)

	end



	-- Low stamina - 3rd priority, bypassed if choking

	if org.isPly and not org.otrub and not org.choking and staminaValue < 30 and org.analgesia <= 1.5 and !org.heartstop then

		org.owner:Notify(low_stamina[math.random(#low_stamina)], 50, "low_stamina", 3)

	end



	local analgesia = tonumber(org.analgesia) or 0
	local painkiller = tonumber(org.painkiller) or 0
	if analgesia > 1.5 or painkiller > 2.4 then

		org.owner:Notify(drugged[math.random(#drugged)], 30, "drugged", 0, nil, color_white)

	end

	-- Complete Judge's latest overdose path using this repository's existing
	-- respiration and blood-module owners. Accumulators make the effects scale
	-- with sustained dose without relying on tick-rate-dependent random rolls.
	if analgesia > 1.5 or painkiller > 2.4 then
		if org.isPly and org.alive then
			local overdose = analgesia + painkiller
			org.overdoseNausea = (org.overdoseNausea or 0) + timeValue * overdose * 0.08
			org.overdoseShit = (org.overdoseShit or 0) + timeValue * overdose * 0.05

			if org.overdoseNausea > 1.1 then
				org.overdoseNausea = 0
				hg.organism.Vomit(owner)
			end
			if org.overdoseShit > 2 then
				org.overdoseShit = 0
				hg.organism.Defecate(owner)
			end
		end
	else
		org.overdoseNausea = nil
		org.overdoseShit = nil
	end



	-- Lung function gating:
	-- * O2 at 0  -> tiny chance per tick of total lung failure
	-- * O2 > 0   -> only restore lung function if the airway/lungs are not
	--              catastrophically damaged. Previously this unconditionally
	--              flipped lungsfunction=true every tick which would resurrect
	--              breathing through destroyed lungs/trachea.
	if o2[1] == 0 then
		if math.random(50) == 1 then
			org.lungsfunction = false
		end
	else
		local lungsLost = (org.lungsL[1] or 0) >= 1 and (org.lungsR[1] or 0) >= 1
		local tracheaLost = (org.trachea or 0) >= 1
		if not (lungsLost or tracheaLost or org.heartstop or org.respiratoryArrest) then
			org.lungsfunction = true
		end
	end



	if (org.lungsL[1] == 1 and org.lungsR[1] == 1) or org.heartstop or org.respiratoryArrest or (org.hemothorax or 0) >= 0.9 then

		org.lungsfunction = false

	end



	if org.trachea >= 1.0 then

		org.lungsfunction = false

	end



	--[[if (pneumothorax or org.trachea >= 0.6 or org.lungsR[1] >= 0.6 or org.lungsL[1] >= 0.6) and org.alive and o2[1] > 0 then

		local timeSub = org.pneumothorax + org.trachea + org.lungsR[1] + org.lungsL[1]

		org.nextCough = org.nextCough and org.nextCough or (CurTime() + 5)

		

		if org.nextCough < CurTime() then

			org.nextCough = CurTime() + math.random(15,30 - timeSub + math.max(10 - o2[1],0))

			owner:EmitSound("homigrad/player/male/male_cough"..math.random(5)..".ogg",50 + Round(timeSub * 2.5))
kaz
		end

	end--]]



	if org.isPly then

		if org.pneumothorax > 0 then
			org.owner:Notify("I can feel something filling my lungs.", true, "pneumothorax1",10) // delay of 10 seconds before typing that
		else
			org.owner:ResetNotification("pneumothorax1")

			org.nextPneumothoraxNotify1 = nil

		end



		if org.pneumothorax > 0.3 then
			org.owner:Notify("It's getting harder to breathe.", true, "pneumothorax2", 5)
		else

			org.owner:ResetNotification("pneumothorax2")

			org.nextPneumothoraxNotify2 = nil

		end



		if org.pneumothorax > 0.5 then
			org.owner:Notify("I'm really struggling to breathe.", true, "pneumothorax3", 5)
		else

			org.owner:ResetNotification("pneumothorax3")

			org.nextPneumothoraxNotify3 = nil

		end



		-- Trachea damage notifications

		if org.trachea > 0.3 and org.trachea <= 0.6 then

			org.owner:Notify("My throat feels like it has a hole in it.", true, "trachea1", 15)

		else

			org.owner:ResetNotification("trachea1")

		end



		if org.trachea > 0.6 and org.trachea < 1.0 then

			org.owner:Notify("I can't get any air through my trachea...", true, "trachea2", 5)

		else

			org.owner:ResetNotification("trachea2")

		end



		if org.trachea >= 1.0 then

			org.owner:Notify("MY TRACHEA IS COMPLETELY DESTROYED!", true, "trachea_critical", 0, nil, color_red)

		else

			org.owner:ResetNotification("trachea_critical")

		end

	end



	local tissueO2 = math.Clamp(o2[1], 0, o2.range)
	local resilience = hg.organism.GetResilience and hg.organism.GetResilience(org) or 0
	local staminaMax = org.stamina and math.max(org.stamina.max or 180, 1) or 180
	local tissueFraction = tissueO2 / math.max(o2.range, 1)
	local tissueHypoxia = math.Clamp((0.84 - tissueFraction) / 0.84, 0, 1)
	local healthFraction = IsValid(owner) and math.Clamp(owner:Health() / math.max(owner:GetMaxHealth(), 1), 0, 1) or 1
	local lowHealthHypoxia = math.Clamp((0.55 - healthFraction) / 0.55, 0, 1)
	local functionalLoss = math.max(tissueHypoxia, lowHealthHypoxia) ^ (1.45 + resilience * 0.35)
	if functionalLoss > 0 then
		org.disorientation = math.max(org.disorientation or 0, functionalLoss * 1.4)
		org.immobilization = math.max(org.immobilization or 0, functionalLoss ^ 1.35 * 6)
		if org.stamina and org.stamina[1] then
			org.stamina[1] = math.max(org.stamina[1] - timeValue * functionalLoss ^ 1.2 * staminaMax / 55, 0)
		end
		-- Tissue hypoxia disables posture and movement. It never requests OTRUB;
		-- that decision is made from brainoxygen in UpdatePerfusion.
		if functionalLoss > 0.62 then org.needfake = true end
		if org.isPly and functionalLoss > 0.72 then hg.LightStunPlayer(owner, 3) end
	end



	if org.lungsR[1] < 0.5 then

		//org.lungsR[1] = max(org.lungsR[1] - timeValue / 240, 0)

	end



	if org.lungsL[1] < 0.5 then

		//org.lungsL[1] = max(org.lungsL[1] - timeValue / 240, 0)

	end



	if owner:IsBerserk() then

		org.brain = math.min(0.5, org.brain)

	end



	local frontal = org.brainFrontal or 0
	local parietal = org.brainParietal or 0
	local temporal = org.brainTemporal or 0
	local occipital = org.brainOccipital or 0
	local hemorrhage = org.brainHemorrhage or 0
	local bleedRate = org.brainBleedRate or 0
	local zerlkersResistance = hg.organism.GetZerlkersResistance and hg.organism.GetZerlkersResistance(org) or 0

	-- Mannitol is the main emergency treatment here: it rapidly lowers edema
	-- and bleeding pressure so recoverable brain trauma can stabilize before it
	-- reaches the fatal damage path. Tranexamic acid remains useful as a slower
	-- direct bleed stabilizer.
	local mannitolK = math.Clamp((org.mannitol or 0) / 4, 0, 1)
	if (org.tranexamic_acid or 0) > 0 then
		bleedRate = max(bleedRate - timeValue / 60000, 0)
		org.brainBleedRate = bleedRate
	end
	if mannitolK > 0 then
		bleedRate = max(bleedRate - timeValue * (1 / 180) * mannitolK, 0)
		org.brainBleedRate = bleedRate
	end

	local hemorrhageReliefRate = 0
	if mannitolK > 0 then hemorrhageReliefRate = hemorrhageReliefRate + (1 / 110) * mannitolK end
	if (org.tranexamic_acid or 0) > 0 then hemorrhageReliefRate = hemorrhageReliefRate + 1 / 1200 end

	local skullDamage = math.Clamp(tonumber(org.skull) or 0, 0, 1)
	if skullDamage >= 0.4 then
		local fractureSeverity = math.Clamp((skullDamage - 0.4) / 0.6, 0, 1)
		local dressingMul = org.bandagedskull and 0.22 or 1
		local medicationMul = (1 - mannitolK * 0.4) * ((org.tranexamic_acid or 0) > 0 and 0.65 or 1)
		local resistanceMul = 1 - zerlkersResistance * 0.75
		local ruptureRate = (0.00015 + fractureSeverity * fractureSeverity * 0.0032)
			* dressingMul * medicationMul * resistanceMul
		local ruptureChance = 1 - math.exp(-ruptureRate * math.max(timeValue, 0))
		if math.Rand(0, 1) < ruptureChance then
			local amount = math.Rand(0.006, 0.018) * Lerp(fractureSeverity, 0.45, 1)
			local rate = math.Rand(0.00004, 0.00018) * Lerp(fractureSeverity, 0.5, 1)
			if hg.organism.AddBrainHemorrhage then
				hg.organism.AddBrainHemorrhage(org, amount, rate)
			else
				org.brainHemorrhage = math.min((org.brainHemorrhage or 0) + amount, 1)
				org.brainBleedRate = math.min((org.brainBleedRate or 0) + rate, 0.008)
			end
		end
	end
	hemorrhage = org.brainHemorrhage or hemorrhage
	bleedRate = org.brainBleedRate or bleedRate

	org.disorientation = math.max(org.disorientation, frontal * 0.35 + parietal * 0.65 + temporal * 0.25)
	org.immobilization = math.max(org.immobilization, parietal * 8)
	org.consciousness = math.min(org.consciousness, 1 - frontal * 0.35 - temporal * 0.15)
	if hemorrhage > 0 then
		org.brain = min(org.brain + timeValue * hemorrhage / (hemorrhage < 0.3 and 900 or 300), 1)
		org.disorientation = math.max(org.disorientation, hemorrhage * 0.9)
		org.consciousness = math.min(org.consciousness, 1 - hemorrhage * 0.45)
		org.painadd = math.min((org.painadd or 0) + timeValue * hemorrhage * 4, 150)
	end

	if hg.organism.AddSeizure and temporal > 0.2 then
		hg.organism.AddSeizure(org, timeValue * temporal / 1200)
	end

	if bleedRate > 0 then
		local traumaProgression = 1 - zerlkersResistance * 0.55
		local cranialDamage = math.Clamp(math.max(org.brain or 0, org.skull or 0, hemorrhage), 0, 1)
		-- The source accumulates gradually.  Its danger ramps with existing cranial
		-- damage and trapped blood, rather than making a small fresh bleed fatal in
		-- seconds.  Severe/open-skull trauma still escalates rapidly if untreated.
		local hemorrhageRate = 0.25 + cranialDamage * 0.65
		local brainDamageRate = 0.35 + cranialDamage * 1.65
		org.brainHemorrhage = min(hemorrhage + timeValue * bleedRate * hemorrhageRate * traumaProgression, 1)
		org.brain = min(org.brain + timeValue * bleedRate * brainDamageRate * traumaProgression, 1)
		org.brainBleedRate = max(bleedRate - timeValue / 600000, 0)
	end

	if hemorrhageReliefRate > 0 and (org.brainHemorrhage or 0) > 0 then
		org.brainHemorrhage = max(org.brainHemorrhage - timeValue * hemorrhageReliefRate, 0)
	end
	if mannitolK > 0 then
		local mannitolBrainRecovery = timeValue * (1 / 170) * mannitolK
		org.brain = max(org.brain - mannitolBrainRecovery, 0)
		org.brainFrontal = max(frontal - mannitolBrainRecovery, 0)
		org.brainParietal = max(parietal - mannitolBrainRecovery, 0)
		org.brainTemporal = max(temporal - mannitolBrainRecovery, 0)
		org.brainOccipital = max(occipital - mannitolBrainRecovery, 0)
	end

	if occipital > 0.35 then
		org.disorientation = math.max(org.disorientation, occipital * 0.4)
	end

	if org.skull < 1 and org.skull > 0 and org.bandagedskull then

		org.skull = math.Approach(org.skull, 0, timeValue / 600)

	end



	if org.brain >= 0.5 and not (hg.organism.IsBrainDamageIgnored and hg.organism.IsBrainDamageIgnored(org)) then
		if org.brain >= 0.5 and (mannitolK <= 0 or (org.brainHemorrhage or 0) >= 0.85) then
			if math.random(60) == 1 then
				org.heartstop = true
			end
		end

		local brainCap = 0.325
		local brainSeverity = math.Clamp((org.brain - brainCap) / (1 - brainCap), 0.1, 1)
		org.consciousness = math.max((org.consciousness or 1) - timeValue * brainSeverity * 0.6, 0)
	end

	local death_from_braindamage = false

	if org.brain >= 0.7 and org.alive then

		death_from_braindamage = true
		if hg.organism.KillFatalBrainDamage then
			hg.organism.KillFatalBrainDamage(org)
			return
		end
		org.alive = false
	end

	if org.isPly then

		if org.brain > 0.1 and org.brain < 0.3 then
			org.owner:Notify(math.random(2) == 1 and "My head hurts..." or "Where am I?", true, "brain", 5)
		else

			org.owner:ResetNotification("brain") 

		end

	end



	local brainRecovery = timeValue / 400 * ((mannitolK > 0 and org.brain < 0.6) and 1 or (org.brain > 0.1 and 0.1 or 0))
	org.brain = max(org.brain - brainRecovery, 0)
	if mannitolK > 0 then
		org.brainFrontal = max(org.brainFrontal - brainRecovery, 0)
		org.brainParietal = max(org.brainParietal - brainRecovery, 0)
		org.brainTemporal = max(org.brainTemporal - brainRecovery, 0)
		org.brainOccipital = max(org.brainOccipital - brainRecovery, 0)
	end

	org.mannitol = math.Approach(org.mannitol, 0, timeValue / 200)
	
	-- Tissue oxygen no longer writes brain injury. Intracranial bleeding remains
	-- damaging here; cerebral hypoxia is handled from brainoxygen in UpdatePerfusion.
	local hemorrhageInjury = math.Clamp(org.brainHemorrhage or 0, 0, 1)
	if hemorrhageInjury > 0 then
		local injuryTime = org.brain < 0.3 and 300 or 120
		org.brain = min(org.brain + timeValue / injuryTime * hemorrhageInjury, 1)
	end

end
