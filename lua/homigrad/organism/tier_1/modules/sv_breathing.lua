local organism = hg.organism

organism.Breathing = organism.Breathing or {}

local Breathing = organism.Breathing

Breathing.Config = {
	minEfficiency = 0.35,
	minDepth = 0.4,
	minRate = 4,
	maxRate = 40,
	laboredAt = 0.5,
	coughInterval = {8, 16},
	gaspInterval = {6, 12},
	laboredInterval = {12, 20},
	coughSound = "zcitysnd/%s/cough_%d.mp3",
	coughSoundCount = 4,
	coughVolume = 60,
}

local function unit(value)
	return math.Clamp(tonumber(value) or 0, 0, 1)
end

Breathing.Sources = {
	toxin = {
		value = function(org)
			local state = hg.SimpleHealth.GetState(org)

			return state and unit(state.toxin / 100) or 0
		end,
		start = 0.25,
		efficiency = 0.6,
		rate = 4,
		labored = 1,
		cough = 0.6,
		gasp = 0.8,
	},
	chest = {
		value = function(org)
			return math.max(hg.SoftTissue.GetSoftImpairment(org, "torso"), unit(org.chest) * 0.6)
		end,
		efficiency = 0.75,
		rate = 6,
	},
	torsoMuscle = {
		value = function(org) return unit(hg.SoftTissue.GetMuscle(org, "torso")) end,
		depth = 0.8,
		rate = 2,
		labored = 1,
	},
	pain = {
		value = function(org) return unit((tonumber(org.pain) or 0) / 100) end,
		start = 0.3,
		rate = 8,
		depth = 0.75,
		gasp = 0.8,
	},
	sedation = {
		value = function(org)
			local dose = (tonumber(org.analgesia) or 0) + (tonumber(org.painkiller) or 0) * 0.3
				+ (tonumber(org.tranquilizer) or 0)

			return unit(dose / 2)
		end,
		rate = -4,
		depth = 0.8,
	},
	bloodLoss = {
		value = function(org)
			return math.max(unit((4500 - (tonumber(org.blood) or 5000)) / 2000), unit((tonumber(org.shock) or 0) / 80))
		end,
		rate = 8,
		depth = 0.8,
	},
	smoke = {
		value = function(org) return unit((tonumber(org.fireCOExposure) or 0) / 10) end,
		efficiency = 0.7,
		cough = 0.5,
	},
}

local function due(org, key, interval)
	local now = CurTime()
	if (org[key] or 0) > now then return false end

	org[key] = now + math.Rand(interval[1], interval[2])

	return true
end

local function emitSymptoms(owner, org, labored, cough, gasp)
	if not owner:IsPlayer() or org.otrub or not org.lungsfunction then return end

	local config = Breathing.Config
	if cough and due(org, "nextBreathCough", config.coughInterval) then
		local voice = ThatPlyIsFemale and ThatPlyIsFemale(owner) and "female" or "male"
		local path = string.format(config.coughSound, voice, math.random(config.coughSoundCount))
		hg.GetCurrentCharacter(owner):EmitSound(path, config.coughVolume)
	end

	if gasp and due(org, "nextBreathGasp", config.gaspInterval) then
		local female = ThatPlyIsFemale and ThatPlyIsFemale(owner)
		local path = female and "rotten_agony/gasp_female" .. math.random(13) .. ".ogg"
			or "rotten_agony/gasp_male" .. math.random(7) .. ".ogg"
		hg.GetCurrentCharacter(owner):EmitSound(path, config.coughVolume)
		hg.ChatLog.Emit("gasp", owner)
	end
	if labored >= config.laboredAt and due(org, "nextBreathLabored", config.laboredInterval) then
		hg.ChatLog.Emit("agonal", owner)
	end
end

function Breathing.Apply(owner, org)
	local config = Breathing.Config
	local efficiency, rate, depth, labored = 1, 0, 1, 0
	local cough, gasp = false, false

	for _, source in pairs(Breathing.Sources) do
		local start = source.start or 0
		local level = math.Clamp((source.value(org) - start) / (1 - start), 0, 1)
		if level > 0 then
			efficiency = efficiency * Lerp(level, 1, source.efficiency or 1)
			depth = depth * Lerp(level, 1, source.depth or 1)
			rate = rate + level * (source.rate or 0)
			labored = math.max(labored, level * (source.labored or 0))
			cough = cough or (source.cough ~= nil and level >= source.cough)
			gasp = gasp or (source.gasp ~= nil and level >= source.gasp)
		end
	end

	org.breathEfficiency = math.max(efficiency, config.minEfficiency)
	org.breathDepth = math.max(depth, config.minDepth)
	org.breathLabored = math.Round(labored, 2)
	org.respiratoryRate = math.Clamp(math.Round((org.respiratoryRate or 14) + rate), config.minRate, config.maxRate)

	emitSymptoms(owner, org, labored, cough, gasp)
end
