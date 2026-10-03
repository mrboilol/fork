
local lpos, lang = Vector(5, 2, -12), Angle(-90, -90, 90)
local lpos2, lang2 = Vector(-5, 3, 6),Angle(0, 0, 0)

local drawfuncopendoor = function(ent, ply, vm, time)
	if ply.zmanipaddtbl then
		local door = ply.zmanipaddtbl[1]

		if !IsValid(door) then return end

		local lh = vm:LookupBone("ValveBiped.Bip01_L_Hand")
		local mat = vm:GetBoneMatrix(lh)
		
		local handle = door:LookupBone("handle")
		if !handle then return end
		local matdoor = door:GetBoneMatrix(handle)
		if !matdoor then return end

		local dot = door:GetAngles():Forward():Dot(ply:EyeAngles():Forward())
		local sign = dot > 0

		local pos, ang = LocalToWorld(LerpVector(1 - (dot + 1) * 0.5, lpos, lpos2), sign and lang or lang2, matdoor:GetTranslation(), matdoor:GetAngles())
		
		local distmul = 1 - math.min(1, pos:DistToSqr(mat:GetTranslation()) / (40 * 40))

		mat:SetTranslation(LerpVector(math.Clamp((1 - time) * distmul, 0, 1), mat:GetTranslation(), pos))
		--mat:SetAngles(ang)

		hg.bone_apply_matrix(vm, lh, mat)
	end
end

local lpos3, lang3 = Vector(0, 0, 0),Angle(0, 0, 0)

local drawfuncinteract = function(ent, ply, vm, time)
	do return end
	if ply.zmanipaddtbl then
		local ent = ply.zmanipaddtbl[1]

		if !IsValid(ent) then return end

		local lh = vm:LookupBone("ValveBiped.Bip01_L_Hand")
		local mat = vm:GetBoneMatrix(lh)
		
		--local handle = door:LookupBone("handle")
		--local matdoor = door:GetBoneMatrix(handle)
		local mat2 = ent:GetBoneMatrix(0)

		local pos, ang = LocalToWorld(lpos3, lang3, mat2:GetTranslation(), mat2:GetAngles())
		
		local distmul = 1 - math.min(1, pos:DistToSqr(mat:GetTranslation()) / (40 * 40))

		mat:SetTranslation(LerpVector(math.Clamp((1 - time) * distmul, 0, 1), mat:GetTranslation(), pos))
		--mat:SetAngles(ang)

		hg.bone_apply_matrix(vm, lh, mat)
	end
end

