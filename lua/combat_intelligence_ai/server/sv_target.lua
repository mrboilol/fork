CAI.Target = CAI.Target or {}
local T = CAI.Target

local AIM_PREDICTION_PASSES = 8
local MAX_AIM_ERROR_DEGREES = 9

function T.CalculateShotVelocity(src, aim, targetVelocity, bullet)
	local speed = bullet.Vel:Length()
	if speed < 1 then return bullet.Vel, 0 end
	local stepTime = FrameTime()
	if stepTime <= 0 then stepTime = engine.TickInterval() end
	local gravity = bullet.NoGravity and vector_origin or physenv.GetGravity()
	local resistance = bullet.AirResistMul or 0
	local time = math.Clamp(src:Distance(aim) / speed, 0.000001, bullet.LifeTime or 5)
	local initialVelocity = (aim - src):GetNormalized() * speed
	for _ = 1, AIM_PREDICTION_PASSES do
		local pos, velocity = src, initialVelocity
		local remaining = time
		while remaining > 0 do
			velocity = velocity + gravity * stepTime
			local interval = math.min(remaining, stepTime)
			pos = pos + velocity * interval
			local len = velocity:Length()
			velocity = velocity:GetNormalized() * math.max(len - resistance * stepTime * len * len, 0)
			remaining = remaining - interval
		end
		local error = aim + targetVelocity * time - pos
		if error:LengthSqr() < 0.0001 then break end
		local corrected = initialVelocity + error * (speed / math.max(src:Distance(pos), 1))
		time = math.Clamp(time * corrected:Length() / speed, 0.000001, bullet.LifeTime or 5)
		initialVelocity = corrected:GetNormalized() * speed
	end

	return initialVelocity, time
end

function T.ApplyBulletRecoil(shooter, bullet, physical)
	if not CAI.Enabled() or (bullet.penetrated or 0) > 0 then return end
	if physical and not isvector(bullet.Vel) then return end
	local dir = physical and bullet.Vel or bullet.Dir
	if not isvector(dir) or dir:LengthSqr() < 0.000001 then return end
	local npc = IsValid(bullet.Attacker) and bullet.Attacker
		or IsValid(bullet.Shooter) and bullet.Shooter or shooter
	if IsValid(npc) and npc:IsWeapon() then npc = npc:GetOwner() end
	if not IsValid(npc) or not npc:IsNPC() then return end
	local data = CAI.Manager.Get(npc)
	if not data then return end
	local weapon = npc:GetActiveWeapon()
	if not IsValid(weapon) or weapon.norecoil then return end
	if not data.recoil or data.recoil.weapon ~= weapon then
		data.recoil = {weapon = weapon, pitch = 0, yaw = 0}
	end
	local recoil = data.recoil
	local now = CurTime()
	if recoil.shotAt ~= now then
		local recovery = (1.2 + CAI.AimSkill() * 1.2) / math.max(weapon.shotRecoveryScale or 1, 0.1)
		local elapsed = math.max(now - (recoil.shotAt or now), 0)
		recoil.shotPitch = math.Approach(recoil.pitch, 0, elapsed * recovery)
		recoil.shotYaw = math.Approach(recoil.yaw, 0, elapsed * recovery)
		local disturbance = 1
		if weapon.GetRecoilImpulseFactors then
			local _, _, _, _, _, value = weapon:GetRecoilImpulseFactors()
			disturbance = value or 1
		end
		local attachment = weapon.GetAttachmentRecoilMul and weapon:GetAttachmentRecoilMul() or 1
		local impulse = math.Clamp(disturbance * (weapon.RecoilMul or 1) * attachment * 0.5, 0.05, 3)
		recoil.pitch = math.Clamp(recoil.shotPitch + impulse * math.Rand(0.85, 1.15), 0, 8)
		recoil.yaw = math.Clamp(recoil.shotYaw + impulse * math.Rand(-0.35, 0.35), -3, 3)
		recoil.shotAt = now
	end
	if recoil.shotPitch == 0 and recoil.shotYaw == 0 then return end
	local angle = dir:Angle()
	angle.p = angle.p - recoil.shotPitch
	angle.y = angle.y + recoil.shotYaw
	local recoiled = angle:Forward()
	if physical then
		bullet.Vel = recoiled * dir:Length()
		bullet.DirOriginal = recoiled
	else
		bullet.Dir = recoiled
	end

	return true
end

