--[[
	An NPC that is lying on the ground should also sound like it.

	The entity itself never moves while it is down - it is hidden and frozen on the
	spot it collapsed on, and the body is a separate ragdoll that slides, rolls and
	gets dragged around. Everything the engine still plays on the NPC (idle chatter,
	pain, alert calls) therefore comes out of thin air where it used to stand, which
	is the one thing that gives the whole illusion away.

	Two halves: sounds that do play are moved onto the body, and a body that is out
	cold stops making them at all. On top of that the hidden entity is kept on the
	body's spot, so anything positional that does not pass through here (the world
	model of the gun in its hand, PVS, Z-City's own visibility culling) lines up too.
]]

--\\ Where the voice comes from
-- Phys bone first: on a server ragdoll GetBoneMatrix / GetBonePosition often sit
-- on the torso even when the head has rolled away. The head phys object is the
-- one that actually moves with the skull.
function ZCNPC.BodyVoicePos(ent)
	if not IsValid(ent) then return vector_origin end

	-- Mouth first. Living NPCs spatialize from the entity origin (the
	-- feet) unless we move the point; the attachment is the actual mouth.
	local att = ent.zcnpc_voice_att
	if att == nil then
		att = ent:LookupAttachment("mouth")
		if not (isnumber(att) and att > 0) then
			att = ent:LookupAttachment("anim_attachment_head")
		end
		if not (isnumber(att) and att > 0) then att = false end
		ent.zcnpc_voice_att = att
	end
	if att then
		local a = ent:GetAttachment(att)
		if a and isvector(a.Pos) then return a.Pos end
	end

	local bone = ent.zcnpc_voice_bone
	if bone == nil then
		bone = ent:LookupBone("ValveBiped.Bip01_Head1")
			or ent:LookupBone("ValveBiped.Bip01_Neck1")
			or ent:LookupBone("ValveBiped.Bip01_Spine2")
			or false
		ent.zcnpc_voice_bone = bone
	end
	if not bone then return ent:WorldSpaceCenter() end

	-- Phys bone first on a ragdoll: GetBoneMatrix often sits on the torso
	-- even when the head has rolled away.
	if ent:IsRagdoll() then
		local physBone = ent.zcnpc_voice_phys
		if physBone == nil then
			physBone = ent:TranslateBoneToPhysBone(bone)
			ent.zcnpc_voice_phys = physBone
		end

		local phys = physBone and physBone >= 0 and ent:GetPhysicsObjectNum(physBone)
		if IsValid(phys) then return phys:GetPos() end
	end

	local matrix = ent:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation() end

	local pos, _ = ent:GetBonePosition(bone)
	if isvector(pos) then return pos end

	return ent:WorldSpaceCenter()
end

local function VoicePos(rag)
	return ZCNPC.BodyVoicePos(rag)
end

-- Finished, not just out cold. A downed body can still cough blood; a corpse
-- cannot, and the organism keeps thinking on one (TransferOrganismToCorpse).
function ZCNPC.IsBodyDead(org)
	if not org then return false end
	if org.alive == false then return true end
	if (org.brain or 0) >= 1 then return true end
	if org.headamputated then return true end

	return false
end

-- Out cold, so it has nothing to say. Deliberately not the same test as
-- ZCNPC.HoldsWeapon: a body can be too weak to keep hold of a rifle and still groan.
--
-- org.fake is NOT silence. Every downed body has fake set (the organism wants it
-- on the floor), and treating that as mute was why conscious writhing looked like
-- it was talking - mouth moved - while nothing came out.
function ZCNPC.IsBodySilent(org)
	if not org then return false end
	if ZCNPC.IsBodyDead(org) then return true end
	if org.otrub then return true end
	if (org.consciousness or 1) <= 0.4 then return true end

	return false
end

local function Silent(org)
	return ZCNPC.IsBodySilent(org)
end

-- HL2 pain / chatter (vo/npc, player/pl_pain, ...). Physics, gore, and ArtAgdoll's
-- own SFX/ tree are left alone - the latter has "death" / "die" in the folder
-- name and would otherwise get caught as voice.
local function IsVoiceSound(name)
	if not isstring(name) or name == "" then return false end

	-- Cheap rejects before lowercasing the whole path (fires on every world sound).
	local c1 = string.byte(name, 1)
	if c1 == 115 or c1 == 83 then -- s/S — sfx/
		local pref = string.sub(name, 1, 4)
		if pref == "sfx/" or pref == "SFX/" or pref == "Sfx/" then return false end
	end

	name = string.lower(name)
	if string.sub(name, 1, 1) == "^" then name = string.sub(name, 2) end
	if string.sub(name, 1, 4) == "sfx/" then return false end
	if string.sub(name, 1, 3) == "vo/" then return true end
	if string.find(name, "pain", 1, true) then return true end
	if string.find(name, "moan", 1, true) then return true end
	if string.find(name, "scream", 1, true) then return true end
	if string.find(name, "die", 1, true) then return true end
	if string.find(name, "death", 1, true) then return true end

	return false
