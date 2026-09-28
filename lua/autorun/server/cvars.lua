if SERVER then
    util.AddNetworkString("change_setting")
    util.AddNetworkString("ar_reset_defaults")
    util.AddNetworkString("ar_reset_cvars")
end

local managedCVars = {
    -- CORE
    ["ar_enabled"] = "1",
    ["ar_enabled_players"] = "1",
    ["ar_enabled_npcs"] = "1",

    -- STUMBLE / BALANCE
    ["ar_PushDuration"] = "2",
    ["ar_PushPeakForce"] = "100",
    ["ar_MaxVelocityClamp"] = "350",
    ["ar_VelocitySmoothing"] = "10",
    ["ar_RaycastDistance"] = "200",
    ["ar_MaxStepUpHeight"] = "18",
    ["ar_MaxStepDownHeight"] = "80",
    ["ar_SearchHeightBuffer"] = "25",
    ["ar_MinFootSeparation"] = "10",
    ["ar_uprightForce"] = "425",
    ["ar_StepHeight"] = "20",
    ["ar_HipTargetHeight"] = "50",
    ["ar_TimeBeforeDecay"] = "4.0",
    ["ar_DecayDuration"] = "3.0",
    ["ar_MaxSlopeAngle"] = "45",
    ["ar_GroundStickDistance"] = "5",
    ["ar_StepTriggerForward"] = "15",
    ["ar_StepTriggerBackward"] = "15",
    ["ar_StepTriggerSide"] = "15",
    ["ar_MinMovementSpeed"] = "15",
    ["ar_StationaryThreshold"] = "15",
    ["ar_FootLockStrength"] = "0.95",
    ["ar_AbsoluteTraceDepth"] = "8192",
    ["ar_PredictionTime"] = "0.35",
    ["ar_MinStepInterval"] = "0.25",
    ["hg_euphoria_getup_stumble"] = "1",
    ["hg_stumble_PushDuration"] = "2",
    ["hg_stumble_PushPeakForce"] = "100",
    ["hg_stumble_MaxVelocityClamp"] = "350",
    ["hg_stumble_VelocitySmoothing"] = "10",
    ["hg_stumble_MaxStepUpHeight"] = "18",
    ["hg_stumble_MaxStepDownHeight"] = "80",
    ["hg_stumble_SearchHeightBuffer"] = "25",
    ["hg_stumble_StepHeight"] = "20",
    ["hg_stumble_HipTargetHeight"] = "50",
    ["hg_stumble_Duration"] = "3.5",
    ["hg_stumble_MinDriveSpeed"] = "130",
    ["hg_stumble_MaxDriveSpeed"] = "450",
    ["hg_stumble_MomentumGain"] = "140",
    ["hg_stumble_DriveAccel"] = "700",
    ["hg_stumble_Carry"] = "0.55",
    ["hg_stumble_Pitch"] = "240",
    ["hg_stumble_MaxSlopeAngle"] = "45",
    ["hg_stumble_StepTriggerForward"] = "15",
    ["hg_stumble_MinMovementSpeed"] = "15",
    ["hg_stumble_StationaryThreshold"] = "15",
    ["hg_stumble_AbsoluteTraceDepth"] = "8192",
    ["hg_stumble_PredictionTime"] = "0.35",
    ["hg_stumble_MinStepInterval"] = "0.25",

    -- WOUND GRAB
    ["ar_EnableWoundGrab"] = "1", 
    ["ar_GrabTime"] = "5",

    -- HEADSHOT
    ["ar_FatalHeadshot"] = "1",
    ["ar_hs_death_delay"] = "4.0",
    ["ar_headshot_force"] = "3000",
    ["ar_headshot_torque"] = "1500",
    ["ar_hs_limp_time"] = "1.8",
    ["ar_hs_limp_str"] = "1.5",
    ["ar_hs_stiff_time"] = "0.65",
    ["ar_hs_stiff_str"] = "4.0",
    ["ar_hs_twitch_time"] = "5.0",
    ["ar_hs_twitch_str"] = "3.0",
    ["ar_hs_twitch_speed"] = "150",
    ["ar_hs_twitch_amp"] = "80",

    -- TUMBLE
    ["ar_EnableTumble"] = "1",
    ["ar_TumbleSpeed"] = "45",
    ["ar_tumble_minspeed"] = "35",
    ["ar_tumble_torque"] = "5000",
    ["ar_tumble_lift"] = "0.5",
    ["ar_tumble_chaos"] = "1.0",

    -- HOLDENV
    ["ar_enableHoldEnv"] = "1",
    ["ar_holdenv_search_radius"] = "15",
    ["ar_holdenv_min_dist"] = "5",
    ["ar_holdenv_max_dist"] = "15",
    ["ar_holdenv_release_vel"] = "200",
    ["ar_holdenv_min_hold"] = "1",
    ["ar_holdenv_max_hold"] = "2",
    ["ar_holdenv_cooldown"] = "3",
    ["ar_holdenv_max_grabs"] = "2",

    -- CRAWLING
    ["ar_enableCrawling"] = "1",

    -- FORCES
    ["ar_max_physics_force"] = "3500",
    ["burn_calf_force"] = "100",
    ["burn_arm_force"] = "57",
    ["burn_strength"] = "4.5",

    -- HEALTH
    ["sv_health_metab_min"] = "2.0",
    ["sv_health_metab_max"] = "5.0",
    ["sv_health_bleed_sensitivity"] = "0.15",
    ["sv_health_bleed_damage_mult"] = "1.0",
    ["sv_health_clotting_mult"] = "1.0",
    ["sv_health_max_bleed_tick"] = "50",

    -- PERFORMANCE TAB
    ["ar_HandsAnimation"] = "1",
    ["ar_Expressions"] = "1", 
}

for name, default in pairs(managedCVars) do
    CreateConVar(name, default, {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY})
end

if SERVER then
    net.Receive("change_setting", function(len, ply)
        if not (IsValid(ply) and ply:IsAdmin()) then return end
        
        local cvarName = net.ReadString()
        local value = net.ReadFloat()

        if managedCVars[cvarName] then
            local cvar = GetConVar(cvarName)
            if cvar then 
                if math.abs(cvar:GetFloat() - value) > 0.0001 then
                    cvar:SetFloat(value) 
                end
            end
        end
    end)

    net.Receive("ar_reset_defaults", function(len, ply)
        if not (IsValid(ply) and ply:IsAdmin()) then return end
        
        for name, default in pairs(managedCVars) do
            local cvar = GetConVar(name)
            if cvar then 
                cvar:SetString(default) 
            end
        end
        
        PrintMessage(HUD_PRINTTALK, "Admin " .. ply:Nick() .. " reset all ragdoll settings.")
    end)

    net.Receive("ar_reset_cvars", function(len, ply)
        if not (IsValid(ply) and ply:IsAdmin()) then return end

        for i = 1, net.ReadUInt(8) do
            local name = net.ReadString()
            local cvar = managedCVars[name] and GetConVar(name)
            if cvar then cvar:SetString(managedCVars[name]) end
        end
    end)
end
