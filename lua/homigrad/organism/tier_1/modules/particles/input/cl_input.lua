local mats = {}
for i = 1, 6 do
	mats[i] = CreateMaterial( "blood_particle0"..i, "Sprite", {
		["$translucent"] = 1,
		["$vertexalpha"] = 1,
		["$vertexcolor"] = 1
	} )
	mats[i]:SetTexture("$basetexture",Material("decals/blood" .. i):GetTexture("$basetexture"))
end

--local mat_huy = Material("sprites/mat_jack_irregularcircle")
local texture = Material("decals/z_blood1"):GetTexture("$basetexture")
local mat_huy = Material("effects/blood_core")
mat_huy:SetTexture("$basetexture",texture)

local cloudmat = Material("effects/smoke_b")
local vomitColorPrimary = Color(229, 220, 148, 140)
local vomitColorSecondary = Color(238, 235, 210, 130)

--оставь это лучше выглядит
--[[for i = 4, 6 do
	mats[i-3] = Material("homigrad/decals/bld" .. i)
end]]
local countmats = #mats
hg.bloodparticles1 = hg.bloodparticles1 or {}
hg.bloodparticles2 = hg.bloodparticles2 or {}
local vecZero = Vector(0, 0, 0)
local lastplaced = SysTime()
local hg_blood_fps = ConVarExists("hg_blood_fps") and GetConVar("hg_blood_fps") or CreateClientConVar("hg_blood_fps", 24, true, nil, "fps to draw blood", 12, 165)
local function addBloodPart(pos, vel, mat, w, h, artery, kishki, owner)
	--local fps = 1 / hg_blood_fps:GetInt() * 1
	--if lastplaced + fps > SysTime() then return end
	--lastplaced = SysTime()
	if LocalPlayer():GetNetVar("disappearance", nil) or (IsValid(owner) and owner:GetNetVar("disappearance", nil)) then return end

	pos = pos + vecZero
	vel = vel + vecZero

	local pos2 = Vector()
	pos2:Set(pos)

	local maxDrops = math.Clamp((hg_blood_fps:GetInt() or 24) * 14, 220, 900)
	if #hg.bloodparticles1 > maxDrops then table.remove(hg.bloodparticles1, 1) end
	
	hg.bloodparticles1[#hg.bloodparticles1 + 1] = {pos, pos2, vel, mat or mat_huy, w or 2, h or 2, CurTime(), artery = artery, kishki = kishki, owner = owner, start_velocity = IsValid(owner) and owner:GetVelocity() or vector_origin}
end

local function addBloodPart2(pos, vel, mat, w, h, time, water, owner)
	if LocalPlayer():GetNetVar("disappearance", nil) or (IsValid(owner) and owner:GetNetVar("disappearance", nil)) then return end

	time = time or 30

	pos = pos + vecZero
	vel = vel + vecZero

	local pos2 = Vector()
	pos2:Set(pos)
	
	local maxClouds = math.Clamp((hg_blood_fps:GetInt() or 24) * 120, 2500, 7000)
	if #hg.bloodparticles2 > maxClouds then table.remove(hg.bloodparticles2, 1) end
	--if water and math.random(2) == 1 then return end
	--if water and math.random(3) > 1 then return end

	hg.bloodparticles2[#hg.bloodparticles2 + 1] = {pos, pos2, vel, mat or cloudmat, w or 60, h or 60, CurTime() + time, time, water = water, owner = owner}
end

hg.addBloodPart = addBloodPart
hg.addBloodPart2 = addBloodPart2

local Rand = math.Rand

local hg_bloodimpacts = ConVarExists("hg_bloodimpacts") and GetConVar("hg_bloodimpacts") or CreateConVar("hg_bloodimpacts", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable custom blood impact effects spray cool kill death", 0, 1)
local bloodImpactCloudSize = 16
local bloodImpactParticleSize = 0.75

local function impact(pos,vel,mul)
	local max = math.min(mul,8)
	local iters = math.ceil(math.random(1, max) * 2.5)
	local velnorm = -vel:GetNormalized() * 5
	
	if hg_bloodimpacts:GetBool() then
		addBloodPart2(pos + velnorm, -vel + Vector(Rand(-10, 10), Rand(-10, 10), Rand(-10, 10)) * 5, nil, bloodImpactCloudSize, bloodImpactCloudSize, 0.3)
		addBloodPart2(pos + velnorm, -vel / 2 + Vector(Rand(-10, 10), Rand(-10, 10), Rand(-10, 10)) * 5, nil, bloodImpactCloudSize, bloodImpactCloudSize, 0.3)
		addBloodPart2(pos + velnorm, -vel / 3 + Vector(Rand(-10, 10), Rand(-10, 10), Rand(-10, 10)) * 5, nil, bloodImpactCloudSize, bloodImpactCloudSize, 0.3)
	end

	for i = 1, iters do
		local size = bloodImpactParticleSize
		addBloodPart(pos, -vel * i / iters + Vector(Rand(-20, 20), Rand(-20, 20), 0), mat_huy, size, size, false, false)
	end
end

net.Receive("hg_bloodimpact", function()
	local pos = net.ReadVector()
	local vel = net.ReadVector() * 500
	local mul = net.ReadFloat()
	local amt = net.ReadInt(8)
	amt = math.Clamp(amt,0,32)
	//debugoverlay.Line(pos, vel, 5, color_white)
		
	local owner = nil
	for _, v in ipairs(ents.FindInSphere(pos, 40)) do
		if v:IsPlayer() or v:IsNPC() or v:IsNextBot() or v:IsRagdoll() then 
			owner = v 
			break 
		end
	end
	for i = 1, amt do impact(pos,vel,mul,owner) end
end)
	net.Receive("hg_brainmist", function()
	local ent = net.ReadEntity()
	local pos = net.ReadVector()
	local ang = net.ReadAngle()
	local headshot = net.ReadBool()
	local club = net.ReadBool()
	local redmist = net.ReadBool()
	local renderEnt = IsValid(ent) and (hg.GetCurrentCharacter and hg.GetCurrentCharacter(ent) or ent) or nil
	if IsValid(renderEnt) and renderEnt:LookupBone("ValveBiped.Bip01_Head1") then
		local bone = renderEnt:LookupBone("ValveBiped.Bip01_Head1")
		local headpos, headang = renderEnt:GetBonePosition(bone)
		if headpos and (renderEnt:IsRagdoll() or headpos:DistToSqr(pos) <= 40000) then
			pos = headpos
			ang = headang
		end
	end
	if headshot and not redmist then
		ParticleEffect("headshot", pos, ang)
	end
	if redmist then
		for i = 1, math.random(1, 2) do
			hg.addBloodPart2(pos + VectorRand(-1.5, 1.5), VectorRand(-18, 18) + ang:Forward() * -8, nil, Rand(6, 10), Rand(6, 10), Rand(0.25, 0.4), true, renderEnt or ent)
		end
	end
	if club then
		local spitColor = Color(210, 230, 235, 110)
		hg.addBloodPart2(pos + VectorRand(-1, 1), ang:Forward() * -90 + VectorRand(-10, 10), nil, Rand(8, 12), Rand(8, 12), 0.25, false, renderEnt or ent, spitColor)
		hg.addBloodPart2(pos + VectorRand(-1, 1), ang:Forward() * -70 + VectorRand(-8, 8), nil, Rand(5, 10), Rand(5, 10), 0.2, false, renderEnt or ent, spitColor)
	end
end)

local function explode(pos, size, force, owner)
	size = size or 1
	local xx, yy = 12, 12
	local w, h = 360 / xx, 360 / yy
	for x = 1, xx * size do
		for y = 1, yy * size do
			addBloodPart2(pos + VectorRand(-10,10), VectorRand(-100,100) * size, cloudmat, 25, 25, 1)
			
			local dir = Vector(0, 0, -1)
			dir:Rotate(Angle(h * y * Rand(0.9, 1.1), w * x * Rand(0.9, 1.1), 0))
			dir[3] = dir[3] + Rand(0.5, 1.5)
			dir:Mul(250 * size)
			addBloodPart(pos, force * 0.2 + dir, mat_huy, math.Rand(5,10), math.Rand(5,10), false, true)
		end
	end
end

local limbs = {
	["lleg"] = "ValveBiped.Bip01_L_Calf",
	["rleg"] = "ValveBiped.Bip01_R_Calf",
	["larm"] = "ValveBiped.Bip01_L_Forearm",
	["rarm"] = "ValveBiped.Bip01_R_Forearm",
	["head"] = "ValveBiped.Bip01_Head1",
}

local injuryBones = {
	skull = "ValveBiped.Bip01_Head1",
	spine1 = "ValveBiped.Bip01_Spine",
	spine2 = "ValveBiped.Bip01_Spine1",
	spine3 = "ValveBiped.Bip01_Spine2",
	chest = "ValveBiped.Bip01_Spine2",
	pelvis = "ValveBiped.Bip01_Pelvis",
	lleg = limbs.lleg,
	rleg = limbs.rleg,
	larm = limbs.larm,
	rarm = limbs.rarm,
}

local severeOrgans = {
	heart = "ValveBiped.Bip01_Spine2",
	stomach = "ValveBiped.Bip01_Spine1",
	liver = "ValveBiped.Bip01_Spine1",
	intestines = "ValveBiped.Bip01_Pelvis",
	lungsL = "ValveBiped.Bip01_Spine2",
	lungsR = "ValveBiped.Bip01_Spine2",
	trachea = "ValveBiped.Bip01_Neck1",
	brain = "ValveBiped.Bip01_Head1",
}

local function getInjuryPos(ent, boneName)
	if not IsValid(ent) then return end
	local bone = boneName and ent:LookupBone(boneName)
	local mat = bone and ent:GetBoneMatrix(bone)
	return mat and mat:GetTranslation() or ent:WorldSpaceCenter()
end

local function emitInjuryMist(ent, pos)
	if not pos then return end
	for i = 1, math.random(1, 2) do
		hg.addBloodPart2(pos + VectorRand(-1.5, 1.5), VectorRand(-18, 18) + Vector(0, 0, math.Rand(4, 14)), nil, math.Rand(6, 10), math.Rand(6, 10), math.Rand(0.25, 0.4), true, ent)
	end
end

local function getOrganDamage(value)
	if istable(value) then return tonumber(value[1]) or 0 end
	return tonumber(value) or 0
end

hook.Add("HG_OrganismChanged", "injury_damage_mist", function(oldorg, org)
	local ply = org.owner
	local ent = hg.GetCurrentCharacter(ply)
	if not IsValid(ent) then return end

	local mistPos
	for ind, nam in pairs(limbs) do
		if !oldorg[ind.."amputated"] and org[ind.."amputated"] then
			mistPos = getInjuryPos(ent, nam)
			break
		end
	end

	if not mistPos then
		for key, boneName in pairs(injuryBones) do
			if key != "skull" and (oldorg[key] or 0) < 1 and (org[key] or 0) >= 1 then
				mistPos = getInjuryPos(ent, boneName)
				break
			end
		end
	end

	if not mistPos then
		for key, boneName in pairs(severeOrgans) do
			if getOrganDamage(oldorg[key]) < 0.75 and getOrganDamage(org[key]) >= 0.75 then
				mistPos = getInjuryPos(ent, boneName)
				break
			end
		end
	end

	if not mistPos and #(org.arterialwounds or {}) > #(oldorg.arterialwounds or {}) then
		local wound = org.arterialwounds[#org.arterialwounds]
		local boneName = wound and wound[4]
		local bone = boneName and ent:LookupBone(boneName)
		local mat = bone and ent:GetBoneMatrix(bone)
		if mat and wound[2] and wound[3] then
			mistPos = LocalToWorld(wound[2], wound[3], mat:GetTranslation(), mat:GetAngles())
		else
			mistPos = getInjuryPos(ent, boneName)
		end
	end

	emitInjuryMist(ent, mistPos)
end)

hg.explode = explode

net.Receive("addfountain",function()
	local ent = net.ReadEntity()
	local force = net.ReadVector()
	
	--local bone = net.ReadInt(8)
	--local lpos = net.ReadVector()
	--local lang = net.ReadAngle()

	if not IsValid(ent) then return end

	local bone = ent:LookupBone("ValveBiped.Bip01_Neck1")
	if bone then
		local mat = ent:GetBoneMatrix(bone)
		if mat then
			explode(mat:GetTranslation() + mat:GetAngles():Forward() * 8, 0.5, force)
		end
	end
end)

net.Receive("bloodsquirt", function()
	local ent = net.ReadEntity()
	
	if not IsValid(ent) then return end

	local bone = net.ReadString()
	local bone = ent:LookupBone(bone)
	local mat = net.ReadMatrix()
	local pos = net.ReadVector()
	local dir = net.ReadVector()
	local len = dir:Length()

	local ent = hg.RagdollOwner(ent) or ent

	//local mat = ent:GetBoneMatrix(bone)
	local localPos, localDir = WorldToLocal(pos, dir:Angle(), mat:GetTranslation(), mat:GetAngles())

	local name = "squirtblood"..ent:EntIndex()..dir[1]
	local i = 250
	local maxI = i
	local vechuy = Vector(0,0,0)
	timer.Create(name, 0.01 * game.GetTimeScale(), i + 10, function()
		if not IsValid(ent) then timer.Remove(name) return end
		local ent = IsValid(ent.FakeRagdoll) and ent.FakeRagdoll or ent
		local amt = i / maxI
		local mat = ent:GetBoneMatrix(bone)
		if not mat then timer.Remove(name) return end
		local pos, dir = LocalToWorld(localPos, localDir, mat:GetTranslation(), mat:GetAngles())
		dir = dir:Forward() * len
		
		vechuy = vechuy + VectorRand(-amt * 5,amt * 5)
		addBloodPart(pos, dir * amt * 90 + vechuy * amt, mat_huy, math.Rand(3,3), math.Rand(3,3), true, false)
		i = i - 1
	end)
	timer.Adjust(name, 0)
end)

--net.Receive("blood particle explode", function() explode(net.ReadVector()) end)

--[[concommand.Add("testpart", function()
	if not LocalPlayer():IsAdmin() then return end
	local pos = Vector(0, 0, 0)
	addBloodPart(pos, Vector(25, 0, 0), mat_huy, math.random(10, 15), math.random(10, 15))
end)]]

net.Receive("bloodsquirt2", function()
	local ent = net.ReadEntity()
	
	if not IsValid(ent) then return end

	local bone = net.ReadString()
	local bone = ent:LookupBone(bone)
	local mat = net.ReadMatrix()
	local pos = net.ReadVector()
	local dir = net.ReadVector()
	local len = dir:Length()

	local ent = hg.RagdollOwner(ent) or ent
	local ply = ent

	//local mat = ent:GetBoneMatrix(bone)
	local localPos, localDir = WorldToLocal(pos, dir:Angle(), mat:GetTranslation(), mat:GetAngles())

	if ply == lply then
		localPos:Add(-Vector(2,-2,0))
	end

	local name = "squirtblood2"..ent:EntIndex()//..dir[1]
	local i = 50
	local maxI = i
	local vechuy = Vector(0,0,0)
	timer.Create(name, 0.01 * game.GetTimeScale(), i + 10, function()
		if not IsValid(ent) then timer.Remove(name) return end
		local ent = IsValid(ent.FakeRagdoll) and ent.FakeRagdoll or ent
		local amt = math.max(i / maxI, 0.2)
		if math.random(5) == 1 then return end
		local mat = ent:GetBoneMatrix(bone)
		if not mat then timer.Remove(name) return end

		if ply == lply and (i == 50 or i == 25) then
			ViewPunch(Angle(15,0,0))
		end

		--ent:SetFlexWeight(ent:GetFlexIDByName("jaw_drop"), 1)

		local pos, dir = LocalToWorld(localPos, localDir, mat:GetTranslation(), mat:GetAngles())
		
		if lply == ply then
			dir = lply:EyeAngles()
		end

		dir = dir:Forward() * len
		addBloodPart(pos + VectorRand(-0.2, 0.2), dir * amt * 90 + VectorRand(-amt * 25,amt * 25), mat_huy, math.Rand(3,3), math.Rand(3,3), false, false)
		i = i - 1
	end)
	timer.Adjust(name, 0)
end)
