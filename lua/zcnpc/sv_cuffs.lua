--[[
	Handcuffs on NPCs.

	weapon_handcuffs only accepts a ragdoll or a player standing perfectly still
	(SWEP:Tie in z_city/lua/weapons/weapon_handcuffs.lua:140), and every consequence
	of being cuffed is written for players: SelectWeapon, PlayerCanPickupWeapon,
	PlayerUse, and the hands-behind-the-back pose, which is client side IK on the
	hands SWEP (hg.handcuffedhands) and bails out on anything but a player.

	A downed body already passes Tie's ragdoll branch, so the missing pieces are
	cuffing an NPC that is still on its feet, keeping the cuffs on when it stands
	back up, and making a cuffed NPC behave like a detainee instead of a soldier.
	The pose and the cuff model live on the client (cl_render.lua) and key off the
	"handcuffed" netvar set here. The stock key is left alone where it already works.
]]

local cfg = ZCNPC.Config

ZCNPC.Cuffed = ZCNPC.Cuffed or {} -- [npc] = true

-- weapon_handcuffs ties its victim 2s into its 2.5s "attack" animation (the anim
-- length minus CallbackTimeAdjust), and the key fills a 0..100 hold meter 5 points
-- per tick, so it needs about a third of a second. Mirror both so cuffing an NPC
-- takes exactly as long as cuffing anyone else.
local CUFF_TIME = 2
local UNCUFF_TIME = 0.35
local REACH = 60 -- hg.eye falls back to `dist or 60`, and neither SWEP passes a dist

local function TracedNPC(ply)
	local trace = hg.eyeTrace(ply, REACH)
	if not trace then return end

	local ent = trace.Entity

	return IsValid(ent) and ent:IsNPC() and ent or nil
end

--\\ State
function ZCNPC.CanCuff(npc)
	if not (ZCNPC.Enabled() and cfg.cuffs:GetBool() and cfg.cuffs_standing:GetBool()) then return false end
	if not (IsValid(npc) and npc:IsNPC()) then return false end
	if IsValid(npc.zcnpc_rag) then return false end -- cuff the body on the ground instead

	local org = npc.organism

	return org ~= nil and org.alive ~= false and not org.handcuffed
end

function ZCNPC.Cuff(npc)
	if not IsValid(npc) then return end

	local org = npc.organism
	if not org then return end

	org.handcuffed = true
	npc:SetNetVar("handcuffed", true)
	ZCNPC.ApplyCuffs(npc)

	hook.Run("ZCNPC_Cuffed", npc, org)
end

function ZCNPC.Uncuff(npc)
	if not IsValid(npc) then return end

	local org = npc.organism
	if org then org.handcuffed = false end

	npc:SetNetVar("handcuffed", false)
	ZCNPC.ClearCuffs(npc)

	hook.Run("ZCNPC_Uncuffed", npc)
end
--//

--\\ Look and behaviour of a cuffed NPC
local function Disarm(npc)
	local rag = IsValid(npc.zcnpc_rag) and npc.zcnpc_rag

	if rag then
		ZCNPC.DropWeapon(npc, ZCNPC.HandDrop(rag))

		local info = ZCNPC.Downed[rag]
		if info then ZCNPC.TakeLoot(rag, info, info.wepclass) end

		return
	end

	ZCNPC.DropWeapon(npc, npc:GetPos() + npc:OBBCenter(), AngleRand())
end

-- Also used when a cuffed NPC gets back on its feet
function ZCNPC.ApplyCuffs(npc)
	if not IsValid(npc) or ZCNPC.Cuffed[npc] then return end
	ZCNPC.Cuffed[npc] = true

	npc.zcnpc_caps = npc:CapabilitiesGet()
	npc:CapabilitiesClear()
	npc:CapabilitiesAdd(bit.bor(CAP_MOVE_GROUND, CAP_ANIMATEDFACE, CAP_TURN_HEAD))

	npc:SetNPCState(NPC_STATE_IDLE)
	if npc.ClearEnemyMemory then npc:ClearEnemyMemory() end
	npc:SetSchedule(SCHED_IDLE_STAND)

	Disarm(npc)

	npc:EmitSound("weapons/357/357_reload3.wav")

	ZCNPC.Debug("cuffed", npc, npc:GetClass())
end

function ZCNPC.ClearCuffs(npc)
	if not ZCNPC.Cuffed[npc] then return end
	ZCNPC.Cuffed[npc] = nil

	if not IsValid(npc) then return end

	if npc.zcnpc_caps then
		npc:CapabilitiesClear()
		npc:CapabilitiesAdd(npc.zcnpc_caps)
		npc.zcnpc_caps = nil
	end

	-- a body on the ground is meant to stay in NPC_STATE_NONE until it wakes up
	if not IsValid(npc.zcnpc_rag) then npc:SetNPCState(NPC_STATE_ALERT) end
end
--//

--\\ Cuffing an NPC that is still on its feet.
-- The SWEP plays its own animation and then quietly fails on a living NPC, so we
-- only have to mirror its timing.
hook.Add("KeyPress", "zcnpc_cuff", function(ply, key)
	if key ~= IN_ATTACK then return end
	if (ply.zcnpc_cuffcd or 0) > CurTime() then return end

	local wep = ply:GetActiveWeapon()
	if not (IsValid(wep) and wep:GetClass() == "weapon_handcuffs") then return end

	local npc = TracedNPC(ply)
	if not (npc and ZCNPC.CanCuff(npc)) then return end

	ply.zcnpc_cuffcd = CurTime() + CUFF_TIME + 0.5

	timer.Simple(CUFF_TIME, function()
		if not (IsValid(ply) and ply:Alive() and IsValid(wep) and wep:GetOwner() == ply) then return end
		if not ZCNPC.CanCuff(npc) then return end
		if ply:GetPos():DistToSqr(npc:GetPos()) > 500 * 500 then return end -- same slack as SWEP:Tie

		ZCNPC.Cuff(npc)

		ply:ChatPrint("Threat handcuffed.")
		ply:SelectWeapon("weapon_hands_sh")
		wep:Remove()
	end)
end)
--//

