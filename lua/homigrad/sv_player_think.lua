local hook_Run = hook.Run
local SysTime, CurTime = SysTime, CurTime
local IsValid = IsValid

local function dispatchPlayerThink(ply)
	if not IsValid(ply) then return end

	local sysTime = SysTime()
	ply.lastcall_tick = ply.lastcall_tick or sysTime - 0.01
	local dtime = sysTime - ply.lastcall_tick

	hook_Run("Player Think", ply, CurTime(), dtime)

	ply.lastcall_tick = sysTime
end

hook.Add("PlayerTick", "ilovefurries", dispatchPlayerThink)

hook.Add("VehicleMove", "ilovefurries", function(ply)
	dispatchPlayerThink(ply)
end)

hook.Add("KeyRelease", "huy-hg2", function(ply, key)
	if not IsValid(ply) then return end

	net.Start("ZB_KeyDown2")
		net.WriteInt(key, 26)
		net.WriteBool(false)
		net.WriteEntity(ply)
	net.SendPVS(ply:GetPos())
end)
