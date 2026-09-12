if SERVER then
	AddCSLuaFile()
end

local warningSound = "rem_refuse.mp3"
local punishmentSound = "rem_intracranialied.mp3"
local warningDuration = SoundDuration(warningSound)
if warningDuration <= 0 then warningDuration = 2 end
local punishmentDuration = 2.038

if SERVER then
	local targetConVar = CreateConVar("hg_antijohnuser", "", FCVAR_REPLICATED, "Toggle current in-server player names, separated by commas")
	local blacklistConVar = CreateConVar("hg_antijohnweapons", "", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Weapon names/classes, entity classes, or prop models to forbid, separated by commas; partial words and * are supported")
	local restrictedNames = {}

	util.AddNetworkString("hg_antijohn_warning")

	local warningWords = {
		"cut that out",
		"thats for grown ups",
		"stop",
		"no"
	}

	local punishmentWords = {
		"stop nigga",
		"back to the lobby",
		"This is your last mistake.",
		"ayo diddy"
	}

	local function splitList(value, splitWhitespace)
		local entries = {}
		local pattern = splitWhitespace and "[^,;%s]+" or "[^,;\r\n]+"
		for entry in string.gmatch(string.lower(value or ""), pattern) do
			entry = string.Trim(entry)
			if entry ~= "" then entries[#entries + 1] = entry end
		end
		return entries
	end

	local function globMatches(value, pattern)
		if pattern == "*" then return true end
		if not string.find(pattern, "*", 1, true) then return value == pattern end
		local escaped = string.gsub(pattern, "([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1")
		escaped = string.gsub(escaped, "%*", ".*")
		return string.match(value, "^" .. escaped .. "$") ~= nil
	end

	local function matchesAny(value, entries)
		value = string.lower(string.Trim(tostring(value or "")))
		if value == "" then return false end
		for _, pattern in ipairs(entries) do
			if globMatches(value, pattern) then return true end
		end
		return false
	end

	local function containsAny(value, entries)
		value = string.lower(string.Trim(tostring(value or "")))
		if value == "" then return false end
		for _, pattern in ipairs(entries) do
			if pattern ~= "" and not string.find(pattern, "*", 1, true) and string.find(value, pattern, 1, true) then
				return true
			end
		end
		return false
	end

	local function editDistance(left, right)
		local previous = {}
		for column = 0, #right do
			previous[column] = column
		end

		for row = 1, #left do
			local current = {[0] = row}
			local leftCharacter = string.sub(left, row, row)
			for column = 1, #right do
				local cost = leftCharacter == string.sub(right, column, column) and 0 or 1
				current[column] = math.min(current[column - 1] + 1, previous[column] + 1, previous[column - 1] + cost)
			end
			previous = current
		end

		return previous[#right]
	end

	local function nearestPlayerNames(query)
		local ranked = {}
		local seen = {}
		for _, ply in ipairs(player.GetAll()) do
			local displayName = string.Trim(ply:Nick())
			local name = string.lower(displayName)
			if name ~= "" and not seen[name] then
				seen[name] = true
				local position = string.find(name, query, 1, true)
				ranked[#ranked + 1] = {
					name = displayName,
					contains = position ~= nil,
					position = position or math.huge,
					distance = editDistance(query, name)
				}
			end
		end

		table.sort(ranked, function(left, right)
			if left.contains ~= right.contains then return left.contains end
			if left.contains and left.position ~= right.position then return left.position < right.position end
			if left.distance ~= right.distance then return left.distance < right.distance end
			return string.lower(left.name) < string.lower(right.name)
		end)

		local names = {}
		for index = 1, math.min(#ranked, 5) do
			names[index] = ranked[index].name
		end
		return names
	end

	local function toggleRestrictedNames(value)
		for _, query in ipairs(splitList(value)) do
			local name = query
			if not restrictedNames[name] then
				name = nil
				for _, ply in ipairs(player.GetAll()) do
					local currentName = string.lower(string.Trim(ply:Nick()))
					if currentName == query then
						name = currentName
						break
					end
				end
			end

			if not name then
				local nearest = nearestPlayerNames(query)
				MsgN("[AntiJohn] No exact in-server user found for: " .. query)
				MsgN(#nearest > 0 and "[AntiJohn] Nearest matches: " .. table.concat(nearest, ", ") or "[AntiJohn] There are no players to suggest.")
				continue
			end

			if restrictedNames[name] then
				restrictedNames[name] = nil
				for _, ply in ipairs(player.GetAll()) do
					if string.lower(string.Trim(ply:Nick())) == name then
						ply.hgAntiJohnAttempts = 0
						ply.hgAntiJohnPunishment = nil
						ply.hgAntiJohnLastAttempt = nil
						ply.hgAntiJohnLastItem = nil
						timer.Remove("hg_antijohn_gib_" .. ply:EntIndex())
						ply:StopSound(punishmentSound)
						net.Start("hg_antijohn_warning")
							net.WriteUInt(0, 2)
							net.WriteString("")
						net.Send(ply)
					end
				end
				MsgN("[AntiJohn] Removed in-server user: " .. name)
			else
				restrictedNames[name] = true
				MsgN("[AntiJohn] Added in-server user: " .. name)
			end
		end
	end

	local clearingTargetConVar = false
	cvars.AddChangeCallback("hg_antijohnuser", function(_, _, newValue)
		if clearingTargetConVar or string.Trim(newValue or "") == "" then return end
		toggleRestrictedNames(newValue)
		timer.Simple(0, function()
			clearingTargetConVar = true
			targetConVar:SetString("")
			clearingTargetConVar = false
		end)
	end, "hg_antijohn_toggle_user")

	timer.Simple(0, function()
		local initialValue = targetConVar:GetString()
		if string.Trim(initialValue) == "" then return end
		toggleRestrictedNames(initialValue)
		clearingTargetConVar = true
		targetConVar:SetString("")
		clearingTargetConVar = false
	end)

	local function isRestrictedPlayer(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return false end
		local name = string.lower(string.Trim(ply:Nick()))
		return restrictedNames[name] == true
	end

	local function isBlacklisted(value)
		local entries = splitList(blacklistConVar:GetString(), true)
		if #entries == 0 then return false end
		if matchesAny(value, entries) then return true end

		local canonical
		if hg and hg.CanonicalWeaponClass then
			canonical = hg.CanonicalWeaponClass(tostring(value or ""))
			if matchesAny(canonical, entries) then return true end
		end

		local stored = weapons.Get(tostring(value or ""))
		local printName = stored and stored.PrintName
		return containsAny(value, entries) or containsAny(canonical, entries) or containsAny(printName, entries)
	end

	local function sendWarning(ply, stage)
		local words = stage == 2 and punishmentWords or warningWords
		net.Start("hg_antijohn_warning")
			net.WriteUInt(stage, 2)
			net.WriteString(words[math.random(#words)])
		net.Send(ply)
	end

	local function punishAttempt(ply, item)
		if not isRestrictedPlayer(ply) or not isBlacklisted(item) then return false end

		local now = CurTime()
		local attemptKey = string.lower(tostring(item or ""))
		if ply.hgAntiJohnLastItem == attemptKey and now - (ply.hgAntiJohnLastAttempt or 0) < 0.25 then
			return true
		end

		ply.hgAntiJohnLastItem = attemptKey
		ply.hgAntiJohnLastAttempt = now
		ply.hgAntiJohnAttempts = (ply.hgAntiJohnAttempts or 0) + 1

		if ply.hgAntiJohnAttempts == 1 then
			sendWarning(ply, 1)
			return true
		end

		if ply.hgAntiJohnPunishment then return true end
		ply.hgAntiJohnPunishment = true
		sendWarning(ply, 2)
		ply:EmitSound(punishmentSound, 100, 100, 1, CHAN_AUTO)

		local timerName = "hg_antijohn_gib_" .. ply:EntIndex()
		timer.Create(timerName, punishmentDuration, 1, function()
			if not IsValid(ply) or not ply.hgAntiJohnPunishment then return end
			local target = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply:GetNWEntity("RagdollDeath")
			if not IsValid(target) then target = ply end
			if IsValid(target) and hg and hg.ExplodeHead then hg.ExplodeHead(target) end
		end)

		return true
	end

	local function blockWeapon(ply, wep)
		if not IsValid(wep) then return end
		if punishAttempt(ply, wep:GetClass()) then return false end
	end

	hook.Add("PlayerCanPickupWeapon", "hg_antijohn_pickup", blockWeapon)

	hook.Add("WeaponEquip", "hg_antijohn_equip", function(wep, ply)
		if not IsValid(wep) or not punishAttempt(ply, wep:GetClass()) then return end
		timer.Simple(0, function()
			if IsValid(ply) and IsValid(wep) and wep:GetOwner() == ply then
				ply:StripWeapon(wep:GetClass())
			end
		end)
	end)

	hook.Add("PlayerGiveSWEP", "hg_antijohn_give", function(ply, class)
		if punishAttempt(ply, class) then return false end
	end)

	hook.Add("PlayerSpawnSWEP", "hg_antijohn_spawn_swep", function(ply, class)
		if punishAttempt(ply, class) then return false end
	end)

	hook.Add("AllowPlayerPickup", "hg_antijohn_entity_pickup", function(ply, ent)
		if not IsValid(ent) then return end
		if punishAttempt(ply, ent:GetClass()) or punishAttempt(ply, ent:GetModel() or "") then return false end
	end)

	local spawnHooks = {
		"PlayerSpawnEffect",
		"PlayerSpawnNPC",
		"PlayerSpawnProp",
		"PlayerSpawnRagdoll",
		"PlayerSpawnSENT",
		"PlayerSpawnVehicle"
	}

	for _, hookName in ipairs(spawnHooks) do
		hook.Add(hookName, "hg_antijohn_owned_entity", function(ply, ...)
			for _, value in ipairs({...}) do
				if isstring(value) and punishAttempt(ply, value) then return false end
			end
		end)
	end

	hook.Add("PlayerSpawn", "hg_antijohn_reset", function(ply)
		ply.hgAntiJohnAttempts = 0
		ply.hgAntiJohnPunishment = nil
		ply.hgAntiJohnLastAttempt = nil
		ply.hgAntiJohnLastItem = nil
		timer.Remove("hg_antijohn_gib_" .. ply:EntIndex())
	end)
end

if CLIENT then
	local warning
	local warningStation
	local fontName = "hg_antijohn_text"

	surface.CreateFont(fontName, {
		font = "VCR OSD Mono",
		size = 52,
		weight = 900,
		antialias = true
	})

	net.Receive("hg_antijohn_warning", function()
		local stage = net.ReadUInt(2)
		local text = net.ReadString()
		if stage == 0 then
			warning = nil
			if warningStation then warningStation:Stop() end
			warningStation = nil
			return
		end
		local duration = stage == 2 and punishmentDuration or warningDuration
		warning = {
			stage = stage,
			text = text,
			endsAt = CurTime() + duration
		}
		if warningStation then warningStation:Stop() end
		warningStation = nil
		if stage == 1 then
			warningStation = CreateSound(LocalPlayer(), warningSound)
			warningStation:PlayEx(1, 100)
		end
	end)

	hook.Add("HUDPaint", "hg_antijohn_warning", function()
		if not warning then return end
		local remaining = warning.endsAt - CurTime()
		if remaining <= 0 then
			warning = nil
			warningStation = nil
			return
		end

		local duration = warning.stage == 2 and punishmentDuration or warningDuration
		local alpha = math.Clamp(remaining / math.min(duration, 1), 0, 1) * 255
		local color = warning.stage == 2 and Color(145, 0, 0, alpha) or Color(0, 0, 0, alpha)
		surface.SetDrawColor(color)
		surface.DrawRect(0, 0, ScrW(), ScrH())
		draw.SimpleTextOutlined(warning.text, fontName, ScrW() * 0.5, ScrH() * 0.5, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, alpha))
	end)
end
