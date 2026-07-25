------------------------
-- Might be useful
------------------------
local inf,ninf,ind = 1/0,-1/0,(1/0)/(1/0)

--(ind==ind) == false :(. This should do though. >= and <= because you never know :3

function math.BadNumber(v) 
	return not v or v==inf or v==ninf or not (v>=0 or v<=0) or tostring(v) == "nan"
end

local max_reasonable_pos 		= 25000
local min_reasonable_pos 		= -25000

hg = hg or {}
hg._queuedCollisionRuleRefresh = hg._queuedCollisionRuleRefresh or {}
hg._queuedCollisionGroupChanges = hg._queuedCollisionGroupChanges or {}
hg._queuedCustomCollisionChecks = hg._queuedCustomCollisionChecks or {}

function hg.QueueCollisionRulesChanged(ent)
	if not IsValid(ent) then return end
	hg._queuedCollisionRuleRefresh[ent] = true
end

function hg.QueueSetCollisionGroup(ent, collisionGroup)
	if not IsValid(ent) then return end
	hg._queuedCollisionGroupChanges[ent] = collisionGroup
end

function hg.QueueSetCustomCollisionCheck(ent, enabled)
	if not IsValid(ent) then return end
	hg._queuedCustomCollisionChecks[ent] = enabled and true or false
end

function hg.SafeSetCustomCollisionCheck(ent, enabled)
	if not IsValid(ent) then return end

	if hg.QueueSetCustomCollisionCheck then
		hg.QueueSetCustomCollisionCheck(ent, enabled)
	else
		ent:SetCustomCollisionCheck(enabled)
	end
end

function hg.SafeSetCollisionGroup(ent, collisionGroup)
	if not IsValid(ent) then return end

	if hg.QueueSetCollisionGroup then
		hg.QueueSetCollisionGroup(ent, collisionGroup)
	else
		ent:SetCollisionGroup(collisionGroup)
	end
end

function hg.SafeCollisionRulesChanged(ent)
	if not IsValid(ent) then return end

	if hg.QueueCollisionRulesChanged then
		hg.QueueCollisionRulesChanged(ent)
	else
		ent:CollisionRulesChanged()
	end
end

function hg.ApplyCollisionRulesChangedNow(ent)
	if not IsValid(ent) then return end

	hg._queuedCollisionRuleRefresh[ent] = nil
	ent:CollisionRulesChanged()
end

function hg.ApplySetCollisionGroupNow(ent, collisionGroup, refreshRules)
	if not IsValid(ent) then return end

	hg._queuedCollisionGroupChanges[ent] = nil

	if ent:GetCollisionGroup() ~= collisionGroup then
		ent:SetCollisionGroup(collisionGroup)
	end

	if refreshRules ~= false then
		hg.ApplyCollisionRulesChangedNow(ent)
	end
end

function hg.ApplySetCustomCollisionCheckNow(ent, enabled, refreshRules)
	if not IsValid(ent) then return end

	hg._queuedCustomCollisionChecks[ent] = nil
	enabled = enabled and true or false

	if ent:GetCustomCollisionCheck() ~= enabled then
		ent:SetCustomCollisionCheck(enabled)
	end

	if refreshRules ~= false then
		hg.ApplyCollisionRulesChangedNow(ent)
	end
end

if SERVER then
	hook.Add("Tick", "hg_queue_collision_rules_changed", function()
		for ent, enabled in pairs(hg._queuedCustomCollisionChecks) do
			hg._queuedCustomCollisionChecks[ent] = nil

			if IsValid(ent) and ent:GetCustomCollisionCheck() ~= enabled then
				ent:SetCustomCollisionCheck(enabled)
			end
		end

		for ent, collisionGroup in pairs(hg._queuedCollisionGroupChanges) do
			hg._queuedCollisionGroupChanges[ent] = nil

			if IsValid(ent) and ent:GetCollisionGroup() ~= collisionGroup then
				ent:SetCollisionGroup(collisionGroup)
			end
		end

		for ent in pairs(hg._queuedCollisionRuleRefresh) do
			hg._queuedCollisionRuleRefresh[ent] = nil

			if IsValid(ent) then
				ent:CollisionRulesChanged()
			end
		end
	end)
end

function IsReasonable( pos )
	local posY, posZ = pos.y, pos.z

	if (pos.x > max_reasonable_pos or posY < min_reasonable_pos or
		posY > max_reasonable_pos or posZ < min_reasonable_pos or
		posZ > max_reasonable_pos) then
		return false
	end
	return true
end

hook.Add("OnCrazyPhysics","crazy_physics",function(ent, physobj)--function(a,msg,c,d, r,g,b)
	if not IsValid(ent) then return end

	if ent.zcity_collision_proxy or IsValid(ent.hg_collision_source) then
		if IsValid(physobj) then
			physobj:EnableMotion(false)
			physobj:Sleep()
		end

		ent:SetVelocity(vector_origin)
		ent:SetLocalVelocity(vector_origin)
		ent:SetLocalAngularVelocity(angle_zero)
		return
	end

	local restoreMotion = IsValid(physobj) and physobj:IsMotionEnabled()
	if IsValid(physobj) then
		physobj:SetVelocity(vector_origin)
		physobj:SetAngleVelocity(vector_origin)
	end

	ent:SetLocalAngularVelocity(angle_zero)
	ent:SetVelocity(vector_origin)
	ent:SetLocalVelocity(vector_origin)

	if restoreMotion then
		timer.Simple(0, function()
			if not IsValid(ent) or not IsValid(physobj) then return end

			physobj:EnableMotion(true)
			physobj:Wake()
		end)
	end
end)