end

local function IsCoughSound(name)
	if not isstring(name) or name == "" then return false end

	name = string.lower(name)
	if string.find(name, "cough", 1, true) then return true end
	if string.find(name, "vomit", 1, true) then return true end

	return false
end

local function IsDeathVoice(name)
	if not isstring(name) or name == "" then return false end

	name = string.lower(name)
	if string.sub(name, 1, 1) == "^" then name = string.sub(name, 2) end
	if string.find(name, "die", 1, true) then return true end
	if string.find(name, "death", 1, true) then return true end

	return false
end

-- Event_Killed plays the death line on the NPC before CreateEntityRagdoll.
-- Hold it and replay on the body so it is not left hanging where they stood.
function ZCNPC.QueueVoice(ent, data)
	if not IsValid(ent) then return end

	ent.zcnpc_pendingvoice = {
		name = data.SoundName or data.OriginalSoundName,
		level = data.SoundLevel or 75,
		pitch = data.Pitch or 100,
		volume = data.Volume or 1,
		channel = data.Channel or CHAN_VOICE,
	}
end

function ZCNPC.FlushVoice(ent, rag)
	local pending = IsValid(ent) and ent.zcnpc_pendingvoice
	if IsValid(ent) then ent.zcnpc_pendingvoice = nil end
	if not (pending and isstring(pending.name) and pending.name ~= "" and IsValid(rag)) then
		return
	end

	rag:EmitSound(pending.name, pending.level, pending.pitch, pending.volume, pending.channel)
end

hook.Add("EntityEmitSound", "zcnpc_bodysound", function(data)
	local ent = data.Entity
	if not IsValid(ent) then return end
	if not ZCNPC.Enabled() then return end

	local soundName = data.SoundName or data.OriginalSoundName
	local voice = IsVoiceSound(soundName) or IsCoughSound(soundName)

	local rag = ent.zcnpc_rag
	local ours = IsValid(rag) or ent.zcnpc_headkill or ent.zcnpc_corpse or ent.zcnpc_dead
		or (ZCNPC.Downed and ZCNPC.Downed[ent])
		or (ZCNPC.ActiveBodies and ZCNPC.ActiveBodies[ent])
		or (ent.organism and ent.organism.fakePlayer)
		or (ent:IsNPC() and istable(ent.organism))
		or (ent:IsRagdoll() and IsValid(ent.zcnpc_npc))
	if not ours then return end

	-- Lethal head shot: still standing for a tick under GODMODE, and HL2 loves to
	-- fire citizen pain lines on that hit. No voice from a finished head - standing
	-- or already on the floor.
	if ent.zcnpc_headkill and voice then
		return false
	end

	local org = ent.organism
	local deathLine = voice and IsDeathVoice(soundName)

	-- Dead organism leftover chatter is mute. A death line belongs on the
	-- corpse, not at the husk origin — that is the metrocop "die" hanging
	-- where they stood while the body is already on the floor.
	if org and ZCNPC.IsBodyDead(org) and voice and not deathLine then
		return false
	end
	if org and Silent(org) and IsVoiceSound(soundName) and not deathLine then
		return false
	end

	if ent:IsRagdoll() then
		data.Pos = VoicePos(ent)

		return true
	end

	if voice and IsValid(rag) then
		data.Entity = rag
		data.Pos = VoicePos(rag)

		return true
	end

	-- No body yet: Event_Killed is earlier than CreateEntityRagdoll.
	if deathLine and ent:IsNPC() then
		ZCNPC.QueueVoice(ent, data)

		return false
	end

	-- Living NPC: mouth, not the feet.
	if voice and ent:IsNPC() then
		data.Pos = VoicePos(ent)

		return true
	end
end)
--//

--\\ Keeping the hidden entity on top of its body
-- Squared distance: anything under this is noise from the body settling.
local FOLLOW_STEP = 16

