TOOL.Author = "Mikey / Meetric"
TOOL.Category = "Construction"
TOOL.Name = "#tool.func_door_vphysics_tool.name"
TOOL.ClientConVar["client_rotation"] = 0

TOOL.Information = {
    {name = "left"},
    {name = "right"},
    {name = "reload"}
}

if CLIENT then
    language.Add("tool.func_door_vphysics_tool.name", "Collision Stabilizer")
    language.Add("tool.func_door_vphysics_tool.desc", "Stabilizes collisions between props and players")
    language.Add("tool.func_door_vphysics_tool.left", "Left click to enable stabilization, click again to disable it")
    language.Add("tool.func_door_vphysics_tool.right", "Right click to stabilize all constrained props")
    language.Add("tool.func_door_vphysics_tool.reload", "Reload to de-stabilize all constrained props")
end

local function valid_door(ent)
	return IsValid(ent) and 
		!ent.DOOR_CHILD and 
		--ent:GetCollisionGroup() == COLLISION_GROUP_NONE and 
		!ent:IsRagdoll() and
		ent:IsSolid()
end

local function create_door(ent, client_rotation)
	local door = ents.Create("func_door_vphysics")
	door:SetPos(ent:GetPos())
	door:SetAngles(ent:GetAngles())
	door:SetModel(ent:GetModel())
	door:SetNotSolid(true)	-- avoid lil physics spazm
	door:SetClientRotation(client_rotation)
	door:Spawn()

	door.DOOR_PARENT = ent
	ent.DOOR_CHILD = door

	SafeRemoveEntity(constraint.NoCollide(ent, door, 0, 0))	-- ShouldCollide optimization
	ent:DeleteOnRemove(door)
	door:Think()

	duplicator.StoreEntityModifier(ent, "func_door_vphysics", {client_rotation})
	
	return door
end

local function remove_door(ent)
	ent.DOOR_CHILD.Think = nil	-- Remove() takes a frame to delete and ENT:Think can sometimes be called and reset the parents collision group back to PASSABLE_DOOR
    ent.DOOR_CHILD:Remove()
    ent.DOOR_CHILD = nil
	
	-- reset its collision
	if ent:GetCollisionGroup() == COLLISION_GROUP_PASSABLE_DOOR then
    	ent:SetCollisionGroup(COLLISION_GROUP_NONE)
	end

	duplicator.ClearEntityModifier(ent, "func_door_vphysics")
end

duplicator.RegisterEntityModifier("func_door_vphysics", function(_, ent, data) create_door(ent, data[1]) end)

function TOOL:LeftClick(tr)
    local ent = tr.Entity
	if ent.DOOR_CHILD then 
		remove_door(ent) 
		return true
	end

	local valid = valid_door(ent)
	if CLIENT or !valid then return valid end

    create_door(ent, self:GetClientNumber("client_rotation") == 1)

	return true
end

function TOOL:Reload(tr)
    local ent = tr.Entity
	if CLIENT then return true end

	for _, constrained in pairs(constraint.GetAllConstrainedEntities(ent)) do
		if constrained.DOOR_CHILD then
			remove_door(constrained)
		end
	end

    return true
end

function TOOL:RightClick(tr)
    local ent = tr.Entity
	if CLIENT then return true end

	local client_rotation = self:GetClientNumber("client_rotation") == 1
	for _, constrained in pairs(constraint.GetAllConstrainedEntities(ent)) do
		if constrained.DOOR_CHILD then
			constrained.DOOR_CHILD:SetClientRotation(client_rotation)
		elseif valid_door(constrained) and constrained:GetCollisionGroup() == COLLISION_GROUP_NONE then 
			create_door(constrained, client_rotation)
		end
	end

    return true
end

-- WARNING: UNOPTIMIZED!
function TOOL:DrawHUD()
	cam.Start3D()
	for k, v in ipairs(ents.FindInSphere(EyePos(), 1000)) do
		if v:GetClass() == "func_door_vphysics" then
			local col = v:GetClientRotation() and 1 or 0
			render.SetColorModulation(1 - col, 1, 1 - col)
			v:Draw()
		end
	end
	cam.End3D()
end

function TOOL.BuildCPanel(CPanel)
	CPanel:CheckBox("Client Rotation", "func_door_vphysics_tool_client_rotation")
    CPanel:AddControl("Header", {Description = "Off = User rotates independently\nOn = User rotates with prop (green)"})
end