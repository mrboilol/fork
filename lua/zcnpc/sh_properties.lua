--[[
	C-menu organism tools for NPCs.

	Z-City's admin properties (admintools/sh_player_properties.lua) only accept
	players and player ragdolls. Testing NPC knockouts, breaks and bleeds is RNG
	or needs a second accident to happen first - so the same tools are offered
	here for any organism NPC / zcnpc body.
]]

ZCNPC = ZCNPC or {}

local function HasAccess(ply)
	if not IsValid(ply) then return false end
	if ply.ZCTools_GetAccess then return ply:ZCTools_GetAccess() end

	return ply:IsAdmin()
end

local function IsNpcHost(ent)
	if not IsValid(ent) then return false end

	if ent:IsNPC() and ent.organism then return true end

	if ent:IsRagdoll() then
		if ent.organism then return true end
		if ent.zcnpc_npcbody or ent.zcnpc_corpse then return true end
		if ZCNPC.Downed and ZCNPC.Downed[ent] then return true end
	end

	return false
end

local function Filter(_, ent, ply)
	return HasAccess(ply) and IsNpcHost(ent)
end

-- Standing NPC, or the hidden NPC behind a body, plus the body that holds the org.
local function Resolve(ent)
	if not IsValid(ent) then return end

	if ent:IsNPC() then
		return ent, ent.zcnpc_rag, ent.organism or (IsValid(ent.zcnpc_rag) and ent.zcnpc_rag.organism)
	end

	if ent:IsRagdoll() then
		local npc = ent.zcnpc_npc
		return npc, ent, ent.organism or (IsValid(npc) and npc.organism)
	end
end

local function OrgOwner(ent)
	local npc, rag, org = Resolve(ent)
	if org then return org.owner or rag or npc, org end
end

-- Body that can take ragdoll physics ops (neck snap constraints, etc.)
local function BodyOf(ent)
	local npc, rag = Resolve(ent)
	if IsValid(rag) then return rag, npc end
	if IsValid(npc) and IsValid(npc.zcnpc_rag) then return npc.zcnpc_rag, npc end

	return nil, npc
end

if SERVER then
	-- Stock hg.BreakNeck calls Player:Kill and looks up RagdollDeath — neither
	-- exists for our NPCs. Snap the spine, put them down, and joint the head.
	function ZCNPC.BreakNeck(ent)
		local rag, npc = BodyOf(ent)
		local owner, org = OrgOwner(ent)
		if not org then return end

		org.spine3 = 1
		org.shock = math.max(org.shock or 0, 100)
		org.needotrub = true
		org.otrub = true

		local voice = IsValid(rag) and rag or owner or ent
		if IsValid(voice) then
			voice:EmitSound("neck_snap_01.wav", 60, 100, 1, CHAN_AUTO)
		end

		if IsValid(npc) and not IsValid(rag) and ZCNPC.MakeUnconscious then
			rag = ZCNPC.MakeUnconscious(npc)
		end

		timer.Simple(0.1, function()
			if not IsValid(rag) then return end

			local headBone = rag:LookupBone("ValveBiped.Bip01_Head1")
			local spineBone = rag:LookupBone("ValveBiped.Bip01_Spine2")
			if not (headBone and spineBone) then return end

			local head = rag:TranslateBoneToPhysBone(headBone)
			local spine = rag:TranslateBoneToPhysBone(spineBone)
			if not head or head < 0 or not spine or spine < 0 then return end

			pcall(function() rag:RemoveInternalConstraint(head) end)

			local phead = rag:GetPhysicsObjectNum(head)
			local pspine = rag:GetPhysicsObjectNum(spine)
			if not (IsValid(phead) and IsValid(pspine)) then return end

			local lpos = WorldToLocal(
				phead:GetPos() + phead:GetAngles():Forward() * -2 + phead:GetAngles():Up() * -1.5,
				angle_zero, pspine:GetPos(), pspine:GetAngles()
			)

			phead:SetPos(pspine:GetPos() + pspine:GetAngles():Forward() * 12.9 + pspine:GetAngles():Right() * -1)
			constraint.AdvBallsocket(rag, rag, spine, head, lpos, nil, 0, 0, -55, -90, -50, 55, 35, 50, 0, 0, 0, 0, 0)
		end)
	end

	-- Kill must go down first: MakeUnconscious refuses org.alive == false.
	function ZCNPC.MenuKill(ent)
		local npc, rag, org = Resolve(ent)

		if IsValid(rag) and ZCNPC.Downed and ZCNPC.Downed[rag] then
			if org then
				org.alive = false
				org.brain = 1
			end
			ZCNPC.KillDowned(rag, ZCNPC.Downed[rag])

			return
		end

		if not IsValid(npc) then return end

		local body = IsValid(npc.zcnpc_rag) and npc.zcnpc_rag or nil
		if not IsValid(body) and ZCNPC.MakeUnconscious then
			body = ZCNPC.MakeUnconscious(npc)
		end

		timer.Simple(0, function()
			if not IsValid(body) then return end

			local o = body.organism
			if o then
				o.alive = false
				o.brain = 1
			end

			if ZCNPC.Downed and ZCNPC.Downed[body] and ZCNPC.KillDowned then
				ZCNPC.KillDowned(body, ZCNPC.Downed[body])
			end
		end)
	end
