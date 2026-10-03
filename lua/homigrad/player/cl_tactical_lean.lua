local TAC_UP = 5
local TAC_DOWN = 14
local TAC_SPEED = 8
local vecHullMin, vecHullMax = Vector(-4, -4, -4), Vector(4, 4, 4)
local moveButtons = bit.bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT, IN_DUCK, IN_JUMP)

local targetZ = 0
local tacZ = 0

local function isTacticalHeld(ply)
	if not IsValid(ply) or not ply:Alive() or ply:InVehicle() or ply:IsTyping() or vgui.CursorVisible() then return false end
	if IsValid(ply.FakeRagdoll) then return false end

	return (input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL))
		and (input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT))
end

hook.Add("CreateMove", "hg-tactical-lean", function(cmd)
	if not isTacticalHeld(LocalPlayer()) then
		targetZ = 0
		return
	end

	local forward, back = cmd:KeyDown(IN_FORWARD), cmd:KeyDown(IN_BACK)
	local left, right = cmd:KeyDown(IN_MOVELEFT), cmd:KeyDown(IN_MOVERIGHT)

	targetZ = (forward and 1 or 0) - (back and 1 or 0)

	local buttons = bit.band(cmd:GetButtons(), bit.bnot(moveButtons))

	if left and not right then
		buttons = bit.bor(buttons, IN_ALT1)
	elseif right and not left then
		buttons = bit.bor(buttons, IN_ALT2)
	end

	cmd:SetButtons(buttons)
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
end)

hook.Add("Think", "hg-tactical-lean", function()
	tacZ = Lerp(math.min(FrameTime() * TAC_SPEED, 1), tacZ, targetZ)
	if math.abs(tacZ) < 0.001 then tacZ = 0 end
end)

function hg.TacticalLeanView(ply, origin)
	if tacZ == 0 or ply ~= LocalPlayer() then return origin end

	local tr = util.TraceHull({
		start = origin,
		endpos = origin + vector_up * tacZ * (tacZ > 0 and TAC_UP or TAC_DOWN),
		mins = vecHullMin,
		maxs = vecHullMax,
		filter = ply,
		mask = MASK_SOLID
	})

	return tr.HitPos
end