function T.ApplyBulletAim(shooter, bullet, physical)
	if not CAI.Enabled() or (bullet.penetrated or 0) > 0 then return end
	if physical and not isvector(bullet.Vel) then return end
	local currentDir = physical and bullet.DirOriginal or bullet.Dir
	if not isvector(currentDir) and physical and isvector(bullet.Vel) then
		currentDir = bullet.Vel:GetNormalized()
	end
	if not isvector(currentDir) then return end
	local npc = IsValid(bullet.Attacker) and bullet.Attacker
		or IsValid(bullet.Shooter) and bullet.Shooter or shooter
	if IsValid(npc) and npc:IsWeapon() then npc = npc:GetOwner() end
	if not IsValid(npc) or not npc:IsNPC() or not CAI.Manager.Get(npc) then return end
	local skill = CAI.AimSkill()
	local godAim = skill == 1
	local speed = isvector(bullet.Vel) and bullet.Vel:Length() or 0
	if godAim then
		bullet.Spread = vector_origin
		bullet.NoHiddenSpread = true
		bullet.Flags = bit.bor(bullet.Flags or 0, FIRE_BULLETS_FIRST_SHOT_ACCURATE)
		if physical then bullet.Vel = currentDir:GetNormalized() * speed end
	end
	local enemy = npc:GetEnemy()
	if not CAI.Util.IsTargetable(enemy) or enemy:GetClass() == "npc_bullseye" then return godAim or nil end
	local target = IsValid(enemy.zcnpc_rag) and enemy.zcnpc_rag
		or hg and hg.GetCurrentCharacter and hg.GetCurrentCharacter(enemy) or enemy
	if not IsValid(target) then return godAim or nil end
	local src = bullet.Src or bullet.Pos
	if not isvector(src) then return godAim or nil end
	local filter = {npc}
	local weapon = npc:GetActiveWeapon()
	if IsValid(weapon) then filter[#filter + 1] = weapon end
	local aim = target:WorldSpaceCenter()
	if CAI.CVBool("cai_prioritize_head") then
		local bone = target:LookupBone("ValveBiped.Bip01_Head1")
		local head = bone and target:GetBonePosition(bone) or target:EyePos()
		if isvector(head) then
			local trace = util.TraceLine({start = src, endpos = head, filter = filter, mask = MASK_SHOT})
			if not trace.Hit or trace.Entity == target then aim = head end
		end
	end
	if not isvector(aim) then return godAim or nil end
	local trace = util.TraceLine({start = src, endpos = aim, filter = filter, mask = MASK_SHOT})
	if trace.Hit and trace.Entity ~= target then return godAim or nil end
	local dir = aim - src
	if dir:LengthSqr() < 1 then return godAim or nil end
	if not godAim then
		local radius = dir:Length() * math.tan(math.rad(MAX_AIM_ERROR_DEGREES * (1 - skill) ^ 3))
		local proficiency = math.Clamp(npc:GetCurrentWeaponProficiency(), 0, WEAPON_PROFICIENCY_PERFECT)
		radius = radius * (1 + (WEAPON_PROFICIENCY_GOOD - proficiency) * 0.35)
		local horizontal = math.Rand(-radius, radius)
		if skill == 0 then
			radius = math.max(radius, target:BoundingRadius() * 1.5)
			horizontal = radius * math.Rand(0.8, 1.2) * (math.random() < 0.5 and -1 or 1)
		end
		aim = aim - target:GetVelocity() * (1 - skill) * 0.35
		local right = dir:GetNormalized():Cross(vector_up)
		if right:LengthSqr() < 0.0001 then right = Vector(1, 0, 0) end
		right = right:GetNormalized()
		local up = right:Cross(dir:GetNormalized())
		aim = aim + right * horizontal + up * math.Rand(-radius, radius) * 0.6
		dir = aim - src
	end
	dir = dir:GetNormalized()
	if physical then
		if skill > 0.5 then
			local calculated = T.CalculateShotVelocity(src, aim, target:GetVelocity(), bullet)
			local prediction = (skill - 0.5) * 2
			dir = (dir * (1 - prediction) + calculated:GetNormalized() * prediction):GetNormalized()
		end
		bullet.Vel = dir * speed
		bullet.DirOriginal = dir
	else
		bullet.Dir = dir
	end
	bullet.Spread = vector_origin
	bullet.NoHiddenSpread = true

	return true
end

local ARCH_THREAT = { rocket = 3, lmg = 2.2, sniper = 2, shotgun = 1.6, smg = 1.3, rifle = 1.2, pistol = 0.8, melee = 0.6 }

function T.Score(data, enemy, rec)
    local npc = data.ent
    local score = 0

    local dist = npc:GetPos():Distance(rec.pos or enemy:GetPos())
    score = score + (1 - math.Clamp(dist / 2500, 0, 1)) * 2

    if enemy.GetActiveWeapon then
        local arch = CAI.WeaponIntel.Classify(enemy:GetActiveWeapon())
        score = score + (ARCH_THREAT[arch] or 1)
    end

    if CAI.Util.CanSee(npc, enemy) then score = score + 1.5 end
    if enemy:Health() < 40 then score = score + 0.7 end
    if not rec.heardOnly then score = score + 0.5 end

    return score
end

function T.Evaluate(data)
    local npc = data.ent
    local best, bestScore = nil, -math.huge
    local bestRec

    for enemy, rec in pairs(data.memory.enemies) do

        local allied = IsValid(enemy) and npc:Disposition(enemy) == D_LI
        if not IsValid(enemy) or allied or not CAI.Util.IsTargetable(enemy) then

            data.memory.enemies[enemy] = nil
            if IsValid(enemy) and npc.ClearEnemyMemory then
                npc:ClearEnemyMemory(enemy)
            end
        else
            local s = T.Score(data, enemy, rec)
            if s > bestScore then best, bestScore, bestRec = enemy, s, rec end
        end
    end

    local cur = npc.GetEnemy and npc:GetEnemy()
    if IsValid(cur) and not CAI.Util.IsTargetable(cur) then
        if npc.ClearEnemyMemory then npc:ClearEnemyMemory(cur) end
        npc:SetEnemy(NULL)
    end

    if data.state == CAI.STATE.SUPPRESS and IsValid(data.suppBullseye) then
        return best, bestRec
    end

    if IsValid(best) and npc.SetEnemy then
        if npc:GetEnemy() ~= best then
            npc:SetEnemy(best)
            if npc.UpdateEnemyMemory then
                npc:UpdateEnemyMemory(best, bestRec.pos or best:GetPos())
            end
        end
    end
    return best, bestRec
end
