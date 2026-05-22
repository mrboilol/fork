if CLIENT then return end

hg.MedicalMinigame = hg.MedicalMinigame or {}
hg.MedicalMinigame.AmputationSessions = hg.MedicalMinigame.AmputationSessions or {}
hg.MedicalMinigame.DislocationSessions = hg.MedicalMinigame.DislocationSessions or {}

local amputationLimbNames = {
    larm = "Left Arm",
    rarm = "Right Arm",
    lleg = "Left Leg",
    rleg = "Right Leg"
}

local amputationLimbBones = {
    larm = "ValveBiped.Bip01_L_Forearm",
    rarm = "ValveBiped.Bip01_R_Forearm",
    lleg = "ValveBiped.Bip01_L_Calf",
    rleg = "ValveBiped.Bip01_R_Calf"
}

local function GetAmputationCutWoundData(target, limb)
    local boneName = amputationLimbBones[limb]
    if not IsValid(target) or not boneName then
        return vector_origin, angle_zero, boneName
    end

    local boneIndex = target:LookupBone(boneName)
    if not boneIndex then
        return vector_origin, angle_zero, boneName
    end

    local upperBoneName = target:GetBoneName(boneIndex - 1)
    local boneLength = target:BoneLength(boneIndex)
    local cutOffset = Vector(boneLength > 0 and boneLength or 5, 0, 0)

    return cutOffset, angle_zero, upperBoneName or boneName
end

local function GetDislocationLimbFromGroup(target, group)
    if not IsValid(target) or not target.organism then return end

    local org = target.organism
    group = math.Round(tonumber(group) or 0)
    if group == 1 then
        if org.llegdislocation then return "lleg" end
        if org.rlegdislocation then return "rleg" end
    elseif group == 2 then
        if org.larmdislocation then return "larm" end
        if org.rarmdislocation then return "rarm" end
    elseif group == 3 then
        if org.jawdislocation then return "jaw" end
    end
end

local function ResolveMinigameTarget(ent)
    if IsValid(ent) and ent:IsRagdoll() then
        ent = hg.RagdollOwner(ent) or ent
    end

    if IsValid(ent) and ent:IsPlayer() then
        return ent
    end
end

local function CanUseMedicalMinigameTarget(ply, target)
    if not IsValid(ply) or not ply:Alive() then return false end
    if not IsValid(target) or not target:IsPlayer() or not target:Alive() then return false end
    if not target.organism then return false end
    if target ~= ply and ply:GetPos():DistToSqr(target:GetPos()) > 10000 then return false end
    return true
end

local function ApplyAmputationProgress(ply, session, progressDelta, swipeSpeed)
    local target = session.target
    local limb = session.limb
    if not CanUseMedicalMinigameTarget(ply, target) then return end
    if not amputationLimbNames[limb] or target.organism[limb .. "amputated"] then return end

    local org = target.organism
    local delta = math.max(progressDelta or 0, 0)
    if delta <= 0 then return end

    session.progress = math.Clamp((session.progress or 0) + delta, 0, 1)

    local speed = math.max(swipeSpeed or 0, 0)
    local normalizedSpeed = math.Clamp(speed / 700, 0, 1.9)
    local painScale = 0.08 + (normalizedSpeed ^ 1.55) * 2.7
    local painAmount = (0.1 + delta * 5.8) * painScale
    org.painadd = (org.painadd or 0) + painAmount

    local tooFastThreshold = 900
    if speed >= tooFastThreshold then
        local overSpeed = speed - tooFastThreshold
        org.painadd = (org.painadd or 0) + math.Clamp((overSpeed / 115) ^ 1.2, 4, 24)

        local dmgInfo = DamageInfo()
        local inflictor = game.GetWorld()
        if IsValid(ply) then
            local activeWeapon = ply:GetActiveWeapon()
            inflictor = IsValid(activeWeapon) and activeWeapon or ply
        end

        dmgInfo:SetAttacker(IsValid(ply) and ply or game.GetWorld())
        dmgInfo:SetInflictor(inflictor)
        dmgInfo:SetDamageType(DMG_SLASH)
        dmgInfo:SetDamage(math.Clamp(overSpeed / 700, 0.5, 3))
        target:TakeDamageInfo(dmgInfo)
    end
end

