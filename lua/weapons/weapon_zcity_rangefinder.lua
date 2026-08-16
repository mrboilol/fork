if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("zcity_rangefinder/cl_dev.lua")
end

local PRIMARY_DELAY = 0.3
local MAX_TRACE_DISTANCE = 50000
local HU_TO_METERS = 0.0254
local GROUND_PHYSICS_MASS = 2

local function CallHomigradBaseMethod(self, methodName)
    local base = weapons.Get("homigrad_base")
    local method = base and base[methodName]

    if method then
        return method(self)
    end
end

SWEP.Base = "homigrad_base"
SWEP.PrintName = "Laser Rangefinder"
SWEP.Author = "Vortex Ranger 1500"
SWEP.Instructions = "Hold Right Click to look through the scope. Left Click to measure distance."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.NPCSpawnable = false
SWEP.NPCUsable = false

SWEP.Slot = 5
SWEP.SlotPos = 1

SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/arc9/darsu_eft/w_rangefinder.mdl"
SWEP.WorldModelFake = "models/weapons/arc9/darsu_eft/c_rangefinder.mdl"
SWEP.UseCustomWorldModel = true

if CLIENT then
    SWEP.WepSelectIcon = Material("entities/weapon_zcity_rangefinder.png")
    SWEP.WepSelectIcon2 = Material("entities/weapon_zcity_rangefinder.png")
    SWEP.WepSelectIcon2box = true
end


SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Damage = 0
SWEP.Primary.Force = 1
SWEP.Primary.Cone = 0
SWEP.Primary.Wait = PRIMARY_DELAY

SWEP.Secondary = SWEP.Secondary or {}
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.weight = 2
SWEP.Ergonomics = 1.0
SWEP.HoldType = "rpg"

-- Deploy / Holster Sounds
SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.ogg", 55, 100, 110}

-- Positioning offsets for the model on the hands
SWEP.RHPos = Vector(5.5, -7.5, 4)
SWEP.RHAng = Angle(0, -5, 90)
SWEP.LHPos = Vector(14, -1, -5)
SWEP.LHAng = Angle(-90, -90, -90)

-- World and Fake model offset positions required by homigrad_base
SWEP.WorldPos = Vector(0, 1.1, -1)
SWEP.WorldAng = Angle(2, 0, 0)

-- We split FakePos and FakeAng into Idle and Zoom states for smooth transition (just like in ARC9!)
SWEP.FakePosIdle = Vector(-11, 8.2, 7.5)
SWEP.FakeAngIdle = Angle(0, 0, 0)

SWEP.FakePosZoom = Vector(-11, 8.2, 7.5)
SWEP.FakeAngZoom = Angle(0, 0, 0)

SWEP.FakePos = Vector(-11, 8.2, 7.5)
SWEP.FakeAng = Angle(0, 0, 0)

-- ARC9's rangefinder model has real sight animations; Homigrad camera still
-- needs a normal ZoomPos so it does not clip into the player's head.
SWEP.RangefinderSightAnimTime = 0.22


-- Attachment and Muzzle placement offsets required by homigrad_base
SWEP.AttachmentPos = Vector(0, 0, 0)
SWEP.AttachmentAng = Angle(0, 0, 0)
SWEP.LocalMuzzlePos = Vector(0, 0, 0)
SWEP.LocalMuzzleAng = Angle(0, 0, 0)
SWEP.attPos = Vector(0, 0, 0)
SWEP.attAng = Angle(0, 0, 0)

SWEP.ZoomPos = Vector(-6, 3.35, 7.85)
SWEP.localScopePos = Vector(-1, 5.1582, 3.5166)
SWEP.RangefinderUseScopeBone = true
SWEP.RangefinderScopeBoneName = "Camera_animated"
SWEP.RangefinderRTDebug = 0
SWEP.RangefinderRTUseScopeOrigin = false
SWEP.RangefinderForceAllRT = false
SWEP.RangefinderLensDiskSize = 1.65
SWEP.RangefinderLensDiskOffset = 0.04
SWEP.RangefinderLensDiskRight = 0
SWEP.RangefinderLensDiskUp = 0
SWEP.RangefinderLensDiskRotation = 0
SWEP.RangefinderLensDiskEnabled = false
SWEP.RangefinderLensDiskIgnoreDepth = true
SWEP.RangefinderOpticShadow = true
SWEP.RangefinderOpticEyeBox = 0.28
SWEP.RangefinderOpticBlackout = 0.95
SWEP.RangefinderOpticShadowScale = 1.0
SWEP.RangefinderOpticFallbackDivisor = 4
SWEP.RangefinderOpticMaskScale = 1.55
SWEP.RangefinderOpticMaskShift = 0.15
SWEP.RangefinderOpticMaskDistMul = 1

-- Realistic RT scope configuration
SWEP.dort = true
SWEP.scopedef = true
SWEP.scopemat = Material("decals/scope.png")
SWEP.perekrestie = Material("null") -- We draw our custom reticle programmatically
SWEP.sizeperekrestie = 0
SWEP.scope_blackout = 200
SWEP.blackoutsize = 4600
SWEP.rot = 0
SWEP.mat = Material("effects/zcity_rangefinder_rt")

SWEP.attachments = {
    barrel = {},
    sight = {},
    mount = {},
    grip = {},
    underbarrel = {},
    magwell = {},
}

-- Zoom properties
SWEP.ZoomFOV = 12
SWEP.FOVMin = 4
SWEP.FOVMax = 12
SWEP.FOVScoped = 12

-- Weapon animations mapping
SWEP.AnimList = {
    ["idle"] = "idle",
    ["idle_sights"] = "idle_sights",
    ["draw"] = "draw",
    ["holster"] = "holster",
    ["ironsight_in"] = "ironsight_in",
    ["ironsight_out"] = "ironsight_out",
    ["inspect"] = "inspect"
}

