local math_Clamp = math.Clamp

local MEMORY_TIME = 180
local MEMORY_FADE_START = 0.6
local MEMORY_MIN_ALPHA = 0.35
local OBSERVE_INTERVAL = 0.25
local OBSERVE_MAX_DIST = 1800
local VIEW_DOT = 0.7
local LOS_INTERVAL = 0.2
local LOS_MIN_FRACTION = 0.97

local ZOOM_DIST = 6000
local ZOOM_RADIUS = 0.2
local ITEM_LIMIT = 64
local ITEM_NAME_LIMIT = 8
local ITEM_REFRESH = 0.5
local VIGNETTE_ALPHA = 215
local VIGNETTE_SPEED = 6
local VIGNETTE_BANDS = 32

local CUE_MAX = 6
local CUE_STEP = 22
local NAME_OFFSET = 30
local OUTLINE_WIDTH = 2
local IS_GAP = 10

local HEAD_BONE = "ValveBiped.Bip01_Head1"
local CHEST_BONE = "ValveBiped.Bip01_Spine2"
local HEAD_CROWN_OFFSET = Vector(0, 0, 9)
local TAG_FOCUS_DIST = 112
local TAG_FADE_START = 256
local TAG_FADE_END = 640
local TAG_TRANSITION_SPEED = 5
local TAG_REST_ALPHA = 0.6
local TAG_VIEW_DOT = 0.25
local TAG_LOS_INTERVAL = 0.15
local TAG_ZOOM_FADE_START = 1200
local TAG_ZOOM_FADE_END = 2000
local NOTICE_DELAY = 1

local tagFont = "HomigradFontLarge"
local cueFont = "HomigradFontMedium"

local propClasses = {prop_physics = true, prop_physics_multiplayer = true}

local tagColor = Color(255, 255, 255)
local tagOutline = Color(0, 0, 0)
local cueColor = Color(255, 255, 255)
local haloColor = Color(255, 220, 90)

local seen = setmetatable({}, {__mode = "k"})
local losCache = setmetatable({}, {__mode = "k"})
local itemCache, itemCacheAt = {}, 0
local corpses = {}
local told = {}
local vignetteAmount = 0

local function o2Of(org)
	return istable(org.o2) and org.o2 or {}
end

