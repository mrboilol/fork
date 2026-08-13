if CLIENT then return end

local hg_iedphones = ConVarExists("hg_iedphones") and GetConVar("hg_iedphones") or CreateConVar(
	"hg_iedphones",
	"1",
	FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED,
	"Give planted IEDs a linked full-service phone controller.",
	0,
	1
)

local netNames = {
	"HG_Phone_OpenUI",
	"HG_Phone_RequestOpen",
	"HG_Phone_Registry",
	"HG_Phone_RequestCall",
	"HG_Phone_AnswerCall",
	"HG_Phone_HangupCall",
	"HG_Phone_Text",
	"HG_Phone_SetRingtone",
	"HG_Phone_SetDisplayName",
	"HG_Phone_SetPublic",
	"HG_Phone_Pickup",
	"HG_Phone_PlaceDown",
	"HG_Phone_Notification"
}

for _, name in ipairs(netNames) do util.AddNetworkString(name) end

HG_PHONE_SERVER = HG_PHONE_SERVER or {}
local PHONE = HG_PHONE_SERVER
PHONE.Registry = PHONE.Registry or {}
PHONE.ActiveUsers = PHONE.ActiveUsers or {}
PHONE.CallSound = "rem_iedcall.mp3"
PHONE.AnswerSound = "panoptisscon/phone_answer.mp3"
PHONE.MaxCallTravelTime = 10
PHONE.CallTravelDistance = 3000
local function CapturePhoneAppearance(ent)
	local color = ent:GetColor()
	local appearance = {
		model = ent:GetModel(),
		skin = ent:GetSkin(),
		material = ent:GetMaterial(),
		color = {r = color.r, g = color.g, b = color.b, a = color.a},
		scale = ent:GetModelScale(),
		renderMode = ent:GetRenderMode(),
		renderFX = ent:GetRenderFX(),
		bodygroups = {},
		submaterials = {}
	}

	for id = 0, ent:GetNumBodyGroups() - 1 do
		appearance.bodygroups[#appearance.bodygroups + 1] = {id = id, value = ent:GetBodygroup(id)}
	end

	for id = 0, #ent:GetMaterials() - 1 do
		local material = ent:GetSubMaterial(id)
		if material and material ~= "" then
			appearance.submaterials[#appearance.submaterials + 1] = {id = id, value = material}
		end
	end

	return appearance
end

local function ApplyPhoneAppearance(ent, appearance)
	if not IsValid(ent) or not istable(appearance) then return end

	ent:SetSkin(tonumber(appearance.skin) or 0)
	ent:SetMaterial(tostring(appearance.material or ""))
	local color = appearance.color or {}
	ent:SetColor(Color(
		math.Clamp(tonumber(color.r) or 255, 0, 255),
		math.Clamp(tonumber(color.g) or 255, 0, 255),
		math.Clamp(tonumber(color.b) or 255, 0, 255),
		math.Clamp(tonumber(color.a) or 255, 0, 255)
	))
	ent:SetModelScale(tonumber(appearance.scale) or 1, 0)
	ent:SetRenderMode(tonumber(appearance.renderMode) or RENDERMODE_NORMAL)
	ent:SetRenderFX(tonumber(appearance.renderFX) or 0)

	for _, bodygroup in ipairs(appearance.bodygroups or {}) do
		ent:SetBodygroup(tonumber(bodygroup.id) or 0, tonumber(bodygroup.value) or 0)
	end
	for _, submaterial in ipairs(appearance.submaterials or {}) do
		ent:SetSubMaterial(tonumber(submaterial.id) or 0, tostring(submaterial.value or ""))
	end
end

PHONE.ActivePhoneByPlayer = PHONE.ActivePhoneByPlayer or {}

local function Notify(ply, message)
	if not IsValid(ply) then return end
	net.Start("HG_Phone_Notification")
		net.WriteString(message)
	net.Send(ply)
end

function PHONE:GetUser(phone)
	if not IsValid(phone) then return nil end
	if phone:IsWeapon() and IsValid(phone:GetOwner()) and phone:GetOwner():IsPlayer() then return phone:GetOwner() end
	return IsValid(self.ActiveUsers[phone]) and self.ActiveUsers[phone] or nil
end

function PHONE:CanControl(ply, phone)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not HG_PHONE.IsPhone(phone) then return false end
	if phone:IsWeapon() then return phone:GetOwner() == ply end
	return ply:GetPos():DistToSqr(phone:GetPos()) <= 180 * 180
end

function PHONE:GenerateNumber()
	for _ = 1, 1000 do
		local number = tostring(math.random(100000, 999999))
		if not IsValid(self.Registry[number]) then return number end
	end
	return tostring(math.floor(SysTime() * 1000) % 900000 + 100000)
end

function PHONE:QueueRegistrySync(target)
	if IsValid(target) then
		timer.Simple(0, function()
			if IsValid(target) then PHONE:SyncRegistry(target) end
		end)
		return
	end

	if self.RegistrySyncQueued then return end
	self.RegistrySyncQueued = true
	timer.Simple(0.1, function()
		PHONE.RegistrySyncQueued = false
		PHONE:SyncRegistry()
	end)
end

function PHONE:SyncRegistry(target)
	local entries = {}
	for number, phone in pairs(self.Registry) do
		if not HG_PHONE.IsPhone(phone) or HG_PHONE.GetNumber(phone) ~= number then
			self.Registry[number] = nil
		elseif HG_PHONE.IsPublic(phone) or (IsValid(target) and PHONE:CanControl(target, phone)) then
			-- Private numbers remain registered so they can still be dialed manually.
			-- They are simply omitted from registries sent to other players.
			entries[#entries + 1] = {number = number, phone = phone}
		end
	end

	table.sort(entries, function(a, b) return a.number < b.number end)
	net.Start("HG_Phone_Registry")
		net.WriteUInt(#entries, 12)
		for _, entry in ipairs(entries) do
			net.WriteString(entry.number)
			net.WriteEntity(entry.phone)
		end
	if IsValid(target) then net.Send(target) else net.Broadcast() end
end

function PHONE:SetIdentity(phone, number, displayName, ringtone)
	if not IsValid(phone) then return false end

	local oldNumber = HG_PHONE.GetNumber(phone)
	if oldNumber ~= "" and self.Registry[oldNumber] == phone then self.Registry[oldNumber] = nil end

	-- Re-registration can omit the number; retain the assigned private number.
	-- This also keeps planted IED controller numbers stable.
	number = tostring(number or oldNumber or "")
	if number == "" or (IsValid(self.Registry[number]) and self.Registry[number] ~= phone) then number = self:GenerateNumber() end
	displayName = string.Trim(tostring(displayName or ""))
	if displayName == "" then displayName = "Phone " .. number end
	displayName = string.sub(displayName, 1, 32)
	ringtone = tostring(ringtone or HG_PHONE.RINGTONES[1].path)
	if not HG_PHONE.RINGTONE_PATHS[ringtone] then ringtone = HG_PHONE.RINGTONES[1].path end

	phone:SetNW2String("HGPhoneNumber", number)
	phone:SetNW2String("HGPhoneName", displayName)
	phone:SetNW2String("HGPhoneRingtone", ringtone)
	if phone:GetNW2Bool("HGPhonePublicInitialized", false) == false then
		phone:SetNW2Bool("HGPhonePublic", phone:GetNW2Bool("HGMapPhone", false))
		phone:SetNW2Bool("HGPhonePublicInitialized", true)
	end
	self.Registry[number] = phone
	self:QueueRegistrySync()
	return true
end

function PHONE:RegisterPhone(phone, number, displayName, ringtone)
	if not HG_PHONE.IsPhone(phone) then return false end
	local currentNumber = HG_PHONE.GetNumber(phone)
	if currentNumber ~= "" and self.Registry[currentNumber] == phone then return true end
	-- An IED must be private before its generated number reaches any registry sync.
	-- Its number stays registered so a player who knows it can still dial it.
	if HG_PHONE.IsIEDPhone(phone) then
		phone:SetNW2Bool("HGPhonePublic", false)
		phone:SetNW2Bool("HGPhonePublicInitialized", true)
	end

	if not displayName then
		local owner = phone:IsWeapon() and phone:GetOwner() or nil
		if HG_PHONE.IsIEDPhone(phone) then
			local names = HG_PHONE.IED_HANDHELD_NAMES or {}
			displayName = #names > 0 and table.Random(names) or "Handheld"
		elseif IsValid(owner) and owner:IsPlayer() then
			displayName = owner:Nick() .. "'s Phone"
		elseif phone:GetNW2Bool("HGMapPhone", false) then
			displayName = phone:GetName() ~= "" and phone:GetName() or "Map Phone"
		end
	end

	phone:SetNW2Int("HGPhoneState", HG_PHONE.STATE_IDLE)
	phone:SetNW2Entity("HGPhoneTarget", NULL)
	return self:SetIdentity(phone, number, displayName, ringtone)
end

local function StopRingtone(phone)
	if not IsValid(phone) then return end
	phone:StopSound(HG_PHONE.GetRingtone(phone))
	local user = PHONE:GetUser(phone)
	if IsValid(user) and user ~= phone then user:StopSound(HG_PHONE.GetRingtone(phone)) end
end

function PHONE:EndCall(phone, reason)
	if not IsValid(phone) then return end
	local target = phone:GetNW2Entity("HGPhoneTarget")
	local firstUser = self:GetUser(phone)
	local secondUser = self:GetUser(target)

	for _, item in ipairs({phone, target}) do
		if IsValid(item) then
			StopRingtone(item)
			item:SetNW2Int("HGPhoneState", HG_PHONE.STATE_IDLE)
			item:SetNW2Entity("HGPhoneTarget", NULL)
			item._HGPhoneRingAt = nil
			item._HGPhoneRingExpires = nil
		end
	end

	if IsValid(firstUser) and self.ActivePhoneByPlayer[firstUser] == phone then self.ActivePhoneByPlayer[firstUser] = nil end
	if IsValid(secondUser) and self.ActivePhoneByPlayer[secondUser] == target then self.ActivePhoneByPlayer[secondUser] = nil end
	self.ActiveUsers[phone] = nil
	self.ActiveUsers[target] = nil

	if reason then
		Notify(firstUser, reason)
		if secondUser ~= firstUser then Notify(secondUser, reason) end
	end
end

function PHONE:EmitPhoneSound(phone, path)
	if not IsValid(phone) then return end
	local user = self:GetUser(phone)
	local emitter = IsValid(user) and user or phone
	emitter:EmitSound(path, 60, 100, 0.75, CHAN_ITEM)
end

function PHONE:GetCallPosition(phone)
	local user = self:GetUser(phone)
	return IsValid(user) and user:GetPos() or phone:GetPos()
end

function PHONE:GetCallTravelTime(source, target)
	local distance = self:GetCallPosition(source):Distance(self:GetCallPosition(target))
	return math.Clamp(distance / self.CallTravelDistance * self.MaxCallTravelTime, 0, self.MaxCallTravelTime)
end

function PHONE:UnregisterPhone(phone, transferring)
	if not IsValid(phone) then return end
	if not transferring and HG_PHONE.GetState(phone) ~= HG_PHONE.STATE_IDLE then self:EndCall(phone, "Call ended.") end
	local number = HG_PHONE.GetNumber(phone)
	if number ~= "" and self.Registry[number] == phone then self.Registry[number] = nil end
	self.ActiveUsers[phone] = nil
	phone:SetNW2String("HGPhoneNumber", "")
	self:QueueRegistrySync()
end

function PHONE:OpenPhone(ply, phone)
	if not self:CanControl(ply, phone) then
		Notify(ply, "You cannot use that phone.")
		return false
	end

	self:RegisterPhone(phone)
	net.Start("HG_Phone_OpenUI")
		net.WriteEntity(phone)
	net.Send(ply)
	self:SyncRegistry(ply)
	return true
end

function PHONE.OpenIEDPhone(ply, phone)
	return PHONE:OpenPhone(ply, phone)
end

function PHONE:UpdateIEDPhone(phone, enabled)
	if not IsValid(phone) then return end
	if enabled and HG_PHONE.IsIEDPhone(phone) then
		self:RegisterPhone(phone)
	elseif HG_PHONE.GetNumber(phone) ~= "" then
		self:UnregisterPhone(phone)
	end
end

local function EmitRingtone(phone)
	if not IsValid(phone) then return end
	-- EmitSound starts another instance every time. Clear the previous ring before
	-- the call manager schedules the next one so long ringtone files cannot stack.
	StopRingtone(phone)
	local emitter = PHONE:GetUser(phone)
	if not IsValid(emitter) then emitter = phone end
	emitter:EmitSound(HG_PHONE.GetRingtone(phone), 68, 100, 0.9, CHAN_AUTO)
end

local function StartCall(ply, source, targetNumber)
	if not PHONE:CanControl(ply, source) then return Notify(ply, "You cannot use that phone.") end
	if HG_PHONE.GetState(source) ~= HG_PHONE.STATE_IDLE then return Notify(ply, "This phone is already busy.") end
	if IsValid(PHONE.ActivePhoneByPlayer[ply]) then return Notify(ply, "You are already in another call.") end

	local target = PHONE.Registry[tostring(targetNumber or "")]
	if not HG_PHONE.IsPhone(target) or target == source then return Notify(ply, "That number is unavailable.") end
	-- IEDs do not answer calls: dialing their assigned number is the trigger.
	if HG_PHONE.IsIEDPhone(target) then
		if target:GetDestroyed() or target:GetDialing() or target:GetDetonating() then return Notify(ply, "That IED is unavailable.") end
		if target.PhoneDetonate and target:PhoneDetonate() then
			PHONE:EmitPhoneSound(source, PHONE.CallSound)
			return Notify(ply, "Dialing " .. HG_PHONE.GetNumber(target) .. "...")
		end
		return Notify(ply, "That IED is unavailable.")
	end
	if HG_PHONE.GetState(target) ~= HG_PHONE.STATE_IDLE then return Notify(ply, "That number is busy.") end
	local targetUser = PHONE:GetUser(target)
	if targetUser == ply then return Notify(ply, "You cannot call another phone you are carrying.") end
	if IsValid(targetUser) and IsValid(PHONE.ActivePhoneByPlayer[targetUser]) then return Notify(ply, "That number is busy.") end

	PHONE.ActiveUsers[source] = ply
	source:SetNW2Entity("HGPhoneTarget", target)
	target:SetNW2Entity("HGPhoneTarget", source)
	source:SetNW2Int("HGPhoneState", HG_PHONE.STATE_CALLING)
	target:SetNW2Int("HGPhoneState", HG_PHONE.STATE_CONNECTING)
	target._HGPhoneCallArrival = CurTime() + PHONE:GetCallTravelTime(source, target)
	PHONE:EmitPhoneSound(source, PHONE.CallSound)
	-- The receiver is notified only when the call has travelled to their phone.
	Notify(ply, "Calling " .. HG_PHONE.GetDisplayName(target) .. "...")

end

net.Receive("HG_Phone_RequestOpen", function(_, ply)
	PHONE:OpenPhone(ply, net.ReadEntity())
end)

net.Receive("HG_Phone_RequestCall", function(_, ply)
	StartCall(ply, net.ReadEntity(), string.sub(net.ReadString(), 1, 16))
end)

net.Receive("HG_Phone_AnswerCall", function(_, ply)
	local phone = net.ReadEntity()
	if not PHONE:CanControl(ply, phone) or HG_PHONE.GetState(phone) ~= HG_PHONE.STATE_RINGING then return end
	if IsValid(PHONE.ActivePhoneByPlayer[ply]) then return Notify(ply, "You are already in another call.") end

	local caller = phone:GetNW2Entity("HGPhoneTarget")
	if not HG_PHONE.IsPhone(caller) or HG_PHONE.GetState(caller) ~= HG_PHONE.STATE_CALLING then return PHONE:EndCall(phone, "The caller hung up.") end

	PHONE.ActiveUsers[phone] = ply
	local callerUser = PHONE:GetUser(caller)
	phone:SetNW2Int("HGPhoneState", HG_PHONE.STATE_IN_CALL)
	caller:SetNW2Int("HGPhoneState", HG_PHONE.STATE_IN_CALL)
	StopRingtone(phone)
	PHONE.ActivePhoneByPlayer[ply] = phone
	if IsValid(callerUser) then PHONE.ActivePhoneByPlayer[callerUser] = caller end
	Notify(ply, "Call connected.")
	Notify(callerUser, "Call connected.")
end)

net.Receive("HG_Phone_HangupCall", function(_, ply)
	local phone = net.ReadEntity()
	if PHONE:CanControl(ply, phone) then
		PHONE:EmitPhoneSound(phone, "panoptisscon/phone_hangup.mp3")
		PHONE:EndCall(phone, "Call ended.")
	end
end)

net.Receive("HG_Phone_Text", function(_, ply)
	local phone = net.ReadEntity()
	local targetNumber = string.sub(net.ReadString(), 1, 16)
	local message = string.Trim(string.sub(net.ReadString(), 1, 256))
	if message == "" or not PHONE:CanControl(ply, phone) then return end

	local target = PHONE.Registry[targetNumber]
	if not HG_PHONE.IsNormalPhone(target) or target == phone then return Notify(ply, "That number cannot receive texts.") end
	local targetUser = PHONE:GetUser(target)
	if not IsValid(targetUser) or not targetUser:Alive() then return Notify(ply, "That number cannot receive texts right now.") end

	for _, recipient in ipairs({ply, targetUser}) do
		net.Start("HG_Phone_Text")
			net.WriteString(ply:Nick())
			net.WriteString(HG_PHONE.GetNumber(phone))
			net.WriteString(message)
		net.Send(recipient)
	end
end)

net.Receive("HG_Phone_SetRingtone", function(_, ply)
	local phone = net.ReadEntity()
	local index = net.ReadUInt(8)
	if not PHONE:CanControl(ply, phone) or not HG_PHONE.RINGTONES[index] then return end
	phone:SetNW2String("HGPhoneRingtone", HG_PHONE.RINGTONES[index].path)
	Notify(ply, "Ringtone set to " .. HG_PHONE.RINGTONES[index].name .. ".")
end)

net.Receive("HG_Phone_SetDisplayName", function(_, ply)
	local phone = net.ReadEntity()
	local name = string.Trim(string.sub(net.ReadString(), 1, 32))
	if name == "" or not PHONE:CanControl(ply, phone) then return end
	phone:SetNW2String("HGPhoneName", name)
	PHONE:QueueRegistrySync()
	Notify(ply, "Phone name updated.")
end)

net.Receive("HG_Phone_SetPublic", function(_, ply)
	local phone = net.ReadEntity()
	if not PHONE:CanControl(ply, phone) then return end
	phone:SetNW2Bool("HGPhonePublic", net.ReadBool())
	PHONE:QueueRegistrySync()
	Notify(ply, HG_PHONE.IsPublic(phone) and "Phone number is public." or "Phone number is private.")
end)

net.Receive("HG_Phone_Pickup", function(_, ply)
	local phone = net.ReadEntity()
	if not PHONE:CanControl(ply, phone) or phone:GetClass() ~= "ent_phone" then return end
	if HG_PHONE.GetState(phone) ~= HG_PHONE.STATE_IDLE then return Notify(ply, "Hang up before picking up this phone.") end
	if ply:HasWeapon("weapon_phone") then return Notify(ply, "You already have a handheld phone.") end

	local number, displayName, ringtone = HG_PHONE.GetNumber(phone), HG_PHONE.GetDisplayName(phone), HG_PHONE.GetRingtone(phone)
	local isDeskPhone = not phone:GetPortableModel()
	local appearanceJSON = isDeskPhone and util.TableToJSON(CapturePhoneAppearance(phone)) or ""
	PHONE:UnregisterPhone(phone, true)
	local weapon = ply:Give("weapon_phone")
	if not IsValid(weapon) then
		PHONE:RegisterPhone(phone, number, displayName, ringtone)
		return Notify(ply, "The phone could not be picked up.")
	end

	weapon:SetNW2Bool("HGDeskPhoneCarry", isDeskPhone and appearanceJSON ~= "")
	weapon:SetNW2String("HGPhoneDeskAppearance", appearanceJSON or "")
	PHONE:SetIdentity(weapon, number, displayName, ringtone)
	phone:Remove()
	ply:SelectWeapon("weapon_phone")
end)

net.Receive("HG_Phone_PlaceDown", function(_, ply)
	local weapon = net.ReadEntity()
	if not PHONE:CanControl(ply, weapon) or weapon:GetClass() ~= "weapon_phone" then return end
	if not weapon:GetNW2Bool("HGDeskPhoneCarry", false) then return Notify(ply, "Handheld phones cannot be placed down.") end
	if HG_PHONE.GetState(weapon) ~= HG_PHONE.STATE_IDLE then return Notify(ply, "Hang up before placing this phone.") end

	local tr = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * 90, filter = ply})
	if not tr.Hit or tr.HitSky then return Notify(ply, "Aim at a nearby surface.") end
	local number, displayName, ringtone = HG_PHONE.GetNumber(weapon), HG_PHONE.GetDisplayName(weapon), HG_PHONE.GetRingtone(weapon)
	local appearance = util.JSONToTable(weapon:GetNW2String("HGPhoneDeskAppearance", ""))
	if not istable(appearance) or not util.IsValidModel(appearance.model or "") then
		return Notify(ply, "This desk phone has no valid saved appearance.")
	end
	local phone = ents.Create("ent_phone")
	if not IsValid(phone) then return end
	phone.PhoneModelOverride = appearance.model
	phone:SetPos(tr.HitPos + tr.HitNormal * 3)
	phone:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
	phone:Spawn()
	phone:Activate()
	ApplyPhoneAppearance(phone, appearance)
	PHONE:UnregisterPhone(weapon, true)
	PHONE:SetIdentity(phone, number, displayName, ringtone)
	weapon:Remove()
end)


function PHONE:CanHearVoiceCall(listener, speaker)
	local source = PHONE.ActivePhoneByPlayer[speaker]
	if not HG_PHONE.IsPhone(source) or HG_PHONE.GetState(source) ~= HG_PHONE.STATE_IN_CALL then return end
	local target = source:GetNW2Entity("HGPhoneTarget")
	if PHONE:GetUser(target) ~= listener then return end
	if not speaker:Alive() or not listener:Alive() then return false, false end
	if speaker.organism and (speaker.organism.otrub or speaker.organism.holdingbreath or speaker.organism.o2[1] < 15 or speaker.organism.brain > 0.05) then return false, false end
	if listener.organism and (listener.organism.otrub or listener.organism.o2[1] < 15) then return false, false end
	return true, false
end

hook.Add("HG_PlayerCanHearPlayersVoice", "HG_Phone_VoiceCall", function(listener, speaker)
	return PHONE:CanHearVoiceCall(listener, speaker)
end)

hook.Add("Think", "HG_Phone_CallManager", function()
	local now = CurTime()
	for _, phone in pairs(PHONE.Registry) do
		if not HG_PHONE.IsPhone(phone) then continue end
		local state = HG_PHONE.GetState(phone)
		if state == HG_PHONE.STATE_RINGING then
			if (phone._HGPhoneRingExpires or 0) <= now then
				PHONE:EndCall(phone, "No answer.")
			elseif (phone._HGPhoneRingAt or 0) <= now then
				EmitRingtone(phone)
				local duration = SoundDuration(HG_PHONE.GetRingtone(phone))
				-- Schedule the next ring from this playback, so it begins only after
				-- the previous ringtone has ended instead of on a fixed interval.
				phone._HGPhoneRingAt = CurTime() + (duration > 0 and duration or 2.5)
			end
		elseif state == HG_PHONE.STATE_CONNECTING then
			if (phone._HGPhoneCallArrival or 0) <= now then
				local caller = phone:GetNW2Entity("HGPhoneTarget")
				if not HG_PHONE.IsPhone(caller) or HG_PHONE.GetState(caller) ~= HG_PHONE.STATE_CALLING then
					PHONE:EndCall(phone, "The caller hung up.")
				else
					phone:SetNW2Int("HGPhoneState", HG_PHONE.STATE_RINGING)
					phone._HGPhoneCallArrival = nil
					phone._HGPhoneRingAt = CurTime()
					phone._HGPhoneRingExpires = now + 30
					PHONE:EmitPhoneSound(phone, PHONE.AnswerSound)
					local targetUser = PHONE:GetUser(phone)
					if IsValid(targetUser) then Notify(targetUser, "Incoming call from " .. HG_PHONE.GetNumber(caller) .. ".") end
				end
			end
		elseif state == HG_PHONE.STATE_CALLING or state == HG_PHONE.STATE_IN_CALL then
			local user = PHONE:GetUser(phone)
			if not IsValid(user) or not user:Alive() or (not phone:IsWeapon() and user:GetPos():DistToSqr(phone:GetPos()) > 240 * 240) then
				PHONE:EndCall(phone, "Call ended.")
			end
		end
	end
end)

hook.Add("EntityRemoved", "HG_Phone_Unregister", function(ent)
	for number, phone in pairs(PHONE.Registry) do
		if phone == ent then
			PHONE.Registry[number] = nil
			PHONE:QueueRegistrySync()
			break
		end
	end
end)

hook.Add("PlayerDisconnected", "HG_Phone_PlayerLeft", function(ply)
	local phone = PHONE.ActivePhoneByPlayer[ply]
	if IsValid(phone) then PHONE:EndCall(phone, "Call ended.") end
end)

local replaceClasses = {
	prop_physics = true,
	prop_physics_multiplayer = true,
	prop_physics_override = true,
	prop_dynamic = true,
	prop_dynamic_override = true
}
local function ReplacePhoneProp(ent)
	if not IsValid(ent) or ent._HGPhoneReplacing or not replaceClasses[ent:GetClass()] or not HG_PHONE.IsMapPhoneModel(ent:GetModel()) then return end
	ent._HGPhoneReplacing = true

	local model, pos, ang = ent:GetModel(), ent:GetPos(), ent:GetAngles()
	local skin, color, material, scale = ent:GetSkin(), ent:GetColor(), ent:GetMaterial(), ent:GetModelScale()
	local noDraw, renderMode, renderFX, collisionGroup = ent:GetNoDraw(), ent:GetRenderMode(), ent:GetRenderFX(), ent:GetCollisionGroup()
	local name, parent = ent:GetName(), ent:GetParent()
	local localPos, localAng = ent:GetLocalPos(), ent:GetLocalAngles()
	local bodygroups = {}
	for i = 0, ent:GetNumBodyGroups() - 1 do bodygroups[i] = ent:GetBodygroup(i) end
	local submaterials = {}
	for i = 0, #ent:GetMaterials() - 1 do
		local submaterial = ent:GetSubMaterial(i)
		if submaterial and submaterial ~= "" then submaterials[i] = submaterial end
	end
	local oldPhys = ent:GetPhysicsObject()
	local motionEnabled = IsValid(oldPhys) and oldPhys:IsMotionEnabled() or false

	local phone = ents.Create("ent_phone")
	if not IsValid(phone) then return end
	phone.PhoneModelOverride = model
	phone:SetPos(pos)
	phone:SetAngles(ang)
	phone:Spawn()
	phone:Activate()
	phone:SetSkin(skin)
	phone:SetColor(color)
	phone:SetMaterial(material)
	phone:SetModelScale(scale, 0)
	phone:SetNoDraw(noDraw)
	phone:SetRenderMode(renderMode)
	phone:SetRenderFX(renderFX)
	phone:SetCollisionGroup(collisionGroup)
	phone:SetNW2Bool("HGMapPhone", true)
	if name ~= "" then phone:SetName(name) end
	for id, value in pairs(bodygroups) do phone:SetBodygroup(id, value) end
	for id, value in pairs(submaterials) do phone:SetSubMaterial(id, value) end
	if IsValid(parent) then
		phone:SetParent(parent)
		phone:SetLocalPos(localPos)
		phone:SetLocalAngles(localAng)
	end
	local newPhys = phone:GetPhysicsObject()
	if IsValid(newPhys) and not motionEnabled then newPhys:EnableMotion(false) end
	PHONE:SetIdentity(phone, nil, name ~= "" and name or "Map Phone", nil)
	ent:Remove()
end

hook.Add("InitPostEntity", "HG_Phone_ReplaceMapProps", function()
	timer.Simple(0, function()
		for _, ent in ipairs(ents.GetAll()) do ReplacePhoneProp(ent) end
	end)
end)

hook.Add("OnEntityCreated", "HG_Phone_ReplaceSpawnedProps", function(ent)
	timer.Simple(0, function() ReplacePhoneProp(ent) end)
end)