local function ApplyDislocationProgress(ply, session, progressDelta, appliedForce)
    local target = session.target
    local limb = session.limb
    if not CanUseMedicalMinigameTarget(ply, target) then return end
    if not limb or not target.organism[limb .. "dislocation"] then return end

    local delta = math.max(progressDelta or 0, 0)
    local force = math.max(appliedForce or 0, 0)
    local forceScale = math.Clamp(force, 0, 1.6)

    if delta <= 0 then
        if forceScale <= 0 then return end

        local org = target.organism
        local pushPain = 0.6 + (forceScale ^ 1.65) * 3.6
        local instantPart = pushPain * 0.9
        local slowPart = pushPain - instantPart
        org.avgpain = math.min((org.avgpain or 0) + instantPart, 150)
        org.painadd = (org.painadd or 0) + slowPart
        org.lasthit = CurTime()

        if forceScale > 0.95 then
            local extra = math.Clamp((forceScale - 0.95) * 8.5, 0.6, 6.5)
            org.avgpain = math.min((org.avgpain or 0) + extra * 0.9, 150)
            org.painadd = (org.painadd or 0) + extra * 0.1
            org.lasthit = CurTime()
        end

        return
    end

    session.progress = math.Clamp((session.progress or 0) + delta, 0, 1)

    local org = target.organism
    local painAmount = (0.12 + delta * 2.6) * (0.65 + (forceScale ^ 1.85) * 3.0)
    org.avgpain = math.min((org.avgpain or 0) + painAmount * 0.25, 150)
    org.painadd = (org.painadd or 0) + painAmount * 0.75
    org.lasthit = CurTime()

    if force > 0.95 then
        local extra = math.Clamp((force - 0.95) * 9, 0.7, 6.5)
        org.avgpain = math.min((org.avgpain or 0) + extra * 0.25, 150)
        org.painadd = (org.painadd or 0) + extra * 0.75
        org.lasthit = CurTime()
    end
end

local function ClearAmputationSessionsForPlayer(ply)
    hg.MedicalMinigame.AmputationSessions[ply] = nil

    for surgeon, session in pairs(hg.MedicalMinigame.AmputationSessions) do
        if session and session.target == ply then
            hg.MedicalMinigame.AmputationSessions[surgeon] = nil
        end
    end
end

local function ClearDislocationSessionsForPlayer(ply)
    hg.MedicalMinigame.DislocationSessions[ply] = nil

    for fixer, session in pairs(hg.MedicalMinigame.DislocationSessions) do
        if session and session.target == ply then
            hg.MedicalMinigame.DislocationSessions[fixer] = nil
        end
    end
end

function hg.MedicalMinigame.StartAmputationMinigame(ply, ent, limb)
    local target = ResolveMinigameTarget(ent) or ply
    if not CanUseMedicalMinigameTarget(ply, target) then return false end
    if not amputationLimbNames[limb] then return false end
    if target.organism[limb .. "amputated"] then return false end

    local existingSession = hg.MedicalMinigame.AmputationSessions[ply]
    if not existingSession or existingSession.target ~= target or existingSession.limb ~= limb then
        existingSession = {
            target = target,
            limb = limb,
            progress = 0
        }
        hg.MedicalMinigame.AmputationSessions[ply] = existingSession
    end

    net.Start("hg_medical_minigame_start")
    net.WriteString("amputation")
    net.WriteEntity(target)
    net.WriteString(limb)
    net.WriteFloat(math.Clamp(existingSession.progress or 0, 0, 1))
    net.Send(ply)

    return true
end

function hg.MedicalMinigame.StartDislocationMinigame(ply, ent, group)
    local target = ResolveMinigameTarget(ent) or ply
    if not CanUseMedicalMinigameTarget(ply, target) then return false end

    local limb = GetDislocationLimbFromGroup(target, group)
    if not limb then return false end

    local existingSession = hg.MedicalMinigame.DislocationSessions[ply]
    if not existingSession or existingSession.target ~= target or existingSession.limb ~= limb then
        existingSession = {
            target = target,
            limb = limb,
            progress = 0,
            side = math.random(0, 1) == 1 and 1 or -1
        }
        hg.MedicalMinigame.DislocationSessions[ply] = existingSession
    end

    net.Start("hg_medical_minigame_start")
    net.WriteString("dislocation")
    net.WriteEntity(target)
    net.WriteString(limb)
    net.WriteFloat(math.Clamp(existingSession.progress or 0, 0, 1))
    net.WriteInt(existingSession.side or 1, 3)
    net.Send(ply)

    return true