local tbl = {
	["models/zmanip/c_zmanipinteract.mdl"] = {
		["interact"] = {
			seq = "interact",
			playTime = 1,
			otherData = { 
				angClamps = { {-75}, {65} }
			},
			drawFunc = drawfuncinteract,
		},
		["use"] = {seq = "use"},
	},
	["models/zmanip/c_zmanipgestures.mdl"] = {
		["flipoff"] = {seq = "flipoff", playTime = 1.2, otherData = {posAdjust = Vector(-4,4,0)}},
		["okayhand"] = {seq = "okayhand", playTime = 2},
		["thumbsup"] = {seq = "thumbsup"},
		["swimforward"] = {seq = "swimforward", playTime = 1},
		["swimleft"] = {seq = "swimleft", playTime = 1},
	},
	["models/zmanip/c_zmaniphandanims.mdl"] = {
		["explosion"] = {seq = "shieldexplosion"},
	},
	["models/zmanip/c_zmanipusedoor.mdl"] = {
		["usedoor"] = {seq = "usedoor"}
	},
	["models/zmanip/c_zmaniphandanims.mdl"] = {
		["visordown"] = {seq = "visordown", playTime = 1.4,
			otherData = {
				posAdjust = Vector(7,1,1),
				angClamps = { {-75}, {35} },
			} },
	},
	["models/weapons/zcity/c_hands_gestures.mdl"] = {
		["door_open_forward"] = {seq = "door_open_forward", playTime = 1.2 ,
			otherData = {
				posAdjust = Vector(7,0,3),
				angClamps = { {12}, {12} },
			},
			drawFunc = drawfuncopendoor,
		},
		["door_open_back"] = {seq = "door_open_back", playTime = 1.2,
			otherData = {
				posAdjust = Vector(7,0,3),
				angClamps = { {12}, {12} },
			},
			drawFunc = drawfuncopendoor,
		},
		["fuckyou"] = {seq = "fuckyou", playTime = 2.2,
			otherData = {
				posAdjust = Vector(6,2,1),
				angClamps = { {-55}, {55} },
			}},
		["point"] = {seq = "point", playTime = 3,
			otherData = {
				angClamps = { {-55}, {55} },
			}},
		["thump_up"] = {seq = "thump_up", playTime = 2.2,
			otherData = {
				posAdjust = Vector(5,2,1),
				angClamps = { {-55}, {55} },
			}},
	},
	["models/weapons/c_ofges_model.mdl"] = {
		["acknowledge"] = {seq = "ofges_acknowledge", playTime = 2.0,
			otherData = {
				posAdjust = Vector(6,2,1),
				angClamps = { {-55}, {55} },
			}},
		["wait"] = {seq = "ofges_wait", playTime = 2.0,
			otherData = {
				posAdjust = Vector(6,2,1),
				angClamps = { {-55}, {55} },
			}},
		["danger"] = {seq = "ofges_danger", playTime = 2.0,
			otherData = {
				posAdjust = Vector(6,2,1),
				angClamps = { {-55}, {55} },
			}},
		["thanks"] = {seq = "ofges_thanks", playTime = 2.0,
			otherData = {
				posAdjust = Vector(6,2,1),
				angClamps = { {-55}, {55} },
			}},
		["omw"] = {seq = "ofges_omw", playTime = 2.0,
			otherData = {
				posAdjust = Vector(6,2,1),
				angClamps = { {-55}, {55} },
			}},
		["regroup"] = {seq = "ofges_regroup", playTime = 2.0,
			otherData = {
				posAdjust = Vector(6,2,1),
				angClamps = { {-55}, {55} },
			}},
		["help"] = {seq = "ofges_help", playTime = 2.0,
			otherData = {
				posAdjust = Vector(6,2,1),
				angClamps = { {-55}, {55} },
			}},
		["hello"] = {seq = "ofges_hello", playTime = 2.0,
			otherData = {
				posAdjust = Vector(6,2,1),
				angClamps = { {-55}, {55} },
			}},
		["point_of"] = {seq = "ofges_point", playTime = 2.0,
			otherData = {
				angClamps = { {-55}, {55} },
			}},
	}
}

hg.ZManipAnims = {}
for mdl, tbl2 in pairs(tbl) do
	for anim, tSettings in pairs(tbl2) do
		hg.ZManipAnims[anim] = {
			mdl = mdl,
			seq = tSettings.seq,
			playTime = tSettings.playTime or 1,
			timeAdjust = tSettings.timeAdjust or 1,
			otherData = tSettings.otherData,
			drawFunc = tSettings.drawFunc,
		}
	end
end

function hg.RunZManipAnim(ply, anim, revers, timeOveride, addtbl)
	local ent = hg.GetCurrentCharacter(ply)
	local zmdl = ply.zmodel

	if !IsValid(zmdl) then return end
	--if ply.zmanipstart ~= nil then return end
	local tbl = hg.ZManipAnims[anim] or anim
	if not tbl.mdl then return end

	zmdl:SetModel(tbl.mdl)
	ply.zmanipstart = CurTime()
	ply.zmaniptime = timeOveride or tbl.playTime or 1
	ply.zmanipseq = tbl.seq
	ply.zmanipanim = anim
	ply.zmanip_revers = revers
	ply.zmanipother = {}
	ply.zmanipother = tbl.otherData
	ply.zmanipdrawFunc = tbl.drawFunc
	ply.zmanipaddtbl = addtbl
	if (ply.NextFoley or 0) < CurTime() then
		ply:EmitSound("player/clothes_generic_foley_0" .. math.random(5) .. ".wav", 55)
		ply.NextFoley = CurTime() + (ply.zmaniptime or 1)
	end
	
	local seq = tbl.seq
	if isstring(seq) then
		seq = zmdl:LookupSequence(seq)
	end
	if isnumber(seq) and seq >= 0 and (not zmdl.GetSequenceCount or seq < zmdl:GetSequenceCount()) then
		zmdl:SetSequence(seq)
	end