function ZCNPC.FollowBody(npc, rag)
	if not (IsValid(npc) and IsValid(rag)) then return end

	local pelvis = rag.zcnpc_pelvis_bone
	if pelvis == nil then
		pelvis = rag:LookupBone("ValveBiped.Bip01_Pelvis") or false
		rag.zcnpc_pelvis_bone = pelvis
	end

	local from = rag:GetPos()

	if pelvis then
		local physBone = rag.zcnpc_pelvis_phys
		if physBone == nil then
			physBone = rag:TranslateBoneToPhysBone(pelvis)
			rag.zcnpc_pelvis_phys = physBone
		end

		local phys = physBone and physBone >= 0 and rag:GetPhysicsObjectNum(physBone)
		if IsValid(phys) then from = phys:GetPos() end
	end

	-- Body has not moved since the last follow: skip the floor TraceLine.
	local lastFrom = npc.zcnpc_follow_from
	if lastFrom and lastFrom:DistToSqr(from) < FOLLOW_STEP then return end

	-- the NPC's origin sits at its feet, so it belongs on the floor under the body
	local tr = util.TraceLine({
		start = from + vector_up * 8,
		endpos = from - vector_up * 128,
		mask = MASK_SOLID,
		filter = { npc, rag },
	})

	local pos = tr.Hit and tr.HitPos or Vector(from.x, from.y, from.z - 36)
	if npc:GetPos():DistToSqr(pos) < FOLLOW_STEP then
		npc.zcnpc_follow_from = from

		return
	end

	-- MOVETYPE_NONE NPCs often ignore a bare SetPos across long drags; a one-tick
	-- noclip hop is what actually teleports the hidden entity onto its body.
	local move = npc:GetMoveType()
	npc:SetMoveType(MOVETYPE_NOCLIP)
	npc:SetPos(pos)
	npc:SetMoveType(move ~= MOVETYPE_NOCLIP and move or MOVETYPE_NONE)
	npc.zcnpc_follow_from = from
end

-- The 0.25s monitor is fine for wake/death; following a dragged body needs to be
-- frequent, but not every Think when nothing is moving.
local nextFollow = 0
hook.Add("Think", "zcnpc_followbody", function()
	if not ZCNPC.Enabled() then return end

	local downed = ZCNPC.Downed
	if not downed or not next(downed) then return end

	local now = CurTime()
	if now < nextFollow then return end
	nextFollow = now + 0.05

	for rag, info in pairs(downed) do
		if IsValid(rag) and IsValid(info.npc) then
			ZCNPC.FollowBody(info.npc, rag)
		end
	end
end)
--//

--\\ Organism voice: blood cough + burning screams
-- Players get these from Z-City (sv_blood.lua Vomit / CoughBlood, sv_phrases
-- BurnScream). Both paths gate on IsPlayer / IsValidPlayer, so NPCs stay mute
-- while coughing blood into their lungs or cooking on the floor.
local BURN_MALE = 14
local BURN_FEMALE = 10

local function Female(ent)
	if not isfunction(ThatPlyIsFemale) then return false end

	local ok, yes = pcall(ThatPlyIsFemale, ent)

	return ok and yes == true
end

local function VoiceEnt(owner)
	if IsValid(owner.zcnpc_rag) then return owner.zcnpc_rag end
	if owner:IsRagdoll() then return owner end

	return owner
end

local function CanSpeak(owner, org)
	if not org or ZCNPC.IsBodyDead(org) then return false end
	if Silent(org) then return false end
	if (owner.zcnpc_voicescd or 0) > CurTime() then return false end

	return true
end

local function CanCough(owner, org)
	if not (IsValid(owner) and org) then return false end
	if ZCNPC.IsBodyDead(org) then return false end

	return true
end

local function PlayVoice(owner, path, cooldown)
	local ent = VoiceEnt(owner)
	if not IsValid(ent) then return end

	ent:EmitSound(path, 75, math.random(95, 105), 1, CHAN_AUTO)
	owner.zcnpc_voicescd = CurTime() + (cooldown or SoundDuration(path) or 2)
	owner.lastPhr = path
end

-- Blood cough / vomit for NPCs. Same cues Z-City uses on players when
-- internalBleed / pneumothorax fills wantToVomit, without the player Notify.
function ZCNPC.CoughBlood(owner, org)
	if not CanCough(owner, org) then return end

	local sex = Female(owner) and "female" or "male"
	local path = "zcitysnd/real_sonar/" .. sex .. "_cough" .. math.random(4) .. ".mp3"
	PlayVoice(owner, path, 2)

	if math.random(5) ~= 1 then return end

	local ent = VoiceEnt(owner)
	local bone = ent:LookupBone("ValveBiped.Bip01_Head1")
	if not bone then return end

	local mat = ent:GetBoneMatrix(bone)
	if not mat then return end

	org.vomitInThroat = nil
	ent:EmitSound("vomit/vomit5.mp3", 70, math.random(95, 105))

	net.Start("bloodsquirt2")
	net.WriteEntity(ent)
	net.WriteString("ValveBiped.Bip01_Head1")
	net.WriteMatrix(mat)
	net.WriteVector(mat:GetTranslation() + mat:GetAngles():Right() * 6 + mat:GetAngles():Forward() * 1)
	net.WriteVector(mat:GetAngles():Right() * 2 * math.Clamp((org.pulse or 70) / 70, 0.4, 1))
	net.Broadcast()
