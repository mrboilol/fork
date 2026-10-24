hg = hg or {}

local HOLSTER_END = "hgHolsterEnd"
local HOLSTER_TOTAL = "hgHolsterTotal"
local HOLSTER_TARGET = "hgHolsterTarget"
local MIN_FRACTION = 0.05

local pending = {}

function hg.GetHolsterEnd(wep)
	local finish = wep:GetNWFloat(HOLSTER_END, 0)
	return finish ~= 0 and finish or nil
end

function hg.GetHolsterTotal(wep)
	return wep:GetNWFloat(HOLSTER_TOTAL, 0)
end

function hg.ClearHolster(wep)
	if CLIENT then return end
	pending[wep] = nil
	if wep:GetNWFloat(HOLSTER_END, 0) == 0 then return end
	wep:SetNWFloat(HOLSTER_END, 0)
	wep:SetNWFloat(HOLSTER_TOTAL, 0)
	wep:SetNWEntity(HOLSTER_TARGET, NULL)
end

function hg.ShouldDelayHolster(wep, newWep)
	local owner = wep:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return false end
	if owner.hgInstantSwitch or wep.NoHolsterDelay or not wep.GetHolsterDuration then return false end
	if not IsValid(newWep) or newWep == wep then return false end
	if IsValid(owner.FakeRagdoll) or owner:GetActiveWeapon() ~= wep then return false end
	local fraction = wep.GetDrawFraction and wep:GetDrawFraction()
	return not fraction or fraction > MIN_FRACTION
end

function hg.BeginHolster(wep, newWep)
	if not hg.GetHolsterEnd(wep) then
		local total = wep:GetHolsterDuration()
		local fraction = wep.GetDrawFraction and wep:GetDrawFraction() or 1
		wep:SetNWFloat(HOLSTER_TOTAL, total)
		wep:SetNWFloat(HOLSTER_END, CurTime() + total * fraction)
		if wep.OnHolsterBegin then wep:OnHolsterBegin(total, fraction) end
	end

	wep:SetNWEntity(HOLSTER_TARGET, newWep)
	pending[wep] = {owner = wep:GetOwner(), target = newWep, finish = hg.GetHolsterEnd(wep)}
end

function hg.HolsterGate(wep, newWep)
	if not hg.ShouldDelayHolster(wep, newWep) then
		hg.ClearHolster(wep)
		return false
	end

	if SERVER then hg.BeginHolster(wep, newWep) end
	return true
end

local function switchTo(owner, target)
	if not IsValid(target) or target:GetOwner() ~= owner then
		target = hg.GetHandsWeapon and hg.GetHandsWeapon(owner) or owner:GetWeapon("weapon_hands_sh")
	end
	if not IsValid(target) then return end

	owner.hgInstantSwitch = true
	owner:SelectWeapon(target:GetClass())
	owner.hgInstantSwitch = nil
end

hook.Add("StartCommand", "hg_weapon_holster_gate", function(ply, cmd)
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and hg.GetHolsterEnd(wep) then
		cmd:RemoveKey(IN_ATTACK + IN_ATTACK2 + IN_RELOAD)
	end
end)

if SERVER then
	hook.Add("Think", "hg_weapon_holster_complete", function()
		if next(pending) == nil then return end

		local now = CurTime()
		for wep, data in pairs(pending) do
			local owner = data.owner
			if not IsValid(owner) or not owner:Alive() then
				pending[wep] = nil
				if IsValid(wep) then hg.ClearHolster(wep) end
			elseif not IsValid(wep) then
				pending[wep] = nil
				switchTo(owner, data.target)
			elseif owner:GetActiveWeapon() ~= wep then
				hg.ClearHolster(wep)
			elseif data.finish <= now then
				hg.ClearHolster(wep)
				switchTo(owner, data.target)
				if owner:GetActiveWeapon() == wep and wep.Deploy then wep:Deploy() end
			end
		end
	end)
end