end

net.Receive("RunZManipAnim", function()
	local ply = net.ReadPlayer()
	local anim = net.ReadString()
	local revers = net.ReadBool()
	local timeOveride = net.ReadFloat()
	local addtbl = net.ReadTable()
	
	hg.RunZManipAnim(ply, anim, revers, timeOveride != 0 and timeOveride or nil, addtbl)
end)

local mdl = Model("models/zmanip/c_zmanipinteract.mdl") -- interact use
function hg.DoZManip(ent, ply)
	if not IsValid(ply.zmodel) then
		ply.zmodel = ClientsideModel(mdl)
		ply.zmodel:SetNoDraw(true)
	end

	local org = ply.organism
	local useRight = org and (org.larmamputated or org.lhandamputated or org.larmupamputated) or false
	if useRight and not hg.CanUseRightHand(ply) then return end

	if not ply.zmanipstart or IsValid(ply:GetNetVar("carryent2")) then return end
	
	local time = (math.Clamp((CurTime() - ply.zmanipstart) / ply.zmaniptime, 0, 1))
	
	if time >= 1 then
		ply.zmanipstart = nil
		return
	end

	local WorldModel = ply.zmodel

	local wep = ply:GetActiveWeapon()

	if wep.ShouldDoZManip and !wep:ShouldDoZManip() then return end
	if !IsValid(wep) then return end

	local tr = hg.eyeTrace(ply, 60)
	if not tr then return end

	local ang = ply:EyeAngles()

	local ml = time * 1
	--print(ml)
	local pos = tr.StartPos + ang:Forward() * (1 - 6 - ml / 1.5) + ang:Right() * (-1 + ml / 2)

	-- position adjust

	if ply.zmanipother and ply.zmanipother.posAdjust then
		pos = pos
		+ ang:Forward() * ply.zmanipother.posAdjust[1]
		+ ang:Right() * ply.zmanipother.posAdjust[2]
		+ ang:Up() * ply.zmanipother.posAdjust[3]
	end


	local ang = ply:EyeAngles()
	local _,ang = LocalToWorld(vector_origin,(angle_zero),vector_origin,ang)

	-- angles clamp

	if ply.zmanipother and ply.zmanipother.angClamps then
		if ply.zmanipother.angClamps[1][1] and ply.zmanipother.angClamps[2][1] then
			ang[1] = math.max( math.min( ang[1], ply.zmanipother.angClamps[2][1] ), ply.zmanipother.angClamps[1][1] )
		end
		if ply.zmanipother.angClamps[1][2] and ply.zmanipother.angClamps[2][2] then
			ang[2] = math.max( math.min( ang[2], ply.zmanipother.angClamps[2][2] ), ply.zmanipother.angClamps[1][2] )
		end
		if ply.zmanipother.angClamps[1][3] and ply.zmanipother.angClamps[2][3] then
			ang[3] = math.max( math.min( ang[3], ply.zmanipother.angClamps[2][3] ), ply.zmanipother.angClamps[1][3] )
		end
	end

	WorldModel:SetRenderOrigin(pos)
	WorldModel:SetRenderAngles(ang)
	WorldModel:SetPos(pos)
	WorldModel:SetAngles(ang)

	WorldModel:SetupBones()
	if useRight then wep.rhandik = true else wep.lhandik = true end

	WorldModel:SetCycle(ply.zmanip_revers and 1 - time or time)

	local camBone = WorldModel:LookupBone("ValveBiped.Bip01_L_Hand")

    if camBone and hg.IsLocal(ply) then
        local matrix = WorldModel:GetBoneMatrix(camBone)

        if matrix then
            local gAngles = matrix:GetAngles()
            local _,gAngles = WorldToLocal(vector_origin, gAngles, pos, ang)
            WorldModel.OldAngPunch = WorldModel.OldAngPunch or gAngles
            local punch = ( WorldModel.OldAngPunch - gAngles ) / 250

            //ViewPunch2( -punch )
            ViewPunch( punch )

            WorldModel.OldAngPunch = gAngles
        end
    end

	local bones = useRight and hg.TPIKBonesRH or hg.TPIKBonesLH

	if ply.zmanipdrawFunc and not useRight then
		ply.zmanipdrawFunc(ent, ply, WorldModel, time)
	end
	for _, bone in ipairs(bones) do
		local wm_boneindex = WorldModel:LookupBone(useRight and (string.gsub(bone, "_R_", "_L_")) or bone)
		if !wm_boneindex then continue end
		local wm_bonematrix = WorldModel:GetBoneMatrix(wm_boneindex)
		if !wm_bonematrix then continue end

		local ply_boneindex = ent:LookupBone(bone)
		if !ply_boneindex then continue end
		local ply_bonematrix = ent:GetBoneMatrix(ply_boneindex)
		if !ply_bonematrix then continue end

		local bonepos = wm_bonematrix:GetTranslation()
		local boneang = wm_bonematrix:GetAngles()

		if useRight then
			local lp, la = WorldToLocal(bonepos, boneang, pos, ang)
			local f, u = la:Forward(), la:Up()
			lp.y, f.y, u.y = -lp.y, -f.y, -u.y
			bonepos, boneang = LocalToWorld(lp, f:AngleEx(u), pos, ang)
		end

		bonepos.x = math.Clamp(bonepos.x, pos.x - 38, pos.x + 38) -- clamping if something gone wrong so no stretching (or animator is fleshy)
		bonepos.y = math.Clamp(bonepos.y, pos.y - 38, pos.y + 38)
		bonepos.z = math.Clamp(bonepos.z, pos.z - 38, pos.z + 38)

		local lerp = (time < 0.25 and (0.25 - time) * 4 or math.max(0, time - 0.75) * 4)
		lerp = math.ease.InOutSine(lerp)

		local m1 = Matrix()
		m1:SetAngles(boneang)
		local m2 = Matrix()
		m2:SetAngles(ply_bonematrix:GetAngles())

		local q1 = Quaternion()
		q1:SetMatrix(m1)

		local q2 = Quaternion()
		q2:SetMatrix(m2)

		local q3 = q1:SLerp(q2, lerp)

		ply_bonematrix:SetTranslation(LerpVector(lerp, bonepos, ply_bonematrix:GetTranslation()))
		ply_bonematrix:SetAngles(q3:Angle())

		--ply_bonematrix:SetTranslation(bonepos + lpos * lerp)
		--ply_bonematrix:SetAngles(q1:Angle())

		--hg.bone_apply_matrix(ent, ply_boneindex, ply_bonematrix)
		ent:SetBoneMatrix(ply_boneindex, ply_bonematrix)
		--ply:SetBonePosition(ply_boneindex, bonepos, boneang)
	end
