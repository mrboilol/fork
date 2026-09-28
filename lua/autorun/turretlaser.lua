if SERVER then
    AddCSLuaFile()
    return
end

local laserMaterial = Material("effects/laser1")
local spriteMaterial = Material("effects/blueflare1")

CreateClientConVar("turretlaser_enabled", "1", true, false)
CreateClientConVar("turretlaser_targetonly", "0", true, false)

local LASERON = true
local LASERFLASHRATE = 0.2
local LASERFLASHTIMER = 0

hook.Add( "OnEntityCreated", "TurretCreated", function( ent )
    if ( ent:GetClass() == "npc_turret_floor" ) then
		ent:SetCycle(0.5)
	end
end)

local function DrawLaser(attachment, color, turret)
    local startPos = attachment.Pos
    local endPos = startPos + (attachment.Ang:Forward() * 99999)
    
    local tr = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = {turret}
    })

    render.SetMaterial(spriteMaterial)
    render.DrawSprite(startPos, 8, 8, color)
    render.SetMaterial(laserMaterial)
    render.DrawBeam(startPos, tr.HitPos, 1, 0, 1, color)

    if tr.Hit then
        render.SetMaterial(spriteMaterial)
        render.DrawSprite(tr.HitPos, 8, 8, color)

        local dlight = DynamicLight(turret:EntIndex())
        if dlight then
            dlight.pos = tr.HitPos
            dlight.r = color.r
            dlight.g = color.g
            dlight.b = color.b
            dlight.brightness = 1
            dlight.Decay = 500
            dlight.Size = 50
            dlight.DieTime = CurTime() + 0.1
        end
    end
end

local function DrawGroundTurretLaser(turret)
    if GetConVar("turretlaser_enabled"):GetBool() == false then
        return
    end

    if not IsValid(turret) then return end
    if turret:GetCycle() == 0 and turret:GetSequence() == 0 then return end

    local attachmentIndex = turret:LookupAttachment("laser_start")
    if attachmentIndex == 0 then return end
    
    local attachment = turret:GetAttachment(attachmentIndex)
    if not attachment then return end

    local seq = turret:GetSequence()
    local lc = Color(0, 0, 0, 0)
    if seq == 0 then
        if GetConVar("turretlaser_targetonly"):GetBool() == true then
            return
        end

        lc = Color(0, 255, 0, 1)
        LASERON = true
    elseif seq == 1 or seq == 2 then
        if LASERON then
            lc = Color(255, 100, 0, 1)
        end
        
        if CurTime() > LASERFLASHTIMER then
            LASERFLASHTIMER = CurTime() + LASERFLASHRATE
            if LASERON == false then LASERON = true else LASERON = false end
        end
    else
        LASERON = true
        lc = Color(255, 0, 0, 1)
    end
    
    if LASERON then
        DrawLaser(attachment, lc, turret)
    end    
end

local function DrawCeilingTurretLaser(turret)
    if GetConVar("turretlaser_enabled"):GetBool() == false then
        return
    end

    if not IsValid(turret) then return end
    if turret:GetCycle() == 0 and turret:GetSequence() == 0 then return end

    local attachmentIndex = turret:LookupAttachment("light")
    if attachmentIndex == 0 then return end
    
    local attachment = turret:GetAttachment(attachmentIndex)
    if not attachment then return end

    local seq = turret:GetSequence()
    local lc = Color(0, 0, 0, 0)
    if seq == 0 or seq == 1 or seq == 5 then
        LASERON = false
    elseif seq == 1 or seq == 2 then
        if LASERON then
            lc = Color(255, 100, 0, 1)
        end
        
        if CurTime() > LASERFLASHTIMER then
            LASERFLASHTIMER = CurTime() + LASERFLASHRATE
            if LASERON == false then LASERON = true else LASERON = false end
        end
    else
        LASERON = true
        lc = Color(255, 0, 0, 1)
    end
    
    if LASERON then
        DrawLaser(attachment, lc, turret)
    end    
end

hook.Add("PostDrawTranslucentRenderables", "DrawTurretLaser", function()
    for _, turret in ipairs(ents.FindByClass("npc_turret_floor")) do
        DrawGroundTurretLaser(turret)
    end   

    for _, turret in ipairs(ents.FindByClass("npc_turret_ceiling")) do
        DrawCeilingTurretLaser(turret)
    end  
end)

local function CreateSettingsPanel(CPanel)
    CPanel:ClearControls()
    CPanel:CheckBox("Laser Enabled", "turretlaser_enabled")
    CPanel:CheckBox("Target Only", "turretlaser_targetonly")
end

hook.Add("PopulateToolMenu", "CombineTurretLaserSettings", function()
    spawnmenu.AddToolMenuOption("Utilities", "User", "Combine Turret Settings", "Combine Turret Laser", "", "", CreateSettingsPanel)
end)