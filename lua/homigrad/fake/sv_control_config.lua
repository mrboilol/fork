local K = {}

K.defaultBones = {
	[0] = "ValveBiped.Bip01_Pelvis",
	[1] = "ValveBiped.Bip01_Spine2",
	[2] = "ValveBiped.Bip01_R_UpperArm",
	[3] = "ValveBiped.Bip01_L_UpperArm",
	[4] = "ValveBiped.Bip01_L_Forearm",
	[5] = "ValveBiped.Bip01_L_Hand",
	[6] = "ValveBiped.Bip01_R_Forearm",
	[7] = "ValveBiped.Bip01_R_Hand",
	[8] = "ValveBiped.Bip01_R_Thigh",
	[9] = "ValveBiped.Bip01_R_Calf",
	[10] = "ValveBiped.Bip01_Head1",
	[11] = "ValveBiped.Bip01_L_Thigh",
	[12] = "ValveBiped.Bip01_L_Calf",
	[13] = "ValveBiped.Bip01_L_Foot",
	[14] = "ValveBiped.Bip01_R_Foot",
}
K.fakePhysLimb = {
	[2] = "rarm", [6] = "rarm", [7] = "rarm",
	[3] = "larm", [4] = "larm", [5] = "larm",
	[8] = "rleg", [9] = "rleg", [14] = "rleg",
	[11] = "lleg", [12] = "lleg", [13] = "lleg",
}
K.fakeLimbs = {"larm", "rarm", "lleg", "rleg"}
K.wound_hold_hand_offset = 4
K.wound_hold_forearm_offset = 8
K.wound_hold_upperarm_offset = 14
K.wound_hold_reach_speed = 55
K.wound_hold_reach_damp = 14
K.wound_hold_arm_speed = 18
K.wound_hold_arm_damp = 12
K.BURN_ROLL_SPEED = 180
K.BURN_ROLL_ACCELERATION = 360
K.BURN_ROLL_EXTINGUISH_ANGLE = 360
K.LEDGE_RANGE = 28
K.LEDGE_PROBE_FORWARD = 8
K.LEDGE_PROBE_HEIGHT = 40
K.LEDGE_ABOVE_TOLERANCE = 8
K.forceArm = 600
K.forceArm_dump = 450
K.fall_cover_mins = Vector(-6, -6, -6)
K.fall_cover_maxs = Vector(6, 6, 6)
K.fall_cover_offsets = {
	["male09"] = {
		[2] = {ang = Angle(-25.820, -105.490, -100.210)},
		[3] = {ang = Angle(-33.460, -72.240, -70.380)},
		[4] = {ang = Angle(-10.640, 145.920, -34.760)},
		[5] = {ang = Angle(12.380, 127.140, 75.320)},
		[6] = {ang = Angle(-19.720, -33.680, -171.940)},
		[7] = {ang = Angle(-1.960, 35.170, 116.580)}
	},
	["female06"] = {
		[2] = {ang = Angle(-22.610, -99.190, -98.620)},
		[3] = {ang = Angle(-29.870, -78.830, -71.760)},
		[4] = {ang = Angle(-11.430, 139.440, -35.610)},
		[5] = {ang = Angle(11.620, 117.010, 78.940)},
		[6] = {ang = Angle(-20.210, -25.920, -171.180)},
		[7] = {ang = Angle(-4.130, 45.020, 113.260)}
	}
}
K.slideFrictionBones = {13, 14, 12, 9}
K.ROLL_PHYS = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
K.SLIDE_PHYS = {0, 1}
K.FAKE_LEG_KICK = {
	DAMAGE_MUL = 0.65,
	RAG_FORCE_MUL = 220,
	PROP_FORCE_MUL = 150,
	PLAYER_PUSH = 300,
	FAKE_CHANCE = 0.65,
	TRACE_RANGE = 28,
	TRACE_SIZE = Vector(5, 5, 5),
	SEGMENT_SIZE = Vector(6, 6, 6),
	EXTEND_TIME = 0.35,
	VIEWPUNCH = Angle(3, 0, 0),
	CHARGE_FORWARD_OFFSET = -90,
	CHARGE_THIGH_RIGHT_OFFSET = -22,
	CHARGE_CALF_RIGHT_OFFSET = -10,
	CHARGE_CALF_UP_OFFSET = 220,
	EXTEND_THIGH_UP_OFFSET = 46,
	SHADOW_TIME = 0.001,
	SHADOW_ANG = 170,
	SHADOW_DAMP = 60,
}

return K
