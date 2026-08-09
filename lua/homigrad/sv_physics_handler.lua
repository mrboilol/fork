local hg_prop_settle_delay = ConVarExists("hg_prop_settle_delay") and GetConVar("hg_prop_settle_delay") or CreateConVar("hg_prop_settle_delay", "6", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Delay before settled loose props are put to sleep.", 0, 300)
local hg_prop_sleep_velocity = ConVarExists("hg_prop_sleep_velocity") and GetConVar("hg_prop_sleep_velocity") or CreateConVar("hg_prop_sleep_velocity", "22", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Maximum linear velocity for a prop to be considered settled by the optimizer.", 0, 500)
local hg_prop_sleep_ang_velocity = ConVarExists("hg_prop_sleep_ang_velocity") and GetConVar("hg_prop_sleep_ang_velocity") or CreateConVar("hg_prop_sleep_ang_velocity", "35", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Maximum angular velocity for a prop to be considered settled by the optimizer.", 0, 1000)

local propClasses = {
	"prop_physics",
	"prop_physics_multiplayer"
}

local function IsLooseOptimizableProp(ent)
	if not IsValid(ent) then return false end
	if IsValid(ent:GetParent()) then return false end
	if ent:GetCustomCollisionCheck() then return false end
	if ent:IsPlayerHolding() then return false end
	if constraint.HasConstraints(ent) then return false end
	if ent:CreatedByMap() then return false end
	if ent.zcity_collision_proxy or IsValid(ent.hg_collision_source) then return false end
	if hg.GetLootBoxData and hg.GetLootBoxData(ent) then return false end

	return true
end

local function RestoreOptimizedProp(ent)
	if not ent.hg_prop_optimizer_collision_changed then return end

	if ent:GetCollisionGroup() == COLLISION_GROUP_DEBRIS then
		local wantedCollisionGroup = ent.hg_prop_optimizer_collision_group or COLLISION_GROUP_NONE
		hg.SafeSetCollisionGroup(ent, wantedCollisionGroup)
	end

	ent.hg_prop_optimizer_collision_changed = nil
end

local function PropIsSettled(phys, maxVelSqr, maxAngVelSqr)
	if not IsValid(phys) then return false end
	if phys:GetVelocity():LengthSqr() > maxVelSqr then return false end
	if phys:GetAngleVelocity():LengthSqr() > maxAngVelSqr then return false end

	return true
end

timer.Create("hg_prop_optimizer", 4, 0, function()
	local now = CurTime()
	local maxVelSqr = hg_prop_sleep_velocity:GetFloat() ^ 2
	local maxAngVelSqr = hg_prop_sleep_ang_velocity:GetFloat() ^ 2
	for _, class in ipairs(propClasses) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if not IsValid(ent) then continue end

			ent.hg_prop_optimizer_spawn = ent.hg_prop_optimizer_spawn or now

			local phys = ent:GetPhysicsObject()
			if not IsValid(phys) then
				RestoreOptimizedProp(ent)
				continue
			end

			if not IsLooseOptimizableProp(ent) then
				RestoreOptimizedProp(ent)
				continue
			end

			-- Older versions moved settled props into the debris collision group,
			-- which lets them pass through players. Restore any props left in that
			-- state after a reload, then only optimize their sleep state.
			RestoreOptimizedProp(ent)

			if (now - ent.hg_prop_optimizer_spawn) < hg_prop_settle_delay:GetFloat() then
				continue
			end

			if not PropIsSettled(phys, maxVelSqr, maxAngVelSqr) then
				RestoreOptimizedProp(ent)
				continue
			end

			phys:Sleep()
		end
	end
end)
