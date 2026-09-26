--[[
	Medicine on NPCs.

	Every medicine SWEP in Z-City starts its Heal with the same three lines: if
	the thing being treated is an NPC, drop a garbage prop, bump its engine
	health, and delete the item. On an NPC still on its feet that is left exactly
	as it is. A man who is up and still fighting is a man the engine is driving
	off a health bar, that bar is what a medkit has always moved on him, and this
	file does not touch it.

	A body on the floor is the other half of it, and there the shortcut has
	nothing left to move: the NPC behind the body is hidden and frozen, and what
	keeps the body alive is the organism that came across with it when it went
	down (sv_uncon.lua). So for a body the shortcut is held off for the length of
	that one call and the same code that treats a player runs instead: the wound
	closest to bleeding out first, only as much dressing as it took, and a kit
	that still has the rest of itself in it afterwards. A body with nothing wrong
	is not treated at all, because the item spent on it is a real item.

	Running that code against a body needs three things said first, because every
	item opens by assuming a player: where the organism is, that the target has a
	body of ours, and that the hold meter is not this target's. HealOnce answers
	those, calls the item once, and then reads the organism back to find out
	whether anything actually changed - the old wrapper did not, which is why a
	medkit on a body that was unconscious and bleeding internally played its
	sound, kept its charges and did nothing anybody could see.

	The other bug is Secondary.Automatic = true with no NextSecondaryFire —
	holding RMB re-enters SecondaryAttack every tick and dumps a pile of
	medkit props before Remove() can take the weapon away. One press is one
	treatment now, rather than one every half second for as long as it is held.

	Citizens (and anyone whose loot kit rolled anything medical) also use those
	items on themselves when the organism is hurting, and the item is really in
	their hands while they do it: it is given and selected the way the surgery
	hands over its kit (sv_cms.lua), held for a fifth of a second first, and taken
	away again afterwards. It used to be given to nobody at all — a hidden SWEP
	read for its numbers inside one call — because Give runs the item's own
	pick-up heal, which on an NPC is a lump of engine health and a deleted medkit.
	That one call is stepped over while one of ours is holding it, which is what
	makes the rest possible.

	Not only the bandage and the pills, either. Anything in the kit that treats
	something is used through its own Heal against its own organism, so a medkit
	closes an internal bleed and a tourniquet clamps an artery — both of them ways
	to die that a wrap has no answer for, and both of them sat unused in a pocket
	until now. Food, drink and the recreational half of the shelf are left alone.

	Painkillers are swallowed on the spot. Anything that is a kneel and both hands
	waits until the fight is over and nothing hostile is nearby: ducking first,
	wrapping second. They do not wrap a teammate - that was Rescue, and it is gone.
]]

local cfg = ZCNPC.Config

local MEDICINE = {
	weapon_bandage_sh = true,
	weapon_bigbandage_sh = true,
	weapon_medkit_sh = true,
	weapon_tourniquet = true,
	weapon_morphine = true,
	weapon_adrenaline = true,
	weapon_naloxone = true,
	weapon_painkillers = true,
	weapon_painkillers_tpik = true,
	weapon_betablock = true,
	weapon_mannitol = true,
	weapon_needle = true,
	weapon_bloodbag = true,
	weapon_thiamine = true,
	weapon_hg_medicine_base = true,
	weapon_fentanyl = true,
	weapon_pluviska = true,
	weapon_fury13 = true,
	weapon_fury16 = true,
	-- food and drink: same NPCHeal shortcut, same deleted item
	weapon_smallconsumable = true,
	weapon_bigconsumable = true,
	weapon_smallconsumable_tpik = true,
	weapon_bigconsumable_tpik = true,
	-- 1nazuma's Enhanced Medicine. Named one by one as well as caught by their base
	-- below, because a class named here is patched at install rather than the first
	-- time one is built - and the first time one is built is inside a Give, which is
	-- one line too late to stop it healing whoever it landed on.
	weapon_medbase = true,
	weapon_afak = true,
	weapon_salewa = true,
	weapon_grizzly = true,
	weapon_ifak = true,
	weapon_alu = true,
	weapon_e_bandage = true,
	weapon_calokb = true,
	weapon_hemopure = true,
	weapon_car = true,
	weapon_surv12 = true,
	weapon_splint = true,
	weapon_ibuprofen = true,
	weapon_anaglin = true,
	weapon_morphine_injector = true,
	weapon_adrenaline_injector = true,
	weapon_propital = true,
	weapon_sj1 = true,
	weapon_zagus = true,
	weapon_etg = true,
	weapon_etg_admin = true,
	weapon_mildronate = true,
	weapon_largebloodbag = true,
	weapon_injectorcase = true,
	weapon_defibrillator = true,
	weapon_medical_pda = true,
}

-- Everything above hangs off one of these three, and so does anything a medicine
-- pack from the workshop adds.
--
-- weapon_medbase is 1nazuma's Enhanced Medicine, and it is a root rather than a
-- branch: SWEP.Base = "weapon_base" (weapon_medbase.lua:2). Nothing in that pack is
-- based on either of Z-City's own two, so weapons.IsBasedOn said no to all twenty of
-- its items and every list in this file that is built by asking it came back empty -
-- which is why an NPC carrying a Salewa never opened it, never took one off a body,
-- and got the raw NPCHeal shortcut when anything else touched it.
local MEDICINE_BASES = { "weapon_bandage_sh", "weapon_hg_medicine_base", "weapon_medbase" }

local BANDAGE_CLASS = "weapon_bandage_sh"
local BIG_BANDAGE_CLASS = "weapon_bigbandage_sh"
local BLOOD_CLASS = "weapon_bloodbag"
local BIG_BLOOD_CLASS = "weapon_largebloodbag"
local PAINKILLERS_CLASS = "weapon_painkillers"

-- The wraps an NPC will spend, big one first. It is the same item with three and a
-- half times the gauze in it (150 against 40, weapon_bigbandage_sh.lua:9) and the
-- same Bandage underneath, so an NPC that has one closes the wound that needed more
-- than a field dressing with it instead of keeping it forever.
local BANDAGE_CLASSES = { BIG_BANDAGE_CLASS, BANDAGE_CLASS }

local HEAL_COOLDOWN = 4
local PAIN_USE = 12
local BLEED_USE = 0.35
local COVER_RETHINK = 1.5
local CLOSE_ENEMY = 320
-- Adopted rather than created, the same way sv_cms.lua takes it: load order between
-- the two of them and the file that owns it (sv_core.lua) is not settled.
ZCNPC.NPCs = ZCNPC.NPCs or setmetatable({}, { __mode = "k" })

local MEDIC_EXTRA_BANDAGES = 2
local MEDIC_BLOOD_BAGS = 1

local function Stored(class)
	if not (class and isfunction(weapons.GetStored)) then return end

	return weapons.GetStored(class)
end

--\\ The table a method is really written on
-- weapons.GetStored hands back the table the file registered and nothing else: the
-- inheritance is done by weapons.Get, once, when an item is built. So an item that
-- never wrote its own Heal has no Heal on its stored table at all - the one it uses
-- lives on the base - and asking the stored table for it gets nil.
--
-- Which is what UseKitItem was asking. It reads Heal off the stored table to get the
-- copy PatchHeal kept out of its own way, so every item that inherited its Heal was
-- an NPC taking something out of its pocket, holding it for a fifth of a second, and
-- putting it back unused.
--
-- Chain walked with a step limit rather than a seen set: a base loop is a broken
-- addon, not something to be clever about, and eight is deeper than any of these go.
local MAX_BASE_DEPTH = 8

