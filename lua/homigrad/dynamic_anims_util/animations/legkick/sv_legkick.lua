--
local PLAYER = FindMetaTable("Player")

local vpang = Angle(2, -1, 1)
local LEG_KICK_DAMAGE_MUL = 1.1
local LEG_KICK_RAG_FORCE_MUL = 650
local LEG_KICK_PROP_FORCE_MUL = 90
local LEG_KICK_PLAYER_PUSH = 190
local LEG_KICK_FAKE_CHANCE = 0.35
local CROUCH_KICK_DAMAGE_MUL = 1.25
local CROUCH_KICK_FAKE_CHANCE = 0.55
local DROP_KICK_DAMAGE_MUL = 2
local DROP_KICK_RAG_FORCE_MUL = 1000
local DROP_KICK_PLAYER_PUSH = 300
local DROP_KICK_FAKE_CHANCE = 0.8
local KICK_STAMINA_COST = 10
local CROUCH_KICK_STAMINA_COST = 20
local DROP_KICK_STAMINA_COST = 35
local CURBSTOMP_STAMINA_COST = 12
local LEG_KICK_TRACE_RANGE = 28
local LEG_KICK_TRACE_SIZE = Vector(5, 5, 5)
local LEG_KICK_SEGMENT_SIZE = Vector(6, 6, 6)
local CURBSTOMP_DAMAGE_MUL = 2.4
local CURBSTOMP_HEAD_DAMAGE_MUL = 1.6
local CURBSTOMP_RAG_FORCE_MUL = 220
local CURBSTOMP_PROP_FORCE_MUL = 20
local CURBSTOMP_PLAYER_PUSH = 12
local CURBSTOMP_FAKE_CHANCE = 0.55
local CURBSTOMP_TRACE_RANGE = 24
local CURBSTOMP_TRACE_SIZE = Vector(6, 6, 6)
local CURBSTOMP_SEGMENT_SIZE = Vector(7, 7, 7)
local CURBSTOMP_HEAD_RADIUS = 16
local CURBSTOMP_HEAD_STOMPS_TO_POP = 5
local CURBSTOMP_HEAD_RESET = 8
local CURB_FLOOR_RANGE = 14
local CURB_SIDE_RANGE = 14
local CURB_LIP_RANGE = 9
local CURB_MIN_HEIGHT = 3
local CURB_MAX_HEIGHT = 30
local CURB_LIP_DROP = 5
local CURB_JAW_DMG_MIN = 1.6
local CURB_JAW_DMG_MAX = 2.8
local KICK_BLOCK_FRONT_DOT = 0.2
local KICK_DEFAULT_PARRY_WINDOW = 0.43
local KICK_PARRY_STUN = 1
local KICK_PARRY_PUSH = 160
local KICK_PARRY_STAMINA_REWARD = 6
local KICK_BLOCK_PUSH = 260
local KICK_BLOCK_DISABLE = 0.8
local KICK_BLOCK_STUN_CHANCE = 0.4
local KICK_BLOCK_STUN = 0.75

local function lightStunNextTick(ply, time)
    timer.Simple(0, function()
        if IsValid(ply) and ply:Alive() and hg.LightStunPlayer then hg.LightStunPlayer(ply, time) end
    end)
end

local function playKickBlockFx(ent, wep, trace, state)
    if wep.PlayBlockImpactEffect then
        wep:PlayBlockImpactEffect(trace, wep, state)
    else
        ent:EmitSound("physics/body/body_medium_impact_soft6.wav", 70, state == "parry" and 120 or 95)
    end
end