end

local HANDOFF_GRAB = 0.35
local HANDOFF_BLEND = 0.35
local handoffPos, handoffAng = Vector(4, 0, 0), Angle(0, 0, 0)

local function handoffEnd(ply, wep)
	local h = ply.hgHandoff
	return h.select + ((IsValid(wep) and wep.isTPIKBase) and 0 or HANDOFF_BLEND)
end

local function clearHandoff(ply)
	if IsValid(ply.hgHandoffModel) then ply.hgHandoffModel:Remove() end
	ply.hgHandoffModel = nil
	ply.hgHandoff = nil
end

net.Receive("hg_pickup_handoff", function()
	local ply = net.ReadPlayer()
	local wep = net.ReadEntity()
	local mdl = net.ReadString()
	local selectDelay = net.ReadFloat()
	if not IsValid(ply) then return end

	clearHandoff(ply)
	if mdl == "" then return end

	local model = ClientsideModel(mdl)
	if not IsValid(model) then return end
	model:SetNoDraw(true)
	if IsValid(wep) then
		model:SetSkin(wep:GetSkin())
		if wep.WorldModelFake and wep.FakeScale then model:SetModelScale(wep.FakeScale, 0) end
	end

	ply.hgHandoffModel = model
	ply.hgHandoff = {wep = wep, start = CurTime(), select = CurTime() + selectDelay}
	ply:CallOnRemove("hg_pickup_handoff", clearHandoff)
end)

