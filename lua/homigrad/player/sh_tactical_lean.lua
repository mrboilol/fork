hg.TacticalLeanMax = 2.6

if SERVER then
	util.AddNetworkString("hg_tactical_lean")

	net.Receive("hg_tactical_lean", function(len, ply)
		if not IsValid(ply) then return end

		ply.hgTacLean = math.Clamp(net.ReadInt(8), -100, 100) / 100
	end)

	hook.Add("PlayerSpawn", "hg-tactical-lean", function(ply)
		ply.hgTacLean = 0
	end)

	hook.Add("PostPlayerDeath", "hg-tactical-lean", function(ply)
		ply.hgTacLean = 0
	end)

	function hg.GetTacticalLean(ply)
		return ply.hgTacLean or 0
	end

	return
end

local RAMP_UP = 1.8
local RAMP_DOWN = 4
local SEND_DELAY = 0.05
local moveButtons = bit.bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT, IN_JUMP)

local tacLean = 0
local lastSent = 0
local nextSend = 0

local function isTacticalHeld(ply)
	if not IsValid(ply) or not ply:Alive() or ply:InVehicle() or ply:IsTyping() or vgui.CursorVisible() then return false end
	if IsValid(ply.FakeRagdoll) then return false end

	return (input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL))
		and (input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT))
end

function hg.GetTacticalLean(ply)
	if ply ~= LocalPlayer() then return 0 end

	return tacLean
end

hook.Add("CreateMove", "hg-tactical-lean", function(cmd)
	local held = isTacticalHeld(LocalPlayer())
	local dir = 0

	if held then
		local forward, back = cmd:KeyDown(IN_FORWARD), cmd:KeyDown(IN_BACK)
		local left, right = cmd:KeyDown(IN_MOVELEFT), cmd:KeyDown(IN_MOVERIGHT)

		dir = (right and 1 or 0) - (left and 1 or 0)

		local buttons = bit.band(cmd:GetButtons(), bit.bnot(moveButtons))

		if forward and not back then
			buttons = bit.band(buttons, bit.bnot(IN_DUCK))
		elseif back and not forward then
			buttons = bit.bor(buttons, IN_DUCK)
		end

		if dir < 0 then
			buttons = bit.bor(buttons, IN_ALT1)
		elseif dir > 0 then
			buttons = bit.bor(buttons, IN_ALT2)
		end

		cmd:SetButtons(buttons)
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
	end

	tacLean = math.Approach(tacLean, dir, (dir == 0 and RAMP_DOWN or RAMP_UP) * FrameTime())

	local quantized = math.Round(tacLean * 100)
	if quantized ~= lastSent and CurTime() >= nextSend then
		lastSent = quantized
		nextSend = CurTime() + SEND_DELAY

		net.Start("hg_tactical_lean")
			net.WriteInt(quantized, 8)
		net.SendToServer()
	end
end)
