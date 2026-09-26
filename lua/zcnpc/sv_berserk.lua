--[[
	Fury-13's killstreak, for NPCs.

	Z-City only adds berserk when the thing that died is a player
	(organism/tier_1/sv_organism.lua "Berserk"). An NPC that goes down the same
	way - brain gone, organism finished - is not Alive() in that sense, so the
	stim never noticed it. The toggle is the whole of the request: count those
	too, or leave the stock rule alone.
]]

local cfg = ZCNPC.Config

local NUMERICAL = {
	"One.", "Two.", "Three.", "Four.", "Five.",
	"Six.", "Seven.", "Eight.", "Nine.", "Ten.",
	"Eleven.", "Twelve.", "Thirteen.", "Fourteen.", "Fifteen.",
	"Sixteen.", "Seventeen.", "Eighteen.", "Nineteen.", "Twenty.",
}

local function Dead(ent)
	if not IsValid(ent) then return true end

	local org = ZCNPC.ResolveOrganism and ZCNPC.ResolveOrganism(ent) or ent.organism
	if org then
		if org.alive == false then return true end
		if (org.brain or 0) >= 1 then return true end
	end

	if ent:IsNPC() then return ent:Health() <= 0 end
	if ent:IsPlayer() then return not ent:Alive() end

	return false
end

local function Credit(attacker)
	if not (IsValid(attacker) and attacker:IsPlayer()) then return end
	if not attacker.organism then return end
	if attacker.IsBerserk and not attacker:IsBerserk() then return end

	attacker.BerserkKills = (attacker.BerserkKills or 0) + 1
	attacker.organism.berserk = (attacker.organism.berserk or 0) + 0.5

	if attacker.NotifyBerserk then
		attacker:NotifyBerserk(NUMERICAL[attacker.BerserkKills] or (attacker.BerserkKills .. "."))
	end

	ZCNPC.Debug("fury killstreak", attacker, attacker.BerserkKills)
end

local function Count(victim, dmgInfo)
	if not (cfg.fury_npc_kills and cfg.fury_npc_kills:GetBool()) then return end
	if not ZCNPC.Enabled() then return end

	local attacker = IsValid(dmgInfo) and dmgInfo:GetAttacker()
	if not (IsValid(attacker) and attacker:IsPlayer()) then return end
	if attacker == victim then return end
	if not (victim:IsNPC() or victim.zcnpc_npcbody) then return end

	if victim.zcnpc_furykill then return end
	victim.zcnpc_furykill = true

	timer.Simple(0, function()
		if not Dead(victim) then
			victim.zcnpc_furykill = nil

			return
		end

		Credit(attacker)
	end)
end

hook.Add("HomigradDamage", "zcnpc_fury_npckills", function(victim, dmgInfo)
	Count(victim, dmgInfo)
end)

hook.Add("OnNPCKilled", "zcnpc_fury_npckills", function(npc, attacker)
	if not (cfg.fury_npc_kills and cfg.fury_npc_kills:GetBool()) then return end
	if not (IsValid(npc) and IsValid(attacker) and attacker:IsPlayer()) then return end
	if npc.zcnpc_furykill then return end

	npc.zcnpc_furykill = true
	Credit(attacker)
end)
