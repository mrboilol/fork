if SERVER then
	AddCSLuaFile()
	resource.AddSingleFile("materials/hypogamy.png")
end

SWEP.Base = "weapon_tpik_base"
SWEP.PrintName = "hypergamy"
SWEP.Category = "ZCity Other"
SWEP.Instructions = "cant escape hypergamy"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 4
SWEP.SlotPos = 5

SWEP.WorldModel = "models/props_c17/paper01.mdl"
SWEP.WorldModelReal = "models/mmod/weapons/c_slam.mdl"
SWEP.WorldModelExchange = false
SWEP.ViewModel = ""
SWEP.HoldType = "slam"
SWEP.HideMeshBones = {"Slam_base", "Slam_panel", "Detonator"}

SWEP.HoldPos = Vector(-6, 0, -2)
SWEP.HoldAng = Angle(-5, 0, 0)
SWEP.ShowPos = Vector(6, 0, 5)

SWEP.setlh = true
SWEP.setrh = true

SWEP.AnimList = {
	["deploy"] = {"tripmine_draw", 1, false, false, function(self)
		if SERVER then self:PlayAnim("idle") end
	end},
	["idle"] = {"tripmine_idle", 1, true},
}

SWEP.DeploySnd = "physics/cardboard/cardboard_box_impact_soft1.wav"

if CLIENT then
	SWEP.WepSelectIcon = Material("hypogamy.png", "smooth")
	SWEP.IconOverride = "hypogamy.png"
	SWEP.BounceWeaponIcon = false
end

local IMG_W, IMG_H = 828, 979
local IMG_ASPECT = IMG_H / IMG_W

local function flatFrame(ent)
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local size = maxs - mins
	local ang = ent:GetAngles()
	local axes = {ang:Forward(), -ang:Right(), ang:Up()}
	local thin = (size.x <= size.y and size.x <= size.z) and 1 or (size.y <= size.z and 2 or 3)
	local a, b = thin % 3 + 1, (thin + 1) % 3 + 1
	local normal = axes[thin]
	local center = ent:LocalToWorld((mins + maxs) * 0.5) + normal * (size[thin] * 0.5 + 0.05)

	return center, normal, axes[a], axes[b], size[a], size[b]
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Showing")
end

function SWEP:InitAdd()
	self:SetHold(self.HoldType)
end

function SWEP:ThinkAdd()
	if CLIENT then return end

	local owner = self:GetOwner()
	local showing = IsValid(owner) and owner:KeyDown(IN_ATTACK) or false
	if self:GetShowing() ~= showing then self:SetShowing(showing) end
end

function SWEP:Holster()
	if SERVER then self:SetShowing(false) end

	return true
end