local cueDefs = {
	{key = "motionless", text = "motionless", sev = 1, dist = 1800, corpse = true, test = function(org) return org.alive == false end},
	{key = "dull", text = "dull", sev = 1, dist = 900, test = function(org) return org.alive ~= false and org.heartstop and org.otrub end},
	{key = "unconscious", text = "unconscious", sev = 0.85, dist = 1500, test = function(org) return org.alive ~= false and org.otrub end},
	{key = "notbreathing", text = "not breathing", sev = 0.95, dist = 450, test = function(org)
		return org.alive ~= false and (org.respiratoryArrest or (org.otrub and o2Of(org).curregen == 0))
	end},
	{key = "seizing", text = "seizing", sev = 0.85, dist = 1200, test = function(org) return org.alive ~= false and org.seizureActive end},
	{key = "critical", text = "barely hanging on", sev = 0.9, dist = 700, test = function(org) return org.alive ~= false and (org.critical or org.incapacitated) end},
	{key = "gasping", text = "gasping for air", sev = 0.8, dist = 500, test = function(org)
		return org.alive ~= false and not org.otrub and (tonumber(o2Of(org)[1]) or 30) < 15
	end},
	{key = "bleedheavy", text = "bleeding heavily", sev = 0.85, dist = 1000, corpse = true, test = function(org)
		return ((tonumber(org.arterialBleed) or 0) > 0.5 or (tonumber(org.bleed) or 0) > 10)
	end},
	{key = "bleed", text = "bleeding", sev = 0.55, dist = 550, corpse = true, test = function(org)
		return (tonumber(org.bleed) or 0) > 2 and (tonumber(org.arterialBleed) or 0) <= 0.5 and (tonumber(org.bleed) or 0) <= 10
	end},
	{key = "verypale", text = "very pale", sev = 0.75, dist = 350, corpse = true, test = function(org) return (tonumber(org.blood) or 5000) < 2500 end},
	{key = "pale", text = "pale", sev = 0.45, dist = 250, corpse = true, test = function(org)
		local blood = tonumber(org.blood) or 5000

		return blood >= 2500 and blood < 3500
	end},
	{key = "agony", text = "in agony", sev = 0.7, dist = 750, test = function(org) return org.alive ~= false and (tonumber(org.pain) or 0) > 70 end},
	{key = "wince", text = "wincing in pain", sev = 0.4, dist = 350, test = function(org)
		local pain = tonumber(org.pain) or 0

		return org.alive ~= false and not org.otrub and pain > 30 and pain <= 70
	end},
	{key = "shock", text = "in shock", sev = 0.6, dist = 320, test = function(org) return org.alive ~= false and (tonumber(org.shock) or 0) > 35 end},
	{key = "dazed", text = "dazed", sev = 0.5, dist = 300, test = function(org)
		return org.alive ~= false and not org.otrub and (tonumber(org.consciousness) or 1) < 0.6
	end},
	{key = "joint", text = "hurt, with a joint out of place", sev = 0.45, dist = 260, corpse = true, test = function(org)
		return org.llegdislocation or org.rlegdislocation or org.larmdislocation or org.rarmdislocation or org.jawdislocation
	end},
	{key = "nohead", text = "missing their head", sev = 1, dist = 1300, corpse = true, test = function(org) return org.headamputated end},
	{key = "noarm", text = "missing an arm", sev = 0.8, dist = 1300, corpse = true, test = function(org)
		return org.larmamputated or org.rarmamputated or org.larmupamputated or org.rarmupamputated
	end},
	{key = "noleg", text = "missing a leg", sev = 0.8, dist = 1300, corpse = true, test = function(org)
		return org.llegamputated or org.rlegamputated or org.llegupamputated or org.rlegupamputated
	end},
	{key = "nopulse", text = "without a pulse", sev = 0.95, check = true, test = function(org)
		return org.alive ~= false and (org.heartstop or (tonumber(org.pulse) or 0) <= 0)
	end},
	{key = "weakpulse", text = "showing a weak pulse", sev = 0.6, check = true, test = function(org)
		return org.alive ~= false and (tonumber(org.pulse) or 0) > 0 and ((tonumber(org.hypotension) or 0) > 0.74 or (tonumber(org.perfusion) or 1) < 0.35)
	end},
	{key = "fastpulse", text = "showing a fast pulse", sev = 0.4, check = true, test = function(org)
		return org.alive ~= false and (tonumber(org.pulse) or 0) >= 105
	end},
	{key = "fixedpupils", text = "showing fixed, dilated pupils", sev = 0.8, check = true, test = function(org)
		return org.alive ~= false and (tonumber(org.brain) or 0) >= 0.6
	end},
	{key = "pinpoint", text = "showing pinpoint pupils", sev = 0.35, check = true, test = function(org)
		return org.alive ~= false and (tonumber(org.analgesia) or 0) > 1
	end},
}

local function PlayerName(ply)
	local name = hg.ChatLog and hg.ChatLog.Name and hg.ChatLog.Name(ply) or ply:GetPlayerName()

	return isstring(name) and name or "Someone"
end

local function SubjectName(ent)
	if ent:IsPlayer() then return PlayerName(ent) end

	local name = ent:GetPlayerName()
	if isstring(name) and name ~= "" then return name end

	local ply = ent:GetNWEntity("ply")

	return IsValid(ply) and ply:IsPlayer() and PlayerName(ply) or nil
end

local function IsHidden(ent)
	return ent.PlayerClassName == "sc_infiltrator" or ent:GetNetVar("disappearance", nil)
end

local function IsCorpse(ent)
	if ent:IsDormant() or ent:GetNoDraw() or not istable(ent.organism) or IsHidden(ent) then return false end

	local owner = hg.RagdollOwner(ent)
	if IsValid(owner) and owner:Alive() then return false end

	return SubjectName(ent) ~= nil
end

