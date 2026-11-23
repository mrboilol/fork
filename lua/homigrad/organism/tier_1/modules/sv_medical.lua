local min, max, Clamp, Approach = math.min, math.max, math.Clamp, math.Approach
hg.organism.module.medical_system = {}
local module = hg.organism.module.medical_system
local function get_role(ply)
	if not IsValid(ply) then return "none" end
	local role = string.lower(tostring(ply.Profession or ""))
	if role == "doctor" or role == "surgeon" or role == "medic" or role == "paramedic" then
		return role
	end
	return "none"
end
local function get_skill(role)
	if role == "surgeon" then return 1.0 end
	if role == "doctor" then return 0.9 end
	if role == "paramedic" then return 0.7 end
	if role == "medic" then return 0.65 end
	return 0.15
end
local function is_alive_org(org)
	return org and org.alive and IsValid(org.owner)
end
local dislocation_order = {"lleg", "rleg", "larm", "rarm", "jaw"}
local dislocation_bones = {
	lleg = {"lleg", "L_Thigh", "L_Calf", "L_Foot"},
	rleg = {"rleg", "R_Thigh", "R_Calf", "R_Foot"},
	larm = {"larm", "L_UpperArm", "L_Forearm", "L_Hand"},
	rarm = {"rarm", "R_UpperArm", "R_Forearm", "R_Hand"},
	jaw = {"jaw", "skull", "Head"},
}

function hg.organism.GetBandageDislocation(org, bone)
	if not org then return end
	if not bone then
		for _, limb in ipairs(dislocation_order) do
			if org[limb .. "dislocation"] then return limb end
		end
		return
	end

	local boneName = tostring(bone)
	for _, limb in ipairs(dislocation_order) do
		if org[limb .. "dislocation"] then
			for _, match in ipairs(dislocation_bones[limb]) do
				if boneName == match or string.find(boneName, match, 1, true) then return limb end
			end
		end
	end
end

function hg.organism.CompleteDislocationFix(org, limb)
	if not org or not limb or not org[limb .. "dislocation"] then return false end
	hg.organism.ClearLimbDislocation(org, limb)
	if hg.fakeBoneFlop and hg.fakeBoneFlop.ReconcileLimb and hg.fakeBoneFlop.ReconcileLimb(org, limb) then
		hg.fakeBoneFlop.ScheduleRebuild(org.owner)
	end
	org.painadd = (org.painadd or 0) + 5
	org.fearadd = (org.fearadd or 0) + 0.1
	if IsValid(org.owner) then
		org.owner:EmitSound("physics/flesh/flesh_impact_hard6.wav", 65)
	end
	return true
end

function hg.organism.ApplyBandageBoneTreatment(org, key, amount, splinting)
	if not org or not key then return 0 end
	local isLimb = key == "lleg" or key == "rleg" or key == "larm" or key == "rarm"
	if isLimb then hg.organism.SyncLimbSegments(org, key) end
	if isLimb and not splinting and hg.IsLimbFractured(org, key)
		and not (hg.IsLimbSplinted and IsValid(org.owner) and hg.IsLimbSplinted(org.owner, key)) then
		return 0
	end
	local current = math.Clamp(tonumber(org[key]) or 0, 0, 1)
	if current < 0.05 then return 0 end

	local target
	if key == "skull" then
		target = current >= 0.6 and 0.59 or math.max(current - (amount or 0.25), 0)
		org.bandagedskull = true
	elseif key == "chest" then
		target = current >= 1 and 0.99 or math.max(current - (amount or 0.25), 0)
		org.bandagedchest = true
	else
		target = isLimb and hg.IsLimbFractured(org, key) and current * 0.99 or current >= 1 and 0.99 or math.max(current - (amount or 0.25), 0)
	end

	org[key] = target
	if isLimb then hg.organism.SyncLimbSegments(org, key) end
	if key ~= "skull" and key ~= "chest" and target < 1 and hg.fakeBoneFlop and hg.fakeBoneFlop.ReconcileLimb and hg.fakeBoneFlop.ReconcileLimb(org, key) then
		hg.fakeBoneFlop.ScheduleRebuild(org.owner)
	end
	return current - target
