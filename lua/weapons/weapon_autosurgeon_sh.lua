

if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_bandage_sh"

SWEP.PrintName = "Portable D.I.H Unit"
SWEP.Instructions = "A portable D.I.H (Direct Injury Handler) unit for the people, by the people."
SWEP.Category = "Medicine"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = 1000
SWEP.Primary.DefaultClip = 1000
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "D.I.H Battery"

SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/w_models/weapons/w_eq_medkit.mdl"

SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(4, -0.5, -3)
SWEP.offsetAng = Angle(-30, 20, 90)

SWEP.Slot = 3
SWEP.SlotPos = 2

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.Config = {
    BatteryMax = 1000,
    BatteryRecharge = {
        ["D.I.H Battery"] = 250,
        ["Taser Cartridge"] = 100
    },
    BatteryCost = {
        [1] = 0.15,
        [2] = 0.35,
        [3] = 0.01
    },
    HealAmount = {
        [1] = 0.65,
        [2] = 0.35,
        [3] = 5.0
    },
    HealTime = {
        [1] = 0.8,
        [2] = 1.5,
        [3] = 0.1
    },
    Cooldown = {
        Primary = 0.25,
        Secondary = 0.25,
        Mode = 1,
        Repair = 0.75,
        Cancel = 0.5,
        TargetLost = 1.0
    },
    Range = 64
}

SWEP.Sounds = {
    Cooldown = "failure.ogg",
    LowBattery = "switch.ogg",
    NoTarget = "buttonpress.ogg",
    Nothing = "lightwork.ogg",
    Busy = "crap.ogg",
    Cancel = "crap.ogg",
    TargetLost = "desert.ogg",
    Depleted = "crap.ogg",
    Start = "start.ogg",
    Mode = "insert.ogg",
    Cycle = "lightwork.ogg",
    DebuffCleared = "success.ogg"
}

SWEP.modes = 3
SWEP.mode = 1
SWEP.modeNames = {
    [1] = "simple",
    [2] = "complex",
    [3] = "stitch"
}

SWEP.TargetOrgans = {
    [1] = {
        "skull", "jaw", "chest", "pelvis",
        "rarmartery", "larmartery", "rlegartery", "llegartery",
        "liver", "stomach", "intestines", "spineartery",
        "lungsL", "lungsR", "pneumothorax",
        "rvein", "lvein", "spinevein", "pulmvein",
        "rarmvein", "larmvein", "rlegvein", "llegvein"
    },
    [2] = {
        "heart", "brain",
        "spine1", "spine2", "spine3",
        "arteria", "eyeR", "eyeL", "trachea"
    }
}

SWEP.ArteryOrgans = {
    ["rarmartery"] = true,
    ["larmartery"] = true,
    ["rlegartery"] = true,
    ["llegartery"] = true,
    ["spineartery"] = true,
    ["arteria"] = true
}

SWEP.DebuffClearers = {
    ["lleg"] = function(org) org.llegdislocation = false end,
    ["rleg"] = function(org) org.rlegdislocation = false end,
    ["larm"] = function(org) org.larmdislocation = false end,
    ["rarm"] = function(org) org.rarmdislocation = false end,
    ["jaw"] = function(org) org.jawdislocation = false end,
    ["lungsL"] = function(org)
        if org.lungsL then org.lungsL = {0, 0} end
        org.lungsfunction = true
    end,
    ["lungsR"] = function(org)
        if org.lungsR then org.lungsR = {0, 0} end
        org.lungsfunction = true
    end,
    ["trachea"] = function(org) org.trachea = 0 end,
    ["pneumothorax"] = function(org) org.pneumothorax = 0 end,
    ["eyeL"] = function(org)
        org.eyekaput = nil
        if IsValid(org.owner) then org.owner:SetNetVar("eyekaput", nil) end
    end,
    ["eyeR"] = function(org)
        org.eyekaput = nil
        if IsValid(org.owner) then org.owner:SetNetVar("eyekaput", nil) end
    end,
    ["brain"] = function(org)
        org.consciousness = 1
        org.disorientation = 0
    end,
    ["stomach"] = function(org)
        if org.toxic then org.toxic.natural = {0, 10, 0.5} end
    end,
    ["liver"] = function(org)
        if istable(org.liver) then org.liver[1] = 0 end
        if org.toxic then org.toxic.natural = {0, 10, 0.5} end
    end
}

