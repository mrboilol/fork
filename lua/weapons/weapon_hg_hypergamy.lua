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
	local normal, right = axes[thin], axes[a]
	if normal.z < 0 then
		normal = -normal
		right = -right
	end
	local center = ent:LocalToWorld((mins + maxs) * 0.5) + normal * (size[thin] * 0.5 + 0.05)

	return center, normal, right, axes[b], size[a], size[b]
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
	local BOARD = 13
	local THICK = 0.6
	local INSET = 0.8

	local imageMat = Material("hypogamy.png", "smooth mips nocull")
	local boardMat = CreateMaterial("hg_hypergamy_board", "UnlitGeneric", {
		["$basetexture"] = "color/white",
		["$vertexcolor"] = 1,
		["$nocull"] = 1,
	})

	local faceTint = Vector(0.66, 0.5, 0.32)
	local edgeTint = Vector(0.5, 0.37, 0.22)
	local imageTint = Vector(1, 1, 1)
	local light = Vector(1, 1, 1)
	local quadCol = Color(255, 255, 255)

	local function quad(mat, center, a, b, tint)
		quadCol.r = 255 * light.x * tint.x
		quadCol.g = 255 * light.y * tint.y
		quadCol.b = 255 * light.z * tint.z
		render.SetMaterial(mat)
		render.DrawQuad(center - a + b, center + a + b, center + a - b, center - a - b, quadCol)
	end

	local function drawBoard(center, right, up, normal)
		local raw = render.GetLightColor(center)
		light:SetUnpacked(math.Clamp(raw.x ^ 0.4545, 0.2, 1), math.Clamp(raw.y ^ 0.4545, 0.2, 1), math.Clamp(raw.z ^ 0.4545, 0.2, 1))

		local r, u, n = right * (BOARD * 0.5), up * (BOARD * 0.5), normal * (THICK * 0.5)
		quad(boardMat, center + n, r, u, faceTint)
		quad(boardMat, center - n, r, u, faceTint)
		quad(boardMat, center + u, r, n, edgeTint)
		quad(boardMat, center - u, r, n, edgeTint)
		quad(boardMat, center + r, n, u, edgeTint)
		quad(boardMat, center - r, n, u, edgeTint)

		local ih = BOARD * 0.9
		quad(imageMat, center + normal * (THICK * 0.5 + 0.04), right * (ih * 0.5 / IMG_ASPECT), up * (ih * 0.5), imageTint)
	end

	local function bonePos(ent, name)
		local bone = ent:LookupBone(name)
		local mat = bone and ent:GetBoneMatrix(bone)

		return mat and mat:GetTranslation()
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

	function SWEP:BoardFrame()
		local owner = self:GetOwner()
		local wm = self.worldModel
		if not IsValid(owner) or not IsValid(wm) or wm:GetModel() ~= self.WorldModelReal then return end

		local lp = bonePos(wm, "ValveBiped.Bip01_L_Finger2") or bonePos(wm, "ValveBiped.Bip01_L_Hand")
		local rp = bonePos(wm, "ValveBiped.Bip01_R_Finger2") or bonePos(wm, "ValveBiped.Bip01_R_Hand")
		if not lp or not rp then return end

		local across = rp - lp
		across:Normalize()

		local fwd = owner:EyeAngles():Forward()
		local n0 = across * fwd:Dot(across) - fwd
		n0:Normalize()
		local up = n0:Cross(across)

		local theta = math.pi * math.ease.InOutSine(self:UpdateShowLerp())
		local c, s = math.cos(theta), math.sin(theta)

		return (lp + rp) * 0.5 - n0 * 0.5, across * c - n0 * s, up, n0 * c + across * s, c
	end

	local function gripHand(ent, hand, finger, target, weight)
		local bone = ent:LookupBone(hand)
		local mat = bone and ent:GetBoneMatrix(bone)
		local grip = bonePos(ent, finger)
		if not mat or not grip then return end

		mat:SetTranslation(mat:GetTranslation() + (target - grip) * weight)
		hg.bone_apply_matrix(ent, bone, mat)
	end

	function SWEP:PostSetHandPos()
		local ply = self:GetOwner()
		if not IsValid(ply) then return end

		local ent = hg.GetTPIKCharacter(ply)
		if not IsValid(ent) then return end
		if not (ent == ply or hg.KeyDown(ply, IN_USE) or ply:GetNetVar("lastFake", 0) > CurTime()) then return end

		local center, right, _, _, c = self:BoardFrame()
		if not center then return end

		local edge = right * ((BOARD * 0.5 - INSET) * (c >= 0 and 1 or -1))
		local weight = math.abs(c)

		if self.lhandik and hg.CanUseLeftHand(ply) then
			gripHand(ent, "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_L_Finger2", center - edge, weight)
		end
		if self.rhandik and hg.CanUseRightHand(ply) then
			gripHand(ent, "ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Finger2", center + edge, weight)
		end
	end

	function SWEP:DrawPostWorldModel()
		if not IsValid(self:GetOwner()) then
			local center, normal, right, up = flatFrame(self)
			drawBoard(center + normal * (THICK * 0.5), right, up, normal)

			return
		end

		local center, right, up, normal = self:BoardFrame()
		if center then drawBoard(center, right, up, normal) end
	end
end