local function resolveKickBlock(kicker, ent, hitPos, normal)
    if not ent:IsPlayer() or IsValid(ent.FakeRagdoll) then return false end
    local wep = ent:GetActiveWeapon()
    if not IsValid(wep) or not wep.GetBlocking or not wep:GetBlocking() or not wep.GetStartedBlocking then return false end

    local toKicker = kicker:WorldSpaceCenter() - ent:WorldSpaceCenter()
    toKicker.z = 0
    toKicker:Normalize()
    local aim = ent:GetAimVector()
    aim.z = 0
    aim:Normalize()
    if aim:Dot(toKicker) < KICK_BLOCK_FRONT_DOT then return false end

    local trace = {HitPos = hitPos, HitNormal = -normal}
    local elapsed = CurTime() - wep:GetStartedBlocking()
    local window = wep.GetBlockParryWindow and wep:GetBlockParryWindow() or KICK_DEFAULT_PARRY_WINDOW

    if elapsed >= 0 and elapsed < window then
        playKickBlockFx(ent, wep, trace, "parry")
        sound.Play("clash/rem_clashblunt.wav", hitPos, 82, math.random(130, 150))

        local stamina = ent.organism and ent.organism.stamina
        if stamina then
            stamina[1] = math.min(stamina.max or stamina[1], stamina[1] + KICK_PARRY_STAMINA_REWARD)
        end

        kicker:SetVelocity(-normal * KICK_PARRY_PUSH)
        lightStunNextTick(kicker, KICK_PARRY_STUN)
        return true
    end

    playKickBlockFx(ent, wep, trace, "break")
    if wep.SetBlocking then wep:SetBlocking(false) end
    if wep.SetBlockDisabledUntil then wep:SetBlockDisabledUntil(CurTime() + KICK_BLOCK_DISABLE) end
    if wep.SetLastBlocked then wep:SetLastBlocked(CurTime()) end
    ent:SetVelocity(normal * KICK_BLOCK_PUSH)

    if math.Rand(0, 1) <= KICK_BLOCK_STUN_CHANCE then
        lightStunNextTick(ent, KICK_BLOCK_STUN)
    end
    return true
end

local function getKickDamageMul(ply)
	local mul = ply.MeleeDamageMul or 1
	mul = mul * (hg.GetSubRolePerk and hg.GetSubRolePerk(ply, "MeleeDamageMul", 1) or 1)
	mul = mul * (ply.GetTraitMultiplier and ply:GetTraitMultiplier("melee_damage", 1) or 1)

    local org = ply.organism
    if ply:IsBerserk() and org then
        mul = mul * (1 + (org.berserk or 0) * 5)
    end

    return math.max(mul, 0)
end

local function getBoneWorld(ent, boneName)
    if not IsValid(ent) then return end
    local bone = ent:LookupBone(boneName)
    if not bone then return end

    local matrix = ent:GetBoneMatrix(bone)
    if matrix then
        return matrix:GetTranslation(), matrix:GetAngles(), bone
    end

    local pos, ang = ent:GetBonePosition(bone)
    if pos and not pos:IsEqualTol(ent:GetPos(), 0.01) then
        return pos, ang, bone
    end

    return nil, nil, bone
end

local function getHeadPos(ent)
    local pos = getBoneWorld(ent, "ValveBiped.Bip01_Head1")
    if pos then return pos end
    return ent:LocalToWorld(ent:OBBCenter() + Vector(0, 0, ent:OBBMaxs().z * 0.75))
end

local function getHeadBone(ent)
    if not IsValid(ent) then return end
    return ent:LookupBone("ValveBiped.Bip01_Head1")
end

local function getHeadPhysBone(ent)
    local bone = getHeadBone(ent)
    if not bone then return end
    local physBone = ent:TranslateBoneToPhysBone(bone)
    if isnumber(physBone) and physBone >= 0 then
        return physBone
    end
end

local function traceLegSegment(self, startPos, endPos, size)
    local tr = util.TraceHull({
        start = startPos,
        endpos = endPos,
        filter = {hg.GetCurrentCharacter(self), self},
        maxs = size,
        mins = -size
    })

    return tr
end

local function getStompHeadCandidate(self, footPos)
    local bestEnt
    local bestHeadPos
    local bestDist = math.huge

    for _, ent in ipairs(ents.FindInSphere(footPos, CURBSTOMP_HEAD_RADIUS * 1.5)) do
        if not IsValid(ent) or ent == self or ent == hg.GetCurrentCharacter(self) then continue end
        if not (ent:IsPlayer() or ent:IsNPC() or ent:GetClass() == "prop_ragdoll") then continue end

        local headPos = getHeadPos(ent)
        if not headPos then continue end

        local dist = footPos:DistToSqr(headPos)
        if dist > CURBSTOMP_HEAD_RADIUS * CURBSTOMP_HEAD_RADIUS then continue end

        if dist < bestDist then
            bestDist = dist
            bestEnt = ent
            bestHeadPos = headPos
        end
    end

    if not IsValid(bestEnt) then return end

    return {
        Hit = true,
        Entity = bestEnt,
        HitPos = bestHeadPos,
        PhysicsBone = getHeadPhysBone(bestEnt) or 0
    }
