IKFoot = IKFoot or {}
IKFoot._runtimeLoaded = true

if SERVER then
	AddCSLuaFile("ik_foot/shared/sh_ik_foot_config.lua")
	include("ik_foot/server/sv_ik_foot_sync.lua")
	return
end

include("ik_foot/shared/sh_ik_foot_config.lua")
