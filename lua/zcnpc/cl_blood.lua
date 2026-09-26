--[[
	Throttle Z-City blood particles and the client organism think on NPCs.

	The organism wound loop (cl_main.lua Player-Ragdoll think) spawns a droplet
	per wound on a timer, and arterial wounds fire even harder. With a handful of
	bleeding NPCs that fills hg.bloodparticles1 every frame - each particle does
	a TraceLine, lighting samples and often a decal - and the framerate falls over.

	The same hook is worse than the spray. Z-City walks every seen ragdoll and
	every NPC it ever sent an organism for, every frame, and for each one it
	lerps the whole stats table and ManipulateBoneScale's the chest (breathing).
	That scale call dumps the bone cache, so three standing NPCs in a room are
	three extra SetupBones a frame on top of the lerp. Z-City even wrote a 0.1s
	limiter for anyone who is not you (cl_utility.lua:436) and left it commented
	out. Players keep the full think; NPCs get the wound/lerp half only when they
	are actually bleeding, at that 0.1s. The chest breathing is a cheap pass of
	its own — scale only, no lerp — so a healthy NPC still looks like it is
	breathing without the rest of the think.

	Dead NPC bodies stay in that loop the same way living ones do: if they
	still have wounds they still spray. The throttle below is how much, not
	whether.
]]

ZCNPC = ZCNPC or {}

local mulCvar
local PARTICLE_SOFT = 70
local PARTICLE_HARD = 120

-- Same distance Z-City's own think already bails at (cl_main.lua:712), asked
-- before the lerp / bone scale instead of after.
local FAR_SQR = 450 * 450

-- Z-City's commented limiter for everyone who is not the local player.
local WOUND_THINK = 0.1

local function BloodMul()
	if not mulCvar then
		mulCvar = GetConVar("zcnpc_blood_mul")
	end

	if not mulCvar then return 0.6 end

	return mulCvar:GetFloat()
end

local function ParticleCount()
	local n1 = istable(hg) and hg.bloodparticles1 and #hg.bloodparticles1 or 0
	local n2 = istable(hg) and hg.bloodparticles2 and #hg.bloodparticles2 or 0

	return n1 + n2
end

-- Standing NPC, our downed rag, or any ragdoll whose organism still belongs to an NPC.
local function IsNpcBloodOwner(owner)
	if not IsValid(owner) then return false end

	if owner:IsNPC() then return true end
	if owner.zcnpc_npcbody then return true end
	if owner.zcnpc_corpse then return true end
	if owner.GetNWBool and owner:GetNWBool("zcnpc_corpse", false) then return true end

	local linked = owner.zcnpc_npc
	if IsValid(linked) and linked:IsNPC() then return true end

	local org = owner.organism
	local orgOwner = org and org.owner
	if IsValid(orgOwner) and orgOwner:IsNPC() then return true end
	if org and org.fakePlayer and owner:IsRagdoll() then return true end

	return false
end

local function DeadNpcBody(ent)
	if not IsValid(ent) then return false end
	if ent:IsPlayer() then return false end
	if ent.zcnpc_parked then return true end
	if ent.zcnpc_corpse or (ent.GetNWBool and ent:GetNWBool("zcnpc_corpse", false)) then
		return true
	end

	local org = ent.organism or ent.new_organism
	if not (istable(org) and org.alive == false) then return false end
	if not ent:IsRagdoll() then return false end
	if org.fakePlayer or ent.zcnpc_npcbody then return true end

	return false
end

-- Something the client think actually has to do: drip, spray, or finish dying.
-- A healthy standing NPC has none of this, and the chest-scale "breathing" is
-- a player visual that is not worth a bone-cache dump per NPC per frame.
local function NeedsClientOrg(ent)
	if not IsValid(ent) then return false end

	local org = ent.organism or ent.new_organism
	if istable(org) then
		if (org.bleed or 0) > 0.15 then return true end
		if (org.internalBleed or 0) > 0 then return true end
		if (org.arteria or 0) > 0 then return true end
	end

	local wounds = ent.wounds or (org and org.wounds)
	if istable(wounds) and wounds[1] then return true end

	local arterial = ent.arterialwounds or (org and org.arterialwounds)
	if istable(arterial) and next(arterial) ~= nil then return true end

	return false
end

local function SkipNpcThink(ply, ent)
	if not (IsNpcBloodOwner(ent) or IsNpcBloodOwner(ply)) then return false end

	local lp = LocalPlayer()
	if IsValid(lp) and IsValid(ent) and ent:GetPos():DistToSqr(lp:GetPos()) > FAR_SQR then
		return true
	end

	if not NeedsClientOrg(ent) and not (IsValid(ply) and NeedsClientOrg(ply)) then
		return true
	end

	local now = CurTime()
	if (ent.zcnpc_orgthink_at or 0) > now then return true end

	ent.zcnpc_orgthink_at = now + WOUND_THINK

	return false
end

-- Same chest scale Z-City writes in cl_main.lua:711. Done here so a healthy NPC
-- still breathes after we take it out of the full think. 20 Hz is enough for a
-- slow sine; dt is the interval, not FrameTime, or the wave would run slow.
local BREATHE = 1 / 20
local vecTorso = Vector(1, 1, 1)
local nextBreathe = 0

