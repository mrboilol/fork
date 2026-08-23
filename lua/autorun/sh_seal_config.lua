if SERVER then AddCSLuaFile() end

HG_SEAL_CONFIG = HG_SEAL_CONFIG or {
    MAX_HEALTH = 100,
    MAX_BLOOD_ML = 1200,
    FATAL_BLOOD_LOSS_ML = 500,
    BLEED_CLOT_RATE = 0.02,
    BANDAGE_TREATMENT_COST = 12,
    BANDAGE_BLEED_REDUCTION = 0.65,
    BANDAGE_BLEED_FLAT = 2,
    DUCT_TAPE_TREATMENT_COST = 15,
    DUCT_TAPE_BLEED_REDUCTION = 0.80,
    DUCT_TAPE_BLEED_FLAT = 3,
    HELD_BLEED_FX_MIN_RATE = 0.5,
    HURT_SOUND_LEVEL = 82,
    DEATH_SOUND_LEVEL = 140,
    CORPSE_LIFETIME = 15,
    CORPSE_FADE_TIME = 3,
    THROW_SPEED = 760,
    THROW_DAMAGE = 19,
    THROW_MIN_DAMAGE_SPEED = 300,
    THROW_DAMAGE_WINDOW = 2,
    THROW_REFERENCE_MASS = 8,
    ANGER_HUNGER_START = 65,
    ANGER_HUNGER_RATE = 1.2,
    ANGER_DAMAGE_MULTIPLIER = 1.6,
    ANGER_DECAY_RATE = 1.8,
    ANGER_BITE_THRESHOLD = 30,
    ANGER_TARGET_RANGE = 500,
    BITE_RANGE = 82,
    BITE_DAMAGE = 14,
    BITE_COOLDOWN_MIN = 1.2,
    BITE_COOLDOWN_MAX = 2.4,
    BITE_ARTERY_CHANCE = 2,
    HAPPY_SOUND_CHANCE = 0.35,
    RECENT_FED_DURATION = 45
}


if SERVER then
    util.AddNetworkString("hg_seal_blood_drop")

    function HG_EmitSealBlood(source, pos, velocity, intensity)
        if not isvector(pos) or not isvector(velocity) then return end
        intensity = math.Clamp(tonumber(intensity) or 0, 0, 1)
        net.Start("hg_seal_blood_drop")
            net.WriteEntity(IsValid(source) and source or game.GetWorld())
            net.WriteVector(pos)
            net.WriteVector(velocity)
            net.WriteFloat(intensity)
        net.SendPVS(pos)
    end
end