local function Chain(class)
	local list, seen = {}, {}

	for _ = 1, MAX_BASE_DEPTH do
		if not (isstring(class) and class ~= "") or seen[class] then break end

		local tbl = Stored(class)
		if not istable(tbl) then break end

		seen[class] = true
		list[#list + 1] = { class = class, tbl = tbl }

		local base = rawget(tbl, "Base")
		if base == class then break end

		class = base
	end

	return list
end

-- The function and the table it was found on, so a wrapper can be put where the
-- original is rather than copied down onto every item that inherits it.
local function Resolve(class, name)
	for _, link in ipairs(Chain(class)) do
		local fn = rawget(link.tbl, name)

		if isfunction(fn) then return fn, link.tbl end
	end
end
--//

--\\ An item one of ours put in a hand on purpose
-- Three things hand an item to an NPC deliberately: an NPC using something out of its
-- own kit (StartUse below), a rescue spending it on somebody else (sv_rescue.lua), and
-- the surgery (sv_cms.lua). Everything an item does to the NPC that picked it up is
-- written for the other case - an NPC that walked over a bandage lying on the floor -
-- and on one of ours it is all wrong, so it is held off while the flag is up.
--
-- Read high up the file because three separate patches below want it.
local function OursToHold(owner)
	if not IsValid(owner) then return false end

	return istable(owner.zcnpc_meduse)
		or istable(owner.zcnpc_rescue)
		or istable(owner.zcnpc_cms)
end

local function HeldByOurs(wep)
	local owner = wep.GetOwner and wep:GetOwner()

	return IsValid(owner) and owner:IsNPC() and OursToHold(owner)
end
--//

--\\ Who this is, and whether there is anything wrong with them
-- Players are not our business: they get Z-City's medicine exactly as it is. Nor
-- is an NPC on its feet — that one keeps the engine health Z-City has always
-- given it, and returning nothing here is what leaves the stock shortcut to run.
--
-- One of our bodies is the only thing this file takes over: the ragdoll a
-- knockout laid down, the corpse it turned into, or the body an NPC that died on
-- its feet left behind. The organism is on the body by then and nothing else on
-- it means anything.
local function TreatOrganism(ent)
	if not IsValid(ent) then return end
	if ent:IsPlayer() then return end
	if ent:IsNPC() then return end
	if not ent:IsRagdoll() then return end

	local ours = (ZCNPC.Downed and ZCNPC.Downed[ent] ~= nil)
		or IsValid(ent.zcnpc_npc)
		or ent.zcnpc_npcbody == true
		or ent.zcnpc_corpse == true

	if not ours then return end

	local org = ZCNPC.ResolveOrganism and ZCNPC.ResolveOrganism(ent) or ent.organism
	if not istable(org) then return end

	return org
end

local BROKEN = { "chest", "lleg", "rleg", "larm", "rarm" }
local AMPUTATED = { "llegamputated", "rlegamputated", "larmamputated", "rarmamputated" }

-- Everything any of Z-City's medicine has an answer for. Deliberately generous:
-- refusing to treat somebody who needed it is a worse bug than the one being
-- fixed, so the only thing this has to be sure about is "nothing at all".
-- org.alive is the only thing in here that means "too late", and it means it because
-- of what says it: with zcnpc_death_brain on, a body is dead when Z-City's own organism
-- has decided it is (sv_uncon.lua). A stopped heart is further down this function as
-- something to treat, which is what it is - the PDA next door has always called that
-- critical rather than dead, and this is the half that used to disagree.
local function NeedsCare(org)
	if not istable(org) then return false end
	if org.alive == false then return false end

	if istable(org.wounds) and #org.wounds > 0 then return true end
	if istable(org.arterialwounds) and #org.arterialwounds > 0 then return true end
	if (org.bleed or 0) > 0.05 then return true end
	if (org.internalBleed or 0) - (org.internalBleedHeal or 0) > 0.05 then return true end

	if (org.skull or 0) >= 0.6 then return true end
	if (org.brain or 0) > 0 then return true end

	for i = 1, #BROKEN do
		if (org[BROKEN[i]] or 0) >= 1 then return true end
	end

	for i = 1, #AMPUTATED do
		if org[AMPUTATED[i]] then return true end
	end

	if (org.pain or 0) >= 5 or (org.avgpain or 0) >= 5 then return true end
	if (org.blood or 5000) < 4500 then return true end
	if (org.consciousness or 1) < 0.95 then return true end
	if org.otrub or org.heartstop or org.fake then return true end
	if (org.tranquilizer or 0) > 0 then return true end
	if (org.pneumothorax or 0) > 0 then return true end

	local lungL = istable(org.lungsL) and org.lungsL[2] or 0
	local lungR = istable(org.lungsR) and org.lungsR[2] or 0
	if lungL >= 1 or lungR >= 1 then return true end

	return false
end

ZCNPC.NpcNeedsCare = NeedsCare

local REFUSE_SAY = 1.5

local function Say(wep, text)
	local owner = IsValid(wep) and wep:GetOwner()
	if not (IsValid(owner) and owner:IsPlayer()) then return end
	if (owner.zcnpc_med_said or 0) > CurTime() then return end

	owner.zcnpc_med_said = CurTime() + REFUSE_SAY
	owner:ChatPrint(text)
end

local function Refuse(wep, org)
	Say(wep, org and org.alive == false
		and "[ZCNPC] Too late for this one. Nothing medicine can do."
		or "[ZCNPC] Nothing to treat here — the kit stays in your hands.")
end
--//

--\\ Did that do anything?
-- The reason a medkit on an NPC read as doing nothing is that quite often it
-- did. Z-City's dressing only knows about open wounds and bones snapped clean
-- through (weapon_hg_medicine_base.lua:313) and gives up on everything else, so
-- a body that was unconscious, bleeding internally and down to half its blood
-- got the sound, kept the kit and changed by nothing at all - which from the
-- outside is indistinguishable from the bridge being broken.
--
-- So the organism is read either side of the treatment. If nothing moved, that
-- is said out loud instead of left to look like a bug.
local function Vitals(org)
	local wounds = 0

	if istable(org.wounds) then
		for i = 1, #org.wounds do
			wounds = wounds + (tonumber(org.wounds[i][1]) or 0)
		end
	end

	return {
		wounds = wounds,
		arterial = istable(org.arterialwounds) and #org.arterialwounds or 0,
		bleed = org.bleed or 0,
		internal = (org.internalBleed or 0) - (org.internalBleedHeal or 0),
		analgesia = org.analgesiaAdd or 0,
		blood = org.blood or 0,
		pain = org.pain or 0,
		skull = org.skull or 0,
		chest = org.chest or 0,
		lleg = org.lleg or 0,
		rleg = org.rleg or 0,
		larm = org.larm or 0,
		rarm = org.rarm or 0,
		tranquilizer = org.tranquilizer or 0,
		pneumothorax = org.pneumothorax or 0,
		heartstop = org.heartstop and 1 or 0,
		consciousness = org.consciousness or 0,
	}
end

-- What is left in the item. An item that spent some of itself did something,
-- even when the thing it treated was already at its ceiling.
local function Charge(wep)
	local values = IsValid(wep) and wep.modeValues
	if not istable(values) then return 0 end

	local total = 0

	for i = 1, #values do
		total = total + (tonumber(values[i]) or 0)
	end

	return total
end

local function Moved(before, after)
	for key, was in pairs(before) do
		if math.abs((after[key] or 0) - was) > 0.001 then return true end
	end

	return false
end
--//

--\\ The stock shortcut, cut down to the one part of it worth keeping
-- NPCHeal is four things (weapon_bandage_sh.lua:1138): a hold type, a lump of
-- engine health, a sound, and self:Remove(). Three of them are wrong on a body
-- Z-City is simulating - the health is not what keeps it alive and the item
-- deleted is the whole medkit - and the fourth is the only half of a treatment
-- anybody outside the code can tell happened. Every item names its own: pills
-- rattle, a syringe pricks, a wrap is a wrap.
--
-- So while our flag is up the call is answered with that sound and nothing else,
-- on the entity Z-City would have played it on and at the pitch it would have
-- picked. Answering it with silence is a treatment nobody can hear happening,
-- and a treatment nobody can hear reads as an item that did not work.
--
-- The flag is only ever up over a body on the floor. Outside it the shortcut is
-- left exactly as it is: an NPC on its feet is meant to take the engine health,
-- and one that picks a medkit up off the floor (OwnerChanged) is meant to use it
-- and be done with it.
local USE_SOUND = "snd_jack_hmcd_bandage.wav"

local function PatchShortcut(tbl, name)
	if not istable(tbl) then return end

	local key = "zcnpc_med_" .. name
	if rawget(tbl, key) then return end

	local orig = rawget(tbl, name) or tbl[name]
	if not isfunction(orig) then return end

	rawset(tbl, key, true)
	rawset(tbl, name, function(self, npc, mul, snd)
		-- Two ways to be over a body of ours. zcnpc_org_heal is one treatment, opened
		-- and closed around a single call (HealOnce); HeldByOurs is the whole time the
		-- item is out of a pocket, and it is the one that matters here, because the
		-- shortcut is not only reached through Heal.
		--
		-- Every item in 1nazuma's pack calls it straight out of OwnerChanged as well
		-- (weapon_ibuprofen.lua:85), which is a line that runs inside the Give that
		-- handed the item over - before there is a treatment to be inside of. Left to
		-- run, it removed the item a fifth of a second before the NPC was going to use
		-- it, so the hand was empty and the kit was spent for a lump of engine health.
		if not (self.zcnpc_org_heal or HeldByOurs(self)) then
			return orig(self, npc, mul, snd)
		end

		-- Same fallback the original has: called with nothing, it means whoever is
		-- holding the item.
		if not IsValid(npc) then npc = self:GetOwner() end
		if not IsValid(npc) then return end

		npc:EmitSound(isstring(snd) and snd or USE_SOUND, 75, math.random(95, 105))
	end)
end

-- The wrapper an item throws on the floor when it is finished with, and the thing
-- everybody was actually watching.
--
-- SpawnGarbage is not a dropped item: it is a prop_physics copy of the model, spawned
-- on the right hand bone and thrown at two hundred units a second along the owner's
-- aim, with a random spin on top (weapon_bandage_sh.lua:403). On a player pressing the
-- last charge out of a bottle that is an empty bottle tossed aside. On an NPC it is
-- the bandage leaving its hand and flying off across the room - which is the item
-- "hanging in the air next to it", because that is exactly what it is. The one in the
-- hand had already deleted itself through NPCHeal, so there was nothing left to see
-- there.
--
-- Half of the medicine in Z-City drops one from the shortcut before anything has been
-- treated, and every item in 1nazuma's pack drops one from OwnerChanged as well, which
-- is one per Give: an NPC reaching into its own pocket every four seconds threw a prop
-- out every four seconds, and each one shrank and was cleaned up on its own sixty
-- second clock, so they came and went the whole time.
--
-- So while one of ours is holding it, none at all, and none for the length of a call we
-- made ourselves either - a body on the floor is treated by a hand that is not always
-- holding anything (HealOnce), and the litter would be thrown from the middle of the
-- room. Neither of those is a flag spent on the first call: an item drops one from the
-- shortcut, one from OwnerChanged and one from its own Heal, so a guard that clears
-- itself would catch the first and let the other two fly.
--
-- Nothing is lost by it. An item held on purpose is taken away again by hand when the
-- treatment ends (PutAway), so there was never a wrapper left over to leave behind.
local function PatchGarbage(tbl)
	if not istable(tbl) then return end
	if rawget(tbl, "zcnpc_med_garbage") then return end

	local orig = rawget(tbl, "SpawnGarbage") or tbl.SpawnGarbage
	if not isfunction(orig) then return end

	rawset(tbl, "zcnpc_med_garbage", true)
	rawset(tbl, "SpawnGarbage", function(self, ...)
		if self.zcnpc_org_litter or HeldByOurs(self) then return end

		return orig(self, ...)
	end)
end

-- One press, one treatment.
--
-- Z-City's medicine is written for one player treating another, and four of the
-- lines every item opens with are false about a man an NPC is treating:
--
-- * ent.organism, read straight off whatever was under the crosshair. A knockout
--   moves the organism onto the body with it (sv_uncon.lua), but a body an NPC
--   left behind when it died on its feet is not always holding its own, and
--   ResolveOrganism is what went and found it.
-- * org.owner.FakeRagdoll. Painkillers refuse outright a target that has not got
--   one (weapon_painkillers.lua:95). A body we laid down is given one as it is
--   built (sv_uncon.lua:234); a corpse that arrived any other way never had one.
-- * The hold meter, which is charged against the treating player's own model and
--   so is never reached for anything else.
-- * ent:IsNPC(), which is the item asking "is this a thing with an organism or a
--   thing with a health bar". Every one of them opens with it and hands an NPC the
--   stock shortcut instead of a treatment. Z-City's own only plays the sound and
--   carries on (weapon_bandage_sh.lua:615), so this was never noticed - but every
--   item in 1nazuma's pack returns on that line (weapon_medbase.lua:1038,
--   weapon_grizzly.lua:128), and returning is the whole of why a Grizzly with four
--   morphine and eight tourniquets in it did nothing for a standing NPC but make a
--   noise. On our own NPC, with its own organism found and handed over, the answer
--   to that question is no.
--
-- Each of those is answered for the length of one call and put back after it, and
-- the item's own Heal runs untouched in between - a medkit still dresses the way
-- a medkit does, morphine still only dulls pain, and an item added by a medicine
-- pack nobody here has read still does whatever it does. What used to happen
-- instead was that the call was passed straight through and the answer thrown
-- away, so half the medicine in the game quietly did nothing to an NPC.
local function NotAnNpc() return false end

