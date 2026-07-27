

local hg_infstamina = CreateConVar("hg_infstamina", "0", {FCVAR_REPLICATED, FCVAR_HIDDEN})



local min, max, Round = math.min, math.max, Round

local hg_organism_stamina_sprint_mul = CreateConVar("hg_organism_stamina_sprint_mul","1",{FCVAR_ARCHIVE,FCVAR_NOTIFY,FCVAR_NEVER_AS_STRING},"Multiply stamina drain when sprinting",0,10)
local panicattack_stamina_drain_mul = 1.35
local low_stamina_drain_max_mul = 1.2
local low_stamina_recovery_min_mul = 0.85
local recent_stamina_loss_recovery_min_mul = 0.5
local recent_stamina_loss_hold_time = 2
local recent_stamina_loss_fade_time = 6
local anger_combat_hold_time = 6
local anger_decay_per_second = 0.075
--local Organism = hg.organism

hg.organism.module.stamina = {}

local module = hg.organism.module.stamina

module[1] = function(org)

	org.adrenaline = 0

	org.adrenalineAdd = 0
	org._adrenalineHoldUntil = 0
	org.anger = 0
	org.angerCombatUntil = 0

	org.adrenalineStorage = 5



	org.stamina = {

		range = 60 * 3,

		regen = 1,

		sub = 0,

		subadd = 0,

		weight = 0,

		recoveryPenaltyUntil = 0,

		recoveryPenaltyFadeUntil = 0,

		max = 60 * 3,

	}

	-- The HUD receives these fields through the organism table and uses them
	-- for the encumbered moodle.
	org.weight = 0
	org.maxweight = 60



	org.energy = 0



	org.hemotransfusionshock = 0



	org.stamina[1] = org.stamina.range

	local owner = org.owner

	org.moveMaxSpeed = IsValid(owner) and owner:IsPlayer() and owner:GetMaxSpeed() or 250

end



