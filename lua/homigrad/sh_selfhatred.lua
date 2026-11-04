local holdTime = 0.35

if SERVER then
	util.AddNetworkString("hg_wristcut_hold")

	local function canWristPose(ply)
		if not ply:Alive() or not ply.suiciding then return false end
		if ply:GetNWFloat("rem_suicide_aim", 0) > 0 or ply:GetNWFloat("rem_urges_end", 0) >= CurTime() then return false end
		if ply.organism and ply.organism.larmamputated then return false end

		local wep = ply:GetActiveWeapon()
		return IsValid(wep) and wep.CanSuicide and wep.IsSharpBlade and wep:IsSharpBlade()
	end

	net.Receive("hg_wristcut_hold", function(_, ply)
		if not IsValid(ply) or not canWristPose(ply) or ply:GetActiveWeapon().SuicideStart then return end

		ply:SetNWBool("hg_wrist_suicide", true)
	end)

	hook.Add("Player Think", "hg_wristcut_mode", function(ply)
		if ply:GetNWBool("hg_wrist_suicide", false) and not canWristPose(ply) then
			ply:SetNWBool("hg_wrist_suicide", false)
		end
	end)

	return
end

local wasDown
local armed
local heldSince

local function suicideKey()
	local bind = input.LookupBinding("suicide")
	local code = bind and input.GetKeyCode(bind)
	if code and code > 0 then return code, true end
	return KEY_B, false
end

hook.Add("Think", "hg_wristcut_hold", function()
	local ply = LocalPlayer()
	local wep = IsValid(ply) and ply:Alive() and ply:GetActiveWeapon()
	local key, bound = suicideKey()
	local down = IsValid(ply) and input.IsButtonDown(key) and not ply:IsTyping() and not gui.IsGameUIVisible() and not IsValid(vgui.GetKeyboardFocus())

	if not down then
		wasDown, armed = nil, nil
		return
	end

	local sharp = IsValid(wep) and wep.CanSuicide and wep.IsSharpBlade and wep:IsSharpBlade()

	if not wasDown then
		wasDown = true
		heldSince = CurTime()
		armed = sharp and not ply:GetNWBool("suiciding", false)

		if sharp and not bound then
			RunConsoleCommand("suicide")
		end
	end

	if not armed or not sharp or wep.SuicideStart or CurTime() - heldSince < holdTime then return end
	if not ply:GetNWBool("suiciding", false) then return end

	armed = false
	net.Start("hg_wristcut_hold")
	net.SendToServer()
end)