local function Suppressed(lply)
	if IsValid(MENUPANELHUYHUY) then return true end
	if lply:GetNWString("hg_ia_mode", "") ~= "" then return true end
	if lply.organism and lply.organism.otrub then return true end

	local wep = lply:GetActiveWeapon()

	return IsValid(wep) and wep.GetCheckingAfflictions and wep:GetCheckingAfflictions() or false
end

local function AltHeld()
	return input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
end

local function ScanActive(lply)
	return IsValid(lply) and lply:Alive() and AltHeld() and zooming == true and not Suppressed(lply)
end

function hg.IsCueScanning()
	return ScanActive(LocalPlayer())
end

local function ToldRecently(name, key, now)
	local at = told[name] and told[name][key]

	return at ~= nil and now - at < MEMORY_TIME
end

local function SetTold(name, key, at)
	told[name] = told[name] or {}
	told[name][key] = at
end

function hg.MarkCuesTold(ent, keys)
	local name = IsValid(ent) and SubjectName(ent)
	if not name then return end

	for i = 1, #keys do SetTold(name, keys[i], CurTime()) end
end

local function Announce(ent, name, def)
	if not (IsValid(hg.chat) and hg.chat.AddLine) then return end

	local base = hg.ChatLog and hg.ChatLog.COLOR_AROUND or color_white
	local pcol = ent.GetPlayerColor and ent:GetPlayerColor()

	hg.chat:AddLine({base, "You notice ", pcol and pcol:ToColor() or base, name, base, " is " .. def.text .. "."}, false, true)
end

local losTrace = {mask = MASK_VISIBLE}
local losFilter = {}

local function HasLOS(ply, character, pos, eye)
	local now = CurTime()
	local cache = losCache[ply]

	if not cache or cache.at < now then
		local lply = LocalPlayer()
		losFilter[1] = lply
		losFilter[2] = hg.GetCurrentCharacter(lply)
		losFilter[3] = ply
		losFilter[4] = character
		losTrace.start = eye
		losTrace.endpos = pos
		losTrace.filter = losFilter

		cache = {at = now + LOS_INTERVAL, visible = util.TraceLine(losTrace).Fraction >= LOS_MIN_FRACTION}
		losCache[ply] = cache
	end

	return cache.visible
end

local function ObserveSubject(ent, character, eye, forward, examined, corpse)
	local org = ent.organism
	local pos = character:WorldSpaceCenter()
	local delta = pos - eye
	local dist = delta:Length()
	local visible = dist <= OBSERVE_MAX_DIST and delta:Dot(forward) >= dist * VIEW_DOT and HasLOS(ent, character, pos, eye)
	if not visible and not examined then return end

	local name = SubjectName(ent)
	if not name then return end

	local now = CurTime()
	local record = seen[ent]
	if not record then
		record = {}
		seen[ent] = record
	end

	for i = 1, #cueDefs do
		local def = cueDefs[i]
		local canSee = examined or (visible and not def.check and dist <= def.dist)
		if not canSee or (corpse and not def.corpse) then continue end

		local entry = record[def.key]

		if def.test(org) then
			if entry then
				entry.at = now
			else
				record[def.key] = {def = def, at = now, noticeAt = now + NOTICE_DELAY}
			end
		elseif entry then
			record[def.key] = nil
			SetTold(name, def.key, nil)
		end
	end
end