local function HealOnce(wep, ent, org, orig, ...)
	local before, charge = Vitals(org), Charge(wep)

	-- Fields on an entity, not keys in a table: an entity is userdata and rawget
	-- refuses it outright, which is what the medkit error was. A method set this way
	-- is found ahead of the one on the metatable and taken off again by writing the
	-- nil back, which is how IsNPC goes back to telling the truth.
	local hadOrg = ent.organism
	local hadFake = ent.FakeRagdoll
	local hadNpc = ent.IsNPC

	ent.organism = org
	ent.IsNPC = NotAnNpc
	if not (isentity(hadFake) and IsValid(hadFake)) then ent.FakeRagdoll = ent end

	local ownerFake
	local holder = org.owner

	if isentity(holder) and IsValid(holder) and holder ~= ent then
		ownerFake = holder.FakeRagdoll
		if not (isentity(ownerFake) and IsValid(ownerFake)) then holder.FakeRagdoll = holder end
	end

	wep.zcnpc_org_heal = true
	wep.zcnpc_org_litter = true

	local ok, result = pcall(orig, wep, ent, ...)

	wep.zcnpc_org_heal = nil
	wep.zcnpc_org_litter = nil

	if IsValid(ent) then
		ent.organism = hadOrg
		ent.FakeRagdoll = (isentity(hadFake) or hadFake == nil) and hadFake or NULL
		ent.IsNPC = hadNpc
	end

	if isentity(holder) and IsValid(holder) and holder ~= ent then
		holder.FakeRagdoll = (isentity(ownerFake) or ownerFake == nil) and ownerFake or NULL
	end

	if not ok then
		ZCNPC.Debug("medicine Heal failed", result)

		return false
	end

	-- Spending the item counts as having done something even when what it was
	-- for was already at its ceiling: the pills are gone either way, and telling
	-- somebody the kit is still in their hands when it is not is worse than
	-- saying nothing.
	if Moved(before, Vitals(org)) or Charge(wep) < charge - 0.001 or not IsValid(wep) then
		return result ~= false and (result or true) or false
	end

	Say(wep, "[ZCNPC] That did nothing for them — this kit cannot treat what is wrong here.")
	ZCNPC.Debug("medicine changed nothing", ent)

	return false
end

local function PatchHeal(tbl)
	if not istable(tbl) then return end
	if rawget(tbl, "zcnpc_med_heal") then return end

	local orig = rawget(tbl, "Heal") or tbl.Heal
	if not isfunction(orig) then return end

	rawset(tbl, "zcnpc_med_heal", true)

	-- Kept where it can be found again. An NPC treating itself is not a target this
	-- wrapper has anything to say about - TreatOrganism only answers for a body on the
	-- floor - so it would hand a standing NPC straight back to the stock shortcut.
	-- What that NPC actually wants is the item's own Heal against its own organism, and
	-- this is the only copy of it left once the wrapper is on (UseKitItem).
	rawset(tbl, "zcnpc_med_healorig", orig)

	rawset(tbl, "Heal", function(self, ent, ...)
		if CLIENT then return orig(self, ent, ...) end

		local org = ZCNPC.Enabled() and TreatOrganism(ent) or nil
		if not org then return orig(self, ent, ...) end

		if not NeedsCare(org) then
			Refuse(self, org)

			return false
		end

		return HealOnce(self, ent, org, orig, ...)
	end)
end

-- Think on these items calls GetOwner():KeyDown. An NPC has no KeyDown, and a
-- progress bar that ticks every frame is a console dump every frame.
local function PatchThink(tbl)
	if not istable(tbl) then return end
	if rawget(tbl, "zcnpc_med_think") then return end

	local orig = rawget(tbl, "Think") or tbl.Think
	if not isfunction(orig) then return end

	rawset(tbl, "zcnpc_med_think", true)
	rawset(tbl, "Think", function(self, ...)
		local owner = self.GetOwner and self:GetOwner()
		if IsValid(owner) and not owner:IsPlayer() then return end

		local ok, a, b, c = pcall(orig, self, ...)
		if not ok then return end

		return a, b, c
	end)
end
--//

local function PatchSecondary(tbl, class)
	if not istable(tbl) or not class then return end
	if rawget(tbl, "zcnpc_med_once") then return end

	local orig = rawget(tbl, "SecondaryAttack") or tbl.SecondaryAttack
	if not isfunction(orig) then return end

	rawset(tbl, "zcnpc_med_once", true)
	rawset(tbl, "SecondaryAttack", function(self, ...)
		if CLIENT then return orig(self, ...) end

		local owner = self:GetOwner()
		if IsValid(owner) and isfunction(hg.eyeTrace) then
			local tr = hg.eyeTrace(owner)
			local ent = tr and tr.Entity or nil

			-- Bodies on the floor are ragdolls, not NPCs, and holding RMB on one
			-- re-entered this every tick the same way.
			--
			-- One press is one treatment. Automatic is on and nothing here sets
			-- NextSecondaryFire, so a held button arrives back in this function
			-- every tick; a gap wider than a few of them is the button having
			-- been let go of, which is the only edge available from in here
			-- without also owning the weapon's Think.
			if IsValid(ent) and (ent:IsNPC() or TreatOrganism(ent) ~= nil) then
				local now = CurTime()
				local pressed = (now - (self.zcnpc_npc_heal_at or 0)) > 0.25

				self.zcnpc_npc_heal_at = now

				if not pressed then return end
			end
		end

		return orig(self, ...)
	end)
end

--\\ An item is not a weapon, and the AI has never been told
-- Every item in the family opens its Think with
--
--		if not self:GetOwner():KeyDown(IN_ATTACK) ...
--
-- (weapon_bandage_sh.lua:147), and KeyDown is a method an NPC does not have. Nor is
-- KeyPressed, which is the first line of Reload and of both attacks on the bag of
-- blood (weapon_bloodbag.lua:95). None of it has ever been tripped over because an
-- NPC that walks over a medkit is handed the stock shortcut and the item deletes
-- itself in the same tick - but the moment one is meant to be held for a while,
-- every tick of holding it is an error.
--
-- So the same treatment the surgical kit gets, for the same reason and at the same
-- length (sv_cms.lua): the questions only the AI asks are answered with "this does
-- nothing", and the ones written for a player are refused for an NPC and handed on
-- for everybody else. Nothing of ours goes through any of them - an item is held for
-- its model and the treatment is run by hand (UseKitItem below) - so refusing them
-- costs us nothing and a player's kit is not touched by any of it.
local function NpcHolds(wep)
	local owner = wep.GetOwner and wep:GetOwner()

	return IsValid(owner) and owner:IsNPC()
end

local PLAYER_ONLY = { "PrimaryAttack", "SecondaryAttack", "Reload", "Think", "StartUse" }

local function PatchNpcUse(tbl)
	if not istable(tbl) then return end
	if rawget(tbl, "zcnpc_med_npcsafe") then return end

	rawset(tbl, "zcnpc_med_npcsafe", true)

	rawset(tbl, "GetCapabilities", function() return 0 end)
	rawset(tbl, "NPCShoot_Primary", function() end)
	rawset(tbl, "NPCShoot_Secondary", function() end)

	for _, name in ipairs(PLAYER_ONLY) do
		local orig = rawget(tbl, name) or tbl[name]
		if not isfunction(orig) then continue end

		rawset(tbl, name, function(self, ...)
			if NpcHolds(self) then return end

			return orig(self, ...)
		end)
	end
end

-- Handing one over on purpose. Every item heals whoever picks it up the moment it
-- changes hands if that somebody is an NPC - a straight NPCHeal, engine health and
-- the item gone (weapon_hg_medicine_base.lua:990), and in 1nazuma's pack a thrown
-- prop in front of it (weapon_ibuprofen.lua:84). That is the right answer for an NPC
-- that walks over a bandage on the floor and the wrong one for an item this file is
-- putting in a hand, so the one call is stepped over while one of ours owns it
-- (OursToHold, near the top).
--
-- This is the wrapper that has to be on before the item exists rather than after it,
-- because OwnerChanged fires from inside the Give that creates it. A wrapper put on
-- the item itself a frame later has already missed it - so what actually saves this
-- is the same wrapper being on the base the item inherits from, which is why the
-- three roots are patched at install and why weapon_medbase being missing from that
-- list broke every item in that pack.
local function PatchOwner(tbl)
	if not istable(tbl) then return end
	if rawget(tbl, "zcnpc_med_owner") then return end

	local orig = rawget(tbl, "OwnerChanged") or tbl.OwnerChanged
	if not isfunction(orig) then return end

	rawset(tbl, "zcnpc_med_owner", true)
	rawset(tbl, "OwnerChanged", function(self, ...)
		if OursToHold(self:GetOwner()) then return end

		return orig(self, ...)
	end)
end
--//

-- The two syringes are left with their NPC branch: on those it is not a shortcut
-- in front of a treatment, it is the item. A shot of Fury is meant to pick an NPC
-- up off engine health, wind it up and set it on whichever side it was not on.
local KEEP_NPC_BRANCH = {
	weapon_fury13 = true,
	weapon_fury16 = true,
}

local function PatchTable(tbl, class)
	-- The right click spam guard is about how often the item is used, not about
	-- what it does, so everything gets it. So is not crashing when an NPC holds it,
	-- and so is not curing one on contact when the hand it landed in is ours.
	PatchSecondary(tbl, class)
	PatchNpcUse(tbl)
	PatchOwner(tbl)
	PatchThink(tbl)

	if KEEP_NPC_BRANCH[class] then return end

	PatchHeal(tbl)
	PatchShortcut(tbl, "NPCHeal")
	PatchGarbage(tbl)
end

-- Cached per class, because this is asked of every weapon that spawns and answering it
-- walks the base chain. The SWEP registry does not change while a map is running;
-- InstallMedical empties this for the one case where it does.
local medicine = {}

local function ClassIsMedicine(class)
	local known = medicine[class]
	if known ~= nil then return known end

	local answer = false

	if MEDICINE[class] then
		answer = true
	else
		for i = 1, #MEDICINE_BASES do
			if class ~= MEDICINE_BASES[i] and weapons.IsBasedOn(class, MEDICINE_BASES[i]) then
				answer = true
				break
			end
		end

		-- And then the base chain by hand, because IsBasedOn only knows the roots named
		-- above and a pack is free to write its own. Anything that treats somebody has
		-- both of these on it somewhere up its chain, so one that did - weapon_medbase
		-- stands on weapon_base and nothing else - is caught here rather than missed.
		if not answer then
			answer = Resolve(class, "Heal") ~= nil and Resolve(class, "NPCHeal") ~= nil
		end
	end

	medicine[class] = answer

	return answer
