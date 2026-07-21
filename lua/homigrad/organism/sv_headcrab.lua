
local PLAYER = FindMetaTable("Player")
util.AddNetworkString("hg_headcrab")
function PLAYER:AddHeadcrab(headcrab)
	if self.PlayerClassName == "headcrabzombie" then return end
	if not self.organism then return end

	-- The headcrab's forced 0.3 brain damage must not overwrite trauma the
	-- victim already had. Keep only the amount the headcrab itself added so a
	-- later removal cannot erase a gunshot or older brain injury.
	self.organism.headcrabBrainDamage = math.max(0.3 - (self.organism.brain or 0), 0)
    --self.organism.headcrabon = headcrab
    self:SetNetVar("headcrab",headcrab)
   
    self.organism.headcrabon = headcrab and CurTime()
	self.organism.headcrabevent = false
	self.organism.headcrabPainSoundAt = nil

    --[[net.Start("hg_headcrab")
    net.WriteEntity(self)
    net.WriteString(headcrab)
    net.Broadcast()--]]
end

function PLAYER:RemoveHeadcrabFromTrauma()
	local org = self.organism
	if not org or not self:GetNetVar("headcrab") then return false end

	-- Remove only the damage imposed by the headcrab. Any prior injury and any
	-- new wound from the shot remain part of the recovery calculation.
	org.brain = math.max((org.brain or 0) - (org.headcrabBrainDamage or 0), 0)
	org.headcrabBrainDamage = nil
	org.headcrabon = nil
	org.headcrabevent = false
	org.headcrabPainSoundAt = nil
	org.noHead = false
	self.noHead = false
	self:SetNWString("PlayerName", "")
	self:SetNetVar("headcrab", false)

	local rag = hg.GetCurrentCharacter and hg.GetCurrentCharacter(self)
	if IsValid(rag) then
		rag:SetNetVar("headcrab", false)
	end

	-- A violent removal can partially undo real brain trauma, including trauma
	-- that existed before the headcrab attached. It is deliberately only a
	-- chance and heals every persisted brain field by the same proportion.
	if math.Rand(0, 1) <= 0.3 then
		local recovery = math.Rand(0.2, 0.4)
		local brainFields = {
			"brain", "brainFrontal", "brainParietal", "brainTemporal",
			"brainOccipital", "brainHemorrhage", "brainBleedRate"
		}
		for _, key in ipairs(brainFields) do
			org[key] = math.max((org[key] or 0) * (1 - recovery), 0)
		end
	end

	return true
end

hook.Add("RagdollDeath","headcrab",function(ply,rag)
    rag:SetNetVar("headcrab", ply:GetNetVar("headcrab"))
    ply:SetNetVar("headcrab", false)
	ply.organism.noHead = false
	ply.noHead = false
end)

hook.Add("Org Clear", "removeheadcrab", function(org)
    org.headcrabon = nil
	org.headcrabevent = false
	org.headcrabBrainDamage = nil
	org.headcrabPainSoundAt = nil
	if IsValid(org.owner) then
		org.owner:SetNetVar("headcrab", false)
		org.owner.noHead = false
	end
	org.noHead = false
end)

local fallbackMats = {
	["Rebel"] = {
		["main"] = "models/zombie_classic/zombie_classic_sheet",
		["pants"] = "models/zombie_classic/zombie_classic_sheet",
		["boots"] = "models/zombie_classic/zombie_classic_sheet",
	},
	["Metrocop"] = {
		["main"] = "models/balaclava_hood/berd_diff_018_a_uni",
		["pants"] = "models/humans/male/group02/lambda",
		["boots"] = "models/humans/male/group01/formal"
	},
	["Combine"] = {
		["main"] = "models/zombie_classic/combinesoldiersheet_zombie",
		["pants"] = "models/gruchk_uwrist/css_seb_swat/swat/gear2",
		["boots"] = "models/humans/male/group01/formal"
	},
}

local clr_red, lerpAng = Color(150, 0, 0), Angle(0, 0, 0)
hook.Add("Org Think", "Headcrab",function(owner, org, timeValue)
    if not IsValid(owner) then return end
    if not owner:IsPlayer() or not owner:Alive() then return end

    if org.headcrabon and (org.headcrabon + 30) < CurTime() and org.brain != 1 and owner.organism.spine3 != 1 then
		local ent = hg.GetCurrentCharacter(owner) or owner
		local mul = ((org.headcrabon + 60) - CurTime()) / 60
		if mul > 0 then
			ent:GetPhysicsObjectNum(math.random(ent:GetPhysicsObjectCount()) - 1):ApplyForceCenter(VectorRand(-750 * mul,750 * mul))
		end
	end

    if owner:IsPlayer() then
		if org.headcrabon then
			owner.noHead = true
			owner:SetNWString("PlayerName", "Body with headcrab")
			org.brain = math.max(org.brain or 0, 0.3)

			if org.alive then
				lerpAng = LerpAngle(FrameTime() * 3, lerpAng, AngleRand(-90, 90))
				lerpAng.r = 0
				owner:SetEyeAngles(owner:EyeAngles() + lerpAng)
			end

			if (org.headcrabon + 60) < CurTime() and org.alive and not org.headcrabevent then
				owner:EmitSound("npc/zombie/zombie_alert" .. math.random(3) .. ".wav", 80, math.random(60, 70))
				owner:EmitSound("neck_snap_01.wav", 80, 80, 1, CHAN_AUTO)
				owner:SetPlayerClass("headcrabzombie")
				org.painadd = org.painadd + 5

				hg.StunPlayer(owner, 5)
				if zb and zb.GiveRole then
					zb.GiveRole(owner, "Zombie", clr_red)
				end

				org.headcrabevent = true
				org.headcrabon = nil
				org.headcrabevent = false
				org.noHead = false

				hg.FakeUp(owner, true)
				owner:SetNetVar("headcrab", false)
			end
		end

		if org.alive and org.headcrabon and (org.headcrabon + 20) < CurTime() then
			if (org.headcrabon + 30) > CurTime() and (org.headcrabPainSoundAt or 0) <= CurTime() then
				owner:EmitSound("npc/zombie/zombie_pain"..math.random(6)..".wav", 80, math.random(80, 90))
				org.painadd = org.painadd + 15
				hg.StunPlayer(owner, 5)
				org.headcrabPainSoundAt = CurTime() + 4
			end
		end

        if org.alive and org.headcrabon and (org.headcrabon + 60) < CurTime() then
			owner:SetNWString("PlayerName", "Body with headcrab")
			org.alive = false
		end
    end
end)