local function FlushNotices(ent, record, now)
	local name = SubjectName(ent)
	if not name then return end

	local texts = {}

	for i = 1, #cueDefs do
		local key = cueDefs[i].key
		local entry = record[key]
		if not entry or not entry.noticeAt or entry.noticeAt > now then continue end

		entry.noticeAt = nil
		if ToldRecently(name, key, now) then continue end

		SetTold(name, key, now)
		Announce(ent, name, entry.def)
		texts[#texts + 1] = entry.def.text
	end

	if #texts == 0 or not hg.AddOverheadMessage then return end

	hg.AddOverheadMessage(ent, "*is " .. table.concat(texts, ", ") .. "*", nil, nil, nil, true)
end

local function Observe()
	local lply = LocalPlayer()
	if not IsValid(lply) or not lply:Alive() then return end

	local now = CurTime()
	local eye, forward = EyePos(), EyeAngles():Forward()
	local checking = lply:GetNWString("hg_ia_mode", "") == "check" and lply:GetNWEntity("hg_ia_target") or nil

	for _, ply in player.Iterator() do
		if ply == lply or not ply.organism or not ply:Alive() or ply:IsDormant() then continue end

		local character = hg.GetCurrentCharacter(ply)
		if IsValid(character) then ObserveSubject(ply, character, eye, forward, checking == ply, false) end
	end

	corpses = {}

	for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
		if not IsCorpse(ent) then continue end

		corpses[#corpses + 1] = ent
		ObserveSubject(ent, ent, eye, forward, checking == ent, true)
	end

	for ent, record in pairs(seen) do
		if not IsValid(ent) then
			seen[ent] = nil
			continue
		end

		FlushNotices(ent, record, now)

		for key, entry in pairs(record) do
			if now - entry.at > MEMORY_TIME then record[key] = nil end
		end
	end
end

timer.Create("HGCueObserve", OBSERVE_INTERVAL, 0, Observe)

local function KnownCues(ply)
	local record = seen[ply]
	if not record then return end

	local list = {}
	for _, entry in pairs(record) do list[#list + 1] = entry end
	if #list == 0 then return end

	table.sort(list, function(a, b) return a.def.sev > b.def.sev end)

	return list
end

local INJURY_SEV = 0.65
local CORPSE_CUE_MAX = 14

local function CorpseCues(org)
	local list = {}
	local now = CurTime()

	for i = 1, #cueDefs do
		local def = cueDefs[i]
		if def.corpse and def.test(org) then list[#list + 1] = {def = def, at = now} end
	end

	local injuries = hg.ChatLog and hg.ChatLog.Injuries
	if injuries then
		for i = 1, #injuries do
			local injury = injuries[i]
			if injury.check(org) then
				injury.cueDef = injury.cueDef or {text = "their " .. injury.text, sev = INJURY_SEV}
				list[#list + 1] = {def = injury.cueDef, at = now}
			end
		end
	end

	if #list == 0 then return end

	table.sort(list, function(a, b) return a.def.sev > b.def.sev end)

	return list
end

local function PlayerTagColor(ent)
	local pcol = ent.GetPlayerColor and ent:GetPlayerColor()
	local col = pcol and pcol:ToColor() or color_white
	tagColor.r, tagColor.g, tagColor.b = col.r, col.g, col.b

	local v = (col.r < 50 and col.g < 50 and col.b < 50) and 100 or 0
	tagOutline.r, tagOutline.g, tagOutline.b = v, v, v
end

local function DrawPerson(ent, name, cues, offer, x, y, alpha, cueMax)
	PlayerTagColor(ent)
	tagColor.a = alpha
	tagOutline.a = alpha

	surface.SetFont(tagFont)
	local nameW, nameH = surface.GetTextSize(name)

	draw.SimpleTextOutlined(name, tagFont, x, y, tagColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, OUTLINE_WIDTH, tagOutline)

	tagOutline.r, tagOutline.g, tagOutline.b = 0, 0, 0

	local count = cues and math.min(#cues, cueMax or CUE_MAX) or 0
	if count > 0 then
		cueColor.r, cueColor.g, cueColor.b, cueColor.a = 255, 255, 255, alpha
		draw.SimpleTextOutlined("is", cueFont, x + nameW / 2 + IS_GAP, y + nameH * 0.5, cueColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, OUTLINE_WIDTH, tagOutline)
	end

	local lineY = y + nameH + 2
	local now = CurTime()

	for i = 1, count do
		local entry = cues[i]
		local sev = math_Clamp(entry.def.sev, 0, 1)
		local age = (now - entry.at) / MEMORY_TIME
		local fade = Lerp(math_Clamp((age - MEMORY_FADE_START) / (1 - MEMORY_FADE_START), 0, 1), 1, MEMORY_MIN_ALPHA)

		cueColor.r, cueColor.g, cueColor.b = 255, 255 * (1 - sev), 255 * (1 - sev)
		cueColor.a = alpha * fade
		tagOutline.a = alpha * fade

		draw.SimpleTextOutlined(entry.def.text, cueFont, x, lineY, cueColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, OUTLINE_WIDTH, tagOutline)
		lineY = lineY + CUE_STEP
	end

	if offer then
		cueColor.r, cueColor.g, cueColor.b, cueColor.a = 255, 255, 255, alpha
		tagOutline.a = alpha

		draw.SimpleTextOutlined("offers you " .. offer .. " (Q)", cueFont, x, lineY, cueColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, OUTLINE_WIDTH, tagOutline)
	end
end

local function CenterDistance(screen, cx, cy)
	local dx, dy = screen.x - cx, screen.y - cy

	return math.sqrt(dx * dx + dy * dy)
end

local function TagBlocked(lply)
	local wep = lply:GetActiveWeapon()
	if not IsValid(wep) then return false end
	if wep.GetCarrying and IsValid(wep:GetCarrying()) then return true end
	if wep.modeNames then return false end

	local hands = hg.PlayerInteract and hg.PlayerInteract.HandsClasses[wep:GetClass()]

	return not hands and (lply:KeyDown(IN_ATTACK2) or (wep.IsZoom and wep:IsZoom()))
end

local tagStates = setmetatable({}, {__mode = "k"})
local tagVisibility = 0

local function BoneWorldPos(character, boneName)
	local bone = character:LookupBone(boneName)
	local matrix = bone and character:GetBoneMatrix(bone)

	return matrix and matrix:GetTranslation()
end

local function VisiblePoint(ply, character, point, eye)
	local lply = LocalPlayer()
	losFilter[1] = lply
	losFilter[2] = hg.GetCurrentCharacter(lply)
	losFilter[3] = ply
	losFilter[4] = character
	losTrace.start = eye
	losTrace.endpos = point
	losTrace.filter = losFilter

	return util.TraceLine(losTrace).Fraction >= LOS_MIN_FRACTION
end

local function DrawTorsoTag(ent, character, faced, scan, offer, opacity, eye, forward)
	local center = character:WorldSpaceCenter()
	local delta = center - eye
	local range = delta:Length()
	local fadeStart = scan and TAG_ZOOM_FADE_START or TAG_FADE_START
	local fadeEnd = scan and TAG_ZOOM_FADE_END or TAG_FADE_END
	local focused = faced and range <= TAG_FOCUS_DIST
	local pinned = faced and scan
	local outOfView = range >= fadeEnd or delta:Dot(forward) < range * TAG_VIEW_DOT
	if outOfView and not focused and not pinned then
		tagStates[ent] = nil
		return
	end

	local name = SubjectName(ent)
	if not name then return end

	local now = CurTime()
	local state = tagStates[ent]
	if not state or state.character ~= character then
		state = {character = character, checkAt = 0, focus = 0}
		tagStates[ent] = state
	end

	local chest = BoneWorldPos(character, CHEST_BONE) or center
	if now >= state.checkAt then
		state.visible = VisiblePoint(ent, character, chest, eye)
		state.checkAt = now + TAG_LOS_INTERVAL
	end

	state.focus = math.Approach(state.focus, focused and 1 or 0, RealFrameTime() * TAG_TRANSITION_SPEED)
	if not state.visible and not focused and not pinned then return end

	local screen = chest:ToScreen()
	if not screen.visible and not focused then return end

	local blend = math.ease.InOutSine(state.focus)
	local centerX, centerY = ScrW() * 0.5, ScrH() * 0.5 + NAME_OFFSET
	local x = screen.visible and Lerp(blend, screen.x, centerX) or centerX
	local y = screen.visible and Lerp(blend, screen.y, centerY) or centerY
	local distanceFade = pinned and 1 or math_Clamp((fadeEnd - range) / (fadeEnd - fadeStart), 0, 1)
	local alpha = opacity * math.ease.InOutSine(distanceFade) * (pinned and 1 or Lerp(blend, TAG_REST_ALPHA, 1))
	local cues, cueMax

	if scan then
		if ent:IsPlayer() then
			cues = KnownCues(ent)
		elseif istable(ent.organism) then
			cues, cueMax = CorpseCues(ent.organism), CORPSE_CUE_MAX
		end
	end

	state.frame = FrameNumber()
	DrawPerson(ent, name, cues, offer, x, y, alpha, cueMax)
end

local function OfferFor(ply, lply)
	if ply:GetNWString("hg_ia_mode", "") ~= "offer" or ply:GetNWEntity("hg_ia_target") ~= lply then return end

	return ply:GetNWString("hg_ia_item", "something")
end

local function DrawTorsoTags(lply, faced, scan)
	local eye, forward = EyePos(), EyeAngles():Forward()
	local opacity = math.ease.InOutSine(tagVisibility) * 255

	for _, ply in player.Iterator() do
		local character = ply ~= lply and ply:Alive() and not ply:IsDormant() and hg.GetCurrentCharacter(ply)
		if not IsValid(character) or character:IsDormant() or character:GetNoDraw() or IsHidden(ply) then
			tagStates[ply] = nil
			continue
		end

		DrawTorsoTag(ply, character, faced == ply, scan, OfferFor(ply, lply), opacity, eye, forward)
	end

	for i = 1, #corpses do
		local corpse = corpses[i]
		if IsValid(corpse) then DrawTorsoTag(corpse, corpse, faced == corpse, scan, nil, opacity, eye, forward) end
	end
end

function hg.GetTagOverhead(ply)
	local state = tagStates[ply]
	if not state or not state.frame or state.frame < FrameNumber() - 1 or not IsValid(state.character) then return end

	local head = BoneWorldPos(state.character, HEAD_BONE)

	return head and head + HEAD_CROWN_OFFSET or state.character:WorldSpaceCenter(), 0
end

local function FacedSubject(lply, dist)
	local trace = hg.eyeTrace(lply, dist)
	local hit = trace and trace.Hit and trace.Entity
	if not IsValid(hit) then return end
	if hit:IsPlayer() then return hit, trace end
	if not hit:IsRagdoll() then return end

	local owner = hg.RagdollOwner(hit)
	if IsValid(owner) and owner:Alive() then return owner, trace end

	return hit, trace
end

local function DrawHoverTag(lply, faced, trace)
	if IsHidden(faced) then return end

	local name = SubjectName(faced)
	if not name then return end

	local range = EyePos():Distance(trace.HitPos)
	local distanceFade = math_Clamp((TAG_FADE_END - range) / (TAG_FADE_END - TAG_FADE_START), 0, 1)
	if distanceFade <= 0 then return end

	local offer = faced:IsPlayer() and OfferFor(faced, lply) or nil
	local screen = trace.HitPos:ToScreen()

	DrawPerson(faced, name, nil, offer, screen.x, screen.y + NAME_OFFSET, math.ease.InOutSine(distanceFade) * 255)
end

local function IsMovable(ent)
	if not (propClasses[ent:GetClass()] or (ent:IsWeapon() and not IsValid(ent:GetOwner()))) then return false end
	if ent:GetMoveType() ~= MOVETYPE_VPHYSICS or ent:GetNoDraw() then return false end

	local phys = ent:GetPhysicsObject()

	return IsValid(phys) and phys:IsMotionEnabled()
end

local function MovableItems(eye)
	local now = CurTime()
	if itemCacheAt > now then return itemCache end
	itemCacheAt = now + ITEM_REFRESH

	local list = {}
	local limit = ZOOM_DIST * ZOOM_DIST
	local all = ents.GetAll()

	for i = 1, #all do
		local ent = all[i]
		if IsValid(ent) and not ent:IsDormant() and IsMovable(ent) then
			local d = eye:DistToSqr(ent:GetPos())
			if d <= limit then list[#list + 1] = {ent = ent, d = d} end
		end
	end

	table.sort(list, function(a, b) return a.d < b.d end)

	for i = #list, ITEM_LIMIT + 1, -1 do list[i] = nil end
	itemCache = list

	return list
end

local function ItemName(ent)
	if ent:IsWeapon() and ent.GetPrintName then
		local name = ent:GetPrintName()
		if isstring(name) and name ~= "" then return name end
	end

	if isstring(ent.PrintName) and ent.PrintName ~= "" then return ent.PrintName end

	local model = string.StripExtension(string.GetFileFromFilename(ent:GetModel() or ""))

	return (string.gsub(model, "_", " "))
end

local function DrawItemNames(radius)
	local cx, cy = ScrW() / 2, ScrH() / 2
	local picks = {}

	for _, item in ipairs(itemCache) do
		local ent = item.ent
		if IsValid(ent) then
			local screen = ent:WorldSpaceCenter():ToScreen()
			local d = screen.visible and CenterDistance(screen, cx, cy)
			if d and d <= radius then picks[#picks + 1] = {ent = ent, screen = screen, d = d} end
		end
	end

	table.sort(picks, function(a, b) return a.d < b.d end)

	cueColor.r, cueColor.g, cueColor.b, cueColor.a = haloColor.r, haloColor.g, haloColor.b, 255
	tagOutline.r, tagOutline.g, tagOutline.b, tagOutline.a = 0, 0, 0, 255

	for i = 1, math.min(#picks, ITEM_NAME_LIMIT) do
		local pick = picks[i]
		draw.SimpleTextOutlined(ItemName(pick.ent), cueFont, pick.screen.x, pick.screen.y, cueColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, OUTLINE_WIDTH, tagOutline)
	end
end

local function DrawVignette(amount)
	local w, h = ScrW(), ScrH()
	local bandW, bandH = w * 0.5 / VIGNETTE_BANDS, h * 0.5 / VIGNETTE_BANDS

	for i = 0, VIGNETTE_BANDS - 1 do
		local fall = 1 - i / VIGNETTE_BANDS
		surface.SetDrawColor(0, 0, 0, VIGNETTE_ALPHA * amount * fall * fall)
		surface.DrawRect(i * bandW, 0, bandW + 1, h)
		surface.DrawRect(w - (i + 1) * bandW, 0, bandW + 1, h)
		surface.DrawRect(0, i * bandH, w, bandH + 1)
		surface.DrawRect(0, h - (i + 1) * bandH, w, bandH + 1)
	end
end

hook.Add("HUDPaint", "HGCueScan", function()
	local lply = LocalPlayer()
	local usable = IsValid(lply) and lply:Alive() and not Suppressed(lply)
	local alt = AltHeld()
	local zoomScan = usable and alt and zooming == true

	vignetteAmount = Lerp(math_Clamp(FrameTime() * VIGNETTE_SPEED, 0, 1), vignetteAmount, zoomScan and 1 or 0)
	if vignetteAmount > 0.01 then DrawVignette(vignetteAmount) end

	if not usable or lply:GetNetVar("disappearance", nil) then
		tagVisibility = 0
		return
	end

	tagVisibility = math.Approach(tagVisibility, alt and 1 or 0, RealFrameTime() * TAG_TRANSITION_SPEED)

	local faced, trace = FacedSubject(lply, zoomScan and ZOOM_DIST or TAG_FADE_END)

	if tagVisibility > 0 then
		DrawTorsoTags(lply, faced, zoomScan)
	elseif faced and not TagBlocked(lply) then
		DrawHoverTag(lply, faced, trace)
	end

	if zoomScan then
		MovableItems(EyePos())
		DrawItemNames(ScrH() * ZOOM_RADIUS)
	end
end)

hook.Add("PreDrawHalos", "HGCueScanHalos", function()
	local lply = LocalPlayer()
	if not ScanActive(lply) then return end

	local highlighted = {}

	for _, item in ipairs(MovableItems(EyePos())) do
		if IsValid(item.ent) then highlighted[#highlighted + 1] = item.ent end
	end

	if #highlighted > 0 then halo.Add(highlighted, haloColor, 2, 2, 1, true, true) end
end)
