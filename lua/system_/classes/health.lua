DMS_Health = DMS_Health or {}
DMS_Health.Active = DMS_Health.Active or {}

setmetatable(DMS_Health.Active, { __mode = "k" })

local IsValid = IsValid
local CurTime = CurTime
local math = math
local pairs = pairs
local hook = hook
local next = next

local m_max = math.max
local m_Clamp = math.Clamp
local m_ceil = math.ceil
local m_Rand = math.Rand

local DEBUG_BLEED = false

local cv_metab_min  = GetConVar("sv_health_metab_min") or CreateConVar("sv_health_metab_min", "1.0", FCVAR_ARCHIVE)
local cv_metab_max  = GetConVar("sv_health_metab_max") or CreateConVar("sv_health_metab_max", "3.0", FCVAR_ARCHIVE)
local cv_bleed_sens = GetConVar("sv_health_bleed_sensitivity") or CreateConVar("sv_health_bleed_sensitivity", "0.1", FCVAR_ARCHIVE)
local cv_bleed_mult = GetConVar("sv_health_bleed_damage_mult") or CreateConVar("sv_health_bleed_damage_mult", "1.0", FCVAR_ARCHIVE)
local cv_max_tick   = GetConVar("sv_health_max_bleed_tick") or CreateConVar("sv_health_max_bleed_tick", "5", FCVAR_ARCHIVE)

function DMS_Health.new(ragdoll, maxHP)
    if not IsValid(ragdoll) then return end
    if DMS_Health.Active[ragdoll] then return DMS_Health.Active[ragdoll] end

    if not maxHP or maxHP <= 0 then maxHP = 100 end
    
    if SERVER then
        ragdoll:SetMaxHealth(maxHP)
        ragdoll:SetHealth(maxHP)
    end

    local data = {
        maxHP = maxHP,
        currentHP = maxHP,
        dead = false,
        seed = ragdoll:EntIndex() + CurTime(),
        metabolism = m_Rand(cv_metab_min:GetFloat(), cv_metab_max:GetFloat()),
        vitalityScale = m_Rand(3.0, 6.0),
        clottingFactor = m_Rand(0.005, 0.01),
        isBleeding = true, 
        bleedSeverity = 5,
        nextBleedTick = 0,
        soundStopped = false
    }

    DMS_Health.Active[ragdoll] = data
    return data
end

function DMS_Health:ApplyDamage(ent, amount)
    if not IsValid(ent) or not amount or amount <= 0 then return end
    
    local data = self.Active[ent]
    if not data then
        local hp = ent:GetMaxHealth()
        data = self.new(ent, hp > 0 and hp or 100)
    end
    
    if not data or data.dead then return end
    
    data.currentHP = m_max(0, data.currentHP - amount)
    data.isBleeding = true
    data.nextBleedTick = 0 
    
    local addedSeverity = amount * cv_bleed_sens:GetFloat()
    data.bleedSeverity = m_Clamp(data.bleedSeverity + addedSeverity, 10, 50)

    if SERVER then
        ent:SetHealth(m_ceil(data.currentHP))
    end

    if data.currentHP <= 0 then 
        self:Die(ent) 
    end
end

local nextMasterThink = 0

hook.Add("Think", "Health_MasterBleedSystem", function()
    local ct = CurTime()
    if ct < nextMasterThink then return end
    nextMasterThink = ct + 0.1
    
    if not next(DMS_Health.Active) then return end
    
    local bleed_mult_val = cv_bleed_mult:GetFloat()
    local max_tick_val = cv_max_tick:GetFloat()
    
    for ent, data in pairs(DMS_Health.Active) do
        if not IsValid(ent) then 
            DMS_Health.Active[ent] = nil 
            continue 
        end
        
        if data.dead or ct < data.nextBleedTick then continue end
        
        data.nextBleedTick = ct + 1.0 
        local baseDecay = (data.bleedSeverity * 0.05) * data.metabolism
        local decay = baseDecay * bleed_mult_val
        
        if decay ~= decay then decay = 0 end
        decay = m_Clamp(decay, 0.1, max_tick_val)

        data.currentHP = data.currentHP - decay
        
        if SERVER then
            ent:SetHealth(m_ceil(data.currentHP))
        end
        
        if DEBUG_BLEED then
            print("Ragdoll " .. ent:EntIndex() .. " draining: -" .. math.Round(decay, 2) .. " | HP: " .. math.Round(data.currentHP))
        end

        data.bleedSeverity = m_max(5, data.bleedSeverity - 0.5)

        if data.currentHP < 15 and not data.soundStopped then
            if SoundManager and SoundManager.Stop then
                SoundManager:Stop(ent, 0.2)
                data.soundStopped = true
            end
        end

        if data.currentHP <= 0 then 
            DMS_Health:Die(ent) 
        end
    end
end)

function DMS_Health:Die(ent)
    if not IsValid(ent) then return end
    
    local data = self.Active[ent]
    if data and data.dead then return end 
    if data then data.dead = true end
    
    if SoundManager and SoundManager.Stop then SoundManager:Stop(ent, 0.1) end
    if RagdollFaceAnimator and RagdollFaceAnimator.DeathRelax then RagdollFaceAnimator:DeathRelax(ent) end
    if AnimatedHands and AnimatedHands.RemoveEntity then AnimatedHands:RemoveEntity(ent) end

    local success = false
    if ActiveRagdoll and ActiveRagdoll.Get then
        local ar = ActiveRagdoll.Get(ent)
        if ar and ar.Destroy then 
            ar:Destroy() 
            success = true
        end
    end

    if not success and DMS and DMS.ActiveRagdolls then
        local entIndex = ent:EntIndex()
        local ar = DMS.ActiveRagdolls[entIndex]
        if ar then
            if ar.Destroy then 
                ar:Destroy()
            elseif DMS.Cleanup then 
                DMS:Cleanup(ar) 
            end
            DMS.ActiveRagdolls[entIndex] = nil
        end
    end
end