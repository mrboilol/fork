AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )


ENT.Spawnable		            	 =  true         
ENT.AdminSpawnable		             =  true 

ENT.PrintName		                 =  "Mortar Cache"
ENT.Author			                 =  "Chappi"
ENT.Contact			                 =  "chappi555@gmail.com"
ENT.Category                         =  "HBOMBS Misc"
ENT.Type                             =  "anim"
ENT.Model                            =  "models/models/gb4/mortar_cache.mdl"
ENT.Mass                             =  100
ENT.AutomaticFrameAdvance = true

ENT.Effect                           =  "bomb_explosion"                  
ENT.EffectAir                        =  "bomb_explosion_air"  

ENT.GBOWNER                          =  nil             -- don't you fucking touch this.

local ExploSnds = {}
ExploSnds[1]                         =  "ambient/explosions/explode_1.wav"
ExploSnds[2]                         =  "ambient/explosions/explode_2.wav"
ExploSnds[3]                         =  "ambient/explosions/explode_3.wav"
ExploSnds[4]                         =  "ambient/explosions/explode_4.wav"
ExploSnds[5]                         =  "ambient/explosions/explode_5.wav"
ExploSnds[6]                         =  "npc/env_headcrabcanister/explosion.wav"

if (SERVER) then util.AddNetworkString( "mortar_cache" ) end
function ENT:Initialize()

	if (SERVER) then
		self:LoadModel()
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetUseType( ONOFF_USE ) 
		
		local phys = self:GetPhysicsObject()
		local skincount = self:SkinCount()
		
		if (phys:IsValid()) then
			phys:SetMass(self.Mass)
			phys:Wake()
		end

		self.Armed    = false
		self.Exploded = false
		self.Used     = false
		self.Arming   = false
		self.OldCount = 0
		self.Life     = 100
		self.BarrelCount = 0
	
		self.RequestTime   = CurTime()
		self.RequestTime2  = CurTime()
		self.Mortar        = nil
		self.AmmoList      = {}

		
	


	end
end


function ENT:ExploSound(pos)
	 local ent = ents.Create("gb4_shockwave_sound_lowsh")
	 ent:SetPos( pos ) 
	 ent:Spawn()
	 ent:Activate()
	 ent:SetVar("GBOWNER", self.GBOWNER)
	 ent:SetVar("MAX_RANGE",500000)
	 ent:SetVar("SHOCKWAVE_INCREMENT",20000)
	 ent:SetVar("DELAY",0.01)
	 ent:SetVar("SOUND", table.Random(ExploSnds))
	 ent:SetVar("Shocktime",1)
end


function ENT:SpawnFunction( ply, tr )
     if ( !tr.Hit ) then return end
	 self.GBOWNER = ply
     local ent = ents.Create( self.ClassName )
	 ent:SetPhysicsAttacker(ply)
     ent:SetPos( tr.HitPos + tr.HitNormal * 32 ) 
     ent:Spawn()
     ent:Activate()
     return ent
end

function ENT:FilterMortars()
	local mortars = {}
	for k, v in pairs(ents.FindInSphere(self:GetPos(), 500)) do
		if (v.HBOWNER!=nil or v.GBOWNER!=nil and v.ClassName != self.ClassName and v:GetMoveType() != "MOVETYPE_NONE" ) or (v:GetClass() == "prop_physics" and v:GetModel() == "models/props_c17/oildrum001_explosive.mdl" )then	
			table.insert(mortars, v)
		end
	end
	return mortars
end

function ENT:HasMortarCountChanged()
	local nm = self:FilterMortars()
	nm = #nm
	
	if self.OldCount == nm then 

	else
		if nm > 0 && self.OldCount==0 then 
			self.OldCount = nm
			self:ResetSequence( self:LookupSequence( "open" ))
			self:SetPlaybackRate( 2 )
			self:EmitSound("open.wav", 70, 100)
			
			timer.Simple(self:SequenceDuration(), function()
				if !self:IsValid() then return end
				
				self.IsOpen=true
			end)			
		elseif nm < 1 && self.OldCount>=1 then
			self.OldCount = nm
			self:EmitSound("close.wav", 70, 100)
			self:ResetSequence( self:LookupSequence( "close" ))
			self:SetPlaybackRate( 2 )
			timer.Simple(self:SequenceDuration(), function()
				if !self:IsValid() then return end
				self.IsOpen=false
			end)

		end
		
	end
	
			
end

function ENT:CanLaunch2()
	if (self.RequestTime2+(math.random(250,270)/1000)) < CurTime()then
		self.RequestTime2=CurTime()
		return true
	else	
		return false
	end
end


function ENT:TakeAmmo()
	
	if self.IsOpen == true then
		for k, v in pairs(self:FilterMortars()) do
			
			if v:GetPos():Distance(self:GetPos()) < 80 && v.Armed!=true then 
				self:EmitSound("items/ammopickup.wav", 80, 100)
				if self.AmmoList[v:GetClass()] == nil then 
					self.AmmoList[v:GetClass()] = 1 
					self:SetNWInt(v:GetClass(), self.AmmoList[v:GetClass()])

				else
				
					self.AmmoList[v:GetClass()] = self.AmmoList[v:GetClass()] + 1 
					self:SetNWInt(v:GetClass(), self.AmmoList[v:GetClass()])
				end
				v:Remove()
			end
		end
	end
end

function ENT:ReconfigureWeight()
	local sum = 0
	for k, v in pairs(self.AmmoList) do
		sum = sum + 1
	end
	
	self:GetPhysicsObject():SetMass(250 + (sum * -100))
