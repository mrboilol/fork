AddCSLuaFile()

DEFINE_BASECLASS( "hb_base_rocket_" )

ENT.Spawnable		            	 =  true         
ENT.AdminSpawnable		             =  true 

ENT.PrintName		                 =  "V2 - MRD1022"
ENT.Author			                 =  ""
ENT.Contact			                 =  ""
ENT.Category                         =  "HBOMBS Nukes"

ENT.Model                            =  "models/thedoctor/v2.mdl"
ENT.RocketTrail                      =  "h_v2"
ENT.RocketBurnoutTrail               =  ""
ENT.Effect                           =  "h_rktboom"
ENT.EffectAir                        =  "h_rktboom_air"
ENT.EffectWater                      =  "h_water_huge" 
ENT.ExplosionSound                   =  "gbombs_5/explosions/heavy_bomb/explosion_big_3.mp3"        
ENT.StartSound                       =  "gbombs_5/launch/srb_launch.wav"          
ENT.ArmSound                         =  "npc/roller/mine/rmine_blip3.wav"            
ENT.ActivationSound                  =  "buttons/button14.wav"    
ENT.EngineSound                      =  "Motor_Small"

ENT.ShouldUnweld                     =  true          
ENT.ShouldIgnite                     =  true         
ENT.UseRandomSounds                  =  false         
ENT.SmartLaunch                      =  false
ENT.Timed                            =  false 

ENT.ExplosionDamage                  =  150
ENT.ExplosionRadius                  =  9000             
ENT.PhysForce                        =  1000             
ENT.SpecialRadius                    =  900            
ENT.MaxIgnitionTime                  =  2           
ENT.Life                             =  35            
ENT.MaxDelay                         =  0           
ENT.TraceLength                      =  600           
ENT.ImpactSpeed                      =  800         
ENT.Mass                             =  10000             
ENT.EnginePower                      =  50          
ENT.FuelBurnoutTime                  =  40           
ENT.IgnitionDelay                    =  2            
ENT.ArmDelay                         =  0.5
ENT.RotationalForce                  =  0                      
ENT.ForceOrientation                 =  "NONE"
ENT.Timer                            =  0
ENT.Shocktime                        = 3
ENT.HBOWNER                          =  nil             -- don't you fucking touch this.

function ENT:Initialize()
 if (SERVER) then
     self:SetModel(self.Model)  
	 self:PhysicsInit( SOLID_VPHYSICS )
	 self:SetSolid( SOLID_VPHYSICS )
	 self:SetMoveType(MOVETYPE_VPHYSICS)
	 self:SetUseType( ONOFF_USE ) -- doesen't fucking work
	 local phys = self:GetPhysicsObject()
	 local skincount = self:SkinCount()
	 if (phys:IsValid()) then
		 phys:SetMass(self.Mass)
		 phys:Wake()
     end
	 if (skincount > 0) then
	     self:SetSkin(math.random(0,skincount))
	 end
	 self.Armed    = false
	 self.Exploded = false
	 self.Fired    = false
	 self.Burnt    = false
	 self.Ignition = false
	 self.Arming   = false
	 self.Power    = 0.8
	 if !(WireAddon == nil) then self.Inputs = Wire_CreateInputs(self, { "Arm", "Detonate", "Launch" }) end
	end
end

function ENT:ExploSound(pos)
	 local ent = ents.Create("hb_shockwave_sound_lowsh")
	 ent:SetPos( pos ) 
	 ent:Spawn()
	 ent:Activate()
	 ent:SetVar("HBOWNER", self.HBOWNER)
	 ent:SetVar("MAX_RANGE",500000)
	 ent:SetVar("SHOCKWAVE_INCREMENT",130)
	 ent:SetVar("DELAY",0.01)
	 ent:SetVar("SOUND", self.ExplosionSound)
	 ent:SetVar("Shocktime",4)
end

