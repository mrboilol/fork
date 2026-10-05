CAI.Personality = CAI.Personality or {}
local PS = CAI.Personality

PS.Traits = {
    Aggressive = { aggression = 0.35, courage = 0.15 },
    Defensive = { aggression = -0.30, patience = 0.25 },
    Patient = { patience = 0.40, accuracy = 0.10 },
    Brave = { courage = 0.40 },
    Cowardly = { courage = -0.45, aggression = -0.15 },
    Calm = { accuracy = 0.15, suppResist = 0.25 },
    Impulsive = { patience = -0.35, aggression = 0.20 },
    Accurate = { accuracy = 0.35 },
    PoorShot = { accuracy = -0.35 },
    Reckless = { aggression = 0.45, accuracy = -0.10, courage = 0.2 },
}

local traitNames = {}
for name in pairs(PS.Traits) do traitNames[#traitNames + 1] = name end

function PS.Generate()
    local picked, stats = {}, {
        aggression = 0, accuracy = 0, courage = 0, patience = 0, suppResist = 0,
    }
    local count = math.random(1, 2)
    local pool = table.Copy(traitNames)
    for i = 1, count do
        if #pool == 0 then break end
        local idx = math.random(#pool)
        local name = table.remove(pool, idx)
        picked[#picked + 1] = name
        for stat, mod in pairs(PS.Traits[name]) do
            stats[stat] = (stats[stat] or 0) + mod
        end
    end

    stats.aggression = math.Clamp(stats.aggression + math.Rand(-0.1, 0.1), -0.8, 0.8)
    stats.accuracy = math.Clamp(stats.accuracy + math.Rand(-0.1, 0.1), -0.8, 0.8)
    stats.courage = math.Clamp(stats.courage + math.Rand(-0.1, 0.1), -0.8, 0.8)
    stats.patience = math.Clamp(stats.patience + math.Rand(-0.1, 0.1), -0.8, 0.8)
    return { traits = picked, stats = stats }
end

function PS.ApplyProficiency(data)
	local npc = data.ent
	if not IsValid(npc) or not npc.SetCurrentWeaponProficiency then return end
	if npc:GetNWBool("JudgeControlsAccuracy") then return end
	local aimSkill = CAI.AimSkill()
	local diff = CAI.Difficulty()
	local score = 2 + data.personality.stats.accuracy * 2 + (diff - 1) * 2.2 + (aimSkill - 0.5) * 4
	if aimSkill == 1 then score = WEAPON_PROFICIENCY_PERFECT end
	if aimSkill < 1 and CAI.CVBool("cai_morale") and data.morale < CAI.Config.Morale.ShakenThreshold then
		score = score - 1
	end
	if aimSkill < 1 and CAI.CVBool("cai_suppression") then
		for threshold, penalty in pairs(CAI.Config.Suppression.AccuracyPenaltySteps) do
			if data.suppression >= threshold then score = math.min(score, 4 - penalty) end
		end
	end
	if npc.overshootTime and npc.overshootTime > CurTime() and npc.didResetProficiency == false then
		local overshootProficiency = GetConVar("nos_overshoot_proficiency")
		if overshootProficiency then score = math.min(score, overshootProficiency:GetInt()) end
	end
	npc:SetCurrentWeaponProficiency(math.Clamp(math.Round(score), 0, 4))
	if isfunction(npc.SetMaxYawSpeed) and isfunction(npc.GetMaxYawSpeed) then
		data.baseYawSpeed = data.baseYawSpeed or npc:GetMaxYawSpeed()
		if data.baseYawSpeed and data.baseYawSpeed > 0 then
			npc:SetMaxYawSpeed(data.baseYawSpeed * (0.4 + aimSkill * 1.1))
		end
	end
end
