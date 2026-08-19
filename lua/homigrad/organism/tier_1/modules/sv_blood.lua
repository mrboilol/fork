local CurTime = CurTime
local time
local max, min, Round = math.max, math.min, math.Round
--local Organism = hg.organism
hg.organism.module.blood = {}
local module = hg.organism.module.blood
local hg_infections = ConVarExists("hg_infections") and GetConVar("hg_infections") or CreateConVar("hg_infections",1,FCVAR_ARCHIVE + FCVAR_NOTIFY,"Enable infections system",0,1)

hg.organism.bloodtypes = {
	["o-"] = {["o-"] = true,["o+"] = true,["a-"] = true,["a+"] = true,["b-"] = true,["b+"] = true,["ab-"] = true,["ab+"] = true},
	["o+"] = {["o+"] = true,["a+"] = true,["b+"] = true,["ab+"] = true},
	["a-"] = {["a+"] = true,["a-"] = true,["ab+"] = true,["ab-"] = true},
	["a+"] = {["a+"] = true,["ab+"] = true},
	["b-"] = {["b+"] = true,["b-"] = true,["ab+"] = true,["ab-"] = true},
	["b+"] = {["b+"] = true,["ab+"] = true},
	["ab-"] = {["ab+"] = true,["ab-"] = true},
	["ab+"] = {["ab+"] = true},
	["c-"] = {["c-"] = true,["o-"] = true,["o+"] = true,["a-"] = true,["a+"] = true,["b-"] = true,["b+"] = true,["ab-"] = true,["ab+"] = true},
}

module[1] = function(org)
	org.blood = hg.organism.normalBloodVolume or 5000
	org.bleed = 0
	org.venousBleed = 0
	org.arterialBleed = 0
	-- Live per-wound rates let clients draw the blood actually being lost after
	-- clotting, adrenaline, pressure, and tourniquet effects are applied.
	org.woundBleedRates = {}
	org.arterialWoundBleedRates = {}
	org.internalBleedRate = 0
	org.internalBleed = 0
	org.internalBleedHeal = 0
	org.arteria = 0
	org.rarmartery = 0
	org.larmartery = 0
	org.rlegartery = 0
	org.llegartery = 0
	org.spineartery = 0
	org.bleedStart = 0
	org.wounds = {}
	org.arterialwounds = {}
	org.holdWound = nil
	org.holdWoundArterial = nil
	org.wantToVomit = 0
	org.vomitInThroat = nil

	org.bloodtype = table.GetKeys(hg.organism.bloodtypes)[math.random(8)]
	
	if org.bloodtype == "c-" then
		org.bloodtype = "o-" --эпик
	end

	org.hemotransfusionshock = 0
	org.ischemia = 0
	org.internalBleedDuration = 0
	org.internalBleedPeak = 0
	org.internalBleedComplication = 0
	org.internalBleedComplicationDelay = 90
	org.internalBleedHemothoraxRoll = nil
	org.internalBleedHemothoraxRisk = false
	org.internalBleedThoughtLevel = 0
	org.nextInternalBleedThought = 0

	org.survivalchance = 1
	org.hemothorax = 0
	org.hemothoraxTrauma = 0
	org.hemothoraxL = 0
	org.hemothoraxR = 0
	org.cardiacTamponade = 0
	org.lastBleedTime = CurTime()
	org.arterialO2Drain = false
	org.arterialO2Impairment = 0
	org.throatcut = false
	org.throatCutTime = 0
	org.throatCutUntil = 0
	org.throatCutSeverity = 0
	org.throatCutPressureShock = 0
end

local about_to_puke = {
	"I feel like I'm gonna puke any second now...",
	"Not feeling good...",
	"Gonna puke right now...",
	"I want to vomit...",
}

local internalBleedThoughts = {
	"Something inside me is bleeding.",
	"That hit did something bad inside.",
	"I can feel blood pooling inside me.",
	"I'm bleeding internally. I need treatment.",
	"Something ruptured inside me.",
}

local vecZero = Vector(0, 0, 0)
local limbArteryWeakness = {
	rarmartery = {limb = "rarm", damage = 0.65},
	larmartery = {limb = "larm", damage = 0.65},
	rlegartery = {limb = "rleg", damage = 0.7},
	llegartery = {limb = "lleg", damage = 0.7},
}

local o2DebuffArteries = {
	-- Legacy state flags only; oxygen delivery is derived elsewhere.
	arteria = true,
	spineartery = true,
}

local arteryStatusKeys = {
	"arteria",
	"rarmartery",
	"larmartery",
	"rlegartery",
	"llegartery",
	"spineartery",
}

function hg.organism.RebuildArteryWoundState(org, syncNow)
	if not org then return end

	local active = {}
	for _, wound in pairs(org.arterialwounds or {}) do
		local artery = wound and wound[7]
		if artery and (wound[1] or 0) > 0 then
			active[artery] = true
		end
	end

	for _, artery in ipairs(arteryStatusKeys) do
		org[artery] = active[artery] and 1 or 0
	end

	org.arteriaO2Drain = active.arteria and true or false
	org.arterialO2Drain = false
	for artery in pairs(o2DebuffArteries) do
		if active[artery] then
			org.arterialO2Drain = true
			break
		end
	end

	local owner = org.owner
	if IsValid(owner) then
		hg.organism.SyncWounds(org)

		if syncNow and hg.send_organism then
			hg.send_organism(org, owner)
		end
	end