end

--\\ Stun / get up
properties.Add("zcnpc_stun", {
	MenuLabel = "Stun / Get up",
	Order = 2001,
	MenuIcon = "icon16/anchor.png",
	Filter = Filter,

	Action = function(self, ent)
		self:MsgStart()
		net.WriteEntity(ent)
		self:MsgEnd()
	end,

	Receive = function(self, _, ply)
		local ent = net.ReadEntity()
		if not self:Filter(ent, ply) then return end

		local npc, rag = Resolve(ent)
		if IsValid(rag) and ZCNPC.Downed and ZCNPC.Downed[rag] then
			if ZCNPC.WakeUp then ZCNPC.WakeUp(rag, ZCNPC.Downed[rag]) end
			print("[ZCNPC]", ply, "woke", npc or rag)
		elseif IsValid(npc) and ZCNPC.Floor then
			ZCNPC.Floor(npc)
			print("[ZCNPC]", ply, "stunned", npc)
		end
	end,
})

--\\ Reset organism
properties.Add("zcnpc_reset_org", {
	MenuLabel = "Reset organism",
	Order = 2002,
	MenuIcon = "icon16/heart_add.png",
	Filter = Filter,

	Action = function(self, ent)
		self:MsgStart()
		net.WriteEntity(ent)
		self:MsgEnd()
	end,

	Receive = function(self, _, ply)
		local ent = net.ReadEntity()
		if not self:Filter(ent, ply) then return end

		local owner, org = OrgOwner(ent)
		if not org then return end

		hg.organism.Clear(org)
		if IsValid(owner) then
			owner.fullsend = true
			if hg.send_bareinfo then hg.send_bareinfo(org) end
		end

		print("[ZCNPC]", ply, "reset organism on", owner)
	end,
})

--\\ Break limb
local BREAK = {
	[0] = function(ent, org, dmg)
		if ZCNPC.BreakNeck then
			ZCNPC.BreakNeck(ent)
		elseif hg.BreakNeck then
			hg.BreakNeck(ent)
		end
	end,
	[1] = function(_, org, dmg) hg.organism.input_list.larmup(org, 0, 1, dmg) end,
	[2] = function(_, org, dmg) hg.organism.input_list.rarmup(org, 0, 1, dmg) end,
	[3] = function(_, org, dmg) hg.organism.input_list.llegup(org, 0, 1, dmg) end,
	[4] = function(_, org, dmg) hg.organism.input_list.rlegup(org, 0, 1, dmg) end,
	[5] = function(_, org, dmg) hg.organism.input_list.spine1(org, 0, 1, dmg) end,
	[6] = function(_, org, dmg) hg.organism.input_list.spine2(org, 0, 1, dmg) end,
	[7] = function(_, org, dmg) hg.organism.input_list.spine3(org, 0, 1, dmg) end,
}