end

local function IsMedicine(class, tbl)
	if not isstring(class) then return false end
	if ClassIsMedicine(class) then return true end

	-- An instance has had its inheritance done by weapons.Get, so this is the answer for
	-- one whose class was never registered the way the chain walk expects.
	return istable(tbl) and isfunction(tbl.Heal) and isfunction(tbl.NPCHeal)
end

-- Every table between the item and its root. A wrapper has to go where the function
-- it is wrapping actually lives: put one on the item and the item inherits the
-- unwrapped copy from its base anyway, and PatchHeal's rawget finds nothing to keep,
-- which is the copy UseKitItem needs.
--
-- The walk stops being medicine before it runs out of bases, and that is the point of
-- asking rather than walking to the end: weapon_medbase stands on weapon_base and
-- weapon_hg_medicine_base stands on weapon_tpik_base, neither of which is medicine and
-- both of which are underneath half the weapons in the game. PatchNpcUse on either
-- would answer GetCapabilities with nothing for every rifle an NPC picked up.
local function PatchFamily(class)
	for _, link in ipairs(Chain(class)) do
		if not IsMedicine(link.class, link.tbl) then break end

		PatchTable(link.tbl, link.class)
	end
end

-- The instance table inherits its methods through weapons.Get, so the wrappers
-- above land on it only if the base they came from was already patched. Bind the
-- resolved functions onto the entity as well: a weapon that was created before
-- we got here keeps whatever it was built with otherwise.
local BOUND = {
	"SecondaryAttack", "Heal", "NPCHeal", "SpawnGarbage",
	"OwnerChanged", "PrimaryAttack", "Reload", "Think", "StartUse",
	"GetCapabilities", "NPCShoot_Primary", "NPCShoot_Secondary",
}

local function PatchWeapon(wep)
	if not IsValid(wep) then return end

	local class = wep:GetClass()
	local tbl = wep:GetTable()
	if not IsMedicine(class, tbl) then return end

	PatchFamily(class)
	PatchTable(tbl, class)

	for i = 1, #BOUND do
		local fn = tbl[BOUND[i]]
		if isfunction(fn) then wep[BOUND[i]] = fn end
	end

	wep.zcnpc_med_bound = true
end

function ZCNPC.InstallMedical()
	-- A pack that mounted after the last pass is a pack every class of which is
	-- remembered as not being medicine.
	table.Empty(medicine)

	-- The three roots first: NPCHeal / SpawnGarbage live on them, and everything
	-- else in the family inherits whatever they hold when it is instantiated.
	for i = 1, #MEDICINE_BASES do
		local stored = Stored(MEDICINE_BASES[i])
		if istable(stored) then PatchTable(stored, MEDICINE_BASES[i]) end
	end

	for class in pairs(MEDICINE) do
		PatchFamily(class)
	end

	for _, tbl in ipairs(weapons.GetList()) do
		local class = tbl.ClassName
		if IsMedicine(class, tbl) then PatchFamily(class) end
	end

	for _, wep in ipairs(ents.FindByClass("weapon_*")) do
		PatchWeapon(wep)
	end
end

ZCNPC.InstallMedical()
hook.Add("InitPostEntity", "zcnpc_medical", ZCNPC.InstallMedical)
hook.Add("OnReloaded", "zcnpc_medical", ZCNPC.InstallMedical)

hook.Add("OnEntityCreated", "zcnpc_medical", function(ent)
	if not IsValid(ent) then return end

	local class = ent:GetClass()
	if not isstring(class) or class:sub(1, 7) ~= "weapon_" then return end

	-- Now, before the tick this was created on has finished handing it to anybody.
	-- OwnerChanged runs from inside Give, so the deferred pass below is a frame past
	-- the one call that matters - it is still wanted, because an item created and given
	-- in one go has a table that is only half built at this point, but it cannot be the
	-- only pass.
	if ClassIsMedicine(class) then PatchFamily(class) end

	timer.Simple(0, function()
		if IsValid(ent) then PatchWeapon(ent) end
	end)
end)

hook.Add("PlayerSwitchWeapon", "zcnpc_medical", function(_, _, wep)
	timer.Simple(0, function()
		if IsValid(wep) then PatchWeapon(wep) end
	end)
end)

--\\ Self-use / medic ally-use from the rolled loot kit
local function KitHas(npc, class)
	if not (IsValid(npc) and class) then return false end
	if npc.zcnpc_lootspent and npc.zcnpc_lootspent[class] then return false end

	local kit = ZCNPC.EnsureLootKit and ZCNPC.EnsureLootKit(npc)
	if not istable(kit) then return false end

	for i = 1, #kit do
		if kit[i] == class then return true end
	end

	return false
end

-- The surgical kit (sv_cms.lua) and the body search (sv_looting.lua) ask the same
-- question about the same roll, so it is asked in one place.
ZCNPC.KitHasItem = KitHas

local function SpendMed(npc, class)
	if ZCNPC.MarkLootSpent then ZCNPC.MarkLootSpent(npc, class) end
end
--//

--\\ Getting it out first
-- Every treatment in this file used to be a single moment. The organism moved, a
-- sound played, and the item it came out of never existed anywhere anybody could
-- see it: a hidden SWEP spawned, read for its numbers and removed inside one call.
-- What that looks like from the outside is a man who stops bleeding for no reason.
--
-- So the item comes out first, and it is the real thing - the same Give / SelectWeapon
-- the surgery hands its kit over with (sv_cms.lua), so the model is the item's own and
-- anybody watching can tell a bandage from a syringe. Getting it out and putting it away
-- again is all this section does; what happens in between belongs to whoever asked.
--
-- And it is not instant, at either end. Three tenths of a second passes between the item
-- reaching the hand and being used, because reaching for something is not free, and it
-- stays in the hand for a moment afterwards rather than vanishing on the frame it worked.
--
-- The second half of that is the one that was wrong. A fifth of a second of draw and
-- then the item gone in the same tick as the effect is not a man using something, it is
-- a man showing you something: at thirty frames a second there were perhaps four frames
-- of a bandage in a hand, and the wrap appeared on the arm after the bandage had already
-- disappeared. Now the use happens with the item still in the hand and the hand puts it
-- away afterwards, which is the order those two things happen in.
local DRAW_TIME = 0.3
local DRAW_TICK = 0.05

-- And how long it keeps hold of it afterwards.
local HOLD_TIME = 0.6

-- Long enough past its own clock to mean nobody is coming back for it, the same guard
-- the surgery keeps over its twelve seconds (sv_cms.lua:317). Nothing here takes a
-- pair of feet away, so a use nobody finished is only an item left in a hand - but an
-- item left in a hand is a rifle that is not in it.
local USE_STALE = 3

local using = {} -- [npc] = true, for the length of one use

-- Named here so the use timer can abort a wrap when the fight starts, even
-- though the two functions are written further down.
local SafeToBandage, SeekCover

-- The item away and the rifle back. Between them these are every way out of a use:
-- finished with, interrupted, and the NPC holding it going down.
local function PutAway(npc, state)
	using[npc] = nil

	local wep = state.wep
	state.wep = nil
	if IsValid(wep) then wep:Remove() end

	if not IsValid(npc) then return end

	-- After the item is gone, not before: while this is set the item's own pick-up
	-- heal is stepped over (PatchOwner), and the last thing it does on its way out
	-- must still be stepped over.
	npc.zcnpc_meduse = nil

	local org = ZCNPC.ResolveOrganism and ZCNPC.ResolveOrganism(npc) or npc.organism
	if istable(org) then org.zcnpc_heal_blood = nil end

	local back = state.hadclass
	if not back then return end

	-- Only if it still has it. Losing the rifle mid-use is one of the ways a use ends,
	-- and re-selecting a gun that is on the floor now leaves an NPC aiming an empty
	-- hand.
	for _, held in ipairs(npc:GetWeapons() or {}) do
		if IsValid(held) and held:GetClass() == back then
			npc:SelectWeapon(back)

			return
		end
	end
end

function ZCNPC.CancelNpcItem(npc, why)
	if not IsValid(npc) then return end

	local state = npc.zcnpc_meduse
	if not istable(state) then return end

	PutAway(npc, state)
	ZCNPC.Debug("item put away unused", npc, state.class, why or "?")
end

-- The item in the hand and nothing else - no clock, no treatment, no bookkeeping.
-- The rescue's phases have timing of their own (sv_rescue.lua) and only want the
-- model held for the length of one of them.
function ZCNPC.NpcHoldItem(npc, class)
	if not (IsValid(npc) and isstring(class) and class ~= "") then return end

	local wep = npc:Give(class)
	if not IsValid(wep) then return end

	npc:SelectWeapon(class)

	return wep
end

-- class is what comes out; use(npc, state) is what to do with it once it is out, and
-- whether that counted for anything. A false answer leaves the kit entry alone.
local function StartUse(npc, class, use, cover)
	if istable(npc.zcnpc_meduse) then return false end
	if not (isstring(class) and isfunction(use)) then return false end

	-- What goes back into the hand afterwards, and it is the gun rather than whatever is
	-- in there now (sv_weapon.lua): asking the plain way would remember an item as the
	-- thing to go back to and leave the NPC holding a bandage for good.
	local held = ZCNPC.HeldGun and ZCNPC.HeldGun(npc) or npc:GetActiveWeapon()

	local state = {
		class = class,
		use = use,
		cover = cover == true,
		at = CurTime() + DRAW_TIME,
		hadclass = IsValid(held) and held:GetClass() or nil,
	}

	-- Set before the item is handed over: PatchOwner reads it to tell this apart from
	-- an NPC stumbling over a bandage on the floor.
	npc.zcnpc_meduse = state

	local wep = ZCNPC.NpcHoldItem(npc, class)
	if not IsValid(wep) then
		npc.zcnpc_meduse = nil

		return false
	end

	state.wep = wep
	using[npc] = true

	return true
end