end

local hold_wound_size_threshold = 4
local hold_wound_pain_threshold = 72
local hold_wound_painadd_threshold = 8
local hold_wound_bleed_threshold = 0.35
local hold_wound_bleed_slow_mul = 0.72
local hold_wound_bleed_slow_twohand_mul = 0.55
local hold_wound_arterial_slow_mul = 0.2
local hold_wound_clot_mul = 1.35
local hold_wound_clot_twohand_mul = 1.6
-- Wounds must threaten the larger survivable blood-loss reserve quickly enough
-- that several cuts or an untreated gunshot still demand immediate treatment.
-- Coagulation, wound pressure, tourniquets, and adrenaline continue to modify
-- these rates normally rather than being bypassed by an instant-loss shortcut.
local wound_bleed_rate_mul = 2.25
local arterial_bleed_rate_mul = 1.35
-- An amputated limb must remain an urgent arterial bleed.  This is lower than
-- the old runaway jet, but high enough to be clearly visible and dangerous
-- until the stump is controlled.
local amputation_arterial_bleed_mul = (hg.organism.config and hg.organism.config.ARTERIAL_AMPUTATION_BLEED_MULTIPLIER) or 0.65
local headgib_arterial_bleed_mul = (hg.organism.config and hg.organism.config.ARTERIAL_HEADGIB_BLEED_MULTIPLIER) or 1.65

local function hasWound(wounds, target)
	if not target or not wounds then return false end

	for i, wound in pairs(wounds) do
		if wound == target then
			return true
		end
	end

	return false
end

local function getLargestWound(wounds)
	local best
	local bestSize = 0

	for i, wound in pairs(wounds or {}) do
		local size = wound[1] or 0
		if size > bestSize then
			best = wound
			bestSize = size
		end
	end

	return best, bestSize
end

local function updateHoldWound(org)
	local arteryWound = getLargestWound(org.arterialwounds)
	if arteryWound then
		org.holdWound = arteryWound
		org.holdWoundArterial = true
		return
	end

	if org.holdWoundArterial then
		org.holdWound = nil
		org.holdWoundArterial = nil
	end

	if org.holdWound and hasWound(org.wounds, org.holdWound) then
		return
	end

	org.holdWound = nil
	org.holdWoundArterial = nil

	local wound, woundSize = getLargestWound(org.wounds)
	if not wound then return end

	local intensePain = org.pain >= hold_wound_pain_threshold or org.painadd >= hold_wound_painadd_threshold
	local profuseBleeding = org.bleed >= hold_wound_bleed_threshold

	if woundSize >= hold_wound_size_threshold and (intensePain or profuseBleeding) then
		org.holdWound = wound
		org.holdWoundArterial = false
	end
end

local function getHeldWoundBleedMul(org, wound)
	if not org.manualHoldWound or org.manualHoldWoundTarget != wound then return 1 end

	if org.manualHoldWoundArterial then
		return hold_wound_arterial_slow_mul
	end

	if (org.manualHoldWoundHands or 0) >= 2 then
		return hold_wound_bleed_slow_twohand_mul
	end

	return hold_wound_bleed_slow_mul
end

local function getHeldWoundClotMul(org, wound)
	if not org.manualHoldWound or org.manualHoldWoundTarget != wound then return 1 end

	if (org.manualHoldWoundHands or 0) >= 2 then
		return hold_wound_clot_twohand_mul
	end

	return hold_wound_clot_mul
end

