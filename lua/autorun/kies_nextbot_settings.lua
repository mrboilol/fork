AddCSLuaFile()

local SETTINGS = {
	kies_health = { 150, 1,   2000 },
	kies_speed  = { 175, 0,   1000 },
	kies_damage = { 25,  0,   500  },
}

local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)

CreateConVar("kies_health", SETTINGS.kies_health[1], FLAGS, "Kies health.")
CreateConVar("kies_speed",  SETTINGS.kies_speed[1],  FLAGS, "Kies movement speed (GMod walk speed is 200).")
CreateConVar("kies_damage", SETTINGS.kies_damage[1], FLAGS, "Damage Kies deals per hit.")
CreateConVar("kies_attack_range",     70,    FLAGS, "How close Kies must be to hit you.")
CreateConVar("kies_attack_delay",     0.6,   FLAGS, "Seconds between Kies hits.")
CreateConVar("kies_acquire_distance", 10000, FLAGS, "Max distance Kies will chase a player from.")

if SERVER then

	util.AddNetworkString("KiesSetting")
	util.AddNetworkString("KiesReset")

	local function CanEdit(ply)
		return IsValid(ply) and (game.SinglePlayer() or ply:IsListenServerHost() or ply:IsSuperAdmin())
	end

	net.Receive("KiesSetting", function(_, ply)
		if not CanEdit(ply) then return end

		local name  = net.ReadString()
		local value = net.ReadFloat()
		local def   = SETTINGS[name]
		if not def then return end

		RunConsoleCommand(name, tostring(math.Clamp(value, def[2], def[3])))
	end)

	net.Receive("KiesReset", function(_, ply)
		if not CanEdit(ply) then return end

		for name, def in pairs(SETTINGS) do
			RunConsoleCommand(name, tostring(def[1]))
		end
	end)

	cvars.AddChangeCallback("kies_health", function(_, _, new)
		local hp = math.max(1, math.floor(tonumber(new) or SETTINGS.kies_health[1]))
		for _, k in ipairs(ents.FindByClass("npc_kies")) do
			if IsValid(k) and k.ApplyNewMaxHealth then
				k:ApplyNewMaxHealth(hp)
			end
		end
	end, "KiesHealthLive")

else

	local sliders = {}
	local suppress = false

	local function SendSetting(name, value)
		net.Start("KiesSetting")
		net.WriteString(name)
		net.WriteFloat(value)
		net.SendToServer()
	end

	local function SetSliderQuiet(name, value)
		local s = sliders[name]
		if not IsValid(s) then return end
		suppress = true
		s:SetValue(value)
		suppress = false
	end

	for name in pairs(SETTINGS) do
		cvars.AddChangeCallback(name, function(_, _, new)
			SetSliderQuiet(name, tonumber(new) or SETTINGS[name][1])
		end, "KiesSlider_" .. name)
	end

	local function AddSetting(panel, name, label)
		local def = SETTINGS[name]
		local s = vgui.Create("DNumSlider", panel)
		s:SetText(label)
		s:SetMin(def[2])
		s:SetMax(def[3])
		s:SetDecimals(0)
		s:SetDark(true)
		s:Dock(TOP)
		s:DockMargin(8, 0, 8, 0)
		s:SetTall(30)

		local cv = GetConVar(name)
		suppress = true
		s:SetValue(cv and cv:GetFloat() or def[1])
		suppress = false

		s.OnValueChanged = function(_, val)
			if suppress then return end
			local timerName = "KiesSend_" .. name
			timer.Create(timerName, 0.25, 1, function()
				SendSetting(name, math.Round(val))
			end)
		end

		sliders[name] = s
		panel:AddItem(s)
	end

	hook.Add("PopulateToolMenu", "KiesNextbotOptions", function()
		spawnmenu.AddToolMenuOption("Options", "Kies Nextbot", "kies_nextbot_options", "Kies Nextbot", "", "", function(panel)
			panel:ClearControls()

			panel:Help("Changes apply to Kies right away, including ones that are already spawned.")

			AddSetting(panel, "kies_speed",  "Speed")
			AddSetting(panel, "kies_damage", "Damage")
			AddSetting(panel, "kies_health", "Health")

			local btn = panel:Button("Reset to defaults")
			btn.DoClick = function()
				for name, def in pairs(SETTINGS) do
					SetSliderQuiet(name, def[1])
				end
				net.Start("KiesReset")
				net.SendToServer()
			end

			panel:ControlHelp("Defaults: Speed 175, Damage 25, Health 150.\nOnly the host / superadmins can change these.")
		end)
	end)

end