end

net.Receive("hg_medical_minigame_request_amputation", function(len, ply)
    local ent = net.ReadEntity()
    local limb = net.ReadString()
    hg.MedicalMinigame.StartAmputationMinigame(ply, ent, limb)
end)

net.Receive("hg_medical_minigame_cancel", function(len, ply)
    local minigameType = net.ReadString()
    if minigameType == "amputation" then
        ClearAmputationSessionsForPlayer(ply)
        return
    end

    if minigameType == "dislocation" then
        ClearDislocationSessionsForPlayer(ply)
        return
    end
end)

hook.Add("PlayerDeath", "hg_medical_minigame_clear_amputation_progress", function(ply)
    ClearAmputationSessionsForPlayer(ply)
    ClearDislocationSessionsForPlayer(ply)
end)

local function GetMedicalMinigameType(wep)
    local class = wep:GetClass()

    -- Skip weapons that have their own circle minigame system (existing bandages)
    if wep.ShouldUseCircleMinigame and wep:ShouldUseCircleMinigame() then
        return nil
    end

    if wep.TryStartCircleMinigame then
        return nil
    end

    if class == "weapon_bruicekit" or class == "weapon_bandage_sh" or class == "weapon_bigbandage_sh" or (class == "weapon_medkit_sh" and wep.mode == 1) then
        return "bandage"
    end

    if class == "weapon_tourniquet" or (class == "weapon_medkit_sh" and wep.mode == 4) then
        return "tourniquet"
    end

    if class == "weapon_morphine" or class == "weapon_fentanyl" or (class == "weapon_medkit_sh" and wep.mode == 3) then
        return "syringe"
    end
end

-- Expose function for external use (e.g., zcity_delta weapon patch)
hg.MedicalMinigame.GetMedicalMinigameType = GetMedicalMinigameType

local function ApplyBruiceKitProgress(wep, ply, target, progressDelta)
    local org = target.organism
    if not org then return end
    if not wep.modeValues or not wep.modeValues[1] then return end

    local requested = math.max(progressDelta or 0, 0) * 40
    if requested <= 0 then return end

    local currentAmount = math.max(tonumber(wep.modeValues[1]) or 0, 0)
    local consumed = math.min(requested, currentAmount)
    if consumed <= 0 then return end

    wep.modeValues[1] = math.max(currentAmount - consumed, 0)

    local heal = consumed / 40
    local keys = {
        "larm",
        "rarm",
        "lleg",
        "rleg",
        "pelvis",
        "spine1",
        "spine2",
        "spine3",
        "chest",
        "skull"
    }

    local bestKey = nil
    local bestVal = 0
    for i = 1, #keys do
        local key = keys[i]
        local skip = (key == "larm" and org.larmamputated)
            or (key == "rarm" and org.rarmamputated)
            or (key == "lleg" and org.llegamputated)
            or (key == "rleg" and org.rlegamputated)
        if not skip then
            local v = tonumber(org[key] or 0) or 0
            if v > bestVal then
                bestVal = v
                bestKey = key
            end
        end
    end

    if bestKey and bestVal > 0.01 then
        org[bestKey] = math.max(bestVal - heal, 0)
    end

    wep:SetNetVar("modeValues", table.Copy(wep.modeValues))
end

local function GetMinigameModeValueIndex(wep, minigameType)
    if minigameType == "tourniquet" then
        if wep:GetClass() == "weapon_medkit_sh" then
            return 4
        end

        return 1
    end

    if minigameType == "syringe" then
        if wep:GetClass() == "weapon_medkit_sh" then
            return 3
        end

        return 1
    end

    return 1
end