function SWEP:SetupDataTables()
    self.BaseClass.SetupDataTables(self)
    self:NetworkVar("Bool", 0, "IsHealing")
    self:NetworkVar("Int", 0, "Mode")
    self:NetworkVar("Entity", 0, "TargetPly")
    self:NetworkVar("Float", 0, "NextHealTick")
end

function SWEP:Initialize()
    self:SetHold(self.HoldType)
    self:SetMode(self.mode or 1)
    self:SetNextHealTick(0)
    self:SetIsHealing(false)
    self:SetTargetPly(NULL)
    self.NextModeChange = 0
    self.NextRepairTime = 0
    self.ModelScale = 1

    if SERVER and not self._asInitialized then
        self._asInitialized = true
        if math.random() < 0.75 then
            self:SetClip1(math.random(150, 400))
        else
            self:SetClip1(0)
        end
    end
end

function SWEP:Holster()
    if SERVER and self:GetIsHealing() then
        self:StopProcedure("Procedure halted")
    end
    if CLIENT then self:CancelBandageRotation() end
    return true
end

function SWEP:OnRemove()
    if CLIENT then self:CancelBandageRotation() end
end

function SWEP:CanOperate(owner)
    if not IsValid(owner) or not owner.organism then return true end
    if not hg or not hg.organism then return true end
    local fake2 = hg.organism.fake_spine2 or 1
    local fake3 = hg.organism.fake_spine3 or 1
    if owner.organism.spine2 >= fake2 or owner.organism.spine3 >= fake3 then
        if SERVER then owner:Notify("You can't do that with a broken spine!", 1, "spine_fail", 3) end
        return false
    end
    return true
end

function SWEP:ResolveTarget(ent)
    if not IsValid(ent) then return nil end
    if ent:IsPlayer() then return ent end
    if ent:IsRagdoll() then
        if IsValid(ent.OrgOwner) and ent.OrgOwner:IsPlayer() then return ent.OrgOwner end
        local fr = ent:GetNWEntity("FakeRagdollParent")
        if IsValid(fr) and fr:IsPlayer() then return fr end
        local owner = ent:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then return owner end
        if IsValid(ent.ply) and ent.ply:IsPlayer() then return ent.ply end
    end
    return nil
end

function SWEP:Notify(text, snd)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if SERVER then
        owner:PrintMessage(HUD_PRINTCENTER, text)
        if snd then owner:EmitSound(snd) end
    end
end

function SWEP:DamageValue(org, key)
    local val = org[key]
    if isnumber(val) then return val end
    if istable(val) and (key == "lungsL" or key == "lungsR") then return val[1] or 0 end
    return 0
end

function SWEP:RemoveArterialWound(org, organName)
    if not org.arterialwounds then return false end
    for i = #org.arterialwounds, 1, -1 do
        local wnd = org.arterialwounds[i]
        if wnd and wnd[7] == organName then
            table.remove(org.arterialwounds, i)
            if IsValid(org.owner) and org.owner.SetNetVar then
                org.owner:SetNetVar("arterialwounds", org.arterialwounds)
            end
            return true
        end
    end
    return false
end

function SWEP:ClearDebuffs(org, organName)
    local fn = self.DebuffClearers[organName]
    if fn then fn(org) end
    if org.pain then
        org.pain = math.max(org.pain - 5, 0)
    end
end

function SWEP:StopProcedure(reason, snd)
    self:SetIsHealing(false)
    self:SetTargetPly(NULL)
    if SERVER and reason then
        self:Notify(reason, snd or self.Sounds.Cancel)
    end
end