end
local limb_from_bone = {
	["ValveBiped.Bip01_L_UpperArm"] = "larmup",
	["ValveBiped.Bip01_L_Forearm"] = "larm",
	["ValveBiped.Bip01_L_Hand"] = "lhand",
	["ValveBiped.Bip01_R_UpperArm"] = "rarmup",
	["ValveBiped.Bip01_R_Forearm"] = "rarm",
	["ValveBiped.Bip01_R_Hand"] = "rhand",
	["ValveBiped.Bip01_L_Thigh"] = "llegup",
	["ValveBiped.Bip01_L_Calf"] = "lleg",
	["ValveBiped.Bip01_L_Foot"] = "lleg",
	["ValveBiped.Bip01_R_Thigh"] = "rlegup",
	["ValveBiped.Bip01_R_Calf"] = "rleg",
	["ValveBiped.Bip01_R_Foot"] = "rleg",
}
local function apply_med_error(actor, org, action, ctx)
	if not IsValid(actor) or not actor:IsPlayer() or not actor:HasTrait("clumsy") then return false end
	local baseChance = 0.12
	if action == "needle" then baseChance = 0.3 end
	if action == "tourniquet" then baseChance = 0.25 end
	if math.Rand(0, 1) > baseChance then return false end
	org.medical_errors = (org.medical_errors or 0) + 1
	if action == "needle" then
		org.lungsL[1] = min(org.lungsL[1] + 0.35, 1)
		org.lungsR[1] = min(org.lungsR[1] + 0.35, 1)
		org.pneumothorax = min((org.pneumothorax or 0) + 0.5, 1)
		org.shock = min((org.shock or 0) + 25, 95)
		org.owner:Notify("Something went wrong with the needle.", 6, "med_err_needle", 0)
	elseif action == "tourniquet" then
		local limb = ctx and ctx.bone and limb_from_bone[ctx.bone]
		if limb and org[limb] ~= nil then
			org[limb] = min(org[limb] + 0.3, 1)
		end
		org.painadd = min((org.painadd or 0) + 40, 150)
		org.shock = min((org.shock or 0) + 20, 95)
		org.owner:Notify("Tourniquet was applied badly.", 6, "med_err_tourniquet", 0)
	elseif action == "transfusion" then
		org.hemotransfusionshock = min((org.hemotransfusionshock or 0) + 0.8, 2)
		org.internalBleed = min((org.internalBleed or 0) + 0.6, 10)
		org.owner:Notify("Transfusion reaction feels wrong.", 6, "med_err_transfusion", 0)
	elseif action == "internal_bleed_treat" then
		org.analgesiaAdd = min((org.analgesiaAdd or 0) + 0.6, 4)
		org.consciousness = Approach(org.consciousness or 1, 0.4, 0.2)
		org.owner:Notify("Wrong dose, feeling dizzy...", 6, "med_err_dose", 0)
	elseif action == "bandage" then
		org.medical_infection = min((org.medical_infection or 0) + 0.8, 2)
		hg.organism.Infection.Seed(org, 0.3)
		org.owner:Notify("Bandage wasn't clean enough.", 6, "med_err_bandage", 0)
	end
	if actor ~= org.owner then
		actor:Notify("Complication occurred.", 4, "med_error_actor", 0)
	end
	return true
end
function hg.organism.GetMedicalRole(ply)
	return get_role(ply)
end
function hg.organism.ApplyMedicalAction(actor, target, action, ctx)
	if not IsValid(actor) or not IsValid(target) or not target.organism then return end
	local org = target.organism
	if not is_alive_org(org) then return end
	local role = get_role(actor)
	local skill = get_skill(role)
	if action == "bandage" and ctx and ctx.success then
		local bonus = 0.2 * skill
		org.painadd = max((org.painadd or 0) - bonus * 6, 0)
		org.fearadd = max((org.fearadd or 0) - bonus * 0.3, 0)
	end
	if action == "tourniquet" and ctx and ctx.success then
		org.shock = max((org.shock or 0) - 2 * skill, 0)
	end
	if action == "needle" and ctx and ctx.success then
		org.pneumothorax = max((org.pneumothorax or 0) - 0.05 * skill, 0)
		org.shock = max((org.shock or 0) - 1.5 * skill, 0)
	end
	if action == "transfusion" and ctx and ctx.amount and ctx.amount > 0 then
		org.hemotransfusionshock = max((org.hemotransfusionshock or 0) - (0.03 * skill), 0)
	end
	if action == "internal_bleed_treat" and ctx and ctx.success then
		local wep = IsValid(actor) and actor:GetActiveWeapon() or nil
		local medkitType = IsValid(wep) and wep.HGMedkitModeTypes and wep.HGMedkitModeTypes[wep.mode]
		if IsValid(wep) and (wep:GetClass() == "weapon_tranexamic_acid" or medkitType == "tranexamic") then
			hg.organism.AdministerTranexamic(org, 0.3 * skill)
		else
			org.internalBleedHeal = min((org.internalBleedHeal or 0) + 0.3 * skill, 20)
		end
	end
	if (org.next_med_error_check or 0) > CurTime() then
		if hg.organism.RecordDepressionTreatment then
			hg.organism.RecordDepressionTreatment(org, false)
		end
		return
	end
	org.next_med_error_check = CurTime() + 0.6
	local failed = apply_med_error(actor, org, action, ctx)
	if hg.organism.RecordDepressionTreatment then
		hg.organism.RecordDepressionTreatment(org, failed)
	end
