local CLASS = player.RegClass("Gordon")

function CLASS.Off(self, equipment)
    if CLIENT then return end
    ApplyAppearance(self,nil,nil,nil,true)
    if CLIENT then return end
    self:SetNetVar("HEVPower", nil)
    self:SetNetVar("HEVSuit", nil)
    self:SetNetVar("HEVOxygen", nil)
    self:SetNetVar("HEVOxygenActive", nil)
    self.HEV = nil
    self.organism.recoilmul = 1
    self.organism.CantCheckPulse = nil
    self.organism.muteChat = nil
end

CLASS.NoFreeze = true
CLASS.NoGloves = true
CLASS.CanEmitRNDSound = false

local model = "models/gfreakman/gordonf_highpoly.mdl"

local maxMorphine = 4
local maxMedicine = 600
local maxPower = 100
local maxOxygen = 100
local HEV_O2_LOW = 20
local HEV_O2_SAFE = 26

function hg.HasHEVHelmet(ply)
    if not IsValid(ply) then return false end
    local armors = ply.armors
    if armors and armors["head"] == "gordon_helmet" then return true end
    local worn = hg.GetNewArmorOnPlacement and hg.GetNewArmorOnPlacement(ply, "head")
    return IsValid(worn) and worn:GetClass() == "ent_new_armor_legacy_gordon_helmet"
end

local function hevchanged(ply)
    if not ply.HEV or not ply.HEV.Power then return end

    local hevpow = (ply.HEV.Power / maxPower)
    ply.organism.recoilmul = 1 - 0.8 * hevpow
    ply.organism.meleespeed = 1 + 1 * hevpow
    ply.organism.stamina.regen = 1 + 3 * hevpow
end

local function createhev(ply)
    ply.organism.recoilmul = 0.2
    ply.organism.meleespeed = 2
    ply.HEV = {}
    ply.HEV.Morphine = maxMorphine
    ply.HEV.Medicine = maxMedicine
    ply.HEV.Power = maxPower
    ply.HEV.Oxygen = maxOxygen
    ply.organism.HEV = ply.HEV
    ply:SetNetVar("HEVMedicine", ply.HEV.Medicine)
    ply:SetNetVar("HEVPower", ply.HEV.Power)
    ply:SetNetVar("HEVSuit", true)
    ply:SetModel(model)
    ply:SetSubMaterial()
    ply:SetBodygroup(2, 2)

    ply.organism.CantCheckPulse = true
    ply.organism.muteChat = true
    ply.armors = {}
    ply.armors["torso"] = "gordon_armor"
    ply.armors["head"] = "gordon_helmet"
    ply.armor_states = ply.armor_states or {}
    ply.armor_states.gordon_armor = {quality = 1.2, plateMaterial = "uhmwpe_ceramic", plateLevel = 6, plateSides = "all", healthMultiplier = 5}
    ply.armor_states.gordon_helmet = {quality = 1.2, protectionMultiplier = 2, healthMultiplier = 5}
    ply.armors_health = ply.armors_health or {}
    ply.armors_durability = ply.armors_durability or {}
    if ply.armors_broken then
        ply.armors_broken.gordon_armor = nil
        ply.armors_broken.gordon_helmet = nil
    end
    if ply.armors_broken_mul then
        ply.armors_broken_mul.gordon_armor = nil
        ply.armors_broken_mul.gordon_helmet = nil
    end
    if ply.armors_regions then
        ply.armors_regions.gordon_armor = nil
        ply.armors_regions.gordon_helmet = nil
    end
    ply.armors_health.gordon_armor = hg.GetArmorMaxCondition(ply, "torso", "gordon_armor")
    ply.armors_durability.gordon_helmet = hg.GetArmorMaxCondition(ply, "head", "gordon_helmet")
    ply:SyncArmor()
    hg.SyncArmorWear(ply, "gordon_armor", "torso")
    hg.SyncArmorWear(ply, "gordon_helmet", "head")
    
    local Appearance = ply.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AColthes = ""
    ply:SetNetVar("Accessories", "")
    ply.CurAppearance = Appearance

    hevchanged(ply)
end