module[2] = function(owner, org, timeValue)

	local stamina = org.stamina

	local now = CurTime()
	if now > (org.angerCombatUntil or 0) then
		org.anger = math.max((org.anger or 0) - timeValue * anger_decay_per_second, 0)
	end

	

	local painfrommoving = (stamina.sub * (org.chest))//(stamina.sub * ((org.jaw == 1 and 1 or 0) + org.chest + (org.jawdislocation and 1 or 0)))

	//org.painadd = org.painadd + painfrommoving * timeValue * 5



	if painfrommoving > 0 then

		//org.owner:Notify("I should stop moving so much...", 30, "painfrommoving", 0, nil, Color(255, 0, 0))

	

		if (org.jaw == 1) or org.jawdislocation then

			//org.owner:Notify("My jaw is really hurting every move I make.", 60, "painfromjaw", 0, nil, Color(255, 210, 210))

		end



		if (org.chest > 0.25) then

			//org.owner:Notify("Breathing is painful. Something is wrong with my ribs.", 60, "painfromribs", 0, nil, Color(255, 210, 210))

		end

	end



	stamina.sub = 0

	local velLen = 0

	if owner:IsPlayer() then

		local wep = owner:GetActiveWeapon()

		local walk = owner:KeyDown(IN_FORWARD) or owner:KeyDown(IN_BACK) or owner:KeyDown(IN_MOVELEFT) or owner:KeyDown(IN_MOVERIGHT)

		velLen = max(min(owner:GetVelocity():Length(), org.moveMaxSpeed), 0) / (owner:GetRunSpeed() / hg_organism_stamina_sprint_mul:GetFloat())-- / ((IsValid(wep) and wep ~= NULL and wep:GetClass() == "weapon_hands_sh" and owner:KeyDown(IN_WALK)) and 1.3 or 0.58))

		--print(velLen)
		if (owner:OnGround() or owner:WaterLevel() >= 2) and walk and not owner:InVehicle() and owner.hg_isJogging and org.stamina[1] > 20 then
			stamina.sub = (owner:WaterLevel() >= 2 and 2 or 1) * (velLen ^ 0.5) * 0.6 -- Jogging uses less
		elseif (owner:OnGround() or owner:WaterLevel() >= 2) and walk and not owner:InVehicle() and owner.hg_isSprinting and org.stamina[1] > 20 then
			stamina.sub = (owner:WaterLevel() >= 2 and 2 or 1) * (velLen ^ 0.5) * 1.10 -- Sprinting uses more
		end

	end



	if org.superfighter then

		org.stamina.subadd = org.stamina.subadd / 4

	end



	if org.chest > 0.3 then

		org.lungsL[2] = math.min(org.lungsL[2] + stamina.sub / 200 * org.chest, 1)

		org.lungsR[2] = math.min(org.lungsR[2] + stamina.sub / 200 * org.chest, 1)

	end





	stamina.sub = stamina.sub + stamina.subadd

	stamina.sub = stamina.sub + (org.stamina_damage or 0)

	org.stamina_damage = 0

	stamina.sub = stamina.sub * (owner.StaminaExhaustMul or 1)

	stamina.sub = stamina.sub / (1 + org.berserk)

		if org.o2[1] < 10 then

		stamina.sub = 0

	end

	local goodmood = math.Clamp(org.goodmood or 0, 0, 1)



	stamina.subadd = 0

	if owner:IsPlayer() then
		org.weight = hg.GetCarryWeight(owner)
		org.maxweight = 60
		stamina.weight = math.Clamp(org.weight / 250, 0, 1)
	else
		stamina.weight = 0
	end

	local muffed = owner.armors and owner.armors["face"] == "mask2"

	stamina.sub = stamina.sub + stamina.sub * stamina.weight * (muffed and 2 or 1)
	if (org.panicattack or 0) >= 0.45 then
		stamina.sub = stamina.sub * panicattack_stamina_drain_mul
	end
	org.hungry = org.hungry or 0

	local perfusionMoveMul = math.Clamp(org.perfusionMoveMul or 1, 0.25, 1)
	local perfusionRegenMul = math.Clamp(org.perfusion or 1, 0.18, 1)
	local heatWeakness = math.Clamp(math.Remap(org.temperature or 36.7, 38, 41, 0, 0.65), 0, 0.65)
	local heatStaminaMul = 1 - heatWeakness * 0.55
	org.heatWeakness = heatWeakness
	stamina.max = ((org.superfighter and 2 or 1) * ((stamina.range * (1 - (org.pneumothorax) / 2) + org.adrenaline * 20 ) * math.max(1 - org.hemotransfusionshock,0.2)) * math.max(1 - (org.hungry/100),0.65) * math.Clamp(0.55 + perfusionMoveMul * 0.45, 0.55, 1) + goodmood * 20) * heatStaminaMul
	stamina[1] = math.min(stamina[1], stamina.max)
	local staminaFraction = math.Clamp(stamina[1] / math.max(stamina.max, 1), 0, 1)
	local lowStamina = 1 - staminaFraction
	local staminaDrainMul = Lerp(lowStamina, 1, low_stamina_drain_max_mul)
	local staminaRecoveryMul = Lerp(lowStamina, 1, low_stamina_recovery_min_mul)
	local staminaBeforeDrain = stamina[1]
	stamina[1] = max(stamina[1] - stamina.sub * staminaDrainMul * timeValue * 8 * (2 - (org.o2[1] / org.o2.range)), 0)
	if staminaBeforeDrain - stamina[1] > 0.01 then
		stamina.recoveryPenaltyUntil = CurTime() + recent_stamina_loss_hold_time
		stamina.recoveryPenaltyFadeUntil = stamina.recoveryPenaltyUntil + recent_stamina_loss_fade_time
	end
	if stamina.max > 100 then

	end

	
	
	//local old = stamina[1]

	local pulseMultiplier = math.Clamp((org.heartbeat or 70) / 70, 0.8, 1.5)

	-- Slower stamina recovery with damaged lungs
	local lungDamage = (org.lungsL[1] + org.lungsR[1]) / 2
	local lungRecoveryMultiplier = math.max(1 - lungDamage, 0.3)
	-- Apply breathing penalty from spine3 damage
	local breathingMul = org.breathing or 1
	local recentLossRecoveryMul = 1
	if now < (stamina.recoveryPenaltyUntil or 0) then
		recentLossRecoveryMul = recent_stamina_loss_recovery_min_mul
	elseif now < (stamina.recoveryPenaltyFadeUntil or 0) then
		local fadeProgress = math.Clamp((now - stamina.recoveryPenaltyUntil) / recent_stamina_loss_fade_time, 0, 1)
		recentLossRecoveryMul = Lerp(fadeProgress, recent_stamina_loss_recovery_min_mul, 1)
	end

	local postureRecoveryMul = 1
	if owner:IsPlayer() then
		local character = hg.GetCurrentCharacter(owner)
		local ragdolled = IsValid(owner.FakeRagdoll) or org.fake or (character and character:IsRagdoll())
		local climbing = IsValid(character) and character:IsRagdoll() and ((IsValid(character.ConsLH) and character.ConsLH.ZCClimbGrip) or (IsValid(character.ConsRH) and character.ConsRH.ZCClimbGrip))
		if ragdolled and not climbing then
			postureRecoveryMul = 1.55
		elseif owner:Crouching() then
			postureRecoveryMul = 1.25
		end
	end

	stamina[1] = min(stamina[1] + stamina.regen * staminaRecoveryMul * recentLossRecoveryMul * timeValue * 3.75 * (org.noradrenaline / 2 + 1) * (org.o2[1] / org.o2.range) * (org.adrenaline / 16 + 1) * (org.satiety/700 + 1) * pulseMultiplier * postureRecoveryMul * (org.holdingbreath and 0 or 1) * (org.lungsfunction and 1 or 0) * lungRecoveryMultiplier * breathingMul * perfusionRegenMul * (1 - heatWeakness * 0.65), stamina.max)



	-- local painfrommoving = (stamina[1] < 150 and 1 or 0) * (stamina[1] - old) * (org.chest)

	-- org.painadd = org.painadd + painfrommoving * timeValue * 5



	if org.nextAdrenalineRegen and org.nextAdrenalineRegen < CurTime() then

		org.adrenalineStorage = math.Approach(org.adrenalineStorage, 5, timeValue / 60 * (org.satiety * 0.01 + 1))

	end



	-- if painfrommoving > 0 then

	-- 	if (org.chest > 0.25) then

	-- 		org.owner:Notify("Breathing is painful. Something is wrong with my ribs.", 60, "painfromribs", 0, nil, Color(255, 210, 210))

	-- 	end

	-- end

		if hg_infstamina:GetBool() then

		stamina.sub = 0

		stamina[1] = stamina.max

	end