end

hook.Add("hg_medical_minigame_finished", "organism-medical-system-action", function(actor, target, minigameType)
	if not IsValid(actor) or not IsValid(target) then return end

	local action
	if minigameType == "bandage" or minigameType == "tourniquet" then
		action = minigameType
	elseif minigameType == "syringe" then
		local wep = actor:GetActiveWeapon()
		if not IsValid(wep) then return end

		local class = wep:GetClass()
		local medkitType = wep.HGMedkitModeTypes and wep.HGMedkitModeTypes[wep.mode]
		if class == "weapon_tranexamic_acid" or medkitType == "tranexamic" or (class == "weapon_medkit_sh" and wep.mode == 3 and (wep.traumaSlot or "tranexamic") == "tranexamic") then
			action = "internal_bleed_treat"
		elseif class == "weapon_needle" or medkitType == "needle" or (class == "weapon_medkit_sh" and wep.mode == 5) then
			action = "needle"
		end
	end

	if action then
		hg.organism.ApplyMedicalAction(actor, target, action, {success = true})
	end
end)

local WAKE_DIZZY_DURATION = 30
local WAKE_DIZZY_MAX = 2
local WAKE_DIZZY_MIN = 1.5
local WAKE_DIZZY_CHANCE = 0.25

module[1] = function(org)
	org.rehab_otrub = 0
	org.rehab_otrub_duration = 0
	org.rehab_dizzy_until = 0
	org.medical_errors = 0
	org.medical_infection = 0
	org.next_med_error_check = 0
	org.bandagedchest = false
	org.bandagedskull = false
	org.medicineActive = nil
end
module[2] = function(owner, org, timeValue)
	if not org.alive then return end
	org.medical_infection = max((org.medical_infection or 0) - timeValue / 900, 0)
	if org.medical_infection > 0 then
		hg.organism.Infection.Seed(org, timeValue / 600 * org.medical_infection)
	end
	local now = CurTime()
	if now < (org.rehab_otrub or 0) then
		local dur = max(org.rehab_otrub_duration or 1, 1)
		local remain = Clamp((org.rehab_otrub - now) / dur, 0, 1)
		org.immobilization = min((org.immobilization or 0) + timeValue * (3 + 5 * remain), 80)
		org.stamina.subadd = (org.stamina.subadd or 0) + remain * 0.2
	end
	if now < (org.rehab_dizzy_until or 0) then
		local dizzyRemain = Clamp((org.rehab_dizzy_until - now) / WAKE_DIZZY_DURATION, 0, 1)
		org.disorientation = max(org.disorientation or 0, WAKE_DIZZY_MIN + (WAKE_DIZZY_MAX - WAKE_DIZZY_MIN) * dizzyRemain)
	end
	hg.Medicine.Tick(org)
end
hook.Add("HG_OnWakeOtrub", "organism-rehab-after-otrub", function(owner)
	if not IsValid(owner) or not owner.organism then return end
	local org = owner.organism
	local bloodFactor = Clamp((3200 - (org.blood or 3200)) / 900, 0, 1)
	local brainFactor = Clamp((org.brain or 0) / 0.6, 0, 1)
	local painFactor = Clamp((org.pain or 0) / 120, 0, 1)
	local duration = 18 + (bloodFactor * 12) + (brainFactor * 10) + (painFactor * 8)
	local role = get_role(owner)
	if role == "doctor" or role == "surgeon" then
		duration = duration * 0.8
	end
	org.rehab_otrub_duration = duration
	org.rehab_otrub = CurTime() + duration
	local headFactor = max(brainFactor, Clamp((org.concussion or 0) / 3, 0, 1))
	if math.Rand(0, 1) < WAKE_DIZZY_CHANCE + headFactor * (1 - WAKE_DIZZY_CHANCE) then
		org.rehab_dizzy_until = CurTime() + WAKE_DIZZY_DURATION
	end
end)