local function ApplySyringeProgress(wep, ply, target, progressDelta)
    local org = target.organism
    if not org then return end

    local modeValueIndex = GetMinigameModeValueIndex(wep, "syringe")
    if not wep.modeValues or not wep.modeValues[modeValueIndex] then return end

    local owner = wep:GetOwner()
    if not IsValid(owner) then return end

    local configuredValue = wep.modeValuesdef and wep.modeValuesdef[modeValueIndex]
    local maxValue = wep.HGMedicalMinigameStartValue or (istable(configuredValue) and configuredValue[1] or configuredValue) or 1
    local requestedAmount = math.max(progressDelta, 0) * math.max(tonumber(maxValue) or 0, 0)
    if requestedAmount <= 0 then return end

    local currentAmount = math.max(tonumber(wep.modeValues[modeValueIndex]) or 0, 0)
    local consumedAmount = math.min(requestedAmount, currentAmount)
    if consumedAmount <= 0 then return end

    wep.modeValues[modeValueIndex] = math.max(currentAmount - consumedAmount, 0)

    local class = wep:GetClass()
    local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
    if class == "weapon_morphine" or class == "weapon_fentanyl" then
        local mul = class == "weapon_fentanyl" and 5 or 1
        local cap = class == "weapon_fentanyl" and 25 or 4
        org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + consumedAmount * mul, cap)

        owner.injectedinto = owner.injectedinto or {}
        owner.injectedinto[org.owner] = owner.injectedinto[org.owner] or 0
        owner.injectedinto[org.owner] = owner.injectedinto[org.owner] + consumedAmount

        if owner.injectedinto[org.owner] > 1 then
            local dmgInfo = DamageInfo()
            dmgInfo:SetAttacker(owner)

            local overdoseMul = class == "weapon_fentanyl" and (zb and zb.MaximumHarm or 10) or (zb and zb.MaximumHarm or 1)
            local character = (hg and hg.GetCurrentCharacter) and hg.GetCurrentCharacter(org.owner) or org.owner
            hook.Run("HomigradDamage", org.owner, dmgInfo, HITGROUP_RIGHTARM, character, consumedAmount * overdoseMul)
        end

        entOwner:EmitSound("pshiksnd")
    elseif class == "weapon_medkit_sh" and wep.mode == 3 then
        local efficiency = owner.Profession == "doctor" and 0.5 or 1
        local internalBleed = math.max((org.internalBleed or 0) - (org.internalBleedHeal or 0), 0)
        local healAmount = math.min(internalBleed, consumedAmount / efficiency)

        org.internalBleedHeal = (org.internalBleedHeal or 0) + healAmount
        entOwner:EmitSound("snds_jack_gmod/ez_medical/" .. math.random(16, 18) .. ".wav", 60, math.random(95, 105))
    end

    if wep.poisoned2 then
        org.poison4 = CurTime()
        wep.poisoned2 = nil
    end

    wep:SetNetVar("modeValues", table.Copy(wep.modeValues))
end

-- Incremental healing based on minigame progress
net.Receive("hg_medical_minigame_progress", function(len, ply)
    local progressDelta = net.ReadFloat()
    local wep = ply:GetActiveWeapon()
    local minigameType = IsValid(wep) and GetMedicalMinigameType(wep) or nil

    if minigameType then
        if minigameType == "bandage" and wep:GetClass() == "weapon_medkit_sh" and wep.mode ~= 1 then return end
        if minigameType == "syringe" and wep:GetClass() == "weapon_medkit_sh" and wep.mode ~= 3 then return end

        local target = wep.healbuddy or ply
        if not IsValid(target) then return end
        if target ~= ply and ply:GetPos():DistToSqr(target:GetPos()) > 10000 then return end

        local org = target.organism
        if not org then return end

        if minigameType == "syringe" then
            ApplySyringeProgress(wep, ply, target, progressDelta)
            return
        end

        if minigameType == "bandage" and wep:GetClass() == "weapon_bruicekit" then
            ApplyBruiceKitProgress(wep, ply, target, progressDelta)
            return
        end

        local healAmount = 55 * progressDelta
        local modeValueIndex = GetMinigameModeValueIndex(wep, "bandage")
        if wep.modeValues and wep.modeValues[modeValueIndex] then
            if #org.wounds > 0 then
                table.sort(org.wounds, function(a, b) return a[1] > b[1] end)

                local woundSize = org.wounds[1][1]
                local healed = math.min(woundSize, healAmount)

                org.wounds[1][1] = org.wounds[1][1] - healed
                org.bleed = math.max(org.bleed - healed, 0)
                wep.modeValues[modeValueIndex] = math.max(wep.modeValues[modeValueIndex] - (healed * 0.6), 0)
                wep:SetNetVar("modeValues", table.Copy(wep.modeValues))
                ply:SetNetVar("wounds", org.wounds)
            else
                local attemptedUse = healAmount * 0.6
                wep.modeValues[modeValueIndex] = math.max(wep.modeValues[modeValueIndex] - attemptedUse, 0)
                wep:SetNetVar("modeValues", table.Copy(wep.modeValues))
            end
        end

        return
    end

    local dislocationSession = hg.MedicalMinigame.DislocationSessions[ply]
    if dislocationSession then
        local appliedForce = net.ReadFloat()
        local target = dislocationSession.target
        local limb = dislocationSession.limb

        if not CanUseMedicalMinigameTarget(ply, target) or not limb or not target.organism[limb .. "dislocation"] then
            hg.MedicalMinigame.DislocationSessions[ply] = nil
            return
        end

        ApplyDislocationProgress(ply, dislocationSession, progressDelta, appliedForce)
        return
    end

    local amputationSession = hg.MedicalMinigame.AmputationSessions[ply]
    if amputationSession then
        local swipeSpeed = net.ReadFloat()
        local target = amputationSession.target
        local limb = amputationSession.limb

        if not CanUseMedicalMinigameTarget(ply, target) or not amputationLimbNames[limb] or target.organism[limb .. "amputated"] then
            hg.MedicalMinigame.AmputationSessions[ply] = nil
            return
        end

        ApplyAmputationProgress(ply, amputationSession, progressDelta, swipeSpeed)
    end
end)

