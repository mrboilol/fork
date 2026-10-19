local K = {}

K.CFG = {
	ARTERIAL_ACTIVE_RATE = 0.05,
	ARTERIAL_PULSE_DEPTH = 0.3,
	BLEED_RATE_CRITICAL = 8,
	CHEST_INSET = 0.45,
	CIRCLE_SEGMENTS = 24,
	DEPTH_SCALE = 0.012,
	DEPTH_SCALE_MAX = 1.3,
	DEPTH_SCALE_MIN = 0.75,
	FADE_IN_RATE = 1.5,
	FADE_OUT_RATE = 3,
	FIGURE_EXTENT = 3.8,
	FILL_ALPHA = 235,
	GRAY_RATE = 3,
	GRAY_SHOCK_RANGE = 60,
	GRAY_SHOCK_START = 10,
	JAW_DROP = 0.13,
	JAW_FORWARD = 0.1,
	MAX_SPINE_LENGTH = 80,
	MEDICAL_UPDATE_INTERVAL = 0.1,
	MIN_SPINE_LENGTH = 4,
	OTRUB_CONSCIOUSNESS = 0.3,
	PANEL_MARGIN_FRACTION = 0.02,
	PANEL_SIZE_FRACTION = 0.36,
	PELVIS_INSET = 0.35,
	POSE_SMOOTH_RATE = 20,
	SNAP_AFTER_HIDDEN = 0.5,
	SPINE_BACK_OFFSET = 0.12,
	TARGET_HEIGHT = 0.1,
	TAU = math.pi * 2,
	WOUND_CAMERA_BIAS = 2,
	WOUND_SIZE_TO_RATE = 0.24,
	YAW_SMOOTH_RATE = 8,
	GRAY_CONSCIOUSNESS_START = 0.85,
}
K.DISPLAY_SPINE = 20
K.OUTLINE_ALPHA = 220
K.MIN_AXIS_LENGTH = 0.05
K.SKULL_LIFT = 0.12
K.WEIGHT = {
	DISLOCATION = 0.7,
	ARTERIAL = 0.95,
	ARTERIAL_CONTROLLED = 0.6,
	HAND_BONE_SHARE = 0.5,
}
K.DEFAULT_PULSE = 72
K.SECONDS_PER_MINUTE = 60
K.WOUND_MARK = {
	sizeBase = 1.5, sizePerSize = 0.15, sizeMax = 4,
	venous = {110, 0, 0},
	arterial = {255, 30, 30},
}
K.REFERENCE_SCREEN_HEIGHT = 1080
K.HEALTH_STOPS = {
	{0, 245, 245, 240, 180},
	{0.5, 255, 225, 40, 255},
	{1, 215, 25, 25, 255},
}
K.COLOR = {
	ARMOR_GOOD = {40, 200, 70},
	ARMOR_DAMAGED = {235, 205, 50},
	ARMOR_RUINED = {215, 25, 25},
	ARMOR_FILL_ALPHA = 30,
	ARMOR_LINE_ALPHA = 220,
	RING_HEALTHY = {255, 255, 255},
	RING_BLEEDING = {215, 25, 25},
	DISLOCATION = {45, 130, 255},
	TOURNIQUET_RING = {70, 130, 235},
	TOURNIQUET_STRAP = {35, 60, 150},
	BANDAGE_CLEAN = {225, 215, 190},
	OUTLINE = {20, 20, 22},
	ORGAN_GRAY = {110, 110, 112},
	ORGAN_BRAIN = {235, 150, 175},
	ORGAN_BRAIN_DEAD = {215, 25, 25},
	ORGAN_HEART = {200, 0, 0},
	ORGAN_LUNG = {0, 255, 255},
	ORGAN_TRACHEA = {0, 125, 255},
	LOBE_FRONTAL = {255, 80, 120},
	LOBE_PARIETAL = {255, 180, 40},
	LOBE_TEMPORAL = {80, 160, 255},
	LOBE_OCCIPITAL = {170, 80, 255},
}
K.ORGAN = {
	SHOW_DAMAGE = 0.01,
	LUNG_SHOW_DAMAGE = 0.5,
	PUNCTURE_DAMAGE = 0.6,
	BRAIN_GRAY_AT = 0.3,
	BRAIN_RED_AT = 0.7,
	BRAIN_RADIUS = 0.8,
	LOBE_RADIUS = 0.2,
	LOBE_OFFSET_Y = 0.45,
	LOBE_OFFSET_X = 0.5,
	HEART_RADIUS = 0.28,
	HEART_DROP = 0.3,
	LUNG_RADIUS = 0.4,
	LUNG_SPREAD = 0.55,
	LUNG_RISE = 0.15,
	TRACHEA_RADIUS = 0.45,
	TRACHEA_DROP = 0.3,
}
K.SHAPE = {
	OUTLINE_WIDTH = 1.5,
	STRAP_THICKNESS = 0.8,
	STRAP_MAX_SEGMENT_SHARE = 0.35,
	TOURNIQUET_STRAP_T = 0.25,
}
K.STRESS = {
	PULL_SPEED = 520,
	START_SPEED = 250,
	SMOOTH_RATE = 12,
	VISIBLE = 0.25,
	SHAKE_PIXELS = 3,
}
K.RADIUS = {
	SKULL = 0.2,
	NECK = 0.1,
	CHEST = 0.2,
	PELVIS = 0.17,
	SPINE = 0.045,
	UPPER_ARM = 0.1,
	LOWER_ARM = 0.09,
	HAND = 0.085,
	THIGH = 0.13,
	CALF = 0.11,
	FOOT = 0.1,
	JOINT = 0.075,
}
K.BONE = {
	PELVIS = 1,
	SPINE1 = 2,
	SPINE2 = 3,
	SPINE4 = 4,
	NECK = 5,
	HEAD = 6,
	JAW = 7,
	L_UPPERARM = 8,
	L_FOREARM = 9,
	L_HAND = 10,
	R_UPPERARM = 11,
	R_FOREARM = 12,
	R_HAND = 13,
	L_THIGH = 14,
	L_CALF = 15,
	L_FOOT = 16,
	L_TOE = 17,
	R_THIGH = 18,
	R_CALF = 19,
	R_FOOT = 20,
	R_TOE = 21,
}
K.BONE_CANDIDATES = {
	[K.BONE.PELVIS] = {"ValveBiped.Bip01_Pelvis", "Bip01 Pelvis", "bip_pelvis", "mixamorig:Hips"},
	[K.BONE.SPINE1] = {"ValveBiped.Bip01_Spine1", "Bip01 Spine1", "bip_spine_1", "mixamorig:Spine"},
	[K.BONE.SPINE2] = {"ValveBiped.Bip01_Spine2", "Bip01 Spine2", "bip_spine_2", "mixamorig:Spine1"},
	[K.BONE.SPINE4] = {"ValveBiped.Bip01_Spine4", "Bip01 Spine4", "bip_spine_3", "mixamorig:Spine2"},
	[K.BONE.NECK] = {"ValveBiped.Bip01_Neck1", "Bip01 Neck", "Bip01 Neck1", "bip_neck", "mixamorig:Neck"},
	[K.BONE.HEAD] = {"ValveBiped.Bip01_Head1", "Bip01 Head", "Bip01 Head1", "bip_head", "mixamorig:Head"},
	[K.BONE.JAW] = {"ValveBiped.Bip01_Jaw", "ValveBiped.jaw", "Bip01 Jaw", "jaw", "Jaw"},
	[K.BONE.L_UPPERARM] = {"ValveBiped.Bip01_L_UpperArm", "Bip01 L UpperArm", "bip_upperArm_L", "mixamorig:LeftArm"},
	[K.BONE.L_FOREARM] = {"ValveBiped.Bip01_L_Forearm", "Bip01 L Forearm", "bip_lowerArm_L", "mixamorig:LeftForeArm"},
	[K.BONE.L_HAND] = {"ValveBiped.Bip01_L_Hand", "Bip01 L Hand", "bip_hand_L", "mixamorig:LeftHand"},
	[K.BONE.R_UPPERARM] = {"ValveBiped.Bip01_R_UpperArm", "Bip01 R UpperArm", "bip_upperArm_R", "mixamorig:RightArm"},
	[K.BONE.R_FOREARM] = {"ValveBiped.Bip01_R_Forearm", "Bip01 R Forearm", "bip_lowerArm_R", "mixamorig:RightForeArm"},
	[K.BONE.R_HAND] = {"ValveBiped.Bip01_R_Hand", "Bip01 R Hand", "bip_hand_R", "mixamorig:RightHand"},
	[K.BONE.L_THIGH] = {"ValveBiped.Bip01_L_Thigh", "Bip01 L Thigh", "bip_hip_L", "mixamorig:LeftUpLeg"},
	[K.BONE.L_CALF] = {"ValveBiped.Bip01_L_Calf", "Bip01 L Calf", "bip_knee_L", "mixamorig:LeftLeg"},
	[K.BONE.L_FOOT] = {"ValveBiped.Bip01_L_Foot", "Bip01 L Foot", "bip_foot_L", "mixamorig:LeftFoot"},
	[K.BONE.L_TOE] = {"ValveBiped.Bip01_L_Toe0", "Bip01 L Toe0", "bip_toe_L", "mixamorig:LeftToeBase"},
	[K.BONE.R_THIGH] = {"ValveBiped.Bip01_R_Thigh", "Bip01 R Thigh", "bip_hip_R", "mixamorig:RightUpLeg"},
	[K.BONE.R_CALF] = {"ValveBiped.Bip01_R_Calf", "Bip01 R Calf", "bip_knee_R", "mixamorig:RightLeg"},
	[K.BONE.R_FOOT] = {"ValveBiped.Bip01_R_Foot", "Bip01 R Foot", "bip_foot_R", "mixamorig:RightFoot"},
	[K.BONE.R_TOE] = {"ValveBiped.Bip01_R_Toe0", "Bip01 R Toe0", "bip_toe_R", "mixamorig:RightToeBase"},
}
K.BONE_COUNT = #K.BONE_CANDIDATES
K.POINT = {
	PELVIS = 1,
	CHEST = 2,
	NECK = 3,
	SKULL = 4,
	JAW = 5,
	SPINE_TOP = 6,
	SPINE_MID = 7,
	SPINE_LOW = 8,
	L_SHOULDER = 9,
	L_ELBOW = 10,
	L_WRIST = 11,
	R_SHOULDER = 12,
	R_ELBOW = 13,
	R_WRIST = 14,
	L_HIP = 15,
	L_KNEE = 16,
	L_ANKLE = 17,
	L_FOOT = 18,
	R_HIP = 19,
	R_KNEE = 20,
	R_ANKLE = 21,
	R_FOOT = 22,
	CHEST_L = 23,
	CHEST_R = 24,
	PELVIS_L = 25,
	PELVIS_R = 26,
}
K.POINT_COUNT = 26
K.LIMB_POINT_BONES = {
	[K.POINT.L_SHOULDER] = K.BONE.L_UPPERARM,
	[K.POINT.L_ELBOW] = K.BONE.L_FOREARM,
	[K.POINT.L_WRIST] = K.BONE.L_HAND,
	[K.POINT.R_SHOULDER] = K.BONE.R_UPPERARM,
	[K.POINT.R_ELBOW] = K.BONE.R_FOREARM,
	[K.POINT.R_WRIST] = K.BONE.R_HAND,
	[K.POINT.L_HIP] = K.BONE.L_THIGH,
	[K.POINT.L_KNEE] = K.BONE.L_CALF,
	[K.POINT.L_ANKLE] = K.BONE.L_FOOT,
	[K.POINT.R_HIP] = K.BONE.R_THIGH,
	[K.POINT.R_KNEE] = K.BONE.R_CALF,
	[K.POINT.R_ANKLE] = K.BONE.R_FOOT,
}
K.LIMBS = {
	{
		base = "lleg", upper = "llegup", lower = "lleg",
		joints = {up = K.POINT.L_HIP, down = K.POINT.L_KNEE},
		points = {K.POINT.L_HIP, K.POINT.L_KNEE, K.POINT.L_ANKLE, K.POINT.L_FOOT},
		radii = {K.RADIUS.THIGH, K.RADIUS.CALF, K.RADIUS.FOOT},
		bones = {K.BONE.L_THIGH, K.BONE.L_CALF, K.BONE.L_FOOT},
	},
	{
		base = "rleg", upper = "rlegup", lower = "rleg",
		joints = {up = K.POINT.R_HIP, down = K.POINT.R_KNEE},
		points = {K.POINT.R_HIP, K.POINT.R_KNEE, K.POINT.R_ANKLE, K.POINT.R_FOOT},
		radii = {K.RADIUS.THIGH, K.RADIUS.CALF, K.RADIUS.FOOT},
		bones = {K.BONE.R_THIGH, K.BONE.R_CALF, K.BONE.R_FOOT},
	},
	{
		base = "larm", upper = "larmup", lower = "larm", hand = "lhand",
		joints = {up = K.POINT.L_SHOULDER, down = K.POINT.L_ELBOW},
		points = {K.POINT.L_SHOULDER, K.POINT.L_ELBOW, K.POINT.L_WRIST},
		radii = {K.RADIUS.UPPER_ARM, K.RADIUS.LOWER_ARM, K.RADIUS.HAND},
		bones = {K.BONE.L_UPPERARM, K.BONE.L_FOREARM, K.BONE.L_HAND},
	},
	{
		base = "rarm", upper = "rarmup", lower = "rarm", hand = "rhand",
		joints = {up = K.POINT.R_SHOULDER, down = K.POINT.R_ELBOW},
		points = {K.POINT.R_SHOULDER, K.POINT.R_ELBOW, K.POINT.R_WRIST},
		radii = {K.RADIUS.UPPER_ARM, K.RADIUS.LOWER_ARM, K.RADIUS.HAND},
		bones = {K.BONE.R_UPPERARM, K.BONE.R_FOREARM, K.BONE.R_HAND},
	},
}
for _, limb in ipairs(K.LIMBS) do
	limb.dislocKeys = {up = limb.base .. "_up", down = limb.base .. "_down"}