local Medicine = hg.Medicine
local SoftTissue = hg.SoftTissue

local BONE_KEYS = {head = "skull", torso = "chest"}
local SEVERITY_STOPS = {muscle = SoftTissue.Config.muscle.severity}
local ANALGESIA_ADD_MAX = 4

local function limbBleed(org, limb)
	local bleed = 0
	for _, wound in ipairs(org.wounds or {}) do
		if SoftTissue.LimbFromBone(wound[4]) == limb then bleed = bleed + math.max(tonumber(wound[1]) or 0, 0) end
	end

	return bleed
end

Medicine.Measures = {
	brute = function(org, limb) return SoftTissue.Get(org, "brute", limb) end,
	burn = function(org, limb) return SoftTissue.Get(org, "burn", limb) end,
	muscle = function(org, limb) return SoftTissue.GetMuscle(org, limb) end,
	bleeding = limbBleed,
	fracture = function(org, limb) return math.Clamp(tonumber(org[BONE_KEYS[limb] or limb]) or 0, 0, 1) end,
	pain = function(org) return tonumber(org.pain) or 0 end,
}

Medicine.Handlers = {
	brute = function(org, limb, amount) return SoftTissue.Heal(org, "brute", limb, amount) end,
	burn = function(org, limb, amount) return SoftTissue.Heal(org, "burn", limb, amount) end,
	muscle = function(org, limb, amount) return SoftTissue.HealMuscle(org, limb, amount) end,
	fracture = function(org, limb, amount)
		return hg.organism.ApplyBandageBoneTreatment(org, BONE_KEYS[limb] or limb, amount)
	end,
	pain = function(org, limb, amount)
		org.analgesiaAdd = min((org.analgesiaAdd or 0) + amount, ANALGESIA_ADD_MAX)

		return amount
	end,
	bleeding = function(org, limb, amount)
		local healed = 0
		for _, wound in ipairs(org.wounds or {}) do
			local size = math.max(tonumber(wound[1]) or 0, 0)
			if size > 0 and healed < amount and SoftTissue.LimbFromBone(wound[4]) == limb then
				local part = min(size, amount - healed)
				wound[1] = size - part
				healed = healed + part
			end
		end

		if healed > 0 then
			org.bleed = max((org.bleed or 0) - healed, 0)
			hg.organism.MarkWoundsNetDirty(org, true)
		end

		return healed
	end,
}

Medicine.Requirements = {
	splint = function(org, limb)
		return hg.IsLimbSplinted ~= nil and IsValid(org.owner) and hg.IsLimbSplinted(org.owner, limb)
	end,
	bandage = function(org, limb)
		return hg.GetBandageKeyLayers ~= nil and IsValid(org.owner) and hg.GetBandageKeyLayers(org.owner, limb) > 0
	end,
}

Medicine.SideEffects = {
	crash = function(org, amount) org.adrenalineAdd = (org.adrenalineAdd or 0) - amount end,
	hiddenPain = function(org, amount) hg.organism.AddPain(org, amount, "body") end,
}

local function requirement(entry, kind)
	local requires = entry.requires
	if istable(requires) then return requires[kind] end

	return requires
end

function Medicine.CanTreat(org, entry, kind, limb)
	local measure = Medicine.Measures[kind]
	local damage = measure and measure(org, limb) or 0
	if damage <= 0 or damage < (entry.minDamage and entry.minDamage[kind] or 0) then return false end

	local maxSeverity = entry.maxSeverity
	if maxSeverity and kind ~= "pain" and kind ~= "bleeding" and kind ~= "fracture" then
		local rank = SoftTissue.GetSeverityRank(damage, SEVERITY_STOPS[kind])
		if rank > (SoftTissue.Config.severityRank[maxSeverity] or maxSeverity) then return false end
	end

	local check = Medicine.Requirements[requirement(entry, kind)]

	return check == nil or check(org, limb) == true
end

local function limbScore(org, entry, limb)
	local score = 0
	for _, kind in ipairs(entry.heals) do
		if Medicine.CanTreat(org, entry, kind, limb) then
			local damage = Medicine.Measures[kind](org, limb)
			local unit = (kind == "muscle" or kind == "fracture") and SoftTissue.Config.impairment.softFull or 1
			score = score + damage * unit
		end
	end

	return score
end