function SWEP:StartProcedure(target)
    local owner = self:GetOwner()
    if not self:CanOperate(owner) then return false end
    if not IsValid(target) or not target.organism then
        self:Notify("No valid target", self.Sounds.NoTarget)
        return false
    end
    if CurTime() < self.NextRepairTime then
        self:Notify("Autosurgeon burnout", self.Sounds.Cooldown)
        return false
    end
    local cost = self.Config.BatteryCost[self:GetMode()]
    if self:Clip1() < cost then
        self:Notify("Battery low", self.Sounds.LowBattery)
        return false
    end

    self:SetIsHealing(true)
    self:SetTargetPly(target)
    self:SetNextHealTick(CurTime())
    self:Notify("Procedure started", self.Sounds.Start)
    self.NextRepairTime = CurTime() + self.Config.Cooldown.Repair
    return true
end

function SWEP:PrimaryAttack()
    if not SERVER then return end
    local owner = self:GetOwner()
    if not self:CanOperate(owner) then return end
    if self._LastPrimary and self._LastPrimary > CurTime() then return end
    self._LastPrimary = CurTime() + self.Config.Cooldown.Primary
    self:SetNextPrimaryFire(CurTime() + self.Config.Cooldown.Primary)
    if self:GetIsHealing() then
        self:Notify("Already working", self.Sounds.Busy)
        return
    end
    self:StartProcedure(owner)
end

function SWEP:SecondaryAttack()
    if not SERVER then return end
    local owner = self:GetOwner()
    if not self:CanOperate(owner) then return end
    if self._LastSecondary and self._LastSecondary > CurTime() then return end
    self._LastSecondary = CurTime() + self.Config.Cooldown.Secondary
    self:SetNextSecondaryFire(CurTime() + self.Config.Cooldown.Secondary)
    if self:GetIsHealing() then
        self:StopProcedure("Procedure halted", self.Sounds.Cancel)
        self.NextRepairTime = CurTime() + self.Config.Cooldown.Cancel
        return
    end
    local target = self:ResolveTarget(hg.eyeTrace(owner).Entity)
    if not IsValid(target) or target == owner then
        self:Notify("Target not found", self.Sounds.NoTarget)
        return
    end
    self:StartProcedure(target)
end

function SWEP:Reload()
    if not SERVER then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if self._LastReload and self._LastReload > CurTime() then return end
    self._LastReload = CurTime() + 0.4
    if self:GetIsHealing() then
        self:Notify("Changes unavailable", self.Sounds.Busy)
        return
    end
    if self.NextModeChange > CurTime() then
        self:Notify("Change burnout", self.Sounds.Cooldown)
        return
    end
    local m = (self:GetMode() % self.modes) + 1
    self:SetMode(m)
    self.mode = m
    self:Notify("Mode: " .. self.modeNames[m], self.Sounds.Mode)
    self.NextModeChange = CurTime() + self.Config.Cooldown.Mode
    if SERVER then
        net.Start("select_mode")
        net.WriteEntity(self)
        net.WriteInt(m, 4)
        net.Broadcast()
    end
end

function SWEP:TickStitch()
    local target = self:GetTargetPly()
    if not IsValid(target) or not target.organism then return self:StopProcedure("Patient lost", self.Sounds.TargetLost) end
    local org = target.organism
    if not org.wounds or #org.wounds == 0 then
        self:StopProcedure("No bleeding", self.Sounds.Nothing)
        return
    end
    table.sort(org.wounds, function(a, b) return (a and a[1] or 0) > (b and b[1] or 0) end)
    local wound = org.wounds[1]
    if not wound or not wound[1] or wound[1] <= 0 then
        self:StopProcedure("No active bleeding", self.Sounds.Nothing)
        return
    end
    local cost = self.Config.BatteryCost[3]
    if self:Clip1() < cost then
        self:StopProcedure("Battery depleted", self.Sounds.Depleted)
        return
    end
    local heal = self.Config.HealAmount[3]
    wound[1] = math.max(0, wound[1] - heal)
    self:SetClip1(math.max(0, self:Clip1() - cost))
    if wound[1] <= 0 then
        table.remove(org.wounds, 1)
        if IsValid(org.owner) and org.owner.SetNetVar then
            org.owner:SetNetVar("wounds", org.wounds)
        end
    end
    if org.pain then org.pain = math.max(org.pain - 1, 0) end
end