--\\ Cuffs follow the organism between body and NPC
-- hg.handcuff spawns a loose prop that only follows a bone, so it would be left
-- hanging in mid air once the body is gone (on a player Z-City just makes a new pair
-- for the next ragdoll and forgets this one).
local function BindCuffProps(rag)
	if rag.zcnpc_cuffbound or not istable(rag.handcuffs) then return end

	rag.zcnpc_cuffbound = true

	for _, ent in ipairs(rag.handcuffs) do
		if IsValid(ent) then rag:DeleteOnRemove(ent) end
	end
end

hook.Add("ZCNPC_Downed", "zcnpc_cuffs", function(npc, rag, org)
	ZCNPC.ClearCuffs(npc) -- the body wears them from here on
	npc:SetNetVar("handcuffed", false)

	if not (cfg.cuffs:GetBool() and org and org.handcuffed) then return end
	if not isfunction(hg.handcuff) then return end

	rag:SetNetVar("handcuffed", true)
	hg.handcuff(rag)
	BindCuffProps(rag)
end)

-- The same levitating prop the gun used to be, and for the same reason. hg.handcuff
-- does not parent its pair to the body, it spawns a loose prop_physics that follows
-- a hand bone (weapon_handcuffs.lua:115), so it is a separate entity with its own
-- visibility - and hiding the body for the length of the get up (cl_getup.lua) hides
-- the body and nothing else. What was left was a pair of handcuffs lying in the air
-- above the floor where the wrists used to be, while the NPC stood up out of them
-- wearing a second pair of its own.
--
-- Hidden rather than removed, and not put back: the body itself is taken away a
-- tenth of a second after the animation ends and takes these with it (BindCuffProps
-- above), so there is nothing left for them to follow either way.
hook.Add("ZCNPC_GetUp", "zcnpc_cuffs", function(_, rag)
	for _, ent in ipairs(IsValid(rag) and rag.handcuffs or {}) do
		-- the pair travels with the weld that holds the wrists together, which is a
		-- constraint and has nothing to draw
		if IsValid(ent) and ent:GetClass() == "prop_physics" then ent:SetNoDraw(true) end
	end
end)

hook.Add("ZCNPC_WokeUp", "zcnpc_cuffs", function(npc, org)
	-- somebody may well have unlocked the cuffs while the body was on the
	-- ground, so the netvar is set either way rather than only when it is true
	local cuffed = cfg.cuffs:GetBool() and org ~= nil and org.handcuffed == true
	npc:SetNetVar("handcuffed", cuffed)

	if cuffed then ZCNPC.ApplyCuffs(npc) end
end)

-- Z-City drops org.handcuffed on a cleared organism (weapon_handcuffs.lua:179), the
-- pose and the prop have to go with it
hook.Add("Org Clear", "zcnpc_cuffs", function(org)
	local owner = org and org.owner
	if IsValid(owner) and ZCNPC.Cuffed[owner] then ZCNPC.ClearCuffs(owner) end
end)
--//

--\\ Keeping detainees docile, and the key working on them
local nextCuffBind = 0

timer.Create("zcnpc_cuffs", 0.2, 0, function()
	if next(ZCNPC.Cuffed) then
		for npc in pairs(ZCNPC.Cuffed) do
			if not IsValid(npc) then
				ZCNPC.Cuffed[npc] = nil
				continue
			end

			-- HL2 AI keeps picking its fights back up on its own
			if IsValid(npc:GetEnemy()) then
				npc:ClearEnemyMemory()
				npc:SetNPCState(NPC_STATE_IDLE)
				npc:SetSchedule(SCHED_IDLE_STAND)
			end
		end
	end

	-- Stock SWEP cuffs on a body that skipped our hook: catch-up every 2s instead
	-- of walking every Downed rag every 0.2s.
	local now = CurTime()
	if now >= nextCuffBind and ZCNPC.Downed and next(ZCNPC.Downed) then
		nextCuffBind = now + 2
		for rag in pairs(ZCNPC.Downed) do
			if IsValid(rag) then BindCuffProps(rag) end
		end
	end

	if not (ZCNPC.Enabled() and cfg.cuffs:GetBool()) then return end
	if not next(ZCNPC.Cuffed) then return end

	for _, ply in player.Iterator() do
		local wep = ply:GetActiveWeapon()

		if not (IsValid(wep) and wep:GetClass() == "weapon_handcuffs_key" and ply:KeyDown(IN_ATTACK)) then
			ply.zcnpc_uncuff = nil
			continue
		end

		local npc = TracedNPC(ply)
		if not (npc and ZCNPC.Cuffed[npc]) then
			ply.zcnpc_uncuff = nil
			continue
		end

		if ply.zcnpc_uncuff ~= npc then
			ply.zcnpc_uncuff = npc
			ply.zcnpc_uncufftime = CurTime() + UNCUFF_TIME
			continue
		end

		if (ply.zcnpc_uncufftime or 0) > CurTime() then continue end
		ply.zcnpc_uncuff = nil

		ZCNPC.Uncuff(npc)
		npc:EmitSound("weapons/357/357_reload1.wav")
		ply:Give("weapon_handcuffs")
	end
end)
--//