function ENT:Think()
     if(self.Burnt) then return end
     if(!self.Ignition) then return end -- if there wasn't ignition, we won't fly
	 if(self.Exploded) then return end -- if we exploded then what the fuck are we doing here
	 if(!self:IsValid()) then return end -- if we aren't good then something fucked up
	 if self.Power <= 1.5 then
		self.Power = self.Power + 0.01
	 elseif self.Power >=1.5 then
		self.Power = 1.5
	 end
	 local phys = self:GetPhysicsObject()  
	 local thrustpos = self:GetPos()
	 if(self.ForceOrientation == "RIGHT") then
	     phys:AddVelocity(self:GetRight() * self.EnginePower) -- Continuous engine impulse
	 elseif(self.ForceOrientation == "LEFT") then
	     phys:AddVelocity(self:GetRight() * -self.EnginePower) -- Continuous engine impulse
	 elseif(self.ForceOrientation == "UP") then
	     phys:AddVelocity(self:GetUp() * self.EnginePower) -- Continuous engine impulse
	 elseif(self.ForceOrientation == "DOWN") then 
	     phys:AddVelocity(self:GetUp() * -self.EnginePower) -- Continuous engine impulse
	 elseif(self.ForceOrientation == "INV") then
	     phys:AddVelocity(self:GetForward() * -self.EnginePower) -- Continuous engine impulse
	 else
		 local tickrate = 1 / engine.TickInterval()
		 
		 if tickrate >= 65 and tickrate <=67 then
			phys:AddVelocity(self:GetForward() * (12*self.Power)) -- Continuous engine impulse
		 else
			phys:AddVelocity(self:GetForward() * 2*(12*self.Power)) -- Continuous engine impulse
		 end
	 end
	 if (self.Armed) then
        phys:AddAngleVelocity(Vector(self.RotationalForce,0,0)) -- Rotational force
	 end
	 
	 self:NextThink(CurTime() + 0.01)
	 return true
end

function ENT:Launch()
     if(self.Exploded) then return end
	 if(self.Burned) then return end
	 --if(self.Armed) then return end
	 if(self.Fired) then return end
	 
	 local phys = self:GetPhysicsObject()
	 if !phys:IsValid() then return end
	 
	 self.Fired = true
	 if(self.SmartLaunch) then
		 constraint.RemoveAll(self)
	 end
	 timer.Simple(0.05,function()
	     if not self:IsValid() then return end
	     if(phys:IsValid()) then
             phys:Wake()
		     phys:EnableMotion(true)
	     end
	 end)
	 timer.Simple(self.IgnitionDelay,function()
	     if not self:IsValid() then return end  -- Make a short ignition delay!

		 local phys = self:GetPhysicsObject()
		 self.Ignition = true
		 self:Arm()
		 local pos = self:GetPos()
		 sound.Play(self.StartSound, pos, 160, 130,1)
	     self:EmitSound(self.EngineSound)

		 ParticleEffectAttach(self.RocketTrail,PATTACH_ABSORIGIN_FOLLOW,self,1)
		 util.ScreenShake( self:GetPos(), 5555, 3555, 10, 500 )
		 util.ScreenShake( self:GetPos(), 5555, 555, 8, 500 )
		 util.ScreenShake( self:GetPos(), 5555, 555, 5, 500 )
		 if(self.FuelBurnoutTime != 0) then 
	         timer.Simple(self.FuelBurnoutTime,function()
		         if not self:IsValid() then return end 
		         self.Burnt = true
		         self:StopParticles()
		         self:StopSound(self.EngineSound)
	             ParticleEffectAttach(self.RocketBurnoutTrail,PATTACH_ABSORIGIN_FOLLOW,self,1)
             end)	 
		 end
     end)		 
end