local BREAK_LABELS = {
	[0] = "Neck",
	[1] = "Left Arm",
	[2] = "Right Arm",
	[3] = "Left Leg",
	[4] = "Right Leg",
	[5] = "Spine 1",
	[6] = "Spine 2",
	[7] = "Spine 3",
}

properties.Add("zcnpc_break_limb", {
	MenuLabel = "Break Limb",
	Order = 2003,
	MenuIcon = "icon16/wrench.png",
	Filter = Filter,

	MenuOpen = function(self, option, ent)
		local submenu = option:AddSubMenu()

		for id = 0, 7 do
			local limb = id
			submenu:AddOption(BREAK_LABELS[limb], function()
				self:MsgStart()
				net.WriteEntity(ent)
				net.WriteUInt(limb, 8)
				self:MsgEnd()
			end)
		end
	end,

	Action = function() end,

	Receive = function(self, _, ply)
		local ent = net.ReadEntity()
		local limb = net.ReadUInt(8)
		if not self:Filter(ent, ply) then return end

		local owner, org = OrgOwner(ent)
		local run = BREAK[limb]
		if not (org and run and hg.organism and hg.organism.input_list) then return end

		run(owner or ent, org, DamageInfo())
		print("[ZCNPC]", ply, "broke", BREAK_LABELS[limb], "on", owner or ent)
	end,
})

--\\ Amputate limb
local AMPUTATE = {
	[0] = function(ent)
		if SERVER and hg.ExplodeHead and not ent.noHead then hg.ExplodeHead(ent) end
	end,
	[1] = function(_, org) hg.organism.AmputateLimb(org, "larm") end,
	[2] = function(_, org) hg.organism.AmputateLimb(org, "rarm") end,
	[3] = function(_, org) hg.organism.AmputateLimb(org, "lleg") end,
	[4] = function(_, org) hg.organism.AmputateLimb(org, "rleg") end,
}

local AMP_LABELS = {
	[0] = "Head",
	[1] = "Left Arm",
	[2] = "Right Arm",
	[3] = "Left Leg",
	[4] = "Right Leg",
}

properties.Add("zcnpc_amputate_limb", {
	MenuLabel = "Amputate Limb",
	Order = 2004,
	MenuIcon = "icon16/cut.png",
	Filter = Filter,

	MenuOpen = function(self, option, ent)
		local submenu = option:AddSubMenu()

		for id = 0, 4 do
			local limb = id
			submenu:AddOption(AMP_LABELS[limb], function()
				self:MsgStart()
				net.WriteEntity(ent)
				net.WriteUInt(limb, 8)
				self:MsgEnd()
			end)
		end
	end,

	Action = function() end,

	Receive = function(self, _, ply)
		local ent = net.ReadEntity()
		local limb = net.ReadUInt(8)
		if not self:Filter(ent, ply) then return end

		local owner, org = OrgOwner(ent)
		local run = AMPUTATE[limb]
		if not run then return end

		local target = IsValid(owner) and IsValid(owner.zcnpc_rag) and owner.zcnpc_rag or owner or ent
		-- Bypass zcnpc_gib_heavy_only so the C-menu tools still work with pistols out.
		if SERVER and ZCNPC.AllowNextGib then ZCNPC.AllowNextGib(org, target) end
		run(target, org)
		print("[ZCNPC]", ply, "amputated", AMP_LABELS[limb], "on", owner or ent)
	end,
})

