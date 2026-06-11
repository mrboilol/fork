AddCSLuaFile()
local function applyMagazineReload(wep)
    if not IsValid(wep) or not wep.ishgwep then return end
    if wep._magazineReloadApplied then return end
    wep._magazineReloadApplied = true
    local oldInitialize = wep.Initialize
    local oldOwnerChanged = wep.OwnerChanged
    local oldReloadEnd = wep.ReloadEnd
    local oldCanReload = wep.CanReload
    local function fillMagazine(self)
        if SERVER then
            local maxClip = self:GetMaxClip1()
            self:SetClip1(maxClip)
            if self.drawBullet ~= nil then
                self.drawBullet = true
            end
        end
    end
    wep.Initialize = function(self, ...)
        oldInitialize(self, ...)
        self._justSpawned = true
        fillMagazine(self)
    end
    wep.CanReload = function(self, ...)
        if not oldCanReload(self, ...) then return false end
        if SERVER then
            local owner = self:GetOwner()
            if not IsValid(owner) then return false end
            local reserve = owner:GetAmmoCount(self:GetPrimaryAmmoType())
            local maxClip = self:GetMaxClip1()
            local currentClip = self:Clip1()
            if reserve >= maxClip then
                return true
            end
            if currentClip < maxClip and reserve > 0 then
                return true
            end
            return false
        else
            return true
        end
    end
    wep.ReloadEnd = function(self)
        if SERVER then
            local owner = self:GetOwner()
            if not IsValid(owner) then return end
            local ammoType = self:GetPrimaryAmmoType()
            local reserve = owner:GetAmmoCount(ammoType)
            local maxClip = self:GetMaxClip1()
            local currentClip = self:Clip1()
            
            -- Drop magazine with current ammo before reloading
            if currentClip > 0 then
                local mag = ents.Create("ent_hg_magazine")
                if IsValid(mag) then
                    local ammoName = game.GetAmmoName(ammoType) or ""
                    mag:SetMagazineData(currentClip, ammoName, self:GetClass())
                    
                    -- Position the magazine at the player's position
                    local pos = owner:GetPos() + owner:GetForward() * 20 + owner:GetUp() * 30
                    mag:SetPos(pos)
                    mag:SetAngles(owner:GetAngles())
                    mag:Spawn()
                    
                    -- Give it some velocity
                    local phys = mag:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:SetVelocity(owner:GetVelocity() + owner:GetForward() * 100 + VectorRand() * 20)
					end
                end
            end
            
            if reserve <= 0 then
                if self.Primary.SoundEmpty then
                    self:PlaySnd(self.Primary.SoundEmpty, true)
                end
                self.reload = nil
                self.ReloadNext = nil
                return
            end
            if reserve >= maxClip then
                owner:SetAmmo(reserve - maxClip, ammoType)
                self:SetClip1(maxClip)
            else
                local need = maxClip - currentClip
                local take = math.min(need, reserve)
                owner:SetAmmo(reserve - take, ammoType)
                self:SetClip1(currentClip + take)
            end
            net.Start("hg_insertAmmo")
                net.WriteEntity(self)
                net.WriteInt(self:Clip1(), 10)
            net.Broadcast()
            self:Draw()
        end
        if oldReloadEnd and oldReloadEnd ~= wep.ReloadEnd then
            oldReloadEnd(self)
        end
        self.reload = nil
        self.ReloadNext = nil
        self.dwr_reverbDisable = nil
        self.shot = 0
        self.shot2 = 0
        self.SprayI = 0
        self.lastShoot = 0
    end
end
hook.Add("OnWeaponCreated", "MagazineReload", applyMagazineReload)
hook.Add("WeaponEquip", "MagazineReload", function(wep, ply)
    applyMagazineReload(wep)
end)
hook.Add("PlayerSpawn", "MagazineReload", function(ply)
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        for _, wep in ipairs(ply:GetWeapons()) do
            applyMagazineReload(wep)
        end
    end)
end)
hook.Add("OnEntityCreated", "MagazineReload", function(ent)
    if not IsValid(ent) then return end
    timer.Simple(0, function()
        if IsValid(ent) and ent.ishgwep then
            applyMagazineReload(ent)
        end
    end)
end)
local scanCount = 0
timer.Create("MagazineReloadScan", 2, 5, function()
    scanCount = scanCount + 1
    for _, ent in ipairs(ents.GetAll()) do
        if ent.ishgwep then
            applyMagazineReload(ent)
        end
    end
end)
hook.Add("PlayerCanPickupWeapon", "MagazineReload_Pickup", function(ply, wep)
    if not IsValid(wep) or not wep.ishgwep then return end
    if wep.IsSpawned and not ply:KeyDown(IN_USE) and not ply.force_pickup then
        return false
    end
end)

-- Drop magazine when weapon is dropped
hook.Add("PlayerDropWeapon", "MagazineReload_Drop", function(ply)
    if not IsValid(ply) then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.ishgwep then return end
    
    local currentClip = wep:Clip1()
    if currentClip > 0 then
        local mag = ents.Create("ent_hg_magazine")
        if IsValid(mag) then
            local ammoType = wep:GetPrimaryAmmoType()
            local ammoName = game.GetAmmoName(ammoType) or ""
            mag:SetMagazineData(currentClip, ammoName, wep:GetClass())
            
            -- Position the magazine at the player's position
            local pos = ply:GetPos() + ply:GetForward() * 20 + ply:GetUp() * 30
            mag:SetPos(pos)
            mag:SetAngles(ply:GetAngles())
            mag:Spawn()
            
            -- Give it some velocity
            local phys = mag:GetPhysicsObject()
            if IsValid(phys) then
                phys:SetVelocity(ply:GetVelocity() + ply:GetForward() * 100 + VectorRand() * 20)
            end
        end
    end
end)