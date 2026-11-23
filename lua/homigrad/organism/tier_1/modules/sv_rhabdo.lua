local Clamp, max, min = math.Clamp, math.max, math.min

hg.organism.Rhabdo = hg.organism.Rhabdo or {}
local Rhabdo = hg.organism.Rhabdo

Rhabdo.Config = {
	musclePerUnit = 0.6,
	tissuePerPoint = 0.003,
	leakPerMuscle = 0.0015,
	leakStart = 0.25,
	myoglobinMax = 2,

	brokenMuscle = 0.75,
	brokenTissue = 80,
	brokenBurst = 0.25,
	brokenPain = 35,
	brokenShock = 4,

	clearTime = 300,
	clearRenalLoss = 0.8,
	hydrationLow = 40,

	kidneyStart = 0.3,
	kidneyRate = 0.004,
	kidneyCap = 0.95,

	acidPerMyoglobin = 3,
	potassiumStart = 0.4,
	potassiumRenal = 0.5,

	arrhythmiaDelay = 60,
	arrhythmiaRamp = 120,
	arrhythmiaRate = 0.006,
	cardiacStressRate = 0.02,

	weakness = 0.25,
	thoughtAt = 0.35,
}
local CONFIG = Rhabdo.Config

local THOUGHTS = {
	"My muscles are swelling up and burning...",
	"My piss is dark... like cola.",
	"Everything is cramping and swollen.",
}

local BREAK_THOUGHTS = {
	"Something just tore deep in there...",
	"It gave way, the whole thing just gave way.",
}

function Rhabdo.Init(org)
	org.myoglobin = 0
	org.rhabdo = 0
	org.hyperkalemia = 0
	org.rhabdoAcid = 0
	org.rhabdoTime = 0
	org.rhabdoPrev = nil
	org.rhabdoBroken = nil
	org.rhabdoNotified = nil
end

local function limbTissue(org, limb)
	local soft = hg.SoftTissue
	return soft.Get(org, "brute", limb) + soft.Get(org, "burn", limb) + soft.GetDeep(org, "brute", limb) + soft.GetDeep(org, "burn", limb)
end

local function notify(owner, org, list, id)
	if not org.isPly or org.otrub or not IsValid(owner) or not owner.Notify then return end
	owner:Notify(list[math.random(#list)], 45, id, 0, nil, Color(200, 150, 140))
end

local function releaseFromTissue(owner, org)
	local prev = org.rhabdoPrev or {}
	local broken = org.rhabdoBroken or {}
	org.rhabdoPrev, org.rhabdoBroken = prev, broken

	local release, load = 0, 0
	for _, limb in ipairs(hg.SoftTissue.LIMBS) do
		local muscle = hg.SoftTissue.GetMuscle(org, limb)
		local tissue = limbTissue(org, limb)
		local last = prev[limb]
		if last then
			release = release + max(muscle - last[1], 0) * CONFIG.musclePerUnit + max(tissue - last[2], 0) * CONFIG.tissuePerPoint
		end
		prev[limb] = {muscle, tissue}
		load = load + max(muscle - CONFIG.leakStart, 0)

		local isBroken = muscle >= CONFIG.brokenMuscle or tissue >= CONFIG.brokenTissue
		if isBroken and not broken[limb] and last then
			release = release + CONFIG.brokenBurst
			org.painadd = (org.painadd or 0) + CONFIG.brokenPain
			org.shock = (org.shock or 0) + CONFIG.brokenShock
			notify(owner, org, BREAK_THOUGHTS, "rhabdo_break")
		end
		broken[limb] = isBroken or nil
	end

	return release, load
end

function hg.organism.UpdateRhabdo(owner, org, mulTime)
	if org.simpleMode or not org.alive or not hg.SoftTissue or not org.muscle then return end

	local release, load = releaseFromTissue(owner, org)
	local myoglobin = tonumber(org.myoglobin) or 0
	myoglobin = myoglobin + release + mulTime * load * CONFIG.leakPerMuscle

	local renal = Clamp(tonumber(org.renalFailure) or 0, 0, 1)
	local perfusion = Clamp(tonumber(org.circulatoryO2Reserve) or 1, 0.2, 1)
	local hydration = Clamp((tonumber(org.hydration) or 100) / 100, 0.3, 1.2)
	local clear = mulTime / CONFIG.clearTime * (1 - renal * CONFIG.clearRenalLoss) * perfusion * hydration
	myoglobin = Clamp(myoglobin - max(myoglobin, 0.2) * clear, 0, CONFIG.myoglobinMax)
	org.myoglobin = myoglobin

	local rhabdo = Clamp(myoglobin / 1.2, 0, 1)
	org.rhabdo = rhabdo

	local kidneyLoad = myoglobin - CONFIG.kidneyStart
	if kidneyLoad > 0 and (tonumber(org.flank) or 0) < CONFIG.kidneyCap then
		local dry = (tonumber(org.hydration) or 100) < CONFIG.hydrationLow and 1.5 or 1
		org.flank = min((tonumber(org.flank) or 0) + mulTime * kidneyLoad * CONFIG.kidneyRate * dry / perfusion, CONFIG.kidneyCap)
	end

	org.rhabdoAcid = myoglobin * CONFIG.acidPerMyoglobin
	org.hyperkalemia = Clamp((myoglobin - CONFIG.potassiumStart) / 1.2 + renal * CONFIG.potassiumRenal * min(myoglobin * 2, 1) + (tonumber(org.acidosis) or 0) * 0.3, 0, 1)

	org.rhabdoTime = rhabdo > 0.3 and (org.rhabdoTime or 0) + mulTime or max((org.rhabdoTime or 0) - mulTime * 2, 0)
	local sustained = Clamp(((org.rhabdoTime or 0) - CONFIG.arrhythmiaDelay) / CONFIG.arrhythmiaRamp, 0, 1)
	local cardiac = max(org.hyperkalemia, sustained * rhabdo)
	if cardiac > 0.2 and not org.heartstop then
		org.arrhythmia = Clamp((org.arrhythmia or 0) + mulTime * (cardiac - 0.2) * CONFIG.arrhythmiaRate, 0, 1)
		if hg.organism.AddCardiacStress then hg.organism.AddCardiacStress(org, mulTime * (cardiac - 0.2) * CONFIG.cardiacStressRate) end
	end

	if rhabdo < CONFIG.thoughtAt * 0.5 then
		org.rhabdoNotified = nil
	elseif rhabdo >= CONFIG.thoughtAt and not org.rhabdoNotified then
		org.rhabdoNotified = true
		notify(owner, org, THOUGHTS, "rhabdo")
	end
end
