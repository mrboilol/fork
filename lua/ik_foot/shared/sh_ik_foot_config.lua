IKFoot = IKFoot or {}

IKFoot.Config = {
	entries = {
		{ key = "enabled",         cvar = "ik_foot",                 type = "bool",  default = true, min = 0,    max = 1,    decimals = 0, desc = "Enable/Disable IK Foot" },
		{ key = "debug",           cvar = "ik_foot_debug",           type = "float", default = 0,    min = 0,    max = 1,    decimals = 0, desc = "Debug Visualization" },
		{ key = "draw_distance",   cvar = "ik_foot_draw_distance",   type = "float", default = 2048, min = 256,  max = 8192, decimals = 0, desc = "Max Distance For Foot IK" },
		{ key = "blend_speed",     cvar = "ik_foot_blend_speed",     type = "float", default = 5,    min = 1,    max = 20,   decimals = 1, desc = "IK Blend In/Out Speed" },
		{ key = "step_height",     cvar = "ik_foot_step_height",     type = "float", default = 5,    min = 1,    max = 15,   decimals = 1, desc = "Swing Foot Lift Height" },
		{ key = "stride_scale",    cvar = "ik_foot_stride_scale",    type = "float", default = 1,    min = 0.5,  max = 1.5,  decimals = 2, desc = "Foot Landing Lead Scale" },
		{ key = "stance_width",    cvar = "ik_foot_stance_width",    type = "float", default = 1,    min = 0.5,  max = 2,    decimals = 2, desc = "Stance Width Scale" },
		{ key = "settle_distance", cvar = "ik_foot_settle_distance", type = "float", default = 7,    min = 2,    max = 20,   decimals = 1, desc = "Idle Re-step Distance" },
		{ key = "settle_angle",    cvar = "ik_foot_settle_angle",    type = "float", default = 40,   min = 10,   max = 90,   decimals = 0, desc = "Idle Re-step Turn Angle" },
		{ key = "flight_hop",      cvar = "ik_foot_flight_hop",      type = "float", default = 2.5,  min = 0,    max = 8,    decimals = 1, desc = "Running Flight Hop Height" },
		{ key = "max_body_drop",   cvar = "ik_foot_max_body_drop",   type = "float", default = 42,   min = 0,    max = 80,   decimals = 1, desc = "Maximum Pelvis Drop" },
		{ key = "align_feet",      cvar = "ik_foot_align",           type = "bool",  default = true, min = 0,    max = 1,    decimals = 0, desc = "Align Planted Feet To Ground" },
	},
}

IKFoot.Config.byKey = {}
for _, entry in ipairs(IKFoot.Config.entries) do
	IKFoot.Config.byKey[entry.key] = entry
end

function IKFoot.Config.ClampNumber(entry, value)
	return math.Clamp(tonumber(value) or 0, entry.min, entry.max)
end



IKFoot.CVars = IKFoot.CVars or {}

for _, entry in ipairs(CLIENT and IKFoot.Config.entries or {}) do
	local default = entry.default
	if entry.type == "bool" then default = default and 1 or 0 end
	IKFoot.CVars[entry.key] = CreateClientConVar(entry.cvar, tostring(default), true, false, entry.desc, entry.min, entry.max)
end

function IKFoot.GetFloat(key)
	local cvar = IKFoot.CVars[key]
	if cvar then return cvar:GetFloat() end

	local entry = IKFoot.Config.byKey[key]
	if not entry then return 0 end

	return entry.type == "bool" and (entry.default and 1 or 0) or entry.default
end