-- Twenty times a second, so the wait is the wait rather than the wait plus however
-- long the half second pass has left to run.
timer.Create("zcnpc_med_use", DRAW_TICK, 0, function()
	if not next(using) then return end

	for npc in pairs(using) do
		local state = IsValid(npc) and npc.zcnpc_meduse

		if not istable(state) then
			using[npc] = nil

			continue
		end

		-- Still holding it, having already used it. Nothing to decide: the item is in
		-- the hand because it is being used, and the clock is what ends that.
		if state.till then
			if CurTime() < state.till then continue end

			PutAway(npc, state)

			continue
		end

		if CurTime() > state.at + USE_STALE then
			ZCNPC.CancelNpcItem(npc, "nobody came back for it")

			continue
		end

		if CurTime() < state.at then continue end

		-- A wrap started in the quiet and finished in a firefight is the bug:
		-- they knelt down while something walked round the corner.
		if state.cover and not SafeToBandage(npc) then
			ZCNPC.CancelNpcItem(npc, "danger")
			SeekCover(npc)

			continue
		end

		local ok = state.use(npc, state) ~= false

		-- Kept in the hand rather than removed here. What was wrong with removing it
		-- here is not that it was too quick, it is that it was the wrong way round: the
		-- effect of using something arrives while it is still in your hand.
		state.till = CurTime() + HOLD_TIME

		-- Either way: an attempt that changed nothing is still an attempt, and trying
		-- the same thing again on the next pass is an NPC with its hand in its pocket
		-- for the rest of the fight.
		if IsValid(npc) then npc.zcnpc_selfheal_cd = CurTime() + HEAL_COOLDOWN end

		ZCNPC.Debug("used", npc, state.class, ok and "and it did something" or "for nothing")
	end
end)

-- A body on the floor is not taking anything out of its pocket, and losing the item
-- out of the hand is the other way one ends without the timer noticing first.
hook.Add("ZCNPC_Downed", "zcnpc_med_use", function(npc)
	ZCNPC.CancelNpcItem(npc, "downed")
end)

hook.Add("ZCNPC_Disarmed", "zcnpc_med_use", function(npc)
	ZCNPC.CancelNpcItem(npc, "disarmed")
end)

hook.Add("HomigradDamage", "zcnpc_med_use", function(victim)
	if not (IsValid(victim) and victim:IsNPC()) then return end

	victim.zcnpc_lastpain = CurTime()

	local state = victim.zcnpc_meduse
	if istable(state) and state.cover then
		ZCNPC.CancelNpcItem(victim, "took a hit")
	end
end)
--//

--\\ Wraps, blood and pills

-- Medic rebels get spare wraps on top of the kit roll so one self-bandage does
-- not empty the bag they need for allies. Tracked separately because loot spent
-- flags are per-class, not per-copy.
--
-- And a bag of blood, which is Z-City's own answer to what a medic has on him
-- rather than ours: the rebel medic class is handed a bandage, a medkit and one
-- full o- bloodbag by hand at spawn (sh_rebel.lua:154). It is the difference
-- between a rescue that stops the bleeding and one that gets the man back on his
-- feet - nothing wakes up under 2900 blood (sv_uncon.lua) and a body that has
-- bled that low has to be filled back up from somewhere.
local function EnsureMedicSupplies(npc)
	if not (ZCNPC.IsMedicCitizen and ZCNPC.IsMedicCitizen(npc)) then return end
	if npc.zcnpc_medic_bandages ~= nil then return end

	npc.zcnpc_medic_bandages = MEDIC_EXTRA_BANDAGES
	npc.zcnpc_medic_blood = MEDIC_BLOOD_BAGS
end

-- Which wrap it would reach for and where that one comes from. The medic's spares are
-- always plain bandages, because a count is not a kit entry and only one class of
-- them is being counted.
local function CanSpendBandage(npc)
	for i = 1, #BANDAGE_CLASSES do
		local class = BANDAGE_CLASSES[i]

		if KitHas(npc, class) then return class, "kit" end
	end

	if (npc.zcnpc_medic_bandages or 0) > 0 then return BANDAGE_CLASS, "medic" end
end

local function SpendBandage(npc, class, source)
	if source == "medic" then
		npc.zcnpc_medic_bandages = math.max((npc.zcnpc_medic_bandages or 0) - 1, 0)

		return
	end

	SpendMed(npc, class or BANDAGE_CLASS)
end

local function NeedsBandage(org)
	if not org then return false end
	if (org.bleed or 0) >= BLEED_USE then return true end
	if istable(org.wounds) and #org.wounds > 0 then return true end
	if (org.skull or 0) >= 0.6 then return true end
	if org.chest == 1 or org.lleg == 1 or org.rleg == 1 or org.larm == 1 or org.rarm == 1 then
		return true
	end

	return false
end

local function NeedsPainkillers(org)
	if not org then return false end
	if (org.analgesiaAdd or 0) >= 2.5 then return false end

	return (org.pain or 0) >= PAIN_USE or (org.avgpain or 0) >= PAIN_USE * 0.5
end

-- Every pill and every needle whose whole job is to take the edge off, in the order an
-- NPC would rather have them. Z-City's own bottle first because it is the one that is
-- always there, then the two out of 1nazuma's pack, then the needles - a needle is
-- worth more than a pill and there is no reason to spend it on pain while a pill will
-- do.
--
-- A list rather than the one class this used to be, and that is the whole of why
-- nobody ever got painkillers. weapon_painkillers is Z-City's, and 1nazuma's loot pool
-- does not roll it: a metrocop's pills are Ibuprofen, a citizen's are Anaglin, and a
-- Combine's are a morphine needle (sh_custom_lootpool.lua:29, :223, :122). So with that
-- pool mounted the only pill class this file knew about was one that was never in
-- anybody's pocket, and NeedsPainkillers was answered every pass with "yes, and there
-- is nothing to do about it".
local PAINKILLER_CLASSES = {
	PAINKILLERS_CLASS,
	"weapon_painkillers_tpik",
	"weapon_ibuprofen",
	"weapon_anaglin",
	"weapon_morphine",
	"weapon_morphine_injector",
	"weapon_sj1",
}

local PAINKILLER_SET = {}

for i = 1, #PAINKILLER_CLASSES do PAINKILLER_SET[PAINKILLER_CLASSES[i]] = true end

local function CanSpendPainkillers(npc)
	for i = 1, #PAINKILLER_CLASSES do
		local class = PAINKILLER_CLASSES[i]

		if KitHas(npc, class) then return class end
	end
end

-- For the body search, which asks of each thing on a corpse whether this NPC is short of
-- it and answers that by class (sv_looting.lua). One bottle is as good as another, so an
-- NPC with Ibuprofen in a pocket is not short of Anaglin - and with five pill classes in
-- the pool, asking by class is an NPC walking across the street for a second bottle of
-- something it is already carrying. Nil for anything that is not a pill, so the search
-- can go on using its own rule for everything else.
function ZCNPC.NpcNeedsPainkillers(npc, class)
	if not PAINKILLER_SET[class] then return end

	return CanSpendPainkillers(npc) == nil
end

-- Same street the body search uses (sv_looting.lua), so the quiet sweep the
-- half-second pass already paid for is reused rather than run again.
local HEAL_QUIET = 1000
local PAIN_LOCK = 2.5

-- In a fight, or just been shot. Losing line of sight is not cover: that is how
-- they used to kneel down and wrap while the shooting was still going.
local function InFight(npc)
	if (npc.zcnpc_lastpain or 0) + PAIN_LOCK > CurTime() then return true end

	if isfunction(npc.GetNPCState) and npc:GetNPCState() == NPC_STATE_COMBAT then
		return true
	end

	local enemy = npc:GetEnemy()
	if not IsValid(enemy) then return false end
	if enemy:IsPlayer() then return enemy:Alive() end
	if not enemy:IsNPC() then return true end
	if enemy:Health() <= 0 then return false end
	if ZCNPC.IsHidden and ZCNPC.IsHidden(enemy) then return false end

	return true
end

-- Cover = nobody hostile nearby, and not mid-fight. Pills ignore this; wraps do
-- not — wrapping in the open is how you get shot again.
SafeToBandage = function(npc)
	if InFight(npc) then return false end
	if ZCNPC.NoThreatNear then return ZCNPC.NoThreatNear(npc, HEAL_QUIET) end

	return not IsValid(npc:GetEnemy())
end

SeekCover = function(npc)
	-- Cover is somewhere else, and where a scripted NPC stands is the map's to say
	-- (sv_core.lua). It goes without the wrap rather than leaving its post for
	-- one: the caller only ever asks for cover because it is not safe to kneel
	-- here, and that answer holds.
	if ZCNPC.MapDriven(npc) then return end

	-- Nor is it worth a needle already in its own leg (sv_cms.lua): that one owns
	-- the feet for twelve seconds and ends itself the moment anything turns up
	-- worth taking cover from. A rescue under way is the same answer - it is already
	-- walking somebody out of the open, which is a better idea than cover for one.
	if istable(npc.zcnpc_cms) then return end
	if istable(npc.zcnpc_rescue) then return end

	-- Soft lock so armour pickup / other chores do not yank them out of cover.
	npc.zcnpc_bandagecover = CurTime() + COVER_RETHINK + 0.25

	if (npc.zcnpc_covernext or 0) > CurTime() then return end
	npc.zcnpc_covernext = CurTime() + COVER_RETHINK

	local enemy = npc:GetEnemy()
	if not IsValid(enemy) then return end

	local sched = npc:GetCurrentSchedule()
	if sched == SCHED_TAKE_COVER_FROM_ENEMY or sched == SCHED_RUN_FROM_ENEMY then
		return
	end

	if npc:GetPos():DistToSqr(enemy:GetPos()) < CLOSE_ENEMY * CLOSE_ENEMY then
		npc:SetSchedule(SCHED_RUN_FROM_ENEMY)
	else
		npc:SetSchedule(SCHED_TAKE_COVER_FROM_ENEMY)
	end

	ZCNPC.Debug("seek cover before bandage", npc)
end

-- How much gauze the item comes with, read off the SWEP rather than named here, so a
-- wrap out of a pack with a number of its own is spent at its own number
-- (weapon_bandage_sh.lua: modeValuesdef[1] = { 40, true }).
local BANDAGE_DEFAULT = 40

local function BandageAmount(stored)
	local def = istable(stored) and istable(stored.modeValuesdef) and stored.modeValuesdef[1]
	local amount = istable(def) and tonumber(def[1]) or tonumber(def)

	if amount and amount > 0 then return amount end

	return BANDAGE_DEFAULT
end