function SWEP:TickOrgans()
    local target = self:GetTargetPly()
    if not IsValid(target) or not target.organism then return self:StopProcedure("Patient lost", self.Sounds.TargetLost) end
    local mode = self:GetMode()
    local org = target.organism
    local organs = self.TargetOrgans[mode]
    if not organs then return self:StopProcedure("No organs", self.Sounds.Nothing) end

    local currentOrgan, maxDamage = nil, 0
    for _, k in ipairs(organs) do
        local dmg = self:DamageValue(org, k)
        if dmg > maxDamage then
            maxDamage = dmg
            currentOrgan = k
        end
    end
    if not currentOrgan or maxDamage <= 0 then
        self:StopProcedure("No damage detected", self.Sounds.Nothing)
        return
    end

    local cost = self.Config.BatteryCost[mode]
    if self:Clip1() < cost then
        self:StopProcedure("Battery depleted", self.Sounds.Depleted)
        return
    end

    local old = self:DamageValue(org, currentOrgan)
    local heal = self.Config.HealAmount[mode]
    local newValue = math.max(0, old - heal)

    if currentOrgan == "lungsL" or currentOrgan == "lungsR" then
        org[currentOrgan][1] = newValue
    else
        org[currentOrgan] = newValue
    end
    self:SetClip1(math.max(0, self:Clip1() - cost))

    self:ClearDebuffs(org, currentOrgan)

    if self.ArteryOrgans[currentOrgan] and newValue == 0 then
        self:RemoveArterialWound(org, currentOrgan)
    end
end

function SWEP:Think()
    self:SetHold(self.HoldType)
    self.ModelScale = 1

    if not SERVER then return end
    if not self:GetIsHealing() then return end

    local owner = self:GetOwner()
    if not self:CanOperate(owner) then
        self:StopProcedure("Operator spine failure", self.Sounds.Cancel)
        return
    end

    local target = self:GetTargetPly()
    if not IsValid(target) or not target.organism then
        self:StopProcedure("Patient lost", self.Sounds.TargetLost)
        self.NextRepairTime = CurTime() + self.Config.Cooldown.TargetLost
        return
    end

    if owner:GetPos():Distance(target:GetPos()) > self.Config.Range or not owner:Visible(target) then
        self:StopProcedure("Target out of range", self.Sounds.TargetLost)
        self.NextRepairTime = CurTime() + self.Config.Cooldown.TargetLost
        return
    end

    if CurTime() < self:GetNextHealTick() then return end
    local mode = self:GetMode()
    self:SetNextHealTick(CurTime() + self.Config.HealTime[mode])

    if mode == 3 then
        self:TickStitch()
    else
        self:TickOrgans()
    end
end

if SERVER then
    util.AddNetworkString("AS_Recharge")

    net.Receive("AS_Recharge", function(len, ply)
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_autosurgeon_sh" then return end
        if not wep:CanOperate(ply) then return end

        local hasBattery = ply:GetAmmoCount("D.I.H Battery") > 0
        local hasTaser = ply:GetAmmoCount("Taser Cartridge") > 0
        if not hasBattery and not hasTaser then return end

        local maxBat = wep.Config.BatteryMax
        local current = wep:Clip1()
        if current >= maxBat then
            wep:Notify("Battery full", wep.Sounds.Cooldown)
            return
        end

        local amount, source
        if hasBattery then
            ply:RemoveAmmo(1, "D.I.H Battery")
            amount = wep.Config.BatteryRecharge["D.I.H Battery"]
            source = "D.I.H Battery"
        else
            ply:RemoveAmmo(1, "Taser Cartridge")
            amount = wep.Config.BatteryRecharge["Taser Cartridge"]
            source = "Taser Cartridge"
        end

        wep:SetClip1(math.min(current + amount, maxBat))
        wep:Notify("Recharged from " .. source, "snd_jack_hmcd_ammobox.wav")
    end)
end