net.Receive("hg_medical_minigame_finish", function(len, ply)
    local requestedType = net.ReadString()
    local reportedProgress = math.Clamp(net.ReadFloat() or 0, 0, 1)

    if requestedType == "amputation" then
        local amputationSession = hg.MedicalMinigame.AmputationSessions[ply]
        if not amputationSession then return end

        local target = amputationSession.target
        local limb = amputationSession.limb
        if not CanUseMedicalMinigameTarget(ply, target) or not amputationLimbNames[limb] then return end
        if target.organism[limb .. "amputated"] then
            hg.MedicalMinigame.AmputationSessions[ply] = nil
            return
        end

        amputationSession.progress = math.max(amputationSession.progress or 0, reportedProgress)
        if (amputationSession.progress or 0) < 0.999 then return end

        hg.MedicalMinigame.AmputationSessions[ply] = nil
        hg.organism.AmputateLimb(target.organism, limb)
        return
    end

    if requestedType == "dislocation" then
        local dislocationSession = hg.MedicalMinigame.DislocationSessions[ply]
        if not dislocationSession then return end

        local target = dislocationSession.target
        local limb = dislocationSession.limb
        if not CanUseMedicalMinigameTarget(ply, target) or not limb then return end
        if not target.organism[limb .. "dislocation"] then
            hg.MedicalMinigame.DislocationSessions[ply] = nil
            return
        end

        dislocationSession.progress = math.max(dislocationSession.progress or 0, reportedProgress)
        if (dislocationSession.progress or 0) < 0.999 then return end

        hg.MedicalMinigame.DislocationSessions[ply] = nil

        if hg.organism and hg.organism.CompleteDislocationFix then
            hg.organism.CompleteDislocationFix(target.organism, limb, ply)
        else
            local org = target.organism
            org[limb .. "dislocation"] = false
            org.painadd = (org.painadd or 0) + 6
            org.fearadd = (org.fearadd or 0) + 0.1
            target:EmitSound("physics/flesh/flesh_impact_hard6.wav", 65)
        end

        return
    end

    local wep = ply:GetActiveWeapon()
    local minigameType = IsValid(wep) and GetMedicalMinigameType(wep) or nil
    if minigameType then
        local target = wep.healbuddy or ply
        if not IsValid(target) then target = ply end

        if target ~= ply and ply:GetPos():DistToSqr(target:GetPos()) > 10000 then return end

        if minigameType == "tourniquet" then
            local modeValueIndex = GetMinigameModeValueIndex(wep, minigameType)
            local mode = wep.mode
            local done = wep:Heal(target, mode)

            if IsValid(wep) and done and wep.PostHeal then
                wep:PostHeal(target, mode)
            end

            if IsValid(wep) and not done and wep.modeValues and wep.modeValues[modeValueIndex] then
                wep.modeValues[modeValueIndex] = 0

                if wep:GetClass() == "weapon_tourniquet" and wep.ShouldDeleteOnFullUse then
                    ply:SelectWeapon("weapon_hands_sh")
                    wep:Remove()
                    return
                end
            end

            if IsValid(wep) and wep.modeValues then
                wep:SetNetVar("modeValues", table.Copy(wep.modeValues))
            end

            return
        end

        wep.HGMedicalMinigameStartValue = nil

        if wep.modeValues then
            local allEmpty = true
            for i, v in ipairs(wep.modeValues) do
                if v > 0 then allEmpty = false break end
            end

            if allEmpty and wep.ShouldDeleteOnFullUse then
                ply:SelectWeapon("weapon_hands_sh")
                wep:Remove()
            end
        end

        return
    end

    if not IsValid(wep) then return end
end)

