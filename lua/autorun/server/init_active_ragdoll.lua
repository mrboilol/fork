local IsValid = IsValid
local pcall = pcall
local ipairs = ipairs
local tostring = tostring
local include = include
local CurTime = CurTime
local hook_Add = hook.Add
local timer_Simple = timer.Simple
local math_Rand = math.Rand
local math_min = math.min
local string_find = string.find

local HEAD_BONE = "ValveBiped.Bip01_Head1"
local MIN_PHYS_VEL_SQR = 22500 

local ArtagdollEnabledCvar = GetConVar("ar_enabled")
local ArtagdollEnabledPLAYERCvar = GetConVar("ar_enabled_players")
local ArtagdollEnabledNPCSCvar = GetConVar("ar_enabled_npcs")

DMS = DMS or {}

local function SafeInclude(f)
    if file.Exists(f, "LUA") then
        local status, err = pcall(function() include(f) end)
        if not status then
            ErrorNoHalt("[DMS] Error including " .. f .. ": " .. tostring(err) .. "\n")
        end
    end
end

if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("system_/DMS/DMS_Physics.lua")
    AddCSLuaFile("system_/DMS/DMS_Core.lua")
end

SafeInclude("system_/DMS/DMS_Physics.lua")
SafeInclude("system_/DMS/DMS_Core.lua")
SafeInclude("system_/classes/Health.lua")
SafeInclude("system_/classes/ActiveRagdoll.lua")
SafeInclude("system_/classes/ActiveRagdollManager.lua")
SafeInclude("system_/utils/SoundManager.lua")
SafeInclude("system_/DMS/Expressions/hands.lua") 
include("system_/DMS/Expressions/face.lua")
SafeInclude("system_/Physics/Stiff.lua") 

local bPath = "system_/DMS/Behaviors/"
local bFiles, _ = file.Find(bPath .. "*.lua", "LUA")
if bFiles then
    for i = 1, #bFiles do
        local f = bFiles[i]
        if SERVER then AddCSLuaFile(bPath .. f) end
        SafeInclude(bPath .. f)
    end
end

-- player support (FROM OLDER FEDHORIA!!) thanks rama !!

local PLAYER = FindMetaTable("Player")
local oldCreateRagdoll = PLAYER.CreateRagdoll
local oldGetRagdollEntity = PLAYER.GetRagdollEntity

local dolls = setmetatable({}, { __mode = "k" })

local function CreateRagdoll(self)
    if self.organism then return end
    SafeRemoveEntity(dolls[self])

    local ragdoll = ents.Create("prop_ragdoll")
    ragdoll:SetModel(self:GetModel())
    ragdoll:SetPos(self:GetPos())
    ragdoll:SetAngles(self:GetAngles())
    ragdoll:Spawn()

    ragdoll:SetSkin(self:GetSkin())

    for i = 0, self:GetNumBodyGroups() - 1 do
        ragdoll:SetBodygroup(i, self:GetBodygroup(i))
    end

    for i = 0, ragdoll:GetPhysicsObjectCount()-1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        local bone = ragdoll:TranslatePhysBoneToBone(i)
        local matrix = self:GetBoneMatrix(bone)
        if matrix then
            local pos, ang = matrix:GetTranslation(), matrix:GetAngles()
            phys:SetPos(pos)
            phys:SetAngles(ang)
        end
        phys:SetVelocity(self:GetVelocity())
    end

    self:SpectateEntity(ragdoll)
    self:Spectate(OBS_MODE_CHASE)

    dolls[self] = ragdoll
end

local function GetRagdollEntity(self)
    if self.organism then return oldGetRagdollEntity(self) end
    return dolls[self] or NULL
end

PLAYER.CreateRagdoll = CreateRagdoll
PLAYER.GetRagdollEntity = GetRagdollEntity

if ArtagdollEnabledCvar and ArtagdollEnabledCvar:GetBool() then
    PLAYER.CreateRagdoll = CreateRagdoll
    PLAYER.GetRagdollEntity = GetRagdollEntity
end

cvars.AddChangeCallback("ar_enabled_players", function(name, old, new)
    if (new == "1") then
        if ArtagdollEnabledCvar and ArtagdollEnabledCvar:GetBool() then
            if (debug.getinfo(PLAYER.CreateRagdoll).short_src == "[C]") then
                PLAYER.CreateRagdoll = CreateRagdoll
                PLAYER.GetRagdollEntity = GetRagdollEntity
            end
        end
    else
        PLAYER.CreateRagdoll = oldCreateRagdoll
        PLAYER.GetRagdollEntity = oldGetRagdollEntity
    end
end, "DMS_Player_Callback")

--

hook_Add("ScaleNPCDamage", "DMS_NPC_HeadshotDetect", function(npc, hitgroup, dmginfo)
    if not IsValid(npc) then return end
    npc.DMS_IsHeadshot = (hitgroup == HITGROUP_HEAD)
end)

hook_Add("ScalePlayerDamage", "DMS_Player_HeadshotDetect", function(ply, hitgroup, dmginfo)
    if not IsValid(ply) then return end
    ply.DMS_IsHeadshot = (hitgroup == HITGROUP_HEAD)
end)

