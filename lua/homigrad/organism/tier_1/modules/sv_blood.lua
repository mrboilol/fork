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
	org.internalBleed = 0
	org.internalBleedHeal = 0
	org.arteria = 0
	org.rarmartery = 0
	org.larmartery = 0
	org.subclavianR = 0
	org.subclavianL = 0
	org.rlegartery = 0
	org.llegartery = 0
	org.spineartery = 0
	org.bleedStart = 0
	org.wounds = {}
	org.arterialwounds = {}
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

	org.pressingWound = false
	org.pressingWoundTarget = nil
	org.pressingWoundEfficiency = 0
	org.pressingWoundMul = 1.0
	org.pressingWoundNextToggle = 0
	org.neckslitStandUpSuppressed = false
end



local about_to_puke = {
	"I feel like I'm gonna puke any second now...",
	"Not feeling good...",
	"Gonna puke right now...",
	"I want to vomit...",
}

local vecZero = Vector(0, 0, 0)
module[2] = function(owner, org, mulTime)
	local adrenaline = math.min(org.adrenaline, 2)
	local isPlayer = owner:IsPlayer()
	org.coagulation_multiplier = 1
	org.blood_regeneration_multiplier = 1

	org.bleedingmul = 1.0

	if org.liver > 0 then
		org.coagulation_multiplier = org.coagulation_multiplier * (1 - org.liver * 0.5)
		org.blood_regeneration_multiplier = org.blood_regeneration_multiplier * (1 - org.liver * 0.75)
		org.bleedingmul = org.bleedingmul * (1 + org.liver * 0.5)
		-- Liver-induced internal bleeding stops when tranexamic acid is administered
		if (org.tranexamic_acid or 0) <= 0 then
			org.internalBleed = org.internalBleed + (org.liver * mulTime * 0.05)
		end
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

	if org.isPly and not org.otrub and org.blood < 2200 then org.owner:Notify(math.random(2) == 1 and "I cant feel anything..." or (math.random(2) == 1 and "nga im fried 😭") or "I feel too numb...",60,"blood2",0) end

	if org.internalBleed < 0.5 and org.bleed < 0.05 and org.pulse > 5 then
		local timeSinceBleed = CurTime() - (org.lastBleedTime or 0)
		local regenBoost = 1 + math.Clamp(timeSinceBleed / 30, 0, 2)
		local goodmood = math.Clamp(org.goodmood or 0, 0, 1)
		local goodmoodBonus = 1 + goodmood * 0.3
		org.blood = min(org.blood + mulTime * 5 * (adrenaline * 1.15 + 1) * (org.satiety / 100 + 1) * org.pulse / 70 * org.blood_regeneration_multiplier * (org.bloodpressure / 110) * regenBoost * goodmoodBonus, 5000)
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

	if org.arteria == 1 then
		local o2DebuffRate = 5
		-- Stronger O2 debuff when blood reaches 3750 or below
		if org.blood <= 3750 then
			o2DebuffRate = 15 -- Triple the debuff rate
			-- Notify player about severe oxygen deprivation from arterial bleeding
			if org.isPly and not org.otrub and (org._arteriaO2NotifyTime or 0) + 30 < CurTime() then
				org.owner:Notify("I can't breathe... my throat is bleeding...", 30, "arteria_o2", 0)
				org._arteriaO2NotifyTime = CurTime()
			end
		end
		org.o2[1] = math.max(org.o2[1] - mulTime * o2DebuffRate, 0)
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
	-- 3500: moderate O2 debuff, consciousness cap 0.85 (compensation delayed)
	-- 3000: compensation tachycardia begins, heart rate rises toward 125
	-- 2750: heavy compensation kicks in, HR spikes toward 190, blood-based heartstop risk begins
	-- 2500: pulse destabilizes, O2 drains hard, ischemia begins
	-- 2000: full ischemic collapse (handled below)
	local bloodConsciousnessCap = 1
	local tempMul = math.Clamp(((org.temperature < 30 and org.temperature - 30 or 0) * 0.25 + 1), 0.25, 1)

	if org.blood < 4500 then
		-- First symptoms: periodic notify
		if org.isPly and not org.otrub and (org._blood4500NotifyTime or 0) + 90 < CurTime() then
			org.owner:Notify("I feel a little lightheaded...", 15, "blood_4500", 0)
			org._blood4500NotifyTime = CurTime()
		end
	end

	if org.blood < 4000 then
		-- Mild O2 debuff: reduced O2 delivery (slight)
		org.o2[1] = math.max(org.o2[1] - mulTime * 0.4, 0)
		-- Soft consciousness cap at 0.95
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, 0.95)
		if org.isPly and not org.otrub and (org._blood4000NotifyTime or 0) + 60 < CurTime() then
			org.owner:Notify("I'm starting to feel weak...", 15, "blood_4000", 0)
			org._blood4000NotifyTime = CurTime()
		end
	end

	if org.blood < 3500 then
		-- Moderate O2 debuff: body struggling to deliver O2
		org.o2[1] = math.max(org.o2[1] - mulTime * 0.8, 0)
		-- Delayed compensation: only mild pulse nudge toward 90
		if org.pulse < 90 and not adrenalineStabilizer then
			org.pulse = math.min(org.pulse + mulTime * 0.4, 90)
		end
		-- Consciousness cap drops to 0.85
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, 0.85)
		if org.isPly and not org.otrub and (org._blood3500NotifyTime or 0) + 45 < CurTime() then
			org.owner:Notify("My head is spinning... I can barely focus.", 15, "blood_3500", 0)
			org._blood3500NotifyTime = CurTime()
		end
	end

	if org.blood < 3000 then
		-- Moderate O2 debuff: body really struggling for blood
		org.o2[1] = math.max(org.o2[1] - mulTime * 1.5, 0)
		-- Compensation tachycardia begins, heart rate rises toward 125
		if org.pulse < 125 and not adrenalineStabilizer then
			org.pulse = math.min(org.pulse + mulTime * 1.0, 125)
		end
		-- Consciousness cap drops to 0.75
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, 0.75)
		if org.isPly and not org.otrub and (org._blood3000NotifyTime or 0) + 30 < CurTime() then
			org.owner:Notify("I can't... get enough air. Everything is heavy.", 15, "blood_3000", 0)
			org._blood3000NotifyTime = CurTime()
		end
	end

	if org.blood < 2750 then
		-- Heavy compensation: heart races desperately to compensate
		org.o2[1] = math.max(org.o2[1] - mulTime * 2.0, 0)
		if org.pulse < 190 and not adrenalineStabilizer then
			org.pulse = math.min(org.pulse + mulTime * 2.0, 190)
		end
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, 0.7)

		-- Blood-based heartstop: big chance only in the 2750-2000 range
		if org.blood >= 2000 then
			if not org._blood_heartstop_check or CurTime() > org._blood_heartstop_check then
				org._blood_heartstop_check = CurTime() + 1
				local depth = math.Clamp((2750 - org.blood) / 750, 0, 1) -- 0 at 2750, 1 at 2000
				local chance = 0.05 + depth * 0.15 -- 5% to 20% per second
				-- Adrenaline stabilizes the heart during compensation
				if adrenalineStabilizer then
					chance = chance * math.max(0, 1 - math.min(totalAdrenaline * 0.25, 0.8))
				end
				if org.givingUp then chance = chance * 1.5 end
				if chance > 0 and math.random() < chance then
					org.heartstop = true
				end
			end
		end
	end

	if org.blood < 2500 then
		-- Steady O2 drain accelerates - hemoglobin too low for organ delivery
		org.o2[1] = math.max(org.o2[1] - mulTime * 4.0, 0)
		-- Pulse now destabilizing: starts to drop from overexertion
		if not adrenalineStabilizer then
			org.pulse = math.max(org.pulse - mulTime * 0.8, 40)
		end
		-- Slow ischemia creep begins
		if not adrenalineStabilizer and not hasAntiIschemia then
			org.ischemia = math.min(org.ischemia + mulTime * 0.004, 1.0)
		end
		-- Consciousness slips lower: cap now 0.55
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, 0.55)
		if org.isPly and not org.otrub and (org._blood2500NotifyTime or 0) + 20 < CurTime() then
			org.owner:Notify("I feel cold... I can't think straight.", 15, "blood_2500", 0)
			org._blood2500NotifyTime = CurTime()
		end
	end

	-- Hard floor: at 2100 begin collapsing to 0 by 2000
	if org.blood < 2100 then
		bloodConsciousnessCap = math.min(bloodConsciousnessCap, math.max((org.blood - 2000) / 100, 0))
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
			local bleed = rand1 * wound[1] * mulTime * math.max(pulse, 20) / 70 * 2.0 * (1 - math.min(adrenaline / 6, 0.5)) * bleedMul * 0.02
			local coagulate = 2 * mulTime * rand2 * (adrenaline * 0.1 + 1) * (org.satiety / 100 + 1) * 0.04 * coagMul
			local isPressed = org.pressingWound and (wound[4] == org.pressingWoundTarget)
			local pressureMul = isPressed and (org.pressingWoundMul or 1.0) or 1.0
			bleedoutspeed = bleedoutspeed + bleed / rand1 * 3 * pressureMul
			coagulatespeed = coagulatespeed + coagulate / rand2
			
			wound[5] = time
			org.blood = max(org.blood - bleed * pressureMul, 1)
				
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
			owner:SetNetVar("wounds", org.wounds)
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
	
	-- Track stand-up from ragdoll: suppress neck bleeding reduction until ragdolled again
	if isPlayer then
		local isRagdoll = IsValid(owner.FakeRagdoll)
		if org._wasRagdoll and not isRagdoll then
			org.neckslitStandUpSuppressed = true
		end
		if isRagdoll then
			org.neckslitStandUpSuppressed = false
		end
		org._wasRagdoll = isRagdoll
	end
	
	-- Neck bleeding reduction based on hands
	if isPlayer and not IsValid(owner.FakeRagdoll) and org.neckslit and not org.neckslitStandUpSuppressed then
		local wep = owner:GetActiveWeapon()
		local handsOnNeck = 0
		if not IsValid(wep) or wep:GetClass() == "weapon_hands_sh" then
			handsOnNeck = 2
		else
			local twohands = wep.TwoHands or (wep.HoldType and (wep.HoldType == "ar2" or wep.HoldType == "shotgun" or wep.HoldType == "smg" or wep.HoldType == "crossbow" or wep.HoldType == "rpg"))
			if twohands then
				handsOnNeck = 0
			else
				handsOnNeck = 1
			end
		end
		
		if handsOnNeck == 2 then
			org.neckslitBleedingReduction = 0.1
		elseif handsOnNeck == 1 then
			org.neckslitBleedingReduction = 0.55
		else
			org.neckslitBleedingReduction = 1.0
		end
	end

	-- Explicit wound pressure reduction (Alt+E)
	if isPlayer and not IsValid(owner.FakeRagdoll) and org.pressingWound then
		org.pressingWoundMul = 1.0 - (0.6 * math.Clamp(org.pressingWoundEfficiency or 0, 0, 1))
	else
		org.pressingWoundMul = 1.0
	end

	local arterialToRemove = {}
	for i, wound in pairs(org.arterialwounds) do
		local neckMul = (wound[7] == "arteria") and (org.neckslitBleedingReduction or 1.0) or 1.0
		local isPressed = org.pressingWound and (wound[7] == org.pressingWoundTarget)
		local pressureMul = isPressed and (org.pressingWoundMul or 1.0) or 1.0
		bleedoutspeed2 = bleedoutspeed2 + wound[1] * mulTime * 0.2 * math.max(pulse, 20) / 80 * neckMul * pressureMul

		if wound[5] + next_arterypump * 2 < time then
			local pos, ang = ent:GetBonePosition(ent:LookupBone(wound[4]))
			wound[5] = time
			org.blood = max(org.blood - wound[1] * mulTime * 4.5 * math.max(pulse, 20) / 80 * neckMul * pressureMul, 1)
			if isAlive or not isPlayer then
				local dir = wound[6]
				local len = dir:Length()
				local _, dir = LocalToWorld(vecZero, dir:Angle(), vecZero, ang)
				dir = -dir:Forward() * len
				hg.organism.BloodDroplet2(owner, org, wound, ownerVel + VectorRand(-10, 10) + dir, true)
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
		owner:SetNetVar("arterialwounds", org.arterialwounds)
	end
	bleedoutspeed2 = bleedoutspeed2 / next_arterypump

	-- At 2000: ischemic collapse begins - O2 starved, heart under stress, consciousness crashes
	if org.blood <= 2000 then
		local ischemicDepth = math.Clamp((2000 - org.blood) / 2000, 0, 1) -- 0 at 2000, 1 at 0
		local ischemicRate = 0.025 + ischemicDepth * 0.10 -- ramps from 0.025 to 0.125/s
		if not adrenalineStabilizer and not hasAntiIschemia then
			org.ischemia = math.min(org.ischemia + mulTime * ischemicRate, 1.0)
		end
		-- O2 delivery collapses: blood cant carry enough oxygen
		org.o2[1] = math.max(org.o2[1] - mulTime * (3 + ischemicDepth * 12), 0)
		-- Heart under ischemic stress: rate destabilizes
		if not adrenalineStabilizer then
			org.pulse = math.max(org.pulse - mulTime * (1 + ischemicDepth * 4), 0)
		end
		-- Consciousness drain at 2000 (already handled by cap above, extra drain below 1800)
		if org.blood < 1800 then
			org.consciousness = math.max((org.consciousness or 1) - mulTime * (0.5 + ischemicDepth * 2.0), 0)
		end
		-- Notify once entering ischemic threshold
		if org.isPly and not org.otrub and (org._ischemicNotifyTime or 0) + 20 < CurTime() then
			org.owner:Notify("My chest... I can't breathe right...", 20, "ischemic_collapse", 0)
			org._ischemicNotifyTime = CurTime()
		end
	end
	
	if hasAntiIschemia then
		org.ischemia = math.max((org.ischemia or 0) - mulTime * 0.05, 0)
	end
	if adrenalineStabilizer then
		org.ischemia = math.max((org.ischemia or 0) - mulTime * 0.01 * totalAdrenaline, 0)
	end

	local bleed = org.internalBleed / 35 -- + org.lungsR[3] + org.lungsL[3]
	
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
	
	if org.otrub and ((not bleeding_will_stop and not (canwakeup_pain and org.blood > 2000)) or (org.brain > 0.4) or (org.pulse < 15) or (org.o2[1] < 5) or (org.trachea >= 0.5) or org.heartstop or (org.spine3 >= hg.organism.fake_spine3) or (org.spine2 >= hg.organism.fake_spine2)) then
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