end

local function getKickTrace(self, inDuck, isCurbstomp)
    local eyeAng = self:EyeAngles()
    local forward = eyeAng:Forward()
    local up = self:GetUp()
    local thighPos = getBoneWorld(self, "ValveBiped.Bip01_R_Thigh")
    local footPos = getBoneWorld(self, "ValveBiped.Bip01_R_Foot")
    local calfPos = getBoneWorld(self, "ValveBiped.Bip01_R_Calf")
    local size = isCurbstomp and CURBSTOMP_TRACE_SIZE or LEG_KICK_TRACE_SIZE
    local segmentSize = isCurbstomp and CURBSTOMP_SEGMENT_SIZE or LEG_KICK_SEGMENT_SIZE
    local fallbackPos = self:GetPos() + self:OBBCenter() + up * -5

    thighPos = thighPos or fallbackPos + up * 14
    calfPos = calfPos or fallbackPos + up * 3
    footPos = footPos or ((inDuck and fallbackPos) or self:EyePos())

    local kickDir
    if isCurbstomp then
        kickDir = (forward * 0.2 - up):GetNormalized()
    else
        kickDir = (forward + up * 0.12):GetNormalized()
    end

    local traces = {
        traceLegSegment(self, thighPos, calfPos, segmentSize),
        traceLegSegment(self, calfPos, footPos, segmentSize),
        traceLegSegment(self, footPos, footPos + kickDir * (isCurbstomp and CURBSTOMP_TRACE_RANGE or LEG_KICK_TRACE_RANGE), size)
    }

    for _, tr in ipairs(traces) do
        if tr.Hit and IsValid(tr.Entity) then
            return tr, kickDir, footPos
        end
    end

    if isCurbstomp then
        local headTr = getStompHeadCandidate(self, footPos)
        if headTr then
            return headTr, kickDir, footPos
        end
    end

    return traces[#traces], kickDir, footPos
end

local function getHeadCounterTarget(ent)
    if not IsValid(ent) then return end
    if ent:IsPlayer() then return ent end
    if ent.IsRagdoll and ent:IsRagdoll() then
        local owner = hg.RagdollOwner(ent)
        if IsValid(owner) then return owner end
    end
    return ent
end

local function canExplodeHead(ent)
    if not IsValid(ent) then return false end
    if ent.headexploded or ent.noHead then return false end
    if ent.organism and (ent.organism.noHead or ent.organism.headamputated) then return false end
    return ent:LookupBone("ValveBiped.Bip01_Head1") ~= nil
end

local function handleCurbstompHead(ent, hitPos)
    if not canExplodeHead(ent) then return end

    local headPos = getHeadPos(ent)
    if not headPos or headPos:DistToSqr(hitPos) > CURBSTOMP_HEAD_RADIUS * CURBSTOMP_HEAD_RADIUS then return end

    local counterEnt = getHeadCounterTarget(ent)
    if not IsValid(counterEnt) then return end

    local hits = ((counterEnt.CurbstompHeadExpire or 0) > CurTime()) and (counterEnt.CurbstompHeadHits or 0) or 0
    hits = hits + 1

    counterEnt.CurbstompHeadHits = hits
    counterEnt.CurbstompHeadExpire = CurTime() + CURBSTOMP_HEAD_RESET

    if hits >= CURBSTOMP_HEAD_STOMPS_TO_POP then
        counterEnt.CurbstompHeadHits = 0
        counterEnt.CurbstompHeadExpire = 0
        hg.ExplodeHead(ent)
    end
end

local function curbTraceFilter(ent)
    return not (ent:IsPlayer() or ent:IsNPC() or ent:IsRagdoll())
end

local function curbTrace(startPos, endPos)
    return util.TraceLine({start = startPos, endpos = endPos, filter = curbTraceFilter, mask = MASK_SOLID})
end

local function findCurbEdge(headPos)
    local floor = curbTrace(headPos, headPos - Vector(0, 0, CURB_FLOOR_RANGE))
    if not floor.Hit or floor.StartSolid or floor.HitNormal.z < 0.7 then return end
    local floorZ = floor.HitPos.z

    for i = 0, 7 do
        local dir = Angle(0, i * 45, 0):Forward()
        local side = curbTrace(headPos, headPos + dir * CURB_SIDE_RANGE)

        if side.Hit then
            if math.abs(side.HitNormal.z) < 0.6 then
                local probe = side.HitPos + dir * 3
                local top = curbTrace(Vector(probe.x, probe.y, floorZ + CURB_MAX_HEIGHT + 2), Vector(probe.x, probe.y, floorZ))
                if top.Hit and not top.StartSolid then
                    local height = top.HitPos.z - floorZ
                    if height >= CURB_MIN_HEIGHT and height <= CURB_MAX_HEIGHT then
                        return Vector(side.HitPos.x, side.HitPos.y, math.min(top.HitPos.z, headPos.z)), side.HitNormal
                    end
                end
            end
        else
            local lipStart = Vector(headPos.x, headPos.y, floorZ + 2)
            local lipEnd = lipStart + dir * CURB_LIP_RANGE
            if not curbTrace(lipStart, lipEnd).Hit then
                local drop = curbTrace(lipEnd, lipEnd - Vector(0, 0, CURB_MAX_HEIGHT + 10))
                if not drop.Hit or (floorZ - drop.HitPos.z) >= CURB_LIP_DROP then
                    return floor.HitPos + dir * (CURB_LIP_RANGE * 0.5), dir
                end
            end
        end
    end
end

local function tryCurbStompJaw(attacker, ent, inflictor, kickDir)
    local input = hg.organism and hg.organism.input_list and hg.organism.input_list.jaw
    if not input then return end

    local owner = hg.RagdollOwner(ent) or ent
    local org = (IsValid(owner) and owner.organism) or ent.organism
    if not org or not IsValid(org.owner) then return end

    local headPos = getHeadPos(ent)
    if not headPos then return end

    local edgePos, edgeNormal = findCurbEdge(headPos)
    if not edgePos then return end

    local dmginfo = DamageInfo()
    dmginfo:SetAttacker(attacker)
    dmginfo:SetInflictor(inflictor)
    dmginfo:SetDamage(30)
    dmginfo:SetDamageType(DMG_CLUB)
    dmginfo:SetDamageForce(kickDir * 3000)
    dmginfo:SetDamagePosition(headPos)

    local sprayDir = (edgeNormal + vector_up):GetNormalized()
    input(org, nil, math.Rand(CURB_JAW_DMG_MIN, CURB_JAW_DMG_MAX), dmginfo, nil, sprayDir, headPos)

    org.painadd = (org.painadd or 0) + 30
    org.shock = math.min((org.shock or 0) + 25, 95)
    if hg.organism.AddInstantPain then hg.organism.AddInstantPain(org, 25, "head") end

    for _ = 1, math.random(4, 6) do
        local normal = (sprayDir + VectorRand(-0.8, 0.8)):GetNormalized()
        local effect = EffectData()
        effect:SetOrigin(headPos)
        effect:SetNormal(normal)
        effect:SetMagnitude(2)
        effect:SetScale(1.2)
        effect:SetRadius(3)
        util.Effect("BloodImpact", effect, true, true)
        net.Start("hg_bloodimpact")
        net.WriteVector(headPos)
        net.WriteVector(normal * math.Rand(0.2, 0.45))
        net.WriteFloat(math.Rand(5, 9))
        net.WriteInt(math.random(5, 8), 8)
        net.SendPVS(headPos)
    end

    util.Decal("Blood", edgePos + edgeNormal * 4, edgePos - edgeNormal * 8, ent)
    util.Decal("Blood", headPos, headPos - Vector(0, 0, 24), ent)

    ent:EmitSound("physics/body/body_medium_break" .. math.random(2, 4) .. ".wav", 70, math.random(90, 105))
    ent:EmitSound("physics/flesh/flesh_bloody_break.wav", 65, math.random(95, 110))
end

function PLAYER:LegAttack()
    if not self:Alive() or hg.GetCurrentCharacter(self):IsRagdoll() or self:GetNWFloat("InLegKick",0) > CurTime() then return end
    if self.InLegKick and self.InLegKick > CurTime() then return end
    if self:GetNWBool("TauntStopMoving", false) then return end
    if hook.Run( "PlayerCanLegAttack", self ) == false then return end

    local isMidAir = not self:IsOnGround()
    if self:IsSprinting() and not isMidAir then return end

    if isMidAir and self.organism.stamina[1] < 70 then return end
	local org = self.organism
	local kickingLegEffectiveness = hg.GetLegEffectiveness and hg.GetLegEffectiveness(self, "rleg") or (org.legstrength or 1)
	if kickingLegEffectiveness <= 0 then return end

    local anim = "kick_pistol_base"
    anim = (self:KeyDown(IN_DUCK) or self:Crouching()) and "kick_pistol_base_crouch" or self:EyeAngles()[1] > 60 and "curbstomp_base" or self:EyeAngles()[1] > 35 and "kick_pistol_25_base" or self:EyeAngles()[1] > 20 and "kick_pistol_45_base" or anim

    if isMidAir then
        anim = self:EyeAngles()[1] > 60 and "curbstomp_midair" or self:EyeAngles()[1] > 35 and "kick_midair_25" or self:EyeAngles()[1] > 20 and "kick_midair_45" or "kick_midair"
        self:EmitSound("HOYAA.mp3", 75, 100)
    end

    self:EmitSound("panoptisscon/kickgrunt.wav", 65)

    local isCrouchKick = (self:KeyDown(IN_DUCK) or self:Crouching()) and not isMidAir
    local isCurbstomp = anim == "curbstomp_base"
    local staminaCost = isMidAir and DROP_KICK_STAMINA_COST or (isCurbstomp and CURBSTOMP_STAMINA_COST or (isCrouchKick and CROUCH_KICK_STAMINA_COST or KICK_STAMINA_COST))
    org.stamina.subadd = org.stamina.subadd + staminaCost
    local speedmul = (2 - (org.stamina[1] / org.stamina.max))
    local speed = 1.5 * speedmul
    local animstopAdjust = 0.3 * speedmul
	local kickSpeedMul = Lerp(kickingLegEffectiveness, 0.45, 1)
	speed = speed / kickSpeedMul
	animstopAdjust = animstopAdjust / kickSpeedMul
    local dmg = isCurbstomp and 22 or 10 * (2 - speedmul)
    dmg = dmg * getKickDamageMul(self)
    dmg = dmg * (self.KickDamageMul or 1)
	dmg = dmg * Lerp(kickingLegEffectiveness, 0.2, 1)
    dmg = dmg * (isCurbstomp and CURBSTOMP_DAMAGE_MUL or LEG_KICK_DAMAGE_MUL)
    dmg = dmg * (isCrouchKick and CROUCH_KICK_DAMAGE_MUL or 1)
    dmg = dmg * (isMidAir and DROP_KICK_DAMAGE_MUL or 1)
	if kickingLegEffectiveness < 0.95 then
		org.painadd = (org.painadd or 0) + (1 - kickingLegEffectiveness) * 8
	end
    --print(dmg)
    --print(speedmul)
    hook.Run("HomigradLegKick", self)
    self:PlayCustomAnims(anim, true, speed, true, animstopAdjust, {
        [0.12] = function(self)
            if hg.GetCurrentCharacter(self):IsRagdoll() then return end
            if !self:IsOnGround() and !isMidAir then self:PlayCustomAnims("") return end
            local ang = self:EyeAngles()
            ang[1] = 0

            --self:SetVelocity(ang:Forward() * -120)
            local reportPos = self:GetPos() + self:OBBCenter()
            local tr = util.TraceLine({
                start = reportPos,
                endpos = reportPos + ang:Forward() * 32,
                filter = {hg.GetCurrentCharacter(self),self}
            })
            if tr.Hit and (self:IsOnGround() or isMidAir) then
                self:SetVelocity(ang:Forward() * -300)
            end
        end,
        [0.21] = function(self)
            if hg.GetCurrentCharacter(self):IsRagdoll() then return end
            if !self:IsOnGround() and !isMidAir then self:PlayCustomAnims("") return end
            local ang = self:EyeAngles()
            if ang[1] > 55 and not (self:KeyDown(IN_DUCK) or self:Crouching()) then
				self:ViewPunch(vpang)
				return
			else
				self:ViewPunch(-vpang)
			end
            ang[1] = 0
            local reportPos = self:GetPos() + self:OBBCenter()
            local tr = util.TraceLine({
                start = reportPos,
                endpos = reportPos + ang:Forward() * 72,
                filter = {hg.GetCurrentCharacter(self),self}
            })
            if tr.Hit and (self:IsOnGround() or isMidAir) then
                --self:EmitSound("panoptisscon/kick.wav")
                self:SetVelocity(ang:Forward() * -150)
            end
        end,
        [0.33] = function(self) -- kick moment
            if hg.GetCurrentCharacter(self):IsRagdoll() then return end
            if !self:IsOnGround() and !isMidAir then self:PlayCustomAnims("") return end
            local ang = self:EyeAngles()
            ang[1] = 0

            self:EmitSound("player/shove_0" .. math.random(1,5) .. ".wav",65)

            local inDuck = (self:KeyDown(IN_DUCK) or self:Crouching())
            local tr, normal, footPos = getKickTrace(self, inDuck, isCurbstomp)

            local org = self.organism
            if hg.IsLimbFractured(org, "rleg") or org.rlegdislocation then
                org.painadd = org.painadd + 20
            end
            
            local entss = {}--ents.FindInBox( tr.HitPos + rad, tr.HitPos - rad )
            if !table.HasValue(entss, tr.Entity) then
                entss[#entss+1] = tr.Entity
            end
            local soundplayed = false
            local blacklist = {[self] = true, [hg.GetCurrentCharacter(self)] = true}
            if tr.Hit then
                soundplayed = true
                if hg.IsLimbFractured(org, "rleg") or org.rlegdislocation then
                    org.painadd = org.painadd + 20
                end
                self:EmitSound("panoptisscon/kick.wav")
            end

            if IsValid(tr.Entity) and tr.Entity.fires then
            local key, fire = next(tr.Entity.fires)

                if key then 
                    tr.Entity.fires[key] = nil

                    if IsValid(key) then
                        key:Remove()
                    end
                end
            end

            for k,ent in ipairs(entss) do
                if IsValid(ent) and not blacklist[ent] then
                    if hgIsDoor(ent) and not ent:GetNoDraw() then
                        local moveSpeed = self:GetVelocity():Length2D()
                        local impact = math.Clamp((dmg / 18) * 0.7 + moveSpeed / 900 + (isMidAir and 0.32 or 0), 0.2, 1.5)
                        hgKickDoor(ent, self, impact, normal, isMidAir)
                        continue
                    end

                    local phys = ent:GetPhysicsObjectNum(tr.PhysicsBone or 0)
                    if !ent:IsPlayer() and not IsValid(phys) then continue end

					local shieldTarget = hg.RagdollOwner(ent) or ent
					-- Leg kicks are unarmed attacks. Resolve the current hands SWEP so
					-- shield effects and damage attribution get a valid inflictor even
					-- when the player has no active weapon.
					local inflictor = hg.GetHandsWeapon and hg.GetHandsWeapon(self) or self
					if not IsValid(inflictor) then
						inflictor = self
					end
					if IsValid(shieldTarget) and shieldTarget:IsPlayer() and hook.Run("hg_ShieldKickBlock", shieldTarget, self, inflictor, self:EyePos(), tr.HitPos) then continue end
					if not isCurbstomp and resolveKickBlock(self, ent, tr.HitPos, normal) then continue end

                    if not soundplayed then
                        soundplayed = true

                        if hg.IsLimbFractured(org, "rleg") or org.rlegdislocation then
                            org.painadd = org.painadd + 20
                        end

                        self:EmitSound("panoptisscon/kick.wav")
                    end

                    local hitDmg = dmg
                    local stompHeadHit = isCurbstomp and footPos and getHeadPos(ent) and footPos:DistToSqr(getHeadPos(ent)) <= CURBSTOMP_HEAD_RADIUS * CURBSTOMP_HEAD_RADIUS
                    if stompHeadHit then
                        hitDmg = hitDmg * CURBSTOMP_HEAD_DAMAGE_MUL
                    end

                    local dmginfo = DamageInfo()

                    dmginfo:SetAttacker(self)
                    dmginfo:SetInflictor(inflictor)
                    dmginfo:SetDamage(dmg)
                    local ragForceMul = isCurbstomp and CURBSTOMP_RAG_FORCE_MUL or LEG_KICK_RAG_FORCE_MUL
                    local propForceMul = isCurbstomp and CURBSTOMP_PROP_FORCE_MUL or LEG_KICK_PROP_FORCE_MUL
                    local playerPush = isCurbstomp and CURBSTOMP_PLAYER_PUSH or LEG_KICK_PLAYER_PUSH
                    if isMidAir then
                        ragForceMul = DROP_KICK_RAG_FORCE_MUL
                        playerPush = DROP_KICK_PLAYER_PUSH
                    end
					local traitKickForce = self.GetTraitMultiplier and self:GetTraitMultiplier("kick_force", 1) or 1
					ragForceMul = ragForceMul * traitKickForce
					propForceMul = propForceMul * traitKickForce
					playerPush = playerPush * traitKickForce
                    local force = normal * hitDmg * ragForceMul

                    dmginfo:SetDamageForce(force)
                    dmginfo:SetDamageType((ent:GetClass() == "func_breakable_surf") and DMG_SLASH or DMG_CLUB)
                    dmginfo:SetDamagePosition(tr.HitPos)

                    PenetrationGlobal = 1
					MaxPenLenGlobal = 1
                    hg.AddForceRag(ent, tr.PhysicsBone or 0, force, 0.25)
                    ent:TakeDamageInfo(dmginfo)
                    
                    if IsValid(phys) then
                        phys:ApplyForceOffset(normal * hitDmg * propForceMul, tr.HitPos)
                    end

					if ent:IsPlayer() or ent:GetClass() == "prop_ragdoll" then
						ent:EmitSound("physics/body/body_medium_impact_hard"..math.random(6)..".wav", 60, math.random(85, 105), 0.6)
					end

                    if ent:IsPlayer() then
                        local fakeChance = isMidAir and DROP_KICK_FAKE_CHANCE or (isCurbstomp and CURBSTOMP_FAKE_CHANCE or (isCrouchKick and CROUCH_KICK_FAKE_CHANCE or LEG_KICK_FAKE_CHANCE))
                        if math.Rand(0, 1) <= fakeChance then
                            timer.Simple(0,function()
                                hg.Fake(ent)
                            end)
                        end

                        ent:SetVelocity(normal * playerPush)
                    end

                    if stompHeadHit then
                        tryCurbStompJaw(self, ent, inflictor, normal)
                    end

                    if isCurbstomp then
                        handleCurbstompHead(ent, footPos or tr.HitPos)
                    end
                end
            end
        end
    })
    self.InLegKick = CurTime() + speed - animstopAdjust
    self:SetNWFloat("InLegKick",CurTime() + speed - animstopAdjust)

    if isMidAir then
        timer.Simple(0.8, function()
            if IsValid(self) then
                hg.Fake(self)
            end
        end)
    end
end

hook.Add("HG_MovementCalc_2","HG-LegKickAnim",function(mul, ply, cmd, mv)
    if ply:GetNWFloat("InLegKick",0) > CurTime() then
        cmd:RemoveKey(IN_MOVELEFT)
        cmd:RemoveKey(IN_MOVERIGHT)
        cmd:RemoveKey(IN_JUMP)

        mv:RemoveKey(IN_MOVELEFT)
        mv:RemoveKey(IN_MOVERIGHT)
        mv:RemoveKey(IN_JUMP)

		mul[1] = mul[1] * math.min(math.max(0.001,1 - (ply:GetNWFloat("InLegKick",0) - CurTime()) * 2 ),1)

        if cmd:KeyDown(IN_DUCK) or ply:Crouching() then
            cmd:AddKey(IN_DUCK)
            mv:AddKey(IN_DUCK)
        else
            cmd:RemoveKey(IN_DUCK)
            mv:RemoveKey(IN_DUCK)
        end
    end
end)

concommand.Add("hg_kick",function(ply)
	if IsValid(ply.FakeRagdoll) and hg.FakeLegAttack then
		hg.FakeLegAttack(ply)
		return
	end

	ply:LegAttack()
end)
