SWEP.Base = "weapon_tpik_base"
local function RagdollOwner(ent)
	return hg.RagdollOwner(ent)
end
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/z_city/nmrih/weapons/fists/v_me_fists.mdl"
SWEP.WorldModelReal = "models/z_city/nmrih/weapons/fists/v_me_fists.mdl"
SWEP.WorldModelExchange = false
SWEP.ViewModel = ""
SWEP.UseHands = true
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.ReachDistance = 40
SWEP.HomicideSWEP = true
SWEP.NoDrop = true
SWEP.ShockMultiplier = 1
SWEP.PainMultiplier = 1
SWEP.BreakBoneMul = 0.33
SWEP.Penetration = 1
SWEP.DamageMul = 0.8
SWEP.HeadGibDamageMul = 0.35
SWEP.animtime = 0
SWEP.WorkWithFake = false
SWEP.supportTPIK = true
SWEP.ismelee = true
SWEP.SwingAng = -5

hg = hg or {}

local string_lower = string.lower

local function UseCoolHands(ply)
        if not IsValid(ply) then return false end

        local coolHands = GetConVar("hg_coolhands")
        if not coolHands or not coolHands:GetBool() then return false end

        local className = string_lower(ply.PlayerClassName or "")

        if className == "furry" then
                return ply.hgUseCoolHands == true
        end

        return className == "default"
end

function hg.GetHandsWeaponClass(ply)
        if UseCoolHands(ply) then
                return "weapon_hg_coolhands"
        end

        return "weapon_hands_sh"
end

function hg.GetHandsWeapon(ply)
        if not IsValid(ply) then return NULL end

        local class = hg.GetHandsWeaponClass(ply)
        local wep = ply:GetWeapon(class)

        if SERVER and not IsValid(wep) then
                wep = ply:Give(class)
        end

        if SERVER then
                local otherClass = class == "weapon_hg_coolhands" and "weapon_hands_sh" or "weapon_hg_coolhands"
                if ply:HasWeapon(otherClass) then
                        ply:StripWeapon(otherClass)
                end
        end

        if IsValid(wep) then
                return wep
        end

        return ply:GetWeapon("weapon_hands_sh")
end

if SERVER then
        util.AddNetworkString("hg_toggle_furry_hands")

        function hg.SetFurryHands(ply, useCoolHands)
                if not IsValid(ply) or string_lower(ply.PlayerClassName or "") ~= "furry" then return end

                ply.hgUseCoolHands = useCoolHands and true or false

                local class = hg.GetHandsWeaponClass(ply)
                local hands = ply:GetWeapon(class)
                if not IsValid(hands) then
                        hands = ply:Give(class)
                end

                local otherClass = class == "weapon_hg_coolhands" and "weapon_hands_sh" or "weapon_hg_coolhands"
                if ply:HasWeapon(otherClass) then
                        ply:StripWeapon(otherClass)
                end

                if IsValid(hands) then
                        ply:SelectWeapon(class)
                end
        end

        net.Receive("hg_toggle_furry_hands", function(_, ply)
                if not IsValid(ply) or string_lower(ply.PlayerClassName or "") ~= "furry" then return end
                hg.SetFurryHands(ply, not ply.hgUseCoolHands)
        end)

        hook.Add("WeaponEquip", "hg_coolhands_fallback", function(wep, ply)
                if not IsValid(wep) then return end

                local weaponClass = wep:GetClass()
                if weaponClass != "weapon_hands_sh" and weaponClass != "weapon_hg_coolhands" then return end
                if not IsValid(ply) then return end

                local expectedClass = hg.GetHandsWeaponClass(ply)
                if weaponClass == expectedClass then return end

                timer.Simple(0, function()
                        if not IsValid(ply) then return end

                        local wasActive = ply:GetActiveWeapon() == wep
                        local desiredClass = hg.GetHandsWeaponClass(ply)

                        if ply:HasWeapon(weaponClass) then
                                ply:StripWeapon(weaponClass)
                        end

                        local hands = ply:GetWeapon(desiredClass)

                        if not IsValid(hands) then
                                hands = ply:Give(desiredClass)
                        end

                        if wasActive and IsValid(hands) then
                                ply:SelectWeapon(desiredClass)
                        end
                end)
        end)
else
        hook.Add("PlayerBindPress", "hg_toggle_furry_hands", function(ply, bind, pressed)
                if not pressed or bind ~= "+reload" then return end
                if string_lower(ply.PlayerClassName or "") ~= "furry" then return end
                if not (input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)) then return end

                net.Start("hg_toggle_furry_hands")
                net.SendToServer()
                return true
        end)
end

local math = math -- owo
local math_random, math_Clamp, CurTime, Color = math.random, math.Clamp, CurTime, Color

-- read if cute :3

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "NextIdle")
	self:NetworkVar("Bool", 2, "Fists")
	self:NetworkVar("Float", 1, "NextDown")
	self:NetworkVar("Bool", 3, "Blocking")
	self:NetworkVar("Bool", 5, "CheckingAfflictions")
	self:NetworkVar("Bool", 4, "IsCarrying")
	self:NetworkVar("Float", 6, "LastBlocked")
	self:NetworkVar("Float", 7, "StartedBlocking")
end

function SWEP:Initialize()
	self:SetNextIdle(CurTime() + 0.44)
	self:SetNextDown(CurTime() + 5)
	self:SetHoldType(self.HoldType)
	self:SetFists(false)
	self:SetBlocking(false)
end

local ang1 = Angle(90,-15,180)
local ang2 = Angle(90,15,0)

local ang4 = Angle(0,0,180)
local ang5 = Angle(0,0,0)

local ang3 = Angle(0,0,180)
local clamp = math_Clamp

local pickupWhiteList = {
	["prop_ragdoll"] = true,
	["prop_physics"] = true,
	["prop_physics_multiplayer"] = true
}

function SWEP:CanPickup(ent)
	if ent:IsNPC() then return false end
	if ent:IsPlayer() then return false end
	if ent:IsWorld() then return false end
	local class = ent:GetClass()
	if pickupWhiteList[class] then return true end
	if CLIENT then return true end
	if IsValid(ent:GetPhysicsObject()) then return true end
	return false
end

SWEP.blockSound = nil
function SWEP:IsClient()
	return CLIENT and self:GetOwner() == LocalPlayer()
end

function SWEP:UpdateNextIdle(t)
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	self:SetNextIdle(CurTime() + (t or 0.44 * (ply.organism.stamina[1] / ply.organism.stamina.max)))
end

function SWEP:IsEntSoft(ent)
	return ent:IsNPC() or ent:IsPlayer() or hg.RagdollOwner(ent) or ent:IsRagdoll()
end

function SWEP:Holster( wep )
	if not IsFirstTimePredicted() then return true end
	local owner = self:GetOwner()

	if owner:GetNetVar("handcuffed",false) then return false end

	return true
end