local function RegisterPhysicsHooks()
    if DMS.PhysicsActive then return end

    hook_Add("CreateEntityRagdoll", "DMS_Init", function(owner, ragdoll)
        if not ArtagdollEnabledCvar or not ArtagdollEnabledNPCSCvar then return end
        if (!ArtagdollEnabledCvar:GetBool() or !ArtagdollEnabledNPCSCvar:GetBool()) then return end
        if not IsValid(owner) or not IsValid(ragdoll) then return end
        if not owner:IsNPC() or owner.organism or ragdoll.organism then return end
        
        if ragdoll:GetPhysicsObjectCount() < 2 then return end

        local bone = ragdoll:LookupBone("ValveBiped.Bip01_Pelvis")
        if not bone or bone == -1 then return end

        local cls = owner:GetClass()
        if string_find(cls, "zombie") or string_find(cls, "headcrab") then return end

        if owner:IsOnFire() then 
            ragdoll:Ignite(math_Rand(8, 15)) 
        end
        
        if owner.DMS_IsHeadshot then 
            ragdoll.DMS_IsHeadshot = true 
        end

        local dmgpos = owner.DMS_LastDmgPos

        timer_Simple(0.05, function()
            if not IsValid(ragdoll) or ragdoll:IsMarkedForDeletion() then return end
            if ragdoll.organism then return end
            if not ActiveRagdollManager then return end

            ActiveRagdollManager.Run(ragdoll, dmgpos)
            ragdoll.DMS_Initialized = true
        end)
    end)
    
    hook.Add("PostPlayerDeath", "Fedhoria", function(ply)
        if ply.organism then return end
        if not ArtagdollEnabledCvar or not ArtagdollEnabledPLAYERCvar then return end
        if (!ArtagdollEnabledCvar:GetBool() or !ArtagdollEnabledPLAYERCvar:GetBool()) then return end
        
        timer_Simple(0.05, function()
            if not IsValid(ply) then return end
            
            local ragdoll = ply:GetRagdollEntity()
            if not IsValid(ragdoll) or ragdoll:GetPhysicsObjectCount() < 2 then return end
            if ragdoll.organism then return end

            local bone = ragdoll:LookupBone("ValveBiped.Bip01_Pelvis")
            if not bone or bone == -1 then return end

            local cls = ply:GetClass()
            if string_find(cls, "zombie") or string_find(cls, "headcrab") then return end

            if ply:IsOnFire() then 
                ragdoll:Ignite(math_Rand(8, 15)) 
            end
            
            if ply.DMS_IsHeadshot then 
                ragdoll.DMS_IsHeadshot = true 
            end

            local dmgpos = ply.DMS_LastDmgPos

            if not ActiveRagdollManager then return end

            ActiveRagdollManager.Run(ragdoll, dmgpos)
            ragdoll.DMS_Initialized = true
            if DMS_Health then DMS_Health.new(ragdoll, 100) end
        end)
    end)
    
    hook_Add("EntityTakeDamage", "DMS_RagdollDmg", function(target, dmginfo)
        if not IsValid(target) or not dmginfo then return end

        target.DMS_LastDmgPos = dmginfo:GetDamagePosition()
        
        if target:GetClass() ~= "prop_ragdoll" then return end
        if not DMS_Health or not ActiveRagdoll then return end

        local ar = ActiveRagdoll.Get(target)
        if not ar then return end
        local health = DMS_Health.Active[target]
        if health and health.zcnpc_shared then return end

        if dmginfo:IsDamageType(DMG_CRUSH) then
            local phys = target:GetPhysicsObject()
            if IsValid(phys) and phys:GetVelocity():LengthSqr() < MIN_PHYS_VEL_SQR then
                return
            end
        end

        if (dmginfo:IsDamageType(DMG_BURN) or dmginfo:IsDamageType(DMG_SLOWBURN)) then
            if not target:IsOnFire() then
                target:Ignite(10)
            end
        end

        if dmginfo:IsBulletDamage() or dmginfo:IsDamageType(DMG_CLUB) then
            local hitPos = dmginfo:GetDamagePosition()
            
            local closestIndex = -1
            local closestDist = math.huge
            
            for i = 0, target:GetPhysicsObjectCount() - 1 do
                local phys = target:GetPhysicsObjectNum(i)
                if IsValid(phys) then
                    local dist = phys:GetPos():DistToSqr(hitPos)
                    if dist < closestDist then
                        closestDist = dist
                        closestIndex = i
                    end
                end
            end

            if closestIndex ~= -1 then
                local boneID = target:TranslatePhysBoneToBone(closestIndex)
                local boneName = target:GetBoneName(boneID)
                
                if boneName and (string_find(boneName, "Head") or string_find(boneName, "head")) then
                    target.DMS_IsHeadshot = true
                end
            end
        end

        if not target.DMS_IsHeadshot then
            local dmg = dmginfo:GetDamage()
            if dmg and dmg > 0 then
                DMS_Health:ApplyDamage(target, dmg)
            end
        end
    end)

    hook_Add("PostCleanupMap", "DMS_Global_Emergency_Clear", function()
        if DMS and DMS.ActiveRagdolls then 
            table.Empty(DMS.ActiveRagdolls)
        end
        
        if ActiveRagdoll and ActiveRagdoll._Instances then 
            for ent, ar in pairs(ActiveRagdoll._Instances) do
                if ar and ar.Destroy then
                    ar:Destroy()
                end
            end
            table.Empty(ActiveRagdoll._Instances)
        end
        
        if DMS_Health and DMS_Health.Active then 
            table.Empty(DMS_Health.Active)
        end
        
        if AnimatedHands and AnimatedHands.Active then 
            table.Empty(AnimatedHands.Active)
        end

        if SoundManager and SoundManager.ActiveSounds then 
            table.Empty(SoundManager.ActiveSounds)
        end
    end)

    DMS.PhysicsActive = true
    print("[DMS] Physics Hooks Active.")
end

hook_Add("InitPostEntity", "DMS_FinalStartup", function()
    timer_Simple(5, function()
        RegisterPhysicsHooks()
    end)
end)

if (GAMEMODE or GM) then
    RegisterPhysicsHooks()
end