-- Measure distance on Left Click
function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + PRIMARY_DELAY)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if SERVER then
        local shootPos = owner:GetShootPos()

        local trace = util.TraceLine({
            start = shootPos,
            endpos = shootPos + owner:GetAimVector() * MAX_TRACE_DISTANCE,
            filter = {owner, self}
        })

        if trace.Hit and not trace.HitSky then
            local distHU = trace.StartPos:Distance(trace.HitPos)
            local distMeters = distHU * HU_TO_METERS
            
            -- Calculate inclination angle (pitch: looking UP is negative, DOWN is positive.
            -- So we invert pitch to make looking UP positive inclination, looking DOWN negative)
            local pitch = owner:EyeAngles().p
            local inclination = -pitch
            local compDist = distMeters * math.cos(math.rad(inclination))

            self:SetNWFloat("MeasuredDistance", distMeters)
            self:SetNWFloat("MeasuredAngle", inclination)
            self:SetNWFloat("CompensatedDistance", compDist)
            self:SetNWBool("HasDistance", true)
        else
            self:SetNWFloat("MeasuredDistance", 0)
            self:SetNWFloat("MeasuredAngle", 0)
            self:SetNWFloat("CompensatedDistance", 0)
            self:SetNWBool("HasDistance", false)
        end

        self:EmitSound("buttons/button14.wav", 60, 100)
    end
end

function SWEP:SecondaryAttack()
    -- Aiming is handled by homigrad_base (holding Right Click/IN_ATTACK2)
end

function SWEP:ShouldUseFakeModel()
    if not IsValid(self:GetOwner()) then return false end
    return self.WorldModelFake ~= nil
end

function SWEP:DrawWorldModel()
    local owner = self:GetOwner()
    if not IsValid(owner) then
        self:DrawModel()
        return
    end

    CallHomigradBaseMethod(self, "DrawWorldModel")
end

function SWEP:KeyDown(key)
    local owner = self:GetOwner()
    if not IsValid(owner) then return false end
    
    -- Block IN_USE specifically when IN_ATTACK is held to disable the buttstock melee attack
    if key == IN_USE and owner:KeyDown(IN_ATTACK) then
        return false
    end
    
    if hg and hg.KeyDown then
        return hg.KeyDown(owner, key)
    end
    return owner:KeyDown(key)
end

function SWEP:SetupGroundPhysics()
    if CLIENT then return end
    
    self:SetModel(self.WorldModel)
    
    local mins, maxs = self:OBBMins(), self:OBBMaxs()
    
    -- If OBB is too small or invalid, use a fallback box
    if not mins or not maxs or mins:Distance(maxs) < 2 then
        mins = Vector(-6, -3, -3)
        maxs = Vector(6, 3, 3)
    end
    
    self:PhysicsInitBox(mins, maxs)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(GROUND_PHYSICS_MASS)
        phys:SetMaterial("weapon")
    end
end

function SWEP:Initialize()
    CallHomigradBaseMethod(self, "Initialize")
    
    if SERVER and not IsValid(self:GetOwner()) then
        timer.Simple(0, function()
            if IsValid(self) and not IsValid(self:GetOwner()) then
                self:SetupGroundPhysics()
            end
        end)
    end
end

function SWEP:OnDrop()
    CallHomigradBaseMethod(self, "OnDrop")
    
    timer.Simple(0, function()
        if IsValid(self) and not IsValid(self:GetOwner()) then
            self:SetupGroundPhysics()
        end
    end)
end


function SWEP:Think()
    CallHomigradBaseMethod(self, "Think")

    if CLIENT then
        local zoom = self:IsZoom()
        self.myZoomLerp = Lerp(FrameTime() * 10, self.myZoomLerp or 0, zoom and 1 or 0)

        self.FakePos = LerpVector(self.myZoomLerp, self.FakePosIdle or Vector(-11, 8.2, 7.5), self.FakePosZoom or Vector(-11, 8.2, 7.5))
        self.FakeAng = LerpAngle(self.myZoomLerp, self.FakeAngIdle or Angle(0, 0, 0), self.FakeAngZoom or Angle(0, 0, 0))
        if self.UpdateRangefinderSightAnim then
            self:UpdateRangefinderSightAnim(zoom)
        end
    end
end

