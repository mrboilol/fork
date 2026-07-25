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
	org.blood = 5000
	org.bleed = 0
	org.venousBleed = 0
	org.arterialBleed = 0
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

	org.survivalchance = 1
	org.hemothorax = 0
	org.lastBleedTime = CurTime()
	org.arterialO2Drain = false
	org.throatcut = false
	org.throatCutTime = 0
	org.throatCutUntil = 0
	org.throatCutSeverity = 0
	org.throatCutPressureShock = 0
end

local internalbleed_phrases = {
	"That's... that's blood I just vomited...",
	"Oh, that's blood...",
	"Fuck, I just puked blood...",
	"Oh shit... I don't feel good...",
}

local about_to_puke = {
	"I feel like I'm gonna puke any second now...",
	"Not feeling good...",
	"Gonna puke right now...",
	"I want to vomit...",
}

local vecZero = Vector(0, 0, 0)
local limbArteryWeakness = {
	rarmartery = {limb = "rarm", damage = 0.65},
	larmartery = {limb = "larm", damage = 0.65},
	rlegartery = {limb = "rleg", damage = 0.7},
	llegartery = {limb = "lleg", damage = 0.7},
}

local o2DebuffArteries = {
	-- A slit carotid is primarily a bleed/shock emergency. Keep its direct body
	-- O2 penalty small so it does not overwhelm the separate airway and blood-loss paths.
	arteria = 0.1,
	spineartery = 0.85,
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
local arterial_bleed_rate_mul = 0.9

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

module[2] = function(owner, org, mulTime)
	local adrenaline = math.Clamp(org.adrenaline or 0, 0, 2)
	local isPlayer = owner:IsPlayer()
	org.coagulation_multiplier = 1
	org.blood_regeneration_multiplier = 1

	org.bleedingmul = 1.0

	if org.liver > 0 then
		org.coagulation_multiplier = org.coagulation_multiplier * (1 - org.liver * 0.5)
		org.blood_regeneration_multiplier = org.blood_regeneration_multiplier * (1 - org.liver * 0.75)
		org.bleedingmul = org.bleedingmul * (1 + org.liver * 0.5)
		-- Liver trauma adds internal bleeding when the organ is damaged. Do not
		-- generate more forever from the persistent liver-damage value here.
	else
		org.coagulation_multiplier = 1.2
		org.blood_regeneration_multiplier = 1.2
		org.bleedingmul = 0.8
	end

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

			ent:EmitSound("vomit/vomit5.mp3")
		end
	end

	if org.isPly and not org.otrub and org.blood < 2900 then org.owner:Notify(math.random(2) == 1 and "I cant feel anything..." or (math.random(2) == 1 and "I think I'm gonna faint right now...") or "I dont feel so good...",true,"blood2",0,nil,Color(200, 170, 170)) end

	if org.internalBleed < 0.5 and org.bleed < 0.05 and org.pulse > 5 then
		local timeSinceBleed = CurTime() - (org.lastBleedTime or 0)
		local recoveryRamp = Lerp(math.Clamp(timeSinceBleed / 60, 0, 1), 0.75, 1)
		local heartRate = org.heartbeat or org.pulse or 75
		local highHeartRateBoost = 1 + math.Clamp((heartRate - 120) / 80, 0, 1) * 0.5
		local adrenalineBoost = 1 + math.Clamp((adrenaline - 0.5) / 1.5, 0, 1) * 0.4
		local satietyMultiplier = 0.75 + math.Clamp((org.satiety or 0) / 100, 0, 1) * 0.25
		local goodmood = math.Clamp(org.goodmood or 0, 0, 1)
		local goodmoodBonus = 1 + goodmood * 0.1
		-- Normal MAP is 93 in the cardiovascular model.  Use that same reference
		-- here so healthy circulation does not receive an unintended regeneration
		-- penalty while high pressure cannot turn regeneration into a fast refill.
		local pressurePerfusion = math.Clamp((org.bloodpressure or 93) / 93, 0.05, 1)
		local regenerationRate = 0.3 * highHeartRateBoost * adrenalineBoost * satietyMultiplier * org.blood_regeneration_multiplier * pressurePerfusion * recoveryRamp * goodmoodBonus
		org.blood = min(org.blood + mulTime * regenerationRate, 5000)
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
		local o2DebuffRate = 0

		for _, wound in pairs(org.arterialwounds) do
			local artery = wound[7]
			if wound[1] and wound[1] > 0 then
				local weakness = limbArteryWeakness[artery]
				if weakness and not org[weakness.limb .. "amputated"] then
					org[weakness.limb] = math.max(org[weakness.limb] or 0, weakness.damage)
				end

				local o2Mul = o2DebuffArteries[artery]
				if o2Mul then
					o2DebuffRate = o2DebuffRate + 5 * o2Mul
				end
			end
		end

		if o2DebuffRate > 0 then
			if org.blood <= 3750 then
				o2DebuffRate = o2DebuffRate * 3
				if org.isPly and not org.otrub then
					org.owner:Notify("I can't breathe... blood's not getting where it should.", true, "arterial_o2", 0, nil, Color(200, 170, 170))
				end
			end

			org.o2[1] = math.max(org.o2[1] - mulTime * o2DebuffRate, 0)
		end
	end

	-- Track how long internal bleed has been untreated
	if org.internalBleed > 0 then
		org.internalBleedDuration = (org.internalBleedDuration or 0) + mulTime
	else
		org.internalBleedDuration = 0
	end

	if org.internalBleed > 2.5 and not adrenalineStabilizer and not hasAntiIschemia then
		local untreatedTime = math.max((org.internalBleedDuration or 0) - 15, 0)
		if untreatedTime > 0 then
			local durationFactor = untreatedTime / 45
			org.ischemia = org.ischemia + durationFactor * org.internalBleed * mulTime * 0.015
		end
	end

	-- Nosebleed from severe internal bleeding
	if org.internalBleed > 0.75 and hg.applyNosebleed and math.random() < org.internalBleed * 0.02 * mulTime then
		hg.applyNosebleed(owner, org.internalBleed * 8)
	end

	-- Tiered blood loss progression
	-- 4500: first symptoms - lightheaded, faint nausea
	-- 4000: slight systemic debuffs begin (O2, consciousness soft-cap 0.95)
	-- 5000-4500: compensation and the configured BPM curve begin rising
	-- 3000: noticeable symptoms, still compensated
	-- 2750: heavy compensation starts
	-- 2500: severe tachycardia; decompensation and coma pressure begin
	-- 2300: forced collapse pressure begins
	-- 2200: unconscious/coma threshold
	-- 2000: deadly hypovolemic shock zone
	local bloodConsciousnessCap = 1
	local tempMul = math.Clamp(((org.temperature < 30 and org.temperature - 30 or 0) * 0.25 + 1), 0.25, 1)
	local blood = org.blood or 5000
	local bloodDeficit = math.Clamp((4000 - blood) / 2500, 0, 1)
	local compensation = math.Clamp((5000 - blood) / (5000 - 2000), 0, 1)
	local shockStage = math.Clamp((2500 - blood) / 750, 0, 1)

	org.hypovolemia = bloodDeficit
	org.hemorrhageCompensation = compensation
	org.hypovolemicShock = shockStage
	-- Hypovolemia also reduces heat delivery. Pulse uses this target on its
	-- temperature tick, allowing severe blood loss to contribute to cold-driven
	-- bradycardia without instantly forcing every bleed into the same rhythm.
	local lowBloodCold = math.Clamp((3500 - blood) / 2500, 0, 1)
	org.lowBloodTemperatureTarget = 36.7 - lowBloodCold * 3.2

	if org.blood < 4500 then
		-- One alert when this blood-loss stage is first reached.
		if org.isPly and not org.otrub then
			org.owner:Notify("I'm starting to feel faint...", true, "blood_4500", 0, nil, Color(200, 170, 170))
		end
	end

	if org.blood < 4000 then
		-- Soft consciousness cap at 0.95
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, 0.95)
		if org.isPly and not org.otrub then
			org.owner:Notify("My body is hard to move...", true, "blood_4000", 0, nil, Color(200, 170, 170))
		end
	end

	if org.blood < 3500 then
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, 0.95)
		if org.isPly and not org.otrub then
			org.owner:Notify("Everything feels so heavy...", true, "blood_3500", 0, nil, Color(200, 170, 170))
		end
	end

	if org.blood < 3000 then
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, 0.9)
		org.disorientation = math.max(org.disorientation or 0, 0.35 + bloodDeficit * 0.65)
		if org.isPly and not org.otrub then
			org.owner:Notify("My eyes are starting to lose focus...", true, "blood_3000", 0, nil, Color(200, 170, 170))
		end
	end

	if org.blood < 2750 then
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, 0.82)
	end

	if org.blood < 2500 then
		-- Slow ischemia creep begins
		if not adrenalineStabilizer and not hasAntiIschemia then
			org.ischemia = math.min(org.ischemia + mulTime * 0.004, 1.0)
		end
		org.shock = math.Approach(org.shock or 0, 18 + shockStage * 42, mulTime * (1 + shockStage * 2))
		if org.stamina and org.stamina[1] then
			org.stamina[1] = math.max(org.stamina[1] - mulTime * shockStage * (org.stamina.max or 180) / 35, 0)
		end
		-- Consciousness now slides toward coma across the 2500-2000 range.
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, math.Clamp((org.blood - 2000) / 500 * 0.52 + 0.1, 0.1, 0.62))
		if org.isPly and not org.otrub then
			org.owner:Notify("I feel cold... I can't think straight.", true, "blood_2500", 0, nil, Color(200, 170, 170))
		end
	end

	-- Hard floor: at 2300 begin collapsing toward coma by 2000.
	if org.blood < 2300 then
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, math.max((org.blood - 2000) / 300, 0))
		org.needfake = true
		if org.blood < 2200 then
			org.needotrub = true
		end
		if not adrenalineStabilizer and not hasAntiIschemia then
			org.ischemia = math.min((org.ischemia or 0) + mulTime * math.Clamp((2300 - org.blood) / 600, 0, 1) * 0.02, 1.5)
		end
	end

	org.consciousness = math.min(org.consciousness, bloodConsciousnessCap * tempMul)

	local beatsPerSecond = max(min(60 / math.max(org.pulse,2) / (org.bleed / 15), 7), 0.3)
	time = CurTime()

	local coagulatespeed = 0
	local bleedoutspeed = 0
	local pulse = org.pulse
	local bleedMul = org.bleedingmul
	local coagMul = org.coagulation_multiplier
	local isAlive = isPlayer and owner:Alive()
	
	if #org.wounds > 0 then
		local ent = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
		local entVel = ent:GetVelocity()
		
		local woundsToRemove = {}
		for i, wound in pairs(org.wounds) do
			local rand1 = math.Rand(4, 10)
			local rand2 = math.Rand(0.5, 1)
			local bleed = rand1 * wound[1] * mulTime * math.max(pulse, 20) / 70 * 1.35 * (1 - math.min(adrenaline / 6, 0.5)) * bleedMul * 0.02
			local coagulate = 2 * mulTime * rand2 * (adrenaline * 0.1 + 1) * (org.satiety / 100 + 1) * 0.05 * coagMul
			bleedoutspeed = bleedoutspeed + bleed / rand1 * 3
			local woundBleedRate = bleed / rand1 * 3
			coagulatespeed = coagulatespeed + coagulate / rand2
			local rand1 = math.Rand(4, 10) * 1
			local rand2 = math.Rand(0.5, 1) * 1
			local bleed = rand1 * wound[1] * mulTime * math.max(org.pulse, 20) / 70 * 2.0 * (1 - math.min(adrenaline / 6, 0.5)) * org.bleedingmul * 0.02
			bleed = bleed * getHeldWoundBleedMul(org, wound)
			local coagulate = 2 * mulTime * rand2 * (adrenaline * 0.1 + 1) * 0.04-- / #org.wounds
			bleedoutspeed = bleedoutspeed + bleed / rand1 * 3--we pray for the luck of it being in the center
			wound.visualBleedRate = woundBleedRate + bleed / rand1 * 3
			coagulatespeed = coagulatespeed + coagulate / rand2 * 1
			
			wound[5] = time
			org.blood = max(org.blood - bleed, 1)
				
			if isAlive or not isPlayer then
				hg.organism.BloodDroplet2(owner, org, wound, entVel + VectorRand(-50, 50), false)
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

	if org.liver > 0.5 then
		org.blood = math.max(org.blood - mulTime * 10 * org.pulse / 70 * org.liver,0)
		bleedoutspeed = bleedoutspeed + mulTime * 10 * org.pulse / 70 * org.liver
	end

	bleedoutspeed = bleedoutspeed / (beatsPerSecond + 2)

	local bleedoutspeed2 = 0
	local next_arterypump = 1 / math.max(pulse, 10)
	local ent = isPlayer and IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
	local ownerVel = owner:GetVelocity()

	local arterialToRemove = {}
	local hasCarotidWound = false
	for i, wound in pairs(org.arterialwounds) do
		if wound[7] == "arteria" and (wound[1] or 0) > 0 then hasCarotidWound = true end
		local passiveArterialBleed = wound[1] * mulTime * 0.14 * arterial_bleed_rate_mul * math.max(pulse, 20) / 80
		bleedoutspeed2 = bleedoutspeed2 + passiveArterialBleed
		local arterialBleed = wound[1] * mulTime * 0.2 * arterial_bleed_rate_mul * math.max(org.pulse, 20) / 80
		arterialBleed = arterialBleed * getHeldWoundBleedMul(org, wound)
		bleedoutspeed2 = bleedoutspeed2 + arterialBleed
		wound.visualBleedRate = passiveArterialBleed + arterialBleed

		if wound[5] + next_arterypump * 2 < time then
			local pos, ang = ent:GetBonePosition(ent:LookupBone(wound[4]))
			wound[5] = time
			org.blood = max(org.blood - wound[1] * mulTime * 3.2 * arterial_bleed_rate_mul * math.max(pulse, 20) / 80, 1)
			if isAlive or not isPlayer then
			local pumpBleed = wound[1] * mulTime * 4.5 * arterial_bleed_rate_mul * math.max(org.pulse, 20) / 80
			pumpBleed = pumpBleed * getHeldWoundBleedMul(org, wound)
			org.blood = max(org.blood - pumpBleed, 1)
			if (owner:IsPlayer() and owner:Alive()) or not owner:IsPlayer() then
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
	end

	for idx = #arterialToRemove, 1, -1 do
		table.remove(org.arterialwounds, arterialToRemove[idx])
	end
	if #arterialToRemove > 0 then
		hg.organism.RebuildArteryWoundState(org)
	end
	if org.throatcut then
		local severity = math.Clamp(org.throatCutSeverity or 1, 0.35, 1.25)
		if hasCarotidWound then
			org.throatCutPressureShock = math.max(org.throatCutPressureShock or 0, severity)
		else
			org.throatCutPressureShock = math.Approach(org.throatCutPressureShock or 0, 0, mulTime / 8)
		end
		-- The open airway continues to consume body oxygen even after a neck
		-- bandage has stopped the arterial jet, but this stays secondary to the
		-- bleeding and airway-function consequences of a slit throat.
		if org.o2 and org.o2[1] then
			org.o2[1] = math.max(org.o2[1] - mulTime * 0.25 * severity, 0)
		end
	end
	bleedoutspeed2 = bleedoutspeed2 / next_arterypump

	-- At 2000: ischemic collapse begins. Pulse owns the terminal BPM/arrest
	-- transition and lungs owns the blood-volume O2 cap.
	if org.blood <= 2000 then
		local ischemicDepth = math.Clamp((2000 - org.blood) / 600, 0, 1)
		local ischemicRate = 0.015 + ischemicDepth * 0.08
		if not adrenalineStabilizer and not hasAntiIschemia then
			org.ischemia = math.min(org.ischemia + mulTime * ischemicRate, 1.0)
		end
		-- Consciousness is already capped above; add direct drain inside fatal volume loss.
		if org.blood < 1900 then
			org.consciousness = math.max((org.consciousness or 1) - mulTime * (0.35 + ischemicDepth * 1.4), 0)
		end
		-- One alert when ischemic collapse starts.
		if org.isPly and not org.otrub then
			org.owner:Notify("My chest... I can't breathe right...", true, "ischemic_collapse", 0, nil, Color(200, 170, 170))
		end
	end
	
	if hasAntiIschemia then
		org.ischemia = math.max((org.ischemia or 0) - mulTime * 0.05, 0)
	end
	if adrenalineStabilizer then
		org.ischemia = math.max((org.ischemia or 0) - mulTime * 0.01 * totalAdrenaline, 0)
	end

	local bleed = org.internalBleed / 55 -- + org.lungsR[3] + org.lungsL[3]
	
	-- Damaged liver prevents natural internal bleeding healing unless tranexamic acid is present
	local canHealInternalBleed = org.liver <= 0 or (org.tranexamic_acid or 0) > 0
	local internalBleedHeal = org.internalBleedHeal or 0

	-- internalBleedHeal actively helps against internal bleeding; natural healing works if liver is healthy or acid is present
	local healRate = (internalBleedHeal > 0 or canHealInternalBleed) and mulTime / 2 or mulTime / 55

	-- Excess internalBleedHeal significantly accelerates healing
	if internalBleedHeal > org.internalBleed then
		healRate = healRate * math.min(1 + (internalBleedHeal - org.internalBleed) * 0.5, 4)
	end

	org.internalBleed = math.Approach(org.internalBleed, 0, healRate)
	coagulatespeed = coagulatespeed + mulTime
	org.internalBleedHeal = math.Approach(org.internalBleedHeal, 0, mulTime / 2)

	if bleed > 0 then org.blood = max(org.blood - bleed * mulTime * 100 * org.pulse / 70, 1) end
	
	if (org.internalBleed > 1 or org.pneumothorax > 0 or (org.hemothorax or 0) > 0.3) and org.blood > 2000 and org.o2[1] > 0 then
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
			if org.isPly then owner:Notify(hg.internalbleed_phrases[math.random(#hg.internalbleed_phrases)], 15, "internalbleed") end
			hg.organism.Vomit(owner)
		end
	end

	org.bleed = (bleedoutspeed + bleedoutspeed2 + bleed)--в секунду

	if org.bleed > 0 then org.lastBleedTime = CurTime() end

	local timetouncon = (org.blood - 2000) / org.bleed
	
	local bleeding_will_stop = (timetouncon ~= timetouncon) or ((coagulatespeed * timetouncon - org.bleed) > 0)
	local canwakeup_pain = ((org.pain - 5) / (org.painlessen)) < timetouncon
	org.timetouncon = (timetouncon ~= timetouncon) and timetouncon or Lerp(hg.lerpFrameTime2(0.01,mulTime), org.timetouncon or 10000, timetouncon)
	
	local scavDyingMode = GetConVar("hg_scavdying")
	local organSystemsEnabled = not hg.organism.OrganSystemsEnabled or hg.organism.OrganSystemsEnabled()
	local normallyIncapacitated
	if organSystemsEnabled then
		normallyIncapacitated = org.otrub and ((not bleeding_will_stop and not (canwakeup_pain and org.blood > 2000)) or (org.brain > 0.4) or (org.pulse < 15) or (org.o2[1] < 5) or (org.trachea >= 0.5) or org.heartstop or (org.spine3 >= hg.organism.fake_spine3) or (org.spine2 >= hg.organism.fake_spine2))
	else
		normallyIncapacitated = org.otrub and org.blood <= 2200
	end
	if (scavDyingMode and scavDyingMode:GetInt() == 1) and org.otrub then
		-- The ring mode must begin when the player becomes incapacitated, not
		-- wait for asystole/flatline to set the state.
		org.incapacitated = normallyIncapacitated
	elseif normallyIncapacitated then
		org.incapacitated = true
	else
		org.incapacitated = false
	end

	local noNeedle = org.needle <= 0
	local tracheaBlocking = org.trachea > 0.5 and noNeedle
	local tracheaNoO2Regen = org.trachea > 0.5 and (org.o2.curregen or 0) <= 0

	if (org.brain > 0.4) or (org.heart > 0.6) or tracheaBlocking or tracheaNoO2Regen then
		org.critical = true
	else
		org.critical = false
	end

	org.bleed = (bleedoutspeed + bleedoutspeed2 + bleed)
	org.bleed = (bleedoutspeed + bleedoutspeed2)
	org.venousBleed = bleedoutspeed
	org.arterialBleed = bleedoutspeed2
	org.internalBleedRate = bleed
	updateHoldWound(org)
end

util.AddNetworkString("bloodsquirt2")
util.AddNetworkString("vomitsquirt2")

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
	org.blood = math.max(org.blood - 200, 0)
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

	ent:EmitSound(snd or "vomit/vomit5.mp3")
	
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

	ent:EmitSound(snd or "vomit/vomit5.mp3")

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

function hg.organism.CoughBlood(org)
	local ply = org.owner
	local phr = "zcitysnd/real_sonar/" .. (ThatPlyIsFemale(ply) and "female" or "male") .. "_cough" .. math.random(4) .. ".mp3"
	ply:EmitSound(phr)
	ply.phrCld = CurTime() + 2
	ply.lastPhr = phr

	if math.random(5) == 1 then
		org.vomitInThroat = nil

		net.Start("bloodsquirt2")
		net.WriteEntity(ent)
		net.WriteString(bon)
		net.WriteMatrix(mat)
		net.WriteVector(mat:GetTranslation() + mat:GetAngles():Right() * 6 + mat:GetAngles():Forward() * 1)
		net.WriteVector(mat:GetAngles():Right() * 2 * math.Clamp(org.pulse / 70, 0.4, 1))
		net.Broadcast()

		ent:EmitSound("vomit/vomit5.mp3")
	end
end

function hg.organism.BloodDroplet2(owner, org, wound, dir, artery)
	hook.Run("HG_BloodParticleStartedDropping", owner, org, wound, dir, artery)
end