local HANDOFF_POS_STIFFNESS = 240
local HANDOFF_POS_DAMPING = 15
local HANDOFF_ANG_STIFFNESS = 190
local HANDOFF_ANG_DAMPING = 13

local function stepHandoffSpring(h, pos, ang)
	local now = SysTime()
	if not h.springPos then
		h.springPos = pos - ang:Forward() * 5 - ang:Up() * 4
		h.springVel = Vector(0, 0, 0)
		h.springAng = Angle(ang.p + 28, ang.y, ang.r)
		h.springAngVel = Vector(0, 0, 0)
		h.springTime = now
	end

	local dt = math.Clamp(now - h.springTime, 0, 0.05)
	h.springTime = now

	local posDrag = math.exp(-HANDOFF_POS_DAMPING * dt)
	h.springVel = (h.springVel + (pos - h.springPos) * HANDOFF_POS_STIFFNESS * dt) * posDrag
	h.springPos = h.springPos + h.springVel * dt

	local angDrag = math.exp(-HANDOFF_ANG_DAMPING * dt)
	local sa, av = h.springAng, h.springAngVel
	av.x = (av.x + math.AngleDifference(ang.p, sa.p) * HANDOFF_ANG_STIFFNESS * dt) * angDrag
	av.y = (av.y + math.AngleDifference(ang.y, sa.y) * HANDOFF_ANG_STIFFNESS * dt) * angDrag
	av.z = (av.z + math.AngleDifference(ang.r, sa.r) * HANDOFF_ANG_STIFFNESS * dt) * angDrag
	sa.p = sa.p + av.x * dt
	sa.y = sa.y + av.y * dt
	sa.r = sa.r + av.z * dt

	return h.springPos, h.springAng
end

function hg.PickupHandoffHides(ply, wep)
	local h = ply.hgHandoff
	return h ~= nil and h.wep == wep and CurTime() < handoffEnd(ply, wep)
end

function hg.DrawPickupHandoff(ent, ply)
	local h = ply.hgHandoff
	if not h then return end

	local model = ply.hgHandoffModel
	local wep = h.wep
	local now = CurTime()
	if not IsValid(model) or now >= handoffEnd(ply, wep) or (now > h.select and IsValid(wep) and wep:GetOwner() ~= ply) then
		clearHandoff(ply)
		return
	end
	if now < h.start + HANDOFF_GRAB then return end

	local org = ply.organism
	local useRight = org and (org.larmamputated or org.lhandamputated or org.larmupamputated)
	local bone = ent:LookupBone(useRight and "ValveBiped.Bip01_R_Hand" or "ValveBiped.Bip01_L_Hand")
	local mat = bone and ent:GetBoneMatrix(bone)
	if not mat then return end

	local pos, ang = LocalToWorld(handoffPos, handoffAng, mat:GetTranslation(), mat:GetAngles())
	pos = LocalToWorld(-model:OBBCenter(), angle_zero, pos, ang)
	pos, ang = stepHandoffSpring(h, pos, ang)

	local real = IsValid(wep) and wep.worldModel
	if now > h.select and IsValid(real) and real:GetModel() == model:GetModel() then
		model:SetRenderOrigin(pos)
		model:SetRenderAngles(ang)
		model:SetupBones()
		real:SetupBones()
		local cm, rm = model:GetBoneMatrix(0), real:GetBoneMatrix(0)
		if cm and rm then
			local op, oa = WorldToLocal(cm:GetTranslation(), cm:GetAngles(), pos, ang)
			local ip, ia = WorldToLocal(vector_origin, angle_zero, op, oa)
			local tpos, tang = LocalToWorld(ip, ia, rm:GetTranslation(), rm:GetAngles())
			local frac = math.ease.InOutSine(math.Clamp((now - h.select) / HANDOFF_BLEND, 0, 1))
			pos = LerpVector(frac, pos, tpos)
			ang = LerpAngle(frac, ang, tang)
			model:SetModelScale(Lerp(frac, 1, real:GetModelScale()))
		end
	end

	model:SetRenderOrigin(pos)
	model:SetRenderAngles(ang)
	model:SetupBones()
	model:DrawModel()
end