if CLIENT then
    SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_medkit")
    SWEP.IconOverride = "vgui/wep_jack_hmcd_medkit.png"
    SWEP.BounceWeaponIcon = false

    local hg_3dzity = CreateClientConVar("hg_3dzity", "1", true, false, "Toggle 3D UI for containers and medical sweps", 0, 1)
    local colBrown = Color(40, 40, 40)
    local colWhite = Color(255, 255, 255, 255)
    local colGray = Color(200, 200, 200, 200)
    local lerpthing = 1

    function SWEP:DrawHUD()
        local owner = self:GetOwner()
        if not IsValid(owner) or not owner:IsPlayer() then return end
        if GetViewEntity() ~= owner then return end
        if owner:InVehicle() then return end

        local mdl = modelshuy[self.Model or self.WorldModel]
        if not IsValid(mdl) then return end

        local tr = hg.eyeTrace(owner)
        if not tr then return end

        local use3D = hg_3dzity:GetBool()
        local size = math.max(math.min(1 - tr.Fraction, 0.5), 0.1)
        local sx, sy = tr.HitPos:ToScreen().x, tr.HitPos:ToScreen().y

        if not use3D and tr.Hit then
            lerpthing = Lerp(0.1, lerpthing, 1)
            colWhite.a = 255 * size
            surface.SetDrawColor(colGray)
            draw.NoTexture()
            surface.SetDrawColor(colWhite)
            draw.NoTexture()
            surface.DrawRect(sx - 25 * lerpthing, sy - 2.5, 50 * lerpthing, 5)
            surface.DrawRect(sx - 2.5, sy - 25 * lerpthing, 5, 50 * lerpthing)
            local col = tr.Entity:GetPlayerColor():ToColor()
            local outline = (col.r < 50 and col.g < 50 and col.b < 50) and Color(255, 255, 255) or Color(0, 0, 0)
            outline.a = 255 * size * 2
            local name = (tr.Entity:IsPlayer() or tr.Entity:IsRagdoll()) and tr.Entity:GetPlayerName() or ""
            draw.DrawText(name, "HomigradFontLarge", sx + 1, sy + 31, outline, TEXT_ALIGN_CENTER)
            draw.DrawText(name, "HomigradFontLarge", sx, sy + 30, col, TEXT_ALIGN_CENTER)
        end

        self:DrawWorldModel2(true)
        local p, a = mdl:GetPos(), mdl:GetAngles()
        local pos, ang = LocalToWorld(self.ofsV, self.ofsA, p, a)
        if use3D then
            cam.Start3D()
                cam.Start3D2D(pos, ang, 0.01)
                render.PushFilterMag(TEXFILTER.LINEAR)
                render.PushFilterMin(TEXFILTER.LINEAR)
                    local battery = self:Clip1()
                    local maxBat = self.Config.BatteryMax
                    local pct = math.Clamp(battery / maxBat, 0, 1)
                    local val = math.Round(pct * 100)
                    local textWidth = 150
                    local barWidth = 100
                    local barHeight = 25
                    local mode = self:GetMode()
                    local txt = string.NiceName(tostring(self.modeNames[mode])) .. " (" .. val .. "%)"

                    colBrown.a = 185
                    draw.RoundedBox(2, 0, 0, textWidth + barWidth, barHeight, colBrown)
                    surface.SetFont("ZCity_Small")
                    surface.SetTextPos(0, 0)
                    surface.SetTextColor(255, 255, 255, 255)
                    draw.SimpleTextOutlined(txt, "ZCity_Small", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1.5, colBrown)

                    surface.SetDrawColor(0, 100, 0, 255)
                    surface.DrawRect(textWidth, 0, barWidth * val / 100, barHeight)
                    surface.SetDrawColor(0, 0, 0, 255)
                    surface.DrawOutlinedRect(textWidth, 0, barWidth, barHeight, 4)
                render.PopFilterMag()
                render.PopFilterMin()
            cam.End3D2D()
        cam.End3D()
        end
    end

    local altWasDown = false
    hook.Add("Think", "AutosurgeonAltRadial", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_autosurgeon_sh" then return end

        local altDown = input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
        if altDown and not altWasDown then
            local hasBattery = ply:GetAmmoCount("D.I.H Battery") > 0
            local hasTaser = ply:GetAmmoCount("Taser Cartridge") > 0
            if not hasBattery and not hasTaser then return end

            local options = {
                {
                    function()
                        net.Start("AS_Recharge")
                        net.SendToServer()
                    end,
                    "Recharge D.I.H"
                }
            }
            hg.CreateRadialMenu(options)
        end
        altWasDown = altDown
    end)
end