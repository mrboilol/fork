CAI.WeaponIntel = CAI.WeaponIntel or {}
local WI = CAI.WeaponIntel

local archetypeCache = {}

-- Z-City NPC Overhaul already knows what every gun in the pack is (sh_npcweapons.lua);
-- its roles are asked first and mapped onto ours.
local ROLE_ARCHETYPE = {
    pistol = "pistol", smg = "smg", rifle = "rifle", shotgun = "shotgun",
    sniper = "sniper", launcher = "rocket", melee = "melee",
}

local MELEE_WORDS = {
    "melee", "knife", "stunstick", "crowbar", "machete", "hatchet", "fireaxe",
    "hammer", "sword", "fists", "hands", "katana", "shovel", "baton",
}

-- wep: a weapon entity or a class name
function WI.Classify(wep)
    local cls = isstring(wep) and wep or (IsValid(wep) and wep:GetClass())
    if not cls then return "rifle" end

    local cached = archetypeCache[cls]
    if cached then return cached end

    local lower = string.lower(cls)
    local arch

    local role = ZCNPC and isfunction(ZCNPC.WeaponRole) and ZCNPC.WeaponRole(lower)
    if role then arch = ROLE_ARCHETYPE[role] end

    if not arch then
        for _, word in ipairs(MELEE_WORDS) do
            if lower:find(word, 1, true) then arch = "melee" break end
        end
    end

    if not arch then
        for _, p in ipairs(CAI.Config.WeaponPatterns) do
            if lower:find(p.pattern, 1, true) then arch = p.archetype break end
        end
    end

    arch = arch or "rifle"
    archetypeCache[cls] = arch

    return arch
end

-- No weapon counts: an unarmed NPC or player fights with its hands.
function WI.IsMelee(wep)
    if not IsValid(wep) then return true end

    return WI.Classify(wep) == "melee"
end

-- Only a weapon that has a clip can be out of one. Melee reports 0 or -1 forever.
function WI.NeedsReload(wep)
    if not IsValid(wep) or WI.IsMelee(wep) then return false end
    if not (wep.Clip1 and wep.GetMaxClip1) then return false end

    return wep:GetMaxClip1() > 0 and wep:Clip1() == 0
end

function WI.Update(data, enemy)
    if not CAI.CVBool("cai_weaponintel") then
        data.enemyWeaponResponse = CAI.Config.WeaponResponses.rifle
        return
    end
    if not (IsValid(enemy) and enemy.GetActiveWeapon) then return end
    local archetype = WI.Classify(enemy:GetActiveWeapon())
    if not IsValid(enemy:GetActiveWeapon()) then archetype = "melee" end

    if data.enemyWeaponArchetype ~= archetype then
        data.enemyWeaponArchetype = archetype
        data.enemyWeaponResponse = CAI.Config.WeaponResponses[archetype] or CAI.Config.WeaponResponses.rifle

        if archetype == "rocket" and data.squad then
            for _, member in ipairs(data.squad.members) do
                local md = CAI.Manager.Get(member)
                if md then md.forceRecover = true end
            end
            CAI.Squad.Broadcast(data.squad, "rocket_spotted", data.ent)
        end
    end
end

function WI.EffectiveAggression(data)
    local agg = 0.5 + (data.personality.stats.aggression or 0) * 0.5
    agg = agg + (CAI.CVNum("cai_aggression") - 0.5) * 0.9
    if data.enemyWeaponResponse then
        agg = agg + (data.enemyWeaponResponse.aggression or 0)
    end
    if data.morale > 80 then agg = agg + 0.1 end
    if data.morale < CAI.Config.Morale.ShakenThreshold then agg = agg - 0.25 end
    return math.Clamp(agg, 0, 1)
end

local ownIdeal = {
    shotgun = 340, smg = 520, rifle = 650, lmg = 720,
    sniper = 1100, pistol = 500, explosive = 900, rocket = 900, melee = 60,
}
function WI.OwnIdeal(npc)
    local wep = npc.GetActiveWeapon and npc:GetActiveWeapon()
    if not IsValid(wep) then return ownIdeal.melee end
    return ownIdeal[WI.Classify(wep)] or 600
end
