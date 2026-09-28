local hg_floppy_debug = CreateConVar("hg_floppy_debug", "0", FCVAR_ARCHIVE, "AAAAAAAAAAAAAAAAAAAAAA", 0, 1)

local function debugPrint(fmt, ...)
	local msg = string.format("[FloppyDebug %.2f] " .. fmt, CurTime(), ...)
	print(msg)
	for _, ply in player.Iterator() do
		if ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTCONSOLE, msg) end
	end
end

local function syncDebug()
	hg.FloppyDebug = hg_floppy_debug:GetBool() and debugPrint or nil
end
syncDebug()
cvars.AddChangeCallback("hg_floppy_debug", syncDebug, "hg_floppy_debug")

local function canUse(ply)
	return not IsValid(ply) or ply:IsSuperAdmin()
end

local function reply(ply, msg)
	if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) end
	print(msg)
end

local function physName(rag, physNum)
	local bone = rag:TranslatePhysBoneToBone(physNum)
	return bone and bone >= 0 and rag:GetBoneName(bone) or "?"
end

local function parentPhys(rag, physNum)
	local bone = rag:TranslatePhysBoneToBone(physNum)
	if not bone or bone < 0 then return end
	local physByBone = {}
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		physByBone[rag:TranslatePhysBoneToBone(i)] = i
	end
	local parent = rag:GetBoneParent(bone)
	while parent and parent >= 0 do
		if physByBone[parent] then return physByBone[parent] end
		parent = rag:GetBoneParent(parent)
	end
end

local function captureRest(rag)
	local rest = {}
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local p = parentPhys(rag, i)
		local phys, physP = rag:GetPhysicsObjectNum(i), p and rag:GetPhysicsObjectNum(p)
		if IsValid(phys) and IsValid(physP) then
			rest[i] = {parent = p, anchor = physP:WorldToLocal(phys:GetPos())}
		end
	end
	return rest
end

local function jointDrift(rag, rest, i)
	local r = rest[i]
	local phys, physP = rag:GetPhysicsObjectNum(i), rag:GetPhysicsObjectNum(r.parent)
	if not IsValid(phys) or not IsValid(physP) then return -1 end
	return physP:LocalToWorld(r.anchor):Distance(phys:GetPos())
end

hook.Add("Ragdoll_Create", "hg-floppy-debug-rest", function(ply, rag)
	if IsValid(rag) then rag.hgFloppyDebugRest = captureRest(rag) end
end)

concommand.Add("hg_floppy_dump", function(ply, _, args)
	if not canUse(ply) then return end
	local target = ply
	if args[1] then
		for _, p in player.Iterator() do
			if string.find(string.lower(p:Nick()), string.lower(args[1]), 1, true) then target = p break end
		end
	end
	if not IsValid(target) then reply(ply, "no target") return end

	local org = target.organism or {}
	reply(ply, "==== floppy dump: " .. tostring(target) .. " model " .. target:GetModel())
	reply(ply, string.format("larm=%s rarm=%s lleg=%s rleg=%s spine1=%s spine2=%s spine3=%s",
		tostring(org.larm), tostring(org.rarm), tostring(org.lleg), tostring(org.rleg),
		tostring(org.spine1), tostring(org.spine2), tostring(org.spine3)))
	reply(ply, "org.fake_floppy_bones: " .. table.ToString(org.fake_floppy_bones or {}, nil, false))
	reply(ply, "org.fake_dislocated_bones: " .. table.ToString(org.fake_dislocated_bones or {}, nil, false))
	local fractures = {}
	for bone in pairs(org.open_fractures or {}) do fractures[#fractures + 1] = bone end
	reply(ply, "org.open_fractures: " .. table.concat(fractures, ", "))

	local rag = target.FakeRagdoll
	if not IsValid(rag) then reply(ply, "no FakeRagdoll") return end
	reply(ply, "rag.hg_floppy_bones: " .. table.ToString(rag.hg_floppy_bones or {}, nil, false))
	for bone, cons in pairs(rag.hg_floppy_constraints or {}) do
		reply(ply, string.format("  constraint %s valid=%s", bone, tostring(IsValid(cons))))
	end

	local rest = rag.hgFloppyDebugRest
	if not rest then reply(ply, "no rest capture (ragdoll made before debug file loaded)") return end
	reply(ply, "joint drift (child origin vs where parent expects it; big = joint not holding):")
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		if rest[i] then
			reply(ply, string.format("  [%2d] %-28s <- [%2d] %-28s drift %.1f", i, physName(rag, i), rest[i].parent, physName(rag, rest[i].parent), jointDrift(rag, rest, i)))
		end
	end
end)

concommand.Add("hg_floppy_probe", function(ply, _, args)
	if not canUse(ply) then return end
	local model = args[1] or (IsValid(ply) and ply:GetModel())
	if not model then reply(ply, "usage: hg_floppy_probe <model>") return end
	local origin = IsValid(ply) and (ply:EyePos() + ply:GetAimVector() * 150 + vector_up * 150) or Vector(0, 0, 500)

	local test = ents.Create("prop_ragdoll")
	test:SetModel(model)
	test:Spawn()
	local count = test:GetPhysicsObjectCount()
	test:Remove()
	reply(ply, "==== probing " .. model .. " (" .. count .. " phys objects)")

	local function probe(k)
		if k >= count then reply(ply, "==== probe done") return end
		local rag = ents.Create("prop_ragdoll")
		rag:SetModel(model)
		rag:SetPos(origin)
		rag:Spawn()
		rag:SetCollisionGroup(COLLISION_GROUP_WORLD)
		for i = 0, count - 1 do
			local phys = rag:GetPhysicsObjectNum(i)
			if IsValid(phys) then
				phys:EnableGravity(false)
				phys:SetVelocity(vector_origin)
				phys:SetAngleVelocity(vector_origin)
			end
		end
		local rest = captureRest(rag)
		rag:RemoveInternalConstraint(k)

		local ticks = 0
		local id = "hg_floppy_probe_" .. rag:EntIndex()
		timer.Create(id, 0, 20, function()
			if not IsValid(rag) then timer.Remove(id) return end
			ticks = ticks + 1
			for i, r in pairs(rest) do
				local phys, physP = rag:GetPhysicsObjectNum(i), rag:GetPhysicsObjectNum(r.parent)
				if IsValid(phys) and IsValid(physP) then
					local dir = phys:GetPos() - physP:GetPos()
					if dir:LengthSqr() < 0.01 then dir = VectorRand() end
					phys:SetVelocity(dir:GetNormalized() * 600)
				end
			end
			if ticks < 20 then return end

			local worst, worstDrift = nil, 0
			local report = {}
			for i in pairs(rest) do
				local d = jointDrift(rag, rest, i)
				if d > 6 then report[#report + 1] = string.format("%s(%.0f)", physName(rag, i), d) end
				if d > worstDrift then worst, worstDrift = i, d end
			end
			reply(ply, string.format("phys %2d %-26s -> broke: %s", k, physName(rag, k),
				#report > 0 and table.concat(report, " ") or "nothing"))
			rag:Remove()
			timer.Simple(0.1, function() probe(k + 1) end)
		end)
	end
	probe(0)
end)
