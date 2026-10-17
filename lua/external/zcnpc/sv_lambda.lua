--[[
	Lambda mapscript triggers.

	Mapscripts do ents.Create("trigger_once") and call SetupTrigger on what
	comes back (d1_trainstation_01.lua:60). That method lives on Lambda's SENT.
	When the engine class of the same name wins, the call is nil and PostInit
	dies — no queue clip, no Barney room trigger.

	The same hole, one call later: d3_c17_10b.lua:55 does v:ClearOutputs() on a
	map trigger_once. That method lives on lambda_entity. Filling SetupTrigger
	on the Entity metatable lets PostInit walk past the create calls and then
	die here — Z-Lambda pcalls the whole PostInit, so every checkpoint after
	the line is skipped too.

	If the created entity already has SetupTrigger, it is left alone. Wrapping
	a working Lambda method and forcing SOLID_BBOX on it was making touches
	worse, not better. Only a missing method is filled in, and only then by
	swapping in lambda_trigger (Lambda's own class, no engine name clash).
]]

if engine.ActiveGamemode() ~= "lambda" then
	hook.Add("Initialize", "zcnpc_lambda_triggers_boot", function()
		if engine.ActiveGamemode() == "lambda" and not ZCNPC._LambdaTriggers then
			local ok, err = pcall(include, "zcnpc/sv_lambda.lua")
			if not ok then
				ErrorNoHalt("[ZCNPC] sv_lambda.lua failed: " .. tostring(err) .. "\n")
			end
		end
	end)
	return
end

if ZCNPC._LambdaTriggers then return end

ZCNPC._LambdaTriggers = true

local ALLOW_CLIENTS = 0x01

local TRIGGER = {
	lambda_trigger = true,
	trigger_once = true,
	trigger_multiple = true,
	trigger_changelevel = true,
	trigger_hurt = true,
	trigger_teleport = true,
	trigger_transition = true,
	trigger_auto = true,
}

-- Fallback only. Used when even lambda_trigger has no method — a point
-- entity, so SOLID_BBOX, not the brush SOLID_BSP Lambda uses on *models.
local function SetupTrigger(self, pos, ang, mins, maxs, spawn, spawnflags)
	if not IsValid(self) then return end

	if spawnflags == nil then spawnflags = ALLOW_CLIENTS end

	if pos ~= nil then self:SetPos(pos) end
	if ang ~= nil then self:SetAngles(ang) end

	if isfunction(self.AddSpawnFlags) then
		self:AddSpawnFlags(spawnflags)
	elseif isfunction(self.SetKeyValue) then
		self:SetKeyValue("spawnflags", tostring(spawnflags))
	end

	if isfunction(self.SetTrigger) then self:SetTrigger(true) end
	self:SetMoveType(MOVETYPE_NONE)
	self:SetNoDraw(true)

	if spawn ~= false then self:Spawn() end

	if isfunction(self.SetSolid) then self:SetSolid(SOLID_BBOX) end
	if isfunction(self.SetNotSolid) then self:SetNotSolid(true) end
	if isfunction(self.SetTrigger) then self:SetTrigger(true) end
	if isfunction(self.AddSolidFlags) then
		self:AddSolidFlags(bit.bor(FSOLID_NOT_SOLID, FSOLID_TRIGGER))
	end

	if mins ~= nil and maxs ~= nil then self:SetCollisionBounds(mins, maxs) end
	if isfunction(self.UseTriggerBounds) then self:UseTriggerBounds(true) end
	if isfunction(self.CollisionRulesChanged) then self:CollisionRulesChanged() end
end

local function ResizeTriggerBox(self, mins, maxs)
	if not IsValid(self) then return end

	if isfunction(self.SetTrigger) then self:SetTrigger(true) end
	if mins ~= nil and maxs ~= nil then self:SetCollisionBounds(mins, maxs) end
	if isfunction(self.UseTriggerBounds) then self:UseTriggerBounds(true) end
end

-- Same body as lambda_entity:ClearOutputs. On a SENT that already parsed
-- map I/O into OutputsTable this is enough. On an engine entity the C++
-- connections stay; ZLOutputsCleared lets Z-Lambda drop those and keep
-- whatever Fire("AddOutput") put back afterwards.
local function ClearOutputs(self)
	if not IsValid(self) then return end

	self.OutputsTable = {}
	self.EntityOutputs = {}
	self.ZLOutputsCleared = true
end

-- Mapscripts call this as a method (ep2_outland_05), not only via Fire.
local function AddOutput(self, output, target, input, param, delay, times)
	if not IsValid(self) or not isstring(output) then return false end

	self.OutputsTable = self.OutputsTable or {}

	if target == nil or input == nil then return false end

	param = param or ""
	delay = delay or "0"
	times = times or "-1"

	if isfunction(self.Fire) then
		self:Fire("AddOutput", string.format(
			"%s %s:%s:%s:%s:%s",
			output,
			tostring(target),
			tostring(input),
			tostring(param),
			tostring(delay),
			tostring(times)
		))
	end

	local outputData = tostring(target) .. "," .. tostring(input) .. "," .. tostring(param) .. "," .. tostring(delay) .. "," .. tostring(times)
	self.OutputsTable[output] = self.OutputsTable[output] or {}
	self.OutputsTable[output][#self.OutputsTable[output] + 1] = {outputData, 0}

	return true
end

local function SetWaitTime(self, waitTime)
	if not IsValid(self) then return end

	if isfunction(self.SetNWVar) then
		pcall(self.SetNWVar, self, "WaitTime", tonumber(waitTime) or 0)
	end

	if isfunction(self.SetKeyValue) then
		self:SetKeyValue("wait", tostring(waitTime))
	end
end

local function GetTouchingObjects(self)
	if not IsValid(self) then return {} end

	if istable(self.TouchingObjects) then
		local touching = {}
		for entId in pairs(self.TouchingObjects) do
			local ent = Entity(entId)
			if IsValid(ent) then
				touching[entId] = ent
			end
		end
		return touching
	end

	if isfunction(self.WorldSpaceAABB) then
		local mins, maxs = self:WorldSpaceAABB()
		if mins ~= nil and maxs ~= nil then
			local found = ents.FindInBox(mins, maxs)
			local touching = {}
			for i = 1, #found do
				local ent = found[i]
				if IsValid(ent) and ent ~= self then
					touching[ent:EntIndex()] = ent
				end
			end
			return touching
		end
	end

	return {}
end

local function Missing(ent, name)
	return not isfunction(ent[name])
end

local function FillMissing(dest)
	if dest == nil then return end

	if dest.SetupTrigger == nil then dest.SetupTrigger = SetupTrigger end
	if dest.ResizeTriggerBox == nil then dest.ResizeTriggerBox = ResizeTriggerBox end
	if dest.ClearOutputs == nil then dest.ClearOutputs = ClearOutputs end
	if dest.AddOutput == nil then dest.AddOutput = AddOutput end
	if dest.SetWaitTime == nil then dest.SetWaitTime = SetWaitTime end
	if dest.GetTouchingObjects == nil then dest.GetTouchingObjects = GetTouchingObjects end
end

local function Stored(className)
	if scripted_ents == nil or not isfunction(scripted_ents.GetStored) then
		return nil
	end

	local stored = scripted_ents.GetStored(className)
	if istable(stored) and istable(stored.t) then return stored.t end

	return nil
end

local function Arm(ent)
	if not IsValid(ent) then return end

	local class = isfunction(ent.GetClass) and ent:GetClass() or nil
	local tbl = isstring(class) and Stored(class) or nil
	if tbl == nil then tbl = Stored("lambda_trigger") end

	if Missing(ent, "SetupTrigger") then
		if istable(tbl) and isfunction(tbl.SetupTrigger) then
			ent.SetupTrigger = tbl.SetupTrigger
		else
			ent.SetupTrigger = SetupTrigger
		end
	end

	if Missing(ent, "ResizeTriggerBox") then
		if istable(tbl) and isfunction(tbl.ResizeTriggerBox) then
			ent.ResizeTriggerBox = tbl.ResizeTriggerBox
		else
			ent.ResizeTriggerBox = ResizeTriggerBox
		end
	end

	FillMissing(ent)
end

local function CopyMissingFns(dest, src)
	if not (istable(dest) and istable(src)) then return end

	for key, value in pairs(src) do
		if isfunction(value) and dest[key] == nil then
			dest[key] = value
		end
	end
end

local function PatchClass(className)
	local tbl = Stored(className)
	if tbl == nil then return false end

	local base = Stored("lambda_trigger")
	if base ~= nil and tbl ~= base then CopyMissingFns(tbl, base) end

	FillMissing(tbl)

	return true
end

local function PatchClasses()
	for className in pairs(TRIGGER) do
		if Stored(className) ~= nil then
			PatchClass(className)
		end
	end
end

local function PatchMeta()
	local meta = FindMetaTable("Entity")
	if meta == nil then return false end

	FillMissing(meta)

	return true
end

local function MakeOnce(ent)
	if not IsValid(ent) then return end

	if isfunction(ent.SetWaitTime) then
		ent:SetWaitTime(-1)
	elseif isfunction(ent.SetNWVar) then
		ent:SetNWVar("WaitTime", -1)
	elseif isfunction(ent.SetKeyValue) then
		ent:SetKeyValue("wait", "-1")
	end
end

-- C functions cannot be indexed, so "already wrapped" lives here.
local wrappedCreate = nil

local function WrapCreate()
	if not isfunction(ents.Create) then return false end
	if ents.Create == wrappedCreate then return true end

	local old = ents.Create

	local function wrapped(class, ...)
		local ent = old(class, ...)
		if not isstring(class) then return ent end

		local key = string.lower(class)
		if TRIGGER[key] ~= true then return ent end

		if IsValid(ent) and isfunction(ent.SetupTrigger) then
			return ent
		end

		if IsValid(ent) then
			ent:Remove()
		end

		local replacement = old("lambda_trigger", ...)
		if not IsValid(replacement) then
			return ent
		end

		if key == "trigger_once" then
			MakeOnce(replacement)
		end

		if not isfunction(replacement.SetupTrigger) then
			pcall(Arm, replacement)
		end

		return replacement
	end

	ents.Create = wrapped
	wrappedCreate = wrapped

	return true
end

local function Install()
	pcall(PatchMeta)
	pcall(PatchClasses)
	pcall(WrapCreate)
end

pcall(Install)

hook.Add("OnGamemodeLoaded", "zcnpc_lambda_triggers", Install)
hook.Add("Initialize", "zcnpc_lambda_triggers", Install)
hook.Add("InitPostEntity", "zcnpc_lambda_triggers", Install)

timer.Simple(0, Install)
timer.Create("zcnpc_lambda_triggers", 1, 8, Install)

hook.Add("OnEntityCreated", "zcnpc_lambda_triggers", function(ent)
	if not isentity(ent) or not isfunction(ent.GetClass) then return end

	local class = ent:GetClass()
	if not isstring(class) or TRIGGER[class] ~= true then return end

	if Missing(ent, "SetupTrigger") or Missing(ent, "ClearOutputs") then
		Arm(ent)
		timer.Simple(0, function()
			if IsValid(ent) and (Missing(ent, "SetupTrigger") or Missing(ent, "ClearOutputs")) then
				Arm(ent)
			end
		end)
	end
end)