function ENT:Explode()
     if not self.Exploded then return end
	 local pos = self:LocalToWorld(self:OBBCenter())
	 
	  	 local ent = ents.Create("hb_shockwave_ent_nounfreeze")
	 ent:SetPos( pos ) 
	 ent:Spawn()
	 ent:Activate()
	 ent:SetVar("DEFAULT_PHYSFORCE", 250)
	 ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", 50)
	 ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", 10)
	 ent:SetVar("HBOWNER", self.HBOWNER)
	 ent:SetVar("MAX_RANGE",8000)
	 ent:SetVar("SHOCKWAVE_INCREMENT",130)
	 ent:SetVar("DELAY",0.01)
	 ent.trace=self.TraceLength
	 ent.decal=self.Decal
	 
	 
	for k, v in pairs(ents.FindInSphere(pos,8000)) do
		if (v:IsValid() or v:IsPlayer()) then
			if v:IsValid() and v:GetPhysicsObject():IsValid() then
				v:Ignite(5,0)
			end
		 end
	 end
	 
	 local ent = ents.Create("hb_shockwave_ent_nounfreeze")	 
	 ent:SetPos( pos ) 
	 ent:Spawn()
	 ent:Activate()
	 ent:SetVar("DEFAULT_PHYSFORCE",10)
	 ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR",1)
	 ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND",5)
	 ent:SetVar("HBOWNER", self.HBOWNER)
	 ent:SetVar("MAX_RANGE",18000)
	 ent:SetVar("SHOCKWAVE_INCREMENT",130)
	 ent:SetVar("DELAY",0.01)
	 ent.trace=self.TraceLength
	 ent.decal=self.Decal
	 
	 for k, v in pairs(ents.FindInSphere(pos,self.SpecialRadius)) do
	     if v:IsValid() then
		     --local phys = v:GetPhysicsObject()
			 local i = 0
		     while i < v:GetPhysicsObjectCount() do
			 phys = v:GetPhysicsObjectNum(i)	  
             if (phys:IsValid()) then		
		 	     local mass = phys:GetMass()
				 local F_ang = self.PhysForce
				 local dist = (pos - v:GetPos()):Length()
				 local relation = math.Clamp((self.SpecialRadius - dist) / self.SpecialRadius, 0, 1)
				 local F_dir = (v:GetPos() - pos):GetNormal() * (self.PhysForce or 690)
				   
				 phys:AddAngleVelocity(Vector(F_ang, F_ang, F_ang) * relation)
				 phys:AddVelocity(F_dir)
		     end
			 i = i + 1
			 end
		 end
	 end

	 timer.Simple (1, function()
	 
		 local ent = ents.Create("hb_shockwave_sound_lowsh")
		 ent:SetPos( pos ) 
		 ent:Spawn()
		 ent:Activate()
		 ent:SetVar("HBOWNER", self.HBOWNER)
		 ent:SetVar("MAX_RANGE",50000)
		 ent:SetVar("SHOCKWAVE_INCREMENT", 130)
		 ent:SetVar("DELAY",0.01)
		 ent:SetVar("SOUND", "gbombs_5/explosions/heavy_bomb/explosion_big_3.mp3")
		 ent:SetVar("Shocktime", 3)
		 
	  	 local ent = ents.Create("hb_shockwave_ent")
		 ent:SetPos( pos ) 
		 ent:Spawn()
		 ent:Activate()
		 ent:SetVar("DEFAULT_PHYSFORCE", 100)
		 ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", self.DEFAULT_PHYSFORCE_PLYAIR)
		 ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", self.DEFAULT_PHYSFORCE_PLYGROUND)
		 ent:SetVar("HBOWNER", self.HBOWNER)
		 ent:SetVar("MAX_RANGE", 11000)
		 ent:SetVar("SHOCKWAVE_INCREMENT",130)
		 ent:SetVar("DELAY",0.01)
		 ent.trace=self.TraceLength
		 ent.decal=self.Decal
	 end)

	 
	 
	 
	 
	 
     if(self:WaterLevel() >= 1) then
		 local trdata   = {}
		 local trlength = Vector(0,0,9000)

		 trdata.start   = pos
		 trdata.endpos  = trdata.start + trlength
		 trdata.filter  = self
		 local tr = util.TraceLine(trdata) 

		 local trdat2   = {}
		 trdat2.start   = tr.HitPos
		 trdat2.endpos  = trdata.start - trlength
		 trdat2.filter  = self
		 trdat2.mask    = MASK_WATER + CONTENTS_TRANSLUCENT
			 
		 local tr2 = util.TraceLine(trdat2)
			 
	     if tr2.Hit then
		     ParticleEffect(self.EffectWater, tr2.HitPos, Angle(0,0,0), nil)   
		 end
     else
		 local tracedata    = {}
	     tracedata.start    = pos
		 tracedata.endpos   = tracedata.start - Vector(0, 0, self.TraceLength)
		 tracedata.filter   = self.Entity
				
		 local trace = util.TraceLine(tracedata)
	     Explosion={}
		 Explosion[1]="h_rktboom"
		 Explosion[2]="h_rktboom"
		 
	     Explosionair={}
		 Explosionair[1]="h_rktboom_air"
		 Explosionair[2]="h_rktboom_air"	
		 
		 if trace.HitWorld then
		     ParticleEffect(table.Random(Explosion),pos,Angle(0,0,0),nil)
		 else 
			 ParticleEffect(table.Random(Explosionair),pos,Angle(0,0,0),nil) 
		 end
     end
	 if self.IsNBC then
	     local nbc = ents.Create(self.NBCEntity)
		 nbc:SetVar("HBOWNER",self.HBOWNER)
		 nbc:SetPos(self:GetPos())
		 nbc:Spawn()
		 nbc:Activate()
	 end
	 self:Remove()
end

function ENT:SpawnFunction( ply, tr )
     if ( !tr.Hit ) then return end
	 self.HBOWNER = ply
     local ent = ents.Create( self.ClassName )
	 ent:SetPhysicsAttacker(ply)
     ent:SetPos( tr.HitPos + tr.HitNormal * 46 ) 
	 ent:SetAngles(Angle(-90,0,0))
     ent:Spawn()
     ent:Activate()

     return ent
end