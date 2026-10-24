local min, max = math.min, math.max
local Clamp, Approach, Remap = math.Clamp, math.Approach, math.Remap
local CurTime = CurTime

local cardiacArrestThoughts = {
	"MY CHEST- IT HURTS...",
	"I'M FADING- EVERYTHING IS GOING DARK",
	"I'M DYING... I CAN'T FEEL MY PULSE",
	"gg boi im cooked"
}

local function updateVentricularTachycardia(org, timeValue, o2Value, electricalInstability, traumaRisk, rhythmViability, riskMul)
	if org.heartstop or org.fibrillation then return end
	local now = CurTime()
	local arrhythmia = Clamp(org.arrhythmia or 0, 0, 1)
	local ischemia = Clamp(1 - (org.myocardialOxygen or 1), 0, 1)
	local hypoxia = Clamp((12 - (o2Value or 30)) / 12, 0, 1)
	local reentry = math.max(electricalInstability, ischemia * 0.85, traumaRisk * 0.75, Clamp(org.heart or 0, 0, 1) * 0.6)
	local qtProlongation = math.max(
		hypoxia * 0.8,
		Clamp(org.brainHemorrhage or 0, 0, 1) * 0.7,
		Clamp((33 - (org.temperature or 36.7)) / 5, 0, 1) * 0.6,
		org.seizureActive and 0.4 or 0
	)
	local vt = org.ventricularTachycardia

	if not vt then
		if arrhythmia < 0.3 or now < (org.nextVTRoll or 0) or (org.rhythmRecoveryUntil or 0) > now then return end
		org.nextVTRoll = now + 3
		local polyChance = Clamp((qtProlongation - 0.35) * 0.1 * arrhythmia, 0, 0.12) * riskMul
		local monoChance = Clamp((reentry - 0.3) * 0.16 * arrhythmia, 0, 0.18) * riskMul
		local roll = math.Rand(0, 1)
		if roll < polyChance then
			org.ventricularTachycardia = "polymorphic"
			org.vtStart = now
			org.vtEnd = now + math.Rand(4, 14)
			org.vtRate = math.Rand(210, 260)
		elseif roll < polyChance + monoChance then
			org.ventricularTachycardia = "monomorphic"
			org.vtStart = now
			org.vtRate = Lerp(reentry, 150, 230) + math.Rand(-10, 10)
		end
		return
	end

	org.arrhythmia = math.max(arrhythmia, 0.6)
	org.heartbeat = Approach(org.heartbeat or 0, org.vtRate or 190, timeValue * 80)
	if vt == "polymorphic" then
		org.heartbeat = Clamp(org.heartbeat + math.Rand(-25, 25), 180, 280)
	end

	if now < (org.nextVTRoll or 0) then return end
	org.nextVTRoll = now + 2

	if vt == "polymorphic" then
		if now >= (org.vtEnd or now) then
			org.ventricularTachycardia = nil
			if math.Rand(0, 1) < (0.15 + qtProlongation * 0.35) * riskMul then
				hg.organism.StartFibrillation(org)
			end
		end
		return
	end

	local elapsed = now - (org.vtStart or now)
	local degenerate = Clamp(0.02 + elapsed / 600 + (1 - rhythmViability) * 0.12 + ischemia * 0.05, 0, 0.35) * riskMul
	local roll = math.Rand(0, 1)
	if roll < degenerate then
		hg.organism.StartFibrillation(org)
	elseif reentry < 0.25 and roll < degenerate + 0.25 then
		org.ventricularTachycardia = nil
	end
end

