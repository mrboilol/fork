--[[
	Medicine in an NPC's hands.

	Now that NPCs hold a bandage for a fifth of a second before using it
	(sv_medical.lua) the whole family has to be drawn while somebody is holding it, and
	there are two shapes of the problem.

	The wraps, the medkit, the tourniquet and every item in 1nazuma's pack inherit this
	and nothing else:

		function SWEP:DrawWorldModel()
			if not IsValid(self:GetOwner()) then
				self:DrawWorldModel2()
			end
		end

	which is weapon_bandage_sh.lua:45, weapon_tpik_base.lua:95 and weapon_medbase.lua:46,
	the three roots everything here grows out of. DrawWorldModel2 is the half that puts a
	model on a right hand; an item on the floor draws itself through it, and an item in a
	hand waits for whoever owns the hand to do the drawing. The pass that does that is
	DrawPlayerRagdoll (fake/sh_render.lua:91) which, name aside, walks players - so an
	NPC's bandage is drawn by nobody at all and the hand is empty. That is the half of
	"the item is not in their hands" that is about the hands; the other half is a
	prop_physics thrown out of them, and it is answered on the server (PatchGarbage).

	The syringes are the other shape. Those override DrawWorldModel with a real one
	that reads the owner's right hand bone itself (weapon_naloxone.lua:60), and it
	works on an NPC as written. What it does not do is ask for the bones first, and
	GetBoneMatrix hands back whatever they were last set up as: the item and the NPC
	holding it are two entries in the render list, and when the item comes first the
	model is drawn on the hand of wherever that NPC was standing last frame.

	So each shape gets the one thing it is missing, and which shape an item is is
	decided by whose function it is holding rather than by guessing at what it does.
]]

ZCNPC = ZCNPC or {}

-- Where the gated stub is written. weapon_bandage_sh is the wraps and everything a wrap
-- grew into, weapon_tpik_base is what weapon_hg_medicine_base itself stands on, and
-- weapon_medbase is the root of 1nazuma's pack - the same stub again, word for word
-- (weapon_medbase.lua:46), and every item in that pack inherits it without touching it.
-- That last one is the surgical kit as well, which is why it no longer has a file of its
-- own: weapon_cms is one of the twenty-odd items hanging off this.
local GATED_BASES = { "weapon_bandage_sh", "weapon_tpik_base", "weapon_medbase" }

-- Same list sv_medical.lua patches Heal on, and for the same reason: an item added by a
-- medicine pack nobody here has read hangs off one of these, and it is going to be held
-- in an NPC's hand exactly like the rest.
local MEDICINE_BASES = { "weapon_bandage_sh", "weapon_hg_medicine_base", "weapon_medbase" }

local ours = {} -- [function] = true, wrappers this file has put on
local gated = {} -- [function] = true, the stub that draws nothing while anybody holds it

local function Stored(class)
	if not (isstring(class) and isfunction(weapons.GetStored)) then return end

	return weapons.GetStored(class)
end

-- Learned rather than described. The stub is one function object shared by every item
-- that never overrode it, so an item is holding the stub if it is holding *that*, and no
-- reading of the body is needed to tell.
local function LearnGates()
	for i = 1, #GATED_BASES do
		local base = Stored(GATED_BASES[i])
		local fn = istable(base) and rawget(base, "DrawWorldModel")

		if isfunction(fn) and not ours[fn] then gated[fn] = true end
	end
end

local function Wrap(tbl)
	if not istable(tbl) then return end

	local orig = rawget(tbl, "DrawWorldModel") or tbl.DrawWorldModel
	if not isfunction(orig) then return end

	-- Already answered for, either on this item or on the base it inherits from.
	if ours[orig] then return end

	local stub = gated[orig] == true

	local wrapper = function(self, ...)
		local owner = self:GetOwner()

		if not (IsValid(owner) and owner:IsNPC()) then
			return orig(self, ...)
		end

		-- The body while it is on the floor, the NPC while it is standing. Both halves
		-- of the family ask hg.GetCurrentCharacter the same question and have to be
		-- handed the same answer, or the bones are set up on one of them and read off
		-- the other. Asked for rather than assumed, so an item mounted without Z-City
		-- under it goes back to drawing nothing instead of erroring every frame.
		local ent = istable(hg) and isfunction(hg.GetCurrentCharacter)
			and hg.GetCurrentCharacter(owner) or owner
		if not IsValid(ent) then return end

		-- Not SetupBones directly: the hand an item belongs in is often a posed one - a
		-- rescue kneels its medic down for the length of the treatment (cl_loot.lua) - and
		-- SetupBones is precisely what throws a pose away. cl_render.lua knows which it is.
		ZCNPC.ReadBones(ent)

		-- The stub's own answer for an NPC is to draw nothing, so there is nothing to
		-- hand it back to. Anything with a DrawWorldModel of its own draws the right
		-- model on the right hand already and only wanted the bones - and it must be the
		-- one that runs, because the DrawWorldModel2 those inherit alongside draws
		-- self.WorldModel and the syringes keep their model in self.Model.
		if not stub then return orig(self, ...) end
		if not isfunction(self.DrawWorldModel2) then return end

		return self:DrawWorldModel2()
	end

	ours[wrapper] = true
	rawset(tbl, "DrawWorldModel", wrapper)
end

local function IsMedicine(class)
	if not (isstring(class) and isfunction(weapons.IsBasedOn)) then return false end

	for i = 1, #MEDICINE_BASES do
		if class ~= MEDICINE_BASES[i] and weapons.IsBasedOn(class, MEDICINE_BASES[i]) then
			return true
		end
	end

	return false
end

-- The instance table resolves its methods through weapons.Get, so a wrapper put on a
-- base only reaches an item built after it went on. One that was already lying in the
-- world keeps whatever it was built with, which is the stub - same rebinding sv_medical.lua
-- does on the server and for the same reason.
local function Bind(wep)
	if not IsValid(wep) then return end
	if not IsMedicine(wep:GetClass()) then return end

	local tbl = wep:GetTable()
	if not istable(tbl) then return end

	Wrap(Stored(wep:GetClass()))

	local fn = tbl.DrawWorldModel
	if isfunction(fn) then wep.DrawWorldModel = fn end
end

local function PatchDraw()
	if not isfunction(weapons.GetStored) then return end

	-- Before anything is wrapped, or the stub being looked for is already ours.
	LearnGates()

	-- The bases first, so everything that never overrode the stub is covered by the one
	-- wrapper and the sweep below finds nothing left to do for it.
	for i = 1, #GATED_BASES do
		Wrap(Stored(GATED_BASES[i]))
	end

	if isfunction(weapons.GetList) then
		for _, wep in ipairs(weapons.GetList()) do
			if IsMedicine(wep.ClassName) then Wrap(Stored(wep.ClassName)) end
		end
	end

	for _, wep in ipairs(ents.FindByClass("weapon_*")) do
		Bind(wep)
	end
end

hook.Add("InitPostEntity", "zcnpc_med_draw", PatchDraw)
hook.Add("OnReloaded", "zcnpc_med_draw", PatchDraw)
PatchDraw()

hook.Add("OnEntityCreated", "zcnpc_med_draw", function(ent)
	if not IsValid(ent) then return end

	local class = ent:GetClass()
	if not (isstring(class) and class:sub(1, 7) == "weapon_") then return end

	timer.Simple(0, function()
		if IsValid(ent) then Bind(ent) end
	end)
end)
