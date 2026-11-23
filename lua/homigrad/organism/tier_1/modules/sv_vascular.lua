local Clamp, Remap, CurTime = math.Clamp, math.Remap, CurTime

local function remapClamped(value, a, b)
	return Clamp(Remap(value, a, b, 0, 1), 0, 1)
end

local function notify(org, text, id)
	if org.isPly and IsValid(org.owner) and org.owner.Notify and not org.otrub then
		org.owner:Notify(text, true, id, 6)
	end
end

function hg.organism.AdministerStreptokinase(org, dose)
	dose = tonumber(dose) or 0
	if not org or dose <= 0 then return false end
	org.streptokinase = math.min((tonumber(org.streptokinase) or 0) + dose, 2)
	return true
end

function hg.organism.GetStreptokinase(org)
	return Clamp(tonumber(org.streptokinase) or 0, 0, 2)
end

function hg.organism.ResetVascularEvents(org)
	org.streptokinase = 0
	org.clotBurden = 0
	org.pulmonaryEmbolism = 0
	org.aneurysm = 0
	org.vascularPressureK = 0
	org.nextVascularRoll = 0
	org.streptokinaseFaintNotified = nil
end

local function getPressureLoad(org)
	local heartbeat = tonumber(org.heartbeat) or 70
	return Clamp(math.max(
		remapClamped(tonumber(org.bloodPressure) or 90, 105, 145),
		remapClamped(tonumber(org.systolic) or 120, 150, 210),
		Clamp(tonumber(org.hypertension) or 0, 0, 1),
		Clamp(tonumber(org.hypertensiveEmergency) or 0, 0, 1)
	) + remapClamped(heartbeat, 150, 230) * 0.3, 0, 1)
end

local function hasAtrialFibrillation(org)
	return org.ecgState == "atrial_fibrillation" or org.unstableRhythm == "atrial_fibrillation"
end

local function triggerPulmonaryEmbolism(org, burden)
	org.pulmonaryEmbolism = math.min((tonumber(org.pulmonaryEmbolism) or 0) + 0.35 + burden * 0.4, 1)
	org.clotBurden = burden * 0.5
	org.painadd = (org.painadd or 0) + 15
	notify(org, "Sharp pain in my chest... I can't catch my breath.", "pulmonary_embolism")
end

local function triggerIschemicStroke(org, burden)
	org.brain = math.min((org.brain or 0) + 0.04 + burden * 0.14, 1)
	org.disorientation = math.max(org.disorientation or 0, 2 + burden * 3)
	if math.Rand(0, 1) < 0.3 + burden * 0.4 then hg.organism.AddSeizure(org, 1) end
	org.clotBurden = burden * 0.6
	notify(org, "Half my face feels numb... the world is tilting.", "ischemic_stroke")
end

local function ruptureAneurysm(org, sk)
	local aneurysm = Clamp(tonumber(org.aneurysm) or 0, 0, 1)
	local bleedMul = 1 + sk * 0.5
	if math.Rand(0, 1) < 0.6 then
		if hg.organism.AddBrainHemorrhage then
			hg.organism.AddBrainHemorrhage(org, (0.12 + aneurysm * 0.15) * bleedMul, (0.002 + aneurysm * 0.003) * bleedMul)
		else
			org.brainHemorrhage = math.min((org.brainHemorrhage or 0) + (0.12 + aneurysm * 0.15) * bleedMul, 1)
			org.brainBleedRate = math.min((org.brainBleedRate or 0) + (0.002 + aneurysm * 0.003) * bleedMul, 0.008)
		end
		org.brain = math.min((org.brain or 0) + 0.08 + aneurysm * 0.12, 1)
		if math.Rand(0, 1) < 0.6 then hg.organism.AddSeizure(org, 1) end
		notify(org, "The worst headache of my life just hit me.", "aneurysm")
	else
		org.internalBleed = (tonumber(org.internalBleed) or 0) + (6 + aneurysm * 8) * bleedMul
		org.painadd = (org.painadd or 0) + 40
		notify(org, "Something tore deep in my gut... tearing pain into my back.", "aneurysm")
	end
	org.aneurysm = aneurysm * 0.2
end