local function BreathEnt(ent, dt)
	if not IsValid(ent) or ent:IsDormant() then return end

	local torso = ent.zcnpc_torsobone
	if torso == nil then
		torso = ent:LookupBone("ValveBiped.Bip01_Spine2") or false
		ent.zcnpc_torsobone = torso
	end
	if not torso then return end

	if DeadNpcBody(ent) then
		vecTorso[1], vecTorso[2], vecTorso[3] = 1, 1, 1
		ent:ManipulateBoneScale(torso, vecTorso)

		return
	end

	local lp = LocalPlayer()
	if IsValid(lp) and ent:GetPos():DistToSqr(lp:GetPos()) > FAR_SQR then return end

	local org = ent.organism
	if not (istable(org) and org.pulse and istable(org.o2) and org.o2[1]) then return end

	local live = (org.alive ~= false and not ent.headexploded) and 1 or 0
	if live == 0 then
		vecTorso[1], vecTorso[2], vecTorso[3] = 1, 1, 1
		ent:ManipulateBoneScale(torso, vecTorso)

		return
	end

	org.pulsethink = org.pulsethink or 0

	local heartbeat = org.heartbeat or 0
	local speed = math.Clamp(heartbeat / 60, 1, 3.3) * 0.5 * ((org.o2[1] < 8) and 0 or 1)
	org.pulsethink = org.pulsethink
		+ (heartbeat > 1 and 1 or 0)
		* (org.holdingbreath and 0 or 1)
		* dt * 5.6 * speed
		* (org.lungsfunction and 1 or 0)
		* live

	local sin = (math.sin(org.pulsethink) + 1) * 0.5
	local amt = 0.05 * sin * math.max((org.pulse or 70) / 70, 0.5)
	local size = 1 + amt
	vecTorso[1] = size
	vecTorso[2] = size
	vecTorso[3] = size
	ent:ManipulateBoneScale(torso, vecTorso)
end

hook.Add("Think", "zcnpc_breathe", function()
	local now = CurTime()
	if now < nextBreathe then return end

	nextBreathe = now + BREATHE

	if istable(hg) and istable(hg.organism_ents) then
		for ent in pairs(hg.organism_ents) do
			if IsValid(ent) and ent:IsNPC() then
				BreathEnt(ent, BREATHE)
			end
		end
	end

	local bodies = ZCNPC.Bodies
	if not bodies then return end

	for _, rag in pairs(bodies) do
		if IsValid(rag) then
			BreathEnt(rag, BREATHE)
		end
	end
end)

local function ShouldKeepNPCBlood(owner)
	-- The convar is on this client whether or not the server is running the addon
	-- (sh_settings.lua), and thinning Z-City's own blood on behalf of an addon that is
	-- not there is not ours to do.
	if ZCNPC.Running and not ZCNPC.Running() then return true end

	local load = ParticleCount()
	if load >= PARTICLE_HARD then return false end
	if load >= PARTICLE_SOFT and math.random() > 0.25 then return false end

	local mul = BloodMul()
	if mul <= 0 then return false end
	if mul >= 1 then return true end

	return math.random() <= mul
end

local function WrapBlood()
	if not istable(hg) then return false end
	if not (isfunction(hg.addBloodPart) and isfunction(hg.addBloodPart2)) then return false end
	if ZCNPC._bloodWrapped then return true end

	local old1 = hg.addBloodPart
	local old2 = hg.addBloodPart2

	hg.addBloodPart = function(pos, vel, mat, w, h, artery, kishki, owner)
		if IsNpcBloodOwner(owner) and not ShouldKeepNPCBlood(owner) then return end

		return old1(pos, vel, mat, w, h, artery, kishki, owner)
	end

	hg.addBloodPart2 = function(pos, vel, mat, w, h, time, water, owner)
		if IsNpcBloodOwner(owner) and not ShouldKeepNPCBlood(owner) then return end

		return old2(pos, vel, mat, w, h, time, water, owner)
	end

	ZCNPC._bloodWrapped = true

	return true
end

-- Z-City's wound / pulse think runs on every seen ragdoll and every NPC in
-- organism_ents. A healthy one does not need a heartbeat scale. A wounded one
-- does not need it sixty times a second.
local function WrapRagdollThink()
	if ZCNPC._ragThinkWrapped then return true end

	local list = hook.GetTable()["Player-Ragdoll think"]
	local old = list and list["organism-think-client-blood"]
	if not isfunction(old) then return false end

	hook.Add("Player-Ragdoll think", "organism-think-client-blood", function(ply, ent, time, dtime)
		if SkipNpcThink(ply, ent) then return end

		return old(ply, ent, time, dtime)
	end)

	ZCNPC._ragThinkWrapped = true

	return true
end

local function Install()
	local blood = WrapBlood()
	local think = WrapRagdollThink()

	return blood and think
end

-- Ragdolls are already in Z-City's prop_ragdoll scan. Hidden husks are skipped
-- by FakeRagdoll. Leaving either in organism_ents just doubles the FOV walk.
-- Idle standing NPCs stay: taking them out would also take their blood think
-- away the moment they get shot, until the next organism_send.
timer.Create("zcnpc_orgents_trim", 1, 0, function()
	if not (istable(hg) and istable(hg.organism_ents)) then return end

	for ent in pairs(hg.organism_ents) do
		if not IsValid(ent) or ent:IsRagdoll() or IsValid(ent.FakeRagdoll) then
			hg.organism_ents[ent] = nil
		end
	end
end)

if not Install() then
	hook.Add("HomigradRun", "zcnpc_blood", function()
		timer.Simple(0, Install)
	end)
	hook.Add("InitPostEntity", "zcnpc_blood", function()
		timer.Simple(0, Install)
	end)
	timer.Create("zcnpc_blood_retry", 1, 0, function()
		if Install() then timer.Remove("zcnpc_blood_retry") end
	end)
end