function hg.organism.UpdateCardiacRhythm(owner, org, timeValue, s)
	local terminalHeartRate, peaDuration = hg.organism.TERMINAL_HEART_RATE, hg.organism.PEA_DURATION
	local organSystemsEnabled = s.organSystemsEnabled
	local o2Value = s.o2Value
	local bloodNow = s.bloodNow
	local normalBloodVolume = s.normalBloodVolume
	local cfg = s.cfg
	local myocardialInstability = s.myocardialInstability
	local internalBleedComplication = s.internalBleedComplication
	local hemorrhageRhythmStress = s.hemorrhageRhythmStress
	local hemorrhageElectricalInstability = s.hemorrhageElectricalInstability
	local hypothermiaInstability = s.hypothermiaInstability
	local hypotensionInstability = s.hypotensionInstability
	local rhythmShock = s.rhythmShock
	local rhythmPain = s.rhythmPain
	local rhythmViability = s.rhythmViability
	local rhythmRiskMul = s.rhythmRiskMul
	local restartCirculationActive = s.restartCirculationActive
	local rhythmInstability = s.rhythmInstability
	local arrhythmiaComplication = s.arrhythmiaComplication
	local adrenalineRateTolerance = s.adrenalineRateTolerance
	local hypertensiveEmergency = s.hypertensiveEmergency
	local cardiacWorkload = s.cardiacWorkload
	local criticalHemorrhageDepth = s.criticalHemorrhageDepth
	local terminalCirculatoryFailure = s.terminalCirculatoryFailure
	local ischemia = Clamp(1 - (org.myocardialOxygen or 1), 0, 1)
	local internalBleedPeak = math.max(tonumber(org.internalBleedPeak) or 0, tonumber(org.internalBleed) or 0, 0)
	local internalBleedRhythmRisk = Clamp(internalBleedComplication * math.Clamp(internalBleedPeak / 6, 0, 1), 0, 1)
	local chestRhythmRisk = Clamp(((org.chest or 0) - 0.45) / 0.55, 0, 1)
	local cardiacTraumaRhythmRisk = math.max(myocardialInstability ^ 1.5, chestRhythmRisk * 0.65)
	local traumaRhythmRisk = math.max(internalBleedRhythmRisk * (0.45 + cardiacTraumaRhythmRisk * 0.55), cardiacTraumaRhythmRisk * 0.6)
	org.internalBleedRhythmRisk = internalBleedRhythmRisk
	org.traumaRhythmRisk = traumaRhythmRisk
	local hypercapniaInstability = Clamp(((org.co2 or 0) - 14) / 12, 0, 1)
	local stress = Clamp(hypercapniaInstability * 0.9 + myocardialInstability * 1.2 + ischemia * 0.8 + (org.heartStrain or 0) * 0.35 + (org.cardiacStressExposure or 0) * 0.45 + (org.hypertension or 0) * 0.35 + (org.hypotension or 0) * 0.3 + hemorrhageRhythmStress * 0.35 + hemorrhageElectricalInstability * 0.95 + hypothermiaInstability * 0.35 + traumaRhythmRisk * 0.8 + hypotensionInstability * 0.9 + Clamp(rhythmShock, 0, 80) / 180 + max(rhythmPain - 60, 0) / 220 + max(org.heartbeat - 165, 0) / 190, 0, 2.5)
	local arrhythmiaTarget = Clamp(math.max(stress * 0.42, hemorrhageElectricalInstability * 0.88, traumaRhythmRisk * 0.72, hypercapniaInstability * 0.85) * math.Clamp(org.conditionResistanceMul or 1, 0.05, 1), 0, 1)
	if org.seizureActive then arrhythmiaTarget = math.max(arrhythmiaTarget, 0.15) end
	do
		local arrhythmiaTolerance = Clamp((0.4 - arrhythmiaTarget) / 0.28, 0, 1)
		local rhythmThreat = org.fibrillation or org.heartstop or org.unstableRhythm ~= nil or org.seizureActive
			or hemorrhageElectricalInstability >= 0.3 or hypotensionInstability >= 0.3
		if rhythmThreat then arrhythmiaTolerance = 0 end
		org.arrhythmiaAdapt = Approach(org.arrhythmiaAdapt or 0, arrhythmiaTolerance > 0 and 1 or 0,
			arrhythmiaTolerance > 0 and timeValue / Lerp(arrhythmiaTolerance, 90, 8) or timeValue / 6)
		arrhythmiaTarget = arrhythmiaTarget * (1 - org.arrhythmiaAdapt * arrhythmiaTolerance)
	end
	local arrhythmiaRiseTime = Lerp(hemorrhageElectricalInstability, 25, 6)
	if (org.rhythmRecoveryUntil or 0) > CurTime() then
		arrhythmiaRiseTime = math.max(arrhythmiaRiseTime, 20)
	end
	org.arrhythmia = Approach(org.arrhythmia or 0, arrhythmiaTarget, arrhythmiaTarget > (org.arrhythmia or 0) and timeValue / arrhythmiaRiseTime or timeValue / 90)
	if organSystemsEnabled then
		updateVentricularTachycardia(org, timeValue, o2Value, hemorrhageElectricalInstability, traumaRhythmRisk, rhythmViability, rhythmRiskMul)
	end
	if stress > 0.55 and CurTime() >= (org.nextArrhythmiaRoll or 0) then
		local rollInterval = Clamp(Remap(stress, 0.55, 2.3, 10, 1.25), 1.25, 10)
		org.nextArrhythmiaRoll = CurTime() + rollInterval
		local vfChance = Clamp((0.01 + (stress - 0.55) * 0.15 + traumaRhythmRisk ^ 2 * 0.16 + hypotensionInstability ^ 2 * 0.3) * rhythmViability, 0, 0.65)
		if math.Rand(0, 1) < vfChance then
			hg.organism.StartFibrillation(org)
		end
	end

	if not org.heartstop and bloodNow < normalBloodVolume and org.heartbeat >= terminalHeartRate - 10
		and not restartCirculationActive then
		org.heartstop = true
		org.terminalRhythm = "terminal_tachycardia"
	elseif not org.heartstop and org.heartbeat >= terminalHeartRate then
		org.terminalRhythm = "terminal_tachycardia"
		hg.organism.StartFibrillation(org)
	end

	if org.fibrillation then
		if not org.heartstop then org.o2[1] = max(org.o2[1] - timeValue * 1.8, 0) end
		local vfElapsed = CurTime() - (org.fibrillationStart or CurTime())
		local minVF = math.max(tonumber(cfg.HEMORRHAGE_VF_MIN_SECONDS) or 6, 1)
		local noUsefulOutput = (org.cardiacOutput or 0) < 0.08
		if vfElapsed >= 24 or (noUsefulOutput and vfElapsed >= minVF) then
			org.heartstop = true
			org.terminalRhythm = "ventricular_fibrillation"
		end
	end
	if rhythmInstability > 0 then
		local complicationBurden = math.max(rhythmInstability * 0.7, arrhythmiaComplication)
		org.heartStrain = Clamp((org.heartStrain or 0) + timeValue * complicationBurden / 160, 0, 1)
		org.ischemia = math.min((org.ischemia or 0) + timeValue * complicationBurden * 0.05, 6)
	end
	if ischemia > 0.35 then org.heartStrain = Clamp((org.heartStrain or 0) + timeValue * ischemia / 260, 0, 1) end
	local rateDamageStart = 180 + adrenalineRateTolerance * 30
	local highRateDamage = Clamp((org.heartbeat - rateDamageStart) / math.max(terminalHeartRate - rateDamageStart, 1), 0, 1)
	local catecholamineOverdrive = adrenalineRateTolerance * Clamp((org.heartbeat - 180) / 80, 0, 1)
	org.heartStrain = Clamp((org.heartStrain or 0) + timeValue * (highRateDamage / 120), 0, 1)
	org.heart = Clamp((org.heart or 0) + timeValue * ((org.cardiacStressExposure or 0) ^ 2 * cardiacWorkload ^ 2 * 0.0005 + highRateDamage ^ 2 * 0.0012 + catecholamineOverdrive * 0.00045), 0, 1)
	if ischemia > 0.45 and org.isPly and not org.otrub and (org.lastCardiacPain or 0) < CurTime() then
		org.lastCardiacPain = CurTime() + math.Rand(14, 24)
		org.painadd = org.painadd + math.Rand(4, 9) * ischemia
		org.shock = math.max(org.shock, 10 + ischemia * 22)
	end
	hg.organism.UpdateCirculatoryEffects(owner, org, timeValue, o2Value, arrhythmiaComplication)

	local bradyLowRate = math.max(tonumber(cfg.BRADYCARDIA_LOW_OUTPUT_HR_BPM) or 45, 1)
	local bradyLowReserve = math.Clamp(tonumber(cfg.BRADYCARDIA_LOW_OUTPUT_RESERVE) or 0.34, 0.05, 0.8)
	local bradyRateDepth = math.Clamp((bradyLowRate - (org.heartbeat or 0)) / math.max(bradyLowRate - 15, 1), 0, 1)
	local bradyOutputDepth = math.Clamp((bradyLowReserve - (org.cardiacOutput or 0)) / bradyLowReserve, 0, 1)
	local bradyPerfusionDepth = math.Clamp((bradyLowReserve - (org.perfusion or 0)) / bradyLowReserve, 0, 1)
	local bradyLowOutputSeverity = math.min(bradyRateDepth, math.max(bradyOutputDepth, bradyPerfusionDepth))
	org.bradycardicLowOutputSeverity = bradyLowOutputSeverity
	if not org.heartstop and bradyLowOutputSeverity > 0 then
		local gain = timeValue * (0.35 + bradyLowOutputSeverity ^ 2 * 1.65)
		org.bradycardicLowOutputTime = math.min((org.bradycardicLowOutputTime or 0) + gain, 20)
	else
		org.bradycardicLowOutputTime = math.Approach(org.bradycardicLowOutputTime or 0, 0, timeValue * 1.5)
	end

	local slowRateK = math.Clamp((55 - (org.heartbeat or 70)) / 30, 0, 1)
	local hypovolemiaK = math.Clamp((1 - bloodNow / normalBloodVolume) / 0.35, 0, 1)
	local hypovolemicBradyStrain = org.heartstop and 0 or slowRateK * hypovolemiaK
	org.hypovolemicBradyStrain = hypovolemicBradyStrain
	if hypovolemicBradyStrain > 0 then
		org.heartStrain = Clamp((org.heartStrain or 0) + timeValue * hypovolemicBradyStrain / 25, 0, 1)
		org.heart = Clamp((org.heart or 0) + timeValue * hypovolemicBradyStrain ^ 2 * 0.002, 0, 1)
		org.bradycardicLowOutputTime = math.min((org.bradycardicLowOutputTime or 0) + timeValue * hypovolemicBradyStrain, 20)
	end

	if organSystemsEnabled then
		local hemorrhageDrivenLowOutput = criticalHemorrhageDepth > 0
		local failedCirculation = (org.pulse < 10 and not hemorrhageDrivenLowOutput or terminalCirculatoryFailure) and not restartCirculationActive
		local failedHypotension = (org.cardiacStressExposure or 0) > 0.9 and (org.cardiacOutput or 0) < 0.08 and not restartCirculationActive
		local failedBradyOutput = (org.bradycardicLowOutputTime or 0) >= (tonumber(cfg.BRADYCARDIA_ARREST_EXPOSURE) or 8)
			and (org.cardiacOutput or 0) < (tonumber(cfg.BRADYCARDIA_ARREST_OUTPUT) or 0.22)
			and (org.perfusion or 0) < (tonumber(cfg.BRADYCARDIA_ARREST_PERFUSION) or 0.28)
			and (not hemorrhageDrivenLowOutput or hypovolemicBradyStrain > 0.2)
			and not restartCirculationActive
		local failedBradyStrain = hypovolemicBradyStrain > 0.25 and (org.heartStrain or 0) >= 0.95 and not restartCirculationActive
		if failedCirculation or failedHypotension or failedBradyOutput or failedBradyStrain or org.brain >= 0.85 or org.heart >= 1 then org.heartstop = true end
		if org.temperature > 42 then org.heartstop = true end
	end
	local hemorrhageDrivenLowOutput = criticalHemorrhageDepth > 0
	if ((org.pulse < 10 and not hemorrhageDrivenLowOutput) or (org.brain >= 0.6 and not (hg.organism.IsBrainDamageIgnored and hg.organism.IsBrainDamageIgnored(org)))) and not restartCirculationActive then org.heartstop = true end
	if org.temperature > 42 then org.heartstop = true end
	if org.heartstop and not org.fibrillation and org.terminalRhythm ~= "ventricular_fibrillation" and org.terminalRhythm ~= "asystole"
		and (org.heartbeat or 0) >= 140 and (org.arrhythmia or 0) >= 0.72
		and (ischemia >= 0.35 or (org.heartStrain or 0) >= 0.3 or (org.heartbeat or 0) >= 200) then
		org.terminalRhythm = "terminal_tachycardia"
	end
	if org.heartstop then
		if org.terminalRhythm ~= "ventricular_fibrillation" then org.fibrillation = false end
		org.arrhythmia = math.Approach(org.arrhythmia or 0, 0, timeValue * 0.35)
	end

	if org.temperature < 34 or org.temperature > 38 or org.blood < 4000 or org.pain > 20 then
		org.fear = math.max(org.fear, 0)
	end

	hg.organism.UpdateBodyTemperature(owner, org, timeValue)
	
	if not org.heartstop then
		org.last_heartbeat = CurTime()
	end

	if org.heartstop then
		if not org.cardiacArrestStart then
			org.cardiacArrestStart = CurTime()
			org.cardiacArrestO2Start = math.Clamp(org.o2 and org.o2[1] or 0, 0, org.o2 and org.o2.range or 30)
		end

		local arrestElapsed = math.max(CurTime() - org.cardiacArrestStart, 0)
		if org.ventricularTachycardia and arrestElapsed < peaDuration then
			org.heartbeat = org.vtRate or 200
			org.ecgState = org.ventricularTachycardia == "polymorphic" and "torsades_de_pointes" or "ventricular_tachycardia"
		elseif org.terminalRhythm == "ventricular_fibrillation" and arrestElapsed < peaDuration then
			org.heartbeat = 260
			org.ecgState = "ventricular_fibrillation"
		elseif org.terminalRhythm == "terminal_tachycardia" and arrestElapsed < peaDuration then
			org.heartbeat = 180
			org.ecgState = "terminal_tachycardia"
		elseif arrestElapsed < peaDuration then
			local peaTarget = Lerp(math.Clamp(arrestElapsed / peaDuration, 0, 1), 60, 20)
			org.heartbeat = math.Approach(org.heartbeat or terminalHeartRate, peaTarget, timeValue * 120)
			org.ecgState = "pea"
		else
			org.heartbeat = math.Approach(org.heartbeat or 0, 0, timeValue * 18)
			org.ecgState = org.heartbeat < 1 and "asystole" or "pea"
		end
		if arrestElapsed >= peaDuration then
			org.terminalRhythm = nil
			org.ventricularTachycardia = nil
		end

	else
		org.cardiacArrestStart = nil
		org.cardiacArrestO2Start = nil
		org.ecgState = hg.organism.GetECGState(org.heartbeat or 0, false, org)
	end

	if org.heartstop and org.terminalCirculatoryFailure and bloodNow <= (tonumber(hg.organism.BLEEDOUT_DEATH_BLOOD) or 2000) and not restartCirculationActive then
		org.heartbeat = 0
		org.pulse = 0
		org.ecgState = "asystole"
	end

	if org.heartstop then
		org.heartstoptime = org.heartstoptime or CurTime()
		if org.isPly and not org.otrub and not org.owner.hgHeartstopThought then
			org.owner.hgHeartstopThought = true
			org.owner:InterruptThought(cardiacArrestThoughts[math.random(#cardiacArrestThoughts)], Color(255, 90, 90, 255))
		end
	else
		if org.isPly then
			org.owner.hgHeartstopThought = nil
			org.owner:ResetNotification("heartstop")
		end
		org.heartstoptime = nil
	end

	hg.organism.EnforceBloodCirculationLimit(org)
end