local function UseBandage(healer, target, org)
	local class, source = CanSpendBandage(healer)
	if not class then return false end

	local stored = Stored(class)
	-- Bandage is the base's and every wrap in the family inherits it: it is the same
	-- function a player's right click reaches through Heal (weapon_bigbandage_sh.lua:90).
	local bandageFn = istable(stored) and stored.Bandage
	if not isfunction(bandageFn) then return false end

	-- Temporary SWEP so Bandage can EmitSound / read modeValues. Not the one in the hand,
	-- even though there is usually one there now (StartUse, and the rescue's own wrap):
	-- that one is the model anybody watching sees and this one is the numbers, and keeping
	-- them apart is what lets both callers spend a wrap the same way whether or not
	-- anything was drawn. Never Give() it either - it is not an item the NPC has.
	local wep = ents.Create(class)
	if not IsValid(wep) then return false end

	wep:SetPos(healer:GetPos())
	wep:SetNoDraw(true)
	wep:SetNotSolid(true)
	wep:Spawn()
	wep.OwnerChanged = function() end
	wep:SetOwner(healer)

	local gauze = BandageAmount(stored)
	wep.modeValues = { [1] = gauze }

	local bleedBefore = org.bleed or 0
	local okCall, result = pcall(bandageFn, wep, target, nil)
	local left = tonumber(wep.modeValues and wep.modeValues[1]) or 0
	local usedAmount = gauze - left

	-- Bandage's return is "new limb wrapped", not "anything healed". Count any
	-- real spend / bleed drop so we do not retry the same kit forever.
	local ok = (okCall and result) or usedAmount > 0.1 or (org.bleed or 0) < bleedBefore - 0.05

	if IsValid(wep) then wep:Remove() end

	if ok then
		SpendBandage(healer, class, source)
		ZCNPC.Debug(healer == target and "self-bandage" or "ally-bandage", healer, target, class)

		return true
	end

	return false
end

-- What a full bag is worth and the ceiling it fills to, both Z-City's own numbers
-- (weapon_bloodbag.lua:186). The bag is not called through: everything it does lives
-- in a Think written around a held mouse button and a player's eye trace, so there is
-- no function to hand a patient to - the same reason painkillers are swallowed by
-- hand above.
--
-- No cross-matching, and that is not a shortcut. Every bag in Z-City is filled with
-- o- (weapon_bloodbag.lua:46, and the rebel medic's is set to it by hand in
-- sh_rebel.lua:158), and o- is the row that says yes to all eight types
-- (modules/sv_blood.lua:9). The only way to hold a bag of anything else is to have
-- drawn it out of somebody, which is a player with a needle and not this.
local BLOOD_FULL = 500
local BLOOD_CAP = 5200

-- Half the bags in the world are empty, because that is what the item is: a coin
-- flip on spawn decides whether there is anything in it (weapon_bloodbag.lua:43).
-- A kit entry is a class name and nothing else, so the flip is made here instead,
-- once, when the bag is opened. A medic's spare is exempt below - a medic packed
-- that one.
local function BagFull()
	return math.random(2) == 1
end

-- The bags, biggest first, and what each one is worth. 1nazuma's is the same item with
-- more in it (weapon_largebloodbag.lua) and it is driven the same way - PrimaryAttack,
-- SecondaryAttack and a Think, no Heal anywhere on it - so it is filled in here beside
-- Z-City's rather than run through UseKitItem like the rest of that pack.
local BLOOD_BAGS = {
	{ class = BIG_BLOOD_CLASS, volume = BLOOD_FULL * 2 },
	{ class = BLOOD_CLASS, volume = BLOOD_FULL },
}

-- Where it comes from first, because that is what the spend needs to know, then the
-- class and what is in it for whoever wants to put the thing in a hand (sv_rescue.lua).
-- A medic's spare is a plain bag: a count is not a kit entry and only one class of them
-- is being counted.
local function CanSpendBlood(npc)
	if (npc.zcnpc_medic_blood or 0) > 0 then return "medic", BLOOD_CLASS, BLOOD_FULL end

	for i = 1, #BLOOD_BAGS do
		local bag = BLOOD_BAGS[i]

		if KitHas(npc, bag.class) then return "kit", bag.class, bag.volume end
	end
end

local function UseBloodBag(healer, target, org)
	if not istable(org) then return false end

	local source, class, volume = CanSpendBlood(healer)
	if not source then return false end

	-- The needle goes in either way, and the bag is gone either way.
	healer:EmitSound("zcity/healing/bloodbag_spear_0.wav", 60, math.random(95, 105))

	if source == "medic" then
		healer.zcnpc_medic_blood = math.max((healer.zcnpc_medic_blood or 0) - 1, 0)
	else
		SpendMed(healer, class)

		if not BagFull() then
			ZCNPC.Debug("transfusion from an empty bag", healer, target, class)

			return true
		end
	end

	org.blood = math.min((org.blood or 0) + (volume or BLOOD_FULL), BLOOD_CAP)

	healer:EmitSound("zcity/healing/bloodbag_loop_" .. math.random(8) .. ".wav", 60, math.random(95, 105))
	ZCNPC.Debug("transfusion", healer, target, class, math.floor(org.blood))

	return true
end

-- One press of Z-City's own bottle (weapon_painkillers.lua), and the only reason it is
-- written down here is for a bottle whose own Heal cannot be reached at all. Everything
-- that has one is swallowed through it instead (TakePainkillers), because a dose is the
-- item's to say: a morphine needle is worth a whole point of analgesia, Anaglin three
-- quarters and Ibuprofen three tenths (weapon_morphine_injector.lua:90,
-- weapon_anaglin.lua:111, weapon_ibuprofen.lua:112), and averaging them here would be this
-- file inventing numbers for items it has not read.
local PILL_DOSE = 0.4

local function UsePainkillers(npc, org, class)
	org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + PILL_DOSE, 4)
	npc:EmitSound("snd_jack_hmcd_pillsuse.wav", 60, math.random(95, 105))
	SpendMed(npc, class or PAINKILLERS_CLASS)
	ZCNPC.Debug("self-painkillers", npc, class or PAINKILLERS_CLASS)

	return true
end
--//

--\\ The rest of what is in the pockets
-- Three items had a function of their own above, because three items are what a rebel
-- was ever handed. Anything else that ended up in a kit - a medkit rolled out of
-- Nazuma's pool, a tourniquet off a body, a syringe out of a pack nobody here has read
-- - sat in that pocket for the rest of the NPC's life.
--
-- Which is worse than a waste. The medkit is the only thing in Z-City that closes an
-- internal bleed (weapon_medkit_sh.lua:137) and the tourniquet the only thing that
-- clamps a limb artery, and both of those are ways to die that a bandage has no answer
-- for - so an NPC was bleeding out internally with the one item that could have stopped
-- it in its pocket.
--
-- None of it is reimplemented. Each one is run through its own Heal against its own
-- organism, which is the same call a player's mouse button makes: the same wound picked,
-- the same charge spent, the same sound. That is the only way an item out of a pack
-- nobody here has read does what it actually does rather than what we guessed it does.
--
-- What is written here is only when it is worth taking out, because that is the one
-- question the item cannot answer. A syringe of adrenaline goes into a man with nothing
-- wrong with him exactly as happily as into one whose heart has stopped.
local function InternalBleeding(org)
	return (org.internalBleed or 0) - (org.internalBleedHeal or 0) > 0.05
end

local function ArterialBleeding(org)
	return istable(org.arterialwounds) and #org.arterialwounds > 0
end

-- A stopped heart, and the compressions in the rescue are the other half of it
-- (sv_rescue.lua). Adrenaline is also what carries a man who is going under, so
-- consciousness on its way out counts - but only while there is not already a syringe of
-- it working, because every item that has any will happily stack a second one.
local function HeartNeedsStarting(org)
	if org.heartstop then return true end

	return (org.consciousness or 1) < 0.5 and (org.adrenalineAdd or 0) < 2
end

-- Swelling inside a skull, which nothing but mannitol touches (weapon_mannitol.lua:89).
local function BrainSwelling(org)
	return (org.brain or 0) > 0 and (org.mannitol or 0) < 2
end

-- A lung with the air on the wrong side of it, and a needle is what lets it out. Not
-- twice: org.needle is the item's own record that one is already in there
-- (weapon_grizzly.lua:195).
local function Pneumothorax(org)
	return (org.pneumothorax or 0) > 0 and (org.needle or 0) < 1
end

-- A limb broken but still attached, which is what a splint is for. Its own floor is a
-- third of the way broken (weapon_splint.lua:90) - lower than the "snapped clean through"
-- a wrap waits for, so a leg a splint can do something about is a leg nothing else will
-- touch. A chest is not a limb and cannot be splinted.
local function BrokenLimb(org)
	for i = 1, #BROKEN do
		local limb = BROKEN[i]

		if limb ~= "chest" and (org[limb] or 0) > 0.3 and not org[limb .. "amputated"] then
			return true
		end
	end

	return false
end

--\\ Which compartment of a kit that has several
-- A first aid kit is not one item. Z-City's own holds gauze, painkillers, tranexamic acid,
-- a tourniquet and a decompression needle; a Grizzly holds those and mannitol and
-- adrenaline as well. Which of them a press spends is self.mode - switched with R and left
-- wherever the last man to hold it left it (weapon_medbase.lua:375) - and each kit's Heal
-- is one long branch on that field (weapon_grizzly.lua:146).
--
-- Nothing here ever set it. So every kit an NPC has ever opened was opened on whatever it
-- was built with, which is mode 1, which is the gauze: the tourniquets, the acid and the
-- needles have never been used by anybody in this addon, and a kit taken out to stop an
-- internal bleed wrapped a bandage round the man's arm instead and reported that it had
-- treated him.
--
-- Read off the item's own names for its own settings rather than by number. The numbers
-- differ between the kits - adrenaline is 7 in a Grizzly and 6 in a Salewa, and a Car kit
-- has no adrenaline at all - but they all name them the same, and a kit added to either
-- pack tomorrow will name them the same too. What is written here is only which need each
-- name answers, in the order worth spending: the artery first because it is the fastest
-- way to die, then the wounds, then what is bleeding where a wrap cannot reach, and the
-- drugs last because pain is not what kills anybody.
local MODE_NEEDS = {
	{ name = "tourniquet", want = ArterialBleeding },
	{ name = "bandaging", want = NeedsBandage },
	{ name = "tranexamic acid", want = InternalBleeding },
	{ name = "decompression needle", want = Pneumothorax },
	{ name = "adrenaline", want = HeartNeedsStarting },
	{ name = "manitol", want = BrainSwelling },
	{ name = "morphine", want = NeedsPainkillers },
	{ name = "painkiller", want = NeedsPainkillers },
	{ name = "splinting", want = BrokenLimb },
}

-- Names to numbers, on one particular kit. Charge is checked here as well: a compartment
-- that has been emptied is not an answer to anything, and picking it is a press that does
-- nothing followed by this file announcing that the kit cannot treat what is wrong.
local function KitMode(wep, org)
	local names = wep.modeNames
	if not istable(names) then return end

	local values = wep.modeValues

	for i = 1, #MODE_NEEDS do
		local need = MODE_NEEDS[i]

		if need.want(org) then
			for mode, name in pairs(names) do
				local left = istable(values) and values[mode]

				if name == need.name and (left == nil or left > 0) then return mode end
			end
		end
	end