end




net.Receive( "mortar_cache", function( len, ply )
	local tbl = net.ReadTable()
	local entity = net.ReadEntity()
	if entity:IsValid()==false then return end
	local function tableToString(tbl)
		local ammo_count = "Ammo left\n"
		for k, v in pairs(tbl) do
			ent = k
			num = v
			ammo_count = ammo_count..ent..": "..num.."\n"
			
		end
		return ammo_count
		
	end
	
	if LocalPlayer():EyePos():Distance( entity:GetPos() ) < 156  then
		AddWorldTip( entity:EntIndex(), ( tableToString(tbl) ), 0.5, entity:GetPos(), entity  )
	end
end )


function ENT:Think()
	if (SERVER) then
		if !self:IsValid() then return end
		self:HasMortarCountChanged()
		self:TakeAmmo()
		self:ReconfigureWeight()


		net.Start( "mortar_cache" )
			net.WriteTable(self.AmmoList)
			net.WriteEntity(self)
		net.Broadcast()


		self:NextThink(CurTime()) 
		
		return true
	end
end


function ENT:CanLaunch()
	if (self.RequestTime+1) < CurTime()then
		self.RequestTime=CurTime()
		return true
	else	
		return false
	end
end

function ENT:TriggerInput(iname, value)	 
end 

function ENT:LoadModel()
     if self.UseRandomModels then
	     self:SetModel(table.Random(Models))
	 else
	     self:SetModel(self.Model)
	 end
end
	 

function ENT:Explode()
	if (CLIENT) then return end
	if !self.Exploded then return end
	local pos = self:GetPos()
    
	 
	self:EmitSound("phx/explode02.wav", 100, 100)

	for class, total in pairs(self.AmmoList) do
		for i=0, total do
			if class == "prop_physics" then
				local ang = math.random(0,628)/100
				local radius = math.random(100,200)
				local pos = Vector(math.cos(ang), math.sin(ang), math.sin(ang))*radius + self:GetPos()
				local ent = ents.Create(class)
				ent:SetPos(self:GetPos() + Vector(math.random(-180,180),math.random(-180,180),math.random(-180,180)))
				ent:SetModel("models/props_c17/oildrum001_explosive.mdl")
				ent:Spawn()
				ent:Activate()
				ent:SetAngles((self:GetPos()-pos):Angle())
				ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
				ent:Ignite(10,0)
				local pos = self:GetPos()
				for i=0, 500 do 
					timer.Simple(i/100, function()
						if ent:IsValid() then 
							ent:GetPhysicsObject():AddVelocity(  Vector(math.random(-180,180),math.random(-180,180),math.random(-180,180)) * 100 )
							
						end
					end)
				end
				local trail = util.SpriteTrail(ent, 0, Color(255,15, 15, 255), false, 15, 1, 8, 1/(15+1)*0.5, "trails/smoke.vmt")			
			else
			
				local ang = math.random(0,628)/100
				local radius = math.random(100,200)
				local pos = Vector(math.cos(ang), math.sin(ang), math.sin(ang))*radius + self:GetPos()
				local ent = ents.Create(class)
				ent:SetPos(self:GetPos() + Vector(math.random(-180,180),math.random(-180,180),math.random(-180,180)))
				ent:Spawn()
				ent:Activate()
				ent:SetAngles((self:GetPos()-pos):Angle())
				ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
				local pos = self:GetPos()

				ent:GetPhysicsObject():SetVelocity((pos-ent:GetPos()):GetNormal() * -math.random(600,600))
	

				ent:Arm()
				local trail = util.SpriteTrail(ent, 0, Color(155,155,155, 50), false, 15, 1, 4, 1/(15+1)*0.5, "trails/smoke.vmt")
			end

		end
	end


    self:Remove()
end

function ENT:OnTakeDamage(dmginfo)
	if (CLIENT) then return end
	if self.Exploded then return end
	self:TakePhysicsDamage(dmginfo)

	local phys = self:GetPhysicsObject()

	if (self.Life <= 0) then return end

	if self:IsValid() then
	self.Life = self.Life - dmginfo:GetDamage()
	if (self.Life <= 0) then 
	if !self:IsValid() then return end 
	self.Exploded = true
	self:Explode()
	end
	end
end

function ENT:PhysicsCollide( data, physobj )
end

function ENT:Arm()
end	 

function ENT:Use( activator, caller )
	if self:CanLaunch() then
		 if !self:IsValid() then return end
		 self:Explode()
	end
end

function ENT:OnRemove()
	if (SERVER) then
		
	end
end


if (CLIENT) then
	function ENT:Draw()
		
		self:DrawModel()

	end

end


function ENT:OnRestore()
     Wire_Restored(self.Entity)
end

function ENT:BuildDupeInfo()
     return WireLib.BuildDupeInfo(self.Entity)
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
     WireLib.ApplyDupeInfo( ply, ent, info, GetEntByID )
end

function ENT:PrentityCopy()
     local DupeInfo = self:BuildDupeInfo()
     if(DupeInfo) then
         duplicator.StorentityModifier(self,"WireDupeInfo",DupeInfo)
     end
end

function ENT:PostEntityPaste(Player,Ent,CreatedEntities)
     if(Ent.EntityMods and Ent.EntityMods.WireDupeInfo) then
         Ent:ApplyDupeInfo(Player, Ent, Ent.EntityMods.WireDupeInfo, function(id) return CreatedEntities[id] end)
     end
end