module[2] = function(owner, org, mulTime)
	local adrenaline = math.Clamp(org.adrenaline or 0, 0, 2)
	local isPlayer = owner:IsPlayer()
	-- sv_liver owns the continuous base modifiers. These fallbacks only protect
	-- hot reloads or unusual construction order before its first tick.
	org.coagulation_multiplier = tonumber(org.coagulation_multiplier) or 1.2
	org.blood_regeneration_multiplier = tonumber(org.blood_regeneration_multiplier) or 1.2
	org.bleedingmul = tonumber(org.bleedingmul) or 0.8

	-- Internal bleeding increases external wound bleeding rate
	if org.internalBleed > 0 then
		org.bleedingmul = org.bleedingmul * (1 + org.internalBleed * 0.15)
	end

	if org.vomitInThroat then
		local ent = hg.GetCurrentCharacter(owner)
		
		local bon = "ValveBiped.Bip01_Head1"
		local bone = ent:LookupBone(bon)
		local mat = ent:GetBoneMatrix(bone)
	
		if mat and mat:GetAngles():Right()[3] < 0.25 then
			org.vomitInThroat = nil

			net.Start("bloodsquirt2")
			net.WriteEntity(ent)
			net.WriteString(bon)
			net.WriteMatrix(mat)
			net.WriteVector(mat:GetTranslation() + mat:GetAngles():Right() * 6 + mat:GetAngles():Forward() * 1)
			net.WriteVector(mat:GetAngles():Right() * 2 * math.Clamp(org.pulse / 70, 0.4, 1))
			net.Broadcast()

			ent:EmitSound("vomit/vomit5.ogg")
		end
	end

	if org.isPly and not org.otrub and (hg.organism.GetResilientBlood and hg.organism.GetResilientBlood(org) or org.blood) < 2900 then org.owner:Notify(math.random(2) == 1 and "I cant feel anything..." or (math.random(2) == 1 and "I think I'm gonna faint right now...") or "I dont feel so good...",true,"blood2",0,nil,Color(200, 170, 170)) end

	if org.internalBleed < 0.5 and org.bleed <= 0 and org.pulse > 5 then
		-- Slow game-scaled recovery. Do not refill hundreds of mL per minute simply
		-- because bleeding has stopped.
		local regenRate = (hg.organism.config and hg.organism.config.BLOOD_REGEN_RATE_ML_S) or 0.5
		org.blood = min(org.blood + mulTime * regenRate, hg.organism.normalBloodVolume or 5000)
	end

	local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
	local adrenalineStabilizer = totalAdrenaline > 0.2
	local hasAntiIschemia = (org.tranexamic_acid or 0) > 0 or (org.thiamine or 0) > 0

	if org.hemotransfusionshock > 0 then
		org.hemotransfusionshock = math.max(org.hemotransfusionshock - mulTime / 150,0)
		org.internalBleed = org.internalBleed + mulTime / 20
		if not adrenalineStabilizer and not hasAntiIschemia then
			org.ischemia = org.ischemia + mulTime / 15
		end
	end

	if org.arterialwounds and #org.arterialwounds > 0 then
		for _, wound in pairs(org.arterialwounds) do
			local artery = wound[7]
			if wound[1] and wound[1] > 0 then
				local weakness = limbArteryWeakness[artery]
				if weakness and not org[weakness.limb .. "amputated"] then
					org[weakness.limb] = math.max(org[weakness.limb] or 0, weakness.damage)
				end
			end
		end
	end

	-- Internal bleeding has a delayed complication curve. The worst severity in
	-- the current episode owns the grace period, so a catastrophic bleed can
	-- begin compromising circulation quickly while a small persistent bleed
	-- takes much longer to become dangerous.
	local internalBleedSeverity = math.max(tonumber(org.internalBleed) or 0, 0)
	local internalThoughtLevel = internalBleedSeverity >= 3 and 3 or internalBleedSeverity >= 1.5 and 2 or internalBleedSeverity > 0.75 and 1 or 0
	if internalThoughtLevel > 0 and org.isPly and IsValid(owner) and not org.otrub then
		if internalThoughtLevel > (org.internalBleedThoughtLevel or 0) and (org.nextInternalBleedThought or 0) <= CurTime() then
			owner:Notify(internalBleedThoughts[math.random(#internalBleedThoughts)], 30, "internalbleed", 0, nil, Color(220, 170, 170))
			org.internalBleedThoughtLevel = internalThoughtLevel
			org.nextInternalBleedThought = CurTime() + 30
		end
	elseif internalBleedSeverity <= 0.05 then
		org.internalBleedThoughtLevel = 0
	end

	if internalBleedSeverity > 0.05 then
		org.internalBleedDuration = (org.internalBleedDuration or 0) + mulTime
		org.internalBleedPeak = math.max(org.internalBleedPeak or 0, internalBleedSeverity)

		local severityK = math.Clamp(((org.internalBleedPeak or 0) - 0.2) / 2.8, 0, 1)
		-- Internal injuries must have time to develop consequences. Moderate
		-- untreated bleeding can progress into shock, while catastrophic trauma
		-- deteriorates much faster.
		local complicationDelay = Lerp(severityK, 45, 5)
		local progressionTime = Lerp(severityK, 105, 18)
		local severityLimit = math.Clamp((org.internalBleedPeak or 0) / 2, 0.1, 1)
		local complicationTarget = math.Clamp(((org.internalBleedDuration or 0) - complicationDelay) / progressionTime, 0, 1) * severityLimit

		org.internalBleedComplicationDelay = complicationDelay
		org.internalBleedComplication = math.Approach(org.internalBleedComplication or 0, complicationTarget, mulTime / progressionTime)

		-- An abdominal/internal bleed only reaches the pleural space as a rare
		-- catastrophic complication. Roll once after the episode becomes severe;
		-- routine and moderate internal bleeding cannot create a hemothorax.
		if (org.internalBleedPeak or 0) >= 4 then
			if org.internalBleedHemothoraxRoll == nil then
				org.internalBleedHemothoraxRoll = math.Rand(0, 1)
			end
			local incidentalHemothoraxChance = math.Clamp(((org.internalBleedPeak or 0) - 4) / 8, 0, 1) * 0.08
			org.internalBleedHemothoraxRisk = org.internalBleedHemothoraxRoll <= incidentalHemothoraxChance
		else
			org.internalBleedHemothoraxRisk = false
		end
	else
		org.internalBleedDuration = 0
		org.internalBleedPeak = 0
		org.internalBleedComplicationDelay = 90
		org.internalBleedComplication = math.Approach(org.internalBleedComplication or 0, 0, mulTime / 90)
		org.internalBleedHemothoraxRoll = nil
		org.internalBleedHemothoraxRisk = false
	end

	-- Severe internal bleeding can still compromise the pericardium. Pleural
	-- accumulation is owned by sv_lungs so it has one progression path.
	local thoracicSeverity = math.Clamp(internalBleedSeverity / 5, 0, 1)
	local thoracicComplication = thoracicSeverity * (org.internalBleedComplication or 0)
	local tamponadeTarget = thoracicComplication * math.Clamp((internalBleedSeverity - 2.5) / 7.5, 0, 1) * 0.65
	org.cardiacTamponade = math.max(org.cardiacTamponade or 0, math.Approach(org.cardiacTamponade or 0, tamponadeTarget, mulTime / 24))

	-- Nosebleed from severe internal bleeding
	if org.internalBleed > 0.75 and hg.applyNosebleed and math.random() < org.internalBleed * 0.02 * mulTime then
		hg.applyNosebleed(owner, org.internalBleed * 8)
	end

	-- Hemorrhagic symptoms use the same preload reserve as cardiac output. This
	-- keeps compensation, shock, pressure and oxygen delivery on one curve.
	local tempMul = math.Clamp(((org.temperature < 30 and org.temperature - 30 or 0) * 0.25 + 1), 0.25, 1)
	local blood = math.max(tonumber(org.blood) or 5000, 0)
	local preloadReserve = hg.organism.GetBloodDeliveryFraction and hg.organism.GetBloodDeliveryFraction(blood, 1)
		or math.Clamp(blood / (hg.organism.normalBloodVolume or 5000), 0, 1)
	local reserveLoss = 1 - preloadReserve
	local criticalReserve = math.Clamp((hg.organism.config and hg.organism.config.CRITICAL_CIRCULATION_RESERVE) or 0.62, 0.1, 0.95)
	local normalBlood = math.max((hg.organism.config and hg.organism.config.NORMAL_BLOOD_VOLUME_ML) or 5000, 1)
	local rawLossFraction = math.Clamp(1 - blood / normalBlood, 0, 1)
	-- Subtle weakness begins with the first real loss. Catastrophic shock is still
	-- derived below from preload reserve, so this does not create an early death band.
	local symptomaticLoss = rawLossFraction ^ 1.10
	local decompensation = math.Clamp((criticalReserve - preloadReserve) / criticalReserve, 0, 1) ^ 1.35
	local compensationDemand = hg.organism.GetHemorrhageCompensationDrive and hg.organism.GetHemorrhageCompensationDrive(blood)
		or math.Clamp(reserveLoss / math.max(1 - criticalReserve, 0.05), 0, 1)

	org.hypovolemia = symptomaticLoss
	org.hemorrhageCompensation = compensationDemand * (1 - decompensation)
	org.hypovolemicShock = decompensation
	org.lowBloodTemperatureTarget = 36.7 - reserveLoss ^ 1.4 * 3.2
	org.disorientation = math.max(org.disorientation or 0, symptomaticLoss ^ 1.25 * 6)

	-- Hypovolemic stress stays below the generic shock-LOC threshold. Pressure
	-- lowers awareness directly; cerebral oxygen decides whether that becomes OTRUB.
	local shockTarget = decompensation * 20
	org.shock = math.Approach(org.shock or 0, math.max(org.shock or 0, shockTarget), mulTime * (0.35 + decompensation * 2.65))
	if org.stamina and org.stamina[1] then
		local staminaLoss = decompensation ^ 1.2 * (org.stamina.max or 180) / 38
		org.stamina[1] = math.max(org.stamina[1] - mulTime * staminaLoss, 0)
	end
	-- A pressure-only consciousness floor stays just above the OTRUB threshold.
	-- Falling brain oxygen can still carry consciousness through that floor later.
	local pressureConsciousness = 1 - decompensation ^ 1.1 * 0.67
	org.consciousness = math.min(org.consciousness, pressureConsciousness * tempMul)
	if symptomaticLoss > 0 and org.isPly and not org.otrub then
		org.owner:Notify("I'm getting weak and lightheaded...", true, "blood_pressure_low", 0, nil, Color(200, 170, 170))
	end

	local beatsPerSecond = max(min(60 / math.max(org.pulse,2) / (org.bleed / 15), 7), 0.3)
	time = CurTime()

	local bleedoutspeed = 0
	local woundBleedRates = {}
	local pulse = org.pulse
	local bleedMul = org.bleedingmul
	local coagMul = org.coagulation_multiplier
	local isAlive = isPlayer and owner:Alive()
	
	if #org.wounds > 0 then
		local ent = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
		local entVel = ent:GetVelocity()
		
		local woundsToRemove = {}
		for i, wound in pairs(org.wounds) do
			local tourniquetBleedMul = hg.GetTourniquetBleedMultiplier and hg.GetTourniquetBleedMultiplier(owner, wound[4]) or 1
			local heldClotMul = getHeldWoundClotMul(org, wound)
			local rand1 = math.Rand(4, 10)
			local rand2 = math.Rand(0.5, 1)
			local bleed = rand1 * wound[1] * mulTime * math.max(pulse, 20) / 70 * wound_bleed_rate_mul * (1 - math.min(adrenaline / 6, 0.5)) * bleedMul * 0.02 * tourniquetBleedMul
			bleed = bleed * getHeldWoundBleedMul(org, wound)
			local coagulate = 2 * mulTime * rand2 * (adrenaline * 0.1 + 1) * (org.satiety / 100 + 1) * 0.05 * coagMul * heldClotMul
			local woundBleedRate = bleed / rand1 * 3
			bleedoutspeed = bleedoutspeed + woundBleedRate
			local visualWoundBleedRate = bleed / math.max(mulTime, 0.001)
			woundBleedRates[i] = visualWoundBleedRate
			wound.visualBleedRate = visualWoundBleedRate
			
			wound[5] = time
			org.blood = max(org.blood - bleed, 1)
				
			if tourniquetBleedMul > 0 and (isAlive or not isPlayer) then
				hg.organism.BloodDroplet2(owner, org, wound, entVel + VectorRand(-50, 50), false)
			end
			if isAlive or not isPlayer then
				wound[1] = max(wound[1] - coagulate, 0)
			end

			if wound[1] == 0 then
				table.insert(woundsToRemove, i)
			end
		end

		for idx = #woundsToRemove, 1, -1 do
			table.remove(org.wounds, woundsToRemove[idx])
		end
		if #woundsToRemove > 0 then
			hg.organism.SyncWounds(org)
		end
	end

	if org.heart == 1 then
		org.blood = math.max(org.blood - mulTime * 100 * org.pulse / 70,0)
		bleedoutspeed = bleedoutspeed + mulTime * 100 * org.pulse / 70
	end

	bleedoutspeed = bleedoutspeed / (beatsPerSecond + 2)

	local bleedoutspeed2 = 0
	local arterialWoundBleedRates = {}
	local next_arterypump = 1 / math.max(pulse, 10)
	local ent = isPlayer and IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
	local ownerVel = owner:GetVelocity()

	local arterialToRemove = {}
	local hasCarotidWound = false
	local heldCarotidWound = false
	for i, wound in pairs(org.arterialwounds) do
		local tourniquetBleedMul = hg.GetTourniquetBleedMultiplier and hg.GetTourniquetBleedMultiplier(owner, wound[4]) or 1
		local isAmputation = wound[9] == true
		local isHeadGib = wound[10] == "headgib"
		local woundSeverityMul = isAmputation and amputation_arterial_bleed_mul or (isHeadGib and headgib_arterial_bleed_mul or 1)
		local circulationOutput = math.max(tonumber(org.cardiacOutput) or 0, 0)
		local pressureFactor = math.Clamp((tonumber(org.bloodPressure) or 0) / 92, 0, 1.5)
		local pulseFactor = math.Clamp((tonumber(org.pulse) or 0) / 70, 0, 1.5)
		-- Pressure-driven bleeding follows actual residual flow. Cardiac arrest is a
		-- rhythm state, not a reason to erase the last few seconds of mechanical
		-- pressure before cardiac output/pulse have mathematically decayed.
		local arterialDrive = math.Clamp(math.sqrt(math.max(circulationOutput * pressureFactor * pulseFactor, 0)), 0, 1.5)
		local passiveDrive = math.Clamp(0.08 + arterialDrive * 0.92, 0.08, 1.5)
		if wound[7] == "arteria" and (wound[1] or 0) > 0 then hasCarotidWound = true end
		if wound[7] == "arteria" and org.manualHoldWound and org.manualHoldWoundArterial and org.manualHoldWoundTarget == wound then
			heldCarotidWound = true
		end
		local passiveArterialBleed = wound[1] * mulTime * 0.14 * arterial_bleed_rate_mul * woundSeverityMul * passiveDrive * tourniquetBleedMul
		bleedoutspeed2 = bleedoutspeed2 + passiveArterialBleed
		local arterialBleed = wound[1] * mulTime * 0.2 * arterial_bleed_rate_mul * woundSeverityMul * arterialDrive * tourniquetBleedMul
		arterialBleed = arterialBleed * getHeldWoundBleedMul(org, wound)
		bleedoutspeed2 = bleedoutspeed2 + arterialBleed
		local woundBleedRate = (passiveArterialBleed + arterialBleed) / math.max(mulTime, 0.001)

		if wound[5] + next_arterypump * 2 < time then
			local pos, ang = ent:GetBonePosition(ent:LookupBone(wound[4]))
			wound[5] = time
			local pulseBleed = wound[1] * mulTime * 3.2 * arterial_bleed_rate_mul * woundSeverityMul * arterialDrive * tourniquetBleedMul
			org.blood = max(org.blood - pulseBleed, 1)
			woundBleedRate = woundBleedRate + pulseBleed / math.max(mulTime, 0.001)
			if tourniquetBleedMul > 0 and (isAlive or not isPlayer) then
				local pumpBleed = wound[1] * mulTime * 4.5 * arterial_bleed_rate_mul * woundSeverityMul * arterialDrive * tourniquetBleedMul
				pumpBleed = pumpBleed * getHeldWoundBleedMul(org, wound)
				org.blood = max(org.blood - pumpBleed, 1)
				woundBleedRate = woundBleedRate + pumpBleed / math.max(mulTime, 0.001)
				if arterialDrive > 0.01 then
					local dir = wound[6]
					local len = dir:Length()
					local _, dir = LocalToWorld(vecZero, dir:Angle(), vecZero, ang)
					dir = -dir:Forward() * len
					hg.organism.BloodDroplet2(owner, org, wound, ownerVel + VectorRand(-10, 10) + dir, true)
				end
			end

			if wound[1] == 0 then
				table.insert(arterialToRemove, i)
				org[wound[7]] = 0
			end
		end
		arterialWoundBleedRates[i] = woundBleedRate
		wound.visualBleedRate = woundBleedRate
	end

	for idx = #arterialToRemove, 1, -1 do
		table.remove(org.arterialwounds, arterialToRemove[idx])
	end
	if #arterialToRemove > 0 then
		hg.organism.RebuildArteryWoundState(org)
	end
	if org.throatcut then
		local severity = math.Clamp(org.throatCutSeverity or 1, 0.35, 1.25)
		local carotidPressureMul = heldCarotidWound and hold_wound_arterial_slow_mul or 1
		local pressureTarget = hasCarotidWound and severity * carotidPressureMul or 0
		local brainPenaltyTarget = hasCarotidWound and math.min(severity * 0.3, 0.45) * carotidPressureMul or 0
		local pressureRate = hasCarotidWound and mulTime / 14 or mulTime / 8
		local brainPenaltyRate = hasCarotidWound and mulTime / 18 or mulTime / 8
		org.throatCutPressureShock = math.Approach(org.throatCutPressureShock or 0, pressureTarget, pressureRate)
		org.neckBrainOxygenPenalty = math.Approach(org.neckBrainOxygenPenalty or 0, brainPenaltyTarget, brainPenaltyRate)
		-- Airway damage is owned by the trachea/ventilation model. Do not drain O2
		-- again here just because the same throat injury also opened an artery.
	end
	bleedoutspeed2 = bleedoutspeed2 / next_arterypump

	if hasAntiIschemia then
		org.ischemia = math.max((org.ischemia or 0) - mulTime * 0.05, 0)
	end
	if adrenalineStabilizer then
		org.ischemia = math.max((org.ischemia or 0) - mulTime * 0.01 * totalAdrenaline, 0)
	end

	-- Internal-bleed severity is an injury score, not a direct mL/sec value.
	-- It is multiplied by 100 when applied below. Keep the resulting loss in a
	-- range where a serious injury needs treatment, but does not empty a player
	-- from a few stacked organ hits before the delayed complications can matter.
	-- An internal-bleed score of 10 produces about 0.033 bleed (3.3 mL/s after the
	-- existing x100 application below); lower injuries scale proportionally.
	-- This keeps a score around 1.0 as an urgent injury instead of an
	-- immediate blood-loss death sentence.
	local bleed = math.Clamp(org.internalBleed / 300, 0, 0.11) -- + org.lungsR[3] + org.lungsL[3]
	
	-- Damaged liver prevents natural internal bleeding healing unless tranexamic acid is present
	local canHealInternalBleed = org.liver <= 0 or (org.tranexamic_acid or 0) > 0
	local internalBleedHeal = org.internalBleedHeal or 0

	-- Natural clotting remains slow. internalBleedHeal is pending treatment,
	-- though, so consume it in lockstep with the injury it actually repairs. This
	-- makes medicine act within seconds and prevents its healing budget from
	-- fading away before it reaches the wound.
	local naturalHeal = mulTime / (canHealInternalBleed and 150 or 300)
	local treatmentHeal = 0
	if internalBleedHeal > 0 then
		local treatmentRate = math.Clamp(0.35 + internalBleedHeal * 0.15, 0.35, 1.1)
		treatmentHeal = math.min(internalBleedHeal, mulTime * treatmentRate)
	end

	local bleedBeforeHeal = math.max(org.internalBleed or 0, 0)
	local naturalApplied = math.min(bleedBeforeHeal, naturalHeal)
	local treatmentApplied = math.min(math.max(bleedBeforeHeal - naturalApplied, 0), treatmentHeal)
	org.internalBleed = math.max(bleedBeforeHeal - naturalApplied - treatmentApplied, 0)
	org.internalBleedHeal = math.max(internalBleedHeal - treatmentApplied, 0)
	if org.internalBleed <= 0 then org.internalBleedHeal = 0 end

	if bleed > 0 then org.blood = max(org.blood - bleed * mulTime * 100 * org.pulse / 70, 1) end

	if (org.internalBleed > 1 or org.pneumothorax > 0 or (org.hemothorax or 0) > 0.3) and org.blood > 0 and org.o2[1] > 0 then
		org.wantToVomit = org.wantToVomit or 0

		org.wantToVomit = org.wantToVomit + math.Rand(0, org.internalBleed / 1000 + org.pneumothorax / 200 + (org.hemothorax or 0) / 150) * mulTime * 5
		
		if org.wantToVomit > 0.90 then
			//owner:Notify(about_to_puke[math.random(#about_to_puke)], 15, "internalbleed_pre")
		end
	end

	if org.wantToVomit > 1 then
		org.wantToVomit = 0

		if org.vomitTypeHeadTrauma then
			org.vomitTypeHeadTrauma = nil
			if math.random(6) == 1 then
				hg.organism.Vomit(owner)
			else
				hg.organism.VomitNormal(owner)
			end
		else
			hg.organism.Vomit(owner)
		end
	end

	org.bleed = (bleedoutspeed + bleedoutspeed2 + bleed)--в секунду

	if org.bleed > 0 then org.lastBleedTime = CurTime() end

	local incapacitationEnabled = not hg.organism.IncapacitationEnabled or hg.organism.IncapacitationEnabled()
	-- Blood volume and tissue O2 never start the terminal OTRUB timer directly.
	-- Cerebral oxygen, brain/airway injury, cardiac arrest, and spinal failure do.
	local cerebralFailure = (org.brainoxygen or 1) < 0.16
	org.incapacitated = incapacitationEnabled and org.otrub and (cerebralFailure or (org.brain > 0.4) or (org.trachea >= 0.5) or org.heartstop or (org.spine3 >= hg.organism.fake_spine3) or (org.spine2 >= hg.organism.fake_spine2)) or false

	local noNeedle = org.needle <= 0
	local tracheaBlocking = org.trachea > 0.5 and noNeedle
	local tracheaNoO2Regen = org.trachea > 0.5 and (org.o2.curregen or 0) <= 0

	if (org.brain > 0.4) or (org.heart > 0.6) or tracheaBlocking or tracheaNoO2Regen then
		org.critical = true
	else
		org.critical = false
	end

	org.bleed = (bleedoutspeed + bleedoutspeed2 + bleed)
	org.venousBleed = bleedoutspeed
	org.arterialBleed = bleedoutspeed2
	org.woundBleedRates = woundBleedRates
	org.arterialWoundBleedRates = arterialWoundBleedRates
	org.internalBleedRate = bleed
	updateHoldWound(org)
end

util.AddNetworkString("bloodsquirt2")
util.AddNetworkString("vomitsquirt2")
util.AddNetworkString("hg_organism_defecate")

local function GetVomitDecal()
	return math.random(6) == 1 and "Organism.VomitMedium" or "Organism.VomitSmall"
end

local function VomitDecalSpray(owner, ent, mat)
	if not IsValid(ent) or not mat then return end

	local basePos = mat:GetTranslation() + mat:GetAngles():Right() * 6 + mat:GetAngles():Forward() * 1
	local forward = mat:GetAngles():Right()
	local step = 0
	local steps = 4
	local timerName = "hg_vomit_decal_" .. owner:EntIndex() .. "_" .. math.floor(CurTime() * 1000) .. "_" .. math.random(1000, 9999)
	timer.Create(timerName, 0.025, steps, function()
		if not IsValid(owner) or not IsValid(ent) then timer.Remove(timerName) return end
		step = step + 1

		local spread = VectorRand(-0.14, 0.14)
		spread[3] = spread[3] * 0.3
		local dir = (forward * 0.58 + Vector(0, 0, -0.72) + spread):GetNormalized()
		local endPos = basePos + dir * (130 + step * 85)
		local tr = util.TraceLine({
			start = basePos,
			endpos = endPos,
			filter = {ent, owner, owner.FakeRagdoll},
			mask = MASK_SOLID_BRUSHONLY
		})

		if tr.Hit then
			util.Decal(GetVomitDecal(), tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal, tr.Entity)
		else
			local trDown = util.TraceLine({
				start = endPos,
				endpos = endPos + Vector(0, 0, -360),
				filter = {ent, owner, owner.FakeRagdoll},
				mask = MASK_SOLID_BRUSHONLY
			})

			if trDown.Hit then
				util.Decal(GetVomitDecal(), trDown.HitPos + trDown.HitNormal, trDown.HitPos - trDown.HitNormal, trDown.Entity)
			end
		end
	end)
end

function hg.organism.Vomit(owner, snd)
	if !hg.IsValidPlayer(owner) then return end
	
	local org = owner.organism
	-- Vomiting loses GI fluid, not 200 mL of circulating blood per episode.
	local ent = hg.GetCurrentCharacter(owner)

	local bon = "ValveBiped.Bip01_Head1"
	local bone = ent:LookupBone(bon)
	local mat = ent:GetBoneMatrix(bone)

	if not mat then return end

	local on_spine = mat:GetAngles():Right()[3] > 0.25
	if on_spine then
		org.vomitInThroat = true
	end

	owner:SetNetVar("vomiting", CurTime() + 1.5)

	ent:EmitSound(snd or "vomit/vomit5.ogg")
	
	if owner.armors and owner.armors.face and hg.armor.face[owner.armors.face].voice_change then
		owner:SetNetVar("zableval_masku", true)
	else
		if !on_spine then
			net.Start("bloodsquirt2")
			net.WriteEntity(ent)
			net.WriteString(bon)
			net.WriteMatrix(mat)
			net.WriteVector(mat:GetTranslation() + mat:GetAngles():Right() * 6 + mat:GetAngles():Forward() * 1)
			net.WriteVector(mat:GetAngles():Right() * 2 * math.Clamp(org.pulse / 70, 0.4, 1))
			net.Broadcast()
		end
	end
end

function hg.organism.VomitNormal(owner, snd)
	if !hg.IsValidPlayer(owner) then return end

	local org = owner.organism
	local ent = hg.GetCurrentCharacter(owner)

	local bon = "ValveBiped.Bip01_Head1"
	local bone = ent:LookupBone(bon)
	local mat = ent:GetBoneMatrix(bone)

	if not mat then return end

	local on_spine = mat:GetAngles():Right()[3] > 0.25
	if on_spine then
		org.vomitInThroat = true
	end

	owner:SetNetVar("vomiting", CurTime() + 1.5)
	org.disorientation = math.min((org.disorientation or 0) + 1.5, 6)
	org.consciousness = math.max((org.consciousness or 1) - 0.08, 0)
	org.hungry = math.min(math.max((org.hungry or 0) + 7, 0), 100)
	org.satiety = math.max((org.satiety or 0) - 20, 0)

	ent:EmitSound(snd or "vomit/vomit5.ogg")

	if owner.armors and owner.armors.face and hg.armor.face[owner.armors.face].voice_change then
		owner:SetNetVar("zableval_masku", true)
	else
		if !on_spine then
			net.Start("vomitsquirt2")
			net.WriteEntity(ent)
			net.WriteString(bon)
			net.WriteMatrix(mat)
			net.WriteVector(mat:GetTranslation() + mat:GetAngles():Right() * 6 + mat:GetAngles():Forward() * 1)
			net.WriteVector(mat:GetAngles():Right() * 2 * math.Clamp(org.pulse / 70, 0.4, 1))
			net.Broadcast()

			local name = "hg_normal_vomit_" .. owner:EntIndex()
			timer.Create(name, 0.09, 2, function()
				if not IsValid(owner) then return end
				local entNow = hg.GetCurrentCharacter(owner)
				if not IsValid(entNow) then return end
				local boneNow = entNow:LookupBone(bon)
				if not boneNow then return end
				local matNow = entNow:GetBoneMatrix(boneNow)
				if not matNow then return end
				VomitDecalSpray(owner, entNow, matNow)
			end)
		end
	end
end

-- Judge's overdose client effect already has a matching decal receiver in this
-- branch. Keep the server event with the blood module that owns vomiting and
-- other expelled-fluid effects instead of loading the overlapping circulation
-- module from Judge.
function hg.organism.Defecate(owner)
	if !hg.IsValidPlayer(owner) then return end

	owner:EmitSound("snd_jack_hmcd_fart.ogg", 75)
	owner:ViewPunch(AngleRand(-0.3, 0.3))
	net.Start("hg_organism_defecate")
		net.WriteEntity(owner)
	net.SendPVS(owner:GetPos())
end

function hg.organism.CoughBlood(org)
	local ply = org.owner
	if not IsValid(ply) then return end
	local phr = "zcitysnd/real_sonar/" .. (ThatPlyIsFemale(ply) and "female" or "male") .. "_cough" .. math.random(4) .. ".ogg"
	ply:EmitSound(phr)
	ply.phrCld = CurTime() + 2
	ply.lastPhr = phr

	if math.random(5) == 1 then
		local ent = hg.GetCurrentCharacter(ply)
		if not IsValid(ent) then return end
		local bon = "ValveBiped.Bip01_Head1"
		local bone = ent:LookupBone(bon)
		local mat = bone and ent:GetBoneMatrix(bone)
		if not mat then return end

		org.vomitInThroat = nil
		net.Start("bloodsquirt2")
		net.WriteEntity(ent)
		net.WriteString(bon)
		net.WriteMatrix(mat)
		net.WriteVector(mat:GetTranslation() + mat:GetAngles():Right() * 6 + mat:GetAngles():Forward())
		net.WriteVector(mat:GetAngles():Right() * 2 * math.Clamp((org.pulse or 0) / 70, 0.4, 1))
		net.Broadcast()

		ent:EmitSound("vomit/vomit5.ogg")
	end
end

function hg.organism.BloodDroplet2(owner, org, wound, dir, artery)
	hook.Run("HG_BloodParticleStartedDropping", owner, org, wound, dir, artery)
end