local function ResolveEyeTarget(ply)
    if not IsValid(ply) then return nil end
    local tr = ply:GetEyeTrace()
    local ent = tr and tr.Entity or nil
    if not IsValid(ent) then return nil end
    if ent:IsRagdoll() and hg and hg.RagdollOwner then
        ent = hg.RagdollOwner(ent) or ent
    end
    if not IsValid(ent) then return nil end
    if not ent:IsPlayer() or not ent:Alive() or not ent.organism then return nil end
    if ent ~= ply and ply:GetPos():DistToSqr(ent:GetPos()) > 10000 then return nil end
    return ent
end

local function StartWeaponMinigameFromCommand(ply, requestedType, useTarget)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply.organism and ply.organism.otrub then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end

    local minigameType = GetMedicalMinigameType(wep)
    if not minigameType or minigameType ~= requestedType then
        ply:ChatPrint("Wrong weapon for minigame: " .. tostring(requestedType))
        return
    end

    local target = useTarget and ResolveEyeTarget(ply) or ply
    if useTarget and not IsValid(target) then
        ply:ChatPrint("No valid target.")
        return
    end

    local modeValueIndex = GetMinigameModeValueIndex(wep, minigameType)
    local startValue = wep.modeValues and wep.modeValues[modeValueIndex] or nil
    wep.healbuddy = target
    wep.HGMedicalMinigameStartValue = startValue

    net.Start("hg_medical_minigame_start")
        net.WriteString(minigameType)
    net.Send(ply)
end

concommand.Add("hg_med_minigame", function(ply, cmd, args)
    local requestedType = tostring(args and args[1] or "")
    local useTarget = tostring(args and args[2] or "") == "target"

    if requestedType ~= "bandage" and requestedType ~= "tourniquet" and requestedType ~= "syringe" then
        if IsValid(ply) then
            ply:ChatPrint("Usage: hg_med_minigame <bandage|tourniquet|syringe> [target]")
        end
        return
    end

    StartWeaponMinigameFromCommand(ply, requestedType, useTarget)
end)

concommand.Add("hg_med_amputate", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local limb = tostring(args and args[1] or "")
    if not amputationLimbNames[limb] then
        ply:ChatPrint("Usage: hg_med_amputate <larm|rarm|lleg|rleg> [target]")
        return
    end

    local useTarget = tostring(args and args[2] or "") == "target"
    local ent = useTarget and ResolveEyeTarget(ply) or ply
    hg.MedicalMinigame.StartAmputationMinigame(ply, ent, limb)
end)

concommand.Add("hg_med_dislocation", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local group = tonumber(args and args[1] or nil)
    if group ~= 1 and group ~= 2 and group ~= 3 then
        ply:ChatPrint("Usage: hg_med_dislocation <1|2|3> [target]")
        return
    end

    local useTarget = tostring(args and args[2] or "") == "target"
    local ent = useTarget and ResolveEyeTarget(ply) or ply
    hg.MedicalMinigame.StartDislocationMinigame(ply, ent, group)
end)

concommand.Add("hg_heartstop", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local useTarget = tostring(args and args[1] or "") == "target"
    local ent = useTarget and ResolveEyeTarget(ply) or ply
    if not IsValid(ent) or not ent.organism then return end

    ent.organism.heartstop = true
    ent.organism.pulse = 0
    ent.organism.heartbeat = 0
end)

concommand.Add("hg_heartstart", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local useTarget = tostring(args and args[1] or "") == "target"
    local ent = useTarget and ResolveEyeTarget(ply) or ply
    if not IsValid(ent) or not ent.organism then return end

    ent.organism.heartstop = false
end)
