HG_PHONE = HG_PHONE or {}

HG_PHONE.MODEL_HANDHELD = "models/saraphines/insurgency explosives/ied/insurgency_ied_phone.mdl"
HG_PHONE.DEFAULT_DESK_MODEL = "models/props/cs_office/phone.mdl"

HG_PHONE.STATE_IDLE = 0
HG_PHONE.STATE_CALLING = 1
HG_PHONE.STATE_RINGING = 2
HG_PHONE.STATE_IN_CALL = 3

HG_PHONE.RINGTONES = {
	{name = "Classic", path = "michaelphone.mp3"},
	{name = "Digital", path = "glide/ui/phone_notify.wav"},
	{name = "Button", path = "buttons/button14.wav"},
	{name = "Alarm", path = "ambient/alarms/alarm1.wav"},
	{name = "Bell", path = "ambient/alarms/warningbell1.wav"}
}

HG_PHONE.MAP_PHONE_MODELS = {
	["models/props/cs_office/phone.mdl"] = true,
	["models/props_lab/deskphone01.mdl"] = true,
	["models/props_interiors/phone_motel.mdl"] = true,
	["models/props_unique/airport/phone.mdl"] = true,
	["models/props_unique/airport/phone_wall.mdl"] = true
}

function HG_PHONE.IsMapPhoneModel(model)
	model = string.lower(model or "")
	if model == "" or model == string.lower(HG_PHONE.MODEL_HANDHELD) or string.find(model, "headphone", 1, true) then return false end
	if HG_PHONE.MAP_PHONE_MODELS[model] then return true end

	local fileName = string.GetFileFromFilename(model)
	return string.find(fileName, "phone", 1, true) ~= nil
		or string.find(fileName, "telephone", 1, true) ~= nil
		or string.find(fileName, "cellphone", 1, true) ~= nil
end

function HG_PHONE.IsNormalPhone(ent)
	if not IsValid(ent) then return false end
	local class = ent:GetClass()
	return class == "ent_phone" or class == "weapon_phone"
end

function HG_PHONE.IsIEDPhone(ent)
	return IsValid(ent)
		and ent:GetClass() == "weapon_traitor_ied"
		and ent.GetPhoneMode
		and ent:GetPhoneMode()
		and ent.GetPlanted
		and ent:GetPlanted()
end

function HG_PHONE.IsPhone(ent)
	return HG_PHONE.IsNormalPhone(ent) or HG_PHONE.IsIEDPhone(ent)
end

function HG_PHONE.GetNumber(ent)
	return IsValid(ent) and ent:GetNW2String("HGPhoneNumber", "") or ""
end

function HG_PHONE.GetDisplayName(ent)
	return IsValid(ent) and ent:GetNW2String("HGPhoneName", "Phone") or "Phone"
end

function HG_PHONE.GetRingtone(ent)
	return IsValid(ent) and ent:GetNW2String("HGPhoneRingtone", HG_PHONE.RINGTONES[1].path) or HG_PHONE.RINGTONES[1].path
end

function HG_PHONE.GetState(ent)
	return IsValid(ent) and ent:GetNW2Int("HGPhoneState", HG_PHONE.STATE_IDLE) or HG_PHONE.STATE_IDLE
end

function HG_PHONE.GetStateName(state)
	if state == HG_PHONE.STATE_CALLING then return "CALLING" end
	if state == HG_PHONE.STATE_RINGING then return "RINGING" end
	if state == HG_PHONE.STATE_IN_CALL then return "IN CALL" end
	return "IDLE"
end

-- Compatibility methods for the ancient phone UI/API and outside addons.
local ENTITY = FindMetaTable("Entity")
if ENTITY then
	if not ENTITY.GetPhoneNumber then function ENTITY:GetPhoneNumber() return HG_PHONE.GetNumber(self) end end
	if not ENTITY.GetDisplayName then function ENTITY:GetDisplayName() return HG_PHONE.GetDisplayName(self) end end
	if not ENTITY.GetPhoneState then function ENTITY:GetPhoneState() return HG_PHONE.GetState(self) end end
	if not ENTITY.GetRingtonePath then function ENTITY:GetRingtonePath() return HG_PHONE.GetRingtone(self) end end
end