if CLIENT then
    local rangefinderZeroAng = Angle(0, 0, 0)
    local rangefinderRTName = "zcity_rangefinder_rt"
    local rangefinderRTSize = 512
    local rangefinderRT = GetRenderTargetEx(
        rangefinderRTName,
        rangefinderRTSize,
        rangefinderRTSize,
        RT_SIZE_NO_CHANGE,
        MATERIAL_RT_DEPTH_SHARED,
        bit.bor(2, 256),
        0,
        IMAGE_FORMAT_BGR888
    )
    local rangefinderRTMaterialPath = "effects/zcity_rangefinder_rt"
    local rangefinderRTMaterial = Material(rangefinderRTMaterialPath)
    local rangefinderRTGlassMaterialPath = "models/weapons/arc9/darsu_eft/ranger/rtglass"
    local rangefinderRTGlassMaterial = Material(rangefinderRTGlassMaterialPath)
    local rangefinderClearMaterialPath = "effects/zcity_rangefinder_clear"
    local rangefinderClearMaterial = Material(rangefinderClearMaterialPath)
    local rangefinderGlassTexture = Material("vgui/black"):GetTexture("$basetexture")
    local rangefinderWhiteMaterial = Material("vgui/white")

    local function NormalizeMaterialPath(matPath)
        return string.lower(string.gsub(matPath or "", "\\", "/"))
    end

    local function IsRangefinderGlassMaterial(matPath)
        return string.find(NormalizeMaterialPath(matPath), "rtglass", 1, true) ~= nil
    end

    local function IsRangefinderRTSlotMaterial(matPath)
        local lower = string.lower(string.gsub(matPath or "", "\\", "/"))

        return lower == "rt"
            or lower == "effects/arc9/rt"
            or lower == "effects/zcity_rangefinder_rt"
            or string.find(lower, "/rt", 1, true)
    end

    -- Register Digital Font
    surface.CreateFont("ZCity_Rangefinder_Digital", {
        font = "Digital-7",
        size = ScreenScale(28),
        weight = 500,
        antialias = true,
        additive = false
    })

    surface.CreateFont("ZCity_Rangefinder_Digital_Medium", {
        font = "Digital-7",
        size = ScreenScale(16),
        weight = 500,
        antialias = true,
        additive = false
    })

    surface.CreateFont("ZCity_Rangefinder_Digital_Small", {
        font = "Digital-7",
        size = ScreenScale(8),
        weight = 500,
        antialias = true,
        additive = false
    })

    surface.CreateFont("ZCity_Rangefinder_RT", {
        font = "Digital-7",
        size = 41,
        weight = 500,
        antialias = true,
        additive = false
    })

    surface.CreateFont("ZCity_Rangefinder_RT_Medium", {
        font = "Digital-7",
        size = 23,
        weight = 500,
        antialias = true,
        additive = false
    })

    surface.CreateFont("ZCity_Rangefinder_RT_Small", {
        font = "Digital-7",
        size = 13,
        weight = 500,
        antialias = true,
        additive = false
    })

    local arrowVertices = {
        -- Head
        { x = 0, y = -8 },
        { x = 4, y = -2 },
        { x = 1.5, y = -2 },
        -- Shaft
        { x = 1.5, y = 6 },
        { x = -1.5, y = 6 },
        -- Head other side
        { x = -1.5, y = -2 },
        { x = -4, y = -2 }
    }

    local function DrawWindArrow(centerX, centerY, angleDegrees, scale, color)
        local rad = math.rad(angleDegrees)
        local cosR = math.cos(rad)
        local sinR = math.sin(rad)
        
        local rotated = {}
        for i, v in ipairs(arrowVertices) do
            rotated[i] = {
                x = centerX + (v.x * scale * cosR - v.y * scale * sinR),
                y = centerY + (v.x * scale * sinR + v.y * scale * cosR)
            }
        end
        
        draw.NoTexture()
        surface.SetDrawColor(color)
        surface.DrawPoly(rotated)
    end

    local function DrawDegreeSymbol(x, y, font, color, alignX, alignY, text)
        surface.SetFont(font)
        local w, h = surface.GetTextSize(text)
        
        local startX = x
        if alignX == TEXT_ALIGN_CENTER then
            startX = x - w * 0.5
        elseif alignX == TEXT_ALIGN_RIGHT then
            startX = x - w
        end
        
        local degSize = math.max(math.Round(h * 0.12), 2)
        local degX = startX + w + math.max(math.Round(h * 0.08), 2)
        local degY = y
        if alignY == TEXT_ALIGN_BOTTOM then
            degY = y - h + math.max(math.Round(h * 0.12), 2)
        elseif alignY == TEXT_ALIGN_TOP then
            degY = y + math.max(math.Round(h * 0.12), 2)
        else
            degY = y - h * 0.5 + math.max(math.Round(h * 0.12), 2)
        end
        
        surface.SetDrawColor(color)
        surface.DrawOutlinedRect(degX, degY, degSize, degSize)
    end


    -- Automatically find the RT Lens material in the model and bind it to optics rendering
    function SWEP:ModelCreated(model)
        if not IsValid(model) then return end
        self.RangefinderWasZoom = nil
        self.RangefinderLensMaterial = rangefinderRTMaterialPath
        self.RangefinderScopeBone = nil
        self.mat = rangefinderRTMaterial

        self:RefreshRangefinderLensSubMaterials(model)
        self:ApplyRangefinderRTMaterial()
    end

    function SWEP:RefreshRangefinderLensSubMaterials(model)
        model = IsValid(model) and model or self:GetWM()
        if not IsValid(model) then return end

        self.RangefinderLensSubMaterials = {}
        self.RangefinderGlassSubMaterials = {}
        self.RangefinderRTSubMaterials = {}

        local mats = model:GetMaterials()
        if not mats then return end

        for index, matPath in ipairs(mats) do
            local subMaterialIndex = index - 1

            if IsRangefinderGlassMaterial(matPath) then
                self.RangefinderLensSubMaterial = subMaterialIndex
                self.RangefinderLensSubMaterials[#self.RangefinderLensSubMaterials + 1] = subMaterialIndex
                self.RangefinderGlassSubMaterials[#self.RangefinderGlassSubMaterials + 1] = subMaterialIndex
            elseif IsRangefinderRTSlotMaterial(matPath) then
                self.RangefinderLensSubMaterial = subMaterialIndex
                self.RangefinderLensSubMaterials[#self.RangefinderLensSubMaterials + 1] = subMaterialIndex
                self.RangefinderRTSubMaterials[#self.RangefinderRTSubMaterials + 1] = subMaterialIndex
            end
        end
    end

    function SWEP:ApplyRangefinderLensSubMaterials(model)
        model = IsValid(model) and model or self:GetWM()
        if not IsValid(model) then return end

        if not self.RangefinderLensSubMaterials or #self.RangefinderLensSubMaterials == 0 then
            self:RefreshRangefinderLensSubMaterials(model)
        end

        if self.RangefinderForceAllRT then
            for index in ipairs(model:GetMaterials() or {}) do
                model:SetSubMaterial(index - 1, rangefinderRTMaterialPath)
            end

            return
        end

        local glassSlots = table.Copy(self.RangefinderGlassSubMaterials or {})
        local rtSlots = table.Copy(self.RangefinderRTSubMaterials or {})

        if #rtSlots == 0 and #glassSlots > 0 then
            rtSlots[1] = table.remove(glassSlots)
        end

        if #glassSlots == 0 and #rtSlots == 0 then
            model:SetSubMaterial(0, "")
            model:SetSubMaterial(1, rangefinderClearMaterialPath)
            model:SetSubMaterial(2, rangefinderRTMaterialPath)
            return
        end

        for _, subMaterialIndex in ipairs(glassSlots) do
            model:SetSubMaterial(subMaterialIndex, rangefinderClearMaterialPath)
        end

        for _, subMaterialIndex in ipairs(rtSlots) do
            model:SetSubMaterial(subMaterialIndex, rangefinderRTMaterialPath)
        end
    end

    function SWEP:ClearRangefinderLensSubMaterials(model)
        model = IsValid(model) and model or self:GetWM()
        if not IsValid(model) then return end

        if not self.RangefinderLensSubMaterials or #self.RangefinderLensSubMaterials == 0 then
            self:RefreshRangefinderLensSubMaterials(model)
        end

        if not self.RangefinderLensSubMaterials or #self.RangefinderLensSubMaterials == 0 then
            for index in ipairs(model:GetMaterials() or {}) do
                model:SetSubMaterial(index - 1, index == 1 and "" or rangefinderClearMaterialPath)
            end

            return
        end

        for _, subMaterialIndex in ipairs(self.RangefinderLensSubMaterials) do
            model:SetSubMaterial(subMaterialIndex, rangefinderClearMaterialPath)
        end
    end

    function SWEP:UpdateRangefinderScopePos()
        if not self.RangefinderUseScopeBone then return end
        if not self.GetTrace then return end

        local model = self:GetWM()
        if not IsValid(model) then return end

        if self.RangefinderScopeBone == nil then
            self.RangefinderScopeBone = model:LookupBone(self.RangefinderScopeBoneName or "Camera_animated") or false
        end

        if self.RangefinderScopeBone == false then return end

        model:SetupBones()

        local matrix = model:GetBoneMatrix(self.RangefinderScopeBone)
        local bonePos = matrix and matrix:GetTranslation() or model:GetBonePosition(self.RangefinderScopeBone)
        local boneAng = matrix and matrix:GetAngles() or select(2, model:GetBonePosition(self.RangefinderScopeBone))
        if not bonePos then return end
        self.RangefinderScopeBoneWorldPos = bonePos
        self.RangefinderScopeBoneWorldAng = boneAng

        local tracePos, traceAng = self:GetTrace(true, nil, nil, true)
        if not tracePos or not traceAng then return end

        local localPos = WorldToLocal(bonePos, rangefinderZeroAng, tracePos, traceAng)
        self.localScopePos = localPos
        self.RangefinderBoneScopePos = localPos
    end

    function SWEP:GetRangefinderScopeWorld()
        if not self.GetTrace then return end

        local tracePos, traceAng = self:GetTrace(true, nil, nil, true)
        if not tracePos or not traceAng then return end

        local localPos = self.localScopePos or Vector(0, 0, 0)
        local scopePos = Vector(localPos.x, localPos.y, localPos.z)
        scopePos:Rotate(traceAng)
        scopePos:Add(tracePos)

        return scopePos, traceAng
    end

    function SWEP:ApplyRangefinderRTMaterial()
        self.RangefinderLensMaterial = rangefinderRTMaterialPath
        self.mat = rangefinderRTMaterial

        rangefinderRTMaterial:SetTexture("$basetexture", rangefinderRT)
        rangefinderRTGlassMaterial:SetTexture("$basetexture", rangefinderGlassTexture)

        rangefinderRTMaterial:SetInt("$translucent", 1)
        rangefinderRTGlassMaterial:SetInt("$translucent", 1)
        rangefinderRTMaterial:SetFloat("$alpha", 1)
        rangefinderRTGlassMaterial:SetFloat("$alpha", 0)
        rangefinderRTMaterial:SetInt("$vertexcolor", 0)
        rangefinderRTGlassMaterial:SetInt("$vertexcolor", 0)
        rangefinderRTMaterial:SetInt("$vertexalpha", 0)
        rangefinderRTGlassMaterial:SetInt("$vertexalpha", 0)
        rangefinderRTMaterial:SetInt("$nocull", 1)
        rangefinderRTGlassMaterial:SetInt("$nocull", 1)
        rangefinderClearMaterial:SetFloat("$alpha", 0)
        rangefinderClearMaterial:SetInt("$ignorez", 1)

        local model = self:GetWM()
        if not IsValid(model) then return end

        self:ApplyRangefinderLensSubMaterials(model)
    end

    function SWEP:ClearRangefinderRTMaterial()
        rangefinderRTMaterial:SetTexture("$basetexture", rangefinderGlassTexture)
        rangefinderRTMaterial:SetFloat("$alpha", 0)
        rangefinderRTGlassMaterial:SetFloat("$alpha", 0)

        local model = self:GetWM()
        if not IsValid(model) then return end

        self:ClearRangefinderLensSubMaterials(model)
    end

    function SWEP:UpdateRangefinderRTMaterialState()
        if self:IsZoom() or (self.RangefinderRTDebug or 0) > 0 then
            self:ApplyRangefinderRTMaterial()
        else
            self:ClearRangefinderRTMaterial()
        end
    end

    local function RangefinderSetNoDraw(ent, state, restore)
        if not IsValid(ent) or not ent.GetNoDraw or not ent.SetNoDraw then return end

        restore[#restore + 1] = {ent, ent:GetNoDraw()}
        ent:SetNoDraw(state)
    end

    local function RangefinderRestoreNoDraw(restore)
        for i = #restore, 1, -1 do
            local entry = restore[i]
            if IsValid(entry[1]) then
                entry[1]:SetNoDraw(entry[2])
            end
        end
    end

    local function RangefinderSetMaterial(ent, material, restore)
        if not IsValid(ent) or not ent.GetMaterial or not ent.SetMaterial then return end

        restore[#restore + 1] = {ent, ent:GetMaterial()}
        ent:SetMaterial(material)
    end

    local function RangefinderRestoreMaterial(restore)
        for i = #restore, 1, -1 do
            local entry = restore[i]
            if IsValid(entry[1]) then
                entry[1]:SetMaterial(entry[2] or "")
            end
        end
    end

    hook.Add("PrePlayerDraw", "ZCityRangefinderHidePlayerInRT", function(ply)
        if IsValid(ply) and ply.RangefinderHideInRT then return true end
    end)

    local function RangefinderDrawFilledCircle(x, y, radius, segments, color)
        surface.SetMaterial(rangefinderWhiteMaterial)
        surface.SetDrawColor(color)

        for i = 0, segments - 1 do
            local a1 = math.pi * 2 * i / segments
            local a2 = math.pi * 2 * (i + 1) / segments

            surface.DrawPoly({
                {x = x, y = y},
                {x = x + math.cos(a1) * radius, y = y + math.sin(a1) * radius},
                {x = x + math.cos(a2) * radius, y = y + math.sin(a2) * radius}
            })
        end
    end

    function SWEP:GetRangefinderOpticOffset()
        local view = render.GetViewSetup(true) or {}
        local viewOrigin = view.origin or EyePos()
        local viewAngles = view.angles or EyeAngles()
        local center = self.RangefinderScopeBoneWorldPos or self:GetRangefinderScopeWorld()
        if not center then return 0, 0, 0 end

        local _, point = util.DistanceToLine(viewOrigin, viewOrigin + viewAngles:Forward() * 128, center)
        if not point then return 0, 0, 0 end

        local localOffset = WorldToLocal(point, rangefinderZeroAng, center, viewAngles)
        local right = -localOffset.y
        local up = localOffset.z
        local miss = math.sqrt(right * right + up * up)

        self.RangefinderLastOpticRight = right
        self.RangefinderLastOpticUp = up
        self.RangefinderLastOpticMiss = miss

        return right, up, miss
    end

    function SWEP:DrawRangefinderOpticShadow(size)
        if not self.RangefinderOpticShadow then return end

        local right, up, miss = self:GetRangefinderOpticOffset()
        local eyeBox = math.max(self.RangefinderOpticEyeBox or 0.28, 0.01)
        local blackout = math.max(self.RangefinderOpticBlackout or 0.95, eyeBox + 0.01)
        local amount = math.Clamp((miss - eyeBox * 0.2) / (blackout - eyeBox * 0.2), 0, 1)
        if amount <= 0 then return end

        local dirX = 0
        local dirY = 0
        if miss > 0.0001 then
            dirX = right / miss
            dirY = -up / miss
        end

        local scale = self.RangefinderOpticShadowScale or 1
        local center = size * 0.5
        local shadowTravel = size * 0.58 * scale
        local shadowX = center + dirX * shadowTravel * (1 - amount)
        local shadowY = center + dirY * shadowTravel * (1 - amount)
        local radius = size * (0.48 + amount * 0.30)
        local alpha = math.Clamp(amount * 245, 0, 245)

        RangefinderDrawFilledCircle(shadowX, shadowY, radius * 1.18, 48, Color(0, 0, 0, math.floor(alpha * 0.30)))
        RangefinderDrawFilledCircle(shadowX, shadowY, radius, 48, Color(0, 0, 0, math.floor(alpha * 0.55)))
        RangefinderDrawFilledCircle(shadowX, shadowY, radius * 0.72, 48, Color(0, 0, 0, math.floor(alpha * 0.35)))

        if amount > 0.82 then
            surface.SetDrawColor(0, 0, 0, math.Clamp((amount - 0.82) / 0.18 * 190, 0, 190))
            surface.DrawRect(0, 0, size, size)
        end
    end

    local function RangefinderDrawTexturedRectRotatedHuy(x, y, w, h, rot, offsetX, offsetY, rotHuy)
        rotHuy = rotHuy or 0
        local sinRot = math.sin(math.rad(rot))
        local cosRot = math.cos(math.rad(rot))
        local newX = x + offsetX * sinRot
        local newY = y + offsetX * cosRot

        newX = newX + offsetY * cosRot
        newY = newY - offsetY * sinRot

        surface.DrawTexturedRectRotated(newX, newY, w, h, rot + rotHuy)
    end

    function SWEP:BuildRangefinderZCityScopeData(view, scopePos, scopeAng, owner, debugMode)
        if not scopePos or not scopeAng then return end

        local viewOrigin = view.origin or owner:EyePos()
        local viewAngles = view.angles or owner:EyeAngles()
        local axisAngles = Angle(scopeAng.p, scopeAng.y, scopeAng.r)
        local axisDot = axisAngles:Forward():Dot(viewAngles:Forward())
        if axisDot < 0.35 then
            axisAngles = Angle(viewAngles.p, viewAngles.y, viewAngles.r)
        end

        local _, point = util.DistanceToLine(viewOrigin, viewOrigin + viewAngles:Forward() * 50, scopePos)
        point = point or scopePos

        local scopeLocal = WorldToLocal(point, rangefinderZeroAng, scopePos, viewAngles)
        local scopeBlackout = math.max(self.scope_blackout or 400, 1)
        local zoomFOV = math.max(self.ZoomFOV or 15, 0.5)
        local renderAngles = Angle(viewAngles.p, viewAngles.y, viewAngles.r)

        local dirToScope = scopePos - viewOrigin
        local distToScope = math.max(dirToScope:Length(), 1)
        dirToScope:Normalize()

        local renderOrigin = viewOrigin + viewAngles:Forward() * 2
        if self.RangefinderRTUseScopeOrigin or debugMode == 2 then
            renderOrigin = scopePos + scopeAng:Forward() * 4
        end

        local screenW = ScrW()
        local screenH = ScrH()
        local scr1 = scopePos:ToScreen()
        local scr2 = point:ToScreen()
        local screenSafe = scr1 and scr2
            and scr1.visible ~= false
            and scr2.visible ~= false
            and math.abs(scr1.x) < screenW * 8
            and math.abs(scr1.y) < screenH * 8
            and math.abs(scr2.x) < screenW * 8
            and math.abs(scr2.y) < screenH * 8

        local diffa
        if screenSafe then
            diffa = Vector((scr1.x - scr2.x) / screenW, (scr1.y - scr2.y) / screenH, 0)
            diffa.x = diffa.x * screenW * 2
            diffa.y = diffa.y * screenH * 2
        else
            local fallbackDivisor = math.max(self.RangefinderOpticFallbackDivisor or 4, 1)
            local fallbackScale = rangefinderRTSize / math.max(distToScope * fallbackDivisor, 1)
            diffa = Vector(-scopeLocal.y * fallbackScale, scopeLocal.z * fallbackScale, 0)
        end

        diffa.x = math.Clamp(diffa.x, -rangefinderRTSize, rangefinderRTSize)
        diffa.y = math.Clamp(diffa.y, -rangefinderRTSize, rangefinderRTSize)

        local diffLenSqr = diffa:LengthSqr()
        local allowed = diffLenSqr < 10000.0 * (rangefinderRTSize / 512) / (scopeBlackout / 400)
        local distMul = self.RangefinderOpticMaskDistMul or 1
        local rtAimX = rangefinderRTSize * 0.5
        local rtAimY = rangefinderRTSize * 0.5

        self.RangefinderLastOpticRight = diffa.x
        self.RangefinderLastOpticUp = diffa.y
        self.RangefinderLastOpticMiss = math.sqrt(diffLenSqr)
        self.RangefinderLastRTFOV = math.Clamp(zoomFOV / distToScope * 12, 1, 90)
        self.RangefinderLastRTAllowed = allowed
        self.RangefinderLastAxisDot = axisDot
        self.RangefinderLastScreenSafe = screenSafe

        return {
            origin = renderOrigin,
            angles = renderAngles,
            fov = self.RangefinderLastRTFOV,
            diffa = diffa,
            distMul = distMul,
            aimX = rtAimX,
            aimY = rtAimY,
            screenAimX = screenW * 0.5,
            screenAimY = screenH * 0.5,
            renderAllowed = allowed
        }
    end

    function SWEP:DrawRangefinderZCityScopeMask(size, scopeData)
        if not self.RangefinderOpticShadow or not scopeData then return end
        if not self.scopemat then return end

        local blackout = (self.blackoutsize or 2500) * 0.75
        local distMul = scopeData.distMul or 1
        local x = scopeData.aimX or size * 0.5
        local y = scopeData.aimY or size * 0.5
        local diffa = scopeData.diffa or vector_origin
        local maskScale = self.RangefinderOpticMaskScale or 1.35
        local shiftMul = self.RangefinderOpticMaskShift or 0.25
        local maskSizeOuter = (blackout * rangefinderRTSize / 512 * 2 + 512) * maskScale
        local maskSizeInner = (blackout * 0.75 * rangefinderRTSize / 512 + 512) * maskScale

        surface.SetMaterial(self.scopemat)
        surface.SetDrawColor(100, 100, 100, 255)
        RangefinderDrawTexturedRectRotatedHuy(
            0,
            0,
            maskSizeOuter,
            maskSizeOuter,
            0,
            (size - y - size / 2) * distMul + size / 2,
            (size - x - size / 2) * distMul + size / 2
        )

        surface.SetDrawColor(0, 0, 0, 255)

        RangefinderDrawTexturedRectRotatedHuy(
            0,
            0,
            maskSizeInner,
            maskSizeInner,
            0,
            -diffa.y * 2 * distMul * shiftMul + size / 2,
            -diffa.x * 2 * distMul * shiftMul + size / 2
        )
    end

    function SWEP:DrawRangefinderLensDisk()
        if not self:IsZoom() then return end
        if not self.RangefinderLensDiskEnabled then return end

        local view = render.GetViewSetup(true) or {}
        local viewOrigin = view.origin or EyePos()
        local viewAngles = view.angles or EyeAngles()
        local center = self.RangefinderScopeBoneWorldPos or self:GetRangefinderScopeWorld()
        if not center then return end

        local normal = (viewOrigin - center):GetNormalized()
        if normal:LengthSqr() < 0.0001 then normal = viewAngles:Forward() * -1 end

        local right = viewAngles:Right()
        local up = viewAngles:Up()
        local rot = math.rad(self.RangefinderLensDiskRotation or 0)
        if rot ~= 0 then
            local cosRot = math.cos(rot)
            local sinRot = math.sin(rot)
            local rotatedRight = right * cosRot + up * sinRot
            local rotatedUp = up * cosRot - right * sinRot
            right = rotatedRight
            up = rotatedUp
        end

        local radius = (self.RangefinderLensDiskSize or 1.65) * 0.5
        center = center
            + normal * (self.RangefinderLensDiskOffset or 0.04)
            + right * (self.RangefinderLensDiskRight or 0)
            + up * (self.RangefinderLensDiskUp or 0)

        rangefinderRTMaterial:SetTexture("$basetexture", rangefinderRT)
        render.SetMaterial(rangefinderRTMaterial)

        local segments = 48
        local ignoreDepth = self.RangefinderLensDiskIgnoreDepth ~= false
        if ignoreDepth then render.OverrideDepthEnable(true, false) end

        mesh.Begin(MATERIAL_TRIANGLES, segments)
            for i = 0, segments - 1 do
                local a1 = math.pi * 2 * i / segments
                local a2 = math.pi * 2 * (i + 1) / segments
                local p1 = center + right * math.cos(a1) * radius + up * math.sin(a1) * radius
                local p2 = center + right * math.cos(a2) * radius + up * math.sin(a2) * radius

                mesh.Position(center)
                mesh.TexCoord(0, 0.5, 0.5)
                mesh.Color(255, 255, 255, 255)
                mesh.AdvanceVertex()

                mesh.Position(p1)
                mesh.TexCoord(0, 0.5 + math.cos(a1) * 0.5, 0.5 - math.sin(a1) * 0.5)
                mesh.Color(255, 255, 255, 255)
                mesh.AdvanceVertex()

                mesh.Position(p2)
                mesh.TexCoord(0, 0.5 + math.cos(a2) * 0.5, 0.5 - math.sin(a2) * 0.5)
                mesh.Color(255, 255, 255, 255)
                mesh.AdvanceVertex()
            end
        mesh.End()

        if ignoreDepth then render.OverrideDepthEnable(false, false) end
    end

    function SWEP:DrawRangefinderRTOverlay(size, centerX, centerY)
        local center = size * 0.5
        centerX = centerX or center
        centerY = centerY or center
        local red = Color(255, 20, 20, 235)
        local redDim = Color(255, 20, 20, 155)

        local gap = 4
        local len = 16
        local thick = 2

        surface.SetDrawColor(red)
        surface.DrawRect(centerX - gap - len, centerY - thick * 0.5, len, thick)
        surface.DrawRect(centerX + gap, centerY - thick * 0.5, len, thick)
        surface.DrawRect(centerX - thick * 0.5, centerY - gap - len, thick, len)
        surface.DrawRect(centerX - thick * 0.5, centerY + gap, thick, len)
        surface.DrawRect(centerX - 1, centerY - 1, 2, 2)

        local hasDist = self:GetNWBool("HasDistance", false)
        local compDist = self:GetNWFloat("CompensatedDistance", 0)
        local measDist = self:GetNWFloat("MeasuredDistance", 0)
        local measAngle = self:GetNWFloat("MeasuredAngle", 0)

        local owner = self:GetOwner()
        local liveAngle = 0
        if IsValid(owner) then
            liveAngle = -owner:EyeAngles().p
        end

        -- 1. Main Compensated Distance (Horizontal Range)
        local mainText = hasDist and string.format("%.1f m", compDist) or "---.- m"
        draw.SimpleText(mainText, "ZCity_Rangefinder_RT", centerX, centerY - 85, red, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        
        -- HD Mode Label (using ZCity_Rangefinder_RT_Medium for medium size)
        draw.SimpleText("HD", "ZCity_Rangefinder_RT_Medium", centerX, centerY - 120, redDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

        -- 2. Secondary Metrics (Left Side): Line of Sight (LOS) and Inclination Angle (ANG)
        local losText = hasDist and string.format("LOS: %.1f m", measDist) or "LOS: ---.- m"
        local angVal = hasDist and measAngle or liveAngle
        local angText = string.format("ANG: %.1f", angVal)
        
        draw.SimpleText(losText, "ZCity_Rangefinder_RT_Medium", centerX - 75, centerY - 32, red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        draw.SimpleText(angText, "ZCity_Rangefinder_RT_Medium", centerX - 75, centerY - 12, red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        DrawDegreeSymbol(centerX - 75, centerY - 12, "ZCity_Rangefinder_RT_Medium", red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, angText)

        -- 3. StormFox Wind Info (Right Side)
        local hasWind = false
        local windSpeed = 0
        local windYaw = 0
        if StormFox2 and StormFox2.Wind and StormFox2.Wind.GetForce and StormFox2.Wind.GetYaw then
            hasWind = true
            windSpeed = StormFox2.Wind.GetForce()
            windYaw = StormFox2.Wind.GetYaw()
        elseif StormFox and StormFox.GetWindSpeed and StormFox.GetWindYaw then
            hasWind = true
            windSpeed = StormFox.GetWindSpeed()
            windYaw = StormFox.GetWindYaw()
        end

        if hasWind then
            local wndText = string.format("WND: %.1f m/s", windSpeed)
            draw.SimpleText(wndText, "ZCity_Rangefinder_RT_Medium", centerX + 75, centerY - 32, red, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
            
            local playerYaw = IsValid(owner) and owner:EyeAngles().y or 0
            local arrowRotation = playerYaw - windYaw
            
            -- Measure text width to place the arrow next to it
            surface.SetFont("ZCity_Rangefinder_RT_Medium")
            local tw, th = surface.GetTextSize(wndText)
            DrawWindArrow(centerX + 75 + tw + 12, centerY - 32 - th * 0.5, arrowRotation, 1.3, red)
        end

        -- 4. Status Indicators (Bottom Left and Right)
        draw.SimpleText("BATT 98%", "ZCity_Rangefinder_RT_Small", centerX - 42, centerY + 22, redDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local lsrColor = math.sin(CurTime() * 10) > 0 and red or Color(120, 10, 10, 120)
        draw.SimpleText("LSR", "ZCity_Rangefinder_RT_Small", centerX + 42, centerY + 22, lsrColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    function SWEP:DrawRangefinderRTTest(size)
        surface.SetDrawColor(5, 18, 12, 255)
        surface.DrawRect(0, 0, size, size)

        surface.SetDrawColor(255, 0, 0, 255)
        surface.DrawOutlinedRect(4, 4, size - 8, size - 8, 4)
        surface.DrawLine(0, 0, size, size)
        surface.DrawLine(size, 0, 0, size)

        draw.SimpleText("RT OK", "ZCity_Rangefinder_RT", size * 0.5, size * 0.5 - 18, Color(255, 20, 20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("MATERIAL TEST", "ZCity_Rangefinder_RT_Small", size * 0.5, size * 0.5 + 24, Color(255, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    function SWEP:DoRT()
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        self.isscoping = true
        self:UpdateRangefinderScopePos()
        self:ApplyRangefinderRTMaterial()

        local view = render.GetViewSetup(true) or {}
        local debugMode = self.RangefinderRTDebug or 0
        local scopePos, scopeAng = self:GetRangefinderScopeWorld()
        if not scopePos or not scopeAng then return end

        local scopeData = self:BuildRangefinderZCityScopeData(view, scopePos, scopeAng, owner, debugMode)
        if not scopeData then return end

        local rtView = {
            x = 0,
            y = 0,
            w = rangefinderRTSize,
            h = rangefinderRTSize,
            origin = scopeData.origin,
            angles = scopeData.angles,
            fov = scopeData.fov,
            znear = 1,
            zfar = 32768,
            drawviewmodel = false,
            drawhud = false,
            bloomtone = false
        }

        render.PushRenderTarget(rangefinderRT, 0, 0, rangefinderRTSize, rangefinderRTSize)

        local oldClip = DisableClipping(true)
        local oldOwnerNoRender = owner.norender
        local oldOwnerShouldTransmit = owner.shouldTransmit
        local oldOwnerRangefinderHide = owner.RangefinderHideInRT
        local hidden = {}
        local hiddenMaterials = {}

        owner.norender = true
        owner.shouldTransmit = false
        owner.RangefinderHideInRT = true
        RangefinderSetNoDraw(owner, true, hidden)
        RangefinderSetNoDraw(owner.FakeRagdoll, true, hidden)
        RangefinderSetNoDraw(owner.c_hands, true, hidden)
        RangefinderSetNoDraw(owner.flmodel, true, hidden)
        RangefinderSetNoDraw(owner.OwOmodel, true, hidden)
        RangefinderSetNoDraw(self:GetWM(), true, hidden)
        RangefinderSetMaterial(owner, "NULL", hiddenMaterials)
        RangefinderSetMaterial(owner.FakeRagdoll, "NULL", hiddenMaterials)
        RangefinderSetMaterial(owner.c_hands, "NULL", hiddenMaterials)
        RangefinderSetMaterial(owner.flmodel, "NULL", hiddenMaterials)
        RangefinderSetMaterial(owner.OwOmodel, "NULL", hiddenMaterials)

        RENDERING_SCOPE = self

        render.Clear(1, 1, 1, 255, true, true)

        if debugMode ~= 1 then
            if scopeData.renderAllowed then
                render.RenderView(rtView)
            end
        end

        cam.Start2D()
            if debugMode == 1 then
                self:DrawRangefinderRTTest(rangefinderRTSize)
            elseif scopeData.renderAllowed then
                self:DrawRangefinderZCityScopeMask(rangefinderRTSize, scopeData)
                self:DrawRangefinderRTOverlay(rangefinderRTSize, scopeData.aimX, scopeData.aimY)
            end
        cam.End2D()

        RENDERING_SCOPE = false
        owner.norender = oldOwnerNoRender
        owner.shouldTransmit = oldOwnerShouldTransmit
        owner.RangefinderHideInRT = oldOwnerRangefinderHide
        RangefinderRestoreMaterial(hiddenMaterials)
        RangefinderRestoreNoDraw(hidden)
        DisableClipping(oldClip)
        render.PopRenderTarget()
    end

    function SWEP:UpdateRangefinderSightAnim(zoom)
        if self.RangefinderWasZoom == zoom then return end
        if not IsValid(self:GetWM()) or not self.PlayAnim then return end

        if self.RangefinderWasZoom == nil then
            self.RangefinderWasZoom = zoom
            if zoom then
                self:PlayAnim("idle_sights", 1, true)
            end
            return
        end

        self.RangefinderWasZoom = zoom
        self.RangefinderSightAnimToken = (self.RangefinderSightAnimToken or 0) + 1

        local token = self.RangefinderSightAnimToken
        local animTime = self.RangefinderSightAnimTime or 0.22
        self:PlayAnim(zoom and "ironsight_in" or "ironsight_out", animTime, false)

        timer.Simple(animTime, function()
            if not IsValid(self) or self.RangefinderSightAnimToken ~= token or not self.PlayAnim then return end

            if self:IsZoom() then
                self:PlayAnim("idle_sights", 1, true)
            else
                self:PlayAnim("idle", 1, true)
            end
        end)
    end

    -- Render custom reticle and distance readout inside the RT scope view
    function SWEP:SightDrawFunc()
        -- Calculate reticle offset with realistic parallax
        local pos, ang = self:GetTrace(true, nil, nil, true)
        local aimWay = ang:Forward() * 1e9
        local toscreen = aimWay:ToScreen()
        local x, y = toscreen.x, toscreen.y
        
        local scrw, scrh = ScrW(), ScrH()
        local offsetX = y / (scrh / ScrH())
        local offsetY = x / (scrw / ScrW())
        local rot = self.rot or 0
        
        -- Exact coordinate math matching homigrad_base's scope offset
        local newX = offsetX * math.sin(math.rad(rot)) + offsetY * math.cos(math.rad(rot))
        local newY = offsetX * math.cos(math.rad(rot)) - offsetY * math.sin(math.rad(rot))

        local red = Color(255, 0, 0, 240)
        local redDim = Color(255, 0, 0, 150)

        -- 1. Red crosshair lines
        local gap = 4
        local len = 16
        local thick = 2
        surface.SetDrawColor(red)
        -- Left
        surface.DrawRect(newX - gap - len, newY - thick / 2, len, thick)
        -- Right
        surface.DrawRect(newX + gap, newY - thick / 2, len, thick)
        -- Top
        surface.DrawRect(newX - thick / 2, newY - gap - len, thick, len)
        -- Bottom
        surface.DrawRect(newX - thick / 2, newY + gap, thick, len)
        -- Center dot
        surface.DrawRect(newX - 1, newY - 1, 2, 2)

        local hasDist = self:GetNWBool("HasDistance", false)
        local compDist = self:GetNWFloat("CompensatedDistance", 0)
        local measDist = self:GetNWFloat("MeasuredDistance", 0)
        local measAngle = self:GetNWFloat("MeasuredAngle", 0)

        local owner = self:GetOwner()
        local liveAngle = 0
        if IsValid(owner) then
            liveAngle = -owner:EyeAngles().p
        end

        -- 2. Main Compensated Distance (Horizontal Range)
        local mainText = hasDist and string.format("%.1f m", compDist) or "---.- m"
        draw.SimpleText(mainText, "ZCity_Rangefinder_Digital", newX, newY - 85, red, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        
        -- HD Mode Label (using ZCity_Rangefinder_Digital_Medium)
        draw.SimpleText("HD", "ZCity_Rangefinder_Digital_Medium", newX, newY - 120, redDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

        -- 3. Secondary Metrics (Left Side): Line of Sight (LOS) and Inclination Angle (ANG)
        local losText = hasDist and string.format("LOS: %.1f m", measDist) or "LOS: ---.- m"
        local angVal = hasDist and measAngle or liveAngle
        local angText = string.format("ANG: %.1f", angVal)
        
        draw.SimpleText(losText, "ZCity_Rangefinder_Digital_Medium", newX - 75, newY - 32, red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        draw.SimpleText(angText, "ZCity_Rangefinder_Digital_Medium", newX - 75, newY - 12, red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        DrawDegreeSymbol(newX - 75, newY - 12, "ZCity_Rangefinder_Digital_Medium", red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, angText)

        -- 4. StormFox Wind Info (Right Side)
        local hasWind = false
        local windSpeed = 0
        local windYaw = 0
        if StormFox2 and StormFox2.Wind and StormFox2.Wind.GetForce and StormFox2.Wind.GetYaw then
            hasWind = true
            windSpeed = StormFox2.Wind.GetForce()
            windYaw = StormFox2.Wind.GetYaw()
        elseif StormFox and StormFox.GetWindSpeed and StormFox.GetWindYaw then
            hasWind = true
            windSpeed = StormFox.GetWindSpeed()
            windYaw = StormFox.GetWindYaw()
        end

        if hasWind then
            local wndText = string.format("WND: %.1f m/s", windSpeed)
            draw.SimpleText(wndText, "ZCity_Rangefinder_Digital_Medium", newX + 75, newY - 32, red, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
            
            local playerYaw = IsValid(owner) and owner:EyeAngles().y or 0
            local arrowRotation = playerYaw - windYaw
            
            -- Measure text width to place the arrow next to it
            surface.SetFont("ZCity_Rangefinder_Digital_Medium")
            local tw, th = surface.GetTextSize(wndText)
            
            -- We pass ScreenScale(1.3) to scale the wind arrow properly matching the medium text size
            DrawWindArrow(newX + 75 + tw + 12, newY - 32 - th * 0.5, arrowRotation, ScreenScale(1.3), red)
        end

        -- 5. Ambient display metrics (Bottom)
        draw.SimpleText("BATT 98%", "ZCity_Rangefinder_Digital_Small", newX - 45, newY + 25, redDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        
        local isBlinking = math.sin(CurTime() * 10) > 0
        local lsrColor = isBlinking and red or Color(100, 0, 0, 100)
        draw.SimpleText("LSR", "ZCity_Rangefinder_Digital_Small", newX + 45, newY + 25, lsrColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    -- Override default DrawHUD to prevent the "BulletSettings" nil-indexing crash
    function SWEP:DrawHUD()
        if not IsValid(self:GetOwner()) then return end
        self.isscoping = false
        self:ChangeFOV()
        self:DrawHUDAdd()
        self:UpdateRangefinderScopePos()

        if self.dort and (self:IsZoom() or (self.RangefinderRTDebug or 0) > 0) then
            self:DoRT()

            local view = render.GetViewSetup(true) or {}
            cam.Start3D(view.origin or EyePos(), view.angles or EyeAngles(), view.fov)
                self:DrawRangefinderLensDisk()
            cam.End3D()
        else
            self:ClearRangefinderRTMaterial()
        end
    end

    hook.Add("radialOptions", "zz_zcity_rangefinder_radial", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "weapon_zcity_rangefinder" and hg and hg.radialOptions then
            for i = #hg.radialOptions, 1, -1 do
                local option = hg.radialOptions[i]
                if option and option[2] == "Weapon Menu" then
                    table.remove(hg.radialOptions, i)
                end
            end
        end
    end)

    include("zcity_rangefinder/cl_dev.lua")

end