--\\ Lobotomize
properties.Add("zcnpc_lobotomize", {
	MenuLabel = "Lobotomize",
	Order = 2005,
	MenuIcon = "icon16/brick.png",
	Filter = Filter,

	Action = function(self, ent)
		self:MsgStart()
		net.WriteEntity(ent)
		self:MsgEnd()
	end,

	Receive = function(self, _, ply)
		local ent = net.ReadEntity()
		if not self:Filter(ent, ply) then return end

		local owner, org = OrgOwner(ent)
		if not org then return end

		org.brain = math.min((org.brain or 0) + 0.05, 1)
		if IsValid(owner) then
			owner.fullsend = true
			if hg.send_bareinfo then hg.send_bareinfo(org) end
		end

		ply:ChatPrint(string.format("[ZCNPC] Brain %.0f%%", (org.brain or 0) * 100))
		print("[ZCNPC]", ply, "lobotomized", owner or ent, org.brain)
	end,
})

--\\ Cough / vomit blood
properties.Add("zcnpc_vomit", {
	MenuLabel = "Cough blood",
	Order = 2006,
	MenuIcon = "icon16/water.png",
	Filter = Filter,

	Action = function(self, ent)
		self:MsgStart()
		net.WriteEntity(ent)
		self:MsgEnd()
	end,

	Receive = function(self, _, ply)
		local ent = net.ReadEntity()
		if not self:Filter(ent, ply) then return end

		local owner, org = OrgOwner(ent)
		if not org then return end

		if ZCNPC.CoughBlood then
			ZCNPC.CoughBlood(owner or ent, org)
		elseif hg.organism and hg.organism.Vomit and IsValid(owner) and owner:IsPlayer() then
			hg.organism.Vomit(owner)
		end

		print("[ZCNPC]", ply, "forced blood cough on", owner or ent)
	end,
})

--\\ Knock out cold (shock)
properties.Add("zcnpc_knockout", {
	MenuLabel = "Knock out",
	Order = 2007,
	MenuIcon = "icon16/status_busy.png",
	Filter = Filter,

	Action = function(self, ent)
		self:MsgStart()
		net.WriteEntity(ent)
		self:MsgEnd()
	end,

	Receive = function(self, _, ply)
		local ent = net.ReadEntity()
		if not self:Filter(ent, ply) then return end

		local npc, _, org = Resolve(ent)
		if not org then return end

		org.shock = 100
		org.needotrub = true
		org.otrub = true

		if IsValid(npc) and ZCNPC.MakeUnconscious then
			timer.Simple(0, function()
				if IsValid(npc) then ZCNPC.MakeUnconscious(npc) end
			end)
		end

		print("[ZCNPC]", ply, "knocked out", npc or ent)
	end,
})

--\\ Ignite (to test fire screams / burn floor)
properties.Add("zcnpc_ignite", {
	MenuLabel = "Ignite",
	Order = 2008,
	MenuIcon = "icon16/fire.png",
	Filter = Filter,

	Action = function(self, ent)
		self:MsgStart()
		net.WriteEntity(ent)
		self:MsgEnd()
	end,

	Receive = function(self, _, ply)
		local ent = net.ReadEntity()
		if not self:Filter(ent, ply) then return end

		local npc, rag = Resolve(ent)
		local target = IsValid(rag) and rag or npc or ent
		if IsValid(target) then target:Ignite(10) end

		print("[ZCNPC]", ply, "ignited", target)
	end,
})

--\\ Kill (bleed-out / dead body)
properties.Add("zcnpc_kill", {
	MenuLabel = "Kill",
	Order = 2009,
	MenuIcon = "icon16/cross.png",
	Filter = Filter,

	Action = function(self, ent)
		self:MsgStart()
		net.WriteEntity(ent)
		self:MsgEnd()
	end,

	Receive = function(self, _, ply)
		local ent = net.ReadEntity()
		if not self:Filter(ent, ply) then return end

		if ZCNPC.MenuKill then ZCNPC.MenuKill(ent) end

		local npc = Resolve(ent)
		print("[ZCNPC]", ply, "killed", npc or ent)
	end,
})
--//