if SERVER then
	local CHECK_INTERVAL = 0.25
	local VIEW_DIST = 500
	local VIEW_DOT = 0.6
	local FACE_DOT = 0.15
	local DEPRESSION_RATE = 0.08

	local function imageFace(wep)
		local owner = wep:GetOwner()
		if not IsValid(owner) then
			local center, normal = flatFrame(wep)

			return center, normal
		end
		if not owner:IsPlayer() or owner:GetActiveWeapon() ~= wep then return end

		local showing = wep:GetShowing()
		local eyeAng = owner:EyeAngles()
		local fwd = eyeAng:Forward()
		local center = owner:EyePos() + fwd * (showing and 22 or 16) - eyeAng:Up() * (showing and 2 or 6)

		return center, showing and fwd or -fwd, owner
	end

	local function depressViewers(wep)
		if not hg.organism or not hg.organism.AddDepression then return end

		local center, normal, owner = imageFace(wep)
		if not center then return end

		for _, ply in player.Iterator() do
			if not ply:Alive() then continue end

			local org = ply.organism
			if not org or not org.alive or org.otrub then continue end

			local eye = ply:EyePos()
			local toEye = eye - center
			local dist = toEye:Length()
			if dist > VIEW_DIST or dist < 1 then continue end

			toEye:Div(dist)
			if toEye:Dot(normal) < FACE_DOT then continue end
			if ply:GetAimVector():Dot(-toEye) < VIEW_DOT then continue end

			local filter = {ply, wep}
			if IsValid(ply.FakeRagdoll) then filter[#filter + 1] = ply.FakeRagdoll end
			if IsValid(owner) then
				filter[#filter + 1] = owner
				if IsValid(owner.FakeRagdoll) then filter[#filter + 1] = owner.FakeRagdoll end
			end

			local tr = util.TraceLine({
				start = eye,
				endpos = center,
				filter = filter,
				mask = MASK_VISIBLE,
			})
			if tr.Hit then continue end

			hg.organism.AddDepression(org, DEPRESSION_RATE * CHECK_INTERVAL * Lerp(dist / VIEW_DIST, 1, 0.35))
		end
	end

	local nextCheck = 0
	hook.Add("Think", "hg_hypergamy_drawing", function()
		local now = CurTime()
		if now < nextCheck then return end
		nextCheck = now + CHECK_INTERVAL

		for _, wep in ipairs(ents.FindByClass("weapon_hg_hypergamy")) do
			depressViewers(wep)
		end
	end)
end

if CLIENT then
	local paperMat = Material("hypogamy.png", "smooth mips")
	local paperColor = Color(255, 255, 255)
	local backColor = Color(240, 240, 235)

	local function litColor(base, pos, normal)
		local light = render.ComputeLighting(pos, normal)
		local r = math.Clamp(light.x, 0.08, 1)
		local g = math.Clamp(light.y, 0.08, 1)
		local b = math.Clamp(light.z, 0.08, 1)

		return base.r * r, base.g * g, base.b * b
	end

	local function sheetAngle(right, up, normal)
		local m = Matrix()
		m:SetForward(right)
		m:SetRight(-up)
		m:SetUp(normal)

		return m:GetAngles()
	end

	local function drawSheet(center, right, up, normal, w, h, back)
		local r, g, b = litColor(paperColor, center, normal)
		cam.Start3D2D(center - right * (w * 0.5) + up * (h * 0.5) + normal * 0.05, sheetAngle(right, up, normal), w / IMG_W)
			surface.SetDrawColor(r, g, b, 255)
			surface.SetMaterial(paperMat)
			surface.DrawTexturedRect(0, 0, IMG_W, IMG_W * h / w)
		cam.End3D2D()

		if not back then return end

		r, g, b = litColor(backColor, center, -normal)
		cam.Start3D2D(center + right * (w * 0.5) + up * (h * 0.5) - normal * 0.05, sheetAngle(-right, up, -normal), w / IMG_W)
			surface.SetDrawColor(r, g, b, 255)
			draw.NoTexture()
			surface.DrawRect(0, 0, IMG_W, IMG_W * h / w)
		cam.End3D2D()
	end

	function SWEP:UpdateShowLerp()
		if self.showLerpFrame == FrameNumber() then return self.showLerp or 0 end
		self.showLerpFrame = FrameNumber()
		self.showLerp = math.Approach(self.showLerp or 0, self:GetShowing() and 1 or 0, FrameTime() * 4)

		return self.showLerp
	end

	function SWEP:GetTPIKHoldPos(holdPos)
		return holdPos + self.ShowPos * math.ease.InOutSine(self:UpdateShowLerp())
	end

	local function gripPos(wm, finger, hand)
		local bone = wm:LookupBone(finger) or wm:LookupBone(hand)
		local mat = bone and wm:GetBoneMatrix(bone)

		return mat and mat:GetTranslation()
	end

	function SWEP:DrawPostWorldModel()
		local owner = self:GetOwner()

		if not IsValid(owner) then
			local center, normal, right, up, sw, sh = flatFrame(self)
			local w = math.min(sw, sh / IMG_ASPECT)
			drawSheet(center, right, up, normal, w, w * IMG_ASPECT)

			return
		end

		local wm = self.worldModel
		if not IsValid(wm) or wm:GetModel() ~= self.WorldModelReal then return end

		local lp = gripPos(wm, "ValveBiped.Bip01_L_Finger2", "ValveBiped.Bip01_L_Hand")
		local rp = gripPos(wm, "ValveBiped.Bip01_R_Finger2", "ValveBiped.Bip01_R_Hand")
		if not lp or not rp then return end

		local across = rp - lp
		local w = math.Clamp(across:Length() + 2, 9, 14)
		across:Normalize()

		local fwd = owner:EyeAngles():Forward()
		local n0 = -(fwd - across * fwd:Dot(across))
		n0:Normalize()
		local u = n0:Cross(across)

		local theta = math.pi * math.ease.InOutSine(self:UpdateShowLerp())
		local c, s = math.cos(theta), math.sin(theta)
		local normal = n0 * c + across * s
		local right = across * c - n0 * s

		local center = (lp + rp) * 0.5 + u * 2
		drawSheet(center, right, u, normal, w, w * IMG_ASPECT, true)
	end
end