end

-- The same question of a class rather than of an item, because PickItem is deciding
-- whether to reach into a pocket and there is nothing in the hand yet to ask. modeNames is
-- written on the SWEP itself, so it can be read without spawning anything; what cannot be
-- read that way is how much is left in each compartment, and a kit that turns out to be
-- empty is one wasted fifth of a second rather than a wrong treatment.
local function KitWant(org, class)
	local stored = isfunction(weapons.GetStored) and weapons.GetStored(class)
	local names = istable(stored) and stored.modeNames

	if not istable(names) then return false end

	for _, name in pairs(names) do
		for i = 1, #MODE_NEEDS do
			if MODE_NEEDS[i].name == name and MODE_NEEDS[i].want(org) then return true end
		end
	end

	return false
end
--//

-- cover = this one is worth ducking for first, the same rule a wrap has always had
-- (SafeToBandage). It is the difference between working on a wound and putting a needle
-- in your own arm: one is both hands and a kneel, the other is over before an NPC has
-- finished turning round. Nothing here is worth standing still in the open for.
local ITEMS = {
	-- The kit that closes what a wrap cannot. First because it is also the best dressing
	-- in the game, so there is nothing it should be reached for after.
	--
	-- Five compartments, not two: gauze, painkillers, tranexamic acid, a tourniquet and a
	-- decompression needle (weapon_medkit_sh.lua:26). This used to be asked only about the
	-- first and the third of those, which was this file describing the item as a dressing
	-- that also stitches - and since nothing set which compartment was being pressed, a
	-- dressing is all it ever was.
	{ class = "weapon_medkit_sh", cover = true, want = KitWant },
	-- A limb artery is the one thing that empties a man faster than he can be wrapped.
	-- Worth it only while there is one to clamp, which is also the only case the item
	-- itself will spend a charge on (weapon_tourniquet.lua:98).
	{ class = "weapon_tourniquet", cover = true, want = ArterialBleeding },
	{ class = "weapon_adrenaline", want = HeartNeedsStarting },
	{ class = "weapon_mannitol", want = BrainSwelling },

	--\\ 1nazuma's Enhanced Medicine
	-- The sweep at the end of PickItem would eventually reach all of these, on the
	-- widest reading of "something is wrong with him" there is. They are named here for
	-- the two things that sweep cannot know: which one to reach for first, and whether
	-- this particular man needs this particular thing. A Grizzly is the best kit in the
	-- pack and a splint is no use at all to somebody whose legs are fine.
	--
	-- The four kits, biggest first, and all four asked the same question: is there
	-- anything wrong with this man that anything in this box answers (KitWant). Written
	-- that way rather than as four lists of wounds because the boxes are not the same -
	-- a Grizzly has mannitol and adrenaline in it and a Car kit has neither - and each of
	-- them already says what is in it.
	--
	-- Behind Z-City's own medkit and tourniquet only because those two are what this
	-- addon has always spent, and an NPC holding one of each should not change its mind
	-- about that because a medicine pack was mounted.
	{ class = "weapon_grizzly", cover = true, want = KitWant },
	{ class = "weapon_afak", cover = true, want = KitWant },
	{ class = "weapon_salewa", cover = true, want = KitWant },
	{ class = "weapon_car", cover = true, want = KitWant },
	{ class = "weapon_ifak", cover = true, want = KitWant },
	{ class = "weapon_alu", cover = true, want = KitWant },
	{ class = "weapon_e_bandage", cover = true, want = NeedsBandage },
	{ class = "weapon_calokb", want = Pneumothorax },
	{ class = "weapon_hemopure", want = InternalBleeding },
	-- The only thing in either pack that sets a bone without closing anything.
	{ class = "weapon_splint", cover = true, want = BrokenLimb },
	-- Zagustin is a haemostatic: it does not close anything, it slows down whatever is
	-- open (weapon_zagus.lua:147). Worth a needle while there is still bleeding a wrap
	-- has not caught up with, and behind the kits because stopping a bleed beats slowing
	-- one.
	{
		class = "weapon_zagus",
		want = function(org)
			return (org.bleed or 0) >= BLEED_USE or InternalBleeding(org)
		end,
	},
	{ class = "weapon_adrenaline_injector", want = HeartNeedsStarting },
	-- Propital is adrenaline, mannitol and a dose of analgesia in one needle
	-- (weapon_propital.lua:91), so it answers any of the three - and behind the plain
	-- adrenaline, because spending all three on a man who only needed one of them is a
	-- waste of the better syringe.
	{
		class = "weapon_propital",
		want = function(org)
			return HeartNeedsStarting(org) or BrainSwelling(org) or NeedsPainkillers(org)
		end,
	},
	--//
}

-- Nothing whose only job is analgesia is on that list, from either pack - not Z-City's
-- morphine and not Ibuprofen, Anaglin or the SJ1. A bottle is picked one step earlier than
-- this, by CanSpendPainkillers, and asked the same NeedsPainkillers question there; naming
-- them here as well would be the same decision written down twice in two files' worth of
-- lines apart, and the second copy is the one that goes stale.
--
-- What is on it is everything that answers something a pill does not. Propital has
-- analgesia in it, but it is on the list for the adrenaline and the mannitol.

-- The ones with a function of their own further up, which are also the two an NPC was ever
-- given and the bag a medic packs. These are used whatever the setting says: they are what
-- self-healing has always meant.
local BASIC = {
	[BANDAGE_CLASS] = true,
	[BIG_BANDAGE_CLASS] = true,
	[BLOOD_CLASS] = true,
	[BIG_BLOOD_CLASS] = true,
	[PAINKILLERS_CLASS] = true,
}

-- A pill is a pill. Whichever bottle a pool happened to roll is the one this NPC reaches
-- for when it hurts (CanSpendPainkillers), so all of them count as basic rather than only
-- the one class Z-City ships - otherwise turning the rest of the kit off left a Combine
-- soldier with a morphine needle he would not touch and a body he would not take one off.
for i = 1, #PAINKILLER_CLASSES do BASIC[PAINKILLER_CLASSES[i]] = true end

-- Those plus everything named above, so the sweep at the end of PickItem does not offer the
-- same item a second time under a looser rule than the one it already has.
local SPOKEN_FOR = {}

for class in pairs(BASIC) do SPOKEN_FOR[class] = true end
for i = 1, #ITEMS do SPOKEN_FOR[ITEMS[i].class] = true end

-- And what is not first aid. IsMedicine is deliberately generous about what counts as
-- medicine - it has to be, since it is the list that decides whose Heal gets fixed - and
-- being generous there means naming the exceptions here.
--
-- Food and drink are the obvious half: they run the same shortcut through the same base,
-- which is why they are on that list at all, but a man does not eat his way out of a
-- gunshot wound. The other half is the drugs. Naloxone, beta blockers and thiamine
-- answer states an NPC has no way of getting into - an opioid overdose, a heart running
-- away with itself, a drinker's deficiency - and Fury, fentanyl and pluviska are not
-- treatment for anything. An NPC that goes through its own pockets under fire and comes
-- out with a hit of Fury is a funnier bug than it is a good one.
local NOT_FIRST_AID = {
	weapon_smallconsumable = true,
	weapon_bigconsumable = true,
	weapon_smallconsumable_tpik = true,
	weapon_bigconsumable_tpik = true,
	weapon_naloxone = true,
	weapon_betablock = true,
	weapon_thiamine = true,
	weapon_fentanyl = true,
	weapon_pluviska = true,
	weapon_fury13 = true,
	weapon_fury16 = true,
	-- Draws blood out rather than putting anything in, and a bag of somebody else's is
	-- a player with a needle and a plan (weapon_needle.lua).
	weapon_needle = true,
	-- The bases themselves are not items anybody carries.
	weapon_hg_medicine_base = true,
	weapon_medbase = true,
	-- And the surgical kit is twelve seconds of kneeling with a file of its own to drive
	-- it (sv_cms.lua). Named right this time: this line used to read weapon_bandage_sh_cms,
	-- which is not the name of anything in any addon, so the kit was never actually
	-- excluded - the sweep at the end of PickItem was free to hand it to UseKitItem as
	-- though it were a bigger medkit, and one call to Heal is not what that item is.
	weapon_cms = true,

	--\\ 1nazuma's Enhanced Medicine
	-- eTG-change and Mildronate are regeneration stims, and the way they work is to
	-- spend blood on it: bloodDrainRate comes off org.blood every tick they are running
	-- (weapon_etg.lua:107, weapon_mildronate.lua:108). On a man who is bleeding that is
	-- not treatment, it is the other thing, and a bleeding man is the only kind that ever
	-- reaches into a pocket in this file.
	weapon_etg = true,
	weapon_etg_admin = true,
	weapon_mildronate = true,
	-- Three procedures rather than three items. The field surgical kit and the
	-- defibrillator each run several seconds of their own state off a held button and an
	-- eye trace, checking what they did against what the target started with
	-- (weapon_surv12.lua:653, weapon_defibrillator.lua:461), and the injector case is a
	-- box of other syringes selected by mode. One call to Heal is not any of those. They
	-- are left where a player will find them, which is the same reason the CMS is left
	-- to its own file.
	weapon_surv12 = true,
	weapon_defibrillator = true,
	weapon_injectorcase = true,
	-- Reads an organism out and draws it on a screen. Nothing to spend and nothing to
	-- treat (weapon_medical_pda.lua).
	weapon_medical_pda = true,
	--//
}

-- Whether an NPC would ever take this out of a pocket at all. Asked by the body search,
-- which has no business lifting something off a corpse that nothing here is ever going to
-- press - that is an item taken away from a player for no reason (sv_looting.lua).
function ZCNPC.NpcUsesItem(class)
	if not isstring(class) then return false end
	if NOT_FIRST_AID[class] then return false end
	if BASIC[class] then return true end

	-- With the rest of the kit switched off there is no reason to lift the rest of the kit off
	-- a corpse either. It would be carried around unused and a player would find the body
	-- already emptied of it.
	if cfg.med_items and not cfg.med_items:GetBool() then return false end
	if SPOKEN_FOR[class] then return true end

	return IsMedicine(class)
end