function Medicine.ResolveLimbs(org, entry, bone)
	if entry.target == "all" then return SoftTissue.LIMBS end

	local aimed = entry.target ~= "worst" and SoftTissue.LimbFromBone(bone)
	if aimed and limbScore(org, entry, aimed) > 0 then return {aimed} end

	local worst, worstScore = nil, 0
	for _, limb in ipairs(SoftTissue.LIMBS) do
		local score = limbScore(org, entry, limb)
		if score > worstScore then worst, worstScore = limb, score end
	end

	return {worst}
end

function Medicine.Plan(id, org, bone, available)
	local entry = Medicine.Items[id]
	local steps, totalCost = {}, 0
	if not entry or not org or not org.softBrute then return steps, totalCost end

	local cost = entry.cost or Medicine.DEFAULT_COST
	for _, limb in ipairs(Medicine.ResolveLimbs(org, entry, bone)) do
		for _, kind in ipairs(entry.heals) do
			local affordable = not available or totalCost + cost <= available + 0.001
			if affordable and Medicine.CanTreat(org, entry, kind, limb) then
				totalCost = totalCost + cost
				steps[#steps + 1] = {
					key = "medicine_" .. kind,
					limb = Medicine.WRAP_KEYS[limb] or limb,
					medicine = id,
					kind = kind,
					target = limb,
					cost = cost,
					heal = istable(entry.amount) and entry.amount[kind] or entry.amount or 0,
				}
			end
		end
	end

	return steps, totalCost
end

local function applyHeal(org, kind, limb, amount)
	local before = SoftTissue.GetPainLoad(org, true)
	local healed = Medicine.Handlers[kind](org, limb, amount) or 0
	local relief = before - SoftTissue.GetPainLoad(org, true)
	if relief > 0 then org.avgpain = max((org.avgpain or 0) - relief, 0) end

	return healed
end

function Medicine.ApplyStep(org, step)
	local entry = Medicine.Items[step.medicine]
	if not entry or not Medicine.Handlers[step.kind] then return 0 end

	if entry.mode ~= "overtime" then return applyHeal(org, step.kind, step.target, step.heal) end

	local tickRate = entry.tickRate or 1
	local ticks = max(math.floor((entry.duration or tickRate) / tickRate), 1)
	org.medicineActive = org.medicineActive or {}
	org.medicineActive[#org.medicineActive + 1] = {
		kind = step.kind,
		limb = step.target,
		perTick = step.heal / ticks,
		ticks = ticks,
		tickRate = tickRate,
		nextTick = CurTime() + tickRate,
	}

	return step.heal
end

function Medicine.Tick(org)
	local active = org.medicineActive
	if not active then return end

	local now = CurTime()
	for index = #active, 1, -1 do
		local effect = active[index]
		if effect.nextTick <= now then
			effect.nextTick = now + effect.tickRate
			effect.ticks = effect.ticks - 1
			applyHeal(org, effect.kind, effect.limb, effect.perTick)
			if effect.ticks <= 0 then table.remove(active, index) end
		end
	end

	if #active == 0 then org.medicineActive = nil end
end

function Medicine.Use(id, org, bone, available)
	local steps, totalCost = Medicine.Plan(id, org, bone, available)
	if #steps == 0 then return false end

	for _, step in ipairs(steps) do
		Medicine.ApplyStep(org, step)
	end

	for name, amount in pairs(Medicine.Items[id].sideEffects or {}) do
		local effect = Medicine.SideEffects[name]
		if effect then effect(org, amount) end
	end

	return totalCost, steps
end

function Medicine.SwepCanHeal(wep, ent)
	local org = ent and ent.organism
	local available = wep.modeValues and wep.modeValues[1] or 0
	if not org or available <= 0 then return false end

	return #Medicine.Plan(wep.MedicineId, org, nil, available) > 0
end

function Medicine.SwepHeal(wep, ent, mode, bone)
	local org = ent.organism
	if not org then return end

	local cost = Medicine.Use(wep.MedicineId, org, bone, wep.modeValues[1] or 0)
	if not cost then return false end

	wep.modeValues[1] = max((wep.modeValues[1] or 0) - cost, 0)

	local owner = wep:GetOwner()
	owner:EmitSound("snd_jack_hmcd_bandage.ogg", 60, math.random(95, 105))
	if wep.modeValues[1] <= 0 and wep.ShouldDeleteOnFullUse then
		owner:SelectWeapon("weapon_hands_sh")
		wep:Remove()
	end

	return true
end
