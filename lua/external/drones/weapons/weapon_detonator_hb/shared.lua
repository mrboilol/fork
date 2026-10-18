
if (SERVER) then // This is where the init.lua stuff goes.
	AddCSLuaFile ("shared.lua")
	SWEP.Weight = 5
	SWEP.AutoSwitchTo = false
	SWEP.AutoSwitchFrom = false
	util.AddNetworkString("detonator_gui")
	util.AddNetworkString("detonator_datastream")
	
elseif (CLIENT) then 
	SWEP.PrintName = "HBOMBS Detonator"
	SWEP.Slot = 1
	SWEP.SlotPos = 1
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = true
	
end
 
SWEP.Author = ""
SWEP.Contact = ""
SWEP.Purpose = "Detonates edverything"
SWEP.Instructions = "Right click while aiming at a bomb to set the time. Left click to detonate."

SWEP.Category = "HBOMBS SWEPS"
 
SWEP.Spawnable = true -- Whether regular players can see it
SWEP.AdminSpawnable = true -- Whether Admins/Super Admins can see it
 
SWEP.ViewModel = "models/weapons/V_radio_hands.mdl" -- This is the model used for clients to see in first person.
SWEP.WorldModel = "" -- This is the model shown to all other clients and in third-person.
SWEP.ViewModelFOV			= 60



SWEP.Primary.ClipSize = -1
 
SWEP.Primary.DefaultClip = -1
 
SWEP.Primary.Automatic = false
 
SWEP.Primary.Ammo = "none"
 
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

 
function SWEP:Reload()
end
 
function SWEP:Think()
end
 
 
function SWEP:PrimaryAttack()
	self:SendWeaponAnim(ACT_VM_DEPLOY)
	
	timer.Simple(self:SequenceDuration(), function()
		self:SendWeaponAnim(ACT_VM_IDLE)
		self:Detonate()
	end)
	
	

end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW_SILENCED)
	
	if self.Owner.DetonatorDB!=nil then for k, v in pairs(self.Owner.DetonatorDB) do if v["entity"]:IsValid() then v["entity"].IsLinked=false self.Owner:ChatPrint(v["entity"]:GetClass().. " unlinked.") end end end
	self.Owner.DetonatorDB = {}
	timer.Simple(self:SequenceDuration(), function()
		self:SendWeaponAnim(ACT_VM_IDLE)
	end)
	

	return true

end
 
function SWEP:Detonate()
	if self.Owner.DetonatorDB == nil then return end
	for k, v in pairs(self.Owner.DetonatorDB) do
		local entity, delay = v["entity"], v["delay" ]
		if entity:IsValid() then
			if string.StartWith(entity:GetClass(), "hb_") then
				timer.Simple(delay, function()
					if !entity:IsValid() then return end
					entity.Exploded=true
					entity:Explode()
				end)
			elseif string.StartWith(entity:GetClass(), "hb_") then
				timer.Simple(delay, function()
					if !entity:IsValid() then return end
					entity.Exploded=true
					entity:Explode()
				end)		

					
			elseif string.StartWith(entity:GetClass(), "gf2_") then
				if string.StartWith(entity:GetClass(), "gf2_fountain_") or string.StartWith(entity:GetClass(), "gf2_romancandle") then	
				
					timer.Simple(delay, function()
						if !entity:IsValid() then return end
						entity:EmitSound("npc/roller/mine/rmine_blip3.wav")
						entity.Armed=true
						entity:StartEmitting() 

						
					end)
					
				elseif string.StartWith(entity:GetClass(), "gf2_rocket") or string.StartWith(entity:GetClass(), "gf2_mortars_mortar_big") then
					timer.Simple(delay, function()
						if !entity:IsValid() then return end

						entity.Armed=true
						entity:Launch()


						
					end)
				else 
					timer.Simple(delay, function()
						if !entity:IsValid() then return end

						entity:Arm()


						
					end)
				end
			end
		end
	end
	
end

function SWEP:SecondaryAttack()
	local trace = self.Owner:GetEyeTrace()
	
	if trace.Entity != nil and trace.Entity.IsLinked!=true then

		net.Start("detonator_gui")
			net.WriteEntity(trace.Entity)
			net.WriteEntity(self.Owner)
		net.Send(self.Owner)
			
		self:EmitSound("buttons/button8.wav",100,100)

	end

end
 
net.Receive("detonator_datastream",function()
	local entity 		= net.ReadEntity()
	local player        = net.ReadEntity()
	local detonator_timer  	= net.ReadFloat()
	entity.IsLinked     = true
	if player.DetonatorDB[entity]==nil then
		table.insert(player.DetonatorDB, {["entity"]=entity,
										  ["delay" ]=detonator_timer})
	end

end)

net.Receive("detonator_gui",function()

	local entity = net.ReadEntity()

	local win=vgui.Create("DFrame")
	win:SetSize(200,200)
	win:Center()
	win:SetVisible(true)
	win:SetTitle("Detonator GUI")
	
	
	local detonator_w=vgui.Create("DLabel", win)
	detonator_w:SetPos(25,60)
	detonator_w:SetText("Explosion Delay (1-120 seconds):")
	detonator_w:SizeToContents()
		
	local detonator_time=vgui.Create("DTextEntry",win)
	detonator_time:SetPos(50,90)
	detonator_time:SetWide(100)
	detonator_time:SetTall(15)
	detonator_time:SetEnterAllowed(false)
	
	
	local DButton = vgui.Create( "DImageButton", win )
	DButton:SetPos( 70, 120 )
	DButton:SetText( "" )
	DButton:SetImage("icon16/cross.png")
	DButton:SetSize( 60, 60 )
	DButton.DoClick = function()
		if (!(not tonumber(detonator_time:GetValue())))then 
			if tonumber(detonator_time:GetValue())>=1 and tonumber(detonator_time:GetValue())<=120 then
				surface.PlaySound("items/suitchargeok1.wav")
				net.Start("detonator_datastream")
					net.WriteEntity(entity)
					net.WriteEntity(LocalPlayer())
					net.WriteFloat(detonator_time:GetValue())
				net.SendToServer()
				
				win:SetVisible(false)
			
				
				
			end
		else
			surface.PlaySound("vo/npc/male01/answer11.wav")		
		end
		
	end

	detonator_time.OnTextChanged=function()
		if (!(not tonumber(detonator_time:GetValue())))then 
			if tonumber(detonator_time:GetValue())>=1 and tonumber(detonator_time:GetValue())<=120 then
				DButton:SetImage("icon16/tick.png")
			else
				DButton:SetImage("icon16/cross.png")			
			end
		else
			DButton:SetImage("icon16/cross.png")
		end
		
	end
	
	win:SetDeleteOnClose(true)
	win:MakePopup()
end)