end

-- Z-City zeros wantToVomit and calls Vomit in the same think. Vomit bails on
-- anything that is not a player (sv_blood.lua:229), so the bar is spent and
-- nothing is heard. That is the whole of "blood coughing never triggers".
-- The NPC path is this file's CoughBlood, and it has to run from inside that
-- call rather than from a later hook that will never see the bar again.
local function InstallVomit()
	if not (istable(hg) and istable(hg.organism) and isfunction(hg.organism.Vomit)) then return end
	if hg.organism._ZCNPCVomit then return end

	local old = hg.organism.Vomit

	hg.organism.Vomit = function(owner, snd)
		if IsValid(owner) and not owner:IsPlayer() then
			local org = owner.organism
			if org then org.wantToVomit = 0 end
			if CanCough(owner, org) then
				ZCNPC.CoughBlood(owner, org)
			end

			return
		end

		return old(owner, snd)
	end

	hg.organism._ZCNPCVomit = true
	ZCNPC.Debug("organism Vomit wrapped for NPC blood cough")

	if isfunction(hg.organism.CoughBlood) and not hg.organism._ZCNPCCoughBlood then
		local oldCough = hg.organism.CoughBlood

		hg.organism.CoughBlood = function(org)
			local owner = org and org.owner
			if IsValid(owner) and not owner:IsPlayer() then
				if CanCough(owner, org) then
					ZCNPC.CoughBlood(owner, org)
				end

				return
			end

			if org and ZCNPC.IsBodyDead(org) then return end

			return oldCough(org)
		end

		hg.organism._ZCNPCCoughBlood = true
	end
end

InstallVomit()
hook.Add("HomigradRun", "zcnpc_vomit", function()
	timer.Simple(0, InstallVomit)
end)

hook.Add("Org Think", "zcnpc_orgsounds", function(owner, org, timeValue)
	if not ZCNPC.Enabled() then return end
	if not (IsValid(owner) and org) then return end
	if owner:IsPlayer() then return end -- Z-City owns players
	if not (owner:IsNPC() or owner:IsRagdoll()) then return end
	if ZCNPC.IsBodyDead(org) then
		org.wantToVomit = 0

		return
	end
	if not CanSpeak(owner, org) then return end

	local body = VoiceEnt(owner)
	local burning = IsValid(body) and body:IsOnFire()

	-- Burning scream: same pool as player BurnScream (sv_phrases.lua)
	if burning then
		if (org.zcnpc_burnsnd or 0) < CurTime() then
			org.zcnpc_burnsnd = CurTime() + math.Rand(2.5, 4.5)
			local female = Female(owner)
			local n = math.random(1, female and BURN_FEMALE or BURN_MALE)
			local path = "zcitysnd/" .. (female and "female" or "male") .. "/burn/death_burn" .. n .. ".mp3"
			PlayVoice(owner, path, SoundDuration(path) or 2)
		end

		return -- don't stack a cough on top of a scream this tick
	end

	-- Internal bleeding → cough / puke blood. Z-City's Vomit bails on NPCs.
	local want = org.wantToVomit or 0
	if want > 1 then
		org.wantToVomit = 0
		ZCNPC.CoughBlood(owner, org)

		return
	end

	-- Heavy external bleed still gets the odd cough without a full vomit bar
	if (org.bleed or 0) > 8 and (org.blood or 5000) < 3500 then
		if (org.zcnpc_coughcd or 0) < CurTime() and math.random(40) == 1 then
			org.zcnpc_coughcd = CurTime() + math.Rand(6, 12)
			local sex = Female(owner) and "female" or "male"
			PlayVoice(owner, "zcitysnd/" .. sex .. "/cough_" .. math.random(1, 6) .. ".mp3", 2)
		end
	elseif (org.internalBleed or 0) > 1 and (org.zcnpc_coughcd or 0) < CurTime() and math.random(25) == 1 then
		-- Internal bleed that has not filled the vomit bar yet still has to be
		-- heard, or the only cough in the game is the one Vomit already spent.
		org.zcnpc_coughcd = CurTime() + math.Rand(8, 16)
		ZCNPC.CoughBlood(owner, org)
	end
end)
--//