-- Which one comes out, in the order of the list. The first thing it has and wants is the
-- one it uses and there is no second in the same pass: a man who has just put a needle
-- in his arm is not also unrolling a bandage in the same half second.
local function PickItem(npc, org)
	if cfg.med_items and not cfg.med_items:GetBool() then return end

	for i = 1, #ITEMS do
		local item = ITEMS[i]

		if KitHas(npc, item.class) and item.want(org, item.class) then
			return item.class, item.cover == true
		end
	end

	-- Whatever else is in there. A medicine pack from the workshop hangs off the same two
	-- bases as everything above (IsMedicine), and an NPC carrying one of its items is
	-- carrying something that treats something - so it is spent on a man with something
	-- wrong with him and left alone on a man without. NeedsCare is the widest reading of
	-- "there is something wrong with him" in this file, which is the right width for an
	-- item nobody has read.
	if not NeedsCare(org) then return end

	local kit = ZCNPC.EnsureLootKit and ZCNPC.EnsureLootKit(npc)
	if not istable(kit) then return end

	for i = 1, #kit do
		local class = kit[i]

		if not SPOKEN_FOR[class] and not NOT_FIRST_AID[class]
			and IsMedicine(class) and KitHas(npc, class) then
			-- Behind cover, because nobody here knows what it is. An item that turns out
			-- to be a kneel and both hands is one that should have ducked first, and the
			-- cost of ducking for a syringe is a second.
			return class, true
		end
	end
end

-- The item is already in the hand by the time this runs - it is the second half of a
-- use, the half after the draw (StartUse).
local function UseKitItem(npc, state, org)
	local wep = state.wep
	if not IsValid(wep) then return false end

	-- The copy kept out of PatchHeal's reach. That wrapper exists to catch a body on the
	-- floor, and this is an NPC on its feet: it would find no body of ours, hand the call
	-- to the stock shortcut, and we would be back to a lump of engine health and a
	-- deleted medkit.
	--
	-- Looked up through the whole base chain, not on the item's own stored table. Most
	-- items do not write their own Heal - a tourniquet and a medkit share the bandage's,
	-- and the pills in 1nazuma's pack share weapon_medbase's - and asking only the item
	-- came back with nothing, which is this function giving up. An NPC that took a kit
	-- out of its pocket, held it for a fifth of a second and put it away untouched was
	-- this line.
	local heal = Resolve(state.class, "zcnpc_med_healorig") or Resolve(state.class, "Heal")
	if not isfunction(heal) then return false end

	-- The hold meter, filled in one go. Half the family will not treat the man holding it
	-- until this reaches 100, and it climbs four points per call to Heal
	-- (weapon_tourniquet.lua:91) - which is a player leaning on the mouse for a second,
	-- and an NPC waiting for something that is never going to happen. What the meter is
	-- for is the animation of taking your time over it, and the time is the draw above.
	if isfunction(wep.SetHolding) then wep:SetHolding(100) end

	-- Which compartment, on a kit that has several. Set on the item the same way its own
	-- Reload sets it, and passed as the argument as well: the kits branch on self.mode
	-- (weapon_grizzly.lua:146) and weapon_medbase's own Heal branches on the argument
	-- (weapon_medbase.lua:1054), so an item that never wrote a Heal of its own was handed
	-- nil and fell through to the bottom of the function doing nothing.
	--
	-- Left alone when there is nothing to choose - one compartment, or a name this file
	-- does not recognise - because whatever it is set to is what a player last chose and
	-- there is nothing better to guess.
	local mode = KitMode(wep, org) or wep.mode or 1

	wep.mode = mode

	if HealOnce(wep, npc, org, heal, mode) == false then return false end

	SpendMed(npc, state.class)
	ZCNPC.Debug("kit item", npc, state.class)

	return true
end

-- Pills, and it is the item's own Heal that swallows them wherever there is one, for the
-- reason the rest of this section exists: a dose is the item's to say and this file has
-- not read most of these bottles. UsePainkillers is what is left for one whose Heal
-- cannot be reached, which is a bottle out of a pack that put it somewhere unusual.
local function TakePainkillers(npc, state, org)
	local class = state.class

	if Resolve(class, "zcnpc_med_healorig") or Resolve(class, "Heal") then
		return UseKitItem(npc, state, org)
	end

	return UsePainkillers(npc, org, class)
end

-- The one way into any of this from the decisions below. The item comes out, it is held
-- for a moment, and then done() is given the organism as it stands at that point rather
-- than as it stood when the NPC reached for its pocket - it is a short wait, but it is
-- long enough to be shot again in.
local function Draw(npc, class, done, cover)
	return StartUse(npc, class, function(healer, state)
		local org = ZCNPC.ResolveOrganism and ZCNPC.ResolveOrganism(healer) or healer.organism
		if not istable(org) or org.alive == false then return false end

		return done(healer, state, org)
	end, cover)
end
--//

--\\ What the rescue reaches for
-- Dragging somebody out and working on them where it is safe is its own file
-- (sv_rescue.lua), because none of it is a medicine question - but what an item does
-- to an organism is one, and it is answered here for a body on the floor exactly as
-- it is for an NPC on its feet. The spare wraps included: a medic that carries two
-- for its squad is carrying them for this.
ZCNPC.NpcNeedsBandage = NeedsBandage
ZCNPC.NpcCanBandage = CanSpendBandage
ZCNPC.NpcBandage = UseBandage
ZCNPC.NpcCanBlood = CanSpendBlood
ZCNPC.NpcBloodBag = UseBloodBag
ZCNPC.NpcMedicSupplies = EnsureMedicSupplies

-- One side of the same argument this used to be. It asked the relationship table
-- whether a is fond of b, which is a question the table answers wrongly in both
-- directions - by class, before anybody has said anything, and in opposite ways for
-- rebels and for Combine. ZCNPC.SameSide is what it should have been asking and
-- says why at length (sv_core.lua).
--
-- Not self. "Somebody on my side who needs a bandage" is somebody else: a medic
-- treats its own wounds through a different path entirely, and letting it find
-- itself here is a man walking across a room to himself.
local function IsFriendly(a, b)
	if a == b then return false end

	return ZCNPC.SameSide(a, b)
end

-- Asked of the husk rather than of the body, both here and by the rescue: a
-- ragdoll has no place in the AI relationship table and the entity it came off
-- does (sv_uncon.lua).
ZCNPC.NpcFriendly = IsFriendly
--//

--\\ Deciding to use any of it
function ZCNPC.UpdateSelfHeal(npc)
	if not ZCNPC.Enabled() then return end
	if not (IsValid(npc) and npc:IsNPC()) then return end
	if IsValid(npc.zcnpc_rag) then return end
	if ZCNPC.IsZombie and ZCNPC.IsZombie(npc) then return end
	if (ZCNPC.GettingUp[npc] or 0) > CurTime() then return end
	if npc:GetNetVar("handcuffed", false) then return end
	if ZCNPC.HasHeadcrab and ZCNPC.HasHeadcrab(npc) then return end
	if (npc.zcnpc_selfheal_cd or 0) > CurTime() then return end

	-- Do not drop the gun mid-fetch / mid-fight animation for a bandage.
	if IsValid(npc.zcnpc_fetch) or IsValid(npc.zcnpc_fetcharmor) then return end
	if istable(npc.zcnpc_rescue) then return end

	if not (cfg.selfheal and cfg.selfheal:GetBool()) then return end

	local org = ZCNPC.ResolveOrganism and ZCNPC.ResolveOrganism(npc) or npc.organism
	if not org or org.alive == false or org.otrub then return end

	-- Do not force a kit roll here. EnsureLootKit from KitHas is enough, and an
	-- eager roll before Nazuma's pool is mounted used to freeze NativeLoot
	-- (bandage / painkillers) for that NPC's whole life.
	EnsureMedicSupplies(npc)

	-- Already got something out of its pocket. The wait is a fifth of a second and the
	-- pass comes round every half, so this is only ever the pass that lands in the middle
	-- of one - and the item that is already out is the item it decided on.
	if istable(npc.zcnpc_meduse) then return end

	local used = false

	-- Pills first and without cover - swallowed on the move. Everything after this
	-- refuses to start while something is already out, so the order of these is the
	-- order they happen in over several passes rather than all at once.
	if NeedsPainkillers(org) then
		local class = CanSpendPainkillers(npc)

		if class then
			used = Draw(npc, class, TakePainkillers) or used
		end
	end

	-- Then the rest of the kit, which is where a medkit or a tourniquet gets reached
	-- for. Ahead of the plain wrap on purpose: both of them close things a wrap cannot
	-- and the medkit is the better dressing besides, so an NPC holding one should not
	-- be spending gauze first and finding out afterwards.
	if not used then
		local class, cover = PickItem(npc, org)

		if class and cover and not SafeToBandage(npc) then
			SeekCover(npc)

			return
		end

		if class then
			used = Draw(npc, class, UseKitItem, cover) or used
		end
	end

	-- A wrap does not close an artery or an internal bleed. Spending the last
	-- bandage on those and then starting again the next pass is the healing loop:
	-- they kneel, the wound keeps pumping, they kneel again.
	if not used and NeedsBandage(org) and not npc.zcnpc_heal_skip_wrap
		and not ArterialBleeding(org) and not InternalBleeding(org) then
		local class = CanSpendBandage(npc)

		if class then
			if SafeToBandage(npc) then
				used = Draw(npc, class, function(healer, _, current)
					local ok = UseBandage(healer, healer, current)

					if ArterialBleeding(current) or InternalBleeding(current) then
						healer.zcnpc_heal_skip_wrap = true
					end

					return ok
				end, true) or used
			else
				SeekCover(npc)

				return
			end
		end
	end

	if used then
		npc.zcnpc_selfheal_cd = CurTime() + HEAL_COOLDOWN
	elseif ArterialBleeding(org) or InternalBleeding(org) then
		-- Nothing in the kit answers this. Trying again every half second is the
		-- other half of the loop: the animation starts, bleed continues, it starts
		-- again. Sit with it until a better item turns up.
		npc.zcnpc_selfheal_cd = CurTime() + HEAL_COOLDOWN * 2
	end
end

-- While the item is in the hand the wound is not allowed to win the race.
-- Otherwise a bandage that takes a second to come out is undone by the bleed
-- that was the reason it came out, and the NPC never leaves the kneel.
hook.Add("Org Think", "zcnpc_healhold", function(owner, org)
	if not (IsValid(owner) and org and istable(owner.zcnpc_meduse)) then return end

	org.zcnpc_heal_blood = org.zcnpc_heal_blood or org.blood or 0
	org.blood = math.max(org.blood or 0, org.zcnpc_heal_blood)
	org.bleed = 0
end)

hook.Add("ZCNPC_Downed", "zcnpc_healhold", function(npc)
	if IsValid(npc) then npc.zcnpc_heal_skip_wrap = nil end
end)
--//