end
K.CHEST_BOX_BONES = {K.BONE.SPINE2, K.BONE.SPINE4, K.BONE.SPINE1}
K.REGIONS = {
	"skull", "jaw", "neck", "chest", "spine2", "spine1", "pelvis",
	"larmup", "larm", "lhand", "rarmup", "rarm", "rhand",
	"llegup", "lleg", "rlegup", "rleg",
}
K.TORSO_BONE_REGIONS = {
	["ValveBiped.Bip01_Head1"] = "skull",
	["ValveBiped.Bip01_Neck1"] = "neck",
	["ValveBiped.Bip01_Spine4"] = "chest",
	["ValveBiped.Bip01_Spine2"] = "chest",
	["ValveBiped.Bip01_L_Clavicle"] = "chest",
	["ValveBiped.Bip01_R_Clavicle"] = "chest",
	["ValveBiped.Bip01_Spine1"] = "pelvis",
	["ValveBiped.Bip01_Spine"] = "pelvis",
	["ValveBiped.Bip01_Pelvis"] = "pelvis",
	["ValveBiped.Bip01_L_Toe0"] = "lleg",
	["ValveBiped.Bip01_R_Toe0"] = "rleg",
}
K.REGION_SEGMENTS = {
	skull = {K.POINT.SKULL, K.POINT.SKULL, K.RADIUS.SKULL},
	jaw = {K.POINT.SKULL, K.POINT.SKULL, K.RADIUS.SKULL},
	neck = {K.POINT.NECK, K.POINT.NECK, K.RADIUS.NECK},
	chest = {K.POINT.CHEST_L, K.POINT.CHEST_R, K.RADIUS.CHEST},
	pelvis = {K.POINT.PELVIS_L, K.POINT.PELVIS_R, K.RADIUS.PELVIS},
	larmup = {K.POINT.L_SHOULDER, K.POINT.L_ELBOW, K.RADIUS.UPPER_ARM},
	larm = {K.POINT.L_ELBOW, K.POINT.L_WRIST, K.RADIUS.LOWER_ARM},
	lhand = {K.POINT.L_WRIST, K.POINT.L_WRIST, K.RADIUS.HAND},
	rarmup = {K.POINT.R_SHOULDER, K.POINT.R_ELBOW, K.RADIUS.UPPER_ARM},
	rarm = {K.POINT.R_ELBOW, K.POINT.R_WRIST, K.RADIUS.LOWER_ARM},
	rhand = {K.POINT.R_WRIST, K.POINT.R_WRIST, K.RADIUS.HAND},
	llegup = {K.POINT.L_HIP, K.POINT.L_KNEE, K.RADIUS.THIGH},
	lleg = {K.POINT.L_KNEE, K.POINT.L_ANKLE, K.RADIUS.CALF},
	rlegup = {K.POINT.R_HIP, K.POINT.R_KNEE, K.RADIUS.THIGH},
	rleg = {K.POINT.R_KNEE, K.POINT.R_ANKLE, K.RADIUS.CALF},
}
K.ARTERY_REGIONS = {
	arteria = "neck",
	aorta = "chest",
	larmartery = "larm",
	rarmartery = "rarm",
	llegartery = "lleg",
	rlegartery = "rleg",
}
K.STRESS_SEGMENTS = {
	{child = K.BONE.L_UPPERARM, parent = K.BONE.SPINE4, base = "larm", segment = "up", regions = {"larmup"}},
	{child = K.BONE.L_FOREARM, parent = K.BONE.L_UPPERARM, base = "larm", segment = "down", regions = {"larm", "lhand"}},
	{child = K.BONE.R_UPPERARM, parent = K.BONE.SPINE4, base = "rarm", segment = "up", regions = {"rarmup"}},
	{child = K.BONE.R_FOREARM, parent = K.BONE.R_UPPERARM, base = "rarm", segment = "down", regions = {"rarm", "rhand"}},
	{child = K.BONE.L_THIGH, parent = K.BONE.PELVIS, base = "lleg", segment = "up", regions = {"llegup"}},
	{child = K.BONE.L_CALF, parent = K.BONE.L_THIGH, base = "lleg", segment = "down", regions = {"lleg"}},
	{child = K.BONE.R_THIGH, parent = K.BONE.PELVIS, base = "rleg", segment = "up", regions = {"rlegup"}},
	{child = K.BONE.R_CALF, parent = K.BONE.R_THIGH, base = "rleg", segment = "down", regions = {"rleg"}},
}
K.HALF_SEGMENTS = K.CFG.CIRCLE_SEGMENTS / 2
K.ARMOR_SIGNS = {
	{-1, -1, -1}, {1, -1, -1}, {1, 1, -1}, {-1, 1, -1},
	{-1, -1, 1}, {1, -1, 1}, {1, 1, 1}, {-1, 1, 1},
}

return K