function hg.organism.UpdateVascularEvents(owner, org, timeValue)
	if org.simpleMode or not org.alive then return end

	local sk = hg.organism.GetStreptokinase(org)
	if sk > 0 then
		org.streptokinase = math.max(sk - timeValue / 240, 0)
		org.tranexamic_acid = math.max((tonumber(org.tranexamic_acid) or 0) - timeValue * sk * 0.08, 0)
		org.internalBleedHeal = math.max((tonumber(org.internalBleedHeal) or 0) - timeValue * sk * 0.08, 0)
		org.strokeExposure = math.max((tonumber(org.strokeExposure) or 0) - timeValue * sk / 30, 0)
	end
	local lysis = Clamp(sk, 0, 1)

	local txa = Clamp((tonumber(org.tranexamic_acid) or 0) / 10, 0, 1)
	if txa > 0 then
		org.tranexamic_acid = math.max(org.tranexamic_acid - timeValue * 0.01, 0)
	end

	local pressureK = getPressureLoad(org)
	org.vascularPressureK = pressureK
	local heartbeat = tonumber(org.heartbeat) or 70

	local burdenTarget = txa * 0.55 + pressureK * 0.3
		+ (hasAtrialFibrillation(org) and 0.4 or 0)
		+ remapClamped(50 - heartbeat, 0, 20) * 0.15
		+ Clamp(tonumber(org.hypervolemia) or 0, 0, 1) * 0.15
	burdenTarget = Clamp(burdenTarget * (1 - lysis * 0.9) * hg.organism.TraitMul(org, "clot_burden", 1), 0, 1)
	local burden = Clamp(tonumber(org.clotBurden) or 0, 0, 1)
	local burdenRate = burdenTarget > burden and timeValue / 120 or timeValue / (lysis > 0 and 15 or 90)
	burden = math.Approach(burden, burdenTarget, burdenRate)
	org.clotBurden = burden

	local pe = Clamp(tonumber(org.pulmonaryEmbolism) or 0, 0, 1)
	if pe > 0 then
		pe = math.max(pe - timeValue * (1 / 600 + sk / 25), 0)
		org.pulmonaryEmbolism = pe
		org.heartStrain = Clamp((org.heartStrain or 0) + timeValue * pe * pe / 150, 0, 1)
	end

	local aneurysm = Clamp(tonumber(org.aneurysm) or 0, 0, 1)
	if pressureK > 0.35 then
		aneurysm = math.min(aneurysm + timeValue * (pressureK - 0.35) / 150, 1)
	elseif pressureK < 0.2 then
		aneurysm = math.max(aneurysm - timeValue / 600, 0)
	end
	org.aneurysm = aneurysm

	if sk > 0.2 and (tonumber(org.hypertension) or 0) < 0.2 and (tonumber(org.hypertensiveEmergency) or 0) < 0.1 then
		local faint = remapClamped(84 - (tonumber(org.bloodPressure) or 90), 0, 16)
		if faint > 0 then
			org.disorientation = math.max(org.disorientation or 0, 0.4 + faint * 1.6)
			if not org.streptokinaseFaintNotified then
				org.streptokinaseFaintNotified = true
				notify(org, "I feel lightheaded... like I'm about to faint.", "streptokinase")
			end
		end
	elseif sk <= 0 then
		org.streptokinaseFaintNotified = nil
	end

	local now = CurTime()
	if (org.nextVascularRoll or 0) > now then return end
	org.nextVascularRoll = now + 5
	local riskMul = Clamp(org.conditionResistanceMul or 1, 0.05, 1)

	if burden > 0.3 and math.Rand(0, 1) < (burden - 0.3) ^ 1.5 * 0.05 * riskMul then
		if math.Rand(0, 1) < 0.65 then
			triggerPulmonaryEmbolism(org, burden)
		else
			triggerIschemicStroke(org, burden)
		end
	end

	if aneurysm > 0.4 and math.Rand(0, 1) < (aneurysm - 0.4) / 0.6 * (0.3 + pressureK * 0.7) * 0.06 * riskMul then
		ruptureAneurysm(org, sk)
	end

	pe = Clamp(tonumber(org.pulmonaryEmbolism) or 0, 0, 1)
	if pe > 0.75 and not org.heartstop and math.Rand(0, 1) < (pe - 0.75) * 0.08 * riskMul then
		hg.organism.StartFibrillation(org)
	end
end