end



function hg.organism.AddNaturalAdrenaline(org, fAmount)

	if org.otrub and not org.heartstop then return end

	if fAmount < 0 then return end

	fAmount = fAmount * 0.45
	if org.heartstop then fAmount = fAmount * 0.75 end

	local storage = org.adrenalineStorage or 0
	local reserveK = math.Clamp(storage / 5, 0, 1)
	local reserveAmt = math.min(storage, fAmount)
	local exhaustedAmt = math.max(fAmount - reserveAmt, 0) * 0.08
	local amt = reserveAmt + exhaustedAmt

	if amt <= 0 then return end

	

	org.adrenaline = math.min(org.adrenaline + amt, 5)
	org._adrenalineHoldUntil = math.max(org._adrenalineHoldUntil or 0, CurTime() + math.Clamp(amt * 2, 1, 8))

	org.adrenalineStorage = math.max(storage - reserveAmt, 0)
	org.adrenalineReserveEffectiveness = reserveK

	org.nextAdrenalineRegen = CurTime() + 30

end

-- Anger is a short combat-only surge using the normal adrenaline reserve.
function hg.organism.RileAnger(org, amount)
	if not org or not org.alive or org.otrub then return end
	amount = math.max(amount or 0, 0)
	if amount <= 0 then return end
	org.anger = math.Clamp((org.anger or 0) + amount, 0, 1)
	org.angerCombatUntil = math.max(org.angerCombatUntil or 0, CurTime() + anger_combat_hold_time)
	hg.organism.AddNaturalAdrenaline(org, amount * 2)
end


local entMeta = FindMetaTable("Entity")



function entMeta:AddNaturalAdrenaline(fAmount)

	local org = self.organism



	if !org then return end



	hg.organism.AddNaturalAdrenaline(org, fAmount)

end



local vecZero = Vector(0, 0, 0)

hook.Add("FinishMove", "!homigrad-organism", function(ply, move)

	local vel = move:GetFinalJumpVelocity()



	if !ply.organism then return end



	if vel ~= vecZero then ply.organism.stamina[1] = max(ply.organism.stamina[1] - ply:GetJumpPower() / 10,0) end
	ply.organism.moveMaxSpeed = move:GetMaxSpeed()

end)