function CLASS.On(self, data)
    if CLIENT then return end
    local equipment = data and data.equipment
    local bRestored = data and data.bRestored 
    ApplyAppearance(self,nil,nil,nil,true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AColthes = ""

    self:SetNetVar("Accessories", "")
    self.CurAppearance = Appearance
    
    self:SetModel("models/humans/gordon/group01/gordoncitizen.mdl")
    self:SetNWString("PlayerName", "Gordon")
    self:SetPlayerColor(Color(246, 139, 0):ToVector())
    self:SetSubMaterial()

    if equipment then
        if equipment == "rebel" then
            local wep = self:Give(math.random(2) == 1 and "weapon_osipr" or "weapon_akm")
            self:GiveAmmo(wep:GetMaxClip1() * 3, wep:GetPrimaryAmmoType(), true)

            local wep = self:Give(math.random(2) == 1 and "weapon_hk_usp" or "weapon_revolver357")
            self:GiveAmmo(wep:GetMaxClip1() * 3, wep:GetPrimaryAmmoType(), true)

            self:Give("weapon_hg_crowbar")

            self:Give("weapon_hg_gravitygun")

            local wep = self:Give("weapon_hg_hl2nade_tpik")
            wep.count = 3
            
            self:Give("weapon_hg_slam")
            self:Give("weapon_walkie_talkie")
        elseif equipment == "refugee" then
            if game.GetMap() ~= "d1_trainstation_06" then
                if game.GetMap() ~= "d1_canals_01" then
                    local wep = self:Give("weapon_hk_usp")
                    self:GiveAmmo(wep:GetMaxClip1() * 3, wep:GetPrimaryAmmoType(), true)
                end

                self:Give("weapon_hg_crowbar")
            end
        end
    end

    if equipment != "citizen" and not bRestored then
        timer.Simple(1,function()
            for i,ent in pairs(ents.FindByClass("item_suit")) do
                ent:Remove()
            end
        end)

        createhev(self)
    elseif bRestored then
        if self.organism then
            self.organism.recoilmul = 0.2
            self.organism.meleespeed = 2
        end
        self.HEV = self.HEV or {}
        self.HEV.Morphine = self.HEV.Morphine or maxMorphine
        self.HEV.Medicine = self.HEV.Medicine or maxMedicine
        self.HEV.Power = self.HEV.Power or maxPower
        self.HEV.Oxygen = self.HEV.Oxygen or maxOxygen
        if self.organism then
            self.organism.HEV = self.HEV
            self.organism.CantCheckPulse = true
        end
        self:SetNetVar("HEVMedicine", self.HEV.Medicine)
        self:SetNetVar("HEVPower", self.HEV.Power)
        self:SetNetVar("HEVSuit", true)
        self:SetModel(model)
        self:SetSubMaterial()
        self:SetBodygroup(2, 2)
        
        self.armors = self.armors or {}
        if not self.armors["torso"] then
            self.armors["torso"] = "gordon_armor"
        end
        if not self.armors["head"] then
            self.armors["head"] = "gordon_helmet"
        end
        self.armor_states = self.armor_states or {}
        self.armor_states.gordon_armor = self.armor_states.gordon_armor or {quality = 1.2, plateMaterial = "uhmwpe_ceramic", plateLevel = 6, plateSides = "all", healthMultiplier = 5}
        self.armor_states.gordon_helmet = self.armor_states.gordon_helmet or {quality = 1.2, protectionMultiplier = 2, healthMultiplier = 5}
        self:SyncArmor()
        hevchanged(self)

        
    end
end

if SERVER then
    local function replaceChargers()
        timer.Simple(1,function()
            for i, ent in ents.Iterator() do
                if ent:GetClass() == "item_suitcharger" then
                    local entnew = ents.Create("prop_physics")
                    entnew:SetModel(ent:GetModel())
                    entnew:SetPos(ent:GetPos())
                    entnew:SetAngles(ent:GetAngles())
                    entnew.armorcharger = true
                    entnew.power = 100
                    entnew:Spawn()
        
                    local phys = entnew:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:EnableMotion(false)
                    end
        
                    timer.Simple(0.1,function()
                        ent:Remove()
                    end)
                end
        
                if ent:GetClass() == "item_healthcharger" then
                    local entnew = ents.Create("prop_physics")
                    entnew:SetModel(ent:GetModel())
                    entnew:SetPos(ent:GetPos())
                    entnew:SetAngles(ent:GetAngles())
                    entnew.healthcharger = true
                    entnew.power = 100
                    entnew:Spawn()
                    
                    local phys = entnew:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:EnableMotion(false)
                    end
        
                    timer.Simple(0.1,function()
                        ent:Remove()
                    end)
                end
            end
        end)
    end
    hook.Add("InitPostEntity", "gordon_chargers_init", replaceChargers)
    hook.Add("PostCleanupMap", "huyhuygordonspasjizn", replaceChargers)
end

hook.Add("Player Think","health_armor_gordonthings",function(ply)
    if not (ply.PlayerClassName == "Gordon" and ply:GetNetVar("HEVSuit")) then return end
    local ent = hg.eyeTrace(ply).Entity
    if not (ent.armorcharger or ent.healthcharger) then return end
    if (ent.ThinkCharge or 0) > CurTime() then return end
    ent:SetCycle(1 - ent.power / 100)

    if not ply:KeyDown(IN_USE) then
        ply.keypresseduse = nil
        if ent.snd then ent:StopLoopingSound(ent.snd) ent.snd = nil end
        return
    end

    ent.ThinkCharge = CurTime() + 0.25
    
    if ent.power > 0 then
        timer.Create("huasd"..ent:EntIndex(),1,1,function()
            if ent.snd then ent:StopLoopingSound(ent.snd) ent.snd = nil end
        end)

        if ent.armorcharger then
            local noneedarmor = ply.HEV.Power == maxPower
            for placement, armor in pairs(ply.armors or {}) do
                if armor == "gordon_armor" or armor == "gordon_helmet" then
                    local maximum = hg.GetArmorMaxCondition(ply, placement, armor)
                    local current = placement == "head" and ply.armors_durability and ply.armors_durability[armor] or ply.armors_health and ply.armors_health[armor]
                    if (current or maximum) < maximum or ply.armors_broken and ply.armors_broken[armor] then noneedarmor = false end
                    for _, regionHealth in pairs(ply.armors_regions and ply.armors_regions[armor] or {}) do
                        if regionHealth < (placement == "torso" and 100 or 70) then noneedarmor = false end
                    end
                end
            end
            if noneedarmor then
                if not ply.keypresseduse then
                    ent:EmitSound(ent.armorcharger and "items/suitchargeno1.wav" or "items/medshotno1.wav")
                end
                ply.keypresseduse = true
                if ent.snd then ent:StopLoopingSound(ent.snd) ent.snd = nil end
                return
            end

            if not ply.keypresseduse then
                ent:EmitSound("items/suitchargeok1.wav")
                
                ent.snd = ent:StartLoopingSound("items/suitcharge1.wav")
            end

            ply.HEV.Power = math.min(ply.HEV.Power + 1, maxPower)
            ply:SetNetVar("HEVPower", ply.HEV.Power)
            hevchanged(ply)
            for placement, armor in pairs(ply.armors or {}) do
                if armor == "gordon_armor" or armor == "gordon_helmet" then
                    local maximum = hg.GetArmorMaxCondition(ply, placement, armor)
                    local condition = placement == "head" and ply.armors_durability or ply.armors_health
                    if condition then condition[armor] = math.min((condition[armor] or maximum) + maximum / 25, maximum) end
                    if ply.armors_broken then ply.armors_broken[armor] = nil end
                    if ply.armors_broken_mul then ply.armors_broken_mul[armor] = nil end
                    for region, regionHealth in pairs(ply.armors_regions and ply.armors_regions[armor] or {}) do
                        local regionMaximum = placement == "torso" and 100 or 70
                        ply.armors_regions[armor][region] = math.min(regionHealth + regionMaximum / 25, regionMaximum)
                    end
                    hg.SyncArmorWear(ply, armor, placement)
                end
            end
            ent.power = ent.power - 1
        else
            local noneedhealth = (ply:Health() == 100) and (ply.HEV.Medicine == maxMedicine) and (ply.HEV.Morphine == maxMorphine)
            
            if noneedhealth then
                if not ply.keypresseduse then
                    ent:EmitSound(ent.armorcharger and "items/suitchargeno1.wav" or "items/medshotno1.wav")
                end
                ply.keypresseduse = true
                if ent.snd then ent:StopLoopingSound(ent.snd) ent.snd = nil end
                return
            end

            if not ply.keypresseduse then
                ent:EmitSound("items/medshot4.wav")
                
                ent.snd = ent:StartLoopingSound("items/medcharge4.wav")
            end

            ply.HEV.Medicine = math.min(ply.HEV.Medicine + 5, maxMedicine)
            ply.HEV.Morphine = math.min(ply.HEV.Morphine + 0.01, maxMorphine)
            ply:SetHealth(math.min(ply:Health() + 1,100))
            ply:SetNetVar("HEVMedicine", ply.HEV.Medicine)
            ent.power = ent.power - 1
        end
    else
        if not ply.keypresseduse then
            ent:EmitSound(ent.armorcharger and "items/suitchargeno1.wav" or "items/medshotno1.wav")
        end
        if ent.snd then ent:StopLoopingSound(ent.snd) ent.snd = nil end
    end
    
    ply.keypresseduse = true
end)

hook.Add("WeaponEquip","pickuplom",function(wep,ply)
    if ply.PlayerClassName == "Gordon" and wep:GetClass() == "weapon_hg_crowbar" then
        wep:Remove()
		local bar = ply:Give("weapon_hg_crowbar_gordon")
		ply:SelectWeapon(bar)
	elseif ply.PlayerClassName ~= "Gordon" and wep:GetClass() == "weapon_hg_crowbar_gordon" then 
		wep:Remove()
		local bar = ply:Give("weapon_hg_crowbar")
		ply:SelectWeapon(bar)
	end
end)

hook.Add("HG_CanThoughts", "GordonCantDumat", function(ply)
	if ply.PlayerClassName == "Gordon" then
		return false
	end
end)

hook.Add("PlayerCanPickupItem","hevsuit",function(ply, ent)
    local entclass = ent:GetClass()
    if entclass == "item_suit" then
        if ply.PlayerClassName == "Gordon" and not ply:GetNetVar("HEVSuit") then
            createhev(ply)
        else
            return false
        end
    end

    if entclass == "item_healthvial" then
        if ply.PlayerClassName == "Gordon" and ply:GetNetVar("HEVSuit") then
            local noneedhealth = (ply:Health() == 100) and (ply.HEV.Medicine == maxMedicine) and (ply.HEV.Morphine == maxMorphine)
            if noneedhealth then return false end
            ply.HEV.Medicine = math.min(ply.HEV.Medicine + 100, maxMedicine)
            if ply:Health() == 100 then ply:SetHealth(99) end
        else
            return false
        end
    end

    if entclass == "item_healthkit" then
        if ply.PlayerClassName == "Gordon" and ply:GetNetVar("HEVSuit") then
            local noneedhealth = (ply:Health() == 100) and (ply.HEV.Medicine == maxMedicine) and (ply.HEV.Morphine == maxMorphine)
            if noneedhealth then return false end
            ply.HEV.Medicine = math.min(ply.HEV.Medicine + 250, maxMedicine)
            ply.HEV.Morphine = math.min(ply.HEV.Morphine + 1, maxMorphine)
            if ply:Health() == 100 then ply:SetHealth(99) end
        else
            return false
        end
    end

    if entclass == "item_battery" then
        if ply.PlayerClassName == "Gordon" and ply:GetNetVar("HEVSuit") then
            local noneedarmor = ply.HEV.Power == maxPower
            if noneedarmor then return false end
            ply.HEV.Power = math.min(ply.HEV.Power + 25, maxPower)
            ply:SetNetVar("HEVPower", ply.HEV.Power)
            ply:SetArmor(0)
            hevchanged(ply)
        else
            return false
        end
    end
end)

hook.Add("HomigradDamage","takesomearmor",function(ply,dmginfo,hitgroup,ent,harm)
    if not (ply.PlayerClassName == "Gordon" and ply:GetNetVar("HEVSuit")) then return end

    if dmginfo:IsDamageType(DMG_FALL + DMG_DROWN + DMG_POISON + DMG_RADIATION) then return end

    local sub = math.Round(dmginfo:GetDamage() / 4,0)
    ply.HEV.Power = math.Clamp(ply.HEV.Power - sub, 0, maxPower)
    ply:SetNetVar("HEVPower", ply.HEV.Power)

    hevchanged(ply)
end)

if CLIENT then
    local BGColor = Color(0,0,0,255)

    local function drawBGPanel(PosX,PosY,alpha)
        local sizeW, sizeH = ScrW()*0.12, ScrH()*0.075
        local posW, posH = ScrW()*PosX, ScrH()*PosY - sizeH

        return {posW, posH}, {sizeW, sizeH}
    end
    local armorlerp = 0

    surface.CreateFont("HEVFontDefault",{
        font = "Courier Prime",
        extended = true,
        size = ScreenScale(24),
        weight = 500,
        blursize = 0,
        scanlines = 2,
        antialias = true
    })

    surface.CreateFont("HEVFontSmall",{
        font = "Courier Prime",
        extended = true,
        size = ScreenScale(7.5),
        weight = 1500,
        blursize = 0,
        scanlines = 2,
        antialias = true
    })

    surface.CreateFont("HEVFontSmallBG",{
        font = "Courier Prime",
        extended = true,
        size = ScreenScale(7.5),
        weight = 500,
        blursize = 1,
        scanlines = 2,
        antialias = true
    })

    surface.CreateFont("HEVFontDefaultBG",{
        font = "Courier Prime",
        extended = true,
        size = ScreenScale(24.5),
        weight = 1500,
        blursize = 1,
        scanlines = 2,
        antialias = true
    })

    local color_hp1 = Color(255,155,0)
    local color_crit = Color(255,0,0)
    local color_ar = Color(255,155,0)
    local color_glow = Color(255,155,0,0)
    local color_glow_ar = Color(255,155,0,0)
    local color_glow_ammo = Color(255,155,0,0)
    local color_bld = Color(255,155,0)
    local color_sight = Color(255,155,0,220) 
    local armorTxt = 0
    local hpTxt = 0
    local BloodTxt = 0
    local bloodlerp = 0
    local ammoTxt = 0
    local ammolerp = 0 
    local bloodOld = 5000
    local oldHpTxt = 0
    local oldArTxt = 0
    local oldAmmoTxt = 0
    local o2lerp = 0
    local posSight = Vector(ScrW(),ScrH(),0)
    function CLASS.HUDPaint(self)
        if not self:Alive() then return end
        if not hg.HasHEVHelmet(self) then return end
        local hasSuit = self:GetNetVar("HEVSuit")

        local FRT = FrameTime() * 5
        if hasSuit then
        local pos, size = drawBGPanel(0.065,0.15)
        surface.SetFont("HEVFontDefault")
        local _,txtSizeY = surface.GetTextSize(math.Round(lply:GetNetVar("HEVMedicine",600)/6,0))
        hpTxt = math.min(hpTxt + 1, math.Round(lply:GetNetVar("HEVMedicine",600)/6,0))
        local color_bg = BGColor
        color_bg.a = 225
        draw.DrawText("000","HEVFontDefaultBG",pos[1]+size[1]*0.08 + 1,pos[2]+(size[2]/2) - txtSizeY/2 + 1,color_bg,TEXT_ALIGN_RIGHT)

        
        color_glow.a = math.Round( Lerp( FRT, color_glow.a, oldHpTxt ~= hpTxt and 255 or 0 ) ) 

        local color_hp = color_hp1:Lerp(color_crit,(1-hpTxt/25)*math.abs(math.cos(CurTime()*2)))
        
        draw.GlowingText( hpTxt, "HEVFontDefault", pos[1]+size[1]*0.08, pos[2]+(size[2]/2) - txtSizeY/2, color_hp, color_glow, nil, TEXT_ALIGN_RIGHT)
        oldHpTxt = hpTxt

        draw.DrawText("Medicine","HEVFontSmall",pos[1]+size[1]*0.085+1,pos[2]+(size[2]/1.8)+1,color_bg,TEXT_ALIGN_LEFT)
        draw.DrawText("Medicine","HEVFontSmall",pos[1]+size[1]*0.085,pos[2]+(size[2]/1.8),color_hp,TEXT_ALIGN_LEFT)
        end

        local armor = hasSuit and (self:GetNetVar("HEVPower") or 0) or math.Round((1 - math.Clamp(self:GetNWFloat("ArmorWeargordon_helmet", 0), 0, 1)) * 100)
        armorlerp = Lerp(FRT,armorlerp,armor > 1 and 1 or 0)
        local pos, size = drawBGPanel(0.17,0.15,125 * (armor > 1 and 1 or 0))
        surface.SetFont("HEVFontDefault")
        local _,txtSizeY = surface.GetTextSize(armor)
        local color_bg = BGColor
        color_bg.a = 225*armorlerp
        color_ar.a = 255*armorlerp
        armorTxt = math.min(armorTxt + 1, armor)
        draw.DrawText("000","HEVFontDefaultBG",pos[1]+size[1]*0.08 + 1,pos[2]+(size[2]/2) - txtSizeY/2 + 1,color_bg,TEXT_ALIGN_RIGHT)

        draw.DrawText(armorTxt,"HEVFontDefault",pos[1]+size[1]*0.08,pos[2]+(size[2]/2) - txtSizeY/2,color_ar,TEXT_ALIGN_RIGHT)
        color_glow_ar.a = math.Round( Lerp( FRT, color_glow_ar.a, oldArTxt ~= armorTxt and 255 or 0 ) ) 
        draw.GlowingText( armorTxt, "HEVFontDefault", pos[1]+size[1]*0.08, pos[2]+(size[2]/2) - txtSizeY/2, color_ar, color_glow_ar, nil, TEXT_ALIGN_RIGHT)
        oldArTxt = armorTxt
        draw.DrawText("Armor","HEVFontSmall",pos[1]+size[1]*0.085+1,pos[2]+(size[2]/1.8)+1,color_bg,TEXT_ALIGN_LEFT)
        draw.DrawText("Armor","HEVFontSmall",pos[1]+size[1]*0.085,pos[2]+(size[2]/1.8),color_ar,TEXT_ALIGN_LEFT)
        
        local wep = self:GetActiveWeapon()
        if IsValid(wep) then
            if not IsValid(wep) or not wep.GetTrace then return end
            local tr = wep:GetTrace(true)
            posSight = LerpVector(FRT*5, posSight, Vector(tr.HitPos:ToScreen().x,tr.HitPos:ToScreen().y,0) )
            color_sight.a = Lerp(FRT*5,color_sight.a, lply:KeyDown(IN_ATTACK2) and 0 or 255)
			
            draw.RoundedBox(0, posSight.x - 1, posSight.y + 2, 2, 6, color_sight)
            draw.RoundedBox(0, posSight.x - 1, posSight.y - 8, 2, 6, color_sight)
            draw.RoundedBox(0, posSight.x + 2, posSight.y - 1, 6, 2, color_sight)
            draw.RoundedBox(0, posSight.x - 8, posSight.y - 1, 6, 2, color_sight)
        end
        
        if IsValid(wep) and wep.Clip1 then
            local FRT = FrameTime() * 5
            ammolerp = Lerp(FRT,ammolerp,wep:Clip1() < 0 and 0 or 1)
            local pos, size = drawBGPanel(0.93,0.15)
            surface.SetFont("HEVFontDefault")
            local _,txtSizeY = surface.GetTextSize(self:Armor())
            local color_bg = BGColor
            color_bg.a = 225*ammolerp
            color_ar.a = 255*ammolerp
            ammoTxt = math.min(ammoTxt + 1, wep:Clip1())
            draw.DrawText( "000", "HEVFontDefaultBG",pos[1]+size[1]*0.08 + 1,pos[2]+(size[2]/2) - txtSizeY/2 + 1,color_bg,TEXT_ALIGN_RIGHT)
            

            color_glow_ammo.a = math.Round( Lerp( FRT, color_glow_ammo.a, oldAmmoTxt ~= ammoTxt and 255 or 0 ) ) 
            draw.GlowingText( ammoTxt, "HEVFontDefault", pos[1]+size[1]*0.08, pos[2]+(size[2]/2) - txtSizeY/2, color_ar, color_glow_ammo,nil, TEXT_ALIGN_RIGHT)
            oldAmmoTxt = ammoTxt

            draw.DrawText( "Ammo", "HEVFontSmall",pos[1]+size[1]*0.085+1,pos[2]+(size[2]/1.8)+1,color_bg,TEXT_ALIGN_LEFT)
            draw.DrawText( "Ammo", "HEVFontSmall",pos[1]+size[1]*0.085,pos[2]+(size[2]/1.8),color_ar,TEXT_ALIGN_LEFT)
        end
        
        if not hasSuit then return end
        local pos, size = drawBGPanel(0.035,0.25)
        surface.SetFont("HEVFontSmall")
        if not self.organism or not self.organism.blood then return end
        bloodlerp = Lerp(FRT,bloodlerp,self.organism.blood > 4900 and 0 or 1)
        bloodOld = self.organism.blood
        local _,txtSizeY = surface.GetTextSize(self.organism.blood)
        
        BloodTxt = math.Round(math.min(BloodTxt + 25, self.organism.blood))

        local color_bg = BGColor
        color_bg.a = 125*bloodlerp
        color_bld.a = 255*bloodlerp
        
        draw.DrawText(BloodTxt,"HEVFontSmall",pos[1]+size[1]*-0.09,pos[2]+(size[2]/2),color_bg,TEXT_ALIGN_LEFT)
        draw.DrawText(BloodTxt,"HEVFontSmall",pos[1]+size[1]*-0.09,pos[2]+(size[2]/2),color_bld,TEXT_ALIGN_LEFT)
        draw.DrawText("Blood/Ml","HEVFontSmall",pos[1]+size[1]*0.085+1,pos[2]+(size[2]/2)+1,color_bg,TEXT_ALIGN_LEFT)
        draw.DrawText("Blood/Ml","HEVFontSmall",pos[1]+size[1]*0.085,pos[2]+(size[2]/2),color_bld,TEXT_ALIGN_LEFT)

        local org = self.organism
        local o2 = org and istable(org.o2) and tonumber(org.o2[1])
        local showO2 = self:GetNetVar("HEVOxygenActive") or (o2 and o2 < HEV_O2_LOW)
        o2lerp = Lerp(FRT, o2lerp, showO2 and 1 or 0)
        if o2lerp > 0.01 then
            local tank = math.Clamp((self:GetNetVar("HEVOxygen", maxOxygen) or maxOxygen) / maxOxygen, 0, 1)
            local barX, barY = pos[1], pos[2] + size[2] * 1.15
            local barW, barH = size[1] * 0.6, ScrH() * 0.008
            local color_o2 = color_hp1:Lerp(color_crit, (1 - tank) * math.abs(math.cos(CurTime() * 3)))

            color_bg.a = 200 * o2lerp
            surface.SetDrawColor(color_bg)
            surface.DrawRect(barX, barY, barW, barH)
            surface.SetDrawColor(color_o2.r, color_o2.g, color_o2.b, 255 * o2lerp)
            surface.DrawRect(barX + 1, barY + 1, (barW - 2) * tank, barH - 2)
            surface.DrawOutlinedRect(barX, barY, barW, barH)
            draw.DrawText("O2 " .. math.Round(tank * 100) .. "%", "HEVFontSmall", barX + barW + size[1] * 0.04, barY + barH / 2 - ScreenScale(4), Color(color_o2.r, color_o2.g, color_o2.b, 255 * o2lerp), TEXT_ALIGN_LEFT)
        end
    end

    local hevMat = Material("sprites/mat_jack_helmoverlay_r")
    hook.Add("RenderScreenspaceEffects","HEV_helmet",function()
        if not hg.HasHEVHelmet(lply) then return end
        if lply:Alive() then
			surface.SetDrawColor(255,132,0,200)
			surface.SetMaterial(hevMat)
			surface.DrawTexturedRectRotated((ScrW()/2) - 5, (ScrH()/2) - 5, ScrW()  + 10, ScrH() + 450,180)
        end
        render.PushFilterMag(TEXFILTER.ANISOTROPIC)
        render.PushFilterMin(TEXFILTER.ANISOTROPIC)
            CLASS.HUDPaint(lply)
        render.PopFilterMag()
        render.PopFilterMin()
    end)

end

if CLIENT then
    local queen = {}
    net.Receive("HEV_DAMAGE",function()
        if not hg.HasHEVHelmet(lply) then return end
        queen[#queen + 1] = net.ReadString()
    end)
    local inPlaying = 0
    hook.Add("Think","HEV_Notify",function()
        if !lply:Alive() and #queen > 0 then queen = {} return end
        if not hg.HasHEVHelmet(lply) then return end
        if inPlaying < CurTime() - 0.1 and queen[#queen] and !lply.organism.otrub then
            inPlaying = CurTime() + SoundDuration(queen[#queen])
            surface.PlaySound(queen[#queen])
            queen[#queen] = nil
        end
    end)

elseif SERVER then
    util.AddNetworkString("HEV_DAMAGE")

    local phrases = {
        "Gordon Freeman has died. Now what?",
        "He's dead. Who will lead the way now?",
        "Gordon Freeman has failed his mission.",
        "What an unfortunate end to such a good employee.",
    }

    local hev_color = Color(255,125,0)
    local dead_color = Color(255,0,0)

    local function hevAlert(ply, text, id, snd)
        ply:Notify(text, 10, id, 0.5, function(ply)
            net.Start("HEV_DAMAGE")
                net.WriteString(snd)
            net.Send(ply)
        end, hev_color)
    end

    local function hevControlBleeding(ply, org)
        local hev = ply.HEV
        if not hev or hev.Medicine <= 0 then return end

        local swep = weapons.GetStored("weapon_bandage_sh")
        if swep and swep.Tourniquet then
            local proxy = {GetOwner = function() return ply end}
            local seen = {}
            local applied = false

            local function try(bone)
                local limb = hg.GetTourniquetLimb(bone)
                if not limb or seen[limb] then return end
                seen[limb] = true
                if hev.Medicine < 15 or hg.HasTourniquetOnLimb(ply, limb) then return end
                if swep.Tourniquet(proxy, ply, bone) then
                    hev.Medicine = hev.Medicine - 15
                    applied = true
                end
            end

            for _, wound in ipairs(org.arterialwounds or {}) do
                if (wound[1] or 0) > 0 then try(wound[7] == "arteria" and "arteria" or wound[4]) end
            end
            for _, wound in ipairs(org.wounds or {}) do
                if (wound[1] or 0) > 0 then try(wound[4]) end
            end

            if applied then
                hevAlert(ply, "HEV suit has detected severe hemorrhage. Applying tourniquet.", "tourniquet_hev", "hl1/fvox/torniquette_applied.wav")
            end
        end

        local internal = (org.internalBleed or 0) > 0.05
        local small = false
        for _, wound in ipairs(org.wounds or {}) do
            if (wound[1] or 0) > 0.05 and (hg.GetTourniquetBleedMultiplier(ply, wound[4], false) or 1) > 0 then
                small = true
                break
            end
        end

        local txaActive = (org.tranexamic_acid or 0) > 1 or (org.tranexamic_acid_pending or 0) > 0
        if (internal or small) and not txaActive and hev.Medicine >= 60 then
            hg.organism.AdministerTranexamic(org, 10)
            hev.Medicine = hev.Medicine - 60
            hevAlert(ply, "HEV suit has detected bleeding. Injecting tranexamic acid.", "txa_hev", "hl1/fvox/blood_plasma.wav")
        end
    end

    local HEV_O2_RATE = 6
    local HEV_O2_REFILL = 0.5

    local function hevSupplyOxygen(ply, org, timeValue)
        local hev = ply.HEV
        local o2 = org.o2
        if not istable(o2) or not isnumber(o2[1]) then return end

        hev.Oxygen = hev.Oxygen or maxOxygen
        local range = tonumber(o2.range) or 30
        local low = o2[1] < HEV_O2_LOW or (org.hevO2Active and o2[1] < HEV_O2_SAFE)
        local active = low and hev.Oxygen > 0 and hg.HasHEVHelmet(ply)

        if active then
            local give = math.max(math.min(HEV_O2_RATE * timeValue, range - o2[1], hev.Oxygen), 0)
            o2[1] = o2[1] + give
            hev.Oxygen = hev.Oxygen - give

            if not org.hevO2Active then
                ply:Notify("HEV suit has detected hypoxia. Supplying emergency oxygen.", 30, "o2_hev", 0.5, function(ply)
                    net.Start("HEV_DAMAGE")
                        net.WriteString("hl1/fvox/automedic_on.wav")
                    net.Send(ply)
                end, hev_color)
            end
        elseif not low and hev.Oxygen < maxOxygen and ply:WaterLevel() < 3 then
            hev.Oxygen = math.min(hev.Oxygen + HEV_O2_REFILL * timeValue, maxOxygen)
        end

        org.hevO2Active = active or nil

        local rounded = math.Round(hev.Oxygen)
        if ply:GetNetVar("HEVOxygen") ~= rounded then ply:SetNetVar("HEVOxygen", rounded) end
        if (ply:GetNetVar("HEVOxygenActive") or false) ~= active then ply:SetNetVar("HEVOxygenActive", active) end
    end

    local HEV_AED_CHARGE = 7
    local HEV_AED_COOLDOWN = 45
    local HEV_AED_COST = 60
    local HEV_THIAMINE_COST = 30
    local HEV_SPLINT_COST = 10
    local HEV_STERILIZE_COST = 10
    local HEV_STERILIZE_COOLDOWN = 20
    local HEV_SURGEON_COST = 100
    local HEV_SURGEON_BATTERY = 400
    local HEV_SURGEON_COOLDOWN = 90
    local hevAEDSounds = {
        shockadvised = "defibrilator/rem_aed_shockadvised.mp3",
        charging = "defibrilator/defib_charge.ogg",
        standclear = "defibrilator/rem_aed_standclear.mp3",
        shocksound = "defibrilator/rem_aed_shocksound.mp3",
        shockdelivered = "defibrilator/rem_aed_shockdelivered.mp3",
        shocksuccess = "defibrilator/defib_success.ogg",
        startcpr = "defibrilator/rem_aed_startcpr.mp3",
    }

    local function hevNotify(ply, text, id)
        ply:Notify(text, 10, id, 0, function() end, hev_color)
    end

    local function hevNeedsAED(org)
        if not org.alive then return false end
        if org.heartstop or org.fibrillation or org.ecgState == "asystole" or org.terminalRhythm == "asystole" then return true end

        local state = hg.SimpleHealth.GetState(org)
        return state ~= nil and (state.flatline or state.crit >= hg.SimpleHealth.CRIT_SOFT)
    end

    local function hevPlayAED(ply, snd, level)
        local ent = hg.GetCurrentCharacter(ply)
        if IsValid(ent) then ent:EmitSound(snd, level or 75, 100) end
    end

    local function hevAutoAED(ply, org)
        if org.hevAEDBusy or (org.hevAEDNext or 0) > CurTime() then return end
        if ply.HEV.Medicine < HEV_AED_COST or not hevNeedsAED(org) then return end

        org.hevAEDBusy = true
        hevNotify(ply, "HEV suit has detected a life-threatening cardiac event. Shock advised.", "aed_hev")
        hevPlayAED(ply, hevAEDSounds.shockadvised)
        hevPlayAED(ply, hevAEDSounds.charging)

        timer.Simple(math.max(SoundDuration(hevAEDSounds.shockadvised), 0.1), function()
            if org.hevAEDBusy then hevPlayAED(ply, hevAEDSounds.standclear) end
        end)

        timer.Simple(HEV_AED_CHARGE, function()
            org.hevAEDBusy = nil
            if not IsValid(ply) or not ply:Alive() or not ply.HEV or not org.alive then return end
            if ply.HEV.Medicine < HEV_AED_COST or not hevNeedsAED(org) then return end

            org.hevAEDNext = CurTime() + HEV_AED_COOLDOWN
            ply.HEV.Medicine = ply.HEV.Medicine - HEV_AED_COST

            hevPlayAED(ply, hevAEDSounds.shocksound, 85)
            hevPlayAED(ply, hevAEDSounds.shockdelivered)

            if hg.SimpleHealth.OnAEDShock then hg.SimpleHealth.OnAEDShock(org) end

            org.fibrillation = false
            org.ventricularTachycardia = nil
            org.arrhythmia = math.max((org.arrhythmia or 0) - 0.75, 0)
            org.heartStrain = math.max((org.heartStrain or 0) - 0.35, 0)
            org.myocardialOxygen = math.max(org.myocardialOxygen or 0, 0.5)
            org.defibSupportUntil = CurTime() + 4
            org.defibDeathGrace = CurTime() + 45
            org.aedResuscitationUntil = CurTime() + 15
            org.epinephrineResuscitationUntil = CurTime() + 15
            org.adrenalineAdd = 4

            if hg.organism.RestoreSupportedOxygen then
                hg.organism.RestoreSupportedOxygen(org, 0.2, {
                    artificialSupport = true,
                    oxygen = 12, oxygenTarget = 20, bodyoxygen = 0.5, bodyoxygenTarget = 0.7,
                    brainoxygen = 0.4, brainoxygenTarget = 0.65, perfusion = 0.4,
                    perfusionTarget = 0.65, myocardialOxygen = 0.5, myocardialOxygenTarget = 0.7,
                    hypoxiaTime = 7, severeHypoxiaTime = 2, systemicIschemiaTime = 8
                })
            end
            if hg.organism.ApplyAEDResuscitation then hg.organism.ApplyAEDResuscitation(org) end
            if hg.organism.TryRestartHeartWithResuscitation then hg.organism.TryRestartHeartWithResuscitation(org) end

            if org.heartstop then
                org.heartstop = false
                org.pulse = math.max(org.pulse or 0, 70)
                org.heartbeat = math.max(org.heartbeat or 0, 70)
            end

            hevPlayAED(ply, hevAEDSounds.shocksuccess)
            hevAlert(ply, "Defibrillation delivered. Epinephrine injected. Auto-pulse enabled.", "aed_hev_done", "hl1/fvox/adrenaline_shot.wav")

            timer.Simple(3, function()
                if IsValid(ply) and ply:Alive() then hevPlayAED(ply, hevAEDSounds.startcpr) end
            end)
        end)
    end

    local function hevSevereDamage(org)
        if not org.alive then return false end
        local lungs = math.max(istable(org.lungsL) and (org.lungsL[1] or 0) or 0, istable(org.lungsR) and (org.lungsR[1] or 0) or 0)
        if (org.heart or 0) > 0.3 or (org.brain or 0) > 0.25 or (org.trachea or 0) > 0.4 or lungs > 0.5 then return true end
        if (org.internalBleed or 0) > 1 or (org.blood or 5000) < 3200 or (org.liver or 0) > 0.6 then return true end
        for _, wound in ipairs(org.arterialwounds or {}) do
            if (wound[1] or 0) > 0.05 then return true end
        end
        return hevNeedsAED(org)
    end

    local function hevAutoThiamine(ply, org)
        if (org.thiamine or 0) > 0.3 or ply.HEV.Medicine < HEV_THIAMINE_COST then return end

        ply.HEV.Medicine = ply.HEV.Medicine - HEV_THIAMINE_COST
        org.thiamine = 1
        hevAlert(ply, "HEV suit has detected severe organ damage. Injecting thiamine.", "thiamine_hev", "hl1/fvox/antitoxin_shot.wav")
    end

    local function hevOpenWounds(org)
        for _, list in ipairs({org.wounds, org.arterialwounds}) do
            for _, wound in ipairs(list or {}) do
                if (wound[1] or 0) > 0 then return true end
            end
        end
        return false
    end

    local function hevAutoSterilize(ply, org)
        if (org.hevSterilizeNext or 0) > CurTime() or ply.HEV.Medicine < HEV_STERILIZE_COST then return end

        local state = org.simpleMode and hg.SimpleHealth.GetState(org)
        local contaminated = state and (state.contamination or 0) > 1
        local infected = (org.infection or 0) > 0.05 or (org.medical_infection or 0) > 0.05
        local exposed = hevOpenWounds(org) and (org.openWoundTime or 0) > 5
        if not (infected or exposed or contaminated) then return end

        org.hevSterilizeNext = CurTime() + HEV_STERILIZE_COOLDOWN
        ply.HEV.Medicine = ply.HEV.Medicine - HEV_STERILIZE_COST

        org.infection = 0
        org.medical_infection = 0
        org.openWoundTime = 0
        org.openWoundRoll = 0
        org.infectionNotified = nil
        org.sepsisSource = math.max((org.sepsisSource or 0) - 0.25, 0)
        if contaminated then state.contamination = 0 end

        hevAlert(ply, "HEV suit has detected wound contamination. Sterilizing wounds.", "sterilize_hev", "hl1/fvox/wound_sterilized.wav")
    end

    local function hevAutoSurgeon(ply, org)
        if (org.hevSurgeonNext or 0) > CurTime() or ply.HEV.Medicine < HEV_SURGEON_COST then return end
        if IsValid(ply.AutosurgeonModelEnt) or ply.AutosurgeonInProgress then return end

        local rag = ply.GetRagdollEntity and ply:GetRagdollEntity()
        local target = IsValid(rag) and rag or ply
        local wep = ents.Create("weapon_autosurgeon_sh")
        if not IsValid(wep) then return end

        wep:Spawn()
        wep.BuiltIn = true
        wep:SetClip1(HEV_SURGEON_BATTERY)
        wep:AttachUnit(ply, target, ply)
        wep:Remove()

        if not ply.AutosurgeonInProgress then return end

        org.hevSurgeonNext = CurTime() + HEV_SURGEON_COOLDOWN
        ply.HEV.Medicine = ply.HEV.Medicine - HEV_SURGEON_COST
        hevAlert(ply, "HEV suit has detected life-threatening damage. Deploying built-in autosurgeon.", "surgeon_hev", "hl1/fvox/administering_medical.wav")
    end

    hook.Add("Org Think","gordon_healing",function(ply, org, timeValue)

        if org.HEV and not org.alive and not org.emitflatline then
            org.emitflatline = true
            hg.GetCurrentCharacter(ply):EmitSound("hl1/fvox/flatline.wav")

            if CurrentRound and CurrentRound().name == "coop" then
                if zChatPrint then
                    zChatPrint(dead_color, phrases[math.random(#phrases)])
                else
                    PrintMessage(HUD_PRINTTALK, phrases[math.random(#phrases)])
                end
            end
        end

        if not ply:IsPlayer() or not ply:Alive() then return end

        if ply.PlayerClassName == "Gordon" and ply:GetNetVar("HEVSuit") then
            ply:SetNetVar("HEVMedicine", ply.HEV.Medicine)
            hevSupplyOxygen(ply, org, timeValue)
            hevAutoAED(ply, org)
            hevAutoSterilize(ply, org)
            if hevSevereDamage(org) then
                hevAutoThiamine(ply, org)
                hevAutoSurgeon(ply, org)
            end
            if org.brain > 0.1 then
                org.mannitol = org.brain * 2
                
                ply:Notify("HEV suit has detected a traumatic brain injury. Injecting mannitol.",true,"mannitol_hev",0.5,function(ply)
                    net.Start("HEV_DAMAGE")
                        net.WriteString("hl1/fvox/automedic_on.wav")
                    net.Send(ply)
                end, hev_color)
            else
                ply:ResetNotification("mannitol_hev")
            end

            if org.pneumothorax > 0 then
                org.lungsR[2] = 0
                org.lungsL[2] = 0
                org.pneumothorax = 0
                org.needle = 0

                ply:Notify("HEV suit has detected pneumothorax. Repairing.", true, "needle_hev", 0.5, function(ply)
                    net.Start("HEV_DAMAGE")
                        net.WriteString("hl1/fvox/automedic_on.wav")
                    net.Send(ply)
                end, hev_color)
            end
            
            local pain = org.pain + org.shock * 3
            if pain > 30 then
                if (org.NextMorphineInject or 0) < CurTime() then
                    org.NextMorphineInject = CurTime() + 10

                    local need = math.min(ply.HEV.Morphine, pain / 80)
                    local old = org.analgesia
                    org.analgesia = math.max(math.min(org.analgesia + need, pain / 80, 1), org.analgesia)
                    local administer = (org.analgesia - old)
                    ply.HEV.Morphine = ply.HEV.Morphine - administer
                    
                    if administer > 0.1 then
                        ply:Notify("HEV suit has detected pain receptors almost reaching the threshold. Injecting morphine.", 10, "morphine_hev", 0.5,
                        function(ply)
                            net.Start("HEV_DAMAGE")
                                net.WriteString("hl1/fvox/morphine_shot.wav")
                            net.Send(ply)
                        end, hev_color)
                    end
                end
            end

            if (org.CO > 10) or (org.COregen > 10) then
                ply:Notify("HEV suit has detected a carbon monoxide presence in the organism. Neutralising.",60,"co_hev",0.5,function(ply)
                    net.Start("HEV_DAMAGE")
                        net.WriteString("hl1/fvox/antidote_shot.wav")
                    net.Send(ply)
                end, hev_color)

                if (org.COThink or 0) < CurTime() then
                    org.COThink = CurTime() + (1 / 120) * 60

                    if org.alive then
                        org.o2[1] = math.min(org.o2[1] + hg.organism.OxygenateBlood(org) * 2, hg.organism.GetAirwayOxygenCap(org))
                        org.CO = math.Approach(org.CO, 0, 2)
                        org.COregen = math.Approach(org.COregen, 0, 2)
                    end
                end
            end

            if (org.BoneCheck or 0) < CurTime() then
                org.BoneCheck = CurTime() + 10

                if ply.HEV.Medicine >= HEV_SPLINT_COST and hg.GetSplintTarget(ply) and hg.ApplySplint(ply, ply) then
                    ply.HEV.Medicine = ply.HEV.Medicine - HEV_SPLINT_COST
                    hevAlert(ply, "HEV suit has detected a fracture. Applying splint.", "bones_hev", "hl1/fvox/major_fracture.wav")
                end
            end

            if (org.BleedThink or 0) < CurTime() then
                org.BleedThink = CurTime() + 3
                hevControlBleeding(ply, org)
            end
            
            if ply.HEV.Medicine > 300 then
                local regen = timeValue / 30

                org.liver = math.max(org.liver - regen, 0)
                org.flank = math.max((org.flank or 0) - regen, 0)
                org.heart = math.max(org.heart - regen, 0)
                org.gut = math.max(org.gut - regen, 0)
                org.lungsR[1] = math.max(org.lungsR[1] - regen, 0)
                org.lungsL[1] = math.max(org.lungsL[1] - regen, 0)
                org.lungsR[2] = math.max(org.lungsR[2] - regen, 0)
                org.lungsL[2] = math.max(org.lungsL[2] - regen, 0)
                org.brain = math.max(org.brain - regen * 0.1, 0)
            end

            if (org.pulse < 40) or (org.blood < 3000) or (org.o2[1] < 10) then
                ply:Notify("HEV suit has detected a critically low pulse. Epinephrine injected. Auto-pulse enabled. Plasma injected.", 60, "pulse_hev", 0.5, function(ply)
                    net.Start("HEV_DAMAGE")
                        net.WriteString("hl1/fvox/health_critical.wav")
                    net.Send(ply)
                end, hev_color)
                
                if (org.BloodThink or 0) < CurTime() then
                    org.BloodThink = CurTime() + 4
    
                    if org.blood < 4000 then
                        local needed = math.min(4000 - org.blood, 500, ply.HEV.Medicine / 6)
                        ply.HEV.Medicine = math.max( ply.HEV.Medicine - needed / 10, 0 )
                        org.blood = org.blood + needed

                        org.adrenalineAdd = 4
                    end
                end
                
                if (org.CPRThink or 0) < CurTime() then
                    org.CPRThink = CurTime() + (1 / 120) * 60
                    
                    if org.alive then
                        org.o2[1] = math.min(org.o2[1] + hg.organism.OxygenateBlood(org) * 2, hg.organism.GetAirwayOxygenCap(org))
                        org.pulse = math.min(org.pulse + 5,70)
                        org.CO = math.Approach(org.CO, 0, 1)
                        org.COregen = math.Approach(org.COregen, 0, 1)
                        if org.pulse > 15 then org.heartstop = false end
                    end
                end
            end
        end
    end)

    hook.Add("HomigradDamage", "HEV_Medical",function(ply, dmgInfo, hitgroup, ent, entharm)
        if ply.PlayerClassName == "Gordon" and ply:GetNetVar("HEVSuit") then
            timer.Simple(0, function()
                timer.Create("HEV_CheckDMG",2,1,function()
                    if not IsValid(ply) or not ply:Alive() or ply.PlayerClassName ~= "Gordon" or ply.HEV.Medicine <= 0 then return end
                    
                    if ply:Health() < 35 then
                        net.Start("HEV_DAMAGE")
                            net.WriteString("hl1/fvox/health_critical.wav")
                        net.Send(ply)
                    end
                end)

                timer.Create("HEV_CheckHP",10,1,function()
                    if not IsValid(ply) or not ply:Alive() or ply.PlayerClassName ~= "Gordon" or ply.HEV.Medicine <= 0 then return end
                    if !entharm or entharm < 1 then return end
                    
                    local org = ply.organism

                    net.Start("HEV_DAMAGE")
                        net.WriteString("hl1/fvox/automedic_on.wav")
                    net.Send(ply)

                end)

                if #ply.organism.wounds > 0 or #ply.organism.arterialwounds > 0 or ply.organism.internalBleed > 0 then
                    if ply.organism.bleed > 0.025 and (!ply.HEV.BloodLossDetect or ply.HEV.BloodLossDetect < CurTime()) then
                        snd = "hl1/fvox/blood_loss.wav"
                        if ply.organism.internalBleed > 0.02 then
                            snd = "hl1/fvox/internal_bleeding.wav"
                        end
                        net.Start("HEV_DAMAGE")
                            net.WriteString(snd)
                        net.Send(ply)

                        ply.HEV.BloodLossDetect = CurTime() + 5
                    end

                end
            end)
        end
    end)

end

