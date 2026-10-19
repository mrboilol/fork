local K = {}
K.head_otrub_consciousness_cap = 0.04
K.instant_pain_shock_scale = 0.75
K.traumatic_shock_threshold = 24
K.player_limb_gib_threshold = 220
K.player_head_gib_threshold = 120
K.player_buckshot_head_gib_threshold = 100
K.player_stomach_gib_threshold = 260
K.player_blast_limb_gib_threshold = 220
K.player_fall_head_gib_threshold = 1.2
K.full_body_blast_gib_threshold = 5000
K.full_body_blast_damage_threshold = 1400
K.full_body_physics_speed_threshold = 3400
K.full_body_physics_damage_threshold = 4200
K.blast_gib_damage_mul = 700
K.melee_gib_damage_mul = 0.35
K.slash_limb_gib_damage_mul = 4.5
K.ballistic_head_gib_damage_mul = 2
K.ballistic_limb_gib_damage_mul = 1.25
K.ragdoll_fall_skull_damage_mul = 1.65
K.ragdoll_fall_jaw_damage_mul = 0.45
K.ragdoll_fall_skull_break_blood_mul = 1.15
K.rifle_penetration_threshold = 11
K.rifle_low_penetration_threshold = 9.5
K.rifle_low_penetration_damage_threshold = 55
K.gib_damage_decay = {
	[HITGROUP_HEAD] = 3,
}
K.body_part_health = {
	[HITGROUP_HEAD] = K.player_head_gib_threshold,
	[HITGROUP_LEFTLEG] = K.player_limb_gib_threshold,
	[HITGROUP_RIGHTLEG] = K.player_limb_gib_threshold,
	[HITGROUP_LEFTARM] = K.player_limb_gib_threshold,
	[HITGROUP_RIGHTARM] = K.player_limb_gib_threshold,
	[HITGROUP_STOMACH] = K.player_stomach_gib_threshold,
}
K.body_part_heal = {
	[HITGROUP_HEAD] = 1,
	[HITGROUP_LEFTLEG] = 1,
	[HITGROUP_RIGHTLEG] = 1,
	[HITGROUP_LEFTARM] = 1,
	[HITGROUP_RIGHTARM] = 1,
	[HITGROUP_STOMACH] = 1,
}

return K
